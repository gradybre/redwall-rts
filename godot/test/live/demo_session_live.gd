extends SceneTree
## The live demo's time controls and accessibility on the REAL scene with REAL Viewport input (decision 0471; review
## UX-022, UX-023). Not discovered by the runner (it is not `test_*.gd` in test/): test/test_demo_session_live.gd runs it
## in its own process, as test_demo_input_live.gd runs demo_input_live.gd (decision 0261).
##
##     godot --headless --path godot --script res://test/live/demo_session_live.gd [-- --size 1920x1080]
##         [-- --capture <dir>]   (not headless: saves the checked frames as PNGs)
##
## It boots demo/demo_village.tscn (on placeholders when the assets are not staged) and, through `root.push_input`:
## Space pauses and the pause card says so, Space resumes; with Pause while planning on, the Pantry pauses and closing it
## resumes; G opens "Run until..." as a modal; clicking 4x and Next meal runs the village until the kitchen's 07:00 call
## and it pauses saying so; from 05:40, Dawn stops at 06:00 to the tick; F6 opens the object list and Enter on a row
## selects and centres that resident; in the menu's Settings, clicking Reduced motion, Large readable and Keyboard
## planner applies each live, and Restore defaults asks and restores. Prints `LIVE <name>: PASS|FAIL <detail>` per check
## and `LIVE-SUMMARY <checks> <failures>`; exits 1 on any failure.

const SHELL_PATH: String = "res://scripts/ui/ui_shell.gd"
const MenuScript := preload("res://demo/ui/demo_menu.gd")
const Access := preload("res://demo/access/demo_access.gd")
const Motion := preload("res://demo/access/demo_motion.gd")
const DemoUiScale := preload("res://demo/ui/demo_ui_scale.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")

const BOOT_FRAMES: int = 12
const STEP_FRAMES: int = 2
## How long a run may take to arrive before the check gives up (real milliseconds: a game hour is 6.25 s at 4x).
const RUN_MSEC: int = 40000
## The run targets' indices (run_until.gd TARGET_*: the harness cannot preload it beside the autoloads).
const TARGET_DAWN: int = 0
const TARGET_MEAL: int = 2
const LEDGER_PLAYER: int = 1
const LEDGER_PLANNING: int = 4

var _village: Node = null
var _wait: int = BOOT_FRAMES
var _steps: Array[Callable] = []
var _checks: int = 0
var _failures: int = 0
var _size: Vector2i = Vector2i(1280, 720)
var _capture_dir: String = ""
var _pending_capture: String = ""
var _ids: Dictionary = {}
## A step waiting for the run to arrive, and the real time it gives up at.
var _waiting: Callable = Callable()
var _deadline_msec: int = 0
var _run_started_tick: int = 0


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
	_steps = [_wait_until_open, _running_shows_no_card, _space_pauses_and_the_card_says_so, _the_card_resumes_by_space,
		_planning_pauses_with_the_pantry, _the_pantry_paused, _closing_the_pantry_resumes, _g_opens_the_run_menu, _choose_4x_and_next_meal,
		_wait_for_the_meal, _resume_after_the_meal, _jump_to_before_dawn, _run_until_dawn, _wait_for_dawn,
		_space_resumes_after_dawn, _f6_opens_the_object_list, _enter_selects_and_centres, _open_the_settings,
		_click_reduced_motion, _click_large_readable, _click_keyboard_planner, _see_the_keyboard_planner,
		_reopen_the_settings, _reveal_restore, _restore_asks, _restore_confirmed]


