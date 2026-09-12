extends "res://test/framework/test_case.gd"
## Coverage for the settlement stores: integer lots, container mass, and derived nutrition.
##
## ARCH-MIG-006 step 5 replaced the float stockpile model. Sixteen prototype tests are gone;
## eleven have replacements here and five retire outright, each recorded in
## docs/tasks/02_test_migration_ledger.md:
##
##   RETIRED, defect class removed by integers:
##     * test_small_rates_are_not_discarded_at_high_stock -- guarded float epsilon starvation.
##       Integer milli-units have no magnitude-scaled dead band.
##     * test_exactly_affordable_cost_is_payable_after_float_accumulation -- guarded
##       SPEND_TOLERANCE, a workaround for float accumulation error. The integer analogue is
##       test_repeated_small_deposits_stay_exact, which needs no tolerance at all.
##   RETIRED, behaviour the specification contradicts:
##     * test_add_resource_clamps_at_cap -- the prototype silently clamped at a flat cap of
##       500, destroying goods. REQ-SET-110/120 require an explicit refusal instead; the
##       contract is INVERTED in test_deposit_over_container_mass_is_refused_not_clamped.
##     * test_set_cap_clamps_existing_stockpile and
##       test_lowering_a_cap_does_not_report_depletion -- there is no per-resource cap to
##       lower. Capacity is a container's mass in grams, and REQ-SET-120 forbids deleting
##       stored resources to fit a smaller store.
##   RETIRED, modelled work that does not exist:
##     * test_tick_applies_net_rates -- invented per-second production rates. Production comes
##       from jobs and recipes, which this milestone does not build, so there is no tick to
##       test and no replacement.
##
## GDD §7.1's starter food fixture and §5.9's two container masses are used as acceptance
## fixtures: both are independently restated here rather than read back from the code.

