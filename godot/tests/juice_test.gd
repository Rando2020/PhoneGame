extends SceneTree
## The juice layer. Bursts and shakes fire on the right events and not on small
## ones; a 15 and a 31 glow; every button on every screen has press feedback and
## is at least 81 px (44 pt) tall; felt replaces the flat backgrounds; RunFlow
## page changes slide and come to rest, and can be interrupted; Reduce Motion
## skips motion; and none of it draws from the game's rng.
##   godot --headless --path godot --script res://tests/juice_test.gd
const SIZE := Vector2i(720, 1560)
var checks := 0
var fails := 0


func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("FAIL ", m)


func _initialize() -> void:
	_go.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## Every visible button under `root`: wired for press feedback, >= 81 px tall.
func _buttons_ok(root: Node, where: String) -> int:
	var n := 0
	for b in root.find_children("*", "BaseButton", true, false):
		var bb := b as BaseButton
		if not bb.is_visible_in_tree():
			continue
		n += 1
		ok(bb.has_meta("press"), "%s: '%s' has no press feedback" % [where, bb.get("text")])
		ok(bb.size.y >= 80.5, "%s: '%s' is %d px tall (< 81)" % [where, bb.get("text"), bb.size.y])
	return n


## Seconds (game time) until RunFlow's page is at rest; 99 if it never is.
func _rest(f: RunFlow) -> float:
	var t0 := Time.get_ticks_msec()
	for i in 2000:
		if absf(f._page.position.x) < 0.01 and f._outgoing == null:
			return (Time.get_ticks_msec() - t0) / 1000.0
		await process_frame
	return 99.0


func _felt(root: Node) -> bool:
	return not root.find_children("*", "Surface", true, false).is_empty()


