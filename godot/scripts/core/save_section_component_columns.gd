extends RefCounted
## ARCH-SAVE-002 section 4 COMPONENT_COLUMNS: the bounded streaming envelope for its first
## implemented body, schema 2 (SAVE-S4-STREAM-R01 v2, ADR 0169).
##
## WHAT THIS MODULE IS. One owner block at a time, in ASCII key order, over the compiled metadata
## in `save_component_columns_schema.gd`. The wire format is that contract's, quoted not invented:
##
##     section = store_count:u32=18, owner blocks in ASCII order
##     owner   = key:utf8-u32, owner_schema_version:u32, primary_count:u64,
##               payload_length:u64, payload
##     payload = child_extent_count:u32, child_extents:u64[],
##               for each field: element_count:u64, values in LE declared signedness
##
## Fragment boundaries are exact and identical on both sides: the 4-byte store count; each owner
## wrapper INCLUDING its child header and child extents as ONE fragment (53 bytes for Buildings,
## the largest wrapper); each field's 8-byte element_count; then whole-element value fragments of
## at most 65536 bytes that never cross a field. There is deliberately NO whole-column, whole-owner
## or whole-section concatenation helper in this production encoder.
##
## WHAT IT DOES NOT DO, AND WHO OWNS THAT. Receiving a framed owner is NOT approval to install it
## into a live store. SAVE-S4-CODEC still requires 18 semantic validators, the missing bulk owner
## APIs and exact capture/apply adapters; the coupled owner sections listed in the contract must
## restore atomically. Nothing here validates gameplay meaning, occupancy, blanks or cross-section
## agreement; nothing here touches a live owner module, a clock, a barrier, a signal or the disk;
## nothing here computes or checks a section CRC, the body digest or the canonical state hash.
## Outer section range/EOF validation and file transactions belong to the coordinator.
##
## CONSTRUCTOR ZEROS ARE ARBITRARY REPRESENTABLE WIRE DATA, NOT SEMANTIC DEFAULTS. There is
## deliberately no assignment bitmap, so this layer cannot detect an ignored setter failure or an
## omitted capture field. Future capture adapters must propagate every failure, populate every
## canonical field and prove full coverage; frame acceptance cannot authorize publishing zero
## substitutes.
##
## SIGNEDNESS AND ARBITRARY u8. Every i32/i64 value round-trips as full-width two's complement
## through `to_byte_array()` / `to_int32_array()` / `to_int64_array()`, and every u8 column carries
## arbitrary bytes. Nothing here clamps, normalises or reinterprets a value; the only
## reinterpretation is the declared little-endian packing, which the host-order probe guards.
##
## HOST BYTE ORDER. The bulk packed conversions are C++ memory copies and inherit the host's byte
## order rather than `save_codec.gd`'s explicit little-endian writes. `byte_order_refusal()` is the
## local four-byte probe -- the same packed-conversion pattern the Directory section uses -- mapped
## to SAVE_COMPONENT_BYTE_ORDER. Both cursors run it in their constructor preflight, so every bulk
## conversion below happens after it. The Directory module is NOT preloaded. A source-level test
## may pin this pattern; passing it on a little-endian host is not evidence about a big-endian one.
##
## MEMORY AND OWNERSHIP (conditional, not measured). The decoder holds AT MOST ONE private owner
## and enforces take-before-next-input. The production caller MUST persist and release an owner,
## INCLUDING clearing any OwnerResult reference, BEFORE feeding the next owner's wrapper; the
## decoder cannot revoke an externally held record, and the adjacent Buildings+Construction pair is
## an explicitly excluded misuse case rather than hidden headroom. The contract's conservative
## bound is 6417408 bytes: Construction's 4893696 owner value bytes, three 65536-byte
## input/conversion windows, and two copies of the single largest field (2 * 663552). This file
## stays inside that by (a) releasing a column's bucket slot BEFORE the replacement is built, so no
## old-column reference is retained while a new one is allocated, and (b) keeping exactly one
## field's raw staging buffer alive at a time, whose peak beside its converted column is two copies
## of that field. Immutable metadata and native overhead are accounted separately, and the
## allowance is arithmetic, not a measured resident set.
##
## STICKY REFUSALS. Each cursor is single-use with no reset. The first error is kept verbatim and
## every later operation returns it without progress, emitting no accepted bytes and publishing no
## record. Refused output wrappers clear their bytes or record; successful ones clear diagnostics.
##
## NO FLOAT. ARCH-AUTH-002: there is no float in this file and there must never be one.

## Self-preload, so the inner cursor classes can reach this script's own static functions. An inner
## class resolves the outer script's CONSTANTS but not its functions -- the same workaround
## `save_codec.gd` and `save_section_directory.gd` already carry.
const SaveSectionComponentColumnsScript := preload(
	"res://scripts/core/save_section_component_columns.gd")
const Schema := preload("res://scripts/core/save_component_columns_schema.gd")
const SaveCodec := preload("res://scripts/core/save_codec.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")

## ARCH-SAVE-002's section order: "1 WORLD, 2 CATALOG_IDS, 3 ENTITY_DIRECTORY, 4 COMPONENT_COLUMNS".
const SECTION_ID: int = 4

