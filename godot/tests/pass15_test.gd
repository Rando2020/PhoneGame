extends SceneTree
## Pass 15: plain-round twists (LOOP_AUDIT 5) and synergy callouts (7).
##  - the plan: every plain slot of every act gets a real twist, never the same
##    twice in a row, the same for the same seed, from its own stream (the run's
##    rng is not touched); none on a Spoiler, a Wager or the Long Count
##  - each twist's rule reaches the round's mods, only ever helping (a better
##    rule already there stays); the twist round's target is x TWIST_TARGET
##  - shown: the intro panel, the keep screen's status, the round end's Next
##  - synergy: total - without A - without B + without both, from pure recounts;
##    the round end names the best pair at SYNERGY_MIN points or more
##   godot --headless --path godot --script res://tests/pass15_test.gd
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
	var ids := CribData.TWISTS.map(func(t): return t.id)
	# ---- the plan
	var seen := {}
	for sd in range(1, 201):
		var r := CribRun.new(CribData.DECKS.keys()[sd % 4], Meta.STREETS[sd % 8], null, sd)
		ok(r.twist_plan.size() == CribData.ACTS * (CribData.ROUNDS - 1), "seed %d: %d slots" % [sd, r.twist_plan.size()])
		var prev := ""
		for a in range(1, CribData.ACTS + 1):
			for rr in range(1, CribData.ROUNDS):
				var id: String = r.twist_plan.get("%d-%d" % [a, rr], "")
				ok(ids.has(id), "seed %d %d-%d: '%s'" % [sd, a, rr, id])
				ok(id != prev, "seed %d: %s twice in a row at %d-%d" % [sd, id, a, rr])
				prev = id
				seen[id] = true
		var s0: int = r.rng.s
		var again := r.twist_plan.duplicate()
		r.plan_twists()
		ok(r.rng.s == s0, "seed %d: planning twists drew from the run's rng" % sd)
		ok(r.twist_plan == again, "seed %d: the plan isn't the seed's" % sd)
	ok(seen.size() == CribData.TWISTS.size(), "all %d twists turn up: %s" % [CribData.TWISTS.size(), seen.keys()])
	var p1 := CribRun.new("pip", null, null, 11).twist_plan
	var p2 := CribRun.new("pip", null, null, 12).twist_plan
	ok(p1 != p2, "two seeds, one plan")
	# where twists don't apply
	var b := CribRun.new("pip", Meta.STREETS[0], null, 5)
	b.round = CribData.ROUNDS
	ok(b.is_boss() and b.twist() == null, "a Spoiler round has no twist")
	var t3 := CribRun.new("pip", Meta.STREETS[2], null, 5)
	t3.round = CribData.ROUNDS - 1
	ok(t3.is_boss() and t3.twist() == null, "Third Street's extra Spoiler has no twist")
	var wg := CribRun.new("pip", Meta.STREETS[0], null, 5)
	wg.wager_at = {"1-2": true}
	wg.round = 2
	ok(wg.is_wager() and wg.twist() == null, "a Wager has no twist")
	var en := CribRun.new("pip", Meta.STREETS[0], null, 5)
	en.enter_endless()
	en.endless_round = 0
	ok(en.twist() == null, "the Long Count has no twist")

	# ---- rules, only helping, and the target
	var want := {"pairs4": ["pairDouble", true], "fifteen3": ["fifteenPoints", 3], "flush3": ["flushNeed", 3],
		"deal7": ["dealtBonus", 1], "cribfull": ["cribFull", true], "mull1": ["mulliganBonus", 1]}
	for id in ids:
		var r := CribRun.new("thump", Meta.STREETS[0], null, 9)
		r.wager_at = {}
		r.round = 1
		var plain := r.target()
		var base_rules := r.rules()
		r.twist_plan["1-1"] = id
		var m := r.rules()
		var k: String = want[id][0]
		ok(m[k] == want[id][1] if not k in ["mulliganBonus", "dealtBonus"] else m[k] == base_rules[k] + 1, "%s: %s = %s" % [id, k, m[k]])
		ok(r.target() == JS.round_(CribData.LADDER_BASE * CribData.TWIST_TARGET), "%s: target %d (plain %d)" % [id, r.target(), plain])
		var rd := CribRound.new(r)
		ok(rd.target == r.target(), "the round's target is the twisted one")
		ok(JS.truthy(rd.mods.get(k)) or rd.mods.get(k) == want[id][1] or k == "mulliganBonus", "%s reaches the round's mods" % id)
		if id == "deal7":
			rd.new_deal()
			ok(rd.dealt.size() == CribData.DEALT + base_rules.dealtBonus + 1, "Seventh Card deals %d" % rd.dealt.size())
	var r0 := CribRun.new("thump", Meta.STREETS[0], null, 9)
	r0.twist_plan = {}
	r0.round = 1
	ok(r0.target() == CribData.LADDER_BASE, "no twist: plain target %d" % r0.target())
	# a better rule already in place stays (a deck that already pays more)
	var rich := CribRun.new("thump", Meta.STREETS[0], null, 9)
	rich.wager_at = {}
	rich.round = 1
	var dk: Dictionary = rich.deck.duplicate(true)
	dk["rule"] = {"flushNeed": 2, "fifteenPoints": 4, "dealtBonus": 1}
	rich.deck = dk
	for pair in [["flush3", "flushNeed", 2], ["fifteen3", "fifteenPoints", 4], ["deal7", "dealtBonus", 2]]:
		rich.twist_plan["1-1"] = pair[0]
		ok(rich.rules()[pair[1]] == pair[2], "%s: a better %s stays %s (got %s)" % [pair[0], pair[1], pair[2], rich.rules()[pair[1]]])

	# ---- shown: intro, keep status, round end Next
	var f: RunFlow = load("res://scenes/run_flow.tscn").instantiate()
	root.add_child(f)
	await process_frame
	var sr := CribRun.new("pip", Meta.STREETS[0], null, 31)
	sr.wager_at = {}
	sr.twist_plan["1-1"] = "fifteen3"
	sr.twist_plan["1-2"] = "pairs4"
	f.start_run(sr)
	await process_frame
	var tx := _labels(f)
	ok(tx.has("RICH FIFTEENS: Fifteens score 3.  Target +%d%%, %d deals." % [roundi((CribData.TWIST_TARGET - 1.0) * 100.0), CribData.DEALS + sr.rules().dealBonus]), "intro: no twist line in %s" % [tx.slice(0, 12)])
	ok(not tx.any(func(t): return t.begins_with("Score ")), "intro: the twist line should replace 'Score N in D deals'")
	f._on_deal()
	for i in 40:
		await process_frame
	ok(f.keep.status_label.text.contains("|  Rich Fifteens"), "keep status: '%s'" % f.keep.status_label.text)
	var nd := CribRound.new(sr)
	nd.won = true
	f.rd = nd
	f._paid = true
	f._render_round_end()
	await process_frame
	var nl := "Next: Round 2, target %d  ·  Doubled Pairs" % sr.next_target()
	ok(_labels(f).has(nl), "round end: no '%s'" % nl)
	var t2 := CribRun.new("pip", Meta.STREETS[0], null, 31)
	t2.wager_at = {}
	t2.twist_plan["1-2"] = "pairs4"
	t2.round = 2
	ok(sr.next_target() == t2.target(), "next target %d is round 2's %d" % [sr.next_target(), t2.target()])
	# a plain round with no twist shows no panel
	var bare := CribRun.new("pip", Meta.STREETS[0], null, 31)
	bare.twist_plan = {}
	f.start_run(bare)
	await process_frame
	ok(not _labels(f).any(func(t): return t.contains("Target +")) and _labels(f).any(func(t): return t.begins_with("Score ")), "a twistless round: no twist line, the Score line back")

	# ---- synergy
	var pairs := 0
	var shown := 0
	for sd in range(1, 160):
		var r := CribRun.new(CribData.DECKS.keys()[sd % 4], Meta.STREETS[0], null, 600 + sd)
		r.twist_plan = {}
		for id in ["keystone2", "ballast", "fifteener", "tallyman", "usury"].slice(sd % 3, sd % 3 + 3):
			r.charms.append(CribData.charm_by_id(id))
		var rd := CribRound.new(r)
		var sum := {}
		for d in 3:
			if rd.new_deal() == null:
				break
			var idx: Array = rd.best_keep_ev().idx
			var hand: Array = idx.map(func(i): return rd.dealt[i])
			var res = rd.commit(idx)
			for key in res.synergy:
				pairs += 1
				sum[key] = sum.get(key, 0) + res.synergy[key]
				var names: PackedStringArray = String(key).split(" + ")
				var a: Charm = null
				var bb: Charm = null
				for c in r.active_charms():
					if c.name == names[0]:
						a = c
					elif c.name == names[1]:
						bb = c
				var luck = res.get("luck")
				var wa: float = res.total - res.contrib.get(names[0], 0)
				var wb: float = res.total - res.contrib.get(names[1], 0)
				ok(a != null and bb != null and res.contrib.has(names[0]) and res.contrib.has(names[1]), "pair %s: both scored" % key)
				ok(JS.round_(res.synergy[key]) > 0, "pair %s: listed at %s" % [key, res.synergy[key]])
			if rd.over:
				break
		for key in sum:
			ok(absf(rd.synergy_totals.get(key, 0) - sum[key]) < 0.001, "round total for %s" % key)
		var bs = rd.best_synergy()
		var top = null
		for key in rd.synergy_totals:
			if JS.round_(rd.synergy_totals[key]) >= CribRound.SYNERGY_MIN and (top == null or rd.synergy_totals[key] > rd.synergy_totals[top]):
				top = key
		ok((bs == null) == (top == null) and (bs == null or bs.pair == top), "best pair %s vs %s" % [bs, top])
		if bs != null and shown < 3:
			f.run = r
			f.rd = rd
			f._paid = true
			f._render_round_end()
			await process_frame
			var line := "%s fed each other  +%d" % [bs.pair, bs.points]
			ok(_labels(f).has(line), "round end: no '%s'" % line)
			shown += 1
	ok(pairs >= 20 and shown >= 1, "synergy cases: %d pairs, %d shown" % [pairs, shown])
	# the formula, by hand on one known count
	var kr := CribRun.new("thump", Meta.STREETS[0], null, 777)
	kr.twist_plan = {}
	for id in ["fifteener", "tallyman"]:
		kr.charms.append(CribData.charm_by_id(id))
	var kd := CribRound.new(kr)
	var checked := 0
	for d in 4:
		if kd.new_deal() == null:
			break
		var idx: Array = kd.best_keep_ev().idx
		var hand: Array = idx.map(func(i): return kd.dealt[i])
		var cs: Array = kr.active_charms().filter(func(c): return c.name in ["Fifteener", "Tallyman"] or c.id in ["fifteener", "tallyman"])
		var res = kd.commit(idx)
		if cs.size() == 2 and res.contrib.has(cs[0].name) and res.contrib.has(cs[1].name):
			var both = kd.run_count(hand, false, null, {"skip": cs[0], "skip2": cs[1], "luck": res.get("luck")})
			var expect: float = res.total - res.contrib[cs[0].name] - res.contrib[cs[1].name] + 0.0
			expect = res.total - (res.total - res.contrib[cs[0].name]) - (res.total - res.contrib[cs[1].name]) + both.total
			var key := "%s + %s" % [cs[0].name, cs[1].name]
			ok((JS.round_(expect) > 0) == res.synergy.has(key), "formula: %s %s" % [expect, res.synergy])
			if res.synergy.has(key):
				ok(absf(res.synergy[key] - expect) < 0.001, "formula value %s vs %s" % [res.synergy[key], expect])
			checked += 1
		if kd.over:
			break
	print("pass15_test: formula checked on %d counts" % checked)
	f.queue_free()
	await process_frame
	print("pass15_test: %d checks, %d fails" % [checks, fails])
	quit(1 if fails > 0 else 0)
