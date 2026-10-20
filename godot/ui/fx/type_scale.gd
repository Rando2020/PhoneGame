class_name TypeScale
## Every font size in ui/ passes through px(): Apple's floor is 11 pt, which is
## 20 px on the 720-px canvas (1 pt = 1.85 px). Sizes under 22 are lifted onto
## 20..22 keeping their order (14 -> 20, 18 -> 21, 22 -> 22); 22 and up are kept.
## Then the player's text size (Settings, "Text size") scales everything: the
## in-game stand-in for Dynamic Type, which Godot 4.3 can't read on iOS without a
## native plugin (docs/PORT.md). Presentation only.

const MIN_PX := 20
const BODY := 31                    ## reading text: 17 pt, Apple's body size
const STEPS := [1.0, 1.15, 1.3]     ## Settings choices: Standard, Large, Larger
static var scale := 1.0


static func px(n: int) -> int:
	var lifted := float(n)
	if n < 22:
		lifted = MIN_PX + clampf(float(n - 14), 0.0, 8.0) / 4.0
	return maxi(MIN_PX, roundi(lifted * scale))


## Every font size in ui/ is set here, so the base size stays on the node and
## a Text size change (Settings or iOS) can restyle a screen already built.
static func set_size(c: Control, n: int) -> void:
	c.set_meta("fs_base", n)
	c.add_theme_font_size_override("font_size", px(n))


## A Text size change, live: restyle every sized control under `root`, then
## send the resize notice every screen already re-lays out on (one node at a
## time over a snapshot; propagate_notification would walk children a rebuild
## is removing).
static func relayout(root: Node) -> void:
	apply_fallback()
	if root == null:
		return
	var all := root.find_children("*", "Control", true, false)
	for c in all:
		if c.has_meta("fs_base"):
			(c as Control).add_theme_font_size_override("font_size", px(int(c.get_meta("fs_base"))))
	# parents first (find_children is depth-first): a screen that rebuilds drops
	# its old children from the tree, and those are skipped
	for c in all:
		if is_instance_valid(c) and c.is_inside_tree():
			c.notification(Control.NOTIFICATION_RESIZED)


## What a screen was last drawn for: its size and the text scale. A resize
## notice redraws only when this changed (opening a screen sends one for the
## size it was already drawn at; a Text size change changes the scale).
static func layout_key(c: Control) -> Vector3:
	return Vector3(c.size.x, c.size.y, scale)


## The size an unstyled Label falls back to (Godot's default is 16 px).
static func apply_fallback() -> void:
	ThemeDB.fallback_font_size = px(20)
