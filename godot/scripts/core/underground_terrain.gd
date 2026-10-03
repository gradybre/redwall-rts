extends RefCounted
## Finite authored estuary base matter and current exclusions. Decision1082.
## No paid geometry, route, support reservation or construction permission is created here.

const World := preload("res://scripts/core/world_init.gd")
const Nodes := preload("res://scripts/core/resource_nodes.gd")
const Items := preload("res://scripts/core/item_definitions.gd")
const ResourceBinding := preload("res://scripts/core/resource_catalog_binding.gd")
const Buildings := preload("res://scripts/core/buildings.gd")
const Definitions := preload("res://scripts/core/building_definitions.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const Space := preload("res://scripts/core/room_space.gd")
const Owner := preload("res://scripts/core/underground_space_owner.gd")
const Budget := preload("res://scripts/core/underground_budget.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const CONTENT_REVISION: int = 1
const DATUM: Vector3i = Vector3i(0, World.LAND_Y_UNITS, 0)
const MIN_QUANTUM: Vector3i = Vector3i(0, -32, 0)
const SIZE_QUANTA: Vector3i = Vector3i(256, 48, 256)
const BOTTOM_U: int = World.LAND_Y_UNITS - 32768
const TOP_U: int = World.LAND_Y_UNITS + 16384
const MAP_WIDTH_U: int = World.MAP_TILES_X * World.TILE_SIZE_UNITS
const LOCAL_TILE_LIMIT: int = 64
const SURVEY_CONTROL_BYTES: int = 256
const DIG: int = 0
const FOOTING: int = 1
const EXTERIOR: int = 2
const NULL_REF: Vector2i = Vector2i(-1, 0)
const REFUSE_BINDING: StringName = &"TERRAIN_OWNER_BINDING"
const REFUSE_BOUNDS: StringName = &"TERRAIN_SURVEY_BOUNDS"
const REFUSE_CAPACITY: StringName = &"TERRAIN_SURVEY_CAPACITY"
const REFUSE_RESOURCE: StringName = &"TERRAIN_RESOURCE_PROTECTED"
const REFUSE_FOUNDATION: StringName = &"TERRAIN_FOUNDATION_PROTECTED"
const REFUSE_BODY: StringName = &"TERRAIN_BUILDING_SITE_PROTECTED"
const REFUSE_WATER: StringName = &"TERRAIN_WATER_PROTECTED"
const REFUSE_DRY: StringName = &"TERRAIN_NOT_NATURAL_DRY_SOLID"
const REFUSE_EXTERIOR: StringName = &"TERRAIN_NOT_OPEN_EXTERIOR"

## Explicit foundation exclusion depth and upper site envelope, by actual catalog key.
## Upper entries follow the maximum-Y brief; they are NOT opaque mesh geometry.
const BUILDING_EXTENTS: Dictionary = {
	"apiary": [512, 2048], "boathouse": [1024, 5120], "brewery": [1024, 5120],
	"cellar": [4096, 2048], "composter": [512, 1280], "covered_store": [1024, 5120],
	"dirt_path": [64, 0], "dryer": [1024, 3072], "fence": [512, 1536],
	"fisher_shelter": [1024, 3584], "forester_lodge": [1024, 4608], "gate": [1024, 3584],
	"hall": [1024, 7168], "infirmary": [1024, 5632], "kitchen": [1024, 5120],
	"lookout": [1024, 8192], "memorial_garden": [512, 2048], "mill": [1024, 7168],
	"nursery": [1024, 3072], "open_stockpile": [512, 0], "paved_path": [128, 0],
	"preserver": [1024, 5120], "quarry_shed": [1024, 4096], "residence": [1024, 6144],
	"saltpan": [512, 512], "stone_wall": [1024, 2560], "weir": [1024, 1536],
	"well": [8192, 3072], "workbench": [1024, 3584], "workshop": [1024, 5120],
}

var _world: World = null
var _nodes: Nodes = null
var _items: Items = null
var _buildings: Buildings = null
var _space: WeakRef = null
var _sources: WeakRef = null
var _budget: Budget = null
var _world_ref: Vector2i = NULL_REF
var _seed: int = 0
var _ready: bool = false
var _count: int = 0
var _limit: int = 0
var _conflict_ref: Vector2i = NULL_REF
var _conflict_tile: int = -1
var _number: IntMath.IntResult = IntMath.IntResult.new()
var _domain_bounds: PackedInt32Array = PackedInt32Array()
var _depth: PackedInt32Array = PackedInt32Array()
var _height: PackedInt32Array = PackedInt32Array()
var _resource_ids: PackedInt32Array = PackedInt32Array()
var _building_facts: PackedInt32Array = PackedInt32Array()
var _resource_facts: PackedInt64Array = PackedInt64Array()
var _tile_box: PackedInt32Array = PackedInt32Array()
var _clip: PackedInt32Array = PackedInt32Array()


func _init() -> void:
	"""Allocate small reusable content/query columns, never a tile-by-depth array."""
	_domain_bounds.resize(6)
	_depth.resize(Definitions.BUILDING_DEFINITION_COUNT)
	_height.resize(Definitions.BUILDING_DEFINITION_COUNT)
	_resource_ids.resize(3)
	_building_facts.resize(4)
	_resource_facts.resize(4)
	_tile_box.resize(6)
	_clip.resize(6)


func configure(world: World, nodes: Nodes, space: Owner, sources: Owner.CoreSources,
		items: Items, budget: Budget) -> StringName:
	"""Bind one actual World and immutable pack; identical numeric refs never prove shared owners."""
	if _ready:
		return &"TERRAIN_ALREADY_BOUND"
	if world == null or nodes == null or space == null or sources == null or items == null \
			or budget == null or not world.is_published() or not items.is_loaded():
		return REFUSE_BINDING
	if world.resource_nodes() != nodes or nodes.directory() != world.directory() \
			or sources.directory() != world.directory() or not space.is_bound_sources(sources) \
			or sources.construction_owner() == null:
		return REFUSE_BINDING
	var domain: Space.Domain = space.domain_copy()
	if domain == null or domain._datum != DATUM or not _pack_contains(domain._bounds):
		return &"TERRAIN_DOMAIN_CONTENT"
	var code: StringName = _compile_content(items)
	if code != &"":
		return code
	_world = world
	_nodes = nodes
	_items = items
	_buildings = sources.construction_owner().buildings()
	_space = weakref(space)
	_sources = weakref(sources)
	_budget = budget
	_world_ref = domain._world
	_domain_bounds = domain._bounds.duplicate()
	_seed = world.section_1_published_seed()
	_ready = true
	return binding_refusal()


func _compile_content(items: Items) -> StringName:
	"""Resolve protected resource and foundation keys through their real catalog domains."""
	var opened: ResourceBinding.OpenResult = ResourceBinding.open(items)
	if not opened.ok or BUILDING_EXTENTS.size() != Catalog.BUILDING_DEFINITION.size():
		return &"TERRAIN_CONTENT_CATALOG"
	var binding: ResourceBinding = opened.boundary as ResourceBinding
	for index: int in 3:
		var key: StringName = [ResourceBinding.TREE_ITEM_KEY, ResourceBinding.STONE_ITEM_KEY,
			ResourceBinding.IRON_ITEM_KEY][index]
		var found: ResourceBinding.KeyLookup = binding.compiled_item_id_of(key)
		if not found.ok:
			return found.code
		_resource_ids[index] = found.id
	for key: String in Catalog.BUILDING_DEFINITION:
		if not BUILDING_EXTENTS.has(key):
			return &"TERRAIN_CONTENT_CATALOG"
		var id: int = int(Catalog.BUILDING_DEFINITION[key])
		_depth[id] = int(BUILDING_EXTENTS[key][0])
		_height[id] = int(BUILDING_EXTENTS[key][1])
	return &""


func binding_refusal() -> StringName:
	"""Recheck actual owner lifetime, published world, seed and full World source generation."""
	if not _ready or _space == null or _sources == null:
		return REFUSE_BINDING
	var space: Owner = _space.get_ref() as Owner
	var sources: Owner.CoreSources = _sources.get_ref() as Owner.CoreSources
	if space == null or sources == null or not space.is_bound_sources(sources) \
			or not _world.is_published() or _world.section_1_published_seed() != _seed \
			or _world.resource_nodes() != _nodes or sources.directory() != _world.directory() \
			or sources.construction_owner() == null or sources.construction_owner().buildings() != _buildings:
		return REFUSE_BINDING
	if space.source_revision(_world_ref) < 1:
		return &"TERRAIN_WORLD_SOURCE"
	return space.source_refusal(_world_ref)


func is_bound_budget(candidate: Budget) -> bool:
	"""Attest the actual shared cold arena; a foreign equal token is not usable."""
	return _ready and candidate != null and candidate == _budget


func is_bound_world(world: World, space: Owner, sources: Owner.CoreSources) -> bool:
	"""Compare actual observation owners; equal references in another composed world grant nothing."""
	return _ready and world != null and world == _world and _space != null and _sources != null \
		and space != null and _space.get_ref() == space and sources != null and _sources.get_ref() == sources


func content_revision() -> int:
	"""Return the immutable terrain pack revision, never the mutable sparse geometry revision."""
	return CONTENT_REVISION if _ready else 0


func last_conflict_ref() -> Vector2i:
	"""Expose the actual protected owner for in-world refusal feedback; no bare slot is returned."""
	return _conflict_ref


func last_conflict_tile() -> int:
	"""Return the exterior tile of the last local conflict, or -1 when there is none."""
	return _conflict_tile


static func survey_bytes(max_rows: int) -> int:
	"""Charge the complete retained caller output before any row append can allocate."""
	return 48 * max_rows + SURVEY_CONTROL_BYTES if max_rows > 0 and max_rows <= Space.MAX_REGIONS else 0


func survey_into(bounds: PackedInt32Array, max_rows: int, out: Space.Volumes, token: int) -> StringName:
	"""Copy clipped current base/exclusion rows under the exact shared lease; every refusal clears."""
	return _survey_into(bounds, max_rows, out, token, true)


func natural_survey_into(bounds: PackedInt32Array, max_rows: int, out: Space.Volumes, token: int) -> StringName:
	"""Read original substrate/floor/exterior only; live exclusions and removed matter remain separate."""
	return _survey_into(bounds, max_rows, out, token, false)


static func natural_survey_checks(bounds: PackedInt32Array) -> int:
	"""Bound two tile walks at eight fixed terrain/role probes per tile, excluding fixed owner lookups."""
	if not Space.valid_box(bounds) or bounds[0] < 0 or bounds[2] < 0 \
			or bounds[3] > MAP_WIDTH_U or bounds[5] > MAP_WIDTH_U:
		return 0
	@warning_ignore("integer_division") var first_x: int = bounds[0] / World.TILE_SIZE_UNITS
	@warning_ignore("integer_division") var last_x: int = (bounds[3] - 1) / World.TILE_SIZE_UNITS
	@warning_ignore("integer_division") var first_z: int = bounds[2] / World.TILE_SIZE_UNITS
	@warning_ignore("integer_division") var last_z: int = (bounds[5] - 1) / World.TILE_SIZE_UNITS
	return 16 * (last_x - first_x + 1) * (last_z - first_z + 1)


func _survey_into(bounds: PackedInt32Array, max_rows: int, out: Space.Volumes, token: int,
		exclusions: bool) -> StringName:
	"""Count before allocating and pin one World source revision across both bounded passes."""
	if out == null:
		return &"TERRAIN_SURVEY_OUTPUT"
	_clear(out)
	_reset_query()
	var code: StringName = _bounds_refusal(bounds)
	if code != &"":
		return code
	if survey_bytes(max_rows) == 0 or not _budget.covers(token, survey_bytes(max_rows)):
		return &"TERRAIN_COLD_LEASE"
	_limit = max_rows
	var revision: int = (_space.get_ref() as Owner).source_revision(_world_ref)
	code = _survey_passes(bounds, out, exclusions, revision)
	if code == &"":
		code = _survey_source_refusal(revision, token, max_rows)
	if code != &"":
		_clear(out)
	return code


func _survey_passes(bounds: PackedInt32Array, out: Space.Volumes, exclusions: bool,
		revision: int) -> StringName:
	"""The count pass and the output pass reuse the same observed World revision for every tile."""
	_count = 0
	var code: StringName = _walk_survey(bounds, null, exclusions, revision)
	if code != &"":
		return code
	var expected: int = _count
	_count = 0
	code = _walk_survey(bounds, out, exclusions, revision)
	if code == &"" and _count != expected:
		code = &"TERRAIN_SOURCE_CHANGED"
	return code


func _survey_source_refusal(revision: int, token: int, rows: int) -> StringName:
	"""Only fixed end-of-survey owner lookups remain; actual lifetime and the original lease must survive."""
	var code: StringName = binding_refusal()
	if code != &"":
		return code
	if not _budget.covers(token, survey_bytes(rows)):
		return &"TERRAIN_COLD_LEASE"
	return &"" if (_space.get_ref() as Owner).source_revision(_world_ref) == revision \
		else &"TERRAIN_SOURCE_CHANGED"


func _walk_survey(bounds: PackedInt32Array, out: Space.Volumes, exclusions: bool,
		revision: int) -> StringName:
	"""Use stable Z/X/role order and bounded local reads; the first pass only counts rows."""
	@warning_ignore("integer_division") var first_x: int = bounds[0] / World.TILE_SIZE_UNITS
	@warning_ignore("integer_division") var last_x: int = (bounds[3] - 1) / World.TILE_SIZE_UNITS
	@warning_ignore("integer_division") var first_z: int = bounds[2] / World.TILE_SIZE_UNITS
	@warning_ignore("integer_division") var last_z: int = (bounds[5] - 1) / World.TILE_SIZE_UNITS
	for z: int in range(first_z, last_z + 1):
		for x: int in range(first_x, last_x + 1):
			var code: StringName = _survey_tile(z * World.MAP_TILES_X + x, bounds, out, exclusions, revision)
			if code != &"":
				return code
	return &""


func _survey_tile(tile: int, bounds: PackedInt32Array, out: Space.Volumes, exclusions: bool,
		revision: int) -> StringName:
	"""Read this tile's actual terrain/resources/building, keeping dynamic overlays distinct."""
	_set_tile_box(tile)
	if not _world.terrain_into(tile, _number):
		return StringName(_number.error)
	if _number.value < 0 or _number.value >= World.TERRAIN_COUNT:
		return &"TERRAIN_WORLD_KIND"
	var code: StringName = _base_rows(tile, _number.value, bounds, out, revision)
	if code == &"" and exclusions:
		code = _resource_rows(tile, bounds, out, revision)
	if code == &"" and exclusions:
		code = _building_rows(tile, bounds, out)
	return code


func _base_rows(tile: int, terrain: int, bounds: PackedInt32Array, out: Space.Volumes,
		revision: int) -> StringName:
	"""Natural floor metadata never becomes map-wide protected support or paid underground void."""
	var floor_y: int = _natural_floor(tile, terrain)
	if floor_y == BOTTOM_U:
		return _emit(BOTTOM_U, World.WATER_SURFACE_Y_UNITS, Space.WATER, _world_ref, revision, bounds, out)
	var code: StringName = _emit(BOTTOM_U, floor_y, Space.DRY_SOLID, _world_ref, revision, bounds, out)
	if code == &"":
		code = _emit(floor_y, floor_y + 1, Space.FLOOR_DATUM, _world_ref, revision, bounds, out)
	if code == &"" and floor_y < World.WATER_SURFACE_Y_UNITS:
		code = _emit(floor_y, World.WATER_SURFACE_Y_UNITS, Space.WATER, _world_ref, revision, bounds, out)
	if code == &"":
		code = _emit(maxi(floor_y, World.WATER_SURFACE_Y_UNITS), TOP_U,
			Space.SUPPORTED_VOID, _world_ref, revision, bounds, out)
	return code


func _resource_rows(tile: int, bounds: PackedInt32Array, out: Space.Volumes,
		revision: int) -> StringName:
	"""Resources stay World-owned live exclusions, validated against actual full node references."""
	var ref: Vector2i = _nodes.ref_at_tile(tile)
	if ref == NULL_REF and not _nodes.has_node_at_tile(tile):
		return &""
	var code: StringName = _resource_extent(ref, tile)
	if code != &"" or _tile_box[1] == _tile_box[4]:
		return code
	return _emit(_tile_box[1], _tile_box[4], Space.RESOURCE, _world_ref, revision, bounds, out)


func _resource_extent(ref: Vector2i, tile: int) -> StringName:
	"""Read actual current stock and regrowth, never guess a catalog id or make ore from cutting."""
	var code: StringName = _nodes.spatial_facts_into(ref, _resource_facts)
	if code != &"":
		return code
	if _resource_facts[0] != tile:
		return &"TERRAIN_RESOURCE_TILE"
	var kind: int = _resource_ids.find(int(_resource_facts[1]))
	if kind < 0 or _resource_facts[2] < 0 or _resource_facts[3] < 0:
		return &"TERRAIN_RESOURCE_CATALOG"
	_tile_box[1] = World.LAND_Y_UNITS
	_tile_box[4] = World.LAND_Y_UNITS
	if _resource_facts[2] == 0 and _resource_facts[3] == 0:
		return &""
	_tile_box[1] -= 1024 if kind == 0 else 4096
	_tile_box[4] += (8192 if _resource_facts[2] > 0 else 256) if kind == 0 else 1024
	return &""


func _building_rows(tile: int, bounds: PackedInt32Array, out: Space.Volumes) -> StringName:
	"""Real rotated footprint maps supply identity; missing source revisions never default to one."""
	var ref: Vector2i = _buildings.building_at_tile(tile)
	if ref == NULL_REF:
		return &""
	var code: StringName = _building_extent(ref, tile)
	if code != &"":
		return code
	if not _vertical_overlap(bounds, _tile_box[1], _tile_box[4]):
		return &""
	var owner: Owner = _space.get_ref() as Owner
	code = owner.source_refusal(ref)
	if code != &"" or owner.source_revision(ref) < 1:
		return code if code != &"" else &"TERRAIN_BUILDING_SOURCE"
	var revision: int = owner.source_revision(ref)
	code = _emit(_tile_box[1], World.LAND_Y_UNITS, Space.SUPPORT, ref, revision, bounds, out)
	if code == &"":
		code = _emit(World.LAND_Y_UNITS, _tile_box[4], Space.PROTECTED_ACCESS, ref, revision, bounds, out)
	return code


func _building_extent(ref: Vector2i, tile: int) -> StringName:
	"""Re-read actual type/origin/rotation/state and verify the tile lies in its rotated footprint."""
	var code: StringName = _buildings.spatial_identity_into(ref, _building_facts)
	if code != &"":
		return code
	var type_id: int = _building_facts[0]
	var definitions: Definitions = _buildings.definitions()
	if not definitions.is_building_id(type_id) or not World.is_tile_index(_building_facts[1]) \
			or _building_facts[2] < 0 or _building_facts[2] > 3 or _building_facts[3] < 0 \
			or _building_facts[3] >= Buildings.STATE_COUNT:
		return &"TERRAIN_BUILDING_CONTENT"
	var width: int = definitions.footprint_x_of(type_id)
	var depth: int = definitions.footprint_z_of(type_id)
	if _building_facts[2] % 2 != 0:
		var original: int = width
		width = depth
		depth = original
	var origin: int = _building_facts[1]
	@warning_ignore("integer_division") var dz: int = tile / World.MAP_TILES_X - origin / World.MAP_TILES_X
	var dx: int = tile % World.MAP_TILES_X - origin % World.MAP_TILES_X
	if dx < 0 or dz < 0 or dx >= width or dz >= depth:
		return &"TERRAIN_BUILDING_FOOTPRINT"
	_tile_box[1] = World.LAND_Y_UNITS - _depth[type_id]
	_tile_box[4] = World.LAND_Y_UNITS + _height[type_id]
	return &""


func _emit(low_y: int, high_y: int, role: int, ref: Vector2i, revision: int,
		bounds: PackedInt32Array, out: Space.Volumes) -> StringName:
	"""Append an exactly clipped half-open row or count it without allocation in pass one."""
	if not _vertical_overlap(bounds, low_y, high_y):
		return &""
	_clip[0] = maxi(_tile_box[0], bounds[0])
	_clip[1] = maxi(low_y, bounds[1])
	_clip[2] = maxi(_tile_box[2], bounds[2])
	_clip[3] = mini(_tile_box[3], bounds[3])
	_clip[4] = mini(high_y, bounds[4])
	_clip[5] = mini(_tile_box[5], bounds[5])
	_count += 1
	if _count > _limit:
		return REFUSE_CAPACITY
	if out != null and not out.append(_clip, role, 0, ref, revision):
		return REFUSE_CAPACITY
	return &""


func dig_refusal(bounds: PackedInt32Array) -> StringName:
	"""Check current base dryness and exclusions only; the paid ledger/profile must also qualify."""
	return _local_refusal(bounds, DIG)


func natural_support_refusal(bounds: PackedInt32Array) -> StringName:
	"""Check original natural footing; the composer must additionally exclude all removed matter."""
	return _local_refusal(bounds, FOOTING)


func exterior_refusal(bounds: PackedInt32Array) -> StringName:
	"""Check finite exterior air and live exclusions, without granting a floor, profile or route."""
	return _local_refusal(bounds, EXTERIOR)


func _local_refusal(bounds: PackedInt32Array, purpose: int) -> StringName:
	"""Read at most64 nearby tiles using preallocated facts/boxes, never a full World snapshot."""
	_reset_query()
	var code: StringName = _bounds_refusal(bounds)
	if code != &"":
		return code
	@warning_ignore("integer_division") var first_x: int = bounds[0] / World.TILE_SIZE_UNITS
	@warning_ignore("integer_division") var last_x: int = (bounds[3] - 1) / World.TILE_SIZE_UNITS
	@warning_ignore("integer_division") var first_z: int = bounds[2] / World.TILE_SIZE_UNITS
	@warning_ignore("integer_division") var last_z: int = (bounds[5] - 1) / World.TILE_SIZE_UNITS
	if (last_x - first_x + 1) * (last_z - first_z + 1) > LOCAL_TILE_LIMIT:
		return &"TERRAIN_LOCAL_CAPACITY"
	for z: int in range(first_z, last_z + 1):
		for x: int in range(first_x, last_x + 1):
			code = _local_tile(z * World.MAP_TILES_X + x, bounds, purpose)
			if code != &"":
				return code
	return &""


func _local_tile(tile: int, bounds: PackedInt32Array, purpose: int) -> StringName:
	"""Reject exact nearby protected geometry before any caller earns productive work."""
	_set_tile_box(tile)
	if not _world.terrain_into(tile, _number):
		return StringName(_number.error)
	if _number.value < 0 or _number.value >= World.TERRAIN_COUNT:
		return &"TERRAIN_WORLD_KIND"
	var floor_y: int = _natural_floor(tile, _number.value)
	if floor_y == BOTTOM_U or (floor_y < 0 and bounds[1] < 0 and bounds[4] > floor_y):
		return _conflict(REFUSE_WATER, _world_ref, tile)
	if purpose != EXTERIOR and bounds[4] > floor_y:
		return _conflict(REFUSE_DRY, _world_ref, tile)
	if purpose == EXTERIOR and bounds[1] < maxi(floor_y, 0):
		return _conflict(REFUSE_EXTERIOR, _world_ref, tile)
	if purpose == FOOTING:
		return &""
	var code: StringName = _local_resource(tile, bounds)
	return _local_building(tile, bounds, purpose) if code == &"" else code


func _local_resource(tile: int, bounds: PackedInt32Array) -> StringName:
	"""Stock/identity changes are visible immediately, even with an unchanged sparse revision."""
	var ref: Vector2i = _nodes.ref_at_tile(tile)
	if ref == NULL_REF and not _nodes.has_node_at_tile(tile):
		return &""
	var code: StringName = _resource_extent(ref, tile)
	if code != &"":
		return _conflict(code, ref, tile)
	return _conflict(REFUSE_RESOURCE, ref, tile) \
		if _vertical_overlap(bounds, _tile_box[1], _tile_box[4]) else &""


func _local_building(tile: int, bounds: PackedInt32Array, purpose: int) -> StringName:
	"""Retained/unfinished Building footprints protect real foundations and unresolved upper sites."""
	var ref: Vector2i = _buildings.building_at_tile(tile)
	if ref == NULL_REF:
		return &""
	var code: StringName = _building_extent(ref, tile)
	if code != &"":
		return _conflict(code, ref, tile)
	if _vertical_overlap(bounds, _tile_box[1], World.LAND_Y_UNITS):
		return _conflict(REFUSE_FOUNDATION, ref, tile)
	if purpose == EXTERIOR and _vertical_overlap(bounds, World.LAND_Y_UNITS, _tile_box[4]):
		return _conflict(REFUSE_BODY, ref, tile)
	return &""


func _bounds_refusal(bounds: PackedInt32Array) -> StringName:
	"""Reject unknown space before reading tiles or narrowing coordinates."""
	var code: StringName = binding_refusal()
	if code != &"":
		return code
	return &"" if Space.valid_box(bounds) and Space.contains_box(_domain_bounds, bounds) else REFUSE_BOUNDS


static func _pack_contains(bounds: PackedInt32Array) -> bool:
	"""Finite authored geology cannot be extended by configuring a larger sparse domain."""
	return Space.valid_box(bounds) and bounds[0] >= 0 and bounds[2] >= 0 \
		and bounds[1] >= BOTTOM_U and bounds[3] <= MAP_WIDTH_U \
		and bounds[5] <= MAP_WIDTH_U and bounds[4] <= TOP_U


static func _natural_floor(tile: int, terrain: int) -> int:
	"""Use actual estuary masks; BOTTOM_U denotes a water-protected column with no authored ground."""
	if terrain == World.TERRAIN_LAND:
		return World.LAND_Y_UNITS
	@warning_ignore("integer_division") var z: int = tile / World.MAP_TILES_X
	if terrain == World.TERRAIN_RIVER and z >= World.FORD_FIRST_Z and z <= World.FORD_LAST_Z:
		return World.FORD_Y_UNITS
	return BOTTOM_U


func _set_tile_box(tile: int) -> void:
	"""Prepare exact X/Z extent; only transient Y values are changed by subsequent readers."""
	_tile_box[0] = (tile % World.MAP_TILES_X) * World.TILE_SIZE_UNITS
	@warning_ignore("integer_division") _tile_box[2] = (tile / World.MAP_TILES_X) * World.TILE_SIZE_UNITS
	_tile_box[3] = _tile_box[0] + World.TILE_SIZE_UNITS
	_tile_box[5] = _tile_box[2] + World.TILE_SIZE_UNITS


static func _vertical_overlap(bounds: PackedInt32Array, low_y: int, high_y: int) -> bool:
	"""Half-open contact at an exact face is not penetration."""
	return low_y < high_y and bounds[1] < high_y and bounds[4] > low_y


func _reset_query() -> void:
	"""Erase previous feedback before any independent cold or hot query."""
	_conflict_ref = NULL_REF
	_conflict_tile = -1


func _conflict(code: StringName, ref: Vector2i, tile: int) -> StringName:
	"""Retain full current conflict identity for a caller's reused status display."""
	_conflict_ref = ref
	_conflict_tile = tile
	return code


static func _clear(out: Space.Volumes) -> void:
	"""No failed query leaves a usable prefix or a previous successful volume table."""
	out.lo_x.clear()
	out.lo_y.clear()
	out.lo_z.clear()
	out.hi_x.clear()
	out.hi_y.clear()
	out.hi_z.clear()
	out.role.clear()
	out.level.clear()
	out.owner_slot.clear()
	out.owner_generation.clear()
	out.owner_revision.clear()
