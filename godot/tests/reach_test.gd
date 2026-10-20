extends SceneTree
## Every button can be reached (pass 11, item 5): at Larger text (x1.3), at
## 720x1280 and 720x1560, laid out against an iPhone 16 Pro Max's safe area
## (59 pt top, 34 pt bottom = 109 / 63 canvas px; SafeArea.simulate), on the
## long screens (shop, Deeds, Gallery tabs, Record, the road, Peddler) and the
## rest of the front door. For each live button: either it already sits fully
## on screen and inside the safe area, or it's inside a ScrollContainer that
## can bring it fully inside both its visible rect and the safe area (a scroll
## may run under the bars, as on iOS, if its content leaves room at the ends). Also: a scroll's content is taller than its view only where
## a scroll exists (nothing is cut off with no way to reach it).
##   godot --headless --path godot --script res://tests/reach_test.gd
var checks := 0
var fails := 0
var reached := 0
var by_scroll := 0


func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		if fails <= 25:
			print("FAIL ", m)


func _initialize() -> void:
	_go.call_deferred()


func _scroll_of(n: Node) -> ScrollContainer:
	var p := n.get_parent()
	while p != null:
		if p is ScrollContainer:
			return p
		p = p.get_parent()
	return null


func _check(where: String, host: Control, view: Vector2) -> void:
	await process_frame
	var safe := Rect2(0, SafeArea.simulate.top, view.x, view.y - SafeArea.simulate.top - SafeArea.simulate.bottom).grow(1.0)
	var buttons := host.find_children("*", "BaseButton", true, false).filter(
		func(b): return b.is_visible_in_tree() and not b.disabled and b.mouse_filter != Control.MOUSE_FILTER_IGNORE)
	ok(not buttons.is_empty(), "%s: no buttons" % where)
	for b in buttons:
		var label: String = b.get("text") if b.get("text") != null and b.get("text") != "" else b.name
		var sc := _scroll_of(b)
		if sc == null:
			ok(safe.encloses(b.get_global_rect()), "%s: '%s' outside the safe area %s" % [where, label, b.get_global_rect()])
		else:
			# a scroll may run under the bars (iOS does); what matters is that
			# scrolling can bring each button fully inside both the scroll's view
			# and the safe area. In content coordinates: the reachable window is
			# the view minus the part under the bars, and the button must fit the
			# window's height and sit at least that far from the content's ends.
			var view_r := sc.get_global_rect()
			var win_top := maxf(view_r.position.y, safe.position.y) - view_r.position.y
			var win_bot := view_r.end.y - minf(view_r.end.y, safe.end.y)
			var content: Control = sc.get_child(0) if sc.get_child_count() > 0 else null
			var ch := maxf(content.size.y, content.custom_minimum_size.y) if content != null else 0.0
			var by: float = b.get_global_rect().position.y - (content.get_global_rect().position.y if content != null else view_r.position.y)
			var bh: float = b.get_global_rect().size.y
			var fits := bh <= view_r.size.y - win_top - win_bot + 1.0
			var room_above := by >= win_top - 1.0 or ch <= view_r.size.y and by + view_r.position.y >= safe.position.y - 1.0
			var room_below := ch - (by + bh) >= win_bot - 1.0 or by + bh + view_r.position.y - sc.scroll_vertical <= safe.end.y + 1.0
			ok(fits and room_above and room_below, "%s: '%s' can't be scrolled clear of the bars (y %d h %d in %d of content; window %d..%d)" % [where, label, by, bh, ch, win_top, view_r.size.y - win_bot])
			ok(view_r.position.x >= -1.0 and b.get_global_rect().end.x <= view.x + 1.0, "%s: '%s' off the side" % [where, label])
			by_scroll += 1
		reached += 1
	# content cut off with no scroll: anything drawn below the safe bottom
	for c in host.find_children("*", "Control", true, false):
		var ctl := c as Control
		if not ctl.is_visible_in_tree() or _scroll_of(ctl) != null or ctl.size.y > view.y * 0.8:
			continue
		if (ctl is Label and (ctl as Label).text != "") or ctl is BaseButton:
			var r := ctl.get_global_rect()
			ok(r.end.y <= safe.end.y and r.position.y >= safe.position.y, "%s: '%s' outside the safe area, not in a scroll %s" % [where, ctl.get("text"), r])


func _go() -> void:
	Achv.persist = false
	Achv.save_store({"__v": 3, "drag_hint": 1})
	for g in ["split_cards", "deep_stall", "sixth_slot"]:
		Achv.grant_system(g)
	SafeArea.simulate = {"top": 109.0, "bottom": 63.0}
	for view in [Vector2(720, 1280), Vector2(720, 1560)]:
		root.size = Vector2i(view)
		TypeScale.scale = 1.3
		var f: RunFlow = load("res://scenes/run_flow.tscn").instantiate()
		root.add_child(f)
		TypeScale.scale = 1.3
		TypeScale.relayout(root)
		for i in 3:
			await process_frame
		var tag := "%dx%d" % [view.x, view.y]
		for step in ["title", "road", "street", "trial", "meld", "peddler", "deeds", "record",
				"gallery:cards", "gallery:split", "gallery:marks", "gallery:backs", "gallery:meld", "gallery:spoil",
				"howto", "settings"]:
			f.show_front_door("title")
			f.settle()
			if step.begins_with("gallery:"):
				Menus.gal_tab = step.get_slice(":", 1)
				f.front.go("gallery")
			elif step == "street" or step == "trial":
				f.front.cb.street = Meta.STREETS[0]
				f.front.go(step)
			elif step != "title":
				Menus.tut_step = 0
				f.front.go(step)
			f.settle()
			await _check("%s %s" % [step, tag], f, view)
		var run := CribRun.new("clover", null, null, 7011)
		for id in ["keystone2", "quartermaster", "counting", "thebank", "sovereign"]:
			run.charms.append(CribData.charm_by_id(id))
		run.essence = 40
		f.start_run(run)
		f.settle()
		await _check("intro " + tag, f, view)
		f._on_deal()
		for i in 60:
			await process_frame
		f.settle()
		await _check("keep " + tag, f, view)
		run.open_shop()
		f.show_shop()
		f.settle()
		await _check("shop " + tag, f, view)
		f.queue_free()
		await process_frame
	SafeArea.simulate = {}
	TypeScale.scale = 1.0
	print("reach_test: %d buttons reached (%d by scrolling); %d checks, %d fails" % [reached, by_scroll, checks, fails])
	quit(1 if fails > 0 else 0)
