extends "res://test/framework/test_case.gd"
## Coverage for task 2.6: the authoritative ItemDefinition catalog and its loader.
##
## Three layers are exercised:
##   1. tools/extract_item_definitions.py's own guards (row count, duplicate id, retired key,
##      non-integer field), invoked as a real subprocess against throwaway fixture copies of
##      docs/gameplay_balance.md so the real balance document is never touched.
##   2. scripts/core/item_definitions.gd loading the real generated
##      godot/data/item_definitions.json: exactly 60 items, deterministic compiled ids, and a
##      spot check of specific rows against docs/gameplay_balance.md §3.1.
##   3. The all-or-nothing / REQ-ADM-003 refusal contract: every SET-AMEND-001 retired key is
##      rejected explicitly, and a single invalid record aborts the whole load with nothing
##      registered anywhere -- not in the target inventory, not in the loader's own columns.
##
## Fixture documents are built by string-editing a copy of the real docs/gameplay_balance.md
## (loaded once in before_each) rather than hand-authoring a 60-row table, so every fixture
## still has the real header/section shape and a genuine 60-row body except for the one
## deliberately broken field under test.

const ItemDefinitionsScript := preload("res://scripts/core/item_definitions.gd")
const InventoryScript := preload("res://scripts/core/inventory.gd")

const REAL_JSON_PATH: String = "res://data/item_definitions.json"
const REAL_DOC_PATH: String = "res://../docs/gameplay_balance.md"
const GENERATOR_SCRIPT_PATH: String = "res://../tools/extract_item_definitions.py"

## An exact, unique line from the real §3.1 table (docs/gameplay_balance.md). Fixtures splice
## this single row to inject one failure while leaving the other 59 rows and the row count
## intact, so the guard under test is the one that fires.
const WOOD_ROW: String = "| wood | MATERIAL | 5000 | 0 | 0 | 0 | 0 | NONE | 0 | [GDD §5.7; NEW category/key normalization] |"

## SET-AMEND-001 §3 retired item keys (docs/setting_rules_amendment.md), mirrored here as the
## test's independent expectation of what must be rejected -- not read back from the module
## under test.
const RETIRED_KEYS: Array[StringName] = [
	&"bow", &"carcass_boar", &"carcass_deer", &"carcass_grouse", &"hide",
	&"hunting_tool", &"meal_game_roast", &"raw_game", &"smoked_game",
]

var _real_doc_text: String = ""
var _fixture_counter: int = 0


func before_each() -> void:
	"""Load the real balance document once per test so fixtures can splice it."""
	_real_doc_text = FileAccess.get_file_as_string(REAL_DOC_PATH)
	assert_false(_real_doc_text.is_empty(), "docs/gameplay_balance.md must be readable")
	_fixture_counter += 1


# --- helpers: fixture files and subprocess invocation ---------------------------------------

func _write_user_file(suffix: String, content: String) -> String:
	"""Write `content` to a fresh user:// file and return its virtual path."""
	var virtual_path: String = "user://fixture_%d_%s" % [_fixture_counter, suffix]
	var file: FileAccess = FileAccess.open(virtual_path, FileAccess.WRITE)
	file.store_string(content)
	file.close()
	return virtual_path


func _run_generator(source_virtual_path: String, output_virtual_path: String) -> int:
	"""Run the real generator script as a subprocess against a fixture; return its exit code."""
	var source_os_path: String = ProjectSettings.globalize_path(source_virtual_path)
	var output_os_path: String = ProjectSettings.globalize_path(output_virtual_path)
	var script_os_path: String = ProjectSettings.globalize_path(GENERATOR_SCRIPT_PATH)
	var args: PackedStringArray = PackedStringArray([
		script_os_path, "--source", source_os_path, "--output", output_os_path,
	])
	var output: Array = []
	return OS.execute("python3", args, output, true)


func _load_json_dict(virtual_path: String) -> Dictionary:
	"""Parse a JSON file at `virtual_path` into a Dictionary."""
	var text: String = FileAccess.get_file_as_string(virtual_path)
	return JSON.parse_string(text)


# --- generator guards (tools/extract_item_definitions.py) -----------------------------------

func test_generator_accepts_the_real_balance_document() -> void:
	"""Sanity baseline: the unmodified real document produces exactly 61 records, exit 0."""
	var source_path: String = _write_user_file("good.md", _real_doc_text)
	var output_path: String = "user://fixture_%d_good.json" % _fixture_counter
	var exit_code: int = _run_generator(source_path, output_path)
	assert_equal(exit_code, 0, "generator must accept the real balance document")
	var payload: Dictionary = _load_json_dict(output_path)
	assert_equal(int(payload["count"]), 61, "real document yields exactly 61 records")


