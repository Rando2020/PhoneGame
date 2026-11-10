class_name Sound
extends Node
## Every sound in the game, from samples rendered offline by
## tools/make_audio2.py (the web synth's own parameters). Presentation only.
##
##   Sound.play(id, pitch)    a one-shot from a pool of POOL voices (the oldest
##                            is stolen when all are busy); false when muted
##   Sound.music(context)     menu, shop, act1..act5, boss, play, endless:
##                            a 0.6 s crossfade to the new loop
##   Sound.set_muted(b) / Sound.set_volume(v)   saved in the Achv store
## The player node attaches itself to the SceneTree root on first use, and
## pauses everything while the app is in the background.

const POOL := 8
const FADE := 0.6
const PENTA := [0, 2, 4, 7, 9, 12, 14, 16, 19, 21, 24, 26, 28, 31]
const MUSIC := ["menu", "shop", "act1", "act2", "act3", "act4", "act5", "boss", "play", "endless"]

static var _node: Sound = null
static var log: Array = []          ## [id, frame, pitch] per sound actually played (tests)
static var music_ctx := ""
static var _cache := {}

var _voices: Array[AudioStreamPlayer] = []
var _started: Array[int] = []        ## the frame each voice last started (for stealing)
var _music: Array[AudioStreamPlayer] = []
var _front := 0
var paused := false


# ------------------------------------------------------------------ settings
static func muted() -> bool:
	return JS.truthy(Achv.load_store().get("sound_muted"))


static func volume() -> float:
	return float(Achv.load_store().get("sound_volume", 0.85))


static func set_muted(b: bool) -> void:
	var m := Achv.load_store()
	m["sound_muted"] = b
	Achv.save_store(m)
	if _node != null:
		_node._apply_volume()


static func set_volume(v: float) -> void:
	var m := Achv.load_store()
	m["sound_volume"] = clampf(v, 0.0, 1.0)
	Achv.save_store(m)
	if _node != null:
		_node._apply_volume()


# ------------------------------------------------------------------ api
static func node() -> Sound:
	if _node == null or not is_instance_valid(_node):
		var tree := Engine.get_main_loop() as SceneTree
		_node = Sound.new()
		_node.name = "Sound"
		tree.root.add_child.call_deferred(_node)
		_node._build()
	return _node


static func stream(id: String) -> AudioStream:
	if not _cache.has(id):
		var p := "res://audio/sfx/%s.wav" % id
		_cache[id] = load(p) if ResourceLoader.exists(p) else null
	return _cache[id]


static func exists(id: String) -> bool:
	return stream(id) != null


## A one-shot. `pitch` scales playback (semitones: Sound.semi(n)).
static func play(id: String, pitch := 1.0) -> bool:
	if id == "" or muted() or volume() <= 0.0:
		return false
	var s := stream(id)
	if s == null:
		push_warning("Sound: no sound '%s'" % id)
		return false
	var n := node()
	log.append([id, Engine.get_process_frames(), pitch])
	n._play(s, pitch)
	return true


static func semi(n: int) -> float:
	return pow(2.0, n / 12.0)


## The count's tick: pitch climbs the pentatonic ladder with the line's index.
static func tick(kind: String, index: int) -> bool:
	var id := "tick_" + kind
	if not exists(id):
		id = "tick_charm"
	return play(id, semi(PENTA[mini(index, PENTA.size() - 1)]))


static func music(ctx: String) -> void:
	if ctx == music_ctx or not ctx in MUSIC:
		return
	music_ctx = ctx
	node()._crossfade(ctx)


## Clear test state.
static func reset() -> void:
	log.clear()
	music_ctx = ""


# ------------------------------------------------------------------ node
func _build() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_voices.append(p)
		_started.append(-1)
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.volume_db = -80.0
		add_child(p)
		_music.append(p)
	_apply_volume()


func _ready() -> void:
	# music asked for before the node was in the tree starts now
	if music_ctx != "" and not _music[_front].playing:
		_music[_front].play()
		_music[_front].volume_db = linear_to_db(maxf(0.0 if Sound.muted() else Sound.volume() * 0.7, 0.0001))


func voices_busy() -> int:
	var n := 0
	for i in _voices.size():
		if _voices[i].playing or _started[i] == Engine.get_process_frames():
			n += 1
	return n


func _play(s: AudioStream, pitch: float) -> void:
	var pick := -1
	for i in _voices.size():
		if not _voices[i].playing and _started[i] != Engine.get_process_frames():
			pick = i
			break
	if pick < 0:                     # all busy: steal the oldest
		pick = 0
		for i in _voices.size():
			if _started[i] < _started[pick]:
				pick = i
	var p := _voices[pick]
	p.stream = s
	p.pitch_scale = clampf(pitch, 0.25, 4.0)
	_started[pick] = Engine.get_process_frames()
	if p.is_inside_tree():
		p.play()


func _apply_volume() -> void:
	var v := 0.0 if Sound.muted() else Sound.volume()
	var db := linear_to_db(maxf(v, 0.0001))
	for p in _voices:
		p.volume_db = db
	for i in _music.size():
		if i == _front and music_ctx != "":
			_music[i].volume_db = linear_to_db(maxf(v * 0.7, 0.0001))


func _crossfade(ctx: String) -> void:
	var p := "res://audio/music/%s.ogg" % ctx
	if not ResourceLoader.exists(p):
		return
	var s: AudioStream = load(p)
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	var old := _music[_front]
	_front = 1 - _front
	var nu := _music[_front]
	nu.stream = s
	nu.volume_db = -60.0
	var v := 0.0 if Sound.muted() else Sound.volume() * 0.7
	if nu.is_inside_tree():
		nu.play()
	var tw := create_tween() if is_inside_tree() else null
	if tw == null:
		nu.volume_db = linear_to_db(maxf(v, 0.0001))
		old.stop()
		return
	tw.set_parallel(true)
	tw.tween_property(nu, "volume_db", linear_to_db(maxf(v, 0.0001)), FADE)
	tw.tween_property(old, "volume_db", -60.0, FADE)
	tw.chain().tween_callback(old.stop)


## The app went to the background (or came back): pause everything.
func set_app_paused(b: bool) -> void:
	paused = b
	for p in _voices + _music:
		p.stream_paused = b


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			set_app_paused(true)
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			set_app_paused(false)
