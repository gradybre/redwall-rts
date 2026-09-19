extends RefCounted
## Section 15 STATE_DIGEST: the canonical field walker for the RWL-STATE-1 logical-state stream.
##
## WHAT THIS MODULE IS
##
## SAVE-R09 (docs/rulings/2026-09-11_save_codec_contract.md, "Canonical logical-state stream,
## RWL-STATE-1") defines section 15 as exactly 32 raw SHA-256 bytes over an ordered stream of
## typed field records. REG-R01 (docs/rulings/2026-09-12_save_registry_answers.md) supplies the
## order: "canonical_state_hash owns section 15 and never includes itself". This file is that
## owner. It walks the checked-in declaration, pulls each field's values from the owner's adapter,
## and streams the result into SHA-256 without ever materialising the whole stream.
##
## WHAT THIS MODULE IS NOT
##
##   * It is NOT the header's body digest. That is SHA-256 over file bytes [264, EOF) and lives in
##     save_header.gd. The two answer different questions and are computed over different inputs.
##   * It is NOT a release-save certification. `docs/planning/canonical_state_registry.json` carries
##     `release_save_ready: false`, and nothing here changes that. At the time of writing NO owner
##     adapter exists, so `Walker.digest_into()` on the production declaration REFUSES with
##     CANONICAL_NO_ADAPTER and `missing_adapter_owners()` returns all 52 declared owners. That is
##     the specified behaviour, not a gap: REG-R01 says "Missing producers cannot be waved through
##     by feeding a digest of a subset or arbitrary empty bytes."
##   * There is deliberately NO subset mode, no "hash what you have" flag and no empty-adapter
##     default. A declared owner without an adapter is a refusal, full stop.
##
## The release/non-release distinction is visible in the API, not only in this comment:
## `DigestResult.covers_release_state` is true only when the walked declaration is the canonical
## one AND every declared owner supplied an adapter. A fixture declaration can be digested (that
## is how this file is tested and how the pinned vector in ADR 0127 was produced), but its result
## says `covers_release_state == false` and carries its own fixture identity string.
##
## ORDER IS DECLARED, NEVER DERIVED
##
## REG-R01: "Do not regenerate order from GDScript declaration order, dictionaries, display
## labels, directory iteration or this document at runtime." The generated table at the bottom of
## this file is compiled from `docs/planning/canonical_state_registry.json` by
## tools/generate_canonical_state_table.py. Record order is section 1..14, then ASCII owner_key
## byte order, then the DECLARED field ordinal inside that owner -- explicitly NOT alphabetical by
## field key. `Declaration.validate()` enforces the first two; the third is positional and is
## pinned by the fixture vector in the test suite, because an alphabetical walk produces a digest
## that is stable, plausible and wrong.
##
## There is no Dictionary anywhere in this file. There is nothing here whose iteration order could
## drift between runs, platforms or engine versions.
##
## WHY A COMPILED TABLE AND NOT A RUNTIME JSON READ -- see docs/decisions/0127. Two reasons that
## are not style: the registry lives at `docs/planning/`, OUTSIDE `res://`, so an exported build
## cannot reach it at all; and Godot's `JSON.parse_string()` returns every number as a float,
## which would put a float on the path of `ordinal`, `type_code` and `section_id` in violation of
## the integer-authoritative-state rule. The cost is that the table must be regenerated whenever
## the registry changes; `test_canonical_state_hash.gd` re-reads the JSON and fails on any drift.
##
## THE int32/int64 SIGN TRAP. GDScript ints are signed 64-bit. `0x80000000` is a POSITIVE GDScript
## int and `-2147483648` is its int32 reading, and the registry stores u32 columns in
## `PackedInt32Array` (see `_next_persistent_id`, whose declared range runs to 2147483648). A type
## 1 (u32) field therefore accepts either storage form and says which it means:
## STORAGE_INT32 reinterprets the two's-complement bits, STORAGE_INT64 carries the logical
## unsigned value and is range-checked. Neither is a default and neither is guessed.
##
## NO IN-BAND FAILURE (decision 0059). Nothing here returns -1, 0, empty bytes or a partial digest
## to mean "something was missing". Every entry point returns a `Refusal` and writes into a
## caller-owned result that is left empty on refusal.

## Self-preload so the inner classes can reach this script's own static functions; an inner
## class cannot call them unqualified. Same pattern as `save_codec.gd`'s `SaveCodecScript`.
const CanonicalStateHashScript := preload("res://scripts/core/canonical_state_hash.gd")
const SaveCodec := preload("res://scripts/core/save_codec.gd")

# --- stream framing -------------------------------------------------------------------------------

## SAVE-R09: "Eleven ASCII bytes `RWL-STATE-1`, NO terminating zero byte."
const STREAM_TAG: String = "RWL-STATE-1"
const STREAM_TAG_BYTES: int = 11

const DIGEST_BYTES: int = 32
const COMPATIBILITY_DIGEST_COUNT: int = 4

## Records exist for sections 1..14 only. Section 15 is this digest; REG-R01's `nonrecord_sections`
## says of it: "canonical_state_hash; 32 raw SHA256 bytes; not its own input".
const SECTION_ID_MIN: int = 1
const SECTION_ID_MAX: int = 14
const SELF_SECTION_ID: int = 15

## SAVE-R09-002 / S2: owner and field keys are nonempty ASCII, at most 256 bytes.
const MAX_KEY_BYTES: int = 256
## S2 freezes the engine identity line at 256 UTF-8 bytes "including its final LF".
const MAX_ENGINE_IDENTITY_BYTES: int = 256
const ASCII_MAX: int = 127
const ENGINE_IDENTITY_TERMINATOR: String = "\n"

## Type codes, shared with SAVE-R09-003's rules-manifest encodings.
const TYPE_U8: int = 0
const TYPE_U32: int = 1
const TYPE_I32: int = 2
const TYPE_U64: int = 3
const TYPE_I64: int = 4
const TYPE_UTF8_U32: int = 5
const TYPE_CODE_MAX: int = 5

## Which packed column an adapter handed over. An adapter states this; the walker never guesses.
const STORAGE_NONE: int = 0
const STORAGE_BYTE: int = 1
const STORAGE_INT32: int = 2
const STORAGE_INT64: int = 3
const STORAGE_TEXT: int = 4

## The bounded I/O window SAVE-R09-003 already names for artifact validation, reused here so the
## digest never holds a second copy of the world.
const CHUNK_BYTES: int = 65536

## The method an owner adapter must expose. Checked at registration, not at walk time.
const ADAPTER_METHOD: StringName = &"canonical_field_values"

# --- refusals -------------------------------------------------------------------------------------

const REFUSE_NONE: StringName = &""
const REFUSE_OWNER_COUNT: StringName = &"CANONICAL_OWNER_COUNT"
const REFUSE_FIELD_COUNT: StringName = &"CANONICAL_FIELD_COUNT"
const REFUSE_SECTION_RANGE: StringName = &"CANONICAL_SECTION_RANGE"
const REFUSE_SELF_INCLUSION: StringName = &"CANONICAL_SELF_INCLUSION"
const REFUSE_OWNER_ORDER: StringName = &"CANONICAL_OWNER_ORDER"
const REFUSE_OWNER_DUPLICATE: StringName = &"CANONICAL_OWNER_DUPLICATE"
const REFUSE_FIELD_DUPLICATE: StringName = &"CANONICAL_FIELD_DUPLICATE"
const REFUSE_KEY_INVALID: StringName = &"CANONICAL_KEY_INVALID"
const REFUSE_TYPE_CODE: StringName = &"CANONICAL_TYPE_CODE"
const REFUSE_SCHEMA_VERSION: StringName = &"CANONICAL_SCHEMA_VERSION"
const REFUSE_STRING_CAP_UNDECLARED: StringName = &"CANONICAL_STRING_CAP_UNDECLARED"
const REFUSE_STRING_CAP_RANGE: StringName = &"CANONICAL_STRING_CAP_RANGE"
const REFUSE_RECORD_COUNT: StringName = &"CANONICAL_RECORD_COUNT"
const REFUSE_UNREGISTERED_OWNER: StringName = &"CANONICAL_UNREGISTERED_OWNER"
const REFUSE_DUPLICATE_ADAPTER: StringName = &"CANONICAL_DUPLICATE_ADAPTER"
const REFUSE_ADAPTER_INTERFACE: StringName = &"CANONICAL_ADAPTER_INTERFACE"
const REFUSE_NO_ADAPTER: StringName = &"CANONICAL_NO_ADAPTER"
const REFUSE_ADAPTER_REFUSED: StringName = &"CANONICAL_ADAPTER_REFUSED"
const REFUSE_STORAGE_MISMATCH: StringName = &"CANONICAL_STORAGE_MISMATCH"
const REFUSE_VALUE_COUNT: StringName = &"CANONICAL_VALUE_COUNT"
const REFUSE_VALUE_RANGE: StringName = &"CANONICAL_VALUE_RANGE"
const REFUSE_DIGEST_LENGTH: StringName = &"CANONICAL_DIGEST_LENGTH"
const REFUSE_ENGINE_IDENTITY: StringName = &"CANONICAL_ENGINE_IDENTITY"
const REFUSE_NEGATIVE_TICK: StringName = &"CANONICAL_NEGATIVE_TICK"
const REFUSE_EMITTER: StringName = &"CANONICAL_EMITTER"
const REFUSE_CAPTURE_LIMIT: StringName = &"CANONICAL_CAPTURE_LIMIT"
const REFUSE_DIGEST_MISMATCH: StringName = &"CANONICAL_DIGEST_MISMATCH"

