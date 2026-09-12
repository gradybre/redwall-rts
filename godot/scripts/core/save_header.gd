extends RefCounted
## ARCH-SAVE-002's fixed 256-byte save header and its 64-byte section descriptors.
##
## WHAT IS IMPLEMENTED, AND WHERE IT IS STATED. Every constant below is transcribed from
## `docs/systems_architecture.md:716-733` -- the save-header offset table and the descriptor
## sentence that follows it. Nothing here is chosen by this module:
##
##   offset 0 magic ASCII `RWLSET01` (8) · 8 format version 1 (u32) · 12 header bytes 256 (u32)
##   16 endian sentinel 16909060 (u32) · 20 section count (u32) · 24 total file bytes (u64)
##   32 completed tick (i64) · 40 rules hash · 72 catalog hash · 104 map hash · 136 integer
##   lookup-table hash · 168 engine patch/build identity hash (32 each) · 200 section table
##   offset, always 256 (u64) · 208 chronicle record count (u64) · 216 replay command sequence
##   at checkpoint (u64) · 224 body digest over table plus section bytes (32).
##
##   Descriptor: `section_id:u32, schema_version:u32, offset:u64, byte_length:u64, row_count:u64,
##   crc32:u32, flags:u32, reserved_zero:24 bytes` = 64 bytes.
##
##   CRC is CRC-32/ISO-HDLC: reversed polynomial 3988292384, initial register 4294967295,
##   reflected bytes, final XOR 4294967295; ASCII `123456789` gives 3421780262. That check vector
##   is asserted in `test_save_header.gd`, so a wrong table cannot pass silently.
##
## THE CATALOG HASH AT OFFSET 72 IS NOT RECOMPUTED HERE. `catalog_ids.gd` already owns that
## digest and names this very offset in its own `SAVE_HEADER_CATALOG_HASH_OFFSET`. This module
## asserts the two constants are equal at load time and delegates the digest to
## `catalog_ids.gd.build()` / `digest_of()`. There is exactly one SHA-256 of the catalog in this
## repository and it is not in this file.
##
## WHAT THIS MODULE DELIBERATELY DOES NOT DO -- task 09.2 owns all of it and is BLOCKED:
##
##   * BLOCKER H1: the schema version policy. `docs/tasks/09_persistence_replay_reliability.md:17`
##     requires "an explicit version policy before writing release saves" and "do not silently
##     repurpose v1 bytes". So the per-section `schema_version` is carried and range-checked as a
##     u32 and NOTHING here validates its value. The file-level format version IS stated as 1
##     (systems_architecture.md:718) and ARCH-SAVE-005 requires rejecting "future format
##     versions", so that one is checked.
##   * BLOCKER H2: the rules hash (offset 40), map hash (104), integer lookup-table hash (136)
##     and engine build hash (168) have NO producer in this repository. Decision 0034 says so of
##     the rules hash in terms: "the separate offset-40 rules hash, whose serializer does not
##     exist yet either". They are therefore carried as caller-supplied 32-byte digests, checked
##     for length and nothing else. This module does not invent how any of them is computed.
##   * BLOCKER H3: section BODIES. ARCH-SAVE-002 assigns fifteen section IDs and never enumerates
##     their contents; §11 EVENT_SCHEDULE, §13 CHRONICLE and §15 STATE_DIGEST have no owning
##     module at all (`docs/persistence_state_registry.md`, whose section assignment is stated
##     there as its own reading with a basis, not as a quotation). Not one byte of a section body
##     is written or parsed here.
##   * BLOCKER H4: whether section ranges must TILE the file with no gaps. ARCH-SAVE-004 requires
##     "nonoverlapping ranges, exact file length, overflow-safe offsets" and does not say
##     contiguous. `section_table_refusal()` therefore enforces non-overlap, containment and the
##     exact declared file length, and permits a gap. Tightening that is 09.2's call to make.
##
## PERSISTENCE AND DIGEST MEMBERSHIP ARE SEPARATE DIMENSIONS (ARCH-SAVE-007, 2026-09-11). The
## offset-224 body digest and the per-section CRC cover EVERY saved byte, including the host
## debt and six clock counters that ARCH-HASH-001 explicitly excludes from the canonical state
## hash. This module owns the former and not the latter: nothing here computes, stores or
## compares ARCH-HASH-001's `RWL-STATE-1` digest, which belongs to section 15 STATE_DIGEST and
## has no owning module yet. `test_save_header.gd` pins the consequence -- changing a header
## field does not change the body digest, so a changed completed tick is caught by state
## verification rather than by this CRC/SHA pair, exactly as the paragraph at
## systems_architecture.md:745 says.
##
## ALLOCATE BEFORE CONSUME (decision 0059). Every function here is static and pure over its
## arguments. A refused header or section table has touched no store, no column and no world; the
## caller gets a `Refusal` and decides. Nothing returns a sentinel offset or a zeroed header that
## could be mistaken for a parsed one.

const SaveCodec := preload("res://scripts/core/save_codec.gd")
const CatalogIdsScript := preload("res://scripts/core/catalog_ids.gd")
const IntMathScript := preload("res://scripts/core/int_math.gd")

