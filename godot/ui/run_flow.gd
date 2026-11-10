class_name RunFlow
extends Control
## A whole run: intro -> round (KeepScreen) -> round end -> shop (ShopScreen)
## -> next intro, until the run is lost or Act 5 is cleared. Port of the web's
## cribRoundIntro / cribRoundEnd / showCribShop NEXT ROUND / cribRunWon
## (web/cribrogue_ui.js). Every engine call happens in the web's order; the
## screens hold no rules of their own.
##
## Tests reach controls through `buttons` (name -> Button) on the intro, round
## end and run end screens, and `keep` / `shop` while those are showing.

signal screen_changed(name: String)

@export var meldling := "pip"
@export var seed := 20261001
@export var street_id := 1

const BG := Color(0.102, 0.094, 0.149)
const PANEL := Color(0.098, 0.086, 0.153)
const INK := Color(0.96, 0.93, 0.88)
const DIM := Color(0.96, 0.93, 0.88, 0.55)
const GOLD := Color(0.91, 0.71, 0.30)
const GREEN := Color(0.43, 0.79, 0.54)
const RED := Color(0.93, 0.38, 0.38)
const SEV := [Color(0.96, 0.93, 0.88), Color(0.91, 0.71, 0.30), Color(0.95, 0.55, 0.40), Color(0.93, 0.38, 0.38)]
const MARGIN := 24.0
const MAX_COLUMN := 920.0

var run: CribRun
var rd: CribRound
var screen := ""
var buttons := {}
var keep: KeepScreen
var shop: ShopScreen
var _page: Control
var _paid := false   ## round-end Glim already added (the web adds it once, on render)


func _ready() -> void:
	Warm.run(self)             # first-use costs now (launch screen), not on the first deal
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Menus.apply()             # saved settings: Reduce Motion, count speed
	deed_toast = DeedToast.new()
	add_child(deed_toast)
	deed_toast.burst_wanted.connect(func(at: Vector2):
		if juice != null and is_instance_valid(juice):
			juice.burst(at, 36, ["gold", "white", "green"]))
	show_front_door("title")


## The web's Cb select state: kept here so the front door remembers the last
## Street and Meldling between runs, as the web does.
var cb := {"step": "title", "mode": "", "street": null, "meld_idx": 0}
var front: FrontDoor


var deed_toast: DeedToast = null


## New deeds: queued toasts over whatever screen is up.
func announce_deeds(ids: Array) -> void:
	if deed_toast != null and not ids.is_empty():
		move_child(deed_toast, -1)
		deed_toast.announce(ids)


## The title and the select steps. `step` "" keeps where the player was.
func show_front_door(step := "") -> void:
	_no_slide = screen == "front"     # moving between front-door steps doesn't slide the page
	_clear()
	_no_slide = false
	_set_screen("front")
	if step != "":
		cb.step = step
	Sound.music("menu")
	front = FrontDoor.new()
	front.can_resume = has_save()
	_page.add_child(front)
	front.open(cb)
	front.begin.connect(start_run, CONNECT_ONE_SHOT)
	front.guided.connect(start_guided, CONNECT_ONE_SHOT)
	front.resume_run.connect(resume, CONNECT_ONE_SHOT)
	front.playtest_jump.connect(playtest_jump)
	front.first.connect(func(id: String):
		if deed_toast != null:
			move_child(deed_toast, -1)
			deed_toast.celebrate(id))


var coach: GuideCoach


## Web guideStart: Thump on First Street (unseeded), straight into the round,
## no intro, with the coach on top. "PLAY ON" leaves for the run choices.
func start_guided() -> void:
	run = CribRun.new("thump", Meta.STREETS[0])
	_on_deal()
	coach = GuideCoach.new()
	_page.add_child(coach)
	coach.attach(keep)
	# PLAY ON leaves the guided round behind (web: showCribSelect): drop its save
	coach.play_on.connect(func():
		clear_save()
		show_front_door("road"), CONNECT_ONE_SHOT)
	coach.message.connect(flash)


# ------------------------------------------------------------------ save / resume
## iOS kills backgrounded apps, so the run is saved at every step (each screen,
## each shop purchase, every deal, count and lay) and resumed exactly. The save
## is written after a step's effects land, so a resume never applies one twice.
## A finished run (lost, or every round cleared) clears it.
const SAVE_PATH := "user://run_save.txt"
var last_save := ""        ## the latest save text (on disk too when Achv.persist)
var saves := 0


func save_now() -> void:
	if run == null:
		return
	var ui := {"screen": screen}
	var r: CribRound = null
	var peg = null
	if screen == "round" and keep != null and keep.rd != null:
		r = keep.rd
		ui.merge(keep.save_ui())
		if keep.peg_view != null:
			peg = keep.peg_session
	elif screen == "round_end":
		r = rd
	last_save = SaveGame.dump(run, r, ui, peg)
	saves += 1
	if Achv.persist:
		var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if f:
			f.store_string(last_save)


func clear_save() -> void:
	last_save = ""
	if Achv.persist and FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


func has_save() -> bool:
	return last_save != "" or (Achv.persist and FileAccess.file_exists(SAVE_PATH))


## Pick the saved run back up where it was.
func resume() -> void:
	var text := last_save
	if text == "" and Achv.persist and FileAccess.file_exists(SAVE_PATH):
		text = FileAccess.get_file_as_string(SAVE_PATH)
	if text == "":
		return
	var parts := SaveGame.load_(text)
	run = parts[0]
	var ui: Dictionary = parts[2]
	match ui.get("screen", "intro"):
		"shop":
			show_shop()
		"round":
			_clear()
			_set_screen("round")
			keep = Warm.keep.instantiate()
			keep.in_run = true
			_page.add_child(keep)
			keep.round_finished.connect(_on_round_finished, CONNECT_ONE_SHOT)
			keep.deeds_earned.connect(announce_deeds)
			keep.save_point.connect(save_now)
			keep.resume_round(run, parts[1], ui, parts[3])
		"round_end":
			rd = parts[1]
			_paid = true          # its Glim was paid before the save
			_render_round_end()
		"free_end":
			show_free_end()
		_:
			show_intro()


