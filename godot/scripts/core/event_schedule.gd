extends RefCounted
## §11 EVENT_SCHEDULE: the bounded timed-event schedule, the store `canonical_state_registry.json`
## already declares and no module supplied.
##
## `docs/persistence_state_registry.md:82` records the hole this closes: "§11 EVENT_SCHEDULE, §13
## CHRONICLE and §15 STATE_DIGEST have no owning module at all yet". REG-R01
## (`docs/rulings/2026-09-12_save_registry_answers.md`) then published a FORWARD declaration for
## this owner -- `section_id 11`, `owner_key "event_schedule"`, `owner_schema_version 1`, eight
## fields with fixed ordinals, marked `REQUIRED_NOT_PRESENT_IN_SNAPSHOT`. That declaration, not
## this file, is the contract: every key, type and ordinal below is transcribed from it and
## `_assert_contracts()` proves the transcription at construction. Nothing here was chosen.
##
## ---------------------------------------------------------------------------------------
## THIS IS NOT `scheduler_events.gd`, AND THE NAMES ARE ONE CHARACTER APART.
##
##   `scheduler_events.gd` -- R07-SCHED-001's SPEED AND PAUSE queue. It carries
##   `SET_REQUESTED_SPEED` / `SET_PAUSE_REASON` records keyed by `(boundary_tick, unsigned
##   sequence)`, it owns a clock and applies events to it, and it is persisted in **§12
##   PENDING_COMMANDS** as the `SCHQ0001` extension after the economic records -- never here.
##   `docs/planning/ready07_scheduler_contract.md:116-124` puts it there and REG-R01 keeps it
##   there. Its queue is a 256-slot RING with a movable `_head`.
##
##   `event_schedule.gd` -- THIS module. The TIMED-GAME-EVENT schedule of **§11**: at most 64
##   records of `kind, source_id, arg0, arg1, due_tick, sequence`, held DENSE from row 0 and
##   sorted by `(due_tick, sequence)`. No ring, no head, no clock, no speed and no pause. It
##   applies nothing to anything; a consumer pops a due row and decides what it means.
##
## Confusing the two puts a pause record in §11 or a timed event in §12, and SAVE-R09-005 says in
## terms: "Scheduler pause/speed commands stay in section 12, never here."
##
## ---------------------------------------------------------------------------------------
## THE SEQUENCE ALLOCATOR IS NOT A NEW ALLOCATION. SAVE-R09-005: `_next_sequence` is "the ALREADY
## BUDGETED WorldRuntime.next_event_sequence i64 (architecture §3), reassigned to EventSchedule
## ownership/section 11". Architecture's ledger row for `WorldRuntime` i64 counters must therefore
## LOSE `next_event_sequence` as this owner gains it; the total does not move by 8 bytes. Whoever
## owns `docs/systems_architecture.md` applies that, because this file may not.
##
## Initial value 1. Issued 1..INT64_MAX, never reused. **Zero means EXHAUSTED**, and from there
## every insertion refuses atomically -- it is not a small sequence and not a null. A capacity
## refusal must not consume a sequence either, which is why `_advance_sequence()` is the LAST
## thing `schedule_into()` does and never the first.
##
## ---------------------------------------------------------------------------------------
## NO STALE TAIL IS OBSERVABLE. Rows `[_count, CAPACITY)` are held at zero, not left as the
## residue of a cancelled or popped event. Decision 0103 applied this reasoning to the directory's
## free heaps and §12 applied it to both of its rings: two observationally identical worlds must
## not produce different bytes. `_remove_row()` zeroes the vacated last row before returning, and
## `state_bytes()` images the FULL 64 rows precisely so a test can catch a tail that was left dirty.
##
## THE INT32 SIGN TRAP. `_kind`, `_source_id`, `_arg0` and `_arg1` are `PackedInt32Array`, but a
## GDScript int is 64-bit: assigning `0x80000000` (positive, 2147483648) into one silently stores
## `-2147483648`. Every one of the four is checked with `IntMath.fits_int32()` BEFORE any column is
## written, so an out-of-range argument refuses instead of arriving sign-flipped. `_due_tick` and
## `_sequence` are i64 and need no narrowing.
##
## THE CALENDAR IS OFFSET, AND THIS IS EXACTLY THE STORE WHERE THAT BITES. A day boundary is
## `(tick + 4500) mod 18000 == 0`, the first midnight is tick 13500, and `tick % 18000 == 0` is
## 06:00. `next_day_boundary_after_into()` is the only place this module computes one, it uses
## `SimClock.CALENDAR_OFFSET_TICKS`, and it GATES its own answer through `SimClock.is_day_boundary()`
## before returning it -- the pattern `ecology.gd:416` established -- so a wrong inverse refuses
## rather than travelling. `due_day_index_into()` likewise delegates to `SimClock.day_index_at()`
## and never divides a raw tick.
##
## ---------------------------------------------------------------------------------------
## WHAT THIS DELIBERATELY DOES NOT DO, NAMED RATHER THAN INVENTED:
##
##   * **NO §11 CODEC.** There is no encoder and no decoder here. SAVE-R09-005 froze the payload
##     as `next_sequence:i64` followed by N 32-byte records with fields in the order
##     `kind, source_id, arg0, arg1, due_tick, sequence`, length `8 + 32*N`; the `OFFSET_*`
##     constants below transcribe that layout so the codec owner cannot re-derive it wrongly, and
##     `state_bytes()` is a TEST image in a different shape, not that payload. §11's codec does
##     not exist. Do not read this file as evidence that it does.
##
##   * **NO KIND OR ARGUMENT DOMAIN.** SAVE-R09-005: "The event owner must register concrete
##     kind/argument domains and event production/consumption rules before real events are
##     activated." No such domain is ruled anywhere in this repository, so this module validates
##     `_kind`, `_source_id`, `_arg0` and `_arg1` as int32 STORAGE ONLY and assigns them no
##     meaning. Inventing an event enum, a cadence or a payload reading here is precisely the
##     invention the scope forbids. BLOCKER, reported: the kind domain and the production rules.
##
##   * **NO PRODUCER AND NO CONSUMER.** Nothing schedules an event and nothing drains one. The
##     store refuses to expire a row on its own, because SAVE-R09-005 requires "no silently
##     expired rows": a due row stays until a consumer pops it.

