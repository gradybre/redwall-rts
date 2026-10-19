extends "res://test/room_heading_case.gd"
## Decision 1943: rooms on every side of their access are dug (the fixture: `room_heading_case.gd`). A Kitchen of
## 2 x 2 cells on each side of the Corridor by the claw mole, and east by a pick mole; a dig stopped while it earns a
## turned-heading cube's paid phase and ordered again; a turned-heading dig saved and restored before every tick.


func test_a_kitchen_east_of_its_access_is_dug() -> void:
	"""Straight out from the access, on its bound heading, as before."""
	dig_matrix(EAST, 2, 2)


func test_a_kitchen_north_of_its_access_is_dug() -> void:
	"""Across the Corridor's north end: the planner turns at the gateway and digs on the +Z heading."""
	dig_matrix(NORTH, 2, 2)


func test_a_kitchen_south_of_its_access_is_dug() -> void:
	"""Across the Corridor's south end, on the -Z heading."""
	dig_matrix(SOUTH, 2, 2)


func test_a_kitchen_west_of_its_access_is_dug() -> void:
	"""Behind the access, on the -X heading."""
	dig_matrix(WEST, 2, 2)


func test_a_pick_mole_digs_east_of_its_access() -> void:
	"""The held pick's own rows (content 12's pick READY and wall rows) dig the Kitchen on the bound heading. (On any
	other heading a pick mole cannot reach a face: its READY rows reach 142 u past its wall rows' anchor and content 12
	publishes the pick's finite step only at +X, decision 1943 §5.)"""
	dig_matrix(EAST, 2, 2, KITCHEN, true)


func test_a_dig_stopped_on_a_turned_heading_cube_and_ordered_again_is_finished() -> void:
	"""The north Kitchen stopped while its mole earns the paid phase of a cube struck on the +Z heading (a death:
	decision 1938's negative-only stop); the stopped dig keeps the phase and its station, and the room ordered again
	with another mole takes the phase over on that heading and is dug to the end, every BRACE paid once."""
	if not _prepared(): return
	var room: Vector2i = _h.side_room(NORTH, 2, 2)
	if room == NULL_REF: return
	var runtime: Runtime = _runtime(room, [_h.crew_member()] as Array[Builder.Crew])
	var builder: Builder = runtime.foreman_of(room).builders()[0]
	var bound: int = _h._profiles._live.fields[Profiles.F_YAW * _h._profiles._profile_capacity + _h.retreat_row]
	for step: int in TICK_BOUND:
		_h.top_up()
		_h.tick += 1
		assert_equal(runtime.advance(_h.tick), [] as Array[StringName], "no refusal before the stop")
		if builder.cubes() >= 2 and builder.stage() == Builder.STAGE_EARN and builder.accepted_mwu() > 0 \
				and builder._yaw(builder._work_profile) != bound: break
	assert_equal(builder.stage(), Builder.STAGE_EARN, "earning a paid phase")
	assert_true(builder._yaw(builder._work_profile) != bound, "on a turned heading")
	var station: Vector2i = builder.station()
	var row: int = _h._residents.directory().get_typed_row(_h._worker)
	_h._jobs.needs()._status[row] = Needs.STATUS_DEAD # Negative-only: the dig stops mid-phase.
	_h._jobs.needs()._health[row] = 0
	var stopped: Dig = _dig(runtime)
	assert_equal(stopped.refusals, [Builder.REFUSE_LOST] as Array[StringName], "stopped by the loss")
	assert_equal(runtime.state_of(room), Runtime.RECORD_STOPPED, "stopped, its crew out")
	assert_true(_h.endpoints.is_live_location(station), "the paid phase's station kept")
	assert_equal(_h._construction.live_project_count(), 1, "the paid phase kept")
	assert_equal(runtime.release_room(room), &"", "released")
	assert_equal(runtime.order_room(room, _h.material, _h.spoil, NULL_REF), &"", "ordered again")
	var second: Builder.Crew = _h.second_member(ClawTests.SECOND_PARKING)
	assert_equal(runtime.start_room(room, runtime.bound_owners(), [second] as Array[Builder.Crew]), &"", "started again")
	var run: Dig = _dig(runtime)
	assert_equal(run.refusals, [] as Array[StringName], "no refusal after the re-order")
	assert_equal(_dug(room), _h.painted_cubes, "every cube dug")
	assert_equal(_h._construction.live_project_count(), 0, "no live Project")
	assert_true(_h._budget.is_quiescent(), "no cold lease left")
	assert_equal(_h.wood_made - _h.free_milli(_h.material, &"wood"), _h.painted_cubes * Contract.BRACE_WOOD_MILLI,
		"every BRACE's wood paid exactly once")


