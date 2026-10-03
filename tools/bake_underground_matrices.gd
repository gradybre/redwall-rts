extends "capture_underground_profiles.gd"
## Decision1080: finite presentation content baked from actual final native poses.
## This new representation can be bounded between frames; the captured live skeletal path remains unqualified.

const MatrixActor := preload("res://demo/cast/underground_actor.gd")
const PALETTE_MAGIC: String = "UGPAL001"
const PALETTE_MAX_BYTES: int = 134217728
const PALETTE_MAX_TEXT: int = 1048576
const FORWARD_CONVERSION: Transform3D = Transform3D(Basis(Vector3(-1, 0, 0), Vector3.UP, Vector3(0, 0, -1)), Vector3.ZERO)

var _stream: FileAccess = null
var _binary_path: String = ""
var _baked_cases: int = 0
var _baked_frames: int = 0
var _baked_scalars: int = 0
var _grounding_y: float = 0.0


func _case_error(request: Variant, pins: Dictionary, ids: Dictionary) -> String:
	"""An explicit existing work-tool binding extends measured states without altering the accepted live harness."""
	if not request is Dictionary or not request.has("held_tool_binding"):
		return super._case_error(request, pins, ids)
	var code: String = persistent_tool_error(request)
	if code != "":
		return code
	var source_request: Dictionary = request.duplicate()
	source_request.attachments = []
	code = super._case_error(source_request, pins, ids)
	if code != "":
		return code
	var prop: Variant = _manifest.world.get("mole_pick")
	if not prop is Dictionary or not prop.get("path") is String or not pins.has(prop.path):
		return "PALETTE_WORK_TOOL_SOURCE_UNPINNED"
	return _import_error(prop.path, pins)


static func persistent_tool_error(request: Dictionary) -> String:
	"""Only one explicitly measured existing right-hand tool may accompany these real source clips."""
	if request.get("held_tool_binding") != "set_work_tool" or request.get("attachments") != ["mole_pick"]:
		return "PALETTE_WORK_TOOL_BINDING"
	var clip: Variant = request.get("clip")
	if clip != "idle" and clip != "walk" and clip != "cautious_crouch_walk_forward":
		return "PALETTE_WORK_TOOL_CLIP"
	return ""


func _item_instance(item: Dictionary) -> MeshInstance3D:
	"""The actual persistent tool method retains the mesh/socket through travel; no fake digging state hides it."""
	if _cases[_case_index].get("held_tool_binding", "") != "set_work_tool":
		return super._item_instance(item)
	_actor.brain.clip = StringName(_cases[_case_index].clip)
	_actor.brain.carrying = false
	_actor.set_work_tool(item.mesh, item.fit)
	_actor.call("_place_tool")
	return _actor.get("_work_tool") as MeshInstance3D


func _initialize() -> void:
	"""Refuse a pre-existing binary or report before the inherited reader can write anything."""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 3:
		printerr("usage: bake_underground_matrices.gd -- spec.json report.json output.ugpal")
		quit(2)
		return
	_out = args[1]
	_binary_path = args[2]
	if _output_exists() or FileAccess.file_exists(_binary_path) or DirAccess.dir_exists_absolute(_binary_path) \
			or _same_path(args[0], _binary_path) or _same_path(_out, _binary_path) or _same_path(args[0], _out):
		printerr("PALETTE_OUTPUT_EXISTS_OR_OVERWRITES_INPUT")
		quit(2)
		return
	_load_spec(args[0])


func _pin_error(source: Variant, pins: Dictionary) -> String:
	"""The complete source closure is read-only, including the sibling finite-content output."""
	if source is Dictionary and source.get("path") is String and _same_path(source.path, _binary_path):
		return "PALETTE_OUTPUT_OVERWRITES_SOURCE"
	return super._pin_error(source, pins)


