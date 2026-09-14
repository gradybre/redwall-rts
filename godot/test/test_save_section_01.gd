extends "res://test/framework/test_case.gd"
## R-WORLD-S1-001: section 1 WORLD's nine-owner wire contract, its validators and its restore.
##
## EVERY NUMBER BELOW IS TRANSCRIBED FROM THE RULING, NOT READ OUT OF `save_section_01.gd`. The
## module derives its offsets from its own field table, so a test that asked the module where a
## field starts would move with any edit to that table and prove nothing. The literals here are
## the independent anchor: §3's owner table, §4's per-field count/value offsets and §8's block
## offsets and section arithmetic.
##
## THE BYTE VECTOR IS READ AT ABSOLUTE OFFSETS WITH `PackedByteArray.decode_*`, never through the
## codec that wrote it. Section 7's `_read_block()` defect and section 9's ordinal swap both
## survived because the check derived its expectation from the thing it was checking; reading the
## wire directly is what closes that.

const Section := preload("res://scripts/core/save_section_01.gd")
const WorldRuntime := preload("res://scripts/core/save_section_world_runtime.gd")
const SaveHeader := preload("res://scripts/core/save_header.gd")
const Digest := preload("res://scripts/core/canonical_state_hash.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")
const JobsScript := preload("res://scripts/core/jobs.gd")
const BuildingsScript := preload("res://scripts/core/buildings.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")
const ForageScript := preload("res://scripts/core/forage.gd")
const FishingScript := preload("res://scripts/core/fishing.gd")
const ResourceNodesScript := preload("res://scripts/core/resource_nodes.gd")
const SpatialWorldScript := preload("res://scripts/core/spatial_world.gd")
const WeatherScript := preload("res://scripts/core/weather.gd")
const WorldInitScript := preload("res://scripts/core/world_init.gd")
const RngScript := preload("res://scripts/core/rng.gd")
const SimClockScript := preload("res://scripts/core/sim_clock.gd")

## R-WORLD-S1-001 §3's owner table, transcribed.
const RULING_OWNER_KEYS: Array[String] = ["buildings", "entity_directory", "farming", "forage",
	"resource_nodes", "spatial_world", "weather", "world_init", "world_runtime"]
const RULING_OWNER_SCHEMAS: Array[int] = [1, 1, 1, 1, 2, 1, 1, 1, 1]
const RULING_PRIMARY_COUNTS: Array[int] = [16384, 1, 16384, 16384, 16384, 262144, 1, 16384, 1]
const RULING_WRAPPER_BYTES: Array[int] = [33, 40, 31, 30, 38, 37, 31, 34, 37]
const RULING_PAYLOAD_BYTES: Array[int] = [196632, 4, 737360, 65544, 65544, 2621484, 64, 65697, 80]

## R-WORLD-S1-001 §8's block and payload offsets, transcribed.
const RULING_BLOCK_OFFSETS: Array[int] = [48, 196713, 196757, 934148, 999722, 1065304, 3686825,
	3686920, 3752651]
const RULING_PAYLOAD_OFFSETS: Array[int] = [81, 196753, 196788, 934178, 999760, 1065341, 3686856,
	3686954, 3752688]
const RULING_END_OFFSETS: Array[int] = [196713, 196757, 934148, 999722, 1065304, 3686825, 3686920,
	3752651, 3752768]

const RULING_SECTION_BYTES: int = 3752768
const RULING_DESCRIPTOR_ROW_COUNT: int = 344067
const RULING_FIRST_SECTION_OFFSET: int = 1216
const RULING_SECTION_2_OFFSET: int = 3753984
const RULING_SECTION_SCHEMA_VERSION: int = 3
const RULING_STORE_COUNT: int = 9
const RULING_COUNT_PREFIX_TOTAL: int = 248
const RULING_STORED_FIELD_COUNT: int = 44
const RULING_CANONICAL_RECORD_COUNT: int = 36

const SCENARIO_VERSION: int = 7
const GENERATOR_SCHEMA: int = 3
const WORLD_SEED: int = 20260914
const COMPLETED_TICK: int = 54000
const CURSOR: int = 41

var _residents: ResidentsScript = null
var _jobs: JobsScript = null
var _directory: EntityDirectory = null
var _stores: Section.Stores = null
var _runtime: WorldRuntime.Record = null
var _state: Section.State = null


func before_each() -> void:
	"""Compose one fresh settlement, every store sharing a single entity directory."""
	_residents = ResidentsScript.new()
	_jobs = JobsScript.new(_residents)
	_directory = _jobs.directory()
	_stores = Section.Stores.new()
	_stores.directory = _directory
	_stores.buildings = BuildingsScript.new(_directory)
	_stores.farming = FarmingScript.new(_directory)
	_stores.forage = ForageScript.new(_directory, _jobs)
	_stores.resource_nodes = ResourceNodesScript.new(_directory)
	_stores.spatial_world = SpatialWorldScript.new()
	_stores.weather = WeatherScript.new()
	_stores.world_init = WorldInitScript.new(_directory, _stores.resource_nodes, _stores.forage,
		FishingScript.new(_directory, _stores.forage, _jobs), RngScript.new(), _stores.farming)
	_runtime = _baseline_runtime()
	_state = Section.State.new()


func _baseline_runtime() -> WorldRuntime.Record:
	"""A WorldRuntime record with a seeded world and non-zero debt and counters."""
	var record: WorldRuntime.Record = WorldRuntime.Record.new()
	record.completed_tick = COMPLETED_TICK
	record.world_seed = WORLD_SEED
	record.rng_seeded = true
	record.requested_speed = SimClockScript.SPEED_DOUBLE
	record.pause_mask = SimClockScript.PLAYER
	record.debt = 2500001
	for index: int in WorldRuntime.COUNTER_COUNT:
		record.counters[index] = index + 1
	return record


func _digest_bytes() -> PackedByteArray:
	"""A 32-byte authored-map digest fixture. Its VALUE belongs to the map producer, not here."""
	var digest: PackedByteArray = PackedByteArray()
	digest.resize(Section.AUTHORED_MAP_DIGEST_BYTES)
	for index: int in Section.AUTHORED_MAP_DIGEST_BYTES:
		digest[index] = (index * 7 + 3) % 256
	return digest


func _captured() -> Section.State:
	"""Capture the composed stores into `_state` and assert the capture succeeded."""
	var refusal: SaveHeader.Refusal = Section.capture_into(_stores, _runtime, SCENARIO_VERSION,
		GENERATOR_SCHEMA, _digest_bytes(), _state)
	assert_true(refusal.is_ok(), "capture_into: %s %s" % [refusal.code, refusal.detail])
	_state.next_persistent_id = CURSOR
	return _state


func _encoded(state: Section.State) -> PackedByteArray:
	"""Encode a section and assert it succeeded, returning its bytes."""
	var out: WorldRuntime.EncodeResult = WorldRuntime.EncodeResult.new()
	assert_true(Section.encode_section(state, out),
		"encode_section: %s %s" % [out.refusal, out.detail])
	return out.bytes


func _decoded_code(bytes: PackedByteArray) -> StringName:
	"""Decode a section expecting a refusal, returning its code."""
	var back: Section.State = Section.State.new()
	return Section.decode_section(bytes, 0, bytes.size(), back).code


