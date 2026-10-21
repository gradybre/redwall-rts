extends "res://test/framework/test_case.gd"
## Decision 1970: crews of three and four on the real Confirm route, where the access's floor has room for more than one
## parking. Three parking defects froze or stalled such crews (ROOM_FOREMAN_CREW_BLOCKED at 0 of 16 cubes, then
## ROOM_BUILDER_STALLED at 6 of 16):
## - a second parking three cells out behind the first, two cells out on the same line, walled its builder in;
## - parkings across the claw rows' heading were never joined (their footing left out the canonical ground row's
##   stance, the one row that walks a lateral leg), so only that line was offered;
## - a parked body reaching into the floor the builders walk to their stations held them there.
## The fixture is decision 1991's Confirm route fixture (`test_underground_room_confirm.gd` TwoRooms, with its
## bystander mole) with its old Corridor widened west, south and north (fixture geometry only).

const ConfirmTests := preload("res://test/test_underground_room_confirm.gd")
const KitchenTests := preload("res://test/test_underground_room_claw_kitchen.gd")
const StationTests := preload("res://test/test_underground_room_station_planner.gd")
const Phase := preload("res://test/test_underground_room_world_phases.gd")
const Confirm := preload("res://scripts/core/underground_room_confirm.gd")
const Composer := preload("res://scripts/core/underground_room_composer.gd")
const Parking := preload("res://scripts/core/underground_room_parking.gd")
const Runtime := preload("res://scripts/core/underground_room_runtime.gd")
const Foreman := preload("res://scripts/core/underground_room_foreman.gd")
const Builder := preload("res://scripts/core/underground_room_builder.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const TICK_BOUND: int = 20000
const WEST: int = 2048
const SOUTH: int = 4096
const NORTH: int = 2048


class WideRooms extends ConfirmTests.TwoRooms:
	## The Confirm route fixture with its old Corridor reaching WEST, SOUTH and NORTH further (fixture geometry only).

	func _bootstrap_corridor() -> void:
		"""The explicit old Corridor rows, widened, and their bootstrap Sites."""
		var token: int = _owner.begin_stage(_owner.revision()).token
		assert_equal(_owner.stage_source(token, corridor), &"", "old Room source")
		var box: PackedInt32Array = corridor_box()
		_floor = _bootstrap_region(token, PackedInt32Array([box[0], Phase.FLOOR, box[1], box[2], Phase.FLOOR + 1, box[3]]),
			Phase.Space.FLOOR_DATUM)
		_bootstrap_region(token, PackedInt32Array([box[0], Phase.FLOOR, box[1], box[2], Phase.FLOOR + 4096, box[3]]),
			Phase.Space.SUPPORTED_VOID)
		_bootstrap_region(token, PackedInt32Array([box[0], Phase.FLOOR - 1024, box[1], box[2], Phase.FLOOR, box[3]]),
			Phase.Space.SUPPORT)
		assert_equal(_owner.seal(token), &"", "widened old corridor geometry")
		_owner.publish(token)
		@warning_ignore("integer_division") var west: int = -4 - WEST / 1024
		@warning_ignore("integer_division") var south: int = -2 - SOUTH / 1024
		@warning_ignore("integer_division") var north: int = 4 + NORTH / 1024
		for x: int in range(west, 2):
			for z: int in range(south, north):
				assert_true(sites.claim_quantum(Vector3i(Phase.X + x * 1024, Phase.FLOOR, Phase.Z + z * 1024), corridor).ok,
					"bootstrap Site")

	func corridor_box() -> PackedInt32Array:
		"""The widened Corridor's floor rectangle (x0, z0, x1, z1)."""
		return PackedInt32Array([Phase.X - 4096 - WEST, Phase.Z - 2048 - SOUTH, Phase.X + 2048, Phase.Z + 4096 + NORTH])

	func _endpoint(point: Vector3i, role: int) -> Vector2i:
		"""As the base fixture's endpoint (the access is STORAGE), with the widened Corridor as its body air."""
		var box: PackedInt32Array = corridor_box()
		var row: Locations.Record = Locations.Record.new()
		row.point = point; row.section = _floor; row.room = corridor; row.level = 1
		row.role = Locations.ROLE_STORAGE if role == Locations.ROLE_TRANSIT else role
		row.envelope = PackedInt32Array([box[0], Phase.FLOOR, box[1], box[2], Phase.FLOOR + 4096, box[3]])
		row.support = PackedInt32Array([point.x - 406, Phase.FLOOR - 1, point.z - 406, point.x + 406, Phase.FLOOR, point.z + 406])
		var cold: int = _budget.acquire(Phase.Budget.COLD_BYTES)
		var token: int = endpoints.begin_prepare(cold).token
		var result: Locations.Result = endpoints.stage_add(token, row)
		assert_equal(result.error, &"", "supported endpoint")
		assert_equal(endpoints.seal(token), &"", "current endpoint")
		assert_true(endpoints.publish(token), "endpoint published")
		assert_equal(_budget.release(cold), &"", "same lease returned")
		return result.location


var _h: WideRooms = null
var _way: ConfirmTests.ClawWayIn = null
var _runtime: Runtime = null
var _moles: Array[Vector2i] = []


func before_each() -> void:
	"""The widened fixture, its way in and a runtime over its owners."""
	_h = WideRooms.new()
	_h.stocked = true
	if not _h.prepare(): return
	_way = ConfirmTests.ClawWayIn.new()
	_way.h = _h
	_runtime = Runtime.new(_h._residents.directory())
	assert_true(_runtime.bind_owners(_h.owners()), "owners")


func after_each() -> void:
	"""Propagate the fixture's own assertions and free every owner."""
	_runtime = null
	_way = null
	_moles.clear()
	if _h != null:
		_h.after_each()
		assert_true(_h.failures.is_empty(), "fixture: %s" % [_h.failures])
	_h = null


func _crew(size: int) -> PackedInt32Array:
	"""The fixture's claw mole, then `size - 1` more claw moles still far off on the surface."""
	var crew: PackedInt32Array = PackedInt32Array([_h._worker.x, _h._worker.y])
	for index: int in size - 1:
		var mole: Vector2i = _h._mole_at(Vector3i(Phase.X, Phase.FLOOR, Phase.Z), NULL_REF).worker
		_moles.append(mole)
		crew.append_array(PackedInt32Array([mole.x, mole.y]))
	return crew


func _painted(crew: PackedInt32Array) -> Confirm.Painted:
	"""The Kitchen painted 2 x 2 at the Corridor's east wall, dug its painted 4 m (decision 1971)."""
	var painted: Confirm.Painted = Confirm.Painted.new()
	painted.level = 1; painted.room_type = ConfirmTests.Buildings.ROOM_TYPE_KITCHEN
	painted.origin_u = Vector3i(Phase.X + 2048, Phase.FLOOR, Phase.Z)
	painted.cells = PackedInt32Array([0, 0, 1, 0, 0, 1, 1, 1])
	painted.height_u = mini(4096, ConfirmTests.Approach.reachable_height_u(_h._profiles, KitchenTests.CLAW_WALL))
	painted.crew = crew
	return painted


func _ordered(size: int) -> Foreman:
	"""Confirm the Kitchen with a named crew of `size`; its foreman, or null."""
	var result: Confirm.Result = Confirm.confirm(_h.orders, _runtime, _h.placements, _way, _h._world_ref,
		_h._owner.revision(), _painted(_crew(size)))
	assert_equal(result.code, &"", "confirmed and ordered")
	return _runtime.foreman_of(result.room) if result.code == &"" else null


func _dig(foreman: Foreman) -> Array[StringName]:
	"""Every fixed tick as the host runs it, to the end; the refusals seen."""
	var seen: Array[StringName] = []
	for step: int in TICK_BOUND:
		_h.tick += 1
		if _runtime.is_running(): seen.append_array(_runtime.advance(_h.tick))
		seen.append_array(Composer.start_waiting(_runtime, _h.placements))
		if not _runtime.is_running() and _runtime.kept() == 0: break
	return seen


func _point(location: Vector2i) -> Vector3i:
	"""One endpoint's point."""
	return Parking._point(_h.endpoints, location.x)


func _request() -> Parking.Request:
	"""The composer's parking request for the Kitchen at the fixture's access, nothing taken."""
	var request: Parking.Request = Parking.Request.new()
	request.access = _h._first; request.forward = _h.provider._ordinary_travel
	request.backward = KitchenTests.CLAW_BACKWARD; request.content = KitchenTests.CLAW_CONTENT
	request.room_box = PackedInt32Array([Phase.X + 2048, Phase.Z, Phase.X + 4096, Phase.Z + 2048])
	return request


func test_a_crew_of_three_parks_clear_of_each_other_and_digs_the_kitchen_to_the_end() -> void:
	"""Three named moles: each parks on its own line from the access (west, south, north), no parking stands on another's
	way, and all three dig the Kitchen to 16 of 16 with no refusal."""
	if _runtime == null: return
	var foreman: Foreman = _ordered(3)
	if foreman == null: return
	var builders: Array[Builder] = []
	builders.assign(foreman.builders())
	assert_equal(builders.size(), 3, "three parked")
	var access: Vector3i = _point(_h._first)
	var request: Parking.Request = _request()
	for index: int in builders.size():
		for other: int in builders.size():
			if other == index: continue
			request.taken = [builders[other].crew().parking]
			assert_false(Parking._crosses_taken(_h.owners(), request, access, _point(builders[index].crew().parking)),
				"parking %d is off parking %d's way and its body off %d's way" % [index, other, other])
	assert_equal(_dig(foreman), [] as Array[StringName], "no refusal")
	assert_equal(foreman.done_cubes(), StationTests.KITCHEN_SITES, "every cube dug")
	for builder: Builder in builders: assert_true(builder.cubes() > 0, "each of the three dug")


func test_a_crew_of_four_digs_with_the_three_the_access_parks_and_leaves_the_fourth_free() -> void:
	"""Decision 1991's rule at a wider access: one access parks at most three claw bodies clear of each other's ways;
	the fourth member is left free (not reserved, not parked), and the three dig the Kitchen to the end."""
	if _runtime == null: return
	var foreman: Foreman = _ordered(4)
	if foreman == null: return
	assert_equal(foreman.builders().size(), 3, "three parked")
	var fourth: Vector2i = _moles[_moles.size() - 1]
	for builder: Builder in foreman.builders(): assert_true(builder.crew().worker != fourth, "the fourth is no builder")
	assert_false(_runtime.reserves_resident(_h._residents.directory().get_typed_row(fourth)), "the fourth left free")
	assert_equal(_dig(foreman), [] as Array[StringName], "no refusal")
	assert_equal(foreman.done_cubes(), StationTests.KITCHEN_SITES, "every cube dug")


func test_a_parking_on_or_across_a_taken_parkings_way_is_refused() -> void:
	"""The first builder parks two cells west of the access. Three cells west lies behind it (its way to the access runs
	through that body): refused. Two cells south and three north are off every way: kept."""
	if _runtime == null: return
	var foreman: Foreman = _ordered(1)
	if foreman == null: return
	var first: Vector2i = foreman.builders()[0].crew().parking
	var access: Vector3i = _point(_h._first)
	assert_equal(_point(first), access + Vector3i(-2 * Parking.CELL_U, 0, 0), "the first parks two cells west")
	var request: Parking.Request = _request()
	request.taken = [first]
	assert_true(Parking._crosses_taken(_h.owners(), request, access, access + Vector3i(-3 * Parking.CELL_U, 0, 0)),
		"behind the first: walled in")
	assert_false(Parking._crosses_taken(_h.owners(), request, access, access + Vector3i(0, 0, -2 * Parking.CELL_U)),
		"two cells south")
	assert_false(Parking._crosses_taken(_h.owners(), request, access, access + Vector3i(0, 0, 3 * Parking.CELL_U)),
		"three cells north")
	request.taken = [_h._endpoint(access + Vector3i(-3 * Parking.CELL_U, 0, 0), Locations.ROLE_TRANSIT)]
	assert_true(Parking._crosses_taken(_h.owners(), request, access, _point(first)),
		"two cells west stands on the way of a parking three cells west (the second clause alone)")
	request.taken = [Vector2i(-1, 0)]
	assert_false(Parking._crosses_taken(_h.owners(), request, access, access + Vector3i(-3 * Parking.CELL_U, 0, 0)),
		"a dead parking ref has no body")


func test_the_sweep_is_exact_at_tangency() -> void:
	"""A 2 x 2 x 2 body about its root, against the same body at the origin: a sweep whose body only touches the still
	one (a gap of zero) does not meet it; one unit closer it does; a sweep starting or ending inside meets it; a sweep
	along an axis it never shares does not."""
	var body: PackedInt32Array = PackedInt32Array([-1, 0, -1, 1, 2, 1])
	var still: Vector3i = Vector3i.ZERO
	assert_false(Parking._sweep_meets(Vector3i(-10, 0, 2), Vector3i(10, 0, 2), body, still), "tangent: z gap 0")
	assert_true(Parking._sweep_meets(Vector3i(-10, 0, 1), Vector3i(10, 0, 1), body, still), "one unit closer")
	assert_true(Parking._sweep_meets(Vector3i(0, 0, 0), Vector3i(10, 0, 0), body, still), "starts inside")
	assert_true(Parking._sweep_meets(Vector3i(10, 0, 0), Vector3i(1, 0, 0), body, still), "ends overlapping")
	assert_false(Parking._sweep_meets(Vector3i(10, 0, 0), Vector3i(2, 0, 0), body, still), "ends touching")
	assert_false(Parking._sweep_meets(Vector3i(-10, 0, -10), Vector3i(-4, 0, 10), body, still), "a diagonal that passes by")
	assert_true(Parking._sweep_meets(Vector3i(-10, 0, -10), Vector3i(10, 0, 10), body, still), "a diagonal through it")
	assert_false(Parking._sweep_meets(Vector3i(-10, 0, -6), Vector3i(6, 0, 10), body, still),
		"inside in x for t in (1/2, 3/4) and in z for t in (1/4, 1/2): never both")
	assert_true(Parking._sweep_meets(Vector3i(-10, 0, -8), Vector3i(6, 0, 8), body, still),
		"inside in x for t in (1/2, 3/4) and in z for t in (3/8, 5/8): both in (1/2, 5/8)")
	assert_false(Parking._sweep_meets(Vector3i(2, 0, 0), Vector3i(10, 0, 0), body, still), "starts touching, moves away")
	assert_false(Parking._sweep_meets(Vector3i(-10, 0, -2), Vector3i(10, 0, -2), body, still), "tangent on the low side")


func test_a_lateral_parking_carries_the_ground_rows_stance() -> void:
	"""Across the claw READY rows' +X heading a parking is reached only on the canonical ground row, so its footing is
	the union with that row's stance; on the heading's line it is the READY rows' alone, as before."""
	if _runtime == null: return
	var access: Vector3i = _point(_h._first)
	var request: Parking.Request = _request()
	var profiles: Profiles = _h._profiles
	assert_true(Parking._lateral(profiles, request, access, access + Vector3i(0, 0, 2048)), "north (+z) is lateral")
	assert_false(Parking._lateral(profiles, request, access, access + Vector3i(-2048, 0, 0)), "west is in line")
	assert_equal(Parking._ground_row(profiles, request.forward, request.content), KitchenTests.CLAW_GROUND,
		"the claws' all-yaw ground WALK")
	var inline: Locations.Record = Parking._record()
	inline.point = access + Vector3i(-2048, 0, 0)
	assert_true(Parking._footing(profiles, request, inline, false), "in-line footing")
	var lateral: Locations.Record = Parking._record()
	lateral.point = access + Vector3i(0, 0, -2048)
	assert_true(Parking._footing(profiles, request, lateral, true), "lateral footing")
	var ground: PackedInt32Array = PackedInt32Array([-406, -406, 406, 406])
	var got: PackedInt32Array = PackedInt32Array([lateral.support[0] - lateral.point.x, lateral.support[2] - lateral.point.z,
		lateral.support[3] - lateral.point.x, lateral.support[5] - lateral.point.z])
	assert_equal(got, ground, "the ground row's stance covers the READY rows'")
	assert_true(inline.support[3] - inline.point.x < 406, "in line: the READY rows' narrower stance, unchanged")


func test_an_old_lateral_endpoint_without_the_ground_stance_is_passed_over() -> void:
	"""A lateral endpoint published before decision 1970 (the READY rows' stance alone) never certifies its spans; it is
	passed over, nothing is published again, and a lateral endpoint with the ground row's stance is kept."""
	if _runtime == null: return
	var access: Vector3i = _point(_h._first)
	var request: Parking.Request = _request()
	var narrow: Vector2i = _narrow_endpoint(access + Vector3i(0, 0, -2 * Parking.CELL_U))
	assert_false(Parking._ground_footed(_h.owners(), request, narrow), "the old narrow footing")
	var edges: int = _h._routes._live.edge_count
	var record: Locations.Record = Parking._record()
	assert_equal(_h.endpoints.read_location_into(_h._first, record), &"", "the access")
	assert_equal(Parking._parking_at(_h.owners(), request, record, _point(narrow)), NULL_REF, "passed over")
	assert_equal(_h._routes._live.edge_count, edges, "no span published again")
	var wide: Vector2i = _h._endpoint(access + Vector3i(0, 0, 3 * Parking.CELL_U), Locations.ROLE_TRANSIT)
	assert_true(Parking._ground_footed(_h.owners(), request, wide), "a ground-row footing is kept")


func _narrow_endpoint(point: Vector3i) -> Vector2i:
	"""A TRANSIT endpoint in the widened Corridor with the claw READY rows' stance as its support (pre-1970 footing)."""
	var box: PackedInt32Array = _h.corridor_box()
	var row: Locations.Record = Locations.Record.new()
	row.point = point; row.section = _h._floor; row.room = _h.corridor; row.level = 1; row.role = Locations.ROLE_TRANSIT
	row.envelope = PackedInt32Array([box[0], Phase.FLOOR, box[1], box[2], Phase.FLOOR + 4096, box[3]])
	row.support = PackedInt32Array([point.x - 249, Phase.FLOOR - 1, point.z - 274, point.x + 274, Phase.FLOOR, point.z + 299])
	var cold: int = _h._budget.acquire(Phase.Budget.COLD_BYTES)
	var token: int = _h.endpoints.begin_prepare(cold).token
	var result: Locations.Result = _h.endpoints.stage_add(token, row)
	assert_equal(result.error, &"", "a narrow endpoint")
	assert_equal(_h.endpoints.seal(token), &"", "sealed")
	assert_true(_h.endpoints.publish(token), "published")
	_h._budget.release(cold)
	return result.location


func test_a_parking_whose_body_reaches_the_builders_floor_is_beside_the_way() -> void:
	"""Two cells north (+z) of the access the parked body reaches into the floor between the access and the Kitchen's cell
	centres (z up to the far cells' centre plus a walking body): refused. Three cells north and two south are clear,
	and so is decision 1991's authored parking 1.75 m south (the fixture's second parking in the claw suites)."""
	if _runtime == null: return
	var access: Vector3i = _point(_h._first)
	var request: Parking.Request = _request()
	var profiles: Profiles = _h._profiles
	assert_true(Parking._beside_the_way(profiles, request, access, access + Vector3i(0, 0, 2048)), "two north")
	assert_false(Parking._beside_the_way(profiles, request, access, access + Vector3i(0, 0, 3072)), "three north")
	assert_false(Parking._beside_the_way(profiles, request, access, access + Vector3i(-2048, 0, 0)), "two west")
	assert_false(Parking._beside_the_way(profiles, request, access, access + Vector3i(0, 0, -2048)), "two south")
	assert_false(Parking._beside_the_way(profiles, request, access, KitchenTests.SECOND_PARKING), "the authored second")


func test_the_composer_skips_a_lateral_point_beside_the_way() -> void:
	"""`find_into` itself refuses a lateral point whose body reaches the builders' floor: with west and north taken and the
	room's cells reaching down toward the south parking's line, two cells south is beside the way; three cells south
	is found."""
	if _runtime == null: return
	var foreman: Foreman = _ordered(1)
	if foreman == null: return
	var access: Vector3i = _point(_h._first)
	var request: Parking.Request = _request()
	var north: Vector2i = _h._endpoint(access + Vector3i(0, 0, 3 * Parking.CELL_U), Locations.ROLE_TRANSIT)
	request.taken = [foreman.builders()[0].crew().parking, north] # West and north are taken: south is what is left.
	request.room_box = PackedInt32Array([Phase.X + 2048, Phase.Z - 1024, Phase.X + 4096, Phase.Z + 2048])
	var south: Vector3i = access + Vector3i(0, 0, -2 * Parking.CELL_U)
	assert_false(Parking._between(access, request.room_box, south), "not between the access and the room")
	assert_true(Parking._beside_the_way(_h._profiles, request, access, south), "but beside the way")
	var found: Array[Vector2i] = []
	assert_equal(Parking.find_into(_h.owners(), request, found), &"", "a parking further south")
	if found.is_empty(): return
	assert_true(_point(found[0]) != south, "the point beside the way is not the parking found")
	assert_equal(_point(found[0]), access + Vector3i(0, 0, -3 * Parking.CELL_U), "three cells south, clear of the way")
