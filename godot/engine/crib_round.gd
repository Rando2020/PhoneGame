class_name CribRound
extends RefCounted
## Port of CribRound from web/cribrogue.js.
## round = reach the target within N deals.
## deal  = draw 6 -> keep 4 -> cut starter -> COUNT (cascade x mult).
## Count results are Dictionaries with the same camelCase keys the JS uses,
## so the UI layer can be ported against the same field names.

var run
var mods: Dictionary
var target: int
var deals_left: int
var deal_index := 0
var score := 0
var crib: Array = []
var over := false
var won := false
var stock: Array
var starting_stock: int
var seen: Array = []
var dealt = null
var starter = null
var starter2 = null
var crib_starter = null
var recuts_left := 0
var auto_recuts := 0
var wager = null
var wager_target := 0
var wager_won := false
var mulligans_left: int
var start_mulligans: int
var cycle := 1
var used: Array = []
var burned: Array = []
var recycled := false
var out_of_cards := false
var cashed_out := false
var phase := "deal"   # deal -> keep -> counted
var last_count = null
var shattered_all: Array = []
var coins_all := 0
var contrib_totals := {}
var synergy_totals := {}   ## "A + B" -> points the pair made together this round
var level_total := 0
var cut_total := 0
var crib_result = null
var margin := 0
var narrow := false
var so_close := false
var deals_spared := 0
var mulligans_spared := 0
var early_bonus := 0
var clean_bonus := 0
var base_glim := 0
var essence_earned := 0
var collected := false   ## The Collector has taken its card this round
## EV table for the current deal, shared by best_keep_ev() and keep_rank().
## Not in the JS: a Godot-only cache. Cleared by anything that changes dealt or stock.
var _ev_table = null
var _ev_dealt = null
var _ev_stock_n := -1


## replay_mods: a recount-only round (Upgrade) with a past round's rules: no
## shuffle, no draws, nothing on the run touched.
func _init(run_, replay_mods = null) -> void:
	run = run_
	if replay_mods != null:
		mods = replay_mods
		return
	mods = run.rules()
	target = run.target()
	deals_left = CribData.DEALS + mods.dealBonus
	stock = JS.shuffle(run.cards.duplicate(), run.rng)   # YOUR deck, dealt down once
	if mods.roundTrim == 99:
		stock = stock.slice(0, 30)
	elif JS.truthy(mods.roundTrim):
		stock = stock.slice(mods.roundTrim)
	if JS.truthy(mods.get("levy")):
		run.essence = 0
	if JS.truthy(mods.get("deadSuitRandom")):
		mods.deadSuit = Cribbage.SUITS[int(floor(run.rng.next() * 4))]
	starting_stock = stock.size()
	wager = {"kind": "exact"} if (run.is_wager() or JS.truthy(mods.get("allExact"))) else null
	if wager != null:
		wager_target = JS.round_(target * 1.35)
	mulligans_left = maxi(0, CribData.BASE_MULLIGANS + mods.mulliganBonus)
	start_mulligans = mulligans_left


func keep_count() -> int:
	return maxi(2, CribData.KEEP + mods.keepBonus - mods.keepPenalty)


func dealt_count() -> int:
	return CribData.DEALT + mods.dealtBonus - mods.keepPenalty


func needed() -> int:
	return dealt_count() + (2 if JS.truthy(mods.get("doubleCut")) else 1)


## A spent deck is gathered and reshuffled, costing a deal.
func recycle() -> bool:
	if JS.truthy(mods.get("noRecycle")):
		return false
	var back := used + burned
	if back.is_empty():
		return false
	stock = JS.shuffle(stock + back, run.rng)
	_invalidate_ev()
	used = []
	burned = []
	seen = []
	cycle += 1
	deals_left = maxi(0, deals_left - 1)
	recycled = true
	return deals_left > 0


func new_deal():
	if over or deals_left <= 0:
		return null
	if stock.size() < needed():
		recycle()
	if stock.size() < needed():
		out_of_cards = true
		settle()
		return null
	dealt = stock.slice(0, dealt_count())
	stock = stock.slice(dealt_count())
	_invalidate_ev()
	starter = null
	starter2 = null
	seen.append_array(dealt)
	recuts_left = mods.recuts
	phase = "keep"
	# Foresight reverses the order back, as a paid advantage
	if JS.truthy(mods.get("foresight")):
		cut_starter()
	return dealt


