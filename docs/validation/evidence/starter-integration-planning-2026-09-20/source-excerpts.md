## godot/scripts/core/buildings.gd:1-160 SHA256 eb6d09a1d80d169fa60795b6e6d22d05dd64329b8ea85f36e805b482ea705dd5
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

## godot/scripts/core/buildings.gd:830-910 SHA256 eb6d09a1d80d169fa60795b6e6d22d05dd64329b8ea85f36e805b482ea705dd5
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

## godot/scripts/core/buildings.gd:1160-1310 SHA256 eb6d09a1d80d169fa60795b6e6d22d05dd64329b8ea85f36e805b482ea705dd5

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

## godot/scripts/core/building_definitions.gd:1-240 SHA256 eedac020ca29c92d9ffcb60d77d2ab8d0d309beee52b98a44c89795dc63fc074
extends RefCounted
## The immutable BuildingDefinition / FurnitureDefinition facts, and the Station provider binding.
##
## Decision 0056 published the two domains' IDENTITY -- thirty building keys and nine furniture
## keys -- and said in terms that "Footprints, materials, work, slots, `managed_interior`,
## `room_tiles`, `unlock`, `base_store_g`, `passive_slots` and `max_builders` are NOT transcribed
## here. They stay in §4.1/§4.2's rows and belong to §7.2 step 2's packed Building/Furniture/Room
## stores." This module is where they land: the numeric half of the catalog, read by `buildings.gd`
## and by anything that needs a capacity rather than an id.
##
## NO SECOND KEY LIST. Every table below is keyed by the SAME StringName keys `catalog.gd` owns,
## and the packed columns are indexed by the id `Catalog.BUILDING_DEFINITION` /
## `Catalog.FURNITURE_DEFINITION` assigns. `_init()` refuses unless the two key sets are exactly
## equal in both directions, so a key added to one and not the other fails loudly instead of
## leaving a zero-filled row that reads as a legal 0-slot, 0-capacity building. Decision 0056
## rejected a second identity file for exactly this drift; keying the facts by the catalog's own
## keys is what keeps that rejection intact while still storing the facts somewhere.
##
## SOURCES, ROW BY ROW. `gameplay_balance.md` §4.1 gives footprint_x, footprint_z, work_mwu,
## slots, managed_interior, room_tiles and unlock; §4.2 gives base_store_g, passive_slots and
## max_builders; §4.3 gives the furniture floor_x, floor_z, work_mwu and user_slots. Those tables
## are themselves derived from GDD §5.9 with `[GDD §5.9; NEW normalized key]` provenance on every
## row, and BAL-CAT-006 is what joins a base row to its upgrade and furniture rows.
##
## UNLOCK IS A MILESTONE ID (R-BUILD-DOM-001, decision 0074). §4.1's unlock column carries 0..3
## and BAL-CAT-002 states the encoding outright: "Unlock values are M0=0, M1=1, M2=2, M3=3,
## M4=4". `unlock_of()` returns that id and `milestones.gd` owns the earned-bit gate; nothing
## here compares ordinals. No current building row carries M4 -- §5.11 gives M4 a victory
## presentation and a cosmetic monument, not a building -- and publishing the fifth milestone
## creates no M4 production entry, which the ruling states explicitly.
##
## THE STATION PROVIDER BINDING (R-BUILD-DOM-002). Eleven building keys are spelled identically
## to the eleven Station service keys and carry DIFFERENT ids; `station_of_building()` is the
## explicit mapping between them, built by key lookup through both catalogs rather than by
## assuming the spellings line up positionally. `kitchen_bench` furniture additionally provides
## the `kitchen` service at one slot per bench. The ruling's own worked example is asserted in
## `_assert_station_binding()`: "kitchen service=3, exterior kitchen building=14, hall
## building=12, and kitchen_bench furniture=5".
##
## A SERVICE ID IS NOT A READY STATION. The ruling is emphatic and this module obeys it: these
## tables give a definition's CATALOG capacity. Whether a particular building can actually run a
## recipe depends on its state, condition, occupancy, room validity, access, inputs, output space
## and -- for well and saltpan -- a bound physical source. None of those is knowable from a
## definition row, so nothing here returns "ready"; `buildings.gd` answers only about live rows,
## and even there the topology gates remain open work.
##
## WHAT IS DELIBERATELY ABSENT:
##   * MATERIALS. §4.1's `materials_milli` and §4.3's are typed pair lists (`wood:100000;
##     stone:60000;cloth:12000`), and they are consumed by the Construction delivery/refund
##     contract in task 06.2 -- REQ-SET-124/125/126 -- which does not exist. A pair list is not
##     an int32 column and transcribing it into one here would fix a representation the store
##     that needs it has not chosen. `work_mwu` IS carried, because it is a single integer that
##     the same rows state and the Construction row will hold as `remaining_mwu`.
##   * THE TIER-2 UPGRADE PACKAGES. §4.2's second table (materials, work, fuel_num/den,
##     capacity_num/den, craft_num/den, added_comfort) belongs with the upgrade command in 06.2.
##     What IS carried is the fact BAL-CAT-006 states as a restriction -- "Only residence, hall,
##     covered_store, and workshop accept the GDD tier-2 packages" -- because `Building.tier` is
##     a stored column and a store that accepts tier 2 on a mill would persist an impossible row.
##   * PASSIVE-SLOT AND WORKER-SLOT SEMANTICS BEYOND THE COUNTS. BAL-CAT-006: "Station worker
##     slots and passive batch slots are distinct", so they are two separate columns here and
##     neither is derived from the other.

