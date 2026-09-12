extends "res://test/framework/test_case.gd"
## Coverage for ARCH-SYS-012 ground motion: the retained 30 Hz displacement remainder, the inherited
## per-size speed caps, and READY_07 1.2's speed-equivalence and invisible-view acceptance items.
##
## SCOPE THIS FILE DOES NOT TEST, BECAUSE THE SLICE DOES NOT DO IT: no `RESERVED -> TRAVEL -> WORK`
## transition, no work contact, no reservation lease and no 300/900-tick retry. READY_07 1.2 places
## those after starter profiles, real services and work-unit context, and there is no JobState write
## anywhere in `movement.gd` for a test to assert against.

const SpatialWorldScript := preload("res://scripts/core/spatial_world.gd")
const NavigationScript := preload("res://scripts/core/navigation.gd")
const TransformsScript := preload("res://scripts/core/transforms.gd")
const MovementScript := preload("res://scripts/core/movement.gd")
const EntityDirectoryScript := preload("res://scripts/core/entity_directory.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")
const SimClockScript := preload("res://scripts/core/sim_clock.gd")
const IntMathScript := preload("res://scripts/core/int_math.gd")

## GDD 5.2's inherited caps, read here only to assert that movement uses them unchanged.
const SMALL_CAP_U_PER_S: int = 3277
const LARGE_CAP_U_PER_S: int = 3072

## A macro corner on open land, so no entry segment is prepended to the route under test.
const ANCHOR_X: int = 192
const ANCHOR_Z: int = 288

## A teleport destination with no authored cell under it, and a height that is deliberately NOT the
## water surface's 0, so a fabricated height is distinguishable from the one the owner wrote. These
## are test fixture values, not production movement constants.
const OFF_MAP_UNITS: int = -8192
const OFF_MAP_Y_UNITS: int = 777

## A contact owner's destination revision for the fixtures. The VALUE is the contact owner's; this
## is a test input, not a published movement constant.
const DESTINATION_REVISION: int = 1

static var _shared_world: SpatialWorldScript = null

var _world: SpatialWorldScript = null
var _directory: EntityDirectoryScript = null
var _residents: ResidentsScript = null
var _navigation: NavigationScript = null
var _transforms: TransformsScript = null
var _movement: MovementScript = null
var _result: IntMathScript.IntResult = null
var _pose: TransformsScript.Pose = null


func before_each() -> void:
	"""Build a complete movement stack against the shared read-only ground map."""
	if _shared_world == null:
		_shared_world = SpatialWorldScript.new()
	_build(_shared_world)


func after_each() -> void:
	"""Drop everything but the shared map."""
	_world = null
	_directory = null
	_residents = null
	_navigation = null
	_transforms = null
	_movement = null
	_result = null
	_pose = null


func _build(world: SpatialWorldScript) -> void:
	"""Wire one directory, resident store, navigator, Transform store and mover together."""
	_world = world
	_directory = EntityDirectoryScript.new()
	_residents = ResidentsScript.new(_directory, null)
	_navigation = NavigationScript.new(_directory, world)
	_transforms = TransformsScript.new(_directory)
	_movement = MovementScript.new(_directory, world, _navigation, _transforms, _residents)
	_result = IntMathScript.IntResult.new()
	_pose = TransformsScript.Pose.new()


func _cell(x: int, z: int) -> int:
	"""The cell index of a grid coordinate."""
	return z * SpatialWorldScript.CELLS_X + x


func _spawn_at(species: StringName, cell: int) -> Vector2i:
	"""Spawn one resident and place it on a cell centre; returns its reference."""
	var spawned: Variant = _residents.spawn(species)
	assert_true(spawned.ok, "the resident spawns (error was %s)" % spawned.error)
	var resident: Vector2i = spawned.ref
	_place_on(resident, cell, "the resident is placed on the cell centre")
	return resident


func _spawn_stage_at(species: StringName, stage: int, cell: int) -> Vector2i:
	"""Spawn one resident at an explicit MOVE-DEP-R02 stage and place it; returns its reference."""
	var spawned: Variant = _residents.spawn_with_stage(species, stage)
	assert_true(spawned.ok, "the %s resident spawns (error was %s)" % [
		ResidentsScript.LIFE_STAGE_KEYS[stage], spawned.error])
	var resident: Vector2i = spawned.ref
	_place_on(resident, cell, "the resident is placed on the cell centre")
	return resident


func _place_on(resident: Vector2i, cell: int, message: String) -> void:
	"""Place a resident on a cell centre at the surface layer, asserting the placement took."""
	assert_true(
		_transforms.place(
			resident, SpatialWorldScript.cell_centre_x_units(cell),
			SpatialWorldScript.LAYER_SURFACE, SpatialWorldScript.cell_centre_z_units(cell), 0),
		message)


func _route_between(start_cell: int, goal_cell: int) -> int:
	"""Build one ready route between two owned ground contacts; returns the request row."""
	var job: Vector2i = _directory.create(EntityDirectoryScript.KIND_JOB)
	var start: SpatialWorldScript.Location = SpatialWorldScript.Location.new()
	var goal: SpatialWorldScript.Location = SpatialWorldScript.Location.new()
	assert_true(_world.bind_ground_location(start, start_cell, job), "start binds")
	assert_true(
		_world.bind_ground_location(
			goal, goal_cell, _directory.create(EntityDirectoryScript.KIND_RESOURCE_NODE)),
		"goal binds")
	assert_true(
		_navigation.submit_request_into(job, start, goal, 1, 0, _result),
		"the request is accepted (refusal was %s)" % _navigation.last_refusal())
	var request: int = _result.value
	var tick: int = 0
	while _navigation.is_pending(request) and tick < 64:
		tick += 1
		_navigation.service(tick)
	assert_true(_navigation.is_ready(request), "the route is ready")
	return request


func _admission(species: StringName, mode: int, load_g: int) -> MovementScript.Admission:
	"""Build an admission naming the published starter profile of `species`."""
	var admission: MovementScript.Admission = MovementScript.Admission.new()
	assert_true(
		_movement.profile_for_species_into(species, _result),
		"%s has a published starter profile" % species)
	admission.set_terms(_result.value, MovementScript.LIFE_STAGE_ADULT, mode, load_g)
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


func _begin(resident: Vector2i, request: int, goal_cell: int, species: StringName) -> bool:
	"""Admit `resident` to travel `request` to a freshly bound contact on `goal_cell`."""
	return _movement.begin_travel(
		resident, request, _admission(species, MovementScript.MODE_GROUND_WALK, 0),
		_contact_at(goal_cell, DESTINATION_REVISION))


func _travelling_mouse(goal_cell: int) -> Vector2i:
	"""Spawn a mouse on the macro anchor, route it to `goal_cell`, and start it travelling."""
	var resident: Vector2i = _spawn_at(&"mouse", _cell(ANCHOR_X, ANCHOR_Z))
	var request: int = _route_between(_cell(ANCHOR_X, ANCHOR_Z), goal_cell)
	assert_true(
		_begin(resident, request, goal_cell, &"mouse"),
		"travel begins (refusal was %s)" % _movement.last_refusal())
	return resident


func _x_of(resident: Vector2i) -> int:
	"""The current authoritative X of a placed resident."""
	assert_true(_transforms.read_into(resident, _pose), "the pose reads")
	return _pose.x


# --- the contract's own numbers ------------------------------------------------------------------

func test_the_remainder_denominator_is_thirty_ticks_times_the_diagonal_cost() -> void:
	"""One uniform scale for both segment kinds, so a retained fraction survives a corner."""
	assert_equal(MovementScript.TICKS_PER_SECOND, 30, "30 fixed ticks a second at 1x")
	assert_equal(MovementScript.REMAINDER_DENOMINATOR, 420, "30 ticks times the diagonal cost 14")
	assert_equal(MovementScript.ORTHOGONAL_NUMERATOR_FACTOR, 14, "an orthogonal tick adds speed*14")
	assert_equal(MovementScript.DIAGONAL_NUMERATOR_FACTOR, 10, "a diagonal tick adds speed*10")
	assert_equal(MovementScript.MOTION_CAPACITY, 512, "the motion scratch is 512 rows")


