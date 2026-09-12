extends RefCounted
## ARCH-SAVE-001's canonical encoding primitives: explicit little-endian integers, two's-complement
## bit representation, length-prefixed UTF-8, bounded reads, and a refusal instead of a bad number.
##
## WHAT ARCH-SAVE-001 ACTUALLY SAYS (systems_architecture.md:688), and what is implemented here:
##
##   * "All saved integers use explicit little-endian encoding" -- every write/read below goes
##     through `PackedByteArray.encode_*`/`decode_*`, which Godot documents as little-endian, at an
##     explicit byte offset. No struct packing, no machine-native dump.
##   * "two's-complement bit representation" -- `u32_bits_to_int32()` and `int32_bits_to_u32()` are
##     the only reinterpretation allowed, and both are total functions over their input domain.
##   * "strings use length-prefixed UTF-8 without object serialization" -- `read_utf8_*` /
##     `write_utf8_*` below. The prefix WIDTH is the unresolved part; see BLOCKER S1.
##   * "No engine Resource serializer, Dictionary order, RID, NodePath, or machine-native memory
##     dump is the canonical format" -- nothing here touches any of those. There is no Dictionary
##     in this module, so there is no iteration order to be nondeterministic about.
##
## BLOCKER S1 -- THE STRING LENGTH PREFIX WIDTH IS NOT SPECIFIED. ARCH-SAVE-001 says
## "length-prefixed UTF-8" and stops. ARCH-SAVE-005 (systems_architecture.md:747) requires
## rejecting "illegal negative lengths", which is only meaningful for a SIGNED prefix, and
## requires rejecting "malformed UTF-8". Searched: systems_architecture.md §8 in full,
## game_gdd.md, gameplay_balance.md, ui_ux_controls.md, docs/rulings/, docs/decisions/ and the
## whole docs/ tree for "length-prefix", "length prefix", "prefixed UTF-8". The only other
## mentions are persistence_state_registry.md:444 quoting ARCH-SAVE-001 back, and decision 0043,
## which measures a NAME_RESIDENT alias in CHARACTERS after the command envelope's own i32
## `payload_length` -- a different field. So this module refuses to pick one: it exposes the u32
## form and the i32 form as separate, explicitly named primitives and leaves the choice of which
## field uses which to 09.2's schema. Neither is a default.
##
## BLOCKER S2 -- NO STRING BYTE CAP IS SPECIFIED. Every string read therefore takes an explicit
## `max_bytes` from its caller. There is no built-in maximum here to be wrong about, and the
## remaining-buffer bound is applied on top of the caller's whatever it says.
##
## REFUSALS ARE NEVER IN-BAND. Nothing here returns -1, 0 or a clamped value to mean failure
## (decision 0059; the H4 sentinel int_math.gd's header names). A read writes into a caller-owned
## `Scalar`/`Text` and returns a bool; a refused read leaves `.ok == false`, a zeroed/empty value
## and a `.refusal` code, and does NOT advance the cursor.
##
## STICKY READER FAILURE. Once a `Reader` refuses, every later read on it refuses with the FIRST
## refusal and the cursor never moves again. A decoder cannot be walked off the end of a buffer by
## ignoring one return value, and cannot accumulate a half-decoded record. `Reader.reset()` is the
## only way back, and it rewinds to the start.
##
## ALLOCATE BEFORE CONSUME (decision 0059). Every length is validated against the remaining bytes
## BEFORE any `resize()`. A hostile length prefix -- negative, larger than the buffer, or larger
## than the caller's cap -- is refused without allocating a single byte for it.
##
## u64 AND GDScript. GDScript's `int` is signed 64-bit, so the upper half of the u64 range is
## unrepresentable. A u64 field whose high bit is set is REFUSED on read
## (REFUSE_UNREPRESENTABLE_U64) rather than silently surfacing as a negative int64 -- the exact
## class of confusion that turning `0x80000000` into a "positive" GDScript int causes at 32 bits.
##
## FLOAT. There is no float path in this module and there must never be one: ARCH-AUTH-002 makes
## every authoritative value an integer and `presentation_extract.gd` (ARCH-SYS-023) is the sole
## float boundary. `test_save_codec.gd` greps this file's own source to enforce that.

## Self-preload so the inner Reader/Writer classes can reach this script's own static functions;
## an inner class cannot call them unqualified. Same pattern as `int_math.gd`'s `IntMathScript`.
const SaveCodecScript := preload("res://scripts/core/save_codec.gd")

