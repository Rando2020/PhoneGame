class_name CutView
extends Control
## Plays a CutPlan: the back rolls (longer for better cuts), the face lands, the
## word and the "from the cut" line appear. One node-owned Tween sequence (no
## await). skip() renders the end state directly, so it lands where a full play does.

signal finished

const INK := Color(0.96, 0.93, 0.88)
const GOLD := Color(0.91, 0.71, 0.30)
const PIP_COLORS := {"perfect": [Color(0.91, 0.71, 0.30), Color.WHITE, Color(0.43, 0.79, 0.54)],
	"great": [Color(0.91, 0.71, 0.30), Color.WHITE], "_": [Color(0.45, 0.62, 0.95), Color.WHITE]}

var plan = null
var done := true
var card: CardView
var word: Label
var sub: Label
var _seq: Tween
var _rest := Vector2.ZERO


func _lab(fs: int, col: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	card = CardView.new()
	card.draggable = false
	add_child(card)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE   # after add_child: CardView._ready sets STOP
	word = _lab(34, GOLD)
	add_child(word)
	sub = _lab(20, Color(INK, 0.6))
	add_child(sub)
	clear()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and card != null:
		_layout()


func _layout() -> void:
	var cs := Vector2(CardArt.BASE_W, CardArt.BASE_H) * CardView.PIXEL_SCALE
	card.position = Vector2((size.x - cs.x) / 2.0, 0)
	word.position = Vector2(0, cs.y + 6)
	word.size = Vector2(size.x, 40)
	sub.position = Vector2(0, cs.y + 46)
	sub.size = Vector2(size.x, 28)


func clear() -> void:
	if _seq and _seq.is_valid():
		_seq.kill()
	plan = null
	done = true
	word.text = ""
	sub.text = ""
	card.rotation = 0.0
	card.setup(1, "S", false)
	_kill_pips()
	_layout()


func play(p: Dictionary) -> void:
	clear()
	plan = p
	done = false
	_rest = position
	card.setup(1, "S", false)
	_seq = create_tween()
	# the roll: a wobble that grows as the wait stretches
	_seq.tween_method(_wobble, 0.0, 1.0, p.roll)
	_seq.tween_callback(_reveal)
	_seq.tween_interval(p.hold)
	_seq.tween_callback(_complete)


func _wobble(prog: float) -> void:
	card.rotation = deg_to_rad(sin(prog * 70.0) * (2.0 + prog * 5.0))


func _final_state() -> void:
	card.rotation = 0.0
	card.setup_card(plan.starter, true)
	word.text = plan.word
	sub.text = plan.sub
	sub.add_theme_color_override("font_color", GOLD if plan.sub_gold else Color(INK, 0.6))


func _reveal() -> void:
	_final_state()
	card.pop(0.18, 0.25)
	_shake(plan.shake)
	_burst(plan.pips)


func _complete() -> void:
	if done:
		return
	done = true
	_kill_pips()
	position = _rest
	finished.emit()


## Jump to the revealed state. Safe at any time, any number of times.
func skip() -> void:
	if done or plan == null:
		return
	if _seq and _seq.is_valid():
		_seq.kill()
	_final_state()
	_complete()


func _shake(strength: float) -> void:
	var tw := create_tween()
	for i in 6:
		var s := strength * (1.0 - i / 6.0)
		tw.tween_property(self, "position", _rest + Vector2(randf_range(-s, s), randf_range(-s, s)), 0.04)
	tw.tween_property(self, "position", _rest, 0.04)


## Pip burst: presentation only, so Godot's randf, never the engine's rng.
func _burst(n: int) -> void:
	var cols: Array = PIP_COLORS.get(plan.tier, PIP_COLORS["_"])
	var c0 := card.position + card.size / 2.0
	for i in n:
		var pip := ColorRect.new()
		pip.size = Vector2(6, 6)
		pip.color = cols[i % cols.size()]
		pip.position = c0
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.set_meta("pip", true)
		add_child(pip)
		var ang := randf() * TAU
		var dist := 60.0 + randf() * 140.0
		var tw := pip.create_tween()
		tw.set_parallel(true)
		tw.tween_property(pip, "position", c0 + Vector2(cos(ang), sin(ang)) * dist, 0.5)
		tw.tween_property(pip, "modulate:a", 0.0, 0.5)
		tw.chain().tween_callback(pip.queue_free)


func _kill_pips() -> void:
	for c in get_children():
		if c.has_meta("pip"):
			remove_child(c)
			c.queue_free()


func pip_count() -> int:
	return get_children().filter(func(c): return c.has_meta("pip")).size()
