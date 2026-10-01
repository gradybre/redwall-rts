extends SceneTree
## The hall (decision 0771) on the REAL scene with real input: a click on the hall opens its panel, the tapestry opens
## from it and Esc closes it; the upgrade is refused while locked and opens with the first harvest; Plan sends the
## selected residents, the work board lists the hall, and the builders carry stone in on the running clock; then the
## rest is carried and built straight through the model (the suites drive whole rounds; here the frames matter): the
## work rail, the great hall, four banners, and the tapestry with every entry. Not discovered by the runner:
## test/test_demo_hall_live.gd runs it in its own process, as the other live harnesses are (decision 0261).
##
##     godot --headless --path godot --script res://test/live/demo_hall_live.gd [-- --size 1920x1080]
##         [-- --capture <dir>]   (not headless: saves the checked frames as PNGs)
##
## Prints `LIVE <name>: PASS|FAIL <detail>` per check and `LIVE-SUMMARY <checks> <failures>`; exits 1 on any failure.

const Rules := preload("res://demo/hall/hall_rules.gd")
const ProjectsScript := preload("res://demo/hall/hall_projects.gd")
const HallScript := preload("res://demo/hall/demo_hall.gd")
const WorkIds := preload("res://demo/work/work_ids.gd")
const TaskScript := preload("res://demo/work/work_task.gd")

const BOOT_FRAMES: int = 14
const SETTLE_FRAMES: int = 4
## Real seconds the builders are given at 4x to set the first stone down at the hall.
const CARRY_WAIT_S: float = 60.0
const HALL_FOCUS: Vector3 = Vector3(1.0, 0.0, -12.0)
const HALL_FACADE: Vector3 = Vector3(-2.6, 4.2, -9.9)

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
	"""Wait `count` frames, holding the window size (the headless server sizes the root to 64x64 at first)."""
	for k: int in count:
		if root.size != _size:
			root.size = _size
		await process_frame


