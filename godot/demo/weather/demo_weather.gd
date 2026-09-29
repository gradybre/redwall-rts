extends RefCounted
## The live demo's ONE weather source. Decision 0196 (live demo). Presentation only: it slows the
## demo cast's surface walking and drives the demo's rain, snow and light; nothing here feeds the
## simulation, and nothing is written into the real Weather row.
##
## ---------------------------------------------------------------------------------------
## WHY A CYCLE AND NOT THE LIVE ROW. The real §5.10 model (scripts/core/weather.gd, driven by
## crop_weather.gd) is reachable -- SettlementSystem.crop_weather().weather() -- but it cannot show
## a demo its weather: it writes ONE climate per game day (18000 ticks, ten real minutes at 1x),
## the first spring is a forced Ideal spell, winter begins on day 37 (six real hours at 1x), and its
## `rain` is a daily moisture figure, not "it is raining now". So the demo drives a COMPRESSED YEAR
## from its own clock (demo_clock.gd), and every spell's climate is the REAL TABLE'S: the season
## baseline and the event's temperature and rain are read from weather.gd's own readers
## (`temperature_tenths_for`, `rain_for`), never copied. Only the order of spells, their length and
## how a climate reads as sky and footing are demo values.
##
##   spell  season  event         temperature  rain   reads as
##   0      spring  ideal spell   18.0 C       1800   clear
##   1      spring  heavy rain     9.0 C       3200   rain
##   2      summer  calm days     22.0 C        300   clear
##   3      autumn  heavy rain     7.0 C       2700   rain
##   4      autumn  early frost   -3.0 C        700   snow
##   5      winter  (baseline)    -5.0 C          0   frost
##   6      winter  hard freeze  -12.0 C          0   frost
##
## HOW A CLIMATE READS (demo): rain >= RAIN_FROM (only §5.10's heavy-rain days reach it) is RAIN,
## unless the temperature is at or below freezing, when rain >= SNOW_FROM is SNOW; at or below
## freezing otherwise is FROST; anything else is CLEAR.
##
## THE SLOWDOWN. Surface walking runs at SURFACE_SPEED_PERMILLE of a resident's walk speed. RAIN's
## 800 is §5.10's heavy-rain "outdoor work x0.80" borrowed as a walking factor (the table states no
## walking factor); SNOW's and FROST's are demo values. Tunnels are dry and sheltered: travel in
## them is never slowed by weather, so the tunnel planner prefers them in bad weather.
##
## TIME. Integer microseconds of demo time (demo_clock.frame_usec), so the HUD's pause freezes the
## weather and 2x / 4x run it faster. Other code reads it through the query functions below.

const WeatherScript := preload("res://scripts/core/weather.gd")

const COND_CLEAR: int = 0
const COND_RAIN: int = 1
const COND_SNOW: int = 2
const COND_FROST: int = 3
const CONDITION_NAMES: Array[String] = ["Clear", "Rain", "Snow", "Frost"]
## Per condition (COND_*): surface walking speed, per mille of a resident's walk speed.
const SURFACE_SPEED_PERMILLE: Array[int] = [1000, 800, 600, 850]

## Demo: how a day's §5.10 climate reads (see HOW A CLIMATE READS).
const RAIN_FROM: int = 2500
const SNOW_FROM: int = 500
const FREEZING_TENTHS: int = 0
## Demo: how long each spell lasts, in demo microseconds (45 s at 1x).
const SPELL_USEC: int = 45000000

const SPELL_SEASONS: Array[int] = [
	WeatherScript.SEASON_SPRING, WeatherScript.SEASON_SPRING, WeatherScript.SEASON_SUMMER,
	WeatherScript.SEASON_AUTUMN, WeatherScript.SEASON_AUTUMN, WeatherScript.SEASON_WINTER,
	WeatherScript.SEASON_WINTER,
]
const SPELL_EVENTS: Array[int] = [
	WeatherScript.EVENT_IDEAL_SPELL, WeatherScript.EVENT_HEAVY_RAIN, WeatherScript.EVENT_CALM_DAYS,
	WeatherScript.EVENT_HEAVY_RAIN, WeatherScript.EVENT_EARLY_FROST, WeatherScript.EVENT_NONE,
	WeatherScript.EVENT_HARD_FREEZE,
]
const SEASON_NAMES: Array[String] = ["Spring", "Summer", "Autumn", "Winter"]
## By compiled EventDefinition id (weather.gd EVENT_KEYS order).
const EVENT_NAMES: Array[String] = ["Blight", "Calm days", "Drought", "Early frost", "Hard freeze",
	"Heavy rain", "Ideal spell"]

