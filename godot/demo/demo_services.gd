extends RefCounted
## What the whole live demo shares, made once by demo_village.gd and handed to the farm and the tunnel
## works. Decision 0196 (live demo). Presentation only.
##
##   calendar   demo_calendar.gd -- THE demo date: farm time, the weather's hour and the HUD's date.
##              The farm's model advances it (farm_sim.gd `share_calendar`); everyone else reads.
##   weather    demo/weather/demo_weather.gd -- THE weather: bound to the farm's real §5.10 row and to
##              the calendar, read by the walkers (via the tunnel planner), the tunnels' hazards, the
##              weather drawing and every panel.
##   water      village_water.gd -- THE water adapter: the farm's edge query and the tunnels' wet-ground,
##              flood and route queries, answered from the real water map (demo/water/water_map.gd).
##   notices    demo_notices.gd -- THE notice feed: every demo warning and report, date-stamped.
##
## A suite that builds a farm or tunnel works without a village passes nothing and gets a fresh set of
## its own, so no module ever runs without one of the four.

const CalendarScript := preload("res://demo/demo_calendar.gd")
const WeatherScript := preload("res://demo/weather/demo_weather.gd")
const WaterScript := preload("res://demo/village_water.gd")
const WaterMapScript := preload("res://demo/water/water_map.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")

var calendar: CalendarScript = CalendarScript.new()
var weather: WeatherScript = WeatherScript.new()
var water: WaterScript = null
var notices: NoticesScript = NoticesScript.new()


func _init(water_map: WaterMapScript = null) -> void:
	"""The set over `water_map` (the village water node's; none: the village's authored water), with
	the notices stamped by the calendar's date."""
	water = WaterScript.new(water_map)
	notices.bind_calendar(calendar)