const IntMath := preload("res://scripts/core/int_math.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")

# --- REG-R01's declared identity for this owner --------------------------------------------------

const SECTION_ID: int = 11
const OWNER_KEY: String = "event_schedule"
const OWNER_SCHEMA_VERSION: int = 1

## The eight declared field keys IN ORDINAL ORDER. Underscores are kept: REG-R01 says "Keep
## underscores in field keys" and forbids regenerating order from GDScript declaration order.
const FIELD_KEYS: Array[String] = ["_next_sequence", "_count", "_kind", "_source_id", "_arg0",
	"_arg1", "_due_tick", "_sequence"]

## The declared `type_code` of each field, in the same ordinal order: u32 = 1, i32 = 2, i64 = 4.
const FIELD_TYPE_CODES: Array[int] = [4, 1, 2, 2, 2, 2, 4, 4]

const TYPE_CODE_U32: int = 1
const TYPE_CODE_I32: int = 2
const TYPE_CODE_I64: int = 4

const ORDINAL_NEXT_SEQUENCE: int = 0
const ORDINAL_COUNT: int = 1
const ORDINAL_KIND: int = 2
const ORDINAL_SOURCE_ID: int = 3
const ORDINAL_ARG0: int = 4
const ORDINAL_ARG1: int = 5
const ORDINAL_DUE_TICK: int = 6
const ORDINAL_SEQUENCE: int = 7

## REG-R01's declared `shape.order` for all six row-shaped fields.
const ROW_ORDER: String = "due_tick_then_sequence"

# --- capacity and the frozen wire stride ----------------------------------------------------------

