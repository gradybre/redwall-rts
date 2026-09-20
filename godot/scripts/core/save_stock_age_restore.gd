extends RefCounted
## SAVE-AGE-R01v2: the section 7 `stock_age` owner block adapter.
##
## `save_section_inventories.gd` owns the WIRE FORMAT and the validator for all six section-7
## owners; `stock_age.gd` now publishes its four declaration columns and its two scalars. This
## module is the join between those two, for ONE owner, and nothing else.
##
## NO CODEC-OWNER CYCLE. The codec is preloaded HERE, not from `stock_age.gd`, so the owner has
## no edge back to the section module. The owner knows about packed columns; this file knows
## about ordinals.
##
## ONE BLOCK, NOT SIX. Every entry point takes a single `Codec.OwnerRecord`, so testing or
## saving this owner never allocates the other five blocks -- which together are the bulk of a
## 10 MB section. The caller owns that block and may reuse it.
##
## WHAT THIS ADAPTER DOES NOT DO. It does not acquire, release or check anything about the load
## barrier beyond asking the SUPPLIED clock whether it is held; it does not pause, tick, bind
## owners, restore Inventory, associate a clock/world/catalog, publish a valid world or roll
## back a file. Those remain the caller's obligations. It makes no callback and no yield, and it
## must not be re-entered from inside an aging or declaration operation or any Inventory
## authority callback -- the public transaction flags alone do not prove that stronger
## condition. It registers no canonical adapter and claims nothing about a whole-section encode.
##
## `clock` DEFAULTS TO NULL ON PURPOSE. A missing clock then produces a structured
## SAVE_AGE_NULL_CLOCK refusal, consistent with the other accepted adapters. A default that
## refuses is a refusal, not an authorization to load unguarded.
##
## ARCH-SAVE-003 COLD PATH. A capture owns one CanonicalColumns plus one private staged
## OwnerRecord while the caller's target block and the live owner coexist; an apply owns one
## CanonicalColumns view plus the owner's freshly duplicated buffers while the old ones are
## replaced. No float, no reflection, no per-tick allocation.

const StockAgeScript := preload("res://scripts/core/stock_age.gd")
const Codec := preload("res://scripts/core/save_section_inventories.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")

## The one owner this adapter speaks for, and its fixed table extent. Both are READ from the
## modules that own them so no number is restated here.
const OWNER: int = Codec.OWNER_STOCK_AGE
const CONTAINER_CAPACITY: int = StockAgeScript.CONTAINER_CAPACITY

## REG-R01's declared ordinals for `stock_age`, in wire order. Ordinals 0 and 1 are the two
## scalars and live in the i64 storage group -- the count is a u32 on the wire but is stored
## int64-backed, so it round-trips without ever being read as a negative int32.
const ORDINAL_DECLARED_COUNT: int = 0
const ORDINAL_LAST_HOUR_TICK: int = 1
const ORDINAL_STORAGE_CLASS: int = 2
const ORDINAL_HEATED_INTERIOR: int = 3
const ORDINAL_DECLARED_GENERATION: int = 4
const ORDINAL_DECLARED_SLOTS: int = 5

## How many columns each storage group of a `stock_age` block holds: two u8, two i32, two i64.
const COLUMNS_PER_GROUP: int = 2
const SCALAR_CELLS: int = 1

const REFUSE_BLOCK_SHAPE: StringName = &"SAVE_AGE_BLOCK_SHAPE"
const REFUSE_NULL_STORE: StringName = &"SAVE_AGE_NULL_STORE"
const REFUSE_NULL_CLOCK: StringName = &"SAVE_AGE_NULL_CLOCK"
const REFUSE_BARRIER_NOT_HELD: StringName = &"SAVE_AGE_BARRIER_NOT_HELD"


