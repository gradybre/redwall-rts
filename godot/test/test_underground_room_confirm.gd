extends "res://test/framework/test_case.gd"
## Decision 1991 (slice C3): Confirm all's real route, end to end on the claw Kitchen (decision 1939) with a way in
## bootstrapped as slice D2's will be. A painted room is admitted through RoomOrders and ordered with the crew the
## player named (P-1990-4 (a)); a batch's later room waits QUEUED for that crew, holding nothing; the player's one Stop
## (P-1990-5 (a)) walks the crew out and releases the record, after which the waiting room starts; a re-order of the
## stopped room digs only what is left, never paying a phase twice. Without D2's seam every painted room is refused
## "No way in" before anything is admitted.

const KitchenTests := preload("res://test/test_underground_room_claw_kitchen.gd")
const StationTests := preload("res://test/test_underground_room_station_planner.gd")
const Phase := preload("res://test/test_underground_room_world_phases.gd")
const Confirm := preload("res://scripts/core/underground_room_confirm.gd")
const Composer := preload("res://scripts/core/underground_room_composer.gd")
const Runtime := preload("res://scripts/core/underground_room_runtime.gd")
const Foreman := preload("res://scripts/core/underground_room_foreman.gd")
const Builder := preload("res://scripts/core/underground_room_builder.gd")
const Approach := preload("res://scripts/core/underground_room_approach.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const Sites := preload("res://scripts/core/excavation_sites.gd")
const Contract := preload("res://scripts/core/excavation_contract.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const TICK_BOUND: int = 60000
## The second room lies north of the Kitchen along the corridor's east wall: cells z 2..3 (fixture geometry only).
const NORTH_Z: int = Phase.Z + 2048
## The second room's station, in the corridor in front of its first cube (fixture geometry only).
const NORTH_STATION: Vector3i = Vector3i(Phase.X + 2048 - 521, Phase.FLOOR, Phase.Z + 2560)


class TwoRooms extends KitchenTests.ClawKitchen:
	## The claw Kitchen, prepared but with no room confirmed: the route admits both rooms itself. A second WORK
	## endpoint stands in front of the northern room, joined to the access both ways.
	var north_work: Vector2i = Vector2i(-1, 0)
	var north_transit: Vector2i = Vector2i(-1, 0)

	func prepare() -> bool:
		"""The fixture's owners, paths, stock and worker, as `confirmed_room` makes them, without its confirmation;
		stock for both rooms' BRACEs."""
		location_capacity = 64; edge_capacity = 128
		_actual_fixture(); connect_source_paths(); finite_stock_and_worker()
		if not failures.is_empty(): return false
		stock(&"wood", StationTests.KITCHEN_SITES * Contract.BRACE_WOOD_MILLI)
		stock(&"stone", StationTests.KITCHEN_SITES * Contract.BRACE_STONE_MILLI)
		north_work = _joined_work(NORTH_STATION)
		return failures.is_empty()

	func _joined_work(point: Vector3i) -> Vector2i:
		"""A WORK endpoint reached as the Kitchen's own is, by a straight span along +X, from a corridor TRANSIT
		endpoint level with it that is joined to the access (the storage endpoint's shape)."""
		var corner: Vector3i = Vector3i(Phase.X - 1024, Phase.FLOOR, point.z)
		var transit: Vector2i = _joined_endpoint(corner)
		north_transit = transit
		var spot: Vector2i = _endpoint(point, Locations.ROLE_WORK)
		var token: int = _begin()
		for reverse: bool in [false, true]:
			var edge: Routes.Edge = _edge()
			edge.from_location = spot if reverse else transit; edge.to_location = transit if reverse else spot
			var from: Vector3i = point if reverse else corner
			var to: Vector3i = corner if reverse else point
			edge.points = PackedInt32Array([from.x, from.y, from.z, to.x, to.y, to.z])
			edge.length_u = absi(to.x - from.x)
			assert_equal(_routes.stage_add(token, edge).error, &"", "a station span")
		assert_equal(_binding.seal(token), &"", "station span certificates")
		assert_equal(_binding.publish(token), &"", "station span publication")
		_end(token)
		return spot


class ClawWayIn extends Confirm.WayIn:
	## Slice D2's seam as the fixture bootstraps it: the corridor access, the claw rows at the Kitchen's heading, the
	## station in front of the room's first cube, and the fixture's one container for storage and spoil.
	var h: TwoRooms = null
	var calls: int = 0

	func approach_into(request: Approach.Request, order: Composer.Order) -> StringName:
		"""Fill the approach and the order from the fixture."""
		calls += 1
		var base: Approach.Request = h.room_request()
		request.access = base.access; request.travel_profile = base.travel_profile
		request.travel_revision = base.travel_revision; request.work_profile = base.work_profile
		request.work_revision = base.work_revision; request.content_revision = base.content_revision
		request.target_origin = request.origin_u; request.face = base.face; request.yaw = base.yaw
		var north: bool = request.origin_u.z != Phase.Z
		# The northern room's admission approaches from the corridor endpoint level with its station (the ground row
		# carries the crew there from the access); its dig keeps the one access the contacts are bound to.
		request.access = h.north_transit if north else base.access
		request.work_location = h.north_work if north else h._last
		order.access = h._first; order.travel = h.provider._ordinary_travel
		order.storage = h.material; order.output = h.material
		return &""


var _h: TwoRooms = null
var _way: ClawWayIn = null
var _runtime: Runtime = null


func before_each() -> void:
	"""The prepared fixture, its way in and a runtime over its owners."""
	_h = TwoRooms.new()
	_h.stocked = true
	if not _h.prepare(): return
	_way = ClawWayIn.new()
	_way.h = _h
	_runtime = Runtime.new(_h._residents.directory())
	assert_true(_runtime.bind_owners(_h.owners()), "owners")


func after_each() -> void:
	"""Propagate the fixture's own assertions and free every owner."""
	_runtime = null
	_way = null
	if _h != null:
		_h.after_each()
		assert_true(_h.failures.is_empty(), "fixture: %s" % _h.failures)
	_h = null


func _painted(origin_z: int, crew: PackedInt32Array) -> Confirm.Painted:
	"""A painted 2 × 2 room at the corridor's east wall from `origin_z`, dug the painted 4 m (decision 1971)."""
	var painted: Confirm.Painted = Confirm.Painted.new()
	painted.level = 1; painted.room_type = Buildings.ROOM_TYPE_KITCHEN
	painted.origin_u = Vector3i(Phase.X + 2048, Phase.FLOOR, origin_z)
	painted.cells = PackedInt32Array([0, 0, 1, 0, 0, 1, 1, 1])
	painted.height_u = mini(4096, Approach.reachable_height_u(_h._profiles, KitchenTests.CLAW_WALL))
	painted.crew = crew
	return painted


func _confirm(painted: Confirm.Painted, way: Confirm.WayIn) -> Confirm.Result:
	"""Confirm one painted room through the route."""
	return Confirm.confirm(_h.orders, _runtime, _h.placements, way, _h._world_ref, _h._owner.revision(), painted)


func _worker_crew() -> PackedInt32Array:
	"""The fixture's claw mole, named."""
	return PackedInt32Array([_h._worker.x, _h._worker.y])


func _tick() -> Array[StringName]:
	"""One fixed tick as the host runs it: the runtime's advance, then the rooms waiting for their crew."""
	_h.tick += 1
	var seen: Array[StringName] = []
	if _runtime.is_running(): seen.append_array(_runtime.advance(_h.tick))
	seen.append_array(Composer.start_waiting(_runtime, _h.placements))
	return seen


func _room_count() -> int:
	"""Live spatial rooms (RoomOrders' admissions)."""
	return _h._buildings.live_room_count()


func test_without_d2_every_painted_room_is_refused_no_way_in_before_anything_is_admitted() -> void:
	"""The seam's base class is the game before slice D2: no level has a way in; nothing is admitted or ordered."""
	if _runtime == null: return
	var rooms: int = _room_count()
	var result: Confirm.Result = _confirm(_painted(Phase.Z, PackedInt32Array()), Confirm.WayIn.new())
	assert_equal(result.code, Confirm.REFUSE_NO_WAY_IN, "no way in")
	assert_false(result.admitted, "not admitted")
	assert_equal(_room_count(), rooms, "no room")
	assert_equal(_runtime.kept(), 0, "no record")
	assert_equal(Confirm.refusal_words(result.code, 1), "No way in: needs a way down to level 1", "the words")
	assert_equal(_confirm(_painted(Phase.Z, PackedInt32Array()), null).code, Confirm.REFUSE_NO_WAY_IN, "no seam at all")


func test_a_crew_that_cannot_dig_is_refused_before_the_way_in_or_admission() -> void:
	"""P-1990-4 (a): 1-4 residents who can dig. Five, a resident named twice, or one who is no mole (or holds a
	tool) is refused, named, before the seam is asked and before RoomOrders admits anything."""
	if _runtime == null: return
	var rooms: int = _room_count()
	var twice: PackedInt32Array = _worker_crew()
	twice.append_array(_worker_crew())
	assert_equal(_confirm(_painted(Phase.Z, twice), _way).code, Composer.REFUSE_CREW_SIZE, "named twice")
	var five: PackedInt32Array = PackedInt32Array()
	for index: int in 5: five.append_array(PackedInt32Array([index, 1]))
	assert_equal(_confirm(_painted(Phase.Z, five), _way).code, Composer.REFUSE_CREW_SIZE, "five")
	var rat: Vector2i = _h._residents.ref_of(_h._residents.spawn(&"mouse").value)
	assert_equal(_confirm(_painted(Phase.Z, PackedInt32Array([rat.x, rat.y])), _way).code,
		Composer.REFUSE_CREW_MEMBER, "not a mole")
	assert_equal(_confirm(_painted(Phase.Z, PackedInt32Array([999, 1])), _way).code, Composer.REFUSE_CREW_MEMBER,
		"no such resident")
	assert_equal(_way.calls, 0, "the way in was never asked")
	assert_equal(_room_count(), rooms, "nothing admitted")


func test_a_named_claw_mole_digs_the_painted_kitchen_end_to_end() -> void:
	"""The route admits the painted Kitchen (one Site per cube of its painted 4 m), orders it with the named mole,
	and the room foreman digs every cube; the crew walks out and the record is released. Each BRACE paid once, at
	its start (BUILD-REQ-019)."""
	if _runtime == null: return
	var wood: int = _h.free_milli(_h.material, &"wood")
	var result: Confirm.Result = _confirm(_painted(Phase.Z, _worker_crew()), _way)
	assert_equal(result.code, &"", "confirmed and ordered")
	assert_true(result.admitted, "admitted")
	assert_equal(_h.free_milli(_h.material, &"wood"), wood, "nothing deducted at Confirm")
	assert_equal(_runtime.state_of(result.room), Runtime.RECORD_DIGGING, "digging at once: its crew was free")
	assert_equal(_runtime.foreman_of(result.room).builders()[0].crew().worker, _h._worker, "the named mole")
	var foreman: Foreman = _runtime.foreman_of(result.room)
	var seen: Array[StringName] = []
	for step: int in TICK_BOUND:
		seen.append_array(_tick())
		if not _runtime.is_running() and _runtime.kept() == 0: break
	assert_equal(seen, [] as Array[StringName], "no refusal")
	assert_equal(foreman.done_cubes(), StationTests.KITCHEN_SITES, "every cube dug")
	assert_equal(_runtime.state_of(result.room), Runtime.RECORD_NONE, "finished, out, released")
	assert_equal(wood - _h.free_milli(_h.material, &"wood"), StationTests.KITCHEN_SITES * Contract.BRACE_WOOD_MILLI,
		"one BRACE's wood a cube")


func _sites_of(room: Vector2i) -> PackedInt32Array:
	"""The Site rows of one room."""
	var out: PackedInt32Array = PackedInt32Array()
	for row: int in _h.sites._count:
		if _h.sites._present[row] == 1 and _h.sites._room(row) == room: out.append(row)
	return out


func _projects_on(room: Vector2i) -> int:
	"""Live phase Projects on a room's Sites."""
	var count: int = 0
	for row: int in _sites_of(room):
		count += 0 if _h.sites.project_of(Vector2i(row, Sites.SITE_GENERATION)) == NULL_REF else 1
	return count


func _dug(room: Vector2i) -> int:
	"""A room's Sites that are supported voids with no live phase (Sites' own record of a dug cube)."""
	var count: int = 0
	for row: int in _sites_of(room):
		if _h.sites._phase[row] == Sites.SUPPORTED_VOID and _h.sites.project_of(Vector2i(row, Sites.SITE_GENERATION)) == NULL_REF:
			count += 1
	return count


func _batch() -> Array[Vector2i]:
	"""One Confirm all of two rooms, one named crew: the Kitchen digs at once, the northern room waits for the crew."""
	var first: Confirm.Result = _confirm(_painted(Phase.Z, _worker_crew()), _way)
	var second: Confirm.Result = _confirm(_painted(NORTH_Z, _worker_crew()), _way)
	assert_equal(first.code, &"", "the Kitchen confirmed and ordered")
	assert_equal(second.code, &"", "the northern room confirmed and ordered")
	return [first.room, second.room]


func test_a_batchs_second_room_waits_for_the_crew_holding_nothing() -> void:
	"""P-1990-4 (a): one crew for the batch. The second room is QUEUED with that crew and holds nothing a dig holds:
	no foreman, no builder, no parking, no phase Project or Job on its Sites, no route actor, no reservation."""
	if _runtime == null: return
	var rooms: Array[Vector2i] = _batch()
	assert_equal(_runtime.state_of(rooms[0]), Runtime.RECORD_DIGGING, "the first room digs")
	assert_equal(_runtime.state_of(rooms[1]), Runtime.RECORD_QUEUED, "the second waits")
	assert_equal(_runtime.crew_of(rooms[1]), _worker_crew(), "for the crew it was given")
	assert_null(_runtime.foreman_of(rooms[1]), "no foreman")
	assert_equal(_runtime.parkings().size(), 1, "one parking: the first room's builder")
	for step: int in 400: _tick()
	assert_equal(_runtime.state_of(rooms[1]), Runtime.RECORD_QUEUED, "still waiting while the crew digs")
	assert_equal(_projects_on(rooms[1]), 0, "no phase Project on its Sites")
	assert_true(_projects_on(rooms[0]) > 0, "while the first room's are open")


func test_a_stop_partway_walks_the_crew_out_then_the_waiting_room_starts_and_a_reorder_finishes() -> void:
	"""P-1990-5 (a): Stop the first room after some cubes. Its crew walks out from rest, its record is released once
	out (the release comes before the waiting room's start, in the host's order), and the second room starts with
	that crew and is dug whole. Re-ordering the first room digs only what is left, taking over any paid phase, so
	every cube's BRACE is paid exactly once."""
	if _runtime == null: return
	var wood: int = _h.free_milli(_h.material, &"wood")
	var rooms: Array[Vector2i] = _batch()
	var foreman: Foreman = _runtime.foreman_of(rooms[0])
	var step: int = 0
	var builder: Builder = foreman.builders()[0]
	while (foreman.done_cubes() < 1 or builder.stage() != Builder.STAGE_EARN) and step < TICK_BOUND:
		_tick(); step += 1
	assert_equal(builder.stage(), Builder.STAGE_EARN, "stopped while a paid phase is under way")
	assert_equal(_runtime.stop_room(rooms[0]), &"", "stopped by the player")
	assert_equal(_runtime.state_of(rooms[0]), Runtime.RECORD_STOPPED, "stopped, its crew still underground")
	var seen: Array[StringName] = []
	var released_first: bool = false
	while _runtime.state_of(rooms[1]) == Runtime.RECORD_QUEUED and step < TICK_BOUND:
		seen.append_array(_tick()); step += 1
		released_first = _runtime.state_of(rooms[0]) == Runtime.RECORD_NONE
	assert_true(released_first, "the stopped record was released when its crew was out")
	assert_equal(_runtime.state_of(rooms[1]), Runtime.RECORD_DIGGING, "then the waiting room started")
	assert_equal(_projects_on(rooms[0]), 1, "the paid phase is kept for a re-order; nothing else is open")
	var dug_before: int = _dug(rooms[0])
	assert_true(dug_before >= 1 and dug_before < StationTests.KITCHEN_SITES, "what was dug stays dug: %d" % dug_before)
	while (_runtime.is_running() or _runtime.kept() > 0) and step < TICK_BOUND:
		seen.append_array(_tick()); step += 1
	assert_equal(_dug(rooms[1]), StationTests.KITCHEN_SITES, "the second room dug whole")
	var again: Composer.Order = Composer.Order.new()
	again.room = rooms[0]; again.access = _h._first; again.travel = _h.provider._ordinary_travel
	again.storage = _h.material; again.output = _h.material; again.crew = _worker_crew()
	assert_equal(Composer.order(_runtime, _h.placements, again), &"", "the stopped room ordered again")
	while (_runtime.is_running() or _runtime.kept() > 0) and step < TICK_BOUND:
		seen.append_array(_tick()); step += 1
	assert_equal(seen, [] as Array[StringName], "no refusal")
	assert_equal(_dug(rooms[0]), StationTests.KITCHEN_SITES, "only what was left, now dug")
	assert_equal(wood - _h.free_milli(_h.material, &"wood"), 2 * StationTests.KITCHEN_SITES * Contract.BRACE_WOOD_MILLI,
		"every BRACE paid exactly once across the stop and the re-order")
	assert_equal(_h._construction.live_project_count(), 0, "no live Project")


func test_a_waiting_record_with_its_crew_saves_and_restores_canonically() -> void:
	"""Decision 1991's record version 2: a QUEUED record keeps its named crew and a stopped one its release flag
	across a capture and a restore, re-encoding to the same bytes."""
	if _runtime == null: return
	var rooms: Array[Vector2i] = _batch()
	for step: int in 200: _tick()
	assert_equal(_runtime.stop_room(rooms[0]), &"", "stopped")
	var bytes: PackedByteArray = PackedByteArray()
	var code: StringName = _runtime.capture(bytes)
	var tries: int = 0
	while code != &"" and tries < 400:
		_tick(); tries += 1
		code = _runtime.capture(bytes)
	assert_equal(code, &"", "captured at a quiet tick")
	var fresh: Runtime = Runtime.new(_h._residents.directory())
	assert_true(fresh.bind_owners(_h.owners()), "owners")
	assert_equal(fresh.restore(bytes), &"", "restored")
	assert_equal(fresh.crew_of(rooms[1]), _worker_crew(), "the waiting crew kept")
	assert_equal(fresh.state_of(rooms[1]), _runtime.state_of(rooms[1]), "the waiting record's state kept")
	var again: PackedByteArray = PackedByteArray()
	assert_equal(fresh.capture(again), &"", "captured again")
	assert_true(again == bytes, "the same bytes")


func test_a_room_admitted_from_another_endpoint_is_dug_from_the_one_access() -> void:
	"""The northern room's admission approaches from the corridor endpoint level with its station; its dig keeps the
	one access the contacts are bound to (P-1936-1 (a)), and the crew reaches every cube from there."""
	if _runtime == null: return
	var result: Confirm.Result = _confirm(_painted(NORTH_Z, _worker_crew()), _way)
	assert_equal(result.code, &"", "ordered")
	var seen: Array[StringName] = []
	for step: int in TICK_BOUND:
		seen.append_array(_tick())
		if not _runtime.is_running() and _runtime.kept() == 0: break
	assert_equal(seen, [] as Array[StringName], "no refusal")
	assert_equal(_dug(result.room), 16, "dug")


func _stop_at_hand_over_then_reorder(operation: int) -> void:
	"""Stop on the tick the cube's working source is handed over to `operation`, then re-order and finish."""
	var wood: int = _h.free_milli(_h.material, &"wood")
	var room: Vector2i = _confirm(_painted(Phase.Z, _worker_crew()), _way).room
	var builder: Builder = _runtime.foreman_of(room).builders()[0]
	var step: int = 0
	while not (builder._operation == operation and builder.stage() == Builder.STAGE_START) and step < TICK_BOUND:
		_tick(); step += 1
	assert_equal(builder._operation, operation, "just handed over")
	var actor: Routes.Actor = Routes.Actor.new()
	assert_equal(_h._routes.read_actor_into(_h._worker, actor), &"", "the actor")
	assert_equal(actor.job, _h._jobs.ref_of(builder._job), "holding the new phase's Job")
	assert_equal(_runtime.stop_room(room), &"", "stopped")
	assert_true(builder._release_pending, "waiting for READY in the source before releasing")
	var seen: Array[StringName] = []
	while _runtime.kept() > 0 and step < TICK_BOUND:
		seen.append_array(_tick()); step += 1
	assert_equal(seen, [] as Array[StringName], "no refusal, no stuck builder")
	assert_equal(_runtime.state_of(room), Runtime.RECORD_NONE, "out and released")
	assert_equal(_h._routes._lost_actor_row(_h._worker), -1, "no route actor left")
	assert_equal(_projects_on(room), 0, "the unstarted phase was cancelled unpaid")
	var again: Composer.Order = Composer.Order.new()
	again.room = room; again.access = _h._first; again.travel = _h.provider._ordinary_travel
	again.storage = _h.material; again.output = _h.material
	assert_equal(Composer.order(_runtime, _h.placements, again), &"", "ordered again (the first idle mole)")
	while (_runtime.is_running() or _runtime.kept() > 0) and step < TICK_BOUND:
		seen.append_array(_tick()); step += 1
	assert_equal(seen, [] as Array[StringName], "no refusal")
	assert_equal(_dug(room), StationTests.KITCHEN_SITES, "dug whole")
	assert_equal(wood - _h.free_milli(_h.material, &"wood"), StationTests.KITCHEN_SITES * Contract.BRACE_WOOD_MILLI,
		"every BRACE paid once")


func test_a_stop_just_after_a_hand_over_waits_for_ready_under_the_actors_job_then_walks_out() -> void:
	"""Decision 1937's review M1, reachable now that the player can stop (item 24 of decision 1990): stopped on the
	tick its BRACE handed the working source over to CUT, the builder asks for READY under the Job and row the actor
	actually holds, waits for it without a refusal, releases the unstarted CUT, walks out and the record is released;
	a re-order then continues the BRACED cube with its CUT (the C2 defect decision 1991 found) and finishes the room
	with every BRACE paid once."""
	if _runtime == null: return
	_stop_at_hand_over_then_reorder(Contract.OP_CUT)


func test_a_stop_at_the_hand_over_to_finish_continues_the_cube_with_its_finish() -> void:
	"""The same at the CUT to FINISH hand-over: the cube is left open and unfinished, and a re-order FINISHes it."""
	if _runtime == null: return
	_stop_at_hand_over_then_reorder(Contract.OP_FINISH)


func test_a_cube_with_no_live_phase_is_continued_from_its_own_phase() -> void:
	"""`_next_operation` by Sites' record: solid or backfilled is BRACEd; braced or mid-cut is CUT; open or
	mid-finish is FINISHed."""
	if _runtime == null: return
	var room: Vector2i = _confirm(_painted(Phase.Z, _worker_crew()), _way).room
	var builder: Builder = _runtime.foreman_of(room).builders()[0]
	var site: Vector2i = Vector2i(_sites_of(room)[0], Sites.SITE_GENERATION)
	var kept: int = _h.sites._phase[site.x]
	var expected: Dictionary = {Sites.SOLID: Contract.OP_BRACE, Sites.BACKFILLED: Contract.OP_BRACE,
		Sites.BRACING: Contract.OP_BRACE, Sites.BRACED: Contract.OP_CUT, Sites.CUTTING: Contract.OP_CUT,
		Sites.OPEN_UNFINISHED: Contract.OP_FINISH, Sites.FINISHING: Contract.OP_FINISH}
	for phase: int in expected:
		_h.sites._phase[site.x] = phase # Negative-only: the mapping read in isolation.
		assert_equal(builder._next_operation(site), expected[phase], "phase %d" % phase)
	_h.sites._phase[site.x] = kept
