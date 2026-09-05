class_name GameOverScreen
extends Screen

var _banked: bool = false


func build() -> void:
	var victory: bool = run().last_result == "victory"

	var body := UIKit.screen_body(20)
	add_child(body)
	var col := UIKit.vbox(12)
	body.add_child(col)

	col.add_child(UIKit.spacer(30, false))
	col.add_child(UIKit.title("RUN COMPLETE" if victory else "RUN ENDED", 34,
			UIKit.GOLD if victory else UIKit.RED))

	var cv := CreatureView.new()
	cv.pixel_scale = 5
	cv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(cv)
	cv.setup(run().meldling if victory else "kingpin")

	col.add_child(UIKit.spacer(6, false))

	var stats := UIKit.panel()
	col.add_child(stats)
	var sv := UIKit.vbox(6)
	stats.add_child(sv)

	var bonus: int = 40 if victory else 0
	var total: int = run().essence_earned + bonus

	sv.add_child(_row("Floors cleared", str(run().visited.size())))
	sv.add_child(_row("Relics carried", str(run().relics.size())))
	sv.add_child(_row("Essence earned", str(run().essence_earned)))
	if victory:
		sv.add_child(_row("Victory bonus", "+%d" % bonus))
	sv.add_child(_row("Banked", str(total)))

	col.add_child(UIKit.spacer(0, true))

	var again := UIKit.button("New Run", 20, 58)
	again.pressed.connect(func():
		_bank(total)
		audio().sfx("meld_prep")
		game.goto("select"))
	col.add_child(again)

	var home := UIKit.button("Title", 16, 48)
	home.pressed.connect(func():
		_bank(total)
		audio().sfx("ui_click")
		game.goto("title"))
	col.add_child(home)

	col.add_child(UIKit.spacer(10, false))


func _row(k: String, v: String) -> Control:
	var h := UIKit.hbox(8)
	h.add_child(UIKit.label(k, 15, UIKit.DIM))
	h.add_child(UIKit.label(v, 15, UIKit.INK, HORIZONTAL_ALIGNMENT_RIGHT))
	return h


func on_shown() -> void:
	audio().sfx("victory" if run().last_result == "victory" else "defeat")
	audio().music("bgm_menu")


func _bank(total: int) -> void:
	if _banked:
		return
	_banked = true
	SaveManager.add_essence(total)
	if run().last_result == "victory":
		SaveManager.unlock(run().meldling)