## REG-R01's `shape.max_count`, and SAVE-R09-005's "existing maximum 64 records". The same 64 is
## budgeted in `docs/systems_architecture.md`'s EventSchedule ledger rows.
const CAPACITY: int = 64

## SAVE-R09-005's record layout, transcribed. NOTHING HERE ENCODES; see the header.
const RECORD_BYTES: int = 32
const OFFSET_KIND: int = 0
const OFFSET_SOURCE_ID: int = 4
const OFFSET_ARG0: int = 8
const OFFSET_ARG1: int = 12
const OFFSET_DUE_TICK: int = 16
const OFFSET_SEQUENCE: int = 24
const FIELD_BYTES: int = 4
const TICK_FIELD_BYTES: int = 8
## `8 + 32*N` at N = CAPACITY: the largest §11 payload this store can ever hand a codec.
const MAX_PAYLOAD_BYTES: int = TICK_FIELD_BYTES + RECORD_BYTES * CAPACITY

# --- the sequence allocator ------------------------------------------------------------------------

const INITIAL_SEQUENCE: int = 1
## SAVE-R09-005: "zero means exhausted". Never a live event's sequence and never an issued value.
const SEQUENCE_EXHAUSTED: int = 0
const MAX_SEQUENCE: int = IntMath.INT64_MAX

# --- refusals. Every one is explicit; none is ever encoded as a returned number ---------------------

const REFUSE_NONE: StringName = &""
const REFUSE_FULL: StringName = &"EVENT_SCHEDULE_FULL"
const REFUSE_SEQUENCE_EXHAUSTED: StringName = &"EVENT_SEQUENCE_EXHAUSTED"
const REFUSE_FIELD_NOT_INT32: StringName = &"EVENT_FIELD_NOT_INT32"
const REFUSE_TICK_NEGATIVE: StringName = &"EVENT_TICK_NEGATIVE"
const REFUSE_DUE_NOT_FUTURE: StringName = &"EVENT_DUE_TICK_NOT_FUTURE"
const REFUSE_ROW_OUT_OF_RANGE: StringName = &"EVENT_ROW_OUT_OF_RANGE"
const REFUSE_SEQUENCE_NOT_SCHEDULED: StringName = &"EVENT_SEQUENCE_NOT_SCHEDULED"
const REFUSE_NOT_DAY_BOUNDARY: StringName = &"EVENT_NOT_DAY_BOUNDARY"
const REFUSE_RESTORE_COUNT: StringName = &"EVENT_RESTORE_COUNT"
const REFUSE_RESTORE_RAGGED: StringName = &"EVENT_RESTORE_COLUMNS_RAGGED"
const REFUSE_RESTORE_SEQUENCE_RANGE: StringName = &"EVENT_RESTORE_SEQUENCE_RANGE"
const REFUSE_RESTORE_ALLOCATOR: StringName = &"EVENT_RESTORE_ALLOCATOR_RANGE"
const REFUSE_RESTORE_ORDER: StringName = &"EVENT_RESTORE_ORDER"
const REFUSE_RESTORE_DUPLICATE: StringName = &"EVENT_RESTORE_DUPLICATE_SEQUENCE"


class Event:
	"""One decoded schedule row. `sequence == 0` is the cleared state and never a live event."""
	var kind: int = 0
	var source_id: int = 0
	var arg0: int = 0
	var arg1: int = 0
	var due_tick: int = 0
	var sequence: int = 0

	func clear() -> void:
		"""Zero every field, so a refused read cannot surface the previous row as this one."""
		kind = 0
		source_id = 0
		arg0 = 0
		arg1 = 0
		due_tick = 0
		sequence = 0


# --- the six declared row columns, allocated once in _init() and never resized again ----------------

var _kind: PackedInt32Array = PackedInt32Array()
var _source_id: PackedInt32Array = PackedInt32Array()
var _arg0: PackedInt32Array = PackedInt32Array()
var _arg1: PackedInt32Array = PackedInt32Array()
var _due_tick: PackedInt64Array = PackedInt64Array()
var _sequence: PackedInt64Array = PackedInt64Array()

