extends "res://test/framework/test_case.gd"
## Coverage for the fixed simulation clock: offset calendar mapping, the 0/1/2/4
## speed set, the pause-reason mask, retained scheduler debt, and the REQ-SET-008
## overload ladder.
##
## The prototype's `GameManager` speed tests are deliberately not ported. They
## asserted a [1.0, 2.0, 3.0] float multiplier cycle driving `Engine.time_scale`,
## which contradicts REQ-SET-003 and the Speed 0/1/2/4 enum on three counts: there
## is no 3x, authoritative time is integer, and host frame scaling is a scheduler
## input rather than a gameplay rate. The prototype keeps running against its own
## suite until it is retired (ARCH-MIG-006 step 2).
##
## Blocker U2: there are no queued speed/pause command tests, because no command
## kind, ordering tiebreak or save section exists for them yet.

const SimClockScript := preload("res://scripts/core/sim_clock.gd")

## 0.05 real seconds. Chosen so debt lands on whole ticks at 2x and 4x and stays
## under the 8-tick frame ceiling at every speed, making tick counts exact.
const FRAME_USEC: int = 50000
const FRAMES_PER_REAL_SECOND: int = 20
## One full real second of backlog at 4x: far past the 0.25 s overload limit.
const OVERLOAD_FRAME_USEC: int = 1000000

var _clock: SimClockScript = null
var _step_calls: int = 0
var _boundary_ticks: Array[int] = []
var _boundary_days: Array[int] = []


func before_each() -> void:
	"""Fresh clock, player pause released, running at 1x with empty callback records."""
	_clock = SimClockScript.new()
	assert_true(_clock.set_pause(SimClockScript.PLAYER, false), "initial player pause releases")
	_step_calls = 0
	_boundary_ticks = []
	_boundary_days = []
	_boundary_moments = []


func _count_step() -> void:
	"""Step callback that records how many ticks the scheduler ran."""
	_step_calls += 1


func _record_boundary(moment: SimClockScript.Calendar) -> void:
	"""Day-boundary callback that records the tick and day of each 00:00 crossing."""
	_boundary_ticks.append(moment.tick)
	_boundary_days.append(moment.absolute_day)


func _run_frames(frames: int, elapsed_usec: int) -> int:
	"""Advance a fixed number of host frames of equal length; return total ticks run."""
	var total: int = 0
	for _index: int in frames:
		total += _clock.advance(elapsed_usec)
	return total


func _run_until_tick(target: int) -> void:
	"""Drive the clock at 4x with recording callbacks until it reaches at least `target`."""
	assert_true(_clock.set_speed(SimClockScript.SPEED_QUADRUPLE), "4x accepted")
	while _clock.completed_tick() < target:
		_clock.advance(FRAME_USEC, _count_step, _record_boundary)


# --- calendar mapping ----------------------------------------------------------------------------

func test_tick_zero_is_six_in_the_morning_of_spring_day_one() -> void:
	"""REQ-SET-006: the clock starts at year 1, spring, day 1, 06:00 -- not at midnight."""
	var moment: SimClockScript.Calendar = SimClockScript.calendar_at(0)
	assert_equal(moment.hour, 6, "tick 0 hour")
	assert_equal(moment.minute, 0, "tick 0 minute")
	assert_equal(moment.absolute_day, 1, "tick 0 absolute day")
	assert_equal(moment.year, 1, "tick 0 year")
	assert_equal(moment.season, 0, "tick 0 season")
	assert_equal(moment.season_name(), "spring", "tick 0 season name")
	assert_equal(moment.season_day, 1, "tick 0 season day")
	assert_equal(moment.clock_text(), "06:00", "tick 0 clock text")