# --- widths and domains ---------------------------------------------------------------------------

const U8_BYTES: int = 1
const I32_BYTES: int = 4
const U32_BYTES: int = 4
const I64_BYTES: int = 8
const U64_BYTES: int = 8

const UINT8_MAX: int = 255
const UINT32_MAX: int = 4294967295
const UINT32_MODULUS: int = 4294967296
const UINT32_SIGN_BIT: int = 2147483648
const INT32_MIN: int = -2147483648
const INT32_MAX: int = 2147483647
const INT64_MIN: int = -9223372036854775807 - 1
const INT64_MAX: int = 9223372036854775807

## The largest u64 a GDScript int can hold. Bit patterns above this are refused, never wrapped.
const UINT64_REPRESENTABLE_MAX: int = INT64_MAX

## Signedness selectors. i32/u32 share a width and so do i64/u64, so no read or write in this
## module infers signedness from a byte count -- it is always passed in.
const SIGNEDNESS_UNSIGNED: int = 0
const SIGNEDNESS_SIGNED: int = 1

# --- refusal codes ----------------------------------------------------------------------------------

const REFUSE_NONE: StringName = &""
const REFUSE_NEGATIVE_OFFSET: StringName = &"SAVE_CODEC_NEGATIVE_OFFSET"
const REFUSE_TRUNCATED: StringName = &"SAVE_CODEC_TRUNCATED"
const REFUSE_VALUE_RANGE: StringName = &"SAVE_CODEC_VALUE_RANGE"
const REFUSE_NEGATIVE_LENGTH: StringName = &"SAVE_CODEC_NEGATIVE_LENGTH"
const REFUSE_NEGATIVE_LIMIT: StringName = &"SAVE_CODEC_NEGATIVE_LIMIT"
const REFUSE_LENGTH_EXCEEDS_BUFFER: StringName = &"SAVE_CODEC_LENGTH_EXCEEDS_BUFFER"
const REFUSE_LENGTH_EXCEEDS_LIMIT: StringName = &"SAVE_CODEC_LENGTH_EXCEEDS_LIMIT"
const REFUSE_UNREPRESENTABLE_U64: StringName = &"SAVE_CODEC_UNREPRESENTABLE_U64"
const REFUSE_MALFORMED_UTF8: StringName = &"SAVE_CODEC_MALFORMED_UTF8"
const REFUSE_UTF8_NOT_ROUND_TRIP: StringName = &"SAVE_CODEC_UTF8_NOT_ROUND_TRIP"
const REFUSE_NONZERO_PADDING: StringName = &"SAVE_CODEC_NONZERO_PADDING"
const REFUSE_SEEK_OUT_OF_RANGE: StringName = &"SAVE_CODEC_SEEK_OUT_OF_RANGE"


class Scalar:
	"""One decoded integer: success flag, value, refusal code and detail. Caller-owned, reusable.

	Mirrors `int_math.gd`'s IntResult shape so the two read the same way, but carries a StringName
	refusal code because a save refusal is matched by code, not by prose.
	"""
	var ok: bool = false
	var value: int = 0
	var refusal: StringName = REFUSE_NONE
	var detail: String = ""

	func succeed(p_value: int) -> bool:
		"""Record a decoded value; always returns true."""
		ok = true
		value = p_value
		refusal = REFUSE_NONE
		detail = ""
		return true

	func refuse(p_refusal: StringName, p_detail: String) -> bool:
		"""Record a refusal with a zeroed value; always returns false.

		The value is zeroed rather than left stale so an ignored return cannot surface an earlier
		read's number as if it were this one's answer.
		"""
		ok = false
		value = 0
		refusal = p_refusal
		detail = p_detail
		return false


class Text:
	"""One decoded length-prefixed UTF-8 string, its byte length, and its refusal. Caller-owned."""
	var ok: bool = false
	var value: String = ""
	var byte_length: int = 0
	var refusal: StringName = REFUSE_NONE
	var detail: String = ""

	func succeed(p_value: String, p_byte_length: int) -> bool:
		"""Record a decoded string and the byte count its prefix declared; always returns true."""
		ok = true
		value = p_value
		byte_length = p_byte_length
		refusal = REFUSE_NONE
		detail = ""
		return true

	func refuse(p_refusal: StringName, p_detail: String) -> bool:
		"""Record a refusal with an empty value and zero length; always returns false."""
		ok = false
		value = ""
		byte_length = 0
		refusal = p_refusal
		detail = p_detail
		return false


