extends "res://test/framework/test_case.gd"
## Coverage for `scripts/core/farming.gd`: the §4.2 FarmPlot store, the systems_architecture.md §2
## TileHistory ledger, the five-row §5.6 crop catalog, and REQ-SET-072/073/074/075/076/078/084/
## 085/086/087.
##
## THE §5.6 TABLE IS TRANSCRIBED HERE INDEPENDENTLY, straight from the GDD, and the module is
## asserted against THIS copy. Re-deriving the expectations from `farming.gd`'s own constants
## would prove only that the module agrees with itself -- the same discipline test_weather.gd
## applies to §5.10's selection intervals.

const Farming := preload("res://scripts/core/farming.gd")
const CatalogScript := preload("res://scripts/core/catalog.gd")
const SimClockScript := preload("res://scripts/core/sim_clock.gd")
const EntityDirectoryScript := preload("res://scripts/core/entity_directory.gd")

# --- GDD §5.6's crop table, transcribed independently -------------------------------------------------

## Row order is catalog.gd's ascending-ASCII compile order, which §4.3 fixes for CropDefinition.
const KEYS: Array[StringName] = [&"beans", &"cabbage", &"flax", &"grain", &"roots"]
## The compiled CropFamily ids. BAL-CAT-002 names crop-family as a domain whose numeric IDs come
## from BAL-CAT-001, i.e. the ascending ASCII order of §5.6's own uppercase family names --
## restated here from that contract, not read back out of catalog.gd or the module.
const CEREAL: int = 0
const FIBER: int = 1
const LEAF: int = 2
const LEGUME: int = 3
const ROOT: int = 4
const FAMILY_COUNT: int = 5
## §5.6 "Family": beans LEGUME, cabbage LEAF, flax FIBER, grain CEREAL, roots ROOT.
const FAMILY: Array[int] = [LEGUME, LEAF, FIBER, CEREAL, ROOT]
## §5.6 "Soils" as BAL-CROP-001's `1<<Soil` mask: loam 1, clay 2, sand 4.
const SOILS: Array[int] = [3, 3, 5, 3, 5]
## §5.6 "Growth game hours".
const GROWTH_HOURS: Array[int] = [144, 120, 168, 192, 120]
## §5.6 "Yield U/tile", in milli-units.
const YIELD_MILLI: Array[int] = [7000, 6000, 5000, 10000, 6000]
## §5.6 "Seed U/tile", in milli-units.
const SEED_MILLI: Array[int] = [250, 250, 250, 250, 250]
## §5.6 "Moisture min-max".
const MOISTURE_MIN: Array[int] = [4000, 4000, 3000, 3500, 2500]
const MOISTURE_MAX: Array[int] = [8000, 8500, 7500, 7500, 7000]
## §5.6 "Frost damage/hour".
const FROST: Array[int] = [1500, 150, 800, 1000, 300]
## §5.6 "Fertility cost/harvest". Beans state -800: a GAIN, and the sign is part of the table.
const FERTILITY_COST: Array[int] = [-800, 900, 800, 1200, 700]
## §5.6 "Plant windows", one legal (season, season_day) per crop, transcribed by hand:
## beans Spring 5-10, cabbage Summer 5-10, flax Spring 1-6, grain Spring 1-4, roots Spring 1-8.
const LEGAL_SEASON: Array[int] = [0, 1, 0, 0, 0]
const LEGAL_DAY: Array[int] = [5, 5, 1, 1, 1]

const LOAM: int = 0
const CLAY: int = 1
const SAND: int = 2
const BEANS: int = 0
const CABBAGE: int = 1
const FLAX: int = 2
const GRAIN: int = 3
const ROOTS: int = 4

const EMPTY: int = 0
const SOWN: int = 1
const GROWING: int = 2
const RIPE: int = 3
const WITHERED: int = 4

const TICKS_PER_HOUR: int = 750
const TILE: int = 100

var _store: Farming = null


func before_each() -> void:
	"""Build a fresh store with its own private directory for every test."""
	_store = Farming.new()


func after_each() -> void:
	"""Drop the store; RefCounted frees it and its private directory with it."""
	_store = null


# --- helpers ------------------------------------------------------------------------------------------

func _plot(tile: int = TILE, soil: int = LOAM, day: int = 1) -> int:
	"""Create one plot and return its row, failing the test if the create refused.

	`day` is required by READY_06 §6.3: `compost_milli` is a current-season mirror the store
	derives at creation, so a create cannot be dated implicitly.
	"""
	var created: Farming.OpResult = _store.create_plot_at_tile(tile, soil, day)
	assert_true(created.ok, "create_plot_at_tile (error: %s)" % created.error)
	return created.value


func _sown(crop: int, tile: int = TILE, soil: int = LOAM, day: int = 1) -> int:
	"""Create a plot and plant `crop` on it in one of §5.6's legal windows for that crop."""
	var slot: int = _plot(tile, soil)
	var planted: Farming.OpResult = _store.plant(slot, crop, day, LEGAL_SEASON[crop], LEGAL_DAY[crop])
	assert_true(planted.ok, "plant (error: %s)" % planted.error)
	return slot


func _growing(crop: int, tile: int = TILE, soil: int = LOAM, day: int = 1) -> int:
	"""Create, plant and start growing one plot: the state REQ-SET-072 integrates in."""
	var slot: int = _sown(crop, tile, soil, day)
	assert_true(_store.begin_growing(slot).ok, "begin_growing")
	return slot


func _grow_hours(slot: int, hours: int, temperature_tenths: int, first_hour: int = 0) -> void:
	"""Advance `hours` whole game hours from `first_hour`, ignoring a refusal after ripening."""
	for hour: int in hours:
		_store.advance_growth_hour(slot, temperature_tenths, (first_hour + hour) * TICKS_PER_HOUR)


func _ripe(crop: int, tile: int = TILE, soil: int = LOAM) -> int:
	"""Grow one plot to RIPE at ideal temperature and in-range moisture, ripening at tick 0-based."""
	var slot: int = _growing(crop, tile, soil)
	_grow_hours(slot, GROWTH_HOURS[crop], 120)
	assert_equal(_store.state_of(slot).value, RIPE, "plot must be RIPE after its full duration")
	return slot


func _ripe_tick_of(crop: int) -> int:
	"""The tick `_ripe()` records as `ripe_tick`: the last hour of the crop's duration."""
	return (GROWTH_HOURS[crop] - 1) * TICKS_PER_HOUR


# --- the §5.6 crop catalog, transcribed row by row ----------------------------------------------------

func test_the_five_crop_keys_compile_to_the_ids_the_module_uses() -> void:
	"""§4.3 numbers a catalog from its ascending ASCII keys, so beans=0 ... roots=4, NOT §5.6's
	printed table order. A drift here repoints every column table at a different crop."""
	var compiled: CatalogScript.DomainResult = CatalogScript.compile_domain(
		"CropDefinition", KEYS
	)
	assert_true(compiled.ok, "the CropDefinition catalog compiles")
	assert_equal(compiled.ids, {&"beans": 0, &"cabbage": 1, &"flax": 2, &"grain": 3, &"roots": 4},
		"the whole compiled crop id table")
	for crop: int in KEYS.size():
		assert_equal(_store.crop_key_of(crop), KEYS[crop], "crop_key_of(%d)" % crop)


func test_every_crop_family_matches_the_gdd_table() -> void:
	"""§5.6's Family column, row by row, against an independent transcription."""
	for crop: int in KEYS.size():
		assert_equal(_store.family_of(crop).value, FAMILY[crop], "family of %s" % KEYS[crop])
	assert_equal(_store.family_of(BEANS).value, Farming.FAMILY_LEGUME, "beans are the LEGUME")


func test_family_ids_are_the_generated_ascii_order() -> void:
	"""BAL-CAT-002: crop-family uses BAL-CAT-001's generated IDs, i.e. ascending ASCII keys."""
	assert_equal(Farming.FAMILY_CEREAL, CEREAL, "CEREAL sorts first of the five keys")
	assert_equal(Farming.FAMILY_FIBER, FIBER, "FIBER sorts second")
	assert_equal(Farming.FAMILY_LEAF, LEAF, "LEAF sorts third")
	assert_equal(Farming.FAMILY_LEGUME, LEGUME, "LEGUME sorts fourth")
	assert_equal(Farming.FAMILY_ROOT, ROOT, "ROOT sorts fifth")
	assert_equal(Farming.FAMILY_COUNT, FAMILY_COUNT, "§5.6 names five families")
	assert_equal(Farming.FAMILY_NONE, -1, "§4.2: no previous family is the empty catalog id -1")


func test_every_allowed_soil_mask_matches_the_gdd_table() -> void:
	"""§5.6's Soils column as BAL-CROP-001's `1<<Soil` mask: grain/beans/cabbage 3, flax/roots 5."""
	for crop: int in KEYS.size():
		assert_equal(_store.allowed_soils_of(crop).value, SOILS[crop], "soils of %s" % KEYS[crop])


func test_soil_compatibility_follows_the_mask_for_all_fifteen_pairs() -> void:
	"""Every crop against every soil, so a flipped bit fails rather than passing on one pair."""
	for crop: int in KEYS.size():
		for soil: int in [LOAM, CLAY, SAND]:
			var expected: bool = (SOILS[crop] & (1 << soil)) != 0
			assert_equal(_store.is_soil_compatible(crop, soil), expected,
				"%s on soil %d" % [KEYS[crop], soil])


func test_every_growth_duration_and_base_yield_matches_the_gdd_table() -> void:
	"""§5.6's Growth game hours and Yield U/tile columns."""
	for crop: int in KEYS.size():
		assert_equal(_store.growth_hours_of(crop).value, GROWTH_HOURS[crop],
			"growth hours of %s" % KEYS[crop])
		assert_equal(_store.base_yield_milli_of(crop).value, YIELD_MILLI[crop],
			"base yield of %s" % KEYS[crop])


func test_every_seed_quantity_moisture_range_and_frost_damage_matches_the_gdd_table() -> void:
	"""§5.6's Seed U/tile, Moisture min-max and Frost damage/hour columns."""
	for crop: int in KEYS.size():
		assert_equal(_store.seed_milli_of(crop).value, SEED_MILLI[crop], "seed of %s" % KEYS[crop])
		assert_equal(_store.moisture_min_of(crop).value, MOISTURE_MIN[crop],
			"moisture min of %s" % KEYS[crop])
		assert_equal(_store.moisture_max_of(crop).value, MOISTURE_MAX[crop],
			"moisture max of %s" % KEYS[crop])
		assert_equal(_store.frost_damage_per_hour_of(crop).value, FROST[crop],
			"frost damage of %s" % KEYS[crop])


func test_every_fertility_cost_matches_the_gdd_table_including_the_bean_gain() -> void:
	"""§5.6's Fertility cost/harvest column. Beans are -800 -- a GAIN -- and the sign is the data."""
	for crop: int in KEYS.size():
		assert_equal(_store.fertility_cost_of(crop).value, FERTILITY_COST[crop],
			"fertility cost of %s" % KEYS[crop])
	assert_true(_store.fertility_cost_of(BEANS).value < 0, "beans must state a negative cost")


func test_the_plant_windows_match_the_gdd_table_on_both_sides_of_every_endpoint() -> void:
	"""BAL-CROP-001: "Plant-window endpoints are inclusive season-local days." Grain Spring 1-4."""
	assert_false(_store.is_plant_window(GRAIN, 0, 0), "day 0 is not a season day at all")
	assert_true(_store.is_plant_window(GRAIN, 0, 1), "grain opens on spring day 1")
	assert_true(_store.is_plant_window(GRAIN, 0, 4), "grain closes on spring day 4 inclusive")
	assert_false(_store.is_plant_window(GRAIN, 0, 5), "grain is shut on spring day 5")
	assert_false(_store.is_plant_window(GRAIN, 1, 1), "grain has no summer window")


func test_the_two_window_crops_carry_both_of_their_gdd_windows() -> void:
	"""Beans Spring 5-10 and Summer 1-3; roots Spring 1-8 and Summer 1-4; cabbage Summer 5-10 and
	Autumn 1-3. A second window silently dropped would leave every one of these false."""
	assert_equal(_store.window_count_of(BEANS).value, 2, "beans state two windows")
	assert_false(_store.is_plant_window(BEANS, 0, 4), "beans shut on spring day 4")
	assert_true(_store.is_plant_window(BEANS, 0, 10), "beans open through spring day 10")
	assert_false(_store.is_plant_window(BEANS, 0, 11), "beans shut on spring day 11")
	assert_true(_store.is_plant_window(BEANS, 1, 3), "beans open through summer day 3")
	assert_false(_store.is_plant_window(BEANS, 1, 4), "beans shut on summer day 4")
	assert_true(_store.is_plant_window(ROOTS, 0, 8), "roots open through spring day 8")
	assert_false(_store.is_plant_window(ROOTS, 0, 9), "roots shut on spring day 9")
	assert_true(_store.is_plant_window(ROOTS, 1, 4), "roots open through summer day 4")
	assert_true(_store.is_plant_window(CABBAGE, 1, 5), "cabbage opens on summer day 5")
	assert_false(_store.is_plant_window(CABBAGE, 1, 4), "cabbage shut on summer day 4")
	assert_true(_store.is_plant_window(CABBAGE, 2, 3), "cabbage open through autumn day 3")
	assert_false(_store.is_plant_window(CABBAGE, 2, 4), "cabbage shut on autumn day 4")
	assert_equal(_store.window_count_of(FLAX).value, 1, "flax states one window")


