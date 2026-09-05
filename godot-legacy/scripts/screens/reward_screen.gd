class_name RewardScreen
extends Screen

## Post-battle (or treasure) relic pick. `treasure` is set by GameRoot.

var treasure: bool = false
var _offers: Array = []
var _taken: bool = false


func build() -> void:
	_offers = run().offer_relics(3)

	var body := UIKit.screen_body(20)
	add_child(body)
	var col := UIKit.vbox(12)
	body.add_child(col)

	col.add_child(UIKit.spacer(10, false))
	col.add_child(UIKit.title("CACHE FOUND" if treasure else "VICTORY", 32))
	col.add_child(UIKit.label("Choose one.", 15, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))

	if not treasure:
		col.add_child(UIKit.label("%d / %d HP   ·   %d Essence" %
				[run().hp, run().max_hp, run().essence_earned],
				15, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))

	col.add_child(UIKit.spacer(8, false))

	if _offers.is_empty():
		col.add_child(UIKit.label("Nothing left to find.", 16, UIKit.DIM,
				HORIZONTAL_ALIGNMENT_CENTER))
	for relic in _offers:
		col.add_child(_relic_card(relic))

	col.add_child(UIKit.spacer(0, true))

	var skip := UIKit.button("Skip", 16, 48)
	skip.pressed.connect(func():
		audio().sfx("ui_click")
		game.goto("map"))
	col.add_child(skip)


func on_shown() -> void:
	if not treasure:
		audio().music("bgm_menu")


func _relic_card(relic: Dictionary) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 84)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	UIKit._style_button(b)
	b.pressed.connect(_take.bind(relic))

	var v := UIKit.vbox(2)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 14
	v.offset_right = -14
	v.offset_top = 10
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	v.add_child(UIKit.label(relic.get("name", "?"), 20, UIKit.GOLD))
	v.add_child(UIKit.wrap_label(relic.get("text", ""), 220, 14, UIKit.DIM,
			HORIZONTAL_ALIGNMENT_LEFT))
	return b


func _take(relic: Dictionary) -> void:
	if _taken:
		return
	_taken = true
	run().add_relic(relic)
	audio().sfx("relic")
	await get_tree().create_timer(0.45).timeout
	game.goto("map")

