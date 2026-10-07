extends "res://test/framework/test_case.gd"
## Suite for `save_section_chronicle.gd`, the section 13 codec (ADR 1222 step 5, DEC-055 Q8).
##
## With the event domain empty the only valid section is the 40-byte empty one. Nonempty streams
## are still built here -- with a digest chained independently through HashingContext -- so the
## refusal ORDER (integrity before semantics) and the bounded streaming are both proved.

const Chronicle := preload("res://scripts/core/chronicle.gd")
const Section := preload("res://scripts/core/save_section_chronicle.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const Digest := preload("res://scripts/core/canonical_state_hash.gd")


func _empty_section() -> PackedByteArray:
	"""The canonical empty section: count 0 then 32 zero digest bytes."""
	var record: Section.Record = Section.Record.new()
	var out: Section.EncodeResult = Section.EncodeResult.new()
	assert_true(Section.encode_section(record, PackedByteArray(), out), "the empty section encodes")
	return out.bytes


func _chain(history: PackedByteArray) -> PackedByteArray:
	"""The rolling digest of `history`, chained with HashingContext and never through the codec."""
	var digest: PackedByteArray = Chronicle.zero_digest()
	@warning_ignore("integer_division") var records: int = history.size() / Chronicle.RECORD_BYTES
	for index: int in records:
		var context: HashingContext = HashingContext.new()
		context.start(HashingContext.HASH_SHA256)
		context.update(digest)
		context.update(history.slice(index * 24, index * 24 + 24))
		digest = context.finish()
	return digest


func _section_with(history: PackedByteArray, digest: PackedByteArray) -> PackedByteArray:
	"""A raw section carrying `history` under a declared digest, bypassing the encoder's checks."""
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(8)
	@warning_ignore("integer_division") var records: int = history.size() / Chronicle.RECORD_BYTES
	bytes.encode_u64(0, records)
	bytes.append_array(digest)
	bytes.append_array(history)
	return bytes


func _decode(bytes: PackedByteArray) -> SaveHeader.Refusal:
	"""Decode `bytes` as a whole section at offset 0 into a scratch Record."""
	return Section.decode_section_into(bytes, 0, bytes.size(), Section.Record.new())


func _owner_image(chronicle: Chronicle) -> PackedByteArray:
	"""Count then digest: the owner's whole observable state."""
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(8)
	bytes.encode_s64(0, chronicle.count())
	bytes.append_array(chronicle.rolling_digest())
	return bytes


func test_empty_section_is_forty_bytes_and_round_trips_into_a_fresh_owner() -> void:
	"""Capture -> encode -> decode -> apply reproduces the empty owner exactly."""
	var source: Chronicle = Chronicle.new()
	var captured: Section.Record = Section.Record.new()
	assert_true(Section.capture_into(source, captured).is_ok(), "capture succeeds")
	var out: Section.EncodeResult = Section.EncodeResult.new()
	assert_true(Section.encode_section(captured, PackedByteArray(), out), "encode succeeds")
	assert_equal(out.bytes.size(), Section.EMPTY_SECTION_BYTES, "40 bytes")
	var decoded: Section.Record = Section.Record.new()
	assert_true(Section.decode_section_into(out.bytes, 0, out.bytes.size(), decoded).is_ok(),
		"decode succeeds")
	var target: Chronicle = Chronicle.new()
	assert_true(Section.apply(decoded, target).is_ok(), "apply succeeds")
	assert_equal(_owner_image(target), _owner_image(source), "the owner round-trips exactly")


func test_decode_at_an_offset_inside_a_larger_buffer() -> void:
	"""The section is read where the descriptor says, not at the buffer start."""
	var bytes: PackedByteArray = PackedByteArray([9, 9, 9])
	bytes.append_array(_empty_section())
	bytes.append_array(PackedByteArray([7]))
	assert_true(Section.decode_section_into(bytes, 3, 40, Section.Record.new()).is_ok(),
		"an embedded section decodes")


func test_truncated_and_misdeclared_lengths_refuse() -> void:
	"""Short buffers, short descriptors and a length that disagrees with the count all refuse."""
	var empty: PackedByteArray = _empty_section()
	assert_equal(Section.decode_section_into(empty, 0, 39, Section.Record.new()).code,
		Section.REFUSE_TRUNCATED, "39 bytes is truncated")
	assert_equal(Section.decode_section_into(empty, 1, 40, Section.Record.new()).code,
		Section.REFUSE_TRUNCATED, "40 bytes past offset 1 exceed the buffer")
	assert_equal(Section.decode_section_into(empty, -1, 40, Section.Record.new()).code,
		Section.REFUSE_NEGATIVE_OFFSET, "a negative offset refuses")
	var padded: PackedByteArray = empty.duplicate()
	padded.append_array(PackedByteArray([0]))
	assert_equal(_decode(padded).code, Section.REFUSE_LENGTH, "a trailing byte refuses")


func test_count_range_and_empty_digest_rules_refuse() -> void:
	"""A count beyond the overflow bound, and a nonzero digest at count 0, both refuse."""
	var huge: PackedByteArray = _empty_section()
	huge.encode_u64(0, Section.MAX_RECORD_COUNT + 1)
	assert_equal(_decode(huge).code, Section.REFUSE_COUNT_RANGE, "an overflowing count refuses")
	var dirty: PackedByteArray = _empty_section()
	dirty[20] = 1
	assert_equal(_decode(dirty).code, Section.REFUSE_EMPTY_DIGEST,
		"an empty section must carry the zero digest")


func test_a_corrupt_stream_reports_digest_mismatch_before_semantics() -> void:
	"""A record under the wrong digest is integrity damage, refused before its event is judged."""
	var history: PackedByteArray = PackedByteArray()
	history.resize(24)
	var wrong: PackedByteArray = _chain(history)
	wrong[0] = wrong[0] ^ 0xff
	assert_equal(_decode(_section_with(history, wrong)).code, Section.REFUSE_DIGEST_MISMATCH,
		"a digest mismatch wins")


func test_an_intact_stream_is_refused_by_the_empty_event_domain() -> void:
	"""Correctly chained records are intact, and only then refused because no event exists."""
	var history: PackedByteArray = PackedByteArray()
	history.resize(48)
	assert_equal(_decode(_section_with(history, _chain(history))).code,
		Section.REFUSE_EVENT_DOMAIN, "an intact stream hits DEC-055 Q8's empty domain")


func test_streaming_crosses_the_chunk_boundary() -> void:
	"""More records than one 65536-byte chunk holds still verify the digest exactly."""
	var history: PackedByteArray = PackedByteArray()
	history.resize((Section.CHUNK_RECORDS + 7) * Chronicle.RECORD_BYTES)
	var digest: PackedByteArray = _chain(history)
	assert_equal(_decode(_section_with(history, digest)).code, Section.REFUSE_EVENT_DOMAIN,
		"the multi-chunk stream verified, then hit the domain")
	digest[31] = digest[31] ^ 1
	assert_equal(_decode(_section_with(history, digest)).code, Section.REFUSE_DIGEST_MISMATCH,
		"one flipped digest bit is still found across chunks")


func test_a_negative_tick_maps_to_its_section_code() -> void:
	"""The owner's record codes surface as SAVE_S13 codes, the first bad record winning."""
	assert_equal(Section.section_code_for(Chronicle.REFUSE_NEGATIVE_TICK),
		Section.REFUSE_NEGATIVE_TICK, "negative tick maps")
	assert_equal(Section.section_code_for(&"SOMETHING_ELSE"), Section.REFUSE_RECORD_REFUSED,
		"an unmapped owner code is RECORD_REFUSED")
	var history: PackedByteArray = PackedByteArray()
	history.resize(24)
	history.encode_s64(Chronicle.OFFSET_TICK, -5)
	assert_equal(_decode(_section_with(history, _chain(history))).code,
		Section.REFUSE_NEGATIVE_TICK, "the tick rule runs before the event domain")


func test_encode_refuses_a_history_that_does_not_match_its_record() -> void:
	"""The encoder applies the decoder's verdict, so it can never write a refused section."""
	var record: Section.Record = Section.Record.new()
	var out: Section.EncodeResult = Section.EncodeResult.new()
	assert_false(Section.encode_section(record, PackedByteArray([1]), out), "1 byte for 0 records")
	assert_equal(out.refusal, Section.REFUSE_HISTORY_LENGTH, "history length refusal")
	assert_true(out.bytes.is_empty(), "no bytes on refusal")
	record.record_count = 1
	record.rolling_digest = _chain(PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]))
	var history: PackedByteArray = PackedByteArray()
	history.resize(24)
	assert_false(Section.encode_section(record, history, out), "an intact out-of-domain record")
	assert_equal(out.refusal, Section.REFUSE_EVENT_DOMAIN, "encode refuses the empty domain")


