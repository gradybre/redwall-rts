extends "res://test/framework/test_case.gd"
## R07-SCHED-001's acceptance list, plus task 04.1's, as named tests.
##
## The contract's closing section names what must pass "before U2 closure": byte offsets, stride
## and round trip; the unsigned high-word boundary; the last u64 sequence; normal capacity 250
## then five unique safety holds and one overload event; repeated hold/clear/hold; refusal with an
## unchanged next sequence; paused draining and unpause; simultaneous pause reasons; 0/1/2/4
## behaviour; first midnight 13500; a speed change with debt; overload equality versus strictly
## over threshold; no discarded whole ticks; a pause requested during an eight-tick catch-up
## frame; and corrupt / oversized / stale-sequence replay. Every one of those has a test here,
## named after it.
##
## THE CROSS-PROCESS SAVE ROUND TRIP IS NOT TESTED AND CANNOT BE: no save module exists. What is
## tested is the local `SCHQ0001` codec and its validation, which the contract explicitly permits
## to pass first. See `test_the_codec_is_local_only_because_no_writer_exists`.

const Scheduler := preload("res://scripts/core/scheduler_events.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")

var _queue: Scheduler = null
var _clock: SimClock = null
var _result: Scheduler.SubmitResult = null
var _event: Scheduler.Event = null
var _report: Scheduler.PumpReport = null
var _boundary_days: PackedInt32Array = PackedInt32Array()
var _steps_run: int = 0
var _hold_at_step: int = -1
var _hold_reason: int = 0
var _hold_boundary: int = -99
var _mid_tick_applied: int = -1
var _mid_tick_paused: bool = false
var _mid_tick_pending: int = -1
var _mid_tick_boundary: int = -99


func before_each() -> void:
	"""A fresh clock and queue per test. The clock starts PLAYER-paused, as sim_clock always has."""
	_clock = SimClock.new()
	_queue = Scheduler.new(_clock)
	_result = Scheduler.SubmitResult.new()
	_event = Scheduler.Event.new()
	_report = Scheduler.PumpReport.new()
	_boundary_days = PackedInt32Array()
	_steps_run = 0
	_hold_at_step = -1
	_hold_reason = 0
	_hold_boundary = -99
	_mid_tick_applied = -1
	_mid_tick_paused = false
	_mid_tick_pending = -1
	_mid_tick_boundary = -99


func _resume(out: Scheduler.SubmitResult) -> void:
	"""Queue and apply an ordinary player resume, so a test can get the clock running."""
	assert_true(_queue.submit_player_resume_into(out), "the ordinary resume must be admitted")
	_queue.pump_into(_report)
	assert_false(_clock.is_paused(), "clearing PLAYER with nothing else held must resume")


func _count_step() -> void:
	"""Per-tick callback: count ticks and, at a chosen one, submit a hold from inside the tick.

	It also records the boundary the queue stamped on that hold, which is the only place that
	value can be observed: by the time the frame returns, the tick has committed and the event has
	been drained.
	"""
	_steps_run += 1
	if _steps_run != _hold_at_step:
		return
	assert_true(_queue.submit_safety_hold_into(_hold_reason, _result),
		"a hold produced from inside a tick must be admitted")
	assert_true(_queue.read_into(_queue.pending_count() - 1, _event), "and must be readable")
	_hold_boundary = _event.boundary_tick


func _pump_probe_step() -> void:
	"""Per-tick callback that submits a hold and then pumps from INSIDE the executing tick."""
	_steps_run += 1
	if _steps_run != _hold_at_step:
		return
	assert_true(_queue.is_executing_tick(), "the queue knows a tick is executing")
	_mid_tick_boundary = _queue.current_boundary()
	assert_true(_queue.submit_safety_hold_into(_hold_reason, _result), "the hold is admitted")
	_mid_tick_applied = _queue.pump()
	_mid_tick_paused = _queue.clock().is_paused()
	_mid_tick_pending = _queue.pending_count()


func _record_day(moment: SimClock.Calendar) -> void:
	"""Day-boundary callback: remember which absolute day each crossing announced."""
	_boundary_days.append(moment.absolute_day)


# --- record layout ------------------------------------------------------------------------------

func test_byte_offsets_and_stride_are_the_contracts_own_literals() -> void:
	"""Every offset is checked against a hard-coded number, so renaming cannot move a field."""
	assert_equal(Scheduler.OFFSET_BOUNDARY_TICK, 0, "boundary_tick sits at 0")
	assert_equal(Scheduler.OFFSET_SEQUENCE_LOW, 8, "sequence_low sits at 8")
	assert_equal(Scheduler.OFFSET_SEQUENCE_HIGH, 12, "sequence_high sits at 12")
	assert_equal(Scheduler.OFFSET_KIND, 16, "kind sits at 16")
	assert_equal(Scheduler.OFFSET_REASON, 20, "reason sits at 20")
	assert_equal(Scheduler.OFFSET_VALUE, 24, "value sits at 24")
	assert_equal(Scheduler.OFFSET_RESERVED, 28, "reserved sits at 28")
	assert_equal(Scheduler.RECORD_BYTES, 32, "the stride is 32 bytes")


func test_capacity_and_control_make_the_ledgers_8224_bytes() -> void:
	"""256 records of 32 bytes plus a 32-byte control header is the row added to ARCH-MEM-010."""
	assert_equal(Scheduler.QUEUE_CAPACITY, 256, "capacity is 256 records")
	assert_equal(Scheduler.RECORD_PAYLOAD_BYTES, 8192, "256 * 32 is 8192")
	assert_equal(Scheduler.CONTROL_BYTES, 32, "queue control is 32 bytes")
	assert_equal(Scheduler.RUNTIME_PAYLOAD_BYTES, 8224, "the ledger row is 8224 bytes")
	assert_equal(Scheduler.NORMAL_CAPACITY, 250, "normal traffic stops at 250")
	assert_equal(Scheduler.RESERVED_CONTROL_SLOTS, 6, "six slots are reserved for control events")


func test_the_control_header_offsets_span_exactly_32_bytes() -> void:
	"""head, count, next sequence, last drained boundary and last applied, in the stated order."""
	assert_equal(Scheduler.OFFSET_CONTROL_HEAD, 0, "head sits at 0")
	assert_equal(Scheduler.OFFSET_CONTROL_COUNT, 4, "count sits at 4")
	assert_equal(Scheduler.OFFSET_CONTROL_NEXT_SEQUENCE_LOW, 8, "next sequence low sits at 8")
	assert_equal(Scheduler.OFFSET_CONTROL_NEXT_SEQUENCE_HIGH, 12, "next sequence high sits at 12")
	assert_equal(Scheduler.OFFSET_CONTROL_LAST_DRAINED_BOUNDARY, 16, "last drained sits at 16")
	assert_equal(Scheduler.OFFSET_CONTROL_LAST_APPLIED_SEQUENCE_LOW, 24, "last applied low at 24")
	assert_equal(Scheduler.OFFSET_CONTROL_LAST_APPLIED_SEQUENCE_HIGH, 28, "last applied high at 28")


func test_the_two_kinds_and_their_values_are_the_contracts() -> void:
	"""0 SET_REQUESTED_SPEED, 1 SET_PAUSE_REASON, pause value 0 clear and 1 hold."""
	assert_equal(Scheduler.KIND_SET_REQUESTED_SPEED, 0, "SET_REQUESTED_SPEED is kind 0")
	assert_equal(Scheduler.KIND_SET_PAUSE_REASON, 1, "SET_PAUSE_REASON is kind 1")
	assert_equal(Scheduler.KIND_COUNT, 2, "there are exactly two scheduler kinds")
	assert_equal(Scheduler.VALUE_CLEAR, 0, "0 clears a pause reason")
	assert_equal(Scheduler.VALUE_HOLD, 1, "1 holds a pause reason")


func test_the_initial_control_state_is_the_contracts() -> void:
	"""head/count 0, next sequence (0,1), last applied (0,0), last drained boundary -1."""
	assert_equal(_queue.pending_count(), 0, "a new queue is empty")
	assert_equal(_queue.head_position(), 0, "head starts at row 0")
	assert_equal(_queue.next_sequence_high(), 0, "the next sequence high word starts at 0")
	assert_equal(_queue.next_sequence_low(), 1, "the next sequence low word starts at 1")
	assert_equal(_queue.last_applied_sequence_high(), 0, "nothing has been applied")
	assert_equal(_queue.last_applied_sequence_low(), 0, "nothing has been applied")
	assert_equal(_queue.last_drained_boundary(), -1, "no prior drain is -1, not 0")


func test_a_record_round_trips_through_its_32_bytes() -> void:
	"""Encode then decode reproduces every field, including a negative u32 bit pattern."""
	var source: Scheduler.Event = Scheduler.Event.new()
	source.boundary_tick = 13500
	source.sequence_low = Scheduler.to_int32_bits(0x80000001)
	source.sequence_high = Scheduler.to_int32_bits(0xfffffffe)
	source.kind = Scheduler.KIND_SET_PAUSE_REASON
	source.reason = SimClock.LOAD
	source.value = Scheduler.VALUE_HOLD
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(Scheduler.RECORD_BYTES)
	assert_true(Scheduler.encode_event_into(source, bytes, 0), "encoding must fit the buffer")
	assert_true(Scheduler.decode_event_into(bytes, 0, _event), "decoding must read it back")
	assert_equal(_event.boundary_tick, 13500, "the boundary survives")
	assert_equal(_event.sequence_low_unsigned(), 0x80000001, "the low word survives unsigned")
	assert_equal(_event.sequence_high_unsigned(), 0xfffffffe, "the high word survives unsigned")
	assert_equal(_event.kind, Scheduler.KIND_SET_PAUSE_REASON, "the kind survives")
	assert_equal(_event.reason, SimClock.LOAD, "the reason survives")
	assert_equal(_event.value, Scheduler.VALUE_HOLD, "the value survives")
	assert_equal(_event.reserved, 0, "reserved stays zero")


func test_each_field_lands_at_its_own_offset_and_nowhere_else() -> void:
	"""Read the encoded bytes back by offset, so a swapped pair of offsets is visible."""
	var source: Scheduler.Event = Scheduler.Event.new()
	source.boundary_tick = 7
	source.sequence_low = 11
	source.sequence_high = 13
	source.kind = Scheduler.KIND_SET_PAUSE_REASON
	source.reason = SimClock.VICTORY
	source.value = Scheduler.VALUE_HOLD
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(Scheduler.RECORD_BYTES)
	Scheduler.encode_event_into(source, bytes, 0)
	assert_equal(bytes.decode_s64(0), 7, "offset 0 holds the i64 boundary")
	assert_equal(bytes.decode_u32(8), 11, "offset 8 holds the low sequence word")
	assert_equal(bytes.decode_u32(12), 13, "offset 12 holds the high sequence word")
	assert_equal(bytes.decode_s32(16), 1, "offset 16 holds the kind")
	assert_equal(bytes.decode_s32(20), SimClock.VICTORY, "offset 20 holds the reason")
	assert_equal(bytes.decode_s32(24), 1, "offset 24 holds the value")
	assert_equal(bytes.decode_u32(28), 0, "offset 28 holds a zero reserved word")


