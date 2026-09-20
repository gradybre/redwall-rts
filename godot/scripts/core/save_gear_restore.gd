extends RefCounted
## SAVE-GEAR-R01 v2: the section 7 `gear` owner block adapter.
##
## `save_section_inventories.gd` owns the WIRE FORMAT and the generic validator for all six
## section-7 owners; `gear.gd` now publishes its twelve canonical columns. This module is the
## join between those two, for ONE owner, and nothing else.
##
## NO CODEC-OWNER CYCLE. The codec is preloaded HERE, not from `gear.gd`, so the owner keeps no
## edge back to any save module. The owner knows packed columns; this file knows ordinals.
##
## ONE BLOCK, NOT SIX, AND NEVER A SECOND INVENTORY. Every entry point takes a single
## `Codec.OwnerRecord`, never a `Codec.Record`, so saving or testing this owner never allocates
## the other five blocks. The supplied Inventory is read for one pure identity predicate and two
## pure boolean flags; it is not bound, mutated, attested or assumed to be the world these rows
## belong to.
##
## EQUIPPED ROWS ARE THE POINT. The legacy `restore_row()` route cannot carry the `equipped`
## byte at all, so a settlement saved with twelve equipped tools came back with twelve
## unequipped ones. This adapter moves the whole image, including that byte, and the owner
## refuses an image with equipped rows unless the three equipment collaborators are already
## bound -- there is no blind post-install rebind, because `bind_equipment()` itself refuses
## while equipped rows exist.
##
## WHAT THIS ADAPTER DOES NOT DO. It does not acquire or release the load barrier -- it only
## asks the SUPPLIED clock whether one is held -- and it does not pause, tick, bind, claim,
## release, repair, restore Inventory, publish a valid world or roll back a file. It makes no
## callback, no yield and no reflective call, and it must not be re-entered: the caller
## guarantees a quiescent boundary, because the public transaction flags alone do not prove that
## stronger condition. Full-world identity, catalog provenance, equipment mirrors, lot and claim
## liveness and any disk rollback remain the coordinator's obligations.
##
## NOTHING IS REPAIRED ON THE WAY IN. The owner refuses a half-null reference pair and a claim
## slot at or above 8192 that the existing codec admits; this adapter forwards COLUMN_GEAR_REF
## verbatim and never clamps, masks, normalizes or remaps such a value. That stream fails
## loading pending the separate job-generation integration ruling. A bulk save is not a repair
## of malformed legacy restore data.
##
## `clock`, `definitions` AND `inventory` DEFAULT TO NULL ON PURPOSE. A missing collaborator then
## produces a structured refusal. A default that refuses is a refusal, not an authorization to
## load unguarded.
##
## ARCH-SAVE-003 COLD PATH. A capture owns one GearColumns plus one private staged OwnerRecord
## while the caller's target block and the live owner coexist; an apply owns one local
## GearColumns whose constructor buffers are then replaced by borrowed block arrays, while the
## owner duplicates what it installs. No float, no reflection, no per-tick allocation.

