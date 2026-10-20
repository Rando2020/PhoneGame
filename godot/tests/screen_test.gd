extends SceneTree
## The keep screen must score exactly what the engine scores.
## Drives KeepScreen with real input events (clicks on cards and the button),
## then replays the same seed and keeps through CribRound directly.
##   godot --headless --path godot --script res://tests/screen_test.gd

const SEEDS := [20261001, 7, 99991, 424242]
## Base portrait, a tall phone (19.5:9) and a tablet-ish shape. With
## aspect="expand" each gives a different canvas, and the layout must follow.
const SIZES := [Vector2i(720, 1280), Vector2i(720, 1560), Vector2i(960, 1280)]
var layouts_checked := 0
var fails := 0
var deals_checked := 0


func _wait_until(cond: Callable, max_frames := 600) -> bool:
	for i in max_frames:
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


func _center(c: Control) -> Vector2:
	return c.get_global_rect().get_center()


func _view_for_dealt(screen: KeepScreen, i: int) -> CardView:
	for k in screen.hand._views.size():
		if int(screen.hand._cards[k]._i) == i:
			return screen.hand._views[k]
	return null


func _fail(msg: String) -> void:
	fails += 1
	print("FAIL ", msg)


func _initialize() -> void:
	Achv.starters = []        # this test drives the keep screen without The Play
	_run.call_deferred()


## Which half to run. The full suite took ~4.7 min, too close to the 5 min
## command limit, so it is split; each half demands only what its own cases
## produce, so neither can pass vacuously.
##   shapes: every seed at 3 phone shapes + the touch probe (layout, input, skip)
##   play:   marked/split deck, Foresight + recut, a charm build (mulligan, recut,
##           crib strip, charm lighting)
##   all:    both (slow; may exceed the limit)
var part := "all"


func _run() -> void:
	Achv.persist = false
	# Cascades are timer-driven; run the clock fast so many deals fit the budget.
	Engine.time_scale = 8.0
	# Headless windows are 64x64, which drops every click below y=64.
	if part in ["all", "shapes"]:
		for sz in SIZES:
			root.size = sz
			await process_frame
			# every seed at the base size; two per extra shape keeps the run short
			for seed in (SEEDS if sz == SIZES[0] else SEEDS.slice(0, 2)):
				await _check_seed(seed)
	root.size = SIZES[0]
	await process_frame
	if part in ["all", "play"]:
		# Marks and split cards through the whole screen path.
		for seed in [31, 32, 33]:
			await _check_seed(seed, true)
		# Foresight + Recut: the starter is known at the keep, so Recut appears.
		for seed in [41, 42, 43]:
			await _check_seed(seed, false, ["foresight", "recut", "steadyhand"])
		# a full charm bar, so the cascade has charms to light
		await _check_seed(51, false, ["keystone2", "ballast", "fifteener", "tallyman", "groundwork"])
	if part in ["all", "shapes"]:
		await _touch_probe()
	print("[%s] deals checked through the UI: %d, layouts checked: %d" % [part, deals_checked, layouts_checked])
	print("marked views seen: %d, split views seen: %d, cascades checked: %d, tap-skips: %d" % [marked_seen, split_seen, cascades_checked, taps_used])
	print("mulligans clicked: %d, recuts clicked: %d, charm-bar lightings checked: %d" % [mulls_used, recuts_used, charm_lights_checked])
	print("cut ceremonies checked: %d, skipped by tap: %d" % [cut_plans_checked, cut_taps])
	var ok := fails == 0 and deals_checked > 0 and cascades_checked >= deals_checked and cut_plans_checked > 0
	if part in ["all", "shapes"]:
		ok = ok and deals_checked >= SEEDS.size() + 2 * (SIZES.size() - 1) and layouts_checked >= SIZES.size() \
			and taps_used > 0 and probe_ran
	if part in ["all", "play"]:
		ok = ok and marked_seen > 0 and split_seen > 0 and mulls_used > 0 and recuts_used > 0 \
			and charm_lights_checked > 0
	print("SCREEN %s OK" % part.to_upper() if ok else "SCREEN %s FAILED" % part.to_upper())
	quit(0 if ok else 1)


