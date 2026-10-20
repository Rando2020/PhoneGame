extends SceneTree
## Dead space (audit #12): the tallest empty band (no visible control drawn in
## it) between the safe top and the bottom button on the intro (plain, Spoiler,
## wager) and the round end (won, lost, Spoiler), at 720x1560 and 720x1280.
## Must be under 18% of the screen height. Prints each band for docs/AUDIT.md.
##   godot --headless --path godot --script res://tests/dead_space_test.gd
const LIMIT := 0.18
var checks := 0
var fails := 0


func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("FAIL ", m)


func _initialize() -> void:
	_go.call_deferred()


## The tallest band with nothing in it, from the first control to the lowest
## button's top. Backgrounds (anything over 80% of the height) don't count.
static func gap(page: Node, view: Vector2) -> float:
	var spans := []
	var bottom := view.y
	for c in page.find_children("*", "Control", true, false):
		var ctl := c as Control
		if not ctl.is_visible_in_tree() or ctl.modulate.a < 0.05 or ctl.get_child_count() > 0 and ctl.size.y > view.y * 0.8:
			continue
		var g := ctl.get_global_rect()
		if g.size.y > view.y * 0.8 or g.size.y < 1.0 or g.end.y < 0 or g.position.y > view.y:
			continue
		spans.append([g.position.y, g.end.y])
		if ctl is Button and ctl.size.y >= 80.0:
			bottom = minf(bottom, g.position.y)
	spans.sort_custom(func(a, b): return a[0] < b[0])
	var reach: float = spans[0][1] if not spans.is_empty() else 0.0
	var worst := 0.0
	for s in spans:
		if s[0] > bottom:
			break
		worst = maxf(worst, s[0] - reach)
		reach = maxf(reach, s[1])
	return maxf(worst, bottom - reach)


func _round(run: CribRun, keep_best: bool) -> CribRound:
	var rd := CribRound.new(run)
	while rd.new_deal() != null:
		rd.commit(rd.best_keep_ev().idx if keep_best else [0, 1, 2, 3])
		if rd.score >= rd.target or rd.deals_left <= 0:
			break
	rd.settle()
	return rd


func _enter(f: RunFlow, st: String) -> void:
	match st:
		"intro":
			f.start_run(CribRun.new("pip", null, null, 5150))
		"wager":
			var w := CribRun.new("pip", null, null, 5150)
			for k in w.wager_at:
				w.act = int(k.split("-")[0])
				w.round = int(k.split("-")[1])
				break
			f.start_run(w)
		"boss":
			var b := CribRun.new("thump", null, null, 5150)
			b.act = 3
			b.round = CribData.ROUNDS
			f.start_run(b)
		"won_end", "lost_end", "boss_end":
			var r := CribRun.new("thump" if st != "lost_end" else "pip", null, null, 77)
			if st != "lost_end":
				for id in ["keystone2", "ballast", "fifteener", "tallyman", "usury"]:
					r.charms.append(CribData.charm_by_id(id))
			if st == "boss_end":
				r.round = CribData.ROUNDS
			if st == "lost_end":
				r.act = 4
			f.run = r
			f.rd = _round(r, st != "lost_end")
			f._paid = false
			f._round_end_effects()
			f._render_round_end()


## The Play: after the first lays, a full pile (seed 5294), and the payout.
func _peg(st: String, view: Vector2) -> PegView:
	Achv.grant_system("the_play")
	# the first seed from 5294 (busy) / 5106 that reaches the wanted pile
	for sd in range(5294 if st == "peg_busy" else 5106, 5600):
		var ps = _peg_session(st, sd)
		if ps != null:
			var v := PegView.new()
			root.add_child(v)
			v.size = view
			v.open(ps)
			return v
	return null


func _peg_session(st: String, sd: int):
	var r := CribRun.new("thump", null, null, sd)
	for id in ["keystone2", "ballast"]:
		r.charms.append(CribData.charm_by_id(id))
	r.act = 3
	r.round = CribData.ROUNDS
	var rd := CribRound.new(r)
	rd.new_deal()
	var idx: Array = rd.best_keep_ev().idx
	var kept: Array = idx.map(func(i): return rd.dealt[i])
	rd.commit(idx)
	var ps := PegSession.start(rd, kept)
	if ps.playable_indices().is_empty():
		return null
	ps.lay(ps.playable_indices()[0])
	ps.answer()
	if st == "peg_busy":
		while not (ps.play.pile.size() >= 6 and ps.play.mine.size() >= 1):
			if ps.play.over or ps.playable_indices().is_empty():
				return null
			ps.lay(ps.playable_indices()[0])
			ps.answer()
	elif st == "peg_payout":
		while not ps.play.over:
			if ps.playable_indices().is_empty():
				return null
			ps.lay(ps.playable_indices()[0])
			ps.answer()
	return ps


func _go() -> void:
	Achv.persist = false
	Achv.save_store({"__v": 3})
	for view in [Vector2(720, 1560), Vector2(720, 1280)]:
		root.size = Vector2i(view)
		var f: RunFlow = load("res://scenes/run_flow.tscn").instantiate()
		root.add_child(f)
		for i in 3:
			await process_frame
		var tag := "%dx%d" % [view.x, view.y]
		for st in ["intro", "wager", "boss", "won_end", "lost_end", "boss_end"]:
			_enter(f, st)
			f.settle()
			await process_frame
			var g := gap(f, view)
			print("%s %s: empty band %d px (%d%%)" % [tag, st, g, roundi(g / view.y * 100.0)])
			ok(g < view.y * LIMIT, "%s %s: empty band %d px, over %d%% of the height" % [tag, st, g, roundi(LIMIT * 100)])
		f.queue_free()
		await process_frame
		for st in ["peg_early", "peg_busy", "peg_payout"]:
			var v := _peg(st, view)
			await process_frame
			var g := gap(v, view)
			print("%s %s: empty band %d px (%d%%)" % [tag, st, g, roundi(g / view.y * 100.0)])
			ok(g < view.y * LIMIT, "%s %s: empty band %d px, over %d%% of the height" % [tag, st, g, roundi(LIMIT * 100)])
			v.queue_free()
			await process_frame
	print("dead_space_test: %d checks, %d fails" % [checks, fails])
	quit(1 if fails > 0 else 0)
