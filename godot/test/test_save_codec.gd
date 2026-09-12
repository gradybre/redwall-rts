extends "res://test/framework/test_case.gd"
## ARCH-SAVE-001's primitives, tested adversarially rather than merely round-tripped.
##
## The point of this suite is the refusals. A codec that round-trips its own output proves almost
## nothing; what has to hold is that a TRUNCATED buffer, a HOSTILE length prefix and a value
## outside its declared width are all refused, before allocating and without advancing a cursor.
##
## The int32 tests deliberately go through `u32_bits_to_int32()` rather than through literals.
## `0x80000000` is a POSITIVE GDScript int and `-2147483648` as an int32; writing the test with
## the literal is how a real bug in this repository's scheduler code hid inside the test meant to
## catch it.

const SaveCodec := preload("res://scripts/core/save_codec.gd")
const CommandsScript := preload("res://scripts/core/commands.gd")

const U32_HIGH_BIT: int = 2147483648
const SOURCE_PATH: String = "res://scripts/core/save_codec.gd"


func _buffer(size: int) -> PackedByteArray:
	"""A zeroed buffer of the requested size."""
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(size)
	return bytes


func _i32_boundaries() -> PackedInt64Array:
	"""Every i32 value worth writing a codec test about, derived from bit patterns not literals."""
	return PackedInt64Array([
		SaveCodec.u32_bits_to_int32(U32_HIGH_BIT),
		SaveCodec.u32_bits_to_int32(U32_HIGH_BIT + 1),
		SaveCodec.u32_bits_to_int32(SaveCodec.UINT32_MAX),
		SaveCodec.u32_bits_to_int32(0),
		SaveCodec.u32_bits_to_int32(1),
		SaveCodec.u32_bits_to_int32(U32_HIGH_BIT - 1),
	])


func _i64_boundaries() -> PackedInt64Array:
	"""INT64_MIN, INT64_MAX and the values around zero that a two's-complement bug lands on."""
	return PackedInt64Array([SaveCodec.INT64_MIN, SaveCodec.INT64_MIN + 1, -1, 0, 1,
		SaveCodec.INT64_MAX - 1, SaveCodec.INT64_MAX])


# --- two's-complement reinterpretation ------------------------------------------------------------

func test_u32_bit_pattern_with_high_bit_is_negative_as_int32() -> void:
	"""0x80000000 is positive in GDScript and -2147483648 as an int32. Both spellings asserted."""
	assert_true(U32_HIGH_BIT > 0, "0x80000000 is a positive GDScript int")
	assert_equal(SaveCodec.u32_bits_to_int32(U32_HIGH_BIT), SaveCodec.INT32_MIN,
		"0x80000000 reinterpreted as i32 is INT32_MIN")
	assert_equal(SaveCodec.u32_bits_to_int32(SaveCodec.UINT32_MAX), -1,
		"0xffffffff reinterpreted as i32 is -1")
	assert_equal(SaveCodec.u32_bits_to_int32(U32_HIGH_BIT - 1), SaveCodec.INT32_MAX,
		"0x7fffffff reinterpreted as i32 is INT32_MAX")


func test_int32_bit_reinterpretation_is_an_involution_over_i32() -> void:
	"""int32_bits_to_u32() and u32_bits_to_int32() invert each other on every boundary value."""
	for value: int in _i32_boundaries():
		var bits: int = SaveCodec.int32_bits_to_u32(value)
		assert_true(SaveCodec.fits_u32(bits), "the bit pattern of %d is a u32" % value)
		assert_equal(SaveCodec.u32_bits_to_int32(bits), value,
			"round trip through the u32 bit pattern of %d" % value)


func test_bit_reinterpretation_agrees_with_the_command_queue() -> void:
	"""save_codec and commands.gd must spell the same conversion; duplication is not drift."""
	for bits: int in [0, 1, U32_HIGH_BIT - 1, U32_HIGH_BIT, U32_HIGH_BIT + 1,
			SaveCodec.UINT32_MAX]:
		assert_equal(SaveCodec.u32_bits_to_int32(bits), CommandsScript.to_int32_bits(bits),
			"u32_bits_to_int32(%d) agrees with commands.to_int32_bits" % bits)


# --- byte order -----------------------------------------------------------------------------------

func test_integers_are_written_little_endian() -> void:
	"""ARCH-SAVE-001 says explicit little-endian. 0x01020304 must land as 04 03 02 01."""
	var bytes: PackedByteArray = _buffer(8)
	var scratch: SaveCodec.Scalar = SaveCodec.Scalar.new()
	assert_true(SaveCodec.write_u32_into(bytes, 0, 0x01020304, scratch), "u32 written")
	assert_equal(bytes[0], 4, "least significant byte first")
	assert_equal(bytes[1], 3, "second byte")
	assert_equal(bytes[2], 2, "third byte")
	assert_equal(bytes[3], 1, "most significant byte last")
	assert_true(SaveCodec.write_i64_into(bytes, 0, 1, scratch), "i64 written")
	assert_equal(bytes[0], 1, "i64 least significant byte first")
	assert_equal(bytes[7], 0, "i64 most significant byte last")


