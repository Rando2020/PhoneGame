extends SceneTree
## Whole runs through RunFlow with real clicks: intro DEAL -> keep 4 cards ->
## Keep -> (skip the count) -> Next deal ... -> Continue -> round end SHOP ->
## buy by click -> NEXT ROUND -> intro. A replay applies the web's handler order
## (cribRoundIntro / afterCount / cribRoundEnd / showCribShop NEXT ROUND) directly
## to the engine; the two runs must agree after every round, and the screens
## must come in the web's order. Also: WALK AWAY on a Wager, SKIP with a banked
## no SKIP even with one banked (Skips were removed), the run-won screen, and layout (text above buttons, all on screen).
##   godot --headless --path godot --script res://tests/run_flow_test.gd
const SIZE := Vector2i(720, 1280)
var checks := 0
var fails := 0
var clicks := 0
var rounds_checked := 0
var plays := 0
var seen := {}   ## screen paths exercised: walk, skip, run_won, run_over, wager_played, boss


func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		if fails <= 10:
			print("FAIL ", m)


func _initialize() -> void:
	_go.call_deferred()


func _wait(cond: Callable, frames := 3000) -> bool:
	for i in frames:
		if cond.call():
			return true
		await process_frame
	return cond.call()


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
	clicks += 1


func _press(c: Control) -> void:
	await _click(c.get_global_rect().get_center())


func state(run, rd) -> Dictionary:
	var lv := {}
	for k in run.levels:
		lv[k] = run.levels[k]
	return {"act": run.act, "round": run.round, "essence": run.essence, "deck": run.cards.size(),
		"charms": run.charms.map(func(c): return c.id), "levels": lv, "skips": run.skips, "shop_open": run.shop_state != null,
		"score": rd.score if rd != null else -1, "won": rd.won if rd != null else false,
		"systems": Achv.locked_systems().map(func(x): return x.id)}


## Text never runs under the buttons; every button on screen.
func check_page(f: RunFlow, where: String) -> void:
	var top := float(SIZE.y)
	for b in f.buttons.values():
		var r: Rect2 = b.get_global_rect()
		ok(r.position.x >= 0 and r.end.x <= SIZE.x and r.position.y >= 0 and r.end.y <= SIZE.y, "%s: button %s off screen %s" % [where, b.text, r])
		ok(absf(r.get_center().x - SIZE.x / 2.0) <= 1.0, "%s: button %s off centre %s" % [where, b.text, r])
		top = minf(top, r.position.y)
	var lowest := 0.0
	for c in f._page.get_children():
		if c is Label or c is Panel:
			lowest = maxf(lowest, c.get_global_rect().end.y)
	ok(lowest <= top + 0.5, "%s: content reaches %.0f, buttons start at %.0f" % [where, lowest, top])


