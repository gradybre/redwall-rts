extends "res://test/framework/test_case.gd"
## Tests for the ARCH-MEM-010 measurement harness in `res://tools/`.
##
## These check the MEASURING INSTRUMENT, not the ledger's conclusions: that reflection finds
## every packed column, that a column's bytes come from its own `size()`, that the named-
## column filter really filters, that the store walk builds one world and not four, and that
## the transcribed §2.3 rows still add up to the 60821078 the document prints.
##
## The handful of absolute byte figures asserted below are all §2.3 allocation rows with a
## fixed derivation in the document (262144 cells x 14 bytes, 4096 records x 64 bytes, and
## so on). If a store change moves one of them, the ledger row it implements has moved too
## and the failure is the correct outcome, not a brittle test.

const Probe := preload("res://tools/memory_ledger_probe.gd")
const LedgerRows := preload("res://tools/memory_ledger_rows.gd")

## §2.3 prints this as the sum of its 24 allocation rows.
const PRINTED_PAYLOAD: int = 60821078
## §2.3's allocation table has exactly this many printed rows.
const PRINTED_ROW_COUNT: int = 24
## ARCH-ID-001's directory length G.
const DIRECTORY_LENGTH: int = 352418

var _probe: Probe = null
var _rows: LedgerRows = null
var _world: Dictionary = {}
var _measured: Array[Dictionary] = []


func before_each() -> void:
	"""Build one wired world and measure it once per test method."""
	_probe = Probe.new()
	_rows = LedgerRows.new()
	_world = _probe.build_world()
	_measured = _probe.collect_instances(_world)


func after_each() -> void:
	"""Drop the world so the next method's allocations start from a clean set."""
	_world = {}
	_measured = []


func _instance(script_path: String) -> Dictionary:
	"""The measured row for one script path, or an empty Dictionary if it was not built."""
	for row: Dictionary in _measured:
		if String(row["script"]) == script_path:
			return row
	return {}


func test_element_calibration_confirms_the_ledgers_byte_model() -> void:
	"""Every packed type's measured bytes per element equals what §2.3's arithmetic assumes."""
	var calibrated: Array[Dictionary] = _probe.calibrate_element_bytes()
	assert_equal(calibrated.size(), Probe.DECLARED_ELEMENT_BYTES.size(),
		"every declared packed type is calibrated")
	for row: Dictionary in calibrated:
		assert_true(bool(row["measured"]),
			"%s produced an observable static-memory delta" % row["type"])
		assert_equal(int(row["bytes_per_element"]), int(row["declared"]),
			"%s bytes per element" % row["type"])


func test_array_elements_cost_more_than_the_ledger_assumes() -> void:
	"""A GDScript Array element is a Variant, not the 8-byte reference §2.3 budgets for."""
	var row: Dictionary = _probe.calibrate_array_element_bytes()
	assert_true(bool(row["measured"]), "the Array allocation produced a static-memory delta")
	assert_equal(int(row["declared"]), 8, "§2.3 budgets 8 bytes per store-code element")
	assert_true(int(row["bytes_per_element"]) > 8,
		"a Variant array element costs more than 8 bytes (measured %d)"
			% int(row["bytes_per_element"]))


func test_the_walk_builds_exactly_one_of_each_store() -> void:
	"""Sharing collaborators must leave no duplicate instance of any script in the world."""
	assert_equal(_probe.duplicate_instances(_measured).size(), 0,
		"no script is instantiated twice in one wired world")
	assert_true(_measured.size() >= 30,
		"the walk reached at least thirty stores (reached %d)" % _measured.size())


func test_duplicate_instances_names_a_script_measured_twice() -> void:
	"""The duplicate check must actually report a repeat, not merely return an empty list."""
	var first: Object = Probe.PresentationExtractScript.new()
	var second: Object = Probe.PresentationExtractScript.new()
	var rows: Array[Dictionary] = [
		_probe.measure_instance(first), _probe.measure_instance(second)]
	var repeated: Array[String] = _probe.duplicate_instances(rows)
	assert_equal(repeated.size(), 1, "one script was measured twice")
	assert_equal(repeated[0], "res://scripts/core/presentation_extract.gd",
		"the repeated script is named")


func test_the_shared_directory_is_measured_once_though_many_stores_hold_it() -> void:
	"""Dedupe by instance id is what stops one directory being counted per store holding it."""
	var directory: Object = _world["entity_directory"]
	assert_true(_world["jobs"].directory() == directory, "the job store shares the directory")
	assert_true(_world["ecology"].directory() == directory, "ecology shares the directory")
	assert_true(_world["transforms"].get("_directory") == directory,
		"the transform store shares the directory")
	var seen: int = 0
	for row: Dictionary in _measured:
		if String(row["script"]) == "res://scripts/core/entity_directory.gd":
			seen += 1
	assert_equal(seen, 1, "the shared directory is measured exactly once")


func test_directory_columns_are_measured_from_their_own_size() -> void:
	"""Every full-length directory column reports `size()` times its element width."""
	var row: Dictionary = _instance("res://scripts/core/entity_directory.gd")
	assert_false(row.is_empty(), "the entity directory was measured")
	var full_length: int = 0
	for column: Dictionary in row["columns"]:
		if int(column["length"]) != DIRECTORY_LENGTH:
			continue
		full_length += 1
		var width: int = int(Probe.DECLARED_ELEMENT_BYTES[int(column["type_id"])])
		assert_equal(int(column["bytes"]), DIRECTORY_LENGTH * width,
			"%s bytes equal its own length times its element width" % column["name"])
	assert_equal(full_length, 9, "nine directory columns are allocated to the full G")


