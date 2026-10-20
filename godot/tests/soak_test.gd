extends SceneTree
## Soak (pass 11, item 4): SOAK_RUNS (default 200) full runs through RunFlow,
## played by a seeded "player" making random choices through the same handlers
## a tap or a flick reaches: random keeps (taps and flicks mixed), random lays
## in The Play, random shop buys, rerolls and sells. Presentation randomness
## only: the player's RNG is its own (never JS.unseeded); the game's draws are
## seeded per run.
## Checks: every run ends (a loss, or the run won); at random points a save,
## resumed in a second RunFlow and saved again, is the same text (a save
## round-trips at every kind of moment); with the flow freed, the node and
## orphan counts after the last run are no higher than after the first.
## The player only does what a player can: no press on a disabled button.
## Errors can't be caught from GDScript: tools/soak.sh runs this and fails on
## any SCRIPT ERROR or engine ERROR line (other than the exit-time leak notes).
##   SOAK_RUNS=200 godot --headless --path godot --script res://tests/soak_test.gd
var checks := 0
var fails := 0
var rng := RandomNumberGenerator.new()      ## the player's choices only
var stats := {"runs": 0, "won": 0, "deals": 0, "flicks": 0, "taps": 0, "lays": 0,
	"buys": 0, "rerolls": 0, "sells": 0, "saves_checked": 0, "rounds": 0}
var save_kinds := {}
var strong := false              ## SOAK_STRONG=1: best keeps, greedy lays, sensible buys
var depth := {}                  ## furthest "act-round" reached -> runs
var bosses := 0                  ## Spoiler rounds played
var free_mode := false           ## SOAK_FREE=1: the game is free-only (Entitlement.force)
var free_cards := 0              ## end cards reached
var max_act := 0                 ## the furthest act any round started in


func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		if fails <= 20:
			print("FAIL ", m)


func _initialize() -> void:
	_go.call_deferred()


## Save, resume in a second flow, save again: the same text.
func _check_save(f: RunFlow, where: String) -> void:
	f.save_now()
	var text := f.last_save
	if text == "":
		return
	var keep_rng = JS.unseeded
	JS.unseeded = JsRng.new(1)              # the copy must not draw from the run's RNG
	var g: RunFlow = load("res://scenes/run_flow.tscn").instantiate()
	root.add_child(g)
	g.last_save = text
	g.resume()
	g.save_now()
	JS.unseeded = keep_rng
	# saved during the Spoiler's beat: resume plays its answer at once (by
	# design), so the original answers too before comparing (both draw from
	# the same saved RNG state)
	var k: KeepScreen = f.keep if f.screen == "round" else null
	if k != null and k.peg_view != null and k.peg_view.waiting:
		k.peg_view._answer()
		f.save_now()
		text = f.last_save
	if g.last_save != text and not FileAccess.file_exists("/tmp/soak_a.txt"):
		for pair in [["/tmp/soak_a.txt", text], ["/tmp/soak_b.txt", g.last_save]]:
			var fa := FileAccess.open(pair[0], FileAccess.WRITE)
			fa.store_string(pair[1])
			fa.close()
	ok(g.last_save == text, "%s: save didn't round-trip (%d vs %d chars)" % [where, g.last_save.length(), text.length()])
	stats.saves_checked += 1
	save_kinds[where.get_slice(" ", 0)] = int(save_kinds.get(where.get_slice(" ", 0), 0)) + 1
	g.queue_free()


