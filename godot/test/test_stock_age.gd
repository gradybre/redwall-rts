extends "res://test/framework/test_case.gd"
## Suite for `scripts/core/stock_age.gd` -- ARCH-SYS-004 StockAge, GDD §5.8 REQ-SET-107–108.
##
## Every factor, shelf life and mass asserted here is RESTATED FROM THE GDD rather than read
## back out of the module under test:
##   * §5.8 "Base age per game hour is 1000 milli-hours; store factor open pile 1500, covered
##     store 1000, pantry 750, cellar 350. Seasonal temperature factor spring 1000/summer 1500/
##     autumn 1000/winter 500; heated interiors use 1000 in winter. Effective age per
##     hour=floor(store_factor*temperature_factor/1000), retaining tick fractions."
##   * §5.8 "When age reaches shelf_hours x 1000, food becomes spoiled_food at identical mass.
##     ... Spoiled_food lasts 240h then is removed as waste".
##   * §5.7/balance item table: berries 250 g shelf 48 h, meal_porridge 500 g shelf 24 h,
##     spoiled_food 250 g shelf 240 h, wood 5000 g shelf 0, seed_grain 100 g shelf 1440 h.
##   * ARCH-TICK-002 `(k+4500) mod 750 = 0`, first midnight 13500.
##   * ARCH-TICK-003 "aging uses the season in the elapsed interval".
##
## The catalog is the REAL `res://data/item_definitions.json`, because §5.8's conversion is
## defined between two concrete catalog items and a fixture with invented masses would test
## arithmetic nobody ships.

const StockAgeScript := preload("res://scripts/core/stock_age.gd")
const InventoryScript := preload("res://scripts/core/inventory.gd")
const ItemDefinitionsScript := preload("res://scripts/core/item_definitions.gd")
const GearScript := preload("res://scripts/core/gear.gd")
const SimClockScript := preload("res://scripts/core/sim_clock.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

## GDD §5.8's store factors, transcribed.
const OPEN_PILE_FACTOR: int = 1500
const COVERED_STORE_FACTOR: int = 1000
const PANTRY_FACTOR: int = 750
const CELLAR_FACTOR: int = 350
## GDD §5.8's seasonal temperature factors, transcribed, in the calendar's season order.
const SPRING_FACTOR: int = 1000
const SUMMER_FACTOR: int = 1500
const AUTUMN_FACTOR: int = 1000
const WINTER_FACTOR: int = 500
## §5.8's heated-interior substitution.
const HEATED_WINTER_FACTOR: int = 1000

const SEASON_SPRING: int = 0
const SEASON_SUMMER: int = 1
const SEASON_AUTUMN: int = 2
const SEASON_WINTER: int = 3

## Item shelf lives and masses, transcribed from `docs/gameplay_balance.md`'s item table.
const BERRIES_SHELF_HOURS: int = 48
const BERRIES_MASS_G: int = 250
const PORRIDGE_SHELF_HOURS: int = 24
const PORRIDGE_MASS_G: int = 500
const SPOILED_SHELF_HOURS: int = 240
const SPOILED_MASS_G: int = 250
const SEED_SHELF_HOURS: int = 1440

const MILLI_HOURS_PER_HOUR: int = 1000
const BIG_MASS_G: int = 100000000
const OWNER: Vector2i = Vector2i(9, 1)
const TEST_POLICY: int = 0
const TEST_PROVENANCE: int = 0
const TEST_QUALITY: int = 0
const NO_RECIPE: int = 0

var _inv: InventoryScript = null
var _defs: ItemDefinitionsScript = null
var _age: StockAgeScript = null


func before_each() -> void:
	"""Build a small inventory carrying the real §4.3 catalog, with ARCH-SYS-004 over it."""
	_inv = InventoryScript.new(8, 64)
	_defs = ItemDefinitionsScript.new()
	_defs.load_default(_inv)
	_age = StockAgeScript.new(_inv, _defs)


func _item(key: StringName) -> int:
	"""Compiled catalog id for an item key, resolved rather than written down."""
	return _defs.compiled_id(key)


func _container(storage_class: int, heated: bool = false,
		filters: int = InventoryScript.FILTERS_ACCEPT_ALL) -> Vector2i:
	"""Create a container and declare its GDD §5.8 storage class."""
	var made: InventoryScript.OpResult = _inv.create_container(
		OWNER, BIG_MASS_G, filters, TEST_POLICY, true)
	if storage_class != StockAgeScript.STORAGE_UNDECLARED:
		_age.declare_storage_class(made.ref, storage_class, heated)
	return made.ref


func _lot(container: Vector2i, key: StringName, quantity_milli: int,
		age_milli_hours: int = 0) -> Vector2i:
	"""Create one lot of a catalog item at a chosen starting age."""
	var made: InventoryScript.OpResult = _inv.create_lot(container, _item(key), quantity_milli,
		TEST_QUALITY, TEST_PROVENANCE, NO_RECIPE, age_milli_hours, 0)
	return made.ref


static func _hour_tick(day: int, hour: int) -> int:
	"""The tick that opens `hour` of absolute `day` under the offset calendar.

	Inverse of `(tick + 4500) mod 18000`, written out here rather than taken from the module:
	tick 0 is 06:00 of day 1, so day d hour h opens at `(d-1)*18000 + h*750 - 4500`.
	"""
	return (day - 1) * SimClockScript.TICKS_PER_DAY + hour * SimClockScript.TICKS_PER_HOUR \
		- SimClockScript.CALENDAR_OFFSET_TICKS


# --- GDD §5.8's two factor tables ---------------------------------------------------------------

func test_the_store_factors_are_the_four_the_gdd_tabulates() -> void:
	"""§5.8: "store factor open pile 1500, covered store 1000, pantry 750, cellar 350"."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	assert_true(StockAgeScript.store_factor_into(StockAgeScript.STORAGE_OPEN_PILE, out),
		"an open pile has a factor")
	assert_equal(out.value, OPEN_PILE_FACTOR, "open pile 1500")
	StockAgeScript.store_factor_into(StockAgeScript.STORAGE_COVERED_STORE, out)
	assert_equal(out.value, COVERED_STORE_FACTOR, "covered store 1000")
	StockAgeScript.store_factor_into(StockAgeScript.STORAGE_PANTRY, out)
	assert_equal(out.value, PANTRY_FACTOR, "pantry 750")
	StockAgeScript.store_factor_into(StockAgeScript.STORAGE_CELLAR, out)
	assert_equal(out.value, CELLAR_FACTOR, "cellar 350")


func test_an_undeclared_storage_class_refuses_instead_of_answering_zero() -> void:
	"""A zero factor reads as "this never ages", which is the wrong answer, not a missing one."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	assert_false(StockAgeScript.store_factor_into(StockAgeScript.STORAGE_UNDECLARED, out),
		"an undeclared container has no store factor")
	assert_equal(out.error, "INVALID_STORAGE_CLASS", "and says why")
	assert_equal(out.value, 0, "with the value channel zeroed rather than usable")
	assert_false(StockAgeScript.store_factor_into(StockAgeScript.STORAGE_CLASS_COUNT, out),
		"and an out-of-range class refuses too")


func test_the_temperature_factors_are_the_four_seasons_the_gdd_tabulates() -> void:
	"""§5.8: "spring 1000/summer 1500/autumn 1000/winter 500"."""
	assert_equal(StockAgeScript.temperature_factor_of(SEASON_SPRING, false), SPRING_FACTOR,
		"spring 1000")
	assert_equal(StockAgeScript.temperature_factor_of(SEASON_SUMMER, false), SUMMER_FACTOR,
		"summer 1500")
	assert_equal(StockAgeScript.temperature_factor_of(SEASON_AUTUMN, false), AUTUMN_FACTOR,
		"autumn 1000")
	assert_equal(StockAgeScript.temperature_factor_of(SEASON_WINTER, false), WINTER_FACTOR,
		"winter 500")


