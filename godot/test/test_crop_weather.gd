extends "res://test/framework/test_case.gd"
## Suite for `scripts/core/crop_weather.gd` — ARCH-SYS-006, REQ-SET-007's "advance crops/weather".
##
## This suite tests the ORCHESTRATION and its TWO CADENCES, not the stores' arithmetic, which
## `test_farming.gd`, `test_weather.gd` and `test_orchard_hive.gd` already pin in isolation. What
## is asserted here is that a real hour crossing reaches the crop store, that a real midnight
## reaches the weather, orchard and moisture steps, that each reaches it exactly once, that each
## reaches it with the right day, and that the steps this stage does NOT own stay untouched.
##
## Every expected number below is recomputed here from the specification's own tables, never read
## back out of the module under test:
##   * §5.6 hourly growth `1000 * temperature_factor * moisture_factor / 1000000`, with the
##     temperature bands 0/500/1000/700 and the moisture bands 1000/500/0 transcribed by hand,
##     and cabbage's stated 120-hour duration.
##   * §5.6's frost damage per hour per crop, and REQ-SET-087's 400/200 blight per day.
##   * §5.10's season baselines (12 C/+1200, 22 C/+300, 10 C/+700, -5 C/+0) and its
##     "600 moisture/day baseline, multiplied 1500/1000 in summer; rain adds after evaporation".
##   * §5.10's event table start days and durations, and decision 0028's roll intervals.
##
## CALENDAR. Tick 0 is 06:00 of absolute day 1, so day D opens at `(D-1)*18000 - 4500` and an
## hour crossing satisfies `(tick + 4500) mod 750 == 0`. 4500 is six whole hours, so an hour
## crossing is also exactly a positive multiple of 750; every tick constant below is that
## arithmetic done by hand.
##
## THE WORLD SEEDS ARE DERIVED, NOT GUESSED. `_SEED_SUMMER_BLIGHT` and friends are the smallest
## positive seeds whose FIRST WEATHER draw lands in decision 0028's stated interval for that
## event in that season, computed from ARCH-RNG-001's own `hash_pair` and xorshift32. Each test
## that uses one ALSO asserts which event was scheduled, so a wrong seed fails loudly rather than
## quietly testing a different row.

const CropWeatherScript := preload("res://scripts/core/crop_weather.gd")
const EcologyScript := preload("res://scripts/core/ecology.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")
const WeatherScript := preload("res://scripts/core/weather.gd")
const OrchardHiveScript := preload("res://scripts/core/orchard_hive.gd")
const EntityDirectoryScript := preload("res://scripts/core/entity_directory.gd")
const FishingScript := preload("res://scripts/core/fishing.gd")
const IntMathScript := preload("res://scripts/core/int_math.gd")
const RngScript := preload("res://scripts/core/rng.gd")

## GDD §5.1's season order, transcribed.
const SPRING: int = 0
const SUMMER: int = 1
const AUTUMN: int = 2
const WINTER: int = 3

## §4.3 states `Soil | LOAM=0, CLAY=1, SAND=2` explicitly; transcribed rather than read back.
const SOIL_LOAM: int = 0

## `farming.gd`'s five §5.6 CropDefinition rows, in the alphabetical order that file compiles
## them: beans, cabbage, flax, grain, roots.
const CROP_BEANS: int = 0
const CROP_CABBAGE: int = 1
const CROP_GRAIN: int = 3
const CROP_ROOTS: int = 4

## §4.3's EventDefinition ids, from the ascending ASCII keys of its own catalog domain.
const EVENT_BLIGHT: int = 0
const EVENT_DROUGHT: int = 2
const EVENT_IDEAL_SPELL: int = 6
const EVENT_NONE: int = -1

## §5.6 CropState, stated explicitly in §4.3.
const STATE_GROWING: int = 2
const STATE_RIPE: int = 3
const STATE_WITHERED: int = 4

## §5.10 season baselines, transcribed from the table in tenths of a degree and moisture points.
const SPRING_TEMPERATURE_TENTHS: int = 120
const SUMMER_TEMPERATURE_TENTHS: int = 220
const WINTER_TEMPERATURE_TENTHS: int = -50
const SPRING_RAIN: int = 1200
const SUMMER_RAIN: int = 300
const WINTER_RAIN: int = 0

## §5.10: "Plots lose 600 moisture/day baseline, multiplied 1500/1000 in summer".
const EVAPORATION_PER_DAY: int = 600
const SUMMER_EVAPORATION_PER_DAY: int = 900
## Drought's separately stated "extra moisture-1500/day", added after the summer multiplier.
const DROUGHT_EXTRA_EVAPORATION: int = 1500

## §5.6's stated growth duration of cabbage, in game hours, and the milli-hour scale.
const CABBAGE_GROWTH_HOURS: int = 120
const MILLI_HOURS_PER_HOUR: int = 1000
## §5.6's frost damage per subzero hour for roots and cabbage.
const ROOTS_FROST_PER_HOUR: int = 300
const CABBAGE_FROST_PER_HOUR: int = 150
## REQ-SET-087's blight damage per day, and its halved tended form.
const BLIGHT_LOSS_PER_DAY: int = 400
const BLIGHT_TENDED_LOSS_PER_DAY: int = 200
## §5.6's crop health scale.
const HEALTH_MAX: int = 10000
## §4.2's starting plot moisture.
const INITIAL_MOISTURE: int = 6000
## REQ-SET-086's clamp.
const MOISTURE_MAX: int = 10000

## §5.6: "Untended spring/summer days remove 100 health; tended days restore 50, max 10000".
const ORCHARD_UNTENDED_LOSS: int = 100
## §4.3's TreeSpecies ids from ascending ASCII keys: apple=0, pear=1.
const SPECIES_APPLE: int = 0

## REQ-SET-082's stated pollination factors for beans.
const POLLINATION_NEUTRAL: int = 1000
const POLLINATION_ONE_HIVE: int = 1100
const POLLINATION_TWO_HIVES: int = 1150

## `sim_clock.gd`'s calendar constants, restated: 750 ticks/hour, 18000/day, 4500 offset.
const TICKS_PER_HOUR: int = 750
const TICKS_PER_DAY: int = 18000
const CALENDAR_OFFSET_TICKS: int = 4500

## Smallest positive world seeds whose first WEATHER draw lands in decision 0028's interval for
## the named event in the named season. Each user asserts the scheduled event as well.
const SEED_SUMMER_BLIGHT: int = 4
const SEED_SUMMER_DROUGHT: int = 6
const SEED_SUMMER_IDEAL: int = 1

## A crop tile well inside §5.1's 128x128 grid, and a hive tile exactly 6 tiles away -- 12288
## simulation units at 2048 units/tile, which is ruling §3's inclusive 12 m range.
const PLOT_TILE_X: int = 40
## Deliberately UNEQUAL to `PLOT_TILE_X`: a square fixture would make a transposed tile decode
## indistinguishable from the right one, and the pollination range would not notice.
const PLOT_TILE_Z: int = 60
const HIVE_TILE_X: int = 46
const SECOND_HIVE_TILE_X: int = 44
## A second crop tile, out of every hive's range, for the "other plots are untouched" assertions.
const FAR_TILE_X: int = 100
const FAR_TILE_Z: int = 100

var _rng: RngScript = null
var _ecology: EcologyScript = null
var _crop: CropWeatherScript = null


func before_each() -> void:
	"""Compose an ecology, an unseeded stream set and the crop/weather stage over both."""
	_rng = RngScript.new()
	_ecology = EcologyScript.new()
	_crop = CropWeatherScript.new(_ecology, _rng)


func after_each() -> void:
	"""Drop every fixture reference so nothing survives into the next test."""
	_crop = null
	_ecology = null
	_rng = null


# --- fixture helpers ------------------------------------------------------------------------------

func _seed(world_seed: int) -> void:
	"""Seed the WEATHER stream, standing in for REQ-SET-009's absent world generation."""
	assert_true(_rng.seed_world(world_seed).ok, "the fixture world seed must take")


func _midnight_of(absolute_day: int) -> int:
	"""The offset-calendar tick that opens `absolute_day`: `(day-1)*18000 - 4500`."""
	return (absolute_day - 1) * TICKS_PER_DAY - CALENDAR_OFFSET_TICKS


func _hour(index: int) -> int:
	"""The `index`-th hour crossing after tick 0. 4500 is six whole hours, so this is `750*index`."""
	return TICKS_PER_HOUR * index


func _tile(x: int, z: int) -> int:
	"""GDD §5.1's exterior tile index `z*128+x`, through the geometry owner."""
	var index: IntMathScript.IntResult = _ecology.resource_nodes().tile_index(x, z)
	assert_true(index.ok, "the fixture tile must be on the grid")
	return index.value


func _plot(x: int, z: int) -> int:
	"""Create one loam FarmPlot through the ARCH-SYS-006 join and return its typed row."""
	var made: FarmingScript.OpResult = _crop.create_plot_at_tile(_tile(x, z), SOIL_LOAM, 1)
	assert_true(made.ok, "the fixture plot must be created (%s)" % made.error)
	return made.value


func _growing(x: int, z: int, crop_id: int, day: int, season: int, season_day: int) -> int:
	"""Create a plot, commit its seed and complete its sowing, leaving it GROWING."""
	var slot: int = _plot(x, z)
	var sown: FarmingScript.OpResult = _crop.farming().plant(slot, crop_id, day, season, season_day)
	assert_true(sown.ok, "the fixture crop must be sown (%s)" % sown.error)
	assert_true(_crop.farming().begin_growing(slot).ok, "and its sowing must complete")
	return slot


func _hive(x: int, z: int, day: int) -> Vector2i:
	"""Colonise one 1x1 hive at §5.6's starting strength 8000, which is above the 5000 line."""
	var building: Vector2i = _ecology.directory().create(EntityDirectoryScript.KIND_BUILDING)
	var made: OrchardHiveScript.OpResult = _ecology.orchard_hive().create_hive(
		building, x, z, x, z, day)
	assert_true(made.ok, "the fixture hive must be created (%s)" % made.error)
	return made.ref


func _orchard(origin_x: int, origin_z: int, day: int) -> Vector2i:
	"""Plant one 4x4 apple block, whose origin is clear of every crop tile used here."""
	var made: OrchardHiveScript.OpResult = _ecology.orchard_hive().plant_orchard(
		origin_x, origin_z, SPECIES_APPLE, day)
	assert_true(made.ok, "the fixture orchard must be planted (%s)" % made.error)
	return made.ref


func _run_day(absolute_day: int) -> CropWeatherScript.DayResult:
	"""Run one crop/weather midnight with no hive eligibility crossing to carry over."""
	return _crop.run_day(_midnight_of(absolute_day), 0)


func _run_days(first_day: int, last_day: int) -> void:
	"""Run every crop/weather midnight from `first_day` to `last_day` inclusive."""
	for day: int in range(first_day, last_day + 1):
		var result: CropWeatherScript.DayResult = _run_day(day)
		assert_true(result.ok, "day %d must commit (%s)" % [day, result.error])


func _health(slot: int) -> int:
	"""§4.2's `health` column of one plot."""
	return _crop.farming().health_of(slot).value


func _moisture(slot: int) -> int:
	"""§4.2's `moisture` column of one plot."""
	return _crop.farming().moisture_of(slot).value