func _process(_delta: float) -> bool:
	"""One step each time the wait runs out (a waiting step is asked again each frame); quit after the last."""
	if root.size != _size:
		root.size = _size
	if _waiting.is_valid():
		if not bool(_waiting.call(Time.get_ticks_msec() >= _deadline_msec)):
			return false
		_waiting = Callable()
		_wait = STEP_FRAMES
	_wait -= 1
	if _wait > 0:
		return false
	if not _pending_capture.is_empty():
		_save_capture()
	if _steps.is_empty():
		_restore_settings()
		print("LIVE-SUMMARY %d %d" % [_checks, _failures])
		quit(1 if _failures > 0 else 0)
		return false
	var step: Callable = _steps.pop_front()
	step.call()
	_wait = STEP_FRAMES
	return false


# --- helpers ----------------------------------------------------------------------------------------------------

func _check(check_name: String, ok: bool, detail: String = "") -> void:
	"""Record one check."""
	_checks += 1
	if not ok:
		_failures += 1
	print("LIVE %s: %s %s" % [check_name, "PASS" if ok else "FAIL", detail])


func _key(code: Key) -> void:
	"""Press and release one key through the Viewport."""
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		root.push_input(event)


func _click(at: Vector2) -> void:
	"""A left click at `at`."""
	var motion := InputEventMouseMotion.new()
	motion.position = at
	root.push_input(motion)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = at
		event.pressed = down
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		root.push_input(event)


func _centre(control: Control) -> Vector2:
	"""A control's centre on screen."""
	return control.get_global_transform_with_canvas() * (control.size / 2.0)


func _capture(file_name: String) -> void:
	"""Save this state's frame at the next step (only when asked for, and never headless)."""
	if not _capture_dir.is_empty() and DisplayServer.get_name() != "headless":
		_pending_capture = file_name


func _save_capture() -> void:
	"""Write the pending frame, and forgive the clock the time the read-back took."""
	root.get_texture().get_image().save_png(_capture_dir.path_join("%s_%dx%d.png" % [_pending_capture, _size.x, _size.y]))
	_pending_capture = ""
	_forgive()


func _forgive() -> void:
	"""Tell the game clock no real time passed during a slow harness frame (no overload pause from the harness)."""
	root.get_node(^"GameManager").set("_last_host_usec", Time.get_ticks_usec())


func _time() -> Node:
	"""The village's time controls."""
	return _village.call(&"time_control")


func _ledger() -> Object:
	"""The pause ledger."""
	return _time().get("ledger")


func _run() -> Object:
	"""The run."""
	return _time().get("run")


func _card() -> CanvasLayer:
	"""The pause card."""
	return _village.call(&"pause_card")


func _card_text() -> String:
	"""What the card says once it has looked."""
	_card().call(&"refresh")
	return String(_card().call(&"text")) if bool(_card().call(&"is_shown")) else ""


func _manager() -> Object:
	"""The GameManager autoload."""
	return root.get_node(^"GameManager")


func _calendar() -> CalendarScript:
	"""The demo calendar."""
	return _village.call(&"services").get("calendar")


func _menu() -> MenuScript:
	"""The game menu."""
	return _village.call(&"menu")


func _gate() -> Node:
	"""The input gate."""
	return _village.call(&"input_gate")


# --- the pause types -------------------------------------------------------------------------------------------

func _wait_until_open() -> void:
	"""Wait for the boot's prewarm to release the clock."""
	_waiting = func(late: bool) -> bool: return late or bool(_time().get("opened"))
	_deadline_msec = Time.get_ticks_msec() + RUN_MSEC


func _running_shows_no_card() -> void:
	"""Opened and running: no card, and the HUD's own pause label hidden."""
	_check("the village opened running", bool(_time().get("opened")) and not bool(_manager().call(&"is_paused")))
	_check("no pause card while running", _card_text().is_empty())
	var label: Control = _village.call(&"_shell").call(&"control_for", int(_ids["ID_PAUSE_LABEL"]))
	_check("the HUD's pause label hidden", label != null and not label.visible)


