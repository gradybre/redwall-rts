extends RefCounted
## R07-SCHED-001: ARCH-CMD-002's speed/pause scheduler-event queue -- the half of blocker U2
## that `commands.gd` deliberately left open.
##
## `commands.gd` carries ECONOMIC edits, due at `completed_tick + 1`. This carries SCHEDULER
## events: requested speed and pause reasons. They are a SEPARATE queue with a separate sequence
## space and a separate barrier, because a pause that waited for `completed_tick + 1` would wait
## for the very tick the pause exists to prevent.
##
## ---------------------------------------------------------------------------------------
## EVERY WIDTH, OFFSET, CAPACITY AND ENUM VALUE BELOW IS TRANSCRIBED FROM
## `docs/planning/ready07_scheduler_contract.md`, adopted by
## `docs/rulings/2026-09-11_ready07_open_item_answers.md` §3. Task 04.1 reserved them as
## amendment deliverables and said in terms that they are "not unspecified values a coder may
## choose at runtime". NONE of them is invented here; see decision 0054.
##
##   Record, 32 bytes little-endian:  boundary_tick i64 @0, sequence_low u32 @8,
##   sequence_high u32 @12, kind i32 @16, reason i32 @20, value i32 @24, reserved u32 @28.
##   Capacity 256 records = 8192 bytes; queue control 32 bytes; TOTAL 8224 bytes.
##   Initial head/count 0, next sequence (high 0, low 1), last applied (0,0),
##   last drained boundary -1.
##
## ---------------------------------------------------------------------------------------
## THE SEQUENCE COMPARISON IS UNSIGNED, for the same reason `commands.gd`'s is. The two words
## are u32 bits held in `PackedInt32Array` columns, so a counter crossing 0x80000000 stores a
## NEGATIVE i32 and a signed comparison would order 0x80000000 before 0x7fffffff -- silently
## reversing two scheduler events. `compare_sequence()` masks both words first. This sequence
## space is INDEPENDENT of the economic one: the two queues never share a number.
##
## EXHAUSTION REFUSES; IT NEVER WRAPS. The last usable u64 is all ones, so `_advance_sequence()`
## rolls from (0xffffffff, 0xffffffff) to (0, 0), which is the EXHAUSTED SENTINEL and never a
## valid event. From there every admission refuses SCHEDULER_SEQUENCE_EXHAUSTED and recovery is
## save/restart -- sequence 1 is never reused, because reusing it would make two distinct events
## compare equal in a replay stream.
##
## TAIL DERIVES FROM HEAD AND COUNT. Admission stamps monotonically increasing keys, so ring
## order IS canonical order and there is no order-index allocation (`commands.gd` needs one only
## because a stamped replay record may arrive out of key order). A record is FULLY INITIALIZED
## before `_count` is incremented, so a reader can never see a half-written row.
##
## ---------------------------------------------------------------------------------------
## THE BOUNDARY PUMP IS THE POINT OF THE WHOLE MODULE. `pump_into()` drains the admitted prefix
## for the CURRENT completed boundary, in sequence order, applying each event to the clock. It
## runs before every fixed-tick decision AND on paused host frames, and no simulation tick runs
## between two events of one prefix. `advance_frame()` is the wiring: pump, then let
## `sim_clock.advance()` pump again before each tick it considers running.
##
## `_last_drained_boundary` is DIAGNOSTIC. It never suppresses a second drain at the same
## boundary -- a paused frame stays at tick 0 forever and must keep accepting and applying
## events there, which is exactly how an unpause arrives.
##
## AN EVENT ADMITTED WHILE TICK k IS EXECUTING IS STAMPED k, NOT k-1. During `step`, the clock's
## `completed_tick()` still reads k-1, so `current_boundary()` adds one while `_executing` is
## set. The record stays in this same bounded ring and is drained only after k commits. It
## changes no speed or pause state midway through k.
##
## ---------------------------------------------------------------------------------------
## WHAT THIS DELIBERATELY DOES NOT DO:
##
##   * NO SAVE WRITER. `encode_extension_into()` / `restore_extension()` are the contract's
##     `SCHQ0001` subsection implemented in full, with validation, and they are UNWIRED: there is
##     no save module in this repository (task 09 owns the codec). The local codec round trip is
##     tested; the CROSS-PROCESS round trip is BLOCKED and reported as blocked, exactly as the
##     contract's closing section requires.
##
##   * NO SPEED/PAUSE KEY ENTERS `ARCH-CMD-003`'s CATALOG. Its 24 economic ids keep their
##     numbering; `KIND_SET_REQUESTED_SPEED`/`KIND_SET_PAUSE_REASON` are this queue's own
##     two-value domain and are not compiled into `catalog.gd`.
##
##   * THE OVERLOAD LADDER'S ARITHMETIC STAYS IN `sim_clock.gd`. This module only carries the
##     decided rung through the barrier; `overload_ladder_target()` still chooses it.
##
## ---------------------------------------------------------------------------------------
## THE LOAD BARRIER IS THE CLOCK'S, NOT A SECOND ONE (RESTORE-R01, decision 0104). This queue owns
## no barrier state and allocates none: `is_load_barrier_held()` below asks `_clock`, so the queue
## and the clock it applies events to can never disagree about whether a load is open. While it is
## held, EVERY admission, the pump, `clear()`, `rebind_clock()`, `begin_host_frame()` and
## `advance_frame()` refuse and change no queue state -- not one column, not the head, not the
## count, not the sequence, and not the refusal diagnostics either.
##
## `rebind_clock()` is barred for a second reason beyond the ruling naming it: this queue reads the
## barrier THROUGH its clock, so a rebind under a held barrier would be an escape from the barrier
## as well as a re-basing of stamped events.
##
## THE LOADER'S OWN INSTALL OPERATIONS PASS THROUGH, exactly as the clock's `restore_runtime()`
## does: `restore_extension()` and `restore_sequence()` are the section 12 install path, and the
## barrier is raised FOR them. `restore_extension()` therefore resets the columns through the
## private `_reset_to_initial_state()` rather than the public `clear()` it used to call, so that
## barring the public command cannot break the privileged path that shares its body.
##
## ---------------------------------------------------------------------------------------
## ALLOCATE BEFORE CONSUME. Every admission validates capacity, sequence room and the whole
## envelope BEFORE one column is written, so a refusal leaves the queue byte-identical -- same
## rows, same head, same count, same next sequence.

const IntMath := preload("res://scripts/core/int_math.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")

# --- the 32-byte record: offsets and stride ------------------------------------------------------

## Contract "Record and bounded storage", in its own order. Every one is asserted against a
## hard-coded literal in `test_scheduler_events.gd` so renaming a constant cannot move a field.
const OFFSET_BOUNDARY_TICK: int = 0
const OFFSET_SEQUENCE_LOW: int = 8
const OFFSET_SEQUENCE_HIGH: int = 12
const OFFSET_KIND: int = 16
const OFFSET_REASON: int = 20
const OFFSET_VALUE: int = 24
const OFFSET_RESERVED: int = 28
const RECORD_BYTES: int = 32
const FIELD_BYTES: int = 4
const TICK_FIELD_BYTES: int = 8

## Contract: "Capacity 256 records = 8192 bytes. Queue control is 32 bytes ... Total 8224 bytes."
const QUEUE_CAPACITY: int = 256
const RECORD_PAYLOAD_BYTES: int = QUEUE_CAPACITY * RECORD_BYTES
const CONTROL_BYTES: int = 32
const RUNTIME_PAYLOAD_BYTES: int = RECORD_PAYLOAD_BYTES + CONTROL_BYTES

## Contract: "Normal submissions are refused when count >= 250, leaving six slots for internal
## control events" -- at most five unmatched pause holds, one per reason, plus one overload
## downgrade, before the next frame's mandatory pump.
const NORMAL_CAPACITY: int = 250
const RESERVED_CONTROL_SLOTS: int = QUEUE_CAPACITY - NORMAL_CAPACITY

# --- the queue control header's own 32-byte layout ------------------------------------------------

const OFFSET_CONTROL_HEAD: int = 0
const OFFSET_CONTROL_COUNT: int = 4
const OFFSET_CONTROL_NEXT_SEQUENCE_LOW: int = 8
const OFFSET_CONTROL_NEXT_SEQUENCE_HIGH: int = 12
const OFFSET_CONTROL_LAST_DRAINED_BOUNDARY: int = 16
const OFFSET_CONTROL_LAST_APPLIED_SEQUENCE_LOW: int = 24
const OFFSET_CONTROL_LAST_APPLIED_SEQUENCE_HIGH: int = 28

