extends "res://test/framework/test_case.gd"
## Actual Profile/Job/Work/Gear owners with explicitly synthetic mesh, timing and geometry certificates.
## These tests qualify the driver protocol, never the mole asset, a work face or a paid frontier.

const Driver := preload("res://data/underground/mole-worker/mole_profile_driver.gd")
const Content := preload("res://demo/cast/underground_actor_content.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const ProfileFixture := preload("res://test/test_underground_profiles.gd")
const MeshFixture := preload("res://test/test_underground_actor_content.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const COUNTS: Array[int] = [11, 3, 4, 5, 5, 4, 5, 5]
var _fixture: ProfileFixture = null
var _source: Content = null
var _driver: Driver = null
var _job: Vector2i = NULL_REF
var _tool: Vector2i = NULL_REF
var _pins: PackedInt64Array = PackedInt64Array([0, 1, 1, 1, 1, 1, 2, 1, 1, 3, 1, 1])


func before_each() -> void:
	"""Reuse only existing real-owner fixture construction; its assertions are inspected explicitly."""
	_fixture = ProfileFixture.new()
	_fixture.before_each()
	_fixture._slot = _fixture._residents.spawn(&"mole").value
	_fixture._worker = _fixture._residents.ref_of(_fixture._slot)
	assert_true(_fixture._residents.spatial_profile_identity_into(_fixture._worker, _fixture._identity), "actual adult mole")
	assert_true(_fixture._transforms.place(_fixture._worker, 1024, 0, 2048, 0), "actual source root")
	_tool = _fixture._equip()
	_job = _fixture._actual_work_job().ref
	assert_true(_fixture._work.claim_tool_for_work(_fixture._slot, _tool).ok, "actual tool claim")
	_source = _content()
	_install_profiles()
	assert_true(_fixture.failures.is_empty(), "real fixture assertions: " + str(_fixture.failures))
	_driver = Driver.new()
	assert_equal(_bind(_driver, _pins), &"", "exact source and actual profile binding")


func after_each() -> void:
	"""Retire only this test's presentation; never let the driver release an authoritative equipment claim."""
	if _driver != null:
		_driver.retire()
	_driver = null
	_source = null
	if _fixture != null:
		assert_true(_fixture.failures.is_empty(), "fixture failure propagation")
		_fixture.after_each()
	_fixture = null


func _content() -> Content:
	"""Eight finite clips use one actual ArrayMesh; source flags remain a labelled synthetic fixture."""
	var helper: MeshFixture = MeshFixture.new()
	var mesh: ArrayMesh = helper._mesh()
	var path: String = "user://mole-driver-%d.bin" % get_instance_id()
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer("UGACNT01".to_ascii_buffer())
	for value: int in [1, 1, 1, 8, 42, 12]:
		file.store_32(value)
	for value: int in [0, -32, 0, 4096, 4096, 4096]:
		file.store_32(value)
	for which: int in 4:
		file.store_buffer(MeshFixture.HASH.hex_decode())
	helper._write_part(file, mesh, 0)
	_write_clips(file)
	for frame: int in 42:
		for value: float in PackedFloat32Array([1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0]):
			file.store_float(value)
	for frame: int in 42:
		file.store_float(0.0)
	file.store_buffer("UGAEND01".to_ascii_buffer())
	file.close()
	var result: Content = Content.new()
	assert_equal(result.load_file(path, FileAccess.get_sha256(path), 3 * 1024 * 1024), &"", "real immutable source loader")
	assert_equal(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)), OK, "owned fixture removed")
	return result


func _write_clips(file: FileAccess) -> void:
	"""Finite profile protocol order with actual loop rules and exact matching source endpoints."""
	var first: int = 0
	for clip: int in 8:
		var loop: int = int(clip == 0 or clip == 1 or clip == 2 or clip == 5)
		for value: int in [first, COUNTS[clip], loop, (COUNTS[clip] - 1) * Driver.ONE]:
			file.store_32(value)
		file.store_buffer(MeshFixture.HASH.hex_decode())
		first += COUNTS[clip]


func _install_profiles(revision: int = 1) -> void:
	"""Actual compiled mole/tool keys plus test-only geometry and certificate bits."""
	var rows: Array[Dictionary] = []
	var boxes: Array[PackedInt32Array] = []
	for index: int in 4:
		var row: Dictionary = _fixture._row(index if index < 2 else Profiles.MODE_WORK)
		row.fields[Profiles.F_TOOL] = _fixture._items.compiled_id(&"tool")
		row.fields[Profiles.F_TOOL_VARIANT] = _fixture.Gear.MANUFACTURE_BASIC
		row.fields[Profiles.F_FIRST_BOX] = boxes.size()
		row.fields[Profiles.F_BOX_COUNT] = 3 if index < 2 else 7
		boxes.append_array(_fixture._boxes())
		if index >= 2:
			row.fields[Profiles.F_YAW_KIND] = Profiles.YAW_EXACT
			row.fields[Profiles.F_WORK_KIND] = _fixture.Jobs.JOB_KIND_BUILD
			row.fields[Profiles.F_CONTACT_KIND] = Profiles.CONTACT_ANCHOR_AND_PATCH
			_add_work_boxes(boxes, index)
		rows.append(row)
	var wire: PackedByteArray = _fixture._image(rows, boxes, revision)
	var digest: PackedByteArray = _source.source_digest().hex_decode()
	for byte: int in 32:
		wire[32 + byte] = digest[byte]
	assert_equal(_fixture._load(wire, revision), &"", "complete synthetic rows through actual immutable reader")


