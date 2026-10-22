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
const GREEN := Color(0.43, 0.79, 0.54)
const DECK_TINT := Color(0.91, 0.71, 0.30)
const MARGIN := 24.0
const MAX_COLUMN := 920.0
const STALL_SCALE := 0.75

var run
var juice: Juice = null    ## set by RunFlow: a legendary purchase bursts
var sell_buttons := {}
var offer_buttons := {}
signal first_charm(ch: Charm)   ## a charm bought for the first time ever (pass 19)
var upgrade = null              ## Upgrade.best() for this render, or null
const OFFER_ICON := 64.0        ## an offer row's charm icon (pass 19)
var upgrade_label: Label = null
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


func open(run_, staged := false) -> void:
	run = run_
	if run.shop_state == null:
		run.open_shop()
	if is_node_ready():
		if staged:
			render_staged()
		else:
			render()


var _drawn_for := Vector3(-1, -1, -1)   ## TypeScale.layout_key at the last draw


## Deferred, like RunFlow's: a resize can land mid-draw, so the size is
## compared once the draw is done.
func _redraw_if_moved() -> void:
	if _content != null and run != null and TypeScale.layout_key(self) != _drawn_for:
		render()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _content != null and run != null:
		_redraw_if_moved.call_deferred()


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
	if Collection.mark(ch.id, Collection.OWNED):
		first_charm.emit(ch)        # once per charm, ever: RunFlow's toast celebrates
	if ch.rarity == "legendary":
		Sound.play("milestone")
		if juice != null:
			juice.burst(size / 2.0, 46, ["gold", "white", "green"])
			juice.shake(6.0, 240.0)
		Haptics.pulse(50)
	else:
		Sound.play("buy")
	_after("charm", "Bought %s" % ch.name)
	return true


func buy_card(i: int) -> bool:
	var entry: Dictionary = run.shop_state.cards[i]
	if entry.get("sold", false) or not run.buy_card(entry):
		return false
	entry["sold"] = true
	Sound.play("buy")
	_after("card", "Added %s to your deck" % Cribbage.card_str(entry.card))
	return true


func do_reroll() -> bool:
	if not run.reroll():
		return false
	Sound.play("cut")
	_after("reroll", "")
	return true


func buy_level(cat: String) -> bool:
	if not run.buy_level(cat):
		return false
	Sound.play("level")
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
	Sound.play("toCrib")
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
	TypeScale.set_size(l, fs)
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
	TypeScale.set_size(b, fs)
	return b


func _place(n: Control, pos: Vector2, sz: Vector2) -> Control:
	_content.add_child(n)
	n.position = pos
	n.size = sz
	return n


## OS safe area, phones only (see SafeArea).
func _insets() -> Dictionary:
	return SafeArea.insets(self)


## The draw, in stages that share `c` (x0, col, ins, y). render() runs them
## all now; open_staged() runs the first now and one per frame after (the
## page's slide hides the rest arriving), so no frame builds the whole shop.
func _stages() -> Array:
	return [_stage_top, _stage_offers, _stage_stall, _stage_bottom]


func render() -> void:
	var c := _begin()
	for st in _stages():
		st.call(c)


## Staged: the first stage now, the rest one per frame (finish() runs them all).
func render_staged() -> void:
	var c := _begin()
	var st := _stages()
	st[0].call(c)
	_pending = st.slice(1)
	_pending_ctx = c
	set_process(true)


func finish() -> void:
	while not _pending.is_empty():
		_pending.pop_front().call(_pending_ctx)
	set_process(false)


func is_building() -> bool:
	return not _pending.is_empty()


func _process(_delta: float) -> void:
	if _pending.is_empty():
		set_process(false)
		return
	_pending.pop_front().call(_pending_ctx)


var _pending: Array = []
var _pending_ctx := {}


func _begin() -> Dictionary:
	_drawn_for = TypeScale.layout_key(self)
	_pending = []
	set_process(false)
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()
	sell_buttons.clear()
	offer_buttons.clear()
	upgrade_label = null
	card_buttons.clear()
	level_buttons.clear()
	var ins := _insets()
	var col := minf(size.x - MARGIN * 2.0, MAX_COLUMN)
	var x0 := (size.x - col) / 2.0
	var y: float = ins.top + MARGIN
	return {"x0": x0, "col": col, "ins": ins, "y": y}