# --- fixed-width round trips at their boundaries ---------------------------------------------------

func test_i32_round_trips_at_every_boundary() -> void:
	"""INT32_MIN, INT32_MAX, -1, 0, 1 and 0x7fffffff survive encode then decode exactly."""
	var bytes: PackedByteArray = _buffer(SaveCodec.I32_BYTES)
	var scratch: SaveCodec.Scalar = SaveCodec.Scalar.new()
	for value: int in _i32_boundaries():
		assert_true(SaveCodec.write_i32_into(bytes, 0, value, scratch), "wrote i32 %d" % value)
		assert_true(SaveCodec.read_i32_at(bytes, 0, scratch), "read i32 %d" % value)
		assert_equal(scratch.value, value, "i32 %d round trips" % value)


func test_i64_round_trips_at_every_boundary() -> void:
	"""INT64_MIN and INT64_MAX survive exactly; a sign-extension bug shows up here."""
	var bytes: PackedByteArray = _buffer(SaveCodec.I64_BYTES)
	var scratch: SaveCodec.Scalar = SaveCodec.Scalar.new()
	for value: int in _i64_boundaries():
		assert_true(SaveCodec.write_i64_into(bytes, 0, value, scratch), "wrote i64 %d" % value)
		assert_true(SaveCodec.read_i64_at(bytes, 0, scratch), "read i64 %d" % value)
		assert_equal(scratch.value, value, "i64 %d round trips" % value)


func test_u32_round_trips_across_its_whole_domain_boundary() -> void:
	"""0, 1, 0x7fffffff, 0x80000000 and 0xffffffff all survive as UNSIGNED values."""
	var bytes: PackedByteArray = _buffer(SaveCodec.U32_BYTES)
	var scratch: SaveCodec.Scalar = SaveCodec.Scalar.new()
	for value: int in [0, 1, U32_HIGH_BIT - 1, U32_HIGH_BIT, SaveCodec.UINT32_MAX]:
		assert_true(SaveCodec.write_u32_into(bytes, 0, value, scratch), "wrote u32 %d" % value)
		assert_true(SaveCodec.read_u32_at(bytes, 0, scratch), "read u32 %d" % value)
		assert_equal(scratch.value, value, "u32 %d round trips unsigned" % value)


func test_the_same_four_bytes_read_as_u32_and_i32_differ_by_design() -> void:
	"""Reading a u32 field as i32 is a real defect; the two reads must disagree, not agree."""
	var bytes: PackedByteArray = _buffer(SaveCodec.U32_BYTES)
	var scratch: SaveCodec.Scalar = SaveCodec.Scalar.new()
	assert_true(SaveCodec.write_u32_into(bytes, 0, U32_HIGH_BIT, scratch), "wrote 0x80000000")
	assert_true(SaveCodec.read_u32_at(bytes, 0, scratch), "read as u32")
	assert_equal(scratch.value, U32_HIGH_BIT, "as a u32 it is 2147483648")
	assert_true(SaveCodec.read_i32_at(bytes, 0, scratch), "read as i32")
	assert_equal(scratch.value, SaveCodec.INT32_MIN, "as an i32 it is -2147483648")


func test_u8_round_trips_at_its_boundaries() -> void:
	"""0 and 255 survive; a signed byte read would turn 255 into -1."""
	var bytes: PackedByteArray = _buffer(SaveCodec.U8_BYTES)
	var scratch: SaveCodec.Scalar = SaveCodec.Scalar.new()
	for value: int in [0, 1, 127, 128, SaveCodec.UINT8_MAX]:
		assert_true(SaveCodec.write_u8_into(bytes, 0, value, scratch), "wrote u8 %d" % value)
		assert_true(SaveCodec.read_u8_at(bytes, 0, scratch), "read u8 %d" % value)
		assert_equal(scratch.value, value, "u8 %d round trips" % value)


func test_u64_round_trips_up_to_the_representable_maximum() -> void:
	"""0 and INT64_MAX survive as u64; that is the whole range a GDScript int can carry."""
	var bytes: PackedByteArray = _buffer(SaveCodec.U64_BYTES)
	var scratch: SaveCodec.Scalar = SaveCodec.Scalar.new()
	for value: int in [0, 1, 4294967296, SaveCodec.UINT64_REPRESENTABLE_MAX]:
		assert_true(SaveCodec.write_u64_into(bytes, 0, value, scratch), "wrote u64 %d" % value)
		assert_true(SaveCodec.read_u64_at(bytes, 0, scratch), "read u64 %d" % value)
		assert_equal(scratch.value, value, "u64 %d round trips" % value)


# --- value-range refusals ---------------------------------------------------------------------------

