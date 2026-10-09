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
##  - `purpose` is an int32 this module still never INTERPRETS; it compares it for equality
##    (coalescing) and for order (canonical serialization) and nothing else. GDD §4.3 numbers no
##    `ReservationPurpose` domain. Brendan's task 06.4 ruling of 2026-10-02 numbers its first
##    members here -- PURPOSE_UNSPECIFIED, PURPOSE_HAUL_SOURCE and PURPOSE_HAUL_DESTINATION
##    (decision 1023) -- explicitly, so no later member can renumber them. The pool still admits
##    any int32: whether an unnumbered purpose should be REFUSED is an open question decision 1023
##    records, and refusing it today would invalidate claims no producer has numbered yet. It is
##    still not mirrored into `catalog.gd`'s protected enums, whose artifact digest it would move.
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
const HaulContract := preload("res://scripts/core/haul_transfer_contract.gd")
const ModularContract := preload("res://scripts/core/modular_project_contract.gd")
const ExcavationContract := preload("res://scripts/core/excavation_contract.gd")

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

## ReservationPurpose, numbered (task 06.4 H2, decision 1023). A haul's goods are claimed twice
## over their life, by the SAME Job, and the purpose says which half of the haul the claim is in:
##   HAUL_SOURCE      -- sized and claimed at assignment (REQ-SET-030), still in its source store,
##                       waiting for the load;
##   HAUL_DESTINATION -- loaded into the hauler's satchel and owed to the haul's destination; the
##                       load carries the claim over (`carry_claim()`), the unload ends it
##                       (`deliver_claim()`).
## UNSPECIFIED is 0, the value a cleared row holds and the one every claim made before the domain
## was numbered carried; it names no producer. Explicit numbers, never a sorted-key compile.
const PURPOSE_UNSPECIFIED: int = 0
const PURPOSE_HAUL_SOURCE: int = 1
const PURPOSE_HAUL_DESTINATION: int = 2
## Paid excavation input claims; consumed atomically into physical-site WIP (decision 1056).
const PURPOSE_EXCAVATION_INPUT: int = 3
## Shared spatial furnishing / spoil operation inputs (decision 1069); distinct from site phases.
const PURPOSE_MODULAR_INPUT: int = 4
## One past the highest numbered member.
const PURPOSE_NUMBERED_COUNT: int = 5

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
const REFUSE_INVENTORY_BINDING: StringName = &"RESERVATION_INVENTORY_BINDING"
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
const REFUSE_INPUT_CLAIM_EXPIRED: StringName = &"INPUT_CLAIM_EXPIRED"

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
## Derived world wiring, never a serialized pointer; clear() deliberately preserves it.
var _bound_inventory: WeakRef = null
## ADR1141 fixed scratch: two216B packets, never a second authoritative claim ledger.
var _haul_original: HaulContract.Transfer = HaulContract.Transfer.new()
var _haul_view: HaulContract.Transfer = HaulContract.Transfer.new()
var _haul_active: bool = false
var _haul_inventory: Inventory = null
var _haul_guard: HaulContract = null
var _haul_error: StringName = &""


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


func inventory_binding_refusal(inventory: Inventory) -> StringName:
	"""Reject another world even when all numeric container, lot and Job references coincide."""
	if inventory == null:
		return REFUSE_NO_INVENTORY
	if _bound_inventory != null and _bound_inventory.get_ref() != inventory:
		return REFUSE_INVENTORY_BINDING
	return REFUSE_NONE


func composition_refusal(inventory: Inventory) -> StringName:
	"""An unbound nonempty legacy import needs explicit Inventory-aware restore, not inferred identity."""
	var code: StringName = inventory_binding_refusal(inventory)
	if code != REFUSE_NONE:
		return code
	return REFUSE_INVENTORY_BINDING if _bound_inventory == null and _active_count > 0 else REFUSE_NONE


func bind_inventory(inventory: Inventory) -> Inventory.OpResult:
	"""Bind an empty pool or confirm its existing world, without changing any claim or quantity."""
	if _haul_reentry():
		return _refuse(HaulContract.REFUSE_REENTRY)
	var code: StringName = composition_refusal(inventory)
	if code != REFUSE_NONE:
		return _refuse(code)
	_remember_inventory(inventory)
	return _ok(NULL_REF, _active_count)


func _remember_inventory(inventory: Inventory) -> void:
	"""Publish world wiring only after successful composition or a committed Inventory operation."""
	if _bound_inventory == null:
		_bound_inventory = weakref(inventory)


func _bound_transaction_open() -> bool:
	"""Metadata-only claim changes must not invalidate an in-flight debit's untouched pool rows."""
	var inventory: Inventory = _bound_inventory.get_ref() as Inventory if _bound_inventory != null else null
	return inventory != null and inventory.is_transaction_open()


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
	`reserved_milli` will outlive the rows that justified it. Existing world wiring is retained;
	a new world needs a new pool, including when this pool is already empty.
	"""
	if _haul_reentry():
		return
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
	if _haul_reentry():
		return _refuse(HaulContract.REFUSE_REENTRY)
	var refusal: StringName = _preflight_batch(job_ref, claims, claim_count, inventory)
	if refusal != REFUSE_NONE:
		return _refuse(refusal)
	var new_rows: int = _pending_new_rows
	refusal = _apply_inventory_claims(claims, claim_count, inventory)
	if refusal != REFUSE_NONE:
		return _refuse(refusal)
	_apply_pool_rows(job_ref, claims, claim_count)
	_remember_inventory(inventory)
	return _ok(job_ref, new_rows)


func _preflight_batch(job_ref: Vector2i, claims: PackedInt64Array, claim_count: int, inventory: Inventory) -> StringName:
	"""Validate the complete transaction without writing anything. REFUSE_NONE means it may run."""
	var binding_code: StringName = inventory_binding_refusal(inventory)
	if binding_code != REFUSE_NONE:
		return binding_code
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


func _first_index_of_key(claims: PackedInt64Array, _claim_count: int, index: int) -> int:
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
	"""Use the common concrete row kernel without changing ordinary public behavior."""
	return _upsert_row_in(self, job_ref, lot_ref, purpose, quantity_milli, expiry)


static func _upsert_row_in(actual: RefCounted, job_ref: Vector2i, lot_ref: Vector2i, purpose: int, quantity_milli: int, expiry: int) -> int:
	"""Add a claim onto its existing row, or allocate a fresh one. Returns the row."""
	var row: int = _find_row_in(actual, job_ref, lot_ref, purpose)
	if row != NULL_ROW:
		actual._r_quantity_milli[row] += quantity_milli
		if expiry > actual._r_expiry[row]:
			actual._r_expiry[row] = expiry
		return row
	row = _allocate_row_in(actual)
	assert(row != NULL_ROW, "the preflight guarantees a free row here")
	actual._r_job_slot[row] = job_ref.x
	actual._r_job_generation[row] = job_ref.y
	actual._r_lot_slot[row] = lot_ref.x
	actual._r_lot_generation[row] = lot_ref.y
	actual._r_purpose[row] = purpose
	actual._r_quantity_milli[row] = quantity_milli
	actual._r_expiry[row] = expiry
	_link_job_in(actual, row)
	_link_lot_in(actual, row)
	return row


# --- Releasing --------------------------------------------------------------------------------

func consume_job_inputs(job_ref: Vector2i, purpose: int, now_tick: int,
		output_container: Vector2i, output_mass_g: int, inventory: Inventory) -> Inventory.OpResult:
	"""Consume matching actual claims and reserve finite output in one Inventory transaction.

	The owning coordinator has already proved its recipe and captured the lots' metadata for
	WIP. This pool supplies ownership, expiry and all-or-nothing accounting, never a recipe.
	It changes no row until Inventory commits; journal/capacity refusal preserves both owners.
	An empty input set is valid for material-free work. The Job owner still proves liveness.
	"""
	if _haul_reentry():
		return _refuse(HaulContract.REFUSE_REENTRY)
	return _consume_inputs_transaction(job_ref, purpose, now_tick, output_container,
		output_mass_g, inventory, null, NULL_REF)


func consume_connector_inputs(job_ref: Vector2i, now_tick: int, output_container: Vector2i,
		output_mass_g: int, inventory: Inventory, guard: ModularContract,
		project: Vector2i) -> Inventory.OpResult:
	"""Keep the connector's final actual-source proof after all removal observers, before payment."""
	if _haul_reentry():
		return _refuse(HaulContract.REFUSE_REENTRY)
	if guard == null:
		return _refuse(ModularContract.REFUSE_AUTHORITY)
	var code: StringName = guard.connector_inputs_refusal(project, job_ref, inventory, self)
	if code != REFUSE_NONE:
		return _refuse(code)
	return _consume_inputs_transaction(job_ref, PURPOSE_MODULAR_INPUT, now_tick, output_container,
		output_mass_g, inventory, guard, project)