func test_crop_readers_refuse_an_unknown_crop_without_a_value() -> void:
	"""No sentinel: an unknown crop refuses with an empty value on every catalog reader."""
	for reader: String in ["family_of", "allowed_soils_of", "growth_hours_of",
			"base_yield_milli_of", "seed_milli_of", "moisture_min_of", "moisture_max_of",
			"frost_damage_per_hour_of", "fertility_cost_of"]:
		var result: Variant = _store.call(reader, 5)
		assert_false(result.ok, "%s(5) must refuse" % reader)
		assert_equal(result.value, 0, "%s(5) carries no value" % reader)
	assert_equal(_store.crop_key_of(-1), &"", "crop_key_of names no key for CROP_NONE")


# --- REQ-SET-072 temperature factor, both sides of every boundary ---------------------------------------

func test_temperature_factor_hits_every_stated_band() -> void:
	"""§5.6: "0 below 0°C, 500 at 0-7°C, 1000 at 8-26°C, 700 above 26°C", in tenths."""
	assert_equal(Farming.temperature_factor_of(-100), 0, "-10°C is below freezing")
	assert_equal(Farming.temperature_factor_of(0), 500, "0°C opens the cool band")
	assert_equal(Farming.temperature_factor_of(70), 500, "7°C is still cool")
	assert_equal(Farming.temperature_factor_of(80), 1000, "8°C opens the ideal band")
	assert_equal(Farming.temperature_factor_of(260), 1000, "26°C is still ideal")
	assert_equal(Farming.temperature_factor_of(270), 700, "27°C is above the ideal band")
	assert_equal(Farming.temperature_factor_of(400), 700, "40°C stays in the hot band")


func test_temperature_factor_boundaries_are_exact_on_both_sides() -> void:
	"""The three thresholds, one tenth either side. These are the classic off-by-one sites, and
	every §5.10 temperature is a whole degree, so a one-tenth slip is invisible in play."""
	assert_equal(Farming.temperature_factor_of(-1), 0, "-0.1°C is below freezing")
	assert_equal(Farming.temperature_factor_of(0), 500, "exactly 0°C is not below freezing")
	assert_equal(Farming.temperature_factor_of(79), 500, "7.9°C is the last cool tenth")
	assert_equal(Farming.temperature_factor_of(80), 1000, "8.0°C is the first ideal tenth")
	assert_equal(Farming.temperature_factor_of(269), 1000, "26.9°C is the last ideal tenth")
	assert_equal(Farming.temperature_factor_of(270), 700, "27.0°C is the first hot tenth")


func test_the_weather_module_temperatures_land_in_the_expected_bands() -> void:
	"""§5.10's own baselines and event temperatures, as tenths, against §5.6's bands: winter -5°C
	stops growth outright, spring 12°C and summer 22°C are ideal, drought's 30°C is hot."""
	assert_equal(Farming.temperature_factor_of(-50), 0, "winter baseline -5°C stops growth")
	assert_equal(Farming.temperature_factor_of(20), 500, "ideal spell's winter 2°C is cool")
	assert_equal(Farming.temperature_factor_of(100), 1000, "autumn baseline 10°C is ideal")
	assert_equal(Farming.temperature_factor_of(120), 1000, "spring baseline 12°C is ideal")
	assert_equal(Farming.temperature_factor_of(220), 1000, "summer baseline 22°C is ideal")
	assert_equal(Farming.temperature_factor_of(300), 700, "drought's 30°C is above the band")
	assert_equal(Farming.temperature_factor_of(-120), 0, "hard freeze's -12°C stops growth")


# --- REQ-SET-072 moisture factor, both sides of every boundary -------------------------------------------

func test_moisture_factor_is_1000_inside_the_stated_range_inclusive() -> void:
	"""Grain's stated 3500-7500, endpoints included."""
	assert_equal(_store.moisture_factor_of(GRAIN, 3500).value, 1000, "grain at its minimum")
	assert_equal(_store.moisture_factor_of(GRAIN, 5000).value, 1000, "grain mid-range")
	assert_equal(_store.moisture_factor_of(GRAIN, 7500).value, 1000, "grain at its maximum")


func test_moisture_factor_boundaries_below_the_range_are_exact() -> void:
	""""500 within 2000 outside range, 0 farther outside", read as an inclusive 2000 margin."""
	assert_equal(_store.moisture_factor_of(GRAIN, 3499).value, 500, "one below the minimum")
	assert_equal(_store.moisture_factor_of(GRAIN, 1500).value, 500, "exactly 2000 below")
	assert_equal(_store.moisture_factor_of(GRAIN, 1499).value, 0, "2001 below is farther outside")
	assert_equal(_store.moisture_factor_of(GRAIN, 0).value, 0, "bone dry")


func test_moisture_factor_boundaries_above_the_range_are_exact() -> void:
	"""The same margin on the wet side. BAL-PROBE-001 corroborates 9400 -> 500 and 9600 -> 0."""
	assert_equal(_store.moisture_factor_of(GRAIN, 7501).value, 500, "one above the maximum")
	assert_equal(_store.moisture_factor_of(GRAIN, 9400).value, 500, "BAL-PROBE-001 day 13")
	assert_equal(_store.moisture_factor_of(GRAIN, 9500).value, 500, "exactly 2000 above")
	assert_equal(_store.moisture_factor_of(GRAIN, 9501).value, 0, "2001 above is farther outside")
	assert_equal(_store.moisture_factor_of(GRAIN, 9600).value, 0, "BAL-PROBE-001 day 6")
	assert_equal(_store.moisture_factor_of(GRAIN, 10000).value, 0, "saturated")


func test_every_crop_uses_its_own_moisture_range() -> void:
	"""Each crop's own endpoints, so one row's numbers cannot stand in for another's."""
	for crop: int in KEYS.size():
		assert_equal(_store.moisture_factor_of(crop, MOISTURE_MIN[crop]).value, 1000,
			"%s at its minimum" % KEYS[crop])
		assert_equal(_store.moisture_factor_of(crop, MOISTURE_MIN[crop] - 1).value, 500,
			"%s just under its minimum" % KEYS[crop])
		assert_equal(_store.moisture_factor_of(crop, MOISTURE_MAX[crop]).value, 1000,
			"%s at its maximum" % KEYS[crop])
		assert_equal(_store.moisture_factor_of(crop, MOISTURE_MAX[crop] + 1).value, 500,
			"%s just over its maximum" % KEYS[crop])


func test_moisture_factor_refuses_a_moisture_outside_the_stated_clamp() -> void:
	"""REQ-SET-086 clamps stored moisture to 0..10000, so a value outside it names no plot state."""
	var below: Variant = _store.moisture_factor_of(GRAIN, -1)
	assert_false(below.ok, "negative moisture must refuse")
	assert_equal(below.value, 0, "a refusal carries no value")
	assert_false(_store.moisture_factor_of(GRAIN, 10001).ok, "moisture above 10000 must refuse")
	assert_false(_store.moisture_factor_of(9, 5000).ok, "an unknown crop must refuse")


# --- REQ-SET-072 the hourly step -------------------------------------------------------------------------

func test_the_hourly_growth_step_is_the_stated_formula() -> void:
	"""§5.6: "1000 milli-hours x temperature_factor x moisture_factor/1000000"."""
	assert_equal(_store.growth_step_milli_hours(1000, 1000).value, 1000, "both factors ideal")
	assert_equal(_store.growth_step_milli_hours(500, 1000).value, 500, "cool, in range")
	assert_equal(_store.growth_step_milli_hours(1000, 500).value, 500, "ideal, near range")
	assert_equal(_store.growth_step_milli_hours(700, 1000).value, 700, "hot, in range")
	assert_equal(_store.growth_step_milli_hours(700, 500).value, 350, "hot and near range")
	assert_equal(_store.growth_step_milli_hours(0, 1000).value, 0, "frozen stops growth")
	assert_equal(_store.growth_step_milli_hours(1000, 0).value, 0, "far outside range stops growth")


func test_growth_accumulates_one_milli_hour_per_hour_at_ideal_conditions() -> void:
	"""A grain plot at 12°C and moisture 6000 gains exactly 1000 milli-hours per hour."""
	var slot: int = _growing(GRAIN)
	_grow_hours(slot, 1, 120)
	assert_equal(_store.growth_milli_hours_of(slot).value, 1000, "one ideal hour")
	_grow_hours(slot, 23, 120, 1)
	assert_equal(_store.growth_milli_hours_of(slot).value, 24000, "one ideal day")
	assert_equal(_store.state_of(slot).value, GROWING, "grain needs 192 hours, not 24")


func test_growth_is_frozen_below_zero_and_slowed_in_the_cool_band() -> void:
	"""The two factors reach the stored column, not just the pure reader."""
	var frozen: int = _growing(GRAIN)
	_grow_hours(frozen, 24, -10)
	assert_equal(_store.growth_milli_hours_of(frozen).value, 0, "no growth below 0°C")
	var cool: int = _growing(GRAIN, TILE + 1)
	_grow_hours(cool, 24, 70)
	assert_equal(_store.growth_milli_hours_of(cool).value, 12000, "24 cool hours at 500 each")


func test_the_growth_remainder_column_stays_zero_under_every_stated_factor_pair() -> void:
	"""§5.6's factors are all multiples of 100, so `1000*tf*mf` is always an exact multiple of
	1000000 and REQ-SET-072's retained fraction is 0. The column exists because the arithmetic
	requires somewhere to keep it, and this asserts the stated tables never need it."""
	var slot: int = _growing(GRAIN)
	_grow_hours(slot, 24, 300)
	assert_equal(_store.tile_growth_remainder_of(TILE).value, 0, "no remainder at 30°C in range")
	_store.apply_moisture_delta(slot, 2000)
	_grow_hours(slot, 24, 300, 24)
	assert_equal(_store.tile_growth_remainder_of(TILE).value, 0, "no remainder at 700x500")
	assert_equal(_store.growth_milli_hours_of(slot).value, 24 * 700 + 24 * 350, "both day totals")


func test_growth_refuses_a_plot_that_is_not_growing() -> void:
	"""REQ-SET-072 integrates "while a crop is growing" -- SOWN, RIPE and EMPTY are not that."""
	var empty: int = _plot()
	var advanced: Farming.OpResult = _store.advance_growth_hour(empty, 120, 0)
	assert_false(advanced.ok, "an empty plot cannot grow")
	assert_equal(advanced.error, Farming.REFUSE_NOT_GROWING, "refusal code")
	assert_equal(advanced.value, 0, "a refusal carries no value")
	var sown: int = _sown(GRAIN, TILE + 1)
	assert_false(_store.advance_growth_hour(sown, 120, 0).ok, "a SOWN plot has work outstanding")
	assert_false(_store.advance_growth_hour(4095, 120, 0).ok, "an empty row refuses")


# --- BAL-PROBE-001, the executed diagnostic ------------------------------------------------------------------

## The moisture and moisture_factor columns of BAL-PROBE-001, absolute days 1..19, transcribed.
const PROBE_MOISTURE: Array[int] = [
	6000, 6600, 7200, 7800, 8400, 9600, 10000, 10000, 10000, 10000,
	10000, 10000, 9400, 8800, 8200, 7600, 7000, 6400, 5800,
]
const PROBE_FACTOR: Array[int] = [
	1000, 1000, 1000, 500, 500, 0, 0, 0, 0, 0, 0, 0, 500, 500, 500, 500, 1000, 1000, 1000,
]
## The probe's cumulative_growth_milli_hours column for days 1..18. Day 1 carries 18 hours because
## tick 0 is 06:00 (§5.1); every later day carries 24. Day 19's printed 210000 is the
## counterfactual total with ripening ignored, so it is checked as a ripening day instead.
const PROBE_GROWTH: Array[int] = [
	18000, 42000, 66000, 78000, 90000, 90000, 90000, 90000, 90000, 90000,
	90000, 90000, 102000, 114000, 126000, 138000, 162000, 186000,
]


func test_bal_probe_001_moisture_factors_reproduce_the_published_column() -> void:
	"""Every moisture the executed probe printed, against the factor it printed beside it."""
	assert_equal(PROBE_MOISTURE.size(), 19, "the probe published nineteen days")
	for index: int in PROBE_MOISTURE.size():
		assert_equal(_store.moisture_factor_of(GRAIN, PROBE_MOISTURE[index]).value,
			PROBE_FACTOR[index], "BAL-PROBE-001 day %d" % (index + 1))


func test_bal_probe_001_growth_totals_reproduce_the_published_column() -> void:
	"""Drive a grain plot through the probe's own moisture trace and match its cumulative column.

	The probe holds temperature at the spring/ideal-spell/summer baselines, all of which score
	1000, so the moisture factor alone shapes the curve."""
	var slot: int = _growing(GRAIN)
	var hour: int = 0
	for index: int in PROBE_GROWTH.size():
		_set_moisture(slot, PROBE_MOISTURE[index])
		var hours: int = 18 if index == 0 else 24
		_grow_hours(slot, hours, 120, hour)
		hour += hours
		assert_equal(_store.growth_milli_hours_of(slot).value, PROBE_GROWTH[index],
			"BAL-PROBE-001 cumulative growth on day %d" % (index + 1))
	assert_equal(_store.state_of(slot).value, GROWING, "not yet ripe at the end of day 18")


func test_bal_probe_001_first_ripe_day_is_day_nineteen() -> void:
	"""BAL-PROBE-001: "First ripe day is 19 in this diagnostic". Six hours into day 19 the plot
	reaches grain's 192 hours exactly; a day-18 ripening would create food before the GDD permits."""
	var slot: int = _growing(GRAIN)
	var hour: int = 0
	for index: int in PROBE_GROWTH.size():
		_set_moisture(slot, PROBE_MOISTURE[index])
		var hours: int = 18 if index == 0 else 24
		_grow_hours(slot, hours, 120, hour)
		hour += hours
	_set_moisture(slot, PROBE_MOISTURE[18])
	_grow_hours(slot, 5, 120, hour)
	assert_equal(_store.state_of(slot).value, GROWING, "five hours into day 19 is not enough")
	_grow_hours(slot, 1, 120, hour + 5)
	assert_equal(_store.state_of(slot).value, RIPE, "the sixth hour of day 19 completes 192 hours")
	assert_equal(_store.growth_milli_hours_of(slot).value, 192000, "exactly 192 game hours")


