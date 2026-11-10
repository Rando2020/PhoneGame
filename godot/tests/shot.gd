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
	# the store shot: searched from the keep screen's seed for a deal whose best
	# keep clears the round in one count, on a twist round (so the header shows
	# one). Engine changes move deals; this keeps the shot a real, strong count.
	if OS.get_environment("SHOT_BUILD") == "":
		var pick := -1
		for sd in range(s.seed, s.seed + 3000):
			var tr := CribRun.new(s.meldling, null, null, sd)
			if tr.twist() == null:
				continue
			var td := CribRound.new(tr)
			if td.new_deal() == null:
				continue
			var res = td.commit(td.best_keep_ev().idx)
			if res.total >= td.target and res.total < td.target * 2.2:
				pick = sd
				break
		print("shot seed ", pick)
		if pick >= 0:
			ready[0] = false
			s.start_round(CribRun.new(s.meldling, null, null, pick))
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
