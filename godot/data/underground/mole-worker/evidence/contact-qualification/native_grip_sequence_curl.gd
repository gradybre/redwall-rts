extends "../grip-authoring/native_grip_sequence.gd"
## ADR 1216: the accepted native grip replay, of the curled pick paw's compiled content (curl-v1).
## Only the body derivative and the report's identities differ from native_grip_sequence.gd.

const Curl := preload("res://data/underground/mole-worker/mole_grip_curl_source.gd")


func _derive_actual(original: Demo, props: Props) -> Dictionary:
	"""The curled derivative from the exact original inputs; the same pick, held by the curled paw's fit."""
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
	var meshes: Array[Mesh] = [result.mesh, props.mesh_of(&"mole_pick")]
	var materials: Array[Material] = [instance.material_override, null]
	return {"meshes": meshes, "materials": materials}


func _finish() -> void:
	"""The same report shape with the curled derivative's identities."""
	var report: Dictionary = {"schema": 1, "content_sha256": _content.source_digest(), "poses": _observed,
		"assertions": _suite.assertions, "failures": _suite.failures, "screenshots": _shots,
		"production_qualified": false, "grip_quality": "CURLED_SHAPE_APPROVED; NATIVE_REPLAY_FOR_REVIEW",
		"source_mesh_sha256": Grip.SOURCE_DIGEST, "derived_mesh_sha256": Curl.DERIVED_DIGEST,
		"world_identity": "synthetic fixture with actual finite pack bounds; no route/work permission"}
	var output: FileAccess = FileAccess.open(_out + "/report.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t") + "\n")
	output.close()
	for failure: String in _suite.failures:
		printerr("FAIL: ", failure)
	print("native-curl-grip-content: %d poses, %d assertions, %d failures; qualified=0" % [_observed, _suite.assertions, _suite.failures.size()])
	quit(0 if _suite.failures.is_empty() else 2)