func _set_moisture(slot: int, moisture: int) -> void:
	"""Move a plot's moisture to an exact value through the clamped delta path."""
	var current: int = _store.moisture_of(slot).value
	assert_true(_store.apply_moisture_delta(slot, moisture - current).ok, "apply_moisture_delta")


# --- REQ-SET-073 ripening -------------------------------------------------------------------------------------

func test_a_crop_ripens_exactly_at_its_stated_duration_not_one_hour_early() -> void:
	"""REQ-SET-073 marks ripe "when growth reaches the crop's duration" -- 192 hours for grain."""
	var slot: int = _growing(GRAIN)
	_grow_hours(slot, 191, 120)
	assert_equal(_store.state_of(slot).value, GROWING, "191 hours is not the stated duration")
	assert_equal(_store.growth_milli_hours_of(slot).value, 191000, "191 whole hours accumulated")
	_grow_hours(slot, 1, 120, 191)
	assert_equal(_store.state_of(slot).value, RIPE, "the 192nd hour ripens grain")
	assert_true(_store.is_ripe(slot), "is_ripe agrees with the state column")


func test_every_crop_ripens_at_its_own_duration() -> void:
	"""Cabbage and roots at 120, beans at 144, flax at 168, grain at 192: five separate numbers."""
	for crop: int in KEYS.size():
		var store: Farming = Farming.new()
		var created: Farming.OpResult = store.create_plot_at_tile(TILE, LOAM, 1)
		var slot: int = created.value
		store.plant(slot, crop, 1, LEGAL_SEASON[crop], LEGAL_DAY[crop])
		store.begin_growing(slot)
		for hour: int in GROWTH_HOURS[crop] - 1:
			store.advance_growth_hour(slot, 120, hour * TICKS_PER_HOUR)
		assert_equal(store.state_of(slot).value, GROWING, "%s one hour early" % KEYS[crop])
		store.advance_growth_hour(slot, 120, (GROWTH_HOURS[crop] - 1) * TICKS_PER_HOUR)
		assert_equal(store.state_of(slot).value, RIPE, "%s at its duration" % KEYS[crop])


func test_ripening_dates_the_tile_and_exposes_the_stated_job_priority() -> void:
	"""REQ-SET-073 also creates a priority-2 harvest job. The transition and the priority are
	exposed; the job is ARCH-SYS-006's, and this store must not create one."""
	assert_equal(_store.tile_ripe_tick_of(TILE).value, -1, "an unworked tile has no ripe tick")
	var slot: int = _ripe(GRAIN)
	assert_equal(_store.tile_ripe_tick_of(TILE).value, _ripe_tick_of(GRAIN),
		"the ripening tick is dated onto the tile")
	assert_equal(_store.harvest_job_priority(), 2, "REQ-SET-073's stated priority")
	assert_equal(_store.harvest_work_milli_wu(), 6000, "§5.6's 6 WU harvest")
	assert_equal(_store.sow_work_milli_wu(), 4000, "§5.6's 4 WU sowing")
	assert_equal(_store.tend_work_milli_wu(), 1000, "§5.6's 1 WU tending/day")


# --- REQ-SET-074 harvest yield -----------------------------------------------------------------------------------

func test_the_fertility_factor_is_500_plus_a_twentieth_and_clamped() -> void:
	"""§5.6: "Fertility factor=500+floor(fertility/20) (500-1000)"."""
	var slot: int = _plot()
	assert_equal(_store.fertility_factor_of(slot).value, 850, "7000 fertility gives 850")
	_store.apply_compost(slot, 1)
	assert_equal(_store.fertility_factor_of(slot).value, 925, "8500 fertility gives 925")
	_store.apply_compost(slot, 13)
	assert_equal(_store.fertility_factor_of(slot).value, 1000, "10000 fertility gives exactly 1000")


func test_the_health_factor_is_health_divided_by_ten() -> void:
	"""§5.6: "health factor=health 0-10000 divided by 10"."""
	var slot: int = _growing(GRAIN)
	assert_equal(_store.health_factor_of(slot).value, 1000, "full health gives 1000")
	_store.apply_health_loss(slot, 4000)
	assert_equal(_store.health_factor_of(slot).value, 600, "6000 health gives 600")
	_store.apply_health_loss(slot, 5)
	assert_equal(_store.health_factor_of(slot).value, 599, "5995 health floors to 599")


func test_the_first_crop_on_a_tile_scores_the_first_crop_rotation_factor() -> void:
	"""§5.6: "1000 for first crop/family change". A LEGUME with no previous family is a FIRST
	crop, not a family change, so beans score 1000 here and not 1100."""
	var grain: int = _growing(GRAIN)
	assert_equal(_store.rotation_factor_of(grain).value, 1000, "grain on virgin soil")
	var beans: int = _growing(BEANS, TILE + 1)
	assert_equal(_store.rotation_factor_of(beans).value, 1000, "beans on virgin soil")


func test_repeating_a_family_scores_850_then_700() -> void:
	"""§5.6: "850 for a second consecutive same-family harvest, 700 for third+"."""
	var slot: int = _harvest_grain_cycles(1)
	assert_equal(_store.last_family_of(slot).value, CEREAL, "grain's CEREAL family is recorded")
	assert_equal(_store.family_streak_of(slot).value, 1, "one harvest in the streak")
	_replant_grain(slot)
	assert_equal(_store.rotation_factor_of(slot).value, 850, "a second consecutive grain")
	_store.harvest(slot, 40, _ripe_tick_of(GRAIN), 1000)
	assert_equal(_store.family_streak_of(slot).value, 2, "two harvests in the streak")
	_replant_grain(slot)
	assert_equal(_store.rotation_factor_of(slot).value, 700, "a third consecutive grain")
	_store.harvest(slot, 60, _ripe_tick_of(GRAIN), 1000)
	_replant_grain(slot)
	assert_equal(_store.rotation_factor_of(slot).value, 700, "a fourth is still 700")


func test_a_family_change_resets_the_factor_and_legumes_score_1100() -> void:
	"""§5.6: "1000 for ... family change, with LEGUME after a different family 1100"."""
	var slot: int = _harvest_grain_cycles(1)
	_store.plant(slot, BEANS, 20, LEGAL_SEASON[BEANS], LEGAL_DAY[BEANS])
	_store.begin_growing(slot)
	assert_equal(_store.rotation_factor_of(slot).value, 1100, "beans after cereal score 1100")
	_grow_hours(slot, GROWTH_HOURS[BEANS], 120)
	_store.harvest(slot, 30, _ripe_tick_of(BEANS), 1000)
	_store.plant(slot, GRAIN, 40, LEGAL_SEASON[GRAIN], LEGAL_DAY[GRAIN])
	_store.begin_growing(slot)
	assert_equal(_store.rotation_factor_of(slot).value, 1000, "cereal after legume is a change")


func test_the_yield_formula_is_the_stated_product() -> void:
	"""REQ-SET-074: floor(base*fertility*health*rotation*pollination/10^12). Grain at 7000
	fertility, full health, a first crop and no hive: 10000*850*1000*1000*1000/10^12 = 8500."""
	var slot: int = _ripe(GRAIN)
	assert_equal(_store.formula_yield_milli(slot, 1000).value, 8500, "the stated product")
	assert_equal(_store.neutral_pollination_factor(), 1000, "§5.6's stated neutral factor")


func test_the_pollination_factor_is_a_caller_supplied_multiplier() -> void:
	"""§5.6 sources it from hives, which blocker U6 leaves unowned, so it is an argument -- in the
	manner fishing.gd takes `base_catch_milli`. 1100 and 1150 are the stated hive multipliers."""
	var slot: int = _ripe(BEANS)
	var base: int = _store.formula_yield_milli(slot, 1000).value
	assert_equal(base, 5950, "beans: 7000*850*1000*1000*1000/10^12")
	assert_equal(_store.formula_yield_milli(slot, 1100).value, 6545, "one healthy hive")
	assert_equal(_store.formula_yield_milli(slot, 1150).value, 6842, "two healthy hives")
	assert_equal(_store.formula_yield_milli(slot, 0).value, 0, "no pollination at all yields 0")


func test_the_yield_is_capped_at_125_percent_of_base() -> void:
	"""§5.6: "Cap final yield at 125% base." Beans at maximum fertility, full health, 1100
	rotation and a 1150 pollination factor compute 7000*1000*1000*1100*1150/10^12 = 8855, above
	the 8750 ceiling, so the cap is what is delivered."""
	var slot: int = _beans_after_grain_at_full_fertility()
	assert_equal(_store.fertility_factor_of(slot).value, 1000, "fertility is at its cap")
	assert_equal(_store.rotation_factor_of(slot).value, 1100, "legume after a different family")
	assert_equal(_store.formula_yield_milli(slot, 1150).value, 8750, "125% of beans' 7000")
	assert_equal(_store.formula_yield_milli(slot, 1136).value, 8747, "8747 is just under the cap")
	assert_equal(_store.formula_yield_milli(slot, 1137).value, 8750, "8754 is just over it")


func test_the_formula_does_not_overflow_at_the_table_maxima() -> void:
	"""§5.6: "This formula uses int64 at the product sizes in the table." The loosest bound over
	the table maxima is 10000*1000*1000*1100*1150 = 1.265e16, four orders below int64. A factor
	far past anything §5.6 states is capped rather than wrapped; one large enough to overflow the
	product REFUSES rather than wrapping into a plausible-looking yield."""
	var slot: int = _ripe(GRAIN)
	_store.apply_compost(slot, 1)
	_store.apply_compost(slot, 13)
	assert_equal(_store.fertility_factor_of(slot).value, 1000, "at the fertility cap")
	var maxima: Variant = _store.formula_yield_milli(slot, 1150)
	assert_true(maxima.ok, "the stated maxima must not overflow (error: %s)" % maxima.error)
	assert_equal(maxima.value, 11500, "10000*1000*1000*1000*1150/10^12, under the 12500 cap")
	var huge: Variant = _store.formula_yield_milli(slot, 100000)
	assert_true(huge.ok, "a factor of 10^5 still fits int64 (error: %s)" % huge.error)
	assert_equal(huge.value, 12500, "and the 125% cap bounds it")
	var overflowing: Variant = _store.formula_yield_milli(slot, 9223372036854775807)
	assert_false(overflowing.ok, "a factor that overflows int64 refuses rather than wrapping")
	assert_equal(overflowing.value, 0, "a refusal carries no value")


func test_the_yield_formula_refuses_a_negative_pollination_factor() -> void:
	"""A negative factor would produce a negative yield, which no requirement defines."""
	var slot: int = _ripe(GRAIN)
	var refused: Variant = _store.formula_yield_milli(slot, -1)
	assert_false(refused.ok, "a negative pollination factor must refuse")
	assert_equal(refused.error, String(Farming.REFUSE_INVALID_FACTOR), "refusal code")
	assert_false(_store.formula_yield_milli(_plot(TILE + 1), 1000).ok, "an empty plot has no yield")


func test_harvest_applies_the_fertility_change_once_and_empties_the_plot() -> void:
	"""REQ-SET-074: "apply the listed fertility change once". Grain costs 1200 of the 7000."""
	var slot: int = _ripe(GRAIN)
	var harvested: Farming.OpResult = _store.harvest(slot, 9, _ripe_tick_of(GRAIN), 1000)
	assert_true(harvested.ok, "harvest (error: %s)" % harvested.error)
	assert_equal(harvested.value, 8500, "the delivered yield")
	assert_equal(_store.fertility_of(slot).value, 5800, "7000 - grain's 1200")
	assert_equal(_store.tile_fertility_of(TILE).value, 5800, "the tile carries the same value")
	assert_equal(_store.state_of(slot).value, EMPTY, "the plot returns to EMPTY")
	assert_equal(_store.crop_id_of(slot).value, -1, "no crop stands on it")
	var again: Farming.OpResult = _store.harvest(slot, 9, _ripe_tick_of(GRAIN), 1000)
	assert_false(again.ok, "a second harvest must refuse, not charge fertility twice")
	assert_equal(_store.fertility_of(slot).value, 5800, "and must not move fertility again")


func test_a_bean_harvest_raises_fertility_because_its_stated_cost_is_negative() -> void:
	"""§5.6 gives beans -800. Transcribing it as a positive cost would drain the soil a legume
	is supposed to restore, and nothing else in the table would look wrong."""
	var slot: int = _ripe(BEANS)
	_store.harvest(slot, 9, _ripe_tick_of(BEANS), 1000)
	assert_equal(_store.fertility_of(slot).value, 7800, "7000 + beans' 800 gain")
	assert_equal(_store.tile_fertility_of(TILE).value, 7800, "the tile carries the gain")


func test_harvest_refuses_a_plot_that_is_not_ripe() -> void:
	"""Only a RIPE plot can be taken; a growing or withered one refuses without a value."""
	var growing: int = _growing(GRAIN)
	var refused: Farming.OpResult = _store.harvest(growing, 1, 0, 1000)
	assert_false(refused.ok, "a growing crop cannot be harvested")
	assert_equal(refused.error, Farming.REFUSE_NOT_RIPE, "refusal code")
	assert_equal(refused.value, 0, "a refusal carries no value")
	_store.apply_health_loss(growing, 10000)
	assert_equal(_store.state_of(growing).value, WITHERED, "health 0 withers the plot")
	assert_false(_store.harvest(growing, 1, 0, 1000).ok, "a withered crop cannot be harvested")


