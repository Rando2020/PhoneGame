class_name KeepScreen
extends Control
## First playable screen: a seeded deal of 6, tap to keep 4, commit, then the
## starter flips and the count shows. Drives CribRound directly; holds no rules.
##
## Test hooks: `dealt_ready` fires once the deal animation finishes and input
## is live; `counted(res)` fires after a commit with the engine's own result.

signal dealt_ready
signal counted(res: Dictionary)
signal cascade_done
## Keep was pressed and the engine counted (before the cut ceremony plays).
signal committed
## The round's state just changed in a way a resume must reproduce (a deal, a
## mulligan, a recut, a count, a lay in The Play). RunFlow saves the game here.
signal save_point
signal deeds_earned(ids: Array)   ## the count's deeds (web doCribCount's Achv.check)
## In a run (RunFlow), the finished round is handed back instead of restarting.
signal round_finished

@export var seed: int = 20261001
@export var meldling: String = "pip"
@export var in_run := false

var run: CribRun
var rd: CribRound
var last_result = null

var hand: HandView
var starter_view: CardView
var counted_row: HandView     ## the counted hand + starter, during and after the cascade
var cascade: CascadeView
var keep_button: Button
var status_label: Label
var cascading := false
var cutting := false
var cut_view: CutView
var last_cut_plan = null   ## the ceremony's plan for the last commit (tests)
var dealing := false
var charm_bar: CharmBar
var crib_strip: CribStrip
var mulligan_button: Button
var recut_button: Button
## The Play (web afterCount): owed after this count's cascade, before the round
## goes on or ends. The round is settled only after it, as the web does.
var peg_pending := false
var peg_kept: Array = []
var peg_view: PegView
var peg_session: PegSession
var last_kr := {}
var optimal_streak := 0      ## web Cb.optimalStreak: best-possible keeps in a row
var meld_sprite: MeldSprite   ## your Meldling, reacting to the round
var spoiler_sprite: SpoilerSprite  ## the Spoiler across from it, on Spoiler rounds
var surface: Surface            ## the felt (darker on a Spoiler round)
var juice: Juice                ## bursts and shake, over everything          ## the last keep's rank (the cascade's coaching line needs it)

const BG := Color(0.102, 0.094, 0.149)
## Widest the content column grows: six cards side by side with no overlap.
const MAX_COLUMN := 920.0
const MARGIN := 24.0
const INK := Color(0.96, 0.93, 0.88)
const DIM := Color(0.96, 0.93, 0.88, 0.6)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_layout()
	# In a run, RunFlow hands the round in; dealing a throwaway one here left
	# its deal_finished connection dangling when the real deal killed it.
	if not in_run:
		start_round()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and keep_button != null:
		_layout()


## OS safe area, phones only (see SafeArea).
func safe_insets() -> Dictionary:
	return SafeArea.insets(self)


