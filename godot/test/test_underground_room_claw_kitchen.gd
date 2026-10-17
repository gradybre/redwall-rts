extends "res://test/framework/test_case.gd"
## Decision 1939: the claw Kitchen. The Kitchen fixture's own geometry and owners, over the mounted content-12 rows
## (`qualified-stairs-v10`, decision 1972) instead of the retired content-6 pick rows: the crew holds no tool
## (DEC-052), travels on the claw READY rows (forward 46, backward 50 at the Kitchen's heading; the all-yaw WALK 42 is
## the canonical ground row), digs with the claw wall row 70 the painted 4 quanta of each cell (decision 1971), and
## hauls with the content's own grip rows (WALK 31, CARRY 32 wood and 37 stone). No row, price, height or pace is
## authored here; the rows are the mounted content's own. It closes decision 1937's deferred cases.

const HaulTests := preload("res://test/test_underground_room_haul.gd")
const ForemanTests := preload("res://test/test_underground_room_foreman.gd")
const StationTests := preload("res://test/test_underground_room_station_planner.gd")
const Phase := preload("res://test/test_underground_room_world_phases.gd")
const CatalogTests := preload("res://test/test_underground_connector_catalog.gd")
const GroupTests := preload("res://test/test_underground_connector_assemblies.gd")
const Bundle := preload("res://data/underground/first-entry-prefix-v1/qualified-stairs-v10/catalog_source.gd")
const ProfileCatalog := preload("res://data/underground/mole-worker/mole_profile_catalog.gd")
const Runtime := preload("res://scripts/core/underground_room_runtime.gd")
const Foreman := preload("res://scripts/core/underground_room_foreman.gd")
const Builder := preload("res://scripts/core/underground_room_builder.gd")
const Approach := preload("res://scripts/core/underground_room_approach.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const Inventory := preload("res://scripts/core/inventory.gd")
const Contract := preload("res://scripts/core/excavation_contract.gd")
const Sites := preload("res://scripts/core/excavation_sites.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const CLAW_CONTENT: int = 12
const CLAW_FORWARD: int = 46 # Claw READY forward at yaw 49152 (+X), the Kitchen's heading.
const CLAW_BACKWARD: int = 50 # Claw READY backward at the same heading.
const CLAW_WALL: int = 70 # Claw wall row at yaw 49152 (decision 1972, rows 67-70).
const CLAW_GROUND: int = 42 # The claw's all-yaw canonical ground WALK.
const TICK_BOUND: int = 40000


class ClawKitchen extends HaulTests.HaulKitchen:
	## The haul Kitchen over content 12's claw rows; `stocked` puts every BRACE's inputs in M from the start.
	var stocked: bool = false

	func _init() -> void:
		"""The claws retreat on the claw READY backward row; the first station stands at the wall row's own reach
		(its point 521 u ahead) from the Kitchen's face."""
		retreat_row = CLAW_BACKWARD
		work_x = Phase.X + 2048 - 521

	func _actual_profiles() -> void:
		"""The mounted content-12 wire, pinned by its published digest; no box, flag or policy is edited."""
		_pool = Pool.new(64, Pool.JOB_CAPACITY, 64); _piles = Piles.new()
		assert_true(_piles.bind_stores(_inventory, _buildings, StockAge.new(_inventory)), "actual piles")
		assert_true(_piles.bind_world(_world_ref), "exact World")
		_carry = Carry.new(); assert_true(_carry.bind(_inventory, _pool, _residents, _piles), "actual cargo")
		_gear = Gear.new(16)
		assert_true(_gear.bind_equipment(_inventory, _residents.directory(), _residents).ok, "actual Gear")
		_work = Work.new(_jobs); assert_true(_work.bind_gear(_gear).ok, "actual Work")
		_profiles = Profiles.new()
		assert_equal(_profiles.configure(ProfileCatalog.PROFILE_COUNT, ProfileCatalog.BOX_COUNT, ProfileCatalog.SOURCE_COUNT,
			ProfileCatalog.PAIRED_BANK_BYTES + ProfileCatalog.CONTROL_RESERVE), &"", "the mounted profile bank")
		assert_equal(_profiles.bind_actual(_residents, _transforms, _inventory, _gear, _carry, _work, _pool, _piles), &"", "actual source owners")
		assert_equal(_profiles.load_file(Bundle.PROFILE_PATH, Bundle.PROFILE_SHA, CLAW_CONTENT), &"", "mounted content-12 wire")

	func _load_catalog(revision: int) -> StringName:
		"""The claw travel rows and the grip rows, each at the existing Movement rate (RATE_GROUND_CAP): no pace."""
		var bytes: PackedByteArray = Phase.GroupFixture._catalog_wire(4, revision)
		var rows: PackedInt32Array = PackedInt32Array([31, 32, 37, CLAW_GROUND, CLAW_FORWARD, CLAW_BACKWARD]) # In row order.
		bytes.encode_u32(44, rows.size()); bytes.encode_s64(48, CLAW_CONTENT)
		bytes.resize(bytes.size() - 80)
		for profile: int in rows:
			Phase.GroupFixture.Fixture._append_row(bytes, PackedInt32Array([profile, -1, 0, 1, 1, 0, Catalog.RATE_GROUND_CAP]), 1)
		var digest: PackedByteArray = PackedByteArray(); digest.resize(32)
		assert_true(_profiles.source_hash_into(0, CLAW_CONTENT, digest), "actual original actor source")
		for index: int in 32: bytes[72 + index] = digest[index]
		bytes.append_array("UGCEND01".to_ascii_buffer())
		return _catalog.load_file(TEMP, _write(TEMP, bytes), revision)

	func _edge() -> Routes.Edge:
		"""The Corridor's spans under content 12."""
		var edge: Routes.Edge = super._edge()
		edge.content_revision = CLAW_CONTENT
		return edge

	func room_request() -> Approach.Request:
		"""The Kitchen dug by the claw wall row at its heading, travelling on the claw READY row; the painted 4 m."""
		var request: Approach.Request = super.room_request()
		request.travel_profile = CLAW_FORWARD; request.work_profile = CLAW_WALL; request.content_revision = CLAW_CONTENT
		request.height_u = mini(4096, Approach.reachable_height_u(_profiles, CLAW_WALL))
		return request

	func finite_stock_and_worker() -> void:
		"""M on the parking; the claws hold no tool. Stocked, M holds one BRACE bill per Site."""
		storage_binding = Locations.InventoryLocations.new(endpoints)
		assert_true(_inventory.bind_spatial_locations(storage_binding, 4).ok, "actual storage authority")
		var made: Inventory.OpResult = _inventory.create_spatial_ground_staging(parking)
		assert_true(made.ok, "the room's storage M: %s" % made.error)
		material = made.ref; storage = parking
		if stocked:
			stock_wood = stock(&"wood", StationTests.KITCHEN_SITES * Contract.BRACE_WOOD_MILLI)
			stock_stone = stock(&"stone", StationTests.KITCHEN_SITES * Contract.BRACE_STONE_MILLI)
		var worker: int = _residents.directory().get_typed_row(_worker)
		assert_true(_jobs.priorities().spawn(worker).ok, "actual priorities")
		assert_true(_jobs.schedule().spawn(worker, _jobs.schedule().default_template_id().value).ok, "actual schedule")
		assert_true(_jobs.schedule().resolve(worker, 8, false).ok and _jobs.spawn_agent(worker).ok, "actual worker availability")

	func _mole_at(point: Vector3i, spot: Vector2i) -> Builder.Crew:
		"""One more claw mole (no tool), still far off on the surface."""
		var mole: Vector2i = _residents.ref_of(_residents.spawn(&"mole").value)
		assert_true(_transforms.place(mole, point.x + 60000, 512, point.z, StationTests.YAW_PLUS_X), "second mole far off")
		var row: int = _residents.directory().get_typed_row(mole)
		assert_true(_jobs.priorities().spawn(row).ok, "priorities")
		assert_true(_jobs.schedule().spawn(row, _jobs.schedule().default_template_id().value).ok, "schedule")
		assert_true(_jobs.schedule().resolve(row, 8, false).ok and _jobs.spawn_agent(row).ok, "availability")
		var member: Builder.Crew = Builder.Crew.new()
		member.worker = mole; member.parking = spot
		return member

	func _frontier_image(counts: PackedInt32Array) -> PackedByteArray:
		"""The haul Kitchen's minimal entry Frontier, valid against content 12's sources (no room haul reads it)."""
		var bytes: PackedByteArray = super._frontier_image(counts)
		bytes.encode_s64(12 + 8 * 5, CLAW_CONTENT)
		return bytes


var _h: ClawKitchen = null


func after_each() -> void:
	"""Propagate the fixture's own assertions and free every owner."""
	if _h != null:
		_h.after_each()
		assert_true(_h.failures.is_empty(), "fixture: %s" % _h.failures)
	_h = null


func _runtime(room: Vector2i, staging: Vector2i, crew: Array[Builder.Crew], owners: Builder.Owners) -> Runtime:
	"""A runtime bound to the fixture's owners with the room ordered and started."""
	var runtime: Runtime = Runtime.new(_h._residents.directory())
	assert_true(runtime.bind_owners(owners), "owners")
	assert_equal(runtime.order_room(room, _h.material, _h.material, staging), &"", "ordered")
	assert_equal(runtime.start_room(room, owners, crew), &"", "started")
	return runtime


func _run(runtime: Runtime) -> Array[StringName]:
	"""Every fixed tick to the end; the refusals seen."""
	var seen: Array[StringName] = []
	for step: int in TICK_BOUND:
		_h.tick += 1
		seen.append_array(runtime.advance(_h.tick))
		if not runtime.is_running(): break
	return seen


func test_a_claw_crew_digs_the_kitchen_end_to_end() -> void:
	"""The claws dig every cube of the painted 4 m with the wall row, holding no tool, and walk back out."""
	_h = ClawKitchen.new()
	_h.stocked = true
	var room: Vector2i = _h.confirmed_room()
	if room == NULL_REF: return
	var crew: Array[Builder.Crew] = [_h.crew_member()]
	assert_equal(crew[0].tool, NULL_REF, "claws: no tool")
	var runtime: Runtime = _runtime(room, NULL_REF, crew, _h.owners())
	var foreman: Foreman = runtime.foreman_of(room)
	assert_equal(foreman.total_cubes(), StationTests.KITCHEN_SITES, "the painted 4 quanta of every cell")
	assert_equal(_run(runtime), [] as Array[StringName], "no refusal")
	assert_equal(foreman.done_cubes(), StationTests.KITCHEN_SITES, "every cube dug")
	assert_equal(_h._construction.live_project_count(), 0, "no live Project")
	assert_equal(runtime.state_of(room), Runtime.RECORD_NONE, "finished, out, released")


func _haul_kitchen() -> Vector2i:
	"""The claw Kitchen with R holding one whole unit of wood and of stone per four BRACEs, and M one BRACE's worth,
	so every later haul falls on the second cube of a column (a column haul)."""
	_h = ClawKitchen.new()
	var room: Vector2i = _h.haul_room()
	if room == NULL_REF: return NULL_REF
	assert_true(_h._inventory.create_lot(_h.material, _h._items.compiled_id(&"wood"), Contract.BRACE_WOOD_MILLI, 1, 0, -1,
		0, 0).ok, "one BRACE of wood in M")
	assert_true(_h._inventory.create_lot(_h.material, _h._items.compiled_id(&"stone"), Contract.BRACE_STONE_MILLI, 1, 0, -1,
		0, 0).ok, "one BRACE of stone in M")
	for key: StringName in [&"wood", &"stone"]:
		assert_true(_h._inventory.create_lot(_h.staging, _h._items.compiled_id(key),
			(StationTests.KITCHEN_SITES / 4 - 1) * HaulTests.Grip.QUANTITY_MILLI, 1, 0, -1, 0, 0).ok, "the rest of R")
	return room


func test_a_claw_builder_hauls_every_brace_and_digs_the_kitchen() -> void:
	"""Decision 1937's deferred cases on the claws: every BRACE's inputs come from R, hauled in whole units through
	Delivery's room branch, with no fixture step: after each haul the builder turns from the grip heading itself and
	goes on, and a cube up a column whose inputs ran out is hauled for from its station."""
	var room: Vector2i = _haul_kitchen()
	if room == NULL_REF: return
	var crew: Array[Builder.Crew] = [_h.store_member()]
	var runtime: Runtime = _runtime(room, _h.staging, crew, _h.haul_owners())
	var builder: Builder = runtime.foreman_of(room).builders()[0]
	var foreman: Foreman = runtime.foreman_of(room)
	var seen: Array[StringName] = []
	var before: int = builder.stage()
	var into_store: Dictionary = {}
	for step: int in TICK_BOUND:
		_h.tick += 1
		seen.append_array(runtime.advance(_h.tick))
		if builder.stage() == Builder.STAGE_TO_STORE and before != Builder.STAGE_TO_STORE:
			into_store[before] = int(into_store.get(before, 0)) + 1
		if builder.walking_next() and builder._leg_state != Builder.LEG_NONE:
			assert_true(builder.in_motion(), "a turn or a leg means it has set off (after a haul too)")
		before = builder.stage()
		if not runtime.is_running(): break
	print("CLAW_HAUL into_store=%s trips=%d" % [into_store, builder.haul_trips()])
	assert_true(into_store.keys().any(func(stage: int) -> bool: return stage != Builder.STAGE_IDLE),
		"a haul from a column's station: %s" % into_store)
	assert_equal(seen, [] as Array[StringName], "no refusal")
	assert_equal(foreman.done_cubes(), StationTests.KITCHEN_SITES, "every cube dug")
	assert_equal(builder.haul_trips(), 2 * StationTests.KITCHEN_SITES / 4, "a wood and a stone trip per four BRACEs")
	assert_equal(_h._inventory.container_lot_count(_h.staging), 0, "R emptied")
	assert_equal(_h.free_milli(_h.material, &"wood"), Contract.BRACE_WOOD_MILLI, "all used but one BRACE's worth")
	assert_equal(_h.free_milli(_h.material, &"stone"), Contract.BRACE_STONE_MILLI, "all used but one BRACE's worth")
	assert_equal(_h._construction.live_project_count(), 0, "no live Project")
