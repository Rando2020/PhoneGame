extends SceneTree
## The front door. Fixture group selectui: for three saves (fresh, mid, all
## unlocked), what the web's select steps open, its title line, and the run
## each choice builds. This clicks through RunFlow's front door for every
## fixture path (Five Acts on two Streets x every open Meldling, the Long
## Count, every Trial, the Daily) and compares the run it starts with the JS,
## plus every Meldling's lock state and the layout at three shapes.
##   godot --headless --path godot --script res://tests/front_door_test.gd
const SHAPES := [Vector2i(720, 1280), Vector2i(720, 1560), Vector2i(960, 1280)]
var checks := 0
var fails := 0
var clicks := 0
var runs_checked := 0
var pages := 0
var kinds := {}


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


## Press a front-door button by key, scrolling it into view first.
func press(f: RunFlow, key: String) -> void:
	await process_frame
	var b: Button = f.front.buttons[key]
	var sc = b.get_parent().get_parent()
	if sc is ScrollContainer:
		sc.ensure_control_visible(b)
		await process_frame
		await process_frame
	await _click(b.get_global_rect().get_center())


func card_out(c) -> Dictionary:
	var o := {"rank": c.rank, "suit": c.suit}
	for k in ["enh", "rank2", "suit2"]:
		if c.has(k) and c[k] != null:
			o[k] = c[k]
	return o


func sig(run: CribRun) -> Dictionary:
	var w: Array = run.wager_at.keys()
	w.sort()
	return {"meld": run.meldling, "street": run.street.id, "trial": run.trial.id if run.trial != null else null,
		"endless": run.endless, "seed": run.seed, "cards": run.cards.map(card_out),
		"bosses": run.boss_plan.map(func(b): return b.id), "wagers": w}


## Every button on screen; action buttons centred; nothing above overlaps them.
func check_page(f: RunFlow, shape: Vector2i, where: String) -> void:
	pages += 1
	var screen := Rect2(Vector2.ZERO, Vector2(shape))
	for k in f.front.buttons:
		var b: Button = f.front.buttons[k]
		var r := b.get_global_rect()
		var in_scroll: bool = b.get_parent().get_parent() is ScrollContainer
		if not in_scroll:
			ok(screen.encloses(r), "%s: %s off screen %s" % [where, k, r])
		if k in ["play", "back", "continue", "begin"]:
			ok(absf(r.get_center().x - shape.x / 2.0) <= 1.0, "%s: %s off centre" % [where, k])
			ok(r.position.y >= shape.y * 0.55, "%s: %s out of thumb reach" % [where, k])
	var lowest := 0.0
	for c in f.front._page.get_children():
		var action := false
		for k in ["play", "back", "continue", "begin"]:
			if f.front.buttons.get(k) == c:
				action = true
		if c is Label or c is Panel or (c is Button and not action):
			lowest = maxf(lowest, c.get_global_rect().end.y)
	var top := float(shape.y)
	for k in ["play", "back", "continue", "begin"]:
		if f.front.buttons.has(k):
			top = minf(top, f.front.buttons[k].get_global_rect().position.y)
	ok(lowest <= top + 0.5, "%s: content reaches %.0f, buttons start at %.0f" % [where, lowest, top])


func to_road(f: RunFlow) -> void:
	f.show_front_door("road")
	f.settle()
	await process_frame


