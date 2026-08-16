extends RefCounted
class_name CpuPlayer

func choose_draw_source(hand: Array, discard_top: Dictionary) -> String:
	if discard_top.is_empty():
		return "deck"
	var trial: Array = hand.duplicate(true)
	trial.append(discard_top)
	var before: float = _best_score(RummyRules.find_actions(hand))
	var after: float = _best_score(RummyRules.find_actions(trial))
	return "discard" if after > before else "deck"

func choose_action(hand: Array, hp: int, max_hp: int) -> Dictionary:
	var actions: Array = RummyRules.find_actions(hand)
	if actions.is_empty():
		return {}
	var best: Dictionary = {}
	var best_score: float = -9999.0
	for raw_action in actions:
		var action: Dictionary = raw_action
		var score: float = _action_score(action, hp, max_hp)
		if score > best_score:
			best_score = score
			best = action
	return best

func choose_discard_index(hand: Array) -> int:
	if hand.is_empty():
		return -1
	var best_idx: int = 0
	var lowest_keep_score: float = 9999.0
	for i in range(hand.size()):
		var card: Dictionary = hand[i]
		var keep: float = 0.0
		for j in range(hand.size()):
			if i == j:
				continue
			var other: Dictionary = hand[j]
			if int(card.rank) == int(other.rank):
				keep += 4.0
			if str(card.suit) == str(other.suit):
				var distance: int = absi(int(card.rank) - int(other.rank))
				if distance == 1:
					keep += 3.0
				elif distance == 2:
					keep += 1.0
		if keep < lowest_keep_score:
			lowest_keep_score = keep
			best_idx = i
	return best_idx

func intent_text(hand: Array, hp: int, max_hp: int) -> String:
	var actions: Array = RummyRules.find_actions(hand)
	var has_brace: bool = false
	var best_attack: Dictionary = {}
	var best_attack_score: float = -9999.0
	for raw_action in actions:
		var action: Dictionary = raw_action
		var action_type: int = int(action.action)
		if action_type == RummyRules.ActionType.BRACE:
			has_brace = true
		if action_type in [RummyRules.ActionType.STRIKE, RummyRules.ActionType.RALLY, RummyRules.ActionType.GRAND_MELD]:
			var attack_score: float = _action_score(action, hp, max_hp)
			if attack_score > best_attack_score:
				best_attack_score = attack_score
				best_attack = action
	if hp <= int(float(max_hp) * 0.35) and has_brace:
		return "DEFENSIVE • Croak can BRACE this turn"
	if not best_attack.is_empty():
		return "DANGER • %s possible • consider BRACE" % RummyRules.action_name(int(best_attack.action))
	return "BUILDING • no complete attack visible yet"

func _best_score(actions: Array) -> float:
	var result: float = 0.0
	for raw_action in actions:
		var action: Dictionary = raw_action
		result = maxf(result, _action_score(action, 40, 40))
	return result

func _action_score(action: Dictionary, hp: int, max_hp: int) -> float:
	var card_count: int = action.cards.size()
	match action.action:
		RummyRules.ActionType.GRAND_MELD:
			return 30.0 + float(card_count)
		RummyRules.ActionType.RALLY:
			return 18.0 + float(card_count)
		RummyRules.ActionType.STRIKE:
			return 15.0 + float(card_count) * 1.5
		RummyRules.ActionType.BRACE:
			return 22.0 if hp <= int(float(max_hp) * 0.35) else 7.0
		RummyRules.ActionType.PREP:
			return 5.0
		_:
			return 0.0
