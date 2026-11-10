extends SceneTree
## Drag in The Play (pass 10): with real mouse events, a card follows the finger
## 1:1; pushed up toward the pile it's laid, and the play after a drag-lay is
## exactly the play after a tap-lay of the same card (pile, count, both scores,
## the Spoiler's answer); a short drag springs home at the finger's speed and
## lays nothing; touch-down feedback keeps the card at its own (small) scale;
## a tap still lays.
##   godot --headless --path godot --script res://tests/peg_drag_test.gd
var checks := 0
var fails := 0


func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("FAIL ", m)


func _initialize() -> void:
	_go.call_deferred()


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


func _session(seed: int) -> PegSession:
	var r := CribRun.new("thump", null, null, seed)
	var rd := CribRound.new(r)
	rd.new_deal()
	var idx: Array = rd.best_keep_ev().idx
	var kept: Array = idx.map(func(i): return rd.dealt[i])
	rd.commit(idx)
	return PegSession.start(rd, kept)


func _state(ps: PegSession) -> String:
	var p := ps.play
	return JSON.stringify([p.pile, p.total, p.score, p.opp_score, p.mine.size(), p.theirs.size()])


func _view(ps: PegSession) -> PegView:
	var v := PegView.new()
	root.add_child(v)
	v.size = Vector2(720, 1560)
	v.open(ps)
	return v


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _go() -> void:
	# a broken build can stall a coroutine: fail rather than hang
	create_timer(240.0).timeout.connect(func():
		print("FAIL watchdog: the test stalled")
		print("peg_drag_test: %d checks, %d fails" % [checks, fails + 1])
		quit(1))
	Achv.persist = false
	Achv.grant_system("the_play")
	root.size = Vector2i(720, 1560)
	MeldSprite.reduce_motion = false
	var compared := 0
	for seed in [5106, 5294, 77, 4242]:
		var a := _session(seed)
		var b := _session(seed)
		var va := _view(a)
		var vb := _view(b)
		await _frames(3)
		ok(_state(a) == _state(b), "seed %d: twins differ before" % seed)
		var guard := 0
		while not a.play.over and guard < 12:
			guard += 1
			# wait out the Spoiler's beat on both
			while va.waiting or vb.waiting:
				await process_frame
			if a.play.over:
				break
			var k := -1
			for i in va.hand_views.size():
				if a.play.playable(i):
					k = i
					break
			if k < 0:
				await _frames(2)
				continue
			vb.visible = false
			va.visible = true
			var ca: CardView = va.hand_views[k]
			var at := ca.get_global_rect().get_center()
			var rest := ca.scale
			# a short drag first: nothing laid, home again at its own scale
			if guard == 1:
				_btn(at, true)
				await process_frame
				ok(ca.scale.x < rest.x and ca.scale.x > rest.x * 0.9, "seed %d: touch-down scale %s from %s" % [seed, ca.scale, rest])
				var local := ca.get_global_transform().affine_inverse() * at
				for d in [Vector2(0, -15), Vector2(10, -30), Vector2(20, -40)]:
					_move(at + d)
					await process_frame
					ok((ca.get_global_transform() * local).distance_to(at + d) < 0.01, "seed %d: not 1:1 at %s" % [seed, d])
				await create_timer(0.1).timeout   # the finger rests before lifting: no coast
				_btn(at + Vector2(20, -40), false)
				await process_frame
				var laid: bool = va.flicks.is_empty() or va.flicks.back() != "none" or _state(a) != _state(b)
				ok(not laid, "seed %d: short drag laid a card" % seed)
				if laid or not is_instance_valid(ca):
					break                      # the twins have parted; nothing more to compare
				await _frames(90)
				ok(ca.position.distance_to(ca._base_pos) < 0.6 and ca.scale.is_equal_approx(rest), "seed %d: short drag didn't spring home (%s %s)" % [seed, ca.position, ca.scale])
				at = ca.get_global_rect().get_center()
			# drag-lay on A, tap-lay the same card on B
			_btn(at, true)
			await process_frame
			for i in 6:
				_move(at + Vector2(0, -30.0 * (i + 1)))
				await process_frame
			_btn(at + Vector2(0, -180), false)
			await process_frame
			ok(va.flicks.back() == "lay", "seed %d: drag up didn't lay" % seed)
			va.visible = false
			vb.visible = true
			var cb: CardView = vb.hand_views[k]
			var bt := cb.get_global_rect().get_center()
			_btn(bt, true)
			await process_frame
			_btn(bt, false)
			await process_frame
			ok(_state(a) == _state(b), "seed %d lay %d: drag %s vs tap %s" % [seed, guard, _state(a), _state(b)])
			compared += 1
			va.visible = true
			await _frames(50)          # both Spoilers answer
			ok(_state(a) == _state(b), "seed %d answer %d: drag %s vs tap %s" % [seed, guard, _state(a), _state(b)])
		va.queue_free()
		vb.queue_free()
		await process_frame
	ok(compared >= 8, "only %d lays compared" % compared)
	print("peg_drag_test: %d checks, %d fails (%d lays compared)" % [checks, fails, compared])
	quit(1 if fails > 0 else 0)
