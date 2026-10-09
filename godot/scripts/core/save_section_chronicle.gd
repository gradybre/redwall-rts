extends RefCounted
## ARCH-SAVE-002 section 13 CHRONICLE: the byte codec for `chronicle.gd`'s count and rolling digest
## plus the append-only record stream they summarise. ADR 1222 build-plan step 5.
##
## THE BYTES (ADR 1222 step 5 packet; record layout and digest rule from SAVE-R09 section 13):
##
##   | Offset | Type        | Field                                  | Bytes         |
##   |-------:|-------------|----------------------------------------|---------------|
##   |      0 | u64         | record_count                           | 8             |
##   |      8 | 32 raw bytes | rolling_digest                        | 32            |
##   |     40 | 24 x N      | records, append order                  | 24 * N        |
##
## Each record is `resident_id:i32, event:i32, tick:i64, other_id:i32, detail_key:i32`, LE. The
## section length is EXACTLY `40 + 24*N`, with N bounded so that sum cannot overflow an int64. The
## descriptor's `row_count` and the header's chronicle count (offset 208) must both equal N.
##
## DECODE STREAMS, IT NEVER HASHES "ALL HISTORY AT ONCE". The records are walked in chunks of at
## most CHUNK_BYTES = 65536 bytes (ARCH-SAVE-003), each a whole number of records -- 2730 records,
## 65520 bytes -- through `DigestVerifier`, which carries only the 32-byte running digest and the
## first invalid record it saw. A future file-backed reader feeds the same verifier chunk by chunk.
##
## INTEGRITY BEFORE SEMANTICS. The verifier hashes every record even after one fails validation,
## and the digest comparison is reported FIRST. A stream that does not match its own digest is
## corrupt, and the fields of a corrupt record are not evidence of anything; a stream that does
## match is intact, and only then is "record k is not in the event domain" a meaningful refusal.
##
## THE EMPTY DOMAIN (DEC-055 Q8). `chronicle.gd` compiles zero event kinds, so the only valid
## section 13 today is the 40-byte empty one: count 0 and the all-zero digest. Every nonempty
## stream refuses -- SAVE_S13_DIGEST_MISMATCH if it is corrupt, SAVE_S13_EVENT_DOMAIN if it is
## intact. Saves are development-only until task 08.5 authors events.
##
## CANONICAL CONTRIBUTION (ARCH-HASH-001). `Adapter` supplies REG-R01's two declared fields --
## `_count` as one u64 and `_rolling_digest` as 32 u8 -- and never the records themselves.
##
## OPEN, NOT INVENTED. SAVE-R09's prose says "length=24*count"; the ADR 1222 step 5 packet adds the
## 40-byte count+digest prefix this file implements. That difference is reported, not resolved
## here. Apply checks no load barrier, matching `save_section_rng.gd`; the orchestrator owns it.
##
## COLD PATH. Saves and loads run at boundaries (ARCH-SAVE-003); per-record slices and hashing
## contexts are acceptable here and never appear in a tick. NO FLOAT anywhere in this file.

