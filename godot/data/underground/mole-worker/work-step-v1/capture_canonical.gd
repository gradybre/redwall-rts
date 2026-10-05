extends "../evidence/grip-authoring/native_grip_sequence.gd"
## Actual source/WorldRoutes canonical replay in explicit test geometry; no production publication or paid work.

const Driver := preload("res://data/underground/mole-worker/mole_profile_driver.gd")
const Fixture := preload("res://test/test_underground_world_routes.gd")
const START: Vector3i = Vector3i(Fixture.X + 512, 512, Fixture.Z + 512)
const TURN: Vector3i = START + Vector3i(0, 0, 1024)
const FRONT: Vector3i = TURN + Vector3i(1024, 0, 0)
const HIGH: Vector3i = FRONT + Vector3i(232, 0, 0)
var _events: Array[Dictionary] = []
var _native: FileAccess = null
var _actual: Fixture = null
var _driver: Driver = null
var _points: PackedInt32Array = PackedInt32Array()
var _matrix_count: int = 0


func _run() -> void:
	"""One borrowed immutable Content serves sequential owners; the renderer never advances the actual source clock."""
	_suite.assert_equal(_content.load_file(_spec.content, _spec.content_sha256, _spec.reserve_bytes), &"", "actual supplied source")
	_world = Node3D.new()
	root.add_child(_world)
	_build_stage()
	var meshes: Dictionary = _borrow_actual_meshes()
	_native = FileAccess.open(_out + "/native.bin", FileAccess.WRITE)
	_native.store_buffer("UGSTPN01".to_ascii_buffer())
	for view: String in ["side", "rts"]:
		_setup_sequence(meshes, view)
		if _suite.failures.is_empty(): await _sequence(view)
		_release_sequence()
	_native.close()
	_native = null
	_world.free()
	_world = null
	_camera = null
	_finish()


func _build_stage() -> void:
	"""Lighting is presentation only; every physical fact comes from the actual fixture owners."""
	super._build_stage()
	root.size = Vector2i(1280, 720)
	_camera.size = 4.0


func _setup_sequence(meshes: Dictionary, view: String) -> void:
	"""Real adult mole, pick, Job, Profiles, ground pace, Space, Locations and WorldRoutes; explicit geometry fixture."""
	_actual = Fixture.new()
	_actual._turn_source_case = 3
	_actual._actual_fixture()
	var first: Vector2i = _actual._first
	var turn: Vector2i = _actual._location(TURN)
	var front: Vector2i = _actual._location(FRONT)
	var high: Vector2i = _high_location()
	_points = PackedInt32Array([first.x, first.y, turn.x, turn.y, front.x, front.y, high.x, high.y])
	_publish_leg(first, turn, START, TURN)
	_publish_leg(turn, front, TURN, FRONT)
	_publish_leg(front, high, FRONT, HIGH)
	_suite.assert_true(_actual._transforms.set_yaw(_actual._worker, 32768), "original spawn heading before source enrollment")
	_suite.assert_equal(_actual._routes.admit_travel_actor(_actual._worker, _actual._source_job, first,
		12, 1, 3, 0, -1, _actual._source_tool), &"", "fresh canonical ground READY")
	_bind_actor(meshes)
	var pins: PackedInt64Array = PackedInt64Array()
	for row: int in 18: pins.append_array(PackedInt64Array([row if row < 2 else row + 11, 1, 3]))
	_driver = Driver.new()
	_suite.assert_equal(_driver.configure(_content, _actual._profiles, _actual._residents, _actual._worker,
		_actual._source_tool, pins, Driver.SourceProgram.ACTOR_SHA, Driver.PROGRAM_SHORT_STEP), &"", "source protocol6")
	var focus: Vector3 = Vector3(START + Vector3i(600, 512, 600)) / 1024.0
	_camera.position = focus + (Vector3(3, 1, -3) if view == "side" else Vector3(3, 4, 3))
	_camera.look_at(focus, Vector3.UP)


