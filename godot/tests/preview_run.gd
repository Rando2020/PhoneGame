extends SceneTree
## The App Store preview: a real run, played by real input events, recorded by
## Godot's movie maker at a fixed 30 fps (each awaited frame is 1/30 s of video).
## Deal; keep by flicking two cards down and tapping two; the count lands; The
## Play, laid by flicks up; then the Peg House and a purchase. Nothing is
## staged except jumping to the shop at the end (a run reaches it after the
## round's four deals, too long for a 30 s preview).
##   xvfb-run -a godot --path godot --rendering-driver opengl3 --resolution 886x1920 \
##     --write-movie /tmp/preview/f.png --fixed-fps 30 --script res://tests/preview_run.gd
## then tools/make_preview.sh. Prints what it did and the frame count.
const MAX_FRAMES := 870          ## 29 s at 30 fps: under Apple's 30 s
var frames := 0
var log_ := []


func _initialize() -> void:
	_go.call_deferred()


func _frame() -> void:
	await process_frame
	frames += 1


func _wait(n: int) -> void:
	for i in n:
		await _frame()


func _btn(at: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = at
	e.global_position = at
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _move(at: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	e.position = at
	e.global_position = at
	Input.parse_input_event(e)
	Input.flush_buffered_events()


## Screen position of a control's centre in window pixels (the canvas is
## stretched from 720 wide, so map through the viewport's transform).
func _at(c: Control) -> Vector2:
	return root.get_final_transform() * c.get_global_rect().get_center()


func _tap(c: Control) -> void:
	var p := _at(c)
	_btn(p, true)
	await _wait(2)
	_btn(p, false)
	await _wait(1)


## A flick: 6 frames (0.2 s) of travel, then let go while still moving.
func _flick(c: Control, dy: float) -> void:
	var p := _at(c)
	var k: float = root.get_final_transform().get_scale().y
	_btn(p, true)
	await _wait(2)
	for i in 6:
		_move(p + Vector2(0, dy * k * (i + 1) / 6.0))
		await _wait(1)
	_btn(p + Vector2(0, dy * k), false)
	await _wait(1)


func _go() -> void:
	Achv.persist = false
	Achv.save_store({"__v": 3, "drag_hint": 1, "tutorial": 1})
	Achv.grant_system("the_play")
	Sound.set_muted(false)               # the movie maker records the game's own sound
	var f: RunFlow = load("res://scenes/run_flow.tscn").instantiate()
	root.add_child(f)
	await _wait(1)
	var run := CribRun.new("thump", null, null, 77)
	for id in ["keystone2", "ballast", "fifteener"]:
		run.charms.append(CribData.charm_by_id(id))
	run.essence = 40
	f.start_run(run)
	await _wait(40)                               # the intro: 1.3 s
	await _tap(f.buttons["deal"])
	log_.append("deal")
	while f.keep == null or f.keep.dealing:
		await _frame()
	await _wait(12)
	var k: KeepScreen = f.keep
	var keep_idx: Array = k.rd.best_keep_ev().idx
	for n in keep_idx.size():
		var v: CardView = k.hand._views[keep_idx[n]]
		if n < 2:
			await _flick(v, 110.0)              # flick down: keep
			log_.append("flick keep %d" % keep_idx[n])
		else:
			await _tap(v)
			log_.append("tap keep %d" % keep_idx[n])
		await _wait(8)
	await _wait(10)
	await _tap(k.keep_button)
	log_.append("Keep")
	while not k.cascading:
		await _frame()
	while k.cascading and frames < 520:
		await _frame()
	await _wait(30)                               # let the total sit: 1 s
	if k.peg_pending:
		await _tap(k.keep_button)                 # The Play
		log_.append("The Play")
		await _wait(20)
		var pv: PegView = k.peg_view
		var guard := 0
		while pv != null and not pv.s.play.over and frames < MAX_FRAMES - 150 and guard < 10:
			guard += 1
			while pv.waiting:
				await _frame()
			var lay := -1
			for i in pv.hand_views.size():
				if pv.s.play.playable(i):
					lay = i
					break
			if lay < 0:
				await _wait(5)
				continue
			await _flick(pv.hand_views[lay], -150.0)   # flick up onto the pile
			log_.append("lay %d" % lay)
			await _wait(26)
		await _wait(20)
	# the Peg House
	f.run.open_shop()
	f.show_shop()
	log_.append("shop")
	await _wait(30)
	var sh: ShopScreen = f.shop
	for id in sh.offer_buttons:
		var b: Button = sh.offer_buttons[id]
		if not b.disabled:
			await _tap(b)
			log_.append("bought %s" % id)
			break
	await _wait(75)                               # 2.5 s on the purchase, then end
	print("preview: %d frames (%.1f s): %s" % [frames, frames / 30.0, ", ".join(log_)])
	quit()
