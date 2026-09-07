extends "res://test/framework/test_case.gd"
## Suite for `scripts/core/reservations.gd` — the global reservation pool of decision 0019.
##
## Covers the five acceptance cases the decision record names: a recipe reserved across five or
## more lots (the case the rejected owner-major `job*4+i` reading would have made impossible),
## exhausting the pool with an explicit refusal and no partial reservations, spoiling a reserved
## lot, replacing a party member, and a deterministic image of the active claims standing in for
## a save format that does not exist yet.
##
## Every case also checks the two things decision 0019 says each acceptance test must preserve:
## OWNERSHIP -- claims stay on the Job that made them, and per decision 0017 a shared claim stays
## on the coordinator when a member leaves -- and INVENTORY TOTALS, through `inventory.audit()`
## and `total_live_milli()`, so no test can pass by quietly destroying or inventing quantity.
##
## Item masses are GDD §5.7 verbatim, matching `test_inventory.gd`.

const ReservationsScript := preload("res://scripts/core/reservations.gd")
const InventoryScript := preload("res://scripts/core/inventory.gd")
const IntMathScript := preload("res://scripts/core/int_math.gd")

const ITEM_GRAIN: int = 0
const ITEM_WOOD: int = 3
const CATEGORY_FOOD: int = 0
const CATEGORY_MATERIAL: int = 3
const BIG_MASS: int = 100000000
## Opaque catalog enum stand-ins, as in `test_inventory.gd`. GDD §4.3 numbers neither container
## policy nor lot provenance, and it numbers no `ReservationPurpose` domain at all, so these are
## arbitrary in-range int32 values chosen by this suite and are NOT catalog IDs.
const TEST_PROVENANCE: int = 3
const TEST_POLICY: int = 0
const PURPOSE_A: int = 0
const PURPOSE_B: int = 1

## Selectors for the audit-corruption test below, which reaches straight into the pool's private
## indexing columns. `const` cannot hold a non-constant expression, so the names are a plain
## `Array[String]` rather than a `PackedStringArray([...])`.
const COL_JOB_HEAD: int = 0
const COL_LOT_HEAD: int = 1
const COL_JOB_PREV: int = 2
const COL_OCCUPIED: int = 3
const COL_FREE_HEAP: int = 4
const COLUMN_NAMES: Array[String] = ["_job_head", "_lot_head", "_job_prev", "_occupied", "_free_heap"]

const OWNER: Vector2i = Vector2i(7, 1)
## Job references. Job liveness lives in the Job store, which this module deliberately does not
## depend on, so these are plain in-range `(slot, generation)` pairs.
const JOB_A: Vector2i = Vector2i(3, 1)
const JOB_B: Vector2i = Vector2i(9, 1)
const COORDINATOR: Vector2i = Vector2i(11, 4)
const MEMBER_ONE: Vector2i = Vector2i(12, 4)
const MEMBER_TWO: Vector2i = Vector2i(13, 4)
const MEMBER_THREE: Vector2i = Vector2i(14, 4)

var _inv: InventoryScript = null
var _pool: ReservationsScript = null
var _container: Vector2i = Vector2i(-1, 0)
var _claims: PackedInt64Array = PackedInt64Array()
var _out: IntMathScript.IntResult = null


func before_each() -> void:
	"""Build a small inventory, a full-capacity pool, and a reusable claim buffer."""
	_inv = _make_inventory()
	_pool = ReservationsScript.new()
	_container = _make_container()
	_claims = PackedInt64Array()
	_claims.resize(32 * ReservationsScript.CLAIM_STRIDE)
	_out = IntMathScript.IntResult.new()


func _make_inventory() -> InventoryScript:
	"""Create an inventory of 8 containers and 64 lots with the test items registered."""
	var inv: InventoryScript = InventoryScript.new(8, 64)
	inv.register_item(ITEM_GRAIN, 250, CATEGORY_FOOD)
	inv.register_item(ITEM_WOOD, 5000, CATEGORY_MATERIAL)
	return inv


func _make_container() -> Vector2i:
	"""Create an accept-everything container in the current inventory."""
	return _inv.create_container(OWNER, BIG_MASS, InventoryScript.FILTERS_ACCEPT_ALL, TEST_POLICY, true).ref


func _lot(quantity_milli: int, item_id: int = ITEM_GRAIN) -> Vector2i:
	"""Create one lot of the given quantity in the shared container."""
	return _inv.create_lot(_container, item_id, quantity_milli, 0, TEST_PROVENANCE, 0, 0, 0).ref


func _write_claim(index: int, lot_ref: Vector2i, purpose: int, quantity_milli: int, expiry: int) -> void:
	"""Write one claim record into the reusable batch buffer."""
	var base: int = index * ReservationsScript.CLAIM_STRIDE
	_claims[base + ReservationsScript.CLAIM_LOT_SLOT] = lot_ref.x
	_claims[base + ReservationsScript.CLAIM_LOT_GENERATION] = lot_ref.y
	_claims[base + ReservationsScript.CLAIM_PURPOSE] = purpose
	_claims[base + ReservationsScript.CLAIM_QUANTITY_MILLI] = quantity_milli
	_claims[base + ReservationsScript.CLAIM_EXPIRY] = expiry


func _claim_one(job_ref: Vector2i, lot_ref: Vector2i, quantity_milli: int, purpose: int = PURPOSE_A, expiry: int = 300) -> InventoryScript.OpResult:
	"""Submit a single-record batch and return its result."""
	_write_claim(0, lot_ref, purpose, quantity_milli, expiry)
	return _pool.claim_batch(job_ref, _claims, 1, _inv)


func _make_lots(count: int, quantity_milli: int) -> Array[Vector2i]:
	"""Create `count` identical lots and return their refs in creation order."""
	var lots: Array[Vector2i] = []
	for index: int in range(count):
		lots.append(_lot(quantity_milli))
	return lots


func _total_reserved(lots: Array[Vector2i]) -> int:
	"""Sum of `reserved_milli` across a group of lots, read from the inventory."""
	var total: int = 0
	for lot_ref: Vector2i in lots:
		total += _inv.lot_reserved_milli(lot_ref)
	return total


func _assert_pool_and_inventory_sound(context: String) -> void:
	"""Both audits must pass: the pool's invariant and the inventory's own conservation."""
	var pool_audit: InventoryScript.OpResult = _pool.audit(_inv)
	assert_true(pool_audit.ok, "%s: pool audit (%s)" % [context, pool_audit.error])
	var inv_audit: InventoryScript.OpResult = _inv.audit()
	assert_true(inv_audit.ok, "%s: inventory audit (%s)" % [context, inv_audit.error])


# --- Allocation ledger ------------------------------------------------------------------------

func test_indexing_allocation_matches_the_decision_0019_budget() -> void:
	"""The packed layout must cost exactly the 786,436 indexing bytes decision 0019 budgets."""
	assert_equal(_pool.indexing_bytes(), 786436, "indexing bytes")
	assert_equal(_pool.indexing_bytes(), ReservationsScript.BUDGET_INDEXING_BYTES, "indexing matches the published budget")
	assert_equal(_pool.payload_bytes(), 1179648, "reservation payload bytes")
	assert_equal(_pool.payload_bytes(), ReservationsScript.BUDGET_PAYLOAD_BYTES, "payload matches the published budget")
	assert_equal(_pool.row_capacity(), 32768, "rows")
	assert_equal(_pool.job_capacity(), 8192, "job heads")
	assert_equal(_pool.lot_capacity(), 16384, "lot heads")
	assert_equal(_pool.free_row_count(), 32768, "every row starts free")
	assert_equal(_pool.active_row_count(), 0, "no row starts active")


