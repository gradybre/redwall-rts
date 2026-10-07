extends RefCounted
## WHICH WILDLIFE IS ABOUT, AND WHEN. Decision 1631 (feature #11, wildlife). Pure, static and presentation only.
##
## AMBIENT, NOT SIMULATED. The GDD keeps FaunaStockReserved canonical empty (REQ-SET-059/065) and the fauna contract
## (docs/planning/fauna_component_validation_contract.md) introduces "no active fauna": so nothing here is a population,
## a stock or a row. How many of each animal show is a FUNCTION of the date, the hour and the weather the HUD already
## shows -- the same answer for the same inputs, with no state, no save and nothing the simulation reads. Nobody hunts,
## feeds or harms them (REQ-ADM-001: no mammal or bird harvest source), and they never swarm (ECO-038's bounded risk).
##
## THE ANIMALS (art pass 2, decision 0951; sizes DEC-047): a robin, a peacock butterfly, a common frog and a brown trout.
## The robin is a wild garden bird, never a resident: no clothes, no name, no voice, not selectable (sapient birds --
## sparrows, kestrels -- are residents in this world, so the robin is drawn at bird scale, 0.45 m beside the 1.00 m mouse,
## and only ever hops, pecks and flies).
##
## THE TABLES (demo values, from the animals' own year in an English wood and garden):
##   * ROBIN: about all year (robins hold winter territories), fewer in winter; out in DAYLIGHT only (GDD §5.10's
##     seasonal daylight, daylight_curves.gd SUNRISE_MIN / SUNSET_MIN). Rain halves them (they shelter); none fly in rain
##     or snow (`may_fly`).
##   * BUTTERFLY (the peacock): hibernates through winter and flies spring to autumn, most in summer; only in dry
##     daylight hours, an hour clear of dawn and dusk, at FLY_TENTHS or warmer.
##   * FROG: at the pond's edge from spring (spawning) to autumn, day and night; gone below freezing (hibernating).
##   * TROUT: rising and leaping in the pond and the stream's run from spring to autumn, in daylight; never in winter
##     (and never through ice: the water freezes only in winter, pond_ice.gd).

const DaylightCurves := preload("res://demo/world/daylight_curves.gd")
const WeatherScript := preload("res://demo/weather/demo_weather.gd")

const ROBIN: int = 0
const BUTTERFLY: int = 1
const FROG: int = 2
const TROUT: int = 3
const KINDS: int = 4
const KIND_NAMES: Array[String] = ["robin", "butterfly", "frog", "trout"]
## Per kind, per season (spring, summer, autumn, winter; row `kind x SEASONS + season`): how many show at most (demo
## values; see THE TABLES).
const SEASON_COUNT: PackedInt32Array = [
	4, 4, 4, 3,
	3, 5, 2, 0,
	3, 2, 2, 0,
	2, 2, 2, 0,
]
## The most of each kind any hour can show: the pools are sized to it.
const MAX_COUNT: PackedInt32Array = [4, 5, 3, 2]
## Butterflies fly at this air temperature or warmer (tenths of a degree C; demo value).
const FLY_TENTHS: int = 100
## Butterflies keep this many minutes clear of sunrise and sunset (demo value: the cool of the day).
const BUTTERFLY_MARGIN_MIN: int = 60
const MINUTES_PER_HOUR: int = 60
const SEASONS: int = 4


static func is_daylight(season: int, hour: int, margin_min: int = 0) -> bool:
	"""Whether `hour` (its start) lies in §5.10's daylight for `season`, `margin_min` minutes clear of sunrise and
	sunset."""
	var at: int = hour * MINUTES_PER_HOUR
	var s: int = clampi(season, 0, SEASONS - 1)
	return at >= DaylightCurves.SUNRISE_MIN[s] + margin_min and at < DaylightCurves.SUNSET_MIN[s] - margin_min


static func count_of(kind: int, season: int, hour: int, condition: int, air_tenths: int) -> int:
	"""How many of `kind` show in this season, hour, weather condition (demo_weather.gd COND_*) and air (see THE
	TABLES). 0 for an unknown kind."""
	if kind < 0 or kind >= KINDS:
		return 0
	var most: int = season_count(kind, season)
	match kind:
		ROBIN:
			if not is_daylight(season, hour):
				return 0
			@warning_ignore("integer_division") var sheltered: int = most / 2
			return sheltered if is_wet(condition) else most
		BUTTERFLY:
			var warm_dry: bool = condition == WeatherScript.COND_CLEAR and air_tenths >= FLY_TENTHS
			return most if warm_dry and is_daylight(season, hour, BUTTERFLY_MARGIN_MIN) else 0
		FROG:
			return most if not is_freezing(condition) else 0
	return most if is_daylight(season, hour) and not is_freezing(condition) else 0


static func season_count(kind: int, season: int) -> int:
	"""The most of `kind` a season shows (SEASON_COUNT)."""
	return SEASON_COUNT[kind * SEASONS + clampi(season, 0, SEASONS - 1)]


static func is_wet(condition: int) -> bool:
	"""Whether rain or snow is falling."""
	return condition == WeatherScript.COND_RAIN or condition == WeatherScript.COND_SNOW


static func is_freezing(condition: int) -> bool:
	"""Whether the air is at or below freezing (demo_weather.gd: frost or snow)."""
	return condition == WeatherScript.COND_FROST or condition == WeatherScript.COND_SNOW


static func may_fly(condition: int) -> bool:
	"""Whether a robin takes wing now: not in rain or snow (it keeps to cover and hops)."""
	return not is_wet(condition)