const EconomySystemScript := preload("res://scripts/systems/economy_system.gd")
const InventoryScript := preload("res://scripts/core/inventory.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const BuildingDefinitionsScript := preload("res://scripts/core/building_definitions.gd")
const CatalogScript := preload("res://scripts/core/catalog.gd")

## GDD §5.1's built fixture: "four open stockpiles", and §5.9's "Four pantry shelves". Restated
## here from the specification rather than read out of `building_definitions.gd`.
const STARTER_OPEN_STOCKPILES: int = 4
const STARTER_PANTRY_SHELVES: int = 4

const SUMMARY_BUDGET_USEC: int = 2000
const MILLI: int = 1000

## The authoritative catalog, spliced into fixture copies. Never written to.
const REAL_CATALOG_PATH: String = "res://data/item_definitions.json"

## A fixture-only item: a SEED row that is also raw-edible and nutritious. No authoritative row
## is both, which is exactly why the §5.8 seed exclusion needs one to be tested at all.
const EDIBLE_SEED_KEY: StringName = &"zz_fixture_edible_seed"
const EDIBLE_SEED_NUTRITION_PER_U: int = 900

## GDD §5.1 "Initial inventory U", restated independently of main.gd.
const STARTING_INVENTORY_U: Dictionary = {
	&"wood": 180, &"stone": 100, &"iron": 20, &"rope": 20, &"tool": 24, &"cloth": 24,
	&"water": 60, &"grain": 80, &"roots": 80, &"berries": 40, &"nuts": 40,
	&"dried_fish": 60, &"ration": 60, &"seed_grain": 32, &"seed_roots": 32,
	&"seed_beans": 16, &"seed_cabbage": 16, &"seed_flax": 16, &"herb": 12, &"compost": 32,
}

## GDD §7.1: 60 ration x2400 + 60 dried_fish x1800 + 80 roots x800 + 40 berries x700
## + 40 nuts x1600. Grain is potential food, not ready food, and is excluded.
const STARTER_READY_NP: int = 408000

## GDD §7.1 starter fixture, the rest of the sentence: "10 small and 2 medium residents consume
## 74400 NP/day, thus 5.48 ready food-days at start".
const STARTER_DEMAND_NP: int = 74400
const STARTER_FOOD_DAYS_CENTI: int = 548
const STARTER_FOOD_DAYS_TEXT: String = "5.48"

var _economy: EconomySystemScript = null
var _residents: ResidentsScript = null
var _depleted: Array[StringName] = []
var _changes: int = 0


func before_each() -> void:
	"""Build a fresh economy system and listen for its UI signals."""
	_economy = EconomySystemScript.new()
	_residents = null
	_depleted = []
	_changes = 0
	_economy.stock_depleted.connect(_on_stock_depleted)
	_economy.stocks_changed.connect(_on_stocks_changed)


func after_each() -> void:
	"""Free the economy system built for the test."""
	_residents = null
	if _economy != null:
		_economy.free()
		_economy = null


func _bind_starting_settlement() -> void:
	"""Seed the §5.1 stores and bind the §5.1 starting cohort, the full §7.1 starter fixture."""
	_seed_starting_inventory()
	_residents = ResidentsScript.new()
	var spawned: ResidentsScript.OpResult = _residents.spawn_initial_settlement()
	if not spawned.ok:
		fail("the starting settlement was refused: %s" % spawned.error)
	_economy.bind_residents(_residents)


func _seed_starting_inventory() -> void:
	"""Deposit the whole GDD §5.1 starting inventory, failing the test on any refusal."""
	for item_key: StringName in STARTING_INVENTORY_U:
		var units: int = STARTING_INVENTORY_U[item_key]
		if not _economy.deposit(item_key, units * MILLI):
			fail("starting inventory refused for %s: %s" % [item_key, _economy.last_refusal()])


func test_catalog_is_loaded_into_open_stores() -> void:
	"""All 60 authoritative items register, and both GDD §5.9 stores open."""
	assert_equal(_economy.catalog_error(), "", "the catalog loaded")
	assert_equal(_economy.item_count(), 61, "all 61 catalog rows are registered")
	assert_true(_economy.inventory().is_container_valid(_economy.pantry()), "the pantry is open")
	assert_true(_economy.inventory().is_container_valid(_economy.material_store()), "the store is open")


func test_starts_with_empty_stores() -> void:
	"""Every item begins at zero and no nutrition is on hand."""
	assert_equal(_economy.stock_milli(&"ration"), 0, "ration starts empty")
	assert_equal(_economy.stock_milli(&"wood"), 0, "wood starts empty")
	assert_equal(_economy.ready_nutrition_points(), 0, "no ready nutrition at start")
	assert_equal(_economy.inventory().live_lot_count(), 0, "no lots exist yet")


func test_deposit_accumulates_into_one_stack() -> void:
	"""Repeated deposits of an identical item merge instead of consuming a lot row each time."""
	assert_true(_economy.deposit(&"wood", 25 * MILLI), "first deposit accepted")
	assert_true(_economy.deposit(&"wood", 15 * MILLI), "second deposit accepted")
	assert_equal(_economy.stock_milli(&"wood"), 40 * MILLI, "wood accumulated")
	assert_equal(_economy.inventory().live_lot_count(), 1, "both deposits share one lot")
	assert_equal(_changes, 2, "each change was signalled once")


func test_repeated_small_deposits_stay_exact() -> void:
	"""Ten deposits of 0.1 U buy exactly 1 U, with no tolerance anywhere in the path.

	This is the integer replacement for the two retired float tests: the quantities are
	milli-units, so accumulation is exact and an exactly-affordable cost is always payable.
	"""
	for index: int in 10:
		_economy.deposit(&"wood", 100)
	assert_equal(_economy.stock_milli(&"wood"), MILLI, "ten tenths are exactly one unit")
	assert_true(_economy.withdraw(&"wood", MILLI), "the exact cost is affordable")
	assert_equal(_economy.stock_milli(&"wood"), 0, "the stack is spent out exactly")


func test_deposit_refuses_non_positive_quantity() -> void:
	"""Zero and negative deposits are refused rather than silently draining a store."""
	_economy.deposit(&"wood", 10 * MILLI)
	assert_false(_economy.deposit(&"wood", -5 * MILLI), "a negative deposit is refused")
	assert_equal(_economy.last_refusal(), InventoryScript.REFUSE_INVALID_QUANTITY, "refusal is explicit")
	assert_equal(_economy.stock_milli(&"wood"), 10 * MILLI, "wood is unchanged")


func test_unknown_item_is_refused_not_ignored() -> void:
	"""A key outside the 60-row catalog is refused explicitly and stores nothing."""
	assert_false(_economy.is_known_item(&"moonlight"), "moonlight is not a catalog item")
	assert_false(_economy.deposit(&"moonlight", MILLI), "an unknown item cannot be deposited")
	assert_equal(_economy.last_refusal(), InventoryScript.REFUSE_UNKNOWN_ITEM, "refusal names the cause")
	assert_equal(_economy.stock_milli(&"moonlight"), 0, "an unknown item reads zero")
	assert_false(_economy.withdraw(&"moonlight", MILLI), "an unknown item cannot be withdrawn")


func test_deposit_over_container_mass_is_refused_not_clamped() -> void:
	"""INVERTED CONTRACT: the prototype clamped at a flat cap; capacity now refuses.

	REQ-SET-110/120: insufficient capacity stops the operation with a diagnostic and never
	deletes or silently discards goods.
	"""
	var wood_units: int = EconomySystemScript.MATERIAL_STORE_MAX_MASS_G / 5000
	assert_true(_economy.deposit(&"wood", wood_units * MILLI), "the store fills exactly")
	assert_false(_economy.deposit(&"wood", MILLI), "one unit past capacity is refused")
	assert_equal(_economy.last_refusal(), InventoryScript.REFUSE_CAPACITY_EXCEEDED, "refusal is explicit")
	assert_equal(_economy.stock_milli(&"wood"), wood_units * MILLI, "nothing was clamped away")


func test_withdraw_spends_when_affordable() -> void:
	"""An affordable cost is deducted and reported as paid."""
	_economy.deposit(&"nuts", 50 * MILLI)
	assert_true(_economy.withdraw(&"nuts", 20 * MILLI), "the withdrawal succeeds")
	assert_equal(_economy.stock_milli(&"nuts"), 30 * MILLI, "nuts were deducted")


func test_withdraw_is_all_or_nothing() -> void:
	"""An unaffordable cost leaves every lot untouched."""
	_economy.deposit(&"nuts", 10 * MILLI)
	assert_false(_economy.withdraw(&"nuts", 25 * MILLI), "the withdrawal fails")
	assert_equal(_economy.last_refusal(), InventoryScript.REFUSE_INSUFFICIENT_UNRESERVED, "refusal is explicit")
	assert_equal(_economy.stock_milli(&"nuts"), 10 * MILLI, "nothing was spent")
	assert_false(_economy.inventory().is_transaction_open(), "the transaction was closed")


func test_withdraw_never_drives_stock_negative() -> void:
	"""Draining an empty store is refused rather than producing negative stock."""
	assert_false(_economy.withdraw(&"nuts", 5 * MILLI), "an empty store cannot be drained")
	assert_equal(_economy.stock_milli(&"nuts"), 0, "stock floors at zero")


func test_withdraw_spans_several_lots() -> void:
	"""A withdrawal larger than any single lot drains across lots without cloning quantity."""
	_economy.deposit(&"nuts", 10 * MILLI)
	_economy.inventory().create_lot(_economy.pantry(), _economy.definitions().compiled_id(&"nuts"),
		10 * MILLI, 5000, 0, 0, 0, 0)
	assert_equal(_economy.inventory().live_lot_count(), 2, "two lots hold the nuts")
	assert_true(_economy.withdraw(&"nuts", 15 * MILLI), "the withdrawal spans both lots")
	assert_equal(_economy.stock_milli(&"nuts"), 5 * MILLI, "exactly the requested amount left")


func test_depletion_signals_once_per_drain() -> void:
	"""Emptying an item raises stock_depleted once; a refused re-drain does not repeat it."""
	_economy.deposit(&"nuts", 5 * MILLI)
	_economy.withdraw(&"nuts", 5 * MILLI)
	_economy.withdraw(&"nuts", 5 * MILLI)
	assert_equal(_depleted.size(), 1, "depletion signalled exactly once")
	assert_equal(_depleted[0], &"nuts", "nuts is the depleted item")


func test_food_and_materials_route_to_their_own_stores() -> void:
	"""Category filters put food in the pantry and materials in the stockpile store."""
	_economy.deposit(&"ration", 10 * MILLI)
	_economy.deposit(&"wood", 10 * MILLI)
	assert_equal(_economy.store_used_mass_g(_economy.pantry()), 5000, "10 ration U is 5000 g of pantry")
	assert_equal(_economy.store_used_mass_g(_economy.material_store()), 50000, "10 wood U is 50000 g of store")


func test_starting_inventory_fits_the_specified_container_masses() -> void:
	"""GDD §5.9: the starting inventory fits the pantry and the four stockpiles as specified."""
	_seed_starting_inventory()
	var pantry_used: int = _economy.store_used_mass_g(_economy.pantry())
	var store_used: int = _economy.store_used_mass_g(_economy.material_store())
	assert_equal(pantry_used, 179200, "starting food masses 179200 g")
	assert_equal(store_used, 1512000, "starting materials mass 1512000 g")
	assert_true(pantry_used <= EconomySystemScript.PANTRY_MAX_MASS_G, "starting food fits the pantry")
	assert_true(store_used <= EconomySystemScript.MATERIAL_STORE_MAX_MASS_G, "materials fit the stockpiles")


func test_ready_nutrition_reproduces_the_gdd_starter_fixture() -> void:
	"""GDD §7.1: the starting stores hold exactly 408000 ready nutrition points."""
	_seed_starting_inventory()
	assert_equal(_economy.ready_nutrition_points(), STARTER_READY_NP, "starter ready NP is 408000")


func test_seeds_and_raw_ingredients_are_excluded_from_ready_nutrition() -> void:
	"""GDD §5.8 excludes seeds and raw inedible ingredients from ready food."""
	_economy.deposit(&"seed_grain", 32 * MILLI)
	_economy.deposit(&"grain", 80 * MILLI)
	_economy.deposit(&"carp", 10 * MILLI)
	assert_equal(_economy.ready_nutrition_points(), 0, "none of these are ready food")
	_economy.deposit(&"nuts", 10 * MILLI)
	assert_equal(_economy.ready_nutrition_points(), 16000, "only the directly edible nuts count")


func _catalog_with_edible_seed() -> String:
	"""Write a copy of the real catalog with one added SEED row that IS edible and nutritious.

	Every seed in the authoritative catalog also carries raw_edible=0 and nutrition_per_u=0, so
	the live rows cannot tell the §5.8 seed exclusion apart from the raw-edible test that
	follows it: deleting the seed clause changes no number anywhere. This fixture separates
	them. It is not a prediction of a balance change; it is the only way to hold the clause the
	specification states twice (§5.8 "excludes seeds", REQ-SET-013 "never consuming seed items")
	to its own contract, independent of a catalog row that happens to agree.
	"""
	var payload: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(REAL_CATALOG_PATH)) as Dictionary
	var items: Array = payload["items"]
	items.append({
		"id": String(EDIBLE_SEED_KEY), "category": "SEED", "mass_g": 100,
		"nutrition_per_u": EDIBLE_SEED_NUTRITION_PER_U, "shelf_hours": 0,
		"raw_edible": 1, "seed": 1, "effect": "NONE", "effect_value": 0,
	})
	var path: String = "user://test_economy_edible_seed_catalog.json"
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(payload))
	file.close()
	return path