func test_capacity_requests_are_clamped_to_the_specified_maxima() -> void:
	"""A larger request is clamped down; the memory ledger fixes the maxima."""
	var big: ReservationsScript = ReservationsScript.new(999999, 999999, 999999)
	assert_equal(big.row_capacity(), 32768, "rows clamp to 32768")
	assert_equal(big.job_capacity(), 8192, "job heads clamp to 8192")
	assert_equal(big.lot_capacity(), 16384, "lot heads clamp to 16384")
	var small: ReservationsScript = ReservationsScript.new(4, 16, 32)
	assert_equal(small.row_capacity(), 4, "a smaller pool is honoured")
	assert_equal(small.free_row_count(), 4, "a smaller pool starts fully free")
	assert_true(small.indexing_bytes() < big.indexing_bytes(), "a smaller pool costs fewer bytes")


# --- Acceptance: a recipe across five or more lots ---------------------------------------------

func test_recipe_reserves_across_five_or_more_lots() -> void:
	"""Decision 0019's headline case: one Job claiming SEVEN lots in one batch.

	The rejected owner-major `job*4+i` reading made this impossible, so the assertion that
	matters most is `job_claim_count > 4` with every claim actually reserved.
	"""
	var lots: Array[Vector2i] = _make_lots(7, 1000)
	for index: int in range(7):
		_write_claim(index, lots[index], PURPOSE_A, 600, 300)
	var result: InventoryScript.OpResult = _pool.claim_batch(JOB_A, _claims, 7, _inv)
	assert_true(result.ok, "seven-lot batch is accepted (%s)" % result.error)
	assert_equal(result.value, 7, "seven fresh rows consumed")
	assert_equal(_pool.job_claim_count(JOB_A), 7, "the job holds seven claims")
	assert_true(_pool.job_claim_count(JOB_A) > 4, "more than four lots per job, which is the point of decision 0019")
	for lot_ref: Vector2i in lots:
		assert_equal(_inv.lot_reserved_milli(lot_ref), 600, "each lot is reserved")
		assert_equal(_inv.lot_available_milli(lot_ref), 400, "each lot keeps its remainder available")
	assert_equal(_pool.job_reserved_total_milli(JOB_A), 4200, "job total")
	assert_equal(_inv.total_live_milli(ITEM_GRAIN), 7000, "reserving moves no quantity")
	_assert_pool_and_inventory_sound("seven-lot recipe")


func test_one_job_may_claim_far_more_lots_than_four() -> void:
	"""Twelve lots on one Job, allocated from the GLOBAL pool rather than a per-job window."""
	var lots: Array[Vector2i] = _make_lots(12, 500)
	for index: int in range(12):
		_write_claim(index, lots[index], PURPOSE_A, 500, 300)
	var result: InventoryScript.OpResult = _pool.claim_batch(JOB_B, _claims, 12, _inv)
	assert_true(result.ok, "twelve-lot batch is accepted (%s)" % result.error)
	assert_equal(_pool.job_claim_count(JOB_B), 12, "twelve claims on one job")
	assert_equal(_pool.active_row_count(), 12, "twelve pool rows")
	for index: int in range(12):
		var row: int = _pool.first_lot_row(lots[index])
		assert_true(row >= 0 and row < 12, "row %d is a low global index, not job_slot*4+i" % row)
	assert_equal(_pool.free_row_count(), 32756, "the global free count dropped by twelve")
	_assert_pool_and_inventory_sound("twelve-lot job")


func test_job_list_is_iterated_in_canonical_lot_order() -> void:
	"""A job's rows read back in ascending lot order however the claims arrived."""
	var lots: Array[Vector2i] = _make_lots(5, 1000)
	for index: int in range(5):
		_write_claim(index, lots[4 - index], PURPOSE_A, 100, 300)
	assert_true(_pool.claim_batch(JOB_A, _claims, 5, _inv).ok, "descending batch accepted")
	var previous: int = -1
	var seen: int = 0
	var row: int = _pool.first_job_row(JOB_A)
	while row != ReservationsScript.NULL_ROW:
		var lot_slot: int = _pool.row_lot_ref(row).x
		assert_true(lot_slot > previous, "lot slot %d follows %d in ascending order" % [lot_slot, previous])
		previous = lot_slot
		seen += 1
		row = _pool.next_job_row(row)
	assert_equal(seen, 5, "every claim is reachable from the job head")


# --- Lowest-free-index allocation ---------------------------------------------------------------

func test_rows_come_from_the_lowest_free_index() -> void:
	"""Decision 0019 allocates from the LOWEST free index, so freed low rows are reused first."""
	var lots: Array[Vector2i] = _make_lots(8, 1000)
	for index: int in range(6):
		assert_true(_claim_one(JOB_A, lots[index], 100).ok, "claim %d accepted" % index)
	for index: int in range(6):
		assert_equal(_pool.first_lot_row(lots[index]), index, "claim %d took row %d" % [index, index])
	assert_true(_pool.release_claim(JOB_A, lots[3], PURPOSE_A, _inv).ok, "row 3 released")
	assert_true(_pool.release_claim(JOB_A, lots[1], PURPOSE_A, _inv).ok, "row 1 released")
	assert_true(_claim_one(JOB_A, lots[6], 100).ok, "next claim accepted")
	assert_equal(_pool.first_lot_row(lots[6]), 1, "the lowest free row (1) is reused before 3")
	assert_true(_claim_one(JOB_A, lots[7], 100).ok, "further claim accepted")
	assert_equal(_pool.first_lot_row(lots[7]), 3, "row 3 follows")
	_assert_pool_and_inventory_sound("lowest free index")


func test_freed_rows_return_to_the_pool() -> void:
	"""Releasing a claim gives its row back and leaves no reserved residue."""
	var lot_ref: Vector2i = _lot(1000)
	assert_true(_claim_one(JOB_A, lot_ref, 750).ok, "claim accepted")
	assert_equal(_pool.free_row_count(), 32767, "one row taken")
	assert_equal(_inv.lot_reserved_milli(lot_ref), 750, "lot reserved")
	var released: InventoryScript.OpResult = _pool.release_claim(JOB_A, lot_ref, PURPOSE_A, _inv)
	assert_true(released.ok, "release accepted")
	assert_equal(released.value, 750, "the released quantity is reported")
	assert_equal(_pool.free_row_count(), 32768, "the row returned")
	assert_equal(_pool.active_row_count(), 0, "no active rows remain")
	assert_equal(_inv.lot_reserved_milli(lot_ref), 0, "nothing stays reserved")
	assert_equal(_inv.total_live_milli(ITEM_GRAIN), 1000, "quantity is untouched by a release")
	_assert_pool_and_inventory_sound("release")


func test_clear_returns_every_row_to_the_pool() -> void:
	"""`clear()` is a world teardown: rows go back, and no column is reallocated."""
	var lots: Array[Vector2i] = _make_lots(3, 1000)
	for lot_ref: Vector2i in lots:
		assert_true(_claim_one(JOB_A, lot_ref, 100).ok, "claim accepted")
	assert_equal(_pool.active_row_count(), 3, "three rows before clear")
	_pool.clear()
	assert_equal(_pool.active_row_count(), 0, "no rows after clear")
	assert_equal(_pool.free_row_count(), 32768, "every row is free again")
	assert_equal(_pool.job_claim_count(JOB_A), 0, "the job list is empty")
	assert_equal(_pool.indexing_bytes(), 786436, "clear reallocates nothing")


