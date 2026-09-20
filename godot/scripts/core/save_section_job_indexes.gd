extends "res://scripts/core/job_index_schema.gd"
## Schema2 section8 byte codec. Shared layout/Record/validation remain public by inheritance.
## SAVE-J2-R02 connects exact owner snapshots; whole-world save remains incomplete.
const JobPlannerScript := preload("res://scripts/core/job_planner.gd")
const SimClockScript := preload("res://scripts/core/sim_clock.gd")
const REFUSE_NULL_STORE: StringName = &"SAVE_JOB_NULL_STORE"
const REFUSE_NULL_CLOCK: StringName = &"SAVE_JOB_NULL_CLOCK"
const REFUSE_BARRIER_NOT_HELD: StringName = &"SAVE_JOB_BARRIER_NOT_HELD"

class EncodeResult:
	"""Outcome of materialising bytes: the buffer, or a refusal and no bytes."""
	var ok: bool = false
	var bytes: PackedByteArray = PackedByteArray()
	var refusal: StringName = REFUSE_NONE
	var detail: String = ""

	func succeed(p_bytes: PackedByteArray) -> bool:
		"""Record the encoded bytes; always returns true."""
		ok = true
		bytes = p_bytes
		refusal = REFUSE_NONE
		detail = ""
		return true

	func refuse(p_refusal: StringName, p_detail: String) -> bool:
		"""Record a refusal with an empty buffer; always returns false."""
		ok = false
		bytes = PackedByteArray()
		refusal = p_refusal
		detail = p_detail
		return false


# --- layout arithmetic ----------------------------------------------------------------------------

static func byte_order_refusal() -> SaveHeader.Refusal:
	"""Prove `Packed*Array.to_byte_array()` is little-endian on this build, for BOTH widths.

	The bulk conversions in `Record.column_bytes()` and `Record.assign_column()` are C++ memory
	copies, not `save_codec.gd` writes, so they inherit the host's byte order instead of the
	codec's explicit little-endian. Every Godot target is little-endian, but an assumption that is
	never checked is how a save written on one machine silently transposes every generation on
	another. Section 8 carries i64 columns as well as i32 ones, so both are probed.
	"""
	var word: PackedByteArray = PackedInt32Array([BYTE_ORDER_PROBE]).to_byte_array()
	var invalid: SaveHeader.Refusal = _probe_refusal(word, SaveCodec.I32_BYTES)
	if not invalid.is_ok():
		return invalid
	var long: PackedByteArray = PackedInt64Array([BYTE_ORDER_PROBE]).to_byte_array()
	return _probe_refusal(long, SaveCodec.I64_BYTES)


static func _probe_refusal(probe: PackedByteArray, width: int) -> SaveHeader.Refusal:
	"""Check one converted sentinel byte by byte against its little-endian reading."""
	if probe.size() != width:
		return SaveHeader.Refusal.new(REFUSE_BYTE_ORDER,
			"a %d-byte value converted to %d bytes" % [width, probe.size()])
	for index: int in width:
		var expected: int = (BYTE_ORDER_PROBE >> (index * 8)) & SaveCodec.UINT8_MAX
		if probe[index] != expected:
			return SaveHeader.Refusal.new(REFUSE_BYTE_ORDER,
				"byte %d of the sentinel is %d, not the little-endian %d"
					% [index, probe[index], expected])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func field_width(field: int) -> int:
	"""Element width of one field, recomputed from its canonical type code."""
	if FIELD_TYPES[field] == CANONICAL_TYPE_U8:
		return SaveCodec.U8_BYTES
	if FIELD_TYPES[field] == CANONICAL_TYPE_I32:
		return SaveCodec.I32_BYTES
	return SaveCodec.I64_BYTES


static func storage_index_of(field: int) -> int:
	"""Recompute one field's index within its type group, so FIELD_STORAGE cannot drift."""
	var index: int = 0
	for earlier: int in field:
		if FIELD_TYPES[earlier] == FIELD_TYPES[field]:
			index += 1
	return index


static func canonical_value_bytes() -> int:
	"""Total VALUE bytes of all 35 columns: the section's ARCH-HASH-001 contribution length."""
	var total: int = 0
	for field: int in FIELD_COUNT:
		total += FIELD_WIDTHS[field] * FIELD_EXTENTS[field]
	return total


static func payload_bytes() -> int:
	"""Total payload length: 35 element counts plus every column's values."""
	return FIELD_COUNT * ELEMENT_COUNT_BYTES + canonical_value_bytes()


