extends "res://test/framework/test_case.gd"
## Coverage for §11 EVENT_SCHEDULE's store, `godot/scripts/core/event_schedule.gd`.
##
## Every expected value below is restated from the SPECIFICATION, not read back out of the module:
## the eight field keys, their types and ordinals from `docs/planning/canonical_state_registry.json`
## (`section_id 11`, `owner_key "event_schedule"`); the 64-record maximum, the 32-byte record order
## `kind, source_id, arg0, arg1, due_tick, sequence`, the initial sequence 1 and the zero-means-
## exhausted rule from SAVE-R09-005 (`docs/rulings/2026-09-11_save_codec_contract.md:164-188`); and
## the offset calendar -- 30 ticks/s, 18000 ticks/day, `(tick + 4500) mod 18000`, first midnight at
## tick 13500 -- from `docs/systems_architecture.md` and `sim_clock.gd`'s own contract.
##
## FOUR TESTS EXIST TO KILL FOUR SPECIFIC MUTATIONS:
##   * `test_a_refused_*` -- a refusal that still mutates. They compare FULL state images byte for
##     byte, so a consumed sequence or a half-written row cannot hide behind a false return.
##   * `test_the_declared_field_*` -- a field renamed, retyped or renumbered against the registry.
##   * `test_the_next_day_boundary_*` -- a day boundary computed as `tick % 18000` instead of
##     `(tick + 4500) % 18000`. Tick 0's answer is 13500, and 18000 is 06:00 of day 2.
##   * `test_a_cancelled_row_leaves_no_stale_tail` -- a tail row left live beyond `_count`. Two
##     observationally identical schedules must image identically (decision 0103's reasoning).

const EventSchedule := preload("res://scripts/core/event_schedule.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")

## The registry's eight declared field keys, in its declared ordinal order 0..7.
const DECLARED_KEYS: Array[String] = ["_next_sequence", "_count", "_kind", "_source_id", "_arg0",
	"_arg1", "_due_tick", "_sequence"]
## The registry's declared `type_code` per ordinal: i64 = 4, u32 = 1, i32 = 2.
const DECLARED_TYPE_CODES: Array[int] = [4, 1, 2, 2, 2, 2, 4, 4]

## The offset calendar, restated. 750 ticks per hour, 18000 per day, midnight offset 4500.
const TICKS_PER_DAY: int = 18000
const CALENDAR_OFFSET: int = 4500
const FIRST_MIDNIGHT: int = 13500
const SECOND_MIDNIGHT: int = 31500
## What a raw `tick % 18000` reading would produce for tick 0. It is 06:00 of day 2, not midnight.
const RAW_MODULO_WRONG_ANSWER: int = 18000

const INT32_MAX: int = 2147483647
const INT32_MIN: int = -2147483648
## Positive as a 64-bit GDScript int; `-2147483648` is its int32 reading. Must never be stored.
const INT32_OVERFLOW: int = 0x80000000

var _store: EventSchedule = null
var _result: IntMath.IntResult = null
var _event: EventSchedule.Event = null


func before_each() -> void:
	"""A fresh empty schedule and reusable result objects for every test."""
	_store = EventSchedule.new()
	_result = IntMath.IntResult.new()
	_event = EventSchedule.Event.new()


func _schedule(kind: int, due_tick: int, now_tick: int) -> int:
	"""Schedule one event with zeroed arguments and return its issued sequence, failing if refused."""
	if not _store.schedule_into(kind, 0, 0, 0, due_tick, now_tick, _result):
		fail("schedule(kind=%d, due=%d) refused: %s" % [kind, due_tick, _result.error])
		return 0
	return _result.value


# --- the declared contract ---------------------------------------------------------------------

func test_the_declared_owner_identity_matches_the_registry() -> void:
	"""Section 11, owner key `event_schedule`, owner schema version 1."""
	assert_equal(EventSchedule.SECTION_ID, 11, "section id")
	assert_equal(EventSchedule.OWNER_KEY, "event_schedule", "owner key")
	assert_equal(EventSchedule.OWNER_SCHEMA_VERSION, 1, "owner schema version")
	assert_equal(EventSchedule.ROW_ORDER, "due_tick_then_sequence", "declared row order")


