class_name Warm
## First-use costs, paid once at startup (behind the launch screen) instead of
## on the first deal: the screens' scenes, all 52 card faces and the back, and
## the Meldling, Spoiler and surface textures, and one hidden build of the
## keep screen and the shop. Loads and builds art only: no
## game state, no JS.unseeded, no sound. Presentation only.

static var done := false
static var keep: PackedScene
static var shop: PackedScene


static func run(host: Node = null) -> void:
	if done:
		return
	done = true
	keep = load("res://scenes/keep_screen.tscn")
	shop = load("res://scenes/shop_screen.tscn")
	for suit in ["S", "H", "C", "D"]:
		for r in range(1, 14):
			CardArt.face(r, suit)
	CardArt.back()
	for id in CribData.DECKS:
		for p in MeldReact.POSES:
			MeldSprite.texture(id, p)
	for dir in ["res://art/spoilers", "res://art/surfaces"]:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".png"):
				load(dir + "/" + f)
	# build one keep screen and one shop (hidden, then freed): their first
	# _ready pays one-time costs (fonts at each size, shaders, sprite setup).
	# _ready builds nodes only; no round starts, no state changes.
	if host != null:
		for sc in [keep, shop]:
			var n: Control = sc.instantiate()
			n.visible = false
			host.add_child(n)
			host.remove_child(n)
			n.free()