func test_the_speed_cap_is_read_from_the_resident_store_not_redefined() -> void:
	"""GDD 5.2's caps live in `residents.gd`, anomaly and all; movement must not carry its own."""
	var mouse: Vector2i = _spawn_at(&"mouse", _cell(ANCHOR_X, ANCHOR_Z))
	var request: int = _route_between(_cell(ANCHOR_X, ANCHOR_Z), _cell(ANCHOR_X + 20, ANCHOR_Z))
	assert_true(
		_begin(mouse, request, _cell(ANCHOR_X + 20, ANCHOR_Z), &"mouse"), "travel begins")
	assert_equal(_movement.speed_of(mouse), SMALL_CAP_U_PER_S, "a mouse travels at the small cap")
	assert_equal(
		ResidentsScript.SIZE_MOVEMENT_U_PER_S[ResidentsScript.SIZE_SMALL], SMALL_CAP_U_PER_S,
		"and that cap is the one the resident store publishes")
	assert_equal(
		ResidentsScript.SIZE_MOVEMENT_U_PER_S[ResidentsScript.SIZE_LARGE], LARGE_CAP_U_PER_S,
		"including GDD 5.2's deliberate large-is-slower anomaly, copied not corrected")


# --- the retained remainder ------------------------------------------------------------------------

func test_thirty_ticks_cover_exactly_the_cap_on_a_straight_run() -> void:
	"""The whole point of the retained remainder: 3277 u/s means 3277 units in 30 ticks, not 3270."""
	var mouse: Vector2i = _travelling_mouse(_cell(ANCHOR_X + 30, ANCHOR_Z))
	var origin: int = _x_of(mouse)
	for tick: int in 30:
		_movement.advance_tick(tick + 1)
	assert_equal(
		_x_of(mouse) - origin, SMALL_CAP_U_PER_S,
		"one second of ticks covers the cap exactly, across every cell boundary it crossed")
	assert_true(
		_movement.route_index_of(mouse) >= 6, "and it really did cross several cells doing it")


func test_a_single_tick_cannot_cover_the_cap_by_itself() -> void:
	"""3277/30 is not a whole number; a truncating implementation would move 109 and keep 0."""
	var mouse: Vector2i = _travelling_mouse(_cell(ANCHOR_X + 30, ANCHOR_Z))
	var origin: int = _x_of(mouse)
	_movement.advance_tick(1)
	assert_equal(_x_of(mouse) - origin, 109, "the first tick releases the whole units it can")
	assert_equal(
		_movement.remainder_x_of(mouse), 98,
		"and retains 3277*14 - 109*420 = 98 four-hundred-and-twentieths for the next one")


func test_the_remainder_is_carried_rather_than_reset_each_tick() -> void:
	"""Over three seconds the error must stay at zero, not accumulate one truncation per tick."""
	var mouse: Vector2i = _travelling_mouse(_cell(ANCHOR_X + 100, ANCHOR_Z))
	var origin: int = _x_of(mouse)
	for tick: int in 90:
		_movement.advance_tick(tick + 1)
	assert_equal(
		_x_of(mouse) - origin, SMALL_CAP_U_PER_S * 3, "three seconds cover exactly three seconds")
	assert_equal(_movement.remainder_x_of(mouse), 0, "and 90 ticks divide the remainder out cleanly")


func test_an_axis_that_is_not_moving_keeps_its_remainder_untouched() -> void:
	"""No budget is banked from a direction the body never travelled in."""
	var mouse: Vector2i = _travelling_mouse(_cell(ANCHOR_X + 30, ANCHOR_Z))
	for tick: int in 10:
		_movement.advance_tick(tick + 1)
	assert_true(_movement.remainder_x_of(mouse) >= 0, "the travelled axis has a live remainder")
	assert_equal(
		_movement.remainder_z_of(mouse), 0,
		"the stationary axis neither accumulated nor released anything")


func test_travel_stops_exactly_on_the_goal_cell_centre() -> void:
	"""Arrival is exact and terminal: no overshoot, no drift past the last route cell."""
	var goal: int = _cell(ANCHOR_X + 10, ANCHOR_Z)
	var mouse: Vector2i = _travelling_mouse(goal)
	var ticks: int = 0
	while _movement.motion_phase(mouse) == MovementScript.MOTION_TRAVELLING and ticks < 400:
		ticks += 1
		_movement.advance_tick(ticks)
	assert_equal(
		_movement.motion_phase_name(mouse), &"ARRIVED", "it settles as arrived, not as route lost")
	assert_true(_transforms.read_into(mouse, _pose), "its pose reads")
	assert_equal(_pose.x, SpatialWorldScript.cell_centre_x_units(goal), "exactly on the goal centre")
	assert_equal(_pose.z, SpatialWorldScript.cell_centre_z_units(goal), "on both axes")
	assert_equal(_movement.travelling_count(), 0, "and nothing is still travelling")


func test_the_body_keeps_a_previous_pose_every_tick_it_moves() -> void:
	"""ARCH-SYS-001's previous state is written by the mover, not left equal to current."""
	var mouse: Vector2i = _travelling_mouse(_cell(ANCHOR_X + 30, ANCHOR_Z))
	assert_true(_transforms.read_into(mouse, _pose), "before the first tick")
	assert_true(_pose.matches_previous(), "a freshly placed body has no history")
	_movement.advance_tick(1)
	assert_true(_transforms.read_into(mouse, _pose), "after one tick")
	assert_false(_pose.matches_previous(), "now it does")
	assert_equal(_pose.prev_x, SpatialWorldScript.cell_centre_x_units(_cell(ANCHOR_X, ANCHOR_Z)),
		"and previous is the tick-start position exactly")


func test_the_mover_does_not_invent_a_facing() -> void:
	"""Yaw's zero reference and handedness are unstated, so movement carries yaw through untouched."""
	var mouse: Vector2i = _spawn_at(&"mouse", _cell(ANCHOR_X, ANCHOR_Z))
	assert_true(_transforms.set_yaw(mouse, 12345), "the owner sets a facing it understands")
	var request: int = _route_between(_cell(ANCHOR_X, ANCHOR_Z), _cell(ANCHOR_X + 20, ANCHOR_Z + 20))
	assert_true(
		_begin(mouse, request, _cell(ANCHOR_X + 20, ANCHOR_Z + 20), &"mouse"), "travel begins")
	for tick: int in 40:
		_movement.advance_tick(tick + 1)
	assert_true(_transforms.read_into(mouse, _pose), "the pose reads")
	assert_equal(_pose.yaw, 12345, "the mover left the facing exactly as its owner set it")
	assert_equal(_pose.prev_yaw, 12345, "including the previous half")


# --- the authored surface -----------------------------------------------------------------------

func test_crossing_the_ford_takes_the_body_to_the_authored_ford_height() -> void:
	"""GDD 5.1's ford is at y=-128 and land at y=512; the mover reads them rather than assuming."""
	var west: int = _cell(300, 200)
	var east: int = _cell(318, 200)
	assert_true(_world.is_ford_cell(_cell(308, 200)), "the crossing runs over the ford")
	var mouse: Vector2i = _spawn_at(&"mouse", west)
	var request: int = _route_between(west, east)
	assert_true(
		_begin(mouse, request, east, &"mouse"),
		"travel begins (refusal was %s)" % _movement.last_refusal())
	var seen_ford_height: bool = false
	var ticks: int = 0
	while _movement.motion_phase(mouse) == MovementScript.MOTION_TRAVELLING and ticks < 600:
		ticks += 1
		_movement.advance_tick(ticks)
		assert_true(_transforms.read_into(mouse, _pose), "the pose reads")
		if _pose.y == -128:
			seen_ford_height = true
	assert_true(seen_ford_height, "the body descends to the authored ford height while crossing")
	assert_equal(_pose.y, 512, "and is back on navigable land at the far bank")


