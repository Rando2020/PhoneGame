extends SceneTree
## Renders the Gallery's Charms tab with a mix of states, and the first-purchase
## card, at SHOT_SIZE (default 720x1560): /tmp/gallery_charms_<size>.png and
## /tmp/charm_first_<size>.png. The store's "Collect them all" shot uses the first.
func _initialize() -> void:
	_go.call_deferred()
func _go() -> void:
	Achv.persist = false
	var st := {"__v": 3, "guided": 1}
	var c := {}
	var i := 0
	for ch in CribData.CHARMS:      # a believable mid-game collection, fixed
		c[ch.id] = [3, 2, 2, 1, 2, 1, 0, 2, 1, 0, 3, 2][i % 12]
		i += 1
	st["charms"] = c
	Achv.save_store(st)
	var sz := OS.get_environment("SHOT_SIZE").split("x") if OS.get_environment("SHOT_SIZE") != "" else PackedStringArray(["720", "1560"])
	root.size = Vector2i(int(sz[0]), int(sz[1]))
	var tag := "%sx%s" % [sz[0], sz[1]]
	var f: RunFlow = load("res://scenes/run_flow.tscn").instantiate()
	root.add_child(f)
	for k in 3: await process_frame
	Menus.gal_tab = "charms"
	f.front.go("gallery")
	f.settle()
	for k in 20: await process_frame
	root.get_texture().get_image().save_png("/tmp/gallery_charms_%s.png" % tag)
	f.move_child(f.deed_toast, -1)      # as RunFlow does before a toast
	f.deed_toast.celebrate_charm(CribData.charm_by_id("keystone2"))
	for k in 40: await process_frame
	root.get_texture().get_image().save_png("/tmp/charm_first_%s.png" % tag)
	print("collection shots saved ", tag)
	quit()