# --- the two declared scalars -----------------------------------------------------------------------

var _count: int = 0
var _next_sequence: int = INITIAL_SEQUENCE

# --- diagnostics and scratch: category 3, never saved and never hashed -------------------------------

var _last_refusal: StringName = REFUSE_NONE
var _math: IntMath.IntResult = IntMath.IntResult.new()


func _init() -> void:
	"""Prove the transcribed declaration, size every column exactly once, then zero the store."""
	_assert_contracts()
	_allocate_columns()
	clear()


func _assert_contracts() -> void:
	"""Prove the eight declared fields, their ordinals and SAVE-R09-005's 32-byte stride."""
	assert(FIELD_KEYS.size() == 8 and FIELD_TYPE_CODES.size() == 8,
		"REG-R01 declares exactly eight fields for section 11 owner event_schedule")
	assert(FIELD_KEYS[ORDINAL_NEXT_SEQUENCE] == "_next_sequence"
		and FIELD_KEYS[ORDINAL_COUNT] == "_count" and FIELD_KEYS[ORDINAL_KIND] == "_kind"
		and FIELD_KEYS[ORDINAL_SOURCE_ID] == "_source_id"
		and FIELD_KEYS[ORDINAL_ARG0] == "_arg0" and FIELD_KEYS[ORDINAL_ARG1] == "_arg1"
		and FIELD_KEYS[ORDINAL_DUE_TICK] == "_due_tick"
		and FIELD_KEYS[ORDINAL_SEQUENCE] == "_sequence",
		"the declared ordinals 0..7 must not be renumbered by this module")
	assert(FIELD_TYPE_CODES[ORDINAL_NEXT_SEQUENCE] == TYPE_CODE_I64
		and FIELD_TYPE_CODES[ORDINAL_COUNT] == TYPE_CODE_U32
		and FIELD_TYPE_CODES[ORDINAL_DUE_TICK] == TYPE_CODE_I64
		and FIELD_TYPE_CODES[ORDINAL_SEQUENCE] == TYPE_CODE_I64,
		"_next_sequence, _due_tick and _sequence are i64; _count is u32")
	assert(OFFSET_SEQUENCE + TICK_FIELD_BYTES == RECORD_BYTES,
		"the record's last field must end exactly at the frozen 32-byte stride")
	assert(OFFSET_DUE_TICK == 4 * FIELD_BYTES,
		"four i32 fields precede due_tick in SAVE-R09-005's record order")


func _allocate_columns() -> void:
	"""Size all six columns to CAPACITY exactly once, per ARCH-MEM-001. Never called again."""
	_due_tick.resize(CAPACITY)
	_sequence.resize(CAPACITY)
	for column: PackedInt32Array in [_kind, _source_id, _arg0, _arg1]:
		column.resize(CAPACITY)


func clear() -> void:
	"""Return the schedule to its initial state: no rows, allocator at 1, every row byte zero.

	World initialization, not a drain. It discards pending events and RESETS the sequence
	allocator, so nothing that must survive a save may call it.
	"""
	_due_tick.fill(0)
	_sequence.fill(0)
	for column: PackedInt32Array in [_kind, _source_id, _arg0, _arg1]:
		column.fill(0)
	_count = 0
	_next_sequence = INITIAL_SEQUENCE
	_last_refusal = REFUSE_NONE


# --- readers ------------------------------------------------------------------------------------------

func capacity() -> int:
	"""REG-R01's declared `max_count` for every row-shaped field: 64."""
	return CAPACITY


func count() -> int:
	"""Live row count, the declared `_count` scalar. Rows `[0, count())` are the whole schedule."""
	return _count


func is_empty() -> bool:
	"""True when no event is scheduled."""
	return _count == 0


func is_full() -> bool:
	"""True when all 64 declared rows are live and another insertion must refuse."""
	return _count >= CAPACITY


func next_sequence() -> int:
	"""The allocator's next value: 1 initially, 0 once exhausted, never a live row's sequence."""
	return _next_sequence