func test_encoding_refuses_a_buffer_that_cannot_hold_the_record() -> void:
	"""A short buffer refuses rather than writing a partial record."""
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(Scheduler.RECORD_BYTES - 1)
	assert_false(Scheduler.encode_event_into(_event, bytes, 0), "31 bytes cannot hold a record")
	assert_false(Scheduler.decode_event_into(bytes, 0, _event), "31 bytes cannot yield a record")
	bytes.resize(Scheduler.RECORD_BYTES)
	assert_false(Scheduler.encode_event_into(_event, bytes, -1), "a negative offset refuses")


# --- unsigned sequence ordering -------------------------------------------------------------------

func test_unsigned_ordering_survives_the_sign_bit() -> void:
	"""0x80000000 must sort AFTER 0x7fffffff; a signed compare reverses exactly this pair."""
	assert_equal(Scheduler.compare_sequence(0, 0x80000000, 0, 0x7fffffff), 1,
		"0x80000000 follows 0x7fffffff in the low word")
	assert_equal(Scheduler.compare_sequence(0x80000000, 0, 0x7fffffff, 0), 1,
		"0x80000000 follows 0x7fffffff in the high word")
	assert_equal(Scheduler.compare_sequence(0, 1, 1, 0), -1, "the high word dominates the low")
	assert_equal(Scheduler.compare_sequence(5, 5, 5, 5), 0, "an equal key compares equal")
	assert_equal(Scheduler.to_int32_bits(0x80000000), -2147483648,
		"0x80000000 is stored as a negative i32")
	assert_equal(Scheduler.to_uint32(-2147483648), 0x80000000, "and reads back unsigned")


func test_unsigned_ordering_survives_a_high_word_STORED_as_a_negative_i32() -> void:
	"""The masking only matters on values that came OUT of a PackedInt32Array column.

	Passing a plain 0x80000000 proves nothing: GDScript ints are 64-bit, so it is already
	positive. What a column hands back is -2147483648, and THAT is what a signed comparison
	mis-orders. Both words are checked, because each has its own mask.
	"""
	var high: int = Scheduler.to_int32_bits(0x80000000)
	var low: int = Scheduler.to_int32_bits(0x7fffffff)
	assert_equal(high, -2147483648, "the stored high word really is negative")
	assert_equal(Scheduler.compare_sequence(high, 0, low, 0), 1,
		"a stored 0x80000000 high word still follows a stored 0x7fffffff one")
	assert_equal(Scheduler.compare_sequence(low, 0, high, 0), -1, "and the reverse holds")
	assert_equal(Scheduler.compare_sequence(0, high, 0, low), 1,
		"the same is true of the low word")
	assert_equal(Scheduler.compare_sequence(0, low, 0, high), -1, "in both directions")


func test_a_stamped_event_whose_HIGH_word_crosses_the_sign_bit_is_admitted() -> void:
	"""last_applied high 0x7fffffff then a stamped high 0x80000000: signed ordering refuses this."""
	assert_true(_queue.restore_sequence(0x7fffffff, 1), "seed the high word below the sign bit")
	assert_true(_queue.submit_speed_into(2, _result), "admit one event")
	assert_equal(_result.sequence_high, 0x7fffffff, "carrying that high word")
	_queue.pump_into(_report)
	assert_equal(_queue.last_applied_sequence_high(), 0x7fffffff, "which becomes last applied")
	_event.reset()
	_event.boundary_tick = _queue.current_boundary()
	_event.sequence_high = Scheduler.to_int32_bits(0x80000000)
	_event.sequence_low = 1
	_event.kind = Scheduler.KIND_SET_REQUESTED_SPEED
	_event.value = 4
	assert_true(_queue.admit_stamped_into(_event, _result),
		"a 0x80000000 high word strictly follows 0x7fffffff and must be admitted")
	assert_equal(_queue.pending_count(), 1, "so the record is queued")


func test_two_stamped_events_across_the_sign_bit_keep_their_order() -> void:
	"""Admission at 0x7fffffff then 0x80000000 stores a positive then a NEGATIVE i32 in order."""
	assert_true(_queue.restore_sequence(0, 0x7fffffff), "an empty queue accepts a restore")
	assert_true(_queue.submit_speed_into(2, _result), "the first event is admitted")
	assert_equal(_result.sequence_low, 0x7fffffff, "it takes 0x7fffffff")
	assert_true(_queue.submit_speed_into(4, _result), "the second event is admitted")
	assert_equal(_result.sequence_low, 0x80000000, "it takes 0x80000000")
	assert_true(_queue.read_into(0, _event), "the first row reads back")
	assert_equal(_event.sequence_low, 2147483647, "the first is a positive i32")
	assert_true(_queue.read_into(1, _event), "the second row reads back")
	assert_equal(_event.sequence_low, -2147483648, "the second is a NEGATIVE i32")
	assert_equal(Scheduler.compare_sequence(0, 0x80000000, 0, 0x7fffffff), 1,
		"and they still order correctly unsigned")


func test_a_stamped_replay_record_crossing_the_sign_bit_is_admitted() -> void:
	"""last_applied 0x7fffffff then a stamped 0x80000000: signed ordering would refuse this."""
	assert_true(_queue.restore_sequence(0, 0x7fffffff), "seed the sequence below the sign bit")
	assert_true(_queue.submit_speed_into(2, _result), "admit one event")
	_queue.pump_into(_report)
	assert_equal(_queue.last_applied_sequence_low(), 0x7fffffff, "last applied is 0x7fffffff")
	_event.reset()
	_event.boundary_tick = _queue.current_boundary()
	_event.sequence_low = Scheduler.to_int32_bits(0x80000000)
	_event.kind = Scheduler.KIND_SET_REQUESTED_SPEED
	_event.value = 4
	assert_true(_queue.admit_stamped_into(_event, _result),
		"0x80000000 strictly follows 0x7fffffff and must be admitted")
	assert_equal(_queue.pending_count(), 1, "the record is queued")


func test_the_low_word_carries_into_the_high_word_without_exhausting() -> void:
	"""(0, 0xffffffff) steps to (1, 0), which is an ordinary sequence, not the sentinel."""
	assert_true(_queue.restore_sequence(0, 0xffffffff), "seed the last low word")
	assert_true(_queue.submit_speed_into(1, _result), "the all-ones low word is usable")
	assert_equal(_queue.next_sequence_high(), 1, "the carry reaches the high word")
	assert_equal(_queue.next_sequence_low(), 0, "and the low word restarts")
	assert_false(_queue.is_sequence_exhausted(), "(1, 0) is not the exhausted sentinel")


func test_the_last_u64_sequence_is_usable_and_then_exhaustion_refuses() -> void:
	"""All-ones is the last usable sequence; the next state is (0,0) and refuses forever."""
	assert_true(_queue.restore_sequence(0xffffffff, 0xffffffff), "seed the last usable sequence")
	assert_false(_queue.is_sequence_exhausted(), "all-ones is still usable")
	assert_true(_queue.submit_speed_into(2, _result), "the last u64 sequence is admitted")
	assert_equal(_result.sequence_high, 0xffffffff, "it carries the all-ones high word")
	assert_equal(_result.sequence_low, 0xffffffff, "and the all-ones low word")
	assert_true(_queue.is_sequence_exhausted(), "the next state is the (0,0) sentinel")
	assert_equal(_queue.next_sequence_low(), 0, "which never becomes 1 again")
	assert_equal(_queue.next_sequence_high(), 0, "in either word")


func test_exhaustion_refuses_rather_than_wrapping_to_sequence_one() -> void:
	"""Once exhausted every admission path refuses; recovery is save/restart, never reuse."""
	assert_true(_queue.restore_sequence(0xffffffff, 0xffffffff), "seed the last usable sequence")
	assert_true(_queue.submit_speed_into(2, _result), "spend it")
	assert_false(_queue.submit_speed_into(4, _result), "a speed event now refuses")
	assert_equal(_result.error, &"SCHEDULER_SEQUENCE_EXHAUSTED", "and names exhaustion")
	assert_false(_queue.submit_player_resume_into(_result), "a resume refuses too")
	assert_false(_queue.submit_safety_hold_into(SimClock.CRITICAL, _result),
		"even a reserved safety hold refuses rather than reusing sequence 1")
	assert_equal(_queue.next_sequence_low(), 0, "the sentinel is unchanged")
	assert_equal(_queue.pending_count(), 1, "and nothing more was queued")


func test_the_sentinel_is_never_a_valid_stamped_event() -> void:
	"""A replay record carrying (0,0) is refused, because that value means exhausted."""
	_event.boundary_tick = _queue.current_boundary()
	_event.sequence_low = 0
	_event.sequence_high = 0
	_event.kind = Scheduler.KIND_SET_REQUESTED_SPEED
	_event.value = 2
	assert_false(_queue.admit_stamped_into(_event, _result), "(0,0) is not an event")
	assert_equal(_result.error, &"SCHEDULER_SEQUENCE_EXHAUSTED", "it is named as the sentinel")


func test_this_sequence_space_is_independent_of_the_economic_one() -> void:
	"""Scheduler sequences start at 1 and advance only here; nothing shares the counter."""
	assert_equal(_queue.next_sequence_low(), 1, "the scheduler's own counter starts at 1")
	assert_true(_queue.submit_speed_into(2, _result), "one scheduler admission")
	assert_equal(_queue.next_sequence_low(), 2, "advances only the scheduler counter")
	var other: Scheduler = Scheduler.new(_clock)
	assert_equal(other.next_sequence_low(), 1, "a second world starts its own space at 1")


# --- admission and refusal ----------------------------------------------------------------------

func test_only_speeds_one_two_and_four_are_selectable() -> void:
	"""0 is the effective pause produced by the mask, and 3x has never existed."""
	for value: int in [1, 2, 4]:
		assert_true(_queue.submit_speed_into(value, _result), "speed %d is selectable" % value)
	for value: int in [0, 3, -1, 5, 8]:
		assert_false(_queue.submit_speed_into(value, _result), "speed %d is not" % value)
		assert_equal(_result.error, &"SCHEDULER_SPEED_NOT_SELECTABLE",
			"speed %d refuses by name rather than clamping" % value)
	assert_equal(_queue.pending_count(), 3, "only the three selectable speeds were queued")


func test_a_speed_event_must_carry_a_zero_reason() -> void:
	"""The contract fixes reason 0 for speed; a pause bit there is a different event's field."""
	_event.boundary_tick = _queue.current_boundary()
	_event.sequence_low = 1
	_event.kind = Scheduler.KIND_SET_REQUESTED_SPEED
	_event.reason = SimClock.MENU
	_event.value = 2
	assert_false(_queue.admit_stamped_into(_event, _result), "a speed event with a reason refuses")
	assert_equal(_result.error, &"SCHEDULER_SPEED_REASON_NONZERO", "and says which field is wrong")


