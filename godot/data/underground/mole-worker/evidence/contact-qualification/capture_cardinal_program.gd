extends "./capture_install_program.gd"
## Actual protocol4/native heading witnesses; fixture admission never publishes a qualified catalog or workpiece.

const WORK_YAWS: PackedInt32Array = [0, 16384, 32768, 49152]
var _heading_index: int = 0
var _native_contacts: Array[Dictionary] = []
var _identity_values: PackedInt32Array = PackedInt32Array()


func _install_fixture_profiles() -> void:
	"""Every fixed source row uses actual owner keys and exact compiler boxes, with declared test-only admission."""
	var rows: Array[Dictionary] = []
	var boxes: Array[PackedInt32Array] = []
	_identity_values = _actual._identity.duplicate()
	for index: int in 18:
		rows.append(_cardinal_fixture_row(index, boxes))
	var wire: PackedByteArray = _actual._image(rows, boxes, 1)
	var digest: PackedByteArray = _content.source_digest().hex_decode()
	for byte: int in 32:
		wire[32 + byte] = digest[byte]
	_suite.assert_equal(_actual._load(wire, 1), &"", "actual cardinal reader; synthetic flags only")


func _cardinal_fixture_row(index: int, boxes: Array[PackedInt32Array]) -> Dictionary:
	"""Assemble one immutable source role and append every compiler-authored box exactly once."""
	var row: Dictionary = _actual._row(index if index < 2 else Profiles.MODE_WORK)
	row.fields[Profiles.F_TOOL] = _actual._items.compiled_id(&"tool")
	row.fields[Profiles.F_TOOL_VARIANT] = _actual.Gear.MANUFACTURE_BASIC
	row.fields[Profiles.F_FAMILIES] = 0
	row.fields[Profiles.F_STATES] = Profiles.STATE_IDLE | Profiles.STATE_RECOVERY
	if index == 1:
		row.fields[Profiles.F_STATES] |= Profiles.STATE_WALK | Profiles.STATE_ENTRY | Profiles.STATE_REVERSAL
	if index >= 2:
		row.fields[Profiles.F_STATES] |= Profiles.STATE_WORK | Profiles.STATE_ENTRY
		row.fields[Profiles.F_YAW_KIND] = Profiles.YAW_EXACT
		@warning_ignore("integer_division") var heading: int = (index - 2) / 4
		row.fields[Profiles.F_YAW] = WORK_YAWS[heading]
		row.fields[Profiles.F_WORK_KIND] = _actual.Jobs.JOB_KIND_BUILD
		row.fields[Profiles.F_CONTACT_KIND] = Profiles.CONTACT_ANCHOR_AND_PATCH
	row.fields[Profiles.F_FIRST_BOX] = boxes.size()
	var role_data: Dictionary = _spec.cardinal_profiles[str(index)] as Dictionary
	for role: int in ROLE_NAMES.size():
		for bounds: Array in role_data.get(ROLE_NAMES[role], []):
			var packed: PackedInt32Array = PackedInt32Array(bounds)
			packed.append(role)
			boxes.append(packed)
	row.fields[Profiles.F_BOX_COUNT] = boxes.size() - row.fields[Profiles.F_FIRST_BOX]
	return row


func _observe_compact_views() -> void:
	"""Each heading starts at the shared ready hub and completes recovery before the actual pose may change."""
	var root_point: Vector3 = Vector3(ORIGIN_U) / 1024.0
	var views: Array[Vector3] = [Vector3(1.7, 0.9, -0.5), Vector3(3.9, 5.0, 4.0)]
	var labels: PackedStringArray = ["side", "rts"]
	var pins: PackedInt64Array = PackedInt64Array()
	for index: int in 18:
		pins.append_array(PackedInt64Array([index, 1, 1]))
	for heading: int in WORK_YAWS.size():
		_heading_index = heading
		_suite.assert_true(_actual._transforms.place(_actual._worker, ORIGIN_U.x, ORIGIN_U.y, ORIGIN_U.z,
			WORK_YAWS[heading]), "actual authored heading")
		for view: int in views.size():
			_camera.position = root_point + views[view]
			_camera.size = 10.0 if view == 1 else 2.5
			_camera.look_at(root_point + Vector3(0.05, 0.65, -0.05), Vector3.UP)
			_driver = Driver.new()
			_suite.assert_equal(_driver.configure(_content, _actual._profiles, _actual._residents, _actual._worker,
				_tool, pins, _content.source_digest(), Driver.PROGRAM_CARDINAL), &"", "exact protocol4 source map")
			await _sequence("%s-yaw%d" % [labels[view], WORK_YAWS[heading]])
			_suite.assert_true(_frame.ready, "complete original-heading recovery before changing heading")
			_driver.retire()
			_driver = null