func test_emptying_a_plot_clears_the_tiles_ripe_tick() -> void:
	"""An EMPTY plot has no ripening instant. A stale ripe tick left on the tile would let
	ripe_elapsed_hours_of() answer for a crop that has already been taken, and would start
	REQ-SET-075's grace running before the next crop existed."""
	var slot: int = _ripe(GRAIN)
	assert_equal(_store.tile_ripe_tick_of(TILE).value, _ripe_tick_of(GRAIN), "dated while ripe")
	_store.harvest(slot, 9, _ripe_tick_of(GRAIN), 1000)
	assert_equal(_store.tile_ripe_tick_of(TILE).value, -1, "a harvest clears it")
	assert_false(_store.ripe_elapsed_hours_of(slot, 999999).ok, "and the reader refuses again")
	var withered: int = _ripe(GRAIN, TILE + 1)
	_store.apply_ripe_expiry(withered, _ripe_tick_of(GRAIN) + 120 * TICKS_PER_HOUR)
	assert_equal(_store.state_of(withered).value, WITHERED, "withered after five days")
	_store.clear_withered(withered)
	assert_equal(_store.tile_ripe_tick_of(TILE + 1).value, -1, "and clearing clears it too")
	assert_equal(_store.tile_growth_remainder_of(TILE).value, 0, "the remainder is cleared too")


# --- REQ-SET-075 the ripe grace, decay and withering ---------------------------------------------------------------

func test_the_ripe_grace_is_48_hours_on_both_sides() -> void:
	"""§5.6: "Ripe crops remain for 48 hours before losing 10% remaining yield/day"."""
	var slot: int = _ripe(GRAIN)
	var ripe_tick: int = _ripe_tick_of(GRAIN)
	assert_equal(_store.ripe_decay_days_of(slot, ripe_tick).value, 0, "no loss at the instant")
	assert_equal(_store.ripe_decay_days_of(slot, ripe_tick + 47 * TICKS_PER_HOUR).value, 0,
		"no loss at 47 hours")
	assert_equal(_store.ripe_decay_days_of(slot, ripe_tick + 48 * TICKS_PER_HOUR).value, 0,
		"no loss at exactly 48 hours -- the crop REMAINS for 48 hours")
	assert_equal(_store.ripe_decay_days_of(slot, ripe_tick + 71 * TICKS_PER_HOUR).value, 0,
		"still no whole loss day at 71 hours")
	assert_equal(_store.ripe_decay_days_of(slot, ripe_tick + 72 * TICKS_PER_HOUR).value, 1,
		"the first whole loss day lands at 72 hours")
	assert_equal(_store.ripe_decay_days_of(slot, ripe_tick + 96 * TICKS_PER_HOUR).value, 2,
		"the second at 96 hours")


func test_the_decay_takes_ten_percent_of_the_remaining_yield_each_day() -> void:
	"""REMAINING, so it compounds: 10000 -> 9000 -> 8100, not a flat 1000 per day.

	READY_06 §6.4 forbids a THIRD harvestable decay step, so a third is refused rather than
	compounded to 7290 -- at 120 hours the crop is WITHERED and completes no normal harvest. That
	changed this test: the previous 7290 assertion described an interval no live crop can present.
	"""
	assert_equal(_store.spoiled_yield_milli(10000, 0).value, 10000, "no decay")
	assert_equal(_store.spoiled_yield_milli(10000, 1).value, 9000, "one day")
	assert_equal(_store.spoiled_yield_milli(10000, 2).value, 8100, "two days compound")
	assert_equal(_store.spoiled_yield_milli(8500, 1).value, 7650, "the floor is applied per day")
	assert_equal(_store.spoiled_yield_milli(9, 1).value, 8, "small quantities floor down")
	var third: Variant = _store.spoiled_yield_milli(10000, 3)
	assert_false(third.ok, "a third harvestable decay step refuses")
	assert_equal(third.value, 0, "and carries no usable number")
	assert_false(_store.spoiled_yield_milli(10000, 6).ok, "beyond the withering window refuses")
	assert_false(_store.spoiled_yield_milli(-1, 1).ok, "a negative base refuses")


func test_a_late_harvest_delivers_the_decayed_yield() -> void:
	"""The grace and the decay reach the delivered quantity, not just the reader."""
	var slot: int = _ripe(GRAIN)
	var ripe_tick: int = _ripe_tick_of(GRAIN)
	assert_equal(_store.harvest_yield_milli(slot, 1000, ripe_tick + 48 * TICKS_PER_HOUR).value,
		8500, "the full yield through the grace")
	assert_equal(_store.harvest_yield_milli(slot, 1000, ripe_tick + 72 * TICKS_PER_HOUR).value,
		7650, "10% of 8500 lost on the third day")
	var harvested: Farming.OpResult = _store.harvest(slot, 5, ripe_tick + 96 * TICKS_PER_HOUR, 1000)
	assert_true(harvested.ok, "a decayed harvest still completes")
	assert_equal(harvested.value, 6885, "two compounded loss days on 8500")


func test_a_ripe_crop_withers_after_five_days_and_not_before() -> void:
	"""§5.6: "after 5 days unharvested they become compost-equivalent waste and the plot
	WITHERED". Both windows run from the ripening instant; see the module header."""
	var slot: int = _ripe(GRAIN)
	var ripe_tick: int = _ripe_tick_of(GRAIN)
	assert_false(_store.is_ripe_expired(slot, ripe_tick + 119 * TICKS_PER_HOUR),
		"119 hours is not five days")
	var early: Farming.OpResult = _store.apply_ripe_expiry(slot, ripe_tick + 119 * TICKS_PER_HOUR)
	assert_true(early.ok, "the expiry check itself succeeds")
	assert_equal(early.value, 0, "nothing withered yet")
	assert_equal(_store.state_of(slot).value, RIPE, "the plot is still harvestable")
	assert_true(_store.is_ripe_expired(slot, ripe_tick + 120 * TICKS_PER_HOUR), "five days")
	var expired: Farming.OpResult = _store.apply_ripe_expiry(slot, ripe_tick + 120 * TICKS_PER_HOUR)
	assert_equal(expired.value, 1, "the plot withered")
	assert_equal(_store.state_of(slot).value, WITHERED, "and the state column says so")


func test_the_elapsed_reader_refuses_a_plot_that_never_ripened() -> void:
	"""Reporting 0 hours would read as "ripe this instant" and hand a spoiled crop a full yield."""
	var slot: int = _growing(GRAIN)
	var refused: Variant = _store.ripe_elapsed_hours_of(slot, 0)
	assert_false(refused.ok, "a growing plot has no ripe tick")
	assert_equal(refused.error, String(Farming.REFUSE_RIPE_TICK_MISSING), "refusal code")
	var ripe: int = _ripe(GRAIN, TILE + 1)
	assert_false(_store.ripe_elapsed_hours_of(ripe, 0).ok, "a tick before ripening refuses")
	assert_false(_store.ripe_elapsed_hours_of(ripe, -1).ok, "a negative tick refuses")


# --- REQ-SET-084 frost -------------------------------------------------------------------------------------------

func test_frost_removes_the_crops_listed_damage_only_below_zero() -> void:
	"""REQ-SET-084: "remove the listed health/hour while temperature<0°C"."""
	var slot: int = _growing(GRAIN)
	assert_equal(_store.frost_damage_per_hour_for(slot, 0).value, 0, "0°C is not frost")
	assert_equal(_store.frost_damage_per_hour_for(slot, -1).value, 1000, "-0.1°C is frost")
	assert_equal(_store.frost_damage_per_hour_for(slot, -120).value, 1000, "hard freeze")
	_store.apply_frost_hour(slot, 0)
	assert_equal(_store.health_of(slot).value, 10000, "no damage at 0°C")
	_store.apply_frost_hour(slot, -10)
	assert_equal(_store.health_of(slot).value, 9000, "grain loses 1000 per subzero hour")


func test_each_crop_takes_its_own_frost_damage() -> void:
	"""Beans 1500, cabbage 150, flax 800, grain 1000, roots 300: five separate numbers."""
	for crop: int in KEYS.size():
		var store: Farming = Farming.new()
		var slot: int = store.create_plot_at_tile(TILE, LOAM, 1).value
		store.plant(slot, crop, 1, LEGAL_SEASON[crop], LEGAL_DAY[crop])
		store.begin_growing(slot)
		assert_equal(store.frost_damage_per_hour_for(slot, -10).value, FROST[crop],
			"frost damage of %s" % KEYS[crop])


func test_only_tended_cabbage_halves_its_frost_damage() -> void:
	"""REQ-SET-084: "halved for cabbage in a tended plot" -- cabbage alone, tended alone."""
	var cabbage: int = _growing(CABBAGE)
	assert_equal(_store.frost_damage_per_hour_for(cabbage, -10).value, 150, "untended cabbage")
	assert_true(_store.tend(cabbage).ok, "tend")
	assert_equal(_store.frost_damage_per_hour_for(cabbage, -10).value, 75, "tended cabbage halves")
	var grain: int = _growing(GRAIN, TILE + 1)
	_store.tend(grain)
	assert_equal(_store.frost_damage_per_hour_for(grain, -10).value, 1000,
		"tending does not halve any other crop's frost damage")
	_store.clear_tended_today()
	assert_equal(_store.frost_damage_per_hour_for(cabbage, -10).value, 150,
		"the halving lasts only for the tended day")


# --- REQ-SET-087 blight, and §5.6 tending ------------------------------------------------------------------------

func test_blight_removes_400_a_day_and_200_when_tended() -> void:
	"""REQ-SET-087: "remove 400 health/day, reduced to 200 if tended"."""
	var slot: int = _growing(GRAIN)
	assert_equal(_store.blight_damage_per_day_for(slot).value, 400, "untended blight")
	var applied: Farming.OpResult = _store.apply_blight_day(slot)
	assert_true(applied.ok, "apply_blight_day")
	assert_equal(applied.value, 9600, "10000 - 400")
	_store.tend(slot)
	assert_equal(_store.blight_damage_per_day_for(slot).value, 200, "tended blight halves")
	_store.apply_blight_day(slot)
	assert_equal(_store.health_of(slot).value, 9400, "9600 - 200")


func test_tending_restores_moisture_and_water_only_below_the_minimum() -> void:
	"""§5.6: "Tending restores 1000 moisture using water 0.25 U when below minimum"."""
	var slot: int = _growing(GRAIN)
	assert_equal(_store.moisture_of(slot).value, 6000, "§5.1's initial farm moisture")
	assert_false(_store.needs_water(slot), "6000 is inside grain's 3500-7500")
	var dry_run: Farming.OpResult = _store.tend(slot)
	assert_true(dry_run.ok, "tend")
	assert_equal(dry_run.value, 0, "no water is drawn at or above the minimum")
	assert_equal(_store.moisture_of(slot).value, 6000, "and no moisture is added")
	_set_moisture(slot, 3500)
	assert_false(_store.needs_water(slot), "exactly the minimum is not BELOW the minimum")
	var at_minimum: Farming.OpResult = _store.tend(slot)
	assert_equal(at_minimum.value, 0, "no water is drawn at exactly the minimum")
	assert_equal(_store.moisture_of(slot).value, 3500, "and no moisture is added there")
	_set_moisture(slot, 3499)
	assert_true(_store.needs_water(slot), "one below grain's minimum needs water")
	var watered: Farming.OpResult = _store.tend(slot)
	assert_equal(watered.value, 250, "water 0.25 U in milli-units")
	assert_equal(_store.moisture_of(slot).value, 4499, "1000 moisture restored")
	assert_true(_store.tend(slot).value == 0, "and it is above the minimum again afterwards")


func test_tending_marks_the_tile_and_the_daily_reset_clears_it() -> void:
	"""ARCH-STATE-003's "growing-day service state" is TileHistory's, not the plot's."""
	var slot: int = _growing(GRAIN)
	assert_false(_store.is_tile_tended_today(TILE), "a fresh tile is untended")
	_store.tend(slot)
	assert_true(_store.is_tile_tended_today(TILE), "tending marks the tile")
	_store.clear_tended_today()
	assert_false(_store.is_tile_tended_today(TILE), "the midnight reset clears it")


func test_emptying_a_plot_cancels_its_tending_so_the_next_crop_starts_untended() -> void:
	"""The tending service belongs to the crop that received it. Carrying the flag across a
	harvest would halve REQ-SET-087's blight loss for a crop nobody tended, on the same day it
	was sown -- the midnight reset alone does not cover a same-day replant."""
	var slot: int = _growing(GRAIN)
	assert_true(_store.tend(slot).ok, "tend while growing")
	assert_true(_store.is_tile_tended_today(TILE), "tended while growing")
	_grow_hours(slot, GROWTH_HOURS[GRAIN], 120)
	_store.harvest(slot, 9, _ripe_tick_of(GRAIN), 1000)
	assert_false(_store.is_tile_tended_today(TILE), "the harvest ends that crop's service day")
	_store.plant(slot, GRAIN, 9, LEGAL_SEASON[GRAIN], LEGAL_DAY[GRAIN])
	_store.begin_growing(slot)
	assert_equal(_store.blight_damage_per_day_for(slot).value, 400,
		"the replanted crop takes the untended blight loss")


