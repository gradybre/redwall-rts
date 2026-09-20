extends RefCounted
## SAVE-CLAIMS-R01 v2: the section 7 `fishing` and `forage` claim-column adapter.
##
## `save_section_inventories.gd` owns the WIRE FORMAT and the generic validator for all six
## section 7 owners; `fishing.gd` and `forage.gd` now publish their claim columns. This module is
## the join between those two, for those TWO owners, and nothing else.
##
## NO CODEC-OWNER CYCLE. The codec is preloaded HERE, not from either owner, so neither owner
## keeps an edge back to a save module. The owners know packed columns; this file knows ordinals.
##
## ONE BLOCK AT A TIME, NEVER A SECTION. Every entry point takes a single `Codec.OwnerRecord`,
## never a `Codec.Record`, so handling one owner never allocates the other five blocks. A pair of
## claim blocks is NOT a completed section 7 and this module emits no `store_count`.
##
## STATELESS. No module-level var, no scratch argument, no caller-visible staging container and
## no invented Inventory dependency: these two owners have none.
##
## WHAT THIS ADAPTER DOES NOT DO. It does not acquire or release the load barrier -- it only asks
## the SUPPLIED clock whether one is held -- and it does not tick, pause, bind, claim, release,
## purge, reconcile, rebuild, repair or roll back a file. It makes no collaborator call, no
## signal, no callback and no yield, and it must not be re-entered: the caller guarantees a
## completed quiescent boundary. The owners' `_pending_*` values are stale scratch at such a
## boundary and are not consulted as busy flags.
##
## NOTHING IS REPAIRED ON THE WAY IN. The owners refuse a codec-admitted quantity of 0 or above
## 1180000, and a fishing slot count above the existing maximum habitat effort capacity; those
## codes are forwarded verbatim and no value is clamped, masked, normalized or remapped.
##
## FULL-WORLD ACTIVATION IS ELSEWHERE. Before a world resumes, the coordinator must run the new
## read-only checked claim reconciliation owned by SAVE-CLAIM-RECONCILIATION: row, Directory and
## Job association, reference liveness policy, habitat and zone presence, per-habitat effort
## capacity, checked aggregate totals against SAVED section 4 effort and quota columns, and
## Forage order-key provenance. A claim-only restore is not a resumed world.
##
## ARCH-SAVE-003 COLD PATH. A capture owns one owner Columns record plus one private staged
## OwnerRecord while the caller's target block and the live owner coexist; an apply owns one
## local Columns record whose constructor buffers are then replaced by borrowed block arrays,
## while the owner duplicates what it installs. No float, no reflection, no per-tick allocation.

const FishingScript := preload("res://scripts/core/fishing.gd")
const ForageScript := preload("res://scripts/core/forage.gd")
const Codec := preload("res://scripts/core/save_section_inventories.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")

## The two owners this adapter speaks for, and their compiled row bounds. Every number is READ
## from the module that owns it so none is restated here.
const FISHING_OWNER: int = Codec.OWNER_FISHING
const FORAGE_OWNER: int = Codec.OWNER_FORAGE
const FISHING_ROWS: int = FishingScript.FISHING_EFFORT_CLAIM_CAPACITY
const FORAGE_ROWS: int = ForageScript.FORAGE_CLAIM_CAPACITY

## How many columns each storage GROUP of a block holds. Checked before any group is indexed.
const FISHING_U8_COLUMNS: int = 1
const FISHING_I32_COLUMNS: int = 6
const FISHING_I64_COLUMNS: int = 0
const FORAGE_U8_COLUMNS: int = 1
const FORAGE_I32_COLUMNS: int = 7
const FORAGE_I64_COLUMNS: int = 3

## REG-R01's declared ordinals for `fishing`, in wire order. These are FIELD ordinals and never
## storage positions: every access below resolves one through `Codec.storage_index_of()`.
const FISH_ORDINAL_ACTIVE: int = 0
const FISH_ORDINAL_EXPEDITION_GENERATION: int = 1
const FISH_ORDINAL_HABITAT_SLOT: int = 2
const FISH_ORDINAL_HABITAT_GENERATION: int = 3
const FISH_ORDINAL_JOB_SLOT: int = 4
const FISH_ORDINAL_JOB_GENERATION: int = 5
const FISH_ORDINAL_SLOT_COUNT: int = 6

