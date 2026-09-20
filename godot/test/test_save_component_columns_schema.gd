extends "res://test/framework/test_case.gd"
## Structural metadata tests. JSON is read only in tests, never by the production codec.
const Schema := preload("res://scripts/core/save_component_columns_schema.gd")
const LAYOUT: String = "res://../docs/planning/component_columns_layout.json"
const REGISTRY: String = "res://../docs/planning/canonical_state_registry.json"
const GOLDENS: String = "res://../docs/validation/evidence/section4-planning-2026-09-20/independent-wire-goldens.json"

func _json(path: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(path)
	assert_true(not text.is_empty(), "fixture exists: " + path)
	return JSON.parse_string(text) as Dictionary

func test_literal_protocol_totals_and_section_local_versions() -> void:
	assert_true(Schema.schema_refusal().is_ok(), "compiled metadata is internally coherent")
	assert_equal(Schema.STORE_COUNT, 18, "eighteen section4 owners")
	assert_equal(Schema.FIELD_COUNT, 298, "298 frozen columns")
	assert_equal(Schema.SECTION_SCHEMA_VERSION, 2, "later LifeStage composition")
	assert_equal(Schema.SECTION_BYTES, 12947565, "independent complete wire arithmetic")
	assert_equal(Schema.DESCRIPTOR_ROW_COUNT, 193184, "sum of block primaries")
	assert_equal(Schema.CHUNK_BYTES, 65536, "existing streaming bound")
	assert_equal(Schema.owner_key(4), "fishing", "section-local fishing index")
	assert_equal(Schema.owner_version(4), 1, "not Fishing section7 version2")
	assert_equal(Schema.primary_count(0), 1024, "not Buildings section1 tile count")
	assert_equal(Schema.primary_count(5), 128, "not Forage section1 tile count")

func test_every_field_matches_registry_and_explicit_source_count_layout() -> void:
	var layout: Array = _json(LAYOUT)["owners"]
	var registry: Array = _json(REGISTRY)["owners"]
	var section: Array = []
	for raw: Variant in registry:
		if int(raw["section_id"]) == 4: section.append(raw)
	assert_equal(section.size(), 18, "registry section4 owner census")
	assert_equal(layout.size(), 18, "explicit layout owner census")
	var total: int = 0
	for owner: int in 18:
		var declared: Dictionary = section[owner]
		var counts: Dictionary = layout[owner]
		assert_equal(Schema.owner_key(owner), String(declared["owner_key"]), "registry key")
		assert_equal(Schema.owner_version(owner), int(declared["owner_schema_version"]), "registry version")
		var fields: Array = declared["fields"]
		assert_equal(Schema.field_count(owner), fields.size(), "registry field count")
		var buckets: PackedInt32Array = PackedInt32Array([0,0,0])
		for field: int in fields.size():
			var item: Dictionary = fields[field]
			var shape: Dictionary = counts["fields"][field]
			var kind: int = int(item["type_code"])
			var bucket: int = 0 if kind == 0 else (1 if kind == 2 else 2)
			assert_true(Schema.field_valid(owner, field), "every declared field valid")
			assert_equal(Schema.field_key(owner,field), String(item["field_key"]), "registry key/ordinal")
			assert_equal(Schema.field_type(owner,field), kind, "registry signed type")
			assert_equal(Schema.element_count(owner,field), int(shape["count"]), "separate source-proved extent")
			assert_equal(Schema.storage_index(owner,field), buckets[bucket], "index within type bucket")
			assert_equal(Schema.field_width(owner,field), 1 if kind == 0 else (4 if kind == 2 else 8), "type width")
			buckets[bucket] += 1
			total += 1
	assert_equal(total, 298, "no fields omitted or double-counted")

func test_all_offsets_tile_the_exact_independent_framing() -> void:
	var layout: Array = _json(LAYOUT)["owners"]
	var pins: Array = _json(GOLDENS)["fixtures"][0]["owner_framing"]
	var cursor: int = 4
	var values: int = 0
	var rows: int = 0
	for owner: int in 18:
		var block: Dictionary = layout[owner]
		assert_equal(Schema.owner_offset(owner), int(pins[owner]["offset"]), "independent Python owner offset")
		assert_equal(Schema.owner_offset(owner), cursor, "no gap between owner blocks")
		assert_equal(Schema.owner_block_bytes(owner), int(block["block_bytes"]), "whole block byte count")
		assert_equal(Schema.payload_bytes(owner), int(block["payload_bytes"]), "payload includes framing")
		var framing: PackedByteArray = String(pins[owner]["framing_hex"]).hex_decode()
		var position: int = cursor + framing.size()
		for field: int in Schema.field_count(owner):
			assert_equal(Schema.field_count_offset(owner,field), position, "exact element-count prefix")
			assert_equal(Schema.field_value_offset(owner,field), position + 8, "exact value start")
			var size: int = Schema.element_count(owner,field) * Schema.field_width(owner,field)
			position += 8 + size
			values += size
		cursor += Schema.owner_block_bytes(owner)
		assert_equal(position, cursor, "exact block consumption")
		rows += Schema.primary_count(owner)
	assert_equal(cursor, 12947565, "exact section EOF")
	assert_equal(values, 12944480, "value bytes exclude framing")
	assert_equal(rows, 193184, "descriptor is sum of primaries")

func test_independent_children_remain_distinct_and_exact() -> void:
	var expected: Array[PackedInt64Array] = []
	for owner: int in 18: expected.append(PackedInt64Array())
	expected[0] = PackedInt64Array([16384,81920])
	expected[3] = PackedInt64Array([4096])
	expected[7] = PackedInt64Array([512])
	expected[10] = PackedInt64Array([1024])
	var count: int = 0
	for owner: int in 18:
		assert_equal(Schema.child_extent_count(owner), expected[owner].size(), "explicit child count, including zero")
		for child: int in expected[owner].size():
			assert_true(Schema.child_valid(owner,child), "declared child valid")
			assert_equal(Schema.child_extent(owner,child), expected[owner][child], "child order and fixed count")
			count += 1
		assert_false(Schema.child_valid(owner,expected[owner].size()), "no undeclared child")
	assert_equal(count,5,"five independent extents across four owners")

func _field(owner: int, key: String) -> int:
	for field: int in Schema.field_count(owner):
		if Schema.field_key(owner,field) == key: return field
	assert_true(false, "declared fixture field exists: " + key)
	return -1

func test_fixed_strides_are_not_independent_child_extents() -> void:
	var cases: Array = [[4,"_stock_present",96],[5,"_patch_present",640],
		[3,"_rotation_ids",384],[9,"_need_value",2560],
		[12,"_skill_xp",6144],[11,"_job_priority",6144],
		[16,"_xp_remainder",6144],[14,"_hourly_activity",12288]]
	for entry: Array in cases:
		var owner: int = int(entry[0])
		var field: int = _field(owner,String(entry[1]))
		if field >= 0: assert_equal(Schema.element_count(owner,field), int(entry[2]), "literal fixed stride")

func test_invalid_lookup_indices_have_separate_validity() -> void:
	for owner: int in PackedInt32Array([-1,18,2147483647]):
		assert_false(Schema.owner_valid(owner), "invalid owner never inferred from returned count")
		assert_false(Schema.field_valid(owner,0), "invalid owner's field refuses")
		assert_false(Schema.child_valid(owner,0), "invalid owner's child refuses")
	for owner: int in 18:
		assert_true(Schema.owner_valid(owner), "valid owner")
		assert_false(Schema.field_valid(owner,-1), "negative ordinal")
		assert_false(Schema.field_valid(owner,Schema.field_count(owner)), "one-past field")
		assert_false(Schema.child_valid(owner,-1), "negative child")