func test_a_nonzero_reserved_word_refuses() -> void:
	"""`reserved` must be zero. An accepted undefined bit would be a semantic nobody specified."""
	_event.boundary_tick = _queue.current_boundary()
	_event.sequence_low = 1
	_event.kind = Scheduler.KIND_SET_REQUESTED_SPEED
	_event.value = 2
	_event.reserved = 1
	assert_false(_queue.admit_stamped_into(_event, _result), "a nonzero reserved word refuses")
	assert_equal(_result.error, &"SCHEDULER_RESERVED_NONZERO", "and is named")
	assert_equal(_queue.pending_count(), 0, "nothing was written")
	_event.reserved = 0
	assert_true(_queue.admit_stamped_into(_event, _result), "the same record with zero is fine")


func test_an_unknown_kind_refuses() -> void:
	"""There are exactly two kinds; a third refuses rather than being treated as one of them."""
	_event.boundary_tick = _queue.current_boundary()
	_event.sequence_low = 1
	_event.kind = 2
	assert_false(_queue.admit_stamped_into(_event, _result), "kind 2 does not exist")
	assert_equal(_result.error, &"SCHEDULER_UNKNOWN_KIND", "and is named as unknown")
	_event.kind = -1
	assert_false(_queue.admit_stamped_into(_event, _result), "nor does kind -1")


func test_a_composite_or_unknown_pause_reason_refuses() -> void:
	"""One event names ONE reason, which is what stops closing one from clearing another."""
	for reason: int in [SimClock.PLAYER | SimClock.MENU, 0, 3, 32, -4]:
		assert_false(_queue.submit_pause_into(reason, reason, Scheduler.VALUE_HOLD, _result),
			"reason %d is not a single known pause bit" % reason)
		assert_equal(_result.error, &"SCHEDULER_PAUSE_REASON_NOT_SINGLE", "and is named")
	assert_equal(_queue.pending_count(), 0, "nothing composite was queued")


func test_a_pause_value_other_than_zero_or_one_refuses() -> void:
	"""Hold and clear are the only two operations on a reason."""
	for value: int in [2, -1, 16]:
		assert_false(_queue.submit_pause_into(SimClock.MENU, SimClock.MENU, value, _result),
			"pause value %d is not clear or hold" % value)
		assert_equal(_result.error, &"SCHEDULER_PAUSE_VALUE", "and is named")


func test_a_producer_may_only_name_its_own_pause_reason() -> void:
	"""A generic UI toggle cannot clear CRITICAL or LOAD, because it cannot claim to own them."""
	assert_false(_queue.submit_pause_into(Scheduler.PRODUCER_PLAYER, SimClock.CRITICAL,
		Scheduler.VALUE_CLEAR, _result), "the player producer cannot clear CRITICAL")
	assert_equal(_result.error, &"SCHEDULER_PRODUCER_NOT_REASON_OWNER", "and is named")
	assert_false(_queue.submit_pause_into(Scheduler.PRODUCER_PLAYER, SimClock.LOAD,
		Scheduler.VALUE_CLEAR, _result), "nor LOAD")
	assert_true(_queue.submit_pause_into(Scheduler.PRODUCER_OVERLOAD, SimClock.CRITICAL,
		Scheduler.VALUE_CLEAR, _result), "the overload owner may clear its own CRITICAL")
	assert_true(_queue.submit_pause_into(Scheduler.PRODUCER_LOADER, SimClock.LOAD,
		Scheduler.VALUE_CLEAR, _result), "and the loader its own LOAD")


func test_the_ordinary_resume_clears_player_and_only_player() -> void:
	"""The mistake this prevents is a Resume button that resumes out of a MENU or a LOAD pause."""
	assert_true(_queue.submit_safety_hold_into(SimClock.MENU, _result), "hold MENU as well")
	assert_true(_queue.submit_player_resume_into(_result), "the ordinary resume is admitted")
	_queue.pump_into(_report)
	assert_false(_clock.has_pause_reason(SimClock.PLAYER), "PLAYER is released")
	assert_true(_clock.has_pause_reason(SimClock.MENU), "MENU is untouched")
	assert_true(_clock.is_paused(), "so the clock is still paused")


func test_a_refusal_leaves_the_next_sequence_and_the_queue_unchanged() -> void:
	"""Failed admission changes no queue, no state and no sequence."""
	assert_true(_queue.submit_speed_into(2, _result), "queue one good event first")
	var sequence_low: int = _queue.next_sequence_low()
	var sequence_high: int = _queue.next_sequence_high()
	var pending: int = _queue.pending_count()
	var head: int = _queue.head_position()
	assert_false(_queue.submit_speed_into(3, _result), "3x refuses")
	assert_false(_queue.submit_pause_into(SimClock.PLAYER, SimClock.CRITICAL, 1, _result),
		"a producer that owns nothing refuses")
	assert_equal(_queue.next_sequence_low(), sequence_low, "the next low word is unchanged")
	assert_equal(_queue.next_sequence_high(), sequence_high, "the next high word is unchanged")
	assert_equal(_queue.pending_count(), pending, "the pending count is unchanged")
	assert_equal(_queue.head_position(), head, "and the head is unchanged")


func test_a_user_repeat_takes_a_new_sequence() -> void:
	"""The contract coalesces only an internal duplicate hold, never a user repeat."""
	assert_true(_queue.submit_speed_into(2, _result), "the first request")
	assert_equal(_result.sequence_low, 1, "takes sequence 1")
	assert_true(_queue.submit_speed_into(2, _result), "the identical repeat is admitted too")
	assert_equal(_result.sequence_low, 2, "and takes a NEW sequence")
	assert_true(_result.admitted, "it really was admitted")
	assert_false(_result.coalesced, "and was not coalesced")
	assert_equal(_queue.pending_count(), 2, "both records are queued")


# --- coalescing ---------------------------------------------------------------------------------

func test_an_internal_duplicate_hold_coalesces_and_consumes_no_sequence() -> void:
	"""Contract: duplicate pause holds from an internal producer must not consume a sequence."""
	assert_true(_queue.submit_safety_hold_into(SimClock.CRITICAL, _result), "the first hold")
	assert_true(_result.admitted, "is admitted")
	var sequence_low: int = _queue.next_sequence_low()
	assert_true(_queue.submit_safety_hold_into(SimClock.CRITICAL, _result), "the duplicate")
	assert_false(_result.admitted, "is not admitted")
	assert_true(_result.coalesced, "it is reported as already held or pending")
	assert_equal(_queue.next_sequence_low(), sequence_low, "and consumes NO sequence")
	assert_equal(_queue.pending_count(), 1, "only one record exists")
	assert_equal(_queue.coalesced_count(), 1, "the coalesce is counted")


func test_a_hold_after_a_pending_clear_is_not_dropped() -> void:
	"""Contract: "scan pending operations so a hold after a pending clear is not incorrectly
	dropped". Reading the live mask alone would drop this one."""
	assert_true(_queue.submit_safety_hold_into(SimClock.MENU, _result), "hold MENU")
	_queue.pump_into(_report)
	assert_true(_clock.has_pause_reason(SimClock.MENU), "the clock now holds MENU")
	assert_true(_queue.submit_pause_into(SimClock.MENU, SimClock.MENU, Scheduler.VALUE_CLEAR,
		_result), "queue a clear WITHOUT pumping it")
	assert_true(_queue.submit_safety_hold_into(SimClock.MENU, _result), "then hold again")
	assert_true(_result.admitted, "the hold must be ADMITTED, not coalesced away")
	assert_equal(_queue.pending_count(), 2, "clear then hold are both queued")
	_queue.pump_into(_report)
	assert_true(_clock.has_pause_reason(SimClock.MENU), "and MENU ends up held")


func test_a_hold_already_held_by_the_clock_coalesces() -> void:
	"""With no pending operation for the reason, the live mask decides."""
	assert_true(_queue.submit_safety_hold_into(SimClock.LOAD, _result), "hold LOAD")
	_queue.pump_into(_report)
	assert_true(_queue.submit_safety_hold_into(SimClock.LOAD, _result), "hold LOAD again")
	assert_true(_result.coalesced, "the clock already holds it, so the repeat coalesces")
	assert_equal(_queue.pending_count(), 0, "and nothing is queued")


# --- capacity and the control reserve -----------------------------------------------------------

func test_normal_traffic_stops_at_250_then_the_reserve_takes_six_control_events() -> void:
	"""The contract's exact bound: 250 normal, then five unique holds and one overload downgrade."""
	_clock.set_pause(SimClock.PLAYER, false)
	for index: int in Scheduler.NORMAL_CAPACITY:
		assert_true(_queue.submit_speed_into(2, _result), "normal event %d fits" % index)
	assert_equal(_queue.pending_count(), 250, "250 normal events are queued")
	assert_false(_queue.submit_speed_into(4, _result), "the 251st normal event refuses")
	assert_equal(_result.error, &"SCHEDULER_NORMAL_CAPACITY_RESERVED", "naming the reserve")
	for reason: int in SimClock.ALL_PAUSE_REASONS:
		assert_true(_queue.submit_safety_hold_into(reason, _result),
			"safety hold %d uses the reserve" % reason)
	assert_equal(_queue.pending_count(), 255, "five unique holds fit above 250")
	assert_true(_queue.submit_overload_downgrade_into(SimClock.SPEED_DOUBLE, _result),
		"and the one overload downgrade fits")
	assert_equal(_queue.pending_count(), 256, "the ring is now exactly full")


func test_a_full_queue_refuses_every_class_of_event() -> void:
	"""At 256 even a reserved control event refuses; no accepted record is ever overwritten."""
	_clock.set_pause(SimClock.PLAYER, false)
	for index: int in Scheduler.NORMAL_CAPACITY:
		_queue.submit_speed_into(2, _result)
	for reason: int in SimClock.ALL_PAUSE_REASONS:
		_queue.submit_safety_hold_into(reason, _result)
	_queue.submit_overload_downgrade_into(SimClock.SPEED_DOUBLE, _result)
	assert_equal(_queue.pending_count(), 256, "the ring is full")
	assert_false(_queue.submit_speed_into(1, _result), "a normal event refuses")
	assert_equal(_result.error, &"SCHEDULER_QUEUE_FULL", "as full, not as reserved")
	_queue.begin_host_frame()
	assert_false(_queue.submit_overload_downgrade_into(SimClock.SPEED_NORMAL, _result),
		"and so does a fresh frame's overload downgrade")
	assert_equal(_result.error, &"SCHEDULER_QUEUE_FULL", "naming capacity")
	assert_equal(_queue.pending_count(), 256, "nothing was overwritten")


func test_the_overload_producer_issues_at_most_one_downgrade_per_frame() -> void:
	"""Contract: the next frame must pump before another downgrade can be produced."""
	_queue.begin_host_frame()
	assert_true(_queue.submit_overload_downgrade_into(SimClock.SPEED_DOUBLE, _result),
		"the frame's one downgrade is admitted")
	assert_true(_queue.overload_issued_this_frame(), "and the frame's issue is spent")
	assert_false(_queue.submit_overload_downgrade_into(SimClock.SPEED_NORMAL, _result),
		"a second downgrade in the same frame refuses")
	assert_equal(_result.error, &"SCHEDULER_OVERLOAD_ALREADY_ISSUED", "and is named")
	_queue.begin_host_frame()
	assert_false(_queue.overload_issued_this_frame(), "a new frame restores the issue")
	assert_true(_queue.submit_overload_downgrade_into(SimClock.SPEED_NORMAL, _result),
		"so the next downgrade is admitted")


