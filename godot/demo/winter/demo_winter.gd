extends Node
## THE WINTER: heating fuel, cold rooms, Chilled residents and the firewood that answers them, in the live demo.
## Decision 0571 (Brendan's rulings of 2026-10-01). Presentation only: the settlement simulation is never written.
##
## EACH GAME HOUR the one calendar crosses -- in order, however many a frame brings (`catch_up`) -- the hearths take
## their wood and the rooms warm or cool (hearth_fuel.gd), on that hour's season, the day's mean temperature and the
## hour's air, read from the farm's real §5.10 row (the event active that day) and its demo frost nights. Then the
## kitchen's cooking is noted for the fuel-days, the fuel's incidents are kept, the Firewood order is kept on the woods'
## board, and the season's notes are posted.
##
## EACH FRAME every resident's place is read -- outdoors (or in the water), in the hall, in a home (its room's void), or
## below in a tunnel -- and its exposure integrated over the calendar ticks the frame brought (cold_exposure.gd), at the
## rate its place gives (winter_rules.gd ENV_*). A jump of more than an hour in one frame (a skip: the Lab's "Skip to
## next season", "Next weather") is NOT integrated -- the residents did not live it. A Chilled resident works at the
## Chilled rate (resident_brain.gd `work_permille`) and is sent, when it may be (not asleep, not in the water or an
## emergency), for a WARM-UP BREAK (warm_up_task.gd) at the nearest heated hearth: its own bed's home first, else the
## nearest heated home, else the hall. With none heated it keeps working, slowly.
##
## THE NOTICES (village news, place Village): an incident while hearths are OUT OF FUEL; one per COLD HOME (a hearth's
## room with sleepers below freezing, not heated); REQ-SET-147's FUEL WARNING (under 2 fuel-days while the three-day
## forecast is below 0 °C, with the last heated hour and the homes); a warning when a resident becomes CHILLED (Go to
## selects it) and a note when it is warmed through; REQ-SET-114's twelve-day projection at autumn's first hour; and
## REQ-SET-149's preparation summary, a pinned card dismissed by the player, at the first winter's first hour.
##
## THE FIREWOOD ORDER (decisions 0571 and 0411): while the stores hold less wood than the twelve-day winter projection
## -- in autumn and winter, or on any day heat is demanded -- one Firewood order stands on the woods' board
## (forest_crew.gd `raise_firewood`: deadfall first, else a fell in a forestry zone), listed under the Woods activity, and
## marked URGENT on the work board (its bucket 2, systems_architecture.md's food/fuel bucket) while fuel-days are under 2
## -- REQ-SET-131's urgent refuel job when a hearth is out. It is a BUILT-IN STANDING ORDER (decision 0711): the
## standing orders' book (demo/orders/standing_orders.gd) holds it, with the winter's rule as its goal
## (goal_firewood.gd), and the winter keeps it on its own hour exactly as before; the player may switch it off.
##
## THE EMERGENCY ACTIONS (GDD §5.10, "consolidate residents into heated halls"; never taken by themselves): `consolidate`
## -- beds allocated warm first now and the sleepers sent to them, and the hearths of homes nobody sleeps in let go out
## -- and `set_banked` (let one hearth go out, or light it again). The fuel panel (fuel_panel.gd) offers them.