func _keep_by_hand(k: KeepScreen) -> void:
	var n := k.rd.keep_count()
	var order := range(k.hand._views.size())
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = order[i]
		order[i] = order[j]
		order[j] = t
	var pick: Array = order.slice(0, n)
	if strong or rng.randf() < 0.7:
		pick = k.rd.best_keep_ev().idx     # a good player, mostly: runs go deeper
	for i in pick:
		var v: CardView = k.hand._views[i]
		if rng.randf() < 0.5:
			k.hand._on_card_flicked(v, Vector2(0, 90), Vector2(0, 600))   # flick down: keep
			stats.flicks += 1
		else:
			k.hand._last_press_view = null
			k.hand._on_card_pressed(v)
			stats.taps += 1
	# now and then: change your mind (flick one back up, tap another)
	if rng.randf() < 0.2:
		var sel: Array = k.hand.get_selected_indices()
		if not sel.is_empty():
			k.hand._on_card_flicked(k.hand._views[sel[0]], Vector2(0, -120), Vector2(0, -700))
			for i in k.hand._views.size():
				if not k.hand.get_selected_indices().has(i) and i != sel[0]:
					k.hand._last_press_view = null
					k.hand._on_card_pressed(k.hand._views[i])
					break


## The Play, greedily: make 15 or 31, then a pair with the top card, else the
## lowest card (keeps the count low for the Spoiler).
func _greedy_lay(pv: PegView, can: Array) -> int:
	var p := pv.s.play
	var best: int = can[0]
	var best_v := -1
	for j in can:
		var c: Dictionary = p.mine[j]
		var t: int = p.total + Cribbage.cval(c)
		var v := 0
		if t == 15 or t == 31:
			v = 3
		elif not p.pile.is_empty() and int(p.pile.back().rank) == int(c.rank):
			v = 2
		elif t != 5 and t != 21:
			v = 1
		if v > best_v or v == best_v and Cribbage.cval(c) < Cribbage.cval(p.mine[best]):
			best_v = v
			best = j
	return best


## Sensible buys: the best affordable charm while a slot is free, then
## Reckonings with what's left. Rarer is better; ties by cost.
func _strong_shop(sh: ShopScreen) -> void:
	var order := ["mythic", "legendary", "rare", "uncommon", "common"]
	var picked := true
	while picked:
		picked = false
		var best_id = null
		var best_r := 99
		for id in sh.offer_buttons:
			var b: Button = sh.offer_buttons[id]
			if b.disabled:
				continue
			var ch: Charm = CribData.charm_by_id(id)
			var r := order.find(String(ch.rarity))
			if r < best_r:
				best_r = r
				best_id = id
		if best_id != null:
			sh.offer_buttons[best_id].emit_signal("pressed")
			stats.buys += 1
			picked = true
	for i in 4:
		for cat in ["run", "fifteen", "pair", "flush"]:
			var lb: Button = sh.level_buttons.get(cat)
			if lb != null and not lb.disabled:
				lb.emit_signal("pressed")
				stats.buys += 1


func _shop(f: RunFlow) -> void:
	var sh: ShopScreen = f.shop
	sh.finish()
	if strong:
		_strong_shop(sh)
		await process_frame
		if rng.randf() < 0.3:
			_check_save(f, "shop")
		sh.next_button.emit_signal("pressed")
		return
	for i in rng.randi_range(0, 3):
		var r := rng.randf()
		if r < 0.45 and not sh.offer_buttons.is_empty():
			var ids := sh.offer_buttons.keys()
			var id = ids[rng.randi_range(0, ids.size() - 1)]
			var b: Button = sh.offer_buttons[id]
			if not b.disabled:
				b.emit_signal("pressed")
				stats.buys += 1
		elif r < 0.65 and sh.reroll_button != null and not sh.reroll_button.disabled:
			sh.reroll_button.emit_signal("pressed")
			stats.rerolls += 1
		elif r < 0.75 and not sh.sell_buttons.is_empty():
			var ids := sh.sell_buttons.keys()
			sh.sell_buttons[ids[rng.randi_range(0, ids.size() - 1)]].emit_signal("pressed")
			stats.sells += 1
		elif not sh.card_buttons.is_empty():
			var ks := sh.card_buttons.keys()
			var cb: Button = sh.card_buttons[ks[rng.randi_range(0, ks.size() - 1)]]
			if not cb.disabled:
				cb.emit_signal("pressed")
				stats.buys += 1
		await process_frame
	if rng.randf() < 0.3:
		_check_save(f, "shop")
	sh.next_button.emit_signal("pressed")


