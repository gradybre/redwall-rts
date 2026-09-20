extends RefCounted
## Global reservation pool: 32768 rows allocated from the lowest free index (decision 0019).
##
## GDD §4.2 fixes the row shape this module owns:
##   Reservation: job: EntityRef, lot: EntityRef, quantity_milli: int64, expiry: int64,
##                purpose: enum -- at most 32768 rows; total per lot <= quantity
##
## DECISION 0019 resolved blocker U4. Rows are allocated GLOBALLY from a lowest-free-index
## min-heap. There is no owner-major `job*4+i` indexing: 32768 rows against 8192 Job rows was a
## storage budget, not a recipe rule, and reading it as owner-major would cap a recipe at four
## input lots -- which even a two-ingredient recipe exceeds once inventory fragments. Each Job
## and each InventoryLot therefore carries a VARIABLE-LENGTH intrusive doubly linked list of
## rows, and the number of lots one job may claim is bounded only by the global pool.
##
## Decision 0017: shared input claims belong to the COORDINATOR Job, never to a member Job.
## Nothing here associates a claim with a worker, so replacing a party member cannot move,
## release, or duplicate a shared claim; a member's departure only releases the member Job's
## own rows.
##
## THE INVARIANT this module exists to hold (decision 0019):
##     lot.reserved_milli == sum(active reservation quantities for that lot) <= lot.quantity_milli
## The left-hand side lives in `inventory.gd` and is only ever changed here through that
## module's PUBLIC API (`reserve_lot` / `release_reservation`), inside its own all-or-nothing
## transaction. This module never touches an inventory column.
##
## ALL-OR-NOTHING (decision 0019, BAL-SAFE-005). `claim_batch()` preflights the COMPLETE
## transaction -- ref validity, per-lot availability, and free-row count after coalescing --
## before a single byte is written anywhere. Insufficient rows produce an explicit
## `CAPACITY_RESERVATION` refusal and leave no partial reservation behind. The write phase then
## runs strictly in the order inventory-first, pool-second, so the only step that could still
## refuse (the inventory reservation) happens while the pool is still untouched and while
## inventory's own journal can roll it back.
##
## COALESCING. Claims with identical `(job_ref, lot_ref, purpose)` share one row and their
## quantities add. That key is the whole identity of a row, so at most one active row exists per
## triple; duplicates within a single batch coalesce with each other as well as with a row that
## already exists.
##
## NO SENTINEL RETURNS. Every mutator returns an `Inventory.OpResult` carrying an explicit
## refusal code. `NULL_ROW` is a linked-list terminator returned by the iteration accessors, not
## a failure signal, and every accessor that could otherwise need one is either guarded by
## `has_claim()` or written in the non-allocating `_into(..., out) -> bool` form.
##
## ARCH-MEM-001/005: every column is a packed array sized once in `_init()`. `clear()` refills
## the existing buffers; nothing here calls `resize()` outside construction and outside the
## diagnostic `state_bytes()`.
##
## UNRESOLVED CONTRACTS, implemented as narrowly as possible rather than guessed:
##  - `purpose` is an OPAQUE int32. GDD §4.3 numbers no `ReservationPurpose` domain, so this
##    module never interprets the value; it compares it for equality (coalescing) and for order
##    (canonical serialization) and nothing else. It is deliberately NOT mirrored into
##    `catalog.gd`'s protected enums, because there is no specified numbering to protect.
##  - `expiry` is an OPAQUE absolute tick. `release_expired_for_job()` reads
##    `now_tick >= expiry` as expired, and there is no encoding for "never expires" because
##    GDD §4.2 gives the field no such sentinel. The cross-job expiry sweep of BAL-SAFE-004 --
##    "release all its rows in job-ID order" -- needs the Job store's persistent-ID mapping,
##    which lives in `jobs.gd`; it is NOT implemented here, and the per-job entry point above is
##    what that sweep will call.
##  - Coalescing an existing row with a claim carrying a LATER expiry extends the row to the
##    later one. Decision 0019 leaves the key free of `expiry`, so one of the two must win, and
##    only the later one is safe: taking the earlier would silently retire a lease a live claim
##    still depends on. Recorded as a resolution, not as a specified rule.