func _fingerprint(bytes: PackedByteArray) -> String:
	"""SHA-256 hex of a byte run, so a mismatch reports 64 characters and not 3.75 MB.

	A failing `assert_equal` prints both operands. On a multi-megabyte column that buries the one
	line a reader needs under a wall of integers -- it produced a 26 MB log the first time a
	mutant was killed here -- so every large comparison below goes through this.
	"""
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


func _int32_fingerprint(column: PackedInt32Array) -> String:
	"""SHA-256 hex of an i32 column."""
	return _fingerprint(column.to_byte_array())


func _int64_fingerprint(column: PackedInt64Array) -> String:
	"""SHA-256 hex of an i64 column."""
	return _fingerprint(column.to_byte_array())


# --- the compiled table against the ruling ---------------------------------------------------

func test_the_nine_owners_their_versions_and_their_counts_are_the_ruled_ones() -> void:
	"""§3's owner table, key for key, in the strict ASCII order blocks must appear in."""
	assert_equal(Section.SECTION_ID, 1, "section id")
	assert_equal(Section.SECTION_SCHEMA_VERSION, RULING_SECTION_SCHEMA_VERSION,
		"R-WORLD-S1-001 takes section 1 to schema 3")
	assert_equal(Section.OWNER_COUNT, RULING_STORE_COUNT, "exactly nine owners")
	var previous: String = ""
	for owner: int in RULING_STORE_COUNT:
		assert_equal(Section.owner_key_of(owner), RULING_OWNER_KEYS[owner], "owner key %d" % owner)
		assert_true(RULING_OWNER_KEYS[owner] > previous, "'%s' follows '%s' in ASCII order"
			% [RULING_OWNER_KEYS[owner], previous])
		previous = RULING_OWNER_KEYS[owner]
		assert_equal(Section.OWNER_SCHEMA_VERSIONS[owner], RULING_OWNER_SCHEMAS[owner],
			"owner schema version of '%s'" % RULING_OWNER_KEYS[owner])
		assert_equal(Section.OWNER_PRIMARY_COUNTS[owner], RULING_PRIMARY_COUNTS[owner],
			"primary_count of '%s'" % RULING_OWNER_KEYS[owner])


func test_only_resource_nodes_moved_to_owner_schema_two() -> void:
	"""The version bump is scoped to (section 1, resource_nodes) and to nothing else."""
	for owner: int in RULING_STORE_COUNT:
		var expected: int = 2 if RULING_OWNER_KEYS[owner] == "resource_nodes" else 1
		assert_equal(Section.OWNER_SCHEMA_VERSIONS[owner], expected,
			"'%s' owner schema version" % RULING_OWNER_KEYS[owner])


func test_every_wrapper_block_and_payload_offset_matches_the_ruling() -> void:
	"""§8's offset table: `24 + len(key)` wrappers, blocks tiling with no gap or overlap."""
	for owner: int in RULING_STORE_COUNT:
		assert_equal(Section.wrapper_bytes_of(owner), RULING_WRAPPER_BYTES[owner],
			"wrapper bytes of '%s'" % RULING_OWNER_KEYS[owner])
		assert_equal(Section.OWNER_PAYLOAD_BYTES[owner], RULING_PAYLOAD_BYTES[owner],
			"payload bytes of '%s'" % RULING_OWNER_KEYS[owner])
		assert_equal(Section.block_offset_of(owner), RULING_BLOCK_OFFSETS[owner],
			"block offset of '%s'" % RULING_OWNER_KEYS[owner])
		assert_equal(Section.payload_offset_of(owner), RULING_PAYLOAD_OFFSETS[owner],
			"payload offset of '%s'" % RULING_OWNER_KEYS[owner])
		assert_equal(RULING_BLOCK_OFFSETS[owner] + RULING_WRAPPER_BYTES[owner]
			+ RULING_PAYLOAD_BYTES[owner], RULING_END_OFFSETS[owner],
			"'%s' ends where the ruling says" % RULING_OWNER_KEYS[owner])


func test_the_section_arithmetic_is_the_rulings_and_the_table_agrees_with_itself() -> void:
	"""§8: 3752768 bytes, descriptor row_count 344067, first offset 1216, §2 at 3753984."""
	assert_equal(Section.SECTION_BYTES, RULING_SECTION_BYTES, "section 1 length")
	assert_equal(Section.DESCRIPTOR_ROW_COUNT, RULING_DESCRIPTOR_ROW_COUNT, "descriptor row_count")
	assert_equal(Section.FIRST_SECTION_OFFSET, RULING_FIRST_SECTION_OFFSET, "first body offset")
	assert_equal(Section.SECTION_2_OFFSET, RULING_SECTION_2_OFFSET, "section 2 offset")
	var wrappers: int = 0
	var payloads: int = 0
	var rows: int = 0
	for owner: int in RULING_STORE_COUNT:
		wrappers += RULING_WRAPPER_BYTES[owner]
		payloads += RULING_PAYLOAD_BYTES[owner]
		rows += RULING_PRIMARY_COUNTS[owner]
	assert_equal(wrappers, 311, "the nine wrappers total 311 bytes")
	assert_equal(payloads, 3752409, "the nine payloads total 3752409 bytes")
	assert_equal(44 + 4 + wrappers + payloads, RULING_SECTION_BYTES, "and the section is their sum")
	assert_equal(rows, RULING_DESCRIPTOR_ROW_COUNT, "row_count is the SUM of the primary counts")
	var table: SaveHeader.Refusal = Section.table_refusal()
	assert_true(table.is_ok(), "the compiled table is self-consistent: %s" % table.detail)
	assert_true(Section.little_endian_refusal().is_ok(), "the host is little-endian")


func test_resource_nodes_declares_one_field_and_the_three_scratch_arrays_are_absent() -> void:
	"""R-WORLD-S1-001 §7: the deposit arrays have no wire representation at all."""
	assert_equal(Section.field_keys_of(Section.OWNER_RESOURCE_NODES),
		["_resource_slot"] as Array[String], "the sole declared field")
	assert_equal(Section.OWNER_PAYLOAD_BYTES[Section.OWNER_RESOURCE_NODES], 65544,
		"8 count bytes plus 16384 i32 values, and nothing for the scratch")
	for key: String in ["_deposit_tiles", "_deposit_ref_slot", "_deposit_ref_generation"]:
		assert_equal(Section.field_keys_of(Section.OWNER_RESOURCE_NODES).find(key), -1,
			"'%s' is not a declared section 1 field" % key)


func test_every_declared_field_lands_at_the_rulings_count_and_value_offsets() -> void:
	"""§4's exhaustive per-field tables, ordinal by ordinal, for all seven ordinary owners."""
	var expected: Dictionary = _ruling_field_offsets()
	for owner: int in RULING_STORE_COUNT:
		if not expected.has(RULING_OWNER_KEYS[owner]):
			continue
		var rows: Array = expected[RULING_OWNER_KEYS[owner]] as Array
		assert_equal(Section.field_keys_of(owner).size(), rows.size(),
			"'%s' field count" % RULING_OWNER_KEYS[owner])
		for ordinal: int in rows.size():
			var row: Array = rows[ordinal] as Array
			assert_equal(Section.field_keys_of(owner)[ordinal], String(row[0]),
				"'%s' ordinal %d key" % [RULING_OWNER_KEYS[owner], ordinal])
			assert_equal(Section.field_types_of(owner)[ordinal], int(row[1]),
				"'%s.%s' type code" % [RULING_OWNER_KEYS[owner], row[0]])
			assert_equal(Section.field_counts_of(owner)[ordinal], int(row[2]),
				"'%s.%s' element count" % [RULING_OWNER_KEYS[owner], row[0]])
			assert_equal(Section.field_count_offset_of(owner, ordinal), int(row[3]),
				"'%s.%s' count offset" % [RULING_OWNER_KEYS[owner], row[0]])
			assert_equal(Section.field_value_offset_of(owner, ordinal), int(row[4]),
				"'%s.%s' value offset" % [RULING_OWNER_KEYS[owner], row[0]])


