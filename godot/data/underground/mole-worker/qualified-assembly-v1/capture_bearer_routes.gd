extends "../work-step-v1/capture_canonical.gd"
## Current actual source2/6 clocks and native palettes; explicit free test geometry is not paid construction.

const PROFILE_PATH: String = "res://data/underground/mole-worker/qualified-assembly-v1/diagnostic-profile-1/mole-worker.ugprof"
const PROFILE_SHA: String = "17d9c229fdfe8ad1923f004db136653ab9834994ba946061be38ec7a2c862ff9"
const GROUND_PATH: String = "res://data/underground/mole-worker/qualified-assembly-v1/bearer-routes-input-v1/ground-pace.ugconn"
const GROUND_SHA: String = "877be0982eb6945c4c4f014e9de428b3ab278d1fddc630080e9c6bfe341a1ea8"
const HANDLING: Vector3i = START
const MATERIAL: Vector3i = START + Vector3i(0, 0, 1536)
const RETREAT: Vector3i = START + Vector3i(0, 0, 1024)


class CurrentFixture extends Fixture:
	## Reuse the real fixture owners with the exact appended source, never a positive permission override.
	func _source_profiles() -> void:
		"""One current Profiles owner holds the immutable30/281/2 source image from before any route publication."""
		assert_equal(_profiles.configure(30, 281, 2, Profiles.ARENA_BYTES), &"", "exact current source pack")
		assert_equal(_profiles.bind_actual(_residents, _transforms, _inventory, _gear, _carry, _work, _pool, _piles), &"", "actual owners")
		assert_equal(_profiles.load_file(PROFILE_PATH, PROFILE_SHA, 4), &"", "whole immutable source4")
		var store: Vector2i = _inventory.create_container(_world_ref, 1000000, -1, 0, true).ref
		_source_tool = _inventory.create_lot(store, _items.compiled_id(&"tool"), 1000, 0, 0, -1, 0, 0).ref
		assert_true(_gear.create_gear(_inventory, _items, _source_tool, Gear.MANUFACTURE_BASIC).ok, "actual source pick")
		assert_true(_gear.equip(_source_tool, _worker).ok, "actual equipped pick")
		_source_job = _turn_job()
		assert_true(_work.claim_tool_for_work(_residents.directory().get_typed_row(_worker), _source_tool).ok, "actual BUILD claim")

	func _load_catalog(revision: int) -> StringName:
		"""Only exact root-authored diagnostic content4 ground paces are used, without altering adopted speed."""
		return _catalog.load_file(GROUND_PATH, GROUND_SHA, revision)


func _setup_sequence(meshes: Dictionary, view: String) -> void:
	"""One fresh actual owner tuple per view; spawn placement occurs before canonical enrollment."""
	_actual = CurrentFixture.new()
	_actual._turn_source_case = 3
	_actual._actual_fixture()
	var material: Vector2i = _actual._location(MATERIAL)
	var retreat: Vector2i = _actual._location(RETREAT)
	_points = PackedInt32Array([material.x, material.y, _actual._first.x, _actual._first.y, retreat.x, retreat.y])
	_publish_leg(material, _actual._first, MATERIAL, HANDLING)
	_publish_leg(_actual._first, retreat, HANDLING, RETREAT)
	_suite.assert_true(_actual._transforms.place(_actual._worker, MATERIAL.x, MATERIAL.y, MATERIAL.z, 0), "original unregistered spawn")
	_suite.assert_equal(_actual._routes.admit_travel_actor(_actual._worker, _actual._source_job, material,
		12, 1, 4, 0, -1, _actual._source_tool), &"", "fresh actual canonical READY")
	_bind_actor(meshes)
	_bind_driver()
	var focus: Vector3 = Vector3(HANDLING + Vector3i(300, 512, 640)) / 1024.0
	_camera.position = focus + (Vector3(3, 1, -3) if view == "side" else Vector3(3, 4, 3))
	_camera.look_at(focus, Vector3.UP)
	_bearer_mesh()


func _bind_driver() -> void:
	"""The unchanged54 scalar driver pins select the old ground and16 work clips inside current content4."""
	var pins: PackedInt64Array = PackedInt64Array()
	for row: int in 18: pins.append_array(PackedInt64Array([row if row < 2 else row + 11, 1, 4]))
	_driver = Driver.new()
	_suite.assert_equal(_driver.configure(_content, _actual._profiles, _actual._residents, _actual._worker,
		_actual._source_tool, pins, Driver.SourceProgram.ACTOR_SHA, Driver.PROGRAM_SHORT_STEP), &"", "same actual source consumer")


