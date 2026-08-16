class_name GameRoot
extends Control

## Entry point. Owns the shared services (audio, card animator, run state) and
## swaps screens with a fade. Set scenes/Game.tscn as the project's main scene.

static var instance: GameRoot

var audio: AudioDirector
var anim: CardAnimator
var run: RunState

var _screen: Screen
var _holder: Control
var _fade: ColorRect
var _busy: bool = false


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	SaveManager.load_game()

	add_child(UIKit.background())

	_holder = Control.new()
	_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	_holder.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_holder)

	audio = AudioDirector.new()
	add_child(audio)
	apply_volumes()

	anim = CardAnimator.new()
	add_child(anim)

	_fade = ColorRect.new()
	_fade.color = Color(0.03, 0.03, 0.06, 1.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.z_index = 200
	add_child(_fade)

	run = RunState.new()
	_scale_cards_to_viewport()
	goto("title")


func apply_volumes() -> void:
	audio.music_volume_db = linear_to_db(maxf(0.0001, SaveManager.music_volume)) - 6.0
	audio.sfx_volume_db = linear_to_db(maxf(0.0001, SaveManager.sfx_volume)) - 3.0


func _scale_cards_to_viewport() -> void:
	## Cards are 70px wide at 1x. Pick a scale that keeps a full hand tappable.
	var w: float = get_viewport_rect().size.x
	CardView.PIXEL_SCALE = 3 if w >= 900 else (2 if w >= 480 else 1)


# ------------------------------------------------------------------ navigation
func goto(id: String, args: Dictionary = {}) -> void:
	if _busy:
		return
	_busy = true

	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.18)
	await tw.finished

	if _screen and is_instance_valid(_screen):
		_screen.on_hidden()
		_screen.queue_free()
		await get_tree().process_frame

	_screen = _make(id)
	if _screen == null:
		push_error("GameRoot: unknown screen '%s'" % id)
		_busy = false
		return
	for k in args:
		_screen.set(k, args[k])
	_holder.add_child(_screen)
	_screen.setup(self)
	_screen.build()

	var tw2 := create_tween()
	tw2.tween_property(_fade, "color:a", 0.0, 0.22)
	await tw2.finished
	_screen.on_shown()
	_busy = false


func _make(id: String) -> Screen:
	match id:
		"title": return TitleScreen.new()
		"select": return SelectScreen.new()
		"map": return MapScreen.new()
		"battle": return BattleScreen.new()
		"reward": return RewardScreen.new()
		"rest": return RestScreen.new()
		"gameover": return GameOverScreen.new()
		"options": return OptionsScreen.new()
	return null


# ------------------------------------------------------------------ run flow
func start_run(meldling: String) -> void:
	run.start(meldling)
	goto("map")


func enter_node() -> void:
	var node := run.current_node()
	var t: int = node.get("type", RunState.NodeType.BATTLE)
	match t:
		RunState.NodeType.REST:
			goto("rest")
		RunState.NodeType.TREASURE:
			goto("reward", {"treasure": true})
		_:
			run.current_enemy = node.get("enemy", "deadwood")
			goto("battle")


func finish_battle(victory: bool) -> void:
	if victory:
		var node := run.current_node()
		var reward: int = 12 if node.get("type", 0) == RunState.NodeType.BATTLE else 25
		run.essence_earned += reward
		run.heal(run.relic_value("heal_after"))
		if node.get("type", 0) == RunState.NodeType.BOSS:
			run.last_result = "victory"
			goto("gameover")
		else:
			goto("reward")
	else:
		run.last_result = "defeat"
		goto("gameover")


func end_run() -> void:
	SaveManager.add_essence(run.essence_earned)
	goto("title")


func _shortcut_quit() -> void:
	SaveManager.save_game()
	get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			var w := DisplayServer.window_get_mode()
			DisplayServer.window_set_mode(
				DisplayServer.WINDOW_MODE_WINDOWED if w == DisplayServer.WINDOW_MODE_FULLSCREEN
				else DisplayServer.WINDOW_MODE_FULLSCREEN)