static func field_count_offset(field: int) -> int:
	"""Byte offset, from the start of the section, of one field's `element_count:u64`."""
	var offset: int = FRAMING_BYTES
	for earlier: int in field:
		offset += ELEMENT_COUNT_BYTES + FIELD_WIDTHS[earlier] * FIELD_EXTENTS[earlier]
	return offset


static func field_value_offset(field: int) -> int:
	"""Byte offset, from the start of the section, of one field's first value."""
	return field_count_offset(field) + ELEMENT_COUNT_BYTES


static func canonical_type_of(field: int) -> int:
	"""SAVE-R09's type code for one field: 0 for u8, 2 for i32, 4 for i64."""
	return FIELD_TYPES[field]


static func descriptor_row_count() -> int:
	"""The 64-byte descriptor's `row_count` for section 8: the one block's designated primary.

	SAVE-LAYOUT-R01 makes a multi-block section's descriptor row count "the checked sum of block
	primary_count values". Section 8 holds exactly ONE block, so that sum has one term and the
	descriptor is PRIMARY_COUNT. It takes no argument, because SAVE-C3-R01 gives a caller nothing
	to choose; section 9's `descriptor_row_count()` has the same shape for the same reason.
	"""
	return PRIMARY_COUNT


static func primary_count_refusal(primary_count: int) -> SaveHeader.Refusal:
	"""Refuse any `primary_count` but SAVE-C3-R01's designated pending-service extent.

	SAVE-C3-R01: "Writer and decoder must validate against the compiled constant rather than a
	caller-supplied positive number." A positive-and-representable check is NOT enough -- 4096,
	5248 and 14080 are all positive, all representable, and all wrong -- so the comparison is
	against PRIMARY_COUNT itself and the detail names why the plausible alternatives are not it.
	"""
	if primary_count == PRIMARY_COUNT:
		return SaveHeader.Refusal.new(REFUSE_NONE, "")
	return SaveHeader.Refusal.new(REFUSE_PRIMARY_COUNT,
		("primary_count %d is not section 8's designated %d pending-service rows. SAVE-C3-R01 "
			+ "designates one primary TABLE per owner block; it is not a sum (%d over all five "
			+ "extents, %d over the three owner capacities), not the secondary %d-row per-plot "
			+ "cycle table, and not the retired 7-row fixture.")
			% [primary_count, PRIMARY_COUNT, SERVICE_ROWS + OWNER_ROWS + ZONE_ROWS + DEMAND_ROWS
				+ HIVE_ROWS, OWNER_ROWS + ZONE_ROWS + HIVE_ROWS, OWNER_ROWS])


static func production_write_refusal() -> SaveHeader.Refusal:
	"""Section8 has its owner API; this grants no other section or full-world readiness."""
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func section_length_refusal(byte_length: int) -> SaveHeader.Refusal:
	"""Check a descriptor's declared section length against this schema's fixed size.

	SAVE-R09-004 requires exact block consumption and no trailing bytes; section 8 has one fixed
	length, so a descriptor that disagrees is wrong before a single payload byte is read.
	"""
	if byte_length != SECTION_BYTES:
		return SaveHeader.Refusal.new(REFUSE_LENGTH,
			"section 8 declares %d bytes, not the fixed %d" % [byte_length, SECTION_BYTES])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


# --- capture --------------------------------------------------------------------------------------

static func capture_record_into(staged: Record, out: Record) -> SaveHeader.Refusal:
	"""Validate source and destination before atomically publishing independent copies."""
	var invalid: SaveHeader.Refusal = record_refusal(staged)
	if not invalid.is_ok():
		return invalid
	var shape: SaveHeader.Refusal = shape_refusal(out)
	if not shape.is_ok():
		return shape
	out.copy_from(staged)
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func capture_into(store: JobPlannerScript, out: Record) -> SaveHeader.Refusal:
	"""Read the real planner through its exact owner API at a caller-owned completed boundary."""
	if store == null:
		return SaveHeader.Refusal.new(REFUSE_NULL_STORE, "no planner supplied")
	var shape: SaveHeader.Refusal = shape_refusal(out)
	if not shape.is_ok():
		return shape
	if not store.copy_job_index_columns_into(out):
		return SaveHeader.Refusal.new(store.last_column_refusal(), "planner capture refused")
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func apply(record: Record, store: JobPlannerScript,
		clock: SimClockScript = null) -> SaveHeader.Refusal:
	"""Install exact planner columns under the supplied world's held load barrier.

	The caller owns clock/world association and prerequisite owner restore order. No
	barrier is acquired or released here, and no pending stale reference is repaired.
	Read the returned Refusal: codec-stage failures do not replace the owner diagnostic.
	"""
	if record == null:
		return SaveHeader.Refusal.new(REFUSE_RECORD_SHAPE, "no planner record")
	if store == null:
		return SaveHeader.Refusal.new(REFUSE_NULL_STORE, "no planner supplied")
	if clock == null:
		return SaveHeader.Refusal.new(REFUSE_NULL_CLOCK, "no world clock supplied")
	if not clock.is_load_barrier_held():
		return SaveHeader.Refusal.new(REFUSE_BARRIER_NOT_HELD, "load barrier is not held")
	var invalid: SaveHeader.Refusal = record_refusal(record)
	if not invalid.is_ok():
		return invalid
	if not store.restore_job_index_columns(record):
		return SaveHeader.Refusal.new(store.last_column_refusal(), "planner restore refused")
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


