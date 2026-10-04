extends "../grip-authoring/native_grip_sequence.gd"
## Source-only varying-height tread witness. Positive deck/post prisms are unpaid engineering fixtures.


func _build_stage() -> void:
	"""Reuse actual light and immutable body resources while keeping fixture support distinct from world authority."""
	super._build_stage()
	root.size = Vector2i(1280, 720)


func _stair_fixture(rise: int) -> void:
	"""Show two64u decks and eight actual side-post prisms; there is no central solid riser."""
	for child: Node in _world.get_children():
		if child is MeshInstance3D:
			child.free()
	_add_timber(Vector3i(-1024, -64, -169), Vector3i(1024, 0, 343))
	_add_timber(Vector3i(-1024, rise - 64, -681), Vector3i(1024, rise, -169))
	for step_index: int in 2:
		var top: int = 0 if step_index == 0 else rise
		for low_x: int in [-896, 768]:
			for low_s: int in [64, 320]:
				var high_z: int = 343 - step_index * 512 - low_s
				_add_timber(Vector3i(low_x, -1024, high_z - 128), Vector3i(low_x + 128, top - 64, high_z))


func _add_timber(low: Vector3i, high: Vector3i) -> void:
	"""The original units and whole positive fixture shapes remain visible, including thickness."""
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(high - low) / 1024.0
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color("795535")
	material.roughness = 1.0
	mesh.material = material
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = Vector3(ORIGIN_U) / 1024.0 + Vector3(low + high) / 2048.0
	_world.add_child(instance)


func _observe_clips() -> void:
	"""Observe source root/joint motion through native palettes; no actual Transform or route is moved."""
	_suite.assert_equal(_content.clip_count(), _spec.stair_cases.size(), "exact stepped source census")
	var anchor: Vector3 = Vector3(ORIGIN_U) / 1024.0
	var views: Array[Vector3] = [Vector3(1.8, 0.6, -0.3), Vector3(-1.6, 0.65, -0.1), Vector3(3.9, 5.0, 4.0)]
	var labels: PackedStringArray = ["side", "opposite", "rts"]
	for clip: int in _content.clip_count():
		_stair_fixture(int(_spec.stair_cases[clip].rise_u))
		for view: int in views.size():
			_camera.position = anchor + views[view]
			_camera.size = 10.0 if labels[view] == "rts" else 2.1
			_camera.look_at(anchor + Vector3(0, 0.4, -0.2), Vector3.UP)
			await _observe_step(clip, labels[view])


func _observe_step(clip: int, label: String) -> void:
	"""Every half-frame interval is exercised; screenshots are sparse witnesses rather than collision proof."""
	var now: PackedInt32Array = PackedInt32Array([0, 0, 0])
	var timing: PackedInt32Array = PackedInt32Array([0, 0])
	var pose: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0, 65536])
	_suite.assert_true(_content.clip_timing_into(clip, timing), "finite stepped source time")
	_suite.assert_equal(timing, PackedInt32Array([90 * 65536, 0]), "explicit nonlooping91-frame source")
	for tick: int in 181:
		_suite.assert_equal(_content.clip_into(clip, tick * 32768, now), &"", "actual stepped source interval")
		for index: int in 3:
			pose[index] = now[index]
			pose[index + 3] = now[index]
		_suite.assert_equal(_actor.apply_pose(pose), &"", "original native mesh and held tool")
		_observed += 1
		await process_frame
		if tick % 20 == 0:
			await _save_frame("%s-step%d-%03d" % [label, clip, tick], clip, tick)


func _observe_transitions() -> void:
	"""This fixture does not claim idle/step/retreat policy or a varying-height support owner."""
	_suite.assert_false(bool(_spec.production_qualified), "source experiment remains unqualified")


func _finish() -> void:
	"""Retain visible source motion with its exact fixture dimensions and explicit authority gap."""
	var report: Dictionary = {"schema": 1, "content_sha256": _content.source_digest(), "poses": _observed,
		"assertions": _suite.assertions, "failures": _suite.failures, "screenshots": _shots,
		"stair_cases": _spec.stair_cases, "production_qualified": false,
		"root_contract": "source palettes include candidate root track; no gameplay Transform, route, support or pace owner",
		"world_identity": "unpaid64u timber deck and eight side-post engineering fixtures"}
	var output: FileAccess = FileAccess.open(_out + "/report.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t") + "\n")
	output.close()
	for failure: String in _suite.failures:
		printerr("FAIL: ", failure)
	print("mole-step-source: %d poses, %d assertions, %d failures; qualified=0" % [_observed, _suite.assertions, _suite.failures.size()])
	quit(0 if _suite.failures.is_empty() else 2)