func cut_starter():
	if starter != null:
		return starter
	starter = JS.pop_or_null(stock)
	_invalidate_ev()
	seen.append(starter)
	if JS.truthy(mods.get("doubleCut")) and not stock.is_empty():
		starter2 = stock.pop_back()
		seen.append(starter2)
	return starter


## The current six go to the Crib and you draw fresh.
## A mulligan must leave a card to cut for the starter (unless already cut).
## Needed once recycling stopped duplicating cards: without it a mulligan can
## empty the stock and the commit has no starter to cut.
func can_mulligan() -> bool:
	if mulligans_left <= 0 or phase != "keep":
		return false
	return stock.size() >= dealt_count() + (0 if starter != null else 1)


func mulligan():
	if not can_mulligan():
		return null
	mulligans_left -= 1
	var room := maxi(0, CribData.CRIB_SIZE - crib.size())
	crib.append_array(dealt.slice(0, room))
	burned = burned + dealt.slice(room)
	dealt = stock.slice(0, dealt_count())
	stock = stock.slice(dealt_count())
	_invalidate_ev()
	seen.append_array(dealt)
	return dealt


## Score the kept hand against every card still in the deck, rank the real cut.
func cut_quality(hand: Array, st: Dictionary) -> Dictionary:
	var pool := stock + [st]
	var scores := pool.map(func(c): return {"card": c, "total": run_count(hand, false, c, {"noAffinity": false}).total})
	scores = JS.stable_sort_desc(scores, func(x): return x.total)
	var mine: int = run_count(hand, false, st).total
	var bare: int = run_count(hand, false, null, {"noStarter": true}).total
	var rank := -1
	for i in scores.size():
		if is_same(scores[i].card, st):
			rank = i
			break
	if rank < 0:
		for i in scores.size():
			if scores[i].total == mine:
				rank = i
				break
	var of := scores.size()
	var pct := 1.0 - (float(rank) / maxi(1, of - 1))
	var best: int = scores[0].total
	var gain := mine - bare
	var tier := "cold"
	if rank == 0 and gain >= 6:
		tier = "perfect"
	elif rank == 0:
		tier = "great"
	elif pct >= 0.92:
		tier = "great"
	elif pct >= 0.72:
		tier = "good"
	elif pct >= 0.35 or gain > 0:
		tier = "okay"
	return {"tier": tier, "rank": rank + 1, "of": of, "pct": pct, "mine": mine, "best": best, "gain": gain, "bare": bare}


## With Double Cut, count against the better starter.
func live_starter(hand: Array):
	if starter2 == null:
		return starter
	var a = Cribbage.count_hand(hand, starter, false, mods).base
	var b = Cribbage.count_hand(hand, starter2, false, mods).base
	return starter2 if b > a else starter


## Cards not yet seen this round: powers the deck viewer.
func remaining() -> Array:
	var u := {}
	for c in seen:
		if c != null:
			u[str(c.rank) + c.suit] = true
	return stock.filter(func(c): return not u.has(str(c.rank) + c.suit))


func remaining_histogram() -> Dictionary:
	var h := {}
	for c in stock:
		h[c.rank] = h.get(c.rank, 0) + 1
	return h


func recut():
	if recuts_left <= 0 or starter == null:
		return null
	recuts_left -= 1
	stock.push_front(starter)
	starter = stock.pop_back()
	_invalidate_ev()
	return starter


func _all_of(hand: Array, st) -> Array:
	return hand + [st] if st != null else hand.duplicate()


