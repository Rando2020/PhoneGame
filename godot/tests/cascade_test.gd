extends SceneTree
## Cascade correctness. Part 1 (plan): thousands of real engine results, every
## plan must end on res.total and contain exactly the right beats. Part 2
## (player): CascadeView played in full and skipped at every point must show
## res.total. Presentation only; nothing here may change a score.
##   godot --headless --path godot --script res://tests/cascade_test.gd
const RESULTS := 1500
var checks := 0
var players_ran := 0
var fails := 0
var cover := {"level": 0, "gild": 0, "cut": 0, "block": 0, "charm": 0, "zero": 0,
	"level+charms": 0, "negative cut": 0, "boss": 0, "banner": 0, "tiers": {}}

func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		if fails <= 8:
			print("FAIL ", m)

func _initialize() -> void:
	_go.call_deferred()

## Real results from random builds: charms, Reckonings, gilds, Spoiler rounds.
func results(n: int) -> Array:
	Achv.persist = false
	Achv.save_store({"__v": 3})
	JS.unseeded = JsRng.new(5)
	var g := JsRng.new(2026)
	var out := []
	var melds := CribData.DECKS.keys()
	var k := 0
	while out.size() < n:
		k += 1
		var run := CribRun.new(melds[k % melds.size()], Meta.STREETS[k % 4], null, 500 + k)
		for i in int(g.next() * 6):
			var ch: Charm = CribData.CHARMS[int(g.next() * CribData.CHARMS.size())]
			if not run.charms.has(ch):
				run.charms.append(ch)
		for cat in run.levels:
			run.levels[cat] = int(g.next() * 3)
		if g.next() < 0.4:
			run.gilded[1 + int(g.next() * 13)] = 1
		run.round = 5 if g.next() < 0.4 else 1 + int(g.next() * 4)   # Spoiler rounds too
		run.act = 1 + int(g.next() * 5)
		var rd := CribRound.new(run)
		for d in 3:
			if rd.new_deal() == null:
				break
			var best := rd.best_keep_ev()
			var kr := rd.keep_rank(best.idx)
			var res = rd.commit(best.idx)
			out.append([res, rd, kr, run.boss() != null])
	return out

func _go() -> void:
	var t0 := Time.get_ticks_msec()
	var all := results(RESULTS)
	for i in all.size():
		var res: Dictionary = all[i][0]
		var plan := CascadePlan.build(res, all[i][1], all[i][2])
		var b: Array = plan.beats
		var kinds := b.map(func(x): return x.kind)
		var w := "result %d" % i
		ok(plan.final == res.total and b[b.size() - 1].number == res.total, "%s: ends on %d not %d" % [w, b[b.size() - 1].number, res.total])
		ok(b[b.size() - 1].kind == "slam", "%s: last beat is the slam" % w)
		# events, in order
		var ev := b.filter(func(x): return x.kind in ["fifteen", "pair", "run", "flush", "nobs"])
		ok(ev.size() == res.events.size(), "%s: %d event beats for %d events" % [w, ev.size(), res.events.size()])
		for j in mini(ev.size(), res.events.size()):
			ok(ev[j].label == res.events[j].label and ev[j].cards == res.events[j].cards, "%s: event %d" % [w, j])
		# each bonus row present exactly when nonzero
		for pair in [["level", "levelBonus"], ["gild", "gildBonus"], ["cut", "cutGain"], ["block", "suppressed"]]:
			var has := kinds.has(pair[0])
			ok(has == JS.truthy(res.get(pair[1])), "%s: %s row %s but %s=%s" % [w, pair[0], has, pair[1], res.get(pair[1])])
			if has:
				cover[pair[0]] += 1
		ok(kinds.has("zero") == res.events.is_empty(), "%s: 'No score' row" % w)
		if res.events.is_empty():
			cover.zero += 1
		# the charm chain: every step, in order, landing on its own total
		var ch := b.filter(func(x): return x.kind == "charm")
		ok(ch.size() == res.steps.size(), "%s: %d charm beats for %d steps" % [w, ch.size(), res.steps.size()])
		for j in mini(ch.size(), res.steps.size()):
			ok(ch[j].label == res.steps[j].name and ch[j].number == res.steps[j].total, "%s: charm step %d" % [w, j])
		if not res.steps.is_empty():
			cover.charm += 1
			if JS.truthy(res.get("levelBonus")):
				cover["level+charms"] += 1   # the case the web cascade drops
		if JS.truthy(res.get("cutGain")) and res.cutGain < 0:
			cover["negative cut"] += 1
			ok(kinds.has("cut") and b[kinds.find("cut")].value.begins_with("\u2212"), "%s: negative cut shows a minus" % w)
		if all[i][3]:
			cover.boss += 1
		for x in b:
			ok(typeof(x.number) == TYPE_INT and x.ms > 0, "%s: beat %s well-formed" % [w, x.kind])
		cover.tiers[plan.tier.word] = cover.tiers.get(plan.tier.word, 0) + 1
		# fluidity: at most coaching + one banner; a clutch line replaces TARGET MET
		var texts: Array = plan.lines.map(func(l): return l.text)
		ok(plan.lines.size() <= 2, "%s: %d footer lines" % [w, plan.lines.size()])
		ok(not (texts.has("TARGET MET") and plan.lines.any(func(l): return l.cls == "clutch")),
			"%s: clutch and TARGET MET stacked" % w)
		if JS.truthy(res.get("crossedTarget")):
			cover["banner"] = cover.get("banner", 0) + 1
	print("plan: %d results, %d checks, %d ms" % [all.size(), checks, Time.get_ticks_msec() - t0])
	print("coverage: ", cover)
	for k in ["level", "gild", "cut", "block", "charm", "zero", "level+charms", "boss", "banner"]:
		ok(cover[k] > 0, "coverage: no result exercised '%s'" % k)
	# A script that fails to load would crash _go before quit() and hang the
	# runner, so check it can instantiate and require the section to report in.
	var player = load("res://tests/cascade_player_test.gd")
	if player == null or not player.can_instantiate():
		ok(false, "cascade_player_test.gd failed to load")
	else:
		await player.new().run(self, all)
	ok(players_ran > 0, "player section never ran")
	var good := fails == 0 and checks > 1000
	print("CASCADE OK" if good else "CASCADE FAILED")
	quit(0 if good else 1)
