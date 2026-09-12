extends "res://test/framework/test_case.gd"
## Coverage for the Weather store and GDD §5.10's seasons, events, moisture and daylight rules.
##
## Every expected number below is restated from the specification, never read back out of the
## module under test: §4.2's eight-column single row and systems_architecture.md §2.2's matching
## width, §5.10's four-row season table and seven-row event table transcribed independently here,
## the planner's ruled roll-to-row map encoded as its own data, BAL-PROBE-001's published
## moisture column, and ARCH-RNG-002's stated draw discipline.
##
## THE ROLL MAP IS TEST DATA, NOT A RE-DERIVATION. MAP_* below are the ruling's own inclusive
## intervals, typed in by hand. Recomputing them from EVENT_WEIGHT would only prove the module
## agrees with itself, so the intervals are asserted as literals and every boundary is probed on
## both sides.
##
## THE STORED IDS AND THE SELECTION ORDER ARE SEPARATE, and this file keeps them separate.
## `Weather.event` is an `EventDefinition` id, numbered by GDD §4.2's closing paragraph from the
## domain's ascending ASCII keys: blight=0, calm_days=1, drought=2, early_frost=3, hard_freeze=4,
## heavy_rain=5, ideal_spell=6, restated below from that contract. Decision 0028's ruled
## selection traversal is §5.10's printed order and is unchanged, so every MAP_* interval below
## still names the same event IDENTITY it always did -- the symbols in those fixtures did not
## move, only the numbers they stand for.

