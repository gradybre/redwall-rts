extends "res://test/framework/test_case.gd"
## Coverage for the PROGRESS-C4-R01 version 2 continuous winter interval helper.
##
## EVERY EXPECTED DATE BELOW IS DERIVED FROM THE RULING AND THE PUBLISHED CALENDAR, NOT FROM THE
## MODULE UNDER TEST. The ruling fixes the award instant at tick 2569500 and the interval at
## 54000 ticks / 54001 observations. GDD 5.1's calendar is `(tick + 4500) mod 18000` with 18000
## ticks per day, 12 days per season and 48 days per year, so tick 2569500 has day index
## (2569500 + 4500) / 18000 = 143, giving year 143/48 + 1 = 3, season (143 % 48 = 47) / 12 = 3
## (winter), season day 47 % 12 + 1 = 12, and tick of day 0 (exact midnight). The surrounding
## boundary table is computed the same way and restated as literals here:
##
##   winter of year 3 : day indices 132..143 -> ticks 2371500 .. 2587499
##   T - 54000        : tick 2515500, day index 140, winter day 9, midnight
##   year 2 instant   : day index 95  -> tick 1705500 (winter day 12, midnight, year 2)
##   year 5 instant   : day index 239 -> tick 4297500 (winter day 12, midnight, year 5)
##
## The first test re-derives that table through the REAL SimClock calendar so a drift in either
## direction is caught, and every later test then asserts against these independent literals.

