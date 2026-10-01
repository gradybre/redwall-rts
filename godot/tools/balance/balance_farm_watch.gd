extends RefCounted
## THE BALANCE HARNESS'S FARM WATCH (decision 0571): the beds and the weather, read once a farm hour. Measurement only.
##
## WEATHER per day: §5.10's event active at noon (weather.gd EVENT_*, by name), whether the demo's frost night or
## blight outbreak falls on the day (farm_weather.gd's fixed schedule), the air temperature the crops felt (min and the
## sum of the hourly readings, tenths: the frost night's figure on its hours) and the hours any bed stood waterlogged.
##
## AN HOUR CROSSING DAMAGES THE HOUR JUST ENDED (farm_sim.gd `run_hour` reads `calendar_at(tick - 1)`), so each reading
## is of the ELAPSED hour: the crossing into 06:00 charges 05:00, the last frost hour.
## LOSSES. A bed's health falling between two hours is charged to a cause: BLIGHT when the bed is or was blighted (a
## withered bed loses its blight mark in the same step that killed it, `_sync_blight`, so the stage before counts too),
## FROST when the elapsed hour was cold (a frost-night hour, or air at or below 0 °C), else OTHER (moisture out of its
## band, standing ripe). A crop that WITHERS is charged the same way, except one that stood RIPE the hour before
## (OVERRIPE: left past its grace). Health is 0..10000 as farming.gd keeps it; the figures are bed-health points, not food.
## SOWN and HARVESTED count beds leaving EMPTY for a crop, and RIPE beds emptied without withering.

