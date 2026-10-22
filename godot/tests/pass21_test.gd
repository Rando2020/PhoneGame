extends SceneTree
## Pass 21: building and collecting in motion. One property for every animation:
## drawn with motion OFF (the static draw), drawn with motion ON and finished at
## once by skip() (a tap), and drawn with motion ON and left to run, the three
## snapshots are identical. And each one really moves (a mid-flight check), and
## Reduce Motion takes its fade path. Screens: the shop purchase (flight, chip
## settle, Glim tick), the round end (count-up, dot pop, Next slide), the
## Gallery reveals, the Shortage stamp (intro and keep screen), the upgrade pulse.
##   godot --headless --path godot --script res://tests/pass21_test.gd
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


## Every Control under `n` (in tree order), at rest: what it says and where it
## sits. Creatures, particles and toasts animate on their own: left out.
static func snap(n: Node) -> Array:
	var out := []
	for c in n.find_children("*", "Control", true, false):
		var skip := false
		var p: Node = c
		while p != null and p != n:
			if p is MeldSprite or p is SpoilerSprite or p is Juice or p is DeedToast:
				skip = true
				break
			p = p.get_parent()
		if skip or not (c as Control).is_visible_in_tree() or c.name == "upgrade_pulse" or c.is_queued_for_deletion():
			continue
		var ctl := c as Control
		out.append([ctl.get_class(), ctl.get("text") if ctl.get("text") != null else "",
			ctl.position.round(), ctl.size.round(), ctl.scale.snapped(Vector2(0.001, 0.001)),
			Color(ctl.modulate).to_html()])
	return out


func _wait_quiet(m: Motion, frames := 240) -> void:
	for i in frames:
		if not m.running():
			break
		await process_frame
	for i in 3:
		await process_frame


static func _diff(a: Array, b: Array) -> String:
	if a.size() != b.size():
		return "%d nodes vs %d" % [a.size(), b.size()]
	for i in a.size():
		if a[i] != b[i]:
			return "node %d: %s vs %s" % [i, a[i], b[i]]
	return ""


# ------------------------------------------------------------------ the shop
func _shop(mode: String) -> Array:
	Achv.save_store({"__v": 3, "guided": 1})
	Motion.enabled = mode != "static"
	var run := CribRun.new("thump", Meta.STREETS[0], null, 2101)
	run.essence = 90
	for id in ["keystone2", "ballast"]:
		run.charms.append(CribData.charm_by_id(id))
	run.open_shop()
	run.shop_state.offer = ["fifteener", "fever", "peacock"].map(func(i): return CribData.charm_by_id(i))
	var sh: ShopScreen = load("res://scenes/shop_screen.tscn").instantiate()
	root.add_child(sh)
	sh.size = Vector2(720, 1560)
	sh.open(run)
	sh.finish()
	await process_frame
	sh.buy_charm(CribData.charm_by_id("fever"))
	var mid := {}
	if mode != "static":
		await process_frame
		mid["running"] = sh.motion.running()
		mid["glim"] = sh.essence_label.text
		mid["flyer"] = sh.get_children().any(func(c): return c is TextureRect and c.get_meta("charm_icon", "") == "fever" and c.visible)
	if mode == "skip":
		sh.motion.skip()
	elif mode == "run":
		await _wait_quiet(sh.motion)
	for i in 6:
		await process_frame          # the same settle frames in every mode (buttons size a frame late)
	var s := snap(sh)
	var leftovers := sh.get_children().filter(func(c): return c is TextureRect and c.get_meta("charm_icon", "") != "" and is_instance_valid(c) and not c.is_queued_for_deletion() and c.visible)
	sh.queue_free()
	await process_frame
	Motion.enabled = true
	return [s, mid, leftovers.size(), run.essence]


# ------------------------------------------------------------------ the round end
func _round_end(f: RunFlow, mode: String) -> Array:
	Motion.enabled = mode != "static"
	var run := CribRun.new("thump", Meta.STREETS[0], null, 2102)
	run.twist_plan = {}
	for id in ["keystone2", "ballast", "fifteener"]:
		run.charms.append(CribData.charm_by_id(id))
	var rd := CribRound.new(run)
	while rd.new_deal() != null:
		rd.commit(rd.best_keep_ev().idx)
		if rd.score >= rd.target or rd.deals_left <= 0:
			break
	rd.settle()
	f.run = run
	f.rd = rd
	f._paid = true
	f._no_slide = false
	f._render_round_end()
	var mid := {}
	if mode != "static":
		await process_frame
		mid["running"] = f.round_motion.running()
		var fs := f._page.find_children("*", "Label", true, false).filter(func(l): return String(l.text).begins_with("Final score  "))
		mid["final"] = fs[0].text if not fs.is_empty() else ""
		mid["dot"] = f.new_dot.scale.x if f.new_dot != null else 1.0
		mid["won"] = rd.won
		mid["want_final"] = "Final score  %d / %d" % [rd.score, rd.target]
	if mode == "skip":
		f.round_motion.skip()
	elif mode == "run":
		await _wait_quiet(f.round_motion, 400)
	for i in 6:
		await process_frame
	var s := snap(f._page)
	Motion.enabled = true
	return [s, mid]


