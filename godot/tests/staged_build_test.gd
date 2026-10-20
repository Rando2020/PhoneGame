extends SceneTree
## Built over frames, same as built at once (pass 12, item 1): the shop opened
## during a slide (stages, one per frame) and every Gallery tab (rows on a
## time budget), once finished, match the same screen built in one go node for
## node: class, text, rect, disabled. And they do build over several frames
## (the opening frame isn't the whole screen), and finish by themselves.
##   godot --headless --path godot --script res://tests/staged_build_test.gd
var checks := 0
var fails := 0


func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("FAIL ", m)


func _initialize() -> void:
	_go.call_deferred()


## Every visible control under n, in tree order: class, text, rect, disabled.
func sig(n: Node) -> Array:
	var out := []
	for c in n.find_children("*", "Control", true, false):
		var ctl := c as Control
		if not ctl.is_visible_in_tree():
			continue
		# a sprite's own rect counts; its insides bob (idle animation), not layout
		var p := ctl.get_parent()
		var in_sprite := false
		while p != null and p != n:
			if p is MeldSprite:
				in_sprite = true
				break
			p = p.get_parent()
		if in_sprite:
			continue
		var t = ctl.get("text")
		out.append("%s|%s|%s|%s" % [ctl.get_class(), t if t != null else "", Rect2(ctl.get_global_rect().position.round(), ctl.get_global_rect().size.round()), ctl.get("disabled")])
	return out


func _first_diff(a: Array, b: Array) -> String:
	for i in maxi(a.size(), b.size()):
		var x = a[i] if i < a.size() else "<none>"
		var y = b[i] if i < b.size() else "<none>"
		if x != y:
			return "at %d of %d/%d: staged %s, at once %s" % [i, a.size(), b.size(), x, y]
	return ""


func _run() -> CribRun:
	var run := CribRun.new("clover", null, null, 7011)
	for id in ["keystone2", "quartermaster", "counting"]:
		run.charms.append(CribData.charm_by_id(id))
	run.essence = 40
	return run


func _go() -> void:
	Achv.persist = false
	Achv.save_store({"__v": 3})
	for g in ["split_cards", "deep_stall", "sixth_slot"]:
		Achv.grant_system(g)
	root.size = Vector2i(720, 1560)
	MeldSprite.reduce_motion = false
	# ---- the shop: staged (opened mid-slide) vs at once
	JS.unseeded = JsRng.new(77)
	var a := _run()
	a.open_shop()
	JS.unseeded = JsRng.new(77)
	var b := _run()
	b.open_shop()
	var s1: ShopScreen = load("res://scenes/shop_screen.tscn").instantiate()
	root.add_child(s1)
	s1.size = Vector2(720, 1560)
	s1.open(a, true)
	var first := sig(s1).size()
	ok(s1.is_building(), "shop: staged open built everything in one frame")
	var frames := 0
	while s1.is_building() and frames < 30:
		await process_frame
		frames += 1
	ok(not s1.is_building() and frames >= 2, "shop: staged build took %d frames (want 2 to 29)" % frames)
	var s2: ShopScreen = load("res://scenes/shop_screen.tscn").instantiate()
	root.add_child(s2)
	s2.size = Vector2(720, 1560)
	s2.open(b, false)
	await process_frame
	var sa := sig(s1)
	var sb := sig(s2)
	ok(first < sb.size() / 2, "shop: the opening frame built %d of %d nodes" % [first, sb.size()])
	ok(sa == sb, "shop: staged differs from at once: %s" % _first_diff(sa, sb))
	ok(s1.next_button != null and s1.offer_buttons.size() == s2.offer_buttons.size() and s1.card_buttons.size() == s2.card_buttons.size()
		and s1.level_buttons.size() == 4, "shop: staged build is missing buttons")
	s1.queue_free()
	s2.queue_free()
	await process_frame
	# ---- every Gallery tab: rows over frames vs flushed at once
	var f: RunFlow = load("res://scenes/run_flow.tscn").instantiate()
	root.add_child(f)
	for i in 3:
		await process_frame
	f.show_front_door("title")
	f.settle()
	for tab in ["cards", "split", "marks", "backs", "meld", "spoil"]:
		Menus.gal_tab = tab
		f.front.go("gallery")
		f.front.settle()                    # page at rest; rows not yet (settle flushes them)
		# rebuild the list, staged, through the tab switch
		Menus._gal_switch(f.front)
		var pending := f.front.rows_pending()
		var n := 0
		while f.front.rows_pending() and n < 120:
			await process_frame
			n += 1
		ok(not f.front.rows_pending(), "gallery %s: rows never finished" % tab)
		var staged := sig(f.front._page)
		Menus._gal_switch(f.front)
		f.front.settle()                    # the same list, flushed in one go
		await process_frame
		var once := sig(f.front._page)
		ok(staged == once, "gallery %s: staged differs from at once: %s" % [tab, _first_diff(staged, once)])
		if tab in ["cards", "meld", "spoil"]:
			ok(pending and n >= 2, "gallery %s: built in %d frames (want several)" % [tab, n])
	print("staged_build_test: %d checks, %d fails" % [checks, fails])
	quit(1 if fails > 0 else 0)