func test_a_heated_interior_substitutes_only_in_winter() -> void:
	"""§5.8 grants "heated interiors use 1000 in winter" and grants nothing in any other season."""
	assert_equal(StockAgeScript.temperature_factor_of(SEASON_WINTER, true), HEATED_WINTER_FACTOR,
		"a heated winter store ages at 1000, not 500")
	assert_equal(StockAgeScript.temperature_factor_of(SEASON_SUMMER, true), SUMMER_FACTOR,
		"and a heated store in summer still takes the summer factor")
	assert_equal(StockAgeScript.temperature_factor_of(SEASON_SPRING, true), SPRING_FACTOR,
		"and in spring the substitution changes nothing")


# --- ARCH-TICK-002's hour crossing ----------------------------------------------------------------

func test_the_crossing_is_the_offset_hour_and_never_a_plain_midnight_modulo() -> void:
	"""ARCH-TICK-002: hour boundaries satisfy `(k+4500) mod 750 = 0`, NOT `k mod 18000 = 0`."""
	assert_false(StockAgeScript.is_hour_boundary(0), "tick 0 is 06:00 and opens no new hour")
	assert_true(StockAgeScript.is_hour_boundary(750), "tick 750 is the first crossing")
	assert_false(StockAgeScript.is_hour_boundary(749), "and the tick before it is not")
	assert_false(StockAgeScript.is_hour_boundary(751), "nor the tick after")
	assert_true(StockAgeScript.is_hour_boundary(SimClockScript.FIRST_MIDNIGHT_TICK),
		"every midnight is also an hour crossing, which is what makes 'midnight first' one pass")
	assert_true(StockAgeScript.is_hour_boundary(18000),
		"tick 18000 IS an hour crossing even though `18000 mod 18000 == 0` names no midnight")
	assert_false(SimClockScript.is_day_boundary(18000),
		"which is exactly why the plain modulo is the wrong predicate")


func test_a_tick_that_is_not_an_hour_crossing_ages_nothing() -> void:
	"""A per-tick call must not accrue an hour; the refusal is named and the store is untouched."""
	var store: Vector2i = _container(StockAgeScript.STORAGE_PANTRY)
	var lot: Vector2i = _lot(store, &"berries", 4000)
	var before: PackedByteArray = _inv.state_bytes()
	var out: StockAgeScript.HourResult = _age.run_hour(751)
	assert_false(out.ok, "tick 751 is inside an hour, not at its start")
	assert_equal(out.error, &"NOT_AN_HOUR_BOUNDARY", "and says so")
	assert_equal(_inv.lot_age_milli_hours(lot), 0, "the lot did not age")
	assert_equal(_inv.state_bytes(), before, "and the whole store is byte identical")


func test_a_replayed_hour_is_refused_rather_than_aged_twice() -> void:
	"""ARCH-TICK-002: the same sixty minutes may not be integrated a second time."""
	var store: Vector2i = _container(StockAgeScript.STORAGE_PANTRY)
	var lot: Vector2i = _lot(store, &"berries", 4000)
	assert_true(_age.run_hour(750).ok, "the first pass commits")
	var replay: StockAgeScript.HourResult = _age.run_hour(750)
	assert_false(replay.ok, "the replay refuses")
	assert_equal(replay.error, &"STOCK_AGE_HOUR_ALREADY_RUN", "with the replay code")
	assert_equal(_inv.lot_age_milli_hours(lot), PANTRY_FACTOR,
		"and exactly one hour of pantry age stands")


func test_an_unbound_catalog_refuses_before_the_hour_latch_is_consumed() -> void:
	"""Allocate before consume: a pass that cannot decide shelf life must not eat the crossing."""
	var standalone: StockAgeScript = StockAgeScript.new(_inv, null)
	var out: StockAgeScript.HourResult = standalone.run_hour(750)
	assert_false(out.ok, "no catalog, no shelf lives, no pass")
	assert_equal(out.error, &"ITEM_CATALOG_NOT_BOUND", "and the missing input is named")
	assert_equal(standalone.last_hour_tick(), StockAgeScript.NO_HOUR_RUN,
		"and the crossing is still available to a bound pass")


# --- REQ-SET-107 effective storage age -------------------------------------------------------------

func test_one_pantry_hour_in_spring_is_the_gdd_product() -> void:
	"""floor(750 * 1000 / 1000) = 750 milli-hours, and nothing rounds it away."""
	var store: Vector2i = _container(StockAgeScript.STORAGE_PANTRY)
	var lot: Vector2i = _lot(store, &"berries", 4000)
	var out: StockAgeScript.HourResult = _age.run_hour(_hour_tick(3, 9))
	assert_true(out.ok, "the hour ran")
	assert_equal(out.season, SEASON_SPRING, "day 3 is in spring")
	assert_equal(out.lots_aged, 1, "one lot aged")
	assert_equal(_inv.lot_age_milli_hours(lot), PANTRY_FACTOR * SPRING_FACTOR / 1000,
		"§5.8's floor(store*temperature/1000) in milli-hours")
	assert_equal(_inv.lot_age_remainder(lot), 0, "with nothing left over")


func test_the_four_store_classes_age_at_four_different_rates_in_one_season() -> void:
	"""The store factor is per CONTAINER, so four stores in one pass give four different ages."""
	var pile: Vector2i = _container(StockAgeScript.STORAGE_OPEN_PILE)
	var covered: Vector2i = _container(StockAgeScript.STORAGE_COVERED_STORE)
	var pantry: Vector2i = _container(StockAgeScript.STORAGE_PANTRY)
	var cellar: Vector2i = _container(StockAgeScript.STORAGE_CELLAR)
	var a: Vector2i = _lot(pile, &"grain", 1000)
	var b: Vector2i = _lot(covered, &"grain", 1000)
	var c: Vector2i = _lot(pantry, &"grain", 1000)
	var d: Vector2i = _lot(cellar, &"grain", 1000)
	assert_true(_age.run_hour(_hour_tick(3, 9)).ok, "one spring hour runs over all four")
	assert_equal(_inv.lot_age_milli_hours(a), OPEN_PILE_FACTOR, "open pile 1500")
	assert_equal(_inv.lot_age_milli_hours(b), COVERED_STORE_FACTOR, "covered store 1000")
	assert_equal(_inv.lot_age_milli_hours(c), PANTRY_FACTOR, "pantry 750")
	assert_equal(_inv.lot_age_milli_hours(d), CELLAR_FACTOR, "cellar 350")


func test_summer_and_winter_move_the_same_store_at_different_rates() -> void:
	"""§5.8's seasonal factor multiplies the store factor; it does not replace it."""
	var cellar: Vector2i = _container(StockAgeScript.STORAGE_CELLAR)
	var summer_lot: Vector2i = _lot(cellar, &"grain", 1000)
	assert_true(_age.run_hour(_hour_tick(15, 5)).ok, "a summer hour runs")
	assert_equal(_inv.lot_age_milli_hours(summer_lot), CELLAR_FACTOR * SUMMER_FACTOR / 1000,
		"cellar in summer is floor(350*1500/1000) = 525")
	assert_true(_age.run_hour(_hour_tick(40, 5)).ok, "a winter hour runs")
	assert_equal(_inv.lot_age_milli_hours(summer_lot),
		CELLAR_FACTOR * SUMMER_FACTOR / 1000 + CELLAR_FACTOR * WINTER_FACTOR / 1000,
		"and winter adds floor(350*500/1000) = 175 on top")


