extends "res://data/underground/mole-worker/evidence/grip-authoring/native_grip_sequence.gd"
## ADR1138. Exact native input storage only; no skin-result, profile or physical permission.

const MAX_VERTICES: int = 32768
const MAX_INDICES: int = 196608
const MAX_SURFACE_BYTES: int = 16777216
const MAX_CAPTURE_BYTES: int = 67108864
const CONTENT_SHA: String = "adc617642313ac004c050d4877ef0b9f4024bb9c88e3ea92ce9a924471bd5ab9"
const ENGINE_SHA: String = "ed1daf0bf001b61586d9930840f2f1394092c079"
const RAW_KEYS: PackedStringArray = ["vertex_data", "attribute_data", "skin_data", "index_data"]
const FORMAT_VERSION: int = 1 << 35
const ALLOWED_FORMAT: int = 7231 | FORMAT_VERSION | (1 << 27) | (1 << 29)

var _stream: FileAccess = null
var _rows: Array[Dictionary] = []
var _mesh_rows: Array[Dictionary] = []
var _spec_sha: String = ""
var _surface_count: int = 0
var _vertex_count: int = 0
var _numeric_bytes: int = 0
var _peak_surface_bytes: int = 0
var _capture_error: StringName = &""
var _refused_mesh: Dictionary = {}


func _initialize() -> void:
	"""Pin exact input bytes and a create-only output bundle before allocating actual asset resources."""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 3 or not Actor.WorldBasis.valid_digest(args[1]):
		_refuse(&"METAL_INPUT_ARGUMENT")
		return
	_spec_sha = args[1]
	_out = args[2].simplify_path()
	if output_refusal(_out, args[0]) != &"":
		_refuse(&"METAL_INPUT_OUTPUT_EXISTS")
		return
	var file: FileAccess = FileAccess.open(args[0], FileAccess.READ)
	if file == null or file.get_length() > 524288 or FileAccess.get_sha256(args[0]) != _spec_sha:
		_refuse(&"METAL_INPUT_SPEC")
		return
	_spec = JSON.parse_string(file.get_as_text()) as Dictionary
	file.close()
	_capture_error = _source_refusal()
	if _capture_error != &"":
		_refuse(_capture_error)
		return
	call_deferred("_run")


static func output_refusal(directory: String, source: String) -> StringName:
	"""Normalize both identities and refuse existing or dangling-link output before loading any source."""
	var base: String = ProjectSettings.globalize_path(directory).simplify_path()
	var parent: DirAccess = DirAccess.open(base)
	if base.is_empty() or parent == null:
		return &"METAL_INPUT_OUTPUT_DIRECTORY"
	for name: String in ["inputs.bin", "report.json"]:
		var path: String = base.path_join(name)
		if path == ProjectSettings.globalize_path(source).simplify_path() or parent.is_link(name) \
				or FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):
			return &"METAL_INPUT_OUTPUT_EXISTS"
	return &""


func _source_refusal() -> StringName:
	"""Current recursive source pins and exact finite content identity never inherit a historical exemption."""
	if _spec.get("schema") != 1 or _spec.get("content_sha256") != CONTENT_SHA \
			or _spec.get("reserve_bytes") != 7141920 or not _spec.get("source_pins") is Dictionary \
			or not _spec.get("content") is String or not _spec.get("manifest") is String:
		return &"METAL_INPUT_SOURCE_SPEC"
	var pins: Dictionary = _spec.source_pins
	if pins.is_empty() or pins.size() > 4096:
		return &"METAL_INPUT_SOURCE_CAPACITY"
	for path: Variant in pins:
		if not path is String or not pins[path] is String or not Actor.WorldBasis.valid_digest(pins[path]) \
				or FileAccess.get_sha256(path) != pins[path]:
			return &"METAL_INPUT_SOURCE_DRIFT"
	return backend_refusal(Engine.get_version_info(), DisplayServer.get_name(),
		RenderingServer.get_current_rendering_driver_name(), RenderingServer.get_current_rendering_method())


static func backend_refusal(engine: Dictionary, display: String, driver: String, method: String) -> StringName:
	"""The dummy/headless renderer cannot stand in for native RD buffer readback."""
	if engine.get("hash") != ENGINE_SHA or engine.get("build") != "official" \
			or engine.get("major") != 4 or engine.get("minor") != 7 or engine.get("patch") != 2:
		return &"METAL_INPUT_ENGINE"
	if display != "macOS" or driver != "metal" or method != "forward_plus":
		return &"METAL_INPUT_BACKEND"
	return &""


