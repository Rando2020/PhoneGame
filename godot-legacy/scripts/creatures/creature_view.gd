class_name CreatureView
extends Control

## Plays the generated creature sprite strips.
## Frame size and frame count are inferred from the strip (square frames),
## so adding a creature to the roster needs no code change here.
##
##   var c := CreatureView.new()
##   add_child(c)
##   c.setup("pip")
##   await c.play_once("attack")
##   c.play("idle")

signal animation_finished(anim: String)

const DIR := "res://assets/meldlings/"
const FPS := {"idle": 7.0, "attack": 13.0, "hurt": 14.0}

@export var pixel_scale: int = 5
@export var flip_h: bool = false

var creature: String = "pip"
var anim: String = "idle"

var _rect: TextureRect
var _atlas: AtlasTexture
var _tex: Texture2D
var _frames: int = 1
var _frame_size: int = 32
var _t: float = 0.0
var _frame: int = 0
var _looping: bool = true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect = TextureRect.new()
	_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)
	_load_anim(anim)


func setup(p_creature: String, p_anim: String = "idle") -> CreatureView:
	creature = p_creature
	anim = p_anim
	if is_node_ready():
		_load_anim(anim)
	return self


func play(p_anim: String) -> void:
	if anim == p_anim and _looping:
		return
	_looping = true
	_load_anim(p_anim)


func play_once(p_anim: String) -> Signal:
	_looping = false
	_load_anim(p_anim)
	return animation_finished


func _load_anim(p_anim: String) -> void:
	var path := DIR + "%s_%s.png" % [creature, p_anim]
	if not ResourceLoader.exists(path):
		push_warning("CreatureView: missing %s" % path)
		return
	anim = p_anim
	_tex = load(path)
	_frame_size = _tex.get_height()
	_frames = maxi(1, _tex.get_width() / _frame_size)
	_frame = 0
	_t = 0.0

	_atlas = AtlasTexture.new()
	_atlas.atlas = _tex
	_atlas.region = Rect2(0, 0, _frame_size, _frame_size)
	_rect.texture = _atlas
	_rect.flip_h = flip_h

	custom_minimum_size = Vector2(_frame_size, _frame_size) * pixel_scale
	size = custom_minimum_size
	set_process(true)


func _process(delta: float) -> void:
	if _atlas == null or _frames <= 1:
		return
	var fps: float = FPS.get(anim, 8.0)
	_t += delta
	if _t < 1.0 / fps:
		return
	_t = 0.0
	_frame += 1
	if _frame >= _frames:
		if _looping:
			_frame = 0
		else:
			_frame = _frames - 1
			set_process(false)
			animation_finished.emit(anim)
			# settle back into idle automatically
			_looping = true
			_load_anim("idle")
			return
	_atlas.region = Rect2(_frame * _frame_size, 0, _frame_size, _frame_size)


## Convenience: take a hit, then return to idle.
func hurt() -> void:
	play_once("hurt")


func attack() -> void:
	play_once("attack")