func test_a_value_outside_its_declared_width_is_refused_not_truncated() -> void:
	"""Writing 2^31 as i32 or 2^32 as u32 must refuse. Silent truncation is the failure mode."""
	var bytes: PackedByteArray = _buffer(8)
	var scratch: SaveCodec.Scalar = SaveCodec.Scalar.new()
	assert_false(SaveCodec.write_i32_into(bytes, 0, U32_HIGH_BIT, scratch), "2^31 is not an i32")
	assert_equal(scratch.refusal, SaveCodec.REFUSE_VALUE_RANGE, "refused as a range error")
	assert_false(SaveCodec.write_i32_into(bytes, 0, SaveCodec.INT32_MIN - 1, scratch),
		"INT32_MIN-1 is not an i32")
	assert_false(SaveCodec.write_u32_into(bytes, 0, SaveCodec.UINT32_MAX + 1, scratch),
		"2^32 is not a u32")
	assert_false(SaveCodec.write_u32_into(bytes, 0, -1, scratch), "-1 is not a u32")
	assert_false(SaveCodec.write_u8_into(bytes, 0, 256, scratch), "256 is not a u8")
	assert_false(SaveCodec.write_u8_into(bytes, 0, -1, scratch), "-1 is not a u8")
	assert_false(SaveCodec.write_u64_into(bytes, 0, -1, scratch), "-1 is not a u64")
	assert_equal(bytes, _buffer(8), "not one refused write touched the buffer")


func test_a_u64_with_its_high_bit_set_is_refused_rather_than_read_as_negative() -> void:
	"""Godot decodes 0xffffffffffffffff into -1. A byte count of -1 must never reach a caller."""
	var bytes: PackedByteArray = _buffer(SaveCodec.U64_BYTES)
	for index: int in SaveCodec.U64_BYTES:
		bytes[index] = 255
	var scratch: SaveCodec.Scalar = SaveCodec.Scalar.new()
	assert_false(SaveCodec.read_u64_at(bytes, 0, scratch), "an unrepresentable u64 is refused")
	assert_equal(scratch.refusal, SaveCodec.REFUSE_UNREPRESENTABLE_U64, "named refusal")
	assert_equal(scratch.value, 0, "the refused read yields no value at all")
	assert_true(SaveCodec.read_i64_at(bytes, 0, scratch), "the same bytes are a legal i64")
	assert_equal(scratch.value, -1, "as an i64 they are -1")


func test_the_lowest_unrepresentable_u64_is_the_high_bit_alone() -> void:
	"""The boundary is exact: INT64_MAX is accepted and INT64_MAX+1 as a bit pattern is not."""
	var bytes: PackedByteArray = _buffer(SaveCodec.U64_BYTES)
	var scratch: SaveCodec.Scalar = SaveCodec.Scalar.new()
	assert_true(SaveCodec.write_u64_into(bytes, 0, SaveCodec.INT64_MAX, scratch), "INT64_MAX")
	assert_true(SaveCodec.read_u64_at(bytes, 0, scratch), "INT64_MAX reads back")
	assert_equal(scratch.value, SaveCodec.INT64_MAX, "INT64_MAX is representable")
	bytes[7] = 128
	for index: int in 7:
		bytes[index] = 0
	assert_false(SaveCodec.read_u64_at(bytes, 0, scratch), "2^63 exactly is refused")
	assert_equal(scratch.refusal, SaveCodec.REFUSE_UNREPRESENTABLE_U64, "named refusal")


# --- bounds on fixed-offset access ------------------------------------------------------------------

func test_a_write_that_would_run_past_the_end_is_refused_at_the_exact_boundary() -> void:
	"""offset == size-width is the last legal write; offset+1 is the first refused one."""
	var bytes: PackedByteArray = _buffer(8)
	var scratch: SaveCodec.Scalar = SaveCodec.Scalar.new()
	assert_true(SaveCodec.write_i32_into(bytes, 4, 1, scratch), "i32 at offset 4 of 8 fits")
	assert_false(SaveCodec.write_i32_into(bytes, 5, 1, scratch), "i32 at offset 5 of 8 does not")
	assert_equal(scratch.refusal, SaveCodec.REFUSE_TRUNCATED, "refused as truncation")
	assert_false(SaveCodec.write_i32_into(bytes, -1, 1, scratch), "a negative offset is refused")
	assert_equal(scratch.refusal, SaveCodec.REFUSE_NEGATIVE_OFFSET, "named refusal")
	assert_false(SaveCodec.write_i64_into(_buffer(4), 0, 1, scratch), "i64 needs eight bytes")


