extends SceneTree
## The Play. Fixture group playui is the real JS running rounds the way the web
## UI does (afterCount, showPegging, pegLay, the payout, then next deal or
## round end).
## Part A replays it through PegSession on the engine.
## Part B plays the same rounds through KeepScreen and PegView with real
## clicks: keep, skip the count, The Play, lay cards (half the beats waited
## out, half tapped through), CONTINUE. Every deal and round must match the JS,
## and the page must fit at three phone shapes.
##   godot --headless --path godot --script res://tests/peg_test.gd
const SHAPES := [Vector2i(720, 1280), Vector2i(720, 1560), Vector2i(960, 1280)]
var checks := 0
var fails := 0
var clicks := 0
var deals_a := 0
var pegs_a := 0
var deals_b := 0
var pegs_b := 0
var waited := 0
var tapped := 0
var layouts := 0
var fx


func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		if fails <= 10:
			print("FAIL ", m)


func _initialize() -> void:
	_go.call_deferred()


func diff(a, b) -> String:
	return load("res://tests/parity_test.gd").diff(a, b)


func card_out(c) -> Dictionary:
	var o := {"rank": c.rank, "suit": c.suit}
	for k in ["enh", "rank2", "suit2"]:
		if c.has(k) and c[k] != null:
			o[k] = c[k]
	return o


## A fresh save with the case's systems and the run the JS built.
func make_run(cfg) -> CribRun:
	Achv.save_store({"__v": 3})
	for sy in cfg.systems:
		Achv.grant_system(sy)
	JS.unseeded = JsRng.new(fx.unseeded)
	var run := CribRun.new(cfg.meld, null, null, cfg.seed)
	for id in cfg.build:
		var ch: Charm = CribData.charm_by_id(id)
		run.charms.append(ch)
		if ch.on_acquire.is_valid():
			ch.on_acquire.call(run)
	run.act = cfg.act
	return run


## Policy, as the fixture: first playable on even deals, last on odd.
func pick(s: PegSession, deal_i: int) -> int:
	var okk := s.playable_indices()
	return okk[0] if deal_i % 2 == 0 else okk[okk.size() - 1]


func deal_record(rd: CribRound, s: PegSession, dealt: Array, keep: Array, res, lays: Array) -> Dictionary:
	var d := {"dealt": dealt.map(card_out), "keep": keep, "total": res.total, "pegged": s != null}
	if s != null:
		d.merge({"opp": s.opp.map(card_out), "lays": lays, "pegs": s.play.score, "oppPegs": s.play.opp_score,
			"net": s.net(), "gain": s.gain(),
			"log": s.play.log.map(func(l): return [l.who, l.label, l.points])})
	d.merge({"score": rd.score, "stock": rd.stock.size(), "dealsLeft": rd.deals_left})
	return d


func want_deal(D) -> Dictionary:
	var d := {"dealt": D.dealt, "keep": D.keep, "total": D.total, "pegged": D.pegged}
	if D.pegged:
		d.merge({"opp": D.opp, "lays": D.lays, "pegs": D.pegs, "oppPegs": D.oppPegs, "net": D.net,
			"gain": D.gain, "log": D.log})
	d.merge({"score": D.score, "stock": D.stock, "dealsLeft": D.dealsLeft})
	return d


# ------------------------------------------------------------------ Part A
func part_a() -> void:
	for ci in fx.playui.size():
		var cs = fx.playui[ci]
		var run := make_run(cs.cfg)
		for ri in cs.rounds.size():
			var R = cs.rounds[ri]
			var rd := CribRound.new(run)
			var di := 0
			while not rd.over and di < 30:
				if rd.new_deal() == null:
					break
				var idx: Array = rd.best_keep_ev().idx
				var kept: Array = idx.map(func(i): return rd.dealt[i])
				var dealt: Array = rd.dealt.duplicate()
				var res = rd.commit(idx)
				var s: PegSession = null
				var lays := []
				if PegSession.wanted(rd):
					s = PegSession.start(rd, kept)
					var g := 0
					while not s.play.over and g < 20:
						g += 1
						var k := pick(s, di)
						lays.append(card_out(s.play.mine[k]))
						s.lay(k)
						s.answer()
					s.apply()
					pegs_a += 1
				var got := deal_record(rd, s, dealt, idx, res, lays)
				if di < R.deals.size():
					var d := diff(want_deal(R.deals[di]), got)
					ok(d == "", "A case %d round %d deal %d: %s" % [ci, ri, di, d])
				else:
					ok(false, "A case %d round %d: extra deal %d" % [ci, ri, di])
				deals_a += 1
				di += 1
				if not (rd.deals_left > 0 and rd.score < rd.target):
					break
			ok(di == R.deals.size(), "A case %d round %d: %d deals, JS %d" % [ci, ri, di, R.deals.size()])
			rd.settle()
			var d2 := diff({"won": R.won, "score": R.score, "crib": R.crib, "earned": R.earned, "stock": R.stock},
				{"won": rd.won, "score": rd.score, "crib": rd.crib_result.total, "earned": rd.essence_earned, "stock": rd.stock.size()})
			ok(d2 == "", "A case %d round %d end: %s" % [ci, ri, d2])
			if not rd.won:
				break
			run.essence += rd.essence_earned
			if run.advance():
				break