## SAVE-LAYOUT-R01's owner-key bound, reused for the length-prefixed key in each wrapper.
const OWNER_KEY_MAX_BYTES: int = 256

## The little-endian probe constant, shared with `save_header.gd`'s endian sentinel. 0x01020304.
const BYTE_ORDER_PROBE: int = SaveHeader.ENDIAN_SENTINEL

# --- refusal codes ------------------------------------------------------------------------------

const REFUSE_NONE: StringName = SaveHeader.REFUSE_NONE
const REFUSE_SCHEMA: StringName = &"SAVE_COMPONENT_SCHEMA"
const REFUSE_DESCRIPTOR: StringName = &"SAVE_COMPONENT_DESCRIPTOR"
const REFUSE_LENGTH: StringName = &"SAVE_COMPONENT_LENGTH"
const REFUSE_METADATA: StringName = &"SAVE_COMPONENT_METADATA"
const REFUSE_OWNER: StringName = &"SAVE_COMPONENT_OWNER"
const REFUSE_SHAPE: StringName = &"SAVE_COMPONENT_SHAPE"
const REFUSE_FRAME: StringName = &"SAVE_COMPONENT_FRAME"
const REFUSE_CHUNK: StringName = &"SAVE_COMPONENT_CHUNK"
const REFUSE_STATE: StringName = &"SAVE_COMPONENT_STATE"
const REFUSE_TRUNCATED: StringName = &"SAVE_COMPONENT_TRUNCATED"
const REFUSE_BYTE_ORDER: StringName = &"SAVE_COMPONENT_BYTE_ORDER"


class FramedOwner:
	"""One owner block's typed packed columns, allocated at exactly the declared extents.

	The three buckets are ordered by ASCENDING OWNER-LOCAL FIELD ORDINAL within their type, which
	is exactly `Schema.storage_index()`. `owner` is -1 with no arrays when the index is not a
	section 4 owner, or when a field declares a type this body does not contain.

	The constructor zeros are arbitrary representable wire data, NOT semantic defaults: a resident
	or plot row of zeros is a legal frame and says nothing about whether a capture adapter ever
	wrote it.
	"""
	var owner: int = -1
	var u8_columns: Array[PackedByteArray] = []
	var i32_columns: Array[PackedInt32Array] = []
	var i64_columns: Array[PackedInt64Array] = []

	func _init(p_owner: int) -> void:
		"""Allocate this owner's exact typed columns, or leave an empty record with owner -1."""
		if not Schema.owner_valid(p_owner):
			return
		for field: int in Schema.field_count(p_owner):
			if Schema.field_width(p_owner, field) == 0:
				u8_columns.clear()
				i32_columns.clear()
				i64_columns.clear()
				return
			_allocate_column(p_owner, field)
		owner = p_owner

	func _allocate_column(p_owner: int, field: int) -> void:
		"""Append one zeroed column of the declared type and exact element count."""
		var count: int = Schema.element_count(p_owner, field)
		var code: int = Schema.field_type(p_owner, field)
		if code == Schema.TYPE_U8:
			var u8: PackedByteArray = PackedByteArray()
			u8.resize(count)
			u8_columns.append(u8)
			return
		if code == Schema.TYPE_I32:
			var i32: PackedInt32Array = PackedInt32Array()
			i32.resize(count)
			i32_columns.append(i32)
			return
		var i64: PackedInt64Array = PackedInt64Array()
		i64.resize(count)
		i64_columns.append(i64)

	func u8_column(field: int) -> PackedByteArray:
		"""The stored u8 column at this owner-local ordinal, not duplicated; empty when invalid."""
		if not Schema.field_valid(owner, field) \
				or Schema.field_type(owner, field) != Schema.TYPE_U8:
			return PackedByteArray()
		var index: int = Schema.storage_index(owner, field)
		if index >= u8_columns.size():
			return PackedByteArray()
		return u8_columns[index]

	func i32_column(field: int) -> PackedInt32Array:
		"""The stored i32 column at this owner-local ordinal, not duplicated; empty when invalid."""
		if not Schema.field_valid(owner, field) \
				or Schema.field_type(owner, field) != Schema.TYPE_I32:
			return PackedInt32Array()
		var index: int = Schema.storage_index(owner, field)
		if index >= i32_columns.size():
			return PackedInt32Array()
		return i32_columns[index]

	func i64_column(field: int) -> PackedInt64Array:
		"""The stored i64 column at this owner-local ordinal, not duplicated; empty when invalid."""
		if not Schema.field_valid(owner, field) \
				or Schema.field_type(owner, field) != Schema.TYPE_I64:
			return PackedInt64Array()
		var index: int = Schema.storage_index(owner, field)
		if index >= i64_columns.size():
			return PackedInt64Array()
		return i64_columns[index]

	func set_u8(field: int, values: PackedByteArray) -> bool:
		"""Replace one u8 column after checking ordinal, type and exact extent. Refusal changes nothing."""
		var index: int = _writable_index(field, Schema.TYPE_U8, values.size())
		if index < 0 or index >= u8_columns.size():
			return false
		u8_columns[index] = PackedByteArray()
		u8_columns[index] = values.duplicate()
		return true

	func set_i32(field: int, values: PackedInt32Array) -> bool:
		"""Replace one i32 column after checking ordinal, type and exact extent. Refusal changes nothing."""
		var index: int = _writable_index(field, Schema.TYPE_I32, values.size())
		if index < 0 or index >= i32_columns.size():
			return false
		i32_columns[index] = PackedInt32Array()
		i32_columns[index] = values.duplicate()
		return true

	func set_i64(field: int, values: PackedInt64Array) -> bool:
		"""Replace one i64 column after checking ordinal, type and exact extent. Refusal changes nothing."""
		var index: int = _writable_index(field, Schema.TYPE_I64, values.size())
		if index < 0 or index >= i64_columns.size():
			return false
		i64_columns[index] = PackedInt64Array()
		i64_columns[index] = values.duplicate()
		return true

	func _writable_index(field: int, code: int, supplied: int) -> int:
		"""Bucket index for a legal setter call, or -1. The old slot is emptied before the one copy.

		The setters drop the previous column reference first and duplicate exactly ONE column
		afterwards, so no unbounded old-column reference is retained across the allocation.
		"""
		if not Schema.field_valid(owner, field) or Schema.field_type(owner, field) != code:
			return -1
		if supplied != Schema.element_count(owner, field):
			return -1
		return Schema.storage_index(owner, field)