func test_the_declared_field_keys_keep_the_registry_order_and_ordinals() -> void:
	"""Eight keys, underscores kept, ordinals 0..7 exactly as declared."""
	assert_equal(EventSchedule.FIELD_KEYS.size(), 8, "eight declared fields")
	for ordinal: int in range(DECLARED_KEYS.size()):
		assert_equal(EventSchedule.FIELD_KEYS[ordinal], DECLARED_KEYS[ordinal],
			"ordinal %d key" % ordinal)
	assert_equal(EventSchedule.ORDINAL_NEXT_SEQUENCE, 0, "_next_sequence ordinal")
	assert_equal(EventSchedule.ORDINAL_COUNT, 1, "_count ordinal")
	assert_equal(EventSchedule.ORDINAL_KIND, 2, "_kind ordinal")
	assert_equal(EventSchedule.ORDINAL_SEQUENCE, 7, "_sequence ordinal")


func test_the_declared_field_types_match_the_registry_type_codes() -> void:
	"""`_next_sequence`, `_due_tick` and `_sequence` are i64; `_count` is u32; the rest i32."""
	assert_equal(EventSchedule.FIELD_TYPE_CODES.size(), 8, "eight declared type codes")
	for ordinal: int in range(DECLARED_TYPE_CODES.size()):
		assert_equal(EventSchedule.FIELD_TYPE_CODES[ordinal], DECLARED_TYPE_CODES[ordinal],
			"ordinal %d type code" % ordinal)


func test_the_record_layout_is_save_r09_005s_thirty_two_byte_stride() -> void:
	"""`kind, source_id, arg0, arg1, due_tick, sequence`, 32 bytes, 64 records maximum."""
	assert_equal(EventSchedule.CAPACITY, 64, "declared max_count")
	assert_equal(EventSchedule.RECORD_BYTES, 32, "record stride")
	assert_equal(EventSchedule.OFFSET_KIND, 0, "kind offset")
	assert_equal(EventSchedule.OFFSET_SOURCE_ID, 4, "source_id offset")
	assert_equal(EventSchedule.OFFSET_ARG0, 8, "arg0 offset")
	assert_equal(EventSchedule.OFFSET_ARG1, 12, "arg1 offset")
	assert_equal(EventSchedule.OFFSET_DUE_TICK, 16, "due_tick offset")
	assert_equal(EventSchedule.OFFSET_SEQUENCE, 24, "sequence offset")
	assert_equal(EventSchedule.MAX_PAYLOAD_BYTES, 8 + 32 * 64, "8 + 32*N at N = 64")


func test_a_new_schedule_is_empty_with_the_allocator_at_one() -> void:
	"""SAVE-R09-005: "Initial next_sequence 1". Zero would mean exhausted, not empty."""
	assert_equal(_store.count(), 0, "no rows")
	assert_true(_store.is_empty(), "empty")
	assert_false(_store.is_full(), "not full")
	assert_equal(_store.next_sequence(), 1, "initial allocator")
	assert_false(_store.is_sequence_exhausted(), "not exhausted")
	assert_equal(_store.capacity(), 64, "capacity")


# --- insertion and ordering --------------------------------------------------------------------

func test_sequences_are_issued_from_one_and_never_repeat() -> void:
	"""Successive insertions take 1, 2, 3 and leave the allocator one past the last issued."""
	assert_equal(_schedule(0, 100, 0), 1, "first sequence")
	assert_equal(_schedule(0, 200, 0), 2, "second sequence")
	assert_equal(_schedule(0, 300, 0), 3, "third sequence")
	assert_equal(_store.next_sequence(), 4, "allocator past the last issued")
	assert_equal(_store.count(), 3, "three live rows")


