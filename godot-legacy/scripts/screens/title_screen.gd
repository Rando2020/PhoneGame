class_name TitleScreen
extends Screen

var _essence_label: Label
var _vit_label: Label
var _buy: Button


func build() -> void:
	var body := UIKit.screen_body(20)
	add_child(body)

	var col := UIKit.vbox(14)
	body.add_child(col)

	col.add_child(UIKit.spacer(20, false))
	col.add_child(UIKit.title("MELDLINGS", 46))
	col.add_child(UIKit.label("Learn Rummy. Master Rummy. Break Rummy.",
			15, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))

	# roster parade
	var parade := UIKit.hbox(6)
	parade.alignment = BoxContainer.ALIGNMENT_CENTER
	parade.custom_minimum_size.y = 150
	col.add_child(parade)
	for id in CreatureDB.meldlings():
		var c := CreatureView.new()
		c.pixel_scale = 3
		parade.add_child(c)
		c.setup(id)

	col.add_child(UIKit.spacer(0, true))

	# --- sanctum: spend Essence on Vitality
	var sanctum := UIKit.panel()
	col.add_child(sanctum)
	var sv := UIKit.vbox(8)
	sanctum.add_child(sv)
	sv.add_child(UIKit.label("SANCTUM", 16, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))

	_essence_label = UIKit.label("", 15, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	sv.add_child(_essence_label)
	_vit_label = UIKit.label("", 14, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	sv.add_child(_vit_label)

	_buy = UIKit.button("Raise Vitality", 16, 46)
	_buy.pressed.connect(_on_buy)
	sv.add_child(_buy)

	col.add_child(UIKit.spacer(6, false))

	var play := UIKit.button("BEGIN RUN", 24, 62)
	play.pressed.connect(func():
		audio().sfx("meld_prep")
		game.goto("select", {"mode": "run"}))
	col.add_child(play)

	var gauntlet := UIKit.button("GAUNTLET  ·  demo run", 17, 50)
	gauntlet.pressed.connect(func():
		audio().sfx("meld_rally")
		game.goto("select", {"mode": "gauntlet"}))
	col.add_child(gauntlet)

	var train := UIKit.button("TRAINING  ·  sandbox", 17, 50)
	train.pressed.connect(func():
		audio().sfx("meld_prep")
		game.goto("select", {"mode": "training"}))
	col.add_child(train)

	var opts := UIKit.button("Options", 18, 50)
	opts.pressed.connect(func():
		audio().sfx("ui_click")
		game.goto("options"))
	col.add_child(opts)

	if OS.get_name() not in ["Web", "Android", "iOS"]:
		var quit := UIKit.button("Quit", 18, 50)
		quit.pressed.connect(func(): game._shortcut_quit())
		col.add_child(quit)

	col.add_child(UIKit.spacer(10, false))
	_refresh()


func on_shown() -> void:
	audio().music("bgm_menu")


func _refresh() -> void:
	_essence_label.text = "Essence  %d" % SaveManager.essence
	_vit_label.text = "Vitality %d / %d   (+%d max HP)" % [
		SaveManager.vitality, SaveManager.VITALITY_CAP, SaveManager.bonus_hp()]
	if SaveManager.vitality >= SaveManager.VITALITY_CAP:
		_buy.text = "Vitality maxed"
		_buy.disabled = true
	else:
		_buy.text = "Raise Vitality — %d Essence" % SaveManager.vitality_cost()
		_buy.disabled = not SaveManager.can_buy_vitality()


func _on_buy() -> void:
	if SaveManager.buy_vitality():
		audio().sfx("level_up")
	else:
		audio().sfx("card_invalid")
	_refresh()