func _step(profile: int, ready: bool, label: String, tick: int) -> bool:
	"""Logical source roles map to explicit catalog rows; actual Gear/Job/pose checks remain in the driver."""
	var chosen: int = profile if profile < 2 else 2 + 4 * _heading_index + profile - 2
	var code: StringName = _driver.step_profile_into(chosen, _job, 32768, ready, _frame)
	_suite.assert_equal(code, &"", "actual cardinal driver step")
	if code != &"":
		return false
	_suite.assert_equal(_frame.yaw, WORK_YAWS[_heading_index], "observed exact heading")
	_suite.assert_equal(_frame.profile_id, chosen, "observed exact immutable profile")
	_suite.assert_equal(_actor.set_world_root(Vector2i(5, 9), _frame.point, _frame.yaw), &"", "native finite World root")
	_suite.assert_equal(_actor.apply_pose(_frame.frames), &"", "native same-source palette")
	_suite.assert_equal(_frame.source_digest, _content.source_digest(), "same immutable source")
	_phase_counts[_frame.phase] += 1
	_events.append({"label": label, "tick": tick, "phase": _frame.phase, "ready": _frame.ready,
		"profile": _frame.profile_id, "source_role": profile, "yaw": _frame.yaw, "frames": Array(_frame.frames)})
	_observed += 1
	await process_frame
	if tick % 48 == 0 or _frame.ready:
		_save_frame("%s-%03d" % [label, tick], chosen, tick)
	return true


func _save_frame(label: String, clip: int, tick: int) -> void:
	"""Render on the actual main-thread backend before readback; no asynchronous window draw is assumed."""
	RenderingServer.force_draw(false, 0.0)
	var image: Image = root.get_texture().get_image()
	var path: String = _out + "/" + label + ".png"
	_suite.assert_false(FileAccess.file_exists(path), "create-only native frame")
	_suite.assert_equal(image.save_png(path), OK, "actual forced rendered witness")
	_shots.append({"path": label + ".png", "clip": clip, "half_tick": tick, "sha256": FileAccess.get_sha256(path)})
	print("cardinal-frame: ", _observed, " ", label)


func _observe_transitions() -> void:
	"""Exact native stone-head points supplement the mathematical all-primitive enclosure at each heading."""
	super._observe_transitions()
	var now: PackedInt32Array = PackedInt32Array([0, 0, 0])
	var pose: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0, 65536])
	for profile: int in range(2, 18):
		var contact: Dictionary = _spec.cardinal_contacts[str(profile)] as Dictionary
		var values: Array = _spec.source_points[str(int(contact.vertex))] as Array
		var point: Vector3 = Vector3(float(values[0]), float(values[1]), float(values[2]))
		var clip: int = 2 + 3 * ((profile - 2) % 4)
		_suite.assert_equal(_actor.set_world_root(Vector2i(5, 9), ORIGIN_U, int(contact.yaw)), &"", "exact witness heading")
		for step: int in 9:
			_suite.assert_equal(_content.clip_into(clip, int(contact.frame_pair[0]) * 65536 + step * 8192, now), &"", "exact contact source time")
			for index: int in 3:
				pose[index] = now[index]
				pose[index + 3] = now[index]
			_suite.assert_equal(_actor.apply_pose(pose), &"", "native actual held-tool pose")
			var moved: Vector3 = (_actor.native_matrix(1, 0) * point - Vector3(ORIGIN_U) / 1024.0) * 1024.0
			_native_contacts.append({"profile": profile, "yaw": int(contact.yaw), "vertex": int(contact.vertex),
				"share_q16": step * 8192, "point_u": [moved.x, moved.y, moved.z], "frames": Array(now)})
			_observed += 1
			await process_frame


func _finish() -> void:
	"""Native source binding and sampled contact witnesses do not create World support, WIP or labor."""
	var report: Dictionary = {"schema": 1, "content_sha256": _content.source_digest(), "poses": _observed,
		"assertions": _suite.assertions, "failures": _suite.failures, "screenshots": _shots,
		"phase_counts": Array(_phase_counts), "events": _events, "native_contacts": _native_contacts,
		"production_qualified": false, "program_version": 4, "actual_species_stage_rig": Array(_identity_values),
		"user_directory": OS.get_user_data_dir(), "world_identity": "actual Resident/Job/Work/Gear and renderer; fixture profile flags, no World/WIP/handling permission"}
	var output: FileAccess = FileAccess.open(_out + "/report.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t") + "\n")
	output.close()
	for failure: String in _suite.failures:
		printerr("FAIL: ", failure)
	print("mole-cardinal-program: %d poses, %d assertions, %d failures; qualified=0" % [_observed, _suite.assertions, _suite.failures.size()])
	quit(0 if _suite.failures.is_empty() else 2)
