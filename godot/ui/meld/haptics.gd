class_name Haptics
extends RefCounted
## One place for the phone's buzz, so it fires on the same frame as the visual
## and tests can see it. Only vibrates on a phone.

static var log: Array = []        ## [ms, ...] since the last clear (tests)
static var enabled := true


static func pulse(ms: int) -> void:
	if ms <= 0 or not enabled:
		return
	log.append(ms)
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)
