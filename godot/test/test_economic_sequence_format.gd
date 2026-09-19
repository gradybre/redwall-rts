extends "res://test/framework/test_case.gd"
## SAVE-SEQ-R01 v2: exhaustion survives section 12 without stealing an ordinary sequence.

const Commands := preload("res://scripts/core/commands.gd")
const Clock := preload("res://scripts/core/sim_clock.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const Pending := preload("res://scripts/core/save_section_pending_commands.gd")
const Header := preload("res://scripts/core/save_header.gd")
const Scheduler := preload("res://scripts/core/scheduler_events.gd")
const Codec := preload("res://scripts/core/save_codec.gd")


func _command() -> Commands.Command:
	"""Use a valid ordinary command whose payload makes arena retention observable."""
	var command: Commands.Command = Commands.Command.new()
	command.kind = 8
	command.payload = PackedByteArray([17, 29])
	return command


func _capture(queue: Commands, scheduler: Scheduler) -> PackedByteArray:
	"""Capture through the live owner, then encode through the real codec."""
	var record: Pending.Record = Pending.Record.new()
	assert_true(Pending.capture_into(queue, scheduler, record).is_ok(), "capture live allocator")
	var encoded: Pending.EncodeResult = Pending.EncodeResult.new()
	assert_true(Pending.encode_record(record, encoded), "encode live allocator")
	return encoded.bytes


func _round_trip_exhaustion(drained: bool) -> void:
	"""Actually issue the last command; optionally drain it before saving and installing."""
	var clock: Clock = Clock.new()
	var directory: Directory = Directory.new()
	var queue: Commands = Commands.new(clock, directory)
	var scheduler: Scheduler = Scheduler.new(clock)
	assert_true(queue.restore_sequence(4294967295, 4294967295), "last available pair")
	var result: Commands.SubmitResult = Commands.SubmitResult.new()
	assert_true(queue.submit_into(_command(), result), "issue final ordinary command")
	assert_equal(queue.next_sequence_high(), 4294967296, "real transition to terminal")
	assert_equal(queue.next_sequence_low(), 0, "terminal low")
	var command: Commands.Command = Commands.Command.new()
	assert_true(queue.read_into(0, command), "last record exists")
	assert_equal(command.sequence_high, -1, "record high remains i32 bits")
	assert_equal(command.sequence_low, -1, "record low remains i32 bits")
	if drained:
		assert_true(queue.drain_due_into(1, command), "drain final command")
	var bytes: PackedByteArray = _capture(queue, scheduler)
	assert_equal(bytes.decode_u32(0), 3, "schema 3")
	assert_equal(bytes.slice(20, 28).hex_encode(), "0000000001000000", "independent terminal bytes")
	assert_equal(bytes.size(), 76 if drained else 142, "framing adds exactly four bytes")
	var record: Pending.Record = Pending.Record.new()
	assert_true(Pending.decode_into(bytes, 0, record).is_ok(), "decode terminal")
	assert_equal(record.economic_next_sequence_high, 4294967296, "no truncation")
	var restored: Commands = Commands.new(clock, directory)
	var restored_scheduler: Scheduler = Scheduler.new(clock)
	assert_false(restored.restore_sequence(4294967296, 0), "legacy u32 hook is unchanged")
	var grant: Clock.LoadBarrierGrant = clock.acquire_load_barrier()
	assert_true(grant.is_ok(), "actual target barrier")
	assert_true(Pending.apply(record, restored, restored_scheduler, 0).is_ok(), "joint install")
	assert_true(grant.token.release(), "resume ordinary admission")
	assert_equal(_capture(restored, restored_scheduler), bytes, "exact saved state restored")
	assert_false(restored.submit_into(_command(), result), "exhaustion survives load")
	assert_equal(result.error, Commands.REFUSE_SEQUENCE_EXHAUSTED, "explicit exhaustion")
	assert_equal(_capture(restored, restored_scheduler), bytes, "refusal leaves authoritative state")
	assert_equal(restored.accepted_count(), 0, "restoration is not admission")


func test_last_issued_command_round_trip() -> void:
	"""The terminal allocator coexists with a pending final ordinary record."""
	_round_trip_exhaustion(false)


func test_drained_exhausted_queue_round_trip() -> void:
	"""Exhaustion persists even when no pending record can reveal its history."""
	_round_trip_exhaustion(true)


func test_prefix_writer_refuses_invalid_tuple_without_any_write() -> void:
	"""Predirty all fields: a late rejection must not leave a partial schema 3 prefix."""
	for pair: Array in [[-1, 0], [0, -1], [4294967296, 1], [4294967297, 0],
			[8589934592, 0], [0, 4294967296]]:
		var bytes: PackedByteArray = PackedByteArray()
		bytes.resize(44)
		bytes.fill(165)
		var before: PackedByteArray = bytes.duplicate()
		assert_false(Scheduler.encode_section_prefix_into(bytes, 8, 0, 0, 0,
			int(pair[1]), int(pair[0])), "invalid pair")
		assert_equal(bytes, before, "no leading field or sentinel overwritten")


func test_prefix_writer_refuses_extreme_offsets_without_any_write() -> void:
	"""Bounds use subtraction and cannot wrap at INT64_MAX."""
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(28)
	bytes.fill(165)
	var before: PackedByteArray = bytes.duplicate()
	for offset: int in [-1, 1, Codec.INT64_MAX]:
		assert_false(Scheduler.encode_section_prefix_into(bytes, offset, 0, 0, 0, 0, 0), "offset refuses")
		assert_equal(bytes, before, "unchanged output")


func test_ordinary_high_words_keep_unsigned_values_and_zero_is_ordinary() -> void:
	"""The high bit of the old u32 word is never interpreted as the sign of the new u64."""
	for high: int in [0, 2147483647, 2147483648, 4294967295, 4294967296]:
		var clock: Clock = Clock.new()
		var queue: Commands = Commands.new(clock, Directory.new())
		var scheduler: Scheduler = Scheduler.new(clock)
		var record: Pending.Record = Pending.Record.new()
		assert_true(Pending.capture_into(queue, scheduler, record).is_ok(), "empty fixture")
		record.economic_next_sequence_high = high
		var encoded: Pending.EncodeResult = Pending.EncodeResult.new()
		assert_true(Pending.encode_record(record, encoded), "valid high encodes")
		assert_equal(encoded.bytes.decode_u64(20), high, "eight-byte value")
		var decoded: Pending.Record = Pending.Record.new()
		assert_true(Pending.decode_into(encoded.bytes, 0, decoded).is_ok(), "valid high decodes")
		assert_equal(decoded.economic_next_sequence_high, high, "unsigned value retained")


func _decode_refusal(bytes: PackedByteArray, offset: int, expected: StringName) -> Header.Refusal:
	"""Snapshot the full caller Record through encoding, and the hostile input independently."""
	var clock: Clock = Clock.new()
	var queue: Commands = Commands.new(clock, Directory.new())
	var scheduler: Scheduler = Scheduler.new(clock)
	var result: Commands.SubmitResult = Commands.SubmitResult.new()
	assert_true(queue.submit_into(_command(), result), "predirty caller record")
	var record: Pending.Record = Pending.Record.new()
	assert_true(Pending.capture_into(queue, scheduler, record).is_ok(), "snapshot caller")
	var before: Pending.EncodeResult = Pending.EncodeResult.new()
	assert_true(Pending.encode_record(record, before), "snapshot encoding")
	var input_before: PackedByteArray = bytes.duplicate()
	var refusal: Header.Refusal = Pending.decode_into(bytes, offset, record)
	assert_equal(refusal.code, expected, "precise refusal")
	var after: Pending.EncodeResult = Pending.EncodeResult.new()
	assert_true(Pending.encode_record(record, after), "caller remains encodable")
	assert_equal(after.bytes, before.bytes, "every saved caller field unchanged")
	assert_equal(bytes, input_before, "input untouched")
	return refusal


func test_schema_is_recognized_before_full_prefix_is_required() -> void:
	"""A complete old schema word reports compatibility, including a 24-byte schema 2 prefix."""
	for version: int in [1, 2, 4]:
		var bytes: PackedByteArray = PackedByteArray()
		bytes.resize(24 if version == 2 else 4)
		bytes.encode_u32(0, version)
		var refusal: Header.Refusal = _decode_refusal(bytes, 0, Pending.REFUSE_SECTION_SCHEMA)
		assert_true(refusal.detail.contains("schema %d" % version), "actual version named")
		assert_true(refusal.detail.contains("supported 3"), "supported version named")
	for size: int in [0, 1, 2, 3, 4, 27]:
		var bytes: PackedByteArray = PackedByteArray()
		bytes.resize(size)
		if size >= 4:
			bytes.encode_u32(0, 3)
		_decode_refusal(bytes, 0, Pending.REFUSE_TRUNCATED)


func test_invalid_u64_and_terminal_tuples_refuse_atomically() -> void:
	"""Reject the u64 sign bit and all unused positive high states, without silent zero."""
	var clock: Clock = Clock.new()
	var bytes: PackedByteArray = _capture(Commands.new(clock, Directory.new()), Scheduler.new(clock))
	for pair: Array in [[4294967296, 1], [4294967297, 0], [8589934592, 0]]:
		var hostile: PackedByteArray = bytes.duplicate()
		hostile.encode_u64(20, int(pair[0]))
		hostile.encode_u32(16, int(pair[1]))
		_decode_refusal(hostile, 0, Pending.REFUSE_SEQUENCE_RANGE)
	bytes[27] = 128
	_decode_refusal(bytes, 0, Pending.REFUSE_SEQUENCE_RANGE)
	_decode_refusal(bytes, Codec.INT64_MAX, Pending.REFUSE_TRUNCATED)
	_decode_refusal(bytes, -1, Pending.REFUSE_NEGATIVE_OFFSET)


func test_section_size_constants_are_pinned_independently() -> void:
	"""Only the saved high word widens; records and the nested scheduler extension do not."""
	assert_equal(Pending.EMPTY_SECTION_BYTES, 76, "empty section")
	assert_equal(Pending.MAX_SECTION_BYTES, 1318988, "maximum section")
	assert_equal(Scheduler.section_twelve_length(4096, 1048576, 256), 1318988, "maximum formula")
	assert_equal(Commands.RECORD_BYTES, 64, "economic record unchanged")
	assert_equal(Scheduler.RECORD_BYTES, 32, "scheduler record unchanged")