func consume_excavation_inputs(job_ref: Vector2i, now_tick: int, output_container: Vector2i,
		output_mass_g: int, inventory: Inventory, guard: ExcavationContract,
		project: Vector2i) -> Inventory.OpResult:
	"""Actual Sites reattests the prepared phase after every reserved-input removal observer."""
	if _haul_reentry():
		return _refuse(HaulContract.REFUSE_REENTRY)
	if guard == null:
		return _refuse(ExcavationContract.REFUSE_AUTHORITY)
	var code: StringName = guard.excavation_inputs_refusal(project, job_ref, inventory, self)
	if code != REFUSE_NONE:
		return _refuse(code)
	return _consume_inputs_transaction(job_ref, PURPOSE_EXCAVATION_INPUT, now_tick, output_container,
		output_mass_g, inventory, null, project, guard)


func _consume_inputs_transaction(job_ref: Vector2i, purpose: int, now_tick: int,
		output_container: Vector2i, output_mass_g: int, inventory: Inventory,
		guard: ModularContract, project: Vector2i, excavation: ExcavationContract = null) -> Inventory.OpResult:
	"""Publish neither claim retirement nor a partial input debit before the complete journal commits."""
	var code: StringName = _consume_inputs_refusal(job_ref, purpose, now_tick,
		output_container, output_mass_g, inventory)
	if code != REFUSE_NONE:
		return _refuse(code)
	var opened: Inventory.OpResult = inventory.begin()
	if not opened.ok:
		return opened
	code = _consume_inputs_inventory(job_ref, purpose, output_container, output_mass_g, inventory)
	if code != REFUSE_NONE:
		inventory.abort()
		return _refuse(code)
	var committed: Inventory.OpResult = null
	if excavation != null:
		committed = inventory.commit_excavation_inputs(excavation, project, job_ref, self, output_container, output_mass_g)
	elif guard != null:
		committed = inventory.commit_connector_inputs(guard, project, job_ref, self)
	else:
		committed = inventory.commit()
	if not committed.ok:
		return committed
	_remember_inventory(inventory)
	return _ok(job_ref, _free_input_rows(job_ref, purpose))


func _consume_inputs_refusal(job_ref: Vector2i, purpose: int, now_tick: int,
		output_container: Vector2i, output_mass_g: int, inventory: Inventory) -> StringName:
	"""Check the full matching claim list and arguments without mutating any owner."""
	var binding_code: StringName = inventory_binding_refusal(inventory)
	if binding_code != REFUSE_NONE:
		return binding_code
	if inventory.is_transaction_open():
		return REFUSE_INVENTORY_TRANSACTION_OPEN
	if purpose < INT32_MIN or purpose > INT32_MAX:
		return REFUSE_INVALID_PURPOSE
	if now_tick < 0:
		return REFUSE_INVALID_EXPIRY
	if output_mass_g < 0 or (output_mass_g == 0 and output_container != NULL_REF):
		return REFUSE_INVALID_QUANTITY
	if output_mass_g > 0 and not inventory.is_container_valid(output_container):
		return Inventory.REFUSE_INVALID_CONTAINER
	var code: StringName = _check_job_ref(job_ref)
	if code != REFUSE_NONE:
		return code
	return _input_rows_refusal(job_ref, purpose, now_tick, inventory)


func _input_rows_refusal(job_ref: Vector2i, purpose: int, now_tick: int,
		inventory: Inventory) -> StringName:
	"""Validate owned quantities and absolute-tick leases before the first Inventory write."""
	var row: int = _list_head(job_ref, true)
	while row != NULL_ROW:
		if _r_purpose[row] == purpose:
			var lot: Vector2i = row_lot_ref(row)
			if not inventory.is_lot_valid(lot):
				return REFUSE_INVALID_LOT
			if inventory.lot_reserved_milli(lot) < _r_quantity_milli[row]:
				return REFUSE_AUDIT_RESERVED_TOTAL
			if now_tick >= _r_expiry[row]:
				return REFUSE_INPUT_CLAIM_EXPIRED
		row = _job_next[row]
	return REFUSE_NONE


func _consume_inputs_inventory(job_ref: Vector2i, purpose: int, output_container: Vector2i,
		output_mass_g: int, inventory: Inventory) -> StringName:
	"""Write only journaled Inventory state while the reservation rows remain untouched."""
	if output_mass_g > 0:
		var reserved: Inventory.OpResult = inventory.reserve_container_mass(output_container, output_mass_g)
		if not reserved.ok:
			return reserved.error
	var row: int = _list_head(job_ref, true)
	while row != NULL_ROW:
		if _r_purpose[row] == purpose:
			var consumed: Inventory.OpResult = inventory.consume_reserved(row_lot_ref(row), _r_quantity_milli[row])
			if not consumed.ok:
				return consumed.error
		row = _job_next[row]
	return REFUSE_NONE


func _free_input_rows(job_ref: Vector2i, purpose: int) -> int:
	"""Publish pool retirement after the matching Inventory transaction has committed."""
	var freed: int = 0
	var row: int = _list_head(job_ref, true)
	while row != NULL_ROW:
		var next: int = _job_next[row]
		if _r_purpose[row] == purpose:
			_free_row(row)
			freed += 1
		row = next
	return freed


func release_claim(job_ref: Vector2i, lot_ref: Vector2i, purpose: int, inventory: Inventory) -> Inventory.OpResult:
	"""Release one `(job, lot, purpose)` claim in full. `.value` is the quantity released."""
	if _haul_reentry():
		return _refuse(HaulContract.REFUSE_REENTRY)
	var binding_code: StringName = inventory_binding_refusal(inventory)
	if binding_code != REFUSE_NONE:
		return _refuse(binding_code)
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
	_remember_inventory(inventory)
	return _ok(lot_ref, quantity)


func release_job_claims(job_ref: Vector2i, inventory: Inventory) -> Inventory.OpResult:
	"""Release every claim held by one Job, or refuse and release none.

	This is the worker-departure and job-cancellation path. Decision 0017 keeps shared claims on
	the coordinator Job, so calling this for a departing member releases that member's own rows
	and cannot touch the party's shared ingredients. `.value` is the number of rows released.
	"""
	if _haul_reentry():
		return _refuse(HaulContract.REFUSE_REENTRY)
	return _release_list(job_ref, true, inventory)