func _high_location() -> Vector2i:
	"""The actual HIGH endpoint needs its whole authored support and air, beyond the ground-only fixture packet."""
	var row: Fixture.Locations.Record = Fixture.Locations.Record.new()
	row.point = HIGH
	row.section = _actual._floor
	row.level = 0
	row.role = Fixture.Locations.ROLE_TRANSIT
	row.envelope = PackedInt32Array([HIGH.x, HIGH.y, HIGH.z, HIGH.x, HIGH.y, HIGH.z])
	row.support = row.envelope.duplicate()
	var descriptor: Fixture.Profiles.Descriptor = Fixture.Profiles.Descriptor.new()
	var box: Fixture.Profiles.Box = Fixture.Profiles.Box.new()
	for profile: int in [10, 11, 12, 26]:
		_suite.assert_equal(_actual._profiles.descriptor_into(profile, 3, descriptor), &"", "whole source endpoint descriptor")
		for ordinal: int in descriptor.box_count:
			_suite.assert_equal(_actual._profiles.box_into(profile, 1, 3, ordinal, box), &"", "whole source endpoint box")
			if box.role >= Fixture.Profiles.CONTACT_POINT: continue
			var bounds: PackedInt32Array = row.support if box.role == Fixture.Profiles.STANCE_SUPPORT else row.envelope
			for axis: int in 3:
				bounds[axis] = mini(bounds[axis], HIGH[axis] + box.low[axis])
				bounds[axis + 3] = maxi(bounds[axis + 3], HIGH[axis] + box.high[axis])
	row.envelope[1] = HIGH.y # Below-plane residuals remain separately covered by exact whole stance.
	var cold: int = _actual._budget.acquire(Fixture.Budget.COLD_BYTES)
	var token: int = _actual._locations.begin_prepare(cold).token
	var added: Fixture.Locations.Result = _actual._locations.stage_add(token, row)
	_suite.assert_equal(added.error, &"", "actual complete HIGH endpoint")
	_suite.assert_equal(_actual._locations.seal(token), &"", "HIGH endpoint sealed")
	_suite.assert_true(_actual._locations.publish(token), "HIGH endpoint published")
	_suite.assert_equal(_actual._budget.release(cold), &"", "HIGH endpoint scratch released")
	return added.location


func _publish_leg(first: Vector2i, last: Vector2i, begin: Vector3i, end: Vector3i) -> void:
	"""Actual whole-source clearance certificates cover both directions before any route request exists."""
	var token: int = _actual._begin()
	for reverse: bool in [false, true]:
		var edge: Fixture.Routes.Edge = _actual._edge()
		edge.from_location = last if reverse else first
		edge.to_location = first if reverse else last
		var a: Vector3i = end if reverse else begin
		var b: Vector3i = begin if reverse else end
		edge.points = PackedInt32Array([a.x, a.y, a.z, b.x, b.y, b.z])
		edge.length_u = absi(b.x - a.x) + absi(b.z - a.z)
		_suite.assert_equal(_actual._routes.stage_add(token, edge).error, &"", "actual finite ground span")
	_suite.assert_equal(_actual._binding.seal(token), &"", "all actual masks sealed")
	_suite.assert_equal(_actual._binding.publish(token), &"", "actual graph and certificates")
	_actual._end(token)


func _bind_actor(meshes: Dictionary) -> void:
	"""No second Content image or fabricated World identity is introduced for the visual consumer."""
	var basis: Actor.WorldBasis = Actor.WorldBasis.new()
	_suite.assert_equal(basis.load_file(_spec.basis, _spec.basis_sha256, _spec.basis_producer_sha256,
		Actor.WorldBasis.RESERVED_BYTES), &"", "actual native basis")
	_actor = Actor.new()
	_world.add_child(_actor)
	_suite.assert_equal(_content.configure_actor(_actor, meshes.meshes, meshes.materials), &"", "actual meshes")
	var domain: Actor.Space.Domain = _actual._owner._domain
	_suite.assert_true(_content.domain_matches(domain.descriptor().bounds_u), "full actual finite World domain")
	_suite.assert_equal(_actor.bind_world_source(basis, domain, domain.descriptor(), _content.source_digest(), basis.source_digest()), &"", "one actual World")
	_matrix_count = _actor._palette.bind_count(0) + 2


