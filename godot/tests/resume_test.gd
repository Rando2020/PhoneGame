extends SceneTree
## Save and resume through the real screens. A bot plays runs by click (best-EV
## keeps, The Play by first playable card, a simple shop) twice: once straight
## through, once "killing the app" every few saves (throwing RunFlow away and
## resuming a new one from the save via the title's CONTINUE). Every decision
## the bot makes must see the same state in both, and the runs must end the
## same. Kills land on every kind of save: the intro, the shop, a fresh deal, a
## mulligan, a count, The Play mid-hand and mid-beat.
##   godot --headless --path godot --script res://tests/resume_test.gd
const SIZE := Vector2i(720, 1280)
var checks := 0
var fails := 0
var kills := 0
var killed_on := {}


func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		if fails <= 10:
			print("FAIL ", m)


func _initialize() -> void:
	_go.call_deferred()


func _click(at: Vector2) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = at
		e.global_position = at
		Input.parse_input_event(e)
		Input.flush_buffered_events()
		await process_frame


func _press(c: Control) -> void:
	await _click(c.get_global_transform() * (c.size / 2.0))


func _wait(cond: Callable, frames := 2000) -> bool:
	for i in frames:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func snap(f: RunFlow) -> String:
	var r: CribRun = f.run
	var s := "%s %d-%d g%d deck%d ch%s" % [f.screen, r.act, r.round, r.essence, r.cards.size(), r.charms.map(func(c): return c.id)]
	if f.screen == "round" and f.keep != null and f.keep.rd != null:
		var rd: CribRound = f.keep.rd
		s += " sc%d dl%d st%d ph%s dealt%s" % [rd.score, rd.deals_left, rd.stock.size(), rd.phase,
			rd.dealt.map(func(c): return "%d%s" % [c.rank, c.suit]) if rd.dealt != null else []]
		if f.keep.peg_view != null:
			var p: PegPlay = f.keep.peg_session.play
			s += " peg%d/%d tot%d mine%d" % [p.score, p.opp_score, p.total, p.mine.size()]
	return s


