extends SceneTree
## The orchard on the REAL scene with REAL Viewport input (decisions 0671-0677): a left click on the old apple brings
## the tab-less Orchard panel into the right column (inside the window, no tab lit); its verbs and their cards; the Tend
## button and a right click on the pear give the selected residents the work; a tab takes the zone back; the work board
## lists the orchard's jobs; the grove stops the woods felling; the fruit trees wear the season; and a resident tends the
## apple in game time. Not discovered by the runner: test/test_demo_orchard_live.gd runs it in its own process.
##
##     godot --headless --path godot --script res://test/live/demo_orchard_live.gd [-- --size 1920x1080]
##         [-- --capture <dir>]   (not headless: saves the checked frames as PNGs)
##
## Prints `LIVE <name>: PASS|FAIL <detail>` per check and `LIVE-SUMMARY <checks> <failures>`; exits 1 on a failure.

const DetailZone := preload("res://demo/ui/demo_detail_zone.gd")
const Rules := preload("res://demo/orchard/orchard_rules.gd")
const JobsScript := preload("res://demo/orchard/orchard_jobs.gd")
const WorkIds := preload("res://demo/work/work_ids.gd")
const LookScript := preload("res://demo/seasons/season_look.gd")
const ForestJobs := preload("res://demo/forestry/forest_jobs.gd")
const ForestCrew := preload("res://demo/forestry/forest_crew.gd")
const ForestStand := preload("res://demo/forestry/forest_stand.gd")

const BOOT_FRAMES: int = 12
const STEP_FRAMES: int = 3
## How many frames the tending may take in game time at 4x (bounded: the walk is ~30 m, the work 20 WU).
const TEND_FRAMES: int = 2400

var _village: Node = null
var _wait: int = BOOT_FRAMES
var _steps: Array[Callable] = []
var _checks: int = 0
var _failures: int = 0
var _size: Vector2i = Vector2i(1280, 720)
var _capture_dir: String = ""
var _pending_capture: String = ""
var _tend_frames: int = 0


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
	_steps = [_pause, _the_orchard_is_wired, _look_at_the_old_orchard, _click_the_old_apple, _its_verbs_and_cards,
		_tend_with_a_resident_selected, _right_click_the_pear, _a_tab_takes_the_zone_back, _the_board_lists_the_jobs,
		_the_grove_stops_the_felling, _the_trees_wear_the_season, _run_at_4x, _the_apple_is_tended]


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