func test_a_read_past_the_end_is_refused_at_the_exact_boundary() -> void:
	"""Same boundary on the read side, which is the one a hostile file exercises."""
	var bytes: PackedByteArray = _buffer(8)
	var scratch: SaveCodec.Scalar = SaveCodec.Scalar.new()
	assert_true(SaveCodec.read_i32_at(bytes, 4, scratch), "i32 at offset 4 of 8 is readable")
	assert_false(SaveCodec.read_i32_at(bytes, 5, scratch), "i32 at offset 5 of 8 is not")
	assert_equal(scratch.refusal, SaveCodec.REFUSE_TRUNCATED, "refused as truncation")
	assert_equal(scratch.value, 0, "a refused read yields no value")
	assert_false(SaveCodec.read_u64_at(_buffer(7), 0, scratch), "u64 needs eight bytes")
	assert_false(SaveCodec.read_u8_at(_buffer(0), 0, scratch), "an empty buffer holds no u8")
	assert_false(SaveCodec.read_i32_at(bytes, -1, scratch), "a negative offset is refused")


# --- the bounded reader --------------------------------------------------------------------------

func test_the_reader_walks_a_record_and_stops_exactly_at_the_end() -> void:
	"""A four-field record reads back field for field and leaves the cursor at the end."""
	var writer: SaveCodec.Writer = SaveCodec.Writer.new(0)
	assert_true(writer.write_i64(SaveCodec.INT64_MIN), "tick")
	assert_true(writer.write_i32(SaveCodec.INT32_MIN), "slot")
	assert_true(writer.write_u32(SaveCodec.UINT32_MAX), "sequence")
	assert_true(writer.write_u8(SaveCodec.UINT8_MAX), "flag")
	var reader: SaveCodec.Reader = SaveCodec.Reader.new(writer.to_bytes())
	var scalar: SaveCodec.Scalar = SaveCodec.Scalar.new()
	assert_true(reader.read_i64_into(scalar), "read tick")
	assert_equal(scalar.value, SaveCodec.INT64_MIN, "tick survives")
	assert_true(reader.read_i32_into(scalar), "read slot")
	assert_equal(scalar.value, SaveCodec.INT32_MIN, "slot survives")
	assert_true(reader.read_u32_into(scalar), "read sequence")
	assert_equal(scalar.value, SaveCodec.UINT32_MAX, "sequence survives unsigned")
	assert_true(reader.read_u8_into(scalar), "read flag")
	assert_equal(reader.remaining(), 0, "the record is exactly consumed")
	assert_false(reader.read_u8_into(scalar), "one byte more is refused")


func test_a_truncated_buffer_refuses_instead_of_returning_a_partial_value() -> void:
	"""Three bytes cannot yield a u32. The cursor must not move and no partial value appears."""
	var reader: SaveCodec.Reader = SaveCodec.Reader.new(PackedByteArray([1, 2, 3]))
	var scalar: SaveCodec.Scalar = SaveCodec.Scalar.new()
	assert_false(reader.read_u32_into(scalar), "a u32 needs four bytes")
	assert_equal(scalar.refusal, SaveCodec.REFUSE_TRUNCATED, "refused as truncation")
	assert_equal(scalar.value, 0, "no partial value")
	assert_equal(reader.position(), 0, "the cursor did not move")
	assert_true(reader.failed(), "the reader records the refusal")


func test_the_reader_refusal_is_sticky_so_one_ignored_return_cannot_walk_off_the_end() -> void:
	"""After a refusal every later read refuses with the FIRST code, cursor frozen."""
	var bytes: PackedByteArray = _buffer(4)
	var reader: SaveCodec.Reader = SaveCodec.Reader.new(bytes)
	var scalar: SaveCodec.Scalar = SaveCodec.Scalar.new()
	assert_false(reader.read_i64_into(scalar), "eight bytes are not there")
	assert_equal(reader.refusal(), SaveCodec.REFUSE_TRUNCATED, "first refusal recorded")
	assert_false(reader.read_u8_into(scalar), "a read that WOULD fit still refuses")
	assert_equal(scalar.refusal, SaveCodec.REFUSE_TRUNCATED, "the first refusal is replayed")
	assert_equal(reader.position(), 0, "the cursor is frozen")
	assert_false(reader.seek(0), "seek refuses while failed")
	reader.reset()
	assert_false(reader.failed(), "reset clears the refusal")
	assert_true(reader.read_u8_into(scalar), "and the reader is usable again")


func test_seek_is_bounded_at_both_ends() -> void:
	"""seek(size) is legal and leaves nothing remaining; seek(-1) and seek(size+1) refuse."""
	var reader: SaveCodec.Reader = SaveCodec.Reader.new(_buffer(8))
	assert_true(reader.seek(8), "seeking to the end is legal")
	assert_equal(reader.remaining(), 0, "nothing remains there")
	assert_false(reader.seek(9), "one past the end is refused")
	assert_equal(reader.refusal(), SaveCodec.REFUSE_SEEK_OUT_OF_RANGE, "named refusal")
	reader.reset()
	assert_false(reader.seek(-1), "a negative seek is refused")
	assert_equal(reader.refusal(), SaveCodec.REFUSE_SEEK_OUT_OF_RANGE, "named refusal")


