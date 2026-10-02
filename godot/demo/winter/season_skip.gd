extends RefCounted
## "SKIP TO NEXT SEASON" (Brendan's ruling 4): the Demo Lab's trigger (F8). Decision 0571. It advances the ONE calendar
## (demo_calendar.gd) to LAND_HOUR -- 06:00, the hour the demo opens at -- on day 1 of the next season, exactly on the
## tick, an hour at a time, and lets the systems catch up deterministically. The spring opening is untouched.
##
## WHAT RUNS, hour by hour, in order (the calendar's owner and the winter in lockstep, so each hour reads its own day's
## weather):
##   * the farm (`advance`: demo_farm.gd `advance_calendar`) -- every hour crossing and midnight of the real crop and
##     §5.10 weather stages: the crops grow, ripen and wither, the beds take their rain and dry, the season's event is
##     drawn and announced, the pantry's lots age and spoil, the routine jobs are raised and the alerts posted;
##   * the winter (`each_hour`: demo_winter.gd `catch_up`) -- the hearths burn their wood and the rooms warm or cool;
## and once the calendar has landed: the kitchen's quiet catch-up (kitchen.gd `skip_to_hour`: the table's portions age,
## no meal is called, cooked or eaten, nobody's hunger falls), and the winter's exposure clock re-based (the jump is not
## lived). The woods (their daily regrowth and deadfall), the fishery (the pond's ice, at the day it lands on) and the
## people catch up by themselves on the next frame, from the calendar.
##
## WHAT IS SKIPPED, and said so in the village news: the residents' walking and work (they carry on from where they
## stand), the kitchen's meals, and the exposure the hours would have brought.

const CalendarScript := preload("res://demo/demo_calendar.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const Rules := preload("res://demo/winter/winter_rules.gd")

## The hour a skip lands on: 06:00, the demo's opening hour (demo_calendar.gd: tick 0 is 06:00 of spring 1).
const LAND_HOUR: int = 6
## Never more hour steps than a season and a day (a guard: each step crosses one hour).
const MAX_STEPS: int = (SimClock.DAYS_PER_SEASON + 1) * SimClock.HOURS_PER_DAY
const SKIPPED: String = "Skipped to %s: %d hours passed. The crops, the stores and the weather ran; the residents' walking and work, the kitchen's meals and the cold they would have felt did not"


static func target_hour(calendar: CalendarScript) -> int:
	"""The hour index a skip lands on: LAND_HOUR on day 1 of the season after the current one."""
	return Rules.next_season_start_hour(calendar.hour_index(), LAND_HOUR)


static func tick_of_hour(hour_index: int) -> int:
	"""The calendar tick an hour index starts at (the inverse of demo_calendar.gd `hour_index_at`)."""
	return hour_index * SimClock.TICKS_PER_HOUR - SimClock.CALENDAR_OFFSET_TICKS


static func usec_for_exact_ticks(calendar: CalendarScript, ticks: int) -> int:
	"""The demo microseconds that bring exactly `ticks` more ticks given the calendar's carried remainder (the smallest
	such): ceil((ticks x HOUR_USEC - remainder) / TICKS_PER_HOUR)."""
	var want: int = ticks * CalendarScript.HOUR_USEC - calendar.remainder()
	return Rules.div(want + SimClock.TICKS_PER_HOUR - 1, SimClock.TICKS_PER_HOUR)


static func run(calendar: CalendarScript, advance: Callable, each_hour: Callable) -> int:
	"""Advance the calendar to `target_hour` an hour crossing at a time through `advance(usec) -> int` (the calendar's
	owner), calling `each_hour()` after each step. Returns the hours stepped."""
	var landing: int = tick_of_hour(target_hour(calendar))
	var steps: int = 0
	while calendar.tick < landing and steps < MAX_STEPS:
		var next: int = mini(CalendarScript.next_hour_crossing(calendar.tick), landing)
		advance.call(usec_for_exact_ticks(calendar, next - calendar.tick))
		if each_hour.is_valid():
			each_hour.call()
		steps += 1
	return steps


static func skipped_line(calendar: CalendarScript, hours: int) -> String:
	"""What the news says after a skip (see WHAT IS SKIPPED)."""
	return SKIPPED % [calendar.date_text(), hours]
