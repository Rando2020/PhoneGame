extends SceneTree
## The guided first round, by click. On a fresh save PLAY reads "first round"
## and starts Thump on First Street with no intro; the run must equal the JS's
## (fixture selectui, save 0, path run/1/thump: same unseeded stream). The six
## beats must come at the web's moments (deal at once; kept 0.12 s after the
## fourth card; cut 0.2 s after Keep; counted, target, done 0.7, 2.6, 5.2 s
## after the count lands), each once, never one behind the last. "PLAY ON"
## ends coaching and opens the roads; "Skip coaching" ends it and the round
## plays on to its end. Both set the save's guided flag.
##   godot --headless --path godot --script res://tests/guide_test.gd
const SIZE := Vector2i(720, 1280)
const SCALE := 4.0
var checks := 0
var fails := 0


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
	await _click(c.get_global_rect().get_center())


## Game seconds since `t0` (the clock runs SCALE times fast).
func since(t0: int) -> float:
	return (Time.get_ticks_msec() - t0) / 1000.0 * SCALE


func _wait(cond: Callable, frames := 3000) -> bool:
	for i in frames:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func card_out(c) -> Dictionary:
	var o := {"rank": c.rank, "suit": c.suit}
	for k in ["enh", "rank2", "suit2"]:
		if c.has(k) and c[k] != null:
			o[k] = c[k]
	return o


func start(fx) -> RunFlow:
	Achv.save_store({"__v": 3})
	var f: RunFlow = load("res://scenes/run_flow.tscn").instantiate()
	root.add_child(f)
	await process_frame
	ok(f.front.buttons["play"].text.contains("first round"), "fresh save: PLAY label '%s'" % f.front.buttons["play"].text)
	var R = null
	for r in fx.selectui[0].runs:
		if r.path[0] == "run" and int(r.path[1]) == 1 and int(r.path[2]) == 1:
			R = r
	JS.unseeded = JsRng.new(R.unseeded)
	await _press(f.front.buttons["play"])
	ok(f.screen == "round" and f.coach != null, "PLAY didn't start the guided round (screen %s)" % f.screen)
	var w: Array = f.run.wager_at.keys()
	w.sort()
	var got := {"meld": f.run.meldling, "street": f.run.street.id, "trial": null, "endless": f.run.endless,
		"seed": f.run.seed, "cards": f.run.cards.map(card_out), "bosses": f.run.boss_plan.map(func(b): return b.id), "wagers": w}
	var d: String = load("res://tests/parity_test.gd").diff(R.run, got)
	ok(d == "", "guided run differs from the web's: %s" % d)
	return f


## A first run, guided coaching already skipped (so plain rounds), seeded.
func start_plain() -> RunFlow:
	Achv.save_store({"__v": 3, "guided": 1})
	var f: RunFlow = load("res://scenes/run_flow.tscn").instantiate()
	root.add_child(f)
	await process_frame
	f.start_run(CribRun.new("thump", Meta.STREETS[0], null, 4141))
	await process_frame
	f._on_deal()
	await process_frame
	return f


func pick_four(f: RunFlow) -> void:
	await _wait(func(): return not f.keep.dealing)
	for k in 4:
		await _press(f.keep.hand._views[k])


