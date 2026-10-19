class_name Press
extends RefCounted
## Press feedback for every button, in one place (Apple: respond on touch-down).
## Down: scale 0.97 and brighten, at once. Up: spring back (Tween TRANS_SPRING,
## owned by the button, so nothing outlives it). Also lifts every button to the
## 44 pt touch minimum: 81 px on the 720 px canvas.
##   Press.wire(button)  /  Press.wire_all(root)  (skips buttons already wired)

const MIN_H := 81.0
const DOWN_SCALE := 0.97
const BRIGHT := 1.12


static func wire(b: BaseButton) -> void:
	if b.has_meta("press"):
		return
	b.set_meta("press", true)
	if b.size.y < MIN_H:
		var grow := MIN_H - b.size.y
		b.size.y = MIN_H
		b.position.y -= grow / 2.0      # grow about the centre, so layouts stay put
	b.custom_minimum_size.y = maxf(b.custom_minimum_size.y, MIN_H)
	b.button_down.connect(_down.bind(b))
	b.button_up.connect(_up.bind(b))


## Wire every button that ever enters the tree (once per tree). Deferred, so
## the button's own layout has set its size and position first.
static func watch(n: Node) -> void:
	var tree := n.get_tree() if n.is_inside_tree() else null
	if tree == null:
		n.ready.connect(func(): watch(n), CONNECT_ONE_SHOT)
		return
	if tree.has_meta("press_watch"):
		return
	tree.set_meta("press_watch", true)
	tree.node_added.connect(func(node: Node):
		if node is BaseButton:
			(func(): if is_instance_valid(node): wire(node)).call_deferred())
	wire_all(tree.root)


static func wire_all(root: Node) -> int:
	var n := 0
	for c in root.find_children("*", "BaseButton", true, false):
		if not (c as BaseButton).has_meta("press"):
			wire(c)
			n += 1
	if root is BaseButton and not root.has_meta("press"):
		wire(root)
		n += 1
	return n


static func _down(b: BaseButton) -> void:
	if not is_instance_valid(b):
		return
	b.pivot_offset = b.size / 2.0
	if b.has_meta("press_tween"):
		var t: Tween = b.get_meta("press_tween")
		if t and t.is_valid():
			t.kill()
	b.scale = Vector2(DOWN_SCALE, DOWN_SCALE)
	b.self_modulate = Color(BRIGHT, BRIGHT, BRIGHT)
	Sound.play("click")


static func _up(b: BaseButton) -> void:
	if not is_instance_valid(b) or not b.is_inside_tree():
		return
	b.self_modulate = Color.WHITE
	if MeldSprite.reduce_motion:
		b.scale = Vector2.ONE
		return
	var t := b.create_tween()
	t.tween_property(b, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
	b.set_meta("press_tween", t)