func release_lot_claims(lot_ref: Vector2i, inventory: Inventory) -> Inventory.OpResult:
	"""Release every claim standing against one lot, or refuse and release none.

	GDD §5.8's spoilage path: the rows go in the lot list's canonical order, which is ascending
	`(job_slot, job_generation, purpose)` and therefore independent of the order they were
	claimed in. `.value` is the number of rows released.
	"""
	if _haul_reentry():
		return _refuse(HaulContract.REFUSE_REENTRY)
	return _release_list(lot_ref, false, inventory)


func _release_list(owner_ref: Vector2i, by_job: bool, inventory: Inventory) -> Inventory.OpResult:
	"""Release a whole job list or lot list all-or-nothing. `by_job` selects which list."""
	var binding_code: StringName = inventory_binding_refusal(inventory)
	if binding_code != REFUSE_NONE:
		return _refuse(binding_code)
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
	_remember_inventory(inventory)
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
	if _haul_reentry():
		return _refuse(HaulContract.REFUSE_REENTRY)
	var binding_code: StringName = inventory_binding_refusal(inventory)
	if binding_code != REFUSE_NONE:
		return _refuse(binding_code)
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
	if dropped > 0:
		_remember_inventory(inventory)
	return _ok(lot_ref, dropped)


func release_expired_for_job(job_ref: Vector2i, now_tick: int, inventory: Inventory) -> Inventory.OpResult:
	"""Release this Job's claims whose lease has run out, reading `now_tick >= expiry` as expired.

	BAL-SAFE-004's cross-job sweep releases rows "in job-ID order", which needs the Job store's
	persistent-ID mapping and therefore belongs to `jobs.gd`; this is the per-job entry point it
	calls. Within the job the rows go in the job list's canonical order. `.value` is the number
	of rows released; a job with nothing expired releases none and is not a refusal.
	"""
	if _haul_reentry():
		return _refuse(HaulContract.REFUSE_REENTRY)
	var binding_code: StringName = inventory_binding_refusal(inventory)
	if binding_code != REFUSE_NONE:
		return _refuse(binding_code)
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
	_remember_inventory(inventory)
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
	if _haul_reentry():
		return _refuse(HaulContract.REFUSE_REENTRY)
	if _bound_transaction_open():
		return _refuse(REFUSE_INVENTORY_TRANSACTION_OPEN)
	if new_expiry < 0:
		return _refuse(REFUSE_INVALID_EXPIRY)
	var row: int = _find_row(job_ref, lot_ref, purpose)
	if row == NULL_ROW:
		return _refuse(REFUSE_NO_SUCH_CLAIM)
	if new_expiry <= _r_expiry[row]:
		return _refuse(REFUSE_EXPIRY_NOT_LATER)
	_r_expiry[row] = new_expiry
	return _ok(lot_ref, new_expiry)


# --- Carrying a claim with its goods (task 06.4 H1, decision 1022) ------------------------------
#
# A haul moves CLAIMED goods. INV-GOODS-R01 forbids teleporting them and BAL-SAFE-002 keeps a lot
# in transit in exactly one container, so they move by Inventory's own move/transfer -- and the
# claim must move with them in the same all-or-nothing step: a claim left on the source would
# reserve quantity that is no longer there, and goods arriving unclaimed in a satchel could be
# drawn by anyone. These two doors are that step. Like `claim_batch()`, each runs ONE inventory
# transaction of its own and refuses a caller's open one, because the pool's rows are not
# journaled by Inventory; the rows are written only after that transaction commits.
#
#   carry_claim():   the LOAD. The claim's whole quantity leaves its lot for `dest_ref` (the
#                    haul's satchel) and arrives STILL CLAIMED by the same Job under
#                    `carried_purpose`, with the same lease.
#   deliver_claim(): the UNLOAD. The quantity leaves for `dest_ref` (the destination store)
#                    UNCLAIMED, and the destination headroom reserved for it is released in the
#                    same transaction, so the room is never counted twice or not at all.
#
# A WHOLE LOT MOVES WHOLE. When the claim is the entire lot, `move_lot()` moves the lot itself:
# it keeps its identity, so whatever is keyed to it (a gear instance) survives and nothing splits
# or merges. A part moves by `transfer()`, which splits it exactly and never clones (REQ-SET-111).

func carry_claim(job_ref: Vector2i, lot_ref: Vector2i, purpose: int, dest_ref: Vector2i,
		carried_purpose: int, inventory: Inventory) -> Inventory.OpResult:
	"""Move one claim's goods into the live container `dest_ref` and keep them claimed.

	On success `.ref` is the lot now holding the goods (the same lot when it moved whole) and
	`.value` the quantity. Refuses, changing neither store: no such claim, a stale lot, an open
	inventory transaction, an out-of-range purpose, and anything Inventory refuses (capacity, a
	filter, an expired seed, a full journal). The lease (`expiry`) is carried unchanged.
	"""
	if _haul_reentry():
		return _refuse(HaulContract.REFUSE_REENTRY)
	return _carry(job_ref, lot_ref, purpose, dest_ref, NULL_REF, 0, carried_purpose, inventory)


func load_claim_into_new_satchel(job_ref: Vector2i, lot_ref: Vector2i, purpose: int,
		owner_ref: Vector2i, carry_g: int, carried_purpose: int,
		inventory: Inventory) -> Inventory.OpResult:
	"""The haul's LOAD: `carry_claim()` into a satchel minted in the SAME transaction.

	Brendan's 2026-10-02 ruling makes the satchel at load, owned by the hauler and sized to its
	species carry limit; minting it inside the move's transaction means a load that refuses (an
	expired seed, a full lot store) leaves no satchel behind and both stores byte-identical.
	`.ref` is the carried lot; its container is the new satchel.
	"""
	if _haul_reentry():
		return _refuse(HaulContract.REFUSE_REENTRY)
	if not Inventory.is_well_formed_owner(owner_ref):
		return _refuse(Inventory.REFUSE_INVALID_OWNER_REF)
	return _carry(job_ref, lot_ref, purpose, NULL_REF, owner_ref, carry_g, carried_purpose,
		inventory)


func _carry(job_ref: Vector2i, lot_ref: Vector2i, purpose: int, dest_ref: Vector2i,
		mint_owner: Vector2i, mint_g: int, carried_purpose: int,
		inventory: Inventory) -> Inventory.OpResult:
	"""`carry_claim()` and the load's shared body: preflight, one transaction, then the rows."""
	var refusal: StringName = _preflight_carry(job_ref, lot_ref, purpose, carried_purpose, inventory)
	if refusal != REFUSE_NONE:
		return _refuse(refusal)
	var row: int = _find_row(job_ref, lot_ref, purpose)
	var quantity: int = _r_quantity_milli[row]
	var expiry: int = _r_expiry[row]
	var moved: Inventory.OpResult = _move_claimed_goods(lot_ref, dest_ref, quantity, 0, true,
		inventory, mint_owner, mint_g)
	if not moved.ok:
		return _refuse(moved.error)
	_free_row(row)
	_upsert_row(job_ref, moved.ref, carried_purpose, quantity, expiry)
	_remember_inventory(inventory)
	return _ok(moved.ref, quantity)