# ------------------------------------------------------------------ the Gallery
func _gallery(f: RunFlow, mode: String, shown) -> Array:
	Motion.enabled = mode != "static"
	var st := {"__v": 3, "guided": 1, "charms": {"fifteener": 3, "fever": 2, "peacock": 1, "keystone2": 2}}
	if shown != null:
		st["charms_shown"] = shown
	Achv.save_store(st)
	f.show_front_door("title")
	f.settle()
	Menus.gal_tab = "charms"
	f.front.go("gallery")
	f.settle()
	for i in 20:
		await process_frame
	var mid := {"revealed": Menus.revealed.duplicate(), "running": Menus.gal_motion.running()}
	if mode == "skip":
		Menus.gal_motion.skip()
	elif mode == "run":
		await _wait_quiet(Menus.gal_motion, 400)
	for i in 6:
		await process_frame
	var inner: Control = f.front._page.find_child("inner", true, false)
	var s := snap(inner)
	var saved: Dictionary = Achv.load_store().get("charms_shown", {})
	Motion.enabled = true
	return [s, mid, saved]


# ------------------------------------------------------------------ the Shortage intro
func _intro(f: RunFlow, mode: String) -> Array:
	Motion.enabled = mode != "static"
	var run := CribRun.new("pip", Meta.STREETS[0], null, 2103)
	run.wager_at = {}
	run.cat_points = {"fifteen": 2, "pair": 12, "run": 1, "flush": 0}
	run.round = 2
	f._no_slide = false
	Sound.log.clear()
	f.start_run(run)
	var mid := {}
	if mode != "static":
		mid["scale"] = f.short_line.scale.x if f.short_line != null else 1.0
		mid["sound"] = Sound.log.any(func(e): return e[0] == "spoiler_peg")
	if mode == "skip":
		f.round_motion.skip()
	elif mode == "run":
		await _wait_quiet(f.round_motion)
	for i in 6:
		await process_frame
	var s := snap(f._page)
	Motion.enabled = true
	return [s, mid]


