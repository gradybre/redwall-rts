extends RefCounted
## DEMO-CONTAIN-R01 #9's ground-pile placement contract (decision 0532): the SITE AUTHORITY that
## `inventory.gd::create_ground_pile()` consults, and the one all-or-nothing helper that places
## goods into piles breadth-first.
##
## WHY A SEPARATE COMPOSER. Inventory publishes the single `create_ground_pile(tile)` door and
## enforces what a store of containers can see -- the domain, one pile per tile, the World owner,
## 400000 g. It holds no map, so it cannot prove a tile passable or off a refused footprint, and
## it cannot declare §5.8's storage class, which `stock_age.gd` owns. This file holds exactly
## those three facts' sources -- Buildings, the ground map and StockAge -- plus the World ref, and
## composes them. It owns no simulation state: every column below is cold-path scratch.
##
## THE SITE RULE (`ground_pile_tile_refusal`). A tile admits a pile only when ALL hold:
##   1. it is a placement cell, `0..16383` (GDD §5.1 `z*128+x`);
##   2. it is not on the footprint the current operation is DESTROYING -- the caller's mask, which
##      is how a footprint whose Building row is already gone (D5's commit order removes the
##      building before it places the return) is still refused;
##   3. it is on no STANDING building's footprint. A DEMOLISHING one refuses by that name; every
##      other live footprint refuses as INACCESSIBLE. Brendan confirmed this reading of #9's
##      "inaccessible footprint" on 2026-10-01 (DEC-043): a ground pile never sits on any standing
##      building's footprint;
##   4. it is passable: GDD §5.1 walkable terrain, and, when a ground map is bound, every one of
##      the tile's 4 x 4 navigation cells statically walkable as that map last recorded it.
##
## BREADTH-FIRST PLACEMENT. From the start tiles, of which at least one must pass the site rule,
## tiles are visited in breadth-first order expanding to the N, E, S, W neighbours -- N is -Z, the far side
## from the hall's south door (GDD §5.9; `starter_structures.gd`'s exit runs +Z) -- through tiles
## that pass the site rule. Each visited tile tops up its existing pile, or creates one, until it
## is full, then the goods spill to the next tile. At most SPILL_TILE_CAP tiles are visited. The
## whole call is ONE inventory transaction: a refusal anywhere rolls every pile and lot back, and
## running out of reachable capacity is the explicit GROUND_PILE_NO_CAPACITY. The one exception is
## `place_lots_from_seeds_in_transaction()` (decision 0535), the same walk inside the CALLER's
## open transaction, for DEMO-CONTAIN-R01 #6's single commit; its caller aborts on a refusal and
## calls `declare_placed_piles()` after its own commit.
##
## REFUND ORIGIN (`refund_seeds_into`). #9 places refunds "by breadth-first search from the
## door's outside access tile, excluding the footprint", and Brendan's follow-up ruling of
## 2026-10-01 (DEC-043) covers every building without one:
##   * A building WITH an authored door starts outside it. `buildings.gd` stores no door, so the
##     only authored one is DERIVED from GDD §5.9's hall layout at rotation 0, whose exterior
##     south exit `starter_structures.gd` already resolves: origin + (6, 10).
##   * Every other building -- wells, workbenches, stockpiles, and a hall at any other rotation,
##     whose door position no layout authors -- starts from the RING of tiles touching the
##     footprint, nearest to the building's FRONT first, then spills N, E, S, W as usual.
##   * No building type defines a front, so the front is the rotation-0 SOUTH side (+Z, the side
##     the hall's door is on) rotated by the building's rotation, a quarter turn clockwise per step
##     seen from above with north up (UI-SET-056's "Rotate placement 90 degrees clockwise"):
##     rotation 0 faces S, 1 W, 2 N, 3 E. "Touching" is edge-sharing, so the four corner tiles are
##     not in the ring. "Nearest" is Manhattan distance to the centre of the front side's ring
##     segment, measured in half tiles; ties go to the lower tile index.
## The search is one breadth-first walk seeded with every eligible start tile in that order.
##
## BUILDINGS' PLACEMENT AUTHORITY (decision 0533, closing decision 0532's M4). `settlement_system.gd`
## binds this composer with `buildings.set_placement_authority()`, and `building_tile_refusal()`
## then refuses every footprint tile that carries a live pile, BUILDING_FOOTPRINT_OVER_GROUND_PILE.
## Moving the pile out of the way is evacuation (D6); this only refuses. `bind_stores()` does not
## make that binding itself, so a composer built for a test leaves its Buildings store unguarded.
##
## STORAGE CLASS 1500. After the transaction commits, every pile on a visited tile that is not
## yet declared is declared STORAGE_OPEN_PILE (§5.8 factor 1500). Only after the commit, because
## a rolled-back pile's slot comes back with the same generation and would inherit a stale
## declaration.