func _click(at: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	"""A click at `at` with `button`."""
	var motion := InputEventMouseMotion.new()
	motion.position = at
	root.push_input(motion)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = button
		event.position = at
		event.pressed = down
		event.button_mask = (MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT) if down else 0
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


func _orchard() -> Node:
	"""The village's orchard."""
	return _village.call(&"orchard")


func _zone() -> DetailZone:
	"""The right column."""
	return _village.get("_zone")


func _screen_of(at: Vector2, height: float) -> Vector2:
	"""Where a ground point `height` m up is on screen."""
	var camera: Camera3D = root.get_viewport().get_camera_3d()
	return camera.unproject_position(Vector3(at.x, height, at.y))


func _fits(rect: Rect2) -> bool:
	"""Whether a rectangle lies inside the window."""
	return Rect2(Vector2.ZERO, Vector2(_size)).grow(1.0).encloses(rect)


# --- the steps ----------------------------------------------------------------------------------------------------------

func _pause() -> void:
	"""Pause as the player (orders are carried out on resume)."""
	root.get_node(^"GameManager").call(&"pause_game")


func _the_orchard_is_wired() -> void:
	"""The node, its stands among the pantry's stores, its trees as real rows."""
	_check("the orchard is built", _orchard() != null)
	var storage: RefCounted = _village.get("_farm").get("pantry").get("storage")
	var read := preload("res://scripts/core/int_math.gd").IntResult.new()
	_check("its stands are pantry stores", storage.call(&"index_of_id_into", Rules.STAND_IDS[0], read) \
		and bool(storage.call(&"is_staging", read.value)))
	_check("the old trees are real rows", int(_orchard().get("model").get("store").call(&"orchard_count")) == 2)


func _look_at_the_old_orchard() -> void:
	"""The camera over the old orchard from the north."""
	var camera: Node = _village.get("_camera")
	camera.set("_target_focus", Vector3(-12.0, 0.0, 30.0))
	camera.set("_target_distance", 24.0)
	camera.set("_target_pitch", deg_to_rad(48.0))
	camera.set("_target_yaw", deg_to_rad(180.0))
	camera.call(&"snap")


func _click_the_old_apple() -> void:
	"""A left click on the apple's trunk: selected, the Orchard panel in the right column, inside the window, no tab lit."""
	_click(_screen_of(Rules.site_centre_m(0), 0.3))
	var panel: CanvasLayer = _orchard().get("panel")
	_check("a click on the apple selects it", int(_orchard().get("selected_kind")) == 1 and int(_orchard().get("selected_id")) == 0,
		"%s %s" % [_orchard().get("selected_kind"), _orchard().get("selected_id")])
	_check("the Orchard panel is shown", bool(panel.call(&"is_shown")))
	_check("it holds the right column", _zone().shown == DetailZone.PANEL_ORCHARD)
	var lit: bool = false
	for k: int in 4:
		lit = lit or _zone().tab(k).button_pressed
	_check("no tab is lit", not lit)
	_check("the panel fits the window", _fits(panel.call(&"frame_rect")), str(panel.call(&"frame_rect")))
	_capture("orchard_panel")


func _its_verbs_and_cards() -> void:
	"""Tend and Harvest shown; in spring Tend may be pressed and Harvest says why not."""
	var panel: CanvasLayer = _orchard().get("panel")
	_orchard().call(&"refresh_panel")
	_check("the panel names the tree", String(panel.call(&"line", &"title")) == "The old apple", panel.call(&"line", &"title"))
	var tend: Button = panel.call(&"button", &"tend")
	var harvest: Button = panel.call(&"button", &"harvest")
	_check("Tend may be pressed", tend.visible and not tend.disabled)
	_check("Harvest is refused in spring", harvest.visible and harvest.disabled)
	_check("its card says why", harvest.tooltip_text.contains("Can't now"), harvest.tooltip_text)


func _tend_with_a_resident_selected() -> void:
	"""Resident 0 selected, the Tend button clicked: the tending is hers."""
	_village.get("_command").call(&"select", PackedInt32Array([0]))
	_orchard().call(&"refresh_panel")
	var tend: Button = _orchard().get("panel").call(&"button", &"tend")
	_click(_centre(tend))
	var jobs: RefCounted = _orchard().get("jobs")
	var j: int = int(jobs.call(&"find", JobsScript.K_TEND, 0))
	_check("Tend orders the selected resident", j >= 0 and int(jobs.get("worker")[j]) == 0, "job %d" % j)


func _right_click_the_pear() -> void:
	"""Resident 1 selected, a right click on the pear: its most pressing work (spring: tending) is hers."""
	_village.get("_command").call(&"select", PackedInt32Array([1]))
	_click(_screen_of(Rules.site_centre_m(1), 0.3), MOUSE_BUTTON_RIGHT)
	var jobs: RefCounted = _orchard().get("jobs")
	var j: int = int(jobs.call(&"find", JobsScript.K_TEND, 1))
	_check("a right click gives her the pear's tending", j >= 0 and int(jobs.get("worker")[j]) == 1, "job %d" % j)
	_check("the selection follows the click", int(_orchard().get("selected_id")) == 1)


func _a_tab_takes_the_zone_back() -> void:
	"""The Woods tab clicked: the Orchard panel goes, the woods' comes."""
	_click(_centre(_zone().tab(DetailZone.PANEL_WOODS)))
	_check("the Woods tab takes the zone", _zone().shown == DetailZone.PANEL_WOODS)
	_check("the Orchard panel is hidden", not bool(_orchard().get("panel").call(&"is_shown")))


func _the_board_lists_the_jobs() -> void:
	"""The work board's source 11 is the orchard's, with its jobs."""
	var board: RefCounted = _village.get("_work").get("board")
	var source: RefCounted = board.call(&"source", WorkIds.SOURCE_ORCHARD)
	_check("the board has the orchard's source", source != null)
	var live: int = 0
	for row: int in JobsScript.MAX_JOBS:
		live += 1 if source != null and bool(source.call(&"live", row)) else 0
	_check("its jobs are listed", live >= 2, "%d" % live)


func _the_grove_stops_the_felling() -> void:
	"""A mature woods tree in the protected grove: a fell is refused."""
	var forestry: Node = _village.get("_forestry")
	var stand: RefCounted = forestry.get("stand")
	var refused: int = 0
	for t: int in int(stand.call(&"count")):
		var at: Vector2 = stand.get("at")[t]
		if at.distance_to(Rules.GROVE_AT) <= Rules.GROVE_RADIUS_M and int(stand.call(&"state_of", t)) == ForestStand.STATE_MATURE:
			var code: String = forestry.get("crew").call(&"refusal_for", ForestJobs.KIND_FELL, t, 0)
			refused += 1 if code == ForestCrew.REFUSE_GROVE else 0
	_check("the grove's trees are never felled", refused >= 1, "%d refused" % refused)


func _the_trees_wear_the_season() -> void:
	"""The fruit trees are among the season's trees (staged: their meshes dressed as KIND_FRUIT)."""
	var seasons: Node = _village.call(&"seasons")
	var fruit: int = 0
	for i: int in int(seasons.call(&"dressed_count")):
		fruit += 1 if int(seasons.call(&"kind_of", i)) == LookScript.KIND_FRUIT else 0
	var staged: bool = ResourceLoader.exists("res://demo/assets/world/oak_mature.glb")
	_check("the fruit trees wear the season", fruit >= 4 or not staged, "%d fruit meshes" % fruit)


func _run_at_4x() -> void:
	"""Resume at 4x."""
	root.get_node(^"GameManager").call(&"resume_game")
	root.get_node(^"GameManager").call(&"set_speed", 4)
	_steps.push_front(_wait_for_tending)


func _wait_for_tending() -> void:
	"""Run until the apple is tended (bounded)."""
	root.get_node(^"GameManager").call(&"acknowledge_overload")
	_tend_frames += STEP_FRAMES
	if not bool(_orchard().get("model").call(&"tended_today", 0)) and _tend_frames < TEND_FRAMES:
		_steps.push_front(_wait_for_tending)


func _the_apple_is_tended() -> void:
	"""The selected resident walked to the apple and did its 20 WU."""
	_check("the apple is tended in game time", bool(_orchard().get("model").call(&"tended_today", 0)),
		"after %d frames" % _tend_frames)
