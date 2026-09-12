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


# --- restore (RESTORE-R01) -----------------------------------------------------------------------
#
# The 2026-09-12 follow-up ruling's acceptance list, pinned. The hazard these tests exist for is
# not that a restore fails loudly -- it is that a restore quietly manufactures the saved state
# through the ordinary command setters, which ZERO a sub-tick debt on a PLAYER pause, or replays
# ticks to reach the saved tick, which would re-fire day boundaries and re-run economy steps.

## Debts G3 and the follow-up ruling name: sub-tick, the tick boundary, and two owed plus a
## remainder. `2500001` is the one G3 calls acceptance.
const RESTORE_DEBTS: Array[int] = [1, 999999, 1000000, 2500001]
## Masks the ruling names: none, one hold, two composed, a player hold beside a victory hold,
## and every known bit at once.
const RESTORE_MASKS: Array[int] = [0, SimClockScript.PLAYER,
	SimClockScript.MENU | SimClockScript.CRITICAL,
	SimClockScript.PLAYER | SimClockScript.VICTORY, 31]
## Six DIFFERENT nonzero counters, so a restore that crossed two of them over is visible.
const RESTORE_COUNTERS: Array[int] = [11, 22, 33, 44, 55, 66]
## The six field names in `restore_runtime()`'s argument order, for the per-counter refusals.
const RESTORE_COUNTER_NAMES: Array[String] = ["_fallback_count", "_diagnostic_pause_count",
	"_acknowledged_catchup_resets", "_acknowledged_ticks_discarded", "_subtick_debt_discards",
	"_day_boundaries_crossed"]

var _restore_overload_signals: int = 0
var _restore_diagnostic_signals: int = 0
var _restore_boundary_signals: int = 0


func _count_overload_signal(_reduced_to_speed: int) -> void:
	"""Signal probe: records that the clock announced an overload rung."""
	_restore_overload_signals += 1


func _count_diagnostic_signal(_diagnostic: String) -> void:
	"""Signal probe: records that the clock announced a diagnostic pause."""
	_restore_diagnostic_signals += 1


func _count_boundary_signal(_absolute_day: int) -> void:
	"""Signal probe: records that the clock announced a day boundary."""
	_restore_boundary_signals += 1


func _watch_every_clock_signal() -> void:
	"""Connect all three UI signals and zero their counts, so a silent restore is provable."""
	_restore_overload_signals = 0
	_restore_diagnostic_signals = 0
	_restore_boundary_signals = 0
	_clock.clock_overload_warning.connect(_count_overload_signal)
	_clock.clock_diagnostic_pause.connect(_count_diagnostic_signal)
	_clock.clock_day_boundary.connect(_count_boundary_signal)


func _assert_no_clock_signal_fired(context: String) -> void:
	"""Assert none of the three clock signals was emitted since `_watch_every_clock_signal()`."""
	assert_equal(_restore_overload_signals, 0, "%s: no overload signal" % context)
	assert_equal(_restore_diagnostic_signals, 0, "%s: no diagnostic signal" % context)
	assert_equal(_restore_boundary_signals, 0, "%s: no day-boundary signal" % context)


func _snapshot(clock: SimClockScript) -> String:
	"""Every observable field of a clock as one string, including both transient diagnostics.

	This is the "byte-identical pre-call state" comparison the ruling requires of a refusal. It
	deliberately includes `last_error()` and `last_diagnostic()`: a refused restore must not even
	write its own reason there.
	"""
	return "%d|%d|%d|%d|%d|%d|%d|%d|%d|%d|%s|%s" % [clock.completed_tick(), clock.debt(),
		clock.requested_speed(), clock.pause_mask(), clock.fallback_count(),
		clock.diagnostic_pause_count(), clock.acknowledged_catchup_resets(),
		clock.acknowledged_ticks_discarded(), clock.subtick_debt_discards(),
		clock.day_boundaries_crossed(), clock.last_error(), clock.last_diagnostic()]


func _restore_with_counters(tick: int, debt: int, speed: int, mask: int,
		counters: Array[int]) -> bool:
	"""Call the ten-argument restore with the six counters supplied as a list."""
	return _clock.restore_runtime(tick, debt, speed, mask, counters[0], counters[1], counters[2],
		counters[3], counters[4], counters[5])


func _restore_plain(tick: int, debt: int, speed: int, mask: int) -> bool:
	"""Call restore with all six counters zero, for cases that are about the other four fields."""
	return _clock.restore_runtime(tick, debt, speed, mask, 0, 0, 0, 0, 0, 0)


