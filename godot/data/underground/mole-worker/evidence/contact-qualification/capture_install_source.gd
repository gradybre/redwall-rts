extends "../grip-authoring/native_grip_sequence.gd"
## Distinct source-only stone-adze fitting witness on a billed, non-supporting bearer candidate.

var _poll_point: Vector3 = Vector3.ZERO
var _native_poll: Array[Dictionary] = []


func _build_stage() -> void:
	"""Keep original materials/light and a readable RTS fixture; no actual paid structure is created."""
	super._build_stage()
	root.size = Vector2i(1280, 720)
	_suite.assert_true(OS.get_user_data_dir().ends_with(str(_spec.user_directory_name)), "isolated actual user directory")


func _bind_actor(meshes: Dictionary) -> void:
	"""Read the exact original broad-adze vertex from the actual bound native mesh."""
	super._bind_actor(meshes)
	var arrays: Array = (meshes.meshes[1] as Mesh).surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	_poll_point = points[int(_spec.poll_vertex)]
	var source: Array = _spec.poll_source_m
	_suite.assert_equal(_poll_point, Vector3(source[0], source[1], source[2]), "actual source poll vertex")


func _fixture(target: int) -> void:
	"""Show the actual previous supports and one loose bearer; the bearer never becomes worker support."""
	for child: Node in _world.get_children():
		if child is MeshInstance3D:
			child.free()
	var rows: Array = _spec.fixtures[target]
	for index: int in rows.size():
		var color: Color = Color("5d5942") if target == 0 else Color("795535")
		if index == rows.size() - 1:
			color = Color("a47b4f")
		_add_part(rows[index], color)


func _add_part(row: Array, color: Color) -> void:
	"""Show the exact positive candidate prisms and original dimensions."""
	var low: Vector3i = Vector3i(row[0], row[1], row[2])
	var high: Vector3i = Vector3i(row[3], row[4], row[5])
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(high - low) / 1024.0
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	mesh.material = material
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = Vector3(ORIGIN_U) / 1024.0 + Vector3(low + high) / 2048.0
	_world.add_child(instance)


func _observe_clips() -> void:
	"""Observe every finite source half-frame for both existing-target cases and three actual camera views."""
	_suite.assert_equal(_content.clip_count(), 3, "distinct poll work/entry/recovery clips")
	var anchor: Vector3 = Vector3(ORIGIN_U) / 1024.0
	var views: Array[Vector3] = [Vector3(1.8, 0.75, -0.4), Vector3(-1.65, 1.1, 0.4), Vector3(3.9, 5.0, 4.0)]
	var names: PackedStringArray = ["side", "opposite", "rts"]
	for target: int in 2:
		_fixture(target)
		for view: int in views.size():
			_camera.position = anchor + views[view]
			_camera.size = 10.0 if names[view] == "rts" else 2.0
			_camera.look_at(anchor + Vector3(0.0, 0.35, -0.2), Vector3.UP)
			for clip: int in 3:
				await _observe_install_clip(clip, "%s-target%d" % [names[view], target])


func _observe_install_clip(clip: int, label: String) -> void:
	"""These fixed source phases are not a BUILD clock or authoritative work completion."""
	var now: PackedInt32Array = PackedInt32Array([0, 0, 0])
	var timing: PackedInt32Array = PackedInt32Array([0, 0])
	var pose: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0, 65536])
	_suite.assert_true(_content.clip_timing_into(clip, timing), "finite poll source time")
	_suite.assert_equal(timing, PackedInt32Array([int(_spec.duration_q16[clip]), 0]), "exact nonlooping source")
	@warning_ignore("integer_division") var count: int = timing[0] / 32768 + 1
	for tick: int in count:
		_suite.assert_equal(_content.clip_into(clip, tick * 32768, now), &"", "actual source interval")
		for index: int in 3:
			pose[index] = now[index]
			pose[index + 3] = now[index]
		_suite.assert_equal(_actor.apply_pose(pose), &"", "actual native body and held poll")
		_observed += 1
		await process_frame
		if tick % 10 == 0 or tick == count - 1:
			await _save_frame("%s-clip%d-%03d" % [label, clip, tick], clip, tick)


func _observe_transitions() -> void:
	"""Witness the native adze crossing the selected timber plane; its complete patch needs separate proof."""
	var now: PackedInt32Array = PackedInt32Array([0, 0, 0])
	var pose: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0, 65536])
	for step: int in 9:
		_suite.assert_equal(_content.clip_into(0, 14 * 65536 + step * 8192, now), &"", "actual poll contact interval")
		for index: int in 3:
			pose[index] = now[index]
			pose[index + 3] = now[index]
		_suite.assert_equal(_actor.apply_pose(pose), &"", "actual native poll point")
		var point: Vector3 = (_actor.native_matrix(1, 0) * _poll_point - Vector3(ORIGIN_U) / 1024.0) * 1024.0
		if step == 0 or step == 8:
			var plane_y: float = float(_spec.contact_plane_y_u)
			_suite.assert_true(point.y > plane_y if step == 0 else point.y < plane_y, "source adze crosses timber face")
		_native_poll.append({"share_q16": step * 8192, "local_point_u": [point.x, point.y, point.z]})
		_observed += 1
		await process_frame


func _finish() -> void:
	"""Retain exact native witnesses without installing a target, paying work or admitting a production profile."""
	var report: Dictionary = {"schema": 1, "content_sha256": _content.source_digest(), "poses": _observed,
		"assertions": _suite.assertions, "failures": _suite.failures, "screenshots": _shots,
		"native_poll": _native_poll, "targets": _spec.targets, "production_qualified": false,
		"user_directory": OS.get_user_data_dir(),
		"world_identity": "retained earth/prior L0 and loose billed bearer candidate; no BUILD/paid/support permission"}
	var output: FileAccess = FileAccess.open(_out + "/report.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t") + "\n")
	output.close()
	for failure: String in _suite.failures:
		printerr("FAIL: ", failure)
	print("mole-install-source: %d poses, %d assertions, %d failures; qualified=0" % [_observed, _suite.assertions, _suite.failures.size()])
	quit(0 if _suite.failures.is_empty() else 2)
