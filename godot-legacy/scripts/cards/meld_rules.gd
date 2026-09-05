class_name MeldRules
extends RefCounted

## Pure functions: classify a selection of cards into a Meldlings action,
## and decide which further cards may legally join that selection.
##
## This mirrors the README mapping. If scripts/rummy_rules.gd is the real
## authority in your project, delete the classify() body here and forward to it --
## can_join() is the part you actually want, since it drives the play hints.

enum Kind { NONE, PAIR, RUN2, RUN, SET, GRAND }

const ACTION_NAMES := {
	Kind.NONE: "",
	Kind.PAIR: "BRACE",
	Kind.RUN2: "PREP",
	Kind.RUN: "STRIKE",
	Kind.SET: "RALLY",
	Kind.GRAND: "GRAND MELD",
}

## Set true if Q-K-A should count as a run in your ruleset.
static var ace_high_runs := false


static func _ranks(cards: Array) -> Array:
	var out: Array = []
	for c in cards:
		out.append(int(c.rank))
	out.sort()
	return out


static func _suits(cards: Array) -> Array:
	var out: Array = []
	for c in cards:
		out.append(CardArt.suit_letter(c.suit))
	return out


static func _same_suit(cards: Array) -> bool:
	var s := _suits(cards)
	for x in s:
		if x != s[0]:
			return false
	return true


static func _same_rank(cards: Array) -> bool:
	var r := _ranks(cards)
	for x in r:
		if x != r[0]:
			return false
	return true


static func _consecutive(ranks: Array) -> bool:
	for i in range(1, ranks.size()):
		if ranks[i] != ranks[i - 1] + 1:
			return false
	return true


static func _is_run(cards: Array) -> bool:
	if not _same_suit(cards):
		return false
	var r := _ranks(cards)
	if _consecutive(r):
		return true
	if ace_high_runs and r[0] == 1:
		# retry with the ace promoted to 14
		var high := r.slice(1)
		high.append(14)
		return _consecutive(high)
	return false


## Returns { kind, action, valid, label }
static func classify(cards: Array) -> Dictionary:
	var n := cards.size()
	if n < 2:
		return _result(Kind.NONE, false, "Select 2 or more cards")

	if _same_rank(cards):
		# a set can never exceed one card per suit
		var seen := {}
		for s in _suits(cards):
			if seen.has(s):
				return _result(Kind.NONE, false, "Duplicate suit in set")
			seen[s] = true
		if n == 2:
			return _result(Kind.PAIR, true, "PAIR")
		if n == 4:
			return _result(Kind.GRAND, true, "4-SUIT SET")
		return _result(Kind.SET, true, "%d-CARD SET" % n)

	if _is_run(cards):
		if n == 2:
			return _result(Kind.RUN2, true, "2-RUN")
		return _result(Kind.RUN, true, "%d-RUN" % n)

	return _result(Kind.NONE, false, "Not a legal meld")


static func _result(kind: int, valid: bool, label: String) -> Dictionary:
	return {
		"kind": kind,
		"valid": valid,
		"label": label,
		"action": ACTION_NAMES[kind],
	}


## Could `card` be added to `selection` and still be on a path to a legal meld?
## This is what powers the highlight/dim hints in the hand.
static func can_join(selection: Array, card: Dictionary) -> bool:
	if selection.is_empty():
		return true

	var probe := selection.duplicate()
	probe.append(card)

	# --- set path: all one rank, all distinct suits, max 4
	if _same_rank(selection) and int(card.rank) == int(selection[0].rank):
		if probe.size() <= 4:
			var seen := {}
			var ok := true
			for s in _suits(probe):
				if seen.has(s):
					ok = false
					break
				seen[s] = true
			if ok:
				return true

	# --- run path: all one suit, extends the sequence at either end
	if _same_suit(selection) and CardArt.suit_letter(card.suit) == CardArt.suit_letter(selection[0].suit):
		var r := _ranks(selection)
		var cr := int(card.rank)
		if _consecutive(r) and (cr == r[0] - 1 or cr == r[-1] + 1):
			return true
		if ace_high_runs and cr == 1 and r[-1] == 13:
			return true

	return false


## Every legal meld that can be built from a hand, best (longest) first.
## Useful for a "show me a play" button.
static func find_melds(hand: Array) -> Array:
	var found: Array = []
	var by_rank := {}
	var by_suit := {}
	for i in hand.size():
		var c = hand[i]
		var r := int(c.rank)
		var s := CardArt.suit_letter(c.suit)
		if not by_rank.has(r):
			by_rank[r] = []
		if not by_suit.has(s):
			by_suit[s] = []
		by_rank[r].append(i)
		by_suit[s].append(i)

	for r in by_rank:
		var idx: Array = by_rank[r]
		if idx.size() >= 2:
			found.append(idx.duplicate())

	for s in by_suit:
		var idx: Array = by_suit[s]
		idx.sort_custom(func(a, b): return int(hand[a].rank) < int(hand[b].rank))
		var chain: Array = []
		for i in idx:
			if chain.is_empty() or int(hand[i].rank) == int(hand[chain[-1]].rank) + 1:
				chain.append(i)
			else:
				if chain.size() >= 2:
					found.append(chain.duplicate())
				chain = [i]
		if chain.size() >= 2:
			found.append(chain)

	found.sort_custom(func(a, b): return a.size() > b.size())
	return found