func test_an_overload_target_that_is_not_a_ladder_rung_refuses() -> void:
	"""The rungs are 2, 1 and the CRITICAL hold; 4 is never a downgrade."""
	assert_false(_queue.submit_overload_downgrade_into(SimClock.SPEED_QUADRUPLE, _result),
		"4x is not a downgrade target")
	assert_equal(_result.error, &"SCHEDULER_OVERLOAD_TARGET", "and is named")
	assert_false(_queue.overload_issued_this_frame(), "a refused downgrade spends no issue")


func test_a_capacity_refusal_is_visible_and_retryable() -> void:
	"""Contract: "Capacity refusal is visible and retryable" -- the pump makes room again."""
	for index: int in Scheduler.NORMAL_CAPACITY:
		_queue.submit_speed_into(2, _result)
	assert_false(_queue.submit_speed_into(4, _result), "the queue is at the normal cap")
	assert_equal(_queue.last_refusal(), &"SCHEDULER_NORMAL_CAPACITY_RESERVED", "visibly")
	_queue.pump_into(_report)
	assert_equal(_queue.pending_count(), 0, "the pump drains everything at this boundary")
	assert_true(_queue.submit_speed_into(4, _result), "and the retry succeeds")


# --- the boundary pump ---------------------------------------------------------------------------

func test_events_are_stamped_with_the_current_completed_boundary() -> void:
	"""Between ticks, an admitted event takes the CURRENT completed tick as its boundary."""
	assert_equal(_queue.current_boundary(), 0, "a fresh clock's boundary is tick 0")
	assert_true(_queue.submit_speed_into(2, _result), "admit at tick 0")
	assert_true(_queue.peek_into(_event), "and read it back")
	assert_equal(_event.boundary_tick, 0, "its boundary is 0")


func test_the_pump_applies_a_prefix_in_sequence_order() -> void:
	"""A pause then a resume in one prefix leaves the final state running, both events retained."""
	assert_true(_queue.submit_safety_hold_into(SimClock.MENU, _result), "hold MENU")
	assert_true(_queue.submit_pause_into(SimClock.MENU, SimClock.MENU, Scheduler.VALUE_CLEAR,
		_result), "then clear it")
	assert_true(_queue.submit_player_resume_into(_result), "and release PLAYER")
	assert_equal(_queue.pump_into(_report), 3, "all three drain in one prefix")
	assert_equal(_report.pause_events, 3, "all three were pause events")
	assert_false(_clock.is_paused(), "and the final state is running")
	assert_equal(_queue.pending_count(), 0, "the prefix is consumed")
	assert_equal(_queue.applied_count(), 3, "three events were applied")


func test_the_last_drained_boundary_never_suppresses_a_second_drain() -> void:
	"""A paused frame stays at one tick and must keep applying events there. Diagnostic only."""
	assert_true(_queue.submit_safety_hold_into(SimClock.MENU, _result), "hold MENU at tick 0")
	assert_equal(_queue.pump_into(_report), 1, "the first drain at boundary 0 applies it")
	assert_equal(_queue.last_drained_boundary(), 0, "and records boundary 0")
	assert_true(_queue.submit_pause_into(SimClock.MENU, SimClock.MENU, Scheduler.VALUE_CLEAR,
		_result), "admit another event at the SAME boundary")
	assert_equal(_queue.pump_into(_report), 1, "the second drain at boundary 0 must still run")
	assert_false(_clock.has_pause_reason(SimClock.MENU), "and its effect must land")
	assert_equal(_queue.last_drained_boundary(), 0, "the diagnostic still reads 0")


func test_an_empty_pump_is_counted_and_records_its_boundary() -> void:
	"""A pump that drains nothing is still a pump; that is how a paused frame behaves."""
	assert_equal(_queue.pump_into(_report), 0, "nothing is due")
	assert_equal(_report.applied, 0, "the report says so")
	assert_equal(_report.boundary_tick, 0, "and names the boundary it looked at")
	assert_equal(_queue.pump_count(), 1, "the pump is counted")
	assert_equal(_queue.last_drained_boundary(), 0, "and the diagnostic moved off -1")


func test_an_event_produced_inside_tick_k_is_stamped_k_not_k_minus_one() -> void:
	"""Contract: "never stamp k-1 and later reinterpret it"."""
	_resume(_result)
	_hold_at_step = 3
	_hold_reason = SimClock.MENU
	var ran: int = _queue.advance_frame(1000000, Callable(self, "_count_step"))
	assert_equal(ran, 3, "the frame stops after the tick that produced the hold")
	assert_equal(_clock.completed_tick(), 3, "three ticks committed")
	assert_true(_clock.has_pause_reason(SimClock.MENU), "and the hold landed")
	assert_equal(_queue.applied_count(), 2, "the resume and the hold were both applied")
	assert_equal(_hold_boundary, 3,
		"THE STAMP ITSELF IS 3: during tick 3 completed_tick() still reads 2, and stamping 2 "
		+ "would be the k-1 the contract forbids, even though it happens to drain at the same pump")


func test_a_pump_from_inside_tick_k_drains_nothing_and_changes_no_state() -> void:
	"""Contract: retain it in the same ring, "drain only after k commits", and change no
	speed/pause state midway through k."""
	_resume(_result)
	_hold_at_step = 4
	_hold_reason = SimClock.MENU
	var ran: int = _queue.advance_frame(1000000, Callable(self, "_pump_probe_step"))
	assert_equal(_mid_tick_boundary, 4,
		"current_boundary() reports k while tick k executes, not the k-1 completed_tick() reads")
	assert_equal(_mid_tick_applied, 0, "the mid-tick pump applied NOTHING")
	assert_equal(_mid_tick_pending, 1, "the event stayed in the same bounded ring")
	assert_false(_mid_tick_paused, "and no pause landed midway through tick 4")
	assert_equal(ran, 4, "tick 4 still committed, and then the barrier stopped tick 5")
	assert_true(_clock.has_pause_reason(SimClock.MENU), "the hold landed only after k committed")


func test_a_pause_during_an_eight_tick_catch_up_frame_stops_the_next_tick() -> void:
	"""The frame would otherwise run all eight; the barrier must cut it short."""
	_resume(_result)
	_hold_at_step = 5
	_hold_reason = SimClock.CRITICAL
	var ran: int = _queue.advance_frame(1000000, Callable(self, "_count_step"))
	assert_less_than(float(ran), 8.0, "fewer than the eight ticks the debt could pay for ran")
	assert_equal(ran, 5, "exactly the five that preceded the hold")
	assert_true(_clock.is_paused(), "the clock is paused")
	assert_true(_clock.debt() >= SimClock.TICK_COST, "and the undrained debt is still owed")


func test_the_queue_is_the_only_stamper_on_a_submission_path() -> void:
	"""A reused envelope cannot smuggle a stale boundary or sequence through submit_*."""
	_resume(_result)
	_queue.advance_frame(200000, Callable(self, "_count_step"))
	assert_equal(_clock.completed_tick(), 6, "six ticks ran")
	assert_true(_queue.submit_speed_into(2, _result), "admit after the frame")
	assert_true(_queue.peek_into(_event), "read the record back")
	assert_equal(_event.boundary_tick, 6, "it carries the new completed boundary")


func test_a_stamped_record_at_the_wrong_boundary_refuses() -> void:
	"""Contract: replay records with a past or future barrier refuse."""
	_event.boundary_tick = 1
	_event.sequence_low = 1
	_event.kind = Scheduler.KIND_SET_REQUESTED_SPEED
	_event.value = 2
	assert_false(_queue.admit_stamped_into(_event, _result), "a future barrier refuses")
	assert_equal(_result.error, &"SCHEDULER_BOUNDARY_MISMATCH", "and is named")
	_event.boundary_tick = -1
	assert_false(_queue.admit_stamped_into(_event, _result), "and so does a negative one")


func test_a_stale_or_repeated_stamped_sequence_refuses() -> void:
	"""Non-increasing sequences refuse rather than making the drain order ambiguous."""
	_event.boundary_tick = 0
	_event.sequence_low = 5
	_event.kind = Scheduler.KIND_SET_REQUESTED_SPEED
	_event.value = 2
	assert_true(_queue.admit_stamped_into(_event, _result), "sequence 5 is admitted")
	assert_false(_queue.admit_stamped_into(_event, _result), "the same sequence refuses")
	assert_equal(_result.error, &"SCHEDULER_SEQUENCE_NOT_INCREASING", "and is named")
	_event.sequence_low = 4
	assert_false(_queue.admit_stamped_into(_event, _result), "and so does an earlier one")
	_event.sequence_low = 6
	assert_true(_queue.admit_stamped_into(_event, _result), "a later one is admitted")


func test_a_stamped_sequence_at_or_below_the_last_applied_refuses() -> void:
	"""last_applied precedes every pending sequence, live as well as on load."""
	assert_true(_queue.submit_speed_into(2, _result), "admit and apply one event")
	_queue.pump_into(_report)
	assert_equal(_queue.last_applied_sequence_low(), 1, "last applied is 1")
	_event.boundary_tick = 0
	_event.sequence_low = 1
	_event.kind = Scheduler.KIND_SET_REQUESTED_SPEED
	_event.value = 4
	assert_false(_queue.admit_stamped_into(_event, _result), "replaying sequence 1 refuses")
	assert_equal(_result.error, &"SCHEDULER_SEQUENCE_NOT_INCREASING", "and is named")


# --- the ring -------------------------------------------------------------------------------------

func test_the_tail_derives_from_head_and_count_across_a_full_wrap() -> void:
	"""There is no order index: position i is (head + i) mod 256, wrap included."""
	var expected_value: int = 0
	for round_index: int in 3:
		for index: int in 200:
			assert_true(_queue.submit_speed_into(1 if index % 2 == 0 else 4, _result),
				"round %d event %d is admitted" % [round_index, index])
		assert_equal(_queue.pending_count(), 200, "200 are queued")
		assert_true(_queue.read_into(199, _event), "the tail reads back")
		expected_value = 4 if 199 % 2 == 1 else 1
		assert_equal(_event.value, expected_value, "and carries the value it was given")
		_queue.pump_into(_report)
	assert_equal(_queue.head_position(), 600 % Scheduler.QUEUE_CAPACITY,
		"the head has wrapped the 256-row ring")
	assert_equal(_queue.pending_count(), 0, "and the queue is empty")


func test_a_reused_row_carries_nothing_from_its_previous_occupant() -> void:
	"""Every field is written before count is incremented, so no stale half survives a wrap."""
	for index: int in 250:
		_queue.submit_pause_into(SimClock.VICTORY, SimClock.VICTORY, Scheduler.VALUE_HOLD, _result)
	_queue.pump_into(_report)
	for index: int in 250:
		assert_true(_queue.submit_speed_into(4, _result), "event %d refills the ring" % index)
	for index: int in 250:
		assert_true(_queue.read_into(index, _event), "row %d reads back" % index)
		assert_equal(_event.kind, Scheduler.KIND_SET_REQUESTED_SPEED, "as a speed event")
		assert_equal(_event.reason, 0, "with no leftover VICTORY reason")
		assert_equal(_event.value, 4, "and the new value")