func test_tending_refuses_a_plot_that_is_not_growing() -> void:
	"""§5.6 attaches tending to "while growing"; REQ-SET-085 cancels it on a withered plot."""
	var empty: int = _plot()
	assert_false(_store.tend(empty).ok, "an empty plot cannot be tended")
	var slot: int = _growing(GRAIN, TILE + 1)
	_store.apply_health_loss(slot, 10000)
	var refused: Farming.OpResult = _store.tend(slot)
	assert_false(refused.ok, "REQ-SET-085 cancels tending on a withered plot")
	assert_equal(refused.error, Farming.REFUSE_NOT_GROWING, "refusal code")


# --- REQ-SET-085 withering and clearing ---------------------------------------------------------------------------

func test_health_reaching_zero_withers_the_plot_and_clears_its_tending() -> void:
	"""REQ-SET-085: "mark it withered, cancel tending/harvest"."""
	var slot: int = _growing(GRAIN)
	_store.tend(slot)
	assert_true(_store.is_tile_tended_today(TILE), "tended before the loss")
	var applied: Farming.OpResult = _store.apply_health_loss(slot, 9999)
	assert_equal(applied.value, 1, "one health left is not zero")
	assert_equal(_store.state_of(slot).value, GROWING, "and the crop is still growing")
	_store.apply_health_loss(slot, 1)
	assert_equal(_store.state_of(slot).value, WITHERED, "reaching 0 withers it")
	assert_true(_store.is_withered(slot), "is_withered agrees with the state column")
	assert_false(_store.is_tile_tended_today(TILE), "tending is cancelled")
	assert_equal(_store.health_of(slot).value, 0, "health is clamped at 0, never negative")


func test_health_loss_clamps_at_zero_rather_than_going_negative() -> void:
	"""A negative health would invert the health factor of every later yield."""
	var slot: int = _growing(GRAIN)
	_store.apply_health_loss(slot, 999999)
	assert_equal(_store.health_of(slot).value, 0, "clamped at 0")
	assert_false(_store.apply_health_loss(slot, 1).ok, "a withered plot takes no further loss")


func test_clearing_a_withered_plot_yields_the_stated_compost_and_work() -> void:
	"""REQ-SET-085: "create a 10-WU clearing job yielding compost 0.5 U/tile"."""
	assert_equal(_store.clearing_work_milli_wu(), 10000, "10 WU in milli-WU")
	assert_equal(_store.clearing_compost_milli(), 500, "compost 0.5 U in milli-units")
	var slot: int = _growing(GRAIN)
	assert_false(_store.clear_withered(slot).ok, "a living crop cannot be cleared")
	_store.apply_health_loss(slot, 10000)
	var cleared: Farming.OpResult = _store.clear_withered(slot)
	assert_true(cleared.ok, "clear_withered (error: %s)" % cleared.error)
	assert_equal(cleared.value, 500, "the clearing yields compost 0.5 U")
	assert_equal(_store.state_of(slot).value, EMPTY, "the plot is empty again")
	assert_equal(_store.fertility_of(slot).value, 7000,
		"a crop that was never harvested charges no fertility cost")


# --- REQ-SET-086 the moisture clamp -----------------------------------------------------------------------------

func test_moisture_is_clamped_to_the_stated_range_at_both_ends() -> void:
	"""REQ-SET-086: "clamp moisture 0-10000". The requirement states a clamp, so this one does
	not refuse -- but the clamp must hold at both ends."""
	var slot: int = _plot()
	var wet: Farming.OpResult = _store.apply_moisture_delta(slot, 99999)
	assert_true(wet.ok, "a weather delta is clamped, not refused")
	assert_equal(wet.value, 10000, "clamped at the stated maximum")
	assert_equal(_store.moisture_of(slot).value, 10000, "and stored clamped")
	var dry: Farming.OpResult = _store.apply_moisture_delta(slot, -99999)
	assert_equal(dry.value, 0, "clamped at the stated minimum")
	assert_equal(_store.moisture_of(slot).value, 0, "and stored clamped")
	assert_false(_store.apply_moisture_delta(4095, 100).ok, "an empty row refuses")


# --- REQ-SET-076 compost ------------------------------------------------------------------------------------------

func test_compost_adds_1500_fertility_and_consumes_two_units() -> void:
	"""§5.6: "Compost applies 2 U/tile for 8 WU and restores 1500 fertility"."""
	var slot: int = _plot()
	assert_equal(_store.compost_milli_per_tile(), 2000, "compost 2 U in milli-units")
	assert_equal(_store.compost_work_milli_wu(), 8000, "§5.6's 8 WU")
	var applied: Farming.OpResult = _store.apply_compost(slot, 1)
	assert_true(applied.ok, "apply_compost (error: %s)" % applied.error)
	assert_equal(applied.value, 2000, "the quantity the caller must consume")
	assert_equal(_store.fertility_of(slot).value, 8500, "7000 + 1500")
	assert_equal(_store.tile_fertility_of(TILE).value, 8500, "and the tile carries it")
	assert_equal(_store.compost_milli_of(slot).value, 2000, "the plot records the quantity")


func test_compost_is_capped_at_ten_thousand_fertility() -> void:
	"""§5.6: "restores 1500 fertility, capped 10000". 7000+1500+1500 = 10000 exactly, and a third
	season's application must not push past it."""
	var slot: int = _plot()
	_store.apply_compost(slot, 1)
	_store.apply_compost(slot, 13)
	assert_equal(_store.fertility_of(slot).value, 10000, "two applications reach the cap exactly")
	assert_true(_store.apply_compost(slot, 25).ok, "a third season is still eligible")
	assert_equal(_store.fertility_of(slot).value, 10000, "but fertility stays at the cap")


func test_compost_is_refused_twice_in_the_same_season() -> void:
	"""REQ-SET-076: "prevent repeat application until the next season". Season 1 is days 1-12."""
	var slot: int = _plot()
	assert_true(_store.is_compost_eligible(TILE, 1), "a fresh tile is eligible")
	_store.apply_compost(slot, 1)
	assert_false(_store.is_compost_eligible(TILE, 1), "not twice on the same day")
	assert_false(_store.is_compost_eligible(TILE, 12), "nor on the last day of that season")
	var refused: Farming.OpResult = _store.apply_compost(slot, 12)
	assert_false(refused.ok, "a second application in one season refuses")
	assert_equal(refused.error, Farming.REFUSE_COMPOST_NOT_ELIGIBLE, "refusal code")
	assert_equal(_store.fertility_of(slot).value, 8500, "and adds no fertility")
	assert_true(_store.is_compost_eligible(TILE, 13), "the next season opens on day 13")


func test_the_compost_season_is_absolute_so_next_years_spring_is_a_new_season() -> void:
	"""§4.3's Season repeats every year. Storing a bare 0-3 ordinal would make one spring
	application block every future spring, which is not "until the next season"."""
	var slot: int = _plot()
	_store.apply_compost(slot, 1)
	assert_equal(_store.tile_compost_season_of(TILE).value, 0, "the first spring is index 0")
	assert_equal(_store.absolute_season_of_day(48).value, 3, "day 48 is the first winter")
	assert_equal(_store.absolute_season_of_day(49).value, 4, "day 49 opens the second year")
	assert_true(_store.is_compost_eligible(TILE, 49), "the second year's spring is eligible")


func test_the_absolute_season_index_advances_every_twelve_days() -> void:
	"""REQ-SET-006: "one season as 12 days". Both sides of the first two boundaries."""
	assert_equal(_store.absolute_season_of_day(1).value, 0, "day 1 opens season 0")
	assert_equal(_store.absolute_season_of_day(12).value, 0, "day 12 closes season 0")
	assert_equal(_store.absolute_season_of_day(13).value, 1, "day 13 opens season 1")
	assert_equal(_store.absolute_season_of_day(24).value, 1, "day 24 closes season 1")
	assert_equal(_store.absolute_season_of_day(25).value, 2, "day 25 opens season 2")
	assert_false(_store.absolute_season_of_day(0).ok, "day 0 names no day")
	assert_equal(SimClockScript.DAYS_PER_SEASON, 12, "read from sim_clock.gd, not mirrored")


# --- REQ-SET-078 fallow recovery --------------------------------------------------------------------------------

func test_a_fallow_tile_gains_fifty_fertility_a_day() -> void:
	"""§5.6: "Empty/fallow plot gains 50 fertility/day". No worker is required (REQ-SET-078)."""
	var slot: int = _ripe(GRAIN)
	_store.harvest(slot, 9, _ripe_tick_of(GRAIN), 1000)
	assert_equal(_store.fertility_of(slot).value, 5800, "after grain's cost")
	assert_equal(_store.fallow_gain_for(TILE, 10).value, 50, "the declared daily rate")
	var applied: Farming.OpResult = _store.apply_fallow_day(TILE, 10)
	assert_true(applied.ok, "apply_fallow_day (error: %s)" % applied.error)
	assert_equal(applied.value, 5850, "5800 + 50")
	assert_equal(_store.fertility_of(slot).value, 5850, "the plot mirror moves with the tile")
	assert_equal(_store.fallow_fertility_per_day(), 50, "the declared rate")


func test_the_legume_fallow_bonus_lasts_exactly_twelve_days() -> void:
	"""§5.6: "last LEGUME crop adds another 50/day for the next 12 days"."""
	var slot: int = _ripe(BEANS)
	_store.harvest(slot, 10, _ripe_tick_of(BEANS), 1000)
	assert_equal(_store.tile_last_legume_day_of(TILE).value, 10, "the harvest day is dated")
	assert_equal(_store.fallow_gain_for(TILE, 10).value, 50, "the harvest day itself is not after")
	assert_equal(_store.fallow_gain_for(TILE, 11).value, 100, "the first of the next 12 days")
	assert_equal(_store.fallow_gain_for(TILE, 22).value, 100, "the twelfth day still doubles")
	assert_equal(_store.fallow_gain_for(TILE, 23).value, 50, "the thirteenth day does not")


func test_a_non_legume_harvest_leaves_no_fallow_bonus() -> void:
	"""Only a LEGUME dates the bonus; a cereal harvest must not."""
	var slot: int = _ripe(GRAIN)
	_store.harvest(slot, 10, _ripe_tick_of(GRAIN), 1000)
	assert_equal(_store.tile_last_legume_day_of(TILE).value, 0, "no legume day recorded")
	assert_equal(_store.fallow_gain_for(TILE, 11).value, 50, "the base rate only")


func test_fallow_recovery_is_capped_and_refuses_a_worked_plot() -> void:
	"""A growing crop is not fallow, and the fertility cap holds against a long fallow."""
	var slot: int = _growing(GRAIN)
	var refused: Farming.OpResult = _store.apply_fallow_day(TILE, 5)
	assert_false(refused.ok, "a growing crop is not fallow")
	assert_equal(refused.error, Farming.REFUSE_NOT_EMPTY, "refusal code")
	assert_equal(_store.fertility_of(slot).value, 7000, "and nothing is added")
	for day: int in range(5, 200):
		_store.apply_fallow_day(TILE + 1, day)
	assert_equal(_store.tile_fertility_of(TILE + 1).value, 10000, "capped at 10000")


func test_fallow_recovery_works_on_a_tile_with_no_plot_at_all() -> void:
	"""§5.6's "empty/fallow plot" includes ground with no designation on it, and ARCH-STATE-003
	keeps that soil history whether a FarmPlot row exists or not."""
	assert_false(_store.has_plot_at_tile(500), "no plot on this tile")
	var applied: Farming.OpResult = _store.apply_fallow_day(500, 3)
	assert_true(applied.ok, "an undesignated tile still recovers")
	assert_equal(applied.value, 7050, "7000 + 50")
	assert_false(_store.apply_fallow_day(16384, 3).ok, "an off-grid tile refuses")
	assert_false(_store.apply_fallow_day(500, 0).ok, "day 0 refuses")


# --- ARCH-STATE-003: the tile outlives the plot -----------------------------------------------------------------

func test_recreating_a_field_does_not_restore_fertility() -> void:
	"""ARCH-STATE-003: "Recreating a field can allocate a FarmPlot row, but it SHALL copy the
	existing tile state; it SHALL not restore fertility". BAL-SAFE-014 states the same rule."""
	var slot: int = _ripe(GRAIN)
	_store.harvest(slot, 9, _ripe_tick_of(GRAIN), 1000)
	assert_equal(_store.fertility_of(slot).value, 5800, "worked down by grain's cost")
	assert_true(_store.destroy(_store.ref_of(slot)).ok, "destroy")
	assert_false(_store.has_plot_at_tile(TILE), "the designation is gone")
	assert_equal(_store.tile_fertility_of(TILE).value, 5800, "the tile remembers")
	var rebuilt: int = _plot()
	assert_equal(_store.fertility_of(rebuilt).value, 5800,
		"a redrawn designation copies the worked soil, it does not reset to 7000")


func test_recreating_a_field_does_not_reset_compost_eligibility() -> void:
	"""ARCH-STATE-003: "it SHALL not ... reset compost eligibility". Destroying and redrawing a
	field must not buy a second application inside one season."""
	var slot: int = _plot()
	_store.apply_compost(slot, 1)
	_store.destroy(_store.ref_of(slot))
	assert_false(_store.is_compost_eligible(TILE, 5), "the tile is still spent for this season")
	var rebuilt: int = _plot()
	var refused: Farming.OpResult = _store.apply_compost(rebuilt, 5)
	assert_false(refused.ok, "a redrawn field cannot compost again this season")
	assert_equal(refused.error, Farming.REFUSE_COMPOST_NOT_ELIGIBLE, "refusal code")
	assert_equal(_store.fertility_of(rebuilt).value, 8500, "and gains nothing")
	assert_true(_store.apply_compost(rebuilt, 13).ok, "the next season is eligible as normal")