static func block_shape_refusal(block: Codec.OwnerRecord) -> SaveHeader.Refusal:
	"""TOTAL local shape gate for one `stock_age` block, before anything indexes into it.

	Null; owner 5; primary count exactly CONTAINER_CAPACITY; no child extents; then the three
	storage GROUPS checked for two columns each, and only THEN each column's own length -- both
	u8 and both i32 at CONTAINER_CAPACITY, both i64 at one cell.

	The codec's generic `owner_refusal()` is not called from here and must not run before this
	passes: its current implementation assumes a well-shaped block and would index columns that
	a hostile block need not have.
	"""
	if block == null:
		return _refuse(REFUSE_BLOCK_SHAPE, "no stock_age owner block was supplied")
	if block.owner != OWNER:
		return _refuse(REFUSE_BLOCK_SHAPE,
			"block declares owner %d, not the stock_age owner %d" % [block.owner, OWNER])
	if block.primary_count != CONTAINER_CAPACITY:
		return _refuse(REFUSE_BLOCK_SHAPE,
			"block declares primary_count %d, not the compiled %d"
				% [block.primary_count, CONTAINER_CAPACITY])
	if block.child_extents.size() != 0:
		return _refuse(REFUSE_BLOCK_SHAPE,
			"stock_age declares no child extents, but the block carries %d"
				% block.child_extents.size())
	if block.u8_columns.size() != COLUMNS_PER_GROUP or block.i32_columns.size() != COLUMNS_PER_GROUP \
			or block.i64_columns.size() != COLUMNS_PER_GROUP:
		return _refuse(REFUSE_BLOCK_SHAPE,
			"block holds %d u8, %d i32 and %d i64 columns, not %d of each"
				% [block.u8_columns.size(), block.i32_columns.size(), block.i64_columns.size(),
					COLUMNS_PER_GROUP])
	for index: int in COLUMNS_PER_GROUP:
		if block.u8_columns[index].size() != CONTAINER_CAPACITY:
			return _refuse(REFUSE_BLOCK_SHAPE,
				"u8 column %d holds %d cells, not %d"
					% [index, block.u8_columns[index].size(), CONTAINER_CAPACITY])
		if block.i32_columns[index].size() != CONTAINER_CAPACITY:
			return _refuse(REFUSE_BLOCK_SHAPE,
				"i32 column %d holds %d cells, not %d"
					% [index, block.i32_columns[index].size(), CONTAINER_CAPACITY])
		if block.i64_columns[index].size() != SCALAR_CELLS:
			return _refuse(REFUSE_BLOCK_SHAPE,
				"i64 scalar column %d holds %d cells, not %d"
					% [index, block.i64_columns[index].size(), SCALAR_CELLS])
	return _accepted()


static func capture_into(store: StockAgeScript, out: Codec.OwnerRecord) -> SaveHeader.Refusal:
	"""Stage one live StockAge into an existing `stock_age` block, or refuse touching nothing.

	ORDER: null store; the target block's shape; one local CanonicalColumns; the owner's own
	capture; one PRIVATE staged OwnerRecord filled by ordinal; the existing codec
	`owner_refusal()` over that staged record; and only then the target's three typed groups.

	WHY A PRIVATE STAGE AND A DIRECT TRANSFER. The staged record never escapes, so its arrays
	can be handed straight across without a second duplicate; and the public setters cannot be
	used for this transfer anyway, because they duplicate and because `set_i32_column()` refuses
	the counted-list ordinal 5 outright. Assignment therefore goes through
	`Codec.storage_index_of()` -- AFTER the shape gate and AFTER the owner has validated its own
	payload, never before.

	The two scalars become independently allocated one-cell PackedInt64Arrays; they are NOT
	narrowed to u32 here, because only the owner's `0..101376` count bound makes that safe and
	the codec performs that check itself.

	After publication the target's metadata is untouched, its buffers are independent of the live
	owner, and both private locals leave scope. Buffers a caller was already holding keep their
	PREVIOUS values because they were replaced rather than written into -- not because of any
	assumed copy-on-write property.

	The staged codec gate is a DEFENSIVE owner/codec equivalence check, not a promised reachable
	failure for a healthy source. Should it ever refuse, the returned Refusal is authoritative
	even though the successful owner capture has already cleared the owner's column diagnostic.
	"""
	if store == null:
		return _refuse(REFUSE_NULL_STORE, "no stock_age store was supplied to capture from")
	var shape: SaveHeader.Refusal = block_shape_refusal(out)
	if not shape.is_ok():
		return shape
	var columns: StockAgeScript.CanonicalColumns = StockAgeScript.CanonicalColumns.new()
	if not store.copy_stock_age_columns_into(columns):
		return _refuse(store.last_column_refusal(), store.canonical_detail())
	var staged: Codec.OwnerRecord = Codec.OwnerRecord.new(OWNER, CONTAINER_CAPACITY,
		PackedInt64Array())
	staged.i64_columns[Codec.storage_index_of(OWNER, ORDINAL_DECLARED_COUNT)] = \
		PackedInt64Array([columns.declared_count])
	staged.i64_columns[Codec.storage_index_of(OWNER, ORDINAL_LAST_HOUR_TICK)] = \
		PackedInt64Array([columns.last_hour_tick])
	staged.u8_columns[Codec.storage_index_of(OWNER, ORDINAL_STORAGE_CLASS)] = \
		columns.c_storage_class
	staged.u8_columns[Codec.storage_index_of(OWNER, ORDINAL_HEATED_INTERIOR)] = \
		columns.c_heated_interior
	staged.i32_columns[Codec.storage_index_of(OWNER, ORDINAL_DECLARED_GENERATION)] = \
		columns.c_declared_generation
	staged.i32_columns[Codec.storage_index_of(OWNER, ORDINAL_DECLARED_SLOTS)] = \
		columns.declared_slots
	var invalid: SaveHeader.Refusal = Codec.owner_refusal(staged)
	if not invalid.is_ok():
		return invalid
	out.u8_columns = staged.u8_columns
	out.i32_columns = staged.i32_columns
	out.i64_columns = staged.i64_columns
	return _accepted()