## One run by the bot. kill_every = 0: never kill.
func play(seed: int, kill_every: int) -> Array:
	Achv.save_store({"__v": 3})
	for sy in ["the_play", "crib_cut"]:
		Achv.grant_system(sy)
	JS.unseeded = JsRng.new(seed)
	var f: RunFlow = load("res://scenes/run_flow.tscn").instantiate()
	root.add_child(f)
	await process_frame
	f.start_run(CribRun.new(["thump", "pip", "clover"][seed % 3], Meta.STREETS[0], null, seed))
	var log := []
	var seen_saves := f.saves
	var since := 0
	var guard := 0
	var mulled := {}
	var shop_killed := {}
	var bought_at := {}       ## one purchase per shop visit, so a resumed shop doesn't buy again
	var kill_now := false
	var last_len := 0
	var stall := 0
	while guard < 3000:
		guard += 1
		await process_frame
		# ---- the kill: new RunFlow, resumed from the save, via CONTINUE
		if kill_every > 0 and (f.saves > seen_saves or kill_now):
			since += f.saves - seen_saves
			seen_saves = f.saves
			# also once on every shop visit (the cadence alone can miss them)
			var shop_kill := f.screen == "shop" and not shop_killed.has(f.run.round_index())
			if shop_kill:
				shop_killed[f.run.round_index()] = true
			if (since >= kill_every or shop_kill or kill_now) and f.last_save != "":
				kill_now = false
				since = 0
				var text := f.last_save
				var where := f.screen
				if where == "round" and f.keep != null:
					where += "/" + f.keep.rd.phase + ("/peg" if f.keep.peg_view != null else "") + \
						("/beat" if f.keep.peg_view != null and f.keep.peg_view.waiting else "")
				killed_on[where] = int(killed_on.get(where, 0)) + 1
				f.queue_free()
				await process_frame
				f = load("res://scenes/run_flow.tscn").instantiate()
				f.last_save = text
				root.add_child(f)
				await process_frame
				ok(f.front.buttons.has("resume"), "no CONTINUE on the title with a save")
				await _press(f.front.buttons["resume"])
				seen_saves = f.saves
				kills += 1
				continue
		match f.screen:
			"intro":
				log.append(snap(f))
				await _press(f.buttons["deal"])
			"round":
				var k: KeepScreen = f.keep
				if k.peg_view != null:
					var pv: PegView = k.peg_view
					if pv.waiting:
						await _click(Vector2(SIZE.x / 2.0, SIZE.y * 0.2))
					elif pv.s.play.over:
						log.append(snap(f))
						await _press(pv.continue_button)
					else:
						log.append(snap(f))
						var can: Array = pv.s.playable_indices()
						if can.is_empty():
							ok(false, "seed %d: The Play waits on a hand with nothing to lay: %s" % [seed, snap(f)])
							break
						await _press(pv.hand_views[can[0]])
				elif k.cutting or k.cascading:
					await _click(Vector2(SIZE.x / 2.0, SIZE.y * 0.45))
				elif k.dealing:
					pass
				elif k.rd.phase == "keep" and not k.rd.over:
					log.append(snap(f))
					var key := "%d-%d-%d" % [f.run.act, f.run.round, k.rd.deal_index]
					var best := k.rd.best_keep_ev()
					if best.ev < 6 and k.mulligan_button.visible and not mulled.has(key):
						mulled[key] = true
						await _press(k.mulligan_button)
						continue
					for i in best.idx:
						for v in k.hand._views.size():
							if int(k.hand._cards[v]._i) == i:
								await _press(k.hand._views[v])
					await _press(k.keep_button)
				elif not k.keep_button.disabled:
					await _press(k.keep_button)    # Next deal / The Play / Continue
			"round_end":
				log.append(snap(f))
				if f.buttons.has("shop"):
					await _press(f.buttons["shop"])
				else:
					break
			"shop":
				var s: ShopScreen = f.shop
				var visit := f.run.round_index()
				if not bought_at.has(visit):
					log.append(snap(f))          # once per visit: a resumed shop is the same visit
					bought_at[visit] = true
					for id in s.offer_buttons:
						var ob: Button = s.offer_buttons[id]
						if not ob.disabled:
							s._scroll.ensure_control_visible(ob)
							await process_frame
							await _press(ob)
							break
					if kill_every > 0:
						kill_now = true     # die right after the purchase: its save must hold it
						continue
				await process_frame
				s = f.shop
				s._scroll.ensure_control_visible(s.next_button)
				await process_frame
				await _press(s.next_button)
			"run_won":
				log.append(snap(f))
				break
			_:
				break
		# a stuck screen (nothing new decided for 400 frames) is a failure, not a hang
		if log.size() == last_len:
			stall += 1
			if stall > 400:
				ok(false, "seed %d: stuck on %s" % [seed, snap(f)])
				break
		else:
			stall = 0
			last_len = log.size()
		if f.run.round_index() > 8:      # long enough: every kind of save happens early
			log.append("stop " + snap(f))
			break
	var end := snap(f)
	f.queue_free()
	await process_frame
	return [log, end]


func _go() -> void:
	Achv.persist = false
	root.size = SIZE
	Engine.time_scale = 8.0
	var runs := 0
	for seed in [4401, 4402, 4403, 4404]:
		var a := await play(seed, 0)
		for k in [3, 7]:
			var b := await play(seed, k)
			var n := mini(a[0].size(), b[0].size())
			var first := -1
			for i in n:
				if a[0][i] != b[0][i]:
					first = i
					break
			ok(first == -1 and a[0].size() == b[0].size(), "seed %d kill every %d: decisions differ at %d\n   straight: %s\n   resumed:  %s" % [seed, k, first,
				a[0][first] if first >= 0 else a[0].size(), b[0][first] if first >= 0 else b[0].size()])
			ok(a[1] == b[1], "seed %d kill every %d: ended %s vs %s" % [seed, k, a[1], b[1]])
			runs += 1
	Engine.time_scale = 1.0
	print("resume: %d run pairs, %d kills, killed on %s" % [runs, kills, killed_on])
	var good := fails == 0 and kills >= 40 and killed_on.size() >= 6 and killed_on.has("shop")
	print("resume checks: %d, failures: %d" % [checks, fails])
	print("RESUME OK" if good else "RESUME FAILED")
	quit(0 if good else 1)
