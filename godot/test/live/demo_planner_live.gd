extends SceneTree
## The seasonal planner on the REAL scene with REAL Viewport input (decision 0451): G opens it as a modal of the input
## gate with the focus inside it and its frame inside the window; Tab stays inside; its filter is clicked; a row clicked
## closes it, opens that bed's panel and centres the camera; the calendar's timeline and table, the soil plans and the
## record are shown; G and Esc close it; the bed panel's Compare… rings and ranks the beds; and at 125 % it still fits.
## Not discovered by the runner: test/test_demo_planner_live.gd runs it in its own process (the runner's worker cannot
## dispatch input; docs/ENVIRONMENT.md).
##
##     godot --headless --path godot --script res://test/live/demo_planner_live.gd [-- --size 1920x1080]
##         [-- --capture <dir>]   (not headless: saves the checked frames as PNGs)
##
## Prints `LIVE <name>: PASS|FAIL <detail>` per check and `LIVE-SUMMARY <checks> <failures>`; exits 1 on a failure.

const GateScript := preload("res://demo/ui/demo_input_gate.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const NewsJumpScript := preload("res://demo/ui/demo_news_jump.gd")

const BOOT_FRAMES: int = 12
const STEP_FRAMES: int = 3
const BED_RADISH: int = 3
const BED_CARROTS: int = 2

var _village: Node = null
var _wait: int = BOOT_FRAMES
var _steps: Array[Callable] = []
var _checks: int = 0
var _failures: int = 0
var _size: Vector2i = Vector2i(1280, 720)
var _capture_dir: String = ""
var _pending_capture: String = ""


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
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(_size)
	_village = (load("res://demo/demo_village.tscn") as PackedScene).instantiate()
	root.add_child(_village)
	current_scene = _village
	_steps = [_pause, _g_opens_the_planner_as_a_modal, _tab_stays_inside, _the_attention_filter, _a_row_opens_its_bed,
		_the_calendar_s_timeline, _the_calendar_s_table, _enter_on_a_focused_tab, _the_soil_plans, _a_day_passes, _the_record,
		_g_and_esc_close_it, _open_the_carrots, _reveal_compare, _compare_rings_the_beds, _compare_back, _at_125, _at_125_close]


func _process(_delta: float) -> bool:
	"""One step each time the wait runs out; quit after the last (the root's size held: decision 0261's note)."""
	if root.size != _size:
		root.size = _size
	_wait -= 1
	if _wait > 0:
		return false
	if not _pending_capture.is_empty():
		_save_capture()
	if _steps.is_empty():
		print("LIVE-SUMMARY %d %d" % [_checks, _failures])
		quit(1 if _failures > 0 else 0)
		return false
	var step: Callable = _steps.pop_front()
	step.call()
	_wait = STEP_FRAMES
	return false


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
	"""Save this state's frame at the next step (only with --capture, never headless)."""
	if not _capture_dir.is_empty() and DisplayServer.get_name() != "headless":
		_pending_capture = file_name


func _save_capture() -> void:
	"""Write the pending frame, and forgive the clock the read-back's time (docs/ENVIRONMENT.md's stall note)."""
	root.get_texture().get_image().save_png(_capture_dir.path_join("%s_%dx%d.png" % [_pending_capture, _size.x, _size.y]))
	_pending_capture = ""
	root.get_node(^"GameManager").set("_last_host_usec", Time.get_ticks_usec())


func _farm() -> Node:
	"""The village's farm."""
	return _village.get("_farm")


func _planner() -> CanvasLayer:
	"""The seasonal planner."""
	return _farm().get("planner")


func _gate() -> GateScript:
	"""The village's input gate."""
	return _village.call(&"input_gate")


func _focus() -> Control:
	"""The focus owner."""
	return root.gui_get_focus_owner()


func _fits(rect: Rect2) -> bool:
	"""Whether a rectangle lies inside the window."""
	return Rect2(Vector2.ZERO, Vector2(_size)).grow(1.0).encloses(rect)


# --- the steps ----------------------------------------------------------------------------------------------------------

func _pause() -> void:
	"""Pause as the player (the frames are of a still village)."""
	root.get_node(^"GameManager").call(&"pause_game")


func _g_opens_the_planner_as_a_modal() -> void:
	"""G opens the planner over the scrim, the top modal, the focus inside it, its frame inside the window."""
	_key(KEY_G)
	_check("G opens the planner", _planner().visible)
	_check("the planner is the top modal", _gate().top_layer() == _planner())
	_check("focus lands inside the planner", _gate().in_top_modal(_focus()), str(_focus()))
	_check("the planner fits the window", _fits(_planner().call(&"frame_rect")), str(_planner().call(&"frame_rect")))
	_check("six beds listed", int(_planner().call(&"overview").call(&"shown_rows")) == 6)
	_capture("planner_overview")


func _tab_stays_inside() -> void:
	"""Tab moves the focus among the planner's own controls."""
	_key(KEY_TAB)
	_check("Tab stays inside the planner", _gate().in_top_modal(_focus()), str(_focus()))


func _the_attention_filter() -> void:
	"""The radish waterlogged; a click on Needs attention lists it alone."""
	var sim: RefCounted = _farm().get("sim")
	var slot: int = sim.call(&"slot_of", BED_RADISH)
	sim.call(&"farming").call(&"apply_moisture_delta", slot, 9600 - int(sim.call(&"moisture_of", BED_RADISH)))
	var button: Button = _planner().call(&"filter_button", 1)
	_click(_centre(button))
	var table: Node = _planner().call(&"overview")
	_check("the filter is clicked", int(_planner().get("filter")) == 1)
	_check("one bed needs attention", int(table.call(&"shown_rows")) == 1)
	_check("the waterlogged radish", int(table.call(&"row_id", 0)) == BED_RADISH)
	_capture("planner_attention")


func _a_row_opens_its_bed() -> void:
	"""A click on the row closes the planner, opens the bed's panel and eases the camera over it."""
	var row: Control = _planner().call(&"overview").call(&"row", 0)
	_click(_centre(row))
	_check("the row closes the planner", not _planner().visible)
	_check("and opens its bed", int(_farm().get("selected_bed")) == BED_RADISH)
	_check("the bed panel shows", bool(_farm().get("bed_panel").call(&"is_shown")))
	var jump: RefCounted = _village.call(&"news_jump")
	_check("the camera is eased over it", (jump.get("last_point") as Vector3).is_equal_approx(NewsJumpScript.bed_point(
		BED_RADISH)), str(jump.get("last_point")))
	_check("focus is out of the planner", not _gate().modal_open())


func _the_calendar_s_timeline() -> void:
	"""The calendar's tab: the timeline, today the HUD's day."""
	_key(KEY_G)
	_click(_centre(_planner().call(&"tab_button", 1)))
	var season: RefCounted = _planner().call(&"season")
	var calendar: RefCounted = _village.call(&"services").get("calendar")
	var now: RefCounted = calendar.call(&"now")
	_check("the calendar tab shows", int(_planner().get("view")) == 1)
	_check("today is the calendar's day", int(season.get("today")) == int(now.get("season_day")))
	var trigger: Button = _village.call(&"_shell").call(&"status_label")
	_check("the HUD shows that day", trigger.text == CalendarScript.day_text(int(now.get("season")),
		int(now.get("season_day"))), trigger.text)
	_check("the timeline draws", (_planner().call(&"timeline") as Control).is_visible_in_tree())
	_check("the planner fits the window", _fits(_planner().call(&"frame_rect")))
	_capture("planner_calendar")


func _the_calendar_s_table() -> void:
	"""The Table: every entry in words, instead of the timeline."""
	_planner().call(&"set_table_view", 1)
	var table: Node = _planner().call(&"calendar_table")
	_check("the table lists every entry", int(table.call(&"shown_rows")) == int(_planner().call(&"season").call(&"count")))
	_check("instead of the timeline", not (_planner().call(&"timeline") as Control).is_visible_in_tree())
	_capture("planner_calendar_table")


func _enter_on_a_focused_tab() -> void:
	"""Enter on a keyboard-focused tab shows it."""
	_gate().call(&"_focus", _planner().call(&"tab_button", 2), true)
	_key(KEY_ENTER)
	_check("Enter on Soil plans shows it", int(_planner().get("view")) == 2)


func _the_soil_plans() -> void:
	"""Bed 1's three plans."""
	_click(_centre(_planner().call(&"tab_button", 2)))
	_check("the three plans", not String(_planner().call(&"plan_texts", 2)).is_empty())
	_capture("planner_soil_plans")


func _a_day_passes() -> void:
	"""The calendar run on a day at once (the kitchen tallies its meals on its next frame)."""
	_farm().call(&"advance_calendar", 24 * CalendarScript.HOUR_USEC)


func _the_record() -> void:
	"""The next farm hour closes the day: yesterday's record, and the season's table."""
	_farm().call(&"advance_calendar", CalendarScript.HOUR_USEC)
	_click(_centre(_planner().call(&"tab_button", 3)))
	_check("yesterday's record", String(_planner().call(&"yesterday_text")).begins_with("Day's record, "),
		String(_planner().call(&"yesterday_text")).left(60))
	_check("the planner fits the window", _fits(_planner().call(&"frame_rect")))
	_capture("planner_record")


func _g_and_esc_close_it() -> void:
	"""G closes it; G opens it; Esc closes it -- and Esc does not also clear the selection."""
	_key(KEY_G)
	_check("G closes the planner", not _planner().visible)
	_key(KEY_G)
	_check("G opens it again", _planner().visible)
	_key(KEY_ESCAPE)
	_check("Esc closes it", not _planner().visible)
	_check("the bed stays open", int(_farm().get("selected_bed")) == BED_RADISH)


func _open_the_carrots() -> void:
	"""The carrots' bed open (its panel laid out by the next step)."""
	_farm().call(&"select_bed", BED_CARROTS)


func _reveal_compare() -> void:
	"""The panel scrolled to Compare… (it lies under the readout at 1280x720), as Tab's focus would."""
	var panel: Node = _farm().get("bed_panel")
	panel.call(&"body").call(&"reveal", panel.get("_compare_button"))


func _compare_rings_the_beds() -> void:
	"""The bed panel's Compare… clicked: every bed ranked and ringed on the map."""
	var panel: Node = _farm().get("bed_panel")
	var button: Button = panel.get("_compare_button")
	_check("Compare… is in the panel's view", (panel.call(&"body") as Control).get_global_rect().grow(1.0).encloses(
		button.get_global_rect()), str(button.get_global_rect()))
	_click(_centre(button))
	_check("Compare… shows the beds", bool(panel.get("comparing")))
	var marks: PackedStringArray = panel.call(&"compare_marks")
	_check("every bed is ranked", marks.size() == 6 and not marks.has(""), str(marks))
	_capture("bed_compare")


func _compare_back() -> void:
	"""Back: the readout again, the marks gone."""
	var panel: Node = _farm().get("bed_panel")
	_click(_centre(panel.call(&"back_button")))
	_check("Back closes the Compare view", not bool(panel.get("comparing")))
	_check("the marks gone", String(_farm().get("view").call(&"compare_mark", 5)).is_empty())


func _at_125() -> void:
	"""At 125 % the planner still fits the window."""
	_village.call(&"set_ui_scale", 125)
	_key(KEY_G)
	_planner().call(&"show_tab", 0)
	_check("at 125 % the planner fits the window", _fits(_planner().call(&"frame_rect")), str(_planner().call(&"frame_rect")))
	_capture("planner_125")


func _at_125_close() -> void:
	"""Closed, back at 100 %."""
	_key(KEY_ESCAPE)
	_village.call(&"set_ui_scale", 100)
	_check("closed at 125 %", not _planner().visible)
