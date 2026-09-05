class_name UIKit
extends RefCounted

## Every Control in this game is built through here.
##
## WHY THIS EXISTS: a Label with autowrap enabled reports a minimum width of
## roughly one character. Put it in a container that sizes to minimum (an
## HBoxContainer where nothing has SIZE_EXPAND_FILL) and it collapses to ~10px,
## wrapping after every letter -- text renders vertically.
##
## So: `label()` always sets AUTOWRAP_OFF. `wrap_label()` is the only thing that
## enables wrapping, and it forces EXPAND_FILL plus a real minimum width so it
## can never collapse. Same idea for `icon()` and EXPAND_IGNORE_SIZE.

const INK := Color(0.93, 0.92, 0.96)
const DIM := Color(0.66, 0.64, 0.75)
const GOLD := Color(0.91, 0.71, 0.30)
const RED := Color(0.86, 0.35, 0.35)
const GREEN := Color(0.45, 0.78, 0.48)
const BLUE := Color(0.45, 0.68, 0.92)
const BG := Color(0.075, 0.07, 0.115)
const PANEL := Color(0.13, 0.12, 0.19)
const PANEL_HI := Color(0.20, 0.18, 0.28)


static func label(text: String, size_px: int = 18, color: Color = INK,
		align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_OFF        # <-- the fix
	l.horizontal_alignment = align
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	return l


## The only wrapping label. Needs a real width, so it demands one.
static func wrap_label(text: String, min_width: int = 240, size_px: int = 16,
		color: Color = DIM, align: int = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := label(text, size_px, color, align)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = maxi(min_width, 80)     # never collapses
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func title(text: String, size_px: int = 40, color: Color = GOLD) -> Label:
	var l := label(text, size_px, color, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.09))
	l.add_theme_constant_override("outline_size", 6)
	return l


static func icon(tex: Texture2D, scale: int = 2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tex:
		# EXPAND_IGNORE_SIZE zeroes the minimum size, so state it explicitly
		t.custom_minimum_size = tex.get_size() * scale
		t.size = t.custom_minimum_size
	return t


static func button(text: String, size_px: int = 20, height: int = 56) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, height)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", size_px)
	b.focus_mode = Control.FOCUS_NONE
	_style_button(b)
	return b


static func _style_button(b: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = PANEL_HI
	normal.set_corner_radius_all(8)
	normal.set_content_margin_all(10)
	normal.border_color = Color(0.34, 0.31, 0.45)
	normal.set_border_width_all(2)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.27, 0.24, 0.36)
	hover.border_color = GOLD

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.17, 0.15, 0.24)

	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.14, 0.13, 0.19)
	disabled.border_color = Color(0.22, 0.21, 0.28)

	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_disabled_color", Color(0.42, 0.40, 0.50))


static func panel(bg: Color = PANEL, radius: int = 12, pad: int = 12) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	sb.border_color = Color(0.24, 0.22, 0.33)
	sb.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return p


static func vbox(sep: int = 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return v


## Every child gets EXPAND_FILL by default -- this is what stops the collapse.
static func hbox(sep: int = 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return h


static func spacer(min_h: int = 0, expand: bool = true) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.custom_minimum_size.y = min_h
	if expand:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


## Simple coloured meter (HP, block, xp...). Never collapses: fixed min height.
static func bar(color: Color, height: int = 16) -> ProgressBar:
	var p := ProgressBar.new()
	p.custom_minimum_size = Vector2(60, height)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.show_percentage = false
	p.max_value = 100.0
	p.value = 100.0

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.07, 0.12)
	bg.set_corner_radius_all(6)
	var fg := StyleBoxFlat.new()
	fg.bg_color = color
	fg.set_corner_radius_all(6)
	p.add_theme_stylebox_override("background", bg)
	p.add_theme_stylebox_override("fill", fg)
	return p


static func background(color: Color = BG) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Root margin container for a screen -- keeps content off the notch/edges.
static func screen_body(margin: int = 18) -> MarginContainer:
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, margin)
	m.mouse_filter = Control.MOUSE_FILTER_PASS
	return m
