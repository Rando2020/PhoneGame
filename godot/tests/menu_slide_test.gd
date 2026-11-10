extends SceneTree
## Menu screens move (audit #7): a front-door step slides in from the right when
## going deeper and from the left when going back, on RunFlow's spring, and
## comes to rest with the old page freed; with Reduce Motion it cross-fades in
## place instead; a redraw in place (a settings toggle, a resize) doesn't move;
## the leaving page takes no taps.
##   godot --headless --path godot --script res://tests/menu_slide_test.gd
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


func _go() -> void:
	Achv.persist = false
	root.size = Vector2i(720, 1560)
	var f: RunFlow = load("res://scenes/run_flow.tscn").instantiate()
	root.add_child(f)
	await _frames(3)
	MeldSprite.reduce_motion = false
	f.show_front_door("title")
	f.settle()
	var fd: FrontDoor = f.front
	for pair in [["deeds", 1.0], ["title", -1.0], ["road", 1.0], ["street", 1.0], ["road", -1.0], ["settings", 1.0]]:
		var old := fd._page
		fd.go(pair[0])
		ok(fd._outgoing == old, "%s: the old page isn't the leaving one" % pair[0])
		ok(is_equal_approx(fd._page.position.x, pair[1] * 720.0), "%s: starts at %d, want %d" % [pair[0], fd._page.position.x, pair[1] * 720.0])
		var dead := old.find_children("*", "BaseButton", true, false).filter(func(b): return not b.disabled)
		ok(dead.is_empty(), "%s: %d buttons on the leaving page still live" % [pair[0], dead.size()])
		await _frames(4)
		var mid := fd._page.position.x
		ok(absf(mid) < 720.0 and signf(mid) == signf(pair[1]), "%s: not moving in (%d)" % [pair[0], mid])
		ok(fd._outgoing != null and is_equal_approx(fd._outgoing.position.x, mid - pair[1] * 720.0), "%s: the old page doesn't travel with it" % pair[0])
		await _frames(120)
		ok(fd._page.position.x == 0.0 and fd._outgoing == null and not is_instance_valid(old), "%s: didn't come to rest (%d)" % [pair[0], fd._page.position.x])
	# a redraw in place: no slide
	fd.buttons["set_sound"].emit_signal("pressed")
	ok(fd._outgoing == null and fd._page.position.x == 0.0, "settings toggle slid")
	Sound.set_muted(false)
	fd.size = Vector2(720, 1280)
	ok(fd._outgoing == null and fd._page.position.x == 0.0, "resize slid")
	fd.size = Vector2(720, 1560)
	# Reduce Motion: cross-fade, no travel
	MeldSprite.reduce_motion = true
	fd.go("title")
	ok(fd._page.position.x == 0.0 and fd._page.modulate.a < 0.05 and fd._outgoing != null, "reduce motion: not a cross-fade (x %d, a %.2f)" % [fd._page.position.x, fd._page.modulate.a])
	await _frames(3)
	ok(fd._page.position.x == 0.0, "reduce motion: the page moved")
	await create_timer(0.35).timeout
	ok(fd._page.modulate.a == 1.0 and fd._outgoing == null, "reduce motion: fade didn't finish")
	MeldSprite.reduce_motion = false
	print("menu_slide_test: %d checks, %d fails" % [checks, fails])
	quit(1 if fails > 0 else 0)