## REG-R01's declared ordinals for `forage`, in wire order.
const FORAGE_ORDINAL_ACTIVE: int = 0
const FORAGE_ORDINAL_JOB_SLOT: int = 1
const FORAGE_ORDINAL_JOB_GENERATION: int = 2
const FORAGE_ORDINAL_DESIGNATION_SLOT: int = 3
const FORAGE_ORDINAL_DESIGNATION_GENERATION: int = 4
const FORAGE_ORDINAL_BASIN_SLOT: int = 5
const FORAGE_ORDINAL_BASIN_GENERATION: int = 6
const FORAGE_ORDINAL_PATCH_KIND: int = 7
const FORAGE_ORDINAL_REMAINING_MILLI: int = 8
const FORAGE_ORDINAL_CREATED_TICK: int = 9
const FORAGE_ORDINAL_PERSISTENT_ID: int = 10

const REFUSE_NULL_STORE: StringName = &"SAVE_CLAIMS_NULL_STORE"
const REFUSE_BLOCK_SHAPE: StringName = &"SAVE_CLAIMS_BLOCK_SHAPE"
const REFUSE_NULL_CLOCK: StringName = &"SAVE_CLAIMS_NULL_CLOCK"
const REFUSE_BARRIER_NOT_HELD: StringName = &"SAVE_CLAIMS_BARRIER_NOT_HELD"


static func fishing_block_shape_refusal(block: Codec.OwnerRecord) -> SaveHeader.Refusal:
	"""TOTAL local shape gate for one `fishing` claim block, before anything indexes into it."""
	return _block_shape_refusal(block, FISHING_OWNER, FISHING_ROWS, FISHING_U8_COLUMNS,
		FISHING_I32_COLUMNS, FISHING_I64_COLUMNS)


static func forage_block_shape_refusal(block: Codec.OwnerRecord) -> SaveHeader.Refusal:
	"""TOTAL local shape gate for one `forage` claim block, before anything indexes into it."""
	return _block_shape_refusal(block, FORAGE_OWNER, FORAGE_ROWS, FORAGE_U8_COLUMNS,
		FORAGE_I32_COLUMNS, FORAGE_I64_COLUMNS)


static func capture_fishing_into(store: FishingScript,
		out: Codec.OwnerRecord) -> SaveHeader.Refusal:
	"""Stage one live fishing claim table into an existing `fishing` block, or refuse.

	Order, fixed: null store; the target block's total shape; the owner's own capture into a
	PRIVATE fixed Columns record; a PRIVATE staged OwnerRecord mapped field by field; the
	existing codec `owner_refusal()` over that staged record; and only then the target's three
	typed groups. The target's metadata is never written before a successful publication.

	The staged record never escapes, so its group containers may transfer ownership; a
	caller-visible group container is never reused. The published packed buffers are independent
	duplicates produced by the owner, so later mutation on either side cannot leak across.

	The codec gate is a DEFENSIVE owner/codec equivalence check -- the owner's domains are
	stricter -- and promises no reachable healthy failure after an owner success. Should it
	refuse, the returned Refusal is authoritative even though the successful owner capture has
	already cleared the owner's own claim diagnostic.
	"""
	if store == null:
		return _refuse(REFUSE_NULL_STORE, "no fishing store was supplied to capture from")
	var shape: SaveHeader.Refusal = fishing_block_shape_refusal(out)
	if not shape.is_ok():
		return shape
	var columns: FishingScript.EffortClaimColumns = FishingScript.EffortClaimColumns.new()
	if not store.copy_effort_claim_columns_into(columns):
		return _refuse(store.last_claim_column_refusal(), store.claim_column_detail())
	var staged: Codec.OwnerRecord = Codec.OwnerRecord.new(FISHING_OWNER, FISHING_ROWS,
		PackedInt64Array())
	staged.u8_columns[Codec.storage_index_of(FISHING_OWNER, FISH_ORDINAL_ACTIVE)] = \
		columns.effort_claim_active
	staged.i32_columns[Codec.storage_index_of(FISHING_OWNER,
		FISH_ORDINAL_EXPEDITION_GENERATION)] = columns.effort_claim_expedition_generation
	staged.i32_columns[Codec.storage_index_of(FISHING_OWNER, FISH_ORDINAL_HABITAT_SLOT)] = \
		columns.effort_claim_habitat_slot
	staged.i32_columns[Codec.storage_index_of(FISHING_OWNER, FISH_ORDINAL_HABITAT_GENERATION)] = \
		columns.effort_claim_habitat_generation
	staged.i32_columns[Codec.storage_index_of(FISHING_OWNER, FISH_ORDINAL_JOB_SLOT)] = \
		columns.effort_claim_job_slot
	staged.i32_columns[Codec.storage_index_of(FISHING_OWNER, FISH_ORDINAL_JOB_GENERATION)] = \
		columns.effort_claim_job_generation
	staged.i32_columns[Codec.storage_index_of(FISHING_OWNER, FISH_ORDINAL_SLOT_COUNT)] = \
		columns.effort_claim_slot_count
	var invalid: SaveHeader.Refusal = Codec.owner_refusal(staged)
	if not invalid.is_ok():
		return invalid
	out.u8_columns = staged.u8_columns
	out.i32_columns = staged.i32_columns
	out.i64_columns = staged.i64_columns
	return _accepted()


