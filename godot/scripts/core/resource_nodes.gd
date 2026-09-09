extends RefCounted
## The ResourceNode store: tree/stone/iron sources, and the exterior-tile placement primitive
## that decides which tile each one stands on.
##
## SCHEMA. GDD §4.2 states the row exactly: `resource_id: int32, quantity_milli: int64,
## capacity_milli: int64, regrow_days: int32, planted_day: int32, exhausted: bool`, with the
## capacity note "Tree/stone/iron source; at most 4096". systems_architecture.md §2 repeats the
## 4096 for the `resource_id, regrow_days, planted_day` I32 block, and entity_directory.gd
## already reserves `KIND_RESOURCE_NODE` at 4096 rows. All three agree, and `_init()` asserts it
## rather than trusting the agreement.
##
## WHAT THIS OWNS AND WHAT IT DOES NOT.
##   * `entity_directory.gd` owns slot allocation, `(slot, generation)` refs and the 4096-row
##     arena. Every node here is created through `create(KIND_RESOURCE_NODE)`, so there is one
##     allocator and one generation counter, exactly as `residents.gd` does it.
##   * `sim_clock.gd` owns the calendar. `planted_day` and every `day` argument below are its
##     `Calendar.absolute_day`, which is 1 on the first day (GDD §5.1: "starting at year 1/
##     spring/day 1/06:00"). This store never reads a clock; the caller passes today's day, so
##     the store cannot disagree with the world about what day it is.
##   * `int_math.gd` owns checked arithmetic. `planted_day + regrow_days` is an int32 sum and
##     goes through `checked_add_into`; it refuses rather than wrapping a maturity date.
##
## THE TILE PRIMITIVE. GDD §5.1: "Exterior tile index is `z*128+x`; tile center in simulation
## units is `(2048*x+1024,0,2048*z+1024)`." A 128x128 exterior grid is 16384 tiles, which is the
## exact row count systems_architecture.md §2 gives `WorldTileMaps` -- so the four-column tile
## store and this formula describe the same grid. `WorldTileMaps.resource_slot` is the tile ->
## node map, and it is carried here, in the only module that can keep it truthful, until a
## `WorldTileMaps` store exists to hold all four columns. `building_slot`, `room_slot` and
## `zone_link_head` are deliberately absent: this increment does not need them and inventing
## them here would fork ownership with the stores that will.
##
## Invariant: a tile holds at most one resource node, enforced by REFUSING a second create on an
## occupied tile. §5.1's "Ore footprints replace tree nodes" is a world-generation instruction
## and is expressed as an explicit `destroy()` then `create_at_tile()`, never as a silent
## overwrite -- an overwrite would strand a live directory row with no tile and no owner.
##
## HARVEST AND REGROWTH. REQ-SET-138: "When a tree is felled, the system shall debit its wood
## once and leave a dated stump for permitted regrowth." `harvest_all()` is that single debit;
## BAL-SAFE-012 ("Tree harvest repeats before debit ... debit the node once and retain its stump
## date") is why an exhausted node refuses every further harvest instead of yielding 0 again.
## Reaching quantity 0 sets `exhausted` and dates the stump with the felling day, which is also
## the start of the regrowth cycle GDD §5.9 measures: "Trees regrow after 48 days when their
## stumps remain and no building occupies the tile".
##
## GAPS -- named, not invented (AGENTS.md: "do not invent a constant"):
##   * `resource_id`'s DOMAIN IS UNSTATED. GDD §4.2 types it `int32` and never says whether it
##     is a compiled `ItemDefinition` id (§5.9's extraction recipes yield wood/stone/iron items,
##     which suggests it) or a separate resource catalog. This store therefore validates the
##     range only and refuses a negative id; no compiled id is ever negative.
##   * `regrow_days == 0` IS READ AS "NEVER REGROWS". The specification gives a regrow period for
##     trees (§5.9, 48 days) and none for stone or iron, while stating surface stone deposits
##     "can exhaust". The field must express a non-renewable node somehow, and treating a zero
##     period as instantaneous regrowth would make every exhausted quarry refill the same day.
##   * REQ-SET-138's "no building occupies the tile" CONDITION CANNOT BE EVALUATED HERE. It reads
##     `WorldTileMaps.building_slot`, which no store owns yet. `is_regrow_ready()` implements the
##     day condition alone; the ecology system (ARCH-SYS-005) must apply the occupancy condition
##     before calling `regrow()`, and this comment is the record that it is still missing.
##   * §5.1's "footprint 4x4" DEPOSITS HAVE NO SCHEMA. The §4.2 row has no footprint field and a
##     tile holds one node, so a 4x4 stone deposit of 1200 U is either 16 nodes whose per-tile
##     split the document never states, or one node with an extent the schema cannot store. That
##     is world generation's blocker (REQ-SET-009, a later increment), not this store's, and no
##     grove, deposit or per-node quantity from §5.1 is compiled in here.
##   * The `FarmPlot` tile-backing store of ARCH-STATE-003 is NOT built here. Its per-tile soil
##     history must outlive a deleted row, but its fields and capacity are itemised nowhere; see
##     docs/tasks/03_ecology_crops_weather.md.

