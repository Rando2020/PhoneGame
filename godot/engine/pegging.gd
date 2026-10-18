class_name PegPlay
extends RefCounted
## Port of web/pegging.js. THE PLAY: you and the Spoiler alternate laying cards
## toward 31, scoring as you go. You hold the Crib, so the Spoiler leads.

const TARGET := 31

var round
var mine: Array
var theirs: Array
var pile: Array = []
var total := 0
var score := 0
var opp_score := 0
var log: Array = []
var turn := "them"
var over := false
var last_lay = null


## Score the card just laid against the pile since the last reset.
static func peg_score(p: Array) -> Array:
	var out := []
	var t := 0
	for c in p:
		t += Cribbage.cval(c)
	if t == 15:
		out.append({"label": "Fifteen", "points": 2})
	if t == TARGET:
		out.append({"label": "Thirty-one", "points": 2})
	# pairs: how many cards back share the laid rank
	var same := 0
	for i in range(p.size() - 1, -1, -1):
		if p[i].rank == p[p.size() - 1].rank:
			same += 1
		else:
			break
	if same == 2:
		out.append({"label": "Pair", "points": 2})
	if same == 3:
		out.append({"label": "Three of a kind", "points": 6})
	if same == 4:
		out.append({"label": "Four of a kind", "points": 12})
	# runs: the longest tail that forms a consecutive set, 3 or more
	for n in range(p.size(), 2, -1):
		var tail: Array = p.slice(p.size() - n).map(func(c): return c.rank)
		tail.sort()
		var ok := true
		for i in range(1, tail.size()):
			if tail[i] != tail[i - 1] + 1:
				ok = false
				break
		if ok:
			out.append({"label": "Run of %d" % n, "points": n})
			break
	return out


func _init(rd, hand: Array, opp_hand: Array) -> void:
	round = rd
	mine = hand.duplicate()
	theirs = opp_hand.duplicate()


func can_play(cards: Array) -> bool:
	return cards.any(func(c): return total + Cribbage.cval(c) <= TARGET)


func playable(i: int) -> bool:
	return total + Cribbage.cval(mine[i]) <= TARGET


func reset(reason: String) -> void:
	log.append({"who": "-", "label": reason, "points": 0})
	pile = []
	total = 0


func lay(who: String, card: Dictionary) -> int:
	var hand: Array = mine if who == "you" else theirs
	var i := JS.index_same(hand, card)
	if i >= 0:
		hand.remove_at(i)
	pile.append(card)
	total += Cribbage.cval(card)
	var events := peg_score(pile)
	var gained := 0
	for e in events:
		gained += e.points
		log.append({"who": who, "label": e.label, "points": e.points, "card": card})
	if who == "you":
		score += gained
	else:
		opp_score += gained
	var hit31 := total == TARGET
	if hit31:
		reset("Thirty-one \u2014 reset")
	last_lay = {"who": who, "card": card, "events": events, "gained": gained, "hit31": hit31}
	return gained


## The Spoiler plays greedily: points now, else the biggest card that fits.
func opp_turn():
	var legal := theirs.filter(func(c): return total + Cribbage.cval(c) <= TARGET)
	if legal.is_empty():
		return null
	var best = legal[0]
	var best_pts := -1
	for c in legal:
		var pts := 0
		for e in peg_score(pile + [c]):
			pts += e.points
		var s := pts * 10 + Cribbage.cval(c)
		if s > best_pts:
			best_pts = s
			best = c
	return best


## Advance until it's the player's turn again, or the play is finished.
func step() -> void:
	var guard := 0
	while guard < 20:
		guard += 1
		if mine.is_empty() and theirs.is_empty():
			if not pile.is_empty():
				log.append({"who": "you", "label": "Last card", "points": 1})
				score += 1
			over = true
			return
		var i_can := can_play(mine)
		var they_can := can_play(theirs)
		if not i_can and not they_can:
			var who := "them" if turn == "you" else "you"
			log.append({"who": who, "label": "Go", "points": 1})
			if who == "you":
				score += 1
			else:
				opp_score += 1
			reset("Go \u2014 reset")
			turn = "you"
			continue
		if turn == "you":
			if i_can:
				return  # wait for input
			log.append({"who": "them", "label": "Go", "points": 1})
			opp_score += 1
			turn = "them"
			continue
		if they_can:
			var c = opp_turn()
			if c != null:
				lay("them", c)
			turn = "you"
		else:
			turn = "you"
	over = true
