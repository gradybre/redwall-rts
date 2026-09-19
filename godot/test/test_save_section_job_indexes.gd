extends "res://test/framework/test_case.gd"
## Adversarial suite for ARCH-SAVE-002 section 8 JOB_INDEXES.
##
## Section 8 carries the planner's five ledgers, and a section 8 that loads subtly wrong does not
## crash -- it re-issues work. Round-trip equality is therefore the FLOOR, not the test. The cases
## that matter are the ones where a wrong load still looks entirely plausible:
##
##   * a column read at another table's extent -- the 128-row zone table walked as 8192 consumes
##     the hive table's bytes and every later column decodes as garbage that still parses;
##   * a PENDING row whose Job reference was dropped -- work nothing records, forever;
##   * a retired row that kept its Job -- a Job nothing will ever cancel;
##   * a sowing row naming a cycle its owner's cursor never allocated -- a reused field cycle,
##     which is precisely what the ruling says must never happen;
##   * a generation whose four bytes are `00 00 00 80` -- a plausible 2147483648 read unsigned and
##     an impossible -2147483648 read signed.
##
## THE PRIMARY COUNT IS NOW RULED, AND THE VECTORS ARE LITERAL. SAVE-C3-R01 designates 8192 -- the
## pending-service row table -- and requires writer and decoder to validate against the compiled
## constant rather than a caller-supplied positive number. So the wrapper is pinned as one literal
## hex string sliced at literal offsets (23, 31, 39), and the four values the ruling rejects (7,
## 4096, 5248, 14080) are injected STRAIGHT INTO THE WIRE, because the encoder no longer offers a
## way to produce one. Every one of those four is positive and u64-representable; the old
## positive-only gate would have passed all four.
##
## THE INT32 SIGN TRAP IS EXERCISED, NOT ASSUMED. A real bug has hidden inside the test written to
## catch it, so the boundary case here builds its value through `SaveCodec.u32_bits_to_int32()` and
## `int32_bits_to_u32()` and asserts the pair agrees, rather than typing a signed literal.
##
## GENERATION NAMESPACE: DIRECTORY, every one. Four exist in this codebase -- directory slot,
## inventory container, inventory lot, navigation route descriptor -- and `gear.gd`/`reservations.gd`
## rows are bare indices with no generation at all. Section 8's six generation columns are all the
## DIRECTORY one: farm plot, designation and hive owner references and the Job references beside
## them are `EntityRef`s resolved through `entity_directory.gd`, so every value this file writes
## into a generation column is a directory generation and is bounded by DIRECTORY_CAPACITY.
##
## FIELD ORDER IS CHECKED AGAINST THE ARTIFACT, NOT AGAINST THIS FILE. `test_declared_ordinals_...`
## reads `docs/planning/canonical_state_registry.json` and compares key, type code and declared
## capacity for all 35 ordinals. SAVE-J2-R01 appends dirty arrays and scalar counts after the
## original 29 fields. The wire order is the declared ordinal order, not source declaration order.
## The suite detects emission in another order,
## including the ASCII key order a dictionary walk would produce.

