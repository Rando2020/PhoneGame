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
## A card was laid or the Spoiler answered: the save should follow.
signal changed

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
var meld_sprite: MeldSprite     ## your Meldling, across the table from the Spoiler
var spoiler_sprite: SpoilerSprite  ## the Spoiler (on a plain round, the table's jester)
## who sits across on a round with no Spoiler
const TABLE_FOE := {"art": "jokester", "sev": 1}
var juice: Juice


func open(session: PegSession) -> void:
	s = session
	Sound.music("play")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP      # the table underneath gets nothing
	render()


var _drawn_for := Vector3(-1, -1, -1)   ## TypeScale.layout_key at the last draw


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and s != null and TypeScale.layout_key(self) != _drawn_for:
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
	TypeScale.set_size(l, fs)
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
	_drawn_for = TypeScale.layout_key(self)
	if _page != null:
		remove_child(_page)
		_page.queue_free()
	_page = Control.new()
	_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_page)
	var felt := Surface.make("spoiler" if s.rd.run.boss() != null else "round")
	_page.add_child(felt)
	Press.watch(self)
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
	# the two scores flank the count; the characters face off lower down
	if spoiler_sprite == null:
		spoiler_sprite = SpoilerSprite.new(boss if boss != null else TABLE_FOE)
		add_child(spoiler_sprite)
	# the Spoiler is a character, not a name (spoiler_test): "THEM", as on its peg lane
	var you := _lab("YOU\n%d" % p.score, 26, GOLD, Vector2(c.x, y + 10.0), third)
	_lab("THEM\n%d" % p.opp_score, 26, RED, Vector2(c.x + third * 2.0, y + 10.0), third)
	total_label = _lab(str(p.total), 64, GOLD if p.total == PegPlay.TARGET else (RED if p.total >= 26 else INK),
		Vector2(c.x + third, y - 8.0), third)
	if p.total == PegPlay.TARGET:
		Glow.apply(total_label)        # 31 lights up
	var of_ := _lab("of %d" % PegPlay.TARGET, 16, DIM, Vector2(c.x + third, total_label.position.y + total_label.size.y + 2.0), third)
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
		call_label = _lab("-", 22, DIM, Vector2(c.x, y), c.y)   # the web's placeholder
	else:
		call_label = _lab("", 22, DIM, Vector2(c.x, y), c.y)
	y += 40.0
	_anim = ""
	# --- bottom: the hand, or the payout
	var bottom: float = size.y - ins.bottom - MARGIN
	# the table's edge, just above your hand
	if not p.over:
		Surface.rail(_page, bottom - card_size(0.82).y - 64.0, size.x, 26.0)
	if meld_sprite == null:
		meld_sprite = MeldSprite.new(s.rd.run.meldling)
		add_child(meld_sprite)
	if juice == null:
		juice = Juice.new()
		juice.target = self
		add_child(juice)
	move_child(meld_sprite, get_child_count() - 1)
	move_child(spoiler_sprite, get_child_count() - 1)
	move_child(juice, get_child_count() - 1)
	if p.over:
		_render_result(y, bottom)
	else:
		_render_hand(bottom)
		var hand_top: float = hand_views[0].position.y - 12.0 if not hand_views.is_empty() else bottom
		_stage(y, hand_top, "idle", "idle")


## The middle of the table, between the call and your hand (or the payout):
## your Meldling and the Spoiler facing off, both sides' pegs as a track, and
## what The Play adds to your round so far. Sized to the room, then centred.
## Reads the play only; the characters' poses are presentation.
var lanes: Array = []          ## [you, them] track rows (tests)
var round_line: Label


func _stage(top: float, bottom: float, my_pose: String, foe_pose: String) -> void:
	var p := s.play
	var c := _col()
	var lane_h := 30.0
	var line_h := 34.0
	var room := bottom - top
	var px := clampf(room - lane_h * 2.0 - line_h - 40.0, 0.0, minf(320.0, (size.x - 40.0 - MARGIN * 2.0) / 2.0))
	var show_art := px >= 90.0
	var block := (px + 16.0 if show_art else 0.0) + lane_h * 2.0 + 8.0 + line_h
	var y := top + maxf(0.0, (room - block) / 2.0)
	meld_sprite.visible = show_art
	spoiler_sprite.visible = show_art
	if show_art:
		var gap := 40.0
		var x0 := (size.x - px * 2.0 - gap) / 2.0
		meld_sprite.size = Vector2(px, px)
		meld_sprite.position = Vector2(x0, y)
		spoiler_sprite.size = Vector2(px, px)
		spoiler_sprite.position = Vector2(x0 + px + gap, y)
		if my_pose != "idle":
			meld_sprite.react(my_pose, true)
		if foe_pose != "idle":
			spoiler_sprite.react(foe_pose)
		y += px + 16.0
	lanes.clear()
	lanes.append(_lane(y, "YOU", p.score, GOLD, c))
	lanes.append(_lane(y + lane_h + 8.0, "THEM", p.opp_score, RED, c))
	y += lane_h * 2.0 + 8.0 + 6.0
	var so_far := s.rd.score + s.gain()
	round_line = _lab("Round  %d / %d   ·   The Play  +%d so far" % [so_far, s.rd.target, s.gain()], 20,
		GREEN if so_far >= s.rd.target else INK, Vector2(c.x, y), c.y)


