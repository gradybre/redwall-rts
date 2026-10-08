extends RefCounted
## ARCH-SAVE-002 section 6 AUXILIARY_STATE: the framing codec, its staged State, the owner adapter
## registry and the canonical-hash adapters (ADR 1222 step 4a).
##
## THE FORMAT (decided by the integration lead for step 4a; little-endian, no padding):
##
##   store_count:u32, exactly OWNER_COUNT (25 since ADR 1228), then one block per declared owner in
##   strict ASCII key order: buildings, command_dispatch, construction_extension,
##   construction_paid_ledger, crop_weather, demolition_admissions, demolition_work, ecology,
##   excavation_inventory, excavation_sites, haul_planner, inventory, modular_projects,
##   room_layout, room_projects, spoil_tips, store_policy, underground_connector_contacts,
##   underground_connector_placements, underground_connector_workpieces,
##   underground_entry_progress, underground_locations, underground_mount, underground_routes,
##   underground_world_routes. EVERY block is always present.
##
##   block   = key_len:u32, key (UTF-8), owner_schema_version:u32, primary_count:u64,
##             payload_length:u64, payload
##   payload = per field in ordinal order: element_count:u64, then element_count * width value
##             bytes, little-endian.
##
##   primary_count is the element count of the block's first non-SCALAR field, or 1 when every
##   field is scalar. payload_length must equal the sum of its fields exactly, and the blocks must
##   tile the section exactly: no gap, no trailing byte.
##
## Counts follow save_auxiliary_state_schema.gd's compiled rules (SCALAR 1, FIXED n, BOUNDED 0..n,
## UNPROVED zero-only), and every count is checked BEFORE any slice is taken. The section length is
## variable but confined to [EMPTY_SECTION_BYTES, MAX_SECTION_BYTES]; the empty section is
## 4471529 bytes because FIXED columns are always carried at their full capacity.
##
## Decoding stages a whole State and the caller's is overwritten only on success (decision 0059),
## so a refused load leaves `out` untouched. Every buffer bound is a SUBTRACTION, so no
## `offset + length` is formed before it is known not to overflow.
##
## Owner semantics live in adapters (`Adapters`), not here: this module never interprets a value.
## `UnsupportedAdapter` is DEC-055 Q9's refusing adapter for owners that have no codec yet.

