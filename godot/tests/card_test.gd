extends SceneTree
## CardView treatments: marks, split cards, reuse. Headless, no rendering needed.
##   godot --headless --path godot --script res://tests/card_test.gd
var checks := 0
var fails := 0

func ok(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL ", msg)

func _initialize() -> void:
	_go.call_deferred()

func _view(card: Dictionary, up := true) -> CardView:
	var v := CardView.new()
	root.add_child(v)
	v.setup_card(card, up)
	return v

func _go() -> void:
	root.size = Vector2i(720, 1280)
	# ---- every mark
	for enh in CribData.ENHANCEMENTS:
		var v := _view({"rank": 7, "suit": "H", "enh": enh})
		ok(v._mark.visible and v._mark.texture == CardArt.mark(enh), "%s overlay shown" % enh)
		ok(v._mark.texture != null, "%s overlay art exists" % enh)
		ok(v._glow.visible, "%s glow shown" % enh)
		var sb: StyleBoxFlat = v._glow.get_theme_stylebox("panel")
		ok(sb != null and sb.shadow_color.is_equal_approx(CardArt.mark_tint(enh)), "%s glow tint" % enh)
		ok(is_equal_approx(v._face.self_modulate.a, 0.93 if enh == "glass" else 1.0), "%s face opacity" % enh)
		ok(v.as_data().get("enh") == enh, "%s round-trips through as_data" % enh)
		v.set_face_up(false)
		ok(not v._mark.visible and not v._glow.visible, "%s hidden face-down" % enh)
		v.queue_free()
	# ---- reuse: a plain setup() must clear a previous mark and split
	var r := _view({"rank": 5, "suit": "D", "enh": "gilded", "rank2": 9, "suit2": "S"})
	r.setup(2, "C", true)
	ok(not r._mark.visible and not r._glow.visible and not r._split.visible and r.enh == "" and r.rank2 == 0,
		"setup() clears mark and split on a reused view")
	ok(r._face.texture == CardArt.face(2, "C"), "reused view shows the plain face")
	r.queue_free()
	# ---- split: pieces and regions match the web's splitCardEl
	for card in [{"rank": 5, "suit": "H", "rank2": 10, "suit2": "S"}, {"rank": 1, "suit": "C", "rank2": 13},
			{"rank": 12, "suit": "D", "rank2": 3, "suit2": "C", "enh": "lucky"}]:
		var v := _view(card)
		var s2: String = card.get("suit2", card.suit)
		ok(v._face.texture == CardArt.split_frame(), "split uses the split frame")
		var kids := v._split.get_children()
		ok(kids.size() == 6, "split has 4 glyphs + 2 pips (got %d)" % kids.size())
		var want := [  # [rank, suit, x, y, big] in make order; pips follow small glyphs
			[card.rank, card.suit, 5, 7, false], [card.rank2, s2, 54, 76, false],
			[card.rank, card.suit, 6, 34, true], [card.rank2, s2, 42, 52, true]]
		var k := 0
		for w in want:
			var g: TextureRect = kids[k]
			var gs := Vector2(22, 14) if w[4] else Vector2(11, 7)
			var red := 1 if w[1] in ["H", "D"] else 0
			ok(g.texture.region == Rect2((w[0] - 1) * gs.x, red * gs.y, gs.x, gs.y), "glyph region %s" % str(w))
			ok(g.position == Vector2(w[2], w[3]) * 2 and g.size == gs * 2, "glyph placement %s" % str(w))
			k += 1
			if not w[4]:
				var p: TextureRect = kids[k]
				var si := ["S", "H", "C", "D"].find(w[1])
				ok(p.texture.region == Rect2(si * 7, red * 7, 7, 7), "pip region %s" % str(w))
				ok(p.position == Vector2(w[2] + 2, w[3] + 8) * 2, "pip placement %s" % str(w))
				k += 1
		ok(not v._mark.visible and not v._glow.visible, "split cards draw without a mark, as on the web")
		v.queue_free()
	# ---- HandView passes engine card data through
	var h := HandView.new()
	h.size = Vector2(720, 240)
	root.add_child(h)
	var cards := [{"rank": 5, "suit": "H", "enh": "coin"}, {"rank": 2, "suit": "S", "rank2": 8, "suit2": "D"}, {"rank": 9, "suit": "C"}]
	h.set_cards(cards, false)
	for i in cards.size():
		ok(h._views[i].as_data() == cards[i], "hand view %d carries %s" % [i, str(cards[i])])
	await process_frame
	print("card checks %d" % checks)
	var good := fails == 0 and checks > 40
	print("CARDS OK" if good else "CARDS FAILED")
	quit(0 if good else 1)
