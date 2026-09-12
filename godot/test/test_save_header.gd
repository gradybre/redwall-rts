extends "res://test/framework/test_case.gd"
## ARCH-SAVE-002's fixed 256-byte header, its 64-byte section descriptors and CRC-32/ISO-HDLC.
##
## The header is where a corrupt or foreign file is supposed to be caught, so nearly every test
## here corrupts one field and asserts the named refusal. The offsets are asserted as literals
## against the architecture table rather than against the module's own constants, because a test
## that reads its expectation out of the code under test proves only that the code is
## self-consistent.

const SaveCodec := preload("res://scripts/core/save_codec.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const CatalogIdsScript := preload("res://scripts/core/catalog_ids.gd")

const SECTION_BODY_BYTES: int = 8


func _digest(fill: int) -> PackedByteArray:
	"""A distinguishable 32-byte stand-in digest."""
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(SaveHeader.DIGEST_BYTES)
	for index: int in SaveHeader.DIGEST_BYTES:
		bytes[index] = (fill + index) & 255
	return bytes


func _descriptors() -> Array[SaveHeader.Descriptor]:
	"""Fifteen valid descriptors, section N at body_offset + (N-1)*8, each eight bytes long."""
	var table: Array[SaveHeader.Descriptor] = []
	for index: int in SaveHeader.SECTION_COUNT:
		var descriptor: SaveHeader.Descriptor = SaveHeader.Descriptor.new()
		descriptor.section_id = index + 1
		descriptor.schema_version = 1
		descriptor.offset = SaveHeader.body_offset() + index * SECTION_BODY_BYTES
		descriptor.byte_length = SECTION_BODY_BYTES
		descriptor.row_count = index
		descriptor.crc32 = 0
		descriptor.flags = 0
		table.append(descriptor)
	return table


func _header(total_bytes: int) -> SaveHeader.Header:
	"""A structurally valid header with placeholder digests and the given declared file length."""
	var header: SaveHeader.Header = SaveHeader.Header.new()
	header.total_file_bytes = total_bytes
	header.completed_tick = 13500
	header.chronicle_record_count = 3
	header.replay_sequence = 41
	header.rules_hash = _digest(1)
	header.catalog_hash = _digest(2)
	header.map_hash = _digest(3)
	header.lookup_hash = _digest(4)
	header.engine_hash = _digest(5)
	header.body_digest = _digest(6)
	return header


func _file_bytes() -> int:
	"""Length of the whole assembled fixture file: header, table and fifteen eight-byte bodies."""
	return SaveHeader.body_offset() + SaveHeader.SECTION_COUNT * SECTION_BODY_BYTES


func _assemble() -> PackedByteArray:
	"""Build a complete fixture file with a correct section table and a correct body digest."""
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(_file_bytes())
	var table: Array[SaveHeader.Descriptor] = _descriptors()
	for index: int in SaveHeader.SECTION_COUNT:
		var descriptor: SaveHeader.Descriptor = table[index]
		SaveHeader.encode_descriptor_into(descriptor, bytes,
			SaveHeader.SECTION_TABLE_OFFSET + index * SaveHeader.SECTION_DESCRIPTOR_BYTES)
		for byte: int in SECTION_BODY_BYTES:
			bytes[descriptor.offset + byte] = (index * 7 + byte) & 255
	var header: SaveHeader.Header = _header(_file_bytes())
	header.body_digest = SaveHeader.compute_body_digest(bytes)
	SaveHeader.encode_header_into(header, bytes)
	return bytes


# --- CRC-32/ISO-HDLC ------------------------------------------------------------------------------

func test_crc32_matches_the_stated_check_vector() -> void:
	"""systems_architecture.md:745 pins ASCII `123456789` to 3421780262. A wrong table fails here."""
	assert_equal(SaveHeader.crc32_of("123456789".to_ascii_buffer()), 3421780262,
		"the ISO-HDLC check vector")
	assert_equal(SaveHeader.CRC32_CHECK_VALUE, 3421780262, "and the transcribed constant agrees")
	assert_equal(SaveHeader.CRC32_REVERSED_POLYNOMIAL, 3988292384, "reversed polynomial")
	assert_equal(SaveHeader.CRC32_INITIAL_REGISTER, 4294967295, "initial register")
	assert_equal(SaveHeader.CRC32_FINAL_XOR, 4294967295, "final XOR")


func test_crc32_of_nothing_is_zero_and_of_one_byte_is_known() -> void:
	"""Two more independent vectors, so passing the check string alone cannot carry the test."""
	assert_equal(SaveHeader.crc32_of(PackedByteArray()), 0, "the empty message")
	assert_equal(SaveHeader.crc32_of(PackedByteArray([0])), 3523407757, "a single zero byte")
	assert_equal(SaveHeader.crc32_of("a".to_ascii_buffer()), 3904355907, "ASCII 'a'")
	assert_true(SaveCodec.fits_u32(SaveHeader.crc32_of("Redwall".to_ascii_buffer())),
		"a CRC is always a u32")


func test_crc32_streams_incrementally_to_the_same_value() -> void:
	"""ARCH-SAVE-003 streams in 65536-byte chunks, so the register must be resumable."""
	var whole: PackedByteArray = "123456789".to_ascii_buffer()
	var register: int = SaveHeader.crc32_update(SaveHeader.CRC32_INITIAL_REGISTER,
		whole.slice(0, 4))
	register = SaveHeader.crc32_update(register, whole.slice(4))
	assert_equal(register ^ SaveHeader.CRC32_FINAL_XOR, SaveHeader.crc32_of(whole),
		"two chunks give the same CRC as one")


func test_crc32_detects_a_single_flipped_bit() -> void:
	"""The whole point of the per-section CRC is localising corruption."""
	var clean: PackedByteArray = "Redwall Abbey".to_ascii_buffer()
	for position: int in clean.size():
		var dirty: PackedByteArray = clean.duplicate()
		dirty[position] = dirty[position] ^ 1
		assert_true(SaveHeader.crc32_of(dirty) != SaveHeader.crc32_of(clean),
			"a flipped bit at %d changes the CRC" % position)


# --- the fixed layout -------------------------------------------------------------------------

func test_every_header_offset_matches_the_architecture_table() -> void:
	"""Transcribed from systems_architecture.md:716-731, as literals, not from the module."""
	assert_equal(SaveHeader.OFFSET_MAGIC, 0, "magic")
	assert_equal(SaveHeader.OFFSET_FORMAT_VERSION, 8, "format version")
	assert_equal(SaveHeader.OFFSET_HEADER_BYTES, 12, "header bytes")
	assert_equal(SaveHeader.OFFSET_ENDIAN_SENTINEL, 16, "endian sentinel")
	assert_equal(SaveHeader.OFFSET_SECTION_COUNT, 20, "section count")
	assert_equal(SaveHeader.OFFSET_TOTAL_FILE_BYTES, 24, "total file bytes")
	assert_equal(SaveHeader.OFFSET_COMPLETED_TICK, 32, "completed tick")
	assert_equal(SaveHeader.OFFSET_RULES_HASH, 40, "rules hash")
	assert_equal(SaveHeader.OFFSET_CATALOG_HASH, 72, "catalog hash")
	assert_equal(SaveHeader.OFFSET_MAP_HASH, 104, "map hash")
	assert_equal(SaveHeader.OFFSET_LOOKUP_HASH, 136, "integer lookup-table hash")
	assert_equal(SaveHeader.OFFSET_ENGINE_HASH, 168, "engine build hash")
	assert_equal(SaveHeader.OFFSET_SECTION_TABLE_OFFSET, 200, "section table offset")
	assert_equal(SaveHeader.OFFSET_CHRONICLE_RECORD_COUNT, 208, "chronicle record count")
	assert_equal(SaveHeader.OFFSET_REPLAY_SEQUENCE, 216, "replay sequence")
	assert_equal(SaveHeader.OFFSET_BODY_DIGEST, 224, "body digest")


func test_the_header_and_descriptor_sizes_are_exactly_consumed() -> void:
	"""224 + 32 = 256 leaves no slack, and the descriptor's eight fields sum to 64."""
	assert_equal(SaveHeader.OFFSET_BODY_DIGEST + SaveHeader.DIGEST_BYTES, 256,
		"the last header field ends exactly at 256")
	assert_equal(SaveHeader.HEADER_BYTES, 256, "header bytes")
	assert_equal(SaveHeader.SECTION_TABLE_OFFSET, 256, "the table starts where the header ends")
	assert_equal(SaveHeader.DESC_OFFSET_RESERVED_ZERO + SaveHeader.DESC_RESERVED_ZERO_BYTES, 64,
		"the descriptor's reserved tail ends exactly at 64")
	assert_equal(SaveHeader.SECTION_DESCRIPTOR_BYTES, 64, "descriptor stride")
	assert_equal(SaveHeader.SECTION_COUNT, 15, "ARCH-SAVE-002 assigns fifteen section IDs")
	assert_equal(SaveHeader.body_offset(), 256 + 64 * 15, "the body starts at 1216")


func test_the_magic_and_endian_sentinel_land_as_stated_bytes() -> void:
	"""16909060 is 0x01020304; little-endian it must read 04 03 02 01 on disk."""
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(SaveHeader.HEADER_BYTES)
	assert_true(SaveHeader.encode_header_into(_header(SaveHeader.body_offset()), bytes).is_ok(),
		"encoded")
	assert_equal(bytes.slice(0, 8).get_string_from_ascii(), "RWLSET01", "the magic is ASCII")
	assert_equal(SaveHeader.ENDIAN_SENTINEL, 16909060, "the sentinel value")
	assert_equal(bytes[16], 4, "sentinel byte 0")
	assert_equal(bytes[17], 3, "sentinel byte 1")
	assert_equal(bytes[18], 2, "sentinel byte 2")
	assert_equal(bytes[19], 1, "sentinel byte 3")


# --- header round trip -------------------------------------------------------------------------

func test_the_header_round_trips_every_field() -> void:
	"""Encode then decode must return every field unchanged, including the six digests."""
	var header: SaveHeader.Header = _header(_file_bytes())
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(SaveHeader.HEADER_BYTES)
	assert_true(SaveHeader.encode_header_into(header, bytes).is_ok(), "encoded")
	var back: SaveHeader.Header = SaveHeader.Header.new()
	assert_true(SaveHeader.decode_header_into(bytes, back).is_ok(), "decoded")
	assert_equal(back.format_version, 1, "format version")
	assert_equal(back.header_bytes, 256, "header bytes")
	assert_equal(back.endian_sentinel, 16909060, "endian sentinel")
	assert_equal(back.section_count, 15, "section count")
	assert_equal(back.total_file_bytes, _file_bytes(), "total file bytes")
	assert_equal(back.completed_tick, 13500, "completed tick")
	assert_equal(back.chronicle_record_count, 3, "chronicle record count")
	assert_equal(back.replay_sequence, 41, "replay sequence")
	assert_equal(back.rules_hash, _digest(1), "rules hash")
	assert_equal(back.catalog_hash, _digest(2), "catalog hash")
	assert_equal(back.map_hash, _digest(3), "map hash")
	assert_equal(back.lookup_hash, _digest(4), "lookup hash")
	assert_equal(back.engine_hash, _digest(5), "engine hash")
	assert_equal(back.body_digest, _digest(6), "body digest")


func test_the_header_encoding_is_byte_identical_across_runs() -> void:
	"""Canonical means byte-identical for equal input; nothing here may vary between encodes."""
	var first: PackedByteArray = PackedByteArray()
	var second: PackedByteArray = PackedByteArray()
	first.resize(SaveHeader.HEADER_BYTES)
	second.resize(SaveHeader.HEADER_BYTES)
	assert_true(SaveHeader.encode_header_into(_header(_file_bytes()), first).is_ok(), "first")
	assert_true(SaveHeader.encode_header_into(_header(_file_bytes()), second).is_ok(), "second")
	assert_equal(first, second, "two encodes of equal input agree byte for byte")
	assert_equal(first.size(), 256, "and occupy exactly the header")


func test_a_maximum_tick_and_a_zero_tick_both_survive() -> void:
	"""The completed tick is i64 and only its negative half is refused."""
	for tick: int in [0, 1, 13500, 18000, SaveCodec.INT64_MAX]:
		var header: SaveHeader.Header = _header(SaveHeader.body_offset())
		header.completed_tick = tick
		var bytes: PackedByteArray = PackedByteArray()
		bytes.resize(SaveHeader.HEADER_BYTES)
		assert_true(SaveHeader.encode_header_into(header, bytes).is_ok(), "encoded tick %d" % tick)
		var back: SaveHeader.Header = SaveHeader.Header.new()
		assert_true(SaveHeader.decode_header_into(bytes, back).is_ok(), "decoded tick %d" % tick)
		assert_equal(back.completed_tick, tick, "tick %d survives" % tick)


# --- header refusals ----------------------------------------------------------------------------

func test_a_short_buffer_refuses_rather_than_reading_past_its_end() -> void:
	"""255 bytes is one short of the header; a decoder must not reach for the 256th."""
	var back: SaveHeader.Header = SaveHeader.Header.new()
	var short: PackedByteArray = PackedByteArray()
	short.resize(SaveHeader.HEADER_BYTES - 1)
	assert_equal(SaveHeader.decode_header_into(short, back).code, SaveHeader.REFUSE_HEADER_TRUNCATED,
		"255 bytes refuse")
	short.resize(SaveHeader.HEADER_BYTES)
	assert_true(SaveHeader.decode_header_into(short, back).is_ok(), "256 bytes parse")
	var out: PackedByteArray = PackedByteArray()
	out.resize(SaveHeader.HEADER_BYTES - 1)
	assert_equal(SaveHeader.encode_header_into(_header(1216), out).code,
		SaveHeader.REFUSE_HEADER_TRUNCATED, "and encoding into 255 bytes refuses")
	assert_equal(out, _buffer_of(SaveHeader.HEADER_BYTES - 1),
		"a refused encode left the buffer untouched")
	var also_bad: SaveHeader.Header = _header(1216)
	also_bad.map_hash = PackedByteArray()
	assert_equal(SaveHeader.encode_header_into(also_bad, out).code,
		SaveHeader.REFUSE_HEADER_TRUNCATED,
		"a buffer too small to hold the header is reported as truncation before anything else")


func _buffer_of(size: int) -> PackedByteArray:
	"""A zeroed buffer of the given size, for asserting that a refused write changed nothing."""
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(size)
	return bytes


func test_a_corrupted_magic_is_refused() -> void:
	"""ARCH-SAVE-004 checks the magic first, so a foreign file never reaches field parsing."""
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(SaveHeader.HEADER_BYTES)
	assert_true(SaveHeader.encode_header_into(_header(1216), bytes).is_ok(), "encoded")
	assert_true(SaveHeader.magic_refusal(bytes).is_ok(), "a clean magic is accepted")
	for position: int in SaveHeader.MAGIC_BYTES:
		var dirty: PackedByteArray = bytes.duplicate()
		dirty[position] = dirty[position] ^ 1
		assert_equal(SaveHeader.magic_refusal(dirty).code, SaveHeader.REFUSE_MAGIC,
			"a flipped magic byte at %d refuses" % position)
	assert_equal(SaveHeader.magic_refusal(PackedByteArray([82, 87, 76])).code,
		SaveHeader.REFUSE_HEADER_TRUNCATED, "a three-byte file cannot even hold the magic")


func test_a_future_format_version_is_refused_separately_from_a_wrong_one() -> void:
	"""ARCH-SAVE-005 names "future format versions" specifically; version 0 is a different fault."""
	var header: SaveHeader.Header = _header(SaveHeader.body_offset())
	header.format_version = 2
	assert_equal(SaveHeader.header_refusal(header, SaveHeader.body_offset()).code,
		SaveHeader.REFUSE_FUTURE_FORMAT_VERSION, "version 2 is refused as a future version")
	header.format_version = 0
	assert_equal(SaveHeader.header_refusal(header, SaveHeader.body_offset()).code,
		SaveHeader.REFUSE_FORMAT_VERSION, "version 0 is refused as a wrong version")
	header.format_version = 1
	assert_true(SaveHeader.header_refusal(header, SaveHeader.body_offset()).is_ok(),
		"version 1 is accepted")


func test_a_byte_swapped_endian_sentinel_is_refused() -> void:
	"""A big-endian writer produces 67305985 here; that is exactly what the sentinel is for."""
	var header: SaveHeader.Header = _header(SaveHeader.body_offset())
	header.endian_sentinel = 67305985
	assert_equal(SaveHeader.header_refusal(header, SaveHeader.body_offset()).code,
		SaveHeader.REFUSE_ENDIAN_SENTINEL, "a byte-swapped sentinel refuses")
	header.endian_sentinel = 0
	assert_equal(SaveHeader.header_refusal(header, SaveHeader.body_offset()).code,
		SaveHeader.REFUSE_ENDIAN_SENTINEL, "and so does a zeroed one")


func test_the_fixed_structural_constants_are_refused_when_changed() -> void:
	"""Header bytes, section table offset and section count are all stated values, not hints."""
	var base: int = SaveHeader.body_offset()
	var wrong_size: SaveHeader.Header = _header(base)
	wrong_size.header_bytes = 128
	assert_equal(SaveHeader.header_refusal(wrong_size, base).code, SaveHeader.REFUSE_HEADER_BYTES,
		"a 128-byte header is refused")
	for offset: int in [512, 128, 0]:
		var wrong_table: SaveHeader.Header = _header(base)
		wrong_table.section_table_offset = offset
		assert_equal(SaveHeader.header_refusal(wrong_table, base).code,
			SaveHeader.REFUSE_SECTION_TABLE_OFFSET,
			"a table offset of %d is refused; it is always 256" % offset)
	var wrong_count: SaveHeader.Header = _header(base)
	wrong_count.section_count = 14
	assert_equal(SaveHeader.header_refusal(wrong_count, base).code,
		SaveHeader.REFUSE_SECTION_COUNT, "fourteen sections are refused")


func test_a_negative_completed_tick_is_refused() -> void:
	"""Ticks count forward from zero; a negative one would invert every calendar computation."""
	var header: SaveHeader.Header = _header(SaveHeader.body_offset())
	header.completed_tick = -1
	assert_equal(SaveHeader.header_refusal(header, SaveHeader.body_offset()).code,
		SaveHeader.REFUSE_NEGATIVE_TICK, "-1 is refused")
	header.completed_tick = SaveCodec.INT64_MIN
	assert_equal(SaveHeader.header_refusal(header, SaveHeader.body_offset()).code,
		SaveHeader.REFUSE_NEGATIVE_TICK, "INT64_MIN is refused")
	header.completed_tick = 0
	assert_true(SaveHeader.header_refusal(header, SaveHeader.body_offset()).is_ok(),
		"tick zero is a legal boundary")


func test_a_declared_file_length_that_is_not_the_real_one_is_refused() -> void:
	"""ARCH-SAVE-004 requires the exact file length; off by one in either direction refuses."""
	var base: int = SaveHeader.body_offset()
	var header: SaveHeader.Header = _header(base)
	assert_true(SaveHeader.header_refusal(header, base).is_ok(), "an exact length is accepted")
	assert_equal(SaveHeader.header_refusal(header, base + 1).code, SaveHeader.REFUSE_FILE_LENGTH,
		"one byte of trailing garbage refuses")
	assert_equal(SaveHeader.header_refusal(header, base - 1).code, SaveHeader.REFUSE_FILE_LENGTH,
		"one byte of truncation refuses")
	var tiny: SaveHeader.Header = _header(SaveHeader.HEADER_BYTES)
	assert_equal(SaveHeader.header_refusal(tiny, SaveHeader.HEADER_BYTES).code,
		SaveHeader.REFUSE_FILE_LENGTH, "a file with no room for the section table refuses")


func test_an_unrepresentable_u64_header_field_is_refused_not_read_as_negative() -> void:
	"""A hostile total-file-bytes of 0xffffffffffffffff must not reach a caller as -1."""
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(SaveHeader.HEADER_BYTES)
	assert_true(SaveHeader.encode_header_into(_header(1216), bytes).is_ok(), "encoded")
	for index: int in 8:
		bytes[SaveHeader.OFFSET_TOTAL_FILE_BYTES + index] = 255
	var back: SaveHeader.Header = SaveHeader.Header.new()
	assert_equal(SaveHeader.decode_header_into(bytes, back).code,
		SaveCodec.REFUSE_UNREPRESENTABLE_U64, "the decode refuses")
	assert_equal(back.total_file_bytes, 0, "and publishes nothing into the caller's header")
	assert_equal(back.completed_tick, 0, "no field of a refused header is published")


func test_a_digest_of_the_wrong_length_is_refused_on_encode() -> void:
	"""Every one of the six digests is 32 bytes; 31 and 33 are both faults."""
	for short: bool in [true, false]:
		var header: SaveHeader.Header = _header(1216)
		var wrong: PackedByteArray = _digest(9)
		wrong.resize(SaveHeader.DIGEST_BYTES - 1 if short else SaveHeader.DIGEST_BYTES + 1)
		header.map_hash = wrong
		var bytes: PackedByteArray = PackedByteArray()
		bytes.resize(SaveHeader.HEADER_BYTES)
		assert_equal(SaveHeader.encode_header_into(header, bytes).code,
			SaveHeader.REFUSE_DIGEST_LENGTH, "a %d-byte digest refuses" % wrong.size())
		assert_equal(bytes, _buffer_of(SaveHeader.HEADER_BYTES),
			"and the refused encode wrote nothing at all")


# --- the catalog hash at offset 72 ------------------------------------------------------------

func test_the_catalog_hash_offset_agrees_with_the_catalog_module() -> void:
	"""One offset, named in two files; they must not drift."""
	assert_equal(SaveHeader.OFFSET_CATALOG_HASH,
		CatalogIdsScript.SAVE_HEADER_CATALOG_HASH_OFFSET, "offset 72 in both modules")
	assert_equal(SaveHeader.OFFSET_CATALOG_HASH, 72, "and it is 72")
	assert_equal(SaveHeader.DIGEST_BYTES, CatalogIdsScript.DIGEST_BYTES, "32 bytes in both")


func test_the_header_carries_the_catalog_modules_digest_byte_for_byte() -> void:
	"""The offset-72 bytes must BE catalog_ids.gd's digest, not a second SHA-256 of something."""
	var built: CatalogIdsScript.BuildResult = CatalogIdsScript.build()
	assert_true(built.ok, "this build compiles its own catalog")
	var header: SaveHeader.Header = _header(1216)
	header.catalog_hash = built.artifact.digest
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(SaveHeader.HEADER_BYTES)
	assert_true(SaveHeader.encode_header_into(header, bytes).is_ok(), "encoded")
	assert_equal(bytes.slice(72, 104), built.artifact.digest,
		"bytes 72..103 are exactly the catalog digest")
	assert_equal(built.artifact.digest, CatalogIdsScript.digest_of(built.artifact.bytes),
		"and that digest is digest_of() over the canonical artifact bytes")
	assert_true(SaveHeader.catalog_hash_refusal(header).is_ok(), "so the load check accepts it")


func test_a_foreign_catalog_hash_is_refused() -> void:
	"""A save written by a build with different catalog IDs must not load into this one."""
	var built: CatalogIdsScript.BuildResult = CatalogIdsScript.build()
	assert_true(built.ok, "this build compiles its own catalog")
	var header: SaveHeader.Header = _header(1216)
	header.catalog_hash = built.artifact.digest.duplicate()
	header.catalog_hash[0] = header.catalog_hash[0] ^ 1
	assert_equal(SaveHeader.catalog_hash_refusal(header).code,
		SaveHeader.REFUSE_CATALOG_HASH_MISMATCH, "one flipped bit refuses")
	header.catalog_hash = PackedByteArray()
	assert_equal(SaveHeader.catalog_hash_refusal(header).code, SaveHeader.REFUSE_DIGEST_LENGTH,
		"an empty catalog hash refuses on length, not as a match")


# --- section descriptors -------------------------------------------------------------------------

func test_a_descriptor_round_trips_every_field_at_its_width_boundary() -> void:
	"""u32 and u64 fields at their maxima, so a narrowed field shows up immediately."""
	var descriptor: SaveHeader.Descriptor = SaveHeader.Descriptor.new()
	descriptor.section_id = 15
	descriptor.schema_version = SaveCodec.UINT32_MAX
	descriptor.offset = SaveCodec.UINT64_REPRESENTABLE_MAX
	descriptor.byte_length = 0
	descriptor.row_count = 4294967296
	descriptor.crc32 = SaveCodec.UINT32_MAX
	descriptor.flags = 2147483648
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(SaveHeader.SECTION_DESCRIPTOR_BYTES)
	assert_true(SaveHeader.encode_descriptor_into(descriptor, bytes, 0).is_ok(), "encoded")
	var back: SaveHeader.Descriptor = SaveHeader.Descriptor.new()
	assert_true(SaveHeader.decode_descriptor_into(bytes, 0, back).is_ok(), "decoded")
	assert_equal(back.section_id, 15, "section id")
	assert_equal(back.schema_version, SaveCodec.UINT32_MAX, "schema version at the u32 maximum")
	assert_equal(back.offset, SaveCodec.UINT64_REPRESENTABLE_MAX, "offset at the u64 maximum")
	assert_equal(back.row_count, 4294967296, "a row count above the u32 range")
	assert_equal(back.crc32, SaveCodec.UINT32_MAX, "crc at the u32 maximum")
	assert_equal(back.flags, 2147483648, "flags with the high bit set stay unsigned")


func test_a_descriptor_zeroes_its_reserved_tail_and_refuses_a_dirty_one() -> void:
	"""ARCH-SAVE-005 rejects nonzero reserved padding; all 24 positions are checked."""
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(SaveHeader.SECTION_DESCRIPTOR_BYTES)
	for index: int in SaveHeader.SECTION_DESCRIPTOR_BYTES:
		bytes[index] = 255
	assert_true(SaveHeader.encode_descriptor_into(_descriptors()[0], bytes, 0).is_ok(), "encoded")
	assert_equal(SaveCodec.zero_padding_refusal(bytes, 40, 24), SaveCodec.REFUSE_NONE,
		"the encoder zeroed the reserved tail over a dirty buffer")
	for position: int in SaveHeader.DESC_RESERVED_ZERO_BYTES:
		var dirty: PackedByteArray = bytes.duplicate()
		dirty[SaveHeader.DESC_OFFSET_RESERVED_ZERO + position] = 1
		var back: SaveHeader.Descriptor = SaveHeader.Descriptor.new()
		assert_equal(SaveHeader.decode_descriptor_into(dirty, 0, back).code,
			SaveHeader.REFUSE_RESERVED_NONZERO, "reserved byte %d refuses" % position)


func test_descriptors_sit_on_a_64_byte_stride_without_interfering() -> void:
	"""Two adjacent descriptors must be independent, or the whole table is one field out."""
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(SaveHeader.SECTION_DESCRIPTOR_BYTES * 2)
	var table: Array[SaveHeader.Descriptor] = _descriptors()
	assert_true(SaveHeader.encode_descriptor_into(table[0], bytes, 0).is_ok(), "first encoded")
	assert_true(SaveHeader.encode_descriptor_into(table[1], bytes, 64).is_ok(), "second encoded")
	var back: SaveHeader.Descriptor = SaveHeader.Descriptor.new()
	assert_true(SaveHeader.decode_descriptor_into(bytes, 0, back).is_ok(), "first decoded")
	assert_equal(back.section_id, 1, "the first descriptor is section 1")
	assert_true(SaveHeader.decode_descriptor_into(bytes, 64, back).is_ok(), "second decoded")
	assert_equal(back.section_id, 2, "the second descriptor is section 2")
	assert_equal(back.row_count, 1, "and carries its own row count")


func test_a_descriptor_outside_its_buffer_is_refused() -> void:
	"""The last legal descriptor offset is size-64; one past it must refuse on both sides."""
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(SaveHeader.SECTION_DESCRIPTOR_BYTES * 2)
	var back: SaveHeader.Descriptor = SaveHeader.Descriptor.new()
	assert_true(SaveHeader.decode_descriptor_into(bytes, 64, back).is_ok(), "offset 64 of 128 fits")
	assert_equal(SaveHeader.decode_descriptor_into(bytes, 65, back).code,
		SaveHeader.REFUSE_HEADER_TRUNCATED, "offset 65 of 128 does not")
	assert_equal(SaveHeader.decode_descriptor_into(bytes, -1, back).code,
		SaveHeader.REFUSE_HEADER_TRUNCATED, "a negative offset refuses")
	assert_equal(SaveHeader.encode_descriptor_into(_descriptors()[0], bytes, 65).code,
		SaveHeader.REFUSE_HEADER_TRUNCATED, "and so does encoding there")


func test_a_negative_descriptor_word_is_refused_on_encode() -> void:
	"""u64 descriptor fields cannot be negative and u32 fields cannot exceed 2^32-1."""
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(SaveHeader.SECTION_DESCRIPTOR_BYTES)
	var descriptor: SaveHeader.Descriptor = _descriptors()[0]
	descriptor.byte_length = -1
	assert_equal(SaveHeader.encode_descriptor_into(descriptor, bytes, 0).code,
		SaveHeader.REFUSE_VALUE_RANGE, "a negative byte length refuses")
	descriptor.byte_length = 8
	descriptor.crc32 = SaveCodec.UINT32_MAX + 1
	assert_equal(SaveHeader.encode_descriptor_into(descriptor, bytes, 0).code,
		SaveHeader.REFUSE_VALUE_RANGE, "a crc above the u32 range refuses")
	assert_equal(bytes, _buffer_of(SaveHeader.SECTION_DESCRIPTOR_BYTES),
		"and neither refusal wrote a byte")


func test_the_section_table_parses_all_fifteen_descriptors() -> void:
	"""The table lives at 256 and is fifteen entries of 64 bytes, ending at 1216."""
	var bytes: PackedByteArray = _assemble()
	var table: Array[SaveHeader.Descriptor] = []
	assert_true(SaveHeader.decode_section_table(bytes, table).is_ok(), "parsed")
	assert_equal(table.size(), 15, "fifteen descriptors")
	for index: int in 15:
		assert_equal(table[index].section_id, index + 1, "descriptor %d is section %d"
			% [index, index + 1])


func test_a_section_table_that_runs_off_the_end_is_refused_and_publishes_nothing() -> void:
	"""Allocate before consume: a caller must never receive a half-parsed table."""
	var bytes: PackedByteArray = _assemble().slice(0, SaveHeader.body_offset() - 1)
	var table: Array[SaveHeader.Descriptor] = []
	assert_equal(SaveHeader.decode_section_table(bytes, table).code,
		SaveHeader.REFUSE_HEADER_TRUNCATED, "one byte short of the table refuses")
	assert_equal(table.size(), 0, "and nothing is published")


# --- section table validation --------------------------------------------------------------------

func test_a_correct_section_table_is_accepted() -> void:
	"""The positive case, so the refusal tests below are not all vacuously passing."""
	var header: SaveHeader.Header = _header(_file_bytes())
	assert_true(SaveHeader.section_table_refusal(_descriptors(), header).is_ok(),
		"fifteen ordered, non-overlapping, in-bounds sections are accepted")
	assert_true(SaveHeader.section_identity_refusal(_descriptors()).is_ok(),
		"and their identities are accepted")


func test_a_duplicate_or_out_of_range_section_id_is_refused() -> void:
	"""ARCH-SAVE-004 requires fifteen UNIQUE ids in the assigned domain."""
	var header: SaveHeader.Header = _header(_file_bytes())
	var duplicated: Array[SaveHeader.Descriptor] = _descriptors()
	duplicated[14].section_id = 1
	assert_equal(SaveHeader.section_table_refusal(duplicated, header).code,
		SaveHeader.REFUSE_SECTION_ID_DUPLICATE, "a repeated id refuses")
	for bad: int in [0, 16, -1]:
		var ranged: Array[SaveHeader.Descriptor] = _descriptors()
		ranged[7].section_id = bad
		assert_equal(SaveHeader.section_table_refusal(ranged, header).code,
			SaveHeader.REFUSE_SECTION_ID_RANGE, "section id %d refuses" % bad)


func test_a_missing_section_id_is_refused() -> void:
	"""The absence check, exercised where it is reachable: fewer than fifteen descriptors."""
	var partial: Array[SaveHeader.Descriptor] = _descriptors()
	partial.remove_at(10)
	assert_equal(SaveHeader.section_identity_refusal(partial).code,
		SaveHeader.REFUSE_SECTION_ID_MISSING, "a table without section 11 refuses")
	var header: SaveHeader.Header = _header(_file_bytes())
	assert_equal(SaveHeader.section_table_refusal(partial, header).code,
		SaveHeader.REFUSE_SECTION_COUNT, "and the table path refuses on the count first")


func test_a_section_range_outside_the_file_is_refused() -> void:
	"""Before the body, or past the declared end; both are ARCH-SAVE-004 range faults."""
	var header: SaveHeader.Header = _header(_file_bytes())
	var early: Array[SaveHeader.Descriptor] = _descriptors()
	early[3].offset = SaveHeader.body_offset() - 1
	assert_equal(SaveHeader.section_table_refusal(early, header).code,
		SaveHeader.REFUSE_SECTION_BEFORE_BODY, "a section starting inside the table refuses")
	var late: Array[SaveHeader.Descriptor] = _descriptors()
	late[3].byte_length = _file_bytes()
	assert_equal(SaveHeader.section_table_refusal(late, header).code,
		SaveHeader.REFUSE_SECTION_PAST_END, "a section running past the end refuses")
	var edge: Array[SaveHeader.Descriptor] = _descriptors()
	edge[14].byte_length = SECTION_BODY_BYTES + 1
	assert_equal(SaveHeader.section_table_refusal(edge, header).code,
		SaveHeader.REFUSE_SECTION_PAST_END, "and one byte past the end refuses too")


func test_a_section_range_that_would_overflow_is_refused_before_it_wraps() -> void:
	"""offset + byte_length must be computed with an overflow check, not with a wrap."""
	var header: SaveHeader.Header = _header(_file_bytes())
	var overflow: Array[SaveHeader.Descriptor] = _descriptors()
	overflow[2].offset = SaveCodec.INT64_MAX
	overflow[2].byte_length = 1
	assert_equal(SaveHeader.section_table_refusal(overflow, header).code,
		SaveHeader.REFUSE_SECTION_RANGE_OVERFLOW, "INT64_MAX + 1 refuses as an overflow")
	var negative: Array[SaveHeader.Descriptor] = _descriptors()
	negative[2].offset = -1
	assert_equal(SaveHeader.section_table_refusal(negative, header).code,
		SaveHeader.REFUSE_SECTION_NEGATIVE, "a negative offset refuses")


func test_overlapping_sections_are_refused_in_offset_order_not_listing_order() -> void:
	"""Sections are listed by id; the overlap check must sort, or a reordered file slips through."""
	var header: SaveHeader.Header = _header(_file_bytes())
	var overlap: Array[SaveHeader.Descriptor] = _descriptors()
	overlap[9].offset = overlap[2].offset + 1
	overlap[9].byte_length = 2
	assert_equal(SaveHeader.section_table_refusal(overlap, header).code,
		SaveHeader.REFUSE_SECTION_OVERLAP, "section 10 inside section 3 refuses")
	var touching: Array[SaveHeader.Descriptor] = _descriptors()
	assert_true(SaveHeader.section_table_refusal(touching, header).is_ok(),
		"exactly abutting sections do not overlap")


func test_an_overlap_of_exactly_one_byte_is_refused() -> void:
	"""The overlap bound is exact. Added after a mutation sweep: relaxing it by one survived.

	Section 4 is moved to end one byte inside section 5, which is the smallest overlap there is.
	"""
	var header: SaveHeader.Header = _header(_file_bytes())
	var touching: Array[SaveHeader.Descriptor] = _descriptors()
	assert_true(SaveHeader.section_table_refusal(touching, header).is_ok(),
		"abutting sections are accepted")
	var overlap: Array[SaveHeader.Descriptor] = _descriptors()
	overlap[3].byte_length = SECTION_BODY_BYTES + 1
	assert_equal(SaveHeader.section_table_refusal(overlap, header).code,
		SaveHeader.REFUSE_SECTION_OVERLAP, "one byte of overlap refuses")


func test_sections_laid_out_in_descending_offset_order_are_accepted() -> void:
	"""The table is listed by id; nothing requires ids to ascend with offsets.

	Added after a mutation sweep: dropping the sort in the overlap check survived, because every
	other fixture happened to list its sections in ascending offset order, where an unsorted scan
	gives the same answer. A descending layout is valid and an unsorted scan calls it an overlap.
	"""
	var header: SaveHeader.Header = _header(_file_bytes())
	var reversed: Array[SaveHeader.Descriptor] = _descriptors()
	for index: int in SaveHeader.SECTION_COUNT:
		reversed[index].offset = SaveHeader.body_offset() \
			+ (SaveHeader.SECTION_COUNT - 1 - index) * SECTION_BODY_BYTES
	assert_equal(reversed[0].offset, _file_bytes() - SECTION_BODY_BYTES,
		"section 1 now sits last in the file")
	assert_equal(reversed[14].offset, SaveHeader.body_offset(), "and section 15 sits first")
	assert_true(SaveHeader.section_table_refusal(reversed, header).is_ok(),
		"a descending layout has no overlap and is accepted")


func test_empty_sections_and_gaps_are_permitted() -> void:
	"""BLOCKER H4: ARCH-SAVE-004 requires nonoverlapping, not contiguous. Pinned so it is visible."""
	var header: SaveHeader.Header = _header(_file_bytes())
	var sparse: Array[SaveHeader.Descriptor] = _descriptors()
	sparse[5].byte_length = 0
	sparse[6].byte_length = 0
	assert_true(SaveHeader.section_table_refusal(sparse, header).is_ok(),
		"two empty sections leave a gap and are accepted")
	var shared: Array[SaveHeader.Descriptor] = _descriptors()
	shared[5].byte_length = 0
	shared[6].byte_length = 0
	shared[6].offset = shared[5].offset
	assert_true(SaveHeader.section_table_refusal(shared, header).is_ok(),
		"two empty sections at the same offset do not overlap either")


# --- the body digest ------------------------------------------------------------------------------

func test_the_body_digest_covers_the_table_and_every_section_byte() -> void:
	""""Body digest over table plus section bytes": everything from offset 256 onward."""
	var bytes: PackedByteArray = _assemble()
	var header: SaveHeader.Header = SaveHeader.Header.new()
	assert_true(SaveHeader.decode_header_into(bytes, header).is_ok(), "decoded")
	assert_true(SaveHeader.body_digest_refusal(bytes, header).is_ok(), "a clean file verifies")
	assert_equal(header.body_digest.size(), 32, "the digest is SHA-256")
	for position: int in [SaveHeader.SECTION_TABLE_OFFSET, SaveHeader.body_offset(),
			_file_bytes() - 1]:
		var dirty: PackedByteArray = bytes.duplicate()
		dirty[position] = dirty[position] ^ 1
		assert_equal(SaveHeader.body_digest_refusal(dirty, header).code,
			SaveHeader.REFUSE_BODY_DIGEST_MISMATCH, "a flipped byte at %d refuses" % position)


func test_the_body_digest_deliberately_does_not_cover_the_header() -> void:
	"""Stated design: header fields are protected by state verification, not by this digest.

	ARCH-SAVE-007 makes the same separation explicit for saved-but-unhashed host metadata: the
	body digest and section CRC cover every saved byte, while ARCH-HASH-001's canonical state
	digest covers a different, smaller set. This test pins which of the two lives here.
	"""
	var bytes: PackedByteArray = _assemble()
	var header: SaveHeader.Header = SaveHeader.Header.new()
	assert_true(SaveHeader.decode_header_into(bytes, header).is_ok(), "decoded")
	var before: PackedByteArray = SaveHeader.compute_body_digest(bytes)
	bytes[SaveHeader.OFFSET_COMPLETED_TICK] = bytes[SaveHeader.OFFSET_COMPLETED_TICK] ^ 1
	assert_equal(SaveHeader.compute_body_digest(bytes), before,
		"changing the completed tick does not change the body digest")
	assert_true(SaveHeader.body_digest_refusal(bytes, header).is_ok(),
		"so a changed tick is caught by state verification, not by this CRC/SHA pair")


func test_the_body_digest_refuses_a_file_with_no_body() -> void:
	"""A 255-byte file has no body at all; the digest must refuse, not hash an empty string."""
	var header: SaveHeader.Header = _header(1216)
	var short: PackedByteArray = PackedByteArray()
	short.resize(SaveHeader.HEADER_BYTES - 1)
	assert_equal(SaveHeader.body_digest_refusal(short, header).code,
		SaveHeader.REFUSE_HEADER_TRUNCATED, "a truncated file refuses")
	assert_equal(SaveHeader.compute_body_digest(short), PackedByteArray(),
		"and produces no digest to be compared by accident")
	header.body_digest = PackedByteArray()
	assert_equal(SaveHeader.body_digest_refusal(_assemble(), header).code,
		SaveHeader.REFUSE_DIGEST_LENGTH, "a missing stored digest refuses on length")


# --- whole-file assembly --------------------------------------------------------------------------

func test_a_whole_assembled_file_passes_every_check_in_order() -> void:
	"""ARCH-SAVE-004's parse order, end to end over a real fixture file."""
	var bytes: PackedByteArray = _assemble()
	assert_equal(bytes.size(), _file_bytes(), "the fixture is the size it claims")
	assert_true(SaveHeader.magic_refusal(bytes).is_ok(), "magic")
	var header: SaveHeader.Header = SaveHeader.Header.new()
	assert_true(SaveHeader.decode_header_into(bytes, header).is_ok(), "header parses")
	assert_true(SaveHeader.header_refusal(header, bytes.size()).is_ok(), "header validates")
	var table: Array[SaveHeader.Descriptor] = []
	assert_true(SaveHeader.decode_section_table(bytes, table).is_ok(), "table parses")
	assert_true(SaveHeader.section_table_refusal(table, header).is_ok(), "table validates")
	assert_true(SaveHeader.body_digest_refusal(bytes, header).is_ok(), "body digest verifies")
	for descriptor: SaveHeader.Descriptor in table:
		var body: PackedByteArray = bytes.slice(descriptor.offset,
			descriptor.offset + descriptor.byte_length)
		assert_true(SaveCodec.fits_u32(SaveHeader.crc32_of(body)),
			"section %d has a computable CRC" % descriptor.section_id)


func test_assembling_the_same_file_twice_gives_identical_bytes() -> void:
	"""Canonical output must not depend on anything that varies between runs."""
	assert_equal(_assemble(), _assemble(), "two assemblies agree byte for byte")
	assert_equal(SaveHeader.compute_body_digest(_assemble()),
		SaveHeader.compute_body_digest(_assemble()), "and so do their body digests")


func test_the_header_source_contains_no_float_path() -> void:
	"""ARCH-AUTH-002: the save header must never introduce a float."""
	var source: String = FileAccess.get_file_as_string("res://scripts/core/save_header.gd")
	assert_true(source.length() > 0, "the header source was read")
	for banned: String in ["encode_float", "decode_float", "encode_double", "decode_double",
			"PackedFloat32Array", "PackedFloat64Array", ": float", "-> float"]:
		assert_false(source.contains(banned), "the header source contains no '%s'" % banned)