# ------------------------------------------------------------------ Part B
func _wait(cond: Callable, frames := 3000) -> bool:
	for i in frames:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func _click(at: Vector2) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = at
		e.global_position = at
		Input.parse_input_event(e)
		Input.flush_buffered_events()
		await process_frame
	clicks += 1


func _center(c: Control) -> Vector2:
	return c.get_global_transform() * (c.size / 2.0)


func _press(c: Control) -> void:
	await _click(_center(c))


func vrect(c: Control) -> Rect2:
	var t := c.get_global_transform()
	return Rect2(t * Vector2.ZERO, c.size * t.get_scale())


## The Play's page: everything on screen, the hand below the call, the payout
## above CONTINUE, CONTINUE centred in the thumb zone.
func check_layout(pv: PegView, shape: Vector2i, where: String) -> void:
	layouts += 1
	var screen := Rect2(Vector2.ZERO, Vector2(shape))
	for v in pv.hand_views + pv.pile_views:
		ok(screen.encloses(vrect(v)), "%s: card off screen %s" % [where, vrect(v)])
	for l in [pv.head_label, pv.total_label, pv.call_label]:
		ok(screen.encloses(vrect(l)), "%s: label off screen" % where)
	var call_end := vrect(pv.call_label).end.y
	for v in pv.pile_views:
		ok(vrect(v).end.y <= vrect(pv.call_label).position.y + 0.5, "%s: pile runs into the call" % where)
	for v in pv.hand_views:
		ok(vrect(v).position.y >= call_end, "%s: hand overlaps the call (%.0f < %.0f)" % [where, vrect(v).position.y, call_end])
	if pv.hint_label != null:
		ok(screen.encloses(vrect(pv.hint_label)), "%s: hint off screen" % where)
	if pv.continue_button != null:
		var b := vrect(pv.continue_button)
		ok(screen.encloses(b), "%s: CONTINUE off screen %s" % [where, b])
		ok(absf(b.get_center().x - shape.x / 2.0) <= 1.0, "%s: CONTINUE off centre" % where)
		ok(b.position.y >= shape.y * 0.6, "%s: CONTINUE out of thumb reach (y %.0f)" % [where, b.position.y])
		for c in pv._page.get_children():
			if c is Panel:
				ok(vrect(c).end.y <= b.position.y, "%s: payout runs under CONTINUE" % where)


