class_name Screen
extends Control

## Base for every screen. GameRoot instantiates these, calls build(), and fades
## them in. Screens never load each other -- they ask `game` to navigate.

var game: GameRoot


func setup(p_game: GameRoot) -> void:
	game = p_game
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS


## Override: construct the UI. Called once, after setup().
func build() -> void:
	pass


## Override: called after the fade-in completes.
func on_shown() -> void:
	pass


## Override: called before the screen is torn down.
func on_hidden() -> void:
	pass


func audio() -> AudioDirector:
	return game.audio


func run() -> RunState:
	return game.run