# --- the two event kinds and their accepted values -------------------------------------------------

## Contract: "kind | I32 | 0 SET_REQUESTED_SPEED, 1 SET_PAUSE_REASON".
const KIND_SET_REQUESTED_SPEED: int = 0
const KIND_SET_PAUSE_REASON: int = 1
const KIND_COUNT: int = 2

## Contract: "SET_PAUSE_REASON accepts ... with value 0 (clear) or 1 (hold)".
const VALUE_CLEAR: int = 0
const VALUE_HOLD: int = 1

## Contract: "reason | I32 | 0 for speed; one existing pause bit for pause".
const SPEED_REASON_NONE: int = 0

## PRODUCER OWNERSHIP. The contract gives each pause reason exactly one owner ("Each producer is
## allowed only its own pause reason") and names no separate producer id space, so the producer
## IS its reason bit -- no numbering is invented here. `submit_player_resume_into()` is the
## "ordinary Resume clears PLAYER only" path, and CRITICAL/LOAD can only be cleared by naming
## their own owner, never by a generic UI toggle.
const PRODUCER_PLAYER: int = SimClock.PLAYER
const PRODUCER_MENU: int = SimClock.MENU
const PRODUCER_OVERLOAD: int = SimClock.CRITICAL
const PRODUCER_VICTORY: int = SimClock.VICTORY
const PRODUCER_LOADER: int = SimClock.LOAD

# --- sequence space --------------------------------------------------------------------------------

## Contract: "next sequence = (high 0, low 1)".
const INITIAL_SEQUENCE_HIGH: int = 0
const INITIAL_SEQUENCE_LOW: int = 1
## Contract: "last applied = (0,0)".
const INITIAL_APPLIED_HIGH: int = 0
const INITIAL_APPLIED_LOW: int = 0
## Contract: "last drained boundary = -1 (no prior drain)".
const NO_PRIOR_DRAIN: int = -1

## u32 bits in an i32 column, read the way ARCH-RNG-001 reads stored xorshift state.
const U32_MASK: int = 0xffffffff
const U32_MAX: int = 4294967295
const U32_SIGN_BIT: int = 2147483648
const U32_MODULUS: int = 4294967296

# --- save subsection `SCHQ0001` ---------------------------------------------------------------------

## Contract "Save and replay contract": tag 8 ASCII bytes, schema_version u32 = 1,
## payload_byte_length u32 = 32 + 32*count, the 32-byte control header with canonical head 0,
## then `count` records in queue order with no unused rows serialized.
const SECTION_TAG: String = "SCHQ0001"
const SECTION_TAG_BYTES: int = 8
const SECTION_SCHEMA_VERSION: int = 1
const OFFSET_EXTENSION_SCHEMA_VERSION: int = 8
const OFFSET_EXTENSION_PAYLOAD_LENGTH: int = 12
const EXTENSION_HEADER_BYTES: int = 16
## X = 48 + 32*S in the contract's own arithmetic.
const EXTENSION_FIXED_BYTES: int = EXTENSION_HEADER_BYTES + CONTROL_BYTES

## Contract, container version 2's section 12 prefix: "an exact 24-byte prefix, six U32 fields".
const SECTION_SCHEMA_VERSION_TWO: int = 2
const SECTION_PREFIX_BYTES: int = 24
const OFFSET_PREFIX_SECTION_SCHEMA: int = 0
const OFFSET_PREFIX_ECONOMIC_COUNT: int = 4
const OFFSET_PREFIX_ECONOMIC_PAYLOAD_USED: int = 8
const OFFSET_PREFIX_SCHEDULER_EXTENSION_BYTES: int = 12
const OFFSET_PREFIX_ECONOMIC_NEXT_SEQUENCE_LOW: int = 16
const OFFSET_PREFIX_ECONOMIC_NEXT_SEQUENCE_HIGH: int = 20
## Contract: "Require E <= 4096, P <= 1048576, S <= 256".
const MAX_ECONOMIC_RECORDS: int = 4096
const MAX_ECONOMIC_PAYLOAD_BYTES: int = 1048576
const ECONOMIC_RECORD_BYTES: int = 64

# --- refusal codes (StringName; this module never returns a sentinel to signal failure) -------------

const REFUSE_NONE: StringName = &""
const REFUSE_QUEUE_FULL: StringName = &"SCHEDULER_QUEUE_FULL"
const REFUSE_NORMAL_CAPACITY: StringName = &"SCHEDULER_NORMAL_CAPACITY_RESERVED"
const REFUSE_QUEUE_NOT_EMPTY: StringName = &"SCHEDULER_QUEUE_NOT_EMPTY"
const REFUSE_NO_CLOCK: StringName = &"SCHEDULER_NO_CLOCK"
const REFUSE_UNKNOWN_KIND: StringName = &"SCHEDULER_UNKNOWN_KIND"
const REFUSE_RESERVED_NONZERO: StringName = &"SCHEDULER_RESERVED_NONZERO"
const REFUSE_SPEED_NOT_SELECTABLE: StringName = &"SCHEDULER_SPEED_NOT_SELECTABLE"
const REFUSE_SPEED_REASON: StringName = &"SCHEDULER_SPEED_REASON_NONZERO"
const REFUSE_PAUSE_REASON: StringName = &"SCHEDULER_PAUSE_REASON_NOT_SINGLE"
const REFUSE_PAUSE_VALUE: StringName = &"SCHEDULER_PAUSE_VALUE"
const REFUSE_PRODUCER_NOT_OWNER: StringName = &"SCHEDULER_PRODUCER_NOT_REASON_OWNER"
const REFUSE_SEQUENCE_EXHAUSTED: StringName = &"SCHEDULER_SEQUENCE_EXHAUSTED"
const REFUSE_SEQUENCE_RANGE: StringName = &"SCHEDULER_SEQUENCE_RANGE"
const REFUSE_SEQUENCE_NOT_INCREASING: StringName = &"SCHEDULER_SEQUENCE_NOT_INCREASING"
const REFUSE_BOUNDARY_RANGE: StringName = &"SCHEDULER_BOUNDARY_RANGE"
const REFUSE_BOUNDARY_MISMATCH: StringName = &"SCHEDULER_BOUNDARY_MISMATCH"
const REFUSE_OVERLOAD_ALREADY_ISSUED: StringName = &"SCHEDULER_OVERLOAD_ALREADY_ISSUED"
const REFUSE_OVERLOAD_TARGET: StringName = &"SCHEDULER_OVERLOAD_TARGET"
const REFUSE_POSITION: StringName = &"SCHEDULER_POSITION_OUT_OF_RANGE"
const REFUSE_BUFFER_TOO_SMALL: StringName = &"SCHEDULER_BUFFER_TOO_SMALL"
const REFUSE_SECTION_TAG: StringName = &"SCHEDULER_SECTION_TAG"
const REFUSE_SECTION_VERSION: StringName = &"SCHEDULER_SECTION_VERSION"
const REFUSE_SECTION_LENGTH: StringName = &"SCHEDULER_SECTION_LENGTH"
const REFUSE_SECTION_COUNT: StringName = &"SCHEDULER_SECTION_COUNT"
const REFUSE_SECTION_HEAD: StringName = &"SCHEDULER_SECTION_HEAD"
const REFUSE_SECTION_CONTROL: StringName = &"SCHEDULER_SECTION_CONTROL"
const REFUSE_SECTION_APPLIED_ORDER: StringName = &"SCHEDULER_SECTION_APPLIED_ORDER"
## RESTORE-R01's shared barrier. Reported through the caller's `SubmitResult` only: a barred call
## deliberately leaves `last_refusal()` and `refused_count()` alone, because the barrier is not a
## property of the request and the queue must stay byte-identical across one.
const REFUSE_LOAD_BARRIER: StringName = &"SCHEDULER_LOAD_BARRIER"


class Event:
	"""One 32-byte scheduler-event record, caller-owned and reused.

	`sequence_low`/`sequence_high` hold u32 BITS in an i32 field, so 0x80000000 reads back as
	-2147483648; use the `_unsigned()` readers to compare. The QUEUE stamps `boundary_tick` and
	both sequence halves on every submission path except `admit_stamped_into()`, which is the one
	entry point that reads a replay stream's own envelope.
	"""
	var boundary_tick: int = 0
	var sequence_low: int = 0
	var sequence_high: int = 0
	var kind: int = 0
	var reason: int = 0
	var value: int = 0
	var reserved: int = 0

	func sequence_low_unsigned() -> int:
		"""The low sequence word as its unsigned value, the way this queue orders it."""
		return sequence_low & 0xffffffff

	func sequence_high_unsigned() -> int:
		"""The high sequence word as its unsigned value, the way this queue orders it."""
		return sequence_high & 0xffffffff

	func reset() -> void:
		"""Return every field to the empty envelope so one owned instance can be reused."""
		boundary_tick = 0
		sequence_low = 0
		sequence_high = 0
		kind = 0
		reason = 0
		value = 0
		reserved = 0