func test_a_heated_interior_ages_faster_in_winter_than_an_unheated_one() -> void:
	"""The heated flag is per container and only changes the winter factor."""
	var cold: Vector2i = _container(StockAgeScript.STORAGE_PANTRY, false)
	var warm: Vector2i = _container(StockAgeScript.STORAGE_PANTRY, true)
	var chilled: Vector2i = _lot(cold, &"grain", 1000)
	var heated: Vector2i = _lot(warm, &"grain", 1000)
	assert_true(_age.run_hour(_hour_tick(40, 5)).ok, "a winter hour runs over both")
	assert_equal(_inv.lot_age_milli_hours(chilled), PANTRY_FACTOR * WINTER_FACTOR / 1000,
		"an unheated pantry ages at floor(750*500/1000) = 375")
	assert_equal(_inv.lot_age_milli_hours(heated), PANTRY_FACTOR * HEATED_WINTER_FACTOR / 1000,
		"a heated one uses the §5.8 substitution and ages at 750")


func test_midnight_ages_with_the_elapsed_intervals_season_not_the_new_days() -> void:
	"""ARCH-TICK-003: "aging uses the season in the elapsed interval".

	Absolute day 13 is summer day 1. Its midnight closes the LAST SPRING HOUR, so the pass that
	runs at that tick must take spring's 1000 and not summer's 1500 -- and it must do so without
	being told, because nothing hands it a season.
	"""
	var midnight: int = _hour_tick(13, 0)
	assert_equal(SimClockScript.calendar_at(midnight).season, SEASON_SUMMER,
		"the tick itself belongs to the first summer day")
	assert_equal(SimClockScript.calendar_at(midnight - 1).season, SEASON_SPRING,
		"and the hour it closes belongs to spring")
	var pile: Vector2i = _container(StockAgeScript.STORAGE_OPEN_PILE)
	var lot: Vector2i = _lot(pile, &"grain", 1000)
	var out: StockAgeScript.HourResult = _age.run_hour(midnight)
	assert_true(out.ok, "the midnight hour runs")
	assert_equal(out.season, SEASON_SPRING, "the pass reports the elapsed interval's season")
	assert_equal(_inv.lot_age_milli_hours(lot), OPEN_PILE_FACTOR * SPRING_FACTOR / 1000,
		"so the lot took spring's 1500, not summer's 2250")


func test_changing_stores_never_resets_age_and_the_new_store_decides_the_next_hour() -> void:
	"""REQ-SET-107: age survives transport, and §5.8's factor follows the container it is in."""
	var pile: Vector2i = _container(StockAgeScript.STORAGE_OPEN_PILE)
	var cellar: Vector2i = _container(StockAgeScript.STORAGE_CELLAR)
	var lot: Vector2i = _lot(pile, &"grain", 1000)
	assert_true(_age.run_hour(_hour_tick(3, 9)).ok, "one open-pile spring hour")
	assert_true(_inv.move_lot(lot, cellar).ok, "the lot is hauled into the cellar")
	assert_equal(_inv.lot_age_milli_hours(lot), OPEN_PILE_FACTOR,
		"the move carried its accrued age rather than resetting it")
	assert_true(_age.run_hour(_hour_tick(3, 10)).ok, "the next hour runs")
	assert_equal(_inv.lot_age_milli_hours(lot), OPEN_PILE_FACTOR + CELLAR_FACTOR,
		"and the second hour was charged at the cellar's rate")


func test_the_retained_fraction_is_carried_rather_than_floored_away() -> void:
	"""§5.8 "retaining tick fractions": the sub-milli-hour remainder survives to the next hour.

	Driven through `inventory.gd` directly with a factor product that is NOT a multiple of 1000,
	because every product of §5.8's four store factors and four seasons happens to be one and
	the carry would otherwise be unexercised arithmetic.
	"""
	var store: Vector2i = _container(StockAgeScript.STORAGE_PANTRY)
	var lot: Vector2i = _lot(store, &"grain", 1000)
	var out: IntMath.IntResult = IntMath.IntResult.new()
	assert_true(_inv.advance_lot_age_hour_into(lot, 1500, 1001, out), "one hour at 1500 x 1001")
	assert_equal(out.value, 1501, "floor(1501500/1000) whole milli-hours released")
	assert_equal(_inv.lot_age_remainder(lot), 500, "and 500 retained rather than discarded")
	assert_true(_inv.advance_lot_age_hour_into(lot, 1500, 1001, out), "a second identical hour")
	assert_equal(out.value, 3003, "the carried 500 completes a whole milli-hour in the second")
	assert_equal(_inv.lot_age_remainder(lot), 0, "leaving nothing behind")


func test_an_undeclared_container_is_not_aged_and_is_counted() -> void:
	"""Gap 1: no building layer means no store factor, and a missing factor is not freshness."""
	var declared: Vector2i = _container(StockAgeScript.STORAGE_PANTRY)
	var unknown: Vector2i = _container(StockAgeScript.STORAGE_UNDECLARED)
	var known_lot: Vector2i = _lot(declared, &"grain", 1000)
	var unknown_lot: Vector2i = _lot(unknown, &"grain", 1000)
	var out: StockAgeScript.HourResult = _age.run_hour(_hour_tick(3, 9))
	assert_true(out.ok, "the pass runs")
	assert_equal(out.containers_aged, 1, "one container had a declared store class")
	assert_equal(out.undeclared_containers, 1, "and the other is reported, not ignored")
	assert_equal(_inv.lot_age_milli_hours(known_lot), PANTRY_FACTOR, "the declared lot aged")
	assert_equal(_inv.lot_age_milli_hours(unknown_lot), 0,
		"and the undeclared one did not age at an invented factor")


# --- REQ-SET-108 expiry ---------------------------------------------------------------------------

func test_a_food_lot_becomes_spoiled_food_of_identical_mass_at_its_shelf_life() -> void:
	"""§5.8: at `shelf_hours x 1000` the lot becomes spoiled_food carrying the same grams."""
	var store: Vector2i = _container(StockAgeScript.STORAGE_COVERED_STORE)
	var start: int = BERRIES_SHELF_HOURS * MILLI_HOURS_PER_HOUR - COVERED_STORE_FACTOR
	var lot: Vector2i = _lot(store, &"berries", 4000, start)
	var out: StockAgeScript.HourResult = _age.run_hour(_hour_tick(3, 9))
	assert_true(out.ok, "the hour ran")
	assert_equal(out.lots_expired, 1, "the lot reached its shelf life")
	assert_equal(_inv.lot_item_id(lot), _item(&"spoiled_food"), "and became spoiled_food")
	assert_equal(_inv.lot_quantity_milli(lot) * SPOILED_MASS_G, 4000 * BERRIES_MASS_G,
		"at exactly the mass the berries carried")
	assert_equal(_inv.lot_age_milli_hours(lot), 0,
		"with a fresh age, because spoiled_food lasts 240h from here")
	assert_true(_inv.audit().ok, "and conservation still closes on both items")


func test_a_heavier_item_converts_to_more_milli_units_of_the_same_mass() -> void:
	"""§5.7 prepared meals weigh 500 g/U and spoiled_food 250 g/U, so the quantity doubles."""
	var store: Vector2i = _container(StockAgeScript.STORAGE_COVERED_STORE)
	var start: int = PORRIDGE_SHELF_HOURS * MILLI_HOURS_PER_HOUR - COVERED_STORE_FACTOR
	var lot: Vector2i = _lot(store, &"meal_porridge", 2000, start)
	assert_true(_age.run_hour(_hour_tick(3, 9)).ok, "the hour ran")
	assert_equal(_inv.lot_item_id(lot), _item(&"spoiled_food"), "the meal spoiled")
	assert_equal(_inv.lot_quantity_milli(lot), 4000,
		"2000 milli-U at 500 g is 4000 milli-U at 250 g")
	assert_equal(_inv.lot_quantity_milli(lot) * SPOILED_MASS_G, 2000 * PORRIDGE_MASS_G,
		"which is the identical mass §5.8 asks for")