# --- Coalescing -------------------------------------------------------------------------------

func test_identical_job_lot_purpose_claims_coalesce_into_one_row() -> void:
	"""Decision 0019's coalescing rule, both within one batch and across two batches."""
	var lot_ref: Vector2i = _lot(1000)
	_write_claim(0, lot_ref, PURPOSE_A, 200, 300)
	_write_claim(1, lot_ref, PURPOSE_A, 300, 300)
	var result: InventoryScript.OpResult = _pool.claim_batch(JOB_A, _claims, 2, _inv)
	assert_true(result.ok, "duplicate-key batch accepted (%s)" % result.error)
	assert_equal(result.value, 1, "only ONE fresh row for two identical claims")
	assert_equal(_pool.active_row_count(), 1, "one active row")
	assert_equal(_pool.claim_quantity_milli(JOB_A, lot_ref, PURPOSE_A), 500, "quantities added")
	assert_equal(_inv.lot_reserved_milli(lot_ref), 500, "the lot carries both claims")
	var second: InventoryScript.OpResult = _claim_one(JOB_A, lot_ref, 250)
	assert_true(second.ok, "later batch accepted")
	assert_equal(second.value, 0, "no fresh row was needed")
	assert_equal(_pool.active_row_count(), 1, "still one row")
	assert_equal(_pool.claim_quantity_milli(JOB_A, lot_ref, PURPOSE_A), 750, "the row absorbed the third claim")
	assert_equal(_inv.lot_reserved_milli(lot_ref), 750, "reserved tracks the coalesced row")
	_assert_pool_and_inventory_sound("coalescing")


func test_a_different_purpose_or_job_gets_its_own_row() -> void:
	"""The coalescing key is the whole triple: change any part of it and a new row appears."""
	var lot_ref: Vector2i = _lot(1000)
	assert_true(_claim_one(JOB_A, lot_ref, 200, PURPOSE_A).ok, "purpose A accepted")
	assert_true(_claim_one(JOB_A, lot_ref, 300, PURPOSE_B).ok, "purpose B accepted")
	assert_true(_claim_one(JOB_B, lot_ref, 400, PURPOSE_A).ok, "other job accepted")
	assert_equal(_pool.active_row_count(), 3, "three distinct rows")
	assert_equal(_pool.claim_quantity_milli(JOB_A, lot_ref, PURPOSE_A), 200, "purpose A is separate")
	assert_equal(_pool.claim_quantity_milli(JOB_A, lot_ref, PURPOSE_B), 300, "purpose B is separate")
	assert_equal(_pool.claim_quantity_milli(JOB_B, lot_ref, PURPOSE_A), 400, "the other job is separate")
	assert_equal(_pool.lot_claim_count(lot_ref), 3, "the lot lists all three")
	assert_equal(_inv.lot_reserved_milli(lot_ref), 900, "reserved is the sum of all three")
	assert_equal(_pool.lot_reserved_total_milli(lot_ref), 900, "the pool re-derives the same sum")
	_assert_pool_and_inventory_sound("distinct keys")


func test_coalescing_keeps_the_later_expiry_and_never_the_earlier() -> void:
	"""An unresolved point resolved in the module: a coalesced row can only be extended."""
	var lot_ref: Vector2i = _lot(1000)
	assert_true(_claim_one(JOB_A, lot_ref, 100, PURPOSE_A, 400).ok, "first claim accepted")
	assert_true(_claim_one(JOB_A, lot_ref, 100, PURPOSE_A, 50).ok, "earlier-expiry claim accepted")
	assert_true(_pool.claim_expiry_into(JOB_A, lot_ref, PURPOSE_A, _out), "expiry readable")
	assert_equal(_out.value, 400, "the earlier expiry did not shorten the lease")
	assert_true(_claim_one(JOB_A, lot_ref, 100, PURPOSE_A, 900).ok, "later-expiry claim accepted")
	assert_true(_pool.claim_expiry_into(JOB_A, lot_ref, PURPOSE_A, _out), "expiry readable again")
	assert_equal(_out.value, 900, "the later expiry extended the lease")
	assert_equal(_pool.claim_quantity_milli(JOB_A, lot_ref, PURPOSE_A), 300, "all three quantities coalesced")


# --- Acceptance: exhausting the pool ------------------------------------------------------------

func test_pool_exhaustion_refuses_explicitly_with_no_partial_reservations() -> void:
	"""Decision 0019's capacity case: too few rows refuses the WHOLE batch and reserves nothing."""
	_pool = ReservationsScript.new(3, 64, 64)
	var lots: Array[Vector2i] = _make_lots(4, 1000)
	for index: int in range(4):
		_write_claim(index, lots[index], PURPOSE_A, 500, 300)
	var before: PackedByteArray = _pool.state_bytes()
	var result: InventoryScript.OpResult = _pool.claim_batch(JOB_A, _claims, 4, _inv)
	assert_false(result.ok, "a four-row batch against a three-row pool is refused")
	assert_equal(result.error, ReservationsScript.REFUSE_CAPACITY_RESERVATION, "the refusal is explicit")
	assert_equal(result.value, 0, "a refusal carries no value")
	assert_equal(_pool.active_row_count(), 0, "not one partial row was written")
	assert_equal(_pool.free_row_count(), 3, "the free count is untouched")
	assert_equal(_total_reserved(lots), 0, "not one milli-unit was reserved")
	assert_equal(_pool.state_bytes(), before, "the pool image is byte-identical to before the refusal")
	assert_equal(_inv.total_live_milli(ITEM_GRAIN), 4000, "inventory totals are untouched")
	_assert_pool_and_inventory_sound("capacity refusal")


func test_a_full_pool_still_accepts_a_batch_that_only_coalesces() -> void:
	"""Coalesced claims need no fresh row, so a full pool must not refuse them."""
	_pool = ReservationsScript.new(1, 64, 64)
	var lot_ref: Vector2i = _lot(1000)
	assert_true(_claim_one(JOB_A, lot_ref, 100).ok, "the single row is taken")
	assert_equal(_pool.free_row_count(), 0, "the pool is now full")
	var coalescing: InventoryScript.OpResult = _claim_one(JOB_A, lot_ref, 200)
	assert_true(coalescing.ok, "a coalescing claim needs no row (%s)" % coalescing.error)
	assert_equal(coalescing.value, 0, "no fresh row consumed")
	assert_equal(_inv.lot_reserved_milli(lot_ref), 300, "the coalesced quantity landed")
	var fresh: InventoryScript.OpResult = _claim_one(JOB_A, _lot(1000), 100)
	assert_false(fresh.ok, "a claim needing a fresh row is refused")
	assert_equal(fresh.error, ReservationsScript.REFUSE_CAPACITY_RESERVATION, "capacity refusal")
	_assert_pool_and_inventory_sound("full pool")


