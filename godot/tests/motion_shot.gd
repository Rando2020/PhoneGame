extends SceneTree
## Mid-flight frames of pass 21's motion (needs xvfb-run): /tmp/motion_*.png
func _initialize() -> void:
	_go.call_deferred()
func _shot(name: String) -> void:
	root.get_texture().get_image().save_png("/tmp/motion_%s.png" % name)
func _go() -> void:
	Achv.persist = false
	Achv.save_store({"__v": 3, "guided": 1})
	root.size = Vector2i(720, 1560)
	# shop purchase, mid-flight
	var run := CribRun.new("thump", Meta.STREETS[0], null, 2101)
	run.essence = 90
	for id in ["keystone2", "ballast"]:
		run.charms.append(CribData.charm_by_id(id))
	run.open_shop()
	run.shop_state.offer = ["fifteener", "fever", "peacock"].map(func(i): return CribData.charm_by_id(i))
	var sh: ShopScreen = load("res://scenes/shop_screen.tscn").instantiate()
	root.add_child(sh)
	sh.size = Vector2(720, 1560)
	sh.open(run)
	sh.finish()
	for i in 10: await process_frame
	sh.buy_charm(CribData.charm_by_id("fever"))
	for i in 9: await process_frame
	_shot("shop_mid")
	for i in 60: await process_frame
	_shot("shop_end")
	sh.queue_free()
	# Gallery mid-flip
	Achv.save_store({"__v": 3, "guided": 1, "charms": {"fifteener": 3, "fever": 2, "peacock": 2, "facecard": 2, "quartermaster": 1},
		"charms_shown": {"fifteener": 1, "fever": 0, "peacock": 0, "facecard": 1, "quartermaster": 0}})
	var f: RunFlow = load("res://scenes/run_flow.tscn").instantiate()
	root.add_child(f)
	for i in 3: await process_frame
	Menus.gal_tab = "charms"
	f.front.go("gallery")
	f.settle()
	for i in 14: await process_frame
	_shot("gallery_mid")
	# round end mid-count
	var rr := CribRun.new("thump", Meta.STREETS[0], null, 2102)
	rr.twist_plan = {}
	var rd := CribRound.new(rr)
	while rd.new_deal() != null:
		rd.commit(rd.best_keep_ev().idx)
		if rd.score >= rd.target or rd.deals_left <= 0:
			break
	rd.settle()
	f.run = rr
	f.rd = rd
	f._paid = true
	f._no_slide = true
	f._render_round_end()
	f._no_slide = false
	f._round_end_motion()
	for i in 14: await process_frame
	_shot("round_mid")
	# the Shortage stamp landing
	var sr := CribRun.new("pip", Meta.STREETS[0], null, 2103)
	sr.wager_at = {}
	sr.cat_points = {"fifteen": 2, "pair": 12, "run": 1, "flush": 0}
	sr.round = 2
	f._no_slide = true
	f.start_run(sr)
	f._no_slide = false
	f._stamp(f.short_line)
	for i in 4: await process_frame
	_shot("stamp_mid")
	print("motion shots saved")
	quit()
