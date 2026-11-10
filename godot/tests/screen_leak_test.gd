extends SceneTree
## Screens created and freed (half of them mid-cascade) must not accumulate
## objects. Baseline after the first screen is loaded scripts + cached textures.
##   godot --headless --path godot --script res://tests/screen_leak_test.gd
var first := -1
var last := -1
func _initialize() -> void:
	_go.call_deferred()
func _go() -> void:
	Achv.persist = false
	root.size = Vector2i(720, 1280)
	Engine.time_scale = 8.0
	var before := Performance.get_monitor(Performance.OBJECT_COUNT)
	for k in 12:
		var s: KeepScreen = load("res://scenes/keep_screen.tscn").instantiate()
		var ready := [false]
		s.dealt_ready.connect(func(): ready[0] = true)
		root.add_child(s)
		if k % 3 == 2:
			for i in 3: await process_frame    # freed MID-deal (cards still landing)
			s.queue_free()
			for i in 30: await process_frame
			await create_timer(1.0, true, false, true).timeout
			var m := int(Performance.get_monitor(Performance.OBJECT_COUNT) - before)
			last = m
			print("after screen %d (freed mid-deal): +%d objects" % [k, m])
			continue
		while not ready[0]: await process_frame
		s.hand.select_indices(s.rd.best_keep_ev().idx)
		s._commit()
		while not s.cascading: await process_frame
		if k % 3 == 1:
			s.queue_free()                 # freed MID-cascade
		else:
			while s.cascading: await process_frame
			s.queue_free()
		for i in 30: await process_frame
		await create_timer(1.5, true, false, true).timeout   # well past any beat, real time
		var n := int(Performance.get_monitor(Performance.OBJECT_COUNT) - before)
		if k == 0: first = n
		last = n
		print("after screen %d (%s): +%d objects, cached textures %d" % [k, "freed mid-cascade" if k % 3 == 1 else "finished", Performance.get_monitor(Performance.OBJECT_COUNT) - before, CardArt._cache.size()])
	var keep_growth := last - first
	print("objects grew by %d over 11 more screens" % keep_growth)
	# ---- the shop: each action re-renders; freed half the time mid-toast
	# CardArt caches every texture it loads (69 files, bounded). Warm it fully
	# so growth here can only be a leak: measured, each cached texture is 2 objects.
	for fn in DirAccess.get_files_at(CardArt.DIR):
		if fn.ends_with(".png"):
			CardArt._tex(CardArt.DIR + fn)
	print("card textures cached: %d" % CardArt._cache.size())
	# the charm icons (pass 19) are cached the same way, bounded by the charm list
	for ch in CribData.CHARMS:
		CharmIcon.texture(ch.id)
	print("charm icons cached: %d" % CharmIcon._cache.size())
	var shop_first := -1
	var shop_last := -1
	var shop_acts := 0
	for k in 8:
		var run := CribRun.new("clover", null, null, 7100 + k)
		run.essence = 200
		var sh: ShopScreen = load("res://scenes/shop_screen.tscn").instantiate()
		root.add_child(sh)
		sh.open(run)
		await process_frame
		for a in 6:
			var did: bool = [sh.do_reroll, func(): return sh.buy_level("pair"), func(): return sh.buy_card(sh.card_buttons.keys()[0]) if sh.card_buttons.size() > 0 else false][a % 3].call()
			shop_acts += int(did)
			await process_frame
		if k % 2 == 0:
			for i in 30: await process_frame
			await create_timer(2.5, true, false, true).timeout   # toast finished
		sh.queue_free()
		for i in 30: await process_frame
		await create_timer(1.0, true, false, true).timeout
		var n2 := int(Performance.get_monitor(Performance.OBJECT_COUNT) - before)
		if k == 0: shop_first = n2
		shop_last = n2
		print("after shop %d (%s): +%d objects, cached textures %d" % [k, "toast done" if k % 2 == 0 else "freed mid-toast", n2, CardArt._cache.size()])
	print("shop objects grew by %d over 7 more shops, %d actions" % [shop_last - shop_first, shop_acts])
	var good := first >= 0 and keep_growth <= 0 and shop_first >= 0 and shop_last - shop_first <= 0 and shop_acts >= 40
	print("SCREEN LEAK OK" if good else "SCREEN LEAK FAILED")
	quit(0 if good else 1)
