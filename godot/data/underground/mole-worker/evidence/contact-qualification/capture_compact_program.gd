extends "./capture_state_program.gd"
## Version2 source witness only. Actual identity owners use explicitly synthetic physical-profile admission flags.

const COMPACT_PROFILES: PackedStringArray = ["stand", "ground_walk", "down", "high", "front"]


func _observe_clips() -> void:
	"""Bind the explicit eleven-clip driver to the actual native matrices and exact five source roles."""
	_actual = Fixture.new()
	_actual.before_each()
	_actual._slot = _actual._residents.spawn(&"mole").value
	_actual._worker = _actual._residents.ref_of(_actual._slot)
	_suite.assert_true(_actual._residents.spatial_profile_identity_into(_actual._worker, _actual._identity), "real adult mole")
	_suite.assert_true(_actual._transforms.place(_actual._worker, ORIGIN_U.x, ORIGIN_U.y, ORIGIN_U.z, 0), "actual witness root")
	_tool = _actual._equip()
	_job = _actual._actual_work_job().ref
	_suite.assert_true(_actual._work.claim_tool_for_work(_actual._slot, _tool).ok, "actual retained tool")
	_install_fixture_profiles()
	_suite.assert_true(_actual.failures.is_empty(), "actual fixture setup: " + str(_actual.failures))
	await _observe_compact_views()
	_suite.assert_equal(_actual._work.tool_job_of(_actual._slot), _job, "no work credit or claim release")
	_suite.assert_equal(_actual._gear.owner_of(_tool), _actual._worker, "actual tool remains held")
	_actual.after_each()
	_suite.assert_true(_actual.failures.is_empty(), "actual fixture teardown: " + str(_actual.failures))
	_actual = null


func _observe_compact_views() -> void:
	"""Three isolated native views exercise every state; they do not claim terrain or final camera qualification."""
	var root_point: Vector3 = Vector3(ORIGIN_U) / 1024.0
	var views: Array[Vector3] = [Vector3(1.7, 0.9, -0.5), Vector3(-1.5, 1.1, 0.5), Vector3(3.9, 5.0, 4.0)]
	var labels: PackedStringArray = ["side", "opposite", "rts"]
	for view: int in views.size():
		_camera.position = root_point + views[view]
		_camera.size = 10.0 if view == 2 else 2.5
		_camera.look_at(root_point + Vector3(0.05, 0.65, -0.05), Vector3.UP)
		_driver = Driver.new()
		_suite.assert_equal(_driver.configure(_content, _actual._profiles, _actual._residents, _actual._worker,
			_tool, PackedInt64Array([0, 1, 1, 1, 1, 1, 2, 1, 1, 3, 1, 1, 4, 1, 1]), _content.source_digest(),
			Driver.PROGRAM_COMPACT), &"", "explicit v2 source binding")
		await _sequence(labels[view])
		_driver.retire()
		_driver = null


func _install_fixture_profiles() -> void:
	"""Real source-derived role boxes enter the actual immutable reader with clearly synthetic test flags."""
	var rows: Array[Dictionary] = []
	var boxes: Array[PackedInt32Array] = []
	for index: int in COMPACT_PROFILES.size():
		var row: Dictionary = _actual._row(index if index < 2 else Profiles.MODE_WORK)
		row.fields[Profiles.F_TOOL] = _actual._items.compiled_id(&"tool")
		row.fields[Profiles.F_TOOL_VARIANT] = _actual.Gear.MANUFACTURE_BASIC
		row.fields[Profiles.F_FIRST_BOX] = boxes.size()
		if index >= 2:
			row.fields[Profiles.F_YAW_KIND] = Profiles.YAW_EXACT
			row.fields[Profiles.F_WORK_KIND] = _actual.Jobs.JOB_KIND_BUILD
			row.fields[Profiles.F_CONTACT_KIND] = Profiles.CONTACT_ANCHOR_AND_PATCH
		for role: int in ROLE_NAMES.size():
			for bounds: Array in _spec.roles[COMPACT_PROFILES[index]].get(ROLE_NAMES[role], []):
				var packed: PackedInt32Array = PackedInt32Array(bounds)
				packed.append(role)
				boxes.append(packed)
		row.fields[Profiles.F_BOX_COUNT] = boxes.size() - row.fields[Profiles.F_FIRST_BOX]
		rows.append(row)
	var wire: PackedByteArray = _actual._image(rows, boxes, 1)
	var digest: PackedByteArray = _content.source_digest().hex_decode()
	for byte: int in 32:
		wire[32 + byte] = digest[byte]
	_suite.assert_equal(_actual._load(wire, 1), &"", "actual reader; no production qualification")


func _sequence(label: String) -> void:
	"""Original down/high sequence plus an interrupted and productive front cycle, all through one ready hub."""
	await super._sequence(label)
	await _span(4, 17, false, label + "-front-partial")
	await _settle(4, label + "-front-retrace")
	await _span(4, 101, false, label + "-front-work")
	await _settle(4, label + "-front-recovery")