# --- starting and losing a route --------------------------------------------------------------------

func test_travel_refuses_a_resident_standing_off_the_route_start() -> void:
	"""No silent snap-to-start: a body that is not on its route has not been given its route."""
	var mouse: Vector2i = _spawn_at(&"mouse", _cell(ANCHOR_X + 5, ANCHOR_Z + 5))
	var request: int = _route_between(_cell(ANCHOR_X, ANCHOR_Z), _cell(ANCHOR_X + 20, ANCHOR_Z))
	assert_false(
		_begin(mouse, request, _cell(ANCHOR_X + 20, ANCHOR_Z), &"mouse"), "travel refuses")
	assert_equal(_movement.last_refusal(), MovementScript.REFUSE_ROUTE_START, "refusal is named")
	assert_equal(_movement.motion_phase(mouse), MovementScript.MOTION_IDLE, "it stays idle")


func test_travel_refuses_an_unready_request_and_an_unplaced_body() -> void:
	"""Both preconditions refuse by name rather than starting a body off with nothing to follow."""
	var mouse: Vector2i = _spawn_at(&"mouse", _cell(ANCHOR_X, ANCHOR_Z))
	assert_false(
		_begin(mouse, 0, _cell(ANCHOR_X, ANCHOR_Z), &"mouse"), "an unallocated request refuses")
	assert_equal(
		_movement.last_refusal(), MovementScript.REFUSE_ROUTE_NOT_READY, "refusal is named")
	var unplaced: Variant = _residents.spawn(&"mouse")
	assert_true(unplaced.ok, "a second resident spawns")
	var request: int = _route_between(_cell(ANCHOR_X, ANCHOR_Z), _cell(ANCHOR_X + 20, ANCHOR_Z))
	assert_false(
		_begin(unplaced.ref, request, _cell(ANCHOR_X + 20, ANCHOR_Z), &"mouse"),
		"an unplaced body refuses")
	assert_equal(_movement.last_refusal(), MovementScript.REFUSE_NOT_PLACED, "refusal is named")


func test_travel_refuses_a_reference_that_is_not_a_living_resident() -> void:
	"""Only residents have motion rows; a job or a retired reference refuses by name."""
	var job: Vector2i = _directory.create(EntityDirectoryScript.KIND_JOB)
	assert_false(
		_begin(job, 0, _cell(ANCHOR_X, ANCHOR_Z), &"mouse"), "a job cannot travel")
	assert_equal(_movement.last_refusal(), MovementScript.REFUSE_NOT_RESIDENT, "refusal is named")
	var mouse: Vector2i = _spawn_at(&"mouse", _cell(ANCHOR_X, ANCHOR_Z))
	assert_true(_directory.destroy(mouse), "retire the resident")
	assert_false(
		_begin(mouse, 0, _cell(ANCHOR_X, ANCHOR_Z), &"mouse"),
		"a retired reference cannot travel")
	assert_equal(_movement.last_refusal(), MovementScript.REFUSE_NOT_RESIDENT, "refusal is named")


func test_a_cancelled_route_stops_the_body_where_it_stands() -> void:
	"""Losing the route is its own terminal phase, and the body does not teleport or keep coasting."""
	var mouse: Vector2i = _spawn_at(&"mouse", _cell(ANCHOR_X, ANCHOR_Z))
	var request: int = _route_between(_cell(ANCHOR_X, ANCHOR_Z), _cell(ANCHOR_X + 30, ANCHOR_Z))
	assert_true(
		_begin(mouse, request, _cell(ANCHOR_X + 30, ANCHOR_Z), &"mouse"), "travel begins")
	for tick: int in 10:
		_movement.advance_tick(tick + 1)
	var stopped_at: int = _x_of(mouse)
	assert_true(_navigation.cancel_request(request), "the route is cancelled under it")
	_movement.advance_tick(11)
	assert_equal(
		_movement.motion_phase_name(mouse), &"ROUTE_LOST", "the body reports its route is gone")
	assert_equal(_x_of(mouse), stopped_at, "and it did not move on the tick that discovered it")
	assert_equal(_movement.travelling_count(), 0, "nothing is travelling")


func test_a_successor_in_a_despawned_travellers_row_does_not_inherit_the_route() -> void:
	"""A motion row outlives its occupant; a route must not. The cursor names its owner, not its row.

	`residents.despawn()` does not call `movement.stop()` and nothing else does, so the row is left
	reading TRAVELLING on a still-READY request. With the typed row handed straight back to the next
	spawn, an owner-blind cursor walks the SUCCESSOR along its predecessor's route and keeps the
	travelling count a resident too high for the whole interval.
	"""
	var mouse: Vector2i = _travelling_mouse(_cell(ANCHOR_X + 30, ANCHOR_Z))
	var row: int = _directory.get_typed_row(mouse)
	for tick: int in 5:
		_movement.advance_tick(tick + 1)
	assert_equal(_movement.travelling_count(), 1, "one body is mid-route")
	assert_true(_residents.despawn(mouse).ok, "it despawns, and nobody calls stop()")
	var heir: Variant = _residents.spawn(&"mouse")
	assert_true(heir.ok, "a successor spawns (error was %s)" % heir.error)
	var successor: Vector2i = heir.ref
	assert_equal(_directory.get_typed_row(successor), row, "into the very same typed row")
	var parked: int = _cell(ANCHOR_X, ANCHOR_Z + 40)
	_place_on(successor, parked, "and is placed somewhere of its own")
	var before: int = _transforms.authoritative_digest()
	assert_equal(_movement.advance_tick(6), 0, "no body advances on the next tick")
	assert_equal(
		_transforms.authoritative_digest(), before,
		"the successor is not walked one unit along a route it never asked for")
	assert_equal(
		_x_of(successor), SpatialWorldScript.cell_centre_x_units(parked), "it stands where it was put")
	assert_equal(
		_movement.motion_phase_name(successor), &"ROUTE_LOST", "the row settles on the owner mismatch")
	assert_equal(_movement.travelling_count(), 0, "and the travelling count is not left inflated")


func test_the_route_cursor_records_its_owner_and_releases_it_on_stop() -> void:
	"""The stamp is the owner's never-reused persistent id, NOT a generation two slots both carry.

	The unrelated entity created first is what makes the difference observable: it takes persistent
	id 1, so the traveller's id and its slot generation are different numbers and an implementation
	that stamped the generation cannot pass by coincidence.
	"""
	var earlier: Vector2i = _directory.create(EntityDirectoryScript.KIND_JOB)
	assert_true(earlier.x >= 0, "an unrelated entity takes the first persistent id")
	var mouse: Vector2i = _travelling_mouse(_cell(ANCHOR_X + 30, ANCHOR_Z))
	var owner_id: int = _directory.get_persistent_id(mouse)
	assert_true(owner_id > 0, "a live resident has a persistent id")
	assert_true(owner_id != mouse.y, "which is not its generation -- a fresh slot's is always 1")
	assert_equal(_movement.route_owner_id_of(mouse), owner_id, "the cursor was stamped with it")
	for tick: int in 10:
		_movement.advance_tick(tick + 1)
	assert_equal(
		_movement.motion_phase_name(mouse), &"TRAVELLING",
		"and the owner it names keeps travelling on its own route")
	assert_true(_movement.stop(mouse), "stop it")
	assert_equal(
		_movement.route_owner_id_of(mouse), MovementScript.NO_OWNER_ID,
		"and stopping releases the ownership stamp with the rest of the cursor")