## The scoring pipeline. Charms fire per event and once per count; the
## returned ctx carries the cascade the UI ticks up.
func run_count(hand: Array, is_crib := false, starter_override = null, opts: Dictionary = {}) -> Dictionary:
	var st = null
	if not JS.truthy(opts.get("noStarter")):
		if starter_override != null:
			st = starter_override
		else:
			st = starter if is_crib else live_starter(hand)
	var res := Cribbage.count_hand(hand, st, is_crib, mods)
	var only = "run" if JS.truthy(mods.onlyRuns) else ("fifteen" if JS.truthy(mods.onlyFifteens) else ("flush" if JS.truthy(mods.onlyFlush) else null))
	if only != null:
		res.events = res.events.filter(func(e): return e.kind == only)
		var b = 0
		for e in res.events:
			b += e.points
		res.base = b
	var suppressed = 0
	var bs = run.boss()
	if bs != null:
		var clean := Cribbage.count_hand(hand, st, is_crib, {"flushNeed": mods.flushNeed})
		suppressed = max(0, clean.base - res.base)
		if suppressed and JS.truthy(mods.get("muggins")):
			var claw := JS.round_(suppressed / 2.0)
			res.base += claw
			res["mugginsClaw"] = claw
			suppressed -= claw
	var ctx := {"base": res.base, "mult": 1.0, "events": res.events, "starter": st,
		"round": self, "run": run, "fired": [], "isCrib": is_crib,
		"suppressed": suppressed, "suppressedBy": bs.name if bs != null else null}
	if res.has("mugginsClaw"):
		ctx["mugginsClaw"] = res.mugginsClaw
	ctx["all"] = _all_of(hand, st)
	# Run-changing charm effects are intents (a count may be hypothetical).
	# essence is projected Glim, updated in charm order; apply_effects() commits.
	ctx["essenceStart"] = run.essence
	ctx["essence"] = run.essence
	ctx["addCards"] = []
	# Nib doubles whatever the cut brought to the hand
	if JS.truthy(mods.get("doubleCutValue")) and st != null and not JS.truthy(opts.get("noStarter")):
		var bare = Cribbage.count_hand(hand, null, is_crib, mods).base
		var gain = max(0, res.base - bare)
		if gain:
			ctx.base += gain
			ctx["nibBonus"] = gain

	# suit affinity against the Spoiler
	var boss_a = bs.get("align") if bs != null else null
	if boss_a != null and not JS.truthy(opts.get("noAffinity")):
		var in_hand := _all_of(hand, st)
		var weak := in_hand.filter(func(c): return c.suit == boss_a).size()
		var strong := in_hand.filter(func(c): return c.suit == CribData.SUIT_OPPOSE[boss_a]).size()
		if weak or strong:
			var f := pow(CribData.AFFINITY_WEAK, float(weak) / in_hand.size()) * \
				pow(CribData.AFFINITY_STRONG, float(strong) / in_hand.size())
			ctx.mult *= f
			ctx["affinity"] = {"suit": boss_a, "weak": weak, "strong": strong, "factor": f}

	# per-card marks
	if not JS.truthy(opts.get("noEnh")):
		var eb = 0   # untyped like a JS number: Fickle's preview average is 6.25
		var em := 1.0
		for c in _all_of(hand, st):
			var enh = c.get("enh")
			if enh == "gilded":
				eb += 6
			elif enh == "glass":
				em *= 1.4
			elif enh == "lucky":
				# rolled once per REAL count (roll_luck) and shared with its counterfactuals;
				# hypothetical counts draw nothing, so tapping can't shift the Daily
				if opts.has("luck"):
					if _luck_hit(opts.luck, c):
						eb += CribData.FICKLE_BONUS
				elif CribData.FICKLE_PREVIEW_EV:
					eb += CribData.FICKLE_BONUS * CribData.FICKLE_HIT
		if is_crib:
			for c in hand:
				if c.get("enh") == "steel":
					ctx.mult += 0.6
		if eb:
			ctx.base += eb
			ctx["enhBase"] = eb
		if em != 1.0:
			ctx.mult *= em
			ctx["enhMult"] = em

	# gilded ranks pay out for every copy present
	if not JS.truthy(opts.get("noGild")):
		var g := 0
		for c in _all_of(hand, st):
			g += 4 * run.gilded.get(c.rank, 0)
		if g:
			ctx.base += g
			ctx["gildBonus"] = g
	var lv_gain := 0
	if not JS.truthy(opts.get("noLevels")):
		for e in res.events:
			lv_gain += CribData.LEVEL_GAIN * run.levels.get(e.kind, 0)
	if lv_gain:
		ctx.base += lv_gain
		ctx["levelBonus"] = lv_gain
	var snap := func() -> int: return maxi(0, JS.round_(ctx.base * ctx.mult))
	ctx["steps"] = []
	var prev: int = snap.call()
	ctx["baseOnly"] = prev
	for ch in run.active_charms():
		if JS.truthy(mods.get("noCharms")):
			break
		if JS.truthy(mods.get("charmlessBoss")) and run.is_boss():
			break
		if opts.get("skip") != null and is_same(opts.skip, ch):
			continue
		if opts.get("skip2") != null and is_same(opts.skip2, ch):
			continue
		var hit := false
		if ch.on_event.is_valid():
			for e in res.events:
				if ch.on_event.call(e, ctx):
					hit = true
		if ch.on_count.is_valid() and ch.on_count.call(ctx):
			hit = true
		if hit:
			ctx.fired.append(ch.name)
			var now: int = snap.call()
			ctx.steps.append({"name": ch.name, "gain": now - prev, "total": now,
				"base": ctx.base, "mult": ctx.mult})
			prev = now
	if JS.truthy(ctx.get("squareMult")):
		ctx.mult = ctx.mult * ctx.mult
	if JS.truthy(mods.multCap):
		ctx.mult = minf(ctx.mult, mods.multCap)
	if not is_crib and JS.truthy(mods.handQuarter):
		ctx.mult *= 0.25
	if is_crib and JS.truthy(mods.cribQuad):
		ctx.mult *= 4
	if JS.truthy(mods.halfCharmBoss) and run.is_boss():
		ctx.mult *= 0.5
	if not is_crib and JS.truthy(mods.get("handZero")):
		ctx.mult = 0.0
	if is_crib and JS.truthy(mods.get("cribHalf")):
		ctx.mult *= 0.5
	if is_crib and JS.truthy(mods.get("cribZero")):
		ctx.mult = 0.0
	elif is_crib:
		if JS.truthy(mods.get("miser")):
			ctx.mult *= 3
		elif not JS.truthy(mods.get("cribFull")):
			ctx.mult *= 0.5
	elif JS.truthy(mods.get("miser")):
		ctx.mult *= 0.5
	ctx["total"] = maxi(0, JS.round_(ctx.base * ctx.mult))
	# Charms only need round/run during the count. Keeping them would form a
	# RefCounted cycle (round.last_count -> ctx -> round) that Godot never frees.
	ctx.erase("round")
	ctx.erase("run")
	return ctx


