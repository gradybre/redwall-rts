extends "./capture_compact_program.gd"
## Actual v3 source replay; synthetic profile flags confer no paid workpiece, handling or terrain permission.

const INSTALL_PROFILES: PackedStringArray = ["stand", "ground_walk", "down", "high", "front", "install"]


func _build_stage() -> void:
	"""Keep native proof isolated from the integrated suite's user data and from gameplay state."""
	super._build_stage()
	_suite.assert_true(OS.get_user_data_dir().ends_with("/" + str(_spec.user_directory_name)), "isolated actual user directory")


func _observe_compact_views() -> void:
	"""Bind all six exact source roles in each view; prior protocols and their evidence remain unchanged."""
	var root_point: Vector3 = Vector3(ORIGIN_U) / 1024.0
	var views: Array[Vector3] = [Vector3(1.7, 0.9, -0.5), Vector3(-1.5, 1.1, 0.5), Vector3(3.9, 5.0, 4.0)]
	var labels: PackedStringArray = ["side", "opposite", "rts"]
	for view: int in views.size():
		_camera.position = root_point + views[view]
		_camera.size = 10.0 if view == 2 else 2.5
		_camera.look_at(root_point + Vector3(0.05, 0.65, -0.05), Vector3.UP)
		_driver = Driver.new()
		_suite.assert_equal(_driver.configure(_content, _actual._profiles, _actual._residents, _actual._worker,
			_tool, PackedInt64Array([0, 1, 1, 1, 1, 1, 2, 1, 1, 3, 1, 1, 4, 1, 1, 5, 1, 1]), _content.source_digest(),
			Driver.PROGRAM_INSTALL), &"", "explicit v3 source binding")
		await _sequence(labels[view])
		_driver.retire()
		_driver = null


func _install_fixture_profiles() -> void:
	"""The actual immutable reader consumes exact compiler boxes with explicitly synthetic test admission."""
	var rows: Array[Dictionary] = []
	var boxes: Array[PackedInt32Array] = []
	for index: int in INSTALL_PROFILES.size():
		var row: Dictionary = _actual._row(index if index < 2 else Profiles.MODE_WORK)
		row.fields[Profiles.F_TOOL] = _actual._items.compiled_id(&"tool")
		row.fields[Profiles.F_TOOL_VARIANT] = _actual.Gear.MANUFACTURE_BASIC
		row.fields[Profiles.F_FIRST_BOX] = boxes.size()
		if index >= 2:
			row.fields[Profiles.F_YAW_KIND] = Profiles.YAW_EXACT
			row.fields[Profiles.F_WORK_KIND] = _actual.Jobs.JOB_KIND_BUILD
			row.fields[Profiles.F_CONTACT_KIND] = Profiles.CONTACT_ANCHOR_AND_PATCH
		for role: int in ROLE_NAMES.size():
			for bounds: Array in _spec.roles[INSTALL_PROFILES[index]].get(ROLE_NAMES[role], []):
				var packed: PackedInt32Array = PackedInt32Array(bounds)
				packed.append(role)
				boxes.append(packed)
		row.fields[Profiles.F_BOX_COUNT] = boxes.size() - row.fields[Profiles.F_FIRST_BOX]
		rows.append(row)
	var wire: PackedByteArray = _actual._image(rows, boxes, 1)
	var digest: PackedByteArray = _content.source_digest().hex_decode()
	for byte: int in 32:
		wire[32 + byte] = digest[byte]
	_suite.assert_equal(_actual._load(wire, 1), &"", "actual reader; no production profile qualification")


func _sequence(label: String) -> void:
	"""Add interrupted installation entry and a full productive/recovery cycle to the original compact program."""
	await super._sequence(label)
	await _span(5, 17, false, label + "-install-partial")
	await _settle(5, label + "-install-retrace")
	await _span(5, 83, false, label + "-install-work")
	await _settle(5, label + "-install-recovery")


func _finish() -> void:
	"""Native program evidence cannot publish or carry the billed bearer or award a single unit of labor."""
	var report: Dictionary = {"schema": 1, "content_sha256": _content.source_digest(), "poses": _observed,
		"assertions": _suite.assertions, "failures": _suite.failures, "screenshots": _shots,
		"phase_counts": Array(_phase_counts), "events": _events, "production_qualified": false,
		"user_directory": OS.get_user_data_dir(), "program_version": 3,
		"world_identity": "actual Resident/Job/Work/Gear and source; synthetic profile flags, no paid WIP/handling/support permission"}
	var output: FileAccess = FileAccess.open(_out + "/report.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t") + "\n")
	output.close()
	for failure: String in _suite.failures:
		printerr("FAIL: ", failure)
	print("mole-install-program: %d poses, %d assertions, %d failures; qualified=0" % [_observed, _suite.assertions, _suite.failures.size()])
	quit(0 if _suite.failures.is_empty() else 2)
