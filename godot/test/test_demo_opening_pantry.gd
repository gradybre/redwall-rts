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
const TakesScript := preload("res://demo/kitchen/ingredient_takes.gd")

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


func test_what_is_left_of_the_opening_stock_is_counted_on_its_lots() -> void:
	"""Decisions 0902 and 0994: the opening stock left is the opening share its lots still hold, as plain-dish portions
	-- 72 at the start; 2 U of the opening wheat withdrawn leaves 70; food brought in is never counted."""
	var pantry := PantryScript.new(StorageScript.new(Vector2.ZERO))
	assert_equal(OpeningScript.portions_left(pantry), 0, "no stock, nothing left")
	OpeningScript.stock(pantry, null, 6)
	assert_equal(OpeningScript.portions_left(pantry), 72, "the whole opening stock")
	var read := IntMath.IntResult.new()
	var wheat: int = _item(&"wheat")
	for lot: int in PantryScript.MAX_LOTS:
		if pantry.lot_item(lot) == wheat:
			assert_true(pantry.withdraw_into(lot, pantry.lot_serial(lot), 2000, read), "2 U of wheat withdrawn")
			break
	assert_equal(OpeningScript.left_milli(pantry, 0), WHEAT_MILLI - 2000, "38 U of wheat left")
	assert_equal(OpeningScript.portions_left(pantry), 70, "a porridge batch fewer")
	pantry.add_into(wheat, 80000, 0, read)
	assert_equal(OpeningScript.portions_left(pantry), 70, "food brought in is not the opening stock")


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


# --- opening provenance on the lots (decision 0994; the review's R02) ------------------------------------------------

const COVERED: int = 0
const CELLAR: int = 1
## Hours the opening carrots age in the covered store before they are moved, so they are the OLDER lot.
const AGED_HOURS: int = 24


func _cellar_pantry() -> PantryScript:
	"""The covered store (1000 per mille) and a GDD cellar (350 per mille) with room for all the carrots."""
	var storage := StorageScript.new(Vector2(-4.0, 0.0))
	storage.add_provider(func() -> Array: return [{"id": &"cellar", "position": Vector2(4.0, 0.0), "capacity_u": 100,
		"label": "Root cellar", "spoilage_permille": 350}])
	return PantryScript.new(storage)


func _lot_of(pantry: PantryScript, item: int, location: int) -> int:
	"""The first lot row of `item` at `location` (-1: none)."""
	for lot: int in PantryScript.MAX_LOTS:
		if pantry.lot_item(lot) == item and pantry.lot_location(lot) == location:
			return lot
	return -1


func _move(pantry: PantryScript, lot: int, milli: int, to: int) -> int:
	"""Carry `milli` of lot `lot` into store `to` by the pantry's own move (decision 0611); the row set down."""
	var read := IntMath.IntResult.new()
	assert_true(pantry.reserve_at_into(pantry.lot_item(lot), milli, to, read), "room held at the destination")
	var hold: int = read.value
	assert_true(pantry.begin_carry_into(lot, pantry.lot_serial(lot), milli, read), "picked up")
	var carried: int = read.value
	assert_true(pantry.set_down_into(carried, pantry.lot_serial(carried), hold, read) and read.value == milli, "set down")
	return carried


func _opening_in_cellar_young_harvest_warm() -> PantryScript:
	"""The review's case: the opening carrots aged a day, then moved into the cool cellar; 20 U of younger harvested
	carrots then received into the warm covered store."""
	var pantry := _cellar_pantry()
	OpeningScript.stock(pantry, null, 6)
	for _h: int in AGED_HOURS:
		pantry.age_hour(0)
	var carrot: int = _item(&"carrot")
	_move(pantry, _lot_of(pantry, carrot, COVERED), CARROT_MILLI, CELLAR)
	var read := IntMath.IntResult.new()
	assert_true(pantry.add_into(carrot, 20000, COVERED, read), "a younger harvest in the warm store")
	assert_true(pantry.lot_age(_lot_of(pantry, carrot, CELLAR)) > pantry.lot_age(read.value), "the opening lot older")
	return pantry


func test_the_kitchen_cooking_a_younger_warm_lot_first_leaves_the_opening_lot_counted() -> void:
	"""The younger warm lot spoils first, so the cook's batch takes it (expiry first, decision 0381): the opening carrots
	in the cellar are untouched and all 50 U still count -- the old ledger would have said 48."""
	var pantry := _opening_in_cellar_young_harvest_warm()
	var carrot: int = _item(&"carrot")
	var takes := TakesScript.new()
	var take: int = takes.new_take()
	var read := IntMath.IntResult.new()
	var selector: int = TakesScript.items_selector(PackedInt32Array([carrot]))
	assert_true(takes.reserve_into(pantry, take, selector, 2000, AGED_HOURS, read) and read.value == 2000, "reserved")
	assert_true(takes.consume_into(pantry, take, 2000, TakesScript.AT_STORE, AGED_HOURS, read), "cooked")
	assert_equal(pantry.milli_at(carrot, COVERED), 18000, "taken from the younger warm lot")
	assert_equal(pantry.milli_at(carrot, CELLAR), CARROT_MILLI, "the opening carrots untouched")
	assert_equal(OpeningScript.left_milli(pantry, 1), CARROT_MILLI, "all 50 U of opening carrots still counted")
	assert_equal(CARROT_MILLI - pantry.withdrawn_total_milli(carrot), 48000, "where the ledger would have said 48")


