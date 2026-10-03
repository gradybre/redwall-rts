extends "../grip-authoring/native_grip_sequence.gd"
## Offline primitive topology, captured only after the actual compact source and mesh identity match.

const MAX_INDICES: int = 196608

var _pick_binding: Dictionary = {}
var _rig_binding: Dictionary = {}


func _run() -> void:
	"""No animation sample or approximate bounding box substitutes for the native primitive census."""
	if FileAccess.file_exists(_out + "/topology.json"):
		printerr("TOPOLOGY_OUTPUT_EXISTS")
		quit(2)
		return
	_suite.assert_equal(_content.load_file(_spec.content, _spec.content_sha256, _spec.reserve_bytes), &"", "exact compact source")
	_world = Node3D.new()
	root.add_child(_world)
	var meshes: Dictionary = _borrow_actual_meshes()
	var parts: Array[Dictionary] = []
	if _suite.failures.is_empty():
		for part: int in meshes.meshes.size():
			parts.append(_capture_part(meshes.meshes[part] as ArrayMesh, part))
	_world.free()
	_world = null
	if _suite.failures.is_empty():
		var file: FileAccess = FileAccess.open(_out + "/topology.json", FileAccess.WRITE)
		file.store_string(JSON.stringify({"schema": 1, "content_sha256": _content.source_digest(),
			"original_body_sha256": Grip.SOURCE_DIGEST, "derived_body_sha256": Grip.DERIVED_DIGEST,
			"assertions": _suite.assertions, "failures": _suite.failures,
			"parts": parts, "pick_binding": _pick_binding, "rig_binding": _rig_binding,
			"production_qualified": false}, "\t") + "\n")
		file.close()
	for failure: String in _suite.failures:
		printerr("FAIL: ", failure)
	print("mole-topology: %d parts, %d assertions, %d failures; qualified=0" % [parts.size(), _suite.assertions, _suite.failures.size()])
	quit(0 if _suite.failures.is_empty() else 2)


func _derive_actual(original: Demo, props: Props) -> Dictionary:
	"""Capture the exact original fitting frame and shaft pivot used by the actual hand owner."""
	var result: Dictionary = super._derive_actual(original, props)
	if not result.is_empty():
		_rig_binding = _capture_rig(original)
		var tunnel: GDScript = load("res://demo/tunnel/tunnel_ext.gd") as GDScript
		var constants: Dictionary = tunnel.get_script_constant_map()
		var bound: AABB = props.drawn_bound(constants.PICK_KEY)
		var grip: Vector3 = Vector3(bound.end.x - bound.size.x * constants.PICK_GRIP_SHARE,
			bound.get_center().y, bound.get_center().z)
		var fit: Transform3D = props.fit_of(constants.PICK_KEY)
		var pivot: Vector3 = fit.affine_inverse() * grip
		_pick_binding = {"key": constants.PICK_KEY, "grip_share": constants.PICK_GRIP_SHARE,
			"drawn_bounds_m": [bound.position.x, bound.position.y, bound.position.z, bound.end.x, bound.end.y, bound.end.z],
			"drawn_grip_m": [grip.x, grip.y, grip.z], "prop_local_grip_m": [pivot.x, pivot.y, pivot.z],
			"fit": [fit.basis.x.x, fit.basis.x.y, fit.basis.x.z, fit.basis.y.x, fit.basis.y.y, fit.basis.y.z,
				fit.basis.z.x, fit.basis.z.y, fit.basis.z.z, fit.origin.x, fit.origin.y, fit.origin.z]}
	return result


func _capture_rig(original: Demo) -> Dictionary:
	"""The finite source-manufacture transition uses the actual full bind hierarchy, not inferred joint names."""
	var skeleton: Skeleton3D = original.get("_skeleton") as Skeleton3D
	var nodes: Array[Node] = original.get_node("Body").find_children("*", "MeshInstance3D", true, false)
	var skin: Skin = (nodes[0] as MeshInstance3D).skin
	var bones: Array[Dictionary] = []
	_suite.assert_equal(skin.get_bind_count(), Grip.BINDS, "exact original bind census")
	_suite.assert_equal(skeleton.get_bone_count(), Grip.BINDS, "exact original hierarchy census")
	for bind: int in skin.get_bind_count():
		var name: StringName = skin.get_bind_name(bind)
		var bone: int = skeleton.find_bone(name) if name != &"" else skin.get_bind_bone(bind)
		_suite.assert_equal(bone, bind, "complete exact ordered actual rig")
		var pose: Transform3D = skin.get_bind_pose(bind)
		bones.append({"bind": bind, "bone": bone, "name": skeleton.get_bone_name(bone),
			"parent": skeleton.get_bone_parent(bone), "inverse_bind": [pose.basis.x.x, pose.basis.x.y, pose.basis.x.z,
				pose.basis.y.x, pose.basis.y.y, pose.basis.y.z, pose.basis.z.x, pose.basis.z.y, pose.basis.z.z,
				pose.origin.x, pose.origin.y, pose.origin.z]})
	return {"right_hand": Grip.HAND, "bones": bones}


func _capture_part(mesh: ArrayMesh, part: int) -> Dictionary:
	"""Every vertex and triangle is covered; unsupported primitives and oversized inputs refuse before array access."""
	var surfaces: Array[Dictionary] = []
	var total_vertices: int = 0
	for surface: int in mesh.get_surface_count():
		var vertices: int = mesh.surface_get_array_len(surface)
		total_vertices += vertices
		var count: int = mesh.surface_get_array_index_len(surface)
		_suite.assert_true(vertices > 0 and vertices <= Content.MAX_VERTICES and count <= MAX_INDICES, "bounded native topology")
		_suite.assert_equal(mesh.surface_get_primitive_type(surface), Mesh.PRIMITIVE_TRIANGLES, "actual triangles")
		if not _suite.failures.is_empty():
			return {}
		var arrays: Array = mesh.surface_get_arrays(surface)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			indices.resize(vertices)
			for index: int in vertices:
				indices[index] = index
		_suite.assert_equal(indices.size() % 3, 0, "complete triangle triples")
		for index: int in indices:
			_suite.assert_true(index >= 0 and index < vertices, "actual bounded vertex index")
		surfaces.append({"surface": surface, "vertex_count": vertices,
			"native_index_count": count, "primitive": mesh.surface_get_primitive_type(surface), "indices": Array(indices)})
	var binds: int = Grip.BINDS if part == 0 else 0
	var fingerprint: PackedByteArray = Content.mesh_fingerprint(mesh, binds, total_vertices, mesh.get_surface_count())
	_suite.assert_equal(fingerprint.size(), 32, "exact source geometry transcript")
	return {"part": part, "mesh_sha256": fingerprint.hex_encode(), "surfaces": surfaces}