func _run() -> void:
	"""Reuse the exact immutable content/grip reconstruction; read actual buffers without creating simulation state."""
	var before: int = OS.get_static_memory_usage()
	_suite.assert_equal(_content.load_file(_spec.content, CONTENT_SHA, 7141920), &"", "exact immutable source image")
	_world = Node3D.new()
	root.add_child(_world)
	var borrowed: Dictionary = _borrow_actual_meshes() if _suite.failures.is_empty() else {}
	if not borrowed.is_empty() and _suite.failures.is_empty():
		_capture(borrowed.meshes)
	if _source_refusal() != &"":
		_capture_error = &"METAL_INPUT_FINAL_SOURCE_DRIFT"
	_world.free()
	_world = null
	_finish_capture(before)


func _capture(meshes: Array[Mesh]) -> void:
	"""Write one surface at a time; the header binds the actual mesh match to this exact source program."""
	if meshes.size() != 2 or _content.mesh_binding_refusal(meshes) != &"":
		_capture_error = &"METAL_INPUT_MESH_IDENTITY"
		return
	_stream = FileAccess.open(_out + "/inputs.bin", FileAccess.WRITE)
	if _stream == null:
		_capture_error = &"METAL_INPUT_OUTPUT"
		return
	_stream.store_buffer("UGMIN001".to_ascii_buffer())
	_stream.store_32(1)
	_stream.store_buffer(_spec_sha.hex_decode())
	_stream.store_buffer(CONTENT_SHA.hex_decode())
	_stream.store_32(2 + int((meshes[0] as ArrayMesh).shadow_mesh != null) + int((meshes[1] as ArrayMesh).shadow_mesh != null))
	for part: int in meshes.size():
		_capture_part(meshes[part] as ArrayMesh, part, 24 if part == 0 else 0, -1)
		if _capture_error != &"":
			break
	_capture_shadows(meshes)
	_close_stream()


func _capture_shadows(meshes: Array[Mesh]) -> void:
	"""Original shadow primitives remain explicit additional inputs, never presumed covered by the main mesh certificate."""
	var part: int = 2
	for parent: int in meshes.size():
		if _capture_error != &"":
			return
		var mesh: ArrayMesh = meshes[parent] as ArrayMesh
		if mesh.shadow_mesh != null:
			_capture_part(mesh.shadow_mesh, part, 24 if parent == 0 else 0, parent)
			part += 1


func _close_stream() -> void:
	"""A failed source census remains incomplete and cannot pass the exact reader footer."""
	if _capture_error == &"":
		_stream.store_buffer("UMINEND1".to_ascii_buffer())
		_stream.store_32(_surface_count)
		_stream.store_32(_vertex_count)
	_stream.close()
	_stream = null


func _capture_part(mesh: ArrayMesh, part: int, binds: int, shadow_of: int) -> void:
	"""Native metadata admission precedes raw buffer and decoded-array allocation."""
	if mesh == null or mesh.get_surface_count() < 1 or mesh.get_surface_count() > 8 \
			or mesh.get_blend_shape_count() != 0 or (shadow_of >= 0 and mesh.shadow_mesh != null):
		_capture_error = &"METAL_INPUT_MESH_CENSUS"
		return
	var meta: Dictionary = _mesh_metadata(mesh, part, binds, shadow_of)
	if meta.mesh_sha256.length() != 64:
		_refused_mesh = _failed_mesh_metadata(mesh, meta, binds)
		_capture_error = &"METAL_INPUT_MESH_FINGERPRINT"
		return
	_record(meta)
	_mesh_rows.append(meta)
	for surface: int in mesh.get_surface_count():
		var code: StringName = counts_refusal(mesh.surface_get_format(surface), mesh.surface_get_array_len(surface),
			mesh.surface_get_array_index_len(surface), binds, mesh.surface_get_primitive_type(surface))
		if code != &"":
			_capture_error = code
			return
		_capture_surface(mesh, part, surface, binds, shadow_of >= 0)
		if _capture_error != &"":
			return


