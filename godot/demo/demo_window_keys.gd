extends Node
## F11 toggles full screen. Decision 0196 (the Windows demo build).
##
## The Windows demo build opens maximized (`display/window/size/mode.demo_build` in project.godot);
## this lets the player go full screen and back. It is read in `_input`, ahead of the HUD and the
## demo's own controls, and consumed. F11 is bound to nothing in the project's input map; Alt+Enter,
## the other usual toggle, is not used because the map binds it to `brush_erase` (UI 1.1 section 5).
## The HUD lays out against the actual viewport (window/stretch/mode="disabled"), so it follows the
## new size by itself.

const FULLSCREEN_KEY: Key = KEY_F11


func _input(event: InputEvent) -> void:
	"""Toggle full screen on F11 (pressed, not echoed)."""
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != FULLSCREEN_KEY:
		return
	toggle()
	get_viewport().set_input_as_handled()


static func toggle() -> void:
	"""Full screen from any windowed mode; maximized from full screen."""
	DisplayServer.window_set_mode(next_mode(DisplayServer.window_get_mode()))


static func next_mode(mode: DisplayServer.WindowMode) -> DisplayServer.WindowMode:
	"""The mode F11 switches `mode` to."""
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		return DisplayServer.WINDOW_MODE_MAXIMIZED
	return DisplayServer.WINDOW_MODE_FULLSCREEN
