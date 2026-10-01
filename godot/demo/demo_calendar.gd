extends RefCounted
## The live demo's ONE calendar: a settlement tick counter that runs on the demo clock. Decision 0196.
##
## Farm time, the weather and the date the HUD shows are all this one counter. It counts on the
## REAL offset calendar (scripts/core/sim_clock.gd: 750 ticks an hour, 18000 a day, tick 0 = 06:00 of
## spring day 1, hour crossings where `(tick + 4500) mod 750 == 0`), so every §5.6 rule stated in game
## hours and days -- growth, the 48-hour grace, withering at 120 hours, fallow days, the compost
## season -- and §5.10's daily weather run unchanged on it.
##
## HOW FAST THOSE TICKS COME: THE SETTLEMENT'S OWN RATE. Brendan's ruling of 2026-10-01 (decision 0421): at 1x one
## game day lasts ten real minutes, as the GDD adopts (docs/game_gdd.md §5.1: "At 1x: day 10 minutes, season 120
## minutes, year 8 hours"; REQ-SET-006). So HOUR_USEC is 25 000 000 demo microseconds -- 25 s a game hour, 750 ticks
## in it: exactly the settlement's fixed "30 ticks/real second at 1x" (GDD §4.1's time row), 2x and 4x scaling it.
## Walking and work run on the same demo microseconds (demo_clock.gd), so a resident at 0.72 m/s covers 18 m in a
## game hour, and the village fits its day. (Until this ruling the calendar ran ten times faster -- 2.5 s a game
## hour, a day a minute -- and a walk across the village took most of a day; decision 0196 recorded that compression,
## 0421 retires it.) It is driven ONLY by the demo clock's microseconds (demo_clock.gd), so the HUD's pause stops it
## and 2x / 4x scale it exactly. Everything on the calendar reads its time HERE and keeps no conversion of its own:
## the farm, the weather (demo/weather/demo_weather.gd reads its hour from here), the kitchen, the night, the
## fishery, the HUD's date (demo/ui/demo_hud_date.gd prints `date_text()`) and the action cards' work times
## (action_card.gd `hours_text`).
##
## WHO ADVANCES IT. Exactly one owner: the farm's model (demo/farm/farm_sim.gd `advance_usec`), because
## every hour crossing and midnight must run the real crop/weather stage in order. Everyone else reads.
## The settlement's own clock (GameManager) keeps running apart and is not written.
##
## Integer throughout: a frame's demo microseconds are converted to ticks with the remainder kept,
## so nothing is lost or gained however the frames are cut.

const SimClock := preload("res://scripts/core/sim_clock.gd")

## Demo microseconds per game hour (see above): 25 s, 750 ticks at 30 a second.
const HOUR_USEC: int = 25000000
## Demo microseconds per game day: ten minutes at 1x.
const DAY_USEC: int = HOUR_USEC * SimClock.HOURS_PER_DAY
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
	@warning_ignore("integer_division") return scaled / HOUR_USEC


static func usec_for_ticks(ticks: int) -> int:
	"""The demo microseconds `ticks` calendar ticks take at 1x (rounded down): work stated in ticks, as the kitchen's
	step rate, shown in the demo time every other work time is counted in (action_card.gd)."""
	@warning_ignore("integer_division") return ticks * HOUR_USEC / SimClock.TICKS_PER_HOUR


static func next_hour_crossing(after_tick: int) -> int:
	"""The first hour crossing strictly after `after_tick` (ARCH-TICK-002's `(k+4500) mod 750`)."""
	var into_hour: int = posmod(after_tick + SimClock.CALENDAR_OFFSET_TICKS, SimClock.TICKS_PER_HOUR)
	return after_tick + SimClock.TICKS_PER_HOUR - into_hour


static func is_day_boundary(boundary_tick: int) -> bool:
	"""Whether an hour crossing is also a midnight (sim_clock's own predicate)."""
	return SimClock.is_day_boundary(boundary_tick)


static func hour_index_at(at_tick: int) -> int:
	"""Whole game hours since midnight before spring day 1 at a tick: changes exactly at each crossing."""
	@warning_ignore("integer_division") return (at_tick + SimClock.CALENDAR_OFFSET_TICKS) / SimClock.TICKS_PER_HOUR


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