func test_first_midnight_is_tick_13500() -> void:
	"""GDD §5.1: the first 00:00 falls at tick 13500, opening absolute day 2."""
	var before: SimClockScript.Calendar = SimClockScript.calendar_at(13499)
	assert_equal(before.hour, 23, "tick 13499 hour")
	assert_equal(before.absolute_day, 1, "tick 13499 absolute day")
	var midnight: SimClockScript.Calendar = SimClockScript.calendar_at(SimClockScript.FIRST_MIDNIGHT_TICK)
	assert_equal(midnight.hour, 0, "tick 13500 hour")
	assert_equal(midnight.minute, 0, "tick 13500 minute")
	assert_equal(midnight.absolute_day, 2, "tick 13500 absolute day")
	assert_equal(midnight.season_day, 2, "tick 13500 season day")
	assert_equal(midnight.year, 1, "tick 13500 year")


func test_hours_and_minutes_advance_at_750_ticks_per_hour() -> void:
	"""REQ-SET-006: 750 ticks make an hour, so a half hour is 375 ticks."""
	assert_equal(SimClockScript.calendar_at(374).minute, 29, "tick 374 minute")
	assert_equal(SimClockScript.calendar_at(375).clock_text(), "06:30", "tick 375 clock text")
	assert_equal(SimClockScript.calendar_at(749).hour, 6, "tick 749 hour")
	assert_equal(SimClockScript.calendar_at(750).clock_text(), "07:00", "tick 750 clock text")
	assert_equal(SimClockScript.calendar_at(750 * 17).clock_text(), "23:00", "tick 12750 clock text")


func _first_boundary_tick_by_scan() -> int:
	"""The earliest positive tick the module itself calls a day boundary, found by scanning.

	Scanned rather than read from FIRST_MIDNIGHT_TICK so the assertion is about what
	is_day_boundary() does, not about two constants agreeing with each other. A full day of
	ticks is scanned, so a raw-modulo rule would be caught at 18000 as readily as at 13500.
	"""
	for tick: int in range(1, SimClockScript.TICKS_PER_DAY + 1):
		if SimClockScript.is_day_boundary(tick):
			return tick
	fail("no day boundary in the first full day of ticks")
	return 0


func test_day_boundaries_use_the_offset_calendar_not_raw_modulo() -> void:
	"""Boundaries are crossings of `(tick+4500) mod 18000`, never `tick mod 18000 == 0`."""
	var first_boundary: int = _first_boundary_tick_by_scan()
	assert_equal(first_boundary, SimClockScript.FIRST_MIDNIGHT_TICK, "the first boundary the module reports is 13500")
	assert_true(first_boundary % SimClockScript.TICKS_PER_DAY != 0, "that boundary is not a raw multiple of the day length")
	assert_true(SimClockScript.is_day_boundary(13500), "tick 13500 opens day 2")
	assert_false(SimClockScript.is_day_boundary(18000), "tick 18000 is 06:00 of day 2, not a boundary")
	assert_equal(SimClockScript.calendar_at(18000).hour, 6, "tick 18000 hour")
	assert_equal(SimClockScript.calendar_at(18000).absolute_day, 2, "tick 18000 absolute day")
	assert_false(SimClockScript.is_day_boundary(0), "tick 0 is 06:00 and opens no new day")
	assert_true(SimClockScript.is_day_boundary(31500), "second midnight")
	assert_true(SimClockScript.is_day_boundary(49500), "third midnight")


func test_day_index_increments_only_at_offset_midnights() -> void:
	"""day_index_at() is the single derivation every consumer shares."""
	assert_equal(SimClockScript.day_index_at(0), 0, "day index at tick 0")
	assert_equal(SimClockScript.day_index_at(13499), 0, "day index just before first midnight")
	assert_equal(SimClockScript.day_index_at(13500), 1, "day index at first midnight")
	assert_equal(SimClockScript.day_index_at(18000), 1, "day index at 06:00 of day 2")
	assert_equal(SimClockScript.day_index_at(31499), 1, "day index just before second midnight")
	assert_equal(SimClockScript.day_index_at(31500), 2, "day index at second midnight")