## A fresh run. Tests may pass a prepared run.
func start_run(run_: CribRun = null) -> void:
	run = run_ if run_ != null else CribRun.new(meldling, Meta.STREETS[street_id - 1], null, seed)
	CascadeView.speed_i = Menus.speed_default(Achv.load_store())
	show_intro()


var _drawn_for := Vector3(-1, -1, -1)   ## TypeScale.layout_key at the last draw


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _page != null and screen in ["intro", "round_end", "run_won", "free_end"]:
		_redraw_if_moved.call_deferred()


## Deferred: a resize can land in the middle of a draw (the first layout pass
## sizing the flow), and the key is only compared once the draw is done.
func _redraw_if_moved() -> void:
	if _page != null and screen in ["intro", "round_end", "run_won", "free_end"] and TypeScale.layout_key(self) != _drawn_for:
		_rerender()


func _rerender() -> void:
	_no_slide = true          # a resize redraws in place: no transition
	match screen:
		"intro": show_intro()
		"round_end": _render_round_end()
		"run_won": show_run_won()
		"free_end": show_free_end()
	_no_slide = false


# ------------------------------------------------------------------ page helpers
## Page transitions: the new page slides in from the right while the old one
## leaves to the left along the same path, on a critically damped spring
## (damping 1.0, response 0.35 s). Interruptible: a page change mid-slide
## drops the leaving page and starts from where the current one is.
const SLIDE_RESPONSE := 0.35
var _outgoing: Control = null
var _slide_v := 0.0
var _no_slide := false
var juice: Juice = null           ## the page's bursts and shake
var surface: Surface = null


func _clear() -> void:
	buttons.clear()
	mvp_icon = null
	synergy_icons = []
	new_dot = null
	short_line = null
	round_motion.skip()
	var animate: bool = _page != null and not _no_slide and not MeldSprite.reduce_motion and size.x > 0.0
	var from_x: float = _page.position.x if _page != null else 0.0
	if _outgoing != null:
		_outgoing.queue_free()
		_outgoing = null
	# the guide coach belongs to its round: it goes now, not when the slide ends
	if coach != null and is_instance_valid(coach):
		coach.queue_free()
	coach = null
	if animate:
		# the current page becomes the leaving one; nothing in it takes input
		_outgoing = _page
		_outgoing.propagate_call("set", ["mouse_filter", Control.MOUSE_FILTER_IGNORE])
		for b in _outgoing.find_children("*", "BaseButton", true, false):
			(b as BaseButton).disabled = true
	for c in get_children():
		if c == _toast or c == _outgoing or c == deed_toast:
			continue
		remove_child(c)
		c.queue_free()
	keep = null
	shop = null
	_page = Control.new()
	_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_page)
	var boss = run.boss() if run != null else null
	surface = Surface.make("spoiler" if boss != null and screen != "shop" else "round")
	_page.add_child(surface)
	juice = Juice.new()
	# no shake at page level: the page itself is what slides (a shake here would
	# fight the spring and restore a stale position)
	juice.target = null
	_page.add_child(juice)
	Press.watch(self)
	if animate:
		_page.position.x = from_x + size.x
		_slide_v = 0.0
	if _toast != null:
		move_child(_toast, -1)


## Snap any transition to rest (tests that measure layout; nothing in play needs it).
func settle() -> void:
	if front != null and is_instance_valid(front):
		front.settle()
	if shop != null and is_instance_valid(shop):
		shop.finish()
	if _page != null:
		_page.position.x = 0.0
	_slide_v = 0.0
	if _outgoing != null:
		_outgoing.queue_free()
		_outgoing = null


func _process(delta: float) -> void:
	if _page == null or (_outgoing == null and absf(_page.position.x) < 0.01):
		return
	var w := TAU / SLIDE_RESPONSE
	var left := minf(delta, 0.25)
	while left > 0.0:
		var h := minf(left, 1.0 / 240.0)
		_slide_v += (-_page.position.x * w * w - _slide_v * 2.0 * w) * h
		_page.position.x += _slide_v * h
		left -= h
	if _outgoing != null:
		_outgoing.position.x = _page.position.x - size.x
	if absf(_page.position.x) < 0.5 and absf(_slide_v) < 20.0:
		_page.position.x = 0.0
		_slide_v = 0.0
		if _outgoing != null:
			_outgoing.queue_free()
			_outgoing = null


## The web's flash(): one line over whatever screen comes next, gone in 1.6 s.
var _toast: Label
var _toast_tween: Tween


## The run card (pass 19): render it once, save it, then the share sheet when
## the build has the plugin (iOS, unverified), else say where it went.
var run_card: RunCard = null
var run_card_path := ""


func _share_card(won: bool) -> void:
	if run == null or run_card != null:
		return
	run_card = RunCard.build(run, won)
	add_child(run_card)
	var path := "user://run_card_%s.png" % Time.get_datetime_string_from_system().replace(":", "-")
	run_card.render_to(path, func(saved: String):
		run_card_path = saved
		if is_instance_valid(run_card):
			run_card.queue_free()
		run_card = null
		if saved == "":
			flash("Couldn't draw the card here.")
		elif not RunCard.share(saved):
			flash("Run card saved."))


func flash(msg: String) -> void:
	if _toast == null:
		_toast = Label.new()
		_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		TypeScale.set_size(_toast, 22)
		_toast.add_theme_color_override("font_color", INK)
		_toast.add_theme_color_override("font_outline_color", BG)
		_toast.add_theme_constant_override("outline_size", 8)
		_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_toast)
	move_child(_toast, -1)
	var c := _col()
	_toast.text = msg
	_toast.position = Vector2(c.x, size.y * 0.42)
	_toast.size = Vector2(c.y, 0)
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.2)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)


func _set_screen(name: String) -> void:
	screen = name
	screen_changed.emit(name)


func _col() -> Vector2:
	var col := minf(size.x - MARGIN * 2.0, MAX_COLUMN)
	return Vector2((size.x - col) / 2.0, col)


## Stacks centred lines top-down; returns the y below what it placed.
## Your Meldling on the page, centred at y; plays `pose` as it appears.
var meld_view: MeldSprite = null
var spoiler_view: SpoilerSprite = null


