class_name Juice
extends Control
## Particles and screen shake, presentation only. Add one over a screen (full
## rect, ignores input); burst() and shake() are fire-and-forget. Draws its own
## particles (no nodes per particle) and shakes `target` (default: its parent)
## with a decaying offset. Its own RandomNumberGenerator: never JS.unseeded.
## MeldSprite.reduce_motion: no particles, no shake (counted, so tests see the
## event happened and was skipped).

const GRAVITY := 900.0
const COLORS := {"gold": Color(1.0, 0.82, 0.33), "white": Color(1, 1, 0.95), "green": Color(0.43, 0.85, 0.55),
	"red": Color(1.0, 0.42, 0.36), "blue": Color(0.5, 0.75, 1.0)}

var bursts := 0          ## burst() calls (tests)
var shakes := 0          ## shake() calls (tests)
var target: Control = null
var _parts: Array = []   ## [pos, vel, life, max_life, color, size]
var _shake := 0.0
var _shake_t := 0.0
var _shake_len := 0.0
var _base := Vector2.ZERO
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = 29          # presentation randomness: fixed, never the game's


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if target == null:
		target = get_parent() as Control


## `count` particles from `at` (local to this node), in the named colours.
func burst(at: Vector2, count: int, colors: Array = ["gold", "white"]) -> void:
	bursts += 1
	if MeldSprite.reduce_motion:
		return
	for i in count:
		var a := _rng.randf_range(-PI, 0.0) + _rng.randf_range(-0.35, 0.35)
		var sp := _rng.randf_range(240.0, 620.0)
		var life := _rng.randf_range(0.55, 1.05)
		var col: Color = COLORS.get(colors[i % colors.size()], Color.WHITE)
		_parts.append([at, Vector2(cos(a), sin(a)) * sp, life, life, col, _rng.randf_range(4.0, 9.0)])
	queue_redraw()


## Shake `target` by up to `strength` px for `ms`, decaying.
func shake(strength: float, ms: float) -> void:
	shakes += 1
	if MeldSprite.reduce_motion or target == null:
		return
	if _shake_t <= 0.0:
		_base = target.position
	_shake = maxf(_shake, strength)
	_shake_len = maxf(_shake_t, ms / 1000.0)
	_shake_t = _shake_len


func live() -> int:
	return _parts.size()


func shaking() -> bool:
	return _shake_t > 0.0


func _process(delta: float) -> void:
	step(delta)


func step(dt: float) -> void:
	if not _parts.is_empty():
		var keep := []
		for p in _parts:
			p[2] -= dt
			if p[2] > 0.0:
				p[1].y += GRAVITY * dt
				p[0] += p[1] * dt
				keep.append(p)
		_parts = keep
		queue_redraw()
	if _shake_t > 0.0 and target != null:
		_shake_t -= dt
		if _shake_t <= 0.0:
			target.position = _base
			_shake = 0.0
		else:
			var k := _shake * (_shake_t / maxf(0.001, _shake_len))
			target.position = _base + Vector2(_rng.randf_range(-k, k), _rng.randf_range(-k, k))


func _draw() -> void:
	for p in _parts:
		var a: float = clampf(p[2] / p[3], 0.0, 1.0)
		var c: Color = p[4]
		c.a = a
		var s: float = p[5] * (0.5 + 0.5 * a)
		draw_rect(Rect2(p[0] - Vector2(s, s) / 2.0, Vector2(s, s)), c)
