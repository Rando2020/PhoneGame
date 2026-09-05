class_name RestScreen
extends Screen

var _done: bool = false


func build() -> void:
	var body := UIKit.screen_body(20)
	add_child(body)
	var col := UIKit.vbox(12)
	body.add_child(col)

	col.add_child(UIKit.spacer(20, false))
	col.add_child(UIKit.title("A QUIET SHUFFLE", 30))
	col.add_child(UIKit.label("%d / %d HP" % [run().hp, run().max_hp],
			18, UIKit.GREEN, HORIZONTAL_ALIGNMENT_CENTER))

	var cv := CreatureView.new()
	cv.pixel_scale = 4
	cv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(cv)
	cv.setup(run().meldling)

	col.add_child(UIKit.spacer(0, true))

	var heal_amount: int = maxi(8, int(run().max_hp * 0.32))
	var rest := UIKit.button("Rest — heal %d HP" % heal_amount, 18, 58)
	rest.pressed.connect(func(): _choose("heal", heal_amount, cv))
	col.add_child(rest)

	var train := UIKit.button("Train — +6 max HP", 18, 58)
	train.pressed.connect(func(): _choose("train", 6, cv))
	col.add_child(train)

	col.add_child(UIKit.spacer(10, false))


func on_shown() -> void:
	audio().music("bgm_menu")


func _choose(kind: String, amount: int, cv: CreatureView) -> void:
	if _done:
		return
	_done = true
	if kind == "heal":
		run().heal(amount)
		audio().sfx("level_up")
	else:
		run().max_hp += amount
		run().heal(amount)
		audio().sfx("meld_grand")
	cv.play_once("attack")
	await get_tree().create_timer(0.6).timeout
	game.goto("map")
