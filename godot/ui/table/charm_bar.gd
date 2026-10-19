class_name CharmBar
extends Control
## The charms row: the Meldling's own knack first, owned charms in resolve order,
## then empty slots up to run.slots(). Port of web cribCharmRow/charmChip.
## The cascade calls light(names) as each charm fires; lit chips keep an outline
## until clear_lit(), so the player can see what contributed after the count.

const H := 48.0
const GAP := 6.0
const BG := Color(0.098, 0.086, 0.153)
const INK := Color(0.96, 0.93, 0.88)
const DECK_TINT := Color(0.91, 0.71, 0.30)

var chips: Array = []          ## [{name, panel, label, tint}]
var lit: Dictionary = {}       ## name -> true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _style(tint: Color, on: bool, empty := false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG.lerp(tint, 0.30) if on else BG
	sb.border_color = tint if not empty else Color(INK, 0.15)
	sb.set_border_width_all(3 if on else 2)
	sb.set_corner_radius_all(8)
	return sb


func build(run) -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	chips.clear()
	lit.clear()
	var list: Array = run.active_charms()
	var empties: int = maxi(0, run.slots() - run.charms.size())
	for ch in list:
		var tint: Color = DECK_TINT if ch.tier == 0 else Color(CribData.RARITY.get(ch.rarity, CribData.RARITY.common).tint)
		_add_chip(ch.name, tint, false)
	for i in empties:
		_add_chip("", Color(INK, 0.15), true)
	_layout()


func _add_chip(name: String, tint: Color, empty: bool) -> void:
	var p := Panel.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", _style(tint, false, empty))
	var l := Label.new()
	l.text = name
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	TypeScale.set_size(l, 17)
	l.add_theme_color_override("font_color", INK)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	add_child(p)
	chips.append({"name": name, "panel": p, "label": l, "tint": tint, "empty": empty})


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


## Chips per row: all in one row when every name fits in two lines without
## breaking a word; else rows of 3 (~215 px a name), so names read whole at
## 11 pt and up instead of trimming to "Qua...".
func per_row(n: int) -> int:
	if n <= 3:
		return maxi(1, n)
	var w := (size.x - GAP * (n - 1)) / n - 8.0
	for c in chips:
		var l: Label = c.label
		if l.text == "":
			continue
		var font := l.get_theme_font("font")
		var fs := l.get_theme_font_size("font_size")
		for word in l.text.split(" "):
			if font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w:
				return 3
		if font.get_multiline_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, w, fs).y > font.get_height(fs) * 2.0 + 2.0:
			return 3
	return n


var row_h := H                 ## grows when a name wraps to two lines


func height() -> float:
	var n := chips.size()
	var rows := ceili(float(maxi(1, n)) / per_row(n))
	return rows * row_h + (rows - 1) * GAP


func _layout() -> void:
	var n := chips.size()
	if n == 0:
		return
	var per := per_row(n)
	var w := (size.x - GAP * (per - 1)) / per
	row_h = H
	for c in chips:
		var l: Label = c.label
		l.size = Vector2(w - 8.0, 0)
		row_h = maxf(row_h, l.get_minimum_size().y + 6.0)
	for i in n:
		var p: Panel = chips[i].panel
		p.position = Vector2((i % per) * (w + GAP), (i / per) * (row_h + GAP))
		p.size = Vector2(w, row_h)
		var l: Label = chips[i].label
		l.position = Vector2(4, 0)
		l.size = Vector2(w - 8.0, row_h)
		p.pivot_offset = p.size / 2.0


## Light these charms (by name): a pulse now, an outline that stays.
func light(names: Array) -> void:
	for c in chips:
		if c.empty or not names.has(c.name):
			continue
		lit[c.name] = true
		var p: Panel = c.panel
		p.add_theme_stylebox_override("panel", _style(c.tint, true))
		var tw := p.create_tween()
		tw.tween_property(p, "scale", Vector2.ONE * 1.12, 0.07)
		tw.tween_property(p, "scale", Vector2.ONE, 0.16)


func clear_lit() -> void:
	lit.clear()
	for c in chips:
		c.panel.scale = Vector2.ONE
		c.panel.add_theme_stylebox_override("panel", _style(c.tint, false, c.empty))