func _growth(slot: int) -> int:
	"""§4.2's `growth_milli_hours` column of one plot."""
	return _crop.farming().growth_milli_hours_of(slot).value


func _state(slot: int) -> int:
	"""§4.2's `state` column of one plot."""
	return _crop.farming().state_of(slot).value


func _weather_draws() -> int:
	"""Draws taken from ARCH-RNG-002's WEATHER stream since the world was seeded."""
	return _rng.draw_count_of(RngScript.STREAM_WEATHER).value


func _pollination(slot: int, crop_id: int) -> IntMathScript.IntResult:
	"""REQ-SET-082's factor for a plot, read exactly as `farming.gd`'s harvest would read it."""
	var out: IntMathScript.IntResult = IntMathScript.IntResult.new()
	_ecology.orchard_hive().farm_pollination_factor_into(slot, crop_id, out)
	return out


# --- the two cadences are separate --------------------------------------------------------------

func test_an_hour_crossing_is_every_750th_tick_and_a_midnight_is_one_of_them() -> void:
	"""ARCH-TICK-002: hour boundaries satisfy `(k+4500) mod 750 == 0`, and 18000 is 24 of them."""
	assert_false(CropWeatherScript.is_hour_boundary(0), "tick 0 is 06:00 and starts no new hour")
	assert_true(CropWeatherScript.is_hour_boundary(750), "the first crossing is tick 750")
	assert_false(CropWeatherScript.is_hour_boundary(751), "and one tick later is not")
	assert_false(CropWeatherScript.is_hour_boundary(749), "nor one tick earlier")
	assert_true(CropWeatherScript.is_hour_boundary(13500), "the first midnight is also an hour")
	assert_true(CropWeatherScript.is_hour_boundary(18000), "so is 06:00 of day 2, which is no day")
	assert_false(CropWeatherScript.is_hour_boundary(-750), "and no negative tick is a crossing")


func test_the_hourly_leg_refuses_a_tick_that_is_not_an_hour_crossing() -> void:
	"""A tick inside an hour integrates nothing: the cadence is a gate, not a rounding."""
	var result: CropWeatherScript.HourResult = _crop.run_hour(751)
	assert_false(result.ok, "751 is not an hour crossing")
	assert_equal(result.error, &"NOT_AN_HOUR_BOUNDARY", "and the refusal names the cadence")
	assert_equal(_crop.last_hour_tick(), -1, "no hour was consumed")


func test_the_hourly_leg_runs_at_hours_that_are_not_midnight() -> void:
	"""The hourly cadence is NOT a midnight-only stage: two ordinary hours integrate two hours."""
	_crop.weather().refresh_daily(SUMMER, 1)
	var slot: int = _growing(PLOT_TILE_X, PLOT_TILE_Z, CROP_CABBAGE, 17, SUMMER, 5)
	assert_true(_crop.run_hour(_hour(1)).ok, "tick 750 is an hour and no midnight")
	assert_equal(_growth(slot), MILLI_HOURS_PER_HOUR, "one hour of growth was integrated")
	assert_true(_crop.run_hour(_hour(2)).ok, "tick 1500 is the next hour")
	assert_equal(_growth(slot), 2 * MILLI_HOURS_PER_HOUR, "and a second hour was integrated")
	assert_equal(_crop.last_day_run(), 0, "and no crop/weather DAY has run at all")


func test_the_daily_leg_refuses_a_tick_that_is_not_a_midnight_crossing() -> void:
	"""`tick % 18000 == 0` names 06:00 under the offset calendar and is not a day boundary."""
	var result: CropWeatherScript.DayResult = _crop.run_day(TICKS_PER_DAY, 0)
	assert_false(result.ok, "tick 18000 is 06:00 of day 2")
	assert_equal(result.error, &"NOT_A_DAY_BOUNDARY", "and the refusal names the cadence")
	assert_equal(_crop.last_day_run(), 0, "no day was consumed")


func test_the_daily_leg_refuses_a_negative_eligibility_crossing_count() -> void:
	"""A count that cannot have come from ARCH-SYS-005 refuses instead of being read as zero."""
	var result: CropWeatherScript.DayResult = _crop.run_day(_midnight_of(2), -1)
	assert_false(result.ok, "a negative crossing count is not a count")
	assert_equal(result.error, &"INVALID_ELIGIBILITY_CROSSINGS", "and says so")
	assert_equal(_crop.last_day_run(), 0, "and no day was consumed")


# --- idempotence, on both cadences --------------------------------------------------------------

func test_a_replayed_hour_is_refused_rather_than_integrated_twice() -> void:
	"""A second call for one hour would double that hour's growth into the same 60 minutes."""
	_crop.weather().refresh_daily(SUMMER, 1)
	var slot: int = _growing(PLOT_TILE_X, PLOT_TILE_Z, CROP_CABBAGE, 17, SUMMER, 5)
	assert_true(_crop.run_hour(_hour(1)).ok, "the first call integrates the hour")
	var replay: CropWeatherScript.HourResult = _crop.run_hour(_hour(1))
	assert_false(replay.ok, "the second is refused")
	assert_equal(replay.error, &"CROP_WEATHER_HOUR_ALREADY_RUN", "with the replay code")
	assert_equal(_growth(slot), MILLI_HOURS_PER_HOUR, "and exactly one hour of growth stands")


func test_an_earlier_hour_cannot_be_run_after_a_later_one() -> void:
	"""The latch is a high-water mark, so a rewound clock cannot re-integrate the same hours."""
	assert_true(_crop.run_hour(_hour(4)).ok, "hour 4 runs")
	var earlier: CropWeatherScript.HourResult = _crop.run_hour(_hour(3))
	assert_false(earlier.ok, "hour 3 is behind the latch")
	assert_equal(earlier.error, &"CROP_WEATHER_HOUR_ALREADY_RUN", "with the replay code")
	assert_equal(_crop.last_hour_tick(), _hour(4), "and the latch did not move backwards")


func test_a_replayed_day_is_refused_rather_than_applied_twice() -> void:
	"""One replayed midnight would evaporate a second day and age every orchard twice."""
	var slot: int = _plot(PLOT_TILE_X, PLOT_TILE_Z)
	assert_true(_run_day(2).ok, "the first run commits")
	var after_one: int = _moisture(slot)
	var replay: CropWeatherScript.DayResult = _run_day(2)
	assert_false(replay.ok, "the second is refused")
	assert_equal(replay.error, &"CROP_WEATHER_DAY_ALREADY_RUN", "with the replay code")
	assert_equal(_moisture(slot), after_one, "and exactly one day of moisture stands")
	assert_equal(_crop.last_day_run(), 2, "the day is reported consumed either way")


func test_an_earlier_day_cannot_be_run_after_a_later_one() -> void:
	"""The day latch is the same high-water mark, so a rewound calendar refuses."""
	assert_true(_run_day(5).ok, "day 5 runs")
	var earlier: CropWeatherScript.DayResult = _run_day(4)
	assert_false(earlier.ok, "day 4 is behind the latch")
	assert_equal(earlier.error, &"CROP_WEATHER_DAY_ALREADY_RUN", "with the replay code")
	assert_equal(_crop.last_day_run(), 5, "and the latch did not move backwards")


func test_the_two_latches_are_independent() -> void:
	"""A consumed midnight does not consume that midnight's hour, and neither blocks the other."""
	assert_true(_crop.run_day(_midnight_of(2), 0).ok, "the day 2 midnight runs as a DAY")
	assert_true(_crop.run_hour(_midnight_of(2)).ok, "and the same tick still runs as an HOUR")
	assert_equal(_crop.last_day_run(), 2, "the day latch holds day 2")
	assert_equal(_crop.last_hour_tick(), _midnight_of(2), "and the hour latch holds its tick")


# --- REQ-SET-072 growth, and REQ-SET-073 ripening at the stated duration -------------------------

func test_a_crop_grows_by_the_stated_hourly_step_and_ripens_at_its_stated_duration() -> void:
	"""§5.6: `1000 * 1000 * 1000 / 1000000` per hour at ideal temperature and in-range moisture.

	Cabbage's stated duration is 120 game hours, its moisture range is 4000-8500 and a plot spawns
	at 6000, and summer's 22 C is inside §5.6's 8-26 C ideal band -- so every hour contributes
	exactly 1000 milli-hours and hour 120 is the first that can ripen it.
	"""
	_crop.weather().refresh_daily(SUMMER, 1)
	assert_equal(_crop.weather().temperature_tenths(), SUMMER_TEMPERATURE_TENTHS, "22 C")
	var slot: int = _growing(PLOT_TILE_X, PLOT_TILE_Z, CROP_CABBAGE, 17, SUMMER, 5)
	for index: int in range(1, CABBAGE_GROWTH_HOURS):
		assert_true(_crop.run_hour(_hour(index)).ok, "hour %d integrates" % index)
	assert_equal(_growth(slot), (CABBAGE_GROWTH_HOURS - 1) * MILLI_HOURS_PER_HOUR,
		"119 hours have accumulated 119000 milli-hours")
	assert_equal(_state(slot), STATE_GROWING, "and 119 hours is not yet the stated 120")
	var last: CropWeatherScript.HourResult = _crop.run_hour(_hour(CABBAGE_GROWTH_HOURS))
	assert_true(last.ok, "the 120th hour integrates")
	assert_equal(_growth(slot), CABBAGE_GROWTH_HOURS * MILLI_HOURS_PER_HOUR, "120000 milli-hours")
	assert_equal(_state(slot), STATE_RIPE, "which is REQ-SET-073's ripening")
	assert_equal(last.plots_ripened, 1, "and the hour reports the plot it ripened")


func test_a_frozen_hour_advances_no_growth_at_all() -> void:
	"""§5.6's temperature factor is 0 below 0 C, so a subzero hour contributes nothing."""
	_crop.weather().refresh_daily(WINTER, 1)
	assert_equal(_crop.weather().temperature_tenths(), WINTER_TEMPERATURE_TENTHS, "-5 C")
	var slot: int = _growing(PLOT_TILE_X, PLOT_TILE_Z, CROP_ROOTS, 3, SPRING, 3)
	assert_true(_crop.run_hour(_hour(1)).ok, "the hour runs")
	assert_equal(_growth(slot), 0, "and nothing grew at -5 C")


func test_a_plot_outside_its_moisture_range_grows_at_the_stated_half_rate() -> void:
	"""§5.6: moisture factor is 500 within 2000 outside the range, so the step halves to 500."""
	_crop.weather().refresh_daily(SUMMER, 1)
	var slot: int = _growing(PLOT_TILE_X, PLOT_TILE_Z, CROP_CABBAGE, 17, SUMMER, 5)
	assert_true(_crop.farming().apply_moisture_delta(slot, -2500).ok, "moisture drops to 3500")
	assert_equal(_moisture(slot), 3500, "which is 500 below cabbage's stated 4000 minimum")
	assert_true(_crop.run_hour(_hour(1)).ok, "the hour runs")
	assert_equal(_growth(slot), 500, "1000 * 1000 * 500 / 1000000")


# --- REQ-SET-084 frost is HOURLY --------------------------------------------------------------------

