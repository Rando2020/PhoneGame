extends SceneTree
## Pass 19: charm art, the collection, the run card. Presentation and meta only.
##  - art: an icon (1x and 2x, right sizes) for every charm id in BOTH engines'
##    lists, a silhouette for every category, no two icons pixel-identical
##  - icons in the UI: bar chips (not the Meldling's knack), shop offers and
##    owned chips (never splitting a word), the upgrade line, the round end's
##    MVP and synergy line; the bar drops icons rather than grow
##  - collection: states only rise; shop offers -> seen; a buy -> owned, with
##    a first-purchase card once per charm ever; a cleared run -> won; saved to
##    disk and read back; the Gallery tab shows every charm in its real state,
##    unseen ones as a silhouette that names nothing
##  - run card: 1080x1350, every text inside it, one icon per charm, best count
##    = the run's best hand total
##   godot --headless --path godot --script res://tests/pass19_test.gd
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


static func _labels(n: Node) -> Array:
	return n.find_children("*", "Label", true, false).map(func(l): return String(l.text))


func _go() -> void:
	Achv.persist = false
	Achv.save_store({"__v": 3, "guided": 1})
	root.size = Vector2i(720, 1560)
	# ---- art for every id, in both engines
	var web := FileAccess.get_file_as_string("res://../web/cribrogue.js")
	var web_ids := []
	var rx := RegEx.new()
	rx.compile("\\{\\s*id:\\s*\"([a-z0-9_]+)\",\\s*name:\\s*\"[^\"]+\",\\s*tier:")
	for m in rx.search_all(web):
		web_ids.append(m.get_string(1))
	var port_ids: Array = CribData.CHARMS.map(func(c): return c.id)
	ok(web_ids.size() >= 53 and port_ids.size() >= 53, "charm lists: web %d, port %d" % [web_ids.size(), port_ids.size()])
	var hashes := {}
	for id in port_ids + web_ids.filter(func(i): return not port_ids.has(i)):
		var p1 := "res://assets/charms/charm_%s.png" % id
		var p2 := CharmIcon.path(id)
		ok(ResourceLoader.exists(p1) and ResourceLoader.exists(p2), "no icon for %s" % id)
		if ResourceLoader.exists(p1) and ResourceLoader.exists(p2):
			var a: Image = (load(p1) as Texture2D).get_image()
			var b: Image = (load(p2) as Texture2D).get_image()
			ok(a.get_size() == Vector2i(32, 32) and b.get_size() == Vector2i(64, 64), "%s sizes %s %s" % [id, a.get_size(), b.get_size()])
			var h := a.get_data().hex_encode().md5_text()
			ok(not hashes.has(h), "%s draws the same as %s" % [id, hashes.get(h)])
			hashes[h] = id
	for cat in ["fifteen", "pair", "run", "flush", "mult", "rule", "deck"]:
		ok(CharmIcon.silhouette(cat, 64.0) != null, "no silhouette for %s" % cat)
	ok(CharmIcon.make("", 40.0) == null and CharmIcon.make("nope", 40.0) == null, "no icon for no charm")

	# ---- the bar
	var run := CribRun.new("thump", Meta.STREETS[0], null, 91)
	for id in ["keystone2", "ballast", "fifteener"]:
		run.charms.append(CribData.charm_by_id(id))
	var bar := CharmBar.new()
	root.add_child(bar)
	bar.size = Vector2(672, 48)
	bar.build(run)
	var with_icon := bar.chips.filter(func(c): return c.get("icon") != null)
	ok(with_icon.size() == 3 and bar.chips[0].get("icon") == null, "bar icons: %d of %d chips; knack %s" % [with_icon.size(), bar.chips.size(), bar.chips[0].get("icon")])
	ok(with_icon.all(func(c): return c.icon.visible), "bar icons shown at standard size")
	# a phone's 6-slot bar has no room beside names: icon-only chips, same height
	ok(bar.icon_only and with_icon.all(func(c): return not c.label.visible and c.panel.tooltip_text == c.name), "phone bar: icon-only chips with the name as a tooltip")
	ok(bar.chips[0].label.visible and bar.chips[0].label.text == "Thump", "the knack keeps its name")
	var plain := CharmBar.new()
	root.add_child(plain)
	plain.size = Vector2(672, 48)
	var pr := CribRun.new("thump", Meta.STREETS[0], null, 91)
	plain.build(pr)
	ok(absf(bar.height() - plain.height()) < 0.5, "icons changed the bar's height: %.0f vs %.0f" % [bar.height(), plain.height()])
	plain.queue_free()
	# a wide bar (room beside names): icon and name together
	bar.size = Vector2(1400, 48)
	bar._layout()
	ok(bar.icons_on and not bar.icon_only and with_icon.all(func(c): return c.icon.visible and c.label.visible), "a wide bar shows icon and name")
	bar.queue_free()

	# ---- shop: icons, the word rule, seen and owned, the first card
	Achv.save_store({"__v": 3, "guided": 1, "pegs": 0})
	var f: RunFlow = load("res://scenes/run_flow.tscn").instantiate()
	root.add_child(f)
	await process_frame
	var sr := CribRun.new("thump", Meta.STREETS[0], null, 92)
	for id in ["keystone2", "quartermaster", "ballast"]:
		sr.charms.append(CribData.charm_by_id(id))
	sr.essence = 200
	sr.open_shop()
	sr.shop_state.offer = ["fifteener", "fever", "peacock"].map(func(i): return CribData.charm_by_id(i))
	f.run = sr
	f.show_shop()
	f.shop.finish()
	await process_frame
	for id in ["fifteener", "fever", "peacock"]:
		var b: Control = f.shop.offer_buttons[id]
		ok(b.find_children("*", "TextureRect", true, false).any(func(t): return t.get_meta("charm_icon", "") == id), "offer %s has no icon" % id)
		ok(Collection.level(id) == Collection.SEEN, "offer %s not marked seen: %d" % [id, Collection.level(id)])
	var icons_now := f.shop.find_children("*", "TextureRect", true, false).map(func(t): return String(t.get_meta("charm_icon", "")))
	ok(icons_now.has("keystone2") and not icons_now.has("quartermaster"), "owned chips: icon for Keystone, none for Quartermaster (it would split the word): %s" % [icons_now])
	ok(not icons_now.has("thump"), "the knack has no icon")
	var firsts := []
	f.shop.first_charm.connect(func(ch): firsts.append(ch.id))
	ok(f.shop.buy_charm(CribData.charm_by_id("fifteener")), "buy failed")
	ok(firsts == ["fifteener"] and Collection.level("fifteener") == Collection.OWNED, "first purchase: %s, level %d" % [firsts, Collection.level("fifteener")])
	ok(f.deed_toast.celebrated.has("charm:fifteener"), "no first-purchase card: %s" % [f.deed_toast.celebrated])
	# a second run buying it again: no second card
	var sr2 := CribRun.new("pip", Meta.STREETS[0], null, 93)
	sr2.essence = 200
	sr2.open_shop()
	sr2.shop_state.offer = [CribData.charm_by_id("fifteener")]
	f.run = sr2
	f.show_shop()
	f.shop.finish()
	var again := []
	f.shop.first_charm.connect(func(ch): again.append(ch.id))
	f.shop.buy_charm(CribData.charm_by_id("fifteener"))
	ok(again.is_empty(), "a second purchase celebrated again")
	# states never fall
	ok(not Collection.mark("fifteener", Collection.SEEN) and Collection.level("fifteener") == Collection.OWNED, "a state fell")
	ok(not Collection.mark("nope", Collection.OWNED), "an unknown id was marked")
	# a cleared run: won with
	sr2.charms = [CribData.charm_by_id("fifteener"), CribData.charm_by_id("rambler")]
	f.run = sr2
	f._run_won_effects()
	ok(Collection.level("fifteener") == Collection.WON and Collection.level("rambler") == Collection.WON, "won with: %d %d" % [Collection.level("fifteener"), Collection.level("rambler")])
	ok(Collection.count(Collection.WON) == 2 and Collection.count(Collection.OWNED) == 2 and Collection.count(Collection.SEEN) >= 4, "counts %d/%d/%d" % [Collection.count(Collection.SEEN), Collection.count(Collection.OWNED), Collection.count(Collection.WON)])

	# ---- saved to disk and read back
	var had := FileAccess.file_exists(Achv.SAVE_PATH)
	var keep := FileAccess.get_file_as_string(Achv.SAVE_PATH) if had else ""
	var mem := Achv.load_store().duplicate(true)
	Achv.persist = true
	Achv.save_store(mem)
	Achv._cache = null
	ok(Collection.level("fifteener") == Collection.WON and Collection.level("fever") == Collection.SEEN, "after a reload: %d %d" % [Collection.level("fifteener"), Collection.level("fever")])
	if had:
		var w := FileAccess.open(Achv.SAVE_PATH, FileAccess.WRITE)
		w.store_string(keep)
		w.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Achv.SAVE_PATH))
	Achv._cache = null
	Achv.persist = false
	Achv.save_store(mem)

	# ---- the Gallery tab
	f.show_front_door("title")
	Menus.gal_tab = "charms"
	f.front.go("gallery")
	f.settle()
	for k in 30:
		await process_frame
	ok(Menus.charm_cells.size() == CribData.CHARMS.size(), "Gallery shows %d of %d charms" % [Menus.charm_cells.size(), CribData.CHARMS.size()])
	var cell_ok := true
	for cell in Menus.charm_cells:
		var lv: int = cell.level
		if lv != Collection.level(cell.id):
			cell_ok = false
		var ic: TextureRect = cell.icon
		if lv == Collection.UNSEEN:
			cell_ok = cell_ok and ic.has_meta("charm_silhouette") and not ic.has_meta("charm_icon") and cell.name.text == "???"
		else:
			cell_ok = cell_ok and ic.get_meta("charm_icon", "") == cell.id and cell.name.text.ends_with(CribData.charm_by_id(cell.id).name)
		if lv == Collection.WON:
			cell_ok = cell_ok and cell.name.text.begins_with("★")
	ok(cell_ok, "a Gallery cell shows the wrong state")
	ok(_labels(f).has("Charms %d / %d" % [Collection.count(Collection.OWNED), CribData.CHARMS.size()]), "Gallery header count")

	# ---- round end icons
	var rr := CribRun.new("thump", Meta.STREETS[0], null, 94)
	for id in ["keystone2", "ballast", "fifteener", "tallyman", "usury"]:
		rr.charms.append(CribData.charm_by_id(id))
	var got_mvp := false
	var got_syn := false
	for sd in range(1, 300):
		rr = CribRun.new("thump", Meta.STREETS[0], null, 600 + sd)
		rr.twist_plan = {}
		for id in ["keystone2", "ballast", "fifteener", "tallyman", "usury"]:
			rr.charms.append(CribData.charm_by_id(id))
		var rd := CribRound.new(rr)
		while rd.new_deal() != null:
			rd.commit(rd.best_keep_ev().idx)
			if rd.score >= rd.target or rd.deals_left <= 0:
				break
		rd.settle()
		var m = rd.mvp()
		var is_charm: bool = m != null and CharmIcon.id_for(str(m.name)) != ""
		var syn = rd.best_synergy()
		if not rd.won or (got_mvp or not is_charm) and (got_syn or syn == null):
			continue
		f.run = rr
		f.rd = rd
		f._paid = true
		f._render_round_end()
		if is_charm:
			ok(f.mvp_icon != null and f.mvp_icon.get_meta("charm_icon") == CharmIcon.id_for(str(m.name)), "MVP icon for %s" % m.name)
			got_mvp = true
		if syn != null:
			var want: Array = String(syn.pair).split(" + ")
			ok(f.synergy_icons.size() == 2 and f.synergy_icons[0].get_meta("charm_icon") == CharmIcon.id_for(want[0]) and f.synergy_icons[1].get_meta("charm_icon") == CharmIcon.id_for(want[1]), "synergy icons %s" % [syn.pair])
			got_syn = true
		if got_mvp and got_syn:
			break
	ok(got_mvp and got_syn, "round ends seen: MVP %s, synergy %s" % [got_mvp, got_syn])

	# ---- the run card
	var cr := CribRun.new("thump", Meta.STREETS[1], null, 95)
	for id in ["keystone2", "ballast", "fifteener", "tallyman", "usury"]:
		cr.charms.append(CribData.charm_by_id(id))
	var best := 0
	var cd := CribRound.new(cr)
	while cd.new_deal() != null:
		var res = cd.commit(cd.best_keep_ev().idx)
		best = maxi(best, JS.round_(res.total))
		if cd.score >= cd.target or cd.deals_left <= 0:
			break
	ok(cr.best_count == best and best > 0, "best count %d vs %d" % [cr.best_count, best])
	for won in [false, true]:
		var card := RunCard.build(cr, won, "2026-10-22")
		ok(card.size == Vector2i(1080, 1350), "card size %s" % card.size)
		ok(card.icons.size() == 5, "card icons %d" % card.icons.size())
		var inside := Rect2(Vector2.ZERO, Vector2(1080, 1350))
		var off := card.labels.filter(func(l): return not inside.encloses(Rect2(l.position, l.size)) or l.size.y < 10.0)
		ok(off.is_empty(), "card text off the card or unsized: %s" % [off.map(func(l): return l.text)])
		# each label as tall as its text really is (an unsized label let lines
		# stack on each other in the first render)
		var short := card.labels.filter(func(l):
			var fs: int = l.get_theme_font_size("font_size")
			return l.size.y + 0.5 < ThemeDB.fallback_font.get_multiline_string_size(l.text, HORIZONTAL_ALIGNMENT_CENTER, l.size.x, fs).y)
		ok(short.is_empty(), "card labels shorter than their text: %s" % [short.map(func(l): return l.text)])
		var texts := card.labels.map(func(l): return l.text)
		ok(texts.has("Best count  %d" % best) and texts.has("Second Street  ·  2026-10-22"), "card texts %s" % [texts])
		ok(texts.has("Cleared every round") if won else texts.has("Reached Act 1, Round 1"), "card line (won %s)" % won)
		card.free()
	ok(not RunCard.share(""), "share with no file")
	f.queue_free()
	await process_frame
	print("pass19_test: %d checks, %d fails" % [checks, fails])
	quit(1 if fails > 0 else 0)