# --- the fixed header layout ------------------------------------------------------------------

const MAGIC: String = "RWLSET01"
const MAGIC_BYTES: int = 8
const HEADER_BYTES: int = 256
const FORMAT_VERSION: int = 1
const ENDIAN_SENTINEL: int = 16909060
const DIGEST_BYTES: int = 32
const SECTION_TABLE_OFFSET: int = 256
const SECTION_DESCRIPTOR_BYTES: int = 64
const SECTION_COUNT: int = 15
const SECTION_ID_MIN: int = 1
const SECTION_ID_MAX: int = 15

const OFFSET_MAGIC: int = 0
const OFFSET_FORMAT_VERSION: int = 8
const OFFSET_HEADER_BYTES: int = 12
const OFFSET_ENDIAN_SENTINEL: int = 16
const OFFSET_SECTION_COUNT: int = 20
const OFFSET_TOTAL_FILE_BYTES: int = 24
const OFFSET_COMPLETED_TICK: int = 32
const OFFSET_RULES_HASH: int = 40
const OFFSET_CATALOG_HASH: int = 72
const OFFSET_MAP_HASH: int = 104
const OFFSET_LOOKUP_HASH: int = 136
const OFFSET_ENGINE_HASH: int = 168
const OFFSET_SECTION_TABLE_OFFSET: int = 200
const OFFSET_CHRONICLE_RECORD_COUNT: int = 208
const OFFSET_REPLAY_SEQUENCE: int = 216
const OFFSET_BODY_DIGEST: int = 224

const DESC_OFFSET_SECTION_ID: int = 0
const DESC_OFFSET_SCHEMA_VERSION: int = 4
const DESC_OFFSET_OFFSET: int = 8
const DESC_OFFSET_BYTE_LENGTH: int = 16
const DESC_OFFSET_ROW_COUNT: int = 24
const DESC_OFFSET_CRC32: int = 32
const DESC_OFFSET_FLAGS: int = 36
const DESC_OFFSET_RESERVED_ZERO: int = 40
const DESC_RESERVED_ZERO_BYTES: int = 24

# --- CRC-32/ISO-HDLC --------------------------------------------------------------------------

const CRC32_REVERSED_POLYNOMIAL: int = 3988292384
const CRC32_INITIAL_REGISTER: int = 4294967295
const CRC32_FINAL_XOR: int = 4294967295
const CRC32_CHECK_VECTOR: String = "123456789"
const CRC32_CHECK_VALUE: int = 3421780262

# --- refusal codes ----------------------------------------------------------------------------

const REFUSE_NONE: StringName = &""
const REFUSE_HEADER_TRUNCATED: StringName = &"SAVE_HEADER_TRUNCATED"
const REFUSE_MAGIC: StringName = &"SAVE_HEADER_MAGIC"
const REFUSE_ENDIAN_SENTINEL: StringName = &"SAVE_HEADER_ENDIAN_SENTINEL"
const REFUSE_FUTURE_FORMAT_VERSION: StringName = &"SAVE_HEADER_FUTURE_FORMAT_VERSION"
const REFUSE_FORMAT_VERSION: StringName = &"SAVE_HEADER_FORMAT_VERSION"
const REFUSE_HEADER_BYTES: StringName = &"SAVE_HEADER_HEADER_BYTES"
const REFUSE_SECTION_TABLE_OFFSET: StringName = &"SAVE_HEADER_SECTION_TABLE_OFFSET"
const REFUSE_SECTION_COUNT: StringName = &"SAVE_HEADER_SECTION_COUNT"
const REFUSE_NEGATIVE_TICK: StringName = &"SAVE_HEADER_NEGATIVE_TICK"
const REFUSE_FILE_LENGTH: StringName = &"SAVE_HEADER_FILE_LENGTH"
const REFUSE_DIGEST_LENGTH: StringName = &"SAVE_HEADER_DIGEST_LENGTH"
const REFUSE_BODY_DIGEST_MISMATCH: StringName = &"SAVE_HEADER_BODY_DIGEST_MISMATCH"
const REFUSE_CATALOG_HASH_MISMATCH: StringName = &"SAVE_HEADER_CATALOG_HASH_MISMATCH"
const REFUSE_CATALOG_UNAVAILABLE: StringName = &"SAVE_HEADER_CATALOG_UNAVAILABLE"
const REFUSE_SECTION_ID_RANGE: StringName = &"SAVE_HEADER_SECTION_ID_RANGE"
const REFUSE_SECTION_ID_DUPLICATE: StringName = &"SAVE_HEADER_SECTION_ID_DUPLICATE"
const REFUSE_SECTION_ID_MISSING: StringName = &"SAVE_HEADER_SECTION_ID_MISSING"
const REFUSE_SECTION_RANGE_OVERFLOW: StringName = &"SAVE_HEADER_SECTION_RANGE_OVERFLOW"
const REFUSE_SECTION_BEFORE_BODY: StringName = &"SAVE_HEADER_SECTION_BEFORE_BODY"
const REFUSE_SECTION_PAST_END: StringName = &"SAVE_HEADER_SECTION_PAST_END"
const REFUSE_SECTION_OVERLAP: StringName = &"SAVE_HEADER_SECTION_OVERLAP"
const REFUSE_SECTION_NEGATIVE: StringName = &"SAVE_HEADER_SECTION_NEGATIVE"
const REFUSE_RESERVED_NONZERO: StringName = &"SAVE_HEADER_RESERVED_NONZERO"
const REFUSE_VALUE_RANGE: StringName = &"SAVE_HEADER_VALUE_RANGE"