func test_apply_refusals_leave_the_owner_byte_identical() -> void:
	"""A null owner, a bad Record and an owner-refused count all change nothing."""
	var chronicle: Chronicle = Chronicle.new()
	var before: PackedByteArray = _owner_image(chronicle)
	assert_equal(Section.apply(Section.Record.new(), null).code, Section.REFUSE_NULL_OWNER,
		"a null owner refuses")
	assert_equal(Section.apply(null, chronicle).code, Section.REFUSE_RECORD_NULL,
		"a null Record refuses")
	var short: Section.Record = Section.Record.new()
	short.rolling_digest = PackedByteArray([0])
	assert_equal(Section.apply(short, chronicle).code, Section.REFUSE_DIGEST_LENGTH,
		"a short digest refuses")
	var nonempty: Section.Record = Section.Record.new()
	nonempty.record_count = 3
	nonempty.rolling_digest = _chain(PackedByteArray())
	nonempty.rolling_digest[0] = 1
	assert_equal(Section.apply(nonempty, chronicle).code, Section.REFUSE_OWNER_REFUSED,
		"the owner refuses records under an empty domain")
	assert_equal(_owner_image(chronicle), before, "every refusal left the owner unchanged")


func test_header_and_descriptor_cross_checks() -> void:
	"""Offset 208 and the descriptor's id, schema, row count and length must all agree."""
	var record: Section.Record = Section.Record.new()
	var header: SaveHeader.Header = SaveHeader.Header.new()
	assert_true(Section.header_count_refusal(header, record).is_ok(), "0 == 0")
	header.chronicle_record_count = 1
	assert_equal(Section.header_count_refusal(header, record).code, Section.REFUSE_HEADER_COUNT,
		"a header count disagreement refuses")
	var descriptor: SaveHeader.Descriptor = SaveHeader.Descriptor.new()
	descriptor.section_id = 13
	descriptor.schema_version = 1
	descriptor.byte_length = 40
	assert_true(Section.descriptor_refusal(descriptor, record).is_ok(), "the empty descriptor")
	descriptor.byte_length = 64
	assert_equal(Section.descriptor_refusal(descriptor, record).code, Section.REFUSE_LENGTH,
		"a wrong byte length refuses")
	descriptor.byte_length = 40
	descriptor.row_count = 2
	assert_equal(Section.descriptor_refusal(descriptor, record).code, Section.REFUSE_ROW_COUNT,
		"a wrong row count refuses")
	descriptor.row_count = 0
	descriptor.schema_version = 2
	assert_equal(Section.descriptor_refusal(descriptor, record).code, Section.REFUSE_SECTION_SCHEMA,
		"a wrong schema refuses")
	descriptor.schema_version = 1
	descriptor.section_id = 12
	assert_equal(Section.descriptor_refusal(descriptor, record).code, Section.REFUSE_SECTION_ID,
		"a wrong section refuses")


func test_canonical_adapter_supplies_exactly_the_two_declared_fields() -> void:
	"""`_count` and `_rolling_digest` are supplied; any other key refuses by name."""
	var adapter: Section.Adapter = Section.Adapter.new(Section.Record.new())
	var values: Digest.FieldValues = Digest.FieldValues.new()
	assert_true(adapter.canonical_field_values(&"_count", values), "the count is supplied")
	values = Digest.FieldValues.new()
	assert_true(adapter.canonical_field_values(&"_rolling_digest", values), "the digest is supplied")
	values = Digest.FieldValues.new()
	assert_false(adapter.canonical_field_values(&"_records", values), "history is never a field")