class WireChunk:
	"""One emitted fragment: its bytes, or a refusal code and detail with no bytes."""
	var bytes: PackedByteArray = PackedByteArray()
	var code: StringName = REFUSE_NONE
	var detail: String = ""

	func is_ok() -> bool:
		"""True when this chunk carries no refusal."""
		return code == REFUSE_NONE

	func succeed(p_bytes: PackedByteArray) -> bool:
		"""Record one fragment's bytes and clear diagnostics; always returns true."""
		bytes = p_bytes
		code = REFUSE_NONE
		detail = ""
		return true

	func refuse(p_code: StringName, p_detail: String) -> bool:
		"""Record a refusal and clear the bytes; always returns false."""
		bytes = PackedByteArray()
		code = p_code
		detail = p_detail
		return false


class OwnerResult:
	"""One transferred owner record, or a refusal with no record."""
	var record: FramedOwner = null
	var code: StringName = REFUSE_NONE
	var detail: String = ""

	func is_ok() -> bool:
		"""True only when there is no refusal AND a record is actually present."""
		return code == REFUSE_NONE and record != null

	func succeed(p_record: FramedOwner) -> bool:
		"""Take ownership of a completed record and clear diagnostics; always returns true."""
		record = p_record
		code = REFUSE_NONE
		detail = ""
		return true

	func refuse(p_code: StringName, p_detail: String) -> bool:
		"""Record a refusal and clear this wrapper's record reference; always returns false."""
		record = null
		code = p_code
		detail = p_detail
		return false


# --- shared preflights and framing arithmetic -----------------------------------------------------

static func accepted() -> SaveHeader.Refusal:
	"""The accepted result: an empty code and no detail."""
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func refused(code: StringName, detail: String) -> SaveHeader.Refusal:
	"""Build a refusal carrying one of this module's codes and its detail."""
	return SaveHeader.Refusal.new(code, detail)


static func byte_order_refusal() -> SaveHeader.Refusal:
	"""Prove this host's packed-to-byte conversion is little-endian before any bulk conversion.

	The local probe, mapped to SAVE_COMPONENT_BYTE_ORDER. `PackedInt32Array.to_byte_array()` and
	its inverses are memory copies, so an unchecked big-endian host would transpose every value in
	every column silently. The i32 probe pins the shared packed-conversion path both cursors use.
	"""
	var probe: PackedByteArray = PackedInt32Array([BYTE_ORDER_PROBE]).to_byte_array()
	if probe.size() != SaveCodec.I32_BYTES:
		return refused(REFUSE_BYTE_ORDER,
			"an i32 converted to %d bytes, not %d" % [probe.size(), SaveCodec.I32_BYTES])
	for index: int in SaveCodec.I32_BYTES:
		var expected: int = (BYTE_ORDER_PROBE >> (index * 8)) & SaveCodec.UINT8_MAX
		if probe[index] != expected:
			return refused(REFUSE_BYTE_ORDER,
				"byte %d of the sentinel is %d, not the little-endian %d"
					% [index, probe[index], expected])
	return accepted()


static func schema_preflight_refusal(section_schema: int) -> SaveHeader.Refusal:
	"""The declared section schema must be this body's 2."""
	if section_schema != Schema.SECTION_SCHEMA_VERSION:
		return refused(REFUSE_SCHEMA, "section schema %d is not %d"
			% [section_schema, Schema.SECTION_SCHEMA_VERSION])
	return accepted()


static func descriptor_preflight_refusal(descriptor_rows: int) -> SaveHeader.Refusal:
	"""The descriptor row count must be the compiled 193184 sum of primaries, not an entity count."""
	if descriptor_rows != Schema.DESCRIPTOR_ROW_COUNT:
		return refused(REFUSE_DESCRIPTOR, "descriptor row_count %d is not %d"
			% [descriptor_rows, Schema.DESCRIPTOR_ROW_COUNT])
	return accepted()