class SubmitResult:
	"""Outcome of one admission attempt, caller-owned and reused.

	`.ok` MUST be inspected first. THREE outcomes, not two: `ok && admitted` queued a record and
	consumed a sequence; `ok && coalesced` recognised an internal producer's duplicate hold as
	already held or already pending and consumed NOTHING, which the contract requires by name;
	`!ok` refused and left the queue byte-identical.
	"""
	var ok: bool = false
	var error: StringName = &""
	var admitted: bool = false
	var coalesced: bool = false
	var sequence_low: int = 0
	var sequence_high: int = 0

	func fill(p_ok: bool, p_error: StringName, p_admitted: bool, p_coalesced: bool) -> void:
		"""Overwrite this result in place, so an admission attempt allocates nothing."""
		ok = p_ok
		error = p_error
		admitted = p_admitted
		coalesced = p_coalesced
		sequence_low = 0
		sequence_high = 0


class PumpReport:
	"""What one boundary pump did, caller-owned and reused.

	`boundary_tick` is the completed boundary the pump drained at, which a paused frame repeats.
	"""
	var applied: int = 0
	var boundary_tick: int = 0
	var speed_events: int = 0
	var pause_events: int = 0

	func reset(p_boundary: int) -> void:
		"""Clear the counters and record the boundary this pump is about to drain."""
		applied = 0
		boundary_tick = p_boundary
		speed_events = 0
		pause_events = 0


# --- collaborating store ---------------------------------------------------------------------------

var _clock: SimClock = null

# --- the record columns: one i64 plus six i32 = exactly 32 bytes per row -----------------------------

var _boundary_tick: PackedInt64Array = PackedInt64Array()
var _sequence_low: PackedInt32Array = PackedInt32Array()
var _sequence_high: PackedInt32Array = PackedInt32Array()
var _kind: PackedInt32Array = PackedInt32Array()
var _reason: PackedInt32Array = PackedInt32Array()
var _value: PackedInt32Array = PackedInt32Array()
var _reserved: PackedInt32Array = PackedInt32Array()

# --- the 32-byte queue control ----------------------------------------------------------------------

var _head: int = 0
var _count: int = 0
var _next_sequence_low: int = INITIAL_SEQUENCE_LOW
var _next_sequence_high: int = INITIAL_SEQUENCE_HIGH
var _last_drained_boundary: int = NO_PRIOR_DRAIN
var _last_applied_sequence_low: int = INITIAL_APPLIED_LOW
var _last_applied_sequence_high: int = INITIAL_APPLIED_HIGH

# --- producer bounds and diagnostics (not part of the 8224-byte payload) -----------------------------

## True only while the caller's `step` callback is running inside a tick, so `current_boundary()`
## can stamp k rather than k-1 for an event produced from inside tick k.
var _executing: bool = false
## The contract's "at most one downgrade per host frame"; `begin_host_frame()` clears it.
var _overload_issued_this_frame: bool = false
var _last_refusal: StringName = REFUSE_NONE
var _admitted_count: int = 0
var _coalesced_count: int = 0
var _refused_count: int = 0
var _applied_count: int = 0
var _pump_count: int = 0

# --- scratch (not simulation state) ------------------------------------------------------------------

var _math: IntMath.IntResult = IntMath.IntResult.new()
var _scratch: Event = Event.new()
var _decode_scratch: Event = Event.new()
var _pump_scratch: PumpReport = PumpReport.new()
## Reused so the overload hook on the frame path allocates nothing.
var _overload_result: SubmitResult = SubmitResult.new()
## Bound once so the per-tick and per-frame hooks allocate no Callable on a hot path.
var _pump_callable: Callable = Callable()
var _step_callable: Callable = Callable()
var _overload_callable: Callable = Callable()
## The caller's per-tick step, held for the duration of one `advance_frame()` call.
var _hosted_step: Callable = Callable()


func _init(p_clock: SimClock = null) -> void:
	"""Bind the clock, prove the transcribed contract, and allocate the columns exactly once.

	Passing nothing builds a private clock, which is what a unit fixture wants: this queue applies
	every drained event to THAT clock, so a second clock would apply them to the wrong world.
	"""
	_clock = p_clock if p_clock != null else SimClock.new()
	_assert_contracts()
	_allocate_columns()
	_pump_callable = Callable(self, "_pump_hook")
	_step_callable = Callable(self, "_step_hook")
	_overload_callable = Callable(self, "_overload_hook")
	_reset_to_initial_state()


func _assert_contracts() -> void:
	"""Prove the record stride, the 8224-byte ledger row and the reserve arithmetic before use."""
	assert(OFFSET_RESERVED + FIELD_BYTES == RECORD_BYTES,
		"the contract's last field must end exactly at the 32-byte stride")
	assert(TICK_FIELD_BYTES + 6 * FIELD_BYTES == RECORD_BYTES,
		"the record is one i64 boundary plus six i32 fields")
	assert(RECORD_PAYLOAD_BYTES == 8192 and RUNTIME_PAYLOAD_BYTES == 8224,
		"256 records of 32 bytes plus a 32-byte control header is the ledger's 8224")
	assert(OFFSET_CONTROL_LAST_APPLIED_SEQUENCE_HIGH + FIELD_BYTES == CONTROL_BYTES,
		"the control header's last field must end exactly at 32 bytes")
	assert(RESERVED_CONTROL_SLOTS == SimClock.ALL_PAUSE_REASONS.size() + 1,
		"the reserve is five unmatched pause holds, one per reason, plus one overload downgrade")
	assert(EXTENSION_FIXED_BYTES == 48, "the contract's X = 48 + 32*S")


func _allocate_columns() -> void:
	"""Size every packed column exactly once, per ARCH-MEM-001. Never called again."""
	_boundary_tick.resize(QUEUE_CAPACITY)
	for column: PackedInt32Array in [_sequence_low, _sequence_high, _kind, _reason, _value,
			_reserved]:
		column.resize(QUEUE_CAPACITY)


func clear() -> bool:
	"""Return the queue and its sequence to the contract's stated initial state.

	This is world initialization, not a drain: it discards pending events and resets the sequence,
	so nothing that survives a save may call it.

	BARRED UNDER THE LOAD BARRIER, changing nothing: discarding a restored queue mid-load is the
	exact loss the barrier exists to prevent. Returns false then, and true when it ran, so the
	refusal is explicit rather than a silent no-op. `restore_extension()` reaches the same reset
	through `_reset_to_initial_state()`, which is the privileged install path.
	"""
	if _command_barred():
		return false
	_reset_to_initial_state()
	return true


func _reset_to_initial_state() -> void:
	"""The reset itself, with no barrier check: `clear()` and the section 12 install share it."""
	_boundary_tick.fill(0)
	for column: PackedInt32Array in [_sequence_low, _sequence_high, _kind, _reason, _value,
			_reserved]:
		column.fill(0)
	_head = 0
	_count = 0
	_next_sequence_low = INITIAL_SEQUENCE_LOW
	_next_sequence_high = INITIAL_SEQUENCE_HIGH
	_last_drained_boundary = NO_PRIOR_DRAIN
	_last_applied_sequence_low = INITIAL_APPLIED_LOW
	_last_applied_sequence_high = INITIAL_APPLIED_HIGH
	_executing = false
	_overload_issued_this_frame = false
	_last_refusal = REFUSE_NONE
	_admitted_count = 0
	_coalesced_count = 0
	_refused_count = 0
	_applied_count = 0
	_pump_count = 0


# --- unsigned sequence arithmetic ---------------------------------------------------------------------

static func compare_sequence(a_high: int, a_low: int, b_high: int, b_low: int) -> int:
	"""Order two 64-bit sequences by UNSIGNED high word then unsigned low word. Returns -1, 0, 1.

	Both words are masked first because they are u32 bits stored in an i32 field: a signed
	comparison orders 0x80000000 before 0x7fffffff and reverses two events the player issued in
	the opposite order, with no error anywhere.
	"""
	var high_a: int = a_high & U32_MASK
	var high_b: int = b_high & U32_MASK
	if high_a != high_b:
		return -1 if high_a < high_b else 1
	var low_a: int = a_low & U32_MASK
	var low_b: int = b_low & U32_MASK
	if low_a != low_b:
		return -1 if low_a < low_b else 1
	return 0