const IntMath := preload("res://scripts/core/int_math.gd")
const InventoryScript := preload("res://scripts/core/inventory.gd")
const BuildingsScript := preload("res://scripts/core/buildings.gd")
const StockAgeScript := preload("res://scripts/core/stock_age.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const SpatialWorldScript := preload("res://scripts/core/spatial_world.gd")
const WorldInit := preload("res://scripts/core/world_init.gd")
const StarterStructures := preload("res://scripts/core/starter_structures.gd")
const Catalog := preload("res://scripts/core/catalog.gd")

const MAP_TILES_X: int = BuildingsScript.MAP_TILES_X
const MAP_TILES_Z: int = BuildingsScript.MAP_TILES_Z
## The placement-cell domain. `test_ground_piles.gd` pins it to Inventory's anchor domain.
const TILE_COUNT: int = BuildingsScript.TILE_COUNT
## #9: "spill to neighbours breadth-first in N, E, S, W order, capped at 16,384 tiles".
const SPILL_TILE_CAP: int = 16384
const NO_TILE: int = -1

## One placement row in the caller's flat spec buffer: the seven attributes `create_lot()` takes.
const SPEC_ITEM: int = 0
const SPEC_QUANTITY: int = 1
const SPEC_QUALITY: int = 2
const SPEC_PROVENANCE: int = 3
const SPEC_RECIPE: int = 4
const SPEC_AGE: int = 5
const SPEC_AGE_REMAINDER: int = 6
const SPEC_STRIDE: int = 7

const REFUSE_NONE: StringName = &""
const REFUSE_OUT_OF_BOUNDS: StringName = &"GROUND_PILE_TILE_OUT_OF_BOUNDS"
const REFUSE_IMPASSABLE: StringName = &"GROUND_PILE_TILE_IMPASSABLE"
const REFUSE_DEMOLISHING_FOOTPRINT: StringName = &"GROUND_PILE_ON_DEMOLISHING_FOOTPRINT"
const REFUSE_DESTROYED_FOOTPRINT: StringName = &"GROUND_PILE_ON_DESTROYED_FOOTPRINT"
const REFUSE_INACCESSIBLE_FOOTPRINT: StringName = &"GROUND_PILE_ON_INACCESSIBLE_FOOTPRINT"
const REFUSE_NO_WORLD: StringName = &"GROUND_PILE_NO_WORLD_REF"
const REFUSE_NOT_BOUND: StringName = &"GROUND_PILE_STORES_NOT_BOUND"
const REFUSE_NO_CAPACITY: StringName = &"GROUND_PILE_NO_CAPACITY"
const REFUSE_MASK_SHAPE: StringName = &"GROUND_PILE_EXCLUSION_MASK_SHAPE"
const REFUSE_SPEC_SHAPE: StringName = &"GROUND_PILE_LOT_SPEC_SHAPE"
const REFUSE_SPEC_VALUE: StringName = &"GROUND_PILE_LOT_SPEC_VALUE"
const REFUSE_TRANSACTION_OPEN: StringName = &"GROUND_PILE_TRANSACTION_OPEN"
## The in-transaction variant (decision 0535) places inside the CALLER's transaction, so it
## refuses when none is open rather than opening, committing or aborting one itself.
const REFUSE_TRANSACTION_CLOSED: StringName = &"GROUND_PILE_TRANSACTION_NOT_OPEN"
const REFUSE_STALE_BUILDING: StringName = &"GROUND_PILE_STALE_BUILDING"
const REFUSE_DOOR_OFF_GRID: StringName = &"GROUND_PILE_DOOR_OFF_GRID"
const REFUSE_SEED_SHAPE: StringName = &"GROUND_PILE_START_TILES_SHAPE"
const REFUSE_DECLARE: StringName = &"GROUND_PILE_STORAGE_CLASS_REFUSED"
## Decision 0532's M4, refused by name: a building footprint may not cover a live ground pile.
const REFUSE_BUILDING_OVER_PILE: StringName = &"BUILDING_FOOTPRINT_OVER_GROUND_PILE"

## N, E, S, W as (dx, dz) on the `z*128+x` grid. N is -Z.
const NEIGHBOUR_DX: Array[int] = [0, 1, 0, -1]
const NEIGHBOUR_DZ: Array[int] = [-1, 0, 1, 0]

## The most start tiles one refund can have: the edge ring of any rectangle on the grid is at most
## `2 * (128 + 128)`. A caller's seed buffer must hold this many cells.
const REFUND_SEED_CAPACITY: int = 2 * (MAP_TILES_X + MAP_TILES_Z)
## The front a building faces, per rotation: the rotation-0 south side turned a quarter clockwise
## per step (S, W, N, E), as (dx, dz). Decision 0532 records the choice; DEC-043 orders it.
const FRONT_DX: Array[int] = [0, -1, 0, 1]
const FRONT_DZ: Array[int] = [1, 0, -1, 0]
const INT64_MAX: int = 9223372036854775807


class PlaceResult:
	"""Caller-owned outcome of one placement. `.ok` must be read first; a refusal zeroes counts.

	`.ok` true means the placement COMMITTED. `.error` is then normally empty; a nonempty one
	with `.ok` true is the post-commit GROUND_PILE_STORAGE_CLASS_REFUSED integrity flag.
	"""
	var ok: bool = false
	var error: StringName = &""
	var tiles_visited: int = 0
	var piles_created: int = 0
	var lots_created: int = 0

	func clear() -> void:
		"""Reset every field to the empty outcome."""
		ok = false
		error = &""
		tiles_visited = 0
		piles_created = 0
		lots_created = 0

	func refuse(code: StringName) -> bool:
		"""Record a refusal that carries no counts. Always returns false."""
		clear()
		error = code
		return false


var _inventory: InventoryScript = null
var _buildings: BuildingsScript = null
var _stock_age: StockAgeScript = null
var _spatial: SpatialWorldScript = null
var _world_ref: Vector2i = EntityDirectory.NULL_REF

## BFS scratch, allocated once (ARCH-MEM-001) and ledgered in ARCH §2.3. `_visited` marks a tile
## examined in this call; `_queue[0, _queue_tail)` is the examined-and-eligible order.
var _visited: PackedByteArray = PackedByteArray()
var _queue: PackedInt32Array = PackedInt32Array()
var _queue_tail: int = 0
## The footprint the current operation is destroying: the caller's mask, borrowed for one call.
var _excluded: PackedByteArray = PackedByteArray()
## Ring-ordering scratch: `distance * TILE_COUNT + tile` per ring tile, INT64_MAX past the ring,
## so one in-place sort orders the ring. `_single_seed` carries one start tile without allocating.
var _seed_keys: PackedInt64Array = PackedInt64Array()
var _single_seed: PackedInt32Array = PackedInt32Array()
## Placement cursor: the spec row being placed and the quantity of it still unplaced.
var _spec_row: int = 0
var _spec_remaining: int = 0


func _init() -> void:
	"""Allocate the BFS scratch once."""
	_visited.resize(TILE_COUNT)
	_queue.resize(TILE_COUNT)
	_seed_keys.resize(REFUND_SEED_CAPACITY)
	_single_seed.resize(1)
	_visited.fill(0)
	_queue.fill(NO_TILE)


func bind_stores(inventory: InventoryScript, buildings: BuildingsScript,
		stock_age: StockAgeScript, spatial: SpatialWorldScript = null) -> bool:
	"""Bind the stores this composer reads and register it as `inventory`'s site authority.

	False, binding nothing, when a required store is null or Inventory refuses the authority.
	`spatial` is optional: without it passability is GDD §5.1's static terrain alone.
	"""
	if inventory == null or buildings == null or stock_age == null:
		return false
	if not inventory.set_ground_pile_authority(self).ok:
		return false
	_inventory = inventory
	_buildings = buildings
	_stock_age = stock_age
	_spatial = spatial
	return true


func bind_world(world_ref: Vector2i) -> bool:
	"""Record the World directory ref that owns every pile. Refuses anything but a live World."""
	if _buildings == null:
		return false
	if not _buildings.directory().is_valid_of_kind(world_ref, EntityDirectory.KIND_WORLD):
		return false
	_world_ref = world_ref
	return true


# --- the site authority Inventory calls -------------------------------------------------------

func ground_pile_owner_ref() -> Vector2i:
	"""The World ref, or the null ref when none is bound or it is no longer live."""
	if _buildings == null:
		return EntityDirectory.NULL_REF
	if not _buildings.directory().is_valid_of_kind(_world_ref, EntityDirectory.KIND_WORLD):
		return EntityDirectory.NULL_REF
	return _world_ref


func ground_pile_tile_refusal(tile: int) -> StringName:
	"""REFUSE_NONE only for a tile #9 lets a pile stand on; else the first rule it breaks."""
	if tile < 0 or tile >= TILE_COUNT:
		return REFUSE_OUT_OF_BOUNDS
	if ground_pile_owner_ref() == EntityDirectory.NULL_REF:
		return REFUSE_NO_WORLD
	if _excluded.size() == TILE_COUNT and _excluded[tile] != 0:
		return REFUSE_DESTROYED_FOOTPRINT
	var footprint: StringName = _footprint_refusal(tile)
	if footprint != REFUSE_NONE:
		return footprint
	return REFUSE_NONE if is_tile_passable(tile) else REFUSE_IMPASSABLE


func _footprint_refusal(tile: int) -> StringName:
	"""DEMOLISHING by name; every other live footprint as not proven accessible."""
	var building: Vector2i = _buildings.building_at_tile(tile)
	if building == EntityDirectory.NULL_REF:
		return REFUSE_NONE
	var state: BuildingsScript.OpResult = _buildings.state_of_building(building)
	if state.ok and state.value == Catalog.BUILDING_STATE["DEMOLISHING"]:
		return REFUSE_DEMOLISHING_FOOTPRINT
	return REFUSE_INACCESSIBLE_FOOTPRINT


func building_tile_refusal(tile: int) -> StringName:
	"""Buildings' placement authority: refuse a footprint tile that carries a live ground pile.

	REFUSE_NOT_BOUND before `bind_stores()`, because an authority that cannot see the piles must
	not wave a footprint through. Reads one cell of Inventory's derived tile -> pile map.
	"""
	if _inventory == null:
		return REFUSE_NOT_BOUND
	if _inventory.ground_pile_at_tile(tile) != InventoryScript.NULL_REF:
		return REFUSE_BUILDING_OVER_PILE
	return REFUSE_NONE


func is_tile_passable(tile: int) -> bool:
	"""GDD §5.1 walkable terrain, and every bound navigation cell under the tile walkable."""
	if tile < 0 or tile >= TILE_COUNT:
		return false
	var x: int = tile % MAP_TILES_X
	@warning_ignore("integer_division") var z: int = tile / MAP_TILES_X
	if not WorldInit.is_walkable(x, z):
		return false
	if _spatial == null:
		return true
	var per: int = SpatialWorldScript.CELLS_PER_TILE
	for dz: int in per:
		for dx: int in per:
			var cell: int = (z * per + dz) * SpatialWorldScript.CELLS_X + x * per + dx
			if not _spatial.is_walkable_cell(cell):
				return false
	return true


# --- the refund origin ---------------------------------------------------------------------------

func refund_seeds_into(building_ref: Vector2i, footprint_mask: PackedByteArray,
		out_seeds: PackedInt32Array, out: IntMath.IntResult) -> bool:
	"""Write a live building's refund start tiles into `out_seeds`; `out.value` is their count.

	The rotation-0 hall yields its one outside door tile; every other building yields its
	footprint's edge ring, nearest to its front first (DEC-043, 2026-10-01). The footprint is
	marked in `footprint_mask`. Call it BEFORE the building is removed: the mask is what keeps the
	destroyed footprint excluded afterwards. Refuses a mask that is not exactly 16384 bytes, a
	seed buffer under REFUND_SEED_CAPACITY cells, a stale ref and a door off the grid; on refusal
	neither the mask nor the buffer is written.
	"""
	if _buildings == null:
		return out.refuse(String(REFUSE_NOT_BOUND))
	if footprint_mask.size() != TILE_COUNT:
		return out.refuse(String(REFUSE_MASK_SHAPE))
	if out_seeds.size() < REFUND_SEED_CAPACITY:
		return out.refuse(String(REFUSE_SEED_SHAPE))
	var type_result: BuildingsScript.OpResult = _buildings.type_id_of_building(building_ref)
	if not type_result.ok:
		return out.refuse(String(REFUSE_STALE_BUILDING))
	var origin: int = _buildings.origin_tile_of_building(building_ref).value
	var rotation: int = _buildings.rotation_of_building(building_ref).value
	if not _seeds_of_into(type_result.value, origin, rotation, out_seeds, out):
		return false
	_mark_footprint(footprint_mask, type_result.value, origin, rotation)
	return true


func _seeds_of_into(type_id: int, origin: int, rotation: int, out_seeds: PackedInt32Array,
		out: IntMath.IntResult) -> bool:
	"""The door tile when the layout authors one, else the front-first ring; `out` the count."""
	if not has_authored_door(type_id, rotation):
		return out.succeed(_ring_seeds_into(type_id, origin, rotation, out_seeds))
	if not _hall_door_outside_into(origin, out):
		return false
	out_seeds[0] = out.value
	return out.succeed(1)


static func has_authored_door(type_id: int, rotation: int) -> bool:
	"""True only for GDD §5.9's hall at rotation 0, the one layout that authors an exterior door."""
	return type_id == int(Catalog.BUILDING_DEFINITION[StarterStructures.HALL_KEY]) and rotation == 0


func _ring_seeds_into(type_id: int, origin: int, rotation: int, out_seeds: PackedInt32Array) -> int:
	"""The footprint's in-grid edge ring, nearest to the front first, into `out_seeds`; its size."""
	var size_x: int = _buildings.definitions().footprint_x_of(type_id)
	var size_z: int = _buildings.definitions().footprint_z_of(type_id)
	var extent_x: int = _buildings.extent_x_of(size_x, size_z, rotation)
	var extent_z: int = _buildings.extent_z_of(size_x, size_z, rotation)
	var x0: int = origin % MAP_TILES_X
	@warning_ignore("integer_division") var z0: int = origin / MAP_TILES_X
	# The front ring segment's centre, in half tiles: the footprint centre pushed out past the
	# front side by half the footprint plus one tile.
	var centre: Vector2i = Vector2i(2 * x0 + extent_x - 1 + FRONT_DX[rotation] * (extent_x + 1),
		2 * z0 + extent_z - 1 + FRONT_DZ[rotation] * (extent_z + 1))
	_seed_keys.fill(INT64_MAX)
	var count: int = 0
	for dx: int in extent_x:
		count = _add_ring_tile(x0 + dx, z0 - 1, centre, count)
		count = _add_ring_tile(x0 + dx, z0 + extent_z, centre, count)
	for dz: int in extent_z:
		count = _add_ring_tile(x0 - 1, z0 + dz, centre, count)
		count = _add_ring_tile(x0 + extent_x, z0 + dz, centre, count)
	_seed_keys.sort()
	for index: int in count:
		out_seeds[index] = _seed_keys[index] % TILE_COUNT
	return count


func _add_ring_tile(x: int, z: int, centre: Vector2i, count: int) -> int:
	"""Key one ring tile by its half-tile distance to the front centre, if it is on the grid."""
	if x < 0 or x >= MAP_TILES_X or z < 0 or z >= MAP_TILES_Z:
		return count
	var distance: int = absi(2 * x - centre.x) + absi(2 * z - centre.y)
	_seed_keys[count] = distance * TILE_COUNT + z * MAP_TILES_X + x
	return count + 1


func _hall_door_outside_into(origin_tile: int, out: IntMath.IntResult) -> bool:
	"""The hall's outside door tile, as the starter layout's own exit offset from its origin."""
	var hall_row: int = StarterStructures.BUILD_KEYS.find(StarterStructures.HALL_KEY)
	var starter_origin: int = StarterStructures.BUILD_ORIGIN_Z[hall_row] * MAP_TILES_X \
		+ StarterStructures.BUILD_ORIGIN_X[hall_row]
	var dx: int = StarterStructures.EXIT_EXTERIOR_GLOBAL % MAP_TILES_X - starter_origin % MAP_TILES_X
	@warning_ignore("integer_division") var dz: int = StarterStructures.EXIT_EXTERIOR_GLOBAL / MAP_TILES_X - starter_origin / MAP_TILES_X
	var x: int = origin_tile % MAP_TILES_X + dx
	@warning_ignore("integer_division") var z: int = origin_tile / MAP_TILES_X + dz
	if x < 0 or x >= MAP_TILES_X or z < 0 or z >= MAP_TILES_Z:
		return out.refuse(String(REFUSE_DOOR_OFF_GRID))
	return out.succeed(z * MAP_TILES_X + x)


func _mark_footprint(mask: PackedByteArray, type_id: int, origin: int, rotation: int) -> void:
	"""Set every tile of one footprint in a 16384-byte mask, leaving other bytes as they were."""
	var size_x: int = _buildings.definitions().footprint_x_of(type_id)
	var size_z: int = _buildings.definitions().footprint_z_of(type_id)
	for dz: int in _buildings.extent_z_of(size_x, size_z, rotation):
		for dx: int in _buildings.extent_x_of(size_x, size_z, rotation):
			mask[origin + dz * MAP_TILES_X + dx] = 1


# --- placing goods into piles --------------------------------------------------------------------

func place_lots_into_piles(start_tile: int, excluded_mask: PackedByteArray,
		specs: PackedInt64Array, out: PlaceResult) -> bool:
	"""Place every spec row into piles breadth-first from `start_tile`, all or nothing.

	`excluded_mask` is empty or exactly 16384 bytes; a nonzero byte is a destroyed-footprint tile.
	`specs` is SPEC_STRIDE int64 per row: item, quantity_milli (> 0), quality, provenance,
	recipe_id, age_milli_hours, age_remainder. Refuses an open inventory transaction; otherwise
	opens one, and on any refusal -- GROUND_PILE_NO_CAPACITY included -- rolls it back so every
	store is byte-identical. New piles are declared storage class 1500 after the commit.
	"""
	_single_seed[0] = start_tile
	return _run_placement(_single_seed, 1, excluded_mask, specs, out, true)


func place_lots_from_seeds(seeds: PackedInt32Array, seed_count: int,
		excluded_mask: PackedByteArray, specs: PackedInt64Array, out: PlaceResult) -> bool:
	"""`place_lots_into_piles()` from the first `seed_count` start tiles, in their order.

	This is the refund entry point: pass what `refund_seeds_into()` wrote. Ineligible seeds are
	skipped; when none is eligible the first seed's own refusal is returned.
	"""
	return _run_placement(seeds, seed_count, excluded_mask, specs, out, true)


func preflight_lots_into_piles(start_tile: int, excluded_mask: PackedByteArray,
		specs: PackedInt64Array, out: PlaceResult) -> bool:
	"""The same placement, always rolled back: would it fit? Leaves every store unchanged."""
	_single_seed[0] = start_tile
	return _run_placement(_single_seed, 1, excluded_mask, specs, out, false)


func preflight_lots_from_seeds(seeds: PackedInt32Array, seed_count: int,
		excluded_mask: PackedByteArray, specs: PackedInt64Array, out: PlaceResult) -> bool:
	"""`place_lots_from_seeds()`, always rolled back."""
	return _run_placement(seeds, seed_count, excluded_mask, specs, out, false)


func place_lots_from_seeds_in_transaction(seeds: PackedInt32Array, seed_count: int,
		excluded_mask: PackedByteArray, specs: PackedInt64Array, out: PlaceResult) -> bool:
	"""`place_lots_from_seeds()` inside the CALLER's open transaction (decision 0532's M2 variant).

	DEMO-CONTAIN-R01 #6 puts the destroyed stores and the 50% return in ONE inventory
	transaction, so this neither opens, commits nor aborts one: it refuses
	GROUND_PILE_TRANSACTION_NOT_OPEN without one. On any refusal the caller MUST abort, because
	piles and lots placed before the refusal are inside its transaction. Storage class 1500 is
	declared only after the caller's commit, through `declare_placed_piles()`.
	"""
	out.clear()
	var ready: StringName = _placement_refusal(seeds, seed_count, excluded_mask, specs, true)
	if ready != REFUSE_NONE:
		return out.refuse(ready)
	_excluded = excluded_mask
	var code: StringName = _place_breadth_first(seeds, seed_count, specs, out)
	_excluded = PackedByteArray()
	if code != REFUSE_NONE:
		return out.refuse(code)
	out.ok = true
	return true


func declare_placed_piles() -> bool:
	"""Declare storage class 1500 on the piles the last in-transaction placement visited.

	Call it once, after the caller's transaction COMMITTED and before any other placement call:
	a rolled-back pile's slot returns with the same generation and would inherit a declaration
	made earlier. False when a declaration refused, which is unreachable while every visited pile
	holds a lot; the goods are placed either way, so a caller flags it and never re-places.
	"""
	return _declare_visited_piles()


func _run_placement(seeds: PackedInt32Array, seed_count: int, excluded_mask: PackedByteArray,
		specs: PackedInt64Array, out: PlaceResult, keep: bool) -> bool:
	"""Validate, place inside one transaction, then commit or roll back."""
	out.clear()
	var ready: StringName = _placement_refusal(seeds, seed_count, excluded_mask, specs, false)
	if ready != REFUSE_NONE:
		return out.refuse(ready)
	_excluded = excluded_mask
	_inventory.begin()
	var code: StringName = _place_breadth_first(seeds, seed_count, specs, out)
	if code != REFUSE_NONE or not keep:
		_inventory.abort()
		_excluded = PackedByteArray()
		if code != REFUSE_NONE:
			return out.refuse(code)
		out.ok = true
		return true
	var committed: InventoryScript.OpResult = _inventory.commit()
	_excluded = PackedByteArray()
	if not committed.ok:
		return out.refuse(committed.error)
	# Committed: from here the goods ARE placed, so the answer is ok whatever follows. A failed
	# declaration (unreachable while every visited pile holds a lot) is flagged, never a refusal,
	# because a caller retrying a "refused" refund would place it twice.
	out.ok = true
	if not _declare_visited_piles():
		out.error = REFUSE_DECLARE
	return true


func _placement_refusal(seeds: PackedInt32Array, seed_count: int,
		excluded_mask: PackedByteArray, specs: PackedInt64Array, in_transaction: bool) -> StringName:
	"""Everything checkable before any placement write, the seed shape included."""
	var ready: StringName = _placement_input_refusal(excluded_mask, specs, in_transaction)
	if ready == REFUSE_NONE and (seed_count < 1 or seed_count > seeds.size()):
		return REFUSE_SEED_SHAPE
	return ready


func _placement_input_refusal(excluded_mask: PackedByteArray,
		specs: PackedInt64Array, in_transaction: bool) -> StringName:
	"""Everything checkable before the transaction opens, or before writing into the caller's."""
	if _inventory == null or _buildings == null or _stock_age == null:
		return REFUSE_NOT_BOUND
	if _inventory.is_transaction_open() != in_transaction:
		return REFUSE_TRANSACTION_CLOSED if in_transaction else REFUSE_TRANSACTION_OPEN
	if excluded_mask.size() != 0 and excluded_mask.size() != TILE_COUNT:
		return REFUSE_MASK_SHAPE
	if specs.size() == 0 or specs.size() % SPEC_STRIDE != 0:
		return REFUSE_SPEC_SHAPE
	@warning_ignore("integer_division") for row: int in specs.size() / SPEC_STRIDE:
		var item: int = specs[row * SPEC_STRIDE + SPEC_ITEM]
		if specs[row * SPEC_STRIDE + SPEC_QUANTITY] <= 0 \
				or not _inventory.is_item_registered(item):
			return REFUSE_SPEC_VALUE
	return REFUSE_NONE


func _place_breadth_first(seeds: PackedInt32Array, seed_count: int, specs: PackedInt64Array,
		out: PlaceResult) -> StringName:
	"""Walk eligible tiles from the seeds, filling each before spilling to the next."""
	var start: StringName = _enqueue_seeds(seeds, seed_count)
	if start != REFUSE_NONE:
		return start
	_spec_row = 0
	_spec_remaining = specs[SPEC_QUANTITY]
	@warning_ignore("integer_division") var rows: int = specs.size() / SPEC_STRIDE
	var head: int = 0
	while head < _queue_tail and _spec_row < rows and head < SPILL_TILE_CAP:
		var tile: int = _queue[head]
		head += 1
		out.tiles_visited += 1
		var filled: StringName = _fill_tile(tile, specs, rows, out)
		if filled != REFUSE_NONE:
			return filled
		_enqueue_neighbours(tile)
	return REFUSE_NONE if _spec_row >= rows else REFUSE_NO_CAPACITY


func _enqueue_seeds(seeds: PackedInt32Array, seed_count: int) -> StringName:
	"""Queue the eligible seeds in order; with none eligible, the first seed's refusal."""
	_visited.fill(0)
	_queue_tail = 0
	var first: StringName = REFUSE_NONE
	for index: int in seed_count:
		var tile: int = seeds[index]
		var code: StringName = ground_pile_tile_refusal(tile)
		if code == REFUSE_NONE and _visited[tile] == 0:
			_visited[tile] = 1
			_queue[_queue_tail] = tile
			_queue_tail += 1
		elif first == REFUSE_NONE:
			first = code
	if _queue_tail == 0:
		return first
	return REFUSE_NONE


func _enqueue_neighbours(tile: int) -> void:
	"""Append the unexamined N, E, S, W neighbours that pass the site rule, in that order."""
	var x: int = tile % MAP_TILES_X
	@warning_ignore("integer_division") var z: int = tile / MAP_TILES_X
	for direction: int in NEIGHBOUR_DX.size():
		var nx: int = x + NEIGHBOUR_DX[direction]
		var nz: int = z + NEIGHBOUR_DZ[direction]
		if nx < 0 or nx >= MAP_TILES_X or nz < 0 or nz >= MAP_TILES_Z:
			continue
		var neighbour: int = nz * MAP_TILES_X + nx
		if _visited[neighbour] != 0:
			continue
		_visited[neighbour] = 1
		if ground_pile_tile_refusal(neighbour) == REFUSE_NONE:
			_queue[_queue_tail] = neighbour
			_queue_tail += 1


func _fill_tile(tile: int, specs: PackedInt64Array, rows: int, out: PlaceResult) -> StringName:
	"""Place as much of the remaining specs as this tile's pile can hold, creating it if needed."""
	var pile: Vector2i = _inventory.ground_pile_at_tile(tile)
	while _spec_row < rows:
		var base: int = _spec_row * SPEC_STRIDE
		var free_g: int = InventoryScript.GROUND_PILE_MAX_MASS_G
		if pile != InventoryScript.NULL_REF:
			free_g = _inventory.container_free_mass_g(pile)
		var fit: int = _fitting_milli(specs[base + SPEC_ITEM], free_g)
		if fit <= 0:
			return REFUSE_NONE
		if pile == InventoryScript.NULL_REF:
			var made: InventoryScript.OpResult = _inventory.create_ground_pile(tile)
			if not made.ok:
				return made.error
			pile = made.ref
			out.piles_created += 1
		var code: StringName = _create_part(pile, specs, base, fit)
		if code != REFUSE_NONE:
			return code
		out.lots_created += 1
		_advance_cursor(specs, rows, fit)
	return REFUSE_NONE


func _fitting_milli(item_id: int, free_g: int) -> int:
	"""How much of the current spec fits `free_g` grams, charged `ceil(q*m/1000)` per lot.

	`ceil(q*m/1000) <= free` exactly when `q*m <= free*1000`, so the largest fitting quantity is
	`floor(free*1000/m)`. A massless item always fits whole.
	"""
	var mass_g: int = _inventory.item_mass_g(item_id)
	if mass_g <= 0:
		return _spec_remaining
	@warning_ignore("integer_division") return mini(_spec_remaining, free_g * InventoryScript.MILLI_PER_UNIT / mass_g)


func _create_part(pile: Vector2i, specs: PackedInt64Array, base: int, quantity: int) -> StringName:
	"""Create one lot of `quantity` carrying the spec row's attributes, in `pile`."""
	var made: InventoryScript.OpResult = _inventory.create_lot(pile, specs[base + SPEC_ITEM],
		quantity, specs[base + SPEC_QUALITY], specs[base + SPEC_PROVENANCE],
		specs[base + SPEC_RECIPE], specs[base + SPEC_AGE], specs[base + SPEC_AGE_REMAINDER])
	return made.error


func _advance_cursor(specs: PackedInt64Array, rows: int, placed: int) -> void:
	"""Charge `placed` against the current spec; step to the next row when it is exhausted."""
	_spec_remaining -= placed
	if _spec_remaining > 0:
		return
	_spec_row += 1
	if _spec_row < rows:
		_spec_remaining = specs[_spec_row * SPEC_STRIDE + SPEC_QUANTITY]


func _declare_visited_piles() -> bool:
	"""Declare storage class 1500 on every visited tile's pile that has no declaration yet."""
	for index: int in _queue_tail:
		var pile: Vector2i = _inventory.ground_pile_at_tile(_queue[index])
		if pile == InventoryScript.NULL_REF:
			continue
		if _stock_age.storage_class_of(pile) != StockAgeScript.STORAGE_UNDECLARED:
			continue
		if not _stock_age.declare_storage_class(pile, StockAgeScript.STORAGE_OPEN_PILE):
			return false
	return true


func last_queue_length() -> int:
	"""How many eligible tiles the last placement examined into its queue. Diagnostic only."""
	return _queue_tail