func test_frost_removes_the_stated_health_every_hour_not_once_a_day() -> void:
	"""REQ-SET-084 states damage PER SUBZERO HOUR; three hours of winter cost three times 300."""
	_crop.weather().refresh_daily(WINTER, 1)
	var slot: int = _growing(PLOT_TILE_X, PLOT_TILE_Z, CROP_ROOTS, 3, SPRING, 3)
	for index: int in range(1, 4):
		var hour: CropWeatherScript.HourResult = _crop.run_hour(_hour(index))
		assert_true(hour.ok, "hour %d integrates" % index)
		assert_equal(hour.plots_frosted, 1, "and reports the frosted plot")
	assert_equal(_health(slot), HEALTH_MAX - 3 * ROOTS_FROST_PER_HOUR,
		"§5.6's roots frost damage is 300/hour, so three hours cost 900")


func test_a_temperate_hour_costs_no_health_at_all() -> void:
	"""REQ-SET-084 applies "while temperature<0 C"; 12 C is not that, and the branch is skipped."""
	_crop.weather().refresh_daily(SPRING, 1)
	assert_equal(_crop.weather().temperature_tenths(), SPRING_TEMPERATURE_TENTHS, "12 C")
	var slot: int = _growing(PLOT_TILE_X, PLOT_TILE_Z, CROP_ROOTS, 3, SPRING, 3)
	var hour: CropWeatherScript.HourResult = _crop.run_hour(_hour(1))
	assert_true(hour.ok, "the hour integrates")
	assert_equal(hour.plots_frosted, 0, "no plot was frosted")
	assert_equal(_health(slot), HEALTH_MAX, "and full health stands")


func test_frost_halves_for_a_tended_cabbage_plot_and_not_for_another_crop() -> void:
	"""REQ-SET-084's "halved for cabbage in a tended plot" reaches the hourly leg through the tile."""
	_crop.weather().refresh_daily(WINTER, 1)
	var cabbage: int = _growing(PLOT_TILE_X, PLOT_TILE_Z, CROP_CABBAGE, 17, SUMMER, 5)
	var roots: int = _growing(FAR_TILE_X, FAR_TILE_Z, CROP_ROOTS, 3, SPRING, 3)
	assert_true(_crop.farming().tend(cabbage).ok, "the cabbage plot is tended today")
	assert_true(_crop.farming().tend(roots).ok, "and so is the roots plot")
	assert_true(_crop.run_hour(_hour(1)).ok, "one subzero hour passes")
	assert_equal(_health(cabbage), HEALTH_MAX - CABBAGE_FROST_PER_HOUR / 2,
		"cabbage's 150/hour is halved to 75 in a tended plot")
	assert_equal(_health(roots), HEALTH_MAX - ROOTS_FROST_PER_HOUR,
		"and roots takes its full 300, because the halving is cabbage's alone")


func test_frost_that_empties_health_withers_the_plot_and_stops_there() -> void:
	"""REQ-SET-085: health reaching 0 marks the plot WITHERED; no clearing job is created here."""
	_crop.weather().refresh_daily(WINTER, 1)
	var slot: int = _growing(PLOT_TILE_X, PLOT_TILE_Z, CROP_GRAIN, 3, SPRING, 3)
	var withered_at: int = 0
	for index: int in range(1, 12):
		var hour: CropWeatherScript.HourResult = _crop.run_hour(_hour(index))
		if hour.plots_withered == 1 and withered_at == 0:
			withered_at = index
	assert_equal(withered_at, 10, "grain's 1000/hour empties 10000 health in exactly ten hours")
	assert_equal(_state(slot), STATE_WITHERED, "and the plot stands WITHERED")
	assert_equal(_health(slot), 0, "with health floored at zero")


# --- REQ-SET-075 the ripe grace, withering at the exact hour ----------------------------------------

func test_a_ripe_plot_withers_at_the_exact_hour_its_five_days_complete() -> void:
	"""§5.6: "after 5 days unharvested they become compost-equivalent waste and the plot WITHERED".

	Five days is 120 hours from the tick `ripe_tick` was dated with, and ripening lands on an hour
	crossing, so hour 119 is inside the window and hour 120 is not.
	"""
	_crop.weather().refresh_daily(SUMMER, 1)
	var slot: int = _growing(PLOT_TILE_X, PLOT_TILE_Z, CROP_CABBAGE, 17, SUMMER, 5)
	for index: int in range(1, CABBAGE_GROWTH_HOURS + 1):
		assert_true(_crop.run_hour(_hour(index)).ok, "hour %d integrates" % index)
	assert_equal(_state(slot), STATE_RIPE, "the crop is ripe at hour 120")
	assert_true(_crop.run_hour(_hour(CABBAGE_GROWTH_HOURS + 119)).ok, "119 ripe hours pass")
	assert_equal(_state(slot), STATE_RIPE, "and 119 hours is inside the stated five days")
	var last: CropWeatherScript.HourResult = _crop.run_hour(_hour(CABBAGE_GROWTH_HOURS + 120))
	assert_true(last.ok, "the 120th ripe hour runs")
	assert_equal(_state(slot), STATE_WITHERED, "and the plot withers at exactly five days")
	assert_equal(last.plots_expired, 1, "the hour reports the expiry it applied")


# --- §5.10 the season event: one draw per season, zero for the forced first spring ------------------

func test_the_forced_first_spring_is_scheduled_and_consumes_no_weather_draw() -> void:
	"""§5.10: "First spring is forced Ideal spell on day 6", and ARCH-RNG-002 gives it zero draws."""
	_seed(SEED_SUMMER_BLIGHT)
	var day: CropWeatherScript.DayResult = _run_day(2)
	assert_true(day.ok, "the first midnight commits")
	assert_equal(day.event_scheduled, EVENT_IDEAL_SPELL, "with §5.10's forced onboarding event")
	assert_equal(day.weather_draws, 0, "and the leg reports no draw")
	assert_equal(_weather_draws(), 0, "which the stream's own counter confirms")
	assert_equal(_crop.weather().start_day(), 6, "the stated start day is 6")
	assert_equal(_crop.last_scheduled_season(), 0, "and absolute season 0 is latched")


func test_an_unseeded_settlement_still_gets_its_forced_first_spring() -> void:
	"""The forced path takes no Rng at all, so a world with no seed still opens with weather."""
	var day: CropWeatherScript.DayResult = _run_day(2)
	assert_true(day.ok, "the first midnight commits with no world seed")
	assert_equal(day.event_scheduled, EVENT_IDEAL_SPELL, "the forced event is scheduled")
	assert_false(_rng.is_seeded(), "and the stream set is still unseeded")


func test_the_whole_first_spring_takes_exactly_zero_weather_draws() -> void:
	"""Eleven more midnights inside one season schedule nothing more and draw nothing more."""
	_seed(SEED_SUMMER_BLIGHT)
	_run_days(2, 12)
	assert_equal(_weather_draws(), 0, "no WEATHER draw was taken across the whole first spring")
	assert_equal(_crop.last_scheduled_season(), 0, "and the season stayed latched at 0")


func test_the_second_season_takes_exactly_one_weather_draw_and_no_more() -> void:
	"""ARCH-RNG-002: "One weighted event-selection roll per new season after the forced first spring"."""
	_seed(SEED_SUMMER_BLIGHT)
	_run_days(2, 12)
	var summer: CropWeatherScript.DayResult = _run_day(13)
	assert_true(summer.ok, "summer day 1's midnight commits")
	assert_equal(summer.weather_draws, 1, "one draw, and exactly one")
	assert_equal(_weather_draws(), 1, "which the stream's own counter confirms")
	assert_equal(summer.event_scheduled, EVENT_BLIGHT,
		"seed 4's first WEATHER draw is roll 87 of 120, decision 0028's summer blight interval")
	_run_days(14, 24)
	assert_equal(_weather_draws(), 1, "eleven more summer midnights take no further draw")
	assert_equal(_crop.last_scheduled_season(), 1, "and absolute season 1 is latched")


func test_a_different_seed_selects_a_different_row_from_the_same_interval_table() -> void:
	"""Decision 0028's mapping reaches the stage: two seeds, two of summer's stated rows."""
	_seed(SEED_SUMMER_DROUGHT)
	_run_days(2, 12)
	assert_equal(_run_day(13).event_scheduled, EVENT_DROUGHT, "roll 73 is summer's drought band")
	var other: CropWeatherScript = CropWeatherScript.new(EcologyScript.new(), _fresh_rng(
		SEED_SUMMER_IDEAL))
	for day: int in range(2, 14):
		assert_true(other.run_day(_midnight_of(day), 0).ok, "day %d commits" % day)
	assert_equal(other.weather().event_of(), EVENT_IDEAL_SPELL, "roll 11 is summer's ideal band")


func _fresh_rng(world_seed: int) -> RngScript:
	"""A separate seeded stream set, for a test that needs two independent worlds."""
	var rng: RngScript = RngScript.new()
	assert_true(rng.seed_world(world_seed).ok, "the second world seed must take")
	return rng


func test_an_unseeded_world_refuses_the_second_seasons_draw_and_names_the_stream() -> void:
	"""REQ-SET-009's world generation does not exist, so the missing seed REFUSES rather than
	defaulting to a number this stage invented."""
	_run_days(2, 12)
	var summer: CropWeatherScript.DayResult = _run_day(13)
	assert_false(summer.ok, "summer's draw cannot be taken without a seeded stream")
	assert_equal(summer.error, &"RNG_NOT_SEEDED", "and the stream's own refusal travels out")
	assert_equal(_crop.last_scheduled_season(), 0, "no season was latched by the refused draw")


func test_a_stage_with_no_stream_bound_at_all_refuses_its_own_code() -> void:
	"""A null Rng is a composition fault, not an unseeded world, and gets its own refusal."""
	var unbound: CropWeatherScript = CropWeatherScript.new(EcologyScript.new(), null)
	for day: int in range(2, 13):
		assert_true(unbound.run_day(_midnight_of(day), 0).ok, "spring day %d commits" % day)
	var summer: CropWeatherScript.DayResult = unbound.run_day(_midnight_of(13), 0)
	assert_false(summer.ok, "no stream is bound to draw from")
	assert_equal(summer.error, &"WEATHER_STREAM_NOT_BOUND", "and the stage names that")


# --- REQ-SET-142 forecast and REQ-SET-145 event end -------------------------------------------------

func test_the_forecast_is_disclosed_three_days_before_the_event_starts() -> void:
	"""REQ-SET-142: the ideal spell starts on season day 6, so day 3 is the disclosure day."""
	_seed(SEED_SUMMER_BLIGHT)
	assert_true(_run_day(2).ok, "spring day 2 commits")
	assert_false(_crop.weather().is_forecast_disclosed(), "day 2 is too early to disclose")
	var day_three: CropWeatherScript.DayResult = _run_day(3)
	assert_equal(day_three.forecast_event, EVENT_IDEAL_SPELL, "day 3 discloses the event")
	assert_true(_crop.weather().is_forecast_disclosed(), "and the calendar retains it")
	assert_equal(_crop.weather().forecast_start_day(), 6, "with its stated start day")
	assert_equal(_crop.weather().forecast_duration_days(), 3, "and its stated duration")