class Refusal:
	"""One refusal: a StringName code and the detail behind it. `REFUSE_NONE` means accepted."""
	var code: StringName
	var detail: String

	func _init(p_code: StringName, p_detail: String) -> void:
		"""Store the refusal code and its detail."""
		code = p_code
		detail = p_detail

	func is_ok() -> bool:
		"""True when this record carries no refusal."""
		return code == REFUSE_NONE


class Header:
	"""The 256 fixed header bytes as typed integers and 32-byte digests. No float, no Variant."""
	var format_version: int = FORMAT_VERSION
	var header_bytes: int = HEADER_BYTES
	var endian_sentinel: int = ENDIAN_SENTINEL
	var section_count: int = SECTION_COUNT
	var total_file_bytes: int = 0
	var completed_tick: int = 0
	var rules_hash: PackedByteArray = PackedByteArray()
	var catalog_hash: PackedByteArray = PackedByteArray()
	var map_hash: PackedByteArray = PackedByteArray()
	var lookup_hash: PackedByteArray = PackedByteArray()
	var engine_hash: PackedByteArray = PackedByteArray()
	var section_table_offset: int = SECTION_TABLE_OFFSET
	var chronicle_record_count: int = 0
	var replay_sequence: int = 0
	var body_digest: PackedByteArray = PackedByteArray()


class Descriptor:
	"""One 64-byte section descriptor. `schema_version` and `flags` are carried, not interpreted."""
	var section_id: int = 0
	var schema_version: int = 0
	var offset: int = 0
	var byte_length: int = 0
	var row_count: int = 0
	var crc32: int = 0
	var flags: int = 0


# --- CRC-32/ISO-HDLC --------------------------------------------------------------------------

static var _crc_table: PackedInt64Array = PackedInt64Array()


static func _crc_lookup() -> PackedInt64Array:
	"""Build the 256-entry reflected CRC table once, from the stated reversed polynomial."""
	if _crc_table.size() == 256:
		return _crc_table
	var table: PackedInt64Array = PackedInt64Array()
	table.resize(256)
	for index: int in 256:
		var register: int = index
		for _bit: int in 8:
			if (register & 1) != 0:
				register = (register >> 1) ^ CRC32_REVERSED_POLYNOMIAL
			else:
				register >>= 1
		table[index] = register
	_crc_table = table
	return _crc_table


static func crc32_update(register: int, bytes: PackedByteArray) -> int:
	"""Fold `bytes` into a running reflected CRC register. Start from CRC32_INITIAL_REGISTER."""
	var table: PackedInt64Array = _crc_lookup()
	var value: int = register & SaveCodec.UINT32_MAX
	for index: int in bytes.size():
		value = table[(value ^ bytes[index]) & 0xff] ^ (value >> 8)
	return value


static func crc32_of(bytes: PackedByteArray) -> int:
	"""CRC-32/ISO-HDLC of exactly these bytes, as an unsigned 32-bit integer."""
	return crc32_update(CRC32_INITIAL_REGISTER, bytes) ^ CRC32_FINAL_XOR


# --- header encode ----------------------------------------------------------------------------

static func encode_header_into(header: Header, out: PackedByteArray) -> Refusal:
	"""Write the 256 fixed header bytes into `out` at offset 0, or refuse without writing.

	Every digest length and every field range is checked BEFORE the first byte is written, so a
	refused encode leaves `out` byte-identical to what the caller handed in.
	"""
	if out.size() < HEADER_BYTES:
		return Refusal.new(REFUSE_HEADER_TRUNCATED,
			"a %d-byte buffer cannot hold the %d-byte header" % [out.size(), HEADER_BYTES])
	var digests: Refusal = digest_lengths_refusal(header)
	if not digests.is_ok():
		return digests
	var ranges: Refusal = _encodable_ranges_refusal(header)
	if not ranges.is_ok():
		return ranges
	var staging: PackedByteArray = PackedByteArray()
	staging.resize(HEADER_BYTES)
	if not _write_header_words(header, staging) or not _write_header_digests(header, staging):
		return Refusal.new(REFUSE_VALUE_RANGE, "a header field could not be encoded")
	var scratch: SaveCodec.Scalar = SaveCodec.Scalar.new()
	if not SaveCodec.write_bytes_into(out, 0, staging, scratch):
		return Refusal.new(REFUSE_HEADER_TRUNCATED, scratch.detail)
	return Refusal.new(REFUSE_NONE, "")


