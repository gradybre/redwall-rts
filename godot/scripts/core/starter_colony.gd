extends RefCounted
## INIT-C live apply (DEMO-CONTAIN-R01 step D3, decision 0533): materialise `starter_structures.gd`'s
## validated plan into a live `buildings.gd` store -- GDD §5.9's seven exterior structures, the
## hall's four rooms and its thirty-one floor furniture -- and publish the store binding the
## pantry and the four stockpiles are owned and anchored by (answers #3a and #7).
##
## WHY A MODULE OF ITS OWN. Decision 0184 kept the producer a pure plan: it creates no owner and
## publishes no ref. Something has to turn that plan into rows, and the settlement composer is
## 2900 lines that already meet every store. This file is the narrow translator between the two:
## it reads a Plan and writes through `buildings.gd`'s ordinary public doors only, so every rule
## those doors enforce -- the unlock gate, the grid, overlap, the interior inset, one room per
## tile, the furniture floor and, through the bound placement authority, a live ground pile --
## applies to the starter colony exactly as it will to a player's building. Nothing here writes
## a column directly and nothing here is called per tick.
##
## VALIDATE EVERYTHING, THEN WRITE (decision 0059). `preflight_refusal()` proves the plan, every
## building placement and the free directory rows of each kind before `apply_into()` writes a
## byte. After that every remaining door is deterministic over an empty hall, so a refusal inside
## `apply_into()` means the store changed under it; the store has no transaction, so the CALLER
## owns rollback. `settlement_system.gd` resets the whole settlement to empty, exactly as it does
## for every other in-transaction failure of generation (decision 0075).
##
## DETERMINISM. Rows are placed in plan order -- buildings 0..6, rooms 0..3, furniture 0..30 --
## so a given directory state always hands out the same slots, generations and persistent ids.
## `plan_mismatch_refusal()` then re-reads every placed row against the plan, field by field.
##
## WHAT IS DELIBERATELY NOT APPLIED, each named rather than guessed:
##   * The plan's EIGHT PARTITION/DOOR EDGES. Edge furniture has no defined `origin_tile` +
##     `rotation` encoding of an undirected tile edge (decision 0080, decision 0087 blocker 4), so
##     placing them would invent that encoding. The thirty-one floor furniture are placed.
##   * ROOM VALIDITY. §5.9's validity list needs connectivity, enclosure and heat that no module
##     evaluates; every starter room stays `valid = 0`, as `designate_room()` writes it.
##   * BUILDING CONDITION. Its scale is unstated (buildings.gd header); the placed value is kept.
##   * BED ASSIGNMENT. The plan's bed order is data for a future assignment owner.