# --- encode ---------------------------------------------------------------------------


static func encode_payload(record: Record, out: EncodeResult) -> bool:
	"""Materialise the 384164-byte payload: 35 `element_count:u64` prefixes and their columns.

	Column-major by SAVE-LAYOUT-R01 and in REG-R01's declared ordinal order. Each column is
	appended as one C++ byte-array copy; nothing here walks values one at a time.
	"""
	var invalid: SaveHeader.Refusal = record_refusal(record)
	if not invalid.is_ok():
		return out.refuse(invalid.code, invalid.detail)
	var buffer: PackedByteArray = PackedByteArray()
	for field: int in FIELD_COUNT:
		var writer: SaveCodec.Writer = SaveCodec.Writer.new(ELEMENT_COUNT_BYTES)
		writer.write_u64(FIELD_EXTENTS[field])
		if writer.failed():
			return out.refuse(REFUSE_ENCODE_FAILED, "%s: %s" % [writer.refusal(), writer.detail()])
		buffer.append_array(writer.to_bytes())
		buffer.append_array(record.column_bytes(field))
	if buffer.size() != PAYLOAD_BYTES:
		return out.refuse(REFUSE_LENGTH,
			"payload encoded %d bytes, not the fixed %d" % [buffer.size(), PAYLOAD_BYTES])
	return out.succeed(buffer)


static func encode_section(record: Record, out: EncodeResult) -> bool:
	"""Materialise a whole section 8: the 39-byte owner wrapper, then the payload.

	The wrapper's `primary_count` is PRIMARY_COUNT and a caller cannot supply another, per
	SAVE-C3-R01. There is deliberately NO `primary_count_refusal(PRIMARY_COUNT)` call here: against
	a compiled constant it could never refuse, and a guard that cannot fire is a guard a mutation
	test cannot kill. A PRIMARY_COUNT outside the u64 domain fails in `writer.write_u64()` instead.
	The `payload_byte_length` field is the ACTUAL encoded body length, measured from the bytes this
	call produced, so the wrapper cannot claim a length the body does not have.
	"""
	var order: SaveHeader.Refusal = byte_order_refusal()
	if not order.is_ok():
		return out.refuse(order.code, order.detail)
	var payload: EncodeResult = EncodeResult.new()
	if not encode_payload(record, payload):
		return out.refuse(payload.refusal, payload.detail)
	var writer: SaveCodec.Writer = SaveCodec.Writer.new(FRAMING_BYTES)
	writer.write_u32(STORE_COUNT)
	writer.write_utf8_u32(OWNER_KEY, OWNER_KEY_MAX_BYTES)
	writer.write_u32(OWNER_SCHEMA_VERSION)
	writer.write_u64(PRIMARY_COUNT)
	writer.write_u64(payload.bytes.size())
	if writer.failed():
		return out.refuse(REFUSE_ENCODE_FAILED, "%s: %s" % [writer.refusal(), writer.detail()])
	var buffer: PackedByteArray = writer.to_bytes()
	buffer.append_array(payload.bytes)
	if buffer.size() != SECTION_BYTES:
		return out.refuse(REFUSE_LENGTH,
			"section 8 encoded %d bytes, not the fixed %d" % [buffer.size(), SECTION_BYTES])
	return out.succeed(buffer)


