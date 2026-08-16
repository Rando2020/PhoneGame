extends Control

const SUITS := ["♥", "♦", "♣", "♠"]
const RED_SUITS := ["♥", "♦"]
const MAX_HAND_VISIBLE := 12

var rules := RummyRules
var cpu_ai := CpuPlayer.new()
var sound: RetroSound

var deck: Array = []
var discard_pile: Array = []
var player_hand: Array = []
var cpu_hand: Array = []
var selected: Array[int] = []

var player_max_hp := 40
var player_hp := 40
var cpu_max_hp := 40
var cpu_hp := 40
var player_block := 0
var cpu_block := 0
var player_thorns := 0
var cpu_thorns := 0
var player_burn := 0
var cpu_burn := 0
var player_hex := 0
var cpu_hex := 0
var prepared_suit := ""
var cpu_prepared_suit := ""
var phase := "draw"
var battle_over := false
var relics: Array[String] = []
var essence := 0
var vitality_rank := 0
var first_brace_heal_used := false

var hand_box: HBoxContainer
var cpu_hand_box: HBoxContainer
var status_label: Label
var log_label: RichTextLabel
var player_hp_label: Label
var cpu_hp_label: Label
var player_hp_bar: ProgressBar
var cpu_hp_bar: ProgressBar
var draw_deck_button: Button
var draw_discard_button: Button
var play_button: Button
var discard_button: Button
var intent_label: Label
var discard_label: Label
var deck_label: Label
var player_status: Label
var cpu_status: Label
var modal_layer: ColorRect
var modal_content: VBoxContainer
var essence_label: Label