## The Spoiler on the page, centred at y (or at x when given).
func _spoiler_at(y: float, px: float, boss: Dictionary, pose: String, x := -1.0, quiet := false) -> float:
	spoiler_view = SpoilerSprite.new(boss)
	spoiler_view.size = Vector2(px, px)
	spoiler_view.position = Vector2((size.x - px) / 2.0 if x < 0.0 else x, y)
	_page.add_child(spoiler_view)
	spoiler_view.react(pose, quiet)
	return y + px


## The act at a glance: one pip per round, done ones gold, this one ringed,
## the Spoiler's round (the last) marked. Reads run.act/round only.
func _act_track(y: float, done_this := false) -> float:
	var c := _col()
	var n := CribData.ROUNDS
	var d := 34.0
	var w := minf(c.y, 440.0)
	var x0 := (size.x - w) / 2.0
	var step := (w - d) / float(n - 1)
	var line := ColorRect.new()
	line.color = Color(INK, 0.18)
	line.position = Vector2(x0 + d / 2.0, y + d / 2.0 - 2.0)
	line.size = Vector2(w - d, 4)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.add_child(line)
	for i in n:
		var r := i + 1
		var done := r < run.round or (r == run.round and done_this)
		var here := r == run.round
		var boss := r == n
		var p := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(int(d / 2.0))
		sb.bg_color = GOLD if done else PANEL
		sb.border_color = (RED if boss else GOLD) if (here or boss) else Color(INK, 0.3)
		sb.set_border_width_all(4 if here else 2)
		p.add_theme_stylebox_override("panel", sb)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.position = Vector2(x0 + i * step, y)
		p.size = Vector2(d, d)
		_page.add_child(p)
		if here and done_this:
			new_dot = p               # the dot this round just filled (pass 21's pop)
		if boss:
			var k := Label.new()
			k.text = "!"
			k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			k.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			TypeScale.set_size(k, 22)
			k.add_theme_color_override("font_color", PANEL if done else RED)
			k.mouse_filter = Control.MOUSE_FILTER_IGNORE
			k.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			p.add_child(k)
	return _line(y + d + 6.0, "ACT %d  ·  ROUND %d OF %d  ·  SPOILER AT %d" % [run.act, run.round, n, n], 17, DIM)


## Your charms as chips (the Meldling's knack first), under a small heading.
func _charm_row(y: float) -> float:
	var c := _col()
	y = _line(y, "YOUR CHARMS", 16, GOLD)
	var bar := CharmBar.new()
	_page.add_child(bar)
	bar.position = Vector2(c.x, y)
	bar.size = Vector2(c.y, CharmBar.H)
	bar.build(run)
	bar.size = Vector2(c.y, bar.height())
	return y + bar.size.y + 10.0


## Use the room left above the buttons: the Meldling (or the pair) grows into up
## to half of it, then the block is centred, so no band sits empty. Short of
## room (Larger text on a short phone), the art shrinks instead, to 90 px. `first` is
## the page child where the content starts; `bottom` is where it ends.
func _fill(first: int, top: float, bottom: float) -> void:
	var btn_top := size.y
	for k in buttons:
		btn_top = minf(btn_top, (buttons[k] as Control).position.y)
	var free := btn_top - 20.0 - bottom
	var art: Array = []
	for v in [meld_view, spoiler_view]:
		if v != null and is_instance_valid(v) and v.get_parent() == _page:
			art.append(v)
	if free < 0.0:
		# too tall (Larger text on a short phone): the art gives up the room,
		# down to 90 px, and everything below it moves up
		if art.is_empty():
			return
		var cut: float = minf(-free, art[0].size.y - 90.0)
		if cut <= 0.0:
			return
		var art_bottom: float = art[0].position.y + art[0].size.y
		for i in range(first, _page.get_child_count()):
			var n := _page.get_child(i) as Control
			if n != null and not art.has(n) and not buttons.values().has(n) and n.position.y >= art_bottom - 1.0:
				n.position.y -= cut
		for v in art:
			var cx: float = v.position.x + v.size.x / 2.0
			v.size -= Vector2(cut, cut)
			v.position.x = cx - v.size.x / 2.0
		return
	if free == 0.0:
		return
	if not art.is_empty():
		var grow := minf(free * 0.5, 180.0)
		var art_bottom: float = art[0].position.y + art[0].size.y
		for i in range(first, _page.get_child_count()):
			var n := _page.get_child(i) as Control
			if n != null and not art.has(n) and not buttons.values().has(n) and n.position.y >= art_bottom - 1.0:
				n.position.y += grow
		var pair := art.size() == 2
		for v in art:
			var cx: float = v.position.x + v.size.x / 2.0
			v.size += Vector2(grow, grow) * (0.5 if pair else 1.0)
			v.position.x = cx - v.size.x / 2.0
		if pair:
			var gap := 24.0
			var x0: float = (size.x - art[0].size.x * 2.0 - gap) / 2.0
			art[0].position.x = x0
			art[1].position.x = x0 + art[0].size.x + gap
			for i in range(first, _page.get_child_count()):
				var n := _page.get_child(i) as Control
				if n != null and not art.has(n) and not buttons.values().has(n) and n.position.y >= art_bottom - 1.0 + grow:
					n.position.y -= grow * 0.5
			grow *= 0.5
		free -= grow
	var shift := free / 2.0
	for i in range(first, _page.get_child_count()):
		var n := _page.get_child(i) as Control
		if n != null and not buttons.values().has(n) and n != juice and n != surface:
			n.position.y += shift


func _meld_at(y: float, px: float, pose: String, quiet := false) -> float:
	meld_view = MeldSprite.new(run.meldling)
	meld_view.size = Vector2(px, px)
	meld_view.position = Vector2((size.x - px) / 2.0, y)
	_page.add_child(meld_view)
	meld_view.react(pose, quiet)
	return y + px