const IntMath := preload("res://scripts/core/int_math.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")

## GDD §4.2: "Tree/stone/iron source; at most 4096".
const RESOURCE_NODE_CAPACITY: int = 4096

## GDD §5.1 exterior grid: index `z*128+x`, so both axes run 0..127 and the grid is 16384 tiles
## -- the row count systems_architecture.md §2 gives `WorldTileMaps`.
const MAP_TILES_X: int = 128
const MAP_TILES_Z: int = 128
const TILE_COUNT: int = MAP_TILES_X * MAP_TILES_Z

## GDD §5.1: "tile center in simulation units is `(2048*x+1024,0,2048*z+1024)`". The literal
## formula puts the centre at y=0; terrain elevation (land 512, ford -128) is a separate mask
## this store does not own.
const TILE_SIZE_UNITS: int = 2048
const TILE_CENTER_OFFSET_UNITS: int = 1024
const TILE_CENTER_Y_UNITS: int = 0

## GDD §5.1 starts the calendar at day 1; `sim_clock.gd`'s `absolute_day` is 1 at tick 0. Day 0
## names no day, so it is refused rather than stored as a plausible planting date.
const MIN_CALENDAR_DAY: int = 1

## Empty value of the `WorldTileMaps.resource_slot` column, matching the directory's null slot.
const NO_NODE: int = EntityDirectory.NULL_SLOT

const NULL_REF: Vector2i = EntityDirectory.NULL_REF

const REFUSE_NONE: StringName = &""
const REFUSE_INVALID_TILE: StringName = &"INVALID_TILE"
const REFUSE_INVALID_TILE_COORDINATE: StringName = &"INVALID_TILE_COORDINATE"
const REFUSE_TILE_OCCUPIED: StringName = &"TILE_OCCUPIED"
const REFUSE_TILE_EMPTY: StringName = &"TILE_EMPTY"
const REFUSE_NOT_PRESENT: StringName = &"RESOURCE_NODE_NOT_PRESENT"
const REFUSE_INVALID_RESOURCE_ID: StringName = &"INVALID_RESOURCE_ID"
const REFUSE_INVALID_CAPACITY: StringName = &"INVALID_CAPACITY"
const REFUSE_INVALID_REGROW_DAYS: StringName = &"INVALID_REGROW_DAYS"
const REFUSE_INVALID_DAY: StringName = &"INVALID_DAY"
const REFUSE_INVALID_AMOUNT: StringName = &"INVALID_AMOUNT"
const REFUSE_INSUFFICIENT_QUANTITY: StringName = &"INSUFFICIENT_QUANTITY"
const REFUSE_NODE_EXHAUSTED: StringName = &"NODE_EXHAUSTED"
const REFUSE_NODE_NOT_EXHAUSTED: StringName = &"NODE_NOT_EXHAUSTED"
const REFUSE_NOT_RENEWABLE: StringName = &"NOT_RENEWABLE"
const REFUSE_REGROW_NOT_DUE: StringName = &"REGROW_NOT_DUE"
const REFUSE_INVALID_INDEX: StringName = &"INVALID_INDEX"
const REFUSE_OVERFLOW: StringName = &"OVERFLOW"