func _go() -> void:
	var real_starters = Achv.starters
	Achv.starters = []        # parts 1 to 3 drive the keep screen without The Play
	var fh := FileAccess.open("res://tests/fixtures/parity.json", FileAccess.READ)
	var fx = load("res://tests/parity_test.gd").norm(JSON.parse_string(fh.get_as_text()))
	Achv.persist = false
	root.size = SIZE
	Engine.time_scale = SCALE
	# ---- 1. the whole coached deal, then PLAY ON
	var f: RunFlow = await start(fx)
	var c: GuideCoach = f.coach
	ok(c.shown == ["deal"] and c.box != null, "deal beat not shown at once: %s" % [c.shown])
	await _press(c.got_button)      # Got it: closes, coaching stays on
	ok(c.box == null and c.on, "Got it should close the box and keep coaching")
	await _wait(func(): return not f.keep.dealing)
	for k in 3:
		await _press(f.keep.hand._views[k])
	await _wait(func(): return false, 20)
	ok(c.shown == ["deal"], "kept beat before the fourth card: %s" % [c.shown])
	var t0 := Time.get_ticks_msec()
	await _press(f.keep.hand._views[3])
	await _wait(func(): return c.shown.size() >= 2)
	var t_kept := since(t0)
	ok(c.shown == ["deal", "kept"], "after four cards: %s" % [c.shown])
	ok(t_kept >= 0.1 and t_kept < 0.5, "kept came %.2f s after the fourth card (web 0.12)" % t_kept)
	await _press(c.got_button)
	t0 = Time.get_ticks_msec()
	await _press(f.keep.keep_button)
	await _wait(func(): return c.shown.size() >= 3)
	var t_cut := since(t0)
	ok(c.shown.back() == "cut" and t_cut >= 0.15 and t_cut < 0.6, "cut beat %s at %.2f s (web 0.2)" % [c.shown.back(), t_cut])
	await _press(c.got_button)
	# skip the ceremony and the count; the landing starts the last three beats
	for t in 3:
		if f.keep.cutting or f.keep.cascading:
			await _click(Vector2(SIZE.x / 2.0, SIZE.y * 0.55))
	await _wait(func(): return not f.keep.cutting and not f.keep.cascading)
	t0 = Time.get_ticks_msec()
	var at := {}
	for b in ["counted", "target", "done"]:
		await _wait(func(): return c.shown.has(b), 4000)
		at[b] = since(t0)
	ok(c.shown == ["deal", "kept", "cut", "counted", "target", "done"], "beat order %s" % [c.shown])
	ok(absf(at.counted - 0.7) < 0.35 and absf(at.target - 2.6) < 0.35 and absf(at.done - 5.2) < 0.35,
		"count beats at %.2f / %.2f / %.2f s (web 0.7 / 2.6 / 5.2)" % [at.counted, at.target, at.done])
	ok(c.got_button.text == "PLAY ON", "last beat button '%s'" % c.got_button.text)
	await _press(c.got_button)
	ok(f.screen == "front" and f.cb.step == "road", "PLAY ON should open the roads (screen %s, step %s)" % [f.screen, f.cb.step])
	ok(JS.truthy(Achv.load_store().get("guided")), "PLAY ON didn't set guided")
	f.show_front_door("title")
	await process_frame
	ok(f.front.buttons["play"].text == "PLAY", "after coaching, PLAY still says '%s'" % f.front.buttons["play"].text)
	f.queue_free()
	await process_frame
	# ---- 2. Skip coaching: no more beats; the round plays to its end
	f = await start(fx)
	c = f.coach
	await _press(c.skip_button)
	ok(not c.on and c.box == null and JS.truthy(Achv.load_store().get("guided")), "Skip coaching didn't end coaching")
	ok(f._toast != null and f._toast.text == "Coaching off.", "no 'Coaching off.' flash")
	var deals := 0
	while f.screen == "round" and deals < 12:
		await _wait(func(): return f.keep.rd.over or (f.keep.rd.phase == "keep" and not f.keep.dealing))
		if f.keep.rd.over:
			break
		await pick_four(f)
		await _press(f.keep.keep_button)
		for t in 3:
			if f.keep.cutting or f.keep.cascading:
				await _click(Vector2(SIZE.x / 2.0, SIZE.y * 0.55))
		await _wait(func(): return not f.keep.cutting and not f.keep.cascading)
		await _wait(func(): return false, 30)
		deals += 1
		if not f.keep.rd.over:
			await _press(f.keep.keep_button)
	ok(c.shown == ["deal"], "beats after Skip coaching: %s" % [c.shown])   # read before the page (and coach) is freed
	await _press(f.keep.keep_button)     # Continue
	await _wait(func(): return f.screen == "round_end")
	ok(not is_instance_valid(c), "the coach outlived its round")
	ok(f.screen == "round_end" and deals >= 1, "the skipped round didn't play to its end (%s after %d deals)" % [f.screen, deals])
	f.queue_free()
	await process_frame
	# ---- 4. a first run with The Play on (pass 14): its coach line shows on
	# the first Play only, by tap, saved once; the round still plays to its end
	Achv.starters = real_starters
	f = await start_plain()
	ok(Achv.has_system("the_play"), "The Play isn't on in a first run")
	var plays := 0
	var hints := []
	deals = 0
	while f.screen == "round" and f.keep != null and deals < 12:
		await _wait(func(): return f.keep.peg_view != null or (f.keep.rd.over and not f.keep.peg_pending) or (f.keep.rd.phase == "keep" and not f.keep.dealing))
		if f.keep.peg_view != null:
			var pv: PegView = f.keep.peg_view
			hints.append(pv.hint_label.text if pv.hint_label != null else "")
			while not pv.s.play.over:
				await _wait(func(): return pv.s.play.over or (not pv.waiting and pv.s.play.turn == "you" and pv.s.play.can_play(pv.s.play.mine)), 600)
				if pv.s.play.over:
					break
				var i := -1
				for k in pv.s.play.mine.size():
					if pv.s.play.playable(k):
						i = k
						break
				if i < 0:
					break
				await _press(pv.hand_views[i])
				await _wait(func(): return pv.waiting or pv.s.play.over, 60)
			plays += 1
			await _wait(func(): return pv.continue_button != null, 600)
			await _press(pv.continue_button)
			await _wait(func(): return f.keep == null or f.keep.peg_view == null, 300)
			continue
		if f.keep.rd.over:
			break
		await pick_four(f)
		await _press(f.keep.keep_button)
		for t in 3:
			if f.keep.cutting or f.keep.cascading:
				await _click(Vector2(SIZE.x / 2.0, SIZE.y * 0.55))
		await _wait(func(): return not f.keep.cutting and not f.keep.cascading)
		await _wait(func(): return false, 30)
		deals += 1
		if f.keep.peg_pending or not f.keep.rd.over:
			await _press(f.keep.keep_button)      # opens The Play when owed, else the next deal
	ok(plays >= 1, "no Play in a first run with it on (%d deals)" % deals)
	ok(hints.size() >= 1 and hints[0] == PegView.PLAY_HINT, "first Play's hint: %s" % [hints.slice(0, 1)])
	ok(hints.size() < 2 or hints[1] != PegView.PLAY_HINT, "the coach line came back: %s" % [hints])
	ok(PegView.play_hint_seen(), "the Play's coach line wasn't saved")
	if f.screen == "round" and f.keep != null and f.keep.rd.over:
		await _press(f.keep.keep_button)
	print("first run with The Play: %d deals, %d Plays, hints %s" % [deals, plays, hints])
	await _wait(func(): return f.screen == "round_end", 600)
	ok(f.screen == "round_end", "the first run's round didn't reach its end (%s, %d deals, %d plays)" % [f.screen, deals, plays])
	f.queue_free()
	await process_frame
	# ---- 3. a beat behind the last one shown is skipped (web: i < Guide.beat)
	var g := GuideCoach.new()
	root.add_child(g)
	g.size = Vector2(SIZE)
	g.show_beat("cut")
	g.show_beat("kept")
	g.show_beat("cut")
	g.show_beat("target")
	ok(g.shown == ["cut", "target"], "order rule: %s" % [g.shown])
	g.queue_free()
	Engine.time_scale = 1.0
	print("guide checks: %d, failures: %d" % [checks, fails])
	var good := fails == 0 and checks >= 20
	print("GUIDE OK" if good else "GUIDE FAILED")
	quit(0 if good else 1)