const Inventory := preload("res://scripts/core/inventory.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

## Reservation rows, GDD §4.2 / ARCH-MEM-002.
const ROW_CAPACITY: int = 32768
## Job rows, systems_architecture.md §2.1. Bounds the job-head column.
const JOB_CAPACITY: int = 8192
## InventoryLot rows, matching `inventory.gd`'s LOT_CAPACITY. Bounds the lot-head column.
const LOT_CAPACITY: int = 16384

## End of an intrusive list, and the "no such row" answer from a lookup. NOT a refusal code:
## no public mutator ever returns it in place of an error.
const NULL_ROW: int = -1
const NULL_SLOT: int = -1
const NULL_GENERATION: int = 0
const NULL_REF: Vector2i = Vector2i(NULL_SLOT, NULL_GENERATION)

const INT32_MIN: int = -2147483648
const INT32_MAX: int = 2147483647

## A batch is a flat int64 array of `claim_count` records of CLAIM_STRIDE fields. Passing the
## claims as one caller-owned buffer keeps this module free of a staging arena that the memory
## ledger does not budget, and lets a caller reuse one buffer forever (ARCH-MEM-005).
const CLAIM_STRIDE: int = 5
const CLAIM_LOT_SLOT: int = 0
const CLAIM_LOT_GENERATION: int = 1
const CLAIM_PURPOSE: int = 2
const CLAIM_QUANTITY_MILLI: int = 3
const CLAIM_EXPIRY: int = 4

## Decision 0019's indexing ledger, in bytes, at full capacity. `indexing_bytes()` re-derives
## this from the columns actually allocated, so a layout change cannot drift from the budget.
const BUDGET_INDEXING_BYTES: int = 786436
## The Reservation payload already carried by systems_architecture.md §2.1 (5xI32 + 2xI64).
const BUDGET_PAYLOAD_BYTES: int = 1179648

const REFUSE_NONE: StringName = &""
const REFUSE_NO_INVENTORY: StringName = &"NO_INVENTORY"
const REFUSE_INVENTORY_TRANSACTION_OPEN: StringName = &"INVENTORY_TRANSACTION_OPEN"
const REFUSE_EMPTY_BATCH: StringName = &"EMPTY_BATCH"
const REFUSE_MALFORMED_BATCH: StringName = &"MALFORMED_BATCH"
const REFUSE_INVALID_JOB: StringName = &"INVALID_JOB"
const REFUSE_JOB_OUT_OF_RANGE: StringName = &"JOB_OUT_OF_RANGE"
const REFUSE_JOB_GENERATION_CONFLICT: StringName = &"JOB_GENERATION_CONFLICT"
const REFUSE_INVALID_LOT: StringName = &"INVALID_LOT"
const REFUSE_LOT_OUT_OF_RANGE: StringName = &"LOT_OUT_OF_RANGE"
const REFUSE_LOT_GENERATION_CONFLICT: StringName = &"LOT_GENERATION_CONFLICT"
const REFUSE_LOT_STILL_LIVE: StringName = &"LOT_STILL_LIVE"
const REFUSE_INVALID_QUANTITY: StringName = &"INVALID_QUANTITY"
const REFUSE_INVALID_PURPOSE: StringName = &"INVALID_PURPOSE"
const REFUSE_INVALID_EXPIRY: StringName = &"INVALID_EXPIRY"
const REFUSE_INSUFFICIENT_UNRESERVED: StringName = &"INSUFFICIENT_UNRESERVED"
const REFUSE_CAPACITY_RESERVATION: StringName = &"CAPACITY_RESERVATION"
const REFUSE_NO_SUCH_CLAIM: StringName = &"NO_SUCH_CLAIM"
const REFUSE_EXPIRY_NOT_LATER: StringName = &"EXPIRY_NOT_LATER"
const REFUSE_OVERFLOW: StringName = &"OVERFLOW"
const REFUSE_AUDIT_OCCUPANCY: StringName = &"AUDIT_OCCUPANCY_MISMATCH"
const REFUSE_AUDIT_HEAP: StringName = &"AUDIT_HEAP_MISMATCH"
const REFUSE_AUDIT_JOB_LIST: StringName = &"AUDIT_JOB_LIST_BROKEN"
const REFUSE_AUDIT_LOT_LIST: StringName = &"AUDIT_LOT_LIST_BROKEN"
const REFUSE_AUDIT_RESERVED_TOTAL: StringName = &"AUDIT_RESERVED_TOTAL_MISMATCH"
const REFUSE_AUDIT_RESERVED_EXCEEDS: StringName = &"AUDIT_RESERVED_EXCEEDS_QUANTITY"

# --- Reservation payload columns (systems_architecture.md §2.1: 5 x I32 + 2 x I64) ------------
var _r_job_slot: PackedInt32Array = PackedInt32Array()
var _r_job_generation: PackedInt32Array = PackedInt32Array()
var _r_lot_slot: PackedInt32Array = PackedInt32Array()
var _r_lot_generation: PackedInt32Array = PackedInt32Array()
var _r_purpose: PackedInt32Array = PackedInt32Array()
var _r_quantity_milli: PackedInt64Array = PackedInt64Array()
var _r_expiry: PackedInt64Array = PackedInt64Array()

# --- Indexing columns, decision 0019's ledger -------------------------------------------------
## 1 while a row is active. Byte column, one per row.
var _occupied: PackedByteArray = PackedByteArray()
## Free rows as a min-heap, so an allocation always returns the LOWEST free index. Same shape
## as `entity_directory.gd`'s ARCH-ID-002 heaps; a stack would reuse the most recently freed row
## instead, which is not what decision 0019 specifies.
var _free_heap: PackedInt32Array = PackedInt32Array()
var _free_count: int = 0
## Head of each Job's list, indexed by job slot. NULL_ROW when the job holds no claim.
var _job_head: PackedInt32Array = PackedInt32Array()
## Head of each InventoryLot's list, indexed by lot slot.
var _lot_head: PackedInt32Array = PackedInt32Array()
## Intrusive links. The job list is kept sorted by `(lot_slot, lot_generation, purpose)` and the
## lot list by `(job_slot, job_generation, purpose)`. Both keys are unique inside their list
## because coalescing makes `(job, lot, purpose)` unique, so each list has exactly ONE canonical
## order that does not depend on the order the claims arrived or on which rows were free at the
## time. That is what makes `state_bytes()` comparable across two logically identical worlds and
## what gives GDD §5.8's "reservations invalidate in stable order" a stable order to use.
var _job_prev: PackedInt32Array = PackedInt32Array()
var _job_next: PackedInt32Array = PackedInt32Array()
var _lot_prev: PackedInt32Array = PackedInt32Array()
var _lot_next: PackedInt32Array = PackedInt32Array()

var _row_capacity: int = 0
var _job_capacity: int = 0
var _lot_capacity: int = 0
var _active_count: int = 0

## Scratch, not state. Checked arithmetic lands here; `_preflight_rows()` leaves the number of
## fresh rows the batch needs here for `claim_batch()` to report.
var _math: IntMath.IntResult = IntMath.IntResult.new()
var _pending_new_rows: int = 0


func _init(p_row_capacity: int = ROW_CAPACITY, p_job_capacity: int = JOB_CAPACITY, p_lot_capacity: int = LOT_CAPACITY) -> void:
	"""Allocate every column once at the requested capacities.

	Defaults are the specification bounds. A test or bounded harness may ask for less; a larger
	request is clamped down, because the memory ledger fixes the maxima.
	"""
	_row_capacity = clampi(p_row_capacity, 1, ROW_CAPACITY)
	_job_capacity = clampi(p_job_capacity, 1, JOB_CAPACITY)
	_lot_capacity = clampi(p_lot_capacity, 1, LOT_CAPACITY)
	_allocate_columns()
	clear()


func _allocate_columns() -> void:
	"""The only place that sizes a packed column (ARCH-MEM-005: allocate once)."""
	_r_job_slot.resize(_row_capacity)
	_r_job_generation.resize(_row_capacity)
	_r_lot_slot.resize(_row_capacity)
	_r_lot_generation.resize(_row_capacity)
	_r_purpose.resize(_row_capacity)
	_r_quantity_milli.resize(_row_capacity)
	_r_expiry.resize(_row_capacity)
	_occupied.resize(_row_capacity)
	_free_heap.resize(_row_capacity)
	_job_prev.resize(_row_capacity)
	_job_next.resize(_row_capacity)
	_lot_prev.resize(_row_capacity)
	_lot_next.resize(_row_capacity)
	_job_head.resize(_job_capacity)
	_lot_head.resize(_lot_capacity)


func clear() -> void:
	"""Drop every claim and refill the free heap without reallocating a column.

	This releases nothing in any inventory: it is a world teardown, not a gameplay operation.
	A caller holding a live inventory must release its claims first, or that inventory's
	`reserved_milli` will outlive the rows that justified it.
	"""
	_r_job_slot.fill(NULL_SLOT)
	_r_job_generation.fill(NULL_GENERATION)
	_r_lot_slot.fill(NULL_SLOT)
	_r_lot_generation.fill(NULL_GENERATION)
	_r_purpose.fill(0)
	_r_quantity_milli.fill(0)
	_r_expiry.fill(0)
	_occupied.fill(0)
	_job_prev.fill(NULL_ROW)
	_job_next.fill(NULL_ROW)
	_lot_prev.fill(NULL_ROW)
	_lot_next.fill(NULL_ROW)
	_job_head.fill(NULL_ROW)
	_lot_head.fill(NULL_ROW)
	for row: int in range(_row_capacity):
		_free_heap[row] = row
	_free_count = _row_capacity
	_active_count = 0
	_pending_new_rows = 0


# --- Capacity and budget ----------------------------------------------------------------------

func row_capacity() -> int:
	"""Total reservation rows this pool was allocated."""
	return _row_capacity


func job_capacity() -> int:
	"""Number of job slots this pool indexes."""
	return _job_capacity


func lot_capacity() -> int:
	"""Number of inventory lot slots this pool indexes."""
	return _lot_capacity


func free_row_count() -> int:
	"""Reservation rows still available to allocate."""
	return _free_count


func active_row_count() -> int:
	"""Reservation rows currently holding a claim."""
	return _active_count


func indexing_bytes() -> int:
	"""Bytes of decision 0019's indexing allocation, re-derived from the live columns.

	Counts the packed payloads only: occupancy byte column, free-row min-heap, the int32 heap
	count, both head columns, and the four link columns. At full capacity this must equal
	BUDGET_INDEXING_BYTES.
	"""
	var links: int = _job_prev.size() + _job_next.size() + _lot_prev.size() + _lot_next.size()
	return _occupied.size() + (_free_heap.size() * 4) + 4 + (_job_head.size() * 4) \
		+ (_lot_head.size() * 4) + (links * 4)


func payload_bytes() -> int:
	"""Bytes of the Reservation payload columns, re-derived from the live columns."""
	var int32_fields: int = _r_job_slot.size() + _r_job_generation.size() + _r_lot_slot.size() \
		+ _r_lot_generation.size() + _r_purpose.size()
	var int64_fields: int = _r_quantity_milli.size() + _r_expiry.size()
	return (int32_fields * 4) + (int64_fields * 8)


# --- Claiming ---------------------------------------------------------------------------------

func claim_batch(job_ref: Vector2i, claims: PackedInt64Array, claim_count: int, inventory: Inventory) -> Inventory.OpResult:
	"""Reserve every claim in one batch for one Job, or refuse and change nothing.

	`claims` is `claim_count` records of CLAIM_STRIDE int64 fields, in the CLAIM_* order. The
	whole transaction is preflighted first, so a refusal -- including the CAPACITY_RESERVATION
	refusal that decision 0019 requires when the pool cannot supply enough rows -- leaves both
	the pool and the inventory exactly as it found them. On success `.value` is the number of
	FRESH rows consumed, which is below `claim_count` whenever a claim coalesced.

	Shared claims belong to the coordinator Job (decision 0017): `job_ref` is whichever Job owns
	the claim, and this module attaches nothing to a worker.

	One inherited bound: the inventory side runs in a single `inventory.gd` transaction, whose
	undo journal holds 4096 entries at 14 per lot touched. A batch large enough to overrun it is
	refused with that module's `JOURNAL_FULL`, explicitly and with nothing applied.
	"""
	var refusal: StringName = _preflight_batch(job_ref, claims, claim_count, inventory)
	if refusal != REFUSE_NONE:
		return _refuse(refusal)
	var new_rows: int = _pending_new_rows
	refusal = _apply_inventory_claims(claims, claim_count, inventory)
	if refusal != REFUSE_NONE:
		return _refuse(refusal)
	_apply_pool_rows(job_ref, claims, claim_count)
	return _ok(job_ref, new_rows)


func _preflight_batch(job_ref: Vector2i, claims: PackedInt64Array, claim_count: int, inventory: Inventory) -> StringName:
	"""Validate the complete transaction without writing anything. REFUSE_NONE means it may run."""
	if inventory == null:
		return REFUSE_NO_INVENTORY
	if inventory.is_transaction_open():
		# The pool's rows are not journaled by inventory's undo log, so joining a caller's open
		# transaction would let a later rollback restore `reserved_milli` while the rows stay --
		# breaking the very invariant this module exists to hold. Refuse instead.
		return REFUSE_INVENTORY_TRANSACTION_OPEN
	if claim_count <= 0:
		return REFUSE_EMPTY_BATCH
	if claims.size() < claim_count * CLAIM_STRIDE:
		return REFUSE_MALFORMED_BATCH
	var refusal: StringName = _check_job_ref(job_ref)
	if refusal != REFUSE_NONE:
		return refusal
	refusal = _preflight_claim_fields(claims, claim_count, inventory)
	if refusal != REFUSE_NONE:
		return refusal
	refusal = _preflight_quantities(claims, claim_count, inventory)
	if refusal != REFUSE_NONE:
		return refusal
	return _preflight_rows(job_ref, claims, claim_count)


func _check_job_ref(job_ref: Vector2i) -> StringName:
	"""Check a job reference is usable as a pool key and does not collide with a live generation.

	Job liveness itself belongs to the Job store, which this module deliberately does not depend
	on. What IS checked here is that the slot is in range, that the reference is not the null
	reference, and that the slot's existing list -- if any -- belongs to the SAME generation. A
	mismatch means a destroyed job left claims behind; that is a leak in the caller and is
	refused at the point of the bug rather than discovered later by `audit()`.
	"""
	if job_ref.x < 0 or job_ref.x >= _job_capacity:
		return REFUSE_JOB_OUT_OF_RANGE
	if job_ref.y <= NULL_GENERATION:
		return REFUSE_INVALID_JOB
	var head: int = _job_head[job_ref.x]
	if head != NULL_ROW and _r_job_generation[head] != job_ref.y:
		return REFUSE_JOB_GENERATION_CONFLICT
	return REFUSE_NONE


func _preflight_claim_fields(claims: PackedInt64Array, claim_count: int, inventory: Inventory) -> StringName:
	"""Validate every field of every claim record: lot ref, quantity, purpose and expiry."""
	for index: int in range(claim_count):
		var base: int = index * CLAIM_STRIDE
		var lot_slot: int = claims[base + CLAIM_LOT_SLOT]
		if lot_slot < 0 or lot_slot >= _lot_capacity:
			return REFUSE_LOT_OUT_OF_RANGE
		var lot_ref: Vector2i = Vector2i(lot_slot, claims[base + CLAIM_LOT_GENERATION])
		if not inventory.is_lot_valid(lot_ref):
			return REFUSE_INVALID_LOT
		var head: int = _lot_head[lot_slot]
		if head != NULL_ROW and _r_lot_generation[head] != lot_ref.y:
			return REFUSE_LOT_GENERATION_CONFLICT
		if claims[base + CLAIM_QUANTITY_MILLI] <= 0:
			return REFUSE_INVALID_QUANTITY
		var purpose: int = claims[base + CLAIM_PURPOSE]
		if purpose < INT32_MIN or purpose > INT32_MAX:
			return REFUSE_INVALID_PURPOSE
		if claims[base + CLAIM_EXPIRY] < 0:
			return REFUSE_INVALID_EXPIRY
	return REFUSE_NONE


func _preflight_quantities(claims: PackedInt64Array, claim_count: int, inventory: Inventory) -> StringName:
	"""Check every lot in the batch can supply the TOTAL this batch asks of it.

	Several records may name the same lot; each is checked once, against the sum of all records
	naming it, so a batch cannot pass by having each piece fit while the whole does not. Keying
	on the lot slot alone is sound because `_preflight_claim_fields()` already proved every
	record's reference valid, and a live lot slot carries exactly one generation.
	"""
	for index: int in range(claim_count):
		var base: int = index * CLAIM_STRIDE
		var lot_slot: int = claims[base + CLAIM_LOT_SLOT]
		if _first_index_of_lot(claims, claim_count, lot_slot) != index:
			continue
		var total: int = 0
		for other: int in range(index, claim_count):
			var other_base: int = other * CLAIM_STRIDE
			if claims[other_base + CLAIM_LOT_SLOT] != lot_slot:
				continue
			if not IntMath.checked_add_into(total, claims[other_base + CLAIM_QUANTITY_MILLI], _math):
				return REFUSE_OVERFLOW
			total = _math.value
		var lot_ref: Vector2i = Vector2i(lot_slot, claims[base + CLAIM_LOT_GENERATION])
		if total > inventory.lot_available_milli(lot_ref):
			return REFUSE_INSUFFICIENT_UNRESERVED
	return REFUSE_NONE


func _preflight_rows(job_ref: Vector2i, claims: PackedInt64Array, claim_count: int) -> StringName:
	"""Count the fresh rows the batch needs after coalescing and refuse if the pool lacks them.

	A record needs no fresh row when an active row already carries its `(job, lot, purpose)`, or
	when an earlier record in the same batch carries the same triple. The count lands in
	`_pending_new_rows` for the caller to report.
	"""
	var needed: int = 0
	for index: int in range(claim_count):
		if _first_index_of_key(claims, claim_count, index) != index:
			continue
		var base: int = index * CLAIM_STRIDE
		var lot_ref: Vector2i = Vector2i(claims[base + CLAIM_LOT_SLOT], claims[base + CLAIM_LOT_GENERATION])
		if _find_row(job_ref, lot_ref, claims[base + CLAIM_PURPOSE]) != NULL_ROW:
			continue
		needed += 1
	_pending_new_rows = needed
	if needed > _free_count:
		return REFUSE_CAPACITY_RESERVATION
	return REFUSE_NONE


func _first_index_of_lot(claims: PackedInt64Array, claim_count: int, lot_slot: int) -> int:
	"""Index of the first record naming `lot_slot`, or `claim_count` when none does."""
	for index: int in range(claim_count):
		if claims[index * CLAIM_STRIDE + CLAIM_LOT_SLOT] == lot_slot:
			return index
	return claim_count


func _first_index_of_key(claims: PackedInt64Array, claim_count: int, index: int) -> int:
	"""Index of the first record sharing record `index`'s `(lot, purpose)` coalescing key."""
	var base: int = index * CLAIM_STRIDE
	var lot_slot: int = claims[base + CLAIM_LOT_SLOT]
	var lot_generation: int = claims[base + CLAIM_LOT_GENERATION]
	var purpose: int = claims[base + CLAIM_PURPOSE]
	for other: int in range(index + 1):
		var other_base: int = other * CLAIM_STRIDE
		if claims[other_base + CLAIM_LOT_SLOT] != lot_slot:
			continue
		if claims[other_base + CLAIM_LOT_GENERATION] != lot_generation:
			continue
		if claims[other_base + CLAIM_PURPOSE] == purpose:
			return other
	return index


func _apply_inventory_claims(claims: PackedInt64Array, claim_count: int, inventory: Inventory) -> StringName:
	"""Raise `reserved_milli` on every claimed lot inside one inventory transaction.

	Runs BEFORE any pool row is written, so the one step that can still refuse does so while the
	pool is untouched and inventory's own journal can undo whatever it already applied.
	"""
	var opened: Inventory.OpResult = inventory.begin()
	if not opened.ok:
		return opened.error
	for index: int in range(claim_count):
		var base: int = index * CLAIM_STRIDE
		var lot_ref: Vector2i = Vector2i(claims[base + CLAIM_LOT_SLOT], claims[base + CLAIM_LOT_GENERATION])
		var reserved: Inventory.OpResult = inventory.reserve_lot(lot_ref, claims[base + CLAIM_QUANTITY_MILLI])
		if not reserved.ok:
			inventory.abort()
			return reserved.error
	var committed: Inventory.OpResult = inventory.commit()
	if not committed.ok:
		return committed.error
	return REFUSE_NONE


func _apply_pool_rows(job_ref: Vector2i, claims: PackedInt64Array, claim_count: int) -> void:
	"""Write the batch's rows. Cannot fail: the preflight proved every row is available."""
	for index: int in range(claim_count):
		var base: int = index * CLAIM_STRIDE
		var lot_ref: Vector2i = Vector2i(claims[base + CLAIM_LOT_SLOT], claims[base + CLAIM_LOT_GENERATION])
		_upsert_row(job_ref, lot_ref, claims[base + CLAIM_PURPOSE], claims[base + CLAIM_QUANTITY_MILLI], claims[base + CLAIM_EXPIRY])


func _upsert_row(job_ref: Vector2i, lot_ref: Vector2i, purpose: int, quantity_milli: int, expiry: int) -> int:
	"""Add a claim onto its existing row, or allocate a fresh one. Returns the row."""
	var row: int = _find_row(job_ref, lot_ref, purpose)
	if row != NULL_ROW:
		_r_quantity_milli[row] += quantity_milli
		if expiry > _r_expiry[row]:
			_r_expiry[row] = expiry
		return row
	row = _allocate_row()
	assert(row != NULL_ROW, "the preflight guarantees a free row here")
	_r_job_slot[row] = job_ref.x
	_r_job_generation[row] = job_ref.y
	_r_lot_slot[row] = lot_ref.x
	_r_lot_generation[row] = lot_ref.y
	_r_purpose[row] = purpose
	_r_quantity_milli[row] = quantity_milli
	_r_expiry[row] = expiry
	_link_job(row)
	_link_lot(row)
	return row


# --- Releasing --------------------------------------------------------------------------------

func release_claim(job_ref: Vector2i, lot_ref: Vector2i, purpose: int, inventory: Inventory) -> Inventory.OpResult:
	"""Release one `(job, lot, purpose)` claim in full. `.value` is the quantity released."""
	if inventory == null:
		return _refuse(REFUSE_NO_INVENTORY)
	if inventory.is_transaction_open():
		return _refuse(REFUSE_INVENTORY_TRANSACTION_OPEN)
	var row: int = _find_row(job_ref, lot_ref, purpose)
	if row == NULL_ROW:
		return _refuse(REFUSE_NO_SUCH_CLAIM)
	if not inventory.is_lot_valid(lot_ref):
		return _refuse(REFUSE_INVALID_LOT)
	var quantity: int = _r_quantity_milli[row]
	var released: Inventory.OpResult = inventory.release_reservation(lot_ref, quantity)
	if not released.ok:
		return _refuse(released.error)
	_free_row(row)
	return _ok(lot_ref, quantity)


func release_job_claims(job_ref: Vector2i, inventory: Inventory) -> Inventory.OpResult:
	"""Release every claim held by one Job, or refuse and release none.

	This is the worker-departure and job-cancellation path. Decision 0017 keeps shared claims on
	the coordinator Job, so calling this for a departing member releases that member's own rows
	and cannot touch the party's shared ingredients. `.value` is the number of rows released.
	"""
	return _release_list(job_ref, true, inventory)


func release_lot_claims(lot_ref: Vector2i, inventory: Inventory) -> Inventory.OpResult:
	"""Release every claim standing against one lot, or refuse and release none.

	GDD §5.8's spoilage path: the rows go in the lot list's canonical order, which is ascending
	`(job_slot, job_generation, purpose)` and therefore independent of the order they were
	claimed in. `.value` is the number of rows released.
	"""
	return _release_list(lot_ref, false, inventory)


func _release_list(owner_ref: Vector2i, by_job: bool, inventory: Inventory) -> Inventory.OpResult:
	"""Release a whole job list or lot list all-or-nothing. `by_job` selects which list."""
	if inventory == null:
		return _refuse(REFUSE_NO_INVENTORY)
	if inventory.is_transaction_open():
		return _refuse(REFUSE_INVENTORY_TRANSACTION_OPEN)
	var head: int = _list_head(owner_ref, by_job)
	if head == NULL_ROW:
		return _ok(owner_ref, 0)
	var refusal: StringName = _check_list_releasable(head, by_job, inventory)
	if refusal != REFUSE_NONE:
		return _refuse(refusal)
	var opened: Inventory.OpResult = inventory.begin()
	if not opened.ok:
		return _refuse(opened.error)
	refusal = _release_inventory_along(head, by_job, inventory)
	if refusal != REFUSE_NONE:
		inventory.abort()
		return _refuse(refusal)
	var committed: Inventory.OpResult = inventory.commit()
	if not committed.ok:
		return _refuse(committed.error)
	return _ok(owner_ref, _free_list_rows(head, by_job))


func _list_head(owner_ref: Vector2i, by_job: bool) -> int:
	"""Head row of `owner_ref`'s list, or NULL_ROW when the owner is out of range or empty."""
	if by_job:
		if owner_ref.x < 0 or owner_ref.x >= _job_capacity:
			return NULL_ROW
		var job_head: int = _job_head[owner_ref.x]
		return job_head if job_head != NULL_ROW and _r_job_generation[job_head] == owner_ref.y else NULL_ROW
	if owner_ref.x < 0 or owner_ref.x >= _lot_capacity:
		return NULL_ROW
	var lot_head: int = _lot_head[owner_ref.x]
	return lot_head if lot_head != NULL_ROW and _r_lot_generation[lot_head] == owner_ref.y else NULL_ROW


func _check_list_releasable(head: int, by_job: bool, inventory: Inventory) -> StringName:
	"""Prove every row in the list can be released before any of them is."""
	var row: int = head
	while row != NULL_ROW:
		var lot_ref: Vector2i = Vector2i(_r_lot_slot[row], _r_lot_generation[row])
		if not inventory.is_lot_valid(lot_ref):
			return REFUSE_INVALID_LOT
		if inventory.lot_reserved_milli(lot_ref) < _r_quantity_milli[row]:
			return REFUSE_AUDIT_RESERVED_TOTAL
		row = _job_next[row] if by_job else _lot_next[row]
	return REFUSE_NONE


func _release_inventory_along(head: int, by_job: bool, inventory: Inventory) -> StringName:
	"""Lower `reserved_milli` for every row of a list inside an open inventory transaction.

	Runs while the pool is still untouched, so a refusal here -- a full journal, say -- is undone
	by `abort()` and leaves the rows exactly where they were. The rows are freed only after the
	inventory side has committed.
	"""
	var row: int = head
	while row != NULL_ROW:
		var lot_ref: Vector2i = Vector2i(_r_lot_slot[row], _r_lot_generation[row])
		var released: Inventory.OpResult = inventory.release_reservation(lot_ref, _r_quantity_milli[row])
		if not released.ok:
			return released.error
		row = _job_next[row] if by_job else _lot_next[row]
	return REFUSE_NONE


func _free_list_rows(head: int, by_job: bool) -> int:
	"""Free every row of a list whose inventory side has already committed. Returns the count."""
	var freed: int = 0
	var row: int = head
	while row != NULL_ROW:
		var next: int = _job_next[row] if by_job else _lot_next[row]
		_free_row(row)
		freed += 1
		row = next
	return freed


func drop_retired_lot_claims(lot_ref: Vector2i, inventory: Inventory) -> Inventory.OpResult:
	"""Discard the pool rows of a lot that no longer exists. `.value` is the rows dropped.

	A lot consumed to zero retires inside `inventory.gd`, taking its `reserved_milli` with it,
	which leaves the pool holding rows for a reference that can never be released again. This is
	the only way to drop them, and it refuses while the lot is still live so it cannot be used
	to quietly desynchronise a live lot's reserved total.
	"""
	if inventory == null:
		return _refuse(REFUSE_NO_INVENTORY)
	if lot_ref.x < 0 or lot_ref.x >= _lot_capacity:
		return _refuse(REFUSE_LOT_OUT_OF_RANGE)
	if inventory.is_lot_valid(lot_ref):
		return _refuse(REFUSE_LOT_STILL_LIVE)
	var dropped: int = 0
	var row: int = _lot_head[lot_ref.x]
	while row != NULL_ROW:
		var next: int = _lot_next[row]
		if _r_lot_generation[row] == lot_ref.y:
			_free_row(row)
			dropped += 1
		row = next
	return _ok(lot_ref, dropped)


func release_expired_for_job(job_ref: Vector2i, now_tick: int, inventory: Inventory) -> Inventory.OpResult:
	"""Release this Job's claims whose lease has run out, reading `now_tick >= expiry` as expired.

	BAL-SAFE-004's cross-job sweep releases rows "in job-ID order", which needs the Job store's
	persistent-ID mapping and therefore belongs to `jobs.gd`; this is the per-job entry point it
	calls. Within the job the rows go in the job list's canonical order. `.value` is the number
	of rows released; a job with nothing expired releases none and is not a refusal.
	"""
	if inventory == null:
		return _refuse(REFUSE_NO_INVENTORY)
	if inventory.is_transaction_open():
		return _refuse(REFUSE_INVENTORY_TRANSACTION_OPEN)
	var head: int = _list_head(job_ref, true)
	if head == NULL_ROW:
		return _ok(job_ref, 0)
	var refusal: StringName = _check_list_releasable(head, true, inventory)
	if refusal != REFUSE_NONE:
		return _refuse(refusal)
	return _release_expired_checked(job_ref, head, now_tick, inventory)


func _release_expired_checked(job_ref: Vector2i, head: int, now_tick: int, inventory: Inventory) -> Inventory.OpResult:
	"""Release the already-checked expired rows of one job list inside one transaction."""
	var opened: Inventory.OpResult = inventory.begin()
	if not opened.ok:
		return _refuse(opened.error)
	var refusal: StringName = _release_expired_inventory(head, now_tick, inventory)
	if refusal != REFUSE_NONE:
		inventory.abort()
		return _refuse(refusal)
	var committed: Inventory.OpResult = inventory.commit()
	if not committed.ok:
		return _refuse(committed.error)
	return _ok(job_ref, _free_expired_rows(head, now_tick))


func _release_expired_inventory(head: int, now_tick: int, inventory: Inventory) -> StringName:
	"""Lower `reserved_milli` for every expired row of a job list, pool still untouched."""
	var row: int = head
	while row != NULL_ROW:
		if now_tick >= _r_expiry[row]:
			var lot_ref: Vector2i = Vector2i(_r_lot_slot[row], _r_lot_generation[row])
			var released: Inventory.OpResult = inventory.release_reservation(lot_ref, _r_quantity_milli[row])
			if not released.ok:
				return released.error
		row = _job_next[row]
	return REFUSE_NONE


func _free_expired_rows(head: int, now_tick: int) -> int:
	"""Free the expired rows of a job list once the inventory side has committed."""
	var freed: int = 0
	var row: int = head
	while row != NULL_ROW:
		var next: int = _job_next[row]
		if now_tick >= _r_expiry[row]:
			_free_row(row)
			freed += 1
		row = next
	return freed


func renew_claim(job_ref: Vector2i, lot_ref: Vector2i, purpose: int, new_expiry: int) -> Inventory.OpResult:
	"""Extend one claim's lease to `new_expiry`. `.value` is the stored expiry after the call.

	BAL-SAFE-004 renewal only ever pushes a lease further out, so an expiry that is not strictly
	later is refused explicitly rather than silently ignored -- a caller that shortened a lease
	by accident would otherwise lose reserved ingredients on the next sweep with no signal.
	"""
	if new_expiry < 0:
		return _refuse(REFUSE_INVALID_EXPIRY)
	var row: int = _find_row(job_ref, lot_ref, purpose)
	if row == NULL_ROW:
		return _refuse(REFUSE_NO_SUCH_CLAIM)
	if new_expiry <= _r_expiry[row]:
		return _refuse(REFUSE_EXPIRY_NOT_LATER)
	_r_expiry[row] = new_expiry
	return _ok(lot_ref, new_expiry)


# --- Row allocation ---------------------------------------------------------------------------

func _allocate_row() -> int:
	"""Take the LOWEST free row index (decision 0019), or NULL_ROW when the pool is full."""
	if _free_count <= 0:
		return NULL_ROW
	var row: int = _pop_min()
	_free_count -= 1
	_occupied[row] = 1
	_active_count += 1
	return row


func _free_row(row: int) -> void:
	"""Unlink a row from both lists, blank it, and return it to the free heap."""
	_unlink_job(row)
	_unlink_lot(row)
	_r_job_slot[row] = NULL_SLOT
	_r_job_generation[row] = NULL_GENERATION
	_r_lot_slot[row] = NULL_SLOT
	_r_lot_generation[row] = NULL_GENERATION
	_r_purpose[row] = 0
	_r_quantity_milli[row] = 0
	_r_expiry[row] = 0
	_occupied[row] = 0
	_active_count -= 1
	_push_free(row)
	_free_count += 1


func _pop_min() -> int:
	"""Remove and return the smallest entry of the free-row min-heap.

	Sift-down copied in shape from `entity_directory.gd`'s ARCH-ID-002 heap, which is left
	byte-untouched; this pool owns a single window so it needs no base offset.
	"""
	var smallest: int = _free_heap[0]
	var last: int = _free_count - 1
	if last == 0:
		return smallest
	_free_heap[0] = _free_heap[last]
	var index: int = 0
	while index * 2 + 1 < last:
		var child: int = index * 2 + 1
		if child + 1 < last and _free_heap[child + 1] < _free_heap[child]:
			child += 1
		if _free_heap[index] <= _free_heap[child]:
			break
		var carried: int = _free_heap[index]
		_free_heap[index] = _free_heap[child]
		_free_heap[child] = carried
		index = child
	return smallest


func _push_free(row: int) -> void:
	"""Insert a freed row into the min-heap so the next allocation still finds the lowest index."""
	var index: int = _free_count
	while index > 0:
		var parent: int = (index - 1) / 2
		if _free_heap[parent] <= row:
			break
		_free_heap[index] = _free_heap[parent]
		index = parent
	_free_heap[index] = row


# --- Intrusive lists --------------------------------------------------------------------------

func _compare_lot_key(row: int, lot_slot: int, lot_generation: int, purpose: int) -> int:
	"""Order a row against a `(lot, purpose)` key: -1 before, 0 equal, 1 after."""
	if _r_lot_slot[row] != lot_slot:
		return -1 if _r_lot_slot[row] < lot_slot else 1
	if _r_lot_generation[row] != lot_generation:
		return -1 if _r_lot_generation[row] < lot_generation else 1
	if _r_purpose[row] != purpose:
		return -1 if _r_purpose[row] < purpose else 1
	return 0


func _compare_job_key(row: int, job_slot: int, job_generation: int, purpose: int) -> int:
	"""Order a row against a `(job, purpose)` key: -1 before, 0 equal, 1 after."""
	if _r_job_slot[row] != job_slot:
		return -1 if _r_job_slot[row] < job_slot else 1
	if _r_job_generation[row] != job_generation:
		return -1 if _r_job_generation[row] < job_generation else 1
	if _r_purpose[row] != purpose:
		return -1 if _r_purpose[row] < purpose else 1
	return 0


func _link_job(row: int) -> void:
	"""Insert a row into its Job's list, keeping the canonical `(lot, purpose)` order."""
	var head_index: int = _r_job_slot[row]
	var cursor: int = _job_head[head_index]
	var previous: int = NULL_ROW
	while cursor != NULL_ROW and _compare_lot_key(cursor, _r_lot_slot[row], _r_lot_generation[row], _r_purpose[row]) < 0:
		previous = cursor
		cursor = _job_next[cursor]
	_job_next[row] = cursor
	_job_prev[row] = previous
	if cursor != NULL_ROW:
		_job_prev[cursor] = row
	if previous == NULL_ROW:
		_job_head[head_index] = row
	else:
		_job_next[previous] = row


func _link_lot(row: int) -> void:
	"""Insert a row into its lot's list, keeping the canonical `(job, purpose)` order."""
	var head_index: int = _r_lot_slot[row]
	var cursor: int = _lot_head[head_index]
	var previous: int = NULL_ROW
	while cursor != NULL_ROW and _compare_job_key(cursor, _r_job_slot[row], _r_job_generation[row], _r_purpose[row]) < 0:
		previous = cursor
		cursor = _lot_next[cursor]
	_lot_next[row] = cursor
	_lot_prev[row] = previous
	if cursor != NULL_ROW:
		_lot_prev[cursor] = row
	if previous == NULL_ROW:
		_lot_head[head_index] = row
	else:
		_lot_next[previous] = row


func _unlink_job(row: int) -> void:
	"""Remove a row from its Job's list."""
	var previous: int = _job_prev[row]
	var next: int = _job_next[row]
	if previous == NULL_ROW:
		_job_head[_r_job_slot[row]] = next
	else:
		_job_next[previous] = next
	if next != NULL_ROW:
		_job_prev[next] = previous
	_job_prev[row] = NULL_ROW
	_job_next[row] = NULL_ROW


func _unlink_lot(row: int) -> void:
	"""Remove a row from its lot's list."""
	var previous: int = _lot_prev[row]
	var next: int = _lot_next[row]
	if previous == NULL_ROW:
		_lot_head[_r_lot_slot[row]] = next
	else:
		_lot_next[previous] = next
	if next != NULL_ROW:
		_lot_prev[next] = previous
	_lot_prev[row] = NULL_ROW
	_lot_next[row] = NULL_ROW


func _find_row(job_ref: Vector2i, lot_ref: Vector2i, purpose: int) -> int:
	"""The active row carrying `(job, lot, purpose)`, or NULL_ROW when there is none.

	Walks the Job's list, which is short -- one entry per lot the job has claimed -- and is
	sorted, so the scan stops as soon as it passes the key.
	"""
	if job_ref.x < 0 or job_ref.x >= _job_capacity:
		return NULL_ROW
	var row: int = _job_head[job_ref.x]
	while row != NULL_ROW:
		var order: int = _compare_lot_key(row, lot_ref.x, lot_ref.y, purpose)
		if order > 0:
			return NULL_ROW
		if order == 0 and _r_job_generation[row] == job_ref.y:
			return row
		row = _job_next[row]
	return NULL_ROW


# --- Queries ----------------------------------------------------------------------------------

func has_claim(job_ref: Vector2i, lot_ref: Vector2i, purpose: int) -> bool:
	"""True when an active row carries this `(job, lot, purpose)` triple."""
	return _find_row(job_ref, lot_ref, purpose) != NULL_ROW


func claim_quantity_milli(job_ref: Vector2i, lot_ref: Vector2i, purpose: int) -> int:
	"""Quantity claimed by one `(job, lot, purpose)` triple, in milli-units.

	Returns 0 when no such claim exists. That is a total, not a failure sentinel: a claim of 0 is
	refused at entry, so 0 can only ever mean "nothing claimed". Use `has_claim()` when the
	distinction has to be explicit.
	"""
	var row: int = _find_row(job_ref, lot_ref, purpose)
	return _r_quantity_milli[row] if row != NULL_ROW else 0


func claim_expiry_into(job_ref: Vector2i, lot_ref: Vector2i, purpose: int, out: IntMath.IntResult) -> bool:
	"""Write one claim's expiry tick into `out`, returning false when there is no such claim.

	Written in the `_into` form because expiry 0 is a legal stored value, so no returned integer
	could distinguish "expires at tick 0" from "no claim" without becoming a sentinel.
	"""
	var row: int = _find_row(job_ref, lot_ref, purpose)
	if row == NULL_ROW:
		return out.refuse("no reservation for this job, lot and purpose")
	return out.succeed(_r_expiry[row])


func job_claim_count(job_ref: Vector2i) -> int:
	"""Number of active rows held by one Job."""
	return _count_list(_list_head(job_ref, true), true)


func lot_claim_count(lot_ref: Vector2i) -> int:
	"""Number of active rows standing against one lot."""
	return _count_list(_list_head(lot_ref, false), false)


func _count_list(head: int, by_job: bool) -> int:
	"""Length of one intrusive list."""
	var count: int = 0
	var row: int = head
	while row != NULL_ROW:
		count += 1
		row = _job_next[row] if by_job else _lot_next[row]
	return count


func job_reserved_total_milli(job_ref: Vector2i) -> int:
	"""Total milli-units claimed by one Job across every lot."""
	return _sum_list(_list_head(job_ref, true), true)


func lot_reserved_total_milli(lot_ref: Vector2i) -> int:
	"""Total milli-units claimed against one lot, re-derived from the rows themselves.

	This is the right-hand side of decision 0019's invariant. `audit()` compares it with the
	`reserved_milli` that `inventory.gd` maintains independently.
	"""
	return _sum_list(_list_head(lot_ref, false), false)


func _sum_list(head: int, by_job: bool) -> int:
	"""Sum of the claimed quantities along one intrusive list."""
	var total: int = 0
	var row: int = head
	while row != NULL_ROW:
		total += _r_quantity_milli[row]
		row = _job_next[row] if by_job else _lot_next[row]
	return total


# --- Row iteration ----------------------------------------------------------------------------

func first_job_row(job_ref: Vector2i) -> int:
	"""First row of a Job's list in canonical order, or NULL_ROW when it holds no claim."""
	return _list_head(job_ref, true)


func next_job_row(row: int) -> int:
	"""Row after `row` in its Job's list, or NULL_ROW at the end."""
	return _job_next[row] if _is_row(row) else NULL_ROW


func first_lot_row(lot_ref: Vector2i) -> int:
	"""First row of a lot's list in canonical order, or NULL_ROW when it carries no claim."""
	return _list_head(lot_ref, false)


func next_lot_row(row: int) -> int:
	"""Row after `row` in its lot's list, or NULL_ROW at the end."""
	return _lot_next[row] if _is_row(row) else NULL_ROW


func _is_row(row: int) -> bool:
	"""True when `row` is an in-range, currently active row index."""
	return row >= 0 and row < _row_capacity and _occupied[row] == 1


func is_row_active(row: int) -> bool:
	"""True when the row index currently holds a claim."""
	return _is_row(row)


func row_job_ref(row: int) -> Vector2i:
	"""EntityRef of the Job owning a row, or NULL_REF when the row is not active."""
	return Vector2i(_r_job_slot[row], _r_job_generation[row]) if _is_row(row) else NULL_REF


func row_lot_ref(row: int) -> Vector2i:
	"""EntityRef of the lot a row claims, or NULL_REF when the row is not active."""
	return Vector2i(_r_lot_slot[row], _r_lot_generation[row]) if _is_row(row) else NULL_REF


func row_purpose_into(row: int, out: IntMath.IntResult) -> bool:
	"""Write a row's opaque purpose into `out`, returning false when the row is not active."""
	if not _is_row(row):
		return out.refuse("row is not active")
	return out.succeed(_r_purpose[row])


func row_quantity_milli(row: int) -> int:
	"""Milli-units claimed by a row. 0 for an inactive row, which holds no claim."""
	return _r_quantity_milli[row] if _is_row(row) else 0


func row_expiry_into(row: int, out: IntMath.IntResult) -> bool:
	"""Write a row's expiry tick into `out`, returning false when the row is not active."""
	if not _is_row(row):
		return out.refuse("row is not active")
	return out.succeed(_r_expiry[row])


# --- Audit ------------------------------------------------------------------------------------

func audit(inventory: Inventory) -> Inventory.OpResult:
	"""Re-derive every structural and quantitative invariant this pool claims to hold.

	Diagnostic, not a tick call. Checks occupancy against the free heap, both lists for
	membership and canonical order, and -- for every lot the pool knows about -- decision 0019's
	`lot.reserved_milli == sum(rows) <= lot.quantity_milli`. Lots reserved by a caller going
	round this pool straight to `inventory.reserve_lot()` are outside its authority and are not
	visible here; `inventory.audit()` still bounds those by quantity.
	"""
	if inventory == null:
		return _refuse(REFUSE_NO_INVENTORY)
	var refusal: StringName = _audit_occupancy()
	if refusal != REFUSE_NONE:
		return _refuse(refusal)
	refusal = _audit_lists()
	if refusal != REFUSE_NONE:
		return _refuse(refusal)
	refusal = _audit_lot_totals(inventory)
	if refusal != REFUSE_NONE:
		return _refuse(refusal)
	return _ok(NULL_REF, _active_count)


func _audit_occupancy() -> StringName:
	"""Occupancy, active count and free heap must all describe the same set of rows."""
	var occupied: int = 0
	for row: int in range(_row_capacity):
		if _occupied[row] == 1:
			occupied += 1
	if occupied != _active_count or occupied + _free_count != _row_capacity:
		return REFUSE_AUDIT_OCCUPANCY
	for index: int in range(_free_count):
		var row: int = _free_heap[index]
		if row < 0 or row >= _row_capacity or _occupied[row] == 1:
			return REFUSE_AUDIT_HEAP
	return REFUSE_NONE


func _audit_lists() -> StringName:
	"""Every active row must appear exactly once in its Job list and once in its lot list."""
	var seen_in_jobs: int = 0
	for slot: int in range(_job_capacity):
		var counted: int = _audit_one_list(_job_head[slot], true, slot)
		if counted < 0:
			return REFUSE_AUDIT_JOB_LIST
		seen_in_jobs += counted
	var seen_in_lots: int = 0
	for slot: int in range(_lot_capacity):
		var counted: int = _audit_one_list(_lot_head[slot], false, slot)
		if counted < 0:
			return REFUSE_AUDIT_LOT_LIST
		seen_in_lots += counted
	if seen_in_jobs != _active_count:
		return REFUSE_AUDIT_JOB_LIST
	if seen_in_lots != _active_count:
		return REFUSE_AUDIT_LOT_LIST
	return REFUSE_NONE


func _audit_one_list(head: int, by_job: bool, expected_slot: int) -> int:
	"""Length of one list, or -1 when it is broken, mis-owned, or out of canonical order."""
	var count: int = 0
	var row: int = head
	var previous: int = NULL_ROW
	while row != NULL_ROW:
		if not _is_row(row) or count > _row_capacity:
			return -1
		var owner_slot: int = _r_job_slot[row] if by_job else _r_lot_slot[row]
		if owner_slot != expected_slot:
			return -1
		if (_job_prev[row] if by_job else _lot_prev[row]) != previous:
			return -1
		if previous != NULL_ROW and _audit_order(previous, row, by_job) >= 0:
			return -1
		count += 1
		previous = row
		row = _job_next[row] if by_job else _lot_next[row]
	return count


func _audit_order(previous: int, row: int, by_job: bool) -> int:
	"""Order of `previous` against `row` under the list's canonical key. Must be strictly -1."""
	if by_job:
		return _compare_lot_key(previous, _r_lot_slot[row], _r_lot_generation[row], _r_purpose[row])
	return _compare_job_key(previous, _r_job_slot[row], _r_job_generation[row], _r_purpose[row])


func _audit_lot_totals(inventory: Inventory) -> StringName:
	"""Decision 0019's invariant, per lot the pool holds rows for."""
	for slot: int in range(_lot_capacity):
		var head: int = _lot_head[slot]
		if head == NULL_ROW:
			continue
		var lot_ref: Vector2i = Vector2i(slot, _r_lot_generation[head])
		if not inventory.is_lot_valid(lot_ref):
			return REFUSE_AUDIT_RESERVED_TOTAL
		var total: int = _sum_list(head, false)
		if total != inventory.lot_reserved_milli(lot_ref):
			return REFUSE_AUDIT_RESERVED_TOTAL
		if total > inventory.lot_quantity_milli(lot_ref):
			return REFUSE_AUDIT_RESERVED_EXCEEDS
	return REFUSE_NONE


# --- Serialization ----------------------------------------------------------------------------

func state_bytes() -> PackedByteArray:
	"""Canonical image of every active claim, comparable across two logically identical worlds.

	NOT A PRODUCTION CALL: it allocates. Deliberately EXCLUDES row indices, the free heap and the
	link columns, because those depend on allocation history -- two worlds that made the same
	claims in a different order, or reused different rows, hold the same claims and must produce
	the same image. Rows are emitted lot-major in ascending lot slot, then in each lot list's
	canonical `(job_slot, job_generation, purpose)` order, so the image is a pure function of the
	set of claims.

	The save format itself does not exist yet: nothing in the architecture defines the save
	header, chunk layout or version field for this store. This is the deterministic serialization
	half of that work; reading an image back is DEFERRED until the save format is specified.
	"""
	var image: PackedInt64Array = PackedInt64Array()
	image.resize(1 + _active_count * 7)
	image[0] = _active_count
	var cursor: int = 1
	for slot: int in range(_lot_capacity):
		var row: int = _lot_head[slot]
		while row != NULL_ROW:
			cursor = _append_row_image(image, cursor, row)
			row = _lot_next[row]
	return var_to_bytes(image)


func _append_row_image(image: PackedInt64Array, cursor: int, row: int) -> int:
	"""Write one row's seven canonical fields at `cursor`. Returns the next cursor."""
	image[cursor] = _r_lot_slot[row]
	image[cursor + 1] = _r_lot_generation[row]
	image[cursor + 2] = _r_job_slot[row]
	image[cursor + 3] = _r_job_generation[row]
	image[cursor + 4] = _r_purpose[row]
	image[cursor + 5] = _r_quantity_milli[row]
	image[cursor + 6] = _r_expiry[row]
	return cursor + 7


# --- Results ----------------------------------------------------------------------------------

func _ok(ref: Vector2i, value: int) -> Inventory.OpResult:
	"""Build a successful result, sharing `inventory.gd`'s result shape rather than cloning it."""
	return Inventory.OpResult.new(true, REFUSE_NONE, ref, value)


func _refuse(code: StringName) -> Inventory.OpResult:
	"""Build an explicit refusal carrying no partially applied effect and no usable ref."""
	return Inventory.OpResult.new(false, code, NULL_REF, 0)


# =================================================================================================
# SAVE-RES-R01 v2 -- Reservations owner column boundary.
#
# APPEND FRAGMENT. These lines are appended verbatim to the END of
# `godot/scripts/core/reservations.gd`. The fragment declares NO `extends`, NO `preload` and NO
# member that file already defines: it only adds new constants, two nested records, one new field
# and the four public column methods. `_math`, `_pending_new_rows`, every existing mutator and
# every existing diagnostic are left exactly as they are, on success and on refusal alike.
#
# WHAT THIS BOUNDARY IS. Eight canonical arrays plus three native extents cross the boundary, and
# nothing else. Row indices are IDENTITIES (REG-R01: reservations "cannot be compacted"), so no
# row is renumbered, compacted or reordered here. The min-heap and the four intrusive links are
# DERIVED: they are rebuilt from the free set and the semantic keys, and a capture REFUSES a
# malformed live index rather than repairing it as a side effect.
#
# WHAT IT IS NOT. No Inventory is touched, no save module is preloaded (the adapter preloads this
# owner, never the reverse), no row generation exists, no clock is read, no lease is expired or
# swept, and `clear()`, `claim_batch()`, `release_*`, `renew_claim()`, `audit()` and
# `inventory.reserve_lot()` are never called from any of it. `audit()` in particular is a
# traversal of indexes it already assumes well formed, so it is never pointed at hostile shapes.
#
# COLD PATH. Every buffer allocated here is a local that leaves scope: two length-R merge buffers
# live at a time, one derived staging record, and one R-byte heap membership buffer. There is no
# owner-persistent scratch, no Dictionary, no recursion, no reflection and no float.
# =================================================================================================

## The complete refusal vocabulary of this boundary. SHAPE is a CALLER error; SOURCE_DERIVED is a
## corrupt LIVE shape, count or index; every other code names a specific canonical payload fault.
const COLUMN_RESERVATION_SHAPE: StringName = &"COLUMN_RESERVATION_SHAPE"
const COLUMN_RESERVATION_OCCUPANCY: StringName = &"COLUMN_RESERVATION_OCCUPANCY"
const COLUMN_RESERVATION_BLANK: StringName = &"COLUMN_RESERVATION_BLANK"
const COLUMN_RESERVATION_REF: StringName = &"COLUMN_RESERVATION_REF"
const COLUMN_RESERVATION_QUANTITY: StringName = &"COLUMN_RESERVATION_QUANTITY"
const COLUMN_RESERVATION_EXPIRY: StringName = &"COLUMN_RESERVATION_EXPIRY"
const COLUMN_RESERVATION_JOB_GENERATION: StringName = &"COLUMN_RESERVATION_JOB_GENERATION"
const COLUMN_RESERVATION_LOT_GENERATION: StringName = &"COLUMN_RESERVATION_LOT_GENERATION"
const COLUMN_RESERVATION_DUPLICATE: StringName = &"COLUMN_RESERVATION_DUPLICATE"
const COLUMN_RESERVATION_OVERFLOW: StringName = &"COLUMN_RESERVATION_OVERFLOW"
const COLUMN_RESERVATION_SOURCE_DERIVED: StringName = &"COLUMN_RESERVATION_SOURCE_DERIVED"

## The i64 ceiling, used by the per-lot sum as a SUBTRACTION bound so no addition can overflow
## before it is checked. Deliberately local: `_math` is existing scratch and stays untouched here.
const RESERVATION_MAX_I64: int = 9223372036854775807

## Category 3 diagnostic. The ONLY field this boundary writes on a refusal, and the only new
## owner field at all. Success clears it; `canonical_detail()` is exactly this code as text.
var _last_column_refusal: StringName = REFUSE_NONE


class ReservationColumns:
	"""The caller-owned record: three native extents and the eight canonical packed arrays.

	Every array holds `row_capacity` entries and starts at the values `clear()` produces -- slot
	columns at NULL_SLOT, everything else at zero -- so a freshly constructed record and a freshly
	cleared pool describe the same empty world.

	REQUESTED METADATA IS PRESERVED, NOT CLAMPED. A caller asking for 99999 rows keeps 99999 in
	`row_capacity` and is then REFUSED by the shape check, while only
	`clampi(requested, 1, ROW_CAPACITY)` cells are ever allocated -- so a hostile request cannot
	allocate unbounded storage AND cannot quietly pass as a smaller valid world.

	This record owns no Inventory, no index array, no owner object and no persistent work buffer.
	"""
	var row_capacity: int = ROW_CAPACITY
	var job_capacity: int = JOB_CAPACITY
	var lot_capacity: int = LOT_CAPACITY
	var occupied: PackedByteArray = PackedByteArray()
	var r_job_slot: PackedInt32Array = PackedInt32Array()
	var r_job_generation: PackedInt32Array = PackedInt32Array()
	var r_lot_slot: PackedInt32Array = PackedInt32Array()
	var r_lot_generation: PackedInt32Array = PackedInt32Array()
	var r_purpose: PackedInt32Array = PackedInt32Array()
	var r_quantity_milli: PackedInt64Array = PackedInt64Array()
	var r_expiry: PackedInt64Array = PackedInt64Array()

	func _init(p_row_capacity: int = ROW_CAPACITY, p_job_capacity: int = JOB_CAPACITY,
			p_lot_capacity: int = LOT_CAPACITY) -> void:
		"""Record the requested extents verbatim and allocate a bounded, canonically blank body."""
		row_capacity = p_row_capacity
		job_capacity = p_job_capacity
		lot_capacity = p_lot_capacity
		var rows: int = clampi(p_row_capacity, 1, ROW_CAPACITY)
		occupied.resize(rows)
		occupied.fill(0)
		r_job_slot.resize(rows)
		r_job_slot.fill(NULL_SLOT)
		r_job_generation.resize(rows)
		r_job_generation.fill(NULL_GENERATION)
		r_lot_slot.resize(rows)
		r_lot_slot.fill(NULL_SLOT)
		r_lot_generation.resize(rows)
		r_lot_generation.fill(NULL_GENERATION)
		r_purpose.resize(rows)
		r_purpose.fill(0)
		r_quantity_milli.resize(rows)
		r_quantity_milli.fill(0)
		r_expiry.resize(rows)
		r_expiry.fill(0)


class ReservationDerived:
	"""PRIVATE staging for the rebuilt indexes. Never published to a caller's record.

	Holds the free min-heap, both head columns, the four link columns, the two counts and one
	local refusal. Every array starts at NULL_ROW, so an inactive row's links and an unused heap
	cell are -1 by construction. That -1 heap TAIL is construction residue, not state: later
	allocations may leave stale values there, and it is never captured, compared or hashed.
	"""
	var _free_heap: PackedInt32Array = PackedInt32Array()
	var _job_head: PackedInt32Array = PackedInt32Array()
	var _lot_head: PackedInt32Array = PackedInt32Array()
	var _job_prev: PackedInt32Array = PackedInt32Array()
	var _job_next: PackedInt32Array = PackedInt32Array()
	var _lot_prev: PackedInt32Array = PackedInt32Array()
	var _lot_next: PackedInt32Array = PackedInt32Array()
	var active_count: int = 0
	var free_count: int = 0
	var refusal: StringName = REFUSE_NONE

	func _init(p_rows: int, p_jobs: int, p_lots: int) -> void:
		"""Allocate every derived column at the extents already proved to be in compiled range."""
		_free_heap.resize(p_rows)
		_free_heap.fill(NULL_ROW)
		_job_prev.resize(p_rows)
		_job_prev.fill(NULL_ROW)
		_job_next.resize(p_rows)
		_job_next.fill(NULL_ROW)
		_lot_prev.resize(p_rows)
		_lot_prev.fill(NULL_ROW)
		_lot_next.resize(p_rows)
		_lot_next.fill(NULL_ROW)
		_job_head.resize(p_jobs)
		_job_head.fill(NULL_ROW)
		_lot_head.resize(p_lots)
		_lot_head.fill(NULL_ROW)


# --- public column API ---------------------------------------------------------------------------

func last_column_refusal() -> StringName:
	"""The code of the most recent column refusal, or REFUSE_NONE after a success."""
	return _last_column_refusal


func canonical_detail() -> String:
	"""The last column refusal as text. Deliberately the code itself: no row detail is promised."""
	return String(_last_column_refusal)


func copy_reservation_columns_into(out: ReservationColumns) -> bool:
	"""Export this pool's eight canonical arrays into `out`, or refuse leaving `out` untouched.

	ORDER, fixed: the caller's record shape (SHAPE); this owner's own extents, array shapes and
	native counts (SOURCE_DERIVED); the live canonical payload, which keeps its specific code;
	then the rebuilt indexes against the live ones, including the heap (SOURCE_DERIVED).

	A capture REFUSES a corrupt source. It does not repair one: silently rewriting a live index
	here would launder a bug into a save file that then looks healthy forever.

	On success every exported array is a SEPARATE duplicate, so a later mutation of this pool
	cannot reach the caller's record and any aliasing the caller had is replaced, not written
	through.
	"""
	if not _reservation_record_shape_ok(out):
		return _refuse_column(COLUMN_RESERVATION_SHAPE)
	if not _reservation_live_shape_ok():
		return _refuse_column(COLUMN_RESERVATION_SOURCE_DERIVED)
	if not _reservation_live_counts_ok():
		return _refuse_column(COLUMN_RESERVATION_SOURCE_DERIVED)
	var derived: ReservationDerived = _derive_reservation_indexes(_occupied, _r_job_slot,
		_r_job_generation, _r_lot_slot, _r_lot_generation, _r_purpose, _r_quantity_milli,
		_r_expiry, _row_capacity, _job_capacity, _lot_capacity)
	if derived.refusal != REFUSE_NONE:
		return _refuse_column(derived.refusal)
	if not _reservation_derived_matches(derived):
		return _refuse_column(COLUMN_RESERVATION_SOURCE_DERIVED)
	out.row_capacity = _row_capacity
	out.job_capacity = _job_capacity
	out.lot_capacity = _lot_capacity
	out.occupied = _occupied.duplicate()
	out.r_job_slot = _r_job_slot.duplicate()
	out.r_job_generation = _r_job_generation.duplicate()
	out.r_lot_slot = _r_lot_slot.duplicate()
	out.r_lot_generation = _r_lot_generation.duplicate()
	out.r_purpose = _r_purpose.duplicate()
	out.r_quantity_milli = _r_quantity_milli.duplicate()
	out.r_expiry = _r_expiry.duplicate()
	_last_column_refusal = REFUSE_NONE
	return true


func restore_reservation_columns(columns: ReservationColumns) -> bool:
	"""Replace this pool's canonical payload and rebuild every derived index, or change nothing.

	ORDER, fixed: the supplied record's shape (SHAPE); this object's own construction extents and
	array shapes, which remain required (SOURCE_DERIVED); the supplied payload, with its specific
	code; then -- and only then -- publication.

	THE OLD PAYLOAD IS NOT VALIDATED. Restore exists precisely to replace a malformed one, so
	nothing about the current rows, counts or indexes is required to be coherent. What IS required
	is that this object was constructed at the extents the record names and still holds columns of
	that shape.

	Publication installs eight INDEPENDENT duplicates of the caller's arrays, then transfers the
	private derived arrays directly -- safe because that staging never escaped this call -- and
	recomputes both counts. Exact occupied row indices are preserved; the free heap is rebuilt as
	an ascending prefix so the next allocation is the lowest free index and both chain orders are
	the canonical semantic ones, whatever layout the source heap happened to have.
	"""
	if not _reservation_record_shape_ok(columns):
		return _refuse_column(COLUMN_RESERVATION_SHAPE)
	if not _reservation_live_shape_ok():
		return _refuse_column(COLUMN_RESERVATION_SOURCE_DERIVED)
	var derived: ReservationDerived = _derive_reservation_indexes(columns.occupied,
		columns.r_job_slot, columns.r_job_generation, columns.r_lot_slot, columns.r_lot_generation,
		columns.r_purpose, columns.r_quantity_milli, columns.r_expiry, _row_capacity,
		_job_capacity, _lot_capacity)
	if derived.refusal != REFUSE_NONE:
		return _refuse_column(derived.refusal)
	_occupied = columns.occupied.duplicate()
	_r_job_slot = columns.r_job_slot.duplicate()
	_r_job_generation = columns.r_job_generation.duplicate()
	_r_lot_slot = columns.r_lot_slot.duplicate()
	_r_lot_generation = columns.r_lot_generation.duplicate()
	_r_purpose = columns.r_purpose.duplicate()
	_r_quantity_milli = columns.r_quantity_milli.duplicate()
	_r_expiry = columns.r_expiry.duplicate()
	_free_heap = derived._free_heap
	_job_head = derived._job_head
	_lot_head = derived._lot_head
	_job_prev = derived._job_prev
	_job_next = derived._job_next
	_lot_prev = derived._lot_prev
	_lot_next = derived._lot_next
	_active_count = derived.active_count
	_free_count = derived.free_count
	_last_column_refusal = REFUSE_NONE
	return true


func _refuse_column(code: StringName) -> bool:
	"""Record a column refusal and answer false. The ONLY owner field a failure writes."""
	_last_column_refusal = code
	return false


# --- shape gates -----------------------------------------------------------------------------------

func _reservation_record_shape_ok(record: ReservationColumns) -> bool:
	"""A caller record is usable only at THIS owner's three extents with all eight arrays at R.

	The metadata comparison is against the constructor extents, not against the compiled maxima,
	so a reduced-extent pool refuses a full-extent record and vice versa instead of reading a
	prefix of it.
	"""
	if record == null:
		return false
	if record.row_capacity != _row_capacity or record.job_capacity != _job_capacity \
			or record.lot_capacity != _lot_capacity:
		return false
	if record.occupied.size() != _row_capacity:
		return false
	if record.r_job_slot.size() != _row_capacity or record.r_job_generation.size() != _row_capacity:
		return false
	if record.r_lot_slot.size() != _row_capacity or record.r_lot_generation.size() != _row_capacity:
		return false
	if record.r_purpose.size() != _row_capacity:
		return false
	if record.r_quantity_milli.size() != _row_capacity or record.r_expiry.size() != _row_capacity:
		return false
	return true


func _reservation_live_shape_ok() -> bool:
	"""This owner's extents must stay in their compiled ranges and every column at its extent.

	Checked BEFORE anything indexes a column or allocates validation staging, so a forged extent
	cannot drive an out-of-bounds read or an unbounded allocation.
	"""
	if _row_capacity < 1 or _row_capacity > ROW_CAPACITY:
		return false
	if _job_capacity < 1 or _job_capacity > JOB_CAPACITY:
		return false
	if _lot_capacity < 1 or _lot_capacity > LOT_CAPACITY:
		return false
	if _occupied.size() != _row_capacity:
		return false
	if _r_job_slot.size() != _row_capacity or _r_job_generation.size() != _row_capacity:
		return false
	if _r_lot_slot.size() != _row_capacity or _r_lot_generation.size() != _row_capacity:
		return false
	if _r_purpose.size() != _row_capacity:
		return false
	if _r_quantity_milli.size() != _row_capacity or _r_expiry.size() != _row_capacity:
		return false
	if _free_heap.size() != _row_capacity:
		return false
	if _job_prev.size() != _row_capacity or _job_next.size() != _row_capacity:
		return false
	if _lot_prev.size() != _row_capacity or _lot_next.size() != _row_capacity:
		return false
	return _job_head.size() == _job_capacity and _lot_head.size() == _lot_capacity


func _reservation_live_counts_ok() -> bool:
	"""Both native counts must be in range and partition the pool. Capture only.

	Restore deliberately skips this: a corrupt count is exactly one of the things it replaces.
	"""
	if _active_count < 0 or _active_count > _row_capacity:
		return false
	if _free_count < 0 or _free_count > _row_capacity:
		return false
	return _active_count + _free_count == _row_capacity


# --- payload validation and private index construction -----------------------------------------------

func _derive_reservation_indexes(occupied: PackedByteArray, job_slot: PackedInt32Array,
		job_generation: PackedInt32Array, lot_slot: PackedInt32Array,
		lot_generation: PackedInt32Array, purpose: PackedInt32Array,
		quantity_milli: PackedInt64Array, expiry: PackedInt64Array, rows: int, jobs: int,
		lots: int) -> ReservationDerived:
	"""Validate a canonical payload in the fixed order and rebuild every derived index from it.

	All array shapes were proved by the callers, so every index below is in range by construction.
	The whole pass is O(R log R + J + L): two packed mergesorts and a constant number of linear
	scans, with no per-row Dictionary, no quadratic insertion, no recursion and no public replay.
	"""
	var derived: ReservationDerived = ReservationDerived.new(rows, jobs, lots)
	var active: int = 0
	for row: int in rows:
		if occupied[row] > 1:
			derived.refusal = COLUMN_RESERVATION_OCCUPANCY
			return derived
		active += occupied[row]
	for row: int in rows:
		if occupied[row] == 1:
			continue
		# Ordinals 1..7 of an inactive row, in declared order: a released row is blanked in full,
		# so any residue is corruption rather than history.
		if job_slot[row] != NULL_SLOT or job_generation[row] != NULL_GENERATION \
				or lot_slot[row] != NULL_SLOT or lot_generation[row] != NULL_GENERATION \
				or purpose[row] != 0 or quantity_milli[row] != 0 or expiry[row] != 0:
			derived.refusal = COLUMN_RESERVATION_BLANK
			return derived
	for row: int in rows:
		if occupied[row] != 1:
			continue
		# Any per-row slot or generation fault is REF. The GENERATION codes are reserved for the
		# later group scans, where a slot carries two different generations at once.
		if job_slot[row] < 0 or job_slot[row] >= jobs or job_generation[row] <= NULL_GENERATION \
				or lot_slot[row] < 0 or lot_slot[row] >= lots \
				or lot_generation[row] <= NULL_GENERATION:
			derived.refusal = COLUMN_RESERVATION_REF
			return derived
		# Zero quantity is an inactive blank, never an occupied empty claim.
		if quantity_milli[row] <= 0:
			derived.refusal = COLUMN_RESERVATION_QUANTITY
			return derived
		# Expired leases are RETAINED: there is no clock here and no sweep.
		if expiry[row] < 0:
			derived.refusal = COLUMN_RESERVATION_EXPIRY
			return derived
	derived.active_count = active
	derived.free_count = rows - active
	var free_index: int = 0
	for row: int in rows:
		if occupied[row] == 0:
			derived._free_heap[free_index] = row
			free_index += 1
	var job_order: PackedInt32Array = _reservation_sorted_rows(occupied, rows, active, job_slot,
		lot_slot, lot_generation, purpose)
	derived.refusal = _reservation_job_groups_refusal(job_order, active, job_slot, job_generation,
		lot_slot, lot_generation, purpose)
	if derived.refusal != REFUSE_NONE:
		return derived
	_reservation_link_rows(job_order, active, job_slot, derived._job_head, derived._job_prev,
		derived._job_next)
	# Release the returned job-order buffer before the second sort allocates its pair.
	job_order = PackedInt32Array()
	var lot_order: PackedInt32Array = _reservation_sorted_rows(occupied, rows, active, lot_slot,
		job_slot, job_generation, purpose)
	derived.refusal = _reservation_lot_groups_refusal(lot_order, active, lot_slot, lot_generation,
		quantity_milli)
	if derived.refusal != REFUSE_NONE:
		return derived
	_reservation_link_rows(lot_order, active, lot_slot, derived._lot_head, derived._lot_prev,
		derived._lot_next)
	return derived


func _reservation_job_groups_refusal(order: PackedInt32Array, count: int,
		job_slot: PackedInt32Array, job_generation: PackedInt32Array, lot_slot: PackedInt32Array,
		lot_generation: PackedInt32Array, purpose: PackedInt32Array) -> StringName:
	"""Job-slot groups: ONE generation per slot across the whole sequence, THEN duplicate keys.

	The generation scan runs to completion first, so a payload that is both mixed-generation and
	duplicated reports the generation fault -- the precedence the contract fixes. Once every group
	is single-generation, two adjacent entries sharing `(lot_slot, lot_generation, purpose)` inside
	a job group are the same full five-field key, which coalescing makes impossible.
	"""
	for offset: int in maxi(0, count - 1):
		var index: int = offset + 1
		var row: int = order[index]
		var previous: int = order[index - 1]
		if job_slot[row] == job_slot[previous] and job_generation[row] != job_generation[previous]:
			return COLUMN_RESERVATION_JOB_GENERATION
	for offset: int in maxi(0, count - 1):
		var index: int = offset + 1
		var row: int = order[index]
		var previous: int = order[index - 1]
		if job_slot[row] != job_slot[previous]:
			continue
		if lot_slot[row] == lot_slot[previous] and lot_generation[row] == lot_generation[previous] \
				and purpose[row] == purpose[previous]:
			return COLUMN_RESERVATION_DUPLICATE
	return REFUSE_NONE


func _reservation_lot_groups_refusal(order: PackedInt32Array, count: int,
		lot_slot: PackedInt32Array, lot_generation: PackedInt32Array,
		quantity_milli: PackedInt64Array) -> StringName:
	"""Lot-slot groups: ONE generation per slot, THEN a checked positive sum per lot.

	Every lot must have an i64 reserved total -- that is the invariant this module exists to hold
	-- so a per-lot sum that cannot fit is refused. The bound is a SUBTRACTION against the i64
	ceiling, evaluated before the addition, so nothing overflows on the way to detecting overflow;
	the owner's `_math` scratch is deliberately not used and stays untouched.

	A JOB's total across DIFFERENT lots is not summed here: the current claim APIs admit such a
	set, and narrowing save input to hide that is a separate runtime arithmetic obligation.
	"""
	for offset: int in maxi(0, count - 1):
		var index: int = offset + 1
		var row: int = order[index]
		var previous: int = order[index - 1]
		if lot_slot[row] == lot_slot[previous] and lot_generation[row] != lot_generation[previous]:
			return COLUMN_RESERVATION_LOT_GENERATION
	var total: int = 0
	for index: int in count:
		var row: int = order[index]
		if index == 0 or lot_slot[row] != lot_slot[order[index - 1]]:
			total = 0
		if quantity_milli[row] > RESERVATION_MAX_I64 - total:
			return COLUMN_RESERVATION_OVERFLOW
		total += quantity_milli[row]
	return REFUSE_NONE


func _reservation_link_rows(order: PackedInt32Array, count: int, owner_slot: PackedInt32Array,
		heads: PackedInt32Array, prev: PackedInt32Array, next: PackedInt32Array) -> void:
	"""Thread one sorted sequence into its intrusive lists by linking ADJACENT entries.

	The chain order is the SEMANTIC key order the sort produced, not the ascending row order: two
	worlds holding the same claims in different rows get the same chains.
	"""
	for index: int in count:
		var row: int = order[index]
		if index == 0 or owner_slot[row] != owner_slot[order[index - 1]]:
			heads[owner_slot[row]] = row
			prev[row] = NULL_ROW
		else:
			prev[row] = order[index - 1]
			next[order[index - 1]] = row
		next[row] = NULL_ROW


func _reservation_sorted_rows(occupied: PackedByteArray, rows: int, count: int,
		k0: PackedInt32Array, k1: PackedInt32Array, k2: PackedInt32Array,
		k3: PackedInt32Array) -> PackedInt32Array:
	"""Deterministic bottom-up mergesort of the occupied row indices under a four-field key.

	Two local length-R PackedInt32Array buffers and nothing else: one holds the order, one is the
	merge destination, and each pass copies back so the two buffers never alias or multiply. The scratch
	buffer is released on return; the returned order is released by the caller after linking
	and before the second sort, keeping at most two merge buffers alive at once.

	The sort is stable on the row index by construction: equal keys fall back to `a < b`.
	"""
	var order: PackedInt32Array = PackedInt32Array()
	order.resize(rows)
	var scratch: PackedInt32Array = PackedInt32Array()
	scratch.resize(rows)
	var filled: int = 0
	for row: int in rows:
		if occupied[row] == 1:
			order[filled] = row
			filled += 1
	var width: int = 1
	while width < count:
		var start: int = 0
		while start < count:
			var middle: int = mini(start + width, count)
			var end: int = mini(start + width + width, count)
			var left: int = start
			var right: int = middle
			var cursor: int = start
			while cursor < end:
				var take_left: bool = false
				if left < middle:
					take_left = right >= end \
						or not _reservation_key_before(order[right], order[left], k0, k1, k2, k3)
				if take_left:
					scratch[cursor] = order[left]
					left += 1
				else:
					scratch[cursor] = order[right]
					right += 1
				cursor += 1
			start += width + width
		for index: int in count:
			order[index] = scratch[index]
		width += width
	return order


func _reservation_key_before(a: int, b: int, k0: PackedInt32Array, k1: PackedInt32Array,
		k2: PackedInt32Array, k3: PackedInt32Array) -> bool:
	"""True when row `a` sorts strictly before row `b`, comparing FIELDS, never differences.

	Subtracting two signed purposes would overflow int32 for extreme values and invert the order,
	so every field is compared directly and the row index breaks the tie.
	"""
	if k0[a] != k0[b]:
		return k0[a] < k0[b]
	if k1[a] != k1[b]:
		return k1[a] < k1[b]
	if k2[a] != k2[b]:
		return k2[a] < k2[b]
	if k3[a] != k3[b]:
		return k3[a] < k3[b]
	return a < b


# --- live derived verification (capture only) ---------------------------------------------------------

func _reservation_derived_matches(derived: ReservationDerived) -> bool:
	"""Every live head, link and count must equal the rebuilt expectation, and the heap be valid.

	Inactive rows are compared too: a stale link on a released row is corruption that would
	otherwise survive a save/load round trip unnoticed.
	"""
	if _active_count != derived.active_count or _free_count != derived.free_count:
		return false
	for slot: int in _job_capacity:
		if _job_head[slot] != derived._job_head[slot]:
			return false
	for slot: int in _lot_capacity:
		if _lot_head[slot] != derived._lot_head[slot]:
			return false
	for row: int in _row_capacity:
		if _job_prev[row] != derived._job_prev[row] or _job_next[row] != derived._job_next[row]:
			return false
		if _lot_prev[row] != derived._lot_prev[row] or _lot_next[row] != derived._lot_next[row]:
			return false
	return _reservation_live_heap_ok()


func _reservation_live_heap_ok() -> bool:
	"""Validate the live free heap's PREFIX only: bounds, membership, then the min-heap property.

	ANY VALID PERMUTATION IS ACCEPTED. The heap is compared to the heap ORDER, never to the
	ascending rebuilt array, because allocation history legitimately leaves different layouts.

	Every cell is bounds-checked BEFORE it indexes the occupancy or membership buffer. The parent
	of `i` is `(i - 1) / 2` by integer division, which is strictly below `i`, so no read ever
	reaches `free_count` or beyond: the tail is residue and is deliberately never inspected.
	"""
	if _free_count != _row_capacity - _active_count:
		return false
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(_row_capacity)
	seen.fill(0)
	for index: int in _free_count:
		var row: int = _free_heap[index]
		if row < 0 or row >= _row_capacity:
			return false
		if _occupied[row] != 0:
			return false
		if seen[row] == 1:
			return false
		seen[row] = 1
		if index > 0 and _free_heap[(index - 1) / 2] > row:
			return false
	return true