# --- value objects --------------------------------------------------------------------------------


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


class Inputs:
	"""The RWL-STATE-1 prefix values, supplied by the save owner; none is produced here.

	SAVE-R09-003 owns the four compatibility digest producers and the engine identity line. This
	module validates their shape and hashes them in the declared order, and refuses anything it
	cannot vouch for -- it never substitutes a zero digest or an invented build string.
	"""
	var rules_digest: PackedByteArray = PackedByteArray()
	var catalog_digest: PackedByteArray = PackedByteArray()
	var map_digest: PackedByteArray = PackedByteArray()
	var lookup_digest: PackedByteArray = PackedByteArray()
	var engine_identity_line: String = ""
	var completed_tick: int = 0


class FieldValues:
	"""One field's values, handed over as the owner's own packed column plus its storage form.

	Packed arrays are copy-on-write, so `supply_*` costs a reference, not a copy of the column.
	`count` is the number of leading elements the owner declares canonical, which for a dense
	store is its used prefix and for a capacity column is the full capacity.
	"""
	var storage: int = STORAGE_NONE
	var count: int = 0
	var bytes: PackedByteArray = PackedByteArray()
	var int32s: PackedInt32Array = PackedInt32Array()
	var int64s: PackedInt64Array = PackedInt64Array()
	var texts: PackedStringArray = PackedStringArray()
	var refusal: StringName = REFUSE_NONE
	var detail: String = ""

	func clear() -> void:
		"""Drop any previous field's column references so a stale value cannot be re-emitted."""
		storage = STORAGE_NONE
		count = 0
		bytes = PackedByteArray()
		int32s = PackedInt32Array()
		int64s = PackedInt64Array()
		texts = PackedStringArray()
		refusal = REFUSE_NONE
		detail = ""

	func refuse(p_refusal: StringName, p_detail: String) -> bool:
		"""Record the adapter's own refusal for this field; always returns false."""
		clear()
		refusal = p_refusal
		detail = p_detail
		return false

	func supply_bytes(column: PackedByteArray, p_count: int) -> bool:
		"""Hand over a u8 column and the count of leading elements that are canonical."""
		if p_count < 0 or p_count > column.size():
			return refuse(REFUSE_VALUE_COUNT, "u8 count %d outside 0..%d" % [p_count, column.size()])
		clear()
		storage = STORAGE_BYTE
		count = p_count
		bytes = column
		return true

	func supply_int32(column: PackedInt32Array, p_count: int) -> bool:
		"""Hand over an i32 column (also the storage of a u32 field's bit patterns)."""
		if p_count < 0 or p_count > column.size():
			return refuse(REFUSE_VALUE_COUNT, "i32 count %d outside 0..%d" % [p_count, column.size()])
		clear()
		storage = STORAGE_INT32
		count = p_count
		int32s = column
		return true

	func supply_int64(column: PackedInt64Array, p_count: int) -> bool:
		"""Hand over an i64 column, or the logical unsigned values of a u32/u64 field."""
		if p_count < 0 or p_count > column.size():
			return refuse(REFUSE_VALUE_COUNT, "i64 count %d outside 0..%d" % [p_count, column.size()])
		clear()
		storage = STORAGE_INT64
		count = p_count
		int64s = column
		return true

	func supply_texts(column: PackedStringArray, p_count: int) -> bool:
		"""Hand over a string column for a type 5 field. Each value carries its own u32 length."""
		if p_count < 0 or p_count > column.size():
			return refuse(REFUSE_VALUE_COUNT, "text count %d outside 0..%d" % [p_count, column.size()])
		clear()
		storage = STORAGE_TEXT
		count = p_count
		texts = column
		return true


class DigestResult:
	"""The outcome of one walk. Empty on refusal; never a partial or subset digest.

	`covers_release_state` is the whole point of this object. It is true only when the canonical
	declaration was walked AND every one of its owners supplied an adapter. Any other true-looking
	digest -- a fixture, a partial registration -- reports false here.
	"""
	var digest: PackedByteArray = PackedByteArray()
	var declaration_id: String = ""
	var record_count: int = 0
	var stream_bytes: int = 0
	var covers_release_state: bool = false
	var captured_stream: PackedByteArray = PackedByteArray()

	func clear() -> void:
		"""Reset every field so a refused walk cannot leave a previous digest visible."""
		digest = PackedByteArray()
		declaration_id = ""
		record_count = 0
		stream_bytes = 0
		covers_release_state = false
		captured_stream = PackedByteArray()


# --- bounded SHA-256 emitter ------------------------------------------------------------------------


class Emitter:
	"""Appends canonical bytes into a fixed chunk buffer and folds full chunks into SHA-256.

	SAVE-R09 requires "bounded streaming and no second world". The buffer is allocated once in
	`_init` and never resized, so a 16384-row column costs one 64 KiB window, not a 64 KiB
	allocation per record. Capture is opt-in, explicitly capped, and refuses rather than
	truncating -- a truncated capture next to a correct digest is exactly the kind of plausible
	wrong artifact this module exists to prevent.
	"""
	var _context: HashingContext = HashingContext.new()
	var _chunk: PackedByteArray = PackedByteArray()
	var _length: int = 0
	var _total: int = 0
	var _scratch: SaveCodec.Scalar = SaveCodec.Scalar.new()
	var _refusal: StringName = REFUSE_NONE
	var _detail: String = ""
	var _capture: PackedByteArray = PackedByteArray()
	var _capture_limit: int = 0

	func _init(p_chunk_bytes: int, p_capture_limit: int) -> void:
		"""Allocate the one chunk buffer and start SHA-256. `p_capture_limit` 0 disables capture."""
		_chunk.resize(maxi(p_chunk_bytes, CHUNK_BYTES))
		_capture_limit = maxi(p_capture_limit, 0)
		_context.start(HashingContext.HASH_SHA256)

	func failed() -> bool:
		"""True once any append has refused."""
		return _refusal != REFUSE_NONE

	func refusal_code() -> StringName:
		"""The first refusal code recorded, or REFUSE_NONE."""
		return _refusal

	func refusal_detail() -> String:
		"""Detail behind the first refusal, or an empty string."""
		return _detail

	func total_bytes() -> int:
		"""Total canonical bytes appended so far, including bytes already folded in."""
		return _total

	func captured() -> PackedByteArray:
		"""The captured stream when capture was enabled, otherwise empty."""
		return _capture

	func fail(p_refusal: StringName, p_detail: String) -> bool:
		"""Record the first refusal; later refusals never overwrite it. Always returns false."""
		if _refusal == REFUSE_NONE:
			_refusal = p_refusal
			_detail = p_detail
		return false

	func _flush() -> void:
		"""Fold the buffered bytes into SHA-256 and rewind the buffer cursor."""
		if _length == 0:
			return
		if _length == _chunk.size():
			_context.update(_chunk)
		else:
			_context.update(_chunk.slice(0, _length))
		_length = 0

	func _room(width: int) -> bool:
		"""Ensure `width` bytes fit in the chunk, flushing first if they do not."""
		if width > _chunk.size():
			return fail(REFUSE_EMITTER, "value of %d bytes exceeds the %d-byte window"
				% [width, _chunk.size()])
		if _length + width > _chunk.size():
			_flush()
		return true

	func _advance(width: int) -> bool:
		"""Record `width` freshly written bytes, capturing them when capture is enabled."""
		if _capture_limit > 0:
			if _total + width > _capture_limit:
				return fail(REFUSE_CAPTURE_LIMIT, "stream exceeds the %d-byte capture cap"
					% _capture_limit)
			for index: int in width:
				_capture.append(_chunk[_length + index])
		_length += width
		_total += width
		return true

	func _append(width: int, value: int, signedness: int) -> bool:
		"""Range-check and write one fixed-width little-endian integer."""
		if failed() or not _room(width):
			return false
		if not _dispatch(width, value, signedness):
			return fail(REFUSE_VALUE_RANGE, _scratch.detail)
		return _advance(width)

	func _dispatch(width: int, value: int, signedness: int) -> bool:
		"""Route one append to the width- and signedness-specific codec write."""
		if width == SaveCodec.U8_BYTES:
			return SaveCodec.write_u8_into(_chunk, _length, value, _scratch)
		if width == SaveCodec.U32_BYTES:
			if signedness == SaveCodec.SIGNEDNESS_UNSIGNED:
				return SaveCodec.write_u32_into(_chunk, _length, value, _scratch)
			return SaveCodec.write_i32_into(_chunk, _length, value, _scratch)
		if signedness == SaveCodec.SIGNEDNESS_UNSIGNED:
			return SaveCodec.write_u64_into(_chunk, _length, value, _scratch)
		return SaveCodec.write_i64_into(_chunk, _length, value, _scratch)

	func put_u8(value: int) -> bool:
		"""Append one unsigned byte."""
		return _append(SaveCodec.U8_BYTES, value, SaveCodec.SIGNEDNESS_UNSIGNED)

	func put_u32(value: int) -> bool:
		"""Append a little-endian u32."""
		return _append(SaveCodec.U32_BYTES, value, SaveCodec.SIGNEDNESS_UNSIGNED)

	func put_i32(value: int) -> bool:
		"""Append a little-endian i32."""
		return _append(SaveCodec.I32_BYTES, value, SaveCodec.SIGNEDNESS_SIGNED)

	func put_u64(value: int) -> bool:
		"""Append a little-endian u64."""
		return _append(SaveCodec.U64_BYTES, value, SaveCodec.SIGNEDNESS_UNSIGNED)

	func put_i64(value: int) -> bool:
		"""Append a little-endian i64."""
		return _append(SaveCodec.I64_BYTES, value, SaveCodec.SIGNEDNESS_SIGNED)

	func put_raw(source: PackedByteArray) -> bool:
		"""Append `source` verbatim, in windows no larger than the chunk buffer."""
		var offset: int = 0
		while offset < source.size():
			if failed():
				return false
			var width: int = mini(source.size() - offset, _chunk.size())
			if not _room(width):
				return false
			for index: int in width:
				_chunk[_length + index] = source[offset + index]
			if not _advance(width):
				return false
			offset += width
		return not failed()

	func put_utf8_u32(text: String, max_bytes: int) -> bool:
		"""Append a u32 UTF-8 BYTE-length prefix and the encoded bytes. Never a character count."""
		if failed():
			return false
		var encoded: PackedByteArray = text.to_utf8_buffer()
		if encoded.size() > max_bytes:
			return fail(REFUSE_VALUE_RANGE, "%d UTF-8 bytes exceed the declared %d-byte cap"
				% [encoded.size(), max_bytes])
		if not put_u32(encoded.size()):
			return false
		return put_raw(encoded)

	func finish_into(out: PackedByteArray) -> bool:
		"""Fold the tail and write the 32 raw SHA-256 bytes into `out`. False on any refusal."""
		if failed():
			return false
		_flush()
		var digest: PackedByteArray = _context.finish()
		if digest.size() != DIGEST_BYTES:
			return fail(REFUSE_DIGEST_LENGTH, "SHA-256 returned %d bytes" % digest.size())
		out.resize(DIGEST_BYTES)
		for index: int in DIGEST_BYTES:
			out[index] = digest[index]
		return true