## Fickle's outcome for each Fickle card in a REAL count, rolled once from the
## run rng. Pairs [card, hit], looked up by identity (duplicate cards are distinct).
func roll_luck(cards: Array) -> Array:
	var out := []
	for c in cards:
		if c != null and c.get("enh") == "lucky":
			out.append([c, run.rng.next() < CribData.FICKLE_HIT])
	return out


static func _luck_hit(luck: Array, c) -> bool:
	for pair in luck:
		if is_same(pair[0], c):
			return pair[1]
	return false


## Apply a REAL count's charm effects (Cutpurse, Usury, The Collector), once.
## Records res.glim, the Glim change, for the UI.
func apply_effects(res: Dictionary) -> void:
	if not res.has("essence"):
		res["glim"] = 0
		return
	res["glim"] = res.essence - res.essenceStart
	if res.glim:
		run.essence = maxi(0, run.essence + res.glim)
	for c in res.addCards:
		if not collected:   # The Collector: once a round
			run.cards.append(c)
			collected = true
			run.collected_count += 1


## Starter unknown: locked-in points plus the EV of the cut.
func preview(keep_idx: Array):
	if dealt == null:
		return null
	var hand: Array = keep_idx.map(func(i): return dealt[i])
	if starter != null:
		return run_count(hand)
	var sure = Cribbage.count_points(hand, null, false, mods)
	var ev = Cribbage.keep_ev_fast(hand, stock, mods)
	return {"blind": true, "sure": sure, "ev": ev, "events": Cribbage.count_hand(hand, null, false, mods).events}


func _invalidate_ev() -> void:
	_ev_table = null


func keep_table() -> Array:
	if _ev_table == null or not is_same(_ev_dealt, dealt) or _ev_stock_n != stock.size():
		_ev_table = Cribbage.keep_options_ev(dealt, stock, keep_count(), mods)
		_ev_dealt = dealt
		_ev_stock_n = stock.size()
	return _ev_table


func best_keep_ev() -> Dictionary:
	return keep_table()[0]


func keep_rank(keep_idx: Array) -> Dictionary:
	var opts := keep_table()
	var key_of := func(a: Array) -> String:
		var s := a.duplicate()
		s.sort()
		return ",".join(s.map(func(x): return str(x)))
	var key: String = key_of.call(keep_idx)
	var at := -1
	for i in opts.size():
		if key_of.call(opts[i].idx) == key:
			at = i
			break
	return {"rank": at + 1, "of": opts.size(), "best": opts[0]}