func test_generator_rejects_wrong_row_count() -> void:
	"""Deleting one row drops the count to 59; the row-count guard must fire (non-zero exit)."""
	var lines: PackedStringArray = _real_doc_text.split("\n")
	var kept: PackedStringArray = PackedStringArray()
	for line: String in lines:
		if line != WOOD_ROW:
			kept.append(line)
	var source_path: String = _write_user_file("short.md", "\n".join(kept))
	var exit_code: int = _run_generator(source_path, "user://fixture_%d_short.json" % _fixture_counter)
	assert_false(exit_code == 0, "59 data rows must be refused")


func test_generator_rejects_duplicate_id() -> void:
	"""Renaming one row's id to an id used elsewhere must refuse without changing the row count."""
	var broken_row: String = WOOD_ROW.replace("| wood |", "| berries |")
	var source_path: String = _write_user_file("dup.md", _real_doc_text.replace(WOOD_ROW, broken_row))
	var exit_code: int = _run_generator(source_path, "user://fixture_%d_dup.json" % _fixture_counter)
	assert_false(exit_code == 0, "a duplicated id must be refused")


func test_generator_rejects_a_retired_key() -> void:
	"""A retired key appearing in §3.1 must refuse (REQ-ADM-003), not silently compile."""
	var broken_row: String = WOOD_ROW.replace("| wood |", "| bow |")
	var source_path: String = _write_user_file("retired.md", _real_doc_text.replace(WOOD_ROW, broken_row))
	var exit_code: int = _run_generator(source_path, "user://fixture_%d_retired.json" % _fixture_counter)
	assert_false(exit_code == 0, "a retired key in the source table must be refused")


func test_generator_rejects_non_integer_numeric_field() -> void:
	"""A decimal value in an integer-only column must refuse rather than silently truncate."""
	var broken_row: String = WOOD_ROW.replace("| 5000 |", "| 5000.5 |")
	var source_path: String = _write_user_file("float.md", _real_doc_text.replace(WOOD_ROW, broken_row))
	var exit_code: int = _run_generator(source_path, "user://fixture_%d_float.json" % _fixture_counter)
	assert_false(exit_code == 0, "a non-integer numeric field must be refused")


# --- loading the real generated catalog ------------------------------------------------------

func test_default_catalog_loads_exactly_61_items() -> void:
	"""The real godot/data/item_definitions.json loads all-or-nothing to exactly 61 items."""
	var inv: InventoryScript = InventoryScript.new(4, 4)
	var defs: ItemDefinitionsScript = ItemDefinitionsScript.new()
	var result: ItemDefinitionsScript.LoadResult = defs.load_default(inv)
	assert_true(result.ok, "default catalog must load (error: %s)" % result.error)
	assert_equal(result.item_count, 61, "exactly 61 items load")
	assert_equal(defs.item_count(), 61, "loader reports 61 items after load")
	assert_true(defs.is_loaded(), "loader marks itself loaded after success")


func test_wood_round_trips_material_5000g() -> void:
	"""Spot check: wood is MATERIAL / 5000 g (docs/gameplay_balance.md §3.1)."""
	var inv: InventoryScript = InventoryScript.new(4, 4)
	var defs: ItemDefinitionsScript = ItemDefinitionsScript.new()
	assert_true(defs.load_default(inv).ok, "default catalog must load")
	var wood_id: int = defs.compiled_id(&"wood")
	assert_true(wood_id >= 0, "wood must compile to a valid id")
	assert_equal(inv.item_mass_g(wood_id), 5000, "wood mass_g")
	assert_equal(inv.item_category(wood_id), defs.category_compiled_id(&"MATERIAL"), "wood category")


func test_berries_round_trips_raw_food_fields() -> void:
	"""Spot check: berries is RAW_FOOD / 250 g / 700 NP / 48 h / raw_edible=1."""
	var inv: InventoryScript = InventoryScript.new(4, 4)
	var defs: ItemDefinitionsScript = ItemDefinitionsScript.new()
	assert_true(defs.load_default(inv).ok, "default catalog must load")
	var berries_id: int = defs.compiled_id(&"berries")
	assert_true(berries_id >= 0, "berries must compile to a valid id")
	assert_equal(inv.item_mass_g(berries_id), 250, "berries mass_g")
	assert_equal(inv.item_category(berries_id), defs.category_compiled_id(&"RAW_FOOD"), "berries category")
	assert_equal(defs.nutrition_per_u(berries_id), 700, "berries nutrition_per_u")
	assert_equal(defs.shelf_hours(berries_id), 48, "berries shelf_hours")
	assert_true(defs.is_raw_edible(berries_id), "berries raw_edible")


