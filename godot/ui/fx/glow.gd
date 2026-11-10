class_name Glow
extends RefCounted
## A label lights up: a soft gold outline around the text (reads as a glow on
## dark felt). Marked with meta "glow" so tests can find it.

const GOLD := Color(1.0, 0.82, 0.33, 0.55)


static func apply(l: Label, col := GOLD, size := 12) -> void:
	l.add_theme_color_override("font_outline_color", col)
	l.add_theme_constant_override("outline_size", size)
	l.set_meta("glow", true)


static func lit(l: Label) -> bool:
	return l != null and l.has_meta("glow")
