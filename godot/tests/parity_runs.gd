extends RefCounted
## Full-run parity. Mirrors playRun() in tools/parity/gen_fixtures.js exactly:
## same policy, same call order, so every field of every trace must match.

var T  # the parity_test SceneTree, for check()
## Optional: called as hook.call(run, rd) at four points per deal/round; returns
## [run, rd] to carry on with. save_test.gd uses it to save and reload the whole
## game at every one of those points.
var hook = null
var hooked := 0


func _h(run, rd) -> Array:
	if hook == null:
		return [run, rd]
	hooked += 1
	return hook.call(run, rd)


func run(test, fx) -> void:
	T = test
	var t0 := Time.get_ticks_msec()
	# PARITY_RUNS=N limits the (slow) full-run section, for quick iteration.
	var lim: int = fx.runs.size()
	if OS.get_environment("PARITY_RUNS") != "":
		lim = mini(lim, int(OS.get_environment("PARITY_RUNS")))
	# PARITY_ONLY=3,17 runs just those indices.
	var only := []
	if OS.get_environment("PARITY_ONLY") != "":
		only = Array(OS.get_environment("PARITY_ONLY").split(",")).map(func(x): return int(x))
	for i in lim:
		if not only.is_empty() and not only.has(i):
			continue
		var r = fx.runs[i]
		var got := play_run(r.cfg)
		if not T.check("runs", "%d (%s st%d%s)" % [i, r.cfg.meld, r.cfg.street,
				" " + r.cfg.trial if r.cfg.trial != null else ""], r.trace, got):
			_locate(r.trace, got)
	print("runs: %d ms" % (Time.get_ticks_msec() - t0))


## Narrow a failing run to the first deal that differs.
func _locate(exp, got) -> void:
	for k in ["cards", "bosses", "wagers"]:
		if T.diff(exp[k], got[k]) != "":
			print("   first difference in run start: ", k)
			return
	for ri in mini(exp.rounds.size(), got.rounds.size()):
		var a = exp.rounds[ri]
		var b = got.rounds[ri]
		for di in mini(a.deals.size(), b.deals.size()):
			var d: String = T.diff(a.deals[di], b.deals[di])
			if d != "":
				print("   round %d deal %d%s" % [ri, di, d])
				return
		var d2: String = T.diff(a, b)
		if d2 != "":
			print("   round %d%s" % [ri, d2])
			return


