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
## GDD §7.1's starter food fixture and §5.9's container masses are used as acceptance fixtures:
## both are independently restated here rather than read back from the code.
##
## DECISION 0533 (DEMO-CONTAIN-R01 D3): the stores open only when bound to real owners. Every test
## below runs against stores bound to a `starter_colony_fixture.gd` colony -- the hall owns the
## pantry, the four open stockpiles own four 400000 g material stores -- and the fill order is
## §5.9's "food first, then item ID, filling container IDs ascending".

const EconomySystemScript := preload("res://scripts/systems/economy_system.gd")
const InventoryScript := preload("res://scripts/core/inventory.gd")
const ItemDefinitionsScript := preload("res://scripts/core/item_definitions.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const BuildingDefinitionsScript := preload("res://scripts/core/building_definitions.gd")
const CatalogScript := preload("res://scripts/core/catalog.gd")
const ColonyFixture := preload("res://test/fixtures/starter_colony_fixture.gd")
const StarterColonyScript := preload("res://scripts/core/starter_colony.gd")

## GDD §5.9's origin tiles, `z*128+x`, restated rather than read from the plan: the hall at
## (58,59), then the stockpiles at (50,60), (50,65), (70,60), (70,65) in authored order.
const HALL_ORIGIN_TILE: int = 59 * 128 + 58
const STOCKPILE_ORIGIN_TILES: Array[int] = [60 * 128 + 50, 65 * 128 + 50, 60 * 128 + 70,
	65 * 128 + 70]

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
## UI-C3-R01 §2 puts the unit on the figure at its owner, so the populated form carries it.
## The refused case keeps the bare "--": "-- days" would read as a measured zero rather than
## an absent divisor.
const STARTER_FOOD_DAYS_TEXT: String = "5.48 days"

var _economy: EconomySystemScript = null
var _colony: ColonyFixture = null
var _residents: ResidentsScript = null
var _depleted: Array[StringName] = []
var _changes: int = 0


func before_each() -> void:
	"""Build a fresh economy system, bind its stores to a starter colony, and listen for signals."""
	_colony = ColonyFixture.new()
	_economy = EconomySystemScript.new()
	if _colony.refusal != StarterColonyScript.REFUSE_NONE \
			or not _economy.open_starter_stores(_colony.binding):
		fail("the starter stores could not be bound: %s / %s"
			% [_colony.refusal, _economy.last_refusal()])
	_residents = null
	_depleted = []
	_changes = 0
	_economy.stock_depleted.connect(_on_stock_depleted)
	_economy.stocks_changed.connect(_on_stocks_changed)


func after_each() -> void:
	"""Free the economy system built for the test."""
	_residents = null
	_colony = null
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
	"""All 60 authoritative items register, and the pantry and four stockpile stores open."""
	assert_equal(_economy.catalog_error(), "", "the catalog loaded")
	assert_equal(_economy.item_count(), 61, "all 61 catalog rows are registered")
	assert_true(_economy.stores_open(), "the stores are bound")
	assert_true(_economy.inventory().is_container_valid(_economy.pantry()), "the pantry is open")
	for index: int in STARTER_OPEN_STOCKPILES:
		assert_true(_economy.inventory().is_container_valid(_economy.stockpile(index)),
			"stockpile store %d is open" % index)
	assert_equal(_economy.inventory().live_container_count(), 1 + STARTER_OPEN_STOCKPILES,
		"five containers and no sixth")


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
	var wood_units: int = 320
	assert_true(_economy.deposit(&"wood", wood_units * MILLI), "the four stores fill exactly")
	var before: PackedByteArray = _economy.inventory().state_bytes()
	assert_false(_economy.deposit(&"wood", MILLI), "one unit past capacity is refused")
	assert_equal(_economy.last_refusal(), InventoryScript.REFUSE_CAPACITY_EXCEEDED, "refusal is explicit")
	assert_equal(_economy.stock_milli(&"wood"), wood_units * MILLI, "nothing was clamped away")
	assert_true(_economy.inventory().state_bytes() == before, "and nothing at all was written")


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
	assert_equal(_economy.store_used_mass_g(_economy.stockpile(0)), 50000,
		"10 wood U is 50000 g of the first stockpile store")
	assert_equal(_economy.material_used_mass_g(), 50000, "and of the material stores together")


func test_starting_inventory_fits_the_specified_container_masses() -> void:
	"""GDD §5.9: the starting inventory fits the pantry and the four stockpiles as specified."""
	_seed_starting_inventory()
	var pantry_used: int = _economy.store_used_mass_g(_economy.pantry())
	var store_used: int = _economy.material_used_mass_g()
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
	assert_equal(_economy.catalog_error(), "", "the fixture catalog loaded")
	assert_true(_economy.open_starter_stores(_colony.binding), "and the stores rebind to the colony")
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
	"""reset() clears every lot, closes the stores, and drops the borrowed residents store.

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
	assert_false(_economy.stores_open(), "the stores closed with their owners' settlement")
	assert_equal(_economy.pantry(), InventoryScript.NULL_REF, "so the pantry names nothing")
	assert_true(_economy.open_starter_stores(_colony.binding), "and they reopen on a binding")


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
	@warning_ignore("integer_division") assert_equal(STARTER_READY_NP * 100 / STARTER_DEMAND_NP, 548, "the exact quotient floors to 548")
	assert_true(STARTER_READY_NP * 100 % STARTER_DEMAND_NP > 0, "the quotient is not exact")
	assert_equal(_economy.food_days_text(), "5.48 days", "the discarded remainder is not rounded up")


func test_food_days_uses_the_winter_demand_multiplier() -> void:
	"""GDD §5.8: the divisor uses today's season multiplier, which §5.2 sets to x1.20 in winter."""
	_bind_starting_settlement()
	assert_true(_residents.set_winter(true).ok, "winter arrives")
	assert_equal(_economy.daily_demand_np().value, 89280, "winter demand is 74400 x 1.20")
	assert_equal(_economy.food_days_centi().value, 456, "the same stores now cover 4.56 days")
	assert_equal(_economy.food_days_text(), "4.56 days", "the display followed the season")


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


# --- decision 0533: owned, anchored stores and §5.9's fill order (DEMO-CONTAIN-R01 D3) ----------

func test_the_stores_stay_closed_until_a_colony_binds_them() -> void:
	"""Answer #7: no ownerless container. A fresh economy opens nothing and refuses stock by name."""
	var fresh: EconomySystemScript = EconomySystemScript.new()
	assert_false(fresh.stores_open(), "nothing is open before a binding")
	assert_equal(fresh.inventory().live_container_count(), 0, "and no container exists")
	assert_equal(fresh.pantry(), InventoryScript.NULL_REF, "the pantry names nothing")
	assert_equal(fresh.stockpile(0), InventoryScript.NULL_REF, "nor does a stockpile store")
	assert_false(fresh.deposit(&"wood", MILLI), "so a deposit is refused")
	assert_equal(fresh.last_refusal(), EconomySystemScript.REFUSE_STORES_NOT_OPEN, "by name")
	assert_false(fresh.withdraw(&"wood", MILLI), "and so is a withdrawal")
	assert_equal(fresh.last_refusal(), EconomySystemScript.REFUSE_STORES_NOT_OPEN, "by the same name")
	assert_equal(fresh.material_used_mass_g(), 0, "and the material stores hold nothing")
	fresh.free()


func test_the_pantry_is_the_halls_and_each_store_is_one_stockpiles_anchored_at_its_origin() -> void:
	"""#3a and #7: owners are the hall and the four open stockpiles; anchors are their origins."""
	var inventory: InventoryScript = _economy.inventory()
	var hall: Vector2i = _colony.buildings.building_at_tile(HALL_ORIGIN_TILE)
	assert_equal(inventory.container_owner(_economy.pantry()), hall, "the hall owns the pantry")
	assert_equal(inventory.container_anchor_tile(_economy.pantry()), HALL_ORIGIN_TILE,
		"anchored at the hall's origin tile")
	assert_equal(inventory.container_max_mass_g(_economy.pantry()), 200000, "four shelves' 200000 g")
	for index: int in STARTER_OPEN_STOCKPILES:
		var store: Vector2i = _economy.stockpile(index)
		var tile: int = STOCKPILE_ORIGIN_TILES[index]
		assert_equal(inventory.container_owner(store), _colony.buildings.building_at_tile(tile),
			"stockpile store %d is owned by the stockpile at tile %d" % [index, tile])
		assert_equal(inventory.container_anchor_tile(store), tile, "and anchored at its origin")
		assert_equal(inventory.container_max_mass_g(store), 400000, "with its own 400000 g")
	assert_true(_economy.stockpile(0).x < _economy.stockpile(3).x,
		"plan order is ascending container order")
	assert_equal(_economy.stockpile(STARTER_OPEN_STOCKPILES), InventoryScript.NULL_REF,
		"and there is no fifth stockpile store")
	assert_equal(_economy.stockpile(-1), InventoryScript.NULL_REF, "nor a negative one")


func test_an_incomplete_or_repeated_binding_is_refused_and_writes_nothing() -> void:
	"""Open refuses before writing: a null binding, a missing owner, a bad anchor, a second open."""
	var fresh: EconomySystemScript = EconomySystemScript.new()
	var before: PackedByteArray = fresh.inventory().state_bytes()
	assert_false(fresh.open_starter_stores(null), "a null binding is refused")
	assert_equal(fresh.last_refusal(), EconomySystemScript.REFUSE_INVALID_STORE_BINDING, "by name")
	var partial: StarterColonyScript.StoreBinding = StarterColonyScript.StoreBinding.new()
	partial.pantry_owner = _colony.binding.pantry_owner
	partial.pantry_anchor_tile = _colony.binding.pantry_anchor_tile
	assert_false(fresh.open_starter_stores(partial), "a binding with no stockpiles is refused")
	assert_equal(fresh.last_refusal(), EconomySystemScript.REFUSE_INVALID_STORE_BINDING,
		"as an incomplete binding, before Inventory is asked")
	var off_grid: StarterColonyScript.StoreBinding = _copy_binding(_colony.binding)
	off_grid.stockpile_anchor_tile[3] = 16384
	assert_false(fresh.open_starter_stores(off_grid), "an off-grid anchor is refused")
	assert_equal(fresh.last_refusal(), EconomySystemScript.REFUSE_INVALID_STORE_BINDING, "likewise")
	var ownerless: StarterColonyScript.StoreBinding = _copy_binding(_colony.binding)
	ownerless.pantry_owner = InventoryScript.NULL_REF
	assert_false(fresh.open_starter_stores(ownerless), "an ownerless pantry is refused")
	assert_equal(fresh.last_refusal(), EconomySystemScript.REFUSE_INVALID_STORE_BINDING, "likewise")
	var slotless: StarterColonyScript.StoreBinding = _copy_binding(_colony.binding)
	slotless.stockpile_slot[0] = -1
	assert_false(fresh.open_starter_stores(slotless), "a negative owner slot is refused")
	assert_equal(fresh.last_refusal(), EconomySystemScript.REFUSE_INVALID_STORE_BINDING,
		"even with a live-looking generation beside it")
	assert_true(fresh.inventory().state_bytes() == before, "and none of them wrote a byte")
	assert_true(fresh.open_starter_stores(_colony.binding), "a complete binding opens")
	var opened: PackedByteArray = fresh.inventory().state_bytes()
	assert_false(fresh.open_starter_stores(_colony.binding), "and a second open is refused")
	assert_equal(fresh.last_refusal(), EconomySystemScript.REFUSE_STORES_ALREADY_OPEN, "by name")
	assert_true(fresh.inventory().state_bytes() == opened, "leaving the open stores untouched")
	fresh.free()


func _copy_binding(source: StarterColonyScript.StoreBinding) -> StarterColonyScript.StoreBinding:
	"""An independent copy of `source`, so a test can corrupt one field of it."""
	var copy: StarterColonyScript.StoreBinding = StarterColonyScript.StoreBinding.new()
	copy.pantry_owner = source.pantry_owner
	copy.pantry_anchor_tile = source.pantry_anchor_tile
	copy.stockpile_slot = source.stockpile_slot.duplicate()
	copy.stockpile_generation = source.stockpile_generation.duplicate()
	copy.stockpile_anchor_tile = source.stockpile_anchor_tile.duplicate()
	return copy


func test_a_deposit_fills_the_stockpiles_in_ascending_order_and_splits_at_a_full_one() -> void:
	"""§5.9 "filling container IDs ascending": 100 wood U is 400000 g, then 100000 g."""
	assert_true(_economy.deposit(&"wood", 100 * MILLI), "500000 g of wood is accepted")
	assert_equal(_economy.store_used_mass_g(_economy.stockpile(0)), 400000, "the first fills")
	assert_equal(_economy.store_used_mass_g(_economy.stockpile(1)), 100000, "the rest spills")
	assert_equal(_economy.store_used_mass_g(_economy.stockpile(2)), 0, "nothing reaches the third")
	assert_equal(_economy.stock_milli(&"wood"), 100 * MILLI, "and no quantity is lost or made")
	assert_true(_economy.deposit(&"wood", 10 * MILLI), "a second deposit")
	assert_equal(_economy.store_used_mass_g(_economy.stockpile(1)), 150000,
		"tops up the first store with room, merging into its stack")
	assert_equal(_economy.inventory().live_lot_count(), 2, "two lots, one per store touched")
	assert_true(_economy.withdraw(&"wood", 85 * MILLI), "a withdrawal spans both stores")
	assert_equal(_economy.stock_milli(&"wood"), 25 * MILLI, "exactly what was asked is taken")
	assert_true(_economy.inventory().audit().ok, "and the inventory audits")


func test_a_split_charges_the_per_lot_ceiling_and_never_overfills() -> void:
	"""The split is floor(free*1000/mass): a part whose ceiling charge would overflow never lands."""
	assert_true(_economy.deposit(&"wood", 79999), "79.999 wood U charges 399995 g")
	assert_equal(_economy.store_used_mass_g(_economy.stockpile(0)), 399995, "ceil(79999*5000/1000)")
	assert_true(_economy.deposit(&"wood", 2 * MILLI), "two more units arrive")
	assert_equal(_economy.store_used_mass_g(_economy.stockpile(0)), 400000,
		"the first store takes exactly the 0.001 U that fills it")
	assert_equal(_economy.store_used_mass_g(_economy.stockpile(1)), 9995,
		"and the second takes the rest")
	assert_equal(_economy.stock_milli(&"wood"), 81999, "every milli-unit accounted for")


func test_the_initial_inventory_lands_in_section_5_9_fill_order() -> void:
	"""Food first, then item ID, filling container IDs ascending: the exact grams per store."""
	assert_true(_economy.seed_initial_inventory(), "the §5.1 inventory is accepted")
	assert_equal(_economy.store_used_mass_g(_economy.pantry()), 179200, "food fills the pantry")
	var expected: Array[int] = [400000, 400000, 400000, 312000]
	for index: int in STARTER_OPEN_STOCKPILES:
		assert_equal(_economy.store_used_mass_g(_economy.stockpile(index)), expected[index],
			"stockpile store %d holds %d g" % [index, expected[index]])
	assert_equal(_store_items(_economy.stockpile(0)),
		_item_ids([&"cloth", &"compost", &"iron", &"rope", &"stone"]),
		"the first store takes the low item ids and the head of the stone")
	assert_equal(_store_items(_economy.stockpile(1)), _item_ids([&"stone", &"tool", &"wood"]),
		"the second the stone's tail, the tools and the head of the wood")
	assert_equal(_economy.stock_units(&"stone"), 100, "stone is split, not lost")
	assert_equal(_economy.stock_units(&"wood"), 180, "and so is wood")
	assert_equal(_economy.ready_nutrition_points(), STARTER_READY_NP, "§7.1's 408000 NP")


func _store_items(container: Vector2i) -> PackedInt32Array:
	"""The sorted compiled item ids of every lot in `container`."""
	var ids: PackedInt32Array = PackedInt32Array()
	var lot: Vector2i = _economy.inventory().container_first_lot(container)
	while lot != InventoryScript.NULL_REF:
		ids.append(_economy.inventory().lot_item_id(lot))
		lot = _economy.inventory().container_next_lot(lot)
	ids.sort()
	return ids


func _item_ids(keys: Array[StringName]) -> PackedInt32Array:
	"""The sorted compiled ids of `keys`."""
	var ids: PackedInt32Array = PackedInt32Array()
	for key: StringName in keys:
		ids.append(_economy.definitions().compiled_id(key))
	ids.sort()
	return ids


func test_the_initial_inventory_list_restates_gdd_5_1() -> void:
	"""The list moved from main.gd into EconomySystem; it must still be §5.1's twenty rows."""
	assert_equal(EconomySystemScript.INITIAL_INVENTORY_U, STARTING_INVENTORY_U,
		"EconomySystem's list is the specification's, row for row")
	assert_equal(EconomySystemScript.MATERIAL_STORE_MAX_MASS_G, 1600000,
		"four 400000 g stores are §5.9's 1600000 g")


func test_a_split_deposit_that_cannot_finish_rolls_every_part_back() -> void:
	"""330 wood U is 1650000 g: four stores take 1600000 g, the rest has nowhere to go -- so nothing
	lands. The parts already placed in earlier stores are rolled back with the refusal."""
	var before: PackedByteArray = _economy.inventory().state_bytes()
	assert_false(_economy.deposit(&"wood", 330 * MILLI), "the deposit is refused")
	assert_equal(_economy.last_refusal(), InventoryScript.REFUSE_CAPACITY_EXCEEDED, "for capacity")
	assert_true(_economy.inventory().state_bytes() == before, "every placed part was rolled back")
	assert_false(_economy.inventory().is_transaction_open(), "and the transaction was closed")
	assert_equal(_changes, 0, "no change was signalled")


func test_reserved_capacity_is_not_filled_by_a_split() -> void:
	"""A store's reserved mass is headroom someone else holds: the split fills around it."""
	assert_true(_economy.inventory().reserve_container_mass(_economy.stockpile(0), 395000).ok,
		"395000 g of the first store is claimed")
	assert_true(_economy.deposit(&"wood", 10 * MILLI), "50000 g of wood arrives")
	assert_equal(_economy.store_used_mass_g(_economy.stockpile(0)), 5000,
		"the first store takes only its unclaimed 5000 g")
	assert_equal(_economy.store_used_mass_g(_economy.stockpile(1)), 45000, "the rest spills")


func test_a_caller_held_transaction_is_refused_not_joined() -> void:
	"""Deposit, withdraw and open never close a transaction someone else opened on `inventory()`."""
	assert_true(_economy.deposit(&"wood", 10 * MILLI), "some wood is stored")
	assert_true(_economy.inventory().begin().ok, "a caller opens its own transaction")
	assert_false(_economy.deposit(&"wood", MILLI), "a deposit is refused")
	assert_equal(_economy.last_refusal(), InventoryScript.REFUSE_NESTED_TRANSACTION, "as nested")
	assert_false(_economy.withdraw(&"wood", MILLI), "so is a withdrawal")
	assert_equal(_economy.last_refusal(), InventoryScript.REFUSE_NESTED_TRANSACTION, "likewise")
	assert_true(_economy.inventory().is_transaction_open(), "the caller's transaction is still open")
	_economy.inventory().abort()
	var fresh: EconomySystemScript = EconomySystemScript.new()
	assert_true(fresh.inventory().begin().ok, "on a closed economy, a caller opens one too")
	assert_false(fresh.open_starter_stores(_colony.binding), "and the stores refuse to open")
	assert_equal(fresh.last_refusal(), InventoryScript.REFUSE_NESTED_TRANSACTION, "as nested")
	assert_false(fresh.stores_open(), "staying closed")
	fresh.inventory().abort()
	fresh.free()


func test_open_and_seed_is_boots_and_creates_one_entry() -> void:
	"""One call opens the bound stores and seeds §5.1's inventory; a refused open seeds nothing."""
	var fresh: EconomySystemScript = EconomySystemScript.new()
	assert_false(fresh.open_and_seed_starter_stores(null), "no binding, no stores")
	assert_equal(fresh.inventory().live_lot_count(), 0, "and nothing was seeded")
	assert_true(fresh.open_and_seed_starter_stores(_colony.binding), "a binding opens and seeds")
	assert_equal(fresh.ready_nutrition_points(), STARTER_READY_NP, "§7.1's 408000 NP")
	fresh.free()


# --- decision 0534: adopting the settlement's inventory -------------------------------------------

func _settlement_like_store() -> InventoryScript:
	"""A store registered from the shipped catalog, as the settlement's own inventory is."""
	var store: InventoryScript = InventoryScript.new()
	var items: ItemDefinitionsScript = ItemDefinitionsScript.new()
	assert_true(items.load_default(store).ok, "the catalog registers into the borrowed store")
	return store


func _closed_economy() -> EconomySystemScript:
	"""A fresh economy with its stores still closed, freed by the caller."""
	return EconomySystemScript.new()


func test_a_bound_economy_opens_its_stores_in_the_borrowed_inventory() -> void:
	"""The lots land in the adopted store, which is the one a demolition gate scans."""
	var economy: EconomySystemScript = _closed_economy()
	var store: InventoryScript = _settlement_like_store()
	assert_true(economy.bind_inventory(store), "the store is adopted: %s" % economy.last_refusal())
	assert_true(economy.is_inventory_borrowed(), "and reported as borrowed")
	assert_true(economy.open_and_seed_starter_stores(_colony.binding), "the stores open and seed")
	assert_true(economy.inventory() == store, "the economy reads the adopted store")
	assert_equal(store.live_container_count(), 1 + STARTER_OPEN_STOCKPILES, "five stores there")
	assert_equal(economy.ready_nutrition_points(), STARTER_READY_NP, "with §5.1's food")
	economy.free()


func test_reset_drops_a_borrowed_store_and_never_clears_it() -> void:
	"""Decision 0087's wrinkle: the settlement owns those rows; a reset must not destroy them."""
	var economy: EconomySystemScript = _closed_economy()
	var store: InventoryScript = _settlement_like_store()
	assert_true(economy.bind_inventory(store), "adopted")
	assert_true(economy.open_and_seed_starter_stores(_colony.binding), "opened")
	var lots: int = store.live_lot_count()
	economy.reset()
	assert_false(economy.is_inventory_borrowed(), "the binding is dropped")
	assert_false(economy.inventory() == store, "the economy is back on its private store")
	assert_equal(store.live_lot_count(), lots, "and the borrowed lots are all still there")
	assert_false(economy.stores_open(), "its stores are closed")
	economy.free()


func test_binding_refuses_once_open_null_or_a_disagreeing_catalog() -> void:
	"""Each refusal leaves the private store in use."""
	assert_false(_economy.bind_inventory(_settlement_like_store()), "open stores refuse")
	assert_equal(_economy.last_refusal(), EconomySystemScript.REFUSE_STORES_ALREADY_OPEN, "named")
	var economy: EconomySystemScript = _closed_economy()
	assert_false(economy.bind_inventory(null), "null refuses")
	assert_equal(economy.last_refusal(), EconomySystemScript.REFUSE_INVALID_INVENTORY, "named")
	var bare: InventoryScript = InventoryScript.new()
	assert_false(economy.bind_inventory(bare), "an unregistered store refuses")
	assert_equal(economy.last_refusal(), EconomySystemScript.REFUSE_INVENTORY_CATALOG_MISMATCH,
		"named")
	var heavier: InventoryScript = InventoryScript.new()
	for item_id: int in InventoryScript.ITEM_CAPACITY:
		if economy.inventory().is_item_registered(item_id):
			heavier.register_item(item_id, economy.inventory().item_mass_g(item_id) + 1,
				economy.inventory().item_category(item_id))
	assert_false(economy.bind_inventory(heavier), "a different mass refuses")
	var moved: InventoryScript = InventoryScript.new()
	for item_id: int in InventoryScript.ITEM_CAPACITY:
		if economy.inventory().is_item_registered(item_id):
			moved.register_item(item_id, economy.inventory().item_mass_g(item_id),
				(economy.inventory().item_category(item_id) + 1) % InventoryScript.CATEGORY_COUNT)
	assert_false(economy.bind_inventory(moved), "a different category refuses")
	var extra: InventoryScript = _settlement_like_store()
	extra.register_item(InventoryScript.ITEM_CAPACITY - 1, 1000, 0)
	assert_false(economy.bind_inventory(extra), "an extra registration refuses")
	assert_false(economy.is_inventory_borrowed(), "and nothing was adopted")
	economy.free()


func test_binding_the_private_store_is_an_unbind() -> void:
	"""Handing back its own store leaves nothing borrowed."""
	var economy: EconomySystemScript = _closed_economy()
	assert_true(economy.bind_inventory(_settlement_like_store()), "adopted")
	economy.reset()
	assert_true(economy.bind_inventory(economy.inventory()), "its own store binds")
	assert_false(economy.is_inventory_borrowed(), "and is not borrowed")
	economy.free()