static func apply(block: Codec.OwnerRecord, store: StockAgeScript,
		clock: SimClock = null) -> SaveHeader.Refusal:
	"""Publish one decoded `stock_age` block into a live store behind a held load barrier.

	ORDER: null block (SHAPE); null store; null clock; a clock whose barrier is NOT held; the
	block's shape; the existing codec `owner_refusal()`; one local CanonicalColumns view of all
	six values; then the owner's own restore.

	The local view may BORROW the block's arrays, because the owner validates before installing,
	duplicates what it installs, and never writes into its input. The view does not escape.

	The barrier is only QUERIED. This adapter does not acquire or release it, does not pause or
	tick, and binds nothing: `bind_stores()` must already have bound the Inventory this save
	belongs to, since rebinding a different one drops every declaration.

	A failure leaves the block, the live owner and every collaborator unchanged, except the
	owner's own `_last_column_refusal` when its API was actually reached. A codec-stage rejection
	leaves that older owner diagnostic alone; the caller reads the returned Refusal, which is
	authoritative either way.
	"""
	if block == null:
		return _refuse(REFUSE_BLOCK_SHAPE, "no stock_age owner block was supplied to apply")
	if store == null:
		return _refuse(REFUSE_NULL_STORE, "no stock_age store was supplied to restore into")
	if clock == null:
		return _refuse(REFUSE_NULL_CLOCK,
			"no clock was supplied, so no load barrier can be shown to be held")
	if not clock.is_load_barrier_held():
		return _refuse(REFUSE_BARRIER_NOT_HELD,
			"the supplied clock holds no load barrier; this adapter never acquires one")
	var shape: SaveHeader.Refusal = block_shape_refusal(block)
	if not shape.is_ok():
		return shape
	var invalid: SaveHeader.Refusal = Codec.owner_refusal(block)
	if not invalid.is_ok():
		return invalid
	var columns: StockAgeScript.CanonicalColumns = StockAgeScript.CanonicalColumns.new()
	columns.container_capacity = CONTAINER_CAPACITY
	columns.declared_count = \
		block.i64_columns[Codec.storage_index_of(OWNER, ORDINAL_DECLARED_COUNT)][0]
	columns.last_hour_tick = \
		block.i64_columns[Codec.storage_index_of(OWNER, ORDINAL_LAST_HOUR_TICK)][0]
	columns.c_storage_class = \
		block.u8_columns[Codec.storage_index_of(OWNER, ORDINAL_STORAGE_CLASS)]
	columns.c_heated_interior = \
		block.u8_columns[Codec.storage_index_of(OWNER, ORDINAL_HEATED_INTERIOR)]
	columns.c_declared_generation = \
		block.i32_columns[Codec.storage_index_of(OWNER, ORDINAL_DECLARED_GENERATION)]
	columns.declared_slots = \
		block.i32_columns[Codec.storage_index_of(OWNER, ORDINAL_DECLARED_SLOTS)]
	if not store.restore_stock_age_columns(columns):
		return _refuse(store.last_column_refusal(), store.canonical_detail())
	return _accepted()


static func _refuse(code: StringName, detail: String) -> SaveHeader.Refusal:
	"""Build one refusal. Owner column codes and codec codes are forwarded verbatim."""
	return SaveHeader.Refusal.new(code, detail)


static func _accepted() -> SaveHeader.Refusal:
	"""The accepting refusal. There is no generic success fallback for a semantic failure."""
	return SaveHeader.Refusal.new(SaveHeader.REFUSE_NONE, "")
