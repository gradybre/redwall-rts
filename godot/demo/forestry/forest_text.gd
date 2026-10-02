extends RefCounted
## What the Woods panel and the notices say. Decision 0196 (live demo). Presentation only: words
## built from the stand, the zones, the deadfall, the board and the demo stores, never a decision.
## Called a few times a second for the panel (strings allocate; never per frame), and once per event
## for a notice.

const Rules := preload("res://demo/forestry/forest_rules.gd")
const StandScript := preload("res://demo/forestry/forest_stand.gd")
const ZonesScript := preload("res://demo/forestry/forest_zones.gd")
const DeadfallScript := preload("res://demo/forestry/forest_deadfall.gd")
const CrewScript := preload("res://demo/forestry/forest_crew.gd")
const JobsScript := preload("res://demo/forestry/forest_jobs.gd")
const PanelScript := preload("res://demo/forestry/forest_panel.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const WeatherCore := preload("res://scripts/core/weather.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

const QUEUE_LINES: int = 5
const LOG_LINES: int = 3
const ANSWER_MSEC: int = 12000

var _stand: StandScript = null
var _zones: ZonesScript = null
var _deadfall: DeadfallScript = null
var _crew: CrewScript = null
var _services: ServicesScript = null
var _counts: PackedInt32Array = PackedInt32Array()
var _enabled_zone: Dictionary = {}
var _read: IntMath.IntResult = IntMath.IntResult.new()
## The latest answer to an order, shown under the queue for ANSWER_MSEC of real time.
var _answer: String = ""
var _answer_msec: int = 0


func configure(stand: StandScript, zones: ZonesScript, deadfall: DeadfallScript, crew: CrewScript,
		services: ServicesScript) -> void:
	"""Speak for these woods."""
	_stand = stand
	_zones = zones
	_deadfall = deadfall
	_crew = crew
	_services = services


func remember(answer: String) -> void:
	"""Keep an order's answer for the panel's log (for ANSWER_MSEC of real time)."""
	_answer = answer
	_answer_msec = Time.get_ticks_msec()


func stores_line() -> String:
	"""The village stores' wood and planks, the figures the top bar shows: "Village stores: wood 40.0 U · planks
	2.0 U" (decision 0251: no line explains whose stock it is -- there is one)."""
	var stores := _services.stores
	return "Village stores: wood %s · planks %s" % [Rules.units_text(stores.wood_milli_u),
		Rules.units_text(stores.plank_milli_u)]


func counts_line() -> String:
	"""The woods in numbers, three short lines: standing, felled, lying."""
	_stand.counts_into(_counts)
	return "Standing: %d mature · %d young\nFelled: %s · %d cleared · trunks %s\nDeadfall: %s, %s" % [
		_counts[StandScript.STATE_MATURE], _counts[StandScript.STATE_YOUNG],
		counted(_counts[StandScript.STATE_STUMP], "stump"), _counts[StandScript.STATE_CLEARED],
		Rules.units_text(_counts[4]), counted(_deadfall.live_count(), "pile"), Rules.units_text(_deadfall.total_milli())]


static func counted(n: int, noun: String) -> String:
	"""e.g. "1 stump", "3 stumps"."""
	return "%d %s%s" % [n, noun, "" if n == 1 else "s"]


func season_line() -> String:
	"""What the season and the weather do to the work."""
	var season: int = _services.calendar.now().season
	var line: String = "%s: " % CalendarScript.SEASON_TITLES[season]
	if season == WeatherCore.SEASON_WINTER:
		@warning_ignore("integer_division") line += "no sap — felling takes %d%% of the time" % (Rules.WINTER_WORK_PERMILLE / 10)
	else:
		line += "sap running (felling is quicker in winter)"
	if _services.weather.event() == WeatherCore.EVENT_HEAVY_RAIN:
		@warning_ignore("integer_division") line += "\nStorm: outdoor work at %d%% (GDD §5.10); trees may blow down" % (Rules.STORM_WORK_PERMILLE / 10)
	return line


func queue_text() -> String:
	"""The job board, oldest first (at most QUEUE_LINES, then "+ n more")."""
	var lines := PackedStringArray()
	var more: int = 0
	for row: int in JobsScript.MAX_JOBS:
		if not _crew.jobs.is_live(row):
			continue
		if lines.size() < QUEUE_LINES:
			lines.append("• " + _crew.job_line(row))
		else:
			more += 1
	if lines.is_empty():
		return "Jobs: none"
	if more > 0:
		lines.append("+ %d more" % more)
	return "Jobs:\n" + "\n".join(lines)


func log_text() -> String:
	"""The last order's answer and the woods' latest news from the one feed."""
	var lines := PackedStringArray()
	if not _answer.is_empty() and Time.get_ticks_msec() - _answer_msec < ANSWER_MSEC:
		lines.append(_answer)
	_services.notices.latest_of_into(NoticesScript.SOURCE_WOODS, LOG_LINES, lines)
	return "\n".join(lines)


func tree_title(t: int, day: int) -> String:
	"""The selected tree's heading ("" for none): what it is and how far it has come."""
	if not _stand.is_tree(t):
		return ""
	var label: String = _stand.label_of(t)
	match _stand.state_of(t):
		StandScript.STATE_MATURE:
			return "%s — mature, %s" % [label, Rules.units_text(_stand.wood_milli_of(t))]
		StandScript.STATE_STUMP:
			return "%s — regrowing, %d days left" % [label, _stand.days_left(t, day)]
		StandScript.STATE_YOUNG:
			return "%s — growing, %d days to maturity" % [label, _stand.days_left(t, day)]
	return "%s — plant a sapling (compost 0.25 U, 4 WU)" % label


func tree_text(t: int) -> String:
	"""The selected tree's zone and floor, and its trunk if one lies there."""
	if not _stand.is_tree(t):
		return ""
	var line: String = "Outside any zone: fell freely"
	if _zones.zone_at_tile_into(_stand.tile[t], _read):
		var z: int = _read.value
		line = "%s (%s): %s" % [_zones.names[z], _zones.kind_name(z), _zones.floor_text(_stand, z)]
	if _stand.trunk_milli[t] > 0:
		line += "\nTrunk lying: %s to haul" % Rules.units_text(_stand.trunk_milli[t])
	var fell_code: String = _crew.refusal_for(JobsScript.KIND_FELL, t, 0)
	if _stand.state_of(t) == StandScript.STATE_MATURE and not fell_code.is_empty():
		line += "\nCan't fell: " + _crew.reason_text(fell_code, t)
	return line


func zone_title(z: int) -> String:
	"""The selected zone's heading ("" for none)."""
	if not _zones.is_zone(z):
		return ""
	return "%s — %s zone" % [_zones.names[z], _zones.kind_name(z)]


func zone_text(z: int) -> String:
	"""The selected zone's trees and its rule."""
	if not _zones.is_zone(z):
		return ""
	if _zones.kind[z] == ZonesScript.KIND_CONSERVATION:
		return "%s. Deadfall may be gathered here." % _zones.floor_text(_stand, z)
	var auto_words: String = "the forestry crew fells it down to its floor" if _zones.auto_fell[z] == 1 else "felled only by order"
	return "%s; %s." % [_zones.floor_text(_stand, z), auto_words]


func zone_actions(z: int) -> Dictionary:
	"""Which of the zone's settings apply: intensive and auto-fell on forestry zones; unmark on any."""
	var forestry: bool = _zones.is_zone(z) and _zones.kind[z] == ZonesScript.KIND_FORESTRY
	_enabled_zone[PanelScript.ACTION_INTENSIVE] = forestry
	_enabled_zone[PanelScript.ACTION_AUTO] = forestry
	_enabled_zone[PanelScript.ACTION_REMOVE_ZONE] = _zones.is_zone(z)
	return _enabled_zone


func matured_line(trees: PackedInt32Array) -> String:
	"""A midnight's regrowth: "A young tree has grown to maturity: an oak in the North stand", or
	"3 trees have grown to maturity: …"."""
	if trees.size() == 1:
		return "A young tree has grown to maturity: %s" % where_tree(trees[0])
	return "%d trees have grown to maturity: their 48 days are up" % trees.size()


func where_tree(t: int) -> String:
	"""A tree and its place: "an oak in the North stand"."""
	var what: String = "a %s" % StandScript.LOOK_NAMES[_stand.look[t]].to_lower()
	if what.begins_with("a o"):
		what = "an " + what.substr(2)
	if _zones.zone_at_tile_into(_stand.tile[t], _read):
		return "%s in the %s" % [what, _zones.names[_read.value]]
	return "%s at the woods' edge" % what
