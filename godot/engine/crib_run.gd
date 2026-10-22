class_name CribRun
extends RefCounted
## Port of CribRun from web/cribrogue.js. A run: your deck, charms, Glim,
## Reckonings, and the Spoiler/Wager plan. With a seed it is deterministic.

var rng: JsRng
var seed = null
var street: Dictionary
var trial = null
var endless := false
var endless_round := 0
var meldling: String
var deck: Dictionary
var act := 1
var round := 1
var essence := 6
var skip_progress := 0
var skips := 0
var charms: Array = []
var levels := {"fifteen": 0, "pair": 0, "run": 0, "flush": 0}
var gilded := {}
var cards: Array = []
var boss_plan: Array = []
var wager_at := {}
var twist_plan := {}
## The run's latest hand counts (hand, cut, rules, luck), newest last, for the
## shop's Upgrade mark. Presentation only.
const COUNT_LOG_MAX := 24
var count_log: Array = []      ## "act-round" -> twist id (CribData.TWISTS)
var shop_state = null
var contrib_run = null
var daily = null
var collected_count := 0   ## cards The Collector has added this run
var deck_charm: Charm = null   ## the Meldling's bonus, built once per run


func _init(meldling_id: String, street_ = null, trial_ = null, seed_ = null) -> void:
	# With a seed the whole run is deterministic: same deck, Spoilers, shop.
	rng = JsRng.new(seed_) if seed_ != null else JS.unseeded
	seed = seed_
	street = street_ if street_ != null else {"id": 1, "name": "First Street", "mods": {}}
	trial = trial_
	meldling = meldling_id
	deck = CribData.DECKS[meldling_id]
	cards = Cribbage.deck()
	var rule: Dictionary = deck.get("rule", {})
	var mim: int = JS.or_(rule, "startMimics", 0)
	for i in mim:
		var pick := int(floor(rng.next() * cards.size()))
		var c := JS.copy(cards[pick])
		c["enh"] = "chameleon"
		cards[pick] = c
	var ex := extra_mods()
	if JS.truthy(ex.get("oneSuit")):
		for c in cards:
			c.suit = ex.oneSuit
	var trim: int = JS.or_(rule, "deckTrim", 0) + JS.or_(street.get("mods", {}), "deckTrim", 0)
	if trim:
		remove_random(trim)
	if JS.truthy(ex.get("deckCap")):
		cards = JS.shuffle(cards, rng).slice(0, ex.deckCap)
	boss_plan = CribData.plan_bosses(rng)
	plan_wagers()
	plan_twists()


func deck_size() -> int:
	return cards.size()


func add_cards(list: Array) -> void:
	for c in list:
		cards.append(JS.copy(c))


func remove_where(pred: Callable) -> int:
	var before := cards.size()
	cards = cards.filter(func(c): return not pred.call(c))
	return before - cards.size()


func remove_random(n: int) -> int:
	# the run's own rng (fixed with the JS): seeded runs, the Daily included, must
	# trim the same cards for everyone. It used Math.random.
	var d := JS.shuffle(cards.duplicate(), rng)
	cards = d.slice(n)
	return n


func histogram() -> Dictionary:
	var h := {}
	for c in cards:
		h[c.rank] = h.get(c.rank, 0) + 1
	return h


func level_cost_for(cat: String) -> int:
	return CribData.level_cost(levels[cat])


func gild_cost_for(rank: int) -> int:
	return 6 + gilded.get(rank, 0) * 5


func gild(rank: int) -> bool:
	var c := gild_cost_for(rank)
	if essence < c:
		return false
	essence -= c
	gilded[rank] = gilded.get(rank, 0) + 1
	return true


func gild_total() -> int:
	var t := 0
	for k in gilded:
		t += gilded[k]
	return t


func buy_level(cat: String) -> bool:
	var c := level_cost_for(cat)
	if essence < c:
		return false
	essence -= c
	levels[cat] += 1
	return true


func round_index() -> int:
	if endless:
		return Meta.ENDLESS_FROM + endless_round
	return (act - 1) * CribData.ROUNDS + round


## The next round's target, read only (the round end's "Next" line).
## The next slot's twist (read only, as next_target), or null.
func next_twist() -> Variant:
	var keep := [act, round]
	if round == CribData.ROUNDS:
		act += 1
		round = 1
	else:
		round += 1
	var t = twist()
	act = keep[0]
	round = keep[1]
	return t


func next_target() -> int:
	# the next slot's real target (its twist included); read only: put back at once
	var keep := [act, round]
	if round == CribData.ROUNDS:
		act += 1
		round = 1
	else:
		round += 1
	var t := target()
	act = keep[0]
	round = keep[1]
	return t


func target() -> int:
	var mul: float = JS.or_(street.get("mods", {}), "targetMul", 1)
	mul *= JS.or_(trial.mods, "targetMul", 1) if trial != null else 1
	mul *= CribData.TWIST_TARGET if twist() != null else 1.0
	return JS.round_(CribData.LADDER_BASE * pow(CribData.LADDER_GROWTH, round_index() - 1) * mul)


