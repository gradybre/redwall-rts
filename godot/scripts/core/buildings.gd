extends RefCounted
## The packed Building, Room and Furniture stores, and the furniture-presence mask.
##
## GDD §4.2 states the three rows exactly:
##   Building  | type_id, tier, origin_tile, rotation, state, condition, construction: EntityRef,
##               interior_id                              | "At most 1024 exterior structures"
##   Room      | type, building: EntityRef, tile_offset, tile_count, valid, temperature_tenths,
##               furniture_mask, occupants                | "Up to 16 rooms/managed building"
##   Furniture | type_id, room: EntityRef, origin_tile, rotation, user: EntityRef, condition
## `systems_architecture.md` §2.2 repeats all three with lengths 1024 / 16384 / 81920, and
## `entity_directory.gd` reserves KIND_BUILDING, KIND_ROOM and KIND_FURNITURE at exactly those
## row counts. `_init()` asserts the agreement rather than trusting it.
##
## ONE MODULE, THREE STORES, AND WHY. R-BUILD-DOM-003 requires the room mask and its membership
## to be updated "atomically on create/remove/reassign". A furniture row's presence bit lives on
## the room it references, and a room's tiles live on the building it references, so the three
## stores share invariants that only one writer can keep. Splitting them across modules would
## put a two-phase update across a module boundary with no transaction, which is how a mask
## survives the row it was counting. `inventory.gd` (containers + lots) and `fishing.gd`
## (habitats + stocks + claims) set the same precedent.
##
## THE FURNITURE MASK (R-BUILD-DOM-003, decision 0074). `furniture_bit(i) = 1 << i` for a
## validated FurnitureDefinition id, so bed=1, decoration=2, hearth=4, interior_door=8,
## interior_partition=16, kitchen_bench=32, patient_bed=64, seat=128, shelf=256 and the known
## mask is 511. `Room.furniture_mask` is the bitwise OR over LIVE, COMMITTED furniture rows whose
## `room` EntityRef resolves to THAT EXACT ROOM GENERATION. It records structural row presence:
##   * a damaged bed still sets bit 1 -- usability is a separate check;
##   * two beds still yield bit value 1, and removing one cannot clear it while the other lives;
##   * a reused room slot starts at 0 and can never inherit the previous room's bits, because the
##     generation on the reference no longer resolves;
##   * an uncommitted placement contributes nothing, because this store has no uncommitted rows:
##     `place_furniture()` either publishes a row or refuses, and a refusal writes nothing.
## The mask is RECOMPUTED from the room's own bounded furniture chain on every structural edit
## (`_recompute_mask_row()`), never incrementally cleared -- an incremental clear is exactly the
## bug where removing one of two beds drops the bed bit. No per-room nine-counter arena is
## allocated; the chain is the accounting, and its cost is one ledger row per link column.
##
## A MASK READ ESTABLISHES NOTHING ELSE. The ruling: "Mask reads do not establish counts, seats,
## bed capacity, comfort, pantry grams, heat, route connectivity or operational work slots."
## `pantry_capacity_g_of_room()`, `kitchen_bench_slots_of_room()` and `count_furniture_of_kind()`
## therefore walk real rows; none of them consults `furniture_mask`. `verify_room_masks()` is the
## load-time comparison R-BUILD-DOM-003 requires -- recompute from staged rows, compare, and
## REFUSE a mismatch rather than silently repairing it.
##
## THE STARTER FIFTH SHELF (R-BUILD-DOM-004). GDD §5.9's interior diagram has five `S` cells: four
## in the row-7 pantry and one at kitchen row 1. All five are instantiated. Only shelves in a
## VALID PANTRY room contribute to the pantry service, so the four give 4 x 50000 = 200000 g and
## the kitchen-owned shelf gives none. `pantry_capacity_g_of_room()` refuses a non-PANTRY room
## outright rather than returning 0, so the kitchen shelf cannot be quietly summed into a total.
## Both rooms still carry shelf-presence bit 256; presence is not capacity.
##
## THE UNLOCK GATE. `place_building()` takes the caller's `unlocked_mask` and tests the
## definition's own earned bit through `milestones.gd`. It never defaults the mask: an absent
## Progress store is unavailable, so a caller with no mask cannot place anything, which is the
## refusal R-BUILD-DOM-001 asks for rather than a fabricated M0 world.
##
## WHAT THIS STORE DOES NOT DECIDE -- named, not invented:
##   * `Building.condition`'s SCALE IS UNSTATED. GDD §4.2 types it int32; §4.3 numbers no scale;
##     §5.9, gameplay_balance.md and ui_ux_controls.md give no repair threshold, no maximum and
##     no damage rate for a building (the 1000/1500 caps in §5.9 are TOOL durability). The store
##     validates non-negativity and the int32 bound and stores what it is given. The DAMAGED
##     transition and any maximum belong to the construction/repair contract in task 06.2.
##   * `Building.interior_id`'s DOMAIN IS UNSTATED. §5.9 says only "Indoor kit themes change
##     geometry only". It is stored as a catalog id with GDD §4.2's "-1 means empty" and is never
##     dereferenced here.
##   * REQ-SET-122's SLOPE, HEIGHT-SPREAD, DOOR AND TERRAIN CONDITIONS ARE NOT EVALUATED. They
##     read terrain masks this store does not own (`world_init.gd` owns ground). What IS enforced
##     is the half REQ-SET-122 states in tiles: in-bounds and nonoverlapping.
##   * BAL-BUILD-001's EDGE-OVERLAP RULE IS NOT ENFORCED. "Edge furniture occupies exactly one
##     undirected interior tile edge and cannot overlap another edge object" needs an edge index
##     keyed by the undirected pair, and nothing states how `origin_tile`+`rotation` name an
##     edge. Edge furniture is accepted on a tile of its room with a validated rotation; the
##     overlap gate belongs with 06.2's atomic-edit contract.
##   * ROOM VALIDITY IS NOT SET HERE FROM TOPOLOGY. `room_meets_countable_rules()` implements
##     exactly the counting half of §5.9's validity list; connectivity, enclosure, exterior links
##     and "heated" need the room/heat topology of 06.2/06.3. `set_room_valid()` is the setter
##     the owning system calls, and no room becomes valid on counting evidence alone.
##   * NO CONSTRUCTION STORE. `Building.construction` is stored and validated as a live
##     KIND_CONSTRUCTION reference when one is supplied; delivery, WIP, refunds and completion
##     are task 06.2. A blueprint placed here has no project behind it yet.
##   * NO CONTAINER IS CREATED. `inventory.gd` owns InventoryContainer rows and
##     R-BUILD-DOM-004 says in terms "do not create a parallel container store". This store
##     publishes the Building row a container can be owned BY, and `base_store_g_of()` states the
##     capacity such a container should be created with; the composition call belongs to the
##     integration owner.