## The run a screen and its replay both start from: optionally the special
## marked/split deck, plus any charms in `build`.
func _prepared_run(seed: int, special: bool, build: Array) -> CribRun:
	var r := _special_run(seed) if special else CribRun.new("pip", null, null, seed)
	for id in build:
		r.charms.append(CribData.charm_by_id(id))
	return r


## A deck where many cards carry marks or a split rank. Fickle included: since the
## marks fix it rolls from the run rng once per real count, so the screen and its
## replay must agree on it too.
func _special_run(seed: int) -> CribRun:
	var r := CribRun.new("pip", null, null, seed)
	var marks := ["gilded", "glass", "chameleon", "steel", "coin", "lucky"]
	for i in r.cards.size():
		var c: Dictionary = r.cards[i]
		if i % 3 == 0:
			c["enh"] = marks[(i / 3) % marks.size()]
		if i % 4 == 1:
			c["rank2"] = (c.rank % 13) + 1
			c["suit2"] = ["S", "H", "C", "D"][i % 4]
	return r


func _check_seed(seed: int, special := false, build: Array = []) -> void:
	Achv.save_store({"__v": 3})
	JS.unseeded = JsRng.new(1)
	var screen: KeepScreen = load("res://scenes/keep_screen.tscn").instantiate()
	screen.seed = seed
	var ready := [false]
	screen.dealt_ready.connect(func(): ready[0] = true)
	var got := [null]
	screen.counted.connect(func(r): got[0] = r)
	root.add_child(screen)

	# The replay: same seed, same keeps, engine only.
	Achv.save_store({"__v": 3})
	JS.unseeded = JsRng.new(1)
	var run2 := CribRun.new(screen.meldling, null, null, seed)
	if special or not build.is_empty():
		# wait out the screen's own first deal, then restart it on the prepared run
		await _wait_until(func(): return ready[0])
		ready[0] = false
		Achv.save_store({"__v": 3})
		JS.unseeded = JsRng.new(1)
		screen.start_round(_prepared_run(seed, special, build))
		run2 = _prepared_run(seed, special, build)
	var rd2 := CribRound.new(run2)

	var deal := 0
	while true:
		if not await _wait_until(func(): return ready[0]):
			_fail("seed %d deal %d: deal never became ready" % [seed, deal])
			break
		ready[0] = false
		_check_layout(screen, "seed %d deal %d" % [seed, deal])
		_check_views(screen, "seed %d deal %d" % [seed, deal])
		rd2.new_deal()
		if T_diff(rd2.dealt, screen.rd.dealt) != "":
			_fail("seed %d deal %d: dealt differs" % [seed, deal])
		_check_crib(screen, "seed %d deal %d" % [seed, deal])
		# Mulligan through a real click on the first deal of some rounds
		if deal == 0 and screen.mulligan_button.visible and (seed % 2 == 1 or not build.is_empty()):
			await _click(_center(screen.mulligan_button))
			if not await _wait_until(func(): return ready[0]):
				_fail("seed %d: mulligan never re-dealt" % seed)
				break
			ready[0] = false
			rd2.mulligan()
			mulls_used += 1
			if T_diff(rd2.dealt, screen.rd.dealt) != "" or rd2.crib.size() != screen.rd.crib.size():
				_fail("seed %d: after mulligan the deal or crib differs" % seed)
			_check_crib(screen, "seed %d after mulligan" % seed)
			_check_layout(screen, "seed %d after mulligan" % seed)
		# Recut through a real click whenever it's offered (Foresight builds)
		if screen.recut_button.visible:
			await _click(_center(screen.recut_button))
			await process_frame
			rd2.recut()
			recuts_used += 1
			if T_diff(rd2.starter, screen.rd.starter) != "" or screen.starter_view.rank != screen.rd.starter.rank:
				_fail("seed %d deal %d: recut starter differs (screen recuts_left %d, replay %d; screen starter %s, replay %s; button at %s)" % [seed, deal, screen.rd.recuts_left, rd2.recuts_left, screen.rd.starter, rd2.starter, screen.recut_button.get_global_rect()])
		var keep: Array = rd2.best_keep_ev().idx
		for i in keep:
			var v := _view_for_dealt(screen, i)
			await _click(_center(v))
			await _wait_until(func(): return not v.get_tree() or true, 2)
		if screen.selected_keep() != keep:
			_fail("seed %d deal %d: UI selected %s, wanted %s" % [seed, deal, screen.selected_keep(), keep])
			break
		if screen.keep_button.disabled:
			_fail("seed %d deal %d: Keep disabled with a full keep" % [seed, deal])
			break
		got[0] = null
		var knew2: bool = rd2.starter != null
		await _click(_center(screen.keep_button))
		# the cut ceremony: a tap anywhere must skip it at once
		if screen.cutting and deal % 3 == 0:
			await _click(_center(screen.cascade) + Vector2(0, 40))
			await process_frame
			cut_taps += 1
			if screen.cutting:
				_fail("seed %d deal %d: tap did not skip the cut ceremony" % [seed, deal])
		if not await _wait_until(func(): return got[0] != null):
			_fail("seed %d deal %d: no count after pressing Keep" % [seed, deal])
			break
		# rotate: tap anywhere to skip, the Skip button, or watch to the end
		var how: String = ["tap", "button", "full", "tapcard"][deal % 4]
		var skip_it := how != "full"
		if how == "tap":
			await _click(_center(screen.cascade) + Vector2(0, 40))   # mid-screen, away from the speed toggle
			taps_used += 1
		elif how == "tapcard":
			# a tap ON a counted card must skip too (cards are display only)
			await _wait_until(func(): return screen.counted_row._views.size() > 0, 60)
			await _click(_center(screen.counted_row._views[0]))
			taps_used += 1
		elif how == "button":
			await _click(_center(screen.keep_button))
		if skip_it:
			# a skip must land at once, not merely because the cascade ran out
			await process_frame
			if screen.cascading:
				_fail("seed %d deal %d: %s did not skip the cascade" % [seed, deal, how])
		if not await _wait_until(func(): return not screen.cascading, 3000):
			_fail("seed %d deal %d: cascade never finished" % [seed, deal])
			break
		_check_after_cascade(screen, got[0], "seed %d deal %d (%s)" % [seed, deal, how])
		var pre2: Array = rd2.stock.duplicate()
		var kept2: Array = keep.map(func(i): return rd2.dealt[i])
		var want = rd2.commit(keep)
		# the ceremony's plan must match the web's computation on the replay
		if knew2:
			if screen.last_cut_plan != null:
				_fail("seed %d deal %d: a ceremony ran with Foresight" % [seed, deal])
		else:
			var p2 := CutPlan.build(CutPlan.quality_like_web(rd2, kept2, pre2))
			var sp = screen.last_cut_plan
			if sp == null or sp.tier != p2.tier or sp.sub != p2.sub or sp.word != p2.word:
				_fail("seed %d deal %d: ceremony %s, replay %s" % [seed, deal, sp.tier if sp else null, p2.tier])
			cut_plans_checked += 1
		var d := T_diff(_summary(want, rd2), _summary(got[0], screen.rd))
		if d != "":
			_fail("seed %d deal %d: %s" % [seed, deal, d])
		deals_checked += 1
		_check_text_fits(screen, "seed %d deal %d" % [seed, deal])
		deal += 1
		# mirror the screen's round-end rule (the web's afterCount)
		if rd2.score >= rd2.target or rd2.deals_left <= 0:
			rd2.settle()
		if rd2.over:
			await _wait_until(func(): return not screen.cascading)
			var want_line := "%s  |  Crib +%d" % ["Round cleared" if rd2.won else "Round lost", rd2.crib_result.total]
			if not screen.status_label.text.ends_with(want_line):
				_fail("seed %d: status says %s, wanted ...%s" % [seed, screen.status_label.text.replace("\n", " / "), want_line])
			if screen.cascade.lines_box.get_child_count() > 2:
				_fail("seed %d: %d footer lines at round end" % [seed, screen.cascade.lines_box.get_child_count()])
			if screen.rd.score != rd2.score or screen.rd.won != rd2.won:
				_fail("seed %d: round end differs (%d/%s vs %d/%s)" % [seed, screen.rd.score, screen.rd.won, rd2.score, rd2.won])
			break
		await _click(_center(screen.keep_button))   # "Next deal"
	screen.queue_free()
	await process_frame