static func length_preflight_refusal(section_byte_length: int) -> SaveHeader.Refusal:
	"""The descriptor's section byte length must be the fixed 12947565 of this body."""
	if section_byte_length != Schema.SECTION_BYTES:
		return refused(REFUSE_LENGTH, "section byte_length %d is not the fixed %d"
			% [section_byte_length, Schema.SECTION_BYTES])
	return accepted()


static func encode_preflight_refusal(section_schema: int,
		descriptor_rows: int) -> SaveHeader.Refusal:
	"""Encoder preflight, in order: schema, descriptor rows, compiled metadata, host byte order."""
	var schema: SaveHeader.Refusal = schema_preflight_refusal(section_schema)
	if not schema.is_ok():
		return schema
	var rows: SaveHeader.Refusal = descriptor_preflight_refusal(descriptor_rows)
	if not rows.is_ok():
		return rows
	var metadata: SaveHeader.Refusal = Schema.schema_refusal()
	if not metadata.is_ok():
		return metadata
	return byte_order_refusal()


static func decode_preflight_refusal(section_schema: int, descriptor_rows: int,
		section_byte_length: int) -> SaveHeader.Refusal:
	"""Decoder preflight: schema, rows, exact length, metadata, host order -- before any allocation.

	On load these three arguments MUST come from the same decoded 64-byte section descriptor and
	never from this module's constants; on capture they are the values prepared for that file.
	Common-file provenance and outer descriptor validation remain coordinator obligations.
	"""
	var schema: SaveHeader.Refusal = schema_preflight_refusal(section_schema)
	if not schema.is_ok():
		return schema
	var rows: SaveHeader.Refusal = descriptor_preflight_refusal(descriptor_rows)
	if not rows.is_ok():
		return rows
	var length: SaveHeader.Refusal = length_preflight_refusal(section_byte_length)
	if not length.is_ok():
		return length
	var metadata: SaveHeader.Refusal = Schema.schema_refusal()
	if not metadata.is_ok():
		return metadata
	return byte_order_refusal()


static func owner_shape_refusal(record: FramedOwner) -> SaveHeader.Refusal:
	"""Validate a nonnull record, its owner index, both bucket lengths and every column extent.

	Structure only: no semantic check, no occupancy reading, no cross-owner rule.
	"""
	if record == null:
		return refused(REFUSE_SHAPE, "no framed owner was supplied")
	if not Schema.owner_valid(record.owner):
		return refused(REFUSE_SHAPE, "owner index %d is not a section 4 owner" % record.owner)
	var buckets: Array[int] = [0, 0, 0]
	for field: int in Schema.field_count(record.owner):
		var column: SaveHeader.Refusal = _column_shape_refusal(record, field, buckets)
		if not column.is_ok():
			return column
	if record.u8_columns.size() != buckets[0] or record.i32_columns.size() != buckets[1] \
			or record.i64_columns.size() != buckets[2]:
		return refused(REFUSE_SHAPE,
			"owner '%s' holds %d/%d/%d columns; the schema declares %d/%d/%d"
				% [Schema.owner_key(record.owner), record.u8_columns.size(),
					record.i32_columns.size(), record.i64_columns.size(), buckets[0], buckets[1],
					buckets[2]])
	return accepted()


static func _column_shape_refusal(record: FramedOwner, field: int,
		buckets: Array[int]) -> SaveHeader.Refusal:
	"""Tally one field into its type bucket and check that column's presence and exact extent."""
	var owner: int = record.owner
	var code: int = Schema.field_type(owner, field)
	var count: int = Schema.element_count(owner, field)
	var index: int = Schema.storage_index(owner, field)
	var held: int = -1
	if code == Schema.TYPE_U8:
		buckets[0] += 1
		held = record.u8_columns[index].size() if index < record.u8_columns.size() else -1
	elif code == Schema.TYPE_I32:
		buckets[1] += 1
		held = record.i32_columns[index].size() if index < record.i32_columns.size() else -1
	elif code == Schema.TYPE_I64:
		buckets[2] += 1
		held = record.i64_columns[index].size() if index < record.i64_columns.size() else -1
	else:
		return refused(REFUSE_SHAPE, "field %d of owner '%s' declares unsupported type %d"
			% [field, Schema.owner_key(owner), code])
	if held != count:
		return refused(REFUSE_SHAPE, "field %d of owner '%s' holds %d values, not %d"
			% [field, Schema.owner_key(owner), held, count])
	return accepted()


static func wrapper_bytes(owner: int) -> int:
	"""Size of one owner's wrapper fragment: the four header words, key text, child header, extents.

	Derived from the compiled block and payload lengths rather than re-measuring the key, so the
	encoder, the decoder and the metadata cannot disagree about a wrapper boundary.
	"""
	if not Schema.owner_valid(owner):
		return 0
	var identity: int = Schema.owner_block_bytes(owner) - Schema.payload_bytes(owner)
	return identity + Schema.CHILD_COUNT_BYTES \
		+ Schema.CHILD_EXTENT_BYTES * Schema.child_extent_count(owner)


static func elements_per_fragment(width: int) -> int:
	"""Whole elements of this width that fit the 65536-byte window. No fragment crosses a field."""
	if width <= 0:
		return 0
	return Schema.CHUNK_BYTES / width