# --- the declaration ------------------------------------------------------------------------------


class Declaration:
	"""The checked-in ordered field declaration, as packed columns. Built once, then read only.

	Owners are stored in section-then-ASCII-owner_key order and fields in each owner's declared
	ordinal order. Nothing in this class sorts anything: `validate()` CHECKS the order it was
	given and refuses a declaration that is out of order, which is the only way an order mistake
	can be caught at all. Re-deriving the order here would defeat REG-R01.
	"""
	var _identity: String = ""
	var _owner_sections: PackedInt32Array = PackedInt32Array()
	var _owner_keys: PackedStringArray = PackedStringArray()
	var _owner_versions: PackedInt32Array = PackedInt32Array()
	var _owner_field_begin: PackedInt32Array = PackedInt32Array()
	var _owner_field_count: PackedInt32Array = PackedInt32Array()
	var _field_keys: PackedStringArray = PackedStringArray()
	var _field_types: PackedByteArray = PackedByteArray()
	var _field_hashed: PackedByteArray = PackedByteArray()
	var _field_has_count: PackedByteArray = PackedByteArray()
	var _field_counts: PackedInt64Array = PackedInt64Array()
	var _field_max_utf8: PackedInt32Array = PackedInt32Array()
	var _record_count: int = 0

	func _init(p_identity: String, p_owners: Array, p_fields: Array) -> void:
		"""Seal a Builder's owner rows and field rows into packed columns. Allocates once, here.

		`p_owners` rows are [section_id, owner_key, schema_version, field_count]; `p_fields` rows
		are [field_key, type_code, hashed, has_count, count, max_utf8_bytes], already in global
		record order.
		"""
		_identity = p_identity
		_seal_owners(p_owners)
		_seal_fields(p_fields)

	func _seal_owners(p_owners: Array) -> void:
		"""Copy the owner rows into packed columns and compute each owner's field span."""
		var count: int = p_owners.size()
		_owner_sections.resize(count)
		_owner_keys.resize(count)
		_owner_versions.resize(count)
		_owner_field_begin.resize(count)
		_owner_field_count.resize(count)
		var begin: int = 0
		for index: int in count:
			var row: Array = p_owners[index]
			_owner_sections[index] = int(row[0])
			_owner_keys[index] = String(row[1])
			_owner_versions[index] = int(row[2])
			_owner_field_begin[index] = begin
			_owner_field_count[index] = int(row[3])
			begin += int(row[3])

	func _seal_fields(p_fields: Array) -> void:
		"""Copy the field rows into packed columns and total the hashed records."""
		var count: int = p_fields.size()
		_field_keys.resize(count)
		_field_types.resize(count)
		_field_hashed.resize(count)
		_field_has_count.resize(count)
		_field_counts.resize(count)
		_field_max_utf8.resize(count)
		_record_count = 0
		for index: int in count:
			var row: Array = p_fields[index]
			_field_keys[index] = String(row[0])
			_field_types[index] = int(row[1])
			_field_hashed[index] = 1 if bool(row[2]) else 0
			_field_has_count[index] = 1 if bool(row[3]) else 0
			_field_counts[index] = int(row[4])
			_field_max_utf8[index] = int(row[5])
			_record_count += _field_hashed[index]

	func identity() -> String:
		"""The declaration's own identity string: the registry_id, or a fixture's own name."""
		return _identity

	func owner_count() -> int:
		"""Number of (section, owner) blocks declared."""
		return _owner_keys.size()

	func field_count() -> int:
		"""Number of declared fields, including those excluded from the record stream."""
		return _field_keys.size()

	func record_count() -> int:
		"""Number of field records the stream emits: the declared fields minus the exclusions."""
		return _record_count

	func owner_section(index: int) -> int:
		"""Section id of owner `index`."""
		return _owner_sections[index]

	func owner_key(index: int) -> String:
		"""ASCII owner key of owner `index`."""
		return _owner_keys[index]

	func owner_schema_version(index: int) -> int:
		"""Owner schema version. Carried for the section wrappers; NOT part of a field record."""
		return _owner_versions[index]

	func owner_field_begin(index: int) -> int:
		"""Global index of owner `index`'s first declared field."""
		return _owner_field_begin[index]

	func owner_field_count(index: int) -> int:
		"""Number of fields declared by owner `index`."""
		return _owner_field_count[index]

	func field_key(index: int) -> String:
		"""ASCII field key at global field `index`."""
		return _field_keys[index]

	func field_type(index: int) -> int:
		"""Type code 0..5 at global field `index`."""
		return _field_types[index]

	func field_is_hashed(index: int) -> bool:
		"""False for a declared field the registry excludes from the record stream."""
		return _field_hashed[index] == 1

	func field_has_declared_count(index: int) -> bool:
		"""True when the registry declares an exact element count for this field."""
		return _field_has_count[index] == 1

	func field_declared_count(index: int) -> int:
		"""The declared element count. Only meaningful when field_has_declared_count() is true."""
		return _field_counts[index]

	func field_max_utf8_bytes(index: int) -> int:
		"""Declared per-value UTF-8 byte cap for a type 5 field; 0 when none is declared."""
		return _field_max_utf8[index]

	func covers_release_state() -> bool:
		"""True only for the canonical declaration compiled from the checked-in registry."""
		return (_identity == DECLARATION_ID
			and owner_count() == CANONICAL_OWNER_COUNT
			and field_count() == CANONICAL_FIELD_COUNT
			and _record_count == CANONICAL_RECORD_COUNT)

	func find_owner(section_id: int, key: String) -> int:
		"""Global owner index for (section, key), or the owner count when it is not declared."""
		for index: int in owner_count():
			if _owner_sections[index] == section_id and _owner_keys[index] == key:
				return index
		return owner_count()

	func validate() -> Refusal:
		"""Check every structural rule the record stream depends on, in declaration order."""
		if owner_count() <= 0:
			return Refusal.new(REFUSE_OWNER_COUNT, "a declaration needs at least one owner")
		var spanned: int = 0
		for index: int in owner_count():
			spanned += _owner_field_count[index]
		if spanned != field_count():
			return Refusal.new(REFUSE_FIELD_COUNT,
				"owner spans cover %d of %d declared fields" % [spanned, field_count()])
		var owners_refusal: Refusal = _validate_owner_order()
		if not owners_refusal.is_ok():
			return owners_refusal
		return _validate_fields()

	func _validate_owner_order() -> Refusal:
		"""Owners must run section 1..14 ascending, then strictly ascending ASCII owner_key."""
		for index: int in owner_count():
			var section: int = _owner_sections[index]
			if section == SELF_SECTION_ID:
				return Refusal.new(REFUSE_SELF_INCLUSION,
					"owner '%s' declares section 15; the digest is never its own input"
						% _owner_keys[index])
			if section < SECTION_ID_MIN or section > SECTION_ID_MAX:
				return Refusal.new(REFUSE_SECTION_RANGE, "section %d outside 1..14" % section)
			if _owner_versions[index] < 1:
				return Refusal.new(REFUSE_SCHEMA_VERSION,
					"owner '%s' schema version %d is below 1" % [_owner_keys[index], _owner_versions[index]])
			var key_refusal: Refusal = _validate_key(_owner_keys[index], "owner")
			if not key_refusal.is_ok():
				return key_refusal
			if index > 0:
				var order_refusal: Refusal = _compare_owners(index - 1, index)
				if not order_refusal.is_ok():
					return order_refusal
		return Refusal.new(REFUSE_NONE, "")

	func _compare_owners(previous: int, index: int) -> Refusal:
		"""Refuse unless owner `index` strictly follows `previous` by (section, ASCII key)."""
		if _owner_sections[index] < _owner_sections[previous]:
			return Refusal.new(REFUSE_OWNER_ORDER, "section %d follows section %d"
				% [_owner_sections[index], _owner_sections[previous]])
		if _owner_sections[index] > _owner_sections[previous]:
			return Refusal.new(REFUSE_NONE, "")
		var order: int = CanonicalStateHashScript.ascii_compare(_owner_keys[previous], _owner_keys[index])
		if order == 0:
			return Refusal.new(REFUSE_OWNER_DUPLICATE, "owner '%s' declared twice in section %d"
				% [_owner_keys[index], _owner_sections[index]])
		if order > 0:
			return Refusal.new(REFUSE_OWNER_ORDER, "owner '%s' precedes '%s' in ASCII order"
				% [_owner_keys[index], _owner_keys[previous]])
		return Refusal.new(REFUSE_NONE, "")

	func _validate_fields() -> Refusal:
		"""Check each owner's field keys, types and per-type declarations in ordinal order."""
		for owner: int in owner_count():
			var begin: int = _owner_field_begin[owner]
			for offset: int in _owner_field_count[owner]:
				var index: int = begin + offset
				var key_refusal: Refusal = _validate_key(_field_keys[index], "field")
				if not key_refusal.is_ok():
					return key_refusal
				for earlier: int in offset:
					if _field_keys[begin + earlier] == _field_keys[index]:
						return Refusal.new(REFUSE_FIELD_DUPLICATE,
							"owner '%s' declares field '%s' twice"
								% [_owner_keys[owner], _field_keys[index]])
				var type_refusal: Refusal = _validate_field_type(index)
				if not type_refusal.is_ok():
					return type_refusal
		return Refusal.new(REFUSE_NONE, "")

	func _validate_field_type(index: int) -> Refusal:
		"""Check one field's type code, declared count and, for type 5, its declared byte cap."""
		var type_code: int = _field_types[index]
		if type_code < TYPE_U8 or type_code > TYPE_CODE_MAX:
			return Refusal.new(REFUSE_TYPE_CODE, "field '%s' declares type %d"
				% [_field_keys[index], type_code])
		if _field_has_count[index] == 1 and _field_counts[index] < 0:
			return Refusal.new(REFUSE_VALUE_COUNT, "field '%s' declares a negative count"
				% _field_keys[index])
		if type_code != TYPE_UTF8_U32:
			return Refusal.new(REFUSE_NONE, "")
		if _field_max_utf8[index] <= 0:
			return Refusal.new(REFUSE_STRING_CAP_UNDECLARED,
				"type 5 field '%s' has no declared UTF-8 byte cap; u32 is not an allocation permission"
					% _field_keys[index])
		if _field_max_utf8[index] > CHUNK_BYTES - SaveCodec.U32_BYTES:
			return Refusal.new(REFUSE_STRING_CAP_RANGE,
				"field '%s' cap %d exceeds the bounded emitter window"
					% [_field_keys[index], _field_max_utf8[index]])
		return Refusal.new(REFUSE_NONE, "")

	func _validate_key(key: String, role: String) -> Refusal:
		"""SAVE-R09-002: keys are nonempty ASCII, at most 256 UTF-8 bytes."""
		var encoded: PackedByteArray = key.to_utf8_buffer()
		if encoded.size() == 0:
			return Refusal.new(REFUSE_KEY_INVALID, "empty %s key" % role)
		if encoded.size() > MAX_KEY_BYTES:
			return Refusal.new(REFUSE_KEY_INVALID, "%s key '%s' is %d bytes"
				% [role, key, encoded.size()])
		for index: int in encoded.size():
			if encoded[index] > ASCII_MAX:
				return Refusal.new(REFUSE_KEY_INVALID, "%s key '%s' is not ASCII" % [role, key])
		return Refusal.new(REFUSE_NONE, "")


