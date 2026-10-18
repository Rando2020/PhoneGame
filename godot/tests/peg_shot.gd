extends SceneTree
## Renders The Play (needs xvfb-run): mid-play and the payout.
## SHOT_SIZE=WxH for other shapes. Writes /tmp/peg_<state>_<W>x<H>.png.
func _initialize() -> void:
	_go.call_deferred()

func _go() -> void:
	Achv.persist = false
	Achv.save_store({"__v": 3})
	Achv.grant_system("the_play")
	var sz := OS.get_environment("SHOT_SIZE").split("x") if OS.get_environment("SHOT_SIZE") != "" else PackedStringArray(["720", "1280"])
	root.size = Vector2i(int(sz[0]), int(sz[1]))
	var tag := "%sx%s" % [sz[0], sz[1]]
	var run := CribRun.new("thump", null, null, 5106)
	for id in ["keystone2", "ballast"]:
		run.charms.append(CribData.charm_by_id(id))
	run.act = 3
	run.round = 5
	var rd := CribRound.new(run)
	rd.new_deal()
	var idx: Array = rd.best_keep_ev().idx
	var kept: Array = idx.map(func(i): return rd.dealt[i])
	rd.commit(idx)
	var s := PegSession.start(rd, kept)
	var v := PegView.new()
	root.add_child(v)
	v.size = Vector2(root.size)
	v.open(s)
	s.lay(s.playable_indices()[0])
	s.answer()
	v.render()
	for i in 20: await process_frame
	root.get_texture().get_image().save_png("/tmp/peg_mid_%s.png" % tag)
	while not s.play.over:
		s.lay(s.playable_indices()[0])
		s.answer()
	v.render()
	for i in 20: await process_frame
	root.get_texture().get_image().save_png("/tmp/peg_payout_%s.png" % tag)
	print("peg shots saved %s: pegs %d, Spoiler %d, gain %d" % [tag, s.play.score, s.play.opp_score, s.gain()])
	quit()
