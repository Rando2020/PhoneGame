extends SceneTree
## Renders every card treatment for a by-eye check (needs xvfb-run).
func _initialize() -> void:
	_go.call_deferred()

func _go() -> void:
	root.size = Vector2i(720, 1280)
	var bg := ColorRect.new()
	bg.color = Color(0.102, 0.094, 0.149)
	bg.size = Vector2(720, 1280)
	root.add_child(bg)
	var cards := [
		[{"rank": 7, "suit": "H"}, true], [{"rank": 12, "suit": "S"}, true],
		[{"rank": 5, "suit": "D", "enh": "gilded"}, true], [{"rank": 9, "suit": "C", "enh": "glass"}, true],
		[{"rank": 1, "suit": "H", "enh": "chameleon"}, true], [{"rank": 4, "suit": "S", "enh": "steel"}, true],
		[{"rank": 11, "suit": "D", "enh": "coin"}, true], [{"rank": 3, "suit": "C", "enh": "lucky"}, true],
		[{"rank": 5, "suit": "H", "rank2": 10, "suit2": "S"}, true], [{"rank": 1, "suit": "C", "rank2": 13, "suit2": "C"}, true],
		[{"rank": 10, "suit": "D", "rank2": 6, "suit2": "H", "enh": "gilded"}, true], [{"rank": 8, "suit": "S", "enh": "glass"}, false],
	]
	for i in cards.size():
		var v := CardView.new()
		root.add_child(v)
		v.setup_card(cards[i][0], cards[i][1])
		v.position = Vector2(40 + (i % 4) * 166, 60 + (i / 4) * 260)
	for i in 20: await process_frame
	root.get_texture().get_image().save_png("/tmp/gallery.png")
	print("gallery saved")
	quit()
