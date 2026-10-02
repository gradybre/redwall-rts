extends SceneTree
## The winter's fuel and warmth loop on the REAL scene with REAL Viewport input (decision 0571): the spring opening's
## "No heat demand"; F8 and a click on the Demo Lab's "Skip to next season", exact to 06:00 on day 1; autumn's twelve-day
## projection in the Heating fuel breakdown opened by a click on the cell; winter with low wood -- the preparation card,
## the clay warning, the Firewood order urgent; the hall's hearth running out and the hall cooling, residents outdoors
## Chilled at 80%; wood in -- the hall relit and the Chilled sent to warm up; and the breakdown's Esc.
## Not discovered by the runner: test/test_demo_winter_live.gd runs it in its own process.
##
##     godot --headless --path godot --script res://test/live/demo_winter_live.gd [-- --size 1920x1080]
##         [-- --capture <dir>]     (not headless: saves the checked frames as PNGs)
##         [-- --acceptance]        (with --capture: winter lived in real time at 4x, waiting on the loop itself --
##                                  homes cooling, Chilled, the Firewood order worked, recovery -- not fast-forwarded)
##
## The quick run keeps the village paused and moves the calendar in ten-minute steps (the farm's own advance), so the
## hours pass in a few frames; the residents stand where they are. Prints `LIVE <name>: PASS|FAIL <detail>` per check
## and `LIVE-SUMMARY <checks> <failures>`; exits 1 on a failure.

