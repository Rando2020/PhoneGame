class_name PileView
extends Control

## Two modes:
##   MODE_DRAW    -- face-down stack, tap to draw, shows remaining count
##   MODE_DISCARD -- shows the top card, accepts dragged cards as a drop target

signal draw_requested()
signal card_dropped(card: Dictionary, source: CardView)

enum Mode { DRAW, DISCARD }

@export var mode: Mode = Mode.DRAW
@export var label_text: String = ""

var count: int = 0
var top_card: Dictionary = {}

var _art: TextureRect
var _label: Label
var _count_label: Label
var _highlight: TextureRect


func _ready() -> void:
	custom_minimum_size = Vector2(CardArt.BASE_W, CardArt.BASE_H) * CardView.PIXEL_SCALE
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP

	_art = TextureRect.new()
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_SCALE
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.pivot_offset = size * 0.5
	add_child(_art)

	_highlight = TextureRect.new()
	_highlight.texture = CardArt.frame("valid")
	_highlight.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_highlight.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_highlight.stretch_mode = TextureRect.STRETCH_SCALE
	_highlight.set_anchors_preset(Control.PRESET_FULL_RECT)
	_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_highlight.visible = false
	add_child(_highlight)

	_label = Label.new()
	_label.text = label_text
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	_label.position = Vector2(0, size.y + 4)
	_label.size = Vector2(size.x, 20)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)

	_count_label = Label.new()
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.add_theme_font_size_override("font_size", 22)
	_count_label.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	_count_label.add_theme_color_override("font_outline_color", Color(0.1, 0.09, 0.14))
	_count_label.add_theme_constant_override("outline_size", 6)
	_count_label.position = Vector2(0, size.y * 0.5 - 16)
	_count_label.size = Vector2(size.x, 32)
	_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_count_label)

	_refresh()


func set_count(n: int) -> void:
	count = n
	if is_node_ready():
		_refresh()


func set_top_card(card: Dictionary) -> void:
	top_card = card
	if is_node_ready():
		_refresh()


func _refresh() -> void:
	if mode == Mode.DRAW:
		_art.texture = CardArt.pile_draw() if count > 0 else CardArt.pile_empty()
		_count_label.text = str(count) if count > 0 else ""
	else:
		if top_card.is_empty():
			_art.texture = CardArt.pile_empty()
		else:
			_art.texture = CardArt.face(int(top_card.rank), top_card.suit)
		_count_label.text = ""
	_label.text = label_text


func _gui_input(event: InputEvent) -> void:
	if mode != Mode.DRAW or count <= 0:
		return
	var hit := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		hit = true
	elif event is InputEventScreenTouch and event.pressed:
		hit = true
	if hit:
		draw_requested.emit()
		accept_event()


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var ok: bool = mode == Mode.DISCARD and data is Dictionary and data.get("type", "") == "card"
	_highlight.visible = ok
	return ok


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_highlight.visible = false
	card_dropped.emit(data["card"], data["source"])


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and is_instance_valid(_highlight):
		_highlight.visible = false


# ------------------------------------------------------------------ flourishes
## Where a flying card should start from / land on.
func card_global_position() -> Vector2:
	return global_position


## Squash the pile downward -- use when a card is taken off the draw pile.
func punch(strength: float = 0.12, dur: float = 0.20) -> void:
	pivot_offset = size * 0.5
	var tw := create_tween()
	tw.tween_property(_art, "scale", Vector2(1.0 + strength, 1.0 - strength), dur * 0.35) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_art, "scale", Vector2.ONE, dur * 0.65) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Swap the visible top card with an impact bounce. Call when a discard lands.
func receive(card: Dictionary) -> void:
	set_top_card(card)
	pivot_offset = size * 0.5
	_art.pivot_offset = _art.size * 0.5
	_art.scale = Vector2(1.16, 0.84)
	_art.rotation = deg_to_rad(randf_range(-5.0, 5.0))
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_art, "scale", Vector2.ONE, 0.26) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_art, "rotation", 0.0, 0.30) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Ripple the count badge when the deck size changes.
func tick_count(n: int) -> void:
	set_count(n)
	if _count_label == null:
		return
	_count_label.pivot_offset = _count_label.size * 0.5
	_count_label.scale = Vector2.ONE * 1.35
	create_tween().tween_property(_count_label, "scale", Vector2.ONE, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Riffle the draw pile at the start of a round.
func shuffle_flourish() -> void:
	if mode != Mode.DRAW:
		return
	_art.pivot_offset = _art.size * 0.5
	var tw := create_tween()
	for i in 4:
		tw.tween_property(_art, "rotation", deg_to_rad(6.0 if i % 2 == 0 else -6.0), 0.07)
		tw.parallel().tween_property(_art, "position:x", 5.0 if i % 2 == 0 else -5.0, 0.07)
	tw.tween_property(_art, "rotation", 0.0, 0.10)
	tw.parallel().tween_property(_art, "position:x", 0.0, 0.10)