func _ruling_field_offsets() -> Dictionary:
	"""§4's tables verbatim: key, type code, element_count, count offset, values offset."""
	return {
		"buildings": [["_building_slot", 2, 16384, 0, 8], ["_room_slot", 2, 16384, 65544, 65552],
			["_furniture_slot", 2, 16384, 131088, 131096]],
		"farming": [["_tile_fertility", 2, 16384, 0, 8],
			["_tile_last_family", 2, 16384, 65544, 65552],
			["_tile_family_streak", 2, 16384, 131088, 131096],
			["_tile_last_legume_day", 2, 16384, 196632, 196640],
			["_tile_compost_season", 2, 16384, 262176, 262184],
			["_tile_active_plot_row", 2, 16384, 327720, 327728],
			["_tile_orchard_row", 2, 16384, 393264, 393272],
			["_tile_ripe_tick", 4, 16384, 458808, 458816],
			["_tile_growth_remainder", 4, 16384, 589888, 589896],
			["_tile_tended_today", 0, 16384, 720968, 720976]],
		"forage": [["_tile_link_head", 2, 16384, 0, 8]],
		"resource_nodes": [["_resource_slot", 2, 16384, 0, 8]],
		"spatial_world": [["_map_revision", 2, 1, 0, 8], ["_walkable", 0, 262144, 12, 20],
			["_layer", 0, 262144, 262164, 262172], ["_terrain", 2, 262144, 524316, 524324],
			["_height_units", 2, 262144, 1572900, 1572908]],
		"weather": [["_row", 2, 8, 0, 8], ["_row64", 4, 2, 40, 48]],
		"world_init": [["_published", 0, 1, 0, 8], ["_published_seed", 2, 1, 9, 17],
			["_terrain", 0, 16384, 21, 29], ["_soil", 0, 16384, 16413, 16421],
			["_basin", 0, 16384, 32805, 32813], ["_cleared", 0, 16384, 49197, 49205],
			["_basin_ref_slot", 2, 7, 65589, 65597],
			["_basin_ref_generation", 2, 7, 65625, 65633],
			["_basin_danger", 2, 7, 65661, 65669]],
	}


func test_the_section_carries_forty_four_stored_fields_and_thirty_six_records() -> void:
	"""§8: 44 declared stored fields, 36 canonical field records, 31 count prefixes, 248 bytes."""
	var stored: int = 0
	var prefixes: int = 0
	for owner: int in RULING_STORE_COUNT:
		var ordinary: int = Section.field_keys_of(owner).size()
		prefixes += ordinary
		stored += ordinary
	stored += 1 + 12
	assert_equal(prefixes, 31, "the seven ordinary owners declare 31 count prefixes")
	assert_equal(prefixes * 8, RULING_COUNT_PREFIX_TOTAL, "248 structural count bytes")
	assert_equal(stored, RULING_STORED_FIELD_COUNT, "44 declared stored fields")
	assert_equal(stored - 8, RULING_CANONICAL_RECORD_COUNT,
		"36 canonical records: world_runtime excludes the tick, debt and six counters")


# --- the encoded bytes, read at absolute offsets ---------------------------------------------

func test_the_encoded_section_is_exactly_the_ruled_length() -> void:
	"""One length, pinned, so a field-table edit cannot quietly resize the section."""
	assert_equal(_encoded(_captured()).size(), RULING_SECTION_BYTES, "encoded section length")


func test_the_provenance_prefix_and_store_count_sit_at_their_absolute_offsets() -> void:
	"""Bytes 0..47, read straight out of the buffer rather than back through the codec."""
	var bytes: PackedByteArray = _encoded(_captured())
	assert_equal(bytes.decode_u32(0), SCENARIO_VERSION, "scenario_version at offset 0")
	assert_equal(bytes.decode_s32(4), WORLD_SEED, "effective_seed at offset 4")
	assert_equal(bytes.decode_u32(8), GENERATOR_SCHEMA, "map_generator_schema at offset 8")
	assert_equal(bytes.slice(12, 44), _digest_bytes(), "the 32-byte authored map digest at 12")
	assert_equal(bytes.decode_u32(44), RULING_STORE_COUNT, "store_count = 9 at offset 44")


func test_every_wrapper_is_pinned_at_its_absolute_offset() -> void:
	"""Key length, key text, schema, primary_count and payload length, per block, from the wire."""
	var bytes: PackedByteArray = _encoded(_captured())
	for owner: int in RULING_STORE_COUNT:
		var at: int = RULING_BLOCK_OFFSETS[owner]
		var key: String = RULING_OWNER_KEYS[owner]
		assert_equal(bytes.decode_u32(at), key.length(), "'%s' key byte count" % key)
		assert_equal(bytes.slice(at + 4, at + 4 + key.length()).get_string_from_utf8(), key,
			"'%s' key text at offset %d" % [key, at + 4])
		var numbers: int = at + 4 + key.length()
		assert_equal(bytes.decode_u32(numbers), RULING_OWNER_SCHEMAS[owner],
			"'%s' owner schema version on the wire" % key)
		assert_equal(bytes.decode_u64(numbers + 4), RULING_PRIMARY_COUNTS[owner],
			"'%s' primary_count on the wire" % key)
		assert_equal(bytes.decode_u64(numbers + 12), RULING_PAYLOAD_BYTES[owner],
			"'%s' payload_byte_length on the wire" % key)
		assert_equal(numbers + 20, RULING_PAYLOAD_OFFSETS[owner], "'%s' payload starts there" % key)


func test_every_element_count_prefix_is_pinned_at_its_absolute_offset() -> void:
	"""All 31 `element_count:u64` prefixes, at payload offset + the ruling's count offset."""
	var bytes: PackedByteArray = _encoded(_captured())
	var expected: Dictionary = _ruling_field_offsets()
	var checked: int = 0
	for owner: int in RULING_STORE_COUNT:
		if not expected.has(RULING_OWNER_KEYS[owner]):
			continue
		for row: Variant in expected[RULING_OWNER_KEYS[owner]] as Array:
			var entry: Array = row as Array
			var at: int = RULING_PAYLOAD_OFFSETS[owner] + int(entry[3])
			assert_equal(bytes.decode_u64(at), int(entry[2]),
				"'%s.%s' element_count on the wire" % [RULING_OWNER_KEYS[owner], entry[0]])
			checked += 1
	assert_equal(checked, 31, "all 31 count prefixes were read")