func test_a_batch_that_outruns_one_lot_reserves_nothing() -> void:
	"""Per-lot availability is checked against the batch TOTAL, not one record at a time."""
	var lot_ref: Vector2i = _lot(1000)
	var other: Vector2i = _lot(1000)
	_write_claim(0, other, PURPOSE_A, 400, 300)
	_write_claim(1, lot_ref, PURPOSE_A, 600, 300)
	_write_claim(2, lot_ref, PURPOSE_B, 600, 300)
	var result: InventoryScript.OpResult = _pool.claim_batch(JOB_A, _claims, 3, _inv)
	assert_false(result.ok, "600 + 600 against a 1000 lot is refused even though each fits alone")
	assert_equal(result.error, ReservationsScript.REFUSE_INSUFFICIENT_UNRESERVED, "explicit refusal")
	assert_equal(_pool.active_row_count(), 0, "no row was written")
	assert_equal(_inv.lot_reserved_milli(lot_ref), 0, "the overrun lot is untouched")
	assert_equal(_inv.lot_reserved_milli(other), 0, "the innocent lot in the same batch is untouched too")
	_assert_pool_and_inventory_sound("per-lot overrun")


func test_an_invalid_lot_anywhere_in_the_batch_voids_the_whole_batch() -> void:
	"""One stale reference among four good ones reserves nothing at all."""
	var lots: Array[Vector2i] = _make_lots(4, 1000)
	for index: int in range(4):
		_write_claim(index, lots[index], PURPOSE_A, 250, 300)
	_write_claim(4, Vector2i(lots[0].x, lots[0].y + 7), PURPOSE_A, 250, 300)
	var stale_generation: InventoryScript.OpResult = _pool.claim_batch(JOB_A, _claims, 5, _inv)
	assert_false(stale_generation.ok, "a stale generation on a live slot refuses the batch")
	assert_equal(stale_generation.error, ReservationsScript.REFUSE_INVALID_LOT, "explicit refusal")
	# A slot that was never allocated, so the refusal cannot come from an unrelated check that
	# happens to trip on the live sibling record sharing its slot.
	_write_claim(4, Vector2i(60, 1), PURPOSE_A, 250, 300)
	var never_lived: InventoryScript.OpResult = _pool.claim_batch(JOB_A, _claims, 5, _inv)
	assert_false(never_lived.ok, "a reference to an empty lot slot refuses the batch")
	assert_equal(never_lived.error, ReservationsScript.REFUSE_INVALID_LOT, "explicit refusal")
	assert_equal(_pool.active_row_count(), 0, "no rows")
	assert_equal(_total_reserved(lots), 0, "the four valid lots were not reserved")
	_assert_pool_and_inventory_sound("stale ref in batch")


# --- The invariant -----------------------------------------------------------------------------

func test_reserved_milli_equals_the_sum_of_active_rows() -> void:
	"""Decision 0019's invariant across several claimants on one lot, before and after a release."""
	var lot_ref: Vector2i = _lot(2000)
	assert_true(_claim_one(JOB_A, lot_ref, 300, PURPOSE_A).ok, "claim A accepted")
	assert_true(_claim_one(JOB_B, lot_ref, 500, PURPOSE_A).ok, "claim B accepted")
	assert_true(_claim_one(JOB_B, lot_ref, 200, PURPOSE_B).ok, "claim B/other purpose accepted")
	assert_equal(_pool.lot_reserved_total_milli(lot_ref), 1000, "rows sum to 1000")
	assert_equal(_inv.lot_reserved_milli(lot_ref), 1000, "inventory agrees")
	assert_true(_inv.lot_reserved_milli(lot_ref) <= _inv.lot_quantity_milli(lot_ref), "reserved never exceeds quantity")
	assert_true(_pool.release_claim(JOB_B, lot_ref, PURPOSE_A, _inv).ok, "one claim released")
	assert_equal(_pool.lot_reserved_total_milli(lot_ref), 500, "rows sum to 500")
	assert_equal(_inv.lot_reserved_milli(lot_ref), 500, "inventory agrees after the release")
	_assert_pool_and_inventory_sound("multi-claimant invariant")


func test_audit_catches_a_reserved_total_that_drifts() -> void:
	"""Reserving behind the pool's back must be caught, or the invariant is unenforced."""
	var lot_ref: Vector2i = _lot(2000)
	assert_true(_claim_one(JOB_A, lot_ref, 300).ok, "claim accepted")
	assert_true(_pool.audit(_inv).ok, "healthy before the drift")
	assert_true(_inv.reserve_lot(lot_ref, 100).ok, "a caller reserves round the pool")
	var drifted: InventoryScript.OpResult = _pool.audit(_inv)
	assert_false(drifted.ok, "the audit refuses a reserved total the rows do not account for")
	assert_equal(drifted.error, ReservationsScript.REFUSE_AUDIT_RESERVED_TOTAL, "explicit audit code")
	assert_true(_inv.release_reservation(lot_ref, 100).ok, "undo the drift")
	assert_true(_pool.audit(_inv).ok, "healthy again once the totals agree")


func test_audit_reports_a_healthy_pool_and_counts_its_rows() -> void:
	"""A clean pool audits green and reports how many rows it holds."""
	var lots: Array[Vector2i] = _make_lots(5, 1000)
	for lot_ref: Vector2i in lots:
		assert_true(_claim_one(JOB_A, lot_ref, 100).ok, "claim accepted")
		assert_true(_claim_one(JOB_B, lot_ref, 100).ok, "second claimant accepted")
	var result: InventoryScript.OpResult = _pool.audit(_inv)
	assert_true(result.ok, "audit green (%s)" % result.error)
	assert_equal(result.value, 10, "ten rows counted")
	assert_equal(_pool.audit(null).ok, false, "a null inventory is refused, not crashed through")
	assert_equal(_pool.audit(null).error, ReservationsScript.REFUSE_NO_INVENTORY, "explicit refusal")


func test_audit_bites_on_structural_corruption() -> void:
	"""Every structural branch of `audit()` must refuse when the thing it checks is broken.

	The public API cannot produce these states while the module is correct, so -- exactly as
	`test_inventory.gd` does for its own audit -- the columns are corrupted directly and restored
	immediately. Without this the branches are unreachable code that no test could distinguish
	from `return REFUSE_NONE`.
	"""
	var lots: Array[Vector2i] = _make_lots(3, 1000)
	for lot_ref: Vector2i in lots:
		assert_true(_claim_one(JOB_A, lot_ref, 100).ok, "job A claim accepted")
	assert_true(_claim_one(JOB_B, lots[0], 200).ok, "job B claim accepted")
	assert_true(_pool.audit(_inv).ok, "healthy to start with")
	_assert_audit_refuses_while_corrupted(lots)


func _assert_audit_refuses_while_corrupted(lots: Array[Vector2i]) -> void:
	"""Break one column at a time, assert the matching audit code, and restore it."""
	var head: int = _pool.first_job_row(JOB_A)
	var second: int = _pool.next_job_row(head)
	_check_corruption(COL_JOB_HEAD, JOB_A.x, ReservationsScript.NULL_ROW, ReservationsScript.REFUSE_AUDIT_JOB_LIST)
	_check_corruption(COL_LOT_HEAD, lots[1].x, ReservationsScript.NULL_ROW, ReservationsScript.REFUSE_AUDIT_LOT_LIST)
	_check_corruption(COL_JOB_PREV, second, 7, ReservationsScript.REFUSE_AUDIT_JOB_LIST)
	_check_corruption(COL_OCCUPIED, head, 0, ReservationsScript.REFUSE_AUDIT_OCCUPANCY)
	_check_corruption(COL_FREE_HEAP, 0, head, ReservationsScript.REFUSE_AUDIT_HEAP)
	_assert_audit_bounds_reserved_by_quantity(head, lots[0])