static func to_int32_bits(value: int) -> int:
	"""The i32 two's-complement spelling of a u32 bit pattern, so a packed i32 column stores it."""
	var bits: int = value & U32_MASK
	return bits - U32_MODULUS if bits >= U32_SIGN_BIT else bits


static func to_uint32(value: int) -> int:
	"""The unsigned value of a u32 bit pattern held in an i32 field."""
	return value & U32_MASK


func _advance_sequence() -> void:
	"""Step the 64-bit session sequence by one. The roll past all-ones LANDS ON THE SENTINEL.

	(0xffffffff, 0xffffffff) is the last usable sequence, so the next state is (0, 0), which
	`is_sequence_exhausted()` reports and every admission path refuses. Sequence 1 is never
	reused.
	"""
	if _next_sequence_low >= U32_MAX:
		_next_sequence_low = 0
		_next_sequence_high = (_next_sequence_high + 1) & U32_MASK
		return
	_next_sequence_low += 1


func is_sequence_exhausted() -> bool:
	"""True once the session sequence has rolled onto the (0,0) exhausted sentinel."""
	return _next_sequence_high == 0 and _next_sequence_low == 0


# --- envelope validation -------------------------------------------------------------------------------

func event_refusal(event: Event) -> StringName:
	"""Every field rule the contract states, evaluated without touching the queue.

	`reserved` must be zero because the contract names it so; a nonzero value is REFUSED rather
	than masked away, because an accepted undefined bit would be a semantic this file invented.
	"""
	if event.reserved != 0:
		return REFUSE_RESERVED_NONZERO
	if event.boundary_tick < 0:
		return REFUSE_BOUNDARY_RANGE
	if event.kind == KIND_SET_REQUESTED_SPEED:
		return _speed_refusal(event.reason, event.value)
	if event.kind == KIND_SET_PAUSE_REASON:
		return _pause_refusal(event.reason, event.value)
	return REFUSE_UNKNOWN_KIND


func _speed_refusal(reason: int, value: int) -> StringName:
	"""Contract: "SET_REQUESTED_SPEED accepts reason 0 / value 1, 2, 4 only."

	Zero is the EFFECTIVE pause produced by the reason mask, not a selectable speed, and 3x has
	never existed. Both refuse rather than clamping to a neighbour.
	"""
	if reason != SPEED_REASON_NONE:
		return REFUSE_SPEED_REASON
	if not SimClock.SELECTABLE_SPEEDS.has(value):
		return REFUSE_SPEED_NOT_SELECTABLE
	return REFUSE_NONE


func _pause_refusal(reason: int, value: int) -> StringName:
	"""Contract: exactly PLAYER 1, MENU 2, CRITICAL 4, VICTORY 8 or LOAD 16, value 0 or 1.

	Composites and unknown bits are rejected: one event names one reason, so that closing one
	reason can never clear another.
	"""
	if not SimClock.ALL_PAUSE_REASONS.has(reason):
		return REFUSE_PAUSE_REASON
	if value != VALUE_CLEAR and value != VALUE_HOLD:
		return REFUSE_PAUSE_VALUE
	return REFUSE_NONE


func _capacity_refusal(reserve_eligible: bool) -> StringName:
	"""The 256/250 split: normal traffic stops at 250 so internal control events always fit."""
	if _count >= QUEUE_CAPACITY:
		return REFUSE_QUEUE_FULL
	if not reserve_eligible and _count >= NORMAL_CAPACITY:
		return REFUSE_NORMAL_CAPACITY
	return REFUSE_NONE


func _admission_refusal(event: Event, reserve_eligible: bool) -> StringName:
	"""Every capacity, sequence and envelope gate, evaluated before anything is written."""
	var refusal: StringName = _capacity_refusal(reserve_eligible)
	if refusal != REFUSE_NONE:
		return refusal
	if is_sequence_exhausted():
		return REFUSE_SEQUENCE_EXHAUSTED
	return event_refusal(event)


# --- the shared load barrier -------------------------------------------------------------------------

func is_load_barrier_held() -> bool:
	"""True while a load holds THE CLOCK'S barrier. This queue keeps no barrier state of its own."""
	return _clock.is_load_barrier_held()


func _command_barred() -> bool:
	"""True when the barrier bars an OPERATIONAL queue command. Every guarded entry calls this.

	That surface is every `submit_*`/`admit_*` admission, `pump_into`, `clear`, `rebind_clock`,
	`begin_host_frame` and `advance_frame`. `restore_extension()` and `restore_sequence()` are
	deliberately NOT on it -- they are the loader's own install operations, and the barrier is
	raised for them rather than against them.
	"""
	return _clock.is_load_barrier_held()


func _refuse_barred(out: SubmitResult) -> bool:
	"""Report a barred admission in the caller's result while leaving this queue untouched.

	`out` is caller-owned memory, so filling it is output, not mutation: leaving a reused result
	carrying a previous success would let a careless caller read `ok` and believe its event was
	admitted. The queue's own `_refused_count`/`_last_refusal` are deliberately NOT touched, which
	is what makes "the barrier changed nothing" a comparison a test can make exactly.
	"""
	out.fill(false, REFUSE_LOAD_BARRIER, false, false)
	return false


# --- admission ------------------------------------------------------------------------------------------

func submit_speed_into(value: int, out: SubmitResult) -> bool:
	"""Queue the player's requested speed (1, 2 or 4) for the current boundary.

	Normal traffic, so it refuses at 250 queued events rather than eating the control reserve.
	A repeat of the speed already requested is still admitted and still takes a new sequence: the
	contract coalesces only an INTERNAL producer's duplicate pause hold, never a user repeat.

	Barred under the load barrier: a speed the player asked for during a load is a command against
	a world still being installed, and the restored queue gains no record of it.
	"""
	if _command_barred():
		return _refuse_barred(out)
	_scratch.reset()
	_scratch.kind = KIND_SET_REQUESTED_SPEED
	_scratch.reason = SPEED_REASON_NONE
	_scratch.value = value
	return _submit_stamped(_scratch, false, out)


func submit_pause_into(producer: int, reason: int, value: int, out: SubmitResult) -> bool:
	"""Queue one pause hold or clear, refusing any producer that does not own that reason.

	Normal traffic. Ownership is the contract's "Each producer is allowed only its own pause
	reason": a generic UI toggle cannot clear CRITICAL or LOAD, because it cannot name itself
	their owner. The producer constants ARE the reason bits, so no id space is invented.

	Barred under the load barrier, BEFORE the ownership check, so a barred call cannot be recorded
	as an ownership refusal either. `submit_player_resume_into()` is barred through this.
	"""
	if _command_barred():
		return _refuse_barred(out)
	if producer != reason:
		return _refuse(out, REFUSE_PRODUCER_NOT_OWNER)
	_scratch.reset()
	_scratch.kind = KIND_SET_PAUSE_REASON
	_scratch.reason = reason
	_scratch.value = value
	return _submit_stamped(_scratch, false, out)


func submit_player_resume_into(out: SubmitResult) -> bool:
	"""The ordinary Resume: clear PLAYER and nothing else, whatever else still holds the clock.

	The contract spells this out because it is the mistake worth preventing -- a Resume button
	that cleared the whole mask would resume out of a MENU, a LOAD or an overload CRITICAL pause.
	"""
	return submit_pause_into(PRODUCER_PLAYER, SimClock.PLAYER, VALUE_CLEAR, out)


func submit_safety_hold_into(reason: int, out: SubmitResult) -> bool:
	"""Queue an INTERNAL producer's pause hold, coalescing a duplicate and using the reserve.

	Contract: "Internal identical holds coalesce before admission; scan pending operations so a
	hold after a pending clear is not incorrectly dropped." A coalesced hold returns ok with
	`admitted` false and CONSUMES NO SEQUENCE. Reserve-eligible, so a safety pause is never the
	admission the 250-record normal cap refuses.

	Barred under the load barrier before the coalescing scan, so a barred hold neither joins the
	queue nor counts as coalesced against a queue the load is still installing.
	"""
	if _command_barred():
		return _refuse_barred(out)
	var refusal: StringName = _pause_refusal(reason, VALUE_HOLD)
	if refusal != REFUSE_NONE:
		return _refuse(out, refusal)
	if _pending_pause_state(reason) == VALUE_HOLD:
		_coalesced_count += 1
		_last_refusal = REFUSE_NONE
		out.fill(true, REFUSE_NONE, false, true)
		return true
	_scratch.reset()
	_scratch.kind = KIND_SET_PAUSE_REASON
	_scratch.reason = reason
	_scratch.value = VALUE_HOLD
	return _submit_stamped(_scratch, true, out)