func deliver_claim(job_ref: Vector2i, lot_ref: Vector2i, purpose: int, dest_ref: Vector2i,
		release_mass_g: int, inventory: Inventory) -> Inventory.OpResult:
	"""Move one claim's goods into `dest_ref` and end the claim: the haul's UNLOAD.

	`release_mass_g` is the destination headroom the haul reserved for these goods (0 when it
	reserved none); it is released in the same transaction as the move. A satchel the move
	empties is destroyed in that transaction too ("destroyed when empty", decision 1022). `.ref`
	is the delivered lot, `.value` the quantity. Refuses like `carry_claim()`, plus a negative
	`release_mass_g` (INVALID_QUANTITY) and Inventory's own refusal of the release.
	"""
	if _haul_reentry():
		return _refuse(HaulContract.REFUSE_REENTRY)
	var refusal: StringName = _preflight_carry(job_ref, lot_ref, purpose, PURPOSE_UNSPECIFIED,
		inventory)
	if refusal == REFUSE_NONE and release_mass_g < 0:
		refusal = REFUSE_INVALID_QUANTITY
	if refusal != REFUSE_NONE:
		return _refuse(refusal)
	var row: int = _find_row(job_ref, lot_ref, purpose)
	var moved: Inventory.OpResult = _move_claimed_goods(lot_ref, dest_ref,
		_r_quantity_milli[row], release_mass_g, false, inventory, NULL_REF, 0)
	if not moved.ok:
		return _refuse(moved.error)
	var quantity: int = _r_quantity_milli[row]
	_free_row(row)
	_remember_inventory(inventory)
	return _ok(moved.ref, quantity)


func repurpose_claim(job_ref: Vector2i, lot_ref: Vector2i, purpose: int,
		new_purpose: int) -> Inventory.OpResult:
	"""Re-key one claim to `new_purpose` where it stands: same job, lot, quantity and lease.

	The load of goods ALREADY in the hauler's satchel (a haul re-posted after a cancellation,
	decision 1022) moves nothing, so only the claim's purpose changes. Inventory's
	`reserved_milli` is untouched, so the module invariant holds without a transaction. A claim
	already keyed `new_purpose` for the same job and lot coalesces with it. `.value` is the
	quantity. Refuses NO_SUCH_CLAIM and an out-of-range purpose, writing nothing.
	"""
	if _haul_reentry():
		return _refuse(HaulContract.REFUSE_REENTRY)
	if _bound_transaction_open():
		return _refuse(REFUSE_INVENTORY_TRANSACTION_OPEN)
	if new_purpose < INT32_MIN or new_purpose > INT32_MAX:
		return _refuse(REFUSE_INVALID_PURPOSE)
	var row: int = _find_row(job_ref, lot_ref, purpose)
	if row == NULL_ROW:
		return _refuse(REFUSE_NO_SUCH_CLAIM)
	var quantity: int = _r_quantity_milli[row]
	var expiry: int = _r_expiry[row]
	_free_row(row)
	_upsert_row(job_ref, lot_ref, new_purpose, quantity, expiry)
	return _ok(lot_ref, quantity)


func _preflight_carry(job_ref: Vector2i, lot_ref: Vector2i, purpose: int, carried_purpose: int,
		inventory: Inventory) -> StringName:
	"""Everything the carry doors check before their transaction opens."""
	var binding_code: StringName = inventory_binding_refusal(inventory)
	if binding_code != REFUSE_NONE:
		return binding_code
	if inventory.is_transaction_open():
		return REFUSE_INVENTORY_TRANSACTION_OPEN
	if carried_purpose < INT32_MIN or carried_purpose > INT32_MAX:
		return REFUSE_INVALID_PURPOSE
	var row: int = _find_row(job_ref, lot_ref, purpose)
	if row == NULL_ROW:
		return REFUSE_NO_SUCH_CLAIM
	if not inventory.is_lot_valid(lot_ref):
		return REFUSE_INVALID_LOT
	if inventory.lot_reserved_milli(lot_ref) < _r_quantity_milli[row]:
		return REFUSE_AUDIT_RESERVED_TOTAL
	return REFUSE_NONE


func _move_claimed_goods(lot_ref: Vector2i, dest_ref: Vector2i, quantity: int,
		release_mass_g: int, keep_claim: bool, inventory: Inventory, mint_owner: Vector2i,
		mint_g: int) -> Inventory.OpResult:
	"""One inventory transaction: [mint a satchel,] unreserve, release headroom, move, re-reserve.

	The pool is untouched until this commits, so any refusal -- Inventory's, or a pool row the
	arriving lot's slot still lists under another generation -- aborts and leaves both stores
	exactly as they were. `.ref` is the arriving lot.
	"""
	var opened: Inventory.OpResult = inventory.begin()
	if not opened.ok:
		return opened
	var target: Inventory.OpResult = _carry_target(dest_ref, mint_owner, mint_g, inventory)
	var moved: Inventory.OpResult = target
	if target.ok:
		moved = _move_inside(lot_ref, target.ref, quantity, release_mass_g, keep_claim, inventory)
	if not moved.ok:
		inventory.abort()
		return moved
	var committed: Inventory.OpResult = inventory.commit()
	return moved if committed.ok else committed


func _carry_target(dest_ref: Vector2i, mint_owner: Vector2i, mint_g: int,
		inventory: Inventory) -> Inventory.OpResult:
	"""The container the goods go to: `dest_ref`, or a satchel minted now for `mint_owner`."""
	if mint_owner == NULL_REF:
		return _ok(dest_ref, 0)
	return inventory.create_satchel(mint_owner, mint_g)


func _move_inside(lot_ref: Vector2i, dest_ref: Vector2i, quantity: int, release_mass_g: int,
		keep_claim: bool, inventory: Inventory) -> Inventory.OpResult:
	"""The writes inside `_move_claimed_goods()`'s open transaction, in order."""
	var source: Vector2i = inventory.lot_container(lot_ref)
	var step: Inventory.OpResult = inventory.release_reservation(lot_ref, quantity)
	if step.ok and release_mass_g > 0:
		step = inventory.release_container_mass(dest_ref, release_mass_g)
	if not step.ok:
		return step
	var whole: bool = quantity == inventory.lot_quantity_milli(lot_ref)
	var moved: Inventory.OpResult = inventory.move_lot(lot_ref, dest_ref) if whole \
		else inventory.transfer(lot_ref, dest_ref, quantity)
	if not moved.ok:
		return moved
	if not keep_claim:
		return _retire_emptied_satchel(source, moved, inventory)
	var head: StringName = _arrival_row_refusal(moved.ref)
	if head != REFUSE_NONE:
		return _refuse(head)
	step = inventory.reserve_lot(moved.ref, quantity)
	return moved if step.ok else step


func _retire_emptied_satchel(source: Vector2i, moved: Inventory.OpResult,
		inventory: Inventory) -> Inventory.OpResult:
	"""Destroy the source satchel the delivery emptied, inside the same transaction."""
	if not inventory.is_satchel(source) or inventory.container_lot_count(source) != 0:
		return moved
	var destroyed: Inventory.OpResult = inventory.destroy_satchel(source)
	return moved if destroyed.ok else destroyed


func _arrival_row_refusal(arrived: Vector2i) -> StringName:
	"""Whether the pool can key a row to the arriving lot: in range, no other generation listed."""
	if arrived.x < 0 or arrived.x >= _lot_capacity:
		return REFUSE_LOT_OUT_OF_RANGE
	var head: int = _lot_head[arrived.x]
	if head != NULL_ROW and _r_lot_generation[head] != arrived.y:
		return REFUSE_LOT_GENERATION_CONFLICT
	return REFUSE_NONE


# --- Guarded spatial hauling (ADR1141) ----------------------------------------------------------

func admit_haul_guarded(job: Vector2i, worker: Vector2i, source_lot: Vector2i,
		quantity_milli: int, expiry_tick: int, destination: Vector2i, reserved_mass_g: int,
		guard: HaulContract, inventory: Inventory) -> Inventory.OpResult:
	"""Reserve source goods and destination grams in one original, finally guarded journal."""
	var code: StringName = _haul_begin(guard, inventory)
	if code != REFUSE_NONE:
		return _refuse(code)
	_haul_pin(HaulContract.ADMIT, job, worker, source_lot, destination, NULL_REF, reserved_mass_g, 0)
	_haul_original.quantity_milli = quantity_milli
	_haul_original.expiry_tick = expiry_tick
	code = _haul_admit_plan()
	return _haul_finish(code)


