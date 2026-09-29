extends RefCounted
## The live demo's ONE weather. Decision 0196 (live demo). Presentation only: it slows the demo cast's
## surface walking, soaks the tunnels' wet ground and drives the demo's rain, snow and light; nothing
## here feeds the simulation, and nothing is written into any Weather row.
##
## ---------------------------------------------------------------------------------------
## THE AUTHORITY IS THE FARM'S REAL WEATHER ROW. The farm (demo/farm/farm_sim.gd) runs a private
## `crop_weather.gd` stage whose daily leg is the REAL §5.10 model (`weather.gd`): season baselines,
## the forced first-spring Ideal spell, one seeded event per later season, and each day's rain, which
## the same stage credits to every bed's moisture at the day's start. This module holds no weather of
## its own: `bind()` points it at that row and at the demo's one calendar (demo_calendar.gd), and
## `sync()` re-reads both whenever the calendar's hour changes. So the rain that slows a walker is the
## rain that wets the beds, on the same day of the same calendar the HUD shows.
##
## HOW A DAY READS HOUR BY HOUR (demo values; §5.10 states rain per DAY, not "it is raining now"):
##   * SHOWERS: a day's rain figure falls as `rain / RAIN_PER_SHOWER_HOUR` whole hours of rain (at most
##     24), centred on SHOWER_CENTRE_HOUR -- spring's baseline 1200 is 6 hours (12:00-17:59), the Ideal
##     spell's 1800 is 9, spring heavy rain's 3200 is 16, summer's 300 one, winter's 0 none.
##   * THE HOUR'S AIR is the row's temperature, pulled down to the farm's demo frost-night figure in
##     a frost night's hours (farm_weather.gd, the same overlay the beds freeze by).
##   * CONDITION: at or below freezing, a rain hour is SNOW and any other FROST; above it, RAIN or CLEAR.
##
## THE SLOWDOWN. Surface walking runs at SURFACE_SPEED_PERMILLE of a resident's walk speed. RAIN's
## 800 is §5.10's heavy-rain "outdoor work x0.80" borrowed as a walking factor (the table states no
## walking factor); SNOW's and FROST's are demo values. Tunnels are dry and sheltered: travel in them
## is never slowed, so the tunnel planner prefers them in bad weather.
##
## UNBOUND (the headless suites' fixtures), it reads spring's §5.10 baseline at 06:00 of day 1 until
## a fixture calls `observe()` -- the same entry point `sync()` uses.

const WeatherScript := preload("res://scripts/core/weather.gd")
const FarmWeather := preload("res://demo/farm/farm_weather.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")

const COND_CLEAR: int = 0
const COND_RAIN: int = 1
const COND_SNOW: int = 2
const COND_FROST: int = 3
const CONDITION_NAMES: Array[String] = ["Clear", "Rain", "Snow", "Frost"]
## Per condition (COND_*): surface walking speed, per mille of a resident's walk speed.
const SURFACE_SPEED_PERMILLE: Array[int] = [1000, 800, 600, 850]
const FULL_SPEED_PERMILLE: int = 1000

## Demo: how a day's rain figure falls as whole hours of showers (see HOW A DAY READS).
const RAIN_PER_SHOWER_HOUR: int = 200
const SHOWER_CENTRE_HOUR: int = 15
const HOURS_PER_DAY: int = 24
const FREEZING_TENTHS: int = 0
const OPENING_SEASON: int = WeatherScript.SEASON_SPRING
const OPENING_DAY: int = 1
const OPENING_HOUR: int = 6
## By compiled EventDefinition id (weather.gd EVENT_KEYS order).
const EVENT_NAMES: Array[String] = ["Blight", "Calm days", "Drought", "Early frost", "Hard freeze",
	"Heavy rain", "Ideal spell"]

## Bumped whenever the condition changes (a drawer or the notice feed can follow it cheaply).
var revision: int = 0

var _calendar: CalendarScript = null
var _row: WeatherScript = null
var _synced: bool = false
var _hour_index: int = 0
var _season: int = OPENING_SEASON
var _season_day: int = OPENING_DAY
var _hour: int = OPENING_HOUR
var _day_tenths: int = 0
var _air_tenths: int = 0
var _rain: int = 0
var _event: int = WeatherScript.EVENT_NONE
var _condition: int = COND_CLEAR


func _init() -> void:
	"""Read spring's §5.10 baseline from the real tables (the unbound opening reading)."""
	var table := WeatherScript.new()
	var tenths: int = table.temperature_tenths_for(OPENING_SEASON, WeatherScript.EVENT_NONE).value
	var rain_figure: int = table.rain_for(OPENING_SEASON, WeatherScript.EVENT_NONE).value
	observe(OPENING_SEASON, OPENING_DAY, OPENING_HOUR, tenths, rain_figure, WeatherScript.EVENT_NONE)
	revision = 0


func bind(calendar: CalendarScript, row: WeatherScript) -> void:
	"""Follow this calendar and this real §5.10 row (the farm's), reading them now."""
	_calendar = calendar
	_row = row
	_synced = false
	sync()


func is_bound() -> bool:
	"""Whether a calendar and a row drive this weather."""
	return _calendar != null and _row != null


