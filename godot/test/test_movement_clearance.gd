extends "res://test/framework/test_case.gd"
## GROUND-CLEARANCE-R01v1: coverage for the qualified-route-clearance admission gate.
##
## Exercises REAL production `Movement.begin_travel()` throughout -- no fixture overrides
## `begin_travel()` or any other admission gate anywhere in this repository. The only overridden
## method, on `test/fixtures/synthetic_ground_movement.gd`, is `profile_clearance_class_into()`,
## which production refuses unconditionally for every starter profile; this suite documents and
## exercises both that production refusal and the fixture's synthetic qualification.

const SpatialWorldScript := preload("res://scripts/core/spatial_world.gd")
const NavigationScript := preload("res://scripts/core/navigation.gd")
const TransformsScript := preload("res://scripts/core/transforms.gd")
const MovementScript := preload("res://scripts/core/movement.gd")
const SyntheticGroundMovementScript := preload("res://test/fixtures/synthetic_ground_movement.gd")
const EntityDirectoryScript := preload("res://scripts/core/entity_directory.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")
const IntMathScript := preload("res://scripts/core/int_math.gd")

const ANCHOR_X: int = 192
const ANCHOR_Z: int = 288
const DESTINATION_REVISION: int = 1
const CLASS_ONE: int = 1
const CLASS_TWO: int = 2

var _world: SpatialWorldScript = null
var _directory: EntityDirectoryScript = null
var _residents: ResidentsScript = null
var _navigation: NavigationScript = null
var _transforms: TransformsScript = null
var _movement: SyntheticGroundMovementScript = null
var _result: IntMathScript.IntResult = null
var _pose: TransformsScript.Pose = null


func before_each() -> void:
	"""Build a complete stack, with the synthetic clearance fixture, against a fresh ground map.

	A fresh map per test, not a shared one: several tests here mutate legality to force a map
	revision change, and that must never leak between tests.
	"""
	_world = SpatialWorldScript.new()
	_directory = EntityDirectoryScript.new()
	_residents = ResidentsScript.new(_directory, null)
	_navigation = NavigationScript.new(_directory, _world)
	_transforms = TransformsScript.new(_directory)
	_movement = SyntheticGroundMovementScript.new(
		_directory, _world, _navigation, _transforms, _residents)
	_result = IntMathScript.IntResult.new()
	_pose = TransformsScript.Pose.new()


func after_each() -> void:
	"""Drop everything; each test built its own map."""
	_world = null
	_directory = null
	_residents = null
	_navigation = null
	_transforms = null
	_movement = null
	_result = null
	_pose = null


func _cell(x: int, z: int) -> int:
	"""The cell index of a grid coordinate."""
	return z * SpatialWorldScript.CELLS_X + x


func _spawn_at(species: StringName, cell: int) -> Vector2i:
	"""Spawn one resident and place it on a cell centre; returns its reference."""
	var spawned: Variant = _residents.spawn(species)
	assert_true(spawned.ok, "the resident spawns (error was %s)" % spawned.error)
	var resident: Vector2i = spawned.ref
	assert_true(
		_transforms.place(
			resident, SpatialWorldScript.cell_centre_x_units(cell),
			SpatialWorldScript.LAYER_SURFACE, SpatialWorldScript.cell_centre_z_units(cell), 0),
		"the resident is placed on the cell centre")
	return resident


func _x_of(resident: Vector2i) -> int:
	"""The current authoritative X of a placed resident."""
	assert_true(_transforms.read_into(resident, _pose), "the pose reads")
	return _pose.x


func _route_between(start_cell: int, goal_cell: int, clearance_class: int) -> int:
	"""Build one ready route between two owned ground contacts at `clearance_class`."""
	var job: Vector2i = _directory.create(EntityDirectoryScript.KIND_JOB)
	var start: SpatialWorldScript.Location = SpatialWorldScript.Location.new()
	var goal: SpatialWorldScript.Location = SpatialWorldScript.Location.new()
	assert_true(_world.bind_ground_location(start, start_cell, job), "start binds")
	assert_true(
		_world.bind_ground_location(
			goal, goal_cell, _directory.create(EntityDirectoryScript.KIND_RESOURCE_NODE)),
		"goal binds")
	assert_true(
		_navigation.submit_request_into(job, start, goal, clearance_class, 0, _result),
		"the request is accepted (refusal was %s)" % _navigation.last_refusal())
	var request: int = _result.value
	var tick: int = 0
	while _navigation.is_pending(request) and tick < 64:
		tick += 1
		_navigation.service(tick)
	assert_true(_navigation.is_ready(request), "the route is ready")
	return request


