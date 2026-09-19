extends "res://test/framework/test_case.gd"
## SAVE-REPLAY-R01: aligned format2 header and redundant checkpoint binding, not a disk coordinator.

const Header := preload("res://scripts/core/save_header.gd")
const Codec := preload("res://scripts/core/save_codec.gd")
const Pending := preload("res://scripts/core/save_section_pending_commands.gd")
const Commands := preload("res://scripts/core/commands.gd")
const Clock := preload("res://scripts/core/sim_clock.gd")
const Directory := preload("res://scripts/core/entity_directory.gd")
const Scheduler := preload("res://scripts/core/scheduler_events.gd")

# Independent Python struct vector is inserted below; no expected bytes come from the codec.
const PINNED_HEADER_HEX: String = "52574c53455430310200000008010000040302010f000000c80400000000000007000000000000001111111111111111111111111111111111111111111111111111111111111111222222222222222222222222222222222222222222222222222222222222222233333333333333333333333333333333333333333333333333333333333333334444444444444444444444444444444444444444444444444444444444444444555555555555555555555555555555555555555555555555555555555555555508010000000000000300000000000000efcdab890000000000000080000000006666666666666666666666666666666666666666666666666666666666666666"


func _header() -> Header.Header:
	"""A fully encodable header with six distinguishable fixture digests."""
	var header: Header.Header = Header.Header.new()
	header.total_file_bytes = 1224
	header.completed_tick = 7
	header.chronicle_record_count = 3
	header.economic_next_sequence_low = 2309737967
	header.economic_next_sequence_high = 2147483648
	header.rules_hash = "11".repeat(32).hex_decode()
	header.catalog_hash = "22".repeat(32).hex_decode()
	header.map_hash = "33".repeat(32).hex_decode()
	header.lookup_hash = "44".repeat(32).hex_decode()
	header.engine_hash = "55".repeat(32).hex_decode()
	header.body_digest = "66".repeat(32).hex_decode()
	return header


func _encode(header: Header.Header) -> PackedByteArray:
	"""Use the real writer and report fixture failures before returning bytes."""
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(264)
	var refusal: Header.Refusal = Header.encode_header_into(header, bytes)
	assert_true(refusal.is_ok(), "fixture encode: %s %s" % [refusal.code, refusal.detail])
	return bytes


func _decode_refuses(bytes: PackedByteArray, code: StringName) -> void:
	"""All saved caller fields and hostile input bytes survive a refused decode."""
	var out: Header.Header = _header()
	var before: PackedByteArray = _encode(out)
	var input_before: PackedByteArray = bytes.duplicate()
	assert_equal(Header.decode_header_into(bytes, out).code, code, "precise decode refusal")
	assert_equal(_encode(out), before, "complete caller header unchanged")
	assert_equal(bytes, input_before, "input untouched")


func test_format2_header_has_an_independent_full_byte_vector() -> void:
	"""Every field, the reserved word and the relocated digest are pinned independently."""
	var bytes: PackedByteArray = _encode(_header())
	assert_equal(bytes.hex_encode(), PINNED_HEADER_HEX, "all264bytes independently pinned")
	assert_equal(Header.HEADER_BYTES, 264, "new header")
	assert_equal(Header.SECTION_TABLE_OFFSET, 264, "new table")
	assert_equal(Header.body_offset(), 1224, "264 +15*64")
	assert_equal(bytes.slice(216, 232).hex_encode(), "efcdab89000000000000008000000000", "checkpoint layout")
	var out: Header.Header = Header.Header.new()
	assert_true(Header.decode_header_into(PINNED_HEADER_HEX.hex_decode(), out).is_ok(), "independent bytes decode")
	assert_equal(_encode(out), bytes, "all fields retained")


func test_full_checkpoint_domain_round_trips_without_signed_combination() -> void:
	"""Zero, both old sign boundaries, final available and terminal are separate states."""
	for pair: Array in [[0, 0], [0, 4294967295], [2147483647, 2147483648],
			[2147483648, 4294967295], [4294967295, 4294967295], [4294967296, 0]]:
		var header: Header.Header = _header()
		header.economic_next_sequence_high = int(pair[0])
		header.economic_next_sequence_low = int(pair[1])
		var bytes: PackedByteArray = _encode(header)
		var out: Header.Header = Header.Header.new()
		assert_true(Header.decode_header_into(bytes, out).is_ok(), "valid pair decodes")
		assert_equal(out.economic_next_sequence_high, int(pair[0]), "positive high")
		assert_equal(out.economic_next_sequence_low, int(pair[1]), "positive low")
		assert_true(Header.header_refusal(out, 1224).is_ok(), "semantic header accepts")
		assert_true(Header.checkpoint_binding_refusal(out, int(pair[0]), int(pair[1]), 7).is_ok(), "exact binding")
		if int(pair[0]) == 4294967296:
			assert_equal(bytes.slice(216, 232).hex_encode(), "00000000000000000000000001000000", "terminal bytes")


