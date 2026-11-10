extends SceneTree
## Meldlings 2.0 reactions. Every game event maps to the right pose for every
## Meldling (signatures only on their own rule), reactions return to idle (or
## hold, for victory and defeat), haptics fire with the reaction, Reduce Motion
## keeps the sprite still, presentation draws nothing from any rng, and the
## real screens put the sprite up and react.
##   godot --headless --path godot --script res://tests/meld_test.gd
var checks := 0
var fails := 0


func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("FAIL ", m)


func _initialize() -> void:
	_go.call_deferred()


func _rd(meld: String, boss := false) -> CribRound:
	var run := CribRun.new(meld, null, null, 77)
	if boss:
		run.round = CribData.ROUNDS
	return CribRound.new(run)


func _res(kinds: Array, total := 5, cut_gain := 0) -> Dictionary:
	return {"events": kinds.map(func(k): return {"kind": k, "points": 2}), "total": total, "cutGain": cut_gain}


func _go() -> void:
	Achv.persist = false
	root.size = Vector2i(720, 1560)
	var melds := ["pip", "thump", "clover", "facet", "nib", "muggins"]
	# what each Meldling's own rule looks like, as a count
	var hit := {"pip": ["fifteen"], "thump": ["pair"], "clover": [], "facet": ["flush"], "nib": [], "muggins": []}
	for m in melds:
		var rd := _rd(m)
		# deal: eager, or nervous on the last deal while short
		ok(MeldReact.pose_for("deal", m, rd) == "eager", "%s deal" % m)
		rd.deals_left = 1
		ok(MeldReact.pose_for("deal", m, rd) == "nervous", "%s last deal, short" % m)
		rd.score = rd.target
		ok(MeldReact.pose_for("deal", m, rd) == "eager", "%s last deal, already there" % m)
		rd = _rd(m)
		# a small plain count: nothing
		ok(MeldReact.pose_for("count", m, rd, _res(["run"], 4)) == "", "%s small run count" % m)
		# a big count: cheer
		var big := MeldReact.big_count(rd)
		ok(MeldReact.pose_for("count", m, rd, _res(["run"], big)) == "cheer", "%s big count" % m)
		ok(MeldReact.pose_for("count", m, rd, _res(["run"], big - 1)) == "", "%s just under big" % m)
		# its own rule: the signature, even on a small count
		var sres := _res(hit[m], 3, 5 if m == "clover" else 0)
		var srd := _rd(m, m == "muggins")
		if m == "nib":
			srd.auto_recuts = 1
		ok(MeldReact.pose_for("count", m, srd, sres) == MeldReact.SIGNATURE[m], "%s signature: got '%s'" % [m, MeldReact.pose_for("count", m, srd, sres)])
		# on a big count too: the signature beats a plain cheer
		var bres := _res(hit[m], MeldReact.big_count(srd), 5 if m == "clover" else 0)
		ok(MeldReact.pose_for("count", m, srd, bres) == MeldReact.SIGNATURE[m], "%s signature on a big count: got '%s'" % [m, MeldReact.pose_for("count", m, srd, bres)])
		# and not on another Meldling's rule
		for other in melds:
			if other == m or other == "clover" or other == "nib" or other == "muggins":
				continue
			if hit[other].is_empty():
				continue
			ok(MeldReact.pose_for("count", m, _rd(m), _res(hit[other], 3)) == "", "%s fired on %s's rule" % [m, other])
		ok(MeldReact.pose_for("round_won", m, rd) == "victory", "%s round won" % m)
		ok(MeldReact.pose_for("run_lost", m, rd) == "deflated", "%s run lost" % m)
		# every pose has art
		for p in MeldReact.POSES + [MeldReact.SIGNATURE[m]]:
			ok(ResourceLoader.exists("res://art/meldlings2/%s_%s.png" % [m, p]), "%s_%s.png missing" % [m, p])
	# a clover cut that adds 3 is not lucky; nib with no auto recut isn't snipping
	ok(MeldReact.pose_for("count", "clover", _rd("clover"), _res([], 3, 3)) == "", "clover small cut")
	ok(MeldReact.pose_for("count", "nib", _rd("nib"), _res([], 3)) == "", "nib no recut")
	ok(MeldReact.pose_for("count", "muggins", _rd("muggins"), _res([], 3)) == "", "muggins off a Spoiler round")
	# ascended Meldlings wear the base art
	for a in ["pip_asc", "thump_asc", "clover_asc", "facet_asc"]:
		ok(MeldReact.art_id(a) == a.trim_suffix("_asc"), "art for " + a)

	# ---- the sprite: hold, return to idle, haptics, locked, reduce motion
	Haptics.log.clear()
	var sp := MeldSprite.new("thump")
	sp.size = Vector2(200, 200)
	root.add_child(sp)
	sp.react("cheer")
	ok(sp.pose == "cheer" and Haptics.log == [25], "cheer plays and buzzes: %s %s" % [sp.pose, Haptics.log])
	for i in 60:
		sp.step(1.0 / 60.0)
	ok(sp.pose == "cheer", "cheer held for 1 s")
	for i in 60:
		sp.step(1.0 / 60.0)
	ok(sp.pose == "idle", "back to idle after the hold: %s" % sp.pose)
	sp.react("victory")
	for i in 600:
		sp.step(1.0 / 60.0)
	ok(sp.pose == "victory" and Haptics.log.back() == 70, "victory holds, long buzz")
	sp.react("slam")
	ok(sp.pose == "slam", "a new reaction replaces a held one")
	sp.set_meld("facet", true)
	sp.react("cheer")
	ok(sp.pose == "idle", "a locked silhouette doesn't react")
	MeldSprite.reduce_motion = true
	sp.set_meld("facet")
	sp.react("cheer")
	var still := true
	for i in 30:
		sp.step(1.0 / 60.0)
		still = still and sp._tex.scale == Vector2.ONE and sp._tex.position == Vector2.ZERO
	ok(still, "Reduce Motion: no squash, no bob")
	MeldSprite.reduce_motion = false
	sp.react("cheer")
	var moved := false
	for i in 30:
		sp.step(1.0 / 60.0)
		moved = moved or sp._tex.scale != Vector2.ONE
	ok(moved, "a reaction squashes and springs back")
	# a long frame must not blow the spring up (it flattened the intro sprite)
	sp.react("eager")
	sp.step(0.5)
	sp.step(0.5)
	var sc: Vector2 = sp._tex.scale
	ok(absf(sc.x - 1.0) < 0.05 and absf(sc.y - 1.0) < 0.05, "settled after two long frames: %s" % sc)
	sp.queue_free()

	# ---- presentation only: reacting draws from no rng
	var rd2 := _rd("pip")
	var before := [JS.unseeded.s, rd2.run.rng.s]
	var s2 := MeldSprite.new("pip")
	for e in ["deal", "count", "round_won", "run_lost"]:
		s2.on_event(e, rd2, _res(["fifteen"], 40))
	ok([JS.unseeded.s, rd2.run.rng.s] == before, "a reaction drew from an rng")
	s2.free()

	# ---- the real screens
	var k: KeepScreen = load("res://scenes/keep_screen.tscn").instantiate()
	k.meldling = "clover"
	root.add_child(k)
	k.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for i in 30:
		await process_frame
	ok(k.meld_sprite != null and k.meld_sprite.meld == "clover" and k.meld_sprite.visible, "keep screen shows your Meldling")
	ok(k.meld_sprite.pose in ["eager", "nervous"] and k.meld_sprite.reactions >= 1, "the deal made it react: %s" % k.meld_sprite.pose)
	var r := k.meld_sprite.get_global_rect()
	ok(r.size.x >= 100 and Rect2(Vector2.ZERO, Vector2(root.size)).encloses(r), "sprite on screen: %s" % r)
	ok(not r.intersects(k.hand.get_global_rect()), "sprite clear of the hand")
	k.queue_free()
	var f: RunFlow = load("res://scenes/run_flow.tscn").instantiate()
	root.add_child(f)
	await process_frame
	ok(f.front.parade.size() == 6, "title parade of six: %d" % f.front.parade.size())
	f.front.go("meld")
	await process_frame
	ok(f.front.meld_view != null and f.front.meld_view.get_global_rect().size.x > 150, "the picker shows the Meldling")
	f.start_run(CribRun.new("facet", Meta.STREETS[0], null, 5))
	await process_frame
	ok(f.meld_view != null and f.meld_view.meld == "facet" and f.meld_view.pose == "eager", "the intro shows your Meldling, eager")
	f.queue_free()
	await process_frame

	print("meld checks: %d, failures: %d" % [checks, fails])
	var good := fails == 0 and checks >= 130
	print("MELD OK" if good else "MELD FAILED")
	quit(0 if good else 1)