func _assert_audit_bounds_reserved_by_quantity(row: int, lot_ref: Vector2i) -> void:
	"""`sum(rows) <= quantity` is the second half of the invariant and needs its own corruption.

	Moving the pool row and the inventory total together keeps the equality check happy, so the
	bound is the only thing that can still refuse -- which is exactly what must be proved.
	"""
	var overrun: int = _inv.lot_quantity_milli(lot_ref) * 2
	_pool._r_quantity_milli[row] += overrun
	_inv._l_reserved_milli[lot_ref.x] += overrun
	var result: InventoryScript.OpResult = _pool.audit(_inv)
	assert_false(result.ok, "audit refuses a claimed total larger than the lot holds")
	assert_equal(result.error, ReservationsScript.REFUSE_AUDIT_RESERVED_EXCEEDS, "the refusal names the bound")
	_pool._r_quantity_milli[row] -= overrun
	_inv._l_reserved_milli[lot_ref.x] -= overrun
	assert_true(_pool.audit(_inv).ok, "healthy again once the totals are restored")


func test_a_release_refuses_when_the_inventory_no_longer_covers_the_rows() -> void:
	"""A whole-list release proves every row is covered BEFORE it releases any of them."""
	var lots: Array[Vector2i] = _make_lots(2, 1000)
	for lot_ref: Vector2i in lots:
		assert_true(_claim_one(JOB_A, lot_ref, 400).ok, "claim accepted")
	var drifted: int = _inv.lot_reserved_milli(lots[1])
	_inv._l_reserved_milli[lots[1].x] = 0
	var result: InventoryScript.OpResult = _pool.release_job_claims(JOB_A, _inv)
	assert_false(result.ok, "a release that cannot be covered is refused")
	assert_equal(result.error, ReservationsScript.REFUSE_AUDIT_RESERVED_TOTAL, "the refusal names the drift")
	assert_equal(_pool.job_claim_count(JOB_A), 2, "not one row was released")
	assert_equal(_inv.lot_reserved_milli(lots[0]), 400, "the coverable lot was not touched either")
	_inv._l_reserved_milli[lots[1].x] = drifted
	var repeated: InventoryScript.OpResult = _pool.release_job_claims(JOB_A, _inv)
	assert_true(repeated.ok, "the same release succeeds once the drift is gone")
	assert_equal(repeated.value, 2, "both rows released")
	_assert_pool_and_inventory_sound("release after drift")


func test_a_claim_is_never_found_under_the_wrong_job_generation() -> void:
	"""Generation is part of the key: the next Job to occupy a slot inherits nothing."""
	var lot_ref: Vector2i = _lot(1000)
	assert_true(_claim_one(JOB_A, lot_ref, 250).ok, "generation 1 claims")
	var next_generation: Vector2i = Vector2i(JOB_A.x, JOB_A.y + 1)
	assert_true(_pool.has_claim(JOB_A, lot_ref, PURPOSE_A), "the claiming generation finds it")
	assert_false(_pool.has_claim(next_generation, lot_ref, PURPOSE_A), "the next generation does not")
	assert_equal(_pool.claim_quantity_milli(next_generation, lot_ref, PURPOSE_A), 0, "nor does it inherit the quantity")
	assert_false(_pool.claim_expiry_into(next_generation, lot_ref, PURPOSE_A, _out), "nor the lease")
	var stolen: InventoryScript.OpResult = _pool.release_claim(next_generation, lot_ref, PURPOSE_A, _inv)
	assert_false(stolen.ok, "the next generation cannot release it")
	assert_equal(stolen.error, ReservationsScript.REFUSE_NO_SUCH_CLAIM, "explicit refusal")
	var renewed: InventoryScript.OpResult = _pool.renew_claim(next_generation, lot_ref, PURPOSE_A, 9000)
	assert_equal(renewed.error, ReservationsScript.REFUSE_NO_SUCH_CLAIM, "nor renew it")
	assert_equal(_inv.lot_reserved_milli(lot_ref), 250, "the real claim is untouched")


func _check_corruption(column: int, index: int, broken: int, expected: StringName) -> void:
	"""Write `broken` into one indexing column, assert the audit code, then put it back."""
	var original: int = _read_column(column, index)
	_write_column(column, index, broken)
	var result: InventoryScript.OpResult = _pool.audit(_inv)
	assert_false(result.ok, "audit refuses a broken %s" % COLUMN_NAMES[column])
	assert_equal(result.error, expected, "the refusal names the %s invariant" % COLUMN_NAMES[column])
	_write_column(column, index, original)
	assert_true(_pool.audit(_inv).ok, "healthy again once %s is restored" % COLUMN_NAMES[column])


func _read_column(column: int, index: int) -> int:
	"""Read one entry of a private indexing column, by direct member access."""
	if column == COL_JOB_HEAD:
		return _pool._job_head[index]
	if column == COL_LOT_HEAD:
		return _pool._lot_head[index]
	if column == COL_JOB_PREV:
		return _pool._job_prev[index]
	if column == COL_OCCUPIED:
		return _pool._occupied[index]
	return _pool._free_heap[index]


func _write_column(column: int, index: int, value: int) -> void:
	"""Write one entry of a private indexing column in place, by direct member access."""
	if column == COL_JOB_HEAD:
		_pool._job_head[index] = value
	elif column == COL_LOT_HEAD:
		_pool._lot_head[index] = value
	elif column == COL_JOB_PREV:
		_pool._job_prev[index] = value
	elif column == COL_OCCUPIED:
		_pool._occupied[index] = value
	else:
		_pool._free_heap[index] = value


# --- Acceptance: spoiling a reserved lot --------------------------------------------------------

func test_spoiling_a_reserved_lot_releases_every_claim_in_stable_order() -> void:
	"""GDD §5.8: a spoiling lot invalidates its reservations in a stable order, losing nothing."""
	var lot_ref: Vector2i = _lot(3000)
	var bystander: Vector2i = _lot(1000)
	# Claimed 3, then 11, then 9 on purpose: neither insertion order nor its reverse is the
	# canonical order, so a list that merely preserved arrival order would be caught here.
	assert_true(_claim_one(JOB_A, lot_ref, 600).ok, "job slot 3 claims first")
	assert_true(_claim_one(COORDINATOR, lot_ref, 400).ok, "job slot 11 claims second")
	assert_true(_claim_one(JOB_B, lot_ref, 500).ok, "job slot 9 claims third")
	assert_true(_claim_one(JOB_A, bystander, 250).ok, "an unrelated lot is claimed")
	var previous: int = -1
	var row: int = _pool.first_lot_row(lot_ref)
	while row != ReservationsScript.NULL_ROW:
		assert_true(_pool.row_job_ref(row).x > previous, "the lot list is in ascending job order")
		previous = _pool.row_job_ref(row).x
		row = _pool.next_lot_row(row)
	var released: InventoryScript.OpResult = _pool.release_lot_claims(lot_ref, _inv)
	assert_true(released.ok, "the spoiling lot's claims release (%s)" % released.error)
	assert_equal(released.value, 3, "all three claims released")
	assert_equal(_inv.lot_reserved_milli(lot_ref), 0, "nothing stays reserved on the spoiled lot")
	assert_equal(_inv.lot_quantity_milli(lot_ref), 3000, "releasing destroys no quantity")
	assert_equal(_pool.job_claim_count(JOB_A), 1, "the job keeps its unrelated claim")
	assert_equal(_inv.lot_reserved_milli(bystander), 250, "the bystander lot is untouched")
	_assert_pool_and_inventory_sound("spoilage release")