class OpResult:
	"""Outcome of one resource-node operation: success flag, refusal code, value and reference.

	`.ok` MUST be inspected before `.value` or `.ref` is used. A refusal always carries value 0
	and the null reference, and never a partially applied effect.
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


# --- collaborators ----------------------------------------------------------------------------

var _directory: EntityDirectory = null
var _owns_directory: bool = false

# --- ResourceNode columns (ARCH-MEM-001: packed, allocated once, indexed by typed row) --------

var _present: PackedByteArray = PackedByteArray()
var _resource_id: PackedInt32Array = PackedInt32Array()
var _quantity_milli: PackedInt64Array = PackedInt64Array()
var _capacity_milli: PackedInt64Array = PackedInt64Array()
var _regrow_days: PackedInt32Array = PackedInt32Array()
var _planted_day: PackedInt32Array = PackedInt32Array()
var _exhausted: PackedByteArray = PackedByteArray()

## Reverse of `WorldTileMaps.resource_slot`: the tile each live row stands on. The pair is kept
## consistent by every mutator here, the way the directory keeps `_typed_row` and
## `_typed_owner_slot` consistent, so neither direction can be believed on its own.
var _tile: PackedInt32Array = PackedInt32Array()

## The directory reference owning each row, so a row can hand back a validatable ref.
var _ref_slot: PackedInt32Array = PackedInt32Array()
var _ref_generation: PackedInt32Array = PackedInt32Array()

## `WorldTileMaps.resource_slot`, systems_architecture.md §2: one int32 per exterior tile,
## `NO_NODE` where no node stands.
var _resource_slot: PackedInt32Array = PackedInt32Array()

## Ascending list of live rows, so a daily ecology sweep iterates the nodes and not all 4096.
var _live_slots: PackedInt32Array = PackedInt32Array()
var _live_count: int = 0

# --- scratch (not simulation state) -----------------------------------------------------------

## Checked-arithmetic scratch for int_math's `_into` forms. Nothing here invokes a callback or a
## signal, so no public operation can re-enter while it holds a live value.
var _math: IntMath.IntResult = IntMath.IntResult.new()


func _init(p_directory: EntityDirectory = null) -> void:
	"""Allocate every column once and adopt or build the directory behind every node reference.

	Passing an existing directory shares it; passing none creates a private one, which is what a
	test or a standalone fixture wants.
	"""
	assert(RESOURCE_NODE_CAPACITY
			== EntityDirectory.KIND_CAPACITY[EntityDirectory.KIND_RESOURCE_NODE],
		"resource-node columns must match the directory's RESOURCE_NODE row capacity")
	_owns_directory = p_directory == null
	_directory = p_directory if p_directory != null else EntityDirectory.new()
	_allocate_columns()
	clear()


func _allocate_columns() -> void:
	"""The only place that sizes a packed array (ARCH-MEM-005: allocate once)."""
	_present.resize(RESOURCE_NODE_CAPACITY)
	_resource_id.resize(RESOURCE_NODE_CAPACITY)
	_quantity_milli.resize(RESOURCE_NODE_CAPACITY)
	_capacity_milli.resize(RESOURCE_NODE_CAPACITY)
	_regrow_days.resize(RESOURCE_NODE_CAPACITY)
	_planted_day.resize(RESOURCE_NODE_CAPACITY)
	_exhausted.resize(RESOURCE_NODE_CAPACITY)
	_tile.resize(RESOURCE_NODE_CAPACITY)
	_ref_slot.resize(RESOURCE_NODE_CAPACITY)
	_ref_generation.resize(RESOURCE_NODE_CAPACITY)
	_live_slots.resize(RESOURCE_NODE_CAPACITY)
	_resource_slot.resize(TILE_COUNT)


func clear() -> void:
	"""Return every column to its empty state without reallocating one of them.

	Every live row's directory slot is released first. A shared directory belongs to its owner
	and is not cleared here, so dropping the rows one by one is the only way this store can avoid
	stranding 4096 allocated slots in a directory it does not own.
	"""
	_release_live_rows()
	_present.fill(0)
	_resource_id.fill(0)
	_quantity_milli.fill(0)
	_capacity_milli.fill(0)
	_regrow_days.fill(0)
	_planted_day.fill(0)
	_exhausted.fill(0)
	_tile.fill(NO_NODE)
	_ref_slot.fill(EntityDirectory.NULL_SLOT)
	_ref_generation.fill(EntityDirectory.NULL_GENERATION)
	_live_slots.fill(EntityDirectory.NULL_SLOT)
	_resource_slot.fill(NO_NODE)
	_live_count = 0
	if _owns_directory:
		_directory.clear()


func _release_live_rows() -> void:
	"""Destroy the directory slot of every live row, so a clear leaks no allocation."""
	for index: int in _live_count:
		var slot: int = _live_slots[index]
		if slot < 0 or slot >= RESOURCE_NODE_CAPACITY or _present[slot] != 1:
			continue
		_directory.destroy(Vector2i(_ref_slot[slot], _ref_generation[slot]))


func directory() -> EntityDirectory:
	"""The allocator behind every resource-node reference."""
	return _directory


# --- GDD §5.1 exterior tile geometry -----------------------------------------------------------

func is_tile_index(tile: int) -> bool:
	"""True when `tile` addresses one of the 16384 exterior tiles."""
	return tile >= 0 and tile < TILE_COUNT


func tile_index(x: int, z: int) -> IntMath.IntResult:
	"""GDD §5.1 exterior tile index `z*128+x`, or an explicit refusal off the 128x128 grid."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	tile_index_into(x, z, out)
	return out