func _admission_on(
	mover: MovementScript, species: StringName, load_g: int
) -> MovementScript.Admission:
	"""Build an admission naming `mover`'s own published starter profile for `species`."""
	var admission: MovementScript.Admission = MovementScript.Admission.new()
	assert_true(
		mover.profile_for_species_into(species, _result),
		"%s has a published starter profile" % species)
	admission.set_terms(
		_result.value, MovementScript.LIFE_STAGE_ADULT, MovementScript.MODE_GROUND_WALK, load_g)
	return admission


func _contact_at(approach_cell: int, revision: int) -> SpatialWorldScript.Contact:
	"""Bind one work contact whose work point and approach cell are the same ground cell."""
	var contact: SpatialWorldScript.Contact = SpatialWorldScript.Contact.new()
	assert_true(
		_world.bind_ground_contact(
			contact, approach_cell, approach_cell,
			_directory.create(EntityDirectoryScript.KIND_BUILDING), revision),
		"the contact binds (refusal was %s)" % _world.last_refusal())
	return contact


func _snapshot(mover: MovementScript, resident: Vector2i, route: int) -> Array[int]:
	"""One flat, EXPLICITLY ORDERED preservation witness, public getters only, no private state.

	Index order: 0 phase, 1 cursor index, 2 remainder_x, 3 remainder_z, 4 owner id, 5 admitted
	profile, 6 admitted profile revision, 7 admitted mode, 8 admitted load, 9 admitted
	destination revision, 10 travelling count, 11 speed_of, 12 authoritative X, 13 route id,
	14 route generation, 15 route refcount. Every value comes from an existing public reader;
	nothing here is a new production accessor.
	"""
	var route_id: int = _navigation.request_route_id(route)
	return [
		mover.motion_phase(resident), mover.route_index_of(resident),
		mover.remainder_x_of(resident), mover.remainder_z_of(resident),
		mover.route_owner_id_of(resident), mover.admitted_profile_of(resident),
		mover.admitted_profile_revision_of(resident), mover.admitted_mode_of(resident),
		mover.admitted_load_g_of(resident), mover.admitted_destination_revision_of(resident),
		mover.travelling_count(), mover.speed_of(resident), _x_of(resident),
		route_id, _navigation.route_generation_of(route_id), _navigation.route_reference_count(route_id),
	]


func test_production_movement_refuses_a_ready_class_one_route_for_every_starter_species() -> void:
	"""Real production `Movement`: PROFILE_CLEARANCE_UNSPECIFIED, for a perfectly valid request.

	Snapshots the FULL public preservation witness and the whole Transform store; admission and
	contact are built BEFORE the snapshot so it isolates only the refused operation.
	"""
	var production: MovementScript = MovementScript.new(
		_directory, _world, _navigation, _transforms, _residents)
	var species_list: Array[StringName] = [&"mouse", &"mole", &"otter", &"squirrel"]
	for index: int in species_list.size():
		var species: StringName = species_list[index]
		var start: int = _cell(ANCHOR_X, ANCHOR_Z + index)
		var goal: int = _cell(ANCHOR_X + 10, ANCHOR_Z + index)
		var resident: Vector2i = _spawn_at(species, start)
		var request: int = _route_between(start, goal, CLASS_ONE)
		var admission: MovementScript.Admission = _admission_on(production, species, 0)
		var contact: SpatialWorldScript.Contact = _contact_at(goal, DESTINATION_REVISION)
		var before: Array[int] = _snapshot(production, resident, request)
		var before_bytes: PackedByteArray = _transforms.state_bytes()
		assert_false(
			production.begin_travel(resident, request, admission, contact),
			"%s is refused by production" % species)
		assert_equal(
			production.last_refusal(), MovementScript.REFUSE_PROFILE_CLEARANCE,
			"refusal is PROFILE_CLEARANCE_UNSPECIFIED")
		assert_equal(
			production.motion_phase(resident), MovementScript.MOTION_IDLE, "never attached")
		assert_equal(
			_snapshot(production, resident, request), before, "%s: full state preserved" % species)
		assert_equal(
			_transforms.state_bytes(), before_bytes, "%s: Transform store byte-identical" % species)
	assert_equal(production.travelling_count(), 0, "nothing is travelling")


