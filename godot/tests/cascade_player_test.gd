extends RefCounted
## CascadeView: full plays and skips at every kind of moment must all land on
## res.total, emit `finished` exactly once, and keep the row list inside its box.
## Called by cascade_test.gd with real engine results.

var T


func run(test, all: Array) -> void:
	T = test
	var tree: SceneTree = test
	tree.root.size = Vector2i(720, 1280)
	Engine.time_scale = 16.0
	var v := CascadeView.new()
	v.size = Vector2(672, 520)
	tree.root.add_child(v)
	await tree.process_frame
	var lit := [0]
	var modes := ["full", "skip_now", "skip_mid", "skip_slam", "skip_twice", "skip_after"]
	var t0 := Time.get_ticks_msec()
	var played := 0
	var worst := 0
	for i in range(0, all.size(), 9):        # ~170 results x one mode each
		var res: Dictionary = all[i][0]
		var plan := CascadePlan.build(res, all[i][1], all[i][2])
		var mode: String = modes[(i / 9) % modes.size()]
		var fin := [0]
		var on_fin := func(): fin[0] += 1
		v.finished.connect(on_fin)
		var landed := [-1]
		var on_land := func(k): landed[0] = k
		v.beat_landed.connect(on_land)
		v.play(plan, func(_c): lit[0] += 1)
		var w := "result %d (%s)" % [i, mode]
		match mode:
			"skip_now":
				v.skip()
			"skip_mid":
				var target: int = plan.beats.size() / 2 - 1
				while landed[0] < target and fin[0] == 0:
					await tree.process_frame
				v.skip()
			"skip_slam":
				while landed[0] < plan.beats.size() - 2 and fin[0] == 0:
					await tree.process_frame
				await tree.process_frame
				v.skip()
			"skip_twice":
				await tree.process_frame
				v.skip()
				v.skip()
		var guard := 0
		while fin[0] == 0 and guard < 4000:
			guard += 1
			await tree.process_frame
		if mode == "skip_after":
			v.skip()                          # after it finished on its own: must be a no-op
		for k in 3:
			await tree.process_frame          # let any stranded coroutine wake and bail
		T.ok(fin[0] == 1, "%s: finished emitted %d times" % [w, fin[0]])
		T.ok(v.shown == res.total and v.number.text == str(res.total), "%s: shows %s, total %d" % [w, v.number.text, res.total])
		var slam: Dictionary = plan.beats[plan.beats.size() - 1]
		T.ok(v.mult_label.text == slam.mult_line, "%s: mult line %s" % [w, v.mult_label.text])
		T.ok(v.tier_label.text == ("TWENTY-NINE" if plan.perfect else plan.tier.word), "%s: tier word" % w)
		T.ok(v.lines_box.get_child_count() == plan.lines.size(), "%s: %d coaching lines" % [w, v.lines_box.get_child_count()])
		T.ok(v.list.get_child_count() * CascadeView.ROW_H <= v.list_h + 0.5, "%s: %d rows overflow %.0f px" % [w, v.list.get_child_count(), v.list_h])
		T.ok(v.number.scale.is_equal_approx(Vector2.ONE) or mode == "full", "%s: number left scaled" % w)
		# worst case: round-end lines appended under clutch + TARGET MET
		v.add_line("Crib +12", "dim")
		v.add_line("Round cleared.", "green")
		var need := 0.0
		for l in v.lines_box.get_children():
			need += l.get_combined_minimum_size().y + v.lines_box.get_theme_constant("separation")
		T.ok(need <= v.lines_box.size.y + 1.0, "%s: footer needs %.0f, has %.0f" % [w, need, v.lines_box.size.y])
		# measured from the rows themselves, not the container's (self-inflating) size
		var rows_bottom: float = v.list.position.y + v.list.get_child_count() * CascadeView.ROW_H
		T.ok(rows_bottom <= v.tier_label.position.y + 0.5,
			"%s: rows collide with the footer: list y %.0f h %.0f rows %d max %d, tier y %.0f, lines %d need %.0f" % [w, v.list.position.y, v.list.size.y, v.list.get_child_count(), v.max_rows(), v.tier_label.position.y, v.lines_box.get_child_count(), need])
		worst = maxi(worst, v.lines_box.get_child_count())
		v.finished.disconnect(on_fin)
		v.beat_landed.disconnect(on_land)
		played += 1
		T.players_ran = played
	T.ok(lit[0] > 0, "cards were lit during plays")
	Engine.time_scale = 1.0
	print("most footer lines in one cascade: %d" % worst)
	print("player: %d cascades across %d modes, %d ms" % [played, modes.size(), Time.get_ticks_msec() - t0])
	v.queue_free()