var mvp_icon: TextureRect = null   ## the round end's MVP icon (tests)
var new_dot: Panel = null          ## the act track's dot this round filled
var short_line: Label = null       ## the intro's Shortage line (the stamp lands on it)
const STAMP_HAPTIC := 35           ## ms: the Shortage stamp (pass 22)
var round_motion := Motion.new()   ## the round end's count-up, dot pop, Next slide (pass 21)


## A tap anywhere lands whatever is moving on this screen (it doesn't stop the
## tap: a press on a button still presses it).
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and round_motion.running():
		round_motion.skip()


## The Shortage stamp (pass 21): its line lands like a stamp, 1.4 to 1.0 with a
## short shake, and a heavy note. Reduce Motion: a fade.
func _stamp(l: Label) -> void:
	if not Motion.on():
		return
	Sound.play("spoiler_peg")
	Haptics.pulse(STAMP_HAPTIC)       # the Shortage lands: a heavier buzz (pass 22)
	if Motion.reduced():
		round_motion.fade_in(l)
		return
	var rest: Vector2 = l.position
	l.pivot_offset = l.size / 2.0
	l.scale = Vector2.ONE * 1.4
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	for dx in [6.0, -5.0, 3.0, -2.0, 0.0]:
		tw.tween_property(l, "position", rest + Vector2(dx, 0), 0.04)
	round_motion.add(tw, func():
		if is_instance_valid(l):
			l.scale = Vector2.ONE
			l.position = rest)


## The round end in motion: Final score and Glim count up (0.6 s), the new act
## dot pops, the Next line slides in last. Drawn at rest first; a tap lands it.
## Reduce Motion: the dot and the Next line fade in; numbers show at once.
func _round_end_motion() -> void:
	if not Motion.on():
		return
	var labels: Array = _page.find_children("*", "Label", true, false)
	var reduced := Motion.reduced()
	for l in labels:
		var t := String(l.text)
		if not reduced and t.begins_with("Final score  "):
			round_motion.count(l, "Final score  %%d / %d" % rd.target, 0.0, rd.score, 0.6)
		elif not reduced and t.begins_with("Glim  +"):
			round_motion.count(l, "Glim  +%d", 0.0, rd.essence_earned, 0.6)
		elif t.begins_with("Next: "):
			if reduced:
				round_motion.fade_in(l)
			else:
				var rest: Vector2 = l.position
				var rest_m: Color = l.modulate
				l.position = rest + Vector2(60, 0)
				l.modulate = Color(rest_m, 0.0)
				var tw: Tween = l.create_tween()
				tw.tween_interval(0.5)
				tw.tween_property(l, "position", rest, Motion.SPRING).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				tw.parallel().tween_property(l, "modulate", rest_m, Motion.SPRING)
				round_motion.add(tw, func():
					if is_instance_valid(l):
						l.position = rest
						l.modulate = rest_m)
	if new_dot != null and is_instance_valid(new_dot):
		if reduced:
			round_motion.fade_in(new_dot)
		else:
			round_motion.settle(new_dot, 0.4, 0.45)
var synergy_icons: Array = []        ## the round end's synergy icons (tests)


