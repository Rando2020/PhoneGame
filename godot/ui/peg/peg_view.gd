class_name PegView
extends Control
## The Play on screen (web renderPegging + pegLay). You tap a card to lay it;
## after a short beat the Spoiler answers. At the end the payout shows and
## CONTINUE hands the gain back. Node-owned tweens only, no await.
##
## Layout, top to bottom: header and both scores; the running total toward 31;
## the pile; the call for the last lay. Bottom, in the thumb zone: your hand
## and its hint, or the payout and CONTINUE.

signal finished(gain: int)

const BG := Color(0.102, 0.094, 0.149)
const PANEL := Color(0.14, 0.13, 0.20)
const INK := Color(0.96, 0.93, 0.88)
const DIM := Color(0.96, 0.93, 0.88, 0.6)
const GOLD := Color(0.91, 0.71, 0.30)
const GREEN := Color(0.43, 0.79, 0.54)
const RED := Color(0.91, 0.42, 0.42)
const BLUE := Color(0.45, 0.62, 0.95)
const MARGIN := 24.0
const MAX_COLUMN := 920.0
const BEAT := 0.62             ## web: Speed.ms(620) before the Spoiler answers

var s: PegSession
var waiting := false           ## the Spoiler's beat: your cards don't respond
var hand_views: Array[CardView] = []
var pile_views: Array[CardView] = []
var continue_button: Button
var total_label: Label
var call_label: Label
var hint_label: Label
var head_label: Label
var _beat: Tween
var _anim := ""                ## who laid the newest pile card: "you" / "foe"
var _page: Control


func open(session: PegSession) -> void:
	s = session
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP      # the table underneath gets nothing
	render()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and s != null:
		render()


func _ins() -> Dictionary:
	return SafeArea.insets(self)


func _col() -> Vector2:
	var w := minf(size.x - MARGIN * 2.0, MAX_COLUMN)
	return Vector2((size.x - w) / 2.0, w)


func _lab(text: String, fs: int, col: Color, at: Vector2, w: float) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = at
	l.size = Vector2(w, 0)
	_page.add_child(l)
	l.size = Vector2(w, l.get_combined_minimum_size().y)
	return l


func _card(c: Dictionary, sc: float, top_left: Vector2) -> CardView:
	var v := CardView.new()
	v.draggable = false
	_page.add_child(v)
	v.setup_card(c, true)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE   # after add_child (CardView._ready sets STOP)
	# CardView scales about its centre: offset so the scaled card's corner lands here
	var full := Vector2(CardArt.BASE_W, CardArt.BASE_H) * CardView.PIXEL_SCALE
	v.scale = Vector2(sc, sc)
	v.position = top_left - full * (1.0 - sc) / 2.0
	return v