func test_one_clamp_step_publishes_both_scalars_and_leaves_no_stray_budget() -> void:
	"""The refactor's own contract: `_consume_into` writes the new position AND what is left.

	Both outputs are instance scalars rather than a returned pair, because `_advance_row()` runs once
	per travelling resident per tick and CLAUDE.md bans constructing objects there. Exercised
	directly, as `test_needs.gd` exercises `_integrate_step`, because the partial-step branch's
	leftover is not observable from outside: `_spend_budget()` breaks out of its loop the moment an
	axis falls short, so a mutant that banked the spent budget there survives every public path.
	"""
	_movement._consume_into(100, 400, 500)
	assert_equal(_movement._step_position, 400, "a budget past the gap lands exactly on the target")
	assert_equal(_movement._step_budget, 200, "keeping only what the 300-unit segment did not cost")
	_movement._consume_into(100, 400, 30)
	assert_equal(_movement._step_position, 130, "a short budget moves as far as it reaches")
	assert_equal(_movement._step_budget, 0, "and is spent whole -- a partial step banks nothing")
	_movement._consume_into(400, 100, 30)
	assert_equal(_movement._step_position, 370, "the same travelling the other way")
	assert_equal(_movement._step_budget, 0, "and still spent whole")
	_movement._consume_into(400, 400, 55)
	assert_equal(_movement._step_position, 400, "a target already reached does not move")
	assert_equal(_movement._step_budget, 55, "and its whole budget survives for the next segment")


func test_a_body_off_the_authored_map_is_settled_rather_than_given_a_fabricated_height() -> void:
	"""`world_init.gd`'s `WATER_SURFACE_Y_UNITS` is 0, so 0 cannot double as "no height found".

	A failed height lookup that answered 0 would be indistinguishable from standing on open water,
	and `transforms.advance()` would commit it as authoritative state. The lookup refuses instead.
	"""
	var mouse: Vector2i = _travelling_mouse(_cell(ANCHOR_X + 30, ANCHOR_Z))
	_movement.advance_tick(1)
	assert_true(
		_transforms.place(mouse, OFF_MAP_UNITS, OFF_MAP_Y_UNITS, OFF_MAP_UNITS, 0),
		"its owner teleports it clean off the authored map")
	var before: int = _transforms.authoritative_digest()
	assert_equal(_movement.advance_tick(2), 0, "the tick moves nothing")
	assert_equal(
		_movement.motion_phase_name(mouse), &"ROUTE_LOST",
		"a position with no authored height settles the body instead of inventing one")
	assert_equal(
		_transforms.authoritative_digest(), before,
		"and no height -- least of all the water surface's 0 -- is committed for it")
	assert_true(_transforms.read_into(mouse, _pose), "its pose still reads")
	assert_equal(_pose.y, OFF_MAP_Y_UNITS, "at exactly the height its owner set, not a fabricated 0")
	assert_equal(_pose.x, OFF_MAP_UNITS, "and it did not creep toward its abandoned route")


func test_stopping_clears_the_route_and_both_remainders() -> void:
	"""An explicit stop returns the row to idle without leaving a half-spent fraction behind."""
	var mouse: Vector2i = _travelling_mouse(_cell(ANCHOR_X + 30, ANCHOR_Z))
	_movement.advance_tick(1)
	assert_true(_movement.remainder_x_of(mouse) > 0, "a fraction is retained mid-route")
	assert_true(_movement.stop(mouse), "stop it")
	assert_equal(_movement.motion_phase(mouse), MovementScript.MOTION_IDLE, "it is idle")
	assert_equal(_movement.remainder_x_of(mouse), 0, "the X remainder is cleared")
	assert_equal(_movement.remainder_z_of(mouse), 0, "and so is Z")
	assert_equal(_movement.route_index_of(mouse), 0, "with the route cursor reset")


func test_an_arrived_body_is_not_advanced_again() -> void:
	"""Once settled, further ticks are a no-op rather than a slow drift past the goal."""
	var goal: int = _cell(ANCHOR_X + 4, ANCHOR_Z)
	var mouse: Vector2i = _travelling_mouse(goal)
	var ticks: int = 0
	while _movement.motion_phase(mouse) == MovementScript.MOTION_TRAVELLING and ticks < 200:
		ticks += 1
		_movement.advance_tick(ticks)
	var settled: int = _x_of(mouse)
	for extra: int in 30:
		assert_equal(_movement.advance_tick(ticks + extra + 1), 0, "no body moves")
	assert_equal(_x_of(mouse), settled, "and the arrived body has not moved a unit")


# --- READY_07 1.2 acceptance: speed equivalence and invisible views --------------------------------

func test_equal_tick_counts_agree_across_speeds_one_two_and_four() -> void:
	"""Game speed changes how OFTEN a tick runs, never what one tick does.

	Each run is driven through the real `sim_clock.gd` at its own requested speed until it has
	drained exactly 90 ticks, and the whole authoritative Transform store is then digested. A speed
	that leaked into the integration -- scaling a step by the multiplier, say -- separates these.
	"""
	var digests: Array[int] = []
	for speed: int in [SimClockScript.SPEED_NORMAL, SimClockScript.SPEED_DOUBLE,
			SimClockScript.SPEED_QUADRUPLE]:
		digests.append(_digest_after_ticks_at_speed(speed, 90))
	assert_equal(digests[1], digests[0], "2x reaches the identical state at equal ticks")
	assert_equal(digests[2], digests[0], "and so does 4x")
	assert_true(digests[0] != 0, "and the runs actually moved something")


func test_a_paused_clock_runs_no_ticks_and_changes_no_state() -> void:
	"""Speed 0 is the fourth member of `0/1/2/4`: real time passes, the simulation does not."""
	var mouse: Vector2i = _travelling_mouse(_cell(ANCHOR_X + 30, ANCHOR_Z))
	var clock: SimClockScript = SimClockScript.new()
	var before: int = _transforms.authoritative_digest()
	var before_x: int = _x_of(mouse)
	var ticks: int = 0
	for frame: int in 120:
		ticks += clock.advance(33334, func() -> void: _movement.advance_tick(ticks + 1))
	assert_equal(ticks, 0, "a paused clock drains no ticks")
	assert_equal(
		_transforms.authoritative_digest(), before, "and the authoritative state is untouched")
	assert_equal(_x_of(mouse), before_x, "the body is exactly where it was")


func _digest_after_ticks_at_speed(speed: int, wanted: int) -> int:
	"""Run one whole movement stack through the real clock at `speed` for exactly `wanted` ticks."""
	_build(_shared_world)
	var mouse: Vector2i = _travelling_mouse(_cell(ANCHOR_X + 60, ANCHOR_Z + 30))
	var clock: SimClockScript = SimClockScript.new()
	assert_true(clock.set_pause(SimClockScript.PLAYER, false), "the clock starts running")
	assert_true(clock.set_speed(speed), "at the requested speed")
	var ticks: int = 0
	var frames: int = 0
	while ticks < wanted and frames < 20000:
		frames += 1
		if clock.advance(1000, func() -> void: _movement.advance_tick(ticks + 1)) > 0:
			ticks += 1
	assert_equal(ticks, wanted, "the run drained exactly the ticks asked of it")
	assert_true(mouse.x >= 0, "the body under test is real")
	return _transforms.authoritative_digest()


func test_presentation_reads_cannot_change_what_the_simulation_committed() -> void:
	"""Invisible-view independence: drawing, or not drawing, must not alter one authoritative field.

	Two identical runs. One is observed every tick at nine sub-tick alphas; the other is never
	observed at all. Their whole Transform stores must digest identically.
	"""
	var observed: int = _digest_after_ticks(60, true)
	var unobserved: int = _digest_after_ticks(60, false)
	assert_equal(observed, unobserved, "an observed run commits exactly what an unobserved one does")
	assert_true(observed != 0, "and both runs actually moved a body")


func test_navigation_work_is_identical_whether_or_not_anyone_is_watching() -> void:
	"""The same independence at the routing layer: quota spent must not depend on a view."""
	_digest_after_ticks(40, true)
	var watched: int = _navigation.total_expansions()
	_digest_after_ticks(40, false)
	assert_equal(
		_navigation.total_expansions(), watched,
		"the navigator finalized exactly the same number of cells either way")


