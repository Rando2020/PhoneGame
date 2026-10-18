extends SceneTree
## Renders the front door (needs xvfb-run). SHOT_SIZE=WxH. /tmp/front_<step>_<W>x<H>.png
func _initialize() -> void:
	_go.call_deferred()

func _go() -> void:
	Achv.persist = false
	Achv.save_store({"__v": 3})
	Achv.unlock_street(3)
	Achv.grant("long_road")
	Achv.mark_trial("pauper")
	RunRecord.record(CribRun.new("pip"), 17, 412)
	Achv.add_pegs(70)
	Achv.buy_back("crimson")
	Achv.set_back("crimson")
	var sz := OS.get_environment("SHOT_SIZE").split("x") if OS.get_environment("SHOT_SIZE") != "" else PackedStringArray(["720", "1280"])
	root.size = Vector2i(int(sz[0]), int(sz[1]))
	var f: RunFlow = load("res://scenes/run_flow.tscn").instantiate()
	root.add_child(f)
	for step in ["title", "road", "street", "trial", "meld", "peddler"]:
		f.cb.street = Meta.STREETS[1]
		f.cb.meld_idx = 3
		f.show_front_door(step)
		for i in 8: await process_frame
		root.get_texture().get_image().save_png("/tmp/front_%s_%sx%s.png" % [step, sz[0], sz[1]])
	print("front shots %sx%s" % [sz[0], sz[1]])
	quit()