func test_a_nutritious_seed_is_still_excluded_because_it_is_a_seed() -> void:
	"""GDD §5.8 / REQ-SET-013: seed stock is never food, whatever its nutrition row says."""
	_economy.reset(_catalog_with_edible_seed())
	assert_equal(_economy.catalog_error(), "", "the fixture catalog opened the stores")
	assert_true(_economy.is_known_item(EDIBLE_SEED_KEY), "the edible seed registered")
	assert_true(_economy.definitions().is_seed(_economy.definitions().compiled_id(EDIBLE_SEED_KEY)),
		"the fixture row really is a seed")
	assert_true(_economy.definitions().is_raw_edible(_economy.definitions().compiled_id(EDIBLE_SEED_KEY)),
		"and it really is raw-edible, unlike every authoritative seed row")
	assert_true(_economy.deposit(EDIBLE_SEED_KEY, 10 * MILLI), "the seed stock is stored")
	assert_equal(_economy.stock_units(EDIBLE_SEED_KEY), 10, "ten units are in the pantry")
	assert_equal(_economy.ready_nutrition_points(), 0,
		"seed stock contributes nothing to ready food even when it is edible and nutritious")
	assert_true(_economy.deposit(&"nuts", 10 * MILLI), "genuinely ready food is stored beside it")
	assert_equal(_economy.ready_nutrition_points(), 16000,
		"only the nuts count; the seed row is still excluded alongside them")


