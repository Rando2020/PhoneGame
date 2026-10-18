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
	set_anchors_preset(Control.PRESET_FULL_RECT)
	start_run()


## A fresh run. Tests may pass a prepared run.
func start_run(run_: CribRun = null) -> void:
	run = run_ if run_ != null else CribRun.new(meldling, Meta.STREETS[street_id - 1], null, seed)
	show_intro()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _page != null and screen in ["intro", "round_end", "run_won"]:
		_rerender()


func _rerender() -> void:
	match screen:
		"intro": show_intro()
		"round_end": _render_round_end()
		"run_won": show_run_won()


# ------------------------------------------------------------------ page helpers
func _clear() -> void:
	buttons.clear()
	for c in get_children():
		if c == _toast:
			continue
		remove_child(c)
		c.queue_free()
	keep = null
	shop = null
	_page = Control.new()
	_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_page)
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.add_child(bg)
	if _toast != null:
		move_child(_toast, -1)


## The web's flash(): one line over whatever screen comes next, gone in 1.6 s.
var _toast: Label
var _toast_tween: Tween


func flash(msg: String) -> void:
	if _toast == null:
		_toast = Label.new()
		_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_toast.add_theme_font_size_override("font_size", 22)
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
func _line(y: float, text: String, fs: int, colr: Color) -> float:
	var c := _col()
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", fs)
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
	b.add_theme_font_size_override("font_size", 30 if big else 22)
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
		var h := 80.0 if i == 0 else 56.0
		# a label wider than the button grows it rightward, off centre: size to fit
		var w := maxf(300.0 if i == 0 else 260.0, b.get_combined_minimum_size().x + 32.0)
		w = minf(w, size.x - MARGIN * 2.0)
		y -= h
		b.size = Vector2(w, h)
		b.position = Vector2((size.x - w) / 2.0, y)
		y -= 12.0


# ------------------------------------------------------------------ intro
## Port of cribRoundIntro.
func show_intro() -> void:
	_clear()
	_set_screen("intro")
	var boss = run.boss()
	var m := run.rules()
	var ins := SafeArea.insets(self)
	var y: float = ins.top + MARGIN * 2.0
	y = _line(y, "ACT %d  ·  ROUND %d / %d" % [run.act, run.round, CribData.ROUNDS], 20, DIM)
	if run.is_wager():
		y = _line(y, "A WAGER", 18, GOLD)
		y = _line(y, "SCORE IT EXACTLY", 40, GOLD)
		var terms := [["THE TERMS", 18, GOLD],
			["Finish on exactly %d. Not one point more." % run.target(), 20, INK]]
		var locked := Achv.locked_systems()
		if not locked.is_empty():
			terms.append(["Win and you keep: %s: %s" % [locked[0].name, locked[0].text], 17, GREEN])
		terms.append(["Lose and the run ends. You may walk away instead.", 17, DIM])
		y = _panel(y + 6.0, terms)
	elif boss != null:
		var sev_name: String = ["", "A SPOILER", "A GRIM SPOILER", "A RUINOUS SPOILER"][boss.sev]
		y = _line(y, "%s  ·  ACT %d BOSS" % [sev_name, run.act], 18, SEV[boss.sev])
		y = _line(y, boss.name, 44, SEV[boss.sev])
		y = _panel(y + 6.0, [["THE SPOILER DECREES", 18, SEV[boss.sev]], [boss.text, 20, INK]])
	else:
		y = _line(y, "TARGET %d" % run.target(), 52, INK)
	y = _line(y + 4.0, "Score %d in %d deals" % [run.target(), CribData.DEALS + m.dealBonus], 22, GOLD)
	y = _line(y, "%s  ·  deck %d  ·  charms %d/%d" % [run.street.name, run.deck_size(), run.charms.size(), run.slots()], 17, DIM)
	# the Spoilers on the road: past dimmed, this act's marked
	var plan := []
	for i in run.boss_plan.size():
		var b: Dictionary = run.boss_plan[i]
		var mark := "" if i + 1 != run.act else "  <"
		plan.append(["A%d %s%s" % [i + 1, b.name, mark], 17, DIM if i + 1 < run.act else SEV[b.sev]])
	y = _line(y + 10.0, "SPOILERS ON THE ROAD", 16, GOLD)
	y = _panel(y, plan)
	var order := ["deal"]
	_button("deal", "DEAL", true, _on_deal)
	if run.is_wager():
		_button("walk", "WALK AWAY", false, _on_walk_away)
		order.append("walk")
	if run.skips > 0 and boss == null:
		_button("skip", "SKIP THIS ROUND  ·  %d banked" % run.skips, false, _on_skip)
		order.append("skip")
	_place_buttons(order)