static func digest_lengths_refusal(header: Header) -> Refusal:
	"""Every one of the six header digests must be exactly 32 bytes. BLOCKER H2: nothing more."""
	var names: Array[String] = ["rules", "catalog", "map", "lookup", "engine", "body"]
	var values: Array[PackedByteArray] = [header.rules_hash, header.catalog_hash, header.map_hash,
		header.lookup_hash, header.engine_hash, header.body_digest]
	for index: int in names.size():
		if values[index].size() != DIGEST_BYTES:
			return Refusal.new(REFUSE_DIGEST_LENGTH, "the %s hash is %d bytes, not %d"
				% [names[index], values[index].size(), DIGEST_BYTES])
	return Refusal.new(REFUSE_NONE, "")


static func _encodable_ranges_refusal(header: Header) -> Refusal:
	"""Refuse any field that does not fit the width ARCH-SAVE-002 gives it, before encoding."""
	if not SaveCodec.fits_u32(header.format_version) or not SaveCodec.fits_u32(header.header_bytes) \
			or not SaveCodec.fits_u32(header.endian_sentinel) \
			or not SaveCodec.fits_u32(header.section_count):
		return Refusal.new(REFUSE_VALUE_RANGE, "a u32 header word is outside the u32 domain")
	if header.total_file_bytes < 0 or header.section_table_offset < 0 \
			or header.chronicle_record_count < 0 or header.replay_sequence < 0:
		return Refusal.new(REFUSE_VALUE_RANGE, "a u64 header word is negative")
	return Refusal.new(REFUSE_NONE, "")


static func _write_header_words(header: Header, out: PackedByteArray) -> bool:
	"""Write the magic and every integer header word into the staging buffer. True when all took."""
	var scratch: SaveCodec.Scalar = SaveCodec.Scalar.new()
	var ok: bool = SaveCodec.write_bytes_into(out, OFFSET_MAGIC, MAGIC.to_ascii_buffer(), scratch)
	ok = SaveCodec.write_u32_into(out, OFFSET_FORMAT_VERSION, header.format_version, scratch) and ok
	ok = SaveCodec.write_u32_into(out, OFFSET_HEADER_BYTES, header.header_bytes, scratch) and ok
	ok = SaveCodec.write_u32_into(out, OFFSET_ENDIAN_SENTINEL, header.endian_sentinel, scratch) and ok
	ok = SaveCodec.write_u32_into(out, OFFSET_SECTION_COUNT, header.section_count, scratch) and ok
	ok = SaveCodec.write_u64_into(out, OFFSET_TOTAL_FILE_BYTES, header.total_file_bytes, scratch) and ok
	ok = SaveCodec.write_i64_into(out, OFFSET_COMPLETED_TICK, header.completed_tick, scratch) and ok
	ok = SaveCodec.write_u64_into(out, OFFSET_SECTION_TABLE_OFFSET, header.section_table_offset,
		scratch) and ok
	ok = SaveCodec.write_u64_into(out, OFFSET_CHRONICLE_RECORD_COUNT, header.chronicle_record_count,
		scratch) and ok
	return SaveCodec.write_u64_into(out, OFFSET_REPLAY_SEQUENCE, header.replay_sequence,
		scratch) and ok


static func _write_header_digests(header: Header, out: PackedByteArray) -> bool:
	"""Write the five identity digests and the body digest. True when every one took."""
	var scratch: SaveCodec.Scalar = SaveCodec.Scalar.new()
	var ok: bool = SaveCodec.write_bytes_into(out, OFFSET_RULES_HASH, header.rules_hash, scratch)
	ok = SaveCodec.write_bytes_into(out, OFFSET_CATALOG_HASH, header.catalog_hash, scratch) and ok
	ok = SaveCodec.write_bytes_into(out, OFFSET_MAP_HASH, header.map_hash, scratch) and ok
	ok = SaveCodec.write_bytes_into(out, OFFSET_LOOKUP_HASH, header.lookup_hash, scratch) and ok
	ok = SaveCodec.write_bytes_into(out, OFFSET_ENGINE_HASH, header.engine_hash, scratch) and ok
	return SaveCodec.write_bytes_into(out, OFFSET_BODY_DIGEST, header.body_digest, scratch) and ok


# --- header decode ----------------------------------------------------------------------------

static func decode_header_into(bytes: PackedByteArray, out: Header) -> Refusal:
	"""Parse the 256 fixed header bytes into `out`, or refuse without a partial parse.

	Structural only: it refuses a short buffer and a u64 field a GDScript int cannot hold, and
	does not judge magic, version, tick or file length. `header_refusal()` does that, in
	ARCH-SAVE-004's order.
	"""
	if bytes.size() < HEADER_BYTES:
		return Refusal.new(REFUSE_HEADER_TRUNCATED,
			"a %d-byte buffer is shorter than the %d-byte header" % [bytes.size(), HEADER_BYTES])
	var reader: SaveCodec.Reader = SaveCodec.Reader.new(bytes)
	var parsed: Header = Header.new()
	if not _read_header_words(reader, parsed):
		return Refusal.new(reader.refusal(), reader.detail())
	_read_header_digests(bytes, parsed)
	_copy_header(parsed, out)
	return Refusal.new(REFUSE_NONE, "")


