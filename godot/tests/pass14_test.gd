extends SceneTree
## Pass 14, items 3 to 5, presentation only:
##  - count speed: 1x on a first run, 2x from the second, a saved choice wins
##    (from Settings or the in-count button), and a run start applies it
##  - "Needs N more" on a count that leaves the target unmet (the exact gap),
##    never on one that meets it
##  - the cut's sound climbs with what the cut added (CUT_STEPS)
##  - first-time celebrations: first act (with its Spoiler), first lone
##    Spoiler, first Peddler buy; each once ever, saved; no draw touched
##   godot --headless --path godot --script res://tests/pass14_test.gd
var checks := 0
var fails := 0


func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("FAIL ", m)


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	Achv.persist = false
	root.size = Vector2i(720, 1560)
	# ---- count speed
	ok(Menus.speed_default({}) == 0, "first run: 1x")
	ok(Menus.speed_default({"history": [{"deck": "pip"}]}) == 1, "second run: 2x")
	ok(Menus.speed_default({"history": [{}], "cascade_speed": 0}) == 0, "a saved 1x wins")
	ok(Menus.speed_default({"cascade_speed": 2}) == 2, "a saved 4x wins on a first run too")
	Achv.save_store({"__v": 3, "guided": 1, "history": [{"deck": "pip"}]})
	var f: RunFlow = load("res://scenes/run_flow.tscn").instantiate()
	root.add_child(f)
	await process_frame
	CascadeView.speed_i = 0
	f.start_run(CribRun.new("pip", Meta.STREETS[0], null, 99))
	ok(CascadeView.speed_i == 1, "a run start after one run: speed %d" % CascadeView.speed_i)
	var cv := CascadeView.new()
	f.add_child(cv)
	await process_frame
	cv.speed_button.pressed.emit()
	ok(int(Achv.load_store().get("cascade_speed", -1)) == 2, "the in-count button's choice is saved")
	f.start_run(CribRun.new("pip", Meta.STREETS[0], null, 98))
	ok(CascadeView.speed_i == 2, "the next run keeps the in-count choice: %d" % CascadeView.speed_i)
	cv.queue_free()

	# ---- "Needs N more", and the cut's pitch
	var need_lines := 0
	var met := 0
	var cut_beats := 0
	for k in 120:
		var run := CribRun.new(CribData.DECKS.keys()[k % 4], Meta.STREETS[0], null, 3000 + k)
		var rd := CribRound.new(run)
		for d in 3:
			if rd.new_deal() == null:
				break
			var best := rd.best_keep_ev()
			var res = rd.commit(best.idx)
			var plan := CascadePlan.build(res, rd)
			var gap := int(rd.target - (res.scoreBefore + res.total))
			var needs: Array = plan.lines.filter(func(l): return String(l.text).begins_with("Needs "))
			if gap > 0:
				need_lines += 1
				ok(needs.size() == 1 and needs[0].text == "Needs %d more" % gap, "gap %d: %s" % [gap, needs])
			else:
				met += 1
				ok(needs.is_empty(), "target met but %s" % [needs])
			for b in plan.beats:
				if b.kind == "cut":
					cut_beats += 1
					ok(int(b.get("step", -1)) == CascadePlan.cut_step(float(res.cutGain)), "cut beat step")
			if rd.over:
				break
	ok(need_lines >= 50 and met >= 5, "cases: %d short, %d met" % [need_lines, met])
	ok(cut_beats >= 10, "cut beats seen: %d" % cut_beats)
	ok(CascadePlan.cut_step(2) == 0 and CascadePlan.cut_step(4) == 2 and CascadePlan.cut_step(11) == 4 and CascadePlan.cut_step(30) == 7, "cut steps")
	var view := CascadeView.new()
	root.add_child(view)
	await process_frame
	Sound.set_muted(false)
	Sound.set_volume(1.0)
	for step in [0, 4, 7]:
		Sound.log.clear()
		view._begin_beat({"kind": "cut", "label": "From the cut", "value": "+9", "number": 9, "ms": 420,
			"cards": [], "mult_line": "", "step": step})
		var cuts: Array = Sound.log.filter(func(e): return e[0] == "line_cut")
		ok(cuts.size() == 1 and absf(cuts[0][2] - Sound.semi(step)) < 0.0001, "cut sound at step %d: %s" % [step, cuts])
	view.queue_free()

	# ---- the won round end's "Next" line: the real next target
	for st in [Meta.STREETS[0], Meta.STREETS[1]]:
		for rr in range(1, CribData.ROUNDS + 1):
			var nr := CribRun.new("pip", st, null, 40 + rr)
			nr.act = 2
			nr.round = rr
			var later := CribRun.new("pip", st, null, 40 + rr)
			later.act = 2 + (1 if rr == CribData.ROUNDS else 0)
			later.round = 1 if rr == CribData.ROUNDS else rr + 1
			ok(nr.next_target() == later.target(), "next target %d-%d: %d vs %d" % [nr.act, rr, nr.next_target(), later.target()])
			var nd := CribRound.new(nr)
			nd.won = true
			f.run = nr
			f.rd = nd
			f._paid = true
			f._render_round_end()
			var want := "Next: %s, target %d" % ["Act 3" if rr == CribData.ROUNDS else ("the Spoiler" if rr + 1 == CribData.ROUNDS else "Round %d" % (rr + 1)), later.target()]
			var hit := f.find_children("*", "Label", true, false).filter(func(l): return l.text == want)
			ok(hit.size() == 1, "round end %d-%d: no '%s'" % [nr.act, rr, want])
	# ---- first-time celebrations
	Achv.save_store({"__v": 3, "guided": 1})
	var r0 := JS.unseeded.next() if JS.unseeded != null else 0.0
	JS.unseeded = JsRng.new(77)
	var probe := JsRng.new(77)
	f.run = CribRun.new("pip", Meta.STREETS[0], null, 5)
	f.run.round = CribData.ROUNDS
	f.rd = CribRound.new(f.run)
	f.rd.won = true
	f._celebrate_round()
	ok(f.deed_toast.celebrated == ["act"], "act cleared: %s" % [f.deed_toast.celebrated])
	ok(Firsts.seen("act") and Firsts.seen("spoiler"), "the act's Spoiler is claimed with it")
	f._celebrate_round()
	ok(f.deed_toast.celebrated == ["act"], "a second act cleared: %s" % [f.deed_toast.celebrated])
	# a lone Spoiler first (Third Street's extra one, round 2), act not yet seen
	Achv.save_store({"__v": 3, "guided": 1})
	f.run = CribRun.new("pip", Meta.STREETS[2], null, 6)
	f.run.round = CribData.ROUNDS - 1
	ok(f.run.is_boss(), "Third Street round %d is a Spoiler" % f.run.round)
	f.rd = CribRound.new(f.run)
	f.rd.won = true
	f._celebrate_round()
	ok(f.deed_toast.celebrated.back() == "spoiler" and not Firsts.seen("act"), "lone Spoiler: %s" % [f.deed_toast.celebrated])
	f.rd.won = false
	f.run.round = CribData.ROUNDS
	Achv.save_store({"__v": 3})
	var n0: int = f.deed_toast.celebrated.size()
	f._celebrate_round()
	ok(f.deed_toast.celebrated.size() == n0, "a lost round celebrates nothing")
	# Peddler
	Achv.save_store({"__v": 3, "guided": 1, "pegs": 200})
	f.show_front_door("title")
	await process_frame
	f.front.go("peddler")
	await process_frame
	var n1: int = f.deed_toast.celebrated.size()
	f.front._tap_back("crimson")
	await process_frame
	ok(f.deed_toast.celebrated.size() == n1 + 1 and f.deed_toast.celebrated.back() == "peddler", "first Peddler buy: %s" % [f.deed_toast.celebrated])
	f.front._tap_back("moss")
	await process_frame
	ok(f.deed_toast.celebrated.size() == n1 + 1, "a second buy celebrates nothing")
	ok(JS.unseeded.next() == probe.next(), "celebrations drew from JS.unseeded")
	ok(Firsts.claim("nope") == false, "unknown ids are refused")
	f.queue_free()
	await process_frame
	print("pass14_test: %d checks, %d fails" % [checks, fails])
	quit(1 if fails > 0 else 0)