func test_a_lot_consumed_to_nothing_leaves_droppable_rows() -> void:
	"""A lot that retires under its claim can only be cleaned up through the explicit drop path."""
	var lot_ref: Vector2i = _lot(1000)
	assert_true(_claim_one(JOB_A, lot_ref, 1000).ok, "the whole lot is claimed")
	var still_live: InventoryScript.OpResult = _pool.drop_retired_lot_claims(lot_ref, _inv)
	assert_false(still_live.ok, "dropping rows for a LIVE lot is refused")
	assert_equal(still_live.error, ReservationsScript.REFUSE_LOT_STILL_LIVE, "explicit refusal")
	assert_true(_inv.consume_reserved(lot_ref, 1000).ok, "the reserved quantity is consumed")
	assert_false(_inv.is_lot_valid(lot_ref), "the emptied lot retired")
	var stuck: InventoryScript.OpResult = _pool.release_claim(JOB_A, lot_ref, PURPOSE_A, _inv)
	assert_false(stuck.ok, "a retired lot cannot be released through the normal path")
	assert_equal(stuck.error, ReservationsScript.REFUSE_INVALID_LOT, "explicit refusal")
	var dropped: InventoryScript.OpResult = _pool.drop_retired_lot_claims(lot_ref, _inv)
	assert_true(dropped.ok, "the retired lot's rows drop")
	assert_equal(dropped.value, 1, "one row dropped")
	assert_equal(_pool.active_row_count(), 0, "the pool is clean")
	assert_equal(_inv.total_sunk_milli(ITEM_GRAIN), 1000, "the consumption is accounted as a sink")
	_assert_pool_and_inventory_sound("retired lot")


# --- Acceptance: replacing a party member -------------------------------------------------------

func test_replacing_a_party_member_leaves_the_coordinator_claims_intact() -> void:
	"""Decision 0017: shared claims live on the coordinator, so a member swap cannot move them."""
	var shared: Array[Vector2i] = _make_lots(3, 1000)
	for index: int in range(3):
		_write_claim(index, shared[index], PURPOSE_A, 700, 300)
	assert_true(_pool.claim_batch(COORDINATOR, _claims, 3, _inv).ok, "coordinator claims the shared inputs")
	var tool_one: Vector2i = _lot(1000, ITEM_WOOD)
	var tool_two: Vector2i = _lot(1000, ITEM_WOOD)
	assert_true(_claim_one(MEMBER_ONE, tool_one, 500).ok, "member one holds a personal claim")
	assert_true(_claim_one(MEMBER_TWO, tool_two, 500).ok, "member two holds a personal claim")
	var departed: InventoryScript.OpResult = _pool.release_job_claims(MEMBER_ONE, _inv)
	assert_true(departed.ok, "the departing member's claims release (%s)" % departed.error)
	assert_equal(departed.value, 1, "only the member's own row went")
	assert_equal(_pool.job_claim_count(COORDINATOR), 3, "the coordinator still holds all three shared claims")
	assert_equal(_pool.job_reserved_total_milli(COORDINATOR), 2100, "the shared quantity is unchanged")
	assert_equal(_total_reserved(shared), 2100, "the shared lots are still reserved")
	assert_equal(_inv.lot_reserved_milli(tool_one), 0, "the departing member's own claim is gone")
	assert_equal(_inv.lot_reserved_milli(tool_two), 500, "the remaining member keeps theirs")
	assert_true(_claim_one(MEMBER_THREE, tool_one, 500).ok, "the replacement takes a personal claim")
	assert_equal(_pool.job_claim_count(COORDINATOR), 3, "the replacement changed nothing shared")
	assert_equal(_inv.total_live_milli(ITEM_WOOD), 2000, "no wood was created or destroyed")
	_assert_pool_and_inventory_sound("member replacement")


func test_cancelling_the_coordinator_releases_only_the_shared_claims() -> void:
	"""The other half of decision 0017: the coordinator's cancellation leaves members alone."""
	var shared: Array[Vector2i] = _make_lots(2, 1000)
	for index: int in range(2):
		_write_claim(index, shared[index], PURPOSE_A, 400, 300)
	assert_true(_pool.claim_batch(COORDINATOR, _claims, 2, _inv).ok, "coordinator claims accepted")
	var personal: Vector2i = _lot(1000, ITEM_WOOD)
	assert_true(_claim_one(MEMBER_ONE, personal, 300).ok, "member claim accepted")
	var cancelled: InventoryScript.OpResult = _pool.release_job_claims(COORDINATOR, _inv)
	assert_true(cancelled.ok, "coordinator release accepted")
	assert_equal(cancelled.value, 2, "both shared rows released")
	assert_equal(_total_reserved(shared), 0, "the shared lots are free again")
	assert_equal(_pool.job_claim_count(MEMBER_ONE), 1, "the member keeps their own claim")
	assert_equal(_inv.lot_reserved_milli(personal), 300, "the member's lot is still reserved")
	_assert_pool_and_inventory_sound("coordinator cancellation")


func test_releasing_a_job_with_no_claims_is_not_a_refusal() -> void:
	"""A member who never claimed anything departs cleanly, releasing zero rows."""
	var result: InventoryScript.OpResult = _pool.release_job_claims(MEMBER_TWO, _inv)
	assert_true(result.ok, "an empty release succeeds")
	assert_equal(result.value, 0, "zero rows released")
	assert_equal(_pool.active_row_count(), 0, "the pool stays empty")


# --- Acceptance: deterministic image of the active claims ----------------------------------------

func test_two_logically_identical_worlds_serialize_identically() -> void:
	"""Save/load stand-in: the image depends on the CLAIMS, not on allocation history.

	The save format itself does not exist yet -- nothing specifies its header, chunking or
	version field -- so reading an image back is deferred. What is testable now, and is what a
	save has to rest on, is that two worlds holding the same claims produce the same bytes even
	when their rows were allocated in a different order.
	"""
	var lots_a: Array[Vector2i] = _make_lots(4, 1000)
	assert_true(_claim_one(JOB_A, lots_a[0], 100, PURPOSE_A, 700).ok, "world A claim 1")
	assert_true(_claim_one(JOB_B, lots_a[3], 200, PURPOSE_B, 800).ok, "world A claim 2")
	assert_true(_claim_one(JOB_A, lots_a[2], 300, PURPOSE_A, 900).ok, "world A claim 3")
	assert_true(_claim_one(COORDINATOR, lots_a[3], 150, PURPOSE_A, 800).ok, "world A shares lot 3")
	assert_true(_claim_one(JOB_A, lots_a[3], 250, PURPOSE_A, 800).ok, "world A shares lot 3 again")
	var image_a: PackedByteArray = _pool.state_bytes()
	_build_second_world()
	var lots_b: Array[Vector2i] = _make_lots(4, 1000)
	var scratch: Vector2i = _lot(1000)
	assert_true(_claim_one(JOB_B, scratch, 500).ok, "world B fragments its rows first")
	assert_true(_claim_one(JOB_A, lots_b[2], 300, PURPOSE_A, 900).ok, "world B claim 3 first")
	assert_true(_pool.release_claim(JOB_B, scratch, PURPOSE_A, _inv).ok, "the scratch claim goes")
	# The shared lot is claimed in the OPPOSITE order to world A, so an image that leaked
	# insertion order rather than the canonical one would differ here.
	assert_true(_claim_one(JOB_A, lots_b[3], 250, PURPOSE_A, 800).ok, "world B shares lot 3 first")
	assert_true(_claim_one(COORDINATOR, lots_b[3], 150, PURPOSE_A, 800).ok, "world B shares lot 3 second")
	assert_true(_claim_one(JOB_B, lots_b[3], 200, PURPOSE_B, 800).ok, "world B claim 2")
	assert_true(_claim_one(JOB_A, lots_b[0], 100, PURPOSE_A, 700).ok, "world B claim 1")
	assert_equal(_pool.state_bytes(), image_a, "the same claims serialize to the same bytes")
	assert_true(image_a.size() > 8, "the image actually carries the claims")