func _bearer_mesh() -> void:
	"""Visualize the complete L0 prism only; this mesh supplies no Space, payment, collision or source permission."""
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(2.0, 0.125, 0.125)
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = Vector3(HANDLING + Vector3i(832, 64, -448)) / 1024.0
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.38, 0.20, 0.09)
	instance.material_override = material
	_actor.add_child(instance)
	instance.top_level = true


func _travel(profile: int, endpoint: Vector2i, tick: int) -> void:
	"""Actual canonical READY is mandatory at each source-family handoff, including the stationary fade time."""
	_suite.assert_equal(_actual._routes.refresh_travel_actor(_actual._worker, _actual._source_job, profile,
		1, 4, 0, -1, _actual._source_tool), &"", "same-heading actual READY handoff")
	_suite.assert_equal(_actual._routes.request_route(_actual._worker, endpoint, tick), &"", "original directed request")


func _sequence(view: String) -> void:
	"""31 actual forward ticks plus26 actual reverse ticks include both full8-tick fades and exact remainders."""
	await _sample(view, 0, "initial", 12)
	_travel(2, _ref(1), 0)
	for tick: int in range(1, 58):
		if tick == 32:
			_suite.assert_equal(Fixture.Routes.source_ready_leaf_refusal(_actual._routes, _actual._worker,
				_actual._source_job, 2, 1, 4), &"", "full arrival fade before reverse")
			_travel(6, _ref(2), tick - 1)
		_suite.assert_equal(_actual._routes.advance_tick(tick), 1, "one integer30Hz tick")
		await _sample(view, tick, "tick", 2 if tick <= 31 else 6)
		if not _suite.failures.is_empty(): break
	_suite.assert_equal(Fixture.Routes.source_ready_leaf_refusal(_actual._routes, _actual._worker,
		_actual._source_job, 6, 1, 4), &"", "full reverse recovery at real retreat")


func _sample(view: String, tick: int, action: String, profile: int) -> void:
	"""The real Driver consumes the same canonical tuple; native bone/tool matrices are written without recomposition."""
	var frame: Driver.Frame = Driver.Frame.new()
	var state: PackedInt64Array = PackedInt64Array([0, 0, 0, 0])
	_suite.assert_equal(_driver.read_route_into(_actual._routes, profile, _actual._source_job, frame), &"", "actual source driver")
	_suite.assert_equal(_actual._routes.source_state_into(_actual._worker, _actual._source_job, profile, 1, 4, state), &"", "same canonical tuple")
	_suite.assert_equal(_actor.set_world_root(_actual._world_ref, frame.point, frame.yaw), &"", "actual integer root")
	_suite.assert_equal(_actor.apply_pose(frame.frames), &"", "actual native source pose")
	_events.append({"view": view, "tick": tick, "action": action, "profile": profile, "state": Array(state),
		"point": [frame.point.x, frame.point.y, frame.point.z], "yaw": frame.yaw, "frames": Array(frame.frames), "ready": frame.ready})
	for bind: int in _actor._palette.bind_count(0): _write_matrix(_actor.native_matrix(0, bind))
	_write_matrix(_actor.native_matrix(1, 0))
	_write_matrix(_actor._nodes[0].global_transform)
	_observed += 1
	await process_frame
	if tick in [0, 4, 8, 16, 23, 27, 31, 35, 39, 44, 49, 53, 57]:
		_save_frame("%s-%s-%03d" % [view, action, tick], profile, tick)


func _finish() -> void:
	"""Native sampled source agreement is separate from the continuous537-input proof and actual paid path."""
	var report: Dictionary = {"schema": 1, "program_version": 6, "content_revision": 4,
		"content_sha256": _content.source_digest(), "poses": _observed, "matrix_count": _matrix_count,
		"assertions": _suite.assertions, "failures": _suite.failures, "events": _events, "screenshots": _shots,
		"native_sha256": FileAccess.get_sha256(_out + "/native.bin"), "resolution": [root.size.x, root.size.y],
		"user_directory": OS.get_user_data_dir(), "production_qualified": false,
		"spatial_authority": "actual WorldRoutes/stores; explicit free test geometry, visual unpaid bearer and diagnostic source flags",
		"source_time": "actual30Hz Routes, forward2 then backward6; every integer fade, root and remainder; rendering has no authority"}
	var file: FileAccess = FileAccess.open(_out + "/report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	for failure: String in _suite.failures: printerr("FAIL: ", failure)
	print("native-bearer-route: %d poses, %d assertions, %d failures; qualified=0" % [_observed, _suite.assertions, _suite.failures.size()])
	quit(0 if _suite.failures.is_empty() else 2)