static func value_fragment_bytes(owner: int, field: int, element: int) -> int:
	"""Length of the next whole-element value fragment of this field, from `element` onward."""
	if not Schema.field_valid(owner, field):
		return 0
	var width: int = Schema.field_width(owner, field)
	var remaining: int = Schema.element_count(owner, field) - element
	if remaining <= 0:
		return 0
	return mini(remaining, elements_per_fragment(width)) * width


static func store_count_fragment() -> PackedByteArray:
	"""The 4-byte store_count fragment that opens the section."""
	var writer: SaveCodec.Writer = SaveCodec.Writer.new(Schema.STORE_COUNT_BYTES)
	writer.write_u32(Schema.STORE_COUNT)
	return writer.to_bytes()


static func owner_wrapper_fragment(owner: int) -> PackedByteArray:
	"""One owner's whole wrapper: key, version, primary count, payload length, child header, extents."""
	if not Schema.owner_valid(owner):
		return PackedByteArray()
	var writer: SaveCodec.Writer = SaveCodec.Writer.new(wrapper_bytes(owner))
	writer.write_utf8_u32(Schema.owner_key(owner), OWNER_KEY_MAX_BYTES)
	writer.write_u32(Schema.owner_version(owner))
	writer.write_u64(Schema.primary_count(owner))
	writer.write_u64(Schema.payload_bytes(owner))
	writer.write_u32(Schema.child_extent_count(owner))
	for child: int in Schema.child_extent_count(owner):
		writer.write_u64(Schema.child_extent(owner, child))
	return writer.to_bytes()


static func field_count_fragment(owner: int, field: int) -> PackedByteArray:
	"""One field's 8-byte element_count fragment."""
	if not Schema.field_valid(owner, field):
		return PackedByteArray()
	var writer: SaveCodec.Writer = SaveCodec.Writer.new(Schema.FIELD_COUNT_BYTES)
	writer.write_u64(Schema.element_count(owner, field))
	return writer.to_bytes()


static func column_fragment(record: FramedOwner, field: int, start: int,
		end: int) -> PackedByteArray:
	"""Little-endian bytes of one column's `[start, end)` values, preserving signed full width."""
	if record == null or not Schema.field_valid(record.owner, field):
		return PackedByteArray()
	var code: int = Schema.field_type(record.owner, field)
	if code == Schema.TYPE_U8:
		return record.u8_column(field).slice(start, end)
	if code == Schema.TYPE_I32:
		return record.i32_column(field).slice(start, end).to_byte_array()
	return record.i64_column(field).slice(start, end).to_byte_array()


static func release_column(record: FramedOwner, field: int) -> void:
	"""Drop one column's buffer, leaving an empty slot of the right type.

	Called before a replacement column is built, so the decoder never holds an old column and a
	new one of the same field at once. A record with a released column is private and unpublished.
	"""
	if record == null or not Schema.field_valid(record.owner, field):
		return
	var code: int = Schema.field_type(record.owner, field)
	var index: int = Schema.storage_index(record.owner, field)
	if code == Schema.TYPE_U8 and index < record.u8_columns.size():
		record.u8_columns[index] = PackedByteArray()
	elif code == Schema.TYPE_I32 and index < record.i32_columns.size():
		record.i32_columns[index] = PackedInt32Array()
	elif code == Schema.TYPE_I64 and index < record.i64_columns.size():
		record.i64_columns[index] = PackedInt64Array()


static func install_column(record: FramedOwner, field: int, raw: PackedByteArray) -> bool:
	"""Convert one field's assembled bytes into its exact private column position.

	The u8 path takes the assembled buffer directly, so an arbitrary byte survives verbatim; the
	i32/i64 paths preserve two's-complement full-width values. The slot is emptied first, so the
	peak here is the staging buffer plus one converted column -- two copies of that one field.
	"""
	if record == null or not Schema.field_valid(record.owner, field):
		return false
	var owner: int = record.owner
	if raw.size() != Schema.element_count(owner, field) * Schema.field_width(owner, field):
		return false
	var index: int = Schema.storage_index(owner, field)
	var code: int = Schema.field_type(owner, field)
	release_column(record, field)
	if code == Schema.TYPE_U8:
		record.u8_columns[index] = raw
		return true
	if code == Schema.TYPE_I32:
		record.i32_columns[index] = raw.to_int32_array()
		return true
	if code == Schema.TYPE_I64:
		record.i64_columns[index] = raw.to_int64_array()
		return true
	return false


