class_name CardView
extends Control

## One card on screen. Builds its own children -- no .tscn needed.
##   var c := CardView.new()
##   c.setup(7, "H")
##   add_child(c)

signal pressed(card_view: CardView)
signal drag_started(card_view: CardView)
## A drag let go: how far the card travelled (global px) and how fast it was
## moving (px/s). The owner decides what that means; a tap is `pressed`.
signal drag_ended(card_view: CardView, travel: Vector2, velocity: Vector2)

const DRAG_SLOP := 12.0       ## px before a touch becomes a drag (a tap below)

enum State { NORMAL, SELECTED, VALID, INVALID, DIM }

static var PIXEL_SCALE: int = 2

var rank: int = 1
var suit: String = "S"
var face_up: bool = true
var draggable: bool = true
var state: int = State.NORMAL
## Meldlings card extras: a mark (CribData.ENHANCEMENTS key) and a split rank.
var enh: String = ""
var rank2: int = 0            ## 0 = not a split card
var suit2: String = ""

var _glow: Panel
var _face: TextureRect
var _mark: TextureRect
var _split: Control
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

	# Mark glow behind the card (web: box-shadow 0 0 10px 2px in the mark tint).
	_glow = Panel.new()
	_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.visible = false
	add_child(_glow)

	_face = TextureRect.new()
	_face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_face.stretch_mode = TextureRect.STRETCH_SCALE
	_face.set_anchors_preset(Control.PRESET_FULL_RECT)
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_face)

	_mark = _pixel_rect()
	_mark.visible = false
	add_child(_mark)

	_split = Control.new()
	_split.set_anchors_preset(Control.PRESET_FULL_RECT)
	_split.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_split)

	_frame = TextureRect.new()
	_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frame.stretch_mode = TextureRect.STRETCH_SCALE
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.visible = false
	add_child(_frame)

	_refresh()


func _pixel_rect() -> TextureRect:
	var t := TextureRect.new()
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		pivot_offset = size * 0.5
		if _split != null:
			_layout_split()


## Plain card. Clears any mark or split rank, since views get reused.
func setup(p_rank: int, p_suit, p_face_up: bool = true) -> CardView:
	rank = p_rank
	suit = CardArt.suit_letter(p_suit)
	face_up = p_face_up
	enh = ""
	rank2 = 0
	suit2 = ""
	if is_node_ready():
		_refresh()
	return self


## A card dictionary straight from the engine: rank, suit, optional enh/rank2/suit2.
func setup_card(card: Dictionary, p_face_up: bool = true) -> CardView:
	rank = int(card.rank)
	suit = CardArt.suit_letter(card.suit)
	face_up = p_face_up
	enh = str(card.get("enh", "")) if card.get("enh") != null else ""
	rank2 = int(card.rank2) if card.get("rank2") != null else 0
	suit2 = CardArt.suit_letter(card.suit2) if card.get("suit2") != null else suit
	if is_node_ready():
		_refresh()
	return self


func as_data() -> Dictionary:
	var d := {"rank": rank, "suit": suit}
	if enh != "":
		d["enh"] = enh
	if rank2 != 0:
		d["rank2"] = rank2
		d["suit2"] = suit2
	return d


func set_face_up(v: bool) -> void:
	face_up = v
	if is_node_ready():
		_refresh()


func set_state(s: int) -> void:
	state = s
	if is_node_ready():
		_refresh()


func _refresh() -> void:
	var split := face_up and rank2 != 0
	if not face_up:
		_face.texture = CardArt.back()
	elif split:
		_face.texture = CardArt.split_frame()
	else:
		_face.texture = CardArt.face(rank, suit)
	_build_split(split)

	# Split cards draw as the plain split face, as on the web (Ziah prefers that look),
	# so a split card's mark is not drawn. The engine still scores the mark.
	var marked := face_up and enh != "" and rank2 == 0
	var mt := CardArt.mark(enh) if marked else null
	_mark.texture = mt
	_mark.visible = mt != null
	_glow.visible = marked
	if marked:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.shadow_color = CardArt.mark_tint(enh)
		sb.shadow_size = 10
		sb.set_expand_margin_all(2)
		sb.set_corner_radius_all(6)
		_glow.add_theme_stylebox_override("panel", sb)
	# Brittle reads as slightly see-through, as on the web.
	_face.self_modulate.a = 0.93 if marked and enh == "glass" else 1.0

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