func _refusal_of(tick: int, debt: int, speed: int, mask: int,
		counters: Array[int]) -> SimClockScript.RestoreRefusal:
	"""Run the pure validator on the same ten arguments, without touching any clock."""
	return SimClockScript.restore_refusal(tick, debt, speed, mask, counters[0], counters[1],
		counters[2], counters[3], counters[4], counters[5])


func _put_the_clock_in_a_used_state() -> void:
	"""Drive real ticks, two ladder steps, two acknowledgements, a sub-tick discard and a refusal.

	A refusal test against a freshly constructed clock proves little, because most of its fields
	are already zero. This leaves nine of the ten runtime fields and both transient strings
	nonzero first, so a partial assignment has something to disturb.
	"""
	assert_true(_clock.set_speed(SimClockScript.SPEED_QUADRUPLE), "4x accepted")
	_run_frames(3, FRAME_USEC)
	_clock.advance(OVERLOAD_FRAME_USEC)
	_clock.acknowledge_without_catchup()
	_clock.advance(OVERLOAD_FRAME_USEC)
	_clock.acknowledge_without_catchup()
	_clock.advance(10000)
	_clock.advance(-1)
	assert_true(_clock.set_pause(SimClockScript.PLAYER, true), "player pause accepted")
	_clock.apply_overload()
	assert_true(_clock.last_error() != "", "the used state carries a refusal reason")
	assert_true(_clock.last_diagnostic() != "", "and a standing diagnostic")
	assert_true(_clock.subtick_debt_discards() > 0, "and a counted sub-tick discard")


func test_restore_installs_all_ten_fields_verbatim() -> void:
	"""RESTORE-R01: one assignment boundary writes tick, debt, speed, mask and all six counters."""
	assert_true(_restore_with_counters(7200, 2500001, SimClockScript.SPEED_DOUBLE,
		SimClockScript.MENU | SimClockScript.CRITICAL, RESTORE_COUNTERS), "restore accepted")
	assert_equal(_clock.completed_tick(), 7200, "completed tick")
	assert_equal(_clock.debt(), 2500001, "debt")
	assert_equal(_clock.requested_speed(), SimClockScript.SPEED_DOUBLE, "requested speed")
	assert_equal(_clock.pause_mask(), SimClockScript.MENU | SimClockScript.CRITICAL, "pause mask")
	assert_equal(_clock.fallback_count(), RESTORE_COUNTERS[0], "fallback count")
	assert_equal(_clock.diagnostic_pause_count(), RESTORE_COUNTERS[1], "diagnostic pause count")
	assert_equal(_clock.acknowledged_catchup_resets(), RESTORE_COUNTERS[2], "catchup resets")
	assert_equal(_clock.acknowledged_ticks_discarded(), RESTORE_COUNTERS[3], "ticks discarded")
	assert_equal(_clock.subtick_debt_discards(), RESTORE_COUNTERS[4], "subtick discards")
	assert_equal(_clock.day_boundaries_crossed(), RESTORE_COUNTERS[5], "day boundaries crossed")


func test_restore_accepts_every_named_debt_speed_and_mask_exactly() -> void:
	"""The ruling's acceptance grid: 4 debts x 3 speeds x 5 masks, each scalar exact afterwards."""
	for debt: int in RESTORE_DEBTS:
		for speed: int in SimClockScript.SELECTABLE_SPEEDS:
			for mask: int in RESTORE_MASKS:
				assert_true(_restore_plain(900, debt, speed, mask),
					"restore accepted debt %d speed %d mask %d" % [debt, speed, mask])
				assert_equal(_clock.debt(), debt, "debt %d survives mask %d" % [debt, mask])
				assert_equal(_clock.requested_speed(), speed, "requested speed %d survives" % speed)
				assert_equal(_clock.pause_mask(), mask, "pause mask %d survives" % mask)


