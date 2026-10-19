extends "res://test/framework/test_case.gd"
## Decision 1942: the station planner and Locations agree on another room's claims. Two claw Kitchens side by side
## on the Corridor's east wall (the northern one at cells z 2..3, slice C3's two-room case on master's runtime): the
## first is stopped mid-phase after five cubes, so one of its cubes is a dug void beside the second room. A WORK
## station published as one air box is proved against its own Site's survey, in which the first room's reservation
## marker is a wall; the planner now keeps that box off it, so the second room is dug whole and the first, ordered
## again, is finished.

const RetirementTests := preload("res://test/test_underground_room_station_retirement.gd")
const ClawTests := preload("res://test/test_underground_room_claw_kitchen.gd")
const Phase := preload("res://test/test_underground_room_world_phases.gd")
const Planner := preload("res://scripts/core/underground_room_station_planner.gd")
const Runtime := preload("res://scripts/core/underground_room_runtime.gd")
const Foreman := preload("res://scripts/core/underground_room_foreman.gd")
const Builder := preload("res://scripts/core/underground_room_builder.gd")
const Approach := preload("res://scripts/core/underground_room_approach.gd")
const Contract := preload("res://scripts/core/excavation_contract.gd")
const Sites := preload("res://scripts/core/excavation_sites.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const Needs := preload("res://scripts/core/needs.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const TICK_BOUND: int = 60000
const KITCHEN_SITES: int = 16
## The northern room's origin and its admission station in the Corridor in front of its first cube (fixture geometry
## only, as slice C3's two-room fixture places them).
const NORTH_Z: int = Phase.Z + 2048
const NORTH_STATION: Vector3i = Vector3i(Phase.X + 2048 - 521, Phase.FLOOR, Phase.Z + 2560)


class TwoKitchens extends RetirementTests.LargeRoom:
	## The claw Kitchen plus a second Kitchen north of it, admitted from its own Corridor station.
	var north_work: Vector2i = NULL_REF
	var north_transit: Vector2i = NULL_REF

	func north_room() -> Vector2i:
		"""The northern Kitchen confirmed from a WORK endpoint in front of its first cube, reached from a Corridor
		TRANSIT endpoint level with it that is joined to the access."""
		var corner: Vector3i = Vector3i(Phase.X - 1024, Phase.FLOOR, NORTH_STATION.z)
		north_transit = _joined_endpoint(corner)
		north_work = _endpoint(NORTH_STATION, Locations.ROLE_WORK)
		var token: int = _begin()
		for reverse: bool in [false, true]:
			var edge: Routes.Edge = _edge()
			edge.from_location = north_work if reverse else north_transit
			edge.to_location = north_transit if reverse else north_work
			var from: Vector3i = NORTH_STATION if reverse else corner
			var to: Vector3i = corner if reverse else NORTH_STATION
			edge.points = PackedInt32Array([from.x, from.y, from.z, to.x, to.y, to.z])
			edge.length_u = absi(to.x - from.x)
			assert_equal(_routes.stage_add(token, edge).error, &"", "a station span")
		assert_equal(_binding.seal(token), &"", "station spans certified")
		assert_equal(_binding.publish(token), &"", "station spans published")
		_end(token)
		var request: Approach.Request = room_request()
		request.space_revision = _owner.revision()
		request.origin_u = Vector3i(Phase.X + 2048, Phase.FLOOR, NORTH_Z)
		request.target_origin = request.origin_u
		request.access = north_transit; request.work_location = north_work
		var made: Buildings.OpResult = orders.confirm_room(request)
		assert_true(made.ok, "the northern Kitchen confirmed: %s" % made.error)
		return made.ref if made.ok else NULL_REF


var _h: TwoKitchens = null


func after_each() -> void:
	"""Propagate the fixture's own assertions and free every owner."""
	if _h != null:
		_h.after_each()
		assert_true(_h.failures.is_empty(), "fixture: %s" % _h.failures)
	_h = null


func _dug(room: Vector2i) -> int:
	"""A room's Sites that are supported voids with no live phase."""
	var count: int = 0
	for row: int in _h.sites._count:
		if _h.sites._present[row] == 1 and _h.sites._room(row) == room and _h.sites._phase[row] == Sites.SUPPORTED_VOID \
				and _h.sites.project_of(Vector2i(row, Sites.SITE_GENERATION)) == NULL_REF:
			count += 1
	return count


func _run(runtime: Runtime, seen: Array[StringName]) -> void:
	"""Every fixed tick until the runtime rests."""
	for step: int in TICK_BOUND:
		_h.tick += 1
		seen.append_array(runtime.advance(_h.tick))
		if not runtime.is_running(): return


func test_a_room_beside_a_stopped_rooms_dug_cube_is_dug_whole_and_the_stopped_room_finished() -> void:
	"""Slice C3's case: the first Kitchen stopped while earning its sixth cube (its column (0,1) holds a dug void
	beside the second room); the second Kitchen is then dug whole by another mole, and the first, ordered again with
	that mole, takes its paid phase over and is finished. Every BRACE is paid exactly once."""
	_h = TwoKitchens.new()
	var first: Vector2i = _h.confirmed_room()
	if first == NULL_REF: return
	var second: Vector2i = _h.north_room()
	if second == NULL_REF: return
	_h.stock(&"wood", KITCHEN_SITES * Contract.BRACE_WOOD_MILLI) # One BRACE bill per Site of both rooms.
	_h.stock(&"stone", KITCHEN_SITES * Contract.BRACE_STONE_MILLI)
	var wood: int = _h.free_milli(_h.material, &"wood")
	var runtime: Runtime = Runtime.new(_h._residents.directory())
	assert_true(runtime.bind_owners(_h.owners()), "owners")
	assert_equal(runtime.order_room(first, _h.material, _h.spoil, NULL_REF), &"", "the first ordered")
	assert_equal(runtime.start_room(first, runtime.bound_owners(), [_h.crew_member()] as Array[Builder.Crew]), &"", "started")
	var foreman: Foreman = runtime.foreman_of(first)
	var builder: Builder = foreman.builders()[0]
	for step: int in TICK_BOUND:
		_h.tick += 1
		runtime.advance(_h.tick)
		if foreman.done_cubes() >= 5 and builder.stage() == Builder.STAGE_EARN: break
	assert_equal(builder.stage(), Builder.STAGE_EARN, "earning the sixth cube's paid phase")
	var row: int = _h._residents.directory().get_typed_row(_h._worker)
	_h._jobs.needs()._status[row] = Needs.STATUS_DEAD # Negative-only: the dig stops mid-phase (decision 1938's way;
	_h._jobs.needs()._health[row] = 0 # slice C3 adds the player's own stop).
	var seen: Array[StringName] = []
	_run(runtime, seen)
	assert_equal(seen, [Builder.REFUSE_LOST] as Array[StringName], "stopped by the loss")
	seen.clear()
	assert_equal(runtime.release_room(first), &"", "the stopped room released, its crew out")
	assert_equal(_dug(first), 5, "five cubes dug, one paid phase kept")
	var crew: Builder.Crew = _h.second_member(ClawTests.SECOND_PARKING)
	assert_equal(runtime.order_room(second, _h.material, _h.spoil, NULL_REF), &"", "the second ordered")
	assert_equal(runtime.start_room(second, runtime.bound_owners(), [crew] as Array[Builder.Crew]), &"", "started")
	_run(runtime, seen)
	assert_equal(seen, [] as Array[StringName], "no refusal")
	assert_equal(_dug(second), KITCHEN_SITES, "the second room dug whole")
	assert_equal(runtime.release_room(second), Runtime.REFUSE_STATE, "finished and released by itself")
	assert_equal(runtime.order_room(first, _h.material, _h.spoil, NULL_REF), &"", "the first ordered again")
	assert_equal(runtime.start_room(first, runtime.bound_owners(), [crew] as Array[Builder.Crew]), &"",
		"started again with the second room's mole, out again")
	_run(runtime, seen)
	assert_equal(seen, [] as Array[StringName], "no refusal after the re-order")
	assert_equal(_dug(first), KITCHEN_SITES, "the first room finished")
	assert_equal(wood - _h.free_milli(_h.material, &"wood"), 2 * KITCHEN_SITES * Contract.BRACE_WOOD_MILLI,
		"every BRACE's wood paid exactly once")
	assert_equal(_h._construction.live_project_count(), 0, "no live Project")


func test_a_work_station_box_may_not_meet_another_rooms_claim() -> void:
	"""The planner's own rule on its own scratch, with both Kitchens confirmed: a WORK station proved as one air box on
	a room's section is held to that room's Site survey, so another room's reservation marker is a wall and its own
	room's is not; on the Corridor's section the Kitchen's marker is a wall too. A single claimed box is the published
	envelope; two or more are proved as a route sweep and are never refused here."""
	_h = TwoKitchens.new()
	var first: Vector2i = _h.confirmed_room()
	if first == NULL_REF: return
	var second: Vector2i = _h.north_room()
	if second == NULL_REF: return
	var q: Planner.Query = _query(second)
	if q == null: return
	var in_second: Vector3i = Vector3i(Phase.X + 2560, Phase.FLOOR, Phase.Z + 2560)
	var in_corridor: Vector3i = Vector3i(Phase.X + 1527, Phase.FLOOR, Phase.Z + 512)
	var cases: Array = [
		[in_second, second, [-400, 400, 520], false, "inside the second room: its own marker is no wall"],
		[in_second, second, [-600, 400, 520], true, "spilling south into the first room's marker"],
		[in_corridor, _h.corridor, [-400, 400, 600], true, "from the Corridor, reaching the first room's marker"],
		[Vector3i(Phase.X - 1024, Phase.FLOOR, Phase.Z + 512), _h.corridor, [-400, 400, 520], false, "inside the Corridor"],
	]
	for row: Array in cases:
		var point: Vector3i = row[0]
		_section(q, row[1])
		var extent: Array = row[2]
		q.envelope = PackedInt32Array([point.x - 400, point.y, point.z + int(extent[0]), point.x + int(extent[2]),
			point.y + 900, point.z + int(extent[1])])
		q.air_counts[0] = 0
		assert_equal(Planner._foreign_claim(q, 0, point), row[3], row[4])
	q.air_counts[0] = 1 # One claimed box: it is the published envelope, whatever the one AABB was.
	for axis: int in 6: q.air[axis] = q.envelope[axis]
	q.envelope = PackedInt32Array([in_corridor.x - 400, in_corridor.y, in_corridor.z - 400, in_corridor.x + 1400,
		in_corridor.y + 900, in_corridor.z + 400])
	assert_false(Planner._foreign_claim(q, 0, Vector3i(Phase.X - 1024, Phase.FLOOR, Phase.Z + 512)),
		"the claimed box decides, not the AABB")
	_section(q, second)
	assert_true(Planner._foreign_claim(q, 0, in_corridor), "a room's section over another room's Site: no such survey")


func _query(room: Vector2i) -> Planner.Query:
	"""A planner Query held for the room's first open cube, its region and claim tables filled (no plan is made)."""
	var cold: int = _h._budget.acquire(Budget.COLD_BYTES)
	var candidate: Planner.Frontier.Candidate = Planner.Frontier.Candidate.new()
	var code: StringName = Planner.Frontier.next_site_into(_h.provider, room, -1, cold, Planner.Space.MAX_CHECKS, candidate)
	assert_equal(code, &"", "a candidate")
	var q: Planner.Query = Planner.Query.new()
	var yaw: int = Planner._retreat_yaw(_h.provider)
	Planner._hold(q, _h.provider, candidate, Planner.facing_face(_h.provider, yaw), yaw, Planner.Space.MAX_CHECKS)
	if code == &"": code = Planner._sources(q, _h.provider)
	if code == &"": code = Planner._gateway(q, _h.provider)
	if code == &"": code = Planner._regions(q)
	assert_equal(code, &"", "region and claim tables")
	assert_true(q.claim_count > 0, "claimed rows met the hull: %d" % q.claim_count)
	_h._budget.release(cold)
	return q if code == &"" else null


func _section(q: Planner.Query, room: Vector2i) -> void:
	"""Point the query's first station at the floor section the room owns."""
	var owner: Owner = _h._owner
	for row: int in owner._region_capacity:
		if owner._r_present[row] == 1 and owner._r_role[row] == Planner.Space.FLOOR_DATUM \
				and Vector2i(owner._r_owner_slot[row], owner._r_owner_generation[row]) == room:
			q.sections[0] = row; q.sections[1] = owner._r_generation[row]
			return
	assert_true(false, "a floor section for %s" % room)
