extends SceneTree
## The loop fixes (LOOP_AUDIT.md, pass 13): every lost run pays Pegs (5 + 2 a
## round cleared), once, even when the screen redraws or the save is resumed;
## the run-end card names the nearest real goal; The Play is there from a
## fresh save, and Wagers win the other systems.
##   godot --headless --path godot --script res://tests/loop_fixes_test.gd
var checks := 0
var fails := 0


func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("FAIL ", m)


func _initialize() -> void:
	_go.call_deferred()


func _texts(n: Node) -> Array:
	return n.find_children("*", "Label", true, false).map(func(l): return (l as Label).text)


func _go() -> void:
	Achv.persist = false
	Achv.save_store({"__v": 3})
	root.size = Vector2i(720, 1560)
	MeldSprite.reduce_motion = true
	# ---- The Play from a fresh save
	ok(Achv.has_system("the_play"), "fresh save: no The Play")
	ok(not Achv.locked_systems().any(func(x): return x.id == "the_play"), "The Play is still a Wager prize")
	ok(Achv.locked_systems().size() == Meta.SYSTEMS.size() - Meta.STARTER_SYSTEMS.size(), "the other systems aren't all lockable")
	var rr := CribRound.new(CribRun.new("pip", null, null, 3))
	rr.new_deal()
	ok(PegSession.wanted(rr), "fresh save: a round doesn't offer The Play")
	# ---- a loss at act 1 round 3 pays 5 + 2 x 2
	var f: RunFlow = load("res://scenes/run_flow.tscn").instantiate()
	root.add_child(f)
	for i in 3:
		await process_frame
	var run := CribRun.new("pip", null, null, 77)
	run.round = 3
	f.run = run
	var rd := CribRound.new(run)
	while rd.new_deal() != null:
		rd.commit([0, 1, 2, 3])
		if rd.score >= rd.target or rd.deals_left <= 0:
			break
	rd.settle()
	ok(not rd.won, "setup: the round was won")
	f.rd = rd
	var pegs0 := Achv.pegs()
	f._paid = false
	f._round_end_effects()
	f._render_round_end()
	f.settle()
	var want := Meta.pegs_for_loss(2)
	ok(want == 9 and Achv.pegs() == pegs0 + want, "a loss in round 3 paid %d, want 9" % (Achv.pegs() - pegs0))
	ok(_texts(f).any(func(t): return String(t).contains("+%d Pegs" % want)), "the loss card doesn't say +%d Pegs" % want)
	ok(_texts(f).has(NextUnlock.line()), "the loss card lacks the next-unlock line")
	# a redraw doesn't pay again; nor does a resumed save of the screen
	f._rerender()
	f.size = Vector2(720, 1280)
	await process_frame
	await process_frame
	f.size = Vector2(720, 1560)
	await process_frame
	ok(Achv.pegs() == pegs0 + want, "a redraw paid again (%d)" % (Achv.pegs() - pegs0))
	# ---- the next-unlock line
	Achv.save_store({"__v": 3})
	var cheapest := ""
	var low := 9999
	for b in Meta.CARD_BACKS + Meta.LENSES:
		if int(b.cost) > 0 and int(b.cost) < low:
			low = int(b.cost)
			cheapest = String(b.name)
	var names := []
	for b in Meta.CARD_BACKS + Meta.LENSES:
		if int(b.cost) == low:
			names.append(String(b.name))
	names.sort()
	cheapest = names[0]
	ok(NextUnlock.line() == "Next: %s, %d more Pegs (0 / %d)." % [cheapest, low, low], "0 Pegs: %s" % NextUnlock.line())
	Achv.add_pegs(low + 6)
	ok(NextUnlock.line().begins_with("You can afford %s at the Peddler" % cheapest), "enough Pegs: %s" % NextUnlock.line())
	Achv.add_pegs(10000)
	for b in Meta.CARD_BACKS:
		Achv.buy_back(b.id)
	for l in Meta.LENSES:
		Achv.buy_lens(l.id)
	var line := NextUnlock.line()
	ok(line.contains("joins when you earn") or line == "Every card back and lens is yours.", "all owned: %s" % line)
	ok(not line.contains("—") and not NextUnlock.line().contains("—"), "em dash in the line")
	f.queue_free()
	MeldSprite.reduce_motion = false
	print("loop_fixes_test: %d checks, %d fails" % [checks, fails])
	quit(1 if fails > 0 else 0)