## Split card: the web's splitCardEl, as AtlasTexture children in card pixels.
## Corner glyph + pip for each rank, and a big glyph for each half.
func _build_split(on: bool) -> void:
	for c in _split.get_children():
		_split.remove_child(c)
		c.queue_free()
	_split.visible = on
	if not on:
		return
	var put := func(r: int, su: String, x: int, y: int, big: bool):
		var g := _pixel_rect()
		g.set_anchors_preset(Control.PRESET_TOP_LEFT)
		g.texture = CardArt.split_glyph(r, su, big)
		g.set_meta("px", Rect2(Vector2(x, y), Vector2(CardArt.SPLIT_GLYPH_BIG if big else CardArt.SPLIT_GLYPH)))
		_split.add_child(g)
		if not big:
			var p := _pixel_rect()
			p.set_anchors_preset(Control.PRESET_TOP_LEFT)
			p.texture = CardArt.split_pip(su)
			p.set_meta("px", Rect2(Vector2(x + 2, y + 8), Vector2(CardArt.SPLIT_PIP)))
			_split.add_child(p)
	put.call(rank, suit, 5, 7, false)
	put.call(rank2, suit2, CardArt.BASE_W - 16, CardArt.BASE_H - 22, false)
	put.call(rank, suit, 6, 34, true)
	put.call(rank2, suit2, CardArt.BASE_W - 28, 52, true)
	_layout_split()


func _layout_split() -> void:
	var k := size / Vector2(CardArt.BASE_W, CardArt.BASE_H)
	for c in _split.get_children():
		var r: Rect2 = c.get_meta("px")
		c.position = r.position * k
		c.size = r.size * k


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
	if _dragging:
		return                     # the finger owns it; release_to takes over
	if _spring_on:
		_spring_to = target        # a moving card retargets without a jump
		return
	if not animate or MeldSprite.reduce_motion:
		position = target
		return
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position", target, 0.14)


func flash_reject() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_spring_on = false
	_tween = create_tween()
	_tween.tween_property(self, "position", _base_pos + Vector2(6, 0), 0.05)
	_tween.tween_property(self, "position", _base_pos + Vector2(-6, 0), 0.05)
	_tween.tween_property(self, "position", _base_pos, 0.05)


func _gui_input(event: InputEvent) -> void:
	# Mouse only. Touch arrives as an emulated mouse click
	# (input_devices/pointing/emulate_mouse_from_touch, pinned in project.godot).
	# Also handling InputEventScreenTouch fired `pressed` twice per tap
	# (measured in tests/screen_test.gd), and the second read as a double-tap.
	# A tap fires on release; a touch that travels DRAG_SLOP becomes a 1:1 drag.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_down = true
			_dragging = false
			_down_at = event.global_position
			_grab = get_global_transform().affine_inverse() * event.global_position   # card-local
			_vel = Vector2.ZERO
			_last_t = Time.get_ticks_usec()
			_last_p = event.global_position
			scale = Vector2.ONE * 0.97         # touch-down feedback, at once
		elif _down:
			_down = false
			scale = Vector2.ONE
			if _dragging:
				_dragging = false
				z_index = 0
				drag_ended.emit(self, event.global_position - _down_at, _vel)
			else:
				pressed.emit(self)
		accept_event()
	elif event is InputEventMouseMotion and _down:
		var p: Vector2 = event.global_position
		if not _dragging and draggable and face_up and p.distance_to(_down_at) >= DRAG_SLOP:
			_dragging = true
			z_index = 10
			scale = Vector2.ONE
			_spring_on = false
			if _tween and _tween.is_valid():
				_tween.kill()
			drag_started.emit(self)
		if _dragging:
			# 1:1: the point you grabbed stays under your finger
			global_position += p - get_global_transform() * _grab
			var now := Time.get_ticks_usec()
			var dt := maxf(0.001, float(now - _last_t) / 1e6)
			_vel = _vel.lerp((p - _last_p) / dt, 0.6)
			_last_t = now
			_last_p = p
		accept_event()


var _down := false
var _dragging := false
var _down_at := Vector2.ZERO
var _grab := Vector2.ZERO       ## the grabbed point, in card-local coordinates
var _vel := Vector2.ZERO        ## px/s, smoothed over the last moves
var _last_t := 0
var _last_p := Vector2.ZERO
var _spring_on := false
var _spring_v := Vector2.ZERO
var _spring_to := Vector2.ZERO
const SPRING_RESPONSE := 0.32   ## s; critically damped (Apple: damping 1.0)


func is_dragging() -> bool:
	return _dragging


## Hand the release velocity to a spring that carries the card to `target`
## (local), so the motion continues instead of restarting.
func release_to(target: Vector2, velocity: Vector2) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_spring_to = target
	_spring_v = velocity
	_spring_on = true
	if MeldSprite.reduce_motion:
		position = target
		_spring_on = false


func spring_velocity() -> Vector2:
	return _spring_v if _spring_on else Vector2.ZERO


func _process(delta: float) -> void:
	if not _spring_on:
		return
	var w := TAU / SPRING_RESPONSE
	var left := minf(delta, 0.25)
	while left > 0.0:
		var h := minf(left, 1.0 / 240.0)
		_spring_v += ((_spring_to - position) * w * w - _spring_v * 2.0 * w) * h
		position += _spring_v * h
		left -= h
	if position.distance_to(_spring_to) < 0.5 and _spring_v.length() < 20.0:
		position = _spring_to
		_spring_on = false


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
