extends "res://test/framework/test_case.gd"
## Finite source-reader tests only; actual RD readback requires the separately pinned native capture.

var _capture: GDScript = null


func before_each() -> void:
	"""Load static validation without instantiating the capture SceneTree or loading actual meshes."""
	var path: String = ProjectSettings.globalize_path("res://").path_join("../tools/capture_underground_metal_inputs.gd").simplify_path()
	_capture = load(path) as GDScript
	assert_true(_capture != null, "exact capture script loaded")


func after_each() -> void:
	"""No capture SceneTree or borrowed asset survives a parser fixture."""
	_capture = null


func _format() -> int:
	"""Synthetic current-format triangle with explicit four-lane skin."""
	return _capture.FORMAT_VERSION | Mesh.ARRAY_FORMAT_VERTEX | Mesh.ARRAY_FORMAT_BONES | Mesh.ARRAY_FORMAT_WEIGHTS


func _arrays() -> Array:
	"""Every declared reference vertex/influence is present; no actual source permission."""
	var result: Array = []
	result.resize(Mesh.ARRAY_MAX)
	result[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP])
	result[Mesh.ARRAY_BONES] = PackedInt32Array([0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3])
	result[Mesh.ARRAY_WEIGHTS] = PackedFloat32Array([1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0])
	return result


func _raw() -> Dictionary:
	"""Only metadata/type shape is tested here; the independent auditor checks exact raw byte lengths/words."""
	return {"format": _format(), "vertex_count": 3, "primitive": Mesh.PRIMITIVE_TRIANGLES,
		"aabb": AABB(Vector3.ZERO, Vector3.ONE)}


func test_finite_current_format_and_every_weight_lane_are_required() -> void:
	"""Four/eight lanes are explicit; unsupported flags, cardinality and arithmetic inputs refuse."""
	assert_equal(_capture.counts_refusal(_format(), 3, 0, 24, Mesh.PRIMITIVE_TRIANGLES), &"", "four lanes")
	assert_equal(_capture.counts_refusal(_format() | Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS, 3, 0, 24, 3), &"", "eight lanes")
	for count: int in [-1, 0, 32769, 9223372036854775807]:
		assert_equal(_capture.counts_refusal(_format(), count, 0, 24, 3), &"METAL_INPUT_COUNTS", "bounded first")
	for flag: int in [Mesh.ARRAY_FLAG_USE_2D_VERTICES, Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE, 1 << 36, 1 << 6]:
		assert_equal(_capture.counts_refusal(_format() | flag, 3, 0, 24, 3), &"METAL_INPUT_FORMAT", "unsupported exact layout")
	assert_equal(_capture.counts_refusal(_format() | Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES, 3, 0, 24, 3),
		&"METAL_INPUT_SKIN_FORMAT", "no compressed skin inference")
	assert_equal(_capture.counts_refusal(_format(), 3, 3, 24, 3), &"METAL_INPUT_INDEX_FORMAT", "index bit required")


func test_missing_short_or_wrong_reference_data_refuses_without_mutation() -> void:
	"""A reference can't omit an unused bone lane or retain an undeclared static skin array."""
	var arrays: Array = _arrays()
	assert_equal(_capture.buffers_refusal(_raw(), arrays, 24), &"", "complete fixture metadata")
	arrays[Mesh.ARRAY_WEIGHTS] = PackedFloat32Array([1])
	assert_equal(_capture.buffers_refusal(_raw(), arrays, 24), &"METAL_INPUT_REFERENCE_SKIN", "truncated weights")
	assert_equal(arrays[Mesh.ARRAY_WEIGHTS], PackedFloat32Array([1]), "refusal does not normalize or fill")
	arrays = _arrays()
	arrays[Mesh.ARRAY_VERTEX] = "bad"
	assert_equal(_capture.buffers_refusal(_raw(), arrays, 24), &"METAL_INPUT_REFERENCE_CENSUS", "wrong vertex type")
	var raw: Dictionary = _raw()
	raw.format = _capture.FORMAT_VERSION | Mesh.ARRAY_FORMAT_VERTEX
	assert_equal(_capture.buffers_refusal(raw, _arrays(), 0), &"METAL_INPUT_REFERENCE_SKIN", "undeclared static lanes")


func test_extra_geometry_and_malformed_raw_storage_are_never_omitted() -> void:
	"""Blend data, malformed LODs and unexpected native storage never silently disappear."""
	for change: Dictionary in [{"lods": [1]}, {"lods": false}]:
		var raw: Dictionary = _raw()
		raw.merge(change, true)
		assert_equal(_capture.buffers_refusal(raw, _arrays(), 24), &"METAL_INPUT_LOD_GEOMETRY", "extra primitive source")
	var bad: Dictionary = _raw()
	bad.blend_shape_data = PackedByteArray([1])
	assert_equal(_capture.buffers_refusal(bad, _arrays(), 24), &"METAL_INPUT_EXTRA_GEOMETRY", "unproved blend")
	bad = _raw()
	bad.skin_data = [1, 2]
	assert_equal(_capture.buffers_refusal(bad, _arrays(), 24), &"METAL_INPUT_BUFFER_TYPE", "packed native storage only")
	bad = _raw()
	bad.index_count = "3"
	assert_equal(_capture.buffers_refusal(bad, _arrays(), 24), &"METAL_INPUT_BUFFER_METADATA", "type before arithmetic")


