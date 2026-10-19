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
