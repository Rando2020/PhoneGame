class_name CascadeView
extends Control
## Plays a CascadePlan: rows tick in, the big number climbs, the slam lands.
## Presentation only. skip() renders the plan's end state directly, so a skip
## always lands on plan.final (== res.total) no matter when it happens.

signal beat_landed(index: int)
signal finished

## Shared like the web's Speed: one setting for every count in a run.
const SPEEDS := [1, 2, 4]
static var speed_i := 0

const ROW_H := 34.0
const INK := Color(0.96, 0.93, 0.88)
const DIM := Color(0.96, 0.93, 0.88, 0.55)
const KIND_COLOR := {
	"fifteen": Color(0.91, 0.71, 0.30), "pair": Color(0.43, 0.79, 0.54), "run": Color(0.45, 0.62, 0.95),
	"flush": Color(0.79, 0.44, 0.84), "nobs": Color(0.95, 0.55, 0.40), "level": Color(0.91, 0.71, 0.30),
	"gild": Color(0.91, 0.71, 0.30), "cut": Color(0.45, 0.88, 0.82), "block": Color(0.93, 0.38, 0.38),
	"charm": Color(0.82, 0.78, 0.98), "zero": DIM,
}
const TIER_COLOR := {"": INK, "t-ok": Color(0.75, 0.85, 1.0), "t-good": Color(0.43, 0.79, 0.54),
	"t-big": Color(0.91, 0.71, 0.30), "t-max": Color(1.0, 0.42, 0.54)}

var plan = null
var shown := 0
var done := true
var light := Callable()     ## light.call(cards: Array or null) ; null = light everything
var charm_light := Callable()  ## charm_light.call(names: Array) as charms fire

var number: Label
var mult_label: Label
var list: VBoxContainer
var tier_label: Label
var lines_box: VBoxContainer
var speed_button: Button
var _tween: Tween
var _rows: Array = []        ## every row added, in order; only the newest that fit are shown


static func speed_k() -> int:
	return SPEEDS[speed_i]


static func ms(t: float) -> float:
	return maxf(24.0, t / speed_k()) / 1000.0


func _lab(fs: int, col: Color, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	number = _lab(88, INK)
	number.pivot_offset = Vector2(0, 0)
	add_child(number)
	mult_label = _lab(26, DIM)
	add_child(mult_label)
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 0)
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(list)
	tier_label = _lab(40, INK)
	add_child(tier_label)
	lines_box = VBoxContainer.new()
	lines_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lines_box)
	speed_button = Button.new()
	speed_button.add_theme_font_size_override("font_size", 22)
	speed_button.pressed.connect(func():
		speed_i = (speed_i + 1) % SPEEDS.size()
		_speed_text())
	add_child(speed_button)
	_speed_text()
	clear()
	_layout()


func _speed_text() -> void:
	speed_button.text = "\u25b8 %d\u00d7" % speed_k()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and number != null:
		_layout()
		_trim()


func _layout() -> void:
	var w := size.x
	number.position = Vector2(0, 0)
	number.size = Vector2(w, 110)
	number.pivot_offset = number.size / 2.0
	mult_label.position = Vector2(0, 110)
	mult_label.size = Vector2(w, 36)
	speed_button.size = Vector2(96, 44)
	speed_button.position = Vector2(w - 96, 0)
	# the footer (tier word + lines) grows to fit; the result list yields its oldest rows
	var lines_h := 0.0
	for l in lines_box.get_children():
		lines_h += l.get_combined_minimum_size().y + lines_box.get_theme_constant("separation")
	var foot := 58.0 + maxf(68.0, lines_h)
	list.position = Vector2(0, 152)
	# Intended height, kept separately: a VBoxContainer grows to fit its rows, so
	# list.size can't be trusted to say how many rows fit.
	list_h = maxf(0.0, size.y - 152 - foot)
	_trim()
	list.size = Vector2(w, list_h)
	tier_label.position = Vector2(0, size.y - foot)
	tier_label.size = Vector2(w, 56)
	lines_box.position = Vector2(0, size.y - foot + 58)
	lines_box.size = Vector2(w, foot - 58)


var list_h := 0.0

## Rows that fit in the list box (zero if the footer has taken all the room).
func max_rows() -> int:
	return maxi(0, int(list_h / ROW_H))


func clear() -> void:
	if _seq and _seq.is_valid():
		_seq.kill()
	if _tween and _tween.is_valid():
		_tween.kill()
	plan = null
	done = true
	speed_button.visible = false
	shown = 0
	number.text = ""
	number.scale = Vector2.ONE
	mult_label.text = ""
	tier_label.text = ""
	_rows.clear()
	for c in list.get_children() + lines_box.get_children():
		c.get_parent().remove_child(c)
		c.queue_free()


func _set_shown(v: float) -> void:
	shown = int(round(v))
	number.text = str(shown)


func _count_to(target: int, secs: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_shown, float(shown), float(target), secs) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _add_row(b: Dictionary) -> void:
	if b.kind in ["chain", "slam"]:
		return
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, ROW_H)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(10, 10)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.color = KIND_COLOR.get(b.kind, INK)
	row.add_child(dot)
	var name_l := _lab(24, INK, HORIZONTAL_ALIGNMENT_LEFT)
	name_l.text = "  " + b.label
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_l)
	var val := _lab(24, KIND_COLOR.get(b.kind, INK), HORIZONTAL_ALIGNMENT_RIGHT)
	val.text = b.value
	row.add_child(val)
	list.add_child(row)
	_rows.append(row)
	_trim()