func test_read_bytes_refuses_a_hostile_count_without_allocating() -> void:
	"""The destination must be untouched by a refused read; that is allocate-before-consume."""
	var reader: SaveCodec.Reader = SaveCodec.Reader.new(_buffer(4))
	var out: PackedByteArray = PackedByteArray([9, 9])
	assert_false(reader.read_bytes_into(-1, out), "a negative count is refused")
	assert_equal(reader.refusal(), SaveCodec.REFUSE_NEGATIVE_LENGTH, "named refusal")
	assert_equal(out, PackedByteArray([9, 9]), "the destination was never resized")
	reader.reset()
	assert_false(reader.read_bytes_into(5, out), "five bytes from a four-byte buffer refuse")
	assert_equal(reader.refusal(), SaveCodec.REFUSE_LENGTH_EXCEEDS_BUFFER, "named refusal")
	assert_equal(out, PackedByteArray([9, 9]), "still never resized")
	reader.reset()
	assert_true(reader.read_bytes_into(4, out), "exactly four bytes are readable")
	assert_equal(out.size(), 4, "and only then is the destination sized")


func test_zero_padding_refuses_a_single_nonzero_reserved_byte() -> void:
	"""ARCH-SAVE-005 rejects nonzero reserved padding. Every position is checked, not just the first."""
	for position: int in 8:
		var bytes: PackedByteArray = _buffer(8)
		bytes[position] = 1
		assert_equal(SaveCodec.zero_padding_refusal(bytes, 0, 8),
			SaveCodec.REFUSE_NONZERO_PADDING, "a nonzero byte at %d refuses" % position)
	assert_equal(SaveCodec.zero_padding_refusal(_buffer(8), 0, 8), SaveCodec.REFUSE_NONE,
		"all-zero padding is accepted")
	assert_equal(SaveCodec.zero_padding_refusal(_buffer(8), 0, 9), SaveCodec.REFUSE_TRUNCATED,
		"padding longer than the buffer refuses")
	assert_equal(SaveCodec.zero_padding_refusal(_buffer(8), 1, 8), SaveCodec.REFUSE_TRUNCATED,
		"eight bytes of padding one byte in refuses on the offset, not only on the count")
	assert_equal(SaveCodec.zero_padding_refusal(_buffer(8), 1, 7), SaveCodec.REFUSE_NONE,
		"and seven bytes one byte in is exactly the last legal span")
	assert_equal(SaveCodec.zero_padding_refusal(_buffer(8), -1, 1), SaveCodec.REFUSE_NEGATIVE_OFFSET,
		"a negative offset refuses")


func test_the_reader_consumes_zero_padding_only_when_it_is_zero() -> void:
	"""The cursor advances over accepted padding and freezes on refused padding."""
	var reader: SaveCodec.Reader = SaveCodec.Reader.new(_buffer(8))
	assert_true(reader.read_zero_padding(8), "eight zero bytes are consumed")
	assert_equal(reader.position(), 8, "the cursor advanced by exactly eight")
	var dirty: PackedByteArray = _buffer(8)
	dirty[7] = 255
	var second: SaveCodec.Reader = SaveCodec.Reader.new(dirty)
	assert_false(second.read_zero_padding(8), "nonzero padding refuses")
	assert_equal(second.refusal(), SaveCodec.REFUSE_NONZERO_PADDING, "named refusal")
	assert_equal(second.position(), 0, "and the cursor did not move")


# --- length-prefixed UTF-8 ------------------------------------------------------------------------

func test_strings_round_trip_byte_exactly_under_both_prefix_widths() -> void:
	"""BLOCKER S1: the prefix width is unspecified, so both primitives must be exact."""
	var samples: Array[String] = ["", "Redwall", "Méadhbh", "あい", "\U0001f430"]
	for text: String in samples:
		for signed: bool in [false, true]:
			var writer: SaveCodec.Writer = SaveCodec.Writer.new(0)
			var wrote: bool = writer.write_utf8_i32(text, 64) if signed \
				else writer.write_utf8_u32(text, 64)
			assert_true(wrote, "wrote '%s'" % text)
			var reader: SaveCodec.Reader = SaveCodec.Reader.new(writer.to_bytes())
			var out: SaveCodec.Text = SaveCodec.Text.new()
			var read: bool = reader.read_utf8_i32_into(64, out) if signed \
				else reader.read_utf8_u32_into(64, out)
			assert_true(read, "read '%s'" % text)
			assert_equal(out.value, text, "'%s' survives byte-exactly" % text)
			assert_equal(out.byte_length, SaveCodec.utf8_byte_length(text), "declared byte length")
			assert_equal(reader.remaining(), 0, "the prefix consumed exactly its bytes")


