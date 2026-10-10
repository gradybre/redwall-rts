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
## rises: "as level as a bone pointing that way allows"); the stall Resume -- a deliberate 1.2 s frame
## at 1x must put the clock into its CRITICAL diagnostic pause, show the stall banner, stay paused, and
## an Enter press must resume it with ticks advancing again (demo/ui/demo_stall_banner.gd); the build's
## version file and whether the playtest log is running (decision 0562); every underground binary the game reads with
## FileAccess, at its pinned digest, before the demo boots, and whether the underground foundation then mounted
## (decision 1841); and screenshots of the opening view, the beaver's tail and the banner.

const TailFlatRollScript := preload("res://scripts/presentation/tail_flat_roll.gd")
const PlaytestLog := preload("res://demo/playtest/playtest_log.gd")
const MoleCatalog := preload("res://data/underground/mole-worker/mole_profile_catalog.gd")
const RuntimeFiles := preload("res://data/underground/runtime_files.gd")
## Retain the actual consumer Script objects whose source the cold runtime catalog checks.
const PROFILE_SCRIPTS: Array[Script] = [
	preload("res://scripts/core/underground_profiles.gd"),
	preload("res://scripts/core/underground_work_face.gd"),
	preload("res://scripts/core/underground_connector_contacts.gd"),
	preload("res://scripts/core/underground_routes.gd"),
	preload("res://scripts/core/underground_world_routes.gd"),
	preload("res://demo/cast/underground_actor.gd"),
	preload("res://demo/cast/underground_actor_content.gd"),
	preload("res://data/underground/mole-worker/mole_profile_driver.gd"),
	preload("res://data/underground/mole-worker/work-approach-v1/source_program.gd"),
	preload("res://data/underground/mole-worker/work-step-v1/source_program.gd"),
]
const ACTOR_CONTENT: String = "res://data/underground/mole-worker/evidence/contact-qualification/install-program-compile-v3/result/mole-worker.ugactor"
const ACTOR_BYTES: int = 648760
const HASH_BLOCK_BYTES: int = 16384
## The largest runtime binary is the 1,058,772-byte claw image; a file past this refuses before it is streamed.
const RUNTIME_FILE_MAX_BYTES: int = 4194304
const BUILD_INFO: String = "res://demo/build_info.json"

const DEMO_SCENE: String = "res://demo/demo_village.tscn"
const ASSETS: String = "res://demo/assets"
const WARM_FRAMES: int = 120
const TAIL_FRAMES: int = 240
const SETTLE_FRAMES: int = 30
const TAIL_BONES: int = 8
const BEAVER: String = "beaver_bridgewright"
const STALL_MSEC: int = 1200
## Frames after the tail check: release the screenshot hold, stall, look, press Enter, look again.
const STALL_AT: int = 10
const LOOK_AT: int = 40
const PRESS_AT: int = 42
const AFTER_AT: int = 50
const DONE_AT: int = 80

var _out: String = ""
var _shots: String = ""
var _report: Dictionary = {}
var _demo: Node = null
var _frame: int = 0
var _skeleton: Skeleton3D = null
var _tail_bones: PackedInt32Array = PackedInt32Array()
var _rest_breadth: PackedVector3Array = PackedVector3Array()
var _tilts: PackedFloat64Array = PackedFloat64Array()
var _tick_after_resume: int = 0
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
	_report["runtime_files"] = runtime_files()
	_report["profile_package"] = profile_package()
	for check: String in ["runtime_files", "profile_package"]:
		if not _report[check]["error"].is_empty():
			_finish(_report[check]["error"])
			return
	_boot_demo()


func _boot_demo() -> void:
	"""Record the same pack settings and boot only after all mandatory profile bytes/source checks pass."""
	var main_scene: String = str(ProjectSettings.get_setting_with_override("application/run/main_scene"))
	_report["main_scene"] = main_scene
	_report["feature_demo_build"] = OS.has_feature("demo_build")
	_report["window_mode_setting"] = ProjectSettings.get_setting_with_override("display/window/size/mode")
	_report["app_name"] = ProjectSettings.get_setting_with_override("application/config/name")
	_report["pack"] = _inventory()
	_report["build_info"] = FileAccess.get_file_as_string(BUILD_INFO) if FileAccess.file_exists(BUILD_INFO) else ""
	if not ResourceLoader.exists(main_scene):
		_finish("main scene missing from the pack: " + main_scene)
		return
	_demo = (load(main_scene) as PackedScene).instantiate()
	root.add_child(_demo)
	current_scene = _demo


static func profile_package(profile_path: String = MoleCatalog.WIRE_PATH,
		actor_path: String = ACTOR_CONTENT) -> Dictionary:
	"""Pack capability only: exact source bytes and artifacts, without claiming actual World/renderer activation."""
	var binary: Dictionary = _profile_binary(profile_path, MoleCatalog.WIRE_BYTES, MoleCatalog.Pins.WIRE_SHA)
	var actor: Dictionary = _profile_binary(actor_path, ACTOR_BYTES, MoleCatalog.Pins.ACTOR_SHA)
	var sources: Dictionary = _profile_sources()
	var error: String = binary["error"]
	if error.is_empty():
		error = actor["error"]
	if error.is_empty():
		error = sources["error"]
	return {"error": error, "profiles": binary, "actor": actor, "sources": sources,
		"world_activation_qualified": false, "static_memory_bytes": Performance.get_monitor(Performance.MEMORY_STATIC)}


