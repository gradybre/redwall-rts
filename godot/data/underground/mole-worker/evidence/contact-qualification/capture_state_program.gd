extends "../grip-authoring/native_grip_sequence.gd"
## Actual source/Actor/driver with real Job/Gear identities and explicitly synthetic profile-admission flags.

const Driver := preload("res://data/underground/mole-worker/mole_profile_driver.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Fixture := preload("res://test/test_underground_profiles.gd")
const ROLE_NAMES: PackedStringArray = ["BODY_HELD_LOAD", "STANCE_SUPPORT", "TURN_RECOVERY", "WORK_APPROACH",
	"WORK_STROKE", "CONTACT_POINT", "CONTACT_PATCH"]
const PROFILE_NAMES: PackedStringArray = ["stand", "ground_walk", "down", "high"]

var _actual: Fixture = null
var _driver: Driver = null
var _frame: Driver.Frame = Driver.Frame.new()
var _job: Vector2i = Vector2i(-1, 0)
var _tool: Vector2i = Vector2i(-1, 0)
var _events: Array[Dictionary] = []
var _phase_counts: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0, 0, 0])


func _build_stage() -> void:
	"""An isolated native quality witness has no terrain, paid support or gameplay collision authority."""
	super._build_stage()
	root.size = Vector2i(1280, 720)


func _observe_clips() -> void:
	"""Use the real integer driver and immutable eight-clip image, never a substituted animation clock."""
	_actual = Fixture.new()
	_actual.before_each()
	_actual._slot = _actual._residents.spawn(&"mole").value
	_actual._worker = _actual._residents.ref_of(_actual._slot)
	_suite.assert_true(_actual._residents.spatial_profile_identity_into(_actual._worker, _actual._identity), "real adult mole")
	_suite.assert_true(_actual._transforms.place(_actual._worker, ORIGIN_U.x, ORIGIN_U.y, ORIGIN_U.z, 0), "actual native witness root")
	_tool = _actual._equip()
	_job = _actual._actual_work_job().ref
	_suite.assert_true(_actual._work.claim_tool_for_work(_actual._slot, _tool).ok, "real retained Work tool claim")
	_install_fixture_profiles()
	_suite.assert_true(_actual.failures.is_empty(), "actual fixture setup assertions: " + str(_actual.failures))
	var root_point: Vector3 = Vector3(ORIGIN_U) / 1024.0
	var views: Array[Vector3] = [Vector3(1.7, 0.9, -0.5), Vector3(-1.5, 1.1, 0.5), Vector3(3.9, 5.0, 4.0)]
	var labels: PackedStringArray = ["side", "opposite", "rts"]
	for view: int in views.size():
		_camera.position = root_point + views[view]
		_camera.size = 10.0 if view == 2 else 2.5
		_camera.look_at(root_point + Vector3(0.05, 0.65, -0.05), Vector3.UP)
		_driver = Driver.new()
		_suite.assert_equal(_driver.configure(_content, _actual._profiles, _actual._residents, _actual._worker,
			_tool, PackedInt64Array([0, 1, 1, 1, 1, 1, 2, 1, 1, 3, 1, 1]), _content.source_digest()), &"", "actual source program binding")
		await _sequence(labels[view])
		_driver.retire()
		_driver = null
	_suite.assert_equal(_actual._work.tool_job_of(_actual._slot), _job, "driver never consumed or released actual work")
	_suite.assert_equal(_actual._gear.owner_of(_tool), _actual._worker, "actual tool remains visible and owned")
	_actual.after_each()
	_suite.assert_true(_actual.failures.is_empty(), "actual fixture teardown assertions: " + str(_actual.failures))
	_actual = null