func test_a_negative_length_prefix_is_refused() -> void:
	"""ARCH-SAVE-005's "illegal negative lengths", which only a signed prefix can carry."""
	var writer: SaveCodec.Writer = SaveCodec.Writer.new(0)
	assert_true(writer.write_i32(-1), "an attacker writes -1 as the length")
	assert_true(writer.write_bytes(PackedByteArray([65, 66, 67])), "and some plausible bytes")
	var reader: SaveCodec.Reader = SaveCodec.Reader.new(writer.to_bytes())
	var out: SaveCodec.Text = SaveCodec.Text.new()
	assert_false(reader.read_utf8_i32_into(1024, out), "a negative length is refused")
	assert_equal(out.refusal, SaveCodec.REFUSE_NEGATIVE_LENGTH, "named refusal")
	assert_equal(out.value, "", "no string is produced")
	assert_equal(out.byte_length, 0, "and no length is produced")


func test_a_huge_length_prefix_is_refused_before_allocating() -> void:
	"""0xffffffff as a u32 prefix in a nine-byte buffer must refuse on the bound, not on memory."""
	var writer: SaveCodec.Writer = SaveCodec.Writer.new(0)
	assert_true(writer.write_u32(SaveCodec.UINT32_MAX), "an attacker writes 4294967295")
	assert_true(writer.write_bytes(PackedByteArray([65, 66, 67, 68, 69])), "and five bytes")
	var reader: SaveCodec.Reader = SaveCodec.Reader.new(writer.to_bytes())
	var out: SaveCodec.Text = SaveCodec.Text.new()
	assert_false(reader.read_utf8_u32_into(SaveCodec.UINT32_MAX, out), "refused on the buffer")
	assert_equal(out.refusal, SaveCodec.REFUSE_LENGTH_EXCEEDS_BUFFER, "named refusal")
	reader.reset()
	assert_false(reader.read_utf8_u32_into(32, out), "refused on the caller's cap first")
	assert_equal(out.refusal, SaveCodec.REFUSE_LENGTH_EXCEEDS_LIMIT, "named refusal")


func test_a_length_prefix_one_byte_past_the_buffer_is_refused() -> void:
	"""The bound is exact: length == remaining is accepted, length == remaining+1 is not."""
	var body: PackedByteArray = PackedByteArray([82, 101, 100])
	var writer: SaveCodec.Writer = SaveCodec.Writer.new(0)
	assert_true(writer.write_u32(body.size()), "an honest length")
	assert_true(writer.write_bytes(body), "and its bytes")
	var reader: SaveCodec.Reader = SaveCodec.Reader.new(writer.to_bytes())
	var out: SaveCodec.Text = SaveCodec.Text.new()
	assert_true(reader.read_utf8_u32_into(64, out), "exactly the remaining bytes are accepted")
	assert_equal(out.value, "Red", "and decode correctly")
	var hostile: PackedByteArray = writer.to_bytes()
	hostile[0] = body.size() + 1
	var second: SaveCodec.Reader = SaveCodec.Reader.new(hostile)
	assert_false(second.read_utf8_u32_into(64, out), "one byte more is refused")
	assert_equal(out.refusal, SaveCodec.REFUSE_LENGTH_EXCEEDS_BUFFER, "named refusal")


func test_a_string_exactly_one_byte_over_its_cap_is_refused() -> void:
	"""The cap bound is exact. length == cap is accepted and length == cap + 1 is not.

	Added after a mutation sweep: relaxing this comparison by one survived every other string
	test, because they all use a cap far from the string they read.
	"""
	var writer: SaveCodec.Writer = SaveCodec.Writer.new(0)
	assert_true(writer.write_utf8_u32("Abbey", 5), "five bytes fit a five-byte cap")
	var bytes: PackedByteArray = writer.to_bytes()
	var out: SaveCodec.Text = SaveCodec.Text.new()
	var at_cap: SaveCodec.Reader = SaveCodec.Reader.new(bytes)
	assert_true(at_cap.read_utf8_u32_into(5, out), "a five-byte string under a five-byte cap")
	assert_equal(out.value, "Abbey", "and it decodes")
	var over_cap: SaveCodec.Reader = SaveCodec.Reader.new(bytes)
	assert_false(over_cap.read_utf8_u32_into(4, out), "the same string under a four-byte cap")
	assert_equal(out.refusal, SaveCodec.REFUSE_LENGTH_EXCEEDS_LIMIT, "named refusal")
	assert_equal(over_cap.position(), SaveCodec.U32_BYTES, "the cursor stops after the prefix")


func test_a_negative_caller_cap_is_refused_rather_than_treated_as_unlimited() -> void:
	"""BLOCKER S2: the cap comes from the caller, so a nonsensical cap must refuse, not open up."""
	var writer: SaveCodec.Writer = SaveCodec.Writer.new(0)
	assert_true(writer.write_utf8_u32("Redwall", 64), "a legitimate string")
	var reader: SaveCodec.Reader = SaveCodec.Reader.new(writer.to_bytes())
	var out: SaveCodec.Text = SaveCodec.Text.new()
	assert_false(reader.read_utf8_u32_into(-1, out), "a negative cap refuses")
	assert_equal(out.refusal, SaveCodec.REFUSE_NEGATIVE_LIMIT, "named refusal")
	var second: SaveCodec.Writer = SaveCodec.Writer.new(0)
	assert_false(second.write_utf8_u32("Redwall", -1), "and on the writing side too")
	assert_equal(second.refusal(), SaveCodec.REFUSE_NEGATIVE_LIMIT, "named refusal")