func test_the_younger_warm_lot_spoiling_first_leaves_the_opening_lot_counted() -> void:
	"""The younger warm lot spoils first: the opening carrots still in the cellar all still count; once they spoil too,
	none do."""
	var pantry := _opening_in_cellar_young_harvest_warm()
	var carrot: int = _item(&"carrot")
	var hours: int = 0
	while pantry.milli_at(carrot, COVERED) > 0 and hours < 100000:
		pantry.age_hour(0)
		hours += 1
	assert_equal(pantry.spoiled_total_milli(carrot), 20000, "the warm lot spoiled")
	assert_equal(pantry.milli_at(carrot, CELLAR), CARROT_MILLI, "the opening lot not yet")
	assert_equal(OpeningScript.left_milli(pantry, 1), CARROT_MILLI, "all of it still counted")
	while pantry.milli_at(carrot, CELLAR) > 0 and hours < 100000:
		pantry.age_hour(0)
		hours += 1
	assert_equal(OpeningScript.left_milli(pantry, 1), 0, "spoiled in turn: none left")
	assert_equal(pantry.opening_milli_of(carrot), 0, "no opening share on a freed row")


func test_a_split_carry_and_a_withdrawal_move_the_opening_share_exactly() -> void:
	"""A carry that splits a lot moves its share with it; a withdrawal from a wholly opening lot takes its own milli-U
	of share; nothing is lost or made between the rows."""
	var pantry := _cellar_pantry()
	OpeningScript.stock(pantry, null, 6)
	var carrot: int = _item(&"carrot")
	var source: int = _lot_of(pantry, carrot, COVERED)
	var moved: int = _move(pantry, source, 20000, CELLAR)
	assert_equal([pantry.lot_opening_milli(moved), pantry.lot_opening_milli(source)], [20000, 30000], "split 20 / 30")
	var read := IntMath.IntResult.new()
	assert_true(pantry.withdraw_into(moved, pantry.lot_serial(moved), 7000, read), "7 U withdrawn")
	assert_equal(pantry.opening_milli_of(carrot), 43000, "43 U of opening carrots left")
	assert_true(pantry.withdraw_into(moved, pantry.lot_serial(moved), 13000, read), "the rest of that lot")
	assert_equal(pantry.lot_opening_milli(moved), 0, "an emptied row holds no share")
	assert_equal(OpeningScript.left_milli(pantry, 1), 30000, "30 U left")


func test_a_delivery_merged_into_an_opening_lot_shares_its_withdrawals_proportionally() -> void:
	"""With every row taken a delivery merges into the opening lot (§5.8): the lot is 50 U opening of 60; 6 U withdrawn
	takes 5 U of opening share (proportional, floored), and the share never exceeds the lot."""
	var pantry := _cellar_pantry()
	OpeningScript.stock(pantry, null, 6)
	var read := IntMath.IntResult.new()
	var radish: int = _item(&"radish")
	while pantry.lot_count() < PantryScript.MAX_LOTS:
		assert_true(pantry.add_into(radish, 1, CELLAR, read), "a row taken")
	var carrot: int = _item(&"carrot")
	assert_true(pantry.add_into(carrot, 10000, COVERED, read), "merged into the opening lot")
	var lot: int = read.value
	assert_equal([pantry.lot_milli(lot), pantry.lot_opening_milli(lot)], [60000, 50000], "50 of 60 U opening")
	assert_true(pantry.withdraw_into(lot, pantry.lot_serial(lot), 6000, read), "6 U withdrawn")
	assert_equal(pantry.lot_opening_milli(lot), 45000, "5 U of it opening")
	assert_true(pantry.withdraw_into(lot, pantry.lot_serial(lot), 1, read), "1 milli-U withdrawn")
	assert_equal(pantry.lot_opening_milli(lot), 45000, "its share floors to nothing")
	assert_equal(pantry.opening_share(lot, pantry.lot_milli(lot)), 45000, "the whole lot carries the whole share")
	assert_equal(pantry.opening_share(lot, 0), 0, "nothing carries nothing")
	assert_equal(pantry.opening_share(-1, 5), 0, "no such row")