func test_invalid_tuple_writer_and_semantic_validator_agree_atomically() -> void:
	"""The complete65bit domain is checked before a schema word or digest can be written."""
	for pair: Array in [[-1, 0], [0, -1], [0, 4294967296], [4294967296, 1],
			[4294967297, 0], [8589934592, 0], [Codec.INT64_MAX, 0]]:
		var header: Header.Header = _header()
		header.economic_next_sequence_high = int(pair[0])
		header.economic_next_sequence_low = int(pair[1])
		var bytes: PackedByteArray = PackedByteArray()
		bytes.resize(279)
		bytes.fill(165)
		var before: PackedByteArray = bytes.duplicate()
		assert_equal(Header.encode_header_into(header, bytes).code, Header.REFUSE_SEQUENCE_RANGE, "tuple writer refusal")
		assert_equal(bytes, before, "all destination bytes unchanged")
		assert_equal(Header.header_refusal(header, 1224).code, Header.REFUSE_SEQUENCE_RANGE, "semantic refusal")


func test_reserved_word_is_carried_and_rejected_without_normalization() -> void:
	"""Padding is checked both from an in-memory caller and from hostile bytes."""
	var header: Header.Header = _header()
	header.checkpoint_reserved_zero = 1
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(264)
	bytes.fill(165)
	var before: PackedByteArray = bytes.duplicate()
	assert_equal(Header.encode_header_into(header, bytes).code, Header.REFUSE_RESERVED_NONZERO, "writer padding gate")
	assert_equal(bytes, before, "writer unchanged")
	assert_equal(Header.header_refusal(header, 1224).code, Header.REFUSE_RESERVED_NONZERO, "semantic padding gate")
	var hostile: PackedByteArray = PINNED_HEADER_HEX.hex_decode()
	hostile.encode_u32(220, 1)
	_decode_refuses(hostile, Header.REFUSE_RESERVED_NONZERO)


func test_hostile_high_u64_and_terminal_low_refuse_without_copying() -> void:
	"""The high sign bit cannot become zero or a negative allocator in caller state."""
	for high: int in [4294967297, 8589934592, Codec.INT64_MAX]:
		var bytes: PackedByteArray = PINNED_HEADER_HEX.hex_decode()
		bytes.encode_u64(224, high)
		_decode_refuses(bytes, Header.REFUSE_SEQUENCE_RANGE)
	var sign_bit: PackedByteArray = PINNED_HEADER_HEX.hex_decode()
	sign_bit[231] = 128
	_decode_refuses(sign_bit, Header.REFUSE_SEQUENCE_RANGE)
	var terminal_low: PackedByteArray = PINNED_HEADER_HEX.hex_decode()
	terminal_low.encode_u64(224, 4294967296)
	terminal_low.encode_u32(216, 1)
	_decode_refuses(terminal_low, Header.REFUSE_SEQUENCE_RANGE)


func test_preamble_precedence_distinguishes_old_future_foreign_and_truncated() -> void:
	"""Legacy format1 is recognized before264bytes are demanded; incomplete preambles truncate."""
	var valid: PackedByteArray = PINNED_HEADER_HEX.hex_decode()
	for size: int in [0, 7, 8, 11, 12, 15, 16, 256, 263]:
		_decode_refuses(valid.slice(0, size), Header.REFUSE_HEADER_TRUNCATED)
	for version: int in [0, 1, 3, 4294967295]:
		for size: int in [16, 256, 264]:
			var bytes: PackedByteArray = valid.slice(0, size)
			bytes.encode_u32(8, version)
			var expected: StringName = Header.REFUSE_FUTURE_FORMAT_VERSION if version > 2 else Header.REFUSE_FORMAT_VERSION
			assert_equal(Header.preamble_refusal(bytes).code, expected, "explicit preamble version")
			_decode_refuses(bytes, expected)
	var foreign: PackedByteArray = valid.slice(0, 16)
	foreign[0] = 0
	foreign.encode_u32(8, 1)
	_decode_refuses(foreign, Header.REFUSE_MAGIC)
	assert_true(Header.preamble_refusal(valid.slice(0, 16)).is_ok(), "preamble alone validates dispatch only")
	assert_equal(Header.header_refusal(_header(), 264).code, Header.REFUSE_FILE_LENGTH, "whole file still requires extent check")