func test_a_turned_heading_dig_restored_before_every_tick_ends_as_the_uninterrupted_dig() -> void:
	"""ARCH-SAVE-006 on a turned heading: two worlds dig the north Kitchen; A's runtime is saved and restored into a
	fresh runtime before every tick. After every tick the two records are the same bytes, and at the end so are the
	two graphs and Locations banks."""
	var b_fixture: SideRooms = SideRooms.new()
	var room_b: Vector2i = b_fixture.side_room(NORTH, 2, 2) if b_fixture.prepared() else NULL_REF
	var room_a: Vector2i = _h.side_room(NORTH, 2, 2) if _prepared() else NULL_REF
	if room_a == NULL_REF or room_b == NULL_REF:
		b_fixture.after_each()
		return
	var a: Runtime = _runtime(room_a, [_h.crew_member()] as Array[Builder.Crew])
	var b: Runtime = Runtime.new(b_fixture._residents.directory())
	assert_true(b.bind_owners(b_fixture.owners()), "owners b")
	assert_equal(b.order_room(room_b, b_fixture.material, b_fixture.spoil, NULL_REF), &"", "ordered b")
	assert_equal(b.start_room(room_b, b.bound_owners(), [b_fixture.crew_member()] as Array[Builder.Crew]), &"", "started b")
	var swaps: int = 0
	for step: int in TICK_BOUND:
		a = _swap(a)
		swaps += 1
		for fixture: SideRooms in [_h, b_fixture]:
			fixture.top_up()
			fixture.tick += 1
		assert_equal(a.advance(_h.tick).duplicate(), b.advance(b_fixture.tick).duplicate(), "same refusals")
		if not _same_record(a, b): break
		if not a.is_running() and not b.is_running(): break
	assert_false(a.is_running() or b.is_running(), "both digs finished")
	assert_equal(_dug(room_a), _h.painted_cubes, "every cube dug")
	assert_true(swaps > 1000, "restored before %d ticks" % swaps)
	assert_true(_image(_h._routes) == _image(b_fixture._routes, b_fixture._budget), "the same graph")
	assert_true(_image(_h.endpoints) == _image(b_fixture.endpoints, b_fixture._budget), "the same Locations")
	b_fixture.after_each()
	assert_true(b_fixture.failures.is_empty(), "fixture b: %s" % b_fixture.failures)


func _swap(runtime: Runtime) -> Runtime:
	"""Save the runtime and restore it into a fresh one over the same owners; the restored one saves the same bytes."""
	var bytes: PackedByteArray = PackedByteArray()
	assert_equal(runtime.capture(bytes), &"", "captured")
	var fresh: Runtime = Runtime.new(_h._residents.directory())
	assert_true(fresh.bind_owners(runtime.bound_owners()), "owners bound")
	assert_equal(fresh.restore(bytes), &"", "restored")
	var again: PackedByteArray = PackedByteArray()
	assert_equal(fresh.capture(again), &"", "captured again")
	assert_true(again == bytes, "the restored runtime saves the same record")
	return fresh


func _same_record(a: Runtime, b: Runtime) -> bool:
	"""Both runtimes save the same bytes."""
	var bytes_a: PackedByteArray = PackedByteArray()
	var bytes_b: PackedByteArray = PackedByteArray()
	assert_equal(a.capture(bytes_a), &"", "a captured")
	assert_equal(b.capture(bytes_b), &"", "b captured")
	assert_true(bytes_a == bytes_b, "the same record")
	return bytes_a == bytes_b


