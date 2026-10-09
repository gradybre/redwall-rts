extends "../grip-authoring/native_grip_sequence.gd"
## Source-indexed motion witness on a deliberately visible candidate ground/target fixture.

var _source_indices: PackedInt32Array = PackedInt32Array()


func _build_stage() -> void:
	"""The one-metre target is shown explicitly; these drawing surfaces confer no simulation support."""
	super._build_stage()
	var floor_color: Color = Color("5b5a42")
	_add_ground(Vector3i(-2048, -64, -2048), Vector3i(-512, 0, 2048), floor_color)
	_add_ground(Vector3i(512, -64, -2048), Vector3i(2048, 0, 2048), floor_color)
	_add_ground(Vector3i(-512, -64, -2048), Vector3i(512, 0, 350), floor_color)
	_add_ground(Vector3i(-512, -64, 1374), Vector3i(512, 0, 2048), floor_color)
	_add_ground(Vector3i(-512, -1024, 350), Vector3i(512, 0, 1374), Color("936642"))
	var last: int = int(_spec.last_source_frame)
	_suite.assert_true(last >= 1 and last <= 56, "explicit finite strike endpoint")
	for frame: int in last + 1:
		_source_indices.append(frame)
	for frame: int in range(last - 1, -1, -1):
		_source_indices.append(frame)


func _add_ground(low: Vector3i, high: Vector3i, color: Color) -> void:
	"""Exact integer candidate geometry is presentation evidence, not a paid cube or clearance owner."""
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(high - low) / 1024.0
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	mesh.material = material
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = mesh
	node.position = Vector3(ORIGIN_U) / 1024.0 + Vector3(low + high) / 2048.0
	_world.add_child(node)


func _observe_clips() -> void:
	"""The actual accepted matrix renderer traverses each source interval forward then backward."""
	var root_point: Vector3 = Vector3(ORIGIN_U) / 1024.0
	var views: Array[Vector3] = [Vector3(-1.45, 1.05, 1.9), Vector3(1.65, 0.8, 0.5), Vector3(0.2, 1.9, 1.2)]
	var labels: PackedStringArray = ["rear", "side", "overhead"]
	for view: int in views.size():
		_camera.position = root_point + views[view]
		_camera.size = 1.65
		_camera.look_at(root_point + Vector3(0.1, 0.4, 0.15), Vector3.UP)
		await _observe_strike(labels[view])


func _observe_strike(label: String) -> void:
	"""No source extrapolation or sampled pose substitution; only positive exact finite source interpolation."""
	var first: PackedInt32Array = PackedInt32Array([0, 0, 0])
	var last: PackedInt32Array = PackedInt32Array([0, 0, 0])
	var pose: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0, 65536])
	for frame: int in _source_indices.size():
		_suite.assert_equal(_content.clip_into(6, _source_indices[frame] * 65536, first), &"", "actual original frame")
		var next: int = mini(frame + 1, _source_indices.size() - 1)
		_suite.assert_equal(_content.clip_into(6, _source_indices[next] * 65536, last), &"", "actual next/retrace frame")
		for step: int in 2:
			pose[0] = first[0]
			pose[1] = last[0]
			pose[2] = step * 32768
			for index: int in 3:
				pose[index + 3] = pose[index]
			_suite.assert_equal(_actor.apply_pose(pose), &"", "actual source-indexed native pose")
			_observed += 1
			await process_frame
			if step == 0 and (frame % 6 == 0 or frame == int(_spec.last_source_frame) or frame + 1 == _source_indices.size()):
				await _save_frame("%s-%03d-source%03d" % [label, frame, _source_indices[frame]], 6, frame * 2)


func _observe_transitions() -> void:
	"""This pilot reviews only the strike/retrace; entry and actual state-owner gates stay explicit."""
	_suite.assert_equal(_source_indices[0], _source_indices[_source_indices.size() - 1], "same safe candidate endpoint")


func _finish() -> void:
	"""The visible target is a labelled design fixture, never a production contact qualification."""
	var report: Dictionary = {"schema": 1, "content_sha256": _content.source_digest(), "poses": _observed,
		"assertions": _suite.assertions, "failures": _suite.failures, "screenshots": _shots,
		"source_frame_indices": Array(_source_indices), "source_clip": 6, "production_qualified": false,
		"candidate_target_u": [-512, -1024, 350, 512, 0, 1374], "native_motion_review": "PENDING",
		"world_identity": "synthetic target/support fixture; no paid operation, real stance or work permission"}
	var output: FileAccess = FileAccess.open(_out + "/report.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t") + "\n")
	output.close()
	for failure: String in _suite.failures:
		printerr("FAIL: ", failure)
	print("mole-contact-motion: %d poses, %d assertions, %d failures; qualified=0" % [_observed, _suite.assertions, _suite.failures.size()])
	quit(0 if _suite.failures.is_empty() else 2)