func _space_pauses_and_the_card_says_so() -> void:
	"""Space: the player's pause, the card 'Paused — You paused' with Resume enabled."""
	_key(KEY_SPACE)
	_check("Space paused as the player", int(_ledger().call(&"kinds")) == LEDGER_PLAYER, str(_ledger().call(&"kinds")))
	var text: String = _card_text()
	_check("the card says the player paused", text == "Paused — You paused", text)
	var resume: Button = _card().call(&"resume_button")
	_check("its Resume is enabled", not resume.disabled)
	_capture("pause_player")


func _the_card_resumes_by_space() -> void:
	"""Space again: Resume; the card goes."""
	_key(KEY_SPACE)
	_check("Space resumed", not bool(_manager().call(&"is_paused")))
	_check("the card went", _card_text().is_empty())


func _planning_pauses_with_the_pantry() -> void:
	"""With Pause while planning on, K opens the Pantry and the village pauses, saying so."""
	Access.set_flag(Access.SET_PAUSE_PLANNING, true)
	_village.call(&"access_effects").call(&"apply")
	_key(KEY_K)
	_waiting = func(_late: bool) -> bool: return true
	_deadline_msec = Time.get_ticks_msec()


func _the_pantry_paused() -> void:
	"""The planning pause was held a frame after K, the card naming the Pantry."""
	_check("the Pantry paused the village (planning)", int(_ledger().call(&"kinds")) == LEDGER_PLANNING,
		str(_ledger().call(&"kinds")))
	var text: String = _card_text()
	_check("the card names the Pantry", text.contains("Planning: the Pantry is open"), text)
	_capture("pause_planning")


func _closing_the_pantry_resumes() -> void:
	"""K again closes the Pantry and the village runs."""
	_key(KEY_K)
	_time().call(&"_process", 0.0)
	_check("closing the Pantry resumed", not bool(_manager().call(&"is_paused")))
	Access.set_flag(Access.SET_PAUSE_PLANNING, false)
	_village.call(&"access_effects").call(&"apply")


# --- run until ---------------------------------------------------------------------------------------------------

func _g_opens_the_run_menu() -> void:
	"""G: the run menu, the top modal, every target listed."""
	_key(KEY_G)
	var menu: CanvasLayer = _village.call(&"run_menu")
	_check("G opens Run until", bool(menu.call(&"is_open")))
	_check("as the top modal", _gate().call(&"top_layer") == menu)
	var dawn: Button = menu.call(&"target_button", TARGET_DAWN)
	_check("Dawn offered with its hour", dawn.text.begins_with("Dawn: 06:00") and not dawn.disabled, dawn.text)
	_capture("run_menu")


func _choose_4x_and_next_meal() -> void:
	"""Click 4x, then Next meal: the run starts at 4x and the menu closes."""
	var menu: CanvasLayer = _village.call(&"run_menu")
	_click(_centre(menu.call(&"speed_button", 2)))
	_check("4x chosen", int(_manager().call(&"get_speed")) == 4, str(_manager().call(&"get_speed")))
	_run_started_tick = _calendar().tick
	_click(_centre(menu.call(&"target_button", TARGET_MEAL)))
	_check("running until the next meal", int(_run().get("target")) == TARGET_MEAL)
	_check("the menu closed", not bool(menu.call(&"is_open")))
	_capture("running")


func _wait_for_the_meal() -> void:
	"""The button says what it runs until; wait (real time) until the run pauses the village."""
	var button: Button = (_village.call(&"run_menu") as CanvasLayer).call(&"button")
	_check("the button says so", button.text == "■ Next meal", button.text)
	_waiting = _arrived.bind("the next meal")
	_deadline_msec = Time.get_ticks_msec() + RUN_MSEC


func _arrived(late: bool, what: String) -> bool:
	"""Whether the run has ended; at the deadline, record that it did not."""
	if not bool(_run().call(&"is_running")):
		return true
	if late:
		_check("the run until %s arrived" % what, false, "still running at %s" % _calendar().date_text())
		return true
	return false