func test_synthetic_class_one_admits_a_real_class_one_route_and_advances() -> void:
	"""The default synthetic class (1) qualifies a route that was actually searched at class 1."""
	var start: int = _cell(ANCHOR_X, ANCHOR_Z)
	var goal: int = _cell(ANCHOR_X + 10, ANCHOR_Z)
	var mouse: Vector2i = _spawn_at(&"mouse", start)
	var request: int = _route_between(start, goal, CLASS_ONE)
	assert_true(
		_movement.begin_travel(
			mouse, request, _admission_on(_movement, &"mouse", 0),
			_contact_at(goal, DESTINATION_REVISION)),
		"synthetic class 1 admits a real class 1 route (refusal was %s)" % _movement.last_refusal())
	var before_x: int = _x_of(mouse)
	_movement.advance_tick(1)
	assert_true(_x_of(mouse) != before_x, "the resident actually advances")


func test_synthetic_class_two_admits_a_real_class_two_route_and_advances() -> void:
	"""A reconfigured synthetic class qualifies a route actually searched at that class."""
	_movement.set_synthetic_clearance_class(CLASS_TWO)
	var start: int = _cell(ANCHOR_X, ANCHOR_Z)
	var goal: int = _cell(ANCHOR_X + 10, ANCHOR_Z)
	var otter: Vector2i = _spawn_at(&"otter", start)
	var request: int = _route_between(start, goal, CLASS_TWO)
	assert_true(
		_movement.begin_travel(
			otter, request, _admission_on(_movement, &"otter", 0),
			_contact_at(goal, DESTINATION_REVISION)),
		"synthetic class 2 admits a real class 2 route (refusal was %s)" % _movement.last_refusal())
	var before_x: int = _x_of(otter)
	_movement.advance_tick(1)
	assert_true(_x_of(otter) != before_x, "the resident actually advances")


func test_profile_one_route_two_mismatch_refuses_and_preserves_idle() -> void:
	"""The default synthetic class 1 against an actually class-2 route refuses by name.

	Full preservation, not phase alone: the whole public snapshot and the whole Transform store.
	"""
	var start: int = _cell(ANCHOR_X, ANCHOR_Z)
	var goal: int = _cell(ANCHOR_X + 10, ANCHOR_Z)
	var mouse: Vector2i = _spawn_at(&"mouse", start)
	var request: int = _route_between(start, goal, CLASS_TWO)
	var admission: MovementScript.Admission = _admission_on(_movement, &"mouse", 0)
	var contact: SpatialWorldScript.Contact = _contact_at(goal, DESTINATION_REVISION)
	var before: Array[int] = _snapshot(_movement, mouse, request)
	var before_bytes: PackedByteArray = _transforms.state_bytes()
	assert_false(
		_movement.begin_travel(mouse, request, admission, contact),
		"a class 1 profile on a class 2 route refuses")
	assert_equal(
		_movement.last_refusal(), MovementScript.REFUSE_ROUTE_CLEARANCE, "refusal is named")
	assert_equal(_movement.motion_phase(mouse), MovementScript.MOTION_IDLE, "it stays idle")
	assert_equal(_movement.travelling_count(), 0, "nothing is travelling")
	assert_equal(_snapshot(_movement, mouse, request), before, "full state preserved")
	assert_equal(_transforms.state_bytes(), before_bytes, "Transform store byte-identical")


func test_profile_two_route_one_mismatch_refuses_and_preserves_idle() -> void:
	"""The reverse mismatch: a reconfigured class 2 profile against an actually class-1 route.

	Full preservation, not phase alone.
	"""
	_movement.set_synthetic_clearance_class(CLASS_TWO)
	var start: int = _cell(ANCHOR_X, ANCHOR_Z)
	var goal: int = _cell(ANCHOR_X + 10, ANCHOR_Z)
	var mouse: Vector2i = _spawn_at(&"mouse", start)
	var request: int = _route_between(start, goal, CLASS_ONE)
	var admission: MovementScript.Admission = _admission_on(_movement, &"mouse", 0)
	var contact: SpatialWorldScript.Contact = _contact_at(goal, DESTINATION_REVISION)
	var before: Array[int] = _snapshot(_movement, mouse, request)
	var before_bytes: PackedByteArray = _transforms.state_bytes()
	assert_false(
		_movement.begin_travel(mouse, request, admission, contact),
		"a class 2 profile on a class 1 route refuses")
	assert_equal(
		_movement.last_refusal(), MovementScript.REFUSE_ROUTE_CLEARANCE, "refusal is named")
	assert_equal(_movement.motion_phase(mouse), MovementScript.MOTION_IDLE, "it stays idle")
	assert_equal(_snapshot(_movement, mouse, request), before, "full state preserved")
	assert_equal(_transforms.state_bytes(), before_bytes, "Transform store byte-identical")


