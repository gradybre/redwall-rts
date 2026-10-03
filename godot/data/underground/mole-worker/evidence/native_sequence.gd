extends SceneTree
## Actual compact source, original imported mole and pick. The World ref is a presentation fixture, not authority.

const Content := preload("res://demo/cast/underground_actor_content.gd")
const Actor := preload("res://demo/cast/underground_actor.gd")
const Demo := preload("res://demo/cast/demo_actor.gd")
const CastSpace := preload("res://demo/cast/cast_space.gd")
const Props := preload("res://demo/props/demo_props.gd")
const Suite := preload("res://test/framework/test_case.gd")
const ORIGIN_U: Vector3i = Vector3i(16384, -4608, 8192)
const CLIPS: PackedInt32Array = [0, 1, 6, 4]
const NAMES: PackedStringArray = ["idle", "walk", "hammer", "crouch"]

var _spec: Dictionary = {}
var _out: String = ""
var _suite: Suite = Suite.new()
var _content: Content = Content.new()
var _actor: Actor = null
var _world: Node3D = null
var _camera: Camera3D = null
var _shots: Array[Dictionary] = []
var _observed: int = 0


func _initialize() -> void:
	"""Only a create-only evidence directory and pinned input file may configure the native witness."""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2 or DisplayServer.get_name() == "headless" or FileAccess.file_exists(args[1] + "/report.json"):
		printerr("CONTENT_NATIVE_INPUT_OR_OUTPUT")
		quit(2)
		return
	_out = args[1]
	var file: FileAccess = FileAccess.open(args[0], FileAccess.READ)
	if file == null or file.get_length() > 65536:
		printerr("CONTENT_NATIVE_SPEC")
		quit(2)
		return
	_spec = JSON.parse_string(file.get_as_text()) as Dictionary
	file.close()
	call_deferred("_run")


func _run() -> void:
	"""Load the actual finite image, borrow exact meshes, then observe every clip and positive blend on the backend."""
	var before: int = OS.get_static_memory_usage()
	var peak: int = OS.get_static_memory_peak_usage()
	_suite.assert_equal(_content.load_file(_spec.content, _spec.content_sha256, _spec.reserve_bytes), &"", "stream actual image")
	print("content-memory: before=", before, "; after=", OS.get_static_memory_usage(), "; prior_peak=", peak,
		"; peak=", OS.get_static_memory_peak_usage(), "; declared_peak=", _content.required_peak_bytes(), "; isolated=false")
	_world = Node3D.new()
	root.add_child(_world)
	_build_stage()
	var meshes: Dictionary = _borrow_actual_meshes()
	if _suite.failures.is_empty():
		_bind_actor(meshes)
	if _suite.failures.is_empty():
		await _observe_clips()
	if _suite.failures.is_empty():
		await _observe_transitions()
	_world.free()
	_world = null
	_actor = null
	_camera = null
	_finish()


func _borrow_actual_meshes() -> Dictionary:
	"""Use the real asset owner and its original material resources; placeholders and alternate geometry refuse."""
	_suite.assert_equal(FileAccess.get_sha256(_spec.manifest), _spec.manifest_sha256, "actual manifest source")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_spec.manifest)) as Dictionary
	var space: CastSpace = CastSpace.new()
	space.setup([], [])
	var original: Demo = Demo.new()
	_suite.assert_true(original.setup_creature(0, &"mole_digger", manifest.cast.mole_digger, space, 1729), "actual staged mole")
	_world.add_child(original)
	original.visible = false
	var meshes: Array[Mesh] = []
	var materials: Array[Material] = []
	for node: Node in original.get_node("Body").find_children("*", "MeshInstance3D", true, false):
		var instance: MeshInstance3D = node as MeshInstance3D
		meshes.append(instance.mesh)
		materials.append(instance.material_override)
	var props: Props = Props.new()
	props.load_from(manifest)
	_suite.assert_true(props.is_staged(&"mole_pick"), "actual staged pick")
	meshes.append(props.mesh_of(&"mole_pick"))
	materials.append(null)
	_suite.assert_equal(_content.mesh_binding_refusal(meshes), &"", "independent Python/native original geometry fingerprint")
	original.free()
	return {"meshes": meshes, "materials": materials}