func _pending_pause_state(reason: int) -> int:
	"""Whether `reason` would be held once every pending event for it has been applied.

	Scans the pending operations rather than reading the live mask alone, so a hold queued AFTER
	a pending clear is recognised as a real change and is not dropped as a duplicate.
	"""
	var held: int = VALUE_HOLD if _clock.has_pause_reason(reason) else VALUE_CLEAR
	for position: int in _count:
		var row: int = _row_at(position)
		if _kind[row] == KIND_SET_PAUSE_REASON and _reason[row] == reason:
			held = _value[row]
	return held


func submit_overload_downgrade_into(target_speed: int, out: SubmitResult) -> bool:
	"""Queue one REQ-SET-008 ladder rung through the same barrier every other event crosses.

	`target_speed` is `sim_clock.overload_ladder_target()`'s answer: 2, 1, or SPEED_PAUSED meaning
	the CRITICAL diagnostic hold. Reserve-eligible and AT MOST ONE PER HOST FRAME -- the contract
	requires the next frame to pump before another can be produced, which `begin_host_frame()`
	enforces by clearing the flag.

	Barred under the load barrier: no frame advances during a load, so no overload can have
	happened, and this frame's single issue is left unspent.
	"""
	if _command_barred():
		return _refuse_barred(out)
	if _overload_issued_this_frame:
		return _refuse(out, REFUSE_OVERLOAD_ALREADY_ISSUED)
	if target_speed == SimClock.SPEED_PAUSED:
		return _submit_overload_record(KIND_SET_PAUSE_REASON, SimClock.CRITICAL, VALUE_HOLD, out)
	if target_speed != SimClock.SPEED_NORMAL and target_speed != SimClock.SPEED_DOUBLE:
		return _refuse(out, REFUSE_OVERLOAD_TARGET)
	return _submit_overload_record(KIND_SET_REQUESTED_SPEED, SPEED_REASON_NONE, target_speed, out)


func _submit_overload_record(kind: int, reason: int, value: int, out: SubmitResult) -> bool:
	"""Admit one overload rung from the reserve and, on success, spend this frame's one issue."""
	_scratch.reset()
	_scratch.kind = kind
	_scratch.reason = reason
	_scratch.value = value
	if not _submit_stamped(_scratch, true, out):
		return false
	_overload_issued_this_frame = true
	return true


func _submit_stamped(event: Event, reserve_eligible: bool, out: SubmitResult) -> bool:
	"""Stamp the current boundary and the next sequence onto a validated event, then commit it."""
	if not IntMath.checked_add_into(_clock.completed_tick(), _executing_offset(), _math):
		return _refuse(out, REFUSE_BOUNDARY_RANGE)
	event.boundary_tick = _math.value
	var refusal: StringName = _admission_refusal(event, reserve_eligible)
	if refusal != REFUSE_NONE:
		return _refuse(out, refusal)
	var high: int = to_int32_bits(_next_sequence_high)
	var low: int = to_int32_bits(_next_sequence_low)
	_write_row(_tail_row(), event, event.boundary_tick, high, low)
	_count += 1
	_advance_sequence()
	return _accept(out, high, low)


func admit_stamped_into(event: Event, out: SubmitResult) -> bool:
	"""Admit one record that carries its own envelope, as a replay or load stream supplies it.

	Contract: "Imported replay records with non-increasing sequence, past/future barrier or
	invalid fields refuse." The session counter is NOT advanced -- a loader restores it with
	`restore_sequence()`. The (0,0) sentinel is never a valid event and refuses here too.

	Barred under the load barrier: this is admission, which the ruling bars by name. The section 12
	load path does NOT come through here -- `restore_extension()` installs a saved queue wholesale,
	and it is the operation the barrier is raised for.
	"""
	if _command_barred():
		return _refuse_barred(out)
	var refusal: StringName = _stamped_envelope_refusal(event)
	if refusal == REFUSE_NONE:
		refusal = _admission_refusal(event, false)
	if refusal != REFUSE_NONE:
		return _refuse(out, refusal)
	_write_row(_tail_row(), event, event.boundary_tick, event.sequence_high, event.sequence_low)
	_count += 1
	return _accept(out, event.sequence_high, event.sequence_low)


func _stamped_envelope_refusal(event: Event) -> StringName:
	"""Validate the boundary and sequence a stamped record supplies for itself."""
	if not IntMath.fits_int32(event.sequence_low) or not IntMath.fits_int32(event.sequence_high):
		return REFUSE_SEQUENCE_RANGE
	if event.sequence_high_unsigned() == 0 and event.sequence_low_unsigned() == 0:
		return REFUSE_SEQUENCE_EXHAUSTED
	if event.boundary_tick != current_boundary():
		return REFUSE_BOUNDARY_MISMATCH
	return _sequence_order_refusal(event.sequence_high, event.sequence_low)


func _sequence_order_refusal(high: int, low: int) -> StringName:
	"""Refuse a sequence that does not strictly follow the last applied one and the queued tail."""
	if compare_sequence(high, low, _last_applied_sequence_high, _last_applied_sequence_low) <= 0:
		return REFUSE_SEQUENCE_NOT_INCREASING
	if _count == 0:
		return REFUSE_NONE
	var tail: int = _row_at(_count - 1)
	if compare_sequence(high, low, _sequence_high[tail], _sequence_low[tail]) <= 0:
		return REFUSE_SEQUENCE_NOT_INCREASING
	return REFUSE_NONE


# --- commit ---------------------------------------------------------------------------------------------

func _row_at(position: int) -> int:
	"""The storage row holding the event at queue position `position`. The tail derives from head."""
	return (_head + position) % QUEUE_CAPACITY


func _tail_row() -> int:
	"""The free row one past the last queued event. Valid only when `_count < QUEUE_CAPACITY`."""
	return (_head + _count) % QUEUE_CAPACITY


func _write_row(row: int, event: Event, boundary: int, high: int, low: int) -> void:
	"""Fill one storage row completely. The caller increments `_count` only AFTER this returns.

	That ordering is the contract's "Record state must be fully initialized before incrementing
	count": no reader can be handed a row carrying one field of a previous occupant.
	"""
	_boundary_tick[row] = boundary
	_sequence_high[row] = high
	_sequence_low[row] = low
	_kind[row] = event.kind
	_reason[row] = event.reason
	_value[row] = event.value
	_reserved[row] = 0


func _accept(out: SubmitResult, high: int, low: int) -> bool:
	"""Record an admitted event and return true, reporting the sequence it took."""
	_admitted_count += 1
	_last_refusal = REFUSE_NONE
	out.fill(true, REFUSE_NONE, true, false)
	out.sequence_high = to_uint32(high)
	out.sequence_low = to_uint32(low)
	return true


func _refuse(out: SubmitResult, code: StringName) -> bool:
	"""Record a refusal that wrote nothing, changed no sequence, and return false."""
	_refused_count += 1
	_last_refusal = code
	out.fill(false, code, false, false)
	return false


# --- the boundary pump -------------------------------------------------------------------------------------

func _executing_offset() -> int:
	"""How far the effective boundary leads `completed_tick()`: 1 inside a tick, 0 between ticks.

	THE ONLY PLACE THAT `+1` IS WRITTEN. `current_boundary()` reports it and `_submit_stamped()`
	stamps it, and if those two ever disagreed a record would be admitted at a boundary the
	admission check validated against a different one.
	"""
	return 1 if _executing else 0


func current_boundary() -> int:
	"""The effective completed boundary an event submitted right now is stamped with.

	`completed_tick()` normally, but `completed_tick() + 1` while the caller's `step` runs, because
	tick k has not committed yet and the contract forbids stamping k-1 and reinterpreting it.
	"""
	return _clock.completed_tick() + _executing_offset()