func _digest_after_ticks(count: int, observe: bool) -> int:
	"""Run one stack for `count` ticks, optionally reading the presentation pose every tick."""
	_build(_shared_world)
	var view: TransformsScript.PresentationPose = TransformsScript.PresentationPose.new()
	var mouse: Vector2i = _travelling_mouse(_cell(ANCHOR_X + 60, ANCHOR_Z + 30))
	for tick: int in count:
		_movement.advance_tick(tick + 1)
		if not observe:
			continue
		for alpha: int in 9:
			assert_true(
				_transforms.presentation_interpolate_into(mouse, alpha, 8, view),
				"the view reads at every sub-tick alpha")
	return _transforms.authoritative_digest()


# --- the starter ground profile manifest, 2026-09-11 movement ruling -------------------------------

func test_exactly_four_starter_profiles_are_published_one_per_cohort_species() -> void:
	"""GDD 5.1's cohort is 6 mice, 2 moles, 2 otters, 2 squirrels. No synthetic fifth species."""
	assert_equal(MovementScript.PROFILE_COUNT, 4, "four starter profiles")
	assert_equal(
		MovementScript.PROFILE_SPECIES_KEYS,
		([&"mouse", &"mole", &"otter", &"squirrel"] as Array[StringName]),
		"in the cohort sentence's own order")
	assert_equal(
		MovementScript.PROFILE_KEYS[0], &"starter.ground.adult.mouse", "stable ASCII profile keys")
	for profile: int in MovementScript.PROFILE_COUNT:
		assert_true(_movement.is_profile(profile), "profile %d is published" % profile)
		assert_equal(
			_movement.profile_revision_of(profile), MovementScript.PROFILE_FIRST_REVISION,
			"at its first revision")
		assert_equal(
			_movement.profile_key_of(profile), MovementScript.PROFILE_KEYS[profile],
			"under its own key")
	assert_false(_movement.is_profile(MovementScript.PROFILE_COUNT), "and there is no fifth")


func test_every_profile_reads_its_speed_and_carry_cap_out_of_the_resident_store() -> void:
	"""The audit is executed, not transcribed: a literal here could drift from GDD 5.2 unnoticed."""
	for profile: int in MovementScript.PROFILE_COUNT:
		assert_true(_movement.profile_size_class_into(profile, _result), "the size class reads")
		var size: int = _result.value
		assert_true(_movement.profile_speed_into(profile, _result), "the speed reads")
		assert_equal(
			_result.value, ResidentsScript.SIZE_MOVEMENT_U_PER_S[size],
			"%s travels at the store's cap for its size" % MovementScript.PROFILE_KEYS[profile])
		assert_true(_movement.profile_carry_capacity_into(profile, _result), "the carry cap reads")
		assert_equal(
			_result.value, ResidentsScript.SIZE_CARRY_G[size],
			"and carries the store's capacity for its size")


func test_the_otter_is_medium_and_the_other_three_are_small() -> void:
	"""The inherited size binding, asserted against `residents.gd`'s own species split."""
	var expected: Dictionary = {
		&"mouse": ResidentsScript.SIZE_SMALL, &"mole": ResidentsScript.SIZE_SMALL,
		&"squirrel": ResidentsScript.SIZE_SMALL, &"otter": ResidentsScript.SIZE_MEDIUM,
	}
	for species: StringName in expected:
		assert_true(_movement.profile_for_species_into(species, _result), "%s resolves" % species)
		var profile: int = _result.value
		assert_true(_movement.profile_size_class_into(profile, _result), "its size class reads")
		assert_equal(_result.value, int(expected[species]), "%s inherits its size class" % species)


func test_an_unprofiled_species_refuses_rather_than_borrowing_a_size_neighbour() -> void:
	"""A size class is not a traversal profile; twelve release-1 species have no starter profile."""
	for species: StringName in [&"shrew", &"rat", &"sparrow", &"hare", &"badger", &"wolverine"]:
		assert_false(
			_movement.profile_for_species_into(species, _result),
			"%s has no starter profile" % species)
		assert_equal(
			_movement.last_refusal(), MovementScript.REFUSE_PROFILE_SPECIES, "refusal is named")
	assert_true(
		_residents.has_species(&"shrew"), "and the store really does compile those species")


func test_no_profile_publishes_a_clearance_class() -> void:
	"""The gap is a refusal a caller must handle, not a field nobody notices is missing."""
	for profile: int in MovementScript.PROFILE_COUNT:
		assert_false(
			_movement.profile_clearance_class_into(profile, _result),
			"%s publishes no clearance" % MovementScript.PROFILE_KEYS[profile])
		assert_equal(
			_movement.last_refusal(), MovementScript.REFUSE_PROFILE_CLEARANCE, "refusal is named")
	assert_false(
		_movement.profile_clearance_class_into(-1, _result), "and a bad id refuses differently")
	assert_equal(_movement.last_refusal(), MovementScript.REFUSE_PROFILE_ID, "by its own name")


func test_only_ground_and_ford_walking_are_profiled_and_the_rest_are_enumerated() -> void:
	"""Swimming, diving, climbing and tunnels stay in release scope and refuse in this increment."""
	assert_equal(MovementScript.MODE_COUNT, 6, "all six adopted modes are enumerated")
	for profile: int in MovementScript.PROFILE_COUNT:
		assert_true(
			_movement.profile_permits_mode(profile, MovementScript.MODE_GROUND_WALK),
			"ground walking is profiled")
		assert_true(
			_movement.profile_permits_mode(profile, MovementScript.MODE_FORD_WALK),
			"ford walking is profiled")
		for mode: int in [
			MovementScript.MODE_SWIM_SURFACE, MovementScript.MODE_DIVE,
			MovementScript.MODE_CLIMB, MovementScript.MODE_TUNNEL_WALK,
		]:
			assert_false(
				_movement.profile_permits_mode(profile, mode),
				"%s is not profiled here" % MovementScript.MODE_NAMES[mode])


func test_all_twelve_starters_admit_travel_under_their_own_profile() -> void:
	"""Every member of the initial cohort, by species, travels on the profile that covers it."""
	var admitted: int = 0
	for index: int in ResidentsScript.INITIAL_POPULATION:
		var species: StringName = ResidentsScript.INITIAL_SPECIES[index]
		var start: int = _cell(ANCHOR_X, ANCHOR_Z + index)
		var goal: int = _cell(ANCHOR_X + 12, ANCHOR_Z + index)
		var resident: Vector2i = _spawn_at(species, start)
		assert_true(
			_begin(resident, _route_between(start, goal), goal, species),
			"%s travels (refusal was %s)" % [species, _movement.last_refusal()])
		assert_true(_movement.profile_for_species_into(species, _result), "its profile resolves")
		assert_equal(
			_movement.admitted_profile_of(resident), _result.value,
			"and the cursor records the profile it was admitted under")
		admitted += 1
	assert_equal(admitted, 12, "all twelve starters were admitted")
	assert_equal(_movement.travelling_count(), 12, "and all twelve are mid-route")


func test_a_mouse_cannot_travel_on_the_otters_profile() -> void:
	"""Admission checks the species the profile covers, not merely that a profile id is valid."""
	var mouse: Vector2i = _spawn_at(&"mouse", _cell(ANCHOR_X, ANCHOR_Z))
	var goal: int = _cell(ANCHOR_X + 20, ANCHOR_Z)
	var request: int = _route_between(_cell(ANCHOR_X, ANCHOR_Z), goal)
	assert_false(_begin(mouse, request, goal, &"otter"), "the wrong profile refuses")
	assert_equal(
		_movement.last_refusal(), MovementScript.REFUSE_PROFILE_SPECIES, "refusal is named")
	assert_equal(_movement.motion_phase(mouse), MovementScript.MOTION_IDLE, "it stays idle")