func test_a_mismatched_readmission_mid_travel_changes_nothing_then_restored_class_continues() -> void:
	"""A refused re-admission touches nothing; restoring the matching class simply continues it."""
	var start: int = _cell(ANCHOR_X, ANCHOR_Z)
	var goal: int = _cell(ANCHOR_X + 30, ANCHOR_Z)
	var mouse: Vector2i = _spawn_at(&"mouse", start)
	var request: int = _route_between(start, goal, CLASS_ONE)
	var contact: SpatialWorldScript.Contact = _contact_at(goal, DESTINATION_REVISION)
	assert_true(
		_movement.begin_travel(mouse, request, _admission_on(_movement, &"mouse", 0), contact),
		"the first admission succeeds (refusal was %s)" % _movement.last_refusal())
	_movement.advance_tick(1)

	var route_id: int = _navigation.request_route_id(request)
	var before_refcount: int = _navigation.route_reference_count(route_id)
	var before_generation: int = _navigation.route_generation_of(route_id)
	var before_digest: int = _transforms.authoritative_digest()
	var before_phase: int = _movement.motion_phase(mouse)
	var before_index: int = _movement.route_index_of(mouse)
	var before_remainder_x: int = _movement.remainder_x_of(mouse)
	var before_remainder_z: int = _movement.remainder_z_of(mouse)
	var before_owner: int = _movement.route_owner_id_of(mouse)
	var before_profile: int = _movement.admitted_profile_of(mouse)
	var before_profile_revision: int = _movement.admitted_profile_revision_of(mouse)
	var before_mode: int = _movement.admitted_mode_of(mouse)
	var before_load: int = _movement.admitted_load_g_of(mouse)
	var before_destination_revision: int = _movement.admitted_destination_revision_of(mouse)
	var before_travelling: int = _movement.travelling_count()
	var before_x: int = _x_of(mouse)
	var before_speed: int = _movement.speed_of(mouse)
	var before_bytes: PackedByteArray = _transforms.state_bytes()

	_movement.set_synthetic_clearance_class(CLASS_TWO)
	assert_false(
		_movement.begin_travel(mouse, request, _admission_on(_movement, &"mouse", 0), contact),
		"the mismatched re-admission refuses")
	assert_equal(
		_movement.last_refusal(), MovementScript.REFUSE_ROUTE_CLEARANCE, "refusal is named")

	assert_equal(_navigation.request_route_id(request), route_id, "route identity unchanged")
	assert_equal(
		_navigation.route_reference_count(route_id), before_refcount, "refcount unchanged")
	assert_equal(
		_navigation.route_generation_of(route_id), before_generation, "generation unchanged")
	assert_equal(
		_transforms.authoritative_digest(), before_digest,
		"no authoritative state changed as a side effect of the refused re-admission")
	assert_equal(_movement.motion_phase(mouse), before_phase, "phase unchanged")
	assert_equal(_movement.route_index_of(mouse), before_index, "cursor index unchanged")
	assert_equal(_movement.remainder_x_of(mouse), before_remainder_x, "X remainder unchanged")
	assert_equal(_movement.remainder_z_of(mouse), before_remainder_z, "Z remainder unchanged")
	assert_equal(_movement.route_owner_id_of(mouse), before_owner, "owner stamp unchanged")
	assert_equal(_movement.admitted_profile_of(mouse), before_profile, "admitted profile unchanged")
	assert_equal(
		_movement.admitted_profile_revision_of(mouse), before_profile_revision,
		"admitted profile revision unchanged")
	assert_equal(_movement.admitted_mode_of(mouse), before_mode, "admitted mode unchanged")
	assert_equal(_movement.admitted_load_g_of(mouse), before_load, "admitted load unchanged")
	assert_equal(
		_movement.admitted_destination_revision_of(mouse), before_destination_revision,
		"admitted destination revision unchanged")
	assert_equal(_movement.travelling_count(), before_travelling, "travelling count unchanged")
	assert_equal(_x_of(mouse), before_x, "and the body did not move")
	assert_equal(_movement.speed_of(mouse), before_speed, "speed unchanged")
	assert_equal(_transforms.state_bytes(), before_bytes, "Transform store byte-identical")

	_movement.set_synthetic_clearance_class(CLASS_ONE)
	_movement.advance_tick(2)
	assert_true(
		_x_of(mouse) != before_x,
		"once the class matches again, the ORIGINAL journey simply continues -- never lost")
	assert_equal(
		_movement.motion_phase(mouse), MovementScript.MOTION_TRAVELLING, "still travelling")