func pump_into(out: PumpReport) -> int:
	"""Drain and apply the admitted prefix for the current completed boundary, in sequence order.

	Runs between fixed ticks AND on paused host frames, which is what lets an unpause arrive
	without waiting for the tick the pause prevents. No simulation tick runs between two events of
	one prefix. Returns the number applied.

	BARRED UNDER THE LOAD BARRIER, which is RESTORE-R01's "checked before scheduler pumping" at the
	queue itself rather than only in a coordinator. Nothing is drained, applied or counted; `out`
	is reset to zero applied so a reused report cannot be read as this pump's result. The 0 is
	true, and `is_load_barrier_held()` separates it from a pump that had nothing due.
	"""
	if _command_barred():
		out.reset(_clock.completed_tick())
		return 0
	var boundary: int = _clock.completed_tick()
	out.reset(boundary)
	while _count > 0 and _boundary_tick[_head] <= boundary:
		_apply_row(_head, out)
		_last_applied_sequence_high = to_uint32(_sequence_high[_head])
		_last_applied_sequence_low = to_uint32(_sequence_low[_head])
		_head = (_head + 1) % QUEUE_CAPACITY
		_count -= 1
	_last_drained_boundary = boundary
	_pump_count += 1
	_applied_count += out.applied
	return out.applied


func _apply_row(row: int, out: PumpReport) -> void:
	"""Apply one drained record to the clock. Admission already proved every field is legal."""
	out.applied += 1
	if _kind[row] == KIND_SET_REQUESTED_SPEED:
		out.speed_events += 1
		var accepted: bool = _clock.set_speed(_value[row])
		assert(accepted, "an admitted speed event must be one the clock accepts")
		return
	out.pause_events += 1
	var applied: bool = _clock.set_pause(_reason[row], _value[row] == VALUE_HOLD)
	assert(applied, "an admitted pause event must name one reason the clock knows")


func pump() -> int:
	"""Non-allocating `pump_into()` for a caller that wants no report. Returns events applied."""
	return pump_into(_pump_scratch)


func _pump_hook() -> void:
	"""The per-tick barrier handed to `sim_clock.advance()`; it decides nothing, it only drains."""
	pump_into(_pump_scratch)


func _step_hook() -> void:
	"""Wrap the host's per-tick callback so admissions made inside tick k are stamped k, not k-1."""
	_executing = true
	if _hosted_step.is_valid():
		_hosted_step.call()
	_executing = false


func _overload_hook() -> void:
	"""Carry one REQ-SET-008 rung through the queue instead of applying it inside the frame.

	The clock still chooses the rung and still records its own diagnostics and signal; only the
	authoritative speed/pause change is deferred to the next pump, which the contract places
	before that frame's ticks. A refused submission leaves the ladder unrecorded rather than
	claiming a downgrade that never happened.
	"""
	var target: int = _clock.overload_ladder_target()
	if not submit_overload_downgrade_into(target, _overload_result):
		return
	_clock.note_overload_step(target)


func begin_host_frame() -> bool:
	"""Open one host frame: the overload producer regains its single downgrade for this frame.

	Barred under the load barrier, where there is no host frame to open. Returns whether it ran.
	"""
	if _command_barred():
		return false
	_open_host_frame()
	return true


func _open_host_frame() -> void:
	"""Restore this frame's single overload issue, with no barrier check. Shared with the guard."""
	_overload_issued_this_frame = false


func advance_frame(elapsed_microseconds: int, step: Callable = Callable(),
		day_boundary: Callable = Callable()) -> int:
	"""One host frame: pump the barrier, then run whatever ticks the clock's debt has earned.

	The opening pump is what runs on a PAUSED frame, where `sim_clock.advance()` returns 0 before
	considering any tick. Inside the frame the same pump runs again before each tick decision, so
	a pause admitted during tick 3 of an eight-tick catch-up stops tick 4.

	BARRED UNDER THE LOAD BARRIER before the frame is opened, so a load that spans many host frames
	pumps nothing and folds no elapsed time into the clock. `sim_clock.advance()` refuses the same
	frame on its own account; both guards are deliberate, because either entry point can be reached
	directly through the raw objects a coordinator hands out.
	"""
	if _command_barred():
		return 0
	_open_host_frame()
	pump_into(_pump_scratch)
	_hosted_step = step
	var ran: int = _clock.advance(elapsed_microseconds, _step_callable, day_boundary,
		_pump_callable, _overload_callable)
	_hosted_step = Callable()
	return ran


# --- reading -------------------------------------------------------------------------------------------------

func read_into(position: int, out: Event) -> bool:
	"""Read the event at queue position `position` (0 is next) into a caller-owned record."""
	if position < 0 or position >= _count:
		_last_refusal = REFUSE_POSITION
		return false
	_read_row(_row_at(position), out)
	return true


func peek_into(out: Event) -> bool:
	"""Read the event at the head of the queue without draining it."""
	return read_into(0, out)


func _read_row(row: int, out: Event) -> void:
	"""Copy storage row `row` into a caller-owned record."""
	out.boundary_tick = _boundary_tick[row]
	out.sequence_low = _sequence_low[row]
	out.sequence_high = _sequence_high[row]
	out.kind = _kind[row]
	out.reason = _reason[row]
	out.value = _value[row]
	out.reserved = _reserved[row]


# --- record serialization ---------------------------------------------------------------------------------------

static func encode_event_into(event: Event, out: PackedByteArray, byte_offset: int) -> bool:
	"""Write one record at the contract's exact 32-byte little-endian layout.

	The ONLY encoder in this module, so a moved offset moves in one place. Refuses a buffer that
	cannot hold the whole record rather than writing a partial one.
	"""
	if byte_offset < 0 or out.size() < byte_offset + RECORD_BYTES:
		return false
	out.encode_s64(byte_offset + OFFSET_BOUNDARY_TICK, event.boundary_tick)
	out.encode_u32(byte_offset + OFFSET_SEQUENCE_LOW, to_uint32(event.sequence_low))
	out.encode_u32(byte_offset + OFFSET_SEQUENCE_HIGH, to_uint32(event.sequence_high))
	out.encode_s32(byte_offset + OFFSET_KIND, event.kind)
	out.encode_s32(byte_offset + OFFSET_REASON, event.reason)
	out.encode_s32(byte_offset + OFFSET_VALUE, event.value)
	out.encode_u32(byte_offset + OFFSET_RESERVED, to_uint32(event.reserved))
	return true


static func decode_event_into(bytes: PackedByteArray, byte_offset: int, out: Event) -> bool:
	"""Read the contract's 32 bytes back into a caller-owned record.

	Structural only: it bounds-checks and fills every field, INCLUDING a nonzero `reserved`, so
	that `event_refusal()` can reject it. It never repairs a record.
	"""
	if byte_offset < 0 or bytes.size() < byte_offset + RECORD_BYTES:
		return false
	out.boundary_tick = bytes.decode_s64(byte_offset + OFFSET_BOUNDARY_TICK)
	out.sequence_low = to_int32_bits(bytes.decode_u32(byte_offset + OFFSET_SEQUENCE_LOW))
	out.sequence_high = to_int32_bits(bytes.decode_u32(byte_offset + OFFSET_SEQUENCE_HIGH))
	out.kind = bytes.decode_s32(byte_offset + OFFSET_KIND)
	out.reason = bytes.decode_s32(byte_offset + OFFSET_REASON)
	out.value = bytes.decode_s32(byte_offset + OFFSET_VALUE)
	out.reserved = bytes.decode_u32(byte_offset + OFFSET_RESERVED)
	return true


func encode_record_into(position: int, out: PackedByteArray, byte_offset: int) -> bool:
	"""Encode the queued event at `position`, for a save or replay writer. Unwired: none exists."""
	if position < 0 or position >= _count:
		_last_refusal = REFUSE_POSITION
		return false
	_read_row(_row_at(position), _scratch)
	if not encode_event_into(_scratch, out, byte_offset):
		_last_refusal = REFUSE_BUFFER_TOO_SMALL
		return false
	return true


# --- the `SCHQ0001` save subsection --------------------------------------------------------------------------------

func extension_byte_length() -> int:
	"""The contract's X = 48 + 32*S for this queue's current pending count."""
	return EXTENSION_FIXED_BYTES + RECORD_BYTES * _count


func encode_control_into(out: PackedByteArray, byte_offset: int, canonical_head: bool) -> bool:
	"""Write the 32-byte queue control header. `canonical_head` writes head 0, as a save requires."""
	if byte_offset < 0 or out.size() < byte_offset + CONTROL_BYTES:
		return false
	out.encode_s32(byte_offset + OFFSET_CONTROL_HEAD, 0 if canonical_head else _head)
	out.encode_s32(byte_offset + OFFSET_CONTROL_COUNT, _count)
	out.encode_u32(byte_offset + OFFSET_CONTROL_NEXT_SEQUENCE_LOW, _next_sequence_low)
	out.encode_u32(byte_offset + OFFSET_CONTROL_NEXT_SEQUENCE_HIGH, _next_sequence_high)
	out.encode_s64(byte_offset + OFFSET_CONTROL_LAST_DRAINED_BOUNDARY, _last_drained_boundary)
	out.encode_u32(byte_offset + OFFSET_CONTROL_LAST_APPLIED_SEQUENCE_LOW,
		_last_applied_sequence_low)
	out.encode_u32(byte_offset + OFFSET_CONTROL_LAST_APPLIED_SEQUENCE_HIGH,
		_last_applied_sequence_high)
	return true