## CardView.pop() settles at scale 1, which would blow a small card up to full
## size. This one returns to the card's own scale.
func _pop(v: CardView, sc: float) -> void:
	v.pivot_offset = v.size * 0.5
	var tw := v.create_tween()
	tw.tween_property(v, "scale", Vector2.ONE * sc * 1.18, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(v, "scale", Vector2.ONE * sc, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func card_size(sc: float) -> Vector2:
	return Vector2(CardArt.BASE_W, CardArt.BASE_H) * CardView.PIXEL_SCALE * sc


## Rebuild the page from the session. Cheap: a dozen nodes.
func render() -> void:
	if _page != null:
		remove_child(_page)
		_page.queue_free()
	_page = Control.new()
	_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_page)
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.add_child(bg)
	hand_views.clear()
	pile_views.clear()
	continue_button = null
	hint_label = null
	var p := s.play
	var ins := _ins()
	var c := _col()
	var y: float = ins.top + MARGIN
	head_label = _lab("THE PLAY", 20, GOLD, Vector2(c.x, y), c.y)
	y += head_label.size.y + 8.0
	# --- the two sides across the count
	var third := c.y / 3.0
	var boss = s.rd.run.boss()
	var you := _lab("YOU\n%d" % p.score, 26, GOLD, Vector2(c.x, y), third)
	_lab("%s\n%d" % [(boss.name if boss != null else "THE SPOILER").to_upper(), p.opp_score], 26, RED,
		Vector2(c.x + third * 2.0, y), third)
	total_label = _lab(str(p.total), 64, GOLD if p.total == PegPlay.TARGET else (RED if p.total >= 26 else INK),
		Vector2(c.x + third, y - 8.0), third)
	var of_ := _lab("of %d" % PegPlay.TARGET, 16, DIM, Vector2(c.x + third, total_label.position.y + total_label.size.y - 10.0), third)
	y = maxf(you.position.y + you.size.y, of_.position.y + of_.size.y) + 10.0
	# progress toward 31
	var bar_w := minf(300.0, c.y)
	var bar := ColorRect.new()
	bar.color = Color(0.098, 0.086, 0.153)
	bar.position = Vector2((size.x - bar_w) / 2.0, y)
	bar.size = Vector2(bar_w, 14)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.add_child(bar)
	var fill := ColorRect.new()
	fill.color = GOLD
	fill.position = bar.position
	fill.size = Vector2(bar_w * minf(1.0, float(p.total) / PegPlay.TARGET), 14)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.add_child(fill)
	_lab("%d in their hand" % p.theirs.size(), 16, DIM, Vector2(c.x + third * 2.0, y - 4.0), third)
	y += 30.0
	# --- the pile, newest card arriving
	var pile_sc := 0.68
	var ps := card_size(pile_sc)
	if p.pile.is_empty():
		_lab("the pile is clear", 18, DIM, Vector2(c.x, y + ps.y / 2.0 - 12.0), c.y)
	else:
		var n := p.pile.size()
		var step := minf(ps.x + 8.0, (c.y - ps.x) / maxf(1.0, n - 1))
		var x0 := (size.x - (step * (n - 1) + ps.x)) / 2.0
		for i in n:
			var v := _card(p.pile[i], pile_sc, Vector2(x0 + step * i, y))
			pile_views.append(v)
			if i == n - 1 and _anim != "":
				_pop(v, pile_sc)
	y += ps.y + 12.0
	# --- what the last lay earned
	var last = p.last_lay
	if last != null and not last.events.is_empty():
		var parts := []
		for e in last.events:
			parts.append("%s +%d" % [e.label, e.points])
		call_label = _lab("   ".join(parts), 22, GREEN if last.who == "you" else RED, Vector2(c.x, y), c.y)
	elif last != null:
		call_label = _lab("—", 22, DIM, Vector2(c.x, y), c.y)   # the web's placeholder
	else:
		call_label = _lab("", 22, DIM, Vector2(c.x, y), c.y)
	y += 40.0
	_anim = ""
	# --- bottom: the hand, or the payout
	var bottom: float = size.y - ins.bottom - MARGIN
	if p.over:
		_render_result(y, bottom)
	else:
		_render_hand(bottom)


func _render_hand(bottom: float) -> void:
	var p := s.play
	var c := _col()
	var can_any := p.can_play(p.mine)
	hint_label = _lab("Lay a card. You cannot pass 31." if can_any else "Nothing fits — the Spoiler must play on.",
		18, DIM if can_any else GOLD, Vector2(c.x, 0), c.y)
	hint_label.position.y = bottom - hint_label.size.y
	var sc := 0.82
	var cs := card_size(sc)
	var n := p.mine.size()
	var gap := 10.0
	var w := n * cs.x + (n - 1) * gap
	if w > c.y:
		gap = (c.y - n * cs.x) / maxf(1.0, n - 1)
		w = c.y
	var x0 := (size.x - w) / 2.0
	var top := hint_label.position.y - 12.0 - cs.y
	for i in n:
		var v := _card(p.mine[i], sc, Vector2(x0 + i * (cs.x + gap), top))
		if p.playable(i) and not waiting:
			v.mouse_filter = Control.MOUSE_FILTER_STOP
			v.pressed.connect(_on_card.bind(i))
		else:
			v.set_state(CardView.State.DIM)
		hand_views.append(v)


func _render_result(y: float, bottom: float) -> void:
	var p := s.play
	var c := _col()
	var won := p.score >= p.opp_score
	var head := _lab("You pegged %d" % p.score if won else "The Spoiler pegged %d" % p.opp_score,
		28, GREEN if won else RED, Vector2(c.x, y), c.y)
	y += head.size.y + 8.0
	var rows := [["Your pegs", "+%d" % p.score, GREEN]]
	if p.opp_score > 0:
		rows.append(["Spoiler's pegs", "−%d" % int(floor(p.opp_score / 2.0)), RED])
	rows.append(["Net", str(s.net()), GOLD])
	if s.mult > 1.01:
		rows.append(["× your multiplier", "×%.2f" % s.mult, BLUE])
	rows.append(["TO YOUR SCORE", "+%d" % s.gain(), GOLD])
	var pw := minf(c.y, 420.0)
	var px := (size.x - pw) / 2.0
	var panel := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL
	sb.border_color = Color(INK, 0.12)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(px, y)
	panel.size = Vector2(pw, rows.size() * 34.0 + 20.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.add_child(panel)
	var ry := y + 10.0
	for r in rows:
		var l := _lab(r[0], 20, INK, Vector2(px + 16.0, ry), pw - 32.0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var v := _lab(r[1], 20, r[2], Vector2(px + 16.0, ry), pw - 32.0)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		ry += 34.0
	continue_button = Button.new()
	continue_button.text = "CONTINUE"
	continue_button.add_theme_font_size_override("font_size", 30)
	_page.add_child(continue_button)
	var bw := maxf(300.0, continue_button.get_combined_minimum_size().x + 32.0)
	continue_button.size = Vector2(bw, 80)
	continue_button.position = Vector2((size.x - bw) / 2.0, bottom - 80.0)
	continue_button.pressed.connect(_on_continue)


## pegLay: your card goes down, then the Spoiler answers after a beat.
func _on_card(_v: CardView, i: int) -> void:
	if waiting or s.play.over or i >= s.play.mine.size() or not s.play.playable(i):
		return
	s.lay(i)
	_anim = "you"
	waiting = true
	render()
	if _beat and _beat.is_valid():
		_beat.kill()
	_beat = create_tween()
	_beat.tween_interval(BEAT)
	_beat.tween_callback(_answer)


func _answer() -> void:
	if not waiting:
		return
	waiting = false
	s.answer()
	_anim = "foe"
	render()


## A tap on the table during the beat brings the answer now (fluidity).
func _gui_input(event: InputEvent) -> void:
	if waiting and event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if _beat and _beat.is_valid():
			_beat.kill()
		_answer()
		accept_event()


func _on_continue() -> void:
	if continue_button == null or s.applied:
		return
	finished.emit(s.apply())