func test_the_getter_reports_the_readied_class_and_refuses_every_non_ready_phase() -> void:
	"""route_clearance_into: prepopulated results, explicit refusals, and no side effects."""
	var start: int = _cell(ANCHOR_X, ANCHOR_Z)
	var goal_one: int = _cell(ANCHOR_X + 10, ANCHOR_Z)
	var goal_two: int = _cell(ANCHOR_X + 10, ANCHOR_Z + 1)
	var request_one: int = _route_between(start, goal_one, CLASS_ONE)
	var request_two: int = _route_between(start, goal_two, CLASS_TWO)

	assert_true(_navigation.route_clearance_into(request_one, _result), "class 1 route reads")
	assert_equal(_result.value, CLASS_ONE, "as class 1")
	assert_true(_navigation.route_clearance_into(request_two, _result), "class 2 route reads")
	assert_equal(_result.value, CLASS_TWO, "as class 2")

	var route_one: int = _navigation.request_route_id(request_one)
	var refcount_before: int = _navigation.route_reference_count(route_one)
	var generation_before: int = _navigation.route_generation_of(route_one)
	for extra_read: int in 3:
		assert_true(_navigation.route_clearance_into(request_one, _result), "reading again")
	assert_equal(
		_navigation.route_reference_count(route_one), refcount_before, "refcount unchanged")
	assert_equal(
		_navigation.route_generation_of(route_one), generation_before, "generation unchanged")

	_result.succeed(999)
	assert_false(_navigation.route_clearance_into(-1, _result), "an invalid row refuses")
	assert_false(_result.ok, "the result reports failure")
	assert_equal(_result.value, 0, "and its value is zeroed, not left stale")
	assert_equal(
		_result.error, String(NavigationScript.REFUSE_NOT_READY), "the error names why")

	_result.succeed(999)
	assert_false(
		_navigation.route_clearance_into(NavigationScript.PATH_REQUEST_CAPACITY - 1, _result),
		"a never-allocated (free) row refuses")
	assert_equal(_result.value, 0, "zeroed")

	var job: Vector2i = _directory.create(EntityDirectoryScript.KIND_JOB)
	var pending_start: SpatialWorldScript.Location = SpatialWorldScript.Location.new()
	var pending_goal: SpatialWorldScript.Location = SpatialWorldScript.Location.new()
	assert_true(_world.bind_ground_location(pending_start, start, job), "pending start binds")
	assert_true(
		_world.bind_ground_location(
			pending_goal, _cell(ANCHOR_X + 60, ANCHOR_Z + 60),
			_directory.create(EntityDirectoryScript.KIND_RESOURCE_NODE)),
		"pending goal binds")
	assert_true(
		_navigation.submit_request_into(job, pending_start, pending_goal, CLASS_ONE, 0, _result),
		"the pending request submits")
	var pending_request: int = _result.value
	assert_true(_navigation.is_queued(pending_request), "and has not been serviced yet")
	_result.succeed(999)
	assert_false(
		_navigation.route_clearance_into(pending_request, _result), "a pending row refuses")
	assert_false(_result.ok, "the pending read reports failure")
	assert_equal(_result.value, 0, "pending read value is zeroed")
	assert_equal(
		_navigation.last_refusal(), NavigationScript.REFUSE_NOT_READY, "the reader's own refusal")

	var route_one_id_before: int = _navigation.request_route_id(request_one)
	assert_true(_navigation.route_clearance_into(request_one, _result), "a ready row reads again")
	assert_true(_result.ok, "the successful read reports success")
	assert_equal(_result.error, "", "and clears its own error string")
	assert_equal(
		_navigation.last_refusal(), NavigationScript.REFUSE_NONE,
		"and clears the refusal the failed reads left behind")
	assert_equal(
		_navigation.request_route_id(request_one), route_one_id_before,
		"request identity is unchanged across reads")

	var cancel_request: int = _route_between(start, _cell(ANCHOR_X + 20, ANCHOR_Z), CLASS_ONE)
	assert_true(_navigation.cancel_request(cancel_request), "the request is cancelled")
	_result.succeed(999)
	assert_false(
		_navigation.route_clearance_into(cancel_request, _result), "a cancelled row refuses")
	assert_false(_result.ok, "the cancelled read reports failure")
	assert_equal(
		_navigation.last_refusal(), NavigationScript.REFUSE_NOT_READY,
		"the cancelled read's own refusal")

	var stale_request: int = _route_between(
		_cell(ANCHOR_X + 100, ANCHOR_Z), _cell(ANCHOR_X + 110, ANCHOR_Z), CLASS_ONE)
	assert_true(
		_world.override_static_legality(_cell(ANCHOR_X + 200, ANCHOR_Z + 200), false),
		"an unrelated cell's legality is edited, advancing the map revision")
	_navigation.service(200)
	assert_true(_navigation.is_stale(stale_request), "the route is now stale")
	_result.succeed(999)
	assert_false(
		_navigation.route_clearance_into(stale_request, _result),
		"a stale-after-service row refuses")
	assert_false(_result.ok, "the stale read reports failure")
	assert_equal(
		_navigation.last_refusal(), NavigationScript.REFUSE_NOT_READY,
		"the stale read's own refusal")