func test_travel_refuses_an_unprofiled_mode_and_a_mode_outside_the_enum() -> void:
	"""An unsupported mode is an explicit refusal, never a silent fall back to ground walking."""
	var mouse: Vector2i = _spawn_at(&"mouse", _cell(ANCHOR_X, ANCHOR_Z))
	var goal: int = _cell(ANCHOR_X + 20, ANCHOR_Z)
	var request: int = _route_between(_cell(ANCHOR_X, ANCHOR_Z), goal)
	assert_false(
		_movement.begin_travel(
			mouse, request, _admission(&"mouse", MovementScript.MODE_DIVE, 0),
			_contact_at(goal, DESTINATION_REVISION)),
		"a dive refuses")
	assert_equal(
		_movement.last_refusal(), MovementScript.REFUSE_MODE_UNPROFILED, "refusal is named")
	assert_false(
		_movement.begin_travel(
			mouse, request, _admission(&"mouse", MovementScript.MODE_COUNT, 0),
			_contact_at(goal, DESTINATION_REVISION)),
		"a mode outside the enum refuses")
	assert_equal(_movement.last_refusal(), MovementScript.REFUSE_MODE_RANGE, "by its own name")


# --- MOVE-DEP-R02: the resident's STORED stage decides, not the caller's copy --------------------
#
# The old test here asserted only that `admission.life_stage != ADULT` refuses, which a caller that
# asserted ADULT for a child passed. It is REPLACED, not removed: every case it covered is still
# covered below, by `test_a_caller_that_asserts_the_wrong_stage_for_an_adult_disagrees`, and the
# refusal it expected moved because the behaviour it tested was the defect. Decision 0101.

func test_the_profiled_adult_value_is_the_resident_stores_own_encoding() -> void:
	"""One encoding, aliased -- not 0 written twice, which a renumber in the store would split."""
	assert_equal(
		MovementScript.LIFE_STAGE_ADULT, ResidentsScript.LIFE_STAGE_ADULT,
		"movement's profiled adult IS the resident store's ADULT")
	assert_equal(ResidentsScript.LIFE_STAGE_COUNT, 3, "and the store's domain is the full three")


func test_every_starter_profile_covers_the_adult_stage_and_says_so_in_its_key() -> void:
	"""MOVE-DEP-R02's `_profile_life_stage`, all ADULT, one entry per published profile."""
	assert_equal(
		MovementScript.PROFILE_LIFE_STAGE.size(), MovementScript.PROFILE_COUNT,
		"one stage binding per profile")
	for profile: int in MovementScript.PROFILE_COUNT:
		assert_true(_movement.profile_life_stage_into(profile, _result), "its stage reads")
		assert_equal(
			_result.value, ResidentsScript.LIFE_STAGE_ADULT,
			"%s covers ADULT" % MovementScript.PROFILE_KEYS[profile])
		assert_true(
			String(MovementScript.PROFILE_KEYS[profile]).contains(
				String(ResidentsScript.LIFE_STAGE_KEYS[_result.value]).to_lower()),
			"and its key spells the stage it binds")
	assert_false(
		_movement.profile_life_stage_into(MovementScript.PROFILE_COUNT, _result),
		"an unpublished id refuses rather than answering ADULT")
	assert_equal(_movement.last_refusal(), MovementScript.REFUSE_PROFILE_ID, "by its own name")


func test_a_caller_cannot_assert_adult_for_a_resident_stored_as_a_child() -> void:
	"""THE DEFECT MOVE-DEP-R02 NAMES: "a caller value cannot override" the stored stage.

	Before this fix the admission believed the caller, so a child travelled under adult profile
	coefficients whenever the caller said ADULT -- which is what every existing caller says.
	"""
	var child: Vector2i = _spawn_stage_at(
		&"mouse", ResidentsScript.LIFE_STAGE_CHILD, _cell(ANCHOR_X, ANCHOR_Z))
	assert_equal(
		_residents.life_stage_of_ref(child).value, ResidentsScript.LIFE_STAGE_CHILD,
		"the store really holds CHILD")
	var goal: int = _cell(ANCHOR_X + 20, ANCHOR_Z)
	var request: int = _route_between(_cell(ANCHOR_X, ANCHOR_Z), goal)
	var admission: MovementScript.Admission = _admission(
		&"mouse", MovementScript.MODE_GROUND_WALK, 0)
	assert_equal(admission.life_stage, MovementScript.LIFE_STAGE_ADULT, "the caller asserts ADULT")
	assert_false(
		_movement.begin_travel(child, request, admission, _contact_at(goal, DESTINATION_REVISION)),
		"and is not believed")
	assert_equal(
		_movement.last_refusal(), MovementScript.REFUSE_LIFE_STAGE_MISMATCH, "refusal is named")
	assert_equal(_movement.motion_phase(child), MovementScript.MOTION_IDLE, "it stays idle")
	assert_equal(_movement.travelling_count(), 0, "and nothing is mid-route")


func test_an_honestly_declared_child_refuses_as_unprofiled_not_as_a_mismatch() -> void:
	"""A caller that tells the truth about a child meets a MISSING PROFILE, a different problem.

	Two bugs, two codes: this one belongs to PC-04, which owns dependent needs, care, schedule and
	hazard rules. Collapsing it into the mismatch code would send its reporter to the wrong owner.
	"""
	var child: Vector2i = _spawn_stage_at(
		&"mouse", ResidentsScript.LIFE_STAGE_CHILD, _cell(ANCHOR_X, ANCHOR_Z))
	var goal: int = _cell(ANCHOR_X + 20, ANCHOR_Z)
	var request: int = _route_between(_cell(ANCHOR_X, ANCHOR_Z), goal)
	var admission: MovementScript.Admission = _admission(
		&"mouse", MovementScript.MODE_GROUND_WALK, 0)
	admission.life_stage = ResidentsScript.LIFE_STAGE_CHILD
	assert_false(
		_movement.begin_travel(child, request, admission, _contact_at(goal, DESTINATION_REVISION)),
		"a truthfully declared child still refuses")
	assert_equal(_movement.last_refusal(), MovementScript.REFUSE_LIFE_STAGE, "refusal is named")
	assert_equal(_movement.motion_phase(child), MovementScript.MOTION_IDLE, "it stays idle")


func test_an_elder_is_refused_on_the_same_channel_as_a_child() -> void:
	"""ELDER is a stored stage too, and no starter profile covers it either."""
	var elder: Vector2i = _spawn_stage_at(
		&"otter", ResidentsScript.LIFE_STAGE_ELDER, _cell(ANCHOR_X, ANCHOR_Z))
	var goal: int = _cell(ANCHOR_X + 20, ANCHOR_Z)
	var request: int = _route_between(_cell(ANCHOR_X, ANCHOR_Z), goal)
	var admission: MovementScript.Admission = _admission(
		&"otter", MovementScript.MODE_GROUND_WALK, 0)
	admission.life_stage = ResidentsScript.LIFE_STAGE_ELDER
	assert_false(
		_movement.begin_travel(elder, request, admission, _contact_at(goal, DESTINATION_REVISION)),
		"an elder refuses")
	assert_equal(_movement.last_refusal(), MovementScript.REFUSE_LIFE_STAGE, "refusal is named")
	assert_equal(_movement.travelling_count(), 0, "and it is not mid-route")


func test_a_caller_that_asserts_the_wrong_stage_for_an_adult_disagrees() -> void:
	"""The old assertion's case, kept: a non-adult caller value on an adult row still refuses.

	It refuses as a MISMATCH now rather than as an unprofiled stage, because the resident really is
	an adult and the only thing wrong is what the caller said about it.
	"""
	var mouse: Vector2i = _spawn_at(&"mouse", _cell(ANCHOR_X, ANCHOR_Z))
	var goal: int = _cell(ANCHOR_X + 20, ANCHOR_Z)
	var request: int = _route_between(_cell(ANCHOR_X, ANCHOR_Z), goal)
	for asserted: int in [ResidentsScript.LIFE_STAGE_CHILD, ResidentsScript.LIFE_STAGE_ELDER]:
		var admission: MovementScript.Admission = _admission(
			&"mouse", MovementScript.MODE_GROUND_WALK, 0)
		admission.life_stage = asserted
		assert_false(
			_movement.begin_travel(
				mouse, request, admission, _contact_at(goal, DESTINATION_REVISION)),
			"asserting %s for an adult refuses" % ResidentsScript.LIFE_STAGE_KEYS[asserted])
		assert_equal(
			_movement.last_refusal(), MovementScript.REFUSE_LIFE_STAGE_MISMATCH, "refusal is named")