const GearScript := preload("res://scripts/core/gear.gd")
const Codec := preload("res://scripts/core/save_section_inventories.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const InventoryScript := preload("res://scripts/core/inventory.gd")
const ItemDefinitionsScript := preload("res://scripts/core/item_definitions.gd")

## The one owner this adapter speaks for, and the compiled row bound. Both are READ from the
## modules that own them so no number is restated here.
const OWNER: int = Codec.OWNER_GEAR
const ROW_CAPACITY: int = GearScript.ROW_CAPACITY

## REG-R01's declared ordinals for `gear`, in wire order. These are FIELD ordinals and never
## group indices: ordinals 0 and 9 are the two u8 columns at storage positions 0 and 1, and
## ordinals 1..8, 10 and 11 are the ten i32 columns at storage positions 0..9. Every access
## below goes through `Codec.storage_index_of()` rather than assuming that mapping.
const ORDINAL_OCCUPIED: int = 0
const ORDINAL_LOT_SLOT: int = 1
const ORDINAL_LOT_GENERATION: int = 2
const ORDINAL_ITEM_ID: int = 3
const ORDINAL_DURABILITY: int = 4
const ORDINAL_DURABILITY_CAP: int = 5
const ORDINAL_OWNER_SLOT: int = 6
const ORDINAL_OWNER_GENERATION: int = 7
const ORDINAL_MANUFACTURE_RECIPE: int = 8
const ORDINAL_EQUIPPED: int = 9
const ORDINAL_CLAIM_JOB_SLOT: int = 10
const ORDINAL_CLAIM_JOB_GENERATION: int = 11

## How many columns each storage group of a `gear` block holds: two u8, ten i32, no i64.
const U8_COLUMNS: int = 2
const I32_COLUMNS: int = 10
const I64_COLUMNS: int = 0

const REFUSE_BLOCK_SHAPE: StringName = &"SAVE_GEAR_BLOCK_SHAPE"
const REFUSE_NULL_STORE: StringName = &"SAVE_GEAR_NULL_STORE"
const REFUSE_NULL_CLOCK: StringName = &"SAVE_GEAR_NULL_CLOCK"
const REFUSE_BARRIER_NOT_HELD: StringName = &"SAVE_GEAR_BARRIER_NOT_HELD"
const REFUSE_NULL_INVENTORY: StringName = &"SAVE_GEAR_NULL_INVENTORY"
const REFUSE_INVENTORY_MISMATCH: StringName = &"SAVE_GEAR_INVENTORY_MISMATCH"
const REFUSE_BUSY: StringName = &"SAVE_GEAR_BUSY"


static func block_shape_refusal(block: Codec.OwnerRecord) -> SaveHeader.Refusal:
	"""TOTAL local shape gate for one `gear` block, before anything indexes into it.

	Null; owner 2; primary count in 1..16384; no child extents; then the three storage GROUPS
	checked for 2/10/0 columns, and only THEN each column's own length against the primary count.

	The codec's generic `owner_refusal()` is not called from here and must not run before this
	passes: it assumes a well-shaped block and would index columns a hostile block need not have.
	"""
	if block == null:
		return _refuse(REFUSE_BLOCK_SHAPE, "no gear owner block was supplied")
	if block.owner != OWNER:
		return _refuse(REFUSE_BLOCK_SHAPE,
			"block declares owner %d, not the gear owner %d" % [block.owner, OWNER])
	if block.primary_count < 1 or block.primary_count > ROW_CAPACITY:
		return _refuse(REFUSE_BLOCK_SHAPE,
			"block declares primary_count %d, outside 1..%d"
				% [block.primary_count, ROW_CAPACITY])
	if block.child_extents.size() != 0:
		return _refuse(REFUSE_BLOCK_SHAPE,
			"gear declares no child extents, but the block carries %d"
				% block.child_extents.size())
	if block.u8_columns.size() != U8_COLUMNS or block.i32_columns.size() != I32_COLUMNS \
			or block.i64_columns.size() != I64_COLUMNS:
		return _refuse(REFUSE_BLOCK_SHAPE,
			"block holds %d u8, %d i32 and %d i64 columns, not %d/%d/%d"
				% [block.u8_columns.size(), block.i32_columns.size(), block.i64_columns.size(),
					U8_COLUMNS, I32_COLUMNS, I64_COLUMNS])
	var rows: int = block.primary_count
	for index: int in U8_COLUMNS:
		if block.u8_columns[index].size() != rows:
			return _refuse(REFUSE_BLOCK_SHAPE,
				"u8 column %d holds %d cells, not %d"
					% [index, block.u8_columns[index].size(), rows])
	for index: int in I32_COLUMNS:
		if block.i32_columns[index].size() != rows:
			return _refuse(REFUSE_BLOCK_SHAPE,
				"i32 column %d holds %d cells, not %d"
					% [index, block.i32_columns[index].size(), rows])
	return _accepted()


static func capture_into(store: GearScript, out: Codec.OwnerRecord,
		definitions: ItemDefinitionsScript = null,
		inventory: InventoryScript = null) -> SaveHeader.Refusal:
	"""Stage one live gear store into an existing `gear` block, or refuse touching nothing.

	ORDER, fixed: null store; the target block's shape AND its row count against this store's
	own; null Inventory; the store's own pure identity predicate; an Inventory with an open or
	poisoned transaction; the owner's own capture into a PRIVATE GearColumns; one private staged
	OwnerRecord filled by ordinal; the existing codec `owner_refusal()` over that staged record;
	and only then the target's three typed groups.

	NO DEFINITIONS GATE RUNS AHEAD OF THE OWNER GATE. A null or unloaded catalog is the owner's
	COLUMN_GEAR_DEFINITIONS refusal, forwarded verbatim, so one module decides what a usable
	catalog is and this one cannot drift from it.

	WHY A PRIVATE STAGE AND A DIRECT TRANSFER. The staged record never escapes, so the owner's
	freshly duplicated arrays can be handed straight across without a second duplicate.
	Assignment goes through `Codec.storage_index_of()` -- AFTER the shape gate and AFTER the
	owner validated its own payload, heap, counts and caches, never before.

	The target's metadata is untouched; its buffers end up independent of the live store. Buffers
	a caller was already holding keep their PREVIOUS values because they were replaced rather
	than written into, not because of any assumed copy-on-write property.

	The staged codec gate is a DEFENSIVE owner/codec equivalence check -- the two validators
	deliberately differ, since the owner is stricter about null pairs and claim slots -- and not
	a promised reachable failure for a healthy source. Should it refuse, the returned Refusal is
	authoritative even though the successful owner capture has already cleared the owner's own
	column diagnostic.
	"""
	if store == null:
		return _refuse(REFUSE_NULL_STORE, "no gear store was supplied to capture from")
	var shape: SaveHeader.Refusal = block_shape_refusal(out)
	if not shape.is_ok():
		return shape
	if out.primary_count != store.row_capacity():
		return _refuse(REFUSE_BLOCK_SHAPE,
			"the target block holds %d rows, not the store's %d"
				% [out.primary_count, store.row_capacity()])
	var busy: SaveHeader.Refusal = _inventory_refusal(store, inventory)
	if not busy.is_ok():
		return busy
	var columns: GearScript.GearColumns = GearScript.GearColumns.new(store.row_capacity())
	if not store.copy_gear_columns_into(columns, definitions):
		return _refuse(store.last_column_refusal(), store.canonical_detail())
	var staged: Codec.OwnerRecord = Codec.OwnerRecord.new(OWNER, out.primary_count,
		PackedInt64Array())
	staged.u8_columns[Codec.storage_index_of(OWNER, ORDINAL_OCCUPIED)] = columns.occupied
	staged.u8_columns[Codec.storage_index_of(OWNER, ORDINAL_EQUIPPED)] = columns.equipped
	staged.i32_columns[Codec.storage_index_of(OWNER, ORDINAL_LOT_SLOT)] = columns.lot_slot
	staged.i32_columns[Codec.storage_index_of(OWNER, ORDINAL_LOT_GENERATION)] = \
		columns.lot_generation
	staged.i32_columns[Codec.storage_index_of(OWNER, ORDINAL_ITEM_ID)] = columns.item_id
	staged.i32_columns[Codec.storage_index_of(OWNER, ORDINAL_DURABILITY)] = columns.durability
	staged.i32_columns[Codec.storage_index_of(OWNER, ORDINAL_DURABILITY_CAP)] = \
		columns.durability_cap
	staged.i32_columns[Codec.storage_index_of(OWNER, ORDINAL_OWNER_SLOT)] = columns.owner_slot
	staged.i32_columns[Codec.storage_index_of(OWNER, ORDINAL_OWNER_GENERATION)] = \
		columns.owner_generation
	staged.i32_columns[Codec.storage_index_of(OWNER, ORDINAL_MANUFACTURE_RECIPE)] = \
		columns.manufacture_recipe
	staged.i32_columns[Codec.storage_index_of(OWNER, ORDINAL_CLAIM_JOB_SLOT)] = \
		columns.claim_job_slot
	staged.i32_columns[Codec.storage_index_of(OWNER, ORDINAL_CLAIM_JOB_GENERATION)] = \
		columns.claim_job_generation
	var invalid: SaveHeader.Refusal = Codec.owner_refusal(staged)
	if not invalid.is_ok():
		return invalid
	out.u8_columns = staged.u8_columns
	out.i32_columns = staged.i32_columns
	out.i64_columns = staged.i64_columns
	return _accepted()


static func apply(block: Codec.OwnerRecord, store: GearScript, clock: SimClock = null,
		definitions: ItemDefinitionsScript = null,
		inventory: InventoryScript = null) -> SaveHeader.Refusal:
	"""Publish one decoded `gear` block into a live store behind a held load barrier.

	ORDER, fixed: null block (SHAPE); null store; null clock; a clock whose barrier is NOT held;
	the block's shape AND its row count against the store's; null Inventory; the store's identity
	predicate; an open or poisoned Inventory; the existing codec `owner_refusal()`; one local
	GearColumns borrowing the validated block arrays; then the owner's own restore.

	The local record first allocates and fills 42R bytes of constructor arrays, then replaces
	those fields with borrowed block arrays. The owner validates before installing, duplicates
	what it installs, and never writes into its input. The view does not escape.

	The barrier is only QUERIED: this adapter never acquires or releases one, never ticks, and
	binds nothing. The clock is required for the barrier alone, and the Inventory for one pure
	predicate and two pure flags. Both identities, and every value field of either, are left
	exactly as they were.

	A failure leaves the block, the live store and every collaborator unchanged, except the
	owner's own `_last_column_refusal` when its API was actually reached. A codec-stage rejection
	leaves that older owner diagnostic alone; the caller reads the returned Refusal, which is
	authoritative either way.
	"""
	if block == null:
		return _refuse(REFUSE_BLOCK_SHAPE, "no gear owner block was supplied to apply")
	if store == null:
		return _refuse(REFUSE_NULL_STORE, "no gear store was supplied to restore into")
	if clock == null:
		return _refuse(REFUSE_NULL_CLOCK,
			"no clock was supplied, so no load barrier can be shown to be held")
	if not clock.is_load_barrier_held():
		return _refuse(REFUSE_BARRIER_NOT_HELD,
			"the supplied clock holds no load barrier; this adapter never acquires one")
	var shape: SaveHeader.Refusal = block_shape_refusal(block)
	if not shape.is_ok():
		return shape
	if block.primary_count != store.row_capacity():
		return _refuse(REFUSE_BLOCK_SHAPE,
			"the block holds %d rows, not the target store's %d"
				% [block.primary_count, store.row_capacity()])
	var busy: SaveHeader.Refusal = _inventory_refusal(store, inventory)
	if not busy.is_ok():
		return busy
	var invalid: SaveHeader.Refusal = Codec.owner_refusal(block)
	if not invalid.is_ok():
		return invalid
	var columns: GearScript.GearColumns = GearScript.GearColumns.new(store.row_capacity())
	columns.occupied = block.u8_columns[Codec.storage_index_of(OWNER, ORDINAL_OCCUPIED)]
	columns.equipped = block.u8_columns[Codec.storage_index_of(OWNER, ORDINAL_EQUIPPED)]
	columns.lot_slot = block.i32_columns[Codec.storage_index_of(OWNER, ORDINAL_LOT_SLOT)]
	columns.lot_generation = \
		block.i32_columns[Codec.storage_index_of(OWNER, ORDINAL_LOT_GENERATION)]
	columns.item_id = block.i32_columns[Codec.storage_index_of(OWNER, ORDINAL_ITEM_ID)]
	columns.durability = block.i32_columns[Codec.storage_index_of(OWNER, ORDINAL_DURABILITY)]
	columns.durability_cap = \
		block.i32_columns[Codec.storage_index_of(OWNER, ORDINAL_DURABILITY_CAP)]
	columns.owner_slot = block.i32_columns[Codec.storage_index_of(OWNER, ORDINAL_OWNER_SLOT)]
	columns.owner_generation = \
		block.i32_columns[Codec.storage_index_of(OWNER, ORDINAL_OWNER_GENERATION)]
	columns.manufacture_recipe = \
		block.i32_columns[Codec.storage_index_of(OWNER, ORDINAL_MANUFACTURE_RECIPE)]
	columns.claim_job_slot = \
		block.i32_columns[Codec.storage_index_of(OWNER, ORDINAL_CLAIM_JOB_SLOT)]
	columns.claim_job_generation = \
		block.i32_columns[Codec.storage_index_of(OWNER, ORDINAL_CLAIM_JOB_GENERATION)]
	if not store.restore_gear_columns(columns, definitions):
		return _refuse(store.last_column_refusal(), store.canonical_detail())
	return _accepted()


static func _inventory_refusal(store: GearScript,
		inventory: InventoryScript) -> SaveHeader.Refusal:
	"""A supplied, matching, quiescent Inventory is mandatory on BOTH paths.

	Null first, then the store's own PURE identity predicate, then the two existing pure boolean
	transaction predicates -- an open transaction and a poisoned one are equally unsafe
	boundaries for a save or a load, so both answer SAVE_GEAR_BUSY.

	A BOUND store rejects a foreign Inventory outright. An UNBOUND store cannot prove world
	association from an identity predicate at all, so it accepts any nonnull Inventory here and
	the coordinator still owns that check. Nothing is bound, mutated or attested, and no new
	Inventory API or private reflection is introduced.
	"""
	if inventory == null:
		return _refuse(REFUSE_NULL_INVENTORY,
			"no inventory was supplied, so no quiescent boundary can be shown")
	if not store.column_inventory_matches(inventory):
		return _refuse(REFUSE_INVENTORY_MISMATCH,
			"the gear store is bound to a different inventory than the one supplied")
	if inventory.is_transaction_open():
		return _refuse(REFUSE_BUSY, "the supplied inventory has an open transaction")
	if inventory.is_transaction_poisoned():
		return _refuse(REFUSE_BUSY, "the supplied inventory's transaction is poisoned")
	return _accepted()


static func _refuse(code: StringName, detail: String) -> SaveHeader.Refusal:
	"""Build one refusal. Owner column codes and codec codes are forwarded verbatim."""
	return SaveHeader.Refusal.new(code, detail)


static func _accepted() -> SaveHeader.Refusal:
	"""The accepting refusal. There is no generic success fallback for a semantic failure."""
	return SaveHeader.Refusal.new(SaveHeader.REFUSE_NONE, "")