func _install_fixture_profiles() -> void:
	"""Use real compiler role boxes but test-only admission flags: this cannot manufacture a production certificate."""
	var rows: Array[Dictionary] = []
	var boxes: Array[PackedInt32Array] = []
	for index: int in 4:
		var row: Dictionary = _actual._row(index if index < 2 else Profiles.MODE_WORK)
		row.fields[Profiles.F_TOOL] = _actual._items.compiled_id(&"tool")
		row.fields[Profiles.F_TOOL_VARIANT] = _actual.Gear.MANUFACTURE_BASIC
		row.fields[Profiles.F_FIRST_BOX] = boxes.size()
		if index >= 2:
			row.fields[Profiles.F_YAW_KIND] = Profiles.YAW_EXACT
			row.fields[Profiles.F_WORK_KIND] = _actual.Jobs.JOB_KIND_BUILD
			row.fields[Profiles.F_CONTACT_KIND] = Profiles.CONTACT_ANCHOR_AND_PATCH
		for role: int in ROLE_NAMES.size():
			for bounds: Array in _spec.roles[PROFILE_NAMES[index]].get(ROLE_NAMES[role], []):
				var packed: PackedInt32Array = PackedInt32Array(bounds)
				packed.append(role)
				boxes.append(packed)
		row.fields[Profiles.F_BOX_COUNT] = boxes.size() - row.fields[Profiles.F_FIRST_BOX]
		rows.append(row)
	var wire: PackedByteArray = _actual._image(rows, boxes, 1)
	var digest: PackedByteArray = _content.source_digest().hex_decode()
	for byte: int in 32:
		wire[32 + byte] = digest[byte]
	_suite.assert_equal(_actual._load(wire, 1), &"", "actual Profile reader, explicitly synthetic admission flags")


func _sequence(label: String) -> void:
	"""Exercise queued travel fades, partial-entry reversal and productive recovery with the same actual Job/tool."""
	await _span(0, 31, false, label + "-idle")
	await _settle(0, label + "-idle-ready")
	await _span(1, 45, false, label + "-walk")
	await _settle(1, label + "-walk-ready")
	await _span(2, 21, false, label + "-down-partial")
	await _settle(2, label + "-down-retrace")
	await _span(2, 91, false, label + "-down-work")
	await _settle(2, label + "-down-recovery")
	await _span(3, 83, false, label + "-high-work")
	await _settle(3, label + "-high-recovery")


func _span(profile: int, count: int, ready: bool, label: String) -> void:
	"""Every observed pose is emitted by the actual driver with a half-tick integer source delta."""
	for tick: int in count:
		if not await _step(profile, ready, label, tick):
			return


func _settle(profile: int, label: String) -> void:
	"""A bounded request waits for exact driver readiness; it never treats a float animation signal as work credit."""
	for tick: int in 256:
		if not await _step(profile, true, label, tick):
			return
		if _frame.ready:
			return
	_suite.assert_true(false, "source did not reach ready within finite program budget")


func _step(profile: int, ready: bool, label: String, tick: int) -> bool:
	"""Preserve actual identity into the same renderer and record every phase transition."""
	var code: StringName = _driver.step_into(profile, _job, 32768, ready, _frame)
	_suite.assert_equal(code, &"", "actual source driver step")
	if code != &"":
		return false
	_suite.assert_equal(_actor.set_world_root(Vector2i(5, 9), _frame.point, _frame.yaw), &"", "actual observed root")
	_suite.assert_equal(_actor.apply_pose(_frame.frames), &"", "actual emitted native matrices")
	_suite.assert_equal(_frame.source_digest, _content.source_digest(), "same immutable renderer source")
	_phase_counts[_frame.phase] += 1
	_events.append({"label": label, "tick": tick, "phase": _frame.phase, "ready": _frame.ready,
		"profile": _frame.profile_id, "frames": Array(_frame.frames)})
	_observed += 1
	await process_frame
	if tick % 24 == 0 or _frame.ready:
		await _save_frame("%s-%03d" % [label, tick], profile, tick)
	return true


func _observe_transitions() -> void:
	"""Every driver phase was exercised through actual source matrices; no independent ad-hoc fade is added."""
	for phase: int in Driver.RETIRED:
		_suite.assert_true(_phase_counts[phase] > 0, "actual driver phase observed: %d" % phase)


func _finish() -> void:
	"""Native and protocol observations remain separate from actual terrain/profile admission."""
	var report: Dictionary = {"schema": 1, "content_sha256": _content.source_digest(), "poses": _observed,
		"assertions": _suite.assertions, "failures": _suite.failures, "screenshots": _shots,
		"phase_counts": Array(_phase_counts), "events": _events, "production_qualified": false,
		"world_identity": "actual identity/equipment owners; synthetic profile flags and witness World, no movement, work or support permission"}
	var output: FileAccess = FileAccess.open(_out + "/report.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t") + "\n")
	output.close()
	for failure: String in _suite.failures:
		printerr("FAIL: ", failure)
	print("mole-state-driver: %d poses, %d assertions, %d failures; qualified=0" % [_observed, _suite.assertions, _suite.failures.size()])
	quit(0 if _suite.failures.is_empty() else 2)
