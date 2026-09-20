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
	_shared_world = null
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


func test_public_arrival_has_a_nonzero_final_displacement_and_retained_speed() -> void:
	var mouse: Vector2i = _travelling_mouse(_cell(ANCHOR_X+1,ANCHOR_Z))
	var last_delta: int = 0
	for tick: int in 30:
		if _movement.motion_phase(mouse) != MovementScript.MOTION_TRAVELLING: break
		var before: int = _x_of(mouse)
		_movement.advance_tick(tick+1)
		last_delta = _x_of(mouse)-before
		assert_true(last_delta >= 0 and last_delta <= 110,"public displacement stays within ceil3277/30")
	assert_equal(_movement.motion_phase(mouse),MovementScript.MOTION_ARRIVED,"arrived")
	assert_true(last_delta > 0,"arrival and final movement share a tick; private vx is source-backed, not directly read")
	var final_remainder: int = _movement.remainder_x_of(mouse)
	assert_true(final_remainder >= 0 and final_remainder < 420,"retained fraction domain")
	var final_x: int = _x_of(mouse)
	_movement.advance_tick(31)
	assert_equal(_x_of(mouse),final_x,"terminal pose retained")
	assert_equal(_movement.remainder_x_of(mouse),final_remainder,"terminal remainder retained")
	assert_equal(_movement.speed_of(mouse),3277,"arrived speed retained")
	assert_true(_movement.stop(mouse),"explicit stop")
	assert_equal(_movement.motion_phase(mouse),MovementScript.MOTION_IDLE,"stop idle")
	assert_equal(_movement.remainder_x_of(mouse),0,"stop fraction zero")
	assert_equal(_movement.speed_of(mouse),3277,"idle history includes prior speed")
func test_public_one_cell_route_arrives_immediately() -> void:
	var cell: int = _cell(ANCHOR_X,ANCHOR_Z)
	var mouse: Vector2i = _spawn_at(&"mouse",cell)
	var request: int = _route_between(cell,cell)
	var before: int = _x_of(mouse)
	assert_true(_begin(mouse,request,cell,&"mouse"),"one-cell route admitted")
	assert_equal(_movement.motion_phase(mouse),MovementScript.MOTION_ARRIVED,"one-cell arrival before first tick")
	assert_equal(_x_of(mouse),before,"one-cell pose unchanged")
	assert_equal(_movement.speed_of(mouse),3277,"positive admitted speed")
	assert_equal(_movement.remainder_x_of(mouse),0,"no displacement accumulated")
func test_public_profile_and_contact_staleness_retain_fractions() -> void:
	var mouse: Vector2i = _travelling_mouse(_cell(ANCHOR_X+20,ANCHOR_Z))
	_movement.advance_tick(1)
	var retained: int = _movement.remainder_x_of(mouse)
	var x: int = _x_of(mouse)
	assert_true(retained > 0,"fraction before stale profile")
	assert_true(_movement.revise_profile(_movement.admitted_profile_of(mouse)),"revise profile")
	_movement.advance_tick(2)
	assert_equal(_movement.motion_phase(mouse),MovementScript.MOTION_PROFILE_STALE,"profile stale")
	assert_equal(_movement.remainder_x_of(mouse),retained,"profile failure keeps fraction")
	assert_equal(_x_of(mouse),x,"profile failure does not move")
	var other: Vector2i = _travelling_mouse(_cell(ANCHOR_X+20,ANCHOR_Z))
	_movement.advance_tick(3)
	retained = _movement.remainder_x_of(other)
	assert_true(_movement.revalidate_destination(other,DESTINATION_REVISION+1),"changed destination checked")
	assert_equal(_movement.motion_phase(other),MovementScript.MOTION_CONTACT_STALE,"contact stale")
	assert_equal(_movement.remainder_x_of(other),retained,"contact failure keeps fraction")
func test_public_reused_resident_row_retains_motion_until_owner_check() -> void:
	var mouse: Vector2i = _travelling_mouse(_cell(ANCHOR_X+20,ANCHOR_Z))
	_movement.advance_tick(1)
	var old_row: int = _directory.get_typed_row(mouse)
	var old_owner: int = _movement.route_owner_id_of(mouse)
	assert_true(_residents.despawn(mouse).ok,"despawn without movement stop")
	var successor: Vector2i = _spawn_at(&"mouse",_cell(ANCHOR_X,ANCHOR_Z))
	assert_equal(_directory.get_typed_row(successor),old_row,"typed row reused")
	assert_true(_directory.get_persistent_id(successor) != old_owner,"new identity")
	assert_equal(_movement.motion_phase(successor),MovementScript.MOTION_TRAVELLING,"old phase persists until tick")
	var before: int = _x_of(successor)
	_movement.advance_tick(2)
	assert_equal(_movement.motion_phase(successor),MovementScript.MOTION_ROUTE_LOST,"old owner detected")
	assert_equal(_x_of(successor),before,"successor never walks old route")
