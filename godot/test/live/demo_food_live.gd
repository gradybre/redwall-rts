extends SceneTree
## The food lanes on the REAL scene with REAL Viewport input (decision 1601 onward): the apiary's skep and bees beside the
## old orchard, a left click on the skep bringing the Orchard panel with the apiary's readout and verbs. Not discovered by
## the runner: test/test_demo_food_live.gd runs it in its own process.
##
##     godot --headless --path godot --script res://test/live/demo_food_live.gd [-- --size 1920x1080]
##         [-- --capture <dir>]   (not headless: saves the checked frames as PNGs)
##
## Prints `LIVE <name>: PASS|FAIL <detail>` per check and `LIVE-SUMMARY <checks> <failures>`; exits 1 on a failure.

const DetailZone := preload("res://demo/ui/demo_detail_zone.gd")
const HiveRules := preload("res://demo/hives/hive_rules.gd")
## demo_orchard.gd SEL_APIARY (named here: its script needs the autoloads a --script run has not registered yet).
const SEL_APIARY: int = 6

const BOOT_FRAMES: int = 12
const STEP_FRAMES: int = 3

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
	_steps = [_pause, _the_apiary_is_wired, _look_at_the_apiary, _click_the_skep, _its_readout_and_verbs,
		_close_on_the_bees]


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
	"""The village's orchard (the apiary's owner)."""
	return _village.call(&"orchard")


func _zone() -> DetailZone:
	"""The right column."""
	return _village.get("_zone")


func _screen_of(at: Vector2, height: float) -> Vector2:
	"""Where a ground point `height` m up is on screen."""
	return root.get_viewport().get_camera_3d().unproject_position(Vector3(at.x, height, at.y))


func _fits(rect: Rect2) -> bool:
	"""Whether a rectangle lies inside the window."""
	return Rect2(Vector2.ZERO, Vector2(_size)).grow(1.0).encloses(rect)


func _look_at(at: Vector3, distance: float, pitch_deg: float, yaw_deg: float) -> void:
	"""The camera on `at` from `distance` m."""
	var camera: Node = _village.get("_camera")
	camera.set("_target_focus", at)
	camera.set("_target_distance", distance)
	camera.set("_target_pitch", deg_to_rad(pitch_deg))
	camera.set("_target_yaw", deg_to_rad(yaw_deg))
	camera.call(&"snap")


# --- the steps ----------------------------------------------------------------------------------------------------------

func _pause() -> void:
	"""Pause as the player."""
	root.get_node(^"GameManager").call(&"pause_game")


func _the_apiary_is_wired() -> void:
	"""Decision 1601: the hive is a real row in the orchard's store, its skep drawn, its bees out in spring."""
	var model: RefCounted = _orchard().get("model")
	_check("the hive is a real row", int(model.get("store").call(&"hive_count")) == HiveRules.APIARY_COUNT)
	var view: Node3D = _orchard().get("apiary_view")
	_check("the skep is drawn", view != null and (view.get("skeps") as Array).size() == HiveRules.APIARY_COUNT)
	_check("the bees are out in spring", view != null and ((view.get("swarms") as Array)[0] as Node3D).visible)
	var staged: bool = ResourceLoader.exists("res://demo/assets/world/bee_skep.glb") \
		or ResourceLoader.exists("res://demo/assets/props/bee_skep.glb")
	_check("the old trees are pollinated", _old_apple_factor() == 1100, "factor %d (skep staged: %s)" % [_old_apple_factor(),
		staged])


func _old_apple_factor() -> int:
	"""REQ-SET-082's factor on the old apple, read from the store."""
	var model: RefCounted = _orchard().get("model")
	var read := preload("res://scripts/core/int_math.gd").IntResult.new()
	var ok: bool = model.get("store").call(&"orchard_pollination_factor_into", int(model.call(&"slot_of", 0)), read)
	return read.value if ok else -1


func _look_at_the_apiary() -> void:
	"""The camera over the skep and the old orchard behind it, from the north."""
	var at: Vector2 = HiveRules.centre_m(0)
	_look_at(Vector3(at.x, 0.0, at.y + 3.0), 16.0, 42.0, 180.0)
	_capture("apiary")


func _click_the_skep() -> void:
	"""A left click on the skep: the apiary selected, the Orchard panel in the right column, inside the window."""
	_click(_screen_of(HiveRules.centre_m(0), 0.4))
	var panel: CanvasLayer = _orchard().get("panel")
	_check("a click on the skep selects the apiary", int(_orchard().get("selected_kind")) == SEL_APIARY,
		"%s" % _orchard().get("selected_kind"))
	_check("the Orchard panel is shown", bool(panel.call(&"is_shown")))
	_check("it holds the right column", _zone().shown == DetailZone.PANEL_ORCHARD)
	_check("the panel fits the window", _fits(panel.call(&"frame_rect")), str(panel.call(&"frame_rect")))
	_capture("apiary_panel")


func _its_readout_and_verbs() -> void:
	"""The apiary's title, its readout (ECO-011's crops, ECO-012's feed), its verbs with their cards."""
	var panel: CanvasLayer = _orchard().get("panel")
	_orchard().call(&"refresh_panel")
	_check("the panel names the apiary", String(panel.call(&"line", &"title")) == "The apiary", panel.call(&"line", &"title"))
	var text: String = panel.call(&"line", &"text")
	_check("it says which crops benefit", text.contains("the old apple") and text.contains("beans in bed"), text)
	_check("it shows the winter feed", text.contains("winter feed"), text)
	var service: Button = panel.call(&"button", &"service")
	_check("Tend the bees is shown", service.visible)
	_check("its card says why not on the founding day", service.disabled and service.tooltip_text.contains("tended today"),
		service.tooltip_text)
	_check("Feed and Recolonise are refused", (panel.call(&"button", &"feed") as Button).disabled \
		and (panel.call(&"button", &"recolonize") as Button).disabled)


func _close_on_the_bees() -> void:
	"""Close on the skep: the swarm about it."""
	var at: Vector2 = HiveRules.centre_m(0)
	_look_at(Vector3(at.x, 0.4, at.y), 4.5, 24.0, 160.0)
	_capture("bees")