const Rules := preload("res://demo/winter/winter_rules.gd")
const FuelScript := preload("res://demo/winter/hearth_fuel.gd")
const ColdScript := preload("res://demo/winter/cold_exposure.gd")
const WarmUpScript := preload("res://demo/winter/warm_up_task.gd")
const Text := preload("res://demo/winter/winter_text.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const IncidentsScript := preload("res://demo/demo_incidents.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const UnfinishedScript := preload("res://demo/cast/unfinished_job.gd")
const NightScript := preload("res://demo/burrow/night_routine.gd")
const SleepTaskScript := preload("res://demo/burrow/sleep_task.gd")
const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")
const FixturesScript := preload("res://demo/burrow/room_fixtures.gd")
const AllocationScript := preload("res://demo/burrow/bed_allocation.gd")
const PathsScript := preload("res://demo/tunnel/graph_paths.gd")
const TunnelRules := preload("res://demo/tunnel/tunnel_rules.gd")
const Roster := preload("res://demo/ui/demo_roster.gd")
const FarmWeather := preload("res://demo/farm/farm_weather.gd")
const WeatherScript := preload("res://scripts/core/weather.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const WorkIds := preload("res://demo/work/work_ids.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const KitchenScript := preload("res://demo/kitchen/kitchen.gd")
const ForestCrewScript := preload("res://demo/forestry/forest_crew.gd")
const BoardScript := preload("res://demo/work/work_board.gd")
const CrewsScript := preload("res://demo/work/work_crews.gd")
const SkipScript := preload("res://demo/winter/season_skip.gd")
const OrdersScript := preload("res://demo/orders/standing_orders.gd")
const FirewoodGoal := preload("res://demo/orders/goal_firewood.gd")

## A frame bringing more calendar than this was not lived (see EACH FRAME).
const MAX_LIVED_TICKS: int = Rules.TICKS_PER_HOUR
## A Chilled resident is sent for its break at most this often (calendar ticks: the night's RESEND_TICKS).
const RESEND_TICKS: int = NightScript.RESEND_TICKS
## A warm-up break is only sent to a fire the stores can keep lit this long (game hours): the time to clear a Chilled
## resident's 4 exposure-hours at 2 an hour (CHILLED_AT_MILLI over CLEAR_MILLI_PER_HOUR; test_demo_winter.gd pins it).
const WARM_UP_HOURS: int = 2
## The share of the way from a home's middle to its hearth a warming resident stands at (per mille).
const FIRE_SIDE_PERMILLE: int = 600
const KEY_OUT: String = "winter:out_of_fuel"
const KEY_LOW: String = "winter:fuel_low"
const KEY_COLD: String = "winter:cold_home:%d"
const KEY_SUMMARY: String = "winter:prepared"
## The hour of a season's first day its notes are posted: the village's dawn (night_routine.gd DAWN_HOUR), the hour the
## demo opens and a season skip lands on.
const NOTE_HOUR: int = NightScript.DAWN_HOUR

var fuel: FuelScript = FuelScript.new()
var cold: ColdScript = ColdScript.new()
## Bumped whenever anything the panels show changed (an hour passed, a choice made, someone Chilled or warmed).
var revision: int = 0
## Warm-up breaks sent so far (a metric).
var breaks_sent: int = 0

var _services: ServicesScript = null
var _cast: DemoCastScript = null
var _graph: GraphScript = null
var _night: NightScript = null
var _row: WeatherScript = null
var _kitchen: KitchenScript = null
var _crew: ForestCrewScript = null
var _board: BoardScript = null
var _brains: Array[BrainScript] = []
var _names: PackedStringArray = PackedStringArray()
var _hall_door: Vector2 = Vector2.INF
var _hour_seen: int = -1
var _last_tick: int = 0
var _hard_freeze: bool = false
var _sent_tick: PackedInt32Array = PackedInt32Array()
var _entered: PackedInt32Array = PackedInt32Array()
var _warmed: PackedInt32Array = PackedInt32Array()
var _out: PackedInt32Array = PackedInt32Array()
var _cold_on: PackedByteArray = PackedByteArray()
var _low_on: bool = false
var _out_on: bool = false
## The standing orders' book holding the Firewood order (decision 0711), and its row there (-1: none).
var _orders: OrdersScript = null
var _firewood_order: int = -1
var _summary_day: int = -1
var _summary_resolved: bool = false
## A season skip is running: its hours are not cooked in, so they are not counted as cooking days (`rebase_cooking`).
var _skipping: bool = false
var _read: IntMath.IntResult = IntMath.IntResult.new()
## Consolidation's homes to keep, a byte per room row (see `consolidate`), and the preview's scratch.
var _keep: PackedByteArray = PackedByteArray()
var _preview: PackedByteArray = PackedByteArray()


func configure(services: ServicesScript, cast: DemoCastScript, graph: GraphScript, night: NightScript,
		weather_row: WeatherScript) -> void:
	"""The winter over this village: its shared services, its cast, its network (rooms and fit-out), its night and the
	farm's real §5.10 row. The hall has a hearth; the first frame passes the current hour."""
	name = "Winter"
	_services = services
	_cast = cast
	_graph = graph
	_night = night
	_row = weather_row
	fuel.bind_stores(services.stores)
	fuel.set_hearth(FuelScript.HALL, true)
	for i: int in cast.actor_count():
		var actor := cast.actor(i) as DemoActorScript
		_brains.append(actor.brain)
		_names.append(actor.display_name)
	cold.configure(_brains.size())
	_sent_tick.resize(_brains.size())
	_sent_tick.fill(-RESEND_TICKS)
	_cold_on.resize(FuelScript.SOURCES)
	_keep.resize(FuelScript.ROOMS)
	_preview.resize(FuelScript.ROOMS)
	_bind_homes()
	_hour_seen = services.calendar.hour_index() - 1
	_last_tick = services.calendar.tick


func _bind_homes() -> void:
	"""The night's warm beds and the hearth's glow, the fit-out's comfort, and the hall's door (see the header)."""
	_night.set_warmth(fuel.is_warm, fuel.hearth_lit, hearth_words)
	_graph.fit.hearth_cold = fuel.hearth_cold
	var hall: int = _cast.space().poi_names.find(NightScript.HALL_POI)
	if hall >= 0:
		_hall_door = _cast.space().poi_position[hall]


func bind_kitchen(kitchen: KitchenScript) -> void:
	"""The kitchen whose cooking wood the fuel-days count (kitchen.gd `consumed_wood_milli`)."""
	_kitchen = kitchen


func bind_work(crew: ForestCrewScript, board: BoardScript, orders: OrdersScript = null) -> void:
	"""The woods' crew the Firewood order goes to (forest_crew.gd), the work board that marks it urgent (null: none),
	and the standing orders' book it is a built-in order of (null: a book of its own)."""
	_crew = crew
	_board = board
	_orders = orders
	if _orders == null:
		_orders = OrdersScript.new()
		_orders.bind_board(board)
	var goal := FirewoodGoal.new(crew, _services.stores, firewood_wanted, firewood_urgent, fuel.projection_milli)
	_firewood_order = _orders.add_builtin(goal)
	if _firewood_order < 0:
		push_error("the standing orders' book is full: the winter has no Firewood order")


func firewood_order() -> int:
	"""The Firewood's row in the standing orders' book (-1: none)."""
	return _firewood_order


func _process(_delta: float) -> void:
	"""Each frame: the hours crossed, then everyone's exposure and the warm-up breaks (see the header)."""
	if _services == null:
		return
	catch_up()
	follow_exposure()
	send_warm_ups()


# --- each hour ----------------------------------------------------------------------------------------

func catch_up() -> int:
	"""Pass every game hour the calendar has crossed since the last call, in order. How many."""
	var hours: int = 0
	while _hour_seen < _services.calendar.hour_index():
		_hour_seen += 1
		_on_hour(_hour_seen)
		hours += 1
	return hours


func _on_hour(h: int) -> void:
	"""One game hour (see EACH GAME HOUR)."""
	_refresh_hearths()
	var season: int = Rules.hour_season(h)
	var day: int = Rules.hour_season_day(h)
	var event: int = _row.active_event_on(Rules.hour_absolute_season(h), day) if _row != null else WeatherScript.EVENT_NONE
	var day_tenths: int = _day_tenths(season, event)
	var mean: int = day_mean_tenths(day_tenths, season, day)
	_hard_freeze = Rules.is_hard_freeze(event)
	var air: int = FarmWeather.air_tenths(day_tenths, FarmWeather.is_frost_hour(season, day, Rules.hour_of_day(h)))
	if _kitchen != null and not _skipping:
		fuel.note_cooking(_kitchen.consumed_wood_milli, Rules.day_of_hour(h))
	fuel.pass_hour(h, season, mean, air)
	_keep_incidents(h)
	_keep_firewood()
	_seasonal_notes(h)
	revision += 1


static func day_mean_tenths(day_tenths: int, season: int, day: int) -> int:
	"""THE DAY'S MEAN (§5.8's "daily mean"): the mean of its 24 hours' air -- the §5.10 day temperature, pulled down in a
	demo frost night's hours (farm_weather.gd) -- floored. A spring day at 12 °C with a frost night means 9.5 °C, so a
	frost night's day demands heat (review H1: a frost night chilled the hall's sleepers in a season of no demand)."""
	var total: int = 0
	for hour: int in Rules.HOURS_PER_DAY:
		total += FarmWeather.air_tenths(day_tenths, FarmWeather.is_frost_hour(season, day, hour))
	return Rules.floor_div(total, Rules.HOURS_PER_DAY)


func _day_tenths(season: int, event: int) -> int:
	"""A day's §5.10 temperature for its season and active event (the baseline when the row refuses)."""
	if _row != null and _row.temperature_tenths_for_into(season, event, _read):
		return _read.value
	return WeatherScript.SEASON_TEMPERATURE_TENTHS[season]


func _refresh_hearths() -> void:
	"""Which homes have a hearth installed: a dug burrow home's fit-out hearth (the hall's is always set)."""
	var rooms: RoomsScript = _graph.rooms
	for r: int in FuelScript.ROOMS:
		var home: bool = rooms.is_done(_graph, r) and rooms.template[r] == RoomsScript.TEMPLATE_HOME
		fuel.set_hearth(r, home and _graph.fit.has_hearth(_graph, r))


func forecast_min_tenths(h: int) -> int:
	"""REQ-SET-147's forecast: the coldest of today's mean and the next two days' -- each the season's baseline unless a
	disclosed §5.10 event (REQ-SET-142) covers it -- and the demo's announced frost nights."""
	var coldest: int = fuel.day_mean_tenths
	for d: int in range(0, 3):
		var at: int = h + d * Rules.HOURS_PER_DAY
		var season: int = Rules.hour_season(at)
		var day: int = Rules.hour_season_day(at)
		coldest = mini(coldest, _day_tenths(season, _forecast_event(Rules.hour_absolute_season(at), day)))
		if FarmWeather.is_frost_night(season, day):
			coldest = mini(coldest, FarmWeather.FROST_NIGHT_TENTHS)
	return coldest


func _forecast_event(absolute_season: int, day: int) -> int:
	"""The disclosed event covering a day (REQ-SET-142's forecast), or none."""
	if _row == null or not _row.is_forecast_disclosed() or _row.forecast_absolute_season() != absolute_season:
		return WeatherScript.EVENT_NONE
	var first: int = _row.forecast_start_day()
	if day < first or day >= first + _row.forecast_duration_days():
		return WeatherScript.EVENT_NONE
	return _row.forecast_event()


# --- the notices --------------------------------------------------------------------------------------

func _keep_incidents(h: int) -> void:
	"""Out of fuel, the low-fuel warning and the cold homes (see THE NOTICES)."""
	var out_now: bool = fuel.out_count() > 0
	if out_now and not _out_on:
		_out.clear()
		for s: int in FuelScript.SOURCES:
			if fuel.is_out(s):
				_out.append(s)
		_report(KEY_OUT, Text.out_line(_out, fuel.air_tenths), _out_state)
	_out_on = out_now
	var low_now: bool = low_fuel(h)
	if low_now and not _low_on:
		_report(KEY_LOW, Text.warning_line(fuel, burning_sources()), _low_state)
	_low_on = low_now
	for s: int in FuelScript.SOURCES:
		_keep_cold_home(s)


func low_fuel(h: int) -> bool:
	"""REQ-SET-147's condition: fuel-days under 2 while the forecast is below freezing."""
	var days: int = fuel.fuel_days_hundredths()
	return Text.is_warning(days) and forecast_min_tenths(h) < Rules.FREEZING_TENTHS


func _keep_cold_home(s: int) -> void:
	"""A hearth's room with sleepers, below freezing and not heated while heat is demanded, is a cold home (once, until
	it warms). A home without a hearth, or a day of no demand, is not one: wood would not help there."""
	var cold_now: bool = fuel.hearth[s] == 1 and fuel.demanded() and has_sleepers(s) and not fuel.is_heated(s) \
		and fuel.temperature_of(s) < Rules.FREEZING_TENTHS
	if cold_now and _cold_on[s] == 0:
		_report(KEY_COLD % s, Text.cold_home_line(s, fuel.temperature_of(s)), _cold_state.bind(s))
	_cold_on[s] = 1 if cold_now else 0


func has_sleepers(s: int) -> bool:
	"""Whether anyone's bed is in home `s` (the hall: anyone without a bed)."""
	if s == FuelScript.HALL:
		return _night.first_bedless() >= 0
	return not _night.sleepers_of(s).is_empty()


func _report(key: String, text: String, watch: Callable) -> void:
	"""A Village warning incident, its state from `watch`."""
	if _services.incidents != null:
		_services.incidents.report(key, NoticesScript.SOURCE_VILLAGE, IncidentsScript.SEVERITY_WARNING, text, "",
			NoticesScript.TARGET_NONE, -1, watch)


func _out_state() -> int:
	"""The out-of-fuel incident: resolved once no hearth is out."""
	return IncidentsScript.STATE_RESOLVED if fuel.out_count() == 0 else IncidentsScript.STATE_NEEDS_DECISION


func _low_state() -> int:
	"""The fuel warning: resolved once the condition clears; assigned while the Firewood order is taken."""
	if not low_fuel(fuel.hour_index):
		return IncidentsScript.STATE_RESOLVED
	return IncidentsScript.STATE_ASSIGNED if firewood_taken() else IncidentsScript.STATE_NEEDS_DECISION


func _cold_state(s: int) -> int:
	"""A cold home: resolved once it is heated or above freezing."""
	var cold_now: bool = not fuel.is_heated(s) and fuel.temperature_of(s) < Rules.FREEZING_TENTHS
	return IncidentsScript.STATE_NEEDS_DECISION if cold_now else IncidentsScript.STATE_RESOLVED


func _seasonal_notes(h: int) -> void:
	"""REQ-SET-114 at autumn's first dawn; REQ-SET-149 at the first winter's (NOTE_HOUR); the summary resolved a day
	later (a pinned card stays until the player dismisses it)."""
	if _summary_day >= 0 and not _summary_resolved and Rules.day_of_hour(h) > _summary_day:
		_summary_resolved = true
		if _services.incidents != null:
			_services.incidents.resolve(KEY_SUMMARY)
	if Rules.hour_of_day(h) != NOTE_HOUR or Rules.hour_season_day(h) != 1:
		return
	var season: int = Rules.hour_season(h)
	if season == WeatherScript.SEASON_AUTUMN:
		_services.notices.post(NoticesScript.SOURCE_VILLAGE, NoticesScript.LEVEL_NOTE,
			"Winter is next. %s" % Text.projection_line(fuel), "Winter is next: %s of wood wanted" % Text.units(
			fuel.projection_milli()))
	elif season == WeatherScript.SEASON_WINTER and _summary_day < 0:
		_summary_day = Rules.day_of_hour(h)
		post_summary()


func post_summary() -> void:
	"""REQ-SET-149: the preparation summary, a pinned card the player dismisses (see THE NOTICES)."""
	if _services.incidents == null:
		return
	var food: String = _kitchen.days_text() if _kitchen != null else "unknown"
	var text: String = Text.summary_line(food, fuel, _night.warm_beds(), beds_count(), outdoors_count(), _brains.size())
	_services.incidents.report(KEY_SUMMARY, NoticesScript.SOURCE_VILLAGE, IncidentsScript.SEVERITY_ROUTINE, text,
		"Winter has come: the village's preparation")
	var serial: int = _services.incidents.serial_of(KEY_SUMMARY)
	if serial != IncidentsScript.NO_SERIAL:
		_services.incidents.pin(serial, true)


func beds_count() -> int:
	"""Residents with a bed."""
	var n: int = 0
	for bed: int in _night.bed_of:
		n += 1 if bed != AllocationScript.NO_BED else 0
	return n


func outdoors_count() -> int:
	"""REQ-SET-149's outdoor staffing: residents on a crew whose work is above ground -- every crew but the Diggers
	(work_crews.gd); with no work board, everyone."""
	if _board == null:
		return _brains.size()
	var n: int = 0
	for i: int in _brains.size():
		n += 1 if i < _board.crews.crew_of.size() and _board.crews.crew_of[i] != CrewsScript.CREW_DIGGERS else 0
	return n


# --- the Firewood order ------------------------------------------------------------------------------

func firewood_wanted() -> bool:
	"""Whether a Firewood order should stand (see THE FIREWOOD ORDER)."""
	var target: int = fuel.projection_milli()
	if target <= 0:
		return false
	var cold_season: bool = fuel.season == WeatherScript.SEASON_AUTUMN or fuel.season == WeatherScript.SEASON_WINTER
	return (fuel.demanded() or cold_season) and fuel.wood_milli() < target


func firewood_urgent() -> bool:
	"""Whether the Firewood order is urgent: fuel-days under 2 (a hearth out of fuel is 0)."""
	return Text.is_warning(fuel.fuel_days_hundredths()) or fuel.out_count() > 0


func firewood_row() -> int:
	"""The Firewood order's row on the woods' board, or -1."""
	return _crew.firewood_row() if _crew != null else -1


func firewood_taken() -> bool:
	"""Whether a resident is on the Firewood order."""
	var row: int = firewood_row()
	return row >= 0 and _crew.jobs.worker[row] >= 0


func _keep_firewood() -> void:
	"""One Firewood order while wood is wanted; urgent under 2 fuel-days (see THE FIREWOOD ORDER): the book keeps its
	built-in order on the winter's hour (standing_orders.gd `keep`)."""
	if _crew != null and _orders != null:
		_orders.keep(_firewood_order)


# --- each frame: exposure -----------------------------------------------------------------------------

func follow_exposure() -> void:
	"""Integrate everyone's exposure over the ticks this frame brought (see EACH FRAME); Chilled sets the work rate."""
	var tick: int = _services.calendar.tick
	var ticks: int = tick - _last_tick
	_last_tick = tick
	if ticks <= 0 or ticks > MAX_LIVED_TICKS:
		return
	for i: int in _brains.size():
		_note_place(i)
		cold.integrate(i, Rules.exposure_rate(cold.env[i], _hard_freeze), ticks)
		_brains[i].work_permille = cold.work_permille(i)
	if not cold.entered.is_empty() or not cold.warmed.is_empty():
		_say_changes()


func skip_lived_time() -> void:
	"""After a skip: the jump is not lived (see EACH FRAME)."""
	_last_tick = _services.calendar.tick


func _note_place(i: int) -> void:
	"""Where resident `i` is now, its environment and the temperature there (cold_exposure.gd WHY)."""
	var b: BrainScript = _brains[i]
	var source: int = ColdScript.OUTDOORS
	if b.indoors:
		source = FuelScript.HALL
	elif b.underground and not b.in_water:
		source = home_at(b)
	if source == ColdScript.OUTDOORS:
		cold.note_place(i, Rules.env_for(false, fuel.air_tenths), source, fuel.air_tenths)
	elif source == ColdScript.BELOW:
		cold.note_place(i, Rules.ENV_NEUTRAL, source, fuel.air_tenths)
	else:
		cold.note_place(i, Rules.env_for(fuel.is_heated(source), fuel.temperature_of(source)), source,
			fuel.temperature_of(source))


func home_at(b: BrainScript) -> int:
	"""The dug home whose void a resident below stands in, or ColdScript.BELOW (a tunnel, a cellar)."""
	var rooms: RoomsScript = _graph.rooms
	var at := Vector2i(TunnelRules.to_u(b.position.x), TunnelRules.to_u(b.position.y))
	var level: int = Roster.level_at_depth_u(TunnelRules.to_u(-b.ground_y_m))
	for r: int in FuelScript.ROOMS:
		if rooms.template[r] != RoomsScript.TEMPLATE_HOME or not rooms.is_done(_graph, r) or rooms.level[r] != level:
			continue
		if rooms.gap_of(r, at) <= 0:
			return r
	return ColdScript.BELOW


func _say_changes() -> void:
	"""Who became Chilled (a warning, Go to selects them) and who warmed through (a note)."""
	cold.take_changes_into(_entered, _warmed)
	for i: int in _entered:
		_services.notices.post(NoticesScript.SOURCE_VILLAGE, NoticesScript.LEVEL_WARNING,
			Text.chilled_line(_names[i], cold, i), "%s is Chilled" % _names[i], NoticesScript.TARGET_RESIDENT, i)
	for i: int in _warmed:
		_services.notices.post(NoticesScript.SOURCE_VILLAGE, NoticesScript.LEVEL_NOTE, Text.warmed_line(_names[i]), "",
			NoticesScript.TARGET_RESIDENT, i)
	revision += 1


# --- each frame: warm-up breaks -----------------------------------------------------------------------

func send_warm_ups() -> void:
	"""Send each Chilled resident that may go for its warm-up break, at most every RESEND_TICKS (see EACH FRAME)."""
	var tick: int = _services.calendar.tick
	for i: int in _brains.size():
		if not cold.is_chilled(i) or tick - _sent_tick[i] < RESEND_TICKS or not may_break(i):
			continue
		_sent_tick[i] = tick
		var source: int = warm_place_for(i)
		if source != ColdScript.OUTDOORS:
			send_warm_up(i, source)


func may_break(i: int) -> bool:
	"""Whether Chilled resident `i` may be sent now: awake, free to be called (the night's own test), not warming, and
	not carrying a load (a load in hand is carried on to its store first: decision 0222's rule -- the Firewood's own
	gatherer delivers before it warms up)."""
	var b: BrainScript = _brains[i]
	if b.resting or b.carrying or b.task is WarmUpScript or b.task is SleepTaskScript:
		return false
	return _night.may_send(i)


func warm_enough(source: int) -> bool:
	"""Whether `source` is a place for a warm-up break: heated, and the stores hold at least WARM_UP_HOURS of today's
	heating there (a fire about to go out again is no place to walk to: the break would end on arrival)."""
	return fuel.is_heated(source) and Rules.hours_of_fuel(fuel.wood_milli(), fuel.heating_day_milli(),
		fuel.cook_mean_milli()) >= WARM_UP_HOURS


func warm_place_for(i: int) -> int:
	"""Where resident `i` warms up: its bed's home if heated, else the nearest heated home it can reach, else the hall
	if heated; ColdScript.OUTDOORS when nowhere is."""
	var bed: int = _night.bed_of[i]
	if bed != AllocationScript.NO_BED:
		var own: int = Rules.div(bed, FixturesScript.PLACES)
		if warm_enough(own) and _reachable(i, own):
			return own
	var best: int = ColdScript.OUTDOORS
	var best_d: float = INF
	for r: int in FuelScript.ROOMS:
		if not warm_enough(r) or not _reachable(i, r):
			continue
		var d: float = _graph.rooms.centre_m(r).distance_squared_to(_brains[i].position)
		if d < best_d:
			best_d = d
			best = r
	if best == ColdScript.OUTDOORS and warm_enough(FuelScript.HALL) and _hall_door.is_finite():
		best = FuelScript.HALL
	return best


func _reachable(i: int, r: int) -> bool:
	"""Whether resident `i` can walk into home `r` through the network (the night's own test)."""
	var middle: int = _graph.rooms.middle[r]
	var fit_class: int = _graph.walker_class(i, false)
	return middle >= 0 and fit_class != PathsScript.CLASS_NONE and _graph.paths.nearest_mouth(_graph, middle, fit_class) >= 0


func send_warm_up(i: int, source: int) -> void:
	"""Hand resident `i` its warm-up break at `source` (a home row, or the hall), parking a work order at a spot."""
	var task: WarmUpScript = WarmUpScript.new(warmed_through.bind(i), fuel.is_heated.bind(source))
	if source == FuelScript.HALL:
		task.to_hall(source, Text.HALL_NAME, _hall_door)
	else:
		_aim_at_fire(task, source)
	var b: BrainScript = _brains[i]
	if b.order == BrainScript.ORDER_WORK and b.poi >= 0:
		b.remember_unfinished(UnfinishedScript.new(NightScript.WorkBack.new(b.poi).take_back, "Work at %s" %
			String(b.space().poi_names[b.poi]).replace("_", " ")))
	b.order_task(task)
	breaks_sent += 1


func _aim_at_fire(task: WarmUpScript, r: int) -> void:
	"""A home break's spots: the room's middle node, a spot FIRE_SIDE_PERMILLE toward its hearth, and the hearth."""
	var rooms: RoomsScript = _graph.rooms
	var hearth_u: Vector2i = FixturesScript.place_u(RoomsScript.TEMPLATE_HOME, hearth_place())
	var side_u := Vector2i(Rules.div(hearth_u.x * FIRE_SIDE_PERMILLE, 1000), Rules.div(hearth_u.y * FIRE_SIDE_PERMILLE, 1000))
	var fire: Vector2i = rooms.to_world_u(r, hearth_u)
	var side: Vector2i = rooms.to_world_u(r, side_u)
	task.to_home(r, Text.source_name(r), rooms.middle[r], _graph.node_m(rooms.middle[r]),
		Vector2(TunnelRules.to_m(side.x), TunnelRules.to_m(side.y)), Vector2(TunnelRules.to_m(fire.x), TunnelRules.to_m(fire.y)))


static func hearth_place() -> int:
	"""A burrow home's hearth place (its template's place of kind hearth)."""
	for f: int in RoomsScript.fixture_count(RoomsScript.TEMPLATE_HOME):
		if FixturesScript.place_kind(RoomsScript.TEMPLATE_HOME, f) == RoomsScript.FIX_HEARTH:
			return f
	return 0


func warmed_through(i: int) -> bool:
	"""Whether resident `i`'s exposure is back to 0 (its break's end)."""
	return cold.cold_milli[i] == 0


# --- the season skip (season_skip.gd) -----------------------------------------------------------------

func skip_to_next_season(advance: Callable) -> int:
	"""The Lab's "Skip to next season" (Brendan's ruling 4): the calendar to 06:00 on day 1 of the next season through
	`advance(usec) -> int` (the farm's, the calendar's owner), this winter's hours in lockstep; then the kitchen's quiet
	catch-up, the exposure clock re-based, and the news told what ran and what did not. The hours stepped."""
	_skipping = true
	var hours: int = SkipScript.run(_services.calendar, advance, catch_up)
	catch_up()
	_skipping = false
	if _kitchen != null:
		_kitchen.skip_to_hour(_services.calendar.hour_index())
		fuel.rebase_cooking(_kitchen.consumed_wood_milli, Rules.day_of_hour(_services.calendar.hour_index()))
	skip_lived_time()
	_services.notices.post(NoticesScript.SOURCE_VILLAGE, NoticesScript.LEVEL_NOTE,
		SkipScript.skipped_line(_services.calendar, hours), "Skipped to %s" % _services.calendar.date_text())
	revision += 1
	return hours


# --- the emergency actions (see THE EMERGENCY ACTIONS) ---------------------------------------------------

func set_banked(source: int, on: bool) -> void:
	"""Let `source`'s hearth go out (on) or light it again: the player's choice, from the next hour."""
	fuel.set_banked(source, on)
	revision += 1


func consolidate() -> PackedInt32Array:
	"""GDD §5.10's consolidation: the sleepers PACKED into the fewest homes with a hearth that hold them (`keep_homes`),
	beds allocated with those as the warm ones (the sleepers sent to their new beds), and the hearths of homes nobody then
	sleeps in let go out -- the fuel the empty homes would burn is saved. [residents moved, hearths let go out]."""
	_keep.fill(0)
	keep_homes(_keep)
	var moved: int = _night.consolidate(_kept)
	return PackedInt32Array([moved, _bank_empty_homes()])


func keep_homes(out: PackedByteArray) -> int:
	"""Which homes to keep lit (a byte per room row into `out`): homes with a hearth not let go out, heated ones first,
	then by most beds, until their beds hold everyone with a bed. How many."""
	var wanted: int = beds_count()
	var kept: int = 0
	var held: int = 0
	for heated: bool in [true, false]:
		while held < wanted:
			var best: int = _roomiest_home(out, heated)
			if best < 0:
				break
			out[best] = 1
			held += _night.beds_in(best)
			kept += 1
	return kept


func _roomiest_home(taken: PackedByteArray, heated: bool) -> int:
	"""The burning home not yet kept, heated or not as asked, with the most beds (the lower row on a tie; -1: none)."""
	var best: int = -1
	for r: int in FuelScript.ROOMS:
		if taken[r] == 1 or fuel.hearth[r] == 0 or fuel.banked[r] == 1 or fuel.is_heated(r) != heated:
			continue
		if best < 0 or _night.beds_in(r) > _night.beds_in(best):
			best = r
	return best


func _kept(r: int) -> bool:
	"""Whether home `r` is one consolidation keeps (the allocation's warm homes)."""
	return r >= 0 and r < _keep.size() and _keep[r] == 1


func _bank_empty_homes() -> int:
	"""Let go out the hearth of every burning home nobody sleeps in. How many."""
	var banked: int = 0
	for r: int in FuelScript.ROOMS:
		if fuel.hearth[r] == 1 and fuel.banked[r] == 0 and not has_sleepers(r):
			fuel.set_banked(r, true)
			banked += 1
	revision += 1
	return banked


func consolidate_preview() -> String:
	"""What `consolidate` would do now, in words."""
	var empty := PackedInt32Array()
	for r: int in FuelScript.ROOMS:
		if fuel.hearth[r] == 1 and fuel.banked[r] == 0 and not has_sleepers(r):
			empty.append(r)
	var kept: int = keep_homes(_preview)
	_preview.fill(0)
	var saving: int = maxi(fuel.burning_count() - 1 - kept, 0) * fuel.day_rate_milli
	var now_empty: String = "no home is empty yet" if empty.is_empty() else "%s %s empty already" % [Text.names_of(empty),
		"is" if empty.size() == 1 else "are"]
	return "Packs the %d %s into the fewest homes with a hearth (%d), then lets the hearths of the homes left empty go out (saves about %s a day); %s" % [
		beds_count(), "sleeper" if beds_count() == 1 else "sleepers", kept, Text.units(saving), now_empty]


# --- the readouts -----------------------------------------------------------------------------------------

func stamp() -> int:
	"""Bumped with everything the HUD's fuel breakdown reads (its `revision`): the counters repaint on it."""
	return revision


func fuel_days_hundredths() -> int:
	"""The HUD's Heating fuel figure (hearth_fuel.gd `fuel_days_hundredths`)."""
	return fuel.fuel_days_hundredths()


func hearth_words(r: int) -> String:
	"""A home's hearth for the room panel: its state and temperature, and why."""
	return Text.state_line(fuel, r).substr(Text.source_title(r).length() + 2)


func burning_sources() -> PackedInt32Array:
	"""Every hearth installed and not let go out (REQ-SET-147's affected homes)."""
	var out := PackedInt32Array()
	for s: int in FuelScript.SOURCES:
		if fuel.hearth[s] == 1 and fuel.banked[s] == 0:
			out.append(s)
	return out


func detail_lines() -> PackedStringArray:
	"""The fuel's breakdown for the ledger and the tooltip: demand, the last heated hour, and -- in autumn -- the
	twelve-day winter projection with its progress."""
	var lines := PackedStringArray([Text.demand_line(fuel)])
	var last: String = Text.last_heated_line(fuel)
	if not last.is_empty():
		lines.append(last)
	if projection_shown():
		lines.append(Text.projection_line(fuel))
	return lines


func projection_shown() -> bool:
	"""Whether REQ-SET-114's projection shows: in autumn (winter is next) and through winter (ruling 6)."""
	return fuel.season == WeatherScript.SEASON_AUTUMN or fuel.season == WeatherScript.SEASON_WINTER


func resident_name(i: int) -> String:
	"""Resident `i`'s name."""
	return _names[i]


func status_text(i: int, alone: bool) -> String:
	"""Resident `i`'s cold line for the party panel ("" when warm): Chilled and why, or the exposure building."""
	return Text.resident_text(cold, i, alone)


func status_word(i: int) -> String:
	"""Resident `i`'s cold word for the roster ("chilled", or "")."""
	return Text.CHILLED_WORD if cold.is_chilled(i) else ""


func fuel_winter_days_milli() -> int:
	"""M4's "fuel >= 18 winter days" (GDD §5.11) in thousandths of a day: the stores' wood over a WINTER day's demand --
	every hearth burning now at 4 U, plus the cooking mean -- whatever today's season (§5.8's fuel-days at winter
	demand); 0 with no hearth to heat. Bound to the goals' M4 `fuel` part (decision 0902). Allocation-free."""
	var hundredths: int = Rules.fuel_days_hundredths(fuel.wood_milli(), fuel.burning_count() * Rules.WINTER_DAY_MILLI,
		fuel.cook_mean_milli())
	return maxi(hundredths, 0) * 10


func metrics_into(out: Dictionary) -> void:
	"""THE METRICS for the balance sim, into `out`: wood burned (milli-U), source-hours heated and out of fuel, fuel-days
	(hundredths; -1 no demand), today's heating demand and the cooking mean (milli-U a day), the projection (milli-U),
	the residents Chilled now and the times anyone became Chilled, warm-up breaks sent."""
	out["burned_milli"] = fuel.burned_milli
	out["heated_hours"] = fuel.heated_hours
	out["cold_hours"] = fuel.cold_hours
	out["fuel_days_hundredths"] = fuel.fuel_days_hundredths()
	out["heating_day_milli"] = fuel.heating_day_milli()
	out["cook_mean_milli"] = fuel.cook_mean_milli()
	out["projection_milli"] = fuel.projection_milli()
	out["chilled_now"] = cold.chilled_total()
	out["chilled_count"] = cold.chilled_count
	out["breaks_sent"] = breaks_sent
