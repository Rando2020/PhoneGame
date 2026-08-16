class_name OptionsScreen
extends Screen

var _confirm_wipe: bool = false
var _wipe_btn: Button


func build() -> void:
	var body := UIKit.screen_body(20)
	add_child(body)
	var col := UIKit.vbox(14)
	body.add_child(col)

	col.add_child(UIKit.spacer(20, false))
	col.add_child(UIKit.title("OPTIONS", 32))
	col.add_child(UIKit.spacer(10, false))

	col.add_child(_slider("Music", SaveManager.music_volume, func(v):
		SaveManager.music_volume = v
		game.apply_volumes()))

	col.add_child(_slider("Sound", SaveManager.sfx_volume, func(v):
		SaveManager.sfx_volume = v
		game.apply_volumes()
		audio().sfx("ui_click")))

	col.add_child(UIKit.spacer(8, false))

	var fs := UIKit.button("Toggle Fullscreen  (F11)", 16, 50)
	fs.pressed.connect(func():
		var m := DisplayServer.window_get_mode()
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_WINDOWED if m == DisplayServer.WINDOW_MODE_FULLSCREEN
			else DisplayServer.WINDOW_MODE_FULLSCREEN)
		audio().sfx("ui_click"))
	col.add_child(fs)

	col.add_child(UIKit.spacer(0, true))

	col.add_child(UIKit.wrap_label(
		"Essence %d   ·   Vitality %d / %d" %
		[SaveManager.essence, SaveManager.vitality, SaveManager.VITALITY_CAP],
		240, 14, UIKit.DIM))

	_wipe_btn = UIKit.button("Erase Progress", 15, 46)
	_wipe_btn.pressed.connect(_on_wipe)
	col.add_child(_wipe_btn)

	var back := UIKit.button("Back", 18, 54)
	back.pressed.connect(func():
		SaveManager.save_game()
		audio().sfx("ui_click")
		game.goto("title"))
	col.add_child(back)

	col.add_child(UIKit.spacer(10, false))


func _slider(name: String, value: float, on_change: Callable) -> Control:
	var box := UIKit.vbox(4)
	var readout := UIKit.label("%s   %d%%" % [name, int(value * 100)], 16, UIKit.INK)
	box.add_child(readout)

	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(0, 30)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.focus_mode = Control.FOCUS_NONE
	s.value_changed.connect(func(v: float):
		readout.text = "%s   %d%%" % [name, int(v * 100)]
		on_change.call(v))
	box.add_child(s)
	return box


func _on_wipe() -> void:
	if not _confirm_wipe:
		_confirm_wipe = true
		_wipe_btn.text = "Really erase? Tap again."
		audio().sfx("card_invalid")
		return
	SaveManager.wipe()
	_confirm_wipe = false
	_wipe_btn.text = "Progress erased"
	_wipe_btn.disabled = true
	audio().sfx("defeat")


func on_shown() -> void:
	audio().music("bgm_menu")