static func capture_forage_into(store: ForageScript,
		out: Codec.OwnerRecord) -> SaveHeader.Refusal:
	"""Stage one live forage claim table into an existing `forage` block, or refuse.

	The same fixed order and the same staging discipline as `capture_fishing_into()`, over the
	eleven forage columns. Section 1's tile head column, the zones, the patches and the link
	arena are neither read nor written here.
	"""
	if store == null:
		return _refuse(REFUSE_NULL_STORE, "no forage store was supplied to capture from")
	var shape: SaveHeader.Refusal = forage_block_shape_refusal(out)
	if not shape.is_ok():
		return shape
	var columns: ForageScript.ForageClaimColumns = ForageScript.ForageClaimColumns.new()
	if not store.copy_forage_claim_columns_into(columns):
		return _refuse(store.last_claim_column_refusal(), store.claim_column_detail())
	var staged: Codec.OwnerRecord = Codec.OwnerRecord.new(FORAGE_OWNER, FORAGE_ROWS,
		PackedInt64Array())
	staged.u8_columns[Codec.storage_index_of(FORAGE_OWNER, FORAGE_ORDINAL_ACTIVE)] = \
		columns.claim_active
	staged.i32_columns[Codec.storage_index_of(FORAGE_OWNER, FORAGE_ORDINAL_JOB_SLOT)] = \
		columns.claim_job_slot
	staged.i32_columns[Codec.storage_index_of(FORAGE_OWNER, FORAGE_ORDINAL_JOB_GENERATION)] = \
		columns.claim_job_generation
	staged.i32_columns[Codec.storage_index_of(FORAGE_OWNER, FORAGE_ORDINAL_DESIGNATION_SLOT)] = \
		columns.claim_designation_slot
	staged.i32_columns[Codec.storage_index_of(FORAGE_OWNER,
		FORAGE_ORDINAL_DESIGNATION_GENERATION)] = columns.claim_designation_generation
	staged.i32_columns[Codec.storage_index_of(FORAGE_OWNER, FORAGE_ORDINAL_BASIN_SLOT)] = \
		columns.claim_basin_slot
	staged.i32_columns[Codec.storage_index_of(FORAGE_OWNER, FORAGE_ORDINAL_BASIN_GENERATION)] = \
		columns.claim_basin_generation
	staged.i32_columns[Codec.storage_index_of(FORAGE_OWNER, FORAGE_ORDINAL_PATCH_KIND)] = \
		columns.claim_patch_kind
	staged.i64_columns[Codec.storage_index_of(FORAGE_OWNER, FORAGE_ORDINAL_REMAINING_MILLI)] = \
		columns.claim_remaining_milli
	staged.i64_columns[Codec.storage_index_of(FORAGE_OWNER, FORAGE_ORDINAL_CREATED_TICK)] = \
		columns.claim_created_tick
	staged.i64_columns[Codec.storage_index_of(FORAGE_OWNER, FORAGE_ORDINAL_PERSISTENT_ID)] = \
		columns.claim_persistent_id
	var invalid: SaveHeader.Refusal = Codec.owner_refusal(staged)
	if not invalid.is_ok():
		return invalid
	out.u8_columns = staged.u8_columns
	out.i32_columns = staged.i32_columns
	out.i64_columns = staged.i64_columns
	return _accepted()