func _ref(ordinal: int) -> Vector2i:
	"""Use original full endpoints; a coordinate never substitutes for an actual Location."""
	return Vector2i(_points[ordinal * 2], _points[ordinal * 2 + 1])


func _travel(profile: int, endpoint: Vector2i, tick: int) -> void:
	"""Only canonical READY may switch exact source profiles and begin a new original route request."""
	_suite.assert_equal(_actual._routes.refresh_travel_actor(_actual._worker, _actual._source_job, profile,
		1, 3, 0, -1, _actual._source_tool), &"", "actual ready profile handoff")
	_suite.assert_equal(_actual._routes.request_route(_actual._worker, endpoint, tick), &"", "actual directed request")


func _sequence(view: String) -> void:
	"""228 actual fixed ticks plus two accepted ready turns; no animation-time or actor-reset shortcut."""
	var profile: int = 12
	await _sample(view, 0, "initial", profile)
	_suite.assert_equal(_actual._routes.request_route(_actual._worker, _ref(1), 0), &"", "ground access leg")
	for tick: int in range(1, 229):
		if tick == 27:
			_suite.assert_equal(_actual._turn(49152, Fixture.Space.MAX_CHECKS, _actual._source_job), &"", "actual wide supported READY turn")
			await _sample(view, 26, "turn", 12)
			profile = 5
			_travel(profile, _ref(2), tick - 1)
		elif tick == 53:
			profile = 10
			_travel(profile, _ref(3), tick - 1)
		elif tick == 72:
			profile = 26
			_suite.assert_equal(_actual._routes.refresh_work_actor(_actual._worker, _actual._source_job,
				profile, 1, 3, 0, -1, _actual._source_tool), &"", "source HIGH entry without productive WU")
		elif tick == 128:
			_suite.assert_equal(_actual._routes.request_source_ready(_actual._worker, _actual._source_job), &"", "actual whole work recovery")
		elif tick == 158:
			profile = 11
			_travel(profile, _ref(2), tick - 1)
		elif tick == 177:
			profile = 9
			_travel(profile, _ref(1), tick - 1)
		elif tick == 203:
			profile = 12
			_suite.assert_equal(_actual._routes.refresh_travel_actor(_actual._worker, _actual._source_job,
				profile, 1, 3, 0, -1, _actual._source_tool), &"", "original canonical ground at recovered gateway")
			_suite.assert_equal(_actual._turn(0, Fixture.Space.MAX_CHECKS, _actual._source_job), &"", "actual wide turn to retreat leg")
			await _sample(view, 202, "turn", profile)
			_suite.assert_equal(_actual._routes.request_route(_actual._worker, _ref(0), tick - 1), &"", "actual ground retreat")
		_suite.assert_equal(_actual._routes.advance_tick(tick), 1, "one headless canonical tick")
		await _sample(view, tick, "tick", profile)
		if not _suite.failures.is_empty(): break
	_suite.assert_equal(Fixture.Routes.source_ready_leaf_refusal(_actual._routes, _actual._worker,
		_actual._source_job, 12, 1, 3), &"", "source recovery ends at original access")


