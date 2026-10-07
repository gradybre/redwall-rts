extends RefCounted
## THE STORM'S WORK FACTOR: GDD §5.10's heavy rain/storm "outdoor work×0.80", applied ONCE, through the village's one
## work pace. Decision 1632 (feature #34, livelier weather). Presentation only, integer per mille.
##
## WHY HERE. Before this, two crews slowed their own work on a storm day -- the woods (forest_crew.gd `step_usec`) and
## the bridge builders (bridge_crew.gd `_usec_per_wu`) -- and the farm, the spoil and every other crew did not. The work
## pace (demo/work/work_pace.gd) is where the GDD's work factors compose by multiplying (§5.2), and where each crew's
## credited work is already read (resident_brain.gd `work_credit`): so the storm is one more factor there, named
## "storm", and the two private copies are gone. A resident outdoors works at STORM_PERMILLE on a storm day; one inside a
## building or below ground (a tunnel, a cellar, a home) is sheltered and works at full pace.
##
## The day is the §5.10 event's (the farm's real row, read through demo_weather.gd `event`), not the hour's rain: the GDD
## states the factor for the event's days.
##
## FORAGING is the one exception left: its trips do not read the work pace yet (forage_trips.gd), so forage_rules.gd
## keeps its own storm factor until it does (a follow-up of decision 1632).

const WeatherScript := preload("res://demo/weather/demo_weather.gd")
const WeatherCore := preload("res://scripts/core/weather.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")

## The factor's name on the work pace ("work at 80% (storm 80%)").
const FACTOR_NAME: String = "storm"
const PERMILLE: int = 1000
## §5.10's heavy rain/storm "outdoor work×0.80", from the real table (never mirrored).
const STORM_PERMILLE: int = WeatherCore.EVENT_OUTDOOR_WORK_PER_1000[WeatherCore.EVENT_HEAVY_RAIN]

var _weather: WeatherScript = null
var _brains: Array[BrainScript] = []


func bind(weather: WeatherScript, brains: Array[BrainScript]) -> void:
	"""The weather whose storm days slow the work, and the residents (by index) whose places say who is outdoors."""
	_weather = weather
	_brains = brains


func is_storm_day() -> bool:
	"""Whether today is a §5.10 heavy rain/storm day."""
	return _weather != null and _weather.event() == WeatherCore.EVENT_HEAVY_RAIN


func is_outdoors(who: int) -> bool:
	"""Whether resident `who` is out in the weather: not inside a building, not below ground (false out of range)."""
	if who < 0 or who >= _brains.size():
		return false
	var b: BrainScript = _brains[who]
	return not b.indoors and not b.underground


func permille(who: int) -> int:
	"""THE FACTOR (work_pace.gd `add_factor`): STORM_PERMILLE for a resident outdoors on a storm day, else PERMILLE."""
	return STORM_PERMILLE if is_storm_day() and is_outdoors(who) else PERMILLE