static func _read_header_words(reader: SaveCodec.Reader, parsed: Header) -> bool:
	"""Read every integer header word through the bounded reader, in offset order."""
	var scalar: SaveCodec.Scalar = SaveCodec.Scalar.new()
	reader.seek(OFFSET_FORMAT_VERSION)
	parsed.format_version = scalar.value if reader.read_u32_into(scalar) else 0
	parsed.header_bytes = scalar.value if reader.read_u32_into(scalar) else 0
	parsed.endian_sentinel = scalar.value if reader.read_u32_into(scalar) else 0
	parsed.section_count = scalar.value if reader.read_u32_into(scalar) else 0
	parsed.total_file_bytes = scalar.value if reader.read_u64_into(scalar) else 0
	parsed.completed_tick = scalar.value if reader.read_i64_into(scalar) else 0
	reader.seek(OFFSET_SECTION_TABLE_OFFSET)
	parsed.section_table_offset = scalar.value if reader.read_u64_into(scalar) else 0
	parsed.chronicle_record_count = scalar.value if reader.read_u64_into(scalar) else 0
	parsed.replay_sequence = scalar.value if reader.read_u64_into(scalar) else 0
	return not reader.failed()


static func _read_header_digests(bytes: PackedByteArray, parsed: Header) -> void:
	"""Slice the six 32-byte digests out of an already length-checked header."""
	parsed.rules_hash = bytes.slice(OFFSET_RULES_HASH, OFFSET_RULES_HASH + DIGEST_BYTES)
	parsed.catalog_hash = bytes.slice(OFFSET_CATALOG_HASH, OFFSET_CATALOG_HASH + DIGEST_BYTES)
	parsed.map_hash = bytes.slice(OFFSET_MAP_HASH, OFFSET_MAP_HASH + DIGEST_BYTES)
	parsed.lookup_hash = bytes.slice(OFFSET_LOOKUP_HASH, OFFSET_LOOKUP_HASH + DIGEST_BYTES)
	parsed.engine_hash = bytes.slice(OFFSET_ENGINE_HASH, OFFSET_ENGINE_HASH + DIGEST_BYTES)
	parsed.body_digest = bytes.slice(OFFSET_BODY_DIGEST, OFFSET_BODY_DIGEST + DIGEST_BYTES)


static func _copy_header(parsed: Header, out: Header) -> void:
	"""Publish a fully parsed header into the caller's object in one step, never field by field."""
	out.format_version = parsed.format_version
	out.header_bytes = parsed.header_bytes
	out.endian_sentinel = parsed.endian_sentinel
	out.section_count = parsed.section_count
	out.total_file_bytes = parsed.total_file_bytes
	out.completed_tick = parsed.completed_tick
	out.rules_hash = parsed.rules_hash
	out.catalog_hash = parsed.catalog_hash
	out.map_hash = parsed.map_hash
	out.lookup_hash = parsed.lookup_hash
	out.engine_hash = parsed.engine_hash
	out.section_table_offset = parsed.section_table_offset
	out.chronicle_record_count = parsed.chronicle_record_count
	out.replay_sequence = parsed.replay_sequence
	out.body_digest = parsed.body_digest


# --- header validation ------------------------------------------------------------------------

static func magic_refusal(bytes: PackedByteArray) -> Refusal:
	"""ARCH-SAVE-004's first check: the eight ASCII magic bytes, compared byte for byte."""
	if bytes.size() < MAGIC_BYTES:
		return Refusal.new(REFUSE_HEADER_TRUNCATED,
			"a %d-byte buffer cannot hold the magic" % bytes.size())
	if bytes.slice(0, MAGIC_BYTES) != MAGIC.to_ascii_buffer():
		return Refusal.new(REFUSE_MAGIC, "the first %d bytes are not '%s'" % [MAGIC_BYTES, MAGIC])
	return Refusal.new(REFUSE_NONE, "")


static func header_refusal(header: Header, available_bytes: int) -> Refusal:
	"""ARCH-SAVE-004's magic/endian/version/tick/length checks over an already parsed header.

	`available_bytes` is the real byte count on disk; ARCH-SAVE-004 requires the "exact file
	length", so a header claiming any other total is refused rather than trusted.
	"""
	var version: Refusal = _version_refusal(header)
	if not version.is_ok():
		return version
	if header.endian_sentinel != ENDIAN_SENTINEL:
		return Refusal.new(REFUSE_ENDIAN_SENTINEL, "endian sentinel %d is not %d"
			% [header.endian_sentinel, ENDIAN_SENTINEL])
	if header.completed_tick < 0:
		return Refusal.new(REFUSE_NEGATIVE_TICK,
			"completed tick %d is negative" % header.completed_tick)
	return _extent_refusal(header, available_bytes)


