extends SceneTree
## The front door's other screens against the WEB, screen by screen, for the same
## stores (fixture: tools/parity/gen_menus.js renders the web's own showDeeds,
## showHistory, showGallery tabs and showTutorial steps):
##   deeds, record, gallery (marks, backs, Meldlings, Spoilers), how to play
## Each shows exactly the web's texts in the web's order. Also: the title's icon
## row opens each screen and Back returns; every button is wired and 44 pt; the
## screens sit on felt under the menu music; no em dash anywhere; settings save
## and apply; the deed toast queues, sounds and buzzes.
##   godot --headless --path godot --script res://tests/menus_test.gd
const FIXTURE := "res://tests/fixtures/menus.json"
var checks := 0
var fails := 0
var per_screen := {}


func ok(c: bool, m: String, screen := "") -> void:
	checks += 1
	if screen != "":
		per_screen[screen] = int(per_screen.get(screen, 0)) + 1
	if not c:
		fails += 1
		if fails <= 25:
			print("FAIL ", m)


func _initialize() -> void:
	_go.call_deferred()


## The texts a player reads, in tree order, outside buttons (as the fixture).
func texts(n: Node) -> Array:
	var out := []
	for c in n.get_children():
		if c is BaseButton:
			continue
		if c is Label and (c as Label).text.strip_edges() != "":
			out.append((c as Label).text.strip_edges())
		out.append_array(texts(c))
	return out


func _diff(a: Array, b: Array) -> String:
	for i in maxi(a.size(), b.size()):
		var x = a[i] if i < a.size() else "<none>"
		var y = b[i] if i < b.size() else "<none>"
		if x != y:
			return "at %d: web '%s', port '%s'" % [i, x, y]
	return ""


func _check_buttons(root_n: Node, where: String) -> void:
	for b in root_n.find_children("*", "BaseButton", true, false):
		var bb := b as BaseButton
		if not bb.is_visible_in_tree():
			continue
		ok(bb.has_meta("press") and bb.size.y >= 80.5, "%s: button '%s' not wired or %d px" % [where, bb.get("text"), bb.size.y])


func _no_dash(root_n: Node, where: String) -> void:
	var bad := texts(root_n).filter(func(t): return String(t).contains("—"))
	ok(bad.is_empty(), "%s: em dash in %s" % [where, bad])