const Section := preload("res://scripts/core/save_section_auxiliary.gd")
const Schema := preload("res://scripts/core/save_auxiliary_state_schema.gd")
const SaveCodec := preload("res://scripts/core/save_codec.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const Digest := preload("res://scripts/core/canonical_state_hash.gd")

const SECTION_ID: int = 6
const OWNER_COUNT: int = Schema.OWNER_COUNT

const REFUSE_NONE: StringName = SaveHeader.REFUSE_NONE
const REFUSE_SECTION_LENGTH: StringName = &"SAVE_S6_SECTION_LENGTH"
const REFUSE_TRUNCATED: StringName = &"SAVE_S6_TRUNCATED"
const REFUSE_STORE_COUNT: StringName = &"SAVE_S6_STORE_COUNT"
const REFUSE_OWNER_KEY: StringName = &"SAVE_S6_OWNER_KEY"
const REFUSE_OWNER_SCHEMA: StringName = &"SAVE_S6_OWNER_SCHEMA"
const REFUSE_PRIMARY_COUNT: StringName = &"SAVE_S6_PRIMARY_COUNT"
const REFUSE_PAYLOAD_LENGTH: StringName = &"SAVE_S6_PAYLOAD_LENGTH"
const REFUSE_ELEMENT_COUNT: StringName = &"SAVE_S6_ELEMENT_COUNT"
const REFUSE_NOT_TILED: StringName = &"SAVE_S6_NOT_TILED"
const REFUSE_NEGATIVE_OFFSET: StringName = &"SAVE_S6_NEGATIVE_OFFSET"
const REFUSE_ENDIANNESS: StringName = &"SAVE_S6_ENDIANNESS"
const REFUSE_ADAPTER_MISSING: StringName = &"SAVE_S6_ADAPTER_MISSING"
const REFUSE_ADAPTER_INTERFACE: StringName = &"SAVE_S6_ADAPTER_INTERFACE"
const REFUSE_FIELD: StringName = &"SAVE_S6_FIELD"
const REFUSE_FIELD_TYPE: StringName = &"SAVE_S6_FIELD_TYPE"
const REFUSE_VALUE_RANGE: StringName = &"SAVE_S6_VALUE_RANGE"
const REFUSE_UNSUPPORTED_STATE: StringName = &"SAVE_UNSUPPORTED_STATE"

const ADAPTER_METHODS: Array[StringName] = [&"capture", &"validate", &"apply"]


static func _ok() -> SaveHeader.Refusal:
	"""The accepted record."""
	return SaveHeader.Refusal.new(REFUSE_NONE, "")


static func _no(code: StringName, detail: String) -> SaveHeader.Refusal:
	"""A refusal record."""
	return SaveHeader.Refusal.new(code, detail)


static func scalar_range_ok(type_code: int, value: int) -> bool:
	"""Whether `value` is representable in `type_code`. u64 is limited to the int64 range."""
	if type_code == Schema.TYPE_U8:
		return value >= 0 and value <= SaveCodec.UINT8_MAX
	if type_code == Schema.TYPE_U32:
		return value >= 0 and value <= SaveCodec.UINT32_MAX
	if type_code == Schema.TYPE_I32:
		return value >= SaveCodec.INT32_MIN and value <= SaveCodec.INT32_MAX
	if type_code == Schema.TYPE_U64:
		return value >= 0
	return true


static func encode_scalar(type_code: int, value: int) -> PackedByteArray:
	"""One value's little-endian bytes in `type_code`. The caller has range-checked it."""
	var raw: PackedByteArray = PackedByteArray()
	raw.resize(Schema.TYPE_WIDTHS[type_code])
	if type_code == Schema.TYPE_U8:
		raw.encode_u8(0, value)
	elif type_code == Schema.TYPE_U32:
		raw.encode_u32(0, value)
	elif type_code == Schema.TYPE_I32:
		raw.encode_s32(0, value)
	elif type_code == Schema.TYPE_U64:
		raw.encode_u64(0, value)
	else:
		raw.encode_s64(0, value)
	return raw


static func decode_scalar(type_code: int, raw: PackedByteArray, at: int) -> int:
	"""One little-endian value of `type_code` at `at`. The caller has bounds-checked it."""
	if type_code == Schema.TYPE_U8:
		return raw.decode_u8(at)
	if type_code == Schema.TYPE_U32:
		return raw.decode_u32(at)
	if type_code == Schema.TYPE_I32:
		return raw.decode_s32(at)
	if type_code == Schema.TYPE_U64:
		return raw.decode_u64(at)
	return raw.decode_s64(at)


static func little_endian_refusal() -> SaveHeader.Refusal:
	"""Prove `Packed*Array.to_byte_array()` is little-endian on this host before trusting it."""
	var narrow: PackedByteArray = PackedInt32Array([1]).to_byte_array()
	var wide: PackedByteArray = PackedInt64Array([1]).to_byte_array()
	if narrow.size() != 4 or narrow[0] != 1 or narrow[3] != 0:
		return _no(REFUSE_ENDIANNESS, "a native i32 conversion produced %s" % narrow.hex_encode())
	if wide.size() != 8 or wide[0] != 1 or wide[7] != 0:
		return _no(REFUSE_ENDIANNESS, "a native i64 conversion produced %s" % wide.hex_encode())
	return _ok()


class Block:
	"""One owner's staged block: per field ordinal its element count and raw little-endian bytes.

	`values[ordinal].size()` is always `counts[ordinal] * width` once a setter or the decoder has
	run; `shape_detail()` re-proves that, because both members are public. Every getter returns a
	COPY and every setter installs a copy: packed arrays are shared by reference in Godot 4.
	"""
	var owner: int = 0
	var counts: PackedInt64Array = PackedInt64Array()
	var values: Array[PackedByteArray] = []

	func _init(p_owner: int) -> void:
		"""A block for one owner, in its canonical empty form."""
		owner = p_owner
		reset_to_empty()

	func reset_to_empty() -> void:
		"""SCALAR fields one zero, FIXED(n) fields n zeros, BOUNDED and UNPROVED fields empty."""
		var fields: int = Schema.field_count_of(owner)
		counts = PackedInt64Array()
		counts.resize(fields)
		values = []
		for ordinal: int in fields:
			var count: int = Schema.empty_count_of(owner, ordinal)
			var raw: PackedByteArray = PackedByteArray()
			raw.resize(count * Schema.width_of(owner, ordinal))
			raw.fill(0)
			counts[ordinal] = count
			values.append(raw)

	func is_canonical_empty() -> bool:
		"""Whether this block equals its owner's canonical empty block exactly."""
		return equals(Section.Block.new(owner))

	func equals(other: Block) -> bool:
		"""Same owner, same counts and byte-identical values."""
		if other == null or other.owner != owner or other.counts != counts:
			return false
		return other.values == values

	func element_count(ordinal: int) -> int:
		"""The element count of one field, or -1 for an undeclared ordinal."""
		return counts[ordinal] if Schema.field_valid(owner, ordinal) else -1

	func primary_count() -> int:
		"""The first non-SCALAR field's element count, or 1 when every field is scalar."""
		for ordinal: int in Schema.field_count_of(owner):
			if Schema.rule_kind_of(owner, ordinal) != Schema.RULE_SCALAR:
				return counts[ordinal]
		return 1

	func payload_bytes() -> int:
		"""The payload this block encodes to: per field an 8-byte count plus its values."""
		var total: int = 0
		for ordinal: int in Schema.field_count_of(owner):
			total += Schema.FIELD_COUNT_BYTES + values[ordinal].size()
		return total

	func shape_detail() -> String:
		"""Every count admissible and every value buffer exactly count * width, or ""."""
		if counts.size() != Schema.field_count_of(owner) or values.size() != counts.size():
			return "'%s' block carries %d counts and %d columns, not %d" % [
				Schema.OWNER_KEYS[owner], counts.size(), values.size(),
				Schema.field_count_of(owner)]
		for ordinal: int in counts.size():
			if not Schema.count_admissible(owner, ordinal, counts[ordinal]):
				return "'%s.%s' holds %d elements, outside its rule" % [Schema.OWNER_KEYS[owner],
					Schema.field_key_of(owner, ordinal), counts[ordinal]]
			if values[ordinal].size() != counts[ordinal] * Schema.width_of(owner, ordinal):
				return "'%s.%s' holds %d value bytes for %d elements" % [Schema.OWNER_KEYS[owner],
					Schema.field_key_of(owner, ordinal), values[ordinal].size(), counts[ordinal]]
		return ""

	func type_matches(ordinal: int, type_code: int) -> bool:
		"""Whether `ordinal` is declared with exactly `type_code`."""
		return Schema.field_valid(owner, ordinal) \
			and Schema.field_type_of(owner, ordinal) == type_code

	func u8_column(ordinal: int) -> PackedByteArray:
		"""A copy of a u8 column; empty for a wrong type or ordinal (check `type_matches`)."""
		return values[ordinal].duplicate() if type_matches(ordinal, Schema.TYPE_U8) \
			else PackedByteArray()

	func i32_column(ordinal: int) -> PackedInt32Array:
		"""A copy of an i32 column; empty for a wrong type or ordinal (check `type_matches`)."""
		return values[ordinal].to_int32_array() if type_matches(ordinal, Schema.TYPE_I32) \
			else PackedInt32Array()

	func i64_column(ordinal: int) -> PackedInt64Array:
		"""A copy of an i64 column; empty for a wrong type or ordinal (check `type_matches`)."""
		return values[ordinal].to_int64_array() if type_matches(ordinal, Schema.TYPE_I64) \
			else PackedInt64Array()

	func set_u8_column(ordinal: int, column: PackedByteArray) -> SaveHeader.Refusal:
		"""Install a copy of a u8 column after checking its type and count rule."""
		var refusal: SaveHeader.Refusal = _column_refusal(ordinal, Schema.TYPE_U8, column.size())
		if refusal.is_ok():
			_install(ordinal, column.size(), column.duplicate())
		return refusal

	func set_i32_column(ordinal: int, column: PackedInt32Array) -> SaveHeader.Refusal:
		"""Install an i32 column's little-endian bytes after checking its type and count rule."""
		var refusal: SaveHeader.Refusal = _column_refusal(ordinal, Schema.TYPE_I32, column.size())
		if refusal.is_ok():
			_install(ordinal, column.size(), column.to_byte_array())
		return refusal

	func set_i64_column(ordinal: int, column: PackedInt64Array) -> SaveHeader.Refusal:
		"""Install an i64 column's little-endian bytes after checking its type and count rule."""
		var refusal: SaveHeader.Refusal = _column_refusal(ordinal, Schema.TYPE_I64, column.size())
		if refusal.is_ok():
			_install(ordinal, column.size(), column.to_byte_array())
		return refusal

	func scalar(ordinal: int) -> int:
		"""A SCALAR field's value; 0 for an undeclared or non-scalar ordinal."""
		if not Schema.field_valid(owner, ordinal) \
				or Schema.rule_kind_of(owner, ordinal) != Schema.RULE_SCALAR:
			return 0
		return Section.decode_scalar(Schema.field_type_of(owner, ordinal), values[ordinal], 0)

	func set_scalar(ordinal: int, value: int) -> SaveHeader.Refusal:
		"""Set a SCALAR field after checking that it is one and that `value` fits its type."""
		if not Schema.field_valid(owner, ordinal):
			return Section._no(REFUSE_FIELD, "'%s' has no ordinal %d" % [Schema.OWNER_KEYS[owner],
				ordinal])
		var type_code: int = Schema.field_type_of(owner, ordinal)
		if Schema.rule_kind_of(owner, ordinal) != Schema.RULE_SCALAR:
			return Section._no(REFUSE_FIELD_TYPE, "'%s.%s' is not a scalar" % [
				Schema.OWNER_KEYS[owner], Schema.field_key_of(owner, ordinal)])
		if not Section.scalar_range_ok(type_code, value):
			return Section._no(REFUSE_VALUE_RANGE, "'%s.%s' cannot hold %d" % [
				Schema.OWNER_KEYS[owner], Schema.field_key_of(owner, ordinal), value])
		_install(ordinal, 1, Section.encode_scalar(type_code, value))
		return Section._ok()

	func copy_from(other: Block) -> void:
		"""Become an independent copy of `other` (same owner expected)."""
		owner = other.owner
		counts = other.counts.duplicate()
		values = []
		for raw: PackedByteArray in other.values:
			values.append(raw.duplicate())

	func _column_refusal(ordinal: int, type_code: int, count: int) -> SaveHeader.Refusal:
		"""Declared ordinal, exact type and an admissible count, or the refusal naming which."""
		if not Schema.field_valid(owner, ordinal):
			return Section._no(REFUSE_FIELD, "'%s' has no ordinal %d" % [Schema.OWNER_KEYS[owner],
				ordinal])
		if Schema.field_type_of(owner, ordinal) != type_code:
			return Section._no(REFUSE_FIELD_TYPE, "'%s.%s' is type %d, not %d" % [
				Schema.OWNER_KEYS[owner], Schema.field_key_of(owner, ordinal),
				Schema.field_type_of(owner, ordinal), type_code])
		if not Schema.count_admissible(owner, ordinal, count):
			return Section._no(REFUSE_ELEMENT_COUNT, "'%s.%s' cannot hold %d elements" % [
				Schema.OWNER_KEYS[owner], Schema.field_key_of(owner, ordinal), count])
		return Section._ok()

	func _install(ordinal: int, count: int, raw: PackedByteArray) -> void:
		"""Bind an already-copied, already-checked buffer to one field."""
		counts[ordinal] = count
		values[ordinal] = raw


class State:
	"""Every declared block, in owner (ASCII) order. `State.new()` is the canonical empty section."""
	var blocks: Array[Block] = []

	func _init() -> void:
		"""Every owner's canonical empty block."""
		for owner: int in OWNER_COUNT:
			blocks.append(Block.new(owner))

	func block(owner: int) -> Block:
		"""One owner's block, or null for an undeclared index."""
		return blocks[owner] if Schema.owner_valid(owner) else null

	func equals(other: State) -> bool:
		"""Every block equal."""
		for owner: int in OWNER_COUNT:
			if not blocks[owner].equals(other.blocks[owner]):
				return false
		return true

	func shape_detail() -> String:
		"""The first block whose shape is wrong, or ""."""
		if blocks.size() != OWNER_COUNT:
			return "state carries %d blocks, not %d" % [blocks.size(), OWNER_COUNT]
		for owner: int in OWNER_COUNT:
			if blocks[owner] == null or blocks[owner].owner != owner:
				return "block %d is missing or belongs to another owner" % owner
			var detail: String = blocks[owner].shape_detail()
			if detail != "":
				return detail
		return ""

	func adopt(staged: State) -> void:
		"""Move a fully validated staged section's buffers into this State's own Blocks."""
		for owner: int in OWNER_COUNT:
			blocks[owner].counts = staged.blocks[owner].counts
			blocks[owner].values = staged.blocks[owner].values


class EncodeResult:
	"""Outcome of encoding the section: the bytes, or a refusal and no bytes."""
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
		"""Record a refusal with no bytes; always returns false."""
		ok = false
		bytes = PackedByteArray()
		refusal = p_refusal
		detail = p_detail
		return false


class Cursor:
	"""A bounded read position inside one section: never reads at or past `end`."""
	var at: int = 0
	var end: int = 0

	func _init(p_at: int, p_end: int) -> void:
		"""Start at `p_at`, bounded by `p_end`."""
		at = p_at
		end = p_end

	func has(width: int) -> bool:
		"""Whether `width` more bytes lie inside the bound. Overflow-safe subtraction."""
		return width >= 0 and width <= end - at


# --- encode -------------------------------------------------------------------------------------

static func encode_section(state: State, out: EncodeResult) -> bool:
	"""Encode `state` as `store_count` then every owner block. A refusal produces no bytes at all."""
	var table: SaveHeader.Refusal = Schema.table_refusal()
	if not table.is_ok():
		return out.refuse(table.code, table.detail)
	var endian: SaveHeader.Refusal = little_endian_refusal()
	if not endian.is_ok():
		return out.refuse(endian.code, endian.detail)
	var shape: String = state.shape_detail()
	if shape != "":
		return out.refuse(REFUSE_ELEMENT_COUNT, shape)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(Schema.STORE_COUNT_BYTES)
	bytes.encode_u32(0, OWNER_COUNT)
	for owner: int in OWNER_COUNT:
		bytes.append_array(_wrapper_bytes(state.blocks[owner]))
		_append_payload(state.blocks[owner], bytes)
	if bytes.size() < Schema.EMPTY_SECTION_BYTES or bytes.size() > Schema.MAX_SECTION_BYTES:
		return out.refuse(REFUSE_SECTION_LENGTH, "section 6 encoded %d bytes" % bytes.size())
	return out.succeed(bytes)


static func _wrapper_bytes(block: Block) -> PackedByteArray:
	"""`key_len, key, owner_schema_version, primary_count, payload_length` for one block."""
	var key: PackedByteArray = Schema.OWNER_KEYS[block.owner].to_utf8_buffer()
	var raw: PackedByteArray = PackedByteArray()
	raw.resize(Schema.WRAPPER_FIXED_BYTES + key.size())
	raw.encode_u32(0, key.size())
	for index: int in key.size():
		raw[4 + index] = key[index]
	raw.encode_u32(4 + key.size(), Schema.OWNER_SCHEMAS[block.owner])
	raw.encode_u64(8 + key.size(), block.primary_count())
	raw.encode_u64(16 + key.size(), block.payload_bytes())
	return raw


static func _append_payload(block: Block, bytes: PackedByteArray) -> void:
	"""Per field: `element_count:u64` then its raw little-endian values."""
	var prefix: PackedByteArray = PackedByteArray()
	prefix.resize(Schema.FIELD_COUNT_BYTES)
	for ordinal: int in block.counts.size():
		prefix.encode_u64(0, block.counts[ordinal])
		bytes.append_array(prefix)
		bytes.append_array(block.values[ordinal])


# --- decode -------------------------------------------------------------------------------------

static func decode_section(bytes: PackedByteArray, offset: int, length: int,
		out: State) -> SaveHeader.Refusal:
	"""Decode a whole section 6 at `offset` into `out`; `out` changes only on success."""
	var extent: SaveHeader.Refusal = extent_refusal(bytes, offset, length)
	if not extent.is_ok():
		return extent
	var cursor: Cursor = Cursor.new(offset, offset + length)
	var store_count: int = bytes.decode_u32(offset)
	if store_count != OWNER_COUNT:
		return _no(REFUSE_STORE_COUNT, "store_count is %d, not %d" % [store_count, OWNER_COUNT])
	cursor.at += Schema.STORE_COUNT_BYTES
	var staged: State = State.new()
	for owner: int in OWNER_COUNT:
		var refusal: SaveHeader.Refusal = _read_block(bytes, cursor, staged.blocks[owner])
		if not refusal.is_ok():
			return refusal
	if cursor.at != cursor.end:
		return _no(REFUSE_NOT_TILED, "the blocks end at %d, %d bytes before the section end"
			% [cursor.at - offset, cursor.end - cursor.at])
	out.adopt(staged)
	return _ok()


static func extent_refusal(bytes: PackedByteArray, offset: int, length: int) -> SaveHeader.Refusal:
	"""Table, host order, offset, the length window and the buffer bound, in that order."""
	var table: SaveHeader.Refusal = Schema.table_refusal()
	if not table.is_ok():
		return table
	var endian: SaveHeader.Refusal = little_endian_refusal()
	if not endian.is_ok():
		return endian
	if offset < 0:
		return _no(REFUSE_NEGATIVE_OFFSET, "offset %d is negative" % offset)
	if length < Schema.EMPTY_SECTION_BYTES or length > Schema.MAX_SECTION_BYTES:
		return _no(REFUSE_SECTION_LENGTH, "section 6 declares %d bytes, outside %d..%d"
			% [length, Schema.EMPTY_SECTION_BYTES, Schema.MAX_SECTION_BYTES])
	if bytes.size() < length or offset > bytes.size() - length:
		return _no(REFUSE_TRUNCATED, "section 6 needs %d bytes at offset %d, buffer holds %d"
			% [length, offset, bytes.size()])
	return _ok()


static func _read_block(bytes: PackedByteArray, cursor: Cursor, block: Block) -> SaveHeader.Refusal:
	"""One block's key, schema, primary count and payload, each checked before it is used."""
	var key: PackedByteArray = Schema.OWNER_KEYS[block.owner].to_utf8_buffer()
	if not cursor.has(SaveCodec.U32_BYTES):
		return _no(REFUSE_TRUNCATED, "no key length for block %d" % block.owner)
	if bytes.decode_u32(cursor.at) != key.size() \
			or not cursor.has(SaveCodec.U32_BYTES + key.size()) or bytes.slice(cursor.at + 4, cursor.at + 4 + key.size()) != key:
		return _no(REFUSE_OWNER_KEY, "block %d does not carry '%s'" % [block.owner,
			Schema.OWNER_KEYS[block.owner]])
	cursor.at += SaveCodec.U32_BYTES + key.size()
	if not cursor.has(Schema.WRAPPER_FIXED_BYTES - SaveCodec.U32_BYTES):
		return _no(REFUSE_TRUNCATED, "'%s' wrapper is cut short" % Schema.OWNER_KEYS[block.owner])
	var schema: int = bytes.decode_u32(cursor.at)
	if schema != Schema.OWNER_SCHEMAS[block.owner]:
		return _no(REFUSE_OWNER_SCHEMA, "'%s' declares schema %d, not %d" % [
			Schema.OWNER_KEYS[block.owner], schema, Schema.OWNER_SCHEMAS[block.owner]])
	var primary: int = bytes.decode_u64(cursor.at + 4)
	var payload_length: int = bytes.decode_u64(cursor.at + 12)
	cursor.at += Schema.WRAPPER_FIXED_BYTES - SaveCodec.U32_BYTES
	var refusal: SaveHeader.Refusal = _read_payload(bytes, cursor, block, payload_length)
	if refusal.is_ok() and primary != block.primary_count():
		return _no(REFUSE_PRIMARY_COUNT, "'%s' declares primary_count %d, not %d" % [
			Schema.OWNER_KEYS[block.owner], primary, block.primary_count()])
	return refusal


static func _read_payload(bytes: PackedByteArray, cursor: Cursor, block: Block,
		payload_length: int) -> SaveHeader.Refusal:
	"""The payload inside its own declared bound, which must be filled exactly by its fields."""
	var key: String = Schema.OWNER_KEYS[block.owner]
	if payload_length < 0 or payload_length > Schema.payload_bytes_at(block.owner, true):
		return _no(REFUSE_PAYLOAD_LENGTH, "'%s' declares %d payload bytes, above its maximum %d"
			% [key, payload_length, Schema.payload_bytes_at(block.owner, true)])
	if not cursor.has(payload_length):
		return _no(REFUSE_TRUNCATED, "'%s' payload of %d bytes runs past the section end"
			% [key, payload_length])
	var inner: Cursor = Cursor.new(cursor.at, cursor.at + payload_length)
	for ordinal: int in Schema.field_count_of(block.owner):
		var refusal: SaveHeader.Refusal = _read_field(bytes, inner, block, ordinal)
		if not refusal.is_ok():
			return refusal
	if inner.at != inner.end:
		return _no(REFUSE_PAYLOAD_LENGTH, "'%s' fields fill %d of %d payload bytes"
			% [key, inner.at - cursor.at, payload_length])
	cursor.at = inner.end
	return _ok()


static func _read_field(bytes: PackedByteArray, inner: Cursor, block: Block,
		ordinal: int) -> SaveHeader.Refusal:
	"""One field's count, checked against its rule BEFORE its values are sliced."""
	var name: String = "%s.%s" % [Schema.OWNER_KEYS[block.owner],
		Schema.field_key_of(block.owner, ordinal)]
	if not inner.has(Schema.FIELD_COUNT_BYTES):
		return _no(REFUSE_PAYLOAD_LENGTH, "'%s' has no room for its element count" % name)
	var count: int = bytes.decode_u64(inner.at)
	if not Schema.count_admissible(block.owner, ordinal, count):
		return _no(REFUSE_ELEMENT_COUNT, "'%s' declares %d elements, outside its rule" % [name,
			count])
	inner.at += Schema.FIELD_COUNT_BYTES
	var width: int = count * Schema.width_of(block.owner, ordinal)
	if not inner.has(width):
		return _no(REFUSE_PAYLOAD_LENGTH, "'%s' needs %d value bytes past the payload end"
			% [name, width])
	block.counts[ordinal] = count
	block.values[ordinal] = bytes.slice(inner.at, inner.at + width)
	inner.at += width
	return _ok()


# --- owner adapters -----------------------------------------------------------------------------

class Adapters:
	"""Owner index -> adapter Object exposing capture/validate/apply(block) -> Refusal."""
	var _by_owner: Array[Object] = []

	func _init() -> void:
		"""No owner has an adapter yet."""
		_by_owner.resize(OWNER_COUNT)

	func register(owner: int, adapter: Object) -> SaveHeader.Refusal:
		"""Bind one owner's adapter; refuses an unknown owner, a repeat or a bad interface."""
		if not Schema.owner_valid(owner):
			return Section._no(REFUSE_ADAPTER_INTERFACE, "owner %d is not declared" % owner)
		if _by_owner[owner] != null:
			return Section._no(REFUSE_ADAPTER_INTERFACE, "'%s' already has an adapter"
				% Schema.OWNER_KEYS[owner])
		for method: StringName in ADAPTER_METHODS:
			if adapter == null or not adapter.has_method(method):
				return Section._no(REFUSE_ADAPTER_INTERFACE, "'%s' adapter lacks %s()"
					% [Schema.OWNER_KEYS[owner], method])
		_by_owner[owner] = adapter
		return Section._ok()

	func adapter_of(owner: int) -> Object:
		"""The adapter bound to `owner`, or null."""
		return _by_owner[owner] if Schema.owner_valid(owner) else null

	func missing_refusal() -> SaveHeader.Refusal:
		"""SAVE_S6_ADAPTER_MISSING naming the first owner without an adapter, or accepted."""
		for owner: int in OWNER_COUNT:
			if _by_owner[owner] == null:
				return Section._no(REFUSE_ADAPTER_MISSING, "'%s' has no section-6 adapter"
					% Schema.OWNER_KEYS[owner])
		return Section._ok()


static func _call_adapter(adapter: Object, method: StringName, block: Block) -> SaveHeader.Refusal:
	"""Call one adapter method; anything but a Refusal is an interface refusal."""
	var result: SaveHeader.Refusal = adapter.call(method, block) as SaveHeader.Refusal
	if result == null:
		return _no(REFUSE_ADAPTER_INTERFACE, "%s() did not return a Refusal for '%s'"
			% [method, Schema.OWNER_KEYS[block.owner]])
	return result


static func capture_into(adapters: Adapters, out: State) -> SaveHeader.Refusal:
	"""Capture every owner into a staged State; `out` adopts it only if every owner succeeds."""
	var missing: SaveHeader.Refusal = adapters.missing_refusal()
	if not missing.is_ok():
		return missing
	var staged: State = State.new()
	for owner: int in OWNER_COUNT:
		var refusal: SaveHeader.Refusal = _call_adapter(adapters.adapter_of(owner), &"capture",
			staged.blocks[owner])
		if not refusal.is_ok():
			return refusal
	var shape: String = staged.shape_detail()
	if shape != "":
		return _no(REFUSE_ELEMENT_COUNT, shape)
	out.adopt(staged)
	return _ok()


static func validate_section(state: State, adapters: Adapters) -> SaveHeader.Refusal:
	"""Every adapter present, every block well-shaped, then every owner's own validation."""
	var missing: SaveHeader.Refusal = adapters.missing_refusal()
	if not missing.is_ok():
		return missing
	var shape: String = state.shape_detail()
	if shape != "":
		return _no(REFUSE_ELEMENT_COUNT, shape)
	for owner: int in OWNER_COUNT:
		var refusal: SaveHeader.Refusal = _call_adapter(adapters.adapter_of(owner), &"validate",
			state.blocks[owner])
		if not refusal.is_ok():
			return refusal
	return _ok()


static func apply_section(state: State, adapters: Adapters) -> SaveHeader.Refusal:
	"""Validate ALL owners first, then apply in ASCII owner order.

	Nothing is applied unless everything validated. An `apply()` refusing AFTER its own
	`validate()` accepted is an adapter contract violation; it is reported, but owners applied
	before it are not rolled back here -- the load orchestrator owns world-level rollback.
	"""
	var valid: SaveHeader.Refusal = validate_section(state, adapters)
	if not valid.is_ok():
		return valid
	for owner: int in OWNER_COUNT:
		var refusal: SaveHeader.Refusal = _call_adapter(adapters.adapter_of(owner), &"apply",
			state.blocks[owner])
		if not refusal.is_ok():
			return refusal
	return _ok()


class UnsupportedAdapter:
	"""DEC-055 Q9: an owner with no codec yet. Saves only while the owner holds no state.

	`probe` is a Callable returning bool "the owner holds state". Anything other than a bool
	false -- an invalid Callable, a non-bool, true -- is treated as holding state (fail closed).
	"""
	var _owner: int = 0
	var _probe: Callable

	func _init(p_owner: int, p_probe: Callable) -> void:
		"""Bind to one owner index and its state probe."""
		_owner = p_owner
		_probe = p_probe

	func capture(block: Block) -> SaveHeader.Refusal:
		"""Write the canonical empty block, or refuse SAVE_UNSUPPORTED_STATE naming the owner."""
		if block.owner != _owner:
			return Section._no(REFUSE_OWNER_KEY, "adapter for owner %d got block %d"
				% [_owner, block.owner])
		var holds: Variant = _probe.call() if _probe.is_valid() else true
		if typeof(holds) != TYPE_BOOL or bool(holds):
			return Section._no(REFUSE_UNSUPPORTED_STATE,
				"'%s' holds state section 6 cannot save yet" % Schema.OWNER_KEYS[_owner])
		block.reset_to_empty()
		return Section._ok()

	func validate(block: Block) -> SaveHeader.Refusal:
		"""Accept only this owner's canonical empty block."""
		if block.owner != _owner or not block.is_canonical_empty():
			return Section._no(REFUSE_UNSUPPORTED_STATE,
				"'%s' block is not its canonical empty form" % Schema.OWNER_KEYS[_owner])
		return Section._ok()

	func apply(_block: Block) -> SaveHeader.Refusal:
		"""Nothing to publish: the owner stays empty."""
		return Section._ok()


# --- canonical hash adapters --------------------------------------------------------------------

class Adapter:
	"""One section-6 owner's canonical value adapter over a staged State.

	Reads the State's block at call time, so a State that has since adopted a decoded section is
	hashed as it is now. Every column handed out is a fresh array.
	"""
	var _state: State = null
	var _owner: int = 0

	func _init(p_state: State, p_owner: int) -> void:
		"""Bind to one State and one of its owners."""
		_state = p_state
		_owner = p_owner

	func canonical_field_values(field_key: StringName, out: Digest.FieldValues) -> bool:
		"""Supply one declared field's typed column at its element count."""
		var ordinal: int = Schema.ordinal_of(_owner, String(field_key))
		if ordinal < 0:
			return out.refuse(REFUSE_FIELD, "'%s' declares no field '%s'"
				% [Schema.OWNER_KEYS[_owner], field_key])
		var block: Block = _state.blocks[_owner]
		var count: int = block.counts[ordinal]
		var raw: PackedByteArray = block.values[ordinal]
		var type_code: int = Schema.field_type_of(_owner, ordinal)
		if type_code == Schema.TYPE_U8:
			return out.supply_bytes(raw.duplicate(), count)
		if type_code == Schema.TYPE_I32:
			return out.supply_int32(raw.to_int32_array(), count)
		if type_code == Schema.TYPE_I64 or type_code == Schema.TYPE_U64:
			return out.supply_int64(raw.to_int64_array(), count)
		return out.supply_int64(Section.u32_logical(raw), count)


static func u32_logical(raw: PackedByteArray) -> PackedInt64Array:
	"""A u32 column's logical unsigned values as int64, the way section 1 supplies a u32 cursor."""
	@warning_ignore("integer_division") var count: int = raw.size() / SaveCodec.U32_BYTES
	var logical: PackedInt64Array = PackedInt64Array()
	logical.resize(count)
	for index: int in count:
		logical[index] = raw.decode_u32(index * SaveCodec.U32_BYTES)
	return logical


static func register_adapters(walker: Digest.Walker, state: State) -> Digest.Refusal:
	"""Register every section-6 owner's canonical value adapters on `walker`."""
	for owner: int in OWNER_COUNT:
		var refusal: Digest.Refusal = walker.register_owner(SECTION_ID, Schema.OWNER_KEYS[owner],
			Adapter.new(state, owner))
		if not refusal.is_ok():
			return refusal
	return Digest.Refusal.new(Digest.REFUSE_NONE, "")