const SaveSectionChronicle := preload("res://scripts/core/save_section_chronicle.gd")
const Chronicle := preload("res://scripts/core/chronicle.gd")
const SaveCodec := preload("res://scripts/core/save_codec.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const Digest := preload("res://scripts/core/canonical_state_hash.gd")

# --- identity and layout -------------------------------------------------------------------------

const SECTION_ID: int = Chronicle.SECTION_ID
## `canonical_state_registry.json` `section_schema_versions[12]`.
const SECTION_SCHEMA_VERSION: int = 1

const COUNT_OFFSET: int = 0
const DIGEST_OFFSET: int = SaveCodec.U64_BYTES
const RECORDS_OFFSET: int = DIGEST_OFFSET + Chronicle.DIGEST_BYTES
const PREFIX_BYTES: int = RECORDS_OFFSET
const RECORD_BYTES: int = Chronicle.RECORD_BYTES
const EMPTY_SECTION_BYTES: int = PREFIX_BYTES

## ARCH-SAVE-003's streaming chunk, and the whole records that fit inside it.
const CHUNK_BYTES: int = 65536
@warning_ignore("integer_division") const CHUNK_RECORDS: int = CHUNK_BYTES / RECORD_BYTES

## The largest N whose `40 + 24*N` still fits an int64.
@warning_ignore("integer_division")
const MAX_RECORD_COUNT: int = (SaveCodec.INT64_MAX - PREFIX_BYTES) / RECORD_BYTES

# --- refusal codes -------------------------------------------------------------------------------

const REFUSE_NONE: StringName = SaveHeader.REFUSE_NONE
const REFUSE_RECORD_NULL: StringName = &"SAVE_S13_RECORD_NULL"
const REFUSE_NULL_OWNER: StringName = &"SAVE_S13_NULL_OWNER"
const REFUSE_NULL_HEADER: StringName = &"SAVE_S13_NULL_HEADER"
const REFUSE_NEGATIVE_OFFSET: StringName = &"SAVE_S13_NEGATIVE_OFFSET"
const REFUSE_TRUNCATED: StringName = &"SAVE_S13_TRUNCATED"
const REFUSE_COUNT_RANGE: StringName = &"SAVE_S13_COUNT_RANGE"
const REFUSE_LENGTH: StringName = &"SAVE_S13_LENGTH"
const REFUSE_DIGEST_LENGTH: StringName = &"SAVE_S13_DIGEST_LENGTH"
const REFUSE_EMPTY_DIGEST: StringName = &"SAVE_S13_EMPTY_DIGEST"
const REFUSE_DIGEST_MISMATCH: StringName = &"SAVE_S13_DIGEST_MISMATCH"
const REFUSE_DIGEST_FAILED: StringName = &"SAVE_S13_DIGEST_FAILED"
const REFUSE_CHUNK_SHAPE: StringName = &"SAVE_S13_CHUNK_SHAPE"
const REFUSE_HISTORY_LENGTH: StringName = &"SAVE_S13_HISTORY_LENGTH"
const REFUSE_NEGATIVE_TICK: StringName = &"SAVE_S13_NEGATIVE_TICK"
const REFUSE_EVENT_DOMAIN: StringName = &"SAVE_S13_EVENT_DOMAIN"
const REFUSE_DETAIL_DOMAIN: StringName = &"SAVE_S13_DETAIL_DOMAIN"
const REFUSE_RECORD_REFUSED: StringName = &"SAVE_S13_RECORD_REFUSED"
const REFUSE_HEADER_COUNT: StringName = &"SAVE_S13_HEADER_COUNT"
const REFUSE_SECTION_ID: StringName = &"SAVE_S13_SECTION_ID"
const REFUSE_SECTION_SCHEMA: StringName = &"SAVE_S13_SECTION_SCHEMA"
const REFUSE_ROW_COUNT: StringName = &"SAVE_S13_ROW_COUNT"
const REFUSE_OWNER_REFUSED: StringName = &"SAVE_S13_OWNER_REFUSED"
const REFUSE_ENCODE_FAILED: StringName = &"SAVE_S13_ENCODE_FAILED"
const REFUSE_ADAPTER_FIELD: StringName = &"SAVE_S13_ADAPTER_FIELD"

## Owner record codes and the section codes they surface as, index for index.
const OWNER_RECORD_CODES: Array[StringName] = [Chronicle.REFUSE_NEGATIVE_TICK,
	Chronicle.REFUSE_EVENT_DOMAIN, Chronicle.REFUSE_DETAIL_DOMAIN]
const SECTION_RECORD_CODES: Array[StringName] = [REFUSE_NEGATIVE_TICK, REFUSE_EVENT_DOMAIN,
	REFUSE_DETAIL_DOMAIN]


class Record:
	"""One section 13 summary: the record count and the 32-byte rolling digest. Never the records."""
	var record_count: int = 0
	var rolling_digest: PackedByteArray = Chronicle.zero_digest()

	func clear() -> void:
		"""Return to the empty section: count 0 and the all-zero digest."""
		record_count = 0
		rolling_digest = Chronicle.zero_digest()

	func copy_from(other: Record) -> void:
		"""Overwrite both fields from `other`, duplicating the digest buffer."""
		record_count = other.record_count
		rolling_digest = other.rolling_digest.duplicate()


class EncodeResult:
	"""Outcome of encoding one section: the payload bytes, or a refusal and no bytes."""
	var ok: bool = false
	var bytes: PackedByteArray = PackedByteArray()
	var refusal: StringName = REFUSE_NONE
	var detail: String = ""

	func succeed(p_bytes: PackedByteArray) -> bool:
		"""Record the encoded payload; always returns true."""
		ok = true
		bytes = p_bytes
		refusal = REFUSE_NONE
		detail = ""
		return true

	func refuse(p_refusal: StringName, p_detail: String) -> bool:
		"""Record a refusal with an empty payload; always returns false."""
		ok = false
		bytes = PackedByteArray()
		refusal = p_refusal
		detail = p_detail
		return false


class DigestVerifier:
	"""Streams records through SAVE-R09's rolling-digest rule, one bounded chunk at a time.

	Holds the 32-byte running digest, the number of records consumed and the FIRST record that
	failed validation -- never a record itself. A hard failure (bad chunk shape, hashing error)
	is sticky and stops consumption.
	"""
	var _digest: PackedByteArray = Chronicle.zero_digest()
	var _records: int = 0
	var _invalid_code: StringName = REFUSE_NONE
	var _invalid_detail: String = ""
	var _failure: StringName = REFUSE_NONE
	var _failure_detail: String = ""
	var _scratch: SaveCodec.Scalar = SaveCodec.Scalar.new()

	func records_consumed() -> int:
		"""Records hashed so far."""
		return _records

	func digest() -> PackedByteArray:
		"""A copy of the running digest."""
		return _digest.duplicate()

	func feed(chunk: PackedByteArray) -> bool:
		"""Consume one chunk: whole records only, at most CHUNK_BYTES. False on a hard failure."""
		if _failure != REFUSE_NONE:
			return false
		if chunk.size() > CHUNK_BYTES or chunk.size() % RECORD_BYTES != 0:
			return _fail(REFUSE_CHUNK_SHAPE, "a %d-byte chunk is not whole records within %d"
				% [chunk.size(), CHUNK_BYTES])
		@warning_ignore("integer_division") var records: int = chunk.size() / RECORD_BYTES
		for index: int in records:
			if not _consume(chunk.slice(index * RECORD_BYTES, (index + 1) * RECORD_BYTES)):
				return false
		return true

	func verdict(declared: PackedByteArray) -> SaveHeader.Refusal:
		"""After the last chunk: hard failure, then digest mismatch, then the first bad record."""
		if _failure != REFUSE_NONE:
			return SaveHeader.Refusal.new(_failure, _failure_detail)
		if _digest != declared:
			return SaveHeader.Refusal.new(REFUSE_DIGEST_MISMATCH,
				"%d records hash to %s, the section declares %s"
					% [_records, _digest.hex_encode(), declared.hex_encode()])
		if _invalid_code != REFUSE_NONE:
			return SaveHeader.Refusal.new(_invalid_code, _invalid_detail)
		return SaveHeader.Refusal.new(REFUSE_NONE, "")

	func _consume(record: PackedByteArray) -> bool:
		"""Validate one record (first failure only) and chain it into the digest."""
		if _invalid_code == REFUSE_NONE:
			_note_validity(record)
		var next: PackedByteArray = PackedByteArray()
		var code: StringName = Chronicle.digest_step_into(_digest, record, next)
		if code != Chronicle.REFUSE_NONE:
			return _fail(REFUSE_DIGEST_FAILED, "record %d: %s" % [_records, code])
		_digest = next
		_records += 1
		return true

	func _note_validity(record: PackedByteArray) -> void:
		"""Run the owner's record rules on one decoded record and keep the first refusal."""
		var fields: PackedInt64Array = PackedInt64Array()
		for at: int in [Chronicle.OFFSET_RESIDENT_ID, Chronicle.OFFSET_EVENT,
				Chronicle.OFFSET_OTHER_ID, Chronicle.OFFSET_DETAIL_KEY]:
			SaveCodec.read_i32_at(record, at, _scratch)
			fields.append(_scratch.value)
		SaveCodec.read_i64_at(record, Chronicle.OFFSET_TICK, _scratch)
		var code: StringName = Chronicle.record_refusal(fields[0], fields[1], _scratch.value,
			fields[2], fields[3])
		if code == Chronicle.REFUSE_NONE:
			return
		_invalid_code = SaveSectionChronicle.section_code_for(code)
		_invalid_detail = "record %d refused by the owner with %s" % [_records, code]

	func _fail(code: StringName, p_detail: String) -> bool:
		"""Record a sticky hard failure; always returns false."""
		_failure = code
		_failure_detail = p_detail
		return false


class Adapter:
	"""Section 13's canonical value adapter (ARCH-HASH-001) over a captured or decoded Record."""
	var _record: Record = null

	func _init(p_record: Record) -> void:
		"""Bind the Record whose two fields this adapter supplies."""
		_record = p_record

	func canonical_field_values(field_key: StringName, out: Digest.FieldValues) -> bool:
		"""`_count` as one u64 (logical i64 storage), `_rolling_digest` as 32 u8; nothing else."""
		if field_key == StringName(Chronicle.FIELD_KEYS[Chronicle.ORDINAL_COUNT]):
			return out.supply_int64(PackedInt64Array([_record.record_count]), 1)
		if field_key == StringName(Chronicle.FIELD_KEYS[Chronicle.ORDINAL_ROLLING_DIGEST]):
			return out.supply_bytes(_record.rolling_digest, Chronicle.DIGEST_BYTES)
		return out.refuse(REFUSE_ADAPTER_FIELD, "'chronicle' declares no field '%s'" % field_key)


# --- shape ---------------------------------------------------------------------------------------

static func section_bytes_for(record_count: int) -> int:
	"""`40 + 24*N`. The caller must already hold N in `0 .. MAX_RECORD_COUNT`."""
	return PREFIX_BYTES + RECORD_BYTES * record_count


static func section_code_for(owner_code: StringName) -> StringName:
	"""The SAVE_S13_* code for a `chronicle.gd` record refusal; unmapped ones are RECORD_REFUSED."""
	var index: int = OWNER_RECORD_CODES.find(owner_code)
	return REFUSE_RECORD_REFUSED if index < 0 else SECTION_RECORD_CODES[index]


static func record_refusal(record: Record) -> SaveHeader.Refusal:
	"""Rules a Record must meet on its own: non-null, count in range, 32-byte digest, empty=zero."""
	if record == null:
		return SaveHeader.Refusal.new(REFUSE_RECORD_NULL, "no Record supplied")
	if record.record_count < 0 or record.record_count > MAX_RECORD_COUNT:
		return SaveHeader.Refusal.new(REFUSE_COUNT_RANGE,
			"record_count %d is outside 0..%d" % [record.record_count, MAX_RECORD_COUNT])
	if record.rolling_digest.size() != Chronicle.DIGEST_BYTES:
		return SaveHeader.Refusal.new(REFUSE_DIGEST_LENGTH,
			"the rolling digest holds %d bytes, not 32" % record.rolling_digest.size())
	if record.record_count == 0 and not Chronicle.is_zero_digest(record.rolling_digest):
		return SaveHeader.Refusal.new(REFUSE_EMPTY_DIGEST,
			"an empty Chronicle's digest must be 32 zero bytes")
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


# --- capture and apply ---------------------------------------------------------------------------

static func capture_into(chronicle: Chronicle, out: Record) -> SaveHeader.Refusal:
	"""Read the live owner's count and digest into a caller-owned Record. `out` untouched on refusal."""
	if chronicle == null:
		return SaveHeader.Refusal.new(REFUSE_NULL_OWNER, "no Chronicle supplied")
	if out == null:
		return SaveHeader.Refusal.new(REFUSE_RECORD_NULL, "no Record supplied")
	var state: Chronicle.State = Chronicle.State.new()
	chronicle.copy_state_into(state)
	out.record_count = state.count
	out.rolling_digest = state.digest
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func apply(record: Record, chronicle: Chronicle) -> SaveHeader.Refusal:
	"""Publish a decoded Record into the owner, both fields or neither.

	The Record must come from `decode_section_into()`, which proved its digest against the saved
	records; apply cannot see records. The owner validates before writing, so a refusal leaves it
	byte-identical.
	"""
	if chronicle == null:
		return SaveHeader.Refusal.new(REFUSE_NULL_OWNER, "no Chronicle supplied")
	var invalid: SaveHeader.Refusal = record_refusal(record)
	if not invalid.is_ok():
		return invalid
	var code: StringName = chronicle.restore_state(record.record_count, record.rolling_digest)
	if code != Chronicle.REFUSE_NONE:
		return SaveHeader.Refusal.new(REFUSE_OWNER_REFUSED,
			"chronicle.restore_state refused with %s" % code)
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


# --- encode ----------------------------------------------------------------------------------------

static func encode_prefix(record: Record, out: EncodeResult) -> bool:
	"""The 40-byte prefix alone, for a writer that streams the records itself."""
	var invalid: SaveHeader.Refusal = record_refusal(record)
	if not invalid.is_ok():
		return out.refuse(invalid.code, invalid.detail)
	var writer: SaveCodec.Writer = SaveCodec.Writer.new(PREFIX_BYTES)
	writer.write_u64(record.record_count)
	writer.write_bytes(record.rolling_digest)
	if writer.failed():
		return out.refuse(REFUSE_ENCODE_FAILED, "%s: %s" % [writer.refusal(), writer.detail()])
	return out.succeed(writer.to_bytes())


static func encode_section(record: Record, history: PackedByteArray, out: EncodeResult) -> bool:
	"""Encode the whole section from a Record and its exact record bytes, verifying first.

	`history` must be exactly `24 * record_count` bytes and must stream to the Record's digest
	with every record valid -- the same verdict decode applies -- so a refused encode writes
	nothing. This in-memory form suits bounded histories; a file writer streams instead.
	"""
	if not encode_prefix(record, out):
		return false
	if history.size() != RECORD_BYTES * record.record_count:
		return out.refuse(REFUSE_HISTORY_LENGTH, "%d history bytes for %d records"
			% [history.size(), record.record_count])
	var verified: SaveHeader.Refusal = verify_history(history, 0, record.record_count,
		record.rolling_digest)
	if not verified.is_ok():
		return out.refuse(verified.code, verified.detail)
	var bytes: PackedByteArray = out.bytes
	bytes.append_array(history)
	return out.succeed(bytes)


# --- decode ----------------------------------------------------------------------------------------

static func decode_section_into(bytes: PackedByteArray, offset: int, length: int,
		out: Record) -> SaveHeader.Refusal:
	"""Decode and fully verify section 13 at `[offset, offset+length)`. `out` untouched on refusal.

	Order: extent, count range, exact length, empty-digest rule, then the streamed digest and
	record verdict. Only a section that passes all of them is copied into `out`.
	"""
	if out == null:
		return SaveHeader.Refusal.new(REFUSE_RECORD_NULL, "no Record supplied")
	var extent: SaveHeader.Refusal = extent_refusal(bytes, offset, length)
	if not extent.is_ok():
		return extent
	var parsed: Record = Record.new()
	var prefix: SaveHeader.Refusal = _read_prefix(bytes, offset, length, parsed)
	if not prefix.is_ok():
		return prefix
	var verified: SaveHeader.Refusal = verify_history(bytes, offset + RECORDS_OFFSET,
		parsed.record_count, parsed.rolling_digest)
	if not verified.is_ok():
		return verified
	out.copy_from(parsed)
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func extent_refusal(bytes: PackedByteArray, offset: int, length: int) -> SaveHeader.Refusal:
	"""Prove `length >= 40` bytes are readable at `offset` without overflowing the addition."""
	if offset < 0:
		return SaveHeader.Refusal.new(REFUSE_NEGATIVE_OFFSET, "offset %d is negative" % offset)
	if length < PREFIX_BYTES:
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED,
			"section 13 needs at least %d bytes, the descriptor gives %d" % [PREFIX_BYTES, length])
	if bytes.size() < length or offset > bytes.size() - length:
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, "%d bytes at offset %d exceed a %d-byte buffer"
			% [length, offset, bytes.size()])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _read_prefix(bytes: PackedByteArray, offset: int, length: int,
		parsed: Record) -> SaveHeader.Refusal:
	"""Read and check the count and digest against the already-proved extent."""
	var scalar: SaveCodec.Scalar = SaveCodec.Scalar.new()
	if not SaveCodec.read_u64_at(bytes, offset + COUNT_OFFSET, scalar):
		return SaveHeader.Refusal.new(REFUSE_COUNT_RANGE, "%s: %s" % [scalar.refusal, scalar.detail])
	if scalar.value > MAX_RECORD_COUNT:
		return SaveHeader.Refusal.new(REFUSE_COUNT_RANGE,
			"record_count %d exceeds %d" % [scalar.value, MAX_RECORD_COUNT])
	if length != section_bytes_for(scalar.value):
		return SaveHeader.Refusal.new(REFUSE_LENGTH, "%d records need %d bytes, the section has %d"
			% [scalar.value, section_bytes_for(scalar.value), length])
	parsed.record_count = scalar.value
	parsed.rolling_digest = bytes.slice(offset + DIGEST_OFFSET, offset + RECORDS_OFFSET)
	return record_refusal(parsed)