func test_the_event_ends_the_day_after_its_window_and_the_forecast_is_retained() -> void:
	"""REQ-SET-145 removes the modifiers; REQ-SET-142 keeps the disclosure in the calendar.

	The ideal spell covers spring days 6-8, so the midnight opening day 9 is the first that
	finds its window closed.
	"""
	_seed(SEED_SUMMER_BLIGHT)
	_run_days(2, 8)
	assert_true(_crop.weather().is_event_scheduled(), "the event still stands on day 8")
	var day_nine: CropWeatherScript.DayResult = _run_day(9)
	assert_equal(day_nine.event_ended, EVENT_IDEAL_SPELL, "day 9 ends it")
	assert_false(_crop.weather().is_event_scheduled(), "and the row names no event")
	assert_equal(day_nine.temperature_tenths, SPRING_TEMPERATURE_TENTHS,
		"the day's baseline returns to spring's own 12 C")
	assert_true(_crop.weather().is_forecast_disclosed(), "and the forecast is still retained")


func test_the_days_baseline_follows_the_active_event_inside_its_window() -> void:
	"""§5.10's ideal spell states 18 C and rain +600 on top of the season's own +1200."""
	_seed(SEED_SUMMER_BLIGHT)
	_run_days(2, 5)
	assert_equal(_crop.weather().temperature_tenths(), SPRING_TEMPERATURE_TENTHS,
		"day 5 is still the plain spring baseline")
	var day_six: CropWeatherScript.DayResult = _run_day(6)
	assert_equal(day_six.temperature_tenths, 180, "day 6 is the ideal spell's stated 18 C")
	assert_equal(day_six.rain, SPRING_RAIN + 600, "and spring's 1200 plus the stated 600")


# --- §5.10 moisture: evaporate first, then rain ------------------------------------------------------

func test_a_plots_moisture_evaporates_before_the_days_rain_is_added() -> void:
	"""§5.10: "rain adds after evaporation", against ONE clamp -- and the order is observable.

	Spring adds 1200 and evaporates 600. A plot at 9800 keeps 10000 under the stated order,
	because the net +600 is clamped once. Adding the rain first and clamping it would cap at
	10000 and then take 600 off, leaving 9400 -- a day's rain silently turned into a day's loss.
	"""
	var slot: int = _plot(PLOT_TILE_X, PLOT_TILE_Z)
	assert_true(_crop.farming().apply_moisture_delta(slot, 3800).ok, "the plot starts at 9800")
	assert_equal(_moisture(slot), 9800, "just below REQ-SET-086's ceiling")
	var day: CropWeatherScript.DayResult = _run_day(2)
	assert_true(day.ok, "the spring midnight commits")
	assert_equal(day.moisture_delta, SPRING_RAIN - EVAPORATION_PER_DAY, "+1200 - 600 = +600")
	assert_equal(_moisture(slot), MOISTURE_MAX, "and the plot is clamped at 10000, not 9400")


func test_summer_scales_the_evaporation_baseline_and_not_the_rain() -> void:
	"""§5.10 scopes "multiplied 1500/1000 in summer" to the 600 baseline: 300 - 900 = -600."""
	_seed(SEED_SUMMER_IDEAL)
	var slot: int = _plot(PLOT_TILE_X, PLOT_TILE_Z)
	_run_days(2, 12)
	var summer: CropWeatherScript.DayResult = _run_day(13)
	assert_true(summer.ok, "summer day 1 commits")
	assert_equal(summer.moisture_delta, SUMMER_RAIN - SUMMER_EVAPORATION_PER_DAY,
		"300 rain against 900 evaporation")
	assert_equal(summer.plots_moistened, 1, "and the one live plot took the change")
	assert_equal(_moisture(slot), MOISTURE_MAX - (SUMMER_EVAPORATION_PER_DAY - SUMMER_RAIN),
		"eleven spring days had already filled the plot to its 10000 ceiling")


func test_drought_adds_its_extra_evaporation_after_the_summer_multiplier() -> void:
	"""§5.10's drought states "rain 0" and "extra moisture-1500/day": 0 - (900 + 1500) = -2400."""
	_seed(SEED_SUMMER_DROUGHT)
	_run_days(2, 12)
	assert_equal(_run_day(13).event_scheduled, EVENT_DROUGHT, "seed 6 draws summer's drought")
	_run_days(14, 17)
	var in_window: CropWeatherScript.DayResult = _run_day(18)
	assert_true(in_window.ok, "summer day 6, the drought's stated start day, commits")
	assert_equal(in_window.moisture_delta,
		-(SUMMER_EVAPORATION_PER_DAY + DROUGHT_EXTRA_EVAPORATION),
		"900 summer evaporation plus drought's separately stated 1500, against no rain")


func test_a_stage_first_running_mid_season_schedules_before_it_waters() -> void:
	"""The season's event is scheduled at the FIRST boundary that season sees, and the moisture
	step must read it.

	§5.10 puts drought's start on season day 6, so a stage whose first boundary IS summer day 6
	schedules an event that is active on that same day -- and that day's moisture has to be
	drought's 2400, not the plain summer 600. This is what fixes §5.10's weather step AHEAD of
	REQ-SET-086's moisture step rather than merely alongside it.
	"""
	_seed(SEED_SUMMER_DROUGHT)
	var slot: int = _plot(PLOT_TILE_X, PLOT_TILE_Z)
	var day: CropWeatherScript.DayResult = _run_day(18)
	assert_true(day.ok, "the summer day 6 midnight commits as this stage's very first day")
	assert_equal(day.season_day, 6, "absolute day 18 is summer's stated day 6")
	assert_equal(day.event_scheduled, EVENT_DROUGHT, "which schedules summer's drought")
	assert_equal(day.moisture_delta,
		-(SUMMER_EVAPORATION_PER_DAY + DROUGHT_EXTRA_EVAPORATION),
		"and the day waters as a drought day, because the schedule ran before the moisture")
	assert_equal(_moisture(slot),
		INITIAL_MOISTURE - SUMMER_EVAPORATION_PER_DAY - DROUGHT_EXTRA_EVAPORATION,
		"so the plot loses 2400 from the 6000 it spawned with")


func test_a_dry_plot_is_floored_at_zero_rather_than_going_negative() -> void:
	"""REQ-SET-086's clamp holds at the bottom as well as the top."""
	_seed(SEED_SUMMER_IDEAL)
	var slot: int = _plot(PLOT_TILE_X, PLOT_TILE_Z)
	_run_days(2, 12)
	assert_true(_crop.farming().apply_moisture_delta(slot, -_moisture(slot) + 200).ok,
		"the plot is left at 200 on the last spring midnight")
	assert_equal(_moisture(slot), 200, "which is less than one summer day of net loss")
	assert_true(_run_day(13).ok, "a summer day of -600 net runs against 200 moisture")
	assert_equal(_moisture(slot), 0, "and the plot floors at zero rather than going negative")


# --- REQ-SET-087 blight settles the COMPLETED day ------------------------------------------------------

func test_blight_removes_the_stated_health_for_each_day_of_its_window() -> void:
	"""REQ-SET-087: 400 health/day while the event covers the day, and nothing outside it.

	Summer blight covers season days 6-8, which are absolute days 18-20; each is settled at the
	midnight that ENDS it, so days 19, 20 and 21 carry the three charges.
	"""
	_seed(SEED_SUMMER_BLIGHT)
	var slot: int = _growing(PLOT_TILE_X, PLOT_TILE_Z, CROP_ROOTS, 13, SUMMER, 1)
	_run_days(2, 12)
	assert_equal(_run_day(13).event_scheduled, EVENT_BLIGHT, "summer draws blight")
	_run_days(14, 18)
	assert_equal(_health(slot), HEALTH_MAX, "nothing is charged before the window's first day ends")
	var first: CropWeatherScript.DayResult = _run_day(19)
	assert_true(first.blight_active, "the midnight ending summer day 6 is blighted")
	assert_equal(_health(slot), HEALTH_MAX - BLIGHT_LOSS_PER_DAY, "and charges the stated 400")
	_run_days(20, 21)
	assert_equal(_health(slot), HEALTH_MAX - 3 * BLIGHT_LOSS_PER_DAY, "three days, three charges")
	assert_true(_run_day(22).ok, "the day after the window runs")
	assert_equal(_health(slot), HEALTH_MAX - 3 * BLIGHT_LOSS_PER_DAY,
		"and REQ-SET-087's "	+ "\"stop damage when the event ends\" needs no step at all")


func test_a_tended_plot_takes_half_the_blight_and_then_loses_its_tending_flag() -> void:
	"""REQ-SET-087's 200 needs the COMPLETED day's tending flag, which the service reset then clears.

	This is the one assertion that pins the daily order: blight settles the day that ended, using
	the flag set during it, and only afterwards is the flag cleared for the day now beginning.
	"""
	_seed(SEED_SUMMER_BLIGHT)
	var slot: int = _growing(PLOT_TILE_X, PLOT_TILE_Z, CROP_ROOTS, 13, SUMMER, 1)
	var tile: int = _tile(PLOT_TILE_X, PLOT_TILE_Z)
	_run_days(2, 18)
	assert_true(_crop.farming().tend(slot).ok, "the plot is tended during summer day 6")
	assert_true(_crop.farming().is_tile_tended_today(tile), "so the tile records the service")
	var settled: CropWeatherScript.DayResult = _run_day(19)
	assert_true(settled.service_counters_reset, "the day reports its service reset")
	assert_equal(_health(slot), HEALTH_MAX - BLIGHT_TENDED_LOSS_PER_DAY,
		"the tended day is charged 200, not 400")
	assert_false(_crop.farming().is_tile_tended_today(tile),
		"and the flag is cleared for the day now beginning")


func test_blight_that_empties_health_withers_the_plot() -> void:
	"""REQ-SET-085 reaches the daily leg too: a crop killed by blight is marked WITHERED."""
	_seed(SEED_SUMMER_BLIGHT)
	var slot: int = _growing(PLOT_TILE_X, PLOT_TILE_Z, CROP_ROOTS, 13, SUMMER, 1)
	_run_days(2, 18)
	assert_true(_crop.farming().apply_health_loss(slot, HEALTH_MAX - BLIGHT_LOSS_PER_DAY).ok,
		"the crop is left with exactly one blighted day of health")
	var settled: CropWeatherScript.DayResult = _run_day(19)
	assert_equal(settled.plots_withered, 1, "the day reports the plot it withered")
	assert_equal(_state(slot), STATE_WITHERED, "and the plot stands WITHERED")


# --- §5.6 the orchard day settles the day that ENDED ----------------------------------------------------

func test_an_orchard_ages_and_loses_health_on_an_untended_growing_season_day() -> void:
	"""§5.6: "Untended spring/summer days remove 100 health"; the day settled is the one that ended."""
	var orchard: Vector2i = _orchard(60, 60, 1)
	var row: int = _ecology.orchard_hive().orchard_row_of(orchard).value
	var day: CropWeatherScript.DayResult = _run_day(2)
	assert_true(day.ok, "the midnight ending spring day 1 commits")
	assert_equal(day.orchards_advanced, 1, "and reports the block it advanced")
	assert_equal(_ecology.orchard_hive().age_days_of(row).value, 1, "the tree is one day old")
	assert_equal(_ecology.orchard_hive().orchard_health_of(row).value,
		HEALTH_MAX - ORCHARD_UNTENDED_LOSS, "and an untended spring day cost 100 health")


