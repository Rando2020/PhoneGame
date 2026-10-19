class_name ShopScreen
extends Control
## The Peg House: the shop between rounds. Port of showCribShop
## (web/cribrogue_ui.js). Every button does exactly what the web's handler does;
## the screen re-renders from the run after each action, as the web does.
##
## Tests reach controls through: sell_buttons[id], offer_buttons[id],
## card_buttons[index into shop_state.cards], reroll_button, level_buttons[cat],
## next_button.

signal acted(kind: String)
signal next_round

const BG := Color(0.102, 0.094, 0.149)
const PANEL := Color(0.098, 0.086, 0.153)
const INK := Color(0.96, 0.93, 0.88)
const DIM := Color(0.96, 0.93, 0.88, 0.55)
const GOLD := Color(0.91, 0.71, 0.30)
const RED := Color(0.93, 0.38, 0.38)
const DECK_TINT := Color(0.91, 0.71, 0.30)
const MARGIN := 24.0
const MAX_COLUMN := 920.0
const STALL_SCALE := 0.75

var run
var juice: Juice = null    ## set by RunFlow: a legendary purchase bursts
var sell_buttons := {}
var offer_buttons := {}
var card_buttons := {}
var level_buttons := {}
var reroll_button: Button
var next_button: Button
var essence_label: Label
var toast: Label

var _scroll: ScrollContainer
var _content: Control
var _toast_tween: Tween


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(Surface.make("round"))
	Surface.rail(self, 0.0, 4096.0, 22.0)      # the shop counter's wood rail, along the top
	Press.watch(self)
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.add_child(_content)
	toast = _label(22, INK, HORIZONTAL_ALIGNMENT_CENTER)
	toast.modulate.a = 0.0
	add_child(toast)
	if run != null:
		render()


func open(run_) -> void:
	run = run_
	if run.shop_state == null:
		run.open_shop()
	if is_node_ready():
		render()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _content != null and run != null:
		render()


# ------------------------------------------------------------------ actions
## Each mirrors the web handler exactly. Returns whether anything happened.
func buy_charm(ch: Charm) -> bool:
	if ch.cost > run.essence or run.is_full():
		return false
	run.essence -= ch.cost
	run.charms.append(ch)
	if ch.on_acquire.is_valid():
		ch.on_acquire.call(run)
	run.shop_state.offer = run.shop_state.offer.filter(func(x): return x.id != ch.id)
	if ch.rarity == "legendary" and juice != null:
		juice.burst(size / 2.0, 46, ["gold", "white", "green"])
		juice.shake(6.0, 240.0)
		Haptics.pulse(50)
	_after("charm", "Bought %s" % ch.name)
	return true


func buy_card(i: int) -> bool:
	var entry: Dictionary = run.shop_state.cards[i]
	if entry.get("sold", false) or not run.buy_card(entry):
		return false
	entry["sold"] = true
	_after("card", "Added %s to your deck" % Cribbage.card_str(entry.card))
	return true


func do_reroll() -> bool:
	if not run.reroll():
		return false
	_after("reroll", "")
	return true


func buy_level(cat: String) -> bool:
	if not run.buy_level(cat):
		return false
	_after("level", "%s Reckoning %d" % [cat.capitalize(), run.levels[cat]])
	return true


func sell(id: String) -> bool:
	var name := ""
	for c in run.charms:
		if c.id == id:
			name = c.name
	var got: int = run.sell(id)
	if got == 0:
		return false
	_after("sell", "Pawned %s for %d Glim" % [name, got])
	return true


func _after(kind: String, msg: String) -> void:
	render()
	if msg != "":
		_toast(msg)
	acted.emit(kind)


func _toast(msg: String) -> void:
	toast.text = msg
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.2)
	_toast_tween.tween_property(toast, "modulate:a", 0.0, 0.4)


