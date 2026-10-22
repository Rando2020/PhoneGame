class_name Menus
extends RefCounted
## The front door's other screens, as FrontDoor steps (they share its felt, its
## menu music, its press feedback and 44 pt buttons):
##   deeds     web showDeeds     (cribrogue_ui.js)
##   record    web showHistory   (lost runs read "Fell A-R")
##   gallery   web showGallery   (gallery.js; Meldlings 2.0 and Spoiler art, every pose)
##   howto     web showTutorial  (tutorial.js, six beats)
##   settings  sound, volume, Reduce Motion, count speed (saved)
## Texts follow the web's word for word and in its order: tests/menus_test.gd
## compares them against fixtures rendered from the web (tools/parity/gen_menus.js).
## Back returns to the title (the web went to the run choices).

const GAL_TABS := [["charms", "Charms"], ["cards", "Cards"], ["split", "Split"], ["marks", "Marks"],
	["backs", "Backs"], ["meld", "Meldlings"], ["spoil", "Spoilers"]]
const GAL_PER_ROW := 4          ## tabs a row (7 tabs: 4 + 3, two rows of 44 pt)

## How to play: the web's six beats. art: a Meldling id, or a Spoiler art id
## (kingpin), drawn with the new art.
const TUT_STEPS := [
	{"title": "Six cards, keep four",
		"body": "You're dealt six. Choose the four you'll count and tap them. The other two are thrown to your Crib.",
		"art": "pip", "anchor": "hand"},
	{"title": "Then the cut decides",
		"body": "Only after you commit is a fifth card cut. It joins your four for the count, so keep for what's LIKELY, not what's certain.",
		"art": "facet", "anchor": "cut"},
	{"title": "The Crib is yours",
		"body": "Your first four thrown cards form the Crib. It scores for you at the end of the round. Feeding it well is a second skill.",
		"art": "muggins", "anchor": "crib"},
	{"title": "Counting",
		"body": "Every pair of cards adding to fifteen scores 2. Pairs score 2. Runs of three or more score their length. Flushes and his-nobs score too.",
		"art": "thump", "anchor": "count"},
	{"title": "Charms and Marks",
		"body": "Charms multiply your count. Marks sit on individual cards. Buy both at the Peg House between rounds. You have five charm slots, so choose.",
		"art": "clover", "anchor": "shop"},
	{"title": "Spoilers",
		"body": "Every third round is a Spoiler with a rule that breaks something. You can see all five at the start of a run. Build for them.",
		"art": "kingpin", "anchor": "boss"},
	# native only (the web has no drag): after the web's six, so those match it
	{"title": "Drag or tap",
		"body": "Tap a card, or drag it. Flick a card up toward the Crib to throw it, or down to keep it. In The Play, flick a card up onto the pile to lay it.",
		"art": "nib", "anchor": "drag"},
	{"title": "The Play",
		"body": "After each count, you and the Spoiler lay cards in turn, the total climbing toward 31. Make it exactly 15 or 31 for 2. Pairs and runs on the pile score too, and what you peg rides your multiplier.",
		"art": "pip", "anchor": "play"},
]
const WEB_TUT_STEPS := 6       ## the first six are the web's, word for word

static var gal_tab := "cards"
static var tut_step := 0


# ------------------------------------------------------------------ layout
## A scrolling column between the header (y) and the Back button.
static func _scroll(fd: FrontDoor, y: float, back_to := "title") -> Control:
	fd._button("back", "Back", false, func(): fd.go(back_to))
	var limit := fd._stack_bottom(["back"])
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(0, y)
	scroll.size = Vector2(fd.size.x, maxf(80.0, limit - 8.0 - y))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.name = "scroll"
	fd._page.add_child(scroll)
	var inner := Control.new()
	inner.name = "inner"
	scroll.add_child(inner)
	return inner