# --- two's-complement reinterpretation --------------------------------------------------------------

static func u32_bits_to_int32(bits: int) -> int:
	"""The i32 two's-complement spelling of a u32 bit pattern, so a packed i32 column stores it.

	Deliberately the same function as `commands.gd`'s `to_int32_bits()`; `test_save_codec.gd`
	asserts the two agree across the whole boundary set rather than trusting that they do.
	"""
	var masked: int = bits & UINT32_MAX
	return masked - UINT32_MODULUS if masked >= UINT32_SIGN_BIT else masked


static func int32_bits_to_u32(value: int) -> int:
	"""The u32 bit pattern of an i32 value. Exact inverse of u32_bits_to_int32() over i32."""
	return value & UINT32_MAX


static func fits_u32(value: int) -> bool:
	"""True when `value` is a representable unsigned 32-bit quantity."""
	return value >= 0 and value <= UINT32_MAX


static func fits_i32(value: int) -> bool:
	"""True when `value` is a representable signed 32-bit quantity."""
	return value >= INT32_MIN and value <= INT32_MAX


static func fits_u64(value: int) -> bool:
	"""True when `value` is a u64 a GDScript int can hold, i.e. its high bit is clear."""
	return value >= 0


# --- bounded fixed-offset writes ----------------------------------------------------------------------

static func _write_room(out: PackedByteArray, offset: int, width: int, result: Scalar) -> bool:
	"""Check that `width` bytes fit at `offset` in `out`, without any offset+width overflow."""
	if offset < 0:
		return result.refuse(REFUSE_NEGATIVE_OFFSET, "offset %d is negative" % offset)
	if out.size() < width or offset > out.size() - width:
		return result.refuse(REFUSE_TRUNCATED,
			"%d bytes at offset %d do not fit in a %d-byte buffer" % [width, offset, out.size()])
	return result.succeed(offset)


static func write_u8_into(out: PackedByteArray, offset: int, value: int, result: Scalar) -> bool:
	"""Write one unsigned byte at `offset`. Refuses out-of-range values and a short buffer."""
	if value < 0 or value > UINT8_MAX:
		return result.refuse(REFUSE_VALUE_RANGE, "%d is not a u8" % value)
	if not _write_room(out, offset, U8_BYTES, result):
		return false
	out.encode_u8(offset, value)
	return result.succeed(value)


static func write_u32_into(out: PackedByteArray, offset: int, value: int, result: Scalar) -> bool:
	"""Write a little-endian u32 at `offset`. Refuses out-of-range values and a short buffer."""
	if not fits_u32(value):
		return result.refuse(REFUSE_VALUE_RANGE, "%d is not a u32" % value)
	if not _write_room(out, offset, U32_BYTES, result):
		return false
	out.encode_u32(offset, value)
	return result.succeed(value)


static func write_i32_into(out: PackedByteArray, offset: int, value: int, result: Scalar) -> bool:
	"""Write a little-endian two's-complement i32 at `offset`. Refuses a value outside i32."""
	if not fits_i32(value):
		return result.refuse(REFUSE_VALUE_RANGE, "%d is not an i32" % value)
	if not _write_room(out, offset, I32_BYTES, result):
		return false
	out.encode_s32(offset, value)
	return result.succeed(value)


static func write_u64_into(out: PackedByteArray, offset: int, value: int, result: Scalar) -> bool:
	"""Write a little-endian u64 at `offset`. Refuses a negative, i.e. an unrepresentable u64."""
	if not fits_u64(value):
		return result.refuse(REFUSE_VALUE_RANGE,
			"%d is not a u64 a GDScript int can hold" % value)
	if not _write_room(out, offset, U64_BYTES, result):
		return false
	out.encode_u64(offset, value)
	return result.succeed(value)


static func write_i64_into(out: PackedByteArray, offset: int, value: int, result: Scalar) -> bool:
	"""Write a little-endian two's-complement i64 at `offset`. Every GDScript int is in range."""
	if not _write_room(out, offset, I64_BYTES, result):
		return false
	out.encode_s64(offset, value)
	return result.succeed(value)


