class_name BattleScreen
extends Screen

var combat: Combat
var _busy: bool = false

var hero: CreatureView
var foe: CreatureView
var hand: HandView
var draw_pile: PileView
var discard_pile: PileView

var foe_name: Label
var foe_hp: Label
var foe_bar: ProgressBar
var foe_status: Label
var intent: Label
var you_hp: Label
var you_bar: ProgressBar
var you_status: Label
var focus_label: Label
var banner: Label
var action_label: Label
var play_btn: Button
var cycle_btn: Button
var end_btn: Button
var _prev_sel: int = 0


func build() -> void:
	combat = Combat.new()
	combat.setup(run(), run().current_enemy)
	combat.log_line.connect(_flash)
	combat.battle_ended.connect(_on_battle_ended)

	var body := UIKit.screen_body(12)
	add_child(body)
	var col := UIKit.vbox(8)
	body.add_child(col)

	# ---------------- enemy panel
	var ep := UIKit.panel(UIKit.PANEL, 10, 8)
	col.add_child(ep)
	var ev := UIKit.vbox(4)
	ep.add_child(ev)

	var erow := UIKit.hbox(8)
	ev.add_child(erow)
	foe_name = UIKit.label("", 18, UIKit.INK)
	erow.add_child(foe_name)
	foe_hp = UIKit.label("", 18, UIKit.RED, HORIZONTAL_ALIGNMENT_RIGHT)
	erow.add_child(foe_hp)

	foe_bar = UIKit.bar(UIKit.RED, 12)
	ev.add_child(foe_bar)
	foe_status = UIKit.label("", 13, UIKit.BLUE)
	ev.add_child(foe_status)
	intent = UIKit.label("", 14, UIKit.GOLD)
	ev.add_child(intent)

	# ---------------- arena
	var arena := UIKit.hbox(20)
	arena.alignment = BoxContainer.ALIGNMENT_CENTER
	arena.custom_minimum_size.y = 170
	col.add_child(arena)

	hero = CreatureView.new()
	hero.pixel_scale = 3
	arena.add_child(hero)
	hero.setup(run().meldling)

	action_label = UIKit.label("", 22, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	arena.add_child(action_label)

	foe = CreatureView.new()
	foe.pixel_scale = 3
	foe.flip_h = true
	arena.add_child(foe)
	foe.setup(run().current_enemy)

	# ---------------- player panel
	var pp := UIKit.panel(UIKit.PANEL, 10, 8)
	col.add_child(pp)
	var pv := UIKit.vbox(4)
	pp.add_child(pv)

	var prow := UIKit.hbox(8)
	pv.add_child(prow)
	prow.add_child(UIKit.label(CreatureDB.display_name(run().meldling), 17, UIKit.INK))
	focus_label = UIKit.label("", 17, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	prow.add_child(focus_label)
	you_hp = UIKit.label("", 17, UIKit.GREEN, HORIZONTAL_ALIGNMENT_RIGHT)
	prow.add_child(you_hp)

	you_bar = UIKit.bar(UIKit.GREEN, 12)
	pv.add_child(you_bar)
	you_status = UIKit.label("", 13, UIKit.BLUE)
	pv.add_child(you_status)

	# ---------------- piles
	var piles := UIKit.hbox(28)
	piles.alignment = BoxContainer.ALIGNMENT_CENTER
	piles.custom_minimum_size.y = CardArt.BASE_H * CardView.PIXEL_SCALE + 24
	col.add_child(piles)

	draw_pile = PileView.new()
	draw_pile.mode = PileView.Mode.DRAW
	draw_pile.label_text = "DRAW"
	draw_pile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	piles.add_child(draw_pile)

	discard_pile = PileView.new()
	discard_pile.mode = PileView.Mode.DISCARD
	discard_pile.label_text = "DISCARD"
	discard_pile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	discard_pile.card_dropped.connect(_on_card_dropped)
	piles.add_child(discard_pile)

	banner = UIKit.label("Tap cards to build a meld", 15, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(banner)

	col.add_child(UIKit.spacer(0, true))

	# ---------------- hand
	hand = HandView.new()
	hand.custom_minimum_size.y = CardArt.BASE_H * CardView.PIXEL_SCALE + 32
	hand.fan_tilt_deg = 2.0
	hand.selection_changed.connect(_on_selection_changed)
	col.add_child(hand)

	# ---------------- buttons
	var bar1 := UIKit.hbox(6)
	col.add_child(bar1)
	bar1.add_child(_btn("Sort", func(): hand.sort_by_rank(); audio().sfx("ui_click")))
	bar1.add_child(_btn("Suit", func(): hand.sort_by_suit(); audio().sfx("ui_click")))
	bar1.add_child(_btn("Hint", _on_hint))

	var bar2 := UIKit.hbox(6)
	col.add_child(bar2)
	play_btn = _btn("PLAY MELD", _on_play, 18, 58)
	play_btn.disabled = true
	bar2.add_child(play_btn)
	cycle_btn = _btn("Cycle", _on_cycle, 16, 58)
	bar2.add_child(cycle_btn)
	end_btn = _btn("End Turn", _on_end_turn, 16, 58)
	bar2.add_child(end_btn)

	hand.set_cards(combat.hand)
	hand.sort_by_rank()
	_refresh()


func _btn(text: String, cb: Callable, size_px: int = 16, h: int = 46) -> Button:
	var b := UIKit.button(text, size_px, h)
	b.pressed.connect(cb)
	return b


func on_shown() -> void:
	audio().music(CreatureDB.music_for(run().current_enemy))
	draw_pile.shuffle_flourish()


# ------------------------------------------------------------------ refresh
func _refresh() -> void:
	foe_name.text = combat.enemy.display_name
	foe_hp.text = "%d / %d" % [combat.enemy.hp, combat.enemy.max_hp]
	foe_bar.value = 100.0 * combat.enemy.hp / maxf(1.0, combat.enemy.max_hp)
	foe_status.text = combat.enemy.status_line()
	intent.text = combat.intent_text()

	you_hp.text = "%d / %d" % [combat.player.hp, combat.player.max_hp]
	you_bar.value = 100.0 * combat.player.hp / maxf(1.0, combat.player.max_hp)
	you_status.text = combat.player.status_line()
	focus_label.text = "FOCUS %d / %d   ·   TURN %d" % [combat.focus, combat.max_focus, combat.turn]

	draw_pile.tick_count(combat.deck.size())
	if not combat.discard.is_empty():
		discard_pile.set_top_card(combat.discard[-1])

	var can_act: bool = combat.focus > 0 and not combat.over and not _busy
	cycle_btn.disabled = not can_act
	end_btn.disabled = _busy or combat.over
	if not can_act:
		play_btn.disabled = true


func _flash(msg: String) -> void:
	banner.text = msg
	banner.modulate.a = 0.35
	create_tween().tween_property(banner, "modulate:a", 1.0, 0.24)


func _set_action(text: String) -> void:
	action_label.text = text
	action_label.pivot_offset = action_label.size * 0.5
	action_label.scale = Vector2.ONE * 1.3
	create_tween().tween_property(action_label, "scale", Vector2.ONE, 0.24) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ------------------------------------------------------------------ input
func _on_selection_changed(cards: Array, verdict: Dictionary) -> void:
	play_btn.disabled = not verdict.valid or combat.focus <= 0 or _busy or combat.over
	if cards.size() > _prev_sel:
		audio().sfx("card_select", 0.0, 1.0 + cards.size() * 0.05)
	elif cards.size() < _prev_sel:
		audio().sfx("card_deselect")
	_prev_sel = cards.size()

	if cards.is_empty():
		banner.text = "Tap cards to build a meld"
		action_label.text = ""
	elif verdict.valid:
		banner.text = "%s  →  %s" % [verdict.label, verdict.action]
		_set_action(verdict.action)
	else:
		banner.text = "%d selected · %s" % [cards.size(), verdict.label]
		action_label.text = "—"


func _on_hint() -> void:
	if hand.autoselect_best_meld():
		audio().sfx("relic", -6.0)
	else:
		_flash("No meld available — Cycle to draw.")
		audio().sfx("card_invalid")


func _on_card_dropped(card: Dictionary, source: CardView) -> void:
	var i := hand.index_of_view(source)
	if i >= 0 and combat.focus > 0 and not _busy:
		_discard_one(i)


func _on_cycle() -> void:
	if _busy or combat.focus <= 0:
		return
	var sel := hand.get_selected_indices()
	if sel.size() == 1:
		_discard_one(sel[0])
	else:
		_flash("Select one card to cycle it away.")
		audio().sfx("card_invalid")


func _discard_one(index: int) -> void:
	_busy = true
	var from := hand.slot_global_position(index)
	var card := hand.remove_at(index, false)
	combat.discard_card(index)
	_prev_sel = 0
	audio().sfx("card_place")
	await game.anim.fly_discard(card, from, discard_pile.card_global_position())
	discard_pile.receive(card)

	combat.spend_focus_to_cycle()
	_sync_hand_additions()
	_busy = false
	_refresh()


func _sync_hand_additions() -> void:
	## combat.hand is the source of truth; mirror any cards it gained.
	while hand.card_count() < combat.hand.size():
		var idx := hand.card_count()
		var card: Dictionary = combat.hand[idx]
		var to := hand.next_slot_global_position()
		hand.append_card(card, true)
		draw_pile.punch()
		draw_pile.tick_count(combat.deck.size())
		audio().sfx("card_draw", -4.0)
		var landed := game.anim.fly_draw(card, draw_pile.card_global_position(), to)
		var i := idx
		landed.connect(func(): hand.reveal_at(i, false), CONNECT_ONE_SHOT)


func _on_play() -> void:
	if _busy or combat.over:
		return
	var cards := hand.get_selected_cards()
	var verdict := MeldRules.classify(cards)
	if not verdict.valid or combat.focus <= 0:
		audio().sfx("card_invalid")
		return

	_busy = true
	play_btn.disabled = true
	var idx := hand.get_selected_indices()
	var starts: Array = []
	for i in idx:
		starts.append(hand.slot_global_position(i))

	combat.take_from_hand(idx)
	var played := hand.remove_selected(false)
	_prev_sel = 0

	var focus_pt: Vector2 = get_global_rect().get_center() - Vector2(0, 40)
	var target: Vector2 = foe.global_position + foe.size * 0.5
	var offensive: bool = verdict.kind in [MeldRules.Kind.RUN, MeldRules.Kind.SET,
			MeldRules.Kind.GRAND]

	audio().sfx_for_action(verdict.action)
	if verdict.kind == MeldRules.Kind.GRAND:
		audio().duck(-9.0, 0.15, 1.1)
	await game.anim.fly_meld(played, starts, focus_pt, target, offensive)

	var result := combat.play_meld(played)

	if offensive:
		hero.attack()
		await get_tree().create_timer(0.16).timeout
		foe.hurt()
		game.anim.impact(target, Color(1, 0.86, 0.42),
			10 if verdict.kind == MeldRules.Kind.GRAND else 6)
		audio().sfx("hit_heavy" if verdict.kind == MeldRules.Kind.GRAND else "hit_light")
		_shake(5.0 if verdict.kind == MeldRules.Kind.GRAND else 3.0)
	else:
		hero.attack()
		game.anim.impact(hero.global_position + hero.size * 0.5, UIKit.BLUE, 6)
		audio().sfx("block", -4.0)

	if not combat.discard.is_empty():
		discard_pile.receive(combat.discard[-1])
	_sync_hand_additions()
	_busy = false
	_refresh()


func _on_end_turn() -> void:
	if _busy or combat.over:
		return
	_busy = true
	hand.clear_selection()
	_prev_sel = 0
	_flash("%s acts…" % combat.enemy.display_name)
	await get_tree().create_timer(0.35).timeout

	var events := combat.end_turn()
	for e in events:
		match e.t:
			"hit":
				foe.attack()
				await get_tree().create_timer(0.18).timeout
				hero.hurt()
				game.anim.impact(hero.global_position + hero.size * 0.5, UIKit.RED, 7)
				audio().sfx("hit_heavy" if e.n > 10 else "hit_light")
				_shake(4.0)
				_flash("%s hits you for %d." % [combat.enemy.display_name, e.n])
			"block":
				foe.attack()
				audio().sfx("block", -4.0)
				_flash("%s braces for %d." % [combat.enemy.display_name, e.n])
			"burn":
				audio().sfx("burn")
				if e.who == "player":
					hero.hurt()
				else:
					foe.hurt()
				_flash("Burn deals %d." % e.n)
			"hex":
				audio().sfx("hex")
				_flash("You are Hexed (%d)." % e.n)
			"burn_applied":
				audio().sfx("burn", -6.0)
		_refresh()
		await get_tree().create_timer(0.42).timeout

	_sync_hand_additions()
	_busy = false
	_refresh()
	if not combat.over:
		_flash("Your turn — Focus restored.")


func _shake(strength: float = 4.0, dur: float = 0.22) -> void:
	var tw := create_tween()
	for i in 5:
		var s := strength * (1.0 - float(i) / 5.0)
		tw.tween_property(self, "position",
			Vector2(randf_range(-s, s), randf_range(-s, s)), dur / 5.0)
	tw.tween_property(self, "position", Vector2.ZERO, dur / 5.0)


# ------------------------------------------------------------------ end
func _on_battle_ended(victory: bool) -> void:
	combat.sync_to_run()
	await get_tree().create_timer(0.7).timeout
	if victory:
		foe.hurt()
		audio().sfx("victory")
		_flash("%s falls!" % combat.enemy.display_name)
	else:
		hero.hurt()
		audio().sfx("defeat")
		_flash("You are overwhelmed…")
	await get_tree().create_timer(1.4).timeout
	game.finish_battle(victory)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		hand.clear_selection()