func test_static_navigation_map_measures_its_declared_row() -> void:
	"""§2.3's 262144-cell, 14-byte-per-cell ground map is what `spatial_world.gd` allocates."""
	var row: Dictionary = _instance("res://scripts/core/spatial_world.gd")
	assert_false(row.is_empty(), "the ground map store was measured")
	assert_equal(int(row["packed_bytes"]), 262144 * 14, "static navigation map bytes")


func test_named_column_filter_excludes_columns_it_was_not_given() -> void:
	"""`column_bytes_named` must total only the named columns, not the whole instance."""
	var row: Dictionary = _instance("res://scripts/core/commands.gd")
	assert_false(row.is_empty(), "the command queue store was measured")
	var arena: int = _probe.column_bytes_named(row, ["_payload"])
	assert_equal(arena, 1048576, "the payload arena alone is ARCH-SAVE-001's 1 MiB")
	var order: int = _probe.column_bytes_named(row, ["_order"])
	assert_equal(order, 4096 * 4, "the order index alone is one i32 per queued record")
	assert_true(arena + order < int(row["packed_bytes"]),
		"two named columns total less than the whole store")
	assert_equal(_probe.column_bytes_named(row, ["_not_a_column"]), 0,
		"a name that matches nothing contributes nothing")


func test_a_star_builder_and_route_arena_match_their_rows() -> void:
	"""The six builder columns and the route arena are exactly §2.3's 5505024 and 4194304."""
	var row: Dictionary = _instance("res://scripts/core/navigation.gd")
	assert_false(row.is_empty(), "the navigation store was measured")
	var builder: Array = ["_g", "_parent", "_heap", "_heap_position", "_stamp", "_state"]
	assert_equal(_probe.column_bytes_named(row, builder), 5505024, "active A* builder bytes")
	assert_equal(_probe.column_bytes_named(row, ["_arena"]), 4194304, "route cell arena bytes")


func test_scheduler_queue_packed_payload_is_short_of_its_declared_row() -> void:
	"""R07-SCHED-001 allocates the 8192 bytes of records; the 32-byte header is not packed."""
	var row: Dictionary = _instance("res://scripts/core/scheduler_events.gd")
	assert_false(row.is_empty(), "the scheduler event queue was measured")
	assert_equal(int(row["packed_bytes"]), 256 * 32, "256 records of 32 bytes")
	assert_equal(int(row["packed_bytes"]), 8192,
		"the declared 8224 includes a control header held in scalar members, not a column")


func test_presentation_snapshot_matches_its_declared_row_exactly() -> void:
	"""ARCH-SYS-023's two frames plus availability and visibility bytes are 244."""
	var row: Dictionary = _instance("res://scripts/core/presentation_extract.gd")
	assert_false(row.is_empty(), "the presentation extract was measured")
	assert_equal(int(row["packed_bytes"]), 244, "presentation snapshot bytes")


func test_lazily_loaded_catalog_allocates_nothing_at_construction() -> void:
	"""`item_definitions.gd` reaches capacity on load, so `_init` allocates no bytes at all."""
	var row: Dictionary = _instance("res://scripts/core/item_definitions.gd")
	assert_false(row.is_empty(), "the item definitions store was measured")
	assert_equal(int(row["packed_bytes"]), 0, "no packed bytes are allocated in _init")
	assert_true((row["columns"] as Array).size() > 0,
		"its packed columns exist and are simply empty")


func test_string_columns_are_reported_apart_from_the_packed_total() -> void:
	"""A PackedStringArray has no fixed element width, so it must not enter `packed_bytes`."""
	var row: Dictionary = _instance("res://scripts/core/residents.gd")
	assert_false(row.is_empty(), "the resident store was measured")
	var strings: Array = row["string_columns"]
	assert_equal(strings.size(), 2, "residents.gd declares two PackedStringArray columns")
	var names: Dictionary = {}
	for column: Dictionary in strings:
		names[String(column["name"])] = column
	assert_true(names.has("_name_key"), "the resident name column is reported")
	assert_equal(int(names["_name_key"]["length"]), 512, "one name slot per resident row")
	assert_equal(int(names["_name_key"]["utf8_content_bytes"]), 0,
		"no name text exists before any resident is admitted")
	assert_true(int(names["_species_key"]["utf8_content_bytes"]) > 0,
		"the species catalog column carries text at construction")
	for column: Dictionary in row["columns"]:
		assert_false(names.has(String(column["name"])),
			"%s is not counted as a fixed-width column" % String(column["name"]))


func test_empty_string_slots_are_measured_not_assumed() -> void:
	"""The per-slot cost of a PackedStringArray is read from the allocator, not declared."""
	var slot: Dictionary = _probe.calibrate_string_array_element_bytes()
	assert_true(bool(slot["measured"]), "the string-array allocation produced a delta")
	assert_true(int(slot["bytes_per_empty_element"]) >= 4,
		"an empty slot still costs at least a pointer (measured %d)"
			% int(slot["bytes_per_empty_element"]))


func test_transcribed_rows_reproduce_the_printed_payload() -> void:
	"""The transcription must add to §2.3's own printed 60821078 across 24 rows."""
	assert_equal(_rows.rows().size(), PRINTED_ROW_COUNT, "twenty-four allocation rows")
	assert_equal(_rows.declared_total(), PRINTED_PAYLOAD, "sum of the printed rows")


func test_every_transcribed_owner_is_a_script_that_exists() -> void:
	"""An owner path that does not resolve would silently report its row as OWNER ABSENT."""
	var owned: int = 0
	for row: Dictionary in _rows.rows():
		var owner: String = String(row["owner"])
		if owner == LedgerRows.UNATTRIBUTED:
			continue
		owned += 1
		assert_true(ResourceLoader.exists(owner), "%s exists" % owner)
	assert_equal(owned, 18, "eighteen of the twenty-four rows name an owning script")