func is_sequence_exhausted() -> bool:
	"""True once every i64 sequence has been issued; from here every insertion refuses."""
	return _next_sequence == SEQUENCE_EXHAUSTED


func last_refusal() -> StringName:
	"""Reason the most recent refusing call gave, or the empty name after a success."""
	return _last_refusal


func read_into(index: int, out: Event) -> bool:
	"""Copy live row `index` into a caller-owned Event. Refuses, and CLEARS `out`, outside range.

	The refusal clears rather than leaves `out` untouched, so ignoring the returned bool cannot
	surface the previous row's numbers as though they were this index's.
	"""
	if index < 0 or index >= _count:
		out.clear()
		return _refuse(REFUSE_ROW_OUT_OF_RANGE)
	out.kind = _kind[index]
	out.source_id = _source_id[index]
	out.arg0 = _arg0[index]
	out.arg1 = _arg1[index]
	out.due_tick = _due_tick[index]
	out.sequence = _sequence[index]
	_last_refusal = REFUSE_NONE
	return true


func find_sequence_into(sequence: int, out: IntMath.IntResult) -> bool:
	"""Row index carrying `sequence`, or a refusal when no live row does.

	There is no -1: row 0 is a legal index and a sentinel here would be read as one. `.ok` MUST
	be inspected, exactly as every `int_math.gd` result requires.
	"""
	for index: int in range(_count):
		if _sequence[index] == sequence:
			_last_refusal = REFUSE_NONE
			return out.succeed(index)
	_refuse(REFUSE_SEQUENCE_NOT_SCHEDULED)
	return out.refuse(String(REFUSE_SEQUENCE_NOT_SCHEDULED))


func due_count(boundary_tick: int) -> int:
	"""How many live rows are due at or before `boundary_tick`.

	Rows are sorted by `(due_tick, sequence)`, so the due set is always a PREFIX and this scan
	stops at the first row that is not due.
	"""
	var due: int = 0
	while due < _count and _due_tick[due] <= boundary_tick:
		due += 1
	return due


func has_due(boundary_tick: int) -> bool:
	"""True when at least one row is due at or before `boundary_tick`."""
	return _count > 0 and _due_tick[0] <= boundary_tick


# --- insertion ------------------------------------------------------------------------------------------