static func _version_refusal(header: Header) -> Refusal:
	"""Format version, header size and section table offset. BLOCKER H1 stops at the file level."""
	if header.format_version > FORMAT_VERSION:
		return Refusal.new(REFUSE_FUTURE_FORMAT_VERSION,
			"format version %d is newer than %d" % [header.format_version, FORMAT_VERSION])
	if header.format_version != FORMAT_VERSION:
		return Refusal.new(REFUSE_FORMAT_VERSION,
			"format version %d is not %d" % [header.format_version, FORMAT_VERSION])
	if header.header_bytes != HEADER_BYTES:
		return Refusal.new(REFUSE_HEADER_BYTES,
			"header bytes %d is not %d" % [header.header_bytes, HEADER_BYTES])
	if header.section_table_offset != SECTION_TABLE_OFFSET:
		return Refusal.new(REFUSE_SECTION_TABLE_OFFSET, "section table offset %d is not %d"
			% [header.section_table_offset, SECTION_TABLE_OFFSET])
	return Refusal.new(REFUSE_NONE, "")


static func _extent_refusal(header: Header, available_bytes: int) -> Refusal:
	"""Section count and declared file length against what is actually on disk."""
	if header.section_count != SECTION_COUNT:
		return Refusal.new(REFUSE_SECTION_COUNT, "section count %d is not %d"
			% [header.section_count, SECTION_COUNT])
	if header.total_file_bytes != available_bytes:
		return Refusal.new(REFUSE_FILE_LENGTH, "the header claims %d bytes but %d are present"
			% [header.total_file_bytes, available_bytes])
	if header.total_file_bytes < body_offset():
		return Refusal.new(REFUSE_FILE_LENGTH,
			"%d bytes cannot hold the header and its %d-entry section table"
				% [header.total_file_bytes, SECTION_COUNT])
	return Refusal.new(REFUSE_NONE, "")


static func body_offset() -> int:
	"""First byte after the header and the full section table: 256 + 64*15."""
	return SECTION_TABLE_OFFSET + SECTION_DESCRIPTOR_BYTES * SECTION_COUNT


# --- section descriptors ------------------------------------------------------------------------

static func encode_descriptor_into(descriptor: Descriptor, out: PackedByteArray,
		offset: int) -> Refusal:
	"""Write one 64-byte descriptor at `offset`, reserved bytes zeroed, or refuse without writing."""
	if not SaveCodec.fits_u32(descriptor.section_id) \
			or not SaveCodec.fits_u32(descriptor.schema_version) \
			or not SaveCodec.fits_u32(descriptor.crc32) or not SaveCodec.fits_u32(descriptor.flags):
		return Refusal.new(REFUSE_VALUE_RANGE, "a u32 descriptor word is outside the u32 domain")
	if descriptor.offset < 0 or descriptor.byte_length < 0 or descriptor.row_count < 0:
		return Refusal.new(REFUSE_VALUE_RANGE, "a u64 descriptor word is negative")
	var staging: PackedByteArray = PackedByteArray()
	staging.resize(SECTION_DESCRIPTOR_BYTES)
	if not _write_descriptor(descriptor, staging):
		return Refusal.new(REFUSE_VALUE_RANGE, "a descriptor field could not be encoded")
	var scratch: SaveCodec.Scalar = SaveCodec.Scalar.new()
	if not SaveCodec.write_bytes_into(out, offset, staging, scratch):
		return Refusal.new(REFUSE_HEADER_TRUNCATED, scratch.detail)
	return Refusal.new(REFUSE_NONE, "")


static func _write_descriptor(descriptor: Descriptor, out: PackedByteArray) -> bool:
	"""Write one descriptor's seven words into a 64-byte staging buffer whose tail is already zero."""
	var scratch: SaveCodec.Scalar = SaveCodec.Scalar.new()
	var ok: bool = SaveCodec.write_u32_into(out, DESC_OFFSET_SECTION_ID, descriptor.section_id,
		scratch)
	ok = SaveCodec.write_u32_into(out, DESC_OFFSET_SCHEMA_VERSION, descriptor.schema_version,
		scratch) and ok
	ok = SaveCodec.write_u64_into(out, DESC_OFFSET_OFFSET, descriptor.offset, scratch) and ok
	ok = SaveCodec.write_u64_into(out, DESC_OFFSET_BYTE_LENGTH, descriptor.byte_length,
		scratch) and ok
	ok = SaveCodec.write_u64_into(out, DESC_OFFSET_ROW_COUNT, descriptor.row_count, scratch) and ok
	ok = SaveCodec.write_u32_into(out, DESC_OFFSET_CRC32, descriptor.crc32, scratch) and ok
	return SaveCodec.write_u32_into(out, DESC_OFFSET_FLAGS, descriptor.flags, scratch) and ok