func test_a_string_longer_than_its_cap_is_refused_on_write() -> void:
	"""The cap is measured in BYTES, so a multi-byte character counts for more than one."""
	var writer: SaveCodec.Writer = SaveCodec.Writer.new(0)
	assert_false(writer.write_utf8_u32("\U0001f430", 3), "four UTF-8 bytes exceed a 3-byte cap")
	assert_equal(writer.refusal(), SaveCodec.REFUSE_LENGTH_EXCEEDS_LIMIT, "named refusal")
	assert_equal(writer.to_bytes(), PackedByteArray(), "a refused writer yields nothing")
	var exact: SaveCodec.Writer = SaveCodec.Writer.new(0)
	assert_true(exact.write_utf8_u32("\U0001f430", 4), "exactly four bytes fit a 4-byte cap")


func test_malformed_utf8_is_refused_in_every_stated_form() -> void:
	"""ARCH-SAVE-005 rejects malformed UTF-8; Godot's own decoder substitutes instead of refusing."""
	var cases: Array[PackedByteArray] = [
		PackedByteArray([0x80]), PackedByteArray([0xbf]),
		PackedByteArray([0xc0, 0x80]), PackedByteArray([0xc1, 0xbf]),
		PackedByteArray([0xe0, 0x80, 0x80]), PackedByteArray([0xed, 0xa0, 0x80]),
		PackedByteArray([0xf0, 0x80, 0x80, 0x80]), PackedByteArray([0xf4, 0x90, 0x80, 0x80]),
		PackedByteArray([0xf5, 0x80, 0x80, 0x80]), PackedByteArray([0xff]),
		PackedByteArray([0xc2]), PackedByteArray([0xe2, 0x82]),
	]
	for bytes: PackedByteArray in cases:
		assert_equal(SaveCodec.utf8_refusal(bytes, 0, bytes.size()),
			SaveCodec.REFUSE_MALFORMED_UTF8, "refused %s" % bytes.hex_encode())


func test_well_formed_utf8_at_every_sequence_width_is_accepted() -> void:
	"""The validator must not be so strict that it rejects the encodings the game will store."""
	var cases: Array[PackedByteArray] = [
		PackedByteArray([0x00]), PackedByteArray([0x7f]),
		PackedByteArray([0xc2, 0x80]), PackedByteArray([0xdf, 0xbf]),
		PackedByteArray([0xe0, 0xa0, 0x80]), PackedByteArray([0xed, 0x9f, 0xbf]),
		PackedByteArray([0xee, 0x80, 0x80]), PackedByteArray([0xef, 0xbf, 0xbf]),
		PackedByteArray([0xf0, 0x90, 0x80, 0x80]), PackedByteArray([0xf4, 0x8f, 0xbf, 0xbf]),
	]
	for bytes: PackedByteArray in cases:
		assert_equal(SaveCodec.utf8_refusal(bytes, 0, bytes.size()), SaveCodec.REFUSE_NONE,
			"accepted %s" % bytes.hex_encode())


func test_an_embedded_nul_refuses_because_it_cannot_round_trip() -> void:
	"""U+0000 is legal UTF-8 but Godot treats it as a terminator, so it is not byte-exact here."""
	var out: SaveCodec.Text = SaveCodec.Text.new()
	var bytes: PackedByteArray = PackedByteArray([65, 0x00, 66])
	assert_equal(SaveCodec.utf8_refusal(bytes, 0, bytes.size()), SaveCodec.REFUSE_NONE,
		"structurally it is valid UTF-8")
	assert_false(SaveCodec.decode_utf8_into(bytes, 0, bytes.size(), out), "but decoding refuses")
	assert_equal(out.refusal, SaveCodec.REFUSE_UTF8_NOT_ROUND_TRIP, "named refusal")
	assert_equal(out.value, "", "and yields no truncated string")


func test_utf8_validation_is_bounded_by_its_own_length_argument() -> void:
	"""A sequence that runs past the declared length is truncated, not silently read further."""
	var bytes: PackedByteArray = PackedByteArray([0xe2, 0x82, 0xac, 0x41])
	assert_equal(SaveCodec.utf8_refusal(bytes, 0, 4), SaveCodec.REFUSE_NONE, "all four are valid")
	assert_equal(SaveCodec.utf8_refusal(bytes, 0, 2), SaveCodec.REFUSE_MALFORMED_UTF8,
		"two bytes of a three-byte sequence refuse")
	assert_equal(SaveCodec.utf8_refusal(bytes, 0, 5), SaveCodec.REFUSE_TRUNCATED,
		"a length past the buffer refuses")
	assert_equal(SaveCodec.utf8_refusal(bytes, -1, 1), SaveCodec.REFUSE_NEGATIVE_OFFSET,
		"a negative offset refuses")