## Bottom-up for the thumb: button, then hand, then the count fills the middle.
func _layout() -> void:
	var ins := safe_insets()
	var col := minf(size.x - MARGIN * 2.0, MAX_COLUMN)
	var x0 := (size.x - col) / 2.0
	var card := Vector2(CardArt.BASE_W, CardArt.BASE_H) * CardView.PIXEL_SCALE

	keep_button.size = Vector2(300, 80)
	keep_button.position = Vector2((size.x - 300) / 2.0, size.y - ins.bottom - MARGIN * 1.5 - 80)

	var hand_h := card.y + hand.lift_amount + 16.0
	hand.size = Vector2(col, hand_h)
	hand.position = Vector2(x0, keep_button.position.y - 24.0 - hand_h)

	status_label.position = Vector2(x0, ins.top + MARGIN * 2.0)
	status_label.size = Vector2(col, 80)

	charm_bar.position = Vector2(x0, status_label.position.y + maxf(84.0, status_label.get_minimum_size().y + 4.0))
	charm_bar.size = Vector2(col, charm_bar.size.y)    # width first: the row height depends on it
	charm_bar.size = Vector2(col, charm_bar.height())

	# Mulligan sits left of Keep in the thumb row, only while it can be used.
	mulligan_button.size = Vector2(minf(170.0, keep_button.position.x - x0 - 12.0), 64)
	mulligan_button.position = Vector2(x0, keep_button.position.y + 8.0)

	# starter before the count; the counted row takes the same band after it
	var band_y := charm_bar.position.y + charm_bar.height() + 12.0
	var band_h := card.y + counted_row.lift_amount + 12.0
	starter_view.position = Vector2((size.x - card.x) / 2.0, band_y + band_h - card.y)
	counted_row.position = Vector2(x0, band_y)
	counted_row.size = Vector2(col, band_h)
	cut_view.position = Vector2(x0, starter_view.position.y)
	cut_view.size = Vector2(col, card.y + 80.0)
	# the crib strip sits right of the starter, recut to its left (Foresight only)
	var sx: float = starter_view.position.x
	crib_strip.position = Vector2(sx + card.x + 24.0, band_y + 8.0)
	crib_strip.size = Vector2(maxf(0.0, x0 + col - crib_strip.position.x), band_h - 8.0)
	recut_button.size = Vector2(minf(140.0, sx - x0 - 24.0), 60)
	recut_button.position = Vector2(sx - 24.0 - recut_button.size.x, band_y + band_h / 2.0 - 30.0)

	var top := band_y + band_h + 16.0
	cascade.position = Vector2(x0, top)
	cascade.size = Vector2(col, maxf(0.0, hand.position.y - 16.0 - top))
	drag_hint.position = Vector2(x0, top)
	drag_hint.size = Vector2(col, 0)
	drag_hint.size = Vector2(col, drag_hint.get_minimum_size().y)   # height at this width
	# your Meldling stands in the open space right of the count, above the hand
	var ms := clampf(cascade.size.y * 0.42, 110.0, 200.0)
	meld_sprite.size = Vector2(ms, ms)
	meld_sprite.position = Vector2(x0 + col - ms, hand.position.y - ms - 4.0)
	spoiler_sprite.size = Vector2(ms, ms)
	spoiler_sprite.position = Vector2(x0, hand.position.y - ms - 4.0)


