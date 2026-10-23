extends SceneTree
## The resize guard (pass 12, item 4) on all four screens that redraw on a
## resize: RunFlow (intro), FrontDoor (title), the shop and The Play.
## 1. A resize that lands in the middle of a draw (the first node the draw adds
##    changes the screen's width, as a first layout pass does) ends, a frame
##    later, with the screen drawn for the new width.
## 2. A resize notice at the size it was already drawn for doesn't redraw.
## 3. A real resize does.
##   godot --headless --path godot --script res://tests/resize_guard_test.gd
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


## What identifies one draw of the screen (a new draw makes a new one).
func _mark(host: Control) -> Object:
	if host is ShopScreen:
		var c: Control = (host as ShopScreen)._content
		return c.get_child(0) if c.get_child_count() > 0 else null
	return host.get("_page")


func _case(name: String, host: Control, draw: Callable) -> void:
	host.size = Vector2(720, 1560)
	await _frames(2)
	# 1. mid-draw resize: the draw's first new node narrows the screen
	var state := {"hit": false}
	var hook := func(n: Node):
		if not state.hit and host.is_ancestor_of(n):
			state.hit = true
			host.size = Vector2(600, 1560)
	node_added.connect(hook)
	draw.call()
	node_added.disconnect(hook)
	ok(state.hit, "%s: the mid-draw resize didn't happen" % name)
	await _frames(3)
	var key := TypeScale.layout_key(host)
	ok(host._drawn_for == key, "%s: after a mid-draw resize, drawn for %s, the screen is %s" % [name, host._drawn_for, key])
	var wide := []
	for c in host.find_children("*", "Control", true, false):
		var ctl := c as Control
		if ctl.is_visible_in_tree() and (ctl is Label or ctl is BaseButton) and ctl.get_global_rect().end.x > host.global_position.x + 601.0:
			wide.append("%s %d" % [ctl.get("text"), ctl.get_global_rect().end.x])
	ok(wide.is_empty(), "%s: drawn past the new width (600): %s" % [name, wide.slice(0, 3)])
	# 2. a notice at the same size: no redraw
	var m := _mark(host)
	host.notification(Control.NOTIFICATION_RESIZED)
	await _frames(2)
	ok(_mark(host) == m, "%s: redrew for a resize to the same size" % name)
	# 3. a real resize: redraws, for the new size
	host.size = Vector2(720, 1280)
	await _frames(3)
	ok(_mark(host) != m and host._drawn_for == TypeScale.layout_key(host), "%s: a real resize didn't redraw for it" % name)


func _go() -> void:
	Achv.persist = false
	Achv.save_store({"__v": 3})
	Achv.grant_system("the_play")
	root.size = Vector2i(720, 1560)
	MeldSprite.reduce_motion = true          # no slides: draws land in place
	var f: RunFlow = load("res://scenes/run_flow.tscn").instantiate()
	root.add_child(f)
	f.set_anchors_preset(Control.PRESET_TOP_LEFT)   # sized by hand below
	await _frames(3)
	var run := CribRun.new("thump", null, null, 77)
	f.run = run
	f.screen = "intro"
	await _case("RunFlow intro", f, f.show_intro)
	f.show_front_door("title")
	f.settle()
	var fd: FrontDoor = f.front
	fd.set_anchors_preset(Control.PRESET_TOP_LEFT)
	await _case("FrontDoor title", fd, fd.render)
	f.queue_free()
	await process_frame
	# the shop, on its own
	var sh: ShopScreen = load("res://scenes/shop_screen.tscn").instantiate()
	root.add_child(sh)
	sh.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var sr := CribRun.new("clover", null, null, 7011)
	sr.open_shop()
	sh.open(sr)
	await _case("shop", sh, sh.render)
	sh.queue_free()
	# The Play, on its own
	var rd := CribRound.new(CribRun.new("thump", null, null, 5294))
	rd.new_deal()
	var idx: Array = rd.best_keep_ev().idx
	var kept: Array = idx.map(func(k): return rd.dealt[k])
	rd.commit(idx)
	var pv := PegView.new()
	root.add_child(pv)
	pv.open(PegSession.start(rd, kept))
	pv.set_anchors_preset(Control.PRESET_TOP_LEFT)
	await _case("The Play", pv, pv.render)
	MeldSprite.reduce_motion = false
	print("resize_guard_test: %d checks, %d fails" % [checks, fails])
	quit(1 if fails > 0 else 0)
