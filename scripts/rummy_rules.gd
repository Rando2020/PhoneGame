extends RefCounted
class_name RummyRules

enum ActionType { NONE, BRACE, PREP, STRIKE, RALLY, GRAND_MELD }

static func card_value(card: Dictionary) -> int:
	var rank := int(card.rank)
	return min(rank, 10)

static func card_label(card: Dictionary) -> String:
	var rank := int(card.rank)
	var face := str(rank)
	if rank == 1: face = "A"
	elif rank == 11: face = "J"
	elif rank == 12: face = "Q"
	elif rank == 13: face = "K"
	return face + str(card.suit)

static func classify(cards: Array) -> int:
	if cards.size() < 2:
		return ActionType.NONE
	if cards.size() == 2:
		if _same_rank(cards):
			return ActionType.BRACE
		if _is_run(cards):
			return ActionType.PREP
		return ActionType.NONE
	if _same_rank(cards):
		if cards.size() == 4 and _unique_suits(cards).size() == 4:
			return ActionType.GRAND_MELD
		return ActionType.RALLY
	if _is_run(cards):
		return ActionType.STRIKE
	return ActionType.NONE

static func action_name(action: int) -> String:
	match action:
		ActionType.BRACE: return "BRACE"
		ActionType.PREP: return "PREP"
		ActionType.STRIKE: return "STRIKE"
		ActionType.RALLY: return "RALLY"
		ActionType.GRAND_MELD: return "GRAND MELD"
		_: return "SELECT CARDS"

static func find_actions(hand: Array) -> Array:
	var results: Array = []
	var n := hand.size()
	# Prototype hands stay small, so exhaustive combinations are clear and deterministic.
	for mask in range(1, 1 << n):
		var picked: Array = []
		for i in range(n):
			if mask & (1 << i):
				picked.append(i)
		if picked.size() < 2 or picked.size() > 7:
			continue
		var cards: Array = []
		for idx in picked:
			cards.append(hand[idx])
		var action := classify(cards)
		if action != ActionType.NONE:
			results.append({"indices": picked, "cards": cards, "action": action})
	return results

static func _same_rank(cards: Array) -> bool:
	var rank := int(cards[0].rank)
	for card in cards:
		if int(card.rank) != rank:
			return false
	return true

static func _is_run(cards: Array) -> bool:
	var suit := str(cards[0].suit)
	var ranks: Array[int] = []
	for card in cards:
		if str(card.suit) != suit:
			return false
		ranks.append(int(card.rank))
	ranks.sort()
	for i in range(1, ranks.size()):
		if ranks[i] != ranks[i - 1] + 1:
			return false
	return true

static func _unique_suits(cards: Array) -> Array:
	var found: Array = []
	for card in cards:
		if not found.has(card.suit):
			found.append(card.suit)
	return found