const SimScript := preload("res://demo/farm/farm_sim.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const FarmWeather := preload("res://demo/farm/farm_weather.gd")
const WeatherScript := preload("res://scripts/core/weather.gd")
const HOURS_PER_DAY: int = 24

const CAUSES: Array[String] = ["blight", "frost", "other", "overripe"]
const CAUSE_BLIGHT: int = 0
const CAUSE_FROST: int = 1
const CAUSE_OTHER: int = 2
const CAUSE_OVERRIPE: int = 3

var _sim: SimScript = null
var _stage: PackedInt32Array = PackedInt32Array()
var _health: PackedInt32Array = PackedInt32Array()
var _health_loss: PackedInt64Array = PackedInt64Array()
var _withered: PackedInt32Array = PackedInt32Array()
var _sown: int = 0
var _harvested: int = 0
var _waterlogged_hours: int = 0
var _temp_sum: int = 0
var _temp_min: int = 0
var _hours: int = 0
var _event: String = ""


func bind(sim: SimScript) -> void:
	"""Watch `sim`'s beds from their state now."""
	_sim = sim
	_stage.resize(Catalog.BED_COUNT)
	_health.resize(Catalog.BED_COUNT)
	_health_loss.resize(CAUSES.size())
	_withered.resize(CAUSES.size())
	for bed: int in Catalog.BED_COUNT:
		_stage[bed] = sim.stage_of(bed)
		_health[bed] = sim.health_of(bed)
	reset_day()


static func event_name(event: int) -> String:
	"""§5.10's event by name ("" for none)."""
	var names: Dictionary = {WeatherScript.EVENT_BLIGHT: "blight", WeatherScript.EVENT_CALM_DAYS: "calm_days",
		WeatherScript.EVENT_DROUGHT: "drought", WeatherScript.EVENT_EARLY_FROST: "early_frost",
		WeatherScript.EVENT_HARD_FREEZE: "hard_freeze", WeatherScript.EVENT_HEAVY_RAIN: "heavy_rain",
		WeatherScript.EVENT_IDEAL_SPELL: "ideal_spell"}
	return String(names.get(event, ""))


static func elapsed_air(season: int, season_day: int, hour_reached: int, weather_tenths: int) -> int:
	"""The air the crops felt in the hour that ended when the calendar reached `hour_reached` (0-23): the weather's,
	or the frost night's on its hours. Frost hours never span midnight, so today's season and day name them."""
	var elapsed: int = (hour_reached + HOURS_PER_DAY - 1) % HOURS_PER_DAY
	return FarmWeather.air_tenths(weather_tenths, FarmWeather.is_frost_hour(season, season_day, elapsed))


static func cold_hour(season: int, season_day: int, hour_reached: int, weather_tenths: int) -> bool:
	"""Whether the hour that ended at `hour_reached` was cold: a frost-night hour, or air at or below 0 °C."""
	var elapsed: int = (hour_reached + HOURS_PER_DAY - 1) % HOURS_PER_DAY
	return FarmWeather.is_frost_hour(season, season_day, elapsed) \
		or elapsed_air(season, season_day, hour_reached, weather_tenths) <= 0


func hour(hour_of_day: int) -> void:
	"""One farm hour crossing (the calendar reached `hour_of_day`, 0-23): the elapsed hour's weather read, each bed's
	change charged."""
	var air: int = elapsed_air(_sim.season(), _sim.season_day(), hour_of_day, _sim.air_tenths())
	var cold: bool = cold_hour(_sim.season(), _sim.season_day(), hour_of_day, _sim.air_tenths())
	_temp_sum += air
	_temp_min = air if _hours == 0 else mini(_temp_min, air)
	_hours += 1
	if hour_of_day == 12:
		_event = event_name(_sim.active_event())
	for bed: int in Catalog.BED_COUNT:
		_bed_hour(bed, cold)


func _bed_hour(bed: int, cold: bool) -> void:
	"""Bed `bed`'s hour read from the farm and booked."""
	if _sim.band_of(bed) == SimScript.BAND_WATERLOGGED:
		_waterlogged_hours += 1
	book(bed, _sim.stage_of(bed), _sim.health_of(bed), _sim.is_blighted(bed), cold)


func book(bed: int, stage: int, health: int, blighted: bool, cold: bool) -> void:
	"""Bed `bed` now shows `stage` at `health`: a health fall and its cause, and a stage change (sown, harvested,
	withered) against what it showed at the last hour."""
	var was_blighted: bool = blighted or _stage[bed] == SimScript.STAGE_BLIGHTED
	var cause: int = CAUSE_BLIGHT if was_blighted else (CAUSE_FROST if cold else CAUSE_OTHER)
	if health < _health[bed] and stage != SimScript.STAGE_EMPTY and _stage[bed] != SimScript.STAGE_EMPTY:
		_health_loss[cause] += _health[bed] - health
	if stage != _stage[bed]:
		if stage == SimScript.STAGE_WITHERED:
			_withered[CAUSE_OVERRIPE if _stage[bed] == SimScript.STAGE_RIPE else cause] += 1
		elif _stage[bed] == SimScript.STAGE_EMPTY:
			_sown += 1
		elif _stage[bed] == SimScript.STAGE_RIPE and stage == SimScript.STAGE_EMPTY:
			_harvested += 1
	_stage[bed] = stage
	_health[bed] = health


func close_day(season: int, season_day: int) -> Dictionary:
	"""This day's weather and beds (`season` 0-3 and `season_day` 1-12 name it), then reset."""
	var loss: Dictionary = {}
	var withered: Dictionary = {}
	for c: int in CAUSES.size():
		loss[CAUSES[c]] = _health_loss[c]
		withered[CAUSES[c]] = _withered[c]
	var day: Dictionary = {
		"weather": {"event": _event, "frost_night": FarmWeather.is_frost_night(season, season_day),
			"blight_outbreak": FarmWeather.is_blight_outbreak(season, season_day), "air_tenths_min": _temp_min,
			"air_tenths_sum": _temp_sum, "hours": _hours, "waterlogged_bed_hours": _waterlogged_hours},
		"beds": {"sown": _sown, "harvested": _harvested, "withered": withered, "health_loss": loss,
			"growing_end": _growing()},
	}
	reset_day()
	return day


func _growing() -> int:
	"""Beds with a crop in them now (sown, growing, blighted or ripe)."""
	var n: int = 0
	for bed: int in Catalog.BED_COUNT:
		var stage: int = _sim.stage_of(bed)
		n += 1 if stage != SimScript.STAGE_EMPTY and stage != SimScript.STAGE_WITHERED else 0
	return n


func reset_day() -> void:
	"""Zero the day's tallies."""
	_health_loss.fill(0)
	_withered.fill(0)
	_sown = 0
	_harvested = 0
	_waterlogged_hours = 0
	_temp_sum = 0
	_temp_min = 0
	_hours = 0
	_event = ""