func _add_work_boxes(boxes: Array[PackedInt32Array], index: int) -> void:
	"""Two visibly different face axes exist for one actual worker and one tool manufacture."""
	boxes.append(PackedInt32Array([-128, -20, -128, 128, 1000, 256, Profiles.WORK_APPROACH]))
	boxes.append(PackedInt32Array([-128, 0, -256, 128, 1000, 128, Profiles.WORK_STROKE]))
	boxes.append(PackedInt32Array([0, 512, -200, 0, 512, -200, Profiles.CONTACT_POINT]))
	boxes.append(PackedInt32Array([-2, 512, -202, 2, 512, -198, Profiles.CONTACT_PATCH]) if index == 2 else
		PackedInt32Array([-2, 510, -200, 2, 514, -200, Profiles.CONTACT_PATCH]))


func _bind(driver: Driver, pins: PackedInt64Array) -> StringName:
	"""No fake mutable authority callback is inserted between this driver and actual owners."""
	return driver.configure(_source, _fixture._profiles, _fixture._residents, _fixture._worker,
		_tool, pins, _source.source_digest())


func test_pause_and_refusal_preserve_exact_visible_frame_and_integer_phase() -> void:
	"""No source interpolation advances with zero time, invalid input or an uncompleted contact handoff."""
	var out: Driver.Frame = Driver.Frame.new()
	assert_equal(_driver.step_into(2, _job, 0, false, out), &"", "initial ready observation")
	assert_true(out.ready, "zero time stays ready")
	var initial: PackedInt32Array = out.frames.duplicate()
	assert_equal(_driver.step_into(2, _job, Driver.ONE, false, out), &"", "actual entry")
	assert_equal(out.phase, Driver.ENTRY, "entry phase")
	var before: PackedInt32Array = out.frames.duplicate()
	var state: PackedInt64Array = _driver._live.duplicate()
	assert_equal(_driver.step_into(2, _job, 0, true, out), &"", "paused cancellation request")
	assert_equal(out.frames, before, "paused pose frozen")
	assert_equal(_driver._live, state, "paused phase frozen")
	assert_equal(_driver.step_into(1, _job, Driver.ONE, false, out), &"MOLE_DRIVER_HANDOFF_REQUIRED", "no buried-pick travel snap")
	assert_equal(_driver.step_into(2, _job, Driver.MAX_DELTA + 1, false, out), &"MOLE_DRIVER_INPUT", "bounded update")
	assert_equal(out.frames, before, "refused pose untouched")
	assert_equal(_driver._live, state, "refused clock untouched")
	assert_equal(_driver.step_into(2, _job, Driver.ONE, true, out), &"", "retrace partial entry")
	assert_true(out.ready, "exact initial source reached")
	assert_equal(out.frames, initial, "exact hub pose restored")


func test_productive_interruption_completes_retrace_before_contact_or_job_handoff() -> void:
	"""The actual same work/tool observation survives the full visible productive recovery."""
	var out: Driver.Frame = Driver.Frame.new()
	assert_equal(_driver.step_into(2, _job, 4 * Driver.ONE, false, out), &"", "entry endpoint")
	assert_equal(out.phase, Driver.WORK, "actual work source")
	assert_equal(_driver.step_into(2, _job, Driver.ONE, false, out), &"", "productive interval")
	assert_equal(_driver.step_into(3, _job, Driver.ONE, false, out), &"MOLE_DRIVER_HANDOFF_REQUIRED", "other exact contact cannot replace buried source")
	assert_equal(_driver.step_into(2, _job, 2 * Driver.ONE, true, out), &"", "finish current productive retrace")
	assert_equal(out.phase, Driver.RECOVERY, "same contact recovery")
	assert_false(out.ready, "recovery is not work credit or travel clearance")
	assert_equal(_driver.step_into(2, _job, 4 * Driver.ONE, true, out), &"", "full clear recovery")
	assert_true(out.ready, "source handoff point")
	assert_equal(_driver.step_into(3, _job, 4 * Driver.ONE, false, out), &"", "now other actual contact")
	assert_equal(out.profile_id, 3, "exact selected upper contact")
	assert_equal(out.phase, Driver.WORK, "upper source entered")