const Catalog := preload("res://scripts/core/catalog.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const BuildingDefinitions := preload("res://scripts/core/building_definitions.gd")
const Milestones := preload("res://scripts/core/milestones.gd")

## systems_architecture.md §2.2 and entity_directory.gd's KIND_CAPACITY, which must agree.
const BUILDING_CAPACITY: int = 1024
const ROOM_CAPACITY: int = 16384
const FURNITURE_CAPACITY: int = 81920

## GDD §5.1's exterior grid: index `z*128+x`, 16384 tiles -- the row count
## `systems_architecture.md` §3 gives `WorldTileMaps`, whose `building_slot` and `room_slot`
## columns this module owns (`resource_nodes.gd` owns `resource_slot` and left these two to
## "the stores that will").
const MAP_TILES_X: int = 128
const MAP_TILES_Z: int = 128
const TILE_COUNT: int = MAP_TILES_X * MAP_TILES_Z

## `systems_architecture.md` §3's `RoomTileLinks`: "Nonoverlapping room tiles", 16384 entries.
const ROOM_TILE_LINK_CAPACITY: int = 16384

## GDD §4.2: "Up to 16 rooms/managed building".
const MAX_ROOMS_PER_BUILDING: int = 16

## GDD §4.2: "rotation 0-3"; §5.9: "rotation in 90 degree steps".
const ROTATION_COUNT: int = 4

## The nine FurnitureDefinition kinds, for the per-kind live counters.
const FURNITURE_KIND_COUNT: int = BuildingDefinitions.FURNITURE_DEFINITION_COUNT

## §5.9's managed interiors are the exterior footprint inset by one tile on every side: the hall
## is 12x10 outside and "Interior 10x8", the residence 10x8 and "Interior 8x6", the infirmary 8x8
## and "Interior 6x6", and "Hall interior origin is exterior origin+(1,1)". `_assert_interiors()`
## re-derives §4.1's room_tiles (80/48/36) from this inset so a drifting table fails loudly.
const INTERIOR_INSET_TILES: int = 1

## Internal absence marker for a typed row index, mirroring the directory's NULL_SLOT. It is
## never returned by a public function: every public refusal carries a code instead.
const NO_ROW: int = EntityDirectory.NULL_SLOT

## Empty value of the intrusive chain links and the two tile maps.
const NO_LINK: int = -1

const NULL_REF: Vector2i = EntityDirectory.NULL_REF

## GDD §4.2: "empty catalog IDs are -1". Used for `interior_id` when no indoor kit is bound.
const NO_INTERIOR: int = Catalog.EMPTY_CATALOG_ID

const INT32_MIN: int = -2147483648
const INT32_MAX: int = 2147483647

## GDD §4.3's protected BuildingState and RoomType ordinals, read from their owner so this
## module holds no second copy of a number §4.3 states.
const STATE_BLUEPRINT: int = Catalog.BUILDING_STATE["BLUEPRINT"]
const STATE_COUNT: int = 6
const ROOM_TYPE_DORMITORY: int = Catalog.ROOM_TYPE["DORMITORY"]
const ROOM_TYPE_PRIVATE_ROOM: int = Catalog.ROOM_TYPE["PRIVATE_ROOM"]
const ROOM_TYPE_KITCHEN: int = Catalog.ROOM_TYPE["KITCHEN"]
const ROOM_TYPE_DINING: int = Catalog.ROOM_TYPE["DINING"]
const ROOM_TYPE_COMMON: int = Catalog.ROOM_TYPE["COMMON"]
const ROOM_TYPE_INFIRMARY: int = Catalog.ROOM_TYPE["INFIRMARY"]
const ROOM_TYPE_PANTRY: int = Catalog.ROOM_TYPE["PANTRY"]
const ROOM_TYPE_CORRIDOR: int = Catalog.ROOM_TYPE["CORRIDOR"]
const ROOM_TYPE_COUNT: int = 8

## GDD §5.9 room validity, the countable half. "dormitory>=3 tiles/bed, at least 1 bed";
## "private room>=6 tiles, exactly 1 bed"; "dining>=2 tiles/seat and>=4 seats"; "kitchen>=6
## tiles,>=1 bench,>=1 hearth"; "common>=8 tiles,>=4 seats"; "infirmary>=3 tiles/patient
## bed,>=1 bed,>=1 shelf"; "pantry>=4 tiles,>=1 shelf".
const TILES_PER_BED: int = 3
const PRIVATE_ROOM_MIN_TILES: int = 6
const PRIVATE_ROOM_BEDS: int = 1
const TILES_PER_SEAT: int = 2
const DINING_MIN_SEATS: int = 4
const KITCHEN_MIN_TILES: int = 6
const COMMON_MIN_TILES: int = 8
const COMMON_MIN_SEATS: int = 4
const TILES_PER_PATIENT_BED: int = 3
const PANTRY_MIN_TILES: int = 4

const REFUSE_NONE: StringName = &""
const REFUSE_UNKNOWN_BUILDING_TYPE: StringName = &"UNKNOWN_BUILDING_TYPE"
const REFUSE_UNKNOWN_FURNITURE_TYPE: StringName = &"UNKNOWN_FURNITURE_TYPE"
const REFUSE_UNKNOWN_ROOM_TYPE: StringName = &"UNKNOWN_ROOM_TYPE"
const REFUSE_UNKNOWN_BUILDING_STATE: StringName = &"UNKNOWN_BUILDING_STATE"
const REFUSE_INVALID_TILE: StringName = &"INVALID_TILE"
const REFUSE_INVALID_ROTATION: StringName = &"INVALID_ROTATION"
const REFUSE_INVALID_TIER: StringName = &"INVALID_TIER"
const REFUSE_INVALID_CONDITION: StringName = &"INVALID_CONDITION"
const REFUSE_INVALID_INTERIOR_ID: StringName = &"INVALID_INTERIOR_ID"
const REFUSE_INVALID_OCCUPANTS: StringName = &"INVALID_OCCUPANTS"
const REFUSE_INVALID_TEMPERATURE: StringName = &"INVALID_TEMPERATURE"
const REFUSE_FOOTPRINT_OFF_GRID: StringName = &"FOOTPRINT_OFF_GRID"
const REFUSE_FOOTPRINT_OCCUPIED: StringName = &"FOOTPRINT_OCCUPIED"
const REFUSE_LOCKED_BY_MILESTONE: StringName = &"LOCKED_BY_MILESTONE"
const REFUSE_STALE_BUILDING_REF: StringName = &"STALE_BUILDING_REF"
const REFUSE_STALE_ROOM_REF: StringName = &"STALE_ROOM_REF"
const REFUSE_STALE_FURNITURE_REF: StringName = &"STALE_FURNITURE_REF"
const REFUSE_STALE_USER_REF: StringName = &"STALE_USER_REF"
const REFUSE_STALE_CONSTRUCTION_REF: StringName = &"STALE_CONSTRUCTION_REF"
const REFUSE_NOT_MANAGED_INTERIOR: StringName = &"NOT_MANAGED_INTERIOR"
const REFUSE_ROOM_LIMIT: StringName = &"ROOM_LIMIT_PER_BUILDING"
const REFUSE_EMPTY_TILE_LIST: StringName = &"EMPTY_TILE_LIST"
const REFUSE_DUPLICATE_TILE: StringName = &"DUPLICATE_TILE"
const REFUSE_TILE_OUTSIDE_INTERIOR: StringName = &"TILE_OUTSIDE_INTERIOR"
const REFUSE_TILE_IN_OTHER_ROOM: StringName = &"TILE_IN_OTHER_ROOM"
const REFUSE_TILE_LINK_ARENA_FULL: StringName = &"CAPACITY_ROOM_TILE_LINKS"
const REFUSE_TILE_NOT_IN_ROOM: StringName = &"TILE_NOT_IN_ROOM"
const REFUSE_FURNITURE_OVERLAP: StringName = &"FURNITURE_OVERLAP"
const REFUSE_BUILDING_HAS_ROOMS: StringName = &"BUILDING_HAS_ROOMS"
const REFUSE_ROOM_HAS_FURNITURE: StringName = &"ROOM_HAS_FURNITURE"
const REFUSE_FURNITURE_IN_USE: StringName = &"FURNITURE_IN_USE"
const REFUSE_NOT_A_PANTRY: StringName = &"NOT_A_PANTRY_ROOM"
const REFUSE_NOT_A_KITCHEN: StringName = &"NOT_A_KITCHEN_ROOM"
const REFUSE_ROOM_NOT_VALID: StringName = &"ROOM_NOT_VALID"
const REFUSE_UNKNOWN_STATION: StringName = &"UNKNOWN_STATION"
const REFUSE_MASK_MISMATCH: StringName = &"ROOM_FURNITURE_MASK_MISMATCH"
const REFUSE_SAME_ROOM: StringName = &"FURNITURE_ALREADY_IN_ROOM"
const REFUSE_DIFFERENT_BUILDING: StringName = &"DIFFERENT_BUILDING"


class OpResult:
	"""Outcome of one building/room/furniture operation: flag, refusal code, value, reference.

	`.ok` MUST be inspected before `.value` or `.ref`. A refusal carries value 0 and the null
	reference `(-1, 0)`, and never a partially applied effect: every mutator below validates
	completely before it writes a byte, so a refused call leaves this store and the directory
	exactly as they were (decision 0059, allocate before consume).
	"""
	var ok: bool
	var error: StringName
	var value: int
	var ref: Vector2i

	func _init(p_ok: bool, p_error: StringName, p_value: int, p_ref: Vector2i) -> void:
		"""Store the outcome fields for this operation."""
		ok = p_ok
		error = p_error
		value = p_value
		ref = p_ref


# --- collaborators ------------------------------------------------------------------------------

var _directory: EntityDirectory = null
var _owns_directory: bool = false
var _definitions: BuildingDefinitions = null

# --- Building columns (GDD §4.2, architecture §2.2) ---------------------------------------------

var _b_type_id: PackedInt32Array = PackedInt32Array()
var _b_tier: PackedInt32Array = PackedInt32Array()
var _b_origin_tile: PackedInt32Array = PackedInt32Array()
var _b_rotation: PackedInt32Array = PackedInt32Array()
var _b_state: PackedInt32Array = PackedInt32Array()
var _b_condition: PackedInt32Array = PackedInt32Array()
var _b_construction_slot: PackedInt32Array = PackedInt32Array()
var _b_construction_generation: PackedInt32Array = PackedInt32Array()
var _b_interior_id: PackedInt32Array = PackedInt32Array()

## Occupancy, the owning directory reference, and the per-building room chain.
var _b_present: PackedByteArray = PackedByteArray()
var _b_ref_slot: PackedInt32Array = PackedInt32Array()
var _b_ref_generation: PackedInt32Array = PackedInt32Array()
var _b_room_head: PackedInt32Array = PackedInt32Array()
var _b_room_count: PackedInt32Array = PackedInt32Array()

# --- Room columns (GDD §4.2, architecture §2.2) --------------------------------------------------

var _r_type: PackedInt32Array = PackedInt32Array()
var _r_building_slot: PackedInt32Array = PackedInt32Array()
var _r_building_generation: PackedInt32Array = PackedInt32Array()
var _r_tile_offset: PackedInt32Array = PackedInt32Array()
var _r_tile_count: PackedInt32Array = PackedInt32Array()
var _r_temperature_tenths: PackedInt32Array = PackedInt32Array()
var _r_furniture_mask: PackedInt32Array = PackedInt32Array()
var _r_occupants: PackedInt32Array = PackedInt32Array()
var _r_valid: PackedByteArray = PackedByteArray()

## Occupancy, the owning directory reference, the building chain links and the furniture chain.
var _r_present: PackedByteArray = PackedByteArray()
var _r_ref_slot: PackedInt32Array = PackedInt32Array()
var _r_ref_generation: PackedInt32Array = PackedInt32Array()
var _r_building_next: PackedInt32Array = PackedInt32Array()
var _r_building_prev: PackedInt32Array = PackedInt32Array()
var _r_furniture_head: PackedInt32Array = PackedInt32Array()
var _r_furniture_count: PackedInt32Array = PackedInt32Array()

# --- Furniture columns (GDD §4.2, architecture §2.2) ---------------------------------------------

var _f_type_id: PackedInt32Array = PackedInt32Array()
var _f_room_slot: PackedInt32Array = PackedInt32Array()
var _f_room_generation: PackedInt32Array = PackedInt32Array()
var _f_origin_tile: PackedInt32Array = PackedInt32Array()
var _f_rotation: PackedInt32Array = PackedInt32Array()
var _f_user_slot: PackedInt32Array = PackedInt32Array()
var _f_user_generation: PackedInt32Array = PackedInt32Array()
var _f_condition: PackedInt32Array = PackedInt32Array()

## Occupancy, the owning directory reference, and the room chain links.
var _f_present: PackedByteArray = PackedByteArray()
var _f_ref_slot: PackedInt32Array = PackedInt32Array()
var _f_ref_generation: PackedInt32Array = PackedInt32Array()
var _f_room_next: PackedInt32Array = PackedInt32Array()
var _f_room_prev: PackedInt32Array = PackedInt32Array()

# --- tile maps and the room-tile arena -----------------------------------------------------------

## `WorldTileMaps.building_slot` and `.room_slot` (architecture §3), plus a third tile map for
## furniture floor occupancy, which GDD §5.9's "furniture cannot overlap" needs and which no
## existing table carries.
var _building_slot: PackedInt32Array = PackedInt32Array()
var _room_slot: PackedInt32Array = PackedInt32Array()
var _furniture_slot: PackedInt32Array = PackedInt32Array()

## `RoomTileLinks.tile_id` (architecture §3): each room's tiles as a contiguous run at
## `tile_offset`, length `tile_count`. Runs are bump-allocated and the arena is COMPACTED when a
## room is removed, so the arena never fragments and no free-run table is allocated; every live
## room's `tile_offset` is corrected in the same call.
var _room_tile_id: PackedInt32Array = PackedInt32Array()

## Live per-kind furniture counts, so a HUD bed counter costs a lookup and not an 81920 scan.
var _f_kind_count: PackedInt32Array = PackedInt32Array()

var _b_live_count: int = 0
var _r_live_count: int = 0
var _f_live_count: int = 0
var _room_tile_used: int = 0


func _init(p_directory: EntityDirectory = null) -> void:
	"""Allocate every column once and adopt or build the directory behind every reference."""
	assert(BUILDING_CAPACITY == EntityDirectory.KIND_CAPACITY[EntityDirectory.KIND_BUILDING],
		"Building columns must match the directory's BUILDING row capacity")
	assert(ROOM_CAPACITY == EntityDirectory.KIND_CAPACITY[EntityDirectory.KIND_ROOM],
		"Room columns must match the directory's ROOM row capacity")
	assert(FURNITURE_CAPACITY == EntityDirectory.KIND_CAPACITY[EntityDirectory.KIND_FURNITURE],
		"Furniture columns must match the directory's FURNITURE row capacity")
	_owns_directory = p_directory == null
	_directory = p_directory if p_directory != null else EntityDirectory.new()
	_definitions = BuildingDefinitions.new()
	_assert_interiors()
	_allocate_columns()
	clear()


func _assert_interiors() -> void:
	"""Re-derive §4.1's room_tiles from §5.9's one-tile interior inset; refuse silent drift.

	Hall 12x10 -> 10x8 = 80, residence 10x8 -> 8x6 = 48, infirmary 8x8 -> 6x6 = 36. The inset is
	§5.9's own "Hall interior origin is exterior origin+(1,1)" read together with its three
	"Interior WxH" entries, and this assertion is what makes that reading checkable rather than
	assumed.
	"""
	for type_id: int in _definitions.building_count():
		if not _definitions.has_managed_interior(type_id):
			assert(_definitions.room_tiles_of(type_id) == 0,
				"BAL-CAT-007: a nonmanaged building must have room_tiles=0")
			continue
		var inner_x: int = _definitions.footprint_x_of(type_id) - 2 * INTERIOR_INSET_TILES
		var inner_z: int = _definitions.footprint_z_of(type_id) - 2 * INTERIOR_INSET_TILES
		assert(inner_x > 0 and inner_z > 0, "a managed interior must have a positive extent")
		assert(inner_x * inner_z == _definitions.room_tiles_of(type_id),
			"the inset interior must reproduce this definition's room_tiles")


func _allocate_columns() -> void:
	"""The only place that sizes a packed array (ARCH-MEM-005: allocate once, never per tick)."""
	_b_type_id.resize(BUILDING_CAPACITY)
	_b_tier.resize(BUILDING_CAPACITY)
	_b_origin_tile.resize(BUILDING_CAPACITY)
	_b_rotation.resize(BUILDING_CAPACITY)
	_b_state.resize(BUILDING_CAPACITY)
	_b_condition.resize(BUILDING_CAPACITY)
	_b_construction_slot.resize(BUILDING_CAPACITY)
	_b_construction_generation.resize(BUILDING_CAPACITY)
	_b_interior_id.resize(BUILDING_CAPACITY)
	_b_present.resize(BUILDING_CAPACITY)
	_b_ref_slot.resize(BUILDING_CAPACITY)
	_b_ref_generation.resize(BUILDING_CAPACITY)
	_b_room_head.resize(BUILDING_CAPACITY)
	_b_room_count.resize(BUILDING_CAPACITY)
	_allocate_room_columns()
	_allocate_furniture_columns()


func _allocate_room_columns() -> void:
	"""Size the Room columns, the room chain links and the three tile maps."""
	_r_type.resize(ROOM_CAPACITY)
	_r_building_slot.resize(ROOM_CAPACITY)
	_r_building_generation.resize(ROOM_CAPACITY)
	_r_tile_offset.resize(ROOM_CAPACITY)
	_r_tile_count.resize(ROOM_CAPACITY)
	_r_temperature_tenths.resize(ROOM_CAPACITY)
	_r_furniture_mask.resize(ROOM_CAPACITY)
	_r_occupants.resize(ROOM_CAPACITY)
	_r_valid.resize(ROOM_CAPACITY)
	_r_present.resize(ROOM_CAPACITY)
	_r_ref_slot.resize(ROOM_CAPACITY)
	_r_ref_generation.resize(ROOM_CAPACITY)
	_r_building_next.resize(ROOM_CAPACITY)
	_r_building_prev.resize(ROOM_CAPACITY)
	_r_furniture_head.resize(ROOM_CAPACITY)
	_r_furniture_count.resize(ROOM_CAPACITY)
	_building_slot.resize(TILE_COUNT)
	_room_slot.resize(TILE_COUNT)
	_furniture_slot.resize(TILE_COUNT)
	_room_tile_id.resize(ROOM_TILE_LINK_CAPACITY)


func _allocate_furniture_columns() -> void:
	"""Size the Furniture columns, its chain links and the per-kind live counters."""
	_f_type_id.resize(FURNITURE_CAPACITY)
	_f_room_slot.resize(FURNITURE_CAPACITY)
	_f_room_generation.resize(FURNITURE_CAPACITY)
	_f_origin_tile.resize(FURNITURE_CAPACITY)
	_f_rotation.resize(FURNITURE_CAPACITY)
	_f_user_slot.resize(FURNITURE_CAPACITY)
	_f_user_generation.resize(FURNITURE_CAPACITY)
	_f_condition.resize(FURNITURE_CAPACITY)
	_f_present.resize(FURNITURE_CAPACITY)
	_f_ref_slot.resize(FURNITURE_CAPACITY)
	_f_ref_generation.resize(FURNITURE_CAPACITY)
	_f_room_next.resize(FURNITURE_CAPACITY)
	_f_room_prev.resize(FURNITURE_CAPACITY)
	_f_kind_count.resize(FURNITURE_KIND_COUNT)


func clear() -> void:
	"""Return every column to its empty state without reallocating one of them."""
	_release_live_rows()
	_clear_building_columns()
	_clear_room_columns()
	_clear_furniture_columns()
	_building_slot.fill(NO_LINK)
	_room_slot.fill(NO_LINK)
	_furniture_slot.fill(NO_LINK)
	_room_tile_id.fill(NO_LINK)
	_f_kind_count.fill(0)
	_b_live_count = 0
	_r_live_count = 0
	_f_live_count = 0
	_room_tile_used = 0
	if _owns_directory:
		_directory.clear()


func _release_live_rows() -> void:
	"""Destroy every live row's directory slot, so a clear leaks no directory allocation."""
	for row: int in FURNITURE_CAPACITY:
		if _f_present[row] == 1:
			_directory.destroy(Vector2i(_f_ref_slot[row], _f_ref_generation[row]))
	for row: int in ROOM_CAPACITY:
		if _r_present[row] == 1:
			_directory.destroy(Vector2i(_r_ref_slot[row], _r_ref_generation[row]))
	for row: int in BUILDING_CAPACITY:
		if _b_present[row] == 1:
			_directory.destroy(Vector2i(_b_ref_slot[row], _b_ref_generation[row]))


func _clear_building_columns() -> void:
	"""Zero the Building columns and reset its references and room chain heads."""
	_b_type_id.fill(0)
	_b_tier.fill(0)
	_b_origin_tile.fill(NO_LINK)
	_b_rotation.fill(0)
	_b_state.fill(0)
	_b_condition.fill(0)
	_b_construction_slot.fill(EntityDirectory.NULL_SLOT)
	_b_construction_generation.fill(EntityDirectory.NULL_GENERATION)
	_b_interior_id.fill(NO_INTERIOR)
	_b_present.fill(0)
	_b_ref_slot.fill(EntityDirectory.NULL_SLOT)
	_b_ref_generation.fill(EntityDirectory.NULL_GENERATION)
	_b_room_head.fill(NO_LINK)
	_b_room_count.fill(0)


func _clear_room_columns() -> void:
	"""Zero the Room columns, its references and both of its chains."""
	_r_type.fill(0)
	_r_building_slot.fill(EntityDirectory.NULL_SLOT)
	_r_building_generation.fill(EntityDirectory.NULL_GENERATION)
	_r_tile_offset.fill(0)
	_r_tile_count.fill(0)
	_r_temperature_tenths.fill(0)
	_r_furniture_mask.fill(0)
	_r_occupants.fill(0)
	_r_valid.fill(0)
	_r_present.fill(0)
	_r_ref_slot.fill(EntityDirectory.NULL_SLOT)
	_r_ref_generation.fill(EntityDirectory.NULL_GENERATION)
	_r_building_next.fill(NO_LINK)
	_r_building_prev.fill(NO_LINK)
	_r_furniture_head.fill(NO_LINK)
	_r_furniture_count.fill(0)


func _clear_furniture_columns() -> void:
	"""Zero the Furniture columns, its references and its room chain links."""
	_f_type_id.fill(0)
	_f_room_slot.fill(EntityDirectory.NULL_SLOT)
	_f_room_generation.fill(EntityDirectory.NULL_GENERATION)
	_f_origin_tile.fill(NO_LINK)
	_f_rotation.fill(0)
	_f_user_slot.fill(EntityDirectory.NULL_SLOT)
	_f_user_generation.fill(EntityDirectory.NULL_GENERATION)
	_f_condition.fill(0)
	_f_present.fill(0)
	_f_ref_slot.fill(EntityDirectory.NULL_SLOT)
	_f_ref_generation.fill(EntityDirectory.NULL_GENERATION)
	_f_room_next.fill(NO_LINK)
	_f_room_prev.fill(NO_LINK)


func directory() -> EntityDirectory:
	"""The allocator behind every building, room and furniture reference."""
	return _directory


func definitions() -> BuildingDefinitions:
	"""The immutable §4.1-§4.3 catalog facts this store validates and measures against."""
	return _definitions


# --- exterior tile geometry -----------------------------------------------------------------------

func is_tile_index(tile: int) -> bool:
	"""True when `tile` addresses one of the 16384 exterior tiles (GDD §5.1 `z*128+x`)."""
	return tile >= 0 and tile < TILE_COUNT


func extent_x_of(size_x: int, size_z: int, rotation: int) -> int:
	"""The x extent of a `size_x` by `size_z` footprint at `rotation`, in tiles.

	§5.9's "rotation in 90 degree steps" makes odd rotations swap the two extents; this is the
	mechanical consequence of the stated rotation, not a chosen convention.
	"""
	return size_z if (rotation % 2) == 1 else size_x


func extent_z_of(size_x: int, size_z: int, rotation: int) -> int:
	"""The z extent of a `size_x` by `size_z` footprint at `rotation`, in tiles."""
	return size_x if (rotation % 2) == 1 else size_z


func _footprint_fits(origin_tile: int, extent_x: int, extent_z: int) -> bool:
	"""True when an axis-aligned extent placed at `origin_tile` stays inside the 128x128 grid."""
	if not is_tile_index(origin_tile) or extent_x <= 0 or extent_z <= 0:
		return false
	var origin_x: int = origin_tile % MAP_TILES_X
	var origin_z: int = origin_tile / MAP_TILES_X
	return origin_x + extent_x <= MAP_TILES_X and origin_z + extent_z <= MAP_TILES_Z


func _tile_at(origin_tile: int, offset_x: int, offset_z: int) -> int:
	"""The tile `offset_x`/`offset_z` tiles from `origin_tile`, assuming a checked footprint."""
	return origin_tile + offset_z * MAP_TILES_X + offset_x


# --- Building lifecycle ---------------------------------------------------------------------------

func place_building(type_id: int, origin_tile: int, rotation: int,
		unlocked_mask: int) -> OpResult:
	"""Publish one exterior structure as a BLUEPRINT, gated on its own earned milestone bit.

	`unlocked_mask` is the caller's `World.milestone_mask` / `Progress.unlocked_mask`; it is never
	defaulted, so an unbound Progress store places nothing (R-BUILD-DOM-001). Refuses -- writing
	nothing -- on an unknown type, an off-grid or overlapping footprint, a rotation outside 0-3,
	an illegal mask, or a definition whose unlock bit is not earned.
	"""
	var code: StringName = _refuse_place_building(type_id, origin_tile, rotation, unlocked_mask)
	if code != REFUSE_NONE:
		return _refuse(code)
	var ref: Vector2i = _directory.create(EntityDirectory.KIND_BUILDING)
	if ref == NULL_REF:
		return _refuse(_directory.last_refusal())
	var row: int = _directory.get_typed_row(ref)
	_write_building_row(row, ref, type_id, origin_tile, rotation)
	_stamp_footprint(row, type_id, origin_tile, rotation)
	_b_live_count += 1
	return OpResult.new(true, REFUSE_NONE, row, ref)


func _refuse_place_building(type_id: int, origin_tile: int, rotation: int,
		unlocked_mask: int) -> StringName:
	"""The code blocking a placement, or REFUSE_NONE when every argument is storable."""
	if not _definitions.is_building_id(type_id):
		return REFUSE_UNKNOWN_BUILDING_TYPE
	if rotation < 0 or rotation >= ROTATION_COUNT:
		return REFUSE_INVALID_ROTATION
	var mask_code: StringName = Milestones.validate_mask(unlocked_mask)
	if mask_code != Milestones.REFUSE_NONE:
		return mask_code
	if not Milestones.is_unlocked(unlocked_mask, _definitions.unlock_of(type_id)):
		return REFUSE_LOCKED_BY_MILESTONE
	return _refuse_footprint(type_id, origin_tile, rotation)


func _refuse_footprint(type_id: int, origin_tile: int, rotation: int) -> StringName:
	"""REQ-SET-122's tile half: in-bounds and nonoverlapping. Terrain conditions are not read."""
	var size_x: int = _definitions.footprint_x_of(type_id)
	var size_z: int = _definitions.footprint_z_of(type_id)
	var extent_x: int = extent_x_of(size_x, size_z, rotation)
	var extent_z: int = extent_z_of(size_x, size_z, rotation)
	if not _footprint_fits(origin_tile, extent_x, extent_z):
		return REFUSE_FOOTPRINT_OFF_GRID
	for offset_z: int in extent_z:
		for offset_x: int in extent_x:
			if _building_slot[_tile_at(origin_tile, offset_x, offset_z)] != NO_LINK:
				return REFUSE_FOOTPRINT_OCCUPIED
	return REFUSE_NONE


func _write_building_row(row: int, ref: Vector2i, type_id: int, origin_tile: int,
		rotation: int) -> void:
	"""Initialize every Building column of a freshly allocated row before it is published."""
	_b_type_id[row] = type_id
	_b_tier[row] = BuildingDefinitions.MIN_TIER
	_b_origin_tile[row] = origin_tile
	_b_rotation[row] = rotation
	_b_state[row] = STATE_BLUEPRINT
	_b_condition[row] = 0
	_b_construction_slot[row] = EntityDirectory.NULL_SLOT
	_b_construction_generation[row] = EntityDirectory.NULL_GENERATION
	_b_interior_id[row] = NO_INTERIOR
	_b_present[row] = 1
	_b_ref_slot[row] = ref.x
	_b_ref_generation[row] = ref.y
	_b_room_head[row] = NO_LINK
	_b_room_count[row] = 0


func _stamp_footprint(row: int, type_id: int, origin_tile: int, rotation: int) -> void:
	"""Write `WorldTileMaps.building_slot` for every tile this structure occupies."""
	var size_x: int = _definitions.footprint_x_of(type_id)
	var size_z: int = _definitions.footprint_z_of(type_id)
	var extent_x: int = extent_x_of(size_x, size_z, rotation)
	var extent_z: int = extent_z_of(size_x, size_z, rotation)
	for offset_z: int in extent_z:
		for offset_x: int in extent_x:
			_building_slot[_tile_at(origin_tile, offset_x, offset_z)] = row


func _clear_footprint(row: int) -> void:
	"""Release every `building_slot` tile this structure holds, the inverse of `_stamp_footprint`."""
	var type_id: int = _b_type_id[row]
	var origin_tile: int = _b_origin_tile[row]
	var rotation: int = _b_rotation[row]
	var size_x: int = _definitions.footprint_x_of(type_id)
	var size_z: int = _definitions.footprint_z_of(type_id)
	for offset_z: int in extent_z_of(size_x, size_z, rotation):
		for offset_x: int in extent_x_of(size_x, size_z, rotation):
			_building_slot[_tile_at(origin_tile, offset_x, offset_z)] = NO_LINK


func demolish_building(building_ref: Vector2i) -> OpResult:
	"""Remove one exterior structure and release its tiles and directory slot.

	REFUSES while the building still owns rooms. Cascading would destroy room and furniture rows
	the caller never named, and task 06.2's "Refuse occupied/only-exit destructive edits" is the
	contract that will decide demolition of an occupied structure; removing its rooms first is
	explicit and leaves every collaborating store byte-identical on refusal.
	"""
	var row: int = _building_row_of(building_ref)
	if row == NO_ROW:
		return _refuse(REFUSE_STALE_BUILDING_REF)
	if _b_room_count[row] != 0:
		return _refuse(REFUSE_BUILDING_HAS_ROOMS)
	_clear_footprint(row)
	_b_present[row] = 0
	_b_ref_slot[row] = EntityDirectory.NULL_SLOT
	_b_ref_generation[row] = EntityDirectory.NULL_GENERATION
	_b_live_count -= 1
	_directory.destroy(building_ref)
	return OpResult.new(true, REFUSE_NONE, row, NULL_REF)


# --- Building accessors and setters ---------------------------------------------------------------

func _building_row_of(building_ref: Vector2i) -> int:
	"""The typed row a live building reference names, or NO_ROW. Internal; never returned raw."""
	if not _directory.is_valid_of_kind(building_ref, EntityDirectory.KIND_BUILDING):
		return NO_ROW
	var row: int = _directory.get_typed_row(building_ref)
	if row < 0 or row >= BUILDING_CAPACITY or _b_present[row] != 1:
		return NO_ROW
	if _b_ref_slot[row] != building_ref.x or _b_ref_generation[row] != building_ref.y:
		return NO_ROW
	return row


func building_ref_of_row(row: int) -> Vector2i:
	"""The reference a live building row hands back, or the GDD null reference `(-1, 0)`."""
	if row < 0 or row >= BUILDING_CAPACITY or _b_present[row] != 1:
		return NULL_REF
	return Vector2i(_b_ref_slot[row], _b_ref_generation[row])


func is_live_building(building_ref: Vector2i) -> bool:
	"""True when `building_ref` still names a live row of this store."""
	return _building_row_of(building_ref) != NO_ROW


func _building_field(building_ref: Vector2i, column: PackedInt32Array) -> OpResult:
	"""One Building column's value for a live reference, or a stale-reference refusal.

	Taking the column as an argument keeps eight one-line accessors from repeating the same
	validation; each public reader below names its own column and nothing outside this file can
	reach a column array.
	"""
	var row: int = _building_row_of(building_ref)
	if row == NO_ROW:
		return _refuse(REFUSE_STALE_BUILDING_REF)
	return OpResult.new(true, REFUSE_NONE, column[row], building_ref)


func type_id_of_building(building_ref: Vector2i) -> OpResult:
	"""`Building.type_id`: a compiled BuildingDefinition id."""
	return _building_field(building_ref, _b_type_id)


func tier_of_building(building_ref: Vector2i) -> OpResult:
	"""`Building.tier`: 1, or 2 for the four keys BAL-CAT-006 allows to upgrade."""
	return _building_field(building_ref, _b_tier)


func state_of_building(building_ref: Vector2i) -> OpResult:
	"""`Building.state`: a protected §4.3 BuildingState ordinal."""
	return _building_field(building_ref, _b_state)


func condition_of_building(building_ref: Vector2i) -> OpResult:
	"""`Building.condition`: an int32 whose SCALE no document states (see the module header)."""
	return _building_field(building_ref, _b_condition)


func origin_tile_of_building(building_ref: Vector2i) -> OpResult:
	"""`Building.origin_tile`: the exterior tile its footprint starts at."""
	return _building_field(building_ref, _b_origin_tile)


func rotation_of_building(building_ref: Vector2i) -> OpResult:
	"""`Building.rotation`: 0-3, in 90 degree steps."""
	return _building_field(building_ref, _b_rotation)


func interior_id_of_building(building_ref: Vector2i) -> OpResult:
	"""`Building.interior_id`, or -1 when no indoor kit is bound. Domain unstated; see header."""
	return _building_field(building_ref, _b_interior_id)


func construction_ref_of_building(building_ref: Vector2i) -> Vector2i:
	"""`Building.construction`, or the null reference when no project is bound."""
	var row: int = _building_row_of(building_ref)
	if row == NO_ROW:
		return NULL_REF
	return Vector2i(_b_construction_slot[row], _b_construction_generation[row])


func set_building_state(building_ref: Vector2i, state: int) -> OpResult:
	"""Move a building to another §4.3 BuildingState. Refuses an ordinal outside 0-5."""
	var row: int = _building_row_of(building_ref)
	if row == NO_ROW:
		return _refuse(REFUSE_STALE_BUILDING_REF)
	if state < 0 or state >= STATE_COUNT:
		return _refuse(REFUSE_UNKNOWN_BUILDING_STATE)
	_b_state[row] = state
	return OpResult.new(true, REFUSE_NONE, state, building_ref)


func set_building_tier(building_ref: Vector2i, tier: int) -> OpResult:
	"""Set `Building.tier`. Refuses tier 2 for any definition §4.2's upgrade table omits."""
	var row: int = _building_row_of(building_ref)
	if row == NO_ROW:
		return _refuse(REFUSE_STALE_BUILDING_REF)
	if not _definitions.accepts_tier(_b_type_id[row], tier):
		return _refuse(REFUSE_INVALID_TIER)
	_b_tier[row] = tier
	return OpResult.new(true, REFUSE_NONE, tier, building_ref)


func set_building_condition(building_ref: Vector2i, condition: int) -> OpResult:
	"""Set `Building.condition`. Refuses a negative value or one outside int32.

	No maximum is enforced because no document states one; the header records that blocker.
	"""
	var row: int = _building_row_of(building_ref)
	if row == NO_ROW:
		return _refuse(REFUSE_STALE_BUILDING_REF)
	if condition < 0 or condition > INT32_MAX:
		return _refuse(REFUSE_INVALID_CONDITION)
	_b_condition[row] = condition
	return OpResult.new(true, REFUSE_NONE, condition, building_ref)


func set_building_interior_id(building_ref: Vector2i, interior_id: int) -> OpResult:
	"""Set `Building.interior_id`. Accepts -1 (none, GDD §4.2) or any non-negative int32."""
	var row: int = _building_row_of(building_ref)
	if row == NO_ROW:
		return _refuse(REFUSE_STALE_BUILDING_REF)
	if interior_id < NO_INTERIOR or interior_id > INT32_MAX:
		return _refuse(REFUSE_INVALID_INTERIOR_ID)
	_b_interior_id[row] = interior_id
	return OpResult.new(true, REFUSE_NONE, interior_id, building_ref)


func set_building_construction(building_ref: Vector2i, construction_ref: Vector2i) -> OpResult:
	"""Bind or clear `Building.construction`. The null reference clears it.

	A non-null reference must be a live KIND_CONSTRUCTION row of the shared directory. No
	Construction store exists yet, so the directory is the only thing that can attest it.
	"""
	var row: int = _building_row_of(building_ref)
	if row == NO_ROW:
		return _refuse(REFUSE_STALE_BUILDING_REF)
	if construction_ref != NULL_REF and not _directory.is_valid_of_kind(
			construction_ref, EntityDirectory.KIND_CONSTRUCTION):
		return _refuse(REFUSE_STALE_CONSTRUCTION_REF)
	_b_construction_slot[row] = construction_ref.x
	_b_construction_generation[row] = construction_ref.y
	return OpResult.new(true, REFUSE_NONE, construction_ref.x, building_ref)


func building_at_tile(tile: int) -> Vector2i:
	"""The structure standing on an exterior tile, or the null reference when none does."""
	if not is_tile_index(tile) or _building_slot[tile] == NO_LINK:
		return NULL_REF
	return building_ref_of_row(_building_slot[tile])


func live_building_count() -> int:
	"""How many exterior structures are live."""
	return _b_live_count


# --- Room lifecycle -------------------------------------------------------------------------------

func designate_room(building_ref: Vector2i, room_type: int, tiles: PackedInt32Array) -> OpResult:
	"""Publish one Room over a set of interior tiles of a managed building.

	Every tile must lie inside that building's interior rectangle (its footprint inset by one
	tile, §5.9) and belong to no other room: GDD §5.9's "One tile belongs to exactly one room".
	Refuses -- writing nothing -- on a stale building, a nonmanaged building, the 17th room, an
	unknown room type, an empty or duplicated tile list, an outside or already-owned tile, or a
	full RoomTileLinks arena.
	"""
	var building_row: int = _building_row_of(building_ref)
	if building_row == NO_ROW:
		return _refuse(REFUSE_STALE_BUILDING_REF)
	var code: StringName = _refuse_designate_room(building_row, room_type, tiles)
	if code != REFUSE_NONE:
		return _refuse(code)
	var ref: Vector2i = _directory.create(EntityDirectory.KIND_ROOM)
	if ref == NULL_REF:
		return _refuse(_directory.last_refusal())
	var row: int = _directory.get_typed_row(ref)
	_write_room_row(row, ref, building_ref, room_type, tiles)
	_link_room(building_row, row)
	_r_live_count += 1
	return OpResult.new(true, REFUSE_NONE, row, ref)


func _refuse_designate_room(building_row: int, room_type: int,
		tiles: PackedInt32Array) -> StringName:
	"""The code blocking a designation, or REFUSE_NONE when every argument is storable."""
	if room_type < 0 or room_type >= ROOM_TYPE_COUNT:
		return REFUSE_UNKNOWN_ROOM_TYPE
	if not _definitions.has_managed_interior(_b_type_id[building_row]):
		return REFUSE_NOT_MANAGED_INTERIOR
	if _b_room_count[building_row] >= MAX_ROOMS_PER_BUILDING:
		return REFUSE_ROOM_LIMIT
	if tiles.is_empty():
		return REFUSE_EMPTY_TILE_LIST
	if _room_tile_used + tiles.size() > ROOM_TILE_LINK_CAPACITY:
		return REFUSE_TILE_LINK_ARENA_FULL
	return _refuse_room_tiles(building_row, tiles)


func _refuse_room_tiles(building_row: int, tiles: PackedInt32Array) -> StringName:
	"""Every tile must be interior to this building, unowned, and named at most once."""
	var seen: Dictionary = {}
	for index: int in tiles.size():
		var tile: int = tiles[index]
		if not is_tile_index(tile):
			return REFUSE_INVALID_TILE
		if seen.has(tile):
			return REFUSE_DUPLICATE_TILE
		seen[tile] = true
		if not _is_interior_tile(building_row, tile):
			return REFUSE_TILE_OUTSIDE_INTERIOR
		if _room_slot[tile] != NO_LINK:
			return REFUSE_TILE_IN_OTHER_ROOM
	return REFUSE_NONE


func _is_interior_tile(building_row: int, tile: int) -> bool:
	"""True when `tile` lies in this building's interior rectangle: its footprint inset by one."""
	var type_id: int = _b_type_id[building_row]
	var rotation: int = _b_rotation[building_row]
	var size_x: int = _definitions.footprint_x_of(type_id)
	var size_z: int = _definitions.footprint_z_of(type_id)
	var origin_tile: int = _b_origin_tile[building_row]
	var min_x: int = origin_tile % MAP_TILES_X + INTERIOR_INSET_TILES
	var min_z: int = origin_tile / MAP_TILES_X + INTERIOR_INSET_TILES
	var inner_x: int = extent_x_of(size_x, size_z, rotation) - 2 * INTERIOR_INSET_TILES
	var inner_z: int = extent_z_of(size_x, size_z, rotation) - 2 * INTERIOR_INSET_TILES
	var tile_x: int = tile % MAP_TILES_X
	var tile_z: int = tile / MAP_TILES_X
	return (tile_x >= min_x and tile_x < min_x + inner_x
		and tile_z >= min_z and tile_z < min_z + inner_z)


func _write_room_row(row: int, ref: Vector2i, building_ref: Vector2i, room_type: int,
		tiles: PackedInt32Array) -> void:
	"""Initialize every Room column, claim its tiles in both the arena and the tile map."""
	_r_type[row] = room_type
	_r_building_slot[row] = building_ref.x
	_r_building_generation[row] = building_ref.y
	_r_tile_offset[row] = _room_tile_used
	_r_tile_count[row] = tiles.size()
	_r_temperature_tenths[row] = 0
	_r_furniture_mask[row] = 0
	_r_occupants[row] = 0
	_r_valid[row] = 0
	_r_present[row] = 1
	_r_ref_slot[row] = ref.x
	_r_ref_generation[row] = ref.y
	_r_furniture_head[row] = NO_LINK
	_r_furniture_count[row] = 0
	for index: int in tiles.size():
		_room_tile_id[_room_tile_used + index] = tiles[index]
		_room_slot[tiles[index]] = row
	_room_tile_used += tiles.size()


func remove_room(room_ref: Vector2i) -> OpResult:
	"""Remove one Room, release its tiles and compact the RoomTileLinks arena.

	REFUSES while the room still holds furniture: a furniture row whose owning room vanished
	would keep a reference that resolves to nothing, and R-BUILD-DOM-003 requires membership and
	mask to move together. Remove or reassign the furniture first.
	"""
	var row: int = _room_row_of(room_ref)
	if row == NO_ROW:
		return _refuse(REFUSE_STALE_ROOM_REF)
	if _r_furniture_count[row] != 0:
		return _refuse(REFUSE_ROOM_HAS_FURNITURE)
	var building_row: int = _building_row_of(
		Vector2i(_r_building_slot[row], _r_building_generation[row]))
	if building_row != NO_ROW:
		_unlink_room(building_row, row)
	_r_present[row] = 0
	_release_room_tiles(row)
	_r_furniture_mask[row] = 0
	_r_valid[row] = 0
	_r_ref_slot[row] = EntityDirectory.NULL_SLOT
	_r_ref_generation[row] = EntityDirectory.NULL_GENERATION
	_r_live_count -= 1
	_directory.destroy(room_ref)
	return OpResult.new(true, REFUSE_NONE, row, NULL_REF)


func _release_room_tiles(row: int) -> void:
	"""Clear a room's tile-map entries and compact its run out of the RoomTileLinks arena."""
	var offset: int = _r_tile_offset[row]
	var count: int = _r_tile_count[row]
	for index: int in count:
		_room_slot[_room_tile_id[offset + index]] = NO_LINK
	for index: int in range(offset, _room_tile_used - count):
		_room_tile_id[index] = _room_tile_id[index + count]
	for index: int in range(_room_tile_used - count, _room_tile_used):
		_room_tile_id[index] = NO_LINK
	_room_tile_used -= count
	_r_tile_offset[row] = 0
	_r_tile_count[row] = 0
	for other: int in ROOM_CAPACITY:
		if _r_present[other] == 1 and _r_tile_offset[other] > offset:
			_r_tile_offset[other] -= count


func _link_room(building_row: int, room_row: int) -> void:
	"""Push a room onto the head of its building's intrusive room chain."""
	var head: int = _b_room_head[building_row]
	_r_building_next[room_row] = head
	_r_building_prev[room_row] = NO_LINK
	if head != NO_LINK:
		_r_building_prev[head] = room_row
	_b_room_head[building_row] = room_row
	_b_room_count[building_row] += 1


func _unlink_room(building_row: int, room_row: int) -> void:
	"""Detach a room from its building's chain, repairing both neighbours and the head."""
	var previous: int = _r_building_prev[room_row]
	var following: int = _r_building_next[room_row]
	if previous == NO_LINK:
		_b_room_head[building_row] = following
	else:
		_r_building_next[previous] = following
	if following != NO_LINK:
		_r_building_prev[following] = previous
	_r_building_next[room_row] = NO_LINK
	_r_building_prev[room_row] = NO_LINK
	_b_room_count[building_row] -= 1


# --- Room accessors and setters -------------------------------------------------------------------

func _room_row_of(room_ref: Vector2i) -> int:
	"""The typed row a live room reference names, or NO_ROW. Internal; never returned raw."""
	if not _directory.is_valid_of_kind(room_ref, EntityDirectory.KIND_ROOM):
		return NO_ROW
	var row: int = _directory.get_typed_row(room_ref)
	if row < 0 or row >= ROOM_CAPACITY or _r_present[row] != 1:
		return NO_ROW
	if _r_ref_slot[row] != room_ref.x or _r_ref_generation[row] != room_ref.y:
		return NO_ROW
	return row


func room_ref_of_row(row: int) -> Vector2i:
	"""The reference a live room row hands back, or the GDD null reference `(-1, 0)`."""
	if row < 0 or row >= ROOM_CAPACITY or _r_present[row] != 1:
		return NULL_REF
	return Vector2i(_r_ref_slot[row], _r_ref_generation[row])


func is_live_room(room_ref: Vector2i) -> bool:
	"""True when `room_ref` still names a live row of this store."""
	return _room_row_of(room_ref) != NO_ROW


func _room_field(room_ref: Vector2i, column: PackedInt32Array) -> OpResult:
	"""One Room column's value for a live reference, or a stale-reference refusal."""
	var row: int = _room_row_of(room_ref)
	if row == NO_ROW:
		return _refuse(REFUSE_STALE_ROOM_REF)
	return OpResult.new(true, REFUSE_NONE, column[row], room_ref)


func type_of_room(room_ref: Vector2i) -> OpResult:
	"""`Room.type`: a protected §4.3 RoomType ordinal."""
	return _room_field(room_ref, _r_type)


func tile_count_of_room(room_ref: Vector2i) -> OpResult:
	"""`Room.tile_count`: how many interior tiles this room owns."""
	return _room_field(room_ref, _r_tile_count)


func tile_offset_of_room(room_ref: Vector2i) -> OpResult:
	"""`Room.tile_offset`: where this room's run starts in the RoomTileLinks arena."""
	return _room_field(room_ref, _r_tile_offset)


func occupants_of_room(room_ref: Vector2i) -> OpResult:
	"""`Room.occupants`: GDD §5.9's authoritative occupancy count."""
	return _room_field(room_ref, _r_occupants)


func temperature_tenths_of_room(room_ref: Vector2i) -> OpResult:
	"""`Room.temperature_tenths`. ARCH-SYS-016 RoomHeat owns what writes it; this store stores it."""
	return _room_field(room_ref, _r_temperature_tenths)


func furniture_mask_of(room_ref: Vector2i) -> OpResult:
	"""`Room.furniture_mask`: the OR of `1 << FurnitureDefinition id` over this room's live rows.

	PRESENCE ONLY (R-BUILD-DOM-003). It proves that at least one row of each set kind references
	this exact room generation. It proves nothing about counts, capacity, comfort, heat,
	connectivity or whether any of those rows can actually be used.
	"""
	return _room_field(room_ref, _r_furniture_mask)


func room_building_ref_of(room_ref: Vector2i) -> Vector2i:
	"""`Room.building`: the exterior structure that owns this room, or the null reference."""
	var row: int = _room_row_of(room_ref)
	if row == NO_ROW:
		return NULL_REF
	return Vector2i(_r_building_slot[row], _r_building_generation[row])


func room_is_valid(room_ref: Vector2i) -> bool:
	"""`Room.valid`. False for a stale reference, which is also the safe reading of "unknown"."""
	var row: int = _room_row_of(room_ref)
	return row != NO_ROW and _r_valid[row] == 1


func set_room_valid(room_ref: Vector2i, valid: bool) -> OpResult:
	"""Set `Room.valid`. The owning validity system calls this; counting alone never does.

	§5.9's list mixes countable rules with topological ones (connected access, enclosure,
	exterior links, heated). `room_meets_countable_rules()` answers the first half only, so this
	setter takes the answer rather than computing it from evidence it does not have.
	"""
	var row: int = _room_row_of(room_ref)
	if row == NO_ROW:
		return _refuse(REFUSE_STALE_ROOM_REF)
	_r_valid[row] = 1 if valid else 0
	return OpResult.new(true, REFUSE_NONE, _r_valid[row], room_ref)


func set_room_occupants(room_ref: Vector2i, occupants: int) -> OpResult:
	"""Set `Room.occupants`. Refuses a negative count or one above the 256 living population cap."""
	var row: int = _room_row_of(room_ref)
	if row == NO_ROW:
		return _refuse(REFUSE_STALE_ROOM_REF)
	if occupants < 0 or occupants > EntityDirectory.RESIDENT_LIVING_CAP:
		return _refuse(REFUSE_INVALID_OCCUPANTS)
	_r_occupants[row] = occupants
	return OpResult.new(true, REFUSE_NONE, occupants, room_ref)


func set_room_temperature_tenths(room_ref: Vector2i, tenths: int) -> OpResult:
	"""Set `Room.temperature_tenths`. Refuses a value outside int32; negatives are legal cold."""
	var row: int = _room_row_of(room_ref)
	if row == NO_ROW:
		return _refuse(REFUSE_STALE_ROOM_REF)
	if tenths < INT32_MIN or tenths > INT32_MAX:
		return _refuse(REFUSE_INVALID_TEMPERATURE)
	_r_temperature_tenths[row] = tenths
	return OpResult.new(true, REFUSE_NONE, tenths, room_ref)


func room_at_tile(tile: int) -> Vector2i:
	"""The room owning an interior tile, or the null reference when none does."""
	if not is_tile_index(tile) or _room_slot[tile] == NO_LINK:
		return NULL_REF
	return room_ref_of_row(_room_slot[tile])


func room_tile_at(room_ref: Vector2i, index: int) -> OpResult:
	"""The `index`-th tile of a room's RoomTileLinks run, or a refusal for an out-of-range index."""
	var row: int = _room_row_of(room_ref)
	if row == NO_ROW:
		return _refuse(REFUSE_STALE_ROOM_REF)
	if index < 0 or index >= _r_tile_count[row]:
		return _refuse(REFUSE_INVALID_TILE)
	return OpResult.new(true, REFUSE_NONE, _room_tile_id[_r_tile_offset[row] + index], room_ref)


func rooms_of_building(building_ref: Vector2i) -> PackedInt32Array:
	"""Every live room row of one building, in chain order. Cold path; allocates its result."""
	var rows: PackedInt32Array = PackedInt32Array()
	var building_row: int = _building_row_of(building_ref)
	if building_row == NO_ROW:
		return rows
	var row: int = _b_room_head[building_row]
	while row != NO_LINK:
		rows.append(row)
		row = _r_building_next[row]
	return rows


func room_count_of_building(building_ref: Vector2i) -> OpResult:
	"""How many rooms one building owns, 0-16."""
	var building_row: int = _building_row_of(building_ref)
	if building_row == NO_ROW:
		return _refuse(REFUSE_STALE_BUILDING_REF)
	return OpResult.new(true, REFUSE_NONE, _b_room_count[building_row], building_ref)


func live_room_count() -> int:
	"""How many rooms are live."""
	return _r_live_count


func room_tile_links_used() -> int:
	"""How many of the 16384 RoomTileLinks entries are in use."""
	return _room_tile_used


# --- Furniture lifecycle --------------------------------------------------------------------------

func place_furniture(room_ref: Vector2i, type_id: int, origin_tile: int,
		rotation: int) -> OpResult:
	"""Publish one committed Furniture row into a room and fold its bit into that room's mask.

	This store has no uncommitted rows: the call either publishes a row -- which immediately
	contributes its presence bit, per R-BUILD-DOM-003 -- or refuses and writes nothing. Refuses
	on a stale room, an unknown furniture type, a rotation outside 0-3, a tile outside the room,
	or a floor footprint overlapping other furniture.
	"""
	var room_row: int = _room_row_of(room_ref)
	if room_row == NO_ROW:
		return _refuse(REFUSE_STALE_ROOM_REF)
	var code: StringName = _refuse_place_furniture(room_row, type_id, origin_tile, rotation)
	if code != REFUSE_NONE:
		return _refuse(code)
	var ref: Vector2i = _directory.create(EntityDirectory.KIND_FURNITURE)
	if ref == NULL_REF:
		return _refuse(_directory.last_refusal())
	var row: int = _directory.get_typed_row(ref)
	_write_furniture_row(row, ref, room_ref, type_id, origin_tile, rotation)
	_link_furniture(room_row, row)
	_stamp_furniture_tiles(row, row)
	_f_kind_count[type_id] += 1
	_f_live_count += 1
	_r_furniture_mask[room_row] = _recompute_mask_row(room_row)
	return OpResult.new(true, REFUSE_NONE, row, ref)


func _refuse_place_furniture(room_row: int, type_id: int, origin_tile: int,
		rotation: int) -> StringName:
	"""The code blocking a furniture placement, or REFUSE_NONE when every argument is storable."""
	if not _definitions.is_furniture_id(type_id):
		return REFUSE_UNKNOWN_FURNITURE_TYPE
	if rotation < 0 or rotation >= ROTATION_COUNT:
		return REFUSE_INVALID_ROTATION
	if not is_tile_index(origin_tile) or _room_slot[origin_tile] != room_row:
		return REFUSE_TILE_NOT_IN_ROOM
	if _definitions.is_edge_furniture(type_id):
		return REFUSE_NONE
	return _refuse_furniture_footprint(room_row, type_id, origin_tile, rotation)


func _refuse_furniture_footprint(room_row: int, type_id: int, origin_tile: int,
		rotation: int) -> StringName:
	"""Every floor tile of a furniture footprint must be in this room and hold no other piece."""
	var size_x: int = _definitions.floor_x_of(type_id)
	var size_z: int = _definitions.floor_z_of(type_id)
	var extent_x: int = extent_x_of(size_x, size_z, rotation)
	var extent_z: int = extent_z_of(size_x, size_z, rotation)
	if not _footprint_fits(origin_tile, extent_x, extent_z):
		return REFUSE_FOOTPRINT_OFF_GRID
	for offset_z: int in extent_z:
		for offset_x: int in extent_x:
			var tile: int = _tile_at(origin_tile, offset_x, offset_z)
			if _room_slot[tile] != room_row:
				return REFUSE_TILE_NOT_IN_ROOM
			if _furniture_slot[tile] != NO_LINK:
				return REFUSE_FURNITURE_OVERLAP
	return REFUSE_NONE


func _write_furniture_row(row: int, ref: Vector2i, room_ref: Vector2i, type_id: int,
		origin_tile: int, rotation: int) -> void:
	"""Initialize every Furniture column of a freshly allocated row before it is published."""
	_f_type_id[row] = type_id
	_f_room_slot[row] = room_ref.x
	_f_room_generation[row] = room_ref.y
	_f_origin_tile[row] = origin_tile
	_f_rotation[row] = rotation
	_f_user_slot[row] = EntityDirectory.NULL_SLOT
	_f_user_generation[row] = EntityDirectory.NULL_GENERATION
	_f_condition[row] = 0
	_f_present[row] = 1
	_f_ref_slot[row] = ref.x
	_f_ref_generation[row] = ref.y


func _stamp_furniture_tiles(row: int, value: int) -> void:
	"""Write `value` into `_furniture_slot` for every floor tile this piece occupies.

	Edge furniture occupies no floor tile (§4.3's "0/0 means edge placement"), so its loop runs
	zero times and it never claims a tile another piece could want.
	"""
	var type_id: int = _f_type_id[row]
	var rotation: int = _f_rotation[row]
	var origin_tile: int = _f_origin_tile[row]
	var size_x: int = _definitions.floor_x_of(type_id)
	var size_z: int = _definitions.floor_z_of(type_id)
	for offset_z: int in extent_z_of(size_x, size_z, rotation):
		for offset_x: int in extent_x_of(size_x, size_z, rotation):
			_furniture_slot[_tile_at(origin_tile, offset_x, offset_z)] = value


func remove_furniture(furniture_ref: Vector2i) -> OpResult:
	"""Remove one Furniture row and recompute its room's mask in the same call.

	REFUSES while a resident still occupies it: `Furniture.user` is a live reference and dropping
	the row would strand it. R-BUILD-DOM-003's removal rule is enforced by recomputing the mask
	from the room's remaining rows -- removing one of two beds leaves bit 1 set, and removing the
	last one clears it, without either case being special-cased.
	"""
	var row: int = _furniture_row_of(furniture_ref)
	if row == NO_ROW:
		return _refuse(REFUSE_STALE_FURNITURE_REF)
	if _f_user_slot[row] != EntityDirectory.NULL_SLOT:
		return _refuse(REFUSE_FURNITURE_IN_USE)
	var room_row: int = _room_row_of(Vector2i(_f_room_slot[row], _f_room_generation[row]))
	_stamp_furniture_tiles(row, NO_LINK)
	if room_row != NO_ROW:
		_unlink_furniture(room_row, row)
	_f_kind_count[_f_type_id[row]] -= 1
	_f_present[row] = 0
	_f_ref_slot[row] = EntityDirectory.NULL_SLOT
	_f_ref_generation[row] = EntityDirectory.NULL_GENERATION
	_f_live_count -= 1
	_directory.destroy(furniture_ref)
	if room_row != NO_ROW:
		_r_furniture_mask[room_row] = _recompute_mask_row(room_row)
	return OpResult.new(true, REFUSE_NONE, row, NULL_REF)


func reassign_furniture(furniture_ref: Vector2i, room_ref: Vector2i) -> OpResult:
	"""Move one committed Furniture row to another room, updating BOTH masks atomically.

	The piece keeps its identity, its condition and its row; only its owning room changes. The
	source room's mask is recomputed from what remains and the destination's from what it gains,
	in one call, so no observer can see the piece in two rooms or in neither.
	"""
	var row: int = _furniture_row_of(furniture_ref)
	if row == NO_ROW:
		return _refuse(REFUSE_STALE_FURNITURE_REF)
	var target_row: int = _room_row_of(room_ref)
	if target_row == NO_ROW:
		return _refuse(REFUSE_STALE_ROOM_REF)
	var source_row: int = _room_row_of(Vector2i(_f_room_slot[row], _f_room_generation[row]))
	if source_row == target_row:
		return _refuse(REFUSE_SAME_ROOM)
	var code: StringName = _refuse_reassign(row, source_row, target_row)
	if code != REFUSE_NONE:
		return _refuse(code)
	_apply_reassign(row, source_row, target_row, room_ref)
	return OpResult.new(true, REFUSE_NONE, row, furniture_ref)


func _refuse_reassign(row: int, source_row: int, target_row: int) -> StringName:
	"""The code blocking a reassignment, or REFUSE_NONE. Edge and floor pieces differ here.

	A FLOOR piece is where its tiles are, so it can only be reassigned to the room that owns
	them; its footprint is re-validated against the destination with its own tiles released
	first, and restored exactly on refusal. An EDGE piece occupies a tile EDGE (§4.3's "0/0 means
	edge placement"), so the edge it sits on can border a room whose tiles it does not stand on,
	and R-BUILD-DOM-003 makes its owner an explicit declaration: "Edge furniture contributes to
	its explicit `Furniture.room` owner only". It may therefore be reassigned between rooms of
	the SAME building, and no further -- an edge cannot border two different structures.
	"""
	if _f_user_slot[row] != EntityDirectory.NULL_SLOT:
		return REFUSE_FURNITURE_IN_USE
	if _definitions.is_edge_furniture(_f_type_id[row]):
		return _refuse_edge_reassign(source_row, target_row)
	_stamp_furniture_tiles(row, NO_LINK)
	var code: StringName = _refuse_place_furniture(
		target_row, _f_type_id[row], _f_origin_tile[row], _f_rotation[row])
	if code != REFUSE_NONE:
		_stamp_furniture_tiles(row, row)
	return code


func _refuse_edge_reassign(source_row: int, target_row: int) -> StringName:
	"""Both rooms must be live rooms of one building for an edge piece to change owner."""
	if source_row == NO_ROW:
		return REFUSE_STALE_ROOM_REF
	if (_r_building_slot[source_row] != _r_building_slot[target_row]
			or _r_building_generation[source_row] != _r_building_generation[target_row]):
		return REFUSE_DIFFERENT_BUILDING
	return REFUSE_NONE


func _apply_reassign(row: int, source_row: int, target_row: int, room_ref: Vector2i) -> void:
	"""Relink one furniture row to its new room and recompute both rooms' masks."""
	if source_row != NO_ROW:
		_unlink_furniture(source_row, row)
	_f_room_slot[row] = room_ref.x
	_f_room_generation[row] = room_ref.y
	_link_furniture(target_row, row)
	_stamp_furniture_tiles(row, row)
	if source_row != NO_ROW:
		_r_furniture_mask[source_row] = _recompute_mask_row(source_row)
	_r_furniture_mask[target_row] = _recompute_mask_row(target_row)


func _link_furniture(room_row: int, furniture_row: int) -> void:
	"""Push a furniture row onto the head of its room's intrusive chain."""
	var head: int = _r_furniture_head[room_row]
	_f_room_next[furniture_row] = head
	_f_room_prev[furniture_row] = NO_LINK
	if head != NO_LINK:
		_f_room_prev[head] = furniture_row
	_r_furniture_head[room_row] = furniture_row
	_r_furniture_count[room_row] += 1


func _unlink_furniture(room_row: int, furniture_row: int) -> void:
	"""Detach a furniture row from its room's chain, repairing both neighbours and the head."""
	var previous: int = _f_room_prev[furniture_row]
	var following: int = _f_room_next[furniture_row]
	if previous == NO_LINK:
		_r_furniture_head[room_row] = following
	else:
		_f_room_next[previous] = following
	if following != NO_LINK:
		_f_room_prev[following] = previous
	_f_room_next[furniture_row] = NO_LINK
	_f_room_prev[furniture_row] = NO_LINK
	_r_furniture_count[room_row] -= 1


# --- Furniture accessors and setters --------------------------------------------------------------

func _furniture_row_of(furniture_ref: Vector2i) -> int:
	"""The typed row a live furniture reference names, or NO_ROW. Internal; never returned raw."""
	if not _directory.is_valid_of_kind(furniture_ref, EntityDirectory.KIND_FURNITURE):
		return NO_ROW
	var row: int = _directory.get_typed_row(furniture_ref)
	if row < 0 or row >= FURNITURE_CAPACITY or _f_present[row] != 1:
		return NO_ROW
	if _f_ref_slot[row] != furniture_ref.x or _f_ref_generation[row] != furniture_ref.y:
		return NO_ROW
	return row


func furniture_ref_of_row(row: int) -> Vector2i:
	"""The reference a live furniture row hands back, or the GDD null reference `(-1, 0)`."""
	if row < 0 or row >= FURNITURE_CAPACITY or _f_present[row] != 1:
		return NULL_REF
	return Vector2i(_f_ref_slot[row], _f_ref_generation[row])


func is_live_furniture(furniture_ref: Vector2i) -> bool:
	"""True when `furniture_ref` still names a live row of this store."""
	return _furniture_row_of(furniture_ref) != NO_ROW


func _furniture_field(furniture_ref: Vector2i, column: PackedInt32Array) -> OpResult:
	"""One Furniture column's value for a live reference, or a stale-reference refusal."""
	var row: int = _furniture_row_of(furniture_ref)
	if row == NO_ROW:
		return _refuse(REFUSE_STALE_FURNITURE_REF)
	return OpResult.new(true, REFUSE_NONE, column[row], furniture_ref)


func type_id_of_furniture(furniture_ref: Vector2i) -> OpResult:
	"""`Furniture.type_id`: a compiled FurnitureDefinition id, 0-8."""
	return _furniture_field(furniture_ref, _f_type_id)


func origin_tile_of_furniture(furniture_ref: Vector2i) -> OpResult:
	"""`Furniture.origin_tile`: the interior tile this piece starts at."""
	return _furniture_field(furniture_ref, _f_origin_tile)


func rotation_of_furniture(furniture_ref: Vector2i) -> OpResult:
	"""`Furniture.rotation`: 0-3."""
	return _furniture_field(furniture_ref, _f_rotation)


func condition_of_furniture(furniture_ref: Vector2i) -> OpResult:
	"""`Furniture.condition`. A damaged piece still contributes its presence bit."""
	return _furniture_field(furniture_ref, _f_condition)


func room_ref_of_furniture(furniture_ref: Vector2i) -> Vector2i:
	"""`Furniture.room`: the room that owns this piece, or the null reference."""
	var row: int = _furniture_row_of(furniture_ref)
	if row == NO_ROW:
		return NULL_REF
	return Vector2i(_f_room_slot[row], _f_room_generation[row])


func user_ref_of_furniture(furniture_ref: Vector2i) -> Vector2i:
	"""`Furniture.user`: the resident using this piece, or the null reference."""
	var row: int = _furniture_row_of(furniture_ref)
	if row == NO_ROW:
		return NULL_REF
	return Vector2i(_f_user_slot[row], _f_user_generation[row])


func set_furniture_user(furniture_ref: Vector2i, user_ref: Vector2i) -> OpResult:
	"""Bind or clear `Furniture.user`. The null reference clears it.

	A non-null reference must name a live resident. GDD §4.2's "Bed/seat/workstation single-user"
	is enforced by the column itself: one reference, so a second binding replaces the first and
	the caller must clear it deliberately.
	"""
	var row: int = _furniture_row_of(furniture_ref)
	if row == NO_ROW:
		return _refuse(REFUSE_STALE_FURNITURE_REF)
	if user_ref != NULL_REF and not _directory.is_valid_of_kind(
			user_ref, EntityDirectory.KIND_RESIDENT):
		return _refuse(REFUSE_STALE_USER_REF)
	_f_user_slot[row] = user_ref.x
	_f_user_generation[row] = user_ref.y
	return OpResult.new(true, REFUSE_NONE, user_ref.x, furniture_ref)


func set_furniture_condition(furniture_ref: Vector2i, condition: int) -> OpResult:
	"""Set `Furniture.condition`. Refuses a negative value; no maximum is stated for furniture."""
	var row: int = _furniture_row_of(furniture_ref)
	if row == NO_ROW:
		return _refuse(REFUSE_STALE_FURNITURE_REF)
	if condition < 0 or condition > INT32_MAX:
		return _refuse(REFUSE_INVALID_CONDITION)
	_f_condition[row] = condition
	return OpResult.new(true, REFUSE_NONE, condition, furniture_ref)


func furniture_at_tile(tile: int) -> Vector2i:
	"""The floor furniture standing on a tile, or the null reference when none does."""
	if not is_tile_index(tile) or _furniture_slot[tile] == NO_LINK:
		return NULL_REF
	return furniture_ref_of_row(_furniture_slot[tile])


func furniture_rows_in_room(room_ref: Vector2i) -> PackedInt32Array:
	"""Every live furniture row of one room, in chain order. Cold path; allocates its result."""
	var rows: PackedInt32Array = PackedInt32Array()
	var room_row: int = _room_row_of(room_ref)
	if room_row == NO_ROW:
		return rows
	var row: int = _r_furniture_head[room_row]
	while row != NO_LINK:
		rows.append(row)
		row = _f_room_next[row]
	return rows


func live_furniture_count() -> int:
	"""How many furniture rows are live across every room."""
	return _f_live_count


func live_furniture_of_kind(type_id: int) -> int:
	"""How many live rows of one FurnitureDefinition kind exist, across every room.

	A maintained counter, not a scan: a HUD bed count must not walk 81920 rows per frame.
	"""
	return _f_kind_count[type_id] if _definitions.is_furniture_id(type_id) else 0


# --- the furniture-presence mask (R-BUILD-DOM-003) -------------------------------------------------

func _recompute_mask_row(room_row: int) -> int:
	"""OR `1 << type_id` over this room's live chain. The single definition of the mask.

	Bounded by the room's own furniture count, not by the 81920-row arena: the ruling forbids
	scanning all furniture per resident per tick, and this walk is the "recompute from the owning
	bounded rows on structural edits" it allows instead.
	"""
	var mask: int = 0
	var row: int = _r_furniture_head[room_row]
	while row != NO_LINK:
		mask |= _definitions.furniture_bit_of(_f_type_id[row])
		row = _f_room_next[row]
	return mask


func recompute_furniture_mask(room_ref: Vector2i) -> OpResult:
	"""Recompute and store one room's mask from its live rows; the value is the new mask."""
	var row: int = _room_row_of(room_ref)
	if row == NO_ROW:
		return _refuse(REFUSE_STALE_ROOM_REF)
	_r_furniture_mask[row] = _recompute_mask_row(row)
	return OpResult.new(true, REFUSE_NONE, _r_furniture_mask[row], room_ref)


func verify_room_masks() -> OpResult:
	"""Compare every stored mask against a recomputation, and REFUSE on the first mismatch.

	R-BUILD-DOM-003's load rule: "recompute expected masks from staged validated furniture
	references and compare; refuse mismatch before activating state rather than silently
	repairing it." The value on success is how many rooms were checked; on refusal it is 0 and
	`.ref` names the offending room, because a loader needs to say WHICH room disagreed.
	"""
	var checked: int = 0
	for row: int in ROOM_CAPACITY:
		if _r_present[row] != 1:
			continue
		checked += 1
		if _r_furniture_mask[row] != _recompute_mask_row(row):
			return OpResult.new(false, REFUSE_MASK_MISMATCH, 0, room_ref_of_row(row))
		if (_r_furniture_mask[row] & ~_definitions.known_furniture_mask()) != 0:
			return OpResult.new(false, REFUSE_MASK_MISMATCH, 0, room_ref_of_row(row))
	return OpResult.new(true, REFUSE_NONE, checked, NULL_REF)


func count_furniture_of_kind(room_ref: Vector2i, type_id: int) -> OpResult:
	"""How many live rows of one kind this room holds. Counts rows; never reads the mask.

	The mask says "at least one"; this says how many. R-BUILD-DOM-003 is explicit that the first
	can never be used to answer the second.
	"""
	var room_row: int = _room_row_of(room_ref)
	if room_row == NO_ROW:
		return _refuse(REFUSE_STALE_ROOM_REF)
	if not _definitions.is_furniture_id(type_id):
		return _refuse(REFUSE_UNKNOWN_FURNITURE_TYPE)
	var total: int = 0
	var row: int = _r_furniture_head[room_row]
	while row != NO_LINK:
		if _f_type_id[row] == type_id:
			total += 1
		row = _f_room_next[row]
	return OpResult.new(true, REFUSE_NONE, total, room_ref)


# --- services measured from real rows --------------------------------------------------------------

func pantry_capacity_g_of_room(room_ref: Vector2i) -> OpResult:
	"""The pantry storage a VALID PANTRY room's shelves supply, in grams.

	R-BUILD-DOM-004: only shelves in a valid PANTRY room contribute, so the starter's four give
	4 x 50000 = 200000 g and its fifth, kitchen-owned shelf gives none. A non-pantry room is
	REFUSED rather than answered 0: a caller summing rooms must not be able to fold the kitchen
	shelf in by accident, and a refusal says why.
	"""
	var room_row: int = _room_row_of(room_ref)
	if room_row == NO_ROW:
		return _refuse(REFUSE_STALE_ROOM_REF)
	if _r_type[room_row] != ROOM_TYPE_PANTRY:
		return _refuse(REFUSE_NOT_A_PANTRY)
	if _r_valid[room_row] != 1:
		return _refuse(REFUSE_ROOM_NOT_VALID)
	var total: int = 0
	var row: int = _r_furniture_head[room_row]
	while row != NO_LINK:
		total += _definitions.shelf_capacity_g_of(_f_type_id[row])
		row = _f_room_next[row]
	return OpResult.new(true, REFUSE_NONE, total, room_ref)


func kitchen_bench_slots_of_room(room_ref: Vector2i) -> OpResult:
	"""Kitchen worker slots a VALID KITCHEN room's benches supply: one per bench instance.

	BAL-CAT-011's second kitchen provider, and R-BUILD-DOM-002's "Each 2x1 bench is one furniture
	instance, not two slots". A non-kitchen room refuses, for the same reason the pantry call
	does. A slot here is a CATALOG capacity, not a ready station: occupancy, access, inputs and
	output space are separate gates this store does not evaluate.
	"""
	var room_row: int = _room_row_of(room_ref)
	if room_row == NO_ROW:
		return _refuse(REFUSE_STALE_ROOM_REF)
	if _r_type[room_row] != ROOM_TYPE_KITCHEN:
		return _refuse(REFUSE_NOT_A_KITCHEN)
	if _r_valid[room_row] != 1:
		return _refuse(REFUSE_ROOM_NOT_VALID)
	var total: int = 0
	var row: int = _r_furniture_head[room_row]
	while row != NO_LINK:
		total += _definitions.furniture_station_slots_of(_f_type_id[row])
		row = _f_room_next[row]
	return OpResult.new(true, REFUSE_NONE, total, room_ref)


func station_slots_in_building(building_ref: Vector2i, station_id: int) -> OpResult:
	"""Catalog worker slots one building offers to one Station service, exterior plus interior.

	R-BUILD-DOM-002's two providers, added without double counting: an exterior kitchen supplies
	its own two slots and provides nothing through furniture; the starter hall provides NO
	exterior kitchen service -- `hall` is not a Station key -- so its one bench gives exactly one
	slot and "hall's catalog slots" (its two Keeper slots) are never added again.
	"""
	var building_row: int = _building_row_of(building_ref)
	if building_row == NO_ROW:
		return _refuse(REFUSE_STALE_BUILDING_REF)
	if station_id < 0 or station_id >= _definitions.station_count():
		return _refuse(REFUSE_UNKNOWN_STATION)
	var total: int = _definitions.catalog_slots_for_station(_b_type_id[building_row], station_id)
	var room_row: int = _b_room_head[building_row]
	while room_row != NO_LINK:
		total += _interior_station_slots(room_row, station_id)
		room_row = _r_building_next[room_row]
	return OpResult.new(true, REFUSE_NONE, total, building_ref)


func _interior_station_slots(room_row: int, station_id: int) -> int:
	"""Slots one VALID room's furniture contributes to a station. An invalid room contributes 0."""
	if _r_valid[room_row] != 1:
		return 0
	var total: int = 0
	var row: int = _r_furniture_head[room_row]
	while row != NO_LINK:
		if _definitions.station_of_furniture(_f_type_id[row]) == station_id:
			total += _definitions.furniture_station_slots_of(_f_type_id[row])
		row = _f_room_next[row]
	return total


func room_meets_countable_rules(room_ref: Vector2i) -> OpResult:
	"""GDD §5.9's room-validity list, COUNTING HALF ONLY: value 1 when it passes, 0 when it fails.

	Implements the tile and furniture arithmetic of "dormitory>=3 tiles/bed, at least 1 bed" and
	its six siblings. It does NOT implement connected access, partitioned enclosure, the exterior
	link, corridor width or "heated", all of which need room/heat topology that does not exist
	yet -- so a true here is a necessary condition for validity and never a sufficient one, and
	`set_room_valid()` is deliberately a separate call.
	"""
	var room_row: int = _room_row_of(room_ref)
	if room_row == NO_ROW:
		return _refuse(REFUSE_STALE_ROOM_REF)
	var passes: bool = _countable_rules_pass(room_row)
	return OpResult.new(true, REFUSE_NONE, 1 if passes else 0, room_ref)


func _countable_rules_pass(room_row: int) -> bool:
	"""Dispatch §5.9's countable validity rule for this room's type."""
	var tiles: int = _r_tile_count[room_row]
	match _r_type[room_row]:
		ROOM_TYPE_DORMITORY:
			var beds: int = _count_kind(room_row, "bed")
			return beds >= 1 and tiles >= TILES_PER_BED * beds
		ROOM_TYPE_PRIVATE_ROOM:
			return tiles >= PRIVATE_ROOM_MIN_TILES and _count_kind(room_row, "bed") == PRIVATE_ROOM_BEDS
		ROOM_TYPE_KITCHEN:
			return (tiles >= KITCHEN_MIN_TILES and _count_kind(room_row, "kitchen_bench") >= 1
				and _count_kind(room_row, "hearth") >= 1)
		ROOM_TYPE_DINING:
			var seats: int = _count_kind(room_row, "seat")
			return seats >= DINING_MIN_SEATS and tiles >= TILES_PER_SEAT * seats
		ROOM_TYPE_COMMON:
			return tiles >= COMMON_MIN_TILES and _count_kind(room_row, "seat") >= COMMON_MIN_SEATS
		ROOM_TYPE_INFIRMARY:
			return _infirmary_rules_pass(room_row, tiles)
		ROOM_TYPE_PANTRY:
			return tiles >= PANTRY_MIN_TILES and _count_kind(room_row, "shelf") >= 1
		_:
			return _r_type[room_row] == ROOM_TYPE_CORRIDOR


func _infirmary_rules_pass(room_row: int, tiles: int) -> bool:
	"""§5.9: "infirmary>=3 tiles/patient bed,>=1 bed,>=1 shelf, heated".

	INTERPRETATION: the ">=1 bed" immediately after ">=3 tiles/patient bed" is read as the
	patient bed that sentence just named, matching §5.9's own infirmary row ("Interior 6x6;8
	patient beds"), which lists no ordinary bed. "Heated" is topology and is not evaluated.
	"""
	var patient_beds: int = _count_kind(room_row, "patient_bed")
	return (patient_beds >= 1 and tiles >= TILES_PER_PATIENT_BED * patient_beds
		and _count_kind(room_row, "shelf") >= 1)


func _count_kind(room_row: int, key: String) -> int:
	"""How many live rows of one furniture KEY this room holds, resolved through the catalog."""
	var type_id: int = int(Catalog.FURNITURE_DEFINITION[key])
	var total: int = 0
	var row: int = _r_furniture_head[room_row]
	while row != NO_LINK:
		if _f_type_id[row] == type_id:
			total += 1
		row = _f_room_next[row]
	return total


func _refuse(code: StringName) -> OpResult:
	"""One refusal: no value, the null reference, and the code that says what was rejected."""
	return OpResult.new(false, code, 0, NULL_REF)