func sync() -> bool:
	"""Re-read the row and the calendar when the calendar's hour changed (an integer compare otherwise).
	True when the condition changed."""
	if not is_bound():
		return false
	var index: int = _calendar.hour_index()
	if _synced and index == _hour_index:
		return false
	_synced = true
	_hour_index = index
	var at: SimClock.Calendar = _calendar.now()
	var absolute_season: int = (at.absolute_day - 1) / SimClock.DAYS_PER_SEASON
	return observe(at.season, at.season_day, at.hour, _row.temperature_tenths(), _row.rain(),
		_row.active_event_on(absolute_season, at.season_day))


func observe(season: int, season_day: int, hour: int, day_tenths: int, rain_figure: int, event: int) -> bool:
	"""Take one hour's reading: a day's §5.10 temperature, rain and event at `hour` (see HOW A DAY
	READS). True when the condition changed."""
	_season = season
	_season_day = season_day
	_hour = hour
	_day_tenths = day_tenths
	_rain = rain_figure
	_event = event
	_air_tenths = FarmWeather.air_tenths(day_tenths, FarmWeather.is_frost_hour(season, season_day, hour))
	var now: int = classify(_air_tenths, is_rain_hour(rain_figure, hour))
	if now == _condition:
		return false
	_condition = now
	revision += 1
	return true


static func shower_hours(rain_figure: int) -> int:
	"""Whole hours of rain a day's rain figure falls as (0..24)."""
	return clampi(rain_figure / RAIN_PER_SHOWER_HOUR, 0, HOURS_PER_DAY)


static func first_shower_hour(rain_figure: int) -> int:
	"""The hour a day's showers begin: centred on SHOWER_CENTRE_HOUR, kept inside the day."""
	var hours: int = shower_hours(rain_figure)
	return clampi(SHOWER_CENTRE_HOUR - hours / 2, 0, HOURS_PER_DAY - hours)


static func is_rain_hour(rain_figure: int, hour: int) -> bool:
	"""Whether rain falls in `hour` of a day with this rain figure."""
	var first: int = first_shower_hour(rain_figure)
	return hour >= first and hour < first + shower_hours(rain_figure)


static func classify(air_tenths: int, raining: bool) -> int:
	"""COND_*: how an hour reads from its air temperature and whether it rains."""
	if air_tenths <= FREEZING_TENTHS:
		return COND_SNOW if raining else COND_FROST
	return COND_RAIN if raining else COND_CLEAR


static func speed_of(condition_id: int) -> int:
	"""Surface walking speed per mille under a condition."""
	return SURFACE_SPEED_PERMILLE[condition_id]


func condition() -> int:
	"""COND_*: the current hour's condition."""
	return _condition


func surface_speed_permille() -> int:
	"""THE WALKING QUERY: surface walking speed per mille of walk speed this hour."""
	return speed_of(_condition)


func is_wet() -> bool:
	"""Whether rain is falling this hour (what soaks the tunnels' wet ground; tunnel_hazards.gd)."""
	return _condition == COND_RAIN


func temperature_tenths() -> int:
	"""This hour's air, tenths of a degree C (the row's day temperature, or a frost night's)."""
	return _air_tenths


func day_temperature_tenths() -> int:
	"""The day's §5.10 temperature, tenths of a degree C."""
	return _day_tenths


func rain() -> int:
	"""The day's §5.10 rain figure -- the one the beds took at the day's start."""
	return _rain


func season() -> int:
	"""The §4.3 Season ordinal."""
	return _season


func season_day() -> int:
	"""The season-local day, 1..12."""
	return _season_day


func hour() -> int:
	"""The hour of the day the reading is for."""
	return _hour


func event() -> int:
	"""The day's active compiled EventDefinition id, or weather.gd's EVENT_NONE."""
	return _event


func label() -> String:
	"""e.g. "Spring 3, Heavy rain" (a baseline day names only the day)."""
	var day: String = CalendarScript.day_text(_season, _season_day)
	if _event < 0 or _event >= EVENT_NAMES.size():
		return day
	return "%s, %s" % [day, EVENT_NAMES[_event]]


func showers_text() -> String:
	"""The day's rain as hours: "rain 12:00–17:59", or "a dry day"."""
	var hours: int = shower_hours(_rain)
	if hours == 0:
		return "a dry day"
	var first: int = first_shower_hour(_rain)
	return "rain %02d:00–%02d:59" % [first, first + hours - 1]


func alert_line() -> String:
	"""A short line: e.g. "Rain, walking 80%" or "Clear"."""
	var speed: int = surface_speed_permille()
	if speed == FULL_SPEED_PERMILLE:
		return CONDITION_NAMES[_condition]
	return "%s, walking %d%%" % [CONDITION_NAMES[_condition], speed / 10]


func readout() -> String:
	"""The panels' weather line: sky, day and temperature, the day's showers, and walking."""
	var sign: String = "-" if _air_tenths < 0 else ""
	var degrees: String = "%s%d.%d °C" % [sign, absi(_air_tenths) / 10, absi(_air_tenths) % 10]
	var line: String = "%s — %s, %s · %s" % [CONDITION_NAMES[_condition], label(), degrees, showers_text()]
	var speed: int = surface_speed_permille()
	if speed == FULL_SPEED_PERMILLE:
		return line + " · walking at full pace"
	return line + " · walking outdoors at %d%%, tunnels unaffected" % (speed / 10)