static func decode_descriptor_into(bytes: PackedByteArray, offset: int,
		out: Descriptor) -> Refusal:
	"""Parse one 64-byte descriptor at `offset`, refusing nonzero reserved padding (ARCH-SAVE-005)."""
	if offset < 0 or bytes.size() < SECTION_DESCRIPTOR_BYTES \
			or offset > bytes.size() - SECTION_DESCRIPTOR_BYTES:
		return Refusal.new(REFUSE_HEADER_TRUNCATED,
			"no %d-byte descriptor at offset %d" % [SECTION_DESCRIPTOR_BYTES, offset])
	var padding: StringName = SaveCodec.zero_padding_refusal(bytes,
		offset + DESC_OFFSET_RESERVED_ZERO, DESC_RESERVED_ZERO_BYTES)
	if padding != SaveCodec.REFUSE_NONE:
		return Refusal.new(REFUSE_RESERVED_NONZERO,
			"the 24 reserved descriptor bytes at offset %d are not zero" % offset)
	var reader: SaveCodec.Reader = SaveCodec.Reader.new(bytes)
	var parsed: Descriptor = Descriptor.new()
	reader.seek(offset)
	if not _read_descriptor(reader, parsed):
		return Refusal.new(reader.refusal(), reader.detail())
	_copy_descriptor(parsed, out)
	return Refusal.new(REFUSE_NONE, "")


static func _read_descriptor(reader: SaveCodec.Reader, parsed: Descriptor) -> bool:
	"""Read one descriptor's seven words in offset order through the bounded reader."""
	var scalar: SaveCodec.Scalar = SaveCodec.Scalar.new()
	parsed.section_id = scalar.value if reader.read_u32_into(scalar) else 0
	parsed.schema_version = scalar.value if reader.read_u32_into(scalar) else 0
	parsed.offset = scalar.value if reader.read_u64_into(scalar) else 0
	parsed.byte_length = scalar.value if reader.read_u64_into(scalar) else 0
	parsed.row_count = scalar.value if reader.read_u64_into(scalar) else 0
	parsed.crc32 = scalar.value if reader.read_u32_into(scalar) else 0
	parsed.flags = scalar.value if reader.read_u32_into(scalar) else 0
	return not reader.failed()


static func _copy_descriptor(parsed: Descriptor, out: Descriptor) -> void:
	"""Publish a fully parsed descriptor into the caller's object in one step."""
	out.section_id = parsed.section_id
	out.schema_version = parsed.schema_version
	out.offset = parsed.offset
	out.byte_length = parsed.byte_length
	out.row_count = parsed.row_count
	out.crc32 = parsed.crc32
	out.flags = parsed.flags


static func decode_section_table(bytes: PackedByteArray, out: Array[Descriptor]) -> Refusal:
	"""Parse all fifteen descriptors starting at offset 256, or refuse leaving `out` untouched.

	Allocate before consume: the descriptors are parsed into a local array and published only
	when every one of them parsed, so a caller never sees a half-filled table.
	"""
	var parsed: Array[Descriptor] = []
	for index: int in SECTION_COUNT:
		var descriptor: Descriptor = Descriptor.new()
		var refusal: Refusal = decode_descriptor_into(bytes,
			SECTION_TABLE_OFFSET + index * SECTION_DESCRIPTOR_BYTES, descriptor)
		if not refusal.is_ok():
			return refusal
		parsed.append(descriptor)
	out.assign(parsed)
	return Refusal.new(REFUSE_NONE, "")


# --- section table validation -------------------------------------------------------------------

static func section_table_refusal(descriptors: Array[Descriptor], header: Header) -> Refusal:
	"""ARCH-SAVE-004: all 15 unique ids, overflow-safe offsets, nonoverlapping, inside the file.

	BLOCKER H4: gaps between sections are permitted because "contiguous" is not stated. Every
	other clause of that sentence is enforced.
	"""
	if descriptors.size() != SECTION_COUNT:
		return Refusal.new(REFUSE_SECTION_COUNT,
			"%d descriptors, not %d" % [descriptors.size(), SECTION_COUNT])
	var identity: Refusal = section_identity_refusal(descriptors)
	if not identity.is_ok():
		return identity
	for descriptor: Descriptor in descriptors:
		var extent: Refusal = _section_extent_refusal(descriptor, header)
		if not extent.is_ok():
			return extent
	return _section_overlap_refusal(descriptors)


static func section_identity_refusal(descriptors: Array[Descriptor]) -> Refusal:
	"""ARCH-SAVE-004's "require all 15 unique section IDs", as a standalone predicate.

	Every id is in 1..15, no id repeats, and all fifteen are present. Public and separately tested
	because within `section_table_refusal()` the last clause is implied by the other two and the
	count: fifteen unique ids drawn from fifteen values leave none out. Called with any other
	number of descriptors -- which a future writer could do -- the absence check earns its keep.
	"""
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(SECTION_ID_MAX + 1)
	for descriptor: Descriptor in descriptors:
		var id: int = descriptor.section_id
		if id < SECTION_ID_MIN or id > SECTION_ID_MAX:
			return Refusal.new(REFUSE_SECTION_ID_RANGE, "section id %d is outside %d..%d"
				% [id, SECTION_ID_MIN, SECTION_ID_MAX])
		if seen[id] != 0:
			return Refusal.new(REFUSE_SECTION_ID_DUPLICATE, "section id %d appears twice" % id)
		seen[id] = 1
	for id: int in range(SECTION_ID_MIN, SECTION_ID_MAX + 1):
		if seen[id] == 0:
			return Refusal.new(REFUSE_SECTION_ID_MISSING, "section id %d is absent" % id)
	return Refusal.new(REFUSE_NONE, "")