func commit(keep_idx: Array):
	if phase != "keep":
		return null
	var blind: bool = starter == null
	cut_starter()   # the reveal happens here
	var hand: Array = keep_idx.map(func(i): return dealt[i])
	if JS.truthy(mods.swapCrib) and crib.size() >= hand.size():
		var swap := crib.slice(0, hand.size())
		crib = crib.slice(hand.size()) + hand
		hand = swap
	# recuts2 (web: same): a blind cut that adds nothing to the kept hand is re-cut
	auto_recuts = 0
	if blind:
		while recuts_left > 0 and stock.size() > 0 and \
				Cribbage.count_hand(hand, starter, false, mods).base == Cribbage.count_hand(hand, null, false, mods).base:
			recut()
			auto_recuts += 1
	var thrown := []
	for i in dealt.size():
		if not keep_idx.has(i):
			thrown.append(dealt[i])
	var luck := roll_luck(hand + [live_starter(hand)])
	var res := run_count(hand, false, null, {"luck": luck})
	# the count, for the shop's Upgrade replay (presentation; capped, no draws)
	run.count_log.append({"hand": hand.duplicate(), "starter": starter, "starter2": starter2,
		"mods": mods.duplicate(true), "luck": luck,
		"deal_index": deal_index, "mulligans_left": mulligans_left, "deals_left": deals_left})
	if run.count_log.size() > CribRun.COUNT_LOG_MAX:
		run.count_log = run.count_log.slice(run.count_log.size() - CribRun.COUNT_LOG_MAX)

	# Counterfactual attribution: re-score with each charm removed, and with no cut.
	res["contrib"] = {}
	for ch in run.active_charms():
		var without := run_count(hand, false, null, {"skip": ch, "luck": luck})
		var d = res.total - without.total
		if d != 0:
			res.contrib[ch.name] = d
	# Synergy (pass 15, LOOP_AUDIT 7; presentation only): for two charms that both
	# scored, what they make together beyond their two separate credits:
	# total - without A - without B + without both. Pure recounts, no draws.
	res["synergy"] = {}
	var scored: Array = run.active_charms().filter(func(c): return res.contrib.has(c.name))
	for i in scored.size():
		for j in range(i + 1, scored.size()):
			var a: Charm = scored[i]
			var b: Charm = scored[j]
			var both := run_count(hand, false, null, {"skip": a, "skip2": b, "luck": luck})
			var syn = res.total - (res.total - res.contrib[a.name]) - (res.total - res.contrib[b.name]) + both.total
			if JS.round_(syn) > 0:
				res.synergy["%s + %s" % [a.name, b.name]] = syn
	var no_levels := run_count(hand, false, null, {"noLevels": true, "luck": luck})
	res["levelContrib"] = res.total - no_levels.total
	var no_cut := run_count(hand, false, null, {"noStarter": true, "luck": luck})
	res["cutGain"] = res.total - no_cut.total
	res["handOnly"] = no_cut.total
	# the real count's charm effects land once, after the counterfactuals
	apply_effects(res)

	# Glass can break, and Coin pays out: both resolve on the real commit only
	res["shattered"] = []
	res["coins"] = 0
	for c in hand + [starter]:
		if c.get("enh") == "coin":
			res.coins += 3
		if c.get("enh") == "glass" and run.rng.next() < 0.25:  # run rng: the Daily must match
			res.shattered.append(c)
			for i in run.cards.size():
				var x = run.cards[i]
				if x.rank == c.rank and x.suit == c.suit and x.get("enh") == "glass":
					run.cards.remove_at(i)
					break
	if res.coins:
		run.essence += res.coins
	shattered_all = shattered_all + res.shattered
	coins_all += res.coins
	for k in res.contrib:
		contrib_totals[k] = contrib_totals.get(k, 0) + res.contrib[k]
	for k in res.synergy:
		synergy_totals[k] = synergy_totals.get(k, 0) + res.synergy[k]
	level_total += res.levelContrib
	cut_total += res.cutGain

	var before := score
	# Only the earliest throws reach the four-card Crib; the rest are burned.
	var room := maxi(0, CribData.CRIB_SIZE - crib.size())
	crib.append_array(thrown.slice(0, room))
	burned = burned + thrown.slice(room)
	# counted cards go back for the next recycle, once (fixed with the JS: this
	# used to run twice, putting duplicates in the deck on every recycle)
	used = used + hand + ([starter] if starter != null else [])
	# Double Cut's second starter was revealed too: it goes back with the rest
	# (fixed with the JS; it used to vanish until round end).
	if starter2 != null:
		used.append(starter2)
	res["toCrib"] = mini(room, thrown.size())
	res["burnedNow"] = thrown.size() - res.toCrib
	score += res.total
	res["scoreBefore"] = before
	res["crossedTarget"] = before < target and score >= target
	res["wasFinalDeal"] = deals_left <= 1
	last_count = res
	deal_index += 1
	deals_left -= 1
	phase = "counted"
	return res