func _ready() -> void:
	sound = RetroSound.new()
	add_child(sound)
	_load_save()
	_build_ui()
	_start_battle()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quick_restart"):
		_start_battle()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#100e1c")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var safe := MarginContainer.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.add_theme_constant_override("margin_left", 24)
	safe.add_theme_constant_override("margin_right", 24)
	safe.add_theme_constant_override("margin_top", 24)
	safe.add_theme_constant_override("margin_bottom", 24)
	add_child(safe)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	safe.add_child(root)

	var title_row := HBoxContainer.new()
	root.add_child(title_row)
	var title := _label("MELDLINGS", 34, Color("#fff3d6"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	essence_label = _label("ESSENCE 0", 18, Color("#ffd166"))
	title_row.add_child(essence_label)

	root.add_child(_label("FIRST BLOOD • Rival 1: Croak", 16, Color("#aaa3c7")))

	var cpu_panel := _panel(Color("#211d35"))
	root.add_child(cpu_panel)
	var cpu_v := VBoxContainer.new()
	cpu_v.add_theme_constant_override("separation", 7)
	cpu_panel.add_child(cpu_v)
	var cpu_row := HBoxContainer.new()
	cpu_v.add_child(cpu_row)
	cpu_row.add_child(_label("CPU • CROAK", 21, Color("#f2ecff")))
	cpu_hp_bar = _hp_bar()
	cpu_row.add_child(cpu_hp_bar)
	cpu_hp_label = _label("40/40", 15, Color.WHITE)
	cpu_row.add_child(cpu_hp_label)
	cpu_status = _label("", 14, Color("#9be3b2"))
	cpu_v.add_child(cpu_status)
	intent_label = _label("INTENT: building...", 14, Color("#ffcf70"))
	intent_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cpu_v.add_child(intent_label)
	cpu_hand_box = HBoxContainer.new()
	cpu_hand_box.alignment = BoxContainer.ALIGNMENT_CENTER
	cpu_hand_box.add_theme_constant_override("separation", 4)
	cpu_v.add_child(cpu_hand_box)

	var table_panel := _panel(Color("#181529"))
	root.add_child(table_panel)
	var table := HBoxContainer.new()
	table.alignment = BoxContainer.ALIGNMENT_CENTER
	table.add_theme_constant_override("separation", 58)
	table_panel.add_child(table)
	var deck_v := VBoxContainer.new()
	deck_v.add_child(_label("DRAW PILE", 13, Color("#9e96b9")))
	deck_label = _label("▧ 52", 30, Color("#8f7cdb"))
	deck_v.add_child(deck_label)
	table.add_child(deck_v)
	var discard_v := VBoxContainer.new()
	discard_v.add_child(_label("DISCARD", 13, Color("#9e96b9")))
	discard_label = _label("--", 30, Color("#ffffff"))
	discard_v.add_child(discard_label)
	table.add_child(discard_v)

	var player_panel := _panel(Color("#25203b"))
	player_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(player_panel)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 8)
	player_panel.add_child(pv)
	var p_row := HBoxContainer.new()
	pv.add_child(p_row)
	p_row.add_child(_label("YOU • PIP", 21, Color("#f2ecff")))
	player_hp_bar = _hp_bar()
	p_row.add_child(player_hp_bar)
	player_hp_label = _label("40/40", 15, Color.WHITE)
	p_row.add_child(player_hp_label)
	player_status = _label("", 14, Color("#9be3b2"))
	pv.add_child(player_status)

	var squad := HBoxContainer.new()
	squad.alignment = BoxContainer.ALIGNMENT_CENTER
	squad.add_theme_constant_override("separation", 12)
	for data in [
		["♥", "Cinderkit", "#ff7b72", "cinderkit"], ["♦", "Glimbug", "#ffd166", "glimbug"],
		["♣", "Mosshell", "#75e6a4", "mosshell"], ["♠", "Noxling", "#9e8cff", "noxling"]
	]:
		var creature := VBoxContainer.new()
		creature.alignment = BoxContainer.ALIGNMENT_CENTER
		var portrait := TextureRect.new()
		portrait.texture = load("res://assets/meldlings/%s.svg" % data[3])
		portrait.custom_minimum_size = Vector2(52, 52)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		creature.add_child(portrait)
		var chip := Label.new()
		chip.text = "%s %s" % [data[0], data[1]]
		chip.add_theme_font_size_override("font_size", 12)
		chip.add_theme_color_override("font_color", Color(data[2]))
		creature.add_child(chip)
		squad.add_child(creature)
	pv.add_child(squad)

	status_label = _label("DRAW A CARD", 18, Color("#ffd166"))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(status_label)

	hand_box = HBoxContainer.new()
	hand_box.alignment = BoxContainer.ALIGNMENT_CENTER
	hand_box.add_theme_constant_override("separation", -3)
	hand_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pv.add_child(hand_box)

	var draws := HBoxContainer.new()
	draws.add_theme_constant_override("separation", 8)
	pv.add_child(draws)
	draw_deck_button = _button("DRAW DECK", _on_draw_deck)
	draw_discard_button = _button("TAKE DISCARD", _on_draw_discard)
	draw_deck_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	draw_discard_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	draws.add_child(draw_deck_button)
	draws.add_child(draw_discard_button)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	pv.add_child(actions)
	play_button = _button("PLAY SELECTED", _on_play_selected)
	discard_button = _button("DISCARD", _on_discard)
	play_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	discard_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(play_button)
	actions.add_child(discard_button)

	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.fit_content = false
	log_label.custom_minimum_size.y = 118
	log_label.scroll_active = true
	log_label.add_theme_font_size_override("normal_font_size", 13)
	log_label.add_theme_color_override("default_color", Color("#c9c2dd"))
	root.add_child(log_label)

	var footer := HBoxContainer.new()
	root.add_child(footer)
	var camp := _button("CAMP", _show_camp)
	footer.add_child(camp)
	var help := _button("RULES", _show_rules)
	footer.add_child(help)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	footer.add_child(_label("R = restart", 12, Color("#6f6885")))

	modal_layer = ColorRect.new()
	modal_layer.color = Color(0.03, 0.025, 0.06, 0.94)
	modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.visible = false
	add_child(modal_layer)
	var modal_margin := MarginContainer.new()
	modal_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_margin.add_theme_constant_override("margin_left", 70)
	modal_margin.add_theme_constant_override("margin_right", 70)
	modal_margin.add_theme_constant_override("margin_top", 150)
	modal_margin.add_theme_constant_override("margin_bottom", 150)
	modal_layer.add_child(modal_margin)
	modal_content = VBoxContainer.new()
	modal_content.alignment = BoxContainer.ALIGNMENT_CENTER
	modal_content.add_theme_constant_override("separation", 16)
	modal_margin.add_child(modal_content)

func _start_battle() -> void:
	battle_over = false
	player_max_hp = 40 + vitality_rank
	player_hp = player_max_hp
	cpu_max_hp = 40
	cpu_hp = cpu_max_hp
	player_block = 0
	cpu_block = 0
	player_thorns = 0
	cpu_thorns = 0
	player_burn = 0
	cpu_burn = 0
	player_hex = 0
	cpu_hex = 0
	prepared_suit = ""
	cpu_prepared_suit = ""
	first_brace_heal_used = false
	phase = "draw"
	selected.clear()
	deck = _new_deck()
	deck.shuffle()
	discard_pile.clear()
	player_hand.clear()
	cpu_hand.clear()
	for i in range(7):
		player_hand.append(deck.pop_back())
		cpu_hand.append(deck.pop_back())
	discard_pile.append(deck.pop_back())
	if log_label:
		log_label.text = "[b]FIRST BLOOD[/b]\nMake pairs to BRACE, 2-card runs to PREP, and 3+ card melds to attack."
	_hide_modal()
	_refresh()

func _new_deck() -> Array:
	var cards: Array = []
	for suit in SUITS:
		for rank in range(1, 14):
			cards.append({"rank": rank, "suit": suit})
	return cards

func _on_draw_deck() -> void:
	if not _can_draw(): return
	if deck.is_empty(): _reshuffle_discards()
	if deck.is_empty(): return
	player_hand.append(deck.pop_back())
	phase = "action"
	sound.draw_card()
	_log("You draw from the deck.")
	_refresh()

func _on_draw_discard() -> void:
	if not _can_draw() or discard_pile.is_empty(): return
	var card: Dictionary = discard_pile.pop_back()
	player_hand.append(card)
	phase = "action"
	sound.draw_card()
	_log("You take [b]%s[/b] from the discard pile." % rules.card_label(card))
	_refresh()

func _can_draw() -> bool:
	return not battle_over and phase == "draw"

func _on_card_pressed(index: int) -> void:
	if battle_over or phase == "draw": return
	if selected.has(index): selected.erase(index)
	else: selected.append(index)
	sound.select_card()
	_refresh_hand()
	_refresh_buttons()

func _on_play_selected() -> void:
	if battle_over or phase != "action" or selected.is_empty(): return
	var cards := _selected_cards()
	var action := rules.classify(cards)
	if action == rules.ActionType.NONE:
		_flash_status("NOT A VALID PATTERN", Color("#ff7b7b"))
		return
	_resolve_player_action(cards, action)
	_remove_selected_from_player()
	selected.clear()
	phase = "discard"
	_refresh()
	if player_hand.is_empty():
		_end_player_turn_without_discard()

func _on_discard() -> void:
	if battle_over or phase not in ["action", "discard"] or selected.size() != 1: return
	var idx := selected[0]
	var card: Dictionary = player_hand[idx]
	player_hand.remove_at(idx)
	discard_pile.append(card)
	selected.clear()
	_log("You discard [b]%s[/b]." % rules.card_label(card))
	phase = "cpu"
	_refresh()
	call_deferred("_cpu_turn")

func _end_player_turn_without_discard() -> void:
	phase = "cpu"
	call_deferred("_cpu_turn")

func _resolve_player_action(cards: Array, action: int) -> void:
	var action_label: String = rules.action_name(action)
	_log("[color=#ffd166][b]%s![/b][/color] %s" % [action_label, _cards_text(cards)])
	if action == rules.ActionType.BRACE:
		_player_brace(cards)
		sound.defend()
	elif action == rules.ActionType.PREP:
		prepared_suit = str(cards[0].suit)
		player_block += 2
		_log("Prep stores %s momentum and grants 2 Block." % prepared_suit)
		sound.defend()
	else:
		var damage := _offense_damage(cards, action, true)
		_damage_cpu(damage)
		_apply_player_suit_offense(cards, action)
		sound.meld()
	_check_end()

func _player_brace(cards: Array) -> void:
	for card in cards:
		match str(card.suit):
			"♥":
				player_block += 4
				if player_burn > 0:
					player_burn = max(0, player_burn - 2)
					_log("Cinderkit's Warmth cleanses 2 Burn.")
				if relics.has("Second Wind") and player_hp <= 10 and not first_brace_heal_used:
					player_hp = min(player_max_hp, player_hp + 3)
					first_brace_heal_used = true
					_log("Second Wind restores 3 HP.")
			"♦":
				player_block += 3
				_log("Glimbug's Bargain steadies your hand.")
			"♣":
				player_block += 5
				player_thorns += 3 + (2 if relics.has("Spiteful Shell") else 0)
				_log("Mosshell grows Thorns.")
			"♠":
				player_block += 2
				player_hex = max(0, player_hex - 1)
				_log("Noxling fades one Hex.")

func _offense_damage(cards: Array, action: int, is_player: bool) -> int:
	var count := cards.size()
	var base := 0
	if action == rules.ActionType.STRIKE: base = 3 + count * 3
	elif action == rules.ActionType.RALLY: base = count * 4
	elif action == rules.ActionType.GRAND_MELD: base = 22
	var prep := prepared_suit if is_player else cpu_prepared_suit
	if action == rules.ActionType.STRIKE and prep == str(cards[0].suit):
		base += 3
		if is_player: prepared_suit = ""
		else: cpu_prepared_suit = ""
	return base

func _apply_player_suit_offense(cards: Array, _action: int) -> void:
	var seen: Array[String] = []
	for card in cards:
		var suit := str(card.suit)
		if seen.has(suit): continue
		seen.append(suit)
		match suit:
			"♥":
				var burn_gain := 1 + (1 if relics.has("Burning Memory") else 0)
				cpu_burn += burn_gain
				_log("Cinderkit applies %d Burn." % burn_gain)
			"♦":
				if cards.size() >= 4:
					essence += 1
					_log("Glimbug pockets 1 Essence.")
			"♣":
				player_block += cards.size()
				_log("Mosshell grants %d Block." % cards.size())
			"♠":
				var bonus := cpu_hex * 2
				if bonus > 0:
					_damage_cpu(bonus)
					_log("Noxling cashes Hex for %d bonus damage." % bonus)

func _cpu_turn() -> void:
	if battle_over: return
	cpu_block = 0
	cpu_thorns = 0
	_apply_turn_start_status(false)
	if _check_end(): return
	var top: Dictionary = discard_pile[-1] if not discard_pile.is_empty() else {}
	var source := cpu_ai.choose_draw_source(cpu_hand, top)
	if source == "discard" and not discard_pile.is_empty():
		var taken: Dictionary = discard_pile.pop_back()
		cpu_hand.append(taken)
		player_hex += 1 if str(taken.suit) == "♠" else 0
		_log("Croak takes [b]%s[/b] from your discard." % rules.card_label(taken))
	else:
		if deck.is_empty(): _reshuffle_discards()
		if not deck.is_empty(): cpu_hand.append(deck.pop_back())
		_log("Croak draws from the deck.")
	var choice := cpu_ai.choose_action(cpu_hand, cpu_hp, cpu_max_hp)
	if not choice.is_empty():
		_resolve_cpu_action(choice.cards, int(choice.action))
		_remove_indices(cpu_hand, choice.indices)
	if _check_end(): return
	if not cpu_hand.is_empty():
		var discard_idx := cpu_ai.choose_discard_index(cpu_hand)
		var discarded: Dictionary = cpu_hand[discard_idx]
		cpu_hand.remove_at(discard_idx)
		discard_pile.append(discarded)
		_log("Croak discards [b]%s[/b]." % rules.card_label(discarded))
	player_block = 0
	player_thorns = 0
	phase = "draw"
	_apply_turn_start_status(true)
	_check_end()
	_refresh()

func _resolve_cpu_action(cards: Array, action: int) -> void:
	_log("[color=#ff9f85]Croak %sS[/color] %s" % [rules.action_name(action), _cards_text(cards)])
	if action == rules.ActionType.BRACE:
		for card in cards:
			match str(card.suit):
				"♥": cpu_block += 4; cpu_burn = max(0, cpu_burn - 2)
				"♦": cpu_block += 3
				"♣": cpu_block += 5; cpu_thorns += 3
				"♠": cpu_block += 2; cpu_hex = max(0, cpu_hex - 1)
		sound.defend()
	elif action == rules.ActionType.PREP:
		cpu_prepared_suit = str(cards[0].suit)
		cpu_block += 2
	else:
		var damage := _offense_damage(cards, action, false)
		_damage_player(damage)
		var seen: Array[String] = []
		for card in cards:
			var suit := str(card.suit)
			if seen.has(suit): continue
			seen.append(suit)
			match suit:
				"♥": player_burn += 1
				"♣": cpu_block += cards.size()
				"♠":
					if player_hex > 0: _damage_player(player_hex * 2)
		sound.meld()

func _damage_player(amount: int) -> void:
	var blocked: int = mini(player_block, amount)
	player_block -= blocked
	var dealt: int = amount - blocked
	player_hp -= dealt
	_log("You take [b]%d[/b] damage%s." % [dealt, " (%d blocked)" % blocked if blocked > 0 else ""])
	if dealt > 0 and player_thorns > 0:
		cpu_hp -= player_thorns
		_log("Mosshell retaliates for [b]%d[/b]." % player_thorns)
	sound.hit()

func _damage_cpu(amount: int) -> void:
	var blocked: int = mini(cpu_block, amount)
	cpu_block -= blocked
	var dealt: int = amount - blocked
	cpu_hp -= dealt
	_log("Croak takes [b]%d[/b] damage%s." % [dealt, " (%d blocked)" % blocked if blocked > 0 else ""])
	if dealt > 0 and cpu_thorns > 0:
		player_hp -= cpu_thorns
		_log("Croak's thorns retaliate for [b]%d[/b]." % cpu_thorns)
	sound.hit()

func _apply_turn_start_status(to_player: bool) -> void:
	if to_player:
		if player_burn > 0:
			player_hp -= player_burn
			_log("Burn scorches you for %d." % player_burn)
			player_burn = max(0, player_burn - 1)
	else:
		if cpu_burn > 0:
			cpu_hp -= cpu_burn
			_log("Burn scorches Croak for %d." % cpu_burn)
			cpu_burn = max(0, cpu_burn - 1)

func _check_end() -> bool:
	if battle_over: return true
	if cpu_hp <= 0:
		battle_over = true
		cpu_hp = 0
		essence += 18
		_save()
		sound.win()
		_refresh()
		_show_relic_choice()
		return true
	if player_hp <= 0:
		battle_over = true
		player_hp = 0
		essence += 9
		_save()
		sound.lose()
		_refresh()
		_show_run_end()
		return true
	return false

func _selected_cards() -> Array:
	var cards: Array = []
	for idx in selected:
		if idx >= 0 and idx < player_hand.size(): cards.append(player_hand[idx])
	return cards

func _remove_selected_from_player() -> void:
	var sorted := selected.duplicate()
	sorted.sort()
	sorted.reverse()
	for idx in sorted:
		player_hand.remove_at(idx)

func _remove_indices(hand: Array, indices: Array) -> void:
	var sorted := indices.duplicate()
	sorted.sort()
	sorted.reverse()
	for idx in sorted: hand.remove_at(idx)

func _reshuffle_discards() -> void:
	if discard_pile.size() <= 1: return
	var top = discard_pile.pop_back()
	deck = discard_pile.duplicate(true)
	deck.shuffle()
	discard_pile = [top]

func _refresh() -> void:
	if not hand_box: return
	_refresh_hand()
	_refresh_cpu_hand()
	_refresh_buttons()
	player_hp_bar.max_value = player_max_hp
	player_hp_bar.value = player_hp
	player_hp_label.text = "%d/%d" % [player_hp, player_max_hp]
	cpu_hp_bar.max_value = cpu_max_hp
	cpu_hp_bar.value = cpu_hp
	cpu_hp_label.text = "%d/%d" % [cpu_hp, cpu_max_hp]
	player_status.text = "BLOCK %d   THORNS %d   BURN %d   HEX %d" % [player_block, player_thorns, player_burn, player_hex]
	cpu_status.text = "BLOCK %d   BURN %d   HEX %d" % [cpu_block, cpu_burn, cpu_hex]
	intent_label.text = "INTENT: " + cpu_ai.intent_text(cpu_hand, cpu_hp, cpu_max_hp)
	deck_label.text = "▧ %d" % deck.size()
	discard_label.text = rules.card_label(discard_pile[-1]) if not discard_pile.is_empty() else "--"
	discard_label.add_theme_color_override("font_color", _card_color(discard_pile[-1]) if not discard_pile.is_empty() else Color.WHITE)
	essence_label.text = "ESSENCE %d" % essence
	status_label.text = _phase_text()

func _refresh_hand() -> void:
	for child in hand_box.get_children(): child.queue_free()
	for i in range(min(player_hand.size(), MAX_HAND_VISIBLE)):
		var card: Dictionary = player_hand[i]
		var b := Button.new()
		b.text = rules.card_label(card)
		b.custom_minimum_size = Vector2(76, 112)
		b.add_theme_font_size_override("font_size", 22)
		b.add_theme_color_override("font_color", _card_color(card))
		b.add_theme_color_override("font_hover_color", _card_color(card))
		b.add_theme_color_override("font_pressed_color", _card_color(card))
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#fff8e9") if not selected.has(i) else Color("#ffe19a")
		style.border_color = Color("#6f6688") if not selected.has(i) else Color("#ffd166")
		style.set_border_width_all(3)
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		b.add_theme_stylebox_override("normal", style)
		b.add_theme_stylebox_override("hover", style)
		b.add_theme_stylebox_override("pressed", style)
		b.pressed.connect(_on_card_pressed.bind(i))
		hand_box.add_child(b)

func _refresh_cpu_hand() -> void:
	for child in cpu_hand_box.get_children(): child.queue_free()
	for i in range(cpu_hand.size()):
		var back := Label.new()
		back.text = "▧"
		back.custom_minimum_size = Vector2(42, 58)
		back.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		back.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		back.add_theme_font_size_override("font_size", 24)
		back.add_theme_color_override("font_color", Color("#8976cf"))
		cpu_hand_box.add_child(back)

func _refresh_buttons() -> void:
	draw_deck_button.disabled = not _can_draw()
	draw_discard_button.disabled = not _can_draw() or discard_pile.is_empty()
	var cards := _selected_cards()
	var action := rules.classify(cards)
	play_button.disabled = battle_over or phase != "action" or action == rules.ActionType.NONE
	play_button.text = rules.action_name(action) if action != rules.ActionType.NONE else "PLAY SELECTED"
	discard_button.disabled = battle_over or phase not in ["action", "discard"] or selected.size() != 1

func _phase_text() -> String:
	if battle_over: return "BATTLE COMPLETE"
	match phase:
		"draw": return "DRAW A CARD"
		"action": return "PAIR = BRACE • 2-RUN = PREP • 3+ = ATTACK"
		"discard": return "DISCARD 1 CARD"
		"cpu": return "CROAK'S TURN..."
		_: return ""

func _cards_text(cards: Array) -> String:
	var labels: Array[String] = []
	for card in cards: labels.append(rules.card_label(card))
	return " ".join(labels)

func _card_color(card: Dictionary) -> Color:
	return Color("#cc405d") if str(card.suit) in RED_SUITS else Color("#252036")

func _log(text: String) -> void:
	log_label.append_text("\n" + text)
	log_label.scroll_to_line(max(0, log_label.get_line_count() - 1))

func _flash_status(text: String, color: Color) -> void:
	status_label.text = text
	status_label.add_theme_color_override("font_color", color)
	get_tree().create_timer(0.8).timeout.connect(func():
		status_label.add_theme_color_override("font_color", Color("#ffd166"))
		_refresh()
	)

func _show_relic_choice() -> void:
	_clear_modal()
	modal_layer.visible = true
	modal_content.add_child(_label("VICTORY!", 42, Color("#ffd166")))
	modal_content.add_child(_label("+18 Essence • Choose a relic for the rematch", 17, Color("#ddd6ef")))
	var options := [
		["Spiteful Shell", "Mosshell BRACE gains +2 Thorns."],
		["Second Wind", "First BRACE at 10 HP or less heals 3."],
		["Burning Memory", "Heart offense applies +1 extra Burn."]
	]
	for option in options:
		var b := _button("%s\n%s" % [option[0], option[1]], _choose_relic.bind(option[0]))
		b.custom_minimum_size.y = 92
		modal_content.add_child(b)

func _choose_relic(relic_name: String) -> void:
	if not relics.has(relic_name): relics.append(relic_name)
	_start_battle()
	_log("Relic active: [color=#ffd166]%s[/color]." % relic_name)

func _show_run_end() -> void:
	_clear_modal()
	modal_layer.visible = true
	modal_content.add_child(_label("RUN ENDED", 38, Color("#ff8b8b")))
	modal_content.add_child(_label("+9 Essence. Failure still moves the camp forward.", 17, Color("#ddd6ef")))
	modal_content.add_child(_button("VISIT CAMP", _show_camp))
	modal_content.add_child(_button("TRY AGAIN", _start_battle))

func _show_camp() -> void:
	_clear_modal()
	modal_layer.visible = true
	modal_content.add_child(_label("MELDLING CAMP", 34, Color("#ffd166")))
	modal_content.add_child(_label("Essence: %d" % essence, 20, Color.WHITE))
	modal_content.add_child(_label("VITALITY %d/10\n+1 starting HP per rank" % vitality_rank, 18, Color("#9be3b2")))
	var cost := 20 + vitality_rank * 10
	var upgrade := _button("UPGRADE VITALITY • %d Essence" % cost, _buy_vitality)
	upgrade.disabled = essence < cost or vitality_rank >= 10
	modal_content.add_child(upgrade)
	modal_content.add_child(_label("Prototype cap: permanent stats stay modest. Future progression unlocks Meldlings, relics, evolutions and Fusions.", 15, Color("#aaa3c7")))
	modal_content.add_child(_button("BACK TO TABLE", _hide_modal))

func _buy_vitality() -> void:
	var cost := 20 + vitality_rank * 10
	if essence >= cost and vitality_rank < 10:
		essence -= cost
		vitality_rank += 1
		_save()
	_show_camp()
	_refresh()

func _show_rules() -> void:
	_clear_modal()
	modal_layer.visible = true
	modal_content.add_child(_label("FIRST BLOOD RULES", 32, Color("#ffd166")))
	modal_content.add_child(_label("PAIR → BRACE\nDefensive Meldling abilities.\n\n2-CARD RUN → PREP\nGain 2 Block and empower that suit's next Strike.\n\n3+ SAME-SUIT RUN → STRIKE\nFocused offense.\n\n3+ SAME-RANK SET → RALLY\nEvery represented suit activates.\n\n4-SUIT SET → GRAND MELD\nThe starter jackpot.", 17, Color("#ece6fa")))
	modal_content.add_child(_button("BACK", _hide_modal))

func _hide_modal() -> void:
	if modal_layer: modal_layer.visible = false

func _clear_modal() -> void:
	for child in modal_content.get_children(): child.queue_free()

func _load_save() -> void:
	var config := ConfigFile.new()
	if config.load("user://meldlings_save.cfg") == OK:
		essence = int(config.get_value("progress", "essence", 0))
		vitality_rank = int(config.get_value("progress", "vitality", 0))

func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("progress", "essence", essence)
	config.set_value("progress", "vitality", vitality_rank)
	config.save("user://meldlings_save.cfg")

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 58
	b.add_theme_font_size_override("font_size", 16)
	b.pressed.connect(callback)
	return b

func _panel(color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("#4a4267")
	style.set_border_width_all(2)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _hp_bar() -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(180, 22)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.show_percentage = false
	return bar
