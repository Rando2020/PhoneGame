extends "res://scripts/main.gd"

var suggestions_box: HBoxContainer
var selection_preview: Label
var sort_button: Button
var sort_mode: String = "suit"

func _ready() -> void:
	super._ready()
	_install_usability_ui()
	_sort_player_hand()
	_refresh()

func _install_usability_ui() -> void:
	var player_stack: VBoxContainer = hand_box.get_parent() as VBoxContainer
	if not player_stack:
		return
	var hand_index: int = hand_box.get_index()

	var guide_row: HBoxContainer = HBoxContainer.new()
	guide_row.add_theme_constant_override("separation", 8)
	selection_preview = _label("♥ Burn   ♦ Loot   ♣ Guard/Thorns   ♠ Hex", 13, Color("#cfc7e8"))
	selection_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide_row.add_child(selection_preview)
	sort_button = _button("SORT: SUIT", _on_sort_hand)
	sort_button.custom_minimum_size = Vector2(112, 42)
	sort_button.add_theme_font_size_override("font_size", 12)
	guide_row.add_child(sort_button)
	player_stack.add_child(guide_row)
	player_stack.move_child(guide_row, hand_index)

	suggestions_box = HBoxContainer.new()
	suggestions_box.alignment = BoxContainer.ALIGNMENT_CENTER
	suggestions_box.add_theme_constant_override("separation", 6)
	player_stack.add_child(suggestions_box)
	player_stack.move_child(suggestions_box, hand_index + 1)

	log_label.custom_minimum_size.y = 84

func _refresh() -> void:
	super._refresh()
	_refresh_suggestions()
	_refresh_selection_preview()

func _refresh_hand() -> void:
	if selected.is_empty() and phase != "cpu":
		_sort_player_hand()
	for child in hand_box.get_children():
		child.queue_free()
	var playable_indices: Array[int] = _playable_card_indices()
	for i in range(mini(player_hand.size(), MAX_HAND_VISIBLE)):
		var card: Dictionary = player_hand[i]
		var card_button: Button = Button.new()
		card_button.text = rules.card_label(card)
		card_button.custom_minimum_size = Vector2(76, 112)
		card_button.add_theme_font_size_override("font_size", 22)
		card_button.add_theme_color_override("font_color", _card_color(card))
		card_button.add_theme_color_override("font_hover_color", _card_color(card))
		card_button.add_theme_color_override("font_pressed_color", _card_color(card))
		var style: StyleBoxFlat = StyleBoxFlat.new()
		if selected.has(i):
			style.bg_color = Color("#ffe19a")
			style.border_color = Color("#ffd166")
		elif phase == "action" and playable_indices.has(i):
			style.bg_color = Color("#effbe9")
			style.border_color = Color("#75e6a4")
			card_button.tooltip_text = "This card can be used in a legal play."
		else:
			style.bg_color = Color("#fff8e9")
			style.border_color = Color("#6f6688")
		style.set_border_width_all(3)
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		card_button.add_theme_stylebox_override("normal", style)
		card_button.add_theme_stylebox_override("hover", style)
		card_button.add_theme_stylebox_override("pressed", style)
		card_button.pressed.connect(_on_card_pressed.bind(i))
		hand_box.add_child(card_button)

func _refresh_buttons() -> void:
	super._refresh_buttons()
	if discard_pile.is_empty():
		draw_discard_button.text = "TAKE DISCARD"
	else:
		var top: Dictionary = discard_pile[-1]
		var draw_hint: String = _discard_completion_hint(top)
		draw_discard_button.text = "TAKE %s%s" % [rules.card_label(top), draw_hint]
	discard_button.text = "DISCARD SELECTED" if selected.size() == 1 else "DISCARD"
	if sort_button:
		sort_button.text = "SORT: %s" % ("SUIT" if sort_mode == "suit" else "RANK")
		sort_button.disabled = not selected.is_empty() or phase == "cpu"
	_refresh_selection_preview()

func _phase_text() -> String:
	if battle_over:
		return "BATTLE COMPLETE"
	match phase:
		"draw":
			return "STEP 1/3 • DRAW FROM DECK OR DISCARD"
		"action":
			return "STEP 2/3 • PLAY A PATTERN OR DISCARD"
		"discard":
			return "STEP 3/3 • SELECT 1 CARD TO DISCARD"
		"cpu":
			return "CROAK'S TURN • WATCH WHAT IT TAKES AND PLAYS"
		_:
			return ""