func test_the_clearance_gate_is_ordered_after_earlier_gates_and_before_route_end_start() -> void:
	"""Earlier refusals still win; the clearance gate then wins over a route-end/start mismatch."""
	var start: int = _cell(ANCHOR_X, ANCHOR_Z)
	var goal: int = _cell(ANCHOR_X + 20, ANCHOR_Z)

	var mouse_one: Vector2i = _spawn_at(&"mouse", start)
	var job: Vector2i = _directory.create(EntityDirectoryScript.KIND_JOB)
	var pending_start: SpatialWorldScript.Location = SpatialWorldScript.Location.new()
	var pending_goal: SpatialWorldScript.Location = SpatialWorldScript.Location.new()
	assert_true(_world.bind_ground_location(pending_start, start, job), "start binds")
	assert_true(_world.bind_ground_location(pending_goal, goal, job), "goal binds")
	assert_true(
		_navigation.submit_request_into(job, pending_start, pending_goal, CLASS_TWO, 0, _result),
		"a class 2 request submits but is not serviced")
	var pending_request: int = _result.value
	assert_true(_navigation.is_queued(pending_request), "still queued")
	assert_false(
		_movement.begin_travel(
			mouse_one, pending_request, _admission_on(_movement, &"mouse", 0),
			_contact_at(goal, DESTINATION_REVISION)),
		"an unready request refuses before clearance is even considered")
	assert_equal(
		_movement.last_refusal(), MovementScript.REFUSE_ROUTE_NOT_READY, "refusal is named")

	var child_start: int = _cell(ANCHOR_X, ANCHOR_Z + 5)
	var child: Vector2i = _residents.spawn_with_stage(&"mouse", ResidentsScript.LIFE_STAGE_CHILD).ref
	assert_true(
		_transforms.place(
			child, SpatialWorldScript.cell_centre_x_units(child_start),
			SpatialWorldScript.LAYER_SURFACE, SpatialWorldScript.cell_centre_z_units(child_start), 0),
		"the child is placed")
	var mismatched_route: int = _route_between(
		child_start, _cell(ANCHOR_X + 20, ANCHOR_Z + 5), CLASS_TWO)
	assert_false(
		_movement.begin_travel(
			child, mismatched_route, _admission_on(_movement, &"mouse", 0),
			_contact_at(_cell(ANCHOR_X + 20, ANCHOR_Z + 5), DESTINATION_REVISION)),
		"an adult-asserting caller on a child resident still refuses on life-stage")
	assert_equal(
		_movement.last_refusal(), MovementScript.REFUSE_LIFE_STAGE_MISMATCH,
		"not the clearance mismatch, even though the route is also the wrong class")

	var mouse_two: Vector2i = _spawn_at(&"mouse", _cell(ANCHOR_X, ANCHOR_Z + 10))
	var wrong_end_route: int = _route_between(
		_cell(ANCHOR_X, ANCHOR_Z + 10), _cell(ANCHOR_X + 20, ANCHOR_Z + 10), CLASS_TWO)
	assert_false(
		_movement.begin_travel(
			mouse_two, wrong_end_route, _admission_on(_movement, &"mouse", 0),
			_contact_at(_cell(ANCHOR_X + 21, ANCHOR_Z + 10), DESTINATION_REVISION)),
		"a route that is both the wrong class AND does not end at the contact refuses")
	assert_equal(
		_movement.last_refusal(), MovementScript.REFUSE_ROUTE_CLEARANCE,
		"on the clearance channel, which the contract places before the route-end check")


