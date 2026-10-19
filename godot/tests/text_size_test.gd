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

const FRONT := ["title", "road", "street", "meld", "peddler", "deeds", "record", "gallery", "howto", "settings"]


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


static func probe(n: Node, view: Vector2) -> Dictionary:
	var r := {"total": 0, "small": 0, "sizes": [], "off": [], "tall": [], "btn": [], "rects": []}
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
		if fs < TypeScale.MIN_PX:
			r.small += 1
			r.sizes.append("%s(%d)" % [text.left(18), fs])
		var g := ctl.get_global_rect()
		if g.position.x < -1.0 or g.end.x > view.x + 1.0:
			r.off.append("%s [%d..%d]" % [text.left(18), g.position.x, g.end.x])
		if ctl is Label and ((ctl as Label).clip_text or (ctl as Label).text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING):
			var lw := (ctl as Label).get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			if lw > ctl.size.x + 1.0:
				r.off.append("%s trimmed %d > %d" % [text.left(18), lw, ctl.size.x])
		if ctl is Label:
			g = _ink(ctl as Label, fs)
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
	var r := probe(f, view)
	if strict:
		table[where] = "%d/%d" % [r.small, r.total]
	ok(r.total > 0, "%s: no text found" % where)
	ok(r.small == 0, "%s: %d of %d labels under 20 px: %s" % [where, r.small, r.total, r.sizes.slice(0, 6)])
	ok(r.btn.is_empty(), "%s: buttons under 81 px: %s" % [where, r.btn.slice(0, 4)])
	ok(r.off.is_empty(), "%s: text off screen: %s" % [where, r.off.slice(0, 4)])
	ok(r.tall.is_empty(), "%s: text overlaps text: %s" % [where, r.tall.slice(0, 4)])


func _go() -> void:
	Achv.persist = false
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
				if step != "title":
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
			f.queue_free()
			await process_frame
	TypeScale.scale = 1.0
	TypeScale.apply_fallback()
	var keys := table.keys()
	print("labels under 20 px at 720x1560, Standard: ", ", ".join(keys.map(func(k): return "%s %s" % [String(k).get_slice(" ", 0), table[k]])))
	print("text_size_test: %d checks, %d fails" % [checks, fails])
	quit(1 if fails > 0 else 0)