func test_the_two_fixed_format_payloads_carry_no_count_prefix() -> void:
	"""`entity_directory` is four cursor bytes and `world_runtime` is its unchanged 80."""
	var bytes: PackedByteArray = _encoded(_captured())
	assert_equal(bytes.decode_u32(RULING_PAYLOAD_OFFSETS[Section.OWNER_ENTITY_DIRECTORY]), CURSOR,
		"the cursor is the whole entity_directory payload")
	var runtime_at: int = RULING_PAYLOAD_OFFSETS[Section.OWNER_WORLD_RUNTIME]
	assert_equal(bytes.decode_s64(runtime_at), COMPLETED_TICK, "completed tick at runtime + 0")
	assert_equal(bytes.decode_s32(runtime_at + 8), WORLD_SEED, "world seed at runtime + 8")
	assert_equal(bytes.decode_u8(runtime_at + 12), 1, "seeded flag at runtime + 12")
	assert_equal(bytes.slice(runtime_at + 13, runtime_at + 16).hex_encode(), "000000",
		"the three reserved bytes are zero")
	assert_equal(bytes.decode_s64(runtime_at + 24), 2500001, "debt restored exactly at + 24")


func test_the_weather_block_is_one_aggregate_row_of_eight_and_two() -> void:
	"""Primary_count 1, not 8: the eight i32 values are columns of one row, not eight entities."""
	var bytes: PackedByteArray = _encoded(_captured())
	var at: int = RULING_PAYLOAD_OFFSETS[Section.OWNER_WEATHER]
	assert_equal(bytes.decode_u64(RULING_BLOCK_OFFSETS[Section.OWNER_WEATHER] + 4 + 7 + 4), 1,
		"weather declares primary_count 1")
	assert_equal(bytes.decode_u64(at), 8, "the i32 row declares eight elements")
	assert_equal(bytes.decode_u64(at + 40), 2, "the i64 row declares two elements")
	assert_equal(RULING_PAYLOAD_BYTES[Section.OWNER_WEATHER], 64, "64 payload bytes in total")


func test_the_mixed_grid_owners_declare_grid_primary_counts_not_singletons() -> void:
	"""`world_init` counts tiles and `spatial_world` counts cells, despite their scalar fields."""
	var bytes: PackedByteArray = _encoded(_captured())
	var world_at: int = RULING_BLOCK_OFFSETS[Section.OWNER_WORLD_INIT] + 4 + 10 + 4
	assert_equal(bytes.decode_u64(world_at), 16384, "world_init counts 16384 exterior tiles")
	assert_equal(bytes.decode_u64(RULING_PAYLOAD_OFFSETS[Section.OWNER_WORLD_INIT]), 1,
		"even though its first field is a one-element scalar")
	var spatial_at: int = RULING_BLOCK_OFFSETS[Section.OWNER_SPATIAL_WORLD] + 4 + 13 + 4
	assert_equal(bytes.decode_u64(spatial_at), 262144, "spatial_world counts 262144 cells")
	assert_equal(bytes.decode_u64(RULING_PAYLOAD_OFFSETS[Section.OWNER_SPATIAL_WORLD]), 1,
		"even though its first field is the one-element revision")


func test_the_module_declares_no_float_path() -> void:
	"""ARCH-AUTH-002: authoritative state is integer, and this codec never touches a float."""
	var file: FileAccess = FileAccess.open("res://scripts/core/save_section_01.gd",
		FileAccess.READ)
	assert_not_null(file, "the source is readable")
	var source: String = file.get_as_text()
	file.close()
	assert_false(source.contains("float"), "no float declaration")
	assert_false(source.contains("PackedFloat"), "no float column")


# --- round trip ---------------------------------------------------------------------------------

func _load_boundary_values(state: Section.State) -> void:
	"""Fill every owner with non-default data and the boundary sentinels the ruling names."""
	state.building_slot[0] = -1
	state.building_slot[1] = 1023
	state.room_slot[2] = 16383
	state.furniture_slot[3] = 81919
	state.farming.fertility[0] = 0
	state.farming.fertility[1] = 10000
	state.farming.last_family[1] = 4
	state.farming.family_streak[1] = 2147483647
	state.farming.last_legume_day[2] = 2147483647
	state.farming.compost_season[3] = -1
	state.farming.compost_season[4] = 2147483647
	state.farming.active_plot_row[5] = 4095
	state.farming.orchard_row[6] = 1023
	state.farming.ripe_tick[7] = -1
	state.farming.ripe_tick[8] = 9223372036854770807
	state.farming.growth_remainder[9] = 999999
	state.farming.tended_today[10] = 1
	state.tile_link_head[11] = 16383
	state.resource_slot[12] = 4095
	state.map_revision = 2147483647
	state.walkable[13] = 1
	state.cell_terrain[14] = 3
	state.height_units[15] = -2147483648
	state.height_units[16] = 2147483647
	_load_weather_and_map(state)


func _load_weather_and_map(state: Section.State) -> void:
	"""A scheduled hard freeze in a winter, a disclosed forecast, and a published estuary map."""
	state.weather_row[WeatherScript.COL_EVENT] = WeatherScript.EVENT_HARD_FREEZE
	state.weather_row[WeatherScript.COL_START_DAY] = 6
	state.weather_row[WeatherScript.COL_DURATION_DAYS] = 3
	state.weather_row[WeatherScript.COL_TEMPERATURE_TENTHS] = -120
	state.weather_row[WeatherScript.COL_RAIN] = 3200
	state.weather_row[WeatherScript.COL_FORECAST_0] = WeatherScript.EVENT_CALM_DAYS
	state.weather_row[WeatherScript.COL_FORECAST_1] = 6
	state.weather_row[WeatherScript.COL_FORECAST_2] = 2
	state.weather_row64[WeatherScript.COL64_SCHEDULED_ABSOLUTE_SEASON] = 3
	state.weather_row64[WeatherScript.COL64_FORECAST_ABSOLUTE_SEASON] = 4
	state.published = 1
	state.published_seed = WORLD_SEED
	state.world_map.terrain[17] = WorldInitScript.TERRAIN_RIVER
	state.world_map.soil[18] = WorldInitScript.SOIL_NONE
	state.world_map.soil[19] = WorldInitScript.SOIL_SAND
	state.world_map.basin[20] = WorldInitScript.NO_BASIN
	state.world_map.cleared[21] = 1
	for index: int in WorldInitScript.BASIN_COUNT:
		state.world_map.basin[100 + index] = index
		state.world_map.basin_ref_slot[index] = 30 + index
		state.world_map.basin_ref_generation[index] = 1 + index
		state.world_map.basin_danger[index] = index % 4


func _assert_same_state(back: Section.State, state: Section.State) -> void:
	"""Every column and scalar of two sections must be equal, field for field."""
	assert_equal(back.scenario_version, state.scenario_version, "scenario_version")
	assert_equal(back.effective_seed, state.effective_seed, "effective_seed")
	assert_equal(back.map_generator_schema, state.map_generator_schema, "map_generator_schema")
	assert_equal(_fingerprint(back.authored_map_digest), _fingerprint(state.authored_map_digest), "authored_map_digest")
	assert_equal(back.next_persistent_id, state.next_persistent_id, "next_persistent_id")
	assert_equal(_int32_fingerprint(back.building_slot), _int32_fingerprint(state.building_slot), "_building_slot")
	assert_equal(_int32_fingerprint(back.room_slot), _int32_fingerprint(state.room_slot), "_room_slot")
	assert_equal(_int32_fingerprint(back.furniture_slot), _int32_fingerprint(state.furniture_slot), "_furniture_slot")
	assert_equal(_int32_fingerprint(back.tile_link_head), _int32_fingerprint(state.tile_link_head), "_tile_link_head")
	assert_equal(_int32_fingerprint(back.resource_slot), _int32_fingerprint(state.resource_slot), "_resource_slot")
	assert_equal(back.map_revision, state.map_revision, "_map_revision")
	assert_equal(_fingerprint(back.walkable), _fingerprint(state.walkable), "_walkable")
	assert_equal(_fingerprint(back.layer), _fingerprint(state.layer), "_layer")
	assert_equal(_int32_fingerprint(back.cell_terrain), _int32_fingerprint(state.cell_terrain), "spatial _terrain")
	assert_equal(_int32_fingerprint(back.height_units), _int32_fingerprint(state.height_units), "_height_units")
	assert_equal(_int32_fingerprint(back.weather_row), _int32_fingerprint(state.weather_row), "_row")
	assert_equal(_int64_fingerprint(back.weather_row64),
		_int64_fingerprint(state.weather_row64), "_row64")
	assert_equal(back.published, state.published, "_published")
	assert_equal(back.published_seed, state.published_seed, "_published_seed")
	_assert_same_farming(back, state)
	_assert_same_map(back, state)