## Wagers are placed once, at run start, on random non-Spoiler rounds.
func plan_wagers() -> void:
	wager_at = {}
	if Achv.locked_systems().is_empty():
		return
	var slots_ := []
	for a in range(1, CribData.ACTS + 1):
		for r in range(2, CribData.ROUNDS):
			slots_.append("%d-%d" % [a, r])
	JS.shuffle(slots_, rng)
	var n := 1 + (1 if rng.next() < 0.45 else 0)  # one, sometimes two
	for i in mini(n, slots_.size()):
		wager_at[slots_[i]] = true


## Its own stream when seeded (seed + 7919), so deals, cuts and the shop draw
## what they did before twists; unseeded, the run's (JS.unseeded), as the web.
func plan_twists() -> void:
	var g: JsRng = JsRng.new(CribRun.twist_seed(seed)) if seed != null else rng
	twist_plan = {}
	var last := -1
	for a in range(1, CribData.ACTS + 1):
		for r in range(1, CribData.ROUNDS):
			var i := int(floor(g.next() * CribData.TWISTS.size()))
			if i == last:
				i = (i + 1) % CribData.TWISTS.size()
			twist_plan["%d-%d" % [a, r]] = CribData.TWISTS[i].id
			last = i


## The plan as sorted "act-round=id" strings (the parity fixtures' form).
## The web's twistSeed: seed + 7919, then a 32-bit integer mix (pass 18;
## nearby seeds opened act 1 on the same twist without it).
static func twist_seed(sd: int) -> int:
	var x := (sd + CribData.TWIST_SEED_STEP) & 0xFFFFFFFF
	x = (((x >> 16) ^ x) * 0x45D9F3B) & 0xFFFFFFFF
	x = (((x >> 16) ^ x) * 0x45D9F3B) & 0xFFFFFFFF
	x = ((x >> 16) ^ x) & 0xFFFFFFFF
	return x if x != 0 else 1


func twist_sig() -> Array:
	var ks: Array = twist_plan.keys()
	ks.sort()
	return ks.map(func(k): return "%s=%s" % [k, twist_plan[k]])


func twist() -> Variant:
	if endless or is_boss() or is_wager():
		return null
	return CribData.twist_by_id(twist_plan.get("%d-%d" % [act, round]))


func is_wager() -> bool:
	return not is_boss() and JS.truthy(wager_at.get("%d-%d" % [act, round]))


func is_boss() -> bool:
	if endless:
		return (endless_round % 3) == 2
	if round == CribData.ROUNDS:
		return true
	return JS.truthy(street.get("mods", {}).get("extraSpoiler")) and round == CribData.ROUNDS - 1   # the round before the act's Spoiler


func slots() -> int:
	var bonus := 1 if Achv.has_system("sixth_slot") else 0
	return maxi(3, CribData.CHARM_SLOTS + bonus + int(JS.or_(street.get("mods", {}), "slots", 0)))


func boss():
	if not is_boss():
		return null
	if JS.truthy(extra_mods().get("allRuinous")):
		var ruin := CribData.BOSS_POOL.filter(func(b): return b.sev == 3)
		return ruin[(act * 3 + round) % ruin.size()]
	if round == CribData.ROUNDS - 1:   # the extra Spoiler
		return CribData.BOSS_POOL[(act * 7 + 3) % CribData.BOSS_POOL.size()]
	return boss_plan[act - 1]


## Street and Trial rules.
func extra_mods() -> Dictionary:
	var out := {}
	out.merge(street.get("mods", {}), true)
	if trial != null:
		out.merge(trial.get("mods", {}), true)
	return out


const _OVERRIDE_KEYS := ["flushNeed", "runNeed", "fifteenPoints", "nobsPoints", "cribKeep"]
## Every Street/Trial key must be listed here or it silently never applies.
const _EXTRA_KEYS := ["hideTracker", "noRecycle", "charmlessBoss", "noCashOut",
	"cribHalf", "handZero", "allExact", "noShop", "allBrittle",
	"allRuinous", "oneSuit", "deckCap", "markCostMul",
	"handQuarter", "cribQuad", "halfCharmBoss", "overBand"]


