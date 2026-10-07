extends SceneTree
## The village's wildlife on the REAL scene (decision 1631; feature #11): a summer noon's robins on the lawn, butterflies
## over the beds, frogs on the pond's bank and a trout's leap; a robin on the wing; a winter noon (robins only) and a
## summer night (nothing). Checks the counts against wildlife_rules.gd, the staged bodies' sizes against DEC-047, that
## the boot prewarm drew them, and that nothing is selectable. Not discovered by the runner.
##
##     godot --path godot --script res://test/live/demo_wildlife_live.gd -- --size 1920x1080 --capture <dir>
##
## (--capture needs a window: not headless.) Prints `LIVE <name>: PASS|FAIL <detail>` and `LIVE-SUMMARY <checks>
## <failures>`; exits 1 on a failure.

const BOOT_FRAMES: int = 20
const STEP_FRAMES: int = 6
## The demo running between poses, so the animals have moved and their clips play (frames at 1x).
const RUN_FRAMES: int = 90
## wildlife_rules.gd kinds, wildlife_view.gd states.
const ROBIN: int = 0
const BUTTERFLY: int = 1
const FROG: int = 2
const TROUT: int = 3
const ST_REST: int = 1
const ST_FLY: int = 4
## DEC-047's sizes (m): robin length, butterfly span, frog length, trout length; and the tolerance on each.
const SIZES_M: PackedFloat32Array = [0.45, 0.36, 0.40, 0.80]
const SIZE_SLACK: float = 0.2

var _village: Node = null
var _wait: int = BOOT_FRAMES
var _steps: Array[Callable] = []
var _checks: int = 0
var _failures: int = 0
var _size: Vector2i = Vector2i(1920, 1080)
var _capture_dir: String = ""
var _pending_capture: String = ""
var _rules: GDScript = null


func _initialize() -> void:
	"""Read the arguments, size the window, boot the village and list the steps."""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for k: int in args.size():
		if args[k] == "--size" and k + 1 < args.size():
			var parts: PackedStringArray = args[k + 1].split("x")
			_size = Vector2i(int(parts[0]), int(parts[1]))
		elif args[k] == "--capture" and k + 1 < args.size():
			_capture_dir = args[k + 1]
	root.size = _size
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(_size)
	_village = (load("res://demo/demo_village.tscn") as PackedScene).instantiate()
	root.add_child(_village)
	current_scene = _village
	_rules = load("res://demo/wildlife/wildlife_rules.gd")
	_steps = [_prewarm_drew_them, _summer_noon, _run, _the_lawn, _a_robin_close, _a_robin_on_the_wing,
		_butterflies_close, _the_pond_frogs, _a_trout_leaps, _sizes, _not_selectable, _winter_noon, _summer_night]


func _process(_delta: float) -> bool:
	"""One step each time the wait runs out; quit after the last."""
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
	if _wait <= 0:
		_wait = STEP_FRAMES
	return false


func _check(check_name: String, ok: bool, detail: String = "") -> void:
	"""Record one check."""
	_checks += 1
	if not ok:
		_failures += 1
	print("LIVE %s: %s %s" % [check_name, "PASS" if ok else "FAIL", detail])


func _capture(file_name: String) -> void:
	"""Save this state's frame at the next step (only with --capture, never headless)."""
	if not _capture_dir.is_empty() and DisplayServer.get_name() != "headless":
		_pending_capture = file_name


func _save_capture() -> void:
	"""Write the pending frame, and forgive the clock the read-back's time."""
	root.get_texture().get_image().save_png(_capture_dir.path_join("%s_%dx%d.png" % [_pending_capture, _size.x, _size.y]))
	_pending_capture = ""
	root.get_node(^"GameManager").set("_last_host_usec", Time.get_ticks_usec())


func _wildlife() -> Node3D:
	"""The village's wildlife view."""
	return _village.get("_wildlife") as Node3D


func _weather() -> Object:
	"""The village's one weather."""
	return _village.get("_services").get("weather")


func _camera() -> Node:
	"""The village's camera rig."""
	return _village.get("_camera")