func _assert_same_farming(back: Section.State, state: Section.State) -> void:
	"""All ten TileHistory columns."""
	assert_equal(_int32_fingerprint(back.farming.fertility),
		_int32_fingerprint(state.farming.fertility), "_tile_fertility")
	assert_equal(_int32_fingerprint(back.farming.last_family),
		_int32_fingerprint(state.farming.last_family), "_tile_last_family")
	assert_equal(_int32_fingerprint(back.farming.family_streak),
		_int32_fingerprint(state.farming.family_streak), "_tile_family_streak")
	assert_equal(_int32_fingerprint(back.farming.last_legume_day),
		_int32_fingerprint(state.farming.last_legume_day),
		"_tile_last_legume_day")
	assert_equal(_int32_fingerprint(back.farming.compost_season),
		_int32_fingerprint(state.farming.compost_season), "_tile_compost_season")
	assert_equal(_int32_fingerprint(back.farming.active_plot_row),
		_int32_fingerprint(state.farming.active_plot_row),
		"_tile_active_plot_row")
	assert_equal(_int32_fingerprint(back.farming.orchard_row),
		_int32_fingerprint(state.farming.orchard_row), "_tile_orchard_row")
	assert_equal(_int64_fingerprint(back.farming.ripe_tick),
		_int64_fingerprint(state.farming.ripe_tick), "_tile_ripe_tick")
	assert_equal(_int64_fingerprint(back.farming.growth_remainder),
		_int64_fingerprint(state.farming.growth_remainder),
		"_tile_growth_remainder")
	assert_equal(_fingerprint(back.farming.tended_today),
		_fingerprint(state.farming.tended_today), "_tile_tended_today")


func _assert_same_map(back: Section.State, state: Section.State) -> void:
	"""All seven world_init map columns."""
	assert_equal(_fingerprint(back.world_map.terrain),
		_fingerprint(state.world_map.terrain), "world_init _terrain")
	assert_equal(_fingerprint(back.world_map.soil),
		_fingerprint(state.world_map.soil), "_soil")
	assert_equal(_fingerprint(back.world_map.basin),
		_fingerprint(state.world_map.basin), "_basin")
	assert_equal(_fingerprint(back.world_map.cleared),
		_fingerprint(state.world_map.cleared), "_cleared")
	assert_equal(_int32_fingerprint(back.world_map.basin_ref_slot),
		_int32_fingerprint(state.world_map.basin_ref_slot), "_basin_ref_slot")
	assert_equal(_int32_fingerprint(back.world_map.basin_ref_generation),
		_int32_fingerprint(state.world_map.basin_ref_generation),
		"_basin_ref_generation")
	assert_equal(_int32_fingerprint(back.world_map.basin_danger),
		_int32_fingerprint(state.world_map.basin_danger), "_basin_danger")


func test_every_owner_round_trips_with_boundary_sentinels_intact() -> void:
	"""Non-default data across all nine owners, including -1, 255, 0/1 and the extreme rows."""
	var state: Section.State = _captured()
	_load_boundary_values(state)
	var back: Section.State = Section.State.new()
	var refusal: SaveHeader.Refusal = Section.decode_section(_encoded(state), 0,
		RULING_SECTION_BYTES, back)
	assert_true(refusal.is_ok(), "decode_section: %s %s" % [refusal.code, refusal.detail])
	_assert_same_state(back, state)
	assert_equal(back.runtime.completed_tick, state.runtime.completed_tick, "completed tick")
	assert_equal(back.runtime.debt, 2500001, "debt survives exactly, unscaled and unrounded")
	for index: int in WorldRuntime.COUNTER_COUNT:
		assert_equal(back.runtime.counters[index], index + 1, "counter %d" % index)


func test_a_decoded_section_re_encodes_to_the_same_bytes() -> void:
	"""Decode then re-encode is the identity on the wire, which a lossy column would break."""
	var state: Section.State = _captured()
	_load_boundary_values(state)
	var bytes: PackedByteArray = _encoded(state)
	var back: Section.State = Section.State.new()
	assert_true(Section.decode_section(bytes, 0, RULING_SECTION_BYTES, back).is_ok(), "decodes")
	assert_equal(_fingerprint(_encoded(back)), _fingerprint(bytes),
		"re-encoding the decoded section is byte-identical")


func test_the_section_decodes_at_the_offset_a_real_file_puts_it_at() -> void:
	"""First body offset 1216, with the section preceded by header-shaped filler."""
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(RULING_FIRST_SECTION_OFFSET)
	bytes.append_array(_encoded(_captured()))
	assert_equal(bytes.size(), RULING_SECTION_2_OFFSET, "section 2 begins at 3753984")
	var back: Section.State = Section.State.new()
	var refusal: SaveHeader.Refusal = Section.decode_section(bytes, RULING_FIRST_SECTION_OFFSET,
		RULING_SECTION_BYTES, back)
	assert_true(refusal.is_ok(), "decode at 1216: %s %s" % [refusal.code, refusal.detail])
	assert_equal(back.next_persistent_id, CURSOR, "and the cursor came back")


# --- refusals -------------------------------------------------------------------------------------

func test_a_store_count_other_than_nine_is_refused() -> void:
	"""Eight owners is not a permitted target variant, and neither is ten."""
	for wrong: int in [0, 1, 2, 8, 10, 4294967295]:
		var bytes: PackedByteArray = _encoded(_captured())
		bytes.encode_u32(44, wrong)
		assert_equal(_decoded_code(bytes), Section.REFUSE_STORE_COUNT,
			"store_count %d refuses" % wrong)


func test_two_owner_keys_swapped_in_place_are_refused() -> void:
	"""The killer case: both blocks are the same width, so only the KEY at a fixed offset differs.

	`forage` and `weather` are both seven-letter keys, so swapping their text leaves every length
	in the file consistent. A decoder that walked a cursor and dispatched on whatever key it found
	would accept this; reading the key at the block's COMPILED offset does not.
	"""
	var bytes: PackedByteArray = _encoded(_captured())
	var forage_at: int = RULING_BLOCK_OFFSETS[Section.OWNER_FORAGE] + 4
	var weather_at: int = RULING_BLOCK_OFFSETS[Section.OWNER_WEATHER] + 4
	var forage_key: PackedByteArray = bytes.slice(forage_at, forage_at + 6)
	assert_equal(forage_key.get_string_from_utf8(), "forage", "the six-byte forage key")
	for index: int in 6:
		bytes[forage_at + index] = "gerbil".to_utf8_buffer()[index]
	assert_equal(_decoded_code(bytes), Section.REFUSE_OWNER_KEY, "a renamed key refuses")
	bytes = _encoded(_captured())
	var weather_key: PackedByteArray = bytes.slice(weather_at, weather_at + 7)
	assert_equal(weather_key.get_string_from_utf8(), "weather", "the seven-byte weather key")
	for index: int in 7:
		bytes[weather_at + index] = "farming".to_utf8_buffer()[index]
	assert_equal(_decoded_code(bytes), Section.REFUSE_OWNER_KEY,
		"a duplicate key at the wrong block refuses")