func test_actual_tool_assignment_content_and_pose_drift_never_become_a_successful_recovery() -> void:
	"""Source readiness cannot recreate a released claim, stale Job or externally moved productive worker."""
	var out: Driver.Frame = Driver.Frame.new()
	assert_equal(_driver.step_into(2, _job, 4 * Driver.ONE, false, out), &"", "productive binding")
	var before: PackedInt32Array = out.frames.duplicate()
	var state: PackedInt64Array = _driver._live.duplicate()
	assert_true(_fixture._work.release_tool_claim(_fixture._slot).ok, "actual claim released")
	assert_equal(_driver.step_into(2, _job, Driver.ONE, true, out), &"PROFILE_TOOL_CLAIM", "cannot invent retained claim")
	assert_equal(out.frames, before, "refused frame unchanged")
	assert_equal(_driver._live, state, "refused phase unchanged")
	assert_true(_fixture._work.claim_tool_for_work(_fixture._slot, _tool).ok, "actual claim restored")
	assert_true(_fixture._transforms.advance(_fixture._worker, 1025, 0, 2048), "external actual pose write")
	assert_equal(_driver.step_into(2, _job, Driver.ONE, true, out), &"MOLE_DRIVER_WORK_POSE_DRIFT", "productive root must stay pinned")
	assert_true(_fixture._transforms.advance(_fixture._worker, 1024, 0, 2048), "restore actual pose")
	_install_profiles(2)
	assert_equal(_driver.step_into(2, _job, Driver.ONE, true, out), &"PROFILE_SELECTION_STALE", "content replacement cannot carry old permission")


func test_ground_walk_uses_complete_fade_and_safe_hub_before_switching_to_work() -> void:
	"""Travel presentation follows actual root changes while positive fixed fades preserve the finite program."""
	var out: Driver.Frame = Driver.Frame.new()
	assert_equal(_driver.step_into(1, _job, 4 * Driver.ONE, false, out), &"", "walking fade")
	assert_equal(out.phase, Driver.FADE_WALK, "not an instantaneous handoff")
	assert_true(out.frames[6] > 0 and out.frames[6] < Driver.ONE, "positive intermediate blend")
	assert_equal(_driver.step_into(1, _job, 4 * Driver.ONE, false, out), &"", "finish walking fade")
	assert_equal(out.phase, Driver.WALK, "finite walk source")
	assert_true(_fixture._transforms.advance(_fixture._worker, 1024, 0, 2040), "actual route pose")
	assert_equal(_driver.step_into(1, _job, 4 * Driver.ONE, true, out), &"", "settle moving source")
	assert_equal(out.point, Vector3i(1024, 0, 2040), "actual position, never driver movement")
	assert_equal(_driver.step_into(2, _job, 0, false, out), &"MOLE_DRIVER_HANDOFF_REQUIRED", "profile still retained during fade")
	assert_equal(_driver.step_into(1, _job, 4 * Driver.ONE, true, out), &"", "clear travel hub")
	assert_true(out.ready, "host can now perform actual profile admission")
	assert_equal(_driver.step_into(2, _job, Driver.ONE, false, out), &"", "actual work source selection")


func test_cold_pins_are_copied_and_retirement_releases_no_actual_owner_state() -> void:
	"""Caller scratch cannot rewrite the bound source; explicit retirement itself grants no new gameplay state."""
	var pins: PackedInt64Array = _pins.duplicate()
	var driver: Driver = Driver.new()
	assert_equal(_bind(driver, pins), &"", "independent presentation state")
	pins[6] = 999
	var out: Driver.Frame = Driver.Frame.new()
	assert_equal(driver.step_into(2, _job, Driver.ONE, false, out), &"", "copied profile tuple")
	out.frames[0] = 999
	assert_equal(driver.step_into(2, _job, 0, false, out), &"", "caller output does not alias state")
	assert_true(out.frames[0] != 999, "fresh exact source frame")
	driver.retire()
	assert_equal(driver.step_into(2, _job, Driver.ONE, true, out), &"MOLE_DRIVER_UNBOUND", "no replay after retirement")
	assert_equal(_fixture._work.tool_job_of(_fixture._slot), _job, "driver did not release actual Work")
	assert_equal(_fixture._gear.owner_of(_tool), _fixture._worker, "driver did not hide or transfer tool")
	assert_equal(_bind(driver, _pins), &"MOLE_DRIVER_ALREADY_BOUND", "retired source cannot silently reactivate")


func test_swapped_work_tuples_cannot_pair_a_downward_clip_with_the_upper_contact() -> void:
	"""Two otherwise valid WORK rows share one source; its authored role IDs remain non-interchangeable."""
	var swapped: PackedInt64Array = _pins.duplicate()
	for field: int in 3:
		swapped[6 + field] = _pins[9 + field]
		swapped[9 + field] = _pins[6 + field]
	var driver: Driver = Driver.new()
	assert_equal(_bind(driver, swapped), &"MOLE_DRIVER_PROFILE_ROLE", "whole valid tuples cannot swap source roles")
	var out: Driver.Frame = Driver.Frame.new()
	assert_equal(driver.step_into(2, _job, Driver.ONE, false, out), &"MOLE_DRIVER_UNBOUND", "refused binding published nothing")
	assert_equal(_bind(driver, _pins), &"", "exact authored role order remains usable after refusal")
	assert_equal(driver.step_into(2, _job, 4 * Driver.ONE, false, out), &"", "actual down contact")
	assert_equal(out.profile_id, 2, "down source owns down certificate")
	assert_equal(out.frames[0], COUNTS[0] + COUNTS[1], "the matching down productive clip")
	driver.retire()
