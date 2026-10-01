extends RefCounted
## The live demo's ONE calendar: a settlement tick counter that runs on the demo clock. Decision 0196.
##
## Farm time, the weather and the date the HUD shows are all this one counter. It counts on the
## REAL offset calendar (scripts/core/sim_clock.gd: 750 ticks an hour, 18000 a day, tick 0 = 06:00 of
## spring day 1, hour crossings where `(tick + 4500) mod 750 == 0`), so every §5.6 rule stated in game
## hours and days -- growth, the 48-hour grace, withering at 120 hours, fallow days, the compost
## season -- and §5.10's daily weather run unchanged on it.
##
## WHAT IS A DEMO VALUE: HOW FAST THOSE TICKS COME. At the settlement's own rate a game hour is 25 real
## seconds and a crop takes 50 to 80 real minutes to ripen, which no demo can show. So the calendar
## runs HOUR_USEC demo microseconds to the game hour: 2.5 s, a day a minute at 1x (15 s at 4x), a
## 120-hour crop ripe in five minutes. It is driven ONLY by the demo clock's microseconds
## (demo_clock.gd), so the HUD's pause stops it and 2x / 4x scale it exactly. That one compression
## applies to everything on the calendar: the farm, the weather (demo/weather/demo_weather.gd reads
## its hour from here) and the HUD's date (demo/ui/demo_hud_date.gd prints `date_text()`).
##
## WHO ADVANCES IT. Exactly one owner: the farm's model (demo/farm/farm_sim.gd `advance_usec`), because
## every hour crossing and midnight must run the real crop/weather stage in order. Everyone else reads.
## The settlement's own clock (GameManager) keeps running apart and is not written.
##
## Integer throughout: a frame's demo microseconds are converted to ticks with the remainder kept,
## so nothing is lost or gained however the frames are cut.

const SimClock := preload("res://scripts/core/sim_clock.gd")

## Demo microseconds per game hour (see above).
const HOUR_USEC: int = 2500000
## The season names the demo prints (sim_clock's own are lower case).
const SEASON_TITLES: Array[String] = ["Spring", "Summer", "Autumn", "Winter"]

## The current tick on the offset calendar (0 = 06:00, spring day 1).
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
	_remainder = scaled % HOUR_USEC
	return scaled / HOUR_USEC


static func next_hour_crossing(after_tick: int) -> int:
	"""The first hour crossing strictly after `after_tick` (ARCH-TICK-002's `(k+4500) mod 750`)."""
	var into_hour: int = posmod(after_tick + SimClock.CALENDAR_OFFSET_TICKS, SimClock.TICKS_PER_HOUR)
	return after_tick + SimClock.TICKS_PER_HOUR - into_hour


static func is_day_boundary(boundary_tick: int) -> bool:
	"""Whether an hour crossing is also a midnight (sim_clock's own predicate)."""
	return SimClock.is_day_boundary(boundary_tick)


static func hour_index_at(at_tick: int) -> int:
	"""Whole game hours since midnight before spring day 1 at a tick: changes exactly at each crossing."""
	return (at_tick + SimClock.CALENDAR_OFFSET_TICKS) / SimClock.TICKS_PER_HOUR


func hour_index() -> int:
	"""The current hour's index (see hour_index_at)."""
	return hour_index_at(tick)


func calendar_at(at_tick: int) -> SimClock.Calendar:
	"""The offset calendar at a tick, in the one reused Calendar (read it before the next call)."""
	SimClock.calendar_at_into(at_tick, _calendar)
	return _calendar


func now() -> SimClock.Calendar:
	"""The calendar at the current tick (the reused Calendar)."""
	return calendar_at(tick)


static func day_text(season: int, season_day: int) -> String:
	"""'Spring 3' -- a season-local day as the demo prints it."""
	return "%s %d" % [SEASON_TITLES[season], season_day]


func date_text() -> String:
	"""THE DEMO'S DATE: 'Y1 Spring 3, 14:00'. The HUD's date trigger, the farm panel's clock line and
	every demo notice's stamp are this one string (allocates: call on an hour change, not per frame)."""
	var at: SimClock.Calendar = now()
	return "Y%d %s, %02d:00" % [at.year, day_text(at.season, at.season_day), at.hour]


func remainder() -> int:
	"""The carried sub-tick remainder (for tests)."""
	return _remainder