const Weather := preload("res://scripts/core/weather.gd")
const Rng := preload("res://scripts/core/rng.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

## GDD §4.3 Season, restated here rather than read from catalog.gd.
const SPRING: int = 0
const SUMMER: int = 1
const AUTUMN: int = 2
const WINTER: int = 3

## REQ-SET-006: "one season as 12 days".
const DAYS_PER_SEASON: int = 12

## Ruling 2026-09-11 §4.2's ABSOLUTE season index, `floor((absolute_day-1)/12)`: not §4.3's
## repeating 0-3 ordinal. Year 1's four seasons happen to be 0-3, which is exactly why they are
## named separately here -- a fixture that used SPRING where an absolute season is wanted would
## pass for one year and silently mean "spring of year 1" forever after. ABS_SPRING_Y2 is 4, the
## first index at which the two spellings visibly disagree, and it is used to prove they do.
const ABS_SPRING: int = 0
const ABS_SUMMER: int = 1
const ABS_AUTUMN: int = 2
const ABS_WINTER: int = 3
const ABS_SPRING_Y2: int = 4
const ABS_SUMMER_Y2: int = 5
const ABS_AUTUMN_Y2: int = 6
## The empty value of both I64 identity columns. Not a season, so every operation refuses it.
const ABS_NONE: int = -1

## The compiled EventDefinition ids: the ascending ASCII order of §5.10's seven keys.
const BLIGHT: int = 0
const CALM: int = 1
const DROUGHT: int = 2
const EARLY_FROST: int = 3
const HARD_FREEZE: int = 4
const HEAVY_RAIN: int = 5
const IDEAL: int = 6
const EVENT_COUNT: int = 7
const NONE: int = -1

## Decision 0028's ruled selection traversal: §5.10's printed table order, 1 Ideal spell ...
## 7 Calm days. This is a SCAN SEQUENCE, never an id.
const SELECTION_ORDER: Array[int] = [
	IDEAL, HEAVY_RAIN, DROUGHT, BLIGHT, EARLY_FROST, HARD_FREEZE, CALM,
]

## §4.2 / systems_architecture.md §2.2: eight int32 columns in exactly one row.
const ROW_COLUMNS: int = 8

## §5.10's "Weight" column, raw integers, indexed by the compiled id: blight 20, calm days 20,
## drought 50, early frost 30, hard freeze 60, heavy rain 35, ideal spell 30.
const WEIGHTS: Array[int] = [20, 20, 50, 30, 60, 35, 30]
## §5.10's "Duration" column, in days, indexed by the compiled id.
const DURATIONS: Array[int] = [3, 2, 4, 2, 3, 2, 3]
## §5.10: "start day is 6, except early frost day 10", indexed by the compiled id.
const START_DAYS: Array[int] = [6, 6, 6, 10, 6, 6, 6]

## §5.10's "Baseline temperature" column, in tenths: 12°C, 22°C, 10°C, -5°C.
const BASELINE_TEMPERATURE: Array[int] = [120, 220, 100, -50]
## §5.10's "Rain/moisture per day" column.
const BASELINE_RAIN: Array[int] = [1200, 300, 700, 0]
## §5.10's "Daylight" column: 06:00-19:00, 05:00-21:00, 07:00-18:00, 08:00-16:00.
const DAYLIGHT_START: Array[int] = [6, 5, 7, 8]
const DAYLIGHT_END: Array[int] = [19, 21, 18, 16]

## The ruled weight sums, verified independently against §5.10's weights.
const WEIGHT_SUMS: Array[int] = [85, 120, 135, 110]

## The ruled map, as flat (event, first_roll, last_roll) triples. All intervals inclusive.
const MAP_SPRING: Array[int] = [IDEAL, 0, 29, HEAVY_RAIN, 30, 64, CALM, 65, 84]
const MAP_SUMMER: Array[int] = [IDEAL, 0, 29, DROUGHT, 30, 79, BLIGHT, 80, 99, CALM, 100, 119]
const MAP_AUTUMN: Array[int] = [
	IDEAL, 0, 29, HEAVY_RAIN, 30, 64, BLIGHT, 65, 84, EARLY_FROST, 85, 114, CALM, 115, 134,
]
const MAP_WINTER: Array[int] = [IDEAL, 0, 29, HARD_FREEZE, 30, 89, CALM, 90, 109]

## §5.10's eligible-season column, as an explicit per-season list in the table's printed order.
const ELIGIBLE_SPRING: Array[int] = [IDEAL, HEAVY_RAIN, CALM]
const ELIGIBLE_SUMMER: Array[int] = [IDEAL, DROUGHT, BLIGHT, CALM]
const ELIGIBLE_AUTUMN: Array[int] = [IDEAL, HEAVY_RAIN, BLIGHT, EARLY_FROST, CALM]
const ELIGIBLE_WINTER: Array[int] = [IDEAL, HARD_FREEZE, CALM]

## BAL-PROBE-001's published moisture column for absolute days 1..17, first spring, ideal spell
## days 6-8, no summer event. Day 13 is summer day 1.
const PROBE_MOISTURE: Array[int] = [
	6000, 6600, 7200, 7800, 8400, 9600, 10000, 10000, 10000,
	10000, 10000, 10000, 9400, 8800, 8200, 7600, 7000,
]

## A fixed world seed for the draw-discipline tests. Any int32 would do; this is UI-SET-103's.
const WORLD_SEED: int = 20260905

var _weather: Weather = null


func before_each() -> void:
	"""Give every test a fresh store with an empty §4.2 row."""
	_weather = Weather.new()


func after_each() -> void:
	"""Drop the store so no test can observe another's row."""
	_weather = null


func _new_rng() -> Rng:
	"""A seeded Rng whose WEATHER stream has taken no draws yet."""
	var rng: Rng = Rng.new()
	rng.seed_world(WORLD_SEED)
	return rng


func _map_of(season: int) -> Array[int]:
	"""The ruled (event, first_roll, last_roll) triples for one season, as test data."""
	if season == SPRING:
		return MAP_SPRING
	if season == SUMMER:
		return MAP_SUMMER
	if season == AUTUMN:
		return MAP_AUTUMN
	return MAP_WINTER


func _eligible_of(season: int) -> Array[int]:
	"""§5.10's eligible rows for one season, in the table's printed order, as test data."""
	if season == SPRING:
		return ELIGIBLE_SPRING
	if season == SUMMER:
		return ELIGIBLE_SUMMER
	if season == AUTUMN:
		return ELIGIBLE_AUTUMN
	return ELIGIBLE_WINTER


# --- the store's shape ------------------------------------------------------------------------

func test_row_width_matches_the_schema() -> void:
	"""§4.2 and systems_architecture.md §2.2 both give Weather eight int32 columns in one row."""
	assert_equal(Weather.ROW_COLUMN_COUNT, ROW_COLUMNS, "Weather has eight int32 columns")
	assert_equal(Weather.ROW_COUNT, 1, "§4.2: one active major event per world")
	assert_equal(Weather.COL_EVENT, 0, "column order follows §2.2's listing")
	assert_equal(Weather.COL_START_DAY, 1, "start_day is the second column")
	assert_equal(Weather.COL_DURATION_DAYS, 2, "duration_days is the third column")
	assert_equal(Weather.COL_TEMPERATURE_TENTHS, 3, "temperature_tenths is the fourth column")
	assert_equal(Weather.COL_RAIN, 4, "rain is the fifth column")
	assert_equal(Weather.COL_FORECAST_0, 5, "forecast[0] is the sixth column")
	assert_equal(Weather.COL_FORECAST_1, 6, "forecast[1] is the seventh column")
	assert_equal(Weather.COL_FORECAST_2, 7, "forecast[2] is the eighth column")


func test_a_new_store_has_no_event_and_no_forecast() -> void:
	"""A fresh row schedules nothing and discloses nothing."""
	assert_equal(_weather.event_of(), NONE, "no event is scheduled initially")
	assert_false(_weather.is_event_scheduled(), "is_event_scheduled agrees with the column")
	assert_equal(_weather.start_day(), 0, "start_day is empty")
	assert_equal(_weather.duration_days(), 0, "duration_days is empty")
	assert_equal(_weather.temperature_tenths(), 0, "no daily temperature has been written")
	assert_equal(_weather.rain(), 0, "no daily rain has been written")
	assert_equal(_weather.forecast_event(), NONE, "nothing is disclosed")
	assert_false(_weather.is_forecast_disclosed(), "is_forecast_disclosed agrees")


func test_clear_returns_a_used_row_to_empty() -> void:
	"""clear() restores the empty row without reallocating the packed column."""
	_weather.schedule_first_spring_event(ABS_SPRING)
	_weather.disclose_forecast(ABS_SPRING, 6)
	_weather.refresh_daily(ABS_SPRING, 6)
	_weather.clear()
	assert_equal(_weather.event_of(), NONE, "the schedule is cleared")
	assert_equal(_weather.forecast_event(), NONE, "the forecast is cleared")
	assert_equal(_weather.temperature_tenths(), 0, "the daily temperature is cleared")
	assert_equal(_weather.rain(), 0, "the daily rain is cleared")


func test_event_ids_are_the_generated_ascii_order() -> void:
	"""GDD §4.2's closing paragraph numbers EventDefinition from its own ascending ASCII keys."""
	assert_equal(Weather.EVENT_BLIGHT, BLIGHT, "blight sorts first of the seven keys")
	assert_equal(Weather.EVENT_CALM_DAYS, CALM, "calm_days sorts second")
	assert_equal(Weather.EVENT_DROUGHT, DROUGHT, "drought sorts third")
	assert_equal(Weather.EVENT_EARLY_FROST, EARLY_FROST, "early_frost sorts fourth")
	assert_equal(Weather.EVENT_HARD_FREEZE, HARD_FREEZE, "hard_freeze sorts fifth")
	assert_equal(Weather.EVENT_HEAVY_RAIN, HEAVY_RAIN, "heavy_rain sorts sixth")
	assert_equal(Weather.EVENT_IDEAL_SPELL, IDEAL, "ideal_spell sorts seventh")
	assert_equal(Weather.EVENT_COUNT, EVENT_COUNT, "§5.10 lists seven event rows")
	assert_equal(Weather.EVENT_NONE, NONE, "the empty event follows §4.2's -1 convention")
	assert_equal(Weather.EVENT_KEYS.size(), EVENT_COUNT, "one catalog key per row")


func test_the_event_keys_are_in_compiled_id_order() -> void:
	"""EVENT_KEYS indexes every §5.10 table, so its order IS the compiled id order."""
	var expected: Array[StringName] = [&"blight", &"calm_days", &"drought", &"early_frost",
		&"hard_freeze", &"heavy_rain", &"ideal_spell"]
	for event: int in EVENT_COUNT:
		assert_equal(Weather.EVENT_KEYS[event], expected[event],
			"compiled id %d is %s" % [event, expected[event]])


func test_the_selection_traversal_is_the_printed_order_not_the_id_order() -> void:
	"""Decision 0028's ruled scan sequence is §5.10's printed order, which is NOT id order."""
	assert_equal(Weather.EVENT_SELECTION_ORDER.size(), EVENT_COUNT, "all seven rows are visited")
	for position: int in EVENT_COUNT:
		assert_equal(Weather.EVENT_SELECTION_ORDER[position], SELECTION_ORDER[position],
			"the ruled traversal's position %d" % position)
	assert_equal(Weather.EVENT_SELECTION_ORDER[0], IDEAL,
		"the scan starts at ideal spell, which is compiled id 6 -- order is not identity")
	var ascending: Array[int] = []
	for event: int in EVENT_COUNT:
		ascending.append(event)
	assert_true(Weather.EVENT_SELECTION_ORDER != ascending,
		"the two contracts genuinely differ: traversing ids 0..6 is a different scan")


# --- §5.10's event table ------------------------------------------------------------------------

func test_event_weights_are_the_raw_stated_integers() -> void:
	"""§5.10's "Weight" column: 30, 35, 50, 20, 30, 60, 20 -- raw, never a rounded percentage."""
	for event: int in EVENT_COUNT:
		var result: IntMath.IntResult = _weather.weight_of(event)
		assert_true(result.ok, "a table row has a weight")
		assert_equal(result.value, WEIGHTS[event], "§5.10's weight for row %d" % event)


func test_event_durations_are_the_stated_days() -> void:
	"""§5.10's "Duration" column: 3, 2, 4, 3, 2, 3, 2 days."""
	for event: int in EVENT_COUNT:
		var result: IntMath.IntResult = _weather.duration_days_of(event)
		assert_true(result.ok, "a table row has a duration")
		assert_equal(result.value, DURATIONS[event], "§5.10's duration for row %d" % event)


func test_start_day_is_six_except_early_frost_at_ten() -> void:
	"""§5.10: "start day is 6, except early frost day 10"."""
	for event: int in EVENT_COUNT:
		var result: IntMath.IntResult = _weather.start_day_of(event)
		assert_true(result.ok, "a table row has a start day")
		assert_equal(result.value, START_DAYS[event], "§5.10's start day for row %d" % event)
	assert_equal(_weather.start_day_of(EARLY_FROST).value, 10, "early frost starts on day 10")
	assert_equal(_weather.start_day_of(HEAVY_RAIN).value, 6, "every other row starts on day 6")


func test_forecast_day_is_three_days_before_the_start() -> void:
	"""REQ-SET-142: "three days in advance" -- day 3 for a day-6 event, day 7 for early frost."""
	assert_equal(_weather.forecast_day_of(IDEAL).value, 3, "ideal spell is disclosed on day 3")
	assert_equal(_weather.forecast_day_of(EARLY_FROST).value, 7, "early frost on day 7")
	assert_equal(Weather.FORECAST_DAYS, 3, "§5.10 announces three days before the start")


func test_eligible_seasons_match_the_stated_column() -> void:
	"""§5.10's "Eligible season" column: Any, Spring/autumn, Summer, Summer/autumn, Autumn,
	Winter, Any."""
	for season: int in 4:
		var eligible: Array[int] = _eligible_of(season)
		for event: int in EVENT_COUNT:
			assert_equal(_weather.is_eligible(event, season), eligible.has(event),
				"row %d eligibility in season %d" % [event, season])


func test_eligible_counts_match_the_stated_column() -> void:
	"""Three rows in spring and winter, four in summer, five in autumn."""
	assert_equal(_weather.eligible_count_of(SPRING).value, 3, "spring admits three rows")
	assert_equal(_weather.eligible_count_of(SUMMER).value, 4, "summer admits four rows")
	assert_equal(_weather.eligible_count_of(AUTUMN).value, 5, "autumn admits five rows")
	assert_equal(_weather.eligible_count_of(WINTER).value, 3, "winter admits three rows")


func test_weight_sums_are_the_ruled_values() -> void:
	"""The ruled sums: spring 85, summer 120, autumn 135, winter 110."""
	for season: int in 4:
		var result: IntMath.IntResult = _weather.weight_sum_of(season)
		assert_true(result.ok, "a season has an eligible weight sum")
		assert_equal(result.value, WEIGHT_SUMS[season], "weight sum for season %d" % season)


func test_weight_sum_equals_the_hand_added_eligible_weights() -> void:
	"""A second, independent check: add §5.10's weights for each season's own eligible rows."""
	assert_equal(30 + 35 + 20, WEIGHT_SUMS[SPRING], "spring is ideal+heavy rain+calm")
	assert_equal(30 + 50 + 20 + 20, WEIGHT_SUMS[SUMMER], "summer is ideal+drought+blight+calm")
	assert_equal(30 + 35 + 20 + 30 + 20, WEIGHT_SUMS[AUTUMN],
		"autumn is ideal+heavy rain+blight+early frost+calm")
	assert_equal(30 + 60 + 20, WEIGHT_SUMS[WINTER], "winter is ideal+hard freeze+calm")
	for season: int in 4:
		assert_equal(_weather.weight_sum_of(season).value, WEIGHT_SUMS[season],
			"the module reproduces the hand-added sum for season %d" % season)


# --- the ruled roll-to-row map ------------------------------------------------------------------

func test_every_roll_of_every_season_maps_to_the_ruled_row() -> void:
	"""Exhaustive: every roll in [0, weight_sum) lands in the ruled interval that contains it."""
	for season: int in 4:
		var map: Array[int] = _map_of(season)
		for triple: int in map.size() / 3:
			var event: int = map[triple * 3]
			for roll: int in range(map[triple * 3 + 1], map[triple * 3 + 2] + 1):
				var result: IntMath.IntResult = _weather.event_for_roll(season, roll)
				assert_equal(result.value, event,
					"season %d roll %d selects row %d" % [season, roll, event])


func test_both_sides_of_every_interval_boundary() -> void:
	"""Each interval's first and last roll select it; one below and one above select a neighbour."""
	for season: int in 4:
		var map: Array[int] = _map_of(season)
		for triple: int in map.size() / 3:
			_check_interval_edges(season, map, triple)


func _check_interval_edges(season: int, map: Array[int], triple: int) -> void:
	"""Probe one ruled interval's two endpoints and the two rolls immediately outside it."""
	var event: int = map[triple * 3]
	var first: int = map[triple * 3 + 1]
	var last: int = map[triple * 3 + 2]
	assert_equal(_weather.event_for_roll(season, first).value, event,
		"season %d: roll %d is the first of row %d" % [season, first, event])
	assert_equal(_weather.event_for_roll(season, last).value, event,
		"season %d: roll %d is the last of row %d" % [season, last, event])
	if triple > 0:
		assert_equal(_weather.event_for_roll(season, first - 1).value, map[(triple - 1) * 3],
			"season %d: roll %d belongs to the previous row" % [season, first - 1])
	else:
		assert_false(_weather.event_for_roll(season, first - 1).ok,
			"season %d: roll -1 is refused, never folded into the first row" % season)
	if triple * 3 + 3 < map.size():
		assert_equal(_weather.event_for_roll(season, last + 1).value, map[(triple + 1) * 3],
			"season %d: roll %d belongs to the next row" % [season, last + 1])
	else:
		assert_false(_weather.event_for_roll(season, last + 1).ok,
			"season %d: a roll at the weight sum is refused" % season)


func test_the_comparison_is_strictly_less_than_cumulative() -> void:
	"""`roll < cumulative`: the cumulative total itself belongs to the NEXT row, not this one."""
	assert_equal(_weather.event_for_roll(SPRING, 29).value, IDEAL,
		"spring roll 29 is still the ideal spell's 30 raw weight")
	assert_equal(_weather.event_for_roll(SPRING, 30).value, HEAVY_RAIN,
		"spring roll 30 -- the cumulative total -- is already the next row")
	assert_equal(_weather.event_for_roll(WINTER, 89).value, HARD_FREEZE,
		"winter roll 89 is the last of hard freeze's 60")
	assert_equal(_weather.event_for_roll(WINTER, 90).value, CALM,
		"winter roll 90 is the cumulative total and selects calm days")
	assert_equal(_weather.event_for_roll(AUTUMN, 114).value, EARLY_FROST,
		"autumn roll 114 is the last of early frost's 30")
	assert_equal(_weather.event_for_roll(AUTUMN, 115).value, CALM,
		"autumn roll 115 is the cumulative total and selects calm days")


func test_each_interval_is_exactly_as_wide_as_its_raw_weight() -> void:
	"""No percentage normalisation: an interval's width IS §5.10's raw integer weight."""
	for season: int in 4:
		var map: Array[int] = _map_of(season)
		for triple: int in map.size() / 3:
			var event: int = map[triple * 3]
			var width: int = map[triple * 3 + 2] - map[triple * 3 + 1] + 1
			assert_equal(width, WEIGHTS[event],
				"season %d row %d spans its raw weight" % [season, event])
			var counted: int = 0
			for roll: int in WEIGHT_SUMS[season]:
				if _weather.event_for_roll(season, roll).value == event:
					counted += 1
			assert_equal(counted, WEIGHTS[event],
				"season %d row %d claims exactly its weight in rolls" % [season, event])


func test_a_roll_outside_the_weight_sum_is_refused() -> void:
	"""A roll is refused with a reason rather than folded back into the first row."""
	for season: int in 4:
		var below: IntMath.IntResult = _weather.event_for_roll(season, -1)
		assert_false(below.ok, "a negative roll is refused in season %d" % season)
		assert_equal(below.value, 0, "a refusal carries no usable event")
		assert_equal(below.error, String(Weather.REFUSE_INVALID_ROLL),
			"refused as an out-of-range roll, not as a failed scan")
		var above: IntMath.IntResult = _weather.event_for_roll(season, WEIGHT_SUMS[season])
		assert_false(above.ok, "a roll at the weight sum is refused in season %d" % season)
		assert_equal(above.error, String(Weather.REFUSE_INVALID_ROLL),
			"the bound is checked before the scan, so the reason is the roll itself")
		var far: IntMath.IntResult = _weather.event_for_roll(season, WEIGHT_SUMS[season] + 1000)
		assert_false(far.ok, "a far roll is refused in season %d" % season)
		assert_equal(far.error, String(Weather.REFUSE_INVALID_ROLL), "for the same reason")


func test_an_invalid_season_is_refused_by_the_mapping() -> void:
	"""§4.3 has four seasons; anything else names no eligible set."""
	assert_false(_weather.event_for_roll(-1, 0).ok, "season -1 is refused")
	assert_false(_weather.event_for_roll(4, 0).ok, "season 4 is refused")
	assert_false(_weather.weight_sum_of(4).ok, "no weight sum exists for season 4")
	assert_false(_weather.eligible_count_of(-1).ok, "no eligible count exists for season -1")
	assert_false(_weather.weight_of(EVENT_COUNT).ok, "there is no eighth event row")
	assert_false(_weather.duration_days_of(-1).ok, "EVENT_NONE has no duration")


# --- ARCH-RNG-002's draw discipline ---------------------------------------------------------------

func test_the_forced_first_spring_consumes_no_draw() -> void:
	"""§5.10's onboarding event: ideal spell on day 6, and ARCH-RNG-002's "zero draws"."""
	var rng: Rng = _new_rng()
	var state_before: int = rng.stored_state_of(Rng.STREAM_WEATHER).value
	var result: Weather.OpResult = _weather.schedule_first_spring_event(ABS_SPRING)
	assert_true(result.ok, "the forced event is scheduled")
	assert_equal(result.value, IDEAL, "§5.10 forces the ideal spell")
	assert_equal(_weather.event_of(), IDEAL, "the row records the ideal spell")
	assert_equal(_weather.start_day(), 6, "§5.10: forced ideal spell on day 6")
	assert_equal(_weather.duration_days(), 3, "with the table's own three-day duration")
	assert_equal(rng.draw_count_of(Rng.STREAM_WEATHER).value, 0, "zero WEATHER draws")
	assert_equal(rng.stored_state_of(Rng.STREAM_WEATHER).value, state_before,
		"the WEATHER state is untouched by the forced event")


func test_an_ordinary_season_consumes_exactly_one_draw() -> void:
	"""ARCH-RNG-002: "One weighted event-selection roll per new season"."""
	var rng: Rng = _new_rng()
	assert_equal(rng.draw_count_of(Rng.STREAM_WEATHER).value, 0, "a fresh stream has no draws")
	var result: Weather.OpResult = _weather.schedule_season_event(ABS_SUMMER, rng)
	assert_true(result.ok, "a summer event is scheduled")
	assert_equal(rng.draw_count_of(Rng.STREAM_WEATHER).value, 1, "exactly one draw is consumed")
	_weather.schedule_season_event(ABS_AUTUMN, rng)
	assert_equal(rng.draw_count_of(Rng.STREAM_WEATHER).value, 2, "one more draw for one more season")
	assert_true(_weather.is_eligible(result.value, SUMMER), "the selected row is summer-eligible")


func test_selection_replays_the_stream_without_reseeding() -> void:
	"""The season index ORDERS the rows; it never reseeds. Eight seasons of lockstep replay."""
	var driven: Rng = _new_rng()
	var shadow: Rng = _new_rng()
	for step: int in 8:
		var season: int = step % 4
		var roll: int = shadow.draw(Rng.STREAM_WEATHER).value % WEIGHT_SUMS[season]
		var expected: int = _weather.event_for_roll(season, roll).value
		var got: Weather.OpResult = _weather.schedule_season_event(season, driven)
		assert_equal(got.value, expected, "step %d selects the shadow stream's row" % step)
		assert_equal(driven.stored_state_of(Rng.STREAM_WEATHER).value,
			shadow.stored_state_of(Rng.STREAM_WEATHER).value,
			"step %d leaves the stream where one raw draw would" % step)
		assert_equal(driven.draw_count_of(Rng.STREAM_WEATHER).value, step + 1,
			"step %d has taken exactly step+1 draws" % step)


func test_a_season_change_does_not_reseed_the_stream() -> void:
	"""Crossing every season boundary must not restore the seeded state (ARCH-RNG-002)."""
	var rng: Rng = _new_rng()
	var seeded_state: int = rng.stored_state_of(Rng.STREAM_WEATHER).value
	for season: int in 4:
		_weather.schedule_season_event(season, rng)
		assert_true(rng.stored_state_of(Rng.STREAM_WEATHER).value != seeded_state,
			"season %d has advanced the stream past its seed" % season)
	assert_equal(rng.draw_count_of(Rng.STREAM_WEATHER).value, 4, "four seasons, four draws")


func test_selection_touches_no_other_stream() -> void:
	"""ARCH-RNG-002: "No other system may consume these streams"."""
	var rng: Rng = _new_rng()
	for season: int in 4:
		_weather.schedule_season_event(season, rng)
	assert_equal(rng.draw_count_of(Rng.STREAM_ECOLOGY).value, 0, "ECOLOGY is untouched")
	assert_equal(rng.draw_count_of(Rng.STREAM_FISHING).value, 0, "FISHING is untouched")
	assert_equal(rng.draw_count_of(Rng.STREAM_IMMIGRATION).value, 0, "IMMIGRATION is untouched")
	assert_equal(rng.draw_count_of(Rng.STREAM_QUALITY).value, 0, "QUALITY is untouched")
	assert_equal(rng.draw_count_of(Rng.STREAM_HUNTING).value, 0, "the tombstone is untouched")
	assert_true(rng.tombstone_is_intact(), "the retired HUNTING stream is still canonical")


func test_the_module_uses_the_weather_stream() -> void:
	"""ARCH-RNG-002 assigns weather its own isolated stream; the id comes from rng.gd."""
	assert_equal(Weather.STREAM_WEATHER, Rng.STREAM_WEATHER, "the WEATHER stream id is rng.gd's")
	var rng: Rng = _new_rng()
	_weather.schedule_season_event(ABS_SPRING, rng)
	assert_equal(rng.draw_count_of(Rng.STREAM_WEATHER).value, 1, "the draw landed on WEATHER")


func test_a_refused_schedule_consumes_no_draw() -> void:
	"""A refusal advances nothing, so a rejected call cannot desynchronise a replay."""
	var rng: Rng = _new_rng()
	var state_before: int = rng.stored_state_of(Rng.STREAM_WEATHER).value
	var bad_season: Weather.OpResult = _weather.schedule_season_event(ABS_NONE, rng)
	assert_false(bad_season.ok, "the empty absolute season -1 is refused")
	assert_equal(rng.draw_count_of(Rng.STREAM_WEATHER).value, 0, "no draw was consumed")
	var no_rng: Weather.OpResult = _weather.schedule_season_event(ABS_SPRING, null)
	assert_false(no_rng.ok, "a null Rng is refused rather than crashed on")
	assert_equal(no_rng.error, Weather.REFUSE_NO_RNG, "with a reason on its own channel")
	assert_equal(_weather.event_of(), NONE, "and no event was written")
	assert_equal(rng.stored_state_of(Rng.STREAM_WEATHER).value, state_before, "state unmoved")


func test_an_unseeded_rng_is_refused_without_writing_the_row() -> void:
	"""The stream's own refusal travels out intact and leaves the row empty."""
	var rng: Rng = Rng.new()
	var result: Weather.OpResult = _weather.schedule_season_event(ABS_SPRING, rng)
	assert_false(result.ok, "an unseeded store cannot draw")
	assert_equal(result.error, Rng.REFUSE_NOT_SEEDED, "rng.gd's own refusal code is preserved")
	assert_equal(_weather.event_of(), NONE, "the row is untouched by a refused draw")


func test_the_same_seed_replays_the_same_seasons() -> void:
	"""Determinism: two stores driven by identically seeded streams agree season for season."""
	var first: Weather = Weather.new()
	var second: Weather = Weather.new()
	var rng_a: Rng = _new_rng()
	var rng_b: Rng = _new_rng()
	for step: int in 6:
		var season: int = step % 4
		var a: int = first.schedule_season_event(season, rng_a).value
		var b: int = second.schedule_season_event(season, rng_b).value
		assert_equal(a, b, "step %d selects the same row from the same seed" % step)


func test_is_forced_first_spring_names_year_one_spring_only() -> void:
	"""§5.10's onboarding season is year 1's spring; every later spring draws."""
	assert_true(_weather.is_forced_first_spring(1, SPRING), "year 1 spring is forced")
	assert_false(_weather.is_forced_first_spring(2, SPRING), "year 2 spring draws")
	assert_false(_weather.is_forced_first_spring(1, SUMMER), "year 1 summer draws")
	assert_false(_weather.is_forced_first_spring(1, WINTER), "year 1 winter draws")
	assert_false(_weather.is_forced_first_spring(0, SPRING), "SimClock years count from 1")


# --- REQ-SET-142's forecast -----------------------------------------------------------------------

func _schedule_event(absolute_season: int, event: int, rng: Rng) -> bool:
	"""Advance the WEATHER stream until its next draw would select `event`, then schedule it.

	INJECTS A VALID EVENT FIXTURE, as ruling §4.3 requires: "Use injected valid event fixtures for
	these checks, not a claim that the production seed necessarily selects blight." Every event it
	can reach is one §5.10 admits in that season -- the roll is mapped through the module's own
	published `event_for_roll()` and no row is written by hand.
	Uses only the public API -- rng.gd's state_of() plus its static next_u32_from() -- so a test
	can reach an event the seed does not immediately produce without any back door into the row.
	The extra draws are irrelevant here: no test using this helper asserts a draw count.
	"""
	var season: int = absolute_season % 4
	for attempt: int in 4096:
		var state: int = rng.state_of(Rng.STREAM_WEATHER).value
		var peek: int = Rng.next_u32_from(state).value % WEIGHT_SUMS[season]
		if _weather.event_for_roll(season, peek).value == event:
			return _weather.schedule_season_event(absolute_season, rng).ok
		rng.draw(Rng.STREAM_WEATHER)
	return false


func test_the_forecast_is_not_due_before_three_days_out() -> void:
	"""REQ-SET-142 discloses on day 3 for a day-6 event, and refuses earlier with a reason."""
	_weather.schedule_first_spring_event(ABS_SPRING)
	for day: int in range(1, 3):
		var early: Weather.OpResult = _weather.disclose_forecast(ABS_SPRING, day)
		assert_false(early.ok, "day %d is too early to disclose" % day)
		assert_equal(early.error, Weather.REFUSE_FORECAST_NOT_DUE, "with the stated reason")
		assert_false(_weather.is_forecast_due(ABS_SPRING, day), "is_forecast_due agrees on day %d" % day)
		assert_false(_weather.is_forecast_disclosed(), "nothing is disclosed yet")
	assert_true(_weather.is_forecast_due(ABS_SPRING, 3), "day 3 is exactly three days before day 6")
	assert_true(_weather.disclose_forecast(ABS_SPRING, 3).ok, "and the disclosure succeeds")


func test_the_disclosed_forecast_holds_event_start_and_duration() -> void:
	"""REQ-SET-142's start and duration are retained; the affected systems derive from the event."""
	_weather.schedule_first_spring_event(ABS_SPRING)
	_weather.disclose_forecast(ABS_SPRING, 3)
	assert_true(_weather.is_forecast_disclosed(), "the forecast is disclosed")
	assert_equal(_weather.forecast_event(), IDEAL, "forecast[0] names the coming event")
	assert_equal(_weather.forecast_start_day(), 6, "forecast[1] is §5.10's start day")
	assert_equal(_weather.forecast_duration_days(), 3, "forecast[2] is §5.10's duration")
	assert_equal(_weather.forecast_absolute_season(), ABS_SPRING,
		"and the disclosure carries the absolute season it belongs to")
	var mask: IntMath.IntResult = _weather.forecast_effect_mask()
	assert_true(mask.ok, "the affected systems derive from the disclosed event")
	assert_equal(mask.value, _weather.effect_mask_for(IDEAL, SPRING).value,
		"and match the event's own effects column, read in its own season")


func test_disclosure_is_idempotent_and_consumes_no_draw() -> void:
	"""BAL-SAFE-017: "opening forecasts ... SHALL consume no event roll"."""
	var rng: Rng = _new_rng()
	_weather.schedule_season_event(ABS_SPRING, rng)
	var count_after_schedule: int = rng.draw_count_of(Rng.STREAM_WEATHER).value
	for day: int in range(3, 13):
		_weather.disclose_forecast(ABS_SPRING, day)
	assert_equal(rng.draw_count_of(Rng.STREAM_WEATHER).value, count_after_schedule,
		"ten disclosures consumed no further draw")
	assert_equal(_weather.forecast_event(), _weather.event_of(), "and disclosed the same event")
	assert_equal(_weather.forecast_start_day(), 6, "with the same start day every time")


func test_early_frost_is_disclosed_on_day_seven() -> void:
	"""§5.10's one exception: early frost starts on day 10, so its forecast falls due on day 7."""
	var rng: Rng = _new_rng()
	assert_true(_schedule_event(ABS_AUTUMN, EARLY_FROST, rng), "early frost is reachable in autumn")
	assert_equal(_weather.event_of(), EARLY_FROST, "the row records early frost")
	assert_equal(_weather.start_day(), 10, "which starts on day 10")
	assert_equal(_weather.duration_days(), 2, "for two days")
	assert_false(_weather.disclose_forecast(ABS_AUTUMN, 6).ok, "day 6 is too early for a day-10 event")
	assert_true(_weather.disclose_forecast(ABS_AUTUMN, 7).ok, "day 7 is three days before day 10")
	assert_equal(_weather.forecast_start_day(), 10, "and discloses the stated start day")


func test_disclosure_without_a_scheduled_event_is_refused() -> void:
	"""There is nothing to disclose before a season's event is selected."""
	var result: Weather.OpResult = _weather.disclose_forecast(ABS_SPRING, 3)
	assert_false(result.ok, "an empty row discloses nothing")
	assert_equal(result.error, Weather.REFUSE_NO_EVENT_SCHEDULED, "with the stated reason")
	assert_false(_weather.is_forecast_due(ABS_SPRING, 3), "and no disclosure is due")
	assert_false(_weather.disclose_forecast(ABS_SPRING, 0).ok, "day 0 is not a season day")
	assert_false(_weather.disclose_forecast(ABS_SPRING, 13).ok, "nor is day 13 of a twelve-day season")


func test_scheduling_a_new_event_clears_the_previous_forecast() -> void:
	"""REQ-SET-142 retains the forecast OF THE SCHEDULED EVENT, not of a superseded one."""
	_weather.schedule_first_spring_event(ABS_SPRING)
	_weather.disclose_forecast(ABS_SPRING, 3)
	var rng: Rng = _new_rng()
	_weather.schedule_season_event(ABS_SUMMER, rng)
	assert_false(_weather.is_forecast_disclosed(), "the stale forecast is cleared")
	assert_equal(_weather.forecast_event(), NONE, "forecast[0] is empty again")
	assert_equal(_weather.forecast_start_day(), 0, "forecast[1] is empty again")
	assert_equal(_weather.forecast_duration_days(), 0, "forecast[2] is empty again")
	assert_equal(_weather.forecast_absolute_season(), ABS_NONE,
		"and its absolute-season identity is emptied to -1 with it, not left at spring's 0")
	assert_false(_weather.is_absolute_season(_weather.forecast_absolute_season()),
		"so the cleared identity names no season at all")
	var undisclosed: IntMath.IntResult = _weather.forecast_effect_mask()
	assert_false(undisclosed.ok, "and no effect mask can be read from a cleared forecast")


# --- the event window -----------------------------------------------------------------------------

func test_the_event_window_covers_start_through_start_plus_duration_minus_one() -> void:
	"""BAL-PROBE-001: "the first spring ideal spell is days 6-8"."""
	_weather.schedule_first_spring_event(ABS_SPRING)
	assert_equal(_weather.last_day(), 8, "a three-day event from day 6 ends on day 8")
	assert_false(_weather.is_event_active(ABS_SPRING, 5), "day 5 is before the window")
	assert_true(_weather.is_event_active(ABS_SPRING, 6), "day 6 opens the window")
	assert_true(_weather.is_event_active(ABS_SPRING, 7), "day 7 is inside it")
	assert_true(_weather.is_event_active(ABS_SPRING, 8), "day 8 closes it")
	assert_false(_weather.is_event_active(ABS_SPRING, 9), "day 9 is after the window")
	assert_equal(_weather.active_event_on(ABS_SPRING, 5), NONE, "no event modifies day 5")
	assert_equal(_weather.active_event_on(ABS_SPRING, 6), IDEAL, "the ideal spell modifies day 6")
	assert_equal(_weather.active_event_on(ABS_SPRING, 9), NONE, "nor day 9")


func test_early_frost_occupies_days_ten_and_eleven() -> void:
	"""§5.10's day-10 start with a two-day duration ends on day 11, inside the season."""
	var rng: Rng = _new_rng()
	assert_true(_schedule_event(ABS_AUTUMN, EARLY_FROST, rng), "early frost is reachable")
	assert_false(_weather.is_event_active(ABS_AUTUMN, 9), "day 9 is before early frost")
	assert_true(_weather.is_event_active(ABS_AUTUMN, 10), "day 10 opens it")
	assert_true(_weather.is_event_active(ABS_AUTUMN, 11), "day 11 closes it")
	assert_false(_weather.is_event_active(ABS_AUTUMN, 12), "day 12 is clear again")
	assert_equal(_weather.last_day(), 11, "and it ends inside the twelve-day season")


func test_an_out_of_range_day_is_never_active() -> void:
	"""A day outside 1..12 names no day of this season at all."""
	_weather.schedule_first_spring_event(ABS_SPRING)
	assert_false(_weather.is_event_active(ABS_SPRING, 0), "day 0 does not exist")
	assert_false(_weather.is_event_active(ABS_SPRING, DAYS_PER_SEASON + 1), "nor day 13")
	assert_equal(_weather.active_event_on(ABS_SPRING, 0), NONE, "and neither carries an event")
	assert_equal(_weather.active_event_on(ABS_SPRING, -5), NONE, "including a negative day")


# --- §5.10's season baseline table -------------------------------------------------------------

func test_season_baseline_temperatures_are_the_stated_tenths() -> void:
	"""§5.10: spring 12°C, summer 22°C, autumn 10°C, winter -5°C, stored in tenths."""
	for season: int in 4:
		var result: IntMath.IntResult = _weather.baseline_temperature_tenths_of(season)
		assert_true(result.ok, "season %d has a baseline temperature" % season)
		assert_equal(result.value, BASELINE_TEMPERATURE[season],
			"§5.10's baseline temperature for season %d" % season)
	assert_equal(_weather.baseline_temperature_tenths_of(WINTER).value, -50,
		"winter's -5°C is stored as -50 tenths, sign intact")
	assert_false(_weather.baseline_temperature_tenths_of(4).ok, "season 4 has no baseline")


func test_season_baseline_rain_is_the_stated_column() -> void:
	"""§5.10's "Rain/moisture per day": +1200, +300, +700, +0."""
	for season: int in 4:
		var result: IntMath.IntResult = _weather.baseline_rain_of(season)
		assert_true(result.ok, "season %d has a baseline rain" % season)
		assert_equal(result.value, BASELINE_RAIN[season], "§5.10's rain for season %d" % season)
	assert_equal(_weather.baseline_rain_of(WINTER).value, 0, "winter adds no rain at all")


func test_daylight_windows_match_the_stated_hours() -> void:
	"""§5.10's "Daylight": 06:00-19:00, 05:00-21:00, 07:00-18:00, 08:00-16:00."""
	for season: int in 4:
		assert_equal(_weather.daylight_start_hour_of(season).value, DAYLIGHT_START[season],
			"first lit hour of season %d" % season)
		assert_equal(_weather.daylight_end_hour_of(season).value, DAYLIGHT_END[season],
			"hour darkness begins in season %d" % season)
		assert_equal(_weather.daylight_hours_of(season).value,
			DAYLIGHT_END[season] - DAYLIGHT_START[season],
			"lit hours of season %d" % season)
	assert_equal(_weather.daylight_hours_of(SPRING).value, 13, "spring has 13 lit hours")
	assert_equal(_weather.daylight_hours_of(WINTER).value, 8, "winter has 8")


func test_both_sides_of_every_daylight_boundary() -> void:
	"""The window is read as [start, end): the closing hour is already dark."""
	for season: int in 4:
		var first: int = DAYLIGHT_START[season]
		var last_dark: int = DAYLIGHT_END[season]
		assert_false(_weather.is_daylight_hour(season, first - 1),
			"season %d: the hour before sunrise is dark" % season)
		assert_true(_weather.is_daylight_hour(season, first),
			"season %d: the opening hour is lit" % season)
		assert_true(_weather.is_daylight_hour(season, last_dark - 1),
			"season %d: the hour before the close is lit" % season)
		assert_false(_weather.is_daylight_hour(season, last_dark),
			"season %d: the closing hour is dark" % season)


func test_an_hour_outside_the_day_is_never_daylight() -> void:
	"""SimClock.Calendar.hour is 0..23; anything else names no hour."""
	assert_false(_weather.is_daylight_hour(SPRING, -1), "hour -1 does not exist")
	assert_false(_weather.is_daylight_hour(SPRING, 24), "nor hour 24")
	assert_false(_weather.is_daylight_hour(4, 12), "nor midday of a fifth season")
	assert_true(_weather.is_hour(0), "midnight is an hour of the day")
	assert_true(_weather.is_hour(23), "and so is 23:00")
	assert_false(_weather.is_hour(24), "24 is the next day's midnight")


func test_the_darkness_work_factor_is_seven_hundred_and_fifty_per_thousand() -> void:
	"""REQ-SET-148: "unlit outdoor productive work×0.75 in darkness", as an integer factor."""
	assert_equal(_weather.darkness_work_factor_per_1000(), 750, "0.75 expressed per 1000")
	assert_equal(Weather.FACTOR_DENOMINATOR, 1000, "factors here are per 1000")
	assert_equal(Weather.NEUTRAL_FACTOR_PER_1000, 1000, "and 1000 is the neutral factor")


func test_winter_hunger_demand_is_multiplied_by_one_point_two() -> void:
	"""REQ-SET-143: "While winter is active, the system shall multiply hunger demand by 1.20"."""
	assert_equal(_weather.hunger_multiplier_per_1000_of(WINTER).value, 1200,
		"winter multiplies hunger demand by 1.20")
	assert_equal(_weather.hunger_multiplier_per_1000_of(SPRING).value, 1000, "spring does not")
	assert_equal(_weather.hunger_multiplier_per_1000_of(SUMMER).value, 1000, "summer does not")
	assert_equal(_weather.hunger_multiplier_per_1000_of(AUTUMN).value, 1000, "autumn does not")
	assert_false(_weather.hunger_multiplier_per_1000_of(-1).ok, "season -1 has no multiplier")


# --- §5.10's effects column ------------------------------------------------------------------------

func test_ideal_spell_temperature_is_eighteen_degrees_except_two_in_winter() -> void:
	"""§5.10: "Temperature 18°C except winter 2°C" -- the table's only season-conditional value."""
	assert_equal(_weather.temperature_tenths_for(SPRING, IDEAL).value, 180, "spring 18°C")
	assert_equal(_weather.temperature_tenths_for(SUMMER, IDEAL).value, 180, "summer 18°C")
	assert_equal(_weather.temperature_tenths_for(AUTUMN, IDEAL).value, 180, "autumn 18°C")
	assert_equal(_weather.temperature_tenths_for(WINTER, IDEAL).value, 20, "winter 2°C")


func test_heavy_rain_is_three_degrees_below_its_season_baseline() -> void:
	"""§5.10: "Temperature-3°C from baseline" -- the one row stated as a delta."""
	assert_equal(_weather.temperature_tenths_for(SPRING, HEAVY_RAIN).value, 120 - 30,
		"spring 12°C - 3°C")
	assert_equal(_weather.temperature_tenths_for(AUTUMN, HEAVY_RAIN).value, 100 - 30,
		"autumn 10°C - 3°C")
	assert_false(_weather.temperature_tenths_for(SUMMER, HEAVY_RAIN).ok,
		"heavy rain is not summer-eligible, so it has no summer temperature")


func test_the_absolute_event_temperatures_are_the_stated_degrees() -> void:
	"""Drought 30°C, early frost -3°C and hard freeze -12°C are absolute (see the module header)."""
	assert_equal(_weather.temperature_tenths_for(SUMMER, DROUGHT).value, 300, "drought 30°C")
	assert_equal(_weather.temperature_tenths_for(AUTUMN, EARLY_FROST).value, -30,
		"early frost -3°C, below freezing so its frost effects have a mechanism")
	assert_equal(_weather.temperature_tenths_for(WINTER, HARD_FREEZE).value, -120,
		"hard freeze -12°C")


func test_blight_and_calm_days_leave_the_baseline_temperature_alone() -> void:
	"""Neither row states a temperature, so the season baseline stands."""
	assert_equal(_weather.temperature_tenths_for(SUMMER, BLIGHT).value, 220, "summer blight 22°C")
	assert_equal(_weather.temperature_tenths_for(AUTUMN, BLIGHT).value, 100, "autumn blight 10°C")
	for season: int in 4:
		assert_equal(_weather.temperature_tenths_for(season, CALM).value,
			BASELINE_TEMPERATURE[season], "calm days keep season %d's baseline" % season)


func test_no_event_reports_the_plain_season_baseline() -> void:
	"""EVENT_NONE is a state, not a refusal: it reports the season's own temperature and rain."""
	for season: int in 4:
		assert_equal(_weather.temperature_tenths_for(season, NONE).value,
			BASELINE_TEMPERATURE[season], "season %d baseline temperature" % season)
		assert_equal(_weather.rain_for(season, NONE).value, BASELINE_RAIN[season],
			"season %d baseline rain" % season)


func test_event_rain_follows_the_stated_additions() -> void:
	"""§5.10: ideal "+600/day", heavy rain "+2000/day", drought "rain 0"; others state none."""
	assert_equal(_weather.rain_for(SPRING, IDEAL).value, 1200 + 600, "spring ideal spell rain")
	assert_equal(_weather.rain_for(WINTER, IDEAL).value, 0 + 600, "winter ideal spell rain")
	assert_equal(_weather.rain_for(SPRING, HEAVY_RAIN).value, 1200 + 2000, "spring storm rain")
	assert_equal(_weather.rain_for(AUTUMN, HEAVY_RAIN).value, 700 + 2000, "autumn storm rain")
	assert_equal(_weather.rain_for(SUMMER, DROUGHT).value, 0, "drought states an absolute rain 0")
	assert_equal(_weather.rain_for(SUMMER, BLIGHT).value, 300, "blight keeps summer's 300")
	assert_equal(_weather.rain_for(AUTUMN, CALM).value, 700, "calm days keep autumn's 700")


func test_an_ineligible_event_is_refused_rather_than_evaluated() -> void:
	"""The partial season guard: a stored row queried against a season §5.10 never admits."""
	assert_false(_weather.temperature_tenths_for(WINTER, DROUGHT).ok, "no winter drought")
	assert_equal(_weather.temperature_tenths_for(WINTER, DROUGHT).error,
		String(Weather.REFUSE_EVENT_NOT_ELIGIBLE), "with the stated reason")
	assert_false(_weather.rain_for(SPRING, BLIGHT).ok, "no spring blight")
	assert_false(_weather.temperature_tenths_for(SUMMER, HARD_FREEZE).ok, "no summer hard freeze")
	assert_false(_weather.temperature_tenths_for(SPRING, EVENT_COUNT).ok, "no eighth row")
	assert_false(_weather.rain_for(4, IDEAL).ok, "no fifth season")


func test_the_reported_effect_factors_are_the_stated_numbers() -> void:
	"""Ideal spell's crop growth×1.20, blight's 400 damage/day, heavy rain's outdoor work×0.80 and
	hard freeze's exposure×2, transcribed as integer factors and applied to nothing here."""
	assert_equal(_weather.crop_growth_factor_per_1000_of(IDEAL).value, 1200, "crop growth×1.20")
	assert_equal(_weather.crop_growth_factor_per_1000_of(BLIGHT).value, 1000, "blight states none")
	assert_equal(_weather.crop_damage_per_day_of(BLIGHT).value, 400, "blight damages 400/day")
	assert_equal(_weather.crop_damage_per_day_of(DROUGHT).value, 0, "drought damages no crop")
	assert_equal(_weather.outdoor_work_factor_per_1000_of(HEAVY_RAIN).value, 800,
		"heavy rain's outdoor work×0.80")
	assert_equal(_weather.outdoor_work_factor_per_1000_of(HARD_FREEZE).value, 1000,
		"hard freeze states no work factor")
	assert_equal(_weather.exposure_multiplier_per_1000_of(HARD_FREEZE).value, 2000,
		"hard freeze's exposure accumulation×2")
	assert_equal(_weather.exposure_multiplier_per_1000_of(EARLY_FROST).value, 1000,
		"early frost states no exposure multiplier")


func test_effect_factors_are_neutral_with_no_event_and_refused_for_a_non_row() -> void:
	"""EVENT_NONE reports the neutral factor; an invented row number is refused."""
	assert_equal(_weather.crop_growth_factor_per_1000_of(NONE).value, 1000, "no growth change")
	assert_equal(_weather.crop_damage_per_day_of(NONE).value, 0, "no crop damage")
	assert_equal(_weather.outdoor_work_factor_per_1000_of(NONE).value, 1000, "no work change")
	assert_equal(_weather.exposure_multiplier_per_1000_of(NONE).value, 1000, "no exposure change")
	assert_false(_weather.crop_growth_factor_per_1000_of(EVENT_COUNT).ok, "no eighth row")
	assert_false(_weather.crop_damage_per_day_of(-2).ok, "no row -2")
	assert_false(_weather.outdoor_work_factor_per_1000_of(99).ok, "no row 99")
	assert_false(_weather.exposure_multiplier_per_1000_of(EVENT_COUNT).ok, "no eighth row")


func test_the_stated_access_flags_belong_to_one_row_each() -> void:
	"""§5.10 states boats disabled for heavy rain, lake ice for hard freeze, the mussel closure for
	blight and orchard water for drought -- each for exactly one row."""
	for event: int in EVENT_COUNT:
		assert_equal(_weather.disables_boats(event), event == HEAVY_RAIN,
			"only heavy rain/storm disables boats (row %d)" % event)
		assert_equal(_weather.lake_ice_access_only(event), event == HARD_FREEZE,
			"only hard freeze restricts the lake to ice access (row %d)" % event)
		assert_equal(_weather.closes_mussel_harvest(event, SUMMER), event == BLIGHT,
			"only blight closes the SUMMER mussel harvest (row %d)" % event)
		assert_false(_weather.closes_mussel_harvest(event, AUTUMN),
			"no row closes the mussel harvest in autumn (row %d)" % event)
		assert_equal(_weather.needs_orchard_water(event), event == DROUGHT,
			"only drought needs orchard water (row %d)" % event)
	assert_false(_weather.disables_boats(NONE), "no event disables nothing")


func test_affected_system_masks_name_each_rows_stated_effects() -> void:
	"""REQ-SET-142's "affected systems", derived from §5.10's effects column, one bit per phrase."""
	var ideal: int = _weather.affected_systems_mask_of(IDEAL).value
	assert_true((ideal & Weather.AFFECTS_CROP_GROWTH) != 0, "ideal spell affects crop growth")
	assert_true((ideal & Weather.AFFECTS_RAIN) != 0, "and rain")
	assert_true((ideal & Weather.AFFECTS_BOATS) == 0, "but not boats")
	assert_equal(_weather.affected_systems_mask_of(CALM).value, 0,
		"calm days state no modifier, so nothing is affected")
	var freeze: int = _weather.affected_systems_mask_of(HARD_FREEZE).value
	assert_true((freeze & Weather.AFFECTS_EXPOSURE) != 0, "hard freeze affects exposure")
	assert_true((freeze & Weather.AFFECTS_LAKE_ICE) != 0, "and lake access")
	assert_true((freeze & Weather.AFFECTS_CROP_DAMAGE) == 0, "but damages no crop directly")
	assert_false(_weather.affected_systems_mask_of(EVENT_COUNT).ok, "no eighth row")


func test_blight_is_reported_active_only_inside_its_window() -> void:
	"""The reader fishing.gd's summer mussel closure needs; no fish store is touched here."""
	var rng: Rng = _new_rng()
	assert_true(_schedule_event(ABS_SUMMER, BLIGHT, rng), "blight is reachable in summer")
	assert_false(_weather.is_blight_active(ABS_SUMMER, 5), "day 5 precedes the day-6 start")
	assert_true(_weather.is_blight_active(ABS_SUMMER, 6), "day 6 opens the three-day blight")
	assert_true(_weather.is_blight_active(ABS_SUMMER, 8), "day 8 closes it")
	assert_false(_weather.is_blight_active(ABS_SUMMER, 9), "day 9 is clear")
	assert_false(_weather.is_blight_active(ABS_WINTER, 6),
		"the winter that follows is a different absolute season and carries no blight")
	assert_false(_weather.is_blight_active(ABS_SUMMER_Y2, 6),
		"and so is the NEXT year's summer, which the old 0-3 ordinal could not tell apart")
	assert_false(_weather.is_blight_active(ABS_SUMMER, 0), "day 0 is no day of the season")
	assert_false(_weather.is_blight_active(ABS_NONE, 6), "the empty identity names no season")


func test_a_non_blight_event_never_reports_blight() -> void:
	"""The forced ideal spell must not answer the mussel closure's question affirmatively."""
	_weather.schedule_first_spring_event(ABS_SPRING)
	for day: int in range(1, DAYS_PER_SEASON + 1):
		assert_false(_weather.is_blight_active(ABS_SPRING, day),
			"an ideal spell is not a blight on day %d" % day)


# --- §5.10's moisture arithmetic --------------------------------------------------------------

func test_daily_evaporation_is_six_hundred_and_nine_hundred_in_summer() -> void:
	"""§5.10: "Plots lose 600 moisture/day baseline, multiplied 1500/1000 in summer"."""
	assert_equal(_weather.evaporation_for(SPRING, NONE).value, 600, "spring loses 600")
	assert_equal(_weather.evaporation_for(SUMMER, NONE).value, 900, "summer loses 600*1500/1000")
	assert_equal(_weather.evaporation_for(AUTUMN, NONE).value, 600, "autumn loses 600")
	assert_equal(_weather.evaporation_for(WINTER, NONE).value, 600, "winter loses 600")
	assert_equal(_weather.evaporation_for(SUMMER, DROUGHT).value, 2400,
		"summer drought loses 900 plus the stated extra 1500")
	assert_equal(_weather.evaporation_for(SUMMER, BLIGHT).value, 900,
		"blight states no extra moisture loss")
	assert_false(_weather.evaporation_for(4, NONE).ok, "no fifth season")


func test_the_net_daily_moisture_change_evaporates_before_rain() -> void:
	"""BAL-CONFLICT-005: "Spring baseline moisture changes by +1200-600=+600/day"."""
	assert_equal(_weather.moisture_delta_for(SPRING, NONE).value, 600, "spring gains 600/day")
	assert_equal(_weather.moisture_delta_for(SUMMER, NONE).value, 300 - 900, "summer loses 600/day")
	assert_equal(_weather.moisture_delta_for(AUTUMN, NONE).value, 700 - 600, "autumn gains 100")
	assert_equal(_weather.moisture_delta_for(WINTER, NONE).value, -600, "winter loses 600")
	assert_equal(_weather.moisture_delta_for(SPRING, IDEAL).value, 1800 - 600,
		"a spring ideal spell gains 1200/day")
	assert_equal(_weather.moisture_delta_for(SUMMER, DROUGHT).value, -2400,
		"drought adds no rain and loses 2400")
	assert_equal(_weather.moisture_delta_for(AUTUMN, HEAVY_RAIN).value, 2700 - 600,
		"an autumn storm gains 2100")


func test_the_published_moisture_probe_is_reproduced_day_by_day() -> void:
	"""BAL-PROBE-001's executed grain/moisture column for absolute days 1-17, transcribed above."""
	_weather.schedule_first_spring_event(ABS_SPRING)
	var moisture: int = PROBE_MOISTURE[0]
	for day: int in range(2, PROBE_MOISTURE.size() + 1):
		var calendar: SimClock.Calendar = SimClock.calendar_at(
			(day - 1) * SimClock.TICKS_PER_DAY + SimClock.CALENDAR_OFFSET_TICKS)
		var event: int = _weather.active_event_on((day - 1) / DAYS_PER_SEASON,
			calendar.season_day)
		var result: IntMath.IntResult = _weather.moisture_after_day(
			moisture, calendar.season, event)
		assert_true(result.ok, "day %d has a moisture result" % day)
		moisture = result.value
		assert_equal(moisture, PROBE_MOISTURE[day - 1],
			"BAL-PROBE-001's moisture on absolute day %d" % day)


func test_moisture_is_clamped_to_the_stated_range() -> void:
	"""REQ-SET-086: "clamp moisture 0-10000"."""
	assert_equal(_weather.moisture_after_day(10000, SPRING, NONE).value, 10000,
		"a saturated plot cannot exceed 10000")
	assert_equal(_weather.moisture_after_day(9800, SPRING, IDEAL).value, 10000,
		"nor can a spring ideal spell push it past the cap")
	assert_equal(_weather.moisture_after_day(0, WINTER, NONE).value, 0,
		"a dry plot cannot fall below 0")
	assert_equal(_weather.moisture_after_day(400, SUMMER, DROUGHT).value, 0,
		"drought stops at the floor rather than going negative")
	assert_equal(_weather.moisture_after_day(9400, SPRING, NONE).value, 10000,
		"exactly reaching the cap is not an overflow")
	assert_equal(_weather.moisture_after_day(600, WINTER, NONE).value, 0,
		"exactly reaching the floor is not an underflow")


func test_a_moisture_outside_the_stated_range_is_refused() -> void:
	"""An out-of-range moisture is refused with a reason, never clamped into a plausible answer."""
	var below: IntMath.IntResult = _weather.moisture_after_day(-1, SPRING, NONE)
	assert_false(below.ok, "a negative moisture is refused")
	assert_equal(below.value, 0, "and carries no usable number")
	assert_equal(below.error, String(Weather.REFUSE_INVALID_MOISTURE), "with the stated reason")
	assert_false(_weather.moisture_after_day(10001, SPRING, NONE).ok, "as is 10001")
	assert_false(_weather.moisture_after_day(6000, 4, NONE).ok, "as is a fifth season")
	assert_false(_weather.moisture_after_day(6000, WINTER, DROUGHT).ok, "as is a winter drought")


# --- §4.2's daily baseline, REQ-SET-145's removal, REQ-SET-141's boundary -------------------------

func test_the_daily_row_records_the_baseline_outside_the_event_window() -> void:
	"""§4.2: "daily baseline independently" -- an unaffected day carries the season's own numbers."""
	_weather.schedule_first_spring_event(ABS_SPRING)
	assert_true(_weather.refresh_daily(ABS_SPRING, 5).ok, "day 5 refreshes")
	assert_equal(_weather.temperature_tenths(), 120, "spring's 12°C stands on day 5")
	assert_equal(_weather.rain(), 1200, "and spring's +1200 rain")
	assert_true(_weather.refresh_daily(ABS_SPRING, 9).ok, "day 9 refreshes")
	assert_equal(_weather.temperature_tenths(), 120, "and the baseline returns after the event")
	assert_equal(_weather.rain(), 1200, "with the baseline rain")


func test_the_daily_row_records_the_event_inside_its_window() -> void:
	"""Each day of the forced ideal spell carries 18°C and spring's rain plus 600."""
	_weather.schedule_first_spring_event(ABS_SPRING)
	for day: int in range(6, 9):
		assert_true(_weather.refresh_daily(ABS_SPRING, day).ok, "day %d refreshes" % day)
		assert_equal(_weather.temperature_tenths(), 180, "day %d is 18°C" % day)
		assert_equal(_weather.rain(), 1800, "day %d rains 1200+600" % day)


func test_refresh_daily_refuses_an_impossible_day_or_season() -> void:
	"""A refusal writes no column, so a bad call cannot leave a wrong baseline behind."""
	_weather.schedule_first_spring_event(ABS_SPRING)
	_weather.refresh_daily(ABS_SPRING, 6)
	assert_false(_weather.refresh_daily(ABS_SPRING, 0).ok, "day 0 is refused")
	assert_false(_weather.refresh_daily(ABS_SPRING, DAYS_PER_SEASON + 1).ok, "day 13 is refused")
	assert_false(_weather.refresh_daily(ABS_NONE, 6).ok, "the empty absolute season -1 is refused")
	assert_equal(_weather.temperature_tenths(), 180, "the last good value is untouched")
	assert_equal(_weather.rain(), 1800, "for both columns")


func test_refresh_daily_never_applies_another_seasons_event() -> void:
	"""Ruling §4.2 CLOSED the partial season guard this test used to assert the limits of.

	BEHAVIOUR CHANGED DELIBERATELY (decision 0055). Before the I64 identity columns, a wrong
	season was caught only when §5.10 did not admit the stored row there -- so a summer-only
	drought asked about autumn REFUSED `EVENT_NOT_ELIGIBLE`, while an Any-season ideal spell
	scheduled for spring was silently APPLIED to a summer day. That second case was the hole.
	Now the row names the absolute season it was scheduled for, so BOTH cases resolve the same
	way: the event is simply not active on a day of any other season, and the day carries its own
	season's plain baseline. Neither case refuses, because neither is an error.
	"""
	var rng: Rng = _new_rng()
	assert_true(_schedule_event(ABS_SUMMER, DROUGHT, rng), "drought is reachable in summer")
	assert_true(_weather.refresh_daily(ABS_SUMMER, 6).ok, "its own season refreshes")
	assert_equal(_weather.temperature_tenths(), 300, "with drought's 30°C")
	assert_true(_weather.refresh_daily(ABS_AUTUMN, 6).ok, "an autumn day refreshes too")
	assert_equal(_weather.temperature_tenths(), 100,
		"but carries autumn's own 10°C baseline, not a summer-only drought's 30°C")
	assert_equal(_weather.active_event_on(ABS_AUTUMN, 6), NONE, "no event is active there")
	_weather.clear()
	_weather.schedule_first_spring_event(ABS_SPRING)
	assert_true(_weather.refresh_daily(ABS_SUMMER, 6).ok, "the ANY-season hole is closed too")
	assert_equal(_weather.temperature_tenths(), 220,
		"summer day 6 is summer's 22°C, not spring's ideal spell 18°C")
	assert_true(_weather.refresh_daily(ABS_SPRING, 6).ok, "its own spring day still refreshes")
	assert_equal(_weather.temperature_tenths(), 180, "and there it IS the ideal spell's 18°C")


func test_ending_an_event_removes_its_modifiers_and_keeps_the_forecast() -> void:
	"""REQ-SET-145: remove the temporary modifiers; the disclosed forecast is retained."""
	_weather.schedule_first_spring_event(ABS_SPRING)
	_weather.disclose_forecast(ABS_SPRING, 3)
	_weather.refresh_daily(ABS_SPRING, 7)
	var result: Weather.OpResult = _weather.end_event(ABS_SPRING)
	assert_true(result.ok, "the event ends")
	assert_equal(result.value, IDEAL, "and reports which event was removed")
	assert_equal(_weather.event_of(), NONE, "no event remains scheduled")
	assert_equal(_weather.start_day(), 0, "its start day is cleared")
	assert_equal(_weather.duration_days(), 0, "its duration is cleared")
	assert_equal(_weather.temperature_tenths(), 120, "the temperature returns to the baseline")
	assert_equal(_weather.rain(), 1200, "and so does the rain")
	assert_equal(_weather.forecast_event(), IDEAL, "REQ-SET-142's forecast is retained")
	assert_equal(_weather.forecast_start_day(), 6, "with its start day")
	assert_equal(_weather.forecast_duration_days(), 3, "and its duration")


func test_ending_an_event_twice_is_refused_and_consumes_no_draw() -> void:
	"""There is nothing left to remove, and removal never touches the stream."""
	var rng: Rng = _new_rng()
	_weather.schedule_season_event(ABS_WINTER, rng)
	var count: int = rng.draw_count_of(Rng.STREAM_WEATHER).value
	assert_true(_weather.end_event(ABS_WINTER).ok, "the first removal succeeds")
	var second: Weather.OpResult = _weather.end_event(ABS_WINTER)
	assert_false(second.ok, "the second is refused")
	assert_equal(second.error, Weather.REFUSE_NO_EVENT_SCHEDULED, "with the stated reason")
	assert_equal(rng.draw_count_of(Rng.STREAM_WEATHER).value, count, "and consumed no draw")
	assert_false(_weather.end_event(ABS_NONE).ok, "the empty absolute season is refused too")


func test_an_ended_event_leaves_the_window_readers_empty() -> void:
	"""After removal no day carries a modifier, which is what "remove its temporary modifiers"
	means for every reader that consults the window."""
	_weather.schedule_first_spring_event(ABS_SPRING)
	_weather.end_event(ABS_SPRING)
	for day: int in range(1, DAYS_PER_SEASON + 1):
		assert_false(_weather.is_event_active(ABS_SPRING, day), "day %d carries no event" % day)
		assert_equal(_weather.active_event_on(ABS_SPRING, day), NONE, "day %d has no modifier" % day)


func test_season_days_run_from_one_to_twelve() -> void:
	"""REQ-SET-006's twelve-day season, read from sim_clock.gd rather than mirrored."""
	assert_equal(Weather.DAYS_PER_SEASON, SimClock.DAYS_PER_SEASON,
		"the module reads the clock's own season length")
	assert_equal(Weather.DAYS_PER_SEASON, DAYS_PER_SEASON, "which REQ-SET-006 fixes at 12")
	assert_false(_weather.is_season_day(0), "day 0 is not a season day")
	assert_true(_weather.is_season_day(1), "day 1 is the first")
	assert_true(_weather.is_season_day(12), "day 12 is the last")
	assert_false(_weather.is_season_day(13), "day 13 belongs to the next season")
	assert_true(_weather.is_season_first_day(1), "day 1 is the boundary REQ-SET-141 acts at")
	assert_false(_weather.is_season_first_day(2), "day 2 is not")


func test_the_season_enum_comes_from_the_protected_catalog_table() -> void:
	"""Decision 0018: §4.3's numbered enums are read from catalog.gd, never mirrored locally."""
	assert_equal(Weather.SEASON_SPRING, SPRING, "§4.3: SPRING=0")
	assert_equal(Weather.SEASON_SUMMER, SUMMER, "§4.3: SUMMER=1")
	assert_equal(Weather.SEASON_AUTUMN, AUTUMN, "§4.3: AUTUMN=2")
	assert_equal(Weather.SEASON_WINTER, WINTER, "§4.3: WINTER=3")
	assert_true(_weather.is_season(0), "season 0 exists")
	assert_true(_weather.is_season(3), "season 3 exists")
	assert_false(_weather.is_season(4), "season 4 does not")
	assert_false(_weather.is_season(-1), "nor season -1")


func test_the_season_boundary_is_the_exact_midnight_of_a_new_season() -> void:
	"""REQ-SET-141 acts "at the exact boundary", which sim_clock.gd's own decode locates."""
	var first_season_boundary: int = 11 * SimClock.TICKS_PER_DAY + SimClock.FIRST_MIDNIGHT_TICK
	var calendar: SimClock.Calendar = SimClock.calendar_at(first_season_boundary)
	assert_equal(calendar.absolute_day, 13, "absolute day 13 opens the second season")
	assert_equal(calendar.season, SUMMER, "which is summer")
	assert_equal(calendar.season_day, 1, "on its first local day")
	assert_true(_weather.is_season_boundary_tick(first_season_boundary),
		"that midnight is a season boundary")
	assert_false(_weather.is_season_boundary_tick(first_season_boundary - 1),
		"the tick before it is not")
	assert_false(_weather.is_season_boundary_tick(first_season_boundary + 1),
		"nor the tick after it")


func test_an_ordinary_midnight_is_not_a_season_boundary() -> void:
	"""The first midnight opens day 2, which is not a new season."""
	assert_false(_weather.is_season_boundary_tick(SimClock.FIRST_MIDNIGHT_TICK),
		"tick 13500 opens day 2, inside spring")
	assert_false(_weather.is_season_boundary_tick(0), "tick 0 is 06:00 of day 1 and opens no day")
	assert_true(_weather.is_season_boundary_tick(
		35 * SimClock.TICKS_PER_DAY + SimClock.FIRST_MIDNIGHT_TICK),
		"absolute day 37 opens the fourth season")
	assert_false(_weather.is_season_boundary_tick(
		36 * SimClock.TICKS_PER_DAY + SimClock.FIRST_MIDNIGHT_TICK),
		"absolute day 38 is winter's second day")


# --- ruling 2026-09-11 §4.2: the two I64 identity columns (decision 0055) -------------------------

func test_the_amended_row_is_eight_i32_columns_plus_two_i64_columns() -> void:
	"""Ruling §4.2: "+16 payload bytes, taking Weather from 32 to 48"."""
	assert_equal(Weather.ROW_COLUMN_COUNT, ROW_COLUMNS, "§4.2's eight I32 columns are unchanged")
	assert_equal(Weather.ROW64_COLUMN_COUNT, 2, "and exactly two I64 columns are added")
	assert_equal(ROW_COLUMNS * 4 + Weather.ROW64_COLUMN_COUNT * 8, 48,
		"8 I32 at 4 bytes plus 2 I64 at 8 bytes is 48, which is 32 + the ruled 16")
	assert_equal(Weather.COL64_SCHEDULED_ABSOLUTE_SEASON, 0, "scheduled identity is column 0")
	assert_equal(Weather.COL64_FORECAST_ABSOLUTE_SEASON, 1, "forecast identity is column 1")
	assert_equal(Weather.ABSOLUTE_SEASON_NONE, ABS_NONE, "both are empty at -1")
	assert_equal(Weather.SCHEMA_VERSION, 2, "this payload is version 2")


func test_a_cleared_row_has_no_temporal_identity_at_all() -> void:
	"""Ruling §4.3: "zero-filled weather is not valid opening weather" -- including the latch."""
	_weather.schedule_first_spring_event(ABS_SPRING)
	_weather.disclose_forecast(ABS_SPRING, 3)
	assert_equal(_weather.scheduled_absolute_season(), ABS_SPRING, "the latch is written")
	assert_equal(_weather.forecast_absolute_season(), ABS_SPRING, "and so is the forecast's")
	_weather.clear()
	assert_equal(_weather.scheduled_absolute_season(), ABS_NONE, "clear() empties the latch")
	assert_equal(_weather.forecast_absolute_season(), ABS_NONE, "and the forecast identity")
	assert_false(_weather.is_season_scheduled(ABS_SPRING),
		"so spring of year 1 is NOT considered already scheduled, which 0 would have implied")


func test_the_absolute_season_is_the_floor_of_day_minus_one_over_twelve() -> void:
	"""Ruling §4.2: `absolute_season = floor((absolute_day-1)/12)`, transcribed day by day."""
	var days: Array[int] = [1, 12, 13, 24, 25, 36, 37, 48, 49, 60]
	var expected: Array[int] = [0, 0, 1, 1, 2, 2, 3, 3, 4, 4]
	for index: int in days.size():
		var got: IntMath.IntResult = _weather.absolute_season_of_day(days[index])
		assert_true(got.ok, "absolute day %d has a season" % days[index])
		assert_equal(got.value, expected[index],
			"absolute day %d falls in absolute season %d" % [days[index], expected[index]])
	assert_false(_weather.absolute_season_of_day(0).ok, "day 0 precedes the calendar")
	assert_false(_weather.absolute_season_of_day(-1).ok, "and so does day -1")


func test_the_matching_season_ordinal_is_the_absolute_season_modulo_four() -> void:
	"""Ruling §4.2: "a matching current season is `absolute_season % 4`"."""
	assert_equal(Weather.season_of_absolute_season(ABS_SPRING), SPRING, "0 is spring")
	assert_equal(Weather.season_of_absolute_season(ABS_SUMMER), SUMMER, "1 is summer")
	assert_equal(Weather.season_of_absolute_season(ABS_AUTUMN), AUTUMN, "2 is autumn")
	assert_equal(Weather.season_of_absolute_season(ABS_WINTER), WINTER, "3 is winter")
	assert_equal(Weather.season_of_absolute_season(ABS_SPRING_Y2), SPRING, "4 is spring again")
	assert_equal(Weather.season_of_absolute_season(ABS_AUTUMN_Y2), AUTUMN, "6 is autumn again")
	assert_true(_weather.is_absolute_season(ABS_SPRING), "0 is a real absolute season")
	assert_false(_weather.is_absolute_season(ABS_NONE), "-1 is the empty value, not a season")


func test_a_scheduled_event_is_not_active_in_another_absolute_season() -> void:
	"""Ruling §4.2: "The scheduled event is not automatically active"."""
	var rng: Rng = _new_rng()
	assert_true(_schedule_event(ABS_SUMMER, BLIGHT, rng), "blight is reachable in summer")
	assert_true(_weather.is_event_active(ABS_SUMMER, 6), "day 6 of THAT summer is covered")
	assert_false(_weather.is_event_active(ABS_AUTUMN, 6), "the following autumn is not")
	assert_false(_weather.is_event_active(ABS_SUMMER_Y2, 6), "nor next year's summer")
	assert_equal(_weather.active_event_on(ABS_SUMMER_Y2, 6), NONE,
		"which the repeating 0-3 ordinal could never have distinguished")
	assert_true(_weather.is_season_scheduled(ABS_SUMMER), "the latch names that one summer")
	assert_false(_weather.is_season_scheduled(ABS_SUMMER_Y2), "and no other")


func test_the_event_window_is_half_open_at_start_plus_duration() -> void:
	"""Ruling §4.2: activity requires "the half-open day interval `[start,start+duration)`"."""
	_weather.schedule_first_spring_event(ABS_SPRING)
	assert_equal(_weather.start_day(), 6, "the fixture starts on day 6")
	assert_equal(_weather.duration_days(), 3, "and runs three days")
	for day: int in range(1, DAYS_PER_SEASON + 1):
		var inside: bool = day >= 6 and day < 6 + 3
		assert_equal(_weather.is_event_active(ABS_SPRING, day), inside,
			"day %d is %s the half-open window" % [day, "inside" if inside else "outside"])
	assert_true(_weather.is_event_active(ABS_SPRING, 8), "start+duration-1 is the last day in")
	assert_false(_weather.is_event_active(ABS_SPRING, 9), "start+duration itself is out")


func test_the_scheduled_once_latch_refuses_a_second_draw_for_one_season() -> void:
	"""§5.10's "exactly one major event occurs per season", enforced, not merely asked for."""
	var rng: Rng = _new_rng()
	assert_true(_weather.schedule_season_event(ABS_SUMMER, rng).ok, "summer is scheduled once")
	var first_event: int = _weather.event_of()
	var draws: int = rng.draw_count_of(Rng.STREAM_WEATHER).value
	var again: Weather.OpResult = _weather.schedule_season_event(ABS_SUMMER, rng)
	assert_false(again.ok, "a second call for the same absolute season is refused")
	assert_equal(again.error, Weather.REFUSE_SEASON_ALREADY_SCHEDULED, "with the stated reason")
	assert_equal(rng.draw_count_of(Rng.STREAM_WEATHER).value, draws,
		"and consumes no draw, so a replay cannot desynchronise")
	assert_equal(_weather.event_of(), first_event, "the stored event is untouched")
	assert_true(_weather.schedule_season_event(ABS_AUTUMN, rng).ok, "the NEXT season still draws")
	assert_equal(rng.draw_count_of(Rng.STREAM_WEATHER).value, draws + 1, "taking exactly one")


func test_the_latch_survives_expiry_and_moves_only_on_a_new_schedule() -> void:
	"""Ruling §4.2: "Keep scheduled_absolute_season through expiry as the scheduled-once latch"."""
	var rng: Rng = _new_rng()
	assert_true(_weather.schedule_season_event(ABS_SUMMER, rng).ok, "summer is scheduled")
	assert_true(_weather.end_event(ABS_SUMMER).ok, "and its window expires")
	assert_false(_weather.is_event_scheduled(), "no event is scheduled any more")
	assert_equal(_weather.scheduled_absolute_season(), ABS_SUMMER, "but the latch still stands")
	var replay: Weather.OpResult = _weather.schedule_season_event(ABS_SUMMER, rng)
	assert_false(replay.ok, "so the expired season cannot be drawn a second time")
	assert_true(_weather.schedule_season_event(ABS_AUTUMN, rng).ok, "autumn schedules")
	assert_equal(_weather.scheduled_absolute_season(), ABS_AUTUMN,
		"and only a SUCCESSFUL schedule moves the latch")


func test_a_disclosed_forecast_keeps_its_absolute_season_after_expiry() -> void:
	"""Ruling §4.2: "A disclosed forecast retains its absolute-season identity after expiry"."""
	var rng: Rng = _new_rng()
	assert_true(_schedule_event(ABS_AUTUMN, EARLY_FROST, rng), "early frost is reachable")
	assert_true(_weather.disclose_forecast(ABS_AUTUMN, 7).ok, "day 7 discloses the day-10 event")
	assert_equal(_weather.forecast_absolute_season(), ABS_AUTUMN, "with autumn's own identity")
	assert_true(_weather.end_event(ABS_AUTUMN).ok, "the event then expires")
	assert_equal(_weather.forecast_event(), EARLY_FROST, "the calendar keeps the forecast")
	assert_equal(_weather.forecast_start_day(), 10, "with its start day")
	assert_equal(_weather.forecast_absolute_season(), ABS_AUTUMN,
		"and with the year it happened in, not merely 'some autumn'")


func test_disclosure_refuses_a_season_the_row_was_not_scheduled_for() -> void:
	"""A forecast belongs to the season whose event it describes, and to no other."""
	_weather.schedule_first_spring_event(ABS_SPRING)
	var wrong: Weather.OpResult = _weather.disclose_forecast(ABS_SUMMER, 3)
	assert_false(wrong.ok, "summer cannot disclose spring's scheduled event")
	assert_equal(wrong.error, Weather.REFUSE_SEASON_IDENTITY_MISMATCH, "with the stated reason")
	assert_false(_weather.is_forecast_disclosed(), "and nothing was written")
	assert_false(_weather.is_forecast_due(ABS_SUMMER, 3), "nor is one due there")
	assert_true(_weather.is_forecast_due(ABS_SPRING, 3), "it is due in its own season")
	assert_false(_weather.disclose_forecast(ABS_NONE, 3).ok, "the empty identity is refused")


func test_the_forced_first_spring_refuses_any_other_absolute_season() -> void:
	"""`floor((absolute_day-1)/12)` is 0 for exactly year 1's spring, so nothing else is forced."""
	var late: Weather.OpResult = _weather.schedule_first_spring_event(ABS_SPRING_Y2)
	assert_false(late.ok, "year 2's spring is not the onboarding season")
	assert_equal(late.error, Weather.REFUSE_NOT_FIRST_ABSOLUTE_SEASON, "with the stated reason")
	assert_false(_weather.is_event_scheduled(), "and no event was written")
	assert_false(_weather.schedule_first_spring_event(ABS_NONE).ok, "nor is -1 the first spring")
	assert_true(_weather.schedule_first_spring_event(ABS_SPRING).ok, "absolute season 0 is")
	var twice: Weather.OpResult = _weather.schedule_first_spring_event(ABS_SPRING)
	assert_false(twice.ok, "and even it is forced only once")
	assert_equal(twice.error, Weather.REFUSE_SEASON_ALREADY_SCHEDULED, "by the same latch")


# --- ruling 2026-09-11 §4.2: the versioned effect mask --------------------------------------------

func test_the_twelve_effect_bits_are_the_ruled_positions_zero_to_eleven() -> void:
	"""Ruling §4.2 fixes the ORDER as well as the twelve names; transcribed here independently."""
	var ruled: Array[int] = [
		Weather.AFFECTS_TEMPERATURE, Weather.AFFECTS_RAIN, Weather.AFFECTS_MOISTURE,
		Weather.AFFECTS_CROP_GROWTH, Weather.AFFECTS_CROP_DAMAGE, Weather.AFFECTS_OUTDOOR_WORK,
		Weather.AFFECTS_BOATS, Weather.AFFECTS_EXPOSURE, Weather.AFFECTS_LAKE_ICE,
		Weather.AFFECTS_MUSSEL_HARVEST, Weather.AFFECTS_ORCHARD_WATER, Weather.AFFECTS_FROST,
	]
	assert_equal(Weather.EFFECT_MASK_BIT_COUNT, 12, "the mask has twelve positions")
	assert_equal(ruled.size(), Weather.EFFECT_MASK_BIT_COUNT, "and twelve names to fill them")
	for position: int in ruled.size():
		assert_equal(ruled[position], 1 << position,
			"ruled effect bit %d is 1 << %d" % [position, position])
	assert_equal(Weather.EFFECT_MASK_VERSION, 1, "the mask is versioned, not anonymous")


func test_the_effect_mask_strips_mussel_harvest_for_non_summer_blight() -> void:
	"""Ruling §4.2: "Strip MUSSEL_HARVEST for non-summer blight"."""
	var summer: int = _weather.effect_mask_for(BLIGHT, SUMMER).value
	var autumn: int = _weather.effect_mask_for(BLIGHT, AUTUMN).value
	assert_true((summer & Weather.AFFECTS_MUSSEL_HARVEST) != 0, "summer blight closes mussels")
	assert_true((autumn & Weather.AFFECTS_MUSSEL_HARVEST) == 0, "autumn blight does not")
	assert_true((autumn & Weather.AFFECTS_CROP_DAMAGE) != 0,
		"but autumn blight still damages crops, so the strip removes ONE bit and no more")
	assert_equal(autumn, summer & ~Weather.AFFECTS_MUSSEL_HARVEST,
		"exactly the mussel bit separates the two seasons' masks")
	assert_equal(_weather.affected_systems_mask_of(BLIGHT).value, summer,
		"the raw table row is the summer reading")
	assert_false(_weather.effect_mask_for(BLIGHT, 4).ok, "a fifth season has no mask")
	assert_equal(_weather.effect_mask_for(NONE, SUMMER).value, 0, "and no event affects nothing")


func test_a_temperature_or_rain_event_is_never_reported_as_crops_only() -> void:
	"""Ruling §4.2: "a coarse mask must not falsely report 'crops only'"."""
	var crop_bits: int = Weather.AFFECTS_CROP_GROWTH | Weather.AFFECTS_CROP_DAMAGE
	var weather_bits: int = Weather.AFFECTS_TEMPERATURE | Weather.AFFECTS_RAIN
	var rows: Array[int] = [DROUGHT, HEAVY_RAIN, HARD_FREEZE, EARLY_FROST, IDEAL]
	var seasons: Array[int] = [SUMMER, SPRING, WINTER, AUTUMN, SPRING]
	for index: int in rows.size():
		var mask: int = _weather.effect_mask_for(rows[index], seasons[index]).value
		assert_true((mask & weather_bits) != 0,
			"row %d states a temperature or rain change" % rows[index])
		assert_true((mask & ~crop_bits) != 0,
			"so row %d reaches beyond crops -- orchards, storage aging, heating" % rows[index])
	assert_equal(_weather.effect_mask_for(CALM, SPRING).value, 0,
		"calm days alone states no modifier at all")


func test_calm_days_has_no_modifiers_and_still_gets_its_forecast() -> void:
	"""Ruling §4.2: "Calm days has no modifiers but still gets its required forecast"."""
	var rng: Rng = _new_rng()
	assert_true(_schedule_event(ABS_SPRING, CALM, rng), "calm days is reachable in spring")
	assert_equal(_weather.event_of(), CALM, "the row records calm days")
	assert_true(_weather.is_forecast_due(ABS_SPRING, 3), "its forecast still falls due on day 3")
	assert_true(_weather.disclose_forecast(ABS_SPRING, 3).ok, "and is disclosed")
	assert_equal(_weather.forecast_event(), CALM, "naming calm days")
	assert_equal(_weather.forecast_start_day(), 6, "with §5.10's start day")
	assert_equal(_weather.forecast_duration_days(), 2, "and its two-day duration")
	assert_equal(_weather.forecast_absolute_season(), ABS_SPRING, "and its season identity")
	var mask: IntMath.IntResult = _weather.forecast_effect_mask()
	assert_true(mask.ok, "the disclosed mask is answered, not refused")
	assert_equal(mask.value, 0, "and is empty, because calm days states no modifier")


func test_closes_mussel_harvest_on_is_summer_blight_and_nothing_else() -> void:
	"""Ruling §4.1's predicate: `new_season == SUMMER && active_new_day_event == BLIGHT`."""
	var rng: Rng = _new_rng()
	assert_true(_schedule_event(ABS_SUMMER, BLIGHT, rng), "blight is reachable in summer")
	assert_true(_weather.closes_mussel_harvest_on(ABS_SUMMER, 6), "summer day 6 closes")
	assert_true(_weather.closes_mussel_harvest_on(ABS_SUMMER, 8), "and so does day 8")
	assert_false(_weather.closes_mussel_harvest_on(ABS_SUMMER, 9),
		"day 9 is the day after expiry and reopens")
	assert_false(_weather.closes_mussel_harvest_on(ABS_SUMMER, 5), "day 5 precedes the window")
	assert_false(_weather.closes_mussel_harvest_on(ABS_AUTUMN, 6), "another season never closes")
	_weather.clear()
	assert_true(_schedule_event(ABS_AUTUMN, BLIGHT, rng), "blight is reachable in autumn too")
	assert_true(_weather.is_blight_active(ABS_AUTUMN, 6), "and that autumn blight IS active")
	assert_false(_weather.closes_mussel_harvest_on(ABS_AUTUMN, 6),
		"yet it permits the mussel harvest, because §5.10 closes it in SUMMER only")


func test_a_non_blight_event_never_closes_the_mussel_harvest() -> void:
	"""The forced ideal spell must not answer the closure question affirmatively."""
	_weather.schedule_first_spring_event(ABS_SPRING)
	for day: int in range(1, DAYS_PER_SEASON + 1):
		assert_false(_weather.closes_mussel_harvest_on(ABS_SPRING, day),
			"an ideal spell closes no mussel bed on day %d" % day)


# --- ruling 2026-09-11 §4.2: the codec's ambiguity rule -------------------------------------------

func test_an_old_snapshot_without_season_identity_is_refused() -> void:
	"""Ruling §4.2: "Reject an ambiguous old snapshot if the absolute season cannot be proven"."""
	var rng: Rng = _new_rng()
	assert_true(_schedule_event(ABS_WINTER, HARD_FREEZE, rng), "hard freeze is winter-only")
	var legacy: Weather.OpResult = _weather.adopt_snapshot_identity(
		Weather.SCHEMA_VERSION_NO_SEASON_IDENTITY, ABS_WINTER, ABS_NONE)
	assert_false(legacy.ok, "a version 1 payload is refused")
	assert_equal(legacy.error, Weather.REFUSE_AMBIGUOUS_SNAPSHOT_SEASON, "as ambiguous")
	assert_equal(_weather.scheduled_absolute_season(), ABS_WINTER, "and nothing was overwritten")
	var future: Weather.OpResult = _weather.adopt_snapshot_identity(99, ABS_WINTER, ABS_NONE)
	assert_false(future.ok, "an unknown version is refused too")
	assert_equal(future.error, Weather.REFUSE_UNKNOWN_SCHEMA_VERSION, "under its own code")


func test_a_snapshot_season_that_its_event_contradicts_is_refused() -> void:
	"""Never accept an identity §5.10's own eligibility column rules out."""
	var rng: Rng = _new_rng()
	assert_true(_schedule_event(ABS_WINTER, HARD_FREEZE, rng), "hard freeze is winter-only")
	var wrong: Weather.OpResult = _weather.adopt_snapshot_identity(
		Weather.SCHEMA_VERSION, ABS_SUMMER, ABS_NONE)
	assert_false(wrong.ok, "a hard freeze cannot have been scheduled for a summer")
	assert_equal(wrong.error, Weather.REFUSE_EVENT_NOT_ELIGIBLE, "with the stated reason")
	var missing: Weather.OpResult = _weather.adopt_snapshot_identity(
		Weather.SCHEMA_VERSION, ABS_NONE, ABS_NONE)
	assert_false(missing.ok, "a scheduled event with an empty identity is ambiguous")
	assert_equal(missing.error, Weather.REFUSE_AMBIGUOUS_SNAPSHOT_SEASON, "and is refused")
	assert_equal(_weather.scheduled_absolute_season(), ABS_WINTER, "nothing was overwritten")


func test_adopting_a_consistent_snapshot_identity_writes_both_columns() -> void:
	"""The success path: a version 2 payload whose identity its stored events admit."""
	var rng: Rng = _new_rng()
	assert_true(_schedule_event(ABS_WINTER, HARD_FREEZE, rng), "hard freeze is winter-only")
	assert_true(_weather.disclose_forecast(ABS_WINTER, 3).ok, "its forecast is disclosed")
	var adopted: Weather.OpResult = _weather.adopt_snapshot_identity(
		Weather.SCHEMA_VERSION, ABS_WINTER + 4, ABS_WINTER + 4)
	assert_true(adopted.ok, "a later year's winter is a consistent identity")
	assert_equal(adopted.value, ABS_WINTER + 4, "and is reported back")
	assert_equal(_weather.scheduled_absolute_season(), ABS_WINTER + 4, "the latch is rewritten")
	assert_equal(_weather.forecast_absolute_season(), ABS_WINTER + 4, "and so is the forecast")
	assert_true(_weather.is_event_active(ABS_WINTER + 4, 6), "the window follows the identity")
	assert_false(_weather.is_event_active(ABS_WINTER, 6), "and leaves the old year behind")


func test_an_event_eligible_in_several_seasons_is_named_as_such() -> void:
	"""Ruling §4.2: "never infer it solely from an event eligible in multiple seasons"."""
	assert_true(_weather.is_multi_season_event(IDEAL), "ideal spell is eligible in all four")
	assert_true(_weather.is_multi_season_event(CALM), "and so is calm days")
	assert_true(_weather.is_multi_season_event(BLIGHT), "blight is summer and autumn")
	assert_true(_weather.is_multi_season_event(HEAVY_RAIN), "heavy rain is spring and autumn")
	assert_false(_weather.is_multi_season_event(DROUGHT), "drought is summer-only")
	assert_false(_weather.is_multi_season_event(HARD_FREEZE), "hard freeze is winter-only")
	assert_false(_weather.is_multi_season_event(EARLY_FROST), "early frost is autumn-only")
	assert_false(_weather.is_multi_season_event(NONE), "and EVENT_NONE is no row at all")


func test_the_event_catalog_is_verifiable_for_the_boundary_preflight() -> void:
	"""Ruling §4.1's preflight reads this before a boundary may commit anything."""
	assert_true(_weather.catalog_is_verified(),
		"the compiled EventDefinition ids are what every §5.10 table is subscripted by")
