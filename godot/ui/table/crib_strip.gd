class_name CribStrip
extends Control
## What you've fed the Crib this round, as small cards with a one-line note.
## Port of the web's cribBlock, compacted for a phone.

const MINI := 0.5               ## card scale inside the strip
const INK := Color(0.96, 0.93, 0.88)
const GOLD := Color(0.91, 0.71, 0.30)

var title: Label
var note: Label
var views: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	title = _lab(18, GOLD)
	add_child(title)
	note = _lab(15, Color(INK, 0.55))
	add_child(note)


func _lab(fs: int, col: Color) -> Label:
	var l := Label.new()
	TypeScale.set_size(l, fs)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func refresh(rd) -> void:
	for v in views:
		remove_child(v)
		v.queue_free()
	views.clear()
	title.text = "CRIB  %d/%d" % [rd.crib.size(), CribData.CRIB_SIZE]
	if JS.truthy(rd.mods.get("cribZero")):
		note.text = "scores nothing"
	elif rd.crib.size() >= CribData.CRIB_SIZE:
		note.text = "full: throws burn"
	else:
		note.text = "first %d throws" % CribData.CRIB_SIZE
	for c in rd.crib:
		var v := CardView.new()
		v.draggable = false
		add_child(v)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE  # after add_child: CardView._ready sets STOP
		v.setup_card(c, true)
		v.scale = Vector2.ONE * MINI
		views.append(v)
	_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and title != null:
		_layout()


func _layout() -> void:
	title.position = Vector2(0, 0)
	title.size = Vector2(size.x, 0)
	note.position = Vector2(0, title.get_minimum_size().y - 2.0)
	note.size = Vector2(size.x, 0)
	var cards_y := note.position.y + note.get_minimum_size().y + 2.0
	var cw := CardArt.BASE_W * CardView.PIXEL_SCALE * MINI
	var step := minf(cw + 4.0, (size.x - cw) / maxf(1.0, CribData.CRIB_SIZE - 1))
	for i in views.size():
		# CardView scales about its centre, so offset by the shrink to keep the
		# card's visible top-left where the layout says.
		var v: CardView = views[i]
		v.position = Vector2(i * step, cards_y) - v.size * (1.0 - MINI) / 2.0