static func _failed_mesh_metadata(mesh: ArrayMesh, meta: Dictionary, binds: int) -> Dictionary:
	"""Retain exact refused counts/formats and native decode reason; these are diagnostics, never a partial certificate."""
	var surfaces: Array[Dictionary] = []
	for surface: int in mesh.get_surface_count():
		var format: int = mesh.surface_get_format(surface)
		var vertices: int = mesh.surface_get_array_len(surface)
		var indices: int = mesh.surface_get_array_index_len(surface)
		var code: StringName = counts_refusal(format, vertices, indices, binds, mesh.surface_get_primitive_type(surface))
		var arrays: Array = mesh.surface_get_arrays(surface) if code == &"" else []
		var raw: Dictionary = RenderingServer.mesh_get_surface(mesh.get_rid(), surface) if not arrays.is_empty() else {}
		surfaces.append({"format": format, "vertices": vertices, "indices": indices,
			"counts_refusal": code,
			"decoded_refusal": Actor._surface_error(arrays, binds), "native_format": raw.get("format"),
			"native_vertices": raw.get("vertex_count"), "native_indices": raw.get("index_count", 0)})
	return {"mesh": meta, "surfaces": surfaces}


static func _mesh_metadata(mesh: ArrayMesh, part: int, binds: int, shadow_of: int) -> Dictionary:
	"""An auxiliary mesh retains its own native transcript; the main palette digest is never reused for it."""
	var vertices: int = 0
	for surface: int in mesh.get_surface_count():
		vertices += mesh.surface_get_array_len(surface)
	var fingerprint: PackedByteArray = _auxiliary_fingerprint(mesh, binds, vertices) if shadow_of >= 0 \
		else Content.mesh_fingerprint(mesh, binds, vertices, mesh.get_surface_count())
	return {"part": part, "shadow_of": shadow_of, "has_shadow": mesh.shadow_mesh != null,
		"binds": binds, "surfaces": mesh.get_surface_count(),
		"vertices": vertices, "aabb": _bounds(mesh.get_aabb()), "aabb_bits": _bounds_bits(mesh.get_aabb()),
		"mesh_sha256": fingerprint.hex_encode(), "fingerprint_kind": "UGAUX001" if shadow_of >= 0 else "UGMESH01"}


static func _auxiliary_fingerprint(mesh: ArrayMesh, binds: int, vertices: int) -> PackedByteArray:
	"""Auxiliary identity hashes exact raw storage; a missing native decoded vertex array is never fabricated."""
	if vertices < 1 or vertices > MAX_VERTICES:
		return PackedByteArray()
	var hashing: HashingContext = HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update("UGAUX001".to_ascii_buffer())
	var header: PackedByteArray = PackedByteArray()
	header.resize(8)
	header.encode_u32(0, binds)
	header.encode_u32(4, mesh.get_surface_count())
	hashing.update(header)
	hashing.update(_bounds_bits(mesh.get_aabb()).hex_decode())
	for surface: int in mesh.get_surface_count():
		if counts_refusal(mesh.surface_get_format(surface), mesh.surface_get_array_len(surface),
				mesh.surface_get_array_index_len(surface), binds, mesh.surface_get_primitive_type(surface)) != &"" \
				or not _hash_auxiliary_surface(mesh, surface, binds, hashing):
			return PackedByteArray()
	return hashing.finish()


static func _hash_auxiliary_surface(mesh: ArrayMesh, surface: int, binds: int, hashing: HashingContext) -> bool:
	"""Every native buffer, AABB and LOD threshold contributes to the distinct auxiliary transcript."""
	var raw: Dictionary = RenderingServer.mesh_get_surface(mesh.get_rid(), surface)
	var arrays: Array = mesh.surface_get_arrays(surface)
	if buffers_refusal(raw, arrays, binds, true) != &"" or _surface_bytes(raw, []) + decoded_bytes(arrays) > MAX_SURFACE_BYTES:
		return false
	var header: PackedByteArray = PackedByteArray()
	header.resize(20)
	header.encode_u64(0, raw.format)
	header.encode_u32(8, raw.vertex_count)
	header.encode_u32(12, raw.get("index_count", 0))
	header.encode_u32(16, raw.primitive)
	hashing.update(header)
	hashing.update(_bounds_bits(raw.aabb).hex_decode())
	for key: String in RAW_KEYS:
		_hash_blob(hashing, raw.get(key, PackedByteArray()))
	var lods: Array = raw.get("lods", [])
	header.resize(4)
	header.encode_u32(0, lods.size())
	hashing.update(header)
	for lod: Dictionary in lods:
		header.encode_float(0, lod.edge_length)
		hashing.update(header)
		_hash_blob(hashing, lod.index_data)
	return true


