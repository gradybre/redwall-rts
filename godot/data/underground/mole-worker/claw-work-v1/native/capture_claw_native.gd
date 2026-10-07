extends SceneTree
## Offline native matrix witness for the claw/paw image (ADR 1217 step 3b: the open paw, no tool, one part). No
## Profile, Driver, movement, work or Inventory authority. The body is the original import, not the pick-paw derivative.

const Content := preload("res://demo/cast/underground_actor_content.gd")
const Actor := preload("res://demo/cast/underground_actor.gd")
const WORLD: Vector2i = Vector2i(5, 9)
const FLOATS: int = 314
const INTS: int = 8
const BODY_VERTICES: int = 17172

var _spec: Dictionary = {}
var _out: String = ""
var _failures: Array[String] = []
var _assertions: int = 0
var _content: Content = Content.new()
var _basis: Actor.WorldBasis = Actor.WorldBasis.new()
var _actor: Actor = null
var _world: Node3D = null
var _camera: Camera3D = null
var _rows: int = 0
var _shots: Array[String] = []


func _initialize() -> void:
	"""A unique output, bounded manifest and real backend are required before source loading."""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2 or DisplayServer.get_name() == "headless":
		quit(2)
		return
	_out = args[1]
	var file: FileAccess = FileAccess.open(args[0], FileAccess.READ)
	if file == null or file.get_length() > 65536 or FileAccess.file_exists(_out + "/report.json"):
		quit(2)
		return
	_spec = JSON.parse_string(file.get_as_text()) as Dictionary
	file.close()
	call_deferred("_run")


func _check(value: bool, label: String) -> bool:
	"""A failed native condition remains evidence and stops dependent work."""
	_assertions += 1
	if not value:
		_failures.append(label)
	return value


func _run() -> void:
	"""Use actual imported geometry, actual Content and actual RenderingServer bones."""
	_check(OS.get_user_data_dir().ends_with("/Redwall-ug-haul-native-1144"), "isolated user directory")
	_check(_content.load_file(_spec.content, _spec.content_sha256, _spec.reserve_bytes) == &"", "content load")
	_check(_content.part_count() == 1, "one part: the open-paw body")
	_check(_basis.load_file(_spec.basis, _spec.basis_sha256, _spec.basis_producer_sha256,
		Actor.WorldBasis.RESERVED_BYTES) == &"", "basis load")
	_world = Node3D.new()
	root.add_child(_world)
	_world.position = Vector3(71, 19, -37) # Actual Actor must bypass this unrelated parent transform.
	var meshes: Array[Mesh] = _meshes()
	if _failures.is_empty():
		_bind(meshes)
	if _failures.is_empty():
		_build_view()
		await _capture()
	if _actor != null:
		_actor.release()
	_world.free()
	_actor = null
	_world = null
	_finish()


func _meshes() -> Array[Mesh]:
	"""The original imported body, unchanged (the open paw), must match the wire's fingerprint."""
	var result: Array[Mesh] = []
	_check(FileAccess.get_sha256(_spec.body) == _spec.body_sha256, "original body bytes")
	var scene: PackedScene = load(_spec.body) as PackedScene
	if not _check(scene != null, "original scene"):
		return result
	var original: Node = scene.instantiate()
	_world.add_child(original)
	var nodes: Array[Node] = original.find_children("*", "MeshInstance3D", true, false)
	if _check(nodes.size() == 1, "one original mesh"):
		result = [(nodes[0] as MeshInstance3D).mesh]
		print("native-mesh: body=", Content.mesh_fingerprint(result[0], 24, BODY_VERTICES, 1).hex_encode())
		_check(_content.mesh_binding_refusal(result) == &"", "complete native mesh fingerprint")
	original.free()
	return result


func _bind(meshes: Array[Mesh]) -> void:
	"""Use a real finite Domain and nonzero parent; World transform is applied only by Actor."""
	_actor = Actor.new()
	_world.add_child(_actor)
	var materials: Array[Material] = [null]
	_check(_content.configure_actor(_actor, meshes, materials) == &"", "actual Actor binding")
	var domain: Actor.Space.Domain = Actor.Space.Domain.new()
	_check(domain.configure(WORLD, Vector3i(0, 512, 0), Vector3i(0, -32, 0),
		Vector3i(256, 48, 256), 8192, 6144, Actor.Space.MAX_CHECKS) == &"", "finite World Domain")
	_check(_content.domain_matches(domain.descriptor().bounds_u), "exact compiled World bounds")
	_check(_actor.bind_world_source(_basis, domain, domain.descriptor(), _content.source_digest(),
		_basis.source_digest()) == &"", "actual World source binding")


