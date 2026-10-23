extends SceneTree
## The first-run drag hint (pass 10, item 5): on the first deal ever the keep
## screen shows one line on dragging, clear of the hand and the Crib; the
## first Keep hides it and saves that; later deals and new keep screens don't
## show it again.
##   godot --headless --path godot --script res://tests/drag_hint_test.gd
var checks := 0
var fails := 0


func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("FAIL ", m)


func _initialize() -> void:
	_go.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _flow() -> RunFlow:
	var f: RunFlow = load("res://scenes/run_flow.tscn").instantiate()
	root.add_child(f)
	return f


func _go() -> void:
	Achv.persist = false
	Achv.save_store({"__v": 3})
	root.size = Vector2i(720, 1560)
	var f := _flow()
	await _frames(3)
	f.start_run(CribRun.new("pip", null, null, 4242))
	f._on_deal()
	await _frames(90)
	var k: KeepScreen = f.keep
	ok(k.drag_hint.visible and k.drag_hint.text == KeepScreen.DRAG_HINT, "first deal: no hint")
	var hint := k.drag_hint.get_global_rect()
	ok(not hint.intersects(k.hand.get_global_rect()), "hint on the hand: %s vs %s" % [hint, k.hand.get_global_rect()])
	ok(not hint.intersects(k.crib_strip.get_global_rect()) and not hint.intersects(k.starter_view.get_global_rect()), "hint on the Crib or starter")
	ok(hint.end.x <= 721.0 and hint.position.x >= -1.0, "hint off screen")
	# keep four: the hint goes and is saved
	k.hand.select_indices([0, 1, 2, 3])
	await process_frame
	k._on_button()
	await process_frame
	ok(not k.drag_hint.visible, "the first Keep didn't hide the hint")
	ok(KeepScreen.drag_hint_seen(), "the hint wasn't saved as seen")
	# skip the count, next deal: still hidden
	for i in 400:
		await process_frame
		if k.rd.phase == "keep" and not k.dealing and not k.cascading:
			break
		if k.cascading:
			k.cascade.skip()
		elif not k.rd.over and k.rd.phase != "keep" and not k.peg_pending:
			k.next_deal()
	ok(not k.drag_hint.visible, "the hint came back on a later deal")
	f.queue_free()
	await process_frame
	# a new screen, same save: never again
	var g := _flow()
	await _frames(3)
	g.start_run(CribRun.new("clover", null, null, 77))
	g._on_deal()
	await _frames(90)
	ok(not g.keep.drag_hint.visible, "the hint came back on a new screen")
	print("drag_hint_test: %d checks, %d fails" % [checks, fails])
	quit(1 if fails > 0 else 0)