static func _hash_blob(hashing: HashingContext, bytes: PackedByteArray) -> void:
	"""Lengths make the complete raw-buffer transcript unambiguous without copying the buffer."""
	var header: PackedByteArray = PackedByteArray()
	header.resize(4)
	header.encode_u32(0, bytes.size())
	hashing.update(header)
	if not bytes.is_empty():
		hashing.update(bytes)


static func counts_refusal(format: int, vertices: int, indices: int, binds: int, primitive: int) -> StringName:
	"""Only finite original triangle surfaces and explicit four/eight-weight skin layouts enter this census."""
	if vertices < 1 or vertices > MAX_VERTICES or indices < 0 or indices > MAX_INDICES \
			or binds < 0 or binds > 64 or primitive != Mesh.PRIMITIVE_TRIANGLES:
		return &"METAL_INPUT_COUNTS"
	if format < 0 or format & ~ALLOWED_FORMAT or not format & FORMAT_VERSION or not format & Mesh.ARRAY_FORMAT_VERTEX:
		return &"METAL_INPUT_FORMAT"
	var skinned: int = Mesh.ARRAY_FORMAT_BONES | Mesh.ARRAY_FORMAT_WEIGHTS
	if (binds > 0 and (format & skinned != skinned or format & Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES)) \
			or (binds == 0 and format & (skinned | Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)):
		return &"METAL_INPUT_SKIN_FORMAT"
	if bool(format & Mesh.ARRAY_FORMAT_INDEX) != (indices > 0):
		return &"METAL_INPUT_INDEX_FORMAT"
	if (indices if indices > 0 else vertices) % 3 != 0:
		return &"METAL_INPUT_TRIANGLES"
	return &""


func _capture_surface(mesh: ArrayMesh, part: int, surface: int, binds: int, auxiliary: bool) -> void:
	"""Raw GPU input and reference decoding refer to the same unchanged real mesh/surface."""
	var raw: Dictionary = RenderingServer.mesh_get_surface(mesh.get_rid(), surface)
	var arrays: Array = mesh.surface_get_arrays(surface)
	_capture_error = buffers_refusal(raw, arrays, binds, auxiliary)
	if _capture_error != &"":
		return
	var meta: Dictionary = _surface_metadata(raw, part, surface, binds)
	meta.position_reference = "native" if arrays[Mesh.ARRAY_VERTEX] != null else "unavailable_compressed_without_normals"
	var references: Array[PackedByteArray] = _references(arrays)
	var size: int = _surface_bytes(raw, references)
	var peak: int = size + decoded_bytes(arrays)
	if peak > MAX_SURFACE_BYTES or _numeric_bytes + size > MAX_CAPTURE_BYTES:
		_capture_error = &"METAL_INPUT_BYTE_CAPACITY"
		return
	_numeric_bytes += size
	_peak_surface_bytes = maxi(_peak_surface_bytes, peak)
	_record(meta)
	for key: String in RAW_KEYS:
		_blob(raw.get(key, PackedByteArray()))
	for reference: PackedByteArray in references:
		_blob(reference)
	for lod: Dictionary in raw.get("lods", []):
		_blob(lod.index_data)
	_rows.append(meta)
	_surface_count += 1
	_vertex_count += int(raw.vertex_count)


static func buffers_refusal(raw: Dictionary, arrays: Array, binds: int, auxiliary: bool = false) -> StringName:
	"""Unsupported extra geometry or a missing decoded field is a refusal, not an omitted proof input."""
	if arrays.size() != Mesh.ARRAY_MAX or not raw.get("format") is int or not raw.get("vertex_count") is int \
			or not raw.get("index_count", 0) is int or not raw.get("primitive") is int or not raw.get("aabb") is AABB:
		return &"METAL_INPUT_BUFFER_METADATA"
	var code: StringName = counts_refusal(raw.format, raw.vertex_count, raw.get("index_count", 0), binds, raw.primitive)
	if code != &"":
		return code
	if not raw.get("blend_shape_data", PackedByteArray()) is PackedByteArray \
			or not raw.get("blend_shape_data", PackedByteArray()).is_empty():
		return &"METAL_INPUT_EXTRA_GEOMETRY"
	if lods_refusal(raw.get("lods", [])) != &"":
		return &"METAL_INPUT_LOD_GEOMETRY"
	for key: String in RAW_KEYS:
		if not raw.get(key, PackedByteArray()) is PackedByteArray:
			return &"METAL_INPUT_BUFFER_TYPE"
	if not absent_shadow_reference(raw, arrays, binds, auxiliary) and (not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array \
			or arrays[Mesh.ARRAY_VERTEX].size() != raw.vertex_count):
		return &"METAL_INPUT_REFERENCE_CENSUS"
	return reference_refusal(raw, arrays, binds)