func test_reading_outside_the_queue_refuses_rather_than_returning_a_row() -> void:
	"""No sentinel: an out-of-range position is a named refusal."""
	assert_false(_queue.read_into(0, _event), "an empty queue has no position 0")
	assert_equal(_queue.last_refusal(), &"SCHEDULER_POSITION_OUT_OF_RANGE", "named")
	assert_true(_queue.submit_speed_into(2, _result), "queue one")
	assert_false(_queue.read_into(1, _event), "position 1 is past the tail")
	assert_false(_queue.read_into(-1, _event), "and -1 is before the head")
	assert_true(_queue.read_into(0, _event), "position 0 is valid")


# --- pause composition and the clock ---------------------------------------------------------------

func test_all_five_reasons_compose_and_closing_one_never_clears_another() -> void:
	"""Task 04.1's acceptance, driven entirely through the queue."""
	for reason: int in SimClock.ALL_PAUSE_REASONS:
		assert_true(_queue.submit_safety_hold_into(reason, _result), "hold %d" % reason)
	_queue.pump_into(_report)
	assert_equal(_clock.pause_mask(), 1 | 2 | 4 | 8 | 16, "all five compose as a mask")
	for reason: int in SimClock.ALL_PAUSE_REASONS:
		assert_true(_queue.submit_pause_into(reason, reason, Scheduler.VALUE_CLEAR, _result),
			"queue a clear for %d" % reason)
		_queue.pump_into(_report)
		assert_false(_clock.has_pause_reason(reason), "reason %d is released" % reason)
	assert_equal(_clock.pause_mask(), 0, "and only then is the clock running")


func test_clearing_one_reason_leaves_the_other_four_holding() -> void:
	"""The failure this guards is a clear that writes the whole mask instead of one bit."""
	for reason: int in SimClock.ALL_PAUSE_REASONS:
		_queue.submit_safety_hold_into(reason, _result)
	_queue.pump_into(_report)
	assert_true(_queue.submit_pause_into(SimClock.MENU, SimClock.MENU, Scheduler.VALUE_CLEAR,
		_result), "clear MENU only")
	_queue.pump_into(_report)
	assert_false(_clock.has_pause_reason(SimClock.MENU), "MENU is gone")
	assert_true(_clock.has_pause_reason(SimClock.PLAYER), "PLAYER still holds")
	assert_true(_clock.has_pause_reason(SimClock.CRITICAL), "CRITICAL still holds")
	assert_true(_clock.has_pause_reason(SimClock.VICTORY), "VICTORY still holds")
	assert_true(_clock.has_pause_reason(SimClock.LOAD), "LOAD still holds")


func test_no_elapsed_time_accrues_while_paused() -> void:
	"""A paused host frame pumps but adds no debt, so nothing is charged to the resumed speed."""
	assert_true(_clock.is_paused(), "a fresh clock is player-paused")
	for frame: int in 10:
		assert_equal(_queue.advance_frame(1000000), 0, "a paused frame runs no tick")
	assert_equal(_clock.debt(), 0, "and accrued no debt at all")
	assert_equal(_queue.pump_count(), 10, "while still pumping the barrier every frame")
	_resume(_result)
	assert_equal(_clock.debt(), 0, "resuming charges nothing retroactively")


func test_unpause_arrives_while_the_queue_still_holds_pending_events() -> void:
	"""The whole point: the unpause cannot wait for the tick the pause prevents."""
	assert_true(_queue.submit_speed_into(4, _result), "queue a speed change while paused")
	assert_true(_queue.submit_player_resume_into(_result), "and the resume behind it")
	assert_equal(_queue.pending_count(), 2, "both are pending with no tick available to drain them")
	var ran: int = _queue.advance_frame(1000000, Callable(self, "_count_step"))
	assert_false(_clock.is_paused(), "the opening pump released the pause")
	assert_equal(_clock.requested_speed(), 4, "and applied the speed change first")
	assert_equal(ran, 8, "so the frame ran its eight ticks")
	assert_equal(_queue.applied_count(), 2, "both submitted events were applied")
	assert_equal(_queue.pending_count(), 1, "and the only thing left is the overload rung")
	assert_true(_queue.peek_into(_event), "which reads back")
	assert_equal(_event.kind, Scheduler.KIND_SET_REQUESTED_SPEED, "as a queued downgrade")
	assert_equal(_event.value, 2, "from 4x to 2x")


func test_a_speed_change_does_not_scale_retained_debt() -> void:
	"""Contract: existing debt stays in unchanged tick units; speed neither multiplies nor divides."""
	_resume(_result)
	_queue.advance_frame(1000000, Callable(self, "_count_step"))
	var debt: int = _clock.debt()
	assert_true(debt > 0, "the frame left debt owed")
	assert_true(_queue.submit_speed_into(4, _result), "queue a speed change")
	_queue.pump_into(_report)
	assert_equal(_clock.requested_speed(), 4, "the speed changed")
	assert_equal(_clock.debt(), debt, "and the debt is the same number of tick-cost units")


func test_the_offset_calendar_still_puts_the_first_midnight_at_13500() -> void:
	"""REQ-SET-007 through the scheduler-driven frame: 2250 frames of six ticks each."""
	_resume(_result)
	assert_true(_queue.submit_speed_into(1, _result), "run at 1x")
	_queue.pump_into(_report)
	for frame: int in 2250:
		_queue.advance_frame(200000, Callable(), Callable(self, "_record_day"))
	assert_equal(_clock.completed_tick(), 13500, "13500 ticks completed")
	assert_equal(_clock.day_boundaries_crossed(), 1, "exactly one boundary was crossed")
	assert_equal(_boundary_days.size(), 1, "and the callback fired once")
	assert_equal(_boundary_days[0], 2, "announcing absolute day 2")
	assert_false(SimClock.is_day_boundary(18000), "tick 18000 is 06:00 and is not a boundary")


# --- the overload ladder through the barrier ---------------------------------------------------------

func _run_to_quarter_second_backlog(final_elapsed: int) -> void:
	"""Three capped 1x frames whose last leaves `final_elapsed`-dependent debt near the threshold.

	Each frame accrues 10500000 debt units and the eight-tick ceiling drains 8000000, so the
	backlog climbs 2500000, 5000000 and then 7500000 -- exactly a quarter real second at 1x.
	"""
	_resume(_result)
	for frame: int in 2:
		_queue.advance_frame(350000, Callable(self, "_count_step"))
	_queue.advance_frame(final_elapsed, Callable(self, "_count_step"))


func test_overload_equality_is_not_overload() -> void:
	"""REQ-SET-008 is STRICTLY greater than a quarter real second; equality must not trigger."""
	_run_to_quarter_second_backlog(350000)
	assert_equal(_clock.debt(), 7500000, "exactly a quarter real second of backlog remains")
	assert_equal(4 * _clock.debt(), 30 * 1 * 1000000, "which is exactly the comparison's equality")
	assert_equal(_clock.fallback_count(), 0, "equality is NOT overload")
	assert_equal(_queue.pending_count(), 0, "so no downgrade was queued")
	assert_false(_clock.has_pause_reason(SimClock.CRITICAL), "and nothing paused")


func test_a_backlog_strictly_over_the_threshold_queues_the_diagnostic_hold() -> void:
	"""One microsecond more than equality is overload, and at 1x the rung is the CRITICAL hold."""
	_run_to_quarter_second_backlog(350001)
	assert_equal(_clock.debt(), 7500030, "the backlog is thirty units past equality")
	assert_true(4 * _clock.debt() > 30 * 1 * 1000000, "which is strictly over the threshold")
	assert_equal(_clock.fallback_count(), 1, "so the ladder stepped once")
	assert_equal(_queue.pending_count(), 1, "queueing exactly one rung")
	assert_true(_queue.peek_into(_event), "which reads back")
	assert_equal(_event.kind, Scheduler.KIND_SET_PAUSE_REASON, "as a pause event")
	assert_equal(_event.reason, SimClock.CRITICAL, "holding CRITICAL")
	assert_equal(_event.value, Scheduler.VALUE_HOLD, "rather than skipping ticks")


func test_the_ladder_runs_four_to_two_to_one_to_diagnostic_and_retains_debt() -> void:
	"""Task 04.1's acceptance, with every rung carried through the queue's barrier."""
	_resume(_result)
	assert_true(_queue.submit_speed_into(4, _result), "start at 4x")
	_queue.pump_into(_report)
	_queue.advance_frame(1000000, Callable(self, "_count_step"))
	assert_equal(_clock.requested_speed(), 4, "the rung is queued, not applied inside the frame")
	_queue.advance_frame(1000000, Callable(self, "_count_step"))
	assert_equal(_clock.requested_speed(), 2, "the next frame's pump applied 4 to 2")
	_queue.advance_frame(1000000, Callable(self, "_count_step"))
	assert_equal(_clock.requested_speed(), 1, "then 2 to 1")
	_queue.advance_frame(1000000, Callable(self, "_count_step"))
	assert_true(_clock.has_pause_reason(SimClock.CRITICAL), "then the diagnostic CRITICAL hold")
	assert_equal(_clock.diagnostic_pause_count(), 1, "counted once")
	assert_true(_clock.owed_ticks() > 0, "and whole ticks are still owed")
	assert_equal(_clock.acknowledged_ticks_discarded(), 0, "with none discarded")


func test_a_queued_ladder_rung_still_records_the_clocks_own_counters() -> void:
	"""Deferring the rung must not silently retire fallback_count or last_diagnostic."""
	_resume(_result)
	assert_true(_queue.submit_speed_into(4, _result), "start at 4x")
	_queue.pump_into(_report)
	_queue.advance_frame(1000000, Callable(self, "_count_step"))
	assert_equal(_clock.fallback_count(), 1, "the ladder step was counted at once")
	assert_true(_clock.last_diagnostic().contains("2x"), "and named the rung it chose")
	assert_equal(_queue.pending_count(), 1, "while the authoritative change is still queued")
	assert_true(_queue.peek_into(_event), "the queued record reads back")
	assert_equal(_event.kind, Scheduler.KIND_SET_REQUESTED_SPEED, "as a speed event")
	assert_equal(_event.value, 2, "carrying the chosen rung")


func test_the_clocks_direct_ladder_is_unchanged_when_no_hook_is_supplied() -> void:
	"""advance() with no scheduler behaves exactly as it did before this queue existed."""
	var bare: SimClock = SimClock.new()
	assert_true(bare.set_pause(SimClock.PLAYER, false), "release the initial pause")
	assert_true(bare.set_speed(4), "run at 4x")
	bare.advance(1000000)
	assert_equal(bare.requested_speed(), 2, "the ladder applies immediately, in-frame")
	assert_equal(bare.fallback_count(), 1, "and is counted")
	assert_equal(bare.overload_ladder_target(), 1, "the next rung from 2x is 1x")