func test_native_backend_and_exact_engine_cannot_be_relabelled() -> void:
	"""A synthetic metadata pass is not a native result; headless and GL remain refused."""
	var engine: Dictionary = {"hash": _capture.ENGINE_SHA, "major": 4, "minor": 7, "patch": 2, "build": "official"}
	assert_equal(_capture.backend_refusal(engine, "macOS", "metal", "forward_plus"), &"", "exact metadata fixture")
	assert_equal(_capture.backend_refusal(engine, "headless", "metal", "forward_plus"), &"METAL_INPUT_BACKEND", "no dummy readback")
	assert_equal(_capture.backend_refusal(engine, "macOS", "opengl3", "gl_compatibility"), &"METAL_INPUT_BACKEND", "not GL evidence")
	engine.hash = "0".repeat(40)
	assert_equal(_capture.backend_refusal(engine, "macOS", "metal", "forward_plus"), &"METAL_INPUT_ENGINE", "actual source version")


func test_decoded_arrays_count_coexists_with_raw_and_reference_copies() -> void:
	"""There is no assumption that raw, native decoded, and .to_byte_array references share storage."""
	assert_equal(_capture.decoded_bytes(_arrays()), 132, "three positions plus twelve IDs and weights")
	var bad: Array = _arrays()
	bad[Mesh.ARRAY_COLOR] = "unexpected"
	assert_true(_capture.decoded_bytes(bad) > _capture.MAX_SURFACE_BYTES, "unknown allocation refuses")


func test_every_lod_is_finite_bounded_and_keeps_complete_triangles() -> void:
	"""Thresholds and byte limits preflight actual auxiliary streams; the offline audit checks every ID."""
	var row: Dictionary = {"edge_length": 0.25, "index_data": PackedByteArray([0, 0, 1, 0, 2, 0])}
	assert_equal(_capture.lods_refusal([row]), &"", "one explicit auxiliary triangle")
	for threshold: Variant in [0.0, -1.0, INF, NAN, "1"]:
		var changed: Dictionary = row.duplicate()
		changed.edge_length = threshold
		assert_equal(_capture.lods_refusal([changed]), &"METAL_INPUT_LOD_GEOMETRY", "finite native threshold")
	var nine: Array = []
	nine.resize(9)
	nine.fill(row)
	assert_equal(_capture.lods_refusal(nine), &"METAL_INPUT_LOD_GEOMETRY", "finite complete stream count")
	row.index_data = PackedByteArray([0, 0, 1, 0])
	assert_equal(_capture.lods_refusal([row]), &"METAL_INPUT_LOD_GEOMETRY", "no partial triangle")


func test_shadow_welding_uses_explicit_index_budget_not_primary_mesh_ratio() -> void:
	"""An auxiliary transcript stays separate when welded vertices have more incident triangles than the primary loader admits."""
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP])
	var indices: PackedInt32Array = PackedInt32Array()
	for repeat: int in 8:
		indices.append_array(PackedInt32Array([0, 1, 2]))
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	assert_equal(_capture.Content.mesh_fingerprint(mesh, 0, 3, 1).size(), 0, "unchanged primary ratio refuses")
	assert_equal(_capture._auxiliary_fingerprint(mesh, 0, 3).size(), 32, "separate bounded auxiliary transcript")
	assert_equal(_capture._auxiliary_fingerprint(mesh, 0, 32769).size(), 0, "count preflight remains finite")


func test_binary_metadata_preserves_actual_float_bits() -> void:
	"""AABB JSON text is diagnostic and cannot replace the six exact source components."""
	var box: AABB = AABB(Vector3(-0.428611934185028, 0.0, -0.5), Vector3.ONE)
	var bits: String = _capture._bounds_bits(box)
	assert_equal(bits.length(), 48, "six complete binary32 components")
	assert_equal(bits.hex_decode().decode_float(0), box.position.x, "exact negative source component")
	assert_equal(bits.hex_decode().decode_float(20), box.size.z, "exact final source component")


func test_missing_compressed_shadow_cpu_reference_is_explicit_and_auxiliary_only() -> void:
	"""The pinned engine omits this vertex array; raw-only capture must not synthesize a native reference."""
	var raw: Dictionary = _raw()
	raw.format = _capture.FORMAT_VERSION | Mesh.ARRAY_FORMAT_VERTEX | Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	assert_equal(_capture.buffers_refusal(raw, arrays, 0), &"METAL_INPUT_REFERENCE_CENSUS", "primary can't omit vertices")
	assert_equal(_capture.buffers_refusal(raw, arrays, 0, true), &"", "explicit auxiliary raw-only source")
	raw.format |= Mesh.ARRAY_FORMAT_NORMAL
	assert_equal(_capture.buffers_refusal(raw, arrays, 0, true), &"METAL_INPUT_REFERENCE_CENSUS", "only exact absent branch")
