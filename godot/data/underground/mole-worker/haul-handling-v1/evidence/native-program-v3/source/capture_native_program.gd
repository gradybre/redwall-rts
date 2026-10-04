extends SceneTree
## Offline native matrix witness. No Profile, Driver, movement, work or Inventory authority.

const Content := preload("res://demo/cast/underground_actor_content.gd")
const Actor := preload("res://demo/cast/underground_actor.gd")
const Grip := preload("res://data/underground/mole-worker/mole_grip_source.gd")
const WORLD: Vector2i = Vector2i(5, 9)
const FLOATS: int = 314
const INTS: int = 8

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
	"""The original import, exact approved grip derivative and whole native log must match the wire."""
	var result: Array[Mesh] = []
	_check(FileAccess.get_sha256(_spec.body) == _spec.body_sha256, "original body bytes")
	var scene: PackedScene = load(_spec.body) as PackedScene
	if not _check(scene != null, "original scene"):
		return result
	var original: Node = scene.instantiate()
	_world.add_child(original)
	var nodes: Array[Node] = original.find_children("*", "MeshInstance3D", true, false)
	var rigs: Array[Node] = original.find_children("*", "Skeleton3D", true, false)
	if not _check(nodes.size() == 1 and rigs.size() == 1, "full original mesh and rig"):
		original.free()
		return result
	var instance: MeshInstance3D = nodes[0] as MeshInstance3D
	var derived: Grip.Result = Grip.create(instance.mesh as ArrayMesh, instance.skin, rigs[0] as Skeleton3D, _fit())
	_check(derived.error == &"", "approved grip derivation: " + String(derived.error))
	if derived.error == &"":
		result = [derived.mesh, _stock()]
		print("native-mesh: body=", Content.mesh_fingerprint(result[0], 24, 17172, 1).hex_encode(),
			"; stock=", Content.mesh_fingerprint(result[1], 0, 522, 1).hex_encode(),
			"; stock-format=", result[1].surface_get_format(0), "; stock-aabb=", result[1].get_aabb())
		_check(_content.mesh_binding_refusal(result) == &"", "both complete native mesh fingerprints")
	original.free()
	return result


func _fit() -> Transform3D:
	"""Reproduce the source-bound pick fit solely to verify the existing grip derivative's identity."""
	var bound: AABB = AABB(Vector3(-0.274994641542435, 0.0, -0.213909700512886),
		Vector3(0.54998928308487, 0.112690538167953, 0.427819401025772))
	var grip: Vector3 = Vector3(bound.end.x - bound.size.x * 0.14, bound.get_center().y, bound.get_center().z)
	var turn: Basis = Basis.from_euler(Vector3(0, 90, 90) * (PI / 180.0))
	return Transform3D(turn, Vector3.ZERO) * Transform3D(Basis.IDENTITY, -grip) \
		* Transform3D(Basis.from_scale(Vector3.ONE * 0.289199709892273), Vector3.ZERO)


func _stock() -> ArrayMesh:
	"""Same native source factory as the accepted 522-vertex, 768-triangle stock capture."""
	var stock: CylinderMesh = CylinderMesh.new()
	stock.top_radius = 0.9 * 0.055
	stock.bottom_radius = stock.top_radius
	stock.height = 1.0
	var result: ArrayMesh = ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, stock.get_mesh_arrays())
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color("8a5837")
	material.roughness = 0.9
	result.surface_set_material(0, material)
	return result


func _bind(meshes: Array[Mesh]) -> void:
	"""Use a real finite Domain and nonzero parent; World transform is applied only by Actor."""
	_actor = Actor.new()
	_world.add_child(_actor)
	var materials: Array[Material] = [null, null]
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
				if view == 0 and elapsed == (timing[0] / 2 / 16384) * 16384:
					await _shot(clip)
				elapsed += 16384
			if not _failures.is_empty():
				break
	file.close()


func _write_pose(file: FileAccess, view: int, clip: int, elapsed: int, yaw: int) -> void:
	"""Store actual native bone values and the separate actual body World transform, never expected values."""
	var chosen: PackedInt32Array = PackedInt32Array([0, 0, 0])
	_check(_content.clip_into(clip, elapsed, chosen) == &"", "source clock")
	var frames: PackedInt32Array = PackedInt32Array([chosen[0], chosen[1], chosen[2], chosen[0], chosen[1], chosen[2], 65536])
	_check(_actor.apply_pose(frames) == &"", "actual native pose")
	for value: int in [view, clip, elapsed, chosen[0], chosen[1], chosen[2], yaw, 0]:
		file.store_32(value)
	for bind: int in 24:
		_write_matrix(file, _actor.native_matrix(0, bind))
	_write_matrix(file, _actor.native_matrix(1, 0))
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
	"""Capture actual rendered geometry at representative joins without changing the sampled source."""
	await process_frame
	await RenderingServer.frame_post_draw
	var name: String = "clip-%d.png" % clip
	_check(root.get_texture().get_image().save_png(_out + "/" + name) == OK, "native screenshot")
	_shots.append(name)


func _finish() -> void:
	"""No successful replay grants a physical profile, handling source or runtime memory admission."""
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
	print("native-haul: %d samples, %d assertions, %d failures; qualified=0" % [_rows, _assertions, _failures.size()])
	quit(0 if _failures.is_empty() else 2)