## One run, to its end. Returns false if it stalled.
var reach := 0
var seen_intro := {}


func _run(f: RunFlow, i: int) -> bool:
	JS.unseeded = JsRng.new(9000 + i)
	var melds := ["pip", "thump", "clover", "nib", "muggins", "facet"]
	var run := CribRun.new(melds[i % melds.size()], Meta.STREETS[i % Meta.STREETS.size()], null, 5000 + i)
	f.start_run(run)
	var steps := 0
	reach = 0
	seen_intro = {}
	while steps < 6000:
		steps += 1
		await process_frame
		f.settle()
		match f.screen:
			"free_end":
				free_cards += 1
				if rng.randf() < 0.3:
					_check_save(f, "free_end")
				if rng.randf() < 0.3:
					f.buttons["unlock"].emit_signal("pressed")   # no store here: it says so
					await process_frame
				f.buttons["not_now"].emit_signal("pressed")
				return true
			"intro":
				max_act = maxi(max_act, f.run.act)
				var at := "%d-%d" % [f.run.act, f.run.round]
				if not seen_intro.has(at):
					seen_intro[at] = true
					if f.run.boss() != null:
						bosses += 1
				reach = maxi(reach, f.run.act * 10 + f.run.round)
				if rng.randf() < 0.2:
					_check_save(f, "intro")
				if f.buttons.has("walk") and not strong and rng.randf() < 0.3:
					f.buttons["walk"].emit_signal("pressed")
				else:
					f.buttons["deal"].emit_signal("pressed")
			"round":
				var k: KeepScreen = f.keep
				if k == null or k.dealing:
					continue
				if k.peg_view != null:
					var pv := k.peg_view
					if pv.waiting:
						pv._answer()
					elif pv.s.play.over:
						if rng.randf() < 0.3:
							_check_save(f, "peg_over")
						pv._on_continue()
					else:
						var can := []
						for j in mini(pv.hand_views.size(), pv.s.play.mine.size()):
							if pv.s.play.playable(j):
								can.append(j)
						if can.is_empty():
							pv._answer()
						else:
							var j: int = _greedy_lay(pv, can) if strong else can[rng.randi_range(0, can.size() - 1)]
							if rng.randf() < 0.5:
								pv._on_card_flicked(pv.hand_views[j], Vector2(0, -150), Vector2(0, -900), j)
							else:
								pv._on_card(pv.hand_views[j], j)
							stats.lays += 1
							if rng.randf() < 0.1:
								_check_save(f, "peg_mid")
				elif k.cutting:
					k.cut_view.skip()                 # a tap skips the cut, as in play
				elif k.cascading:
					k.cascade.skip()
				elif k.rd.phase == "keep" and not k.rd.over and not k.dealing:
					if rng.randf() < 0.15:
						_check_save(f, "keep")
					_keep_by_hand(k)
					if not k.keep_button.disabled:   # Keep lights once four are chosen
						stats.deals += 1
						k._on_button()
				elif k.keep_button.disabled:
					continue                          # a player can't press it now
				else:
					if rng.randf() < 0.1:
						_check_save(f, "counted")
					k._on_button()
			"round_end":
				stats.rounds += 1
				if rng.randf() < 0.3:
					_check_save(f, "round_end")
				if f.buttons.has("free_next"):
					f.buttons["free_next"].emit_signal("pressed")   # free mode: the end card
				elif f.buttons.has("shop"):
					f.buttons["shop"].emit_signal("pressed")
				else:
					return true                     # the run is over
			"shop":
				await _shop(f)
			"run_won":
				stats.won += 1
				return true
			_:
				return true                         # front door: the run ended
	ok(false, "run %d stalled on %s after %d steps" % [i, f.screen, steps])
	return false


