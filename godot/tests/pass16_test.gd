extends SceneTree
## Pass 16: the shop's upgrade mark (LOOP_AUDIT 3), presentation only.
##  - the count log: every hand count is logged (hand, cut, rules, luck, the
##    round state charms read), capped at COUNT_LOG_MAX, newest last
##  - replay fidelity: each logged count, recounted with the bar unchanged,
##    gives exactly the total the real count gave
##  - Upgrade.best: null unless the bar is full and the log has counts; the
##    marked pair is the best of every (owned, offered) pair, recomputed here
##    by hand; rule charms are never compared; under MIN, no mark
##  - nothing moves: run.charms (same objects, same order), the run's rng,
##    Glim and the log are as they were
##  - the shop: the marked offer carries the line; no line when not full
##   godot --headless --path godot --script res://tests/pass16_test.gd
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


## Plays one round with best keeps; returns the real hand totals, in order.
func _play(run: CribRun) -> Array:
	var rd := CribRound.new(run)
	var totals := []
	while rd.new_deal() != null:
		var res = rd.commit(rd.best_keep_ev().idx)
		totals.append(res.total)
		if rd.over or rd.score >= rd.target or rd.deals_left <= 0:
			break
	return totals


## This test's own recount (written apart from Upgrade._total).
func _recount(run: CribRun) -> float:
	var t := 0.0
	for e in run.count_log:
		var rd := CribRound.new(run, e.mods)
		rd.starter = e.starter
		rd.starter2 = e.starter2
		rd.deal_index = e.deal_index
		rd.mulligans_left = e.mulligans_left
		rd.deals_left = e.deals_left
		t += rd.run_count(e.hand, false, null, {"luck": e.luck}).total
	return t


const BAR := ["twinner", "rambler", "peacock", "facecard", "keystone2"]
const OFFER := ["fifteener", "fever", "counting"]


