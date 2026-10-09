extends "res://test/framework/test_case.gd"
## ADR 1229 increment 3, the hand fixture: content 10's source-proved travel rows on actual Routes, WorldRoutes,
## Locations and Space owners. Two decks one tread apart (a 512 u deck 128 u above the next, as T_k above T_k+1) are
## World-owned SUPPORT in completed void; a synthetic catalog (test-only) carries one EARTH_TIMBER variant and
## DEC-050's paces (528 u/s over a 528 u tread edge, 116 u/s over the 174 u half-turn). The actual mole is driven by
## real route ticks.

const Binding := preload("res://scripts/core/underground_world_routes.gd")
const Routes := preload("res://scripts/core/underground_routes.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Locations := preload("res://scripts/core/underground_locations.gd")
const Catalog := preload("res://scripts/core/underground_connector_catalog.gd")
const ContentFixture := preload("res://test/test_underground_connector_catalog.gd")
const Levels := preload("res://scripts/core/underground_level_catalog.gd")
const Residents := preload("res://scripts/core/residents.gd")
const Transforms := preload("res://scripts/core/transforms.gd")
const Movement := preload("res://scripts/core/movement.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const Construction := preload("res://scripts/core/construction.gd")
const Inventory := preload("res://scripts/core/inventory.gd")
const Items := preload("res://scripts/core/item_definitions.gd")
const Gear := preload("res://scripts/core/gear.gd")
const Carry := preload("res://scripts/core/haul_carry.gd")
const Work := preload("res://scripts/core/work.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const Pool := preload("res://scripts/core/reservations.gd")
const Piles := preload("res://scripts/core/ground_piles.gd")
const StockAge := preload("res://scripts/core/stock_age.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const World := preload("res://scripts/core/world_init.gd")
const Nodes := preload("res://scripts/core/resource_nodes.gd")
const Forage := preload("res://scripts/core/forage.gd")
const Fishing := preload("res://scripts/core/fishing.gd")
const Rng := preload("res://scripts/core/rng.gd")
const Terrain := preload("res://scripts/core/underground_terrain.gd")
const StairMotion := preload("res://scripts/core/underground_stair_motion.gd")
const MotionPins := preload("res://data/underground/mole-worker/qualified-claw-stair-motion-v1/catalog_source.gd")
const Pins := preload("res://data/underground/mole-worker/qualified-claw-stairs-v11/catalog_source.gd")
const Stair := preload("res://data/underground/mole-worker/qualified-claw-runtime-v2/stair_program.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const X: int = 60 * 2048
const Z: int = 50 * 2048
## The upper deck's far edge; the upper deck is [FAR, FAR + 512) at top 512, the lower [FAR - 512, FAR) at top 384.
const FAR: int = Z + 2048
const UP: int = 512
const LOW: int = 384
const CATALOG_TEMP: String = "user://stair-routes-catalog.bin"
const PROFILE_WIRE: String = "res://data/underground/mole-worker/qualified-claw-stairs-v11/mole-worker.ugprof"
const GROUND_WIRE: String = "res://data/underground/mole-worker/qualified-claw-stairs-v11/ground-pace.ugconn"
## DEC-050 as authored connector paces: one tread (528 u) a second, a half-turn (174 u) in a second and a half.
const STAIR_PACES: Array[Vector2i] = [Vector2i(53, 528), Vector2i(54, 528), Vector2i(55, 116)]

var _residents: Residents = null
var _transforms: Transforms = null
var _buildings: Buildings = null
var _construction: Construction = null
var _inventory: Inventory = null
var _items: Items = null
var _gear: Gear = null
var _carry: Carry = null
var _work: Work = null
var _jobs: Jobs = null
var _pool: Pool = null
var _piles: Piles = null
var _profiles: Profiles = null
var _owner: Owner = null
var _sources: Owner.CoreSources = null
var _locations: Locations = null
var _budget: Budget = null
var _routes: Routes = null
var _binding: Binding = null
var _world: World = null
var _nodes: Nodes = null
var _terrain: Terrain = null
var _movement: Movement = null
var _levels: Levels = null
var _catalog: Catalog = null
var _motion: StairMotion = null
var _world_ref: Vector2i = NULL_REF
var _worker: Vector2i = NULL_REF
var _floors: Array[Vector2i] = []
var _lease: int = 0
var _tick: int = 0


func before_each() -> void:
	"""Actual stores with the content-10 rows and the claw stair tables."""
	_residents = Residents.new()
	_jobs = Jobs.new(_residents)
	_nodes = Nodes.new(_residents.directory())
	var forage: Forage = Forage.new(_residents.directory(), _jobs)
	var fishing: Fishing = Fishing.new(_residents.directory(), forage, _jobs)
	_world = World.new(_residents.directory(), _nodes, forage, fishing, Rng.new(), null, null, _jobs)
	_inventory = Inventory.new(32, 64)
	_items = Items.new()
	assert_true(_items.load_default(_inventory).ok, "item definitions")
	assert_true(_world.generate(World.bound_request(_items).request).ok, "terrain")
	_world_ref = _residents.directory().create(Directory.KIND_WORLD)
	_worker = _residents.ref_of(_residents.spawn(&"mole").value)
	_transforms = Transforms.new(_residents.directory())
	_buildings = Buildings.new(_residents.directory())
	_construction = Construction.new(_buildings)
	_budget = Budget.new()
	_motion = StairMotion.new()
	assert_equal(_motion.load_file(MotionPins.WIRE_PATH, MotionPins.WIRE_SHA), &"", "stair tables")
	_tick = 0


func after_each() -> void:
	"""The acyclic composition drops in reverse order."""
	if _binding != null and _lease != 0:
		_binding.abort(_binding._route_token)
		_budget.release(_lease)
	_lease = 0
	if _budget != null: assert_true(_budget.is_quiescent(), "every lease returned")
	_drop_route_owners()
	_profiles = null
	_work = null
	_jobs = null
	_carry = null
	_gear = null
	_piles = null
	_pool = null
	_inventory = null
	_items = null
	_transforms = null
	_construction = null
	_buildings = null
	_residents = null
	_budget = null
	_floors.clear()
	if FileAccess.file_exists(CATALOG_TEMP): DirAccess.remove_absolute(ProjectSettings.globalize_path(CATALOG_TEMP))


func _drop_route_owners() -> void:
	"""Adapters before the stores they borrow."""
	_binding = null
	_routes = null
	_locations = null
	_owner = null
	_sources = null
	_terrain = null
	_catalog = null
	_levels = null
	_movement = null
	_world = null
	_nodes = null
	_motion = null


func _compose(lower_deck: bool = true, obstacle: bool = false, bind_motion: bool = true) -> void:
	"""Profiles, Space with both decks, Locations, Terrain, the catalog and the route owners."""
	_pool = Pool.new(64, Pool.JOB_CAPACITY, 64)
	_piles = Piles.new()
	assert_true(_piles.bind_stores(_inventory, _buildings, StockAge.new(_inventory)), "piles")
	assert_true(_piles.bind_world(_world_ref), "pile World")
	_carry = Carry.new()
	assert_true(_carry.bind(_inventory, _pool, _residents, _piles), "cargo")
	_gear = Gear.new(16)
	assert_true(_gear.bind_equipment(_inventory, _residents.directory(), _residents).ok, "Gear")
	_work = Work.new(_jobs)
	assert_true(_work.bind_gear(_gear).ok, "Work")
	_profiles = Profiles.new()
	var packed: int = 2 * (67 * Profiles.PROFILE_WIRE_BYTES + 547 * 28 + 6 * 32 + 32)
	assert_equal(_profiles.configure(67, 547, 6, packed + Profiles.CONTROL_RESERVE), &"", "content-10 capacity")
	assert_equal(_profiles.bind_actual(_residents, _transforms, _inventory, _gear, _carry, _work, _pool, _piles), &"", "readers")
	assert_equal(_profiles.load_file(PROFILE_WIRE, Pins.WIRE_SHA, 10), &"", "content 10")
	var domain: Space.Domain = _space(lower_deck, obstacle)
	_catalog_owner(domain)
	_route_owners(bind_motion)


func _space(lower_deck: bool, obstacle: bool) -> Space.Domain:
	"""Two decks, the void around them partitioned, and three floor datums (upper, lower, and the span)."""
	_routes = Routes.new(_residents, _transforms)
	_sources = Owner.CoreSources.new(_residents.directory(), _buildings, _construction, _routes)
	var domain: Space.Domain = Space.Domain.new()
	assert_equal(domain.configure(_world_ref, Vector3i(0, 512, 0), Vector3i(0, -32, 0),
		Vector3i(256, 48, 256), 8192, 6144, Space.MAX_CHECKS), &"", "Domain")
	_owner = Owner.new(_sources)
	assert_equal(_owner.configure(domain, Budget.REGION_CAPACITY, Budget.SOURCE_CAPACITY), &"", "owner")
	var token: int = _owner.begin_stage(_owner.revision()).token
	_floors = [_region(token, _slab(UP, FAR, FAR + 512, UP + 1), Space.FLOOR_DATUM),
		_region(token, _slab(LOW, FAR - 512, FAR, LOW + 1), Space.FLOOR_DATUM),
		_region(token, _slab(0, FAR - 1024, FAR + 1024, 1), Space.FLOOR_DATUM)]
	_region(token, _slab(UP - 64, FAR, FAR + 512, UP), Space.SUPPORT)
	_region(token, _slab(LOW - 64, FAR - 512, FAR if lower_deck else FAR - 100, LOW), Space.SUPPORT)
	if not lower_deck: _region(token, _slab(LOW - 64, FAR - 100, FAR, LOW), Space.SUPPORTED_VOID)
	for box: PackedInt32Array in [_slab(0, Z - 2048, FAR - 512, 2560), _slab(LOW, FAR - 512, FAR, 2560),
			_slab(0, FAR - 512, FAR, LOW - 64), _slab(UP, FAR, FAR + 512, 2560), _slab(0, FAR, FAR + 512, UP - 64),
			_slab(0, FAR + 512, Z + 4096, 2560)]:
		_region(token, box, Space.SUPPORTED_VOID)
	if obstacle: _region(token, PackedInt32Array([X + 900, 600, FAR - 670, X + 1100, 700, FAR - 650]), Space.OBSTACLE)
	assert_equal(_owner.seal(token), &"", "sealed")
	_owner.publish(token)
	return domain


func _slab(low_y: int, low_z: int, high_z: int, high_y: int) -> PackedInt32Array:
	"""A box across the fixture's whole width."""
	return PackedInt32Array([X - 2048, low_y, low_z, X + 4096, high_y, high_z])


func _region(token: int, box: PackedInt32Array, role: int) -> Vector2i:
	"""One World-owned test fact through the actual stage."""
	var row: Owner.Region = Owner.Region.new()
	row.box = box
	row.role = role
	row.level = 0
	row.owner = _world_ref
	var result: Owner.Result = _owner.stage_add(token, row)
	assert_equal(result.error, &"", "region: %s" % result.error)
	return result.handle


func _catalog_owner(domain: Space.Domain) -> void:
	"""Levels, Movement and a test-only catalog with one EARTH_TIMBER variant and the stair paces."""
	_movement = Movement.new(_residents.directory(), null, null, _transforms, _residents)
	_levels = Levels.new()
	assert_equal(_levels.load_file(ContentFixture.LEVEL_PATH, ContentFixture.LEVEL_HASH, 1), &"", "levels")
	assert_equal(_levels.bind_domain(domain, _residents.directory(), domain.descriptor(), Space.VERSION), &"", "levels bound")
	_catalog = Catalog.new()
	assert_equal(_catalog.configure(Catalog.RESERVED_BYTES), &"", "catalog lifetime")
	assert_equal(_catalog.bind_actual(_profiles, _levels, _movement, _residents, _transforms, domain), &"", "pace owners")
	var bytes: PackedByteArray = stair_catalog_image()
	var file: FileAccess = FileAccess.open(CATALOG_TEMP, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	assert_equal(_catalog.load_file(CATALOG_TEMP, FileAccess.get_sha256(CATALOG_TEMP), 1), &"", "stair catalog")


static func stair_catalog_image() -> PackedByteArray:
	"""Test-only UGCONN01: content 10, source 4; one family-0 variant; content 10's ground caps and three stair rows."""
	var ground: PackedByteArray = FileAccess.get_file_as_bytes(GROUND_WIRE)
	var rows: int = ground.decode_u32(44)
	var bytes: PackedByteArray = _catalog_header(rows + STAIR_PACES.size())
	_append(bytes, [0, 0, 1, 0, 0, 0, 0, -128, -512, 0, 0, 0, 0, 0, 2, 0, 5, 0, 1, 0, 4, 0, 0,
		Profiles.MODE_WALK, 0, 1], 1)
	_append(bytes, [0, 0, 0, 0])
	_append(bytes, [0, -128, -512, 0])
	_append(bytes, [-1024, -256, -1024, 1024, 1024, 512, Space.ENVELOPE, 0])
	_append(bytes, [-512, 0, -256, 512, 1, 256, Space.LANDING, 0])
	_append(bytes, [-512, -128, -768, 512, -127, -256, Space.LANDING, 0])
	_append(bytes, [-512, -256, -512, 512, -128, 0, Space.SUPPORT_REQUIRED, 0])
	_append(bytes, [-512, 0, -128, 512, 1024, 0, Space.OPENING, 0])
	_append(bytes, [0, 64, 0, -1, 0, 0, 0, 0, 4])
	for corner: Vector2i in [Vector2i(-512, -512), Vector2i(512, -512), Vector2i(512, 0), Vector2i(-512, 0)]:
		_append(bytes, [corner.x, 0, corner.y])
	_append(bytes, [1024])
	_append_paces(bytes, ground, rows)
	bytes.append_array("UGCEND01".to_ascii_buffer())
	return bytes


static func _catalog_header(paces: int) -> PackedByteArray:
	"""Version 1, revision 1, the census, content 10 on source 4, and both source digests."""
	var bytes: PackedByteArray = "UGCONN01".to_ascii_buffer()
	bytes.resize(72)
	bytes.encode_u32(8, 1)
	bytes.encode_s64(12, 1)
	var counts: PackedInt32Array = PackedInt32Array([1, 2, 5, 1, 4, 1, paces])
	for index: int in 7:
		bytes.encode_u32(20 + index * 4, counts[index])
	bytes.encode_s64(48, 10)
	bytes.encode_s64(56, 1)
	bytes.encode_s64(64, 4)
	bytes.append_array(Pins.CLAW_SOURCE_SHA.hex_decode())
	bytes.append_array(ContentFixture.LEVEL_HASH.hex_decode())
	return bytes


static func _append_paces(bytes: PackedByteArray, ground: PackedByteArray, rows: int) -> void:
	"""Content 10's ground caps in their order, with the stair rows inserted at their profile's place."""
	var pending: int = 0
	for row: int in rows:
		var profile: int = ground.decode_s32(136 + 36 * row)
		while pending < STAIR_PACES.size() and STAIR_PACES[pending].x < profile:
			_append_stair_pace(bytes, STAIR_PACES[pending])
			pending += 1
		bytes.append_array(ground.slice(136 + 36 * row, 172 + 36 * row))
	while pending < STAIR_PACES.size():
		_append_stair_pace(bytes, STAIR_PACES[pending])
		pending += 1


static func _append_stair_pace(bytes: PackedByteArray, pace: Vector2i) -> void:
	"""(profile, EARTH_TIMBER, variant 0, Movement 1 rev 1, rate, RATE_AUTHORED), profile revision 1."""
	_append(bytes, [pace.x, 0, 0, 1, 1, pace.y, Catalog.RATE_AUTHORED], 1)


static func _append(bytes: PackedByteArray, words: Array, revision: int = -1) -> void:
	"""Little-endian int32 words, then an optional int64."""
	var start: int = bytes.size()
	bytes.resize(start + 4 * words.size() + (8 if revision >= 0 else 0))
	for index: int in words.size():
		bytes.encode_s32(start + 4 * index, words[index])
	if revision >= 0: bytes.encode_s64(start + 4 * words.size(), revision)


func _route_owners(bind_motion: bool) -> void:
	"""Locations, Terrain, the WorldRoutes provider and the graph bound back to it."""
	_locations = Locations.new()
	assert_equal(_locations.configure(_residents.directory(), _buildings, _transforms, _inventory,
		_owner, _sources, _budget, 64, 228 * 64 + 256), &"", "endpoints")
	_terrain = Terrain.new()
	assert_equal(_terrain.configure(_world, _nodes, _owner, _sources, _items, _budget), &"", "terrain")
	_binding = Binding.new()
	var config: Binding.Configuration = Binding.Configuration.new()
	config.routes = _routes
	config.owner = _owner
	config.sources = _sources
	config.locations = _locations
	config.profiles = _profiles
	config.catalog = _catalog
	config.levels = _levels
	config.movement = _movement
	config.residents = _residents
	config.transforms = _transforms
	config.world = _world
	config.terrain = _terrain
	config.budget = _budget
	assert_equal(_binding.configure(config), &"", "provider")
	assert_equal(_routes.configure(_locations, _owner, _sources, _buildings, _budget, _binding, 64, 16, 64, 64,
		Routes.ARENA_BYTES), &"", "graph")
	assert_equal(_routes.bind_profiles(_profiles, _inventory, _gear, _carry, _work, _pool, _piles), &"", "selection")
	if bind_motion: assert_equal(_routes.bind_stair_motion(_motion), &"", "stair tables bound")


func _location(point: Vector3i, floor_index: int, facing_up: bool, behind: int) -> Vector2i:
	"""A READY stop: the claw tread stance (row 64's) as footing, turned for an upward facing; air above the root
	reaching `behind` u towards +Z (it must stop short of a deck above)."""
	var row: Locations.Record = Locations.Record.new()
	row.point = point
	row.section = _floors[floor_index]
	row.level = 0
	row.role = Locations.ROLE_TRANSIT
	row.envelope = PackedInt32Array([point.x - 600, point.y, point.z - 300, point.x + 600, point.y + 1000, point.z + behind])
	row.support = PackedInt32Array([point.x - 299, point.y - 1, point.z - 175, point.x + 276, point.y, point.z + 169]) \
		if facing_up else PackedInt32Array([point.x - 276, point.y - 1, point.z - 169, point.x + 299, point.y, point.z + 175])
	var cold: int = _budget.acquire(Budget.COLD_BYTES)
	var token: int = _locations.begin_prepare(cold).token
	var added: Locations.Result = _locations.stage_add(token, row)
	assert_equal(added.error, &"", "stop at %s: %s" % [point, added.error])
	assert_equal(_locations.seal(token), &"", "sealed")
	assert_true(_locations.publish(token), "published")
	assert_equal(_budget.release(cold), &"", "lease")
	return added.location


func _edge(first: Vector2i, last: Vector2i, a: Vector3i, b: Vector3i, family: int) -> Routes.Edge:
	"""One straight span in the span datum; the length is the exact ceil length Routes recomputes."""
	var edge: Routes.Edge = Routes.Edge.new()
	edge.from_location = first
	edge.to_location = last
	edge.section = _floors[2]
	edge.level = 0
	edge.family = family
	edge.variant = 0
	edge.mode = Profiles.MODE_WALK
	edge.posture = Profiles.POSTURE_UPRIGHT
	edge.content_revision = 10
	edge.geometry_revision = _owner.revision()
	edge.point_count = 2
	edge.points = PackedInt32Array([a.x, a.y, a.z, b.x, b.y, b.z])
	edge.length_u = Routes._segment_length(a, b)
	return edge


func _publish(edge: Routes.Edge) -> Routes.Result:
	"""Stage, seal and publish one edge through the actual provider; returns the stage result."""
	_lease = _budget.acquire(Budget.COLD_BYTES)
	var begun: Routes.Result = _binding.begin_prepare(_lease)
	assert_equal(begun.error, &"", "preparation")
	var added: Routes.Result = _routes.stage_add(begun.token, edge)
	if added.error == &"":
		assert_equal(_binding.seal(begun.token), &"", "sealed")
		assert_equal(_binding.publish(begun.token), &"", "published")
	_binding.abort(begun.token)
	assert_equal(_budget.release(_lease), &"", "lease")
	_lease = 0
	return added


func _masked(edge: Vector2i) -> Array[int]:
	"""Profiles whose bit the live certificate holds."""
	var out: Array[int] = []
	for profile: int in 67:
		if _binding._live.admits(edge.x, profile): out.append(profile)
	return out


func _drive(start: Vector2i, target: Vector2i, profile: int, at: Vector3i, yaw: int, ticks: int) -> Array:
	"""Admit the mole at `start` on `profile`, request the route and run `ticks` real ticks; every pose."""
	assert_true(_transforms.place(_worker, at.x, at.y, at.z, yaw), "pose")
	assert_equal(_routes.admit_travel_actor(_worker, NULL_REF, start, profile, 1, 10, 0, -1, NULL_REF), &"", "admitted")
	_tick += 1
	assert_equal(_routes.request_route(_worker, target, _tick), &"", "route")
	return _run(ticks)


func _run(ticks: int) -> Array:
	"""Real route ticks; the pose, heading, location and source word after each."""
	var poses: Array = []
	var actor: Routes.Actor = Routes.Actor.new()
	for step: int in ticks:
		_tick += 1
		assert_equal(_routes.advance_tick(_tick), 1, "one actor moved on tick %d" % step)
		assert_equal(_routes.read_actor_into(_worker, actor), &"", "readable")
		var row: int = _residents.directory().get_typed_row(_worker)
		assert_equal(_routes._source_clock_refusal(row), &"", "a valid saved state on tick %d" % step)
		poses.append([actor.point, actor.yaw, actor.location, _routes._motion.resident[Routes.R_PHASE * Routes.RESIDENT_CAPACITY + row]])
	return poses


func test_a_descent_crosses_one_tread_in_thirty_ticks_on_its_root_track() -> void:
	"""Upper stop 169 u behind the far edge to the lower stop 169 u behind its own: only row 53 fits the edge, and
	each tick's root is the start plus the accepted track's key 3t; the crossing ends READY on the lower stop."""
	_compose()
	var a: Vector3i = Vector3i(X + 1024, UP, FAR + 169)
	var b: Vector3i = a + Vector3i(0, -128, -512)
	var top: Vector2i = _location(a, 0, false, 235)
	var bottom: Vector2i = _location(b, 1, false, 300)
	var added: Routes.Result = _publish(_edge(top, bottom, a, b, 0))
	assert_equal(added.error, &"", "the stair edge qualifies")
	assert_equal(_masked(added.ref), [Pins.CLAW_DESCENT_ROW] as Array[int], "only the descent fits")
	var poses: Array = _drive(top, bottom, Pins.CLAW_DESCENT_ROW, a, 0, 30)
	var program: int = _motion.program_of(Pins.CLAW_DESCENT_ROW)
	for tick: int in [0, 14, 28]:
		assert_equal(poses[tick][0], a + _motion.root_at(program, 3 * (tick + 1)), "root on tick %d" % (tick + 1))
	assert_equal(poses[29][0], b, "ends exactly on the lower stop")
	assert_equal(poses[29][2], bottom, "at the lower Location")
	assert_equal(poses[29][3], Stair.word(Routes.PHASE_IDLE, Stair.READY), "back on the READY hub")
	assert_equal(poses[14][3] & 3, Routes.PHASE_TRAVELLING, "travelling mid-crossing")


func test_the_half_turn_ends_facing_up_174_u_back() -> void:
	"""The half-turn takes 45 ticks to 174 u back on its table's root and heading, ending on heading 32768."""
	_compose()
	var a: Vector3i = Vector3i(X + 1024, UP, FAR + 169)
	var u: Vector3i = a + Vector3i(0, 0, 174)
	var start: Vector2i = _location(a, 0, false, 300)
	var turned: Vector2i = _location(u, 0, true, 160)
	var added: Routes.Result = _publish(_edge(start, turned, a, u, 0))
	assert_equal(_masked(added.ref), [Pins.CLAW_TURN_ROW] as Array[int], "only the half-turn fits")
	var poses: Array = _drive(start, turned, Pins.CLAW_TURN_ROW, a, 0, 45)
	var program: int = _motion.program_of(Pins.CLAW_TURN_ROW)
	assert_equal([poses[21][0], poses[21][1]], [a + _motion.root_at(program, 132), _motion.heading_at(program, 132)], "key 132")
	assert_equal([poses[44][0], poses[44][1], poses[44][2]], [u, 32768, turned], "faces up the stair on its stop")


func test_the_ascent_climbs_one_tread_facing_up() -> void:
	"""From 343 u behind the lower deck's far edge to 343 u behind the upper's, facing up, in 30 ticks."""
	_compose()
	var low: Vector3i = Vector3i(X + 1024, LOW, FAR - 169)
	var u: Vector3i = low + Vector3i(0, 128, 512)
	var lower: Vector2i = _location(low, 1, true, 169)
	var upper: Vector2i = _location(u, 0, true, 160)
	var added: Routes.Result = _publish(_edge(lower, upper, low, u, 0))
	assert_equal(_masked(added.ref), [Pins.CLAW_ASCENT_ROW] as Array[int], "only the ascent fits")
	var poses: Array = _drive(lower, upper, Pins.CLAW_ASCENT_ROW, low, 32768, 30)
	var program: int = _motion.program_of(Pins.CLAW_ASCENT_ROW)
	assert_equal(poses[14][0], low + _motion.root_at(program, 45), "key 45")
	assert_equal([poses[29][0], poses[29][1], poses[29][2]], [u, 32768, upper], "up one tread in 30 ticks")


func test_the_short_step_back_takes_two_movement_ticks() -> void:
	"""The 141 u step back on a deck (a ground edge) keeps facing down the stair and lands on the station."""
	_compose()
	var a: Vector3i = Vector3i(X + 1024, UP, FAR + 169)
	var s: Vector3i = a + Vector3i(0, 0, 141)
	var start: Vector2i = _location(a, 0, false, 300)
	var station: Vector2i = _location(s, 0, false, 160)
	var added: Routes.Result = _publish(_edge(start, station, a, s, -1))
	assert_equal(added.error, &"", "a ground edge")
	assert_true(Pins.CLAW_STEP_BACK_ROW in _masked(added.ref), "the step back fits")
	var poses: Array = _drive(start, station, Pins.CLAW_STEP_BACK_ROW, a, 0, 2)
	assert_equal([poses[0][0], poses[0][1]], [a + Vector3i(0, 0, 70), 0], "half way, still facing down")
	assert_equal([poses[1][0], poses[1][2], poses[1][3]], [s, station, Stair.word(Routes.PHASE_IDLE, Stair.READY)],
		"on the station, READY")


func test_a_missing_deck_or_foreign_matter_refuses_the_stair_edge() -> void:
	"""A lower deck 100 u short of the riser is not the fixture the descent was proved on; an obstacle in its body
	blocks it; without the bound
	stair tables a connector edge still needs its source."""
	var a: Vector3i = Vector3i(X + 1024, UP, FAR + 169)
	var b: Vector3i = a + Vector3i(0, -128, -512)
	for fault: int in 3:
		_compose(fault != 0, fault == 1, fault != 2)
		var top: Vector2i = _location(a, 0, false, 235)
		var bottom: Vector2i = _location(b, 1, false, 300)
		var added: Routes.Result = _publish(_edge(top, bottom, a, b, 0))
		var expected: StringName = &"WORLD_ROUTE_FIXED_CONNECTOR_SOURCE_REQUIRED" if fault == 2 else &"WORLD_ROUTE_NO_FITTING_PROFILE"
		assert_equal(added.error, expected, "fault %d refused" % fault)
		after_each()
		before_each()

