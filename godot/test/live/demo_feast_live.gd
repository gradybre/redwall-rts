extends SceneTree
## The called feasts (decision 1701) on the REAL scene with real input: the HUD's Feast command opens the Feasts panel
## (in the window, its text and buttons at the floors), which says what each theme needs; stocked, the Hearth feast is
## called by its button for today's 17:00 supper (Brendan's ruling on Q-D11), the regatta is refused while it is
## planned, and on the running clock the village sits down to it: tallied, completed, Shared Warmth on the winter's cold,
## M4's "feasts" measured. Not discovered by the runner: test/test_demo_feast_live.gd runs it in its own process at both
## sizes, as the other live harnesses are (decision 0261).
##
##     godot --headless --path godot --script res://test/live/demo_feast_live.gd [-- --size 1920x1080]
##         [-- --capture <dir>]   (not headless: saves the checked frames as PNGs)
##
## Prints `LIVE <name>: PASS|FAIL <detail>` per check and `LIVE-SUMMARY <checks> <failures>`; exits 1 on any failure.

const CalendarScript := preload("res://demo/demo_calendar.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const Rules := preload("res://demo/feast/feast_rules.gd")
## called_feast.gd's states (not preloaded, for the same reason).
const ST_IDLE: int = 0
const ST_PREPARING: int = 1
const ST_ACTIVE: int = 2
## UiShell.ID_FEAST (scripts/ui/ui_shell.gd is not preloaded here: it names an autoload, which --script mode has not
## registered when this script compiles).
const ID_FEAST: int = 32
const IntMath := preload("res://scripts/core/int_math.gd")

const BOOT_FRAMES: int = 14
const SETTLE_FRAMES: int = 4
## Real seconds the village is given at 4x to cook, eat and tally the feast (about 5 game hours: 32 s).
const FEAST_WAIT_S: float = 120.0
## The hall's tables (world_layout.gd `table_e` at (5, -7)) and how far the camera stands back for the supper frame.
const TABLES_FOCUS: Vector3 = Vector3(3.0, 0.0, -7.0)
const TABLES_DISTANCE: float = 18.0
const PEA: int = 11
const CABBAGE: int = 6
const WHEAT: int = 13
const CARROT: int = 2

var _village: Node = null
var _size: Vector2i = Vector2i(1280, 720)
var _capture_dir: String = ""
var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	"""Read the arguments, size the window, boot the village and run the checks."""
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
	_run.call_deferred()


func _frames(count: int) -> void:
	"""Wait `count` frames, holding the window size."""
	for k: int in count:
		if root.size != _size:
			root.size = _size
		await process_frame


func _run() -> void:
	"""Every step, then the summary."""
	await _frames(BOOT_FRAMES)
	await _the_command_opens_the_panel()
	await _call_the_hearth_feast()
	await _the_village_sits_down()
	print("LIVE-SUMMARY %d %d" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


# --- helpers ------------------------------------------------------------------------------------------------------

func _check(check_name: String, ok: bool, detail: String = "") -> void:
	"""Record one check, named with the size."""
	_checks += 1
	if not ok:
		_failures += 1
	print("LIVE %dx%d %s: %s %s" % [_size.x, _size.y, check_name, "PASS" if ok else "FAIL", detail])


func _feasts() -> Node:
	"""The village's called feasts (demo/feast/demo_feasts.gd)."""
	return _village.call(&"feasts") as Node


func _feast() -> RefCounted:
	"""The called feast's model."""
	return _feasts().get(&"feast") as RefCounted


func _manager() -> Object:
	"""The GameManager autoload."""
	return root.get_node(^"GameManager")


func _click(control: Control) -> void:
	"""A left click at `control`'s centre, through the Viewport."""
	var at: Vector2 = control.get_global_transform_with_canvas() * (control.size / 2.0)
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


func _reveal(control: Control) -> void:
	"""Scroll `control`'s scroll to it, and wait for it to move."""
	var at: Node = control.get_parent()
	while at != null and not at is ScrollContainer:
		at = at.get_parent()
	if at != null and at.has_method(&"reveal"):
		at.call(&"reveal", control)
	await _frames(2)


func _within(rect: Rect2) -> bool:
	"""Whether `rect` lies inside the window."""
	return Rect2(Vector2.ZERO, Vector2(_size)).grow(0.5).encloses(rect)


func _floors(what: String, layer: Node) -> void:
	"""Every shown label and button under `layer` at least 14 px; every shown button at least 32 px tall."""
	var bad := PackedStringArray()
	for node: Node in layer.find_children("*", "Control", true, false):
		var control := node as Control
		if not (control is Label or control is Button) or not control.is_visible_in_tree():
			continue
		if String(control.get(&"text")).is_empty():
			continue
		if control.get_theme_font_size(&"font_size") < 14 or (control is Button and control.size.y < 32.0 - 0.01):
			bad.append("%s %dpx %.0f" % [control.name, control.get_theme_font_size(&"font_size"), control.size.y])
	_check("%s: text 14 px, buttons 32 px" % what, bad.is_empty(), ", ".join(bad))


func _capture(file_name: String) -> void:
	"""Save the frame now (only when asked for, and never headless)."""
	if _capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await _frames(3)
	root.get_texture().get_image().save_png(_capture_dir.path_join("%s_%dx%d.png" % [file_name, _size.x, _size.y]))
	_manager().set("_last_host_usec", Time.get_ticks_usec())


func _keep_running(speed: int) -> void:
	"""The clock at `speed`, past any stall (the harness acknowledges it, as the player's Resume does)."""
	var manager: Object = _manager()
	if bool(manager.call(&"is_paused")):
		manager.call(&"acknowledge_overload")
		manager.call(&"resume_game")
	if int(manager.call(&"get_speed")) != speed:
		manager.call(&"set_speed", speed)


func _stock(item: int, milli: int) -> void:
	"""`milli` of `item` into the kitchen's pantry (as a harvest or a trip would bring it)."""
	var read := IntMath.IntResult.new()
	var stocked: bool = _feast().kitchen.pantry.add_into(item, milli, 0, read)
	if not stocked:
		_check("stocked item %d" % item, false, read.error)


func _look_at_tables() -> void:
	"""Centre the camera over the hall's tables (the kitchen's seats) and let it settle."""
	var camera: Node = _village.get("_camera")
	camera.set("_target_distance", TABLES_DISTANCE)
	camera.call(&"centre_on", TABLES_FOCUS)
	camera.call(&"snap")
	await _frames(SETTLE_FRAMES)


func _stock_the_hearth() -> void:
	"""The Hearth feast's food beside what the kitchen's own planned meals hold, wood and water in store."""
	for item: int in [PEA, CABBAGE, Catalog.ITEM_NUTS]:
		_stock(item, 24000)
	_stock(Catalog.ITEM_FLOUR, 60000)
	_stock(Catalog.ITEM_HERB, 2000)
	_stock(WHEAT, 20000)
	_stock(CARROT, 20000)
	(_village.get("_services") as RefCounted).get("stores").call(&"add_wood", 60000)
	(_village.get("_services") as RefCounted).get("stores").call(&"add_water", 20000)


# --- the steps ------------------------------------------------------------------------------------------------------

func _the_command_opens_the_panel() -> void:
	"""The HUD's Feast command opens the Feasts panel: in the window, at the floors, every theme saying what it needs."""
	_check("the feasts are built", _feasts() != null)
	var shell: Node = _village.call(&"_shell") as Node
	var command: Button = shell.call(&"control_for", ID_FEAST) as Button if shell != null else null
	_check("the Feast command is enabled", command != null and not command.disabled)
	if command != null:
		_click(command)
	await _frames(SETTLE_FRAMES)
	var panel: Node = _feasts().get(&"panel")
	_check("the Feast command opens the Feasts panel", panel.call(&"is_open"))
	_check("the panel is in the window", _within(panel.call(&"frame_rect")), str(panel.call(&"frame_rect")))
	var themes: String = panel.call(&"text_of", &"themes")
	_check("each theme says what it needs or that it is ready", themes.split("\n").size() == Rules.THEME_COUNT, themes)
	_check("M4's feasts are measured", bool((_village.call(&"guide").get(&"goals").get(&"book").call(&"part_of",
		&"m4_hearth_charter", &"feasts")).call(&"is_measured")))
	_floors("the Feasts panel", panel)
	await _capture("feasts_panel_open")


func _call_the_hearth_feast() -> void:
	"""At 14:00 with the Hearth's food in store, Call holds today's supper; the regatta is then refused."""
	_village.get("_farm").call(&"advance_calendar", 8 * CalendarScript.HOUR_USEC)
	_village.get("_winter").call(&"catch_up")
	_stock_the_hearth()
	await _frames(SETTLE_FRAMES)
	var panel: Node = _feasts().get(&"panel")
	panel.call(&"refresh")
	var themes: String = String(panel.call(&"text_of", &"themes"))
	_check("the Hearth can be made", themes.contains("Hearth: every course can be made"), themes.get_slice("\n", 0))
	_check("today's supper is offered", _feast().choice_day == _feast().today(), "%d" % _feast().choice_day)
	var call_button: Button = panel.call(&"button", &"call")
	await _reveal(call_button)
	await _capture("feasts_panel_ready")
	if call_button.disabled:
		_click(panel.call(&"button", &"override"))
		await _frames(SETTLE_FRAMES)
	_click(call_button)
	await _frames(SETTLE_FRAMES)
	_check("Call holds the feast", _feast().state == ST_PREPARING, String(panel.call(&"text_of", &"message")))
	_check("the panel says so", String(panel.call(&"text_of", &"status")).contains("preparing"))
	var regatta: RefCounted = _village.call(&"regatta").get(&"regatta")
	var clash: String = String((regatta.get(&"feast_clash") as Callable).call(_feast().today() + 20))
	_check("the regatta waits on it (one feast prepared at a time)", clash.contains("one feast is prepared at a time"), clash)
	await _capture("feasts_panel_called")
	panel.call(&"close_window")


func _the_village_sits_down() -> void:
	"""On the running clock the supper is the feast: served, tallied, completed; Shared Warmth on the cold."""
	var started: int = Time.get_ticks_msec()
	var looked: bool = false
	while Time.get_ticks_msec() - started < int(FEAST_WAIT_S * 1000.0) and _feast().state != ST_IDLE:
		_keep_running(4)
		await _frames(1)
		if not looked and _feast().state == ST_ACTIVE and _feast().hour() >= 17 and _feast().kitchen.portions_eaten > 0:
			looked = true
			await _look_at_tables()
			await _capture("feast_at_supper")
	_check("the feast is tallied", _feast().state == ST_IDLE, _feast().last_line)
	_check("residents shared it", _feast().attendees.size() > 0, _feast().last_line)
	_check("it is completed", _feast().completed == 1 and int(_feasts().call(&"feasts_completed")) >= 1)
	var warm: bool = _feast().buffs.active(Rules.HEARTH, _feast().now_tick())
	var cold: int = int(_village.get("_winter").get("cold").get("gain_permille"))
	_check("Shared Warmth granted (everyone ate every course)", warm, _feast().last_line)
	_check("and it reaches the winter's cold", cold == 750, "%d" % cold)
	_manager().call(&"set_speed", 1)
	_feasts().get(&"panel").open()
	await _frames(SETTLE_FRAMES)
	_check("the panel shows the last feast", String(_feasts().get(&"panel").call(&"text_of", &"last")).contains("Hearth feast"))
	await _capture("feasts_panel_after")
	_feasts().get(&"panel").close_window()