const Catalog := preload("res://scripts/core/catalog.gd")
const Milestones := preload("res://scripts/core/milestones.gd")

## Column order of every BUILDING_FACTS row. Named so a transcription cannot be read positionally
## by mistake, and so `_fill_building_columns()` reads like the source table.
const B_FOOTPRINT_X: int = 0
const B_FOOTPRINT_Z: int = 1
const B_WORK_MWU: int = 2
const B_SLOTS: int = 3
const B_MANAGED_INTERIOR: int = 4
const B_ROOM_TILES: int = 5
const B_UNLOCK: int = 6
const B_BASE_STORE_G: int = 7
const B_PASSIVE_SLOTS: int = 8
const B_MAX_BUILDERS: int = 9
const B_FIELD_COUNT: int = 10

## Column order of every FURNITURE_FACTS row, from `gameplay_balance.md` §4.3.
const F_FLOOR_X: int = 0
const F_FLOOR_Z: int = 1
const F_WORK_MWU: int = 2
const F_USER_SLOTS: int = 3
const F_FIELD_COUNT: int = 4

## Compile-time lengths for the two fact arenas, so `_allocate_columns()` states a constant the
## registry checker can resolve. Decision 0056 fixes both counts -- thirty BuildingDefinition and
## nine FurnitureDefinition rows -- and `_assert_key_sets()` re-checks them against the live
## catalogs on every construction, so a catalog edit cannot leave these stale.
const BUILDING_DEFINITION_COUNT: int = 30
const FURNITURE_DEFINITION_COUNT: int = 9

## `gameplay_balance.md` §4.1 joined with §4.2, one row per BuildingDefinition key. Order within
## this literal is irrelevant: every row is placed by `Catalog.BUILDING_DEFINITION[key]`, so the
## ids come from the compiler and never from this file's layout.
##
## footprint_x, footprint_z, work_mwu, slots, managed_interior, room_tiles, unlock,
## base_store_g, passive_slots, max_builders
const BUILDING_FACTS: Dictionary = {
	"apiary": [3, 3, 180000, 1, 0, 0, 2, 100000, 0, 4],
	"boathouse": [6, 4, 720000, 4, 0, 0, 3, 200000, 0, 4],
	"brewery": [5, 4, 480000, 1, 0, 0, 2, 100000, 4, 4],
	"cellar": [6, 6, 900000, 2, 0, 0, 1, 1000000, 0, 4],
	"composter": [3, 3, 120000, 1, 0, 0, 0, 100000, 4, 4],
	"covered_store": [6, 6, 480000, 2, 0, 0, 0, 1500000, 0, 4],
	"dirt_path": [1, 1, 2000, 0, 0, 0, 0, 0, 0, 4],
	"dryer": [4, 3, 240000, 1, 0, 0, 0, 100000, 4, 4],
	"fence": [1, 1, 12000, 0, 0, 0, 0, 0, 0, 4],
	"fisher_shelter": [4, 3, 240000, 2, 0, 0, 0, 200000, 0, 4],
	"forester_lodge": [4, 4, 240000, 3, 0, 0, 0, 100000, 0, 4],
	"gate": [2, 1, 90000, 0, 0, 0, 0, 0, 0, 4],
	"hall": [12, 10, 2400000, 2, 1, 80, 0, 0, 0, 4],
	"infirmary": [8, 8, 1000000, 2, 1, 36, 1, 0, 0, 4],
	"kitchen": [6, 6, 600000, 2, 0, 0, 0, 100000, 0, 4],
	"lookout": [2, 2, 180000, 1, 0, 0, 1, 0, 0, 4],
	"memorial_garden": [4, 4, 240000, 1, 0, 0, 0, 0, 0, 4],
	"mill": [5, 5, 720000, 2, 0, 0, 1, 100000, 0, 4],
	"nursery": [4, 4, 300000, 2, 0, 0, 3, 100000, 4, 4],
	"open_stockpile": [4, 4, 60000, 0, 0, 0, 0, 400000, 0, 4],
	"paved_path": [1, 1, 6000, 0, 0, 0, 2, 0, 0, 4],
	"preserver": [5, 4, 480000, 2, 0, 0, 1, 100000, 4, 4],
	"quarry_shed": [4, 4, 240000, 3, 0, 0, 0, 100000, 0, 4],
	"residence": [10, 8, 1200000, 0, 1, 48, 0, 0, 0, 4],
	"saltpan": [4, 4, 240000, 1, 0, 0, 1, 100000, 4, 4],
	"stone_wall": [1, 1, 30000, 0, 0, 0, 2, 0, 0, 4],
	"weir": [4, 2, 480000, 1, 0, 0, 2, 100000, 0, 4],
	"well": [2, 2, 240000, 2, 0, 0, 0, 100000, 0, 4],
	"workbench": [3, 3, 180000, 2, 0, 0, 0, 100000, 0, 4],
	"workshop": [6, 6, 720000, 3, 0, 0, 1, 100000, 0, 4],
}