static func absent_shadow_reference(raw: Dictionary, arrays: Array, binds: int, auxiliary: bool) -> bool:
	"""Godot's pinned compressed-without-normal decode continues before assigning the vertex array; retain the absence."""
	return auxiliary and binds == 0 and arrays[Mesh.ARRAY_VERTEX] == null \
		and raw.format & Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES and not raw.format & Mesh.ARRAY_FORMAT_NORMAL


static func lods_refusal(value: Variant) -> StringName:
	"""Finite extra index streams retain their exact threshold and all triangles over the same vertex source."""
	if not value is Array or value.size() > 8:
		return &"METAL_INPUT_LOD_GEOMETRY"
	for row: Variant in value:
		if not row is Dictionary or not row.get("index_data") is PackedByteArray:
			return &"METAL_INPUT_LOD_GEOMETRY"
		var edge: Variant = row.get("edge_length")
		if not edge is float or not is_finite(edge) or edge <= 0.0 or row.index_data.size() < 6 \
				or row.index_data.size() > MAX_INDICES * 2 or row.index_data.size() % 6 != 0:
			return &"METAL_INPUT_LOD_GEOMETRY"
	return &""


static func reference_refusal(raw: Dictionary, arrays: Array, binds: int) -> StringName:
	"""Reference lengths and types must account for every actual vertex influence and index."""
	var size: int = int(raw.vertex_count) * (8 if int(raw.format) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS else 4)
	if binds > 0 and (not arrays[Mesh.ARRAY_BONES] is PackedInt32Array or not arrays[Mesh.ARRAY_WEIGHTS] is PackedFloat32Array):
		return &"METAL_INPUT_REFERENCE_SKIN"
	if binds > 0 and (arrays[Mesh.ARRAY_BONES].size() != size or arrays[Mesh.ARRAY_WEIGHTS].size() != size):
		return &"METAL_INPUT_REFERENCE_SKIN"
	if binds == 0 and (arrays[Mesh.ARRAY_BONES] != null or arrays[Mesh.ARRAY_WEIGHTS] != null):
		return &"METAL_INPUT_REFERENCE_SKIN"
	var index_count: int = raw.get("index_count", 0)
	if index_count > 0 and (not arrays[Mesh.ARRAY_INDEX] is PackedInt32Array or arrays[Mesh.ARRAY_INDEX].size() != index_count):
		return &"METAL_INPUT_REFERENCE_INDEX"
	if index_count == 0 and arrays[Mesh.ARRAY_INDEX] != null:
		return &"METAL_INPUT_REFERENCE_INDEX"
	return &""


static func decoded_bytes(arrays: Array) -> int:
	"""Count actual decoded arrays coexisting with raw buffers and copied reference bytes; sharing is not assumed."""
	var size: int = 0
	for value: Variant in arrays:
		if value is PackedVector3Array:
			size += value.size() * 12
		elif value is PackedVector2Array:
			size += value.size() * 8
		elif value is PackedColorArray:
			size += value.size() * 16
		elif value is PackedFloat32Array or value is PackedInt32Array:
			size += value.size() * 4
		elif value != null:
			return MAX_SURFACE_BYTES + 1
	return size


static func _surface_metadata(raw: Dictionary, part: int, surface: int, binds: int) -> Dictionary:
	"""Use public exact native offset readers; the independent Python audit derives them again."""
	var format: int = raw.format
	var count: int = raw.vertex_count
	var offsets: Array[int] = []
	for index: int in Mesh.ARRAY_MAX:
		offsets.append(RenderingServer.mesh_surface_get_format_offset(format, count, index))
	var lods: Array[Dictionary] = []
	for lod: Dictionary in raw.get("lods", []):
		var edge: PackedByteArray = PackedByteArray()
		edge.resize(4)
		edge.encode_float(0, lod.edge_length)
		lods.append({"edge_length": lod.edge_length, "edge_bits": edge.hex_encode(), "index_bytes": lod.index_data.size()})
	return {"part": part, "surface": surface, "binds": binds, "format": format,
		"vertices": count, "indices": raw.get("index_count", 0), "primitive": raw.primitive, "lods": lods,
		"aabb": _bounds(raw.aabb), "aabb_bits": _bounds_bits(raw.aabb), "offsets": offsets,
		"vertex_stride": RenderingServer.mesh_surface_get_format_vertex_stride(format, count),
		"normal_stride": RenderingServer.mesh_surface_get_format_normal_tangent_stride(format, count),
		"attribute_stride": RenderingServer.mesh_surface_get_format_attribute_stride(format, count),
		"skin_stride": RenderingServer.mesh_surface_get_format_skin_stride(format, count),
		"index_stride": RenderingServer.mesh_surface_get_format_index_stride(format, count)}