func test_the_orchard_day_is_the_day_that_ended_not_the_day_that_began() -> void:
	"""The midnight opening SPRING day 1 settles WINTER day 12, which §5.6 charges nothing for.

	Passing the day now beginning would charge a spring untended day at the moment winter ended,
	which is the same class of error decision 0046 names for the hive's completed day.
	"""
	var orchard: Vector2i = _orchard(60, 60, 1)
	var row: int = _ecology.orchard_hive().orchard_row_of(orchard).value
	_seed(SEED_SUMMER_IDEAL)
	assert_true(_run_day(48).ok, "the midnight ending winter day 11 commits")
	var before: int = _ecology.orchard_hive().orchard_health_of(row).value
	assert_true(_run_day(49).ok, "and so does the one ending winter day 12, opening year 2")
	assert_equal(_ecology.orchard_hive().orchard_health_of(row).value, before,
		"a winter day changes no orchard health, because §5.6 charges spring and summer only")
	assert_true(_run_day(50).ok, "the midnight ending spring day 1 of year 2 commits")
	assert_equal(_ecology.orchard_hive().orchard_health_of(row).value,
		before - ORCHARD_UNTENDED_LOSS, "and THAT is the first spring day charged")


func test_the_winter_chill_counter_follows_the_completed_winter_days() -> void:
	"""§5.6: "Winter chill counter increments per day with temperature<=5 C", reset on winter day 1.

	Winter's baseline is -5 C, so every completed winter day counts. The count is read in autumn,
	where it answers "the previous winter" from the one §4.2 column.
	"""
	var orchard: Vector2i = _orchard(60, 60, 1)
	var row: int = _ecology.orchard_hive().orchard_row_of(orchard).value
	_seed(SEED_SUMMER_IDEAL)
	_run_days(2, 40)
	assert_equal(_ecology.orchard_hive().chill_days_of(row).value, 3,
		"absolute day 40 opens winter day 4, so winter days 1-3 have been settled")
	_run_days(41, 49)
	assert_equal(_ecology.orchard_hive().chill_days_of(row).value, 12,
		"all twelve completed winter days at -5 C, which is at or below the stated 5 C")


# --- decision 0044: the FarmPlot side of the pollination refresh ---------------------------------------

func test_creating_a_plot_refreshes_its_pollination_slice_synchronously() -> void:
	"""Ruling §3: the refresh is part of the committed change, before any dependent read."""
	_hive(HIVE_TILE_X, PLOT_TILE_Z, 1)
	var slot: int = _plot(PLOT_TILE_X, PLOT_TILE_Z)
	assert_true(_crop.check_farm_links_of(slot),
		"the slice already IS the canonical selection when create returns")
	var factor: IntMathScript.IntResult = _pollination(slot, CROP_BEANS)
	assert_true(factor.ok, "and the yield read succeeds without repairing anything")
	assert_equal(factor.value, POLLINATION_ONE_HIVE, "REQ-SET-082's one-hive multiplier")


func test_a_hive_out_of_range_links_to_nothing() -> void:
	"""Ruling §3's range is an inclusive 12 m; the seventh tile away is 14336 units and outside."""
	_hive(PLOT_TILE_X + 7, PLOT_TILE_Z, 1)
	var slot: int = _plot(PLOT_TILE_X, PLOT_TILE_Z)
	assert_true(_crop.check_farm_links_of(slot), "the empty slice is canonical")
	assert_equal(_pollination(slot, CROP_BEANS).value, POLLINATION_NEUTRAL,
		"and a bean plot with no hive in range pays the neutral 1000")


func test_a_yield_read_does_not_repair_a_slice_a_new_hive_made_stale() -> void:
	"""Ruling §3: "Yield and UI reads never repair or mutate links." Only an explicit refresh does.

	`orchard_hive.gd` refreshes its own ORCHARD recipients when a hive is created and states it
	cannot refresh farm recipients. So the second hive leaves this plot's slice one hive short,
	the slice is still LIVE and VALID -- so the read succeeds -- and it answers 1100, the factor
	the stale slice earns, not the 1150 a recomputation would find.
	"""
	_hive(HIVE_TILE_X, PLOT_TILE_Z, 1)
	var slot: int = _plot(PLOT_TILE_X, PLOT_TILE_Z)
	_hive(SECOND_HIVE_TILE_X, PLOT_TILE_Z, 1)
	assert_false(_crop.check_farm_links_of(slot), "the stored slice is no longer canonical")
	assert_equal(_pollination(slot, CROP_BEANS).value, POLLINATION_ONE_HIVE,
		"and the read answers the stale slice rather than repairing it")
	var refreshed: IntMathScript.IntResult = _crop.refresh_all_farm_links()
	assert_true(refreshed.ok, "the explicit refresh succeeds")
	assert_equal(refreshed.value, 1, "over the one live plot")
	assert_true(_crop.check_farm_links_of(slot), "and the slice is canonical again")
	assert_equal(_pollination(slot, CROP_BEANS).value, POLLINATION_TWO_HIVES,
		"which is REQ-SET-082's two-hive multiplier")


func test_a_hive_that_falls_below_the_healthy_line_refuses_the_read_it_cannot_repair() -> void:
	"""Ruling §3: an ineligible linked hive makes the slice STALE, and a read refuses it."""
	var hive: Vector2i = _hive(HIVE_TILE_X, PLOT_TILE_Z, 1)
	var slot: int = _plot(PLOT_TILE_X, PLOT_TILE_Z)
	assert_true(_ecology.orchard_hive().restore_hive_state(hive, 4999, 0, 0, 0, 1).ok,
		"the hive drops one point below §5.6's 5000 healthy line")
	var factor: IntMathScript.IntResult = _pollination(slot, CROP_BEANS)
	assert_false(factor.ok, "the read refuses rather than quietly downgrading the multiplier")
	assert_equal(String(factor.error), "POLLINATION_LINKS_STALE", "with ruling §3's own code")
	assert_true(_crop.refresh_all_farm_links().ok, "an explicit refresh repairs it")
	assert_equal(_pollination(slot, CROP_BEANS).value, POLLINATION_NEUTRAL,
		"and the plot now earns the neutral factor it deserves")


func test_the_daily_leg_refreshes_the_farm_side_of_an_eligibility_crossing() -> void:
	"""The join increment 9 left here: ARCH-SYS-005 commits the strength change, this refreshes.

	The hive is dropped below 5000 WITHOUT a refresh, exactly as a hive-day strength loss inside
	`ecology.gd` leaves the farm side, and the boundary is then told that one crossing occurred.
	"""
	var hive: Vector2i = _hive(HIVE_TILE_X, PLOT_TILE_Z, 1)
	var slot: int = _plot(PLOT_TILE_X, PLOT_TILE_Z)
	assert_true(_ecology.orchard_hive().restore_hive_state(hive, 4999, 0, 0, 0, 1).ok,
		"the hive crosses below the healthy line")
	assert_false(_pollination(slot, CROP_BEANS).ok, "the slice is stale before the boundary")
	var day: CropWeatherScript.DayResult = _crop.run_day(_midnight_of(2), 1)
	assert_true(day.ok, "the midnight commits")
	assert_equal(day.farm_links_refreshed, 1, "and refreshed the one live plot's slice")
	assert_true(_crop.check_farm_links_of(slot), "which is canonical again")


func test_a_boundary_with_no_eligibility_crossing_refreshes_nothing() -> void:
	"""Zero crossings must refresh NOTHING: a blanket daily repair would hide a skipped refresh."""
	_hive(HIVE_TILE_X, PLOT_TILE_Z, 1)
	var slot: int = _plot(PLOT_TILE_X, PLOT_TILE_Z)
	_hive(SECOND_HIVE_TILE_X, PLOT_TILE_Z, 1)
	var day: CropWeatherScript.DayResult = _crop.run_day(_midnight_of(2), 0)
	assert_true(day.ok, "the midnight commits")
	assert_equal(day.farm_links_refreshed, 0, "and refreshed nothing")
	assert_false(_crop.check_farm_links_of(slot), "so the stale slice is still stale")


func test_destroying_a_plot_clears_its_slice_before_the_row_can_be_reused() -> void:
	"""Ruling §3: the owner lifecycle clears its slice "including on typed-slot reuse"."""
	_hive(HIVE_TILE_X, PLOT_TILE_Z, 1)
	var slot: int = _plot(PLOT_TILE_X, PLOT_TILE_Z)
	var ref: Vector2i = _crop.farming().ref_of(slot)
	assert_equal(_pollination(slot, CROP_BEANS).value, POLLINATION_ONE_HIVE, "one hive is linked")
	assert_true(_crop.destroy_plot(ref).ok, "the plot is destroyed through the join")
	var link: OrchardHiveScript.OpResult = _ecology.orchard_hive().farm_link_at(slot, 0)
	assert_true(link.ok, "the slice is readable")
	assert_equal(link.ref, EntityDirectoryScript.NULL_REF, "and its first entry is the null ref")


func test_destroying_a_plot_through_the_store_alone_is_refused_by_the_join() -> void:
	"""A stale reference refuses instead of clearing whatever row it happens to point at."""
	var slot: int = _plot(PLOT_TILE_X, PLOT_TILE_Z)
	var ref: Vector2i = _crop.farming().ref_of(slot)
	assert_true(_crop.destroy_plot(ref).ok, "the first destroy succeeds")
	var again: FarmingScript.OpResult = _crop.destroy_plot(ref)
	assert_false(again.ok, "the second is refused")
	assert_equal(again.error, &"FARM_PLOT_NOT_PRESENT", "with the store's own code")


# --- prime_day: the opening day the calendar gives no midnight ------------------------------------------

func test_a_fresh_store_reports_no_weather_until_a_day_is_opened() -> void:
	"""The cleared §4.2 row is 0.0 C and no rain, which is a store state and not a season."""
	assert_equal(_crop.weather().temperature_tenths(), 0, "the row is cleared")
	assert_false(_crop.weather().is_event_scheduled(), "and names no event")


func test_priming_day_one_writes_springs_baseline_and_takes_no_draw() -> void:
	"""Day 1 opens at 06:00 and reaches no midnight, so its own weather has to be written."""
	_seed(SEED_SUMMER_BLIGHT)
	assert_true(_crop.prime_day(1), "day 1 is opened")
	assert_equal(_crop.weather().temperature_tenths(), SPRING_TEMPERATURE_TENTHS, "spring's 12 C")
	assert_equal(_crop.weather().rain(), SPRING_RAIN, "and spring's +1200")
	assert_equal(_crop.weather().event_of(), EVENT_IDEAL_SPELL, "the forced event is scheduled")
	assert_equal(_weather_draws(), 0, "and no WEATHER draw was taken")


func test_priming_a_day_consumes_it_so_the_same_day_cannot_be_run_twice() -> void:
	"""The primed day shares the daily latch: opening day 1 does not open day 2 as well."""
	assert_true(_crop.prime_day(1), "day 1 is opened")
	assert_false(_crop.prime_day(1), "and cannot be opened again")
	assert_equal(_crop.last_refusal(), &"CROP_WEATHER_DAY_ALREADY_RUN", "with the replay code")
	assert_true(_run_day(2).ok, "while day 2's own midnight still runs")


func test_priming_refuses_a_day_before_the_calendar_starts() -> void:
	"""Day 0 names no calendar day and is refused rather than treated as day 1."""
	assert_false(_crop.prime_day(0), "day 0 does not exist")
	assert_equal(_crop.last_refusal(), &"INVALID_ABSOLUTE_DAY", "and the refusal names it")


