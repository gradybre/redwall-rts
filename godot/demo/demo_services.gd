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
##   incidents  demo_incidents.gd -- THE incidents: the unresolved, actionable conditions behind the
##              warnings (a waterlogged bed, a flooded tunnel, a rescue), kept until they resolve or the
##              player acknowledges them, and the sound hook (decision 0331).
##   news_clock demo_news_clock.gd -- the real time the news counts, stopped while the village is paused.
##   props      demo/props/demo_props.gd -- THE staged small props (items, finds, tunnel and water
##              gear, room furniture): each model's mesh loaded once and shared by every placement,
##              and the icons. demo_village.gd loads it from the manifest; a fresh set draws boxes.
##   stores     demo/tunnel/tunnel_stores.gd -- THE demo stores: wood, stone, planks and finds. The woods
##              (demo/forestry/) put their wood in and saw their planks from it; the tunnel works pay
##              bracing and lanterns from it. One wood stock for the demo.
##   work_pace  demo/work/work_pace.gd -- THE work pace: each owner's per-resident work factor (the
##              infirmary's health factor, decision 0622), composed by multiplying; work owners read it.
##
## A suite that builds a farm, tunnel works or woods without a village passes nothing and gets a fresh
## set of its own, so no module ever runs without one of the six.

const CalendarScript := preload("res://demo/demo_calendar.gd")
const WeatherScript := preload("res://demo/weather/demo_weather.gd")
const WaterScript := preload("res://demo/village_water.gd")
const WaterMapScript := preload("res://demo/water/water_map.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const IncidentsScript := preload("res://demo/demo_incidents.gd")
const NewsClockScript := preload("res://demo/demo_news_clock.gd")
const PropsScript := preload("res://demo/props/demo_props.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")
const WorkPaceScript := preload("res://demo/work/work_pace.gd")

var calendar: CalendarScript = CalendarScript.new()
var weather: WeatherScript = WeatherScript.new()
var water: WaterScript = null
var notices: NoticesScript = NoticesScript.new()
var incidents: IncidentsScript = IncidentsScript.new()
var news_clock: NewsClockScript = NewsClockScript.new()
var props: PropsScript = PropsScript.new()
var stores: StoresScript = StoresScript.new()
var work_pace: WorkPaceScript = WorkPaceScript.new()


func _init(water_map: WaterMapScript = null) -> void:
	"""The set over `water_map` (the village water node's; none: the village's authored water), with
	the notices and incidents stamped by the calendar's date and timed on the news clock."""
	water = WaterScript.new(water_map)
	notices.bind_calendar(calendar)
	notices.bind_clock(news_clock)
	incidents.bind(notices, calendar, news_clock)