func test_season_rolls_over_after_twelve_days() -> void:
	"""REQ-SET-006: a season is 12 days, so absolute day 13 is summer day 1."""
	var last_spring: SimClockScript.Calendar = SimClockScript.calendar_at(211499)
	assert_equal(last_spring.absolute_day, 12, "last spring absolute day")
	assert_equal(last_spring.season, 0, "last spring season")
	assert_equal(last_spring.season_day, 12, "last spring season day")
	var first_summer: SimClockScript.Calendar = SimClockScript.calendar_at(211500)
	assert_equal(first_summer.absolute_day, 13, "first summer absolute day")
	assert_equal(first_summer.season, 1, "first summer season")
	assert_equal(first_summer.season_name(), "summer", "first summer season name")
	assert_equal(first_summer.season_day, 1, "first summer season day")
	assert_equal(first_summer.hour, 0, "first summer hour")


func test_year_rolls_over_after_forty_eight_days() -> void:
	"""REQ-SET-006: a year is 48 days, so absolute day 49 is year 2 spring day 1."""
	var last_winter: SimClockScript.Calendar = SimClockScript.calendar_at(859499)
	assert_equal(last_winter.absolute_day, 48, "last winter absolute day")
	assert_equal(last_winter.year, 1, "last winter year")
	assert_equal(last_winter.season, 3, "last winter season")
	assert_equal(last_winter.season_name(), "winter", "last winter season name")
	assert_equal(last_winter.season_day, 12, "last winter season day")
	var new_year: SimClockScript.Calendar = SimClockScript.calendar_at(859500)
	assert_equal(new_year.absolute_day, 49, "new year absolute day")
	assert_equal(new_year.year, 2, "new year year")
	assert_equal(new_year.season, 0, "new year season")
	assert_equal(new_year.season_day, 1, "new year season day")


# --- speed ---------------------------------------------------------------------------------------

func test_three_times_speed_is_rejected() -> void:
	"""There is no 3x: the prototype's [1.0, 2.0, 3.0] cycle contradicts the Speed enum."""
	assert_false(_clock.set_speed(3), "3x must be refused")
	assert_equal(_clock.requested_speed(), SimClockScript.SPEED_NORMAL, "speed unchanged after refusal")
	assert_true(_clock.last_error() != "", "refusal records a reason")
	assert_false(_clock.set_speed(5), "5x must be refused")
	assert_false(_clock.set_speed(-1), "negative speed must be refused")
	assert_equal(_clock.requested_speed(), SimClockScript.SPEED_NORMAL, "speed still unchanged")


func test_speed_zero_is_not_requestable_because_pause_is_authoritative() -> void:
	"""SPEED_PAUSED is an effective-speed value only; a caller wanting 0 must name a pause reason."""
	assert_false(_clock.set_speed(SimClockScript.SPEED_PAUSED), "0x must be refused as a request")
	assert_equal(_clock.requested_speed(), SimClockScript.SPEED_NORMAL, "speed unchanged")
	assert_true(_clock.set_pause(SimClockScript.MENU, true), "menu pause accepted")
	assert_equal(_clock.effective_speed(), SimClockScript.SPEED_PAUSED, "paused effective speed is 0")


func test_normal_speed_runs_thirty_ticks_per_real_second() -> void:
	"""REQ-SET-002: 30 fixed ticks per second of 1x simulation time."""
	var ticks: int = _run_frames(FRAMES_PER_REAL_SECOND, FRAME_USEC)
	assert_equal(ticks, 30, "ticks in one real second at 1x")
	assert_equal(_clock.completed_tick(), 30, "completed tick after one real second")