func test_recreating_a_field_keeps_the_last_family_and_the_legume_clock() -> void:
	"""ARCH-STATE-003 names "last crop family, the last legume-harvest day" explicitly."""
	var slot: int = _ripe(BEANS)
	_store.harvest(slot, 10, _ripe_tick_of(BEANS), 1000)
	_store.destroy(_store.ref_of(slot))
	assert_equal(_store.tile_last_family_of(TILE).value, LEGUME, "the LEGUME family survives")
	assert_equal(_store.tile_last_legume_day_of(TILE).value, 10, "the legume day survives")
	assert_equal(_store.fallow_gain_for(TILE, 11).value, 100, "and still pays its bonus")
	var rebuilt: int = _plot()
	assert_equal(_store.last_family_of(rebuilt).value, LEGUME,
		"the new row copies the family in")


func test_a_redrawn_designation_cannot_fabricate_a_rotation_bonus() -> void:
	"""READY_06 §7: the tile owns (last_family, family_streak) and the plot row mirrors it, so a
	redraw restores BOTH halves. One banked grain harvest still reads as a second consecutive
	same-family harvest afterwards. Before the ruling the count was lost and this test asserted a
	zero streak on the rebuilt row; it now asserts the restored 1."""
	var slot: int = _harvest_grain_cycles(1)
	_store.destroy(_store.ref_of(slot))
	var rebuilt: int = _plot()
	assert_equal(_store.family_streak_of(rebuilt).value, 1, "the count survives the redraw")
	assert_equal(_store.tile_family_streak_of(TILE).value, 1, "because the tile owns it")
	_store.plant(rebuilt, GRAIN, 30, LEGAL_SEASON[GRAIN], LEGAL_DAY[GRAIN])
	_store.begin_growing(rebuilt)
	assert_equal(_store.rotation_factor_of(rebuilt).value, 850,
		"a redraw must not reset the rotation penalty to the first-crop 1000")


func test_destroying_a_plot_frees_its_tile_and_its_directory_row() -> void:
	"""The tile link is cleared both ways and the directory slot is handed back."""
	var slot: int = _plot()
	var ref: Vector2i = _store.ref_of(slot)
	assert_equal(_store.tile_active_plot_row_of(TILE).value, slot, "the tile points at the plot")
	assert_equal(_store.tile_of(slot).value, TILE, "and the plot points back")
	assert_true(_store.destroy(ref).ok, "destroy")
	assert_equal(_store.count(), 0, "no live plots")
	assert_false(_store.is_present(slot), "the row is empty")
	assert_equal(_store.tile_active_plot_row_of(TILE).value, -1, "the tile is free")
	var stale: Farming.OpResult = _store.destroy(ref)
	assert_false(stale.ok, "a stale reference must refuse")
	assert_equal(stale.error, Farming.REFUSE_NOT_PRESENT, "refusal code")


func test_the_orchard_row_column_is_allocated_and_never_written() -> void:
	"""systems_architecture.md §2 budgets `orchard_row` in TileHistory; REQ-SET-079-083 orchards
	are increment 8, so the column exists at its stated length and stays empty here."""
	assert_equal(_store.tile_orchard_row_of(0).value, -1, "the first tile has no orchard")
	assert_equal(_store.tile_orchard_row_of(16383).value, -1, "nor the last of the 16384")
	var slot: int = _ripe(GRAIN)
	_store.harvest(slot, 9, _ripe_tick_of(GRAIN), 1000)
	assert_equal(_store.tile_orchard_row_of(TILE).value, -1, "and farming never writes it")
	assert_false(_store.tile_orchard_row_of(16384).ok, "tile 16384 is off the ledger")


# --- the store: tiles, capacity, soil and lifecycle ---------------------------------------------------------------

func test_the_tile_ledger_covers_exactly_the_stated_sixteen_thousand_rows() -> void:
	"""systems_architecture.md §2 gives TileHistory 16384 rows, which is §5.1's 128x128 grid."""
	assert_true(_store.is_tile_index(0), "the first tile")
	assert_true(_store.is_tile_index(16383), "the last tile")
	assert_false(_store.is_tile_index(16384), "one past the end")
	assert_false(_store.is_tile_index(-1), "before the beginning")
	assert_true(_store.create_plot_at_tile(16383, LOAM, 1).ok, "a plot on the last tile")
	var off_grid: Farming.OpResult = _store.create_plot_at_tile(16384, LOAM, 1)
	assert_false(off_grid.ok, "a plot off the grid refuses")
	assert_equal(off_grid.error, Farming.REFUSE_INVALID_TILE, "refusal code")


func test_a_tile_holds_at_most_one_plot() -> void:
	"""One FarmPlot per 2 m tile (§4.2), enforced by refusing the second."""
	_plot()
	var second: Farming.OpResult = _store.create_plot_at_tile(TILE, LOAM, 1)
	assert_false(second.ok, "a second plot on one tile refuses")
	assert_equal(second.error, Farming.REFUSE_TILE_OCCUPIED, "refusal code")
	assert_equal(second.ref, Vector2i(-1, 0), "a refusal carries the null reference")
	assert_equal(_store.count(), 1, "and no second row is allocated")


func test_the_store_fills_to_its_stated_four_thousand_and_ninety_six_rows() -> void:
	"""§4.2: "up to 4096 active farm tiles", which is also the directory's FARM_PLOT capacity."""
	assert_equal(EntityDirectoryScript.KIND_CAPACITY[EntityDirectoryScript.KIND_FARM_PLOT], 4096,
		"the directory reserves 4096 farm-plot rows")
	for tile: int in 4096:
		assert_true(_store.create_plot_at_tile(tile, LOAM, 1).ok if tile == 0 else true, "first")
		if tile > 0:
			_store.create_plot_at_tile(tile, LOAM, 1)
	assert_equal(_store.count(), 4096, "every row is live")
	var overflow: Farming.OpResult = _store.create_plot_at_tile(4096, LOAM, 1)
	assert_false(overflow.ok, "the 4097th plot refuses")
	assert_equal(overflow.error, &"CAPACITY_FARM_PLOT", "ARCH-ID-004's capacity refusal code")


func test_a_new_plot_starts_at_the_stated_initial_values() -> void:
	"""§5.6's "any crop-compatible soil starts fertility 7000" and §5.1's moisture 6000/health
	10000, with "empty plots have no previous crop family"."""
	var slot: int = _plot()
	assert_equal(_store.fertility_of(slot).value, 7000, "fertility 7000")
	assert_equal(_store.moisture_of(slot).value, 6000, "moisture 6000")
	assert_equal(_store.health_of(slot).value, 10000, "health 10000")
	assert_equal(_store.state_of(slot).value, EMPTY, "state EMPTY")
	assert_equal(_store.crop_id_of(slot).value, -1, "no crop")
	assert_equal(_store.last_family_of(slot).value, -1, "no previous crop family")
	assert_equal(_store.family_streak_of(slot).value, 0, "no streak")
	assert_equal(_store.compost_milli_of(slot).value, 0, "no compost applied")
	assert_equal(_store.sow_day_of(slot).value, 0, "no sow day")


func test_incompatible_soil_rejects_planting() -> void:
	"""§5.6: "incompatible soil rejects planting". Grain states loam and clay, not sand."""
	var sand: int = _plot(TILE, SAND)
	var refused: Farming.OpResult = _store.plant(sand, GRAIN, 1, 0, 1)
	assert_false(refused.ok, "grain refuses sand")
	assert_equal(refused.error, Farming.REFUSE_SOIL_INCOMPATIBLE, "refusal code")
	assert_equal(_store.state_of(sand).value, EMPTY, "and nothing is sown")
	assert_true(_store.plant(sand, ROOTS, 1, 0, 1).ok, "roots accept sand")
	var clay: int = _plot(TILE + 1, CLAY)
	assert_false(_store.plant(clay, FLAX, 1, 0, 1).ok, "flax refuses clay")
	assert_true(_store.plant(clay, GRAIN, 1, 0, 1).ok, "grain accepts clay")


func test_planting_refuses_outside_the_stated_window_and_returns_the_seed_quantity() -> void:
	"""REQ-SET-070's soil and window gates. The seed is RETURNED, never consumed here."""
	var slot: int = _plot()
	var late: Farming.OpResult = _store.plant(slot, GRAIN, 5, 0, 5)
	assert_false(late.ok, "spring day 5 is outside grain's 1-4 window")
	assert_equal(late.error, Farming.REFUSE_OUTSIDE_PLANT_WINDOW, "refusal code")
	assert_equal(late.value, 0, "a refusal carries no seed quantity")
	var planted: Farming.OpResult = _store.plant(slot, GRAIN, 4, 0, 4)
	assert_true(planted.ok, "spring day 4 is the last legal day")
	assert_equal(planted.value, 250, "seed 0.25 U in milli-units")
	assert_equal(_store.state_of(slot).value, SOWN, "the plot enters SOWN, not GROWING")
	assert_equal(_store.sow_day_of(slot).value, 4, "the sow day is recorded")
	assert_false(_store.plant(slot, ROOTS, 4, 0, 4).ok, "an occupied plot refuses a second crop")


func test_planting_refuses_invalid_arguments_without_writing_anything() -> void:
	"""Every refusal leaves the plot exactly as it was."""
	var slot: int = _plot()
	assert_false(_store.plant(slot, 5, 1, 0, 1).ok, "an unknown crop refuses")
	assert_false(_store.plant(slot, GRAIN, 1, 4, 1).ok, "an unknown season refuses")
	assert_false(_store.plant(slot, GRAIN, 1, 0, 13).ok, "season day 13 refuses")
	assert_false(_store.plant(slot, GRAIN, 0, 0, 1).ok, "day 0 refuses")
	assert_false(_store.plant(4095, GRAIN, 1, 0, 1).ok, "an empty row refuses")
	assert_equal(_store.state_of(slot).value, EMPTY, "the plot is untouched")
	assert_equal(_store.crop_id_of(slot).value, -1, "and holds no crop")


func test_begin_growing_moves_a_sown_plot_and_only_a_sown_plot() -> void:
	"""§5.6's 4 WU of sowing work completing is the SOWN -> GROWING transition."""
	var slot: int = _sown(GRAIN)
	assert_true(_store.begin_growing(slot).ok, "a sown plot starts growing")
	assert_equal(_store.state_of(slot).value, GROWING, "state GROWING")
	var refused: Farming.OpResult = _store.begin_growing(slot)
	assert_false(refused.ok, "a growing plot cannot start twice")
	assert_equal(refused.error, Farming.REFUSE_NOT_SOWN, "refusal code")
	assert_false(_store.begin_growing(_plot(TILE + 1)).ok, "an empty plot cannot start growing")


func test_the_live_list_stays_ascending_across_creates_and_destroys() -> void:
	"""A daily sweep iterates the live rows, so their order must not depend on churn."""
	var first: int = _plot(10)
	var second: int = _plot(11)
	var third: int = _plot(12)
	_store.destroy(_store.ref_of(second))
	var fourth: int = _plot(13)
	assert_equal(_store.count(), 3, "three live plots")
	var previous: int = -1
	for index: int in _store.count():
		var slot: int = _store.live_slot_at(index).value
		assert_true(slot > previous, "live slots ascend at index %d" % index)
		previous = slot
	assert_false(_store.live_slot_at(3).ok, "past the end refuses")
	assert_true(first >= 0 and third >= 0 and fourth >= 0, "every create returned a row")


func test_clear_releases_every_row_and_resets_the_tile_ledger() -> void:
	"""A cleared world has no worked soil left to remember, and leaks no directory allocation."""
	var slot: int = _plot()
	_store.apply_compost(slot, 1)
	_store.clear()
	assert_equal(_store.count(), 0, "no live plots")
	assert_equal(_store.tile_fertility_of(TILE).value, 7000, "fertility back to the stated start")
	assert_true(_store.is_compost_eligible(TILE, 1), "compost eligibility is reset by a clear")
	assert_equal(_store.tile_active_plot_row_of(TILE).value, -1, "no plot on the tile")
	assert_equal(_store.directory().live_count(EntityDirectoryScript.KIND_FARM_PLOT), 0,
		"and no directory row is stranded")
	assert_true(_store.create_plot_at_tile(TILE, LOAM, 1).ok, "the store is usable again")


func test_the_store_shares_a_directory_when_one_is_passed_in() -> void:
	"""One allocator and one generation counter across every store, as residents.gd does it."""
	var directory: EntityDirectoryScript = EntityDirectoryScript.new()
	var store: Farming = Farming.new(directory)
	assert_equal(store.directory(), directory, "the passed directory is adopted")
	var created: Farming.OpResult = store.create_plot_at_tile(TILE, LOAM, 1)
	assert_true(created.ok, "create through the shared directory")
	assert_true(directory.is_valid_of_kind(created.ref, EntityDirectoryScript.KIND_FARM_PLOT),
		"the reference validates against the shared directory")


func test_every_plot_reader_refuses_an_absent_row_without_a_value() -> void:
	"""No sentinel anywhere: an absent row refuses with an empty value on every reader."""
	for reader: String in ["tile_of", "crop_id_of", "state_of", "soil_of", "fertility_of",
			"moisture_of", "health_of", "last_family_of", "family_streak_of", "sow_day_of",
			"growth_milli_hours_of", "compost_milli_of", "fertility_factor_of",
			"health_factor_of", "rotation_factor_of", "growth_target_milli_hours_of"]:
		var result: Variant = _store.call(reader, 0)
		assert_false(result.ok, "%s on an absent row must refuse" % reader)
		assert_equal(result.value, 0, "%s carries no value" % reader)
	assert_equal(_store.ref_of(0), Vector2i(-1, 0), "ref_of yields the §4.1 null reference")