static func write_bytes_into(out: PackedByteArray, offset: int, source: PackedByteArray,
		result: Scalar) -> bool:
	"""Copy `source` verbatim into `out` at `offset`. Refuses rather than truncating the copy."""
	if not _write_room(out, offset, source.size(), result):
		return false
	for index: int in source.size():
		out[offset + index] = source[index]
	return result.succeed(source.size())


# --- bounded fixed-offset reads -------------------------------------------------------------------

static func _read_room(bytes: PackedByteArray, offset: int, width: int, out: Scalar) -> bool:
	"""Check that `width` bytes are readable at `offset`, without any offset+width overflow."""
	if offset < 0:
		return out.refuse(REFUSE_NEGATIVE_OFFSET, "offset %d is negative" % offset)
	if bytes.size() < width or offset > bytes.size() - width:
		return out.refuse(REFUSE_TRUNCATED,
			"%d bytes at offset %d exceed a %d-byte buffer" % [width, offset, bytes.size()])
	return true


static func read_u8_at(bytes: PackedByteArray, offset: int, out: Scalar) -> bool:
	"""Read one unsigned byte at `offset`, or refuse without reading past the end."""
	if not _read_room(bytes, offset, U8_BYTES, out):
		return false
	return out.succeed(bytes.decode_u8(offset))


static func read_u32_at(bytes: PackedByteArray, offset: int, out: Scalar) -> bool:
	"""Read a little-endian u32 at `offset`, or refuse without reading past the end."""
	if not _read_room(bytes, offset, U32_BYTES, out):
		return false
	return out.succeed(bytes.decode_u32(offset))


static func read_i32_at(bytes: PackedByteArray, offset: int, out: Scalar) -> bool:
	"""Read a little-endian two's-complement i32 at `offset`, or refuse."""
	if not _read_room(bytes, offset, I32_BYTES, out):
		return false
	return out.succeed(bytes.decode_s32(offset))


static func read_u64_at(bytes: PackedByteArray, offset: int, out: Scalar) -> bool:
	"""Read a little-endian u64 at `offset`. Refuses a bit pattern with its high bit set.

	Godot decodes such a pattern into a negative int64. Surfacing that as a byte count or a file
	offset is exactly the confusion this module exists to prevent, so it is a refusal.
	"""
	if not _read_room(bytes, offset, U64_BYTES, out):
		return false
	var value: int = bytes.decode_u64(offset)
	if value < 0:
		return out.refuse(REFUSE_UNREPRESENTABLE_U64,
			"the u64 at offset %d has its high bit set" % offset)
	return out.succeed(value)


static func read_i64_at(bytes: PackedByteArray, offset: int, out: Scalar) -> bool:
	"""Read a little-endian two's-complement i64 at `offset`, or refuse."""
	if not _read_room(bytes, offset, I64_BYTES, out):
		return false
	return out.succeed(bytes.decode_s64(offset))


static func zero_padding_refusal(bytes: PackedByteArray, offset: int, count: int) -> StringName:
	"""REFUSE_NONE when `count` bytes at `offset` are all zero. ARCH-SAVE-005 reserved padding.

	"Reject nonzero reserved padding" (systems_architecture.md:747). A short buffer or a negative
	offset/count is a refusal too, never a silently shortened check.
	"""
	if offset < 0 or count < 0:
		return REFUSE_NEGATIVE_OFFSET
	if bytes.size() < count or offset > bytes.size() - count:
		return REFUSE_TRUNCATED
	for index: int in count:
		if bytes[offset + index] != 0:
			return REFUSE_NONZERO_PADDING
	return REFUSE_NONE


# --- strict UTF-8 -------------------------------------------------------------------------------

static func utf8_refusal(bytes: PackedByteArray, offset: int, length: int) -> StringName:
	"""REFUSE_NONE when `length` bytes at `offset` are well-formed UTF-8. ARCH-SAVE-005.

	Strict: rejects a continuation byte in a lead position, an overlong form (0xC0/0xC1, 0xE0
	followed by < 0xA0, 0xF0 followed by < 0x90), a UTF-16 surrogate (0xED followed by >= 0xA0),
	a scalar above U+10FFFF (0xF4 followed by > 0x8F, and 0xF5..0xFF), and a truncated sequence.
	Godot's own `get_string_from_utf8()` substitutes replacement characters instead of refusing,
	so this cannot be delegated to it.
	"""
	if offset < 0 or length < 0:
		return REFUSE_NEGATIVE_OFFSET
	if bytes.size() < length or offset > bytes.size() - length:
		return REFUSE_TRUNCATED
	var index: int = 0
	while index < length:
		var width: int = _utf8_sequence_width(bytes[offset + index])
		if width == 0 or index + width > length:
			return REFUSE_MALFORMED_UTF8
		if not _utf8_tail_ok(bytes, offset + index, width):
			return REFUSE_MALFORMED_UTF8
		index += width
	return REFUSE_NONE