static func _section_extent_refusal(descriptor: Descriptor, header: Header) -> Refusal:
	"""One section's range: nonnegative, overflow-safe, after the table, inside the file."""
	if descriptor.offset < 0 or descriptor.byte_length < 0:
		return Refusal.new(REFUSE_SECTION_NEGATIVE,
			"section %d has a negative offset or length" % descriptor.section_id)
	var end: IntMathScript.IntResult = IntMathScript.checked_add(descriptor.offset,
		descriptor.byte_length)
	if not end.ok:
		return Refusal.new(REFUSE_SECTION_RANGE_OVERFLOW,
			"section %d offset+length overflows int64" % descriptor.section_id)
	if descriptor.offset < body_offset():
		return Refusal.new(REFUSE_SECTION_BEFORE_BODY, "section %d starts at %d, before %d"
			% [descriptor.section_id, descriptor.offset, body_offset()])
	if end.value > header.total_file_bytes:
		return Refusal.new(REFUSE_SECTION_PAST_END, "section %d ends at %d, past the %d-byte file"
			% [descriptor.section_id, end.value, header.total_file_bytes])
	return Refusal.new(REFUSE_NONE, "")


static func _section_overlap_refusal(descriptors: Array[Descriptor]) -> Refusal:
	"""No two nonempty sections share a byte. Compared in ascending-offset order, not as given."""
	var order: Array[Descriptor] = descriptors.duplicate()
	order.sort_custom(func(a: Descriptor, b: Descriptor) -> bool: return a.offset < b.offset)
	var reach: int = 0
	var reach_id: int = 0
	for descriptor: Descriptor in order:
		if descriptor.byte_length == 0:
			continue
		if descriptor.offset < reach:
			return Refusal.new(REFUSE_SECTION_OVERLAP, "section %d starts at %d, inside section %d"
				% [descriptor.section_id, descriptor.offset, reach_id])
		reach = descriptor.offset + descriptor.byte_length
		reach_id = descriptor.section_id
	return Refusal.new(REFUSE_NONE, "")


# --- body digest and catalog identity -------------------------------------------------------------

static func compute_body_digest(bytes: PackedByteArray) -> PackedByteArray:
	"""SHA-256 over the section table plus every section byte: everything from offset 256 on.

	"Body digest over table plus section bytes" (systems_architecture.md:729). Returns an empty
	array only when the buffer is shorter than the header, which `body_digest_refusal()` refuses
	before ever comparing -- an empty digest is never compared against a stored one.
	"""
	if bytes.size() < HEADER_BYTES:
		return PackedByteArray()
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes.slice(HEADER_BYTES))
	return context.finish()


static func body_digest_refusal(bytes: PackedByteArray, header: Header) -> Refusal:
	"""Recompute the offset-224 body digest over the file and compare it byte for byte."""
	if bytes.size() < HEADER_BYTES:
		return Refusal.new(REFUSE_HEADER_TRUNCATED,
			"a %d-byte buffer has no body to digest" % bytes.size())
	if header.body_digest.size() != DIGEST_BYTES:
		return Refusal.new(REFUSE_DIGEST_LENGTH,
			"the stored body digest is %d bytes, not %d"
				% [header.body_digest.size(), DIGEST_BYTES])
	if compute_body_digest(bytes) != header.body_digest:
		return Refusal.new(REFUSE_BODY_DIGEST_MISMATCH,
			"the offset-%d body digest does not cover these bytes" % OFFSET_BODY_DIGEST)
	return Refusal.new(REFUSE_NONE, "")


static func catalog_hash_refusal(header: Header) -> Refusal:
	"""Compare the offset-72 catalog hash against `catalog_ids.gd`'s digest for this build.

	The digest is NOT recomputed here. `catalog_ids.gd` owns it, names this offset in its own
	`SAVE_HEADER_CATALOG_HASH_OFFSET`, and this function asserts the two constants agree before
	comparing, so the two files cannot drift to different offsets unnoticed.
	"""
	assert(OFFSET_CATALOG_HASH == CatalogIdsScript.SAVE_HEADER_CATALOG_HASH_OFFSET)
	if header.catalog_hash.size() != DIGEST_BYTES:
		return Refusal.new(REFUSE_DIGEST_LENGTH, "the catalog hash is %d bytes, not %d"
			% [header.catalog_hash.size(), DIGEST_BYTES])
	var built: CatalogIdsScript.BuildResult = CatalogIdsScript.build()
	if not built.ok:
		return Refusal.new(REFUSE_CATALOG_UNAVAILABLE,
			"this build cannot compile its own catalog: %s" % built.detail)
	if header.catalog_hash != built.artifact.digest:
		return Refusal.new(REFUSE_CATALOG_HASH_MISMATCH,
			"the save's catalog hash %s is not this build's %s"
				% [header.catalog_hash.hex_encode(), built.artifact.digest_hex()])
	return Refusal.new(REFUSE_NONE, "")