const SaveCodec := preload("res://scripts/core/save_codec.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const Section := preload("res://scripts/core/save_section_job_indexes.gd")
const JobPlannerScript := preload("res://scripts/core/job_planner.gd")
const EntityDirectoryScript := preload("res://scripts/core/entity_directory.gd")

const REGISTRY_PATH: String = "res://../docs/planning/canonical_state_registry.json"
const MODULE_PATH: String = "res://scripts/core/save_section_job_indexes.gd"

## SAVE-C3-R01's designated primary count, restated as a LITERAL rather than as
## `Section.PRIMARY_COUNT`. A test that asserted `PRIMARY_COUNT == PRIMARY_COUNT` would pass
## against any value the module chose; these four digits are the ruling's, and if the module moves
## off them this suite says so.
const RULED_PRIMARY_COUNT: int = 8192

## The four values SAVE-C3-R01 names and REJECTS, each with the reading that produces it. They are
## tested BY VALUE because the point is that every one of them is positive, representable, and
## wrong -- a "positive u64" gate would wave all four through.
const REJECTED_OLD_FIXTURE: int = 7
const REJECTED_PLOT_CYCLE_TABLE: int = 4096
const REJECTED_OWNER_CAPACITY_SUM: int = 5248
const REJECTED_ALL_FIVE_EXTENT_SUM: int = 14080

## Absolute wire offsets, written as literals on purpose. `Section.OFFSET_PRIMARY_COUNT` is the
## module's own arithmetic, and a vector that located itself through the thing it is checking is
## how §7's `_read_block()` and §9's ordinal swap both survived a round trip. 23 = 4 (store_count)
## + 4 (key length) + 11 ("job_planner") + 4 (owner schema).
const WIRE_OFFSET_PRIMARY_COUNT: int = 23
const WIRE_OFFSET_PAYLOAD_LENGTH: int = 31
const WIRE_FRAMING_BYTES: int = 39

var _record: Section.Record = null


func before_each() -> void:
	"""Build an empty-planner Record for each test."""
	_record = Section.Record.new()


# --- fixtures ---------------------------------------------------------------------------------------

func _service_row(owner_slot: int, operation: int) -> int:
	"""The planner's owner-major service row index, transcribed rather than read back."""
	return owner_slot * 2 + operation


func _demand_row(zone_slot: int, kind: int) -> int:
	"""The planner's owner-major demand row index, transcribed rather than read back."""
	return zone_slot * 5 + kind


func _write(field: int, row: int, value: int) -> void:
	"""Write one value into the suite's Record."""
	_record.set_value(field, row, value)


func _populate() -> void:
	"""A valid, busy section 8: two farm services, two sowing rows, a zone, and two hives."""
	_populate_service()
	_populate_demand()
	_populate_hives()


func _populate_service() -> void:
	"""One pending tend, one requested sowing, one published sowing, one retired tend row."""
	var tend: int = _service_row(5, 0)
	_write(Section.FIELD_STATUS, tend, 1)
	_write(Section.FIELD_OWNER_SLOT, tend, 100)
	_write(Section.FIELD_OWNER_GENERATION, tend, 3)
	_write(Section.FIELD_SERVICE_DAY, tend, 12)
	_write(Section.FIELD_SERVICED_DAY, tend, 11)
	_write(Section.FIELD_JOB_SLOT, tend, 200)
	_write(Section.FIELD_JOB_GENERATION, tend, 1)
	_write(Section.FIELD_REQUIRES_WATER, tend, 1)
	_write(Section.FIELD_SERVICED_DAY, _service_row(7, 0), 9)
	_populate_sowing()


func _populate_sowing() -> void:
	"""A REQUESTED cycle on plot 9 and a PENDING one on plot 3, each agreeing with its cursor."""
	var requested: int = _service_row(9, 1)
	_write(Section.FIELD_STATUS, requested, 3)
	_write(Section.FIELD_OWNER_SLOT, requested, 101)
	_write(Section.FIELD_OWNER_GENERATION, requested, 4)
	_write(Section.FIELD_FIELD_CYCLE, requested, 1)
	_write(Section.FIELD_REQUESTED_CROP, requested, 3)
	_write(Section.FIELD_CYCLE_CURSOR, 9, 1)
	var published: int = _service_row(3, 1)
	_write(Section.FIELD_STATUS, published, 1)
	_write(Section.FIELD_OWNER_SLOT, published, 102)
	_write(Section.FIELD_OWNER_GENERATION, published, 5)
	_write(Section.FIELD_FIELD_CYCLE, published, 2)
	_write(Section.FIELD_REQUESTED_CROP, published, 1)
	_write(Section.FIELD_JOB_SLOT, published, 203)
	_write(Section.FIELD_JOB_GENERATION, published, 2)
	_write(Section.FIELD_CYCLE_CURSOR, 3, 2)
	_write(Section.FIELD_COMPLETED_CYCLE, 3, 1)


func _populate_demand() -> void:
	"""Zone 2 enabled, one pending harvest, one unmet claim, one free row retaining its blocker."""
	_write(Section.FIELD_DEMAND_ENABLED, 2, 1)
	_write(Section.FIELD_DEMAND_OWNER_SLOT, 2, 300)
	_write(Section.FIELD_DEMAND_OWNER_GENERATION, 2, 2)
	var pending: int = _demand_row(2, 1)
	_write(Section.FIELD_DEMAND_STATUS, pending, 1)
	_write(Section.FIELD_DEMAND_JOB_SLOT, pending, 301)
	_write(Section.FIELD_DEMAND_JOB_GENERATION, pending, 7)
	_write(Section.FIELD_DEMAND_QUANTIFIED_MILLI, pending, 4500)
	var unmet: int = _demand_row(2, 2)
	_write(Section.FIELD_DEMAND_STATUS, unmet, 2)
	_write(Section.FIELD_DEMAND_QUANTIFIED_MILLI, unmet, 1200)
	_write(Section.FIELD_DEMAND_BLOCKER, unmet, 3)
	_write(Section.FIELD_DEMAND_BLOCKER, _demand_row(2, 3), 5)


func _populate_hives() -> void:
	"""One pending hive service and one free hive still owed winter feed."""
	_write(Section.FIELD_HIVE_STATUS, 4, 1)
	_write(Section.FIELD_HIVE_OWNER_SLOT, 4, 400)
	_write(Section.FIELD_HIVE_OWNER_GENERATION, 4, 9)
	_write(Section.FIELD_HIVE_SERVICE_DAY, 4, 12)
	_write(Section.FIELD_HIVE_JOB_SLOT, 4, 401)
	_write(Section.FIELD_HIVE_JOB_GENERATION, 4, 3)
	_write(Section.FIELD_HIVE_FEED_DEMAND_MILLI, 4, 250)
	_write(Section.FIELD_HIVE_FEED_DEMAND_MILLI, 8, 700)
	_write(Section.FIELD_HIVE_BLOCKER, 8, 3)


func _encode(record: Section.Record) -> PackedByteArray:
	"""Encode a whole section and assert it succeeded, returning its bytes.

	Takes no primary count: SAVE-C3-R01 binds it to the compiled constant, so there is nothing for
	a test -- or any other caller -- to pass. A wrong count now has to be INJECTED INTO THE WIRE at
	byte 23, which is what `test_a_primary_count_that_is_not_the_designated_table_refuses()` does.
	"""
	var out: Section.EncodeResult = Section.EncodeResult.new()
	var ok: bool = Section.encode_section(record, out)
	assert_true(ok, "encode_section succeeds: %s %s" % [out.refusal, out.detail])
	return out.bytes


func _decode(bytes: PackedByteArray, out: Section.Record) -> SaveHeader.Refusal:
	"""Decode a section at offset 0 into `out`."""
	return Section.decode_section_into(bytes, 0, out)


func _patch_u32(bytes: PackedByteArray, offset: int, value: int) -> PackedByteArray:
	"""Overwrite four little-endian bytes of a copy, for corrupting a framing field."""
	var patched: PackedByteArray = bytes.duplicate()
	var scalar: SaveCodec.Scalar = SaveCodec.Scalar.new()
	assert_true(SaveCodec.write_u32_into(patched, offset, value, scalar), "patched u32")
	return patched


func _patch_u64(bytes: PackedByteArray, offset: int, value: int) -> PackedByteArray:
	"""Overwrite eight little-endian bytes of a copy."""
	var patched: PackedByteArray = bytes.duplicate()
	var scalar: SaveCodec.Scalar = SaveCodec.Scalar.new()
	assert_true(SaveCodec.write_u64_into(patched, offset, value, scalar), "patched u64")
	return patched


func _value_bytes(bytes: PackedByteArray, field: int, row: int) -> PackedByteArray:
	"""The wire bytes of one value, located through the module's own offset arithmetic."""
	var start: int = Section.field_value_offset(field) + row * Section.FIELD_WIDTHS[field]
	return bytes.slice(start, start + Section.FIELD_WIDTHS[field])


func _refuses(refusal: SaveHeader.Refusal, code: StringName, message: String) -> void:
	"""Assert one refusal carries exactly the expected code."""
	assert_equal(refusal.code, code, "%s (detail: %s)" % [message, refusal.detail])


# --- the declared schema ------------------------------------------------------------------------

func test_declared_ordinals_match_the_registry_artifact() -> void:
	"""REG-R01's 35 declared ordinals, keys, type codes and capacities are what this module emits."""
	var text: String = FileAccess.get_file_as_string(REGISTRY_PATH)
	assert_true(text.length() > 0, "the canonical registry artifact is readable")
	var parsed: Variant = JSON.parse_string(text)
	var owners: Array = (parsed as Dictionary)["owners"] as Array
	var fields: Array = []
	for owner: Variant in owners:
		var group: Dictionary = owner as Dictionary
		if int(group["section_id"]) == Section.SECTION_ID \
				and String(group["owner_key"]) == Section.OWNER_KEY:
			fields = group["fields"] as Array
			assert_equal(int(group["owner_schema_version"]), Section.OWNER_SCHEMA_VERSION,
				"section 8 owner schema version")
	assert_equal(fields.size(), Section.FIELD_COUNT, "section 8 declares 35 fields")
	for entry: Variant in fields:
		var field: Dictionary = entry as Dictionary
		var ordinal: int = int(field["ordinal"])
		assert_equal(String(field["field_key"]), String(Section.FIELD_KEYS[ordinal]),
			"ordinal %d key" % ordinal)
		assert_equal(int(field["type_code"]), Section.FIELD_TYPES[ordinal],
			"ordinal %d type code" % ordinal)
		var shape: Dictionary = field["shape"] as Dictionary
		if field.get("scalar", false):
			assert_equal(int(shape["count"]), Section.FIELD_EXTENTS[ordinal],
				"ordinal %d scalar extent" % ordinal)
		else:
			assert_true(String(shape["declared_capacity"]).contains(
				str(Section.FIELD_EXTENTS[ordinal])), "ordinal %d declared capacity" % ordinal)


func test_extents_come_from_the_owning_schema() -> void:
	"""Every extent is `job_planner.gd`'s own constant, and the five tables are five sizes."""
	assert_equal(Section.SERVICE_ROWS, JobPlannerScript.SERVICE_ROW_COUNT, "service rows")
	assert_equal(Section.OWNER_ROWS, JobPlannerScript.OWNER_CAPACITY, "owner rows")
	assert_equal(Section.ZONE_ROWS, JobPlannerScript.ZONE_OWNER_CAPACITY, "zone rows")
	assert_equal(Section.DEMAND_ROWS, JobPlannerScript.DEMAND_ROW_COUNT, "demand rows")
	assert_equal(Section.HIVE_ROWS, JobPlannerScript.HIVE_OWNER_CAPACITY, "hive rows")
	var distinct: Dictionary = {}
	for field: int in Section.FIELD_COUNT:
		distinct[Section.FIELD_EXTENTS[field]] = true
	assert_equal(distinct.size(), 6, "the block spans five table extents plus scalar extent 1")
	assert_equal(Section.FIELD_EXTENTS[Section.FIELD_DEMAND_ENABLED], 128,
		"_demand_enabled is a zone column, not a service column")


func test_layout_constants_match_their_recomputation() -> void:
	"""The literal byte totals agree with the arithmetic over FIELD_WIDTHS and FIELD_EXTENTS."""
	assert_equal(Section.payload_bytes(), Section.PAYLOAD_BYTES, "payload bytes")
	assert_equal(Section.canonical_value_bytes(), Section.CANONICAL_VALUE_BYTES, "value bytes")
	assert_equal(Section.SECTION_BYTES, Section.FRAMING_BYTES + Section.PAYLOAD_BYTES,
		"section bytes")
	assert_equal(Section.FRAMING_BYTES, 4 + 4 + Section.OWNER_KEY_BYTES + 4 + 8 + 8,
		"the owner wrapper is 39 bytes")
	assert_equal(Section.OWNER_KEY_BYTES, Section.OWNER_KEY.to_utf8_buffer().size(),
		"owner key byte length")
	assert_equal(Section.PAYLOAD_BYTES, 384164, "pinned payload length")
	assert_equal(Section.SECTION_BYTES, 384203, "pinned section length")


func test_field_tables_agree_with_each_other() -> void:
	"""Widths, storage indexes and the three type groups are recomputed, never trusted."""
	for field: int in Section.FIELD_COUNT:
		assert_equal(Section.field_width(field), Section.FIELD_WIDTHS[field],
			"field %d width" % field)
		assert_equal(Section.storage_index_of(field), Section.FIELD_STORAGE[field],
			"field %d storage index" % field)
	assert_equal(Section.FIELD_KEYS.size(), Section.FIELD_COUNT, "35 keys")
	assert_equal(Section.FIELD_UNUSED.size(), Section.FIELD_COUNT, "35 unused values")
	assert_equal(_record.u8_columns.size(), 8, "eight u8 columns")
	assert_equal(_record.i32_columns.size(), 25, "twenty-five i32 columns")
	assert_equal(_record.i64_columns.size(), 2, "two i64 columns")


func test_payload_tiles_with_no_gaps() -> void:
	"""Every field's count and values abut the next; the last one ends at the section's end."""
	assert_equal(Section.field_count_offset(0), Section.FRAMING_BYTES, "first count follows framing")
	for field: int in Section.FIELD_COUNT:
		assert_equal(Section.field_value_offset(field),
			Section.field_count_offset(field) + 8, "field %d values follow its count" % field)
	var last: int = Section.FIELD_COUNT - 1
	var end: int = Section.field_value_offset(last) \
		+ Section.FIELD_WIDTHS[last] * Section.FIELD_EXTENTS[last]
	assert_equal(end, Section.SECTION_BYTES, "the last column ends at the section end")


func test_empty_record_holds_the_declared_unused_values() -> void:
	"""`Record.clear()` is `job_planner.gd::clear()`: -1 slots, 0 generations, NO_CROP crops."""
	assert_equal(_record.value_of(Section.FIELD_OWNER_SLOT, 0), -1, "free owner slot")
	assert_equal(_record.value_of(Section.FIELD_OWNER_GENERATION, 0), 0, "free owner generation")
	assert_equal(_record.value_of(Section.FIELD_REQUESTED_CROP, 0), -1, "free crop is NO_CROP")
	assert_equal(_record.value_of(Section.FIELD_HIVE_JOB_SLOT, 1023), -1, "free hive job slot")
	assert_equal(_record.value_of(Section.FIELD_DEMAND_QUANTIFIED_MILLI, 639), 0, "free claim")
	assert_equal(_record.value_of(Section.FIELD_STATUS, 8191), 0, "free status")
	assert_true(Section.record_refusal(_record).is_ok(), "an empty planner is a valid section 8")


# --- pinned bytes -------------------------------------------------------------------------------

func test_framing_bytes_are_pinned() -> void:
	"""The 39-byte owner wrapper as ONE literal hex vector, sliced at literal offsets.

	SAVE-C3-R01's acceptance is "pin exact §8 wrapper bytes". Every offset and every digit below is
	a literal: `bytes.slice(0, 39)`, not `slice(0, Section.FRAMING_BYTES)`. A vector that addressed
	itself through the module's own constants would move silently with them, which is exactly how
	§7's recomputed payload length and §9's symmetric ordinal swap both survived a round trip.

	`0020000000000000` is 8192 as a little-endian u64 (0x2000), sitting at byte 23.
	"""
	var bytes: PackedByteArray = _encode(_record)
	assert_equal(bytes.size(), 384203, "section length is the frozen 384203 bytes")
	assert_equal(bytes.slice(0, WIRE_FRAMING_BYTES).hex_encode(),
		"01000000"
		+ "0b000000"
		+ "6a6f625f706c616e6e6572"
		+ "02000000"
		+ "0020000000000000"
		+ "a4dc050000000000",
		"store count 1, key length 11, 'job_planner', schema 2, primary 8192, payload 384164")
	assert_equal(bytes.slice(WIRE_OFFSET_PRIMARY_COUNT, WIRE_OFFSET_PRIMARY_COUNT + 8).hex_encode(),
		"0020000000000000", "byte 23 is the designated primary count, 8192 LE")
	assert_equal(bytes.slice(WIRE_OFFSET_PAYLOAD_LENGTH, WIRE_FRAMING_BYTES).hex_encode(),
		"a4dc050000000000", "byte 31 is payload_byte_length 384164")


func test_the_pinned_offsets_are_the_modules_offsets() -> void:
	"""The literal offsets above and the module's own arithmetic must agree.

	Kept SEPARATE from the vector on purpose: the vector proves the bytes, this proves the module
	has not quietly redefined where they live. Folding the two together is what makes a wire check
	self-referential.
	"""
	assert_equal(Section.OFFSET_PRIMARY_COUNT, WIRE_OFFSET_PRIMARY_COUNT, "primary count at 23")
	assert_equal(Section.OFFSET_PAYLOAD_BYTE_LENGTH, WIRE_OFFSET_PAYLOAD_LENGTH, "length at 31")
	assert_equal(Section.FRAMING_BYTES, WIRE_FRAMING_BYTES, "the wrapper is 39 bytes")
	assert_equal(Section.SECTION_BYTES, 384203, "the section length is advanced by SAVE-J2-R01")
	assert_equal(Section.PAYLOAD_BYTES, 384164, "the payload is advanced by SAVE-J2-R01")
	assert_equal(Section.FIELD_COUNT, 35, "35 fields, advanced by SAVE-J2-R01")
	assert_equal(Section.OWNER_SCHEMA_VERSION, 2, "SAVE-J2-R01 owner version")


func test_element_counts_are_each_field_own_extent() -> void:
	"""Each of the 35 `element_count:u64` prefixes is its OWN table's row count.

	This is where an extent guessed from the first column dies on the wire: a `_demand_enabled`
	prefix of 8192 instead of 128 is visible here before any value is read.
	"""
	var bytes: PackedByteArray = _encode(_record)
	var scalar: SaveCodec.Scalar = SaveCodec.Scalar.new()
	for field: int in Section.FIELD_COUNT:
		assert_true(SaveCodec.read_u64_at(bytes, Section.field_count_offset(field), scalar),
			"field %d count is readable" % field)
		assert_equal(scalar.value, Section.FIELD_EXTENTS[field], "field %d element count" % field)
	assert_true(SaveCodec.read_u64_at(bytes, Section.field_count_offset(
		Section.FIELD_DEMAND_ENABLED), scalar), "zone count is readable")
	assert_equal(scalar.value, 128, "the zone table declares 128 rows, not the service table's")


func test_column_major_values_are_pinned() -> void:
	"""Unequal-width, non-symmetric columns pinned as SAVE-LAYOUT-R01 requires.

	`_demand_job_slot` is i32 and `_demand_quantified_milli` is i64 over the SAME 640 rows, so the
	two runs have different strides and different lengths. Record-major packing would interleave
	them; column-major keeps each whole, which is what these two vectors prove.
	"""
	_populate()
	var bytes: PackedByteArray = _encode(_record)
	var slot_start: int = Section.field_value_offset(Section.FIELD_DEMAND_JOB_SLOT) \
		+ _demand_row(2, 1) * 4
	assert_equal(bytes.slice(slot_start, slot_start + 8).hex_encode(), "2d010000ffffffff",
		"job slot 301 at row 11 then the null slot at row 12")
	var claim_start: int = Section.field_value_offset(Section.FIELD_DEMAND_QUANTIFIED_MILLI) \
		+ _demand_row(2, 1) * 8
	assert_equal(bytes.slice(claim_start, claim_start + 8).hex_encode(), "9411000000000000",
		"4500 milli-units as eight little-endian bytes")
	assert_equal(bytes.slice(claim_start + 8, claim_start + 16).hex_encode(), "b004000000000000",
		"the next row's 1200 milli-units, immediately after it")
	assert_equal(_value_bytes(bytes, Section.FIELD_STATUS, _service_row(5, 0)).hex_encode(), "01",
		"the tend row's status byte")


func test_canonical_bytes_exclude_the_framing() -> void:
	"""ARCH-HASH-001's contribution is 35 columns of values: no wrapper, no element counts."""
	_populate()
	var out: Section.EncodeResult = Section.EncodeResult.new()
	assert_true(Section.canonical_bytes_of(_record, out), "canonical bytes encode")
	assert_equal(out.bytes.size(), Section.CANONICAL_VALUE_BYTES, "383884 value bytes")
	assert_equal(out.bytes.size(), Section.PAYLOAD_BYTES - 35 * 8, "the 35 counts are excluded")
	var expected: PackedByteArray = PackedByteArray()
	for field: int in Section.FIELD_COUNT:
		expected.append_array(_record.column_bytes(field))
	assert_equal(out.bytes, expected, "canonical bytes are the columns in ordinal order")
	var changed: Section.Record = Section.Record.new()
	changed.copy_from(_record)
	changed.set_value(Section.FIELD_HIVE_FEED_DEMAND_MILLI, 8, 701)
	var moved: Section.EncodeResult = Section.EncodeResult.new()
	assert_true(Section.canonical_bytes_of(changed, moved), "second canonical encode")
	assert_false(moved.bytes == out.bytes, "every section 8 field is hashed")


func test_round_trip_is_byte_identical() -> void:
	"""Encode, decode, re-encode: the same 384203 bytes and the same 35 columns."""
	_populate()
	var bytes: PackedByteArray = _encode(_record)
	var decoded: Section.Record = Section.Record.new()
	_refuses(_decode(bytes, decoded), Section.REFUSE_NONE, "round trip")
	assert_true(decoded.equals(_record), "every column survives the round trip")
	assert_equal(_encode(decoded), bytes, "re-encode is byte-identical")


# --- SAVE-C3-R01: the primary count is the designated pending-service table -----------------------

func test_primary_count_is_the_designated_pending_service_table() -> void:
	"""8192, because it is the PENDING-SERVICE row extent -- not because it is column zero's.

	The distinction is not pedantry: 8192 is also `FIELD_EXTENTS[0]`, so a codec that derived the
	count from the first column would produce the same byte for the wrong reason and pass every
	equality test here. What separates the two is that the designation follows the TABLE: this
	asserts `PRIMARY_COUNT == SERVICE_ROW_COUNT` against the planner's own constant, and asserts it
	is NOT any of the other four extents nor any of the sums a reader might otherwise derive.
	"""
	assert_equal(Section.PRIMARY_COUNT, RULED_PRIMARY_COUNT, "SAVE-C3-R01 designates 8192")
	assert_equal(Section.PRIMARY_COUNT, JobPlannerScript.SERVICE_ROW_COUNT,
		"it is the pending-service row table, read from the planner")
	assert_equal(Section.SERVICE_ROWS + Section.OWNER_ROWS + Section.ZONE_ROWS
		+ Section.DEMAND_ROWS + Section.HIVE_ROWS, REJECTED_ALL_FIVE_EXTENT_SUM,
		"the five extents really do sum to 14080")
	assert_equal(Section.OWNER_ROWS + Section.ZONE_ROWS + Section.HIVE_ROWS,
		REJECTED_OWNER_CAPACITY_SUM, "the three owner capacities really do sum to 5248")
	for rejected: int in [REJECTED_OLD_FIXTURE, REJECTED_PLOT_CYCLE_TABLE,
			REJECTED_OWNER_CAPACITY_SUM, REJECTED_ALL_FIVE_EXTENT_SUM]:
		assert_false(Section.PRIMARY_COUNT == rejected, "%d is not the primary count" % rejected)
	assert_equal(Section.OWNER_ROWS, REJECTED_PLOT_CYCLE_TABLE, "4096 is the secondary table")
	assert_equal(Section.ZONE_ROWS, 128, "the zone table is 128 and stayed 128")
	assert_equal(Section.DEMAND_ROWS, 640, "the demand table is 640 and stayed 640")
	assert_equal(Section.HIVE_ROWS, 1024, "the hive table is 1024 and stayed 1024")


func test_the_caller_cannot_choose_a_primary_count() -> void:
	"""`primary_count_refusal()` accepts exactly one value and refuses all four named alternatives.

	SAVE-C3-R01: "Writer and decoder must validate against the compiled constant rather than a
	caller-supplied positive number." Every rejected value here is positive and u64-representable,
	so a `> 0` gate would pass all of them.
	"""
	assert_true(Section.primary_count_refusal(RULED_PRIMARY_COUNT).is_ok(), "8192 is accepted")
	for rejected: int in [REJECTED_OLD_FIXTURE, REJECTED_PLOT_CYCLE_TABLE,
			REJECTED_OWNER_CAPACITY_SUM, REJECTED_ALL_FIVE_EXTENT_SUM, 128, 640, 1024, 8191,
			8193, 0, -1]:
		var refusal: SaveHeader.Refusal = Section.primary_count_refusal(rejected)
		assert_false(refusal.is_ok(), "%d is refused as a primary count" % rejected)
		assert_equal(refusal.code, Section.REFUSE_PRIMARY_COUNT, "refusal code for %d" % rejected)


func test_a_primary_count_that_is_not_the_designated_table_refuses() -> void:
	"""A header whose count word disagrees with the body is refused, and writes nothing.

	The wrong count is injected STRAIGHT INTO THE WIRE at literal byte 23, because the encoder no
	longer offers a way to produce one. This is the mutation the ruling names: a decode that
	accepted such a header would load a section 8 written under a different reading of the field.
	"""
	var bytes: PackedByteArray = _encode(_record)
	var loaded: Section.Record = Section.Record.new()
	_refuses(_decode(bytes, loaded), Section.REFUSE_NONE, "the honest section loads")
	var before: Section.Record = Section.Record.new()
	before.copy_from(loaded)
	for rejected: int in [REJECTED_OLD_FIXTURE, REJECTED_PLOT_CYCLE_TABLE,
			REJECTED_OWNER_CAPACITY_SUM, REJECTED_ALL_FIVE_EXTENT_SUM, 0]:
		var forged: PackedByteArray = _patch_u64(bytes, WIRE_OFFSET_PRIMARY_COUNT, rejected)
		assert_equal(forged.size(), 384203, "the forged section is still full length")
		assert_equal(forged.slice(0, WIRE_OFFSET_PRIMARY_COUNT),
			bytes.slice(0, WIRE_OFFSET_PRIMARY_COUNT), "only the count word changed")
		assert_equal(forged.slice(WIRE_OFFSET_PAYLOAD_LENGTH, 384203),
			bytes.slice(WIRE_OFFSET_PAYLOAD_LENGTH, 384203), "the body is untouched")
		_refuses(_decode(forged, loaded), Section.REFUSE_PRIMARY_COUNT,
			"a header claiming %d is refused" % rejected)
		assert_true(loaded.equals(before), "the refused decode wrote nothing")


func test_the_encoder_writes_the_ruled_count_unconditionally() -> void:
	"""Two encodes of two different Records agree byte for byte across the whole wrapper."""
	var empty: PackedByteArray = _encode(_record)
	_populate()
	var full: PackedByteArray = _encode(_record)
	assert_false(empty == full, "the two Records do differ somewhere")
	assert_equal(empty.slice(0, WIRE_FRAMING_BYTES), full.slice(0, WIRE_FRAMING_BYTES),
		"the wrapper does not depend on the state it frames")
	var scalar: SaveCodec.Scalar = SaveCodec.Scalar.new()
	assert_true(SaveCodec.read_u64_at(full, WIRE_OFFSET_PRIMARY_COUNT, scalar), "count is readable")
	assert_equal(scalar.value, RULED_PRIMARY_COUNT, "a populated section still declares 8192")


func test_production_write_is_refused_while_the_store_has_no_column_api() -> void:
	"""SAVE-C3-R01 closes J1 but tells this lane to keep refusing production writes for J2.

	Binding a count is not a capture adapter. The refusal must therefore still fire, and must now
	name the REMAINING hole rather than the closed one.
	"""
	var refusal: SaveHeader.Refusal = Section.production_write_refusal()
	assert_false(refusal.is_ok(), "writing section 8 into a save file is still refused")
	assert_equal(refusal.code, Section.REFUSE_STORE_NO_COLUMN_API, "it is BLOCKER J2's code")
	assert_true(refusal.detail.contains("copy_job_index_columns_into"),
		"the refusal names the reader the planner owner must add")
	assert_true(refusal.detail.contains(str(RULED_PRIMARY_COUNT)),
		"and records that the count itself is settled")


# --- BLOCKER J2: no live store round trip yet -------------------------------------------------------

func test_capture_and_apply_refuse_without_a_planner_column_api() -> void:
	"""`job_planner.gd` publishes no bulk column reader or writer, so both halves refuse."""
	var planner: JobPlannerScript = JobPlannerScript.new()
	var out: Section.Record = Section.Record.new()
	var captured: SaveHeader.Refusal = Section.capture_into(planner, out)
	_refuses(captured, Section.REFUSE_STORE_NO_COLUMN_API, "capture_into refuses")
	assert_true(captured.detail.contains("copy_job_index_columns_into"),
		"the refusal names the reader the planner owner must add")
	assert_true(out.equals(Section.Record.new()), "a refused capture wrote nothing")
	_populate()
	_refuses(Section.apply(_record, planner), Section.REFUSE_STORE_NO_COLUMN_API,
		"apply refuses a valid record for want of a writer")


func test_apply_reports_an_invalid_record_before_the_blocker() -> void:
	"""A caller with a corrupt Record learns that first; the blocker is not a catch-all."""
	var planner: JobPlannerScript = JobPlannerScript.new()
	_write(Section.FIELD_STATUS, 0, JobPlannerScript.STATUS_COUNT)
	_refuses(Section.apply(_record, planner), Section.REFUSE_STATUS_DOMAIN,
		"validation runs before the blocker")


func test_capture_record_into_is_all_or_nothing() -> void:
	"""The column-level capture that works today: valid copies, invalid leaves `out` untouched."""
	_populate()
	var out: Section.Record = Section.Record.new()
	_refuses(Section.capture_record_into(_record, out), Section.REFUSE_NONE, "valid capture")
	assert_true(out.equals(_record), "the capture published every column")
	var before: Section.Record = Section.Record.new()
	before.copy_from(out)
	var broken: Section.Record = Section.Record.new()
	broken.copy_from(_record)
	broken.set_value(Section.FIELD_HIVE_OWNER_GENERATION, 4, 0)
	_refuses(Section.capture_record_into(broken, out), Section.REFUSE_REFERENCE_SHAPE,
		"a half reference refuses")
	assert_true(out.equals(before), "a refused capture left the record byte-identical")


# --- allocate before consume, and the framing gates ----------------------------------------------

func test_a_full_length_invalid_section_leaves_the_record_byte_identical() -> void:
	"""Decision 0059, tested where it actually bites: the extent gate catches a TRUNCATION long
	before anything is read, so the case that proves validate-then-commit is a section of exactly
	the right length whose 300000th byte is wrong."""
	_populate()
	var bytes: PackedByteArray = _encode(_record)
	var corrupt: PackedByteArray = bytes.duplicate()
	var offset: int = Section.field_value_offset(Section.FIELD_HIVE_JOB_SLOT) + 8 * 4
	var scalar: SaveCodec.Scalar = SaveCodec.Scalar.new()
	assert_true(SaveCodec.write_i32_into(corrupt, offset, 77, scalar), "corrupted a free hive row")
	assert_equal(corrupt.size(), Section.SECTION_BYTES, "the corrupt section is full length")
	var out: Section.Record = Section.Record.new()
	_refuses(_decode(bytes, out), Section.REFUSE_NONE, "first load")
	var before: Section.Record = Section.Record.new()
	before.copy_from(out)
	_refuses(_decode(corrupt, out), Section.REFUSE_ROW_NOT_CLEAR,
		"a free hive row holding a Job slot is refused")
	assert_true(out.equals(before), "the refused decode wrote nothing at all")


func test_truncation_and_offsets_are_gated_before_any_read() -> void:
	"""`extent_refusal()` is the primary gate and is public so it can be tested on its own."""
	var bytes: PackedByteArray = _encode(_record)
	assert_true(Section.extent_refusal(bytes, 0).is_ok(), "a whole section at offset 0")
	_refuses(Section.extent_refusal(bytes, 1), Section.REFUSE_TRUNCATED, "one byte short")
	_refuses(Section.extent_refusal(bytes, -1), Section.REFUSE_NEGATIVE_OFFSET, "negative offset")
	_refuses(Section.extent_refusal(bytes.slice(0, Section.SECTION_BYTES - 1), 0),
		Section.REFUSE_TRUNCATED, "a section one byte short")
	var padded: PackedByteArray = PackedByteArray()
	padded.resize(9)
	padded.append_array(bytes)
	assert_true(Section.extent_refusal(padded, 9).is_ok(), "a section at a nonzero offset")
	var out: Section.Record = Section.Record.new()
	_refuses(Section.decode_section_into(padded, 9, out),
		Section.REFUSE_NONE, "decoding at a nonzero offset")


func test_section_length_refusal_checks_a_descriptor() -> void:
	"""SAVE-R09-004: a descriptor claiming any other length is wrong before a byte is read."""
	assert_true(Section.section_length_refusal(Section.SECTION_BYTES).is_ok(), "the exact length")
	_refuses(Section.section_length_refusal(Section.SECTION_BYTES - 1), Section.REFUSE_LENGTH,
		"one byte short")
	assert_equal(Section.descriptor_row_count(), RULED_PRIMARY_COUNT,
		"§8 holds one block, so its descriptor row_count is that block's primary count")
	assert_equal(Section.descriptor_row_count(), Section.PRIMARY_COUNT,
		"the descriptor and the wrapper cannot disagree")
	for rejected: int in [REJECTED_OLD_FIXTURE, REJECTED_PLOT_CYCLE_TABLE,
			REJECTED_OWNER_CAPACITY_SUM, REJECTED_ALL_FIVE_EXTENT_SUM]:
		assert_false(Section.descriptor_row_count() == rejected,
			"the descriptor is not %d" % rejected)


func test_a_payload_length_that_disagrees_with_the_body_refuses() -> void:
	"""The wrapper cannot claim a length the 384164-byte body does not have."""
	var bytes: PackedByteArray = _encode(_record)
	var out: Section.Record = Section.Record.new()
	_refuses(_decode(_patch_u64(bytes, Section.OFFSET_PAYLOAD_BYTE_LENGTH,
		Section.PAYLOAD_BYTES - 8), out), Section.REFUSE_PAYLOAD_LENGTH,
		"a short payload length")
	_refuses(_decode(_patch_u64(bytes, Section.OFFSET_PAYLOAD_BYTE_LENGTH,
		Section.SECTION_BYTES), out), Section.REFUSE_PAYLOAD_LENGTH,
		"a payload length that swallowed the wrapper")


func test_the_owner_wrapper_is_checked_field_by_field() -> void:
	"""Store count, owner key and schema version each refuse on their own."""
	var bytes: PackedByteArray = _encode(_record)
	var out: Section.Record = Section.Record.new()
	_refuses(_decode(_patch_u32(bytes, Section.OFFSET_STORE_COUNT, 2), out), Section.REFUSE_STORE_COUNT, "section 8 holds one registered block")
	var foreign: PackedByteArray = bytes.duplicate()
	foreign[Section.OFFSET_OWNER_KEY] = "J".to_utf8_buffer()[0]
	_refuses(_decode(foreign, out), Section.REFUSE_OWNER_KEY,
		"'Job_planner' is not this owner")
	_refuses(_decode(_patch_u32(bytes, Section.OFFSET_OWNER_SCHEMA_VERSION, 1),
		out), Section.REFUSE_OWNER_SCHEMA_VERSION, "schema 1 is not 2")
	_refuses(_decode(_patch_u32(bytes, Section.OFFSET_OWNER_KEY_LENGTH, 12),
		out), Section.REFUSE_OWNER_KEY, "a key length of 12")


func test_an_element_count_from_another_table_refuses() -> void:
	"""The 128-row zone column declaring the service table's 8192 rows is refused on the wire."""
	var bytes: PackedByteArray = _encode(_record)
	var out: Section.Record = Section.Record.new()
	var offset: int = Section.field_count_offset(Section.FIELD_DEMAND_ENABLED)
	_refuses(_decode(_patch_u64(bytes, offset, Section.SERVICE_ROWS), out),
		Section.REFUSE_ELEMENT_COUNT, "a zone column claiming 8192 rows")
	_refuses(_decode(_patch_u64(bytes, Section.field_count_offset(0), 0),
		out), Section.REFUSE_ELEMENT_COUNT, "an empty first column")


func test_a_record_of_the_wrong_shape_refuses_before_indexing() -> void:
	"""A column sized at another table's extent is refused by `_shape_refusal()`, not walked."""
	var wrong: PackedByteArray = PackedByteArray()
	wrong.resize(Section.SERVICE_ROWS)
	_record.u8_columns[Section.FIELD_STORAGE[Section.FIELD_DEMAND_ENABLED]] = wrong
	var refusal: SaveHeader.Refusal = Section.record_refusal(_record)
	_refuses(refusal, Section.REFUSE_RECORD_SHAPE, "a zone column holding 8192 values")
	assert_true(refusal.detail.contains("_demand_enabled"), "the refusal names the column")


# --- the int32 sign trap -------------------------------------------------------------------------

func test_a_generation_of_0x80000000_is_refused_as_negative() -> void:
	"""GDScript ints are 64-bit: `0x80000000` is a positive 2147483648 and an i32 -2147483648.

	The bit pattern is built through the codec's own helpers and the pair is asserted, rather than
	typing a signed literal and hoping the two agree.
	"""
	var unsigned: int = SaveCodec.UINT32_SIGN_BIT
	assert_equal(unsigned, 2147483648, "0x80000000 is positive in a 64-bit int")
	assert_equal(SaveCodec.u32_bits_to_int32(unsigned), -2147483648, "the same bits as int32")
	assert_equal(SaveCodec.int32_bits_to_u32(-2147483648), unsigned, "and back again")
	var bytes: PackedByteArray = _encode(_record)
	var offset: int = Section.field_value_offset(Section.FIELD_OWNER_GENERATION)
	var scalar: SaveCodec.Scalar = SaveCodec.Scalar.new()
	var corrupt: PackedByteArray = bytes.duplicate()
	assert_true(SaveCodec.write_u32_into(corrupt, offset, unsigned, scalar), "wrote 00 00 00 80")
	assert_equal(corrupt.slice(offset, offset + 4).hex_encode(), "00000080", "the pinned bytes")
	var out: Section.Record = Section.Record.new()
	_refuses(_decode(corrupt, out), Section.REFUSE_NEGATIVE_VALUE,
		"a generation of -2147483648 is refused, not read as 2147483648")


func test_the_largest_representable_generation_survives() -> void:
	"""2147483647 is a legal directory generation and must not be refused with its neighbour."""
	_write(Section.FIELD_STATUS, 0, 1)
	_write(Section.FIELD_OWNER_SLOT, 0, 7)
	_write(Section.FIELD_OWNER_GENERATION, 0, EntityDirectoryScript.MAX_INT32)
	_write(Section.FIELD_JOB_SLOT, 0, 8)
	_write(Section.FIELD_JOB_GENERATION, 0, EntityDirectoryScript.MAX_INT32)
	assert_true(Section.record_refusal(_record).is_ok(), "a spent generation is still valid")
	var bytes: PackedByteArray = _encode(_record)
	var offset: int = Section.field_value_offset(Section.FIELD_OWNER_GENERATION)
	assert_equal(bytes.slice(offset, offset + 4).hex_encode(), "ffffff7f", "2147483647's bytes")
	var out: Section.Record = Section.Record.new()
	_refuses(_decode(bytes, out), Section.REFUSE_NONE, "it round-trips")
	assert_equal(out.value_of(Section.FIELD_OWNER_GENERATION, 0),
		EntityDirectoryScript.MAX_INT32, "and comes back exactly")


# --- column domains ------------------------------------------------------------------------------

func test_bounded_byte_columns_refuse_a_value_outside_their_own_domain() -> void:
	"""Each u8 column is bounded by ITS OWN owning enum count, not by a shared maximum."""
	_write(Section.FIELD_STATUS, 3, JobPlannerScript.STATUS_COUNT)
	_refuses(Section.record_refusal(_record), Section.REFUSE_STATUS_DOMAIN, "status 4")
	_write(Section.FIELD_STATUS, 3, 0)
	_write(Section.FIELD_GATE_REASON, 3, JobPlannerScript.REASON_COUNT)
	_refuses(Section.record_refusal(_record), Section.REFUSE_REASON_DOMAIN, "gate reason 6")
	_write(Section.FIELD_GATE_REASON, 3, 0)
	_write(Section.FIELD_DEMAND_BLOCKER, 3, JobPlannerScript.BLOCKER_COUNT)
	_refuses(Section.record_refusal(_record), Section.REFUSE_REASON_DOMAIN, "demand blocker 12")
	_write(Section.FIELD_DEMAND_BLOCKER, 3, 0)
	_write(Section.FIELD_HIVE_BLOCKER, 3, JobPlannerScript.HIVE_BLOCKER_COUNT)
	_refuses(Section.record_refusal(_record), Section.REFUSE_REASON_DOMAIN, "hive blocker 5")


func test_flag_columns_hold_only_zero_or_one() -> void:
	"""`_requires_water` and `_demand_enabled` are flags; 2 is not a truer true."""
	var tend: int = _service_row(1, 0)
	_write(Section.FIELD_STATUS, tend, 1)
	_write(Section.FIELD_OWNER_SLOT, tend, 5)
	_write(Section.FIELD_OWNER_GENERATION, tend, 1)
	_write(Section.FIELD_JOB_SLOT, tend, 6)
	_write(Section.FIELD_JOB_GENERATION, tend, 1)
	_write(Section.FIELD_REQUIRES_WATER, tend, 2)
	_refuses(Section.record_refusal(_record), Section.REFUSE_FLAG_DOMAIN, "requires_water 2")
	_write(Section.FIELD_REQUIRES_WATER, tend, 1)
	assert_true(Section.record_refusal(_record).is_ok(), "1 is a flag")
	_write(Section.FIELD_DEMAND_ENABLED, 5, 2)
	_refuses(Section.record_refusal(_record), Section.REFUSE_FLAG_DOMAIN, "demand_enabled 2")


func test_slot_columns_are_directory_slots() -> void:
	"""A slot outside `[-1, DIRECTORY_CAPACITY)` is refused; a farm-plot row index is not a slot."""
	_write(Section.FIELD_DEMAND_JOB_SLOT, 4, EntityDirectoryScript.DIRECTORY_CAPACITY)
	_refuses(Section.record_refusal(_record), Section.REFUSE_SLOT_DOMAIN, "one past capacity")
	_write(Section.FIELD_DEMAND_JOB_SLOT, 4, -2)
	_refuses(Section.record_refusal(_record), Section.REFUSE_SLOT_DOMAIN, "-2 is not the null slot")
	_write(Section.FIELD_DEMAND_JOB_SLOT, 4, -1)
	assert_true(Section.record_refusal(_record).is_ok(), "-1 is the null slot")


func test_days_cycles_and_quantities_are_never_negative() -> void:
	"""Every day, cycle and milli-unit column refuses a negative value."""
	_write(Section.FIELD_SERVICED_DAY, 2, -1)
	_refuses(Section.record_refusal(_record), Section.REFUSE_NEGATIVE_VALUE, "a negative day")
	_write(Section.FIELD_SERVICED_DAY, 2, 0)
	_write(Section.FIELD_CYCLE_CURSOR, 2, -4)
	_refuses(Section.record_refusal(_record), Section.REFUSE_NEGATIVE_VALUE, "a negative cursor")
	_write(Section.FIELD_CYCLE_CURSOR, 2, 0)
	_write(Section.FIELD_HIVE_FEED_DEMAND_MILLI, 2, -250)
	_refuses(Section.record_refusal(_record), Section.REFUSE_NEGATIVE_VALUE, "a negative demand")
	_write(Section.FIELD_HIVE_FEED_DEMAND_MILLI, 2, 0)
	_write(Section.FIELD_DEMAND_QUANTIFIED_MILLI, 2, -1)
	_refuses(Section.record_refusal(_record), Section.REFUSE_NEGATIVE_VALUE, "a negative claim")


func test_requested_crop_is_a_compiled_crop_or_no_crop() -> void:
	"""`_requested_crop` holds NO_CROP or a crop id `farming.gd` compiled."""
	_write(Section.FIELD_REQUESTED_CROP, _service_row(4, 1), JobPlannerScript.NO_CROP)
	assert_true(Section.record_refusal(_record).is_ok(), "NO_CROP on a free row")
	_write(Section.FIELD_REQUESTED_CROP, _service_row(4, 1), -2)
	_refuses(Section.record_refusal(_record), Section.REFUSE_CROP_DOMAIN, "-2 is no crop")
	_write(Section.FIELD_REQUESTED_CROP, _service_row(4, 1), 5)
	_refuses(Section.record_refusal(_record), Section.REFUSE_CROP_DOMAIN, "crop 5 is not compiled")


# --- the three tables' row rules -------------------------------------------------------------------

func test_a_free_row_keeps_no_residue_of_what_it_carried() -> void:
	"""`service_row_is_clear()`, `demand_row_is_clear()` and `hive_service_row_is_clear()`."""
	_write(Section.FIELD_FIELD_CYCLE, _service_row(6, 1), 4)
	_write(Section.FIELD_CYCLE_CURSOR, 6, 4)
	_refuses(Section.record_refusal(_record), Section.REFUSE_ROW_NOT_CLEAR,
		"a free sowing row keeping its cycle")
	_write(Section.FIELD_FIELD_CYCLE, _service_row(6, 1), 0)
	_write(Section.FIELD_DEMAND_QUANTIFIED_MILLI, 17, 900)
	_refuses(Section.record_refusal(_record), Section.REFUSE_ROW_NOT_CLEAR,
		"a free demand row keeping its claim")
	_write(Section.FIELD_DEMAND_QUANTIFIED_MILLI, 17, 0)
	_write(Section.FIELD_HIVE_SERVICE_DAY, 11, 3)
	_refuses(Section.record_refusal(_record), Section.REFUSE_ROW_NOT_CLEAR,
		"a free hive row keeping its service day")
	_write(Section.FIELD_HIVE_SERVICE_DAY, 11, 0)
	_write(Section.FIELD_REQUIRES_WATER, _service_row(6, 0), 1)
	_refuses(Section.record_refusal(_record), Section.REFUSE_ROW_NOT_CLEAR,
		"a free tend row keeping its water flag")
	_write(Section.FIELD_REQUIRES_WATER, _service_row(6, 0), 0)
	_write(Section.FIELD_GATE_REASON, _service_row(6, 1), 2)
	_refuses(Section.record_refusal(_record), Section.REFUSE_ROW_NOT_CLEAR,
		"a free sowing row keeping its gate reason")


func test_the_history_a_free_row_is_allowed_to_keep() -> void:
	"""The three fields the planner's own predicates EXCLUDE are not hygiene, and stay.

	`_retire_row()` keeps `_serviced_day` because it is "the completion history the ruling forbids
	discarding"; the demand blocker and the hive's winter feed demand are "the row's retained
	REASON-like state, written by the gate sweep onto a free row". A validator that swept them out
	with the rest would refuse a save the planner itself produces every midnight.
	"""
	_write(Section.FIELD_SERVICED_DAY, _service_row(6, 0), 41)
	_write(Section.FIELD_DEMAND_BLOCKER, 17, 9)
	_write(Section.FIELD_HIVE_FEED_DEMAND_MILLI, 11, 2500)
	_write(Section.FIELD_HIVE_BLOCKER, 11, 4)
	assert_true(Section.record_refusal(_record).is_ok(),
		"a free row may keep its completion history and its reason")
	var bytes: PackedByteArray = _encode(_record)
	var out: Section.Record = Section.Record.new()
	_refuses(_decode(bytes, out), Section.REFUSE_NONE, "and round-trips")
	assert_equal(out.value_of(Section.FIELD_SERVICED_DAY, _service_row(6, 0)), 41,
		"the completion day survived")


func test_a_tend_row_carries_no_sowing_state() -> void:
	"""Operation 0 and operation 1 share a table and must not share each other's columns.

	The row is made PENDING first: a FREE row carrying any of these values is refused one step
	earlier, by the row-hygiene predicate, and this rule is about a row that is legitimately in use.
	"""
	_write(Section.FIELD_STATUS, _service_row(6, 0), 1)
	_write(Section.FIELD_OWNER_SLOT, _service_row(6, 0), 20)
	_write(Section.FIELD_OWNER_GENERATION, _service_row(6, 0), 1)
	_write(Section.FIELD_JOB_SLOT, _service_row(6, 0), 21)
	_write(Section.FIELD_JOB_GENERATION, _service_row(6, 0), 1)
	assert_true(Section.record_refusal(_record).is_ok(), "a plain pending tend row is valid")
	_write(Section.FIELD_FIELD_CYCLE, _service_row(6, 0), 1)
	_refuses(Section.record_refusal(_record), Section.REFUSE_OPERATION_MISMATCH,
		"a tend row holding a field cycle")
	_write(Section.FIELD_FIELD_CYCLE, _service_row(6, 0), 0)
	_write(Section.FIELD_GATE_REASON, _service_row(6, 0), 2)
	_refuses(Section.record_refusal(_record), Section.REFUSE_OPERATION_MISMATCH,
		"a tend row holding a sowing gate reason")
	_write(Section.FIELD_GATE_REASON, _service_row(6, 0), 0)
	_write(Section.FIELD_STATUS, _service_row(6, 0), JobPlannerScript.STATUS_REQUESTED)
	_refuses(Section.record_refusal(_record), Section.REFUSE_OPERATION_MISMATCH,
		"STATUS_REQUESTED on a tend row")


func test_a_sowing_row_carries_no_day() -> void:
	"""Sowing is not a daily service: both day columns refuse a value on operation 1.

	The row is made REQUESTED first, for the same reason the tend case is made PENDING: a FREE row
	holding a service day is refused one step earlier by the hygiene predicate.
	"""
	_write(Section.FIELD_STATUS, _service_row(6, 1), 3)
	_write(Section.FIELD_OWNER_SLOT, _service_row(6, 1), 22)
	_write(Section.FIELD_OWNER_GENERATION, _service_row(6, 1), 1)
	_write(Section.FIELD_FIELD_CYCLE, _service_row(6, 1), 1)
	_write(Section.FIELD_REQUESTED_CROP, _service_row(6, 1), 2)
	_write(Section.FIELD_CYCLE_CURSOR, 6, 1)
	assert_true(Section.record_refusal(_record).is_ok(), "a plain requested sowing row is valid")
	_write(Section.FIELD_SERVICE_DAY, _service_row(6, 1), 3)
	_refuses(Section.record_refusal(_record), Section.REFUSE_OPERATION_MISMATCH,
		"a sowing row holding a service day")
	_write(Section.FIELD_SERVICE_DAY, _service_row(6, 1), 0)
	_write(Section.FIELD_SERVICED_DAY, _service_row(6, 1), 3)
	_refuses(Section.record_refusal(_record), Section.REFUSE_OPERATION_MISMATCH,
		"a sowing row holding a serviced day")


func test_an_outstanding_cycle_agrees_with_its_owner_cursor() -> void:
	""""Never reuse a field cycle": an open request names the cycle the cursor last allocated."""
	_populate()
	assert_true(Section.record_refusal(_record).is_ok(), "the fixture agrees")
	_write(Section.FIELD_CYCLE_CURSOR, 9, 2)
	_refuses(Section.record_refusal(_record), Section.REFUSE_CYCLE_DISAGREES,
		"a cursor that ran ahead of its open request")
	_write(Section.FIELD_CYCLE_CURSOR, 9, 1)
	_write(Section.FIELD_COMPLETED_CYCLE, 9, 2)
	_refuses(Section.record_refusal(_record), Section.REFUSE_CYCLE_RANGE,
		"a completed cycle that was never allocated")


func test_an_outstanding_sowing_row_names_a_real_crop() -> void:
	"""A REQUESTED cycle without a crop cannot be sown by anything."""
	_populate()
	_write(Section.FIELD_REQUESTED_CROP, _service_row(9, 1), JobPlannerScript.NO_CROP)
	_refuses(Section.record_refusal(_record), Section.REFUSE_CROP_DOMAIN,
		"an outstanding request with no crop")


func test_exactly_the_pending_rows_carry_a_job() -> void:
	"""A PENDING row with no Job is work nothing records; a retired row with one is a leak."""
	_populate()
	_write(Section.FIELD_JOB_SLOT, _service_row(5, 0), -1)
	_write(Section.FIELD_JOB_GENERATION, _service_row(5, 0), 0)
	_refuses(Section.record_refusal(_record), Section.REFUSE_JOB_BINDING,
		"a pending service with no Job")
	_populate()
	_write(Section.FIELD_DEMAND_JOB_SLOT, _demand_row(2, 2), 500)
	_write(Section.FIELD_DEMAND_JOB_GENERATION, _demand_row(2, 2), 1)
	_refuses(Section.record_refusal(_record), Section.REFUSE_JOB_BINDING,
		"an unmet demand still holding a Job")
	_populate()
	_write(Section.FIELD_HIVE_JOB_SLOT, 4, -1)
	_write(Section.FIELD_HIVE_JOB_GENERATION, 4, 0)
	_refuses(Section.record_refusal(_record), Section.REFUSE_JOB_BINDING,
		"a pending hive service with no Job")


func test_a_used_row_names_its_owner_in_both_halves() -> void:
	"""Half a reference is worse than none: a reused typed row can carry the same generation."""
	_populate()
	_write(Section.FIELD_OWNER_GENERATION, _service_row(5, 0), 0)
	_refuses(Section.record_refusal(_record), Section.REFUSE_REFERENCE_SHAPE,
		"slot 100 with generation 0")
	_populate()
	_write(Section.FIELD_OWNER_SLOT, _service_row(5, 0), -1)
	_refuses(Section.record_refusal(_record), Section.REFUSE_REFERENCE_SHAPE,
		"the null slot with generation 3")
	_populate()
	_write(Section.FIELD_HIVE_OWNER_SLOT, 4, -1)
	_write(Section.FIELD_HIVE_OWNER_GENERATION, 4, 0)
	_refuses(Section.record_refusal(_record), Section.REFUSE_OWNER_MISSING,
		"a pending hive service with no hive")


func test_an_enabled_designation_names_its_zone() -> void:
	"""`_write_enabled_demand()` stores both halves; enablement without them is unattributable."""
	_write(Section.FIELD_DEMAND_ENABLED, 6, 1)
	_refuses(Section.record_refusal(_record), Section.REFUSE_OWNER_MISSING,
		"demand enabled on no designation")
	_write(Section.FIELD_DEMAND_OWNER_SLOT, 6, 44)
	_write(Section.FIELD_DEMAND_OWNER_GENERATION, 6, 2)
	assert_true(Section.record_refusal(_record).is_ok(), "enabled with a designation reference")
	_write(Section.FIELD_DEMAND_ENABLED, 6, 0)
	assert_true(Section.record_refusal(_record).is_ok(),
		"a disabled zone may keep its reference while a row still names it")


func test_requested_status_belongs_only_to_sowing() -> void:
	"""The demand and hive tables use FREE, PENDING and UNMET; REQUESTED has no branch there."""
	_write(Section.FIELD_DEMAND_STATUS, 9, JobPlannerScript.STATUS_REQUESTED)
	_refuses(Section.record_refusal(_record), Section.REFUSE_STATUS_DOMAIN,
		"REQUESTED in the demand table")
	_write(Section.FIELD_DEMAND_STATUS, 9, 0)
	_write(Section.FIELD_HIVE_OWNER_SLOT, 9, 55)
	_write(Section.FIELD_HIVE_OWNER_GENERATION, 9, 1)
	_write(Section.FIELD_HIVE_STATUS, 9, JobPlannerScript.STATUS_REQUESTED)
	_refuses(Section.record_refusal(_record), Section.REFUSE_STATUS_DOMAIN,
		"REQUESTED in the hive table")


# --- encode-side guards ---------------------------------------------------------------------------

func test_encode_refuses_an_invalid_record() -> void:
	"""An invalid Record never reaches the wire, through any of the three encoders."""
	_write(Section.FIELD_STATUS, 1, JobPlannerScript.STATUS_COUNT)
	var section: Section.EncodeResult = Section.EncodeResult.new()
	assert_false(Section.encode_section(_record, section), "no section")
	assert_equal(section.refusal, Section.REFUSE_STATUS_DOMAIN, "section refusal code")
	var payload: Section.EncodeResult = Section.EncodeResult.new()
	assert_false(Section.encode_payload(_record, payload), "no payload")
	var canonical: Section.EncodeResult = Section.EncodeResult.new()
	assert_false(Section.canonical_bytes_of(_record, canonical), "no canonical bytes")
	assert_equal(canonical.bytes.size(), 0, "a refused encode produces no bytes")


func test_this_build_is_little_endian() -> void:
	"""Both bulk conversions are host-ordered memory copies, so both widths are probed."""
	assert_true(Section.byte_order_refusal().is_ok(), "i32 and i64 conversions are little-endian")


func test_module_source_holds_no_float() -> void:
	"""ARCH-AUTH-002: authoritative state is integer, and this module never names a float."""
	var source: String = FileAccess.get_file_as_string(MODULE_PATH)
	assert_true(source.length() > 0, "the module source is readable")
	assert_false(source.contains(": float"), "no float-typed declaration")
	assert_false(source.contains("-> float"), "no float return")
	assert_false(source.contains("PackedFloat"), "no float column")