func _image(owner: Object, budget: Budget = null) -> PackedByteArray:
	"""An owner's own capture under a cold lease (Routes or Locations)."""
	var lease_owner: Budget = budget if budget != null else _h._budget
	var cold: int = lease_owner.acquire(Budget.COLD_BYTES)
	var image: PackedByteArray = PackedByteArray()
	assert_equal(owner.call(&"capture_state_into", cold, image), &"", "captured")
	assert_equal(lease_owner.release(cold), &"", "lease returned")
	return image


func test_the_heading_passes_classify_refusals() -> void:
	"""Which refusals move on to the next heading: a plan that reaches no contact, missing rows, a vertical face or a
	contact on a chain this row cannot walk (`_unreached`); after the bound heading also no travel rows or a search
	out of checks (`_passable`); a paid phase moves on when no contact, no walkable chain or no rows (`_resumable`).
	Any other refusal is returned."""
	for code: StringName in Planner.RANKED + [Planner.REFUSE_HEADING, Planner.REFUSE_VERTICAL, &"ROUTE_NOT_CONNECTED"]:
		assert_true(Planner._unreached(code) and Planner._passable(code), "%s moves on" % code)
	for code: StringName in [Planner.REFUSE_TRAVEL, Planner.REFUSE_CAPACITY]:
		assert_false(Planner._unreached(code), "%s stops the bound heading" % code)
		assert_true(Planner._passable(code), "%s passes a later heading" % code)
	for code: StringName in [&"", Planner.REFUSE_SCOPE, &"ROUTE_EDGE_REVISION", &"WORK_FACE_COLUMN_UNOPENED"]:
		assert_false(Planner._passable(code), "%s is returned" % code)
	for code: StringName in [Planner.Frontier.REFUSE_CONTACT, &"ROUTE_NOT_CONNECTED", Planner.REFUSE_HEADING]:
		assert_true(Planner._resumable(code), "%s resumes on the next heading" % code)
	for code: StringName in [&"", Planner.Frontier.REFUSE_ACTIVE, Planner.REFUSE_CAPACITY]:
		assert_false(Planner._resumable(code), "%s is returned" % code)


func test_a_straight_chain_keeps_three_stations_and_an_l_shaped_one_five() -> void:
	"""`_cap`: ADR 1213's three for a straight approach, the publication's five for an L-shaped one; spans are split at
	their integer midpoint rounded down on every axis, below zero too."""
	var q: Planner.Query = Planner.Query.new()
	assert_equal(Planner._cap(q), 3, "straight")
	q.cornered = true
	assert_equal(Planner._cap(q), Planner.Publication.MAX_STATIONS, "L-shaped")
	assert_equal(Planner.Publication.MAX_STATIONS, 5, "five")
	assert_equal(Planner._midpoint(Vector3i(-3, 0, 4), Vector3i(-2, 0, 4)), Vector3i(-3, 0, 4), "down below zero")
	assert_equal(Planner._midpoint(Vector3i(2, 0, -1), Vector3i(3, 0, -1)), Vector3i(2, 0, -1), "down above zero")


