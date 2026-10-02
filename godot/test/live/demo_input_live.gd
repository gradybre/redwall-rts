extends SceneTree
## The live demo's input, menu and keyboard checks on the REAL scene with REAL Viewport input (decision
## 0261; review F26, F29, F30, F50). Not discovered by the runner (it is not `test_*.gd` in test/): the
## suite runs it in its own process from test/test_demo_input_live.gd, because the runner's worker runs
## every suite inside `_initialize`, before the root is in the tree, where no Viewport can dispatch input.
##
##     godot --headless --path godot --script res://test/live/demo_input_live.gd [-- --size 1920x1080]
##         [-- --capture <dir>]   (not headless: saves the checked frames as PNGs)
##
## It boots demo/demo_village.tscn (on placeholders when the assets are not staged), then each step pushes
## events through `root.push_input` -- the path a real click or key takes: `_input`, the GUI, the
## unhandled passes -- and checks what the village did. Prints `LIVE <name>: PASS|FAIL <detail>` per check
## and `LIVE-SUMMARY <checks> <failures>`; exits 1 on any failure.

## The HUD shell's element ids, read from its script at run time: it names the GameManager autoload, which
## a main-loop script cannot preload (autoload globals are not registered when it compiles).
const SHELL_PATH: String = "res://scripts/ui/ui_shell.gd"
const GateScript := preload("res://demo/ui/demo_input_gate.gd")
const MenuScript := preload("res://demo/ui/demo_menu.gd")
const ZoneScript := preload("res://demo/ui/demo_detail_zone.gd")
const TunnelPanel := preload("res://demo/tunnel/tunnel_panel.gd")
const ForestPanel := preload("res://demo/forestry/forest_panel.gd")
const WaterPanel := preload("res://demo/waterplay/water_panel.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const PlaytestLog := preload("res://demo/playtest/playtest_log.gd")

## Frames to let the village boot (its prewarm releases the clock after its first frames).
const BOOT_FRAMES: int = 12
## Frames between steps (a deferred placement or a queued free lands in between).
const STEP_FRAMES: int = 2
## Every label a test trigger had in the player panels (review F50).
const TRIGGER_WORDS: Array[String] = ["Next weather", "Test event", "Storm gust", "Cramp"]

var _village: Node = null
var _frames: int = 0
var _wait: int = BOOT_FRAMES
var _steps: Array[Callable] = []
var _checks: int = 0
var _failures: int = 0
var _size: Vector2i = Vector2i(1280, 720)
var _capture_dir: String = ""
var _order_before: int = 0
var _ids: Dictionary = {}
var _pending_capture: String = ""
var _restart_checked_hold: bool = false
## The playtest log's node and file as first seen (decision 0562): the same after a restart.
var _playtest_node: Node = null
var _playtest_file: String = ""


func _initialize() -> void:
	"""Read the arguments, size the window, boot the village and list the steps."""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for k: int in args.size() - 1:
		if args[k] == "--size":
			var parts: PackedStringArray = args[k + 1].split("x")
			_size = Vector2i(int(parts[0]), int(parts[1]))
		elif args[k] == "--capture":
			_capture_dir = args[k + 1]
	root.size = _size
	_ids = (load(SHELL_PATH) as GDScript).get_script_constant_map()
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(_size)
	_village = (load("res://demo/demo_village.tscn") as PackedScene).instantiate()
	root.add_child(_village)
	current_scene = _village
	_steps = [_pantry_opens_as_a_modal, _pantry_blocks_the_world, _pantry_traps_tab, _pantry_escape_returns,
		_escape_ladder_ends_in_the_menu, _menu_button_opens_the_menu, _menu_pages_and_escape, _menu_controls_back,
		_menu_restores_speed, _menu_confirms_restart_and_quit, _confirm_cancel_and_quit,
		_settings_offer_what_works, _settings_fit_and_sound, _settings_close, _playtest_opens_the_menu, _playtest_presses_f12, _playtest_marked, _sound_really_plays, _f7_and_tab_reach_every_panel_button, _focus_ring_off,
		_f7_reaches_the_left_column_then_the_world, _enter_and_space_route_by_focus, _enter_goes_to_the_dig_tool,
		_lab_holds_the_triggers, _lab_fires_and_panels_are_clean, _lab_from_the_menu, _history_click_does_not_leak,
		_a_click_gives_the_arrows_back, _the_banner_over_the_lab, _the_banner_takes_enter,
		_the_hud_workspace_keeps_the_keys, _the_workspace_covers_no_stop, _a_group_is_box_selected,
		_a_member_row_selects_and_centres, _a_water_action_without_scrolling, _the_picker_opens_on_bed_1,
		_the_picker_crosses_spring_5, _jobs_opens_the_work_screen, _work_tab_and_enter, _work_queue_a_fell,
		_work_show_the_fell, _work_open_the_picker, _work_show_the_target, _work_reassign_by_click, _work_show_residents, _work_scroll_to_resident, _work_edit_a_crew, _work_cancel_all_shows_its_scope,
		_work_keep_working, _work_closes_on_j, _shift_right_click_queues,
		_scale_follows_the_choice, _work_at_the_chosen_scale, _work_close_scaled,
		_restart_boots_again, _after_restart, _playtest_survives_the_restart, _playtest_presses_f12, _playtest_marked_again,
		_a_smaller_window_steps_the_scale_down]


func _process(_delta: float) -> bool:
	"""Run one step each time the wait runs out; quit after the last. The headless display server sizes the
	root to 64x64 on the first frame, so the size is held here."""
	_frames += 1
	if root.size != _size:
		root.size = _size
	_wait -= 1
	if _wait > 0:
		return false
	if _steps.is_empty():
		print("LIVE-SUMMARY %d %d" % [_checks, _failures])
		quit(1 if _failures > 0 else 0)
		return false
	if not _pending_capture.is_empty():
		_save_capture()
	var step: Callable = _steps.pop_front()
	step.call()
	_wait = STEP_FRAMES
	return false


# --- helpers ----------------------------------------------------------------------------------------

func _check(check_name: String, ok: bool, detail: String = "") -> void:
	"""Record one check."""
	_checks += 1
	if not ok:
		_failures += 1
	print("LIVE %s: %s %s" % [check_name, "PASS" if ok else "FAIL", detail])


func _key(code: Key, shift: bool = false) -> void:
	"""Press and release one key through the Viewport."""
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.shift_pressed = shift
		event.pressed = down
		root.push_input(event)


func _click(at: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT, shift: bool = false) -> void:
	"""Press and release a mouse button at `at` (with Shift held when `shift`)."""
	var motion := InputEventMouseMotion.new()
	motion.position = at
	root.push_input(motion)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = button
		event.position = at
		event.shift_pressed = shift
		event.pressed = down
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down and button == MOUSE_BUTTON_LEFT else 0
		root.push_input(event)


func _drag(from: Vector2, to: Vector2) -> void:
	"""A left drag from `from` to `to` in four moves."""
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = from
	press.pressed = true
	root.push_input(press)
	for k: int in range(1, 5):
		var motion := InputEventMouseMotion.new()
		motion.position = from.lerp(to, float(k) / 4.0)
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(motion)
	var release := press.duplicate() as InputEventMouseButton
	release.position = to
	release.pressed = false
	root.push_input(release)


func _centre(control: Control) -> Vector2:
	"""A control's centre on screen."""
	return control.get_global_transform_with_canvas() * (control.size / 2.0)


func _gate() -> GateScript:
	"""The village's input gate."""
	return _village.call(&"input_gate")


func _menu() -> MenuScript:
	"""The village's game menu."""
	return _village.call(&"menu")


func _command() -> Node:
	"""The demo's command layer."""
	return _village.get("_command")


func _brain(i: int) -> Object:
	"""Resident `i`'s brain."""
	return _village.get("_cast").call(&"actor", i).get("brain")


func _pantry() -> CanvasLayer:
	"""The farm's Pantry panel."""
	return _village.get("_farm").get("pantry_panel")


func _shell() -> Control:
	"""The HUD shell."""
	return _village.call(&"_shell")


func _shell_control(id_name: String) -> Control:
	"""A HUD element by its shell constant's name (ID_MENU, ...)."""
	return _shell().call(&"control_for", int(_ids[id_name]))


func _focus() -> Control:
	"""The focus owner."""
	return root.gui_get_focus_owner()


func _manager() -> Object:
	"""The GameManager autoload."""
	return root.get_node(^"GameManager")


## A point on open ground, left of centre and below the HUD's top row -- outside any centred pop-up.
func _world_point() -> Vector2:
	"""Open world, outside the modal rectangle's frame and the side columns."""
	return Vector2(float(_size.x) * 0.5, float(_size.y) * 0.93)


func _capture(file_name: String) -> void:
	"""Save this state's frame once it is drawn -- at the next step, so a step that captures ends there (only
	when asked for, and never headless)."""
	if not _capture_dir.is_empty() and DisplayServer.get_name() != "headless":
		_pending_capture = file_name


func _save_capture() -> void:
	"""Write the pending frame, and forgive the clock the time the read-back took (a slow frame would
	otherwise put the clock into its overload pause and the stall banner over the next checks)."""
	root.get_texture().get_image().save_png(_capture_dir.path_join("%s_%dx%d.png" % [_pending_capture, _size.x, _size.y]))
	_pending_capture = ""
	_manager().set("_last_host_usec", Time.get_ticks_usec())


# --- F26: the Pantry owns input -----------------------------------------------------------------

func _pantry_opens_as_a_modal() -> void:
	"""K opens the Pantry over a scrim, with focus inside it."""
	_command().call(&"select", PackedInt32Array([0]))
	_order_before = int(_brain(0).get("order"))
	_key(KEY_K)
	_check("pantry opens on K", _pantry().visible)
	_check("pantry is the top modal", _gate().top_layer() == _pantry())
	var scrim: ColorRect = _gate().scrim_of(_pantry())
	_check("pantry has a scrim over the whole view", scrim != null and scrim.get_global_rect().size.x >= float(_size.x) - 1.0, str(scrim.get_global_rect()) if scrim else "none")
	_check("focus lands inside the pantry", _gate().in_top_modal(_focus()), str(_focus()))
	_check("opened by a key, its focus is drawn", _focus() != null and _focus().has_focus(true))
	_check("on its content, not its ×", _focus() != _pantry().call(&"close_button"))
	_capture("pantry_open")


func _pantry_blocks_the_world() -> void:
	"""An outside right-click, a drag, B, V and Space change nothing behind the Pantry."""
	var was_paused: bool = bool(_manager().call(&"is_paused"))
	_click(_world_point(), MOUSE_BUTTON_RIGHT)
	_check("outside right-click issues no order", int(_brain(0).get("order")) == _order_before,
		"order %d" % int(_brain(0).get("order")))
	_drag(Vector2(10.0, float(_size.y) * 0.9), Vector2(float(_size.x) - 10.0, float(_size.y) * 0.98))
	_check("a drag does not box-select", _command().call(&"selected") == PackedInt32Array([0]))
	var overlay: int = int(_village.get("_farm").get("lenses").get("active"))
	_key(KEY_B)
	_key(KEY_V)
	_key(KEY_SPACE)
	_check("B does not open the Dig tool", not bool(_command().call(&"tunnels").get("planning")))
	_check("V does not step the map layer", int(_village.get("_farm").get("lenses").get("active")) == overlay)
	_check("Space does not toggle the pause", bool(_manager().call(&"is_paused")) == was_paused)
	var camera: Node = _village.get("_camera")
	var distance: float = float(camera.get("_target_distance"))
	_key(KEY_PAGEUP)
	_check("Page Up does not zoom the camera behind it", is_equal_approx(float(camera.get("_target_distance")), distance))
	var down := InputEventKey.new()
	down.keycode = KEY_LEFT
	down.pressed = true
	root.push_input(down)
	_check("an arrow does not pan the camera behind it", not (camera.get("_held") as PackedByteArray).has(1))
	down.pressed = false
	root.push_input(down)
	_check("the pantry is still open", _pantry().visible)


func _pantry_traps_tab() -> void:
	"""Tab and Shift+Tab stay inside the Pantry."""
	var first: Control = _focus()
	_key(KEY_TAB)
	var second: Control = _focus()
	_check("Tab moves within the pantry", second != first and _gate().in_top_modal(second), str(second))
	for k: int in 40:
		_key(KEY_TAB)
		if not _gate().in_top_modal(_focus()):
			break
	_check("40 Tabs never leave the pantry", _gate().in_top_modal(_focus()))
	_check("the pantry's focus is the keyboard's (drawn)", _focus() != null and _focus().has_focus(true))
	_key(KEY_TAB, true)
	_check("Shift+Tab stays inside", _gate().in_top_modal(_focus()))


func _pantry_escape_returns() -> void:
	"""Esc closes the Pantry alone: the selection stays, the scrim goes, focus goes back to the world."""
	_key(KEY_ESCAPE)
	_check("Esc closes the pantry", not _pantry().visible)
	_check("the same Esc does not clear the selection", _command().call(&"selection_count") == 1)
	_check("no modal is left", not _gate().modal_open())
	_check("focus returns to the world", _focus() == null, str(_focus()))
	_key(KEY_K)
	_key(KEY_K)
	_check("K opens and K closes the pantry", not _pantry().visible and not _gate().modal_open())
	var zone: ZoneScript = _village.get("_zone")
	_key(KEY_F7)
	_key(KEY_K)
	_check("K opens the pantry from a focused tab", _pantry().visible and _gate().in_top_modal(_focus()))
	_key(KEY_ESCAPE)
	_check("closing it gives the tab its focus back, drawn", _focus() == zone.tab(0) and _focus().has_focus(true))
	_key(KEY_ESCAPE)


func _escape_ladder_ends_in_the_menu() -> void:
	"""Esc clears the selection, and the next Esc -- nothing left to dismiss -- opens the game menu."""
	_key(KEY_ESCAPE)
	_check("Esc then clears the selection", _command().call(&"selection_count") == 0)
	_check("and does not open the menu", not _menu().visible)
	_key(KEY_ESCAPE)
	_check("the next Esc opens the game menu", _menu().visible)
	_key(KEY_ESCAPE)
	_check("Esc on the menu closes it", not _menu().visible)


# --- F29: the game menu -------------------------------------------------------------------------

func _menu_button_opens_the_menu() -> void:
	"""The HUD's Menu button, clicked, opens the pause menu -- not the New Settlement form."""
	_manager().call(&"set_speed", 2)
	var button: Control = _shell_control("ID_MENU")
	_click(_centre(button))
	_check("Menu opens the game menu", _menu().visible and _menu().page() == MenuScript.PAGE_MENU)
	_check("Menu does not open New Settlement", not _shell_control("ID_NEW_SETTLEMENT").is_visible_in_tree())
	_check("the menu holds the MENU pause", (_manager().call(&"get_pause_reason_names") as Array).has("MENU"))
	_check("the village stops", int(_manager().call(&"get_effective_speed")) == 0)
	_check("the menu says the demo cannot save", _menu().page_text(MenuScript.PAGE_MENU).contains("can't save"))
	_check("focus is on Resume", _focus() == _menu().menu_button(0))
	_check("opened by a click, its focus is not drawn", not _focus().has_focus(true))
	_capture("pause_menu")


func _menu_pages_and_escape() -> void:
	"""Controls and Settings open by keyboard; Esc goes back a page, then closes."""
	_key(KEY_TAB)
	_key(KEY_TAB)
	_key(KEY_ENTER)
	_check("Tab, Tab, Enter opens Controls", _menu().page() == MenuScript.PAGE_CONTROLS)
	_check("Controls lists F7 and F8", _menu().page_text(MenuScript.PAGE_CONTROLS).contains("F7")
		and _menu().page_text(MenuScript.PAGE_CONTROLS).contains("F8"))
	_capture("menu_controls")


func _menu_controls_back() -> void:
	"""Esc from Controls goes back to the menu, focus on Controls."""
	_key(KEY_ESCAPE)
	_check("Esc goes back to the menu", _menu().visible and _menu().page() == MenuScript.PAGE_MENU)
	_check("focus is back on Controls", _focus() == _menu().menu_button(2))


func _menu_restores_speed() -> void:
	"""Closing the menu releases MENU only and restores the 2x it had."""
	_key(KEY_ESCAPE)
	_check("Esc closes the menu", not _menu().visible)
	_check("MENU is released", not (_manager().call(&"get_pause_reason_names") as Array).has("MENU"))
	_check("the 2x speed is back", int(_manager().call(&"get_effective_speed")) == 2)
	_manager().call(&"set_speed", 1)


func _menu_confirms_restart_and_quit() -> void:
	"""Restart and Quit ask first and say the village will be lost; Cancel and Esc go back."""
	_menu().open()
	_menu().menu_button(1).pressed.emit()
	_check("Restart asks first", _menu().page() == MenuScript.PAGE_CONFIRM
		and _menu().page_text(MenuScript.PAGE_CONFIRM).contains("will be lost"))
	_check("focus is on Cancel", _focus() == _menu().cancel_button())
	_capture("menu_confirm")


func _confirm_cancel_and_quit() -> void:
	"""Enter on Cancel goes back; Quit asks too; Esc on its question goes back."""
	_key(KEY_ENTER)
	_check("Enter on Cancel goes back", _menu().page() == MenuScript.PAGE_MENU and _menu().visible)
	_menu().menu_button(5).pressed.emit()
	_check("Quit asks first", _menu().page() == MenuScript.PAGE_CONFIRM
		and _menu().confirm_button().text == "Quit demo")
	_key(KEY_ESCAPE)
	_check("Esc on the question goes back", _menu().page() == MenuScript.PAGE_MENU)


func _settings_offer_what_works() -> void:
	"""Settings: the scale the window fits, full screen, and the sound (decision 0351) -- inside the window."""
	_menu().menu_button(3).pressed.emit()
	_check("Settings opens", _menu().page() == MenuScript.PAGE_SETTINGS)
	var fits_150: bool = _size.y >= 1080
	_check("100%% is chosen", _menu().scale_button(0).button_pressed)
	_check("150%% is offered only where it fits", _menu().scale_button(2).disabled != fits_150)
	_check("the sound section is offered", _menu().page_text(MenuScript.PAGE_SETTINGS).contains("Quiet focus"))
	_capture("menu_settings")


func _settings_fit_and_sound() -> void:
	"""Laid out: the Settings frame inside the window; the sound owner follows the menu (decision 0351)."""
	var frame: PanelContainer = _menu().frame()
	var bottom: float = frame.position.y + frame.size.y * frame.scale.y
	_check("the Settings frame fits the window", frame.position.y >= 0.0 and bottom <= float(_size.y) + 1.0,
		"top %.0f bottom %.0f" % [frame.position.y, bottom])
	_sound_follows_the_menu()


func _sound_really_plays() -> void:
	"""In the running scene, with a real (silent) stream injected: a chop is given to a playing player at pitch 1,
	the pause stops it, the rain loop plays with its level and stops at 0, and a button made now clicks
	(decision 0351). The injected streams are taken out again."""
	var sound: Node = _village.call(&"sound")
	var table: RefCounted = sound.get(&"table")
	var voices: Node = sound.get(&"voices")
	var chop: int = int(table.call(&"row", &"chop"))
	var wav := _silent_wav()
	(table.get(&"streams") as Array)[chop] = [wav]
	var now: int = Time.get_ticks_msec() + 100000
	_check("a chop is played", int(sound.call(&"cue", chop, sound.call(&"listener_at"), false, now)) == 0)
	var player: AudioStreamPlayer3D = _playing_voice(voices)
	_check("its player really plays, at pitch 1", player != null and is_equal_approx(player.pitch_scale, 1.0))
	sound.call(&"set_paused", true)
	_check("the pause stops it", _playing_voice(voices) == null)
	sound.call(&"set_paused", false)
	(table.get(&"streams") as Array)[chop] = []
	_loop_plays_and_stops(sound, wav)
	_a_late_button_clicks(sound, table, voices)


func _silent_wav() -> AudioStreamWAV:
	"""Two seconds of silence, 16-bit mono."""
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var data := PackedByteArray()
	data.resize(22050 * 2 * 2)
	wav.data = data
	return wav


func _playing_voice(voices: Node) -> AudioStreamPlayer3D:
	"""The first placed voice playing (null: none)."""
	for voice: int in int(voices.call(&"voice_count")):
		var player := voices.call(&"placed_player", voice) as AudioStreamPlayer3D
		if player != null and player.playing:
			return player
	return null


func _loop_plays_and_stops(sound: Node, wav: AudioStreamWAV) -> void:
	"""The rain loop with a stream: playing as its level rises, stopped at 0."""
	var rain := (sound.get(&"_loop_flat") as Array)[1] as AudioStreamPlayer
	var taps: RefCounted = sound.get(&"taps")
	var level: int = int(taps.get(&"rain_permille"))
	rain.stream = wav
	taps.set(&"rain_permille", 1000)
	sound.call(&"_ease_loops", 0.5)
	_check("the rain loop plays while it rains", rain.playing)
	taps.set(&"rain_permille", 0)
	sound.call(&"_ease_loops", 5.0)
	_check("and stops when it is dry", not rain.playing)
	rain.stream = null
	taps.set(&"rain_permille", level)


func _a_late_button_clicks(_sound: Node, table: RefCounted, voices: Node) -> void:
	"""A button added to the running scene now is hooked as it joins the tree, and clicks."""
	var click: int = int(table.call(&"row", &"ui_click"))
	var before: int = _offered(voices, click)
	var late := Button.new()
	_village.add_child(late)
	late.pressed.emit()
	_check("a button made after boot offers its click (played, or held back by the click's gap or voices)",
		_offered(voices, click) == before + 1, "offered %d -> %d" % [before, _offered(voices, click)])
	late.queue_free()


func _offered(voices: Node, cue: int) -> int:
	"""How many times cue `cue` was offered to the voices (sound_voices.gd `offered`)."""
	return int((voices.get(&"offered") as PackedInt32Array)[cue])


func _sound_follows_the_menu() -> void:
	"""The village's sound owner: its buses made, ducked while the menu holds the clock, and Work's + moves the bus."""
	var sound: Node = _village.call(&"sound")
	var mix: RefCounted = sound.get(&"mix")
	_check("the sound owner ducks while the menu holds the clock", bool(mix.get(&"paused")))
	var work: int = AudioServer.get_bus_index(&"Work")
	_check("the Work bus exists", work > 0)
	var settings: Node = _menu().get(&"sound")
	(settings.call(&"up_button", 2) as Button).pressed.emit()
	_check("Work's + raises the bus to 80 %", absf(AudioServer.get_bus_volume_db(work) - linear_to_db(0.8)) < 0.01,
		"%.2f dB" % AudioServer.get_bus_volume_db(work))
	(settings.call(&"down_button", 2) as Button).pressed.emit()


func _settings_close() -> void:
	"""Esc, Esc: Settings, then the menu, close."""
	_key(KEY_ESCAPE)
	_key(KEY_ESCAPE)
	_check("two Escs close the menu", not _menu().visible and not _gate().modal_open())


# --- the playtest log (decision 0562) ----------------------------------------------------------

func _playtest_file_text() -> String:
	"""The running session's file so far ('' without one)."""
	var session: RefCounted = PlaytestLog.session()
	if session == null:
		return ""
	return FileAccess.get_file_as_string(String(session.call(&"dir")).path_join(String(session.call(&"file_name"))))


func _playtest_opens_the_menu() -> void:
	"""The village started the log under the root, its probes bound; Settings shows its section; the menu opens (a
	panel breadcrumb on the next frame)."""
	_playtest_node = root.get_node_or_null(NodePath(String(PlaytestLog.NODE_NAME)))
	_check("the playtest log runs under the root", _playtest_node != null and PlaytestLog.session() != null)
	if PlaytestLog.session() == null:
		return
	_playtest_file = String(PlaytestLog.session().call(&"file_name"))
	_check("its breadcrumbs are bound", int(_playtest_node.call(&"probe_count")) >= 5)
	_check("the compared map layer is a breadcrumb", (_playtest_node.get("_probe_tags") as Array).has(&"compare layer"))
	_menu().open()
	_check("Settings has the playtest log", _menu().page_text(MenuScript.PAGE_SETTINGS).contains("Open log folder"))


func _playtest_presses_f12() -> void:
	"""F12 over the open menu marks; the menu stays open (the log's node reads F12 before the gate)."""
	_key(KEY_F12)
	_check("F12 over the menu leaves it open", _menu().visible and _gate().modal_open())


func _playtest_marked() -> void:
	"""The mark is in the file, with the menu's breadcrumb before it; Esc closes the menu."""
	var text: String = _playtest_file_text()
	_check("F12 wrote the mark", text.contains("MARK #1  the tester marked a problem here"))
	_check("after the menu's breadcrumb", text.contains("panel DemoMenu opened"))
	_check("the village opened in the log", text.contains("scene village open"))
	_key(KEY_ESCAPE)


func _playtest_survives_the_restart() -> void:
	"""After Restart demo: the same node and file, the new village's probes bound, and the node last under the root
	again (so F12 still comes before the gate)."""
	var node: Node = root.get_node_or_null(NodePath(String(PlaytestLog.NODE_NAME)))
	_check("the same playtest log after the restart", node != null and node == _playtest_node)
	_check("the same session file", PlaytestLog.session() != null
		and String(PlaytestLog.session().call(&"file_name")) == _playtest_file)
	if node == null:
		return
	_check("the new village's breadcrumbs are bound", int(node.call(&"probe_count")) >= 5)
	_check("it is the root's last child again", node.get_index() == root.get_child_count() - 1)
	_menu().open()


func _playtest_marked_again() -> void:
	"""The second mark lands over the restarted village's menu, after the restart's breadcrumb."""
	var text: String = _playtest_file_text()
	_check("F12 marks again after the restart", text.contains("MARK #2  the tester marked a problem here"))
	_check("the restart is a breadcrumb", text.contains("scene restart"))
	_key(KEY_ESCAPE)


# --- F30: keyboard focus ------------------------------------------------------------------------

func _f7_and_tab_reach_every_panel_button() -> void:
	"""F7 lands on the right column; Tab reaches every shown button of each of the four panels."""
	var zone: ZoneScript = _village.get("_zone")
	for panel_key: int in 4:
		zone.show_panel(panel_key)
		_key(KEY_F7)
		_check("F7 focuses the right column (panel %d)" % panel_key, _focus() == zone.tab(0), str(_focus()))
		var wanted: Array[Control] = _gate().region_controls(0)
		var reached: Array[Control] = []
		for k: int in wanted.size() + 2:
			if not reached.has(_focus()):
				reached.append(_focus())
			_key(KEY_TAB)
		var missing: int = 0
		for control: Control in wanted:
			missing += 0 if reached.has(control) else 1
		_check("Tab reaches all %d buttons of panel %d" % [wanted.size(), panel_key], missing == 0
			and wanted.size() >= (5 if panel_key == ZoneScript.PANEL_TUNNELS else 6), "missing %d" % missing)
		_key(KEY_ESCAPE)
		_check("Esc gives focus back to the world (panel %d)" % panel_key, _focus() == null)
	zone.show_panel(ZoneScript.PANEL_WOODS)
	_key(KEY_F7)
	_key(KEY_TAB)
	_key(KEY_TAB, true)
	_check("Shift+Tab steps back", _focus() == zone.tab(0))
	for k: int in 6:
		_key(KEY_TAB)
	var panel: Node = _village.get("_forestry").get("panel")
	_check("six Tabs on: a Woods button, the keyboard's", _focus() != null and panel.is_ancestor_of(_focus())
		and _focus().has_focus(true), str(_focus()))
	_capture("focus_ring")


func _focus_ring_off() -> void:
	"""Esc hands the focus back to the world, and the ring goes with it."""
	_key(KEY_ESCAPE)
	_check("the ring's focus is gone", _focus() == null)


func _f7_reaches_the_left_column_then_the_world() -> void:
	"""With the whole cast selected (a digger among them, so the party panel's Dig and room buttons show):
	F7, F7 -> the left column; F7 -> the Map layer picker (decision 0391); F7 -> the world."""
	_command().call(&"select", PackedInt32Array(range(int(_village.get("_cast").call(&"actor_count")))))
	_command().call(&"_refresh_panel")
	var party: Node = _command().call(&"panel")
	_key(KEY_F7)
	_check("F7 first: the right column", _gate().region_of(_focus()) == 0)
	_key(KEY_F7)
	_check("F7 again: the party panel", _focus() != null and party.is_ancestor_of(_focus()), str(_focus()))
	var ring: Array[Control] = _gate().region_controls(1)
	_key(KEY_TAB)
	_check("Tab moves along the party panel", ring.size() < 2 or _focus() == ring[1])
	_key(KEY_F7)
	_check("F7 a third time: the Map layer picker", _focus() != null
		and _village.get("_lens_picker").is_ancestor_of(_focus()), str(_focus()))
	_key(KEY_F7)
	_check("F7 a fourth time: the guide card (decision 0481)", _focus() != null
		and _village.call(&"guide").get("card").call(&"frame").is_ancestor_of(_focus()), str(_focus()))
	_key(KEY_F7)
	_check("F7 a fifth time: the world", _focus() == null)
	_check("the selection is untouched", _command().call(&"selection_count") > 1)
	_key(KEY_ESCAPE)


func _enter_and_space_route_by_focus() -> void:
	"""Enter and Space press a keyboard-focused tab; a clicked one gives Space back to the pause."""
	var zone: ZoneScript = _village.get("_zone")
	zone.show_panel(ZoneScript.PANEL_FARM)
	_key(KEY_F7)
	_key(KEY_TAB)
	_check("Tab reaches the Tunnels tab", _focus() == zone.tab(ZoneScript.PANEL_TUNNELS))
	_key(KEY_ENTER)
	_check("Enter presses it", zone.shown == ZoneScript.PANEL_TUNNELS)
	var was_paused: bool = bool(_manager().call(&"is_paused"))
	_key(KEY_TAB)
	_key(KEY_SPACE)
	_check("Space presses the focused Woods tab", zone.shown == ZoneScript.PANEL_WOODS)
	_check("and does not pause", bool(_manager().call(&"is_paused")) == was_paused)
	_key(KEY_ESCAPE)
	_click(_centre(zone.tab(ZoneScript.PANEL_WATER)))
	_check("a click opens Water", zone.shown == ZoneScript.PANEL_WATER, "%s at %s hovered %s" % [zone.shown, _centre(zone.tab(ZoneScript.PANEL_WATER)), root.gui_get_hovered_control()])
	_key(KEY_SPACE)
	_check("Space after a click pauses the world", bool(_manager().call(&"is_paused")) != was_paused)
	_check("and drops the click's focus", _focus() == null)
	_key(KEY_SPACE)


func _enter_goes_to_the_dig_tool() -> void:
	"""With the Dig tool out: Enter from a keyboard-focused button presses the button, not the tool; from a
	clicked button or no focus it is the tool's."""
	var tool: Object = _command().call(&"tunnels")
	var zone: ZoneScript = _village.get("_zone")
	_key(KEY_B)
	_check("B opens the Dig tool", bool(tool.get("planning")))
	tool.set("_last_notice", "")
	_key(KEY_F7)
	_key(KEY_TAB)
	_key(KEY_ENTER)
	_check("Enter on a focused tab presses the tab", zone.shown == ZoneScript.PANEL_TUNNELS)
	_check("and the tool never saw it", String(tool.call(&"notice")).is_empty(), String(tool.call(&"notice")))
	_click(_centre(zone.tab(ZoneScript.PANEL_FARM)))
	_key(KEY_ENTER)
	_check("Enter after a click is the tool's", not String(tool.call(&"notice")).is_empty())
	_check("and did not press the clicked tab again", zone.shown == ZoneScript.PANEL_FARM)
	_key(KEY_B)
	_check("B closes the Dig tool", not bool(tool.get("planning")))


# --- F50: the Demo Lab --------------------------------------------------------------------------

func _lab_holds_the_triggers() -> void:
	"""F8 opens the Lab with the four triggers, Skip to next season (decision 0571), the season preview (decision 0551)
	and the infirmary's two test injuries (decision 0622), then the guide's Practice stories (decision 0481); the panels
	hold none of them; F8 closes it."""
	var lab: CanvasLayer = _village.call(&"lab")
	_key(KEY_F8)
	_check("F8 opens the Demo Lab", lab.visible and _gate().top_layer() == lab)
	_check("the Lab holds the triggers and Practice stories",
		Array(lab.call(&"trigger_labels")) == ["Next weather", "Test event", "Storm gust", "Cramp", "Skip to next season",
			"Season preview", "Injury", "Serious injury", "Practice stories"], str(lab.call(&"trigger_labels")))
	_check("Cramp waits for a swimmer", (lab.call(&"trigger_button", 3) as Button).disabled)
	_capture("demo_lab")


func _lab_fires_and_panels_are_clean() -> void:
	"""Storm gust fires from the Lab; no player panel holds a trigger; F8 closes the Lab."""
	var lab: CanvasLayer = _village.call(&"lab")
	(lab.call(&"trigger_button", 2) as Button).pressed.emit()
	_check("Storm gust fires from the Lab", String(lab.call(&"status_text")).begins_with("Sent: Storm gust"))
	var panels: Array[Node] = [_village.get("_farm").get("bed_panel"), _command().call(&"tunnels").get("ext").get("panel"),
		_village.get("_forestry").get("panel"), _village.get("_waterplay").get("panel")]
	var found: PackedStringArray = PackedStringArray()
	for panel: Node in panels:
		_button_words(panel, found)
	_check("no player panel holds a test trigger", found.is_empty(), ", ".join(found))
	_key(KEY_F8)
	_check("F8 closes the Lab", not lab.visible and not _gate().modal_open())


func _button_words(node: Node, found: PackedStringArray) -> void:
	"""Every button under `node` whose text names a test trigger."""
	for child: Node in node.get_children():
		if child is Button:
			for word: String in TRIGGER_WORDS:
				if (child as Button).text.contains(word):
					found.append((child as Button).text)
		_button_words(child, found)


func _lab_from_the_menu() -> void:
	"""The menu's Demo Lab closes the menu (releasing its pause) and opens the Lab."""
	var lab: CanvasLayer = _village.call(&"lab")
	_menu().open()
	_menu().menu_button(4).pressed.emit()
	_check("the menu's Demo Lab opens the Lab", lab.visible and not _menu().visible)
	_check("and releases MENU", not (_manager().call(&"get_pause_reason_names") as Array).has("MENU"))
	_key(KEY_ESCAPE)
	_check("Esc closes the Lab", not lab.visible)


func _history_click_does_not_leak() -> void:
	"""The village news history (N, decision 0331; it stands in for the shell's notification history) is an
	expansion, not a modal: a click on it never reaches the world, and Esc closes it before the selection."""
	_command().call(&"select", PackedInt32Array([1]))
	_order_before = int(_brain(1).get("order"))
	_key(KEY_N)
	var history: Object = _village.call(&"news_history")
	_check("N opens the village news history", bool(history.call(&"is_open")))
	_check("and not the shell's history behind it", not _shell_control("ID_HISTORY").is_visible_in_tree())
	_click((history.call(&"frame_rect") as Rect2).get_center(), MOUSE_BUTTON_RIGHT)
	_check("a right-click on it issues no order", int(_brain(1).get("order")) == _order_before)
	_key(KEY_ESCAPE)
	_check("Esc closes it", not bool(history.call(&"is_open")))
	_check("and leaves the selection", _command().call(&"selected") == PackedInt32Array([1]))
	_key(KEY_ESCAPE)


func _a_click_gives_the_arrows_back() -> void:
	"""After clicking a tab, an arrow pans the camera (a click's focus is dropped), and the Food command
	clicked opens the Pantry whose Esc hands the command its hidden focus back."""
	var zone: ZoneScript = _village.get("_zone")
	_click(_centre(zone.tab(ZoneScript.PANEL_WOODS)))
	var camera: Node = _village.get("_camera")
	var down := InputEventKey.new()
	down.keycode = KEY_LEFT
	down.pressed = true
	root.push_input(down)
	_check("an arrow after a click pans the camera", (camera.get("_held") as PackedByteArray).has(1))
	_check("and drops the click's focus", _focus() == null)
	down.pressed = false
	root.push_input(down)
	var food: Control = _shell().call(&"control_for", int((_ids["COMMAND_IDS"] as Array)[3]))
	_click(_centre(food))
	_check("the Food command opens the Pantry", _pantry().visible)
	_key(KEY_ESCAPE)
	_check("Esc gives the Food command its focus back, hidden as the click left it",
		_focus() == food and not food.has_focus(true), str(_focus()))
	_key(KEY_LEFT)


func _the_banner_over_the_lab() -> void:
	"""The Lab open, a stall puts the banner up: B still does nothing behind the Lab, and Enter is the
	banner's Resume."""
	_key(KEY_F8)
	_check("the clock runs before the stall", not bool(_manager().call(&"is_paused")),
		str(_manager().call(&"get_pause_reason_names")))
	OS.delay_msec(1200)


func _the_banner_takes_enter() -> void:
	"""(The stall has landed.)"""
	var banner: Node = _village.get("_stall_banner")
	_check("a stall puts the banner up", bool(banner.call(&"is_shown")))
	_key(KEY_B)
	_check("B behind the Lab still does nothing", not bool(_command().call(&"tunnels").get("planning")))
	_check("the Lab is still the top modal", _gate().top_layer() == _village.call(&"lab"))
	_key(KEY_ENTER)
	_check("Enter is the banner's Resume", not (_manager().call(&"get_pause_reason_names") as Array).has("CRITICAL"))
	_key(KEY_F8)
	_check("F8 closes the Lab", not _gate().modal_open())


func _the_hud_workspace_keeps_the_keys() -> void:
	"""The gate defers to the HUD shell's own scrimmed workspace (its true modal pages; none is reachable from
	the demo, so the wiring is checked here and the routing in test_demo_input_gate.gd). An ordinary
	workspace (Residents, L) holds nothing, and the panels stay live beside it (UI §4.2)."""
	var defer: Callable = _gate().get("_defer_to")
	_check("the gate defers to the shell's workspace", defer.is_valid() and defer.get_object() == _shell()
		and defer.get_method() == &"workspace_owns_input")
	_key(KEY_L)
	_check("the Residents workspace is not modal", not bool(_shell().call(&"workspace_owns_input")))
	_key(KEY_F7)
	_check("so F7 still reaches the panels beside it", _gate().region_of(_focus()) == 0)
	_key(KEY_ESCAPE)
	_shell().call(&"_on_back_pressed")


# --- the Work screen (decision 0411; review F22, F32, SOC-004, UX-002) -----------------------------------

func _work() -> Node:
	"""The village's work (demo/work/demo_work.gd)."""
	return _village.call(&"work")


func _work_screen() -> CanvasLayer:
	"""The Work screen."""
	return _work().get("screen")


func _board() -> RefCounted:
	"""The work board."""
	return _work().get("board")


func _jobs_opens_the_work_screen() -> void:
	"""The HUD's Jobs command is unlocked for the Work screen: J opens it as a modal with the focus inside it and its
	frame inside the window; Esc closes it; a click on the Jobs button opens it again."""
	var jobs := _shell_control("ID_JOBS") as Button
	_check("the Jobs command is enabled", jobs != null and not jobs.disabled)
	_key(KEY_J)
	_check("J opens the Work screen", _work_screen().visible)
	_check("the Work screen is the top modal", _gate().top_layer() == _work_screen())
	_check("focus lands inside the Work screen", _gate().in_top_modal(_focus()), str(_focus()))
	var frame: Rect2 = _work_screen().call(&"frame_rect")
	_check("the Work screen fits the window", Rect2(Vector2.ZERO, Vector2(_size)).grow(1.0).encloses(frame), str(frame))
	_key(KEY_ESCAPE)
	_check("Esc closes the Work screen", not _work_screen().visible)
	_click(_centre(jobs))
	_check("a click on Jobs opens it", _work_screen().visible)


func _work_tab_and_enter() -> void:
	"""Tab moves the focus through the Work screen's own controls (the gate's trap); Enter on a focused view tab presses
	it."""
	var screen := _work_screen()
	var residents: Button = screen.call(&"tab_button", 1)
	residents.grab_focus()
	_key(KEY_TAB)
	_check("Tab stays inside the Work screen", _gate().in_top_modal(_focus()), str(_focus()))
	residents.grab_focus()
	_key(KEY_ENTER)
	_check("Enter on a focused tab shows its view", int(screen.get("view")) == 1)
	(screen.call(&"tab_button", 0) as Button).grab_focus()
	_key(KEY_ENTER)
	_check("and back to the Tasks", int(screen.get("view")) == 0)


func _work_queue_a_fell() -> void:
	"""A felling ordered with nobody selected: on the Work screen's Tasks view, with its worker, state and commands."""
	var forestry: Node = _village.get("_forestry")
	var crew: RefCounted = forestry.get("crew")
	var stand: RefCounted = forestry.get("stand")
	for t: int in int(stand.call(&"count")):
		if String(crew.call(&"refusal_for", 0, t, 0)).is_empty():
			crew.call(&"order", 0, t, 0, PackedInt32Array(), 0)
			break
	var screen := _work_screen()
	screen.call(&"refresh")
	var row: Control = _fell_row()
	_check("the felling is a row on the Tasks view", row != null)
	if row == null:
		return
	(screen.get("_scroll") as ScrollContainer).ensure_control_visible(row)
	_capture("work_tasks")


func _fell_row() -> Control:
	"""The Tasks view's felling row (null: none)."""
	for row: Control in _work_screen().call(&"task_rows_shown"):
		if String(row.call(&"title")).begins_with("Fell"):
			return row
	return null


func _work_show_the_fell() -> void:
	"""Scroll the felling's row into view again (the farm's sowing policy puts more tasks on the board from the first
	hour -- decision 0886 -- so the list may have moved since it was queued)."""
	var row: Control = _fell_row()
	if row != null:
		(_work_screen().get("_scroll") as ScrollContainer).ensure_control_visible(row)


func _work_open_the_picker() -> void:
	"""A click on the felling's Reassign… opens its picker: every resident, each with its eligibility."""
	var row: Control = _fell_row()
	if row == null:
		_check("the felling's row is still there", false)
		return
	_click(_centre(row.call(&"button_of", &"pick")))
	_check("Reassign… opens the picker", bool(row.call(&"picker_open")))
	var last: Control = row.call(&"resident_button", int(_board().call(&"resident_count")) - 1)
	if last != null:
		(_work_screen().get("_scroll") as ScrollContainer).ensure_control_visible(last)
	_capture("work_picker")


func _reassign_target(row: Control) -> int:
	"""The first resident other than the felling's worker the board would let take it (-1: none)."""
	var board: RefCounted = _board()
	var source: int = int(row.get("task_source"))
	var task_row: int = int(row.get("task_row"))
	var before: int = int(board.call(&"source", source).call(&"worker", task_row))
	for who: int in int(board.call(&"resident_count")):
		if who != before and String(board.call(&"eligibility_words", source, task_row, who)).is_empty():
			return who
	return -1


func _work_show_the_target() -> void:
	"""Scroll the picker's button for the resident the felling goes to into view (the picker was scrolled to its last)."""
	var row: Control = _fell_row()
	var button: Button = row.call(&"resident_button", _reassign_target(row)) if row != null else null
	if button != null:
		(_work_screen().get("_scroll") as ScrollContainer).ensure_control_visible(button)


func _work_reassign_by_click() -> void:
	"""A click on a resident in the picker gives it the felling; the row says so."""
	var row: Control = _fell_row()
	if row == null:
		_check("the felling's row is still there", false)
		return
	var board: RefCounted = _board()
	var source: int = int(row.get("task_source"))
	var task_row: int = int(row.get("task_row"))
	var before: int = int(board.call(&"source", source).call(&"worker", task_row))
	var to: int = _reassign_target(row)
	var button: Button = row.call(&"resident_button", to)
	_check("an eligible resident's button is enabled", button != null and not button.disabled)
	_click(_centre(button))
	var after: int = int(board.call(&"source", source).call(&"worker", task_row))
	_check("a click reassigns the felling", after == to, "%d -> %d (wanted %d): %s" % [before, after, to,
		_work_screen().call(&"answer")])


func _work_show_residents() -> void:
	"""A click on the Residents tab shows the crews; resident 0's row is scrolled into view (drawn by the next step)."""
	var screen := _work_screen()
	_click(_centre(screen.call(&"tab_button", 1)))
	_check("a click shows the Residents view", int(screen.get("view")) == 1)
	_check("resident 0 has a row", _resident_row(0) != null)


func _work_scroll_to_resident() -> void:
	"""Resident 0's Crew ▶ scrolled into view, once the Residents view is laid out (drawn by the next step)."""
	var row: Control = _resident_row(0)
	if row != null:
		(_work_screen().get("_scroll") as ScrollContainer).ensure_control_visible(row.call(&"button_of", &"crew_on"))


func _resident_row(who: int) -> Control:
	"""The Residents view's row for resident `who` (null: none)."""
	for shown: Control in _work_screen().call(&"resident_rows_shown"):
		if int(shown.get("who")) == who:
			return shown
	return null


func _work_edit_a_crew() -> void:
	"""The Residents view: a click on a resident's "Crew ▶" moves it to the next crew, its row says so."""
	var screen := _work_screen()
	var crews: RefCounted = _board().get("crews")
	var row: Control = _resident_row(0)
	if row == null:
		return
	var was: int = int((crews.get("crew_of") as PackedInt32Array)[0])
	var button: Button = row.call(&"button_of", &"crew_on")
	_click(_centre(button))
	var now: int = int((crews.get("crew_of") as PackedInt32Array)[0])
	_check("Crew ▶ moves it to the next crew", now == (was + 1) % 5, "%d -> %d at %s" % [was, now, _centre(button)])
	screen.call(&"refresh")
	var named: Control = _resident_row(0)
	_check("its row names the new crew", named != null and String(named.call(&"title")).contains(
		["Field", "Woods", "Diggers", "Haulers", "Builders"][now] + " crew"), String(named.call(&"title")) if named else "")
	_check("the screen is still open", screen.visible)
	var frame: Rect2 = screen.call(&"frame_rect")
	_check("the Residents view fits the window", Rect2(Vector2.ZERO, Vector2(_size)).grow(1.0).encloses(frame), str(frame))
	(screen.call(&"preset_button", 1) as Button).grab_focus()
	_check("a focused preset previews its changes", String((screen.get("_preset_note") as Label).text).begins_with("Harvest week"))
	_capture("work_residents")


func _work_cancel_all_shows_its_scope() -> void:
	"""The Projects view groups the tasks by where they are; Cancel all work… only shows its scope, counted, until it
	is confirmed."""
	var screen := _work_screen()
	_click(_centre(screen.call(&"tab_button", 2)))
	_check("a click shows the Projects view", int(screen.get("view")) == 2)
	var before: int = (screen.call(&"task_rows_shown") as Array).size()
	_click(_centre(screen.call(&"cancel_all_button")))
	_check("Cancel all work… shows its scope first", String(screen.call(&"confirm_text")).begins_with("Cancel all work:")
		or String(screen.call(&"answer")).begins_with("Nothing to cancel"), String(screen.call(&"confirm_text")))
	_check("and cancels nothing yet", (screen.call(&"task_rows_shown") as Array).size() == before)
	_capture("work_cancel_scope")


func _work_keep_working() -> void:
	"""Keep working closes the scope; nothing was cancelled."""
	var screen := _work_screen()
	var frame: Rect2 = screen.call(&"frame_rect")
	_check("the Work screen still fits the window with the scope shown", Rect2(Vector2.ZERO, Vector2(_size)).grow(1.0)
		.encloses(frame), str(frame))
	var keep: Button = (screen.call(&"confirm_buttons") as Array)[1]
	if keep.is_visible_in_tree():
		_click(_centre(keep))
	_check("Keep working closes the scope", String(screen.call(&"confirm_text")).is_empty())


func _work_closes_on_j() -> void:
	"""J closes the Work screen again (its own key)."""
	_key(KEY_J)
	_check("J closes the Work screen", not _work_screen().visible)


func _shift_right_click_queues() -> void:
	"""Shift+right-click on open ground with a resident selected appends a walk to its order list: an idle resident
	takes it up at once, a second one waits on the list -- "Next: ..." in the party panel."""
	_command().call(&"select", PackedInt32Array([1]))
	var brain: Object = _brain(1)
	brain.call(&"release")
	var at: Vector2 = Vector2(float(_size.x) * 0.5, float(_size.y) * 0.45)
	_click(at, MOUSE_BUTTON_RIGHT, true)
	_click(at + Vector2(-60.0, 0.0), MOUSE_BUTTON_RIGHT, true)
	_check("Shift+right-click appends to the order list", int(brain.call(&"queue_size")) >= 1,
		"list %d, order %d: %s (hovered %s)" % [int(brain.call(&"queue_size")), int(brain.get("order")),
		_command().call(&"notice_for_selection"), root.gui_get_hovered_control()])
	var entries: Array = _command().call(&"party_entries")
	_check("the party panel lists what is next", entries.size() == 1
		and not (entries[0]["then"] as PackedStringArray).is_empty())
	_check("and says it was queued", String(_command().call(&"notice_for_selection")).begins_with("Walk queued"))
	brain.call(&"release")
	_command().call(&"clear_selection")


func _work_at_the_chosen_scale() -> void:
	"""(At 1920x1080, after 150% was chosen: decision 0391's step.) The Work screen is drawn at the HUD's scale and still
	fits the window."""
	if _size.y < 1080:
		return
	_key(KEY_J)
	var frame: Control = _work_screen().get("_frame")
	var chosen: float = 1.5 if _chose_150 else 1.25
	_check("the Work screen follows the interface scale", is_equal_approx(frame.scale.x, chosen), str(frame.scale))
	var rect: Rect2 = _work_screen().call(&"frame_rect")
	_check("and fits the window at it", Rect2(Vector2.ZERO, Vector2(_size)).grow(1.0).encloses(rect), str(rect))
	_capture("work_scaled")


func _work_close_scaled() -> void:
	"""(At 1920x1080.) J closes it again."""
	if _size.y >= 1080 and _work_screen().visible:
		_key(KEY_J)


func _scale_follows_the_choice() -> void:
	"""At 1920x1080: 150% scales the HUD, the right column, the party panel, the stall banner and the level indicator
	together (and is kept through a restart, below). At 1280x720 150% is not offered, which the settings step
	checked (decision 0391: 125% is)."""
	if _size.y < 1080:
		return
	_menu().open()
	_menu().menu_button(3).pressed.emit()
	_menu().scale_button(2).pressed.emit()
	_chose_150 = true
	_check("150% reaches the HUD", int(_shell().get("_user_scale")) == 150)
	_check("and the right column", is_equal_approx((_village.get("_zone").get("_strip") as Control).scale.x, 1.5))
	_check("and the party panel", is_equal_approx((_command().call(&"panel").get("_frame") as Control).scale.x, 1.5))
	_check("and the stall banner", is_equal_approx((_village.get("_stall_banner").get("_frame") as Control).scale.x, 1.5))
	_check("and the level indicator", is_equal_approx(float(_command().call(&"tunnels").get("view").call(&"indicator_scale")), 1.5))
	_menu().back_or_close()
	_menu().back_or_close()


# --- group F: panels that stay usable (decision 0391) ----------------------------------------------

## Wheat and peas in the farm catalogue (farm_catalog.gd ITEM_LABELS): wheat sows Spring 1-4, peas from Spring 5.
const WHEAT: int = 13
const PEA: int = 11
var _picker_scroll: int = 0
## Whether this run chose 150 % (the 1080p run), so the shrink to 1280x720 steps down to 125 %.
var _chose_150: bool = false
var _picker_title: String = ""


func _the_workspace_covers_no_stop() -> void:
	"""G's open item: with the Residents workspace (L) open, F7 and Tab through the right column never land on a
	control it covers, and at 1280x720 it does cover some (decision 0391)."""
	_key(KEY_L)
	var cover: Rect2 = _village.call(&"_workspace_rect", _shell())
	_check("the workspace is open", cover.has_area(), str(cover))
	var covered: int = 0
	for control: Control in GateScript.focusables(_gate().get("_regions")[0]):
		covered += 1 if GateScript.screen_rect(control).intersects(cover) else 0
	if _size.y < 1080:
		_check("at 1280x720 it covers right-column buttons", covered > 0, "%d" % covered)
	var landed: Array[Rect2] = []
	_key(KEY_F7)
	for k: int in 12:
		if _focus() != null:
			landed.append(GateScript.screen_rect(_focus()))
		_key(KEY_TAB)
	var under: int = 0
	for rect: Rect2 in landed:
		under += 1 if rect.intersects(cover) else 0
	_check("F7 and Tab skip every covered stop", not landed.is_empty() and under == 0, "%d of %d" % [under, landed.size()])
	_key(KEY_ESCAPE)
	_shell().call(&"_on_back_pressed")


func _a_group_is_box_selected() -> void:
	"""A real drag over the residents on screen selects a group, and the party panel stays, with its count, its
	summary and Release in view (F20: at 1280x720 it used to vanish)."""
	_command().call(&"clear_selection")
	var box: Rect2 = _cast_box()
	_drag(box.position, box.end)
	var picked: PackedInt32Array = _command().call(&"selected")
	_check("the drag selected a group", picked.size() >= 2, "%d from %s" % [picked.size(), box])
	_command().call(&"_refresh_panel")
	_capture("group_selected")


func _a_member_row_selects_and_centres() -> void:
	"""(After the drag.) The party panel lists every member; a real click on the second row selects that resident
	alone and eases the camera to it."""
	var party: Node = _command().call(&"panel")
	var picked: PackedInt32Array = _command().call(&"selected")
	var frame: Control = party.get("_frame")
	_check("the party panel shows for the group", frame.is_visible_in_tree(), str(party.call(&"frame_rect")))
	_check("with its count", String(party.call(&"count_shown")) == "%d selected" % picked.size(), String(party.call(&"count_shown")))
	_check("Release in view", _fraction(party.call(&"release_button")) >= 0.99)
	_check("a row per member", int(party.call(&"member_row_count")) == picked.size())
	if picked.size() < 2:
		return
	var row: Button = party.call(&"member_row", 1)
	(party.call(&"inspector") as ScrollContainer).call(&"reveal", row)
	_steps.push_front(_click_member_row.bind(picked[1]))


func _click_member_row(who: int) -> void:
	"""The click itself, once the row is scrolled into view."""
	var row: Button = _command().call(&"panel").call(&"member_row", 1)
	var camera: Node = _village.get("_camera")
	var before: Vector3 = camera.get("_target_focus")
	_check("the row is in view", _fraction(row) >= 0.99, str(row.get_global_rect()))
	_click(_centre(row))
	_check("the click selected that resident alone", _command().call(&"selected") == PackedInt32Array([who]),
		str(_command().call(&"selected")))
	var feet: Vector2 = _brain(who).get("position")
	var after: Vector3 = camera.get("_target_focus")
	_check("and centred the camera on it", absf(after.x - feet.x) < 1.0 and absf(after.z - feet.y) < 1.0,
		"%s -> %s, feet %s" % [before, after, feet])


func _a_water_action_without_scrolling() -> void:
	"""F12: resident 0 selected, the Water panel open -- Swim shortcuts is in view without scrolling, no roster row
	before it, and a real click on it toggles it."""
	_command().call(&"select", PackedInt32Array([0]))
	_village.get("_zone").call(&"show_panel", 3)
	var water: Node = _village.get("_waterplay").get("panel")
	_village.get("_waterplay").call(&"refresh_panel")
	(water.call(&"sections") as ScrollContainer).scroll_vertical = 0
	_steps.push_front(_click_swim_shortcuts)


func _click_swim_shortcuts() -> void:
	"""The click, a frame after the panel was laid out."""
	var water: Node = _village.get("_waterplay").get("panel")
	var consent: Button = water.call(&"button", WaterPanel.ACTION_CONSENT)
	_check("Swim shortcuts in view, unscrolled", _fraction(consent) >= 0.99, str(consent.get_global_rect()))
	_check("no resident row before it", not (water.call(&"roster_row", 0) as Control).is_visible_in_tree())
	var presses: Array[int] = [0]
	var count := func() -> void: presses[0] += 1
	consent.pressed.connect(count)
	_click(_centre(consent))
	consent.pressed.disconnect(count)
	_check("a real click presses it", presses[0] == 1, "%d" % presses[0])
	_capture("water_action")
	_click(_centre(consent))


func _the_picker_opens_on_bed_1() -> void:
	"""F36: bed 1's crop picker open, the keyboard's focus on Wheat, the list scrolled a little."""
	var farm: Node = _village.get("_farm")
	farm.call(&"select_bed", 0)
	var bed: Node = farm.get("bed_panel")
	bed.call(&"open_picker")
	_gate().call(&"_focus", bed.call(&"picker_button", WHEAT), true)
	var body: ScrollContainer = bed.call(&"body")
	body.scroll_vertical = 40
	_picker_title = String(bed.call(&"picker_title_text"))
	_check("wheat sowable at the start", not (bed.call(&"picker_button", WHEAT) as Button).disabled)
	_check("peas not yet", (bed.call(&"picker_button", PEA) as Button).disabled)


func _the_picker_crosses_spring_5() -> void:
	"""The real farm calendar crosses into Spring 5 with the picker open: wheat is refused with its reason, peas are
	sowable, the title has today's date -- and the focus and the scroll are where they were."""
	var farm: Node = _village.get("_farm")
	var bed: Node = farm.get("bed_panel")
	var body: ScrollContainer = bed.call(&"body")
	_picker_scroll = body.scroll_vertical
	var quarter: int = 6 * CalendarScript.HOUR_USEC
	for k: int in 32:
		if String(bed.call(&"picker_title")).contains("Spring 5"):
			break
		farm.call(&"advance_calendar", quarter)
	_steps.push_front(_after_spring_5)


func _after_spring_5() -> void:
	"""(The farm's own refresh has run on the turned hour.)"""
	var bed: Node = _village.get("_farm").get("bed_panel")
	var wheat: Button = bed.call(&"picker_button", WHEAT)
	_check("the picker is still open", bool(bed.get("picking")))
	_check("wheat refused now", wheat.disabled, wheat.tooltip_text.left(80))
	_check("with its reason", String(bed.call(&"picker_detail", WHEAT)).contains("can't: sow in"))
	_check("peas sowable now", not (bed.call(&"picker_button", PEA) as Button).disabled)
	var title: String = bed.call(&"picker_title_text")
	_check("the title's date is today's", title.contains("Spring 5") and title != _picker_title, title)
	_check("the focus stayed on Wheat", _focus() == wheat, str(_focus()))
	_check("the scroll stayed", (bed.call(&"body") as ScrollContainer).scroll_vertical == _picker_scroll,
		"%d -> %d" % [_picker_scroll, (bed.call(&"body") as ScrollContainer).scroll_vertical])
	_capture("picker_spring_5")
	_steps.push_front(_close_the_picker)


func _close_the_picker() -> void:
	"""(After the frame is saved.) Back to the bed's verbs, and focus to the world."""
	_village.get("_farm").get("bed_panel").call(&"close_picker")
	_key(KEY_ESCAPE)


func _cast_box() -> Rect2:
	"""A screen box round the residents in view (a box selects by screen position, under a panel too), its first
	corner -- where the press lands -- on open ground (no panel under it)."""
	var camera: Camera3D = get_viewport_camera()
	var box := Rect2()
	var first: bool = true
	for i: int in int(_village.get("_cast").call(&"actor_count")):
		var at: Vector3 = (_village.get("_cast").call(&"actor", i) as Node3D).global_position
		if camera.is_position_behind(at):
			continue
		var p: Vector2 = camera.unproject_position(at)
		if not Rect2(Vector2.ZERO, Vector2(_size)).has_point(p):
			continue
		box = Rect2(p, Vector2.ZERO) if first else box.expand(p)
		first = false
	box = box.grow(24.0)
	for corner: Vector2 in [box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)]:
		if not _over_ui(corner):
			return Rect2(corner, box.get_center() * 2.0 - corner - corner)
	return box


