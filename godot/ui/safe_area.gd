class_name SafeArea
## OS safe area (notch, home indicator) as insets in canvas units.
## Only on phones: on a desktop the "safe area" is the monitor's usable area
## (minus taskbars) in screen coordinates and says nothing about the window.
## Measured under xvfb: a 1280x1024 screen gave a bogus 256 px bottom inset.


## Tests only: a phone's insets (canvas px) to lay out against off-device.
static var simulate := {}


static func insets(ctrl: Control) -> Dictionary:
	if not simulate.is_empty():
		return simulate.duplicate()
	var out := {"top": 0.0, "bottom": 0.0}
	if not OS.has_feature("mobile"):
		return out
	var win := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if win.x <= 0 or win.y <= 0 or safe.size.y <= 0 or safe.size.y > win.y:
		return out
	var k := ctrl.size.y / float(win.y)
	out.top = maxf(0.0, safe.position.y) * k
	out.bottom = maxf(0.0, win.y - safe.end.y) * k
	return out
