extends "res://test/framework/test_case.gd"
## Decision 1934 (C2.2, P-C22-1 "Same-level now + basic stair carry"): the same-level room Delivery, on the Kitchen
## fixture. A staging container R in the Corridor, its grip stand and the storage's stand are real endpoints joined by
## real WALK and CARRY spans; one Delivery is composed over the fixture's own owners. The builder walks to the room's
## storage M, the entry's hauler (unchanged) carries whole units from R through Delivery's room branch, and the BRACE
## claims them from M. Only the content-6 grip rows 31-41 haul, and they hold no tool (ADR1217), while the fixture's
## retired pick rows need the pick: so the room's storage M is the crew's parking endpoint, the pick goes into M before
## the haul and comes back after (a fixture step; the game's claw rows name no tool). A body parked on the Corridor
## access would close every later station chain, so M is not the access. No price, height or pace is taken from it.

const ForemanTests := preload("res://test/test_underground_room_foreman.gd")
const StationTests := preload("res://test/test_underground_room_station_planner.gd")
const Phase := preload("res://test/test_underground_room_world_phases.gd")
const CatalogTests := preload("res://test/test_underground_connector_catalog.gd")
const GroupTests := preload("res://test/test_underground_connector_assemblies.gd")
const Foreman := preload("res://scripts/core/underground_room_foreman.gd")
const Builder := preload("res://scripts/core/underground_room_builder.gd")
const Delivery := preload("res://scripts/core/underground_connector_delivery.gd")
const HaulPlanner := preload("res://scripts/core/haul_planner.gd")
const StorePolicy := preload("res://scripts/core/store_policy.gd")
const Clock := preload("res://scripts/core/sim_clock.gd")
const EntryFrontier := preload("res://scripts/core/underground_entry_frontier.gd")
const Hauler := preload("res://scripts/core/underground_entry_hauler.gd")
const Grip := preload("res://data/underground/mole-worker/qualified-claw-runtime-v1/grip_certificate.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Inventory := preload("res://scripts/core/inventory.gd")
const Contract := preload("res://scripts/core/excavation_contract.gd")
const Sites := preload("res://scripts/core/excavation_sites.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const Needs := preload("res://scripts/core/needs.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const KITCHEN_SITES: int = StationTests.KITCHEN_SITES
const TICK_BOUND: int = 24000
const FRONTIER_PATH: String = "user://room_haul_entry_frontier.ugfrnt"
## Relative to a stand: the content-5/6 grip rows' stance, foot residual and the stock's floor contact at S
## (`underground_entry_work_area.gd` STAND_FOOT, copied, not authored here).
const STAND_FOOT: Array[int] = [-579, -1, -412, 406, 0, 412]
## The staging container's endpoint: the same Corridor floor, 2 m beside the storage (fixture geometry only).
const SOURCE_POINT: Vector3i = Vector3i(Phase.X - 3072, Phase.FLOOR, Phase.Z + 2560)
## A second Corridor floor for the stair-carry gap's test (level 2; fixture geometry only).
const LOWER_FLOOR: int = Phase.FLOOR - 8192


class HaulKitchen extends ForemanTests.Kitchen:
	## The Kitchen with an empty storage, a stocked staging container, the two grip stands and one Delivery.
	var staging: Vector2i = NULL_REF
	var staging_at: Vector2i = NULL_REF
	var stand_store: Vector2i = NULL_REF
	var stand_source: Vector2i = NULL_REF
	var delivery: Delivery = null
	var entry_frontier: EntryFrontier = null
	var haul_planner: HaulPlanner = null
	var clock: Clock = null
	var lower_floor: Vector2i = NULL_REF

	func _load_catalog(revision: int) -> StringName:
		"""The Kitchen's rows plus the toolless WALK 31 and the CARRY rows 32 (wood) and 37 (stone), each at the existing
		Movement rate (RATE_GROUND_CAP, as the content-6 manifest's ground pace rule says): no pace is authored."""
		var bytes: PackedByteArray = Phase.GroupFixture._catalog_wire(4, revision)
		var rows: PackedInt32Array = PackedInt32Array([5, 9, 10, 11, 12, 31, 32, 37])
		bytes.encode_u32(44, rows.size()); bytes.encode_s64(48, StationTests.CONTENT)
		bytes.resize(bytes.size() - 80)
		for profile: int in rows:
			Phase.GroupFixture.Fixture._append_row(bytes, PackedInt32Array([profile, -1, 0, 1, 1, 0, Catalog.RATE_GROUND_CAP]), 1)
		var digest: PackedByteArray = PackedByteArray(); digest.resize(32)
		assert_true(_profiles.source_hash_into(0, StationTests.CONTENT, digest), "actual original actor source")
		for index: int in 32: bytes[72 + index] = digest[index]
		bytes.append_array("UGCEND01".to_ascii_buffer())
		return _catalog.load_file(TEMP, _write(TEMP, bytes), revision)

	func finite_stock_and_worker() -> void:
		"""The storage M, on the parking endpoint, holds only the pick: every brace input must be hauled in from R."""
		storage_binding = Locations.InventoryLocations.new(endpoints)
		assert_true(_inventory.bind_spatial_locations(storage_binding, 4).ok, "actual storage authority")
		var made: Inventory.OpResult = _inventory.create_spatial_ground_staging(parking)
		assert_true(made.ok, "the room's storage M: %s" % made.error)
		material = made.ref; storage = parking
		tool = stock(&"tool", 1000)
		assert_true(_gear.create_gear(_inventory, _items, tool, Gear.MANUFACTURE_BASIC).ok, "actual basic pick")
		assert_true(_gear.equip(tool, _worker).ok, "actual carried pick")
		var worker: int = _residents.directory().get_typed_row(_worker)
		assert_true(_jobs.priorities().spawn(worker).ok, "actual priorities")
		assert_true(_jobs.schedule().spawn(worker, _jobs.schedule().default_template_id().value).ok, "actual schedule")
		assert_true(_jobs.schedule().resolve(worker, 8, false).ok and _jobs.spawn_agent(worker).ok, "actual worker availability")

	func haul_room() -> Vector2i:
		"""A confirmed Kitchen, R stocked with one whole unit of wood and of stone, the stands and spans, Delivery."""
		var room: Vector2i = confirmed_room()
		if room == NULL_REF: return NULL_REF
		staging_at = _endpoint(SOURCE_POINT, Locations.ROLE_TRANSIT) # The SourceFixture maps this to STORAGE.
		var made: Inventory.OpResult = _inventory.create_spatial_ground_staging(staging_at)
		assert_true(made.ok, "the staging container R: %s" % made.error)
		staging = made.ref
		for key: StringName in [&"wood", &"stone"]:
			assert_true(_inventory.create_lot(staging, _items.compiled_id(key), Grip.QUANTITY_MILLI, 1, 0, -1, 0, 0).ok,
				"one whole staged %s unit" % key)
		var offset: Vector3i = Grip.stock_offset(Grip.QUARTER)
		stand_store = _stand(store_point() - offset)
		stand_source = _stand(SOURCE_POINT - offset)
		_publish_haul_spans()
		_compose_delivery()
		return room if failures.is_empty() else NULL_REF

	func store_point() -> Vector3i:
		"""M's endpoint: the crew's parking in the Corridor."""
		return Vector3i(Phase.X - 3072, Phase.FLOOR, Phase.Z + 512)

	func _stand(point: Vector3i) -> Vector2i:
		"""A WORK endpoint whose surveyed footing carries the grip rows' stance and the stock's contact at S."""
		var row: Locations.Record = Locations.Record.new()
		row.point = point; row.section = _floor; row.room = corridor; row.level = 1; row.role = Locations.ROLE_WORK
		row.envelope = PackedInt32Array([Phase.X - 4096, Phase.FLOOR, Phase.Z - 2048, Phase.X + 2048, Phase.FLOOR + 4096, Phase.Z + 4096])
		row.support = PackedInt32Array([point.x + STAND_FOOT[0], Phase.FLOOR + STAND_FOOT[1], point.z + STAND_FOOT[2],
			point.x + STAND_FOOT[3], Phase.FLOOR + STAND_FOOT[4], point.z + STAND_FOOT[5]])
		var cold: int = _budget.acquire(Budget.COLD_BYTES)
		var token: int = endpoints.begin_prepare(cold).token
		var result: Locations.Result = endpoints.stage_add(token, row)
		assert_equal(result.error, &"", "a grip stand")
		assert_equal(endpoints.seal(token), &"", "stand sealed")
		assert_true(endpoints.publish(token), "stand published")
		assert_equal(_budget.release(cold), &"", "same lease returned")
		return result.location

	func _publish_haul_spans() -> void:
		"""ADR1198's haul spans: M and its stand, the two stands both ways empty, and the loaded CARRY span that steps out
		by the stand offset and enters M's stand already on the grip heading (the work area's own shape)."""
		var offset: Vector3i = Grip.stock_offset(Grip.QUARTER)
		var m: Vector3i = store_point()
		var stand_m: Vector3i = m - offset
		var stand_r: Vector3i = SOURCE_POINT - offset
		var token: int = _begin()
		_span(token, parking, stand_store, [m, stand_m], Profiles.MODE_WALK)
		_span(token, stand_store, parking, [stand_m, m], Profiles.MODE_WALK)
		_span(token, stand_store, stand_source, [stand_m, stand_r], Profiles.MODE_WALK)
		_span(token, stand_source, stand_store, [stand_r, stand_m], Profiles.MODE_WALK)
		_span(token, stand_source, stand_store, [stand_r, stand_r - offset, stand_m - offset, stand_m], Profiles.MODE_CARRY)
		assert_equal(_binding.seal(token), &"", "haul span certificates")
		assert_equal(_binding.publish(token), &"", "haul span publication")
		_end(token)

	func _span(token: int, from: Vector2i, to: Vector2i, points: Array[Vector3i], mode: int) -> void:
		"""One straight-segment ground span; its length is the sum of Routes' own ceil-of-Euclid segment lengths."""
		var edge: Routes.Edge = _edge()
		edge.from_location = from; edge.to_location = to; edge.mode = mode
		edge.points = PackedInt32Array()
		edge.length_u = 0
		for index: int in points.size():
			edge.points.append_array(PackedInt32Array([points[index].x, points[index].y, points[index].z]))
			if index > 0: edge.length_u += _ceil_length(points[index] - points[index - 1])
		edge.point_count = points.size()
		assert_equal(_routes.stage_add(token, edge).error, &"", "a haul span")

	func _compose_delivery() -> void:
		"""The World's one Delivery over the fixture's owners, with a minimal valid entry Frontier source (Delivery is
		composed with the entry's; a room haul reads none of its rows)."""
		entry_frontier = EntryFrontier.new()
		var counts: PackedInt32Array = PackedInt32Array([2, 1, 1, 1, 1, 1])
		assert_equal(entry_frontier.configure(counts, EntryFrontier.required_bytes(counts)), &"", "finite frontier bank")
		assert_equal(entry_frontier.bind_actual(_catalog, groups._reader, groups._recipes, _profiles), &"", "source chain")
		var bytes: PackedByteArray = _frontier_image(counts)
		assert_equal(entry_frontier.load_file(FRONTIER_PATH, CatalogTests._write(FRONTIER_PATH, bytes), 1), &"", "frontier")
		haul_planner = HaulPlanner.new()
		assert_true(haul_planner.bind(_inventory, _pool, _residents, _buildings, _piles,
			StorePolicy.new(_buildings, _inventory)), "actual haul Planner")
		clock = Clock.new()
		delivery = Delivery.new()
		assert_equal(delivery.configure(placements, entry_frontier, haul_planner, _binding, _work, clock,
			Delivery.RESERVED_BYTES), &"", "one bounded Delivery")

	func _frontier_image(counts: PackedInt32Array) -> PackedByteArray:
		"""One row per table (two installations, one per grouped assembly), each valid against this Kitchen's sources."""
		var bytes: PackedByteArray = "UGFRNT01".to_ascii_buffer(); bytes.resize(EntryFrontier.WIRE_HEADER_BYTES)
		bytes.encode_u32(8, 1)
		var revisions: PackedInt64Array = PackedInt64Array([1, 1, 1, GroupTests.GROUP_REVISION, GroupTests.RECIPE_REVISION,
			StationTests.CONTENT])
		for index: int in 6: bytes.encode_s64(12 + 8 * index, revisions[index])
		for index: int in 6: bytes.encode_u32(68 + 4 * index, counts[index])
		for index: int in 32:
			bytes[92 + index] = groups._reader._digests[32 + index]
			bytes[124 + index] = groups._reader._digests[index]
			bytes[156 + index] = groups._reader._digests[64 + index]
			bytes[188 + index] = _profiles._live.sources[index]
		for ordinal: int in 2: CatalogTests._append_row(bytes, PackedInt32Array([ordinal, 0, 0, 0, 1, 0, 1, 0, 0]))
		CatalogTests._append_row(bytes, PackedInt32Array([0, 0, 0, 0, StationTests.YAW_PLUS_X, 27, Profiles.POSTURE_UPRIGHT,
			0, Jobs.JOB_KIND_BUILD]), 1)
		for row: int in [23, 19, 15]: CatalogTests._append_row(bytes, PackedInt32Array([row]), 1) # The same FRONT row turned.
		CatalogTests._append_row(bytes, PackedInt32Array([0, 0, 0, 1024, 1024, 1024, Sites.SUPPORTED_VOID]))
		CatalogTests._append_row(bytes, PackedInt32Array([EntryFrontier.NATURAL, -1, -1, 0, 0, 0, 1024, 1, 1024]))
		CatalogTests._append_row(bytes, PackedInt32Array([EntryFrontier.SURFACE_ANCHOR, -1, 0, Locations.ROLE_WORK, 0, 0, 0, 5]), 1)
		CatalogTests._append_row(bytes, PackedInt32Array([0, 0, 0, 1024, 1024, 1024, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]))
		bytes.append_array("UGFEND01".to_ascii_buffer())
		return bytes

	func _bootstrap_corridor() -> void:
		"""The Corridor's existing floor, and a second one 8 m lower (level 2) with its one paid Site under the lower
		storage, published before any route so no route geometry goes stale (fixture geometry only)."""
		super._bootstrap_corridor()
		var y: int = LOWER_FLOOR
		var token: int = _owner.begin_stage(_owner.revision()).token
		lower_floor = _lower_region(token, [Phase.X - 4096, y, Phase.Z - 2048, Phase.X + 2048, y + 1, Phase.Z + 4096],
			Space.FLOOR_DATUM, NULL_REF)
		_lower_region(token, [Phase.X - 4096, y, Phase.Z - 2048, Phase.X + 2048, y + 4096, Phase.Z + 4096], Space.SUPPORTED_VOID, lower_floor)
		_lower_region(token, [Phase.X - 4096, y - 1024, Phase.Z - 2048, Phase.X + 2048, y, Phase.Z + 4096], Space.SUPPORT, lower_floor)
		assert_equal(_owner.seal(token), &"", "lower floor sealed")
		_owner.publish(token)
		var claimed: Construction.OpResult = sites.claim_quantum(Vector3i(Phase.X - 3072, y, Phase.Z), corridor)
		assert_true(claimed.ok, "the lower storage's Site identity: %s" % claimed.error)

	func lower_staging() -> Vector2i:
		"""A STORAGE container on the lower Corridor floor."""
		var y: int = LOWER_FLOOR
		var lower: Vector2i = lower_floor
		var row: Locations.Record = Locations.Record.new()
		row.point = Vector3i(Phase.X - 3072, y, Phase.Z + 512); row.section = lower; row.room = corridor; row.level = 2
		row.role = Locations.ROLE_STORAGE
		row.envelope = PackedInt32Array([Phase.X - 4096, y, Phase.Z - 2048, Phase.X + 2048, y + 4096, Phase.Z + 4096])
		row.support = PackedInt32Array([row.point.x - 406, y - 1, row.point.z - 406, row.point.x + 406, y, row.point.z + 406])
		var cold: int = _budget.acquire(Budget.COLD_BYTES)
		var stage: int = endpoints.begin_prepare(cold).token
		var result: Locations.Result = endpoints.stage_add(stage, row)
		assert_equal(result.error, &"", "a lower storage endpoint")
		assert_equal(endpoints.seal(stage), &"", "lower endpoint sealed")
		assert_true(endpoints.publish(stage), "lower endpoint published")
		assert_equal(_budget.release(cold), &"", "same lease returned")
		var made: Inventory.OpResult = _inventory.create_spatial_ground_staging(result.location)
		assert_true(made.ok, "a lower staging container: %s" % made.error)
		return made.ref

	func _lower_region(token: int, box: Array[int], role: int, section: Vector2i) -> Vector2i:
		"""One Corridor region of the lower floor."""
		var region: Owner.Region = Owner.Region.new()
		region.box = PackedInt32Array(box); region.role = role; region.owner = corridor; region.level = 2
		region.section = section
		var result: Owner.Result = _owner.stage_add(token, region)
		assert_equal(result.error, &"", "lower region")
		return result.handle

	func haul_owners() -> Builder.Owners:
		"""The fixture's owners with the Delivery and the Locations the hauler reads."""
		var o: Builder.Owners = owners()
		o.delivery = delivery
		o.locations = endpoints
		return o

	func store_member() -> Builder.Crew:
		"""The fixture's mole with its pick, parked on M itself so the haul starts where it stands."""
		var member: Builder.Crew = Builder.Crew.new()
		member.worker = _worker; member.tool = tool; member.parking = parking
		return member

	func free_milli(container: Vector2i, key: StringName) -> int:
		"""Unreserved quantity of one item in one container."""
		return Hauler.free_milli(_inventory, container, _items.compiled_id(key))

	func after_each() -> void:
		"""Delivery and its Planner go before the fixture's owners."""
		delivery = null; haul_planner = null; entry_frontier = null; clock = null
		super.after_each()


var _h: HaulKitchen = null
var _room: Vector2i = NULL_REF


func before_each() -> void:
	"""One Kitchen with its haul stands and Delivery per test."""
	_h = HaulKitchen.new()
	_room = _h.haul_room()


func after_each() -> void:
	"""No Delivery packet escapes; the fixture's own assertions propagate."""
	if _h != null:
		if _h.delivery != null: assert_false(_h.delivery._busy, "no escaped delivery packet")
		_h.after_each()
		assert_true(_h.failures.is_empty(), "actual fixture: %s" % _h.failures)
	_h = null


func _foreman(staging: Vector2i) -> Foreman:
	"""A configured foreman over the haul owners, with the mole parked on M."""
	var foreman: Foreman = Foreman.new()
	var crew: Array[Builder.Crew] = [_h.store_member()]
	assert_equal(foreman.configure(_h.haul_owners(), _room, _h.material, _h.material, staging, crew), &"", "configured")
	return foreman


func _set_off(foreman: Foreman) -> Builder:
	"""The first tick registers the builder on M and sends it for the first cube; the BRACE lacks both inputs."""
	_h.tick += 1
	assert_equal(foreman.advance(_h.tick), &"", "dispatched")
	var builder: Builder = foreman.builders()[0]
	assert_equal(builder.stage(), Builder.STAGE_TO_STORE, "to the storage first")
	assert_false(builder.in_motion(), "with no leg to walk it has not set off: the footprint check comes first")
	return builder


func _put_pick_down() -> void:
	"""Fixture step: the haul rows hold no tool, so the pick goes into M (the same lot, ADR1217's toolless haul)."""
	assert_true(_h._gear.unequip(_h.tool, _h.material, false).ok, "pick put into M")


func test_the_builder_hauls_the_first_brace_inputs_and_the_room_is_dug() -> void:
	"""Same-level Delivery end to end: two trips carry one whole unit of wood and of stone from R to M through the
	room branch, the BRACE claims them from M, and the room is dug with them and the stock added to M afterwards."""
	if _room == NULL_REF: return
	var foreman: Foreman = _foreman(_h.staging)
	var builder: Builder = _set_off(foreman)
	_put_pick_down()
	var code: StringName = &""
	var armed: bool = false
	var before: int = builder.stage()
	for step: int in TICK_BOUND:
		_h.tick += 1
		code = foreman.advance(_h.tick)
		_check_set_off(builder, before)
		before = builder.stage()
		if not armed and builder.stage() == Builder.STAGE_TRAVEL and builder.haul_trips() == 2:
			armed = true
			assert_true(builder.in_motion(), "still set off after the haul")
			assert_equal(builder.occupied(), builder.claim(), "the cube's claim stays occupied, not the body")
			_after_the_haul()
		if not foreman.is_running(): break
	assert_equal(code, &"", "no refusal")
	assert_equal(foreman.state(), Foreman.STATE_DONE, "the room is dug")
	assert_equal(foreman.done_cubes(), KITCHEN_SITES, "every cube, by Sites' record")
	assert_equal(builder.haul_trips(), 2, "one trip per whole unit")
	assert_equal(builder.haul_mwu(), 2 * (HaulPlanner.HAUL_LOAD_MILLI_WU + HaulPlanner.HAUL_UNLOAD_MILLI_WU), "lift and set-down paid")
	assert_equal(_h._inventory.container_lot_count(_h.staging), 0, "R emptied")
	assert_equal(_h.free_milli(_h.material, &"wood"), 0, "every hauled and added wood unit was used")
	assert_equal(_h.free_milli(_h.material, &"stone"), 0, "every hauled and added stone unit was used")
	assert_equal(_h._construction.live_project_count(), 0, "no live Project")


func _check_set_off(builder: Builder, before: int) -> void:
	"""A builder just sent home from its column's end has not set off; a turned or moving one has."""
	if builder.stage() == Builder.STAGE_RETREAT and before != Builder.STAGE_RETREAT:
		assert_false(builder.in_motion(), "sent home, not yet set off: the footprint check comes first")
	if builder.walking_next() and builder._leg_state != Builder.LEG_NONE:
		assert_true(builder.in_motion(), "a turn or a leg means it has set off")


func _after_the_haul() -> void:
	"""Back on M under the BRACE Job: the BRACE's inputs are already reserved out of the hauled units, so no other
	builder can plan against them. Fixture step: the resting mole turns to the pick travel row's heading, takes the
	pick back and selects that row (as it stood when it arrived); the other cubes' inputs are put into M, so no further
	haul is needed (the pick fixture cannot haul twice)."""
	assert_equal(_h.free_milli(_h.material, &"wood"), Grip.QUANTITY_MILLI - Contract.BRACE_WOOD_MILLI, "reserved")
	assert_equal(_h.free_milli(_h.material, &"stone"), Grip.QUANTITY_MILLI - Contract.BRACE_STONE_MILLI, "reserved")
	var job: Vector2i = _h._jobs.job_of(_h._residents.directory().get_typed_row(_h._worker))
	assert_equal(Phase.WorldFixture.Binding.turn_actor(_h._binding, _h._worker, job, StationTests.YAW_PLUS_X,
		Space.MAX_CHECKS), &"", "turned empty-handed")
	assert_true(_h._gear.equip(_h.tool, _h._worker).ok, "pick taken back")
	assert_equal(_h._routes.refresh_travel_actor(_h._worker, job, 5, 1, StationTests.CONTENT, 0, -1, _h.tool), &"",
		"on the pick travel row")
	var rest: int = (KITCHEN_SITES - 4) * Contract.BRACE_WOOD_MILLI
	assert_true(_h._inventory.create_lot(_h.material, _h._items.compiled_id(&"wood"), rest, 1, 0, -1, 0, 0).ok, "wood")
	assert_true(_h._inventory.create_lot(_h.material, _h._items.compiled_id(&"stone"), rest, 1, 0, -1, 0, 0).ok, "stone")


func test_a_held_tool_stops_the_haul_at_the_switch_and_the_brace_is_cancelled() -> void:
	"""The haul rows hold no tool: a crew still holding one is refused by Routes at the switch at rest, before any
	claim. The room stops; the unstarted BRACE is cancelled and the HAUL Job retired, nothing moved."""
	if _room == NULL_REF: return
	var foreman: Foreman = _foreman(_h.staging)
	_set_off(foreman)
	_h.tick += 1
	assert_equal(foreman.advance(_h.tick), &"PROFILE_TOOL_REQUIRED", "named by the owner")
	assert_equal(foreman.abandon_error(), &"", "released cleanly")
	assert_equal(_h._construction.live_project_count(), 0, "BRACE cancelled")
	var row: int = _h._residents.directory().get_typed_row(_h._worker)
	assert_equal(_h._jobs.job_of(row), NULL_REF, "no Job held")
	assert_equal(_h.free_milli(_h.staging, &"wood"), Grip.QUANTITY_MILLI, "R untouched")


func test_a_crew_lost_mid_haul_returns_the_admitted_claim() -> void:
	"""ADR1225 through Delivery's own cancel: a builder that dies between admission and the lift leaves no claim on
	R's unit; the HAUL Job is retired and the unstarted BRACE cancelled."""
	if _room == NULL_REF: return
	var foreman: Foreman = _foreman(_h.staging)
	var builder: Builder = _set_off(foreman)
	_put_pick_down()
	_h.tick += 1
	assert_equal(foreman.advance(_h.tick), &"", "the first trip admitted")
	assert_equal(builder.stage(), Builder.STAGE_HAUL, "hauling")
	assert_true(builder.walking_next() and builder.in_motion() and not builder.standing(), "a haul is under way")
	assert_equal(builder._hauler.stage(), Hauler.STAGE_TO_SOURCE, "walking to R's stand")
	assert_equal(_h.free_milli(_h.staging, &"wood"), 0, "R's wood unit is claimed")
	var row: int = _h._residents.directory().get_typed_row(_h._worker)
	_h._jobs.needs()._status[row] = Needs.STATUS_DEAD # Negative-only: death mid-haul.
	_h._jobs.needs()._health[row] = 0
	_h.tick += 1
	assert_equal(foreman.advance(_h.tick), Builder.REFUSE_LOST, "named")
	assert_equal(foreman.abandon_error(), &"", "released cleanly")
	assert_equal(_h.free_milli(_h.staging, &"wood"), Grip.QUANTITY_MILLI, "the claim returned")
	assert_equal(_h._jobs.job_of(row), NULL_REF, "no Job held")
	assert_equal(_h._construction.live_project_count(), 0, "BRACE cancelled")


func test_without_a_staging_container_nothing_is_hauled() -> void:
	"""A Delivery alone does not haul: with no staging container named, the BRACE takes its Job at once and the
	storage's missing inputs are refused at START, as before decision 1934."""
	if _room == NULL_REF: return
	var foreman: Foreman = _foreman(NULL_REF)
	var builder: Builder = foreman.builders()[0]
	var code: StringName = &""
	for step: int in 4000:
		_h.tick += 1
		code = foreman.advance(_h.tick)
		if not foreman.is_running(): break
	assert_equal(code, &"ENTRY_FOREMAN_INPUT_LOT", "the storage lacks the inputs at START")
	assert_equal(builder.haul_trips(), 0, "no trip")
	assert_equal(_h.free_milli(_h.staging, &"wood"), Grip.QUANTITY_MILLI, "R untouched")




func test_a_staging_container_on_another_level_is_the_stair_carry_gap() -> void:
	"""P-C22-1: no certified stair row carries cargo yet, so stock on another level is named, not hauled. The BRACE
	was opened before the haul was planned and is cancelled; nothing is claimed."""
	if _room == NULL_REF: return
	var lower: Vector2i = _h.lower_staging()
	var foreman: Foreman = _foreman(lower)
	_h.tick += 1
	assert_equal(foreman.advance(_h.tick), Builder.REFUSE_STAIR, "ROOM_HAUL_NO_STAIR_CARRY")
	assert_equal(foreman.abandon_error(), &"", "released cleanly")
	assert_equal(_h._construction.live_project_count(), 0, "BRACE cancelled")


func test_the_claimed_footprint_covers_the_trips() -> void:
	"""ECON-001's turn-taking sees the haul: the cube's claim reaches both grip stands, not only the way on."""
	if _room == NULL_REF: return
	var builder: Builder = _set_off(_foreman(_h.staging))
	var offset: Vector3i = Grip.stock_offset(Grip.QUARTER)
	assert_true(_claimed(builder.claim(), SOURCE_POINT - offset), "R's stand is claimed")
	assert_true(_claimed(builder.claim(), _h.store_point() - offset), "M's stand is claimed")
	assert_true(_claimed(builder.claim(), SOURCE_POINT), "the lift's reach to the stock at R")
	assert_true(_claimed(builder.claim(), Vector3i(SOURCE_POINT.x - 2 * offset.x, 0, Phase.Z + 1536)),
		"the loaded CARRY span's run, outside every empty walk")
	assert_false(_claimed(builder.claim(), Vector3i(Phase.X - 3072, 0, Phase.Z - 1536)), "not the whole Corridor")


func _claimed(boxes: PackedInt32Array, point: Vector3i) -> bool:
	"""Some claimed box holds the point's floor position."""
	for at: int in range(0, boxes.size(), 6):
		if boxes[at] <= point.x and point.x < boxes[at + 3] and boxes[at + 2] <= point.z and point.z < boxes[at + 5]:
			return true
	return false


func test_a_haul_needs_the_locations_and_spatial_containers() -> void:
	"""Without the Locations the hauler reads the builder refuses its scope; a staging container with no endpoint
	has no stand (the hauler's own word). Either way the opened BRACE is cancelled."""
	if _room == NULL_REF: return
	var foreign: Builder.Owners = _h.haul_owners()
	foreign.locations = Locations.new()
	var stray: Foreman = Foreman.new()
	var members: Array[Builder.Crew] = [_h.store_member()]
	assert_equal(stray.configure(foreign, _room, _h.material, _h.material, _h.staging, members), &"", "configured")
	_h.tick += 1
	assert_equal(stray.advance(_h.tick), Builder.REFUSE_SCOPE, "Locations other than the binding's")
	var owners: Builder.Owners = _h.haul_owners()
	owners.locations = null
	var foreman: Foreman = Foreman.new()
	var crew: Array[Builder.Crew] = [_h.store_member()]
	assert_equal(foreman.configure(owners, _room, _h.material, _h.material, _h.staging, crew), &"", "configured")
	_h.tick += 1
	assert_equal(foreman.advance(_h.tick), Builder.REFUSE_SCOPE, "no Locations")
	assert_equal(_h._construction.live_project_count(), 0, "BRACE cancelled")
	var loose: Vector2i = _h._inventory.create_container(_h._world_ref, 1000000, -1, 0, true).ref
	foreman = _foreman(loose)
	_h.tick += 1
	assert_equal(foreman.advance(_h.tick), Hauler.REFUSE_STAND, "no endpoint, no stand")
	assert_equal(_h._construction.live_project_count(), 0, "BRACE cancelled")


func test_delivery_takes_a_room_dig_by_its_site_not_by_an_entry_placement() -> void:
	"""The room branch is chosen from the Project's own Site: its room is no live Placement's corridor. Negative-only:
	a live Placement naming the Kitchen as its corridor sends the same Project down the entry branch, which refuses
	it; without it the same admission is accepted for one whole unit."""
	if _room == NULL_REF: return
	var builder: Builder = _set_off(_foreman(_h.staging))
	_put_pick_down()
	var project: Vector2i = _h.sites.project_of(builder._site)
	var made: Jobs.OpResult = _h._jobs.create_job(Jobs.JOB_KIND_HAUL, 0, 0, HaulPlanner.HAUL_LOAD_MILLI_WU, 0)
	assert_true(_h._jobs.set_requester(made.value, project).ok and _h._jobs.set_source(made.value, project).ok, "HAUL source")
	assert_true(_h._jobs.assign_worker(_h._residents.directory().get_typed_row(_h._worker), made.value).ok, "assigned")
	assert_equal(_h._routes.refresh_actor(_h._worker, made.ref, Profiles.MODE_WALK, 0, -1, NULL_REF), &"", "toolless walk")
	var lot: Vector2i = _h._inventory.container_first_lot(_h.staging)
	var p: RefCounted = _h.placements
	p._live.present[0] = 1 # Negative-only: a live entry Placement in the Kitchen.
	p._set32(p._live, 0, 0, 1)
	p._set_pair(p._live, 1, 0, _room)
	assert_false(_h.delivery.admit(made.ref, lot, Grip.QUANTITY_MILLI, _h.tick + 1000).ok, "entry branch refuses")
	p._live.present[0] = 0
	var admitted: Inventory.OpResult = _h.delivery.admit(made.ref, lot, Grip.QUANTITY_MILLI, _h.tick + 1000)
	assert_true(admitted.ok, "room branch admits: %s" % admitted.error)
	assert_equal(admitted.value, Grip.QUANTITY_MILLI, "one whole unit")
	assert_true(_h.delivery.cancel(made.ref).ok, "claim returned")


func test_a_crew_lost_on_the_way_home_from_the_haul_cancels_the_brace() -> void:
	"""ADR1225 at the haul's last stage: the BRACE Job already holds the builder (the hauler's walk back onto M), so
	the release goes through Jobs and the unstarted BRACE is cancelled; the delivered units stay in M."""
	if _room == NULL_REF: return
	var foreman: Foreman = _foreman(_h.staging)
	var builder: Builder = _set_off(foreman)
	_put_pick_down()
	for step: int in 4000:
		_h.tick += 1
		assert_equal(foreman.advance(_h.tick), &"", "hauling")
		if builder._hauler != null and builder._hauler.stage() == Hauler.STAGE_HOME: break
	assert_equal(builder._hauler.stage(), Hauler.STAGE_HOME, "walking back onto M under the BRACE Job")
	var row: int = _h._residents.directory().get_typed_row(_h._worker)
	_h._jobs.needs()._status[row] = Needs.STATUS_DEAD # Negative-only: death on the way home.
	_h._jobs.needs()._health[row] = 0
	_h.tick += 1
	assert_equal(foreman.advance(_h.tick), Builder.REFUSE_LOST, "named")
	assert_equal(foreman.abandon_error(), &"", "released cleanly")
	assert_equal(_h._jobs.job_of(row), NULL_REF, "no Job held")
	assert_equal(_h._construction.live_project_count(), 0, "BRACE cancelled")
	assert_equal(_h.free_milli(_h.material, &"wood"), Grip.QUANTITY_MILLI, "the hauled unit stays in M, free")


func test_the_staging_container_cannot_be_the_storage() -> void:
	"""Hauling from M into M would move nothing; the foreman refuses the scope."""
	if _room == NULL_REF: return
	var crew: Array[Builder.Crew] = [_h.store_member()]
	assert_equal(Foreman.new().configure(_h.haul_owners(), _room, _h.material, _h.material, _h.material, crew),
		Foreman.REFUSE_SCOPE, "staging is storage")


func test_the_haul_starts_only_between_the_endpoints_it_was_planned_for() -> void:
	"""Negative-only: endpoints changed between planning and the first trip are re-proved; a staging container moved
	to another level is the stair-carry gap, one moved on the same level is a moved target."""
	if _room == NULL_REF: return
	var builder: Builder = _set_off(_foreman(_h.staging))
	builder._ctx.staging = _h.lower_staging()
	_h.tick += 1
	assert_equal(builder.advance(_h.tick), Builder.REFUSE_STAIR, "re-proved on the level")
	_h.after_each()
	assert_true(_h.failures.is_empty(), "first fixture: %s" % _h.failures)
	_h = HaulKitchen.new()
	_room = _h.haul_room()
	builder = _set_off(_foreman(_h.staging))
	builder._ctx.staging = _h._inventory.create_spatial_ground_staging(_h._first).ref
	_h.tick += 1
	assert_equal(builder.advance(_h.tick), Builder.REFUSE_TARGET, "another container on the same level")
