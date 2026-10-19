extends SceneTree
## Renders the menu screens (needs xvfb-run). SHOT_SIZE=WxH. /tmp/menu_<step>_<W>x<H>.png
func _initialize() -> void:
	_go.call_deferred()

func _go() -> void:
	Achv.persist = false
	var fx = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/menus.json"))
	Achv.save_store(fx.stores[1].store)
	var sz := OS.get_environment("SHOT_SIZE").split("x") if OS.get_environment("SHOT_SIZE") != "" else PackedStringArray(["720", "1280"])
	root.size = Vector2i(int(sz[0]), int(sz[1]))
	var f: RunFlow = load("res://scenes/run_flow.tscn").instantiate()
	root.add_child(f)
	for i in 4: await process_frame
	var shots := [["title", ""], ["deeds", ""], ["record", ""], ["gallery", "meld"], ["gallery", "spoil"], ["gallery", "backs"], ["howto", ""], ["settings", ""]]
	for s in shots:
		if s[1] != "": Menus.gal_tab = s[1]
		Menus.tut_step = 3
		f.front.go(s[0])
		for i in 20: await process_frame
		root.get_texture().get_image().save_png("/tmp/menu_%s%s_%sx%s.png" % [s[0], ("_" + s[1]) if s[1] != "" else "", sz[0], sz[1]])
	quit()