## Oldest rows scroll off once the box is full, as on the web.
func _trim() -> void:
	while list.get_child_count() > max_rows():
		var c := list.get_child(0)
		list.remove_child(c)
		c.queue_free()


func _finish_display() -> void:
	shown = plan.final
	number.text = str(shown)
	var slam: Dictionary = plan.beats[plan.beats.size() - 1]
	mult_label.text = slam.mult_line
	tier_label.text = "TWENTY-NINE" if plan.perfect else plan.tier.word
	tier_label.add_theme_color_override("font_color", TIER_COLOR.get("t-max" if plan.perfect else plan.tier.cls, INK))
	for c in lines_box.get_children():
		lines_box.remove_child(c)
		c.queue_free()
	for ln in plan.lines:
		var l := _lab(24 if ln.cls != "clutch" else 30, TIER_COLOR.get("t-big") if ln.cls == "clutch"
			else (Color(0.43, 0.79, 0.54) if ln.cls == "green" else (TIER_COLOR.get("t-big") if ln.cls == "gold" else DIM)))
		l.text = ln.text
		lines_box.add_child(l)
	_layout()
	if light.is_valid():
		light.call(null)
	if charm_light.is_valid():
		charm_light.call(plan.get("fired", []))


## An extra footer line (round end, etc.). cls: green | gold | dim | clutch.
func add_line(text: String, cls := "dim") -> void:
	var col: Color = DIM
	if cls == "green":
		col = Color(0.43, 0.79, 0.54)
	elif cls in ["gold", "clutch"]:
		col = TIER_COLOR.get("t-big")
	var l := _lab(24, col)
	l.text = text
	lines_box.add_child(l)
	_layout()


## Play a plan. Listen for `finished` (or call skip()) to know it's over.
## The whole cascade is ONE Tween sequence owned by this node, not a coroutine:
## awaiting SceneTreeTimers leaked one object per view freed mid-count
## (measured), while node-bound tweens die with the node.
func play(p: Dictionary, light_cb := Callable(), charm_cb := Callable()) -> void:
	clear()
	plan = p
	light = light_cb
	charm_light = charm_cb
	speed_button.visible = true
	done = false
	_set_shown(0)
	_seq = create_tween()
	for i in plan.beats.size():
		var b: Dictionary = plan.beats[i]
		if b.kind == "slam":
			break
		_seq.tween_callback(_begin_beat.bind(b))
		_seq.tween_interval(ms(b.ms))
		_seq.tween_callback(func(): beat_landed.emit(i))
	_seq.tween_callback(_slam)
	_seq.tween_interval(0.62)
	_seq.tween_callback(func():
		beat_landed.emit(plan.beats.size() - 1)
		_finish_display())
	_seq.tween_interval(0.3)
	_seq.tween_callback(_complete)


var _seq: Tween


func _begin_beat(b: Dictionary) -> void:
	_add_row(b)
	if b.kind == "charm" and charm_light.is_valid():
		charm_light.call([b.label])
	if not b.cards.is_empty() and light.is_valid():
		light.call(b.cards)
	if b.mult_line != "":
		mult_label.text = b.mult_line
	_count_to(b.number, ms(b.ms * 0.6))
	if b.kind != "chain":
		_pulse(0.10)


func _slam() -> void:
	var slam: Dictionary = plan.beats[plan.beats.size() - 1]
	mult_label.text = slam.mult_line
	if light.is_valid():
		light.call(null)
	if charm_light.is_valid():
		charm_light.call(plan.fired)
	_count_to(plan.final, 0.62)
	_pulse(0.22)
	_shake(5.0 + minf(16.0, plan.ratio * 5.0))


func _complete() -> void:
	if done:
		return
	done = true
	finished.emit()


## Jump to the end state. Safe at any moment, any number of times.
func skip() -> void:
	if done or plan == null:
		return
	if _seq and _seq.is_valid():
		_seq.kill()
	if _tween and _tween.is_valid():
		_tween.kill()
	number.scale = Vector2.ONE
	position = _rest_pos if _shaking else position
	_shaking = false
	# rows: everything the full play would have shown, newest that fit
	for c in list.get_children():
		list.remove_child(c)
		c.queue_free()
	_rows.clear()
	for b in plan.beats:
		_add_row(b)
	_finish_display()
	done = true
	finished.emit()


func _pulse(s: float) -> void:
	var tw := create_tween()
	tw.tween_property(number, "scale", Vector2.ONE * (1.0 + s), 0.06)
	tw.tween_property(number, "scale", Vector2.ONE, 0.14)


var _rest_pos := Vector2.ZERO
var _shaking := false


func _shake(strength: float) -> void:
	if not _shaking:
		_rest_pos = position
	_shaking = true
	var tw := create_tween()
	for i in 7:
		var s := strength * (1.0 - i / 7.0)
		tw.tween_property(self, "position", _rest_pos + Vector2(randf_range(-s, s), randf_range(-s, s)), 0.04)
	tw.tween_property(self, "position", _rest_pos, 0.04)
	tw.tween_callback(func(): _shaking = false)
