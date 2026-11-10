class_name CardAnimator
extends Control

## A full-rect overlay that owns cards while they are in flight between widgets
## (draw pile -> hand, hand -> discard, hand -> the enemy).
##
## Add one as the LAST child of your battle root so it draws on top:
##   var anim := CardAnimator.new()
##   add_child(anim)
## Then `CardAnimator.instance` resolves from anywhere.

static var instance: CardAnimator

@export var arc_lift: float = 90.0     ## how high a flight bows in the middle
@export var default_time: float = 0.34


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100


func _to_local_pos(global_pos: Vector2) -> Vector2:
	return global_pos - global_position


static func _arc(t: float, a: Vector2, b: Vector2, lift: float) -> Vector2:
	return a.lerp(b, t) - Vector2(0, sin(t * PI) * lift)


## Fly a card from one screen position to another.
## opts: time, lift, spin, flip_at (0..1, -1 = no flip), start_face_up,
##       end_face_up, scale_from, scale_to, fade_out, trans
## Returns a signal you can await.
func fly(card: Dictionary, from_global: Vector2, to_global: Vector2, opts: Dictionary = {}) -> Signal:
	var time: float = opts.get("time", default_time)
	var lift: float = opts.get("lift", arc_lift)
	var spin: float = opts.get("spin", 0.0)
	var flip_at: float = opts.get("flip_at", -1.0)
	var start_up: bool = opts.get("start_face_up", true)
	var end_up: bool = opts.get("end_face_up", true)
	var s_from: float = opts.get("scale_from", 1.0)
	var s_to: float = opts.get("scale_to", 1.0)
	var fade_out: bool = opts.get("fade_out", false)

	var v := CardView.new()
	v.draggable = false
	add_child(v)
	v.setup(int(card.get("rank", 1)), card.get("suit", "S"), start_up)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.pivot_offset = v.size * 0.5

	var a := _to_local_pos(from_global)
	var b := _to_local_pos(to_global)
	v.position = a
	v.scale = Vector2.ONE * s_from
	v.rotation = 0.0

	var flipped := {"done": flip_at < 0.0}
	var step := func(t: float) -> void:
		if not is_instance_valid(v):
			return
		var e: float = 1.0 - pow(1.0 - t, 2.4)          # ease-out
		v.position = _arc(e, a, b, lift)
		v.scale = Vector2.ONE * lerpf(s_from, s_to, e)
		v.rotation = deg_to_rad(spin * sin(e * PI))
		if fade_out:
			v.modulate.a = 1.0 - maxf(0.0, (e - 0.65) / 0.35)
		if not flipped["done"] and e >= flip_at:
			flipped["done"] = true
			v.set_face_up(end_up)

	var tw := create_tween()
	tw.tween_method(step, 0.0, 1.0, time)
	tw.tween_callback(func():
		if is_instance_valid(v):
			v.queue_free())
	return tw.finished


## Convenience: a card leaving the draw pile, flipping face-up on the way in.
func fly_draw(card: Dictionary, from_global: Vector2, to_global: Vector2,
		time: float = 0.30) -> Signal:
	return fly(card, from_global, to_global, {
		"time": time, "lift": 70.0, "spin": -8.0, "flip_at": 0.45,
		"start_face_up": false, "end_face_up": true,
		"scale_from": 0.86, "scale_to": 1.0,
	})


## Convenience: a card thrown onto the discard pile.
func fly_discard(card: Dictionary, from_global: Vector2, to_global: Vector2,
		time: float = 0.26) -> Signal:
	return fly(card, from_global, to_global, {
		"time": time, "lift": 55.0, "spin": 16.0,
		"scale_from": 1.0, "scale_to": 0.94,
	})


## A played meld: cards gather at a focus point, pop, then strike outward.
func fly_meld(cards: Array, from_globals: Array, focus_global: Vector2,
		target_global: Vector2, offensive: bool = true) -> Signal:
	var last: Signal = get_tree().create_timer(0.01).timeout
	for i in cards.size():
		var start: Vector2 = from_globals[i] if i < from_globals.size() else focus_global
		var spread := Vector2((i - (cards.size() - 1) * 0.5) * 26.0, 0)
		var gather := create_tween()
		gather.tween_interval(i * 0.045)
		var c: Dictionary = cards[i]
		gather.tween_callback(func():
				fly(c, start, focus_global + spread, {
					"time": 0.20, "lift": 30.0, "spin": 0.0,
					"scale_from": 1.0, "scale_to": 1.12,
				}))
		gather.tween_interval(0.20)
		gather.tween_callback(func():
				fly(c, focus_global + spread,
					target_global if offensive else focus_global + Vector2(0, 40), {
					"time": 0.26 if offensive else 0.34,
					"lift": 40.0 if offensive else -10.0,
					"spin": 24.0 if offensive else 0.0,
					"scale_from": 1.12, "scale_to": 0.5 if offensive else 0.9,
					"fade_out": true,
				}))
		last = gather.finished
	return last


## Small screen-space impact: a burst of pips at a point. Cheap, no assets.
func impact(at_global: Vector2, color: Color = Color(1, 0.85, 0.4), count: int = 8) -> void:
	var origin := _to_local_pos(at_global)
	for i in count:
		var dot := ColorRect.new()
		dot.color = color
		dot.size = Vector2(6, 6)
		dot.position = origin
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dot)
		var ang := TAU * (float(i) / count) + randf_range(-0.2, 0.2)
		var dist := randf_range(40.0, 90.0)
		var dest := origin + Vector2(cos(ang), sin(ang)) * dist
		var tw := create_tween().set_parallel(true)
		tw.tween_property(dot, "position", dest, 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(dot, "modulate:a", 0.0, 0.34)
		tw.tween_property(dot, "size", Vector2(2, 2), 0.34)
		tw.chain().tween_callback(dot.queue_free)