func _go() -> void:
	Achv.persist = false
	Achv.save_store({"__v": 3, "guided": 1})
	root.size = Vector2i(720, 1560)
	# ---- the log and replay fidelity (no Glim-reading charms on the bar)
	var marked := 0
	var unmarked := 0
	var fidelity := 0
	for sd in range(1, 41):
		var run := CribRun.new(CribData.DECKS.keys()[sd % 4], Meta.STREETS[0], null, 4000 + sd)
		for id in BAR:
			run.charms.append(CribData.charm_by_id(id))
		ok(run.is_full(), "seed %d: bar not full" % sd)
		ok(Upgrade.best(run, OFFER.map(func(i): return CribData.charm_by_id(i))) == null, "an empty log marks nothing")
		var totals := []
		for r in 3:
			totals += _play(run)
			run.round = mini(run.round + 1, CribData.ROUNDS - 1)
		ok(run.count_log.size() == mini(totals.size(), CribRun.COUNT_LOG_MAX), "seed %d: log %d of %d counts" % [sd, run.count_log.size(), totals.size()])
		# fidelity: one by one against the real totals (the log's tail)
		var tail := totals.slice(totals.size() - run.count_log.size())
		for i in run.count_log.size():
			var keep := run.count_log
			run.count_log = [keep[i]]
			var one := _recount(run)
			run.count_log = keep
			ok(absf(one - tail[i]) < 0.001, "seed %d count %d: replay %s, real %s" % [sd, i, one, tail[i]])
			fidelity += 1
		# Upgrade.best against every pair, by hand
		var offers: Array = OFFER.map(func(i): return CribData.charm_by_id(i))
		var before_charms := run.charms.duplicate()
		var s0: int = run.rng.s
		var g0: int = run.essence
		var log0 := run.count_log.duplicate()
		var b = Upgrade.best(run, offers)
		ok(run.charms.size() == before_charms.size() and range(run.charms.size()).all(func(k): return is_same(run.charms[k], before_charms[k])), "seed %d: the bar moved" % sd)
		ok(run.rng.s == s0 and run.essence == g0 and run.count_log == log0, "seed %d: rng, Glim or log moved" % sd)
		var base := _recount(run)
		var top = null
		for k in run.charms.size():
			var mine: Charm = run.charms[k]
			if mine.rule != null:
				continue
			for x in offers:
				if x.rule != null:
					continue
				run.charms[k] = x
				var g := _recount(run) - base
				run.charms[k] = mine
				if top == null or g > top[2]:
					top = [x, mine, g]
		if top == null or JS.round_(top[2]) < Upgrade.MIN:
			ok(b == null, "seed %d: marked %s though the best gain is %s" % [sd, b, top])
			unmarked += 1
		else:
			ok(b != null and b.offer == top[0] and b.over == top[1] and b.gain == JS.round_(top[2]) and b.counts == run.count_log.size(),
				"seed %d: %s vs best %s over %s +%s" % [sd, b, top[0].name, top[1].name, top[2]])
			marked += 1
		# not full: no mark
		var spare = run.charms.pop_back()
		ok(Upgrade.best(run, offers) == null, "a bar with room marks nothing")
		run.charms.append(spare)
	# a strong bar against a weak offer: the mark should mostly stay off
	for sd in range(1, 21):
		var run := CribRun.new(CribData.DECKS.keys()[sd % 4], Meta.STREETS[0], null, 4500 + sd)
		for id in ["keystone2", "fever", "counting", "fifteener", "twinner"]:
			run.charms.append(CribData.charm_by_id(id))
		_play(run)
		var weak: Array = [CribData.charm_by_id("peacock")]
		var b = Upgrade.best(run, weak)
		var base := _recount(run)
		var best_g = null
		for k in run.charms.size():
			var mine: Charm = run.charms[k]
			run.charms[k] = weak[0]
			var g := _recount(run) - base
			run.charms[k] = mine
			if best_g == null or g > best_g:
				best_g = g
		ok((b == null) == (JS.round_(best_g) < Upgrade.MIN), "strong bar seed %d: mark %s, best gain %s" % [sd, b, best_g])
		if b == null:
			unmarked += 1
	ok(marked >= 5 and unmarked >= 1 and fidelity >= 100, "cases: %d marked, %d not, %d replays" % [marked, unmarked, fidelity])
	# rule charms are never compared
	var rr := CribRun.new("pip", Meta.STREETS[0], null, 77)
	for id in ["aceeleven", "shortflush", "wrap", "recut", "cribmaster"]:
		rr.charms.append(CribData.charm_by_id(id))
	_play(rr)
	ok(Upgrade.best(rr, [CribData.charm_by_id("fifteener")]) == null, "a bar of rule charms is never marked")
	var rr2 := CribRun.new("pip", Meta.STREETS[0], null, 78)
	for id in BAR:
		rr2.charms.append(CribData.charm_by_id(id))
	_play(rr2)
	var only_rules = Upgrade.best(rr2, [CribData.charm_by_id("aceeleven"), CribData.charm_by_id("shortflush")])
	ok(only_rules == null, "rule offers are never marked: %s" % [only_rules])
	# the log's cap
	var lr := CribRun.new("thump", Meta.STREETS[0], null, 79)
	for k in 12:
		_play(lr)
	ok(lr.count_log.size() == CribRun.COUNT_LOG_MAX, "log capped at %d: %d" % [CribRun.COUNT_LOG_MAX, lr.count_log.size()])

	# ---- the shop line
	var f: RunFlow = load("res://scenes/run_flow.tscn").instantiate()
	root.add_child(f)
	await process_frame
	var shown := false
	for sd in range(1, 80):
		var run := CribRun.new("thump", Meta.STREETS[0], null, 5000 + sd)
		for id in BAR:
			run.charms.append(CribData.charm_by_id(id))
		_play(run)
		run.open_shop()
		run.shop_state.offer = OFFER.map(func(i): return CribData.charm_by_id(i))
		var b = Upgrade.best(run, run.shop_state.offer)
		if b == null:
			continue
		f.run = run
		f.show_shop()
		f.shop.finish()
		await process_frame
		var want := "UPGRADE over %s: +%d on your last %d counts" % [b.over.name, b.gain, b.counts]
		var lab: Label = f.shop.upgrade_label
		ok(lab != null and lab.text == want and f.shop.offer_buttons[b.offer.id].is_ancestor_of(lab), "shop line '%s' (want '%s')" % [lab.text if lab != null else null, want])
		var lines := f.find_children("*", "Label", true, false).filter(func(l): return String(l.text).begins_with("UPGRADE"))
		ok(lines.size() == 1, "one upgrade line, got %d" % lines.size())
		run.charms.pop_back()
		f.shop.render()
		f.shop.finish()
		await process_frame
		ok(f.shop.upgrade_label == null and f.find_children("*", "Label", true, false).filter(func(l): return String(l.text).begins_with("UPGRADE")).is_empty(), "room on the bar, still a line")
		shown = true
		break
	ok(shown, "no seed gave an upgrade to show")
	f.queue_free()
	await process_frame
	print("pass16_test: %d marked, %d unmarked, %d replays" % [marked, unmarked, fidelity])
	print("pass16_test: %d checks, %d fails" % [checks, fails])
	quit(1 if fails > 0 else 0)
