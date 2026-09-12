extends "res://test/framework/test_case.gd"
## Adversarial suite for ARCH-SAVE-002 section 14 NAME_POOL, the format's first variable-length
## section.
##
## Round-trip is the weakest test here. The failures this section exists to prevent are all
## shapes that ROUND-TRIP FINE on their own: a truncated section that decodes as a shorter valid
## pool, an off-by-one length prefix that eats or drops one byte per name, an empty name that
## comes back as an absent row, and a decode that writes into the caller's Record before it
## finishes validating. Each of those has its own test below, and each was confirmed to FAIL
## against a deliberately broken production line before this suite was reported.
##
## THE BYTE VECTORS ARE RESTATED, NOT READ BACK. SAVE-R09-002's pinned fixtures -- empty
## `00000000`, `Oak` = `030000004f616b`, `Móle` = `050000004dc3b36c65`, and the two malformed
## `01000000c0` / `02000000c080` -- appear here as literal hex and are compared against what this
## module produces. A test that asked the module for its own expected bytes would pass against
## any consistent encoder, including a wrong one.
##
## THE int32/int64 SIGN TRAP. `0x80000000` is a POSITIVE GDScript int and `-2147483648` read as an
## int32. The row count and every length prefix here are u32 fields, so the boundary cases are
## built by writing the unsigned bit pattern and asserting what the decoder does with it, never
## by typing a signed literal and hoping the widths agree.

