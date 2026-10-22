class_name DeedToast
extends Control
## The web's announceDeeds / pumpDeeds: a queue of "DEED UNLOCKED" cards, one at
## a time, each held 3.4 s then slid out over 0.5 s. Plays the web's deed sound
## with a short buzz, in the same call. Lives on RunFlow (not on a page), so a
## page change doesn't cut a toast short. Tweens are this node's own; no await.

const HOLD := 3.4
const OUT := 0.5

var queue: Array = []         ## deeds waiting (dictionaries from Meta.ACHIEVEMENTS)
var shown: Array = []         ## names shown, in order (tests)
var busy := false
var _card: Panel = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func announce(ids: Array) -> void:
	for id in ids:
		for a in Meta.ACHIEVEMENTS:
			if a.id == id:
				queue.append(a)
	pump()


## A first-time celebration (Firsts): same card, its own header and chord.
func celebrate(id: String) -> void:
	var a: Dictionary = Firsts.ALL[id].duplicate()
	a["head"] = "A FIRST"
	a["first"] = id
	celebrated.append(id)
	queue.append(a)
	pump()


var celebrated: Array = []    ## first ids queued, in order (tests)


## A charm bought for the first time ever (Collection): the same card, its icon.
func celebrate_charm(ch) -> void:
	celebrated.append("charm:" + ch.id)
	queue.append({"name": "%s joins your collection" % ch.name, "text": ch.text,
		"head": "A NEW CHARM", "first": "charm:" + ch.id, "icon": ch.id})
	pump()
signal burst_wanted(at: Vector2)


func pump() -> void:
	if busy or queue.is_empty():
		return
	busy = true
	var a: Dictionary = queue.pop_front()
	shown.append(String(a.name))
	var w := minf(size.x - 48.0, 620.0)
	_card = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.11, 0.18, 0.96)
	sb.border_color = Color(0.91, 0.71, 0.30)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	_card.add_theme_stylebox_override("panel", sb)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card)
	var icon := CharmIcon.make(String(a.get("icon", "")), 52.0) if a.has("icon") else null
	if icon != null:
		icon.position = Vector2(14, 14)
		_card.add_child(icon)
	else:
		var star := _lab("★", 40, Color(0.91, 0.71, 0.30), Vector2(18, 16), 50)
		_card.add_child(star)
	var k := _lab(String(a.get("head", "DEED UNLOCKED")), 16, Color(0.91, 0.71, 0.30), Vector2(78, 12), w - 96.0)
	_card.add_child(k)
	var n := _lab(String(a.name), 24, Color(0.96, 0.93, 0.88), Vector2(78, 34), w - 96.0)
	_card.add_child(n)
	var t := _lab(String(a.text), 17, Color(0.96, 0.93, 0.88, 0.6), Vector2(78, 40 + n.size.y), w - 96.0)
	_card.add_child(t)
	var h := t.position.y + t.size.y + 14.0
	_card.size = Vector2(w, h)
	var rest := Vector2((size.x - w) / 2.0, size.y * 0.70)
	_card.position = rest + (Vector2.ZERO if MeldSprite.reduce_motion else Vector2(0, 40))
	_card.modulate.a = 0.0
	if a.has("first"):
		Sound.play("chord_t-max")
		Haptics.pulse(30)
		burst_wanted.emit(rest + Vector2(w / 2.0, 0))
	else:
		Sound.play("deed")
		Haptics.pulse(20)
	var tw := create_tween()
	tw.tween_property(_card, "modulate:a", 1.0, 0.2)
	tw.parallel().tween_property(_card, "position", rest, 0.35).set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
	tw.tween_interval(HOLD)
	tw.tween_property(_card, "modulate:a", 0.0, OUT)
	tw.tween_callback(_next)


func _lab(text: String, fs: int, col: Color, at: Vector2, w: float) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	TypeScale.set_size(l, fs)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = at
	l.size = Vector2(w, 0)
	l.size = Vector2(w, l.get_combined_minimum_size().y)
	return l


func _next() -> void:
	if _card != null:
		_card.queue_free()
		_card = null
	busy = false
	pump()
