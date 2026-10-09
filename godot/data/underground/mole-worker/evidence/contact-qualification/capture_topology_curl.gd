extends "capture_topology.gd"
## ADR 1216: the same native primitive census as capture_topology.gd, of the curled pick paw's compiled content.
## Only the body derivative differs (mole_grip_curl_source.gd); the rig and pick bindings are read as before.

const Curl := preload("res://data/underground/mole-worker/mole_grip_curl_source.gd")


func _run() -> void:
	"""Load the curled content, rebuild its meshes natively and write their full index census."""
	if FileAccess.file_exists(_out + "/topology.json"):
		printerr("TOPOLOGY_OUTPUT_EXISTS")
		quit(2)
		return
	_suite.assert_equal(_content.load_file(_spec.content, _spec.content_sha256, _spec.reserve_bytes), &"", "exact curled content")
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
		_write(parts)
	for failure: String in _suite.failures:
		printerr("FAIL: ", failure)
	print("mole-curl-topology: %d parts, %d assertions, %d failures; qualified=0" % [parts.size(), _suite.assertions, _suite.failures.size()])
	quit(0 if _suite.failures.is_empty() else 2)


func _write(parts: Array[Dictionary]) -> void:
	"""The census with the curled derivative's identities."""
	var file: FileAccess = FileAccess.open(_out + "/topology.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema": 1, "content_sha256": _content.source_digest(),
		"original_body_sha256": Grip.SOURCE_DIGEST, "derived_body_sha256": Curl.DERIVED_DIGEST,
		"assertions": _suite.assertions, "failures": _suite.failures,
		"parts": parts, "pick_binding": _pick_binding, "rig_binding": _rig_binding,
		"production_qualified": false}, "\t") + "\n")
	file.close()


func _derive_actual(original: Demo, props: Props) -> Dictionary:
	"""The curled derivative from the exact original inputs, then the same rig and pick binding capture."""
	var nodes: Array[Node] = original.get_node("Body").find_children("*", "MeshInstance3D", true, false)
	_suite.assert_equal(nodes.size(), 1, "one actual original body")
	if nodes.size() != 1:
		return {}
	var instance: MeshInstance3D = nodes[0] as MeshInstance3D
	var tunnel: GDScript = load("res://demo/tunnel/tunnel_ext.gd") as GDScript
	var fit: Transform3D = tunnel.call("pick_fit", props)
	var result: Curl.Result = Curl.create(instance.mesh as ArrayMesh, instance.skin, original.get("_skeleton") as Skeleton3D, fit)
	_suite.assert_equal(result.error, &"", "same source-bound curled derivative as the bake")
	_suite.assert_equal(result.changed_vertices, Curl.CHANGED_VERTICES, "exact affected source vertices")
	_suite.assert_true(props.is_staged(&"mole_pick"), "actual staged pick")
	if result.error != &"":
		return {}
	_capture_bindings(original, props)
	var meshes: Array[Mesh] = [result.mesh, props.mesh_of(&"mole_pick")]
	var materials: Array[Material] = [instance.material_override, null]
	return {"meshes": meshes, "materials": materials}


func _capture_bindings(original: Demo, props: Props) -> void:
	"""The rig and the pick binding, exactly as capture_topology.gd records them."""
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