func _refresh_selection_preview() -> void:
	if not selection_preview:
		return
	if phase == "draw":
		selection_preview.text = "Draw first. Taking the discard will tell you if it completes a play."
		return
	if phase == "cpu":
		selection_preview.text = "Watch Croak's draw, meld, and discard. Your discarded cards can help it."
		return
	var cards: Array = _selected_cards()
	if cards.is_empty():
		selection_preview.text = "Green cards are playable. Tap a suggestion to auto-select a legal pattern."
		return
	var action: int = rules.classify(cards)
	if action == rules.ActionType.NONE:
		if cards.size() == 1:
			selection_preview.text = "%s selected • DISCARD ends your turn" % rules.card_label(cards[0])
		else:
			selection_preview.text = "Not legal yet • Pair = BRACE • 2-card same-suit sequence = PREP • 3+ = attack"
		return
	selection_preview.text = _action_preview(cards, action)

func _action_preview(cards: Array, action: int) -> String:
	if action == rules.ActionType.BRACE:
		var block_gain: int = 0
		var thorns_gain: int = 0
		var extras: Array[String] = []
		for card in cards:
			match str(card.suit):
				"♥":
					block_gain += 4
					if player_burn > 0:
						extras.append("cleanse Burn")
				"♦":
					block_gain += 3
				"♣":
					block_gain += 5
					thorns_gain += 3 + (2 if relics.has("Spiteful Shell") else 0)
				"♠":
					block_gain += 2
					if player_hex > 0:
						extras.append("cleanse Hex")
		var preview: String = "BRACE • +%d Block" % block_gain
		if thorns_gain > 0:
			preview += " • +%d Thorns" % thorns_gain
		if not extras.is_empty():
			preview += " • " + ", ".join(extras)
		return preview
	if action == rules.ActionType.PREP:
		return "PREP %s • +2 Block • next %s Strike gets +3 damage" % [str(cards[0].suit), str(cards[0].suit)]
	var damage: int = _preview_offense_damage(cards, action)
	var effects: Array[String] = []
	var seen: Array[String] = []
	for card in cards:
		var suit: String = str(card.suit)
		if seen.has(suit):
			continue
		seen.append(suit)
		match suit:
			"♥":
				effects.append("Burn")
			"♦":
				if cards.size() >= 4:
					effects.append("+Essence")
			"♣":
				effects.append("+%d Block" % cards.size())
			"♠":
				if cpu_hex > 0:
					effects.append("+%d Hex dmg" % (cpu_hex * 2))
	var preview: String = "%s • %d damage" % [rules.action_name(action), damage]
	if not effects.is_empty():
		preview += " • " + " • ".join(effects)
	return preview

func _preview_offense_damage(cards: Array, action: int) -> int:
	var count: int = cards.size()
	var base: int = 0
	if action == rules.ActionType.STRIKE:
		base = 3 + count * 3
	elif action == rules.ActionType.RALLY:
		base = count * 4
	elif action == rules.ActionType.GRAND_MELD:
		base = 22
	if action == rules.ActionType.STRIKE and prepared_suit == str(cards[0].suit):
		base += 3
	return base

func _playable_card_indices() -> Array[int]:
	var result: Array[int] = []
	if phase != "action":
		return result
	var actions: Array = rules.find_actions(player_hand)
	for raw_action_data in actions:
		var action_data: Dictionary = raw_action_data
		var indices: Array = action_data.indices
		for raw_idx in indices:
			var idx: int = int(raw_idx)
			if not result.has(idx):
				result.append(idx)
	return result

func _refresh_suggestions() -> void:
	if not suggestions_box:
		return
	for child in suggestions_box.get_children():
		child.queue_free()
	suggestions_box.visible = phase == "action" and not battle_over
	if not suggestions_box.visible:
		return
	var suggestions: Array = _suggested_actions()
	if suggestions.is_empty():
		var no_play: Label = _label("No meld ready • select 1 card to discard, or hold promising cards", 12, Color("#9d96b6"))
		suggestions_box.add_child(no_play)
		return
	for raw_suggestion in suggestions:
		var suggestion: Dictionary = raw_suggestion
		var action: int = int(suggestion.action)
		var cards: Array = suggestion.cards
		var label_text: String = "%s\n%s" % [rules.action_name(action), _cards_text(cards)]
		var suggestion_button: Button = _button(label_text, _select_suggestion.bind(suggestion.indices))
		suggestion_button.custom_minimum_size = Vector2(0, 54)
		suggestion_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		suggestion_button.add_theme_font_size_override("font_size", 12)
		suggestions_box.add_child(suggestion_button)

func _suggested_actions() -> Array:
	var actions: Array = rules.find_actions(player_hand)
	var best_by_type: Dictionary = {}
	for raw_action_data in actions:
		var action_data: Dictionary = raw_action_data
		var action_type: int = int(action_data.action)
		var score: float = _suggestion_score(action_data)
		var should_store: bool = not best_by_type.has(action_type)
		if not should_store:
			var current_best: Dictionary = best_by_type[action_type]
			should_store = score > float(current_best.ui_score)
		if should_store:
			var stored: Dictionary = action_data.duplicate(true)
			stored["ui_score"] = score
			best_by_type[action_type] = stored
	var remaining: Array = best_by_type.values()
	var result: Array = []
	while result.size() < 3 and not remaining.is_empty():
		var best_index: int = 0
		var best_score: float = -99999.0
		for i in range(remaining.size()):
			var candidate: Dictionary = remaining[i]
			var candidate_score: float = float(candidate.ui_score)
			if candidate_score > best_score:
				best_score = candidate_score
				best_index = i
		result.append(remaining[best_index])
		remaining.remove_at(best_index)
	return result