## One full run. `prep` builds the run (screen and replay get identical copies).
func play(name: String, prep: Callable, opts := {}) -> void:
	Achv.persist = false
	Achv.save_store({"__v": 3})
	for sy in opts.get("systems", []):
		Achv.grant_system(sy)
	var save_b = Achv._cache.duplicate(true)
	JS.unseeded = JsRng.new(11)
	var f: RunFlow = load("res://scenes/run_flow.tscn").instantiate()
	root.add_child(f)
	await process_frame
	f.start_run(prep.call())
	# the replay gets its own save and Math.random stream, swapped in around its calls
	var ui_save = Achv.load_store()
	var R: CribRun = prep.call()
	# GDScript lambdas capture locals BY VALUE: assignments inside one don't
	# survive the call. Keep the swapped state in a Dictionary (shared by reference).
	var st := {"save_a": null, "save_b": save_b, "rng_a": null, "rng_b": JsRng.new(11)}
	var swap := func(to_replay: bool):
		if to_replay:
			st.save_a = Achv._cache
			st.rng_a = JS.unseeded
			Achv._cache = st.save_b
			JS.unseeded = st.rng_b
		else:
			st.save_b = Achv._cache
			st.rng_b = JS.unseeded
			Achv._cache = st.save_a
			JS.unseeded = st.rng_a
	var walked := false
	var order := []
	var guard := 0
	while guard < 40:
		guard += 1
		await _wait(func(): return f.screen == "intro")
		order.append("intro")
		check_page(f, "%s intro %d-%d" % [name, f.run.act, f.run.round])
		if f.run.boss() != null:
			seen["boss"] = true
		# ---- intro choices
		if opts.get("walk", false) and not walked and f.run.is_wager():
			ok(f.buttons.has("walk"), "%s: wager without WALK AWAY" % name)
			await _press(f.buttons["walk"])
			swap.call(true)
			R.wager_at["%d-%d" % [R.act, R.round]] = false
			swap.call(false)
			walked = true
			seen["walk"] = true
			ok(not f.run.is_wager() and f.screen == "intro", "%s: walk away didn't strike the wager" % name)
			ok(f._toast != null and f._toast.text == "You let the wager pass." and f._toast.get_index() == f.get_child_count() - 1, "%s: no walk-away flash on top" % name)
			continue
		# Skips were removed: even with one banked, there's no SKIP button
		if f.run.skips > 0:
			ok(not f.buttons.has("skip"), "%s: SKIP button is back" % name)
			seen["no_skip"] = true
		if true:
			if f.run.is_wager():
				seen["wager_played"] = true
			await _press(f.buttons["deal"])
			ok(f.screen == "round", "%s: DEAL didn't start the round" % name)
			order.append("round")
			swap.call(true)
			var rd := CribRound.new(R)
			swap.call(false)
			# ---- the round: same keeps on both sides
			var deal := 0
			while true:
				await _wait(func(): return f.keep != null and (f.keep.rd.phase == "keep" and not f.keep.dealing or f.keep.rd.over))
				if f.keep.rd.over:
					break
				swap.call(true)
				var nd = rd.new_deal()
				swap.call(false)
				ok(nd != null, "%s: replay ran out of cards where the screen dealt" % name)
				var keep: Array = rd.best_keep_ev().idx
				ok(load("res://tests/parity_test.gd").diff(rd.dealt, f.keep.rd.dealt) == "", "%s %d-%d deal %d: dealt differs" % [name, R.act, R.round, deal])
				for i in keep:
					for k in f.keep.hand._views.size():
						if int(f.keep.hand._cards[k]._i) == i:
							await _press(f.keep.hand._views[k])
				await _press(f.keep.keep_button)
				# the web's doCribCount + afterCount: the Play (if owed) comes before
				# the round goes on or ends
				swap.call(true)
				var kept: Array = keep.map(func(i): return rd.dealt[i])
				rd.commit(keep)
				var owed := PegSession.wanted(rd)
				swap.call(false)
				# skip the cut ceremony / cascade by tapping the table
				for t in 2:
					if f.keep.cutting or f.keep.cascading:
						await _click(Vector2(SIZE.x / 2.0, SIZE.y * 0.45))
				await _wait(func(): return not f.keep.cutting and not f.keep.cascading)
				deal += 1
				ok(f.keep.peg_pending == owed, "%s %d-%d deal %d: Play owed %s, web %s" % [name, R.act, R.round, deal, f.keep.peg_pending, owed])
				if owed:
					await _press(f.keep.keep_button)   # "The Play"
					var pv: PegView = f.keep.peg_view
					swap.call(true)
					var rs := PegSession.start(rd, kept)
					swap.call(false)
					var g := 0
					while not pv.s.play.over and g < 20:
						g += 1
						var kk: int = pv.s.playable_indices()[0]
						await _press(pv.hand_views[kk])
						await _click(Vector2(SIZE.x / 2.0, SIZE.y * 0.2))   # tap through the beat
						swap.call(true)
						rs.lay(rs.playable_indices()[0])
						rs.answer()
						swap.call(false)
					await _press(pv.continue_button)
					swap.call(true)
					rs.apply()
					var ends: bool = not (rd.deals_left > 0 and rd.score < rd.target)
					if ends:
						rd.settle()
					swap.call(false)
					plays += 1
					seen["play"] = true
					if ends:
						break      # the round is handed straight to the round-end page
					continue
				swap.call(true)
				if rd.score >= rd.target or rd.deals_left <= 0:
					rd.settle()
				swap.call(false)
				if f.keep.rd.over:
					break
				await _press(f.keep.keep_button)   # "Next deal"
			if not rd.over:
				swap.call(true)
				rd.settle()   # the replay's deck ran dry where the screen's did
				swap.call(false)
			if f.screen == "round":
				ok(f.keep.keep_button.text == "Continue", "%s: round over but button says %s" % [name, f.keep.keep_button.text])
				await _press(f.keep.keep_button)   # "Continue"
			await _wait(func(): return f.screen == "round_end")
			order.append("round_end")
			check_page(f, "%s round end %d-%d" % [name, R.act, R.round])
			# ---- replay cribRoundEnd
			swap.call(true)
			rd.settle()
			if rd.wager != null and rd.wager_won:
				var locked := Achv.locked_systems()
				if not locked.is_empty():
					Achv.grant_system(locked[0].id)
			if rd.won:
				R.essence += rd.essence_earned
			swap.call(false)
			var a := state(f.run, f.rd)
			swap.call(true)
			var b := state(R, rd)
			swap.call(false)
			var d: String = load("res://tests/parity_test.gd").diff(b, a)
			ok(d == "", "%s round %d-%d: flow differs from the web's order: %s" % [name, R.act, R.round, d])
			rounds_checked += 1
			if d != "":
				break
			if not rd.won:
				ok(f.buttons.has("new_run") and not f.buttons.has("shop"), "%s: lost round should offer NEW RUN only" % name)
				seen["run_over"] = true
				break
			await _press(f.buttons["shop"])
			ok(f.screen == "shop", "%s: SHOP didn't open the shop" % name)
			order.append("shop")
			swap.call(true)
			R.open_shop()
			swap.call(false)
		# ---- the shop: buy the first affordable charm and one Reckoning, by click
		await process_frame
		var s: ShopScreen = f.shop
		for id in s.offer_buttons:
			var ob: Button = s.offer_buttons[id]
			if not ob.disabled:
				s._scroll.ensure_control_visible(ob)
				await process_frame
				await _press(ob)
				swap.call(true)
				var ch: Charm = null
				for c in R.shop_state.offer:
					if c.id == id:
						ch = c
				R.essence -= ch.cost
				R.charms.append(ch)
				if ch.on_acquire.is_valid():
					ch.on_acquire.call(R)
				R.shop_state.offer = R.shop_state.offer.filter(func(x): return x.id != id)
				swap.call(false)
				break
		await process_frame
		s = f.shop
		if not s.level_buttons["fifteen"].disabled:
			s._scroll.ensure_control_visible(s.level_buttons["fifteen"])
			await process_frame
			await _press(s.level_buttons["fifteen"])
			swap.call(true)
			R.buy_level("fifteen")
			swap.call(false)
		await process_frame
		s = f.shop
		s._scroll.ensure_control_visible(s.next_button)
		await process_frame
		await _press(s.next_button)
		# ---- replay the NEXT ROUND handler
		swap.call(true)
		R.shop_state = null
		var finished := false
		if R.endless:
			R.endless_round += 1
		elif R.advance():
			finished = true
		swap.call(false)
		var a2 := state(f.run, null)
		swap.call(true)
		var b2 := state(R, null)
		swap.call(false)
		ok(load("res://tests/parity_test.gd").diff(b2, a2) == "", "%s after shop: %s" % [name, load("res://tests/parity_test.gd").diff(b2, a2)])
		if finished:
			await _wait(func(): return f.screen == "run_won")
			ok(f.screen == "run_won" and f.buttons.has("new_run"), "%s: Act 5 cleared but no run-won screen" % name)
			check_page(f, "%s run won" % name)
			seen["run_won"] = true
			order.append("run_won")
			break
	# the web's screen order: intro, (round, round_end)?, shop, intro ...
	var bad := false
	for i in range(1, order.size()):
		var pair: String = order[i - 1] + ">" + order[i]
		if not pair in ["intro>round", "intro>shop", "intro>intro", "round>round_end", "round_end>shop", "shop>intro", "shop>run_won"]:
			bad = true
			ok(false, "%s: screen order %s" % [name, pair])
	print("%s: %d screens, ended on %s" % [name, order.size(), order[order.size() - 1]])
	Achv._cache = ui_save
	f.queue_free()
	await process_frame