func encode_extension_into(out: PackedByteArray, byte_offset: int) -> bool:
	"""Write the whole `SCHQ0001` subsection: tag, version, length, control, then the records.

	UNWIRED. These are exactly the bytes task 09's codec needs and nothing in this repository
	calls them, because no save module exists. The cross-process round trip is BLOCKED; the
	local one is tested.
	"""
	var length: int = extension_byte_length()
	if byte_offset < 0 or out.size() < byte_offset + length:
		_last_refusal = REFUSE_BUFFER_TOO_SMALL
		return false
	for index: int in SECTION_TAG_BYTES:
		out.encode_u8(byte_offset + index, SECTION_TAG.unicode_at(index))
	out.encode_u32(byte_offset + OFFSET_EXTENSION_SCHEMA_VERSION, SECTION_SCHEMA_VERSION)
	out.encode_u32(byte_offset + OFFSET_EXTENSION_PAYLOAD_LENGTH,
		CONTROL_BYTES + RECORD_BYTES * _count)
	encode_control_into(out, byte_offset + EXTENSION_HEADER_BYTES, true)
	for position: int in _count:
		_read_row(_row_at(position), _scratch)
		encode_event_into(_scratch, out,
			byte_offset + EXTENSION_FIXED_BYTES + position * RECORD_BYTES)
	_last_refusal = REFUSE_NONE
	return true


func extension_refusal(bytes: PackedByteArray, byte_offset: int, saved_completed_tick: int) -> StringName:
	"""Validate a whole `SCHQ0001` subsection WITHOUT touching this queue. REFUSE_NONE when clean.

	The contract requires every length, the count bound, sequence bounds, reason ownership rules,
	zero padding and `pending boundary == saved completed tick` to be checked BEFORE world
	mutation. `restore_extension()` runs this first and writes only when it answers clean.
	"""
	var refusal: StringName = _extension_header_refusal(bytes, byte_offset)
	if refusal != REFUSE_NONE:
		return refusal
	var count: int = bytes.decode_s32(byte_offset + EXTENSION_HEADER_BYTES + OFFSET_CONTROL_COUNT)
	refusal = _extension_control_refusal(bytes, byte_offset, count)
	if refusal != REFUSE_NONE:
		return refusal
	return _extension_records_refusal(bytes, byte_offset, count, saved_completed_tick)


func _extension_header_refusal(bytes: PackedByteArray, byte_offset: int) -> StringName:
	"""Check the 8-byte tag, the schema version, the declared payload length and the ring head."""
	if byte_offset < 0 or bytes.size() < byte_offset + EXTENSION_FIXED_BYTES:
		return REFUSE_SECTION_LENGTH
	for index: int in SECTION_TAG_BYTES:
		if bytes.decode_u8(byte_offset + index) != SECTION_TAG.unicode_at(index):
			return REFUSE_SECTION_TAG
	if bytes.decode_u32(byte_offset + OFFSET_EXTENSION_SCHEMA_VERSION) != SECTION_SCHEMA_VERSION:
		return REFUSE_SECTION_VERSION
	var control: int = byte_offset + EXTENSION_HEADER_BYTES
	if bytes.decode_s32(control + OFFSET_CONTROL_HEAD) != 0:
		return REFUSE_SECTION_HEAD
	var count: int = bytes.decode_s32(control + OFFSET_CONTROL_COUNT)
	if count < 0 or count > QUEUE_CAPACITY:
		return REFUSE_SECTION_COUNT
	return _extension_length_refusal(bytes, byte_offset, count)


func _extension_length_refusal(bytes: PackedByteArray, byte_offset: int, count: int) -> StringName:
	"""Agree the declared payload length, the count and the buffer's actual extent, or refuse."""
	if bytes.decode_u32(byte_offset + OFFSET_EXTENSION_PAYLOAD_LENGTH) \
			!= CONTROL_BYTES + RECORD_BYTES * count:
		return REFUSE_SECTION_LENGTH
	if bytes.size() < byte_offset + EXTENSION_FIXED_BYTES + RECORD_BYTES * count:
		return REFUSE_SECTION_LENGTH
	return REFUSE_NONE


func _extension_control_refusal(bytes: PackedByteArray, byte_offset: int, count: int) -> StringName:
	"""Check the control header's own invariants: a real drain boundary and a usable sequence."""
	var control: int = byte_offset + EXTENSION_HEADER_BYTES
	if bytes.decode_s64(control + OFFSET_CONTROL_LAST_DRAINED_BOUNDARY) < NO_PRIOR_DRAIN:
		return REFUSE_SECTION_CONTROL
	var next_high: int = bytes.decode_u32(control + OFFSET_CONTROL_NEXT_SEQUENCE_HIGH)
	var next_low: int = bytes.decode_u32(control + OFFSET_CONTROL_NEXT_SEQUENCE_LOW)
	if count == 0 or (next_high == 0 and next_low == 0):
		return REFUSE_NONE
	var last: int = byte_offset + EXTENSION_FIXED_BYTES + (count - 1) * RECORD_BYTES
	var high: int = bytes.decode_u32(last + OFFSET_SEQUENCE_HIGH)
	var low: int = bytes.decode_u32(last + OFFSET_SEQUENCE_LOW)
	if compare_sequence(next_high, next_low, high, low) <= 0:
		return REFUSE_SECTION_CONTROL
	return REFUSE_NONE


func _extension_records_refusal(bytes: PackedByteArray, byte_offset: int, count: int,
		saved_completed_tick: int) -> StringName:
	"""Validate every serialized record: fields, zero padding, boundary and strict sequence order."""
	var control: int = byte_offset + EXTENSION_HEADER_BYTES
	var high: int = bytes.decode_u32(control + OFFSET_CONTROL_LAST_APPLIED_SEQUENCE_HIGH)
	var low: int = bytes.decode_u32(control + OFFSET_CONTROL_LAST_APPLIED_SEQUENCE_LOW)
	for index: int in count:
		decode_event_into(bytes, byte_offset + EXTENSION_FIXED_BYTES + index * RECORD_BYTES,
			_decode_scratch)
		var refusal: StringName = event_refusal(_decode_scratch)
		if refusal != REFUSE_NONE:
			return refusal
		if _decode_scratch.boundary_tick != saved_completed_tick:
			return REFUSE_BOUNDARY_MISMATCH
		var record_high: int = _decode_scratch.sequence_high_unsigned()
		var record_low: int = _decode_scratch.sequence_low_unsigned()
		if record_high == 0 and record_low == 0:
			return REFUSE_SEQUENCE_EXHAUSTED
		if compare_sequence(record_high, record_low, high, low) <= 0:
			return REFUSE_SECTION_APPLIED_ORDER if index == 0 else REFUSE_SEQUENCE_NOT_INCREASING
		high = record_high
		low = record_low
	return REFUSE_NONE


func restore_extension(bytes: PackedByteArray, byte_offset: int, saved_completed_tick: int) -> bool:
	"""Replace this queue from a validated `SCHQ0001` subsection. Refuses before mutating anything.

	Restores records from row 0 with every unused row zeroed, so two loads of the same bytes
	produce byte-identical columns. `clear()` runs only after validation has passed, which is what
	makes a rejected file leave the live queue untouched.

	PASSES THROUGH THE LOAD BARRIER. This is the section 12 install the barrier is raised for, so it
	is not guarded; it resets through `_reset_to_initial_state()` rather than the public `clear()`,
	which IS guarded, so that the command and the install cannot be confused for one another.
	"""
	var refusal: StringName = extension_refusal(bytes, byte_offset, saved_completed_tick)
	if refusal != REFUSE_NONE:
		_last_refusal = refusal
		return false
	var control: int = byte_offset + EXTENSION_HEADER_BYTES
	var count: int = bytes.decode_s32(control + OFFSET_CONTROL_COUNT)
	_reset_to_initial_state()
	for index: int in count:
		decode_event_into(bytes, byte_offset + EXTENSION_FIXED_BYTES + index * RECORD_BYTES,
			_decode_scratch)
		_write_row(index, _decode_scratch, _decode_scratch.boundary_tick,
			_decode_scratch.sequence_high, _decode_scratch.sequence_low)
	_count = count
	_restore_control(bytes, control)
	_last_refusal = REFUSE_NONE
	return true