func test_rows_are_held_sorted_by_due_tick_then_sequence() -> void:
	"""Out-of-order insertions land in `(due_tick, sequence)` order, which is the declared order."""
	_schedule(10, 500, 0)
	_schedule(11, 100, 0)
	_schedule(12, 500, 0)
	_schedule(13, 300, 0)
	var expected_kinds: Array[int] = [11, 13, 10, 12]
	var expected_due: Array[int] = [100, 300, 500, 500]
	for row: int in range(4):
		assert_true(_store.read_into(row, _event), "row %d readable" % row)
		assert_equal(_event.kind, expected_kinds[row], "row %d kind" % row)
		assert_equal(_event.due_tick, expected_due[row], "row %d due tick" % row)
	assert_true(_store.read_into(2, _event), "equal-due first row")
	assert_equal(_event.sequence, 1, "the earlier sequence sorts first among equal due ticks")


func test_every_stored_field_reads_back_unchanged() -> void:
	"""The four i32 arguments and the i64 due tick survive insertion exactly."""
	assert_true(_store.schedule_into(7, INT32_MIN, INT32_MAX, -1, 999, 0, _result), "scheduled")
	assert_true(_store.read_into(0, _event), "row readable")
	assert_equal(_event.kind, 7, "kind")
	assert_equal(_event.source_id, INT32_MIN, "source id at the int32 floor")
	assert_equal(_event.arg0, INT32_MAX, "arg0 at the int32 ceiling")
	assert_equal(_event.arg1, -1, "arg1")
	assert_equal(_event.due_tick, 999, "due tick")
	assert_equal(_event.sequence, 1, "sequence")


# --- refusals that must leave the store byte-identical ------------------------------------------

func test_a_refused_past_due_tick_leaves_the_store_byte_identical() -> void:
	"""SAVE-R09-005 forbids silently expired rows, so a due tick at or before now refuses."""
	_schedule(1, 100, 0)
	var before: PackedByteArray = _store.state_bytes()
	assert_false(_store.schedule_into(2, 0, 0, 0, 50, 50, _result), "due == now refuses")
	assert_equal(_result.error, "EVENT_DUE_TICK_NOT_FUTURE", "refusal reason")
	assert_false(_store.schedule_into(2, 0, 0, 0, 49, 50, _result), "due < now refuses")
	assert_true(_store.state_bytes() == before, "two refusals changed not one byte")
	assert_equal(_store.next_sequence(), 2, "no sequence was consumed")


func test_a_refused_non_int32_argument_leaves_the_store_byte_identical() -> void:
	"""`0x80000000` is positive in GDScript and `-2147483648` in an i32 column; it must refuse."""
	var before: PackedByteArray = _store.state_bytes()
	assert_false(_store.schedule_into(0, 0, INT32_OVERFLOW, 0, 100, 0, _result), "arg0 refuses")
	assert_equal(_result.error, "EVENT_FIELD_NOT_INT32", "refusal reason")
	assert_false(_store.schedule_into(INT32_MIN - 1, 0, 0, 0, 100, 0, _result), "kind refuses")
	assert_false(_store.schedule_into(0, INT32_MAX + 1, 0, 0, 100, 0, _result), "source refuses")
	assert_false(_store.schedule_into(0, 0, 0, INT32_OVERFLOW, 100, 0, _result), "arg1 refuses")
	assert_true(_store.state_bytes() == before, "four refusals changed not one byte")
	assert_equal(_store.count(), 0, "nothing was inserted")
	assert_equal(_store.next_sequence(), 1, "no sequence was consumed")


func test_a_refused_insertion_into_a_full_schedule_consumes_no_sequence() -> void:
	"""SAVE-R09-005: "Capacity failure must not consume a sequence"."""
	for index: int in range(64):
		_schedule(index, index + 1, 0)
	assert_true(_store.is_full(), "64 rows fills the declared capacity")
	assert_equal(_store.next_sequence(), 65, "64 sequences issued")
	var before: PackedByteArray = _store.state_bytes()
	assert_false(_store.schedule_into(0, 0, 0, 0, 5000, 0, _result), "the 65th refuses")
	assert_equal(_result.error, "EVENT_SCHEDULE_FULL", "refusal reason")
	assert_true(_store.state_bytes() == before, "the refusal changed not one byte")
	assert_equal(_store.next_sequence(), 65, "the allocator did not move")