func test_a_stage_outside_the_domain_refuses_on_its_own_channel() -> void:
	"""COUNT is a bound and a cleared `Admission` holds -1; neither is clamped to ADULT."""
	var mouse: Vector2i = _spawn_at(&"mouse", _cell(ANCHOR_X, ANCHOR_Z))
	var goal: int = _cell(ANCHOR_X + 20, ANCHOR_Z)
	var request: int = _route_between(_cell(ANCHOR_X, ANCHOR_Z), goal)
	for asserted: int in [-1, ResidentsScript.LIFE_STAGE_COUNT, 256]:
		var admission: MovementScript.Admission = _admission(
			&"mouse", MovementScript.MODE_GROUND_WALK, 0)
		admission.life_stage = asserted
		assert_false(
			_movement.begin_travel(
				mouse, request, admission, _contact_at(goal, DESTINATION_REVISION)),
			"stage %d is not in the domain" % asserted)
		assert_equal(
			_movement.last_refusal(), MovementScript.REFUSE_LIFE_STAGE_RANGE, "refusal is named")
	assert_equal(_movement.motion_phase(mouse), MovementScript.MOTION_IDLE, "it stays idle")


func test_a_reference_the_store_will_not_answer_for_refuses_rather_than_defaulting() -> void:
	"""An unreadable stage REFUSES. `IntResult.refuse()` zeroes its value, and zero is ADULT.

	A directory reference of the right kind whose resident row was never written is exactly that
	case: valid to `_motion_row()`, absent to `residents.gd`. Reading `.value` without checking
	`.ok` would admit it as an adult -- the sentinel-shaped bug this codebase has been bitten by.
	"""
	var orphan: Vector2i = _directory.create(EntityDirectoryScript.KIND_RESIDENT)
	assert_true(
		_directory.is_valid_of_kind(orphan, EntityDirectoryScript.KIND_RESIDENT),
		"the directory validates the reference")
	assert_false(_residents.life_stage_of_ref(orphan).ok, "but the store holds no row for it")
	var goal: int = _cell(ANCHOR_X + 20, ANCHOR_Z)
	var request: int = _route_between(_cell(ANCHOR_X, ANCHOR_Z), goal)
	_place_on(orphan, _cell(ANCHOR_X, ANCHOR_Z), "it is placed on the route start")
	assert_false(
		_movement.begin_travel(
			orphan, request, _admission(&"mouse", MovementScript.MODE_GROUND_WALK, 0),
			_contact_at(goal, DESTINATION_REVISION)),
		"admission refuses it")
	assert_equal(
		_movement.last_refusal(), MovementScript.REFUSE_LIFE_STAGE_UNREADABLE, "refusal is named")
	assert_equal(_movement.travelling_count(), 0, "and nothing is mid-route")


# --- the committed load boundary, GDD 5.2 carry capacities ----------------------------------------

func test_the_committed_load_boundary_is_the_inherited_carry_capacity_exactly() -> void:
	"""12000 g admits a mouse, 12001 g does not. The boundary is the store's, not a new number."""
	var goal: int = _cell(ANCHOR_X + 20, ANCHOR_Z)
	var at_cap: Vector2i = _spawn_at(&"mouse", _cell(ANCHOR_X, ANCHOR_Z))
	var contact: SpatialWorldScript.Contact = _contact_at(goal, DESTINATION_REVISION)
	assert_true(
		_movement.begin_travel(
			at_cap, _route_between(_cell(ANCHOR_X, ANCHOR_Z), goal),
			_admission(&"mouse", MovementScript.MODE_GROUND_WALK, 12000), contact),
		"a mouse carrying exactly its capacity travels")
	assert_equal(
		_movement.admitted_load_g_of(at_cap),
		ResidentsScript.SIZE_CARRY_G[ResidentsScript.SIZE_SMALL],
		"and the cursor records the committed load")
	var over: Vector2i = _spawn_at(&"mouse", _cell(ANCHOR_X, ANCHOR_Z + 1))
	assert_false(
		_movement.begin_travel(
			over, _route_between(_cell(ANCHOR_X, ANCHOR_Z + 1), goal),
			_admission(&"mouse", MovementScript.MODE_GROUND_WALK, 12001), contact),
		"one gram over refuses")
	assert_equal(_movement.last_refusal(), MovementScript.REFUSE_LOAD_CAPACITY, "refusal is named")


func test_a_negative_committed_load_refuses_rather_than_reading_as_free_capacity() -> void:
	"""A negative load would pass a bare `> capacity` test and is its own named refusal."""
	var mouse: Vector2i = _spawn_at(&"mouse", _cell(ANCHOR_X, ANCHOR_Z))
	var goal: int = _cell(ANCHOR_X + 20, ANCHOR_Z)
	assert_false(
		_movement.begin_travel(
			mouse, _route_between(_cell(ANCHOR_X, ANCHOR_Z), goal),
			_admission(&"mouse", MovementScript.MODE_GROUND_WALK, -1),
			_contact_at(goal, DESTINATION_REVISION)),
		"a negative load refuses")
	assert_equal(_movement.last_refusal(), MovementScript.REFUSE_LOAD_NEGATIVE, "refusal is named")


func test_an_otter_carries_more_than_a_mouse_because_its_size_class_does() -> void:
	"""16000 g is the medium capacity; a load a mouse refuses is legal for an otter."""
	var otter: Vector2i = _spawn_at(&"otter", _cell(ANCHOR_X, ANCHOR_Z))
	var goal: int = _cell(ANCHOR_X + 20, ANCHOR_Z)
	assert_true(
		_movement.begin_travel(
			otter, _route_between(_cell(ANCHOR_X, ANCHOR_Z), goal),
			_admission(&"otter", MovementScript.MODE_GROUND_WALK, 16000),
			_contact_at(goal, DESTINATION_REVISION)),
		"an otter carries the medium capacity (refusal was %s)" % _movement.last_refusal())
	assert_equal(
		ResidentsScript.SIZE_CARRY_G[ResidentsScript.SIZE_MEDIUM], 16000,
		"and that capacity is the resident store's own")


# --- exact contacts --------------------------------------------------------------------------------

func test_travel_refuses_a_route_that_does_not_end_on_the_contacts_approach_cell() -> void:
	"""Arrival must be the exact contact. A route stopping nearby has not reached the destination."""
	var mouse: Vector2i = _spawn_at(&"mouse", _cell(ANCHOR_X, ANCHOR_Z))
	var goal: int = _cell(ANCHOR_X + 20, ANCHOR_Z)
	var request: int = _route_between(_cell(ANCHOR_X, ANCHOR_Z), goal)
	assert_false(
		_movement.begin_travel(
			mouse, request, _admission(&"mouse", MovementScript.MODE_GROUND_WALK, 0),
			_contact_at(_cell(ANCHOR_X + 21, ANCHOR_Z), DESTINATION_REVISION)),
		"a contact one cell past the route's end refuses")
	assert_equal(_movement.last_refusal(), MovementScript.REFUSE_ROUTE_CONTACT, "refusal is named")


