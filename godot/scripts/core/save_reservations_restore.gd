extends RefCounted
## SAVE-RES-R01 v2: the section 7 `reservations` owner block adapter.
##
## `save_section_inventories.gd` owns the WIRE FORMAT and the validator for all six section-7
## owners; `reservations.gd` now publishes its eight canonical columns. This module is the join
## between those two, for ONE owner, and nothing else.
##
## NO CODEC-OWNER CYCLE. The codec is preloaded HERE, not from `reservations.gd`, so the owner has
## no edge back to any save module. The owner knows packed columns; this file knows ordinals.
##
## ONE BLOCK, NOT SIX, AND NEVER A SECOND INVENTORY. Every entry point takes a single
## `Codec.OwnerRecord`, never a `Codec.Record`, so saving or testing this owner never allocates
## the other five blocks. The supplied Inventory is read for two pure boolean flags and is not
## bound, mutated, attested or assumed to be the world these rows belong to.
##
## J AND L COME FROM THE TARGET. The wire carries no job or lot extent, so the TARGET pool's
## constructor extents are the explicit interpretation context and `apply()` refuses any row
## outside them. A block does not recover its source's extents and this adapter does not pretend
## otherwise.
##
## WHAT THIS ADAPTER DOES NOT DO. It does not acquire or release the load barrier -- it only asks
## the SUPPLIED clock whether one is held -- and it does not pause, tick, bind, claim, release,
## restore Inventory, publish a valid world or roll back a file. It makes no callback and no
## yield, and it must not be re-entered: the caller guarantees a quiescent boundary, because the
## public transaction flags alone do not prove that stronger condition. Full-world identity, every
## live lot's reserved total (including lots with NO rows), job mapping and liveness, and any disk
## rollback remain the coordinator's obligations.
##
## `clock` AND `inventory` DEFAULT TO NULL ON PURPOSE. A missing collaborator then produces a
## structured refusal. A default that refuses is a refusal, not an authorization to load unguarded.
##
## ARCH-SAVE-003 COLD PATH. A capture owns one ReservationColumns plus one private staged
## OwnerRecord while the caller's target block and the live owner coexist; an apply owns one
## borrowed column view while the owner duplicates what it installs. No float, no reflection, no
## per-tick allocation.

