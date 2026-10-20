extends SceneTree
## Apple's text floor (audit #1): on all 13 screens, at 720x1280 and 720x1560 and
## at every Text size setting, every visible label and button reads at 20 px
## (11 pt) or more, no button is under 81 px (44 pt), no text runs off the
## screen, and no label sits on top of another.
##   godot --headless --path godot --script res://tests/text_size_test.gd
## Prints a per-screen table (labels under 20 px / total) for docs/AUDIT.md.
var checks := 0
var fails := 0
var table := {}
var body_all := 0         ## reading lines seen at 720x1560, Standard
var body_big := 0         ## of those, at 17 pt (31 px) or more
var body_by := {}
var BODY := {}            ## every description a player reads, by text


static func body_texts() -> Dictionary:
	var out := {}
	for a in Meta.ACHIEVEMENTS:
		out[String(a.text)] = true
	for c in CribData.CHARMS:
		out[String(c.text)] = true
	for k in CribData.DECKS:
		out[String(CribData.DECKS[k].text)] = true
	for b in CribData.BOSS_POOL:
		out[String(b.text)] = true
	for k in CribData.ENHANCEMENTS:
		if CribData.ENHANCEMENTS[k].has("text"):
			out[String(CribData.ENHANCEMENTS[k].text)] = true
	for st in Menus.TUT_STEPS:
		out[String(st.body)] = true
	return out

const FRONT := ["title", "road", "street", "meld", "peddler", "deeds", "record", "gallery", "gallery:meld", "gallery:spoil", "gallery:marks", "howto", "howto:2", "howto:6", "settings"]


func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		if fails <= 30:
			print("FAIL ", m)


func _initialize() -> void:
	_go.call_deferred()


static func _nested(a: Node, b: Node) -> bool:
	return a.is_ancestor_of(b) or b.is_ancestor_of(a)


## Where the glyphs actually are: the wrapped text's size, placed by alignment.
static func _ink(l: Label, fs: int) -> Rect2:
	var font := l.get_theme_font("font")
	var wrap := l.size.x if l.autowrap_mode != TextServer.AUTOWRAP_OFF else -1.0
	var sz := font.get_multiline_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, wrap, fs)
	var g := l.get_global_rect()
	var x := g.position.x
	if l.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
		x += (g.size.x - sz.x) * 0.5
	elif l.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
		x += g.size.x - sz.x
	var y := g.position.y
	if l.vertical_alignment == VERTICAL_ALIGNMENT_CENTER:
		y += (g.size.y - sz.y) * 0.5
	elif l.vertical_alignment == VERTICAL_ALIGNMENT_BOTTOM:
		y += g.size.y - sz.y
	return Rect2(Vector2(x, y), sz)


## Where a card is drawn: its rect through its transform (CardView scales
## about its centre, so position and size alone miss it).
static func _drawn(cv: Control) -> Rect2:
	var t := cv.get_global_transform()
	var a := t * Vector2.ZERO
	var b := t * cv.size
	return Rect2(a, b - a).abs()


static func _cards(n: Node) -> Array:
	return n.find_children("*", "CardView", true, false).filter(
		func(c): return c.is_visible_in_tree() and c.modulate.a > 0.05)


static func probe(n: Node, view: Vector2, body_set := {}) -> Dictionary:
	var r := {"body_set": body_set, "body": 0, "body_big": 0, "total": 0, "small": 0, "sizes": [], "off": [], "tall": [], "btn": [], "rects": [], "cards": _cards(n)}
	for c in n.find_children("*", "Control", true, false):
		var ctl := c as Control
		if not ctl.is_visible_in_tree() or ctl.modulate.a < 0.05:
			continue
		var text := ""
		if ctl is Label:
			text = (ctl as Label).text
		elif ctl is Button:
			text = (ctl as Button).text
		if ctl is BaseButton and ctl.mouse_filter != Control.MOUSE_FILTER_IGNORE and ctl.size.y < 80.5:
			r.btn.append("%s %d px" % [text, ctl.size.y])
		if text.strip_edges() == "":
			continue
		var fs := ctl.get_theme_font_size("font_size")
		r.total += 1
		if ctl is Label and r.has("body_set") and r.body_set.has(text):
			r.body += 1
			if fs >= 31:
				r.body_big += 1
		if fs < TypeScale.MIN_PX:
			r.small += 1
			r.sizes.append("%s(%d)" % [text.left(18), fs])
		var g := ctl.get_global_rect()
		if g.position.x < -1.0 or g.end.x > view.x + 1.0:
			r.off.append("%s [%d..%d]" % [text.left(18), g.position.x, g.end.x])
		if ctl is Button:
			# a button's text must fit: whole (no wrap), or word by word (wrapping)
			var bb := ctl as Button
			var sb := bb.get_theme_stylebox("normal")
			var room := bb.size.x - (sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT) if sb != null else 0.0)
			var bf := bb.get_theme_font("font")
			var pieces: Array = [text] if bb.autowrap_mode == TextServer.AUTOWRAP_OFF else Array(text.split(" "))
			for piece in pieces:
				var bw := bf.get_string_size(piece, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				if bw > room + 1.0:
					r.off.append("button '%s' trimmed %d > %d" % [String(piece).left(18), bw, room])
			if bb.autowrap_mode != TextServer.AUTOWRAP_OFF:
				var need := bf.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, room, fs).y
				if need > bb.size.y + 1.0:
					r.off.append("button '%s' too tall %d > %d" % [text.left(18), need, bb.size.y])
		if ctl is Label and ((ctl as Label).clip_text or (ctl as Label).text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING):
			var lw := (ctl as Label).get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			if lw > ctl.size.x + 1.0:
				r.off.append("%s trimmed %d > %d" % [text.left(18), lw, ctl.size.x])
		if ctl is Label:
			g = _ink(ctl as Label, fs)
			for cv in r.cards:
				if not cv.is_ancestor_of(ctl) and _drawn(cv).intersection(g).get_area() > 0.25 * g.get_area():
					r.tall.append("'%s' on a card" % text.left(18))
			for o in r.rects:
				var ov: Rect2 = o[1].intersection(g)
				if ov.get_area() > 0.25 * minf(g.get_area(), o[1].get_area()) and not _nested(ctl, o[2]):
					r.tall.append("'%s' on '%s'" % [text.left(18), String(o[0]).left(18)])
			r.rects.append([text, g, ctl])
	return r