func test_restoring_a_player_pause_keeps_subtick_debt_and_counts_no_discard() -> void:
	"""The exact defect the ruling forbids: `set_pause(PLAYER, true)` would zero this debt.

	`set_pause()` discards a debt in `(0, TICK_COST)` on a PLAYER hold and counts it. A restore
	that manufactured the saved mask through that setter would leave 0 debt and 5 discards here.
	"""
	assert_true(_restore_with_counters(120, 999999, SimClockScript.SPEED_NORMAL,
		SimClockScript.PLAYER, [1, 2, 3, 4, 4, 6]), "restore accepted")
	assert_equal(_clock.debt(), 999999, "sub-tick debt restored, not zeroed")
	assert_equal(_clock.subtick_debt_discards(), 4, "the discard counter is not incremented")
	assert_equal(_clock.owed_ticks(), 0, "999999 owes no whole tick")
	assert_true(_clock.has_pause_reason(SimClockScript.PLAYER), "the player hold is restored")
	assert_equal(_clock.effective_speed(), SimClockScript.SPEED_PAUSED, "and it pauses the clock")


func test_restored_debt_of_2500001_owes_two_ticks_and_keeps_its_remainder() -> void:
	"""G3 acceptance: 2500001 is two owed ticks plus 500001, and both halves survive the restore."""
	assert_true(_restore_plain(500, 2500001, SimClockScript.SPEED_NORMAL, 0), "restore accepted")
	assert_equal(_clock.debt(), 2500001, "debt is exact, not rounded to a whole tick")
	assert_equal(_clock.owed_ticks(), 2, "two whole ticks owed")
	assert_equal(_clock.debt() % SimClockScript.TICK_COST, 500001, "the remainder is intact")
	assert_equal(_clock.advance(0, _count_step), 2, "a zero-length frame runs both owed ticks")
	assert_equal(_clock.completed_tick(), 502, "and lands two ticks past the restored one")
	assert_equal(_clock.debt(), 500001, "leaving the sub-tick remainder still owed")


func test_restore_runs_no_tick_and_replays_nothing_to_reach_the_saved_tick() -> void:
	"""No simulated tick replay: a distant tick is installed, not walked to."""
	_step_calls = 0
	_watch_every_clock_signal()
	assert_true(_restore_with_counters(3 * SimClockScript.TICKS_PER_DAY + 17, 0,
		SimClockScript.SPEED_QUADRUPLE, 0, RESTORE_COUNTERS), "restore accepted")
	assert_equal(_clock.completed_tick(), 3 * SimClockScript.TICKS_PER_DAY + 17, "tick installed")
	assert_equal(_step_calls, 0, "no step callback could run: restore takes none")
	assert_equal(_clock.day_boundaries_crossed(), RESTORE_COUNTERS[5],
		"the boundary counter is the saved one, never recomputed from the tick")
	_assert_no_clock_signal_fired("restoring a distant tick")


func test_restore_at_midnight_replays_no_notification() -> void:
	"""Restoring AT 13500 and AT 18000 emits nothing; a save boundary is not a crossing."""
	_watch_every_clock_signal()
	assert_true(_restore_plain(SimClockScript.FIRST_MIDNIGHT_TICK, 0,
		SimClockScript.SPEED_NORMAL, 0), "restore at 13500 accepted")
	assert_true(SimClockScript.is_day_boundary(SimClockScript.FIRST_MIDNIGHT_TICK),
		"13500 really is a boundary tick")
	_assert_no_clock_signal_fired("restore at tick 13500")
	assert_true(_restore_plain(SimClockScript.TICKS_PER_DAY, 0, SimClockScript.SPEED_NORMAL, 0),
		"restore at 18000 accepted")
	assert_false(SimClockScript.is_day_boundary(SimClockScript.TICKS_PER_DAY),
		"18000 is 06:00 of day 2 and is not a boundary")
	_assert_no_clock_signal_fired("restore at tick 18000")


func test_the_next_real_crossing_after_a_restore_is_delivered_exactly_once() -> void:
	"""Restore just short of the second midnight; the normal clock then reports it once."""
	_watch_every_clock_signal()
	var second_midnight: int = SimClockScript.FIRST_MIDNIGHT_TICK + SimClockScript.TICKS_PER_DAY
	assert_true(_restore_plain(second_midnight - 1, 0, SimClockScript.SPEED_NORMAL, 0),
		"restore one tick short of the crossing")
	assert_equal(_clock.advance(FRAME_USEC, _count_step, _record_boundary), 1, "one tick runs")
	assert_equal(_boundary_ticks.size(), 1, "exactly one crossing delivered")
	assert_equal(_boundary_ticks[0], second_midnight, "and it is the restored day's midnight")
	assert_equal(_restore_boundary_signals, 1, "the UI signal fires once, for the real crossing")
	assert_equal(_clock.day_boundaries_crossed(), 1, "the counter advances by exactly one")