static func _utf8_sequence_width(lead: int) -> int:
	"""Byte width the lead byte declares, or 0 when it cannot start a UTF-8 sequence."""
	if lead < 0x80:
		return 1
	if lead < 0xc2:
		return 0
	if lead < 0xe0:
		return 2
	if lead < 0xf0:
		return 3
	if lead < 0xf5:
		return 4
	return 0


static func _utf8_tail_ok(bytes: PackedByteArray, start: int, width: int) -> bool:
	"""Validate the continuation bytes of one sequence, including its lead-specific first range."""
	var lead: int = bytes[start]
	var low: int = 0x80
	var high: int = 0xbf
	if lead == 0xe0:
		low = 0xa0
	elif lead == 0xed:
		high = 0x9f
	elif lead == 0xf0:
		low = 0x90
	elif lead == 0xf4:
		high = 0x8f
	for index: int in range(1, width):
		var byte: int = bytes[start + index]
		var lower: int = low if index == 1 else 0x80
		var upper: int = high if index == 1 else 0xbf
		if byte < lower or byte > upper:
			return false
	return true


static func decode_utf8_into(bytes: PackedByteArray, offset: int, length: int, out: Text) -> bool:
	"""Validate then decode `length` UTF-8 bytes at `offset` into `out`, or refuse.

	After the structural check the decoded String is re-encoded and compared byte for byte. That
	catches anything the engine's decoder would represent lossily -- an embedded U+0000 among
	them, which Godot treats as a terminator -- because a save codec that is not byte-exact on the
	round trip is not canonical.
	"""
	var refusal: StringName = utf8_refusal(bytes, offset, length)
	if refusal != REFUSE_NONE:
		return out.refuse(refusal, "the %d bytes at offset %d are not canonical UTF-8"
			% [length, offset])
	var slice: PackedByteArray = bytes.slice(offset, offset + length)
	var text: String = slice.get_string_from_utf8()
	if text.to_utf8_buffer() != slice:
		return out.refuse(REFUSE_UTF8_NOT_ROUND_TRIP,
			"the %d bytes at offset %d do not survive a decode/encode round trip" % [length, offset])
	return out.succeed(text, length)


static func utf8_byte_length(text: String) -> int:
	"""Byte length this string takes as UTF-8. The value a length prefix must carry."""
	return text.to_utf8_buffer().size()


# --- the bounded sequential reader ------------------------------------------------------------------

