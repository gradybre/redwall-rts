extends "res://test/framework/test_case.gd"
## Real World/Terrain/Level/Space/Budget preflight. Existing obstacle fixture placement alone is synthetic.
## There is no productive contact, profile, entry, support qualification or successful Room admission here.

const Bindings := preload("res://scripts/core/underground_room_bindings.gd")
const Orders := preload("res://scripts/core/underground_room_orders.gd")
const WorldBindings := preload("res://scripts/core/underground_world_bindings.gd")
const Terrain := preload("res://scripts/core/underground_terrain.gd")
const World := preload("res://scripts/core/world_init.gd")
const Nodes := preload("res://scripts/core/resource_nodes.gd")
const Residents := preload("res://scripts/core/residents.gd")
const Jobs := preload("res://scripts/core/jobs.gd")
const Forage := preload("res://scripts/core/forage.gd")
const Fishing := preload("res://scripts/core/fishing.gd")
const Rng := preload("res://scripts/core/rng.gd")
const Items := preload("res://scripts/core/item_definitions.gd")
const Inventory := preload("res://scripts/core/inventory.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const Construction := preload("res://scripts/core/construction.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const Sites := preload("res://scripts/core/excavation_sites.gd")
const Work := preload("res://scripts/core/work.gd")
const Gear := preload("res://scripts/core/gear.gd")
const Reservations := preload("res://scripts/core/reservations.gd")
const Router := preload("res://scripts/core/modular_projects.gd")
const RoomCatalog := preload("res://scripts/core/room_catalog.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const Levels := preload("res://scripts/core/underground_level_catalog.gd")
const Footprint := preload("res://scripts/core/room_footprint.gd")
const MaskFixture := preload("res://test/test_underground_room_bindings.gd")
const RoomFixture := preload("res://test/test_underground_furniture_work.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)
const X: int = 60 * 2048
const Z: int = 50 * 2048
const LEVEL_PACK: String = "res://data/underground/initial_level_pack.uglvl"
const LEVEL_SHA: String = "c5deb094b335bf6e5db018eeed591a115086b79bd909f829ed6e34166db81f94"

class ReleaseProbe extends RefCounted:
	## External composition ownership can disappear inside a real callback; the active borrower must survive.
	var router: Router = null
	var sites: Sites = null
	var observed: WeakRef = null
	var retained_after_release: bool = false

	func drop_outer_owners() -> void:
		"""Release only test-owned outer references, then observe the real synchronous Sites borrower."""
		router = null
		sites = null
		retained_after_release = observed.get_ref() != null

class ObservedWorld extends WorldBindings:
	## Exact composer wiring remains real; callbacks inject only caller growth and outer-owner release.
	var arena: Budget = null
	var grow_before_copy: Orders.RoomPlan = null
	var release_probe: ReleaseProbe = null

	func binding_refusal() -> StringName:
		"""Grow only after real lease admission, before the provider's first copy."""
		var code: StringName = super.binding_refusal()
		if grow_before_copy != null and arena != null and not arena.is_quiescent():
			grow_before_copy.cells.resize((Footprint.MAX_OPERATION_CELLS + 1) * 2)
			grow_before_copy = null
		if release_probe != null and arena != null and not arena.is_quiescent():
			release_probe.drop_outer_owners()
		return code

class ObservedSpace extends RoomFixture.WatchedSpace:
	## The full actual retained owner supplies the image; callbacks inject adversarial lifetime changes.
	var surveys: int = 0
	var arena: Budget = null
	var expire: bool = false
	var replacement: int = 0
	var orders: WeakRef = null
	var rooms: WeakRef = null
	var nested_plan: Orders.RoomPlan = null
	var nested_error: StringName = &""
	var mutate_after_copy: Orders.RoomPlan = null

	func snapshot_into(out: Space.Snapshot) -> StringName:
		"""Observe the actual source image before changing a caller input or the exact held token."""
		surveys += 1
		var token: int = (rooms.get_ref() as Bindings).room_cold_token()
		var code: StringName = super.snapshot_into(out)
		if mutate_after_copy != null:
			mutate_after_copy.cells[0] += 1
			mutate_after_copy = null
		if nested_plan != null:
			var plan: Orders.RoomPlan = nested_plan
			nested_plan = null
			nested_error = (orders.get_ref() as Orders).confirm_room(plan).error
		if expire:
			expire = false
			assert(arena.release(token) == &"", "exact originally admitted lease")
			replacement = arena.acquire(Budget.COLD_BYTES)
		return code

class ObservedTerrain extends Terrain:
	## Exact original terrain checks run in every observed window; no synthetic dry-soil permission.
	var calls: int = 0
	var maximum_tiles: int = 0
	var expire: bool = false
	var replacement: int = 0
	var arena: Budget = null
	var rooms: WeakRef = null

	func dig_refusal(bounds: PackedInt32Array) -> StringName:
		"""Count actual tile spans and optionally replace the lease after one genuine terrain query."""
		calls += 1
		@warning_ignore("integer_division") var width: int = (bounds[3] - 1) / World.TILE_SIZE_UNITS - bounds[0] / World.TILE_SIZE_UNITS + 1
		@warning_ignore("integer_division") var depth: int = (bounds[5] - 1) / World.TILE_SIZE_UNITS - bounds[2] / World.TILE_SIZE_UNITS + 1
		maximum_tiles = maxi(maximum_tiles, width * depth)
		var code: StringName = super.dig_refusal(bounds)
		if expire:
			expire = false
			var token: int = (rooms.get_ref() as Bindings).room_cold_token()
			assert(arena.release(token) == &"", "actual query held the original token")
			replacement = arena.acquire(Budget.COLD_BYTES)
		return code

class ObservedRooms extends Bindings:
	## Count the real allocation boundary; a refused huge plan must never enter it.
	var preflights: int = 0

	func _admission_preflight(provider: WorldBindings, levels: Levels) -> StringName:
		"""Keep real geometry behavior while observing whether cold allocations begin."""
		preflights += 1
		return super._admission_preflight(provider, levels)

var _residents: Residents = null
var _jobs: Jobs = null
var _nodes: Nodes = null
var _world: World = null
var _inventory: Inventory = null
var _items: Items = null
var _buildings: Buildings = null
var _construction: Construction = null
var _sources: Owner.CoreSources = null
var _space: ObservedSpace = null
var _terrain: ObservedTerrain = null
var _provider: ObservedWorld = null
var _budget: Budget = null
var _levels: Levels = null
var _physical: MaskFixture.SyntheticSpatial = null
var _sites: Sites = null
var _router: Router = null
var _orders: RoomFixture.SyntheticRegistration = null
var _rooms: ObservedRooms = null
var _world_ref: Vector2i = NULL_REF


func before_each() -> void:
	"""Build an actual generated World and every real identity/accounting owner before the provider binds."""
	_residents = Residents.new()
	_jobs = Jobs.new(_residents)
	_nodes = Nodes.new(_jobs.directory())
	var forage: Forage = Forage.new(_jobs.directory(), _jobs)
	var fishing: Fishing = Fishing.new(_jobs.directory(), forage, _jobs)
	_world = World.new(_jobs.directory(), _nodes, forage, fishing, Rng.new(), null, null, _jobs)
	_inventory = Inventory.new(32, 256)
	_items = Items.new()
	assert_true(_items.load_default(_inventory).ok, "actual adopted materials")
	assert_true(_world.generate(World.bound_request(_items).request).ok, "actual original World")
	_world_ref = _jobs.directory().create(Directory.KIND_WORLD)
	_buildings = Buildings.new(_jobs.directory())
	_construction = Construction.new(_buildings)
	_sources = Owner.CoreSources.new(_jobs.directory(), _buildings, _construction)
	_budget = Budget.new()
	_bind_space()
	_bind_accounting()
	_bind_rooms()


func _domain() -> Space.Domain:
	"""Exact actual level-pack domain and paid datum; painted cells keep a separate pitch."""
	var domain: Space.Domain = Space.Domain.new()
	assert_equal(domain.configure(_world_ref, Vector3i(0, 512, 0), Vector3i(0, -32, 0),
		Vector3i(256, 48, 256), Footprint.MAX_OPERATION_CELLS, 8192, Space.MAX_CHECKS), &"", "actual content domain")
	return domain


func _bind_space() -> void:
	"""No existing completed void or free entrance is supplied by this real untouched terrain fixture."""
	_space = ObservedSpace.new(_sources)
	_space.arena = _budget
	assert_equal(_space.configure(_domain(), Budget.REGION_CAPACITY, Budget.SOURCE_CAPACITY), &"", "actual sparse arena")
	_terrain = ObservedTerrain.new()
	_terrain.arena = _budget
	assert_equal(_terrain.configure(_world, _nodes, _space, _sources, _items, _budget), &"", "actual geology/exclusions")
	_provider = ObservedWorld.new()
	_provider.arena = _budget
	assert_equal(_provider.configure(_world, _terrain, _space, _sources, _budget), &"", "actual World composer")
	_levels = Levels.new()
	assert_equal(_levels.load_file(LEVEL_PACK, LEVEL_SHA, 1), &"", "real source-pinned level pack")
	var domain: Space.Domain = _domain()
	assert_equal(_levels.bind_domain(domain, _jobs.directory(), domain.descriptor(), Space.VERSION), &"", "exact World/content binding")


func _bind_accounting() -> void:
	"""Only unstarted Sites fixture registration is synthetic; all stores, Funding and Router are actual."""
	var work: Work = Work.new(_jobs)
	var gear: Gear = Gear.new(8)
	var reservations: Reservations = Reservations.new()
	assert_true(gear.bind_equipment(_inventory, _jobs.directory(), _residents).ok, "actual Gear namespace")
	assert_true(work.bind_gear(gear).ok, "actual Work equipment")
	_physical = MaskFixture.SyntheticSpatial.new()
	_physical.domain = _domain()
	_physical.buildings = _buildings
	_sites = Sites.new(_construction, _inventory, reservations, _items, _jobs, work, _physical, 32, 8)
	assert_equal(_sites.initialization_refusal(), &"", "real physical history")
	_router = Router.new(_construction, _inventory, reservations, _items, _jobs, work, _sites)
	assert_equal(_router.initialization_refusal(), &"", "actual shared paid operation owner")


func _bind_rooms() -> void:
	"""The one actual RoomOrders authority owns both existing fixture identities and real confirmation."""
	_rooms = ObservedRooms.new()
	assert_equal(_rooms.configure(_provider, _sites, _budget), &"", "actual room phase provider")
	_orders = RoomFixture.SyntheticRegistration.new()
	assert_equal(_orders.configure(_router, _space, _sources, RoomCatalog.new(), _rooms), &"", "actual sole Room authority")
	assert_equal(_rooms.configure_room_admission(_orders, _levels), &"", "actual admission owner and level catalog")
	_space.orders = weakref(_orders)
	_space.rooms = weakref(_rooms)
	_terrain.rooms = weakref(_rooms)


func after_each() -> void:
	"""Every refusal releases all original cold buffers and no authoritative owner leaks through callbacks."""
	if _space.replacement > 0:
		assert_equal(_budget.release(_space.replacement), &"", "test owns the replacement lease")
	if _terrain.replacement > 0:
		assert_equal(_budget.release(_terrain.replacement), &"", "test owns the terrain replacement lease")
	assert_true(_budget.is_quiescent(), "no cross-frame room lease")
	assert_false(_space.has_prepared(), "no leaked future source candidate")
	assert_true(_orders._room_plan.cells.is_empty(), "coordinator plan cleared")
	assert_null(_rooms._room_pin, "provider copied plan dropped before release")
	_space.nested_plan = null
	_rooms = null
	_orders = null
	_router = null
	_sites = null
	_physical = null
	_levels = null
	_provider = null
	_terrain = null
	_space = null
	_sources = null
	_construction = null
	_buildings = null
	_world = null
	_nodes = null
	_jobs = null
	_residents = null
	_inventory = null
	_items = null
	_budget = null


func _plan(level: int = 1, cells: PackedInt32Array = PackedInt32Array([0, 0, 1, 0, 0, 1]),
		pitch: int = 256, offset: int = 0) -> Orders.RoomPlan:
	"""Choose authored actual Y from the catalog; no test-specific floor spacing enters production."""
	var record: Levels.Record = Levels.Record.new()
	assert_equal(_levels.level_into(level, offset, record), &"", "selected actual authored level")
	var plan: Orders.RoomPlan = Orders.RoomPlan.new()
	plan.world = _world_ref
	plan.space_revision = _space.revision()
	plan.room_type = Buildings.ROOM_TYPE_KITCHEN
	plan.level = level
	plan.origin_u = Vector3i(X, record.floor_y_u, Z)
	plan.cell_size_u = pitch
	plan.height_u = record.clear_height_u
	plan.cells = cells.duplicate()
	return plan


func _state() -> PackedByteArray:
	"""Actual row images include allocation/generation history, paid progress and resource ownership."""
	var out: PackedByteArray = _jobs.directory().state_bytes()
	out.append_array(_buildings.spatial_state_bytes())
	out.append_array(_construction.state_bytes())
	out.append_array(_space.state_bytes())
	out.append_array(_sites.state_bytes())
	out.append_array(_inventory.state_bytes())
	return out


func _assert_refusal(plan: Orders.RoomPlan, expected: StringName) -> void:
	"""No refused static preflight spends a Room, project, item, physical site or allocator generation."""
	var before: PackedByteArray = _state()
	var result: Buildings.OpResult = _orders.confirm_room(plan)
	assert_false(result.ok, "static observation alone never completes admission")
	assert_equal(result.error, expected, "exact actual refusal")
	assert_equal(_state(), before, "every authoritative byte remains unchanged")
	assert_true(_budget.is_quiescent() or _space.replacement > 0 or _terrain.replacement > 0, "own synchronous lease is released")


func _room(level: int = 1) -> Vector2i:
	"""Initial obstacle setup alone has an explicit synthetic registration bracket in the actual owner."""
	_orders.permit_action = Buildings.SPATIAL_ROOM_CREATE
	_orders.permit_value = Buildings.ROOM_TYPE_KITCHEN
	var made: Buildings.OpResult = _buildings.designate_spatial_room(Buildings.ROOM_TYPE_KITCHEN)
	_orders.permit_action = -1
	assert_true(made.ok, "actual fixture Room")
	var stage: Owner.Result = _space.begin_stage(_space.revision())
	assert_equal(_space.stage_source(stage.token, made.ref), &"", "actual full Room source")
	var record: Levels.Record = Levels.Record.new()
	assert_equal(_levels.level_into(level, 0, record), &"", "fixture actual floor")
	_put(stage.token, PackedInt32Array([X, record.floor_y_u, Z, X + 4096, record.floor_y_u + 1, Z + 4096]),
		Space.FLOOR_DATUM, made.ref, level)
	_publish(stage.token)
	return made.ref


func _put(token: int, box: PackedInt32Array, role: int, source: Vector2i, level: int,
		section: Vector2i = NULL_REF, claim: bool = false) -> Vector2i:
	"""Actual sparse validation owns every fixture shape, source generation and typed reservation."""
	var region: Owner.Region = Owner.Region.new()
	region.box = box
	region.role = role
	region.owner = source
	region.level = level
	region.section = section
	if claim:
		region.claim_kind = Owner.CLAIM_ROOM
		region.claim_ref = source
	var made: Owner.Result = _space.stage_add(token, region)
	assert_equal(made.error, &"", "actual fixture row")
	return made.handle


func _publish(token: int) -> void:
	"""No fixture bypasses actual source validation or sparse publication."""
	assert_equal(_space.seal(token), &"", "actual fixture candidate seals")
	_space.publish(token)


func _floor(room: Vector2i) -> Vector2i:
	"""Fixture-only cold lookup of the actual full floor generation."""
	var handles: PackedInt32Array = PackedInt32Array()
	assert_equal(_space.overlapping_regions_into(_domain()._bounds, handles), &"", "actual fixture region query")
	var region: Owner.Region = Owner.Region.new()
	region.box.resize(6)
	for at: int in range(0, handles.size(), 2):
		assert_equal(_space.region_into_reused(Vector2i(handles[at], handles[at + 1]), region), &"", "actual handle")
		if region.owner == room and region.role == Space.FLOOR_DATUM:
			return region.section
	return NULL_REF


func test_clear_actual_dirt_reaches_missing_entry_without_publishing_a_free_room() -> void:
	"""Authored height plus dry terrain is useful evidence, but cannot invent first work or a connector."""
	var plan: Orders.RoomPlan = _plan()
	var cells: PackedInt32Array = plan.cells.duplicate()
	_assert_refusal(plan, Bindings.REFUSE_ENTRY)
	assert_equal(_space.surveys, 1, "one actual unfiltered retained owner image")
	assert_equal(plan.cells, cells, "exact fine concave input is untouched")
	assert_equal(_buildings.live_room_count(), 0, "no prematurely accepted Room")
	assert_equal(_construction.live_project_count(), 0, "no fake entry or work project")
	assert_equal(_budget.peak_reserved_bytes(), Budget.COLD_BYTES, "whole simultaneous peak admitted")


func test_oversize_and_busy_refuse_before_domain_plan_or_snapshot_copy() -> void:
	"""The complete existing footprint ceiling fits; a larger caller shape refuses before any owned copy."""
	assert_equal(Bindings.room_admission_cold_bytes(Footprint.MAX_OPERATION_CELLS), 722944, "complete simultaneous envelope")
	assert_true(Bindings.room_admission_cold_bytes(478) < Budget.COLD_BYTES, "no inherited477-cell cap")
	assert_equal(Bindings.room_admission_cold_bytes(Footprint.MAX_OPERATION_CELLS + 1), 0, "existing public ceiling preserved")
	var cells: PackedInt32Array = PackedInt32Array()
	for x: int in Footprint.MAX_OPERATION_CELLS + 1:
		cells.append_array(PackedInt32Array([x, 0]))
	var plan: Orders.RoomPlan = _plan(1, cells)
	var copies: int = _space.domain_calls
	_assert_refusal(plan, Orders.REFUSE_PLAN)
	assert_equal(_rooms.preflights, 0, "no provider copy or Footprint validation")
	assert_equal(_space.domain_calls, copies, "no Domain copy")
	assert_equal(_space.surveys, 0, "no spatial copy")
	assert_equal(plan.cells, cells, "oversize input not trimmed")
	var token: int = _budget.acquire(Budget.COLD_BYTES)
	assert_equal(_orders.confirm_room(_plan()).error, Budget.REFUSE_BUSY, "another real owner holds the arena")
	assert_true(_budget.covers(token, Budget.COLD_BYTES), "foreign lease preserved")
	assert_equal(_budget.release(token), &"", "actual foreign owner releases")


func test_level_label_height_and_floor_must_match_actual_catalog() -> void:
	"""A depth label cannot disguise a wall overlap or make an arbitrary gap into an authored room height."""
	var plan: Orders.RoomPlan = _plan()
	plan.level = 2
	_assert_refusal(plan, Bindings.REFUSE_LEVEL)
	plan = _plan()
	plan.height_u -= 1
	_assert_refusal(plan, Bindings.REFUSE_LEVEL)
	plan = _plan()
	plan.origin_u.y += 1
	_assert_refusal(plan, Bindings.REFUSE_LEVEL)
	_assert_refusal(_plan(2, PackedInt32Array([0, 0]), 512, 1024), Bindings.REFUSE_ENTRY)


func test_full_paid_cube_rejects_wall_outside_fine_shape_and_other_depth_stays_separate() -> void:
	"""Fine boundaries grant no unpriced sliver around an obstacle inside the same physical cut."""
	var token: int = _space.begin_stage(_space.revision()).token
	_put(token, PackedInt32Array([X + 512, -9728, Z, X + 768, -8704, Z + 256]), Space.OBSTACLE, _world_ref, 2)
	_publish(token)
	_assert_refusal(_plan(2, PackedInt32Array([0, 0])), Bindings.REFUSE_CUT)
	_assert_refusal(_plan(1, PackedInt32Array([0, 0])), Bindings.REFUSE_ENTRY)


func test_existing_room_claims_and_actual_pending_items_remain_blockers() -> void:
	"""Unfiltered admission cannot borrow the exact-claim exemptions used only by an already owned paid Site."""
	var room: Vector2i = _room(2)
	var floor_ref: Vector2i = _floor(room)
	var token: int = _space.begin_stage(_space.revision()).token
	_put(token, PackedInt32Array([X, -9728, Z, X + 256, -5632, Z + 256]), Space.OBSTACLE, room, 2, floor_ref, true)
	_publish(token)
	_assert_refusal(_plan(2, PackedInt32Array([0, 0])), Bindings.REFUSE_CUT)
	_assert_refusal(_plan(1, PackedInt32Array([0, 0])), Bindings.REFUSE_ENTRY)
	_orders.permit_action = Buildings.SPATIAL_FURNITURE_CREATE
	_orders.permit_related = room
	_orders.permit_value = Catalog.FURNITURE_DEFINITION["shelf"]
	var made: Buildings.OpResult = _buildings.stage_spatial_furniture(room, _orders.permit_value, 0)
	_orders.permit_action = -1
	assert_true(made.ok, "actual pending Furniture row")
	token = _space.begin_stage(_space.revision()).token
	assert_equal(_space.stage_source(token, made.ref), &"", "actual pending item source")
	_put(token, PackedInt32Array([X + 1024, -9728, Z, X + 1280, -8704, Z + 256]), Space.OBSTACLE, made.ref, 2, floor_ref)
	_publish(token)
	var plan: Orders.RoomPlan = _plan(2, PackedInt32Array([0, 0]))
	plan.origin_u.x += 1024
	_assert_refusal(plan, Bindings.REFUSE_CUT)


func test_protected_above_and_required_footing_use_actual_xyz_bands() -> void:
	"""A selected lower room cannot erase occupied protection or footing just by changing its depth label."""
	var token: int = _space.begin_stage(_space.revision()).token
	_put(token, PackedInt32Array([X, -5600, Z, X + 256, -5500, Z + 256]), Space.OBSTACLE, _world_ref, 1)
	_publish(token)
	_assert_refusal(_plan(2, PackedInt32Array([0, 0])), Bindings.REFUSE_ABOVE)
	var shifted: Orders.RoomPlan = _plan(2, PackedInt32Array([0, 0]))
	shifted.origin_u.x += 2048
	token = _space.begin_stage(_space.revision()).token
	_put(token, PackedInt32Array([X + 2048, -10000, Z, X + 2304, -9900, Z + 256]), Space.UNFINISHED, _world_ref, 2)
	_publish(token)
	shifted.space_revision = _space.revision()
	_assert_refusal(shifted, Bindings.REFUSE_FOOTING)


func test_hole_occupancy_is_not_filled_by_metadata_or_room_bounds() -> void:
	"""A whole-cube hole remains outside all exact painted runs and their local vertical obligations."""
	var token: int = _space.begin_stage(_space.revision()).token
	_put(token, PackedInt32Array([X + 1024, -9000, Z + 1024, X + 2048, -8000, Z + 2048]), Space.OBSTACLE, _world_ref, 2)
	_publish(token)
	var ring: PackedInt32Array = PackedInt32Array([0, 0, 1, 0, 2, 0, 0, 1, 2, 1, 0, 2, 1, 2, 2, 2])
	_assert_refusal(_plan(2, ring, 1024), Bindings.REFUSE_ENTRY)


func test_retained_physical_history_cannot_be_reclassified_as_virgin_by_a_new_plan() -> void:
	"""Even a history row with no currently published void needs the actual reuse/backfill companion."""
	var room: Vector2i = _room(2)
	assert_true(_sites.claim_quantum(Vector3i(X, -9728, Z), room).ok, "actual immutable paid-lattice identity")
	_assert_refusal(_plan(2, PackedInt32Array([0, 0])), Bindings.REFUSE_RETAINED)


func test_snapshot_callback_lease_replacement_clears_owned_scratch_and_preserves_foreign_lease() -> void:
	"""A full returned snapshot cannot substitute for the exact current cold reservation."""
	_space.expire = true
	_assert_refusal(_plan(), Orders.REFUSE_ROOM_COLD)
	assert_true(_budget.covers(_space.replacement, Budget.COLD_BYTES), "cleanup did not steal replacement")
	assert_null(_rooms._room_pin, "copied plan dropped on lifetime refusal")
	assert_true(_orders._room_plan.cells.is_empty(), "coordinator never copied after false admission")


func test_source_callback_reentry_refuses_before_any_nested_cold_acquisition() -> void:
	"""The real outer observer keeps exclusivity before every provider callback."""
	_space.nested_plan = _plan()
	_assert_refusal(_plan(), Bindings.REFUSE_ENTRY)
	assert_equal(_space.nested_error, Orders.REFUSE_TRANSITION, "nested Room confirmation refused immediately")
	assert_equal(_space.surveys, 1, "only the outer actual snapshot exists")


func test_unscoped_direct_begin_and_refused_rebinding_have_no_permission() -> void:
	"""Public provider entry still requires the actual sole coordinator's exact active input object."""
	assert_equal(_rooms.begin_room_cold(_plan()), Bindings.REFUSE_ADMISSION, "idle direct call")
	assert_equal(_rooms.configure_room_admission(_orders, _levels), Bindings.REFUSE_ADMISSION, "once-bound wiring")
	assert_equal(Bindings.new().configure_room_admission(_orders, _levels), Bindings.REFUSE_ADMISSION, "unconfigured provider")
	assert_true(_budget.is_quiescent(), "no idle caller acquires cold memory")


func test_callback_grown_input_refuses_before_any_owned_copy() -> void:
	"""A valid small input cannot pass admission then grow beyond the reserved Footprint/native peak."""
	var plan: Orders.RoomPlan = _plan()
	_provider.grow_before_copy = plan
	var copies: int = _space.domain_calls
	_assert_refusal(plan, Budget.REFUSE_BYTES)
	assert_equal(plan.cells.size(), (Footprint.MAX_OPERATION_CELLS + 1) * 2, "adversarial caller mutation remains visible, never silently truncated")
	assert_equal(_rooms.preflights, 0, "no provider plan/Footprint/Domain allocation entered")
	assert_equal(_space.domain_calls, copies, "no Domain copy after false size qualification")
	assert_equal(_space.surveys, 0, "no actual whole-space copy")
	_assert_refusal(_plan(), Bindings.REFUSE_ENTRY)


func test_snapshot_callback_cannot_change_the_exact_copied_shape() -> void:
	"""Current terrain evidence never qualifies a different player outline after the original was pinned."""
	var plan: Orders.RoomPlan = _plan()
	_space.mutate_after_copy = plan
	_assert_refusal(plan, Orders.REFUSE_ROOM_COLD)
	assert_equal(plan.cells[0], 1, "caller mutation is not overwritten as a fake rollback")
	assert_null(_rooms._room_pin, "only the owned copy is dropped")
	_assert_refusal(_plan(), Bindings.REFUSE_ENTRY)


func test_equal_numbered_foreign_level_binding_and_expired_catalog_refuse() -> void:
	"""A catalog bound to a different actual Directory cannot qualify coincident numeric World metadata."""
	var foreign_directory: Directory = Directory.new()
	for slot: int in _world_ref.x:
		foreign_directory.create(Directory.KIND_ROOM)
	var foreign_world: Vector2i = foreign_directory.create(Directory.KIND_WORLD)
	while foreign_world.y < _world_ref.y:
		assert_true(foreign_directory.destroy(foreign_world), "advance actual foreign World generation")
		foreign_world = foreign_directory.create(Directory.KIND_WORLD)
	assert_equal(foreign_world, _world_ref, "deliberately equal numeric World")
	var foreign_levels: Levels = Levels.new()
	assert_equal(foreign_levels.load_file(LEVEL_PACK, LEVEL_SHA, 1), &"", "same authored catalog")
	var domain: Space.Domain = _domain()
	assert_equal(foreign_levels.bind_domain(domain, foreign_directory, domain.descriptor(), Space.VERSION), &"", "foreign owner binding")
	_rooms._levels = weakref(foreign_levels)
	_assert_refusal(_plan(), Bindings.REFUSE_LEVEL)
	_rooms._levels = weakref(_levels)
	var plan: Orders.RoomPlan = _plan()
	_levels = null
	_assert_refusal(plan, Bindings.REFUSE_ADMISSION)
	assert_equal(_space.surveys, 0, "neither false catalog reaches a whole-space survey")


func test_actual_sites_survives_callback_outer_release_until_scope_cleanup() -> void:
	"""The synchronous admission borrows the real physical owner while expired coordinator wiring refuses."""
	var plan: Orders.RoomPlan = _plan()
	var probe: ReleaseProbe = ReleaseProbe.new()
	probe.router = _router
	probe.sites = _sites
	probe.observed = weakref(_sites)
	_provider.release_probe = probe
	var before: Array[PackedByteArray] = [_jobs.directory().state_bytes(), _space.state_bytes(),
		_construction.state_bytes(), _inventory.state_bytes()]
	_router = null
	_sites = null
	assert_equal(_orders.confirm_room(plan).error, Orders.REFUSE_ROOM_COLD, "expired actual composition refuses")
	assert_true(probe.retained_after_release, "actual Sites remains alive throughout the synchronous callback")
	assert_null(probe.observed.get_ref(), "no hidden strong Sites reference remains after cleanup")
	assert_equal(_rooms.preflights, 0, "no copied plan or geometry enters after actual owner expiry")
	assert_true(_budget.is_quiescent(), "exact admitted lease releases")
	var after: Array[PackedByteArray] = [_jobs.directory().state_bytes(), _space.state_bytes(),
		_construction.state_bytes(), _inventory.state_bytes()]
	assert_equal(after, before, "no actual identity, geometry, payment or inventory changes")


func test_full_existing_cell_ceiling_reaches_entry_refusal_under_one_actual_lease() -> void:
	"""A complete16,384-cell plan fits real admission scratch without replacing477 with another room-size policy."""
	var cells: PackedInt32Array = Footprint.rectangle(0, 0, 128, 128, Footprint.MAX_OPERATION_CELLS).cells
	var plan: Orders.RoomPlan = _plan(2, cells)
	plan.origin_u.x = 20 * World.TILE_SIZE_UNITS
	plan.origin_u.z = 20 * World.TILE_SIZE_UNITS
	_assert_refusal(plan, Bindings.REFUSE_ENTRY)
	assert_equal(plan.cells, cells, "full exact outline remains unchanged")
	assert_equal(_space.surveys, 1, "one complete actual retained image")
	assert_true(_terrain.calls > 3, "every fine run and authored band is observed")
	assert_true(_terrain.maximum_tiles <= Terrain.LOCAL_TILE_LIMIT, "all actual local queries stay bounded")
	assert_equal(_budget.peak_reserved_bytes(), Budget.COLD_BYTES, "all copies share the actual arena")


func _long_plan() -> Orders.RoomPlan:
	"""A single fine run spans66 actual surface tiles while remaining entirely in authored dry land."""
	var cells: PackedInt32Array = Footprint.rectangle(0, 0, 130, 1, Footprint.MAX_OPERATION_CELLS).cells
	var plan: Orders.RoomPlan = _plan(2, cells, 1024)
	plan.origin_u.x = 4 * World.TILE_SIZE_UNITS + 1024
	return plan


func test_long_run_is_exactly_windowed_instead_of_inheriting_local_terrain_capacity() -> void:
	"""A local read limit is not a Room width limit; clipped windows cover the same full physical extent."""
	var plan: Orders.RoomPlan = _long_plan()
	var bounds: PackedInt32Array = PackedInt32Array([plan.origin_u.x, plan.origin_u.y, plan.origin_u.z,
		plan.origin_u.x + 130 * 1024, plan.origin_u.y + plan.height_u, plan.origin_u.z + 1024])
	assert_equal(_terrain.dig_refusal(bounds), &"TERRAIN_LOCAL_CAPACITY", "same complete run exceeds one local read")
	_terrain.maximum_tiles = 0
	_terrain.calls = 0
	_assert_refusal(plan, Bindings.REFUSE_ENTRY)
	assert_true(_terrain.calls >= 27, "cut, footing and roof each require multiple exact windows")
	assert_true(_terrain.maximum_tiles <= Terrain.LOCAL_TILE_LIMIT, "no enlarged local query bypass")
	assert_equal(_space.surveys, 1, "long plan does not duplicate retained images")


func test_large_hole_keeps_retained_occupancy_outside_exact_room_runs() -> void:
	"""One full source image cannot turn its bounding envelope into an occupied or usable room area."""
	var origin: int = 20 * World.TILE_SIZE_UNITS
	var token: int = _space.begin_stage(_space.revision()).token
	_put(token, PackedInt32Array([origin + 8192, -9000, origin + 8192,
		origin + 9216, -8000, origin + 9216]), Space.OBSTACLE, _world_ref, 2)
	_publish(token)
	var ring: PackedInt32Array = PackedInt32Array()
	for z: int in 128:
		for x: int in 128:
			if x == 0 or z == 0 or x == 127 or z == 127:
				ring.append_array(PackedInt32Array([x, z]))
	assert_equal(ring.size(), 508 * 2, "holey outline already exceeds the removed temporary cap")
	var plan: Orders.RoomPlan = _plan(2, ring)
	plan.origin_u.x = origin
	plan.origin_u.z = origin
	_assert_refusal(plan, Bindings.REFUSE_ENTRY)
	assert_equal(plan.cells, ring, "no bounding-box fill or hole deletion")
	plan.cells = Footprint.rectangle(0, 0, 128, 128, Footprint.MAX_OPERATION_CELLS).cells
	_assert_refusal(plan, Bindings.REFUSE_CUT)


func test_window_callback_losing_lease_stops_before_next_read_and_preserves_replacement() -> void:
	"""After one actual terrain window returns, lost lifetime cannot fund another query or any publication."""
	_terrain.expire = true
	_assert_refusal(_long_plan(), Orders.REFUSE_ROOM_COLD)
	assert_equal(_terrain.calls, 1, "no second window entered after original lease loss")
	assert_equal(_space.surveys, 1, "the original retained image was observed only once")
	assert_true(_budget.covers(_terrain.replacement, Budget.COLD_BYTES), "cleanup preserves another exact token")
	assert_null(_rooms._room_pin, "owned plan dropped before cleanup")
	assert_true(_orders._room_plan.cells.is_empty(), "no downstream candidate copy after refusal")


func test_wide_and_deep_cell_checks_all_actual_eight_by_eight_tile_windows() -> void:
	"""The engineering window bounds both horizontal axes without changing the caller's exact cell pitch."""
	var plan: Orders.RoomPlan = _plan(2, PackedInt32Array([0, 0]), 32768)
	plan.origin_u.x = 20 * World.TILE_SIZE_UNITS
	plan.origin_u.z = 20 * World.TILE_SIZE_UNITS
	_assert_refusal(plan, Bindings.REFUSE_ENTRY)
	assert_equal(_terrain.calls, 12, "four windows for each of cut, footing and roof")
	assert_equal(_terrain.maximum_tiles, Terrain.LOCAL_TILE_LIMIT, "actual full64-tile windows")
	assert_equal(plan.cell_size_u, 32768, "no cell-size snapping or truncation")


func test_later_terrain_window_observes_actual_river_instead_of_accepting_first_dry_window() -> void:
	"""Original water remains a blocker beyond the first local window, without any sparse obstacle fixture."""
	var plan: Orders.RoomPlan = _plan(2, PackedInt32Array([0, 0]), 32768)
	plan.origin_u.x = World.RIVER_FIRST_X * World.TILE_SIZE_UNITS - 17 * 1024
	plan.origin_u.z = 60 * World.TILE_SIZE_UNITS
	_assert_refusal(plan, Terrain.REFUSE_WATER)
	assert_equal(_terrain.calls, 2, "first exact dry window passes and second observes live river")
	assert_true(_terrain.maximum_tiles <= Terrain.LOCAL_TILE_LIMIT, "late refusal used bounded actual reads")