func test_restore_refuses_a_negative_or_unrepresentable_tick() -> void:
	"""The tick bound is the existing `tick + 4500` arithmetic's headroom, not a new calendar."""
	assert_false(_restore_plain(-1, 0, SimClockScript.SPEED_NORMAL, 0), "a negative tick refuses")
	assert_equal(_refusal_of(-1, 0, 1, 0, RESTORE_COUNTERS).code,
		SimClockScript.REFUSE_RESTORE_NEGATIVE_TICK, "negative tick code")
	var ceiling: int = SimClockScript.RESTORE_COMPLETED_TICK_MAX
	assert_false(_restore_plain(ceiling + 1, 0, SimClockScript.SPEED_NORMAL, 0),
		"one past the representable ceiling refuses")
	assert_equal(_refusal_of(ceiling + 1, 0, 1, 0, RESTORE_COUNTERS).code,
		SimClockScript.REFUSE_RESTORE_TICK_UNREPRESENTABLE, "unrepresentable tick code")
	assert_true(_restore_plain(ceiling, 0, SimClockScript.SPEED_NORMAL, 0),
		"the ceiling itself is representable and accepted")
	assert_equal(_clock.completed_tick(), ceiling, "and is installed exactly")
	assert_equal(ceiling + SimClockScript.CALENDAR_OFFSET_TICKS, 9223372036854775807,
		"the ceiling is exactly INT64_MAX minus the calendar offset")


func test_restore_refuses_every_speed_outside_one_two_four() -> void:
	"""Speed 0 is derived from the mask by effective_speed(); it is never a stored request."""
	for speed: int in [0, 3, -1, 5, 8]:
		assert_false(_restore_plain(10, 0, speed, 0), "requested speed %d refuses" % speed)
		assert_equal(_refusal_of(10, 0, speed, 0, RESTORE_COUNTERS).code,
			SimClockScript.REFUSE_RESTORE_SPEED, "speed %d refusal code" % speed)
	assert_equal(_clock.completed_tick(), 0, "no refused speed advanced the tick")
	assert_true(_restore_plain(10, 0, SimClockScript.SPEED_NORMAL, SimClockScript.PLAYER),
		"a paused restore states speed 1 and derives 0")
	assert_equal(_clock.requested_speed(), SimClockScript.SPEED_NORMAL, "1 is what is stored")
	assert_equal(_clock.effective_speed(), SimClockScript.SPEED_PAUSED, "0 is what is derived")


func test_restore_refuses_a_pause_mask_carrying_an_unknown_bit() -> void:
	"""The int32/int64 sign trap: `0x80000000` is POSITIVE here and int32 -2147483648 on disk.

	Both readings of the same bits must refuse, and they are written as bit conversions rather
	than typed literals, because a literal is exactly where this bug hides.
	"""
	var high_bit: int = 1 << 31
	var same_bits_as_int32: int = high_bit - (1 << 32)
	assert_true(high_bit > 0, "0x80000000 is a positive GDScript int")
	assert_true(same_bits_as_int32 < 0, "the same bits read as an int32 are negative")
	for mask: int in [SimClockScript.LOAD << 1, high_bit, same_bits_as_int32, -1, 32]:
		assert_false(_restore_plain(10, 0, SimClockScript.SPEED_NORMAL, mask),
			"pause mask %d refuses" % mask)
		assert_equal(_refusal_of(10, 0, 1, mask, RESTORE_COUNTERS).code,
			SimClockScript.REFUSE_RESTORE_PAUSE_MASK, "mask %d refusal code" % mask)
	assert_equal(SimClockScript.KNOWN_PAUSE_BITS, 31, "the five known bits are 1|2|4|8|16")
	assert_true(_restore_plain(10, 0, SimClockScript.SPEED_NORMAL,
		SimClockScript.KNOWN_PAUSE_BITS), "every known bit at once is a legal composite")


func test_restore_preserves_the_saved_load_bit_beside_every_other_hold() -> void:
	"""G3: never clear a saved LOAD bit, and never let it erase PLAYER/MENU/CRITICAL/VICTORY."""
	assert_true(_restore_plain(60, 0, SimClockScript.SPEED_QUADRUPLE,
		SimClockScript.KNOWN_PAUSE_BITS), "restore accepted")
	for reason: int in SimClockScript.ALL_PAUSE_REASONS:
		assert_true(_clock.has_pause_reason(reason), "pause reason %d restored" % reason)
	assert_equal(_clock.pause_reason_names().size(), 5, "all five reasons are reported")
	assert_true(_restore_plain(60, 0, SimClockScript.SPEED_QUADRUPLE, SimClockScript.LOAD),
		"a save taken under LOAD alone restores under LOAD alone")
	assert_equal(_clock.pause_mask(), SimClockScript.LOAD, "the LOAD hold is not silently cleared")
	assert_equal(_clock.requested_speed(), SimClockScript.SPEED_QUADRUPLE,
		"the requested speed survives a paused restore")