func _go() -> void:
	Achv.persist = false
	Achv.save_store({"__v": 3, "guided": 1})
	root.size = Vector2i(720, 1560)
	Sound.set_muted(false)
	Sound.set_volume(1.0)
	for reduced in [false, true]:
		MeldSprite.reduce_motion = reduced
		var tag := " (Reduce Motion)" if reduced else ""
		# ---- shop purchase
		var a: Array = await _shop("static")
		var b: Array = await _shop("skip")
		var c: Array = await _shop("run")
		ok(_diff(a[0], b[0]) == "", "shop: skip vs static%s: %s" % [tag, _diff(a[0], b[0])])
		ok(_diff(a[0], c[0]) == "", "shop: run vs static%s: %s" % [tag, _diff(a[0], c[0])])
		ok(b[1].running, "shop: nothing was moving after a purchase%s" % tag)
		ok(b[2] == 0 and c[2] == 0, "shop: a flying icon was left behind%s" % tag)
		if not reduced:
			ok(b[1].flyer, "shop: the bought icon didn't fly")
			ok(b[1].glim != "%d Glim" % b[3], "shop: the Glim didn't tick (%s)" % b[1].glim)
		else:
			ok(not b[1].flyer and b[1].glim == "%d Glim" % b[3], "shop: Reduce Motion still flew or ticked")
		# ---- round end
		var f: RunFlow = load("res://scenes/run_flow.tscn").instantiate()
		root.add_child(f)
		await process_frame
		MeldSprite.reduce_motion = reduced     # RunFlow's _ready applied the saved setting
		var ra: Array = await _round_end(f, "static")
		var rb: Array = await _round_end(f, "skip")
		var rc: Array = await _round_end(f, "run")
		ok(_diff(ra[0], rb[0]) == "", "round end: skip vs static%s: %s" % [tag, _diff(ra[0], rb[0])])
		ok(_diff(ra[0], rc[0]) == "", "round end: run vs static%s: %s" % [tag, _diff(ra[0], rc[0])])
		ok(rb[1].running, "round end: nothing moving%s" % tag)
		if not reduced:
			ok(rb[1].final != rb[1].want_final, "round end: the score didn't count up (%s)" % rb[1].final)
			ok(not rb[1].won or rb[1].dot < 0.99, "round end: the new dot didn't pop (%s)" % rb[1].dot)
		else:
			ok(rb[1].final == rb[1].want_final, "round end: Reduce Motion counted (%s vs %s)" % [rb[1].final, rb[1].want_final])
		# ---- Gallery reveals: a first visit records, a later one flips the risen
		var g0: Array = await _gallery(f, "run", null)
		ok(g0[1].revealed.is_empty(), "Gallery: a first visit flipped %s" % [g0[1].revealed])
		ok(int(g0[2].get("fifteener", -1)) == 3 and int(g0[2].get("fever", -1)) == 2, "Gallery: shown levels not saved: %s" % [g0[2]])
		var before := {"fifteener": 2, "fever": 1, "peacock": 1, "keystone2": 2}
		var ga: Array = await _gallery(f, "static", before)
		var gb: Array = await _gallery(f, "skip", before)
		var gc: Array = await _gallery(f, "run", before)
		ok(_diff(ga[0], gb[0]) == "", "Gallery: skip vs static%s: %s" % [tag, _diff(ga[0], gb[0])])
		ok(_diff(ga[0], gc[0]) == "", "Gallery: run vs static%s: %s" % [tag, _diff(ga[0], gc[0])])
		var rev: Array = gb[1].revealed
		rev.sort()
		ok(rev == ["fever", "fifteener"], "Gallery: flipped %s (want fever, fifteener: the two that rose)" % [rev])
		ok(gb[1].running or reduced and gb[1].running, "Gallery: nothing moving%s" % tag)
		var again: Array = await _gallery(f, "skip", gb[2])
		ok(again[1].revealed.is_empty(), "Gallery: flipped again on the next visit: %s" % [again[1].revealed])
		# ---- the Shortage stamp on the intro
		var ia: Array = await _intro(f, "static")
		var ib: Array = await _intro(f, "skip")
		var ic: Array = await _intro(f, "run")
		ok(_diff(ia[0], ib[0]) == "", "intro stamp: skip vs static%s: %s" % [tag, _diff(ia[0], ib[0])])
		ok(_diff(ia[0], ic[0]) == "", "intro stamp: run vs static%s: %s" % [tag, _diff(ia[0], ic[0])])
		ok(ib[1].sound, "intro stamp: no sound%s" % tag)
		if not reduced:
			ok(ib[1].scale > 1.05, "intro stamp: it didn't land from above (%s)" % ib[1].scale)
		# ---- the keep screen's HALF stamp
		Motion.enabled = true
		f._on_deal()
		for i in 60:
			await process_frame
		var hs: Label = f.keep.half_stamp
		ok(hs != null and hs.text == "HALF", "keep: no HALF stamp")
		await _wait_quiet(f.keep.keep_motion)
		if hs != null:
			ok(hs.scale == Vector2.ONE, "keep: the stamp didn't come to rest (%s)" % hs.scale)
			var st_rect := hs.get_global_rect()
			ok(Rect2(Vector2.ZERO, Vector2(720, 1560)).encloses(st_rect), "keep: the stamp is off screen")
		f.queue_free()
		await process_frame
	MeldSprite.reduce_motion = false
	# ---- the upgrade pulse: loops with motion, sits still at rest
	for on in [true, false]:
		Motion.enabled = on
		Achv.save_store({"__v": 3, "guided": 1})
		var found := false
		for sd in range(1, 60):
			var run := CribRun.new("thump", Meta.STREETS[0], null, 5000 + sd)
			for id in ["twinner", "rambler", "peacock", "streak", "keystone2"]:
				run.charms.append(CribData.charm_by_id(id))
			var rd := CribRound.new(run)
			while rd.new_deal() != null:
				rd.commit(rd.best_keep_ev().idx)
				if rd.score >= rd.target or rd.deals_left <= 0:
					break
			run.open_shop()
			run.shop_state.offer = ["fifteener", "fever", "counting"].map(func(i): return CribData.charm_by_id(i))
			if Upgrade.best(run, run.shop_state.offer) == null:
				continue
			var sh: ShopScreen = load("res://scenes/shop_screen.tscn").instantiate()
			root.add_child(sh)
			sh.size = Vector2(720, 1560)
			sh.open(run)
			sh.finish()
			await process_frame
			ok(sh.upgrade_pulse != null, "no upgrade pulse with a mark")
			if sh.upgrade_pulse != null:
				var a0: float = sh.upgrade_pulse.modulate.a
				for i in 30:
					await process_frame
				var a1: float = sh.upgrade_pulse.modulate.a
				if on:
					ok(a1 < 0.99, "the pulse doesn't move (%s -> %s)" % [a0, a1])
				else:
					ok(a0 == 1.0 and a1 == 1.0, "at rest the pulse moved (%s -> %s)" % [a0, a1])
			sh.queue_free()
			await process_frame
			found = true
			break
		ok(found, "no seed gave an upgrade mark")
	Motion.enabled = true
	print("pass21_test: %d checks, %d fails" % [checks, fails])
	quit(1 if fails > 0 else 0)