# --- composition and clearing -----------------------------------------------------------------------

func test_the_stage_shares_the_ecologys_directory_and_hives() -> void:
	"""One directory validates every reference, and the hives are ARCH-SYS-005's own rows."""
	assert_true(_crop.directory() == _ecology.directory(), "one entity directory")
	assert_true(_crop.orchard_hive() == _ecology.orchard_hive(), "one orchard and hive store")
	assert_true(_crop.farming().directory() == _ecology.directory(), "the crop store shares it")
	assert_true(_crop.rng() == _rng, "and one ARCH-RNG-002 stream set")


func test_clear_empties_the_crop_and_weather_stores_and_drops_both_latches() -> void:
	"""A cleared stage is one settlement's state; the borrowed ecology is NOT cleared with it."""
	_plot(PLOT_TILE_X, PLOT_TILE_Z)
	_orchard(60, 60, 1)
	assert_true(_run_day(2).ok, "a day runs")
	assert_true(_crop.run_hour(_midnight_of(2)).ok, "and an hour")
	_crop.clear()
	assert_equal(_crop.farming().count(), 0, "the crop store is emptied")
	assert_equal(_crop.weather().event_of(), EVENT_NONE, "the weather row is cleared")
	assert_equal(_crop.last_day_run(), 0, "the day latch is dropped")
	assert_equal(_crop.last_hour_tick(), -1, "the hour latch is dropped")
	assert_equal(_crop.last_scheduled_season(), -1, "the season latch is dropped")
	assert_equal(_ecology.orchard_hive().orchard_count(), 1,
		"and the borrowed ecology keeps its own rows")


func test_a_day_with_no_plots_and_no_orchards_honestly_does_nothing() -> void:
	"""A fresh settlement has no world generator, so the stage commits a day and changes nobody."""
	var day: CropWeatherScript.DayResult = _run_day(2)
	assert_true(day.ok, "the day commits")
	assert_equal(day.plots_moistened, 0, "no plot took moisture")
	assert_equal(day.orchards_advanced, 0, "no orchard advanced")
	assert_equal(day.plots_blighted, 0, "and nothing was blighted")


func test_a_preflight_refusal_advances_nothing_at_all_and_can_be_retried() -> void:
	"""Ruling §4.1: a scheduling refusal is a failure with a diagnostic, not a half-run day.

	BEHAVIOUR CHANGED DELIBERATELY (decision 0055). This test previously asserted that an
	unseeded summer draw still CONSUMED day 13 -- the latch was raised before the steps, so a
	refusal half way left the earlier steps committed and the day unrepeatable. The ruling forbids
	exactly that: "Preflight required season identity, RNG and catalog inputs before a boundary
	can partially advance", and "a scheduling refusal is a failure requiring a diagnostic, not
	permission to clear some state and publish an apparently completed tick." So the RNG is now
	proved BEFORE anything commits: the day is untouched, `last_day_run()` still reports 12, the
	moisture the eleven spring days accumulated is unchanged, and seeding the world lets the very
	same day 13 run to completion.
	"""
	var slot: int = _plot(PLOT_TILE_X, PLOT_TILE_Z)
	_run_days(2, 12)
	var moisture_before: int = _moisture(slot)
	assert_true(moisture_before > 0, "eleven spring days have moved the plot's moisture")
	var refused: CropWeatherScript.DayResult = _run_day(13)
	assert_false(refused.ok, "the unseeded summer draw refuses")
	assert_equal(refused.error, RngScript.REFUSE_NOT_SEEDED, "carrying the stream's own reason")
	assert_equal(refused.plots_moistened, 0, "and no count survives on the refused result")
	assert_equal(refused.absolute_day, 0, "not even the day it refused for")
	assert_equal(_crop.last_day_run(), 12, "day 13 was not consumed by a preflight refusal")
	assert_equal(_moisture(slot), moisture_before, "and no step moved the plot's moisture")
	_seed(20260911)
	var retried: CropWeatherScript.DayResult = _run_day(13)
	assert_true(retried.ok, "the very same day runs once the stream is seeded (%s)" % retried.error)
	assert_equal(retried.absolute_day, 13, "for the day that was refused")
	assert_equal(_crop.last_day_run(), 13, "and only now is it consumed")


# --- ruling 2026-09-11 §4.1/§4.3: season identity, the mussel closure and the exact fixtures ------
#
# EVERY TICK BELOW IS THE RULING'S OWN, TYPED IN AS A LITERAL and then checked against
# `(D-1)*18000-4500` computed independently by `_midnight_of()`. If the two ever disagree the
# fixture fails rather than quietly testing some other midnight.

## Ruling §4.3's required exact checks, transcribed: summer day 3/6/8/9 and autumn day 1/3/6.
const TICK_SUMMER_DAY_3: int = 247500
const TICK_SUMMER_DAY_6: int = 301500
const TICK_SUMMER_DAY_8: int = 337500
const TICK_SUMMER_DAY_9: int = 355500
const TICK_AUTUMN_DAY_1: int = 427500
const TICK_AUTUMN_DAY_3: int = 463500
const TICK_AUTUMN_DAY_6: int = 517500

## The absolute days those ticks open, so each fixture states both halves of its own identity.
const DAY_SUMMER_1: int = 13
const DAY_SUMMER_3: int = 15
const DAY_SUMMER_6: int = 18
const DAY_SUMMER_8: int = 20
const DAY_SUMMER_9: int = 21
const DAY_AUTUMN_1: int = 25
const DAY_AUTUMN_3: int = 27
const DAY_AUTUMN_6: int = 30

## Ruling §4.2's absolute season index for year 1, `floor((absolute_day-1)/12)`.
const ABS_SPRING: int = 0
const ABS_SUMMER: int = 1
const ABS_AUTUMN: int = 2

## `catalog.gd`'s compiled HabitatType ids, ascending ASCII: coast, lake, river.
const HABITAT_COAST: int = 0
## §5.4 lists herring/mackerel/mussel under Coast, so the mussel is species index 2 there.
const SPECIES_INDEX_MUSSEL: int = 2
## Three opaque ItemDefinition ids for the fixture's coast habitat; §5.4's tables are not keyed
## on them, and every closure assertion below names the stock by its row.
const COAST_ITEM_IDS: Array[int] = [30, 31, 32]

## §5.10's baselines, transcribed: summer 22°C and autumn 10°C, in tenths.
const SUMMER_BASELINE_TENTHS: int = 220
const AUTUMN_BASELINE_TENTHS: int = 100


func _mussel_row() -> int:
	"""Create one §5.4 coast habitat and return the FishStock row of its mussel bed."""
	var made: FishingScript.OpResult = _ecology.fishing().create_habitat(
		HABITAT_COAST, EntityDirectoryScript.NULL_REF,
		PackedInt32Array(COAST_ITEM_IDS), 0, 0, 0)
	assert_true(made.ok, "the fixture coast habitat must be created (%s)" % made.error)
	var row: IntMathScript.IntResult = _ecology.fishing().stock_row_of(
		made.ref, SPECIES_INDEX_MUSSEL)
	assert_true(row.ok, "and must carry a mussel stock (%s)" % row.error)
	return row.value


func _arm_event(absolute_season: int, event: int) -> void:
	"""Advance the WEATHER stream until its NEXT draw selects `event` in that season.

	Ruling §4.3: "Use injected valid event fixtures for these checks, not a claim that the
	production seed necessarily selects blight." The injection goes through the module's own
	published roll-to-row map, so only an event §5.10 admits in that season can ever be armed,
	and every caller additionally asserts which event the boundary actually scheduled.
	"""
	var season: int = absolute_season % 4
	var weather: WeatherScript = _crop.weather()
	for attempt: int in 4096:
		var state: int = _rng.state_of(RngScript.STREAM_WEATHER).value
		var peek: int = RngScript.next_u32_from(state).value \
			% weather.weight_sum_of(season).value
		if weather.event_for_roll(season, peek).value == event:
			return
		_rng.draw(RngScript.STREAM_WEATHER)
	fail("no draw within 4096 attempts selects event %d in season %d" % [event, season])


func _closed(row: int) -> bool:
	"""The §4.2 `closed` EVENT bit of one stock, which ruling §4.1 gives ARCH-SYS-006 to write."""
	return _ecology.fishing().is_event_closed(row)


func _open_summer_with_blight(row: int) -> void:
	"""Seed, run spring, and open summer with an injected blight on days 6-8. `row` is asserted."""
	_seed(SEED_SUMMER_BLIGHT)
	_run_days(2, DAY_SUMMER_1 - 1)
	_arm_event(ABS_SUMMER, EVENT_BLIGHT)
	var summer: CropWeatherScript.DayResult = _run_day(DAY_SUMMER_1)
	assert_true(summer.ok, "summer day 1 commits (%s)" % summer.error)
	assert_equal(summer.event_scheduled, EVENT_BLIGHT, "with the injected blight scheduled")
	assert_equal(summer.weather_draws, 1, "on exactly one WEATHER draw")
	assert_false(_closed(row), "and the closure does not begin before the event does")


func test_the_ruling_fixture_ticks_are_the_offset_calendars_own_midnights() -> void:
	"""Ruling §4.3: "a midnight at absolute day D is `tick=(D-1)*18000-4500`"."""
	assert_equal(_midnight_of(DAY_SUMMER_3), TICK_SUMMER_DAY_3, "summer day 3 is tick 247500")
	assert_equal(_midnight_of(DAY_SUMMER_6), TICK_SUMMER_DAY_6, "summer day 6 is tick 301500")
	assert_equal(_midnight_of(DAY_SUMMER_8), TICK_SUMMER_DAY_8, "summer day 8 is tick 337500")
	assert_equal(_midnight_of(DAY_SUMMER_9), TICK_SUMMER_DAY_9, "summer day 9 is tick 355500")
	assert_equal(_midnight_of(DAY_AUTUMN_1), TICK_AUTUMN_DAY_1, "autumn day 1 is tick 427500")
	assert_equal(_midnight_of(DAY_AUTUMN_3), TICK_AUTUMN_DAY_3, "autumn day 3 is tick 463500")
	assert_equal(_midnight_of(DAY_AUTUMN_6), TICK_AUTUMN_DAY_6, "autumn day 6 is tick 517500")


func test_summer_day_six_tick_301500_closes_the_mussel_harvest() -> void:
	"""Ruling §4.3: "summer day 6 tick 301500 closes mussels before planning"."""
	var row: int = _mussel_row()
	_open_summer_with_blight(row)
	_run_days(DAY_SUMMER_1 + 1, DAY_SUMMER_6 - 1)
	assert_false(_closed(row), "days 2-5 of the summer are still open")
	var day: CropWeatherScript.DayResult = _crop.run_day(TICK_SUMMER_DAY_6, 0)
	assert_true(day.ok, "the boundary at tick 301500 commits (%s)" % day.error)
	assert_equal(day.boundary_tick, TICK_SUMMER_DAY_6, "it is exactly tick 301500")
	assert_equal(day.absolute_day, DAY_SUMMER_6, "opening absolute day 18")
	assert_equal(day.season, SUMMER, "which is summer")
	assert_equal(day.season_day, 6, "on its sixth local day")
	assert_equal(day.absolute_season, ABS_SUMMER, "absolute season 1")
	assert_true(day.mussel_event_closed, "and the ruled predicate is true")
	assert_equal(day.mussel_stocks_written, 1, "one present mussel stock was written")
	assert_true(_closed(row), "so the stock's event bit is closed WHEN THE BOUNDARY RETURNS")
	assert_true(_ecology.fishing().is_harvest_closed(row, SUMMER, 6), "and no harvest is allowed")