func test_readers_that_need_a_crop_refuse_an_empty_plot() -> void:
	"""An EMPTY plot has no crop, so a rotation factor or a duration would name nothing."""
	var slot: int = _plot()
	var rotation: Variant = _store.rotation_factor_of(slot)
	assert_false(rotation.ok, "rotation_factor_of on an empty plot must refuse")
	assert_equal(rotation.error, String(Farming.REFUSE_NO_CROP), "refusal code")
	assert_false(_store.growth_target_milli_hours_of(slot).ok, "and so must the duration")
	var sown: int = _sown(GRAIN, TILE + 1)
	assert_equal(_store.growth_target_milli_hours_of(sown).value, 192000, "grain's 192 hours")


# --- helpers that drive full crop cycles ------------------------------------------------------------------------

func _harvest_grain_cycles(cycles: int, tile: int = TILE) -> int:
	"""Grow and harvest grain `cycles` times on one plot, returning that plot's row."""
	var slot: int = _ripe(GRAIN, tile)
	for cycle: int in cycles:
		if cycle > 0:
			_replant_grain(slot)
		var harvested: Farming.OpResult = _store.harvest(slot, 9, _ripe_tick_of(GRAIN), 1000)
		assert_true(harvested.ok, "harvest cycle %d (error: %s)" % [cycle, harvested.error])
	return slot


func _replant_grain(slot: int) -> void:
	"""Replant and re-ripen grain on an already-harvested plot."""
	assert_true(_store.plant(slot, GRAIN, 20, LEGAL_SEASON[GRAIN], LEGAL_DAY[GRAIN]).ok, "replant")
	_store.begin_growing(slot)
	_grow_hours(slot, GROWTH_HOURS[GRAIN], 120)


func _beans_after_grain_at_full_fertility() -> int:
	"""A ripe bean plot at the 10000 fertility cap whose tile last carried a cereal."""
	var slot: int = _harvest_grain_cycles(1)
	_store.apply_compost(slot, 1)
	_store.apply_compost(slot, 13)
	_store.apply_compost(slot, 25)
	_store.apply_compost(slot, 37)
	assert_true(_store.plant(slot, BEANS, 40, LEGAL_SEASON[BEANS], LEGAL_DAY[BEANS]).ok, "plant")
	_store.begin_growing(slot)
	_grow_hours(slot, GROWTH_HOURS[BEANS], 120)
	return slot


# --- READY_06 §7: the persisted family streak ------------------------------------------------------

func test_the_streak_survives_an_erase_and_recreate_so_a_third_harvest_still_scores_700() -> void:
	"""THE RULING'S REDRAW FIXTURE, verbatim: "two same-family harvests -> erase/recreate -> next
	same-family harvest still 700". Before READY_06 §7 the tile kept the family but not the count,
	so the rebuilt plot read as a second consecutive harvest and paid 850 instead."""
	var slot: int = _harvest_grain_cycles(2)
	assert_equal(_store.family_streak_of(slot).value, 2, "two banked grain harvests")
	assert_equal(_store.tile_family_streak_of(TILE).value, 2, "and the tile owns the count")
	assert_true(_store.destroy(_store.ref_of(slot)).ok, "erase the designation")
	assert_equal(_store.tile_family_streak_of(TILE).value, 2, "erasing cannot erase the count")
	var rebuilt: int = _plot()
	assert_equal(_store.last_family_of(rebuilt).value, CEREAL, "the family is restored")
	assert_equal(_store.family_streak_of(rebuilt).value, 2, "and so is the count")
	_store.plant(rebuilt, GRAIN, 30, LEGAL_SEASON[GRAIN], LEGAL_DAY[GRAIN])
	_store.begin_growing(rebuilt)
	assert_equal(_store.rotation_factor_of(rebuilt).value, 700,
		"a third same-family crop still scores 700 across the redraw, not 850")


func test_a_family_change_after_a_redraw_still_scores_1000_and_1100_for_a_legume() -> void:
	"""The ruling's other half: "a family change still gives 1000, or 1100 for LEGUME"."""
	var slot: int = _harvest_grain_cycles(2)
	_store.destroy(_store.ref_of(slot))
	var rebuilt: int = _plot()
	_store.plant(rebuilt, BEANS, 30, LEGAL_SEASON[BEANS], LEGAL_DAY[BEANS])
	_store.begin_growing(rebuilt)
	assert_equal(_store.rotation_factor_of(rebuilt).value, 1100,
		"a LEGUME after a different family scores 1100 across a redraw")
	var other: int = _harvest_grain_cycles(2, TILE + 1)
	_store.destroy(_store.ref_of(other))
	var rebuilt_roots: int = _plot(TILE + 1)
	_store.plant(rebuilt_roots, ROOTS, 30, LEGAL_SEASON[ROOTS], LEGAL_DAY[ROOTS])
	_store.begin_growing(rebuilt_roots)
	assert_equal(_store.rotation_factor_of(rebuilt_roots).value, 1000,
		"a non-legume family change scores the first-crop 1000")


func test_a_harvest_writes_the_family_and_the_count_onto_the_tile_together() -> void:
	"""READY_06 §7: "Update both atomically on completed harvest". Neither half can be observed
	without the other, on the plot row or on the tile."""
	var slot: int = _ripe(GRAIN)
	assert_equal(_store.tile_last_family_of(TILE).value, -1, "no family before the harvest")
	assert_equal(_store.tile_family_streak_of(TILE).value, 0, "and no count")
	_store.harvest(slot, 9, _ripe_tick_of(GRAIN), 1000)
	assert_equal(_store.tile_last_family_of(TILE).value, CEREAL, "the family lands")
	assert_equal(_store.tile_family_streak_of(TILE).value, 1, "and the count with it")
	assert_equal(_store.last_family_of(slot).value, CEREAL, "the plot mirrors the family")
	assert_equal(_store.family_streak_of(slot).value, 1, "and mirrors the count")


func test_a_different_family_resets_the_count_to_one_rather_than_continuing_it() -> void:
	"""READY_06 §6.2: "Same family increments; a different family resets to 1"."""
	var slot: int = _harvest_grain_cycles(3)
	assert_equal(_store.family_streak_of(slot).value, 3, "three banked cereal harvests")
	_store.plant(slot, BEANS, 40, LEGAL_SEASON[BEANS], LEGAL_DAY[BEANS])
	_store.begin_growing(slot)
	_grow_hours(slot, GROWTH_HOURS[BEANS], 120)
	_store.harvest(slot, 50, _ripe_tick_of(BEANS), 1000)
	assert_equal(_store.last_family_of(slot).value, LEGUME, "the family changed")
	assert_equal(_store.family_streak_of(slot).value, 1, "so the count restarts at 1, not 4")
	assert_equal(_store.tile_family_streak_of(TILE).value, 1, "on the tile as well")


func test_withering_and_fallow_days_neither_reset_nor_advance_the_count() -> void:
	"""READY_06 §6.2: "withering, fallow time, unfinished sowing and redraw neither reset nor
	advance it". Only a SUCCESSFUL COMPLETED harvest moves the pair."""
	var slot: int = _harvest_grain_cycles(2)
	_replant_grain(slot)
	_store.apply_ripe_expiry(slot, _ripe_tick_of(GRAIN) + 120 * TICKS_PER_HOUR)
	assert_equal(_store.state_of(slot).value, WITHERED, "the replanted crop withered")
	assert_equal(_store.family_streak_of(slot).value, 2, "withering advanced nothing")
	_store.clear_withered(slot)
	assert_equal(_store.family_streak_of(slot).value, 2, "nor did clearing it")
	_store.apply_fallow_day(TILE, 61)
	assert_equal(_store.tile_family_streak_of(TILE).value, 2, "nor did a fallow day")
	assert_equal(_store.tile_last_family_of(TILE).value, CEREAL, "and the family is untouched")


func test_an_unfinished_sowing_never_advances_the_count() -> void:
	"""READY_06 §6.2 again: the streak counts harvests, never sowings."""
	var slot: int = _harvest_grain_cycles(1)
	assert_true(_store.plant(slot, GRAIN, 20, LEGAL_SEASON[GRAIN], LEGAL_DAY[GRAIN]).ok, "sow")
	assert_equal(_store.family_streak_of(slot).value, 1, "sowing banks nothing")
	assert_true(_store.begin_growing(slot).ok, "finish the sowing work")
	assert_equal(_store.family_streak_of(slot).value, 1, "nor does completing the sowing")
	assert_equal(_store.tile_family_streak_of(TILE).value, 1, "nor on the tile")


func test_the_streak_saturates_at_int32_max_instead_of_overflowing() -> void:
	"""READY_06 §6.2: "Saturate at INT32_MAX -- if already at the maximum, retain it; otherwise
	increment. Never evaluate an overflowing addition." Loaded through the tile-history gate,
	because nothing reaches 2147483647 harvests by playing."""
	var restored: Farming.OpResult = _store.restore_tile_family_history(TILE, CEREAL, 2147483647)
	assert_true(restored.ok, "restore a saturated tile (error: %s)" % restored.error)
	var slot: int = _plot()
	assert_equal(_store.family_streak_of(slot).value, 2147483647, "the plot mirrors the maximum")
	assert_false(_store.rotation_factor_of(slot).ok, "an empty plot carries no crop to score")
	_store.plant(slot, GRAIN, 20, LEGAL_SEASON[GRAIN], LEGAL_DAY[GRAIN])
	_store.begin_growing(slot)
	_grow_hours(slot, GROWTH_HOURS[GRAIN], 120)
	assert_true(_store.harvest(slot, 30, _ripe_tick_of(GRAIN), 1000).ok, "harvest at the maximum")
	assert_equal(_store.family_streak_of(slot).value, 2147483647, "the count is retained")
	assert_equal(_store.tile_family_streak_of(TILE).value, 2147483647, "on the tile too")


func test_one_below_the_maximum_still_increments_to_the_maximum() -> void:
	"""The other side of the saturation boundary: 2147483646 must still advance once."""
	assert_true(_store.restore_tile_family_history(TILE, CEREAL, 2147483646).ok, "restore")
	var slot: int = _plot()
	_store.plant(slot, GRAIN, 20, LEGAL_SEASON[GRAIN], LEGAL_DAY[GRAIN])
	_store.begin_growing(slot)
	_grow_hours(slot, GROWTH_HOURS[GRAIN], 120)
	assert_true(_store.harvest(slot, 30, _ripe_tick_of(GRAIN), 1000).ok, "harvest")
	assert_equal(_store.family_streak_of(slot).value, 2147483647, "2147483646 + 1")


func test_a_populated_family_with_a_zero_count_is_refused_not_reinterpreted() -> void:
	"""READY_06 §7: "A populated family paired with zero streak must not be silently treated as
	known complete history; any legacy snapshot with missing counts needs explicit migration or
	rejection." This is the rejection, and it writes neither half."""
	assert_false(Farming.is_history_pair_consistent(CEREAL, 0), "family with no count")
	assert_true(Farming.is_history_pair_consistent(-1, 0), "no family and no count")
	assert_false(Farming.is_history_pair_consistent(-1, 1), "a count with no family")
	assert_true(Farming.is_history_pair_consistent(LEGUME, 1), "a family with a count")
	var refused: Farming.OpResult = _store.restore_tile_family_history(TILE, CEREAL, 0)
	assert_false(refused.ok, "a legacy pair with a missing count refuses")
	assert_equal(refused.error, Farming.REFUSE_HISTORY_INCONSISTENT, "refusal code")
	assert_equal(_store.tile_last_family_of(TILE).value, -1, "the family was not written")
	assert_equal(_store.tile_family_streak_of(TILE).value, 0, "nor the count")


func test_the_tile_history_gate_refuses_invalid_arguments_and_an_occupied_tile() -> void:
	"""A load writes tile history before designations, and it never writes a nonsense family."""
	assert_false(_store.restore_tile_family_history(16384, CEREAL, 1).ok, "an off-grid tile")
	assert_false(_store.restore_tile_family_history(TILE, FAMILY_COUNT, 1).ok, "no such family")
	assert_false(_store.restore_tile_family_history(TILE, -2, 0).ok, "nor a family below -1")
	assert_false(_store.restore_tile_family_history(TILE, CEREAL, -1).ok, "a negative count")
	var occupied: int = _plot()
	assert_true(_store.is_present(occupied), "the tile now carries a plot")
	var refused: Farming.OpResult = _store.restore_tile_family_history(TILE, CEREAL, 1)
	assert_false(refused.ok, "a tile with a live plot refuses")
	assert_equal(refused.error, Farming.REFUSE_TILE_OCCUPIED, "refusal code")


func test_an_invalid_or_stale_plot_reference_cannot_alter_tile_history() -> void:
	"""READY_06 §7: "Invalid/stale plot references must not alter tile history"."""
	var slot: int = _harvest_grain_cycles(1)
	var ref: Vector2i = _store.ref_of(slot)
	assert_true(_store.destroy(ref).ok, "destroy")
	assert_false(_store.destroy(ref).ok, "the stale reference refuses")
	assert_false(_store.harvest(slot, 9, 0, 1000).ok, "harvesting the emptied row refuses")
	assert_false(_store.harvest(4095, 9, 0, 1000).ok, "an absent row refuses")
	assert_equal(_store.tile_last_family_of(TILE).value, CEREAL, "the family is unchanged")
	assert_equal(_store.tile_family_streak_of(TILE).value, 1, "and so is the count")


# --- READY_06 §6.4: the ripe clocks, at the exact stated boundaries -----------------------------------