# ------------------------------------------------------------------ rendering
func _label(fs: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _box(col: Color, border: Color, radius := 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	return sb


func _button(text: String, fs := 22) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", fs)
	return b


func _place(n: Control, pos: Vector2, sz: Vector2) -> Control:
	_content.add_child(n)
	n.position = pos
	n.size = sz
	return n


## OS safe area, phones only (see SafeArea).
func _insets() -> Dictionary:
	return SafeArea.insets(self)


func render() -> void:
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()
	sell_buttons.clear()
	offer_buttons.clear()
	card_buttons.clear()
	level_buttons.clear()
	var ins := _insets()
	var col := minf(size.x - MARGIN * 2.0, MAX_COLUMN)
	var x0 := (size.x - col) / 2.0
	var y: float = ins.top + MARGIN

	# ---- header
	var head := _place(Panel.new(), Vector2(x0, y), Vector2(col, 76))
	head.add_theme_stylebox_override("panel", _box(PANEL, Color(INK, 0.12)))
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := _label(26, GOLD)
	title.text = "THE PEG HOUSE"
	title.position = Vector2(14, 6)
	title.size = Vector2(col * 0.6, 34)
	head.add_child(title)
	essence_label = _label(26, GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	essence_label.text = "%d Glim" % run.essence
	essence_label.position = Vector2(col * 0.4, 6)
	essence_label.size = Vector2(col * 0.6 - 14, 34)
	head.add_child(essence_label)
	var sub := _label(17, DIM)
	sub.text = "Act %d-%d cleared  ·  deck %d cards  ·  charms %d/%d" % [
		run.act, run.round, run.deck_size(), run.charms.size(), run.slots()]
	sub.position = Vector2(14, 42)
	sub.size = Vector2(col - 28, 26)
	head.add_child(sub)
	y += 76 + 14

	# ---- your charms (Meldling first, no sell), then owned (x to sell), then empty slots
	var lab := _label(17, GOLD)
	lab.text = "YOUR CHARMS  (tap × to sell)"
	_place(lab, Vector2(x0, y), Vector2(col, 24))
	y += 26
	var chips: Array = []
	for ch in run.active_charms():
		chips.append(ch)
	var empties: int = maxi(0, run.slots() - run.charms.size())
	var n := chips.size() + empties
	var cw := (col - 6.0 * (n - 1)) / n
	for i in n:
		var p := _place(Panel.new(), Vector2(x0 + i * (cw + 6), y), Vector2(cw, 58))
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if i >= chips.size():
			p.add_theme_stylebox_override("panel", _box(PANEL, Color(INK, 0.12)))
			continue
		var ch: Charm = chips[i]
		var tint := DECK_TINT if ch.tier == 0 else Color(CribData.RARITY.get(ch.rarity, CribData.RARITY.common).tint)
		p.add_theme_stylebox_override("panel", _box(PANEL, tint))
		# names get the full chip width; a sellable chip keeps a strip at the
		# top for the x so the two never overlap
		var top: float = 18.0 if ch.tier != 0 else 2.0
		var name_w: float = cw - 6.0
		var name_h: float = 58.0 - top - 2.0
		var nm := _label(_fit_size(ch.name, name_w, name_h, 14, 8), INK, HORIZONTAL_ALIGNMENT_CENTER)
		nm.text = ch.name
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD
		nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		nm.position = Vector2(3, top)
		nm.size = Vector2(name_w, name_h)
		p.add_child(nm)
		if ch.tier != 0:
			# visible x is small; the touch target is the whole top strip corner
			var x := _button("×", 16)
			x.flat = true
			x.position = Vector2(cw - 34, 0)
			x.size = Vector2(34, 26)
			x.pressed.connect(sell.bind(ch.id))
			p.add_child(x)
			sell_buttons[ch.id] = x
	y += 58 + 16

	# ---- charm offers + reroll
	var oh := _label(19, INK)
	oh.text = "CHARMS ON OFFER"
	_place(oh, Vector2(x0, y + 6), Vector2(col * 0.6, 28))
	reroll_button = _button("Reroll  %d" % run.reroll_cost(), 20)
	_place(reroll_button, Vector2(x0 + col - 150, y), Vector2(150, 40))
	reroll_button.disabled = run.essence < run.reroll_cost()
	reroll_button.pressed.connect(do_reroll)
	y += 48
	var full: bool = run.is_full()
	var owned := {}
	for c in run.charms:
		owned[c.id] = true
	for ch in run.shop_state.offer:
		if owned.has(ch.id):
			continue
		var tint := Color(CribData.RARITY.get(ch.rarity, CribData.RARITY.common).tint)
		var b := Button.new()
		_place(b, Vector2(x0, y), Vector2(col, 88))
		b.add_theme_stylebox_override("normal", _box(PANEL, tint))
		b.add_theme_stylebox_override("hover", _box(PANEL.lerp(tint, 0.12), tint))
		b.add_theme_stylebox_override("pressed", _box(PANEL.lerp(tint, 0.25), tint))
		b.add_theme_stylebox_override("disabled", _box(PANEL, Color(tint, 0.35)))
		b.disabled = ch.cost > run.essence or full
		b.pressed.connect(buy_charm.bind(ch))
		var nm := _label(21, INK)
		nm.text = ch.name
		nm.position = Vector2(14, 6)
		nm.size = Vector2(col * 0.55, 28)
		b.add_child(nm)
		var rt := _label(15, tint)
		rt.text = CribData.RARITY[ch.rarity].name
		rt.position = Vector2(col * 0.55, 10)
		rt.size = Vector2(col * 0.45 - 90, 24)
		b.add_child(rt)
		var tx := _label(15, DIM)
		tx.text = ch.text
		tx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tx.position = Vector2(14, 36)
		tx.size = Vector2(col - 110, 48)
		b.add_child(tx)
		var cost := _label(26, GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
		cost.text = str(ch.cost)
		cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cost.position = Vector2(col - 80, 0)
		cost.size = Vector2(66, 88)
		b.add_child(cost)
		if b.disabled:
			for k in [nm, tx, cost]:
				k.modulate.a = 0.45
		offer_buttons[ch.id] = b
		y += 88 + 8
	if full:
		var fl := _label(16, RED)
		fl.text = "Every charm slot is spoken for. Pawn one first."
		_place(fl, Vector2(x0, y), Vector2(col, 24))
		y += 26
	y += 10

	# ---- the stall
	var sh := _label(19, INK)
	sh.text = "THE STALL  ·  take a card into your deck"
	_place(sh, Vector2(x0, y), Vector2(col, 28))
	y += 30
	var shown := []
	for i in run.shop_state.cards.size():
		if not run.shop_state.cards[i].get("sold", false):
			shown.append(i)
	var card_sz := Vector2(CardArt.BASE_W, CardArt.BASE_H) * CardView.PIXEL_SCALE * STALL_SCALE
	var slot_w := col / 4.0
	if shown.is_empty():
		var bare := _label(16, DIM)
		bare.text = "The stall is bare."
		_place(bare, Vector2(x0, y), Vector2(col, 24))
		y += 30
	else:
		for k in shown.size():
			var i: int = shown[k]
			var entry: Dictionary = run.shop_state.cards[i]
			var sx := x0 + k * slot_w
			var v := CardView.new()
			v.draggable = false
			_content.add_child(v)
			v.mouse_filter = Control.MOUSE_FILTER_IGNORE   # after add_child: CardView._ready sets STOP
			v.setup_card(entry.card, true)
			v.scale = Vector2.ONE * STALL_SCALE
			# CardView scales about its centre: offset so the visible card sits at the slot
			v.position = Vector2(sx + (slot_w - card_sz.x) / 2.0, y) - v.size * (1.0 - STALL_SCALE) / 2.0
			var enh = entry.card.get("enh")
			var mk := _label(15, GOLD if enh != null else DIM, HORIZONTAL_ALIGNMENT_CENTER)
			mk.text = CribData.ENHANCEMENTS[enh].name if enh != null else "unmarked"
			_place(mk, Vector2(sx, y + card_sz.y + 2), Vector2(slot_w, 22))
			var b := _button(str(entry.cost), 20)
			_place(b, Vector2(sx + 10, y + card_sz.y + 26), Vector2(slot_w - 20, 40))
			b.disabled = run.essence < entry.cost
			b.pressed.connect(buy_card.bind(i))
			card_buttons[i] = b
		y += card_sz.y + 26 + 40
	y += 16

	# ---- Reckonings
	var rh := _label(19, INK)
	rh.text = "RECKONINGS  ·  +%d base per scoring event, each level" % CribData.LEVEL_GAIN
	_place(rh, Vector2(x0, y), Vector2(col, 28))
	y += 30
	var lw := (col - 8.0 * 3) / 4.0
	var li := 0
	for cat in CribData.LEVEL_CATS:
		var cost: int = run.level_cost_for(cat)
		var b := Button.new()
		_place(b, Vector2(x0 + li * (lw + 8), y), Vector2(lw, 84))
		b.disabled = run.essence < cost
		b.pressed.connect(buy_level.bind(cat))
		var t1 := _label(17, INK, HORIZONTAL_ALIGNMENT_CENTER)
		t1.text = cat
		t1.position = Vector2(0, 4)
		t1.size = Vector2(lw, 24)
		b.add_child(t1)
		var t2 := _label(20, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		t2.text = "%d → %d" % [run.levels[cat], run.levels[cat] + 1]
		t2.position = Vector2(0, 28)
		t2.size = Vector2(lw, 26)
		b.add_child(t2)
		var t3 := _label(16, DIM, HORIZONTAL_ALIGNMENT_CENTER)
		t3.text = str(cost)
		t3.position = Vector2(0, 56)
		t3.size = Vector2(lw, 22)
		b.add_child(t3)
		level_buttons[cat] = b
		li += 1
	y += 84 + 20

	# ---- next round: bottom of the screen if there is room, else after the content
	var nb_y: float = maxf(y, size.y - ins.bottom - MARGIN * 1.5 - 80)
	next_button = _button("NEXT ROUND", 30)
	_place(next_button, Vector2((size.x - 300) / 2.0, nb_y), Vector2(300, 80))
	next_button.pressed.connect(func(): next_round.emit())
	_content.custom_minimum_size = Vector2(size.x, nb_y + 80 + MARGIN + ins.bottom)
	_content.size = _content.custom_minimum_size
	toast.position = Vector2(x0, nb_y - 44)
	toast.size = Vector2(col, 36)


## Largest font size (from hi down to lo) at which `text`, word-wrapped greedily
## the way Label wraps it, fits a width x height box without breaking a word.
## Measured with the real font, not estimated (a width guess hid "House").
## Two lines are preferred; three only when two can't fit at any size.
func _fit_size(text: String, width: float, height: float, hi: int, lo: int) -> int:
	var font := get_theme_default_font()
	var words := text.split(" ")
	for max_lines in [2, 3]:
		var fs := _fit_lines(font, words, width - 4.0, height, hi, lo, max_lines)
		if fs > 0:
			return fs
	return lo


func _fit_lines(font: Font, words: PackedStringArray, avail: float, height: float, hi: int, lo: int, max_lines: int) -> int:
	var gap := float(get_theme_constant("line_spacing", "Label"))
	for fs in range(hi, lo - 1, -1):
		var lines := 1
		var cur := ""
		var ok := true
		for w in words:
			if font.get_string_size(w, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > avail:
				ok = false
				break
			var trial: String = w if cur == "" else cur + " " + w
			if font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= avail:
				cur = trial
			else:
				lines += 1
				cur = w
		if ok and lines <= max_lines and lines * (font.get_height(fs) + gap) <= height:
			return fs
	return -1


## Height the content needs, to check it fits without scrolling.
func content_height() -> float:
	return _content.custom_minimum_size.y
