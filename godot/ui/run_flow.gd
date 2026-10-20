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
## A finished run (lost, or all 25 rounds cleared) clears it.
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
		_:
			show_intro()


## A fresh run. Tests may pass a prepared run.
func start_run(run_: CribRun = null) -> void:
	run = run_ if run_ != null else CribRun.new(meldling, Meta.STREETS[street_id - 1], null, seed)
	show_intro()


var _drawn_for := Vector3(-1, -1, -1)   ## TypeScale.layout_key at the last draw


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _page != null and screen in ["intro", "round_end", "run_won"]:
		_redraw_if_moved.call_deferred()


## Deferred: a resize can land in the middle of a draw (the first layout pass
## sizing the flow), and the key is only compared once the draw is done.
func _redraw_if_moved() -> void:
	if _page != null and screen in ["intro", "round_end", "run_won"] and TypeScale.layout_key(self) != _drawn_for:
		_rerender()


func _rerender() -> void:
	_no_slide = true          # a resize redraws in place: no transition
	match screen:
		"intro": show_intro()
		"round_end": _render_round_end()
		"run_won": show_run_won()
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
		var grow := minf(free * 0.5, 140.0)
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
	save_now()


func _on_deal() -> void:
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
func _round_end_effects() -> void:
	rd.settle()   # settles the Crib once if needed (web cribend.patch)
	if rd.wager != null and rd.wager_won:
		var locked := Achv.locked_systems()
		if not locked.is_empty():
			Achv.grant_system(locked[0].id)
	var max_lv := 0
	for k in run.levels:
		max_lv = maxi(max_lv, run.levels[k])
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
		y = _panel(y + 4.0, lines)
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
	if rd.won:
		_button("shop", "SHOP", true, func():
			run.open_shop()
			show_shop())
		_place_buttons(["shop"])
	else:
		y = _line(y, "Reached Act %d, Round %d." % [run.act, run.round], 20, DIM)
		y = _line(y, RunRecord.line(), 18, GOLD)
		_button("new_run", "NEW RUN", true, _new_run)
		_button("title", "Title", false, func(): show_front_door("title"))
		_place_buttons(["new_run", "title"])
	_fill(first, ins.top, y)

	if rd.won:
		_page.move_child(juice, -1)
		juice.burst(Vector2(size.x / 2.0, size.y * 0.22), 40, ["gold", "white", "green"])


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
	var rm = run.run_mvp()
	if rm != null:
		y = _line(y, "Carried by %s: %d points." % [rm.name, rm.points], 20, GOLD)
	y = _line(y, "All %d rounds cleared on %s." % [CribData.ACTS * CribData.ROUNDS, run.street.name], 20, INK)
	if run.street.id < Meta.STREETS.size():
		y = _line(y, "%s is open." % Meta.STREETS[run.street.id].name, 18, GOLD)
	_button("new_run", "NEW RUN", true, _new_run)
	_place_buttons(["new_run"])
