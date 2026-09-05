class_name MapScreen
extends Screen

## The "movement" layer: a branching run map. You occupy a node, and can move
## only to nodes the current one links forward to.

const NODE_SIZE := 58
const ROW_H := 96

var _canvas: Control
var _token: Control
var _buttons: Dictionary = {}      ## Vector2i -> Button
var _moving: bool = false
var _started: bool = false


func build() -> void:
	var body := UIKit.screen_body(14)
	add_child(body)
	var col := UIKit.vbox(8)
	body.add_child(col)

	# header
	var head := UIKit.panel(UIKit.PANEL, 10, 8)
	col.add_child(head)
	var hb := UIKit.hbox(8)
	head.add_child(hb)
	var d := CreatureDB.get_data(run().meldling)
	hb.add_child(UIKit.label(d.get("name", "?"), 17, UIKit.INK))
	hb.add_child(UIKit.label("%d / %d HP" % [run().hp, run().max_hp], 17,
			UIKit.GREEN if run().hp > run().max_hp * 0.4 else UIKit.RED,
			HORIZONTAL_ALIGNMENT_CENTER))
	hb.add_child(UIKit.label("%d Essence" % run().essence_earned, 17, UIKit.GOLD,
			HORIZONTAL_ALIGNMENT_RIGHT))

	if not run().relics.is_empty():
		var names: Array = []
		for r in run().relics:
			names.append(r.get("name", "?"))
		col.add_child(UIKit.wrap_label("Relics: " + ", ".join(names), 260, 13, UIKit.BLUE))

	# map canvas
	_canvas = Control.new()
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.custom_minimum_size.y = ROW_H * run().map.size()
	_canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	_canvas.clip_contents = false
	col.add_child(_canvas)
	_canvas.draw.connect(_draw_links)
	_canvas.resized.connect(_place_nodes)

	_build_nodes()

	var back := UIKit.button("Abandon Run", 15, 42)
	back.pressed.connect(func():
		audio().sfx("card_invalid")
		game.end_run())
	col.add_child(back)


func on_shown() -> void:
	audio().music("bgm_menu")
	_place_nodes()
	_refresh_reachable()


# ------------------------------------------------------------------ layout
func _node_pos(r: int, c: int) -> Vector2:
	var rows: int = run().map.size()
	var cols: int = run().map[r].size()
	var w: float = _canvas.size.x
	var h: float = _canvas.size.y
	var x: float = w * (float(c) + 1.0) / (float(cols) + 1.0)
	var y: float = h - (float(r) + 0.5) * (h / float(rows))
	return Vector2(x, y)


func _build_nodes() -> void:
	for r in run().map.size():
		for c in run().map[r].size():
			var node: Dictionary = run().map[r][c]
			var b := Button.new()
			b.custom_minimum_size = Vector2(NODE_SIZE, NODE_SIZE)
			b.size = b.custom_minimum_size
			b.focus_mode = Control.FOCUS_NONE
			b.text = _glyph(node.get("type", 0))
			b.add_theme_font_size_override("font_size", 22)
			b.tooltip_text = RunState.TYPE_NAMES.get(node.get("type", 0), "")
			b.pressed.connect(_on_node.bind(r, c))
			_style_node(b, node.get("type", 0))
			_canvas.add_child(b)
			_buttons[Vector2i(r, c)] = b

	_token = Control.new()
	_token.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_token.z_index = 5
	_canvas.add_child(_token)
	var cv := CreatureView.new()
	cv.pixel_scale = 2
	_token.add_child(cv)
	cv.setup(run().meldling)
	cv.position = Vector2(-32, -78)


func _place_nodes() -> void:
	if _canvas == null or run().map.is_empty():
		return
	for key in _buttons:
		var b: Button = _buttons[key]
		b.position = _node_pos(key.x, key.y) - Vector2(NODE_SIZE, NODE_SIZE) * 0.5
	if _token and not _moving:
		_token.position = _node_pos(run().floor_index, run().node_index)
	_canvas.queue_redraw()


func _draw_links() -> void:
	if run().map.is_empty():
		return
	for r in run().map.size() - 1:
		for c in run().map[r].size():
			var from := _node_pos(r, c)
			for target in run().reachable_from(r, c):
				var to := _node_pos(r + 1, target)
				var lit: bool = (r == run().floor_index and c == run().node_index and _started)
				_canvas.draw_line(from, to,
					UIKit.GOLD if lit else Color(0.28, 0.26, 0.38), 3.0 if lit else 2.0, true)


func _glyph(t: int) -> String:
	match t:
		RunState.NodeType.BATTLE: return "⚔"
		RunState.NodeType.ELITE: return "☠"
		RunState.NodeType.REST: return "✚"
		RunState.NodeType.TREASURE: return "◆"
		RunState.NodeType.BOSS: return "♛"
	return "?"


func _style_node(b: Button, t: int) -> void:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(NODE_SIZE / 2)
	sb.bg_color = UIKit.PANEL
	sb.set_border_width_all(3)
	sb.border_color = {
		RunState.NodeType.BATTLE: Color(0.45, 0.43, 0.58),
		RunState.NodeType.ELITE: Color(0.82, 0.42, 0.62),
		RunState.NodeType.REST: UIKit.GREEN,
		RunState.NodeType.TREASURE: UIKit.GOLD,
		RunState.NodeType.BOSS: UIKit.RED,
	}.get(t, Color(0.4, 0.4, 0.5))
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_stylebox_override("disabled", sb)
	b.add_theme_color_override("font_color", UIKit.INK)
	b.add_theme_color_override("font_disabled_color", Color(0.35, 0.34, 0.42))


# ------------------------------------------------------------------ movement
func _refresh_reachable() -> void:
	var here := Vector2i(run().floor_index, run().node_index)
	var open: Array = []
	if not _started:
		for c in run().map[0].size():
			open.append(Vector2i(0, c))
	else:
		for t in run().reachable_from(here.x, here.y):
			open.append(Vector2i(here.x + 1, t))

	for key in _buttons:
		var b: Button = _buttons[key]
		var can: bool = key in open
		b.disabled = not can
		b.modulate = Color.WHITE if can else Color(0.62, 0.60, 0.70)
		if can:
			_pulse(b)
	_canvas.queue_redraw()


func _pulse(b: Button) -> void:
	b.pivot_offset = b.size * 0.5
	var tw := create_tween().set_loops()
	tw.tween_property(b, "scale", Vector2.ONE * 1.10, 0.55) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(b, "scale", Vector2.ONE, 0.55) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_node(r: int, c: int) -> void:
	if _moving:
		return
	_moving = true
	for key in _buttons:
		_buttons[key].disabled = true
	audio().sfx("card_place")

	var dest := _node_pos(r, c)
	var tw := create_tween()
	tw.tween_property(_token, "position", dest, 0.42) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tw.finished

	_started = true
	run().advance_to(r, c)
	audio().sfx("ui_click")
	await get_tree().create_timer(0.12).timeout
	game.enter_node()