class Builder:
	"""Assembles owner and field rows in declared order, then seals them into a Declaration.

	Appending here is the only growth in this module's construction path and it happens once, at
	build time. The Builder never sorts: the caller supplies the order the registry declares, and
	`Declaration.validate()` is what decides whether that order was right.
	"""
	var _owners: Array = []
	var _fields: Array = []
	var _open_field_count: int = 0

	func begin_owner(section_id: int, owner_key: String, schema_version: int) -> void:
		"""Start a new owner block. Its field count is filled in as fields are added."""
		_owners.append([section_id, owner_key, schema_version, 0])
		_open_field_count = 0

	func add_field(field_key: String, type_code: int, hashed: bool, has_count: bool,
			count: int, max_utf8_bytes: int) -> void:
		"""Append the next field of the open owner, in its declared ordinal position."""
		_fields.append([field_key, type_code, hashed, has_count, count, max_utf8_bytes])
		_open_field_count += 1
		var owner: Array = _owners[_owners.size() - 1]
		owner[3] = _open_field_count

	func seal(identity: String) -> Declaration:
		"""Produce the immutable Declaration. Call `validate()` on it before walking."""
		return Declaration.new(identity, _owners, _fields)


# --- the walker -----------------------------------------------------------------------------------


class Walker:
	"""Walks a Declaration, pulls each field's values from its owner adapter, and hashes them.

	An adapter is any Object exposing `canonical_field_values(field_key: StringName,
	out: FieldValues) -> bool`. The walker drives; an adapter never decides what or when to emit,
	and never decides that a field can be left out.
	"""
	var _declaration: Declaration
	var _adapters: Array = []
	var _values: FieldValues = FieldValues.new()

	func _init(p_declaration: Declaration) -> void:
		"""Bind a declaration and allocate one null adapter slot per declared owner."""
		_declaration = p_declaration
		_adapters.resize(p_declaration.owner_count())

	func declaration() -> Declaration:
		"""The bound declaration."""
		return _declaration

	func register_owner(section_id: int, owner_key: String, adapter: Object) -> Refusal:
		"""Bind one owner's value adapter. Refuses an unknown owner, a repeat or a bad interface."""
		var index: int = _declaration.find_owner(section_id, owner_key)
		if index >= _declaration.owner_count():
			return Refusal.new(REFUSE_UNREGISTERED_OWNER,
				"(%d, '%s') is not declared by %s" % [section_id, owner_key, _declaration.identity()])
		if _adapters[index] != null:
			return Refusal.new(REFUSE_DUPLICATE_ADAPTER,
				"(%d, '%s') already has an adapter" % [section_id, owner_key])
		if adapter == null or not adapter.has_method(ADAPTER_METHOD):
			return Refusal.new(REFUSE_ADAPTER_INTERFACE,
				"(%d, '%s') adapter does not expose %s()" % [section_id, owner_key, ADAPTER_METHOD])
		_adapters[index] = adapter
		return Refusal.new(REFUSE_NONE, "")

	func missing_adapter_owners() -> PackedStringArray:
		"""Every declared owner still without an adapter, as "section:owner_key", in walk order."""
		var missing: PackedStringArray = PackedStringArray()
		for index: int in _declaration.owner_count():
			if _adapters[index] == null:
				missing.append("%d:%s" % [_declaration.owner_section(index),
					_declaration.owner_key(index)])
		return missing

	func adapter_coverage_complete() -> bool:
		"""True when every declared owner has an adapter. False is a refusal, never a subset."""
		for index: int in _declaration.owner_count():
			if _adapters[index] == null:
				return false
		return true

	func covers_release_state() -> bool:
		"""True only for the canonical declaration with complete adapter coverage."""
		return _declaration.covers_release_state() and adapter_coverage_complete()

	func digest_into(inputs: Inputs, result: DigestResult, capture_limit: int) -> Refusal:
		"""Walk the declaration and write the 32 raw SHA-256 bytes into `result`.

		Refuses before hashing a single byte if any declared owner lacks an adapter. `capture_limit`
		above 0 also returns the exact stream bytes, refusing if the stream exceeds that cap.
		"""
		result.clear()
		var structure: Refusal = _declaration.validate()
		if not structure.is_ok():
			return structure
		var coverage: Refusal = _coverage_refusal()
		if not coverage.is_ok():
			return coverage
		var input_refusal: Refusal = _validate_inputs(inputs)
		if not input_refusal.is_ok():
			return input_refusal
		var emitter: Emitter = Emitter.new(CHUNK_BYTES, capture_limit)
		var walk: Refusal = _walk(inputs, emitter)
		if not walk.is_ok():
			return walk
		if not emitter.finish_into(result.digest):
			result.clear()
			return Refusal.new(emitter.refusal_code(), emitter.refusal_detail())
		_fill_result(result, emitter)
		return Refusal.new(REFUSE_NONE, "")

	func verify(inputs: Inputs, expected: PackedByteArray, result: DigestResult) -> Refusal:
		"""Recompute the digest and compare it with `expected`. Refuses on any difference."""
		if expected.size() != DIGEST_BYTES:
			return Refusal.new(REFUSE_DIGEST_LENGTH,
				"expected digest is %d bytes, not 32" % expected.size())
		var refusal: Refusal = digest_into(inputs, result, 0)
		if not refusal.is_ok():
			return refusal
		if result.digest != expected:
			result.clear()
			return Refusal.new(REFUSE_DIGEST_MISMATCH,
				"recomputed canonical state digest does not match the stored one")
		return Refusal.new(REFUSE_NONE, "")

	func _fill_result(result: DigestResult, emitter: Emitter) -> void:
		"""Record what was walked alongside the digest, including the release-coverage claim."""
		result.declaration_id = _declaration.identity()
		result.record_count = _declaration.record_count()
		result.stream_bytes = emitter.total_bytes()
		result.covers_release_state = covers_release_state()
		result.captured_stream = emitter.captured()

	func _coverage_refusal() -> Refusal:
		"""REG-R01: a declared owner without a producer refuses; it is never silently skipped."""
		var missing: PackedStringArray = missing_adapter_owners()
		if missing.size() == 0:
			return Refusal.new(REFUSE_NONE, "")
		return Refusal.new(REFUSE_NO_ADAPTER,
			"%d of %d declared owners have no value adapter: %s"
				% [missing.size(), _declaration.owner_count(), ", ".join(missing)])

	func _validate_inputs(inputs: Inputs) -> Refusal:
		"""Check the four compatibility digests, the engine identity line and the completed tick."""
		var named: Array = [["rules", inputs.rules_digest], ["catalog", inputs.catalog_digest],
			["map", inputs.map_digest], ["lookup", inputs.lookup_digest]]
		for entry: Array in named:
			var digest: PackedByteArray = entry[1]
			if digest.size() != DIGEST_BYTES:
				return Refusal.new(REFUSE_DIGEST_LENGTH,
					"%s identity is %d bytes, not 32" % [entry[0], digest.size()])
		if inputs.completed_tick < 0:
			return Refusal.new(REFUSE_NEGATIVE_TICK,
				"completed tick %d is negative" % inputs.completed_tick)
		return _validate_engine_identity(inputs.engine_identity_line)

	func _validate_engine_identity(line: String) -> Refusal:
		"""SAVE-R09-003's engine line: nonempty ASCII, one trailing LF, at most 256 UTF-8 bytes."""
		var encoded: PackedByteArray = line.to_utf8_buffer()
		if encoded.size() == 0:
			return Refusal.new(REFUSE_ENGINE_IDENTITY, "engine identity line is empty")
		if encoded.size() > MAX_ENGINE_IDENTITY_BYTES:
			return Refusal.new(REFUSE_ENGINE_IDENTITY,
				"engine identity line is %d bytes, over the 256-byte cap" % encoded.size())
		if not line.ends_with(ENGINE_IDENTITY_TERMINATOR):
			return Refusal.new(REFUSE_ENGINE_IDENTITY, "engine identity line has no final LF")
		for index: int in encoded.size() - 1:
			if encoded[index] > ASCII_MAX or encoded[index] < 32:
				return Refusal.new(REFUSE_ENGINE_IDENTITY,
					"engine identity byte %d is outside printable ASCII" % index)
		return Refusal.new(REFUSE_NONE, "")

	func _walk(inputs: Inputs, emitter: Emitter) -> Refusal:
		"""Emit the RWL-STATE-1 prefix, then every record, in declared order."""
		var prefix: Refusal = _emit_prefix(inputs, emitter)
		if not prefix.is_ok():
			return prefix
		for owner: int in _declaration.owner_count():
			var owner_refusal: Refusal = _emit_owner(owner, emitter)
			if not owner_refusal.is_ok():
				return owner_refusal
		return Refusal.new(REFUSE_NONE, "")

	func _emit_prefix(inputs: Inputs, emitter: Emitter) -> Refusal:
		"""SAVE-R09 stream items 1-5: tag, four digests, engine line, completed tick, count."""
		emitter.put_raw(STREAM_TAG.to_utf8_buffer())
		emitter.put_raw(inputs.rules_digest)
		emitter.put_raw(inputs.catalog_digest)
		emitter.put_raw(inputs.map_digest)
		emitter.put_raw(inputs.lookup_digest)
		emitter.put_utf8_u32(inputs.engine_identity_line, MAX_ENGINE_IDENTITY_BYTES)
		emitter.put_i64(inputs.completed_tick)
		emitter.put_u32(_declaration.record_count())
		if emitter.failed():
			return Refusal.new(emitter.refusal_code(), emitter.refusal_detail())
		return Refusal.new(REFUSE_NONE, "")

	func _emit_owner(owner: int, emitter: Emitter) -> Refusal:
		"""Emit one owner's hashed fields in declared ordinal order, skipping its exclusions."""
		var adapter: Object = _adapters[owner]
		var begin: int = _declaration.owner_field_begin(owner)
		for offset: int in _declaration.owner_field_count(owner):
			var index: int = begin + offset
			if not _declaration.field_is_hashed(index):
				continue
			var record: Refusal = _emit_record(owner, index, adapter, emitter)
			if not record.is_ok():
				return record
		return Refusal.new(REFUSE_NONE, "")

	func _emit_record(owner: int, index: int, adapter: Object, emitter: Emitter) -> Refusal:
		"""One record: section_id:u32, owner_key, field_key, type:u8, value_count:u64, values."""
		_values.clear()
		var field_key: String = _declaration.field_key(index)
		if not adapter.call(ADAPTER_METHOD, StringName(field_key), _values):
			return Refusal.new(REFUSE_ADAPTER_REFUSED, "owner '%s' refused field '%s': %s %s"
				% [_declaration.owner_key(owner), field_key, _values.refusal, _values.detail])
		var shape: Refusal = _check_values(index, field_key)
		if not shape.is_ok():
			return shape
		emitter.put_u32(_declaration.owner_section(owner))
		emitter.put_utf8_u32(_declaration.owner_key(owner), MAX_KEY_BYTES)
		emitter.put_utf8_u32(field_key, MAX_KEY_BYTES)
		emitter.put_u8(_declaration.field_type(index))
		emitter.put_u64(_values.count)
		if emitter.failed():
			return Refusal.new(emitter.refusal_code(), emitter.refusal_detail())
		return _emit_values(index, emitter)

	func _check_values(index: int, field_key: String) -> Refusal:
		"""Check the adapter's storage form and count against what the field declares."""
		var type_code: int = _declaration.field_type(index)
		if not _storage_allowed(type_code, _values.storage):
			return Refusal.new(REFUSE_STORAGE_MISMATCH,
				"field '%s' type %d cannot be emitted from storage form %d"
					% [field_key, type_code, _values.storage])
		if _declaration.field_has_declared_count(index):
			var declared: int = _declaration.field_declared_count(index)
			if _values.count != declared:
				return Refusal.new(REFUSE_VALUE_COUNT,
					"field '%s' declares %d values, adapter supplied %d"
						% [field_key, declared, _values.count])
		return Refusal.new(REFUSE_NONE, "")

	func _emit_values(index: int, emitter: Emitter) -> Refusal:
		"""Emit the field's values in the declared type encoding, then report any emitter refusal."""
		var type_code: int = _declaration.field_type(index)
		if type_code == TYPE_UTF8_U32:
			_emit_texts(_declaration.field_max_utf8_bytes(index), emitter)
		else:
			var range_refusal: Refusal = _emit_integers(type_code, emitter)
			if not range_refusal.is_ok():
				return range_refusal
		if emitter.failed():
			return Refusal.new(emitter.refusal_code(), emitter.refusal_detail())
		return Refusal.new(REFUSE_NONE, "")

	func _emit_texts(max_bytes: int, emitter: Emitter) -> void:
		"""Type 5: each value carries its own u32 UTF-8 BYTE-length prefix, never a char count."""
		for position: int in _values.count:
			if not emitter.put_utf8_u32(_values.texts[position], max_bytes):
				return

	func _emit_integers(type_code: int, emitter: Emitter) -> Refusal:
		"""Types 0-4, each from the storage form the adapter declared. See the sign-trap note."""
		if type_code == TYPE_U8:
			for position: int in _values.count:
				emitter.put_u8(_values.bytes[position])
			return Refusal.new(REFUSE_NONE, "")
		if type_code == TYPE_I32:
			for position: int in _values.count:
				emitter.put_i32(_values.int32s[position])
			return Refusal.new(REFUSE_NONE, "")
		if type_code == TYPE_U32:
			return _emit_u32(emitter)
		return _emit_wide(type_code, emitter)

	func _emit_u32(emitter: Emitter) -> Refusal:
		"""u32 from i32 bit patterns, or from logical i64 values range-checked against 0..2^32-1."""
		if _values.storage == STORAGE_INT32:
			for position: int in _values.count:
				emitter.put_u32(SaveCodec.int32_bits_to_u32(_values.int32s[position]))
			return Refusal.new(REFUSE_NONE, "")
		for position: int in _values.count:
			var value: int = _values.int64s[position]
			if value < 0 or value > SaveCodec.UINT32_MAX:
				return Refusal.new(REFUSE_VALUE_RANGE,
					"u32 value %d at index %d is outside 0..4294967295" % [value, position])
			emitter.put_u32(value)
		return Refusal.new(REFUSE_NONE, "")

	func _emit_wide(type_code: int, emitter: Emitter) -> Refusal:
		"""u64 and i64. A negative u64 refuses: GDScript cannot hold the upper half of that range."""
		if type_code == TYPE_I64:
			for position: int in _values.count:
				emitter.put_i64(_values.int64s[position])
			return Refusal.new(REFUSE_NONE, "")
		for position: int in _values.count:
			var value: int = _values.int64s[position]
			if value < 0:
				return Refusal.new(REFUSE_VALUE_RANGE,
					"u64 value at index %d is negative as a GDScript int" % position)
			emitter.put_u64(value)
		return Refusal.new(REFUSE_NONE, "")

	func _storage_allowed(type_code: int, storage: int) -> bool:
		"""The fixed type-to-storage table. No inference, no default, no silent widening."""
		if type_code == TYPE_U8:
			return storage == STORAGE_BYTE
		if type_code == TYPE_U32:
			return storage == STORAGE_INT32 or storage == STORAGE_INT64
		if type_code == TYPE_I32:
			return storage == STORAGE_INT32
		if type_code == TYPE_U64 or type_code == TYPE_I64:
			return storage == STORAGE_INT64
		return storage == STORAGE_TEXT


