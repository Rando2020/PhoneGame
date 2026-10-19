extends SceneTree
## Audio. Every id the game plays exists as a rendered sample; every event plays
## its sound in the same frame (the same call) as its haptic; nothing plays when
## muted, and mute and volume are saved; the voice pool never grows past POOL;
## the cascade's ticks climb in pitch; the cut ceremony rolls and lands per tier;
## the music context follows the screen, as the web picks it; backgrounding
## pauses every player.
##   godot --headless --path godot --script res://tests/sound_test.gd
var checks := 0
var fails := 0


func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("FAIL ", m)


func _initialize() -> void:
	_go.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## The last sound played, and whether it was this frame.
func _last() -> Array:
	return Sound.log.back() if not Sound.log.is_empty() else ["", -1, 0.0]


func _now() -> int:
	return Engine.get_process_frames()


func _go() -> void:
	Achv.persist = false
	Achv.save_store({"__v": 3})
	root.size = Vector2i(720, 1560)
	Sound.reset()
	# ---- every id the game asks for exists
	var ids := ["click", "deal", "toCrib", "select", "deselect", "buy", "milestone", "level", "cut",
		"win", "lose", "bad", "slam_1", "slam_2", "slam_3", "boss_intro", "ramp_burst", "cut_roll",
		"spoiler_peg", "line_gild", "line_cut", "line_level", "crib_tick", "deed", "guide", "charm_fire", "flip"]
	for k in ["fifteen", "pair", "run", "flush", "nobs", "charm"]:
		ids.append("tick_" + k)
	for t in CascadePlan.TIERS:
		ids.append("chord_" + (String(t.cls) if t.cls != "" else "t-none"))
	for t in CutPlan.TIERS:
		ids.append("cut_" + String(t))
	for v in MeldReact.SOUND.values() + SpoilerSprite.SOUND.values() + CascadeView.LINE_SOUND.values():
		ids.append(v)
	for id in ids:
		ok(Sound.exists(id), "no sample for '%s'" % id)
	for ctx in Sound.MUSIC:
		var p := "res://audio/music/%s.ogg" % ctx
		ok(ResourceLoader.exists(p), "no music loop for %s" % ctx)
	await _frames(2)          # the player node joins the tree

	# ---- reactions: sound and haptic in the same call (the same frame)
	var sp := MeldSprite.new("thump")
	root.add_child(sp)
	for p in MeldReact.SOUND.keys():
		Haptics.log.clear()
		var f := _now()
		sp.react(p)
		var l := _last()
		ok(l[0] == MeldReact.SOUND[p] and l[1] == f, "%s plays %s this frame (got %s)" % [p, MeldReact.SOUND[p], l])
		if int(MeldReact.BUZZ.get(p, 0)) > 0:
			ok(Haptics.log.size() == 1 and l[1] == f, "%s buzzes in the same frame as its sound" % p)
	var n0 := Sound.log.size()
	sp.react("cheer", true)
	ok(Sound.log.size() == n0, "a quiet reaction stays quiet")
	var ssp := SpoilerSprite.new(CribData.BOSS_POOL[0])
	root.add_child(ssp)
	ssp.react("smug")
	ok(_last()[0] == "spoiler_peg", "the Spoiler's smirk is its voice")
	n0 = Sound.log.size()
	ssp.react("defeated")
	ssp.react("gloat")
	ok(Sound.log.size() == n0, "the Spoiler's end poses stay silent (your win / lose plays)")

	# ---- mute and volume: saved, and nothing plays
	Sound.set_muted(true)
	ok(JS.truthy(Achv.load_store().get("sound_muted")), "mute saved")
	n0 = Sound.log.size()
	ok(not Sound.play("click"), "muted: play refuses")
	sp.react("victory")
	ok(Sound.log.size() == n0, "muted: a reaction makes no sound")
	Sound.set_muted(false)
	Sound.set_volume(0.0)
	ok(not Sound.play("click") and absf(float(Achv.load_store().get("sound_volume")) - 0.0) < 0.001, "volume 0 saved and silent")
	Sound.set_volume(0.7)
	ok(Sound.play("click") and absf(Sound.volume() - 0.7) < 0.001, "volume restored")

	# ---- the pool never grows
	var node := Sound.node()
	for i in 40:
		Sound.play("tick_run", 1.0 + i * 0.01)
	ok(node._voices.size() == Sound.POOL and node.voices_busy() <= Sound.POOL, "40 at once: %d voices, %d busy" % [node._voices.size(), node.voices_busy()])
	await _frames(2)

	# ---- press: a click on touch-down
	var b := Button.new()
	root.add_child(b)
	Press.wire(b)
	var f2 := _now()
	b.button_down.emit()
	ok(_last()[0] == "click" and _last()[1] == f2, "touch-down clicks")
	b.queue_free()

	# ---- the cascade: ticks climb, the slam and its chord land
	var cv := CascadeView.new()
	root.add_child(cv)
	await process_frame
	cv._tick_i = 0
	var pitches := []
	for k in ["fifteen", "fifteen", "pair", "run"]:
		cv._begin_beat({"kind": k, "label": k, "value": "+2", "number": 2, "cards": [], "mult_line": "", "ms": 300})
		ok(String(_last()[0]) == "tick_" + k, "a %s line ticks tick_%s" % [k, k])
		pitches.append(float(_last()[2]))
	ok(pitches[0] < pitches[1] and pitches[1] < pitches[2] and pitches[2] < pitches[3], "ticks climb: %s" % [pitches])
	cv._begin_beat({"kind": "gild", "label": "", "value": "", "number": 2, "cards": [], "mult_line": "", "ms": 300})
	ok(_last()[0] == "line_gild", "the gild line has its note")
	cv.plan = {"beats": [{"kind": "slam", "label": "", "value": "", "number": 40, "cards": [], "mult_line": "x2", "ms": 620}],
		"final": 40, "tier": CascadePlan.TIERS[4], "ratio": 3.4, "fired": []}
	var s0 := Sound.log.size()
	cv._slam()
	var slam_ids := Sound.log.slice(s0).map(func(e): return e[0])
	ok(slam_ids == ["ramp_burst", "slam_3", "chord_t-max"], "a massive slam: %s" % [slam_ids])
	cv.queue_free()

	# ---- the cut ceremony: strikes climb, the landing per tier
	var cut := CutView.new()
	root.add_child(cut)
	await process_frame
	cut.plan = {"tier": "great", "roll": 1.0}
	cut._strikes = -1
	s0 = Sound.log.size()
	for prog in [0.0, 0.1, 0.3, 0.6, 0.99]:      # each crosses a 90 ms step
		cut._wobble(prog)
	var rolls := Sound.log.slice(s0)
	ok(rolls.size() == 5 and rolls.all(func(e): return e[0] == "cut_roll"), "five strikes: %s" % [rolls.size()])
	ok(rolls.size() == 5 and float(rolls[4][2]) > float(rolls[0][2]), "strikes climb in pitch")
	cut._wobble(0.991)
	ok(Sound.log.size() == s0 + 5, "no strike between 90 ms steps")
	cut.queue_free()

	# ---- music follows the screen
	var flow: RunFlow = load("res://scenes/run_flow.tscn").instantiate()
	root.add_child(flow)
	await _frames(2)
	ok(Sound.music_ctx == "menu", "title: menu (%s)" % Sound.music_ctx)
	flow.start_run(CribRun.new("pip", Meta.STREETS[0], null, 3))
	await process_frame
	ok(Sound.music_ctx == "act1", "act 1 intro: act1 (%s)" % Sound.music_ctx)
	var r3 := CribRun.new("pip", Meta.STREETS[0], null, 3)
	r3.act = 3
	flow.start_run(r3)
	ok(Sound.music_ctx == "act3", "act 3: act3 (%s)" % Sound.music_ctx)
	var rb := CribRun.new("pip", Meta.STREETS[0], null, 3)
	rb.round = CribData.ROUNDS
	flow.start_run(rb)
	ok(Sound.music_ctx == "boss", "a Spoiler round: boss (%s)" % Sound.music_ctx)
	ok(Sound.log.any(func(e): return e[0] == "boss_intro"), "the boss intro sounds")
	var re := CribRun.new("pip", Meta.STREETS[0], null, 3)
	re.enter_endless()
	re.endless_round = 0
	flow.start_run(re)
	ok(Sound.music_ctx == "endless", "the Long Count: endless (%s)" % Sound.music_ctx)
	ok(RunFlow.music_for(CribRun.new("pip")) == "act1", "music_for act 1")
	var r9 := CribRun.new("pip")
	r9.act = 7
	ok(RunFlow.music_for(r9) == "act5", "beyond act 5: act5")
	flow.run.essence = 999
	flow.show_shop()
	ok(Sound.music_ctx == "shop", "shop: shop (%s)" % Sound.music_ctx)
	# shop purchases: buy, and a legendary's fanfare with its buzz in the same frame
	var common: Charm = null
	var legend: Charm = null
	for c in CribData.CHARMS:
		if c.rarity == "common" and common == null:
			common = c
		if c.rarity == "legendary" and legend == null:
			legend = c
	flow.shop.buy_charm(common)
	ok(_last()[0] == "buy", "a common: buy")
	Haptics.log.clear()
	var f3 := _now()
	flow.shop.buy_charm(legend)
	ok(_last()[0] == "milestone" and _last()[1] == f3 and Haptics.log == [50], "a legendary: fanfare and buzz together")
	flow.show_front_door("title")
	ok(Sound.music_ctx == "menu", "back to the title: menu")
	flow.queue_free()
	await process_frame
	# The Play: its loop, a lay, and 31's slam with its buzz
	var prd := CribRound.new(CribRun.new("pip", null, null, 5))
	prd.new_deal()
	var ses := PegSession.start(prd, prd.dealt.slice(0, 4))
	var pv := PegView.new()
	root.add_child(pv)
	pv.open(ses)
	await process_frame
	ok(Sound.music_ctx == "play", "The Play: play (%s)" % Sound.music_ctx)
	ses.play.total = 31
	ses.play.last_lay = {"who": "you", "events": [], "hit31": true}
	Haptics.log.clear()
	var f4 := _now()
	pv.juice_lay()
	ok(_last()[0] == "slam_1" and _last()[1] == f4 and Haptics.log == [40], "31: slam and buzz together")
	pv.queue_free()

	# ---- backgrounded: everything pauses, and resumes
	Sound.play("win")
	await process_frame
	var live := []
	for p in node._voices + node._music:
		if p.has_stream_playback():
			live.append(p)
	ok(live.size() >= 2, "something is playing to pause (%d)" % live.size())
	node._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	var all_paused := true
	for p in live:
		all_paused = all_paused and p.stream_paused
	ok(node.paused and all_paused, "backgrounded: everything playing is paused")
	node._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	var any_paused := false
	for p in live:
		any_paused = any_paused or p.stream_paused
	ok(not node.paused and not any_paused, "back: playing")

	print("sound checks: %d, failures: %d" % [checks, fails])
	var good := fails == 0 and checks >= 90
	print("SOUND OK" if good else "SOUND FAILED")
	quit(0 if good else 1)