static func verify_history(bytes: PackedByteArray, start: int, record_count: int,
		declared: PackedByteArray) -> SaveHeader.Refusal:
	"""Stream `record_count` records from `start` through a DigestVerifier, CHUNK_RECORDS at a time.

	Never slices more than CHUNK_BYTES at once. The caller has proved the extent.
	"""
	var verifier: DigestVerifier = DigestVerifier.new()
	var cursor: int = start
	var remaining: int = record_count
	while remaining > 0:
		var take: int = mini(remaining, CHUNK_RECORDS)
		if not verifier.feed(bytes.slice(cursor, cursor + take * RECORD_BYTES)):
			break
		cursor += take * RECORD_BYTES
		remaining -= take
	return verifier.verdict(declared)


# --- cross-checks ----------------------------------------------------------------------------------

static func header_count_refusal(header: SaveHeader.Header, record: Record) -> SaveHeader.Refusal:
	"""The header's chronicle count (offset 208) must equal section 13's record_count."""
	if header == null:
		return SaveHeader.Refusal.new(REFUSE_NULL_HEADER, "no Header supplied")
	if record == null:
		return SaveHeader.Refusal.new(REFUSE_RECORD_NULL, "no Record supplied")
	if header.chronicle_record_count != record.record_count:
		return SaveHeader.Refusal.new(REFUSE_HEADER_COUNT, "header offset 208 says %d, section 13 says %d"
			% [header.chronicle_record_count, record.record_count])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func descriptor_refusal(descriptor: SaveHeader.Descriptor,
		record: Record) -> SaveHeader.Refusal:
	"""The descriptor names section 13 at schema 1, with row_count N and byte_length 40 + 24*N."""
	var invalid: SaveHeader.Refusal = record_refusal(record)
	if not invalid.is_ok():
		return invalid
	if descriptor == null or descriptor.section_id != SECTION_ID:
		return SaveHeader.Refusal.new(REFUSE_SECTION_ID, "the descriptor is not section 13's")
	if descriptor.schema_version != SECTION_SCHEMA_VERSION:
		return SaveHeader.Refusal.new(REFUSE_SECTION_SCHEMA,
			"section 13 schema %d, not %d" % [descriptor.schema_version, SECTION_SCHEMA_VERSION])
	if descriptor.row_count != record.record_count:
		return SaveHeader.Refusal.new(REFUSE_ROW_COUNT, "descriptor row_count %d, section says %d"
			% [descriptor.row_count, record.record_count])
	if descriptor.byte_length != section_bytes_for(record.record_count):
		return SaveHeader.Refusal.new(REFUSE_LENGTH, "descriptor byte_length %d, expected %d"
			% [descriptor.byte_length, section_bytes_for(record.record_count)])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


# --- ARCH-HASH-001 ---------------------------------------------------------------------------------

static func register_adapter(walker: Digest.Walker, record: Record) -> Digest.Refusal:
	"""Register section 13's `chronicle` owner adapter over `record` on `walker`."""
	if record == null:
		return Digest.Refusal.new(REFUSE_RECORD_NULL, "no Record supplied")
	return walker.register_owner(SECTION_ID, Chronicle.OWNER_KEY, Adapter.new(record))
