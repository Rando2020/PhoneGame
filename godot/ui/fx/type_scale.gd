class_name TypeScale
## Every font size in ui/ passes through px(): Apple's floor is 11 pt, which is
## 20 px on the 720-px canvas (1 pt = 1.85 px). Sizes under 22 are lifted onto
## 20..22 keeping their order (14 -> 20, 18 -> 21, 22 -> 22); 22 and up are kept.
## Then the player's text size (Settings, "Text size") scales everything: the
## in-game stand-in for Dynamic Type, which Godot 4.3 can't read on iOS without a
## native plugin (docs/PORT.md). Presentation only.

const MIN_PX := 20
const STEPS := [1.0, 1.15, 1.3]     ## Settings choices: Standard, Large, Larger
static var scale := 1.0


static func px(n: int) -> int:
	var lifted := float(n)
	if n < 22:
		lifted = MIN_PX + clampf(float(n - 14), 0.0, 8.0) / 4.0
	return maxi(MIN_PX, roundi(lifted * scale))


## The size an unstyled Label falls back to (Godot's default is 16 px).
static func apply_fallback() -> void:
	ThemeDB.fallback_font_size = px(20)