## Every node path in the tree, to a file (to name a leak when there is one).
func _paths(file: String) -> void:
	var fa := FileAccess.open(file, FileAccess.WRITE)
	for c in root.find_children("*", "", true, false):
		fa.store_line("%s %s" % [String(root.get_path_to(c)).split("/").slice(0, 3), c.get_class()])
	fa.close()


func _go() -> void:
	var n := int(OS.get_environment("SOAK_RUNS")) if OS.get_environment("SOAK_RUNS") != "" else 200
	strong = OS.get_environment("SOAK_STRONG") == "1"
	free_mode = OS.get_environment("SOAK_FREE") == "1"
	if free_mode:
		Entitlement.force = false
	rng.seed = 20261020
	Achv.persist = false
	Achv.save_store({"__v": 3, "drag_hint": 1, "tutorial": 1})
	Achv.grant_system("the_play")
	Sound.set_muted(true)
	MeldSprite.reduce_motion = true          # no travel: fewer frames per step
	root.size = Vector2i(720, 1560)
	for i in 5:
		await process_frame
	var f: RunFlow = load("res://scenes/run_flow.tscn").instantiate()
	root.add_child(f)
	var t0 := Time.get_ticks_msec()
	var nodes0 := 0.0
	var orphans0 := 0.0
	for i in n:
		if await _run(f, i):
			stats.runs += 1
		var key := "act %d" % (reach / 10)
		depth[key] = int(depth.get(key, 0)) + 1
		if i == 0:
			# the baseline after one run, with the flow freed: first-use
			# singletons (Sound's players) exist by then; growth after it is a leak
			f.queue_free()
			for w in 5:
				await process_frame
			nodes0 = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
			orphans0 = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
			_paths("/tmp/soak_nodes0.txt")
			f = load("res://scenes/run_flow.tscn").instantiate()
			root.add_child(f)
		if i % 25 == 24:
			print("soak: %d runs, %.0f s" % [i + 1, (Time.get_ticks_msec() - t0) / 1000.0])
	f.queue_free()
	for i in 10:
		await process_frame
	var nodes1 := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	_paths("/tmp/soak_nodes1.txt")
	if Performance.get_monitor(Performance.OBJECT_NODE_COUNT) > nodes0:
		for c in root.get_children():
			print("left in the tree: %s (%s) %d below" % [c.name, c.get_class(), c.get_child_count()])
	var orphans1 := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	ok(stats.runs == n, "%d of %d runs finished" % [stats.runs, n])
	ok(nodes1 <= nodes0, "nodes left behind: %d -> %d" % [nodes0, nodes1])
	ok(orphans1 <= orphans0, "orphan nodes left behind: %d -> %d" % [orphans0, orphans1])
	ok(stats.saves_checked >= n, "only %d saves round-tripped" % stats.saves_checked)
	for kind in ["intro", "keep", "counted", "peg_mid", "peg_over", "round_end", "shop"]:
		ok(save_kinds.get(kind, 0) > 0, "no save checked at %s" % kind)
	if free_mode:
		ok(max_act <= Entitlement.FREE_LAST_ACT, "free mode: a round started in act %d" % max_act)
		ok(free_cards > 0, "free mode: no run reached the end card")
		print("soak free mode: %d end cards, furthest act %d" % [free_cards, max_act])
		Entitlement.force = null
	if strong and not free_mode:
		var deep := 0
		for k in depth:
			if int(String(k).get_slice(" ", 1)) >= 3:
				deep += depth[k]
		ok(deep * 2 >= n and bosses > 0, "strong player: only %d of %d runs reached act 3 (%d Spoiler rounds)" % [deep, n, bosses])
	print("soak: %s" % [stats])
	print("soak saves by moment: %s" % [save_kinds])
	print("soak depth (furthest act reached, runs): %s; Spoiler rounds played: %d; runs won: %d" % [depth, bosses, stats.won])
	print("soak_test: %d checks, %d fails" % [checks, fails])
	quit(1 if fails > 0 else 0)