func _strong(seed: int, act := 1) -> CribRun:
	var r := CribRun.new("thump", null, null, seed)
	for id in ["keystone2", "ballast", "fifteener", "tallyman", "usury"]:
		r.charms.append(CribData.charm_by_id(id))
	r.act = act
	return r


func _go() -> void:
	root.size = SIZE
	Engine.time_scale = 10.0
	await process_frame
	var t0 := Time.get_ticks_msec()
	await play("plain run", func(): return CribRun.new("pip", null, null, 424242))
	await play("strong from Act 5", func(): return _strong(777, 5))
	await play("skip + walk away", func():
		var r := _strong(31337, 1)
		r.skips = 1
		return r
		, {"walk": true})
	await play("long plain run", func(): return CribRun.new("pip", null, null, 9001))
	await play("The Play owned", func():
		var r := _strong(2468, 1)
		return r
		, {"systems": ["the_play", "crib_cut"]})
	Engine.time_scale = 1.0
	print("run flow: %d rounds checked, %d Plays, %d clicks, paths %s, %d ms" % [rounds_checked, plays, clicks, seen.keys(), Time.get_ticks_msec() - t0])
	var good := fails == 0 and rounds_checked >= 8 and plays >= 15 and seen.has("run_won") and seen.has("run_over") and seen.has("no_skip") and seen.has("walk")
	print("run flow checks: %d, failures: %d" % [checks, fails])
	print("RUN FLOW OK" if good else "RUN FLOW FAILED")
	quit(0 if good else 1)