func _ticks_in_one_real_second(speed: int) -> int:
	"""Run a fresh clock at `speed` for one real second of equal frames; return the ticks run."""
	var clock: SimClockScript = SimClockScript.new()
	assert_true(clock.set_pause(SimClockScript.PLAYER, false), "player pause released at %dx" % speed)
	assert_true(clock.set_speed(speed), "%dx accepted" % speed)
	var ticks: int = 0
	for _index: int in FRAMES_PER_REAL_SECOND:
		ticks += clock.advance(FRAME_USEC)
	return ticks


func test_double_and_quadruple_run_exactly_two_and_four_times_the_ticks() -> void:
	"""REQ-SET-003: the same elapsed real time yields exactly 2x and 4x as many identical ticks.

	The multiples are asserted against the 1x rate this same clock actually runs, measured in
	this test. Comparing 120 to a written-out `4 * 30` compares two literals and holds even
	if advance() never runs a tick at any speed.
	"""
	var single_ticks: int = _ticks_in_one_real_second(SimClockScript.SPEED_NORMAL)
	var double_ticks: int = _ticks_in_one_real_second(SimClockScript.SPEED_DOUBLE)
	var quad_ticks: int = _ticks_in_one_real_second(SimClockScript.SPEED_QUADRUPLE)
	assert_equal(single_ticks, 30, "ticks in one real second at 1x")
	assert_equal(double_ticks, 60, "ticks in one real second at 2x")
	assert_equal(quad_ticks, 120, "ticks in one real second at 4x")
	assert_equal(double_ticks, single_ticks * 2, "2x runs exactly twice the ticks 1x runs")
	assert_equal(quad_ticks, single_ticks * 4, "4x runs exactly four times the ticks 1x runs")


func test_speed_change_does_not_clear_a_pause_reason() -> void:
	"""Requested speed persists separately from the effective paused state (ARCH-CMD-002)."""
	assert_true(_clock.set_pause(SimClockScript.MENU, true), "menu pause accepted")
	assert_true(_clock.set_speed(SimClockScript.SPEED_QUADRUPLE), "4x accepted while paused")
	assert_true(_clock.is_paused(), "still paused after a speed change")
	assert_equal(_clock.requested_speed(), SimClockScript.SPEED_QUADRUPLE, "requested speed retained")
	assert_equal(_clock.effective_speed(), SimClockScript.SPEED_PAUSED, "effective speed still 0")


# --- pause ---------------------------------------------------------------------------------------

func test_pause_reasons_compose_as_a_mask_needing_separate_releases() -> void:
	"""Closing a menu must not resume a pause the player still holds."""
	assert_true(_clock.set_pause(SimClockScript.PLAYER, true), "player pause accepted")
	assert_true(_clock.set_pause(SimClockScript.MENU, true), "menu pause accepted")
	assert_equal(_clock.pause_mask(), SimClockScript.PLAYER | SimClockScript.MENU, "composed mask")
	assert_true(_clock.set_pause(SimClockScript.MENU, false), "menu pause released")
	assert_true(_clock.is_paused(), "one release is not enough")
	assert_true(_clock.has_pause_reason(SimClockScript.PLAYER), "player reason still held")
	assert_true(_clock.set_pause(SimClockScript.PLAYER, false), "player pause released")
	assert_false(_clock.is_paused(), "two reasons need two releases")


func test_pause_reason_names_report_every_held_reason() -> void:
	"""The HUD diagnostic lists each held reason in bit order."""
	assert_true(_clock.set_pause(SimClockScript.MENU, true), "menu pause accepted")
	assert_true(_clock.set_pause(SimClockScript.LOAD, true), "load pause accepted")
	var names: Array[String] = _clock.pause_reason_names()
	assert_equal(names.size(), 2, "two reasons named")
	assert_equal(names[0], "MENU", "first reason name")
	assert_equal(names[1], "LOAD", "second reason name")


func test_unknown_or_composite_pause_reasons_are_refused() -> void:
	"""set_pause takes exactly one known reason; anything else changes nothing."""
	assert_false(_clock.set_pause(0, true), "empty reason refused")
	assert_false(_clock.set_pause(32, true), "unknown bit refused")
	assert_false(_clock.set_pause(SimClockScript.PLAYER | SimClockScript.MENU, true), "composite refused")
	assert_false(_clock.is_paused(), "no reason was applied")