func _build_second_world() -> void:
	"""Replace the fixture with a fresh inventory, pool and container for a comparison world."""
	_inv = _make_inventory()
	_pool = ReservationsScript.new()
	_container = _make_container()


func test_a_different_claim_changes_the_image() -> void:
	"""The image must actually depend on the claims, or the comparison above proves nothing."""
	var lot_ref: Vector2i = _lot(1000)
	assert_true(_claim_one(JOB_A, lot_ref, 100).ok, "claim accepted")
	var image: PackedByteArray = _pool.state_bytes()
	_build_second_world()
	var other: Vector2i = _lot(1000)
	assert_true(_claim_one(JOB_A, other, 101).ok, "the other world claims one milli-unit more")
	assert_true(_pool.state_bytes() != image, "a different quantity produces different bytes")
	_build_second_world()
	var third: Vector2i = _lot(1000)
	assert_true(_claim_one(JOB_B, third, 100).ok, "a different job claims the same quantity")
	assert_true(_pool.state_bytes() != image, "a different owner produces different bytes")
	assert_equal(ReservationsScript.new().state_bytes(), ReservationsScript.new().state_bytes(), "two empty pools agree")


# --- Leases -------------------------------------------------------------------------------------

func test_expired_claims_release_and_live_ones_survive() -> void:
	"""BAL-SAFE-004's per-job half: rows at or past `now_tick` go, later ones stay."""
	var lots: Array[Vector2i] = _make_lots(3, 1000)
	assert_true(_claim_one(JOB_A, lots[0], 100, PURPOSE_A, 100).ok, "short lease accepted")
	assert_true(_claim_one(JOB_A, lots[1], 200, PURPOSE_A, 400).ok, "long lease accepted")
	assert_true(_claim_one(JOB_A, lots[2], 300, PURPOSE_A, 100).ok, "second short lease accepted")
	var swept: InventoryScript.OpResult = _pool.release_expired_for_job(JOB_A, 100, _inv)
	assert_true(swept.ok, "the sweep runs (%s)" % swept.error)
	assert_equal(swept.value, 2, "both expired leases released")
	assert_equal(_inv.lot_reserved_milli(lots[0]), 0, "the first expired lot is free")
	assert_equal(_inv.lot_reserved_milli(lots[2]), 0, "the second expired lot is free")
	assert_equal(_inv.lot_reserved_milli(lots[1]), 200, "the live lease survives")
	assert_equal(_pool.job_claim_count(JOB_A), 1, "one row remains")
	var again: InventoryScript.OpResult = _pool.release_expired_for_job(JOB_A, 399, _inv)
	assert_equal(again.value, 0, "a tick before expiry releases nothing")
	_assert_pool_and_inventory_sound("lease sweep")


func test_renewal_only_ever_extends_a_lease() -> void:
	"""A renewal that would shorten a lease is refused explicitly rather than ignored."""
	var lot_ref: Vector2i = _lot(1000)
	assert_true(_claim_one(JOB_A, lot_ref, 100, PURPOSE_A, 300).ok, "claim accepted")
	var shorter: InventoryScript.OpResult = _pool.renew_claim(JOB_A, lot_ref, PURPOSE_A, 200)
	assert_false(shorter.ok, "shortening is refused")
	assert_equal(shorter.error, ReservationsScript.REFUSE_EXPIRY_NOT_LATER, "explicit refusal")
	assert_true(_pool.claim_expiry_into(JOB_A, lot_ref, PURPOSE_A, _out), "expiry readable")
	assert_equal(_out.value, 300, "the refused renewal changed nothing")
	var longer: InventoryScript.OpResult = _pool.renew_claim(JOB_A, lot_ref, PURPOSE_A, 600)
	assert_true(longer.ok, "extending is accepted")
	assert_equal(longer.value, 600, "the new expiry is reported")
	var missing: InventoryScript.OpResult = _pool.renew_claim(JOB_B, lot_ref, PURPOSE_A, 900)
	assert_false(missing.ok, "renewing a claim that does not exist is refused")
	assert_equal(missing.error, ReservationsScript.REFUSE_NO_SUCH_CLAIM, "explicit refusal")


# --- Refusals and guards -------------------------------------------------------------------------

func test_batch_refuses_an_unusable_job_reference() -> void:
	"""The null reference and an out-of-range slot are refused before anything is touched."""
	var lot_ref: Vector2i = _lot(1000)
	_write_claim(0, lot_ref, PURPOSE_A, 100, 300)
	var null_ref: InventoryScript.OpResult = _pool.claim_batch(ReservationsScript.NULL_REF, _claims, 1, _inv)
	assert_false(null_ref.ok, "the null reference is refused")
	assert_equal(null_ref.error, ReservationsScript.REFUSE_JOB_OUT_OF_RANGE, "explicit refusal")
	var beyond: InventoryScript.OpResult = _pool.claim_batch(Vector2i(8192, 1), _claims, 1, _inv)
	assert_equal(beyond.error, ReservationsScript.REFUSE_JOB_OUT_OF_RANGE, "slot 8192 is out of range")
	var zero_generation: InventoryScript.OpResult = _pool.claim_batch(Vector2i(5, 0), _claims, 1, _inv)
	assert_equal(zero_generation.error, ReservationsScript.REFUSE_INVALID_JOB, "generation 0 is not a live ref")
	assert_equal(_inv.lot_reserved_milli(lot_ref), 0, "no refusal reserved anything")


func test_batch_refuses_malformed_input() -> void:
	"""Empty, truncated and ill-formed batches are refused with distinct explicit codes."""
	var lot_ref: Vector2i = _lot(1000)
	_write_claim(0, lot_ref, PURPOSE_A, 100, 300)
	assert_equal(_pool.claim_batch(JOB_A, _claims, 0, _inv).error, ReservationsScript.REFUSE_EMPTY_BATCH, "count 0")
	var short_buffer: PackedInt64Array = PackedInt64Array()
	short_buffer.resize(ReservationsScript.CLAIM_STRIDE)
	assert_equal(_pool.claim_batch(JOB_A, short_buffer, 2, _inv).error, ReservationsScript.REFUSE_MALFORMED_BATCH, "buffer too short")
	_write_claim(0, lot_ref, PURPOSE_A, 0, 300)
	assert_equal(_pool.claim_batch(JOB_A, _claims, 1, _inv).error, ReservationsScript.REFUSE_INVALID_QUANTITY, "zero quantity")
	_write_claim(0, lot_ref, PURPOSE_A, 100, -1)
	assert_equal(_pool.claim_batch(JOB_A, _claims, 1, _inv).error, ReservationsScript.REFUSE_INVALID_EXPIRY, "negative expiry")
	_write_claim(0, Vector2i(16384, 1), PURPOSE_A, 100, 300)
	assert_equal(_pool.claim_batch(JOB_A, _claims, 1, _inv).error, ReservationsScript.REFUSE_LOT_OUT_OF_RANGE, "lot slot out of range")
	assert_equal(_pool.active_row_count(), 0, "none of those wrote a row")


