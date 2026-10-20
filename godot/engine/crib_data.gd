class_name CribData
extends RefCounted
## Port of the data half of web/cribrogue.js: constants, marks, charms,
## Meldlings (decks), Spoilers (bosses) and the shop rollers.

const ACTS := 5
const ROUNDS := 3   ## 3 rounds an act (2026-10-20, Ziah; tools/sim/run_length.sh)
const LADDER_BASE := 36
const LADDER_GROWTH := 1.29   ## was 1.19 at 5 rounds an act; 1.29 matches its clear rate
const DEALS := 4
const DEALT := 6
const KEEP := 4
## Hard cap on charms. Without it the AI hoarded 18 and cleared 90% of runs.
const CHARM_SLOTS := 5
const BASE_MULLIGANS := 2
const CRIB_SIZE := 4
const SKIP_COST := 100

## Fickle: a 1 in 4 chance of +25 base on a real count. Hypothetical counts show
## its expected +6.25 (Ziah's call); FICKLE_PREVIEW_EV = false shows no bonus.
const FICKLE_HIT := 0.25
const FICKLE_BONUS := 25
const FICKLE_PREVIEW_EV := true

## MARKS. Key order matters: rollCardOffer picks by index.
const ENHANCEMENTS := {
	"gilded": {"name": "Sunlit", "tint": "#e8b64c", "tag": "\u2600", "cost": 5,
		"text": "+6 base whenever this card is counted."},
	"glass": {"name": "Brittle", "tint": "#74e0d0", "tag": "\u2727", "cost": 7,
		"text": "x1.4 mult when counted. 1 in 4 chance it breaks for good."},
	"chameleon": {"name": "Mimic", "tint": "#c96fd6", "tag": "\u2248", "cost": 8,
		"text": "Wears any suit it likes, for flushes."},
	"steel": {"name": "Offering", "tint": "#9aa6bf", "tag": "\u2020", "cost": 6,
		"text": "+0.6 mult, but only if you give it to the Crib."},
	"coin": {"name": "Minted", "tint": "#6fc98a", "tag": "\u25c8", "cost": 5,
		"text": "+3 Glim each time it is counted."},
	"lucky": {"name": "Fickle", "tint": "#e8804c", "tag": "?", "cost": 6,
		"text": "1 in 4 chance of +25 base. Otherwise nothing."},
}

## Fives make fifteen with every ten-card, so the market keeps them rare.
const CARD_WEIGHT := {1: 6, 2: 6, 3: 6, 4: 6, 5: 1, 6: 5, 7: 5, 8: 5, 9: 5, 10: 3, 11: 3, 12: 3, 13: 3}
const RANK_PREMIUM := {5: 9, 10: 3, 11: 3, 12: 3, 13: 3}

## Charm quality, ascending.
const RARITY := {
	"common": {"name": "Worn", "weight": 50, "tint": "#8fa3c8"},
	"uncommon": {"name": "Keen", "weight": 30, "tint": "#6fc98a"},
	"rare": {"name": "Gleaming", "weight": 15, "tint": "#e8b64c"},
	"legendary": {"name": "Hallowed", "weight": 5, "tint": "#d06fd6"},
	"mythic": {"name": "Mythic", "weight": 2, "tint": "#ff6b8a"},
}
const RARITY_ORDER := ["common", "uncommon", "rare", "legendary", "mythic"]

const LEVEL_CATS := ["fifteen", "pair", "run", "flush"]
const LEVEL_GAIN := 3

const SUIT_OPPOSE := {"S": "H", "H": "S", "C": "D", "D": "C"}
const AFFINITY_WEAK := 0.6
const AFFINITY_STRONG := 1.35