func _stage_top(ctx: Dictionary) -> void:
	var x0: float = ctx.x0
	var col: float = ctx.col
	var ins: Dictionary = ctx.ins
	var y: float = ctx.y
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
	# more than 4 chips: rows of 3, so a name gets ~215 px at 11 pt and up
	var per := n if n <= 4 else 3
	var cw := (col - 6.0 * (per - 1)) / per
	var ch_h := 72.0
	for i in n:
		var cx := x0 + (i % per) * (cw + 6)
		var cy := y + (i / per) * (ch_h + 6)
		var p := _place(Panel.new(), Vector2(cx, cy), Vector2(cw, ch_h))
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if i >= chips.size():
			p.add_theme_stylebox_override("panel", _box(PANEL, Color(INK, 0.12)))
			continue
		var ch: Charm = chips[i]
		var tint := DECK_TINT if ch.tier == 0 else Color(CribData.RARITY.get(ch.rarity, CribData.RARITY.common).tint)
		p.add_theme_stylebox_override("panel", _box(PANEL, tint))
		# a sellable chip keeps the right edge for the x so the two never overlap
		var xw: float = 30.0 if ch.tier != 0 else 0.0
		var nm := _label(18, INK, HORIZONTAL_ALIGNMENT_CENTER)
		nm.text = ch.name
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		# the charm's icon (pass 19) on the left; the Meldling's knack has none
		var iw := 0.0
		var ic := CharmIcon.make(ch.id, 40.0) if ch.tier != 0 else null
		# an icon never splits a word: a name's longest word must still fit beside it
		if ic != null:
			var f := nm.get_theme_font("font")
			var fsz := nm.get_theme_font_size("font_size")
			var room := cw - 8.0 - xw - 42.0
			var fits := f.get_multiline_string_size(ch.name, HORIZONTAL_ALIGNMENT_CENTER, room, fsz).y <= ch_h - 4.0
			for word in String(ch.name).split(" "):
				if f.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x > room:
					fits = false
			# and the name must still fit the chip's height beside it (Larger text)
			if not fits:
				ic.free()
				ic = null
		if ic != null:
			ic.position = Vector2(4, (ch_h - 40.0) / 2.0)
			p.add_child(ic)
			iw = 42.0
		nm.position = Vector2(4 + iw, 2)
		nm.size = Vector2(cw - 8.0 - xw - iw, ch_h - 4.0)
		p.add_child(nm)
		if ch.tier != 0:
			var x := _button("×", 22)
			x.flat = true
			x.position = Vector2(cw - 34, 0)
			x.size = Vector2(34, 34)
			x.pressed.connect(sell.bind(ch.id))
			p.add_child(x)
			sell_buttons[ch.id] = x
	y += ceili(float(n) / per) * (ch_h + 6) + 10
	ctx.y = y