class EncodeCursor:
	"""Streams section 4 one bound owner at a time, in exact field-aligned fragments.

	Single-use, with no reset. The first error is sticky and every later call returns it with no
	progress and no accepted bytes. A bound record is BORROWED, not snapshotted: the caller must
	freeze it for that owner's whole emission. No array of 18 records is ever held, and there is no
	whole-column, whole-owner or whole-section concatenation helper.
	"""
	var _owner: int = 0
	var _field: int = 0
	var _element: int = 0
	var _record: FramedOwner = null
	var _store_count_done: bool = false
	var _wrapper_done: bool = false
	var _count_done: bool = false
	var _emitted: int = 0
	var _owners_done: bool = false
	var _code: StringName = REFUSE_NONE
	var _detail: String = ""

	func _init(section_schema: int, descriptor_rows: int) -> void:
		"""Preflight schema, descriptor rows, compiled metadata and host byte order, in that order."""
		var preflight: SaveHeader.Refusal = SaveSectionComponentColumnsScript \
			.encode_preflight_refusal(section_schema, descriptor_rows)
		if not preflight.is_ok():
			_fail(preflight.code, preflight.detail)

	func refusal() -> SaveHeader.Refusal:
		"""The first error recorded, or the accepted result."""
		return SaveHeader.Refusal.new(_code, _detail)

	func failed() -> bool:
		"""True once any operation has refused."""
		return _code != REFUSE_NONE

	func owner_index() -> int:
		"""The next or current expected owner index, 0..17, or 18 once all owners are emitted."""
		return _owner

	func needs_owner() -> bool:
		"""True once the store count is out and another owner must be bound. False on failure or end."""
		return not failed() and not _owners_done and _store_count_done and _record == null \
			and _owner < Schema.STORE_COUNT

	func has_more() -> bool:
		"""True until every owner is emitted, including while waiting for a bind. False on failure."""
		return not failed() and not _owners_done

	func emitted_bytes() -> int:
		"""Bytes returned by successful fragments. Sink acknowledgement is outside this codec."""
		return _emitted

	func is_complete() -> bool:
		"""True only when all 18 owners are emitted and the byte count is exactly SECTION_BYTES."""
		return not failed() and _owners_done and _emitted == Schema.SECTION_BYTES

	func bind_owner(record: FramedOwner) -> SaveHeader.Refusal:
		"""Borrow the expected owner's record after checking its index and full shape. Sticky on failure."""
		if failed():
			return refusal()
		if not needs_owner():
			_fail(REFUSE_STATE, "owner %d cannot be bound in this state" % _owner)
			return refusal()
		if record == null:
			_fail(REFUSE_SHAPE, "no framed owner was supplied for owner %d" % _owner)
			return refusal()
		if record.owner != _owner:
			_fail(REFUSE_OWNER, "owner %d was supplied where owner %d is expected"
				% [record.owner, _owner])
			return refusal()
		var shape: SaveHeader.Refusal = SaveSectionComponentColumnsScript \
			.owner_shape_refusal(record)
		if not shape.is_ok():
			_fail(shape.code, shape.detail)
			return refusal()
		_record = record
		_wrapper_done = false
		_count_done = false
		_field = 0
		_element = 0
		return SaveHeader.Refusal.new(REFUSE_NONE, "")

	func next_chunk_into(out: WireChunk) -> bool:
		"""Emit the next exact fragment, or refuse with the cursor's first sticky code."""
		if out == null:
			return _fail(REFUSE_STATE, "no output chunk was supplied")
		if failed():
			return out.refuse(_code, _detail)
		if _owners_done:
			_fail(REFUSE_STATE, "all %d owners have already been emitted" % Schema.STORE_COUNT)
			return out.refuse(_code, _detail)
		if not _store_count_done:
			return _store_count_into(out)
		if _record == null:
			_fail(REFUSE_STATE, "owner %d must be bound before its next fragment" % _owner)
			return out.refuse(_code, _detail)
		if not _wrapper_done:
			return _wrapper_into(out)
		if not _count_done:
			return _count_into(out)
		return _values_into(out)

	func finish() -> SaveHeader.Refusal:
		"""Succeed only when every owner is emitted at exactly SECTION_BYTES; otherwise refuse."""
		if failed():
			return refusal()
		if is_complete():
			return SaveHeader.Refusal.new(REFUSE_NONE, "")
		_fail(REFUSE_TRUNCATED, "%d of %d bytes emitted with owner %d outstanding"
			% [_emitted, Schema.SECTION_BYTES, _owner])
		return refusal()

	func _store_count_into(out: WireChunk) -> bool:
		"""Emit the 4-byte store count that opens the section."""
		if not _emit(SaveSectionComponentColumnsScript.store_count_fragment(),
				Schema.STORE_COUNT_BYTES, REFUSE_METADATA, out):
			return false
		_store_count_done = true
		return true

	func _wrapper_into(out: WireChunk) -> bool:
		"""Emit this owner's whole wrapper, child header and child extents as one fragment."""
		var expected: int = SaveSectionComponentColumnsScript.wrapper_bytes(_owner)
		if not _emit(SaveSectionComponentColumnsScript.owner_wrapper_fragment(_owner), expected,
				REFUSE_METADATA, out):
			return false
		_wrapper_done = true
		_count_done = false
		_field = 0
		_element = 0
		return true

	func _count_into(out: WireChunk) -> bool:
		"""Emit the current field's 8-byte element count."""
		if not _emit(SaveSectionComponentColumnsScript.field_count_fragment(_owner, _field),
				Schema.FIELD_COUNT_BYTES, REFUSE_METADATA, out):
			return false
		_count_done = true
		_element = 0
		return true

	func _values_into(out: WireChunk) -> bool:
		"""Emit the next whole-element value fragment of the current field, at most 65536 bytes."""
		var width: int = Schema.field_width(_owner, _field)
		var total: int = Schema.element_count(_owner, _field)
		var end: int = mini(_element
			+ SaveSectionComponentColumnsScript.elements_per_fragment(width), total)
		var bytes: PackedByteArray = SaveSectionComponentColumnsScript \
			.column_fragment(_record, _field, _element, end)
		if not _emit(bytes, (end - _element) * width, REFUSE_SHAPE, out):
			return false
		_element = end
		if _element >= total:
			_advance_field()
		return true

	func _advance_field() -> void:
		"""Move to the next field, or release the borrowed record and request the next owner."""
		_field += 1
		_count_done = false
		_element = 0
		if _field < Schema.field_count(_owner):
			return
		_record = null
		_wrapper_done = false
		_field = 0
		_owner += 1
		_owners_done = _owner >= Schema.STORE_COUNT

	func _emit(bytes: PackedByteArray, expected: int, code: StringName, out: WireChunk) -> bool:
		"""Hand one fragment to the caller, refusing unless it is exactly the expected length."""
		if bytes.size() != expected:
			_fail(code, "owner %d field %d framed %d bytes where %d are declared"
				% [_owner, _field, bytes.size(), expected])
			return out.refuse(_code, _detail)
		_emitted += bytes.size()
		return out.succeed(bytes)

	func _fail(code: StringName, detail: String) -> bool:
		"""Record the first error; later errors never overwrite it. Always returns false."""
		if _code == REFUSE_NONE:
			_code = code
			_detail = detail
		_record = null
		return false