func test_a_lot_one_hour_short_of_its_shelf_life_is_still_food() -> void:
	"""The threshold is `age >= shelf_hours x 1000`, tested on both sides of the crossing."""
	var store: Vector2i = _container(StockAgeScript.STORAGE_COVERED_STORE)
	var start: int = BERRIES_SHELF_HOURS * MILLI_HOURS_PER_HOUR - 2 * COVERED_STORE_FACTOR
	var lot: Vector2i = _lot(store, &"berries", 4000, start)
	assert_true(_age.run_hour(_hour_tick(3, 9)).ok, "one hour short of the shelf life")
	assert_equal(_inv.lot_item_id(lot), _item(&"berries"), "the lot is still berries")
	assert_equal(_inv.lot_age_milli_hours(lot),
		BERRIES_SHELF_HOURS * MILLI_HOURS_PER_HOUR - COVERED_STORE_FACTOR, "at one hour under")
	assert_true(_age.run_hour(_hour_tick(3, 10)).ok, "the hour that reaches it")
	assert_equal(_inv.lot_item_id(lot), _item(&"spoiled_food"), "expires it exactly then")


func test_an_unlimited_shelf_item_ages_and_never_expires() -> void:
	"""§5.8: "Unlimited shelf items have shelf_hours=0 and do not spoil". They still carry age."""
	var store: Vector2i = _container(StockAgeScript.STORAGE_OPEN_PILE)
	var lot: Vector2i = _lot(store, &"wood", 2000)
	assert_equal(_defs.shelf_hours(_item(&"wood")), 0, "wood is an unlimited-shelf item")
	for hour: int in range(0, 12):
		assert_true(_age.run_hour(_hour_tick(3, 9 + hour)).ok, "hour %d runs" % hour)
	assert_equal(_inv.lot_item_id(lot), _item(&"wood"), "wood never becomes waste")
	assert_equal(_inv.lot_age_milli_hours(lot), 12 * OPEN_PILE_FACTOR,
		"and its stored age is a real accrued number, not a frozen zero")


func test_spoiled_food_is_removed_as_waste_after_two_hundred_and_forty_hours() -> void:
	"""§5.8: "Spoiled_food lasts 240h then is removed as waste with a notice"."""
	var store: Vector2i = _container(StockAgeScript.STORAGE_COVERED_STORE)
	var start: int = SPOILED_SHELF_HOURS * MILLI_HOURS_PER_HOUR - COVERED_STORE_FACTOR
	var lot: Vector2i = _lot(store, &"spoiled_food", 4000, start)
	var out: StockAgeScript.HourResult = _age.run_hour(_hour_tick(3, 9))
	assert_true(out.ok, "the hour ran")
	assert_equal(out.waste_removed_lots, 1, "the waste lot was removed")
	assert_equal(out.waste_removed_milli, 4000, "for its whole quantity")
	assert_false(_inv.is_lot_valid(lot), "the row is retired, so waste cannot grow forever")
	assert_equal(_inv.container_used_mass_g(store), 0, "and the container got its mass back")
	assert_equal(out.notices_owed, 1,
		"the notice is OWED rather than issued: ARCH-SYS-021 has no Notice store")
	assert_true(_inv.audit().ok, "conservation closes with the quantity counted as sunk")


func test_an_inexact_equal_mass_conversion_refuses_instead_of_rounding() -> void:
	"""§5.8 asks for IDENTICAL mass, and two masses that do not divide have no such quantity.

	Driven through the pure conversion directly: every shipped catalog mass divides into
	spoiled_food's 250 g, so the branch is unreachable from the shipped items and would
	otherwise be arithmetic no test exercises. A future item with an indivisible mass is
	exactly what it exists for.
	"""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	assert_true(StockAgeScript.equal_mass_quantity_into(2000, 500, 250, out),
		"500 g meals into 250 g waste divides exactly")
	assert_equal(out.value, 4000, "2000 milli-U at 500 g is 4000 milli-U at 250 g")
	assert_false(StockAgeScript.equal_mass_quantity_into(1, 175, 250, out),
		"175 milli-grams cannot be carried by any whole milli-unit of a 250 g item")
	assert_equal(out.error, "SPOILAGE_MASS_NOT_CONVERTIBLE", "and the refusal is named")
	assert_equal(out.value, 0, "with the value channel zeroed rather than rounded")
	assert_false(StockAgeScript.equal_mass_quantity_into(1000, 500, 0, out),
		"an unregistered target mass refuses too")


func test_expiry_invalidates_the_lots_reservations_in_the_same_transaction() -> void:
	"""REQ-SET-108: "invalidate its food reservations, create spoiled_food of equal mass"."""
	var store: Vector2i = _container(StockAgeScript.STORAGE_COVERED_STORE)
	var start: int = BERRIES_SHELF_HOURS * MILLI_HOURS_PER_HOUR - COVERED_STORE_FACTOR
	var lot: Vector2i = _lot(store, &"berries", 4000, start)
	assert_true(_inv.reserve_lot(lot, 1500).ok, "a job claims part of the lot")
	var out: StockAgeScript.HourResult = _age.run_hour(_hour_tick(3, 9))
	assert_true(out.ok, "the hour ran")
	assert_equal(out.reservations_invalidated_milli, 1500, "the claim is reported as invalidated")
	assert_equal(_inv.lot_reserved_milli(lot), 0, "and no claim is held against the waste")
	assert_equal(_inv.lot_item_id(lot), _item(&"spoiled_food"), "while the conversion committed")
	assert_equal(out.replans_owed, 1,
		"the replanning REQ-SET-108 asks for is OWED: there is no recipe or meal store")


func test_a_container_filter_cannot_veto_a_spoilage_conversion() -> void:
	"""Food rots where it stands: §5.8's conversion is a transformation, not a placement.

	The container admits RAW_FOOD and not WASTE, exactly as a §5.9 pantry does, and the
	conversion still commits. `create_lot()` still enforces the same filter for a placement.
	"""
	var food_only: int = _inv.category_mask(_inv.item_category(_item(&"berries")))
	var store: Vector2i = _container(StockAgeScript.STORAGE_PANTRY, false, food_only)
	assert_false(_inv.create_lot(store, _item(&"spoiled_food"), 1000, TEST_QUALITY,
		TEST_PROVENANCE, NO_RECIPE, 0, 0).ok, "the filter refuses waste being PLACED there")
	var start: int = BERRIES_SHELF_HOURS * MILLI_HOURS_PER_HOUR - PANTRY_FACTOR
	var lot: Vector2i = _lot(store, &"berries", 4000, start)
	assert_true(_age.run_hour(_hour_tick(3, 9)).ok, "the hour ran")
	assert_equal(_inv.lot_item_id(lot), _item(&"spoiled_food"),
		"and the berries in the pantry still rotted")


# --- the equipped-lot gap --------------------------------------------------------------------------

func test_every_equippable_item_has_an_unlimited_shelf_life() -> void:
	"""THIS IS THE NAMED GAP'S TRIPWIRE, not a claim that equipment cannot age.

	§5.8 defines age through a STORE factor and names no factor for a lot held as equipment, so
	whether equipment ages is undecided. It is currently unobservable because every item
	`gear.gd` admits as an equippable instance has `shelf_hours = 0`, which §5.8 says does not
	spoil. The day that stops being true, this test fails and the gap must be answered.
	"""
	for key: StringName in GearScript.INSTANCE_REQUIRED_KEYS:
		var id: int = _item(key)
		assert_true(id >= 0, "%s is a catalog item" % key)
		assert_equal(_defs.shelf_hours(id), 0,
			"%s must have an unlimited shelf life while equipment aging is undecided" % key)