func test_restore_refuses_a_negative_debt_and_names_each_negative_counter() -> void:
	"""Debt and all six counters are `0..INT64_MAX`; every one is checked, not just the first."""
	assert_false(_restore_plain(10, -1, SimClockScript.SPEED_NORMAL, 0), "negative debt refuses")
	assert_equal(_refusal_of(10, -1, 1, 0, RESTORE_COUNTERS).code,
		SimClockScript.REFUSE_RESTORE_NEGATIVE_DEBT, "negative debt code")
	for index: int in RESTORE_COUNTER_NAMES.size():
		var counters: Array[int] = RESTORE_COUNTERS.duplicate()
		counters[index] = -1
		assert_false(_restore_with_counters(10, 0, SimClockScript.SPEED_NORMAL, 0, counters),
			"a negative %s refuses" % RESTORE_COUNTER_NAMES[index])
		var refusal: SimClockScript.RestoreRefusal = _refusal_of(10, 0, 1, 0, counters)
		assert_equal(refusal.code, SimClockScript.REFUSE_RESTORE_NEGATIVE_COUNTER,
			"negative %s code" % RESTORE_COUNTER_NAMES[index])
		assert_true(refusal.detail.begins_with(RESTORE_COUNTER_NAMES[index]),
			"the refusal names %s, not another counter" % RESTORE_COUNTER_NAMES[index])


func test_a_refused_restore_leaves_the_clock_byte_identical() -> void:
	"""Allocate before consume (decision 0059): validation completes before the first assignment.

	The LATE invalid argument is the one that matters. If the tick were assigned before the sixth
	counter was checked, this clock would come back holding a restored tick beside its own old
	counters -- a world that never existed.
	"""
	_put_the_clock_in_a_used_state()
	_watch_every_clock_signal()
	var before: String = _snapshot(_clock)
	var late_invalid: Array[int] = [1, 2, 3, 4, 5, -1]
	assert_false(_restore_with_counters(999999, 2500001, SimClockScript.SPEED_DOUBLE,
		SimClockScript.MENU, late_invalid), "a late invalid argument refuses")
	assert_equal(_snapshot(_clock), before, "every field survives a late refusal unchanged")
	assert_false(_restore_with_counters(-1, 2500001, SimClockScript.SPEED_DOUBLE,
		SimClockScript.MENU, RESTORE_COUNTERS), "an early invalid argument refuses")
	assert_equal(_snapshot(_clock), before, "every field survives an early refusal unchanged")
	assert_false(_restore_with_counters(999999, 0, 3, SimClockScript.MENU, RESTORE_COUNTERS),
		"speed 3 refuses")
	assert_equal(_snapshot(_clock), before, "every field survives a refused speed unchanged")
	_assert_no_clock_signal_fired("three refused restores")


func test_a_refused_restore_does_not_even_write_its_own_reason() -> void:
	"""Transient diagnostics are unchanged on refusal; the reason comes from the pure validator.

	So the save owner reports the refusal through its own result rather than reading it back off
	a clock it has just failed to write.
	"""
	_put_the_clock_in_a_used_state()
	var kept_error: String = _clock.last_error()
	var kept_diagnostic: String = _clock.last_diagnostic()
	assert_false(_restore_plain(-5, 0, SimClockScript.SPEED_NORMAL, 0), "restore refuses")
	assert_equal(_clock.last_error(), kept_error, "last_error() is untouched by the refusal")
	assert_equal(_clock.last_diagnostic(), kept_diagnostic, "last_diagnostic() is untouched")
	var refusal: SimClockScript.RestoreRefusal = _refusal_of(-5, 0, 1, 0, RESTORE_COUNTERS)
	assert_false(refusal.is_ok(), "the pure validator carries the verdict")
	assert_true(refusal.detail != "", "and the reason the caller reports")