func test_a_wrong_key_byte_count_is_refused() -> void:
	"""The u32 key length is compared against the compiled key, not used to size a read."""
	var bytes: PackedByteArray = _encoded(_captured())
	bytes.encode_u32(RULING_BLOCK_OFFSETS[Section.OWNER_FARMING], 8)
	assert_equal(_decoded_code(bytes), Section.REFUSE_OWNER_KEY, "a lying key length refuses")


func test_a_wrong_owner_schema_version_is_refused_for_each_owner() -> void:
	"""Including `resource_nodes` at 1: the pre-correction version is not accepted under this one."""
	for owner: int in RULING_STORE_COUNT:
		var bytes: PackedByteArray = _encoded(_captured())
		var at: int = RULING_BLOCK_OFFSETS[owner] + 4 + RULING_OWNER_KEYS[owner].length()
		bytes.encode_u32(at, RULING_OWNER_SCHEMAS[owner] + 1)
		assert_equal(_decoded_code(bytes), Section.REFUSE_OWNER_SCHEMA,
			"'%s' at schema %d refuses" % [RULING_OWNER_KEYS[owner], RULING_OWNER_SCHEMAS[owner] + 1])
	var older: PackedByteArray = _encoded(_captured())
	var resource_at: int = RULING_BLOCK_OFFSETS[Section.OWNER_RESOURCE_NODES] + 4 + 14
	older.encode_u32(resource_at, 1)
	assert_equal(_decoded_code(older), Section.REFUSE_OWNER_SCHEMA,
		"resource_nodes schema 1 is refused, not reinterpreted")


func test_a_wrong_primary_count_or_payload_length_is_refused() -> void:
	"""Both are compared against the compiled table; neither is believed and used to advance."""
	for owner: int in RULING_STORE_COUNT:
		var numbers: int = RULING_BLOCK_OFFSETS[owner] + 4 + RULING_OWNER_KEYS[owner].length()
		var counted: PackedByteArray = _encoded(_captured())
		counted.encode_u64(numbers + 4, RULING_PRIMARY_COUNTS[owner] + 1)
		assert_equal(_decoded_code(counted), Section.REFUSE_PRIMARY_COUNT,
			"'%s' primary_count refuses" % RULING_OWNER_KEYS[owner])
		var sized: PackedByteArray = _encoded(_captured())
		sized.encode_u64(numbers + 12, RULING_PAYLOAD_BYTES[owner] - 1)
		assert_equal(_decoded_code(sized), Section.REFUSE_PAYLOAD_LENGTH,
			"'%s' payload_byte_length refuses" % RULING_OWNER_KEYS[owner])


func test_singleton_primary_counts_for_the_mixed_grids_are_rejected() -> void:
	"""The ruling names 1 for `world_init` and `spatial_world` as a rejected alternative."""
	for owner: int in [Section.OWNER_WORLD_INIT, Section.OWNER_SPATIAL_WORLD]:
		var bytes: PackedByteArray = _encoded(_captured())
		bytes.encode_u64(RULING_BLOCK_OFFSETS[owner] + 4 + RULING_OWNER_KEYS[owner].length() + 4, 1)
		assert_equal(_decoded_code(bytes), Section.REFUSE_PRIMARY_COUNT,
			"'%s' with primary_count 1 refuses" % RULING_OWNER_KEYS[owner])


func test_every_element_count_prefix_must_equal_its_declared_count() -> void:
	"""All 31, each mutated on its own: a count is never an allocation request."""
	var expected: Dictionary = _ruling_field_offsets()
	var checked: int = 0
	for owner: int in RULING_STORE_COUNT:
		if not expected.has(RULING_OWNER_KEYS[owner]):
			continue
		for row: Variant in expected[RULING_OWNER_KEYS[owner]] as Array:
			var entry: Array = row as Array
			var bytes: PackedByteArray = _encoded(_captured())
			bytes.encode_u64(RULING_PAYLOAD_OFFSETS[owner] + int(entry[3]), int(entry[2]) - 1)
			assert_equal(_decoded_code(bytes), Section.REFUSE_ELEMENT_COUNT,
				"'%s.%s' count refuses" % [RULING_OWNER_KEYS[owner], entry[0]])
			checked += 1
	assert_equal(checked, 31, "all 31 count prefixes were mutated")


func test_a_section_one_byte_short_is_refused_rather_than_measured() -> void:
	"""A short buffer, a short declared length and a long one all refuse. No partial decode."""
	var bytes: PackedByteArray = _encoded(_captured())
	assert_equal(_decoded_code(bytes.slice(0, RULING_SECTION_BYTES - 1)),
		Section.REFUSE_SECTION_LENGTH, "a buffer one byte short refuses")
	var back: Section.State = Section.State.new()
	assert_equal(Section.decode_section(bytes, 0, RULING_SECTION_BYTES - 1, back).code,
		Section.REFUSE_SECTION_LENGTH, "a declared length one byte short refuses")
	assert_equal(Section.decode_section(bytes, 0, RULING_SECTION_BYTES + 1, back).code,
		Section.REFUSE_SECTION_LENGTH, "a declared length one byte long refuses")
	assert_equal(Section.decode_section(bytes, 1, RULING_SECTION_BYTES, back).code,
		Section.REFUSE_TRUNCATED, "and one byte past the last legal offset refuses")
	assert_equal(Section.decode_section(bytes, -1, RULING_SECTION_BYTES, back).code,
		Section.REFUSE_NEGATIVE_OFFSET, "a negative offset refuses by name")


func test_a_refused_decode_leaves_the_callers_state_byte_identical() -> void:
	"""Allocate before consume: a malformed section must not half-publish into the caller's State."""
	var good: Section.State = _captured()
	_load_boundary_values(good)
	var target: Section.State = Section.State.new()
	assert_true(Section.decode_section(_encoded(good), 0, RULING_SECTION_BYTES, target).is_ok(),
		"the good section lands")
	var broken: PackedByteArray = _encoded(good)
	broken.encode_u64(RULING_PAYLOAD_OFFSETS[Section.OWNER_SPATIAL_WORLD] + 262164, 7)
	var refusal: SaveHeader.Refusal = Section.decode_section(broken, 0, RULING_SECTION_BYTES,
		target)
	assert_equal(refusal.code, Section.REFUSE_ELEMENT_COUNT, "the broken section refuses")
	_assert_same_state(target, good)