func _go() -> void:
	Achv.persist = false
	root.size = Vector2i(720, 1560)
	var fx = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	ok(fx != null and fx.stores.size() == 4 and fx.tutorial.size() == 6, "fixture loaded")
	var f: RunFlow = load("res://scenes/run_flow.tscn").instantiate()
	root.add_child(f)
	for i in 3:
		await process_frame
	for S in fx.stores:
		Achv.save_store(S.store)
		f.show_front_door("title")
		f.settle()
		await process_frame
		var fd: FrontDoor = f.front
		# the icon row
		for step in ["deeds", "gallery", "record", "howto", "settings"]:
			ok(fd.buttons.has("icon_" + step), "%s: no %s icon on the title" % [S.name, step], "title")
		# ---- deeds
		fd.go("deeds")
		await process_frame
		var d := _diff(S.deeds, texts(fd._page))
		ok(d == "", "%s deeds: %s" % [S.name, d], "deeds")
		_check_buttons(fd, "deeds")
		_no_dash(fd, "deeds")
		# ---- record
		fd.go("record")
		await process_frame
		d = _diff(S.record, texts(fd._page))
		ok(d == "", "%s record: %s" % [S.name, d], "record")
		_check_buttons(fd, "record")
		# ---- gallery tabs
		for tab in ["marks", "backs", "meld", "spoil"]:
			Menus.gal_tab = tab
			fd.go("gallery")
			await process_frame
			d = _diff(S.gallery[tab], texts(fd._page))
			ok(d == "", "%s gallery %s: %s" % [S.name, tab, d], "gallery")
			_check_buttons(fd, "gallery " + tab)
			_no_dash(fd, "gallery " + tab)
		# Back returns to the title
		fd.buttons["back"].emit_signal("pressed")
		await process_frame
		ok(fd.cb.step == "title", "%s: Back from the gallery lands on %s" % [S.name, fd.cb.step], "gallery")
	# the gallery shows every pose: 7 per Meldling, 5 per Spoiler
	Achv.save_store(fx.stores[3].store)
	var fd2: FrontDoor = f.front
	Menus.gal_tab = "meld"
	fd2.go("gallery")
	await process_frame
	var melds := fd2._page.find_children("*", "MeldSprite", true, false).filter(func(x): return not x is SpoilerSprite)
	ok(melds.size() == CribData.DECKS.size() * 8, "Meldlings tab: %d sprites (want %d: a portrait and 7 poses each)" % [melds.size(), CribData.DECKS.size() * 8], "gallery")
	var poses := {}
	for m in melds:
		poses[(m as MeldSprite).pose] = true
	ok(poses.size() >= 7, "every pose shown: %s" % [poses.keys()], "gallery")
	Achv.save_store(fx.stores[0].store)
	fd2.go("gallery")
	await process_frame
	var locked := fd2._page.find_children("*", "MeldSprite", true, false).filter(func(x): return (x as MeldSprite).locked)
	ok(locked.size() > 0, "a fresh save shows locked Meldlings as silhouettes", "gallery")
	Menus.gal_tab = "spoil"
	fd2.go("gallery")
	await process_frame
	ok(fd2._page.find_children("*", "SpoilerSprite", true, false).size() == CribData.BOSS_POOL.size() * 6, "Spoilers tab: a portrait and 5 poses each", "gallery")
	# ---- how to play, step by step, against the web
	Menus.tut_step = 0
	fd2.go("howto")
	for i in fx.tutorial.size():
		await process_frame
		var d2 := _diff(fx.tutorial[i], texts(fd2._page))
		ok(d2 == "", "how to play %d: %s" % [i, d2], "howto")
		_check_buttons(fd2, "how to play %d" % i)
		_no_dash(fd2, "how to play %d" % i)
		ok(fd2._page.find_children("*", "MeldSprite", true, false).size() >= 1, "how to play %d: art" % i, "howto")
		fd2.buttons["next"].emit_signal("pressed")
	await process_frame
	ok(fd2.cb.step == "road" and JS.truthy(Achv.load_store().get("tutorial")), "PLAY at the end goes to the roads and marks it done", "howto")
	ok(_felt(f) and Sound.music_ctx == "menu", "menus on felt, menu music", "howto")
	# ---- settings: each control saves and applies
	Achv.save_store({"__v": 3})
	fd2.go("settings")
	await process_frame
	_check_buttons(fd2, "settings")
	var was := MeldSprite.reduce_motion
	fd2.buttons["set_motion"].emit_signal("pressed")
	await process_frame
	ok(MeldSprite.reduce_motion != was and JS.truthy(Achv.load_store().get("reduce_motion")) == MeldSprite.reduce_motion, "Reduce Motion toggles and saves", "settings")
	MeldSprite.reduce_motion = false
	Menus.apply()
	ok(MeldSprite.reduce_motion == JS.truthy(Achv.load_store().get("reduce_motion")), "saved Reduce Motion applies at start", "settings")
	fd2.buttons["set_sound"].emit_signal("pressed")
	await process_frame
	ok(Sound.muted(), "Sound off saves", "settings")
	fd2.buttons["set_sound"].emit_signal("pressed")
	await process_frame
	ok(not Sound.muted(), "Sound on", "settings")
	var v0 := Sound.volume()
	fd2.buttons["set_volume"].emit_signal("pressed")
	await process_frame
	ok(absf(Sound.volume() - v0) > 0.01, "volume steps", "settings")
	CascadeView.speed_i = 0
	fd2.buttons["set_speed"].emit_signal("pressed")
	await process_frame
	ok(CascadeView.speed_i == 1 and int(Achv.load_store().get("cascade_speed")) == 1, "count speed steps and saves", "settings")
	CascadeView.speed_i = 0
	Menus.apply()
	ok(CascadeView.speed_i == 1, "saved count speed applies at start", "settings")
	MeldSprite.reduce_motion = false
	CascadeView.speed_i = 0
	# ---- the deed toast
	Sound.reset()
	Haptics.log.clear()
	f.announce_deeds(["counted", "his_heels"])
	ok(f.deed_toast.shown == ["Counted"] and f.deed_toast.queue.size() == 1, "one toast at a time: %s" % [f.deed_toast.shown], "toast")
	ok(Sound.log.size() == 1 and Sound.log[0][0] == "deed" and Haptics.log == [20], "the deed sound and buzz together", "toast")
	f.announce_deeds(["clutch"])         # a new deed while one is up waits its turn
	ok(f.deed_toast.shown.size() == 1 and f.deed_toast.queue.size() == 2, "a deed arriving mid-toast queues: %s" % [f.deed_toast.shown], "toast")
	f.show_front_door("title")          # a page change doesn't cut it short
	ok(is_instance_valid(f.deed_toast) and f.deed_toast.busy, "the toast survives a page change", "toast")
	var waited := 0
	while f.deed_toast.shown.size() < 2 and waited < 900:
		await process_frame
		waited += 1
	ok(f.deed_toast.shown.size() == 2 and f.deed_toast.shown[1] == "His Heels", "the second deed follows: %s" % [f.deed_toast.shown], "toast")
	f.queue_free()

	print("menus: per screen %s" % [per_screen])
	print("menus checks: %d, failures: %d" % [checks, fails])
	var good := fails == 0 and checks >= 150
	print("MENUS OK" if good else "MENUS FAILED")
	quit(0 if good else 1)


func _felt(n: Node) -> bool:
	return not n.find_children("*", "Surface", true, false).is_empty()