func test_an_exhausted_allocator_refuses_every_insertion() -> void:
	"""Zero means exhausted, never a small sequence: from there insertion refuses atomically."""
	assert_true(_store.restore_rows(0, PackedInt32Array(), PackedInt32Array(), PackedInt32Array(),
		PackedInt32Array(), PackedInt64Array(), PackedInt64Array()), "restored as exhausted")
	assert_true(_store.is_sequence_exhausted(), "exhausted")
	var before: PackedByteArray = _store.state_bytes()
	assert_false(_store.schedule_into(0, 0, 0, 0, 100, 0, _result), "insertion refuses")
	assert_equal(_result.error, "EVENT_SEQUENCE_EXHAUSTED", "refusal reason")
	assert_true(_store.state_bytes() == before, "the refusal changed not one byte")


func test_the_allocator_exhausts_rather_than_wrapping_to_one() -> void:
	"""Issuing INT64_MAX leaves the allocator at 0; sequence 1 is never reused."""
	assert_true(_store.restore_rows(IntMath.INT64_MAX, PackedInt32Array(), PackedInt32Array(),
		PackedInt32Array(), PackedInt32Array(), PackedInt64Array(), PackedInt64Array()),
		"restored at the last usable sequence")
	assert_equal(_schedule(0, 100, 0), IntMath.INT64_MAX, "the last sequence is issued")
	assert_true(_store.is_sequence_exhausted(), "the allocator is now exhausted")
	assert_equal(_store.next_sequence(), 0, "exhausted reads as 0, not 1")


# --- removal, the stale tail and the no-silent-expiry rule ---------------------------------------

func test_a_cancelled_row_leaves_no_stale_tail() -> void:
	"""A schedule that once held a cancelled event must image identically to one that never did."""
	_schedule(41, 100, 0)
	_schedule(42, 200, 0)
	assert_true(_store.cancel(2), "the second event cancels")
	var other: EventSchedule = EventSchedule.new()
	assert_true(other.restore_rows(3, PackedInt32Array([41]), PackedInt32Array([0]),
		PackedInt32Array([0]), PackedInt32Array([0]), PackedInt64Array([100]),
		PackedInt64Array([1])), "the same live state, installed directly")
	assert_true(_store.state_bytes() == other.state_bytes(),
		"two observationally identical schedules must produce identical bytes")


func test_a_popped_row_leaves_no_stale_tail() -> void:
	"""Popping the only due row must zero the vacated row, not leave it live beyond the count."""
	_schedule(41, 100, 0)
	_schedule(42, 200, 0)
	assert_true(_store.pop_due_into(150, _event), "the first row pops")
	assert_equal(_event.kind, 41, "the earliest due row was returned")
	var other: EventSchedule = EventSchedule.new()
	assert_true(other.restore_rows(3, PackedInt32Array([42]), PackedInt32Array([0]),
		PackedInt32Array([0]), PackedInt32Array([0]), PackedInt64Array([200]),
		PackedInt64Array([2])), "the same live state, installed directly")
	assert_true(_store.state_bytes() == other.state_bytes(), "no stale tail after a pop")


func test_cancelling_an_unknown_sequence_refuses_and_changes_nothing() -> void:
	"""A sequence that was never issued, and one already cancelled, both refuse explicitly."""
	_schedule(1, 100, 0)
	assert_true(_store.cancel(1), "the live sequence cancels")
	var before: PackedByteArray = _store.state_bytes()
	assert_false(_store.cancel(1), "cancelling it twice refuses")
	assert_equal(String(_store.last_refusal()), "EVENT_SEQUENCE_NOT_SCHEDULED", "refusal reason")
	assert_false(_store.cancel(99), "an unissued sequence refuses")
	assert_true(_store.state_bytes() == before, "two refusals changed not one byte")


