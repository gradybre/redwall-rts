extends RefCounted
## THE §5.10 EVENTS IN WORDS, and the notice when one begins or ends. Decision 1632 (feature #34). Presentation only.
##
## REQ-SET-142: "When a major event is scheduled, the system shall disclose its start, duration, and affected systems
## three days in advance". The farm's forecast line (farm_alerts.gd) said only which event was coming; it now says
## `forecast_text`: the event, its first day, how many days, and what it does -- every number read from the real
## §5.10 tables (scripts/core/weather.gd EVENT_*), never mirrored. And on the day an event starts the village is told
## again what it does (`began_text`), and when it is over (`ended_text`), once each (`follow`).
##
## Each event's effects, as §5.10 states them and as the demo applies them:
##   storm         rain, colder; boats stay at the jetty (fishery.gd, ferry_rules.gd); outdoor work x0.80
##                 (the work pace's "storm" factor, storm_pace.gd); lightning over the woods (weather_fx.gd)
##   drought       hot, no rain, the beds dry faster (farm_sim.gd); orchards want water (orchard_jobs.gd)
##   blight        crop damage a day (farm_sim.gd)
##   early frost   colder; frost on the beds (farm_weather.gd)
##   hard freeze   bitter cold; outdoor exposure twice as fast (demo_winter.gd); no boat leaves
##   calm days     no change: an announced safe interval
##   ideal spell   mild; crops grow faster; gentle rain

const WeatherCore := preload("res://scripts/core/weather.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")

## Per event id (weather.gd order): the event's name in a sentence.
const NAMES: Array[String] = ["blight", "calm days", "drought", "an early frost", "a hard freeze", "a storm",
	"an ideal spell"]
## Per event id: the notice's words when it begins and when it is over.
const BEGAN: Array[String] = ["Blight has come", "Calm days have come", "A drought has come", "An early frost has come",
	"A hard freeze has come", "A storm has come", "An ideal spell has come"]
const ENDED: Array[String] = ["The blight is over", "The calm days are over", "The drought is over",
	"The early frost is over", "The hard freeze is over", "The storm has passed", "The ideal spell is over"]
const TENTHS_PER_DEGREE: int = 10
const PERMILLE: int = 1000
const PER_PERCENT: int = 10

## The event last followed (`follow`), EVENT_NONE for none.
var _following: int = WeatherCore.EVENT_NONE


static func is_event(event: int) -> bool:
	"""Whether `event` is one of §5.10's compiled ids."""
	return event >= 0 and event < WeatherCore.EVENT_COUNT


static func name_of(event: int) -> String:
	"""The event's name in a sentence ("" for none)."""
	return NAMES[event] if is_event(event) else ""


static func effects_text(event: int, season: int = -1) -> String:
	"""What `event` does in `season` (-1: any), in words, from the real §5.10 tables (see the header); "" for none."""
	match event:
		WeatherCore.EVENT_HEAVY_RAIN:
			@warning_ignore("integer_division") var work: int = WeatherCore.EVENT_OUTDOOR_WORK_PER_1000[event] / PER_PERCENT
			return "rain %s a day, %s; boats stay at the jetty; outdoor work at %d%%" % [_rain(event), _degrees(event), work]
		WeatherCore.EVENT_DROUGHT:
			return "%s, no rain; the beds dry %d more a day; orchards want water" % [_degrees(event),
				WeatherCore.EVENT_EXTRA_EVAPORATION[event]]
		WeatherCore.EVENT_BLIGHT:
			return "crops lose %d health a day%s" % [WeatherCore.EVENT_CROP_DAMAGE_PER_DAY[event],
				"; the summer mussel harvest closes" if season == WeatherCore.SEASON_SUMMER else ""]
		WeatherCore.EVENT_EARLY_FROST:
			return "%s; frost on the beds" % _degrees(event)
		WeatherCore.EVENT_HARD_FREEZE:
			@warning_ignore("integer_division") var times: int = WeatherCore.EVENT_EXPOSURE_PER_1000[event] / PERMILLE
			return "%s; outdoor cold %d times as fast; no boat leaves, only the ice is open" % [_degrees(event), times]
		WeatherCore.EVENT_CALM_DAYS:
			return "no change: a safe interval"
		WeatherCore.EVENT_IDEAL_SPELL:
			@warning_ignore("integer_division") var growth: int = (WeatherCore.EVENT_CROP_GROWTH_PER_1000[event] - PERMILLE) / PER_PERCENT
			return "%s; crops grow %d%% faster; rain %s a day" % [_degrees(event, season), growth, _rain(event)]
	return ""


static func _degrees(event: int, season: int = -1) -> String:
	"""The event's temperature in words, from EVENT_TEMPERATURE_*: "30 °C" (absolute) or "3 °C colder" (heavy rain's
	delta from the baseline). The ideal spell's is its season's (§5.10: 2 °C in winter); both when the season is -1."""
	var tenths: int = WeatherCore.EVENT_TEMPERATURE_TENTHS[event]
	if WeatherCore.EVENT_TEMPERATURE_MODE[event] == WeatherCore.TEMPERATURE_DELTA:
		return "%s %s" % [_celsius(absi(tenths)), "colder" if tenths < 0 else "warmer"]
	if event != WeatherCore.EVENT_IDEAL_SPELL:
		return _celsius(tenths)
	var winter: String = _celsius(WeatherCore.IDEAL_SPELL_WINTER_TEMPERATURE_TENTHS)
	if season < 0:
		return "%s (%s in winter)" % [_celsius(tenths), winter]
	return winter if season == WeatherCore.SEASON_WINTER else _celsius(tenths)


static func _celsius(tenths: int) -> String:
	"""Whole degrees: "-12 °C"."""
	@warning_ignore("integer_division") var whole: int = tenths / TENTHS_PER_DEGREE
	return "%d °C" % whole


static func _rain(event: int) -> String:
	"""The event's rain a day, "+2000"."""
	return "+%d" % WeatherCore.EVENT_RAIN[event]


static func forecast_text(event: int, season: int, start_day: int, days: int) -> String:
	"""REQ-SET-142's disclosure: "Forecast: a storm from Spring 6 for 2 days — rain +2000 a day, ...". "" for none."""
	if not is_event(event):
		return ""
	return "Forecast: %s from %s for %d day%s — %s" % [name_of(event), CalendarScript.day_text(season, start_day), days,
		"" if days == 1 else "s", effects_text(event, season)]


static func began_text(event: int, season: int = -1) -> String:
	"""The notice on an event's first day in `season`: "A storm has come: rain +2000 a day, ...". "" for none."""
	return "%s: %s" % [BEGAN[event], effects_text(event, season)] if is_event(event) else ""


static func ended_text(event: int) -> String:
	"""The notice when an event is over: "The storm has passed". "" for none."""
	return ENDED[event] if is_event(event) else ""


func follow(event: int, notices: NoticesScript, season: int = -1) -> bool:
	"""Post the notice when today's event begins or ends (once each; see the header). True when one was posted."""
	if event == _following:
		return false
	var ended: int = _following
	_following = event
	if notices == null:
		return true
	if is_event(ended):
		notices.post(NoticesScript.SOURCE_WEATHER, NoticesScript.LEVEL_NOTE, ended_text(ended), ended_text(ended))
	if is_event(event):
		notices.post(NoticesScript.SOURCE_WEATHER, NoticesScript.LEVEL_NOTE, began_text(event, season), BEGAN[event])
	return true


func following() -> int:
	"""The event last followed (EVENT_NONE for none)."""
	return _following
