class_name CardView
extends Control

## One card on screen. Builds its own children -- no .tscn needed.
##   var c := CardView.new()
##   c.setup(7, "H")
##   add_child(c)

signal pressed(card_view: CardView)
signal drag_started(card_view: CardView)

enum State { NORMAL, SELECTED, VALID, INVALID, DIM }

const PIXEL_SCALE := 2

var rank: int = 1
var suit: String = "S"
var face_up: bool = true
var draggable: bool = true
var state: int = State.NORMAL

var _face: TextureRect
var _frame: TextureRect
var _tween: Tween
var _hover_tween: Tween
var base_rotation: float = 0.0
var _base_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	custom_minimum_size = Vector2(CardArt.BASE_W, CardArt.BASE_H) * PIXEL_SCALE
	size = custom_minimum_size
	pivot_offset = size * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP

	_face = TextureRect.new()
	_face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_face.stretch_mode = TextureRect.STRETCH_SCALE
	_face.set_anchors_preset(Control.PRESET_FULL_RECT)
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_face)

	_frame = TextureRect.new()
	_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frame.stretch_mode = TextureRect.STRETCH_SCALE
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.visible = false
	add_child(_frame)

	_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		pivot_offset = size * 0.5


func setup(p_rank: int, p_suit, p_face_up: bool = true) -> CardView:
	rank = p_rank
	suit = CardArt.suit_letter(p_suit)
	face_up = p_face_up
	if is_node_ready():
		_refresh()
	return self


func as_data() -> Dictionary:
	return {"rank": rank, "suit": suit}


func set_face_up(v: bool) -> void:
	face_up = v
	if is_node_ready():
		_refresh()


func set_state(s: int) -> void:
	state = s
	if is_node_ready():
		_refresh()


func _refresh() -> void:
	_face.texture = CardArt.face(rank, suit) if face_up else CardArt.back()

	match state:
		State.SELECTED:
			_frame.texture = CardArt.frame("selected")
			_frame.visible = true
			modulate = Color.WHITE
		State.VALID:
			_frame.texture = CardArt.frame("valid")
			_frame.visible = true
			modulate = Color.WHITE
		State.INVALID:
			_frame.texture = CardArt.frame("invalid")
			_frame.visible = true
			modulate = Color.WHITE
		State.DIM:
			_frame.visible = false
			modulate = Color(0.55, 0.55, 0.62, 1.0)
		_:
			_frame.visible = false
			modulate = Color.WHITE


## Remember where the layout wants this card, so lift/settle can animate around it.
func set_base_position(p: Vector2, animate: bool = true) -> void:
	_base_pos = p
	_animate_to(p, animate)


func lift(amount: float = 22.0, animate: bool = true) -> void:
	_animate_to(_base_pos + Vector2(0, -amount), animate)


func settle(animate: bool = true) -> void:
	_animate_to(_base_pos, animate)


func _animate_to(target: Vector2, animate: bool) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	if not animate:
		position = target
		return
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position", target, 0.14)


func flash_reject() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "position", _base_pos + Vector2(6, 0), 0.05)
	_tween.tween_property(self, "position", _base_pos + Vector2(-6, 0), 0.05)
	_tween.tween_property(self, "position", _base_pos, 0.05)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed.emit(self)
		accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		pressed.emit(self)
		accept_event()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not draggable or not face_up:
		return null

	var preview := TextureRect.new()
	preview.texture = CardArt.face(rank, suit)
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_SCALE
	preview.size = size
	preview.modulate.a = 0.9

	var holder := Control.new()
	holder.add_child(preview)
	preview.position = -size * 0.5
	set_drag_preview(holder)

	drag_started.emit(self)
	return {"type": "card", "source": self, "card": as_data()}


# ------------------------------------------------------------------ flourishes
## Flip between face and back with a horizontal squash, swapping at the midpoint.
func flip_to(p_face_up: bool, dur: float = 0.22) -> Signal:
	if _tween and _tween.is_valid():
		_tween.kill()
	pivot_offset = size * 0.5
	_tween = create_tween()
	_tween.tween_property(self, "scale:x", 0.02, dur * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func(): set_face_up(p_face_up))
	_tween.tween_property(self, "scale:x", 1.0, dur * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return _tween.finished


## Scale punch -- use on deal-in, on a valid meld, on anything that should feel good.
func pop(strength: float = 0.22, dur: float = 0.26) -> void:
	pivot_offset = size * 0.5
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE * (1.0 + strength), dur * 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2.ONE, dur * 0.65) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Fade + scale in from nothing, for a card arriving in the hand.
func appear(dur: float = 0.20) -> void:
	pivot_offset = size * 0.5
	modulate.a = 0.0
	scale = Vector2.ONE * 0.7
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, dur)
	tw.tween_property(self, "scale", Vector2.ONE, dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Shrink away, then free. Returns a signal so callers can await the removal.
func vanish(dur: float = 0.18) -> Signal:
	pivot_offset = size * 0.5
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, dur)
	tw.tween_property(self, "scale", Vector2.ONE * 0.6, dur)
	tw.chain().tween_callback(queue_free)
	return tw.finished


## Idle hover wobble for the currently selected card.
func set_hover(on: bool) -> void:
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()
	if not on:
		_hover_tween = create_tween()
		_hover_tween.tween_property(self, "rotation", base_rotation, 0.16)
		return
	_hover_tween = create_tween().set_loops()
	_hover_tween.tween_property(self, "rotation", base_rotation + deg_to_rad(1.8), 0.9) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_hover_tween.tween_property(self, "rotation", base_rotation - deg_to_rad(1.8), 0.9) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
