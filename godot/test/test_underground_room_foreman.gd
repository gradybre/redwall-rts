extends "res://test/framework/test_case.gd"
## Decision 1933 (C2.1): the production room foreman, driven only by `advance(tick)` on the fixed tick, over the
## ADR1161/1213 Kitchen fixture. P-C2-1 add-on ("Yes, tests only"): the fixture runs the retired content-6 pick rows
## to test the dispatch logic only; no height or price is taken from them (the Kitchen's 8 Sites are the fixture's own
## DEC-054 clamp). Every owner is the real one; nothing is injected.

const StationTests := preload("res://test/test_underground_room_station_planner.gd")
const Phase := preload("res://test/test_underground_room_world_phases.gd")
const Foreman := preload("res://scripts/core/underground_room_foreman.gd")
const Builder := preload("res://scripts/core/underground_room_builder.gd")
const DigOrder := preload("res://scripts/core/underground_room_dig_order.gd")
const Contract := preload("res://scripts/core/excavation_contract.gd")
const Sites := preload("res://scripts/core/excavation_sites.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Inventory := preload("res://scripts/core/inventory.gd")
const Schedule := preload("res://scripts/core/schedule.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const KITCHEN_SITES: int = StationTests.KITCHEN_SITES
const TICK_BOUND: int = 20000
const REST_HOUR: int = 2


class Kitchen extends StationTests.StepFixture:
	## The ADR1213 loop fixture with the worker starting on its parking endpoint, as a crew member does.

	func owners() -> Builder.Owners:
		"""The fixture's actual owners as the foreman borrows them."""
		var o: Builder.Owners = Builder.Owners.new()
		o.provider = provider; o.sites = sites; o.jobs = _jobs; o.work = _work; o.routes = _routes
		o.binding = _binding; o.residents = _residents; o.pool = _pool; o.inventory = _inventory
		o.profiles = _profiles; o.construction = _construction; o.items = _items; o.owner = _owner; o.budget = _budget
		o.transforms = _transforms
		return o

	func crew_member() -> Builder.Crew:
		"""The fixture's mole, standing on its parking endpoint with its (retired-content) pick."""
		assert_true(_transforms.place(_worker, Phase.X - 3072, Phase.FLOOR, Phase.Z + 512, YAW_PLUS_X), "parked pose")
		var member: Builder.Crew = Builder.Crew.new()
		member.worker = _worker; member.tool = tool; member.parking = parking
		return member

	func second_member(point: Vector3i) -> Builder.Crew:
		"""A second real mole with its own pick, parked on a new endpoint joined to the access by real spans."""
		var spot: Vector2i = _endpoint(point, Locations.ROLE_TRANSIT)
		var token: int = _begin()
		for reverse: bool in [false, true]:
			var edge: Routes.Edge = _edge()
			edge.from_location = _first if reverse else spot; edge.to_location = spot if reverse else _first
			var a: Vector3i = Vector3i(Phase.X - 1024, Phase.FLOOR, Phase.Z + 512)
			var from: Vector3i = a if reverse else point
			var to: Vector3i = point if reverse else a
			edge.points = PackedInt32Array([from.x, from.y, from.z, to.x, to.y, to.z])
			edge.length_u = _ceil_length(from - to)
			assert_equal(_routes.stage_add(token, edge).error, &"", "second parking span")
		assert_equal(_binding.seal(token), &"", "second parking certificates")
		assert_equal(_binding.publish(token), &"", "second parking publication")
		_end(token)
		return _mole_at(point, spot)

	static func _ceil_length(delta: Vector3i) -> int:
		"""Routes' own rule: the ceil of the integer Euclidean length."""
		var square: int = delta.x * delta.x + delta.y * delta.y + delta.z * delta.z
		var root: int = int(sqrt(float(square)))
		while root * root < square: root += 1
		while root > 0 and (root - 1) * (root - 1) >= square: root -= 1
		return root

	func _mole_at(point: Vector3i, spot: Vector2i) -> Builder.Crew:
		"""Spawn, schedule and equip one more mole, still far off on the surface: it arrives on its parking when the
		foreman registers it (ADR1219's arrival)."""
		var mole: Vector2i = _residents.ref_of(_residents.spawn(&"mole").value)
		assert_true(_transforms.place(mole, point.x + 60000, 512, point.z, YAW_PLUS_X), "second mole far off")
		var pick: Vector2i = stock(&"tool", 1000)
		assert_true(_gear.create_gear(_inventory, _items, pick, Gear.MANUFACTURE_BASIC).ok, "second pick")
		assert_true(_gear.equip(pick, mole).ok, "second carried pick")
		var row: int = _residents.directory().get_typed_row(mole)
		assert_true(_jobs.priorities().spawn(row).ok, "priorities")
		assert_true(_jobs.schedule().spawn(row, _jobs.schedule().default_template_id().value).ok, "schedule")
		assert_true(_jobs.schedule().resolve(row, 8, false).ok and _jobs.spawn_agent(row).ok, "availability")
		var member: Builder.Crew = Builder.Crew.new()
		member.worker = mole; member.tool = pick; member.parking = spot
		return member

	func run(foreman: Foreman, bound: int) -> StringName:
		"""Advance only the foreman, one fixed tick at a time, until it stops or the bound is reached."""
		var code: StringName = &""
		for step: int in bound:
			tick += 1
			code = foreman.advance(tick)
			if not foreman.is_running(): return code
		return &"BOUND"


var _h: Kitchen = null


func after_each() -> void:
	"""Propagate the fixture's own assertions and free every owner."""
	if _h != null:
		_h.after_each()
		assert_true(_h.failures.is_empty(), "actual fixture: %s" % _h.failures)
	_h = null


func _started(crew: Array[Builder.Crew]) -> Foreman:
	"""A confirmed Kitchen and a configured foreman, or null with the fixture's failures."""
	_h = Kitchen.new()
	var room: Vector2i = _h.confirmed_room()
	if room == NULL_REF: return null
	if crew.is_empty(): crew.append(_h.crew_member())
	var foreman: Foreman = Foreman.new()
	assert_equal(foreman.configure(_h.owners(), room, _h.material, _h.material, crew), &"", "configured")
	return foreman


func test_one_builder_digs_the_whole_kitchen_on_the_fixed_tick() -> void:
	"""Driven only by advance(tick): all eight cubes paid exactly, in breadth-first order, the builder parked."""
	var foreman: Foreman = _started([])
	if foreman == null: return
	var code: StringName = _h.run(foreman, TICK_BOUND)
	assert_equal(code, &"", "no refusal")
	assert_equal(foreman.state(), Foreman.STATE_DONE, "the room is done")
	assert_equal(foreman.done_cubes(), KITCHEN_SITES, "every cube done by Sites' record")
	var builder: Builder = foreman.builders()[0]
	assert_equal(builder.cubes(), KITCHEN_SITES, "one builder finished all eight")
	assert_equal(builder.accepted_mwu(), KITCHEN_SITES * (Contract.BRACE_WORK_MWU + Contract.CUT_WORK_MWU + Contract.FINISH_WORK_MWU), "work")
	_assert_paid(KITCHEN_SITES)
	_assert_parked(_h._worker, _h.parking)
	print("ROOM-FOREMAN ticks=%d up-column=%d tries=%d" % [_h.tick, builder.column_cubes(), foreman.column_tries()])
	assert_true(foreman.column_tries() > 0, "a finished cube's builder was offered the cube above it first")
	assert_equal(foreman.blocked_ticks(), 0, "one builder never waits on another")
	var again: Foreman = Foreman.new()
	assert_equal(again.configure(_h.owners(), foreman.room(), _h.material, _h.material, [_h.crew_member()]), &"", "a dug room")
	assert_equal(again.done_cubes(), KITCHEN_SITES, "already done by Sites' record")
	_h.tick += 1
	assert_equal(again.advance(_h.tick), &"", "nothing to do")
	assert_equal(again.state(), Foreman.STATE_DONE, "done at once")


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


func test_a_builder_rests_at_its_station_when_the_hour_forbids_work_and_carries_on_after() -> void:
	"""ADR1226 / REQ-SET-034: the hour turns to rest while a phase is worked or about to start. Every excavation phase
	is shorter than Work's 30-WU safe segment, so the phase completes, the source recovers to READY at the station
	and the builder waits there without a Job; when the hour allows work again it opens the next phase. Nothing is
	paid twice and the whole Kitchen still ends with exact ledgers."""
	var foreman: Foreman = _started([])
	if foreman == null: return
	var builder: Builder = foreman.builders()[0]
	var row: int = _h._residents.directory().get_typed_row(_h._worker)
	assert_equal(_h._jobs.schedule().hour_activity_of(row, REST_HOUR).value, Schedule.ACTIVITY_SLEEP, "a sleeping hour")
	var rests: PackedInt32Array = PackedInt32Array()
	for step: int in TICK_BOUND:
		_h.tick += 1
		assert_equal(foreman.advance(_h.tick), &"", "no refusal")
		_rest_step(foreman, builder, row, rests)
		if not foreman.is_running(): break
	assert_equal(rests, PackedInt32Array([Builder.STAGE_BETWEEN, Builder.STAGE_BETWEEN, Builder.STAGE_COLUMN, Builder.STAGE_IDLE]),
		"between phases twice, at a column's end, and parked")
	assert_equal(foreman.state(), Foreman.STATE_DONE, "the room is done")
	assert_equal(builder.accepted_mwu(), KITCHEN_SITES * (Contract.BRACE_WORK_MWU + Contract.CUT_WORK_MWU + Contract.FINISH_WORK_MWU), "no work paid twice")
	_assert_paid(KITCHEN_SITES)


func _rest_step(foreman: Foreman, builder: Builder, row: int, rests: PackedInt32Array) -> void:
	"""Turn the hour to rest during two phases (cubes 1 and 2), at a column's end (cube 3) and while parked (cube 4),
	and wait each one out, recording where the builder rested."""
	var flip: int = Builder.STAGE_EARN if rests.is_empty() else Builder.STAGE_START
	if builder.stage() == flip and rests.size() < 2 and builder.cubes() == rests.size() + 1:
		assert_true(_h._jobs.schedule().resolve(row, REST_HOUR, false).ok, "the hour turns to rest")
	if builder.stage() == Builder.STAGE_BETWEEN:
		rests.append(builder.stage())
		_wait_out_rest(foreman, builder, row)
	elif (builder.at_column_end() and builder.cubes() == 3) or (builder.idle() and builder.cubes() == 4 and rests.size() < 4):
		rests.append(builder.stage()) # a rest hour also keeps it at its station, or parked, with nothing taken
		assert_true(_h._jobs.schedule().resolve(row, REST_HOUR, false).ok, "rest")
		_wait_out_rest(foreman, builder, row)


func _wait_out_rest(foreman: Foreman, builder: Builder, row: int) -> void:
	"""Sixty ticks of a rest hour change nothing; then the hour allows work again."""
	var stage: int = builder.stage()
	for wait: int in 60:
		_h.tick += 1
		assert_equal(foreman.advance(_h.tick), &"", "resting")
	assert_equal(builder.stage(), stage, "still resting while the hour forbids work")
	assert_true(_h._jobs.schedule().resolve(row, 8, false).ok, "a working hour again")