static func apply_fishing(block: Codec.OwnerRecord, store: FishingScript,
		clock: SimClock = null) -> SaveHeader.Refusal:
	"""Publish one decoded `fishing` claim block into a live store behind a held load barrier.

	Order, fixed: null block (BLOCK_SHAPE); null store; null clock; a clock whose barrier is NOT
	held; the block's total shape; the existing codec `owner_refusal()`; one LOCAL fixed Columns
	record borrowing the validated block arrays; then the owner's own restore, which validates
	again on its own stricter terms and duplicates what it installs.

	The barrier is only QUERIED: this adapter never acquires or releases one, never ticks and
	binds nothing. The clock is required for the barrier alone and none of its fields change.

	A failure leaves the block, the live store and the clock unchanged, except the owner's own
	claim diagnostic when its API was actually reached; an adapter early failure leaves that
	older owner diagnostic alone. The returned Refusal is authoritative either way.
	"""
	if block == null:
		return _refuse(REFUSE_BLOCK_SHAPE, "no fishing claim block was supplied to apply")
	if store == null:
		return _refuse(REFUSE_NULL_STORE, "no fishing store was supplied to restore into")
	if clock == null:
		return _refuse(REFUSE_NULL_CLOCK,
			"no clock was supplied, so no load barrier can be shown to be held")
	if not clock.is_load_barrier_held():
		return _refuse(REFUSE_BARRIER_NOT_HELD,
			"the supplied clock holds no load barrier; this adapter never acquires one")
	var shape: SaveHeader.Refusal = fishing_block_shape_refusal(block)
	if not shape.is_ok():
		return shape
	var invalid: SaveHeader.Refusal = Codec.owner_refusal(block)
	if not invalid.is_ok():
		return invalid
	var columns: FishingScript.EffortClaimColumns = FishingScript.EffortClaimColumns.new()
	columns.effort_claim_active = \
		block.u8_columns[Codec.storage_index_of(FISHING_OWNER, FISH_ORDINAL_ACTIVE)]
	columns.effort_claim_expedition_generation = block.i32_columns[Codec.storage_index_of(
		FISHING_OWNER, FISH_ORDINAL_EXPEDITION_GENERATION)]
	columns.effort_claim_habitat_slot = \
		block.i32_columns[Codec.storage_index_of(FISHING_OWNER, FISH_ORDINAL_HABITAT_SLOT)]
	columns.effort_claim_habitat_generation = \
		block.i32_columns[Codec.storage_index_of(FISHING_OWNER, FISH_ORDINAL_HABITAT_GENERATION)]
	columns.effort_claim_job_slot = \
		block.i32_columns[Codec.storage_index_of(FISHING_OWNER, FISH_ORDINAL_JOB_SLOT)]
	columns.effort_claim_job_generation = \
		block.i32_columns[Codec.storage_index_of(FISHING_OWNER, FISH_ORDINAL_JOB_GENERATION)]
	columns.effort_claim_slot_count = \
		block.i32_columns[Codec.storage_index_of(FISHING_OWNER, FISH_ORDINAL_SLOT_COUNT)]
	if not store.restore_effort_claim_columns(columns):
		return _refuse(store.last_claim_column_refusal(), store.claim_column_detail())
	return _accepted()


static func apply_forage(block: Codec.OwnerRecord, store: ForageScript,
		clock: SimClock = null) -> SaveHeader.Refusal:
	"""Publish one decoded `forage` claim block into a live store behind a held load barrier.

	The same fixed order and the same borrowing discipline as `apply_fishing()`, over the eleven
	forage columns. The owner preserves the canonical created tick and persistent id verbatim;
	nothing here rewrites an ordering key or a reservation aggregate.
	"""
	if block == null:
		return _refuse(REFUSE_BLOCK_SHAPE, "no forage claim block was supplied to apply")
	if store == null:
		return _refuse(REFUSE_NULL_STORE, "no forage store was supplied to restore into")
	if clock == null:
		return _refuse(REFUSE_NULL_CLOCK,
			"no clock was supplied, so no load barrier can be shown to be held")
	if not clock.is_load_barrier_held():
		return _refuse(REFUSE_BARRIER_NOT_HELD,
			"the supplied clock holds no load barrier; this adapter never acquires one")
	var shape: SaveHeader.Refusal = forage_block_shape_refusal(block)
	if not shape.is_ok():
		return shape
	var invalid: SaveHeader.Refusal = Codec.owner_refusal(block)
	if not invalid.is_ok():
		return invalid
	var columns: ForageScript.ForageClaimColumns = ForageScript.ForageClaimColumns.new()
	columns.claim_active = \
		block.u8_columns[Codec.storage_index_of(FORAGE_OWNER, FORAGE_ORDINAL_ACTIVE)]
	columns.claim_job_slot = \
		block.i32_columns[Codec.storage_index_of(FORAGE_OWNER, FORAGE_ORDINAL_JOB_SLOT)]
	columns.claim_job_generation = \
		block.i32_columns[Codec.storage_index_of(FORAGE_OWNER, FORAGE_ORDINAL_JOB_GENERATION)]
	columns.claim_designation_slot = \
		block.i32_columns[Codec.storage_index_of(FORAGE_OWNER, FORAGE_ORDINAL_DESIGNATION_SLOT)]
	columns.claim_designation_generation = block.i32_columns[Codec.storage_index_of(
		FORAGE_OWNER, FORAGE_ORDINAL_DESIGNATION_GENERATION)]
	columns.claim_basin_slot = \
		block.i32_columns[Codec.storage_index_of(FORAGE_OWNER, FORAGE_ORDINAL_BASIN_SLOT)]
	columns.claim_basin_generation = \
		block.i32_columns[Codec.storage_index_of(FORAGE_OWNER, FORAGE_ORDINAL_BASIN_GENERATION)]
	columns.claim_patch_kind = \
		block.i32_columns[Codec.storage_index_of(FORAGE_OWNER, FORAGE_ORDINAL_PATCH_KIND)]
	columns.claim_remaining_milli = \
		block.i64_columns[Codec.storage_index_of(FORAGE_OWNER, FORAGE_ORDINAL_REMAINING_MILLI)]
	columns.claim_created_tick = \
		block.i64_columns[Codec.storage_index_of(FORAGE_OWNER, FORAGE_ORDINAL_CREATED_TICK)]
	columns.claim_persistent_id = \
		block.i64_columns[Codec.storage_index_of(FORAGE_OWNER, FORAGE_ORDINAL_PERSISTENT_ID)]
	if not store.restore_forage_claim_columns(columns):
		return _refuse(store.last_claim_column_refusal(), store.claim_column_detail())
	return _accepted()


