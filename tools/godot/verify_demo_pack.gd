extends SceneTree
## Boot an exported demo pack and report what it holds and what it does. Decision 0196.
##
## Run by tools/build_demo_windows.py with the EDITOR binary, which accepts `--main-pack` (the export
## templates do not): `godot --main-pack <pck> --script <this file> -- <out.json> <screenshot dir>`.
## Loading the pack as the main pack gives this process the pack's own project settings, custom
## features included, so what it reads is what the exported game reads.
##
## Settings are read with `get_setting_with_override`, as the engine reads them: plain `get_setting`
## ignores feature overrides, so it would report scenes/main.tscn even from a correct pack.
##
## It records: the resolved main scene and whether the `demo_build` feature is on; every packed path
## under res://demo/assets (and how many imported textures are VRAM-compressed S3TC); the demo scene
## booted from the resolved main scene, with the staged manifest, card atlases and icons found in the
## pack; texture and video memory in the opening view; the beaver's flat tail over 4 s of play
## (decision 0203) -- whether its roll modifier is bound, the RESIDUAL roll (how far each paddle bone's
## breadth is from the level target the modifier aims at, which must be ~0 once it has run) and, for
## information, the breadth's tilt from horizontal (not 0 wherever the tail swings sideways as it
## rises: "as level as a bone pointing that way allows"); and screenshots of the opening view and
## the beaver's tail.

const TailFlatRollScript := preload("res://scripts/presentation/tail_flat_roll.gd")

const DEMO_SCENE: String = "res://demo/demo_village.tscn"
const ASSETS: String = "res://demo/assets"
const WARM_FRAMES: int = 120
const TAIL_FRAMES: int = 240
const SETTLE_FRAMES: int = 30
const TAIL_BONES: int = 8
const BEAVER: String = "beaver_bridgewright"

var _out: String = ""
var _shots: String = ""
var _report: Dictionary = {}
var _demo: Node = null
var _frame: int = 0
var _skeleton: Skeleton3D = null
var _tail_bones: PackedInt32Array = PackedInt32Array()
var _rest_breadth: PackedVector3Array = PackedVector3Array()
var _tilts: PackedFloat64Array = PackedFloat64Array()
var _residuals: PackedFloat64Array = PackedFloat64Array()
var _lengths: PackedVector3Array = PackedVector3Array()
var _hips_breadth: Vector3 = Vector3.ZERO


func _initialize() -> void:
	"""Read the pack, then boot the resolved main scene."""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("usage: --main-pack <pck> --script verify_demo_pack.gd -- <out.json> [screenshot dir]")
		quit(2)
		return
	_out = args[0]
	_shots = args[1] if args.size() > 1 else ""
	var main_scene: String = str(ProjectSettings.get_setting_with_override("application/run/main_scene"))
	_report["main_scene"] = main_scene
	_report["feature_demo_build"] = OS.has_feature("demo_build")
	_report["window_mode_setting"] = ProjectSettings.get_setting_with_override("display/window/size/mode")
	_report["app_name"] = ProjectSettings.get_setting_with_override("application/config/name")
	_report["pack"] = _inventory()
	if not ResourceLoader.exists(main_scene):
		_finish("main scene missing from the pack: " + main_scene)
		return
	_demo = (load(main_scene) as PackedScene).instantiate()
	root.add_child(_demo)
	current_scene = _demo


func _inventory() -> Dictionary:
	"""What the pack holds under res://demo/assets, by kind."""
	var files: PackedStringArray = PackedStringArray()
	_walk(ASSETS, files)
	var counts: Dictionary = {"files": files.size(), "glb_imports": 0, "raw_png": 0, "texture_imports": 0}
	for path: String in files:
		if path.ends_with(".glb.import"):
			counts["glb_imports"] += 1
		elif path.ends_with(".png.import") or path.ends_with(".jpg.import"):
			counts["texture_imports"] += 1
		elif path.ends_with(".png"):
			counts["raw_png"] += 1
	var s3tc: PackedStringArray = PackedStringArray()
	_walk("res://.godot/imported", s3tc)
	counts["s3tc_ctex"] = Array(s3tc).filter(func(p: String) -> bool: return p.ends_with(".s3tc.ctex")).size()
	counts["plain_ctex"] = Array(s3tc).filter(func(p: String) -> bool:
		return p.ends_with(".ctex") and not p.ends_with(".s3tc.ctex")).size()
	counts["manifest"] = FileAccess.file_exists(ASSETS + "/manifest.json")
	counts["demo_scene"] = ResourceLoader.exists(DEMO_SCENE)
	return counts


func _walk(path: String, into: PackedStringArray) -> void:
	"""Every file under `path`, recursively."""
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	dir.include_hidden = true
	for file: String in dir.get_files():
		into.append(path.path_join(file))
	for sub: String in dir.get_directories():
		_walk(path.path_join(sub), into)


func _process(_delta: float) -> bool:
	"""Warm up, measure the opening view, then watch the beaver's tail."""
	if _demo == null:
		return true
	_frame += 1
	if _frame == WARM_FRAMES:
		_report["clock_at_open"] = _clock_state()
		_save("opening_view")
		_report["texture_mem_mb"] = Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0
		_report["video_mem_mb"] = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
		_report["renderer"] = RenderingServer.get_current_rendering_driver_name()
		_report["demo_root"] = str(_demo.name)
		_bind_beaver()
	elif _frame == WARM_FRAMES + 2:
		_hold_clock(false)
		_aim_at_beaver()
	elif _frame > WARM_FRAMES and _frame <= WARM_FRAMES + TAIL_FRAMES:
		_aim_at_beaver()
	elif _frame == WARM_FRAMES + TAIL_FRAMES + SETTLE_FRAMES:
		_report["clock_at_end"] = _clock_state()
		_save("beaver_tail")
		_finish("")
		return true
	return false