func schedule(kind: int, source_id: int, arg0: int, arg1: int, due_tick: int,
		now_tick: int) -> IntMath.IntResult:
	"""Allocating form of schedule_into(); the value is the issued sequence."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	schedule_into(kind, source_id, arg0, arg1, due_tick, now_tick, out)
	return out


func schedule_into(kind: int, source_id: int, arg0: int, arg1: int, due_tick: int, now_tick: int,
		out: IntMath.IntResult) -> bool:
	"""Insert one event due at `due_tick`, in `(due_tick, sequence)` order. Value: its sequence.

	ALLOCATE BEFORE CONSUME (decision 0059): every check runs before any column is touched, and
	the allocator advances LAST. A refusal -- full schedule, exhausted allocator, non-int32 field
	or a due tick that is not strictly after `now_tick` -- therefore leaves this store
	BYTE-IDENTICAL, including `_next_sequence`. SAVE-R09-005: "Capacity failure must not consume
	a sequence."

	`now_tick` is the caller's COMPLETED boundary. A due tick at or before it would already have
	expired unnoticed, which the same ruling forbids, so it refuses instead.
	"""
	if not _validate_schedule(kind, source_id, arg0, arg1, due_tick, now_tick, out):
		return false
	var issued: int = _next_sequence
	var index: int = _insertion_index(due_tick)
	_shift_up(index)
	_write_row(index, kind, source_id, arg0, arg1, due_tick, issued)
	_count += 1
	_advance_sequence()
	_last_refusal = REFUSE_NONE
	return out.succeed(issued)


func _validate_schedule(kind: int, source_id: int, arg0: int, arg1: int, due_tick: int,
		now_tick: int, out: IntMath.IntResult) -> bool:
	"""Every insertion precondition, run before a single column byte moves. Mutates nothing."""
	if is_full():
		_refuse(REFUSE_FULL)
		return out.refuse(String(REFUSE_FULL))
	if is_sequence_exhausted():
		_refuse(REFUSE_SEQUENCE_EXHAUSTED)
		return out.refuse(String(REFUSE_SEQUENCE_EXHAUSTED))
	if not IntMath.fits_int32(kind) or not IntMath.fits_int32(source_id) \
			or not IntMath.fits_int32(arg0) or not IntMath.fits_int32(arg1):
		_refuse(REFUSE_FIELD_NOT_INT32)
		return out.refuse(String(REFUSE_FIELD_NOT_INT32))
	if now_tick < 0 or due_tick < 0:
		_refuse(REFUSE_TICK_NEGATIVE)
		return out.refuse(String(REFUSE_TICK_NEGATIVE))
	if due_tick <= now_tick:
		_refuse(REFUSE_DUE_NOT_FUTURE)
		return out.refuse(String(REFUSE_DUE_NOT_FUTURE))
	return true


func _insertion_index(due_tick: int) -> int:
	"""First row whose due tick is strictly later than `due_tick`.

	A freshly issued sequence is greater than every live one, so placing the new row AFTER every
	equal-due row is what `(due_tick, sequence)` order requires; no sequence comparison is needed.
	"""
	var index: int = 0
	while index < _count and _due_tick[index] <= due_tick:
		index += 1
	return index


func _shift_up(from_index: int) -> void:
	"""Open a hole at `from_index` by moving rows `[from_index, _count)` one row later."""
	var index: int = _count
	while index > from_index:
		_kind[index] = _kind[index - 1]
		_source_id[index] = _source_id[index - 1]
		_arg0[index] = _arg0[index - 1]
		_arg1[index] = _arg1[index - 1]
		_due_tick[index] = _due_tick[index - 1]
		_sequence[index] = _sequence[index - 1]
		index -= 1


func _write_row(index: int, kind: int, source_id: int, arg0: int, arg1: int, due_tick: int,
		sequence: int) -> void:
	"""Write one fully validated row. Every int32 field was range-checked by the caller."""
	_kind[index] = kind
	_source_id[index] = source_id
	_arg0[index] = arg0
	_arg1[index] = arg1
	_due_tick[index] = due_tick
	_sequence[index] = sequence


func _advance_sequence() -> void:
	"""Consume the issued sequence. Rolling off INT64_MAX lands on 0, which is EXHAUSTED."""
	if _next_sequence == MAX_SEQUENCE:
		_next_sequence = SEQUENCE_EXHAUSTED
		return
	_next_sequence += 1


# --- removal ----------------------------------------------------------------------------------------

func cancel(sequence: int) -> bool:
	"""Remove the row carrying `sequence`. False, with an explicit refusal, when none does.

	The sequence is NOT returned to the allocator: SAVE-R09-005 requires issued sequences to be
	"never reused", because two distinct events sharing one number compare equal in a replay.
	"""
	if not find_sequence_into(sequence, _math):
		return false
	_remove_row(_math.value)
	_last_refusal = REFUSE_NONE
	return true


func pop_due_into(boundary_tick: int, out: Event) -> bool:
	"""Remove and return the earliest row due at or before `boundary_tick`.

	False with a CLEARED `out` when nothing is due; that is an empty answer, not a refusal, and
	`out.sequence == 0` can never be mistaken for an event. Nothing expires on its own: a due row
	stays in the schedule until this call takes it.
	"""
	if not has_due(boundary_tick):
		out.clear()
		return false
	if not read_into(0, out):
		return false
	_remove_row(0)
	return true


func _remove_row(index: int) -> void:
	"""Close the gap at `index` and ZERO the vacated last row, leaving no stale tail.

	The tail beyond `_count` must be byte zero: two schedules holding the same live rows have to
	image identically whether or not one of them once held a cancelled event in row 63.
	"""
	var cursor: int = index
	while cursor < _count - 1:
		_kind[cursor] = _kind[cursor + 1]
		_source_id[cursor] = _source_id[cursor + 1]
		_arg0[cursor] = _arg0[cursor + 1]
		_arg1[cursor] = _arg1[cursor + 1]
		_due_tick[cursor] = _due_tick[cursor + 1]
		_sequence[cursor] = _sequence[cursor + 1]
		cursor += 1
	_count -= 1
	_write_row(_count, 0, 0, 0, 0, 0, 0)


# --- the offset calendar ------------------------------------------------------------------------------

static func next_day_boundary_after_into(tick: int, out: IntMath.IntResult) -> bool:
	"""First midnight STRICTLY after `tick`, under `(t + 4500) mod 18000`. Never `t % 18000`.

	Tick 0 is 06:00 of the first day, so the answer for 0 is 13500 -- the first midnight -- not
	18000, which is 06:00 of day 2. The computed tick is gated through `SimClock.is_day_boundary()`
	before it is returned, the inverse-checking pattern `ecology.gd` established, so this can
	never disagree with the single definition of a crossing.
	"""
	if tick < 0:
		return out.refuse(String(REFUSE_TICK_NEGATIVE))
	if not IntMath.checked_add_into(tick, SimClock.CALENDAR_OFFSET_TICKS, out):
		return false
	var into_day: int = out.value % SimClock.TICKS_PER_DAY
	if not IntMath.checked_add_into(tick, SimClock.TICKS_PER_DAY - into_day, out):
		return false
	if not SimClock.is_day_boundary(out.value):
		return out.refuse(String(REFUSE_NOT_DAY_BOUNDARY))
	return true


func due_day_index_into(index: int, out: IntMath.IntResult) -> bool:
	"""Zero-based offset-calendar day a live row falls on. Refuses outside `[0, _count)`.

	`SimClock.day_index_at()` is the single definition; dividing the raw tick by 18000 would put
	the first midnight on day 0 with 06:00 of the same morning, which is a different day.
	"""
	if index < 0 or index >= _count:
		_refuse(REFUSE_ROW_OUT_OF_RANGE)
		return out.refuse(String(REFUSE_ROW_OUT_OF_RANGE))
	_last_refusal = REFUSE_NONE
	return out.succeed(SimClock.day_index_at(_due_tick[index]))


func schedule_at_next_day_boundary_into(kind: int, source_id: int, arg0: int, arg1: int,
		now_tick: int, out: IntMath.IntResult) -> bool:
	"""schedule_into() with the due tick set to the first midnight strictly after `now_tick`.

	Calendar arithmetic plus the ordinary validated insertion; it grants no cadence and repeats
	nothing. A refused boundary leaves the store byte-identical because nothing has been written.
	"""
	if now_tick < 0:
		_refuse(REFUSE_TICK_NEGATIVE)
		return out.refuse(String(REFUSE_TICK_NEGATIVE))
	if not next_day_boundary_after_into(now_tick, out):
		_refuse(REFUSE_NOT_DAY_BOUNDARY)
		return out.refuse(String(REFUSE_NOT_DAY_BOUNDARY))
	return schedule_into(kind, source_id, arg0, arg1, out.value, now_tick, out)


# --- restore ---------------------------------------------------------------------------------------

func restore_rows(p_next_sequence: int, p_kind: PackedInt32Array, p_source_id: PackedInt32Array,
		p_arg0: PackedInt32Array, p_arg1: PackedInt32Array, p_due_tick: PackedInt64Array,
		p_sequence: PackedInt64Array) -> bool:
	"""Install a validated schedule. NOT A DECODER: it takes decoded columns, never bytes.

	§11's codec does not exist; this is the store-side gate it will have to pass through. Every
	invariant SAVE-R09-005 states is checked BEFORE a single column is written -- count within 64,
	columns not ragged, ticks nonnegative, sequences nonzero, unique, ordered by
	`(due_tick, sequence)` and below `next_sequence` unless it is exhausted -- so a refusal leaves
	this store byte-identical and an invalid save cannot be half-installed.
	"""
	if not _validate_restore(p_next_sequence, p_kind, p_source_id, p_arg0, p_arg1, p_due_tick,
			p_sequence):
		return false
	clear()
	for index: int in range(p_kind.size()):
		_write_row(index, p_kind[index], p_source_id[index], p_arg0[index], p_arg1[index],
			p_due_tick[index], p_sequence[index])
	_count = p_kind.size()
	_next_sequence = p_next_sequence
	_last_refusal = REFUSE_NONE
	return true


func _validate_restore(p_next_sequence: int, p_kind: PackedInt32Array,
		p_source_id: PackedInt32Array, p_arg0: PackedInt32Array, p_arg1: PackedInt32Array,
		p_due_tick: PackedInt64Array, p_sequence: PackedInt64Array) -> bool:
	"""Shape, allocator and per-row checks for restore_rows(). Mutates nothing on any path."""
	var rows: int = p_kind.size()
	if rows > CAPACITY:
		return _refuse(REFUSE_RESTORE_COUNT)
	if p_source_id.size() != rows or p_arg0.size() != rows or p_arg1.size() != rows \
			or p_due_tick.size() != rows or p_sequence.size() != rows:
		return _refuse(REFUSE_RESTORE_RAGGED)
	if p_next_sequence < SEQUENCE_EXHAUSTED:
		return _refuse(REFUSE_RESTORE_ALLOCATOR)
	for index: int in range(rows):
		if p_due_tick[index] < 0:
			return _refuse(REFUSE_TICK_NEGATIVE)
		if p_sequence[index] <= SEQUENCE_EXHAUSTED:
			return _refuse(REFUSE_RESTORE_SEQUENCE_RANGE)
		if p_next_sequence != SEQUENCE_EXHAUSTED and p_sequence[index] >= p_next_sequence:
			return _refuse(REFUSE_RESTORE_SEQUENCE_RANGE)
	return _validate_restore_order(p_due_tick, p_sequence)


func _validate_restore_order(p_due_tick: PackedInt64Array, p_sequence: PackedInt64Array) -> bool:
	"""Rows are dense and strictly ascending by `(due_tick, sequence)`, with no repeated sequence.

	The pairwise uniqueness scan is O(n^2) over at most 64 rows on a cold restore path, and it is
	NOT implied by the ordering check: equal sequences at different due ticks would sort fine.
	"""
	var rows: int = p_sequence.size()
	for index: int in range(1, rows):
		var earlier: int = p_due_tick[index - 1]
		var later: int = p_due_tick[index]
		if later < earlier or (later == earlier and p_sequence[index] <= p_sequence[index - 1]):
			return _refuse(REFUSE_RESTORE_ORDER)
	for index: int in range(rows):
		for other: int in range(index + 1, rows):
			if p_sequence[index] == p_sequence[other]:
				return _refuse(REFUSE_RESTORE_DUPLICATE)
	return true


# --- verification image -------------------------------------------------------------------------------

func state_bytes() -> PackedByteArray:
	"""Byte image of ALL authoritative state, for byte-identical refusal and rollback checks.

	NOT A PRODUCTION CALL and NOT §11's payload: the wire form SAVE-R09-005 froze is
	`next_sequence:i64` then `_count` 32-byte records, and no encoder for it exists. This image
	instead covers every column at its FULL 64-row length, so a stale row left beyond `_count`
	shows up as a byte difference rather than hiding behind the live prefix.
	"""
	var out: PackedByteArray = PackedByteArray()
	out.append_array(var_to_bytes(_kind))
	out.append_array(var_to_bytes(_source_id))
	out.append_array(var_to_bytes(_arg0))
	out.append_array(var_to_bytes(_arg1))
	out.append_array(var_to_bytes(_due_tick))
	out.append_array(var_to_bytes(_sequence))
	out.append_array(var_to_bytes(PackedInt64Array([_next_sequence, _count])))
	return out


func _refuse(reason: StringName) -> bool:
	"""Record an explicit refusal and return false. Never encodes a refusal as a value."""
	_last_refusal = reason
	return false