static func _references(arrays: Array) -> Array[PackedByteArray]:
	"""Retain exact float32 positions/weights and int32 IDs/indices, including unused positive influences."""
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] if arrays[Mesh.ARRAY_VERTEX] != null else PackedVector3Array()
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES] if arrays[Mesh.ARRAY_BONES] != null else PackedInt32Array()
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS] if arrays[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	return [points.to_byte_array(), bones.to_byte_array(), weights.to_byte_array(), indices.to_byte_array()]


static func _surface_bytes(raw: Dictionary, references: Array[PackedByteArray]) -> int:
	"""Charge repeated raw/reference arrays even if a runtime happens to share their backing allocation."""
	var count: int = 0
	for key: String in RAW_KEYS:
		count += (raw.get(key, PackedByteArray()) as PackedByteArray).size()
	for reference: PackedByteArray in references:
		count += reference.size()
	for lod: Dictionary in raw.get("lods", []):
		count += (lod.index_data as PackedByteArray).size()
	return count


static func _bounds(value: AABB) -> Array[float]:
	"""Readable diagnostics only; aabb_bits preserves the exact binary32 components independently."""
	return [value.position.x, value.position.y, value.position.z, value.size.x, value.size.y, value.size.z]


static func _bounds_bits(value: AABB) -> String:
	"""JSON's decimal formatting must not silently replace the exact GPU decode AABB."""
	var result: PackedByteArray = PackedByteArray()
	result.resize(24)
	for axis: int in 3:
		result.encode_float(axis * 4, value.position[axis])
		result.encode_float(12 + axis * 4, value.size[axis])
	return result.hex_encode()


func _record(value: Dictionary) -> void:
	"""Small bounded metadata accompanies each streamed surface, never one full JSON geometry image."""
	var bytes: PackedByteArray = JSON.stringify(value).to_utf8_buffer()
	assert(bytes.size() <= 16384)
	_blob(bytes)


func _blob(value: PackedByteArray) -> void:
	"""Length-delimit every buffer so the offline reader can refuse partial or extra data."""
	_stream.store_32(value.size())
	_stream.store_buffer(value)


func _finish_capture(before: int) -> void:
	"""A positive complete native census remains source-only and records native memory as a diagnostic."""
	var good: bool = _capture_error == &"" and _suite.failures.is_empty() and _surface_count > 0
	var report: Dictionary = {"schema": 1, "error": _capture_error, "assertions": _suite.assertions,
		"failures": _suite.failures, "spec_sha256": _spec_sha, "content_sha256": CONTENT_SHA,
		"surfaces": _surface_count, "vertices": _vertex_count, "numeric_bytes": _numeric_bytes,
		"peak_surface_numeric_bytes": _peak_surface_bytes,
		"rows": _rows, "meshes": _mesh_rows, "refused_mesh": _refused_mesh, "engine": Engine.get_version_info(), "display": DisplayServer.get_name(),
		"driver": RenderingServer.get_current_rendering_driver_name(),
		"method": RenderingServer.get_current_rendering_method(), "qualified_profiles": 0,
		"gpu_arithmetic_qualified": false, "world_qualified": false,
		"memory_before": before, "memory_after": OS.get_static_memory_usage(),
		"memory_peak": OS.get_static_memory_peak_usage(), "isolated_memory_qualified": false}
	if FileAccess.file_exists(_out + "/inputs.bin"):
		report["inputs_sha256"] = FileAccess.get_sha256(_out + "/inputs.bin")
	var file: FileAccess = FileAccess.open(_out + "/report.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t") + "\n")
		file.close()
	else:
		good = false
	print("metal-inputs: %d surfaces, %d vertices, %d assertions, %d failures; error=%s; qualified=0" \
		% [_surface_count, _vertex_count, _suite.assertions, _suite.failures.size(), _capture_error])
	quit(0 if good else 2)


func _refuse(code: StringName) -> void:
	"""Preflight refusals do not touch output or stage any source resource."""
	printerr(code)
	quit(2)
