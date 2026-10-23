extends SceneTree
## Pass 22: the playtest build. Nothing here changes play.
##  - off in release: without the "playtest" feature, the version label's taps
##    open nothing, the page refuses, nothing is logged; the iOS preset has no
##    "playtest" feature; the desktop presets do, and leave the tests out
##  - the menu: 5 taps within 2.5 s open it (4, or 5 spread out, don't)
##  - the jumps build real states: a round-2 Shortage intro, a full bar with an
##    upgrade mark, Gallery reveals, a lost run's end with Share
##  - the log: one line a round from RunFlow's own hooks, with the round's kind,
##    its category mix (the run's tally across the round), seconds, mulligans
##    and whether it cleared; the switch turns it off; the summary's numbers
##  - haptics: a light tap when a bought charm lands, a heavier one on the stamp
##   godot --headless --path godot --script res://tests/pass22_test.gd
var checks := 0
var fails := 0


func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		if fails <= 30:
			print("FAIL ", m)


func _initialize() -> void:
	_go.call_deferred()


func _log_lines() -> int:
	return Playtest.entries().size()


func _go() -> void:
	Achv.persist = false
	Achv.save_store({"__v": 3, "guided": 1})
	root.size = Vector2i(720, 1560)
	var keep_log = FileAccess.get_file_as_string(Playtest.LOG_PATH) if FileAccess.file_exists(Playtest.LOG_PATH) else null
	Playtest.clear_log()

	# ---- presets
	var cfg := ConfigFile.new()
	ok(cfg.load("res://export_presets.cfg") == OK, "export_presets.cfg didn't load")
	var seen := {}
	for sec in cfg.get_sections():
		if not sec.begins_with("preset.") or sec.ends_with(".options"):
			continue
		var name := String(cfg.get_value(sec, "name"))
		var feats := String(cfg.get_value(sec, "custom_features", ""))
		seen[name] = feats
		if name == "iOS":
			ok(not feats.contains("playtest"), "the iOS release preset carries the playtest feature")
		elif name.begins_with("Playtest"):
			ok(feats.contains("playtest") and String(cfg.get_value(sec, "exclude_filter", "")).contains("tests/*"), "%s: features '%s'" % [name, feats])
	ok(seen.has("iOS") and seen.has("Playtest Linux") and seen.has("Playtest Windows") and seen.has("Playtest macOS"), "presets: %s" % [seen.keys()])

	# ---- off in release (this binary has no "playtest" feature)
	Playtest.forced = null
	ok(not Playtest.enabled() and not OS.has_feature("playtest"), "playtest on without the feature")
	var f: RunFlow = load("res://scenes/run_flow.tscn").instantiate()
	root.add_child(f)
	await process_frame
	f.show_front_door("title")
	f.settle()
	var opened := false
	for i in 6:
		opened = f.front.version_tap(1000 + i * 100) or opened
	ok(not opened and f.front.cb.step == "title", "release: 6 taps opened the menu")
	f.front.go("playtest")
	f.settle()
	ok(f.front.cb.step == "title", "release: the playtest page didn't refuse (%s)" % f.front.cb.step)
	ok(not f.playtest_jump("shortage"), "release: a jump ran")
	var r0 := CribRun.new("pip", Meta.STREETS[0], null, 7)
	Playtest.round_start(r0, 0)
	ok(Playtest.round_end(r0, CribRound.new(r0), 1000).is_empty() and _log_lines() == 0, "release: a round was logged")
	var ver: Label = f.front._page.find_child("version", true, false)
	ok(ver != null and ver.text == "v2.0.0", "no version label on the title")

	# ---- the menu in a playtest build
	Playtest.forced = true
	f.show_front_door("title")
	f.settle()
	f.front.version_taps.clear()
	for i in 4:
		f.front.version_tap(5000 + i * 200)
	ok(f.front.cb.step == "title", "4 taps opened the menu")
	f.front.version_taps.clear()
	for i in 5:
		f.front.version_tap(9000 + i * 900)
	ok(f.front.cb.step == "title", "5 slow taps opened the menu")
	f.front.version_taps.clear()
	var got := false
	for i in 5:
		got = f.front.version_tap(20000 + i * 200) or got
	ok(got and f.front.cb.step == "playtest", "5 quick taps didn't open the menu (%s)" % f.front.cb.step)
	f.settle()
	for k in ["pt_shortage", "pt_upgrade", "pt_gallery", "pt_run_end", "pt_log", "pt_clear"]:
		ok(f.front.buttons.has(k), "playtest page: no %s" % k)

	# ---- the jumps
	ok(f.playtest_jump("shortage"), "jump: shortage")
	ok(f.screen == "intro" and f.run.round == 2 and f.run.shortage() != null and f.short_line != null, "jump: not a round-2 Shortage intro (%s, round %d)" % [f.screen, f.run.round])
	ok(f.run.cat_points.values().any(func(v): return v > 0), "jump: round 1 wasn't played (empty tally)")
	ok(f.playtest_jump("upgrade"), "jump: upgrade")
	await process_frame
	f.shop.finish()
	ok(f.screen == "shop" and f.run.is_full() and f.shop.upgrade != null and f.shop.upgrade_label != null, "jump: no full bar with an upgrade mark")
	ok(not f.run.count_log.is_empty(), "jump: the upgrade mark isn't from played counts")
	Achv.save_store({"__v": 3, "guided": 1, "charms_shown": {}})
	ok(f.playtest_jump("gallery"), "jump: gallery")
	f.settle()
	for i in 20:
		await process_frame
	var rev: Array = Menus.revealed.duplicate()
	rev.sort()
	ok(f.front.cb.step == "gallery" and Menus.gal_tab == "charms" and rev == ["fever", "fifteener", "keystone2", "peacock"], "jump: Gallery reveals %s" % [rev])
	ok(f.playtest_jump("run_end"), "jump: run_end")
	ok(f.screen == "round_end" and not f.rd.won and f.buttons.has("share"), "jump: not a lost run's end with Share (%s)" % f.screen)
	ok(not f.playtest_jump("nope"), "an unknown jump ran")

	# ---- the log, from RunFlow's own hooks
	Playtest.clear_log()
	Achv.save_store({"__v": 3, "guided": 1})
	var lr := CribRun.new("thump", Meta.STREETS[0], null, 8801)
	lr.wager_at = {}
	lr.cat_points = {"fifteen": 4, "pair": 9, "run": 0, "flush": 0}
	lr.round = 2                      # a Shortage round (pairs)
	f.start_run(lr)
	f._on_deal()                      # RunFlow's round start
	ok(not Playtest._start.is_empty() and Playtest._start.kind == "shortage:pair", "round start: %s" % [Playtest._start])
	var tally0: Dictionary = lr.cat_points.duplicate()
	var d := CribRound.new(lr)
	var mull0 := d.mulligans_left
	if d.new_deal() != null and d.mulligans_left > 0:
		d.mulligan()
	while d.dealt.size() > 0 and d.phase == "keep":
		d.commit(d.best_keep_ev().idx)
		if d.score >= d.target or d.deals_left <= 0 or d.new_deal() == null:
			break
	f.rd = d
	f._round_end_effects()            # RunFlow's round end: one line
	var es := Playtest.entries()
	ok(es.size() == 1, "log lines: %d" % es.size())
	if es.size() == 1:
		var e: Dictionary = es[0]
		var want_mix := {}
		for k in Playtest.CATS:
			want_mix[k] = float(lr.cat_points[k]) - float(tally0[k])
		ok(e.kind == "shortage:pair" and int(e.act) == 1 and int(e.round) == 2, "log kind/act/round: %s" % [e])
		ok(e.mix == want_mix, "log mix %s vs %s" % [e.mix, want_mix])
		ok(int(e.mulligans) == d.start_mulligans - d.mulligans_left and int(e.mulligans) >= 1, "log mulligans %s" % e.mulligans)
		ok(bool(e.cleared) == d.won and float(e.secs) >= 0.0, "log cleared/secs %s" % [e])
		ok(String(e.session) == Playtest._session(), "log session")
	# a lost round logs cleared: false, with injected times
	var lost := CribRun.new("pip", Meta.STREETS[0], null, 8803)
	Playtest.round_start(lost, 1000)
	var lrd := CribRound.new(lost)
	lrd.won = false
	var le := Playtest.round_end(lost, lrd, 4500)
	ok(le.get("cleared") == false and le.get("secs") == 3.5, "lost round entry %s" % [le])
	Playtest.clear_log()
	Playtest.round_start(lr, 0)
	Playtest.round_end(lr, d, 10)
	# the switch
	Playtest.set_log(false)
	f.start_run(CribRun.new("pip", Meta.STREETS[0], null, 8802))
	f._on_deal()
	f.rd = CribRound.new(f.run)
	f._round_end_effects()
	ok(_log_lines() == 1 and not Playtest.log_on(), "log off still logged (%d lines)" % _log_lines())
	Playtest.set_log(true)

	# ---- the summary's numbers
	var S := "s1"
	var syn := [
		{"session": S, "act": 1, "round": 1, "kind": "twist:pairs4", "mix": {"fifteen": 8, "pair": 2, "run": 0, "flush": 0}, "secs": 40.0, "mulligans": 1, "cleared": true},
		{"session": S, "act": 1, "round": 2, "kind": "shortage:fifteen", "mix": {"fifteen": 2, "pair": 6, "run": 0, "flush": 0}, "secs": 60.0, "mulligans": 0, "cleared": true},
		{"session": S, "act": 1, "round": 3, "kind": "spoiler", "mix": {"fifteen": 9, "pair": 0, "run": 0, "flush": 0}, "secs": 50.0, "mulligans": 2, "cleared": true},
		{"session": S, "act": 2, "round": 1, "kind": "twist:flush3", "mix": {"fifteen": 3, "pair": 6, "run": 0, "flush": 1}, "secs": 30.0, "mulligans": 0, "cleared": true},
		{"session": S, "act": 2, "round": 2, "kind": "shortage:pair", "mix": {"fifteen": 7, "pair": 1, "run": 0, "flush": 0}, "secs": 20.0, "mulligans": 1, "cleared": false},
		{"session": S, "act": 1, "round": 1, "kind": "plain", "mix": {"fifteen": 0, "pair": 0, "run": 5, "flush": 0}, "secs": 10.0, "mulligans": 0, "cleared": false},
	]
	var s := Playtest.summary(syn)
	ok(s.rounds == 6 and s.cleared_pct == 66.7 and s.avg_secs == 35.0 and s.mulligans_per_round == 0.67, "summary totals %s" % [s])
	ok(s.by_kind.shortage.rounds == 2 and s.by_kind.shortage.cleared_pct == 50.0 and s.by_kind.shortage.avg_secs == 40.0, "summary shortage %s" % [s.by_kind.get("shortage")])
	ok(s.by_kind.twist.rounds == 2 and s.by_kind.spoiler.rounds == 1 and s.by_kind.plain.rounds == 1, "summary kinds %s" % [s.by_kind.keys()])
	# non-Spoiler moves within a run: 1-1 -> 1-2 (fifteen -> pair: change), 1-2 -> 2-1 (pair -> pair: same),
	# 2-1 -> 2-2 (pair -> fifteen: change); 2-2 -> 1-1 starts a new run (not counted)
	ok(s.transitions == 3 and s.lead_changes_pct == 66.7, "summary lead changes %s of %s" % [s.lead_changes_pct, s.transitions])
	ok(Playtest.summary([]).rounds == 0, "an empty summary")
	# a new run that starts on the same act and round as the last entry is not a move
	var again := Playtest.summary([syn[0], syn[0].duplicate()])
	ok(again.transitions == 0, "a repeated 1-1 counted as a move (%d)" % again.transitions)

	# ---- haptics
	Haptics.log.clear()
	Achv.save_store({"__v": 3, "guided": 1})
	var hr := CribRun.new("thump", Meta.STREETS[0], null, 2101)
	hr.essence = 90
	hr.open_shop()
	hr.shop_state.offer = ["fifteener", "fever", "peacock"].map(func(i): return CribData.charm_by_id(i))
	var sh: ShopScreen = load("res://scenes/shop_screen.tscn").instantiate()
	root.add_child(sh)
	sh.size = Vector2(720, 1560)
	sh.open(hr)
	sh.finish()
	await process_frame
	sh.buy_charm(CribData.charm_by_id("fever"))
	for i in 60:
		await process_frame
	ok(Haptics.log.has(ShopScreen.LAND_HAPTIC), "no landing tap: %s" % [Haptics.log])
	sh.queue_free()
	Haptics.log.clear()
	var st := CribRun.new("pip", Meta.STREETS[0], null, 2103)
	st.wager_at = {}
	st.cat_points = {"fifteen": 2, "pair": 12, "run": 1, "flush": 0}
	st.round = 2
	f._no_slide = false
	f.start_run(st)
	ok(Haptics.log.has(RunFlow.STAMP_HAPTIC), "no stamp buzz: %s" % [Haptics.log])
	ok(RunFlow.STAMP_HAPTIC > ShopScreen.LAND_HAPTIC, "the stamp should buzz heavier than a landing")

	f.queue_free()
	await process_frame
	Playtest.forced = null
	Playtest.clear_log()
	if keep_log != null:
		var w := FileAccess.open(Playtest.LOG_PATH, FileAccess.WRITE)
		w.store_string(keep_log)
		w.close()
	print("pass22_test: %d checks, %d fails" % [checks, fails])
	quit(1 if fails > 0 else 0)
