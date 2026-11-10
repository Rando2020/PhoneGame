class_name Upgrade
## The shop's "upgrade" mark (pass 16, LOOP_AUDIT 3). Presentation only.
## With the charm bar full, every pair (owned charm O, offered charm X) is
## measured, not guessed: the run's logged counts (CribRun.count_log) are
## recounted with X in O's slot, and the gain is that total minus the same
## counts recounted with the bar as it is. The best pair at MIN points or more
## is marked. Recounts are pure (no draws); run.charms is put back at once.
## Approximations: Glim-dependent charms use today's Glim. Charms with a
## `rule` (they change the rules, which are logged) are never compared.

const MIN := 5


static func _total(run: CribRun) -> float:
	var t := 0.0
	for e in run.count_log:
		var rd := CribRound.new(run, e.mods)
		rd.starter = e.starter
		rd.starter2 = e.starter2
		# the round state charms read (ctx.round), as it was at that count
		rd.deal_index = e.deal_index
		rd.mulligans_left = e.mulligans_left
		rd.deals_left = e.deals_left
		t += rd.run_count(e.hand, false, null, {"luck": e.luck}).total
	return t


## {offer: Charm, over: Charm, gain: int, counts: int} or null.
static func best(run: CribRun, offers: Array):
	if not run.is_full() or run.count_log.is_empty():
		return null
	var owned_ids := {}
	for c in run.charms:
		owned_ids[c.id] = true
	var base := _total(run)
	var top = null
	for i in run.charms.size():
		var mine: Charm = run.charms[i]
		if mine.rule != null:
			continue      # a rule charm is in the logged rules: a swap can't take it out
		for x in offers:
			if owned_ids.has(x.id) or x.rule != null:
				continue
			run.charms[i] = x
			var g := _total(run) - base
			run.charms[i] = mine
			if top == null or g > top.gain:
				top = {"offer": x, "over": mine, "gain": g}
	if top == null or JS.round_(top.gain) < MIN:
		return null
	top.gain = JS.round_(top.gain)
	top["counts"] = run.count_log.size()
	return top