func test_an_out_of_domain_value_is_refused_by_its_owners_own_validator() -> void:
	"""Wire-legal bytes that no live store would accept: one per owner, named by its own code."""
	var state: Section.State = _captured()
	_load_boundary_values(state)
	assert_true(Section.validate_section(state, _stores).is_ok(), "the baseline validates")
	var cases: Array = [["building_slot", 1024], ["resource_slot", 4096],
		["tile_link_head", 16384]]
	for entry: Array in cases:
		var broken: Section.State = _captured()
		_load_boundary_values(broken)
		broken.set(String(entry[0]), _with(broken.get(String(entry[0])), int(entry[1])))
		assert_false(Section.validate_section(broken, _stores).is_ok(),
			"'%s' = %d is refused" % [entry[0], entry[1]])


func _with(column: PackedInt32Array, value: int) -> PackedInt32Array:
	"""A copy of `column` with its first entry replaced, so the original is left alone."""
	var copy: PackedInt32Array = column.duplicate()
	copy[0] = value
	return copy


# --- the deposit scratch contributes nothing -------------------------------------------------

func _refused_deposit_at(origin_x: int, origin_z: int) -> void:
	"""Drive a placement that WRITES the footprint scratch and then refuses on its fields.

	`_refuse_deposit()` fills `_deposit_tiles` before it validates the resource id, so a refusal
	here leaves sixteen tile indices in the scratch and changes nothing else at all.
	"""
	var result: ResourceNodesScript.OpResult = _stores.resource_nodes.place_deposit(origin_x,
		origin_z, -1, 75000, 0, 1, 0)
	assert_false(result.ok, "the placement refuses after writing its footprint scratch")
	assert_equal(result.error, ResourceNodesScript.REFUSE_INVALID_RESOURCE_ID, "on the id")


func test_changing_only_the_deposit_scratch_changes_no_section_byte() -> void:
	"""R-WORLD-S1-001 §10: the three reclassified arrays produce no payload and no digest change."""
	_refused_deposit_at(ResourceNodesScript.STONE_DEPOSIT_ORIGIN_X,
		ResourceNodesScript.STONE_DEPOSIT_ORIGIN_Z)
	var first: PackedByteArray = _encoded(_captured())
	_refused_deposit_at(ResourceNodesScript.IRON_DEPOSIT_ORIGIN_X,
		ResourceNodesScript.IRON_DEPOSIT_ORIGIN_Z)
	var second: Section.State = Section.State.new()
	var refusal: SaveHeader.Refusal = Section.capture_into(_stores, _runtime, SCENARIO_VERSION,
		GENERATOR_SCHEMA, _digest_bytes(), second)
	assert_true(refusal.is_ok(), "the second capture succeeds: %s" % refusal.detail)
	second.next_persistent_id = CURSOR
	assert_equal(_fingerprint(_encoded(second)), _fingerprint(first),
		"two different deposit footprints in scratch produce identical section bytes")


func test_a_placement_that_really_lands_does_change_the_section() -> void:
	"""The other half of the claim: ignored scratch is not the same as an ignored placement."""
	var before: PackedByteArray = _encoded(_captured())
	var result: ResourceNodesScript.OpResult = _stores.resource_nodes.place_deposit(
		ResourceNodesScript.STONE_DEPOSIT_ORIGIN_X, ResourceNodesScript.STONE_DEPOSIT_ORIGIN_Z,
		1, ResourceNodesScript.STONE_DEPOSIT_NODE_MILLI, 0, 1, 0)
	assert_true(result.ok, "a valid deposit places: %s" % result.error)
	var after: Section.State = Section.State.new()
	assert_true(Section.capture_into(_stores, _runtime, SCENARIO_VERSION, GENERATOR_SCHEMA,
		_digest_bytes(), after).is_ok(), "the second capture succeeds")
	after.next_persistent_id = CURSOR
	assert_false(_fingerprint(_encoded(after)) == _fingerprint(before),
		"sixteen real nodes DO move the tile map")


func test_the_resource_adapter_refuses_each_scratch_field_by_name() -> void:
	"""A removed declaration must refuse, not quietly return a plausible sixteen-entry column."""
	var adapter: Section.Adapter = Section.Adapter.new(_captured(), Section.OWNER_RESOURCE_NODES)
	var values: Digest.FieldValues = Digest.FieldValues.new()
	for key: String in ["_deposit_tiles", "_deposit_ref_slot", "_deposit_ref_generation"]:
		assert_false(adapter.canonical_field_values(StringName(key), values),
			"'%s' is refused" % key)
		assert_equal(values.refusal, Section.REFUSE_ADAPTER_FIELD, "by name")
		assert_equal(values.count, 0, "and with no values at all")
	assert_true(adapter.canonical_field_values(&"_resource_slot", values), "the real field works")
	assert_equal(values.count, 16384, "all 16384 tile entries")


# --- canonical value adapters ------------------------------------------------------------------

func test_all_nine_section_one_owners_supply_a_canonical_adapter() -> void:
	"""`missing_adapter_owners()` must stop naming any section-1 owner once these are registered."""
	var walker: Digest.Walker = Digest.production_walker()
	var before: PackedStringArray = walker.missing_adapter_owners()
	var section_one: int = 0
	for entry: String in before:
		if entry.begins_with("1:"):
			section_one += 1
	assert_equal(section_one, RULING_STORE_COUNT, "all nine start without an adapter")
	var refusal: Digest.Refusal = Section.register_adapters(walker, _captured())
	assert_true(refusal.is_ok(), "register_adapters: %s %s" % [refusal.code, refusal.detail])
	for entry: String in walker.missing_adapter_owners():
		assert_false(entry.begins_with("1:"), "'%s' still has no adapter" % entry)


func test_every_declared_section_one_record_is_supplied_at_its_declared_count() -> void:
	"""Walk the compiled declaration's §1 owners and ask each adapter for every hashed field."""
	var declaration: Digest.Declaration = Digest.production_declaration()
	var state: Section.State = _captured()
	var values: Digest.FieldValues = Digest.FieldValues.new()
	var supplied: int = 0
	for owner: int in RULING_STORE_COUNT:
		var index: int = declaration.find_owner(1, RULING_OWNER_KEYS[owner])
		assert_true(index < declaration.owner_count(),
			"'%s' is declared" % RULING_OWNER_KEYS[owner])
		var adapter: Section.Adapter = Section.Adapter.new(state, owner)
		var begin: int = declaration.owner_field_begin(index)
		for offset: int in declaration.owner_field_count(index):
			if not declaration.field_is_hashed(begin + offset):
				continue
			var key: String = declaration.field_key(begin + offset)
			assert_true(adapter.canonical_field_values(StringName(key), values),
				"'%s.%s' is supplied: %s" % [RULING_OWNER_KEYS[owner], key, values.detail])
			supplied += 1
	assert_equal(supplied, RULING_CANONICAL_RECORD_COUNT,
		"section 1 emits 36 canonical field records")


func test_an_unknown_field_key_is_refused_by_every_owner_adapter() -> void:
	"""No adapter invents a column for a key its owner does not declare."""
	var state: Section.State = _captured()
	var values: Digest.FieldValues = Digest.FieldValues.new()
	for owner: int in RULING_STORE_COUNT:
		var adapter: Section.Adapter = Section.Adapter.new(state, owner)
		assert_false(adapter.canonical_field_values(&"_not_a_field", values),
			"'%s' refuses an unknown key" % RULING_OWNER_KEYS[owner])
		assert_equal(values.refusal, Section.REFUSE_ADAPTER_FIELD, "by name")