# --- module entry points --------------------------------------------------------------------------

static var _production: Declaration = null


static func ascii_compare(left: String, right: String) -> int:
	"""Byte-wise ASCII comparison: -1, 0 or 1. Explicit, so no locale or case rule can creep in."""
	var a: PackedByteArray = left.to_utf8_buffer()
	var b: PackedByteArray = right.to_utf8_buffer()
	var shared: int = mini(a.size(), b.size())
	for index: int in shared:
		if a[index] < b[index]:
			return -1
		if a[index] > b[index]:
			return 1
	if a.size() < b.size():
		return -1
	if a.size() > b.size():
		return 1
	return 0


static func production_declaration() -> Declaration:
	"""The canonical declaration compiled from the checked-in registry. Built once, then shared."""
	if _production != null:
		return _production
	var builder: Builder = Builder.new()
	var field_index: int = 0
	for owner: int in CANONICAL_OWNER_COUNT:
		builder.begin_owner(int(OWNER_SECTIONS[owner]), String(OWNER_KEYS[owner]),
			int(OWNER_VERSIONS[owner]))
		for _offset: int in int(OWNER_FIELD_COUNTS[owner]):
			_add_generated_field(builder, field_index)
			field_index += 1
	_production = builder.seal(DECLARATION_ID)
	return _production