## Every view shows exactly its dealt card: rank, suit, mark, split rank.
var marked_seen := 0
var split_seen := 0
func _check_views(s: KeepScreen, where: String) -> void:
	for k in s.hand._views.size():
		var v: CardView = s.hand._views[k]
		var c: Dictionary = s.rd.dealt[int(s.hand._cards[k]._i)]
		var want := [c.rank, c.suit, c.get("enh", ""), c.get("rank2", 0)]
		var got := [v.rank, v.suit, v.enh, v.rank2]
		if want != got:
			_fail("%s: view shows %s, card is %s" % [where, got, want])
		if v.enh != "" and v.rank2 == 0:
			marked_seen += 1
			if not v._mark.visible:
				_fail("%s: marked card without overlay" % where)
		if v.enh != "" and v.rank2 != 0 and v._mark.visible:
			_fail("%s: split card drew its mark (should match the web)" % where)
		if v.rank2 != 0:
			split_seen += 1
			if not v._split.visible:
				_fail("%s: split card drawn plain" % where)


## Everything on screen, stacked top to bottom with no overlap, hand above button.
func _check_layout(s: KeepScreen, where: String) -> void:
	layouts_checked += 1
	var vis := s.get_global_rect()
	var tag := "%s @%s" % [where, str(root.size)]
	var stack := [["status", s.status_label], ["charms", s.charm_bar], ["starter", s.starter_view], ["cascade", s.cascade],
		["hand", s.hand], ["button", s.keep_button]]
	var prev_bottom := vis.position.y
	for e in stack:
		var r: Rect2 = e[1].get_global_rect()
		if not vis.encloses(r.grow(-0.5)):
			_fail("%s: %s %s outside visible %s" % [tag, e[0], r, vis])
		if r.position.y < prev_bottom - 0.5:
			_fail("%s: %s overlaps the element above (top %.0f < %.0f)" % [tag, e[0], r.position.y, prev_bottom])
		prev_bottom = r.end.y
	var gap: float = s.keep_button.get_global_rect().position.y - s.hand.get_global_rect().end.y
	if gap < 0 or gap > 60:
		_fail("%s: hand is %.0f px above the button, expected 0-60" % [tag, gap])
	# anchored to the thumb zone: button near the bottom edge, not floating
	var below: float = vis.end.y - s.keep_button.get_global_rect().end.y
	if below > 120:
		_fail("%s: %.0f px of dead space below the button" % [tag, below])
	# centred, not pinned to the left of a wide canvas
	var cx := vis.get_center().x
	for e in [["hand", s.hand], ["button", s.keep_button], ["starter", s.starter_view]]:
		var off: float = absf(e[1].get_global_rect().get_center().x - cx)
		if off > 2.0:
			_fail("%s: %s is %.0f px off centre" % [tag, e[0], off])
	# side controls: on screen and clear of what they sit beside
	var side := [["crib", s.crib_strip, s.starter_view], ["recut", s.recut_button, s.starter_view],
		["mulligan", s.mulligan_button, s.keep_button]]
	for e in side:
		if not e[1].visible:
			continue
		var r: Rect2 = e[1].get_global_rect()
		if not vis.encloses(r.grow(-0.5)):
			_fail("%s: %s %s outside visible %s" % [tag, e[0], r, vis])
		if r.intersects(e[2].get_global_rect().grow(-1.0)):
			_fail("%s: %s overlaps its neighbour" % [tag, e[0]])
	if s.crib_strip.visible:
		for v in s.crib_strip.views:
			if not vis.encloses(v.get_global_rect().grow(-0.5)):
				_fail("%s: a crib card is off screen at %s" % [tag, v.get_global_rect()])
	# every card fully on screen
	for v in s.hand._views:
		if not vis.encloses(v.get_global_rect().grow(-0.5)):
			_fail("%s: a card is off screen at %s" % [tag, v.get_global_rect()])