func test_no_whole_tick_is_ever_discarded_without_an_explicit_acknowledgement() -> void:
	"""The conservative U3 reading survives: only the counted explicit path drops owed ticks."""
	_resume(_result)
	assert_true(_queue.submit_speed_into(4, _result), "run at 4x")
	_queue.pump_into(_report)
	for frame: int in 4:
		_queue.advance_frame(1000000, Callable(self, "_count_step"))
	assert_equal(_clock.acknowledged_catchup_resets(), 0, "no acknowledgement has been made")
	assert_equal(_clock.acknowledged_ticks_discarded(), 0, "so no whole tick was discarded")
	assert_equal(_clock.subtick_debt_discards(), 0, "and no sub-tick discard fired either")
	assert_equal(_clock.completed_tick(), _steps_run, "every tick the clock counted really ran")


func test_acknowledge_without_catchup_keeps_its_recorded_behaviour() -> void:
	"""Unchanged by this work: still explicit, still the only whole-tick drop, still counted."""
	_resume(_result)
	assert_true(_queue.submit_speed_into(4, _result), "run at 4x")
	_queue.pump_into(_report)
	for frame: int in 4:
		_queue.advance_frame(1000000, Callable(self, "_count_step"))
	var completed: int = _clock.completed_tick()
	var owed: int = _clock.owed_ticks()
	assert_true(owed > 0, "ticks are owed")
	assert_equal(_clock.acknowledge_without_catchup(), owed, "the call reports what it dropped")
	assert_equal(_clock.acknowledged_catchup_resets(), 1, "the reset is counted")
	assert_equal(_clock.acknowledged_ticks_discarded(), owed, "the dropped total is recorded")
	assert_equal(_clock.completed_tick(), completed, "completed state never moves")
	assert_false(_clock.has_pause_reason(SimClock.CRITICAL), "and CRITICAL is released")


# --- the `SCHQ0001` save subsection ------------------------------------------------------------------

func _encoded_extension(saved: Scheduler) -> PackedByteArray:
	"""Encode a queue's whole extension into a fresh buffer of exactly the right length."""
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(saved.extension_byte_length())
	assert_true(saved.encode_extension_into(bytes, 0), "the extension must encode")
	return bytes


func test_the_extension_length_is_48_plus_32_per_record() -> void:
	"""The contract's X = 48 + 32*S, and its 24-byte section prefix arithmetic."""
	assert_equal(_queue.extension_byte_length(), 48, "an empty queue's extension is 48 bytes")
	for index: int in 3:
		_queue.submit_speed_into(2, _result)
	assert_equal(_queue.extension_byte_length(), 48 + 96, "three records add 96")
	assert_equal(Scheduler.SECTION_PREFIX_BYTES, 24, "the section prefix is 24 bytes")
	assert_equal(Scheduler.section_twelve_length(0, 0, 0), 72, "72 + 64E + P + 32S with all zero")
	assert_equal(Scheduler.section_twelve_length(2, 100, 3), 72 + 128 + 100 + 96,
		"and with two economic records, 100 payload bytes and three scheduler records")


func test_the_section_prefix_bounds_are_the_contracts() -> void:
	"""E <= 4096, P <= 1048576, S <= 256, each refused by name rather than clamped."""
	assert_equal(Scheduler.section_twelve_refusal(4096, 1048576, 256), &"",
		"the exact maxima are accepted")
	assert_equal(Scheduler.section_twelve_refusal(4097, 0, 0), &"SCHEDULER_SECTION_COUNT",
		"one economic record too many refuses")
	assert_equal(Scheduler.section_twelve_refusal(0, 1048577, 0), &"SCHEDULER_SECTION_LENGTH",
		"one payload byte too many refuses")
	assert_equal(Scheduler.section_twelve_refusal(0, 0, 257), &"SCHEDULER_SECTION_COUNT",
		"one scheduler record too many refuses")
	assert_equal(Scheduler.section_twelve_refusal(-1, 0, 0), &"SCHEDULER_SECTION_COUNT",
		"and a negative count refuses")


func test_the_section_prefix_writes_six_u32_in_the_stated_order() -> void:
	"""section_schema 2, E, P, X, economic next sequence low then high."""
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(Scheduler.SECTION_PREFIX_BYTES)
	assert_true(Scheduler.encode_section_prefix_into(bytes, 0, 7, 640, 3, 11, 13),
		"the prefix encodes")
	assert_equal(bytes.decode_u32(0), 2, "section_schema is 2")
	assert_equal(bytes.decode_u32(4), 7, "then the economic count")
	assert_equal(bytes.decode_u32(8), 640, "then the economic payload used")
	assert_equal(bytes.decode_u32(12), 48 + 96, "then the scheduler extension bytes")
	assert_equal(bytes.decode_u32(16), 11, "then the economic next sequence low word")
	assert_equal(bytes.decode_u32(20), 13, "then its high word")
	assert_false(Scheduler.encode_section_prefix_into(bytes, 0, 4097, 0, 0, 0, 0),
		"an out-of-bound economic count refuses")


func test_a_pending_queue_round_trips_through_its_extension() -> void:
	"""Encode, restore into a second queue, and compare every record and every control counter.

	The queue is deliberately driven to a state where all four control counters differ from their
	initial values first, so that two control fields sharing one offset cannot round trip by
	accident.
	"""
	assert_true(_queue.submit_speed_into(2, _result), "apply one event so last_applied moves")
	_queue.pump_into(_report)
	assert_true(_queue.submit_speed_into(4, _result), "queue a speed change")
	assert_true(_queue.submit_safety_hold_into(SimClock.LOAD, _result), "and a LOAD hold")
	assert_equal(_queue.last_applied_sequence_low(), 1, "last applied is a distinct 1")
	assert_equal(_queue.last_drained_boundary(), 0, "last drained has moved off -1")
	assert_equal(_queue.next_sequence_low(), 4, "and the next sequence is a distinct 4")
	var bytes: PackedByteArray = _encoded_extension(_queue)
	var loaded: Scheduler = Scheduler.new(SimClock.new())
	assert_true(loaded.restore_extension(bytes, 0, 0), "the extension restores")
	assert_equal(loaded.pending_count(), 2, "both records came back")
	assert_equal(loaded.head_position(), 0, "restored from row 0")
	assert_equal(loaded.next_sequence_low(), 4, "the next sequence low word came back")
	assert_equal(loaded.next_sequence_high(), 0, "and its high word")
	assert_equal(loaded.last_applied_sequence_low(), 1, "last applied came back")
	assert_equal(loaded.last_applied_sequence_high(), 0, "in both words")
	assert_equal(loaded.last_drained_boundary(), 0, "and so did the drain diagnostic")
	assert_true(loaded.read_into(0, _event), "the first record reads back")
	assert_equal(_event.kind, Scheduler.KIND_SET_REQUESTED_SPEED, "as the speed change")
	assert_equal(_event.value, 4, "with its value")
	assert_true(loaded.read_into(1, _event), "the second reads back")
	assert_equal(_event.reason, SimClock.LOAD, "as the LOAD hold")


func test_the_extension_serializes_no_unused_row() -> void:
	"""Contract: "count 32-byte scheduler records in queue order (no unused rows serialized)"."""
	var bytes: PackedByteArray = _encoded_extension(_queue)
	assert_equal(bytes.size(), 48, "an empty queue serializes only its header and control")
	assert_equal(bytes.decode_u32(Scheduler.OFFSET_EXTENSION_PAYLOAD_LENGTH), 32,
		"the declared payload length is the control header alone")
	for index: int in Scheduler.SECTION_TAG_BYTES:
		assert_equal(bytes.decode_u8(index), "SCHQ0001".unicode_at(index),
			"tag byte %d is the contract's" % index)
	assert_equal(bytes.decode_u32(8), 1, "schema_version is 1")


func test_a_ring_that_has_wrapped_serializes_in_queue_order_with_head_zero() -> void:
	"""Canonical head 0: the saved order is queue order, not the live ring's rotation."""
	for index: int in 200:
		_queue.submit_speed_into(2, _result)
	_queue.pump_into(_report)
	assert_true(_queue.submit_speed_into(1, _result), "admit one after the head has moved")
	assert_true(_queue.submit_speed_into(4, _result), "and a second")
	assert_equal(_queue.head_position(), 200, "the live head is rotated")
	var bytes: PackedByteArray = _encoded_extension(_queue)
	assert_equal(bytes.decode_s32(16 + Scheduler.OFFSET_CONTROL_HEAD), 0, "but the saved head is 0")
	var loaded: Scheduler = Scheduler.new(SimClock.new())
	assert_true(loaded.restore_extension(bytes, 0, 0), "and it restores")
	assert_true(loaded.read_into(0, _event), "with the first record first")
	assert_equal(_event.value, 1, "in queue order, not ring order")


func test_a_corrupt_tag_or_version_refuses_before_mutating_the_live_queue() -> void:
	"""Contract: reject with the actual format reason; no fabricated parity."""
	assert_true(_queue.submit_speed_into(4, _result), "the live queue holds one event")
	var bytes: PackedByteArray = _encoded_extension(_queue)
	bytes.encode_u8(0, 0x58)
	assert_false(_queue.restore_extension(bytes, 0, 0), "a corrupt tag refuses")
	assert_equal(_queue.last_refusal(), &"SCHEDULER_SECTION_TAG", "naming the tag")
	assert_equal(_queue.pending_count(), 1, "and the live queue is untouched")
	bytes.encode_u8(0, "S".unicode_at(0))
	bytes.encode_u32(Scheduler.OFFSET_EXTENSION_SCHEMA_VERSION, 2)
	assert_false(_queue.restore_extension(bytes, 0, 0), "an unknown version refuses")
	assert_equal(_queue.last_refusal(), &"SCHEDULER_SECTION_VERSION", "naming the version")
	assert_equal(_queue.pending_count(), 1, "still untouched")


func test_an_oversized_or_disagreeing_length_refuses() -> void:
	"""Declared payload length, the count and the buffer's extent must all agree exactly."""
	assert_true(_queue.submit_speed_into(4, _result), "one pending record")
	var bytes: PackedByteArray = _encoded_extension(_queue)
	bytes.encode_u32(Scheduler.OFFSET_EXTENSION_PAYLOAD_LENGTH, 32 + 64)
	assert_false(_queue.restore_extension(bytes, 0, 0), "a disagreeing payload length refuses")
	assert_equal(_queue.last_refusal(), &"SCHEDULER_SECTION_LENGTH", "named as a length")
	var truncated: PackedByteArray = _encoded_extension(_queue)
	truncated.resize(truncated.size() - 1)
	assert_false(_queue.restore_extension(truncated, 0, 0), "a truncated buffer refuses")
	assert_equal(_queue.last_refusal(), &"SCHEDULER_SECTION_LENGTH", "also as a length")


func test_a_count_above_the_capacity_refuses() -> void:
	"""count <= 256, checked before any row is read."""
	var bytes: PackedByteArray = _encoded_extension(_queue)
	bytes.encode_s32(16 + Scheduler.OFFSET_CONTROL_COUNT, 257)
	assert_false(_queue.restore_extension(bytes, 0, 0), "257 records refuses")
	assert_equal(_queue.last_refusal(), &"SCHEDULER_SECTION_COUNT", "as a count")
	bytes.encode_s32(16 + Scheduler.OFFSET_CONTROL_COUNT, -1)
	assert_false(_queue.restore_extension(bytes, 0, 0), "and so does a negative count")
	assert_equal(_queue.last_refusal(), &"SCHEDULER_SECTION_COUNT", "also as a count")


