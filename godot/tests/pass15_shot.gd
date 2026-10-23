extends SceneTree
## Renders for pass 15 by eye: a twist round's intro and a round end with a
## synergy line, at SHOT_SIZE (default 720x1560). Writes /tmp/p15_*.png.
func _initialize() -> void:
	_go.call_deferred()
func _snap(name: String) -> void:
	for i in 12: await process_frame
	root.get_texture().get_image().save_png("/tmp/p15_%s.png" % name)
func _go() -> void:
	Achv.persist = false
	Achv.save_store({"__v": 3, "guided": 1})
	var sz := OS.get_environment("SHOT_SIZE").split("x") if OS.get_environment("SHOT_SIZE") != "" else PackedStringArray(["720", "1560"])
	root.size = Vector2i(int(sz[0]), int(sz[1]))
	var f: RunFlow = load("res://scenes/run_flow.tscn").instantiate()
	root.add_child(f)
	for i in 3: await process_frame
	var r := CribRun.new("pip", Meta.STREETS[0], null, 31)
	r.wager_at = {}
	r.twist_plan["1-1"] = "fifteen3"
	r.twist_plan["1-2"] = "pairs4"
	f.start_run(r)
	await _snap("intro")
	# a round end where two charms fed each other
	for sd in range(1, 400):
		var q := CribRun.new("thump", Meta.STREETS[0], null, 600 + sd)
		q.twist_plan = {}
		for id in ["keystone2", "ballast", "fifteener", "tallyman", "usury"].slice(sd % 3, sd % 3 + 3):
			q.charms.append(CribData.charm_by_id(id))
		var rd := CribRound.new(q)
		while rd.new_deal() != null:
			rd.commit(rd.best_keep_ev().idx)
			if rd.score >= rd.target or rd.deals_left <= 0:
				break
		rd.settle()
		if rd.won and rd.best_synergy() != null:
			f.run = q
			f.rd = rd
			f._paid = false
			f._round_end_effects()
			f._render_round_end()
			await _snap("synergy")
			break
	quit()