func test_reserved_food_is_excluded_from_ready_nutrition() -> void:
	"""GDD §5.8 excludes locked reservations from ready food-days."""
	_economy.deposit(&"nuts", 10 * MILLI)
	var lot: Vector2i = _economy.inventory().container_first_lot(_economy.pantry())
	_economy.inventory().reserve_lot(lot, 4 * MILLI)
	_economy.recompute_summary()
	assert_equal(_economy.ready_nutrition_points(), 9600, "only the 6 unreserved units count")


func test_expired_food_is_excluded_from_ready_nutrition() -> void:
	"""GDD §5.8: food whose effective age reached shelf_hours x 1000 is not ready food.

	Nothing ages lots yet, so this is exercised by writing the aged lot directly.
	"""
	var berries: int = _economy.definitions().compiled_id(&"berries")
	var shelf_milli_hours: int = _economy.definitions().shelf_hours(berries) * 1000
	_economy.inventory().create_lot(_economy.pantry(), berries, 10 * MILLI, 0, 0, 0, shelf_milli_hours, 0)
	_economy.recompute_summary()
	assert_equal(_economy.ready_nutrition_points(), 0, "expired berries are not ready food")


func test_reset_returns_to_empty_stores() -> void:
	"""reset() clears every lot, reopens the stores, and drops the borrowed residents store.

	The binding must go with the stock. A reset that kept it would divide the reloaded, empty
	stores by the previous run's population, which is a wrong food-days figure on screen rather
	than an honestly absent one.
	"""
	_bind_starting_settlement()
	assert_true(_economy.has_residents(), "the cohort is bound before the reset")
	assert_equal(_economy.food_days_text(), STARTER_FOOD_DAYS_TEXT, "and food-days is populated")
	_economy.reset()
	assert_equal(_economy.inventory().live_lot_count(), 0, "every lot was cleared")
	assert_equal(_economy.stock_milli(&"wood"), 0, "wood is empty")
	assert_equal(_economy.ready_nutrition_points(), 0, "the derived summary was cleared too")
	assert_equal(_economy.item_count(), 61, "the catalog is registered again")
	assert_false(_economy.has_residents(), "the stale residents binding was dropped")
	assert_false(_economy.daily_demand_np().ok, "the divisor is refused, not stale")
	assert_equal(_economy.daily_demand_np().error, String(EconomySystemScript.REFUSE_NO_RESIDENT_STORE),
		"the refusal names the missing store")
	assert_equal(_economy.food_days_text(), "--",
		"food-days is unpopulated after a reset, never the previous run's figure")