func _restore_control(bytes: PackedByteArray, control: int) -> void:
	"""Take the validated control header's counters back into this queue's live state."""
	_head = 0
	_next_sequence_low = bytes.decode_u32(control + OFFSET_CONTROL_NEXT_SEQUENCE_LOW)
	_next_sequence_high = bytes.decode_u32(control + OFFSET_CONTROL_NEXT_SEQUENCE_HIGH)
	_last_drained_boundary = bytes.decode_s64(control + OFFSET_CONTROL_LAST_DRAINED_BOUNDARY)
	_last_applied_sequence_low = bytes.decode_u32(control + OFFSET_CONTROL_LAST_APPLIED_SEQUENCE_LOW)
	_last_applied_sequence_high = bytes.decode_u32(
		control + OFFSET_CONTROL_LAST_APPLIED_SEQUENCE_HIGH)


# --- container version 2's section 12 arithmetic (pure; it reads no economic store) ----------------------------------

static func section_twelve_length(economic_count: int, economic_payload_used: int,
		scheduler_count: int) -> int:
	"""The contract's `72 + 64*E + P + 32*S`. Returns a length, never a failure sentinel.

	Callers validate the three inputs with `section_twelve_refusal()` FIRST; this is arithmetic,
	not a gate. It exists so the prefix's `scheduler_extension_bytes` and the section directory's
	own length cannot be derived twice from two different formulas.
	"""
	return SECTION_PREFIX_BYTES + ECONOMIC_RECORD_BYTES * economic_count \
		+ economic_payload_used + EXTENSION_FIXED_BYTES + RECORD_BYTES * scheduler_count


static func section_twelve_refusal(economic_count: int, economic_payload_used: int,
		scheduler_count: int) -> StringName:
	"""The contract's "Require E <= 4096, P <= 1048576, S <= 256" and nonnegativity."""
	if economic_count < 0 or economic_count > MAX_ECONOMIC_RECORDS:
		return REFUSE_SECTION_COUNT
	if economic_payload_used < 0 or economic_payload_used > MAX_ECONOMIC_PAYLOAD_BYTES:
		return REFUSE_SECTION_LENGTH
	if scheduler_count < 0 or scheduler_count > QUEUE_CAPACITY:
		return REFUSE_SECTION_COUNT
	return REFUSE_NONE


static func encode_section_prefix_into(out: PackedByteArray, byte_offset: int, economic_count: int,
		economic_payload_used: int, scheduler_count: int, economic_next_low: int,
		economic_next_high: int) -> bool:
	"""Write the exact 24-byte prefix: six u32 in the contract's stated order.

	`economic_next_sequence_*` preserve `commands.gd`'s own allocator semantics, NOT this
	scheduler's initial-1 / (0,0)-sentinel policy; the two sequence spaces never mix.
	"""
	if byte_offset < 0 or out.size() < byte_offset + SECTION_PREFIX_BYTES:
		return false
	if section_twelve_refusal(economic_count, economic_payload_used, scheduler_count) != REFUSE_NONE:
		return false
	out.encode_u32(byte_offset + OFFSET_PREFIX_SECTION_SCHEMA, SECTION_SCHEMA_VERSION_TWO)
	out.encode_u32(byte_offset + OFFSET_PREFIX_ECONOMIC_COUNT, economic_count)
	out.encode_u32(byte_offset + OFFSET_PREFIX_ECONOMIC_PAYLOAD_USED, economic_payload_used)
	out.encode_u32(byte_offset + OFFSET_PREFIX_SCHEDULER_EXTENSION_BYTES,
		EXTENSION_FIXED_BYTES + RECORD_BYTES * scheduler_count)
	out.encode_u32(byte_offset + OFFSET_PREFIX_ECONOMIC_NEXT_SEQUENCE_LOW, economic_next_low)
	out.encode_u32(byte_offset + OFFSET_PREFIX_ECONOMIC_NEXT_SEQUENCE_HIGH, economic_next_high)
	return true


# --- loader hooks, capacity and diagnostics -----------------------------------------------------------------------

func restore_sequence(high: int, low: int) -> bool:
	"""Set the session sequence a loaded world resumes from. Only legal on an EMPTY queue.

	Restoring under a non-empty queue could mint a number already in it, so it refuses instead.
	(0,0) is accepted here and only here: a world whose sequence was exhausted before the save
	must come back exhausted rather than silently restarting at 1.

	PASSES THROUGH THE LOAD BARRIER, as the loader hook it is.
	"""
	if high < 0 or high > U32_MAX or low < 0 or low > U32_MAX:
		_last_refusal = REFUSE_SEQUENCE_RANGE
		return false
	if _count != 0:
		_last_refusal = REFUSE_QUEUE_NOT_EMPTY
		return false
	_next_sequence_high = high
	_next_sequence_low = low
	_last_refusal = REFUSE_NONE
	return true


func rebind_clock(p_clock: SimClock) -> bool:
	"""Point this queue at another clock. Only legal on an EMPTY queue, and never at null.

	Pending events were stamped against the OLD clock's tick numbering, so re-basing them would
	silently move when a pause or a speed change takes effect.

	BARRED UNDER THE LOAD BARRIER, and doubly so: the ruling names rebind, and this queue reads the
	barrier THROUGH `_clock`, so a rebind under a held barrier would be an escape from the barrier
	itself. A load installs into the clock it already has; it never swaps one in.
	"""
	if _command_barred():
		return false
	if p_clock == null:
		_last_refusal = REFUSE_NO_CLOCK
		return false
	if _count != 0:
		_last_refusal = REFUSE_QUEUE_NOT_EMPTY
		return false
	_clock = p_clock
	_last_refusal = REFUSE_NONE
	return true


func capacity() -> int:
	"""The contract's 256-record bound."""
	return QUEUE_CAPACITY


func normal_capacity() -> int:
	"""The count at which NORMAL submissions start refusing, leaving the control reserve."""
	return NORMAL_CAPACITY


func pending_count() -> int:
	"""How many admitted events are queued and undrained."""
	return _count


func free_count() -> int:
	"""How many more events of any class the queue can hold."""
	return QUEUE_CAPACITY - _count


func head_position() -> int:
	"""The ring row the next drained event occupies. Diagnostic; the tail derives from it."""
	return _head


func next_sequence_high() -> int:
	"""The unsigned high word the next stamped event will carry."""
	return _next_sequence_high


func next_sequence_low() -> int:
	"""The unsigned low word the next stamped event will carry."""
	return _next_sequence_low


func last_applied_sequence_high() -> int:
	"""Unsigned high word of the last event this queue applied to the clock."""
	return _last_applied_sequence_high


func last_applied_sequence_low() -> int:
	"""Unsigned low word of the last event this queue applied to the clock."""
	return _last_applied_sequence_low


func last_drained_boundary() -> int:
	"""The boundary of the most recent pump, or -1 before the first. DIAGNOSTIC ONLY.

	It never suppresses a second drain at the same boundary: a paused frame stays at one tick and
	must keep applying events there, which is how the unpause itself arrives.
	"""
	return _last_drained_boundary


func overload_issued_this_frame() -> bool:
	"""Whether the overload producer has already spent this host frame's one downgrade."""
	return _overload_issued_this_frame


func is_executing_tick() -> bool:
	"""True while the hosted per-tick step is running, when submissions stamp `completed_tick+1`."""
	return _executing


func admitted_count() -> int:
	"""How many events this queue has admitted since `clear()`."""
	return _admitted_count


func coalesced_count() -> int:
	"""Internal duplicate holds recognised as already held, which consumed no sequence."""
	return _coalesced_count


func refused_count() -> int:
	"""How many admission attempts this queue has refused since `clear()`."""
	return _refused_count


func applied_count() -> int:
	"""How many events the pump has applied to the clock since `clear()`."""
	return _applied_count


func pump_count() -> int:
	"""How many boundary pumps have run since `clear()`, including those that drained nothing."""
	return _pump_count


func last_refusal() -> StringName:
	"""The most recent refusal code, or REFUSE_NONE after a successful admission."""
	return _last_refusal


func clock() -> SimClock:
	"""The clock every drained event is applied to, so a caller can share exactly this one."""
	return _clock