func test_paused_host_time_accumulates_no_debt() -> void:
	"""REQ-SET-004: while paused the simulation freezes; wall time adds no owed ticks."""
	var fresh: SimClockScript = SimClockScript.new()
	assert_true(fresh.is_paused(), "a new clock starts player-paused")
	assert_equal(fresh.advance(OVERLOAD_FRAME_USEC), 0, "paused advance runs no ticks")
	assert_equal(fresh.debt(), 0, "paused advance accrues no debt")
	assert_equal(fresh.completed_tick(), 0, "paused advance completes no tick")


# --- retained debt (blocker U3) ------------------------------------------------------------------

func test_debt_is_retained_across_advances_rather_than_discarded() -> void:
	"""ARCH-CLOCK-001: sub-tick debt carries into the next frame and eventually runs a tick."""
	assert_equal(_clock.advance(20000), 0, "0.02 s is less than one tick at 1x")
	assert_equal(_clock.debt(), 600000, "sub-tick debt retained")
	assert_equal(_clock.owed_ticks(), 0, "no whole tick owed yet")
	assert_equal(_clock.advance(20000), 1, "the carried remainder completes a tick")
	assert_equal(_clock.debt(), 200000, "the new remainder is retained too")
	assert_equal(_clock.completed_tick(), 1, "exactly one tick completed")


func test_frame_tick_ceiling_owes_the_remainder_instead_of_dropping_it() -> void:
	"""ARCH-CLOCK-001 schedules at most 8 ticks per frame and keeps the rest owed."""
	var ticks: int = _clock.advance(400000)
	assert_equal(ticks, SimClockScript.MAX_TICKS_PER_FRAME, "frame ceiling applied")
	assert_equal(_clock.debt(), 4000000, "undrained debt retained")
	assert_equal(_clock.owed_ticks(), 4, "four whole ticks still owed")
	assert_false(_clock.is_paused(), "a 4-tick backlog is under the 0.25 s limit")


func test_player_pause_discards_only_subtick_debt_and_counts_it() -> void:
	"""ARCH-CLOCK-002 permits dropping sub-tick presentation debt; the drop is observable."""
	assert_equal(_clock.advance(20000), 0, "sub-tick advance")
	assert_equal(_clock.debt(), 600000, "sub-tick debt present")
	assert_true(_clock.set_pause(SimClockScript.PLAYER, true), "player pause accepted")
	assert_equal(_clock.debt(), 0, "sub-tick presentation debt dropped")
	assert_equal(_clock.subtick_debt_discards(), 1, "the drop is counted, not silent")
	assert_equal(_clock.completed_tick(), 0, "no completed tick was affected")


func test_player_pause_never_discards_whole_owed_ticks() -> void:
	"""Blocker U3 conservative rule: owed ticks survive an ordinary pause untouched."""
	assert_equal(_clock.advance(400000), SimClockScript.MAX_TICKS_PER_FRAME, "frame ceiling applied")
	assert_true(_clock.set_pause(SimClockScript.PLAYER, true), "player pause accepted")
	assert_equal(_clock.debt(), 4000000, "whole owed ticks retained through the pause")
	assert_equal(_clock.owed_ticks(), 4, "still four ticks owed")
	assert_equal(_clock.subtick_debt_discards(), 0, "no sub-tick discard while whole ticks are owed")


# --- overload ladder -----------------------------------------------------------------------------