## The cascade's rows and footer lines must fit their boxes.
func _check_text_fits(s: KeepScreen, where: String) -> void:
	var c := s.cascade
	if c.list.get_child_count() * CascadeView.ROW_H > c.list_h + 0.5:
		_fail("%s @%s: %d cascade rows overflow %.0f px" % [where, str(root.size), c.list.get_child_count(), c.list_h])
	var need := 0.0
	for l in c.lines_box.get_children():
		need += l.get_combined_minimum_size().y
	if need > c.lines_box.size.y + 1.0:
		_fail("%s @%s: footer lines need %.0f px, box is %.0f" % [where, str(root.size), need, c.lines_box.size.y])


## The crib strip shows exactly the round's crib.
func _check_crib(s: KeepScreen, where: String) -> void:
	var shown: Array = s.crib_strip.views.map(func(v): return [v.rank, v.suit])
	var want: Array = s.rd.crib.map(func(c): return [c.rank, c.suit])
	if shown != want:
		_fail("%s: crib strip %s, crib is %s" % [where, shown, want])
	if not s.crib_strip.title.text.begins_with("CRIB  %d/" % s.rd.crib.size()):
		_fail("%s: crib title %s" % [where, s.crib_strip.title.text])


## After the cascade: right number, the counted cards out of the hand and in the row.
var cascades_checked := 0
var taps_used := 0
var mulls_used := 0
var recuts_used := 0
var charm_lights_checked := 0
var cut_plans_checked := 0
var cut_taps := 0
var probe_ran := false
func _check_after_cascade(s: KeepScreen, res: Dictionary, where: String) -> void:
	cascades_checked += 1
	if s.cascade.shown != res.total or s.cascade.number.text != str(res.total):
		_fail("%s: cascade shows %s, total %d" % [where, s.cascade.number.text, res.total])
	if s.hand.card_count() != 0:
		_fail("%s: %d cards still in the hand" % [where, s.hand.card_count()])
	# the charm bar lights exactly the charms that fired (skipped or watched)
	var lit: Array = s.charm_bar.lit.keys()
	lit.sort()
	var fired: Array = []
	for n in res.fired:
		if not fired.has(n):
			fired.append(n)
	fired.sort()
	if lit != fired:
		_fail("%s: charm bar lit %s, fired %s" % [where, lit, fired])
	if not fired.is_empty():
		charm_lights_checked += 1
	var row := s.counted_row._views.map(func(v): return [v.rank, v.suit])
	var want: Array = res.all.map(func(c): return [c.rank, c.suit])
	if row != want:
		_fail("%s: counted row %s, engine counted %s" % [where, row, want])


