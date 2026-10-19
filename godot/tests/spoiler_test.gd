extends SceneTree
## Spoilers as characters. Every BOSS_POOL Spoiler has all five poses at its own
## severity; counts map to stung / smug / nothing; it smirks when it pegs;
## round won -> defeated and run lost -> gloat (both hold); reactions return to
## idle; no rng drawn; and the real screens put it up: boss intro, the keep
## screen on a Spoiler round (only then), The Play (no name text in place of
## it), round end beside your Meldling.
##   godot --headless --path godot --script res://tests/spoiler_test.gd
var checks := 0
var fails := 0


func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("FAIL ", m)


func _initialize() -> void:
	_go.call_deferred()


func _boss_round(seed := 77) -> CribRound:
	var run := CribRun.new("pip", null, null, seed)
	run.round = CribData.ROUNDS
	return CribRound.new(run)


func _go() -> void:
	Achv.persist = false
	root.size = Vector2i(720, 1560)
	# ---- art: every Spoiler, every pose, at its severity
	for b in CribData.BOSS_POOL:
		for p in SpoilerSprite.POSES:
			ok(ResourceLoader.exists(SpoilerSprite.path_for(b.art, b.sev, p)), "%s: %s missing" % [b.id, SpoilerSprite.path_for(b.art, b.sev, p)])
	# ---- events
	var rd := _boss_round()
	var share := SpoilerSprite.share(rd)
	ok(share == int(ceil(float(rd.target) / (CribData.DEALS + int(rd.mods.get("dealBonus", 0))))), "share")
	var cases := [
		[{"total": share, "suppressed": 0}, "stung", "made the share"],
		[{"total": share + 30, "suppressed": 6}, "stung", "made the share despite the rule"],
		[{"total": share - 1, "suppressed": 6}, "smug", "the rule bit and you fell short"],
		[{"total": share - 1, "suppressed": 1}, "smug", "the rule took one point"],
		[{"total": share - 1, "suppressed": 0}, "", "short, but not the rule's doing"],
		[{"total": 0, "suppressed": 0}, "", "a zero count"],
	]
	for c in cases:
		ok(SpoilerSprite.pose_for("count", rd, c[0]) == c[1], "count, %s: got '%s'" % [c[2], SpoilerSprite.pose_for("count", rd, c[0])])
	ok(SpoilerSprite.pose_for("peg", rd) == "smug", "pegging")
	ok(SpoilerSprite.pose_for("round_won", rd) == "defeated", "round won")
	ok(SpoilerSprite.pose_for("run_lost", rd) == "gloat", "run lost")
	ok(SpoilerSprite.pose_for("deal", rd) == "", "no reaction to a deal")
	# ---- sprite: hold and return, holds forever on the end poses, no buzz
	Haptics.log.clear()
	var sp := SpoilerSprite.new(CribData.BOSS_POOL[0])
	sp.size = Vector2(200, 200)
	root.add_child(sp)
	ok(sp._tex.texture != null and sp.art == String(CribData.BOSS_POOL[0].art), "texture for %s" % sp.art)
	sp.react("smug")
	for i in 60:
		sp.step(1.0 / 60.0)
	ok(sp.pose == "smug", "smug held for 1 s")
	for i in 40:
		sp.step(1.0 / 60.0)
	ok(sp.pose == "idle", "smug returns to idle: %s" % sp.pose)
	for p in ["defeated", "gloat"]:
		sp.react(p)
		for i in 600:
			sp.step(1.0 / 60.0)
		ok(sp.pose == p, "%s holds" % p)
	ok(Haptics.log.is_empty(), "the Spoiler buzzes on its own: %s" % [Haptics.log])
	for b in CribData.BOSS_POOL:
		sp.set_boss(b)
		ok(sp._tex.texture != null and sp.sev == int(b.sev), "set_boss %s" % b.id)
	sp.queue_free()
	# ---- presentation only
	var before := [JS.unseeded.s, rd.run.rng.s]
	var s2 := SpoilerSprite.new(CribData.BOSS_POOL[3])
	for e in ["count", "peg", "round_won", "run_lost"]:
		s2.on_event(e, rd, {"total": 99, "suppressed": 3})
	ok([JS.unseeded.s, rd.run.rng.s] == before, "a Spoiler reaction drew from an rng")
	s2.free()

	# ---- the real screens
	var f: RunFlow = load("res://scenes/run_flow.tscn").instantiate()
	root.add_child(f)
	await process_frame
	var br := CribRun.new("thump", Meta.STREETS[0], null, 9)
	br.round = CribData.ROUNDS
	var boss: Dictionary = br.boss()
	f.start_run(br)
	await process_frame
	ok(f.spoiler_view != null and f.spoiler_view.art == String(boss.art) and f.spoiler_view.pose == "smug", "boss intro shows %s, smug" % boss.name)
	var r := f.spoiler_view.get_global_rect()
	ok(r.size.x >= 150 and Rect2(Vector2.ZERO, Vector2(root.size)).encloses(r), "intro Spoiler on screen: %s" % r)
	f.queue_free()
	await process_frame
	# keep screen: shown on a Spoiler round, hidden otherwise
	for want in [true, false]:
		var k: KeepScreen = load("res://scenes/keep_screen.tscn").instantiate()
		k.in_run = true
		root.add_child(k)
		k.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var kr := CribRun.new("clover", Meta.STREETS[0], null, 31)
		if want:
			kr.round = CribData.ROUNDS
		k.start_round(kr)
		for i in 20:
			await process_frame
		ok(k.spoiler_sprite.visible == want, "keep screen Spoiler visible=%s on %s round" % [k.spoiler_sprite.visible, "a Spoiler" if want else "a plain"])
		if want:
			var a := k.spoiler_sprite.get_global_rect()
			var b2 := k.meld_sprite.get_global_rect()
			ok(not a.intersects(b2) and not a.intersects(k.hand.get_global_rect()), "keep: Spoiler clear of Meldling and hand")
			ok(k.spoiler_sprite.art == String(kr.boss().art), "keep: the round's Spoiler")
		k.queue_free()
		await process_frame
	# The Play: the character in place of the name
	var prd := _boss_round(5)
	prd.new_deal()
	var ses := PegSession.start(prd, prd.dealt.slice(0, 4))
	var pv := PegView.new()
	root.add_child(pv)
	pv.size = Vector2(720, 1560)       # a phone: the stage needs the height
	pv.open(ses)
	await process_frame
	ok(pv.spoiler_sprite != null and pv.spoiler_sprite.visible and pv.spoiler_sprite.art == String(prd.run.boss().art), "The Play shows the Spoiler")
	var named := false
	for l in pv.find_children("*", "Label", true, false):
		if (l as Label).text.contains(String(prd.run.boss().name).to_upper()):
			named = true
	ok(not named, "The Play still prints the Spoiler's name where the character stands")
	# its score sits below it, not under it
	var fr := pv.spoiler_sprite.get_global_rect()
	var covered := false
	for l in pv.find_children("*", "Label", true, false):
		var lab := l as Label
		if lab.text == str(ses.play.opp_score) and lab.get_global_rect().get_center().y < fr.end.y:
			covered = true
	ok(not covered, "the Spoiler covers its own score")
	pv.queue_free()

	print("spoiler checks: %d, failures: %d" % [checks, fails])
	var good := fails == 0 and checks >= 110
	print("SPOILER OK" if good else "SPOILER FAILED")
	quit(0 if good else 1)