func test_stores_conserve_quantity_across_a_sequence() -> void:
	"""Deposits, withdrawals and merges keep live + sunk == sourced for every item."""
	_seed_starting_inventory()
	_economy.withdraw(&"wood", 55 * MILLI)
	_economy.deposit(&"wood", 5 * MILLI)
	_economy.withdraw(&"ration", 60 * MILLI)
	_economy.deposit(&"nuts", 7 * MILLI)
	assert_true(_economy.inventory().audit().ok, "the inventory audit passes")
	assert_equal(_economy.stock_milli(&"wood"), 130 * MILLI, "wood balances")
	assert_equal(_economy.stock_milli(&"ration"), 0, "ration is spent out")


func test_summary_recompute_stays_within_budget() -> void:
	"""Re-deriving the stock summary over the starting stores costs less than 2 ms."""
	_seed_starting_inventory()
	_economy.recompute_summary()
	assert_less_than(_economy.get_last_summary_usec(), SUMMARY_BUDGET_USEC, "recompute is under 2ms")


func _on_stock_depleted(item_key: StringName) -> void:
	"""Record a depletion signal for assertion."""
	_depleted.append(item_key)


func _on_stocks_changed() -> void:
	"""Count committed-change signals for assertion."""
	_changes += 1


# --- GDD §5.8 food-days ------------------------------------------------------------------------

func test_food_days_is_unpopulated_without_a_residents_store() -> void:
	"""No population means no divisor. §5.8 gets a refusal, never a placeholder number."""
	_seed_starting_inventory()
	assert_false(_economy.has_residents(), "nothing supplies a population")
	var centi: IntMath.IntResult = _economy.food_days_centi()
	assert_false(centi.ok, "food-days is refused")
	assert_equal(centi.error, String(EconomySystemScript.REFUSE_NO_RESIDENT_STORE), "the refusal names the cause")
	assert_equal(centi.value, 0, "a refusal carries no usable value")
	assert_equal(_economy.food_days_text(), "--", "the display stays unpopulated")