func _load_spec(path: String) -> void:
	"""Open a bounded stream only after all actual asset/import/script pins were verified."""
	super._load_spec(path)
	if _finished:
		return
	if DisplayServer.get_name() == "headless":
		_error = "PALETTE_NATIVE_RENDERER_REQUIRED"
		_finish()
		return
	_stream = FileAccess.open(_binary_path, FileAccess.WRITE)
	if _stream == null:
		_error = "PALETTE_OUTPUT_UNWRITABLE"
		_finish()
		return
	_stream.store_buffer(PALETTE_MAGIC.to_ascii_buffer())
	_stream.store_32(2)
	_write_text(JSON.stringify(_presentation_metadata(path)))
	_stream.store_32(_cases.size())


func _presentation_metadata(path: String) -> Dictionary:
	"""Keep the exact native backend and complete source closure attached to the finite content."""
	return {"engine": Engine.get_version_info(), "spec_sha256": FileAccess.get_sha256(path),
		"sources": _spec.sources, "manifest": _spec.manifest, "cases": _spec.cases,
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"display_server": DisplayServer.get_name(), "api_version": RenderingServer.get_video_adapter_api_version(),
		"axes": "integer-world convention: +Y up, -Z forward; metre-valued presentation source",
		"representation": "final float32 affine skin/attachment matrices; positive fixed-weight matrix interpolation",
		"grounding_schema": 1, "grounding": "schema2 common float32 Y after skinning; same fixed interpolation weights; actual deformed body minimum",
		"qualification": "FINITE_PRESENTATION_SOURCE_ONLY; no runtime/world contact authorization"}


func _begin_case(request: Dictionary) -> void:
	"""One finite clip/scenario owns its exact source geometry and matrix frames; no other state inherits it."""
	super._begin_case(request)
	if _body.size() + _items.size() > MatrixActor.MAX_PARTS or _steps > MatrixActor.MAX_FRAMES:
		_error = "PALETTE_CASE_CAPACITY"
		return
	_stream.store_32(0x43415345)
	_write_text(JSON.stringify({"id": request.id, "cast": request.cast, "species": request.species,
		"life_stage": request.life_stage, "clip": request.clip, "scenario": request.scenario,
		"sample_hz": SAMPLE_HZ, "source_duration_s": _row.clip_duration_s,
		"source_loop_mode": _row.clip_loop_mode, "parts": _body.size() + _items.size(),
		"frames": _steps, "body_parts": _body.size(), "attachments": request.attachments,
		"warm_steps": WARM_STEPS, "world_permissions": "absent",
		"held_tool_binding": request.get("held_tool_binding", "demo_clip_specific")}))
	_baked_scalars = 0
	for part: Dictionary in _body:
		_write_body_part(part)
	for item: Dictionary in _items:
		_write_attachment_part(item)
	if (_baked_scalars + 1) * _steps > MatrixActor.MAX_SCALARS:
		_error = "PALETTE_CASE_SCALAR_CAPACITY"
	_stream_ok()


func _write_body_part(part: Dictionary) -> void:
	"""Original mesh vertices and all native influences are the exact input to the new matrix representation."""
	var instance: MeshInstance3D = part.node
	var count: int = part.binds.indices.size()
	if count > MatrixActor.MAX_BINDS or instance.material_override != null or instance.material_overlay != null:
		_error = "PALETTE_ORIGINAL_MATERIAL_OR_BINDS"
		return
	var code: StringName = MatrixActor._mesh_error(instance.mesh, count)
	if code != &"":
		_error = String(code)
		return
	for surface: int in instance.mesh.get_surface_count():
		if instance.get_active_material(surface) != instance.mesh.surface_get_material(surface):
			_error = "PALETTE_PER_SURFACE_MATERIAL_OVERRIDE"
			return
	_write_text(JSON.stringify({"kind": "body", "name": String(_actor.get_path_to(instance)),
		"mesh_resource": instance.mesh.resource_path, "binds": count, "surfaces": part.surfaces.size(),
		"surface_formats": _surface_formats(instance.mesh), "mesh_aabb": _mesh_aabb(instance.mesh)}))
	_baked_scalars += maxi(1, count) * MatrixActor.MATRIX_SCALARS
	for surface: Dictionary in part.surfaces:
		_write_surface(surface.positions, surface.bones, surface.weights)


