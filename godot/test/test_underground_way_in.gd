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
const Confirm := preload("res://scripts/core/underground_room_confirm.gd")
const Composer := preload("res://scripts/core/underground_room_composer.gd")
const Runtime := preload("res://scripts/core/underground_room_runtime.gd")
const Foreman := preload("res://scripts/core/underground_room_foreman.gd")
const Approach := preload("res://scripts/core/underground_room_approach.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
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
	foot.wall_rows = PackedInt32Array([KitchenTests.CLAW_WALL - 1])
	assert_equal(way.approach_into(_request(Phase.Z), Composer.Order.new()), Front.REFUSE_NO_FRONT, "another yaw")


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
	var foreman: Foreman = _runtime.foreman_of(result.room)
	assert_equal(_dig_to_the_end(result.room), [] as Array[StringName], "no refusal")
	assert_equal(foreman.done_cubes(), StationTests.KITCHEN_SITES, "every cube dug")