static func canonical_bytes_of(record: Record, out: EncodeResult) -> bool:
	"""This section's contribution to ARCH-HASH-001: 35 columns of VALUES and nothing else.

	Every section-8 field carries `hash: true` in REG-R01's artifact, so no column is saved-but-
	not-hashed the way section 1's host debt is. What the digest does NOT include is framing: the
	store count, the owner wrapper and the 35 `element_count` prefixes are wire shape, not state.
	SAVE-R09's canonical record is `section_id, owner_key, field_key, type, value_count, values`
	and this produces exactly the `values` half of all 35; section 15 owns the record prefixes,
	the concatenation order and the final SHA-256, and none of those is decided here.
	"""
	var invalid: SaveHeader.Refusal = record_refusal(record)
	if not invalid.is_ok():
		return out.refuse(invalid.code, invalid.detail)
	var buffer: PackedByteArray = PackedByteArray()
	for field: int in FIELD_COUNT:
		buffer.append_array(record.column_bytes(field))
	if buffer.size() != CANONICAL_VALUE_BYTES:
		return out.refuse(REFUSE_LENGTH,
			"canonical values are %d bytes, not %d" % [buffer.size(), CANONICAL_VALUE_BYTES])
	return out.succeed(buffer)


# --- decode ----------------------------------------------------------------------------------------

static func decode_section_into(bytes: PackedByteArray, offset: int,
		out: Record) -> SaveHeader.Refusal:
	"""Decode a known current-schema body; full-file callers must pass their actual descriptor."""
	return decode_section_with_schema_into(bytes, offset, SECTION_SCHEMA_VERSION, out)


static func decode_section_with_schema_into(bytes: PackedByteArray, offset: int,
		section_schema_version: int, out: Record) -> SaveHeader.Refusal:
	"""Check readable owner/version preamble before extent; stage and validate before publication."""
	var preamble: SaveHeader.Refusal = _preamble_refusal(bytes, offset, section_schema_version)
	if not preamble.is_ok():
		return preamble
	var extent: SaveHeader.Refusal = extent_refusal(bytes, offset)
	if not extent.is_ok():
		return extent
	var order: SaveHeader.Refusal = byte_order_refusal()
	if not order.is_ok():
		return order
	var reader: SaveCodec.Reader = SaveCodec.Reader.new(bytes)
	if not reader.seek(offset):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, reader.detail())
	var framing: SaveHeader.Refusal = _read_framing(reader)
	if not framing.is_ok():
		return framing
	return _decode_columns_into(bytes, reader, out)