const BOSS_POOL := [
	# severity 1
	{"id": "ashfall", "name": "Ashfall", "art": "famine", "sev": 1, "text": "One suit turns to ash. Those cards are inert.", "rule": {"noFlush": true, "deadSuitRandom": true}, "align": "S"},
	{"id": "auditor", "name": "The Auditor", "art": "auditor", "sev": 1, "text": "Fifteens score 1 instead of 2.", "rule": {"fifteenPoints": 1}, "align": "H"},
	{"id": "shortstop", "name": "Shortstop", "art": "jokester", "sev": 1, "text": "Runs score nothing, and pairs score half.", "rule": {"noRuns": true, "pairScale": 0.5}, "align": "C"},
	{"id": "blight", "name": "Blight", "art": "deadwood", "sev": 1, "text": "Pairs score half.", "rule": {"pairScale": 0.5}, "align": "D"},
	{"id": "chains", "name": "Chains", "art": "leaden", "sev": 1, "text": "No mulligans and no recuts.", "rule": {"mulliganBonus": -9, "recuts": 0}},
	# severity 2
	{"id": "irongrip", "name": "Iron Grip", "art": "leaden", "sev": 2, "text": "You keep one card fewer.", "rule": {"keepPenalty": 1}, "align": "S"},
	{"id": "famine", "name": "Famine", "art": "famine", "sev": 2, "text": "One fewer deal this round.", "rule": {"dealBonus": -1}, "align": "H"},
	{"id": "thief", "name": "The Thief", "art": "thief", "sev": 2, "text": "10 cards are stolen from your deck.", "rule": {"roundTrim": 10}, "align": "C"},
	{"id": "curse", "name": "Miser's Curse", "art": "kingpin", "sev": 2, "text": "The Crib scores nothing.", "rule": {"cribZero": true}},
	{"id": "fog", "name": "The Fog", "art": "fog", "sev": 2, "text": "Your deck tracker is hidden.", "rule": {"hideTracker": true}, "align": "D"},
	# severity 3
	{"id": "leaden", "name": "Leaden", "art": "leaden", "sev": 3, "text": "Your multiplier is capped at x4.", "rule": {"multCap": 4}},
	{"id": "puritan", "name": "Puritan", "art": "auditor", "sev": 3, "text": "Pairs score nothing at all.", "rule": {"noPairs": true}, "align": "S"},
	{"id": "drought", "name": "Drought", "art": "famine", "sev": 3, "text": "One fewer deal, and no mulligans.", "rule": {"dealBonus": -1, "mulliganBonus": -9}, "align": "H"},
	{"id": "hush", "name": "The Hush", "art": "fog", "sev": 2, "text": "Charms score nothing this round.", "rule": {"noCharms": true}, "align": "H"},
	{"id": "levy", "name": "The Levy", "art": "thief", "sev": 2, "text": "You start the round with no Glim.", "rule": {"levy": true}, "align": "C"},
	{"id": "shears", "name": "Shears", "art": "jokester", "sev": 3, "text": "Your deck is cut to 30 cards for this round.", "rule": {"roundTrim": 99}, "align": "D"},
	{"id": "eclipse", "name": "Eclipse", "art": "eclipse", "sev": 3, "text": "Fifteens score 1, flushes and nobs score nothing.", "rule": {"fifteenPoints": 1, "noFlush": true, "noNobs": true}},
]
const ACT_SEVERITY := [1, 1, 2, 2, 3]

static var CHARMS: Array = _build_charms()
static var DECKS: Dictionary = _build_decks()


static func level_cost(lv: int) -> int:
	return 4 + JS.round_(lv * 2.2)


static func charm_by_id(id: String) -> Charm:
	for c in CHARMS:
		if c.id == id:
			return c
	return null


# ------------------------------------------------------------------ rollers
static func roll_card_rank(rng: JsRng = null) -> int:
	var r_: JsRng = rng if rng != null else JS.unseeded
	var total := 0
	for k in CARD_WEIGHT:
		total += CARD_WEIGHT[k]
	var r := r_.next() * total
	for k in JS.num_keys(CARD_WEIGHT):
		r -= CARD_WEIGHT[k]
		if r <= 0:
			return k
	return 7


static func roll_card_offer(rng: JsRng = null) -> Dictionary:
	var r_: JsRng = rng if rng != null else JS.unseeded
	var rank := roll_card_rank(r_)
	var suit: String = Cribbage.SUITS[int(floor(r_.next() * 4))]
	var card := {"rank": rank, "suit": suit}
	var cost: int = 4 + RANK_PREMIUM.get(rank, 0)
	# Split cards: two ranks on one card, unlocked from a Wager.
	if Achv.has_system("split_cards") and r_.next() < 0.22:
		var r2 := roll_card_rank(r_)
		if r2 == rank:
			r2 = (rank % 13) + 1
		card["rank2"] = r2
		card["suit2"] = Cribbage.SUITS[int(floor(r_.next() * 4))]
		cost += 7 + JS.round_(RANK_PREMIUM.get(r2, 0) * 0.5)
	if r_.next() < 0.55:
		var keys := ENHANCEMENTS.keys()
		var enh: String = keys[int(floor(r_.next() * keys.size()))]
		card["enh"] = enh
		cost += ENHANCEMENTS[enh].cost
	return {"card": card, "cost": cost}