func _visit(f: RunFlow, where: String, view: Vector2, strict: bool) -> void:
	await process_frame
	f.settle()
	await process_frame
	var r := probe(f, view, BODY)
	if strict:
		table[where] = "%d/%d" % [r.small, r.total]
		body_all += r.body
		body_big += r.body_big
		if r.body > 0:
			body_by[where.get_slice(" ", 0)] = "%d/%d" % [r.body_big, r.body]
	ok(r.total > 0, "%s: no text found" % where)
	ok(r.small == 0, "%s: %d of %d labels under 20 px: %s" % [where, r.small, r.total, r.sizes.slice(0, 6)])
	ok(r.btn.is_empty(), "%s: buttons under 81 px: %s" % [where, r.btn.slice(0, 4)])
	ok(r.off.is_empty(), "%s: text off screen: %s" % [where, r.off.slice(0, 4)])
	ok(r.tall.is_empty(), "%s: text overlaps text: %s" % [where, r.tall.slice(0, 4)])


func _go() -> void:
	Achv.persist = false
	BODY = body_texts()
	for view in [Vector2(720, 1560), Vector2(720, 1280)]:
		for si in TypeScale.STEPS.size():
			TypeScale.scale = TypeScale.STEPS[si]
			TypeScale.apply_fallback()
			root.size = Vector2i(view)
			var f: RunFlow = load("res://scenes/run_flow.tscn").instantiate()
			root.add_child(f)
			TypeScale.scale = TypeScale.STEPS[si]    # _ready loads the saved setting
			TypeScale.apply_fallback()
			for i in 3:
				await process_frame
			var tag := "%dx%d@%.2f" % [view.x, view.y, TypeScale.scale]
			var strict: bool = si == 0 and view.y == 1560
			for step in FRONT:
				f.show_front_door("title")
				f.settle()
				if step.begins_with("howto:"):
					Menus.tut_step = int(step.get_slice(":", 1))
					f.front.go("howto")
				elif step.contains(":"):
					Menus.gal_tab = step.get_slice(":", 1)
					f.front.go("gallery")
				elif step != "title":
					Menus.gal_tab = "cards"
					Menus.tut_step = 0
					f.front.go(step)
				await _visit(f, "%s %s" % [step, tag], view, strict)
			JS.unseeded = JsRng.new(4242)
			for g in ["split_cards", "deep_stall", "sixth_slot"]:
				Achv.grant_system(g)
			# the longest names, a full bar: the worst case for chips
			var run := CribRun.new("clover", null, null, 7011)
			for id in ["keystone2", "quartermaster", "counting", "thebank", "sovereign"]:
				run.charms.append(CribData.charm_by_id(id))
			f.start_run(run)
			await _visit(f, "intro " + tag, view, strict)
			f._on_deal()
			for i in 90:
				await process_frame
			await _visit(f, "keep " + tag, view, strict)
			f.show_shop()
			await _visit(f, "shop " + tag, view, strict)
			f.show_free_end()
			await _visit(f, "free_end " + tag, view, strict)
			f.queue_free()
			await process_frame
	TypeScale.scale = 1.0
	TypeScale.apply_fallback()
	var keys := table.keys()
	print("labels under 20 px at 720x1560, Standard: ", ", ".join(keys.map(func(k): return "%s %s" % [String(k).get_slice(" ", 0), table[k]])))
	ok(body_all >= 40 and body_big == body_all, "reading text under 17 pt: %d of %d lines" % [body_all - body_big, body_all])
	print("body lines at 17 pt or more, 720x1560 Standard: %d of %d (%d%%)  %s" % [body_big, body_all, roundi(100.0 * body_big / maxf(1, body_all)), body_by])
	print("text_size_test: %d checks, %d fails" % [checks, fails])
	quit(1 if fails > 0 else 0)
