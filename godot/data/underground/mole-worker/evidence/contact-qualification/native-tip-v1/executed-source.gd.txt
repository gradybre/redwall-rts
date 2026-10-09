extends "capture_work_motion.gd"
## Native source point/face witness. The marked source vertex is not an invented reach point.

var _tip_point: Vector3 = Vector3.ZERO
var _tip_rows: Array[Dictionary] = []


func _bind_actor(meshes: Dictionary) -> void:
	"""Read the same original prop vertex checked by the source-bound primitive proof."""
	super._bind_actor(meshes)
	var arrays: Array = (meshes.meshes[1] as Mesh).surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var witness: Dictionary = _spec.tip_witness.witness
	_suite.assert_true(int(witness.vertex) >= 0 and int(witness.vertex) < points.size(), "actual source head point exists")
	if not _suite.failures.is_empty():
		return
	_tip_point = points[int(witness.vertex)]
	var source: Array = witness.source_point_f32_m
	_suite.assert_equal(_tip_point, Vector3(source[0], source[1], source[2]), "same exact native prop vertex")


func _observe_clips() -> void:
	"""The actual installed attachment crosses the exact plane; sampled observations do not replace interval proof."""
	var root_point: Vector3 = Vector3(ORIGIN_U) / 1024.0
	_camera.position = root_point + Vector3(1.65, 0.8, -0.5)
	_camera.size = 1.9
	_camera.look_at(root_point + Vector3(0.05, 0.5, -0.05), Vector3.UP)
	var now: PackedInt32Array = PackedInt32Array([0, 0, 0])
	var pose: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0, 65536])
	for step: int in 9:
		var source_time: int = int(_spec.tip_witness.witness.first_frame) * 65536 + step * 8192
		_suite.assert_equal(_content.clip_into(int(_spec.tip_witness.clip), source_time, now), &"", "exact native source interval")
		for index: int in 3:
			pose[index] = now[index]
			pose[index + 3] = now[index]
		_suite.assert_equal(_actor.apply_pose(pose), &"", "same actual body/attachment renderer")
		_record_tip(step, _actor.native_matrix(1, 0) * _tip_point - root_point)
		_observed += 1
		await process_frame
		await _save_frame("source-tip-%02d" % step, int(_spec.tip_witness.clip), source_time)


func _record_tip(step: int, point: Vector3) -> void:
	"""Compare actual endpoint positions against the proved outward intervals, not a hand-selected tolerance."""
	if step == 0 or step == 8:
		var endpoint: int = 0 if step == 0 else 1
		var interval: Array = _spec.tip_witness.witness.endpoint_intervals_q24[endpoint]
		for axis: int in 3:
			_suite.assert_true(float(interval[0][axis]) / 16777216.0 <= point[axis]
				and point[axis] <= float(interval[1][axis]) / 16777216.0, "native endpoint inside exact source residual interval")
		_suite.assert_true(point.y > 0.0 if step == 0 else point.y < 0.0, "real head point lies on opposite sides")
	_tip_rows.append({"share_q16": step * 8192, "local_point_u": [point.x * 1024.0, point.y * 1024.0, point.z * 1024.0]})


func _observe_transitions() -> void:
	"""This small native run witnesses only the already authored source contact interval."""
	_suite.assert_equal(_tip_rows.size(), 9, "complete selected interval witness")


func _finish() -> void:
	"""The exact contact witness remains separate from worker assignment, support and paid target authority."""
	var report: Dictionary = {"schema": 1, "content_sha256": _content.source_digest(), "poses": _observed,
		"assertions": _suite.assertions, "failures": _suite.failures, "screenshots": _shots,
		"source_tip": _spec.tip_witness, "native_points": _tip_rows, "production_qualified": false,
		"world_identity": "same finite synthetic witness Domain/root; no real stance or work permission"}
	var output: FileAccess = FileAccess.open(_out + "/report.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t") + "\n")
	output.close()
	for failure: String in _suite.failures:
		printerr("FAIL: ", failure)
	print("mole-source-tip: %d poses, %d assertions, %d failures; qualified=0" % [_observed, _suite.assertions, _suite.failures.size()])
	quit(0 if _suite.failures.is_empty() else 2)