## Charm icons in a row ending just left of a centred label's first line.
func _icons_before(l: Label, names: Array, px: float) -> void:
	synergy_icons.clear()
	var font := l.get_theme_font("font")
	var fs := l.get_theme_font_size("font_size")
	var first_w := minf(l.size.x, font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	var x := l.position.x + (l.size.x - first_w) / 2.0 - 4.0
	var y := l.position.y + (font.get_height(fs) - px) / 2.0
	for i in range(names.size() - 1, -1, -1):
		var ic := CharmIcon.make(CharmIcon.id_for(String(names[i]).strip_edges()), px)
		if ic == null:
			continue
		x -= px + 2.0
		ic.position = Vector2(maxf(0.0, x), y)
		_page.add_child(ic)
		synergy_icons.push_front(ic)


func _line(y: float, text: String, fs: int, colr: Color) -> float:
	var c := _col()
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	TypeScale.set_size(l, fs)
	l.add_theme_color_override("font_color", colr)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = Vector2(c.x, y)
	l.size = Vector2(c.y, 0)
	_page.add_child(l)
	var h: float = l.get_combined_minimum_size().y
	l.size.y = h
	return y + h + 6.0


func _panel(y: float, lines: Array) -> float:
	## lines: [[text, fs, color], ...] inside a bordered box
	var c := _col()
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL
	sb.border_color = Color(INK, 0.15)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.position = Vector2(c.x, y)
	_page.add_child(p)
	var yy := y + 10.0
	for ln in lines:
		yy = _line(yy, ln[0], ln[1], ln[2])
	p.size = Vector2(c.y, yy - y + 6.0)
	return y + p.size.y + 10.0


## The main action sits in the thumb zone; side actions stack just above it.
func _button(key: String, text: String, big: bool, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	TypeScale.set_size(b, 30 if big else 22)
	b.pressed.connect(cb)
	_page.add_child(b)
	buttons[key] = b
	return b


func _place_buttons(order: Array) -> void:
	## order: keys, bottom first. The first is big and lowest.
	var ins := SafeArea.insets(self)
	var y: float = size.y - ins.bottom - MARGIN * 1.5
	for i in order.size():
		var b: Button = buttons[order[i]]
		var h := Press.MIN_H + 6.0 if i == 0 else Press.MIN_H   # 44 pt minimum
		# a label wider than the button grows it rightward, off centre: size to fit
		var w := maxf(300.0 if i == 0 else 260.0, b.get_combined_minimum_size().x + 32.0)
		w = minf(w, size.x - MARGIN * 2.0)
		y -= h
		b.size = Vector2(w, h)
		b.position = Vector2((size.x - w) / 2.0, y)
		y -= 12.0


# ------------------------------------------------------------------ intro
## Port of cribRoundIntro.
## The web's intro track: the boss theme on a Spoiler round, the Long Count's
## own loop, else the act's (act 5's beyond it).
static func music_for(r: CribRun) -> String:
	if r.boss() != null:
		return "boss"
	if r.endless:
		return "endless"
	return "act%d" % mini(5, r.act)


func show_intro() -> void:
	if Entitlement.capped(run):
		show_free_end()            # free mode never starts a round past act 1
		return
	_drawn_for = TypeScale.layout_key(self)
	_clear()
	_set_screen("intro")
	var boss = run.boss()
	var m := run.rules()
	Sound.music(music_for(run))
	var ins := SafeArea.insets(self)
	var y: float = ins.top + MARGIN * 2.0
	var first := _page.get_child_count()
	y = _line(y, "ACT %d  ·  ROUND %d / %d" % [run.act, run.round, CribData.ROUNDS], 20, DIM)
	if run.is_wager():
		y = _line(y, "A WAGER", 18, GOLD)
		y = _line(y, "SCORE IT EXACTLY", 40, GOLD)
		var terms := [["THE TERMS", 18, GOLD],
			["Finish on exactly %d. Not one point more." % run.target(), 20, INK]]
		var locked := Achv.locked_systems()
		if not locked.is_empty():
			terms.append(["Win and you keep: %s. %s" % [locked[0].name, locked[0].text], 17, GREEN])
		terms.append(["Lose and the run ends. You may walk away instead.", 17, DIM])
		y = _panel(y + 6.0, terms)
	elif boss != null:
		var sev_name: String = ["", "A SPOILER", "A GRIM SPOILER", "A RUINOUS SPOILER"][boss.sev]
		y = _line(y, "%s  ·  ACT %d BOSS" % [sev_name, run.act], 18, SEV[boss.sev])
		y = _line(y, boss.name, 44, SEV[boss.sev])
		y = _spoiler_at(y, 220.0, boss, "smug", -1.0, true)
		Sound.play("boss_intro")
		y = _panel(y + 6.0, [["THE SPOILER DECREES", 18, SEV[boss.sev]], [boss.text, 20, INK]])
	else:
		y = _line(y, "TARGET %d" % run.target(), 52, INK)
		y = _meld_at(y, 220.0, "eager")
	var tw = run.twist() if boss == null and not run.is_wager() else null
	var short = run.shortage() if boss == null else null
	if short != null:
		# the Shortage (pass 20): the run's best category is short this round
		y = _line(y + 4.0, "SHORTAGE: %s score half this round, your best so far. %d deals." % [
			CribData.SHORTAGE_NAMES[short], CribData.DEALS + m.dealBonus], 22, RED)
		short_line = _page.get_child(_page.get_child_count() - 1)
	elif tw != null:
		# the plain round's twist (LOOP_AUDIT 5), its price, and the deals, in
		# the place of "Score N in D deals" (the target is just above)
		y = _line(y + 4.0, "%s: %s  Target +%d%%, %d deals." % [String(tw.name).to_upper(), tw.text,
			roundi((CribData.TWIST_TARGET - 1.0) * 100.0), CribData.DEALS + m.dealBonus], 22, GOLD)
	else:
		y = _line(y + 4.0, "Score %d in %d deals" % [run.target(), CribData.DEALS + m.dealBonus], 22, GOLD)
	y = _line(y, "%s  ·  deck %d  ·  charms %d/%d" % [run.street.name, run.deck_size(), run.charms.size(), run.slots()], 17, DIM)
	# the Spoilers on the road: past dimmed, this act's marked
	var plan := []
	for i in run.boss_plan.size():
		var b: Dictionary = run.boss_plan[i]
		var mark := "" if i + 1 != run.act else "  <"
		plan.append(["A%d %s%s" % [i + 1, b.name, mark], 17, DIM if i + 1 < run.act else SEV[b.sev]])
	y = _act_track(y + 10.0)
	y = _charm_row(y + 4.0)
	y = _line(y, "SPOILERS ON THE ROAD", 16, GOLD)
	y = _panel(y, plan)
	var order := ["deal"]
	_button("deal", "DEAL", true, _on_deal)
	if run.is_wager():
		_button("walk", "WALK AWAY", false, _on_walk_away)
		order.append("walk")
	_place_buttons(order)
	_fill(first, ins.top, y)
	if short_line != null and not _no_slide:
		_stamp(short_line)
	save_now()


func _on_deal() -> void:
	Playtest.round_start(run)      # playtest builds only: the private session log
	_clear()
	_set_screen("round")
	keep = Warm.keep.instantiate()
	keep.in_run = true
	keep.seed = seed
	keep.meldling = meldling
	_page.add_child(keep)
	keep.round_finished.connect(_on_round_finished, CONNECT_ONE_SHOT)
	keep.deeds_earned.connect(announce_deeds)
	keep.save_point.connect(save_now)
	keep.start_round(run)


## Web: the wager is struck from the plan and the intro redrawn.
func _on_walk_away() -> void:
	run.wager_at["%d-%d" % [run.act, run.round]] = false
	show_intro()
	flash("You let the wager pass.")


## Skips were removed (web too): nothing ever earned one, and as designed a
## skipped round costs more Glim than it pays (simulated; see PORT.md).


# ------------------------------------------------------------------ round end
func _on_round_finished() -> void:
	rd = keep.rd
	_paid = false
	_round_end_effects()
	_render_round_end()
	if rd.won:
		save_now()
	else:
		clear_save()          # the run is over


## Port of cribRoundEnd's state changes, in its order. Runs once per round.
## First-time celebrations (Firsts). A Spoiler closes every act, so the two
## usually land together: then the act's card shows and the Spoiler's is
## claimed quietly. Presentation only.
func _celebrate_round() -> void:
	if rd == null or not rd.won or deed_toast == null:
		return
	var act_done: bool = run.round == CribData.ROUNDS
	if act_done and Firsts.claim("act"):
		Firsts.claim("spoiler")
		deed_toast.celebrate("act")
	elif run.is_boss() and Firsts.claim("spoiler"):
		deed_toast.celebrate("spoiler")


func _round_end_effects() -> void:
	rd.settle()   # settles the Crib once if needed (web cribend.patch)
	Playtest.round_end(run, rd)
	if rd.wager != null and rd.wager_won:
		var locked := Achv.locked_systems()
		if not locked.is_empty():
			Achv.grant_system(locked[0].id)
	var max_lv := 0
	for k in run.levels:
		max_lv = maxi(max_lv, run.levels[k])
	_celebrate_round()
	announce_deeds(Achv.check("round", {"won": rd.won, "act": run.act, "round": run.round, "score": rd.score,
		"target": rd.target, "deckSize": run.deck_size(),
		"cribTotal": rd.crib_result.total if rd.crib_result != null else 0,
		"maxReckoning": max_lv,
		"hallowed": run.charms.filter(func(c): return c.rarity == "legendary").size(),
		"shattered": rd.shattered_all.size(),
		"actCleared": rd.won and run.round == CribData.ROUNDS}))
	if rd.won and not _paid:
		run.essence += rd.essence_earned
		_paid = true
	if not rd.won:
		Achv.add_pegs(Meta.pegs_for_loss(run.round_index() - 1))   # every run pays
		RunRecord.record(run, run.round_index() - 1, rd.score)
		# lost runs go in the Record too, not only wins
		Achv.log_run({"deck": run.meldling, "reached": run.round_index() - 1, "street": run.street.id,
			"score": rd.score, "cleared": false, "when": int(Time.get_unix_time_from_system() * 1000.0)})
		# the Daily is one attempt; the Long Count keeps its best (web: same fix)
		if run.daily != null:
			Achv.record_daily(run.daily, {"reached": run.round_index() - 1, "score": rd.score})
		if run.endless:
			Achv.set_endless(run.round_index() - 1)


func _render_round_end() -> void:
	_drawn_for = TypeScale.layout_key(self)
	_clear()
	_set_screen("round_end")
	if not _no_slide:          # a resize redraw doesn't play it again
		Sound.play("win" if rd.won else "lose")
	var ins := SafeArea.insets(self)
	var y: float = ins.top + MARGIN * 2.0
	var first := _page.get_child_count()
	var head := "ROUND CLEARED" if rd.won else "RUN OVER"
	var colr := INK if rd.won else RED
	if rd.wager != null:
		head = ("EXACTLY %d" % rd.target) if rd.wager_won else ("MISSED BY %d" % absi(rd.margin))
	if rd.narrow:
		head = "CLEARED BY %d" % rd.margin
		colr = GOLD
	if rd.so_close:
		head = "%d SHORT" % -rd.margin
		colr = RED
	y = _line(y, head, 44, colr)
	var boss_end = run.boss()
	if boss_end != null:
		# a Spoiler round: you and it, side by side
		var px := 190.0
		var gap := 24.0
		var x0 := (size.x - px * 2.0 - gap) / 2.0
		_meld_at(y, px, "victory" if rd.won else "deflated", true)
		meld_view.position.x = x0
		y = _spoiler_at(y, px, boss_end, "defeated" if rd.won else "gloat", x0 + px + gap, true)
	else:
		y = _meld_at(y, 200.0, "victory" if rd.won else "deflated", true)
	var m = rd.mvp()
	if m != null:
		var lines := [["THIS WON YOU THE ROUND" if m.decisive else "BIGGEST CONTRIBUTOR", 16, DIM],
			[str(m.name), 30, INK], ["+%d points" % JS.round_(m.points), 18, GOLD]]
		if m.decisive:
			lines.append(["Without it you'd have finished on %d. You needed %d." % [JS.round_(m.without), rd.target], 17, RED])
		var top := y + 4.0
		y = _panel(top, lines)
		# the MVP's charm icon (pass 19) at the panel's left, when it's a charm
		var mic := CharmIcon.make(CharmIcon.id_for(str(m.name)), 56.0)
		if mic != null:
			mic.position = Vector2(_col().x + 12.0, top + (y - top - 56.0) / 2.0 - 3.0)
			_page.add_child(mic)
			mvp_icon = mic
	var syn = rd.best_synergy()
	if syn != null:
		# two charms that fed each other (LOOP_AUDIT 7): the build, named, with
		# both icons (pass 19) just before the line's text
		y = _line(y + 4.0, "%s fed each other  +%d" % [syn.pair, syn.points], 20, GOLD)
		var sl: Label = _page.get_child(_page.get_child_count() - 1)
		_icons_before(sl, String(syn.pair).split(" + "), 30.0)
	var box := []
	if not rd.shattered_all.is_empty():
		box.append(["Shattered: " + ", ".join(rd.shattered_all.map(func(c): return Cribbage.card_str(c))), 17, Color(0.45, 0.88, 0.82)])
	if rd.coins_all:
		box.append(["Minted cards  +%d Glim" % rd.coins_all, 18, GREEN])
	var cr = rd.crib_result
	var crib_labels: Array = cr.events.map(func(e): return e.label) if cr != null else []
	if not crib_labels.is_empty():
		box.append([", ".join(crib_labels), 16, DIM])
	box.append(["The Crib pays  +%d" % (cr.total if cr != null else 0), 20, GOLD])
	if rd.out_of_cards:
		box.append(["Your deck ran out.", 17, RED])
	box.append(["Final score  %d / %d" % [rd.score, rd.target], 22, GREEN if rd.won else RED])
	if rd.won:
		box.append(["Glim  +%d" % rd.essence_earned, 22, GOLD])
	y = _panel(y + 4.0, box)
	if rd.won:
		y = _act_track(y + 6.0, true)
		if not run.endless and not (run.act == CribData.ACTS and run.round == CribData.ROUNDS):
			var nxt := "Act %d" % (run.act + 1) if run.round == CribData.ROUNDS else (
				"the Spoiler" if run.round + 1 == CribData.ROUNDS else "Round %d" % (run.round + 1))
			var nt = run.next_twist()
			var ns = run.next_shortage()
			var tag := ("  ·  Shortage: %s" % CribData.SHORTAGE_NAMES[ns]) if ns != null else ("  ·  " + String(nt.name) if nt != null else "")
			y = _line(y + 4.0, "Next: %s, target %d%s" % [nxt, run.next_target(), tag], 22, INK)
	if rd.won and Entitlement.capped(run, true):
		# free to try: the first Spoiler is beaten; what's next is the end card
		_button("free_next", "WHAT'S NEXT", true, show_free_end)
		_place_buttons(["free_next"])
	elif rd.won:
		_button("shop", "SHOP", true, func():
			run.open_shop()
			show_shop())
		_place_buttons(["shop"])
	else:
		y = _line(y, "Reached Act %d, Round %d.  +%d Pegs" % [run.act, run.round, Meta.pegs_for_loss(run.round_index() - 1)], 20, DIM)
		y = _line(y, RunRecord.line(), 18, GOLD)
		y = _line(y, NextUnlock.line(), 20, INK)
		_button("new_run", "NEW RUN", true, _new_run)
		_button("share", "Share", false, _share_card.bind(false))
		_button("title", "Title", false, func(): show_front_door("title"))
		_place_buttons(["new_run", "share", "title"])
	_fill(first, ins.top, y)
	if not _no_slide:
		_round_end_motion()

	if rd.won:
		_page.move_child(juice, -1)
		juice.burst(Vector2(size.x / 2.0, size.y * 0.22), 40, ["gold", "white", "green"])


# ------------------------------------------------------------------ free to try
## The free part ends here (docs/MONETIZATION.md): the first Spoiler is beaten.
## What the full game adds (counted from the data), the unlock, Restore, and
## Not now. Once a run, after a win, never after a loss; no other nagging.
## Unlocking continues this same run into the shop.
var free_status: Label = null
var _store_hooked: Object = null


func show_free_end() -> void:
	_drawn_for = TypeScale.layout_key(self)
	_clear()
	_set_screen("free_end")
	var ins := SafeArea.insets(self)
	var y: float = ins.top + MARGIN * 2.0
	var first := _page.get_child_count()
	y = _line(y, "YOU BEAT THE FIRST SPOILER", 40, GOLD)
	y = _meld_at(y, 200.0, "victory", true)
	y = _panel(y + 4.0, [["THE FREE PART ENDS HERE", 16, DIM], [Entitlement.pitch(run), TypeScale.BODY, INK]])
	free_status = Label.new()
	free_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	free_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	TypeScale.set_size(free_status, 20)
	free_status.add_theme_color_override("font_color", DIM)
	free_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var c := _col()
	free_status.position = Vector2(c.x, y)
	free_status.size = Vector2(c.y, 0)
	_page.add_child(free_status)
	free_status.size = Vector2(c.y, free_status.get_combined_minimum_size().y)
	y += free_status.size.y
	var price := Entitlement.price()
	_button("unlock", ("UNLOCK  ·  %s" % price) if price != "" else "UNLOCK THE FULL GAME", true, _free_unlock)
	_button("restore", "Restore Purchases", false, _free_restore)
	_button("not_now", "Not now", false, _free_not_now)
	_place_buttons(["unlock", "restore", "not_now"])
	_fill(first, ins.top, y)
	_hook_store()
	save_now()


func _free_say(msg: String, col := DIM) -> void:
	if free_status != null and is_instance_valid(free_status):
		free_status.text = msg
		free_status.add_theme_color_override("font_color", col)
		free_status.size.y = free_status.get_combined_minimum_size().y


func _hook_store() -> void:
	var st := Entitlement.store()
	if st == null or st == _store_hooked:
		return
	_store_hooked = st
	if st.has_signal("purchased"):
		st.connect("purchased", _on_store_purchased)
	if st.has_signal("restored"):
		st.connect("restored", _on_store_restored)
	if st.has_signal("failed"):
		st.connect("failed", _on_store_failed)


func _free_unlock() -> void:
	var st := Entitlement.store()
	if st == null:
		_free_say("The App Store isn't available right now. Try again in a moment.", RED)
		return
	_free_say("Waiting for the App Store...")
	st.call("purchase", Entitlement.FULL_ID)


func _free_restore() -> void:
	var st := Entitlement.store()
	if st == null:
		_free_say("The App Store isn't available right now. Try again in a moment.", RED)
		return
	_free_say("Checking your purchases...")
	st.call("restore")


func _on_store_purchased(id: String) -> void:
	if id != Entitlement.FULL_ID:
		return
	Entitlement.grant()
	_free_continue("Unlocked. Thank you!")


func _on_store_restored(ids: Array) -> void:
	if ids.has(Entitlement.FULL_ID):
		Entitlement.grant()
		_free_continue("Restored. Welcome back!")
	elif screen == "free_end":
		_free_say("Nothing to restore on this Apple ID.", DIM)


func _on_store_failed(id: String, reason: String) -> void:
	if id != Entitlement.FULL_ID or screen != "free_end":
		return
	if reason == "cancelled":
		_free_say("Purchase cancelled. Nothing changed.", DIM)
	else:
		_free_say("The purchase didn't go through (%s). Try again, or Restore if you bought it before." % reason, RED)


## Unlocked on the card: the same run goes on, into the shop for act 2.
func _free_continue(msg: String) -> void:
	if screen != "free_end" or run == null:
		return
	Sound.play("buy")
	flash(msg)
	run.open_shop()
	show_shop()


## Not now: the run ends here as a free finish (recorded, Pegs paid once).
func _free_not_now() -> void:
	var cleared := run.round_index() if rd == null or rd.won else run.round_index() - 1
	cleared = mini(cleared, CribData.ROUNDS * Entitlement.FREE_LAST_ACT)
	Achv.add_pegs(Meta.pegs_for_loss(cleared))
	RunRecord.record(run, cleared, rd.score if rd != null else 0)
	Achv.log_run({"deck": run.meldling, "reached": cleared, "street": run.street.id,
		"score": rd.score if rd != null else 0, "cleared": false, "free": true,
		"when": int(Time.get_unix_time_from_system() * 1000.0)})
	if run.daily != null:
		Achv.record_daily(run.daily, {"reached": cleared, "score": rd.score if rd != null else 0})
	clear_save()
	run = null
	show_front_door("title")


## Web "New Run": back to the select steps, where the player left them.

func _new_run() -> void:
	show_front_door()


# ------------------------------------------------------------------ shop
func show_shop() -> void:
	_clear()
	_set_screen("shop")
	Sound.music("shop")
	shop = Warm.shop.instantiate()
	shop.juice = juice
	_page.add_child(shop)
	_page.move_child(juice, -1)
	# while the page slides in, the shop arrives over a few frames (the slide
	# hides it); at rest (no slide) it's built at once
	shop.open(run, absf(_page.position.x) > 1.0)
	shop.next_round.connect(_on_next_round, CONNECT_ONE_SHOT)
	shop.acted.connect(func(_k): save_now())
	shop.first_charm.connect(func(ch: Charm):
		if deed_toast != null:
			move_child(deed_toast, -1)
			deed_toast.celebrate_charm(ch))
	save_now()


## Port of the shop's NEXT ROUND handler.
func _on_next_round() -> void:
	run.shop_state = null
	if run.endless:
		run.endless_round += 1
		show_intro()
		return
	if run.advance():
		_run_won_effects()
		clear_save()          # the run is over
		show_run_won()
		return
	show_intro()


# ------------------------------------------------------------------ run won
var _won_pegs := 0


## Port of cribRunWon's state changes, in its order. Runs once.
func _run_won_effects() -> void:
	Collection.mark_all(run.charms.map(func(c): return c.id), Collection.WON)   # the collection (pass 19)
	announce_deeds(Achv.check("run", {"cleared": true, "street": run.street.id}))
	Achv.mark_cleared(run.meldling)
	if run.trial != null:
		Achv.mark_trial(run.trial.id)
	var total := CribData.ACTS * CribData.ROUNDS
	_won_pegs = Meta.pegs_for_run(total, true, run.street.id, Achv.count())
	Achv.add_pegs(_won_pegs)
	Achv.log_run({"deck": run.meldling, "reached": total, "street": run.street.id,
		"score": 0, "cleared": true, "when": int(Time.get_unix_time_from_system() * 1000.0)})
	RunRecord.record(run, total, 0)
	if run.daily != null:
		Achv.record_daily(run.daily, {"reached": total, "score": 0, "cleared": true})


func show_run_won() -> void:
	_drawn_for = TypeScale.layout_key(self)
	_clear()
	_set_screen("run_won")
	var ins := SafeArea.insets(self)
	var y: float = ins.top + MARGIN * 3.0
	y = _line(y, "TWENTY-NINE", 52, GOLD)
	y = _line(y, "+%d Pegs" % _won_pegs, 22, GOLD)
	y = _line(y, NextUnlock.line(), 20, INK)
	var rm = run.run_mvp()
	if rm != null:
		y = _line(y, "Carried by %s: %d points." % [rm.name, rm.points], 20, GOLD)
	y = _line(y, "All %d rounds cleared on %s." % [CribData.ACTS * CribData.ROUNDS, run.street.name], 20, INK)
	if run.street.id < Meta.STREETS.size():
		y = _line(y, "%s is open." % Meta.STREETS[run.street.id].name, 18, GOLD)
	_button("new_run", "NEW RUN", true, _new_run)
	_button("share", "Share", false, _share_card.bind(true))
	_place_buttons(["new_run", "share"])


## Pass 21: no animation outlives its screen (a running job would keep a
## reference cycle alive: screen_leak_test).
func _exit_tree() -> void:
	round_motion.skip()



# ------------------------------------------------------------------ playtest jumps (pass 22)
## Build a real state through the engine and show it (playtest builds only).
## Returns whether it got there (tests). Rounds are played by the engine's own
## best keeps; nothing is drawn that a real game couldn't reach.
func playtest_jump(kind: String) -> bool:
	if not Playtest.enabled():
		return false
	match kind:
		"shortage":
			for sd in range(2201, 2300):
				var r := CribRun.new(CribData.DECKS.keys()[sd % 4], Meta.STREETS[0], null, sd)
				var r1 := _play_round(r, true)
				if not r1.won:
					continue
				r.essence += r1.essence_earned
				r.advance()
				if r.shortage() == null:
					continue
				start_run(r)
				return true
		"upgrade":
			for sd in range(2301, 2400):
				var r := CribRun.new("thump", Meta.STREETS[0], null, sd)
				for id in ["twinner", "rambler", "peacock", "streak", "keystone2"]:
					if not r.is_full():
						r.charms.append(CribData.charm_by_id(id))
				_play_round(r, true)
				r.open_shop()
				var pool := CribData.CHARMS.filter(func(ch): return ch.rule == null and not r.charms.has(ch) and ch.tier != 0)
				for i in range(0, pool.size() - 2, 3):
					var offer: Array = pool.slice(i, i + 3)
					if Upgrade.best(r, offer) != null:
						r.shop_state.offer = offer
						r.essence = maxi(r.essence, 30)
						run = r
						show_shop()
						return true
		"gallery":
			var ids := ["fifteener", "fever", "keystone2", "peacock"]
			var m := Achv.load_store().duplicate(true)
			var shown: Dictionary = m.get("charms_shown", {}).duplicate()
			for ch in CribData.CHARMS:
				if not shown.has(ch.id):
					shown[ch.id] = Collection.level(ch.id)
			for id in ids:
				shown[id] = mini(int(shown.get(id, 0)), Collection.SEEN if id != "peacock" else Collection.UNSEEN)
			m["charms_shown"] = shown
			Achv.save_store(m)
			Collection.mark("fifteener", Collection.WON)
			Collection.mark("fever", Collection.OWNED)
			Collection.mark("keystone2", Collection.OWNED)
			Collection.mark("peacock", Collection.SEEN)
			Menus.gal_tab = "charms"
			show_front_door("title")
			front.go("gallery")
			return true
		"run_end":
			for sd in range(2401, 2500):
				var r := CribRun.new("pip", Meta.STREETS[0], null, sd)
				for id in ["keystone2", "ballast", "fifteener"]:
					r.charms.append(CribData.charm_by_id(id))
				r.act = 2
				r.round = 2
				var d := _play_round(r, false)
				if d.won:
					continue
				run = r
				rd = d
				_paid = false
				_round_end_effects()
				_render_round_end()
				return true
	return false


## One round played to its end by the engine: best keeps, or highest cards.
func _play_round(r: CribRun, best: bool) -> CribRound:
	var d := CribRound.new(r)
	while d.new_deal() != null:
		var idx: Array = d.best_keep_ev().idx if best else range(d.keep_count())
		d.commit(idx)
		if d.score >= d.target or d.deals_left <= 0:
			break
	d.settle()
	return d