func _go() -> void:
	Achv.persist = false
	root.size = SIZE
	Engine.time_scale = 1.0
	# ---- Juice itself
	var host := Control.new()
	host.size = Vector2(SIZE)
	root.add_child(host)
	var j := Juice.new()
	host.add_child(j)
	await process_frame
	var before_rng := JS.unseeded.s
	j.burst(Vector2(360, 600), 30)
	ok(j.live() == 30, "a burst of 30: %d" % j.live())
	j.shake(10, 300)
	ok(j.shaking(), "shaking")
	var moved := false
	for i in 10:
		j.step(1.0 / 60.0)
		moved = moved or host.position != Vector2.ZERO
	ok(moved, "the shake moves its target")
	for i in 90:
		j.step(1.0 / 60.0)
	ok(j.live() == 0 and not j.shaking() and host.position.length() < 0.01, "particles gone, shake at rest: %d %s %s %s" % [j.live(), j.shaking(), j._shake_t, host.position])
	ok(JS.unseeded.s == before_rng, "juice drew from JS.unseeded")
	MeldSprite.reduce_motion = true
	j.burst(Vector2(100, 100), 30)
	j.shake(10, 300)
	ok(j.live() == 0 and not j.shaking() and j.bursts == 2 and j.shakes == 2, "Reduce Motion: counted, but no particles or shake")
	MeldSprite.reduce_motion = false
	host.queue_free()
	# ---- Press
	var b := Button.new()
	b.text = "x"
	b.size = Vector2(40, 30)
	b.position = Vector2(100, 100)
	root.add_child(b)
	Press.wire(b)
	ok(b.size.y >= 81 and absf(b.position.y + b.size.y / 2.0 - 115.0) < 1.0, "a small button grows to 81 px about its centre: %s %s" % [b.position, b.size])
	b.button_down.emit()
	ok(b.scale == Vector2(0.97, 0.97) and b.self_modulate.r > 1.0, "down: 0.97 and brighter")
	b.button_up.emit()
	ok(b.self_modulate == Color.WHITE, "up: back to normal colour")
	await _frames(40)
	ok(b.scale.distance_to(Vector2.ONE) < 0.01, "up: springs back to 1: %s" % b.scale)
	b.queue_free()

	# ---- the run's screens
	var f: RunFlow = load("res://scenes/run_flow.tscn").instantiate()
	root.add_child(f)
	await _frames(3)
	var nb := 0
	nb += _buttons_ok(f, "title")
	ok(_felt(f), "title on felt")
	f.front.go("meld")
	await _frames(2)
	nb += _buttons_ok(f, "picker")
	var run := CribRun.new("thump", Meta.STREETS[0], null, 4)
	f.start_run(run)
	await _frames(2)
	nb += _buttons_ok(f, "intro")
	ok(_felt(f), "intro on felt")
	# the transition: the new page slides in, comes to rest
	ok(f._page.position.x > 1.0, "the page arrives from the side: %s" % f._page.position)
	ok(await _rest(f) < 2.0, "the transition comes to rest within 2 s: %s" % f._page.position)
	# interruptible: two page changes in a row end at rest, nothing left behind
	f.show_intro()
	await _frames(2)
	var mid := f._page.position.x
	f.show_intro()
	ok(f._page.position.x > mid, "the interrupting page starts beyond where the last one was")
	ok(await _rest(f) < 2.0 and f._outgoing == null, "an interrupted transition still comes to rest")
	# keep screen
	f.buttons["deal"].emit_signal("pressed")
	await _frames(30)
	nb += _buttons_ok(f, "keep")
	# a re-layout (rotation, a new phone shape) must not shrink them back
	root.size = Vector2i(720, 1280)
	await _frames(3)
	root.size = SIZE
	await _frames(3)
	nb += _buttons_ok(f, "keep after a re-layout")
	ok(f.keep != null and _felt(f.keep), "keep screen on felt")
	# a big count bursts; a small one doesn't
	var k: KeepScreen = f.keep
	var jk: Juice = k.juice
	var bursts0 := jk.bursts
	k.last_result = {"total": MeldReact.big_count(k.rd), "events": [], "cutGain": 0}
	k.juice_count()
	ok(jk.bursts == bursts0 + 1 and jk.shakes >= 1, "a big count bursts and shakes")
	k.last_result = {"total": MeldReact.big_count(k.rd) - 1, "events": [], "cutGain": 0}
	k.juice_count()
	ok(jk.bursts == bursts0 + 1, "a small count doesn't burst")
	# a fifteen line glows in the cascade; other lines don't
	var cv := k.cascade
	cv._add_row({"kind": "fifteen", "label": "Fifteen 2", "value": "+2"})
	cv._add_row({"kind": "pair", "label": "Pair of 3s", "value": "+2"})
	var rows: Array = cv._rows
	var lit_fifteen := false
	var lit_pair := false
	for l in rows[rows.size() - 2].find_children("*", "Label", true, false):
		lit_fifteen = lit_fifteen or Glow.lit(l)
	for l in rows[rows.size() - 1].find_children("*", "Label", true, false):
		lit_pair = lit_pair or Glow.lit(l)
	ok(lit_fifteen and not lit_pair, "a fifteen glows, a pair doesn't (%s %s)" % [lit_fifteen, lit_pair])
	# round end: cleared bursts
	var wr := CribRound.new(run)
	wr.score = wr.target
	wr.settle()
	f.rd = wr
	f._paid = true
	f._render_round_end()
	await _frames(2)
	ok(f.juice.bursts >= 1, "a cleared round bursts")
	nb += _buttons_ok(f, "round end")
	# shop: a legendary bursts, a common doesn't
	f.run.essence = 999
	f.show_shop()
	await _frames(3)
	nb += _buttons_ok(f, "shop")
	ok(_felt(f.shop), "shop on felt")
	ok(not f.shop.find_children("rail", "TextureRect", true, false).is_empty(), "shop has its wood rail")
	var b0 := f.juice.bursts
	var common: Charm = null
	var legend: Charm = null
	for c in CribData.CHARMS:
		if c.rarity == "common" and common == null:
			common = c
		if c.rarity == "legendary" and legend == null:
			legend = c
	f.shop.buy_charm(common)
	ok(f.juice.bursts == b0, "a common purchase doesn't burst")
	f.shop.buy_charm(legend)
	ok(f.juice.bursts == b0 + 1, "a legendary purchase bursts")
	f.queue_free()
	await _frames(2)

	# ---- The Play: 31 bursts and glows
	var prd := CribRound.new(CribRun.new("pip", null, null, 5))
	prd.new_deal()
	var ses := PegSession.start(prd, prd.dealt.slice(0, 4))
	var pv := PegView.new()
	root.add_child(pv)
	pv.open(ses)
	await process_frame
	nb += _buttons_ok(pv, "The Play")
	ok(_felt(pv), "The Play on felt")
	ok(not pv.find_children("rail", "TextureRect", true, false).is_empty(), "The Play has its table edge")
	var pb := pv.juice.bursts
	ses.play.total = 31
	ses.play.last_lay = {"who": "you", "events": [], "hit31": true}
	pv.juice_lay()
	pv.render()
	ok(pv.juice.bursts == pb + 1 and Glow.lit(pv.total_label), "31: a burst and a glow")
	ses.play.total = 20
	ses.play.last_lay = {"who": "you", "events": [], "hit31": false}
	pv.juice_lay()
	pv.render()
	ok(pv.juice.bursts == pb + 1 and not Glow.lit(pv.total_label), "20: nothing")
	ses.play.over = true
	pv.render()
	await process_frame
	nb += _buttons_ok(pv, "The Play payout")
	pv.queue_free()
	ok(nb >= 14, "buttons checked: %d" % nb)

	print("juice checks: %d, failures: %d" % [checks, fails])
	var good := fails == 0 and checks >= 50
	print("JUICE OK" if good else "JUICE FAILED")
	quit(0 if good else 1)