func test_summer_day_eight_tick_337500_remains_closed() -> void:
	"""Ruling §4.3: "summer day 8 tick 337500 remains closed"."""
	var row: int = _mussel_row()
	_open_summer_with_blight(row)
	_run_days(DAY_SUMMER_1 + 1, DAY_SUMMER_8 - 1)
	assert_true(_closed(row), "day 7 inside the window is already closed")
	var day: CropWeatherScript.DayResult = _crop.run_day(TICK_SUMMER_DAY_8, 0)
	assert_true(day.ok, "the boundary at tick 337500 commits (%s)" % day.error)
	assert_equal(day.absolute_day, DAY_SUMMER_8, "opening absolute day 20")
	assert_equal(day.season_day, 8, "summer's eighth day, the last of the three")
	assert_true(day.mussel_event_closed, "the closure still stands")
	assert_true(_closed(row), "on the last day of the half-open window")


func test_summer_day_nine_tick_355500_reopens_the_mussel_harvest() -> void:
	"""Ruling §4.3: "day 9 tick 355500 reopens", the day after the half-open window ends."""
	var row: int = _mussel_row()
	_open_summer_with_blight(row)
	_run_days(DAY_SUMMER_1 + 1, DAY_SUMMER_9 - 1)
	assert_true(_closed(row), "day 8 closed the bed")
	var day: CropWeatherScript.DayResult = _crop.run_day(TICK_SUMMER_DAY_9, 0)
	assert_true(day.ok, "the boundary at tick 355500 commits (%s)" % day.error)
	assert_equal(day.absolute_day, DAY_SUMMER_9, "opening absolute day 21")
	assert_equal(day.season_day, 9, "summer's ninth day")
	assert_false(day.mussel_event_closed, "the ruled predicate is false the day after expiry")
	assert_equal(day.mussel_stocks_written, 1, "and the bit is WRITTEN false, not merely skipped")
	assert_false(_closed(row), "so the bed reopens without anyone reopening it by hand")
	assert_false(_ecology.fishing().is_harvest_closed(row, SUMMER, 9), "and harvest is allowed")


func test_summer_day_three_tick_247500_discloses_the_forecast() -> void:
	"""Ruling §4.3: "Summer day 3 forecast is tick 247500"."""
	var row: int = _mussel_row()
	_open_summer_with_blight(row)
	_run_days(DAY_SUMMER_1 + 1, DAY_SUMMER_3 - 1)
	var day: CropWeatherScript.DayResult = _crop.run_day(TICK_SUMMER_DAY_3, 0)
	assert_true(day.ok, "the boundary at tick 247500 commits (%s)" % day.error)
	assert_equal(day.absolute_day, DAY_SUMMER_3, "opening absolute day 15")
	assert_equal(day.season_day, 3, "three days before §5.10's day-6 start")
	assert_equal(day.forecast_event, EVENT_BLIGHT, "the coming blight is disclosed")
	assert_equal(day.forecast_absolute_season, ABS_SUMMER, "carrying absolute season 1")
	assert_equal(_crop.weather().forecast_start_day(), 6, "with its start day")
	assert_false(day.mussel_event_closed, "a DISCLOSED event closes nothing yet")
	assert_false(_closed(row), "the bed is open three days before the blight arrives")


func test_autumn_day_six_tick_517500_permits_mussels_during_a_blight() -> void:
	"""Ruling §4.3: "Autumn day 6 tick 517500 permits mussels during blight"."""
	var row: int = _mussel_row()
	_open_summer_with_blight(row)
	_run_days(DAY_SUMMER_1 + 1, DAY_AUTUMN_1 - 1)
	_arm_event(ABS_AUTUMN, EVENT_BLIGHT)
	var autumn: CropWeatherScript.DayResult = _run_day(DAY_AUTUMN_1)
	assert_equal(autumn.event_scheduled, EVENT_BLIGHT, "autumn's own blight is injected")
	_run_days(DAY_AUTUMN_1 + 1, DAY_AUTUMN_6 - 1)
	var day: CropWeatherScript.DayResult = _crop.run_day(TICK_AUTUMN_DAY_6, 0)
	assert_true(day.ok, "the boundary at tick 517500 commits (%s)" % day.error)
	assert_equal(day.absolute_day, DAY_AUTUMN_6, "opening absolute day 30")
	assert_equal(day.absolute_season, ABS_AUTUMN, "absolute season 2")
	assert_true(_crop.weather().is_blight_active(ABS_AUTUMN, 6),
		"the autumn blight IS active and damages crops")
	assert_false(day.mussel_event_closed, "yet §5.10 closes the mussel harvest in SUMMER only")
	assert_false(_closed(row), "so the bed stays open through an autumn blight")


func test_autumn_day_three_tick_463500_carries_absolute_season_two() -> void:
	"""Ruling §4.3: "autumn day 3 forecast at 463500 carries absolute season 2"."""
	var row: int = _mussel_row()
	_open_summer_with_blight(row)
	_run_days(DAY_SUMMER_1 + 1, DAY_AUTUMN_1 - 1)
	_arm_event(ABS_AUTUMN, EVENT_BLIGHT)
	assert_equal(_run_day(DAY_AUTUMN_1).event_scheduled, EVENT_BLIGHT, "autumn blight injected")
	_run_days(DAY_AUTUMN_1 + 1, DAY_AUTUMN_3 - 1)
	var day: CropWeatherScript.DayResult = _crop.run_day(TICK_AUTUMN_DAY_3, 0)
	assert_true(day.ok, "the boundary at tick 463500 commits (%s)" % day.error)
	assert_equal(day.absolute_day, DAY_AUTUMN_3, "opening absolute day 27")
	assert_equal(day.forecast_event, EVENT_BLIGHT, "autumn's blight is disclosed")
	assert_equal(day.forecast_absolute_season, 2, "carrying absolute season 2, as ruled")
	assert_equal(_crop.weather().forecast_absolute_season(), 2, "and the column agrees")
	assert_false(_closed(row), "and an autumn disclosure closes no mussel bed")


func test_tick_427500_does_not_reuse_the_summer_schedule() -> void:
	"""Ruling §4.3: "At tick 427500 entering autumn day 1, do not reuse the summer schedule"."""
	var row: int = _mussel_row()
	_open_summer_with_blight(row)
	_run_days(DAY_SUMMER_1 + 1, DAY_AUTUMN_1 - 1)
	assert_equal(_crop.last_scheduled_season(), ABS_SUMMER, "summer holds the latch")
	_arm_event(ABS_AUTUMN, EVENT_BLIGHT)
	var day: CropWeatherScript.DayResult = _crop.run_day(TICK_AUTUMN_DAY_1, 0)
	assert_true(day.ok, "the boundary at tick 427500 commits (%s)" % day.error)
	assert_equal(day.absolute_day, DAY_AUTUMN_1, "opening absolute day 25")
	assert_equal(day.absolute_season, ABS_AUTUMN, "absolute season 2")
	assert_equal(day.completed_absolute_season, ABS_SUMMER,
		"while the ELAPSED calendar the completed day settles under is still summer, absolute 1")
	assert_equal(day.completed_day, DAY_AUTUMN_1 - 1, "which is absolute day 24")
	assert_equal(day.event_ended, EVENT_NONE,
		"summer's blight had already expired inside summer, so nothing is carried across")
	assert_false(_crop.weather().is_event_active(ABS_SUMMER, 6),
		"and the summer window is dead even for the day it used to cover")
	assert_equal(day.weather_draws, 1, "and autumn takes its OWN single draw")
	assert_equal(day.event_scheduled, EVENT_BLIGHT, "for its own injected event")
	assert_equal(_crop.last_scheduled_season(), ABS_AUTUMN, "the latch has moved to autumn")
	assert_true(_crop.weather().is_season_scheduled(ABS_AUTUMN), "and names autumn alone")
	assert_false(_crop.weather().is_season_scheduled(ABS_SUMMER), "summer is behind it")


func test_the_hour_before_tick_427500_still_uses_summer_climate() -> void:
	"""Ruling §4.3: "the preceding hour still uses summer climate" at the autumn crossing."""
	var row: int = _mussel_row()
	_open_summer_with_blight(row)
	_run_days(DAY_SUMMER_1 + 1, DAY_AUTUMN_1 - 1)
	assert_equal(_crop.weather().temperature_tenths(), SUMMER_BASELINE_TENTHS,
		"the row holds summer's 22°C after summer's last midnight")
	var hour: CropWeatherScript.HourResult = _crop.run_hour(TICK_AUTUMN_DAY_1)
	assert_true(hour.ok, "the midnight tick is an hour crossing too (%s)" % hour.error)
	assert_equal(hour.tick, TICK_AUTUMN_DAY_1, "and it is tick 427500")
	assert_equal(hour.temperature_tenths, SUMMER_BASELINE_TENTHS,
		"the ELAPSED hour integrates at summer's climate, because the day leg has not run")
	_arm_event(ABS_AUTUMN, EVENT_BLIGHT)
	var day: CropWeatherScript.DayResult = _crop.run_day(TICK_AUTUMN_DAY_1, 0)
	assert_true(day.ok, "then the daily leg runs (%s)" % day.error)
	assert_equal(day.elapsed_hour_tick, TICK_AUTUMN_DAY_1,
		"which reports the hour already consumed, proving the order was not reversed")
	assert_equal(_crop.weather().temperature_tenths(), AUTUMN_BASELINE_TENTHS,
		"and only now does the row hold autumn's 10°C")


func test_the_completed_days_blight_settles_before_the_new_days_closure() -> void:
	"""Ruling §4.1's order: completed-day crop effects, THEN the new day's weather and closure."""
	var row: int = _mussel_row()
	_open_summer_with_blight(row)
	_run_days(DAY_SUMMER_1 + 1, 17)
	var slot: int = _growing(PLOT_TILE_X, PLOT_TILE_Z, CROP_CABBAGE, 17, SUMMER, 5)
	_run_days(DAY_SUMMER_6, DAY_SUMMER_8)
	var damaged: int = _health(slot)
	assert_true(damaged < FarmingScript.HEALTH_MAX, "blighted days have damaged the plot")
	var day: CropWeatherScript.DayResult = _crop.run_day(TICK_SUMMER_DAY_9, 0)
	assert_true(day.ok, "summer day 9 commits (%s)" % day.error)
	assert_true(day.blight_active,
		"the COMPLETED day 8 was still inside the window, so its damage settles")
	assert_equal(day.plots_blighted, 1, "one plot took the completed day's damage")
	assert_true(_health(slot) < damaged, "and its health fell again")
	assert_false(day.mussel_event_closed,
		"while the NEW day 9 is outside the window and reopens the bed in the same boundary")
	assert_false(_closed(row), "the two legs read different days and do not contradict")