func _go() -> void:
	# a script that fails to load hangs the runner: fail fast instead
	for path in ["res://ui/front/front_door.gd", "res://ui/front/run_record.gd", "res://ui/run_flow.gd"]:
		var sc: Script = load(path)
		if sc == null or not sc.can_instantiate():
			print("FAIL %s does not load" % path)
			print("FRONT DOOR FAILED")
			quit(1)
			return
	var fh := FileAccess.open("res://tests/fixtures/parity.json", FileAccess.READ)
	var fx = load("res://tests/parity_test.gd").norm(JSON.parse_string(fh.get_as_text()))
	Achv.persist = false
	var n_ids: int = CribData.DECKS.size()
	for si in fx.selectui.size():
		var S = fx.selectui[si]
		var shape: Vector2i = SHAPES[si % SHAPES.size()]
		root.size = shape
		Achv.save_store(S.store.duplicate(true))
		var f: RunFlow = load("res://scenes/run_flow.tscn").instantiate()
		root.add_child(f)
		await process_frame
		var where := "save %d @%s" % [si, shape]
		# ---- title
		ok(f.screen == "front" and f.cb.step == "title", "%s: didn't open on the title" % where)
		var line: Label = f.front._page.get_node("line")
		ok(line.text == S.line, "%s: title line '%s', web '%s'" % [where, line.text, S.line])
		check_page(f, shape, where + " title")
		# web: a save never guided and with no runs gets the guided first round
		var first: bool = not S.store.has("guided") and not S.store.has("runs")
		ok(f.front.buttons["play"].text.contains("first round") == first, "%s: PLAY label '%s'" % [where, f.front.buttons["play"].text])
		await press(f, "play")
		if first:
			ok(f.screen == "round" and f.coach != null and f.run.meldling == "thump" and int(f.run.street.id) == 1, "%s: fresh PLAY didn't start the guided round" % where)
			f.show_front_door("road")
			f.settle()        # measure the page at rest, not mid-slide
			await process_frame
		ok(f.cb.step == "road", "%s: PLAY didn't open the roads" % where)
		check_page(f, shape, where + " road")
		# ---- what's open
		ok(not f.front.buttons["daily"].disabled and not f.front.buttons["run"].disabled and not f.front.buttons["trial"].disabled, "%s: a road locked" % where)
		ok(f.front.buttons["endless"].disabled == (not S.longRoad), "%s: Long Count lock %s, web %s" % [where, f.front.buttons["endless"].disabled, not S.longRoad])
		var tlabel: Label = f.front.buttons["trial"].get_child(1)
		ok(tlabel.text.contains("%d of %d done" % [S.trialsDone, Meta.TRIALS.size()]), "%s: trial note '%s'" % [where, tlabel.text])
		if S.longRoad:
			ok(f.front.buttons["endless"].get_child(1).text.contains("Best round %d" % S.bestEndless), "%s: endless note" % where)
		# every Meldling's lock, through the carousel
		await press(f, "run")
		ok(f.cb.step == "street", "%s: Five Acts didn't go to the Street" % where)
		check_page(f, shape, where + " street")
		ok(f.front.buttons["next"].disabled == (S.maxStreet <= 1), "%s: street stepper with %d open" % [where, S.maxStreet])
		await press(f, "continue")
		check_page(f, shape, where + " meld")
		for i in n_ids:
			var cur: int = f.cb.meld_idx
			ok(f.front.buttons["begin"].disabled == (not S.meldOpen[cur]), "%s: Meldling %d lock" % [where, cur])
			await press(f, "next")
		ok(f.cb.meld_idx % n_ids == 0, "%s: carousel didn't wrap" % where)
		# ---- every fixture path
		for R in S.runs:
			var p: Array = R.path
			await to_road(f)
			match p[0]:
				"run":
					await press(f, "run")
					while int(f.cb.street.id) > int(p[1]):
						await press(f, "prev")
					while int(f.cb.street.id) < int(p[1]):
						await press(f, "next")
					await press(f, "continue")
					while posmod(int(f.cb.meld_idx), n_ids) != int(p[2]):
						await press(f, "next")
					JS.unseeded = JsRng.new(R.unseeded)
					await press(f, "begin")
				"endless":
					# the Long Count keeps the last Street chosen: set First Street first
					await press(f, "run")
					while int(f.cb.street.id) > 1:
						await press(f, "prev")
					await press(f, "back")
					await press(f, "endless")
					ok(f.cb.step == "meld", "%s: Long Count didn't go to the Meldling" % where)
					while posmod(int(f.cb.meld_idx), n_ids) != int(p[2]):
						await press(f, "next")
					JS.unseeded = JsRng.new(R.unseeded)
					await press(f, "begin")
				"trial":
					await press(f, "trial")
					check_page(f, shape, where + " trials")
					JS.unseeded = JsRng.new(R.unseeded)
					await press(f, "trial_%d" % int(p[1]))
				"daily":
					f.front.today = p[1]
					JS.unseeded = JsRng.new(R.unseeded)
					await press(f, "daily")
			await process_frame
			ok(f.screen == "intro", "%s %s: no intro after choosing (screen %s)" % [where, p, f.screen])
			if f.screen == "intro":
				var d := diff(R.run, sig(f.run))
				ok(d == "", "%s %s: run differs from the web's: %s" % [where, p, d])
				ok(f.cb.step == "road", "%s %s: select step not reset" % [where, p])
				runs_checked += 1
				kinds[p[0]] = int(kinds.get(p[0], 0)) + 1
		# The web's selMeld builds the Long Count with Cb.street, whatever was
		# chosen last: pick the deepest Street, back out, then the Long Count.
		if S.longRoad and S.maxStreet > 1:
			await to_road(f)
			await press(f, "run")
			while int(f.cb.street.id) < int(S.maxStreet):
				await press(f, "next")
			await press(f, "back")
			await press(f, "endless")
			while not S.meldOpen[posmod(int(f.cb.meld_idx), n_ids)]:
				await press(f, "next")
			await press(f, "begin")
			await process_frame
			ok(f.screen == "intro" and f.run.endless and int(f.run.street.id) == int(S.maxStreet),
				"%s: Long Count should keep Street %d, got %s" % [where, S.maxStreet, f.run.street.id if f.run else null])
		f.queue_free()
		await process_frame
	# ---- Meta.record / line against the JS store: a lost round and a won run
	Achv.save_store(fx.selectui[1].store.duplicate(true))
	var m := Achv.load_store()
	ok(int(m.get("runs", 0)) == 2 and RunRecord.line() == fx.selectui[1].line, "record: line from the JS store")
	print("front door: %d runs compared %s, %d pages laid out, %d clicks" % [runs_checked, kinds, pages, clicks])
	var good := fails == 0 and runs_checked >= 60 and kinds.size() == 4 and pages >= 15
	print("front door checks: %d, failures: %d" % [checks, fails])
	print("FRONT DOOR OK" if good else "FRONT DOOR FAILED")
	quit(0 if good else 1)