func test_travel_refuses_a_contact_whose_owner_has_been_retired() -> void:
	"""An empty building is not a valid target, and neither is a destroyed one."""
	var mouse: Vector2i = _spawn_at(&"mouse", _cell(ANCHOR_X, ANCHOR_Z))
	var goal: int = _cell(ANCHOR_X + 20, ANCHOR_Z)
	var request: int = _route_between(_cell(ANCHOR_X, ANCHOR_Z), goal)
	var contact: SpatialWorldScript.Contact = _contact_at(goal, DESTINATION_REVISION)
	assert_true(_directory.destroy(contact.owner_ref()), "the destination is retired")
	assert_false(
		_movement.begin_travel(
			mouse, request, _admission(&"mouse", MovementScript.MODE_GROUND_WALK, 0), contact),
		"travel to a retired owner refuses")
	assert_equal(_movement.last_refusal(), MovementScript.REFUSE_CONTACT_OWNER, "refusal is named")


func test_travel_refuses_an_unbound_contact() -> void:
	"""A contact record that was never filled names no destination at all."""
	var mouse: Vector2i = _spawn_at(&"mouse", _cell(ANCHOR_X, ANCHOR_Z))
	var goal: int = _cell(ANCHOR_X + 20, ANCHOR_Z)
	var request: int = _route_between(_cell(ANCHOR_X, ANCHOR_Z), goal)
	assert_false(
		_movement.begin_travel(
			mouse, request, _admission(&"mouse", MovementScript.MODE_GROUND_WALK, 0),
			SpatialWorldScript.Contact.new()),
		"an unbound contact refuses")
	assert_equal(
		_movement.last_refusal(), MovementScript.REFUSE_CONTACT_UNBOUND, "refusal is named")


# --- stale profile and contact revisions ------------------------------------------------------------

func test_revising_a_profile_settles_a_body_already_travelling_under_the_old_one() -> void:
	"""MOVE-REQ-006: a changed profile revision revalidates the journey rather than continuing it."""
	var mouse: Vector2i = _travelling_mouse(_cell(ANCHOR_X + 30, ANCHOR_Z))
	for tick: int in 5:
		_movement.advance_tick(tick + 1)
	var stopped_at: int = _x_of(mouse)
	assert_equal(
		_movement.admitted_profile_revision_of(mouse), MovementScript.PROFILE_FIRST_REVISION,
		"it was admitted at the first revision")
	assert_true(
		_movement.revise_profile(_movement.admitted_profile_of(mouse)), "the profile revises")
	_movement.advance_tick(6)
	assert_equal(
		_movement.motion_phase_name(mouse), &"PROFILE_STALE",
		"the body reports its admitted profile is gone")
	assert_equal(_x_of(mouse), stopped_at, "and it did not move on the tick that discovered it")
	assert_equal(_movement.travelling_count(), 0, "nothing is travelling")


func test_a_changed_destination_revision_settles_the_body_contact_stale() -> void:
	"""The contact owner re-presents its revision; a mismatch stops the journey by its own name."""
	var mouse: Vector2i = _travelling_mouse(_cell(ANCHOR_X + 30, ANCHOR_Z))
	for tick: int in 5:
		_movement.advance_tick(tick + 1)
	assert_equal(
		_movement.admitted_destination_revision_of(mouse), DESTINATION_REVISION,
		"the admitted revision is recorded")
	assert_true(
		_movement.revalidate_destination(mouse, DESTINATION_REVISION),
		"the unchanged revision revalidates")
	assert_equal(
		_movement.motion_phase(mouse), MovementScript.MOTION_TRAVELLING, "and it keeps travelling")
	assert_true(
		_movement.revalidate_destination(mouse, DESTINATION_REVISION + 1),
		"the changed revision revalidates too")
	assert_equal(
		_movement.motion_phase_name(mouse), &"CONTACT_STALE", "but settles the body this time")
	assert_equal(_movement.travelling_count(), 0, "nothing is travelling")


func test_revalidating_a_resident_that_is_not_travelling_refuses() -> void:
	"""There is no journey to invalidate, and saying so is not the same as saying nothing changed."""
	var mouse: Vector2i = _spawn_at(&"mouse", _cell(ANCHOR_X, ANCHOR_Z))
	assert_false(_movement.revalidate_destination(mouse, DESTINATION_REVISION), "it refuses")
	assert_equal(
		_movement.last_refusal(), MovementScript.REFUSE_NOT_TRAVELLING, "refusal is named")


func test_stopping_clears_the_whole_admission_not_only_the_route() -> void:
	"""A cleared row must not leave a profile, mode, load or destination revision behind."""
	var mouse: Vector2i = _travelling_mouse(_cell(ANCHOR_X + 30, ANCHOR_Z))
	assert_true(_movement.admitted_profile_of(mouse) >= 0, "it was admitted under a profile")
	assert_true(_movement.stop(mouse), "it stops")
	assert_equal(
		_movement.admitted_profile_of(mouse), MovementScript.NO_PROFILE, "no profile remains")
	assert_equal(_movement.admitted_mode_of(mouse), MovementScript.NO_MODE, "no mode remains")
	assert_equal(_movement.admitted_load_g_of(mouse), 0, "no committed load remains")
	assert_equal(
		_movement.admitted_destination_revision_of(mouse), 0, "no destination revision remains")


func test_admitted_terms_of_a_body_that_is_not_a_resident_read_as_absent() -> void:
	"""Every admission reader answers for a reference that has no motion row at all."""
	var job: Vector2i = _directory.create(EntityDirectoryScript.KIND_JOB)
	assert_equal(_movement.admitted_profile_of(job), MovementScript.NO_PROFILE, "no profile")
	assert_equal(_movement.admitted_mode_of(job), MovementScript.NO_MODE, "no mode")
	assert_equal(_movement.admitted_load_g_of(job), 0, "no load")
	assert_equal(_movement.admitted_destination_revision_of(job), 0, "no destination revision")
	assert_equal(_movement.admitted_profile_revision_of(job), 0, "no profile revision")


func test_the_mode_a_body_travels_in_is_the_one_it_was_admitted_in() -> void:
	"""Ford walking is a distinct admitted mode, and the cursor keeps it rather than normalising."""
	var west: int = _cell(300, 200)
	var east: int = _cell(318, 200)
	var mouse: Vector2i = _spawn_at(&"mouse", west)
	assert_true(
		_movement.begin_travel(
			mouse, _route_between(west, east),
			_admission(&"mouse", MovementScript.MODE_FORD_WALK, 0),
			_contact_at(east, DESTINATION_REVISION)),
		"ford walking is admitted (refusal was %s)" % _movement.last_refusal())
	assert_equal(
		_movement.admitted_mode_of(mouse), MovementScript.MODE_FORD_WALK, "and it is retained")
	assert_true(_world.is_ford_cell(_cell(308, 200)), "the route really does cross the ford")


func test_all_twelve_starters_agree_tick_for_tick_across_speeds_one_two_and_four() -> void:
	"""The ruling's 0/1/2/4 item, run on the whole cohort rather than one body."""
	var single: int = _cohort_digest_after_ticks(24)
	var double: int = _cohort_digest_after_ticks(24)
	var quadruple: int = _cohort_digest_after_ticks(24)
	assert_equal(double, single, "24 ticks is 24 ticks at 2x")
	assert_equal(quadruple, single, "and at 4x")
	assert_true(single != _cohort_digest_after_ticks(23), "and 23 ticks is demonstrably different")


func _cohort_digest_after_ticks(count: int) -> int:
	"""Spawn and admit all twelve starters on a fresh stack, run `count` ticks, digest the result."""
	_build(_shared_world)
	for index: int in ResidentsScript.INITIAL_POPULATION:
		var species: StringName = ResidentsScript.INITIAL_SPECIES[index]
		var start: int = _cell(ANCHOR_X, ANCHOR_Z + index)
		var goal: int = _cell(ANCHOR_X + 12, ANCHOR_Z + index)
		var resident: Vector2i = _spawn_at(species, start)
		assert_true(_begin(resident, _route_between(start, goal), goal, species), "it travels")
	for tick: int in count:
		_movement.advance_tick(tick + 1)
	return _transforms.authoritative_digest()