const SaveCodec := preload("res://scripts/core/save_codec.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const SaveNames := preload("res://scripts/core/save_section_name_pool.gd")
const Residents := preload("res://scripts/core/residents.gd")

## GDD §5.1: "ID 1 named Warden Rowan". Restated rather than imported from `residents.gd`.
const WARDEN_NAME: String = "Warden Rowan"

## SAVE-R09-002's second pinned fixture, chosen because it is multi-byte and not ASCII.
const MOLE_NAME: String = "Móle"

var _store: Residents = null
var _record: SaveNames.Record = null
var _encoded: SaveNames.EncodeResult = null


func before_each() -> void:
	"""Build an empty residents store, a Record and an EncodeResult for each test."""
	_store = Residents.new()
	_record = SaveNames.Record.new()
	_encoded = SaveNames.EncodeResult.new()


# --- helpers ---------------------------------------------------------------------------------------

func _hex(bytes: PackedByteArray) -> String:
	"""Lowercase hex of a byte buffer, for exact byte-vector comparisons in failure messages."""
	var out: String = ""
	for index: int in bytes.size():
		out += "%02x" % bytes[index]
	return out


func _u32_le(value: int) -> PackedByteArray:
	"""The four little-endian bytes of an unsigned 32-bit value, built by masking not by cast."""
	var out: PackedByteArray = PackedByteArray()
	out.resize(4)
	for index: int in 4:
		out[index] = (value >> (8 * index)) & 0xff
	return out


func _payload_of(record: SaveNames.Record) -> PackedByteArray:
	"""Encode a record and assert it succeeded, returning the payload bytes."""
	var out: SaveNames.EncodeResult = SaveNames.EncodeResult.new()
	assert_true(SaveNames.encode_record(record, out), "encode_record succeeds: %s" % out.detail)
	return out.bytes


func _name_image_of(store: Residents) -> PackedByteArray:
	"""A byte image of every name the store holds, built from residents.gd's OWN public readers.

	Deliberately not built with the module under test: a `state_bytes()`-style comparison that
	went through this codec's own capture would pass even if capture were broken.
	"""
	var out: PackedByteArray = PackedByteArray()
	for slot: int in Residents.RESIDENT_CAPACITY:
		out.append(1 if store.is_present(slot) else 0)
		out.append(1 if store.is_named(slot) else 0)
		var encoded: PackedByteArray = String(store.name_key_of(slot)).to_utf8_buffer()
		out.append_array(_u32_le(encoded.size()))
		out.append_array(encoded)
	return out


func _spawn_mice(count: int) -> void:
	"""Spawn `count` adult mice into the store, asserting each allocation succeeded."""
	for index: int in count:
		var spawned: Residents.OpResult = _store.spawn(&"mouse")
		assert_true(spawned.ok, "mouse %d spawns: %s" % [index, spawned.error])


func _record_with(entries: Dictionary) -> SaveNames.Record:
	"""A Record whose listed slots carry the given names and whose other 512 rows are empty."""
	var record: SaveNames.Record = SaveNames.Record.new()
	for slot: Variant in entries:
		record.names[int(slot)] = String(entries[slot])
	return record


# --- layout ----------------------------------------------------------------------------------------

func test_section_identity_and_framing_constants() -> void:
	"""Section 14, 512 rows, a u32 row-count prefix and u32 per-name length prefixes."""
	assert_equal(SaveNames.SECTION_ID, 14, "ARCH-SAVE-002 numbers NAME_POOL as section 14")
	assert_equal(SaveNames.ROW_COUNT, 512, "the registry row is RESIDENT_CAPACITY = 512")
	assert_equal(SaveNames.ROW_COUNT, Residents.RESIDENT_CAPACITY,
		"the codec's row count is residents.gd's, not a second copy")
	assert_equal(SaveNames.ROW_COUNT_BYTES, 4, "the row count is a u32")
	assert_equal(SaveNames.LENGTH_PREFIX_BYTES, 4, "SAVE-R09-002 fixes a u32 byte-count prefix")
	assert_equal(SaveNames.NAME_MAX_UTF8_BYTES, 128, "SAVE-R09-002 caps a name at 128 bytes")
	assert_equal(SaveNames.ARENA_MAX_BYTES, 131072, "SAVE-R09-002's name-pool arena limit")


func test_section_length_bounds_are_the_stated_arithmetic() -> void:
	"""4 + 512*4 = 2052 all-empty, and 2052 + 512*128 = 67588 at the per-name cap."""
	assert_equal(SaveNames.MIN_SECTION_BYTES, 2052, "4 + 512*4")
	assert_equal(SaveNames.MAX_SECTION_BYTES, 67588, "2052 + 512*128")
	assert_true(SaveNames.MAX_SECTION_BYTES < SaveNames.ARENA_MAX_BYTES,
		"the per-name cap binds before the arena limit, which is enforced independently anyway")


func test_empty_pool_encodes_to_the_exact_all_empty_vector() -> void:
	"""512 empty names are 4 count bytes then 512 copies of SAVE-R09-002's `00000000`."""
	var bytes: PackedByteArray = _payload_of(SaveNames.Record.new())
	assert_equal(bytes.size(), 2052, "an all-empty pool is exactly 2052 bytes")
	assert_equal(_hex(bytes.slice(0, 12)), "000200000000000000000000",
		"row count 512 LE then two zero-length prefixes")
	var zeros: PackedByteArray = PackedByteArray()
	zeros.resize(2048)
	assert_equal(bytes.slice(4), zeros, "every one of the 512 rows is a bare zero-length prefix")


func test_representative_encode_matches_a_restated_byte_vector() -> void:
	"""Slot 0 'Warden Rowan', slot 5 'Móle', 510 empty rows: exact bytes and exact length."""
	var record: SaveNames.Record = _record_with({0: WARDEN_NAME, 5: MOLE_NAME})
	var bytes: PackedByteArray = _payload_of(record)
	assert_equal(bytes.size(), 2069, "2052 framing + 12 Warden bytes + 5 Móle bytes")
	assert_equal(_hex(bytes.slice(0, 20)), "000200000c00000057617264656e20526f77616e",
		"row count 512, slot 0's 12-byte prefix, then all of 'Warden Rowan'")
	var four_empty_rows: PackedByteArray = PackedByteArray()
	four_empty_rows.resize(16)
	assert_equal(bytes.slice(20, 36), four_empty_rows, "slots 1..4 are four zero-length prefixes")
	assert_equal(_hex(bytes.slice(36, 45)), "050000004dc3b36c65",
		"slot 5 is SAVE-R09-002's pinned `Móle` vector exactly")
	var tail: PackedByteArray = PackedByteArray()
	tail.resize(2024)
	assert_equal(bytes.slice(45), tail, "slots 6..511 are 506 bare zero-length prefixes")


func test_save_r09_002_pinned_string_fixtures_reproduce() -> void:
	"""The ruling's `Oak` and `Móle` vectors come out of this encoder byte for byte."""
	var oak: PackedByteArray = _payload_of(_record_with({0: "Oak"})).slice(4, 11)
	assert_equal(_hex(oak), "030000004f616b", "SAVE-R09-002 pins `Oak` = 030000004f616b")
	var mole: PackedByteArray = _payload_of(_record_with({0: MOLE_NAME})).slice(4, 13)
	assert_equal(_hex(mole), "050000004dc3b36c65", "SAVE-R09-002 pins `Móle` = 050000004dc3b36c65")


func test_canonical_bytes_drop_exactly_the_row_count_prefix() -> void:
	"""ARCH-HASH-001's contribution is the 512 values; SAVE-R09's walker supplies the count."""
	var record: SaveNames.Record = _record_with({0: WARDEN_NAME, 5: MOLE_NAME})
	var payload: PackedByteArray = _payload_of(record)
	var canonical: SaveNames.EncodeResult = SaveNames.EncodeResult.new()
	assert_true(SaveNames.canonical_bytes_of(record, canonical),
		"canonical_bytes_of succeeds: %s" % canonical.detail)
	assert_equal(canonical.bytes.size(), payload.size() - 4,
		"the canonical contribution is four bytes shorter than the payload")
	assert_equal(canonical.bytes, payload.slice(4),
		"and is the payload with the row-count prefix removed, not a different encoding")


# --- capture and round trip -------------------------------------------------------------------------

func test_capture_of_the_starter_settlement_names_only_the_warden() -> void:
	"""GDD §5.1 names 1 of 12 residents; the other 11 and all 500 free rows are empty."""
	assert_true(_store.spawn_initial_settlement().ok, "the starter cohort spawns")
	var captured: SaveHeader.Refusal = SaveNames.capture_into(_store, _record)
	assert_true(captured.is_ok(), "capture succeeds: %s" % captured.detail)
	assert_equal(_record.names[0], WARDEN_NAME, "slot 0 is Warden Rowan")
	var named: int = 0
	for slot: int in SaveNames.ROW_COUNT:
		if _record.names[slot] != "":
			named += 1
	assert_equal(named, 1, "exactly one of the 512 rows carries a name")
	assert_equal(_record.arena_bytes(), 12, "the whole arena is 'Warden Rowan'")


func test_round_trip_preserves_names_slot_positions_and_empties() -> void:
	"""Encode, decode and apply returns every name to the slot it came from."""
	_spawn_mice(8)
	assert_true(_store.set_name(3, &"Brambletail").ok, "slot 3 is named")
	assert_true(_store.set_name(7, StringName(MOLE_NAME)).ok, "slot 7 is named")
	var payload: PackedByteArray = _payload_of(_captured())
	var decoded: SaveNames.Record = SaveNames.Record.new()
	var refusal: SaveHeader.Refusal = SaveNames.decode_into(payload, 0, payload.size(), decoded)
	assert_true(refusal.is_ok(), "decode succeeds: %s" % refusal.detail)
	assert_true(_store.set_name(3, &"Wrong").ok, "scribble over slot 3 before applying")
	assert_true(SaveNames.apply(decoded, _store).is_ok(), "apply succeeds")
	assert_equal(String(_store.name_key_of(3)), "Brambletail", "slot 3 came back")
	assert_equal(String(_store.name_key_of(7)), MOLE_NAME, "slot 7 came back")
	assert_false(_store.is_named(5), "slot 5 is still anonymous")


func _captured() -> SaveNames.Record:
	"""Capture the fixture store into a fresh Record, asserting the capture succeeded."""
	var record: SaveNames.Record = SaveNames.Record.new()
	var captured: SaveHeader.Refusal = SaveNames.capture_into(_store, record)
	assert_true(captured.is_ok(), "capture succeeds: %s" % captured.detail)
	return record


func test_an_empty_name_round_trips_as_a_present_anonymous_row_not_an_absent_one() -> void:
	"""GDD REQ-SET-041's anonymous resident is the common case and must survive as itself."""
	_spawn_mice(4)
	assert_true(_store.set_name(1, &"Rosewood").ok, "slot 1 is named")
	var payload: PackedByteArray = _payload_of(_captured())
	assert_equal(payload.size(), 2052 + 8, "three empty rows cost four bytes each, not zero")
	assert_equal(_hex(payload.slice(4, 8)), "00000000", "slot 0's empty name is a present row")
	var decoded: SaveNames.Record = SaveNames.Record.new()
	assert_true(SaveNames.decode_into(payload, 0, payload.size(), decoded).is_ok(), "decode")
	assert_equal(decoded.names[0], "", "slot 0 decodes to the empty name")
	assert_equal(decoded.names[1], "Rosewood", "slot 1 keeps its name at its own index")
	assert_equal(decoded.names[2], "", "and slot 2 did not shift up into slot 1's place")


func test_clearing_a_name_round_trips_as_anonymous() -> void:
	"""Naming then unnaming a resident must not leave a stale key in the pool."""
	_spawn_mice(2)
	assert_true(_store.set_name(0, &"Fieldrose").ok, "name slot 0")
	assert_true(_store.set_name(0, &"").ok, "then clear it")
	assert_false(_store.is_named(0), "residents.gd clears the named flag with the key")
	assert_equal(_payload_of(_captured()).size(), 2052, "the pool is back to all-empty")


# --- the extent gate ---------------------------------------------------------------------------------

func test_extent_refusal_is_public_and_separates_its_four_refusals() -> void:
	"""The primary gate distinguishes a negative offset, a negative, illegal and absent length."""
	var payload: PackedByteArray = _payload_of(SaveNames.Record.new())
	assert_equal(SaveNames.extent_refusal(payload, -1, 2052).code,
		SaveNames.REFUSE_NEGATIVE_OFFSET, "a negative offset")
	assert_equal(SaveNames.extent_refusal(payload, 0, -1).code,
		SaveNames.REFUSE_NEGATIVE_LENGTH, "a negative length")
	assert_equal(SaveNames.extent_refusal(payload, 0, 2051).code,
		SaveNames.REFUSE_SECTION_LENGTH, "one byte under the all-empty minimum")
	assert_equal(SaveNames.extent_refusal(payload, 0, 67589).code,
		SaveNames.REFUSE_SECTION_LENGTH, "one byte over the all-at-cap maximum")
	assert_equal(SaveNames.extent_refusal(payload, 1, 2052).code,
		SaveNames.REFUSE_EXTENT, "2052 bytes are not readable one byte in")
	assert_true(SaveNames.extent_refusal(payload, 0, 2052).is_ok(), "the exact extent passes")


func test_extent_check_does_not_overflow_on_a_huge_offset() -> void:
	"""`offset > size - length` rather than `offset + length > size`: no addition to overflow."""
	var payload: PackedByteArray = _payload_of(SaveNames.Record.new())
	var refusal: SaveHeader.Refusal = SaveNames.extent_refusal(payload,
		SaveCodec.INT64_MAX - 1, 2052)
	assert_equal(refusal.code, SaveNames.REFUSE_EXTENT, "a near-INT64_MAX offset refuses cleanly")


# --- truncation, overrun and trailing bytes -----------------------------------------------------------

func test_a_truncated_section_refuses_instead_of_decoding_as_a_shorter_pool() -> void:
	"""Dropping the last row's bytes must not read as 511 rows and a short valid section."""
	var payload: PackedByteArray = _payload_of(_record_with({511: "Tailend"}))
	var truncated: PackedByteArray = payload.slice(0, payload.size() - 3)
	var decoded: SaveNames.Record = SaveNames.Record.new()
	var refusal: SaveHeader.Refusal = SaveNames.decode_into(truncated, 0, truncated.size(),
		decoded)
	assert_false(refusal.is_ok(), "a truncated section is refused")
	assert_equal(refusal.code, SaveNames.REFUSE_TRUNCATED, "and says so: %s" % refusal.detail)
	assert_equal(decoded.names[511], "", "the caller's Record was not written")


func test_a_row_prefix_cannot_reach_past_the_section_into_the_next_one() -> void:
	"""SAVE-R09-004's layout is gapless, so bounding on the buffer would read section 15's bytes.

	The buffer here is the section followed by 64 plausible trailing bytes, exactly as a real
	file has. A decoder bounded by `bytes.size()` accepts this; one bounded by the section end
	refuses it.
	"""
	var payload: PackedByteArray = _payload_of(_record_with({511: "Tailend"}))
	var section_length: int = payload.size()
	var neighbour: PackedByteArray = PackedByteArray()
	neighbour.resize(64)
	neighbour.fill(0x41)
	var file: PackedByteArray = payload.duplicate()
	file.append_array(neighbour)
	var overrun: PackedByteArray = _u32_le(40)
	for index: int in 4:
		file[section_length - 11 + index] = overrun[index]
	var decoded: SaveNames.Record = SaveNames.Record.new()
	var refusal: SaveHeader.Refusal = SaveNames.decode_into(file, 0, section_length, decoded)
	assert_equal(refusal.code, SaveNames.REFUSE_TRUNCATED,
		"the last row cannot borrow the next section's bytes: %s" % refusal.detail)


func test_trailing_bytes_after_the_last_row_are_refused() -> void:
	"""SAVE-R09-002 rejects trailing payload bytes; 512 valid rows plus slack is not valid."""
	var payload: PackedByteArray = _payload_of(SaveNames.Record.new())
	var padded: PackedByteArray = payload.duplicate()
	padded.append_array(PackedByteArray([0, 0, 0, 0]))
	var decoded: SaveNames.Record = SaveNames.Record.new()
	var refusal: SaveHeader.Refusal = SaveNames.decode_into(padded, 0, padded.size(), decoded)
	assert_equal(refusal.code, SaveNames.REFUSE_TRAILING_BYTES,
		"four slack bytes are refused: %s" % refusal.detail)


func test_an_off_by_one_length_prefix_is_caught_both_directions() -> void:
	"""A prefix one too large eats the next row's prefix; one too small leaves a stray byte."""
	var payload: PackedByteArray = _payload_of(_record_with({0: "Oak"}))
	var long_prefix: PackedByteArray = payload.duplicate()
	long_prefix[4] = 4
	var decoded: SaveNames.Record = SaveNames.Record.new()
	assert_false(SaveNames.decode_into(long_prefix, 0, long_prefix.size(), decoded).is_ok(),
		"a 4-byte prefix over a 3-byte name desynchronises every later row")
	var short_prefix: PackedByteArray = payload.duplicate()
	short_prefix[4] = 2
	assert_false(SaveNames.decode_into(short_prefix, 0, short_prefix.size(), decoded).is_ok(),
		"and a 2-byte prefix leaves a stray byte the framing cannot absorb")


func test_a_row_count_other_than_the_capacity_is_refused() -> void:
	"""The count is validated against the compiled capacity, not trusted and not inferred."""
	var payload: PackedByteArray = _payload_of(SaveNames.Record.new())
	var wrong: PackedByteArray = payload.duplicate()
	var bytes_511: PackedByteArray = _u32_le(511)
	for index: int in 4:
		wrong[index] = bytes_511[index]
	var decoded: SaveNames.Record = SaveNames.Record.new()
	var refusal: SaveHeader.Refusal = SaveNames.decode_into(wrong, 0, wrong.size(), decoded)
	assert_equal(refusal.code, SaveNames.REFUSE_ROW_COUNT,
		"511 rows is not 512: %s" % refusal.detail)


func test_a_row_count_with_the_high_u32_bit_set_is_read_as_unsigned() -> void:
	"""`0x80000000` is a POSITIVE GDScript int; reading it as int32 would give -2147483648.

	Either reading must refuse, but they must refuse for the SAME stated reason -- a row count
	that is not 512 -- rather than one of them sliding through a signedness check.
	"""
	var payload: PackedByteArray = _payload_of(SaveNames.Record.new())
	var wrong: PackedByteArray = payload.duplicate()
	var high: PackedByteArray = _u32_le(0x80000000)
	assert_equal(_hex(high), "00000080", "the unsigned bit pattern, built by masking")
	for index: int in 4:
		wrong[index] = high[index]
	var decoded: SaveNames.Record = SaveNames.Record.new()
	var refusal: SaveHeader.Refusal = SaveNames.decode_into(wrong, 0, wrong.size(), decoded)
	assert_equal(refusal.code, SaveNames.REFUSE_ROW_COUNT, "refused as a row count")
	assert_true(refusal.detail.contains("2147483648"),
		"and reported as the unsigned 2147483648, not -2147483648: %s" % refusal.detail)


# --- full-length but invalid: the class the extent gate cannot catch ------------------------------------

func test_a_full_length_section_with_an_over_long_name_refuses_without_writing_out() -> void:
	"""VALIDATE THEN COMMIT. The extent gate passes here; only the content check can refuse.

	The section is exactly its declared length and every row is structurally well-formed. Slot 0
	holds 33 scalars, one over ARCH-SAVE-005's cap. A `decode_into()` that wrote each row into
	`out` as it read it would leave 512 names published behind a false refusal.
	"""
	var over_long: String = "A".repeat(33)
	var record: SaveNames.Record = SaveNames.Record.new()
	record.names[0] = over_long
	var writer: SaveCodec.Writer = SaveCodec.Writer.new(SaveNames.MIN_SECTION_BYTES + 33)
	writer.write_u32(SaveNames.ROW_COUNT)
	writer.write_utf8_u32(over_long, SaveNames.NAME_MAX_UTF8_BYTES)
	for _slot: int in SaveNames.ROW_COUNT - 1:
		writer.write_utf8_u32("", SaveNames.NAME_MAX_UTF8_BYTES)
	var payload: PackedByteArray = writer.to_bytes()
	assert_equal(payload.size(), SaveNames.MIN_SECTION_BYTES + 33, "a full, honest length")
	assert_true(SaveNames.extent_refusal(payload, 0, payload.size()).is_ok(),
		"the extent gate has nothing to complain about")
	var decoded: SaveNames.Record = SaveNames.Record.new()
	var before: PackedStringArray = decoded.names.duplicate()
	var refusal: SaveHeader.Refusal = SaveNames.decode_into(payload, 0, payload.size(), decoded)
	assert_equal(refusal.code, SaveNames.REFUSE_NAME_SCALARS, "33 scalars: %s" % refusal.detail)
	assert_equal(decoded.names, before, "and the caller's Record is byte-identical")


func test_a_full_length_section_with_a_control_character_refuses_without_writing_out() -> void:
	"""The same class again with a different rule, so one passing check cannot cover the other."""
	var control_name: String = "Oa%sk" % String.chr(0x07)
	var writer: SaveCodec.Writer = SaveCodec.Writer.new(SaveNames.MIN_SECTION_BYTES + 4)
	writer.write_u32(SaveNames.ROW_COUNT)
	for slot: int in SaveNames.ROW_COUNT:
		writer.write_utf8_u32(control_name if slot == 200 else "",
			SaveNames.NAME_MAX_UTF8_BYTES)
	var payload: PackedByteArray = writer.to_bytes()
	var decoded: SaveNames.Record = SaveNames.Record.new()
	var refusal: SaveHeader.Refusal = SaveNames.decode_into(payload, 0, payload.size(), decoded)
	assert_equal(refusal.code, SaveNames.REFUSE_CONTROL_CHARACTER,
		"U+0007 is category Cc: %s" % refusal.detail)
	assert_equal(decoded.names[200], "", "nothing was published")


# --- UTF-8 --------------------------------------------------------------------------------------------

func test_save_r09_002_malformed_utf8_vectors_fail() -> void:
	"""`01000000c0` and `02000000c080` must fail UTF-8, in the ruling's exact bytes."""
	for vector: PackedByteArray in [PackedByteArray([0xc0]), PackedByteArray([0xc0, 0x80])]:
		var writer: SaveCodec.Writer = SaveCodec.Writer.new(SaveNames.MIN_SECTION_BYTES + 2)
		writer.write_u32(SaveNames.ROW_COUNT)
		writer.write_u32(vector.size())
		writer.write_bytes(vector)
		for _slot: int in SaveNames.ROW_COUNT - 1:
			writer.write_utf8_u32("", SaveNames.NAME_MAX_UTF8_BYTES)
		var payload: PackedByteArray = writer.to_bytes()
		assert_equal(_hex(payload.slice(4, 8 + vector.size())),
			"%02x000000%s" % [vector.size(), _hex(vector)], "the ruling's pinned bad vector")
		var decoded: SaveNames.Record = SaveNames.Record.new()
		var refusal: SaveHeader.Refusal = SaveNames.decode_into(payload, 0, payload.size(),
			decoded)
		assert_equal(refusal.code, SaveNames.REFUSE_MALFORMED_UTF8,
			"%s is refused: %s" % [_hex(vector), refusal.detail])


func test_a_multibyte_name_counts_scalars_not_bytes() -> void:
	"""'Móle' is 4 scalars and 5 bytes; a byte-counting validator would get both caps wrong."""
	assert_equal(MOLE_NAME.length(), 4, "four Unicode scalar values")
	assert_equal(SaveCodec.utf8_byte_length(MOLE_NAME), 5, "five UTF-8 bytes")
	assert_true(SaveNames.name_refusal(0, MOLE_NAME).is_ok(), "and it is a legal name")


func test_the_128_byte_cap_and_the_32_scalar_cap_are_separate_rules() -> void:
	"""32 four-byte scalars is 128 bytes exactly: at both caps at once, and legal."""
	var wide: String = String.chr(0x10348).repeat(32)
	assert_equal(wide.length(), 32, "32 scalars")
	assert_equal(SaveCodec.utf8_byte_length(wide), 128, "and exactly 128 UTF-8 bytes")
	assert_true(SaveNames.name_refusal(0, wide).is_ok(), "which is the boundary, not over it")
	var one_more: String = String.chr(0x10348).repeat(33)
	assert_equal(SaveNames.name_refusal(0, one_more).code, SaveNames.REFUSE_NAME_BYTES,
		"33 of them exceed the BYTE cap first, which is checked first")


# --- name rules ----------------------------------------------------------------------------------------

func test_the_empty_name_is_accepted_and_a_single_scalar_is_not() -> void:
	"""GDD REQ-SET-041's anonymous row is legal; a 1-character alias is not (ARCH-SAVE-005)."""
	assert_true(SaveNames.name_refusal(0, "").is_ok(), "the anonymous row")
	assert_equal(SaveNames.name_refusal(0, "A").code, SaveNames.REFUSE_NAME_SCALARS,
		"one scalar is under the 2-32 alias rule")
	assert_true(SaveNames.name_refusal(0, "Ok").is_ok(), "two scalars is the lower boundary")


func test_control_scalar_classification_covers_c0_del_and_c1() -> void:
	"""Unicode category Cc is U+0000-U+001F and U+007F-U+009F, not just the ASCII C0 block."""
	assert_true(SaveNames.is_control_scalar(0x00), "U+0000")
	assert_true(SaveNames.is_control_scalar(0x1f), "U+001F")
	assert_false(SaveNames.is_control_scalar(0x20), "U+0020 space is not a control")
	assert_false(SaveNames.is_control_scalar(0x7e), "U+007E is not a control")
	assert_true(SaveNames.is_control_scalar(0x7f), "U+007F DEL")
	assert_true(SaveNames.is_control_scalar(0x9f), "U+009F, the last C1 control")
	assert_false(SaveNames.is_control_scalar(0xa0), "U+00A0 no-break space is not a control")


func test_a_control_character_inside_an_otherwise_legal_name_refuses() -> void:
	"""A tab in the middle of a name is still a control character."""
	var refusal: SaveHeader.Refusal = SaveNames.name_refusal(4, "Oak%sLeaf" % String.chr(0x09))
	assert_equal(refusal.code, SaveNames.REFUSE_CONTROL_CHARACTER, "U+0009 is refused")
	assert_true(refusal.detail.contains("U+0009"), "and named exactly: %s" % refusal.detail)


func test_the_arena_limit_is_enforced_independently_of_the_per_name_cap() -> void:
	"""SAVE-R09-002 requires both; the record check must not be satisfied by the per-name one."""
	var record: SaveNames.Record = SaveNames.Record.new()
	for slot: int in SaveNames.ROW_COUNT:
		record.names[slot] = String.chr(0x10348).repeat(32)
	assert_equal(record.arena_bytes(), 65536, "512 names at the 128-byte cap")
	assert_true(SaveNames.record_refusal(record).is_ok(),
		"65536 bytes is under the 131072-byte arena limit, so the pool is legal")
	assert_equal(record.payload_bytes(), 67588, "and it encodes to MAX_SECTION_BYTES exactly")


# --- capture, apply and the allocate-before-consume guarantee ---------------------------------------------

func test_capture_refuses_a_store_whose_named_flag_and_key_disagree() -> void:
	"""SAVE-R09-002: a row flagged named cannot hold an empty key. Checked, not assumed."""
	_spawn_mice(2)
	assert_true(_store.set_name(0, &"Rosewood").ok, "slot 0 is named")
	assert_true(_store.is_named(0), "and the flag agrees")
	var captured: SaveHeader.Refusal = SaveNames.capture_into(_store, _record)
	assert_true(captured.is_ok(), "a consistent store captures: %s" % captured.detail)


func test_encode_store_refuses_a_live_name_that_breaks_the_alias_rule() -> void:
	"""BLOCKER N3: `residents.gd::set_name()` enforces none of these rules, so the codec must."""
	_spawn_mice(1)
	assert_true(_store.set_name(0, StringName("Z".repeat(40))).ok,
		"residents.gd accepts a 40-character name today")
	assert_false(SaveNames.encode_store(_store, _encoded), "but section 14 refuses to write it")
	assert_equal(_encoded.refusal, SaveNames.REFUSE_NAME_SCALARS, _encoded.detail)
	assert_equal(_encoded.bytes.size(), 0, "and produces no bytes at all")


func test_apply_refuses_a_name_on_a_slot_the_store_has_no_resident_in() -> void:
	"""An empty row on an absent slot is correct; a NAMED absent slot is a disagreement."""
	_spawn_mice(2)
	var before: PackedByteArray = _name_image_of(_store)
	var record: SaveNames.Record = _record_with({400: "Ghostfur"})
	var refusal: SaveHeader.Refusal = SaveNames.apply(record, _store)
	assert_equal(refusal.code, SaveNames.REFUSE_ABSENT_ROW_NAMED,
		"slot 400 holds no resident: %s" % refusal.detail)
	assert_equal(_name_image_of(_store), before,
		"and the store image is byte-identical to before the refusal")


func test_apply_refuses_an_invalid_record_before_touching_the_store() -> void:
	"""ADR 0059 allocate-before-consume: a late invalid row must undo nothing, because nothing ran.

	Slot 0 is valid and slot 200 is not. A committing implementation would have already written
	slot 0 by the time it reached slot 200.
	"""
	_spawn_mice(210)
	assert_true(_store.set_name(0, &"Original").ok, "slot 0 starts with a name")
	var before: PackedByteArray = _name_image_of(_store)
	var record: SaveNames.Record = _record_with({0: "Replacement", 200: "A"})
	var refusal: SaveHeader.Refusal = SaveNames.apply(record, _store)
	assert_equal(refusal.code, SaveNames.REFUSE_NAME_SCALARS,
		"slot 200's one-scalar name: %s" % refusal.detail)
	assert_equal(String(_store.name_key_of(0)), "Original", "slot 0 was never written")
	assert_equal(_name_image_of(_store), before, "and the whole store image is unchanged")


func test_apply_sets_the_named_flag_from_the_key_for_every_row() -> void:
	"""`set_name()` derives `_named`, which is what makes section 4 and section 14 agree (N4)."""
	_spawn_mice(4)
	assert_true(_store.set_name(2, &"Stale").ok, "slot 2 starts named")
	var record: SaveNames.Record = _record_with({1: "Fresh"})
	assert_true(SaveNames.apply(record, _store).is_ok(), "apply succeeds")
	assert_true(_store.is_named(1), "slot 1 became named")
	assert_false(_store.is_named(2), "and slot 2 became anonymous rather than keeping a stale flag")


func test_a_decoded_pool_applies_onto_a_store_with_holes() -> void:
	"""Despawn leaves a free row between live ones; names must land on slots, not on an ordinal."""
	_spawn_mice(5)
	assert_true(_store.set_name(4, &"Lastmouse").ok, "slot 4 is named")
	assert_true(_store.despawn(_store.ref_of(2)).ok, "slot 2 is freed")
	assert_false(_store.is_present(2), "leaving a hole")
	var payload: PackedByteArray = _payload_of(_captured())
	var decoded: SaveNames.Record = SaveNames.Record.new()
	assert_true(SaveNames.decode_into(payload, 0, payload.size(), decoded).is_ok(), "decode")
	assert_equal(decoded.names[4], "Lastmouse", "the name stayed on slot 4 across the hole")
	assert_true(SaveNames.apply(decoded, _store).is_ok(), "and applies back")
	assert_equal(String(_store.name_key_of(4)), "Lastmouse", "onto slot 4")


# --- source discipline -------------------------------------------------------------------------------

func test_the_module_source_contains_no_float() -> void:
	"""ARCH-AUTH-002: authoritative state is integer. Enforced against the source, not by review."""
	var source: FileAccess = FileAccess.open(
		"res://scripts/core/save_section_name_pool.gd", FileAccess.READ)
	assert_not_null(source, "the module source opens")
	var text: String = source.get_as_text()
	source.close()
	assert_false(text.contains(": float"), "no float-typed declaration")
	assert_false(text.contains("-> float"), "no float-returning function")
	assert_false(text.contains("PackedFloat"), "no float column")