func transfer_haul_guarded(action: int, job: Vector2i, worker: Vector2i,
		source_lot: Vector2i, destination: Vector2i, original_satchel: Vector2i,
		reserved_mass_g: int, carry_limit_g: int, guard: HaulContract,
		inventory: Inventory) -> Inventory.OpResult:
	"""Load, repost, unload or cancel exact owned goods; caller publishes only after success."""
	var code: StringName = _haul_begin(guard, inventory)
	if code != REFUSE_NONE:
		return _refuse(code)
	_haul_pin(action, job, worker, source_lot, destination, original_satchel, reserved_mass_g, carry_limit_g)
	code = _haul_transfer_plan()
	return _haul_finish(code)


func _haul_begin(guard: HaulContract, inventory: Inventory) -> StringName:
	"""Retain actual owners before any economic observer can run; a nested attempt poisons this scope."""
	if _haul_reentry():
		return HaulContract.REFUSE_REENTRY
	if guard == null or inventory == null or _bound_inventory == null:
		return HaulContract.REFUSE_UNBOUND
	if _bound_inventory.get_ref() != inventory:
		return REFUSE_INVENTORY_BINDING
	if inventory._tx_open or inventory._attesting:
		return REFUSE_INVENTORY_TRANSACTION_OPEN
	_haul_active = true
	_haul_inventory = inventory
	_haul_guard = guard
	_haul_error = REFUSE_NONE
	return REFUSE_NONE


func _haul_pin(action: int, job: Vector2i, worker: Vector2i, source_lot: Vector2i,
		destination: Vector2i, satchel: Vector2i, grams: int, carry_g: int) -> void:
	"""Reset the existing private packet and pin the caller's complete input tuple."""
	_haul_reset_packet(_haul_original)
	_haul_original.action = action
	_haul_original.job = job
	_haul_original.worker = worker
	_haul_original.source_lot = source_lot
	_haul_original.destination = destination
	_haul_original.original_satchel = satchel
	_haul_original.reserved_mass_g = grams
	_haul_original.carry_limit_g = carry_g


static func _haul_reset_packet(packet: HaulContract.Transfer) -> void:
	"""No per-operation packet allocation and no stale optional source facts on cancellation."""
	packet.job = NULL_REF
	packet.worker = NULL_REF
	packet.source_lot = NULL_REF
	packet.source_container = NULL_REF
	packet.destination = NULL_REF
	packet.original_satchel = NULL_REF
	packet.arrived_lot = NULL_REF
	packet.staged_satchel = NULL_REF
	packet.action = -1
	packet.claim_row = NULL_ROW
	packet.claim_count = 0
	packet.from_purpose = 0
	packet.to_purpose = 0
	packet.quantity_milli = 0
	packet.expiry_tick = 0
	packet.reserved_mass_g = 0
	packet.carry_limit_g = 0
	packet.item_id = -1
	packet.item_mass_g = 0
	packet.quality = 0
	packet.age_milli_hours = 0
	packet.age_remainder = 0
	packet.provenance = 0
	packet.recipe_id = 0
	packet.source_quantity_milli = 0
	packet.source_reserved_milli = 0
	packet.destination_reserved_g = 0


func _haul_common_plan() -> StringName:
	"""Full pool key and actual destination before opening the sole journal."""
	var packet: HaulContract.Transfer = _haul_original
	var code: StringName = _check_job_ref(packet.job)
	if code != REFUSE_NONE:
		return code
	if not HaulContract.container_live(_haul_inventory, packet.destination):
		return Inventory.REFUSE_INVALID_CONTAINER
	if packet.reserved_mass_g < 0 or _haul_inventory._c_policy[packet.destination.x] == Inventory.POLICY_SATCHEL:
		return REFUSE_INVALID_QUANTITY
	packet.destination_reserved_g = _haul_inventory._c_reserved_mass_g[packet.destination.x]
	if packet.action != HaulContract.ADMIT and packet.destination_reserved_g < packet.reserved_mass_g:
		return Inventory.REFUSE_INSUFFICIENT_RESERVED_MASS
	return REFUSE_NONE


func _haul_source_plan() -> StringName:
	"""Capture all item/quantity/age facts directly; Delivery owns actual worker/phase/location proof."""
	var packet: HaulContract.Transfer = _haul_original
	if not HaulContract.lot_live(_haul_inventory, packet.source_lot):
		return REFUSE_INVALID_LOT
	var key_code: StringName = _arrival_row_refusal(packet.source_lot)
	if key_code != REFUSE_NONE:
		return key_code
	if packet.worker.x < 0 or packet.worker.y <= 0:
		return HaulContract.REFUSE_SCOPE
	var row: int = packet.source_lot.x
	packet.source_container = Vector2i(_haul_inventory._l_container_slot[row], _haul_inventory._l_container_generation[row])
	if not HaulContract.container_live(_haul_inventory, packet.source_container):
		return Inventory.REFUSE_LOT_EQUIPPED
	packet.item_id = _haul_inventory._l_item_id[row]
	packet.item_mass_g = _haul_inventory._item_mass_g[packet.item_id]
	packet.quality = _haul_inventory._l_quality[row]
	packet.age_milli_hours = _haul_inventory._l_age_milli_hours[row]
	packet.age_remainder = _haul_inventory._l_age_remainder[row]
	packet.provenance = _haul_inventory._l_provenance[row]
	packet.recipe_id = _haul_inventory._l_recipe_id[row]
	packet.source_quantity_milli = _haul_inventory._l_quantity_milli[row]
	packet.source_reserved_milli = _haul_inventory._l_reserved_milli[row]
	return REFUSE_NONE


func _haul_admit_plan() -> StringName:
	"""One HAUL_SOURCE row and exact ceil-debit grams; nothing is published during planning."""
	var code: StringName = _haul_common_plan()
	if code == REFUSE_NONE:
		code = _haul_source_plan()
	if code != REFUSE_NONE:
		return code
	var packet: HaulContract.Transfer = _haul_original
	if _job_head[packet.job.x] != NULL_ROW or _free_count <= 0:
		return HaulContract.REFUSE_CLAIM
	if packet.quantity_milli <= 0 or packet.quantity_milli > packet.source_quantity_milli - packet.source_reserved_milli \
		or packet.expiry_tick < 0:
		return REFUSE_INVALID_QUANTITY
	packet.claim_row = _free_heap[0]
	packet.claim_count = 1
	packet.to_purpose = PURPOSE_HAUL_SOURCE
	return _haul_mass_refusal()


func _haul_transfer_plan() -> StringName:
	"""Normal transfers require the single original haul claim; cancellation releases the whole chain."""
	var packet: HaulContract.Transfer = _haul_original
	if packet.action < HaulContract.LOAD or packet.action > HaulContract.CANCEL:
		return HaulContract.REFUSE_SCOPE
	var code: StringName = _haul_common_plan()
	if code != REFUSE_NONE:
		return code
	packet.claim_row = _job_head[packet.job.x]
	if packet.action == HaulContract.CANCEL:
		return _haul_cancel_plan()
	code = _haul_source_plan()
	if code != REFUSE_NONE:
		return code
	packet.from_purpose = PURPOSE_HAUL_DESTINATION if packet.action == HaulContract.UNLOAD else PURPOSE_HAUL_SOURCE
	packet.to_purpose = PURPOSE_HAUL_DESTINATION if packet.action != HaulContract.UNLOAD else PURPOSE_UNSPECIFIED
	if packet.claim_row < 0 or _job_next[packet.claim_row] != NULL_ROW \
		or _find_row(packet.job, packet.source_lot, packet.from_purpose) != packet.claim_row:
		return REFUSE_NO_SUCH_CLAIM
	packet.claim_count = 1
	packet.quantity_milli = _r_quantity_milli[packet.claim_row]
	packet.expiry_tick = _r_expiry[packet.claim_row]
	if packet.quantity_milli <= 0 or packet.source_reserved_milli < packet.quantity_milli:
		return REFUSE_AUDIT_RESERVED_TOTAL
	code = _haul_mass_refusal()
	return _haul_satchel_refusal() if code == REFUSE_NONE else code