func _on_deal() -> void:
	_clear()
	_set_screen("round")
	keep = load("res://scenes/keep_screen.tscn").instantiate()
	keep.in_run = true
	keep.seed = seed
	keep.meldling = meldling
	_page.add_child(keep)
	keep.round_finished.connect(_on_round_finished, CONNECT_ONE_SHOT)
	keep.start_round(run)


## Web: the wager is struck from the plan and the intro redrawn.
func _on_walk_away() -> void:
	run.wager_at["%d-%d" % [run.act, run.round]] = false
	show_intro()
	flash("You let the wager pass.")


## Web: a Skip pays Glim and goes straight to the shop. Spoilers can't be skipped.
func _on_skip() -> void:
	run.skips -= 1
	run.essence += 8 + JS.round_(run.round_index() * 0.6)
	run.open_shop()
	show_shop()
	flash("Round skipped — you take the Glim and move on.")


# ------------------------------------------------------------------ round end
func _on_round_finished() -> void:
	rd = keep.rd
	_paid = false
	_round_end_effects()
	_render_round_end()


## Port of cribRoundEnd's state changes, in its order. Runs once per round.
func _round_end_effects() -> void:
	if rd.crib_result == null:
		rd.settle_crib()
	rd.settle()
	if rd.wager != null and rd.wager_won:
		var locked := Achv.locked_systems()
		if not locked.is_empty():
			Achv.grant_system(locked[0].id)
	var max_lv := 0
	for k in run.levels:
		max_lv = maxi(max_lv, run.levels[k])
	Achv.check("round", {"won": rd.won, "act": run.act, "round": run.round, "score": rd.score,
		"target": rd.target, "deckSize": run.deck_size(),
		"cribTotal": rd.crib_result.total if rd.crib_result != null else 0,
		"maxReckoning": max_lv,
		"hallowed": run.charms.filter(func(c): return c.rarity == "legendary").size(),
		"shattered": rd.shattered_all.size(),
		"actCleared": rd.won and run.round == CribData.ROUNDS})
	if rd.won and not _paid:
		run.essence += rd.essence_earned
		_paid = true


func _render_round_end() -> void:
	_clear()
	_set_screen("round_end")
	var ins := SafeArea.insets(self)
	var y: float = ins.top + MARGIN * 2.0
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
		_button("shop", "SHOP", true, func():
			run.open_shop()
			show_shop())
		_place_buttons(["shop"])
	else:
		y = _line(y, "Reached Act %d, Round %d." % [run.act, run.round], 20, DIM)
		_button("new_run", "NEW RUN", true, _new_run)
		_place_buttons(["new_run"])


func _new_run() -> void:
	seed += 1
	start_run()


# ------------------------------------------------------------------ shop
func show_shop() -> void:
	_clear()
	_set_screen("shop")
	shop = load("res://scenes/shop_screen.tscn").instantiate()
	_page.add_child(shop)
	shop.open(run)
	shop.next_round.connect(_on_next_round, CONNECT_ONE_SHOT)


## Port of the shop's NEXT ROUND handler.
func _on_next_round() -> void:
	run.shop_state = null
	if run.endless:
		run.endless_round += 1
		show_intro()
		return
	if run.advance():
		_run_won_effects()
		show_run_won()
		return
	show_intro()


# ------------------------------------------------------------------ run won
var _won_pegs := 0


## Port of cribRunWon's state changes, in its order. Runs once.
func _run_won_effects() -> void:
	Achv.check("run", {"cleared": true, "street": run.street.id})
	Achv.mark_cleared(run.meldling)
	if run.trial != null:
		Achv.mark_trial(run.trial.id)
	var total := CribData.ACTS * CribData.ROUNDS
	_won_pegs = Meta.pegs_for_run(total, true, run.street.id, Achv.count())
	Achv.add_pegs(_won_pegs)
	Achv.log_run({"deck": run.meldling, "reached": total, "street": run.street.id,
		"score": 0, "cleared": true, "when": int(Time.get_unix_time_from_system() * 1000.0)})


func show_run_won() -> void:
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