func test_the_pure_validator_mutates_no_clock() -> void:
	"""`restore_refusal()` is static and side-effect free, so a codec can share its checks."""
	_put_the_clock_in_a_used_state()
	var before: String = _snapshot(_clock)
	assert_true(_refusal_of(42, 2500001, SimClockScript.SPEED_DOUBLE, SimClockScript.PLAYER,
		RESTORE_COUNTERS).is_ok(), "a valid record validates")
	assert_false(_refusal_of(42, 2500001, 3, SimClockScript.PLAYER, RESTORE_COUNTERS).is_ok(),
		"an invalid one does not")
	assert_equal(_snapshot(_clock), before, "neither call touched the clock")
	assert_equal(SimClockScript.restore_refusal(0, 0, 1, 0, 0, 0, 0, 0, 0, 0).code,
		SimClockScript.REFUSE_NONE, "the accepted case carries REFUSE_NONE")


func test_a_successful_restore_clears_only_the_transient_strings() -> void:
	"""On success the ten fields are the saved ones and only the two diagnostic strings reset."""
	_put_the_clock_in_a_used_state()
	assert_true(_restore_with_counters(4321, 1000000, SimClockScript.SPEED_NORMAL,
		SimClockScript.VICTORY, RESTORE_COUNTERS), "restore accepted")
	assert_equal(_clock.last_error(), "", "last_error() cleared")
	assert_equal(_clock.last_diagnostic(), "", "last_diagnostic() cleared")
	assert_equal(_clock.completed_tick(), 4321, "the restored tick replaced the driven one")
	assert_equal(_clock.pause_mask(), SimClockScript.VICTORY,
		"the saved mask replaced the live PLAYER and CRITICAL holds")
	assert_equal(_clock.acknowledged_catchup_resets(), RESTORE_COUNTERS[2],
		"the saved acknowledgement count replaced the live one")
	assert_equal(_clock.acknowledged_ticks_discarded(), RESTORE_COUNTERS[3],
		"restore is not a second path that drops owed ticks; it installs the recorded total")


func test_restore_accepts_the_whole_representable_counter_domain() -> void:
	"""`0..INT64_MAX`: the top of that domain is the int64 itself, and it must not be clamped."""
	var int64_max: int = 9223372036854775807
	assert_true(_clock.restore_runtime(0, int64_max, SimClockScript.SPEED_NORMAL, 0, int64_max,
		int64_max, int64_max, int64_max, int64_max, int64_max), "the extreme record is accepted")
	assert_equal(_clock.debt(), int64_max, "debt is not clamped to the codec's tighter bound")
	assert_equal(_clock.fallback_count(), int64_max, "fallback count exact")
	assert_equal(_clock.day_boundaries_crossed(), int64_max, "day boundaries exact")
	assert_equal(_clock.advance(1, _count_step), 0,
		"the next frame refuses its own overflowing arithmetic rather than wrapping")
	assert_true(_clock.last_error() != "", "and records why")
	assert_equal(_clock.debt(), int64_max, "leaving the restored debt exactly as it was")


func test_a_restored_clock_continues_identically_to_an_uninterrupted_one() -> void:
	"""Host continuation: same subsequent elapsed input, same tick, debt, speed and mask.

	The uninterrupted clock carries a nonzero retained debt and a non-default speed at the moment
	it is copied, which is what makes this more than a comparison of two zeroed states.
	"""
	assert_true(_clock.set_speed(SimClockScript.SPEED_DOUBLE), "2x accepted")
	_run_frames(7, 33333)
	assert_true(_clock.debt() > 0, "the source clock retains a sub-tick debt")
	var restored: SimClockScript = SimClockScript.new()
	assert_true(restored.restore_runtime(_clock.completed_tick(), _clock.debt(),
		_clock.requested_speed(), _clock.pause_mask(), _clock.fallback_count(),
		_clock.diagnostic_pause_count(), _clock.acknowledged_catchup_resets(),
		_clock.acknowledged_ticks_discarded(), _clock.subtick_debt_discards(),
		_clock.day_boundaries_crossed()), "restore accepted")
	assert_equal(_snapshot(restored), _snapshot(_clock), "the copy starts where the source stands")
	for _index: int in 40:
		assert_equal(restored.advance(16667), _clock.advance(16667), "identical ticks per frame")
	assert_equal(restored.completed_tick(), _clock.completed_tick(), "same completed tick")
	assert_equal(restored.debt(), _clock.debt(), "same retained debt")
	assert_equal(restored.pause_mask(), _clock.pause_mask(), "same pause mask")
