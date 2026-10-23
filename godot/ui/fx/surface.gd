class_name Surface
extends Control
## A table surface: tiled felt (tools/make_surfaces.py) under a vignette. Drop in
## where a flat ColorRect background was. kind: "round", "spoiler", "menu".
## A wood rail can sit on top: Surface.rail(parent, y, width).

var kind := "round"


static func make(kind_: String) -> Surface:
	var s := Surface.new()
	s.kind = kind_
	return s


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var felt := TextureRect.new()
	felt.texture = load("res://art/surfaces/felt_%s.png" % kind)
	felt.stretch_mode = TextureRect.STRETCH_TILE
	felt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	felt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	felt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(felt)
	var vig := TextureRect.new()
	vig.texture = load("res://art/surfaces/vignette.png")
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(vig)


## A horizontal wood rail across `parent` at y.
static func rail(parent: Control, y: float, w: float, h := 34.0) -> TextureRect:
	var r := TextureRect.new()
	r.texture = load("res://art/surfaces/wood_rail.png")
	r.stretch_mode = TextureRect.STRETCH_TILE
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.position = Vector2(0, y)
	r.size = Vector2(w, h)
	r.name = "rail"
	parent.add_child(r)
	return r