func test_the_planner_decay_fixture_is_100000_then_90000_then_81000_then_unharvestable() -> void:
	"""THE RULING'S DECAY FIXTURE, verbatim: "A 100000-milli-U fixture is 100000 just before 72h,
	90000 at 72h, 81000 at 96h, then not harvestable at 120h." Asserted on the arithmetic and on
	the delivered quantity, so neither the schedule nor the withering deadline can drift alone."""
	assert_equal(_store.spoiled_yield_milli(100000, 0).value, 100000, "100000 through the grace")
	assert_equal(_store.spoiled_yield_milli(100000, 1).value, 90000, "90000 after one interval")
	assert_equal(_store.spoiled_yield_milli(100000, 2).value, 81000, "81000 after two")
	assert_false(_store.spoiled_yield_milli(100000, 3).ok, "no third harvestable interval")
	var slot: int = _ripe(GRAIN)
	var ripe_tick: int = _ripe_tick_of(GRAIN)
	assert_equal(_store.ripe_decay_days_of(slot, ripe_tick + 71 * TICKS_PER_HOUR).value, 0,
		"no completed interval one hour before 72")
	assert_equal(_store.ripe_decay_days_of(slot, ripe_tick + 72 * TICKS_PER_HOUR).value, 1,
		"one completed interval at 72 hours")
	assert_equal(_store.ripe_decay_days_of(slot, ripe_tick + 96 * TICKS_PER_HOUR).value, 2,
		"two at 96 hours")


func test_a_harvest_at_120_hours_refuses_even_before_the_expiry_sweep_runs() -> void:
	"""READY_06 §6.4: "at 120 the crop is WITHERED and cannot complete a normal harvest". The
	state column only moves when a caller runs apply_ripe_expiry(), so the deadline is enforced by
	harvest() itself -- otherwise a harvest landing first would collect a third decay step."""
	var slot: int = _ripe(GRAIN)
	var ripe_tick: int = _ripe_tick_of(GRAIN)
	assert_equal(_store.state_of(slot).value, RIPE, "no expiry sweep has run")
	assert_true(_store.harvest_yield_milli(slot, 1000, ripe_tick + 119 * TICKS_PER_HOUR).ok,
		"119 hours still delivers a yield")
	var refused: Farming.OpResult = _store.harvest(slot, 9, ripe_tick + 120 * TICKS_PER_HOUR, 1000)
	assert_false(refused.ok, "120 hours refuses")
	assert_equal(refused.error, Farming.REFUSE_RIPE_EXPIRED, "refusal code")
	assert_equal(refused.value, 0, "and carries no yield")
	assert_equal(_store.state_of(slot).value, RIPE, "a refusal changes nothing")
	assert_equal(_store.tile_family_streak_of(TILE).value, 0, "and banks no harvest")
	assert_true(_store.harvest(slot, 9, ripe_tick + 119 * TICKS_PER_HOUR, 1000).ok,
		"one hour earlier still completes")


func test_the_ripe_and_growth_clocks_live_on_the_tile_so_a_redraw_cannot_restart_them() -> void:
	"""READY_06 §6.4: "Retain the hourly/tick remainder and the ripe timestamp so a load or redraw
	cannot restart either clock"."""
	var slot: int = _ripe(GRAIN)
	var ripe_tick: int = _ripe_tick_of(GRAIN)
	assert_equal(_store.tile_ripe_tick_of(TILE).value, ripe_tick, "the tile carries the instant")
	_store.destroy(_store.ref_of(slot))
	assert_equal(_store.tile_ripe_tick_of(TILE).value, ripe_tick, "erasing does not clear it")
	assert_equal(_store.tile_growth_remainder_of(TILE).value, 0, "nor the growth remainder")
	var rebuilt: int = _plot()
	assert_equal(_store.ripe_elapsed_hours_of(rebuilt, ripe_tick + 96 * TICKS_PER_HOUR).value, 96,
		"the rebuilt row reads the same clock, it does not start a fresh one")


# --- READY_06 §6.1: sowing, and the post-commitment cancellation regime -------------------------------

func test_a_sown_plot_takes_no_growth_no_tending_no_frost_and_no_blight() -> void:
	"""READY_06 §6.1: "No hourly growth, and no growing-crop tending, frost or blight, applies to
	SOWN." Every one of those entry points must refuse before the sowing work completes."""
	var slot: int = _sown(GRAIN)
	assert_true(_store.is_sowing(slot), "seed is committed and the sowing work is outstanding")
	var grown: Farming.OpResult = _store.advance_growth_hour(slot, 120, 0)
	assert_false(grown.ok, "no hourly growth")
	assert_equal(grown.error, Farming.REFUSE_NOT_GROWING, "refusal code")
	assert_false(_store.tend(slot).ok, "no growing-crop tending")
	assert_false(_store.apply_frost_hour(slot, -50).ok, "no frost")
	assert_false(_store.apply_blight_day(slot).ok, "no blight")
	assert_equal(_store.growth_milli_hours_of(slot).value, 0, "and nothing accumulated")
	assert_equal(_store.health_of(slot).value, 10000, "at full health")
	assert_true(_store.begin_growing(slot).ok, "successful sowing completion enters GROWING")
	assert_false(_store.is_sowing(slot), "and the plot is no longer sowing")
	assert_true(_store.advance_growth_hour(slot, 120, 0).ok, "which is where growth starts")


func test_a_replacement_worker_cannot_commit_the_seed_a_second_time() -> void:
	"""READY_06 §6.1: "A worker change preserves the WIP and cannot consume seed again." The WU
	progress is the Job's, so a worker change calls nothing here; what this store must guarantee
	is that a second productive start on the same plot refuses."""
	var slot: int = _sown(GRAIN)
	assert_equal(_store.sow_work_milli_wu(), 4000, "§5.6's 4 WU of sowing, in milli-WU")
	var again: Farming.OpResult = _store.plant(slot, GRAIN, 1, LEGAL_SEASON[GRAIN], LEGAL_DAY[GRAIN])
	assert_false(again.ok, "a second productive start refuses")
	assert_equal(again.error, Farming.REFUSE_NOT_EMPTY, "refusal code")
	assert_equal(again.value, 0, "and returns no second seed quantity")
	assert_equal(_store.state_of(slot).value, SOWN, "the committed sowing is untouched")
	assert_equal(_store.crop_id_of(slot).value, GRAIN, "with its crop intact")


func test_the_seed_committed_at_productive_start_is_exactly_250_milli_units() -> void:
	"""READY_06 §6.1: "consume the exact seed (250 milli-U per tile)". Returned, never consumed
	here -- inventory.gd owns the lot."""
	var slot: int = _plot()
	var planted: Farming.OpResult = _store.plant(slot, GRAIN, 1, LEGAL_SEASON[GRAIN], LEGAL_DAY[GRAIN])
	assert_true(planted.ok, "plant (error: %s)" % planted.error)
	assert_equal(planted.value, 250, "the seed the caller must consume")
	assert_equal(_store.state_of(slot).value, SOWN, "and the plot is SOWN, not GROWING")


func test_cancelling_a_committed_sowing_refunds_nothing_and_keeps_every_history() -> void:
	"""READY_06 §6.1's post-commitment regime: "discard the committed seed and unfinished WIP with
	no seed or compost refund, return the plot to EMPTY, and preserve soil, family and compost
	history and XP already earned"."""
	var slot: int = _harvest_grain_cycles(1)
	assert_true(_store.apply_compost(slot, 1).ok, "compost the tile this season")
	assert_equal(_store.fertility_of(slot).value, 7300, "7000 - 1200 + 1500")
	assert_true(_store.plant(slot, GRAIN, 2, LEGAL_SEASON[GRAIN], LEGAL_DAY[GRAIN]).ok, "sow")
	var cancelled: Farming.OpResult = _store.cancel_sowing(slot)
	assert_true(cancelled.ok, "cancel_sowing (error: %s)" % cancelled.error)
	assert_equal(cancelled.value, 0, "no seed and no compost is refunded")
	assert_equal(_store.state_of(slot).value, EMPTY, "the plot is EMPTY again")
	assert_equal(_store.crop_id_of(slot).value, -1, "with no crop")
	assert_equal(_store.fertility_of(slot).value, 7300, "soil history is preserved")
	assert_equal(_store.last_family_of(slot).value, CEREAL, "family history is preserved")
	assert_equal(_store.family_streak_of(slot).value, 1, "and its count")
	assert_equal(_store.compost_milli_of(slot).value, 2000, "compost history is preserved")
	assert_false(_store.is_compost_eligible(TILE, 2), "and buys no second application")


func test_cancel_sowing_applies_only_to_a_plot_that_holds_committed_seed() -> void:
	"""A cancellation before productive start touches nothing here, because the plot never left
	EMPTY; a GROWING, RIPE or WITHERED plot is past the sowing regime entirely."""
	var empty: int = _plot()
	var refused: Farming.OpResult = _store.cancel_sowing(empty)
	assert_false(refused.ok, "an EMPTY plot has no committed sowing to cancel")
	assert_equal(refused.error, Farming.REFUSE_NOT_SOWN, "refusal code")
	var growing: int = _growing(GRAIN, TILE + 1)
	assert_false(_store.cancel_sowing(growing).ok, "a GROWING plot is past the sowing regime")
	assert_equal(_store.state_of(growing).value, GROWING, "and is left alone")
	var ripe: int = _ripe(GRAIN, TILE + 2)
	assert_false(_store.cancel_sowing(ripe).ok, "a RIPE plot too")
	assert_false(_store.cancel_sowing(4095).ok, "and an absent row refuses")


# --- READY_06 §6.3: compost_milli is a current-season mirror ------------------------------------------

func test_a_redraw_in_the_same_season_derives_the_mirror_back_to_2000() -> void:
	"""READY_06 §6.3: "At plot creation, redraw and load, derive or validate the mirror: 2000 iff
	the tile's application season equals the current absolute season, else 0." The mirror follows
	the TILE, so a redraw inside the same season shows the application again."""
	var slot: int = _plot()
	assert_equal(_store.compost_milli_of(slot).value, 0, "nothing applied yet")
	assert_true(_store.apply_compost(slot, 1).ok, "apply compost in the first spring")
	assert_equal(_store.compost_milli_of(slot).value, 2000, "the mirror holds the 2 U")
	_store.destroy(_store.ref_of(slot))
	var same_season: int = _plot(TILE, LOAM, 12)
	assert_equal(_store.compost_milli_of(same_season).value, 2000,
		"day 12 is still the first season, so the mirror is derived back")
	_store.destroy(_store.ref_of(same_season))
	var next_season: int = _plot(TILE, LOAM, 13)
	assert_equal(_store.compost_milli_of(next_season).value, 0,
		"day 13 opens a new season, so the mirror is 0")
	assert_equal(_store.tile_compost_season_of(TILE).value, 0,
		"and the authoritative application season is untouched by either redraw")


func test_the_season_boundary_resets_the_mirror_without_touching_history_or_fertility() -> void:
	"""READY_06 §6.3: "Reset the mirror at a season boundary without clearing tile history or
	fertility"."""
	var slot: int = _harvest_grain_cycles(1)
	assert_true(_store.apply_compost(slot, 1).ok, "apply compost in the first spring")
	assert_equal(_store.compost_milli_of(slot).value, 2000, "the mirror is set")
	var unchanged: Farming.OpResult = _store.refresh_compost_mirrors_for_day(12)
	assert_true(unchanged.ok, "refresh inside the same season")
	assert_equal(unchanged.value, 0, "changes nothing")
	assert_equal(_store.compost_milli_of(slot).value, 2000, "and leaves the mirror set")
	var boundary: Farming.OpResult = _store.refresh_compost_mirrors_for_day(13)
	assert_true(boundary.ok, "refresh on the first day of the next season")
	assert_equal(boundary.value, 1, "one mirror was reset")
	assert_equal(_store.compost_milli_of(slot).value, 0, "the mirror is 0 in the new season")
	assert_equal(_store.tile_compost_season_of(TILE).value, 0, "the application season stands")
	assert_equal(_store.fertility_of(slot).value, 7300, "fertility is untouched")
	assert_equal(_store.tile_last_family_of(TILE).value, CEREAL, "and so is the rotation pair")
	assert_equal(_store.tile_family_streak_of(TILE).value, 1, "both halves of it")
	assert_true(_store.is_compost_eligible(TILE, 13), "the new season is eligible as normal")


func test_the_mirror_refresh_is_idempotent_and_refuses_a_day_before_the_calendar() -> void:
	"""Repeated calls settle: the second reports nothing changed. Day 0 names no day."""
	var slot: int = _plot()
	_store.apply_compost(slot, 1)
	assert_equal(_store.refresh_compost_mirrors_for_day(25).value, 1, "the first reset")
	assert_equal(_store.refresh_compost_mirrors_for_day(25).value, 0, "the second changes nothing")
	assert_equal(_store.refresh_compost_mirrors_for_day(1).value, 1, "and it can be re-derived")
	assert_equal(_store.compost_milli_of(slot).value, 2000, "back to the applied quantity")
	var refused: Farming.OpResult = _store.refresh_compost_mirrors_for_day(0)
	assert_false(refused.ok, "day 0 names no day")
	assert_equal(refused.error, Farming.REFUSE_INVALID_DAY, "refusal code")
	assert_equal(_store.compost_milli_of(slot).value, 2000, "and a refusal moves no mirror")


func test_creating_a_plot_refuses_a_day_before_the_calendar_and_allocates_nothing() -> void:
	"""The mirror cannot be derived without a day, so an undatable create refuses outright."""
	var refused: Farming.OpResult = _store.create_plot_at_tile(TILE, LOAM, 0)
	assert_false(refused.ok, "day 0 refuses")
	assert_equal(refused.error, Farming.REFUSE_INVALID_DAY, "refusal code")
	assert_equal(_store.count(), 0, "and no row was allocated")
	assert_false(_store.has_plot_at_tile(TILE), "nor was the tile claimed")
	assert_true(_store.create_plot_at_tile(TILE, LOAM, 1).ok, "day 1 is the first storable day")