## All passive rules merged: deck + charms + Street/Trial + boss.
func rules() -> Dictionary:
	var r := {"nobsPoints": 1, "fifteenPoints": 2, "flushNeed": 4, "recuts": 0,
		"dealBonus": 0, "dealtBonus": 0, "keepPenalty": 0,
		"mulliganBonus": 0, "cribKeep": 4, "keepBonus": 0, "pairScale": 1,
		"roundTrim": 0, "multCap": 0, "deadSuit": null,
		"onlyRuns": false, "onlyFifteens": false, "onlyFlush": false, "swapCrib": false,
		"runNeed": 3, "flushPairs": false,
		"handQuarter": false, "cribQuad": false, "halfCharmBoss": false, "overBand": 0}
	var merge := func(src: Dictionary):
		for k in src:
			var v = src[k]
			if JS.is_num(v) and r.has(k):
				if k in _OVERRIDE_KEYS:
					r[k] = v
				elif k == "pairScale":
					r[k] = r[k] * v
				else:
					r[k] = r[k] + v
			else:
				r[k] = v
	if deck.get("rule") != null:
		merge.call(deck.rule)
	for c in charms:
		if c.rule != null:
			merge.call(c.rule)
	var ex := extra_mods()
	for k in ["dealBonus", "mulliganBonus"]:
		if JS.is_num(ex.get(k)):
			r[k] += ex[k]
	for k in _EXTRA_KEYS:
		if ex.has(k) and ex[k] != null:
			r[k] = ex[k]
	var b = boss()
	if b != null:
		merge.call(b.rule)
	# a twist only ever helps: the better of it and what's already there
	var tw = twist()
	if tw != null:
		for k in tw.rule:
			var v = tw.rule[k]
			if k == "flushNeed":
				r[k] = mini(r[k], v)
			elif k in ["fifteenPoints", "nobsPoints"]:
				r[k] = maxi(r[k], v)
			elif k in ["mulliganBonus", "dealtBonus"]:
				r[k] += v
			else:
				r[k] = v
	return r


## Deck bonus behaves as a permanent charm, placed first.
func active_charms() -> Array:
	var list := charms.duplicate()
	if deck.get("charm") != null:
		# ONE object per run (fixed with the JS): commit's counterfactual skips
		# charms by identity, so a fresh object per call was never credited.
		if deck_charm == null:
			deck_charm = Charm.new()
			deck_charm.name = deck.name
			deck_charm.tier = 0
			deck_charm.on_event = deck.charm.get("on_event", Callable())
			deck_charm.on_count = deck.charm.get("on_count", Callable())
		list.push_front(deck_charm)
	return list


func enter_endless() -> void:
	endless = true
	act = CribData.ACTS
	round = CribData.ROUNDS


func advance() -> bool:
	round += 1
	if round > CribData.ROUNDS:
		round = 1
		act += 1
	return act > CribData.ACTS


func is_full() -> bool:
	return charms.size() >= slots()


## Charms resolve left to right, so order is a real optimisation layer.
func move_charm(from: int, to: int) -> bool:
	if from == to or from < 0 or to < 0:
		return false
	if from >= charms.size() or to >= charms.size():
		return false
	var c = charms.pop_at(from)
	charms.insert(to, c)
	return true


func score_with_order(rd, hand: Array, order: Array) -> int:
	var saved := charms
	charms = order.filter(func(i): return i >= 0 and i < saved.size()).map(func(i): return saved[i])
	var total: int = rd.run_count(hand).total
	charms = saved
	return total


## Best arrangement of what you own, for the auto-sort button.
func best_order(rd, hand: Array):
	var n := charms.size()
	if n < 2 or n > 6:
		return null
	var best = null
	for perm in JS.permutations(range(n)):
		var t := score_with_order(rd, hand, perm)
		if best == null or t > best.total:
			best = {"order": perm.duplicate(), "total": t}
	return best


func sell(id: String) -> int:
	for i in charms.size():
		if charms[i].id == id:
			var refund := maxi(2, charms[i].cost / 2)
			charms.remove_at(i)
			essence += refund
			return refund
	return 0


## Roll by rarity first, then pick within that band.
func roll_shop(n := 3) -> Array:
	var owned := {}
	for c in charms:
		owned[c.id] = true
	var pool := CribData.CHARMS.filter(func(c): return not owned.has(c.id))
	var out := []
	var guard := 0
	while out.size() < n and guard < 200:
		guard += 1
		var rar := CribData.roll_rarity(rng, int(street.get("id", 0)) >= 4 or endless)
		var band := pool.filter(func(c): return c.rarity == rar and not out.has(c))
		var from := band if not band.is_empty() else pool.filter(func(c): return not out.has(c))
		if from.is_empty():
			break
		out.append(from[int(floor(rng.next() * from.size()))])
	return out


func open_shop() -> Dictionary:
	var offer := roll_shop(3)
	var n_cards := 4 if Achv.has_system("deep_stall") else 3
	var cs := []
	for i in n_cards:
		cs.append(CribData.roll_card_offer(rng))
	shop_state = {"offer": offer, "cards": cs, "rerolls": 0}
	return shop_state


func buy_card(entry: Dictionary) -> bool:
	if essence < entry.cost:
		return false
	essence -= entry.cost
	cards.append(JS.copy(entry.card))
	return true


func reroll_cost() -> int:
	return 3 + 2 * (shop_state.rerolls if shop_state != null else 0)


func reroll() -> bool:
	var c := reroll_cost()
	if essence < c:
		return false
	essence -= c
	shop_state.rerolls += 1
	shop_state.offer = roll_shop(3)
	shop_state.cards = [CribData.roll_card_offer(rng), CribData.roll_card_offer(rng), CribData.roll_card_offer(rng)]
	return true


func run_mvp():
	var c: Dictionary = contrib_run if contrib_run != null else {}
	var best = null
	for k in c:
		if best == null or c[k] > c[best]:
			best = k
	return {"name": best, "points": JS.round_(c[best])} if best != null else null
