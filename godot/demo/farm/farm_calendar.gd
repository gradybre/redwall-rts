extends RefCounted
## The demo farm's calendar: a settlement tick counter that runs on the demo clock. Decision 0196.
##
## The farm advances the REAL crop store on the REAL offset calendar (scripts/core/sim_clock.gd:
## 750 ticks an hour, 18000 a day, tick 0 = 06:00 of spring day 1, hour crossings where
## `(tick + 4500) mod 750 == 0`), so every §5.6 rule that is stated in game hours and days -- growth,
## the 48-hour grace, withering at 120 hours, fallow days, the compost season -- runs unchanged.
##
## WHAT IS A DEMO VALUE: HOW FAST THOSE TICKS COME. At the settlement's own rate a game hour is
## 25 real seconds and a crop takes 50 to 80 real minutes to ripen, which no demo can show. The
## farm's calendar therefore runs FARM_HOUR_USEC demo microseconds to the game hour: 2.5 s, so a
## farm day is a minute at 1x (15 s at 4x) and a 120-hour crop ripens in five minutes (75 s at
## 4x). It is still driven ONLY by the demo clock's microseconds (demo_clock.gd), so the HUD's
## pause stops it and 2x / 4x scale it exactly. It is a separate calendar from the HUD's date,
## which keeps showing the settlement's own clock.
##
## Integer throughout: a frame's demo microseconds are converted to ticks with the remainder kept,
## so nothing is lost or gained however the frames are cut.

const SimClock := preload("res://scripts/core/sim_clock.gd")

## Demo microseconds per farm game hour (see above).
const FARM_HOUR_USEC: int = 2500000

## The farm's current tick on the offset calendar (0 = 06:00, spring day 1).
var tick: int = 0
## Demo microseconds x ticks-per-hour not yet worth a whole tick.
var _remainder: int = 0
var _calendar: SimClock.Calendar = SimClock.Calendar.new(0)


func ticks_for_usec(usec: int) -> int:
	"""How many whole ticks `usec` more demo microseconds bring, keeping the rest for next time.
	Negative input brings none (the clock never runs backwards)."""
	if usec <= 0:
		return 0
	var scaled: int = _remainder + usec * SimClock.TICKS_PER_HOUR
	_remainder = scaled % FARM_HOUR_USEC
	return scaled / FARM_HOUR_USEC


static func next_hour_crossing(after_tick: int) -> int:
	"""The first hour crossing strictly after `after_tick` (ARCH-TICK-002's `(k+4500) mod 750`)."""
	var into_hour: int = posmod(after_tick + SimClock.CALENDAR_OFFSET_TICKS, SimClock.TICKS_PER_HOUR)
	return after_tick + SimClock.TICKS_PER_HOUR - into_hour


static func is_day_boundary(boundary_tick: int) -> bool:
	"""Whether an hour crossing is also a midnight (sim_clock's own predicate)."""
	return SimClock.is_day_boundary(boundary_tick)


func calendar_at(at_tick: int) -> SimClock.Calendar:
	"""The offset calendar at a tick, in the one reused Calendar (read it before the next call)."""
	SimClock.calendar_at_into(at_tick, _calendar)
	return _calendar


func remainder() -> int:
	"""The carried sub-tick remainder (for tests)."""
	return _remainder