func test_overload_steps_four_to_two_to_one_then_pauses_with_a_diagnostic() -> void:
	"""REQ-SET-008: 4x drops to 2x, 2x to 1x, and 1x pauses with a diagnostic instead of skipping."""
	assert_true(_clock.set_speed(SimClockScript.SPEED_QUADRUPLE), "4x accepted")
	_clock.advance(OVERLOAD_FRAME_USEC)
	assert_equal(_clock.requested_speed(), SimClockScript.SPEED_DOUBLE, "4x reduced to 2x")
	_clock.advance(OVERLOAD_FRAME_USEC)
	assert_equal(_clock.requested_speed(), SimClockScript.SPEED_NORMAL, "2x reduced to 1x")
	_clock.advance(OVERLOAD_FRAME_USEC)
	assert_equal(_clock.requested_speed(), SimClockScript.SPEED_NORMAL, "1x is never reduced further")
	assert_true(_clock.has_pause_reason(SimClockScript.CRITICAL), "1x overload pauses critically")
	assert_equal(_clock.diagnostic_pause_count(), 1, "the diagnostic pause is counted")
	assert_equal(_clock.fallback_count(), 3, "three ladder steps taken")
	assert_true(_clock.last_diagnostic() != "", "a diagnostic message is available for the HUD")


func test_overload_retains_every_owed_tick_rather_than_skipping() -> void:
	"""REQ-SET-008 and ARCH-CLOCK-001: the ladder slows the clock, it never hides backlog."""
	assert_true(_clock.set_speed(SimClockScript.SPEED_QUADRUPLE), "4x accepted")
	_clock.advance(OVERLOAD_FRAME_USEC)
	_clock.advance(OVERLOAD_FRAME_USEC)
	_clock.advance(OVERLOAD_FRAME_USEC)
	assert_equal(_clock.completed_tick(), 3 * SimClockScript.MAX_TICKS_PER_FRAME, "every frame ran its ceiling")
	assert_equal(_clock.owed_ticks(), 186, "all remaining ticks are still owed")
	var frozen_debt: int = _clock.debt()
	assert_equal(_clock.advance(OVERLOAD_FRAME_USEC), 0, "the diagnostic pause freezes the scheduler")
	assert_equal(_clock.debt(), frozen_debt, "paused frames neither add nor drop debt")
	assert_equal(_clock.completed_tick(), 24, "no tick runs while critically paused")


func test_acknowledge_without_catchup_is_counted_and_never_rewinds_the_tick() -> void:
	"""Blocker U3: the one debt-dropping recovery path is explicit, counted, and state-preserving.

	ARCH-CLOCK-001 forbids discarding owed ticks; ARCH-CLOCK-002 allows an explicit
	resume-without-catch-up to clear scheduler debt and requires the event be recorded. The
	conservative resolution keeps the drop out of every implicit path and exposes both counters.
	"""
	assert_true(_clock.set_speed(SimClockScript.SPEED_QUADRUPLE), "4x accepted")
	_clock.advance(OVERLOAD_FRAME_USEC)
	_clock.advance(OVERLOAD_FRAME_USEC)
	_clock.advance(OVERLOAD_FRAME_USEC)
	assert_equal(_clock.acknowledged_catchup_resets(), 0, "nothing acknowledged implicitly")
	var dropped: int = _clock.acknowledge_without_catchup()
	assert_equal(dropped, 186, "the acknowledgement reports what it dropped")
	assert_equal(_clock.acknowledged_catchup_resets(), 1, "the scheduler event is recorded")
	assert_equal(_clock.acknowledged_ticks_discarded(), 186, "the dropped total is recorded")
	assert_equal(_clock.debt(), 0, "scheduler debt cleared")
	assert_equal(_clock.completed_tick(), 24, "completed state never rewinds or advances")
	assert_false(_clock.is_paused(), "the CRITICAL pause is lifted")
	assert_equal(_clock.requested_speed(), SimClockScript.SPEED_NORMAL, "no automatic speed increase")


# --- callbacks -----------------------------------------------------------------------------------

