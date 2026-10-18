extends SceneTree
## Renders the guided first round's first beat over the deal (needs xvfb-run).
## SHOT_SIZE=WxH. Writes /tmp/guide_<W>x<H>.png
func _initialize() -> void:
	_go.call_deferred()

func _go() -> void:
	Achv.persist = false
	Achv.save_store({"__v": 3})
	var sz := OS.get_environment("SHOT_SIZE").split("x") if OS.get_environment("SHOT_SIZE") != "" else PackedStringArray(["720", "1280"])
	root.size = Vector2i(int(sz[0]), int(sz[1]))
	JS.unseeded = JsRng.new(77)
	var f: RunFlow = load("res://scenes/run_flow.tscn").instantiate()
	root.add_child(f)
	await process_frame
	f.start_guided()
	for i in 90: await process_frame
	root.get_texture().get_image().save_png("/tmp/guide_%sx%s.png" % [sz[0], sz[1]])
	print("guide shot %sx%s" % [sz[0], sz[1]])
	quit()
