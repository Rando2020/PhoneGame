class_name FrontDoor
extends Control
## The way into a run: the title, then the web's showCribSelect steps (road,
## street, trial, Meldling). Builds the run exactly as the web's buttons do and
## hands it over with `begin`. The step and choices live in `cb`, which the
## owner keeps between visits, as the web keeps them in Cb.
##
## Not ported from the title yet: Deeds, Gallery, Record, How to play,
## the theme toggle and the dev panel.

signal begin(run: CribRun)
## Web: PLAY on a fresh save (never guided, no runs) starts the guided first round.
signal guided
## CONTINUE on the title: pick the saved run back up.
signal resume_run
var can_resume := false     ## set by the owner before open(): a saved run exists

const BG := Color(0.102, 0.094, 0.149)
const PANEL := Color(0.14, 0.13, 0.20)
const INK := Color(0.96, 0.93, 0.88)
const DIM := Color(0.96, 0.93, 0.88, 0.6)
const GOLD := Color(0.91, 0.71, 0.30)
const MARGIN := 24.0
const MAX_COLUMN := 640.0
const ROMAN := ["I", "II", "III", "IV", "V", "VI", "VII", "VIII"]

## Web Cb: step ("title"/"road"/"street"/"trial"/"meld"), mode, street, meld_idx.
var cb := {"step": "title", "mode": "", "street": null, "meld_idx": 0}
var buttons := {}            ## key -> Button, for tests
var today := ""              ## Daily key override (tests); "" = today
var _page: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)   # size now, not next layout pass


func open(state: Dictionary = {}) -> void:
	if not state.is_empty():
		cb = state
	render()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _page != null:
		render()


var parade: Array = []            ## the title's six Meldlings
var meld_view: MeldSprite = null  ## the picker's Meldling


func render() -> void:
	match cb.step:
		"road": _road()
		"street": _street()
		"trial": _trial()
		"meld": _meld()
		"peddler": _peddler()
		_: _title()


func go(step: String) -> void:
	cb.step = step
	render()


# ------------------------------------------------------------------ helpers
func _clear() -> void:
	buttons.clear()
	if _page != null:
		remove_child(_page)
		_page.queue_free()
	_page = Control.new()
	_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_page)
	_page.add_child(Surface.make("menu"))
	Press.watch(self)


func _col() -> Vector2:
	var w := minf(size.x - MARGIN * 2.0, MAX_COLUMN)
	return Vector2((size.x - w) / 2.0, w)


func _top() -> float:
	return SafeArea.insets(self).top + MARGIN * 1.5


func _bottom() -> float:
	return size.y - SafeArea.insets(self).bottom - MARGIN


