extends SceneTree
## Renders the run-flow pages (needs xvfb-run). SHOT_SIZE=WxH for other shapes.
## Writes /tmp/flow_<page>_<W>x<H>.png for: plain intro with a banked skip,
## a wager, a boss, a won and a lost round end, and the run-won page.
func _initialize() -> void:
	_go.call_deferred()


func _round(run: CribRun, keep_best: bool) -> CribRound:
	var rd := CribRound.new(run)
	while rd.new_deal() != null:
		var idx: Array = rd.best_keep_ev().idx if keep_best else [0, 1, 2, 3]
		rd.commit(idx)
		if rd.score >= rd.target or rd.deals_left <= 0:
			break
	rd.settle()
	return rd


func _go() -> void:
	Achv.persist = false
	Achv.save_store({"__v": 3})
	var sz := OS.get_environment("SHOT_SIZE").split("x") if OS.get_environment("SHOT_SIZE") != "" else PackedStringArray(["720", "1280"])
	root.size = Vector2i(int(sz[0]), int(sz[1]))
	var tag := "%sx%s" % [sz[0], sz[1]]
	var f: RunFlow = load("res://scenes/run_flow.tscn").instantiate()
	root.add_child(f)
	await process_frame
	var shots := []
	# plain intro with a skip banked
	var r := CribRun.new("pip", null, null, 5150)
	r.skips = 1
	f.start_run(r)
	shots.append("intro")
	await _snap(f, "intro", tag)
	# a wager
	var w := CribRun.new("pip", null, null, 5150)
	for k in w.wager_at:
		var p: PackedStringArray = k.split("-")
		w.act = int(p[0])
		w.round = int(p[1])
		break
	f.start_run(w)
	await _snap(f, "wager", tag)
	# a boss
	var b := CribRun.new("thump", null, null, 5150)
	b.act = 3
	b.round = CribData.ROUNDS
	f.start_run(b)
	await _snap(f, "boss", tag)
	# round ends
	var strong := CribRun.new("thump", null, null, 77)
	for id in ["keystone2", "ballast", "fifteener", "tallyman", "usury"]:
		strong.charms.append(CribData.charm_by_id(id))
	f.run = strong
	f.rd = _round(strong, true)
	f._paid = false
	f._round_end_effects()
	f._render_round_end()
	await _snap(f, "won_end", tag)
	var weak := CribRun.new("pip", null, null, 77)
	weak.act = 4
	f.run = weak
	f.rd = _round(weak, false)
	f._paid = false
	f._round_end_effects()
	f._render_round_end()
	await _snap(f, "lost_end", tag)
	# run won
	f.run = strong
	f.show_run_won()
	await _snap(f, "run_won", tag)
	quit()


func _snap(f: RunFlow, page: String, tag: String) -> void:
	for i in 12:
		await process_frame
	var path := "/tmp/flow_%s_%s.png" % [page, tag]
	root.get_texture().get_image().save_png(path)
	print("%s: screen=%s buttons=%s" % [path, f.screen, f.buttons.keys()])