func test_meal_nut_roast_is_present() -> void:
	"""AMEND-001 introduced meal_nut_roast as the game_roast replacement; it must compile."""
	var inv: InventoryScript = InventoryScript.new(4, 4)
	var defs: ItemDefinitionsScript = ItemDefinitionsScript.new()
	assert_true(defs.load_default(inv).ok, "default catalog must load")
	assert_true(defs.compiled_id(&"meal_nut_roast") >= 0, "meal_nut_roast must be a compiled item")


# --- REQ-ADM-003: retired keys are rejected, never substituted -------------------------------

func _fixture_with_id_replaced(new_id: StringName) -> String:
	"""Write a copy of the real generated JSON with its first item's id replaced, return its path."""
	var payload: Dictionary = _load_json_dict(REAL_JSON_PATH)
	var items: Array = payload["items"]
	items[0]["id"] = String(new_id)
	return _write_user_file("retired_%s.json" % new_id, JSON.stringify(payload))


func test_every_retired_key_is_rejected_explicitly() -> void:
	"""Every one of the nine SET-AMEND-001 keys is refused, individually, with no substitution."""
	for retired_key: StringName in RETIRED_KEYS:
		var path: String = _fixture_with_id_replaced(retired_key)
		var inv: InventoryScript = InventoryScript.new(4, 4)
		var defs: ItemDefinitionsScript = ItemDefinitionsScript.new()
		var result: ItemDefinitionsScript.LoadResult = defs.load_from_file(path, inv)
		assert_false(result.ok, "retired key '%s' must be refused" % retired_key)
		assert_true(result.error.find(String(retired_key)) != -1, "refusal names '%s'" % retired_key)
		assert_false(defs.is_loaded(), "loader must not mark itself loaded for '%s'" % retired_key)


# --- all-or-nothing: one invalid record aborts everything ------------------------------------

func test_invalid_record_aborts_entire_load_and_registers_nothing() -> void:
	"""One malformed record refuses the whole 60-item batch; nothing is registered anywhere."""
	var payload: Dictionary = _load_json_dict(REAL_JSON_PATH)
	var items: Array = payload["items"]
	items[30].erase("mass_g")
	var path: String = _write_user_file("invalid.json", JSON.stringify(payload))
	var inv: InventoryScript = InventoryScript.new(64, 64)
	var defs: ItemDefinitionsScript = ItemDefinitionsScript.new()
	var result: ItemDefinitionsScript.LoadResult = defs.load_from_file(path, inv)
	assert_false(result.ok, "a missing field must refuse the whole load")
	assert_false(defs.is_loaded(), "loader must not mark itself loaded")
	assert_equal(defs.item_count(), 0, "loader must report zero items")
	for candidate_id: int in InventoryScript.ITEM_CAPACITY:
		assert_false(inv.is_item_registered(candidate_id), "id %d must be unregistered" % candidate_id)


# --- deterministic, insertion-order-independent compiled ids ---------------------------------

func _fixture_with_items(ids_in_order: Array[String]) -> String:
	"""Write a minimal valid catalog whose items appear in exactly `ids_in_order`."""
	var items: Array = []
	for item_id: String in ids_in_order:
		items.append({
			"id": item_id, "category": "MATERIAL", "mass_g": 1000, "nutrition_per_u": 0,
			"shelf_hours": 0, "raw_edible": 0, "seed": 0, "effect": "NONE", "effect_value": 0,
		})
	var payload: Dictionary = {"items": items}
	return _write_user_file("order_%d.json" % ids_in_order.size(), JSON.stringify(payload))


func test_compiled_ids_are_ascending_ascii_and_order_independent() -> void:
	"""The same key set compiles to the same ascending-ASCII ids regardless of file order."""
	var forward: Array[String] = ["zeta", "alpha", "mike", "bravo", "yankee"]
	var reversed_order: Array[String] = forward.duplicate()
	reversed_order.reverse()
	var sorted_ids: Array[String] = forward.duplicate()
	sorted_ids.sort()

	var inv_a: InventoryScript = InventoryScript.new(8, 8)
	var defs_a: ItemDefinitionsScript = ItemDefinitionsScript.new()
	assert_true(defs_a.load_from_file(_fixture_with_items(forward), inv_a).ok, "forward order loads")

	var inv_b: InventoryScript = InventoryScript.new(8, 8)
	var defs_b: ItemDefinitionsScript = ItemDefinitionsScript.new()
	assert_true(defs_b.load_from_file(_fixture_with_items(reversed_order), inv_b).ok, "reversed order loads")

	for index: int in sorted_ids.size():
		var expected_id: int = index
		var key: StringName = StringName(sorted_ids[index])
		assert_equal(defs_a.compiled_id(key), expected_id, "forward-order id for %s" % key)
		assert_equal(defs_b.compiled_id(key), expected_id, "reversed-order id for %s" % key)
