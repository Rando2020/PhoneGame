extends SceneTree
## Dynamic Type and Reduce Motion from iOS (audit #9, #10), through the native
## plugin hook. Godot 4.3 can't read either setting, so the plugin (docs/PORT.md)
## is the only route; here a stand-in singleton plays the plugin. Checks: with
## no plugin, the in-game defaults; with it, the phone's settings are followed
## until the player picks their own in Settings; a change in iOS Settings
## (the plugin's `changed` signal) applies at once; every UIKit size category
## maps onto a step in order.
##   godot --headless --path godot --script res://tests/os_access_test.gd
var checks := 0
var fails := 0


class FakeAccess extends Object:
	signal changed
	var motion := false
	var category := "UICTContentSizeCategoryL"
	func reduce_motion() -> bool:
		return motion
	func content_size() -> String:
		return category


func ok(c: bool, m: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("FAIL ", m)


func _initialize() -> void:
	Achv.persist = false
	# no plugin: the in-game defaults
	Achv.save_store({"__v": 3})
	Menus.apply()
	ok(not MeldSprite.reduce_motion and TypeScale.scale == 1.0, "no plugin: not the defaults")
	# the categories, in order
	var cats := ["XS", "S", "M", "L", "XL", "XXL", "XXXL", "AccessibilityM", "AccessibilityXXXL"]
	var steps := cats.map(func(c): return Menus.text_step_for("UICTContentSizeCategory" + c))
	ok(steps == [0, 0, 0, 0, 1, 1, 2, 2, 2], "category steps %s" % [steps])
	# with the plugin: the phone's settings
	var fa := FakeAccess.new()
	fa.motion = true
	fa.category = "UICTContentSizeCategoryXXL"
	Engine.register_singleton("MeldAccess", fa)
	Menus.apply()
	ok(MeldSprite.reduce_motion, "phone's Reduce Motion not followed")
	ok(TypeScale.scale == TypeScale.STEPS[1], "phone's XXL not Large (%.2f)" % TypeScale.scale)
	ok(ThemeDB.fallback_font_size == TypeScale.px(20), "fallback size not rescaled")
	# a change in iOS Settings applies at once
	fa.motion = false
	fa.category = "UICTContentSizeCategoryAccessibilityL"
	fa.changed.emit()
	ok(not MeldSprite.reduce_motion and TypeScale.scale == TypeScale.STEPS[2], "iOS change not applied (%s, %.2f)" % [MeldSprite.reduce_motion, TypeScale.scale])
	# the player's own choice wins over the phone
	Achv.save_store({"__v": 3, "reduce_motion": true, "text_scale": 0})
	Menus.apply()
	ok(MeldSprite.reduce_motion and TypeScale.scale == 1.0, "saved choice didn't win")
	fa.changed.emit()
	ok(MeldSprite.reduce_motion and TypeScale.scale == 1.0, "an iOS change overrode the saved choice")
	Engine.unregister_singleton("MeldAccess")
	fa.free()
	MeldSprite.reduce_motion = false
	TypeScale.scale = 1.0
	print("os_access_test: %d checks, %d fails" % [checks, fails])
	quit(1 if fails > 0 else 0)