func _haul_mass_refusal() -> StringName:
	"""Reuse Inventory's exact per-lot ceiling arithmetic; no assembly-size carry assumption."""
	var packet: HaulContract.Transfer = _haul_original
	if not IntMath.inventory_capacity_debit_g_into(packet.quantity_milli, packet.item_mass_g, _math):
		return Inventory.REFUSE_OVERFLOW
	if packet.reserved_mass_g != _math.value:
		return HaulContract.REFUSE_SCOPE
	if (packet.action == HaulContract.LOAD or packet.action == HaulContract.REPOST) \
		and (packet.carry_limit_g <= 0 or _math.value > packet.carry_limit_g):
		return Inventory.REFUSE_CAPACITY_EXCEEDED
	return REFUSE_NONE


func _haul_satchel_refusal() -> StringName:
	"""Staged creation differs from an already carried lot; both use the exact worker pair."""
	var packet: HaulContract.Transfer = _haul_original
	if packet.action == HaulContract.LOAD:
		return REFUSE_NONE if packet.original_satchel == NULL_REF \
			and _haul_inventory._c_policy[packet.source_container.x] != Inventory.POLICY_SATCHEL else HaulContract.REFUSE_SCOPE
	if packet.original_satchel != packet.source_container \
		or not HaulContract.satchel_matches(_haul_inventory, packet.original_satchel, packet.worker):
		return HaulContract.REFUSE_SCOPE
	return REFUSE_NONE


func _haul_cancel_plan() -> StringName:
	"""Worker/Project-free release of exact original claims, with bounded traversal and no image."""
	var row: int = _haul_original.claim_row
	while row != NULL_ROW:
		if row < 0 or row >= _row_capacity or _haul_original.claim_count >= _row_capacity \
			or _occupied[row] != 1 or _r_job_generation[row] != _haul_original.job.y:
			return HaulContract.REFUSE_CLAIM
		var lot: Vector2i = Vector2i(_r_lot_slot[row], _r_lot_generation[row])
		if not HaulContract.lot_live(_haul_inventory, lot) or _r_quantity_milli[row] <= 0 \
			or _haul_inventory._l_reserved_milli[lot.x] < _r_quantity_milli[row]:
			return REFUSE_AUDIT_RESERVED_TOTAL
		_haul_original.claim_count += 1
		row = _job_next[row]
	return REFUSE_NONE


func _haul_finish(code: StringName) -> Inventory.OpResult:
	"""Only this original synchronous scope can reach the journal and its pure publication tail."""
	var result: Inventory.OpResult = _refuse(code) if code != REFUSE_NONE else _haul_transaction()
	_clear_haul_scope(self)
	return result


func _haul_transaction() -> Inventory.OpResult:
	"""All Inventory observers precede its guarded commit; Pool rows stay live and locked throughout."""
	var step: Inventory.OpResult = _haul_inventory.begin()
	if not step.ok:
		return step
	step = _haul_stage()
	if not step.ok or _haul_error != REFUSE_NONE:
		_haul_inventory.abort()
		return _refuse(_haul_error) if _haul_error != REFUSE_NONE else step
	HaulContract.copy_into(_haul_original, _haul_view)
	var committed: Inventory.OpResult = _haul_inventory.commit_haul_transfer(_haul_guard, _haul_view, self)
	if not committed.ok:
		return committed
	_publish_haul_pool_rows(self, _haul_original)
	if _haul_original.action == HaulContract.CANCEL:
		return Inventory.OpResult.new(true, REFUSE_NONE, _haul_original.job, _haul_original.claim_count)
	return Inventory.OpResult.new(true, REFUSE_NONE, _haul_original.arrived_lot, _haul_original.quantity_milli)


func _haul_stage() -> Inventory.OpResult:
	"""Reuse the real Inventory move/reserve/satchel operations in the one existing journal."""
	var packet: HaulContract.Transfer = _haul_original
	if packet.action == HaulContract.ADMIT:
		return _haul_stage_admit()
	if packet.action == HaulContract.CANCEL:
		return _haul_stage_cancel()
	if packet.action == HaulContract.REPOST:
		packet.arrived_lot = packet.source_lot
		packet.staged_satchel = packet.original_satchel
		return _ok(packet.source_lot, packet.quantity_milli)
	var target: Inventory.OpResult = _haul_inventory.create_satchel(packet.worker, packet.carry_limit_g) \
		if packet.action == HaulContract.LOAD else _ok(packet.destination, 0)
	if not target.ok:
		return target
	var moved: Inventory.OpResult = _move_inside(packet.source_lot, target.ref, packet.quantity_milli,
		packet.reserved_mass_g if packet.action == HaulContract.UNLOAD else 0,
		packet.action == HaulContract.LOAD, _haul_inventory)
	if moved.ok:
		packet.arrived_lot = moved.ref
		packet.staged_satchel = target.ref if packet.action == HaulContract.LOAD else \
			(packet.original_satchel if HaulContract.container_live(_haul_inventory, packet.original_satchel) else NULL_REF)
	return moved


func _haul_stage_admit() -> Inventory.OpResult:
	"""Capacity and the new source claim are admitted or rolled back together."""
	var packet: HaulContract.Transfer = _haul_original
	var step: Inventory.OpResult = _haul_inventory.reserve_container_mass(packet.destination, packet.reserved_mass_g)
	if step.ok:
		step = _haul_inventory.reserve_lot(packet.source_lot, packet.quantity_milli)
	if step.ok:
		packet.arrived_lot = packet.source_lot
	return step


func _haul_stage_cancel() -> Inventory.OpResult:
	"""No satchel goods move; both claim release and destination capacity share this journal."""
	var row: int = _haul_original.claim_row
	while row != NULL_ROW:
		var step: Inventory.OpResult = _haul_inventory.release_reservation(
			Vector2i(_r_lot_slot[row], _r_lot_generation[row]), _r_quantity_milli[row])
		if not step.ok:
			return step
		row = _job_next[row]
	return _haul_inventory.release_container_mass(_haul_original.destination, _haul_original.reserved_mass_g) \
		if _haul_original.reserved_mass_g > 0 else _ok(NULL_REF, 0)


func _haul_reentry() -> bool:
	"""Every public Pool mutation refuses and poisons its original synchronous haul scope."""
	if not _haul_active:
		return false
	_haul_error = HaulContract.REFUSE_REENTRY
	return true


static func _clear_haul_scope(actual: RefCounted) -> void:
	"""No callback is permitted after a committed transfer, including scratch cleanup."""
	actual._haul_active = false
	actual._haul_inventory = null
	actual._haul_guard = null
	actual._haul_error = &""


static func _publish_haul_pool_rows(actual: RefCounted, packet: HaulContract.Transfer) -> void:
	"""Publish only already-preflighted rows after Inventory's last observer and successful commit."""
	if packet.action == HaulContract.CANCEL:
		var row: int = packet.claim_row
		while row != NULL_ROW:
			var next: int = actual._job_next[row]
			_free_row_in(actual, row)
			row = next
		return
	if packet.action != HaulContract.ADMIT:
		_free_row_in(actual, packet.claim_row)
	if packet.action != HaulContract.UNLOAD:
		_upsert_row_in(actual, packet.job, packet.arrived_lot, packet.to_purpose,
			packet.quantity_milli, packet.expiry_tick)


