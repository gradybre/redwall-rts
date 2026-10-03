extends "../native_sequence.gd"
## Actual compact replay of the explicitly authored firm mole hand, using the same immutable helper as its bake.

const Grip := preload("res://data/underground/mole-worker/mole_grip_source.gd")


func _borrow_actual_meshes() -> Dictionary:
	"""Rebuild the reviewed fixed derivative from its exact original inputs, then require the compact mesh digest."""
	_suite.assert_equal(FileAccess.get_sha256(_spec.manifest), _spec.manifest_sha256, "actual manifest source")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_spec.manifest)) as Dictionary
	var space: CastSpace = CastSpace.new()
	space.setup([], [])
	var original: Demo = Demo.new()
	_suite.assert_true(original.setup_creature(0, &"mole_digger", manifest.cast.mole_digger, space, 1729), "actual staged original mole")
	_world.add_child(original)
	original.visible = false
	var props: Props = Props.new()
	props.load_from(manifest)
	var result: Dictionary = _derive_actual(original, props)
	original.free()
	if not result.is_empty():
		_suite.assert_equal(_content.mesh_binding_refusal(result.meshes), &"", "exact authored native/Python geometry fingerprint")
	return result


func _derive_actual(original: Demo, props: Props) -> Dictionary:
	"""No matching filename or substitute body can pass the immutable original/derivative and fit checks."""
	var nodes: Array[Node] = original.get_node("Body").find_children("*", "MeshInstance3D", true, false)
	_suite.assert_equal(nodes.size(), 1, "one actual original body")
	if nodes.size() != 1:
		return {}
	var instance: MeshInstance3D = nodes[0] as MeshInstance3D
	var tunnel: GDScript = load("res://demo/tunnel/tunnel_ext.gd") as GDScript
	var fit: Transform3D = tunnel.call("pick_fit", props)
	var result: Grip.Result = Grip.create(instance.mesh as ArrayMesh, instance.skin, original.get("_skeleton") as Skeleton3D, fit)
	_suite.assert_equal(result.error, &"", "same source-bound authored grip as the finite bake")
	_suite.assert_equal(result.changed_vertices, Grip.CHANGED_VERTICES, "exact affected source vertices")
	_suite.assert_true(props.is_staged(&"mole_pick"), "actual staged pick")
	if result.error != &"":
		return {}
	var meshes: Array[Mesh] = [result.mesh, props.mesh_of(&"mole_pick")]
	var materials: Array[Material] = [instance.material_override, null]
	return {"meshes": meshes, "materials": materials}


func _finish() -> void:
	"""Retain a distinct authored-geometry report; visual source approval is not a live work/profile permission."""
	var report: Dictionary = {"schema": 1, "content_sha256": _content.source_digest(), "poses": _observed,
		"assertions": _suite.assertions, "failures": _suite.failures, "screenshots": _shots,
		"production_qualified": false, "grip_quality": "AUTHORED_SOURCE_APPROVED; MATRIX_REPLAY_REQUIRES_REVIEW",
		"source_mesh_sha256": Grip.SOURCE_DIGEST, "derived_mesh_sha256": Grip.DERIVED_DIGEST,
		"world_identity": "synthetic fixture with actual finite pack bounds; no route/work permission"}
	var output: FileAccess = FileAccess.open(_out + "/report.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t") + "\n")
	output.close()
	for failure: String in _suite.failures:
		printerr("FAIL: ", failure)
	print("native-grip-content: %d poses, %d assertions, %d failures; qualified=0" % [_observed, _suite.assertions, _suite.failures.size()])
	quit(0 if _suite.failures.is_empty() else 2)
