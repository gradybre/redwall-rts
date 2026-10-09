extends "res://test/framework/test_case.gd"
## Suite for `save_section_child_arenas.gd` and its generated table (ADR 1222 step 3).
##
## The table is compared against the registry JSON read here (never by production code); the
## codec is exercised through empty and filled round trips and every SAVE_S5_* refusal with `out`
## proved untouched, and the canonical hash adapters are registered on the production walker.

const Section := preload("res://scripts/core/save_section_child_arenas.gd")
const Schema := preload("res://scripts/core/save_child_arenas_schema.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const Digest := preload("res://scripts/core/canonical_state_hash.gd")
const REGISTRY_PATH: String = "res://../docs/planning/canonical_state_registry.json"

const BUILDINGS: int = 0
const CONSTRUCTION: int = 1
const FORAGE: int = 2
const JOBS: int = 3
const ORCHARD_HIVE: int = 4


func _encode(state: Section.State) -> PackedByteArray:
	"""Encode `state`, asserting success."""
	var out: Section.EncodeResult = Section.EncodeResult.new()
	assert_true(Section.encode_section(state, out), "encode: %s %s" % [out.refusal, out.detail])
	return out.bytes


func _marked_state() -> Section.State:
	"""A State distinguishable from the empty one, used as a decode target that must not change."""
	var state: Section.State = Section.State.new()
	assert_true(state.block(FORAGE).set_scalar(0, 77).is_ok(), "mark forage._link_bump")
	return state


func _assert_refused(bytes: PackedByteArray, offset: int, length: int, code: StringName,
		what: String) -> void:
	"""Decode must refuse with exactly `code` and leave the marked target byte-identical."""
	var target: Section.State = _marked_state()
	var refusal: SaveHeader.Refusal = Section.decode_section(bytes, offset, length, target)
	assert_equal(refusal.code, code, "%s: %s" % [what, refusal.detail])
	assert_true(target.equals(_marked_state()), "%s leaves `out` untouched" % what)


func _block_offset(owner: int) -> int:
	"""Section-relative offset of `owner`'s block."""
	var at: int = Schema.STORE_COUNT_BYTES
	for previous: int in owner:
		at += Schema.wrapper_bytes_of(previous) + Schema.payload_bytes_at(previous, false)
	return at


func _count_offset(owner: int, ordinal: int) -> int:
	"""Section-relative offset of one field's element count."""
	var at: int = _block_offset(owner) + Schema.wrapper_bytes_of(owner)
	for previous: int in ordinal:
		at += Schema.FIELD_COUNT_BYTES + Schema.empty_count_of(owner, previous) \
			* Schema.width_of(owner, previous)
	return at


func test_generated_table_matches_the_registry_json() -> void:
	"""Owner order, schemas, field keys, type codes and ordinals equal the registry's section 5."""
	var text: String = FileAccess.get_file_as_string(REGISTRY_PATH)
	assert_false(text.is_empty(), "the registry is readable")
	var registry: Dictionary = JSON.parse_string(text) as Dictionary
	var owner: int = 0
	for raw: Variant in registry["owners"] as Array:
		var row: Dictionary = raw as Dictionary
		if int(row["section_id"]) != 5:
			continue
		assert_equal(Schema.OWNER_KEYS[owner], String(row["owner_key"]), "owner %d key" % owner)
		assert_equal(Schema.OWNER_SCHEMAS[owner], int(row["owner_schema_version"]), "schema")
		var fields: Array = row["fields"] as Array
		assert_equal(Schema.field_count_of(owner), fields.size(), "%d field count" % owner)
		for ordinal: int in fields.size():
			var field: Dictionary = fields[ordinal] as Dictionary
			assert_equal(Schema.field_key_of(owner, ordinal), String(field["field_key"]), "key")
			assert_equal(Schema.field_type_of(owner, ordinal), int(field["type_code"]), "type")
		owner += 1
	assert_equal(owner, Schema.OWNER_COUNT, "five section-5 owners")
	assert_equal(Schema.SECTION_SCHEMA_VERSION,
		int((registry["section_schema_versions"] as Array)[4]), "section schema")


func test_table_rules_are_fixed_and_the_length_is_exact() -> void:
	"""Every field is FIXED or SCALAR, so the empty and maximum sections are the same length."""
	assert_true(Schema.table_refusal().is_ok(), "table_refusal accepts the compiled table")
	assert_equal(Schema.EMPTY_SECTION_BYTES, Schema.MAX_SECTION_BYTES, "a fixed-length section")
	assert_equal(Schema.UNPROVED_FIELDS.size(), 0, "no unproved bound")
	for owner: int in Schema.OWNER_COUNT:
		for ordinal: int in Schema.field_count_of(owner):
			var kind: int = Schema.rule_kind_of(owner, ordinal)
			assert_true(kind == Schema.RULE_FIXED or kind == Schema.RULE_SCALAR,
				"%s.%s" % [Schema.OWNER_KEYS[owner], Schema.field_key_of(owner, ordinal)])
	assert_equal(Schema.rule_value_of(CONSTRUCTION, 0), 331776, "the delivered-material ledger")
	assert_equal(Schema.rule_value_of(JOBS, 3), 8192, "jobs._member_next")
	assert_equal(Schema.rule_value_of(ORCHARD_HIVE, 0), 30720, "orchard_hive link rows")


func _filled_state() -> Section.State:
	"""A state with values in every column type of several owners, set through the setters."""
	var state: Section.State = Section.State.new()
	var next: PackedInt32Array = PackedInt32Array()
	next.resize(8192)
	next.fill(-1)
	next[5] = 9
	assert_true(state.block(JOBS).set_i32_column(3, next).is_ok(), "jobs._member_next")
	var delivered: PackedInt64Array = PackedInt64Array()
	delivered.resize(331776)
	delivered[331775] = 1 << 40
	assert_true(state.block(CONSTRUCTION).set_i64_column(0, delivered).is_ok(), "_delivered")
	assert_true(state.block(FORAGE).set_scalar(2, -5).is_ok(), "forage._link_used")
	return state


func test_empty_and_filled_states_round_trip_to_identical_bytes() -> void:
	"""Both encode to the fixed length and decode back to equal States and identical bytes."""
	for state: Section.State in [Section.State.new(), _filled_state()]:
		var bytes: PackedByteArray = _encode(state)
		assert_equal(bytes.size(), Schema.EMPTY_SECTION_BYTES, "fixed section length")
		assert_equal(bytes.decode_u32(0), 5, "store_count")
		var decoded: Section.State = _marked_state()
		var refusal: SaveHeader.Refusal = Section.decode_section(bytes, 0, bytes.size(), decoded)
		assert_true(refusal.is_ok(), "decode: %s %s" % [refusal.code, refusal.detail])
		assert_true(decoded.equals(state), "decoded equals the source")
		assert_equal(_encode(decoded), bytes, "re-encoding is byte-identical")
	var back: Section.State = Section.State.new()
	var filled: PackedByteArray = _encode(_filled_state())
	assert_true(Section.decode_section(filled, 0, filled.size(), back).is_ok(), "decodes")
	assert_equal(back.block(JOBS).i32_column(3)[5], 9, "i32 back")
	assert_equal(back.block(CONSTRUCTION).i64_column(0)[331775], 1 << 40, "i64 back")
	assert_equal(back.block(FORAGE).scalar(2), -5, "i32 scalar back")


func test_setters_refuse_wrong_types_and_counts() -> void:
	"""Setters check type and the FIXED count; getters hand out copies."""
	var block: Section.Block = Section.State.new().block(JOBS)
	assert_equal(block.set_i64_column(0, PackedInt64Array([1])).code, Section.REFUSE_FIELD_TYPE,
		"i64 into an i32 field")
	assert_equal(block.set_i32_column(0, PackedInt32Array([1])).code,
		Section.REFUSE_ELEMENT_COUNT, "FIXED(8192) refuses one element")
	assert_equal(block.set_scalar(0, 1).code, Section.REFUSE_FIELD_TYPE, "scalar into a column")
	var copy: PackedInt32Array = block.i32_column(0)
	copy[0] = 99
	assert_equal(block.i32_column(0)[0], 0, "no shared buffer")


func test_extent_wrapper_and_count_refusals_leave_out_untouched() -> void:
	"""Every decode refusal has its exact SAVE_S5_* code and changes nothing."""
	var empty: PackedByteArray = _encode(Section.State.new())
	_assert_refused(empty, -1, empty.size(), Section.REFUSE_NEGATIVE_OFFSET, "negative offset")
	_assert_refused(empty, 0, empty.size() - 1, Section.REFUSE_SECTION_LENGTH, "short length")
	_assert_refused(empty, 1, empty.size(), Section.REFUSE_TRUNCATED, "buffer too short")
	var bytes: PackedByteArray = empty.duplicate()
	bytes.encode_u32(0, 4)
	_assert_refused(bytes, 0, bytes.size(), Section.REFUSE_STORE_COUNT, "store_count 4")
	bytes = empty.duplicate()
	bytes[_block_offset(JOBS) + 4] = 0x6b
	_assert_refused(bytes, 0, bytes.size(), Section.REFUSE_OWNER_KEY, "wrong key byte")
	var head: int = _block_offset(FORAGE) + 4 + "forage".length()
	bytes = empty.duplicate()
	bytes.encode_u32(head, 2)
	_assert_refused(bytes, 0, bytes.size(), Section.REFUSE_OWNER_SCHEMA, "schema 2")
	bytes = empty.duplicate()
	bytes.encode_u64(head + 4, 2)
	_assert_refused(bytes, 0, bytes.size(), Section.REFUSE_PRIMARY_COUNT, "primary 2")
	bytes = empty.duplicate()
	bytes.encode_u64(_count_offset(ORCHARD_HIVE, 1), 30719)
	_assert_refused(bytes, 0, bytes.size(), Section.REFUSE_ELEMENT_COUNT, "FIXED 30719")
	assert_equal(Section.REFUSE_ENDIANNESS, &"SAVE_S5_ENDIANNESS", "the section 5 code family")


func test_register_adapters_covers_every_section_five_owner() -> void:
	"""All five §5 owners register on the production walker and supply typed columns."""
	var walker: Digest.Walker = Digest.production_walker()
	var state: Section.State = _filled_state()
	var refusal: Digest.Refusal = Section.register_adapters(walker, state)
	assert_true(refusal.is_ok(), "register_adapters: %s %s" % [refusal.code, refusal.detail])
	for entry: String in walker.missing_adapter_owners():
		assert_false(entry.begins_with("5:"), "no §5 owner left unregistered: %s" % entry)
	var values: Digest.FieldValues = Digest.FieldValues.new()
	var adapter: Section.Adapter = Section.Adapter.new(state, CONSTRUCTION)
	assert_true(adapter.canonical_field_values(&"_delivered_milli", values), "i64 column")
	assert_equal(values.count, 331776, "at its element count")
	assert_false(adapter.canonical_field_values(&"_nope", values), "unknown field")
	assert_equal(values.refusal, Section.REFUSE_FIELD, "refused by name")
