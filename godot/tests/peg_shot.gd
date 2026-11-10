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
	run.round = CribData.ROUNDS
	var rd := CribRound.new(run)
	rd.new_deal()
	var idx: Array = rd.best_keep_ev().idx
	var kept: Array = idx.map(func(i): return rd.dealt[i])
	rd.commit(idx)
	var s := PegSession.start(rd, kept)
	var v := PegView.new()
	root.add_child(v)
	v.size = root.get_visible_rect().size
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
	# the store shot (seed found by search): a full pile at 23, both sides on
	# the board, cards still in hand, the Act 3 Spoiler across the table
	# searched from 5294 (the seed before 3 rounds an act and twists)
	var bs: PegSession = null
	var picked := -1
	for sd in range(5294, 6500):
		bs = _busy(sd)
		if bs != null:
			picked = sd
			break
	print("peg_busy seed ", picked)
	v.open(bs)
	v.render()
	for i in 20: await process_frame
	root.get_texture().get_image().save_png("/tmp/peg_busy_%s.png" % tag)
	print("peg shots saved %s: pegs %d, Spoiler %d, gain %d" % [tag, s.play.score, s.play.opp_score, s.gain()])
	quit()


## The store shot's pile, or null: 6+ cards down at 20 or more, both sides
## pegged, a card still in your hand (never loops: stops when stuck).
func _busy(sd: int) -> PegSession:
	var br := CribRun.new("thump", null, null, sd)
	for id in ["keystone2", "ballast"]:
		br.charms.append(CribData.charm_by_id(id))
	br.act = 3
	br.round = CribData.ROUNDS
	var bd := CribRound.new(br)
	bd.new_deal()
	var bidx: Array = bd.best_keep_ev().idx
	var bkept: Array = bidx.map(func(i): return bd.dealt[i])
	bd.commit(bidx)
	var bs := PegSession.start(bd, bkept)
	for guard in 20:
		if bs.play.pile.size() >= 6 and bs.play.mine.size() >= 1:
			return bs if bs.play.total >= 20 and bs.play.score > 0 and bs.play.opp_score > 0 else null
		if bs.play.over or bs.playable_indices().is_empty():
			return null
		bs.lay(bs.playable_indices()[0])
		bs.answer()
	return null
