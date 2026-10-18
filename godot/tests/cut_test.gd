extends SceneTree
## The cut ceremony. Part A: tiers computed the web UI's way match the JS for
## the same cuts (fixture group cutui). Part B: CutView played in full and
## skipped at any point lands on the same end state.
##   godot --headless --path godot --script res://tests/cut_test.gd
var checks := 0
var fails := 0

func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		if fails <= 8:
			print("FAIL ", m)

func _initialize() -> void:
	_go.call_deferred()

func _go() -> void:
	var f := FileAccess.open("res://tests/fixtures/parity.json", FileAccess.READ)
	var fx = load("res://tests/parity_test.gd").norm(JSON.parse_string(f.get_as_text()))
	Achv.persist = false
	# ---- Part A: same cuts, same tiers as the JS
	var by_case := {}
	for c in fx.cutui:
		var k := "%d" % c.seed
		if not by_case.has(k):
			by_case[k] = []
		by_case[k].append(c)
	var tiers_seen := {}
	for k in by_case:
		var cases: Array = by_case[k]
		var c0 = cases[0]
		Achv.save_store({"__v": 3})
		JS.unseeded = JsRng.new(fx.unseeded)
		var run := CribRun.new(c0.meld, null, null, c0.seed)
		for id in c0.build:
			run.charms.append(CribData.charm_by_id(id))
		var rd := CribRound.new(run)
		for c in cases:
			if rd.new_deal() == null:
				ok(false, "seed %s: deal %d missing" % [k, c.deal])
				break
			ok((rd.starter != null) == c.knew, "seed %s deal %d: foresight state" % [k, c.deal])
			var idx: Array = rd.best_keep_ev().idx
			var kept: Array = idx.map(func(i): return rd.dealt[i])
			var pre: Array = rd.stock.duplicate()
			rd.commit(idx)
			var q := CutPlan.quality_like_web(rd, kept, pre)
			var got := {"tier": q.tier, "rank": q.rank, "of": q.of, "gain": q.gain,
				"starter": {"rank": q.starter.rank, "suit": q.starter.suit}}
			var want := {"tier": c.tier, "rank": c.rank, "of": c.of, "gain": c.gain,
				"starter": {"rank": c.starter.rank, "suit": c.starter.suit}}
			ok(load("res://tests/parity_test.gd").diff(want, got) == "", "seed %s deal %d: %s vs JS %s" % [k, c.deal, got, want])
			var p := CutPlan.build(q)
			ok(p.word == CutPlan.TIERS[c.tier].word and is_equal_approx(p.roll, CutPlan.TIERS[c.tier].roll / 1000.0), "seed %s: plan for %s" % [k, c.tier])
			tiers_seen[c.tier] = true
	ok(tiers_seen.size() == 5, "only tiers %s exercised" % [tiers_seen.keys()])
	var a_checks := checks
	# ---- Part B: full play and skips land on the same state
	root.size = Vector2i(720, 1280)
	Engine.time_scale = 10.0
	var v := CutView.new()
	v.size = Vector2(600, 300)
	root.add_child(v)
	await process_frame
	var starter := {"rank": 11, "suit": "H", "enh": "gilded"}
	for tier in CutPlan.TIERS:
		var q := {"tier": tier, "gain": 6 if tier != "cold" else 0, "rank": 3, "of": 40, "starter": starter}
		var p := CutPlan.build(q)
		var finals := []
		for mode in ["full", "skip_now", "skip_mid_roll", "skip_in_hold", "skip_twice"]:
			var fin := [0]
			var cb := func(): fin[0] += 1
			v.finished.connect(cb)
			v.play(p)
			match mode:
				"skip_now":
					v.skip()
				"skip_mid_roll":
					await create_timer(p.roll * 0.5).timeout
					v.skip()
				"skip_in_hold":
					await create_timer(p.roll + p.hold * 0.4).timeout
					v.skip()
				"skip_twice":
					v.skip()
					v.skip()
			var guard := 0
			while fin[0] == 0 and guard < 600:
				guard += 1
				await process_frame
			await process_frame
			ok(fin[0] == 1, "%s/%s: finished %d times" % [tier, mode, fin[0]])
			ok(v.pip_count() == 0, "%s/%s: %d pips left behind" % [tier, mode, v.pip_count()])
			ok(is_zero_approx(v.card.rotation), "%s/%s: card left rotated" % [tier, mode])
			finals.append([v.card.face_up, v.card.rank, v.card.suit, v.card.enh, v.word.text, v.sub.text])
			v.finished.disconnect(cb)
		for i in range(1, finals.size()):
			ok(finals[i] == finals[0], "%s: skip mode %d ends at %s, full play at %s" % [tier, i, finals[i], finals[0]])
		ok(finals[0][0] and finals[0][1] == 11 and finals[0][4] == p.word and finals[0][5] == p.sub, "%s: end state is the revealed starter" % tier)
	Engine.time_scale = 1.0
	print("cut checks: %d (tiers vs JS: %d), failures: %d" % [checks, a_checks, fails])
	var good := fails == 0 and a_checks >= 500 and checks >= a_checks + 100
	print("CUT OK" if good else "CUT FAILED")
	quit(0 if good else 1)