class StubAuthority extends RefCounted:
	"""A stand-in equipment authority attesting for exactly the lots it was told to.

	`gear.gd` is the real one. This exists so the equipped-lot half of the aging contract can be
	tested without the gear store deciding what the answer is.
	"""
	var attested: Dictionary = {}

	func attest(lot_ref: Vector2i) -> void:
		"""Start attesting for one lot."""
		attested[lot_ref] = true

	func is_equipped_record(lot_ref: Vector2i) -> bool:
		"""The attestation `inventory.gd` calls."""
		return attested.has(lot_ref)


func test_an_equipped_lot_refuses_to_age_rather_than_ageing_at_a_guessed_factor() -> void:
	"""An equipped lot is in no store, so there is no §5.8 factor to charge it at."""
	var store: Vector2i = _container(StockAgeScript.STORAGE_COVERED_STORE)
	var lot: Vector2i = _lot(store, &"tool", 1000)
	var authority: StubAuthority = StubAuthority.new()
	assert_true(_inv.set_equipment_authority(authority).ok, "an authority binds")
	authority.attest(lot)
	assert_true(_inv.detach_lot_to_equipment(lot).ok, "the proved lot is equipped")
	var out: IntMath.IntResult = IntMath.IntResult.new()
	assert_false(_inv.advance_lot_age_hour_into(lot, OPEN_PILE_FACTOR, SPRING_FACTOR, out),
		"an equipped lot refuses to age")
	assert_equal(out.error, "LOT_EQUIPPED", "with the reason named rather than a factor guessed")
	assert_equal(_inv.lot_age_milli_hours(lot), 0, "and no age was written")


func test_the_hourly_sweep_cannot_reach_an_equipped_lot_at_all() -> void:
	"""An equipped lot is threaded into no container chain, so the sweep never visits it."""
	var store: Vector2i = _container(StockAgeScript.STORAGE_OPEN_PILE)
	var shelved: Vector2i = _lot(store, &"grain", 1000)
	var equipped: Vector2i = _lot(store, &"tool", 1000)
	var authority: StubAuthority = StubAuthority.new()
	_inv.set_equipment_authority(authority)
	authority.attest(equipped)
	assert_true(_inv.detach_lot_to_equipment(equipped).ok, "the tool is equipped")
	var out: StockAgeScript.HourResult = _age.run_hour(_hour_tick(3, 9))
	assert_true(out.ok, "the hour runs")
	assert_equal(out.lots_aged, 1, "only the shelved lot was reached")
	assert_equal(out.refused_lots, 0, "and the equipped one was never even attempted")
	assert_equal(_inv.lot_age_milli_hours(shelved), OPEN_PILE_FACTOR, "the shelved lot aged")
	assert_equal(_inv.lot_age_milli_hours(equipped), 0, "the equipped one did not")


# --- the storage declarations ------------------------------------------------------------------------

func test_a_declaration_needs_a_live_container_and_a_real_storage_class() -> void:
	"""Neither half is taken on trust: an invalid ref and an invented class both refuse."""
	assert_false(_age.declare_storage_class(InventoryScript.NULL_REF,
		StockAgeScript.STORAGE_PANTRY), "the null ref is not a container")
	assert_equal(_age.last_refusal(), &"INVALID_CONTAINER", "and says so")
	var store: Vector2i = _container(StockAgeScript.STORAGE_UNDECLARED)
	assert_false(_age.declare_storage_class(store, StockAgeScript.STORAGE_CLASS_COUNT),
		"a class the GDD does not tabulate refuses")
	assert_equal(_age.last_refusal(), &"INVALID_STORAGE_CLASS", "with the class refusal")
	assert_equal(_age.declared_container_count(), 0, "and nothing was recorded")


func test_a_recycled_container_slot_does_not_inherit_the_old_storage_class() -> void:
	"""`inventory.gd` runs its own container generation space, and the declaration validates it."""
	var cellar: Vector2i = _container(StockAgeScript.STORAGE_CELLAR)
	assert_equal(_age.storage_class_of(cellar), StockAgeScript.STORAGE_CELLAR, "declared")
	assert_true(_inv.destroy_container(cellar).ok, "the cellar is demolished")
	var reused: InventoryScript.OpResult = _inv.create_container(
		OWNER, BIG_MASS_G, InventoryScript.FILTERS_ACCEPT_ALL, TEST_POLICY, true)
	assert_equal(reused.ref.x, cellar.x, "the allocator handed back the same slot")
	assert_true(reused.ref.y != cellar.y, "at a new generation")
	assert_equal(_age.storage_class_of(reused.ref), StockAgeScript.STORAGE_UNDECLARED,
		"and the new container is undeclared rather than inheriting a cellar's 350")


func test_the_sweep_drops_a_declaration_whose_container_is_gone() -> void:
	"""A stale declaration is cleaned up by the pass that finds it, not left to accumulate."""
	var doomed: Vector2i = _container(StockAgeScript.STORAGE_PANTRY)
	var kept: Vector2i = _container(StockAgeScript.STORAGE_CELLAR)
	var lot: Vector2i = _lot(kept, &"grain", 1000)
	assert_equal(_age.declared_container_count(), 2, "two declarations stand")
	assert_true(_inv.destroy_container(doomed).ok, "one container is destroyed")
	var out: StockAgeScript.HourResult = _age.run_hour(_hour_tick(3, 9))
	assert_true(out.ok, "the hour still runs")
	assert_equal(_age.declared_container_count(), 1, "the stale declaration is dropped")
	assert_equal(out.containers_aged, 1, "and only the live container was aged")
	assert_equal(_inv.lot_age_milli_hours(lot), CELLAR_FACTOR,
		"the surviving container's lot aged at its own factor")


func test_a_withdrawn_declaration_stops_the_container_ageing() -> void:
	"""The declaration is the seam the building layer owns; withdrawing it is part of that seam."""
	var store: Vector2i = _container(StockAgeScript.STORAGE_PANTRY)
	var lot: Vector2i = _lot(store, &"grain", 1000)
	assert_true(_age.withdraw_storage_class(store), "the declaration is withdrawn")
	assert_equal(_age.declared_container_count(), 0, "and the list is empty")
	assert_false(_age.withdraw_storage_class(store), "withdrawing twice refuses")
	assert_equal(_age.last_refusal(), &"CONTAINER_NOT_DECLARED", "and names why")
	assert_true(_age.run_hour(_hour_tick(3, 9)).ok, "the hour runs over nothing")
	assert_equal(_inv.lot_age_milli_hours(lot), 0, "and the lot did not age")


func test_binding_a_different_inventory_drops_every_declaration() -> void:
	"""A declaration names a container slot in ONE store; carrying it across would misname one."""
	var store: Vector2i = _container(StockAgeScript.STORAGE_CELLAR)
	assert_equal(_age.declared_container_count(), 1, "one declaration stands")
	var other: InventoryScript = InventoryScript.new(8, 64)
	_defs.load_default(other)
	assert_true(_age.bind_stores(other, _defs), "the stage is rebound to another store")
	assert_equal(_age.declared_container_count(), 0, "and carries no declaration across")
	assert_equal(_age.storage_class_of(store), StockAgeScript.STORAGE_UNDECLARED,
		"so slot %d of the new store inherits no cellar" % store.x)


