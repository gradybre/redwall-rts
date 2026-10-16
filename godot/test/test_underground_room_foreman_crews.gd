extends "res://test/framework/test_case.gd"
## Decision 1933 (C2.1): the room foreman with a crew of two (ECON-001), a builder sent on from its station, and a
## full spoil pile. Kitchen fixture from test_underground_room_foreman.gd (retired content-6 pick rows, tests only).

const ForemanTests := preload("res://test/test_underground_room_foreman.gd")
const Phase := preload("res://test/test_underground_room_world_phases.gd")
const Foreman := preload("res://scripts/core/underground_room_foreman.gd")
const Builder := preload("res://scripts/core/underground_room_builder.gd")
const DigOrder := preload("res://scripts/core/underground_room_dig_order.gd")
const Contract := preload("res://scripts/core/excavation_contract.gd")
const Sites := preload("res://scripts/core/excavation_sites.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Inventory := preload("res://scripts/core/inventory.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const KITCHEN_SITES: int = ForemanTests.KITCHEN_SITES
const TICK_BOUND: int = ForemanTests.TICK_BOUND
## In the widened Corridor: clear of the first parking's line and of every station chain the Kitchen publishes, and
## inside the Corridor by the all-yaw ground row's widest box (1,256 u), so its span is certified for that row.
const SECOND_PARKING: Vector3i = Vector3i(Phase.X - 1024, Phase.FLOOR, Phase.Z - 3072)
const WIDE_SOUTH: int = 4096


class WideKitchen extends ForemanTests.Kitchen:
	## The same Kitchen and access, with the old Corridor bootstrap reaching 4 m further south: room for a second
	## builder to park clear of the first one's line and of every Kitchen station chain (the held pick reaches 910 u
	## sideways). Test geometry only; it changes no rule.

	func _bootstrap_corridor() -> void:
		"""The explicit old Corridor rows, widened to the south by WIDE_SOUTH."""
		var token: int = _owner.begin_stage(_owner.revision()).token
		assert_equal(_owner.stage_source(token, corridor), &"", "old Room source")
		var low_z: int = Phase.Z - 2048 - WIDE_SOUTH
		_floor = _bootstrap_region(token, PackedInt32Array([Phase.X - 4096, Phase.FLOOR, low_z, Phase.X + 2048, Phase.FLOOR + 1, Phase.Z + 4096]), Phase.Space.FLOOR_DATUM)
		_bootstrap_region(token, PackedInt32Array([Phase.X - 4096, Phase.FLOOR, low_z, Phase.X + 2048, Phase.FLOOR + 4096, Phase.Z + 4096]), Phase.Space.SUPPORTED_VOID)
		_bootstrap_region(token, PackedInt32Array([Phase.X - 4096, Phase.FLOOR - 1024, low_z, Phase.X + 2048, Phase.FLOOR, Phase.Z + 4096]), Phase.Space.SUPPORT)
		assert_equal(_owner.seal(token), &"", "widened old corridor geometry")
		_owner.publish(token)
		@warning_ignore("integer_division") var south: int = -2 - WIDE_SOUTH / 1024
		for x: int in range(-4, 2):
			for z: int in range(south, 4):
				assert_true(sites.claim_quantum(Vector3i(Phase.X + x * 1024, Phase.FLOOR, Phase.Z + z * 1024), corridor).ok, "bootstrap Site")

	func _endpoint(point: Vector3i, role: int) -> Vector2i:
		"""As the base fixture's endpoint, with the widened Corridor as its body air."""
		var row: Locations.Record = Locations.Record.new()
		row.point = point; row.section = _floor; row.room = corridor; row.level = 1
		row.role = Locations.ROLE_STORAGE if role == Locations.ROLE_TRANSIT else role
		row.envelope = PackedInt32Array([Phase.X - 4096, Phase.FLOOR, Phase.Z - 2048 - WIDE_SOUTH, Phase.X + 2048, Phase.FLOOR + 4096, Phase.Z + 4096])
		row.support = PackedInt32Array([point.x - 406, Phase.FLOOR - 1, point.z - 406, point.x + 406, Phase.FLOOR, point.z + 406])
		var cold: int = _budget.acquire(Phase.Budget.COLD_BYTES)
		var token: int = endpoints.begin_prepare(cold).token
		var result: Locations.Result = endpoints.stage_add(token, row)
		assert_equal(result.error, &"", "supported endpoint")
		assert_equal(endpoints.seal(token), &"", "current endpoint")
		assert_true(endpoints.publish(token), "endpoint published")
		assert_equal(_budget.release(cold), &"", "same lease returned")
		return result.location


var _h: ForemanTests.Kitchen = null


func after_each() -> void:
	"""Propagate the fixture's own assertions and free every owner."""
	if _h != null:
		_h.after_each()
		assert_true(_h.failures.is_empty(), "actual fixture: %s" % _h.failures)
	_h = null


func _started() -> Foreman:
	"""A confirmed Kitchen and a one-builder foreman, or null with the fixture's failures."""
	_h = ForemanTests.Kitchen.new()
	var room: Vector2i = _h.confirmed_room()
	if room == NULL_REF: return null
	var foreman: Foreman = Foreman.new()
	assert_equal(foreman.configure(_h.owners(), room, _h.material, _h.material, NULL_REF, [_h.crew_member()]), &"", "configured")
	return foreman


func _assert_paid(cubes: int) -> void:
	"""Exact bills, earth and support for the paid cubes, no live Project and no cold lease left."""
	assert_equal(_h._inventory.lot_quantity_milli(_h.stock_wood), (KITCHEN_SITES - cubes) * Contract.BRACE_WOOD_MILLI, "wood")
	assert_equal(_h._inventory.lot_quantity_milli(_h.stock_stone), (KITCHEN_SITES - cubes) * Contract.BRACE_STONE_MILLI, "stone")
	assert_equal(_h.sites.virgin_sourced_milli(), cubes * Contract.EARTH_MILLI, "only CUT made earth")
	assert_equal(_h.sites.support_conservation_refusal(), &"", "support conserved")
	assert_equal(_h.sites.earth_conservation_refusal(), &"", "earth conserved")
	assert_equal(_h._construction.live_project_count(), 0, "no live Project")
	assert_true(_h._budget.is_quiescent(), "no cold lease outlives the dig")


func _assert_parked(worker: Vector2i, parking: Vector2i) -> void:
	"""The builder ends on its own parking endpoint by real travel."""
	var actor: Routes.Actor = Routes.Actor.new()
	assert_equal(_h._routes.read_actor_into(worker, actor), &"", "actual worker")
	assert_equal(actor.location, parking, "parked by real travel")


func test_two_builders_share_the_kitchen_without_sharing_a_cube() -> void:
	"""ECON-001: two builders, one worker per cube face; both dig, they take turns where their footprints meet, the
	room is dug exactly once, and each builder parks again."""
	var foreman: Foreman = _two()
	if foreman == null: return
	var first: Builder = foreman.builders()[0]
	var second: Builder = foreman.builders()[1]
	var together: int = 0
	for step: int in TICK_BOUND:
		_h.tick += 1
		assert_equal(foreman.advance(_h.tick), &"", "no refusal")
		together = maxi(together, int(_working(first)) + int(_working(second)))
		if not foreman.is_running(): break
	assert_equal(foreman.state(), Foreman.STATE_DONE, "the room is done")
	assert_equal(first.cubes() + second.cubes(), KITCHEN_SITES, "each cube finished exactly once")
	assert_true(first.cubes() > 0 and second.cubes() > 0, "both builders dug")
	assert_true(foreman.blocked_ticks() > 0, "they took turns where their footprints met")
	print("ROOM-FOREMAN-TWO ticks=%d first=%d second=%d together=%d blocked=%d" % [_h.tick, first.cubes(),
		second.cubes(), together, foreman.blocked_ticks()])
	_assert_paid(KITCHEN_SITES)
	_assert_parked(foreman.builders()[0].crew().worker, foreman.builders()[0].crew().parking)
	_assert_parked(foreman.builders()[1].crew().worker, foreman.builders()[1].crew().parking)


func _two() -> Foreman:
	"""The widened Kitchen and a two-builder foreman, or null with the fixture's failures."""
	_h = WideKitchen.new()
	var room: Vector2i = _h.confirmed_room()
	if room == NULL_REF: return null
	var crew: Array[Builder.Crew] = [_h.crew_member(), _h.second_member(SECOND_PARKING)]
	if not _h.failures.is_empty(): return null
	var foreman: Foreman = Foreman.new()
	assert_equal(foreman.configure(_h.owners(), room, _h.material, _h.material, NULL_REF, crew), &"", "configured")
	return foreman


static func _working(builder: Builder) -> bool:
	"""At a station with a phase in hand (entering, starting, earning, recovering or between phases)."""
	var stage: int = builder.stage()
	return stage == Builder.STAGE_ENTER or stage == Builder.STAGE_START or stage == Builder.STAGE_EARN \
		or stage == Builder.STAGE_RECOVER or stage == Builder.STAGE_BETWEEN


func test_a_crew_that_can_never_move_again_stops_the_room_and_releases_its_phase() -> void:
	"""Negative-only: one open cube, taken by the first builder, whose footprint is made to meet the second builder's
	parked body; the second has nothing to take, so nothing can ever change. The room stops with
	ROOM_FOREMAN_CREW_BLOCKED instead of waiting forever, and the unpaid BRACE is cancelled."""
	var foreman: Foreman = _two()
	if foreman == null: return
	for at: int in foreman._cube.size(): foreman._cube[at] = Foreman.CUBE_DONE if at > 0 else Foreman.CUBE_OPEN
	_h.tick += 1
	assert_equal(foreman.advance(_h.tick), &"", "registered; the first builder takes the one cube")
	var first: Builder = foreman.builders()[0]
	assert_true(first.walking_next() and not first.in_motion(), "about to set off")
	var body: PackedInt32Array = foreman.builders()[1]._foot.body()
	for axis: int in 6: body[axis] = first.claim()[axis] # The second builder now stands in the first one's way.
	foreman._epoch += 1
	_h.tick += 1
	assert_equal(foreman.advance(_h.tick), Foreman.REFUSE_BLOCKED, "named, not a silent wait")
	assert_equal(foreman.state(), Foreman.STATE_FAILED, "stopped")
	assert_equal(foreman.abandon_error(), &"", "released cleanly")
	assert_equal(_h._construction.live_project_count(), 0, "the unpaid BRACE was cancelled")
	assert_equal(_h._inventory.lot_quantity_milli(_h.stock_wood), KITCHEN_SITES * Contract.BRACE_WOOD_MILLI, "nothing paid")
	var row: int = _h._residents.directory().get_typed_row(first.crew().worker)
	assert_equal(_h._jobs.job_of(row), NULL_REF, "the resident holds no Job")


func test_a_builder_at_its_station_cannot_publish_a_new_chain_and_goes_home() -> void:
	"""ADR1213 "Parking": a chain cannot be published while a worker stands on it. Sent on from READY at a finished
	cube's station to a cube that needs new stations, the builder is refused, stays at its station, and the foreman
	then walks it home; the cube is dug later from parking. (Under painted height an upper cube is paid from its
	column's floor station, decision 1971, and needs no new chain.)"""
	var foreman: Foreman = _started()
	if foreman == null: return
	var builder: Builder = foreman.builders()[0]
	var order: DigOrder.Order = foreman.order()
	for step: int in TICK_BOUND:
		_h.tick += 1
		assert_equal(foreman.advance(_h.tick), &"", "no refusal")
		if builder.at_column_end() and builder.last_index() == 3: break
	assert_true(builder.at_column_end(), "READY at the first column's floor station, its top cube done")
	assert_equal(builder.column_cubes(), 3, "the column's three upper cubes were taken from that station")
	var site: Vector2i = Vector2i(order.rows[4], Sites.SITE_GENERATION)
	var code: StringName = builder.continue_column(4, site, order.keys[4], _h.tick)
	assert_equal(code, &"ROUTE_OCCUPIED", "its own body blocks the next column's chain")
	assert_true(builder.at_column_end(), "still READY at its station, nothing opened")
	assert_equal(builder.column_cubes(), 3, "nothing more taken")
	assert_equal(_h._construction.live_project_count(), 0, "no phase opened")
	code = _h.run(foreman, TICK_BOUND)
	assert_equal(code, &"", "no refusal")
	assert_equal(foreman.state(), Foreman.STATE_DONE, "the room is done from parking")
	_assert_paid(KITCHEN_SITES)


func test_a_full_spoil_pile_stops_the_room_before_any_unpaid_cut() -> void:
	"""ECON-003: CUT reserves its earth's room in the bound spoil pile before starting. Earth has no certified carry
	yet (grip certificate: wood and stone only), so a full pile stops the room with its refusal; the BRACE stays paid,
	nothing is cut, and no cube is counted done. The spoil pile here is its own container, apart from the stock."""
	_h = ForemanTests.Kitchen.new()
	var room: Vector2i = _h.confirmed_room()
	if room == NULL_REF: return
	var made: Inventory.OpResult = _h._inventory.create_spatial_ground_staging(_h.parking)
	assert_true(made.ok, "a second, separate pile: %s" % made.error)
	if not made.ok: return
	var pile: Vector2i = made.ref
	var earth: Inventory.OpResult = _h._inventory.create_lot(pile, _h._items.compiled_id(&"excavated_earth"),
		_h._inventory.container_free_mass_g(pile) - 1000, 1, 0, -1, 0, 0)
	assert_true(earth.ok, "the pile is all but full: %s" % earth.error)
	var foreman: Foreman = Foreman.new()
	assert_equal(foreman.configure(_h.owners(), room, _h.material, pile, NULL_REF, [_h.crew_member()]), &"", "configured")
	var code: StringName = _h.run(foreman, TICK_BOUND)
	assert_equal(code, Inventory.REFUSE_CAPACITY_EXCEEDED, "the pile's own refusal, named")
	assert_equal(foreman.state(), Foreman.STATE_FAILED, "the room stops")
	assert_equal(foreman.error(), Inventory.REFUSE_CAPACITY_EXCEEDED, "kept for the alert")
	assert_equal(foreman.done_cubes(), 0, "no cube shown done")
	assert_equal(_h.sites.virgin_sourced_milli(), 0, "nothing was cut")
	assert_equal(_h._inventory.lot_quantity_milli(_h.stock_wood), (KITCHEN_SITES - 1) * Contract.BRACE_WOOD_MILLI, "one BRACE paid")
	assert_equal(foreman.abandon_error(), &"", "released cleanly")
	assert_equal(_h._construction.live_project_count(), 0, "the unstarted CUT was cancelled, no Project left")
	assert_equal(_h._jobs.job_of(_h._residents.directory().get_typed_row(_h._worker)), NULL_REF, "the mole holds no Job")