func test_a_due_row_never_expires_on_its_own() -> void:
	"""SAVE-R09-005: "no silently expired rows". A due row stays until a consumer pops it."""
	_schedule(5, 100, 0)
	assert_equal(_store.due_count(99), 0, "not yet due")
	assert_false(_store.has_due(99), "not yet due")
	assert_equal(_store.due_count(100), 1, "due at its own tick")
	assert_equal(_store.due_count(100000), 1, "still due long afterwards")
	assert_equal(_store.count(), 1, "querying due rows removed nothing")
	assert_true(_store.pop_due_into(100000, _event), "only a pop removes it")
	assert_equal(_store.count(), 0, "now removed")


func test_popping_with_nothing_due_returns_a_cleared_event() -> void:
	"""An empty answer, not a refusal: `sequence == 0` can never be read as a live event."""
	_schedule(9, 500, 0)
	_event.kind = 77
	_event.sequence = 88
	assert_false(_store.pop_due_into(100, _event), "nothing is due yet")
	assert_equal(_event.sequence, 0, "the event was cleared, not left stale")
	assert_equal(_event.kind, 0, "every field was cleared")
	assert_equal(_store.count(), 1, "the row is untouched")


func test_reading_outside_the_live_rows_refuses_and_clears() -> void:
	"""There is no sentinel row: an out-of-range read refuses and zeroes the caller's Event."""
	_schedule(6, 100, 0)
	assert_true(_store.read_into(0, _event), "row 0 is live")
	assert_false(_store.read_into(1, _event), "row 1 is not")
	assert_equal(String(_store.last_refusal()), "EVENT_ROW_OUT_OF_RANGE", "refusal reason")
	assert_equal(_event.sequence, 0, "the stale row was cleared")
	assert_false(_store.read_into(-1, _event), "a negative index refuses")


func test_find_sequence_refuses_instead_of_returning_a_sentinel() -> void:
	"""Row 0 is a legal index, so an absent sequence must refuse rather than answer -1."""
	_schedule(1, 100, 0)
	assert_true(_store.find_sequence_into(1, _result), "the issued sequence is found")
	assert_equal(_result.value, 0, "it is at row 0")
	assert_false(_store.find_sequence_into(2, _result), "an unissued sequence refuses")
	assert_equal(_result.error, "EVENT_SEQUENCE_NOT_SCHEDULED", "refusal reason")
	assert_equal(_result.value, 0, "a refusal carries no index, which is why .ok must be read")


# --- the offset calendar ------------------------------------------------------------------------

func test_the_next_day_boundary_after_tick_zero_is_the_first_midnight() -> void:
	"""`(tick + 4500) mod 18000`: tick 0 is 06:00, so the next midnight is 13500, not 18000."""
	assert_true(EventSchedule.next_day_boundary_after_into(0, _result), "computed")
	assert_equal(_result.value, FIRST_MIDNIGHT, "the first midnight is tick 13500")
	assert_false(_result.value == RAW_MODULO_WRONG_ANSWER,
		"tick %d is 06:00 of day 2, which a raw `tick %% 18000` would have returned"
			% RAW_MODULO_WRONG_ANSWER)
	assert_true(SimClock.is_day_boundary(_result.value), "the clock agrees it is a crossing")


func test_the_next_day_boundary_is_strictly_after_the_given_tick() -> void:
	"""Asked at a midnight, the answer is the NEXT one; asked one tick before, it is that one."""
	assert_true(EventSchedule.next_day_boundary_after_into(FIRST_MIDNIGHT - 1, _result), "computed")
	assert_equal(_result.value, FIRST_MIDNIGHT, "one tick before midnight")
	assert_true(EventSchedule.next_day_boundary_after_into(FIRST_MIDNIGHT, _result), "computed")
	assert_equal(_result.value, SECOND_MIDNIGHT, "strictly after, so the next day")
	assert_true(EventSchedule.next_day_boundary_after_into(TICKS_PER_DAY, _result), "computed")
	assert_equal(_result.value, SECOND_MIDNIGHT, "tick 18000 is 06:00 of day 2, not a crossing")
	assert_false(EventSchedule.next_day_boundary_after_into(-1, _result), "a negative tick refuses")