## `gameplay_balance.md` §4.3: floor_x, floor_z, work_mwu, user_slots. A 0x0 floor is §4.3's own
## "0/0 means edge placement" -- the partition and the door occupy a tile EDGE, not a tile.
const FURNITURE_FACTS: Dictionary = {
	"bed": [1, 1, 20000, 1],
	"decoration": [1, 1, 12000, 0],
	"hearth": [2, 1, 60000, 0],
	"interior_door": [0, 0, 12000, 0],
	"interior_partition": [0, 0, 8000, 0],
	"kitchen_bench": [2, 1, 60000, 1],
	"patient_bed": [1, 1, 24000, 1],
	"seat": [1, 1, 10000, 1],
	"shelf": [1, 1, 16000, 0],
}

## BAL-CAT-006: "Only residence, hall, covered_store, and workshop accept the GDD tier-2
## packages". §4.2's upgrade table lists exactly these four rows and no others.
const TIER_TWO_KEYS: Array[String] = ["covered_store", "hall", "residence", "workshop"]

## GDD §5.9 and §4.1's minimum: every building exists at tier 1.
const MIN_TIER: int = 1
const TIER_TWO: int = 2

## The eleven exterior buildings whose key is also a Station key. R-BUILD-DOM-002: "The eleven
## same-named exterior building definitions provide their corresponding Station service only when
## their actual owning building/service conditions pass." Stored as KEYS, resolved to the two
## different id spaces in `_init()`, because the whole point of the ruling is that the ids differ.
const STATION_PROVIDER_KEYS: Array[String] = [
	"brewery", "composter", "dryer", "kitchen", "mill", "nursery",
	"preserver", "saltpan", "well", "workbench", "workshop",
]

## BAL-CAT-011: "each valid interior kitchen_bench's 1 slot". One bench is one furniture
## instance providing one kitchen worker slot -- the ruling adds "Each 2x1 bench is one furniture
## instance, not two slots", so this is 1 and not the bench's 2x1 footprint.
const KITCHEN_BENCH_KEY: String = "kitchen_bench"
const KITCHEN_STATION_KEY: String = "kitchen"
const KITCHEN_BENCH_SLOTS: int = 1

## GDD §5.9's furniture table: "Shelf |1x1 |wood 2 |16 |50000g pantry capacity". BAL-CAT-006:
## "A shelf adds its 50000 g to the pantry service, not to an unrelated building's industrial
## buffer." R-BUILD-DOM-004 keeps all five starter shelves and lets only the four in the valid
## PANTRY room contribute: 4 x 50000 = 200000 g.
const SHELF_KEY: String = "shelf"
const SHELF_PANTRY_CAPACITY_G: int = 50000

## GDD §5.9: "Hearth |2x1 |stone 6 |60 |Heat up to 120 interior tiles", repeated in §5.9's
## managed-heat paragraph as "up to 120 total interior tiles per hearth".
const HEARTH_KEY: String = "hearth"
const HEARTH_HEATED_TILE_CAPACITY: int = 120

## The empty catalog id, GDD §4.2: "empty catalog IDs are -1". Absence, never a refusal channel.
const NO_STATION: int = Catalog.EMPTY_CATALOG_ID

const REFUSE_NONE: StringName = &""
const REFUSE_UNKNOWN_BUILDING: StringName = &"UNKNOWN_BUILDING_DEFINITION"
const REFUSE_UNKNOWN_FURNITURE: StringName = &"UNKNOWN_FURNITURE_DEFINITION"
const REFUSE_NO_STATION_SERVICE: StringName = &"NO_STATION_SERVICE"
const REFUSE_INVALID_TIER: StringName = &"INVALID_TIER"

# --- compiled fact columns, indexed by compiled definition id (allocated once) -----------------

var _b_footprint_x: PackedInt32Array = PackedInt32Array()
var _b_footprint_z: PackedInt32Array = PackedInt32Array()
var _b_work_mwu: PackedInt64Array = PackedInt64Array()
var _b_slots: PackedInt32Array = PackedInt32Array()
var _b_room_tiles: PackedInt32Array = PackedInt32Array()
var _b_unlock: PackedInt32Array = PackedInt32Array()
var _b_base_store_g: PackedInt64Array = PackedInt64Array()
var _b_passive_slots: PackedInt32Array = PackedInt32Array()
var _b_max_builders: PackedInt32Array = PackedInt32Array()
var _b_managed_interior: PackedByteArray = PackedByteArray()
var _b_tier_two_allowed: PackedByteArray = PackedByteArray()

## Building id -> Station id, or NO_STATION. The explicit provider mapping R-BUILD-DOM-002
## requires: "Import by the field's named domain and bind through explicit provider mappings."
var _b_station: PackedInt32Array = PackedInt32Array()

var _f_floor_x: PackedInt32Array = PackedInt32Array()
var _f_floor_z: PackedInt32Array = PackedInt32Array()
var _f_work_mwu: PackedInt64Array = PackedInt64Array()
var _f_user_slots: PackedInt32Array = PackedInt32Array()