static func _block_shape_refusal(block: Codec.OwnerRecord, owner: int, rows: int,
		u8_count: int, i32_count: int, i64_count: int) -> SaveHeader.Refusal:
	"""Null; the declared owner; the fixed primary count; no child extents; the three storage
	GROUP sizes; and only THEN every column's own length against the primary count.

	The codec's generic `owner_refusal()` is not called from here and must not run before this
	passes: it assumes a well-shaped block and would index columns a hostile block need not have.
	Both claim tables are native fixed slices, so a record cannot reconfigure their extent.
	"""
	if block == null:
		return _refuse(REFUSE_BLOCK_SHAPE, "no claim owner block was supplied")
	if block.owner != owner:
		return _refuse(REFUSE_BLOCK_SHAPE,
			"block declares owner %d, not the claim owner %d" % [block.owner, owner])
	if block.primary_count != rows:
		return _refuse(REFUSE_BLOCK_SHAPE,
			"block declares primary_count %d, not the fixed %d" % [block.primary_count, rows])
	if block.child_extents.size() != 0:
		return _refuse(REFUSE_BLOCK_SHAPE,
			"this owner declares no child extents, but the block carries %d"
				% block.child_extents.size())
	if block.u8_columns.size() != u8_count or block.i32_columns.size() != i32_count \
			or block.i64_columns.size() != i64_count:
		return _refuse(REFUSE_BLOCK_SHAPE,
			"block holds %d u8, %d i32 and %d i64 columns, not %d/%d/%d"
				% [block.u8_columns.size(), block.i32_columns.size(), block.i64_columns.size(),
					u8_count, i32_count, i64_count])
	for index: int in u8_count:
		if block.u8_columns[index].size() != rows:
			return _refuse(REFUSE_BLOCK_SHAPE,
				"u8 column %d holds %d cells, not %d"
					% [index, block.u8_columns[index].size(), rows])
	for index: int in i32_count:
		if block.i32_columns[index].size() != rows:
			return _refuse(REFUSE_BLOCK_SHAPE,
				"i32 column %d holds %d cells, not %d"
					% [index, block.i32_columns[index].size(), rows])
	for index: int in i64_count:
		if block.i64_columns[index].size() != rows:
			return _refuse(REFUSE_BLOCK_SHAPE,
				"i64 column %d holds %d cells, not %d"
					% [index, block.i64_columns[index].size(), rows])
	return _accepted()


static func _refuse(code: StringName, detail: String) -> SaveHeader.Refusal:
	"""Build one refusal. Owner column codes and codec codes are forwarded verbatim."""
	return SaveHeader.Refusal.new(code, detail)


static func _accepted() -> SaveHeader.Refusal:
	"""The accepting refusal. There is no generic success fallback for a semantic failure."""
	return SaveHeader.Refusal.new(SaveHeader.REFUSE_NONE, "")