static func _preamble_refusal(bytes: PackedByteArray, offset: int,
		section_schema_version: int) -> SaveHeader.Refusal:
	"""Never allocate a Record or require a new-schema extent to identify an older owner."""
	if offset < 0:
		return SaveHeader.Refusal.new(REFUSE_NEGATIVE_OFFSET, "negative section offset")
	if offset > bytes.size() or bytes.size() - offset < PREAMBLE_BYTES:
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, "section8 preamble requires23 bytes")
	if bytes.decode_u32(offset) != STORE_COUNT:
		return SaveHeader.Refusal.new(REFUSE_STORE_COUNT, "section8 requires one owner")
	if bytes.decode_u32(offset + OFFSET_OWNER_KEY_LENGTH) != OWNER_KEY_BYTES:
		return SaveHeader.Refusal.new(REFUSE_OWNER_KEY, "owner key length differs")
	if bytes.slice(offset + OFFSET_OWNER_KEY, offset + OFFSET_OWNER_SCHEMA_VERSION) != OWNER_KEY.to_utf8_buffer():
		return SaveHeader.Refusal.new(REFUSE_OWNER_KEY, "owner key differs")
	if bytes.decode_u32(offset + OFFSET_OWNER_SCHEMA_VERSION) != OWNER_SCHEMA_VERSION:
		return SaveHeader.Refusal.new(REFUSE_OWNER_SCHEMA_VERSION, "requires planner owner schema2")
	if section_schema_version != SECTION_SCHEMA_VERSION:
		return SaveHeader.Refusal.new(REFUSE_SECTION_SCHEMA_VERSION, "requires section8 schema2")
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _decode_columns_into(bytes: PackedByteArray, reader: SaveCodec.Reader,
		out: Record) -> SaveHeader.Refusal:
	"""Read the 35 columns into a LOCAL Record, validate it, and only then publish it to `out`."""
	var parsed: Record = Record.new()
	var columns: SaveHeader.Refusal = _read_columns(bytes, reader, parsed)
	if not columns.is_ok():
		return columns
	var invalid: SaveHeader.Refusal = record_refusal(parsed)
	if not invalid.is_ok():
		return invalid
	var shape: SaveHeader.Refusal = shape_refusal(out)
	if not shape.is_ok():
		return shape
	out.copy_from(parsed)
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func extent_refusal(bytes: PackedByteArray, offset: int) -> SaveHeader.Refusal:
	"""Prove `SECTION_BYTES` are readable at `offset` without overflowing the addition.

	Public because it is the PRIMARY gate and must be testable on its own, exactly as
	`save_section_directory.gd::extent_refusal()` is: the Reader is bounded too, so a slack extent
	check would still end in a refusal and hide. A load orchestrator can also ask before committing.
	"""
	if offset < 0:
		return SaveHeader.Refusal.new(REFUSE_NEGATIVE_OFFSET, "offset %d is negative" % offset)
	if bytes.size() < SECTION_BYTES or offset > bytes.size() - SECTION_BYTES:
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED,
			"section 8 needs %d bytes at offset %d, buffer holds %d"
				% [SECTION_BYTES, offset, bytes.size()])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _read_framing(reader: SaveCodec.Reader) -> SaveHeader.Refusal:
	"""Read and check the 39-byte block header: store count, owner, schema, counts, length."""
	var scalar: SaveCodec.Scalar = SaveCodec.Scalar.new()
	if not reader.read_u32_into(scalar):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, reader.detail())
	if scalar.value != STORE_COUNT:
		return SaveHeader.Refusal.new(REFUSE_STORE_COUNT,
			"section 8 declares %d stores, not %d" % [scalar.value, STORE_COUNT])
	var owner: SaveHeader.Refusal = _read_owner(reader)
	if not owner.is_ok():
		return owner
	if not reader.read_u64_into(scalar):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, reader.detail())
	var count: SaveHeader.Refusal = primary_count_refusal(scalar.value)
	if not count.is_ok():
		return count
	if not reader.read_u64_into(scalar):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, reader.detail())
	if scalar.value != PAYLOAD_BYTES:
		return SaveHeader.Refusal.new(REFUSE_PAYLOAD_LENGTH,
			"payload_byte_length %d is not the fixed %d" % [scalar.value, PAYLOAD_BYTES])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _read_owner(reader: SaveCodec.Reader) -> SaveHeader.Refusal:
	"""Read the owner key and its schema version, refusing any owner but this one."""
	var text: SaveCodec.Text = SaveCodec.Text.new()
	if not reader.read_utf8_u32_into(OWNER_KEY_MAX_BYTES, text):
		return SaveHeader.Refusal.new(REFUSE_OWNER_KEY, text.detail)
	if text.value != OWNER_KEY:
		return SaveHeader.Refusal.new(REFUSE_OWNER_KEY,
			"section 8 block is owned by '%s', not '%s'" % [text.value, OWNER_KEY])
	var scalar: SaveCodec.Scalar = SaveCodec.Scalar.new()
	if not reader.read_u32_into(scalar):
		return SaveHeader.Refusal.new(REFUSE_TRUNCATED, reader.detail())
	if scalar.value != OWNER_SCHEMA_VERSION:
		return SaveHeader.Refusal.new(REFUSE_OWNER_SCHEMA_VERSION,
			"owner schema %d is not the supported %d" % [scalar.value, OWNER_SCHEMA_VERSION])
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _read_columns(bytes: PackedByteArray, reader: SaveCodec.Reader,
		parsed: Record) -> SaveHeader.Refusal:
	"""Read all 35 `element_count` prefixes and their value runs into `parsed`.

	Each prefix is checked against the OWNING SCHEMA'S extent for that field, never against the
	first column's or against whatever the previous prefix said.
	"""
	var scalar: SaveCodec.Scalar = SaveCodec.Scalar.new()
	for field: int in FIELD_COUNT:
		if not reader.read_u64_into(scalar):
			return SaveHeader.Refusal.new(REFUSE_TRUNCATED, reader.detail())
		if scalar.value != FIELD_EXTENTS[field]:
			return SaveHeader.Refusal.new(REFUSE_ELEMENT_COUNT,
				"field %d (%s) declares %d elements, not the schema's %d"
					% [field, FIELD_KEYS[field], scalar.value, FIELD_EXTENTS[field]])
		var start: int = reader.position()
		var end: int = start + FIELD_WIDTHS[field] * FIELD_EXTENTS[field]
		parsed.assign_column(field, bytes.slice(start, end))
		if not reader.seek(end):
			return SaveHeader.Refusal.new(REFUSE_TRUNCATED, reader.detail())
	return SaveHeader.Refusal.new(REFUSE_NONE, "")