static func _add_generated_field(builder: Builder, index: int) -> void:
	"""Append one generated field row, expanding the sparse exclusion/count/cap tables."""
	var count_slot: int = FIELD_COUNT_INDEXES.find(index)
	var cap_slot: int = FIELD_MAX_UTF8_INDEXES.find(index)
	builder.add_field(String(FIELD_KEYS[index]), int(FIELD_TYPES[index]),
		not FIELD_EXCLUDED_INDEXES.has(index), count_slot >= 0,
		int(FIELD_COUNT_VALUES[count_slot]) if count_slot >= 0 else 0,
		int(FIELD_MAX_UTF8_VALUES[cap_slot]) if cap_slot >= 0 else 0)


static func production_walker() -> Walker:
	"""A walker over the canonical declaration with NO adapters registered.

	Every owner must be registered by its own module before `digest_into()` will produce anything.
	As of ADR 0127 not one adapter exists, so this walker refuses with CANONICAL_NO_ADAPTER and
	lists all 52 owners. That refusal IS the deliverable; do not paper over it with empty bytes.
	"""
	return Walker.new(production_declaration())


# --- BEGIN GENERATED DECLARATION TABLE ---
# Generated from docs/planning/canonical_state_registry.json by
# tools/generate_canonical_state_table.py. Do not hand-edit: test_canonical_state_hash.gd
# re-reads that JSON and proves every entry below equals it.
#   registry_id RWL-CANONICAL-REGISTRY-2026-09-15-3, registry_version 5
#   52 owners, 610 declared fields, 602 canonical records, 553 persisted packed fields.

const DECLARATION_ID: String = "RWL-CANONICAL-REGISTRY-2026-09-15-3"
const DECLARATION_VERSION: int = 5
const CANONICAL_OWNER_COUNT: int = 52
const CANONICAL_FIELD_COUNT: int = 610
const CANONICAL_RECORD_COUNT: int = 602

const OWNER_SECTIONS: Array = [
	1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 3, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 5, 5, 5,
	5, 5, 6, 6, 6, 7, 7, 7, 7, 7, 7, 8, 9, 9, 10, 11, 12, 12, 13, 14
]

const OWNER_KEYS: Array = [
	"buildings", "entity_directory", "farming", "forage", "resource_nodes", "spatial_world",
	"weather", "world_init", "world_runtime", "movement", "entity_directory", "buildings",
	"construction", "farming", "field_policy", "fishing", "forage", "injury", "jobs", "movement",
	"needs", "orchard_hive", "priorities", "residents", "resource_nodes", "schedule", "transforms",
	"work", "world_init", "buildings", "construction", "forage", "jobs", "orchard_hive",
	"command_dispatch", "crop_weather", "ecology", "fishing", "forage", "gear", "inventory",
	"reservations", "stock_age", "job_planner", "movement", "navigation", "rng", "event_schedule",
	"commands", "scheduler_events", "chronicle", "residents"
]

const OWNER_VERSIONS: Array = [
	1, 1, 1, 1, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 1, 1, 2, 1, 1, 1, 2, 1, 1, 1, 1,
	1, 1, 1, 1, 1, 1, 1, 1, 3, 1, 1, 2, 1, 2, 1, 1, 2, 1, 1, 1
]

const OWNER_FIELD_COUNTS: Array = [
	3, 1, 10, 1, 1, 5, 2, 9, 12, 1, 6, 29, 16, 15, 20, 22, 20, 11, 38, 16, 20, 25, 4, 19, 10, 6, 9,
	9, 9, 15, 1, 10, 4, 2, 4, 2, 1, 7, 11, 12, 30, 8, 6, 35, 9, 57, 2, 8, 20, 14, 2, 1
]

