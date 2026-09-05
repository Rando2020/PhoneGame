class_name SandboxScreen
extends BattleScreen

## TRAINING. This IS a real battle -- it extends BattleScreen, so every button
## exercises the shipping combat code. The drawer just lets you force any
## situation instead of waiting for the shuffle to give it to you.
##
## The point: answer "is bracing-to-build ever correct?" by setting the position
## deliberately, rather than replaying runs hoping it comes up.

const RANKS := ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]

var _drawer: PanelContainer
var _open: bool = false
var _preview: Label
var _toggle: Button
var _rank_pick: OptionButton
var _suit_pick: OptionButton
var _enemy_pick: OptionButton


func build() -> void:
	super.build()
	_build_drawer()
	_build_toggle()


# ------------------------------------------------------------------ drawer
func _build_toggle() -> void:
	_toggle = UIKit.button("⚙ TRAINING", 14, 34)
	_toggle.size_flags_horizontal = Control.SIZE_SHRINK_END
	_toggle.custom_minimum_size.x = 140
	_toggle.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_toggle.position = Vector2(-150, 4)
	_toggle.z_index = 60
	_toggle.pressed.connect(_toggle_drawer)
	add_child(_toggle)


func _build_drawer() -> void:
	_drawer = UIKit.panel(Color(0.10, 0.09, 0.16, 0.98), 12, 10)
	_drawer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_drawer.offset_top = 44
	_drawer.offset_left = 10
	_drawer.offset_right = -10
	_drawer.offset_bottom = -10
	_drawer.z_index = 50
	_drawer.visible = false
	add_child(_drawer)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_drawer.add_child(scroll)

	var col := UIKit.vbox(8)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)

	col.add_child(UIKit.label("TRAINING", 20, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	_preview = UIKit.wrap_label("Select cards to see what they'd do.", 240, 14, UIKit.BLUE)
	col.add_child(_preview)

	# ---- one-tap melds. The most useful thing in here.
	col.add_child(_head("Deal me a meld"))
	var m1 := UIKit.hbox(5)
	col.add_child(m1)
	m1.add_child(_mini("Pair", func(): _give([[7, "H"], [7, "S"]])))
	m1.add_child(_mini("2-Run", func(): _give([[5, "D"], [6, "D"]])))
	m1.add_child(_mini("3-Run", func(): _give([[4, "H"], [5, "H"], [6, "H"]])))

	var m2 := UIKit.hbox(5)
	col.add_child(m2)
	m2.add_child(_mini("5-Run", func(): _give([[3, "C"], [4, "C"], [5, "C"], [6, "C"], [7, "C"]])))
	m2.add_child(_mini("3-Set", func(): _give([[9, "H"], [9, "S"], [9, "C"]])))
	m2.add_child(_mini("GRAND", func(): _give([[12, "S"], [12, "H"], [12, "C"], [12, "D"]])))

	# ---- exact card
	col.add_child(_head("Exact card"))
	var cardrow := UIKit.hbox(5)
	col.add_child(cardrow)

	_rank_pick = OptionButton.new()
	_rank_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for r in RANKS:
		_rank_pick.add_item(r)
	_rank_pick.selected = 6
	cardrow.add_child(_rank_pick)

	_suit_pick = OptionButton.new()
	_suit_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in 4:
		_suit_pick.add_item("%s %s" % [CardArt.SUIT_SYMBOLS[CardArt.SUIT_LETTERS[i]],
				CardArt.SUIT_NAMES[i]])
	cardrow.add_child(_suit_pick)

	cardrow.add_child(_mini("Add", func():
		_give([[_rank_pick.selected + 1, CardArt.SUIT_LETTERS[_suit_pick.selected]]])))

	# ---- opponent
	col.add_child(_head("Opponent"))
	_enemy_pick = OptionButton.new()
	_enemy_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ids: Array = []
	for id in CreatureDB.ROSTER:
		if CreatureDB.ROSTER[id].get("kind", "") != "meldling":
			ids.append(id)
	for id in ids:
		_enemy_pick.add_item(CreatureDB.display_name(id))
	_enemy_pick.item_selected.connect(func(i: int): _swap_enemy(ids[i]))
	col.add_child(_enemy_pick)

	var hp := UIKit.hbox(5)
	col.add_child(hp)
	hp.add_child(_mini("Foe 10hp", func(): _set_foe_hp(10)))
	hp.add_child(_mini("Foe 1hp", func(): _set_foe_hp(1)))
	hp.add_child(_mini("Foe full", func(): _set_foe_hp(combat.enemy.max_hp)))

	# ---- resources
	col.add_child(_head("Resources"))
	var res := UIKit.hbox(5)
	col.add_child(res)
	res.add_child(_mini("+3 Focus", func(): combat.focus += 3; _refresh()))
	res.add_child(_mini("+20 HP", func():
		combat.player.hp = mini(combat.player.max_hp, combat.player.hp + 20); _refresh()))
	res.add_child(_mini("Draw 3", func():
		combat.draw_to_hand(3); _sync_hand_additions(); _refresh()))

	var st := UIKit.hbox(5)
	col.add_child(st)
	st.add_child(_mini("+5 Burn", func(): combat.player.burn += 5; _refresh()))
	st.add_child(_mini("+3 Hex", func(): combat.player.hex += 3; _refresh()))
	st.add_child(_mini("+5 Thorns", func(): combat.player.thorns += 5; _refresh()))

	# ---- relics
	col.add_child(_head("Relics"))
	for relic in RunState.RELICS:
		var b := UIKit.button("%s — %s" % [relic["name"], relic["text"]], 12, 38)
		b.pressed.connect(func():
			if not run().has_relic(relic["id"]):
				run().add_relic(relic)
				audio().sfx("relic", -8.0)
				b.disabled = true
				_update_preview())
		b.disabled = run().has_relic(relic["id"])
		col.add_child(b)

	# ---- flow
	col.add_child(_head("Flow"))
	var flow := UIKit.hbox(5)
	col.add_child(flow)
	flow.add_child(_mini("Win", func(): combat.force_end(true)))
	flow.add_child(_mini("Lose", func(): combat.force_end(false)))
	flow.add_child(_mini("Restart", func(): game.goto("sandbox")))

	col.add_child(UIKit.spacer(6, false))
	var back := UIKit.button("Leave Training", 15, 44)
	back.pressed.connect(func():
		audio().sfx("ui_click")
		game.goto("title"))
	col.add_child(back)
	col.add_child(UIKit.spacer(10, false))


func _head(text: String) -> Label:
	return UIKit.label(text, 14, UIKit.GOLD)


func _mini(text: String, cb: Callable) -> Button:
	var b := UIKit.button(text, 13, 36)
	b.pressed.connect(cb)
	return b


func _toggle_drawer() -> void:
	_open = not _open
	_drawer.visible = _open
	_toggle.text = "✕ CLOSE" if _open else "⚙ TRAINING"
	audio().sfx("ui_click")
	if _open:
		_update_preview()


# ------------------------------------------------------------------ actions
func _give(cards: Array) -> void:
	for c in cards:
		combat.inject_card(c[0], c[1])
	_sync_hand_additions()
	audio().sfx("card_draw", -6.0)
	_refresh()


func _swap_enemy(id: String) -> void:
	combat.set_enemy(id)
	foe.setup(id)
	run().current_enemy = id
	audio().sfx("meld_strike", -6.0)
	_refresh()


func _set_foe_hp(n: int) -> void:
	combat.enemy.hp = clampi(n, 0, combat.enemy.max_hp)
	_refresh()
	if combat.enemy.hp <= 0:
		combat.force_end(true)


func _update_preview() -> void:
	if _preview == null or combat == null:
		return
	var sel := hand.get_selected_cards()
	if sel.is_empty():
		_preview.text = "Select cards to see what they'd do."
	else:
		_preview.text = combat.preview_meld(sel)


func _on_selection_changed(cards: Array, verdict: Dictionary) -> void:
	super._on_selection_changed(cards, verdict)
	_update_preview()


## Training never ends the run -- it just resets, so you can keep testing.
func _on_battle_ended(victory: bool) -> void:
	_flash("%s — resetting." % ("Victory" if victory else "Defeat"))
	audio().sfx("victory" if victory else "defeat")
	await get_tree().create_timer(1.2).timeout
	game.goto("sandbox")