## Furniture id -> the Station service one instance provides, or NO_STATION. Only kitchen_bench
## has an entry today; a furniture kind with no service entry provides none, and a zero here
## would be `brewery` rather than "nothing", which is why the empty value is -1.
var _f_station: PackedInt32Array = PackedInt32Array()
var _f_station_slots: PackedInt32Array = PackedInt32Array()

var _building_count: int = 0
var _furniture_count: int = 0
var _station_count: int = 0


func _init() -> void:
	"""Compile the fact columns from the two catalogs, asserting the key sets match exactly."""
	_building_count = Catalog.BUILDING_DEFINITION.size()
	_furniture_count = Catalog.FURNITURE_DEFINITION.size()
	_station_count = Catalog.STATION.size()
	_assert_key_sets()
	_allocate_columns()
	_fill_building_columns()
	_fill_furniture_columns()
	_bind_stations()
	_assert_station_binding()


func _assert_key_sets() -> void:
	"""Refuse to construct unless every catalog key has a fact row and every fact row a key."""

## godot/scripts/core/spatial_world.gd:1-205 SHA256 3825788db07885db94dab7288c832b8219f89e54da22d871d58e98e2d590b26b
extends RefCounted
## ARCH-PATH-001 ground map: the baseline settlement surface as static integer navigation cells,
## plus the ground half of the shared location identity frozen by task 05.1a.
##
## ---------------------------------------------------------------------------------------
## WHAT A GROUND LOCATION IS, AND WHAT IT IS NOT (READY_07 1.2, first bullet).
##
## A ground location ID here is a BASELINE CELL INDEX qualified by a declared domain, a declared
## layer and the world/map revision it was minted against. It is NOT a universal multi-level
## location. Two different floors, a submerged column and a canopy branch can all sit above the
## same X/Z, so `cell` alone names a destination only inside `(DOMAIN_GROUND, LAYER_SURFACE)`.
## Every public API in this slice therefore carries the whole `Location` record -- domain, layer,
## revision, cell AND the generation-safe owner of the contact -- and no API in this slice accepts
## a bare X/Z pair as a destination. SET-MOVE-001 2's dynamic Location/Connection directory kinds
## are the eventual shared boundary; this module keeps the same field shape deliberately, so the
## later domains extend it instead of replacing it.
##
## BLOCKER, NAMED NOT INVENTED: domains other than DOMAIN_GROUND and layers other than
## LAYER_SURFACE refuse with `DOMAIN_NOT_CONTRACTED` / `LAYER_NOT_CONTRACTED`. Their finite depth,
## elevation and cell budgets are MOVE-G01 parameter-pack outputs (READY_07 1.3) and are not
## guessed here. One floor is not a substitute for multilevel scope.
##
## ---------------------------------------------------------------------------------------
## CLEARANCE IS AN INPUT, NOT A CONSTANT THIS MODULE OWNS.
##
## `_clearance[cell]` is pure map geometry: the side of the largest all-passable square whose
## north-west corner is that cell, in half-metre cells. A route asks `cell_passes_clearance(cell,
## clearance_class)` with a clearance class the CALLER supplies. This module publishes no body,
## posture or gear clearance number, because READY_07 1.2 is explicit that exact production
## body/gear clearances are a profile decision that neither the 1.0 m mouse anchor nor a size-speed
## category determines. Reference routing with a synthetic clearance class is unblocked; ordinary
## resident travel cannot be declared correct until starter profiles and contact clearances are
## specified, and nothing here may be published into an active gameplay catalog as if it were one.
##
## ---------------------------------------------------------------------------------------
## THE CONTACT SCHEMA IS A SCHEMA, NOT A CATALOG OF DESTINATIONS.
##
## `Contact` below is the movement half of the 2026-09-11 ruling's starter contact manifest: a work
## cell, a separate approach cell a body actually stands on, one generation-checked owner, and the
## owner's destination revision. What this module supplies is the RECORD SHAPE and its refusals.
## The exact supported footprint and contact envelope -- how far an approach may be from its work
## point, whether a footprint spans cells, which side of a building offers one -- is the contact
## owner's value and is NOT invented here. No adjacency rule is imposed for that reason.
##
## ---------------------------------------------------------------------------------------
## MEMORY. The five columns below ARE systems_architecture.md 2.3's "Static navigation map",
## 262144 x 14 bytes = 3670016: walkability/layer bytes plus terrain/height/clearance i32. No
## second world, no shadow copy, and no `resize()` outside `_init()`.

const IntMath := preload("res://scripts/core/int_math.gd")
const WorldInit := preload("res://scripts/core/world_init.gd")

# --- geometry, ARCH-PATH-001 --------------------------------------------------------------------

## "Navigation cells are 1/2 m, producing 512x512=262144 cells; cell ID=`z*512+x`."
const CELLS_X: int = 512
const CELLS_Z: int = 512
const CELL_COUNT: int = CELLS_X * CELLS_Z

## Positions are int32 in 1/1024 m units (GDD 4.2), so a half-metre cell is 512 units wide.
const CELL_SIZE_UNITS: int = 512
const CELL_CENTRE_OFFSET_UNITS: int = 256