func test_the_closure_reads_the_schedule_the_same_boundary_just_made() -> void:
	"""Ruling §4.1's order: schedule/disclose the new day's weather ONCE, THEN set the bit.

	The two steps are separated by driving the stage to a NON-CONSECUTIVE boundary. The day latch
	only requires the day to advance, so spring can be run to its end and the very next boundary
	taken at summer day 6 -- the first summer midnight this stage sees, which therefore BOTH
	schedules the season's event and falls inside that event's window. If the closure step ran
	before the schedule step it would still be looking at spring's ideal spell, which belongs to
	another absolute season and closes nothing, and the bed would stay open.
	"""
	var row: int = _mussel_row()
	_seed(SEED_SUMMER_BLIGHT)
	_run_days(2, 12)
	assert_equal(_crop.last_scheduled_season(), ABS_SPRING, "spring alone has been scheduled")
	assert_false(_closed(row), "and the bed is open")
	_arm_event(ABS_SUMMER, EVENT_BLIGHT)
	var day: CropWeatherScript.DayResult = _crop.run_day(TICK_SUMMER_DAY_6, 0)
	assert_true(day.ok, "the jump straight to summer day 6 commits (%s)" % day.error)
	assert_equal(day.absolute_day, DAY_SUMMER_6, "opening absolute day 18")
	assert_equal(day.event_scheduled, EVENT_BLIGHT, "this boundary scheduled the blight")
	assert_equal(day.weather_draws, 1, "on its own single draw")
	assert_true(day.mussel_event_closed,
		"and the closure read THAT schedule, not the spring event the row held on entry")
	assert_true(_closed(row), "so the bed is closed by the same boundary that scheduled it")


func test_a_duplicate_boundary_call_changes_no_closure() -> void:
	"""Ruling §4.3: "Repeat across ... duplicate-boundary calls"."""
	var row: int = _mussel_row()
	_open_summer_with_blight(row)
	_run_days(DAY_SUMMER_1 + 1, DAY_SUMMER_6)
	assert_true(_closed(row), "summer day 6 closed the bed")
	var replay: CropWeatherScript.DayResult = _crop.run_day(TICK_SUMMER_DAY_6, 0)
	assert_false(replay.ok, "the same midnight refuses a second time")
	assert_equal(replay.error, CropWeatherScript.REFUSE_DAY_ALREADY_RUN, "as an already-run day")
	assert_equal(replay.mussel_stocks_written, 0, "a refusal carries no count")
	assert_true(_closed(row), "and the bed is neither reopened nor written twice")
	assert_equal(_crop.last_day_run(), DAY_SUMMER_6, "the day stays consumed")


func test_hours_without_a_boundary_never_move_the_closure() -> void:
	"""Ruling §4.3: "Repeat across ... pause". A paused clock raises no midnight, and the bit
	must not drift across the hours that do elapse."""
	var row: int = _mussel_row()
	_open_summer_with_blight(row)
	_run_days(DAY_SUMMER_1 + 1, DAY_SUMMER_6)
	assert_true(_closed(row), "the bed is closed on summer day 6")
	for step: int in range(1, 13):
		var hour: CropWeatherScript.HourResult = _crop.run_hour(
			TICK_SUMMER_DAY_6 + step * TICKS_PER_HOUR)
		assert_true(hour.ok, "hour %d of the day runs (%s)" % [step, hour.error])
	assert_true(_closed(row), "twelve hours later the bed is still exactly as the boundary left it")
	assert_equal(_crop.last_day_run(), DAY_SUMMER_6, "and no new day was opened")


func test_the_closure_repeats_in_the_following_year() -> void:
	"""Ruling §4.3: "Repeat across years". Year 2's summer is a DIFFERENT absolute season."""
	var row: int = _mussel_row()
	_open_summer_with_blight(row)
	_run_days(DAY_SUMMER_1 + 1, 48)
	assert_false(_closed(row), "the bed is open at the end of year 1")
	assert_equal(_crop.last_scheduled_season(), 3, "winter of year 1 holds the latch")
	_run_days(49, 60)
	assert_equal(_crop.last_scheduled_season(), 4, "year 2's spring is absolute season 4")
	_arm_event(5, EVENT_BLIGHT)
	var summer: CropWeatherScript.DayResult = _run_day(61)
	assert_equal(summer.absolute_season, 5, "year 2's summer is absolute season 5")
	assert_equal(summer.event_scheduled, EVENT_BLIGHT, "with an injected blight")
	_run_days(62, 65)
	var day: CropWeatherScript.DayResult = _crop.run_day(1165500, 0)
	assert_true(day.ok, "year 2's summer day 6 commits (%s)" % day.error)
	assert_equal(day.absolute_day, 66, "which is absolute day 66")
	assert_equal(day.boundary_tick, _midnight_of(66), "at `(66-1)*18000-4500`")
	assert_true(day.mussel_event_closed, "and closes the bed a second year running")
	assert_true(_closed(row), "which the repeating 0-3 ordinal alone could not have scheduled")


func test_the_scheduled_once_latch_has_exactly_one_owner() -> void:
	"""Ruling §4.2: the CropWeather latch is REPLACED by the Weather column, in one migration."""
	_seed(SEED_SUMMER_BLIGHT)
	assert_equal(_crop.last_scheduled_season(), CropWeatherScript.NO_SEASON_SCHEDULED,
		"a fresh stage has scheduled no season")
	assert_equal(CropWeatherScript.NO_SEASON_SCHEDULED, WeatherScript.ABSOLUTE_SEASON_NONE,
		"and its empty value IS the store's, not a second opinion about what empty means")
	for day: int in range(2, 40):
		var result: CropWeatherScript.DayResult = _run_day(day)
		assert_true(result.ok, "day %d commits (%s)" % [day, result.error])
		assert_equal(_crop.last_scheduled_season(), _crop.weather().scheduled_absolute_season(),
			"on day %d the stage reports exactly the Weather column" % day)
	_crop.clear()
	assert_equal(_crop.last_scheduled_season(), CropWeatherScript.NO_SEASON_SCHEDULED,
		"and clear() drops the one latch there is")


func test_the_two_stores_derive_the_same_absolute_season() -> void:
	"""`weather.gd` and `farming.gd` both compute `floor((day-1)/12)`; four years of agreement."""
	for day: int in range(1, 193):
		var weather_view: IntMathScript.IntResult = _crop.weather().absolute_season_of_day(day)
		var farm_view: IntMathScript.IntResult = _crop.farming().absolute_season_of_day(day)
		assert_true(weather_view.ok and farm_view.ok, "day %d has a season in both" % day)
		assert_equal(weather_view.value, farm_view.value,
			"the two stores agree on absolute day %d" % day)
	assert_equal(_crop.weather().absolute_season_of_day(192).value, 15,
		"four years is sixteen absolute seasons, numbered 0-15")


func test_the_mussel_closure_is_written_for_no_other_species() -> void:
	"""Ruling §4.1 reserves the event bit for one cause, and this stage writes one species."""
	var mussel: int = _mussel_row()
	var herring: IntMathScript.IntResult = _ecology.fishing().stock_row_of(
		_ecology.fishing().stock_habitat_ref_of(mussel), 0)
	assert_true(herring.ok, "the same habitat carries a herring stock (%s)" % herring.error)
	_open_summer_with_blight(mussel)
	_run_days(DAY_SUMMER_1 + 1, DAY_SUMMER_6)
	assert_true(_closed(mussel), "the mussel bed closes")
	assert_false(_closed(herring.value), "and the herring stock beside it does not")
	assert_true(_ecology.fishing().population_milli_of(herring.value).ok,
		"the herring stock is still present and readable")
	assert_false(_ecology.fishing().is_harvest_closed(herring.value, SUMMER, 6),
		"and its harvest is still permitted")


func test_a_world_with_no_mussel_bed_writes_nothing_and_is_not_an_error() -> void:
	"""Zero present mussel stocks is an answer, not a refusal."""
	_seed(SEED_SUMMER_BLIGHT)
	_run_days(2, DAY_SUMMER_1 - 1)
	_arm_event(ABS_SUMMER, EVENT_BLIGHT)
	assert_equal(_run_day(DAY_SUMMER_1).event_scheduled, EVENT_BLIGHT, "blight is injected")
	_run_days(DAY_SUMMER_1 + 1, DAY_SUMMER_6 - 1)
	var day: CropWeatherScript.DayResult = _crop.run_day(TICK_SUMMER_DAY_6, 0)
	assert_true(day.ok, "the boundary still commits (%s)" % day.error)
	assert_true(day.mussel_event_closed, "the ruled predicate is still true")
	assert_equal(day.mussel_stocks_written, 0, "but no stock existed to write it to")


func test_a_season_identity_that_the_clock_contradicts_refuses_the_boundary() -> void:
	"""Ruling §4.1's preflight: season identity is proved before anything may advance.

	`preflight_refusal_for()` takes the season as an ARGUMENT, so the comparison
	`absolute_season % 4 == season` can actually be made to fail here -- inside `run_day_into()`
	both sides come from one decoded tick and can never disagree with each other.
	"""
	_seed(SEED_SUMMER_BLIGHT)
	_run_days(2, 12)
	var before: int = _crop.last_day_run()
	assert_equal(_crop.preflight_refusal_for(DAY_SUMMER_6, SUMMER),
		CropWeatherScript.REFUSE_NONE, "absolute day 18 really is a summer day and preflights")
	for wrong: int in [SPRING, AUTUMN, WINTER]:
		assert_equal(_crop.preflight_refusal_for(DAY_SUMMER_6, wrong),
			CropWeatherScript.REFUSE_SEASON_IDENTITY_MISMATCH,
			"season %d contradicts absolute day 18's own identity and is refused" % wrong)
	assert_equal(_crop.preflight_refusal_for(0, SPRING),
		WeatherScript.REFUSE_INVALID_SEASON_DAY, "day 0 precedes the calendar entirely")
	assert_equal(_crop.last_day_run(), before, "and no preflight consumed a day")
	var not_a_boundary: CropWeatherScript.DayResult = _crop.run_day(TICK_SUMMER_DAY_6 + 1, 0)
	assert_false(not_a_boundary.ok, "a tick that is not a midnight refuses")
	assert_equal(not_a_boundary.error, CropWeatherScript.REFUSE_NOT_DAY_BOUNDARY, "as such")
	assert_equal(_crop.last_day_run(), before, "and consumed no day either")


func test_no_stated_event_ever_covers_the_last_day_of_its_season() -> void:
	"""Why the completed-day blight leg can be reasoned about across a season crossing.

	A crossing always settles season day 12, and §5.10 gives no event a window that reaches it:
	the latest start is early frost's day 10 with a two-day duration, ending on day 11. That is
	what makes "did the elapsed leg read the elapsed season?" unobservable for BLIGHT specifically,
	and the invariant is asserted here so a later table change fails a test instead of silently
	making the elapsed/new distinction load-bearing with nothing watching it. The distinction
	itself is still checked: `DayResult.completed_absolute_season` is derived from `completed_day`
	and asserted to differ from `absolute_season` at tick 427500.
	"""
	var weather: WeatherScript = _crop.weather()
	for event: int in WeatherScript.EVENT_COUNT:
		var start: int = weather.start_day_of(event).value
		var duration: int = weather.duration_days_of(event).value
		assert_true(start + duration - 1 < WeatherScript.DAYS_PER_SEASON,
			"§5.10 row %d ends on day %d, before a season's twelfth" % [event,
			start + duration - 1])
		assert_false(weather.is_season_day(start + duration - 1) and start + duration - 1 == 12,
			"row %d must not reach the day a season crossing settles" % event)
