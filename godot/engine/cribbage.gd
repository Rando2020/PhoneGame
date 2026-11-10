class_name Cribbage
extends RefCounted
## Port of web/cribbage.js. Exact cribbage counting.
## A card is a Dictionary: {rank:int, suit:String} plus optional enh, rank2, suit2.
## Returns an ordered cascade of events so the UI can tick them up one at a time.

const SUITS := ["S", "H", "C", "D"]
const RANK_LABEL := ["", "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
const SUIT_NAME := {"S": "Spade", "H": "Heart", "C": "Club", "D": "Diamond"}
const SUIT_SYM := {"S": "\u2660", "H": "\u2665", "C": "\u2663", "D": "\u2666"}


static func cval(c: Dictionary, mods: Dictionary = {}) -> int:
	if JS.truthy(mods.get("aceEleven")) and c.rank == 1:
		return 11
	return mini(10, c.rank)


static func deck() -> Array:
	var d := []
	for s in SUITS:
		for r in range(1, 14):
			d.append({"rank": r, "suit": s})
	return d


static func card_str(c: Dictionary) -> String:
	return RANK_LABEL[c.rank] + SUIT_SYM.get(c.suit, c.suit)


static func _has_split(c) -> bool:
	return c != null and c.has("rank2") and c.rank2 != null


## A split card is two ranks at once. Expand into every combination, keep the best.
static func expand_splits(cards: Array) -> Array:
	var out := [cards]
	for i in cards.size():
		var c = cards[i]
		if not _has_split(c):
			continue
		var nxt := []
		for variant in out:
			var a: Array = variant.duplicate()
			var ca := JS.copy(c)
			ca["rank"] = c.rank
			ca["split"] = true
			a[i] = ca
			var b: Array = variant.duplicate()
			var cb := JS.copy(c)
			cb["rank"] = c.rank2
			cb["split"] = true
			b[i] = cb
			nxt.append(a)
			nxt.append(b)
		out = nxt.slice(0, 64)  # hard cap; nobody holds six splits
	return out


## hand: kept cards. starter: the cut card or null. is_crib: flush needs all five.
## Returns {events: [{kind, label, points, cards}], base}.
static func count_hand(hand: Array, starter, is_crib := false, mods: Dictionary = {}) -> Dictionary:
	var has_split := false
	for c in hand:
		if _has_split(c):
			has_split = true
	if _has_split(starter):
		has_split = true
	if has_split:
		var all := hand + [starter] if starter != null else hand.duplicate()
		var best = null
		for variant in expand_splits(all):
			var h: Array = variant.slice(0, variant.size() - 1) if starter != null else variant
			var st = variant[variant.size() - 1] if starter != null else null
			var r := count_hand_core(h, st, is_crib, mods)
			if best == null or r.base > best.base:
				best = r
		return best
	return count_hand_core(hand, starter, is_crib, mods)


static func count_hand_core(hand: Array, starter, is_crib := false, mods: Dictionary = {}) -> Dictionary:
	var all: Array = hand + [starter] if starter != null else hand.duplicate()
	var dead = mods.get("deadSuit")
	# a "dead" suit is inert: it cannot form fifteens, pairs, runs or flushes
	if JS.truthy(dead):
		all = all.filter(func(c): return c.suit != dead)
	var events := []
	var n := all.size()

	# --- fifteens: every subset summing to exactly 15
	if not JS.truthy(mods.get("noFifteens")):
		var running = 0
		var per = JS.nn(mods, "fifteenPoints", 2)
		# Each subset's sum is a smaller subset's sum plus one card: one add per
		# mask, and a card list only for the subsets that actually make 15.
		# Masks ascend and bits are read low to high, so event and card order
		# match the JS exactly. This loop was ~75% of count_hand's cost.
		var vals := PackedInt32Array()
		for c in all:
			vals.append(cval(c, mods))
		var size := 1 << n
		var sums := PackedInt32Array()
		sums.resize(size)
		var bits := PackedInt32Array()
		bits.resize(size)
		for m in range(1, size):
			var low := m & -m
			var i := 0
			while (1 << i) != low:
				i += 1
			sums[m] = sums[m ^ low] + vals[i]
			bits[m] = bits[m ^ low] + 1
			if sums[m] == 15 and bits[m] >= 2:
				var cards := []
				for k in n:
					if m & (1 << k):
						cards.append(all[k])
				running += per
				events.append({"kind": "fifteen", "label": "Fifteen " + JS.num_str(running),
					"points": per, "cards": cards})

	# --- pairs (JS iterates integer keys in ascending order)
	if not JS.truthy(mods.get("noPairs")):
		var by_rank := {}
		for c in all:
			if not by_rank.has(c.rank):
				by_rank[c.rank] = []
			by_rank[c.rank].append(c)
		var per = (4 if JS.truthy(mods.get("pairDouble")) else 2) * JS.nn(mods, "pairScale", 1)
		for r in JS.num_keys(by_rank):
			var g: Array = by_rank[r]
			if g.size() < 2:
				continue
			var pairs := g.size() * (g.size() - 1) / 2
			var name := "Pair" if g.size() == 2 else ("Three of a kind" if g.size() == 3 else "Four of a kind")
			events.append({"kind": "pair", "label": "%s of %ss" % [name, RANK_LABEL[r]],
				"points": pairs * per, "cards": g})

	# --- runs: maximal consecutive stretches, counted with multiplicity
	if not JS.truthy(mods.get("noRuns")):
		var count := {}
		for c in all:
			count[c.rank] = count.get(c.rank, 0) + 1
		var ranks := JS.num_keys(count)
		var need = JS.or_(mods, "runNeed", 3)
		# maximal consecutive stretches, as lists of ranks
		var segs := []
		var i := 0
		while i < ranks.size():
			var j := i
			while j + 1 < ranks.size() and ranks[j + 1] == ranks[j] + 1:
				j += 1
			segs.append(ranks.slice(i, j + 1))
			i = j + 1
		# Round the Bend: a stretch ending at K joins one starting at A (Q-K-A-2).
		# The joined run takes the A stretch's place, so event order is fixed.
		if JS.truthy(mods.get("wrapRuns")) and segs.size() >= 2 and segs[0][0] == 1 and segs[segs.size() - 1][segs[segs.size() - 1].size() - 1] == 13:
			var top: Array = segs.pop_back()
			segs[0] = top + segs[0]
		for seg in segs:
			var length: int = seg.size()
			if length >= need:
				var cap = JS.or_(mods, "runCap", 99)
				var scored = mini(length, cap)
				var mult := 1
				for r in seg:
					mult *= count[r]
				var bonus = JS.or_(mods, "runCardBonus", 0) * scored
				var pts = scored * mult + bonus
				var cards := all.filter(func(c): return seg.has(c.rank))
				var label := ("%d runs of %d" % [mult, scored]) if mult > 1 else ("Run of %d" % scored)
				events.append({"kind": "run", "label": label, "points": pts, "cards": cards})

	# --- flush
	var need_f = JS.or_(mods, "flushNeed", 4)
	var flush_pairs := JS.truthy(mods.get("flushPairs"))
	if flush_pairs:
		# one event per same-suit pair, so the count grows with the hand
		var by_suit := {}
		var src := all.filter(func(c): return c.suit != dead) if JS.truthy(dead) else all
		# Mimic wears one suit: it joins your largest natural suit group
		# (with the JS; Clover Ascended's Mimics did nothing here before)
		for c in src:
			if _is_wild(c):
				continue
			if not by_suit.has(c.suit):
				by_suit[c.suit] = []
			by_suit[c.suit].append(c)
		var big = null
		for su in by_suit:
			if big == null or by_suit[su].size() > by_suit[big].size():
				big = su
		for c in src:
			if _is_wild(c):
				var key = big if big != null else c.suit
				if not by_suit.has(key):
					by_suit[key] = []
				by_suit[key].append(c)
		for su in by_suit:
			var g: Array = by_suit[su]
			for i in g.size():
				for j in range(i + 1, g.size()):
					events.append({"kind": "flush", "label": "%s pair" % SUIT_NAME.get(su, su),
						"points": 2, "cards": [g[i], g[j]]})
	else:
		var suits := {}
		var flush_hand := hand.filter(func(c): return c.suit != dead) if JS.truthy(dead) else hand
		# Mimic ("chameleon") wears any suit for flushes. Fixed in the JS and here
		# together; it used to check only "wild", so Mimic never counted.
		var wilds := flush_hand.filter(func(c): return _is_wild(c)).size()
		for c in flush_hand:
			if _is_wild(c):
				continue
			suits[c.suit] = suits.get(c.suit, 0) + 1
		for k in suits:
			suits[k] += wilds
		if suits.is_empty() and wilds >= need_f:
			suits[flush_hand[0].suit] = wilds
		for s in suits:
			if suits[s] >= mini(need_f, hand.size()) and not JS.truthy(mods.get("noFlush")):
				var with_starter: bool = starter != null and starter.suit == s
				if is_crib and not with_starter:
					break  # crib flush needs all five
				var pts: int = suits[s] + (1 if with_starter else 0)
				var fc := flush_hand.filter(func(c): return c.suit == s or _is_wild(c))
				if with_starter:
					fc.append(starter)
				events.append({"kind": "flush", "label": "Flush of %d" % pts, "points": pts, "cards": fc})
				break

	# --- nobs
	if starter != null and not JS.truthy(mods.get("noNobs")):
		for c in hand:
			if c.rank == 11 and c.suit == starter.suit and (not JS.truthy(dead) or c.suit != dead):
				events.append({"kind": "nobs", "label": "Nobs",
					"points": JS.nn(mods, "nobsPoints", 1), "cards": [c]})
				break

	# catScale (pass 20): a category's points scaled this round (the Shortage)
	var cs = mods.get("catScale")
	if cs != null:
		for e in events:
			if cs.has(e.kind):
				e.points = e.points * cs[e.kind]
	var base = 0
	for e in events:
		base += e.points
	return {"events": events, "base": base}


static func _is_wild(c: Dictionary) -> bool:
	return c.get("enh") == "wild" or c.get("enh") == "chameleon"


static func count_points(hand: Array, starter, is_crib := false, mods: Dictionary = {}):
	return count_hand(hand, starter, is_crib, mods).base


## All ways to keep k of the dealt cards, scored against a known starter.
static func keep_options(dealt: Array, starter, keep := 4, mods: Dictionary = {}) -> Array:
	var out := []
	for idx in JS.combos(dealt.size(), keep):
		var hand: Array = idx.map(func(i): return dealt[i])
		out.append({"idx": idx, "points": count_points(hand, starter, false, mods)})
	return JS.stable_sort_desc(out, func(o): return o.points)


## Expected value of a keep across every starter still in a fresh deck.
static func keep_ev(dealt: Array, keep_idx: Array, mods: Dictionary = {}) -> float:
	var hand: Array = keep_idx.map(func(i): return dealt[i])
	var seen := {}
	for c in dealt:
		seen[str(c.rank) + c.suit] = true
	var total = 0
	var n := 0
	for c in deck():
		if seen.has(str(c.rank) + c.suit):
			continue
		total += count_points(hand, c, false, mods)
		n += 1
	return float(total) / n if n else 0.0


## Fast EV: one representative card per rank, weighted by copies left in the pool.
static func keep_ev_fast(hand: Array, pool: Array, mods: Dictionary = {}):
	var by_rank := {}
	for c in pool:
		if not by_rank.has(c.rank):
			by_rank[c.rank] = []
		by_rank[c.rank].append(c)
	var total = 0
	var weight := 0
	for r in JS.num_keys(by_rank):
		var g: Array = by_rank[r]
		total += count_points(hand, g[0], false, mods) * g.size()
		weight += g.size()
	return float(total) / weight if weight else count_points(hand, null, false, mods)


static func keep_options_ev(dealt: Array, pool: Array, keep := 4, mods: Dictionary = {}) -> Array:
	var out := []
	for idx in JS.combos(dealt.size(), keep):
		var hand: Array = idx.map(func(i): return dealt[i])
		out.append({"idx": idx, "ev": keep_ev_fast(hand, pool, mods),
			"sure": count_points(hand, null, false, mods)})
	return JS.stable_sort_desc(out, func(o): return o.ev)


static func best_keep_by_ev(dealt: Array, keep := 4, mods: Dictionary = {}) -> Dictionary:
	var best = null
	var best_ev := -1.0
	for idx in JS.combos(dealt.size(), keep):
		var ev := keep_ev(dealt, idx, mods)
		if ev > best_ev:
			best_ev = ev
			best = idx
	return {"idx": best, "ev": best_ev}