func test_clear_drops_every_declaration_and_the_hourly_latch() -> void:
	"""A cleared stage is one settlement's state, not a stage carrying another world's stores."""
	var store: Vector2i = _container(StockAgeScript.STORAGE_PANTRY)
	assert_true(_age.run_hour(_hour_tick(3, 9)).ok, "an hour runs")
	_age.clear()
	assert_equal(_age.declared_container_count(), 0, "the declarations are gone")
	assert_equal(_age.storage_class_of(store), StockAgeScript.STORAGE_UNDECLARED,
		"including the one for a container that is still alive")
	assert_equal(_age.last_hour_tick(), StockAgeScript.NO_HOUR_RUN, "and the latch is dropped")


# --- STOCK-SEED-R01: expired seed converts to compost by exact floored nominal mass -------------
#
# Every number below is RESTATED FROM THE RULING (docs/rulings/2026-09-12_alerts_and_seed_expiry.md)
# or from `docs/gameplay_balance.md`'s item table, never read back out of `stock_age.gd`.

## The ruling's worked boundary table: expired seed milli-U -> compost milli-U, decay milli-grams.
const SEED_EXPIRY_TABLE: Array[Array] = [
	[1, 0, 100], [9, 0, 900], [10, 1, 0], [19, 1, 900], [1000, 100, 0], [10000, 1000, 0],
]

## The five seed items the ruling enumerates, and the two catalog masses it quotes.
const SEED_KEYS: Array[StringName] = [
	&"seed_beans", &"seed_cabbage", &"seed_flax", &"seed_grain", &"seed_roots",
]
const SEED_MASS_G: int = 100
const COMPOST_MASS_G: int = 1000
## "All five current seed items use 100 g/U and compost 1000 g/U, so this is floor(q/10)."
const EXPECTED_DIVISOR: int = 10


func _expired_seed_start_age(store_factor: int) -> int:
	"""Starting age that reaches a seed's 1440 h shelf threshold on the NEXT hour exactly."""
	return SEED_SHELF_HOURS * MILLI_HOURS_PER_HOUR - store_factor


func test_the_catalog_masses_still_make_the_expiry_divisor_exactly_ten() -> void:
	"""The tripwire for STOCK-SEED-R01's "currently floor(q_milli/10)".

	The module DERIVES its divisor from the two catalog masses and writes no 10 anywhere, which
	is the point: this test pins what that derivation currently evaluates to, so a catalog edit
	to a seed mass or to compost's mass FAILS here instead of silently re-pricing every expiry.
	"""
	for key: StringName in SEED_KEYS:
		var id: int = _item(key)
		assert_true(id >= 0, "%s is a catalog item" % key)
		assert_true(_defs.is_seed(id), "%s carries the seed flag the ruling triggers on" % key)
		assert_equal(_inv.item_mass_g(id), SEED_MASS_G, "%s is 100 g/U" % key)
		assert_equal(_defs.shelf_hours(id), SEED_SHELF_HOURS, "%s has a 1440 h shelf life" % key)
	assert_equal(_inv.item_mass_g(_item(&"compost")), COMPOST_MASS_G, "compost is 1000 g/U")
	assert_equal(COMPOST_MASS_G % SEED_MASS_G, 0, "the two masses divide, so a divisor exists")
	assert_equal(COMPOST_MASS_G / SEED_MASS_G, EXPECTED_DIVISOR,
		"the derived divisor is currently 10; changing a catalog mass must fail here")


func test_the_rulings_expiry_boundary_table_holds_row_by_row() -> void:
	"""floor_div(checked_mul(q, seed_mass), compost_mass), with EXACTLY one final floor.

	Dividing the masses first would agree on every row that is a multiple of ten and disagree on
	1, 9 and 19, which is why the ruling tabulates those three.
	"""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	for row: Array in SEED_EXPIRY_TABLE:
		var seed_milli: int = row[0]
		assert_true(StockAgeScript.expiry_compost_quantity_into(
			seed_milli, SEED_MASS_G, COMPOST_MASS_G, out), "%d milli-U converts" % seed_milli)
		assert_equal(out.value, row[1], "%d milli-U of seed yields %d of compost" % [row[0], row[1]])
		assert_true(StockAgeScript.expiry_decay_loss_milli_g_into(
			seed_milli, SEED_MASS_G, COMPOST_MASS_G, out), "%d milli-U has a loss" % seed_milli)
		assert_equal(out.value, row[2],
			"%d milli-U discards %d milli-grams as decay" % [row[0], row[2]])


func test_the_nominal_mass_invariant_holds_on_every_tabulated_row() -> void:
	"""STOCK-SEED-R01: "Required nominal invariant: compost_milli*compost_mass <= seed_milli*seed_mass"."""
	for row: Array in SEED_EXPIRY_TABLE:
		assert_true(row[1] * COMPOST_MASS_G <= row[0] * SEED_MASS_G,
			"%d milli-U of compost never carries more mass than %d of seed" % [row[1], row[0]])
		assert_equal(row[1] * COMPOST_MASS_G + row[2], row[0] * SEED_MASS_G,
			"and output mass plus decay loss accounts for the input exactly")


func test_a_zero_or_negative_mass_refuses_instead_of_answering_a_quantity() -> void:
	""""Positive validated catalog masses" -- an absent one has no yield, not a yield of zero."""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	assert_false(StockAgeScript.expiry_compost_quantity_into(1000, 0, COMPOST_MASS_G, out),
		"an unregistered seed mass refuses")
	assert_equal(out.error, "SEED_COMPOST_YIELD_UNREPRESENTABLE", "and names why")
	assert_equal(out.value, 0, "with the value channel zeroed rather than guessed")
	assert_false(StockAgeScript.expiry_compost_quantity_into(1000, SEED_MASS_G, 0, out),
		"an unregistered compost mass refuses")
	assert_false(StockAgeScript.expiry_compost_quantity_into(0, SEED_MASS_G, COMPOST_MASS_G, out),
		"and a lot of nothing has no conversion")
	assert_false(StockAgeScript.expiry_decay_loss_milli_g_into(1000, SEED_MASS_G, 0, out),
		"the decay-loss form refuses on the same inputs")


func test_a_yield_that_overflows_int64_refuses_rather_than_saturating() -> void:
	""""Do not saturate overflow": a saturated product would create matter out of arithmetic.

	Driven through the pure form because no container in this game admits 9.3e16 milli-U of a
	100 g/U seed, and the checked multiply must still be the thing that stops it.
	"""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	var huge: int = 9223372036854775807
	assert_false(StockAgeScript.expiry_compost_quantity_into(
		huge, SEED_MASS_G, COMPOST_MASS_G, out), "the product does not fit int64")
	assert_equal(out.value, 0, "and no compost quantity is invented")
	assert_false(StockAgeScript.expiry_decay_loss_milli_g_into(
		huge, SEED_MASS_G, COMPOST_MASS_G, out), "nor is a decay remainder")


func test_all_five_seed_items_become_compost_on_their_shelf_hour() -> void:
	""""Acceptance: all five seed types" -- each converts, and each at its own floored yield."""
	var store: Vector2i = _container(StockAgeScript.STORAGE_CELLAR)
	var lots: Array[Vector2i] = []
	for key: StringName in SEED_KEYS:
		lots.append(_lot(store, key, 10000, _expired_seed_start_age(CELLAR_FACTOR)))
	var out: StockAgeScript.HourResult = _age.run_hour(_hour_tick(3, 9))
	assert_true(out.ok, "the hour ran")
	assert_equal(out.seed_lots_converted, SEED_KEYS.size(), "all five seed lots converted")
	assert_equal(out.seed_lots_retired, 0, "none floored to zero at 10000 milli-U")
	assert_equal(out.compost_sourced_milli, SEED_KEYS.size() * 1000, "each yielding 1000")
	for lot: Vector2i in lots:
		assert_equal(_inv.lot_item_id(lot), _item(&"compost"), "the row is compost now")
		assert_equal(_inv.lot_quantity_milli(lot), 1000, "at floor(10000/10)")
		assert_equal(_inv.lot_age_milli_hours(lot), 0, "with a fresh age, not the seed's 1440 h")
	assert_true(_inv.audit().ok, "and conservation closes across all five")