## One side's pegs: a row of holes, the pegged ones filled, the count at the end.
func _lane(y: float, who: String, pegs: int, col: Color, c: Vector2) -> Dictionary:
	var name_w := 96.0
	var num_w := 56.0
	var holes := clampi(maxi(16, maxi(s.play.score, s.play.opp_score) + 2), 16, 31)
	var w := c.y - name_w - num_w
	var d := minf(20.0, w / holes - 4.0)
	var step := w / holes
	var n := _lab(who, 18, col, Vector2(c.x, y), name_w)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var filled := 0
	for i in holes:
		var on := i < pegs
		var h := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(int(d / 2.0))
		sb.bg_color = col if on else Color(0.06, 0.05, 0.10, 0.85)
		sb.border_color = Color(col, 0.5)
		sb.set_border_width_all(0 if on else 1)
		h.add_theme_stylebox_override("panel", sb)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.position = Vector2(c.x + name_w + i * step + (step - d) / 2.0, y + (30.0 - d) / 2.0)
		h.size = Vector2(d, d)
		_page.add_child(h)
		if on:
			filled += 1
	var k := _lab(str(pegs), 20, col, Vector2(c.x + c.y - num_w, y), num_w)
	k.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return {"holes": holes, "filled": filled, "pegs": pegs}


func _render_hand(bottom: float) -> void:
	var p := s.play
	var c := _col()
	var can_any := p.can_play(p.mine)
	hint_label = _lab("Lay a card. You cannot pass 31." if can_any else "Nothing fits. The Spoiler must play on.",
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
			v.draggable = true
			v.set_base_position(v.position, false)
			v.pressed.connect(_on_card.bind(i))
			v.drag_ended.connect(_on_card_flicked.bind(i))
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
	TypeScale.set_size(continue_button, 30)
	_page.add_child(continue_button)
	var bw := maxf(300.0, continue_button.get_combined_minimum_size().x + 32.0)
	continue_button.size = Vector2(bw, 80)
	continue_button.position = Vector2((size.x - bw) / 2.0, bottom - 80.0)
	continue_button.pressed.connect(_on_continue)
	_stage(y + panel.size.y + 12.0, continue_button.position.y - 12.0,
		"victory" if won else "deflated", "defeated" if won else "gloat")


## pegLay: your card goes down, then the Spoiler answers after a beat.
func _on_card(_v: CardView, i: int) -> void:
	if waiting or s.play.over or i >= s.play.mine.size() or not s.play.playable(i):
		return
	var gained := s.lay(i)
	if gained > 0:
		Sound.tick("pair", mini(6, gained))
	else:
		Sound.play("toCrib")
	_anim = "you"
	var ll = s.play.last_lay
	if meld_sprite != null and ll != null and ll.who == "you" and not ll.events.is_empty():
		meld_sprite.react("cheer")
		if spoiler_sprite != null:
			spoiler_sprite.react("stung")      # it felt that
	juice_lay()
	waiting = true
	render()
	changed.emit()
	if _beat and _beat.is_valid():
		_beat.kill()
	_beat = create_tween()
	_beat.tween_interval(BEAT)
	_beat.tween_callback(_answer)


## A drag let go: pushed up toward the pile (where it would coast to, as in the
## keep hand), it's laid exactly as a tap lays it; anything less springs home at
## the finger's speed. Presentation only: the lay is _on_card's.
const FLICK_LAY := -80.0
var flicks: Array = []          ## "lay"/"none" (tests)


func _on_card_flicked(v: CardView, travel: Vector2, velocity: Vector2, i: int) -> void:
	if travel.y + velocity.y * HandView.COAST <= FLICK_LAY and not waiting and not s.play.over:
		flicks.append("lay")
		_on_card(v, i)
	else:
		flicks.append("none")
		v.release_to(v._base_pos, velocity)


## 31 in The Play: a burst from the total, a shake, a buzz on the same frame.
func juice_lay() -> void:
	var ll = s.play.last_lay
	if juice == null or ll == null or not JS.truthy(ll.get("hit31")):
		return
	var at := total_label.position + total_label.size / 2.0 if total_label != null else size / 2.0
	juice.burst(at, 40, ["gold", "white", "green"])
	juice.shake(10.0, 300.0)
	Sound.play("slam_1")
	Haptics.pulse(40)


func _answer() -> void:
	if not waiting:
		return
	waiting = false
	s.answer()
	_anim = "foe"
	var fl = s.play.last_lay
	if spoiler_sprite != null and fl != null and fl.who == "them" and not fl.events.is_empty():
		spoiler_sprite.on_event("peg")
		if meld_sprite != null:
			meld_sprite.react("nervous", true)
	juice_lay()
	render()
	changed.emit()


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
	var g := s.apply()
	Sound.play("win" if g > 0 else "bad")
	finished.emit(g)
