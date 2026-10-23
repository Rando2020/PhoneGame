extends SceneTree
## Text size changes apply to the screen you're on (pass 10, item 4), through
## both routes: the Settings row, and the iOS setting changing underneath (the
## MeldAccess plugin's `changed`, played by a stand-in). On every screen, after
## the change: every sized control is at its base size at the new scale, and
## the screen re-laid out (nothing off screen, trimmed or overlapping, the
## text_size_test probe).
##   godot --headless --path godot --script res://tests/live_text_test.gd
var checks := 0
var fails := 0
const Probe := preload("res://tests/text_size_test.gd")


class FakeAccess extends Object:
	signal changed
	var category := "UICTContentSizeCategoryL"
	func reduce_motion() -> bool:
		return false
	func content_size() -> String:
		return category


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


## Every sized control is at px(base) for the scale now in force.
func _sized(where: String, root_n: Node) -> void:
	var wrong := []
	var n := 0
	for c in root_n.find_children("*", "Control", true, false):
		if not c.has_meta("fs_base"):
			continue
		n += 1
		var want := TypeScale.px(int(c.get_meta("fs_base")))
		var got := (c as Control).get_theme_font_size("font_size")
		if got != want:
			wrong.append("%s %d want %d" % [c.get("text") if c.get("text") != null else c.name, got, want])
	ok(n > 0 and wrong.is_empty(), "%s @%.2f: %d of %d at the old size %s" % [where, TypeScale.scale, wrong.size(), n, wrong.slice(0, 3)])


func _clean(where: String, root_n: Node) -> void:
	var r: Dictionary = Probe.probe(root_n, Vector2(720, 1560))
	ok(r.off.is_empty() and r.tall.is_empty(), "%s @%.2f: off %s overlap %s" % [where, TypeScale.scale, r.off.slice(0, 3), r.tall.slice(0, 3)])


func _go() -> void:
	Achv.persist = false
	Achv.save_store({"__v": 3})
	root.size = Vector2i(720, 1560)
	TypeScale.scale = 1.0
	var f: RunFlow = load("res://scenes/run_flow.tscn").instantiate()
	root.add_child(f)
	await _frames(3)
	# --- route 1: the Settings row, on the settings screen, Standard -> Large -> Larger
	f.show_front_door("title")
	f.settle()
	f.front.go("settings")
	f.settle()
	for i in 2:
		f.front.buttons["set_text"].emit_signal("pressed")
		await _frames(2)
		f.settle()
		ok(TypeScale.scale == TypeScale.STEPS[i + 1], "Settings row didn't step the size")
		_sized("settings", f)
		_clean("settings", f)
	f.front.buttons["set_text"].emit_signal("pressed")     # back to Standard
	await _frames(2)
	ok(TypeScale.scale == 1.0, "Settings row didn't wrap to Standard")
	# --- route 2: iOS changes it while a screen is up (the plugin's signal)
	Achv.save_store({"__v": 3})          # no saved choice: the phone decides
	var fa := FakeAccess.new()
	Engine.register_singleton("MeldAccess", fa)
	Menus.apply()
	var run := CribRun.new("clover", null, null, 7011)
	for id in ["keystone2", "quartermaster", "counting", "thebank", "sovereign"]:
		run.charms.append(CribData.charm_by_id(id))
	var screens := ["intro", "keep", "shop", "play"]
	var pv: PegView = null
	for sc in screens:
		match sc:
			"intro":
				f.start_run(run)
			"keep":
				f._on_deal()
				await _frames(90)
			"shop":
				f.show_shop()
			"play":
				Achv.grant_system("the_play")
				var rd := CribRound.new(CribRun.new("thump", null, null, 5294))
				rd.new_deal()
				var idx: Array = rd.best_keep_ev().idx
				var kept: Array = idx.map(func(k): return rd.dealt[k])
				rd.commit(idx)
				pv = PegView.new()
				root.add_child(pv)
				pv.size = Vector2(720, 1560)
				pv.open(PegSession.start(rd, kept))
		await _frames(2)
		f.settle()
		var host: Node = pv if sc == "play" else f
		for cat in ["UICTContentSizeCategoryXXL", "UICTContentSizeCategoryAccessibilityM", "UICTContentSizeCategoryL"]:
			fa.category = cat
			fa.changed.emit()
			await _frames(2)
			f.settle()
			ok(TypeScale.scale == TypeScale.STEPS[Menus.text_step_for(cat)], "%s: iOS %s not applied" % [sc, cat])
			_sized(sc, host)
			_clean(sc, host)
	Engine.unregister_singleton("MeldAccess")
	fa.free()
	TypeScale.scale = 1.0
	print("live_text_test: %d checks, %d fails" % [checks, fails])
	quit(1 if fails > 0 else 0)
