extends "capture_work_motion.gd"
## Distinct source-bound upper-course witness; the station and target are engineering fixtures.

var _wall_tip: Vector3 = Vector3.ZERO
var _wall_points: Array[Dictionary] = []


func _build_stage() -> void:
	"""Show the proposed bench-relative course without silently installing a real platform."""
	super._build_stage()
	for child: Node in _world.get_children():
		if child is MeshInstance3D:
			child.free()
	_add_ground(Vector3i(-2048, -128, -536), Vector3i(2048, 0, 2048), Color("5b5a42"))
	_add_ground(Vector3i(-512, 1024, -1560), Vector3i(512, 2048, -536), Color("936642"))


func _bind_actor(meshes: Dictionary) -> void:
	"""The rendered head point is read from the exact actual pick mesh, not an inferred socket."""
	super._bind_actor(meshes)
	var arrays: Array = (meshes.meshes[1] as Mesh).surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	_wall_tip = points[148]
	var source: Array = _spec.wall_tip.source_point_f32_m
	_suite.assert_equal(_wall_tip, Vector3(source[0], source[1], source[2]), "exact original head tip")


func _observe_clips() -> void:
	"""Observe the new forward-wall sequence and corrected approach; unchanged carry loops already have their own evidence."""
	var root_point: Vector3 = Vector3(ORIGIN_U) / 1024.0
	var views: Array[Vector3] = [Vector3(1.65, 0.8, -0.5), Vector3(-1.5, 1.1, 0.5), Vector3(3.9, 5.0, 4.0)]
	var labels: PackedStringArray = ["side", "opposite", "rts"]
	for view: int in views.size():
		_camera.position = root_point + views[view]
		_camera.size = 10.0 if labels[view] == "rts" else 2.5
		_camera.look_at(root_point + Vector3(0.05, 0.85, -0.05), Vector3.UP)
		await _observe_strike(labels[view])
		await _observe_handoff(labels[view])


func _observe_transitions() -> void:
	"""Native values independently witness which side of the exact vertical plane the real stone tip occupies."""
	var now: PackedInt32Array = PackedInt32Array([0, 0, 0])
	var pose: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0, 65536])
	for step: int in 9:
		_suite.assert_equal(_content.clip_into(6, 12 * 65536 + step * 8192, now), &"", "actual front-strike interval")
		for index: int in 3:
			pose[index] = now[index]
			pose[index + 3] = now[index]
		_suite.assert_equal(_actor.apply_pose(pose), &"", "actual native front-strike pose")
		var point: Vector3 = (_actor.native_matrix(1, 0) * _wall_tip - Vector3(ORIGIN_U) / 1024.0) * 1024.0
		if step == 0 or step == 8:
			_suite.assert_true(point.z > -536.0 if step == 0 else point.z < -536.0, "actual source crosses the selected vertical face")
		_wall_points.append({"share_q16": step * 8192, "local_point_u": [point.x, point.y, point.z]})
		_observed += 1
		await process_frame


func _finish() -> void:
	"""No authored support, profile or frontier is installed by a native source witness."""
	var report: Dictionary = {"schema": 1, "content_sha256": _content.source_digest(), "poses": _observed,
		"assertions": _suite.assertions, "failures": _suite.failures, "screenshots": _shots,
		"source_frame_indices": _spec.source_frame_indices, "native_tip": _wall_points,
		"source_tip": _spec.wall_tip, "production_qualified": false,
		"world_identity": "synthetic upper-course/bench fixture; no actual paid structure, profile or work permission"}
	var output: FileAccess = FileAccess.open(_out + "/report.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t") + "\n")
	output.close()
	for failure: String in _suite.failures:
		printerr("FAIL: ", failure)
	print("mole-high-wall: %d poses, %d assertions, %d failures; qualified=0" % [_observed, _suite.assertions, _suite.failures.size()])
	quit(0 if _suite.failures.is_empty() else 2)