func _suggestion_score(action_data: Dictionary) -> float:
	var action: int = int(action_data.action)
	var card_count: int = action_data.cards.size()
	var score: float = 0.0
	match action:
		RummyRules.ActionType.GRAND_MELD:
			score = 100.0
		RummyRules.ActionType.RALLY:
			score = 80.0 + float(card_count)
		RummyRules.ActionType.STRIKE:
			score = 70.0 + float(card_count)
		RummyRules.ActionType.BRACE:
			score = 55.0
			if player_hp <= 15 or player_burn > 0 or player_hex > 0:
				score += 35.0
		RummyRules.ActionType.PREP:
			score = 40.0
	return score

func _select_suggestion(indices: Array) -> void:
	if phase != "action" or battle_over:
		return
	selected.clear()
	for raw_idx in indices:
		selected.append(int(raw_idx))
	sound.select_card()
	_refresh_hand()
	_refresh_buttons()

func _discard_completion_hint(top: Dictionary) -> String:
	var trial: Array = player_hand.duplicate(true)
	trial.append(top)
	var new_index: int = trial.size() - 1
	var best_action: int = rules.ActionType.NONE
	var best_score: float = -1.0
	for raw_action_data in rules.find_actions(trial):
		var action_data: Dictionary = raw_action_data
		if not action_data.indices.has(new_index):
			continue
		var score: float = _suggestion_score(action_data)
		if score > best_score:
			best_score = score
			best_action = int(action_data.action)
	if best_action == rules.ActionType.NONE:
		return ""
	return " • %s READY" % rules.action_name(best_action)

func _on_sort_hand() -> void:
	if not selected.is_empty() or phase == "cpu":
		return
	sort_mode = "rank" if sort_mode == "suit" else "suit"
	_sort_player_hand()
	_refresh()

func _sort_player_hand() -> void:
	if sort_mode == "suit":
		player_hand.sort_custom(_card_less_suit)
	else:
		player_hand.sort_custom(_card_less_rank)

func _card_less_suit(a: Dictionary, b: Dictionary) -> bool:
	var suit_a: int = SUITS.find(str(a.suit))
	var suit_b: int = SUITS.find(str(b.suit))
	if suit_a == suit_b:
		return int(a.rank) < int(b.rank)
	return suit_a < suit_b

func _card_less_rank(a: Dictionary, b: Dictionary) -> bool:
	var rank_a: int = int(a.rank)
	var rank_b: int = int(b.rank)
	if rank_a == rank_b:
		return SUITS.find(str(a.suit)) < SUITS.find(str(b.suit))
	return rank_a < rank_b

func _cpu_turn() -> void:
	if battle_over:
		return
	cpu_block = 0
	cpu_thorns = 0
	_apply_turn_start_status(false)
	if _check_end():
		return
	_refresh()
	await get_tree().create_timer(0.35).timeout

	var top: Dictionary = discard_pile[-1] if not discard_pile.is_empty() else {}
	var source: String = cpu_ai.choose_draw_source(cpu_hand, top)
	if source == "discard" and not discard_pile.is_empty():
		var taken: Dictionary = discard_pile.pop_back()
		cpu_hand.append(taken)
		player_hex += 1 if str(taken.suit) == "♠" else 0
		_log("Croak takes [b]%s[/b] from your discard." % rules.card_label(taken))
	else:
		if deck.is_empty():
			_reshuffle_discards()
		if not deck.is_empty():
			cpu_hand.append(deck.pop_back())
		_log("Croak draws from the deck.")
	_refresh()
	await get_tree().create_timer(0.45).timeout

	var choice: Dictionary = cpu_ai.choose_action(cpu_hand, cpu_hp, cpu_max_hp)
	if not choice.is_empty():
		_resolve_cpu_action(choice.cards, int(choice.action))
		_remove_indices(cpu_hand, choice.indices)
		_refresh()
		await get_tree().create_timer(0.55).timeout
	if _check_end():
		return

	if not cpu_hand.is_empty():
		var discard_idx: int = cpu_ai.choose_discard_index(cpu_hand)
		var discarded: Dictionary = cpu_hand[discard_idx]
		cpu_hand.remove_at(discard_idx)
		discard_pile.append(discarded)
		_log("Croak discards [b]%s[/b]." % rules.card_label(discarded))
		_refresh()
		await get_tree().create_timer(0.35).timeout

	player_block = 0
	player_thorns = 0
	phase = "draw"
	_apply_turn_start_status(true)
	_check_end()
	_refresh()