static func runtime_files(files: Dictionary = RuntimeFiles.FILES) -> Dictionary:
	"""Every underground binary the game opens with FileAccess, present at its pinned digest (decision 1841)."""
	var refused: PackedStringArray = PackedStringArray()
	var report: Dictionary = {"error": "", "count": files.size(), "bytes": 0}
	for path: String in files:
		var file: Dictionary = _profile_binary(path, -1, files[path])
		if not file["error"].is_empty():
			refused.append(path)
			if report["error"].is_empty():
				report["error"] = file["error"]
		report["bytes"] += maxi(file["bytes"], 0)
	report["refused"] = refused
	return report


static func _profile_binary(path: String, size: int, digest: String) -> Dictionary:
	"""Hash the same open stream in16KiB blocks; size mismatch refuses before allocating file-sized data. A size of
	-1 takes any length up to RUNTIME_FILE_MAX_BYTES, where the digest alone pins the bytes."""
	var report: Dictionary = {"path": path, "bytes": -1, "sha256": "", "error": ""}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		report["error"] = "source-bound profile artifact missing: " + path
		return report
	report["bytes"] = file.get_length()
	if report["bytes"] != size and (size >= 0 or report["bytes"] > RUNTIME_FILE_MAX_BYTES):
		report["error"] = "source-bound profile artifact byte count differs: " + path
		return report
	var hashing: HashingContext = HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	var left: int = report["bytes"]
	while left > 0:
		var block: PackedByteArray = file.get_buffer(mini(HASH_BLOCK_BYTES, left))
		if block.size() != mini(HASH_BLOCK_BYTES, left):
			report["error"] = "source-bound profile artifact truncated: " + path
			return report
		hashing.update(block)
		left -= block.size()
	report["sha256"] = hashing.finish().hex_encode()
	if report["sha256"] != digest:
		report["error"] = "source-bound profile artifact digest differs: " + path
	return report


static func _profile_sources() -> Dictionary:
	"""Check cache identity and retained text of the real consumer scripts; the runtime helper checks every hash."""
	var report: Dictionary = {"error": "", "count": PROFILE_SCRIPTS.size(), "characters": 0}
	if PROFILE_SCRIPTS.size() != MoleCatalog.Pins.PATHS.size():
		report["error"] = "source-bound profile Script census differs"
		return report
	for index: int in PROFILE_SCRIPTS.size():
		var path: String = MoleCatalog.Pins.PATHS[index]
		if not ResourceLoader.has_cached(path) or PROFILE_SCRIPTS[index] != ResourceLoader.load(path, "Script", ResourceLoader.CACHE_MODE_REUSE):
			report["error"] = "source-bound profile Script identity differs: " + path
			return report
		report["characters"] += PROFILE_SCRIPTS[index].get_source_code().length()
	report["error"] = str(MoleCatalog.runtime_sources_refusal())
	return report


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
		_report["playtest_log"] = PlaytestLog.session().file_name() if PlaytestLog.session() != null else ""
		_report["underground_mounted"] = _underground_mounted()
		_bind_beaver()
	elif _frame == WARM_FRAMES + 2:
		_hold_clock(false)
		_aim_at_beaver()
	elif _frame > WARM_FRAMES and _frame <= WARM_FRAMES + TAIL_FRAMES:
		_aim_at_beaver()
	elif _frame == WARM_FRAMES + TAIL_FRAMES + SETTLE_FRAMES:
		_report["clock_at_end"] = _clock_state()
		_save("beaver_tail")
	elif _frame > WARM_FRAMES + TAIL_FRAMES + SETTLE_FRAMES:
		return _stall_step(_frame - WARM_FRAMES - TAIL_FRAMES - SETTLE_FRAMES)
	return false


func _stall_step(step: int) -> bool:
	"""The stall Resume check, one step per frame; true when the report is written."""
	var manager: Node = root.get_node_or_null("GameManager")
	var banner: Node = _demo.find_child("DemoStallBanner", true, false)
	if step == 2:
		_hold_clock(false)
	elif step == STALL_AT:
		OS.delay_msec(STALL_MSEC)
	elif step == LOOK_AT:
		_report["stall_clock"] = _clock_state()
		_report["stall_banner_shown"] = banner != null and banner.call("is_shown")
		_save_now("stall_banner")
	elif step == PRESS_AT:
		_press(KEY_ENTER, true)
		_press(KEY_ENTER, false)
	elif step == AFTER_AT:
		_report["after_resume_clock"] = _clock_state()
		_report["after_resume_banner_shown"] = banner != null and banner.call("is_shown")
		_tick_after_resume = manager.call("get_completed_tick") if manager != null else 0
	elif step == DONE_AT:
		var ticks: int = manager.call("get_completed_tick") if manager != null else 0
		_report["ticks_after_resume"] = ticks - _tick_after_resume
		_finish("")
		return true
	return false


func _press(keycode: Key, pressed: bool) -> void:
	"""A key event through the engine's own input path, as a player's press arrives."""
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)


func _underground_mounted() -> bool:
	"""Whether the demo gave the settlement its underground foundation and composed its room and route owners
	(demo_village.gd _mount_modular_foundation; session state 2, owners ready). A binary missing from the pack refuses
	that with only a warning, so the check reads the session itself."""
	var settlement: Node = root.get_node_or_null("SettlementSystem")
	var session: Object = settlement.call("underground_session") if settlement != null else null
	return session != null and settlement.call("underground_content") != null and session.get("_operations_state") == 2


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


func _save_now(name: String) -> void:
	"""A screenshot without holding the clock (it is already paused)."""
	if not _shots.is_empty():
		root.get_texture().get_image().save_png(_shots.path_join(name + ".png"))


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
