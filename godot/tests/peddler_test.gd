extends SceneTree
## The Peddler. Fixture group pedui: the real JS tapping card backs the way the
## web's Peddler does (equip if owned, else buy and equip, else "Not enough
## Pegs"), with the save after every tap. This taps the same backs in Godot by
## click and compares; checks the page at three shapes, that a face-down card
## shows the equipped back, and that Back goes to the roads, as the web does.
##   godot --headless --path godot --script res://tests/peddler_test.gd
const SHAPES := [Vector2i(720, 1280), Vector2i(720, 1560), Vector2i(960, 1280)]
var checks := 0
var fails := 0
var clicks := 0
var taps := 0
var outs := {}


func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		if fails <= 10:
			print("FAIL ", m)


func _initialize() -> void:
	_go.call_deferred()


func _click(at: Vector2) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = at
		e.global_position = at
		Input.parse_input_event(e)
		Input.flush_buffered_events()
		await process_frame
	clicks += 1


func press(f: RunFlow, key: String) -> void:
	await process_frame
	await _click(f.front.buttons[key].get_global_rect().get_center())


func snap() -> Dictionary:
	return {"pegs": Achv.pegs(), "owned": Meta.CARD_BACKS.filter(func(b): return Achv.owns_back(b.id)).map(func(b): return b.id),
		"active": Achv.active_back()}


func check_page(f: RunFlow, shape: Vector2i, where: String) -> void:
	f.settle()     # measure at rest, not mid-slide
	var screen := Rect2(Vector2.ZERO, Vector2(shape))
	var back: Rect2 = f.front.buttons["back"].get_global_rect()
	ok(screen.encloses(back) and absf(back.get_center().x - shape.x / 2.0) <= 1.0, "%s: Back off screen or centre" % where)
	for b in Meta.CARD_BACKS:
		var r: Rect2 = f.front.buttons["back_" + b.id].get_global_rect()
		ok(screen.encloses(r), "%s: %s slot off screen %s" % [where, b.id, r])
		ok(r.end.y <= back.position.y, "%s: %s slot runs under Back" % [where, b.id])


func _go() -> void:
	for path in ["res://ui/front/front_door.gd", "res://ui/run_flow.gd", "res://ui/cards/card_art.gd"]:
		var sc: Script = load(path)
		if sc == null or not sc.can_instantiate():
			print("FAIL %s does not load" % path)
			print("PEDDLER FAILED")
			quit(1)
			return
	var fh := FileAccess.open("res://tests/fixtures/parity.json", FileAccess.READ)
	var fx = load("res://tests/parity_test.gd").norm(JSON.parse_string(fh.get_as_text()))
	Achv.persist = false
	var diff := func(a, b): return load("res://tests/parity_test.gd").diff(a, b)
	for ci in fx.pedui.size():
		var C = fx.pedui[ci]
		var shape: Vector2i = SHAPES[ci % SHAPES.size()]
		root.size = shape
		Achv.save_store(C.store.duplicate(true))
		var f: RunFlow = load("res://scenes/run_flow.tscn").instantiate()
		root.add_child(f)
		await process_frame
		await press(f, "peddler")
		ok(f.cb.step == "peddler", "case %d: title button didn't open the Peddler" % ci)
		var where := "case %d @%s" % [ci, shape]
		ok(diff.call(C.steps[0].state, snap()) == "", "%s: start state %s" % [where, diff.call(C.steps[0].state, snap())])
		check_page(f, shape, where)
		var probe := CardView.new()
		root.add_child(probe)
		for si in range(1, C.steps.size()):
			var S = C.steps[si]
			var id: String = Meta.CARD_BACKS[int(S.tap)].id
			await press(f, "back_" + id)
			taps += 1
			outs[S.out] = int(outs.get(S.out, 0)) + 1
			ok(f.front.last_tap == S.out, "%s tap %d (%s): %s, web %s" % [where, si, id, f.front.last_tap, S.out])
			ok(diff.call(S.state, snap()) == "", "%s tap %d: %s" % [where, si, diff.call(S.state, snap())])
			var pegs_line: Label = null
			for c in f.front._page.get_children():
				if c is Label and c.text.ends_with(" Pegs") and not c.text.begins_with("Not"):
					pegs_line = c
			ok(pegs_line != null and pegs_line.text == "%d Pegs" % S.state.pegs, "%s tap %d: Pegs line" % [where, si])
			var flash := f.front._flash != null and is_instance_valid(f.front._flash) and f.front._flash.get_parent() == f.front._page
			ok(flash == (S.out == "short"), "%s tap %d: flash %s for %s" % [where, si, flash, S.out])
			probe.setup(1, "S", false)
			ok(probe._face.texture == CardArt.back() and CardArt.back().resource_path.ends_with("back_%s.png" % S.state.active),
				"%s tap %d: face-down card not wearing %s" % [where, si, S.state.active])
			check_page(f, shape, where + " tap %d" % si)
		probe.queue_free()
		await press(f, "back")
		ok(f.cb.step == "road", "%s: Back went to %s, web goes to the roads" % [where, f.cb.step])
		f.queue_free()
		await process_frame
	print("peddler: %d taps %s, %d clicks" % [taps, outs, clicks])
	var good := fails == 0 and taps >= 30 and outs.size() == 3
	print("peddler checks: %d, failures: %d" % [checks, fails])
	print("PEDDLER OK" if good else "PEDDLER FAILED")
	quit(0 if good else 1)