class DecodeCursor:
	"""Reads section 4 one owner at a time, comparing framing byte-for-byte before allocating.

	Single-use, with no reset. Framing fragments are compared against the compiled expected bytes
	-- every key, schema, count, extent and payload length -- so a hostile field never drives an
	allocation or advances an offset. At most one private owner exists, and no more input is taken
	until it is transferred. Receiving a framed owner is not approval to install it into a live
	store: semantic validation, CRC, digests and file transactions live outside this cursor.
	"""
	var _owner: int = 0
	var _field: int = 0
	var _element: int = 0
	var _record: FramedOwner = null
	var _pending: PackedByteArray = PackedByteArray()
	var _store_count_done: bool = false
	var _wrapper_done: bool = false
	var _count_done: bool = false
	var _ready: bool = false
	var _consumed: int = 0
	var _owners_done: bool = false
	var _code: StringName = REFUSE_NONE
	var _detail: String = ""

	func _init(section_schema: int, descriptor_rows: int, section_byte_length: int) -> void:
		"""Preflight schema, rows, exact length, metadata and host order before any allocation."""
		var preflight: SaveHeader.Refusal = SaveSectionComponentColumnsScript \
			.decode_preflight_refusal(section_schema, descriptor_rows, section_byte_length)
		if not preflight.is_ok():
			_fail(preflight.code, preflight.detail)

	func refusal() -> SaveHeader.Refusal:
		"""The first error recorded, or the accepted result."""
		return SaveHeader.Refusal.new(_code, _detail)

	func failed() -> bool:
		"""True once any operation has refused."""
		return _code != REFUSE_NONE

	func owner_index() -> int:
		"""The owner index currently expected, 0..17, or 18 once the last one is transferred."""
		return _owner

	func owner_ready() -> bool:
		"""True only once every field of the current owner is complete and awaiting transfer."""
		return not failed() and _ready

	func consumed_bytes() -> int:
		"""Accepted fragment bytes only. A refused fragment never advances this."""
		return _consumed

	func is_complete() -> bool:
		"""True only when the final owner is transferred and the byte count is exactly SECTION_BYTES."""
		return not failed() and _owners_done and _consumed == Schema.SECTION_BYTES

	func next_read_size() -> int:
		"""Exact next fragment length, 1..65536, or zero while ready, complete or failed.

		A disk adapter must assemble precisely this many bytes in a window of at most 65536; this
		API does not accept an arbitrary partial fragment.
		"""
		if failed() or _owners_done or _ready:
			return 0
		if not _store_count_done:
			return Schema.STORE_COUNT_BYTES
		if not _wrapper_done:
			return SaveSectionComponentColumnsScript.wrapper_bytes(_owner)
		if not _count_done:
			return Schema.FIELD_COUNT_BYTES
		return SaveSectionComponentColumnsScript.value_fragment_bytes(_owner, _field, _element)

	func accept_chunk(bytes: PackedByteArray) -> SaveHeader.Refusal:
		"""Accept exactly one expected fragment, refusing before any change on a wrong state or size."""
		if failed():
			return refusal()
		if _owners_done or _ready:
			_fail(REFUSE_STATE, "no input is accepted while owner %d is ready or the section is done"
				% _owner)
			return refusal()
		var expected: int = next_read_size()
		if bytes.size() != expected:
			_fail(REFUSE_CHUNK, "a %d-byte fragment was supplied where %d bytes are expected"
				% [bytes.size(), expected])
			return refusal()
		if not _store_count_done:
			return _accept_framing(bytes,
				SaveSectionComponentColumnsScript.store_count_fragment(), 0)
		if not _wrapper_done:
			return _accept_framing(bytes,
				SaveSectionComponentColumnsScript.owner_wrapper_fragment(_owner), 1)
		if not _count_done:
			return _accept_framing(bytes,
				SaveSectionComponentColumnsScript.field_count_fragment(_owner, _field), 2)
		return _accept_values(bytes)

	func take_owner_into(out: OwnerResult) -> bool:
		"""Transfer the completed owner by reference, clear this cursor's reference and advance.

		There is no whole-record publication copy. The caller must persist and RELEASE the record,
		including this wrapper's reference, before feeding the next owner's wrapper.
		"""
		if out == null:
			return _fail(REFUSE_STATE, "no output result was supplied")
		if failed():
			return out.refuse(_code, _detail)
		if not _ready or _record == null:
			_fail(REFUSE_STATE, "owner %d is not complete" % _owner)
			return out.refuse(_code, _detail)
		var record: FramedOwner = _record
		_record = null
		_ready = false
		_wrapper_done = false
		_count_done = false
		_field = 0
		_element = 0
		_owner += 1
		_owners_done = _owner >= Schema.STORE_COUNT
		return out.succeed(record)

	func finish() -> SaveHeader.Refusal:
		"""Succeed only when the last owner is transferred at exactly SECTION_BYTES; otherwise refuse."""
		if failed():
			return refusal()
		if is_complete():
			return SaveHeader.Refusal.new(REFUSE_NONE, "")
		_fail(REFUSE_TRUNCATED, "%d of %d bytes consumed with owner %d outstanding"
			% [_consumed, Schema.SECTION_BYTES, _owner])
		return refusal()

	func _accept_framing(bytes: PackedByteArray, expected: PackedByteArray,
			stage: int) -> SaveHeader.Refusal:
		"""Compare one framing fragment byte-for-byte, then advance. Stage 0/1/2 is count/wrapper/field."""
		if expected.is_empty() or bytes != expected:
			_fail(REFUSE_FRAME, "the framing fragment at offset %d does not match owner %d stage %d"
				% [_consumed, _owner, stage])
			_drop()
			return refusal()
		if stage == 1:
			var allocated: SaveHeader.Refusal = _allocate_owner()
			if not allocated.is_ok():
				return allocated
		_consumed += bytes.size()
		if stage == 0:
			_store_count_done = true
		elif stage == 1:
			_wrapper_done = true
			_count_done = false
			_field = 0
			_element = 0
		else:
			_begin_field()
		return SaveHeader.Refusal.new(REFUSE_NONE, "")

	func _allocate_owner() -> SaveHeader.Refusal:
		"""Allocate this owner's private columns, only after its entire wrapper matched."""
		var record: FramedOwner = FramedOwner.new(_owner)
		var shape: SaveHeader.Refusal = SaveSectionComponentColumnsScript \
			.owner_shape_refusal(record)
		if not shape.is_ok():
			_fail(shape.code, shape.detail)
			_drop()
			return refusal()
		_record = record
		return SaveHeader.Refusal.new(REFUSE_NONE, "")

	func _begin_field() -> void:
		"""Open the current field: empty its allocated slot and start a fresh staging buffer.

		Releasing the slot here is the COW discipline -- the zero column is dropped before any of
		the replacement exists, so the peak for a field is its staging buffer plus its one column.
		"""
		_count_done = true
		_element = 0
		_pending = PackedByteArray()
		SaveSectionComponentColumnsScript.release_column(_record, _field)

	func _accept_values(bytes: PackedByteArray) -> SaveHeader.Refusal:
		"""Assemble one value fragment into the private staging buffer, installing a finished field."""
		var width: int = Schema.field_width(_owner, _field)
		if width <= 0 or bytes.size() % width != 0:
			_fail(REFUSE_CHUNK, "owner %d field %d cannot take a %d-byte fragment"
				% [_owner, _field, bytes.size()])
			_drop()
			return refusal()
		_pending.append_array(bytes)
		_element += bytes.size() / width
		_consumed += bytes.size()
		if _element < Schema.element_count(_owner, _field):
			return SaveHeader.Refusal.new(REFUSE_NONE, "")
		return _install_field()

	func _install_field() -> SaveHeader.Refusal:
		"""Convert the assembled field into its exact private position and advance."""
		if not SaveSectionComponentColumnsScript.install_column(_record, _field, _pending):
			_fail(REFUSE_SHAPE, "owner %d field %d could not take its %d assembled bytes"
				% [_owner, _field, _pending.size()])
			_drop()
			return refusal()
		_pending = PackedByteArray()
		_field += 1
		_count_done = false
		_element = 0
		if _field >= Schema.field_count(_owner):
			_ready = true
		return SaveHeader.Refusal.new(REFUSE_NONE, "")

	func _drop() -> void:
		"""Release the private partial or untransferred record and its staging buffer.

		The last accepted offset and the first diagnostic are retained; input and every previously
		transferred record are left untouched.
		"""
		_record = null
		_pending = PackedByteArray()
		_ready = false

	func _fail(code: StringName, detail: String) -> bool:
		"""Record the first error; later errors never overwrite it. Always returns false."""
		if _code == REFUSE_NONE:
			_code = code
			_detail = detail
		_drop()
		return false