## Mythics only exist deep on the Streets.
static func roll_rarity(rng: JsRng, allow_mythic := false) -> String:
	var pool := RARITY_ORDER if allow_mythic else RARITY_ORDER.filter(func(k): return k != "mythic")
	var total := 0
	for k in pool:
		total += RARITY[k].weight
	var r := rng.next() * total
	for k in pool:
		r -= RARITY[k].weight
		if r <= 0:
			return k
	return "common"


static func plan_bosses(rng: JsRng = null) -> Array:
	var r_: JsRng = rng if rng != null else JS.unseeded
	var used := {}
	var plan := []
	for act in range(1, ACTS + 1):
		var sev: int = ACT_SEVERITY[act - 1]
		var band := BOSS_POOL.filter(func(b): return b.sev == sev and not used.has(b.id))
		if band.is_empty():
			band = BOSS_POOL.filter(func(b): return not used.has(b.id))
		var pick: Dictionary = band[int(floor(r_.next() * band.size()))]
		used[pick.id] = true
		plan.append(pick)
	return plan


# ------------------------------------------------------------------ charm helpers
static func _base(ctx: Dictionary, n) -> bool:
	ctx.base += n
	return true


static func _xmult(ctx: Dictionary, f: float) -> bool:
	ctx.mult *= f
	return true


static func _amult(ctx: Dictionary, f: float) -> bool:
	ctx.mult += f
	return true


static func _n_all(ctx: Dictionary, pred: Callable) -> int:
	return ctx.all.filter(pred).size()


static func _n_kind(ctx: Dictionary, kind: String) -> int:
	return ctx.events.filter(func(e): return e.kind == kind).size()


static func _has_kind(ctx: Dictionary, kind: String) -> bool:
	return ctx.events.any(func(e): return e.kind == kind)


static func _kinds(ctx: Dictionary) -> int:
	var s := {}
	for e in ctx.events:
		s[e.kind] = true
	return s.size()


static func _is_red(c: Dictionary) -> bool:
	return c.suit == "H" or c.suit == "D"


static func _courts(ctx: Dictionary) -> int:
	return _n_all(ctx, func(c): return c.rank >= 11)


## Redesigned with the JS (was: copy the last counted card, i.e. the random starter,
## every count). The card in the most scoring events joins once a round (an intent,
## applied by CribRound.apply_effects), and each card collected so far adds +2 base.
static func _collector(ctx: Dictionary) -> bool:
	var n: int = ctx.run.collected_count
	if n:
		ctx.base += 2 * n
	var best = null
	var best_n := 0
	for c in ctx.all:
		var k := 0
		for e in ctx.events:
			# identity, as JS includes(): Array.has compares Dictionaries by value
			if e.cards.any(func(x): return is_same(x, c)):
				k += 1
		if k > best_n:
			best = c
			best_n = k
	if best != null:
		ctx.addCards.append(JS.copy(best))
	return n > 0 or best != null


static func _echo(ctx: Dictionary) -> bool:
	if ctx.events.is_empty():
		return false
	var best: Dictionary = ctx.events[0]
	for e in ctx.events:
		if e.points > best.points:
			best = e
	ctx.base += best.points
	return true


static func _usury(ctx: Dictionary) -> bool:
	ctx.mult *= 2   # was x3 (64.6% clear when owned early vs 13.8% with no charm)
	ctx.essence = maxi(0, ctx.essence - 4)  # projected Glim; applied on real counts only
	return true


static func _cutpurse(ctx: Dictionary) -> bool:
	ctx.essence += 2  # projected Glim; applied on real counts only
	return true


static func _slowburn(ctx: Dictionary) -> bool:
	var n := 0
	for k in ctx.run.levels:
		n += ctx.run.levels[k]
	return _amult(ctx, 0.12 * n) if n else false