func _clock_state() -> String:
	"""The game clock's state and held pause reasons, e.g. "Playing []" or "Paused [CRITICAL]"."""
	var manager: Node = root.get_node_or_null("GameManager")
	if manager == null:
		return "no GameManager"
	return "%s %s" % [manager.call("get_state_name"), manager.call("get_pause_reason_names")]


func _bind_beaver() -> void:
	"""Find the beaver's skeleton and flat-roll modifier, and sample its tail after every skeleton update."""
	var actor: Node = _demo.find_child(BEAVER, true, false)
	_report["beaver_found"] = actor != null
	if actor == null:
		return
	var rig: Object = actor.get("_tail")
	_report["beaver_tail_refusal"] = str(actor.get("tail_refusal"))
	_report["beaver_flat_roll_bound"] = rig != null and rig.get("flat_roll") != null
	var skeletons: Array[Node] = actor.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return
	_skeleton = skeletons[0] as Skeleton3D
	for i in TAIL_BONES:
		var bone: int = _skeleton.find_bone("tail_%02d" % i)
		if bone < 0:
			return
		_tail_bones.append(bone)
		_rest_breadth.append(_skeleton.get_bone_global_rest(bone).basis.orthonormalized().inverse() * Vector3.RIGHT)
	for i in TAIL_BONES:
		_lengths.append(_skeleton.get_bone_rest(_tail_bones[mini(i + 1, TAIL_BONES - 1)]).origin.normalized())
	var hips: int = _skeleton.get_bone_parent(_tail_bones[0])
	_hips_breadth = _skeleton.get_bone_global_rest(hips).basis.orthonormalized().inverse() * Vector3.RIGHT
	_skeleton.skeleton_updated.connect(_sample_tail)


func _sample_tail() -> void:
	"""This update's largest residual roll and largest tilt from horizontal over the tail bones, in degrees
	(skeleton space, which is upright: the actor only turns about Y)."""
	var hips_rotation: Quaternion = TailFlatRollScript.global_rotation(_skeleton, _skeleton.get_bone_parent(_tail_bones[0]))
	var target: Vector3 = TailFlatRollScript.level_breadth(hips_rotation * _hips_breadth)
	var worst_tilt: float = 0.0
	var worst_residual: float = 0.0
	for i in _tail_bones.size():
		var rotation: Quaternion = TailFlatRollScript.global_rotation(_skeleton, _tail_bones[i])
		var breadth: Vector3 = (rotation * _rest_breadth[i]).normalized()
		var roll: float = TailFlatRollScript.roll_to(rotation * _lengths[i], breadth, target)
		worst_residual = maxf(worst_residual, absf(rad_to_deg(roll)))
		worst_tilt = maxf(worst_tilt, rad_to_deg(asin(clampf(absf(breadth.y), 0.0, 1.0))))
	_residuals.append(worst_residual)
	_tilts.append(worst_tilt)


func _aim_at_beaver() -> void:
	"""Hold the camera behind and above the beaver, so the last screenshot shows its tail."""
	if _skeleton == null:
		return
	var rig: Node = _demo.get_node_or_null("DemoCamera")
	if rig == null:
		return
	rig.set_process(false)
	var at: Vector3 = _skeleton.global_position
	var back: Vector3 = _skeleton.global_basis.z.normalized() * -1.0
	var camera: Camera3D = rig.call("camera")
	camera.look_at_from_position(at + back * 2.6 + Vector3(0.9, 1.4, 0.0), at + Vector3(0.0, 0.3, 0.0), Vector3.UP)


func _hold_clock(hold: bool) -> void:
	"""Pause (as the player) around a screenshot, and resume after it. Reading back and encoding a
	HiDPI frame stalls one frame by more than the clock's overload limit (a quarter second of debt at
	1x), and the stall would otherwise pause the game with CRITICAL -- a harness artefact, not the demo."""
	var manager: Node = root.get_node_or_null("GameManager")
	if manager != null:
		manager.call("pause_game" if hold else "resume_game")


func _save(name: String) -> void:
	"""A screenshot of the window, when a folder was given, with the game clock held around it."""
	if _shots.is_empty():
		return
	_hold_clock(true)
	DirAccess.make_dir_recursive_absolute(_shots)
	root.get_texture().get_image().save_png(_shots.path_join(name + ".png"))


func _finish(error: String) -> void:
	"""Write the report."""
	_report["tail_samples"] = _tilts.size()
	_report["tail_residual_roll_max_deg"] = _percentile(_residuals, 1.0)
	_report["tail_residual_roll_p95_deg"] = _percentile(_residuals, 0.95)
	_report["tail_tilt_max_deg"] = _percentile(_tilts, 1.0)
	_report["tail_tilt_p50_deg"] = _percentile(_tilts, 0.5)
	_report["error"] = error
	var file: FileAccess = FileAccess.open(_out, FileAccess.WRITE)
	file.store_string(JSON.stringify(_report, "  "))
	print("VERIFY_DEMO_PACK ", JSON.stringify(_report))
	if not error.is_empty():
		quit(1)


static func _percentile(values: PackedFloat64Array, at: float) -> float:
	"""The `at` quantile of `values` (1.0: the largest), or -1 when there are none."""
	if values.is_empty():
		return -1.0
	var sorted: PackedFloat64Array = values.duplicate()
	sorted.sort()
	return sorted[mini(int(sorted.size() * at), sorted.size() - 1)]