func test_batch_refuses_to_join_an_open_inventory_transaction() -> void:
	"""The pool's rows are outside inventory's journal, so an outer rollback must be impossible."""
	var lot_ref: Vector2i = _lot(1000)
	assert_true(_inv.begin().ok, "a caller opens its own transaction")
	var result: InventoryScript.OpResult = _claim_one(JOB_A, lot_ref, 100)
	assert_false(result.ok, "claiming inside someone else's transaction is refused")
	assert_equal(result.error, ReservationsScript.REFUSE_INVENTORY_TRANSACTION_OPEN, "explicit refusal")
	assert_equal(_pool.active_row_count(), 0, "nothing was written")
	_inv.abort()
	assert_true(_claim_one(JOB_A, lot_ref, 100).ok, "the same claim is accepted once the transaction closes")


func test_a_reused_job_slot_refuses_until_the_old_claims_are_released() -> void:
	"""A destroyed Job that leaked claims is caught at the point of the bug, not by a later audit."""
	var lot_ref: Vector2i = _lot(1000)
	assert_true(_claim_one(JOB_A, lot_ref, 100).ok, "generation 1 claims")
	var reused: InventoryScript.OpResult = _claim_one(Vector2i(JOB_A.x, JOB_A.y + 1), _lot(1000), 100)
	assert_false(reused.ok, "the next generation of that slot is refused")
	assert_equal(reused.error, ReservationsScript.REFUSE_JOB_GENERATION_CONFLICT, "explicit refusal")
	assert_true(_pool.release_job_claims(JOB_A, _inv).ok, "the old job releases its claims")
	assert_true(_claim_one(Vector2i(JOB_A.x, JOB_A.y + 1), _lot(1000), 100).ok, "the reused slot is then usable")
	_assert_pool_and_inventory_sound("job slot reuse")


func test_a_null_inventory_is_refused_rather_than_dereferenced() -> void:
	"""Every path that needs an inventory refuses explicitly when it is handed none."""
	var lot_ref: Vector2i = _lot(1000)
	_write_claim(0, lot_ref, PURPOSE_A, 100, 300)
	assert_equal(_pool.claim_batch(JOB_A, _claims, 1, null).error, ReservationsScript.REFUSE_NO_INVENTORY, "claim_batch")
	assert_equal(_pool.release_claim(JOB_A, lot_ref, PURPOSE_A, null).error, ReservationsScript.REFUSE_NO_INVENTORY, "release_claim")
	assert_equal(_pool.release_job_claims(JOB_A, null).error, ReservationsScript.REFUSE_NO_INVENTORY, "release_job_claims")
	assert_equal(_pool.release_lot_claims(lot_ref, null).error, ReservationsScript.REFUSE_NO_INVENTORY, "release_lot_claims")
	assert_equal(_pool.release_expired_for_job(JOB_A, 0, null).error, ReservationsScript.REFUSE_NO_INVENTORY, "release_expired_for_job")
	assert_equal(_pool.drop_retired_lot_claims(lot_ref, null).error, ReservationsScript.REFUSE_NO_INVENTORY, "drop_retired_lot_claims")


func test_releasing_an_unknown_claim_is_an_explicit_refusal() -> void:
	"""No sentinel: asking to release something that was never claimed says so."""
	var lot_ref: Vector2i = _lot(1000)
	var result: InventoryScript.OpResult = _pool.release_claim(JOB_A, lot_ref, PURPOSE_A, _inv)
	assert_false(result.ok, "unknown claim refused")
	assert_equal(result.error, ReservationsScript.REFUSE_NO_SUCH_CLAIM, "explicit refusal")
	assert_true(_claim_one(JOB_A, lot_ref, 100).ok, "claim accepted")
	var wrong_purpose: InventoryScript.OpResult = _pool.release_claim(JOB_A, lot_ref, PURPOSE_B, _inv)
	assert_equal(wrong_purpose.error, ReservationsScript.REFUSE_NO_SUCH_CLAIM, "the purpose is part of the key")
	assert_equal(_inv.lot_reserved_milli(lot_ref), 100, "the real claim survived both refusals")


# --- Queries without sentinels ---------------------------------------------------------------------

func test_claim_expiry_is_reported_without_a_sentinel() -> void:
	"""Expiry 0 is a legal stored value, so the reader is written in the `_into` form."""
	var lot_ref: Vector2i = _lot(1000)
	assert_true(_claim_one(JOB_A, lot_ref, 100, PURPOSE_A, 0).ok, "a claim expiring at tick 0")
	assert_true(_pool.claim_expiry_into(JOB_A, lot_ref, PURPOSE_A, _out), "an existing claim reads back")
	assert_equal(_out.value, 0, "expiry 0 is reported as a value, not as absence")
	assert_false(_pool.claim_expiry_into(JOB_B, lot_ref, PURPOSE_A, _out), "an absent claim refuses")
	assert_false(_out.ok, "the refusal is on the result object")
	assert_equal(_out.value, 0, "a refused read carries no stale value")
	assert_equal(_pool.claim_quantity_milli(JOB_B, lot_ref, PURPOSE_A), 0, "an absent claim totals zero")
	assert_false(_pool.has_claim(JOB_B, lot_ref, PURPOSE_A), "and has_claim says so explicitly")
	assert_true(_pool.has_claim(JOB_A, lot_ref, PURPOSE_A), "the real claim is found")


func test_row_accessors_refuse_an_inactive_row() -> void:
	"""Row-level readers never report a freed row's residue as live data."""
	var lot_ref: Vector2i = _lot(1000)
	assert_true(_claim_one(JOB_A, lot_ref, 100, PURPOSE_B, 55).ok, "claim accepted")
	var row: int = _pool.first_lot_row(lot_ref)
	assert_true(_pool.is_row_active(row), "the row is active")
	assert_true(_pool.row_purpose_into(row, _out), "purpose reads back")
	assert_equal(_out.value, PURPOSE_B, "the stored purpose is opaque and unaltered")
	assert_true(_pool.row_expiry_into(row, _out), "expiry reads back")
	assert_equal(_out.value, 55, "the stored expiry")
	assert_equal(_pool.row_quantity_milli(row), 100, "the stored quantity")
	assert_true(_pool.release_claim(JOB_A, lot_ref, PURPOSE_B, _inv).ok, "release the claim")
	assert_false(_pool.is_row_active(row), "the row is no longer active")
	assert_false(_pool.row_purpose_into(row, _out), "purpose refuses on a freed row")
	assert_false(_pool.row_expiry_into(row, _out), "expiry refuses on a freed row")
	assert_equal(_pool.row_job_ref(row), ReservationsScript.NULL_REF, "a freed row has no owner")
	assert_equal(_pool.row_lot_ref(row), ReservationsScript.NULL_REF, "a freed row claims no lot")
	assert_equal(_pool.next_job_row(row), ReservationsScript.NULL_ROW, "iteration from a freed row ends")
	assert_equal(_pool.next_lot_row(row), ReservationsScript.NULL_ROW, "lot iteration from a freed row ends")