## Only scripts that compile before the autoloads exist are preloaded here (the main script is compiled first); the
## demo's own are loaded once the village is built (`_load_scripts`) and read through them.
const GateScript := preload("res://demo/ui/demo_input_gate.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const WeatherCore := preload("res://scripts/core/weather.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")

const BOOT_FRAMES: int = 12
const STEP_FRAMES: int = 3
## hearth_fuel.gd HALL: the hall's row, after the eight homes'.
const HALL: int = 8
## ui_shell.gd ID_FUEL.
const ID_FUEL: int = 3
## winter_text.gd NO_DEMAND_SHORT; demo_winter.gd KEY_*; work_ids.gd SOURCE_WOODS.
const NO_DEMAND_SHORT: String = "No demand"
const KEY_OUT: String = "winter:out_of_fuel"
const KEY_SUMMARY: String = "winter:prepared"
const SOURCE_WOODS: int = 1
## winter_rules.gd HEATED_TENTHS.
const HEATED_TENTHS: int = 180
## Winter arrives with this much wood (milli-U): the hearth's hours to dawn leave it under an hour or two.
const LOW_WOOD_MILLI: int = 1500
## The quick run's steps of the calendar an hour: ten game minutes each.
const STEPS_PER_HOUR: int = 6
## The acceptance run's wood at winter's dawn (milli-U): about four hours of the hall's and the home's hearths.
const ACCEPTANCE_WOOD_MILLI: int = 1400
## burrow_rooms.gd TEMPLATE_HOME and FIX_HEARTH; room_fixtures.gd PLACES and INSTALLED.
const TEMPLATE_HOME: int = 1
const FIX_HEARTH: int = 1
const PLACES: int = 8
const INSTALLED: int = 2
## tunnel_rules.gd TOP_LEVEL: the first level below the ground.
const TOP_LEVEL: int = 1
## The acceptance run's patience for each stage, in real seconds at 4x (a game hour is 6.25 s).
const STAGE_TIMEOUT_S: float = 420.0

var _village: Node = null
var _wait: int = BOOT_FRAMES
var _steps: Array[Callable] = []
var _checks: int = 0
var _failures: int = 0
var _size: Vector2i = Vector2i(1280, 720)
var _capture_dir: String = ""
var _pending_capture: String = ""
var _acceptance: bool = false
var _until: Callable = Callable()
var _until_name: String = ""
var _until_s: float = 0.0
var _heartbeat_s: float = 0.0
var _log: PackedStringArray = PackedStringArray()
var _warm_up_script: GDScript = null
## The home the harness builds (its room row; -1 none).
var _home: int = -1


func _initialize() -> void:
	"""Read the arguments, size the window, boot the village and list the steps."""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for k: int in args.size():
		if args[k] == "--size" and k + 1 < args.size():
			var parts: PackedStringArray = args[k + 1].split("x")
			_size = Vector2i(int(parts[0]), int(parts[1]))
		elif args[k] == "--capture" and k + 1 < args.size():
			_capture_dir = args[k + 1]
		elif args[k] == "--acceptance":
			_acceptance = true
	root.size = _size
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(_size)
	_village = (load("res://demo/demo_village.tscn") as PackedScene).instantiate()
	root.add_child(_village)
	current_scene = _village
	_warm_up_script = load("res://demo/winter/warm_up_task.gd")
	_steps = [_pause, _spring_says_no_heat_demand, _f8_opens_the_lab, _skip_to_summer, _skip_to_autumn, _close_the_lab,
		_autumn_projection_in_the_breakdown, _esc_closes_the_breakdown, _build_a_home, _low_wood_and_on_to_winter,
		_winter_arrives]
	if _acceptance:
		_steps.append_array([_acceptance_wood, _look_below_at_the_home, _run_at_4x, _wait_home_heated, _wait_home_cold,
			_look_up, _wait_chilled, _wait_firewood_worked, _wait_recovery, _finish_log])
	else:
		_steps.append_array([_hours_pass_without_wood, _wood_comes_in, _the_cell_recovers, _consolidate_in_the_breakdown,
			_esc_closes_the_breakdown])


func _process(delta: float) -> bool:
	"""One step each time the wait runs out (or a waited condition holds); quit after the last."""
	if root.size != _size:
		root.size = _size
	if _until.is_valid():
		return _keep_waiting(delta)
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


func _keep_waiting(delta: float) -> bool:
	"""The acceptance run: keep the clock at 4x through stalls until the condition holds or the stage times out."""
	var gm: Node = root.get_node(^"GameManager")
	if bool(gm.call(&"is_paused")):
		var reasons := PackedStringArray()
		_village.call(&"time_control").get("ledger").call(&"reasons_into", reasons)
		print("ACC paused at %s: %s" % [_calendar().date_text(), ", ".join(reasons)])
		gm.call(&"acknowledge_overload")
		_village.call(&"time_control").call(&"resume")
		gm.call(&"resume_game")
	if int(gm.call(&"get_effective_speed")) != 4:
		gm.call(&"set_speed", 4)
	_until_s += delta
	_heartbeat_s += delta
	if _heartbeat_s >= 10.0:
		_heartbeat_s = 0.0
		print("ACC %.0f s: %s, %d fps, speed %d, paused %s, wood %d" % [_until_s, _calendar().date_text(),
			Engine.get_frames_per_second(), int(gm.call(&"get_effective_speed")), str(gm.call(&"is_paused")),
			int(_stores().get("wood_milli_u"))])
	if bool(_until.call()) or _until_s > STAGE_TIMEOUT_S:
		_check(_until_name, bool(_until.call()), "after %.0f s (%s)" % [_until_s, _calendar().date_text()])
		_until = Callable()
		_wait = STEP_FRAMES
	return false


func _check(check_name: String, ok: bool, detail: String = "") -> void:
	"""Record one check."""
	_checks += 1
	if not ok:
		_failures += 1
	var line: String = "LIVE %s: %s %s" % [check_name, "PASS" if ok else "FAIL", detail]
	_log.append(line)
	print(line)


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


func _winter() -> Variant:
	"""The village's winter."""
	return _village.call(&"winter")


func _panel() -> Variant:
	"""The Heating fuel breakdown."""
	return _village.call(&"fuel_panel")


func _calendar() -> CalendarScript:
	"""The one calendar."""
	return _village.get("_services").get("calendar")


func _stores() -> RefCounted:
	"""The village stores."""
	return _village.get("_services").get("stores")


func _shell() -> Variant:
	"""The HUD shell."""
	return _village.call(&"_shell")


func _lab() -> CanvasLayer:
	"""The Demo Lab."""
	return _village.call(&"lab")


func _gate() -> GateScript:
	"""The village's input gate."""
	return _village.call(&"input_gate")


func _fuel_cell() -> Control:
	"""The top bar's Heating fuel cell."""
	return _shell().control_for(ID_FUEL)


func _fuel_value() -> Label:
	"""The cell's value line."""
	return _shell().counter_value_label(ID_FUEL)


func _forward_hours(hours: int) -> void:
	"""The quick run: the calendar on `hours` game hours in ten-minute steps through the farm, the winter following each
	step as a frame would (each step is lived: under an hour)."""
	var farm: Node = _village.get("_farm")
	@warning_ignore("integer_division")
	var step_usec: int = CalendarScript.HOUR_USEC / STEPS_PER_HOUR
	for k: int in hours * STEPS_PER_HOUR:
		farm.call(&"advance_calendar", step_usec)
		_winter().catch_up()
		_winter().follow_exposure()
		_winter().send_warm_ups()


func _skip_button() -> Button:
	"""The Lab's "Skip to next season"."""
	var labels: PackedStringArray = _lab().call(&"trigger_labels")
	return _lab().call(&"trigger_button", labels.find("Skip to next season"))


# --- the steps ----------------------------------------------------------------------------------------------------------

func _pause() -> void:
	"""Pause as the player (the quick run moves the calendar itself)."""
	root.get_node(^"GameManager").call(&"pause_game")


func _spring_says_no_heat_demand() -> void:
	"""The spring opening: Heating fuel in UI-SET-003's caption, no heat demanded, not a warning."""
	_check("the cell is Heating fuel", _shell().counter_caption_label(ID_FUEL).text == "Heating fuel",
		_shell().counter_caption_label(ID_FUEL).text)
	_check("spring: no heat demand", _fuel_value().text == NO_DEMAND_SHORT,
		_fuel_value().text)
	_check("its tooltip in full", _fuel_cell().tooltip_text.begins_with("Heating fuel: No current heat demand"),
		_fuel_cell().tooltip_text)
	_capture("spring_hud")


func _f8_opens_the_lab() -> void:
	"""F8 opens the Demo Lab with the skip among its triggers."""
	_key(KEY_F8)
	_check("F8 opens the Lab", _lab().visible)
	_check("the Lab holds Skip to next season", _skip_button() != null)


func _skip_to_summer() -> void:
	"""A click on the skip lands on summer 1, 06:00:00."""
	_click(_centre(_skip_button()))
	var at: Variant = _calendar().now()
	_check("summer 1, 06:00 exactly", at.season == WeatherCore.SEASON_SUMMER and at.season_day == 1
		and at.hour == 6 and at.minute == 0, _calendar().date_text())


func _skip_to_autumn() -> void:
	"""Again: autumn 1, 06:00 -- and the twelve-day projection posted to the news."""
	_click(_centre(_skip_button()))
	_check("autumn 1, 06:00", _calendar().now().season == WeatherCore.SEASON_AUTUMN and _calendar().now().hour == 6,
		_calendar().date_text())
	var notices: RefCounted = _village.get("_services").get("notices")
	var posted: bool = false
	for k: int in notices.call(&"count"):
		posted = posted or String(notices.call(&"text", k)).begins_with("Winter is next.")
	_check("REQ-SET-114's projection posted", posted)


func _close_the_lab() -> void:
	"""F8 closes the Lab."""
	_key(KEY_F8)
	_check("F8 closes the Lab", not _lab().visible)


func _autumn_projection_in_the_breakdown() -> void:
	"""A click on the Heating fuel cell opens the breakdown, top modal: the projection with its progress bar."""
	_click(_centre(_fuel_cell()))
	_check("the cell opens the breakdown", _panel().visible)
	_check("the breakdown is the top modal", _gate().top_layer() == _panel())
	var shown: String = String(_panel().get("_lines").get("text"))
	_check("the twelve-day projection", shown.contains("Winter needs"), shown)
	_check("with its progress", bool(_panel().get("_progress").get("visible")))
	_capture("autumn_projection")


func _esc_closes_the_breakdown() -> void:
	"""Esc closes it."""
	_key(KEY_ESCAPE)
	_check("Esc closes the breakdown", not _panel().visible)


func _build_a_home() -> void:
	"""A burrow home dug at the first open spot the room rules allow, its three beds and its hearth put in at once (the
	night test's own way: the fit-out's phases written INSTALLED)."""
	var tool: Variant = _village.get("_command").call(&"tunnels")
	var graph: Variant = tool.get("network")
	var site: Variant = tool.call(&"room_site")
	var at: Vector2i = _open_spot(graph, site)
	var ref := PackedInt32Array([0, 0, 0, 0, 0])
	var laid: bool = at != Vector2i.MAX and bool(graph.call(&"add_room", TEMPLATE_HOME, at, 0, 0, ref))
	_check("a home laid at an open spot", laid, str(at))
	if not laid:
		return
	var chain := PackedInt32Array()
	graph.call(&"piece_segments_into", ref[2], chain)
	for slot: int in chain:
		graph.call(&"start_dig", slot, graph.get("generation")[slot], 0)
		graph.call(&"advance", slot, graph.get("generation")[slot], 1000000000)
	_home = ref[0]
	var fit: Variant = graph.get("fit")
	for f: int in 4:
		fit.call(&"phase_of", graph, _home, f)
		fit.get("phase")[_home * PLACES + f] = INSTALLED
	fit.set("revision", int(fit.get("revision")) + 1)
	_check("dug, with a hearth", bool(graph.get("rooms").call(&"is_done", graph, _home)) and bool(fit.call(&"has_hearth",
		graph, _home)))


func _open_spot(graph: Variant, site: Variant) -> Vector2i:
	"""The spot nearest the square, on a 2 m grid, where a home may be dug on the first level (Vector2i.MAX: none)."""
	var best: Vector2i = Vector2i.MAX
	for x: int in range(-14, 15, 2):
		for z: int in range(-14, 15, 2):
			var at := Vector2i(x * 1024, z * 1024)
			if int(graph.get("rooms").call(&"refusal", graph, site, TEMPLATE_HOME, at, 0, TOP_LEVEL)) != 0:
				continue
			if best == Vector2i.MAX or Vector2(at).length() < Vector2(best).length():
				best = at
	return best


func _low_wood_and_on_to_winter() -> void:
	"""The stores down to LOW_WOOD_MILLI, then on to winter through the Lab."""
	_stores().set("wood_milli_u", LOW_WOOD_MILLI)
	_key(KEY_F8)
	_click(_centre(_skip_button()))
	_key(KEY_F8)
	_check("winter 1, 06:00", _calendar().now().season == WeatherCore.SEASON_WINTER and _calendar().now().hour == 6,
		_calendar().date_text())


func _winter_arrives() -> void:
	"""Winter's dawn: the preparation card, the cell's clay warning, the Firewood order urgent."""
	var cards: CanvasLayer = _village.call(&"incident_cards")
	var incidents: RefCounted = _village.get("_services").get("incidents")
	cards.call(&"refresh")
	var summary: int = incidents.call(&"serial_of", KEY_SUMMARY)
	_check("the preparation summary", summary != -1, str(incidents.call(&"text_of", summary)))
	_check("pinned on the card", bool(cards.call(&"is_shown")) and int(cards.call(&"shown_serial")) == summary,
		"shown %s serial %d, stall %s, paused %s" % [str(cards.call(&"is_shown")), int(cards.call(&"shown_serial")),
		str(_village.get("_stall_banner").call(&"is_shown")), str(root.get_node(^"GameManager").call(&"is_paused"))])
	_check("the cell warns", _fuel_value().get_theme_color(&"font_color") == Palette.CLAY, _fuel_value().text)
	var row: int = _winter().firewood_row()
	var board: RefCounted = _village.call(&"work").get("board")
	_check("a Firewood order", row >= 0)
	_check("urgent", row >= 0 and bool(board.call(&"is_urgent", SOURCE_WOODS, row)))
	_capture("winter_arrives")


func _hours_pass_without_wood() -> void:
	"""Twelve hours on, the wood gone: the hall out of fuel and below freezing, the incident raised, those outdoors
	Chilled at 80% with nowhere warm to go."""
	_forward_hours(12)
	var fuel: Variant = _winter().get("fuel")
	_check("the hall is out of fuel", fuel.is_out(HALL))
	_check("the hall has cooled below freezing", fuel.temperature_of(HALL) < 0, "%d tenths" % fuel.temperature_of(HALL))
	var incidents: RefCounted = _village.get("_services").get("incidents")
	_check("the out-of-fuel incident", bool(incidents.call(&"is_unresolved", incidents.call(&"serial_of", KEY_OUT))))
	var chilled: int = _first_chilled()
	_check("someone outdoors is Chilled", chilled >= 0, _winter().status_text(maxi(chilled, 0), true))
	_check("working at 80%", chilled >= 0 and _brain(chilled).work_permille == 800)
	_check("with nowhere warm, no break", chilled >= 0 and not _is_warming(chilled))
	_check("the home's hearth out too", _home >= 0 and bool(fuel.is_out(_home)))
	var graph: Variant = _village.get("_command").call(&"tunnels").get("network")
	_check("its comfort without the hearth", _home >= 0 and int(graph.get("fit").call(&"comfort", graph, _home)) == 4000,
		str(graph.get("fit").call(&"comfort", graph, _home)))
	_capture("out_of_fuel")


func _wood_comes_in() -> void:
	"""Wood in (the Firewood's worth): the next hour the hall is relit and the Chilled are sent to warm up there."""
	_stores().call(&"add_wood", 24000)
	_forward_hours(1)
	_check("the hall relit", _winter().fuel.is_heated(HALL))
	_check("the home relit, its hearth lit", _home >= 0 and bool(_winter().fuel.hearth_lit(_home)))
	_check("the home's beds are warm beds", int(_village.get("_command").call(&"tunnels").get("ext").get("night").call(
		&"warm_beds")) > 0)
	var warming: int = 0
	for i: int in _winter().cold.count():
		warming += 1 if _winter().cold.is_chilled(i) and _is_warming(i) else 0
	_check("the Chilled sent to warm up in the hall", warming > 0 and int(_winter().breaks_sent) >= warming,
		"%d warming, %d breaks sent" % [warming, _winter().breaks_sent])
	_capture("recovery")


func _the_cell_recovers() -> void:
	"""A frame later the top bar has repainted: days of fuel again, out of its warning."""
	_check("the cell reads days again", _fuel_value().text.ends_with("days") and _fuel_value().text != "0.0 days",
		_fuel_value().text)
	_check("out of its warning", _fuel_value().get_theme_color(&"font_color") != Palette.CLAY, _fuel_value().text)


func _consolidate_in_the_breakdown() -> void:
	"""The breakdown again: its Consolidate's preview, pressed by click; it says what it did."""
	_click(_centre(_fuel_cell()))
	var button: Button = _panel().call(&"consolidate_button")
	_check("Consolidate previews its effect", button.tooltip_text.begins_with("Packs the"), button.tooltip_text)
	_click(_centre(button))
	_check("and says what it did", String(_panel().call(&"status_text")).begins_with("Consolidated:"), String(_panel().call(&"status_text")))
	_capture("breakdown")


func _first_chilled() -> int:
	"""The first Chilled resident (-1: none)."""
	for i: int in _winter().cold.count():
		if _winter().cold.is_chilled(i):
			return i
	return -1


func _brain(i: int) -> Variant:
	"""Resident `i`'s brain."""
	var cast: Node = _village.get("_cast")
	return cast.call(&"actor", i).get("brain")


func _is_warming(i: int) -> bool:
	"""Whether resident `i` is on a warm-up break (warm_up_task.gd)."""
	var task: Variant = _brain(i).get("task")
	return task != null and (task as Object).get_script() == _warm_up_script


# --- the acceptance run (real time at 4x) -------------------------------------------------------------------------------

func _wait_for(stage: String, condition: Callable) -> void:
	"""Wait (at 4x, through stalls) until `condition()` holds, then check it."""
	_until = condition
	_until_name = stage
	_until_s = 0.0


func _look_below_at_the_home() -> void:
	"""The underground view over the home (its hearth's glow is drawn below)."""
	if _home < 0:
		return
	var centre: Vector2 = _village.call(&"rooms").call(&"centre_m", _home)
	_village.call(&"show_underground", true)
	_village.get("_camera").call(&"centre_on", Vector3(centre.x, 0.0, centre.y))


func _look_up() -> void:
	"""Back to the surface view."""
	_village.call(&"show_underground", false)


func _wait_home_heated() -> void:
	"""The home's hearth burns: its glow below."""
	_wait_for("the home heated, its hearth lit", func() -> bool:
		var lit: bool = _home >= 0 and bool(_winter().get("fuel").call(&"hearth_lit", _home))
		if lit:
			_capture("acc_home_heated")
		return lit)


func _wait_home_cold() -> void:
	"""The wood runs out: the home's hearth goes out and the room cools below freezing."""
	_wait_for("the home out of fuel and below freezing", func() -> bool:
		var fuel: Variant = _winter().get("fuel")
		var cold: bool = _home >= 0 and bool(fuel.call(&"is_out", _home)) and int(fuel.call(&"temperature_of", _home)) < 0
		if cold:
			_capture("acc_home_cold")
		return cold)


func _acceptance_wood() -> void:
	"""The acceptance run's winter opens with ACCEPTANCE_WOOD_MILLI in store: the hall's hearth burns about four hours."""
	_stores().set("wood_milli_u", ACCEPTANCE_WOOD_MILLI)
	_check("winter opens with about four hours of wood", int(_stores().get("wood_milli_u")) == ACCEPTANCE_WOOD_MILLI)


func _run_at_4x() -> void:
	"""Resume at 4x."""
	var gm: Node = root.get_node(^"GameManager")
	gm.call(&"resume_game")
	gm.call(&"set_speed", 4)
	_check("running at 4x", int(gm.call(&"get_effective_speed")) == 4)


func _wait_hall_out() -> void:
	"""The hall's hearth runs out and the hall cools."""
	_wait_for("the hall out of fuel and cooling", func() -> bool:
		var cooled: bool = _winter().fuel.is_out(HALL) and _winter().fuel.temperature_of(HALL) < HEATED_TENTHS
		if cooled and _pending_capture.is_empty():
			_capture("acc_hall_cold")
		return cooled)


func _wait_chilled() -> void:
	"""Someone outdoors becomes Chilled: selected, so the party panel says why."""
	_wait_for("a resident Chilled", func() -> bool:
		var who: int = _first_chilled()
		if who >= 0:
			_village.call(&"select_resident", who)
			_capture("acc_chilled")
		return who >= 0)


func _wait_firewood_worked() -> void:
	"""Someone takes up the urgent Firewood order."""
	_wait_for("the Firewood order taken", func() -> bool:
		var taken: bool = _winter().firewood_taken() or _stores().get("wood_milli_u") > 400
		if taken:
			_capture("acc_firewood")
		return taken)


func _wait_recovery() -> void:
	"""Firewood in: the hall relit, and Chilled residents warming up or warmed through."""
	_wait_for("recovery: the hall relit, the Chilled warming", func() -> bool:
		var relit: bool = _winter().fuel.is_heated(HALL)
		var warming: bool = _first_chilled() < 0 or _is_warming(_first_chilled()) \
			or int(_winter().get("breaks_sent")) > 0
		if relit and warming:
			_capture("acc_recovery")
		return relit and warming)


func _finish_log() -> void:
	"""Write the run's lines next to the frames."""
	if _capture_dir.is_empty():
		return
	var file := FileAccess.open(_capture_dir.path_join("acceptance_log.txt"), FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(_log) + "\n")
		var metrics: Dictionary = {}
		_winter().call(&"metrics_into", metrics)
		file.store_string(JSON.stringify(metrics) + "\n")
	_check("the log written", file != null)