func _run() -> void:
	"""Every step, then the summary."""
	await _frames(BOOT_FRAMES)
	await _the_hall_opens()
	await _the_tapestry_opens()
	await _the_first_harvest_opens_the_upgrade()
	await _plan_and_carry()
	await _raise_the_great_hall()
	await _hang_the_banners()
	await _the_full_tapestry()
	print("LIVE-SUMMARY %d %d" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


# --- helpers ------------------------------------------------------------------------------------------------------

func _check(check_name: String, ok: bool, detail: String = "") -> void:
	"""Record one check, named with the size."""
	_checks += 1
	if not ok:
		_failures += 1
	print("LIVE %dx%d %s: %s %s" % [_size.x, _size.y, check_name, "PASS" if ok else "FAIL", detail])


func _manager() -> Object:
	"""The GameManager autoload."""
	return root.get_node(^"GameManager")


func _hall() -> HallScript:
	"""The village's hall."""
	return _village.call(&"hall") as HallScript


func _projects() -> ProjectsScript:
	"""The hall's projects."""
	return _hall().projects


func _look_at_hall(distance: float) -> void:
	"""Centre the camera over the hall at `distance`, and let it settle."""
	var camera: Node = _village.get("_camera")
	camera.set("_target_distance", distance)
	camera.call(&"centre_on", HALL_FOCUS)
	camera.call(&"snap")
	await _frames(SETTLE_FRAMES)


func _click_at(at: Vector2) -> void:
	"""A left click at `at` (viewport pixels), through the Viewport."""
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


func _open_point_on_hall() -> Vector2:
	"""A point on the hall's facade, in the window, with no HUD control over it (the HUD and panels take clicks
	first): the first of a grid over the facade."""
	var camera: Camera3D = (_village.get("_camera") as Node).call(&"camera")
	for y: float in [4.0, 2.5, 5.5, 1.5]:
		for x: float in [-3.0, 3.0, -1.0, 1.0, -5.0, 5.0]:
			var at: Vector2 = camera.unproject_position(Vector3(x, y, HALL_FACADE.z))
			if not Rect2(Vector2.ZERO, Vector2(_size)).has_point(at):
				continue
			var motion := InputEventMouseMotion.new()
			motion.position = at
			root.push_input(motion)
			await _frames(1)
			if root.gui_get_hovered_control() == null:
				return at
	return camera.unproject_position(HALL_FACADE)


func _reveal(control: Control) -> void:
	"""Scroll `control`'s scroll to it (as focus does), and wait for it to move."""
	var at: Node = control.get_parent()
	while at != null and not at is ScrollContainer:
		at = at.get_parent()
	if at != null and at.has_method(&"reveal"):
		at.call(&"reveal", control)
	await _frames(2)


func _click(control: Control) -> void:
	"""A left click at `control`'s centre."""
	_click_at(control.get_global_transform_with_canvas() * (control.size / 2.0))


func _key(code: Key) -> void:
	"""Press and release one key through the Viewport."""
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		root.push_input(event)


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


static func _straight_in(projects: ProjectsScript, project: int) -> void:
	"""Carry what `project` still needs straight in from the stores (the rounds are the suites')."""
	for mat: int in Rules.MAT_COUNT:
		var left: int = projects.outstanding(project, mat)
		if left > 0:
			projects.deliver(project, mat, projects.lift(project, mat, projects.reserve(project, mat, left)))


# --- the steps ------------------------------------------------------------------------------------------------------

func _the_hall_opens() -> void:
	"""A click on the hall's facade opens its panel, in the window, at stage 1, its upgrade locked."""
	_check("the hall is built", _hall() != null)
	_check("stage 1 is woven at the start", _hall().tapestry.count() == 1, "%d" % _hall().tapestry.count())
	await _look_at_hall(26.0)
	_click_at(await _open_point_on_hall())
	await _frames(SETTLE_FRAMES)
	_check("a click on the hall opens its panel", _hall().panel.is_open())
	_check("the panel is in the window", _within(_hall().panel.frame_rect()), str(_hall().panel.frame_rect()))
	_check("it is the community hall", _hall().panel.title_text() == "Community hall", _hall().panel.title_text())
	var plan: Button = _hall().panel.button(&"plan_upgrade")
	_check("Plan is dimmed while locked, saying why", plan.disabled and plan.tooltip_text.begins_with("The upgrade opens"),
		plan.tooltip_text)
	_floors("the hall's panel", _hall().panel)
	await _capture("hall_panel_stage1")


func _the_tapestry_opens() -> void:
	"""The tapestry opens from the panel, stands in for it, and Esc closes it."""
	_click(_hall().panel.button(&"tapestry"))
	await _frames(SETTLE_FRAMES)
	var tapestry: Node = _hall().tapestry_panel
	_check("the tapestry opens from the hall", tapestry.call(&"is_open") and not _hall().panel.is_open())
	_check("its one entry is drawn", int(tapestry.call(&"shown_entries")) == 1)
	_check("the tapestry is in the window", _within(tapestry.call(&"frame_rect")))
	_floors("the tapestry", tapestry)
	await _capture("tapestry_start")
	if tapestry.call(&"is_open"):
		_key(KEY_ESCAPE)
	await _frames(SETTLE_FRAMES)
	_check("Esc closes the tapestry", not tapestry.call(&"is_open"))
	_check("and opens nothing else in its place", not _hall().panel.is_open() and not bool(_village.call(&"menu").get(
		&"visible")))


func _the_first_harvest_opens_the_upgrade() -> void:
	"""The farm's harvest log gains its first harvest (as farm_crew.gd writes it): woven, and the upgrade opens."""
	var crew: RefCounted = (_village.get("_farm") as Node).get("crew")
	crew.set("harvested_by", PackedInt32Array([0]))
	crew.set("harvested_bed", PackedInt32Array([2]))
	crew.set("harvested_item", PackedInt32Array([0]))
	crew.set("harvests", 1)
	await _frames(SETTLE_FRAMES)
	_check("the first harvest is woven", _hall().tapestry.has_key(HallScript.KEY_FIRST_HARVEST))
	_check("the upgrade opens", _projects().unlocked)
	_check("the work board lists the hall", (_village.call(&"work").get("board") as RefCounted).call(&"source",
		WorkIds.SOURCE_HALL) != null)


func _plan_and_carry() -> void:
	"""Four selected residents sent by Plan; the board lists their places; on the running clock stone reaches the hall."""
	(_village.get("_services") as RefCounted).get("stores").call(&"add_stone", 30000)
	_village.get("_command").call(&"select", PackedInt32Array([0, 1, 2, 3]))
	_hall().open()
	await _frames(SETTLE_FRAMES)
	var plan: Button = _hall().panel.button(&"plan_upgrade")
	_check("Plan is offered once open", not plan.disabled, plan.tooltip_text)
	await _reveal(plan)
	_click(plan)
	await _frames(SETTLE_FRAMES)
	_check("Plan answers on the panel", _hall().panel.message_text().begins_with("Upgrade planned"),
		_hall().panel.message_text())
	_check("the selected set off", _hall().crew.builders_on(Rules.PROJECT_UPGRADE) == 4,
		"%d" % _hall().crew.builders_on(Rules.PROJECT_UPGRADE))
	var task := TaskScript.new()
	var board: RefCounted = _village.call(&"work").get("board")
	_check("the Work screen's row", bool(board.call(&"fill", WorkIds.SOURCE_HALL, 0, task))
		and task.action == "Raise the great hall", task.action)
	_hall().panel.close_window()
	await _carry_some()


func _carry_some() -> void:
	"""Run at 4x until a load is set down at the hall (or CARRY_WAIT_S passes)."""
	var started: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < int(CARRY_WAIT_S * 1000.0):
		_keep_running(4)
		await _frames(1)
		if _projects().delivered_permille(Rules.PROJECT_UPGRADE) > 0:
			break
	_check("the builders carry a load to the hall", _projects().delivered_permille(Rules.PROJECT_UPGRADE) > 0,
		"%d per mille" % _projects().delivered_permille(Rules.PROJECT_UPGRADE))
	await _look_at_hall(24.0)
	await _capture("hall_delivering")
	_manager().call(&"set_speed", 1)


func _raise_the_great_hall() -> void:
	"""The rest carried straight in: building, the work rail; the work done: tier 2, the great hall, woven."""
	_straight_in(_projects(), Rules.PROJECT_UPGRADE)
	var started: int = Time.get_ticks_msec()
	while _projects().phase[Rules.PROJECT_UPGRADE] == ProjectsScript.PHASE_DELIVERING \
			and Time.get_ticks_msec() - started < 20000:
		_keep_running(4)
		await _frames(1)
	_check("building once everything is delivered",
		_projects().phase[Rules.PROJECT_UPGRADE] == ProjectsScript.PHASE_BUILDING)
	await _frames(SETTLE_FRAMES)
	_check("the work rail stands", _hall().view.scaffold_shown())
	await _capture("hall_building")
	_projects().add_work(Rules.PROJECT_UPGRADE, _projects().work_left_usec(Rules.PROJECT_UPGRADE), 0)
	await _frames(SETTLE_FRAMES)
	_check("tier 2", _projects().tier == Rules.TIER_GREAT)
	_check("the great hall is drawn", _hall().view.great_shown() and not _hall().view.scaffold_shown())
	_check("stage 2 is woven", _hall().tapestry.has_key(HallScript.KEY_STAGE_2))
	_hall().open()
	await _frames(SETTLE_FRAMES)
	_check("the panel names the great hall", _hall().panel.title_text() == "Great hall")
	_check("a second upgrade is refused (BAL-SAFE-013)", _hall().panel.button(&"plan_upgrade").disabled)
	await _capture("hall_panel_stage2")
	_hall().panel.close_window()


func _hang_the_banners() -> void:
	"""Four banners planned with the panel's button, a fifth refused; hung, each drawn; comfort 9500."""
	_hall().open()
	await _frames(SETTLE_FRAMES)
	var hang: Button = _hall().panel.button(&"plan_banner")
	for k: int in Rules.BANNERS_MAX:
		await _reveal(hang)
		_click(hang)
		await _frames(SETTLE_FRAMES)
	_check("four banners planned", _projects().banners_planned() == 4, "%d" % _projects().banners_planned())
	_check("a fifth is refused", hang.disabled)
	_hall().panel.close_window()
	for p: int in range(Rules.PROJECT_BANNER_FIRST, Rules.PROJECT_COUNT):
		_hall().crew.release_project(p)
		_straight_in(_projects(), p)
		_projects().add_work(p, _projects().work_left_usec(p), 0)
	await _frames(SETTLE_FRAMES)
	_check("four banners drawn", _hall().view.shown_banners() == 4)
	_check("comfort 9500", _hall().comfort_target() == 9500, "%d" % _hall().comfort_target())
	await _look_at_hall(24.0)
	await _capture("hall_great")
	await _look_at_hall(40.0)
	await _capture("hall_great_far")


func _the_full_tapestry() -> void:
	"""Every entry drawn: stage 1, the first harvest, stage 2 and four banners."""
	_hall().open_tapestry()
	await _frames(SETTLE_FRAMES)
	var tapestry: Node = _hall().tapestry_panel
	_check("seven entries drawn", int(tapestry.call(&"shown_entries")) == 7, "%d" % int(tapestry.call(&"shown_entries")))
	_check("woven oldest first", String(tapestry.call(&"entry_title", 0)) == "Stage 1: the community hall")
	_floors("the full tapestry", tapestry)
	await _capture("tapestry_full")
	_check("the hall is a planning surface while open", _hall().is_open())
	tapestry.call(&"close_window")