func _summary(res: Dictionary, rd: CribRound) -> Dictionary:
	# The deal's own numbers. rd.score is not used here: the screen may already
	# have cashed out (adding the crib) before this is read. Round-end scores are
	# compared separately, after both sides settle.
	return {"total": res.total, "base": res.base, "mult": res.mult,
		"labels": res.events.map(func(e): return e.label), "fired": res.fired,
		"starter": [rd.starter.rank, rd.starter.suit], "scoreAfter": res.scoreBefore + res.total}


func T_diff(a, b) -> String:
	return load("res://tests/parity_test.gd").diff(a, b)


## Does one tap fire `pressed` once? Godot emulates mouse from touch by default.
func _touch_probe() -> void:
	var screen: KeepScreen = load("res://scenes/keep_screen.tscn").instantiate()
	var ready := [false]
	screen.dealt_ready.connect(func(): ready[0] = true)
	root.add_child(screen)
	await _wait_until(func(): return ready[0])
	var v: CardView = screen.hand._views[0]
	var n := [0]
	v.pressed.connect(func(_x): n[0] += 1)
	for pressed in [true, false]:
		var t := InputEventScreenTouch.new()
		t.index = 0
		t.pressed = pressed
		t.position = _center(v)
		Input.parse_input_event(t)
		Input.flush_buffered_events()
		await process_frame
	await process_frame
	print("touch probe: one tap fired `pressed` %d time(s); selected now %d" % [n[0], screen.hand._selected.size()])
	probe_ran = true
	if n[0] != 1:
		_fail("one tap fired pressed %d times" % n[0])
	screen.queue_free()
	await process_frame