class Reader:
	"""A cursor over a byte buffer that cannot be walked off its end.

	Every read is bounded by the buffer size, refuses rather than returning a partial value, and
	leaves the cursor where it was. The first refusal is STICKY: later reads return it unchanged,
	so ignoring one return value cannot let a decoder run on past a truncation.
	"""
	var _bytes: PackedByteArray
	var _cursor: int = 0
	var _refusal: StringName = REFUSE_NONE
	var _detail: String = ""

	func _init(p_bytes: PackedByteArray) -> void:
		"""Open a reader positioned at byte zero of `p_bytes`."""
		_bytes = p_bytes

	func failed() -> bool:
		"""True once any read has refused."""
		return _refusal != REFUSE_NONE

	func refusal() -> StringName:
		"""The first refusal code recorded, or REFUSE_NONE."""
		return _refusal

	func detail() -> String:
		"""Human-readable detail behind the first refusal, or an empty string."""
		return _detail

	func position() -> int:
		"""Current cursor offset."""
		return _cursor

	func size() -> int:
		"""Total bytes in the buffer."""
		return _bytes.size()

	func remaining() -> int:
		"""Bytes left between the cursor and the end of the buffer."""
		return _bytes.size() - _cursor

	func reset() -> void:
		"""Rewind to byte zero and clear the sticky refusal. The only way back from a refusal."""
		_cursor = 0
		_refusal = REFUSE_NONE
		_detail = ""

	func seek(target: int) -> bool:
		"""Move the cursor to `target`. Refuses outside [0, size()] and does not clear a refusal."""
		if failed():
			return false
		if target < 0 or target > _bytes.size():
			return _fail(REFUSE_SEEK_OUT_OF_RANGE,
				"seek to %d is outside a %d-byte buffer" % [target, _bytes.size()])
		_cursor = target
		return true

	func _fail(p_refusal: StringName, p_detail: String) -> bool:
		"""Record the first refusal; later refusals never overwrite it. Always returns false."""
		if _refusal == REFUSE_NONE:
			_refusal = p_refusal
			_detail = p_detail
		return false

	func _replay(out: Scalar) -> bool:
		"""Copy the sticky refusal into a caller's Scalar. Always returns false."""
		return out.refuse(_refusal, _detail)

	func read_u8_into(out: Scalar) -> bool:
		"""Read one unsigned byte and advance, or refuse and leave the cursor alone."""
		return _read_fixed(U8_BYTES, SIGNEDNESS_UNSIGNED, out)

	func read_u32_into(out: Scalar) -> bool:
		"""Read a little-endian u32 and advance, or refuse and leave the cursor alone."""
		return _read_fixed(U32_BYTES, SIGNEDNESS_UNSIGNED, out)

	func read_i32_into(out: Scalar) -> bool:
		"""Read a little-endian i32 and advance, or refuse and leave the cursor alone."""
		return _read_fixed(I32_BYTES, SIGNEDNESS_SIGNED, out)

	func read_u64_into(out: Scalar) -> bool:
		"""Read a little-endian u64 and advance. Refuses a pattern with its high bit set."""
		return _read_fixed(U64_BYTES, SIGNEDNESS_UNSIGNED, out)

	func read_i64_into(out: Scalar) -> bool:
		"""Read a little-endian i64 and advance, or refuse and leave the cursor alone."""
		return _read_fixed(I64_BYTES, SIGNEDNESS_SIGNED, out)

	func _read_fixed(width: int, signedness: int, out: Scalar) -> bool:
		"""Dispatch one fixed-width read, advancing only on success. One bound check, one place."""
		if failed():
			return _replay(out)
		if not _dispatch_fixed(width, signedness, out):
			return _fail(out.refusal, out.detail)
		_cursor += width
		return true

	func _dispatch_fixed(width: int, signedness: int, out: Scalar) -> bool:
		"""Perform the width- and signedness-specific read at the cursor without moving it.

		Width alone cannot choose: i32 and u32 are both 4 bytes and i64 and u64 are both 8, so
		reading a u32 field as i32 would turn 0x80000000 into -2147483648 without a word of
		complaint. Signedness is therefore carried explicitly, never inferred.
		"""
		if width == U8_BYTES:
			return SaveCodecScript.read_u8_at(_bytes, _cursor, out)
		if width == U32_BYTES:
			if signedness == SIGNEDNESS_UNSIGNED:
				return SaveCodecScript.read_u32_at(_bytes, _cursor, out)
			return SaveCodecScript.read_i32_at(_bytes, _cursor, out)
		if signedness == SIGNEDNESS_UNSIGNED:
			return SaveCodecScript.read_u64_at(_bytes, _cursor, out)
		return SaveCodecScript.read_i64_at(_bytes, _cursor, out)

	func read_bytes_into(count: int, out: PackedByteArray) -> bool:
		"""Copy `count` bytes into `out`, resizing it ONLY after the count is proved safe.

		Allocate before consume (decision 0059): a negative or oversized count refuses before
		`out` is touched at all, so a hostile count cannot make this allocate.
		"""
		if failed():
			return false
		if count < 0:
			return _fail(REFUSE_NEGATIVE_LENGTH, "byte count %d is negative" % count)
		if count > remaining():
			return _fail(REFUSE_LENGTH_EXCEEDS_BUFFER,
				"%d bytes requested with %d remaining" % [count, remaining()])
		out.resize(count)
		for index: int in count:
			out[index] = _bytes[_cursor + index]
		_cursor += count
		return true

	func read_zero_padding(count: int) -> bool:
		"""Consume `count` reserved bytes, refusing unless every one is zero (ARCH-SAVE-005)."""
		if failed():
			return false
		if count < 0:
			return _fail(REFUSE_NEGATIVE_LENGTH, "padding count %d is negative" % count)
		var refusal: StringName = SaveCodecScript.zero_padding_refusal(_bytes, _cursor, count)
		if refusal != REFUSE_NONE:
			return _fail(refusal, "%d reserved bytes at offset %d" % [count, _cursor])
		_cursor += count
		return true

	func read_utf8_u32_into(max_bytes: int, out: Text) -> bool:
		"""Read a u32-byte-length-prefixed UTF-8 string. See BLOCKER S1: the width is a choice.

		The prefix is a byte count, not a character count. ARCH-SAVE-005's 2-32 CHARACTER alias
		bound is a separate, caller-level rule and is deliberately not applied here.
		"""
		if failed():
			return out.refuse(_refusal, _detail)
		var length: Scalar = Scalar.new()
		if not read_u32_into(length):
			return out.refuse(_refusal, _detail)
		return _finish_utf8(length.value, max_bytes, out)

	func read_utf8_i32_into(max_bytes: int, out: Text) -> bool:
		"""Read an i32-byte-length-prefixed UTF-8 string, refusing a negative length.

		ARCH-SAVE-005 requires rejecting "illegal negative lengths"; a signed prefix is the only
		place one can occur. See BLOCKER S1 for why both widths exist.
		"""
		if failed():
			return out.refuse(_refusal, _detail)
		var length: Scalar = Scalar.new()
		if not read_i32_into(length):
			return out.refuse(_refusal, _detail)
		if length.value < 0:
			_fail(REFUSE_NEGATIVE_LENGTH, "string length %d is negative" % length.value)
			return out.refuse(_refusal, _detail)
		return _finish_utf8(length.value, max_bytes, out)

	func _finish_utf8(length: int, max_bytes: int, out: Text) -> bool:
		"""Bound a decoded length against the caller's cap and the buffer, then decode it."""
		if max_bytes < 0:
			_fail(REFUSE_NEGATIVE_LIMIT, "max_bytes %d is negative" % max_bytes)
			return out.refuse(_refusal, _detail)
		if length > max_bytes:
			_fail(REFUSE_LENGTH_EXCEEDS_LIMIT,
				"string length %d exceeds the %d-byte cap" % [length, max_bytes])
			return out.refuse(_refusal, _detail)
		if length > remaining():
			_fail(REFUSE_LENGTH_EXCEEDS_BUFFER,
				"string length %d exceeds the %d remaining bytes" % [length, remaining()])
			return out.refuse(_refusal, _detail)
		if not SaveCodecScript.decode_utf8_into(_bytes, _cursor, length, out):
			_fail(out.refusal, out.detail)
			return false
		_cursor += length
		return true