## world_init.gd's exterior tiles are 2 m, so one tile covers exactly 4x4 navigation cells.
const CELLS_PER_TILE: int = 4

## ARCH-PATH-003: "Macro cells contain 16x16 navigation cells".
const MACRO_CELLS: int = 16
const MACROS_X: int = CELLS_X / MACRO_CELLS
const MACROS_Z: int = CELLS_Z / MACRO_CELLS
const MACRO_COUNT: int = MACROS_X * MACROS_Z
const CELLS_PER_MACRO: int = MACRO_CELLS * MACRO_CELLS

# --- declared domain and layer space ------------------------------------------------------------

const DOMAIN_GROUND: int = 0
const DOMAIN_COUNT: int = 1
const LAYER_SURFACE: int = 0
const LAYER_COUNT: int = 1

# --- revisions ----------------------------------------------------------------------------------

## SET-MOVE-001 2 makes the topology revision a positive i64 that refuses exhaustion and never
## wraps. This baseline fixture carries the revision inside an int32-width identity record, so it
## refuses one step EARLIER than the eventual contract rather than wrapping into a revision that
## would silently revalidate every stale route. Widening the record to i64 is a MOVE-G02 output.
const FIRST_MAP_REVISION: int = 1
const MAX_MAP_REVISION: int = IntMath.INT32_MAX

const MIN_CLEARANCE_CLASS: int = 1
const MAX_CLEARANCE_CLASS: int = CELLS_X

# --- refusal codes ------------------------------------------------------------------------------

const REFUSE_NONE: StringName = &""
const REFUSE_INVALID_CELL: StringName = &"INVALID_CELL"
const REFUSE_INVALID_COORD: StringName = &"INVALID_CELL_COORD"
const REFUSE_INVALID_POSITION: StringName = &"POSITION_OUT_OF_MAP"
const REFUSE_DOMAIN: StringName = &"DOMAIN_NOT_CONTRACTED"
const REFUSE_LAYER: StringName = &"LAYER_NOT_CONTRACTED"
const REFUSE_REVISION_EXHAUSTED: StringName = &"MAP_REVISION_EXHAUSTED"
const REFUSE_NULL_OWNER: StringName = &"LOCATION_OWNER_REQUIRED"
const REFUSE_CONTACT_REVISION: StringName = &"CONTACT_DESTINATION_REVISION_REQUIRED"
const REFUSE_CONTACT_APPROACH: StringName = &"CONTACT_APPROACH_NOT_WALKABLE"

## The first legal destination revision. Zero means "this contact named no destination state at
## all", which is how an empty building or an absent service store is kept out of the manifest --
## the ruling's "empty buildings or nonexistent service stores are not valid targets". The revision
## VALUE is the contact owner's; only its null is contracted here.
const FIRST_DESTINATION_REVISION: int = 1


class Location:
	extends RefCounted
	## One ground contact: spatial context plus the generation-safe entity that owns it.
	##
	## Caller-owned and reused, like `int_math.gd`'s IntResult, so a per-tick reader allocates
	## nothing. `owner_slot`/`owner_generation` are HALVES OF ONE EntityRef and must be compared
	## as a pair; comparing only the slot is the defect class this record exists to make visible.

	var domain: int = -1
	var layer: int = -1
	var revision: int = 0
	var cell: int = -1
	var owner_slot: int = -1
	var owner_generation: int = 0

	func clear() -> void:
		"""Return this record to the unbound state; `is_bound()` is false afterwards."""
		domain = -1
		layer = -1
		revision = 0
		cell = -1
		owner_slot = -1
		owner_generation = 0

	func is_bound() -> bool:
		"""True when this record names a domain, a layer and a cell. Says nothing about staleness."""
		return domain >= 0 and layer >= 0 and cell >= 0

	func owner_ref() -> Vector2i:
		"""The owning entity reference as GDD 4.1's `(slot, generation)` pair."""
		return Vector2i(owner_slot, owner_generation)

	func same_place_as(other: Location) -> bool:
		"""True when both records name the same domain, layer and cell. Ignores owner and revision."""
		return domain == other.domain and layer == other.layer and cell == other.cell


class Contact:
	extends RefCounted
	## One work or service destination: WHERE THE WORK IS and WHERE A BODY MUST STAND ARE TWO
	## DIFFERENT CELLS, plus the destination's own revision.
	##
	## The two locations are separate on purpose. A workbench, a store shelf or a well head occupies
	## a cell that navigation need not make walkable at all; the body stands on the approach cell.
	## Collapsing them is exactly SET-MOVE-001 MOVE-REQ-013's defect -- "being horizontally close
	## cannot satisfy a below-floor job" -- one level up.
	##
	## `destination_revision` is the CONTACT OWNER'S number, not this module's. It changes when the
	## thing being travelled to changes in a way that invalidates an admitted journey: a store
	## emptied, a service withdrawn, a building demolished and rebuilt on the same handle. Movement
	## records it at admission and refuses on mismatch; it never guesses what should bump it.
	##
	## NOT SETTLED HERE, AND DELIBERATELY NOT INVENTED: how far an approach cell may lie from its
	## work cell, whether a footprint spans several cells, and which approach a multi-sided building
	## offers. Those are the "exact supported footprint/contact envelopes" the 2026-09-11 movement
	## ruling assigns to the contact owner. This record therefore takes the approach cell as given
	## and checks only that it is a real, walkable ground cell -- no adjacency rule is imposed,
	## because imposing one would be choosing that envelope.

	var work: Location = Location.new()
	var approach: Location = Location.new()
	var destination_revision: int = 0

	func clear() -> void:
		"""Return this contact to the unbound state; `is_bound()` is false afterwards."""
		work.clear()
		approach.clear()
		destination_revision = 0

	func is_bound() -> bool:
		"""True when both endpoints name a place and the owner declared a destination revision."""
		return work.is_bound() and approach.is_bound() and destination_revision > 0

	func owner_ref() -> Vector2i:
		"""The owning entity reference; both endpoints always carry the same owner."""
		return work.owner_ref()