func _sample(view: String, tick: int, action: String, profile: int) -> void:
	"""Actual native palette/body/tool matrices are compared independently, including every accepted clock and root."""
	var frame: Driver.Frame = Driver.Frame.new()
	var state: PackedInt64Array = PackedInt64Array([0, 0, 0, 0])
	_suite.assert_equal(_driver.read_route_into(_actual._routes, profile, _actual._source_job, frame), &"", "actual source driver")
	_suite.assert_equal(_actual._routes.source_state_into(_actual._worker, _actual._source_job, profile, 1, 3, state), &"", "same canonical owner")
	_suite.assert_equal(_actor.set_world_root(_actual._world_ref, frame.point, frame.yaw), &"", "actual integer root")
	_suite.assert_equal(_actor.apply_pose(frame.frames), &"", "native source pose")
	_events.append({"view": view, "tick": tick, "action": action, "profile": profile, "state": Array(state),
		"point": [frame.point.x, frame.point.y, frame.point.z], "yaw": frame.yaw, "frames": Array(frame.frames), "ready": frame.ready})
	for bind: int in _actor._palette.bind_count(0): _write_matrix(_actor.native_matrix(0, bind))
	_write_matrix(_actor.native_matrix(1, 0))
	_write_matrix(_actor._nodes[0].global_transform)
	_observed += 1
	await process_frame
	if action != "tick" or tick in [4, 18, 26, 40, 52, 56, 61, 63, 71, 88, 115, 143, 157, 166, 168, 176, 190, 202, 215, 228]:
		_save_frame("%s-%s-%03d" % [view, action, tick], profile, tick)


func _write_matrix(matrix: Transform3D) -> void:
	"""Twelve binary32 columns per original native transform, without rounding or CPU recomposition."""
	for vector: Vector3 in [matrix.basis.x, matrix.basis.y, matrix.basis.z, matrix.origin]:
		_native.store_float(vector.x)
		_native.store_float(vector.y)
		_native.store_float(vector.z)


func _save_frame(label: String, clip: int, tick: int) -> void:
	"""Deterministic native draw/readback; screen cadence has no authority over the tick state."""
	RenderingServer.force_draw(false, 0.0)
	var image: Image = root.get_texture().get_image()
	var path: String = _out + "/" + label + ".png"
	_suite.assert_false(FileAccess.file_exists(path), "create-only frame")
	_suite.assert_equal(image.save_png(path), OK, "actual rendered frame")
	_shots.append({"path": label + ".png", "clip": clip, "half_tick": tick, "sha256": FileAccess.get_sha256(path)})
	print("step-frame: ", _observed, " ", label)


func _release_sequence() -> void:
	"""Release test owners after the presentation borrower; never mutate them to obtain a READY transition."""
	if _driver != null: _driver.retire()
	_driver = null
	if _actor != null: _actor.free()
	_actor = null
	if _actual != null:
		_actual.after_each()
		_suite.assert_true(_actual.failures.is_empty(), "all actual fixture assertions: " + str(_actual.failures))
	_actual = null


func _finish() -> void:
	"""This sampled native test does not publish a certificate, paid room or whole-game qualification."""
	var report: Dictionary = {"schema": 1, "program_version": 6, "content_sha256": _content.source_digest(),
		"poses": _observed, "matrix_count": _matrix_count, "assertions": _suite.assertions, "failures": _suite.failures,
		"events": _events, "screenshots": _shots, "native_sha256": FileAccess.get_sha256(_out + "/native.bin"),
		"resolution": [root.size.x, root.size.y], "user_directory": OS.get_user_data_dir(), "production_qualified": false,
		"spatial_authority": "actual WorldRoutes/stores and whole source bounds; explicit unearned test geometry and diagnostic flags",
		"source_time": "actual30Hz Routes, finite232u prefixes, canonical ground and READY turns; no rendering progress"}
	var file: FileAccess = FileAccess.open(_out + "/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	for failure: String in _suite.failures: printerr("FAIL: ", failure)
	print("native-step: %d poses, %d assertions, %d failures; qualified=0" % [_observed, _suite.assertions, _suite.failures.size()])
	quit(0 if _suite.failures.is_empty() else 2)