func test_step_callback_runs_once_per_completed_tick() -> void:
	"""The scheduler drives gameplay by direct call, once per fixed tick."""
	var ticks: int = _clock.advance(200000, _count_step)
	assert_equal(ticks, 6, "0.2 s is six ticks at 1x")
	assert_equal(_step_calls, 6, "one step call per tick")


func test_day_boundary_fires_at_offset_midnight_only() -> void:
	"""REQ-SET-007 boundaries follow the offset calendar: one crossing by tick 18000, at 13500."""
	_run_until_tick(18000)
	assert_equal(_boundary_ticks.size(), 1, "exactly one boundary through tick 18000")
	assert_equal(_boundary_ticks[0], SimClockScript.FIRST_MIDNIGHT_TICK, "the boundary is tick 13500")
	assert_equal(_boundary_days[0], 2, "the boundary opens absolute day 2")
	assert_equal(_clock.day_boundaries_crossed(), 1, "boundary counter agrees")
	assert_equal(_step_calls, _clock.completed_tick(), "every tick ran its step")


func test_pause_raised_inside_a_step_stops_before_the_next_tick() -> void:
	"""ARCH-CMD-002: a pause takes effect before another tick starts, and the rest stays owed."""
	var ticks: int = _clock.advance(400000, _pause_on_third_tick)
	assert_equal(ticks, 3, "the frame stopped at the pausing tick")
	assert_equal(_clock.completed_tick(), 3, "three ticks completed")
	assert_equal(_clock.debt(), 9000000, "the undrained ticks are still owed")
	assert_true(_clock.has_pause_reason(SimClockScript.MENU), "the pause raised inside the step holds")


func _pause_on_third_tick() -> void:
	"""Step callback that raises a MENU pause once three ticks have run."""
	_step_calls += 1
	if _step_calls == 3:
		assert_true(_clock.set_pause(SimClockScript.MENU, true), "menu pause accepted mid-frame")


# --- refusals ------------------------------------------------------------------------------------

func test_negative_elapsed_time_is_refused_without_changing_state() -> void:
	"""Host timing is untrusted input: a bad frame delta refuses instead of corrupting debt."""
	assert_equal(_clock.advance(-1), 0, "negative elapsed runs no ticks")
	assert_true(_clock.last_error() != "", "the refusal records a reason")
	assert_equal(_clock.debt(), 0, "debt untouched")
	assert_equal(_clock.completed_tick(), 0, "completed tick untouched")


func test_overflowing_elapsed_time_is_refused_rather_than_wrapping() -> void:
	"""BAL-AUTH-002: int64 overflow refuses; it never wraps into a plausible small backlog."""
	assert_equal(_clock.advance(9223372036854775807), 0, "overflowing elapsed runs no ticks")
	assert_true(_clock.last_error() != "", "the refusal records a reason")
	assert_equal(_clock.debt(), 0, "debt untouched")
	assert_equal(_clock.completed_tick(), 0, "completed tick untouched")


func test_a_successful_advance_clears_the_previous_error() -> void:
	"""last_error() describes the most recent call, not a stale one."""
	assert_equal(_clock.advance(-1), 0, "refused advance")
	assert_true(_clock.last_error() != "", "error recorded")
	assert_equal(_clock.advance(FRAME_USEC), 1, "a valid frame runs its tick")
	assert_equal(_clock.last_error(), "", "error cleared by the successful call")


# --- Non-allocating polling path (task 2.7, decision 0015) ---------------------------------------

var _boundary_moments: Array = []


func _keep_boundary_moment(moment: SimClockScript.Calendar) -> void:
	"""Day-boundary callback that RETAINS the Calendar it was handed, to expose reuse."""
	_boundary_moments.append(moment)