func test_an_expired_seed_lot_is_sunk_whole_and_compost_sourced_floored() -> void:
	""""records the ENTIRE seed quantity as a seed sink and the calculated positive compost
	quantity as a compost source"."""
	var store: Vector2i = _container(StockAgeScript.STORAGE_CELLAR)
	var seed_id: int = _item(&"seed_grain")
	var compost_id: int = _item(&"compost")
	var lot: Vector2i = _lot(store, &"seed_grain", 10000, _expired_seed_start_age(CELLAR_FACTOR))
	var out: StockAgeScript.HourResult = _age.run_hour(_hour_tick(3, 9))
	assert_true(out.ok, "the hour ran")
	assert_equal(_inv.lot_item_id(lot), compost_id, "the row itself became compost")
	assert_equal(out.lots_expired, 1, "the conversion counts as an expiry")
	assert_equal(out.seed_sunk_milli, 10000, "the whole seed quantity is reported sunk")
	assert_equal(_inv.total_sunk_milli(seed_id), 10000, "and the seed ledger says the same")
	assert_equal(_inv.total_sourced_milli(compost_id), 1000, "while compost is sourced floored")
	assert_equal(_inv.total_live_milli(seed_id), 0, "no seed survives the conversion")
	assert_equal(_inv.total_live_milli(compost_id), 1000, "and the compost is live")
	assert_equal(out.seed_decay_loss_milli_g, 0, "an exact multiple of ten loses nothing")
	assert_true(_inv.audit().ok, "conservation closes on both items")


func test_the_floored_remainder_is_decay_loss_carried_by_the_seed_sink() -> void:
	"""19 milli-U -> 1 milli-U of compost and 900 milli-grams of decay loss (the ruling's row).

	The loss is not silently dropped: the ENTIRE 19 is sunk against seed_grain while only 1 is
	sourced as compost, so `audit()`'s per-item `live + sunk == sourced` still closes and the
	missing 0.9 g is visible as the difference between the two ledgers' nominal masses.
	"""
	var store: Vector2i = _container(StockAgeScript.STORAGE_CELLAR)
	var lot: Vector2i = _lot(store, &"seed_grain", 19, _expired_seed_start_age(CELLAR_FACTOR))
	var out: StockAgeScript.HourResult = _age.run_hour(_hour_tick(3, 9))
	assert_true(out.ok, "the hour ran")
	assert_equal(out.seed_lots_converted, 1, "19 milli-U still yields a positive lot")
	assert_equal(_inv.lot_quantity_milli(lot), 1, "of exactly 1 milli-U of compost")
	assert_equal(out.seed_decay_loss_milli_g, 900, "and reports 900 milli-grams of decay loss")
	assert_equal(_inv.total_sunk_milli(_item(&"seed_grain")), 19, "the whole 19 is sunk")
	assert_equal(_inv.total_sourced_milli(_item(&"compost")), 1, "only 1 milli-U is sourced")
	assert_true(1 * COMPOST_MASS_G <= 19 * SEED_MASS_G, "the nominal invariant holds")
	assert_true(_inv.audit().ok, "conservation closes with the loss accounted")


func test_a_seed_lot_whose_yield_floors_to_zero_is_retired_not_left_at_zero() -> void:
	""""When output is zero, atomically invalidate reservations and sink retire the seed lot
	without creating a zero-quantity compost lot"."""
	var store: Vector2i = _container(StockAgeScript.STORAGE_CELLAR)
	var lot: Vector2i = _lot(store, &"seed_grain", 9, _expired_seed_start_age(CELLAR_FACTOR))
	var out: StockAgeScript.HourResult = _age.run_hour(_hour_tick(3, 9))
	assert_true(out.ok, "the hour ran")
	assert_equal(out.seed_lots_retired, 1, "the lot retired")
	assert_equal(out.seed_lots_converted, 0, "nothing was converted")
	assert_equal(out.refused_lots, 0, "and retirement is an OUTCOME, not a refusal")
	assert_false(_inv.is_lot_valid(lot), "the row is gone rather than lingering at zero")
	assert_equal(_inv.live_lot_count(), 0, "no zero-quantity compost lot was created")
	assert_equal(_inv.total_live_milli(_item(&"compost")), 0, "and no compost exists")
	assert_equal(_inv.total_sunk_milli(_item(&"seed_grain")), 9, "the whole 9 is sunk as decay")
	assert_equal(out.seed_decay_loss_milli_g, 900, "all 900 milli-grams of it lost")
	assert_equal(_inv.container_used_mass_g(store), 0, "and the container got its mass back")
	assert_true(_inv.audit().ok, "conservation closes on a retirement too")


func test_splitting_a_seed_lot_can_only_lose_compost_never_gain_it() -> void:
	"""STOCK-SEED-R01: "sum(floor(q_i/10)) <= floor(sum(q_i)/10)", because the rule is PER LOT.

	18 milli-U in one lot yields 1; the same 18 as 9 + 9 yields 0 + 0. Applying the floor to the
	container's aggregate instead of per lot would hand the split stack a unit it did not earn.
	"""
	var whole_store: Vector2i = _container(StockAgeScript.STORAGE_CELLAR)
	_lot(whole_store, &"seed_grain", 18, _expired_seed_start_age(CELLAR_FACTOR))
	var whole: StockAgeScript.HourResult = _age.run_hour(_hour_tick(3, 9))
	assert_equal(whole.compost_sourced_milli, 1, "one lot of 18 milli-U yields 1")
	before_each()
	var split_store: Vector2i = _container(StockAgeScript.STORAGE_CELLAR)
	_lot(split_store, &"seed_grain", 9, _expired_seed_start_age(CELLAR_FACTOR))
	_lot(split_store, &"seed_grain", 9, _expired_seed_start_age(CELLAR_FACTOR))
	var split: StockAgeScript.HourResult = _age.run_hour(_hour_tick(3, 9))
	assert_equal(split.compost_sourced_milli, 0, "the same 18 split in two yields nothing")
	assert_equal(split.seed_lots_retired, 2, "both halves retire instead")
	assert_true(split.compost_sourced_milli <= whole.compost_sourced_milli,
		"splitting never increases the compost an expiring seed stack produces")


func test_a_seed_conversion_invalidates_its_reservations_in_the_same_transaction() -> void:
	""""Inventory atomically invalidates/releases the lot's reservations" at the boundary.

	Without the release inside the transaction `transform_lot_item()` refuses
	LOT_HAS_RESERVATION and the seed would still be seed, which is what this pins.
	"""
	var store: Vector2i = _container(StockAgeScript.STORAGE_CELLAR)
	var lot: Vector2i = _lot(store, &"seed_grain", 10000, _expired_seed_start_age(CELLAR_FACTOR))
	assert_true(_inv.reserve_lot(lot, 4000).ok, "a sowing job claims part of the seed")
	var out: StockAgeScript.HourResult = _age.run_hour(_hour_tick(3, 9))
	assert_true(out.ok, "the hour ran")
	assert_equal(out.reservations_invalidated_milli, 4000, "the claim is reported invalidated")
	assert_equal(_inv.lot_reserved_milli(lot), 0, "no worker keeps a claim on the compost")
	assert_equal(_inv.lot_item_id(lot), _item(&"compost"), "and the conversion still committed")
	assert_equal(out.replans_owed, 1, "with the replanning owed to an owner that does not exist")


