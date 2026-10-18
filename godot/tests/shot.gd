extends SceneTree
## Renders the keep screen to PNGs (needs a display; use xvfb-run).
##   xvfb-run godot --path godot --rendering-method gl_compatibility --script res://tests/shot.gd
func _initialize() -> void:
	_go.call_deferred()

func _go() -> void:
	Achv.persist = false
	var sz := OS.get_environment("SHOT_SIZE").split("x") if OS.get_environment("SHOT_SIZE") != "" else PackedStringArray(["720", "1280"])
	root.size = Vector2i(int(sz[0]), int(sz[1]))
	var tag := "%sx%s" % [sz[0], sz[1]]
	var s: KeepScreen = load("res://scenes/keep_screen.tscn").instantiate()
	var ready := [false]
	s.dealt_ready.connect(func(): ready[0] = true)
	var done := [false]
	root.add_child(s)
	while not ready[0]:
		await process_frame
	# SHOT_BUILD=foresight,recut,keystone2 restarts on a run owning those charms,
	# and mulligans once so the crib strip has cards.
	if OS.get_environment("SHOT_BUILD") != "":
		var run := CribRun.new(s.meldling, null, null, s.seed)
		for id in OS.get_environment("SHOT_BUILD").split(","):
			run.charms.append(CribData.charm_by_id(id))
		ready[0] = false
		s.start_round(run)
		while not ready[0]:
			await process_frame
		ready[0] = false
		s._on_mulligan()
		while not ready[0]:
			await process_frame
	s.hand.select_indices(s.rd.best_keep_ev().idx)
	for i in 30: await process_frame
	root.get_texture().get_image().save_png("/tmp/shot_keep_%s.png" % tag)
	s._commit()
	while not s.cascading:
		await process_frame
	await create_timer(1.1).timeout
	root.get_texture().get_image().save_png("/tmp/shot_mid_%s.png" % tag)
	while s.cascading:
		await process_frame
	for i in 30: await process_frame
	root.get_texture().get_image().save_png("/tmp/shot_count_%s.png" % tag)
	print("shots saved")
	quit()