func play_run(cfg) -> Dictionary:
	Achv.persist = false
	Achv.save_store({"__v": 3})
	for s in cfg.systems:
		Achv.grant_system(s)
	JS.unseeded = JsRng.new(cfg.unseeded)
	var street: Dictionary = Meta.STREETS[cfg.street - 1]
	var trial = null
	if cfg.trial != null:
		for t in Meta.TRIALS:
			if t.id == cfg.trial:
				trial = t
	var run := CribRun.new(cfg.meld, street, trial, cfg.seed)
	for id in cfg.get("force", []):
		var ch := CribData.charm_by_id(id)
		run.charms.append(ch)
		if ch.on_acquire.is_valid():
			ch.on_acquire.call(run)
	if cfg.endless:
		run.enter_endless()
		run.endless_round = 0
	var wk: Array = run.wager_at.keys()
	wk.sort()
	var tr := {"cards": run.cards.map(func(c): return T.card_out(c)),
		"bosses": run.boss_plan.map(func(b): return b.id), "wagers": wk, "rounds": []}
	for r in cfg.maxRounds:
		var rd := CribRound.new(run)
		var hp := _h(run, rd)
		run = hp[0]
		rd = hp[1]
		var bs = run.boss()
		var rt := {"idx": run.round_index(), "target": rd.target, "boss": bs.id if bs != null else null,
			"deadSuit": rd.mods.deadSuit, "stock": rd.stock.size(), "wager": rd.wager != null, "deals": []}
		var guard := 0
		while not rd.over and guard < 30:
			guard += 1
			hp = _h(run, rd)
			run = hp[0]
			rd = hp[1]
			if rd.new_deal() == null:
				break
			var best := rd.best_keep_ev()
			var mull := false
			if rd.deal_index == 0 and rd.mulligans_left > 0 and best.ev < 4 and rd.mulligan() != null:
				mull = true
				best = rd.best_keep_ev()
			var kept: Array = best.idx.map(func(i): return rd.dealt[i])
			var ord = null
			if run.charms.size() >= 2 and rd.deal_index == 1:
				ord = run.best_order(rd, kept)
			var rank := rd.keep_rank(best.idx)
			var pv = rd.preview(best.idx)
			var res = rd.commit(best.idx)
			var q := rd.cut_quality(kept, rd.starter)
			rt.deals.append({
				"dealt": rd.dealt.map(func(c): return T.card_out(c)), "keep": best.idx, "ev": best.ev,
				"mull": mull, "rank": rank.rank,
				"pv": [pv.sure, pv.ev] if pv.has("blind") else pv.total,
				"ord": [ord.order, ord.total] if ord != null else null,
				"starter": T.card_out(rd.starter), "total": res.total, "base": res.base, "mult": res.mult,
				"labels": res.events.map(func(e): return e.label), "fired": res.fired,
				"steps": res.steps.map(func(x): return [x.name, x.gain, x.total]), "contrib": res.contrib,
				"levelContrib": res.levelContrib, "cutGain": res.cutGain, "coins": res.coins,
				"shattered": res.shattered.size(), "q": [q.tier, q.rank, q.of, q.mine, q.best, q.bare],
				"essence": run.essence, "deck": run.cards.size(), "stock": rd.stock.size(), "score": rd.score})
			hp = _h(run, rd)
			run = hp[0]
			rd = hp[1]
			if rd.score >= rd.target and not JS.truthy(rd.mods.get("noCashOut")) and rd.wager == null:
				rd.cash_out()
		if not rd.over:
			rd.settle()
		var cr: Dictionary = rd.crib_result
		rt.merge({"won": rd.won, "score": rd.score, "crib": cr.total,
			"cribLabels": cr.events.map(func(e): return e.label), "earned": rd.essence_earned,
			"mvp": rd.mvp(), "cycle": rd.cycle, "outOfCards": rd.out_of_cards,
			"wagerWon": rd.wager_won, "narrow": rd.narrow})
		tr.rounds.append(rt)
		if not rd.won:
			break
		run.essence += rd.essence_earned
		if not JS.truthy(rd.mods.get("noShop")):
			var shop := run.open_shop()
			rt["shop"] = {"offer": shop.offer.map(func(c): return c.id),
				"cards": shop.cards.map(func(e): return [T.card_out(e.card), e.cost])}
			for c in shop.offer:
				if not run.is_full() and run.essence >= c.cost:
					run.essence -= c.cost
					run.charms.append(c)
					if c.on_acquire.is_valid():
						c.on_acquire.call(run)
					rt["bought"] = c.id
					break
			for e in shop.cards:
				if run.buy_card(e):
					break
			if run.essence >= 20 and run.reroll():
				rt["reroll"] = shop.offer.map(func(c): return c.id)
			for cat in CribData.LEVEL_CATS:
				if run.buy_level(cat):
					break
			if run.essence >= 15:
				run.gild(5)
			if run.charms.size() >= 3 and run.round_index() % 4 == 0:
				rt["sold"] = run.sell(run.charms[0].id)
			if run.charms.size() >= 2:
				run.move_charm(run.charms.size() - 1, 0)
		hp = _h(run, null)
		run = hp[0]
		if run.endless:
			run.endless_round += 1
			continue
		if run.advance():
			tr["cleared"] = true
			break
	tr["end"] = {"essence": run.essence, "deck": run.cards.size(),
		"charms": run.charms.map(func(c): return c.id), "levels": run.levels, "mvp": run.run_mvp()}
	return T.norm(tr)