# --- static navigation map, systems_architecture.md 2.3 "Static navigation map" ------------------

var _walkable: PackedByteArray = PackedByteArray()
var _layer: PackedByteArray = PackedByteArray()
var _terrain: PackedInt32Array = PackedInt32Array()
var _height_units: PackedInt32Array = PackedInt32Array()
var _clearance: PackedInt32Array = PackedInt32Array()

var _map_revision: int = FIRST_MAP_REVISION
var _walkable_count: int = 0
var _clearance_dirty: bool = false
var _last_refusal: StringName = REFUSE_NONE


func _init() -> void:

## godot/scripts/core/spatial_world.gd:435-510 SHA256 3825788db07885db94dab7288c832b8219f89e54da22d871d58e98e2d590b26b
func bind_ground_location(out: Location, cell: int, owner: Vector2i) -> bool:
	"""Fill `out` with a ground contact at `cell` owned by `owner`, or refuse explicitly.

	The owner is mandatory and may not be the null reference: READY_07 1.2 requires public APIs to
	carry a generation-safe contact owner rather than assume an X/Z pair identifies a destination.
	Whether that owner is still LIVE is the directory's question, asked by `navigation.gd` at
	submit and again at service; this call only records the pair.
	"""
	if not is_cell(cell):
		_last_refusal = REFUSE_INVALID_CELL
		return false
	if owner.x < 0:
		_last_refusal = REFUSE_NULL_OWNER
		return false
	out.domain = DOMAIN_GROUND
	out.layer = LAYER_SURFACE
	out.revision = _map_revision
	out.cell = cell
	out.owner_slot = owner.x
	out.owner_generation = owner.y
	_last_refusal = REFUSE_NONE
	return true


func location_is_current(location: Location) -> bool:
	"""True when `location` still names a contracted, in-bounds ground cell at the CURRENT revision."""
	if location.domain != DOMAIN_GROUND or location.layer != LAYER_SURFACE:
		return false
	if location.revision != _map_revision:
		return false
	return is_cell(location.cell)


func bind_ground_contact(
	out: Contact, work_cell: int, approach_cell: int, owner: Vector2i, destination_revision: int
) -> bool:
	"""Fill `out` with a work/service destination, or refuse explicitly and leave it unbound.

	Every check runs before anything is written, so a refused bind never leaves a half-filled
	contact that a later `is_bound()` would accept. The approach cell must be walkable -- a contact
	a body cannot legally stand at is not a destination -- while the work cell need only exist,
	because building interiors and water work points are not required to be navigable ground.
	"""
	out.clear()
	if destination_revision < FIRST_DESTINATION_REVISION:
		_last_refusal = REFUSE_CONTACT_REVISION
		return false
	if not is_cell(work_cell) or not is_cell(approach_cell):
		_last_refusal = REFUSE_INVALID_CELL
		return false
	if not is_walkable_cell(approach_cell):
		_last_refusal = REFUSE_CONTACT_APPROACH
		return false
	if not bind_ground_location(out.work, work_cell, owner):
		out.clear()
		return false
	if not bind_ground_location(out.approach, approach_cell, owner):
		out.clear()
		return false
	out.destination_revision = destination_revision
	_last_refusal = REFUSE_NONE
	return true


func contact_is_current(contact: Contact) -> bool:
	"""True when both of a bound contact's endpoints still name cells at the CURRENT map revision.

	Says nothing about the owner being alive or the destination revision still being the admitted
	one. Those are two separate questions, asked by two separate callers, and merging them would
	hide which of the three went stale.
	"""
	if not contact.is_bound():
		return false
	return location_is_current(contact.work) and location_is_current(contact.approach)



## docs/game_gdd.md:627-705 SHA256 bdb0b35a982a27dd7fe85d2142f9b484f6e0ca23afb4b81b7b6f526be671d85e
### 5.9 Building catalog, placement, interiors, and upgrades

Footprints are 2 m tiles, rotation in 90° steps. Materials are U; WU is total shared construction work, not per worker. Maximum 4 builders/project unless listed. Indoor kit themes change geometry only.