# --- Row allocation ---------------------------------------------------------------------------

func _allocate_row() -> int:
	"""Use the common concrete row kernel without changing ordinary public behavior."""
	return _allocate_row_in(self)


static func _allocate_row_in(actual: RefCounted) -> int:
	"""Take the LOWEST free row index (decision 0019), or NULL_ROW when the pool is full."""
	if actual._free_count <= 0:
		return NULL_ROW
	var row: int = _pop_min_in(actual)
	actual._free_count -= 1
	actual._occupied[row] = 1
	actual._active_count += 1
	return row


func _free_row(row: int) -> void:
	"""Use the common concrete row kernel without changing ordinary public behavior."""
	_free_row_in(self, row)


static func _free_row_in(actual: RefCounted, row: int) -> void:
	"""Unlink a row from both lists, blank it, and return it to the free heap."""
	_unlink_job_in(actual, row)
	_unlink_lot_in(actual, row)
	actual._r_job_slot[row] = NULL_SLOT
	actual._r_job_generation[row] = NULL_GENERATION
	actual._r_lot_slot[row] = NULL_SLOT
	actual._r_lot_generation[row] = NULL_GENERATION
	actual._r_purpose[row] = 0
	actual._r_quantity_milli[row] = 0
	actual._r_expiry[row] = 0
	actual._occupied[row] = 0
	actual._active_count -= 1
	_push_free_in(actual, row)
	actual._free_count += 1


func _pop_min() -> int:
	"""Use the common concrete row kernel without changing ordinary public behavior."""
	return _pop_min_in(self)


static func _pop_min_in(actual: RefCounted) -> int:
	"""Remove and return the smallest entry of the free-row min-heap.

	Sift-down copied in shape from `entity_directory.gd`'s ARCH-ID-002 heap, which is left
	byte-untouched; this pool owns a single window so it needs no base offset.
	"""
	var smallest: int = actual._free_heap[0]
	var last: int = actual._free_count - 1
	if last == 0:
		return smallest
	actual._free_heap[0] = actual._free_heap[last]
	var index: int = 0
	while index * 2 + 1 < last:
		var child: int = index * 2 + 1
		if child + 1 < last and actual._free_heap[child + 1] < actual._free_heap[child]:
			child += 1
		if actual._free_heap[index] <= actual._free_heap[child]:
			break
		var carried: int = actual._free_heap[index]
		actual._free_heap[index] = actual._free_heap[child]
		actual._free_heap[child] = carried
		index = child
	return smallest


func _push_free(row: int) -> void:
	"""Use the common concrete row kernel without changing ordinary public behavior."""
	_push_free_in(self, row)


static func _push_free_in(actual: RefCounted, row: int) -> void:
	"""Insert a freed row into the min-heap so the next allocation still finds the lowest index."""
	var index: int = actual._free_count
	while index > 0:
		@warning_ignore("integer_division") var parent: int = (index - 1) / 2
		if actual._free_heap[parent] <= row:
			break
		actual._free_heap[index] = actual._free_heap[parent]
		index = parent
	actual._free_heap[index] = row


# --- Intrusive lists --------------------------------------------------------------------------

func _compare_lot_key(row: int, lot_slot: int, lot_generation: int, purpose: int) -> int:
	"""Use the common concrete row kernel without changing ordinary public behavior."""
	return _compare_lot_key_in(self, row, lot_slot, lot_generation, purpose)


static func _compare_lot_key_in(actual: RefCounted, row: int, lot_slot: int, lot_generation: int, purpose: int) -> int:
	"""Order a row against a `(lot, purpose)` key: -1 before, 0 equal, 1 after."""
	if actual._r_lot_slot[row] != lot_slot:
		return -1 if actual._r_lot_slot[row] < lot_slot else 1
	if actual._r_lot_generation[row] != lot_generation:
		return -1 if actual._r_lot_generation[row] < lot_generation else 1
	if actual._r_purpose[row] != purpose:
		return -1 if actual._r_purpose[row] < purpose else 1
	return 0


func _compare_job_key(row: int, job_slot: int, job_generation: int, purpose: int) -> int:
	"""Use the common concrete row kernel without changing ordinary public behavior."""
	return _compare_job_key_in(self, row, job_slot, job_generation, purpose)


static func _compare_job_key_in(actual: RefCounted, row: int, job_slot: int, job_generation: int, purpose: int) -> int:
	"""Order a row against a `(job, purpose)` key: -1 before, 0 equal, 1 after."""
	if actual._r_job_slot[row] != job_slot:
		return -1 if actual._r_job_slot[row] < job_slot else 1
	if actual._r_job_generation[row] != job_generation:
		return -1 if actual._r_job_generation[row] < job_generation else 1
	if actual._r_purpose[row] != purpose:
		return -1 if actual._r_purpose[row] < purpose else 1
	return 0


func _link_job(row: int) -> void:
	"""Use the common concrete row kernel without changing ordinary public behavior."""
	_link_job_in(self, row)


static func _link_job_in(actual: RefCounted, row: int) -> void:
	"""Insert a row into its Job's list, keeping the canonical `(lot, purpose)` order."""
	var head_index: int = actual._r_job_slot[row]
	var cursor: int = actual._job_head[head_index]
	var previous: int = NULL_ROW
	while cursor != NULL_ROW and _compare_lot_key_in(actual, cursor, actual._r_lot_slot[row], actual._r_lot_generation[row], actual._r_purpose[row]) < 0:
		previous = cursor
		cursor = actual._job_next[cursor]
	actual._job_next[row] = cursor
	actual._job_prev[row] = previous
	if cursor != NULL_ROW:
		actual._job_prev[cursor] = row
	if previous == NULL_ROW:
		actual._job_head[head_index] = row
	else:
		actual._job_next[previous] = row


func _link_lot(row: int) -> void:
	"""Use the common concrete row kernel without changing ordinary public behavior."""
	_link_lot_in(self, row)


static func _link_lot_in(actual: RefCounted, row: int) -> void:
	"""Insert a row into its lot's list, keeping the canonical `(job, purpose)` order."""
	var head_index: int = actual._r_lot_slot[row]
	var cursor: int = actual._lot_head[head_index]
	var previous: int = NULL_ROW
	while cursor != NULL_ROW and _compare_job_key_in(actual, cursor, actual._r_job_slot[row], actual._r_job_generation[row], actual._r_purpose[row]) < 0:
		previous = cursor
		cursor = actual._lot_next[cursor]
	actual._lot_next[row] = cursor
	actual._lot_prev[row] = previous
	if cursor != NULL_ROW:
		actual._lot_prev[cursor] = row
	if previous == NULL_ROW:
		actual._lot_head[head_index] = row
	else:
		actual._lot_next[previous] = row


func _unlink_job(row: int) -> void:
	"""Use the common concrete row kernel without changing ordinary public behavior."""
	_unlink_job_in(self, row)


static func _unlink_job_in(actual: RefCounted, row: int) -> void:
	"""Remove a row from its Job's list."""
	var previous: int = actual._job_prev[row]
	var next: int = actual._job_next[row]
	if previous == NULL_ROW:
		actual._job_head[actual._r_job_slot[row]] = next
	else:
		actual._job_next[previous] = next
	if next != NULL_ROW:
		actual._job_prev[next] = previous
	actual._job_prev[row] = NULL_ROW
	actual._job_next[row] = NULL_ROW


func _unlink_lot(row: int) -> void:
	"""Use the common concrete row kernel without changing ordinary public behavior."""
	_unlink_lot_in(self, row)