func test_food_days_is_unpopulated_while_nobody_is_alive() -> void:
	"""A bound but empty settlement still has no divisor; the numerator alone is not food-days."""
	_seed_starting_inventory()
	_residents = ResidentsScript.new()
	_economy.bind_residents(_residents)
	assert_true(_economy.has_residents(), "a residents store is bound")
	assert_false(_economy.daily_demand_np().ok, "an empty settlement has no daily demand")
	assert_equal(_economy.food_days_text(), "--", "food-days remains unpopulated")
	assert_equal(_economy.ready_nutrition_points(), STARTER_READY_NP, "the numerator is still there")


func test_food_days_reproduces_the_gdd_starter_fixture() -> void:
	"""GDD §7.1: 408000 ready NP over 74400 NP/day is 5.48 ready food-days at start."""
	_bind_starting_settlement()
	assert_equal(_economy.ready_nutrition_points(), STARTER_READY_NP, "the numerator is 408000")
	assert_equal(_economy.daily_demand_np().value, STARTER_DEMAND_NP, "the divisor is 74400")
	var centi: IntMath.IntResult = _economy.food_days_centi()
	assert_true(centi.ok, "food-days is computable")
	assert_equal(centi.value, STARTER_FOOD_DAYS_CENTI, "food-days is 548 hundredths")
	assert_equal(_economy.food_days_text(), STARTER_FOOD_DAYS_TEXT, "displayed to two decimals")


func test_food_days_truncates_rather_than_rounds() -> void:
	"""§5.8 writes floor(100*NP/demand)/100: 548.38 hundredths displays as 5.48, never 5.49."""
	_bind_starting_settlement()
	assert_equal(STARTER_READY_NP * 100 / STARTER_DEMAND_NP, 548, "the exact quotient floors to 548")
	assert_true(STARTER_READY_NP * 100 % STARTER_DEMAND_NP > 0, "the quotient is not exact")
	assert_equal(_economy.food_days_text(), "5.48", "the discarded remainder is not rounded up")


func test_food_days_uses_the_winter_demand_multiplier() -> void:
	"""GDD §5.8: the divisor uses today's season multiplier, which §5.2 sets to x1.20 in winter."""
	_bind_starting_settlement()
	assert_true(_residents.set_winter(true).ok, "winter arrives")
	assert_equal(_economy.daily_demand_np().value, 89280, "winter demand is 74400 x 1.20")
	assert_equal(_economy.food_days_centi().value, 456, "the same stores now cover 4.56 days")
	assert_equal(_economy.food_days_text(), "4.56", "the display followed the season")


func test_food_days_excludes_reserved_and_inedible_stock() -> void:
	"""The numerator stays §5.8's: seeds, raw ingredients and reservations never inflate it."""
	_residents = ResidentsScript.new()
	_residents.spawn(&"mouse")
	_economy.bind_residents(_residents)
	_economy.deposit(&"nuts", 10 * MILLI)
	_economy.deposit(&"grain", 100 * MILLI)
	_economy.deposit(&"seed_grain", 100 * MILLI)
	assert_equal(_economy.food_days_centi().value, 266, "10 nuts U is 16000 NP over 6000 NP/day")
	var lot: Vector2i = _find_lot(&"nuts")
	assert_true(_economy.inventory().reserve_lot(lot, 5 * MILLI).ok, "half the nuts are reserved")
	_economy.recompute_summary()
	assert_equal(_economy.food_days_centi().value, 133, "reserving half the nuts halves food-days")


func _find_lot(item_key: StringName) -> Vector2i:
	"""The first pantry lot holding one item, so a test never assumes container link order."""
	var item_id: int = _economy.definitions().compiled_id(item_key)
	var lot: Vector2i = _economy.inventory().container_first_lot(_economy.pantry())
	while lot != InventoryScript.NULL_REF:
		if _economy.inventory().lot_item_id(lot) == item_id:
			return lot
		lot = _economy.inventory().container_next_lot(lot)
	fail("no %s lot in the pantry" % item_key)
	return InventoryScript.NULL_REF


