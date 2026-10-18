extends SceneTree
## Renders the cut ceremony on the real keep screen, mid-roll and revealed
## (needs xvfb-run).
func _initialize() -> void:
	_go.call_deferred()
func _go() -> void:
	Achv.persist = false
	root.size = Vector2i(720, 1280)
	var s: KeepScreen = load("res://scenes/keep_screen.tscn").instantiate()
	var ready := [false]
	s.dealt_ready.connect(func(): ready[0] = true)
	root.add_child(s)
	while not ready[0]:
		await process_frame
	s.hand.select_indices(s.rd.best_keep_ev().idx)
	for i in 10: await process_frame
	s._commit()
	await create_timer(0.35).timeout
	root.get_texture().get_image().save_png("/tmp/cut_roll.png")
	# the reveal holds for plan.hold after plan.roll; capture inside the hold
	await create_timer(s.last_cut_plan.roll - 0.35 + 0.3).timeout
	root.get_texture().get_image().save_png("/tmp/cut_reveal.png")
	print("cut shots saved: tier %s" % s.last_cut_plan.tier)
	quit()