func test_a_noncanonical_saved_head_refuses() -> void:
	"""The save format fixes head 0; anything else means the ring was written raw."""
	var bytes: PackedByteArray = _encoded_extension(_queue)
	bytes.encode_s32(16 + Scheduler.OFFSET_CONTROL_HEAD, 5)
	assert_false(_queue.restore_extension(bytes, 0, 0), "a nonzero saved head refuses")
	assert_equal(_queue.last_refusal(), &"SCHEDULER_SECTION_HEAD", "and is named")


func test_a_record_whose_boundary_is_not_the_saved_completed_tick_refuses() -> void:
	"""Contract: "pending boundary == saved completed tick before world mutation"."""
	assert_true(_queue.submit_speed_into(4, _result), "one pending record at boundary 0")
	var bytes: PackedByteArray = _encoded_extension(_queue)
	assert_false(_queue.restore_extension(bytes, 0, 7), "claiming completed tick 7 refuses")
	assert_equal(_queue.last_refusal(), &"SCHEDULER_BOUNDARY_MISMATCH", "and is named")
	assert_true(_queue.restore_extension(bytes, 0, 0), "the true completed tick restores")


func test_a_stale_or_unordered_saved_sequence_refuses() -> void:
	"""last_applied precedes every pending sequence, and pending sequences strictly increase."""
	for index: int in 3:
		_queue.submit_speed_into(2, _result)
	var bytes: PackedByteArray = _encoded_extension(_queue)
	bytes.encode_u32(48 + Scheduler.RECORD_BYTES + Scheduler.OFFSET_SEQUENCE_LOW, 1)
	assert_false(_queue.restore_extension(bytes, 0, 0), "a repeated pending sequence refuses")
	assert_equal(_queue.last_refusal(), &"SCHEDULER_SEQUENCE_NOT_INCREASING", "and is named")
	var applied: PackedByteArray = _encoded_extension(_queue)
	applied.encode_u32(16 + Scheduler.OFFSET_CONTROL_LAST_APPLIED_SEQUENCE_LOW, 2)
	assert_false(_queue.restore_extension(applied, 0, 0),
		"a last_applied that does not precede the first pending sequence refuses")
	assert_equal(_queue.last_refusal(), &"SCHEDULER_SECTION_APPLIED_ORDER", "and is named")


func test_a_next_sequence_not_above_every_admitted_one_refuses() -> void:
	"""Unless exhausted, the next sequence is greater than everything already admitted."""
	for index: int in 3:
		_queue.submit_speed_into(2, _result)
	var bytes: PackedByteArray = _encoded_extension(_queue)
	bytes.encode_u32(16 + Scheduler.OFFSET_CONTROL_NEXT_SEQUENCE_LOW, 3)
	assert_false(_queue.restore_extension(bytes, 0, 0), "a next sequence inside the queue refuses")
	assert_equal(_queue.last_refusal(), &"SCHEDULER_SECTION_CONTROL", "as a control fault")
	bytes.encode_u32(16 + Scheduler.OFFSET_CONTROL_NEXT_SEQUENCE_LOW, 0)
	bytes.encode_u32(16 + Scheduler.OFFSET_CONTROL_NEXT_SEQUENCE_HIGH, 0)
	assert_true(_queue.restore_extension(bytes, 0, 0),
		"but an exhausted (0,0) next sequence is allowed above pending records")
	assert_true(_queue.is_sequence_exhausted(), "and comes back exhausted, not restarted at 1")


func test_a_corrupt_record_field_refuses_with_its_own_reason() -> void:
	"""Every serialized record passes the same envelope rules an admission does."""
	assert_true(_queue.submit_speed_into(4, _result), "one pending record")
	var bytes: PackedByteArray = _encoded_extension(_queue)
	bytes.encode_u32(48 + Scheduler.OFFSET_RESERVED, 1)
	assert_false(_queue.restore_extension(bytes, 0, 0), "nonzero padding refuses")
	assert_equal(_queue.last_refusal(), &"SCHEDULER_RESERVED_NONZERO", "by its own reason")
	var speed: PackedByteArray = _encoded_extension(_queue)
	speed.encode_s32(48 + Scheduler.OFFSET_VALUE, 3)
	assert_false(_queue.restore_extension(speed, 0, 0), "a 3x record refuses")
	assert_equal(_queue.last_refusal(), &"SCHEDULER_SPEED_NOT_SELECTABLE", "by its own reason")


func test_a_saved_record_with_a_negative_boundary_refuses() -> void:
	"""Contract: "Reject ... negative boundary". This is the path that reaches that rule.

	A live submission derives its boundary from the clock and can never be negative, and a stamped
	replay record is caught by the boundary-mismatch rule first. A corrupt save claiming BOTH a
	negative completed tick and a matching negative record boundary reaches the check itself, and
	must still be refused rather than restored into a world at tick -1.
	"""
	assert_true(_queue.submit_speed_into(4, _result), "one pending record at boundary 0")
	var bytes: PackedByteArray = _encoded_extension(_queue)
	bytes.encode_s64(48 + Scheduler.OFFSET_BOUNDARY_TICK, -1)
	assert_false(_queue.restore_extension(bytes, 0, -1),
		"a negative boundary refuses even when the claimed completed tick agrees with it")
	assert_equal(_queue.last_refusal(), &"SCHEDULER_BOUNDARY_RANGE", "by its own reason")
	assert_equal(_queue.pending_count(), 1, "and the live queue is untouched")


func test_a_restored_queue_zeroes_every_unused_row() -> void:
	"""Two loads of the same bytes produce byte-identical columns, so a replay cannot diverge."""
	for index: int in 200:
		_queue.submit_pause_into(SimClock.VICTORY, SimClock.VICTORY, Scheduler.VALUE_HOLD, _result)
	var wide: PackedByteArray = _encoded_extension(_queue)
	assert_true(_queue.restore_extension(wide, 0, 0), "restore the wide queue")
	var narrow: Scheduler = Scheduler.new(SimClock.new())
	assert_true(narrow.submit_speed_into(2, _result), "a second queue holds one record")
	var thin: PackedByteArray = _encoded_extension(narrow)
	assert_true(_queue.restore_extension(thin, 0, 0), "restoring the thin one over the wide one")
	assert_equal(_queue.pending_count(), 1, "leaves exactly one record")
	assert_true(_queue.read_into(0, _event), "which reads back")
	assert_equal(_event.kind, Scheduler.KIND_SET_REQUESTED_SPEED, "as the thin queue's event")
	assert_false(_queue.read_into(1, _event), "and row 1 is not reachable")


func test_the_codec_is_local_only_because_no_writer_exists() -> void:
	"""BLOCKED, stated as a test so it cannot be quietly forgotten.

	The contract permits local codec tests to pass first and says U2's production pending-save
	acceptance "remains blocked until that real integration is executed". No save module exists in
	this repository, so the cross-process round trip cannot be run at all; what IS proven is that
	the bytes a writer would need are produced and validated.
	"""
	var bytes: PackedByteArray = _encoded_extension(_queue)
	assert_equal(bytes.size(), _queue.extension_byte_length(),
		"the encoder fills exactly the length it declares")
	assert_false(FileAccess.file_exists("res://scripts/core/save_container.gd"),
		"there is still no save container module, so the cross-process trip stays BLOCKED")


# --- rebinding and clearing --------------------------------------------------------------------------

func test_rebinding_or_restoring_under_a_pending_queue_refuses() -> void:
	"""Pending events were stamped against this clock's numbering; re-basing would move them."""
	assert_true(_queue.submit_speed_into(2, _result), "queue one event")
	assert_false(_queue.rebind_clock(SimClock.new()), "rebinding refuses")
	assert_equal(_queue.last_refusal(), &"SCHEDULER_QUEUE_NOT_EMPTY", "as a non-empty queue")
	assert_false(_queue.restore_sequence(0, 9), "restoring the sequence refuses too")
	assert_equal(_queue.last_refusal(), &"SCHEDULER_QUEUE_NOT_EMPTY", "for the same reason")
	assert_false(_queue.rebind_clock(null), "and a null clock always refuses")
	assert_equal(_queue.last_refusal(), &"SCHEDULER_NO_CLOCK", "by its own name")
	_queue.pump_into(_report)
	assert_true(_queue.rebind_clock(SimClock.new()), "an emptied queue rebinds")


func test_clear_returns_every_counter_to_the_contracts_initial_state() -> void:
	"""World initialization, not a drain: it must reproduce the stated initial control exactly."""
	_queue.submit_speed_into(2, _result)
	_queue.pump_into(_report)
	_queue.submit_safety_hold_into(SimClock.MENU, _result)
	_queue.clear()
	assert_equal(_queue.pending_count(), 0, "the queue is empty")
	assert_equal(_queue.head_position(), 0, "head is back at 0")
	assert_equal(_queue.next_sequence_low(), 1, "the next sequence is back to 1")
	assert_equal(_queue.last_applied_sequence_low(), 0, "last applied is back to 0")
	assert_equal(_queue.last_drained_boundary(), -1, "and last drained is back to -1")
	assert_equal(_queue.applied_count(), 0, "the counters reset")
	assert_equal(_queue.pump_count(), 0, "all of them")


func test_a_second_queue_on_the_same_clock_sees_the_same_boundary() -> void:
	"""The queue applies to THE clock it was handed, which is what `clock()` exposes."""
	assert_equal(_queue.clock(), _clock, "the bound clock is the one passed in")
	var other: Scheduler = Scheduler.new(_clock)
	assert_equal(other.current_boundary(), _queue.current_boundary(), "both read one boundary")
	assert_true(_queue.submit_player_resume_into(_result), "resume through the first")
	_queue.pump_into(_report)
	assert_false(other.clock().is_paused(), "and the second sees the same clock resume")


# --- the shared load barrier (RESTORE-R01, decision 0098) ---------------------------------------------
#
# The ruling is explicit that a coordinator-only check is insufficient "while mutable raw access
# exists". `game_manager.scheduler_events()` hands out THIS object, so these tests hold the barrier
# on the raw clock and attack the raw queue with every mutator it has. The barrier is the CLOCK'S:
# this queue owns no barrier state, which is why `rebind_clock()` has to be barred as well -- a
# rebind under a held barrier would be an escape from it.


func _hold_barrier() -> SimClock.LoadBarrier:
	"""Raise the barrier on the clock this queue is bound to, and return its token."""
	var grant: SimClock.LoadBarrierGrant = _clock.acquire_load_barrier()
	assert_true(grant.is_ok(), "the barrier is granted")
	assert_true(_queue.is_load_barrier_held(), "and the QUEUE sees it, through its clock")
	return grant.token