func test_food_days_falls_as_the_population_grows() -> void:
	"""The divisor is live: an arriving resident lowers food-days without any stock changing."""
	_bind_starting_settlement()
	var before: int = _economy.food_days_centi().value
	assert_true(_residents.spawn(&"badger").ok, "a large resident joins")
	var after: IntMath.IntResult = _economy.food_days_centi()
	assert_equal(_economy.daily_demand_np().value, STARTER_DEMAND_NP + 9600, "a large resident adds 9600")
	assert_true(after.value < before, "the same stores now cover fewer days")
	assert_equal(after.value, 485, "408000 NP over 84000 NP/day is 4.85 days")


func test_unbinding_returns_food_days_to_unpopulated() -> void:
	"""Losing the population source must return the counter to "--", not freeze a stale figure."""
	_bind_starting_settlement()
	assert_true(_economy.food_days_centi().ok, "food-days is populated while bound")
	_economy.bind_residents(null)
	assert_false(_economy.has_residents(), "the store was unbound")
	assert_equal(_economy.food_days_text(), "--", "the counter returns to unpopulated")


func test_fuel_days_stays_unpopulated_and_names_its_missing_input() -> void:
	"""GDD §5.8 fuel-days needs a heating demand no implemented system supplies."""
	_bind_starting_settlement()
	_economy.deposit(&"wood", 100 * MILLI)
	assert_equal(_economy.fuel_days_text(), "--", "fuel-days is not computable")
	assert_true(_economy.fuel_days_missing_input().contains("heating demand"),
		"the missing input is named rather than approximated")
	assert_true(_economy.stock_units(&"wood") > 0, "wood stock alone is not a fuel forecast")


func test_food_days_computation_stays_within_budget() -> void:
	"""Deriving food-days over a full 256-resident settlement costs less than 2 ms."""
	_seed_starting_inventory()
	_residents = ResidentsScript.new()
	for index: int in ResidentsScript.RESIDENT_LIVING_CAP:
		if not _residents.spawn(&"mouse").ok:
			fail("spawn %d refused" % index)
			return
	_economy.bind_residents(_residents)
	assert_true(_economy.food_days_centi().ok, "food-days is computable at the living cap")
	assert_less_than(_economy.get_last_food_days_usec(), SUMMARY_BUDGET_USEC, "under 2ms at 256 residents")


# --- the §5.9 container masses now have a store that states them (decision 0087) ----------------

func test_the_material_store_mass_is_four_open_stockpiles_own_capacity() -> void:
	"""§5.9's "Four stockpiles provide 1600000g" is 4 x BAL-CAT-006's `base_store_g` of 400000.

	These two containers were opened against a sentence copied out of §5.9, because no module
	published a building's declared capacity. `building_definitions.gd` does now, and
	`settlement_system.gd` composes the store that owns it, so the constant can be checked
	against the very number `place_building()` would attach to a placed stockpile.

	THE CONSTANT IS NOT REPLACED BY THE LOOKUP. Nothing places a stockpile yet -- §7.2's starter
	build does not exist -- so deriving the mass from zero placed buildings would open a
	zero-gram store. The agreement is asserted instead, which is what catches a later drift.
	"""
	var definitions: BuildingDefinitionsScript = BuildingDefinitionsScript.new()
	var stockpile: int = int(CatalogScript.BUILDING_DEFINITION["open_stockpile"])
	assert_equal(definitions.base_store_g_of(stockpile) * STARTER_OPEN_STOCKPILES,
		EconomySystemScript.MATERIAL_STORE_MAX_MASS_G,
		"four open stockpiles supply exactly the material store's mass")


func test_the_pantry_mass_is_four_shelves_own_pantry_capacity() -> void:
	"""§5.9's "Four pantry shelves supply 200000g storage" is 4 x BAL-CAT-006's 50000 g shelf.

	The fifth, kitchen-owned starter shelf is deliberately NOT counted: R-BUILD-DOM-004 keeps it
	out of the pantry service and `buildings.pantry_capacity_g_of_room()` refuses a non-pantry
	room rather than folding it in. Four is the number §5.9 states and four is what this asserts.
	"""
	var definitions: BuildingDefinitionsScript = BuildingDefinitionsScript.new()
	var shelf: int = int(CatalogScript.FURNITURE_DEFINITION["shelf"])
	assert_equal(definitions.shelf_capacity_g_of(shelf) * STARTER_PANTRY_SHELVES,
		EconomySystemScript.PANTRY_MAX_MASS_G,
		"four pantry shelves supply exactly the pantry's mass")