func get_viewport_camera() -> Camera3D:
	"""The camera the world is drawn through."""
	return root.get_camera_3d()


func _over_ui(point: Vector2) -> bool:
	"""Whether a shown control that stops the mouse is under `point`."""
	for node: Node in root.find_children("*", "Control", true, false):
		var control := node as Control
		if control.mouse_filter == Control.MOUSE_FILTER_STOP and control.is_visible_in_tree() \
				and GateScript.screen_rect(control).has_point(point):
			return true
	return false


func _fraction(control: Control) -> float:
	"""How much of `control` is on screen, cut by the window and every clipping ancestor (the review's probe)."""
	if control == null or not control.is_visible_in_tree():
		return 0.0
	var rect: Rect2 = control.get_global_rect()
	var clip := Rect2(Vector2.ZERO, Vector2(_size))
	var at: Node = control.get_parent()
	while at != null:
		if at is Control and (at as Control).clip_contents:
			clip = clip.intersection((at as Control).get_global_rect())
		at = at.get_parent()
	return rect.intersection(clip).get_area() / maxf(rect.get_area(), 0.0001)


# --- restart ------------------------------------------------------------------------------------

func _restart_boots_again() -> void:
	"""Restart, confirmed, reloads the demo."""
	_menu().open()
	_menu().menu_button(1).pressed.emit()
	_menu().confirm_button().pressed.emit()
	_village = null
	_wait = 3
	_restart_checked_hold = false


