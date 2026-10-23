class_name MeldSprite
extends Control
## One Meldling on screen. Idle by default; react(pose) plays a reaction that
## holds (MeldReact.HOLD) and returns to idle. Motion is code-driven and
## interruptible: an idle bob, and a per-axis spring on scale that a reaction
## kicks (squash on land, then pop back). Critically damped (damping 1.0,
## response 0.35 s); only cheer and victory get a little bounce (0.6).
## No await, no tweens that outlive the node.
##
## reduce_motion: no bob, no squash; a reaction cross-fades in instead.

static var reduce_motion := false
const RESPONSE := 0.35

var meld := "pip"
var pose := "idle"
var locked := false            ## a silhouette (locked in the picker)
var timer := 0.0               ## seconds left in the current reaction (<= 0 holds)
var reactions := 0             ## reactions played (tests)
var _t := 0.0
var _scale := Vector2.ONE
var _vel := Vector2.ZERO
var _damping := 1.0
var _fade := 1.0
var _tex: TextureRect


func _init(meld_id := "pip") -> void:
	meld = MeldReact.art_id(meld_id)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tex = TextureRect.new()
	_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_tex)
	_show()


static func texture(meld_id: String, p: String) -> Texture2D:
	var path := "res://art/meldlings2/%s_%s.png" % [MeldReact.art_id(meld_id), p]
	if not ResourceLoader.exists(path):
		path = "res://art/meldlings2/%s_idle.png" % MeldReact.art_id(meld_id)
	return load(path)


func set_meld(meld_id: String, is_locked := false) -> void:
	meld = MeldReact.art_id(meld_id)
	locked = is_locked
	pose = "idle"
	timer = 0.0
	_show()


func _show() -> void:
	_tex.texture = _texture_for(pose)
	_tex.modulate = Color(0.02, 0.02, 0.05, 0.55) if locked else Color(1, 1, 1, _fade)


## Play a reaction ("" or unknown does nothing). Fires its sound and haptic in
## the same call. quiet: no sound or buzz (a second sprite echoing a beat that
## already played, as the round-end page does).
func react(p: String, quiet := false) -> void:
	if p == "" or locked:
		return
	pose = p
	timer = _hold(p)
	reactions += 1
	_damping = 0.6 if p in ["cheer", "victory"] else 1.0
	if reduce_motion:
		_fade = 0.0           # cross-fade in, no squash
	else:
		_scale = Vector2(1.14, 0.84)   # land: squash, then the spring pops it back
		_vel = Vector2.ZERO
	if not quiet:
		Sound.play(_sound(p))
		Haptics.pulse(_buzz(p))
	_show()


# ---- overridden by SpoilerSprite
func _texture_for(p: String) -> Texture2D:
	return texture(meld, p)


func _hold(p: String) -> float:
	return float(MeldReact.HOLD.get(p, 1.2))


func _buzz(p: String) -> int:
	return int(MeldReact.BUZZ.get(p, 0))


func _sound(p: String) -> String:
	return String(MeldReact.SOUND.get(p, ""))


## The event entry point: MeldReact decides, this plays it.
func on_event(event: String, rd: CribRound = null, res: Dictionary = {}) -> String:
	var p := MeldReact.pose_for(event, meld, rd, res)
	react(p)
	return p


func _process(delta: float) -> void:
	step(delta)


## Advance time (also called directly by tests).
func step(dt: float) -> void:
	_t += dt
	if timer > 0.0:
		timer -= dt
		if timer <= 0.0:
			pose = "idle"
			timer = 0.0
			_show()
	# per-axis spring toward 1 (Apple's damping + response form)
	# fixed substeps: a long frame (a slow phone, a render) can't blow the spring up
	var w := TAU / RESPONSE
	var left := minf(dt, 0.25)
	while left > 0.0:
		var h := minf(left, 1.0 / 240.0)
		var acc := (Vector2.ONE - _scale) * w * w - _vel * 2.0 * _damping * w
		_vel += acc * h
		_scale += _vel * h
		left -= h
	if _fade < 1.0:
		_fade = minf(1.0, _fade + dt / 0.18)
		_tex.modulate.a = _fade
	var bob := 0.0 if reduce_motion or locked else sin(_t * 2.4) * size.y * 0.018
	_tex.pivot_offset = Vector2(size.x / 2.0, size.y)     # squash from the feet
	_tex.scale = Vector2.ONE if reduce_motion else _scale
	_tex.position = Vector2(0, bob)
