class_name RunCard
extends SubViewport
## A run card to share (pass 19): one 1080x1350 PNG of a finished run. The
## Meldling, how far it got, the best single count, the charms with their
## icons, the street and the date, drawn by Godot itself in an off-screen
## viewport. Presentation only.
##
## Rendered once: the image is read on RenderingServer.frame_post_draw (a
## signal, no await), saved to user://, then handed to the share sheet when
## the build has the MeldShare plugin (iOS; unverified without a Mac).
## Without it (desktop, editor), the saved file is the result.

const W := 1080
const H := 1350
const BG := Color(0.086, 0.157, 0.122)
const PANEL := Color(0.098, 0.086, 0.153)
const INK := Color(0.96, 0.93, 0.88)
const DIM := Color(0.96, 0.93, 0.88, 0.62)
const GOLD := Color(0.91, 0.71, 0.30)

var labels: Array[Label] = []     ## every text on the card (tests: none off-canvas)
var icons: Array = []             ## the charm icons placed (tests)
var page: Control


## The card's content for a finished run. `won`: every round cleared.
static func build(run: CribRun, won: bool, date := "") -> RunCard:
	var c := RunCard.new()
	c.size = Vector2i(W, H)
	c.transparent_bg = false
	c.render_target_update_mode = SubViewport.UPDATE_ONCE
	c.page = Control.new()
	c.page.size = Vector2(W, H)
	c.add_child(c.page)
	var bg := ColorRect.new()
	bg.color = BG
	bg.size = Vector2(W, H)
	c.page.add_child(bg)
	var frame := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = GOLD
	sb.set_border_width_all(6)
	sb.set_corner_radius_all(28)
	frame.add_theme_stylebox_override("panel", sb)
	frame.position = Vector2(24, 24)
	frame.size = Vector2(W - 48, H - 48)
	c.page.add_child(frame)
	# fixed bands, so the card is never half empty: title, Meldling, the line,
	# the best count, the charms, the footer
	c._text("MELDLINGS", 72, GOLD, 74.0)
	var meld := MeldSprite.new(run.meldling)
	meld.pose = "victory" if won else "eager"
	meld.size = Vector2(500, 500)
	meld.position = Vector2((W - 500) / 2.0, 190.0)
	c.page.add_child(meld)
	var how := "Cleared every round" if won else "Reached Act %d, Round %d" % [run.act, run.round]
	var y := c._text(how, 60, INK, 720.0)
	c._text("Best count  %d" % run.best_count, 46, GOLD, y + 4.0)
	var owned: Array = run.charms.slice(0, 6)
	if not owned.is_empty():
		var n := owned.size()
		var cell := minf(170.0, (W - 160.0) / n)
		var x0 := (W - n * cell) / 2.0
		var top := 930.0
		for i in n:
			var ch: Charm = owned[i]
			var ic := CharmIcon.make(ch.id, 132.0)
			if ic != null:
				ic.position = Vector2(x0 + i * cell + (cell - 132.0) / 2.0, top)
				c.page.add_child(ic)
				c.icons.append(ic)
			c._label(ch.name, 26, DIM, Vector2(x0 + i * cell + 4.0, top + 140.0), cell - 8.0)
	else:
		c._text("No charms. Pure counting.", 34, DIM, 980.0)
	var d := date if date != "" else Time.get_date_string_from_system()
	c._text("%s  ·  %s" % [run.street.name, d], 32, DIM, H - 126.0)
	return c


func _label(text: String, fs: int, col: Color, at: Vector2, w: float) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.position = at
	l.size = Vector2(w, 0)
	page.add_child(l)
	# measured from the font (the card isn't in the tree yet, so a Label's own
	# minimum size would read 0 and lines would stack on each other)
	var font: Font = ThemeDB.fallback_font
	var h := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, w, fs).y
	l.size = Vector2(w, ceilf(h) + 4.0)
	labels.append(l)
	return l


func _text(text: String, fs: int, col: Color, y: float) -> float:
	var l := _label(text, fs, col, Vector2(80, y), W - 160.0)
	return y + l.size.y + 6.0


## Draw once and save. `done.call(path)` after the frame is drawn ("" on a
## renderer that draws nothing, as headless). Needs to be in the tree.
func render_to(path: String, done: Callable) -> void:
	render_target_update_mode = SubViewport.UPDATE_ONCE
	RenderingServer.frame_post_draw.connect(func():
		var img := get_texture().get_image() if get_texture() != null else null
		var ok := img != null and not img.is_empty() and img.save_png(path) == OK
		done.call(path if ok else ""), CONNECT_ONE_SHOT)


## The share sheet when the plugin is there (iOS), else nothing: the file is
## already saved. Returns whether a sheet was asked for.
static func share(path: String) -> bool:
	if path == "" or not Engine.has_singleton("MeldShare"):
		return false
	Engine.get_singleton("MeldShare").call("share_image", ProjectSettings.globalize_path(path))
	return true