func test_every_computed_boundary_satisfies_the_offset_formula() -> void:
	"""Sampled across two days, every answer satisfies `(t + 4500) mod 18000 == 0`."""
	for tick: int in range(0, 2 * TICKS_PER_DAY, 997):
		assert_true(EventSchedule.next_day_boundary_after_into(tick, _result), "computed")
		assert_equal((_result.value + CALENDAR_OFFSET) % TICKS_PER_DAY, 0,
			"tick %d maps to an offset-calendar midnight" % tick)
		assert_true(_result.value > tick, "strictly after tick %d" % tick)


func test_the_due_day_index_uses_the_offset_calendar() -> void:
	"""Tick 13499 is still day 0; 13500 opens day 1. A raw `tick / 18000` would say 0 for both."""
	_schedule(1, FIRST_MIDNIGHT - 1, 0)
	_schedule(2, FIRST_MIDNIGHT, 0)
	_schedule(3, SECOND_MIDNIGHT, 0)
	assert_true(_store.due_day_index_into(0, _result), "row 0")
	assert_equal(_result.value, 0, "tick 13499 falls on day 0")
	assert_true(_store.due_day_index_into(1, _result), "row 1")
	assert_equal(_result.value, 1, "tick 13500 opens day 1")
	assert_true(_store.due_day_index_into(2, _result), "row 2")
	assert_equal(_result.value, 2, "tick 31500 opens day 2")
	assert_false(_store.due_day_index_into(3, _result), "no fourth row")


func test_scheduling_at_the_next_day_boundary_lands_on_midnight() -> void:
	"""The convenience path is the ordinary validated insertion with a calendar-derived due tick."""
	assert_true(_store.schedule_at_next_day_boundary_into(4, 0, 0, 0, 0, _result), "scheduled")
	assert_equal(_result.value, 1, "the issued sequence")
	assert_true(_store.read_into(0, _event), "row readable")
	assert_equal(_event.due_tick, FIRST_MIDNIGHT, "due at the first midnight")
	assert_true(SimClock.is_day_boundary(_event.due_tick), "the clock agrees it is a crossing")
	var before: PackedByteArray = _store.state_bytes()
	assert_false(_store.schedule_at_next_day_boundary_into(4, 0, 0, 0, -1, _result), "refuses")
	assert_true(_store.state_bytes() == before, "the refusal changed not one byte")


# --- restore ------------------------------------------------------------------------------------

func test_restore_installs_a_valid_schedule() -> void:
	"""Decoded columns in, validated state out. This is not a decoder; §11's codec does not exist."""
	assert_true(_store.restore_rows(9, PackedInt32Array([3, 4]), PackedInt32Array([10, 11]),
		PackedInt32Array([20, 21]), PackedInt32Array([30, 31]), PackedInt64Array([100, 100]),
		PackedInt64Array([5, 8])), "installed")
	assert_equal(_store.count(), 2, "two rows")
	assert_equal(_store.next_sequence(), 9, "the allocator came from the file, not from the rows")
	assert_true(_store.read_into(1, _event), "row 1 readable")
	assert_equal(_event.kind, 4, "kind")
	assert_equal(_event.source_id, 11, "source id")
	assert_equal(_event.arg0, 21, "arg0")
	assert_equal(_event.arg1, 31, "arg1")
	assert_equal(_event.sequence, 8, "sequence")


func _refuse_restore(next_sequence: int, due: PackedInt64Array, sequences: PackedInt64Array,
		reason: String, label: String) -> void:
	"""Assert one restore payload refuses with `reason` and leaves the store byte-identical."""
	var before: PackedByteArray = _store.state_bytes()
	var columns: PackedInt32Array = PackedInt32Array()
	columns.resize(due.size())
	assert_false(_store.restore_rows(next_sequence, columns, columns, columns, columns, due,
		sequences), label)
	assert_equal(String(_store.last_refusal()), reason, "%s reason" % label)
	assert_true(_store.state_bytes() == before, "%s changed not one byte" % label)