func test_a_reserved_zero_yield_seed_lot_retires_with_its_claim_released() -> void:
	"""Zero output still releases the claim first: a retired lot may hold no reservation."""
	var store: Vector2i = _container(StockAgeScript.STORAGE_CELLAR)
	var lot: Vector2i = _lot(store, &"seed_grain", 9, _expired_seed_start_age(CELLAR_FACTOR))
	assert_true(_inv.reserve_lot(lot, 9).ok, "the whole 9 milli-U is claimed")
	var out: StockAgeScript.HourResult = _age.run_hour(_hour_tick(3, 9))
	assert_true(out.ok, "the hour ran")
	assert_equal(out.reservations_invalidated_milli, 9, "the claim is reported invalidated")
	assert_equal(out.seed_lots_retired, 1, "and the lot retired")
	assert_false(_inv.is_lot_valid(lot), "with no reserved quantity left pointing at nothing")
	assert_true(_inv.audit().ok, "conservation closes")


func test_a_seed_lot_one_hour_short_of_its_shelf_life_is_not_converted() -> void:
	""""Trigger only when the existing hourly aging pass REACHES the declared expiry".

	The crossing is `age >= shelf_hours * 1000` and nothing earlier: a lot two hours out still
	ages for real, and converts on the hour it actually reaches 1440000.
	"""
	var store: Vector2i = _container(StockAgeScript.STORAGE_CELLAR)
	var start: int = SEED_SHELF_HOURS * MILLI_HOURS_PER_HOUR - 2 * CELLAR_FACTOR
	var lot: Vector2i = _lot(store, &"seed_grain", 10000, start)
	var first: StockAgeScript.HourResult = _age.run_hour(_hour_tick(3, 9))
	assert_true(first.ok, "the first hour ran")
	assert_equal(first.seed_lots_converted, 0, "one hour short converts nothing")
	assert_equal(_inv.lot_item_id(lot), _item(&"seed_grain"), "the lot is still seed")
	assert_equal(_inv.lot_age_milli_hours(lot), SEED_SHELF_HOURS * MILLI_HOURS_PER_HOUR
		- CELLAR_FACTOR, "and it aged by exactly one cellar hour")
	var second: StockAgeScript.HourResult = _age.run_hour(_hour_tick(3, 10))
	assert_equal(second.seed_lots_converted, 1, "the next hour reaches the threshold exactly")
	assert_equal(_inv.lot_item_id(lot), _item(&"compost"), "and the seed becomes compost")


func test_a_seed_conversion_never_charges_the_container_more_mass() -> void:
	""""No extra container capacity may be charged from rounded seed mass".

	19 milli-U of a 100 g/U seed charges ceil(1900/1000) = 2 g; the 1 milli-U of compost it
	becomes charges 1 g. The floor can only ever return capacity, never take more.
	"""
	var store: Vector2i = _container(StockAgeScript.STORAGE_CELLAR)
	var lot: Vector2i = _lot(store, &"seed_grain", 19, _expired_seed_start_age(CELLAR_FACTOR))
	var before: int = _inv.container_used_mass_g(store)
	assert_equal(before, 2, "19 milli-U at 100 g/U charges a 2 g ceiling")
	assert_true(_age.run_hour(_hour_tick(3, 9)).ok, "the hour ran")
	assert_equal(_inv.lot_item_id(lot), _item(&"compost"), "the conversion committed")
	assert_equal(_inv.container_used_mass_g(store), 1, "and the compost charges 1 g")
	assert_true(_inv.container_used_mass_g(store) <= before, "never more than the seed did")


func test_a_refused_expiry_hour_leaves_the_inventory_byte_identical() -> void:
	"""Decision 0059: a refusal leaves every collaborating store byte identical.

	The hour is refused at preflight with somebody else's transaction open, which is the one
	refusal a unit test can force through the real catalog; `state_bytes()` is the proof, not a
	spot check of two fields.
	"""
	var store: Vector2i = _container(StockAgeScript.STORAGE_CELLAR)
	_lot(store, &"seed_grain", 10000, _expired_seed_start_age(CELLAR_FACTOR))
	var before: PackedByteArray = _inv.state_bytes()
	assert_true(_inv.begin().ok, "another owner opens a transaction")
	var out: StockAgeScript.HourResult = _age.run_hour(_hour_tick(3, 9))
	assert_false(out.ok, "the aging pass refuses rather than nesting")
	assert_equal(out.error, &"INVENTORY_TRANSACTION_OPEN", "and names why")
	assert_equal(out.seed_lots_converted, 0, "a refusal carries no counts")
	_inv.abort()
	assert_equal(_inv.state_bytes(), before, "and the store is byte identical")


# --- STOCK-SEED-R01's consumer eligibility predicate (enforcement is Inventory's) ----------------

func test_an_expired_seed_lot_is_refused_to_every_seed_consumer() -> void:
	"""The predicate STOCK-SEED-R01 requires seed consumers to apply, at the exact boundary.

	ENFORCEMENT IS NOT IN THIS MODULE: the ruling gives quantity admission to `inventory.gd`,
	which this lane does not own, so this proves the predicate and not that any consumer calls
	it. Nothing in the repository does yet.
	"""
	var store: Vector2i = _container(StockAgeScript.STORAGE_CELLAR)
	var threshold: int = SEED_SHELF_HOURS * MILLI_HOURS_PER_HOUR
	var fresh: Vector2i = _lot(store, &"seed_grain", 1000, threshold - 1)
	assert_false(_age.refuses_seed_consumption(fresh), "one milli-hour short is still usable")
	var expired: Vector2i = _lot(store, &"seed_grain", 1000, threshold)
	assert_true(_age.refuses_seed_consumption(expired), "reaching the threshold refuses it")
	var older: Vector2i = _lot(store, &"seed_grain", 1000, threshold + 5000)
	assert_true(_age.refuses_seed_consumption(older), "and so does anything past it")


func test_the_seed_guard_has_no_opinion_about_food_and_fails_closed() -> void:
	"""A non-seed answers false; anything the guard cannot evaluate answers true."""
	var store: Vector2i = _container(StockAgeScript.STORAGE_CELLAR)
	var berries: Vector2i = _lot(store, &"berries", 1000,
		BERRIES_SHELF_HOURS * MILLI_HOURS_PER_HOUR)
	assert_false(_age.refuses_seed_consumption(berries),
		"expired berries are not this guard's business")
	assert_true(_age.refuses_seed_consumption(InventoryScript.NULL_REF),
		"an invalid lot is never admitted")
	assert_true(_age.refuses_seed_consumption(Vector2i(berries.x, berries.y + 1)),
		"nor is a stale reference whose generation has moved on")
	var unbound: StockAgeScript = StockAgeScript.new()
	assert_true(unbound.refuses_seed_consumption(Vector2i(0, 1)),
		"and an unbound stage refuses rather than admitting what it cannot read")


func test_reading_the_seed_guard_converts_nothing() -> void:
	"""STOCK-SEED-R01: "No conversion on ... reads". The predicate is a read and stays one."""
	var store: Vector2i = _container(StockAgeScript.STORAGE_CELLAR)
	var lot: Vector2i = _lot(store, &"seed_grain", 10000,
		SEED_SHELF_HOURS * MILLI_HOURS_PER_HOUR)
	var before: PackedByteArray = _inv.state_bytes()
	assert_true(_age.refuses_seed_consumption(lot), "the lot is past its shelf life")
	assert_equal(_inv.state_bytes(), before, "and reading that changed nothing at all")
	assert_equal(_inv.lot_item_id(lot), _item(&"seed_grain"), "the seed is still seed")
	assert_equal(_inv.total_sourced_milli(_item(&"compost")), 0, "no compost was sourced")