func _stage_offers(ctx: Dictionary) -> void:
	var x0: float = ctx.x0
	var col: float = ctx.col
	var ins: Dictionary = ctx.ins
	var y: float = ctx.y
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
	# the collection (pass 19): every offer shown is now seen (idempotent)
	Collection.mark_all(run.shop_state.offer.map(func(x): return x.id), Collection.SEEN)
	# the upgrade mark (LOOP_AUDIT 3): measured on this run's counts, not guessed
	upgrade = Upgrade.best(run, run.shop_state.offer) if full else null
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
		# the charm's icon (pass 19), then its name, rarity and text beside it
		var lx := 14.0
		var oic := CharmIcon.make(ch.id, OFFER_ICON)
		if oic != null:
			oic.position = Vector2(10, 10)
			b.add_child(oic)
			lx = 10.0 + OFFER_ICON + 10.0
		var nm := _label(28, INK)
		nm.text = ch.name
		nm.position = Vector2(lx, 6)
		nm.size = Vector2(col * 0.55 - lx + 14.0, 28)
		b.add_child(nm)
		var rt := _label(15, tint)
		rt.text = CribData.RARITY[ch.rarity].name
		rt.position = Vector2(col * 0.55, 10)
		rt.size = Vector2(col * 0.45 - 90, 24)
		b.add_child(rt)
		var tx := _label(TypeScale.BODY, DIM)
		tx.text = ch.text
		tx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tx.position = Vector2(lx, nm.position.y + nm.get_minimum_size().y - 2.0)
		tx.size = Vector2(col - 96 - lx, 0)
		b.add_child(tx)
		var bottom := tx.position.y + tx.get_minimum_size().y
		if upgrade != null and upgrade.offer == ch:
			var up := _label(TypeScale.BODY, GREEN)
			up.text = "UPGRADE over %s: +%d on your last %d counts" % [upgrade.over.name, upgrade.gain, upgrade.counts]
			up.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			# the charm it would replace, as a small icon before the line
			var ux := lx
			var over_ic := CharmIcon.make(upgrade.over.id, 28.0)
			if over_ic != null:
				over_ic.position = Vector2(lx, bottom + 2.0)
				b.add_child(over_ic)
				ux = lx + 32.0
			up.position = Vector2(ux, bottom)
			up.size = Vector2(col - 96 - ux, 0)
			b.add_child(up)
			upgrade_label = up
			bottom = up.position.y + up.get_minimum_size().y
		var row_h := maxf(OFFER_ICON + 20.0 if oic != null else 88.0, maxf(88.0, bottom + 6.0))
		b.size.y = row_h
		var cost := _label(26, GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
		cost.text = str(ch.cost)
		cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cost.position = Vector2(col - 80, 0)
		cost.size = Vector2(66, row_h)
		b.add_child(cost)
		if b.disabled:
			# (the upgrade line stays bright: it's why you'd pawn a charm)
			for k in [nm, tx, cost]:
				k.modulate.a = 0.45
		offer_buttons[ch.id] = b
		y += row_h + 8
	if full:
		var fl := _label(16, RED)
		fl.text = "Every charm slot is spoken for. Pawn one first."
		_place(fl, Vector2(x0, y), Vector2(col, 24))
		y += 26
	y += 10
	ctx.y = y


func _stage_stall(ctx: Dictionary) -> void:
	var x0: float = ctx.x0
	var col: float = ctx.col
	var ins: Dictionary = ctx.ins
	var y: float = ctx.y
	# ---- the stall
	var sh := _label(19, INK)
	sh.text = "THE STALL  ·  take a card into your deck"
	_place(sh, Vector2(x0, y), Vector2(col, 28))
	y += 38
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
	ctx.y = y


func _stage_bottom(ctx: Dictionary) -> void:
	var x0: float = ctx.x0
	var col: float = ctx.col
	var ins: Dictionary = ctx.ins
	var y: float = ctx.y
	# ---- Reckonings
	var rh := _label(19, INK)
	rh.text = "RECKONINGS  ·  +%d base per scoring event, each level" % CribData.LEVEL_GAIN
	rh.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(rh, Vector2(x0, y), Vector2(col, 28))
	rh.size.y = maxf(28.0, rh.get_minimum_size().y)
	y += rh.size.y + 2.0
	var lw := (col - 8.0 * 3) / 4.0
	var li := 0
	var tile_h := 84.0
	for cat in CribData.LEVEL_CATS:
		var cost: int = run.level_cost_for(cat)
		var b := Button.new()
		_place(b, Vector2(x0 + li * (lw + 8), y), Vector2(lw, 84))
		b.disabled = run.essence < cost
		b.pressed.connect(buy_level.bind(cat))
		var ty := 4.0
		for part in [[cat, 17, INK], ["%d → %d" % [run.levels[cat], run.levels[cat] + 1], 20, GOLD], [str(cost), 16, DIM]]:
			var t := _label(part[1], part[2], HORIZONTAL_ALIGNMENT_CENTER)
			t.text = part[0]
			t.position = Vector2(0, ty)
			t.size = Vector2(lw, 0)
			b.add_child(t)
			ty += t.get_minimum_size().y - 4.0
		tile_h = maxf(tile_h, ty + 8.0)
		level_buttons[cat] = b
		li += 1
	for k in level_buttons:
		level_buttons[k].size.y = tile_h
	y += tile_h + 20

	# ---- next round: bottom of the screen if there is room, else after the content
	var nb_y: float = maxf(y, size.y - ins.bottom - MARGIN * 1.5 - 80)
	next_button = _button("NEXT ROUND", 30)
	_place(next_button, Vector2((size.x - 300) / 2.0, nb_y), Vector2(300, 80))
	next_button.pressed.connect(func(): next_round.emit())
	_content.custom_minimum_size = Vector2(size.x, nb_y + 80 + MARGIN + ins.bottom)
	_content.size = _content.custom_minimum_size
	toast.position = Vector2(x0, nb_y - 44)
	toast.size = Vector2(col, 36)
	ctx.y = y


## Height the content needs, to check it fits without scrolling.
func content_height() -> float:
	return _content.custom_minimum_size.y