static func _lab(fd: FrontDoor, parent: Control, text: String, fs: int, col: Color, x: float, y: float, w: float,
		align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	return fd._label(parent, text, fs, col, Vector2(x, y), w, align)


static func _done(inner: Control, fd: FrontDoor, y: float) -> void:
	inner.custom_minimum_size = Vector2(fd.size.x, y + 12.0)


# ------------------------------------------------------------------ deeds
static func deeds(fd: FrontDoor) -> void:
	fd._clear()
	var y := fd._line(fd._top(), "DEEDS", 34, fd.INK)
	y = fd._line(y, "%d of %d earned" % [Achv.count(), Meta.ACHIEVEMENTS.size()], 18, fd.DIM) + 6.0
	var inner := _scroll(fd, y)
	var c := fd._col()
	var yy := 0.0
	for a in Meta.ACHIEVEMENTS:
		var got := Achv.has(a.id)
		var secret: bool = JS.truthy(a.get("secret"))
		var row := Panel.new()
		row.add_theme_stylebox_override("panel", fd._box(fd.PANEL if got else fd.PANEL.darkened(0.2), Color(fd.GOLD, 0.5) if got else Color(fd.INK, 0.08)))
		row.position = Vector2(c.x, yy)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(row)
		_lab(fd, row, "✔" if got else "·", 26, fd.GOLD if got else fd.DIM, 14, 14, 30)
		var n := _lab(fd, row, a.name if (got or not secret) else "???", TypeScale.BODY, fd.GOLD if got else fd.DIM, 52, 10, c.y - 70.0)
		var t := _lab(fd, row, a.text if (got or not secret) else "A hidden deed.", TypeScale.BODY, fd.DIM, 52, 14 + n.size.y, c.y - 70.0)
		row.size = Vector2(c.y, t.position.y + t.size.y + 12.0)
		yy += row.size.y + 8.0
	_done(inner, fd, yy)


# ------------------------------------------------------------------ record
static func record(fd: FrontDoor) -> void:
	fd._clear()
	var y := fd._line(fd._top(), "THE RECORD", 34, fd.INK) + 6.0
	var inner := _scroll(fd, y)
	var c := fd._col()
	var yy := 0.0
	var stats := Achv.deck_stats()
	var keys: Array = stats.keys()
	if not keys.is_empty():
		yy = _section(fd, inner, yy, "BY MELDLING", "average act reached")
		# the web sorts by avg, highest first; ties keep their order (a stable sort)
		var order: Array = range(keys.size())
		order.sort_custom(func(a, b):
			var fa := float(stats[keys[a]].avg)
			var fb := float(stats[keys[b]].avg)
			return fa > fb if fa != fb else a < b)
		for i in order:
			var k: String = keys[i]
			var d: Dictionary = stats[k]
			var w := c.y / 4.0
			var sp := MeldSprite.new(k)
			sp.size = Vector2(56, 56)
			sp.position = Vector2(c.x - 4.0, yy - 10.0)
			inner.add_child(sp)
			var name: String = CribData.DECKS[k].name if CribData.DECKS.has(k) else k
			_lab(fd, inner, name, 22, fd.GOLD, c.x + 56.0, yy, w)
			_lab(fd, inner, "%d run%s" % [d.runs, "" if d.runs == 1 else "s"], 17, fd.DIM, c.x + w + 24.0, yy + 4.0, w)
			_lab(fd, inner, "avg %s" % d.avg, 17, fd.INK, c.x + w * 2.0, yy + 4.0, w)
			_lab(fd, inner, "best %d" % d.best, 17, Color(0.43, 0.79, 0.54), c.x + w * 3.0, yy + 4.0, w, HORIZONTAL_ALIGNMENT_RIGHT)
			yy += 52.0
	yy = _section(fd, inner, yy + 6.0, "LAST TEN", "")
	var h := Achv.history()
	if h.is_empty():
		yy = _lab(fd, inner, "No runs recorded yet.", 18, fd.DIM, c.x, yy, c.y).position.y + 32.0
	for r in h:
		var cleared: bool = JS.truthy(r.get("cleared"))
		var reached := int(r.reached)
		var at := reached if cleared else reached + 1      # a lost run reads the round it fell on
		var act := maxi(1, int(ceil(at / float(CribData.ROUNDS))))
		var rd := (maxi(1, at) - 1) % CribData.ROUNDS + 1
		var w := c.y / 3.0
		var deck := String(r.deck)
		_lab(fd, inner, CribData.DECKS[deck].name if CribData.DECKS.has(deck) else deck, 18, fd.INK, c.x, yy, w)
		_lab(fd, inner, Meta.STREETS[int(r.street) - 1].name, 17, fd.DIM, c.x + w, yy, w)
		_lab(fd, inner, "CLEARED" if cleared else "Fell %d-%d" % [act, rd], 18, fd.GOLD if cleared else fd.INK, c.x + w * 2.0, yy, w, HORIZONTAL_ALIGNMENT_RIGHT)
		yy += 40.0
	_done(inner, fd, yy)


static func _section(fd: FrontDoor, parent: Control, y: float, title: String, note: String) -> float:
	var c := fd._col()
	var t := _lab(fd, parent, title, 18, fd.GOLD, c.x, y, c.y * 0.6)
	if note != "":
		_lab(fd, parent, note, 15, fd.DIM, c.x + c.y * 0.4, y + 2.0, c.y * 0.6, HORIZONTAL_ALIGNMENT_RIGHT)
	return y + t.size.y + 10.0


# ------------------------------------------------------------------ gallery
static func gallery(fd: FrontDoor) -> void:
	fd._clear()
	var y := fd._line(fd._top(), "THE GALLERY", 34, fd.INK)
	# tabs: two rows (4 + 3), each 44 pt
	var c := fd._col()
	var tw := (c.y - 8.0 * (GAL_PER_ROW - 1)) / GAL_PER_ROW
	for i in GAL_TABS.size():
		var tab: Array = GAL_TABS[i]
		var b := Button.new()
		b.text = tab[1]
		b.toggle_mode = true
		b.button_pressed = gal_tab == tab[0]
		TypeScale.set_size(b, 20)
		b.size = Vector2(tw, Press.MIN_H)
		b.position = Vector2(c.x + (i % GAL_PER_ROW) * (tw + 8.0), y + floorf(i / float(GAL_PER_ROW)) * (Press.MIN_H + 8.0))
		var id: String = tab[0]
		b.pressed.connect(func():
			gal_tab = id
			Sound.play("tab")
			_gal_switch(fd))
		fd._page.add_child(b)
		fd.buttons["tab_" + id] = b
	y += ceilf(GAL_TABS.size() / float(GAL_PER_ROW)) * (Press.MIN_H + 8.0) + 6.0
	var inner := _scroll(fd, y)
	_gal_fill(fd, inner)


## A tab tap: only the list changes (the title, tabs and Back stay), so the tap
## frame does no more than clear the old list; its rows arrive from the next.
static func _gal_switch(fd: FrontDoor) -> void:
	var inner: Control = fd._page.find_child("inner", true, false)
	if inner == null:
		fd.render()
		return
	for k in fd.buttons:
		if String(k).begins_with("tab_"):
			(fd.buttons[k] as Button).set_pressed_no_signal(String(k) == "tab_" + gal_tab)
	for ch in inner.get_children():
		inner.remove_child(ch)
		ch.queue_free()
	var sc := inner.get_parent() as ScrollContainer
	if sc != null:
		sc.scroll_vertical = 0
	_gal_fill(fd, inner)


static func _gal_fill(fd: FrontDoor, inner: Control) -> void:
	var tab: Array
	match gal_tab:
		"cards": tab = _gal_cards(fd, inner)
		"split": tab = _gal_split(fd, inner)
		"marks": tab = _gal_marks(fd, inner)
		"backs": tab = _gal_backs(fd, inner)
		"meld": tab = _gal_meld(fd, inner)
		"charms": tab = _gal_charms(fd, inner)
		_: tab = _gal_spoil(fd, inner)
	fd.queue_rows(tab[1], tab[0], func(yy: float): _done(inner, fd, yy))


static func _note(fd: FrontDoor, parent: Control, y: float, txt: String) -> float:
	var c := fd._col()
	return _lab(fd, parent, txt, 17, fd.DIM, c.x, y, c.y).size.y + y + 10.0


static func _card_at(parent: Control, card: Dictionary, sc: float, at: Vector2) -> CardView:
	var v := CardView.new()
	parent.add_child(v)
	v.setup_card(card, true)
	v.scale = Vector2(sc, sc)
	# CardView scales about its centre: offset so the drawn card's top-left is `at`
	v.position = at - v.size * (1.0 - sc) / 2.0
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


## Each tab: [y after the note, rows]. A row is func(y) -> y below it; the
## FrontDoor builds rows over frames on a time budget (FrontDoor.queue_rows),
## so a long tab never stops a frame. Same rows, same layout as building at once.
static func _gal_cards(fd: FrontDoor, box: Control) -> Array:
	var y := _note(fd, box, 0.0, "All 52 faces. Every card in the game is generated, not drawn by hand.")
	var c := fd._col()
	var cw := CardArt.BASE_W * CardView.PIXEL_SCALE
	var ch := CardArt.BASE_H * CardView.PIXEL_SCALE
	var per := 7
	var sc := minf(0.62, (c.y / per - 6.0) / cw)
	var rows := []
	for suit in ["S", "H", "C", "D"]:
		rows.append(func(yy: float) -> float:
			yy = _lab(fd, box, "%s  %s" % [Cribbage.SUIT_SYM[suit], {"S": "Spades", "H": "Hearts", "C": "Clubs", "D": "Diamonds"}[suit]], 18, fd.GOLD, c.x, yy, c.y).size.y + yy + 6.0
			for r in range(1, 14):
				var k := r - 1
				_card_at(box, {"rank": r, "suit": suit}, sc, Vector2(c.x + (k % per) * (cw * sc + 6.0), yy + floorf(k / float(per)) * (ch * sc + 6.0)))
			return yy + 2.0 * (ch * sc + 6.0) + 8.0)
	return [y, rows]


## The charm collection (pass 19): all of them, by category. Unseen charms are
## a dark silhouette with no name; seen ones dim; owned ones full; won-with
## ones carry a gold WON tag. The header counts are real.
const CHARM_CATS := [["fifteen", "Fifteens"], ["pair", "Pairs"], ["run", "Runs"], ["flush", "Flushes"],
	["mult", "Multipliers"], ["rule", "Rules"], ["deck", "Deck"]]
static var charm_cells: Array = []     ## [{id, level, icon, name}] (tests)


## Gallery reveals (pass 21): charms that rose since the tab was last shown
## flip from their old look (silhouette or dimmed) to the new one, 60 ms apart,
## the first time only. "Shown" levels are saved; a first visit ever just
## records them (nothing to compare against, so no flips).
static var gal_motion := Motion.new()
static var _shown_before := {}
static var _reveal_n := 0
static var revealed: Array = []          ## ids flipped this visit (tests)


static func _gal_charms(fd: FrontDoor, box: Control) -> Array:
	charm_cells.clear()
	gal_motion.skip()
	revealed = []
	_reveal_n = 0
	var store := Achv.load_store()
	var first_visit := not store.has("charms_shown")
	_shown_before = {} if first_visit else store.get("charms_shown", {}).duplicate()
	var now := {}
	for ch in CribData.CHARMS:
		now[ch.id] = Collection.level(ch.id)
	var m := store.duplicate(true)
	m["charms_shown"] = now
	Achv.save_store(m)
	# a first visit (no "charms_shown" yet): _shown_before is empty, and a charm
	# with no shown level counts as shown at its own level, so nothing flips
	var c := fd._col()
	var have := Collection.count(Collection.OWNED)
	var head := _lab(fd, box, "Charms %d / %d" % [have, Collection.total()], 26, fd.GOLD, c.x, 0.0, c.y)
	var y := head.size.y + 4.0
	y = _note(fd, box, y, "Seen %d  ·  owned %d  ·  ★ won a run with %d. A charm counts once you've bought it." % [
		Collection.count(Collection.SEEN), have, Collection.count(Collection.WON)])
	var per := 4          # 5 a row broke "Quartermaster" mid-word at the text floor
	var cell := (c.y - 8.0 * (per - 1)) / per
	var icon_px := minf(88.0, cell - 8.0)
	var rows := []
	for cat in CHARM_CATS:
		var list: Array = CribData.CHARMS.filter(func(ch): return ch.get("cat") == cat[0])
		if list.is_empty():
			continue
		var owned_here := list.filter(func(ch): return Collection.level(ch.id) >= Collection.OWNED).size()
		rows.append(func(yy: float) -> float:
			return _lab(fd, box, "%s  %d / %d" % [cat[1], owned_here, list.size()], 18, fd.GOLD, c.x, yy, c.y).size.y + yy + 6.0)
		for r0 in range(0, list.size(), per):
			var chunk: Array = list.slice(r0, r0 + per)
			rows.append(func(yy: float) -> float:
				var tallest := 0.0
				for k in chunk.size():
					var ch: Charm = chunk[k]
					var lv := Collection.level(ch.id)
					var x := c.x + k * (cell + 8.0)
					# unseen: the category's silhouette only (not which charm, not how rare)
					var ic: TextureRect = CharmIcon.silhouette(ch.cat, icon_px) if lv == Collection.UNSEEN else CharmIcon.make(ch.id, icon_px)
					if ic != null:
						ic.position = Vector2(x + (cell - icon_px) / 2.0, yy)
						if lv == Collection.SEEN:
							ic.modulate = Color(1, 1, 1, 0.45)
						box.add_child(ic)
					# won with: the name in gold with a star (no badge over the art)
					var label := "???" if lv == Collection.UNSEEN else (("★ " + ch.name) if lv == Collection.WON else ch.name)
					var col: Color = fd.GOLD if lv == Collection.WON else (fd.INK if lv == Collection.OWNED else fd.DIM)
					var nm := _lab(fd, box, label, 15, col, x, yy + icon_px + 2.0, cell, HORIZONTAL_ALIGNMENT_CENTER)
					var h := icon_px + 2.0 + nm.size.y
					charm_cells.append({"id": ch.id, "level": lv, "icon": ic, "name": nm})
					var was: int = int(_shown_before.get(ch.id, lv))
					if ic != null and lv > was:
						_reveal(box, ic, nm, ch, was, icon_px)
					tallest = maxf(tallest, h)
				return yy + tallest + 10.0)
	return [y, rows]


## One reveal: the old look closes (scale x 1 -> 0), the new opens (0 -> 1).
## Reduce Motion: the new look fades in. Ends exactly on the at-rest cell.
static func _reveal(box: Control, ic: TextureRect, nm: Label, ch: Charm, was: int, px: float) -> void:
	revealed.append(ch.id)
	if not Motion.on():
		return
	if Motion.reduced():
		gal_motion.fade_in(ic)
		return
	var old: TextureRect = CharmIcon.silhouette(ch.cat, px) if was == Collection.UNSEEN else CharmIcon.make(ch.id, px)
	if was == Collection.SEEN:
		old.modulate = Color(1, 1, 1, 0.45)
	old.position = ic.position
	box.add_child(old)
	var rest_m := ic.modulate
	var delay := 0.06 * _reveal_n
	_reveal_n += 1
	ic.pivot_offset = ic.size / 2.0
	old.pivot_offset = old.size / 2.0
	ic.scale = Vector2(0.0, 1.0)
	var tw := ic.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(old, "scale", Vector2(0.0, 1.0), 0.12).set_ease(Tween.EASE_IN)
	tw.tween_property(ic, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	gal_motion.add(tw, func():
		if is_instance_valid(ic):
			ic.scale = Vector2.ONE
			ic.modulate = rest_m
		if is_instance_valid(old):
			old.queue_free())


static func _gal_split(fd: FrontDoor, box: Control) -> Array:
	var y := _note(fd, box, 0.0, "Split cards count as either rank. Four shared images compose all 2,704 combinations. Nothing here is a pre-rendered asset.")
	var c := fd._col()
	var samples := [[2, 3, "H", "H"], [1, 13, "S", "D"], [10, 11, "C", "C"], [5, 9, "D", "S"],
		[7, 8, "H", "S"], [4, 12, "C", "H"], [6, 6, "D", "D"], [3, 10, "S", "C"]]
	var cw := CardArt.BASE_W * CardView.PIXEL_SCALE
	var ch := CardArt.BASE_H * CardView.PIXEL_SCALE
	var sc := minf(0.72, (c.y / 4.0 - 10.0) / cw)
	var rows := []
	for half in 2:
		rows.append(func(yy: float) -> float:
			for j in 4:
				var i := half * 4 + j
				var s: Array = samples[i]
				var at := Vector2(c.x + j * (c.y / 4.0), yy)
				_card_at(box, {"rank": s[0], "rank2": s[1], "suit": s[2], "suit2": s[3]}, sc, at)
				_lab(fd, box, "%s/%s" % [Cribbage.RANK_LABEL[s[0]], Cribbage.RANK_LABEL[s[1]]], 15, fd.DIM, at.x, at.y + ch * sc + 4.0, cw * sc, HORIZONTAL_ALIGNMENT_CENTER)
			return yy + ch * sc + 40.0)
	rows.append(func(yy: float) -> float:
		yy = _lab(fd, box, "How it scores", 18, fd.GOLD, c.x, yy, c.y).size.y + yy + 6.0
		return _note(fd, box, yy, "A hand of [2/3] 4 5 10 with a 6 cut scores 8: the split takes the 3 to complete a run of four. Held as a 2 it would score 7."))
	return [y, rows]


static func _gal_marks(fd: FrontDoor, box: Control) -> Array:
	var y := _note(fd, box, 0.0, "Marks sit on individual cards and change what they do.")
	var c := fd._col()
	var ch := CardArt.BASE_H * CardView.PIXEL_SCALE * 0.6
	var rows := []
	for k in CribData.ENHANCEMENTS:
		var m: Dictionary = CribData.ENHANCEMENTS[k]
		rows.append(func(yy: float) -> float:
			_card_at(box, {"rank": 5, "suit": "H", "enh": k}, 0.6, Vector2(c.x, yy))
			var n := _lab(fd, box, m.name, TypeScale.BODY, fd.GOLD, c.x + 110.0, yy + 6.0, c.y - 110.0)
			var mt := _lab(fd, box, m.text, TypeScale.BODY, fd.DIM, c.x + 110.0, yy + 10.0 + n.size.y, c.y - 110.0)
			return maxf(yy + maxf(ch, 70.0) + 12.0, mt.position.y + mt.size.y + 12.0))
	return [y, rows]


static func _gal_backs(fd: FrontDoor, box: Control) -> Array:
	var y := _note(fd, box, 0.0, "Card backs, bought from the Peddler with Pegs. Tap an owned back to equip it.")
	var c := fd._col()
	var per := 3
	var w := c.y / per
	var rows := []
	var n_rows := ceili(Meta.CARD_BACKS.size() / float(per))
	for r in n_rows:
		rows.append(func(yy: float) -> float:
			for j in per:
				var i := r * per + j
				if i >= Meta.CARD_BACKS.size():
					break
				_back_cell(fd, box, Meta.CARD_BACKS[i], Vector2(c.x + j * w, yy), w)
			return yy + 190.0)
	return [y, rows]


static func _back_cell(fd: FrontDoor, box: Control, b: Dictionary, at: Vector2, w: float) -> void:
	var owned := Achv.owns_back(b.id)
	var cell := Control.new()
	cell.position = at
	cell.size = Vector2(w - 8.0, 180.0)
	cell.name = "back_" + String(b.id)
	box.add_child(cell)
	var img := TextureRect.new()
	var bp := CardArt.DIR + "back_%s.png" % b.id
	img.texture = load(bp) if ResourceLoader.exists(bp) else null
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.size = Vector2(w - 8.0, 140.0)
	img.modulate = Color.WHITE if owned else Color(0.3, 0.3, 0.35, 0.8)
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(img)
	var on := Achv.active_back() == String(b.id)
	_lab(fd, cell, String(b.name) if owned else "%d Pegs" % b.cost, 16, fd.GOLD if owned else fd.DIM, 0, 146, w - 8.0, HORIZONTAL_ALIGNMENT_CENTER)
	if on:
		var ring := ReferenceRect.new()
		ring.border_color = fd.GOLD
		ring.border_width = 3.0
		ring.editor_only = false
		ring.size = img.size
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(ring)
	if owned:
		var id := String(b.id)
		cell.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				Achv.set_back(id)
				Sound.play("select")
				fd.render())


static func _gal_meld(fd: FrontDoor, box: Control) -> Array:
	var y := _note(fd, box, 0.0, "Six Meldlings. Two are earned.")
	var c := fd._col()
	var rows := []
	for id in CribData.DECKS:
		rows.append(func(yy: float) -> float:
			var d: Dictionary = CribData.DECKS[id]
			var open := Achv.meldling_unlocked(id)
			var sp := MeldSprite.new(id)
			sp.size = Vector2(96, 96)
			sp.position = Vector2(c.x, yy)
			box.add_child(sp)
			sp.set_meld(id, not open)
			var n := _lab(fd, box, ("%s %s" % [d.name, Cribbage.SUIT_SYM.get(d.suit, "")]) if open else "???", TypeScale.BODY, fd.GOLD if open else fd.DIM, c.x + 108.0, yy + 4.0, c.y - 108.0)
			var t := _lab(fd, box, d.text if open else "Locked.", TypeScale.BODY, fd.DIM, c.x + 108.0, yy + 8.0 + n.size.y, c.y - 108.0)
			return maxf(yy + 100.0, t.position.y + t.size.y + 8.0))
		rows.append(func(yy: float) -> float:
			var open := Achv.meldling_unlocked(id)
			# every pose, in a strip (a silhouette while locked)
			var art := MeldReact.art_id(id)
			var poses: Array = MeldReact.POSES + [MeldReact.SIGNATURE[art]]
			var pw := minf(72.0, c.y / poses.size())
			for k in poses.size():
				var ps := MeldSprite.new(id)
				ps.size = Vector2(pw, pw)
				ps.position = Vector2(c.x + k * pw, yy)
				box.add_child(ps)
				ps.set_meld(id, not open)
				if open:
					ps.pose = poses[k]
					ps._show()
			return yy + pw + 14.0)
	return [y, rows]


static func _gal_spoil(fd: FrontDoor, box: Control) -> Array:
	var y := _note(fd, box, 0.0, "All %d Spoilers. Five are drawn per run, so no two runs meet the same set." % CribData.BOSS_POOL.size())
	var c := fd._col()
	var rows := []
	for sev in [1, 2, 3]:
		rows.append(func(yy: float) -> float:
			return _lab(fd, box, ["", "THREAT", "SEVERE", "RUINOUS"][sev], 18, [fd.GOLD, Color(0.96, 0.6, 0.35), Color(0.91, 0.42, 0.42)][sev - 1], c.x, yy, c.y).size.y + yy + 6.0)
		for b in CribData.BOSS_POOL:
			if int(b.sev) != sev:
				continue
			rows.append(func(yy: float) -> float:
				var sp := SpoilerSprite.new(b)
				sp.size = Vector2(88, 88)
				sp.position = Vector2(c.x, yy)
				box.add_child(sp)
				var align: String = Cribbage.SUIT_SYM.get(b.get("align", ""), "") if b.get("align") != null else ""
				var n := _lab(fd, box, String(b.name) + ("  " + align if align != "" else ""), TypeScale.BODY, fd.GOLD, c.x + 100.0, yy + 4.0, c.y - 100.0)
				var t := _lab(fd, box, b.text, TypeScale.BODY, fd.DIM, c.x + 100.0, yy + 8.0 + n.size.y, c.y - 100.0)
				return maxf(yy + 92.0, t.position.y + t.size.y + 8.0))
			rows.append(func(yy: float) -> float:
				# its five poses
				var pw := minf(64.0, (c.y - 100.0) / SpoilerSprite.POSES.size())
				for k in SpoilerSprite.POSES.size():
					var ps := SpoilerSprite.new(b)
					ps.size = Vector2(pw, pw)
					ps.position = Vector2(c.x + 100.0 + k * pw, yy)
					box.add_child(ps)
					ps.pose = SpoilerSprite.POSES[k]
					ps._show()
				return yy + pw + 12.0)
	return [y, rows]


# ------------------------------------------------------------------ how to play
static func howto(fd: FrontDoor) -> void:
	fd._clear()
	if tut_step >= TUT_STEPS.size():
		tut_step = 0
		var m := Achv.load_store()
		m["tutorial"] = 1
		Achv.save_store(m)
		fd.go("road")
		return
	var st: Dictionary = TUT_STEPS[tut_step]
	var c := fd._col()
	var y := fd._top()
	# progress pips
	var n := TUT_STEPS.size()
	var x0 := (fd.size.x - (n * 14.0 + (n - 1) * 10.0)) / 2.0
	for i in n:
		var d := ColorRect.new()
		d.color = fd.GOLD if i == tut_step else (Color(fd.GOLD, 0.45) if i < tut_step else Color(fd.INK, 0.25))
		d.size = Vector2(14, 14)
		d.position = Vector2(x0 + i * 24.0, y)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fd._page.add_child(d)
	y += 30.0
	var px := minf(220.0, fd.size.y * 0.18)
	var art: String = st.art
	var sp: MeldSprite
	if MeldReact.SIGNATURE.has(art):
		sp = MeldSprite.new(art)
	else:
		sp = SpoilerSprite.new({"art": art, "sev": 2})
	sp.size = Vector2(px, px)
	sp.position = Vector2((fd.size.x - px) / 2.0, y)
	fd._page.add_child(sp)
	sp.react("smug" if (sp is SpoilerSprite) else "eager", true)
	y += px + 8.0
	var box := Panel.new()
	box.add_theme_stylebox_override("panel", fd._box(fd.PANEL, Color(fd.GOLD, 0.3)))
	box.position = Vector2(c.x, y)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fd._page.add_child(box)
	var t := _lab(fd, box, st.title, 34, fd.GOLD, 16, 12, c.y - 32.0)
	var b := _lab(fd, box, st.body, TypeScale.BODY, fd.INK, 16, 18 + t.size.y, c.y - 32.0)
	box.size = Vector2(c.y, b.position.y + b.size.y + 14.0)
	y += box.size.y + 16.0
	_tut_visual(fd, String(st.anchor), y)
	# Back / Next (PLAY on the last), Skip
	var last := tut_step == TUT_STEPS.size() - 1
	fd._button("next", "PLAY" if last else "Next", true, func():
		tut_step += 1
		Sound.play("buy" if tut_step >= TUT_STEPS.size() else "select")
		fd.render())
	var stack := ["skip", "next"]
	fd._button("skip", "Skip", false, func():
		tut_step = TUT_STEPS.size()
		fd.render())
	if tut_step > 0:
		fd._button("prev", "Back", false, func():
			tut_step -= 1
			fd.render())
		stack = ["skip", "next", "prev"]
	stack = ["next", "skip"] if tut_step == 0 else ["next", "prev", "skip"]
	fd._stack_bottom(stack)


## A card row's visible bottom (_card_at puts the drawn card's top-left at y).
static func _row_bottom(y: float, sc: float) -> float:
	return y + CardArt.BASE_H * CardView.PIXEL_SCALE * sc


static func _tut_visual(fd: FrontDoor, anchor: String, y: float) -> void:
	var c := fd._col()
	var C := func(r: int, s: String, enh := "") -> Dictionary:
		var o := {"rank": r, "suit": s}
		if enh != "":
			o["enh"] = enh
		return o
	var cw := CardArt.BASE_W * CardView.PIXEL_SCALE
	var sc := minf(0.8, (c.y / 6.0 - 8.0) / cw)
	var row := func(cards: Array, dim_from := 99) -> void:
		var w := cards.size() * (cw * sc + 8.0) - 8.0
		var x := (fd.size.x - w) / 2.0
		for i in cards.size():
			var v := _card_at(fd._page, cards[i], sc, Vector2(x + i * (cw * sc + 8.0), y))
			if i >= dim_from:
				v.modulate = Color(1, 1, 1, 0.45)
	match anchor:
		"hand":
			row.call([C.call(5, "H"), C.call(5, "S"), C.call(10, "C"), C.call(11, "D"), C.call(2, "S"), C.call(9, "H")], 4)
		"cut":
			row.call([C.call(5, "H"), C.call(5, "S"), C.call(10, "C"), C.call(11, "D")])
		"crib":
			row.call([C.call(2, "S"), C.call(9, "H")])
			_lab(fd, fd._page, "→ your Crib", 20, fd.GOLD, c.x, _row_bottom(y, sc) + 8.0, c.y, HORIZONTAL_ALIGNMENT_CENTER)
		"count":
			var yy := y
			for pair in [["Fifteen 2", "+2"], ["Fifteen 4", "+2"], ["Pair of 5s", "+2"], ["Run of 3", "+3"]]:
				_lab(fd, fd._page, pair[0], 22, fd.INK, c.x + 40.0, yy, c.y * 0.6)
				_lab(fd, fd._page, pair[1], 22, Color(0.43, 0.79, 0.54), c.x, yy, c.y - 40.0, HORIZONTAL_ALIGNMENT_RIGHT)
				yy += 34.0
		"shop":
			row.call([C.call(5, "H", "gilded"), C.call(7, "C", "glass"), C.call(12, "S", "coin")])
		"drag":
			row.call([C.call(2, "S"), C.call(9, "H")])
			var below := _row_bottom(y, sc) + 8.0
			_lab(fd, fd._page, "Flick up: to your Crib", 22, fd.GOLD, c.x, below, c.y, HORIZONTAL_ALIGNMENT_CENTER)
			_lab(fd, fd._page, "Flick down: keep it", 22, Color(0.43, 0.79, 0.54), c.x, below + 34.0, c.y, HORIZONTAL_ALIGNMENT_CENTER)
		"play":
			row.call([C.call(7, "S"), C.call(8, "H"), C.call(10, "C"), C.call(6, "D")])
			var below := _row_bottom(y, sc) + 8.0
			_lab(fd, fd._page, "7 + 8 = 15: +2", 22, fd.GOLD, c.x, below, c.y, HORIZONTAL_ALIGNMENT_CENTER)
			_lab(fd, fd._page, "+ 10 + 6 = 31: +2", 22, Color(0.43, 0.79, 0.54), c.x, below + 34.0, c.y, HORIZONTAL_ALIGNMENT_CENTER)
		"boss":
			var px := minf(150.0, c.y / 3.0)
			var arts := ["deadwood", "jokester", "fog"]
			for i in 3:
				var s := SpoilerSprite.new({"art": arts[i], "sev": 1 if arts[i] != "fog" else 2})
				s.size = Vector2(px, px)
				s.position = Vector2((fd.size.x - px * 3.0) / 2.0 + i * px, y)
				fd._page.add_child(s)


# ------------------------------------------------------------------ settings
static func reduce_motion_saved() -> bool:
	var m := Achv.load_store()
	if m.has("reduce_motion"):
		return JS.truthy(m.reduce_motion)
	var os := os_access()
	if os != null:
		return bool(os.call("reduce_motion"))
	return false       # Godot 4.3 exposes no OS Reduce Motion setting: off until chosen


## The native iOS plugin (docs/PORT.md, "Dynamic Type and Reduce Motion"), when
## the build has it: reduce_motion() -> bool, content_size() -> the UIKit
## category string, and a `changed` signal. Without it: null, in-game settings only.
static func os_access() -> Object:
	return Engine.get_singleton("MeldAccess") if Engine.has_singleton("MeldAccess") else null


## The phone's text size category onto our three steps.
static func text_step_for(category: String) -> int:
	var c := category.trim_prefix("UICTContentSizeCategory")
	if c.begins_with("Accessibility") or c == "XXXL":
		return 2
	if c in ["XL", "XXL"]:
		return 1
	return 0


static var _os_hooked := false


## Count speed: the saved setting once chosen; else 1x on the first run (to
## learn the count) and 2x from the second (pass 14; LOOP_AUDIT item 7).
static func speed_default(m: Dictionary) -> int:
	if m.has("cascade_speed"):
		return clampi(int(m.cascade_speed), 0, CascadeView.SPEEDS.size() - 1)
	return 1 if not (m.get("history", []) as Array).is_empty() else 0


## Apply saved settings at start (RunFlow._ready).
static func apply() -> void:
	MeldSprite.reduce_motion = reduce_motion_saved()
	var m := Achv.load_store()
	CascadeView.speed_i = speed_default(m)
	var ti := int(m.get("text_scale", -1))
	var os := os_access()
	if ti < 0:
		ti = text_step_for(String(os.call("content_size"))) if os != null else 0
	var was := TypeScale.scale
	TypeScale.scale = TypeScale.STEPS[clampi(ti, 0, TypeScale.STEPS.size() - 1)]
	TypeScale.apply_fallback()
	var tree := Engine.get_main_loop() as SceneTree
	if was != TypeScale.scale and tree != null:
		TypeScale.relayout(tree.root)      # e.g. changed in iOS Settings: this screen now
	if os != null and not _os_hooked and os.has_signal("changed"):
		_os_hooked = true
		os.connect("changed", apply)    # the player changed it in iOS Settings


const TEXT_NAMES := ["Standard", "Large", "Larger"]


static func _text_i() -> int:
	return maxi(0, TypeScale.STEPS.find(TypeScale.scale))


static func _save(key: String, v) -> void:
	var m := Achv.load_store()
	m[key] = v
	Achv.save_store(m)


static func settings(fd: FrontDoor) -> void:
	fd._clear()
	var y := fd._line(fd._top(), "SETTINGS", 34, fd.INK) + 12.0
	var c := fd._col()
	var rows := [
		["sound", "Sound", "Off" if Sound.muted() else "On", func(): Sound.set_muted(not Sound.muted())],
		["volume", "Volume", "%d%%" % roundi(Sound.volume() * 100.0), func():
			var v := Sound.volume() + 0.25
			Sound.set_volume(0.25 if v > 1.001 else v)],
		["motion", "Reduce Motion", "On" if MeldSprite.reduce_motion else "Off", func():
			MeldSprite.reduce_motion = not MeldSprite.reduce_motion
			_save("reduce_motion", MeldSprite.reduce_motion)],
		["speed", "Count speed", "%dx" % CascadeView.speed_k(), func():
			CascadeView.speed_i = (CascadeView.speed_i + 1) % CascadeView.SPEEDS.size()
			_save("cascade_speed", CascadeView.speed_i)],
		["text", "Text size", TEXT_NAMES[_text_i()], func():
			var i := (_text_i() + 1) % TypeScale.STEPS.size()
			TypeScale.scale = TypeScale.STEPS[i]
			_save("text_scale", i)
			TypeScale.relayout(fd.get_tree().root)],
	]
	for r in rows:
		_lab(fd, fd._page, r[1], 24, fd.INK, c.x, y + 24.0, c.y * 0.55)
		var b := Button.new()
		b.text = r[2]
		TypeScale.set_size(b, 22)
		b.size = Vector2(180, Press.MIN_H)
		b.position = Vector2(c.x + c.y - 180.0, y)
		var act: Callable = r[3]
		b.pressed.connect(func():
			act.call()
			fd.render())
		fd._page.add_child(b)
		fd.buttons["set_" + String(r[0])] = b
		y += Press.MIN_H + 16.0
	_lab(fd, fd._page, "Reduce Motion turns off shake, particles, slides and bounces.", 16, fd.DIM, c.x, y + 6.0, c.y)
	fd._button("back", "Back", false, func(): fd.go("title"))
	fd._stack_bottom(["back"])