const FIELD_KEYS: Array = [
	"_building_slot", "_room_slot", "_furniture_slot", "_next_persistent_id", "_tile_fertility",
	"_tile_last_family", "_tile_family_streak", "_tile_last_legume_day", "_tile_compost_season",
	"_tile_active_plot_row", "_tile_orchard_row", "_tile_ripe_tick", "_tile_growth_remainder",
	"_tile_tended_today", "_tile_link_head", "_resource_slot", "_map_revision", "_walkable",
	"_layer", "_terrain", "_height_units", "_row", "_row64", "_published", "_published_seed",
	"_terrain", "_soil", "_basin", "_cleared", "_basin_ref_slot", "_basin_ref_generation",
	"_basin_danger", "_completed_tick", "_world_seed", "_seeded", "_requested_speed", "_pause_mask",
	"_debt", "_fallback_count", "_diagnostic_pause_count", "_acknowledged_catchup_resets",
	"_acknowledged_ticks_discarded", "_subtick_debt_discards", "_day_boundaries_crossed",
	"_profile_revision", "_active", "_generation", "_retired", "_persistent_id", "_kind",
	"_typed_row", "_b_present", "_r_present", "_f_present", "_b_type_id", "_b_tier",
	"_b_origin_tile", "_b_rotation", "_b_state", "_b_condition", "_b_construction_slot",
	"_b_construction_generation", "_b_interior_id", "_r_type", "_r_building_slot",
	"_r_building_generation", "_r_tile_offset", "_r_tile_count", "_r_temperature_tenths",
	"_r_furniture_mask", "_r_occupants", "_r_valid", "_f_type_id", "_f_room_slot",
	"_f_room_generation", "_f_origin_tile", "_f_rotation", "_f_user_slot", "_f_user_generation",
	"_f_condition", "_present", "_material_container_slot", "_material_container_generation",
	"_assigned_count", "_max_workers", "_refund_policy", "_remaining_mwu", "_paused", "_work_begun",
	"_ref_slot", "_ref_generation", "_subject_slot", "_subject_generation", "_purpose", "_type_id",
	"_phase", "_present", "_crop_id", "_state", "_soil", "_fertility", "_moisture",
	"_growth_milli_hours", "_health", "_last_family", "_family_streak", "_compost_milli",
	"_sow_day", "_tile", "_ref_slot", "_ref_generation", "_field_present", "_zone_slot",
	"_zone_generation", "_rotation_ids", "_rotation_cursor", "_auto_rotation", "_seed_reserve",
	"_cycle_ordinal", "_participants", "_resolved", "_withdrawn", "_completed_cycles",
	"_cancelled_cycles", "_requested_crop", "_cycle_state", "_close_reason", "_request_state",
	"_plot_field_slot", "_plot_cycle", "_plot_outcome", "_habitat_present", "_stock_present",
	"_habitat_type", "_habitat_zone_slot", "_habitat_zone_generation", "_habitat_effort_slots",
	"_habitat_pollution", "_habitat_danger", "_habitat_protected_fraction",
	"_habitat_capacity_milli", "_habitat_ref_slot", "_habitat_ref_generation",
	"_habitat_effort_used", "_habitat_intensive", "_stock_habitat_slot",
	"_stock_habitat_generation", "_stock_species_id", "_stock_population_milli",
	"_stock_capacity_milli", "_stock_harvested_today_milli", "_stock_closed", "_stock_restocking",
	"_zone_present", "_patch_present", "_zone_type", "_zone_danger", "_zone_quota_milli",
	"_zone_protected", "_zone_enabled", "_zone_ref_slot", "_zone_ref_generation",
	"_zone_basin_slot", "_zone_basin_generation", "_zone_harvested_today_milli",
	"_zone_quota_reserved_milli", "_zone_quota_mode", "_patch_item_id", "_patch_zone_slot",
	"_patch_zone_generation", "_patch_stock_milli", "_patch_capacity_milli",
	"_patch_harvested_year_milli", "_present", "_kind", "_airless_episode", "_exhaustion_latch",
	"_care_context_blocked", "_severity", "_rescuer_slot", "_rescuer_generation",
	"_untreated_ticks", "_care_progress_mwu", "_last_incident_ordinal", "_job_present",
	"_agent_present", "_kind", "_requester_slot", "_requester_generation", "_destination_slot",
	"_destination_generation", "_source_slot", "_source_generation", "_priority", "_required_skill",
	"_state", "_worker_slot", "_worker_generation", "_remaining_mwu", "_created_tick",
	"_job_ref_slot", "_job_ref_generation", "_urgency", "_dangerous", "_station_gate", "_tool_gate",
	"_unlock_gate", "_inputs_gate", "_is_coordinator", "_agent_job_slot", "_agent_job_generation",
	"_agent_phase", "_agent_target_slot", "_agent_target_generation", "_agent_path_id",
	"_agent_path_cursor", "_agent_lease_expiry", "_agent_blocked_tick", "_agent_manual_until",
	"_agent_hazard_locked", "_job_scan_cursor", "_continuation_bucket", "_vx", "_vz",
	"_remainder_x", "_remainder_z", "_next_x", "_next_z", "_correction_x", "_correction_z",
	"_radius_u", "_desired_yaw", "_next_yaw", "_grid_next", "_grid_cell", "_speed_u_per_s",
	"_movement_phase", "_blocked_ticks", "_present", "_need_value", "_need_remainder", "_health",
	"_health_remainder", "_cold_milli_hours", "_cold_remainder", "_starving_ticks",
	"_departure_days", "_status", "_size_class", "_activity", "_comfort_environment",
	"_social_paired", "_purpose_source", "_cold_environment", "_clothing_tier", "_infirmary",
	"_injury_state", "_airless", "_o_present", "_h_present", "_o_species_id", "_o_age_days",
	"_o_health", "_o_chill_days", "_o_tended_today", "_o_harvested_year", "_o_origin_x",
	"_o_origin_z", "_o_ref_slot", "_o_ref_generation", "_h_building_slot", "_h_building_generation",
	"_h_strength", "_h_serviced_day", "_h_feed_milli", "_h_honey_milli", "_h_wax_milli",
	"_h_min_tile_x", "_h_min_tile_z", "_h_max_tile_x", "_h_max_tile_z", "_h_ref_slot",
	"_h_ref_generation", "_present", "_job_priority", "_auto_fallback", "_dangerous_work",
	"_present", "_species", "_size_class", "_named", "_life_stage", "_arrival_tick", "_role",
	"_home_slot", "_home_generation", "_bed_slot", "_bed_generation", "_ref_slot",
	"_ref_generation", "_equip_tool_item_id", "_equip_tool_durability", "_equip_satchel_slot",
	"_equip_satchel_generation", "_skill_xp", "_skill_level", "_present", "_resource_id",
	"_quantity_milli", "_capacity_milli", "_regrow_days", "_planted_day", "_exhausted", "_tile",
	"_ref_slot", "_ref_generation", "_present", "_hourly_activity", "_template",
	"_current_activity", "_sleep_satisfied", "_resolved", "_bound_persistent_id", "_x", "_y", "_z",
	"_yaw", "_prev_x", "_prev_y", "_prev_z", "_prev_yaw", "_potential_remainder", "_xp_remainder",
	"_memory_total", "_wear_remainder", "_tool_lot_slot", "_tool_lot_generation", "_tool_job_slot",
	"_tool_job_generation", "_tool_broken", "_fauna_zone_slot", "_fauna_zone_generation",
	"_fauna_species_id", "_fauna_population", "_fauna_capacity", "_fauna_tracks",
	"_fauna_harvest_today", "_fauna_migration_link", "_fauna_birth_remainder", "_b_ref_slot",
	"_b_ref_generation", "_b_room_head", "_b_room_count", "_r_ref_slot", "_r_ref_generation",
	"_r_building_next", "_r_building_prev", "_r_furniture_head", "_r_furniture_count",
	"_f_ref_slot", "_f_ref_generation", "_f_room_next", "_f_room_prev", "_room_tile_id",
	"_delivered_milli", "_link_bump", "_link_free_head", "_link_used", "_zone_link_head",
	"_zone_tile_count", "_zone_patch_count", "_link_tile", "_link_zone", "_link_tile_next",
	"_link_zone_next", "_coordinator_slot", "_coordinator_generation", "_member_head",
	"_member_next", "_link_hive_slot", "_link_hive_generation", "_intent_player_id",
	"_intent_sequence_high", "_intent_sequence_low", "_intent_zone_generation", "_last_day",
	"_last_hour_tick", "_last_day", "_effort_claim_active", "_effort_claim_expedition_generation",
	"_effort_claim_habitat_slot", "_effort_claim_habitat_generation", "_effort_claim_job_slot",
	"_effort_claim_job_generation", "_effort_claim_slot_count", "_claim_active", "_claim_job_slot",
	"_claim_job_generation", "_claim_designation_slot", "_claim_designation_generation",
	"_claim_basin_slot", "_claim_basin_generation", "_claim_patch_kind", "_claim_remaining_milli",
	"_claim_created_tick", "_claim_persistent_id", "_occupied", "_lot_slot", "_lot_generation",
	"_item_id", "_durability", "_durability_cap", "_owner_slot", "_owner_generation",
	"_manufacture_recipe", "_equipped", "_claim_job_slot", "_claim_job_generation", "_c_free_count",
	"_l_free_count", "_c_live", "_l_live", "_c_generation", "_l_generation", "_c_owner_slot",
	"_c_owner_generation", "_c_policy", "_c_lot_count", "_c_first_lot", "_c_max_mass_g",
	"_c_filters", "_c_reserved_mass_g", "_c_used_mass_g", "_c_reachable", "_l_item_id",
	"_l_quality", "_l_provenance", "_l_recipe_id", "_l_container_slot", "_l_container_generation",
	"_l_next", "_l_prev", "_l_quantity_milli", "_l_reserved_milli", "_l_age_milli_hours",
	"_l_age_remainder", "_c_free", "_l_free", "_occupied", "_r_job_slot", "_r_job_generation",
	"_r_lot_slot", "_r_lot_generation", "_r_purpose", "_r_quantity_milli", "_r_expiry",
	"_declared_count", "_last_hour_tick", "_c_storage_class", "_c_heated_interior",
	"_c_declared_generation", "_declared_slots", "_owner_slot", "_owner_generation", "_service_day",
	"_job_slot", "_job_generation", "_serviced_day", "_status", "_requires_water", "_field_cycle",
	"_requested_crop", "_gate_reason", "_cycle_cursor", "_completed_cycle", "_demand_enabled",
	"_demand_owner_slot", "_demand_owner_generation", "_demand_status", "_demand_blocker",
	"_demand_job_slot", "_demand_job_generation", "_demand_quantified_milli", "_hive_owner_slot",
	"_hive_owner_generation", "_hive_service_day", "_hive_job_slot", "_hive_job_generation",
	"_hive_feed_demand_milli", "_hive_status", "_hive_blocker", "_dirty_rows", "_dirty_count",
	"_dirty_zone_rows", "_dirty_zone_count", "_dirty_hive_rows", "_dirty_hive_count",
	"_cursor_owner_id", "_cursor_request", "_cursor_route_generation", "_cursor_index",
	"_cursor_profile_id", "_cursor_profile_revision", "_cursor_mode", "_cursor_load_g",
	"_cursor_destination_revision", "_search_serial", "_heap_size", "_search_goal",
	"_search_origin", "_search_macro", "_search_clearance", "_expansions_remaining",
	"_expansions_total", "_arena_used", "_free_request_head", "_queue_head", "_active_request",
	"_served_revision", "_stamp", "_d_flags", "_d_generation", "_r_phase", "_g", "_parent", "_heap",
	"_heap_position", "_state", "_arena", "_d_route_id", "_d_start_macro", "_d_goal_cell",
	"_d_clearance", "_d_map_revision", "_d_variant_start", "_d_anchor", "_d_offset", "_d_count",
	"_d_refcount", "_d_use_low", "_d_use_high", "_d_next_variant", "_d_reserved", "_r_job_slot",
	"_r_job_generation", "_r_start_cell", "_r_goal_cell", "_r_clearance", "_r_start_macro",
	"_r_map_revision", "_r_route_id", "_r_route_generation", "_r_created_low", "_r_created_high",
	"_r_next_queue", "_r_exact_start", "_r_anchor", "_r_expansions", "_c_start_owner_slot",
	"_c_start_owner_generation", "_c_goal_owner_slot", "_c_goal_owner_generation",
	"_c_requester_persistent_id", "_state", "_draw_count", "_next_sequence", "_count", "_kind",
	"_source_id", "_arg0", "_arg1", "_due_tick", "_sequence", "_count", "_payload_used",
	"_next_sequence_high", "_next_sequence_low", "_execute_tick", "_player_id", "_sequence_low",
	"_sequence_high", "_kind", "_target_slot", "_target_generation", "_goal_x", "_goal_z", "_arg0",
	"_arg1", "_payload_offset", "_payload_length", "_flags", "_reserved_zero", "_payload", "_head",
	"_count", "_next_sequence_low", "_next_sequence_high", "_last_applied_sequence_low",
	"_last_applied_sequence_high", "_last_drained_boundary", "_boundary_tick", "_sequence_low",
	"_sequence_high", "_kind", "_reason", "_value", "_reserved", "_count", "_rolling_digest",
	"_name_key"
]