func _queue_snapshot() -> String:
	"""Every observable field of the queue as one string, for the byte-identical comparison.

	It deliberately includes the refusal diagnostics: a barred command must not even be counted as
	a refusal, because the barrier is a property of the moment rather than of the request.
	"""
	return "%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%s" % [_queue.pending_count(), _queue.head_position(),
		_queue.next_sequence_high(), _queue.next_sequence_low(),
		_queue.last_applied_sequence_high(), _queue.last_applied_sequence_low(),
		_queue.last_drained_boundary(), _queue.admitted_count(), _queue.coalesced_count(),
		_queue.refused_count(), _queue.applied_count(), _queue.last_refusal()]


func test_the_queue_reads_the_clocks_barrier_and_holds_none_of_its_own() -> void:
	"""One barrier per world: a second queue on the same clock is barred by the same token."""
	assert_false(_queue.is_load_barrier_held(), "no barrier stands to begin with")
	var token: SimClock.LoadBarrier = _hold_barrier()
	var other: Scheduler = Scheduler.new(_clock)
	assert_equal(other.next_sequence_low(), 1, "a queue built under the barrier still initializes")
	assert_true(other.is_load_barrier_held(), "a second queue on that clock is barred too")
	assert_false(other.submit_speed_into(2, _result), "and refuses the same admission")
	assert_true(token.release(), "release")
	assert_false(_queue.is_load_barrier_held(), "both queues see the barrier drop")
	assert_false(other.is_load_barrier_held(), "because neither of them owns it")


func test_every_admission_is_barred_and_leaves_the_queue_byte_identical() -> void:
	"""Speed, pause, resume, safety hold, overload rung and stamped replay: all six refuse."""
	assert_true(_queue.submit_speed_into(4, _result), "one admitted event before the load")
	var before: String = _queue_snapshot()
	var token: SimClock.LoadBarrier = _hold_barrier()
	assert_false(_queue.submit_speed_into(2, _result), "speed is barred")
	assert_equal(_result.error, Scheduler.REFUSE_LOAD_BARRIER, "and says so in the result")
	assert_false(_queue.submit_pause_into(Scheduler.PRODUCER_MENU, SimClock.MENU,
		Scheduler.VALUE_HOLD, _result), "a pause hold is barred")
	assert_false(_queue.submit_player_resume_into(_result), "the player resume is barred")
	assert_false(_queue.submit_safety_hold_into(SimClock.CRITICAL, _result),
		"an internal safety hold is barred")
	assert_false(_queue.submit_overload_downgrade_into(SimClock.SPEED_DOUBLE, _result),
		"an overload rung is barred")
	_event.reset()
	_event.kind = Scheduler.KIND_SET_REQUESTED_SPEED
	_event.value = 1
	_event.boundary_tick = _queue.current_boundary()
	_event.sequence_low = 90
	assert_false(_queue.admit_stamped_into(_event, _result), "a stamped replay record is barred")
	assert_equal(_queue_snapshot(), before, "and the queue is byte-identical after all six")
	assert_true(token.release(), "release")
	assert_true(_queue.submit_speed_into(2, _result), "the same admission now lands")


func test_a_barred_admission_is_not_counted_as_a_queue_refusal() -> void:
	"""It is not the request that was wrong, so `refused_count()` and `last_refusal()` stand."""
	assert_false(_queue.submit_pause_into(Scheduler.PRODUCER_MENU, SimClock.PLAYER,
		Scheduler.VALUE_HOLD, _result), "an ordinary ownership refusal first")
	assert_equal(_queue.last_refusal(), Scheduler.REFUSE_PRODUCER_NOT_OWNER, "recorded as such")
	var refusals: int = _queue.refused_count()
	var token: SimClock.LoadBarrier = _hold_barrier()
	assert_false(_queue.submit_speed_into(2, _result), "the barred admission refuses")
	assert_equal(_result.error, Scheduler.REFUSE_LOAD_BARRIER,
		"telling the caller through its own result")
	assert_false(_result.ok, "which cannot be mistaken for the success it carried before")
	assert_equal(_queue.refused_count(), refusals, "the queue counted no refusal")
	assert_equal(_queue.last_refusal(), Scheduler.REFUSE_PRODUCER_NOT_OWNER,
		"and the standing reason is still the real one")
	assert_true(token.release(), "release")


func test_pumping_is_barred_so_a_restored_queue_applies_nothing_mid_load() -> void:
	"""RESTORE-R01's guard before scheduler pumping, at the queue rather than in a coordinator."""
	assert_true(_queue.submit_player_resume_into(_result), "queue a resume")
	var pumps: int = _queue.pump_count()
	var token: SimClock.LoadBarrier = _hold_barrier()
	for _index: int in 5:
		assert_equal(_queue.pump_into(_report), 0, "a load frame pumps nothing")
	assert_equal(_report.applied, 0, "and the report says so rather than carrying a stale count")
	assert_equal(_queue.pending_count(), 1, "the pending resume is still pending")
	assert_equal(_queue.pump_count(), pumps, "no pump was even counted")
	assert_true(_clock.is_paused(), "and the clock is still holding its PLAYER pause")
	assert_true(token.release(), "release")
	assert_equal(_queue.pump(), 1, "the pending record applies once, after the guard releases")
	assert_false(_clock.is_paused(), "resuming the clock then and not before")


func test_clear_is_barred_so_a_load_cannot_discard_the_queue_it_is_restoring() -> void:
	"""`clear()` is world initialization; running it mid-load would lose the restored records."""
	assert_true(_queue.submit_speed_into(4, _result), "one pending event")
	var before: String = _queue_snapshot()
	var token: SimClock.LoadBarrier = _hold_barrier()
	assert_false(_queue.clear(), "clear is barred")
	assert_equal(_queue.pending_count(), 1, "so the pending event survives the load")
	assert_equal(_queue_snapshot(), before, "with the whole queue byte-identical")
	assert_true(token.release(), "release")
	assert_true(_queue.clear(), "clear runs once the barrier is down")
	assert_equal(_queue.pending_count(), 0, "discarding the event then, and not before")


func test_rebinding_is_barred_on_an_EMPTY_queue_that_would_otherwise_rebind_freely() -> void:
	"""The barrier is read THROUGH `_clock`, so a rebind would be an escape from it.

	The queue is deliberately empty: `rebind_clock()` already refuses a non-empty one, so a test
	that left an event queued would pass against no barrier check at all.
	"""
	assert_equal(_queue.pending_count(), 0, "an empty queue, which would rebind freely")
	var replacement: SimClock = SimClock.new()
	var token: SimClock.LoadBarrier = _hold_barrier()
	assert_false(_queue.rebind_clock(replacement), "rebinding to an unbarred clock is barred")
	assert_equal(_queue.clock(), _clock, "so the queue still reads the barred clock")
	assert_true(_queue.is_load_barrier_held(), "and the barrier cannot be escaped that way")
	assert_equal(_queue.last_refusal(), Scheduler.REFUSE_NONE,
		"the barred call recorded no queue refusal of its own")
	assert_true(token.release(), "release")
	assert_true(_queue.rebind_clock(replacement), "the same rebind lands once the barrier is down")


func test_frame_entry_points_are_barred_at_the_queue_as_well_as_at_the_clock() -> void:
	"""Either can be reached directly through the raw objects, so both refuse."""
	assert_true(_queue.submit_player_resume_into(_result), "resume queued")
	_queue.pump_into(_report)
	var tick: int = _clock.completed_tick()
	assert_true(_queue.submit_overload_downgrade_into(SimClock.SPEED_DOUBLE, _result),
		"spend this frame's single overload issue before the load")
	assert_true(_queue.overload_issued_this_frame(), "which is now spent")
	var token: SimClock.LoadBarrier = _hold_barrier()
	for _index: int in 10:
		assert_equal(_queue.advance_frame(100000, _count_step), 0, "a barred frame runs no tick")
	assert_equal(_clock.completed_tick(), tick, "the completed tick never moved")
	assert_equal(_clock.debt(), 0, "and no elapsed time became debt")
	assert_equal(_steps_run, 0, "no step callback ran")
	assert_true(_queue.overload_issued_this_frame(),
		"and no barred frame was OPENED either, so the spent issue stays spent")
	assert_false(_queue.begin_host_frame(), "opening one directly is barred too")
	assert_true(_queue.overload_issued_this_frame(), "leaving it spent as well")
	assert_true(token.release(), "release")
	assert_true(_queue.advance_frame(100000, _count_step) > 0, "the next real frame runs ticks")


func test_the_loaders_own_install_operations_pass_through_the_barrier() -> void:
	"""`restore_extension()` and `restore_sequence()` are what the barrier is raised FOR."""
	assert_true(_queue.submit_speed_into(4, _result), "build a queue worth saving")
	assert_true(_queue.submit_safety_hold_into(SimClock.MENU, _result), "with two records")
	var bytes: PackedByteArray = _encoded_extension(_queue)
	var loaded: Scheduler = Scheduler.new(_clock)
	var token: SimClock.LoadBarrier = _hold_barrier()
	assert_true(loaded.restore_extension(bytes, 0, 0), "the section 12 install writes through")
	assert_equal(loaded.pending_count(), 2, "installing both saved records")
	assert_equal(loaded.head_position(), 0, "from row 0")
	assert_true(loaded.is_load_barrier_held(), "and the barrier still stands over it")
	assert_equal(loaded.pump_into(_report), 0, "which still bars the pump of what it installed")
	var empty: Scheduler = Scheduler.new(_clock)
	assert_true(empty.restore_sequence(0, 4096), "the loader's sequence hook writes through too")
	assert_equal(empty.next_sequence_low(), 4096, "installing the saved next sequence")
	assert_true(token.release(), "release")


func test_a_restored_paused_queue_applies_once_in_order_after_the_guard_releases() -> void:
	"""The ruling's acceptance case: many load frames pump nothing, then the prefix applies once."""
	assert_true(_queue.submit_safety_hold_into(SimClock.MENU, _result), "a MENU hold is saved")
	assert_true(_queue.submit_player_resume_into(_result), "and a player resume behind it")
	var bytes: PackedByteArray = _encoded_extension(_queue)
	var loaded: Scheduler = Scheduler.new(SimClock.new())
	var grant: SimClock.LoadBarrierGrant = loaded.clock().acquire_load_barrier()
	assert_true(grant.is_ok(), "the loaded world's own barrier is granted")
	var token: SimClock.LoadBarrier = grant.token
	assert_true(loaded.restore_extension(bytes, 0, 0), "the saved queue is installed under the guard")
	for _index: int in 6:
		assert_equal(loaded.advance_frame(50000), 0, "each load frame pumps and ticks nothing")
	assert_equal(loaded.pending_count(), 2, "both pending records are still pending")
	assert_true(loaded.clock().has_pause_reason(SimClock.PLAYER),
		"and the restored PLAYER hold has not been resumed implicitly")
	assert_true(token.release(), "release the guard")
	assert_equal(loaded.pump_into(_report), 2, "both records apply at the next boundary")
	assert_equal(_report.pause_events, 2, "both of them pause events, in order")
	assert_true(loaded.clock().has_pause_reason(SimClock.MENU), "the MENU hold landed")
	assert_false(loaded.clock().has_pause_reason(SimClock.PLAYER), "and the resume after it")
