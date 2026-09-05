class_name AudioDirector
extends Node

## Plays the generated music and SFX.
##
## Add as an autoload named `Audio` (Project > Project Settings > Autoload),
## or just add one to your scene -- either way `AudioDirector.instance` works.
##
##   AudioDirector.instance.sfx("card_place")
##   AudioDirector.instance.music("bgm_battle")
##   AudioDirector.instance.sfx_for_action("STRIKE")

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const VOICES := 12

static var instance: AudioDirector

@export var sfx_volume_db: float = -3.0
@export var music_volume_db: float = -10.0
@export var pitch_jitter: float = 0.03   ## keeps repeated taps from sounding machine-gunned

var _voices: Array[AudioStreamPlayer] = []
var _voice_i: int = 0
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_active: AudioStreamPlayer
var _current_track: String = ""
var _cache: Dictionary = {}

## Meldlings action name -> sfx file
const ACTION_SFX := {
	"BRACE": "meld_brace",
	"PREP": "meld_prep",
	"STRIKE": "meld_strike",
	"RALLY": "meld_rally",
	"GRAND MELD": "meld_grand",
}


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.volume_db = sfx_volume_db
		add_child(p)
		_voices.append(p)

	_music_a = AudioStreamPlayer.new()
	_music_b = AudioStreamPlayer.new()
	for m in [_music_a, _music_b]:
		m.volume_db = -80.0
		add_child(m)
	_music_active = _music_a


func _load(path: String) -> AudioStream:
	if not _cache.has(path):
		if not ResourceLoader.exists(path):
			push_warning("AudioDirector: missing stream %s" % path)
			_cache[path] = null
		else:
			_cache[path] = load(path)
	return _cache[path]


# ------------------------------------------------------------------ sfx
func sfx(name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var stream := _load(SFX_DIR + name + ".wav")
	if stream == null:
		return
	var p := _voices[_voice_i]
	_voice_i = (_voice_i + 1) % VOICES
	p.stream = stream
	p.volume_db = sfx_volume_db + volume_db
	p.pitch_scale = pitch + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


## Convenience: fire the right sting for a meld verdict's action name.
func sfx_for_action(action: String) -> void:
	if ACTION_SFX.has(action):
		sfx(ACTION_SFX[action])


# ------------------------------------------------------------------ music
func music(track: String, fade: float = 1.2) -> void:
	if track == _current_track and _music_active.playing:
		return
	var stream := _load(MUSIC_DIR + track + ".ogg")
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		stream.loop = true

	var incoming: AudioStreamPlayer = _music_b if _music_active == _music_a else _music_a
	var outgoing: AudioStreamPlayer = _music_active

	incoming.stream = stream
	incoming.volume_db = -80.0
	incoming.play()

	var tw := create_tween().set_parallel(true)
	tw.tween_property(incoming, "volume_db", music_volume_db, fade)
	if outgoing.playing:
		tw.tween_property(outgoing, "volume_db", -80.0, fade)
		tw.chain().tween_callback(outgoing.stop)

	_music_active = incoming
	_current_track = track


func stop_music(fade: float = 0.8) -> void:
	if not _music_active.playing:
		return
	var tw := create_tween()
	tw.tween_property(_music_active, "volume_db", -80.0, fade)
	tw.tween_callback(_music_active.stop)
	_current_track = ""


func duck(amount_db: float = -8.0, time: float = 0.25, hold: float = 0.8) -> void:
	"""Dip the music briefly, e.g. under a boss intro or a GRAND MELD."""
	var tw := create_tween()
	tw.tween_property(_music_active, "volume_db", music_volume_db + amount_db, time)
	tw.tween_interval(hold)
	tw.tween_property(_music_active, "volume_db", music_volume_db, time * 2.0)