const FIELD_TYPES: Array = [
	2, 2, 2, 1, 2, 2, 2, 2, 2, 2, 2, 4, 4, 0, 2, 2, 2, 0, 0, 2, 2, 2, 4, 0, 2, 0, 0, 0, 0, 2, 2, 2,
	4, 2, 0, 2, 2, 4, 4, 4, 4, 4, 4, 4, 2, 0, 2, 0, 2, 2, 2, 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
	2, 2, 2, 2, 2, 2, 2, 0, 2, 2, 2, 2, 2, 2, 2, 2, 0, 2, 2, 2, 2, 2, 4, 0, 0, 2, 2, 2, 2, 2, 2, 2,
	0, 2, 2, 2, 2, 2, 4, 2, 2, 2, 4, 2, 2, 2, 2, 0, 2, 2, 2, 2, 0, 0, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0,
	2, 2, 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 4, 2, 2, 2, 0, 2, 2, 2, 4, 4, 4, 0, 0, 0, 0, 2, 2, 4, 0, 0,
	2, 2, 2, 2, 4, 4, 0, 2, 2, 2, 4, 4, 4, 0, 0, 0, 0, 0, 2, 2, 2, 4, 4, 4, 0, 0, 2, 2, 2, 2, 2, 2,
	2, 2, 2, 2, 2, 2, 4, 4, 2, 2, 0, 0, 0, 0, 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 4, 4, 4, 0, 2, 0, 2, 2,
	2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 0, 2, 4, 2, 4, 4, 4, 4, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 2, 2, 2, 2, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2, 4, 4, 4, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 0,
	2, 0, 0, 0, 4, 0, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 4, 2, 0, 2, 4, 4, 2, 2, 0, 2, 2, 2, 0, 0, 2, 2,
	0, 0, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 0, 2, 2, 2, 2, 2, 2, 2, 2, 4, 2, 2, 2,
	2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 4, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
	2, 2, 4, 2, 0, 2, 2, 2, 2, 2, 2, 0, 2, 2, 2, 2, 2, 2, 2, 4, 4, 4, 0, 2, 2, 2, 2, 2, 2, 2, 2, 0,
	2, 2, 1, 1, 0, 0, 2, 2, 2, 2, 2, 2, 2, 4, 4, 4, 4, 0, 2, 2, 2, 2, 2, 2, 2, 2, 4, 4, 4, 4, 2, 2,
	0, 2, 2, 2, 2, 2, 4, 4, 1, 4, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 2, 2, 0, 2, 2, 0, 2, 2, 0, 0,
	2, 2, 4, 2, 2, 2, 2, 2, 4, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
	2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 0, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
	2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 1, 4, 4, 1, 2, 2, 2, 2, 4, 4, 1, 1, 3,
	1, 4, 2, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 0, 1, 1, 1, 1, 1, 1, 4, 4, 1, 1, 2, 2, 2, 2, 3,
	0, 5
]

## Field indexes the registry marks hash=false: emitted by no record. See hash_location.
const FIELD_EXCLUDED_INDEXES: Array = [
	32, 37, 38, 39, 40, 41, 42, 43
]

## Sparse (index, value) pairs for fields whose shape declares an exact element count.
const FIELD_COUNT_INDEXES: Array = [
	3, 16, 23, 24, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 365, 366, 367, 385, 386, 387,
	418, 419, 456, 457, 492, 494, 496, 506, 507, 508, 509, 510, 511, 512, 513, 514, 515, 516, 517,
	518, 565, 566, 573, 574, 575, 576, 593, 594, 595, 596, 597, 598, 599, 607, 608
]
const FIELD_COUNT_VALUES: Array = [
	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
	1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 32
]

## Sparse (index, value) pairs for type-5 fields' declared UTF-8 byte cap (SAVE-R09-002).
const FIELD_MAX_UTF8_INDEXES: Array = [
	609
]
const FIELD_MAX_UTF8_VALUES: Array = [
	128
]
# --- END GENERATED DECLARATION TABLE ---