func _resume_after_the_meal() -> void:
	"""Paused at 07:00 exactly, saying so."""
	var at := SimClock.Calendar.new(_calendar().tick)
	_check("stopped on the breakfast call, 07:00", at.hour == 7 and at.minute == 0 and _calendar().tick == 750,
		"%02d:%02d tick %d" % [at.hour, at.minute, _calendar().tick])
	var text: String = _card_text()
	_check("the card says it arrived", text.contains("Reached the next meal: Y1 Spring 1, 07:00"), text)
	_capture("run_until_meal")


func _jump_to_before_dawn() -> void:
	"""Space resumes; run the calendar on to 05:40 (the farm's own hours, as the Lab's Next weather does), at 4x still."""
	_key(KEY_SPACE)
	_check("Space resumed after the meal", not bool(_manager().call(&"is_paused")))
	var to: int = SimClock.TICKS_PER_DAY - SimClock.TICKS_PER_HOUR / 3
	var usec: int = CalendarScript.usec_for_ticks(to - _calendar().tick)
	_village.get("_farm").call(&"advance_calendar", usec)
	_forgive()
	var at := SimClock.Calendar.new(_calendar().tick)
	_check("the calendar at 05:40", at.hour == 5 and at.minute >= 39, "%02d:%02d" % [at.hour, at.minute])


func _run_until_dawn() -> void:
	"""G, then Dawn by the keyboard: focus it and press Enter."""
	_key(KEY_G)
	var menu: CanvasLayer = _village.call(&"run_menu")
	var dawn: Button = menu.call(&"target_button", TARGET_DAWN)
	dawn.grab_focus()
	_key(KEY_ENTER)
	_check("Enter on Dawn started the run", int(_run().get("target")) == TARGET_DAWN, str(_run().get("target")))


func _wait_for_dawn() -> void:
	"""Wait until the run pauses the village."""
	_waiting = _arrived.bind("dawn")
	_deadline_msec = Time.get_ticks_msec() + RUN_MSEC


func _space_resumes_after_dawn() -> void:
	"""At 06:00:00 to the tick; the card says so."""
	var tick: int = _calendar().tick
	_check("stopped at dawn to the tick", tick == SimClock.TICKS_PER_DAY, "tick %d (%s)" % [tick, _calendar().date_text()])
	var text: String = _card_text()
	_check("the card says dawn", text.contains("Reached dawn: Y1 Spring 2, 06:00"), text)
	_capture("run_until_dawn")


# --- the object list ---------------------------------------------------------------------------------------------

func _f6_opens_the_object_list() -> void:
	"""Space resumes at 1x; F6: the list as the top modal, a row per resident first."""
	_key(KEY_SPACE)
	_manager().call(&"set_speed", 1)
	_check("Space resumed after dawn", not bool(_manager().call(&"is_paused")))
	_key(KEY_F6)
	var list: CanvasLayer = _village.call(&"object_list")
	_check("F6 opens the object list", list.visible)
	_check("as the top modal", _gate().call(&"top_layer") == list)
	var first: Button = list.call(&"row_button", 0)
	_check("the first row is the first resident", first.text.ends_with("— resident"), first.text)
	_capture("object_list")


func _enter_selects_and_centres() -> void:
	"""The keyboard on row 2, Enter: that resident selected, the camera over it, the list closed."""
	var list: CanvasLayer = _village.call(&"object_list")
	var row: Button = list.call(&"row_button", 1)
	row.grab_focus()
	_key(KEY_ENTER)
	var command: Node = _village.get("_command")
	_check("Enter selected resident 2", command.call(&"selected") == PackedInt32Array([1]), str(command.call(&"selected")))
	var actor: Node3D = _village.get("_cast").call(&"actor", 1)
	var target: Vector3 = _village.get("_camera").get("_target_focus")
	_check("and centred the camera on it", absf(target.x - actor.position.x) < 0.5 and absf(target.z - actor.position.z) < 0.5,
		"%s vs %s" % [target, actor.position])
	_check("the list closed", not list.visible)