const Interval := preload("res://scripts/core/progression_interval.gd")
const SimClockScript := preload("res://scripts/core/sim_clock.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

## The award instant, and the 54000-tick-earlier endpoint the streak must already cover.
const T: int = 2569500
const T_MINUS_INTERVAL: int = 2515500
## Winter of year 3, first and last tick.
const WINTER3_START: int = 2371500
const WINTER3_END: int = 2587499
## The same calendar position one and two years away.
const YEAR2_T: int = 1705500
const YEAR2_T_MINUS_INTERVAL: int = 1651500
const YEAR5_T: int = 4297500
const YEAR5_T_MINUS_INTERVAL: int = 4243500
## INT64_MAX - CALENDAR_OFFSET_TICKS, written out rather than read off the module.
const MAX_TICK: int = 9223372036854771307

var _out: IntMath.IntResult = null


func before_each() -> void:
	"""One caller-owned result object per test, reused across calls exactly as an owner would."""
	_out = IntMath.IntResult.new()


func _assert_refused(refused: bool, label: String) -> void:
	"""Assert a refusal reported false AND left the documented ok/value/error shape behind."""
	assert_false(refused, "%s must refuse" % label)
	assert_false(_out.ok, "%s leaves ok false" % label)
	assert_equal(_out.value, 0, "%s zeroes the value" % label)
	assert_true(_out.error != "", "%s states a reason" % label)


func test_the_real_calendar_places_the_award_instant_where_the_ruling_says() -> void:
	"""Tick 2569500 is year 3, winter, day 12, 00:00, and the year-3 winter spans the table above."""
	var moment: SimClockScript.Calendar = SimClockScript.calendar_at(T)
	assert_equal(moment.year, 3, "T is in year 3")
	assert_equal(moment.season_name(), "winter", "T is in winter")
	assert_equal(moment.season_day, 12, "T is winter day 12")
	assert_equal(moment.tick_of_day, 0, "T is exact midnight")
	assert_equal(SimClockScript.calendar_at(WINTER3_START).season_name(), "winter",
		"2371500 is the first winter tick")
	assert_equal(SimClockScript.calendar_at(WINTER3_START - 1).season_name(), "autumn",
		"2371499 is still autumn")
	assert_equal(SimClockScript.calendar_at(WINTER3_END).season_name(), "winter",
		"2587499 is the last winter tick")
	assert_equal(SimClockScript.calendar_at(WINTER3_END + 1).season_name(), "spring",
		"2587500 has left winter")
	assert_equal(SimClockScript.calendar_at(T_MINUS_INTERVAL).season_day, 9,
		"T-54000 is winter day 9")
	assert_equal(Interval.REQUIRED_INTERVAL_TICKS, 54000, "the interval is 54000 ticks")
	assert_equal(Interval.REQUIRED_OBSERVATIONS, 54001, "observed as 54001 committed states")


func test_a_contiguous_54001_observation_window_awards() -> void:
	"""The ruling's pass case: every state from T-54000 through T inclusive, then eligibility."""
	var last: int = T_MINUS_INTERVAL - 1
	var since: int = -1
	var observations: int = 0
	var all_ok: bool = true
	var since_stable: bool = true
	var tick: int = T_MINUS_INTERVAL
	while tick <= T:
		if not Interval.advance_since_into(tick, last, since, true, _out):
			all_ok = false
			break
		since = _out.value
		last = tick
		observations += 1
		if since != T_MINUS_INTERVAL:
			since_stable = false
			break
		tick += 1
	assert_true(all_ok, "every contiguous observation is accepted")
	assert_true(since_stable, "the streak start never moves once set")
	assert_equal(observations, 54001, "the window is 54001 observations")
	assert_equal(last, T, "the final observation is T")
	assert_true(Interval.award_eligible_into(T, last, since, true, false, _out), "T is decidable")
	assert_equal(_out.value, 1, "a full 54001-observation window awards")


func test_starting_one_tick_late_is_one_observation_short() -> void:
	"""54000 intervals is the requirement; a streak beginning at T-53999 spans only 53999."""
	assert_true(Interval.award_eligible_into(T, T, T_MINUS_INTERVAL + 1, true, false, _out),
		"a late start is still a valid tuple")
	assert_equal(_out.value, 0, "starting one tick late is not eligible")
	assert_true(Interval.award_eligible_into(T, T, T_MINUS_INTERVAL, true, false, _out),
		"the exact endpoint is valid")
	assert_equal(_out.value, 1, "exactly 54000 intervals is enough")


func test_one_false_predicate_between_midnights_resets_the_streak() -> void:
	"""A single false observation mid-window restarts the streak and loses the award at T."""
	var break_tick: int = T - 30000
	assert_true(Interval.advance_since_into(break_tick, break_tick - 1, T_MINUS_INTERVAL, false,
		_out), "a false observation is still a valid observation")
	assert_equal(_out.value, -1, "a false predicate clears the streak")
	assert_true(Interval.advance_since_into(break_tick + 1, break_tick, -1, true, _out),
		"the next true observation restarts it")
	assert_equal(_out.value, break_tick + 1, "the new streak starts at the recovering tick")
	assert_true(Interval.award_eligible_into(T, T, break_tick + 1, true, false, _out),
		"the shortened streak is a valid tuple")
	assert_equal(_out.value, 0, "and it cannot award at T")


func test_a_false_predicate_at_the_award_instant_is_ineligible() -> void:
	"""False at T must answer 0 with since=-1, and must refuse a tuple claiming both."""
	assert_true(Interval.advance_since_into(T, T - 1, T_MINUS_INTERVAL, false, _out),
		"observing false at T is valid")
	assert_equal(_out.value, -1, "and clears the streak at the award instant itself")
	assert_true(Interval.award_eligible_into(T, T, -1, false, false, _out), "a valid false tuple")
	assert_equal(_out.value, 0, "false predicates never award")
	_assert_refused(Interval.award_eligible_into(T, T, T_MINUS_INTERVAL, false, false, _out),
		"false predicates with a live since")


func test_initialization_and_strict_observation_ordering() -> void:
	"""Tick 0 with last=-1 and since=-1 is the ONLY fresh observation; every skip refuses."""
	assert_true(Interval.advance_since_into(0, -1, -1, true, _out), "tick 0 initializes")
	assert_equal(_out.value, -1, "tick 0 is spring, so no streak starts")
	_assert_refused(Interval.advance_since_into(5, -1, -1, true, _out), "a fresh tick 5")
	_assert_refused(Interval.advance_since_into(0, -1, 3, true, _out), "a fresh tick with a since")
	_assert_refused(Interval.advance_since_into(T, T, T_MINUS_INTERVAL, true, _out),
		"a duplicate observation")
	_assert_refused(Interval.advance_since_into(T + 2, T, T_MINUS_INTERVAL, true, _out),
		"a skipped observation")
	_assert_refused(Interval.advance_since_into(T - 1, T, T_MINUS_INTERVAL, true, _out),
		"a reversed observation")
	_assert_refused(Interval.advance_since_into(-1, -2, -1, true, _out), "a negative tick")


func test_leaving_winter_resets_and_the_last_winter_tick_does_not() -> void:
	"""The streak survives to 2587499 and is gone at 2587500, which is spring."""
	assert_true(Interval.advance_since_into(WINTER3_END, WINTER3_END - 1, T_MINUS_INTERVAL, true,
		_out), "the last winter tick is observable")
	assert_equal(_out.value, T_MINUS_INTERVAL, "and preserves the streak")
	assert_true(Interval.advance_since_into(WINTER3_END + 1, WINTER3_END, T_MINUS_INTERVAL, true,
		_out), "the first spring tick is observable")
	assert_equal(_out.value, -1, "leaving winter resets the streak even with true predicates")


func test_winter_start_begins_a_new_since_and_cannot_inherit_one() -> void:
	"""A streak starts at 2371500 itself, and a since carried out of autumn is refused."""
	assert_true(Interval.advance_since_into(WINTER3_START - 1, WINTER3_START - 2, -1, true, _out),
		"the last autumn tick is observable")
	assert_equal(_out.value, -1, "autumn starts no streak")
	assert_true(Interval.advance_since_into(WINTER3_START, WINTER3_START - 1, -1, true, _out),
		"the first winter tick is observable")
	assert_equal(_out.value, WINTER3_START, "and the streak starts there")
	_assert_refused(Interval.advance_since_into(WINTER3_START, WINTER3_START - 1,
		YEAR2_T_MINUS_INTERVAL, true, _out), "a since carried in from a previous winter")


func test_malformed_future_and_prior_winter_since_values_refuse() -> void:
	"""A corrupt prior tuple is refused, never repaired and never reported as merely ineligible."""
	_assert_refused(Interval.advance_since_into(T, T - 1, -2, true, _out), "since -2")
	_assert_refused(Interval.advance_since_into(T, T - 1, T, true, _out), "a future since")
	_assert_refused(Interval.advance_since_into(T, T - 1, YEAR2_T_MINUS_INTERVAL, true, _out),
		"a since from a previous winter")
	_assert_refused(Interval.award_eligible_into(T, T, -2, true, false, _out), "award since -2")
	_assert_refused(Interval.award_eligible_into(T, T, T + 1, true, false, _out),
		"an award since after T")
	_assert_refused(Interval.award_eligible_into(T, T, YEAR2_T_MINUS_INTERVAL, true, false, _out),
		"an award since from a previous winter")
	_assert_refused(Interval.award_eligible_into(T, T - 1, T_MINUS_INTERVAL, true, false, _out),
		"an award whose final observation never happened")
	_assert_refused(Interval.award_eligible_into(WINTER3_END + 1, WINTER3_END + 1, WINTER3_END,
		true, false, _out), "a live since outside winter")
	_assert_refused(Interval.award_eligible_into(T, T, -1, true, false, _out),
		"true winter predicates with no since")


func test_year_two_never_awards_even_with_a_complete_window() -> void:
	"""Tick 1705500 is the same calendar instant one year early; the year gate is independent."""
	var moment: SimClockScript.Calendar = SimClockScript.calendar_at(YEAR2_T)
	assert_equal(moment.year, 2, "1705500 is year 2")
	assert_equal(moment.season_day, 12, "winter day 12")
	assert_equal(moment.tick_of_day, 0, "at exact midnight")
	assert_true(Interval.award_eligible_into(YEAR2_T, YEAR2_T, YEAR2_T_MINUS_INTERVAL, true, false,
		_out), "a full year-2 window is a valid tuple")
	assert_equal(_out.value, 0, "but year 2 is never eligible")


func test_a_later_year_still_awards() -> void:
	"""The gate is year>=3, not year==3: tick 4297500 is year 5 winter day 12 at midnight."""
	assert_equal(SimClockScript.calendar_at(YEAR5_T).year, 5, "4297500 is year 5")
	assert_equal(SimClockScript.calendar_at(YEAR5_T).season_day, 12, "winter day 12")
	assert_true(Interval.award_eligible_into(YEAR5_T, YEAR5_T, YEAR5_T_MINUS_INTERVAL, true, false,
		_out), "a full year-5 window is decidable")
	assert_equal(_out.value, 1, "and a later year still awards")


func test_the_ticks_adjacent_to_the_award_instant_are_not_the_award_instant() -> void:
	"""T-1 is winter day 11 at 23:59 and T+1 is one tick past midnight; neither may award."""
	assert_equal(SimClockScript.calendar_at(T - 1).season_day, 11, "T-1 is winter day 11")
	assert_equal(SimClockScript.calendar_at(T + 1).tick_of_day, 1, "T+1 is past midnight")
	assert_true(Interval.award_eligible_into(T - 1, T - 1, T_MINUS_INTERVAL - 1, true, false, _out),
		"T-1 is decidable")
	assert_equal(_out.value, 0, "the tick before the instant does not award")
	assert_true(Interval.award_eligible_into(T, T, T_MINUS_INTERVAL, true, false, _out),
		"T is decidable")
	assert_equal(_out.value, 1, "the instant itself awards")
	assert_true(Interval.award_eligible_into(T + 1, T + 1, T_MINUS_INTERVAL, true, false, _out),
		"T+1 is decidable")
	assert_equal(_out.value, 0, "one tick late is not the award instant, despite a longer streak")


func test_an_already_awarded_world_is_never_eligible_again() -> void:
	"""The award is once; the helper reports 0 rather than refusing a legitimate repeat question."""
	assert_true(Interval.award_eligible_into(T, T, T_MINUS_INTERVAL, true, true, _out),
		"an already-awarded world is still decidable")
	assert_equal(_out.value, 0, "and is not eligible again")


func test_a_restore_equivalent_scalar_handoff_reproduces_the_streak() -> void:
	"""The helper is stateless: two scalars carried across a save boundary are the whole history."""
	var last: int = WINTER3_START - 1
	var since: int = -1
	var tick: int = WINTER3_START
	while tick < WINTER3_START + 10:
		assert_true(Interval.advance_since_into(tick, last, since, true, _out), "observation runs")
		since = _out.value
		last = tick
		tick += 1
	assert_equal(since, WINTER3_START, "the pre-save streak starts at the winter's first tick")
	assert_equal(last, WINTER3_START + 9, "and the last observation is the tenth tick")
	var restored: IntMath.IntResult = IntMath.IntResult.new()
	assert_true(Interval.advance_since_into(last + 1, last, since, true, restored),
		"the restored scalars resume cleanly on a different result object")
	assert_equal(restored.value, WINTER3_START, "with the identical streak start")


func test_pause_is_represented_by_no_invocation() -> void:
	"""Caller protocol only: omit observations while paused, then reject a repeated tick. No clock is run."""
	var last: int = T - 2
	var since: int = T_MINUS_INTERVAL
	assert_true(Interval.advance_since_into(last + 1, last, since, true, _out), "one tick runs")
	since = _out.value
	last = last + 1
	var paused_frames: int = 0
	while paused_frames < 3:
		paused_frames += 1
	assert_equal(last, T - 1, "paused frames advance no observation")
	assert_equal(since, T_MINUS_INTERVAL, "and change no streak")
	_assert_refused(Interval.advance_since_into(last, last, since, true, _out),
		"a paused wall frame that re-observed its tick")
	assert_true(Interval.advance_since_into(last + 1, last, since, true, _out),
		"resuming observes the next tick")
	assert_equal(_out.value, T_MINUS_INTERVAL, "and the streak survived the pause untouched")
	assert_true(Interval.award_eligible_into(T, T, _out.value, true, false, _out), "T decidable")
	assert_equal(_out.value, 1, "the unchanged supplied tuple qualifies; this is not a clock-pause integration test")


func test_the_tick_domain_stops_at_the_calendar_addition_limit() -> void:
	"""0..INT64_MAX-4500 is accepted; one tick beyond refuses instead of overflowing the calendar."""
	assert_equal(Interval.MAX_OBSERVABLE_TICK, MAX_TICK, "the ceiling is INT64_MAX minus 4500")
	assert_true(Interval.advance_since_into(MAX_TICK, MAX_TICK - 1, -1, false, _out),
		"the ceiling tick is observable")
	assert_equal(_out.value, -1, "a false predicate there clears the streak whatever its season")
	_assert_refused(Interval.advance_since_into(MAX_TICK + 1, MAX_TICK, -1, false, _out),
		"one tick past the ceiling")
	_assert_refused(Interval.advance_since_into(0, MAX_TICK + 1, -1, false, _out),
		"a last observation past the ceiling")
	assert_true(Interval.award_eligible_into(MAX_TICK, MAX_TICK, -1, false, false, _out),
		"the ceiling tick is decidable")
	assert_equal(_out.value, 0, "and false predicates award nothing there")
	_assert_refused(Interval.award_eligible_into(MAX_TICK + 1, MAX_TICK + 1, -1, false, false,
		_out), "an award past the ceiling")