func _aim(at: Vector3, yaw_deg: float, pitch_deg: float, metres: float) -> void:
	"""Look at `at` from this heading, pitch and distance, at once -- `at` in the frame's middle even off the ground (a
	bird in the air): the view is centred on the ground point behind `at` along the view's own direction."""
	_camera().call(&"aim", at, yaw_deg, pitch_deg, metres)
	_camera().call(&"snap")
	var ahead: Vector3 = -root.get_viewport().get_camera_3d().global_basis.z
	if ahead.y < -0.01 and at.y > 0.05:
		_camera().call(&"aim", at + ahead * (-at.y / ahead.y), yaw_deg, pitch_deg, metres)
		_camera().call(&"snap")


func _on_screen(label: String, i: int) -> void:
	"""Check animal `i`'s shown body projects inside the frame, and say where."""
	var at: Vector3 = _spot(i)
	var camera: Camera3D = root.get_viewport().get_camera_3d()
	var px: Vector2 = camera.unproject_position(at)
	var inside: bool = not camera.is_position_behind(at) and Rect2(Vector2.ZERO, Vector2(_size)).has_point(px)
	_check("%s is in the frame" % label, inside, "at %s, on screen %s" % [at, px])


func _read(season: int, hour: int, tenths: int) -> void:
	"""Hold the weather at this hour (paused, the calendar does not move it) and show its wildlife now."""
	root.get_node(^"GameManager").call(&"pause_game")
	_weather().call(&"observe", season, 4, hour, tenths, 0, -1)
	_wildlife().call(&"refresh", true)


func _counts_match(label: String, season: int, hour: int, tenths: int) -> void:
	"""Each kind shows as wildlife_rules.gd says for this hour (within its pool)."""
	var condition: int = int(_weather().call(&"condition"))
	for kind: int in 4:
		var want: int = mini(int(_rules.call(&"count_of", kind, season, hour, condition, tenths)),
			int(_wildlife().call(&"pool_size", kind)))
		var shown: int = int(_wildlife().call(&"shown", kind))
		_check("%s: %s" % [label, _rules.get("KIND_NAMES")[kind]], shown == want, "%d shown, %d by the rules" % [shown, want])


func _first(kind: int) -> int:
	"""The first pool row of `kind`."""
	return int(_wildlife().call(&"first_of", kind))


func _spot(i: int) -> Vector3:
	"""Where animal `i`'s shown body is."""
	return (_wildlife().call(&"shown_body_of", i) as Node3D).global_position


func _prewarm_drew_them() -> void:
	"""The boot prewarm's report lists the wildlife's frame step."""
	var report: Array = _village.call(&"prewarm").get("report")
	var found: bool = false
	for row: Dictionary in report:
		found = found or String(row.get("step", "")) == "wildlife"
	_check("the boot prewarm drew the wildlife", found, "%d steps" % report.size())
	print("LIVE-INFO %d of 5 wildlife models staged" % int(_wildlife().call(&"staged_count")))


func _summer_noon() -> void:
	"""Summer noon, clear and warm: every kind about, as the rules say."""
	_read(1, 12, 220)
	_counts_match("summer noon", 1, 12, 220)


func _run() -> void:
	"""Let the village run a moment at 1x (the animals move, the clips play), then pause again."""
	root.get_node(^"GameManager").call(&"resume_game")
	_wait = RUN_FRAMES


func _the_lawn() -> void:
	"""The village from the usual height: robins on the lawn and paths, butterflies over the beds."""
	root.get_node(^"GameManager").call(&"pause_game")
	_aim(Vector3(-6.0, 0.0, 8.0), 20.0, 42.0, 18.0)
	_capture("wildlife_lawn")


func _a_robin_close() -> void:
	"""Close on a robin at rest (the one nearest the square: in the open): a small wild bird, no name, no clothes."""
	var i: int = _first(ROBIN)
	for k: int in int(_wildlife().call(&"shown", ROBIN)):
		if Vector2(_spot(_first(ROBIN) + k).x, _spot(_first(ROBIN) + k).z).length() < Vector2(_spot(i).x, _spot(i).z).length():
			i = _first(ROBIN) + k
	_aim(_spot(i), 30.0, 28.0, 3.2)
	_check("a robin shows", (_wildlife().call(&"shown_body_of", i) as Node3D).visible, str(_spot(i)))
	_on_screen("the robin", i)
	_capture("wildlife_robin")