func _write_attachment_part(item: Dictionary) -> void:
	"""An authored held mesh is exported once; all socket/fitting motion is in its final per-frame matrix."""
	var code: StringName = MatrixActor._mesh_error(item.mesh, 0)
	if code != &"":
		_error = String(code)
		return
	var instance: MeshInstance3D = _item_instance(item)
	code = _attachment_material_error(instance)
	if code != &"":
		_error = String(code)
		return
	_write_text(JSON.stringify({"kind": "attachment", "name": item.key,
		"mesh_resource": item.mesh.resource_path, "binds": 0, "surfaces": item.surfaces.size(),
		"surface_formats": _surface_formats(item.mesh), "mesh_aabb": _mesh_aabb(item.mesh),
		"instance_material_override": instance.material_override != null}))
	_baked_scalars += MatrixActor.MATRIX_SCALARS
	for points: PackedVector3Array in item.surfaces:
		_write_surface(points, PackedInt32Array(), PackedFloat32Array())


static func _attachment_material_error(instance: MeshInstance3D) -> StringName:
	"""Only original surface materials plus the explicitly captured global override are supported."""
	if instance == null or instance.mesh == null or instance.material_overlay != null:
		return &"PALETTE_ATTACHMENT_MATERIAL"
	for surface: int in instance.mesh.get_surface_count():
		if instance.get_surface_override_material(surface) != null:
			return &"PALETTE_PER_SURFACE_MATERIAL_OVERRIDE"
	return MatrixActor._material_error(instance.material_override)


static func _surface_formats(mesh: Mesh) -> Array[int]:
	"""Retain actual imported compression/skin flags; PrimitiveMesh sources are generated uncompressed arrays."""
	var formats: Array[int] = []
	for surface: int in mesh.get_surface_count():
		formats.append((mesh as ArrayMesh).surface_get_format(surface) if mesh is ArrayMesh else 0)
	return formats


static func _mesh_aabb(mesh: Mesh) -> Array[float]:
	"""The whole-mesh AABB bounds every compressed surface's decode origin and scale for residual proof."""
	var bounds: AABB = mesh.get_aabb()
	return [bounds.position.x, bounds.position.y, bounds.position.z, bounds.size.x, bounds.size.y, bounds.size.z]


func _write_surface(points: PackedVector3Array, bones: PackedInt32Array, weights: PackedFloat32Array) -> void:
	"""Float32 records preserve the exact decoded mesh data used by the renderer; no source weights are normalized."""
	_stream.store_32(points.size())
	@warning_ignore("integer_division") var stride: int = weights.size() / points.size()
	_stream.store_32(stride)
	for vertex: int in points.size():
		for component: float in [points[vertex].x, points[vertex].y, points[vertex].z]:
			_write_float(component)
		for influence: int in stride:
			var at: int = vertex * stride + influence
			_stream.store_32(bones[at])
			_write_float(weights[at])


func _capture_pose() -> void:
	"""The baked values, not the live interpolation history between captured poses, become the finite content."""
	super._capture_pose()
	if _error != "":
		return
	_stream.store_32(0x4652414d)
	_stream.store_32(_step)
	_grounding_y = _body_grounding_y()
	_write_float(_grounding_y)
	for part: Dictionary in _body:
		var instance: MeshInstance3D = part.node
		var local: Transform3D = FORWARD_CONVERSION * instance.global_transform
		if part.binds.indices.is_empty():
			_write_transform(local)
		for bind: int in part.binds.indices.size():
			_write_transform(local * (_skeleton.get_bone_global_pose(part.binds.indices[bind]) * part.binds.poses[bind]))
	for item: Dictionary in _items:
		var instance: MeshInstance3D = _item_instance(item)
		if instance == null or not instance.visible or instance.mesh != item.mesh:
			_error = "PALETTE_ATTACHMENT_CHANGED"
			return
		_write_transform(FORWARD_CONVERSION * instance.global_transform)
	_baked_frames += 1
	_stream_ok()