# --- the presets --------------------------------------------------------------------------------------------------

func _open_the_settings() -> void:
	"""The game menu's Settings page, the accessibility section in it."""
	_menu().open()
	_menu().call(&"_show_page", MenuScript.PAGE_SETTINGS)
	_check("Settings open", _menu().page() == MenuScript.PAGE_SETTINGS)


func _press_preset(preset: int) -> void:
	"""Scroll a preset into view and click it."""
	var button: Button = _menu().access.preset_button(preset)
	_menu().get("_settings_scroll").call(&"reveal", button)
	_click(_centre(button))


func _click_reduced_motion() -> void:
	"""Reduced motion: the flag, the camera's easing off, particles cut -- live."""
	var applies: int = int(_village.call(&"access_effects").get("applies"))
	_press_preset(Access.PRESET_MOTION)
	_check("Reduced motion applied", Access.is_on(Access.SET_MOTION) and Motion.reduced)
	_check("the effects applied live", int(_village.call(&"access_effects").get("applies")) > applies)
	_capture("preset_reduced_motion")


func _click_large_readable() -> void:
	"""Large readable: the largest scale the window offers, bigger tooltips, high-contrast panels."""
	_press_preset(Access.PRESET_LARGE)
	var wanted: int = 150 if bool(_village.call(&"ui_scale_fits", 150)) else 125
	_check("the interface at %d %%" % wanted, DemoUiScale.percent == wanted, str(DemoUiScale.percent))
	_check("bigger tooltips and high contrast on", Access.is_on(Access.SET_TOOLTIPS) and Access.is_on(Access.SET_CONTRAST))
	var preview: String = _menu().access.preview_text()
	_check("the line says what it applied", preview.begins_with("Applied Large readable"), preview)
	_capture("preset_large_readable")


func _click_keyboard_planner() -> void:
	"""Keyboard planner: focus hints and the targets' rings; then close the menu and focus the right column."""
	_press_preset(Access.PRESET_KEYBOARD)
	_check("the rings shown", bool(_village.call(&"target_marks").visible))
	_check("focus hints on", bool(_village.call(&"focus_hint").get("enabled")))
	_menu().close()
	_key(KEY_F7)


func _see_the_keyboard_planner() -> void:
	"""The rings drawn and the focus hint under the focused control."""
	_check("rings drawn on the surface", int(_village.call(&"target_marks").get("surface_rings")) > 0,
		str(_village.call(&"target_marks").get("surface_rings")))
	var hint: String = _village.call(&"focus_hint").call(&"shown_text")
	_check("the focus hint names the control and its keys", hint.contains(" — Enter: ") and hint.contains("Esc: back"), hint)
	_capture("preset_keyboard_planner")


func _reopen_the_settings() -> void:
	"""Focus back to the world, and the Settings page again."""
	_key(KEY_ESCAPE)
	_menu().open()
	_menu().call(&"_show_page", MenuScript.PAGE_SETTINGS)


func _reveal_restore() -> void:
	"""Scroll Restore defaults into view (the scroll moves its rows at the next sort)."""
	_menu().get("_settings_scroll").call(&"reveal", _menu().access.restore_button())


func _restore_asks() -> void:
	"""Restore defaults, clicked: it asks, saying what it changes."""
	var restore: Button = _menu().access.restore_button()
	_click(_centre(restore))
	_check("Restore asks first", _menu().access.confirm_shown())
	_capture("restore_asks")


func _restore_confirmed() -> void:
	"""Confirmed: every setting at its default, the scale 100 %."""
	_menu().access.restore_defaults()
	_check("defaults restored", Access.flags == Access.DEFAULTS and DemoUiScale.percent == 100 and not Motion.reduced,
		"%s %d" % [Access.flags, DemoUiScale.percent])
	_menu().close()


func _restore_settings() -> void:
	"""Leave the session's settings at their defaults."""
	Access.reset()
	Motion.reduced = false