# --- the writer ----------------------------------------------------------------------------------

func test_the_writer_produces_the_same_bytes_as_the_fixed_offset_primitives() -> void:
	"""Two ways of building the same record must agree byte for byte, or one of them is wrong."""
	var writer: SaveCodec.Writer = SaveCodec.Writer.new(0)
	assert_true(writer.write_i64(-30), "tick")
	assert_true(writer.write_u32(U32_HIGH_BIT), "bits")
	var staged: PackedByteArray = _buffer(12)
	var scratch: SaveCodec.Scalar = SaveCodec.Scalar.new()
	assert_true(SaveCodec.write_i64_into(staged, 0, -30, scratch), "tick staged")
	assert_true(SaveCodec.write_u32_into(staged, 8, U32_HIGH_BIT, scratch), "bits staged")
	assert_equal(writer.to_bytes(), staged, "the writer and the static form agree exactly")


func test_the_encoding_is_identical_across_independent_runs() -> void:
	"""Canonical means byte-identical for equal input, including under a different reservation."""
	var first: SaveCodec.Writer = SaveCodec.Writer.new(0)
	var second: SaveCodec.Writer = SaveCodec.Writer.new(4096)
	for writer: SaveCodec.Writer in [first, second]:
		assert_true(writer.write_i64(13500), "tick")
		assert_true(writer.write_utf8_u32("Matthias", 64), "name")
		assert_true(writer.write_zero_padding(7), "reserved")
		assert_true(writer.write_i32(SaveCodec.INT32_MIN), "slot")
	assert_equal(first.to_bytes(), second.to_bytes(), "reservation cannot change the bytes")
	assert_equal(first.length(), second.length(), "nor the length")
	assert_equal(first.length(), 8 + 4 + 8 + 7 + 4, "and the length is the sum of the fields")


func test_a_refused_writer_yields_nothing_and_stays_refused() -> void:
	"""A half-written record must never escape; the first refusal is the one reported."""
	var writer: SaveCodec.Writer = SaveCodec.Writer.new(0)
	assert_true(writer.write_i64(1), "a good field")
	assert_false(writer.write_u32(-1), "then a bad one")
	assert_equal(writer.refusal(), SaveCodec.REFUSE_VALUE_RANGE, "named refusal")
	assert_false(writer.write_i64(2), "later writes refuse too")
	assert_equal(writer.refusal(), SaveCodec.REFUSE_VALUE_RANGE, "and keep the first code")
	assert_equal(writer.to_bytes(), PackedByteArray(), "no partial record is produced")


func test_a_resized_packed_byte_array_is_zero_filled() -> void:
	"""A pinned ENGINE assumption, not a claim about this module.

	`Writer.write_zero_padding()` writes its zeroes explicitly, but that loop is unobservable
	from outside: the backing buffer only ever grows through `resize()`, which zero-fills, and
	the write cursor never moves backwards, so the bytes are already zero when the loop runs.
	A mutation sweep found the loop's removal survives for exactly that reason. Rather than
	leave the dependency silent, it is pinned here: if Godot ever stops zero-filling, this fails
	and the explicit loop in the writer becomes load-bearing instead of belt-and-braces.
	"""
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(4)
	for index: int in 4:
		bytes[index] = 255
	bytes.resize(8)
	for index: int in range(4, 8):
		assert_equal(bytes[index], 0, "resize() zero-fills new element %d" % index)
	assert_equal(bytes[0], 255, "and leaves the existing elements alone")


func test_the_writer_rejects_negative_padding_and_writes_real_zeroes() -> void:
	"""Padding must be zeroed, not merely reserved, or a reused buffer leaks old bytes."""
	var writer: SaveCodec.Writer = SaveCodec.Writer.new(0)
	assert_true(writer.write_u8(255), "a nonzero byte first")
	assert_true(writer.write_zero_padding(24), "then reserved padding")
	var bytes: PackedByteArray = writer.to_bytes()
	assert_equal(bytes.size(), 25, "the padding is counted")
	assert_equal(SaveCodec.zero_padding_refusal(bytes, 1, 24), SaveCodec.REFUSE_NONE,
		"and every padding byte really is zero")
	var second: SaveCodec.Writer = SaveCodec.Writer.new(0)
	assert_false(second.write_zero_padding(-1), "a negative padding count refuses")


# --- the integer-only rule ---------------------------------------------------------------------

func test_the_codec_source_contains_no_float_path() -> void:
	"""ARCH-AUTH-002: a save codec must never introduce a float. Enforced against the source."""
	var source: String = FileAccess.get_file_as_string(SOURCE_PATH)
	assert_true(source.length() > 0, "the codec source was read")
	for banned: String in ["encode_float", "decode_float", "encode_double", "decode_double",
			"encode_half", "decode_half", "PackedFloat32Array", "PackedFloat64Array",
			": float", "-> float"]:
		assert_false(source.contains(banned), "the codec source contains no '%s'" % banned)
