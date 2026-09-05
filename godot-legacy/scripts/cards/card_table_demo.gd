extends Control

## Runnable showcase: animated card UI + creatures + audio.
## Press F6 on scenes/CardTable.tscn.
##
## R = redeal, E = next enemy, M = mute music, Esc = clear selection.

const HAND_SIZE := 10

var deck: Array = []
var discard: Array = []
var enemy_pool: Array = ["deadwood", "shuffler", "jokester", "kingpin"]
var enemy_i: int = 0
var _prev_selected: int = 0
var _busy: bool = false

var hand: HandView
var draw_pile: PileView
var discard_pile: PileView
var banner: Label
var action_label: Label
var play_button: Button
var hero: CreatureView
var foe: CreatureView
var foe_label: Label
var audio: AudioDirector
var anim: CardAnimator


func _ready() -> void:
	audio = AudioDirector.new()
	add_child(audio)
	_build_ui()
	anim = CardAnimator.new()
	add_child(anim)              # last child == draws on top of everything
	await get_tree().process_frame
	await _new_round()
	audio.music("bgm_battle")


# ------------------------------------------------------------------ ui
func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.08, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	root.offset_left = 16
	root.offset_right = -16
	root.offset_top = 20
	root.offset_bottom = -20
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(root)

	action_label = Label.new()
	action_label.text = "MELDLINGS"
	action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_label.add_theme_font_size_override("font_size", 32)
	action_label.add_theme_color_override("font_color", Color(0.91, 0.71, 0.30))
	action_label.pivot_offset = Vector2(180, 20)
	root.add_child(action_label)

	var arena := HBoxContainer.new()
	arena.alignment = BoxContainer.ALIGNMENT_CENTER
	arena.add_theme_constant_override("separation", 40)
	arena.custom_minimum_size.y = 230
	root.add_child(arena)

	hero = CreatureView.new()
	hero.pixel_scale = 5
	arena.add_child(hero)
	hero.setup("pip")

	foe = CreatureView.new()
	foe.pixel_scale = 5
	foe.flip_h = true
	arena.add_child(foe)
	foe.setup(enemy_pool[enemy_i])

	foe_label = Label.new()
	foe_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foe_label.add_theme_font_size_override("font_size", 16)
	foe_label.add_theme_color_override("font_color", Color(0.75, 0.72, 0.82))
	root.add_child(foe_label)

	var piles := HBoxContainer.new()
	piles.alignment = BoxContainer.ALIGNMENT_CENTER
	piles.add_theme_constant_override("separation", 44)
	piles.custom_minimum_size.y = 215
	root.add_child(piles)

	draw_pile = PileView.new()
	draw_pile.mode = PileView.Mode.DRAW
	draw_pile.label_text = "DRAW"
	draw_pile.draw_requested.connect(_on_draw)
	piles.add_child(draw_pile)

	discard_pile = PileView.new()
	discard_pile.mode = PileView.Mode.DISCARD
	discard_pile.label_text = "DISCARD"
	discard_pile.card_dropped.connect(_on_card_dropped)
	piles.add_child(discard_pile)

	banner = Label.new()
	banner.text = "Tap cards to build a meld"
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 19)
	banner.add_theme_color_override("font_color", Color(0.8, 0.8, 0.88))
	root.add_child(banner)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(spacer)

	hand = HandView.new()
	hand.custom_minimum_size.y = CardArt.BASE_H * CardView.PIXEL_SCALE + 34
	hand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand.fan_tilt_deg = 2.0
	hand.selection_changed.connect(_on_selection_changed)
	hand.card_activated.connect(_on_card_activated)
	root.add_child(hand)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	root.add_child(bar)
	bar.add_child(_button("Sort", func(): hand.sort_by_rank(); audio.sfx("ui_click")))
	bar.add_child(_button("Suit", func(): hand.sort_by_suit(); audio.sfx("ui_click")))
	bar.add_child(_button("Hint", func(): _hint()))
	play_button = _button("PLAY", func(): _play_meld())
	play_button.disabled = true
	bar.add_child(play_button)
	bar.add_child(_button("Discard", func(): _discard_selected()))


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 54)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 17)
	b.pressed.connect(cb)
	return b


# ------------------------------------------------------------------ flow
func _new_round() -> void:
	_busy = true
	deck = CardArt.new_deck()
	deck.shuffle()
	discard.clear()
	hand.set_cards([], false)
	discard_pile.set_top_card({})
	draw_pile.set_count(deck.size())
	draw_pile.shuffle_flourish()
	audio.sfx("shuffle")
	await get_tree().create_timer(0.42).timeout

	# deal one card at a time, each flying off the draw pile
	for i in HAND_SIZE:
		var card: Dictionary = deck.pop_back()
		var to := hand.next_slot_global_position()
		hand.append_card(card, true)
		draw_pile.punch(0.10)
		draw_pile.tick_count(deck.size())
		audio.sfx("card_draw", -6.0, 1.0 + i * 0.012)
		var idx := hand.card_count() - 1
		var landed := anim.fly_draw(card, draw_pile.card_global_position(), to, 0.26)
		landed.connect(func(): hand.reveal_at(idx, false), CONNECT_ONE_SHOT)
		await get_tree().create_timer(0.075).timeout

	await get_tree().create_timer(0.24).timeout
	hand.sort_by_rank()
	discard.append(deck.pop_back())
	discard_pile.receive(discard[-1])
	draw_pile.tick_count(deck.size())
	_prev_selected = 0
	_sync_foe()
	_busy = false


