extends "res://test/framework/test_case.gd"
## Adversarial suite for ARCH-SAVE-002 section 3 ENTITY_DIRECTORY.
##
## Section 3 is the identity backbone: every `EntityRef = (slot, generation)` in every other
## section resolves through these six columns, so a section 3 that loads subtly wrong corrupts
## everything downstream in silence. Round-trip equality is therefore the FLOOR, not the test.
## The cases that matter are the ones where a wrong load still looks entirely plausible:
##
##   * a generation off by one -- the reloaded world hands out a `(slot, generation)` pair that a
##     pre-save reference still holds, and that stale reference validates against an unrelated row;
##   * a retired slot loaded as reusable -- the allocator hands back a slot whose generation has
##     already been spent, and the next wrap collides;
##   * a free slot's `-1` typed row loaded as row 0 -- the free slot now claims a live typed row;
##   * allocator heap garbage persisted -- two identical worlds produce different bytes.
##
## THE INT32 SIGN TRAP IS EXERCISED, NOT ASSUMED. GDScript ints are 64-bit, so `0x80000000` is a
## POSITIVE 2147483648 and `-2147483648` is the same four bytes read as int32. A real bug has hidden
## inside the test written to catch it, so every boundary case here builds its value through
## `SaveCodec.u32_bits_to_int32()` / `int32_bits_to_u32()` and asserts the pair agrees, rather than
## typing a signed literal and hoping.
##
## GENERATION NAMESPACE: DIRECTORY. Four exist in this codebase (directory slot, inventory
## container, inventory lot, navigation route descriptor) and `gear.gd`/`reservations.gd` rows are
## bare indices. Every generation in this file is `entity_directory.gd`'s slot generation.

