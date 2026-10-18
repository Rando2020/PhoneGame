extends SceneTree
## Renders the shop (needs xvfb-run). SHOT_SIZE=WxH for other shapes.
func _initialize() -> void:
	_go.call_deferred()
func _go() -> void:
	Achv.persist = false
	Achv.save_store({"__v": 3})
	for s in ["split_cards", "deep_stall", "sixth_slot"]:
		Achv.grant_system(s)
	var sz := OS.get_environment("SHOT_SIZE").split("x") if OS.get_environment("SHOT_SIZE") != "" else PackedStringArray(["720", "1280"])
	root.size = Vector2i(int(sz[0]), int(sz[1]))
	var run := CribRun.new("clover", null, null, 7011)
	for id in ["keystone2", "quartermaster", "counting", "thebank", "sovereign"]:
		run.charms.append(CribData.charm_by_id(id))
	run.essence = 34
	run.round = 3
	var s: ShopScreen = load("res://scenes/shop_screen.tscn").instantiate()
	root.add_child(s)
	s.open(run)
	for i in 20: await process_frame
	root.get_texture().get_image().save_png("/tmp/shop_%sx%s.png" % [sz[0], sz[1]])
	print("shop shot saved; content %.0f of %d" % [s.content_height(), root.size.y])
	quit()