const ReservationsScript := preload("res://scripts/core/reservations.gd")
const Codec := preload("res://scripts/core/save_section_inventories.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const InventoryScript := preload("res://scripts/core/inventory.gd")

## The one owner this adapter speaks for, and the compiled row bound. Both are READ from the
## modules that own them so no number is restated here.
const OWNER: int = Codec.OWNER_RESERVATIONS
const ROW_CAPACITY: int = ReservationsScript.ROW_CAPACITY

## REG-R01's declared ordinals for `reservations`, in wire order.
const ORDINAL_OCCUPIED: int = 0
const ORDINAL_JOB_SLOT: int = 1
const ORDINAL_JOB_GENERATION: int = 2
const ORDINAL_LOT_SLOT: int = 3
const ORDINAL_LOT_GENERATION: int = 4
const ORDINAL_PURPOSE: int = 5
const ORDINAL_QUANTITY_MILLI: int = 6
const ORDINAL_EXPIRY: int = 7

## How many columns each storage group of a `reservations` block holds: one u8, five i32, two i64.
const U8_COLUMNS: int = 1
const I32_COLUMNS: int = 5
const I64_COLUMNS: int = 2

const REFUSE_BLOCK_SHAPE: StringName = &"SAVE_RES_BLOCK_SHAPE"
const REFUSE_NULL_STORE: StringName = &"SAVE_RES_NULL_STORE"
const REFUSE_NULL_CLOCK: StringName = &"SAVE_RES_NULL_CLOCK"
const REFUSE_BARRIER_NOT_HELD: StringName = &"SAVE_RES_BARRIER_NOT_HELD"
const REFUSE_NULL_INVENTORY: StringName = &"SAVE_RES_NULL_INVENTORY"
const REFUSE_BUSY: StringName = &"SAVE_RES_BUSY"


static func block_shape_refusal(block: Codec.OwnerRecord) -> SaveHeader.Refusal:
	"""TOTAL local shape gate for one `reservations` block, before anything indexes into it.

	Null; owner 4; primary count in 1..32768; no child extents; then the three storage GROUPS
	checked for 1/5/2 columns, and only THEN each column's own length against the primary count.

	The codec's generic `owner_refusal()` is not called from here and must not run before this
	passes: it assumes a well-shaped block and would index columns a hostile block need not have.
	"""
	if block == null:
		return _refuse(REFUSE_BLOCK_SHAPE, "no reservations owner block was supplied")
	if block.owner != OWNER:
		return _refuse(REFUSE_BLOCK_SHAPE,
			"block declares owner %d, not the reservations owner %d" % [block.owner, OWNER])
	if block.primary_count < 1 or block.primary_count > ROW_CAPACITY:
		return _refuse(REFUSE_BLOCK_SHAPE,
			"block declares primary_count %d, outside 1..%d"
				% [block.primary_count, ROW_CAPACITY])
	if block.child_extents.size() != 0:
		return _refuse(REFUSE_BLOCK_SHAPE,
			"reservations declares no child extents, but the block carries %d"
				% block.child_extents.size())
	if block.u8_columns.size() != U8_COLUMNS or block.i32_columns.size() != I32_COLUMNS \
			or block.i64_columns.size() != I64_COLUMNS:
		return _refuse(REFUSE_BLOCK_SHAPE,
			"block holds %d u8, %d i32 and %d i64 columns, not %d/%d/%d"
				% [block.u8_columns.size(), block.i32_columns.size(), block.i64_columns.size(),
					U8_COLUMNS, I32_COLUMNS, I64_COLUMNS])
	var rows: int = block.primary_count
	if block.u8_columns[0].size() != rows:
		return _refuse(REFUSE_BLOCK_SHAPE,
			"the occupancy column holds %d cells, not %d" % [block.u8_columns[0].size(), rows])
	for index: int in I32_COLUMNS:
		if block.i32_columns[index].size() != rows:
			return _refuse(REFUSE_BLOCK_SHAPE,
				"i32 column %d holds %d cells, not %d"
					% [index, block.i32_columns[index].size(), rows])
	for index: int in I64_COLUMNS:
		if block.i64_columns[index].size() != rows:
			return _refuse(REFUSE_BLOCK_SHAPE,
				"i64 column %d holds %d cells, not %d"
					% [index, block.i64_columns[index].size(), rows])
	return _accepted()


static func capture_into(store: ReservationsScript, out: Codec.OwnerRecord,
		inventory: InventoryScript = null) -> SaveHeader.Refusal:
	"""Stage one live pool into an existing `reservations` block, or refuse touching nothing.

	ORDER, fixed: null store; the target block's shape AND its row count against this pool's own;
	null Inventory; an Inventory with an open or poisoned transaction; the owner's own capture;
	one PRIVATE staged OwnerRecord filled by ordinal; the existing codec `owner_refusal()` over
	that staged record; and only then the target's three typed groups.

	WHY A PRIVATE STAGE AND A DIRECT TRANSFER. The staged record never escapes, so the owner's
	freshly duplicated arrays can be handed straight across without a second duplicate. Assignment
	goes through `Codec.storage_index_of()` -- AFTER the shape gate and AFTER the owner validated
	its own payload and indexes, never before.

	The target's metadata is untouched; its buffers end up independent of the live pool. Buffers a
	caller was already holding keep their PREVIOUS values because they were replaced rather than
	written into, not because of any assumed copy-on-write property.

	The staged codec gate is a DEFENSIVE owner/codec equivalence check -- the two validators
	deliberately differ, since the codec cannot see cross-row or reduced-extent rules -- and not a
	promised reachable failure for a healthy source. Should it refuse, the returned Refusal is
	authoritative even though the successful owner capture has already cleared the owner's own
	column diagnostic.
	"""
	if store == null:
		return _refuse(REFUSE_NULL_STORE, "no reservations store was supplied to capture from")
	var shape: SaveHeader.Refusal = block_shape_refusal(out)
	if not shape.is_ok():
		return shape
	if out.primary_count != store.row_capacity():
		return _refuse(REFUSE_BLOCK_SHAPE,
			"the target block holds %d rows, not the pool's %d"
				% [out.primary_count, store.row_capacity()])
	var busy: SaveHeader.Refusal = _inventory_refusal(inventory)
	if not busy.is_ok():
		return busy
	var columns: ReservationsScript.ReservationColumns = \
		ReservationsScript.ReservationColumns.new(store.row_capacity(), store.job_capacity(),
			store.lot_capacity())
	if not store.copy_reservation_columns_into(columns):
		return _refuse(store.last_column_refusal(), store.canonical_detail())
	var staged: Codec.OwnerRecord = Codec.OwnerRecord.new(OWNER, out.primary_count,
		PackedInt64Array())
	staged.u8_columns[Codec.storage_index_of(OWNER, ORDINAL_OCCUPIED)] = columns.occupied
	staged.i32_columns[Codec.storage_index_of(OWNER, ORDINAL_JOB_SLOT)] = columns.r_job_slot
	staged.i32_columns[Codec.storage_index_of(OWNER, ORDINAL_JOB_GENERATION)] = \
		columns.r_job_generation
	staged.i32_columns[Codec.storage_index_of(OWNER, ORDINAL_LOT_SLOT)] = columns.r_lot_slot
	staged.i32_columns[Codec.storage_index_of(OWNER, ORDINAL_LOT_GENERATION)] = \
		columns.r_lot_generation
	staged.i32_columns[Codec.storage_index_of(OWNER, ORDINAL_PURPOSE)] = columns.r_purpose
	staged.i64_columns[Codec.storage_index_of(OWNER, ORDINAL_QUANTITY_MILLI)] = \
		columns.r_quantity_milli
	staged.i64_columns[Codec.storage_index_of(OWNER, ORDINAL_EXPIRY)] = columns.r_expiry
	var invalid: SaveHeader.Refusal = Codec.owner_refusal(staged)
	if not invalid.is_ok():
		return invalid
	out.u8_columns = staged.u8_columns
	out.i32_columns = staged.i32_columns
	out.i64_columns = staged.i64_columns
	return _accepted()


static func apply(block: Codec.OwnerRecord, store: ReservationsScript, clock: SimClock = null,
		inventory: InventoryScript = null) -> SaveHeader.Refusal:
	"""Publish one decoded `reservations` block into a live pool behind a held load barrier.

	ORDER, fixed: null block (SHAPE); null store; null clock; a clock whose barrier is NOT held;
	the block's shape AND its row count against the pool's; null Inventory; an open or poisoned
	Inventory; the existing codec `owner_refusal()`; one local column view carrying the TARGET's
	job and lot extents; then the owner's own restore.

	The local record first allocates and fills 37R bytes of constructor arrays, then
	replaces those fields with borrowed block arrays. The owner validates before installing,
	duplicates what it installs, and never writes into its input. The view does not escape.

	The barrier is only QUERIED: this adapter never acquires or releases one, never ticks, and
	binds nothing. The clock is required for the barrier alone -- not to expire or validate a
	lease -- and the Inventory is read for two pure flags. Both identities, and every value field
	of either, are left exactly as they were.

	A failure leaves the block, the live pool and every collaborator unchanged, except the owner's
	own `_last_column_refusal` when its API was actually reached. A codec-stage rejection leaves
	that older owner diagnostic alone; the caller reads the returned Refusal, which is
	authoritative either way.
	"""
	if block == null:
		return _refuse(REFUSE_BLOCK_SHAPE, "no reservations owner block was supplied to apply")
	if store == null:
		return _refuse(REFUSE_NULL_STORE, "no reservations store was supplied to restore into")
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
			"the block holds %d rows, not the target pool's %d"
				% [block.primary_count, store.row_capacity()])
	var busy: SaveHeader.Refusal = _inventory_refusal(inventory)
	if not busy.is_ok():
		return busy
	var invalid: SaveHeader.Refusal = Codec.owner_refusal(block)
	if not invalid.is_ok():
		return invalid
	# The TARGET's constructor extents are the interpretation context the wire does not carry:
	# a row naming a job or lot outside them is refused by the owner, never silently admitted.
	var columns: ReservationsScript.ReservationColumns = \
		ReservationsScript.ReservationColumns.new(store.row_capacity(), store.job_capacity(),
			store.lot_capacity())
	columns.occupied = block.u8_columns[Codec.storage_index_of(OWNER, ORDINAL_OCCUPIED)]
	columns.r_job_slot = block.i32_columns[Codec.storage_index_of(OWNER, ORDINAL_JOB_SLOT)]
	columns.r_job_generation = \
		block.i32_columns[Codec.storage_index_of(OWNER, ORDINAL_JOB_GENERATION)]
	columns.r_lot_slot = block.i32_columns[Codec.storage_index_of(OWNER, ORDINAL_LOT_SLOT)]
	columns.r_lot_generation = \
		block.i32_columns[Codec.storage_index_of(OWNER, ORDINAL_LOT_GENERATION)]
	columns.r_purpose = block.i32_columns[Codec.storage_index_of(OWNER, ORDINAL_PURPOSE)]
	columns.r_quantity_milli = \
		block.i64_columns[Codec.storage_index_of(OWNER, ORDINAL_QUANTITY_MILLI)]
	columns.r_expiry = block.i64_columns[Codec.storage_index_of(OWNER, ORDINAL_EXPIRY)]
	if not store.restore_reservation_columns(columns):
		return _refuse(store.last_column_refusal(), store.canonical_detail())
	return _accepted()


static func _inventory_refusal(inventory: InventoryScript) -> SaveHeader.Refusal:
	"""A supplied, quiescent Inventory is mandatory on BOTH paths. Null first, then busy.

	Only two existing PURE bool predicates are queried, in this order, and both answer with the
	same SAVE_RES_BUSY code: an open transaction and a poisoned one are equally unsafe boundaries
	for a save or a load. Nothing is bound, mutated or attested, and no new Inventory API or
	private reflection is introduced -- supplying the right world is the caller's obligation.
	"""
	if inventory == null:
		return _refuse(REFUSE_NULL_INVENTORY,
			"no inventory was supplied, so no quiescent boundary can be shown")
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