func _sync_foe() -> void:
	var id: String = enemy_pool[enemy_i]
	foe.setup(id)
	var d := CreatureDB.get_data(id)
	foe_label.text = "%s  ·  %d HP  ·  %s" % [d.get("name", id), d.get("hp", 0), d.get("blurb", "")]
	audio.music(CreatureDB.music_for(id))


func _on_draw() -> void:
	if _busy:
		return
	if deck.is_empty():
		_flash("Deck empty")
		audio.sfx("card_invalid")
		return
	_busy = true
	var card: Dictionary = deck.pop_back()
	var to := hand.next_slot_global_position()
	var idx := hand.append_card(card, true)
	draw_pile.punch()
	draw_pile.tick_count(deck.size())
	audio.sfx("card_draw")
	await anim.fly_draw(card, draw_pile.card_global_position(), to)
	hand.reveal_at(idx)
	_busy = false


func _on_selection_changed(cards: Array, verdict: Dictionary) -> void:
	play_button.disabled = not verdict.valid
	if cards.size() > _prev_selected:
		audio.sfx("card_select", 0.0, 1.0 + cards.size() * 0.05)
	elif cards.size() < _prev_selected:
		audio.sfx("card_deselect")
	_prev_selected = cards.size()

	if cards.is_empty():
		banner.text = "Tap cards to build a meld"
		_set_action("MELDLINGS", false)
		return
	if verdict.valid:
		banner.text = "%s  →  %s" % [verdict.label, verdict.action]
		_set_action(verdict.action, true)
	else:
		banner.text = "%d selected · %s" % [cards.size(), verdict.label]
		_set_action("—", false)


func _set_action(text: String, punch: bool) -> void:
	if action_label.text == text:
		return
	action_label.text = text
	if not punch:
		return
	action_label.pivot_offset = action_label.size * 0.5
	action_label.scale = Vector2.ONE * 1.25
	create_tween().tween_property(action_label, "scale", Vector2.ONE, 0.24) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_card_activated(index: int) -> void:
	if _busy:
		return
	_throw_to_discard(index)


func _on_card_dropped(card: Dictionary, source: CardView) -> void:
	var index := hand.index_of_view(source)
	if index >= 0:
		_throw_to_discard(index)


func _throw_to_discard(index: int) -> void:
	var from := hand.slot_global_position(index)
	var card := hand.remove_at(index, false)
	if card.is_empty():
		return
	_prev_selected = 0
	audio.sfx("card_place")
	await anim.fly_discard(card, from, discard_pile.card_global_position())
	discard.append(card)
	discard_pile.receive(card)


func _play_meld() -> void:
	if _busy:
		return
	var verdict := MeldRules.classify(hand.get_selected_cards())
	if not verdict.valid:
		return
	_busy = true
	play_button.disabled = true

	var idx := hand.get_selected_indices()
	var starts: Array = []
	for i in idx:
		starts.append(hand.slot_global_position(i))
	var played := hand.remove_selected(false)
	_prev_selected = 0

	var focus: Vector2 = get_global_rect().get_center() - Vector2(0, 60)
	var target: Vector2 = foe.global_position + foe.size * 0.5
	var offensive: bool = verdict.kind in [MeldRules.Kind.RUN, MeldRules.Kind.SET,
			MeldRules.Kind.GRAND]

	audio.sfx_for_action(verdict.action)
	if verdict.kind == MeldRules.Kind.GRAND:
		audio.duck(-9.0, 0.15, 1.1)
	await anim.fly_meld(played, starts, focus, target, offensive)

	if offensive:
		hero.attack()
		await get_tree().create_timer(0.18).timeout
		foe.hurt()
		anim.impact(target, Color(1, 0.86, 0.42), 10 if verdict.kind == MeldRules.Kind.GRAND else 6)
		audio.sfx("hit_heavy" if verdict.kind == MeldRules.Kind.GRAND else "hit_light")
		_shake(6.0 if verdict.kind == MeldRules.Kind.GRAND else 3.0)
	else:
		hero.attack()
		anim.impact(hero.global_position + hero.size * 0.5, Color(0.55, 0.8, 1.0), 6)
		audio.sfx("block", -4.0)

	for c in played:
		discard.append(c)
	discard_pile.receive(discard[-1])
	_flash("%s!  (%d cards)" % [verdict.action, played.size()])
	_busy = false


func _discard_selected() -> void:
	if _busy:
		return
	var sel := hand.get_selected_indices()
	if sel.size() != 1:
		_flash("Select exactly one card to discard")
		audio.sfx("card_invalid")
		return
	_throw_to_discard(sel[0])


func _hint() -> void:
	if hand.autoselect_best_meld():
		audio.sfx("relic", -6.0)
	else:
		_flash("No meld available — discard and draw")
		audio.sfx("card_invalid")


func _flash(msg: String) -> void:
	banner.text = msg
	banner.pivot_offset = banner.size * 0.5
	banner.modulate.a = 0.4
	create_tween().tween_property(banner, "modulate:a", 1.0, 0.22)


func _shake(strength: float = 4.0, dur: float = 0.22) -> void:
	var tw := create_tween()
	var steps := 5
	for i in steps:
		var s := strength * (1.0 - float(i) / steps)
		tw.tween_property(self, "position",
			Vector2(randf_range(-s, s), randf_range(-s, s)), dur / steps)
	tw.tween_property(self, "position", Vector2.ZERO, dur / steps)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		hand.clear_selection()
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:
				if not _busy:
					_new_round()
			KEY_E:
				enemy_i = (enemy_i + 1) % enemy_pool.size()
				_sync_foe()
				foe.hurt()
			KEY_M:
				if audio._current_track == "":
					audio.music(CreatureDB.music_for(enemy_pool[enemy_i]))
				else:
					audio.stop_music()