## Best possible keep for this deal against the known starter (coaching).
func best_keep() -> Dictionary:
	var opts := Cribbage.keep_options(dealt, starter, keep_count(), mods)
	var best: Dictionary = opts[0]
	return {"idx": best.idx, "total": run_count(best.idx.map(func(i): return dealt[i])).total}


## The Gathering: feeding the Crib well raises what it pays.
func crib_mult() -> float:
	if not Achv.has_system("crib_mult"):
		return 1.0
	var m := 1.0
	var suits := {}
	for c in crib:
		suits[c.suit] = suits.get(c.suit, 0) + 1
		if c.rank >= 11:
			m += 0.2
	for k in suits:
		if suits[k] >= 2:
			m += 0.3 * (suits[k] - 1)
	return m


## Round end: the Crib pays out.
func settle_crib() -> Dictionary:
	var hand := crib.duplicate()
	var ck: int = JS.or_(mods, "cribKeep", CribData.CRIB_SIZE)
	if hand.size() > ck:
		var opts := Cribbage.keep_options(hand, starter, ck, mods)
		hand = opts[0].idx.map(func(i): return crib[i])
	# The Crib's Own Cut: a second starter, drawn only for the Crib.
	if Achv.has_system("crib_cut") and not stock.is_empty():
		crib_starter = stock.pop_back()
		_invalidate_ev()
	var cs = crib_starter if crib_starter != null else starter
	var res: Dictionary = run_count(hand, true, cs, {"luck": roll_luck(hand + ([cs] if cs != null else []))}) if hand.size() >= 2 \
		else {"base": 0, "mult": 1, "total": 0, "events": [], "fired": []}
	apply_effects(res)
	var gm := crib_mult()
	if gm != 1.0:
		res["gathering"] = gm
		res.total = JS.round_(res.total * gm)
	crib_result = res
	score += res.total
	return res


## Who carried the round, and would you have failed without them?
## The round's best pair (round end), or null under SYNERGY_MIN points.
const SYNERGY_MIN := 5
func best_synergy():
	var best = null
	for k in synergy_totals:
		if JS.round_(synergy_totals[k]) >= SYNERGY_MIN and (best == null or synergy_totals[k] > synergy_totals[best]):
			best = k
	return {"pair": best, "points": JS.round_(synergy_totals[best])} if best != null else null


func mvp():
	var all := contrib_totals.duplicate()
	if level_total:
		all["Category levels"] = level_total
	if cut_total:
		all["The cut"] = cut_total
	var best = null
	for k in all:
		if best == null or all[k] > all[best]:
			best = k
	if best == null:
		return null
	var without = score - all[best]
	return {"name": best, "points": all[best], "without": without,
		"decisive": score >= target and without < target}


## Finish the moment you're over the line.
func cash_out() -> bool:
	if over:
		return won
	cashed_out = true
	return settle()


func settle() -> bool:
	if over:
		return won
	settle_crib()
	over = true
	if wager != null and not JS.truthy(mods.get("allExact")):
		# The exact score wins the unlock; missing it costs the prize, not the run.
		wager_won = score == wager_target
		won = score >= target
	elif JS.truthy(mods.get("allExact")):
		var ceil_: float = target * (1 + JS.or_(mods, "overBand", 0.15))
		won = score >= target and score <= ceil_
	else:
		won = score >= target
	margin = score - target
	var band := maxi(8, JS.round_(target * 0.12))
	narrow = won and margin <= band
	so_close = not won and -margin <= band
	# fold this round's attribution into the run total
	if run.contrib_run == null:
		run.contrib_run = {}
	var add := func(k: String, v):
		if v:
			run.contrib_run[k] = run.contrib_run.get(k, 0) + v
	for k in contrib_totals:
		add.call(k, contrib_totals[k])
	add.call("Category levels", level_total)
	add.call("The cut", cut_total)

	# Three ways to be paid: clearing, clearing EARLY, and clearing CLEAN.
	deals_spared = maxi(0, deals_left)
	mulligans_spared = maxi(0, mulligans_left)
	# The Stink Hole and Skunk Line (noCashOut): clearing early pays nothing extra
	early_bonus = deals_spared * 4 if won and not JS.truthy(mods.get("noCashOut")) else 0
	clean_bonus = mulligans_spared * 3 if won else 0
	base_glim = maxi(4, 6 + JS.round_(run.round_index() * 0.9)
		+ int(floor(maxi(0, score - target) / maxf(15, target * 0.25)))) if won else 0
	essence_earned = base_glim + early_bonus + clean_bonus if won else 0
	return won
