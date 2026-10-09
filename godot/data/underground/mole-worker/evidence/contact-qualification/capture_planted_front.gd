extends "capture_high_wall.gd"
## Native source-only planted-front witness. The tread and target are explicit unpaid fixtures.


func _build_stage() -> void:
	"""Present the intended512u tread and next vertical face without inventing physical support truth."""
	super._build_stage()
	for child: Node in _world.get_children():
		if child is MeshInstance3D:
			child.free()
	_add_ground(Vector3i(-1024, -128, -256), Vector3i(1024, 0, 256), Color("6e5139"))
	_add_ground(Vector3i(-512, -256, -1792), Vector3i(512, 768, -768), Color("936642"))


func _observe_transitions() -> void:
	"""Read the actual original head vertex through the native palette over the proved front crossing."""
	var now: PackedInt32Array = PackedInt32Array([0, 0, 0])
	var pose: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0, 65536])
	for step: int in 9:
		_suite.assert_equal(_content.clip_into(6, 14 * 65536 + step * 8192, now), &"", "actual planted strike interval")
		for index: int in 3:
			pose[index] = now[index]
			pose[index + 3] = now[index]
		_suite.assert_equal(_actor.apply_pose(pose), &"", "actual native planted pose")
		var point: Vector3 = (_actor.native_matrix(1, 0) * _wall_tip - Vector3(ORIGIN_U) / 1024.0) * 1024.0
		if step == 0 or step == 8:
			_suite.assert_true(point.z > -768.0 if step == 0 else point.z < -768.0, "native head crosses next tread face")
		_wall_points.append({"share_q16": step * 8192, "local_point_u": [point.x, point.y, point.z]})
		_observed += 1
		await process_frame


func _finish() -> void:
	"""No unpaid fixture or native sample is promoted to a completed approach or source certificate."""
	var report: Dictionary = {"schema": 1, "content_sha256": _content.source_digest(), "poses": _observed,
		"assertions": _suite.assertions, "failures": _suite.failures, "screenshots": _shots,
		"source_frame_indices": _spec.source_frame_indices, "native_tip": _wall_points,
		"source_tip": _spec.wall_tip, "production_qualified": false,
		"world_identity": "synthetic512u tread and vertical face; no paid structure, stance, source profile or work permission"}
	var output: FileAccess = FileAccess.open(_out + "/report.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t") + "\n")
	output.close()
	for failure: String in _suite.failures:
		printerr("FAIL: ", failure)
	print("mole-planted-front: %d poses, %d assertions, %d failures; qualified=0" % [_observed, _suite.assertions, _suite.failures.size()])
	quit(0 if _suite.failures.is_empty() else 2)