func test_restore_refuses_every_invariant_violation_atomically() -> void:
	"""Order, uniqueness, sequence range and tick sign are all checked before anything is written."""
	_refuse_restore(9, PackedInt64Array([200, 100]), PackedInt64Array([1, 2]),
		"EVENT_RESTORE_ORDER", "rows out of due order")
	_refuse_restore(9, PackedInt64Array([100, 100]), PackedInt64Array([5, 5]),
		"EVENT_RESTORE_ORDER", "equal due ticks with a non-increasing sequence")
	_refuse_restore(9, PackedInt64Array([100, 200]), PackedInt64Array([5, 5]),
		"EVENT_RESTORE_DUPLICATE_SEQUENCE", "one sequence used twice")
	_refuse_restore(9, PackedInt64Array([100]), PackedInt64Array([0]),
		"EVENT_RESTORE_SEQUENCE_RANGE", "sequence 0 is the exhausted marker, never a row")
	_refuse_restore(5, PackedInt64Array([100]), PackedInt64Array([5]),
		"EVENT_RESTORE_SEQUENCE_RANGE", "a row at or above next_sequence")
	_refuse_restore(9, PackedInt64Array([-1]), PackedInt64Array([5]),
		"EVENT_TICK_NEGATIVE", "a negative due tick")
	_refuse_restore(-1, PackedInt64Array([100]), PackedInt64Array([5]),
		"EVENT_RESTORE_ALLOCATOR_RANGE", "a negative allocator")


func test_restore_refuses_more_rows_than_the_declared_maximum() -> void:
	"""The registry declares `max_count` 64; a 65-row file is refused, not truncated."""
	var due: PackedInt64Array = PackedInt64Array()
	var sequences: PackedInt64Array = PackedInt64Array()
	for index: int in range(65):
		due.append(index + 1)
		sequences.append(index + 1)
	_refuse_restore(100, due, sequences, "EVENT_RESTORE_COUNT", "65 rows")


func test_restore_refuses_ragged_columns() -> void:
	"""All six row columns must carry the same count; a short one is a corrupt file."""
	var before: PackedByteArray = _store.state_bytes()
	assert_false(_store.restore_rows(9, PackedInt32Array([1, 2]), PackedInt32Array([1]),
		PackedInt32Array([1, 2]), PackedInt32Array([1, 2]), PackedInt64Array([100, 200]),
		PackedInt64Array([1, 2])), "ragged columns refuse")
	assert_equal(String(_store.last_refusal()), "EVENT_RESTORE_COLUMNS_RAGGED", "refusal reason")
	assert_true(_store.state_bytes() == before, "the refusal changed not one byte")


func test_restore_accepts_an_exhausted_allocator_with_live_rows() -> void:
	"""Exhaustion is a save-able state: the rows survive, and no further insertion is possible."""
	assert_true(_store.restore_rows(0, PackedInt32Array([1]), PackedInt32Array([0]),
		PackedInt32Array([0]), PackedInt32Array([0]), PackedInt64Array([100]),
		PackedInt64Array([IntMath.INT64_MAX])), "installed")
	assert_equal(_store.count(), 1, "the row survived")
	assert_true(_store.is_sequence_exhausted(), "still exhausted")
	assert_false(_store.schedule_into(0, 0, 0, 0, 200, 0, _result), "no further insertion")


func test_clear_returns_the_store_to_its_initial_image() -> void:
	"""World initialization: rows gone, allocator back to 1, every byte as freshly constructed."""
	var fresh: PackedByteArray = EventSchedule.new().state_bytes()
	_schedule(1, 100, 0)
	_schedule(2, 200, 0)
	assert_true(_store.cancel(1), "cancelled")
	_store.clear()
	assert_equal(_store.count(), 0, "no rows")
	assert_equal(_store.next_sequence(), 1, "allocator reset")
	assert_true(_store.state_bytes() == fresh, "byte-identical to a new schedule")
