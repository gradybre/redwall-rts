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
	for row: int in range(rows):
		if occupied[row] > 1:
			derived.refusal = COLUMN_RESERVATION_OCCUPANCY
			return derived
		active += occupied[row]
	for row: int in range(rows):
		if occupied[row] == 1:
			continue
		# Ordinals 1..7 of an inactive row, in declared order: a released row is blanked in full,
		# so any residue is corruption rather than history.
		if job_slot[row] != NULL_SLOT or job_generation[row] != NULL_GENERATION \
				or lot_slot[row] != NULL_SLOT or lot_generation[row] != NULL_GENERATION \
				or purpose[row] != 0 or quantity_milli[row] != 0 or expiry[row] != 0:
			derived.refusal = COLUMN_RESERVATION_BLANK
			return derived
	for row: int in range(rows):
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
	for row: int in range(rows):
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
	for index: int in range(1, count):
		var row: int = order[index]
		var previous: int = order[index - 1]
		if job_slot[row] == job_slot[previous] and job_generation[row] != job_generation[previous]:
			return COLUMN_RESERVATION_JOB_GENERATION
	for index: int in range(1, count):
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
	for index: int in range(1, count):
		var row: int = order[index]
		var previous: int = order[index - 1]
		if lot_slot[row] == lot_slot[previous] and lot_generation[row] != lot_generation[previous]:
			return COLUMN_RESERVATION_LOT_GENERATION
	var total: int = 0
	for index: int in range(count):
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
	for index: int in range(count):
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
	merge destination, and each pass copies back so the two buffers never alias or multiply. Both
	are released when this returns, so the two sorts a validation performs are SEQUENTIAL in
	memory as well as in time.

	The sort is stable on the row index by construction: equal keys fall back to `a < b`.
	"""
	var order: PackedInt32Array = PackedInt32Array()
	order.resize(rows)
	var scratch: PackedInt32Array = PackedInt32Array()
	scratch.resize(rows)
	var filled: int = 0
	for row: int in range(rows):
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
		for index: int in range(count):
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
	for slot: int in range(_job_capacity):
		if _job_head[slot] != derived._job_head[slot]:
			return false
	for slot: int in range(_lot_capacity):
		if _lot_head[slot] != derived._lot_head[slot]:
			return false
	for row: int in range(_row_capacity):
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
	for index: int in range(_free_count):
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