func _body_grounding_y() -> float:
	"""The common post-skin offset comes from the exact finite body pose; attachments do not shift the feet."""
	var minimum: float = INF
	for part: Dictionary in _body:
		var instance: MeshInstance3D = part.node
		var local: Transform3D = FORWARD_CONVERSION * instance.global_transform
		var matrices: Array[Transform3D] = []
		for bind: int in part.binds.indices.size():
			matrices.append(local * (_skeleton.get_bone_global_pose(part.binds.indices[bind]) * part.binds.poses[bind]))
		for surface: Dictionary in part.surfaces:
			for vertex: int in surface.positions.size():
				var point: Vector3 = local * surface.positions[vertex] if matrices.is_empty() \
					else _skin_point(surface, vertex, matrices)
				minimum = minf(minimum, point.y)
	if not is_finite(minimum):
		_error = "PALETTE_GROUNDING_SOURCE"
		return 0.0
	return -minimum


func _write_transform(value: Transform3D) -> void:
	"""Store basis columns and translation exactly as the adapter submits them to RenderingServer."""
	for column: Vector3 in [value.basis.x, value.basis.y, value.basis.z, value.origin]:
		_write_float(column.x)
		_write_float(column.y)
		_write_float(column.z)


func _write_float(value: float) -> void:
	"""The finite binary32 content contract also caps coefficient magnitude for residual derivation."""
	if not is_finite(value) or absf(value) > MatrixActor.SOURCE_LIMIT:
		_error = "PALETTE_NONFINITE_SOURCE"
		return
	_stream.store_float(value)


func _write_text(value: String) -> void:
	"""One bounded metadata record; no full raw matrix JSON image is retained."""
	var bytes: PackedByteArray = value.to_utf8_buffer()
	if bytes.size() > PALETTE_MAX_TEXT:
		_error = "PALETTE_METADATA_CAPACITY"
		return
	_stream.store_32(bytes.size())
	_stream.store_buffer(bytes)


func _stream_ok() -> void:
	"""Capacity/IO refusal keeps a partial file with no valid completion footer."""
	if _stream.get_position() > PALETTE_MAX_BYTES or _stream.get_error() != OK:
		_error = "PALETTE_STREAM_CAPACITY_OR_IO"


func _end_case() -> void:
	"""Require actual renderer palette parity and complete timelines before closing a content case."""
	if _row.samples != _steps or _row.skin_engine_matrix_checks != _steps * _row.expected_palette_checks_per_sample \
			or _row.skin_engine_matrix_max_error_m != 0.0:
		_error = "PALETTE_NATIVE_SOURCE_COVERAGE"
		_finish()
		return
	_stream.store_32(0x454e4443)
	_stream.store_32(_row.samples)
	_baked_cases += 1
	super._end_case()


func _finish() -> void:
	"""Publish a complete finite-source footer only after every exact case; permission qualification remains absent."""
	if _finished:
		return
	if _stream != null:
		if _error == "" and _baked_cases == _cases.size():
			_stream.store_32(0x444f4e45)
			_stream.store_32(_baked_cases)
			_stream.store_32(_baked_frames)
			_stream_ok()
		_stream.close()
		_stream = null
		_report["finite_presentation_content"] = {"schema": 2, "path": _binary_path,
			"sha256": FileAccess.get_sha256(_binary_path), "cases": _baked_cases,
			"frames": _baked_frames, "status": "FINITE_SOURCE_ONLY" if _error == "" else "REFUSED"}
	super._finish()
