extends SceneTree
## Card drag on the keep hand (audit #8), with real mouse events through the GUI:
## the card follows the finger 1:1 holding the grab offset; a flick up throws a
## kept card, a flick down keeps a thrown one (or shakes "no" when the keep is
## full); a short drag changes nothing; a tap still toggles (on release); the
## card leaves the finger at the finger's speed (velocity handoff) and springs
## home; with Reduce Motion it lands home at once. A drag only picks what a tap
## would: the keep made by dragging scores exactly as the same keep by taps.
##   godot --headless --path godot --script res://tests/drag_test.gd
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


## Press at `from`, move in `steps` frames to `to`, release there.
func _drag(from: Vector2, to: Vector2, steps: int) -> void:
	_btn(from, true)
	await process_frame
	for i in steps:
		_move(from.lerp(to, float(i + 1) / steps))
		await process_frame
	_btn(to, false)
	await process_frame


func _tap(at: Vector2) -> void:
	_btn(at, true)
	await process_frame
	_btn(at, false)
	await process_frame


func _hand(cards: Array) -> HandView:
	var h := HandView.new()
	h.size = Vector2(680, 260)
	h.position = Vector2(20, 1000)
	root.add_child(h)
	h.set_cards(cards, false)
	return h


func _settle_frames(n := 90) -> void:
	for i in n:
		await process_frame


func _go() -> void:
	root.size = Vector2i(720, 1560)
	MeldSprite.reduce_motion = false
	var deal := [{"rank": 5, "suit": "H"}, {"rank": 5, "suit": "S"}, {"rank": 10, "suit": "D"},
		{"rank": 11, "suit": "C"}, {"rank": 2, "suit": "H"}, {"rank": 9, "suit": "S"}]
	var h := _hand(deal)
	await _settle_frames(10)
	var v: CardView = h._views[0]
	var c0 := v.get_global_rect().get_center()
	# tap: toggles on release, not on press
	_btn(c0, true)
	await process_frame
	ok(h.get_selected_indices().is_empty(), "tap fired on press")
	ok(v.scale.x < 1.0, "no touch-down feedback")
	_btn(c0, false)
	await process_frame
	ok(h.get_selected_indices() == [0], "tap didn't select on release")
	await _settle_frames()
	# 1:1 with the grab offset: grab off-centre, move, the same point stays under the finger
	c0 = v.get_global_rect().get_center()
	var grab := c0 + Vector2(-20, 30)
	var local := v.get_global_transform().affine_inverse() * grab
	_btn(grab, true)
	await process_frame
	for d in [Vector2(5, 0), Vector2(30, -40), Vector2(-60, -150), Vector2(10, -220)]:
		_move(grab + d)
		await process_frame
		if d.length() >= CardView.DRAG_SLOP:
			var under := v.get_global_transform() * local
			ok(under.distance_to(grab + d) < 0.01, "not 1:1 at %s: grabbed point at %s, finger at %s" % [d, under, grab + d])
	ok(v.is_dragging(), "never became a drag")
	ok(v.z_index > 0, "dragged card not on top")
	# flick up throws it out of the keep
	_btn(grab + Vector2(10, -220), false)
	await process_frame
	ok(h.get_selected_indices().is_empty() and h.flicks.back() == "throw", "flick up didn't throw (%s)" % [h.flicks])
	ok(not v.is_dragging() and v.z_index == 0, "drag didn't end")
	await _settle_frames()
	ok(v.position.distance_to(v._base_pos) < 0.6, "didn't spring home (%s vs %s)" % [v.position, v._base_pos])
	# flick down keeps it; a fast short flick counts by its coast
	c0 = v.get_global_rect().get_center()
	await _drag(c0, c0 + Vector2(0, 40), 2)
	ok(h.get_selected_indices() == [0] and h.flicks.back() == "keep", "fast short flick down didn't keep (%s)" % [h.flicks])
	await _settle_frames()
	# a short slow drag changes nothing
	c0 = v.get_global_rect().get_center()
	await _drag(c0, c0 + Vector2(0, -30), 30)
	ok(h.get_selected_indices() == [0] and h.flicks.back() == "none", "short slow drag changed the keep")
	await _settle_frames()
	# velocity handoff: just after release the spring moves at the finger's speed
	c0 = h._views[1].get_global_rect().get_center()
	var w: CardView = h._views[1]
	_btn(c0, true)
	await process_frame
	var t0 := Time.get_ticks_usec()
	for i in 6:
		_move(c0 + Vector2(0, -12.0 * (i + 1)))
		await process_frame
	var finger := w._vel
	_btn(c0 + Vector2(0, -72), false)
	ok(w.spring_velocity().is_equal_approx(finger) and finger.y < -50.0, "no velocity handoff: spring %s finger %s" % [w.spring_velocity(), finger])
	await process_frame
	await _settle_frames()
	ok(w.position.distance_to(w._base_pos) < 0.6, "handoff card didn't land")
	# a full keep: a flick down on a thrown card shakes no
	h.select_indices([0, 1, 2, 3])
	await _settle_frames(20)
	var t: CardView = h._views[5]
	c0 = t.get_global_rect().get_center()
	await _drag(c0, c0 + Vector2(0, 120), 6)
	ok(h.get_selected_indices() == [0, 1, 2, 3] and h.flicks.back() == "none", "full keep took a fifth")
	await _settle_frames()
	# Reduce Motion: lands home at once
	MeldSprite.reduce_motion = true
	c0 = t.get_global_rect().get_center()
	await _drag(c0, c0 + Vector2(0, -40), 8)
	ok(t.position == t._base_pos, "reduce motion: not home at once (%s vs %s)" % [t.position, t._base_pos])
	MeldSprite.reduce_motion = false
	h.queue_free()
	await process_frame
	# the same keep by drags and by taps scores the same: presentation only
	var keeps := []
	for mode in ["tap", "drag"]:
		var g := _hand(deal)
		await _settle_frames(10)
		for i in [0, 1, 2, 3]:
			var cv: CardView = g._views[i]
			var at := cv.get_global_rect().get_center()
			if mode == "tap":
				await _tap(at)
			else:
				await _drag(at, at + Vector2(0, 90), 5)
			await _settle_frames(30)
		keeps.append(g.get_selected_cards().map(func(k): return "%d%s" % [k.rank, k.suit]))
		g.queue_free()
		await process_frame
	ok(keeps[0] == keeps[1] and keeps[0].size() == 4, "drag keep %s differs from tap keep %s" % [keeps[1], keeps[0]])
	print("drag_test: %d checks, %d fails" % [checks, fails])
	quit(1 if fails > 0 else 0)