static func _alchemist(run) -> void:
	for c in run.cards:
		if c.rank >= 2 and c.rank <= 4:
			c.rank = 5


# ------------------------------------------------------------------ charms
static func _build_charms() -> Array:
	var C := func(d: Dictionary) -> Charm: return Charm.make(d)
	return [
		# ---- tier 1: flat, keyed to a scoring category
		C.call({"id": "fifteener", "name": "Fifteener", "tier": 1, "cost": 5, "rarity": "common", "cat": "fifteen", "text": "+3 per fifteen.",
			"on_event": func(e, ctx): return _base(ctx, 3) if e.kind == "fifteen" else false}),
		C.call({"id": "twinner", "name": "Twinner", "tier": 1, "cost": 5, "rarity": "common", "cat": "pair", "text": "+4 per pair scored.",
			"on_event": func(e, ctx): return _base(ctx, 4) if e.kind == "pair" else false}),
		C.call({"id": "rambler", "name": "Rambler", "tier": 1, "cost": 5, "rarity": "common", "cat": "run", "text": "+5 per run.",
			"on_event": func(e, ctx): return _base(ctx, 5) if e.kind == "run" else false}),
		C.call({"id": "peacock", "name": "Peacock", "tier": 1, "cost": 6, "rarity": "common", "cat": "flush", "text": "+8 for a flush.",
			"on_event": func(e, ctx): return _base(ctx, 8) if e.kind == "flush" else false}),
		C.call({"id": "facecard", "name": "Face Value", "tier": 1, "cost": 6, "rarity": "common", "cat": "fifteen", "text": "+2 per J/Q/K in hand.",
			"on_count": func(ctx): return _base(ctx, 2 * _courts(ctx)) if _courts(ctx) else false}),

		# ---- tier 2: multipliers
		C.call({"id": "counting", "name": "The Counting House", "tier": 2, "cost": 9, "rarity": "rare", "cat": "mult", "text": "x1.25 per distinct category scored.",
			"on_count": func(ctx): return _xmult(ctx, pow(1.25, _kinds(ctx))) if _kinds(ctx) else false}),
		C.call({"id": "fever", "name": "Fifteen Fever", "tier": 2, "cost": 9, "rarity": "uncommon", "cat": "mult", "text": "x1.8 if 3 or more fifteens.",
			"on_count": func(ctx): return _xmult(ctx, 1.8) if _n_kind(ctx, "fifteen") >= 3 else false}),
		C.call({"id": "suited", "name": "Suited", "tier": 2, "cost": 8, "rarity": "uncommon", "cat": "mult", "text": "x1.7 if the hand has a flush.",
			"on_count": func(ctx): return _xmult(ctx, 1.7) if _has_kind(ctx, "flush") else false}),
		C.call({"id": "streak", "name": "Streak", "tier": 2, "cost": 11, "rarity": "rare", "cat": "mult", "text": "x1.3 compounding each deal this round.",
			"on_count": func(ctx): return _xmult(ctx, pow(1.3, ctx.round.deal_index))}),
		C.call({"id": "keystone2", "name": "Keystone", "tier": 2, "cost": 10, "rarity": "uncommon", "cat": "mult", "text": "x1.6 mult, always.",
			"on_count": func(ctx): return _xmult(ctx, 1.6)}),
		C.call({"id": "thirdtime", "name": "Third Time Lucky", "tier": 2, "cost": 10, "rarity": "rare", "cat": "mult", "text": "x2.5 on every third deal.",
			"on_count": func(ctx): return _xmult(ctx, 2.5) if (ctx.round.deal_index + 1) % 3 == 0 else false}),
		C.call({"id": "purse", "name": "Deep Pockets", "tier": 2, "cost": 12, "rarity": "rare", "cat": "mult", "text": "x1.15 per charm you own.",
			"on_count": func(ctx): return _xmult(ctx, pow(1.15, ctx.run.charms.size()))}),

		# ---- tier 3: rule-breakers
		C.call({"id": "aceeleven", "name": "Aces High", "tier": 3, "cost": 8, "rarity": "uncommon", "cat": "rule", "text": "Aces count 11 toward fifteens.",
			"rule": {"aceEleven": true}}),
		# wrapRuns: read by Cribbage.count_hand_core (runs may pass K-A).
		C.call({"id": "wrap", "name": "Round the Bend", "tier": 3, "cost": 10, "rarity": "rare", "cat": "rule", "text": "Runs may wrap K-A-2.",
			"rule": {"wrapRuns": true}}),
		C.call({"id": "shortflush", "name": "Half a Flush", "tier": 3, "cost": 9, "rarity": "uncommon", "cat": "flush", "text": "Three-card flushes count.",
			"rule": {"flushNeed": 3}}),
		C.call({"id": "recut", "name": "Recut", "tier": 3, "cost": 9, "rarity": "uncommon", "cat": "rule", "text": "A cut that adds nothing to your hand is re-cut, once per deal.",
			"rule": {"recuts": 1}}),
		C.call({"id": "cribmaster", "name": "Crib Master", "tier": 3, "cost": 10, "rarity": "rare", "cat": "rule", "text": "The Crib scores at full mult.",
			"rule": {"cribFull": true}}),
		C.call({"id": "fifthdeal", "name": "One More Deal", "tier": 3, "cost": 12, "rarity": "rare", "cat": "rule", "text": "+1 deal each round.",
			"rule": {"dealBonus": 1}}),
		C.call({"id": "widedeal", "name": "Generous Deal", "tier": 3, "cost": 13, "rarity": "rare", "cat": "rule", "text": "You are dealt 7 cards, not 6.",
			"rule": {"dealtBonus": 1}}),

		# ---- passives that change HOW you play
		C.call({"id": "foresight", "name": "Foresight", "tier": 3, "cost": 11, "rarity": "legendary", "cat": "rule",
			"text": "The starter is cut BEFORE you keep. You always know the answer.", "rule": {"foresight": true}}),
		C.call({"id": "doublecut", "name": "Double Cut", "tier": 3, "cost": 12, "rarity": "rare", "cat": "rule",
			"text": "Two starters are cut; your hand counts against the better one.", "rule": {"doubleCut": true}}),
		C.call({"id": "royalblood", "name": "Royal Blood", "tier": 3, "cost": 10, "rarity": "legendary", "cat": "deck",
			"text": "Remove every 2-6 from your deck. J/Q/K score +7 each.",
			"on_acquire": func(run): run.remove_where(func(c): return c.rank >= 2 and c.rank <= 6),
			"on_count": func(ctx): return _base(ctx, 7 * _courts(ctx)) if _courts(ctx) else false}),
		C.call({"id": "peasant", "name": "Peasant Stock", "tier": 3, "cost": 9, "rarity": "rare", "cat": "deck",
			"text": "Remove every J/Q/K from your deck. x1.6 mult.",
			"on_acquire": func(run): run.remove_where(func(c): return c.rank >= 11),
			"on_count": func(ctx): return _xmult(ctx, 1.6)}),
		C.call({"id": "loaded", "name": "Cooked Deck", "tier": 3, "cost": 10, "rarity": "rare", "cat": "deck",
			"text": "Add four extra 5s to your deck.",
			"on_acquire": func(run): run.add_cards([{"rank": 5, "suit": "S"}, {"rank": 5, "suit": "H"}, {"rank": 5, "suit": "C"}, {"rank": 5, "suit": "D"}])}),
		C.call({"id": "thindeck", "name": "Whittled", "tier": 3, "cost": 9, "rarity": "rare", "cat": "deck",
			"text": "Remove 8 random cards. +1 deal each round.",
			"on_acquire": func(run): run.remove_random(8), "rule": {"dealBonus": 1}}),
		C.call({"id": "secondchance", "name": "Change of Heart", "tier": 3, "cost": 7, "rarity": "uncommon", "cat": "rule",
			"text": "+2 mulligans each round.", "rule": {"mulliganBonus": 2}}),
		C.call({"id": "greedycrib", "name": "Greedy Crib", "tier": 3, "cost": 11, "rarity": "rare", "cat": "rule",
			"text": "The Crib keeps its best 5 cards instead of 4.", "rule": {"cribKeep": 5}}),
		C.call({"id": "miser", "name": "Miser", "tier": 3, "cost": 10, "rarity": "legendary", "cat": "rule",
			"text": "Hands score x0.5. The Crib scores x3.", "rule": {"miser": true}}),

		# ---- legendaries
		C.call({"id": "sovereign", "name": "Sovereign", "tier": 3, "cost": 12, "rarity": "legendary", "cat": "mult",
			"text": "x1.3 mult for each J/Q/K in the counted hand.",
			"on_count": func(ctx): return _xmult(ctx, pow(1.3, _courts(ctx))) if _courts(ctx) else false}),
		C.call({"id": "nineteen", "name": "The Nineteen", "tier": 3, "cost": 11, "rarity": "legendary", "cat": "rule",
			"text": "A hand that scores nothing scores 45 instead.",
			"on_count": func(ctx): return _base(ctx, 45) if ctx.base == 0 else false}),
		C.call({"id": "doubling", "name": "Doubling Cube", "tier": 3, "cost": 12, "rarity": "legendary", "cat": "mult",
			"text": "Your final deal of each round scores x3.",
			"on_count": func(ctx): return _xmult(ctx, 3) if ctx.round.deals_left <= 1 else false}),
		C.call({"id": "alchemist", "name": "Alchemist", "tier": 3, "cost": 11, "rarity": "legendary", "cat": "deck",
			"text": "Every 2, 3 and 4 in your deck becomes a 5.", "on_acquire": func(run): _alchemist(run)}),
		C.call({"id": "overflow", "name": "Overflow", "tier": 3, "cost": 13, "rarity": "legendary", "cat": "mult",
			"text": "Your multiplier is squared.",
			"on_count": func(ctx): ctx.squareMult = true; return true}),

		# ---- second wave
		C.call({"id": "quartermaster", "name": "Quartermaster", "tier": 1, "cost": 5, "rarity": "common", "cat": "fifteen",
			"text": "+4 base per card of your Meldling's suit.",
			"on_count": func(ctx):
				var su: String = DECKS[ctx.run.meldling].suit
				var n := _n_all(ctx, func(c): return c.suit == su)
				return _base(ctx, 4 * n) if n else false}),
		C.call({"id": "evenhand", "name": "Even Hand", "tier": 1, "cost": 5, "rarity": "common", "cat": "pair",
			"text": "+5 base per even-ranked card counted.",
			"on_count": func(ctx):
				var n := _n_all(ctx, func(c): return c.rank % 2 == 0)
				return _base(ctx, 5 * n) if n else false}),
		C.call({"id": "oddfellow", "name": "Odd Fellow", "tier": 1, "cost": 5, "rarity": "common", "cat": "run",
			"text": "+5 base per odd-ranked card counted.",
			"on_count": func(ctx):
				var n := _n_all(ctx, func(c): return c.rank % 2 == 1)
				return _base(ctx, 5 * n) if n else false}),
		C.call({"id": "shortmemory", "name": "Short Memory", "tier": 2, "cost": 8, "rarity": "uncommon", "cat": "mult",
			"text": "x1.5 mult on your first deal of each round.",
			"on_count": func(ctx): return _xmult(ctx, 1.5) if ctx.round.deal_index == 0 else false}),
		C.call({"id": "lastword", "name": "The Last Word", "tier": 2, "cost": 9, "rarity": "uncommon", "cat": "mult",
			"text": "x2 mult on your final deal of each round.",
			"on_count": func(ctx): return _xmult(ctx, 2) if ctx.round.deals_left <= 1 else false}),
		C.call({"id": "thinice", "name": "Thin Ice", "tier": 2, "cost": 10, "rarity": "rare", "cat": "mult",
			"text": "x2.2 mult while your deck holds fewer than 30 cards.",
			"on_count": func(ctx): return _xmult(ctx, 2.2) if ctx.run.deck_size() < 30 else false}),
		C.call({"id": "hoarder", "name": "Hoarder", "tier": 2, "cost": 10, "rarity": "rare", "cat": "mult",
			"text": "x1.25 mult per mulligan you still hold.",
			"on_count": func(ctx): return _xmult(ctx, pow(1.25, ctx.round.mulligans_left)) if ctx.round.mulligans_left else false}),
		C.call({"id": "cutpurse", "name": "Cutpurse", "tier": 3, "cost": 9, "rarity": "rare", "cat": "rule",
			"text": "+2 Glim every time you count a hand.", "on_count": func(ctx): return _cutpurse(ctx)}),
		C.call({"id": "steadyhand", "name": "Steady Hand", "tier": 3, "cost": 10, "rarity": "rare", "cat": "rule",
			"text": "+1 mulligan. A cut that adds nothing to your hand is re-cut, once per deal.", "rule": {"mulliganBonus": 1, "recuts": 1}}),

		# ---- additive-mult charms: these are what make ORDER matter
		C.call({"id": "ballast", "name": "Ballast", "tier": 2, "cost": 8, "rarity": "uncommon", "cat": "mult",
			"text": "+0.8 mult. Placement matters: put it early.", "on_count": func(ctx): return _amult(ctx, 0.8)}),
		C.call({"id": "tallyman", "name": "Tallyman", "tier": 2, "cost": 9, "rarity": "uncommon", "cat": "mult",
			"text": "+0.3 mult per distinct category you scored.",
			"on_count": func(ctx): return _amult(ctx, 0.3 * _kinds(ctx)) if _kinds(ctx) else false}),
		C.call({"id": "slowburn", "name": "Slow Burn", "tier": 2, "cost": 10, "rarity": "rare", "cat": "mult",
			"text": "+0.12 mult per Reckoning you have taken.", "on_count": func(ctx): return _slowburn(ctx)}),
		C.call({"id": "groundwork", "name": "Groundwork", "tier": 1, "cost": 6, "rarity": "common", "cat": "mult",
			"text": "+0.14 mult per scoring event in the hand.",
			"on_count": func(ctx): return _amult(ctx, 0.14 * ctx.events.size()) if ctx.events.size() else false}),
		C.call({"id": "bloodline", "name": "Bloodline", "tier": 2, "cost": 9, "rarity": "rare", "cat": "mult",
			"text": "+1.5 mult if every counted card is the same colour.",
			"on_count": func(ctx):
				var mono: bool = ctx.all.all(func(c): return _is_red(c)) or ctx.all.all(func(c): return not _is_red(c))
				return _amult(ctx, 1.5) if mono else false}),

		# ---- MYTHIC: Street IV and deeper only
		C.call({"id": "collector", "name": "The Collector", "tier": 3, "cost": 16, "rarity": "mythic", "cat": "rule",
			"text": "Once a round, your best counted card joins your deck. +2 base for every card collected this run.", "on_count": func(ctx): return _collector(ctx)}),
		C.call({"id": "exchange", "name": "The Exchange", "tier": 3, "cost": 18, "rarity": "mythic", "cat": "rule",
			"text": "After the cut, your hand and your Crib trade places.", "rule": {"swapCrib": true}}),
		C.call({"id": "echo", "name": "Echo", "tier": 3, "cost": 17, "rarity": "mythic", "cat": "mult",
			"text": "Your highest scoring event is counted a second time.", "on_count": func(ctx): return _echo(ctx)}),
		C.call({"id": "usury", "name": "Usury", "tier": 3, "cost": 15, "rarity": "mythic", "cat": "mult",
			"text": "x2 mult, but you lose 4 Glim every count.", "on_count": func(ctx): return _usury(ctx)}),
		C.call({"id": "thelong", "name": "The Long Game", "tier": 3, "cost": 20, "rarity": "mythic", "cat": "mult",
			"text": "+0.5 mult for every round you have already cleared this run.",
			"on_count": func(ctx):
				var n: int = ctx.run.round_index() - 1
				return _amult(ctx, 0.5 * n) if n > 0 else false}),

		C.call({"id": "thebank", "name": "The Bank", "tier": 3, "cost": 12, "rarity": "legendary", "cat": "mult",
			"text": "x1.04 mult for every Glim you are holding.",
			"on_count": func(ctx):
				var g: int = mini(40, ctx.essence)  # sees Cutpurse/Usury placed before it
				return _xmult(ctx, pow(1.04, g)) if g else false}),
	]


