class_name CharmIcon
## Charm icons (pass 19): the 32x32 pixel art from tools/make_charms.py, shown
## at its 2x file (64x64) and scaled with nearest filtering so pixels stay crisp.
## Presentation only. The Meldling's own knack (tier 0) has no icon.

const DIR := "res://assets/charms/"
static var _cache := {}


static func path(id: String) -> String:
	return DIR + "charm_%s@2x.png" % id


static func texture(id: String) -> Texture2D:
	if id == "":
		return null
	if not _cache.has(id):
		_cache[id] = load(path(id)) if ResourceLoader.exists(path(id)) else null
	return _cache[id]


static func has(id: String) -> bool:
	return texture(id) != null


## A charm's id from its display name (the round end knows names), or "".
static func id_for(name: String) -> String:
	for c in CribData.CHARMS:
		if c.name == name:
			return c.id
	return ""


## A square TextureRect of `px`, or null when the charm has no icon.
static func make(id: String, px: float) -> TextureRect:
	var t := texture(id)
	if t == null:
		return null
	var r := TextureRect.new()
	r.texture = t
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size = Vector2(px, px)
	r.custom_minimum_size = Vector2(px, px)
	r.set_meta("charm_icon", id)
	return r