func test_old_header_metadata_has_no_public_writer() -> void:
	"""The codec cannot emit a forbidden old version even when supplied an ample output buffer."""
	for field: String in ["format", "header", "table"]:
		var header: Header.Header = _header()
		var expected: StringName = Header.REFUSE_FORMAT_VERSION
		if field == "format":
			header.format_version = 1
		elif field == "header":
			header.header_bytes = 256
			expected = Header.REFUSE_HEADER_BYTES
		else:
			header.section_table_offset = 256
			expected = Header.REFUSE_SECTION_TABLE_OFFSET
		var bytes: PackedByteArray = PackedByteArray()
		bytes.resize(264)
		bytes.fill(165)
		var before: PackedByteArray = bytes.duplicate()
		assert_equal(Header.encode_header_into(header, bytes).code, expected, "old metadata refuses")
		assert_equal(bytes, before, "no partial write")


func test_binding_mismatch_is_visible_even_when_body_digest_is_unchanged() -> void:
	"""The body digest excludes header bytes; the explicit cross-check supplies this protection."""
	var bytes: PackedByteArray = _encode(_header())
	bytes.resize(1224)
	var body_before: PackedByteArray = Header.compute_body_digest(bytes)
	for offset: int in [32, 216, 224]:
		var changed: PackedByteArray = bytes.duplicate()
		changed[offset] = changed[offset] ^ 1
		assert_equal(Header.compute_body_digest(changed), body_before, "header corruption does not alter body digest")
		var header: Header.Header = Header.Header.new()
		assert_true(Header.decode_header_into(changed, header).is_ok(), "structurally valid changed checkpoint")
		var before: PackedByteArray = _encode(header)
		assert_equal(Header.checkpoint_binding_refusal(header, 2147483648, 2309737967, 7).code,
			Header.REFUSE_CHECKPOINT_MISMATCH, "explicit high/low/tick cross-check")
		assert_equal(_encode(header), before, "binding validator is pure")


func test_binding_rejects_invalid_inputs_before_reporting_mismatch() -> void:
	"""A matching malformed pair must never pass merely because the two sides are equal."""
	assert_equal(Header.checkpoint_binding_refusal(null, 0, 0, 0).code, Header.REFUSE_VALUE_RANGE, "null header")
	for pair: Array in [[-1, 0], [0, -1], [4294967296, 1], [4294967297, 0], [0, 4294967296]]:
		var header: Header.Header = _header()
		assert_equal(Header.checkpoint_binding_refusal(header, int(pair[0]), int(pair[1]), 7).code,
			Header.REFUSE_SEQUENCE_RANGE, "invalid section12 allocator")
		header.economic_next_sequence_high = int(pair[0])
		header.economic_next_sequence_low = int(pair[1])
		assert_equal(Header.checkpoint_binding_refusal(header, int(pair[0]), int(pair[1]), 7).code,
			Header.REFUSE_SEQUENCE_RANGE, "invalid equal allocators")
	var negative: Header.Header = _header()
	assert_equal(Header.checkpoint_binding_refusal(negative, 2147483648, 2309737967, -1).code,
		Header.REFUSE_NEGATIVE_TICK, "negative section1 tick")
	negative.completed_tick = -1
	assert_equal(Header.checkpoint_binding_refusal(negative, 2147483648, 2309737967, -1).code,
		Header.REFUSE_NEGATIVE_TICK, "equal negative ticks refuse")


func test_actual_exhausted_queue_binds_to_decoded_header_in_both_states() -> void:
	"""Issue and drain a real final command; both section snapshots must bind without inference."""
	var clock: Clock = Clock.new()
	var queue: Commands = Commands.new(clock, Directory.new())
	var scheduler: Scheduler = Scheduler.new(clock)
	assert_true(queue.restore_sequence(4294967295, 4294967295), "last ordinary pair")
	var command: Commands.Command = Commands.Command.new()
	command.kind = 8
	assert_true(queue.submit_into(command, Commands.SubmitResult.new()), "final actual admission")
	for drained: bool in [false, true]:
		if drained:
			assert_true(queue.drain_due_into(1, command), "drain final record")
		var captured: Pending.Record = Pending.Record.new()
		assert_true(Pending.capture_into(queue, scheduler, captured).is_ok(), "actual section12 capture")
		var encoded: Pending.EncodeResult = Pending.EncodeResult.new()
		assert_true(Pending.encode_record(captured, encoded), "actual section12 encoding")
		var decoded: Pending.Record = Pending.Record.new()
		assert_true(Pending.decode_into(encoded.bytes, 0, decoded).is_ok(), "section12 decode")
		var header: Header.Header = _header()
		header.completed_tick = clock.completed_tick()
		header.economic_next_sequence_high = queue.next_sequence_high()
		header.economic_next_sequence_low = queue.next_sequence_low()
		var back: Header.Header = Header.Header.new()
		assert_true(Header.decode_header_into(_encode(header), back).is_ok(), "header decode")
		assert_equal(back.economic_next_sequence_high, 4294967296, "terminal header")
		assert_true(Header.checkpoint_binding_refusal(back, decoded.economic_next_sequence_high,
			decoded.economic_next_sequence_low, clock.completed_tick()).is_ok(), "exact decoded binding")
