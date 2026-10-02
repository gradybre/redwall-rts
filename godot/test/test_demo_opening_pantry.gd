extends "res://test/framework/test_case.gd"
## The pantry the demo opens with (demo/farm/opening_pantry.gd, decision 0912): 40 U of wheat and 50 U of carrots in
## the covered store, as fresh lots on the pantry's own ledger, NOT counted as the opening day's harvest; and the real
## village opens with them (its own headless process: the village is booted, not hand-built).

const OpeningScript := preload("res://demo/farm/opening_pantry.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const StorageScript := preload("res://demo/farm/farm_storage.gd")
const RecordScript := preload("res://demo/farm/farm_record.gd")
const SimScript := preload("res://demo/farm/farm_sim.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const PROBE: String = "res://test/live/opening_pantry_probe.gd"
const WHEAT_MILLI: int = 40000
const CARROT_MILLI: int = 50000
## The opening stock cooks 72 portions: 20 porridge batches (2 U) and 16 soup batches (3 U), 2 portions each -- four days
## of meals for the staged nine (18 portions a day), six for the six placeholders where the assets are not staged (CI).
const OPENING_PORTIONS: int = 72


func _item(key: StringName) -> int:
	"""A pantry item by key."""
	return Catalog.ITEM_KEYS.find(key)


func test_the_opening_stock_is_wheat_and_carrots_in_the_covered_store() -> void:
	"""40 U of wheat and 50 U of carrots, stored at location 0, fresh, and on the stored ledger like any delivery."""
	var pantry := PantryScript.new(StorageScript.new(Vector2.ZERO))
	assert_equal(OpeningScript.stock(pantry, null, 6), WHEAT_MILLI + CARROT_MILLI, "all 90 U stored")
	assert_equal(OpeningScript.total_milli(), WHEAT_MILLI + CARROT_MILLI, "the whole stock, as the village checks it")
	assert_equal(pantry.milli_of(_item(&"wheat")), WHEAT_MILLI, "40 U of wheat")
	assert_equal(pantry.milli_of(_item(&"carrot")), CARROT_MILLI, "50 U of carrots")
	assert_equal(pantry.milli_at(_item(&"wheat"), 0), WHEAT_MILLI, "the wheat in the covered store")
	assert_equal(pantry.milli_at(_item(&"carrot"), 0), CARROT_MILLI, "the carrots in the covered store")
	assert_equal(pantry.total_milli(), WHEAT_MILLI + CARROT_MILLI, "nothing else")
	assert_equal(pantry.stored_total_milli(_item(&"wheat")), WHEAT_MILLI, "on the pantry's stored ledger")
	var read := IntMath.IntResult.new()
	assert_true(pantry.freshness_permille_into(_item(&"carrot"), read) and read.value == 1000, "fresh")


func test_the_opening_stock_is_not_the_first_day_s_harvest() -> void:
	"""The record is re-opened once the stock is in: the opening day records only what is stored after it."""
	var pantry := PantryScript.new(StorageScript.new(Vector2.ZERO))
	var record := RecordScript.new()
	record.bind(pantry, SimScript.new().crop_weather().weather())
	record.start(6)
	OpeningScript.stock(pantry, record, 6)
	var read := IntMath.IntResult.new()
	pantry.add_into(_item(&"radish"), 5100, 0, read)
	assert_equal(record.close_through(24), 1, "spring 1 closes at midnight")
	assert_equal(record.value(0, RecordScript.F_HARVESTED), 5100, "only the radish was harvested")
	assert_equal(record.item_value(0, RecordScript.G_HARVESTED, _item(&"wheat")), 0, "the opening wheat is not")


func test_a_store_without_room_is_not_forced() -> void:
	"""A row the store refuses is left out, not forced in: the milli-U stored say so."""
	var pantry := PantryScript.new(StorageScript.new(Vector2.ZERO))
	var read := IntMath.IntResult.new()
	var room: int = pantry.room_milli_of(0)
	assert_true(pantry.add_into(_item(&"oats"), room - 45000, 0, read), "the store filled to 45 U of room")
	assert_equal(OpeningScript.stock(pantry, null, 6), WHEAT_MILLI, "the wheat fits; the carrots do not")
	assert_equal(pantry.milli_of(_item(&"carrot")), 0, "no carrots forced in")


func test_the_real_village_opens_with_the_stock() -> void:
	"""The booted village (its own process): the pantry holds the opening stock, the kitchen counts it as Ready food,
	and the record's opening day has harvested nothing."""
	var output: Array = []
	var args: PackedStringArray = ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--quit-after",
		"600", "--script", PROBE]
	var code: int = OS.execute(OS.get_executable_path(), args, output, true, false)
	var text: String = "".join(PackedStringArray(output))
	var line: String = ""
	for row: String in text.split("\n"):
		if row.begins_with("OPENING "):
			line = row
		elif row.contains("SCRIPT ERROR"):
			fail("the probe: %s" % row)
	assert_equal(code, 0, "the probe exited cleanly")
	var residents: int = int(line.get_slice("residents=", 1))
	assert_true(residents > 0, "the probe counted the cast: %s" % line)
	@warning_ignore("integer_division")
	var ready_days: int = OPENING_PORTIONS * 1000 / (2 * maxi(residents, 1))
	assert_equal(line, "OPENING wheat=%d carrot=%d ready_days_milli=%d harvested=0 residents=%d" % [WHEAT_MILLI,
		CARROT_MILLI, ready_days, residents], "what the village opened with: %s" % line)
