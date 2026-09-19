extends "res://test/framework/test_case.gd"
## SAVE-P2-R02: restore exact queue layout and preserve future admission behavior.

const Commands := preload("res://scripts/core/commands.gd")
const Clock := preload("res://scripts/core/sim_clock.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const Pending := preload("res://scripts/core/save_section_pending_commands.gd")
const Header := preload("res://scripts/core/save_header.gd")
const Scheduler := preload("res://scripts/core/scheduler_events.gd")

var _clock: Clock
var _directory: Directory
var _queue: Commands
var _result: Commands.SubmitResult


func before_each() -> void:
	"""Use fresh real owners, without a barrier until a test takes it."""
	_clock = Clock.new()
	_directory = Directory.new()
	_queue = Commands.new(_clock, _directory)
	_result = Commands.SubmitResult.new()


func _command(tick: int = 2, sequence: int = 1) -> Commands.Command:
	"""A valid neutral envelope; independent wire checks pin its 64-byte layout."""
	var command: Commands.Command = Commands.Command.new()
	command.kind = 8
	command.execute_tick = tick
	command.sequence_low = sequence
	command.arg0 = sequence
	return command


func _records(commands: Array) -> PackedByteArray:
	"""Encode fixture envelopes through the public record writer."""
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(commands.size() * 64)
	for index: int in commands.size():
		assert_true(Commands.encode_command_into(commands[index], bytes, index * 64), "fixture encodes")
	return bytes


func _image(queue: Commands) -> Array:
	"""Snapshot observable records, live payloads, cursor, allocator and counters."""
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(queue.pending_count() * 64)
	var payloads: Array = []
	var command: Commands.Command = Commands.Command.new()
	for index: int in queue.pending_count():
		assert_true(queue.encode_record_into(index, bytes, index * 64), "snapshot record")
		assert_true(queue.read_into(index, command), "snapshot command")
		var payload: PackedByteArray = PackedByteArray()
		payload.resize(command.payload_length)
		assert_true(queue.read_payload_into(command, payload), "snapshot payload")
		payloads.append(payload)
	return [bytes, payloads, queue.payload_used(), queue.next_sequence_high(),
		queue.next_sequence_low(), queue.accepted_count(), queue.refused_count(), queue.drained_count()]


func _barrier() -> Clock.LoadBarrier:
	"""Acquire the actual owner's barrier and check the grant."""
	var grant: Clock.LoadBarrierGrant = _clock.acquire_load_barrier()
	assert_true(grant.is_ok(), "fixture owns load barrier")
	return grant.token


func _reject(records: PackedByteArray, arena: PackedByteArray, high: int = 0, low: int = 7) -> void:
	"""Both validation and mutation refusal leave an existing window unchanged."""
	var before: Array = _image(_queue)
	var input_records: PackedByteArray = records.duplicate()
	var input_arena: PackedByteArray = arena.duplicate()
	var diagnostic: StringName = _queue.last_refusal()
	assert_true(_queue.pending_window_refusal(records, arena, high, low) != &"", "validator refuses")
	assert_equal(_queue.last_refusal(), diagnostic, "pure validator retains diagnostic")
	assert_equal(_image(_queue), before, "pure validation retains state")
	assert_false(_queue.restore_pending_window(records, arena, high, low), "restore refuses")
	assert_true(_queue.last_refusal() != &"", "refusal is explicit")
	assert_equal(_image(_queue), before, "refusal retains state and counters")
	assert_equal(records, input_records, "record input unchanged")
	assert_equal(arena, input_arena, "arena input unchanged")


func test_restore_retains_permuted_offsets_holes_dead_tail_and_capacity() -> void:
	"""Highwater, not the sum of live payload lengths, determines the next admission."""
	assert_true(_queue.submit_into(_command(), _result), "prior accepted diagnostic")
	var a: Commands.Command = _command(2, 1)
	var b: Commands.Command = _command(3, 2)
	a.payload_offset = 6
	a.payload_length = 2
	b.payload_offset = 2
	b.payload_length = 2
	var records: PackedByteArray = _records([a, b])
	var arena: PackedByteArray = PackedByteArray([0, 0, 21, 22, 0, 0, 11, 12, 0, 0])
	var token: Clock.LoadBarrier = _barrier()
	assert_true(_queue.restore_pending_window(records, arena, 0, 70), "nonempty replacement")
	var image: Array = _image(_queue)
	assert_equal(image[0], records, "exact record offsets and keys")
	assert_equal(image[1], [PackedByteArray([11, 12]), PackedByteArray([21, 22])], "exact payloads")
	assert_equal(_queue.accepted_count(), 1, "restore is not admission")
	assert_equal(_queue.payload_used(), 10, "dead tail consumes capacity")
	records.fill(0)
	arena.fill(255)
	assert_equal(_image(_queue), image, "caller inputs are not retained")
	assert_true(token.release(), "resume normal commands")
	var next: Commands.Command = _command()
	next.payload.resize(1048567)
	assert_false(_queue.submit_into(next, _result), "one byte beyond remaining capacity refuses")
	assert_equal(_result.error, Commands.REFUSE_PAYLOAD_ARENA_FULL, "capacity refusal")
	next.payload.resize(1048566)
	assert_true(_queue.submit_into(next, _result), "exact remainder accepted")
	assert_equal(_queue.payload_used(), 1048576, "full arena")
	assert_equal(_queue.next_sequence_low(), 71, "one ordinary sequence consumed")
	var out: Commands.Command = Commands.Command.new()
	assert_true(_queue.drain_due_into(1, out), "new current-tick command first")
	assert_equal(out.payload_offset, 10, "appended at saved highwater")
	assert_true(_queue.drain_due_into(2, out), "first restored command next")
	assert_equal(out.arg0, 1, "canonical key order")
	assert_true(_queue.drain_due_into(3, out), "second restored command last")
	assert_equal(out.arg0, 2, "second key")


func test_zero_length_spans_share_offsets_and_may_equal_highwater() -> void:
	"""Empty payloads retain their exact offsets without falsely overlapping live bytes."""
	var a: Commands.Command = _command(2, 1)
	var b: Commands.Command = _command(2, 2)
	var c: Commands.Command = _command(2, 3)
	a.payload_offset = 4
	b.payload_offset = 4
	c.payload_offset = 1
	c.payload_length = 2
	var records: PackedByteArray = _records([a, b, c])
	_barrier()
	assert_true(_queue.restore_pending_window(records, PackedByteArray([0, 1, 2, 0]), 0, 4), "legal empty spans")
	assert_equal(_image(_queue)[0], records, "zero-length offsets retained exactly")


func test_restore_requires_current_held_barrier_even_when_previously_released() -> void:
	"""A released token is not authority for a second install."""
	var records: PackedByteArray = _records([_command()])
	_reject(records, PackedByteArray())
	var token: Clock.LoadBarrier = _barrier()
	assert_true(_queue.restore_pending_window(records, PackedByteArray(), 0, 7), "held barrier accepts")
	assert_true(token.release(), "release token")
	_reject(records, PackedByteArray())


func test_malformed_late_records_and_spans_refuse_before_mutation() -> void:
	"""Corrupt each late field while a prior real window is installed."""
	assert_true(_queue.submit_into(_command(), _result), "preexisting command")
	_barrier()
	var a: Commands.Command = _command(2, 1)
	var b: Commands.Command = _command(3, 2)
	a.payload_length = 1
	b.payload_offset = 2
	b.payload_length = 1
	var clean: PackedByteArray = _records([a, b])
	var arena: PackedByteArray = PackedByteArray([11, 0, 22, 0])
	for mutation: Array in [[8, 9], [20, -1], [24, -2], [28, 1], [48, -1], [48, 4],
			[52, -1], [52, 2147483647], [56, 1], [60, 1]]:
		var corrupt: PackedByteArray = clean.duplicate()
		corrupt.encode_s32(64 + int(mutation[0]), int(mutation[1]))
		_reject(corrupt, arena)
	var overlap: PackedByteArray = clean.duplicate()
	overlap.encode_s32(64 + 48, 0)
	_reject(overlap, arena)
	for garbage_at: int in [1, 3]:
		var dirty: PackedByteArray = arena.duplicate()
		dirty[garbage_at] = 99
		_reject(clean, dirty)
	_reject(clean.slice(0, 127), arena)
	var too_many: PackedByteArray = PackedByteArray()
	too_many.resize(4097 * 64)
	_reject(too_many, PackedByteArray())
	var too_large: PackedByteArray = PackedByteArray()
	too_large.resize(1048577)
	_reject(clean, too_large)
	_reject(PackedByteArray(), PackedByteArray([0]))


func test_stale_target_and_reversed_duplicate_or_past_keys_refuse() -> void:
	"""A valid first row must not publish before the second row is rejected."""
	var ref: Vector2i = _directory.create(Directory.KIND_RESIDENT)
	assert_true(ref.x >= 0, "live fixture target")
	assert_true(_directory.destroy(ref), "target becomes stale")
	_barrier()
	var a: Commands.Command = _command(2, 1)
	var b: Commands.Command = _command(3, 2)
	b.target_slot = ref.x
	b.target_generation = ref.y
	_reject(_records([a, b]), PackedByteArray())
	b.target_slot = -1
	b.target_generation = 0
	_reject(_records([b, a]), PackedByteArray())
	_reject(_records([a, a]), PackedByteArray())
	b.execute_tick = 0
	_reject(_records([a, b]), PackedByteArray())


func test_unsigned_record_keys_and_terminal_allocator_are_distinct() -> void:
	"""An exhausted allocator can coexist with pending records, without consuming a sequence."""
	var a: Commands.Command = _command(2, 2147483647)
	var b: Commands.Command = _command(2, Commands.to_int32_bits(2147483648))
	var records: PackedByteArray = _records([a, b])
	var token: Clock.LoadBarrier = _barrier()
	assert_true(_queue.restore_pending_window(records, PackedByteArray(), 4294967296, 0), "terminal runtime pair")
	assert_equal(_image(_queue)[0], records, "unsigned canonical order retained")
	assert_equal(_queue.next_sequence_high(), 4294967296, "exhaustion retained")
	for tuple: Array in [[-1, 0], [0, -1], [4294967297, 0], [4294967296, 1], [0, 4294967296]]:
		_reject(records, PackedByteArray(), int(tuple[0]), int(tuple[1]))
	assert_true(token.release(), "resume")
	assert_false(_queue.submit_into(_command(), _result), "exhausted ordinary allocator refuses")
	assert_equal(_result.error, Commands.REFUSE_SEQUENCE_EXHAUSTED, "no zero wrap")
	assert_equal(_queue.pending_count(), 2, "pending replay retained")
	assert_equal(_queue.next_sequence_high(), 4294967296, "refusal does not advance")


func test_every_ordinary_mutator_is_barred_without_counter_or_output_changes() -> void:
	"""Only the refusal/result diagnostics may change while a load owns the queue."""
	assert_true(_queue.submit_into(_command(), _result), "existing command")
	var invalid: Commands.Command = _command()
	invalid.kind = -1
	assert_false(_queue.submit_group_into([_command(), invalid], _result), "prime nonzero refused member")
	assert_equal(_result.member, 1, "second member failed")
	var token: Clock.LoadBarrier = _barrier()
	var before: Array = _image(_queue)
	assert_false(_queue.submit_into(_command(), _result), "single barred")
	assert_equal(_result.error, &"COMMAND_LOAD_BARRIER", "explicit barrier refusal")
	assert_false(_queue.submit_group_into([_command()], _result), "group barred")
	assert_false(_queue.submit_id_group_into(_command(), PackedInt32Array(), _result), "ID group barred")
	assert_false(_queue.admit_stamped_into(_command(), _result), "replay admission barred")
	var out: Commands.Command = _command(99, 88)
	var out_before: PackedByteArray = _records([out])
	assert_false(_queue.drain_due_into(999, out), "drain barred")
	assert_equal(_records([out]), out_before, "drain output untouched")
	_queue.clear()
	assert_equal(_queue.last_refusal(), &"COMMAND_LOAD_BARRIER", "clear is barred")
	assert_false(_queue.rebind_clock(Clock.new()), "rebind barred")
	assert_equal(_queue.clock(), _clock, "clock identity retained")
	assert_equal(_image(_queue), before, "all authoritative bytes and counters unchanged")
	assert_equal(_queue.get("_refused_member"), 1, "ordinary guards precede refused-member reset")
	assert_true(token.is_held(), "ordinary calls never release barrier")


func test_constructor_under_barrier_and_rebind_to_barred_clock() -> void:
	"""Private initialization works; public rebind cannot enter another ongoing load."""
	var token: Clock.LoadBarrier = _barrier()
	var constructed: Commands = Commands.new(_clock, _directory)
	assert_equal(constructed.pending_count(), 0, "constructor initialized empty window")
	assert_equal(constructed.payload_available(), 1048576, "constructor initialized arena")
	assert_equal(constructed.next_sequence_low(), 0, "constructor initialized allocator")
	assert_true(constructed.restore_pending_window(_records([_command()]), PackedByteArray(), 0, 4), "initialized columns accept restore")
	var unbarred: Commands = Commands.new()
	var prior: Clock = unbarred.clock()
	assert_false(unbarred.rebind_clock(_clock), "incoming barrier blocks rebind")
	assert_equal(unbarred.clock(), prior, "unbarred prior clock retained")
	assert_true(token.is_held(), "constructor and rebind leave token held")


func test_real_mixed_tick_admission_and_partial_drain_round_trip() -> void:
	"""Allocation order differs from key order even before any partial drain."""
	var scheduler: Scheduler = Scheduler.new(_clock)
	for spec: Array in [[5, 1, 11], [1, 2, 22], [6, 3, 33], [1, 4, 44]]:
		var command: Commands.Command = _command(int(spec[0]), int(spec[1]))
		command.payload = PackedByteArray([int(spec[2])])
		assert_true(_queue.admit_stamped_into(command, _result), "mixed-tick fixture admitted")
	var before_drain: Pending.Record = Pending.Record.new()
	assert_true(Pending.capture_into(_queue, scheduler, before_drain).is_ok(), "capture canonical/allocation disagreement")
	assert_equal(before_drain.payload_offset.slice(0, 4), PackedInt32Array([1, 3, 0, 2]), "nonmonotonic offsets")
	var out: Commands.Command = Commands.Command.new()
	assert_true(_queue.drain_due_into(1, out), "drain interior allocation")
	assert_true(_queue.drain_due_into(1, out), "drain final allocation")
	var record: Pending.Record = Pending.Record.new()
	assert_true(Pending.capture_into(_queue, scheduler, record).is_ok(), "capture with interior hole and dead tail")
	assert_equal(record.payload.slice(0, 4), PackedByteArray([11, 0, 33, 0]), "dead bytes canonicalized")
	var encoded: Pending.EncodeResult = Pending.EncodeResult.new()
	assert_true(Pending.encode_record(record, encoded), "encode actual layout")
	var decoded: Pending.Record = Pending.Record.new()
	assert_true(Pending.decode_into(encoded.bytes, 0, decoded).is_ok(), "decode actual bytes")
	var target: Commands = Commands.new(_clock, _directory)
	var target_scheduler: Scheduler = Scheduler.new(_clock)
	_barrier()
	assert_true(Pending.apply(decoded, target, target_scheduler, 0).is_ok(), "apply actual queues")
	assert_equal(_image(target).slice(0, 5), _image(_queue).slice(0, 5), "exact live state including allocator")
	var recaptured: Pending.Record = Pending.Record.new()
	assert_true(Pending.capture_into(target, target_scheduler, recaptured).is_ok(), "recapture restored owners")
	var round_trip: Pending.EncodeResult = Pending.EncodeResult.new()
	assert_true(Pending.encode_record(recaptured, round_trip), "encode recapture")
	assert_equal(round_trip.bytes, encoded.bytes, "byte-exact round trip")


class FaultScheduler extends Scheduler:
	"""Force a public install refusal after the real preflight succeeds."""
	var observing: Commands = null
	var observed_count: int = -1
	func restore_extension(_bytes: PackedByteArray, _offset: int, _tick: int) -> bool:
		"""Refuse without writing or fabricating a diagnostic, exercising the adapter fallback."""
		if observing != null:
			observed_count = observing.pending_count()
		return false


class FaultCommands extends Commands:
	"""Permit install, then refuse the public recovery call; no production fault switches."""
	var calls_until_failure: int = 1

	func restore_pending_window(records: PackedByteArray, arena: PackedByteArray,
			high: int, low: int) -> bool:
		"""Fail exactly the configured public restore call without mutating the owner."""
		if calls_until_failure == 0:
			return false
		calls_until_failure -= 1
		return super.restore_pending_window(records, arena, high, low)


func _saved_pair() -> Pending.Record:
	"""A real incoming economic command and scheduler event, captured before any barrier."""
	assert_true(_queue.submit_into(_command(), _result), "source economic command")
	var scheduler: Scheduler = Scheduler.new(_clock)
	var result: Scheduler.SubmitResult = Scheduler.SubmitResult.new()
	assert_true(scheduler.submit_speed_into(4, result), "source scheduler event")
	var record: Pending.Record = Pending.Record.new()
	assert_true(Pending.capture_into(_queue, scheduler, record).is_ok(), "source pair capture")
	return record


func _scheduler_image(store: Scheduler) -> PackedByteArray:
	"""Read control and queue bytes independently of the pending codec."""
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(store.extension_byte_length())
	assert_true(store.encode_extension_into(bytes, 0), "scheduler snapshot")
	return bytes


func test_codec_requires_same_clock_same_tick_and_held_barrier() -> void:
	"""Equal tick values on different clock objects do not establish a shared world."""
	var record: Pending.Record = _saved_pair()
	var target: Commands = Commands.new(_clock, _directory)
	var scheduler: Scheduler = Scheduler.new(_clock)
	var before: Array = _image(target)
	var scheduler_before: PackedByteArray = _scheduler_image(scheduler)
	assert_false(Pending.apply(record, target, scheduler, 0).is_ok(), "no barrier refuses")
	var token: Clock.LoadBarrier = _barrier()
	assert_false(Pending.apply(record, target, Scheduler.new(Clock.new()), 0).is_ok(), "different clock refuses")
	assert_false(Pending.apply(record, target, scheduler, 4).is_ok(), "saved tick mismatch refuses")
	assert_false(Pending.apply(record, null, scheduler, 0).is_ok(), "null economic owner refuses")
	assert_false(Pending.apply(record, target, null, 0).is_ok(), "null scheduler refuses")
	assert_false(Pending.apply(null, target, scheduler, 0).is_ok(), "null record refuses")
	assert_true(token.release(), "release fixture barrier")
	assert_false(Pending.apply(record, target, scheduler, 0).is_ok(), "released barrier refuses")
	assert_equal(_image(target), before, "economic state unchanged")
	assert_equal(_scheduler_image(scheduler), scheduler_before, "scheduler state unchanged")


func test_late_scheduler_failure_restores_prior_empty_economic_allocator() -> void:
	"""Commands install first; failed scheduler install recovers the exact prior allocator."""
	var record: Pending.Record = _saved_pair()
	var target: Commands = Commands.new(_clock, _directory)
	var scheduler: FaultScheduler = FaultScheduler.new(_clock)
	scheduler.observing = target
	assert_true(target.restore_sequence(2147483648, 71), "distinct prior allocator")
	var before: Array = _image(target)
	var scheduler_before: PackedByteArray = _scheduler_image(scheduler)
	var token: Clock.LoadBarrier = _barrier()
	var refusal: Header.Refusal = Pending.apply(record, target, scheduler, 0)
	assert_false(refusal.is_ok(), "late failure refuses")
	assert_true(refusal.detail.length() > 0, "failure explained even with empty owner diagnostic")
	assert_equal(scheduler.observed_count, 1, "scheduler failed after economic install")
	assert_equal(_image(target), before, "empty queue and exact high/low recovered")
	assert_equal(_scheduler_image(scheduler), scheduler_before, "scheduler unchanged")
	assert_true(token.is_held(), "adapter retains caller barrier")


func test_late_scheduler_failure_can_recover_a_terminal_prior_allocator() -> void:
	"""The prior empty runtime state may be exhausted even while schema2 cannot encode it."""
	var record: Pending.Record = _saved_pair()
	var target: Commands = Commands.new(_clock, _directory)
	var scheduler: FaultScheduler = FaultScheduler.new(_clock)
	scheduler.observing = target
	_barrier()
	assert_true(target.restore_pending_window(PackedByteArray(), PackedByteArray(), 4294967296, 0), "prior terminal state")
	var before: Array = _image(target)
	assert_false(Pending.apply(record, target, scheduler, 0).is_ok(), "late failure")
	assert_equal(scheduler.observed_count, 1, "terminal recovery follows actual economic install")
	assert_equal(_image(target), before, "terminal prior allocator recovered")


func test_failed_economic_recovery_reports_uncertainty_and_holds_barrier() -> void:
	"""Recovery cannot be assumed successful after the second public owner refusal."""
	var record: Pending.Record = _saved_pair()
	var target: FaultCommands = FaultCommands.new(_clock, _directory)
	var scheduler: FaultScheduler = FaultScheduler.new(_clock)
	scheduler.observing = target
	assert_true(target.restore_sequence(0, 71), "distinct prior sequence")
	var before: Array = _image(target)
	var scheduler_before: PackedByteArray = _scheduler_image(scheduler)
	var token: Clock.LoadBarrier = _barrier()
	assert_equal(Pending.apply(record, target, scheduler, 0).code, &"SAVE_PC_ROLLBACK_FAILED", "distinct uncertainty")
	assert_true(_image(target) != before, "injected failed recovery actually left installed commands")
	assert_equal(target.pending_count(), 1, "commands had installed before scheduler refusal")
	assert_equal(_scheduler_image(scheduler), scheduler_before, "scheduler refused atomically")
	assert_true(token.is_held(), "failure never exposes partial state through barrier release")


func test_first_economic_install_failure_leaves_both_queues_unchanged() -> void:
	"""A refused first owner must not install scheduler work."""
	var record: Pending.Record = _saved_pair()
	var target: FaultCommands = FaultCommands.new(_clock, _directory)
	target.calls_until_failure = 0
	var scheduler: Scheduler = Scheduler.new(_clock)
	var before: Array = _image(target)
	var scheduler_before: PackedByteArray = _scheduler_image(scheduler)
	_barrier()
	assert_false(Pending.apply(record, target, scheduler, 0).is_ok(), "first install refuses")
	assert_equal(_image(target), before, "economic unchanged")
	assert_equal(_scheduler_image(scheduler), scheduler_before, "scheduler never installed")


func test_success_preserves_nonzero_admission_refusal_and_drain_counters() -> void:
	"""Privileged assignment must not erase operational diagnostics through ordinary clear."""
	assert_true(_queue.submit_into(_command(), _result), "one accepted command")
	var out: Commands.Command = Commands.Command.new()
	assert_true(_queue.drain_due_into(1, out), "one drained command")
	var bad: Commands.Command = _command()
	bad.kind = -1
	assert_false(_queue.submit_into(bad, _result), "one refused command")
	assert_equal([_queue.accepted_count(), _queue.refused_count(), _queue.drained_count()], [1, 1, 1], "nonzero diagnostic fixture")
	_barrier()
	assert_true(_queue.restore_pending_window(_records([_command()]), PackedByteArray(), 0, 7), "privileged install")
	assert_equal([_queue.accepted_count(), _queue.refused_count(), _queue.drained_count()], [1, 1, 1], "all counters preserved")


func test_high_sequence_word_order_is_unsigned_too() -> void:
	"""Low-word coverage alone would miss a signed comparison of the major sequence word."""
	var a: Commands.Command = _command(2, 99)
	var b: Commands.Command = _command(2, 1)
	a.sequence_high = 2147483647
	b.sequence_high = Commands.to_int32_bits(2147483648)
	var token: Clock.LoadBarrier = _barrier()
	var records: PackedByteArray = _records([a, b])
	assert_true(_queue.restore_pending_window(records, PackedByteArray(), 0, 7), "unsigned high words accepted in order")
	_reject(_records([b, a]), PackedByteArray())
	assert_true(token.release(), "resume drain")
	var out: Commands.Command = Commands.Command.new()
	assert_true(_queue.drain_due_into(2, out), "first key drains")
	assert_equal(out.sequence_high, 2147483647, "unsigned earlier high")
	assert_true(_queue.drain_due_into(2, out), "second key drains")
	assert_equal(Commands.to_uint32(out.sequence_high), 2147483648, "unsigned later high")


func test_exact_record_capacity_restores_without_allocating_sequences() -> void:
	"""A full saved queue is valid even though normal admission has no room left."""
	var records: PackedByteArray = PackedByteArray()
	records.resize(4096 * 64)
	var command: Commands.Command = _command()
	for index: int in 4096:
		command.sequence_low = index
		assert_true(Commands.encode_command_into(command, records, index * 64), "full-window fixture row")
	var token: Clock.LoadBarrier = _barrier()
	assert_true(_queue.restore_pending_window(records, PackedByteArray(), 0, 0), "exact capacity restore")
	assert_equal(_queue.pending_count(), 4096, "all rows restored")
	assert_equal(_queue.next_sequence_low(), 0, "initial allocator zero has ordinary meaning")
	assert_equal(_image(_queue)[0], records, "last row and all prior rows retained")
	assert_true(token.release(), "resume")
	assert_false(_queue.submit_into(_command(), _result), "no room for one more command")
	assert_equal(_result.error, Commands.REFUSE_QUEUE_FULL, "actual capacity bound")
	assert_equal(_queue.next_sequence_low(), 0, "refusal does not consume sequence")