func test_turning_lines_are_each_tried_once_nearest_the_gateway_first() -> void:
	"""`_turning_lines` on the claw's ground row (reach 712): each void region's two planes along the heading set back
	by the reach, behind-the-gateway lines dropped, each distinct line once, nearest the gateway first."""
	if not _prepared(): return
	var room: Vector2i = _h.side_room(EAST, 2, 2)
	if room == NULL_REF: return
	var q: Planner.Query = _query(room)
	if q == null: return
	var start: int = q.start[q.axis]
	var boxes: Array = [[start + 2000, start + 3000], [start + 2000, start + 3000], [start + 100, start + 5000],
		[start - 5000, start - 1000]]
	q.counts[Planner.VOID] = boxes.size()
	for index: int in boxes.size():
		q.tables[Planner.VOID][index * 6 + q.axis] = boxes[index][0]
		q.tables[Planner.VOID][index * 6 + q.axis + 3] = boxes[index][1]
	assert_equal(Planner._ground_reach(q), 712, "the claw ground body's reach")
	var count: int = Planner._turning_lines(q)
	var lines: Array[int] = []
	for at: int in count: lines.append(int(q.lines[at] & 0xFFFFFFFF) - 2147483648)
	assert_equal(lines, [start + 812, start + 2288, start + 2712, start + 4288] as Array[int],
		"distinct, ahead of the gateway, nearest first")


func test_a_builder_walks_only_headings_its_rows_cover() -> void:
	"""`_walkable`: the claw's READY rows run every quarter turn; a yaw between them has none."""
	if not _prepared(): return
	for yaw: int in [0, 16384, 32768, 49152]:
		assert_true(Planner._walkable(_h.provider, yaw), "yaw %d" % yaw)
	assert_false(Planner._walkable(_h.provider, 8192), "no rows at yaw 8192")


func _query(room: Vector2i) -> Planner.Query:
	"""A planner Query held for the room's first open cube, its region tables filled (no plan is made)."""
	var cold: int = _h._budget.acquire(Budget.COLD_BYTES)
	var candidate: Planner.Frontier.Candidate = Planner.Frontier.Candidate.new()
	var code: StringName = Planner.Frontier.next_site_into(_h.provider, room, -1, cold, Space.MAX_CHECKS, candidate)
	assert_equal(code, &"", "a candidate")
	var q: Planner.Query = Planner.Query.new()
	var yaw: int = Planner._retreat_yaw(_h.provider)
	Planner._hold(q, _h.provider, candidate, Planner.facing_face(_h.provider, yaw), yaw, Space.MAX_CHECKS)
	if code == &"": code = Planner._sources(q, _h.provider)
	if code == &"": code = Planner._gateway(q, _h.provider)
	if code == &"": code = Planner._regions(q)
	assert_equal(code, &"", "region tables")
	_h._budget.release(cold)
	return q if code == &"" else null


func test_runs_split_at_section_boundaries_as_each_plan_says() -> void:
	"""On the Kitchen's own section table (the Corridor's floor to x = X + 2048, the Kitchen's beyond), each run's
	first refusal names how it was split, the Kitchen still undug: ADR 1213's split (PLAN_MASTER) refuses a decreasing
	run across the boundary outright (SECTION, rank 2); decision 1943's splits it at the boundary, whose first span
	then fails its sweep into the undug room (rank 1). Going up from one unit below the boundary, that unit is its own
	span in the Corridor (its sweep fails, rank 1), not a span refused across the boundary (rank 2)."""
	if not _prepared(): return
	var room: Vector2i = _h.side_room(EAST, 2, 2)
	if room == NULL_REF: return
	var q: Planner.Query = _query(room)
	if q == null: return
	var boundary: int = Phase.X + 2048
	var inside: Vector3i = Vector3i(boundary + 512, Phase.FLOOR, Phase.Z + 512)
	var outside: Vector3i = Vector3i(boundary - 1000, Phase.FLOOR, Phase.Z + 512)
	q.direction = -1
	for master: bool in [true, false]:
		q.master = master; q.rank = -1; q.stations = 0
		assert_false(Planner._legs(q, inside, outside, q.forward, q.backward), "no decreasing run into undug ground")
		assert_equal(q.rank, 2 if master else 1, "master refuses the crossing" if master else "decision 1943 splits it")
	q.direction = 1; q.master = false; q.rank = -1; q.stations = 0
	assert_false(Planner._run(q, Vector3i(boundary - 1, Phase.FLOOR, Phase.Z + 512), inside, q.forward, q.backward, 0, 1),
		"no run into undug ground")
	assert_equal(q.rank, 1, "the unit below the boundary is a span of its own")