func _bind_actor(meshes: Dictionary) -> void:
	"""Actual finite coefficients and full configured Domain bind the exact native world equation."""
	var basis: Actor.WorldBasis = Actor.WorldBasis.new()
	_suite.assert_equal(basis.load_file(_spec.basis, _spec.basis_sha256, _spec.basis_producer_sha256,
		Actor.WorldBasis.RESERVED_BYTES), &"", "actual complete native basis")
	_actor = Actor.new()
	_world.add_child(_actor)
	_suite.assert_equal(_content.configure_actor(_actor, meshes.meshes, meshes.materials), &"", "borrow immutable source")
	var domain: Actor.Space.Domain = Actor.Space.Domain.new()
	_suite.assert_equal(domain.configure(Vector2i(5, 9), Vector3i(0, 512, 0), Vector3i(0, -32, 0),
		Vector3i(256, 48, 256), 8192, 6144, Actor.Space.MAX_CHECKS), &"", "finite Domain, fixture World ref")
	_suite.assert_true(_content.domain_matches(domain.descriptor().bounds_u), "same numerical domain")
	_suite.assert_equal(_actor.bind_world_source(basis, domain, domain.descriptor(), _content.source_digest(),
		basis.source_digest()), &"", "same-file source/world binding")
	_suite.assert_equal(_actor.set_world_root(Vector2i(5, 9), ORIGIN_U, 0), &"", "initial exact root")


func _build_stage() -> void:
	"""Lighting, camera and floor are presentation witnesses; they do not supply physical support truth."""
	root.size = Vector2i(960, 720)
	_camera = Camera3D.new()
	_world.add_child(_camera)
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 1.48
	_camera.position = Vector3(17.2, -3.85, 6.3)
	_camera.look_at(Vector3(16, -4.05, 8), Vector3.UP)
	_camera.current = true
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("272b29")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("ccd7df")
	environment.environment.ambient_light_energy = 0.65
	_world.add_child(environment)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-43, -35, 0)
	light.light_energy = 1.9
	_world.add_child(light)


func _observe_clips() -> void:
	"""All seven source states advance; close-view stills cover idle, travel, strike and stooped recovery."""
	var pose: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0, 65536])
	var now: PackedInt32Array = PackedInt32Array([0, 0, 0])
	var timing: PackedInt32Array = PackedInt32Array([0, 0])
	for clip: int in _content.clip_count():
		_suite.assert_true(_content.clip_timing_into(clip, timing), "complete finite timeline")
		@warning_ignore("integer_division") var half_ticks: int = (timing[0] + 32767) / 32768 + 2
		for tick: int in half_ticks:
			_suite.assert_equal(_content.clip_into(clip, tick * 32768, now), &"", "fixed source half-step")
			for index: int in 3:
				pose[index] = now[index]
				pose[index + 3] = now[index]
			_suite.assert_equal(_actor.apply_pose(pose), &"", "actual native matrix pose")
			_observed += 1
			await process_frame
			if CLIPS.has(clip) and tick % 12 == 0:
				await _save_frame(NAMES[CLIPS.find(clip)] + "-%02d" % tick, clip, tick)


func _observe_transitions() -> void:
	"""Positive actual two-clip blends retain the held mesh; this observes quality, not mode-transition permission."""
	var now: PackedInt32Array = PackedInt32Array([0, 0, 0])
	var prior: PackedInt32Array = PackedInt32Array([0, 0, 0])
	var pose: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0, 0])
	for destination: int in [1, 6, 0]:
		_suite.assert_equal(_content.clip_into(0, 65536 * 8, prior), &"", "idle blend endpoint")
		for step: int in 9:
			_suite.assert_equal(_content.clip_into(destination, step * 32768, now), &"", "moving blend endpoint")
			for index: int in 3:
				pose[index] = now[index]
				pose[index + 3] = prior[index]
			pose[6] = step * 8192
			_suite.assert_equal(_actor.apply_pose(pose), &"", "positive actual shared source blend")
			_observed += 1
			await process_frame
			if step == 4:
				await _save_frame("blend-%d" % destination, destination, step)


func _save_frame(label: String, clip: int, tick: int) -> void:
	"""Capture the fully rendered original material/geometry, including exact source culling bounds."""
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = _out + "/" + label + ".png"
	_suite.assert_false(FileAccess.file_exists(path), "create-only native frame")
	_suite.assert_equal(image.save_png(path), OK, "actual rendered witness")
	_shots.append({"path": label + ".png", "clip": clip, "half_tick": tick, "sha256": FileAccess.get_sha256(path)})


func _finish() -> void:
	"""Positive native counts remain explicitly separate from physical and grip quality qualification."""
	var report: Dictionary = {"schema": 1, "content_sha256": _content.source_digest(), "poses": _observed,
		"assertions": _suite.assertions, "failures": _suite.failures, "screenshots": _shots,
		"production_qualified": false, "grip_quality": "REQUIRES_ANIMATED_REVIEW",
		"world_identity": "synthetic fixture with actual finite pack bounds; no route/work permission"}
	var output: FileAccess = FileAccess.open(_out + "/report.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t") + "\n")
	output.close()
	for failure: String in _suite.failures:
		printerr("FAIL: ", failure)
	print("native-content: %d poses, %d assertions, %d failures; qualified=0" % [_observed, _suite.assertions, _suite.failures.size()])
	quit(0 if _suite.failures.is_empty() else 2)