func test_the_runtime_adapter_emits_four_records_and_never_debt() -> void:
	"""REG-R01: the tick is in the canonical prefix, and debt and the six counters are excluded."""
	var adapter: Section.Adapter = Section.Adapter.new(_captured(), Section.OWNER_WORLD_RUNTIME)
	var values: Digest.FieldValues = Digest.FieldValues.new()
	for key: String in ["_world_seed", "_seeded", "_requested_speed", "_pause_mask"]:
		assert_true(adapter.canonical_field_values(StringName(key), values), "'%s' supplied" % key)
		assert_equal(values.count, 1, "'%s' is one value" % key)
	for key: String in ["_completed_tick", "_debt", "_fallback_count"]:
		assert_false(adapter.canonical_field_values(StringName(key), values),
			"'%s' emits no canonical record" % key)


# --- validation, restore and the load barrier ---------------------------------------------------

func test_a_published_seed_must_agree_with_provenance_and_with_the_runtime() -> void:
	"""The one cross-owner rule this module owns, because no single owner can see both halves."""
	var state: Section.State = _captured()
	_load_boundary_values(state)
	assert_true(Section.seed_agreement_refusal(state).is_ok(), "the baseline agrees")
	state.published_seed = WORLD_SEED + 1
	assert_equal(Section.seed_agreement_refusal(state).code, Section.REFUSE_SEED_DISAGREES,
		"a published seed unlike the provenance seed refuses")
	state.published_seed = WORLD_SEED
	state.effective_seed = WORLD_SEED + 1
	assert_equal(Section.seed_agreement_refusal(state).code, Section.REFUSE_SEED_DISAGREES,
		"and so does a provenance seed unlike the published one")
	state.effective_seed = WORLD_SEED
	state.runtime.rng_seeded = false
	assert_equal(Section.seed_agreement_refusal(state).code, Section.REFUSE_UNSEEDED_PUBLISHED,
		"a published world on an unseeded runtime refuses")


func test_an_unpublished_map_asserts_nothing_about_the_seed() -> void:
	"""An empty map is an explicit state, not a claim that a half-built world can be saved."""
	var state: Section.State = _captured()
	assert_equal(state.published, 0, "a fresh generator has published nothing")
	state.effective_seed = 0
	state.runtime.world_seed = 0
	state.runtime.rng_seeded = false
	assert_true(Section.seed_agreement_refusal(state).is_ok(), "no seed rule applies")


func _fresh_stores() -> Section.Stores:
	"""A second, independent settlement to restore into, sharing nothing with `_stores`."""
	var residents: ResidentsScript = ResidentsScript.new()
	var jobs: JobsScript = JobsScript.new(residents)
	var directory: EntityDirectory = jobs.directory()
	var stores: Section.Stores = Section.Stores.new()
	stores.directory = directory
	stores.buildings = BuildingsScript.new(directory)
	stores.farming = FarmingScript.new(directory)
	stores.forage = ForageScript.new(directory, jobs)
	stores.resource_nodes = ResourceNodesScript.new(directory)
	stores.spatial_world = SpatialWorldScript.new()
	stores.weather = WeatherScript.new()
	stores.world_init = WorldInitScript.new(directory, stores.resource_nodes, stores.forage,
		FishingScript.new(directory, stores.forage, jobs), RngScript.new(), stores.farming)
	return stores


func test_a_validated_section_restores_into_a_second_world_and_captures_identically() -> void:
	"""Restore is the inverse of capture: the target world re-captures to the same bytes."""
	var state: Section.State = _captured()
	var bytes: PackedByteArray = _encoded(state)
	var target: Section.Stores = _fresh_stores()
	var refusal: SaveHeader.Refusal = Section.restore_section(state, target)
	assert_true(refusal.is_ok(), "restore_section: %s %s" % [refusal.code, refusal.detail])
	var again: Section.State = Section.State.new()
	assert_true(Section.capture_into(target, _runtime, SCENARIO_VERSION, GENERATOR_SCHEMA,
		_digest_bytes(), again).is_ok(), "the restored world re-captures")
	again.next_persistent_id = CURSOR
	assert_equal(_fingerprint(_encoded(again)), _fingerprint(bytes),
		"and produces the same section bytes")
	assert_true(Section.cross_check_refusal(target).is_ok(), "every cross-owner inverse holds")


func test_a_refused_restore_leaves_the_target_world_unchanged() -> void:
	"""The load barrier's whole point: a rejected section must not half-publish an owner."""
	var target: Section.Stores = _fresh_stores()
	var untouched: Section.State = Section.State.new()
	assert_true(Section.capture_into(target, _runtime, SCENARIO_VERSION, GENERATOR_SCHEMA,
		_digest_bytes(), untouched).is_ok(), "the target captures cleanly first")
	var before: PackedByteArray = _encoded(untouched)
	var broken: Section.State = _captured()
	broken.resource_slot = _with(broken.resource_slot, 4096)
	assert_false(Section.restore_section(broken, target).is_ok(), "the restore refuses")
	var after: Section.State = Section.State.new()
	assert_true(Section.capture_into(target, _runtime, SCENARIO_VERSION, GENERATOR_SCHEMA,
		_digest_bytes(), after).is_ok(), "the target still captures")
	assert_equal(_fingerprint(_encoded(after)), _fingerprint(before),
		"and is byte-identical to what it was")


func test_a_restore_that_refuses_late_still_leaves_the_earlier_owners_alone() -> void:
	"""Validation runs to completion BEFORE publication, so owner order cannot half-apply a load."""
	var target: Section.Stores = _fresh_stores()
	var untouched: Section.State = Section.State.new()
	assert_true(Section.capture_into(target, _runtime, SCENARIO_VERSION, GENERATOR_SCHEMA,
		_digest_bytes(), untouched).is_ok(), "the target captures cleanly first")
	var before: PackedByteArray = _encoded(untouched)
	var broken: Section.State = _captured()
	broken.building_slot = _with(broken.building_slot, 0)
	broken.world_map.basin_danger = PackedInt32Array([9, 0, 0, 0, 0, 0, 0])
	assert_false(Section.restore_section(broken, target).is_ok(),
		"the LAST owner's validator refuses")
	var after: Section.State = Section.State.new()
	assert_true(Section.capture_into(target, _runtime, SCENARIO_VERSION, GENERATOR_SCHEMA,
		_digest_bytes(), after).is_ok(), "the target still captures")
	assert_equal(_int32_fingerprint(after.building_slot),
		_int32_fingerprint(untouched.building_slot),
		"the FIRST owner's tile map never moved, even though its value was the valid one")
	assert_equal(_fingerprint(_encoded(after)), _fingerprint(before),
		"and the whole section is unchanged")


func test_an_unbound_store_refuses_rather_than_skipping_an_owner() -> void:
	"""A codec that accepted a null store would silently omit that owner from the section."""
	var partial: Section.Stores = _fresh_stores()
	partial.weather = null
	var state: Section.State = Section.State.new()
	assert_equal(Section.capture_into(partial, _runtime, SCENARIO_VERSION, GENERATOR_SCHEMA,
		_digest_bytes(), state).code, Section.REFUSE_STORE_MISSING, "capture refuses")
	assert_equal(Section.validate_section(_captured(), partial).code, Section.REFUSE_STORE_MISSING,
		"validation refuses")
	assert_equal(Section.cross_check_refusal(partial).code, Section.REFUSE_STORE_MISSING,
		"and so does the cross check")
