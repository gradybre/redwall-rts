extends "res://test/framework/test_case.gd"
## Actual generated estuary/Directory/resource/Building inputs; no mock terrain permission.

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
const Catalog := preload("res://scripts/core/catalog.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const CLEAR_TILE: int = 50 * 128 + 60


class ObservedOwner extends Owner:
	## Count real World-source lookups without replacing geometry or source validation.
	var revision_reads: int = 0
	var source_reads: int = 0
	var advance_on_source_read: bool = false

	func source_revision(ref: Vector2i) -> int:
		"""An unchanged immutable World needs no repeated source-capacity scan per moving resident."""
		revision_reads += 1
		return super.source_revision(ref)

	func source_refusal(ref: Vector2i) -> StringName:
		"""The first query after actual geometry publication still performs the real source proof."""
		source_reads += 1
		var code: StringName = super.source_refusal(ref)
		if code == &"" and advance_on_source_read:
			advance_on_source_read = false
			var begun: Owner.Result = begin_stage(revision())
			if begun.error != &"":
				return begun.error
			code = seal(begun.token)
			if code != &"":
				abort(begun.token)
				return code
			publish(begun.token)
		return code


var _residents: Residents = null
var _jobs: Jobs = null
var _nodes: Nodes = null
var _world: World = null
var _items: Items = null
var _inventory: Inventory = null
var _buildings: Buildings = null
var _construction: Construction = null
var _sources: Owner.CoreSources = null
var _owner: Owner = null
var _budget: Budget = null
var _terrain: Terrain = null
var _lease: int = 0
var _world_ref: Vector2i = Vector2i(-1, 0)


func before_each() -> void:
	"""Generate real world rows first, then bind an actual World identity and sparse owner."""
	_residents = Residents.new()
	_jobs = Jobs.new(_residents)
	_nodes = Nodes.new(_jobs.directory())
	var forage: Forage = Forage.new(_jobs.directory(), _jobs)
	var fishing: Fishing = Fishing.new(_jobs.directory(), forage, _jobs)
	_world = World.new(_jobs.directory(), _nodes, forage, fishing, Rng.new(), null, null, _jobs)
	_inventory = Inventory.new()
	_items = Items.new()
	assert_true(_items.load_default(_inventory).ok, "actual catalog loads")
	var request: World.RequestResult = World.bound_request(_items)
	assert_true(request.ok, "actual resource catalog-bound request")
	assert_true(_world.generate(request.request).ok, "actual estuary publishes")
	_world_ref = _jobs.directory().create(Directory.KIND_WORLD)
	_buildings = Buildings.new(_jobs.directory())
	_construction = Construction.new(_buildings)
	_sources = Owner.CoreSources.new(_jobs.directory(), _buildings, _construction)
	_owner = Owner.new(_sources)
	assert_equal(_owner.configure(_domain(), 256, 64), &"", "actual sparse owner")
	_budget = Budget.new()
	_terrain = Terrain.new()
	assert_equal(_terrain.configure(_world, _nodes, _owner, _sources, _items, _budget), &"", "actual terrain binding")
	_lease = _budget.acquire(Budget.COLD_BYTES)
	assert_true(_lease > 0, "one shared bounded cold operation per fixture")


func after_each() -> void:
	"""Release actual stores and weak terrain bindings; no engine-owned fixture survives."""
	if _lease != 0:
		assert_equal(_budget.release(_lease), &"", "test-local output references have expired")
	_lease = 0
	_terrain = null
	_owner = null
	_sources = null
	_construction = null
	_buildings = null
	_world = null
	_nodes = null
	_jobs = null
	_residents = null
	_items = null
	_inventory = null
	_budget = null


func _domain(datum: Vector3i = Vector3i(0, 512, 0), minimum: Vector3i = Vector3i(0, -32, 0),
		size: Vector3i = Vector3i(256, 48, 256)) -> Space.Domain:
	"""Independent authored pack values pin the finite datum without deriving them from Terrain."""
	var domain: Space.Domain = Space.Domain.new()
	assert_equal(domain.configure(_world_ref, datum, minimum, size, 8192, 8192, 1048576), &"", "finite test domain")
	return domain


func _box(tile: int = CLEAR_TILE, low_y: int = -1536, high_y: int = 512) -> PackedInt32Array:
	"""Build one exact2m tile box using the GDD coordinate arithmetic, independently of Terrain."""
	var x: int = (tile % 128) * 2048
	@warning_ignore("integer_division") var z: int = (tile / 128) * 2048
	return PackedInt32Array([x, low_y, z, x + 2048, high_y, z + 2048])


func _survey(bounds: PackedInt32Array, rows: int = 128) -> Space.Volumes:
	"""Inspect small outputs within the fixture's single actual shared lease, held through cleanup."""
	var out: Space.Volumes = Space.Volumes.new()
	assert_true(_budget.covers(_lease, Terrain.survey_bytes(rows)), "fixture's shared cold peak covers output")
	assert_equal(_terrain.survey_into(bounds, rows, out, _lease), &"", "actual clipped survey")
	return out


func _place(key: String, tile: int = CLEAR_TILE, rotation: int = 0) -> Vector2i:
	"""Publish a real unfinished Building through the actual catalog and owner lifecycle."""
	var made: Buildings.OpResult = _buildings.place_building(int(Catalog.BUILDING_DEFINITION[key]), tile, rotation, 31)
	assert_true(made.ok, "actual Building blueprint")
	return made.ref


func _register(ref: Vector2i) -> void:
	"""Register actual current source facts; never invent a numeric revision for survey rows."""
	var begun: Owner.Result = _owner.begin_stage(_owner.revision())
	assert_equal(begun.error, &"", "source transaction")
	assert_equal(_owner.stage_source(begun.token, ref), &"", "actual source read")
	assert_equal(_owner.seal(begun.token), &"", "source seal")
	_owner.publish(begun.token)


func test_binding_requires_actual_generated_resource_and_source_owners() -> void:
	"""Equal Directory or token numbers cannot replace actual collaborator bindings."""
	var fresh: Terrain = Terrain.new()
	assert_equal(fresh.content_revision(), 0, "unbound content unavailable")
	assert_equal(fresh.binding_refusal(), Terrain.REFUSE_BINDING, "unbound refuses")
	var foreign_nodes: Nodes = Nodes.new(_jobs.directory())
	assert_equal(fresh.configure(_world, foreign_nodes, _owner, _sources, _items, _budget), Terrain.REFUSE_BINDING,
		"same Directory but wrong resource object refuses")
	var foreign_sources: Owner.CoreSources = Owner.CoreSources.new(_jobs.directory(), _buildings, _construction)
	assert_equal(fresh.configure(_world, _nodes, _owner, foreign_sources, _items, _budget), Terrain.REFUSE_BINDING,
		"same stores but wrong bound source object refuses")
	assert_equal(_terrain.configure(_world, _nodes, _owner, _sources, _items, _budget), &"TERRAIN_ALREADY_BOUND", "immutable binding")
	assert_true(_terrain.is_bound_budget(_budget), "actual arena")
	assert_false(_terrain.is_bound_budget(Budget.new()), "foreign arena")
	assert_equal(_terrain.content_revision(), 1, "explicit finite content revision")


func test_wrong_datum_and_extended_depth_cannot_invent_terrain() -> void:
	"""The old zero-height demo and a deeper sparse domain do not redefine the authored geology."""
	for domain: Space.Domain in [_domain(Vector3i.ZERO), _domain(Vector3i(0, 512, 0), Vector3i(0, -33, 0))]:
		var owner: Owner = Owner.new(_sources)
		assert_equal(owner.configure(domain, 8, 4), &"", "valid generic space differs from terrain pack")
		var terrain: Terrain = Terrain.new()
		assert_equal(terrain.configure(_world, _nodes, owner, _sources, _items, _budget), &"TERRAIN_DOMAIN_CONTENT",
			"actual pack refuses datum/depth mismatch")


func test_dry_clipped_survey_has_exact_source_and_no_map_wide_protected_support() -> void:
	"""Half-open clipped rows preserve true512u floor and do not block every future entrance."""
	var bounds: PackedInt32Array = _box(CLEAR_TILE, -700, 2000)
	bounds[0] += 117
	bounds[3] -= 91
	bounds[2] += 83
	var out: Space.Volumes = _survey(bounds)
	assert_equal(out.role, PackedInt32Array([Space.DRY_SOLID, Space.FLOOR_DATUM, Space.SUPPORTED_VOID]), "exact natural roles")
	assert_equal(out.lo_y, PackedInt32Array([-700, 512, 512]), "actual clipped lower heights")
	assert_equal(out.hi_y, PackedInt32Array([512, 513, 2000]), "actual clipped upper heights")
	for row: int in out.role.size():
		assert_equal(out.ref_at(row), _world_ref, "actual World generation")
		assert_equal(out.owner_revision[row], _owner.source_revision(_world_ref), "actual owner revision")
		assert_equal(out.lo_x[row], bounds[0], "left clip exact")
		assert_equal(out.hi_x[row], bounds[3], "right clip exact")
		assert_equal(out.lo_z[row], bounds[2], "front clip exact")
	assert_equal(out.role.count(Space.SUPPORT), 0, "natural ground is not blanket protected footing")
	assert_equal(_terrain.dig_refusal(_box()), &"", "first surface cut can be considered")
	assert_equal(_terrain.natural_support_refusal(_box(CLEAR_TILE, 256, 512)), &"", "real original dry footing")
	assert_equal(_terrain.natural_support_refusal(_box(CLEAR_TILE, 512, 768)), Terrain.REFUSE_DRY, "air is not ground support")


func test_exact_dry_water_boundary_and_real_ford_height() -> void:
	"""Cross-tile coverage sees a water strip; the ford remains−128u rather than LAND or water zero."""
	var river: int = 60 * 128 + 76
	assert_equal(_terrain.dig_refusal(_box(river, -1536, -512)), Terrain.REFUSE_WATER, "river column protected")
	assert_equal(_terrain.last_conflict_ref(), _world_ref, "water owns actual World ref")
	assert_equal(_terrain.last_conflict_tile(), river, "actual water tile")
	var crossing: PackedInt32Array = _box(river - 1, -20000, -18000)
	crossing[3] += 1
	assert_equal(_terrain.dig_refusal(crossing), Terrain.REFUSE_WATER, "one unit across river boundary refuses")
	crossing[3] -= 1
	assert_equal(_terrain.dig_refusal(crossing), &"", "touching exact boundary is legal dry substrate")
	var ford: int = 49 * 128 + 77
	var out: Space.Volumes = _survey(_box(ford, -1024, 1024))
	assert_equal(out.role, PackedInt32Array([Space.DRY_SOLID, Space.FLOOR_DATUM, Space.WATER, Space.SUPPORTED_VOID]), "ford roles")
	assert_equal(out.lo_y, PackedInt32Array([-1024, -128, -128, 0]), "actual ford and water datums")
	assert_equal(_terrain.natural_support_refusal(_box(ford, -384, -128)), &"", "ford substrate")
	assert_equal(_terrain.exterior_refusal(_box(ford, -128, 768)), Terrain.REFUSE_WATER, "terrain alone grants no wading permission")


func test_every_water_mask_has_finite_excavation_protection_without_fake_floor() -> void:
	"""Coast, lake and non-ford river use their actual generated masks and no invented seabed route."""
	for tile: int in [5 * 128 + 20, 66 * 128 + 100, 60 * 128 + 77]:
		var out: Space.Volumes = _survey(_box(tile, -32256, 512))
		assert_equal(out.role, PackedInt32Array([Space.WATER]), "only protected wet column")
		assert_equal(out.lo_y[0], -32256, "finite bottom")
		assert_equal(out.hi_y[0], 0, "actual water surface")
		assert_equal(_terrain.dig_refusal(_box(tile, -32257, -32000)), Terrain.REFUSE_BOUNDS, "below authored extent refuses")


func test_tree_stump_regrowth_and_retirement_are_seen_without_sparse_revision_changes() -> void:
	"""Fresh real resource reads prevent cached terrain from ignoring newly planted or regrown trees."""
	var revision: int = _owner.revision()
	var tree: Nodes.OpResult = _nodes.create_at_tile(CLEAR_TILE, _items.compiled_id(&"wood"), 1000, 4, 1)
	assert_true(tree.ok, "actual new renewable resource")
	assert_equal(_terrain.dig_refusal(_box(CLEAR_TILE, -512, 512)), Terrain.REFUSE_RESOURCE, "roots protected")
	assert_equal(_terrain.last_conflict_ref(), tree.ref, "actual node full ref in feedback")
	assert_equal(_terrain.exterior_refusal(_box(CLEAR_TILE, 1024, 2048)), Terrain.REFUSE_RESOURCE, "live tree upper extent")
	assert_true(_nodes.harvest_all(tree.value, 2).ok, "actual harvest leaves stump")
	assert_equal(_terrain.exterior_refusal(_box(CLEAR_TILE, 1024, 2048)), &"", "upper tree absent after harvest")
	assert_equal(_terrain.dig_refusal(_box(CLEAR_TILE, -512, 512)), Terrain.REFUSE_RESOURCE, "renewable roots remain")
	assert_true(_nodes.regrow(tree.value, 6).ok, "actual dated regrowth")
	assert_equal(_terrain.exterior_refusal(_box(CLEAR_TILE, 1024, 2048)), Terrain.REFUSE_RESOURCE, "regrown tree immediately seen")
	assert_equal(_owner.revision(), revision, "no sparse revision was fabricated")
	assert_true(_nodes.destroy(tree.ref).ok, "actual resource owner removes node")
	assert_equal(_terrain.dig_refusal(_box(CLEAR_TILE, -512, 512)), &"", "actual retirement releases resource exclusion")
	assert_equal(_terrain.last_conflict_ref(), Directory.NULL_REF, "success clears old feedback")


func test_exhausted_nonrenewable_deposit_does_not_keep_a_phantom_resource() -> void:
	"""Actual stock is exhausted through the resource owner; Terrain never changes yield."""
	for key: StringName in [&"stone", &"iron"]:
		var deposit: Nodes.OpResult = _nodes.create_at_tile(CLEAR_TILE, _items.compiled_id(key), 1200, 0, 1)
		assert_true(deposit.ok, "actual finite deposit")
		assert_equal(_terrain.dig_refusal(_box(CLEAR_TILE, -3584, -1536)), Terrain.REFUSE_RESOURCE, "deep deposit protected")
		assert_true(_nodes.harvest_all(deposit.value, 2).ok, "only actual harvest consumes stock")
		assert_equal(_terrain.dig_refusal(_box(CLEAR_TILE, -3584, -1536)), &"", "no exhausted resource phantom")
		assert_equal(_nodes.quantity_milli_of(deposit.value).value, 0, "survey and query never create ore")
		assert_true(_nodes.destroy(deposit.ref).ok, "free tile between real deposits")


func test_unknown_resource_item_refuses_instead_of_guessing_tree_or_stone() -> void:
	"""The owner accepts stored IDs, but terrain qualification requires the bound authored item keys."""
	var node: Nodes.OpResult = _nodes.create_at_tile(CLEAR_TILE, _items.compiled_id(&"cloth"), 1000, 0, 1)
	assert_true(node.ok, "actual owner has an unauthored resource kind")
	assert_equal(_terrain.dig_refusal(_box()), &"TERRAIN_RESOURCE_CATALOG", "no guessed geometry")
	var out: Space.Volumes = Space.Volumes.new()
	var token: int = _lease
	assert_equal(_terrain.survey_into(_box(), 16, out, token), &"TERRAIN_RESOURCE_CATALOG", "cold query also refuses")
	assert_equal(out.role.size(), 0, "no partial natural row leaks from refused query")


func test_real_rotated_unfinished_building_protects_foundation_and_body() -> void:
	"""Actual footprint maps include rotated non-square blueprints before any completed mesh exists."""
	var hall: Vector2i = _place("hall", CLEAR_TILE, 1)
	var inside: int = CLEAR_TILE + 11 * 128 + 9
	var outside: int = CLEAR_TILE + 12 * 128 + 9
	assert_equal(_terrain.dig_refusal(_box(inside, -512, 512)), Terrain.REFUSE_FOUNDATION, "rotated far foundation cell")
	assert_equal(_terrain.last_conflict_ref(), hall, "full actual blueprint owner")
	assert_equal(_terrain.dig_refusal(_box(outside, -20000, -18000)), &"", "outside rotated footprint")
	assert_equal(_terrain.exterior_refusal(_box(CLEAR_TILE, 512, 2048)), Terrain.REFUSE_BODY, "unknown upper body remains protected")
	assert_equal(_terrain.dig_refusal(_box(inside, -1536, -512)), &"", "foundation is finite, exact touching is not penetration")
	_register(hall)
	var out: Space.Volumes = _survey(_box(CLEAR_TILE, -512, 2048))
	assert_equal(out.role.count(Space.SUPPORT), 1, "protected structural foundation")
	assert_equal(out.role.count(Space.PROTECTED_ACCESS), 1, "upper site exclusion, not opaque mesh claim")
	var row: int = out.role.find(Space.SUPPORT)
	assert_equal(out.ref_at(row), hall, "actual Building source")
	assert_equal(out.owner_revision[row], _owner.source_revision(hall), "real current source revision")


func test_open_stockpile_and_paths_do_not_invent_filled_upper_obstacles() -> void:
	"""Goods and route contacts remain actual companion-owned facts, not maximum visual-height cubes."""
	for key: String in ["open_stockpile", "dirt_path", "paved_path"]:
		var building: Vector2i = _place(key)
		assert_equal(_terrain.exterior_refusal(_box(CLEAR_TILE, 512, 2048)), &"", "no opaque empty upper volume")
		assert_equal(_terrain.dig_refusal(_box(CLEAR_TILE, -512, 512)), Terrain.REFUSE_FOUNDATION, "real foundation reservation")
		assert_true(_buildings.demolish_building(building).ok, "actual empty Building retirement")


func test_cold_building_rows_require_registered_current_nonzero_revision() -> void:
	"""A numeric1 cannot stand in for a missing or source-drifted Building registration."""
	var building: Vector2i = _place("well")
	var out: Space.Volumes = Space.Volumes.new()
	var token: int = _lease
	assert_equal(_terrain.survey_into(_box(), 16, out, token), &"SPACE_SOURCE_NOT_REGISTERED", "no guessed source")
	assert_equal(out.role.size(), 0, "entire output cleared")
	_register(building)
	out = _survey(_box())
	assert_equal(out.role.count(Space.SUPPORT), 1, "actual well foundation now represented")
	assert_true(_buildings.set_building_interior_id(building, 5).ok, "actual identity fact changes")
	token = _lease
	assert_equal(_terrain.survey_into(_box(), 16, out, token), &"SPACE_SOURCE_DRIFT", "old source facts refuse")
	assert_equal(out.role.size(), 0, "earlier successful output erased")
	_register(building)
	out = _survey(_box())
	assert_equal(_owner.source_revision(building), 2, "real owner advanced revision")
	assert_equal(out.owner_revision[out.role.find(Space.SUPPORT)], 2, "current revision, not hardcoded1")


func test_capacity_lease_and_off_domain_refusals_clear_every_output_column() -> void:
	"""Failed cold output cannot leave an earlier success or a usable prefix, and never spends a lease."""
	var out: Space.Volumes = _survey(_box(CLEAR_TILE, -512, 2048))
	var token: int = _lease
	assert_equal(_terrain.survey_into(_box(CLEAR_TILE, -512, 2048), 1, out, token), Terrain.REFUSE_CAPACITY, "count pass refuses before append")
	assert_equal(out.lo_x.size() + out.hi_y.size() + out.owner_revision.size() + out.role.size(), 0, "output cleared")
	assert_true(_budget.covers(token, Terrain.survey_bytes(1)), "caller still owns its lease")
	assert_equal(_budget.release(token), &"", "empty failed output releases the test lease")
	_lease = 0
	assert_equal(_terrain.survey_into(_box(), 1, out, token), &"TERRAIN_COLD_LEASE", "released token refuses")
	assert_equal(_terrain.dig_refusal(_box(CLEAR_TILE, -32257, -30000)), Terrain.REFUSE_BOUNDS, "finite bottom")
	assert_equal(_terrain.exterior_refusal(_box(CLEAR_TILE, 16896, 16897)), Terrain.REFUSE_BOUNDS, "finite top")
	var broad: PackedInt32Array = PackedInt32Array([0, -20000, 0, 18432, -18000, 18432])
	assert_equal(_terrain.dig_refusal(broad), &"TERRAIN_LOCAL_CAPACITY", "hot query bound is explicit")
	assert_equal(Terrain.survey_bytes(0), 0, "no empty allocation permission")
	assert_equal(Terrain.survey_bytes(16385), 0, "no over-ceiling allocation permission")
	assert_equal(_terrain.survey_into(_box(), 1, null, 0), &"TERRAIN_SURVEY_OUTPUT", "null output refuses")


func test_published_world_reset_full_ref_retirement_and_unknown_terrain_refuse() -> void:
	"""World lifetime is checked by the real owner, not cached seed or stale survey rows."""
	var original: int = _world._terrain[CLEAR_TILE]
	_world._terrain[CLEAR_TILE] = 255
	assert_equal(_terrain.dig_refusal(_box()), &"TERRAIN_WORLD_KIND", "unknown actual terrain refuses")
	_world._terrain[CLEAR_TILE] = original
	assert_true(_jobs.directory().destroy(_world_ref), "actual World identity retired")
	assert_true(_terrain.binding_refusal() != &"", "retired World refuses")
	_world.clear()
	assert_equal(_terrain.binding_refusal(), Terrain.REFUSE_BINDING, "unpublished World refuses")


func test_world_and_resource_into_readers_erase_stale_facts_and_preserve_generations() -> void:
	"""New local reader seams use the existing real owner lifecycle, not bare numeric slots."""
	var number: IntMath.IntResult = IntMath.IntResult.new()
	assert_true(_world.resource_nodes() == _nodes, "exact generation owner")
	assert_true(_world.terrain_into(CLEAR_TILE, number), "actual terrain read")
	assert_equal(number.value, World.TERRAIN_LAND, "real land")
	assert_false(_world.terrain_into(-1, number), "invalid tile refuses")
	assert_equal(number.value, 0, "old terrain result erased")
	assert_false(_world.terrain_into(CLEAR_TILE, null), "null scratch refuses")
	var node: Nodes.OpResult = _nodes.create_at_tile(CLEAR_TILE, _items.compiled_id(&"wood"), 2000, 4, 1)
	assert_true(node.ok, "actual resource")
	var facts: PackedInt64Array = PackedInt64Array([9, 9, 9, 9])
	assert_equal(_nodes.spatial_facts_into(node.ref, facts), &"", "full actual identity")
	assert_equal(facts, PackedInt64Array([CLEAR_TILE, _items.compiled_id(&"wood"), 2000, 4]), "exact facts")
	assert_true(_nodes.destroy(node.ref).ok, "actual row retires")
	var replacement: Nodes.OpResult = _nodes.create_at_tile(CLEAR_TILE, _items.compiled_id(&"stone"), 700, 0, 1)
	assert_true(replacement.ok, "actual row reused")
	assert_true(replacement.ref != node.ref, "full generation differs")
	assert_equal(_nodes.spatial_facts_into(node.ref, facts), Nodes.REFUSE_NOT_PRESENT, "old full ref cannot read replacement")
	assert_equal(facts, PackedInt64Array([0, 0, 0, 0]), "all old resource facts erased")
	facts.resize(3)
	facts.fill(6)
	assert_equal(_nodes.spatial_facts_into(replacement.ref, facts), &"RESOURCE_SPATIAL_FACTS_SHAPE", "wrong output size refuses")
	assert_equal(facts, PackedInt64Array([0, 0, 0]), "no resize and no stale prefix")


func test_surveys_do_not_mutate_or_refill_retained_paid_space() -> void:
	"""A base observation is not publication; sparse paid geometry must be composed by its owner."""
	var begun: Owner.Result = _owner.begin_stage(_owner.revision())
	var piece: Owner.Region = Owner.Region.new()
	piece.box = _box(CLEAR_TILE, -1536, -512)
	piece.role = Space.SUPPORTED_VOID
	piece.level = 1
	piece.owner = _world_ref
	assert_equal(_owner.stage_add(begun.token, piece).error, &"", "explicit fixture retained finished geometry")
	assert_equal(_owner.seal(begun.token), &"", "actual sparse owner validates")
	_owner.publish(begun.token)
	var before: PackedByteArray = _owner.state_bytes()
	var out: Space.Volumes = _survey(_box())
	assert_equal(out.role, PackedInt32Array([Space.DRY_SOLID]), "base geology remains separately identified")
	assert_equal(_owner.state_bytes(), before, "Terrain never publishes soil over actual retained void")
	assert_equal(_terrain.dig_refusal(_box()), &"", "base-only query does not claim paid-ledger permission")
	assert_equal(_owner.state_bytes(), before, "local query cannot mutate paid owner either")


func test_natural_observation_is_separate_from_live_exclusion_and_sparse_source_registration() -> void:
	"""Original substrate is readable without pretending an unregistered foundation or resource is absent."""
	var building: Vector2i = _place("kitchen")
	var out: Space.Volumes = Space.Volumes.new()
	assert_equal(_terrain.natural_survey_into(_box(), 16, out, _lease), &"", "read original substrate only")
	assert_equal(out.role, PackedInt32Array([Space.DRY_SOLID]), "no guessed Building source or obstacle facts")
	assert_equal(out.ref_at(0), _world_ref, "actual World owns only the original substrate")
	assert_equal(_owner.source_revision(building), 0, "observation does not register or mutate sources")
	assert_equal(_terrain.dig_refusal(_box()), Terrain.REFUSE_FOUNDATION, "fresh actual foundation still refuses excavation")
	assert_equal(_terrain.survey_into(_box(), 16, out, _lease), &"SPACE_SOURCE_NOT_REGISTERED", "full survey still requires real source")
	assert_equal(out.role.size(), 0, "full refusal clears prior natural output")
	var foreign: Owner.CoreSources = Owner.CoreSources.new(_jobs.directory(), _buildings, _construction)
	assert_true(_terrain.is_bound_world(_world, _owner, _sources), "actual owners attest")
	assert_false(_terrain.is_bound_world(_world, _owner, foreign), "equal Directory and stores are not equal source owner")
	assert_false(_terrain.is_bound_world(null, _owner, _sources), "absent World cannot borrow observations")


func test_natural_survey_preserves_clipping_capacity_and_exact_budget_contract() -> void:
	"""The base-only path cannot bypass the full survey's bounds, pre-count or actual lease lifetime."""
	var out: Space.Volumes = Space.Volumes.new()
	var box: PackedInt32Array = _box(CLEAR_TILE, -1, 514)
	box[0] += 7
	box[5] -= 9
	assert_equal(_terrain.natural_survey_into(box, 3, out, _lease), &"", "three exact natural roles")
	assert_equal(out.role, PackedInt32Array([Space.DRY_SOLID, Space.FLOOR_DATUM, Space.SUPPORTED_VOID]), "stable base-role order")
	for row: int in out.role.size():
		assert_equal(out.lo_x[row], box[0], "exact cropped left edge")
		assert_equal(out.hi_z[row], box[5], "exact cropped back edge")
	assert_equal(_terrain.natural_survey_into(box, 2, out, _lease), Terrain.REFUSE_CAPACITY, "count pass refuses before partial append")
	assert_equal(out.role.size() + out.owner_revision.size(), 0, "no stale output remains")
	assert_equal(_terrain.natural_survey_into(box, 3, out, _lease + 1), &"TERRAIN_COLD_LEASE", "foreign numeric lease refuses")


func test_mixed_height_exclusions_do_not_imply_empty_space_or_support() -> void:
	"""A landing crossing the surface can inspect protections without treating untouched soil as dug air."""
	var bounds: PackedInt32Array = _box(CLEAR_TILE, -256, 2048)
	var before: PackedByteArray = _owner.state_bytes()
	assert_equal(_terrain.exclusions_refusal(bounds), &"", "no protected exclusion at this mixed-height location")
	assert_equal(_terrain.dig_refusal(bounds), Terrain.REFUSE_DRY, "upper air is not excavatable dry soil")
	assert_equal(_terrain.exterior_refusal(bounds), Terrain.REFUSE_EXTERIOR, "lower soil is not exterior free space")
	assert_equal(_terrain.natural_support_refusal(bounds), Terrain.REFUSE_DRY, "mixed interval supplies no footing")
	assert_equal(_owner.state_bytes(), before, "protection observation cannot publish paid void or support")
	assert_equal(_terrain.exclusions_refusal(_box(CLEAR_TILE, -32257, -32000)), Terrain.REFUSE_BOUNDS, "finite depth")
	var broad: PackedInt32Array = PackedInt32Array([0, -256, 0, 18432, 2048, 18432])
	assert_equal(_terrain.exclusions_refusal(broad), &"TERRAIN_LOCAL_CAPACITY", "bounded nearby tile count")


func test_mixed_height_exclusions_keep_exact_water_surface_and_ford_edges() -> void:
	"""Air above water has no wet exclusion, but never becomes a supported traversal permission."""
	for tile: int in [5 * 128 + 20, 66 * 128 + 100, 60 * 128 + 76, 49 * 128 + 77]:
		assert_equal(_terrain.exclusions_refusal(_box(tile, -1, 2048)), Terrain.REFUSE_WATER, "one unit below water refuses")
		assert_equal(_terrain.exclusions_refusal(_box(tile, 0, 2048)), &"", "exact water surface does not overlap air")
		assert_equal(_terrain.natural_support_refusal(_box(tile, 0, 256)), Terrain.REFUSE_WATER \
			if tile != 49 * 128 + 77 else Terrain.REFUSE_DRY, "air above water never supplies natural support")
	var crossing: PackedInt32Array = _box(60 * 128 + 75, -1024, 2048)
	assert_equal(_terrain.exclusions_refusal(crossing), &"", "dry side can be considered by actual paid geometry")
	crossing[3] += 1
	assert_equal(_terrain.exclusions_refusal(crossing), Terrain.REFUSE_WATER, "exact one-unit wet crossing refuses")
	assert_equal(_terrain.exclusions_refusal(_box(49 * 128 + 77, -256, -128)), &"", "ford substrate below water")
	assert_equal(_terrain.exclusions_refusal(_box(49 * 128 + 77, -256, -127)), Terrain.REFUSE_WATER, "one unit above ford bed")


func test_mixed_height_exclusions_read_live_roots_harvest_and_regrowth() -> void:
	"""No graph or immutable World-source cache hides renewable resource changes."""
	var revision: int = _owner.revision()
	var tree: Nodes.OpResult = _nodes.create_at_tile(CLEAR_TILE, _items.compiled_id(&"wood"), 1000, 4, 1)
	assert_true(tree.ok, "actual renewable tree")
	assert_equal(_terrain.exclusions_refusal(_box(CLEAR_TILE, -256, 2048)), Terrain.REFUSE_RESOURCE, "root and upper body protected")
	assert_equal(_terrain.last_conflict_ref(), tree.ref, "full real resource identity")
	assert_true(_nodes.harvest_all(tree.value, 2).ok, "actual stump transition")
	assert_equal(_terrain.exclusions_refusal(_box(CLEAR_TILE, 1024, 2048)), &"", "harvested canopy no longer blocks")
	assert_equal(_terrain.exclusions_refusal(_box(CLEAR_TILE, -256, 1024)), Terrain.REFUSE_RESOURCE, "retained stump and roots still block")
	assert_true(_nodes.regrow(tree.value, 6).ok, "actual regrowth")
	assert_equal(_terrain.exclusions_refusal(_box(CLEAR_TILE, 1024, 2048)), Terrain.REFUSE_RESOURCE, "same geometry revision sees new canopy")
	assert_true(_nodes.destroy(tree.ref).ok, "actual resource removed")
	assert_equal(_terrain.exclusions_refusal(_box(CLEAR_TILE, -256, 2048)), &"", "retired resource no longer blocks")
	assert_equal(_owner.revision(), revision, "resource lifecycle did not change sparse geometry revision")


func test_mixed_height_exclusions_protect_live_unregistered_building_and_exact_faces() -> void:
	"""An unfinished upper building is visible immediately, including its real foundation depth."""
	var kitchen: Vector2i = _place("kitchen")
	assert_equal(_owner.source_revision(kitchen), 0, "not yet a registered sparse source")
	assert_equal(_terrain.exclusions_refusal(_box(CLEAR_TILE, -256, 2048)), Terrain.REFUSE_FOUNDATION, "cross-surface foundation remains protected")
	assert_equal(_terrain.last_conflict_ref(), kitchen, "actual Building full ref")
	assert_equal(_terrain.exclusions_refusal(_box(CLEAR_TILE, 512, 5632)), Terrain.REFUSE_BODY, "exact upper site extent")
	assert_equal(_terrain.exclusions_refusal(_box(CLEAR_TILE, -1536, -512)), &"", "touching underside is not penetration")
	assert_equal(_terrain.exclusions_refusal(_box(CLEAR_TILE, 5632, 6656)), &"", "touching top is not penetration")
	assert_true(_buildings.demolish_building(kitchen).ok, "actual unfinished Building cancellation")
	assert_equal(_terrain.exclusions_refusal(_box(CLEAR_TILE, -256, 2048)), &"", "actual removal releases exclusion")


func _observed_owner() -> ObservedOwner:
	"""Bind the production sparse capacities while retaining all actual source/terrain owners."""
	var observed: ObservedOwner = ObservedOwner.new(_sources)
	assert_equal(observed.configure(_domain(), 6144, 2048), &"", "production sparse capacity")
	_owner = observed
	_terrain = Terrain.new()
	assert_equal(_terrain.configure(_world, _nodes, _owner, _sources, _items, _budget), &"", "actual observed owner binding")
	observed.revision_reads = 0
	observed.source_reads = 0
	return observed


func test_world_source_proof_is_reused_only_until_actual_geometry_publication() -> void:
	"""256 unchanged local reads do not rescan2048 source slots; one real publication refreshes proof."""
	var observed: ObservedOwner = _observed_owner()
	var bounds: PackedInt32Array = _box(CLEAR_TILE, -256, 2048)
	for index: int in 256:
		assert_equal(_terrain.exclusions_refusal(bounds), &"", "unchanged full World source")
	assert_equal(observed.revision_reads, 0, "no repeated source-revision scans")
	assert_equal(observed.source_reads, 0, "no repeated immutable-source scans")
	_register(_world_ref)
	for index: int in 256:
		assert_equal(_terrain.exclusions_refusal(bounds), &"", "actual publication is revalidated")
	assert_equal(observed.revision_reads, 1, "exactly one source-revision scan for new geometry revision")
	assert_equal(observed.source_reads, 1, "exactly one real source proof")
	assert_true(_jobs.directory().destroy(_world_ref), "actual World identity retires")
	var replacement: Vector2i = _jobs.directory().create(Directory.KIND_WORLD)
	assert_true(replacement != _world_ref, "actual generation changed")
	assert_equal(_terrain.exclusions_refusal(bounds), &"TERRAIN_WORLD_SOURCE", "matching cached revision never bypasses full generation")


func test_world_source_proof_never_pins_a_revision_changed_during_its_read() -> void:
	"""A reentrant source read publishing real geometry cannot supply a stale cache certificate."""
	var observed: ObservedOwner = _observed_owner()
	_register(_world_ref)
	observed.advance_on_source_read = true
	assert_equal(_terrain.exclusions_refusal(_box()), &"TERRAIN_WORLD_SOURCE", "publication inside source proof refuses")
	assert_equal(_terrain.exclusions_refusal(_box()), &"", "next independent query validates the actual new revision")
	assert_equal(observed.revision_reads, 2, "refused proof was not cached")
	assert_equal(observed.source_reads, 2, "actual proof reran")


class ObservedBindingTerrain extends Terrain:
	## Public observation hook is deliberately distinct from the final actual local-facts reader.
	var calls: int = 0

	func binding_refusal() -> StringName:
		"""Count the ordinary observer without changing any actual source fact or physical rule."""
		calls += 1
		return super.binding_refusal()


func test_final_local_facts_read_fresh_unregistered_obstacles_without_observation_hook() -> void:
	"""A late new well changes actual exclusion geometry even though the sparse revision is unchanged."""
	var final_reader: ObservedBindingTerrain = ObservedBindingTerrain.new()
	assert_equal(final_reader.configure(_world, _nodes, _owner, _sources, _items, _budget), &"", "exact actual owners")
	var bounds: PackedInt32Array = _box()
	assert_equal(final_reader.dig_refusal(bounds), &"", "ordinary binding and dry-space proof")
	var calls: int = final_reader.calls
	var revision: int = _owner.revision()
	assert_equal(final_reader.local_facts_refusal(bounds, Terrain.DIG, revision), &"", "current leaf facts")
	assert_equal(final_reader.calls, calls, "no public binding callback during final attestation")
	var well: Vector2i = _place("well")
	assert_true(_buildings.is_live_building(well), "actual new obstruction")
	assert_equal(_owner.revision(), revision, "no sparse publication disguised as the trigger")
	assert_equal(final_reader.local_facts_refusal(bounds, Terrain.DIG, revision), Terrain.REFUSE_FOUNDATION, "fresh protected foundation")
	assert_equal(final_reader.calls, calls, "late exclusion check remains callback-free")


func test_final_local_facts_require_current_attested_wiring_and_exact_finite_bounds() -> void:
	"""The leaf reader cannot initialize an unbound provider or accept a foreign/stale geometry image."""
	var bounds: PackedInt32Array = _box()
	var revision: int = _owner.revision()
	assert_equal(Terrain.new().local_facts_refusal(bounds, Terrain.DIG, revision), Terrain.REFUSE_BINDING, "unbound")
	assert_equal(_terrain.local_facts_refusal(bounds, Terrain.DIG, revision + 1), Terrain.REFUSE_BINDING, "wrong geometry")
	assert_equal(_terrain.local_facts_refusal(bounds, 99, revision), Terrain.REFUSE_BOUNDS, "unknown purpose")
	bounds[3] = bounds[0]
	assert_equal(_terrain.local_facts_refusal(bounds, Terrain.DIG, revision), Terrain.REFUSE_BOUNDS, "degenerate target")


func test_prepared_local_facts_require_the_exact_sealed_candidate_and_original_lease() -> void:
	"""The live-only reader stays closed while a narrow prepared reader checks original natural ground."""
	var bounds: PackedInt32Array = _box(CLEAR_TILE, 512, 1536)
	var revision: int = _owner.revision()
	var token: int = _owner.begin_stage(revision).token
	assert_equal(_terrain.prepared_local_facts_refusal(bounds, Terrain.EXTERIOR, revision, token, _lease),
		Terrain.REFUSE_BINDING, "unsealed candidate refuses")
	assert_equal(_owner.seal(token), &"", "actual candidate seals")
	assert_equal(_terrain.local_facts_refusal(bounds, Terrain.EXTERIOR, revision), Terrain.REFUSE_BINDING, "ordinary reader remains live-only")
	assert_equal(_terrain.prepared_local_facts_refusal(bounds, Terrain.EXTERIOR, revision, token, _lease), &"", "exact sealed scope")
	assert_equal(_terrain.prepared_local_facts_refusal(bounds, Terrain.EXTERIOR, revision, token + 1, _lease), Terrain.REFUSE_BINDING, "foreign Space token")
	assert_equal(_terrain.prepared_local_facts_refusal(bounds, Terrain.EXTERIOR, revision, token, _lease + 1), Terrain.REFUSE_BINDING, "foreign cold token")
	assert_equal(_terrain.prepared_local_facts_refusal(bounds, 99, revision, token, _lease), Terrain.REFUSE_BOUNDS, "unknown purpose")
	assert_true(_owner.abort(token), "candidate aborted")
	assert_equal(_terrain.prepared_local_facts_refusal(bounds, Terrain.EXTERIOR, revision, token, _lease), Terrain.REFUSE_BINDING, "expired scope")


func test_prepared_local_facts_see_late_actual_obstacles_without_public_observers() -> void:
	"""A newly placed real Building after sealing prevents the final natural-anchor publication."""
	var reader: ObservedBindingTerrain = ObservedBindingTerrain.new()
	assert_equal(reader.configure(_world, _nodes, _owner, _sources, _items, _budget), &"", "actual reader")
	var bounds: PackedInt32Array = _box(CLEAR_TILE, 512, 1536)
	var revision: int = _owner.revision()
	var calls: int = reader.calls
	var token: int = _owner.begin_stage(revision).token
	assert_equal(_owner.seal(token), &"", "actual sealed scope")
	assert_equal(reader.prepared_local_facts_refusal(bounds, Terrain.EXTERIOR, revision, token, _lease), &"", "clear surface")
	var well: Vector2i = _place("well")
	assert_true(_buildings.is_live_building(well), "actual late Building")
	assert_equal(reader.prepared_local_facts_refusal(bounds, Terrain.EXTERIOR, revision, token, _lease), Terrain.REFUSE_BODY, "live upper obstacle")
	assert_equal(reader.calls, calls, "no public observation callback")
	assert_true(_owner.abort(token), "test candidate discarded")


func test_prepared_local_facts_never_adopt_a_replacement_cold_lease() -> void:
	"""Numerically valid new capacity cannot extend the old operation that its caller still names."""
	var bounds: PackedInt32Array = _box(CLEAR_TILE, 512, 1536)
	var revision: int = _owner.revision()
	var token: int = _owner.begin_stage(revision).token
	assert_equal(_owner.seal(token), &"", "actual sealed scope")
	var old: int = _lease
	assert_equal(_budget.release(old), &"", "original operation expired")
	_lease = _budget.acquire(Budget.COLD_BYTES)
	assert_true(_lease > old, "replacement identity differs")
	assert_equal(_terrain.prepared_local_facts_refusal(bounds, Terrain.EXTERIOR, revision, token, old), Terrain.REFUSE_BINDING, "old exact lease refused")
	assert_true(_budget.covers(_lease, Budget.COLD_BYTES), "foreign replacement was not released")
	assert_true(_owner.abort(token), "test candidate discarded")
