class_name SelectScreen
extends Screen

var _chosen: String = "pip"
var _views: Dictionary = {}
var _name_label: Label
var _blurb: Label
var _stat: Label


func build() -> void:
	var body := UIKit.screen_body(20)
	add_child(body)
	var col := UIKit.vbox(12)
	body.add_child(col)

	col.add_child(UIKit.title("CHOOSE YOUR MELDLING", 26))
	col.add_child(UIKit.label("Each one bends a different Rummy concept.",
			14, UIKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(UIKit.spacer(6, false))

	var row := UIKit.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.custom_minimum_size.y = 180
	col.add_child(row)

	for id in CreatureDB.meldlings():
		var slot := Button.new()
		slot.custom_minimum_size = Vector2(112, 168)
		slot.flat = true
		slot.focus_mode = Control.FOCUS_NONE
		slot.pressed.connect(_on_pick.bind(id))
		row.add_child(slot)

		var v := CreatureView.new()
		v.pixel_scale = 4
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(v)
		v.setup(id)
		v.position = Vector2(-8, 10)
		_views[id] = v

	col.add_child(UIKit.spacer(4, false))

	var info := UIKit.panel()
	col.add_child(info)
	var iv := UIKit.vbox(6)
	info.add_child(iv)
	_name_label = UIKit.label("", 24, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	iv.add_child(_name_label)
	_stat = UIKit.label("", 15, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	iv.add_child(_stat)
	_blurb = UIKit.wrap_label("", 260, 15, UIKit.DIM)
	iv.add_child(_blurb)

	col.add_child(UIKit.spacer(0, true))

	var go := UIKit.button("START", 22, 60)
	go.pressed.connect(func():
		audio().sfx("meld_rally")
		game.start_run(_chosen))
	col.add_child(go)

	var back := UIKit.button("Back", 16, 46)
	back.pressed.connect(func():
		audio().sfx("ui_click")
		game.goto("title"))
	col.add_child(back)

	_on_pick("pip")


func _on_pick(id: String) -> void:
	_chosen = id
	audio().sfx("card_select")
	var d := CreatureDB.get_data(id)
	_name_label.text = d.get("name", id)
	_stat.text = "%d HP  (+%d Vitality)  ·  %s" % [
		int(d.get("hp", 60)), SaveManager.bonus_hp(),
		CardArt.SUIT_NAMES[CardArt.suit_index(d.get("suit", "S"))]]
	_blurb.text = d.get("blurb", "")

	for k in _views:
		var v: CreatureView = _views[k]
		v.modulate = Color.WHITE if k == id else Color(0.5, 0.5, 0.58)
		if k == id:
			v.play_once("attack")