static func _unlink_lot_in(actual: RefCounted, row: int) -> void:
	"""Remove a row from its lot's list."""
	var previous: int = actual._lot_prev[row]
	var next: int = actual._lot_next[row]
	if previous == NULL_ROW:
		actual._lot_head[actual._r_lot_slot[row]] = next
	else:
		actual._lot_next[previous] = next
	if next != NULL_ROW:
		actual._lot_prev[next] = previous
	actual._lot_prev[row] = NULL_ROW
	actual._lot_next[row] = NULL_ROW


func _find_row(job_ref: Vector2i, lot_ref: Vector2i, purpose: int) -> int:
	"""Use the common concrete row kernel without changing ordinary public behavior."""
	return _find_row_in(self, job_ref, lot_ref, purpose)


static func _find_row_in(actual: RefCounted, job_ref: Vector2i, lot_ref: Vector2i, purpose: int) -> int:
	"""The active row carrying `(job, lot, purpose)`, or NULL_ROW when there is none.

	Walks the Job's list, which is short -- one entry per lot the job has claimed -- and is
	sorted, so the scan stops as soon as it passes the key.
	"""
	if job_ref.x < 0 or job_ref.x >= actual._job_capacity:
		return NULL_ROW
	var row: int = actual._job_head[job_ref.x]
	while row != NULL_ROW:
		var order: int = _compare_lot_key_in(actual, row, lot_ref.x, lot_ref.y, purpose)
		if order > 0:
			return NULL_ROW
		if order == 0 and actual._r_job_generation[row] == job_ref.y:
			return row
		row = actual._job_next[row]
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


func job_reserved_total_milli(job_ref: Vector2i) -> IntMath.IntResult:
	"""Total milli-units claimed by one Job across every lot, as an explicit checked result.

	COLD PATH: allocates exactly one IntResult and delegates to the `_into` form, so the two
	surfaces can never disagree. `.ok` MUST be inspected before `.value`; a job whose claims sum
	past int64 yields an explicit refusal, never a wrapped negative total.

	Each call returns an INDEPENDENT result object holding no reference to owner scratch.
	"""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	job_reserved_total_milli_into(job_ref, out)
	return out


func lot_reserved_total_milli(lot_ref: Vector2i) -> IntMath.IntResult:
	"""Total milli-units claimed against one lot, re-derived from the rows, as a checked result.

	This is the right-hand side of decision 0019's invariant. COLD PATH: allocates exactly one
	IntResult and delegates to the `_into` form.
	"""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	lot_reserved_total_milli_into(lot_ref, out)
	return out


func job_reserved_total_milli_into(job_ref: Vector2i, out: IntMath.IntResult) -> bool:
	"""Non-allocating job_reserved_total_milli(): sum into caller-owned `out`, return out.ok.

	`out` is caller-owned and is ALSO this call's arithmetic scratch, so it must not be a result
	the caller still needs. A null `out` is refused before this touches a head column or any row,
	and no owner field -- canonical, derived, pending or `_math` -- is written on any path.

	A job with no list at all, including an out-of-range or generation-mismatched reference, is a
	total of zero rather than a refusal: `_list_head()` answers NULL_ROW and the traversal ends
	immediately in `out.succeed(0)`, clearing whatever failure `out` carried before.
	"""
	if out == null:
		return false
	return _sum_list_into(_list_head(job_ref, true), true, out)


func lot_reserved_total_milli_into(lot_ref: Vector2i, out: IntMath.IntResult) -> bool:
	"""Non-allocating lot_reserved_total_milli(): sum into caller-owned `out`, return out.ok.

	Same contract as the job form, against the lot list: `out` doubles as scratch, a null `out`
	is refused before any list access, a missing lot list succeeds at zero, and nothing in this
	pool or in any Inventory is mutated.
	"""
	if out == null:
		return false
	return _sum_list_into(_list_head(lot_ref, false), false, out)


func _sum_list_into(head: int, by_job: bool, out: IntMath.IntResult) -> bool:
	"""Checked sum of the claimed quantities along one intrusive list, written into `out`.

	The ONLY summation helper in this module. Traversal order is the list's existing canonical
	order, unchanged; what changes is that every quantity goes through `IntMath.checked_add_into`
	instead of `+=`. Because `out` is the scratch for each step, the running value is copied into
	a local BEFORE the next call, which is the convention every checked caller here already uses.

	Overflow returns false with `out.ok == false`, `out.value == 0` and a non-empty IntMath error,
	so no partial total is ever exposed as a success. An empty list -- head == NULL_ROW -- reaches
	the final `out.succeed(0)` and is an explicit success, not a refusal.
	"""
	if out == null:
		return false
	var total: int = 0
	var row: int = head
	while row != NULL_ROW:
		if not IntMath.checked_add_into(total, _r_quantity_milli[row], out):
			return false
		total = out.value
		row = _job_next[row] if by_job else _lot_next[row]
	return out.succeed(total)


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
	var binding_code: StringName = inventory_binding_refusal(inventory)
	if binding_code != REFUSE_NONE:
		return _refuse(binding_code)
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
	"""Decision 0019's invariant, per lot the pool holds rows for, with a CHECKED sum.

	Fixed order, per lot:
	  1. the existing `is_lot_valid` gate, whose REFUSE_AUDIT_RESERVED_TOTAL precedence over
	     every arithmetic outcome is preserved -- an invalid lot is still reported as such even
	     when its rows would also overflow;
	  2. the checked sum, returning the ALREADY EXISTING REFUSE_OVERFLOW before any comparison,
	     so audit can never compare a wrapped total against a real reserved figure and call a
	     broken world healthy;
	  3. equality against `inventory.reserved_milli`;
	  4. the quantity bound.

	`_math.value` is copied into `total` IMMEDIATELY, before the two further Inventory queries,
	because `_math` is shared scratch and any later checked call would overwrite it.

	This closes one blind spot only. Lots the pool holds no rows for -- including Inventory lots
	reserved by a caller going around this pool -- are still invisible here; that reconciliation
	remains the coordinator's separately documented task, and this change does not claim to fix
	all audit coverage.
	"""
	for slot: int in range(_lot_capacity):
		var head: int = _lot_head[slot]
		if head == NULL_ROW:
			continue
		var lot_ref: Vector2i = Vector2i(slot, _r_lot_generation[head])
		if not inventory.is_lot_valid(lot_ref):
			return REFUSE_AUDIT_RESERVED_TOTAL
		if not _sum_list_into(head, false, _math):
			return REFUSE_OVERFLOW
		var total: int = _math.value
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


func restore_reservation_columns(columns: ReservationColumns, inventory: Inventory = null) -> bool:
	"""Replace this pool's canonical payload and rebuild every derived index, or change nothing.

	A supplied Inventory must match any existing world binding and is remembered only after
	publication. Omitting it preserves the legacy pure-column boundary and all existing wiring;
	an unbound nonempty result cannot compose with Sites until explicitly restored with Inventory.

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
	if _haul_reentry():
		return _refuse_column(HaulContract.REFUSE_REENTRY)
	if not _reservation_record_shape_ok(columns):
		return _refuse_column(COLUMN_RESERVATION_SHAPE)
	if not _reservation_live_shape_ok():
		return _refuse_column(COLUMN_RESERVATION_SOURCE_DERIVED)
	if inventory != null and inventory_binding_refusal(inventory) != REFUSE_NONE:
		return _refuse_column(REFUSE_INVENTORY_BINDING)
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
	if inventory != null:
		_remember_inventory(inventory)
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
		@warning_ignore("integer_division") if index > 0 and _free_heap[(index - 1) / 2] > row:
			return false
	return true
