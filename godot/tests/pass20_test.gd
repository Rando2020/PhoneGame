extends SceneTree
## Pass 20: the Shortage (both engines; parity covers the web side), and sound.
##  - the tally: run.cat_points = the run's kept hands' points by category
##  - shortage(): round 2 of an act only, never the run's first round, a
##    Spoiler, a Wager or the Long Count; the category is the tally's highest
##    (ties fifteen, pair, run, flush); that round has no twist and no twist
##    target; its rules halve that category and nothing else
##  - shown ahead: the intro line, the keep status, the round end's Next line
##  - sound: the first-purchase card plays charm_new; a Gallery tab plays tab
##   godot --headless --path godot --script res://tests/pass20_test.gd
var checks := 0
var fails := 0


func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		if fails <= 30:
			print("FAIL ", m)


func _initialize() -> void:
	_go.call_deferred()


func _labels(n: Node) -> Array:
	return n.find_children("*", "Label", true, false).map(func(l): return String(l.text))


func _go() -> void:
	Achv.persist = false
	Achv.save_store({"__v": 3, "guided": 1})
	root.size = Vector2i(720, 1560)
	# ---- the tally
	for sd in range(1, 41):
		var run := CribRun.new(CribData.DECKS.keys()[sd % 4], Meta.STREETS[0], null, 8000 + sd)
		var want := {"fifteen": 0, "pair": 0, "run": 0, "flush": 0}
		var rd := CribRound.new(run)
		while rd.new_deal() != null:
			var res = rd.commit(rd.best_keep_ev().idx)
			for e in res.events:
				if want.has(e.kind):
					want[e.kind] += e.points
			if rd.score >= rd.target or rd.deals_left <= 0:
				break
		ok(run.cat_points == want, "seed %d tally %s vs %s" % [sd, run.cat_points, want])

	# ---- when it applies
	var r := CribRun.new("pip", Meta.STREETS[0], null, 31)
	r.wager_at = {}
	r.cat_points = {"fifteen": 10, "pair": 30, "run": 4, "flush": 0}
	r.act = 1
	r.round = 1
	ok(r.shortage() == null, "round 1 has no Shortage")
	r.round = 2
	ok(r.shortage() == "pair", "round 2: pairs short, got %s" % r.shortage())
	r.act = 2
	r.round = 1
	ok(r.shortage() == null, "act 2 round 1 has no Shortage (round 2 only)")
	r.act = 1
	r.round = 2
	ok(r.twist() == null, "a Shortage round has no twist")
	ok(r.rules().catScale == {"pair": CribData.SHORTAGE_SCALE}, "rules: %s" % [r.rules().get("catScale")])
	var plain := CribRun.new("pip", Meta.STREETS[0], null, 31)
	plain.twist_plan = {}
	plain.round = 2
	ok(r.target() == plain.target(), "no twist target on a Shortage round: %d vs %d" % [r.target(), plain.target()])
	r.round = CribData.ROUNDS
	ok(r.shortage() == null, "a Spoiler round has no Shortage")
	r.round = 2
	r.wager_at = {"1-2": true}
	ok(r.shortage() == null, "a Wager has no Shortage")
	r.wager_at = {}
	r.act = 2
	r.round = 2
	ok(r.shortage() == "pair", "act 2 round 2 too")
	r.twist_plan.erase("2-2")
	ok(r.shortage() == null, "no slot, no Shortage")
	var en := CribRun.new("pip", Meta.STREETS[0], null, 31)
	en.enter_endless()
	en.endless_round = 1
	ok(en.shortage() == null, "the Long Count has no Shortage")
	var ties := CribRun.new("pip", Meta.STREETS[0], null, 31)
	ties.wager_at = {}
	ties.round = 2
	ties.cat_points = {"fifteen": 0, "pair": 0, "run": 0, "flush": 0}
	ok(ties.shortage() == "fifteen", "all zero: fifteens (the fixed order)")
	ties.cat_points = {"fifteen": 5, "pair": 9, "run": 9, "flush": 2}
	ok(ties.shortage() == "pair", "a tie: pairs before runs")

	# ---- it halves that category and nothing else
	var hand := [{"rank": 5, "suit": "H"}, {"rank": 5, "suit": "S"}, {"rank": 6, "suit": "C"}, {"rank": 4, "suit": "D"}]
	var cut := {"rank": 10, "suit": "H"}
	var base := Cribbage.count_hand(hand, cut, false, {})
	for cat in CribData.SHORTAGE_CATS:
		var sc: float = [0.5, 0.25][CribData.SHORTAGE_CATS.find(cat) % 2]   # the scale given, not a fixed half
		var half := Cribbage.count_hand(hand, cut, false, {"catScale": {cat: sc}})
		var ok_all := true
		for i in base.events.size():
			var e0 = base.events[i]
			var e1 = half.events[i]
			ok_all = ok_all and absf(e1.points - (e0.points * sc if e0.kind == cat else e0.points)) < 1e-9
		ok(ok_all, "catScale %s scaled the wrong events" % cat)

	# ---- shown ahead
	var f: RunFlow = load("res://scenes/run_flow.tscn").instantiate()
	root.add_child(f)
	await process_frame
	var sr := CribRun.new("pip", Meta.STREETS[0], null, 31)
	sr.wager_at = {}
	sr.cat_points = {"fifteen": 3, "pair": 1, "run": 12, "flush": 0}
	sr.round = 2
	f.start_run(sr)
	await process_frame
	var line := "SHORTAGE: Runs score half this round, your best so far. %d deals." % (CribData.DEALS + sr.rules().dealBonus)
	ok(_labels(f).has(line), "intro: no '%s'" % line)
	ok(not _labels(f).any(func(t): return t.begins_with("Score ")), "the Shortage line replaces 'Score N in D deals'")
	f._on_deal()
	for i in 40:
		await process_frame
	ok(f.keep.status_label.text.contains("|  Short: Runs"), "keep status: '%s'" % f.keep.status_label.text)
	# a round 1 end: Next names the coming Shortage
	var r1 := CribRun.new("pip", Meta.STREETS[0], null, 31)
	r1.wager_at = {}
	r1.cat_points = {"fifteen": 3, "pair": 8, "run": 1, "flush": 0}
	r1.round = 1
	var nd := CribRound.new(r1)
	nd.won = true
	f.run = r1
	f.rd = nd
	f._paid = true
	f._render_round_end()
	await process_frame
	var nxt := "Next: Round 2, target %d  ·  Shortage: Pairs" % r1.next_target()
	ok(_labels(f).has(nxt), "round end: no '%s' in %s" % [nxt, _labels(f).filter(func(t): return t.begins_with("Next"))])

	# ---- sound
	Sound.set_muted(false)
	Sound.set_volume(1.0)
	Sound.log.clear()
	f.move_child(f.deed_toast, -1)
	f.deed_toast.queue.clear()
	f.deed_toast.busy = false
	f.deed_toast.celebrate_charm(CribData.charm_by_id("keystone2"))
	ok(Sound.log.any(func(e): return e[0] == "charm_new"), "the first-purchase card plays charm_new: %s" % [Sound.log])
	ok(not Sound.log.any(func(e): return e[0] == "chord_t-max"), "and not the generic first chord")
	f.show_front_door("title")
	f.settle()
	f.front.go("gallery")
	f.settle()
	await process_frame
	Sound.log.clear()
	(f.front.buttons["tab_cards"] as Button).pressed.emit()
	ok(Sound.log.any(func(e): return e[0] == "tab"), "a Gallery tab plays tab")
	ok(Sound.exists("charm_new") and Sound.exists("tab"), "the two cues exist")
	f.queue_free()
	await process_frame
	print("pass20_test: %d checks, %d fails" % [checks, fails])
	quit(1 if fails > 0 else 0)