func _after_restart() -> void:
	"""The restarted demo runs, with no menu pause left over (waited for: its prewarm holds the clock for
	its first frames)."""
	_village = current_scene
	if not _restart_checked_hold:
		_restart_checked_hold = true
		_check("the restart holds the clock through its first frames",
			(_manager().call(&"get_pause_reason_names") as Array).has("PLAYER"))
	if _village != null and bool(_manager().call(&"is_paused")) and _frames < 600:
		_steps.push_front(_after_restart)
		return
	_check("the demo restarted", _village != null and _village.has_method(&"input_gate"))
	if _village == null:
		return
	_check("no MENU pause survives the restart", not (_manager().call(&"get_pause_reason_names") as Array).has("MENU"))
	_check("the restarted demo runs", not bool(_manager().call(&"is_paused")),
		str(_manager().call(&"get_pause_reason_names")))
	if _size.y >= 1080:
		_check("the restart keeps 150% on the HUD", int(_shell().get("_user_scale")) == 150)
		_check("and in the menu", _menu().scale_percent == 150)
		_size = Vector2i(1280, 720)


func _a_smaller_window_steps_the_scale_down() -> void:
	"""(After a 1080p run.) The window shrinks to 1280x720: 150% no longer fits, so the demo steps down to the largest
	size that does, 125% (decision 0391)."""
	var expected: int = 125 if _chose_150 else 100
	_check("the scale steps down to what the window fits", _menu().scale_percent == expected
		and int(_shell().get("_user_scale")) == expected, "%d%%" % _menu().scale_percent)