# ------------------------------------------------------------------ Meldlings
static func _build_decks() -> Dictionary:
	return {
		"pip": {"name": "Pip", "suit": "S",
			"text": "RUNS: +9 base and x2.0 mult. But pairs score half.",
			"rule": {"pairScale": 0.5},
			"charm": {"on_event": func(e, ctx): return _base(ctx, 9) if e.kind == "run" else false,
				"on_count": func(ctx): return _xmult(ctx, 2.0) if _has_kind(ctx, "run") else false}},
		"thump": {"name": "Thump", "suit": "H",
			"text": "FIFTEENS: each one adds +0.2 mult. Stack them.",
			"rule": {},
			"charm": {"on_count": func(ctx): return _amult(ctx, 0.2 * _n_kind(ctx, "fifteen")) if _n_kind(ctx, "fifteen") else false}},
		"clover": {"name": "Clover", "suit": "C",
			"text": "FLUSHES: 3-card flushes count, x2.1 mult, and you start with two Mimic cards.",
			"rule": {"flushNeed": 3, "startMimics": 2},
			"charm": {"on_event": func(e, ctx): return _base(ctx, 9) if e.kind == "flush" else false,
				"on_count": func(ctx): return _xmult(ctx, 2.1) if _has_kind(ctx, "flush") else false}},
		"nib": {"name": "Nib", "suit": "S",
			"text": "THE CUT: you see the cut before you keep, with +2 recuts. Whatever the cut adds, it adds twice, and a cut that scores is worth x1.5.",
			"rule": {"recuts": 2, "doubleCutValue": true, "foresight": true},
			"charm": {"on_count": func(ctx): return _xmult(ctx, 1.5) if JS.truthy(ctx.get("nibBonus")) else false}},
		"muggins": {"name": "Muggins", "suit": "C",
			"text": "THE THIEF: takes half of any points a Spoiler blocks. +1 mult on Spoiler rounds, +0.3 mult otherwise.",
			"rule": {"muggins": true},
			"charm": {"on_count": func(ctx): return _amult(ctx, 1.0 if JS.truthy(ctx.get("suppressedBy")) else 0.3)}},
		"pip_asc": {"art": "pip", "name": "Pip Ascended", "suit": "S", "ascended": true,
			"text": "RUNS ONLY: a run needs only two. x3.2 mult, +14 base each.",
			"rule": {"onlyRuns": true, "runNeed": 2},
			"charm": {"on_event": func(e, ctx): return _base(ctx, 14) if e.kind == "run" else false,
				"on_count": func(ctx): return _xmult(ctx, 3.2) if _has_kind(ctx, "run") else false}},
		"thump_asc": {"art": "thump", "name": "Thump Ascended", "suit": "H", "ascended": true,
			"text": "FIFTEENS ONLY: each is +0.6 mult and +5 base. Nothing else scores.",
			"rule": {"onlyFifteens": true},
			"charm": {"on_event": func(e, ctx): return _base(ctx, 5) if e.kind == "fifteen" else false,
				"on_count": func(ctx): return _amult(ctx, 0.6 * _n_kind(ctx, "fifteen")) if _n_kind(ctx, "fifteen") else false}},
		"clover_asc": {"art": "clover", "name": "Clover Ascended", "suit": "C", "ascended": true,
			"text": "FLUSHES ONLY: every matching pair of suits scores. x2.4 mult.",
			"rule": {"flushNeed": 2, "onlyFlush": true, "flushPairs": true, "startMimics": 4},
			"charm": {"on_event": func(e, ctx): return _base(ctx, 4) if e.kind == "flush" else false,
				"on_count": func(ctx): return _xmult(ctx, 2.4) if _has_kind(ctx, "flush") else false}},
		"facet_asc": {"art": "facet", "name": "Facet Ascended", "suit": "D", "ascended": true,
			"text": "Dealt 9, keep 7. Everything scores at 0.75 mult, and the deck never recycles.",
			"rule": {"dealtBonus": 3, "keepBonus": 3, "deckTrim": 26, "noRecycle": true},
			"charm": {"on_count": func(ctx): return _xmult(ctx, 0.75)}},
		"facet": {"name": "Facet", "suit": "D",
			"text": "BIG HANDS: dealt 7, keep 5. Your deck starts 20 cards lighter, and everything scores at 0.85 mult.",
			"rule": {"dealtBonus": 1, "keepBonus": 1, "deckTrim": 20},
			"charm": {"on_count": func(ctx): return _xmult(ctx, 0.85)}},
	}