func part_b(cases: Array) -> void:
	for n in cases.size():
		var ci: int = cases[n]
		var cs = fx.playui[ci]
		var shape: Vector2i = SHAPES[n % SHAPES.size()]
		root.size = shape
		var run := make_run(cs.cfg)
		var k: KeepScreen = load("res://scenes/keep_screen.tscn").instantiate()
		k.in_run = true
		root.add_child(k)
		await process_frame
		for ri in cs.rounds.size():
			var R = cs.rounds[ri]
			var finished := [false]
			var on_fin := func(): finished[0] = true
			k.round_finished.connect(on_fin, CONNECT_ONE_SHOT)
			k.start_round(run)
			var rd: CribRound = k.rd
			for di in R.deals.size():
				var D = R.deals[di]
				var where := "B case %d round %d deal %d @%s" % [ci, ri, di, shape]
				await _wait(func(): return rd.phase == "keep" and not k.dealing)
				ok(diff(D.dealt, rd.dealt.map(card_out)) == "", "%s: dealt differs" % where)
				for i in D.keep:
					for v in k.hand._views.size():
						if int(k.hand._cards[v]._i) == i:
							await _press(k.hand._views[v])
				await _press(k.keep_button)
				for t in 2:
					if k.cutting or k.cascading:
						await _click(Vector2(shape.x / 2.0, shape.y * 0.45))
				await _wait(func(): return not k.cutting and not k.cascading)
				ok(k.peg_pending == D.pegged, "%s: Play owed %s, JS %s" % [where, k.peg_pending, D.pegged])
				var lays := []
				if k.peg_pending:
					ok(k.keep_button.text == "The Play", "%s: button says %s" % [where, k.keep_button.text])
					ok(not rd.over, "%s: settled before the Play" % where)
					await _press(k.keep_button)
					var pv: PegView = k.peg_view
					ok(pv != null, "%s: no Play screen" % where)
					if pv == null:
						break
					await process_frame
					var g := 0
					while not pv.s.play.over and g < 20:
						g += 1
						if g == 1:
							check_layout(pv, shape, where + " hand")
						var kk := pick(pv.s, di)
						lays.append(card_out(pv.s.play.mine[kk]))
						await _press(pv.hand_views[kk])
						ok(pv.waiting or pv.s.play.over, "%s: no beat after a lay" % where)
						if (g + di) % 2 == 0:
							await _click(Vector2(shape.x / 2.0, shape.y * 0.2))   # tap through the beat
							tapped += 1
						else:
							await _wait(func(): return not pv.waiting)
							waited += 1
						ok(not pv.waiting, "%s: still waiting on the Spoiler" % where)
					for w in 30:
						await process_frame    # let the newest card's pop settle
					check_layout(pv, shape, where + " payout")
					for v in pv.pile_views:
						ok(is_equal_approx(v.scale.x, 0.68), "%s: pile card left at scale %.2f" % [where, v.scale.x])
					var got := deal_record(rd, pv.s, D.dealt, D.keep, k.last_result, lays)
					got.score = rd.score + pv.s.gain()    # the JS records the score after CONTINUE
					ok(diff(want_deal(D), got) == "", "%s: %s" % [where, diff(want_deal(D), got)])
					await _press(pv.continue_button)
					ok(k.peg_view == null, "%s: Play screen still up" % where)
					# a finished round has also paid its Crib by now
					var crib: int = rd.crib_result.total if rd.over and rd.crib_result != null else 0
					ok(rd.score == D.score + crib, "%s: score %d after CONTINUE, JS %d + Crib %d" % [where, rd.score, D.score, crib])
					pegs_b += 1
				else:
					var crib2: int = rd.crib_result.total if rd.over and rd.crib_result != null else 0
					ok(rd.score == D.score + crib2, "%s: no-Play deal score %d, JS %d + Crib %d" % [where, rd.score, D.score, crib2])
					if not rd.over and di < R.deals.size() - 1:
						await _press(k.keep_button)    # Next deal
				deals_b += 1
			# round end
			if not finished[0] and rd.over:
				await _press(k.keep_button)   # Continue
			await _wait(func(): return finished[0])
			ok(finished[0], "B case %d round %d: round never handed back" % [ci, ri])
			rd.settle()
			var d2 := diff({"won": R.won, "score": R.score, "crib": R.crib, "earned": R.earned},
				{"won": rd.won, "score": rd.score, "crib": rd.crib_result.total, "earned": rd.essence_earned})
			ok(d2 == "", "B case %d round %d end: %s" % [ci, ri, d2])
			if not rd.won:
				break
			run.essence += rd.essence_earned
			if run.advance():
				break
		k.queue_free()
		await process_frame


func _go() -> void:
	var f := FileAccess.open("res://tests/fixtures/parity.json", FileAccess.READ)
	fx = load("res://tests/parity_test.gd").norm(JSON.parse_string(f.get_as_text()))
	Achv.persist = false
	var t0 := Time.get_ticks_msec()
	part_a()
	print("A: %d deals, %d Plays replayed through PegSession" % [deals_a, pegs_a])
	Engine.time_scale = 8.0
	var picks := []
	var env := OS.get_environment("PEG_CASES")
	if env != "":
		for x in env.split(","):
			picks.append(int(x))
	else:
		for i in range(0, fx.playui.size(), 3):
			picks.append(i)
	await part_b(picks)
	Engine.time_scale = 1.0
	print("B: %d deals, %d Plays by %d clicks (%d beats waited, %d tapped through), %d layouts" % [deals_b, pegs_b, clicks, waited, tapped, layouts])
	var good := fails == 0 and deals_a >= 150 and pegs_a >= 120 and pegs_b >= 30 and waited >= 10 and tapped >= 10 and layouts >= 60
	print("peg checks: %d, failures: %d, %d ms" % [checks, fails, Time.get_ticks_msec() - t0])
	print("PEG OK" if good else "PEG FAILED")
	quit(0 if good else 1)