| Building | Footprint | Materials | WU | Operational slots | Managed interior / capacity | Unlock |
|---|---|---|---:|---:|---|---|
| Refuge/community hall |12×10 |wood 100, stone 60, cloth 12 |2400 |Keeper 2 |Interior 10×8; configured rooms |Start |
| Residence |10×8 |wood 60, stone 24, cloth 8 |1200 |0 |Interior 8×6;12-bed layout capacity; furniture purchased separately |Start |
| Infirmary |8×8 |wood 40, stone 30, cloth 12 |1000 |Healer 2 |Interior 6×6;8 patient beds |M1 |
| Kitchen |6×6 |wood 30, stone 20, iron 2 |600 |Cook 2 |Black box;2 cooking slots |Start |
| Open stockpile |4×4 |wood 4 |60 |0 |400000g; open storage |Start |
| Covered store |6×6 |wood 35, stone 10 |480 |Hauler 2 |1500000g; covered storage |Start |
| Cellar |6×6 |wood 20, stone 60 |900 |Hauler 2 |1000000g; cellar storage |M1 |
| Well |2×2 |wood 10, stone 20 |240 |Hauler 2 |Draw water 10 U/10 WU |Start |
| Workbench shelter |3×3 |wood 12, stone 4 |180 |Crafter 2 |2 craft slots |Start |
| Workshop |6×6 |wood 35, stone 20, iron 4 |720 |Crafter 3 |3 craft slots |M1 |
| Mill |5×5 |wood 25, stone 30 |720 |Crafter 2 |2 mill slots |M1 |
| Dryer |4×3 |wood 16, rope 4 |240 |Preserver 1 |4 passive batch slots |Start |
| Preserver/smokehouse |5×4 |wood 20, stone 24, iron 2 |480 |Preserver 2 |4 passive batch slots |M1 |
| Fisher shelter |4×3 |wood 18, rope 2 |240 |Fisher 2 |Gear locker; bank access |Start |
| Weir |4×2 |wood 30, stone 12, rope 6 |480 |Fisher 1 |2 habitat effort slots |M2 |
| Boathouse |6×4 |wood 40, stone 16, rope 4 |720 |Fisher 4 |2 stored boats; shore line |M3 |
| Composter |3×3 |wood 10 |120 |Keeper 1 |4 passive batch slots |Start |
| Apiary |3×3 |wood 12, rope 2 |180 |Keeper 1 |1 hive |M2 |
| Nursery |4×4 |wood 16, stone 8 |300 |Tender 2 |4 propagation slots |M3 |
| Brewery |5×4 |wood 24, stone 12, iron 2 |480 |Cook 1 |4 passive batch slots |M2 |
| Saltpan |4×4 |wood 8, stone 16 |240 |Preserver 1 |4 passive slots; coast≤4 m |M1 |
| Forester lodge |4×4 |wood 20, stone 8 |240 |Keeper 3 |Managed tree-zone access |Start |
| Quarry shed |4×4 |wood 16, stone 8 |240 |Crafter 3 |Stone/iron source access |Start |
| Lookout |2×2 |wood 12, stone 4 |180 |Keeper 1 |32 m low-risk radius when staffed |M1 |
| Fence segment |1×1 |wood 1 |12 |0 |Wildlife exclusion boundary |Start |
| Stone wall segment |1×1 |stone 3 |30 |0 |Weather/wildlife boundary |M2 |
| Gate |2×1 |wood 6, iron 1 |90 |0 |Passable toggle |Start |
| Dirt path |1×1 |None |2 |0 |Ground speed+10% |Start |
| Paved path |1×1 |stone 1 |6 |0 |Ground speed+20%; replaces dirt |M2 |
| Memorial garden |4×4 |wood 8, stone 12 |240 |Keeper 1 |16 permanent grave entries; visual reuse after 48 days |Start |

Construction materials are delivered to the project container before BUILD phase; workers can deliver in parts, but ordinary production reservations cannot consume delivered construction goods. Build rate sums up to 4 workers' actual work rates. A two-worker residence takes 600 base productive WU/worker, excluding hauling and travel.

Managed-building heat is a connected service: a fueled hearth supplies every valid room connected by open boundaries or interior doors within that building, up to 120 total interior tiles per hearth. Thus the starter dormitory receives its kitchen hearth's heat. Closed impermeable partitions without doors split the heated component. Allocate capacity by hearth ID, then room ID; a room is heated only if its entire tile count fits. Unheated indoors restores no room comfort and follows the hourly temperature convergence rule. Outdoor comfort restoration stops at 6000.

Operational stores for black-box production structures hold 100000 g input/output mass total, except fisher/boathouse gear lockers 200000 g. Passive batch slots and active worker slots are separate constraints. Ground piles hold at most 400000 g each and have 1500 aging factor; create adjacent passable tiles in N,E,S,W breadth-first order when a pile is full. Flax weighs 250 g/U, has no nutrition, and never spoils; dried_fish/salted_fish/dried_fruit weigh 250 g/U. Spoiled_food weighs 250 g/U, raw edible false; loss conversion uses milli-U to conserve its declared mass. General nonfood materials have shelf 0 and default quality PLAIN.