func _a_robin_on_the_wing() -> void:
	"""A robin taken to the middle of a flight (its flight body, its flap clip held there)."""
	var w: Node3D = _wildlife()
	var i: int = _first(ROBIN) + 1
	w.call(&"_fly", i)
	w.call(&"_step", i, float(w.get("_dur")[i]) * 0.4)
	_check("a robin flies", int(w.call(&"state_of", i)) == ST_FLY, "state %d" % int(w.call(&"state_of", i)))
	_aim(_spot(i), 200.0, 18.0, 4.0)
	_on_screen("the flying robin", i)
	var wing := w.call(&"flight_body_of", i) as Node3D
	var players: Array[Node] = wing.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		var player := players[0] as AnimationPlayer
		_check("the flight body flaps", player.active and player.is_playing() and String(player.current_animation) in [
			"flap", "glide"], String(player.current_animation))
		_check("paused, its clip stands still", is_zero_approx(player.speed_scale), str(player.speed_scale))
		_check("the perched body's player is off", not (_player_of(w.call(&"body_of", i) as Node3D)).active, "")
	_capture("wildlife_robin_flying")


func _player_of(body: Node3D) -> AnimationPlayer:
	"""A body's AnimationPlayer (a staged one always has one)."""
	return body.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer


func _butterflies_close() -> void:
	"""Close on the butterflies over the cabbage beds."""
	var i: int = _first(BUTTERFLY)
	_aim(_spot(i), 10.0, 24.0, 3.6)
	_on_screen("the butterfly", i)
	_capture("wildlife_butterflies")


func _the_pond_frogs() -> void:
	"""The frogs on the pond's bank, facing the water."""
	var i: int = _first(FROG)
	_check("a frog shows", (_wildlife().call(&"shown_body_of", i) as Node3D).visible, str(_spot(i)))
	_aim(_spot(i), 300.0, 55.0, 3.4)
	_on_screen("the frog", i)
	_capture("wildlife_frogs")


func _a_trout_leaps() -> void:
	"""A trout made to leap now, its clip held at the top of its arc."""
	var w: Node3D = _wildlife()
	var i: int = _first(TROUT)
	w.call(&"_enter", i, ST_REST, 0.0)
	w.call(&"_step", i, 0.01)
	var body := w.call(&"body_of", i) as Node3D
	var players: Array[Node] = body.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		(players[0] as AnimationPlayer).seek(0.7, true)
	_check("a trout leaps", body.visible and String(w.call(&"clip_of", i)) == "leap", str(body.global_position))
	_aim(body.global_position, 160.0, 14.0, 4.5)
	_on_screen("the trout", i)
	_capture("wildlife_trout")


func _sizes() -> void:
	"""Each staged body's longest extent is DEC-047's size (within SIZE_SLACK); stand-ins are not checked."""
	for kind: int in 4:
		var body := _wildlife().call(&"body_of", _first(kind)) as Node3D
		if body.find_children("*", "AnimationPlayer", true, false).is_empty():
			continue
		var box := _bounds(body)
		var longest: float = maxf(box.size.x, box.size.z)
		_check("%s's size" % _rules.get("KIND_NAMES")[kind], absf(longest - SIZES_M[kind]) <= SIZES_M[kind] * SIZE_SLACK,
			"%.2f m (DEC-047 %.2f m)" % [longest, SIZES_M[kind]])


func _bounds(body: Node3D) -> AABB:
	"""A body's meshes' bounds in its own frame (unrotated)."""
	var box := AABB()
	var first: bool = true
	for node: Node in body.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var local: AABB = body.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
		box = local if first else box.merge(local)
		first = false
	return box


func _not_selectable() -> void:
	"""The animals carry no collision: nothing a click can pick."""
	var bodies: Array[Node] = _wildlife().find_children("*", "CollisionObject3D", true, false)
	_check("nothing selectable", bodies.is_empty(), "%d collision bodies" % bodies.size())


func _winter_noon() -> void:
	"""Winter noon, frosty: only the robins."""
	_read(3, 12, -50)
	_counts_match("winter noon", 3, 12, -50)
	_aim(Vector3(-6.0, 0.0, 8.0), 20.0, 42.0, 18.0)
	_capture("wildlife_winter")


func _summer_night() -> void:
	"""A summer night: the frogs only (no robins, butterflies or trout)."""
	_read(1, 23, 180)
	_counts_match("summer night", 1, 23, 180)