const StarterStructures := preload("res://scripts/core/starter_structures.gd")
const BuildingsScript := preload("res://scripts/core/buildings.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const Catalog := preload("res://scripts/core/catalog.gd")
const InventoryScript := preload("res://scripts/core/inventory.gd")

const Plan := StarterStructures.Plan

const REFUSE_NONE: StringName = &""
const REFUSE_PLAN_NULL: StringName = &"STARTER_COLONY_PLAN_NULL"
const REFUSE_STORE_NULL: StringName = &"STARTER_COLONY_NO_BUILDING_STORE"
const REFUSE_DIRECTORY_CAPACITY: StringName = &"STARTER_COLONY_DIRECTORY_CAPACITY"
const REFUSE_PLAN_MISMATCH: StringName = &"STARTER_COLONY_PLAN_MISMATCH"
const REFUSE_NOT_PLACED: StringName = &"STARTER_COLONY_NOT_PLACED"

## GDD §5.1/§5.9: four open stockpiles, which together provide the 1600000 g material store.
const STOCKPILE_COUNT: int = 4

const HALL_TYPE_ID: int = Catalog.BUILDING_DEFINITION[StarterStructures.HALL_KEY]
const STOCKPILE_TYPE_ID: int = Catalog.BUILDING_DEFINITION[StarterStructures.OPEN_STOCKPILE_KEY]


class Applied:
	"""The refs one apply published, in plan order, as slot and generation columns.

	Cold, caller-owned, sized once. Not simulation state: the rows themselves live in
	`buildings.gd`, and this record only lets the caller verify them against the plan.
	"""
	var building_slot: PackedInt32Array = PackedInt32Array()
	var building_generation: PackedInt32Array = PackedInt32Array()
	var room_slot: PackedInt32Array = PackedInt32Array()
	var room_generation: PackedInt32Array = PackedInt32Array()
	var furniture_slot: PackedInt32Array = PackedInt32Array()
	var furniture_generation: PackedInt32Array = PackedInt32Array()

	func _init() -> void:
		"""Size the six columns once and fill them with the null ref."""
		building_slot.resize(Plan.BUILDING_ROW_COUNT)
		building_generation.resize(Plan.BUILDING_ROW_COUNT)
		room_slot.resize(Plan.ROOM_ROW_COUNT)
		room_generation.resize(Plan.ROOM_ROW_COUNT)
		furniture_slot.resize(Plan.FURNITURE_ROW_COUNT)
		furniture_generation.resize(Plan.FURNITURE_ROW_COUNT)
		clear()

	func clear() -> void:
		"""Return every ref to the null ref `(-1, 0)`."""
		building_slot.fill(EntityDirectory.NULL_SLOT)
		building_generation.fill(EntityDirectory.NULL_GENERATION)
		room_slot.fill(EntityDirectory.NULL_SLOT)
		room_generation.fill(EntityDirectory.NULL_GENERATION)
		furniture_slot.fill(EntityDirectory.NULL_SLOT)
		furniture_generation.fill(EntityDirectory.NULL_GENERATION)

	func building_ref(row: int) -> Vector2i:
		"""The building placed for plan row `row`."""
		return Vector2i(building_slot[row], building_generation[row])

	func room_ref(ordinal: int) -> Vector2i:
		"""The room designated for plan room ordinal `ordinal`."""
		return Vector2i(room_slot[ordinal], room_generation[ordinal])

	func furniture_ref(row: int) -> Vector2i:
		"""The furniture placed for plan furniture row `row`."""
		return Vector2i(furniture_slot[row], furniture_generation[row])


class StoreBinding:
	"""Answer #7's owners and #3a's anchors for the starter stores, read back from live rows.

	The pantry is owned by the hall and anchored at the hall's origin tile; each of the four
	material stockpile containers is owned by one open stockpile and anchored at its origin tile,
	in plan order -- which is container-ID order when the stores are opened in it (§5.9's "filling
	container IDs ascending").
	"""
	var pantry_owner: Vector2i = EntityDirectory.NULL_REF
	var pantry_anchor_tile: int = -1
	var stockpile_slot: PackedInt32Array = PackedInt32Array()
	var stockpile_generation: PackedInt32Array = PackedInt32Array()
	var stockpile_anchor_tile: PackedInt32Array = PackedInt32Array()

	func _init() -> void:
		"""Size the stockpile columns once and clear them."""
		stockpile_slot.resize(STOCKPILE_COUNT)
		stockpile_generation.resize(STOCKPILE_COUNT)
		stockpile_anchor_tile.resize(STOCKPILE_COUNT)
		clear()

	func clear() -> void:
		"""Return every owner to the null ref and every anchor to unplaced."""
		pantry_owner = EntityDirectory.NULL_REF
		pantry_anchor_tile = -1
		stockpile_slot.fill(EntityDirectory.NULL_SLOT)
		stockpile_generation.fill(EntityDirectory.NULL_GENERATION)
		stockpile_anchor_tile.fill(-1)

	func stockpile_owner(index: int) -> Vector2i:
		"""The open stockpile that owns material store `index`."""
		return Vector2i(stockpile_slot[index], stockpile_generation[index])

	func is_complete() -> bool:
		"""True when all five owners are well formed and all five anchors are placement cells."""
		if not _well_formed(pantry_owner, pantry_anchor_tile):
			return false
		for index: int in STOCKPILE_COUNT:
			if not _well_formed(stockpile_owner(index), stockpile_anchor_tile[index]):
				return false
		return true

	func _well_formed(ref: Vector2i, tile: int) -> bool:
		"""Inventory's own owner-shape rule (decision 0533) and an in-grid anchor."""
		return InventoryScript.is_well_formed_owner(ref) \
			and tile >= 0 and tile < BuildingsScript.TILE_COUNT


# --- preflight ------------------------------------------------------------------------------------

static func preflight_refusal(buildings: BuildingsScript, plan: Plan,
		unlocked_mask: int) -> StringName:
	"""Everything `apply_into()` needs, proved without writing: plan, placements, directory rows."""
	if buildings == null:
		return REFUSE_STORE_NULL
	if plan == null:
		return REFUSE_PLAN_NULL
	var plan_code: StringName = StarterStructures.plan_refusal(plan)
	if plan_code != StarterStructures.REFUSE_NONE:
		return plan_code
	for row: int in Plan.BUILDING_ROW_COUNT:
		var code: StringName = buildings.placement_refusal(
			plan.building_field(row, Plan.BUILDING_COL_TYPE_ID),
			plan.building_field(row, Plan.BUILDING_COL_GLOBAL_ORIGIN_TILE),
			plan.building_field(row, Plan.BUILDING_COL_ROTATION), unlocked_mask)
		if code != BuildingsScript.REFUSE_NONE:
			return code
	return _capacity_refusal(buildings)


static func _capacity_refusal(buildings: BuildingsScript) -> StringName:
	"""Every Building, Room and Furniture row the apply will take must be free now.

	The room-tile arena needs no check of its own: it holds one link per tile that is in a room,
	and the 120 tiles of a free hall footprint are in none, so 80 more always fit. A directory
	SLOT can still run short of the rows if generations have retired slots; then `create()` refuses
	mid-apply and the caller's reset recovers, as the module header says.
	"""
	var directory: EntityDirectory = buildings.directory()
	if directory.free_row_count(EntityDirectory.KIND_BUILDING) < Plan.BUILDING_ROW_COUNT \
			or directory.free_row_count(EntityDirectory.KIND_ROOM) < Plan.ROOM_ROW_COUNT \
			or directory.free_row_count(EntityDirectory.KIND_FURNITURE) < Plan.FURNITURE_ROW_COUNT:
		return REFUSE_DIRECTORY_CAPACITY
	return REFUSE_NONE


# --- apply ----------------------------------------------------------------------------------------

static func apply_into(buildings: BuildingsScript, plan: Plan, unlocked_mask: int,
		out: Applied) -> StringName:
	"""Preflight, then place the buildings, rooms and furniture in plan order into `out`.

	A refusal after the preflight leaves a partial colony: the caller resets (module header).
	"""
	var code: StringName = preflight_refusal(buildings, plan, unlocked_mask)
	if code != REFUSE_NONE:
		return code
	out.clear()
	code = _place_buildings(buildings, plan, unlocked_mask, out)
	if code != REFUSE_NONE:
		return code
	code = _designate_rooms(buildings, plan, out)
	if code != REFUSE_NONE:
		return code
	return _place_furniture(buildings, plan, out)


static func _place_buildings(buildings: BuildingsScript, plan: Plan, unlocked_mask: int,
		out: Applied) -> StringName:
	"""Place every building row, then give it the plan's desired state.

	The tier is not written: `place_building()` writes tier 1 and the authored plan asks for 1.
	`plan_mismatch_refusal()` re-reads it, so a plan asking for another tier is refused rather
	than silently accepted.
	"""
	for row: int in Plan.BUILDING_ROW_COUNT:
		var placed: BuildingsScript.OpResult = buildings.place_building(
			plan.building_field(row, Plan.BUILDING_COL_TYPE_ID),
			plan.building_field(row, Plan.BUILDING_COL_GLOBAL_ORIGIN_TILE),
			plan.building_field(row, Plan.BUILDING_COL_ROTATION), unlocked_mask)
		if not placed.ok:
			return placed.error
		out.building_slot[row] = placed.ref.x
		out.building_generation[row] = placed.ref.y
		var state: BuildingsScript.OpResult = buildings.set_building_state(placed.ref,
			plan.building_field(row, Plan.BUILDING_COL_DESIRED_STATE))
		if not state.ok:
			return state.error
	return REFUSE_NONE


static func _designate_rooms(buildings: BuildingsScript, plan: Plan, out: Applied) -> StringName:
	"""Designate the four rooms over the hall, each from its own run of the plan's room tiles."""
	var hall: Vector2i = out.building_ref(hall_row_of(plan))
	for ordinal: int in Plan.ROOM_ROW_COUNT:
		var offset: int = plan.room_field(ordinal, Plan.ROOM_COL_TILE_OFFSET)
		var count: int = plan.room_field(ordinal, Plan.ROOM_COL_TILE_COUNT)
		var tiles: PackedInt32Array = plan.room_tiles.slice(offset, offset + count)
		var made: BuildingsScript.OpResult = buildings.designate_room(hall,
			plan.room_field(ordinal, Plan.ROOM_COL_TYPE_ID), tiles)
		if not made.ok:
			return made.error
		out.room_slot[ordinal] = made.ref.x
		out.room_generation[ordinal] = made.ref.y
	return REFUSE_NONE


static func _place_furniture(buildings: BuildingsScript, plan: Plan, out: Applied) -> StringName:
	"""Place the thirty-one floor furniture at their global origins, into their plan rooms."""
	var hall_origin: int = plan.building_field(hall_row_of(plan), Plan.BUILDING_COL_GLOBAL_ORIGIN_TILE)
	for row: int in Plan.FURNITURE_ROW_COUNT:
		var room: Vector2i = out.room_ref(plan.furniture_field(row, Plan.FURNITURE_COL_ROOM_ORDINAL))
		var placed: BuildingsScript.OpResult = buildings.place_furniture(room,
			plan.furniture_field(row, Plan.FURNITURE_COL_TYPE_ID),
			interior_to_global(plan.furniture_field(row, Plan.FURNITURE_COL_ORIGIN_LOCAL),
				hall_origin),
			plan.furniture_field(row, Plan.FURNITURE_COL_ROTATION))
		if not placed.ok:
			return placed.error
		out.furniture_slot[row] = placed.ref.x
		out.furniture_generation[row] = placed.ref.y
	return REFUSE_NONE


# --- geometry -------------------------------------------------------------------------------------

static func hall_row_of(plan: Plan) -> int:
	"""The plan's hall building row. `plan_refusal()` has already proved there is exactly one."""
	for row: int in Plan.BUILDING_ROW_COUNT:
		if plan.building_field(row, Plan.BUILDING_COL_TYPE_ID) == HALL_TYPE_ID:
			return row
	return -1


static func interior_to_global(local_tile: int, hall_origin_tile: int) -> int:
	"""GDD §5.9: interior-local `z*10+x` to the exterior `z*128+x`, interior origin = hall + (1,1)."""
	@warning_ignore("integer_division")
	var local_z: int = local_tile / StarterStructures.INTERIOR_WIDTH
	var local_x: int = local_tile % StarterStructures.INTERIOR_WIDTH
	@warning_ignore("integer_division")
	var hall_z: int = hall_origin_tile / BuildingsScript.MAP_TILES_X
	var hall_x: int = hall_origin_tile % BuildingsScript.MAP_TILES_X
	return (hall_z + StarterStructures.INTERIOR_INSET_TILES + local_z) * BuildingsScript.MAP_TILES_X \
		+ hall_x + StarterStructures.INTERIOR_INSET_TILES + local_x


# --- verification against the plan ---------------------------------------------------------------

static func plan_mismatch_refusal(buildings: BuildingsScript, plan: Plan,
		applied: Applied) -> StringName:
	"""Re-read every placed row and compare it with the plan, field by field.

	REFUSE_NONE only when exactly the planned buildings, rooms and furniture are live with the
	planned type, tiles, rotation, tier, state and parent.
	"""
	for row: int in Plan.BUILDING_ROW_COUNT:
		if not _building_matches(buildings, plan, row, applied.building_ref(row)):
			return REFUSE_PLAN_MISMATCH
	var hall: Vector2i = applied.building_ref(hall_row_of(plan))
	for ordinal: int in Plan.ROOM_ROW_COUNT:
		if not _room_matches(buildings, plan, ordinal, applied.room_ref(ordinal), hall):
			return REFUSE_PLAN_MISMATCH
	var hall_origin: int = plan.building_field(hall_row_of(plan), Plan.BUILDING_COL_GLOBAL_ORIGIN_TILE)
	for row: int in Plan.FURNITURE_ROW_COUNT:
		if not _furniture_matches(buildings, plan, row, applied, hall_origin):
			return REFUSE_PLAN_MISMATCH
	return REFUSE_NONE


static func _building_matches(buildings: BuildingsScript, plan: Plan, row: int,
		ref: Vector2i) -> bool:
	"""One building row's type, origin, rotation, tier and state, and its origin tile's owner."""
	var origin: int = plan.building_field(row, Plan.BUILDING_COL_GLOBAL_ORIGIN_TILE)
	return buildings.is_live_building(ref) \
		and buildings.building_at_tile(origin) == ref \
		and _reads(buildings.type_id_of_building(ref), plan.building_field(row, Plan.BUILDING_COL_TYPE_ID)) \
		and _reads(buildings.origin_tile_of_building(ref), origin) \
		and _reads(buildings.rotation_of_building(ref), plan.building_field(row, Plan.BUILDING_COL_ROTATION)) \
		and _reads(buildings.tier_of_building(ref), plan.building_field(row, Plan.BUILDING_COL_TIER)) \
		and _reads(buildings.state_of_building(ref), plan.building_field(row, Plan.BUILDING_COL_DESIRED_STATE))


static func _room_matches(buildings: BuildingsScript, plan: Plan, ordinal: int, ref: Vector2i,
		hall: Vector2i) -> bool:
	"""One room's type, parent hall and exact tile run, in plan order."""
	var offset: int = plan.room_field(ordinal, Plan.ROOM_COL_TILE_OFFSET)
	var count: int = plan.room_field(ordinal, Plan.ROOM_COL_TILE_COUNT)
	if not buildings.is_live_room(ref) or buildings.room_building_ref_of(ref) != hall:
		return false
	if not _reads(buildings.type_of_room(ref), plan.room_field(ordinal, Plan.ROOM_COL_TYPE_ID)) \
			or not _reads(buildings.tile_count_of_room(ref), count):
		return false
	for index: int in count:
		if not _reads(buildings.room_tile_at(ref, index), plan.room_tiles[offset + index]):
			return false
	return true


static func _furniture_matches(buildings: BuildingsScript, plan: Plan, row: int, applied: Applied,
		hall_origin: int) -> bool:
	"""One furniture row's type, global origin, rotation and room."""
	var ref: Vector2i = applied.furniture_ref(row)
	var room: Vector2i = applied.room_ref(plan.furniture_field(row, Plan.FURNITURE_COL_ROOM_ORDINAL))
	var origin: int = interior_to_global(
		plan.furniture_field(row, Plan.FURNITURE_COL_ORIGIN_LOCAL), hall_origin)
	return buildings.is_live_furniture(ref) \
		and buildings.room_ref_of_furniture(ref) == room \
		and _reads(buildings.type_id_of_furniture(ref), plan.furniture_field(row, Plan.FURNITURE_COL_TYPE_ID)) \
		and _reads(buildings.origin_tile_of_furniture(ref), origin) \
		and _reads(buildings.rotation_of_furniture(ref), plan.furniture_field(row, Plan.FURNITURE_COL_ROTATION))


static func _reads(result: BuildingsScript.OpResult, expected: int) -> bool:
	"""True when a store read succeeded and carries exactly `expected`."""
	return result.ok and result.value == expected


# --- the store binding ----------------------------------------------------------------------------

static func store_binding_into(buildings: BuildingsScript, plan: Plan,
		out: StoreBinding) -> StringName:
	"""Read the hall and the four stockpiles back from the LIVE store at their planned origins.

	Refuses REFUSE_NOT_PLACED -- leaving `out` cleared -- unless the hall and exactly
	STOCKPILE_COUNT open stockpiles stand at the plan's origin tiles. Reading the live store
	rather than a remembered apply record is what keeps the binding honest after a reset.
	"""
	out.clear()
	if buildings == null or plan == null:
		return REFUSE_NOT_PLACED
	var found: int = 0
	for row: int in Plan.BUILDING_ROW_COUNT:
		var type_id: int = plan.building_field(row, Plan.BUILDING_COL_TYPE_ID)
		var origin: int = plan.building_field(row, Plan.BUILDING_COL_GLOBAL_ORIGIN_TILE)
		var ref: Vector2i = _standing_at(buildings, type_id, origin)
		if type_id == HALL_TYPE_ID:
			out.pantry_owner = ref
			out.pantry_anchor_tile = origin
		elif type_id == STOCKPILE_TYPE_ID:
			if found == STOCKPILE_COUNT:
				found += 1
				break
			out.stockpile_slot[found] = ref.x
			out.stockpile_generation[found] = ref.y
			out.stockpile_anchor_tile[found] = origin
			found += 1
	if found != STOCKPILE_COUNT or not out.is_complete():
		out.clear()
		return REFUSE_NOT_PLACED
	return REFUSE_NONE


static func _standing_at(buildings: BuildingsScript, type_id: int, origin: int) -> Vector2i:
	"""The live building of `type_id` whose origin is exactly `origin`, or the null ref."""
	var ref: Vector2i = buildings.building_at_tile(origin)
	if ref == EntityDirectory.NULL_REF or not _reads(buildings.type_id_of_building(ref), type_id) \
			or not _reads(buildings.origin_tile_of_building(ref), origin):
		return EntityDirectory.NULL_REF
	return ref