func _label(parent: Control, text: String, fs: int, col: Color, at: Vector2, w: float,
		align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = at
	l.size = Vector2(w, 0)
	parent.add_child(l)
	l.size = Vector2(w, l.get_combined_minimum_size().y)
	return l


func _line(y: float, text: String, fs: int, col: Color) -> float:
	var c := _col()
	var l := _label(_page, text, fs, col, Vector2(c.x, y), c.y)
	return y + l.size.y + 6.0


func _header(kicker: String, title: String) -> float:
	var y := _line(_top(), kicker, 18, GOLD)
	return _line(y, title, 34, INK) + 10.0


func _box(col: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	return sb


## A big centred action button, sized to its label.
func _button(key: String, text: String, big: bool, cb_: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 30 if big else 22)
	b.pressed.connect(cb_)
	_page.add_child(b)
	var w := maxf(300.0 if big else 200.0, b.get_combined_minimum_size().x + 32.0)
	b.size = Vector2(minf(w, size.x - MARGIN * 2.0), Press.MIN_H + 6.0 if big else Press.MIN_H)   # 44 pt minimum
	b.position.x = (size.x - b.size.x) / 2.0
	buttons[key] = b
	return b


## Stack buttons upward from the bottom (thumb zone), first = lowest.
func _stack_bottom(keys: Array) -> float:
	var y := _bottom()
	for k in keys:
		var b: Button = buttons[k]
		y -= b.size.y
		b.position.y = y
		y -= 12.0
	return y


## A full-width card: a name and a note, the whole card tappable.
func _card(key: String, y: float, name: String, note: String, open: bool, cb_: Callable) -> float:
	var c := _col()
	var b := Button.new()
	b.disabled = not open
	b.add_theme_stylebox_override("normal", _box(PANEL, Color(INK, 0.14)))
	b.add_theme_stylebox_override("hover", _box(PANEL.lightened(0.06), Color(GOLD, 0.6)))
	b.add_theme_stylebox_override("pressed", _box(PANEL.lightened(0.1), GOLD))
	b.add_theme_stylebox_override("disabled", _box(PANEL.darkened(0.25), Color(INK, 0.06)))
	b.position = Vector2(c.x, y)
	_page.add_child(b)
	var n := _label(b, name, 24, GOLD if open else DIM, Vector2(16, 10), c.y - 32.0, HORIZONTAL_ALIGNMENT_LEFT)
	var t := _label(b, note, 17, DIM, Vector2(16, 12 + n.size.y), c.y - 32.0, HORIZONTAL_ALIGNMENT_LEFT)
	b.size = Vector2(c.y, maxf(76.0, t.position.y + t.size.y + 10.0))
	b.pressed.connect(cb_)
	buttons[key] = b
	return y + b.size.y + 10.0


func _day() -> String:
	return today if today != "" else Meta.daily_key()


# ------------------------------------------------------------------ title
func _title() -> void:
	_clear()
	var y := _line(_top() + size.y * 0.12, "MELDLINGS", 56, GOLD)
	y = _line(y, "Count it. Cut it. Break it.", 22, DIM)
	var parade_top := y
	var m := Achv.load_store()
	var first_time := not JS.truthy(m.get("guided")) and not JS.truthy(m.get("runs"))
	_button("play", "PLAY  \u00b7  first round" if first_time else "PLAY", true, func():
		if first_time:
			guided.emit()
		else:
			go("road"))
	_button("peddler", "Peddler", false, func(): go("peddler"))
	var stack := ["play", "peddler"]   # PLAY lowest, in the thumb zone
	if can_resume:
		# a run in progress: CONTINUE is the main action; PLAY starts a new one
		_button("resume", "CONTINUE", true, func(): resume_run.emit())
		buttons["play"].text = "NEW RUN"
		stack = ["resume", "play", "peddler"]
	var top := _stack_bottom(stack)
	var c := _col()
	var l := _label(_page, RunRecord.line(), 16, DIM, Vector2(c.x, 0), c.y)
	l.position.y = minf(top - l.size.y - 8.0, _bottom())
	l.name = "line"
	# the parade: all six, bobbing out of step, sized to the space above the buttons
	var c0 := _col()
	var room := maxf(0.0, l.position.y - 16.0 - (parade_top + 24.0))
	var per := minf(c0.y / 3.0, room / 1.92)
	var px0 := (size.x - per * 3.0) / 2.0
	parade.clear()
	for k in MeldReact.SIGNATURE.size():
		var id: String = MeldReact.SIGNATURE.keys()[k]
		var sp := MeldSprite.new(id)
		sp.size = Vector2(per, per)
		sp.position = Vector2(px0 + (k % 3) * per, parade_top + 24.0 + floorf(k / 3.0) * per * 0.92)
		sp.step(k * 0.43)                 # out of step, so they don't bob as one
		_page.add_child(sp)
		parade.append(sp)


# ------------------------------------------------------------------ road
func _road() -> void:
	_clear()
	var y := _header("STEP ONE", "CHOOSE YOUR ROAD")
	var dk := _day()
	var done_today = Achv.daily_done(dk)
	var streak := Achv.daily_streak()
	var done_n := Meta.TRIALS.filter(func(t): return Achv.trial_done(t.id)).size()
	var long_road := Achv.has("long_road")
	var roads := [
		{"id": "daily", "name": "The Daily",
			"note": ("Done: reached %d. Come back tomorrow." % int(done_today.reached)) if done_today != null
				else "Everyone gets the same deck today. One attempt.%s" % (("  Streak %d." % streak) if streak else "")},
		{"id": "run", "name": "The Five Acts", "note": "Twenty-five rounds. Five Spoilers. The road as it was meant."},
		{"id": "trial", "name": "Trials", "note": "One rule taken to its limit. %d of %d done." % [done_n, Meta.TRIALS.size()]},
		{"id": "endless", "name": "The Long Count",
			"note": ("No ceiling. Best round %d." % Achv.best_endless()) if long_road else "Locked. Clear the Five Acts first."},
	]
	for r in roads:
		var open: bool = (r.id != "endless" or long_road) and (r.id != "daily" or done_today == null)
		y = _card(r.id, y, r.name, r.note, open, _pick_road.bind(r.id))
	_button("back", "Back", false, func(): go("title"))
	_stack_bottom(["back"])


func _pick_road(id: String) -> void:
	cb.mode = id
	if id == "daily":
		# fixed deck, fixed Meldling, one attempt
		var dk := _day()
		var seed := Meta.daily_seed(dk)
		var decks := ["pip", "thump", "clover", "facet"]
		var run := CribRun.new(decks[seed % decks.size()], Meta.STREETS[0], null, seed)
		run.daily = dk
		cb.step = "road"
		begin.emit(run)
		return
	go("trial" if id == "trial" else ("meld" if id == "endless" else "street"))


# ------------------------------------------------------------------ street
func _street() -> void:
	_clear()
	var y := _header("STEP TWO", "HOW HARD")
	var max_street := Achv.street_unlocked()
	if cb.street == null or int(cb.street.id) > max_street:
		cb.street = Meta.STREETS[0]
	var i := Meta.STREETS.find(cb.street)
	var c := _col()
	var face_y := y
	y = _line(y, ROMAN[i], 44, INK)
	y = _line(y, cb.street.name, 26, GOLD)
	y = _line(y, cb.street.text, 18, DIM)
	# the steppers sit either side of the face, big enough for a thumb
	var prev := Button.new()
	prev.text = "<"
	prev.add_theme_font_size_override("font_size", 34)
	prev.disabled = i == 0
	prev.size = Vector2(72, 72)
	prev.position = Vector2(c.x, face_y + 6.0)
	prev.pressed.connect(func():
		cb.street = Meta.STREETS[maxi(0, i - 1)]
		render())
	_page.add_child(prev)
	buttons["prev"] = prev
	var next := Button.new()
	next.text = ">"
	next.add_theme_font_size_override("font_size", 34)
	next.disabled = i >= max_street - 1
	next.size = Vector2(72, 72)
	next.position = Vector2(c.x + c.y - 72.0, face_y + 6.0)
	next.pressed.connect(func():
		cb.street = Meta.STREETS[mini(max_street - 1, i + 1)]
		render())
	_page.add_child(next)
	buttons["next"] = next
	# one pip per Street: the current one gold, locked ones dim
	var n := Meta.STREETS.size()
	var pw := 14.0
	var x0 := (size.x - (n * pw + (n - 1) * 10.0)) / 2.0
	for k in n:
		var d := ColorRect.new()
		d.color = GOLD if k == i else (Color(INK, 0.15) if k >= max_street else Color(INK, 0.45))
		d.size = Vector2(pw, pw)
		d.position = Vector2(x0 + k * (pw + 10.0), y + 6.0)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_page.add_child(d)
	y += 32.0
	if max_street < Meta.STREETS.size():
		y = _line(y, "Clear %s to open the next." % Meta.STREETS[max_street - 1].name, 16, DIM)
	_button("continue", "CONTINUE", true, func(): go("meld"))
	_button("back", "Back", false, func(): go("road"))
	_stack_bottom(["back", "continue"])


# ------------------------------------------------------------------ trial
func _trial() -> void:
	_clear()
	var y := _header("STEP TWO", "PICK A TRIAL")
	_button("back", "Back", false, func(): go("road"))
	var limit := _stack_bottom(["back"])
	# eight Trials: compact cards, and a scroll only if a short screen needs it
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(0, y)
	scroll.size = Vector2(size.x, limit - y)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_page.add_child(scroll)
	var inner := Control.new()
	scroll.add_child(inner)
	var hold := _page
	_page = inner
	var yy := 0.0
	for k in Meta.TRIALS.size():
		var t: Dictionary = Meta.TRIALS[k]
		var done := Achv.trial_done(t.id)
		yy = _card("trial_%d" % k, yy, t.name + ("  (done)" if done else ""), t.text, true, _pick_trial.bind(k))
	_page = hold
	inner.custom_minimum_size = Vector2(size.x, yy)


func _pick_trial(k: int) -> void:
	var t: Dictionary = Meta.TRIALS[k]
	var run := CribRun.new(t.deck, Meta.STREETS[0], t)
	cb.step = "road"
	begin.emit(run)


# ------------------------------------------------------------------ meld
func _meld() -> void:
	_clear()
	var y := _header("STEP THREE", "YOUR MELDLING")
	var ids: Array = CribData.DECKS.keys()
	cb.meld_idx = posmod(int(cb.meld_idx), ids.size())
	var id: String = ids[cb.meld_idx]
	var d: Dictionary = CribData.DECKS[id]
	var open := Achv.meldling_unlocked(id)
	var c := _col()
	var face_y := y
	# the Meldling itself; a locked one is a silhouette
	var px := minf(c.y - 160.0, 300.0)
	meld_view = MeldSprite.new(id)
	meld_view.size = Vector2(px, px)
	meld_view.position = Vector2((size.x - px) / 2.0, y)
	_page.add_child(meld_view)
	meld_view.set_meld(id, not open)
	if open:
		meld_view.react("eager")
	face_y = y + px / 2.0 - 36.0
	y += px
	y = _line(y + 4.0, d.name if open else "???", 40, GOLD if open else DIM)
	for pair in [["prev", -1, c.x], ["next", 1, c.x + c.y - 72.0]]:
		var b := Button.new()
		b.text = "<" if pair[1] < 0 else ">"
		b.add_theme_font_size_override("font_size", 34)
		b.size = Vector2(72, 72)
		b.position = Vector2(pair[2], face_y)
		var step: int = pair[1]
		b.pressed.connect(func():
			cb.meld_idx = int(cb.meld_idx) + step
			render())
		_page.add_child(b)
		buttons[pair[0]] = b
	var info := ""
	if open:
		info = d.text
	elif d.get("ascended", false):
		info = "Locked. Clear a run with %s." % CribData.DECKS[d.art].name
	else:
		var req = null
		for a in Meta.ACHIEVEMENTS:
			if a.id == Meta.MELDLING_UNLOCKS.get(id):
				req = a
		info = ("Locked: %s" % req.name) if req != null else "Locked."
	var pnl := Panel.new()
	pnl.add_theme_stylebox_override("panel", _box(PANEL, Color(INK, 0.12)))
	pnl.position = Vector2(c.x, y + 8.0)
	_page.add_child(pnl)
	var l := _label(pnl, info, 20, INK if open else DIM, Vector2(16, 12), c.y - 32.0)
	pnl.size = Vector2(c.y, l.size.y + 24.0)
	pnl.name = "info"
	y = pnl.position.y + pnl.size.y + 14.0
	var n := ids.size()
	var x0 := (size.x - (n * 12.0 + (n - 1) * 8.0)) / 2.0
	for k in n:
		var dot := ColorRect.new()
		dot.color = GOLD if k == cb.meld_idx else Color(INK, 0.3)
		dot.size = Vector2(12, 12)
		dot.position = Vector2(x0 + k * 20.0, y)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_page.add_child(dot)
	var go_b := _button("begin", "BEGIN", true, _begin_meld.bind(id))
	go_b.disabled = not open
	_button("back", "Back", false, func(): go("road" if cb.mode == "endless" else "street"))
	_stack_bottom(["back", "begin"])


func _begin_meld(id: String) -> void:
	var run := CribRun.new(id, cb.street if cb.street != null else Meta.STREETS[0])
	if cb.mode == "endless":
		run.enter_endless()
		run.endless_round = 0
	cb.step = "road"
	begin.emit(run)


# ------------------------------------------------------------------ peddler
## Web showPeddler: card backs for Pegs. Tap an owned back to equip it; tap
## an unowned one to buy and equip it, if the Pegs cover it.
var last_tap := ""            ## "equip" / "buy" / "short", for tests
var _flash: Label
var _flash_pending := false  ## show "Not enough Pegs" once, on the render after the tap


func _peddler() -> void:
	_clear()
	var y := _line(_top(), "THE PEDDLER", 34, INK)
	y = _line(y, "%d Pegs" % Achv.pegs(), 26, GOLD)
	y = _line(y, "Pegs are earned for how far you get, not for grinding. They stay with your profile.", 17, DIM)
	y = _line(y + 6.0, "CARD BACKS  \u00b7  tap to equip", 18, GOLD)
	var c := _col()
	var cols := 3
	var gap := 12.0
	var sw := (c.y - gap * (cols - 1)) / cols
	var art := Vector2(70, 98) * minf(2.0, (sw - 20.0) / 70.0)
	var sh := art.y + 76.0
	for i in Meta.CARD_BACKS.size():
		var b: Dictionary = Meta.CARD_BACKS[i]
		var owned := Achv.owns_back(b.id)
		var active: bool = Achv.active_back() == b.id
		var slot := Button.new()
		slot.add_theme_stylebox_override("normal", _box(PANEL, GOLD if active else Color(INK, 0.14)))
		slot.add_theme_stylebox_override("hover", _box(PANEL.lightened(0.06), GOLD if active else Color(GOLD, 0.5)))
		slot.add_theme_stylebox_override("pressed", _box(PANEL.lightened(0.1), GOLD))
		slot.position = Vector2(c.x + (i % cols) * (sw + gap), y + int(i / cols) * (sh + gap))
		slot.size = Vector2(sw, sh)
		_page.add_child(slot)
		var img := TextureRect.new()
		img.texture = load("res://assets/cards/back_%s.png" % b.id)
		img.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.size = art
		img.position = Vector2((sw - art.x) / 2.0, 10.0)
		img.modulate = Color.WHITE if owned else Color(1, 1, 1, 0.45)
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(img)
		_label(slot, b.name, 18, INK, Vector2(0, art.y + 16.0), sw)
		_label(slot, ("EQUIPPED" if active else "owned") if owned else "%d Pegs" % b.cost, 15,
			Color(0.43, 0.79, 0.54) if owned else GOLD, Vector2(0, art.y + 44.0), sw)
		slot.pressed.connect(_tap_back.bind(b.id))
		buttons["back_" + b.id] = slot
	# web: Back goes to the select steps (showCribSelect), not the title
	_button("back", "Back", false, func(): go("road" if cb.step in ["title", "peddler"] else cb.step))
	_stack_bottom(["back"])
	if _flash_pending:
		_flash_pending = false
		_flash = _label(_page, "Not enough Pegs", 22, GOLD, Vector2(c.x, 0), c.y)
		_flash.position.y = buttons["back"].position.y - _flash.size.y - 16.0
		var tw := _flash.create_tween()
		tw.tween_interval(1.2)
		tw.tween_property(_flash, "modulate:a", 0.0, 0.4)


func _tap_back(id: String) -> void:
	if Achv.owns_back(id):
		Achv.set_back(id)
		last_tap = "equip"
	elif Achv.buy_back(id):
		Achv.set_back(id)
		last_tap = "buy"
	else:
		last_tap = "short"
	_flash_pending = last_tap == "short"
	render()