# --- the appending writer -----------------------------------------------------------------------

class Writer:
	"""An append-only canonical byte writer. Reserve once at construction; growth doubles.

	Every value is range-checked before it is written, so an out-of-range field refuses instead of
	silently truncating to its low bytes. `to_bytes()` returns exactly the logical length, so two
	writers fed the same values produce byte-identical output regardless of reserved capacity.
	"""
	var _bytes: PackedByteArray = PackedByteArray()
	var _length: int = 0
	var _refusal: StringName = REFUSE_NONE
	var _detail: String = ""
	var _scratch: Scalar = Scalar.new()

	func _init(p_reserve_bytes: int) -> void:
		"""Allocate the backing buffer once. A negative reserve is clamped to zero, never used."""
		_bytes.resize(maxi(p_reserve_bytes, 0))

	func failed() -> bool:
		"""True once any write has refused."""
		return _refusal != REFUSE_NONE

	func refusal() -> StringName:
		"""The first refusal code recorded, or REFUSE_NONE."""
		return _refusal

	func detail() -> String:
		"""Human-readable detail behind the first refusal, or an empty string."""
		return _detail

	func length() -> int:
		"""Bytes written so far."""
		return _length

	func to_bytes() -> PackedByteArray:
		"""The written bytes exactly, with no reserved tail. Empty after a refusal."""
		if failed():
			return PackedByteArray()
		return _bytes.slice(0, _length)

	func _reserve(width: int) -> void:
		"""Ensure `width` more bytes fit, doubling the buffer rather than growing by one.

		This is the writer's only allocation and it is amortised, not per value. A save writer is
		a once-per-boundary cold path (ARCH-SAVE-003), unlike the per-tick columns that must be
		sized in `_init` and never resized again.
		"""
		var needed: int = _length + width
		if needed > _bytes.size():
			_bytes.resize(maxi(needed, _bytes.size() * 2))

	func _fail(p_refusal: StringName, p_detail: String) -> bool:
		"""Record the first refusal; later refusals never overwrite it. Always returns false."""
		if _refusal == REFUSE_NONE:
			_refusal = p_refusal
			_detail = p_detail
		return false

	func write_u8(value: int) -> bool:
		"""Append one unsigned byte, or refuse."""
		return _append(U8_BYTES, value, SIGNEDNESS_UNSIGNED)

	func write_u32(value: int) -> bool:
		"""Append a little-endian u32, or refuse a value outside the u32 domain."""
		return _append(U32_BYTES, value, SIGNEDNESS_UNSIGNED)

	func write_i32(value: int) -> bool:
		"""Append a little-endian i32, or refuse a value outside the i32 domain."""
		return _append(I32_BYTES, value, SIGNEDNESS_SIGNED)

	func write_u64(value: int) -> bool:
		"""Append a little-endian u64, or refuse a value a GDScript int cannot hold as u64."""
		return _append(U64_BYTES, value, SIGNEDNESS_UNSIGNED)

	func write_i64(value: int) -> bool:
		"""Append a little-endian i64. Every GDScript int is in range."""
		return _append(I64_BYTES, value, SIGNEDNESS_SIGNED)

	func _append(width: int, value: int, signedness: int) -> bool:
		"""Reserve room then write one fixed-width value, advancing only on success."""
		if failed():
			return false
		_reserve(width)
		if not _dispatch_append(width, value, signedness):
			return _fail(_scratch.refusal, _scratch.detail)
		_length += width
		return true

	func _dispatch_append(width: int, value: int, signedness: int) -> bool:
		"""Route one append to the width- and signedness-specific static write."""
		if width == U8_BYTES:
			return SaveCodecScript.write_u8_into(_bytes, _length, value, _scratch)
		if width == U32_BYTES:
			if signedness == SIGNEDNESS_UNSIGNED:
				return SaveCodecScript.write_u32_into(_bytes, _length, value, _scratch)
			return SaveCodecScript.write_i32_into(_bytes, _length, value, _scratch)
		if signedness == SIGNEDNESS_UNSIGNED:
			return SaveCodecScript.write_u64_into(_bytes, _length, value, _scratch)
		return SaveCodecScript.write_i64_into(_bytes, _length, value, _scratch)

	func write_bytes(source: PackedByteArray) -> bool:
		"""Append `source` verbatim, or refuse."""
		if failed():
			return false
		_reserve(source.size())
		for index: int in source.size():
			_bytes[_length + index] = source[index]
		_length += source.size()
		return true

	func write_zero_padding(count: int) -> bool:
		"""Append `count` zero bytes of reserved padding, refusing a negative count."""
		if failed():
			return false
		if count < 0:
			return _fail(REFUSE_NEGATIVE_LENGTH, "padding count %d is negative" % count)
		_reserve(count)
		for index: int in count:
			_bytes[_length + index] = 0
		_length += count
		return true

	func write_utf8_u32(text: String, max_bytes: int) -> bool:
		"""Append a u32-byte-length-prefixed UTF-8 string. See BLOCKER S1 on the prefix width."""
		return _append_utf8(text, max_bytes, SIGNEDNESS_UNSIGNED)

	func write_utf8_i32(text: String, max_bytes: int) -> bool:
		"""Append an i32-byte-length-prefixed UTF-8 string. See BLOCKER S1 on the prefix width."""
		return _append_utf8(text, max_bytes, SIGNEDNESS_SIGNED)

	func _append_utf8(text: String, max_bytes: int, signedness: int) -> bool:
		"""Encode, bound against the caller's cap, then write the prefix and the bytes."""
		if failed():
			return false
		if max_bytes < 0:
			return _fail(REFUSE_NEGATIVE_LIMIT, "max_bytes %d is negative" % max_bytes)
		var encoded: PackedByteArray = text.to_utf8_buffer()
		if encoded.size() > max_bytes:
			return _fail(REFUSE_LENGTH_EXCEEDS_LIMIT,
				"%d UTF-8 bytes exceed the %d-byte cap" % [encoded.size(), max_bytes])
		var written: bool = write_u32(encoded.size()) if signedness == SIGNEDNESS_UNSIGNED \
			else write_i32(encoded.size())
		if not written:
			return false
		return write_bytes(encoded)
