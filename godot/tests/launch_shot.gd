extends SceneTree
## The launch screen: the title's first frame (felt, wordmark, the six), without
## the buttons or the record line (they aren't tappable yet). SHOT_SIZE=WxH.
## -> /tmp/launch_<W>x<H>.png
func _initialize() -> void:
	_go.call_deferred()

func _go() -> void:
	Achv.persist = false
	Achv.save_store({"__v": 3})
	var sz := OS.get_environment("SHOT_SIZE").split("x") if OS.get_environment("SHOT_SIZE") != "" else PackedStringArray(["1290", "2796"])
	root.size = Vector2i(int(sz[0]), int(sz[1]))
	MeldSprite.reduce_motion = true       # no bob: the frame the app opens on
	var f: RunFlow = load("res://scenes/run_flow.tscn").instantiate()
	root.add_child(f)
	for i in 6: await process_frame
	for b in f.front.find_children("*", "BaseButton", true, false):
		(b as Control).hide()
	var line := f.front._page.get_node_or_null("line")
	if line: line.hide()
	for i in 4: await process_frame
	root.get_texture().get_image().save_png("/tmp/launch_%sx%s.png" % [sz[0], sz[1]])
	quit()