func _label(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	TypeScale.set_size(l, font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build() -> void:
	surface = Surface.make("round")
	add_child(surface)
	Press.watch(self)

	status_label = _label(28, INK)
	add_child(status_label)

	meld_sprite = MeldSprite.new("pip")
	add_child(meld_sprite)
	spoiler_sprite = SpoilerSprite.new()
	spoiler_sprite.hide()
	add_child(spoiler_sprite)
	juice = Juice.new()
	juice.target = self
	add_child(juice)          # in the tree from the start, so it's freed with the screen

	cut_view = CutView.new()
	cut_view.hide()
	add_child(cut_view)

	starter_view = CardView.new()
	starter_view.draggable = false
	add_child(starter_view)
	starter_view.setup(1, "S", false)
	starter_view.mouse_filter = Control.MOUSE_FILTER_IGNORE

	charm_bar = CharmBar.new()
	add_child(charm_bar)

	# first deal ever: one line on dragging, until the first Keep (saved)
	drag_hint = _label(20, Color(0.96, 0.93, 0.88, 0.7))
	drag_hint.text = DRAG_HINT
	drag_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	drag_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	drag_hint.hide()
	add_child(drag_hint)

	crib_strip = CribStrip.new()
	add_child(crib_strip)

	recut_button = Button.new()
	recut_button.text = "Recut"
	TypeScale.set_size(recut_button, 24)
	recut_button.pressed.connect(_on_recut)
	add_child(recut_button)

	counted_row = HandView.new()
	counted_row.max_select = 0
	counted_row.show_hints = false
	add_child(counted_row)
	# After add_child: HandView/CardView reset mouse_filter in _ready. A PASS
	# row on top swallowed clicks meant for the Recut button beneath it.
	counted_row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	cascade = CascadeView.new()
	add_child(cascade)

	hand = HandView.new()
	add_child(hand)
	hand.selection_changed.connect(_on_selection)

	keep_button = Button.new()
	TypeScale.set_size(keep_button, 30)
	keep_button.pressed.connect(_on_button)
	add_child(keep_button)

	mulligan_button = Button.new()
	TypeScale.set_size(mulligan_button, 22)
	mulligan_button.pressed.connect(_on_mulligan)
	add_child(mulligan_button)


## A fresh seeded run and its first round. Tests may pass a prepared run.
func start_round(run_: CribRun = null) -> void:
	run = run_ if run_ != null else CribRun.new(meldling, null, null, seed)
	rd = CribRound.new(run)
	last_result = null
	peg_pending = false
	peg_kept = []
	if peg_view != null:
		remove_child(peg_view)
		peg_view.queue_free()
		peg_view = null
	charm_bar.build(run)
	_layout()
	next_deal()


const DRAG_HINT := "Tip: flick a card up to throw it to the Crib, or down to keep it."
var drag_hint: Label


static func drag_hint_seen() -> bool:
	return JS.truthy(Achv.load_store().get("drag_hint"))


func next_deal() -> void:
	if rd.new_deal() == null:
		if not rd.over:
			rd.settle()
		_show_round_end()
		return
	_show_deal()
	save_point.emit()


## Draw rd.dealt as a fresh deal (also used to resume a saved one).
func _show_deal() -> void:
	peg_kept = []                # a new deal: the last deal's Play is done with
	drag_hint.visible = not drag_hint_seen()
	# Foresight cuts before the keep: show the starter face up from the deal.
	if rd.starter != null:
		starter_view.setup_card(rd.starter, true)
	else:
		starter_view.setup(1, "S", false)
	starter_view.show()
	counted_row.set_cards([], false)
	cascade.clear()
	cut_view.clear()
	cut_view.hide()
	charm_bar.clear_lit()
	crib_strip.refresh(rd)
	crib_strip.show()
	hand.max_select = rd.keep_count()
	if run != null and meld_sprite.meld != MeldReact.art_id(run.meldling):
		meld_sprite.set_meld(run.meldling)
	Sound.play("deal")
	meld_sprite.on_event("deal", rd)
	var boss = run.boss() if run != null else null
	spoiler_sprite.visible = boss != null
	var want := "spoiler" if boss != null else "round"
	if surface.kind != want:
		var s2 := Surface.make(want)
		add_child(s2)
		move_child(s2, surface.get_index())
		surface.queue_free()
		surface = s2
	if boss != null and spoiler_sprite.art != String(boss.art):
		spoiler_sprite.set_boss(boss)
	_update_status()
	keep_button.disabled = true
	keep_button.text = "Keep 0/%d" % rd.keep_count()
	_deal_hand()


## Deal rd.dealt into the hand. Each card is tagged with its index in rd.dealt,
## since the view may reorder its copies.
func _deal_hand() -> void:
	dealing = true                    # controls stay hidden until the cards land
	_refresh_controls()
	var tagged := []
	for i in rd.dealt.size():
		var c := JS.copy(rd.dealt[i])
		c["_i"] = i
		tagged.append(c)
	hand.deal_finished.connect(_on_hand_dealt, CONNECT_ONE_SHOT)
	hand.deal(tagged)


func _on_hand_dealt() -> void:
	dealing = false
	_refresh_controls()
	dealt_ready.emit()


## Mulligan and recut appear only while usable: fewer controls, more flow.
func _refresh_controls() -> void:
	var keeping: bool = rd != null and rd.phase == "keep" and not cascading and not dealing and not rd.over
	mulligan_button.visible = keeping and rd.can_mulligan()
	mulligan_button.text = "Mulligan (%d)" % (rd.mulligans_left if rd != null else 0)
	recut_button.visible = keeping and rd.starter != null and rd.recuts_left > 0


func _on_mulligan() -> void:
	if not mulligan_button.visible or rd.mulligan() == null:
		return
	crib_strip.refresh(rd)
	Sound.play("toCrib")
	keep_button.disabled = true
	keep_button.text = "Keep 0/%d" % rd.keep_count()
	_deal_hand()
	save_point.emit()


func _on_recut() -> void:
	if not recut_button.visible or rd.recut() == null:
		return
	starter_view.setup_card(rd.starter, true)
	_refresh_controls()
	save_point.emit()


## The keep as indices into rd.dealt, ascending.
func selected_keep() -> Array:
	var idx: Array = hand.get_selected_cards().map(func(c): return int(c._i))
	idx.sort()
	return idx


func _on_selection(_cards: Array, verdict: Dictionary) -> void:
	if rd.phase != "keep":
		return
	keep_button.disabled = not verdict.valid
	keep_button.text = "Keep %d/%d" % [verdict.count, verdict.need]
	Sound.play("select")


func _on_button() -> void:
	if cascading:
		cascade.skip()
	elif peg_pending:
		_start_peg()
	elif rd.over:
		if in_run:
			round_finished.emit()
			return
		seed += 1
		start_round()
	elif rd.phase == "keep":
		_commit()
	else:
		next_deal()


func _commit() -> void:
	var idx := selected_keep()
	if idx.size() != rd.keep_count():
		return
	if drag_hint.visible:
		drag_hint.hide()
		var m := Achv.load_store()
		m["drag_hint"] = 1
		Achv.save_store(m)
	var kr := rd.keep_rank(idx)        # rank the DECISION, before the cut is known
	last_kr = kr
	var knew_starter: bool = rd.starter != null
	var kept: Array = idx.map(func(i): return rd.dealt[i])
	var pre_stock: Array = rd.stock.duplicate()   # the web scores the cut against this
	var res = rd.commit(idx)
	Sound.play("toCrib")
	# web doCribCount: the count's deeds, checked on the real commit
	optimal_streak = optimal_streak + 1 if (kr != null and int(kr.get("rank", 0)) == 1) else 0
	var got := Achv.check("count", {
		"total": res.total, "base": res.base,
		"perfect": int(res.base) >= 29 and not JS.truthy(res.get("levelBonus")) and not JS.truthy(res.get("enhBase")),
		"cutJack": rd.starter != null and int(rd.starter.rank) == 11,
		"cutSaved": JS.truthy(res.get("crossedTarget")) and int(res.scoreBefore) + int(res.handOnly) < rd.target,
		"optimalStreak": optimal_streak})
	if not got.is_empty():
		deeds_earned.emit(got)
	committed.emit()
	# the cut's tier, before round end can touch the stock (Foresight: no ceremony)
	last_cut_plan = null if knew_starter else CutPlan.build(CutPlan.quality_like_web(rd, kept, pre_stock))
	last_result = res
	keep_button.disabled = true
	# round end is decided now; only its display waits for the cascade
	# As the web's afterCount: the round ends the moment the target falls or the
	# deals run out.
	# With The Play owed, both wait for it: its gain counts toward the target, and
	# settling first would draw the Crib's Own Cut before the Spoiler's hand.
	peg_pending = PegSession.wanted(rd)
	peg_kept = kept
	if not peg_pending and (rd.score >= rd.target or rd.deals_left <= 0):
		rd.settle()
	save_point.emit()

	mulligan_button.hide()
	recut_button.hide()
	if not knew_starter:
		# the cut ceremony: rolls longer for better cuts; tap anywhere to skip
		starter_view.hide()
		crib_strip.hide()
		cut_view.show()
		cutting = true
		# one-shot connection, not an await (no coroutine outlives the screen)
		cut_view.finished.connect(_after_cut.bind(res, kr), CONNECT_ONE_SHOT)
		cut_view.play(last_cut_plan)
	else:
		_after_flip(res, kr)


func _after_cut(res: Dictionary, kr: Dictionary) -> void:
	cutting = false
	cut_view.hide()
	_after_flip(res, kr)


## Second half of the commit, once the starter is face up.
func _after_flip(res: Dictionary, kr: Dictionary) -> void:
	# kept cards leave the hand; the throws go to the crib
	hand.remove_selected(true)
	while hand.card_count() > 0:
		hand.remove_at(0, true)
	# the counted row is what the engine actually counted (Exchange, Double Cut)
	starter_view.hide()
	crib_strip.hide()
	var shown := []
	for c in res.all:
		shown.append(JS.copy(c))
	counted_row.set_cards(shown, true)
	# counted cards are display only: taps fall through to the skip handler
	for v in counted_row._views:
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE

	cascading = true
	keep_button.text = "Skip"
	keep_button.disabled = false
	counted.emit(res)
	# One-shot connection rather than an await, so no suspended function state
	# outlives the screen if it is freed mid-count.
	cascade.finished.connect(_on_cascade_finished, CONNECT_ONE_SHOT)
	cascade.play(CascadePlan.build(res, rd, kr), _light, charm_bar.light)


func _on_cascade_finished() -> void:
	cascading = false
	# the reaction lands with the total
	if last_result != null:
		meld_sprite.on_event("count", rd, last_result)
		juice_count()
		if spoiler_sprite.visible:
			spoiler_sprite.on_event("count", rd, last_result)
	_update_status()
	if peg_pending:
		keep_button.text = "The Play"
	elif rd.over:
		_show_round_end()
	else:
		keep_button.text = "Next deal"
	cascade_done.emit()


## showPegging: the Play covers the table until CONTINUE.
func _start_peg() -> void:
	if peg_view != null:
		return
	peg_session = PegSession.start(rd, peg_kept)
	peg_view = PegView.new()
	add_child(peg_view)
	peg_view.size = size
	peg_view.open(peg_session)
	peg_view.finished.connect(_on_peg_finished, CONNECT_ONE_SHOT)
	peg_view.changed.connect(func(): save_point.emit())
	save_point.emit()


## What a resume needs beyond the engine state.
func save_ui() -> Dictionary:
	var kept_idx := []
	for c in peg_kept:
		kept_idx.append(JS.index_same(rd.dealt, c))
	return {"kr": last_kr, "peg_pending": peg_pending, "peg_kept": kept_idx}


## Pick a saved round back up: the deal in hand, or the count already made
## (shown at its end state), with The Play owed or in progress.
func resume_round(run_: CribRun, rd_: CribRound, ui: Dictionary, peg = null) -> void:
	run = run_
	rd = rd_
	charm_bar.build(run)
	_layout()
	last_result = rd.last_count
	last_kr = ui.get("kr", {})
	peg_pending = ui.get("peg_pending", false)
	peg_kept = ui.get("peg_kept", []).filter(func(i): return i >= 0 and i < rd.dealt.size()).map(func(i): return rd.dealt[i])
	if rd.phase == "keep":
		_show_deal()
		return
	# counted: the result is in; show it settled, not replayed
	_after_flip(last_result, last_kr)
	cascade.skip()
	if peg != null:
		# saved mid-beat: your card is down, the Spoiler hasn't answered yet
		if not peg.play.over and peg.play.turn == "them":
			peg.answer()
		peg_session = peg
		peg_view = PegView.new()
		add_child(peg_view)
		peg_view.size = size
		peg_view.open(peg_session)
		peg_view.finished.connect(_on_peg_finished, CONNECT_ONE_SHOT)
		peg_view.changed.connect(func(): save_point.emit())


## The Play's CONTINUE: the gain is already in the score. Then exactly the web's
## afterCount test: another deal, or the round ends.
func _on_peg_finished(_gain: int) -> void:
	peg_pending = false
	peg_kept = []
	remove_child(peg_view)
	peg_view.queue_free()
	peg_view = null
	if rd.deals_left > 0 and rd.score < rd.target:
		next_deal()
		return
	if not rd.over:
		rd.settle()
	_update_status()
	if in_run:
		round_finished.emit()
	else:
		_show_round_end()


## Light the counted cards an event used (null = all of them). Split hands
## count with variant copies, so match on suit and either rank, as the web does
## with its rank+suit key.
func _light(cards) -> void:
	for k in counted_row._views.size():
		var v: CardView = counted_row._views[k]
		if cards == null:
			v.set_state(CardView.State.VALID)
			continue
		var hit := false
		for c in cards:
			if c.suit == v.suit and (c.rank == v.rank or (v.rank2 != 0 and c.rank == v.rank2)):
				hit = true
		v.set_state(CardView.State.SELECTED if hit else CardView.State.NORMAL)


## Round-end facts go to the status bar and the button, not under the count:
## the cascade footer stays about the hand that was just counted.
## A big count (the cheer threshold): a burst from the counted hand and a shake.
func juice_count() -> void:
	if last_result == null or rd == null:
		return
	if int(last_result.get("total", 0)) >= MeldReact.big_count(rd):
		move_child(juice, -1)
		var at := counted_row.position + counted_row.size / 2.0
		juice.burst(at, 34, ["gold", "white"])
		juice.shake(8.0, 260.0)


func _show_round_end() -> void:
	meld_sprite.on_event("round_won" if rd.won else "run_lost", rd)
	if spoiler_sprite.visible:
		spoiler_sprite.on_event("round_won" if rd.won else "run_lost", rd)
	_update_status()
	keep_button.text = "Continue" if in_run else "New round"
	keep_button.disabled = false


## The Shortage's HALF stamp (pass 21): a small red tag just after the status
## line's text, landing once per round (1.4 to 1.0, a short shake, a heavy
## note). Only where it fits on the screen; gone when the round is over.
var half_stamp: Label = null
var keep_motion := Motion.new()
var _stamped_rd = null


func _half_stamp(show: bool) -> void:
	if not show:
		if half_stamp != null and is_instance_valid(half_stamp):
			half_stamp.queue_free()
		half_stamp = null
		return
	var font := status_label.get_theme_font("font")
	var fs := status_label.get_theme_font_size("font_size")
	var lines := status_label.text.split("\n")
	var w := font.get_string_size(lines[lines.size() - 1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x := status_label.position.x + (status_label.size.x + w) / 2.0 + 10.0
	var y := status_label.position.y + font.get_height(fs) * (lines.size() - 1)
	var fresh := half_stamp == null or not is_instance_valid(half_stamp)
	if fresh:
		half_stamp = _label(20, Color(0.93, 0.38, 0.38))
		half_stamp.text = "HALF"
		half_stamp.name = "half_stamp"
		add_child(half_stamp)
	var sw := font.get_string_size("HALF", HORIZONTAL_ALIGNMENT_LEFT, -1, half_stamp.get_theme_font_size("font_size")).x + 4.0
	if x + sw > size.x - 4.0:
		half_stamp.queue_free()      # no room beside the text: the status already names it
		half_stamp = null
		return
	half_stamp.size = Vector2(sw, font.get_height(fs))
	half_stamp.position = Vector2(x, y + (font.get_height(fs) - half_stamp.get_combined_minimum_size().y) / 2.0)
	if _stamped_rd == rd or not Motion.on():
		return
	_stamped_rd = rd
	Sound.play("spoiler_peg")
	if Motion.reduced():
		keep_motion.fade_in(half_stamp)
		return
	var st := half_stamp
	var rest: Vector2 = st.position
	st.pivot_offset = st.size / 2.0
	st.scale = Vector2.ONE * 1.4
	var tw := st.create_tween()
	tw.tween_property(st, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	for dx in [4.0, -3.0, 2.0, 0.0]:
		tw.tween_property(st, "position", rest + Vector2(dx, 0), 0.04)
	keep_motion.add(tw, func():
		if is_instance_valid(st):
			st.scale = Vector2.ONE
			st.position = rest)


func _update_status() -> void:
	var second := "Deals left %d" % rd.deals_left
	var tw = run.twist() if run != null else null
	var sh = run.shortage() if run != null else null
	if sh != null and not rd.over:
		second += "  |  Short: " + CribData.SHORTAGE_NAMES[sh]   # the Shortage, kept in sight
	elif tw != null and not rd.over:
		second += "  |  " + String(tw.name)     # the round's twist, kept in sight
	if rd.over:
		var crib: int = rd.crib_result.total if rd.crib_result != null else 0
		second = "%s  |  Crib +%d" % ["Round cleared" if rd.won else "Round lost", crib]
	status_label.text = "%s  |  Target %d  |  Score %d\n%s" % [run.deck.name, rd.target, rd.score, second]
	_half_stamp(sh != null and not rd.over)


## During a count the whole screen is the skip button: the thumb shouldn't
## have to aim. Continuing still uses the button, so a stray tap can't deal.
## A tap lands the HALF stamp (it never stops the tap).
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and keep_motion.running():
		keep_motion.skip()


func _gui_input(event: InputEvent) -> void:
	if (cascading or cutting) and event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if cutting:
			cut_view.skip()
		else:
			cascade.skip()
		accept_event()


## Pass 21: no animation outlives its screen (a running job would keep a
## reference cycle alive: screen_leak_test).
func _exit_tree() -> void:
	keep_motion.skip()