const SaveCodec := preload("res://scripts/core/save_codec.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const SaveSectionDirectory := preload("res://scripts/core/save_section_directory.gd")
const EntityDirectoryScript := preload("res://scripts/core/entity_directory.gd")

const CAPACITY: int = SaveSectionDirectory.PRIMARY_COUNT

var _record: SaveSectionDirectory.Record = null
var _encoded: SaveSectionDirectory.EncodeResult = null


func before_each() -> void:
	"""Build an empty-directory Record and an EncodeResult for each test."""
	_record = SaveSectionDirectory.Record.new()
	_encoded = SaveSectionDirectory.EncodeResult.new()


# --- fixtures ------------------------------------------------------------------------------------

func _set_live(record: SaveSectionDirectory.Record, slot: int, generation: int,
		persistent_id: int, kind: int, row: int) -> void:
	"""Mark one slot live with a full identity, as `_publish_row()` leaves it."""
	record.active[slot] = 1
	record.generation[slot] = generation
	record.persistent_id[slot] = persistent_id
	record.kind[slot] = kind
	record.typed_row[slot] = row


func _set_retired(record: SaveSectionDirectory.Record, slot: int) -> void:
	"""Mark one slot retired, as `destroy()` leaves a slot that spent its last generation."""
	record.retired[slot] = 1
	record.generation[slot] = EntityDirectoryScript.MAX_INT32


func _populate(record: SaveSectionDirectory.Record) -> void:
	"""The shared fixture: one live resident, one live job, a reused free slot and a retired slot."""
	_set_live(record, 0, 1, 1, EntityDirectoryScript.KIND_RESIDENT, 0)
	_set_live(record, 1, 3, 2, EntityDirectoryScript.KIND_JOB, 7)
	record.generation[2] = 5
	_set_retired(record, 3)


func _hex(bytes: PackedByteArray) -> String:
	"""Lowercase hex of a byte run, for pinned vectors."""
	var text: String = ""
	for value: int in bytes:
		text += "%02x" % value
	return text


func _encode(record: SaveSectionDirectory.Record) -> PackedByteArray:
	"""Encode a Record and assert it succeeded, returning the section bytes."""
	var out: SaveSectionDirectory.EncodeResult = SaveSectionDirectory.EncodeResult.new()
	assert_true(SaveSectionDirectory.encode_record(record, out),
		"encode_record succeeds: %s %s" % [out.refusal, out.detail])
	return out.bytes


func _decode_refusal(bytes: PackedByteArray,
		out: SaveSectionDirectory.Record) -> SaveHeader.Refusal:
	"""Decode at offset 0 and return the refusal, without asserting either way."""
	return SaveSectionDirectory.decode_into(bytes, 0, out)


func _patch_i32(bytes: PackedByteArray, offset: int, value: int) -> PackedByteArray:
	"""Return a copy of `bytes` with a little-endian i32 written at `offset`."""
	var patched: PackedByteArray = bytes.duplicate()
	patched.encode_s32(offset, value)
	return patched


# --- layout and identity ---------------------------------------------------------------------------

func test_section_identity_matches_arch_save_002() -> void:
	"""Section 3, one entity_directory block, owner schema 1, row_count = full capacity."""
	assert_equal(SaveSectionDirectory.SECTION_ID, 3,
		"ARCH-SAVE-002 numbers ENTITY_DIRECTORY as section 3")
	assert_equal(SaveSectionDirectory.STORE_COUNT, 1,
		"SAVE-LAYOUT-R01: exactly one entity_directory block")
	assert_equal(SaveSectionDirectory.OWNER_KEY, "entity_directory", "the ruling's own block name")
	assert_equal(SaveSectionDirectory.OWNER_SCHEMA_VERSION, 1, "initial section 3 framing")
	assert_equal(SaveSectionDirectory.PRIMARY_COUNT, 352418,
		"primary_count is the compiled directory capacity")
	assert_equal(SaveSectionDirectory.descriptor_row_count(), 352418,
		"descriptor row_count is the capacity, never the count of living residents")


func test_capacity_is_read_from_the_directory_not_restated() -> void:
	"""The codec's capacity constants come from entity_directory.gd so they cannot drift."""
	assert_equal(SaveSectionDirectory.PRIMARY_COUNT,
		EntityDirectoryScript.DIRECTORY_CAPACITY, "capacity is the directory's own")
	assert_equal(SaveSectionDirectory.KIND_COUNT, EntityDirectoryScript.KIND_COUNT,
		"kind count is the directory's own")
	assert_equal(SaveSectionDirectory.MAX_INT32, 2147483647, "the last generation a slot spends")


func test_column_order_is_save_layout_r01s() -> void:
	"""_active, _generation, _retired, _persistent_id, _kind, _typed_row, in that order."""
	assert_equal(SaveSectionDirectory.FIELD_COUNT, 6, "six columns, no heaps and no counters")
	var expected: Array[StringName] = [&"_active", &"_generation", &"_retired",
		&"_persistent_id", &"_kind", &"_typed_row"]
	for field: int in SaveSectionDirectory.FIELD_COUNT:
		assert_equal(SaveSectionDirectory.FIELD_KEYS[field], expected[field],
			"field %d is %s" % [field, expected[field]])
	var widths: Array[int] = [1, 4, 1, 4, 4, 4]
	for field: int in SaveSectionDirectory.FIELD_COUNT:
		assert_equal(SaveSectionDirectory.FIELD_WIDTHS[field], widths[field],
			"field %d is %d bytes wide" % [field, widths[field]])


func test_section_carries_no_allocator_heap() -> void:
	"""The fixed length is exactly the six columns; a persisted heap would change it.

	`_free_heap` and `_heap_index` hold stale garbage beyond their live prefix, so writing either
	would make two worlds that are identical in every observable way produce different bytes. The
	arithmetic below is the guard: 44 framing + 6 element counts + 18 bytes per slot.
	"""
	assert_equal(SaveSectionDirectory.TOTAL_FIELD_WIDTH,
		SaveSectionDirectory.total_field_width(), "1+4+1+4+4+4 recomputed from FIELD_WIDTHS")
	assert_equal(SaveSectionDirectory.FRAMING_BYTES, 44, "4 + (4+16) + 4 + 8 + 8")
	assert_equal(SaveSectionDirectory.PAYLOAD_BYTES, 6 * 8 + 18 * CAPACITY,
		"six element counts plus 18 bytes per slot")
	assert_equal(SaveSectionDirectory.SECTION_BYTES, 6343616, "44 + 48 + 18*352418")
	assert_equal(_encode(_record).size(), 6343616, "an encoded section is exactly that long")


func test_field_offsets_are_the_pinned_byte_map() -> void:
	"""Every offset in the module header's table, recomputed rather than copied."""
	var counts: Array[int] = [44, 352470, 1762150, 2114576, 3524256, 4933936]
	var values: Array[int] = [52, 352478, 1762158, 2114584, 3524264, 4933944]
	for field: int in SaveSectionDirectory.FIELD_COUNT:
		assert_equal(SaveSectionDirectory.field_count_offset(field), counts[field],
			"field %d element_count offset" % field)
		assert_equal(SaveSectionDirectory.field_value_offset(field), values[field],
			"field %d first value offset" % field)
	assert_equal(SaveSectionDirectory.field_count_offset(5) + 8 + 4 * CAPACITY,
		SaveSectionDirectory.SECTION_BYTES, "the last column ends exactly at the section end")


func test_byte_order_probe_accepts_this_build() -> void:
	"""The bulk conversions inherit host byte order, so the probe must pass before any encode."""
	var refusal: SaveHeader.Refusal = SaveSectionDirectory.byte_order_refusal()
	assert_true(refusal.is_ok(), "little-endian probe: %s" % refusal.detail)
	var probe: PackedByteArray = PackedInt32Array([SaveHeader.ENDIAN_SENTINEL]).to_byte_array()
	assert_equal(_hex(probe), "04030201", "0x01020304 stored little-endian")


func test_canonical_type_codes_are_save_r09s() -> void:
	"""SAVE-R09 type 0 is u8 and type 2 is i32; section 3 uses only those two."""
	assert_equal(SaveSectionDirectory.canonical_type_of(SaveSectionDirectory.FIELD_ACTIVE), 0,
		"_active is a u8 column")
	assert_equal(SaveSectionDirectory.canonical_type_of(SaveSectionDirectory.FIELD_RETIRED), 0,
		"_retired is a u8 column")
	assert_equal(SaveSectionDirectory.canonical_type_of(SaveSectionDirectory.FIELD_GENERATION), 2,
		"_generation is an i32 column")
	assert_equal(SaveSectionDirectory.canonical_type_of(SaveSectionDirectory.FIELD_TYPED_ROW), 2,
		"_typed_row is an i32 column")


# --- pinned byte vectors -----------------------------------------------------------------------------

func test_framing_bytes_are_pinned() -> void:
	"""The 44-byte block header, byte for byte."""
	var bytes: PackedByteArray = _encode(_record)
	assert_equal(_hex(bytes.slice(0, 44)),
		"0100000010000000656e746974795f6469726563746f727901000000"
			+ "a26005000000000094cb600000000000",
		"store_count 1, 16-byte owner key, schema 1, 352418 slots, 6343572 payload bytes")


func test_populated_column_bytes_are_pinned() -> void:
	"""The first four slots of every column, for the shared fixture."""
	_populate(_record)
	var bytes: PackedByteArray = _encode(_record)
	var offsets: Array[int] = [52, 352478, 1762158, 2114584, 3524264, 4933944]
	var runs: Array[int] = [4, 16, 4, 16, 16, 16]
	var expected: Array[String] = [
		"01010000",
		"010000000300000005000000ffffff7f",
		"00000001",
		"01000000020000000000000000000000",
		"0e0000000b000000ffffffffffffffff",
		"0000000007000000ffffffffffffffff",
	]
	for field: int in SaveSectionDirectory.FIELD_COUNT:
		assert_equal(_hex(bytes.slice(offsets[field], offsets[field] + runs[field])),
			expected[field], "column %s slots 0-3" % SaveSectionDirectory.FIELD_KEYS[field])


func test_unequal_width_columns_pin_column_major_bytes() -> void:
	"""SAVE-LAYOUT-R01 asks for unequal-width, non-symmetric pinned bytes. This is section 3's.

	`_active` is one byte per slot and `_generation` is four, and the two columns are written one
	after the other rather than interleaved per slot. Generation 258 is 0x0102 so its low byte and
	its high byte differ, which a symmetric value would hide.
	"""
	_set_live(_record, 0, 1, 1, EntityDirectoryScript.KIND_WORLD, 0)
	_set_live(_record, 1, 258, 2, EntityDirectoryScript.KIND_FEAST, 0)
	var bytes: PackedByteArray = _encode(_record)
	assert_equal(_hex(bytes.slice(52, 54)), "0101", "two live occupancy bytes, column-major")
	assert_equal(_hex(bytes.slice(352478, 352486)), "0100000002010000",
		"generations 1 and 258, little-endian, immediately after the whole occupancy column")


func test_round_trip_re_encodes_byte_identically() -> void:
	"""Encode, decode, re-encode: the two byte strings must be identical, not merely equivalent."""
	_populate(_record)
	var bytes: PackedByteArray = _encode(_record)
	var decoded: SaveSectionDirectory.Record = SaveSectionDirectory.Record.new()
	var refusal: SaveHeader.Refusal = _decode_refusal(bytes, decoded)
	assert_true(refusal.is_ok(), "decode succeeds: %s %s" % [refusal.code, refusal.detail])
	assert_true(decoded.equals(_record), "every column survives the round trip")
	assert_equal(_encode(decoded), bytes, "re-encoding the decoded record is byte-identical")


# --- streaming -------------------------------------------------------------------------------------

func test_chunk_cursor_streams_within_the_arch_save_003_bound() -> void:
	"""Every chunk is at most 65536 bytes and the stream sums to the section length."""
	assert_equal(SaveSectionDirectory.CHUNK_BYTES, 65536, "ARCH-SAVE-003's chunk size")
	_populate(_record)
	var cursor: SaveSectionDirectory.ChunkCursor = SaveSectionDirectory.ChunkCursor.new(_record)
	var chunk: SaveSectionDirectory.Chunk = SaveSectionDirectory.Chunk.new()
	var total: int = 0
	var largest: int = 0
	while cursor.has_more():
		assert_true(cursor.next_chunk_into(chunk), "chunk: %s" % chunk.detail)
		total += chunk.bytes.size()
		largest = maxi(largest, chunk.bytes.size())
	assert_equal(total, SaveSectionDirectory.SECTION_BYTES, "the stream is the whole section")
	assert_equal(cursor.emitted_bytes(), total, "the cursor counts what it emitted")
	assert_true(largest <= SaveSectionDirectory.CHUNK_BYTES, "no chunk exceeds 65536 bytes")


func test_chunk_stream_concatenates_to_the_materialised_section() -> void:
	"""Streaming and `encode_record()` produce the same bytes in the same order."""
	_populate(_record)
	var expected: PackedByteArray = _encode(_record)
	var cursor: SaveSectionDirectory.ChunkCursor = SaveSectionDirectory.ChunkCursor.new(_record)
	var chunk: SaveSectionDirectory.Chunk = SaveSectionDirectory.Chunk.new()
	var streamed: PackedByteArray = PackedByteArray()
	while cursor.has_more():
		assert_true(cursor.next_chunk_into(chunk), "chunk: %s" % chunk.detail)
		streamed.append_array(chunk.bytes)
	assert_equal(streamed, expected, "the streamed bytes are the materialised bytes")
	assert_false(cursor.next_chunk_into(chunk), "a drained cursor refuses rather than repeating")
	assert_equal(chunk.refusal, SaveSectionDirectory.REFUSE_CURSOR_EXHAUSTED,
		"and says so with a code")


func test_incremental_crc_over_chunks_equals_the_whole() -> void:
	"""ARCH-SAVE-003 folds CRC incrementally; chained `crc32_update` must equal `crc32_of`.

	Deliberately run over a short, bounded vector rather than the 6343616-byte section:
	`crc32_update()` is a per-byte GDScript loop, and the property being proved -- that folding a
	split stream equals folding it whole -- does not depend on the length.
	"""
	var whole: PackedByteArray = "123456789".to_ascii_buffer()
	assert_equal(SaveHeader.crc32_of(whole), SaveHeader.CRC32_CHECK_VALUE,
		"the pinned CRC check vector still holds")
	var register: int = SaveHeader.CRC32_INITIAL_REGISTER
	register = SaveHeader.crc32_update(register, whole.slice(0, 4))
	register = SaveHeader.crc32_update(register, whole.slice(4, 9))
	assert_equal(register ^ SaveHeader.CRC32_FINAL_XOR, SaveHeader.CRC32_CHECK_VALUE,
		"folding two chunks gives the same CRC as folding the whole")


func test_column_cursor_emits_only_one_columns_values() -> void:
	"""Section 15's handle: the values half of one canonical field record, and nothing else."""
	_populate(_record)
	var bytes: PackedByteArray = _encode(_record)
	var cursor: SaveSectionDirectory.ColumnCursor = SaveSectionDirectory.ColumnCursor.new(
		_record, SaveSectionDirectory.FIELD_GENERATION)
	assert_equal(cursor.field(), SaveSectionDirectory.FIELD_GENERATION, "it knows its field")
	var chunk: SaveSectionDirectory.Chunk = SaveSectionDirectory.Chunk.new()
	var values: PackedByteArray = PackedByteArray()
	while cursor.has_more():
		assert_true(cursor.next_chunk_into(chunk), "chunk: %s" % chunk.detail)
		values.append_array(chunk.bytes)
	var start: int = SaveSectionDirectory.field_value_offset(
		SaveSectionDirectory.FIELD_GENERATION)
	assert_equal(values, bytes.slice(start, start + 4 * CAPACITY),
		"the column cursor emits exactly the section's generation value region")


# --- the four silent failures ------------------------------------------------------------------------

func test_a_generation_off_by_one_changes_the_bytes() -> void:
	"""A stale `(slot, generation)` pair must not become valid again across a save.

	The whole point of the generation column: if slot 1 came back at generation 2 instead of 3, a
	reference taken before the save would validate against the row that replaced it.
	"""
	_populate(_record)
	var bytes: PackedByteArray = _encode(_record)
	var offset: int = SaveSectionDirectory.field_value_offset(
		SaveSectionDirectory.FIELD_GENERATION) + 4
	assert_equal(bytes.decode_s32(offset), 3, "slot 1 was saved at generation 3")
	var decoded: SaveSectionDirectory.Record = SaveSectionDirectory.Record.new()
	assert_true(_decode_refusal(_patch_i32(bytes, offset, 2), decoded).is_ok(),
		"generation 2 is a perfectly legal section, which is exactly the danger")
	assert_equal(decoded.generation[1], 2, "so the only defence is that the bytes differ")
	assert_false(_encode(decoded) == bytes, "a one-step generation change changes the section")


func test_a_retired_slot_cannot_load_as_reusable() -> void:
	"""Retirement is cross-checked against the spent generation in BOTH directions."""
	_populate(_record)
	assert_true(SaveSectionDirectory.record_refusal(_record).is_ok(), "the fixture is valid")
	_record.retired[3] = 0
	var loosened: SaveHeader.Refusal = SaveSectionDirectory.record_refusal(_record)
	assert_equal(loosened.code, SaveSectionDirectory.REFUSE_RETIREMENT_DISAGREES,
		"a spent generation with the retirement byte cleared is refused")
	_record.retired[3] = 1
	_record.generation[3] = 10
	var early: SaveHeader.Refusal = SaveSectionDirectory.record_refusal(_record)
	assert_equal(early.code, SaveSectionDirectory.REFUSE_RETIREMENT_DISAGREES,
		"and a retired slot that has not spent its last generation is refused too")


func test_a_retirement_swap_that_keeps_the_counts_balanced_is_still_refused() -> void:
	"""Two wrongs that cancel in the count: the per-slot check is what catches them.

	Slot 4 is retired but sits at generation 10, while slot 5 holds the spent generation and is NOT
	retired. The whole-column closure sees one spent inactive slot and one retirement and is
	satisfied; only the per-retired-slot generation check sees that they are different slots. A
	loader that trusted the count alone would hand slot 4 back to the allocator at generation 11
	and never reuse slot 5 at all.
	"""
	_set_retired(_record, 4)
	_record.generation[4] = 10
	_record.generation[5] = EntityDirectoryScript.MAX_INT32
	var refusal: SaveHeader.Refusal = SaveSectionDirectory.record_refusal(_record)
	assert_equal(refusal.code, SaveSectionDirectory.REFUSE_RETIREMENT_DISAGREES,
		"the swapped pair is refused")
	assert_true(refusal.detail.contains("retired slot 4"),
		"and the detail names the retired slot, not the count")
	_record.generation[4] = EntityDirectoryScript.MAX_INT32
	_record.retired[5] = 1
	assert_true(SaveSectionDirectory.record_refusal(_record).is_ok(),
		"two properly retired slots are accepted")


func test_a_live_slot_may_hold_the_last_generation_without_being_retired() -> void:
	"""A slot retires on the NEXT destroy, not on reaching 2147483647; both must round-trip."""
	_set_live(_record, 0, EntityDirectoryScript.MAX_INT32, 1,
		EntityDirectoryScript.KIND_ROOM, 0)
	_set_retired(_record, 1)
	assert_true(SaveSectionDirectory.record_refusal(_record).is_ok(),
		"live-at-the-last-generation and retired coexist")
	var decoded: SaveSectionDirectory.Record = SaveSectionDirectory.Record.new()
	assert_true(_decode_refusal(_encode(_record), decoded).is_ok(), "and survive a round trip")
	assert_equal(decoded.generation[0], 2147483647, "the live slot keeps its spent generation")
	assert_equal(decoded.retired[0], 0, "and is still not retired")
	assert_equal(decoded.retired[1], 1, "while the retired slot is")


func test_a_free_slots_null_typed_row_stays_minus_one() -> void:
	"""SAVE-LAYOUT-R01: inactive fields hold their DECLARED unused value, and -1 is not 0."""
	_populate(_record)
	var bytes: PackedByteArray = _encode(_record)
	var offset: int = SaveSectionDirectory.field_value_offset(
		SaveSectionDirectory.FIELD_TYPED_ROW) + 4 * 2
	assert_equal(bytes.decode_s32(offset), -1, "free slot 2 is written as -1, not 0")
	assert_equal(_hex(bytes.slice(offset, offset + 4)), "ffffffff", "all four bytes set")
	var decoded: SaveSectionDirectory.Record = SaveSectionDirectory.Record.new()
	assert_true(_decode_refusal(bytes, decoded).is_ok(), "it decodes")
	assert_equal(decoded.typed_row[2], -1, "and comes back as -1")
	assert_equal(decoded.kind[2], -1, "as does the free slot's kind")


func test_a_never_used_slot_holds_its_declared_canonical_values() -> void:
	"""SAVE-LAYOUT-R01 corrected the old zero-fill sentence: use zero only where the owner says so.

	A slot no `create()` has ever touched is occupancy 0, generation 0, retirement 0, persistent id
	0, kind -1 and typed row -1. Pinned on the wire for a slot in the middle of the section, because
	changing any one of these silently changes every save ever written and every canonical digest.
	"""
	_populate(_record)
	var bytes: PackedByteArray = _encode(_record)
	var slot: int = 100000
	assert_equal(bytes[SaveSectionDirectory.field_value_offset(0) + slot], 0, "not occupied")
	assert_equal(bytes.decode_s32(
		SaveSectionDirectory.field_value_offset(1) + 4 * slot), 0, "generation 0, never 1")
	assert_equal(bytes[SaveSectionDirectory.field_value_offset(2) + slot], 0, "not retired")
	assert_equal(bytes.decode_s32(
		SaveSectionDirectory.field_value_offset(3) + 4 * slot), 0, "no persistent id")
	assert_equal(bytes.decode_s32(
		SaveSectionDirectory.field_value_offset(4) + 4 * slot), -1, "kind -1, never 0")
	assert_equal(bytes.decode_s32(
		SaveSectionDirectory.field_value_offset(5) + 4 * slot), -1, "typed row -1, never 0")


func test_a_free_slot_loaded_as_row_zero_is_refused() -> void:
	"""If -1 were normalised to 0 the free slot would claim a live typed row. Refuse it."""
	_populate(_record)
	var bytes: PackedByteArray = _encode(_record)
	var offset: int = SaveSectionDirectory.field_value_offset(
		SaveSectionDirectory.FIELD_TYPED_ROW) + 4 * 2
	var decoded: SaveSectionDirectory.Record = SaveSectionDirectory.Record.new()
	var refusal: SaveHeader.Refusal = _decode_refusal(_patch_i32(bytes, offset, 0), decoded)
	assert_equal(refusal.code, SaveSectionDirectory.REFUSE_FREE_SLOT_IDENTITY,
		"a free slot holding row 0 is refused")
	assert_true(decoded.equals(SaveSectionDirectory.Record.new()),
		"and the caller's record is untouched")


# --- validate then commit ------------------------------------------------------------------------------

func test_a_full_length_invalid_section_leaves_the_record_untouched() -> void:
	"""Commit-then-validate is the bug: the section is the right LENGTH and the wrong CONTENT."""
	_populate(_record)
	var valid: PackedByteArray = _encode(_record)
	var prior: SaveSectionDirectory.Record = SaveSectionDirectory.Record.new()
	_populate(prior)
	var offset: int = SaveSectionDirectory.field_value_offset(
		SaveSectionDirectory.FIELD_KIND)
	var corrupt: PackedByteArray = _patch_i32(valid, offset, EntityDirectoryScript.KIND_COUNT)
	assert_equal(corrupt.size(), SaveSectionDirectory.SECTION_BYTES, "still full length")
	var refusal: SaveHeader.Refusal = _decode_refusal(corrupt, prior)
	assert_equal(refusal.code, SaveSectionDirectory.REFUSE_LIVE_SLOT_KIND,
		"an out-of-domain kind on a live slot is refused")
	var untouched: SaveSectionDirectory.Record = SaveSectionDirectory.Record.new()
	_populate(untouched)
	assert_true(prior.equals(untouched), "every column of the caller's record is byte-identical")


func test_a_full_length_section_with_a_duplicate_typed_row_is_refused() -> void:
	"""Two live slots owning one typed row would give ARCH-ID-003's validator two owners."""
	_set_live(_record, 0, 1, 1, EntityDirectoryScript.KIND_ROOM, 4)
	_set_live(_record, 5, 1, 2, EntityDirectoryScript.KIND_ROOM, 4)
	var refusal: SaveHeader.Refusal = SaveSectionDirectory.record_refusal(_record)
	assert_equal(refusal.code, SaveSectionDirectory.REFUSE_DUPLICATE_TYPED_ROW,
		"the second claim on room row 4 is refused")
	assert_false(SaveSectionDirectory.encode_record(_record, _encoded),
		"and the section cannot be encoded at all")
	assert_equal(_encoded.bytes.size(), 0, "a refused encode produces no bytes")
	assert_equal(_encoded.refusal, SaveSectionDirectory.REFUSE_DUPLICATE_TYPED_ROW,
		"carrying the same code the validator gave")


func test_a_duplicate_persistent_id_is_refused() -> void:
	"""ARCH-SAVE-004 validates unique persistent IDs; two live slots cannot share one."""
	_set_live(_record, 0, 1, 9, EntityDirectoryScript.KIND_JOB, 0)
	_set_live(_record, 1, 1, 9, EntityDirectoryScript.KIND_JOB, 1)
	var refusal: SaveHeader.Refusal = SaveSectionDirectory.record_refusal(_record)
	assert_equal(refusal.code, SaveSectionDirectory.REFUSE_DUPLICATE_PERSISTENT_ID,
		"persistent id 9 held twice is refused")
	_record.persistent_id[1] = 10
	assert_true(SaveSectionDirectory.record_refusal(_record).is_ok(),
		"distinct ids are accepted")


func test_truncation_at_every_stage_is_refused_without_writing() -> void:
	"""One byte short of the section, and one byte short of the framing, both refuse."""
	_populate(_record)
	var bytes: PackedByteArray = _encode(_record)
	var out: SaveSectionDirectory.Record = SaveSectionDirectory.Record.new()
	var short: SaveHeader.Refusal = _decode_refusal(
		bytes.slice(0, SaveSectionDirectory.SECTION_BYTES - 1), out)
	assert_equal(short.code, SaveSectionDirectory.REFUSE_TRUNCATED, "one byte short is refused")
	var tiny: SaveHeader.Refusal = _decode_refusal(bytes.slice(0, 10), out)
	assert_equal(tiny.code, SaveSectionDirectory.REFUSE_TRUNCATED, "ten bytes is refused")
	assert_true(out.equals(SaveSectionDirectory.Record.new()), "and nothing was written")
	var negative: SaveHeader.Refusal = SaveSectionDirectory.decode_into(bytes, -1, out)
	assert_equal(negative.code, SaveSectionDirectory.REFUSE_NEGATIVE_OFFSET,
		"a negative offset is refused before the addition")


func test_extent_refusal_is_public_and_overflow_safe() -> void:
	"""The primary gate, testable on its own, with no offset addition that can overflow."""
	var bytes: PackedByteArray = _encode(_record)
	assert_true(SaveSectionDirectory.extent_refusal(bytes, 0).is_ok(), "an exact buffer fits")
	assert_equal(SaveSectionDirectory.extent_refusal(bytes, 1).code,
		SaveSectionDirectory.REFUSE_TRUNCATED, "one byte past the start does not")
	assert_equal(SaveSectionDirectory.extent_refusal(PackedByteArray(), 0).code,
		SaveSectionDirectory.REFUSE_TRUNCATED, "an empty buffer does not")
	assert_equal(SaveSectionDirectory.extent_refusal(bytes, SaveCodec.INT64_MAX).code,
		SaveSectionDirectory.REFUSE_TRUNCATED, "nor does an offset at the int64 ceiling")


func test_decoding_at_a_nonzero_offset_reads_the_same_section() -> void:
	"""Sections are gapless but this decoder is told where it starts, never assuming a neighbour."""
	_populate(_record)
	var bytes: PackedByteArray = _encode(_record)
	var padded: PackedByteArray = PackedByteArray()
	padded.resize(1216)
	padded.append_array(bytes)
	var decoded: SaveSectionDirectory.Record = SaveSectionDirectory.Record.new()
	var refusal: SaveHeader.Refusal = SaveSectionDirectory.decode_into(padded, 1216, decoded)
	assert_true(refusal.is_ok(), "decode at 1216: %s %s" % [refusal.code, refusal.detail])
	assert_true(decoded.equals(_record), "the same six columns come back")


# --- framing refusals ---------------------------------------------------------------------------------

func test_framing_fields_are_each_validated() -> void:
	"""Store count, owner key, owner schema, primary count and payload length each refuse."""
	var bytes: PackedByteArray = _encode(_record)
	var out: SaveSectionDirectory.Record = SaveSectionDirectory.Record.new()
	assert_equal(_decode_refusal(_patch_i32(bytes, 0, 2), out).code,
		SaveSectionDirectory.REFUSE_STORE_COUNT, "two stores is refused")
	var renamed: PackedByteArray = bytes.duplicate()
	renamed[8] = 0x45
	assert_equal(_decode_refusal(renamed, out).code, SaveSectionDirectory.REFUSE_OWNER_KEY,
		"a different owner key is refused")
	assert_equal(_decode_refusal(_patch_i32(bytes, 24, 2), out).code,
		SaveSectionDirectory.REFUSE_OWNER_SCHEMA_VERSION, "owner schema 2 is refused")
	assert_equal(_decode_refusal(_patch_i32(bytes, 28, CAPACITY - 1), out).code,
		SaveSectionDirectory.REFUSE_PRIMARY_COUNT, "a short primary count is refused")
	assert_equal(_decode_refusal(_patch_i32(bytes, 36, 10), out).code,
		SaveSectionDirectory.REFUSE_PAYLOAD_LENGTH, "a wrong payload length is refused")
	assert_true(out.equals(SaveSectionDirectory.Record.new()), "and none of them wrote a column")


func test_a_wrong_element_count_is_refused() -> void:
	"""Each column declares its own count and every one of them must be the full capacity."""
	var bytes: PackedByteArray = _encode(_record)
	var out: SaveSectionDirectory.Record = SaveSectionDirectory.Record.new()
	for field: int in SaveSectionDirectory.FIELD_COUNT:
		var offset: int = SaveSectionDirectory.field_count_offset(field)
		var refusal: SaveHeader.Refusal = _decode_refusal(_patch_i32(bytes, offset, 1), out)
		assert_equal(refusal.code, SaveSectionDirectory.REFUSE_ELEMENT_COUNT,
			"field %d declaring 1 element is refused" % field)


func test_section_length_refusal_checks_a_descriptor() -> void:
	"""A descriptor declaring anything but the fixed length is wrong before a byte is read."""
	assert_true(SaveSectionDirectory.section_length_refusal(6343616).is_ok(), "the fixed length")
	assert_equal(SaveSectionDirectory.section_length_refusal(0).code,
		SaveSectionDirectory.REFUSE_LENGTH, "a zero-byte section 3 is refused")
	assert_equal(SaveSectionDirectory.section_length_refusal(6343617).code,
		SaveSectionDirectory.REFUSE_LENGTH, "one byte too many is refused")


# --- the int32 sign trap ---------------------------------------------------------------------------------

func test_the_high_bit_pattern_is_read_signed_and_refused() -> void:
	"""`00 00 00 80` is 2147483648 as u32 and -2147483648 as i32. Section 3 reads i32."""
	var bits: int = SaveCodec.UINT32_SIGN_BIT
	assert_equal(bits, 2147483648, "0x80000000 is a POSITIVE GDScript int")
	var signed: int = SaveCodec.u32_bits_to_int32(bits)
	assert_equal(signed, -2147483648, "the same four bytes read as int32")
	assert_equal(SaveCodec.int32_bits_to_u32(signed), bits, "and the conversion round-trips")
	var bytes: PackedByteArray = _encode(_record)
	var offset: int = SaveSectionDirectory.field_value_offset(
		SaveSectionDirectory.FIELD_GENERATION)
	var out: SaveSectionDirectory.Record = SaveSectionDirectory.Record.new()
	var refusal: SaveHeader.Refusal = _decode_refusal(_patch_i32(bytes, offset, signed), out)
	assert_equal(refusal.code, SaveSectionDirectory.REFUSE_GENERATION_RANGE,
		"a negative generation is refused, not accepted as a plausible 2147483648")


func test_the_last_generation_survives_as_itself() -> void:
	"""2147483647 is one below the sign bit and must not be confused with it."""
	var last: int = SaveCodec.u32_bits_to_int32(SaveCodec.UINT32_SIGN_BIT - 1)
	assert_equal(last, EntityDirectoryScript.MAX_INT32, "0x7fffffff is the last generation")
	_set_retired(_record, 0)
	var bytes: PackedByteArray = _encode(_record)
	var offset: int = SaveSectionDirectory.field_value_offset(
		SaveSectionDirectory.FIELD_GENERATION)
	assert_equal(_hex(bytes.slice(offset, offset + 4)), "ffffff7f", "little-endian 0x7fffffff")
	var decoded: SaveSectionDirectory.Record = SaveSectionDirectory.Record.new()
	assert_true(_decode_refusal(bytes, decoded).is_ok(), "it decodes")
	assert_equal(decoded.generation[0], last, "and comes back as 2147483647")


# --- column domains ----------------------------------------------------------------------------------------

func test_occupancy_and_retirement_bytes_are_zero_or_one() -> void:
	"""ARCH-SAVE-002's occupied bitset is one byte per slot, and only 0 and 1 are legal."""
	_record.active[0] = 2
	assert_equal(SaveSectionDirectory.record_refusal(_record).code,
		SaveSectionDirectory.REFUSE_OCCUPANCY_BYTE, "occupancy byte 2 is refused")
	_record.active[0] = 0
	_record.retired[0] = 255
	assert_equal(SaveSectionDirectory.record_refusal(_record).code,
		SaveSectionDirectory.REFUSE_RETIRED_BYTE, "retirement byte 255 is refused")


func test_live_slot_identity_fields_are_each_validated() -> void:
	"""Generation, persistent ID, kind and typed row each have their own refusal on a live slot."""
	_set_live(_record, 0, 0, 1, EntityDirectoryScript.KIND_HIVE, 0)
	assert_equal(SaveSectionDirectory.record_refusal(_record).code,
		SaveSectionDirectory.REFUSE_LIVE_SLOT_GENERATION, "a live slot at generation 0")
	_record.generation[0] = 1
	_record.persistent_id[0] = 0
	assert_equal(SaveSectionDirectory.record_refusal(_record).code,
		SaveSectionDirectory.REFUSE_LIVE_SLOT_PERSISTENT_ID, "a live slot with no persistent id")
	_record.persistent_id[0] = 1
	_record.kind[0] = EntityDirectoryScript.KIND_COUNT
	assert_equal(SaveSectionDirectory.record_refusal(_record).code,
		SaveSectionDirectory.REFUSE_LIVE_SLOT_KIND, "kind 18 does not exist")
	_record.kind[0] = EntityDirectoryScript.KIND_HIVE
	_record.typed_row[0] = EntityDirectoryScript.KIND_CAPACITY[EntityDirectoryScript.KIND_HIVE]
	assert_equal(SaveSectionDirectory.record_refusal(_record).code,
		SaveSectionDirectory.REFUSE_LIVE_SLOT_ROW, "a row past the kind's capacity")


func test_a_free_slot_carrying_a_stale_identity_is_refused() -> void:
	"""`destroy()` zeroes the identity, so a free slot with one is a corrupted section."""
	_record.persistent_id[7] = 4
	assert_equal(SaveSectionDirectory.record_refusal(_record).code,
		SaveSectionDirectory.REFUSE_FREE_SLOT_IDENTITY, "a free slot with a persistent id")
	_record.persistent_id[7] = 0
	_record.kind[7] = EntityDirectoryScript.KIND_JOB
	assert_equal(SaveSectionDirectory.record_refusal(_record).code,
		SaveSectionDirectory.REFUSE_FREE_SLOT_IDENTITY, "a free slot with a kind")


func test_the_living_resident_cap_is_enforced() -> void:
	"""GDD §4.1 caps living residents at 256 even though the store holds 512 rows."""
	for row: int in EntityDirectoryScript.RESIDENT_LIVING_CAP:
		_set_live(_record, row, 1, row + 1, EntityDirectoryScript.KIND_RESIDENT, row)
	assert_true(SaveSectionDirectory.record_refusal(_record).is_ok(), "256 residents is legal")
	_set_live(_record, EntityDirectoryScript.RESIDENT_LIVING_CAP, 1,
		EntityDirectoryScript.RESIDENT_LIVING_CAP + 1, EntityDirectoryScript.KIND_RESIDENT,
		EntityDirectoryScript.RESIDENT_LIVING_CAP)
	assert_equal(SaveSectionDirectory.record_refusal(_record).code,
		SaveSectionDirectory.REFUSE_LIVING_CAP, "257 living residents is refused")


func test_a_short_column_is_refused_before_anything_indexes_it() -> void:
	"""A Record whose columns are not full capacity cannot be encoded."""
	_record.typed_row = PackedInt32Array()
	var refusal: SaveHeader.Refusal = SaveSectionDirectory.record_refusal(_record)
	assert_equal(refusal.code, SaveSectionDirectory.REFUSE_RECORD_SHAPE,
		"an empty column is refused")
	assert_false(SaveSectionDirectory.encode_record(_record, _encoded), "and cannot be encoded")
	assert_equal(_encoded.refusal, SaveSectionDirectory.REFUSE_RECORD_SHAPE,
		"with the shape code, not a length code")


# --- the rebuilt, never-written half ------------------------------------------------------------------------

func test_rebuild_reproduces_the_reverse_owner_map() -> void:
	"""`_typed_owner_slot` is the exact inverse of `_typed_row`, arena-partitioned by kind."""
	_set_live(_record, 0, 1, 1, EntityDirectoryScript.KIND_RESIDENT, 3)
	_set_live(_record, 9, 1, 2, EntityDirectoryScript.KIND_WORLD, 0)
	var derived: SaveSectionDirectory.Derived = SaveSectionDirectory.Derived.new()
	var refusal: SaveHeader.Refusal = SaveSectionDirectory.rebuild_into(_record, derived)
	assert_true(refusal.is_ok(), "rebuild succeeds: %s %s" % [refusal.code, refusal.detail])
	var resident_base: int = 0
	for kind: int in EntityDirectoryScript.KIND_RESIDENT:
		resident_base += EntityDirectoryScript.KIND_CAPACITY[kind]
	assert_equal(derived.typed_owner_slot[resident_base + 3], 0, "resident row 3 is owned by slot 0")
	assert_equal(derived.typed_owner_slot[resident_base + 2], -1, "row 2 is free")
	assert_equal(derived.typed_owner_slot[CAPACITY - 1], 9, "the world row is the last arena entry")


func test_rebuild_reproduces_every_counter() -> void:
	"""live, inactive, retired, allocatable, and both per-kind counters, all from the columns."""
	_populate(_record)
	var derived: SaveSectionDirectory.Derived = SaveSectionDirectory.Derived.new()
	assert_true(SaveSectionDirectory.rebuild_into(_record, derived).is_ok(), "rebuild succeeds")
	assert_equal(derived.live_count, 2, "two live slots")
	assert_equal(derived.inactive_count, CAPACITY - 2, "everything else is inactive")
	assert_equal(derived.retired_count, 1, "one retired slot")
	assert_equal(derived.allocatable_slot_count, CAPACITY - 3,
		"a retired slot is inactive but never allocatable again")
	assert_equal(derived.kind_live_count[EntityDirectoryScript.KIND_RESIDENT], 1, "one resident")
	assert_equal(derived.kind_free_count[EntityDirectoryScript.KIND_RESIDENT],
		EntityDirectoryScript.KIND_CAPACITY[EntityDirectoryScript.KIND_RESIDENT] - 1,
		"and one fewer free resident row")


func test_the_free_set_alone_decides_the_next_allocation() -> void:
	"""Why the heaps are rebuilt and not written: `_pop_min` returns the window MINIMUM.

	Allocation order therefore depends on the SET of free entries, never on the permutation the
	array happens to hold, so a rebuilt ascending heap allocates exactly as the saved one would.
	This is task 09's "restored lowest-free allocation" property, checked on the live store.
	"""
	var store: EntityDirectoryScript = EntityDirectoryScript.new()
	var first: Vector2i = store.create(EntityDirectoryScript.KIND_JOB)
	var second: Vector2i = store.create(EntityDirectoryScript.KIND_JOB)
	var third: Vector2i = store.create(EntityDirectoryScript.KIND_JOB)
	assert_equal(first.x, 0, "the first job takes slot 0")
	assert_equal(second.x, 1, "the second takes slot 1")
	assert_equal(third.x, 2, "the third takes slot 2")
	assert_true(store.destroy(third), "release the highest slot first")
	assert_true(store.destroy(first), "then the lowest")
	var reused: Vector2i = store.create(EntityDirectoryScript.KIND_JOB)
	assert_equal(reused.x, 0, "the minimum free slot is reused whatever order they were freed in")
	assert_equal(reused.y, 2, "and its generation moved forward rather than repeating")


func test_agrees_with_a_live_directory_and_catches_a_single_wrong_value() -> void:
	"""Verification against a live store: every live slot and every counter."""
	var store: EntityDirectoryScript = EntityDirectoryScript.new()
	var resident: Vector2i = store.create(EntityDirectoryScript.KIND_RESIDENT)
	var job: Vector2i = store.create(EntityDirectoryScript.KIND_JOB)
	assert_true(store.destroy(job), "free the job slot so a generation moves on")
	var room: Vector2i = store.create(EntityDirectoryScript.KIND_ROOM)
	assert_equal(room.x, job.x, "the room reuses the job's slot")
	_set_live(_record, resident.x, resident.y, 1, EntityDirectoryScript.KIND_RESIDENT, 0)
	_set_live(_record, room.x, room.y, 3, EntityDirectoryScript.KIND_ROOM, 0)
	var agreed: SaveHeader.Refusal = SaveSectionDirectory.agrees_with_directory(_record, store)
	assert_true(agreed.is_ok(), "the record agrees with the store: %s" % agreed.detail)
	_record.persistent_id[room.x] = 4
	assert_equal(SaveSectionDirectory.agrees_with_directory(_record, store).code,
		SaveSectionDirectory.REFUSE_STORE_MISMATCH, "one wrong persistent id is caught")


func test_agreement_catches_a_generation_that_is_one_step_off() -> void:
	"""The silent failure again, this time between a decoded record and the world it loads into."""
	var store: EntityDirectoryScript = EntityDirectoryScript.new()
	var first: Vector2i = store.create(EntityDirectoryScript.KIND_FEAST)
	assert_true(store.destroy(first), "destroy it")
	var second: Vector2i = store.create(EntityDirectoryScript.KIND_FEAST)
	assert_equal(second.y, first.y + 1, "the reused slot is one generation on")
	_set_live(_record, second.x, second.y, 2, EntityDirectoryScript.KIND_FEAST, 0)
	assert_true(SaveSectionDirectory.agrees_with_directory(_record, store).is_ok(), "agreed")
	_record.generation[second.x] = first.y
	assert_equal(SaveSectionDirectory.agrees_with_directory(_record, store).code,
		SaveSectionDirectory.REFUSE_STORE_MISMATCH, "the stale generation is caught")


func test_agreement_catches_a_live_count_that_does_not_match() -> void:
	"""A record missing a live row still matches every slot it does carry; the counters do not."""
	var store: EntityDirectoryScript = EntityDirectoryScript.new()
	var kept: Vector2i = store.create(EntityDirectoryScript.KIND_HIVE)
	var extra: Vector2i = store.create(EntityDirectoryScript.KIND_HIVE)
	assert_true(store.is_valid(extra), "the store holds two hives")
	_set_live(_record, kept.x, kept.y, 1, EntityDirectoryScript.KIND_HIVE, 0)
	var refusal: SaveHeader.Refusal = SaveSectionDirectory.agrees_with_directory(_record, store)
	assert_equal(refusal.code, SaveSectionDirectory.REFUSE_STORE_MISMATCH,
		"a record one row short is refused")
	assert_true(refusal.detail.contains("live rows"), "and the detail names the counter")


# --- capture ------------------------------------------------------------------------------------------------

func test_capture_columns_validates_before_it_copies() -> void:
	"""The capture step takes columns and refuses an invalid set without touching the Record."""
	var source: SaveSectionDirectory.Record = SaveSectionDirectory.Record.new()
	_set_live(source, 4, 2, 7, EntityDirectoryScript.KIND_FURNITURE, 11)
	var out: SaveSectionDirectory.Record = SaveSectionDirectory.Record.new()
	var refusal: SaveHeader.Refusal = SaveSectionDirectory.capture_columns_into(source.active,
		source.generation, source.retired, source.persistent_id, source.kind, source.typed_row,
		out)
	assert_true(refusal.is_ok(), "a valid column set is captured: %s" % refusal.detail)
	assert_true(out.equals(source), "and lands verbatim")
	source.generation[4] = 0
	var bad: SaveSectionDirectory.Record = SaveSectionDirectory.Record.new()
	assert_equal(SaveSectionDirectory.capture_columns_into(source.active, source.generation,
		source.retired, source.persistent_id, source.kind, source.typed_row, bad).code,
		SaveSectionDirectory.REFUSE_LIVE_SLOT_GENERATION, "an invalid set is refused")
	assert_true(bad.equals(SaveSectionDirectory.Record.new()), "leaving the Record untouched")


func test_capture_from_a_live_store_reads_every_column() -> void:
	"""BLOCKER D1 is closed: `copy_columns_into()` reads the inactive generations too.

	This test asserted the opposite while the blocker was open, and it was right then: with no
	reader for the generation of an INACTIVE slot, its old assertion was
	`assert_equal(refusal.code, REFUSE_STORE_NO_COLUMN_READER, "capture from a live store
	refuses")`, because capturing five of six columns and leaving generations at zero would hand
	the next `create()` a pair a pre-save reference still holds. The directory owner has since
	added the bulk column API (decision 0105), so the contract to pin is the capture itself --
	including the free slot 1 whose generation no other reader can see.
	"""
	var store: EntityDirectoryScript = EntityDirectoryScript.new()
	var kept: Vector2i = store.create(EntityDirectoryScript.KIND_ROOM)
	var released: Vector2i = store.create(EntityDirectoryScript.KIND_ROOM)
	assert_true(store.destroy(released), "one slot is freed, carrying its generation with it")
	var out: SaveSectionDirectory.Record = SaveSectionDirectory.Record.new()
	var refusal: SaveHeader.Refusal = SaveSectionDirectory.capture_into(store, out)
	assert_true(refusal.is_ok(), "capture from a live store succeeds: %s" % refusal.detail)
	assert_equal(out.active[kept.x], 1, "the live slot is captured live")
	assert_equal(out.generation[kept.x], kept.y, "with its generation")
	assert_equal(out.active[released.x], 0, "the freed slot is captured free")
	assert_equal(out.generation[released.x], released.y,
		"and its generation survives, which is the value the registry demands verbatim")
	assert_equal(store.ref_of_slot(released.x), EntityDirectoryScript.NULL_REF,
		"while every other reader still sees nothing there")


func test_the_round_trip_returns_a_byte_identical_section_and_the_same_allocation_order() -> void:
	"""capture -> encode -> decode -> apply -> re-encode, against a second directory.

	The re-encode is the strongest single check available: it compares all 6343616 bytes of both
	worlds, so a column that failed to publish or a slot restored one generation off changes it.
	The allocation order is checked separately because no byte comparison of the six columns can
	see it -- the heaps are rebuilt, not written.
	"""
	var saved: EntityDirectoryScript = _live_store()
	var captured: SaveSectionDirectory.Record = SaveSectionDirectory.Record.new()
	assert_true(SaveSectionDirectory.capture_into(saved, captured).is_ok(), "captured")
	assert_equal(captured.active.count(1), 4, "the capture is not vacuous: four slots are live")
	assert_equal(captured.retired.count(1), 1, "and one is retired")
	var bytes: PackedByteArray = _encode(captured)
	var decoded: SaveSectionDirectory.Record = SaveSectionDirectory.Record.new()
	assert_true(_decode_refusal(bytes, decoded).is_ok(), "decoded")
	var loaded: EntityDirectoryScript = EntityDirectoryScript.new()
	var applied: SaveHeader.Refusal = SaveSectionDirectory.apply(decoded, loaded)
	assert_true(applied.is_ok(), "applied: %s %s" % [applied.code, applied.detail])
	assert_true(SaveSectionDirectory.agrees_with_directory(decoded, loaded).is_ok(),
		"the loaded store agrees with the record it was loaded from")
	var recaptured: SaveSectionDirectory.Record = SaveSectionDirectory.Record.new()
	assert_true(SaveSectionDirectory.capture_into(loaded, recaptured).is_ok(), "recaptured")
	assert_true(_encode(recaptured) == bytes, "the reloaded world re-encodes byte for byte")
	assert_equal(_next_slots(loaded, 4), _next_slots(saved, 4),
		"and allocates the same slots in the same order")


func test_apply_refuses_an_invalid_record_and_leaves_the_store_alone() -> void:
	"""Decision 0059 at the point it matters most: every EntityRef resolves through this store."""
	var store: EntityDirectoryScript = _live_store()
	var before: PackedByteArray = store.state_bytes()
	_set_live(_record, 4, 2, 7, EntityDirectoryScript.KIND_FURNITURE, 11)
	_record.generation[4] = 0
	var refusal: SaveHeader.Refusal = SaveSectionDirectory.apply(_record, store)
	assert_equal(refusal.code, SaveSectionDirectory.REFUSE_LIVE_SLOT_GENERATION,
		"a live slot at generation 0 is refused by this section, before the store is asked")
	assert_true(store.state_bytes() == before, "and the store is byte-identical")
	assert_equal(store.last_column_refusal(), EntityDirectoryScript.REFUSAL_NONE,
		"the directory was never asked to restore anything")


func _live_store() -> EntityDirectoryScript:
	"""A directory holding live, reused, free, retired and never-used slots."""
	var store: EntityDirectoryScript = EntityDirectoryScript.new()
	var refs: Array[Vector2i] = []
	for index: int in range(6):
		refs.append(store.create(EntityDirectoryScript.KIND_RESIDENT))
	assert_true(store.destroy(refs[2]), "slot 2 is released and reused below")
	assert_true(store.destroy(refs[4]), "slot 4 stays free at generation 1")
	assert_true(store.create(EntityDirectoryScript.KIND_JOB) == Vector2i(2, 2),
		"the job takes the lowest free slot")
	var generations: PackedInt32Array = store.get("_generation")
	generations[5] = EntityDirectoryScript.MAX_INT32
	store.set("_generation", generations)
	assert_true(store.destroy(Vector2i(5, EntityDirectoryScript.MAX_INT32)),
		"slot 5 spends its last generation and retires")
	return store


func _next_slots(store: EntityDirectoryScript, count: int) -> PackedInt32Array:
	"""The slots the next `count` creates hand out, which is the restored-lowest-free property."""
	var slots: PackedInt32Array = PackedInt32Array()
	for index: int in range(count):
		slots.append(store.create(EntityDirectoryScript.KIND_ROOM).x)
	return slots


# --- source discipline ------------------------------------------------------------------------------------------

func test_module_source_holds_no_float() -> void:
	"""ARCH-AUTH-002: authoritative state is integer, and this module is all authoritative state."""
	var source: String = FileAccess.get_file_as_string(
		"res://scripts/core/save_section_directory.gd")
	assert_true(source.length() > 0, "the module source was read")
	assert_false(source.contains(": float"), "no float-typed declaration")
	assert_false(source.contains("-> float"), "no float return")
	assert_false(source.contains("PackedFloat"), "no float column")


func test_module_names_the_closed_blocker_and_the_open_one() -> void:
	"""A blocker that is not written down is a blocker the next reader re-discovers the hard way.

	This asserted `source.contains("BLOCKER D1")` alongside D2 while both were open, and that was
	right then. D1 is closed by decision 0105 and the header now records how; D2 is untouched, so
	the assertion that this section writes no persistent-id allocator is unchanged.
	"""
	var source: String = FileAccess.get_file_as_string(
		"res://scripts/core/save_section_directory.gd")
	assert_true(source.contains("BLOCKER D1 -- CLOSED"), "the column reader/writer landed")
	assert_true(source.contains("BLOCKER D2"), "the unwritten _next_persistent_id")
	assert_false(source.contains("_free_heap["), "the heaps are never indexed here")
	assert_false(source.contains("_next_persistent_id ="), "and this section assigns no allocator")