var spell: int = 0
var spell_usec: int = 0
## Bumped whenever the spell changes (a drawer or notice can follow it cheaply).
var revision: int = 0

var _temperature: PackedInt32Array = PackedInt32Array()
var _rain: PackedInt32Array = PackedInt32Array()


func _init() -> void:
	"""Read every spell's climate from the real §5.10 tables once."""
	var table := WeatherScript.new()
	_temperature.resize(SPELL_SEASONS.size())
	_rain.resize(SPELL_SEASONS.size())
	for k in SPELL_SEASONS.size():
		_temperature[k] = table.temperature_tenths_for(SPELL_SEASONS[k], SPELL_EVENTS[k]).value
		_rain[k] = table.rain_for(SPELL_SEASONS[k], SPELL_EVENTS[k]).value


static func classify(temperature_tenths: int, rain: int) -> int:
	"""COND_*: how a day's temperature (tenths of a degree) and rain read (see HOW A CLIMATE READS)."""
	if temperature_tenths <= FREEZING_TENTHS:
		return COND_SNOW if rain >= SNOW_FROM else COND_FROST
	return COND_RAIN if rain >= RAIN_FROM else COND_CLEAR


static func speed_of(condition: int) -> int:
	"""Surface walking speed per mille under a condition."""
	return SURFACE_SPEED_PERMILLE[condition]


func spell_count() -> int:
	"""How many spells the compressed year has."""
	return SPELL_SEASONS.size()


func advance(usec: int) -> bool:
	"""Run the weather on by `usec` demo microseconds. True when the spell changed."""
	if usec <= 0:
		return false
	spell_usec += usec
	if spell_usec < SPELL_USEC:
		return false
	var passed := spell_usec / SPELL_USEC
	spell_usec -= passed * SPELL_USEC
	spell = (spell + passed) % spell_count()
	revision += 1
	return true


func set_spell(k: int) -> void:
	"""Jump to spell `k` (wrapped into range), from its start: the panel's demo "Next weather"."""
	spell = posmod(k, spell_count())
	spell_usec = 0
	revision += 1


func next_spell() -> void:
	"""Jump to the next spell."""
	set_spell(spell + 1)


func temperature_tenths() -> int:
	"""The spell's temperature, tenths of a degree C (weather.gd's own table)."""
	return _temperature[spell]


func rain() -> int:
	"""The spell's rain figure (weather.gd's own table)."""
	return _rain[spell]


func season() -> int:
	"""The spell's §4.3 Season ordinal."""
	return SPELL_SEASONS[spell]


func event() -> int:
	"""The spell's compiled EventDefinition id, or weather.gd's EVENT_NONE for a baseline day."""
	return SPELL_EVENTS[spell]


func condition() -> int:
	"""COND_*: how the spell reads."""
	return classify(temperature_tenths(), rain())


func surface_speed_permille() -> int:
	"""THE QUERY: surface walking speed per mille of walk speed under the current weather."""
	return speed_of(condition())


func is_wet() -> bool:
	"""Whether rain is falling (what soaks wet ground; see tunnel_hazards.gd)."""
	return condition() == COND_RAIN


func label() -> String:
	"""e.g. "Autumn, Heavy rain" (a baseline day names only the season)."""
	var name := SEASON_NAMES[season()]
	if event() == WeatherScript.EVENT_NONE:
		return name
	return "%s, %s" % [name, EVENT_NAMES[event()]]


func alert_line() -> String:
	"""A short line for the HUD's alert card: e.g. "Rain, walking 80%" or "Clear"."""
	var speed := surface_speed_permille()
	if speed == 1000:
		return CONDITION_NAMES[condition()]
	return "%s, walking %d%%" % [CONDITION_NAMES[condition()], speed / 10]


func readout() -> String:
	"""The panel's weather line: sky, temperature and what it does to walking."""
	var tenths := temperature_tenths()
	var sign := "-" if tenths < 0 else ""
	var degrees := "%s%d.%d °C" % [sign, absi(tenths) / 10, absi(tenths) % 10]
	var line := "%s — %s, %s" % [CONDITION_NAMES[condition()], label(), degrees]
	var speed := surface_speed_permille()
	if speed == 1000:
		return line + " · walking at full pace"
	return line + " · walking outdoors at %d%%, tunnels unaffected" % (speed / 10)