func _build_view() -> void:
	"""The camera and light are presentation only; no drawn floor supplies runtime support."""
	_camera = Camera3D.new()
	root.add_child(_camera)
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 1.8
	_camera.current = true
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("272b29")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("ccd7df")
	environment.environment.ambient_light_energy = 0.7
	root.add_child(environment)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-43, -35, 0)
	light.light_energy = 1.7
	root.add_child(light)


func _capture() -> void:
	"""Every integer key and quarter interval passes through the exact Content sampler, including true wrap."""
	var file: FileAccess = FileAccess.open(_out + "/native.bin", FileAccess.WRITE)
	file.store_buffer("UGHNAT01".to_ascii_buffer())
	file.store_32(INTS)
	file.store_32(FLOATS)
	var timing: PackedInt32Array = PackedInt32Array([0, 0])
	for view: int in _spec.views.size():
		var point: Array = _spec.views[view].root_u
		var root_u: Vector3i = Vector3i(point[0], point[1], point[2])
		var yaw: int = _spec.views[view].yaw
		_check(_actor.set_world_root(WORLD, root_u, yaw) == &"", "actual integer root and heading")
		_camera.position = Vector3(root_u) / 1024.0 + Vector3(1.6, 0.7, -1.0)
		_camera.look_at(Vector3(root_u) / 1024.0 + Vector3(0, 0.4, -0.15), Vector3.UP)
		for clip: int in _content.clip_count():
			_check(_content.clip_timing_into(clip, timing), "actual clip duration")
			var elapsed: int = 0
			while elapsed <= timing[0]:
				_write_pose(file, view, clip, elapsed, yaw)
				if view == 0 and elapsed == (timing[0] >> 1):
					await _shot(clip)
				elapsed += 16384
			if not _failures.is_empty():
				break
	file.close()


func _write_pose(file: FileAccess, view: int, clip: int, elapsed: int, yaw: int) -> void:
	"""Store actual native bone values and the actual body World transform; the absent second part writes identity
	so the row layout stays the accepted 8 + 314 scalars."""
	var chosen: PackedInt32Array = PackedInt32Array([0, 0, 0])
	_check(_content.clip_into(clip, elapsed, chosen) == &"", "source clock")
	var frames: PackedInt32Array = PackedInt32Array([chosen[0], chosen[1], chosen[2], chosen[0], chosen[1], chosen[2], 65536])
	_check(_actor.apply_pose(frames) == &"", "actual native pose")
	var shown: int = int(_actor._nodes[0].visible)
	_check(shown == 1, "native body visibility")
	for value: int in [view, clip, elapsed, chosen[0], chosen[1], chosen[2], yaw, shown]:
		file.store_32(value)
	for bind: int in 24:
		_write_matrix(file, _actor.native_matrix(0, bind))
	_write_matrix(file, Transform3D.IDENTITY)
	_write_matrix(file, _actor._nodes[0].global_transform)
	var coefficients: PackedFloat32Array = PackedFloat32Array([0.0, 0.0])
	_check(_basis.coefficients_into(yaw, coefficients) == &"", "actual basis coefficients")
	file.store_float(coefficients[0])
	file.store_float(coefficients[1])
	_rows += 1


static func _write_matrix(file: FileAccess, value: Transform3D) -> void:
	"""Native Transform3D column order is retained exactly in little-endian binary32."""
	for column: int in 4:
		var vector: Vector3 = value.basis[column] if column < 3 else value.origin
		for axis: int in 3:
			file.store_float(vector[axis])


func _shot(clip: int) -> void:
	"""Capture actual rendered geometry at representative keys without changing the sampled source."""
	await process_frame
	await RenderingServer.frame_post_draw
	var name: String = "clip-%d.png" % clip
	_check(root.get_texture().get_image().save_png(_out + "/" + name) == OK, "native screenshot")
	_shots.append(name)


func _finish() -> void:
	"""No successful replay grants a physical profile, work source or runtime memory admission."""
	if _camera != null:
		_camera.free()
	var report: Dictionary = {"schema": 1, "rows": _rows, "assertions": _assertions, "failures": _failures,
		"content_sha256": _content.source_digest(), "basis_sha256": _basis.source_digest(),
		"engine": Engine.get_version_info(), "rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"rendering_method": RenderingServer.get_current_rendering_method(), "display_server": DisplayServer.get_name(),
		"api_version": RenderingServer.get_video_adapter_api_version(), "user_directory": OS.get_user_data_dir(),
		"screenshots": _shots, "production_qualified": false, "runtime_admitted": false}
	var file: FileAccess = FileAccess.open(_out + "/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t", true, true) + "\n")
	file.close()
	for failure: String in _failures:
		printerr("FAIL: ", failure)
	print("native-claw: %d samples, %d assertions, %d failures; qualified=0" % [_rows, _assertions, _failures.size()])
	quit(0 if _failures.is_empty() else 2)
