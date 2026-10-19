class_name GuideCoach
extends Control
## The guided first round (web tutorial.js: Guide, GUIDE_BEATS, guideShow,
## guideFinish). Coaching boxes over a real round, each shown once and only in
## order: a beat behind the last one shown is skipped, as the web's
## `i < Guide.beat` check does. Timing, as the web calls guideShow:
##   deal     when the round starts (guideStart)
##   kept     when the fourth card is chosen (renderCrib, +120 ms)
##   cut      after Keep (doCribCount, +200 ms)
##   counted, target, done   when the count lands (+700, +2600, +5200 ms)
## "Got it" closes a box; on the last beat it reads "PLAY ON", ends coaching
## and leaves for the run choices. "Skip coaching" ends coaching; the round
## carries on. Not ported: the highlight on the element each beat points at.

signal play_on        ## the last beat's button: coaching done, go choose a run
signal message(text: String)

const BEATS := [
	{"at": "deal", "title": "Six cards.",
		"body": "Keep four. Tap them. The two you leave behind are thrown to your Crib, which scores for you at the end of the round."},
	{"at": "kept", "title": "Now look at the two numbers.",
		"body": "LOCKED IN is what your four cards are worth on their own. EXPECTED AFTER CUT is what they're likely worth once a fifth card is turned. They often disagree, and that disagreement is the whole game."},
	{"at": "cut", "title": "The cut decides.",
		"body": "Only now is a fifth card turned, and it joins your four. A longer roll means a better card. You are betting on what's still in the deck."},
	{"at": "counted", "title": "Fifteen two, fifteen four.",
		"body": "Every pair of cards adding to fifteen scores 2. Pairs score 2. Runs score their length. Then your charms multiply the total."},
	{"at": "target", "title": "NEED tells you the truth.",
		"body": "The bar shows the target. NEED is how far you are, and the number beside it is what each remaining deal must average. When that gets implausible, it turns red."},
	{"at": "done", "title": "That's the loop.",
		"body": "Clear the target before your deals run out. Spend Glim between rounds on charms and cards. Every fifth round is a Spoiler that breaks a rule. Everything else you'll pick up as you go."},
]

const PANEL := Color(0.14, 0.13, 0.20)
const INK := Color(0.96, 0.93, 0.88)
const DIM := Color(0.96, 0.93, 0.88, 0.7)
const GOLD := Color(0.91, 0.71, 0.30)
const MARGIN := 24.0

var on := true
var beat := 0                 ## web Guide.beat: one past the last beat shown
var shown: Array = []         ## beats shown, in order (tests)
var box: Panel
var got_button: Button
var skip_button: Button
var keep: KeepScreen
var _timers: Array = []


## Web guideStart's coaching half: watch this round's screen.
func attach(k: KeepScreen) -> void:
	keep = k
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE      # the table stays playable underneath
	k.hand.selection_changed.connect(_on_selection)
	k.committed.connect(func(): _later("cut", 0.2))
	k.cascade_done.connect(func():
		_later("counted", 0.7)
		_later("target", 2.6)
		_later("done", 5.2))
	show_beat("deal")


func _on_selection(_cards: Array, verdict: Dictionary) -> void:
	if verdict.valid:
		_later("kept", 0.12)


## A node-owned delay (no await): the beat fires unless coaching is off by then.
func _later(at: String, secs: float) -> void:
	var tw := create_tween()
	tw.tween_interval(secs)
	tw.tween_callback(show_beat.bind(at))
	_timers.append(tw)


## Web guideShow: the beat matching this moment, if it isn't behind.
func show_beat(at: String) -> void:
	if not on:
		return
	var i := -1
	for k in BEATS.size():
		if BEATS[k].at == at:
			i = k
	if i < 0 or i < beat:
		return
	beat = i + 1
	shown.append(at)
	_render(i)


func _render(i: int) -> void:
	if box != null:
		remove_child(box)
		box.queue_free()
	var b: Dictionary = BEATS[i]
	var w := minf(size.x - MARGIN * 2.0, 640.0)
	box = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL
	sb.border_color = GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	box.add_theme_stylebox_override("panel", sb)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(box)
	var y := 12.0
	for part in [["%d of %d" % [i + 1, BEATS.size()], 15, GOLD], [b.title, 24, INK], [b.body, 18, DIM]]:
		var l := Label.new()
		l.text = part[0]
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.add_theme_font_size_override("font_size", TypeScale.px(part[1]))
		l.add_theme_color_override("font_color", part[2])
		l.position = Vector2(16, y)
		l.size = Vector2(w - 32.0, 0)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(l)
		l.size = Vector2(w - 32.0, l.get_combined_minimum_size().y)
		y += l.size.y + 6.0
	var last := i == BEATS.size() - 1
	got_button = _btn("PLAY ON" if last else "Got it", Vector2(16, y + 4.0))
	got_button.pressed.connect(_on_got.bind(last))
	skip_button = _btn("Skip coaching", Vector2(got_button.position.x + got_button.size.x + 12.0, y + 4.0))
	skip_button.pressed.connect(_on_skip)
	box.size = Vector2(w, y + 4.0 + 56.0 + 14.0)
	# just above the hand, in the open table: the status line, the hand and the
	# buttons stay visible
	var top: float = SafeArea.insets(self).top + 64.0
	if keep != null and keep.hand != null:
		top = maxf(top, keep.hand.get_global_rect().position.y - get_global_rect().position.y - box.size.y - 24.0)
	box.position = Vector2((size.x - w) / 2.0, top)


func _btn(text: String, at: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", TypeScale.px(20))
	box.add_child(b)
	b.size = Vector2(maxf(140.0, b.get_combined_minimum_size().x + 28.0), 56)
	b.position = at
	return b


func _close() -> void:
	if box != null:
		remove_child(box)
		box.queue_free()
		box = null


func _on_got(last: bool) -> void:
	_close()
	if last:
		finish()
		play_on.emit()


func _on_skip() -> void:
	_close()
	finish()
	message.emit("Coaching off.")


## Web guideFinish: coaching off for good.
func finish() -> void:
	on = false
	for tw in _timers:
		if tw.is_valid():
			tw.kill()
	_timers.clear()
	var m := Achv.load_store()
	m["guided"] = 1
	Achv.save_store(m)