func tile_index_into(x: int, z: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating tile_index(): write `z*128+x` into caller-owned `out`, return out.ok."""
	if x < 0 or x >= MAP_TILES_X or z < 0 or z >= MAP_TILES_Z:
		return out.refuse(String(REFUSE_INVALID_TILE_COORDINATE))
	return out.succeed(z * MAP_TILES_X + x)


func tile_x_of(tile: int) -> IntMath.IntResult:
	"""The x coordinate a tile index decodes to, or an explicit refusal."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_tile_index(tile):
		out.refuse(String(REFUSE_INVALID_TILE))
		return out
	out.succeed(tile % MAP_TILES_X)
	return out


func tile_z_of(tile: int) -> IntMath.IntResult:
	"""The z coordinate a tile index decodes to, or an explicit refusal."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_tile_index(tile):
		out.refuse(String(REFUSE_INVALID_TILE))
		return out
	out.succeed(tile / MAP_TILES_X)
	return out


func tile_center_x_units(tile: int) -> IntMath.IntResult:
	"""GDD §5.1 tile-centre x in simulation units, `2048*x+1024`, or an explicit refusal."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_tile_index(tile):
		out.refuse(String(REFUSE_INVALID_TILE))
		return out
	out.succeed((tile % MAP_TILES_X) * TILE_SIZE_UNITS + TILE_CENTER_OFFSET_UNITS)
	return out


func tile_center_z_units(tile: int) -> IntMath.IntResult:
	"""GDD §5.1 tile-centre z in simulation units, `2048*z+1024`, or an explicit refusal."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_tile_index(tile):
		out.refuse(String(REFUSE_INVALID_TILE))
		return out
	out.succeed((tile / MAP_TILES_X) * TILE_SIZE_UNITS + TILE_CENTER_OFFSET_UNITS)
	return out


# --- placement: the WorldTileMaps.resource_slot column ------------------------------------------

func has_node_at_tile(tile: int) -> bool:
	"""True when an exterior tile carries a live resource node."""
	return is_tile_index(tile) and _resource_slot[tile] != NO_NODE


func slot_at_tile(tile: int) -> IntMath.IntResult:
	"""The row standing on a tile, or an explicit refusal for an off-grid or empty tile."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_tile_index(tile):
		out.refuse(String(REFUSE_INVALID_TILE))
		return out
	if _resource_slot[tile] == NO_NODE:
		out.refuse(String(REFUSE_TILE_EMPTY))
		return out
	out.succeed(_resource_slot[tile])
	return out


func ref_at_tile(tile: int) -> Vector2i:
	"""The reference standing on a tile, or the GDD §4.1 null reference `(-1, 0)` when none does.

	The null reference is the specification's own "no entity" value and fails `is_valid()`; it is
	not a failure sentinel. `slot_at_tile()` is the form that refuses with a reason.
	"""
	if not has_node_at_tile(tile):
		return NULL_REF
	return ref_of(_resource_slot[tile])


# --- lifecycle -----------------------------------------------------------------------------------

func create_at_tile(tile: int, resource_id: int, capacity_milli: int, regrow_days: int,
		planted_day: int) -> OpResult:
	"""Place one full resource node on an empty exterior tile.

	The node starts at its capacity: GDD §5.1 generates mature sources ("Each mature node
	contains 12 wood U"), and every other state is reached through `harvest()` and `regrow()`.
	Refuses -- allocating nothing -- on an off-grid tile, an occupied tile, a negative resource
	id, a non-positive capacity, a negative regrow period, or a day before day 1.
	"""
	var code: StringName = _refuse_create(tile, resource_id, capacity_milli, regrow_days,
		planted_day)
	if code != REFUSE_NONE:
		return _refuse(code)
	var ref: Vector2i = _directory.create(EntityDirectory.KIND_RESOURCE_NODE)
	if ref == NULL_REF:
		return _refuse(_directory.last_refusal())
	var slot: int = _directory.get_typed_row(ref)
	_write_created_row(slot, ref, tile, resource_id, capacity_milli, regrow_days, planted_day)
	return _succeed(slot, ref)


func _refuse_create(tile: int, resource_id: int, capacity_milli: int, regrow_days: int,
		planted_day: int) -> StringName:
	"""The code blocking a create, or REFUSE_NONE when every argument is storable."""
	if not is_tile_index(tile):
		return REFUSE_INVALID_TILE
	if _resource_slot[tile] != NO_NODE:
		return REFUSE_TILE_OCCUPIED
	if resource_id < 0 or not IntMath.fits_int32(resource_id):
		return REFUSE_INVALID_RESOURCE_ID
	if capacity_milli <= 0:
		return REFUSE_INVALID_CAPACITY
	if regrow_days < 0 or not IntMath.fits_int32(regrow_days):
		return REFUSE_INVALID_REGROW_DAYS
	return _check_day(planted_day)


func _write_created_row(slot: int, ref: Vector2i, tile: int, resource_id: int,
		capacity_milli: int, regrow_days: int, planted_day: int) -> void:
	"""Write every §4.2 column of a freshly placed node and link it to its tile both ways."""
	_present[slot] = 1
	_resource_id[slot] = resource_id
	_quantity_milli[slot] = capacity_milli
	_capacity_milli[slot] = capacity_milli
	_regrow_days[slot] = regrow_days
	_planted_day[slot] = planted_day
	_exhausted[slot] = 0
	_tile[slot] = tile
	_ref_slot[slot] = ref.x
	_ref_generation[slot] = ref.y
	_resource_slot[tile] = slot
	_insert_live_slot(slot)


func destroy(ref: Vector2i) -> OpResult:
	"""Remove one node, free its tile and release its directory slot. Returns the freed tile.

	Refuses a stale or wrong-kind reference rather than clearing whatever row it points at, which
	is what makes a reused slot safe: the old reference's generation no longer validates.
	"""
	if not _directory.is_valid_of_kind(ref, EntityDirectory.KIND_RESOURCE_NODE):
		return _refuse(REFUSE_NOT_PRESENT)
	var slot: int = _directory.get_typed_row(ref)
	if not is_present(slot):
		return _refuse(REFUSE_NOT_PRESENT)
	var tile: int = _tile[slot]
	if is_tile_index(tile) and _resource_slot[tile] == slot:
		_resource_slot[tile] = NO_NODE
	_present[slot] = 0
	_quantity_milli[slot] = 0
	_exhausted[slot] = 0
	_tile[slot] = NO_NODE
	_ref_slot[slot] = EntityDirectory.NULL_SLOT
	_ref_generation[slot] = EntityDirectory.NULL_GENERATION
	_remove_live_slot(slot)
	_directory.destroy(ref)
	return _succeed(tile, NULL_REF)


func _insert_live_slot(slot: int) -> void:
	"""Insert a created row into the ascending live list, keeping iteration order stable."""
	var index: int = _live_count
	while index > 0 and _live_slots[index - 1] > slot:
		_live_slots[index] = _live_slots[index - 1]
		index -= 1
	_live_slots[index] = slot
	_live_count += 1


func _remove_live_slot(slot: int) -> void:
	"""Remove a row from the ascending live list, closing the gap behind it."""
	var index: int = 0
	while index < _live_count and _live_slots[index] != slot:
		index += 1
	if index >= _live_count:
		return
	while index + 1 < _live_count:
		_live_slots[index] = _live_slots[index + 1]
		index += 1
	_live_count -= 1
	_live_slots[_live_count] = EntityDirectory.NULL_SLOT


# --- readers ---------------------------------------------------------------------------------------

func is_present(slot: int) -> bool:
	"""True when `slot` is in range and holds a placed resource node."""
	return slot >= 0 and slot < RESOURCE_NODE_CAPACITY and _present[slot] == 1


func count() -> int:
	"""Number of live resource nodes."""
	return _live_count


func live_slot_at(index: int) -> IntMath.IntResult:
	"""The `index`-th live row in ascending slot order, or an explicit refusal."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if index < 0 or index >= _live_count:
		out.refuse(String(REFUSE_INVALID_INDEX))
		return out
	out.succeed(_live_slots[index])
	return out


func ref_of(slot: int) -> Vector2i:
	"""The directory reference owning a row, or the null reference when the row is empty."""
	if not is_present(slot):
		return NULL_REF
	return Vector2i(_ref_slot[slot], _ref_generation[slot])


func tile_of(slot: int) -> IntMath.IntResult:
	"""The exterior tile a row stands on, or an explicit refusal."""
	return _read(slot, _tile)


func resource_id_of(slot: int) -> IntMath.IntResult:
	"""The row's resource id, or an explicit refusal. See the header on its unstated domain."""
	return _read(slot, _resource_id)


func regrow_days_of(slot: int) -> IntMath.IntResult:
	"""The row's regrowth period in days; 0 means the node never regrows."""
	return _read(slot, _regrow_days)


func planted_day_of(slot: int) -> IntMath.IntResult:
	"""The calendar day this node's current growth cycle began: its planting or stump date."""
	return _read(slot, _planted_day)


func capacity_milli_of(slot: int) -> IntMath.IntResult:
	"""The row's full-stock capacity in milli-units, or an explicit refusal."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_present(slot):
		out.refuse(String(REFUSE_NOT_PRESENT))
		return out
	out.succeed(_capacity_milli[slot])
	return out


func quantity_milli_of(slot: int) -> IntMath.IntResult:
	"""The row's remaining stock in milli-units, or an explicit refusal."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	quantity_milli_into(slot, out)
	return out


func quantity_milli_into(slot: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating quantity_milli_of(): write the stock into caller-owned `out`."""
	if not is_present(slot):
		return out.refuse(String(REFUSE_NOT_PRESENT))
	return out.succeed(_quantity_milli[slot])


func is_exhausted(slot: int) -> bool:
	"""True when a live row has been drawn down to 0 and stands as a dated stump."""
	return is_present(slot) and _exhausted[slot] == 1


func _read(slot: int, column: PackedInt32Array) -> IntMath.IntResult:
	"""Read one int32 column of a live row, refusing rather than returning a default."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if not is_present(slot):
		out.refuse(String(REFUSE_NOT_PRESENT))
		return out
	out.succeed(column[slot])
	return out


# --- harvest, exhaustion and regrowth (GDD §5.9, REQ-SET-138/139) ---------------------------------

func harvest(slot: int, amount_milli: int, day: int) -> OpResult:
	"""Debit `amount_milli` from a node on `day`. Returns the stock left after the debit.

	Refuses rather than clamping when the node holds less than asked for: a silent short delivery
	would let a job book more output than the world gave up. An exhausted node refuses every
	harvest (BAL-SAFE-012's repeat-before-debit guard), and the debit that empties a node dates
	its stump with `day` (REQ-SET-138).
	"""
	if not harvest_into(slot, amount_milli, day, _math):
		return _refuse(StringName(_math.error))
	return _succeed(_math.value, ref_of(slot))


func harvest_into(slot: int, amount_milli: int, day: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating harvest(): write the remaining stock into caller-owned `out`.

	`out` doubles as this call's scratch, so it must not be a result the caller still needs.
	"""
	var code: StringName = _check_harvest(slot, amount_milli, day)
	if code != REFUSE_NONE:
		return out.refuse(String(code))
	var remaining: int = _quantity_milli[slot] - amount_milli
	_quantity_milli[slot] = remaining
	if remaining == 0:
		_exhausted[slot] = 1
		_planted_day[slot] = day
	return out.succeed(remaining)


func _check_harvest(slot: int, amount_milli: int, day: int) -> StringName:
	"""REFUSE_NONE when a live, unexhausted node can give up exactly `amount_milli` on `day`."""
	if not is_present(slot):
		return REFUSE_NOT_PRESENT
	if _exhausted[slot] == 1:
		return REFUSE_NODE_EXHAUSTED
	if amount_milli <= 0:
		return REFUSE_INVALID_AMOUNT
	if amount_milli > _quantity_milli[slot]:
		return REFUSE_INSUFFICIENT_QUANTITY
	return _check_day(day)


func harvest_all(slot: int, day: int) -> OpResult:
	"""REQ-SET-138's single debit: take everything the node holds and date its stump `day`.

	Returns the amount debited. Refuses an already-exhausted node instead of debiting 0 a second
	time, which is exactly the repeat BAL-SAFE-012 forbids.
	"""
	if not is_present(slot):
		return _refuse(REFUSE_NOT_PRESENT)
	if _exhausted[slot] == 1:
		return _refuse(REFUSE_NODE_EXHAUSTED)
	var amount: int = _quantity_milli[slot]
	if not harvest_into(slot, amount, day, _math):
		return _refuse(StringName(_math.error))
	return _succeed(amount, ref_of(slot))


func regrow_ready_day_of(slot: int) -> IntMath.IntResult:
	"""The day an exhausted renewable node's stock returns: `planted_day + regrow_days`.

	Refuses a node that is not exhausted (there is no pending cycle to date) and one with
	`regrow_days == 0`, which never regrows. Overflow of the int32 sum refuses rather than wraps.
	"""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	regrow_ready_day_into(slot, out)
	return out


func regrow_ready_day_into(slot: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating regrow_ready_day_of(): write the regrowth date into caller-owned `out`."""
	if not is_present(slot):
		return out.refuse(String(REFUSE_NOT_PRESENT))
	if _exhausted[slot] != 1:
		return out.refuse(String(REFUSE_NODE_NOT_EXHAUSTED))
	if _regrow_days[slot] == 0:
		return out.refuse(String(REFUSE_NOT_RENEWABLE))
	if not IntMath.checked_add_into(_planted_day[slot], _regrow_days[slot], out):
		return false
	if not IntMath.fits_int32(out.value):
		return out.refuse(String(REFUSE_OVERFLOW))
	return true


func is_regrow_ready(slot: int, day: int) -> IntMath.IntResult:
	"""1 when `day` has reached an exhausted node's regrowth date, 0 when it has not.

	The GDD §5.9 tile condition ("no building occupies the tile") is NOT evaluated here; see the
	header. The caller owns that half of the test until a building/tile store exists.
	"""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	is_regrow_ready_into(slot, day, out)
	return out


func is_regrow_ready_into(slot: int, day: int, out: IntMath.IntResult) -> bool:
	"""Non-allocating is_regrow_ready(): write 1 or 0 into caller-owned `out`.

	`out` doubles as this call's scratch: the regrowth date lands there first and is compared
	against `day` before the verdict overwrites it.
	"""
	var code: StringName = _check_day(day)
	if code != REFUSE_NONE:
		return out.refuse(String(code))
	if not regrow_ready_day_into(slot, out):
		return false
	return out.succeed(1 if day >= out.value else 0)


func regrow(slot: int, day: int) -> OpResult:
	"""Restore an exhausted node to its capacity on the day its regrowth completes.

	Returns the restored stock. Refuses a node whose date has not arrived, one that never
	regrows, and one that is not exhausted, so a mature node cannot be topped up twice.
	"""
	if not is_regrow_ready_into(slot, day, _math):
		return _refuse(StringName(_math.error))
	if _math.value != 1:
		return _refuse(REFUSE_REGROW_NOT_DUE)
	_quantity_milli[slot] = _capacity_milli[slot]
	_exhausted[slot] = 0
	return _succeed(_capacity_milli[slot], ref_of(slot))


func _check_day(day: int) -> StringName:
	"""REFUSE_NONE when `day` is a storable calendar day, day 1 or later."""
	if day < MIN_CALENDAR_DAY or not IntMath.fits_int32(day):
		return REFUSE_INVALID_DAY
	return REFUSE_NONE


# --- result helpers ---------------------------------------------------------------------------------

func _succeed(value: int, ref: Vector2i) -> OpResult:
	"""Build a successful OpResult carrying a value and a reference."""
	return OpResult.new(true, REFUSE_NONE, value, ref)


func _refuse(code: StringName) -> OpResult:
	"""Build a refused OpResult. The value and reference are always empty on a refusal.

	This is not a sentinel scheme: the code travels on its own channel and a refusal never
	carries a usable number, so an ignored refusal cannot surface a plausible answer.
	"""
	return OpResult.new(false, code, 0, NULL_REF)
