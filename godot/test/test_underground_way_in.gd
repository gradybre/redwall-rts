extends "res://test/framework/test_case.gd"
## Decision 2052 (slice D2 phase 1; Brendan, 2026-10-20, "Approve, start phase 1"): the production way in, proved on
## the claw Kitchen (decision 1939) with its corridor access standing in for a way down's foot. The front station is
## found by the wall row's own patch (P-2052-1 (a)): the Kitchen's existing station is reused, a room north along the
## corridor gets C3's fixture shape (a corner on the access's line, a station 521 u in front of its first cube),
## published once and withdrawn on demand. The store and the spoil pile (P-2052-2 (a)) are made on first use and found
## again by their points. Through the real Confirm route both rooms are admitted, and the claws dig them.

const KitchenTests := preload("res://test/test_underground_room_claw_kitchen.gd")
const StationTests := preload("res://test/test_underground_room_station_planner.gd")
const Phase := preload("res://test/test_underground_room_world_phases.gd")
const WayIn := preload("res://scripts/core/underground_way_in.gd")
const Front := preload("res://scripts/core/underground_way_in_front.gd")
const Builder := preload("res://scripts/core/underground_room_builder.gd")
const Prep := preload("res://scripts/core/underground_way_in_foot_prep.gd")
const Confirm := preload("res://scripts/core/underground_room_confirm.gd")
const Composer := preload("res://scripts/core/underground_room_composer.gd")
const Runtime := preload("res://scripts/core/underground_room_runtime.gd")
const Foreman := preload("res://scripts/core/underground_room_foreman.gd")
const Approach := preload("res://scripts/core/underground_room_approach.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const Contract := preload("res://scripts/core/excavation_contract.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const TICK_BOUND: int = 60000
## C3's second room, north along the corridor's east wall, and the station its fixture published by hand (decision
## 1991 E12): the way in must arrive at the same point by itself.
const NORTH_Z: int = Phase.Z + 2048
const NORTH_STATION: Vector3i = Vector3i(Phase.X + 2048 - 521, Phase.FLOOR, Phase.Z + 2560)
const NORTH_CORNER: Vector3i = Vector3i(Phase.X - 1024, Phase.FLOOR, Phase.Z + 2560)
## The spoil pile's point in the corridor: off the store's 2 m cell, the parkings and the corners (fixture geometry).
const PILE_POINT: Vector3i = Vector3i(Phase.X - 3072, Phase.FLOOR, Phase.Z + 2560)


class FootKitchen extends KitchenTests.ClawKitchen:
	## The claw Kitchen prepared with no room confirmed and no station but the Kitchen's own: the way in places the
	## rest. One claw mole stays far off on the surface (decision 1991 §3a).

	func prepare() -> bool:
		"""The fixture's owners, paths, stock (both rooms' BRACEs) and worker, as C3's TwoRooms has them."""
		location_capacity = 64; edge_capacity = 128
		_actual_fixture(); connect_source_paths(); finite_stock_and_worker()
		if not failures.is_empty(): return false
		stock(&"wood", StationTests.KITCHEN_SITES * Contract.BRACE_WOOD_MILLI)
		stock(&"stone", StationTests.KITCHEN_SITES * Contract.BRACE_STONE_MILLI)
		_mole_at(Vector3i(Phase.X, Phase.FLOOR, Phase.Z), NULL_REF)
		return failures.is_empty()

	func foot() -> WayIn.Foot:
		"""The corridor access as a way down's foot: level 1, the bound retreat row, the claw rows at the Kitchen's
		heading, the store M and a pile point."""
		var out: WayIn.Foot = WayIn.Foot.new()
		out.level = 1; out.access = _first; out.travel = provider._ordinary_travel
		out.ground = KitchenTests.CLAW_GROUND; out.content = KitchenTests.CLAW_CONTENT
		out.wall_rows = PackedInt32Array([KitchenTests.CLAW_WALL])
		out.forward_rows = PackedInt32Array([KitchenTests.CLAW_FORWARD])
		out.backward_rows = PackedInt32Array([KitchenTests.CLAW_BACKWARD])
		out.store_point = KitchenTests.CLAW_STORE_POINT; out.pile_point = PILE_POINT
		return out


var _h: FootKitchen = null
var _way: WayIn.StairWayIn = null
var _runtime: Runtime = null


func before_each() -> void:
	"""The prepared fixture, a runtime over its owners, and the way in configured from its foot."""
	_h = FootKitchen.new()
	_h.stocked = true
	if not _h.prepare(): return
	_runtime = Runtime.new(_h._residents.directory())
	assert_true(_runtime.bind_owners(_h.owners()), "owners")
	_way = WayIn.StairWayIn.new()
	assert_equal(_way.configure(_runtime.bound_owners(), _h.foot()), &"", "configured")


func after_each() -> void:
	"""Propagate the fixture's own assertions and free every owner."""
	_runtime = null
	_way = null
	if _h != null:
		_h.after_each()
		assert_true(_h.failures.is_empty(), "fixture: %s" % _h.failures)
	_h = null


func _request(origin_z: int, level: int = 1) -> Approach.Request:
	"""A painted 2 × 2 Kitchen at the corridor's east wall from `origin_z`, as Confirm builds its request."""
	var request: Approach.Request = Approach.Request.new()
	request.world = _h._world_ref; request.space_revision = _h._owner.revision()
	request.room_type = Buildings.ROOM_TYPE_KITCHEN; request.level = level
	request.origin_u = Vector3i(Phase.X + 2048, Phase.FLOOR, origin_z)
	request.cell_size_u = 1024
	request.cells = PackedInt32Array([0, 0, 1, 0, 0, 1, 1, 1])
	request.height_u = mini(4096, Approach.reachable_height_u(_h._profiles, KitchenTests.CLAW_WALL))
	return request


func _painted(origin_z: int) -> Confirm.Painted:
	"""The same room as the panel confirms it, with the fixture's claw mole named."""
	var painted: Confirm.Painted = Confirm.Painted.new()
	painted.level = 1; painted.room_type = Buildings.ROOM_TYPE_KITCHEN
	painted.origin_u = Vector3i(Phase.X + 2048, Phase.FLOOR, origin_z)
	painted.cells = PackedInt32Array([0, 0, 1, 0, 0, 1, 1, 1])
	painted.height_u = mini(4096, Approach.reachable_height_u(_h._profiles, KitchenTests.CLAW_WALL))
	painted.crew = PackedInt32Array([_h._worker.x, _h._worker.y])
	return painted


func _endpoints() -> int:
	"""Live Locations endpoints."""
	var count: int = 0
	for row: int in _h.endpoints._capacity: count += _h.endpoints._live.present[row]
	return count


func _spans() -> int:
	"""Live Routes spans."""
	var count: int = 0
	for row: int in _h._routes._edge_capacity: count += _h._routes._live.present[row]
	return count


func _containers() -> int:
	"""Live spatial ground containers."""
	var count: int = 0
	for slot: int in _h._inventory._spatial_container_slot: count += 1 if slot >= 0 else 0
	return count


func _point(location: Vector2i) -> Vector3i:
	"""An endpoint's point."""
	return Front.point_of(_h.endpoints, location.x)


func _tick() -> Array[StringName]:
	"""One fixed tick as the host runs it: the runtime's advance, then the rooms waiting for their crew."""
	_h.tick += 1
	var seen: Array[StringName] = []
	if _runtime.is_running(): seen.append_array(_runtime.advance(_h.tick))
	seen.append_array(Composer.start_waiting(_runtime, _h.placements))
	return seen


func _dig_to_the_end(room: Vector2i) -> Array[StringName]:
	"""Every fixed tick until the room's record is released; the refusals seen."""
	var seen: Array[StringName] = []
	for step: int in TICK_BOUND:
		seen.append_array(_tick())
		if not _runtime.is_running() and _runtime.kept() == 0: break
	assert_equal(_runtime.state_of(room), Runtime.RECORD_NONE, "finished, out, released")
	return seen


func test_the_kitchen_is_approached_from_its_own_station_with_no_corner() -> void:
	"""The wall row's patch lies on the Kitchen's west face from the existing station, which lines up with the access:
	nothing is published for the front; the order's way in is the foot's."""
	if _runtime == null: return
	var request: Approach.Request = _request(Phase.Z)
	var order: Composer.Order = Composer.Order.new()
	assert_equal(_way.approach_into(request, order), &"", "a front")
	assert_equal(request.work_location, _h._last, "the Kitchen's station, reused")
	assert_equal(request.access, _h._first, "no corner: the access itself")
	assert_equal(_way.pending(), PackedInt32Array(), "nothing published for the front")
	assert_equal(request.target_origin, request.origin_u, "the first cube")
	assert_equal(request.face, 0, "its -X face")
	assert_equal(request.yaw, 49152, "the wall row's yaw")
	assert_equal(request.travel_profile, KitchenTests.CLAW_FORWARD, "the forward row at that yaw")
	assert_equal(request.work_profile, KitchenTests.CLAW_WALL, "the claw wall row")
	assert_equal(request.content_revision, KitchenTests.CLAW_CONTENT, "the mounted content")
	assert_equal(request.space_revision, _h._owner.revision(), "the current Space revision")
	assert_equal([order.access, order.travel, order.staging], [_h._first, _h.provider._ordinary_travel, NULL_REF],
		"the foot's access, retreat row and staging")


func test_the_store_is_reused_and_the_pile_is_made_once_and_found_again() -> void:
	"""P-2052-2 (a): the store at its point is M's own container; the pile is made on the first order; a new way in
	over the same foot (as after a load) finds both and makes nothing."""
	if _runtime == null: return
	var order: Composer.Order = Composer.Order.new()
	var before: int = _containers()
	assert_equal(_way.approach_into(_request(Phase.Z), order), &"", "first order")
	assert_equal(order.storage, _h.material, "the store: M's container at its point")
	assert_true(order.output != NULL_REF, "a pile")
	assert_true(order.output != order.storage, "its own container")
	assert_equal(_point(_h._inventory.spatial_location_of(order.output)), PILE_POINT, "at the pile's point")
	assert_equal(_containers(), before + 1, "one container made")
	var again: WayIn.StairWayIn = WayIn.StairWayIn.new()
	assert_equal(again.configure(_runtime.bound_owners(), _h.foot()), &"", "a second way in")
	var endpoints: int = _endpoints()
	var second: Composer.Order = Composer.Order.new()
	assert_equal(again.approach_into(_request(Phase.Z), second), &"", "second order")
	assert_equal([second.storage, second.output], [order.storage, order.output], "the same two containers")
	assert_equal([_containers(), _endpoints()], [before + 1, endpoints], "nothing more made")


func test_the_north_room_gets_a_published_station_at_the_fixtures_own_point() -> void:
	"""Its first cube is (0, 0) of its cells, nearest the access; the station stands 521 u in front of its west face,
	reached from a corner on the access's line: C3's hand-made shape, now found and published by the way in."""
	if _runtime == null: return
	var endpoints: int = _endpoints()
	var request: Approach.Request = _request(NORTH_Z)
	assert_equal(_way.approach_into(request, Composer.Order.new()), &"", "a front")
	assert_equal(_point(request.work_location), NORTH_STATION, "the station's point")
	assert_equal(_point(request.access), NORTH_CORNER, "the corner's point")
	assert_equal(_h.endpoints._live.i32[Locations.ROLE * _h.endpoints._capacity + request.work_location.x],
		Locations.ROLE_WORK, "a WORK station")
	assert_equal(_way.pending(), PackedInt32Array([request.work_location.x, request.work_location.y,
		request.access.x, request.access.y]), "the station and the corner listed")
	assert_equal(_endpoints(), endpoints + 3, "station, corner and the pile's endpoint")
	assert_equal(request.target_origin, request.origin_u, "its first cube")


func test_asking_again_for_the_same_room_publishes_nothing() -> void:
	"""Every endpoint and span is found at its point: a second order of the same room adds nothing."""
	if _runtime == null: return
	var first: Approach.Request = _request(NORTH_Z)
	assert_equal(_way.approach_into(first, Composer.Order.new()), &"", "first")
	assert_equal(_way.settle(true), &"", "its room admitted: the front is kept")
	var endpoints: int = _endpoints()
	var spans: int = _spans()
	var second: Approach.Request = _request(NORTH_Z)
	assert_equal(_way.approach_into(second, Composer.Order.new()), &"", "second")
	assert_equal([second.work_location, second.access], [first.work_location, first.access], "the same front")
	assert_equal(_way.pending(), PackedInt32Array(), "nothing published")
	assert_equal([_endpoints(), _spans()], [endpoints, spans], "nothing added")


func test_withdrawing_retires_what_one_call_published_and_nothing_else() -> void:
	"""A room RoomOrders refused: its station and corner leave with every span touching them; the store, the pile
	and the Kitchen's own station stay."""
	if _runtime == null: return
	assert_equal(_way.approach_into(_request(Phase.Z), Composer.Order.new()), &"", "the Kitchen first (the pile)")
	var endpoints: int = _endpoints()
	var spans: int = _spans()
	var request: Approach.Request = _request(NORTH_Z)
	assert_equal(_way.approach_into(request, Composer.Order.new()), &"", "north")
	assert_true(_spans() > spans, "spans published")
	assert_equal(_way.withdraw_pending(), &"", "withdrawn")
	assert_equal([_endpoints(), _spans()], [endpoints, spans], "back as before")
	assert_false(Front.occupied(_h.endpoints, NORTH_STATION), "no station there")
	assert_equal(_way.pending(), PackedInt32Array(), "nothing listed")
	assert_equal(_way.withdraw_pending(), &"", "a second withdrawal does nothing")
	assert_true(_h.endpoints._live_ref(_h.endpoints._live, _h._last), "the Kitchen's station stays")


func test_another_level_is_refused_no_way_in_and_nothing_is_made() -> void:
	"""Only the foot's level: any other is the base seam's refusal, before any publication."""
	if _runtime == null: return
	var counts: Array[int] = [_endpoints(), _spans(), _containers()]
	assert_equal(_way.approach_into(_request(Phase.Z, 2), Composer.Order.new()), Confirm.REFUSE_NO_WAY_IN, "level 2")
	assert_equal([_endpoints(), _spans(), _containers()], counts, "nothing made")
	assert_equal(WayIn.StairWayIn.new().approach_into(_request(Phase.Z), Composer.Order.new()),
		Confirm.REFUSE_NO_WAY_IN, "an unconfigured way in")


func test_a_room_the_access_floor_cannot_face_has_no_front() -> void:
	"""A room painted beyond the access's surveyed air has no station point there: WAY_IN_NO_FRONT, nothing made
	(not even the pile)."""
	if _runtime == null: return
	var counts: Array[int] = [_endpoints(), _spans(), _containers()]
	var request: Approach.Request = _request(Phase.Z)
	request.origin_u = Vector3i(Phase.X + 8192, Phase.FLOOR, Phase.Z)
	assert_equal(_way.approach_into(request, Composer.Order.new()), Front.REFUSE_NO_FRONT, "no front")
	assert_equal([_endpoints(), _spans(), _containers()], counts, "nothing made")


func test_a_heading_whose_rows_do_not_pair_is_never_used() -> void:
	"""A wall row at another yaw than its forward row, or a row that is no WORK row, offers no front."""
	if _runtime == null: return
	var foot: WayIn.Foot = _h.foot()
	foot.wall_rows = PackedInt32Array([KitchenTests.CLAW_GROUND])
	var way: WayIn.StairWayIn = WayIn.StairWayIn.new()
	assert_equal(way.configure(_runtime.bound_owners(), foot), &"", "configured")
	assert_equal(way.approach_into(_request(Phase.Z), Composer.Order.new()), Front.REFUSE_NO_FRONT, "not a WORK row")
	foot.wall_rows = PackedInt32Array([_wall_at_another_yaw()])
	assert_equal(way.approach_into(_request(Phase.Z), Composer.Order.new()), Front.REFUSE_NO_FRONT, "another yaw")


func _wall_at_another_yaw() -> int:
	"""One of content 12's claw wall rows (67-70) whose yaw is not the forward row's."""
	var walk: Profiles.Descriptor = Profiles.Descriptor.new()
	assert_equal(_h._profiles.descriptor_into(KitchenTests.CLAW_FORWARD, KitchenTests.CLAW_CONTENT, walk), &"", "walk")
	for row: int in range(67, 71):
		var wall: Profiles.Descriptor = Profiles.Descriptor.new()
		assert_equal(_h._profiles.descriptor_into(row, KitchenTests.CLAW_CONTENT, wall), &"", "wall %d" % row)
		if wall.mode == Profiles.MODE_WORK and wall.yaw != walk.yaw: return row
	assert_true(false, "a wall row at another yaw")
	return KitchenTests.CLAW_WALL


func test_an_incomplete_foot_or_owners_are_refused_at_configure() -> void:
	"""Every field a room order reads must be set, and the heading rows must pair up."""
	if _runtime == null: return
	var way: WayIn.StairWayIn = WayIn.StairWayIn.new()
	assert_equal(way.configure(null, _h.foot()), WayIn.REFUSE_FOOT, "no owners")
	assert_equal(way.configure(_runtime.bound_owners(), null), WayIn.REFUSE_FOOT, "no foot")
	var broken: Array[Callable] = [
		func(f: WayIn.Foot) -> void: f.level = 0,
		func(f: WayIn.Foot) -> void: f.access = NULL_REF,
		func(f: WayIn.Foot) -> void: f.travel = -1,
		func(f: WayIn.Foot) -> void: f.ground = -1,
		func(f: WayIn.Foot) -> void: f.content = 0,
		func(f: WayIn.Foot) -> void: f.wall_rows = PackedInt32Array(),
		func(f: WayIn.Foot) -> void: f.forward_rows = PackedInt32Array([1, 2]),
		func(f: WayIn.Foot) -> void: f.pile_point = f.store_point]
	for index: int in broken.size():
		var foot: WayIn.Foot = _h.foot()
		broken[index].call(foot)
		assert_equal(way.configure(_runtime.bound_owners(), foot), WayIn.REFUSE_FOOT, "broken field %d" % index)
	assert_equal(way.approach_into(_request(Phase.Z), Composer.Order.new()), Confirm.REFUSE_NO_WAY_IN, "never set")


func test_the_real_confirm_route_digs_the_kitchen_through_the_way_in() -> void:
	"""Confirm all's route admits the painted Kitchen through the way in and the claws dig every cube; the spoil goes
	to the pile and the BRACEs' wood comes from the store."""
	if _runtime == null: return
	var wood: int = _h.free_milli(_h.material, &"wood")
	var result: Confirm.Result = Confirm.confirm(_h.orders, _runtime, _h.placements, _way, _h._world_ref,
		_h._owner.revision(), _painted(Phase.Z))
	assert_equal(result.code, &"", "confirmed and ordered")
	assert_true(result.admitted, "admitted")
	assert_equal(_way.settle(result.admitted), &"", "settled")
	var foreman: Foreman = _runtime.foreman_of(result.room)
	assert_equal(_dig_to_the_end(result.room), [] as Array[StringName], "no refusal")
	assert_equal(foreman.done_cubes(), StationTests.KITCHEN_SITES, "every cube dug")
	assert_equal(wood - _h.free_milli(_h.material, &"wood"), StationTests.KITCHEN_SITES * Contract.BRACE_WOOD_MILLI,
		"one BRACE's wood a cube, from the store")


func test_the_real_confirm_route_admits_and_digs_the_north_room_from_its_published_station() -> void:
	"""The station the way in published passes RoomOrders' own approach witness, and the room is dug end to end."""
	if _runtime == null: return
	var result: Confirm.Result = Confirm.confirm(_h.orders, _runtime, _h.placements, _way, _h._world_ref,
		_h._owner.revision(), _painted(NORTH_Z))
	assert_equal(result.code, &"", "confirmed and ordered")
	assert_true(result.admitted, "admitted through the published station")
	assert_equal(_way.settle(result.admitted), &"", "settled: the front is kept")
	assert_true(Front.occupied(_h.endpoints, NORTH_STATION), "the station stays while its room is dug")
	var foreman: Foreman = _runtime.foreman_of(result.room)
	assert_equal(_dig_to_the_end(result.room), [] as Array[StringName], "no refusal")
	assert_equal(foreman.done_cubes(), StationTests.KITCHEN_SITES, "every cube dug")


func _access() -> Locations.Record:
	"""The access endpoint's packet."""
	var access: Locations.Record = Front.record()
	assert_equal(_h.endpoints.read_location_into(_h._first, access), &"", "the access")
	return access


func _kitchen_candidate() -> Front.Candidate:
	"""The Kitchen heading's candidate, read from the mounted rows."""
	var c: Front.Candidate = Front.Candidate.new()
	assert_equal(Front.heading_into(_h._profiles, _h.foot(), 0, c), &"", "the heading")
	return c


func test_place_mirrors_for_a_patch_behind_its_root_on_z() -> void:
	"""A patch planar on z and lying toward -z: the station stands north of a room's south-facing cell, on its centre
	line, and strikes the cell's +Z face (face 5); the corner is on the access's z line."""
	if _runtime == null: return
	var c: Front.Candidate = _kitchen_candidate()
	c.axis = 2
	c.patch_low = Vector3i(c.patch_low.z, c.patch_low.y, -c.patch_low.x)
	c.patch_high = Vector3i(c.patch_high.z, c.patch_high.y, -c.patch_high.x)
	var request: Approach.Request = _request(Phase.Z - 3072)
	request.origin_u = Vector3i(Phase.X - 2048, Phase.FLOOR, Phase.Z - 3072)
	assert_true(Front.place(_h._profiles, request, _access(), 4, c), "cell (0, 1) faces the corridor")
	assert_equal([c.ahead, c.face], [-1, 5], "toward -z, the +Z face")
	assert_equal(c.point, Vector3i(Phase.X - 1536, Phase.FLOOR, Phase.Z - 1024 + 521), "the station")
	assert_equal(c.corner, Vector3i(Phase.X - 1536, Phase.FLOOR, Phase.Z + 512), "the corner on the access line")
	assert_false(Front.place(_h._profiles, request, _access(), 0, c), "cell (0, 0) has the room behind it")


func test_place_refuses_a_corner_over_the_room() -> void:
	"""A room that also holds the cell under the corner cannot be reached from it."""
	if _runtime == null: return
	var c: Front.Candidate = _kitchen_candidate()
	var request: Approach.Request = _request(NORTH_Z)
	assert_true(Front.place(_h._profiles, request, _access(), 0, c), "the north room's first cell")
	request.cells.append_array(PackedInt32Array([-3, 0]))
	assert_false(Front.place(_h._profiles, request, _access(), 0, c), "its corner now stands on a room cell")


func test_a_room_on_another_floor_has_no_front() -> void:
	"""The station stands on the access's own floor: a room whose floor is a quantum higher gets none."""
	if _runtime == null: return
	var counts: Array[int] = [_endpoints(), _spans(), _containers()]
	var request: Approach.Request = _request(Phase.Z)
	request.origin_u.y += 1024
	assert_equal(_way.approach_into(request, Composer.Order.new()), Front.REFUSE_NO_FRONT, "no front")
	assert_equal([_endpoints(), _spans(), _containers()], counts, "nothing made")


func test_cells_are_tried_nearest_the_access_first() -> void:
	"""By the distance of each cell's centre from the access, ties by cell order, whatever order they are listed in."""
	if _runtime == null: return
	var request: Approach.Request = _request(Phase.Z)
	request.cells = PackedInt32Array([1, 1, 1, 0, 0, 1, 0, 0])
	assert_equal(Front.cells_by_distance(request, _access().point), PackedInt32Array([6, 2, 4, 0]), "nearest first")
	assert_true(Front.has_cell(request, Vector2i(1, 0)), "listed")
	assert_false(Front.has_cell(request, Vector2i(0, 2)), "not listed")
	assert_false(Front.has_cell(request, Vector2i(1, 2)), "x alone is not enough")


func test_a_body_touching_the_room_face_is_clear_and_one_unit_more_is_not() -> void:
	"""Half-open boxes: the body may end exactly on the room's face, not one unit past it."""
	if _runtime == null: return
	var request: Approach.Request = _request(Phase.Z)
	var probe: Vector3i = Vector3i(Phase.X, Phase.FLOOR, Phase.Z + 512)
	var reach: int = Front.extent(_h._profiles, KitchenTests.CLAW_FORWARD, probe)[3] - probe.x
	var touching: Vector3i = Vector3i(Phase.X + 2048 - reach, Phase.FLOOR, Phase.Z + 512)
	assert_true(Front.body_clear(_h._profiles, KitchenTests.CLAW_FORWARD, request, _access(), touching), "touching")
	assert_false(Front.body_clear(_h._profiles, KitchenTests.CLAW_FORWARD, request, _access(),
		touching + Vector3i(1, 0, 0)), "one unit into the room")


func test_an_endpoint_of_another_role_at_the_point_is_never_reused_or_doubled() -> void:
	"""A WORK station is not a TRANSIT corner, and a STORAGE endpoint is not a WORK station: nothing is published over
	either, and the published list stays empty."""
	if _runtime == null: return
	var made: PackedInt32Array = PackedInt32Array()
	var endpoints: int = _endpoints()
	var rows: PackedInt32Array = PackedInt32Array([KitchenTests.CLAW_GROUND])
	var foot: WayIn.Foot = _h.foot()
	assert_equal(Front.endpoint_at(_runtime.bound_owners(), foot, _access(), _point(_h._last), Locations.ROLE_TRANSIT,
		rows, made), NULL_REF, "a WORK station is no corner")
	assert_equal(Front.endpoint_at(_runtime.bound_owners(), foot, _access(), KitchenTests.CLAW_STORE_POINT,
		Locations.ROLE_WORK, rows, made), NULL_REF, "a store is no station")
	assert_equal(Front.endpoint_at(_runtime.bound_owners(), foot, _access(), KitchenTests.CLAW_STORE_POINT,
		Locations.ROLE_TRANSIT, rows, made), _h.storage, "a store serves as a corner, as a parking does")
	assert_equal([made, _endpoints()], [PackedInt32Array(), endpoints], "nothing published")


func test_a_pile_point_taken_by_a_station_refuses_and_withdraws_the_front() -> void:
	"""P-2052-2 (a): the pile's point holds a WORK station, so no pile can stand there: WAY_IN_CONTAINER, and the
	north room's station and corner, published first in the same call, are withdrawn."""
	if _runtime == null: return
	var foot: WayIn.Foot = _h.foot()
	foot.pile_point = _point(_h._last)
	var way: WayIn.StairWayIn = WayIn.StairWayIn.new()
	assert_equal(way.configure(_runtime.bound_owners(), foot), &"", "configured")
	var counts: Array[int] = [_endpoints(), _spans(), _containers()]
	assert_equal(way.approach_into(_request(NORTH_Z), Composer.Order.new()), WayIn.REFUSE_CONTAINER, "no pile")
	assert_equal([_endpoints(), _spans(), _containers()], counts, "the front withdrawn, nothing made")
	assert_equal(way.pending(), PackedInt32Array(), "nothing listed")


func test_an_unsettled_front_refuses_the_next_order_until_settled() -> void:
	"""Review H2: the north room's front waits for the caller's word; a second order is refused WAY_IN_UNSETTLED and
	makes nothing; settle(false) withdraws the front, after which orders go on."""
	if _runtime == null: return
	assert_equal(_way.approach_into(_request(Phase.Z), Composer.Order.new()), &"", "the Kitchen (no front published)")
	var counts: Array[int] = [_endpoints(), _spans(), _containers()]
	assert_equal(_way.approach_into(_request(NORTH_Z), Composer.Order.new()), &"", "north")
	var published: Array[int] = [_endpoints(), _spans(), _containers()]
	assert_equal(_way.approach_into(_request(Phase.Z), Composer.Order.new()), WayIn.REFUSE_UNSETTLED, "unsettled")
	assert_equal([_endpoints(), _spans(), _containers()], published, "nothing made")
	assert_equal(_way.settle(false), &"", "refused: withdrawn")
	assert_equal([_endpoints(), _spans(), _containers()], counts, "the front gone")
	assert_equal(_way.approach_into(_request(Phase.Z), Composer.Order.new()), &"", "orders go on")


func test_a_room_roomorders_refuses_after_the_front_is_published_leaves_nothing_once_settled() -> void:
	"""The real route: the north room's front is published, then RoomOrders refuses its unauthored dug height; the
	caller settles with `admitted` false and every endpoint and span the way in published is gone."""
	if _runtime == null: return
	assert_equal(_way.approach_into(_request(Phase.Z), Composer.Order.new()), &"", "the pile first")
	var counts: Array[int] = [_endpoints(), _spans(), _containers()]
	var painted: Confirm.Painted = _painted(NORTH_Z)
	painted.height_u = 1000
	var result: Confirm.Result = Confirm.confirm(_h.orders, _runtime, _h.placements, _way, _h._world_ref,
		_h._owner.revision(), painted)
	assert_true(result.code != &"", "refused by RoomOrders")
	assert_false(result.admitted, "not admitted")
	assert_false(_way.pending().is_empty(), "the front was published")
	assert_equal(_way.settle(result.admitted), &"", "settled")
	assert_equal([_endpoints(), _spans(), _containers()], counts, "nothing left")


func test_a_station_on_its_corner_is_never_placed() -> void:
	"""Review M1: an access level with the station on the heading's axis would put the corner on the station."""
	if _runtime == null: return
	var c: Front.Candidate = _kitchen_candidate()
	var access: Locations.Record = _access()
	access.point.x = NORTH_STATION.x
	assert_false(Front.place(_h._profiles, _request(NORTH_Z), access, 0, c), "station on its corner")
	access.point.x = NORTH_STATION.x + 1
	assert_false(Front.place(_h._profiles, _request(NORTH_Z), access, 0, c), "station behind its corner")


func test_a_held_cold_lease_publishes_nothing_and_says_unjoined() -> void:
	"""Review M2: with the cold lease held elsewhere no endpoint can be published; the call refuses
	WAY_IN_FRONT_UNJOINED and leaves nothing."""
	if _runtime == null: return
	var counts: Array[int] = [_endpoints(), _spans(), _containers()]
	var lease: int = _h._budget.acquire(Budget.COLD_BYTES)
	assert_true(lease != 0, "lease held")
	assert_equal(_way.approach_into(_request(NORTH_Z), Composer.Order.new()), Front.REFUSE_UNJOINED, "unjoined")
	assert_equal(_h._budget.release(lease), &"", "released")
	assert_equal([_endpoints(), _spans(), _containers()], counts, "nothing made")


func test_a_cell_whose_cube_would_wrap_int32_is_never_placed() -> void:
	"""Review LOW: a cell index past int32's range in metres is refused before any cube is built."""
	if _runtime == null: return
	var c: Front.Candidate = _kitchen_candidate()
	var request: Approach.Request = _request(Phase.Z)
	request.cells = PackedInt32Array([1 << 22, 0]) # 2^22 m wraps an int32 cube back onto cell (0, 0)'s.
	assert_false(Front.cell_in_range(request, 0), "out of range")
	assert_false(Front.place(_h._profiles, request, _access(), 0, c), "never placed")
	assert_true(Front.cell_in_range(_request(Phase.Z), 0), "an ordinary cell")


func test_a_wall_row_at_another_yaw_than_its_walk_is_refused_by_the_heading() -> void:
	"""The approach's own rule: the forward row walks at the wall row's yaw, or the heading offers nothing."""
	if _runtime == null: return
	var foot: WayIn.Foot = _h.foot()
	foot.wall_rows = PackedInt32Array([_wall_at_another_yaw()])
	assert_equal(Front.heading_into(_h._profiles, foot, 0, Front.Candidate.new()), Front.REFUSE_NO_FRONT, "refused")
	assert_equal(Front.heading_into(_h._profiles, _h.foot(), 0, Front.Candidate.new()), &"", "the paired heading")


func test_a_patch_reaching_past_its_cube_is_not_on_the_face() -> void:
	"""The patch must lie inside the struck cube on its other two axes: one unit past the cube's top is refused."""
	if _runtime == null: return
	var c: Front.Candidate = _kitchen_candidate()
	var cube: Vector3i = Vector3i(Phase.X + 2048, Phase.FLOOR, Phase.Z)
	var point: Vector3i = Vector3i(cube.x - c.patch_low.x, Phase.FLOOR, Phase.Z + 512)
	assert_true(Front.patch_on_face(c, point, cube, cube.x), "the Kitchen's patch")
	c.patch_high.y = 1024
	assert_true(Front.patch_on_face(c, point, cube, cube.x), "up to the cube's top")
	assert_false(Front.patch_on_face(c, point + Vector3i(1, 0, 0), cube, cube.x), "off the face plane")
	c.patch_high.y = 1025
	assert_false(Front.patch_on_face(c, point, cube, cube.x), "one unit past its top")


# --- decision 2054 (phase 2): fronts kept, retired and recalled; Resume; the reuse guard; a stair's hub ---------------

func _north_admitted() -> Confirm.Result:
	"""The north room confirmed through the way in and settled with its room."""
	var result: Confirm.Result = Confirm.confirm(_h.orders, _runtime, _h.placements, _way, _h._world_ref,
		_h._owner.revision(), _painted(NORTH_Z))
	assert_equal(result.code, &"", "confirmed and ordered")
	assert_equal(_way.settle(result.admitted, result.room), &"", "settled with its room")
	return result


func _fronts_of(way: WayIn.StairWayIn) -> Array[Vector3i]:
	"""The kept fronts' (station point, corner point) as points, room by room."""
	var out: Array[Vector3i] = []
	var fronts: PackedInt32Array = way.fronts()
	for at: int in range(0, fronts.size(), 6):
		out.append_array([_point(Vector2i(fronts[at + 2], fronts[at + 3])), _point(Vector2i(fronts[at + 4], fronts[at + 5]))])
	return out


func test_an_admitted_rooms_front_is_kept_and_retired_once_its_record_is_released() -> void:
	"""Decision 2054 (2053 §3): settled with its room, the front is kept while the room digs, and retired (station and
	corner) once the record is released; a second pass retires nothing."""
	if _runtime == null: return
	var result: Confirm.Result = _north_admitted()
	assert_equal(_fronts_of(_way), [NORTH_STATION, NORTH_CORNER], "kept: the north room's station and corner")
	assert_equal(_way.retire_fronts(_runtime), 0, "not while its room is kept")
	assert_equal(_dig_to_the_end(result.room), [] as Array[StringName], "dug")
	var endpoints: int = _endpoints()
	assert_equal(_way.retire_fronts(_runtime), 1, "released: retired")
	assert_false(Front.occupied(_h.endpoints, NORTH_STATION), "the station is gone")
	assert_false(Front.occupied(_h.endpoints, NORTH_CORNER), "the corner is gone")
	assert_equal(_way.fronts(), PackedInt32Array(), "nothing kept")
	assert_equal(_endpoints(), endpoints - 2, "those two only (the room's own stations follow decision 1942)")
	assert_equal(_way.retire_fronts(_runtime), 0, "nothing more")


func test_a_front_kept_twice_or_for_an_unknown_room_follows_the_rules() -> void:
	"""One front per room; a front another kept front shares keeps its endpoints until the last goes; the access is
	never retired."""
	if _runtime == null: return
	assert_equal(_way.approach_into(_request(NORTH_Z), Composer.Order.new()), &"", "the north front")
	var station: Vector2i = Front.existing(_h.endpoints, _access(), NORTH_STATION, Locations.ROLE_WORK)
	var corner: Vector2i = Front.existing(_h.endpoints, _access(), NORTH_CORNER, Locations.ROLE_TRANSIT)
	assert_equal(_way.settle(true, Vector2i(7, 1)), &"", "kept for an unknown room")
	_way._keep(Vector2i(7, 1), station, corner)
	_way._keep(Vector2i(8, 1), station, _h._first)
	assert_equal(_way.fronts().size(), 12, "one front per room")
	assert_true(_way._shared(0, station) and not _way._shared(0, corner), "the station is shared, the corner not")
	assert_equal(_way.retire_fronts(_runtime), 2, "both rooms are unknown: both fronts retired")
	assert_false(Front.occupied(_h.endpoints, NORTH_STATION), "the station went with the last front")
	assert_true(_h.endpoints._live_ref(_h.endpoints._live, _h._first), "the access stays")


func test_the_fronts_are_recalled_from_the_rooms_sites_after_a_load() -> void:
	"""Decision 2054: a new way in over the same foot (as the host binds after a load) finds the admitted room's front
	again from its Sites, publishing nothing; Prep reads the room's cells back as painted."""
	if _runtime == null: return
	var result: Confirm.Result = _north_admitted()
	var counts: Array[int] = [_endpoints(), _spans()]
	var again: WayIn.StairWayIn = WayIn.StairWayIn.new()
	assert_equal(again.configure(_runtime.bound_owners(), _h.foot()), &"", "configured")
	assert_equal(again.recall_fronts(_runtime), 1, "one front found")
	assert_equal(again.fronts(), _way.fronts(), "the same front")
	assert_equal(again.recall_fronts(_runtime), 0, "only once")
	assert_equal([_endpoints(), _spans()], counts, "nothing published")
	assert_true(Prep.rooms_on_level(_h.sites, Phase.FLOOR).has(result.room), "its room is on the floor")
	var read: Approach.Request = Prep.request_of_room(_h.sites, result.room, 1)
	assert_equal(read.origin_u, Vector3i(Phase.X + 2048, Phase.FLOOR, NORTH_Z), "its lowest corner")
	var cells: Array = Array(read.cells)
	assert_equal(cells.size(), 8, "four cells")
	for at: int in range(0, 8, 2):
		assert_true(Front.has_cell(read, Vector2i(_painted(NORTH_Z).cells[at], _painted(NORTH_Z).cells[at + 1])),
			"cell %d" % (at >> 1))
	assert_null(Prep.request_of_room(_h.sites, Vector2i(9999, 1), 1), "no Sites: no room")


func test_resume_re_orders_a_stopped_room_whole_and_pays_each_brace_once() -> void:
	"""Decision 1991 M-4, P-2052-5 (a): a stopped room is ordered again through the way in (its front published again
	once retired), and the dig finishes with one BRACE's wood a cube in all."""
	if _runtime == null: return
	var wood: int = _h.free_milli(_h.material, &"wood")
	var result: Confirm.Result = _north_admitted()
	for step: int in 400: _tick()
	assert_equal(_runtime.stop_room(result.room), &"", "stopped")
	for step: int in TICK_BOUND:
		_tick()
		if _runtime.state_of(result.room) == Runtime.RECORD_NONE: break
	assert_equal(_way.retire_fronts(_runtime), 1, "its front retired once its record is released")
	var order: Composer.Order = Composer.Order.new()
	assert_equal(_way.order_into(result.room, order), &"", "the way in again")
	assert_false(_way.pending().is_empty(), "the front published again")
	assert_equal([order.room, order.access, order.travel], [result.room, _h._first, _h.provider._ordinary_travel],
		"the room, the foot's access and retreat row")
	assert_equal(Composer.order(_runtime, _h.placements, order), &"", "ordered again")
	assert_equal(_way.settle(true, result.room), &"", "kept")
	var foreman: Foreman = _runtime.foreman_of(result.room)
	assert_equal(_dig_to_the_end(result.room), [] as Array[StringName], "no refusal")
	assert_equal(foreman.done_cubes() > 0, true, "dug on")
	assert_equal(wood - _h.free_milli(_h.material, &"wood"), StationTests.KITCHEN_SITES * Contract.BRACE_WOOD_MILLI,
		"every BRACE paid once")
	assert_equal(_way.order_into(Vector2i(9999, 1), Composer.Order.new()), WayIn.REFUSE_NO_ROOM, "no such room")


func test_a_reused_front_endpoint_routed_elsewhere_is_never_taken_over() -> void:
	"""Decision 2054 (2053 review M3): once the north corner is joined to anything but the access and its station, a
	new order of the room refuses rather than reuse it."""
	if _runtime == null: return
	assert_equal(_way.approach_into(_request(NORTH_Z), Composer.Order.new()), &"", "the north front")
	assert_equal(_way.settle(true), &"", "kept")
	var corner: Vector2i = Front.existing(_h.endpoints, _access(), NORTH_CORNER, Locations.ROLE_TRANSIT)
	assert_false(Front.routed_elsewhere(_h._routes, corner, [_h._first, corner,
		Front.existing(_h.endpoints, _access(), NORTH_STATION, Locations.ROLE_WORK)]), "joined to its own only")
	assert_true(Front.span_pair(_runtime.bound_owners(), _h.foot(), _access(), corner, _h.storage), "a foreign span")
	assert_true(Front.routed_elsewhere(_h._routes, corner, [_h._first, corner]), "now routed elsewhere")
	assert_equal(_way.approach_into(_request(NORTH_Z), Composer.Order.new()), Front.REFUSE_UNJOINED, "not taken over")


func test_a_stairs_hub_is_made_once_joined_and_found_again_publishing_nothing() -> void:
	"""Decision 2054 on the fixture: a foot with a stair stop gets its hub at its point in the foot's air, joined to the
	stop both ways; `access_found` publishes nothing and finds it only once made."""
	if _runtime == null: return
	var foot: WayIn.Foot = _h.foot()
	foot.stair = _h._first; foot.access = NULL_REF
	foot.hub_point = PILE_POINT + Vector3i(0, 0, -1024)
	foot.hub_rows = PackedInt32Array([KitchenTests.CLAW_GROUND])
	foot.open = _access().envelope.duplicate()
	assert_equal(foot.refusal(), &"", "a stair's foot")
	var owners: Builder.Owners = _runtime.bound_owners()
	var counts: Array[int] = [_endpoints(), _spans()]
	assert_false(Prep.access_found(owners, foot), "no hub yet")
	assert_equal([_endpoints(), _spans()], counts, "nothing published")
	assert_equal(Prep.access_ready(owners, foot), &"", "the hub made")
	assert_true(foot.access != NULL_REF and _point(foot.access) == foot.hub_point, "at its point")
	assert_true(Front.span_between(_h._routes, _h._first, foot.access) and Front.span_between(_h._routes, foot.access,
		_h._first), "joined to the stop both ways")
	var made: Array[int] = [_endpoints(), _spans()]
	assert_equal(made, [counts[0] + 1, counts[1] + 2], "one endpoint, two spans")
	var hub: Vector2i = foot.access
	foot.access = NULL_REF
	assert_true(Prep.access_found(owners, foot) and foot.access == hub, "found again")
	assert_equal(Prep.access_ready(owners, foot), &"", "again")
	assert_equal([_endpoints(), _spans()], made, "nothing more")
	assert_equal(Prep.stand_ready(owners, foot), &"", "no stand rows: no stand")


func test_a_loaded_span_enters_its_stand_along_x() -> void:
	"""P-2091-7 (a): from a point off the stand's line, down to that line and then along x (three points); on its
	line, straight; always CARRY."""
	if _runtime == null: return
	var owners: Builder.Owners = _runtime.bound_owners()
	var foot: WayIn.Foot = _h.foot()
	var a: Vector3i = _point(_h._first)
	var b: Vector3i = _point(_h._last)
	var edge: RefCounted = Prep.loaded_span(owners, foot, _access(), _h._first, _h._last)
	assert_equal(edge.mode, Profiles.MODE_CARRY, "loaded")
	if a.x != b.x and a.z != b.z:
		assert_equal(edge.points, PackedInt32Array([a.x, a.y, a.z, a.x, a.y, b.z, b.x, b.y, b.z]), "bent onto the line")
		assert_equal(edge.length_u, absi(b.z - a.z) + absi(b.x - a.x), "the legs' length")
	else:
		assert_equal(edge.point_count, 2, "straight")
	var straight: RefCounted = Prep.loaded_span(owners, foot, _access(), _h._first, _h._first)
	assert_equal(straight.point_count, 2, "one point's span stays straight")