Generic BUILD/CRAFT/FARM/KEEP extraction work consumes 1 equipped tool durability per completed 10 WU; preserve remainder across tasks. No generic wear applies to eating, sleeping, socializing, healing, hauling, cooking, or gear-specific fishing cycles. Basic tools cap 1000, iron tools cap 1500; the fishing table's 1000 cap applies to fishing gear only. Repair uses wood 1+stone 0.5 and 30 WU to restore 200 general-tool durability up to its cap. Broken tools block tool-required work; bare-hand branch/stone recovery and basic-tool crafting remain available. Basic gear crafting at a workbench costs 30 WU/net, 40/trap, 40/ice_kit; boat assembly at boathouse costs 480 WU using its fishing-table materials. Changing equipment is a HAUL task of 4 WU plus travel and never creates a new item.

Wildlife pressure is one existing midnight ecology check per forage basin/apiary during summer/autumn: chance 200/10000, halved to 100 by a complete enclosing fence/wall boundary. On success remove min(2 U, current honey) from an apiary, or min(5 U,current stock) from that basin's highest-stock currently available forage item, ties item ID. Emit an advisory; do not injure residents. Lookout staffing reduces zone danger only, not this roll. No additional random disaster, structure fire, siege, or raider simulation exists in release 1.

Resource extraction recipes: tree 12 wood/120 WU, stone 4 U/120 WU, iron 2 U/180 WU. Surface stone deposits can exhaust; a quarry placed at the guaranteed bedrock source yields stone 4/180 WU indefinitely. Iron is optional efficiency equipment after the initial deposit. Trees regrow after 48 days when their stumps remain and no building occupies the tile; planting a cleared forestry tile costs compost 0.25 U and 4 WU, also maturing after 48 days. A forestry zone retains at least 20% mature trees by default; intensive override retains 10%. Fences reduce forage/hive wildlife-loss events by 50% when a closed boundary encloses the relevant tiles, not just when one fence is nearby.

| Furniture | Footprint tiles | Materials U | WU | Function |
|---|---|---|---:|---|
| Bed |1×1 |wood 2, cloth 1 |20 |1 resident; adjacent walk tile |
| Patient bed |1×1 |wood 2, cloth 2 |24 |1 patient; adjacent walk tile |
| Seat/table place |1×1 |wood 1 |10 |1 diner; group table visuals merge |
| Kitchen bench |2×1 |wood 4, stone 4, iron 1 |60 |1 cooking slot |
| Hearth |2×1 |stone 6 |60 |Heat up to 120 interior tiles |
| Shelf |1×1 |wood 2 |16 |50000g pantry capacity |
| Decoration |1×1 |wood 1, wax 0.25 |12 |Room comfort target+250, cap 1000 |
| Interior partition |Tile edge |wood 1 |8 |Room boundary; no floor occupation |
| Interior door |Tile edge |wood 2 |12 |Passable boundary; maintains heat |

Room validity: dormitory≥3 tiles/bed, at least 1 bed, all bed-adjacent access connected to exterior door; private room≥6 tiles, exactly 1 bed, partitioned enclosure; dining≥2 tiles/seat and≥4 seats; kitchen≥6 tiles,≥1 bench,≥1 hearth; common≥8 tiles,≥4 seats; infirmary≥3 tiles/patient bed,≥1 bed,≥1 shelf, heated; pantry≥4 tiles,≥1 shelf; corridor≥1 tile wide, linked to exterior. One tile belongs to exactly one room, furniture cannot overlap, and at least one connected walk path must reach every usable furniture access tile. Room occupancy is authoritative; roof visibility is presentation.

Default starter interior is 10×8 tiles. B=bed, K=kitchen bench cell, H=hearth cell, S=shelf, T=seat, .=walk tile. The left 5 columns form a 40-tile dormitory with 12 beds; the right 5 columns form kitchen on rows 0–1 (10 tiles), common room on rows 2–6 (25 tiles), and pantry on row 7 (5 tiles). A partition separates x4/x5, with a door at row 4. Other room designations share open walkable boundaries. The exterior south door is at x5. Coordinates are zero-based.

```text
BBBB..KKHH
.........S
BBBB..TTTT
..........
BBBB..TTTT
......TTTT
..........
......SSSS
```

Every seat has an adjacent walk tile above or below; shelves can be reached from the open common-room edge. Four pantry shelves supply 200000g storage. The fifth S at kitchen row 1 is a separate kitchen-owned shelf; it adds no pantry capacity or new industrial buffer. R-BUILD-DOM-004 preserves all five instances. On the 128×128 exterior tile grid, place the hall at(58,59), stockpiles at(50,60),(50,65),(70,60),(70,65), well at(64,54), and workbench at(58,54), all rotation 0. Clear these footprints before resource placement. Hall interior origin is exterior origin+(1,1). Four stockpiles provide 1600000g material storage; starting food fits the pantry. All initial items are assigned to legal containers by food first, then item ID, filling container IDs ascending.

*Baseline fixture boundary: the layout above specifies the existing starter interior, not the limit of the required construction system. DEC-029/031 and SET-MOVE-001 require placed burrows, planned tunnels/rooms and free multi-level excavation to work together. The former one-floor release restriction is superseded. Finish MOVE-G01/G02 before treating room/service rules and capacity bounds as complete for expanded space.*