func test_calendar_into_reproduces_calendar_field_for_field() -> void:
	"""The non-allocating form must decode identically to the allocating one, not approximately."""
	_run_frames(600, 33333)
	var allocated: SimClockScript.Calendar = _clock.calendar()
	var reused: SimClockScript.Calendar = SimClockScript.Calendar.new(0)
	_clock.calendar_into(reused)
	assert_equal(reused.tick, allocated.tick, "tick")
	assert_equal(reused.absolute_day, allocated.absolute_day, "absolute_day")
	assert_equal(reused.year, allocated.year, "year")
	assert_equal(reused.season, allocated.season, "season")
	assert_equal(reused.season_day, allocated.season_day, "season_day")
	assert_equal(reused.hour, allocated.hour, "hour")
	assert_equal(reused.minute, allocated.minute, "minute")
	assert_equal(reused.tick_of_day, allocated.tick_of_day, "tick_of_day")
	assert_equal(reused.clock_text(), allocated.clock_text(), "clock_text")


func test_calendar_into_overwrites_every_field_of_a_reused_instance() -> void:
	"""A polled HUD instance must never keep a field from an earlier, distant tick."""
	var reused: SimClockScript.Calendar = SimClockScript.Calendar.new(0)
	SimClockScript.calendar_at_into(3 * SimClockScript.TICKS_PER_DAY + 5000, reused)
	assert_equal(reused.absolute_day, 4, "seeded to day 4")
	SimClockScript.calendar_at_into(0, reused)
	var fresh: SimClockScript.Calendar = SimClockScript.calendar_at(0)
	assert_equal(reused.tick, 0, "tick reset")
	assert_equal(reused.absolute_day, fresh.absolute_day, "absolute_day reset, not carried over")
	assert_equal(reused.year, fresh.year, "year reset")
	assert_equal(reused.season, fresh.season, "season reset")
	assert_equal(reused.season_day, fresh.season_day, "season_day reset")
	assert_equal(reused.hour, fresh.hour, "hour reset")
	assert_equal(reused.minute, fresh.minute, "minute reset")
	assert_equal(reused.tick_of_day, fresh.tick_of_day, "tick_of_day reset")


func test_day_boundary_callback_receives_a_distinct_calendar_per_crossing() -> void:
	"""The escaping Calendar must stay freshly allocated: a callee may keep it.

	If _notify_day_boundary() ever reuses one instance, the first retained moment would change
	under the callee when the second boundary fired. This test fails the moment that happens.
	"""
	_boundary_moments = []
	assert_true(_clock.set_speed(SimClockScript.SPEED_QUADRUPLE), "4x accepted")
	var target: int = SimClockScript.FIRST_MIDNIGHT_TICK + SimClockScript.TICKS_PER_DAY
	while _clock.completed_tick() < target:
		_clock.advance(FRAME_USEC, Callable(), _keep_boundary_moment)
	assert_equal(_boundary_moments.size(), 2, "exactly two midnights crossed")
	var first: SimClockScript.Calendar = _boundary_moments[0]
	var second: SimClockScript.Calendar = _boundary_moments[1]
	assert_false(first == second, "each crossing hands out its own Calendar")
	assert_equal(first.tick, SimClockScript.FIRST_MIDNIGHT_TICK, "first retained moment is midnight 1")
	assert_equal(second.tick, SimClockScript.FIRST_MIDNIGHT_TICK + SimClockScript.TICKS_PER_DAY, "second retained moment is midnight 2")


func test_advance_retains_no_objects_across_many_frames() -> void:
	"""The per-frame scheduler must accumulate nothing on the clock, frame after frame.

	Scope, stated honestly: a live-object census cannot see a transient RefCounted, so this
	does not prove advance() is allocation-free -- that is a timing property, measured with the
	task 2.7 benchmark. What it does catch is the leak class: a scheduler that keeps a result,
	a Calendar or a diagnostic object per frame instead of reusing its one scratch.
	"""
	var before: int = Performance.get_monitor(Performance.OBJECT_COUNT)
	for _index: int in 500:
		_clock.advance(16666)
	var after: int = Performance.get_monitor(Performance.OBJECT_COUNT)
	assert_equal(after - before, 0, "500 advance() frames retained no objects")