func test_invalid_profile_id_refuses_before_clearance_is_considered() -> void:
	"""An invalid profile id is caught by the existing profile-identity gate, before clearance."""
	var start: int = _cell(ANCHOR_X, ANCHOR_Z)
	var goal: int = _cell(ANCHOR_X + 10, ANCHOR_Z)
	var mouse: Vector2i = _spawn_at(&"mouse", start)
	var request: int = _route_between(start, goal, CLASS_TWO)
	var admission: MovementScript.Admission = MovementScript.Admission.new()
	admission.set_terms(-1, MovementScript.LIFE_STAGE_ADULT, MovementScript.MODE_GROUND_WALK, 0)
	assert_false(
		_movement.begin_travel(mouse, request, admission, _contact_at(goal, DESTINATION_REVISION)),
		"an invalid profile id refuses")
	assert_equal(
		_movement.last_refusal(), MovementScript.REFUSE_PROFILE_ID,
		"not the clearance mismatch, even though the route is also the wrong class")


func test_unbound_contact_refuses_before_clearance_is_considered() -> void:
	"""An unbound contact is caught by the existing contact gate, before clearance."""
	var start: int = _cell(ANCHOR_X, ANCHOR_Z)
	var goal: int = _cell(ANCHOR_X + 10, ANCHOR_Z)
	var mouse: Vector2i = _spawn_at(&"mouse", start)
	var request: int = _route_between(start, goal, CLASS_TWO)
	assert_false(
		_movement.begin_travel(
			mouse, request, _admission_on(_movement, &"mouse", 0),
			SpatialWorldScript.Contact.new()),
		"an unbound contact refuses")
	assert_equal(
		_movement.last_refusal(), MovementScript.REFUSE_CONTACT_UNBOUND,
		"not the clearance mismatch, even though the route is also the wrong class")


func test_the_clearance_gate_precedes_a_wrong_route_start_too() -> void:
	"""The existing wrong-END case is not the only route/contact relation clearance precedes."""
	var start: int = _cell(ANCHOR_X, ANCHOR_Z)
	var off_start: int = _cell(ANCHOR_X + 1, ANCHOR_Z)
	var goal: int = _cell(ANCHOR_X + 10, ANCHOR_Z)
	var mouse: Vector2i = _spawn_at(&"mouse", off_start)
	var request: int = _route_between(start, goal, CLASS_TWO)
	assert_false(
		_movement.begin_travel(
			mouse, request, _admission_on(_movement, &"mouse", 0),
			_contact_at(goal, DESTINATION_REVISION)),
		"a route that is both the wrong class AND not started from refuses")
	assert_equal(
		_movement.last_refusal(), MovementScript.REFUSE_ROUTE_CLEARANCE,
		"on the clearance channel, which precedes the route-start check too")


func test_the_synthetic_fixture_retains_the_parents_refusal_for_an_invalid_profile_id() -> void:
	"""The fixture overrides only the valid-profile answer; an invalid id still refuses as-is."""
	assert_false(
		_movement.profile_clearance_class_into(-1, _result), "an invalid id refuses on the fixture")
	assert_equal(
		_movement.last_refusal(), MovementScript.REFUSE_PROFILE_ID,
		"exactly the parent's own refusal, not a fixture-specific one")
