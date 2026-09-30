extends "res://test/framework/test_case.gd"
## The live demo's farm and tunnel works as ONE village (decision 0196): one weather, one calendar,
## the tunnels' root cellars as the pantry's stores, one water adapter, one notice feed, and one demo
## panel at a time in the HUD's right column. Each test builds the pieces the way demo_village.gd
## wires them -- a command layer (whose tunnel tool builds the tunnel works) and a farm sharing ONE
## set of services -- over the placeholder cast in the real village layout. No staged assets.

const ServicesScript := preload("res://demo/demo_services.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const VillageWaterScript := preload("res://demo/village_water.gd")
const WaterMapScript := preload("res://demo/water/water_map.gd")
const TunnelPlanScript := preload("res://demo/tunnel/tunnel_plan.gd")
const NetworkScript := preload("res://demo/tunnel/tunnel_network.gd")
const WeatherScript := preload("res://demo/weather/demo_weather.gd")
const CoreWeather := preload("res://scripts/core/weather.gd")
const DemoFarmScript := preload("res://demo/farm/demo_farm.gd")
const FarmCellars := preload("res://demo/farm/farm_cellars.gd")
const Catalog := preload("res://demo/farm/farm_catalog.gd")
const StorageScript := preload("res://demo/farm/farm_storage.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const JobsScript := preload("res://demo/farm/farm_jobs.gd")
const Text := preload("res://demo/farm/farm_text.gd")
const AlertsScript := preload("res://demo/farm/farm_alerts.gd")
const ChambersScript := preload("res://demo/burrow/burrow_chambers.gd")
const WorksScript := preload("res://demo/tunnel/tunnel_works.gd")
const TaskScript := preload("res://demo/tunnel/tunnel_task.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const HudDateScript := preload("res://demo/ui/demo_hud_date.gd")
const NewsStripScript := preload("res://demo/ui/demo_news_strip.gd")
const DetailZoneScript := preload("res://demo/ui/demo_detail_zone.gd")
const TunnelPanelScript := preload("res://demo/tunnel/tunnel_panel.gd")
const BedPanelScript := preload("res://demo/farm/farm_bed_panel.gd")
const DemoWorldScript := preload("res://demo/world/demo_world.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const CommandScript := preload("res://demo/control/demo_command.gd")
const GameManagerScript := preload("res://scripts/systems/game_manager.gd")
const UiShell := preload("res://scripts/ui/ui_shell.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const VillageScript := preload("res://demo/demo_village.gd")

const DT: float = 1.0 / 60.0
const HOUR_USEC: int = 2500000
const CARROT: int = 2
const BED_LOAM: int = 0
const BED_CARROTS: int = 2
const BED_RADISH: int = 3
const BED_GRAIN_E: int = 5
const SPRING_EVAPORATION: int = 600

var _nodes: Array[Node] = []
var _services: ServicesScript = ServicesScript.new()
var _command: CommandScript = null
var _read: IntMath.IntResult = IntMath.IntResult.new()


func before_each() -> void:
	"""A fresh set of demo services per test."""
	_services = ServicesScript.new()
	_command = null


func after_each() -> void:
	"""Free every node a test built."""
	for node: Node in _nodes:
		if is_instance_valid(node):
			if node.is_inside_tree():
				node.get_parent().remove_child(node)
			node.free()
	_nodes.clear()


# --- fixtures -----------------------------------------------------------------------------------

func _cast() -> DemoCastScript:
	"""The placeholder cast in the real village layout."""
	var world := DemoWorldScript.new()
	_nodes.append(world)
	var circles: Array[Vector3] = world.obstacles()
	var cast := DemoCastScript.new()
	_nodes.append(cast)
	cast.build({}, world.points_of_interest(), circles)
	cast.set_bounds(world.bounds())
	return cast


func _village(with_cellars: bool) -> DemoFarmScript:
	"""The command layer (and its tunnel works) and the farm on ONE set of services, as demo_village.gd
	wires them; with the tunnels' root cellars as the pantry's stores when `with_cellars`."""
	var cast := _cast()
	_command = CommandScript.new()
	_nodes.append(_command)
	var camera := Camera3D.new()
	_nodes.append(camera)
	_command.configure(cast, camera, null, _services)
	var farm := DemoFarmScript.new()
	_nodes.append(farm)
	var providers: Array[Callable] = []
	if with_cellars:
		providers.append(FarmCellars.provider(_works().chambers, _command.tunnels().network))
	farm.configure({}, null, cast, _command, camera, null, providers, _services)
	return farm


func _works() -> WorksScript:
	"""The tunnel works the command layer's tunnel tool built."""
	return _command.tunnels().ext.works


func _dig_cellar(chambers: ChambersScript, at_m: Vector2) -> int:
	"""A finished root cellar centred at `at_m` (x, z metres); returns its chamber slot."""
	var ref := PackedInt32Array([-1, 0])
	var added: bool = chambers.add_into(ChambersScript.KIND_CELLAR, null, 0, 0,
		Vector2i(Rules.to_u(at_m.x), Rules.to_u(at_m.y)), ref)
	assert_true(added, "a cellar slot")
	chambers.set_done(ref[0])
	return ref[0]


func _feed_has(text: String, level: int) -> bool:
	"""Whether the shared feed holds this full text at this level."""
	for k: int in _services.notices.count():
		if _services.notices.text(k) == text and _services.notices.level(k) == level:
			return true
	return false


# --- one weather ----------------------------------------------------------------------------------

func test_one_weather_slows_the_walkers_and_wets_the_beds() -> void:
	"""The farm, the tunnel works and the village share ONE weather, read from the farm's real §5.10
	row: dry all of spring 1 (a spell's dry day, decision 0205); at 06:00 on spring 2, the spell's wet
	day, the showers begin and the planner's surface speed drops to 800; at midnight the empty loam bed
	takes exactly that day's rain less spring's evaporation -- every day's own, wet day or dry."""
	var farm := _village(false)
	var weather: WeatherScript = _services.weather
	assert_true(_works().weather == weather, "the tunnel works read the shared weather")
	assert_true(weather.is_bound(), "bound to the farm's real row")
	farm.step(5 * HOUR_USEC)
	_works().step(0)
	assert_equal(_works()._network.surface_permille, 1000, "11:00: dry, full pace")
	farm.step(HOUR_USEC)
	_works().step(0)
	assert_equal(weather.condition(), WeatherScript.COND_CLEAR, "12:00 of a dry day: still dry")
	farm.step(18 * HOUR_USEC)
	_works().step(0)
	assert_equal(weather.condition(), WeatherScript.COND_RAIN, "06:00 of the wet day: the showers begin")
	assert_equal(_works()._network.surface_permille, 800, "walkers slowed")
	var row: CoreWeather = farm.sim.crop_weather().weather()
	assert_equal(weather.rain(), row.rain(), "the weather's rain is the row's")
	assert_equal(weather.rain(), 1200, "spring's baseline")
	var before: int = farm.sim.moisture_of(BED_LOAM)
	farm.step(18 * HOUR_USEC)
	assert_equal(farm.sim.days_run, 2, "two midnights passed")
	assert_equal(farm.sim.last_weather_delta(), weather.rain() - SPRING_EVAPORATION, "the day's rain less evaporation")
	assert_equal(farm.sim.moisture_of(BED_LOAM), before + weather.rain() - SPRING_EVAPORATION,
		"the bed took the rain the walkers walk in")
	_works().step(0)
	assert_equal(_works()._network.surface_permille, 1000, "00:00: dry again")


func test_a_change_of_weather_is_posted_once_with_the_date() -> void:
	"""The spell's showers starting at 06:00 on spring 2 are one WEATHER note in the feed, stamped with the
	demo date; the next rainy hour posts nothing (the farm's own notes are not counted here)."""
	var farm := _village(false)
	farm.step(24 * HOUR_USEC)
	var posted: PackedInt32Array = _weather_notices()
	assert_equal(posted.size(), 1, "one weather notice")
	assert_equal(_services.notices.stamp(posted[0]), "Y1 Spring 2, 06:00", "stamped with the demo date")
	assert_equal(_services.notices.summary(posted[0]), "Weather: Rain, walking 80%", "its short line")
	farm.step(HOUR_USEC)
	assert_equal(_weather_notices().size(), 1, "still raining: nothing new")


func _weather_notices() -> PackedInt32Array:
	"""The feed's weather notices, oldest first."""
	var found := PackedInt32Array()
	for k: int in _services.notices.count():
		if _services.notices.source(k) == NoticesScript.SOURCE_WEATHER:
			found.append(k)
	return found


func test_next_weather_runs_the_one_calendar_to_the_change() -> void:
	"""From 06:00 of spring 1 the next change is the spell's showers at 06:00 of spring 2: a day runs --
	farm, weather and date together."""
	var farm := _village(false)
	assert_equal(farm.skip_to_next_weather(), 24, "a day")
	assert_equal(_services.calendar.date_text(), "Y1 Spring 2, 06:00", "the calendar moved")
	assert_equal(farm.sim.hours_run, 24, "the farm ran them")
	assert_equal(_services.weather.condition(), WeatherScript.COND_RAIN, "and it rains")


# --- one calendar ---------------------------------------------------------------------------------

func test_the_hud_date_is_the_farm_date() -> void:
	"""The HUD's date trigger shows the one calendar's day (all that fits its 88 px), its tooltip the
	full date and hour with the state and speed, and the farm panel's clock line the same date; UIManager
	writing the settlement's date over it is painted back on the next sync."""
	var farm := _village(false)
	var shell := UiShell.new()
	_nodes.append(shell)
	shell.build()
	var manager := GameManagerScript.new()
	_nodes.append(manager)
	assert_true(manager.start_game(), "the test's clock")
	var date := HudDateScript.new()
	date.bind(shell, _services.calendar, manager)
	farm.step(8 * HOUR_USEC)
	assert_true(date.sync(), "painted")
	assert_equal(shell.status_label().text, "Spring 1", "the HUD shows the demo day")
	assert_equal(shell.status_label().tooltip_text, HudDateScript.tooltip_text("Y1 Spring 1, 14:00",
		manager.get_state_name(), manager.get_speed()), "its tooltip the whole date and hour")
	assert_equal(shell.status_label().get_theme_font_size(&"font_size"), HudDateScript.TEXT_PX, "at the size that fits")
	assert_true(Text.clock_line(farm.sim).begins_with("Y1 Spring 1, 14:00 · "), "the farm panel shows the same date")
	assert_false(date.sync(), "nothing to repaint")
	shell.set_status_line("Playing  x1  Y1 spring 1")
	assert_true(date.sync(), "UIManager's settlement date is painted over")
	assert_equal(shell.status_label().text, "Spring 1", "ours again")
	farm.step(18 * HOUR_USEC)
	assert_true(date.sync(), "a new day")
	assert_equal(shell.status_label().text, "Spring 2", "follows the calendar")
	assert_true(shell.status_label().tooltip_text.begins_with("Y1 Spring 2, 08:00"), "to the hour")


func test_the_frost_warning_names_the_night_on_the_hud_s_calendar() -> void:
	"""At 12:00 of spring 10 the farm warns of the night into spring 11 (spring's one frost night,
	farm_weather.gd), stamped with the same date the HUD then shows."""
	var farm := _village(false)
	var shell := UiShell.new()
	_nodes.append(shell)
	shell.build()
	var manager := GameManagerScript.new()
	_nodes.append(manager)
	manager.start_game()
	var date := HudDateScript.new()
	date.bind(shell, _services.calendar, manager)
	farm.step((24 * 9 + 6) * HOUR_USEC)
	date.sync()
	var frost: String = AlertsScript.frost_text(0, 10)
	assert_true(frost.begins_with("Frost tonight (Spring 11, 02:00–05:59)!"), "names the night")
	assert_true(_feed_has(frost, NoticesScript.LEVEL_WARNING), "a warning in the feed")
	var stamp: String = ""
	for k: int in _services.notices.count():
		if _services.notices.text(k) == frost:
			stamp = _services.notices.stamp(k)
	assert_equal(stamp, "Y1 Spring 10, 12:00", "stamped at noon of spring 10")
	assert_equal(shell.status_label().text, "Spring 10", "the day the HUD shows")
	assert_true(shell.status_label().tooltip_text.begins_with(stamp), "and its tooltip's date and hour")


func test_the_farm_adopts_the_calendar_only_before_either_runs() -> void:
	"""Sharing is refused once the farm or the shared calendar has run, so no hour is lost or repeated."""
	var farm := _village(false)
	assert_true(farm.sim.calendar == _services.calendar, "the farm advances the shared calendar")
	farm.step(HOUR_USEC)
	assert_equal(_services.calendar.tick, 750, "an hour on the shared calendar")
	var fresh := CalendarScript.new()
	assert_false(farm.sim.share_calendar(fresh).ok, "refused once the farm has run")
	var started := CalendarScript.new()
	started.tick = 750
	var idle := DemoFarmScript.SimScript.new()
	assert_false(idle.share_calendar(started).ok, "refused when the shared calendar has run")
	assert_false(idle.share_calendar(null).ok, "and with none")
	var part := DemoFarmScript.SimScript.new()
	part.advance_usec(HOUR_USEC / 2)
	assert_equal(part.hours_run, 0, "half an hour: no hour run yet")
	assert_false(part.share_calendar(CalendarScript.new()).ok, "but its calendar has moved: refused")
	assert_true(farm.sim.calendar == _services.calendar, "kept")


# --- cellars -> pantry ------------------------------------------------------------------------------

func test_a_finished_root_cellar_is_a_pantry_store() -> void:
	"""burrow_chambers' cellar, through farm_cellars.gd: a StringName id the provider API accepts, its
	label, its 60 U and the GDD's 350; a planned cellar and a burrow home are not stores."""
	var chambers := ChambersScript.new()
	var storage := StorageScript.new(Vector2(14.0, 6.2))
	storage.add_provider(FarmCellars.provider(chambers, null))
	assert_equal(storage.count(), 1, "the covered store only")
	var ref := PackedInt32Array([-1, 0])
	chambers.add_into(ChambersScript.KIND_CELLAR, null, 0, 0, Vector2i(-6144, 12288), ref)
	chambers.add_into(ChambersScript.KIND_HOME, null, 0, 0, Vector2i(0, 0), ref)
	chambers.set_done(ref[0])
	storage.refresh()
	assert_equal(storage.count(), 1, "planned cellars and homes are not stores")
	chambers.set_done(0)
	storage.refresh()
	assert_equal(storage.count(), 2, "the cellar is")
	assert_equal(storage.refused_entries(), 0, "nothing refused")
	assert_equal(storage.id_of(1), &"root_cellar:0:0", "its id")
	assert_equal(storage.label_of(1), "Root cellar 1", "its label")
	assert_equal(storage.capacity_milli_of(1), 60000, "60 U")
	assert_equal(storage.permille_of(1), 350, "the GDD's cellar factor")
	assert_equal(storage.position_of(1), Vector2(-6.0, 12.0), "no tunnel: delivered where it lies")


func test_a_cellar_is_entered_by_its_tunnel_s_nearer_mouth() -> void:
	"""A cellar dug 1 m into an open 8 m tunnel is delivered to at the entrance; one 7 m in, at the
	exit -- the cellar's door, where a carrier can stand."""
	var chambers := ChambersScript.new()
	var network := NetworkScript.new()
	var ref := PackedInt32Array([-1, 0])
	assert_true(network.add_into(PackedInt32Array([0, 0, 8192, 0]), 2, 0, ref), "a tunnel")
	network.advance(ref[0], ref[1], 3600 * Rules.USEC_PER_SECOND)
	assert_true(network.is_open(ref[0]), "open")
	var room := PackedInt32Array([-1, 0])
	chambers.add_into(ChambersScript.KIND_CELLAR, network, ref[0], 1024, Vector2i(1024, 2048), room)
	chambers.set_done(room[0])
	chambers.add_into(ChambersScript.KIND_CELLAR, network, ref[0], 7168, Vector2i(7168, 2048), room)
	chambers.set_done(room[0])
	var entries: Array = FarmCellars.entries(chambers, network)
	assert_equal(entries[0][StorageScript.KEY_POSITION], Vector3(0.0, 0.0, 0.0), "1 m in: the entrance")
	assert_equal(entries[1][StorageScript.KEY_POSITION], Vector3(8.0, 0.0, 0.0), "7 m in: the exit")


func test_a_harvest_goes_to_the_coldest_store_with_room_nearest_its_bed() -> void:
	"""Two cellars (350) beat the covered store (1000); between them the one nearer the bed wins, each
	way round; a full cellar passes to the other, and a load no cellar holds goes to the store."""
	var chambers := ChambersScript.new()
	var far_cellar := _dig_cellar(chambers, Vector2(8.0, 4.0))
	var near_cellar := _dig_cellar(chambers, Vector2(-6.0, 12.8))
	var storage := StorageScript.new(Vector2(14.0, 6.2))
	storage.add_provider(FarmCellars.provider(chambers, null))
	var pantry := PantryScript.new(storage)
	assert_true(pantry.location_near_into(5100, Catalog.bed_centre_m(BED_CARROTS), _read), "from the carrots")
	assert_equal(storage.id_of(_read.value), &"root_cellar:%d:0" % near_cellar, "the cellar by the beds")
	assert_true(pantry.location_near_into(5100, Vector2(10.0, 4.0), _read), "from by the store")
	assert_equal(storage.id_of(_read.value), &"root_cellar:%d:0" % far_cellar, "the cellar by the store")
	assert_true(pantry.add_into(CARROT, 60000, 2, _read), "fill the near cellar")
	assert_true(pantry.location_near_into(5100, Catalog.bed_centre_m(BED_CARROTS), _read), "again")
	assert_equal(storage.id_of(_read.value), &"root_cellar:%d:0" % far_cellar, "the other cellar")
	assert_true(pantry.location_near_into(61000, Catalog.bed_centre_m(BED_CARROTS), _read), "too big")
	assert_equal(_read.value, 0, "the covered store")


func test_the_village_s_cellars_take_the_farm_s_harvest() -> void:
	"""Wired as demo_village.gd wires it: two root cellars -- one dug by the beds, one by the covered
	store -- become stores at the next farm hour, and the ripe carrots are carried to the one by their
	bed, not across the village."""
	var farm := _village(true)
	var by_store := _dig_cellar(_works().chambers, Vector2(10.0, 3.6))
	var by_beds := _dig_cellar(_works().chambers, Vector2(-6.0, 12.8))
	farm.step(24 * HOUR_USEC)
	assert_equal(farm.storage.count(), 3, "both cellars are stores")
	farm.crew.order(JobsScript.KIND_HARVEST, BED_CARROTS, PackedInt32Array([3]), JobsScript.ORIGIN_PLAYER)
	var cast: DemoCastScript = farm._cast
	var stored: bool = false
	for frame: int in roundi(120.0 / DT):
		cast.advance(DT)
		farm.crew.update(cast.clock.frame_usec)
		if farm.pantry.total_units() > 0:
			stored = true
			break
	assert_true(stored, "delivered")
	assert_true(farm.storage.index_of_id_into(&"root_cellar:%d:0" % by_beds, _read), "the cellar by the beds")
	assert_equal(farm.pantry.milli_at(CARROT, _read.value), 5100, "holds the carrots")
	assert_equal(farm.pantry.milli_at(CARROT, 0), 0, "not the covered store")
	assert_true(farm.storage.index_of_id_into(&"root_cellar:%d:0" % by_store, _read), "the cellar by the store")
	assert_equal(farm.pantry.milli_at(CARROT, _read.value), 0, "is passed over")
	assert_true(_feed_has("Harvested 5.1 U of carrot into the root cellar %d" % (by_beds + 1), NoticesScript.LEVEL_NOTE),
		"the crew's report is in the feed")


func test_the_village_hands_the_tunnels_cellars_to_the_farm() -> void:
	"""demo_village.storage_providers() is the tunnel works' finished cellars, as pantry stores."""
	_village(false)
	var village := VillageScript.new()
	_nodes.append(village)
	village._command = _command
	var providers: Array[Callable] = village.storage_providers()
	assert_equal(providers.size(), 1, "one provider")
	assert_equal((providers[0].call() as Array).size(), 0, "no cellar yet")
	_dig_cellar(_works().chambers, Vector2(-6.0, 12.8))
	var entries: Array = providers[0].call()
	assert_equal(entries.size(), 1, "the cellar")
	assert_equal(entries[0][StorageScript.KEY_ID], &"root_cellar:0:0", "as a pantry store")


# --- one water adapter --------------------------------------------------------------------------------

func test_every_water_query_goes_through_the_one_adapter_over_the_real_map() -> void:
	"""The farm's edge query and the tunnel works' ground, floods and route checks all ask the shared
	adapter, and it answers from the real stream (hand-read distances: the ford's bank 2460 u from
	x = 19.5, the run's 2567 u; the wet reach 4608 u)."""
	var farm := _village(false)
	var water: VillageWaterScript = _services.water
	assert_true(_works().water == water, "the tunnel works' water is the village's")
	assert_true(_works().events._water == water, "and their floods'")
	assert_true(farm.tunnels.water_edge == water.edge_query(), "the farm's edge query is the adapter's")
	assert_true(_command.tunnels().plan.water_crossing == water.crosses_water, "the planner asks it too")
	assert_true(water.at_edge(Rules.to_u(19.5), Rules.to_u(-0.8)), "by the ford")
	assert_false(water.at_edge(Rules.to_u(19.5), Rules.to_u(9.0)), "by the run: 2567 u")
	assert_true(water.near_water(Rules.to_u(19.0), Rules.to_u(9.0)), "wet ground by the stream")
	assert_false(water.near_water(Rules.to_u(17.5), Rules.to_u(9.0)), "4626 u: dry")
	assert_true(_works().ground.wet_at(Rules.to_u(19.0), Rules.to_u(9.0)), "the tunnels' ground map agrees")
	assert_equal(water.spill_centre_u(), Vector2i(22427, -895), "the flood spills at the ford's west bank")
	assert_equal(_works().events.centre_m(), Vector2(Rules.to_m(22427), Rules.to_m(-895)), "where the flood event is")


func test_a_tunnel_from_the_stream_s_edge_irrigates_the_beds_it_runs_under() -> void:
	"""A finished tunnel with its east mouth by the ford (at the real stream's edge) running under the
	radish bed irrigates it; the same route from the run's bank (just too far) only drains it."""
	var farm := _village(false)
	var network: NetworkScript = farm._cast.space().tunnels
	var ref := PackedInt32Array([-1, 0])
	var route := PackedInt32Array([Rules.to_u(19.5), Rules.to_u(-0.8), Rules.to_u(-6.0), Rules.to_u(12.8),
		Rules.to_u(-12.0), Rules.to_u(12.8)])
	assert_true(network.add_into(route, 3, 0, ref), "the ford tunnel")
	network.advance(ref[0], ref[1], 3600 * Rules.USEC_PER_SECOND)
	farm.step(HOUR_USEC)
	assert_true(farm.sim.is_irrigated(BED_RADISH), "irrigated from the stream")
	_services = ServicesScript.new()
	var other := _village(false)
	var other_network: NetworkScript = other._cast.space().tunnels
	var dry := PackedInt32Array([Rules.to_u(19.5), Rules.to_u(9.0), Rules.to_u(-6.0), Rules.to_u(12.8),
		Rules.to_u(-12.0), Rules.to_u(12.8)])
	assert_true(other_network.add_into(dry, 3, 0, ref), "the run tunnel")
	other_network.advance(ref[0], ref[1], 3600 * Rules.USEC_PER_SECOND)
	other.step(HOUR_USEC)
	assert_false(other.sim.is_irrigated(BED_RADISH), "not from 2567 u away")
	assert_true(other.sim.is_drained(BED_RADISH), "it drains instead")


func test_the_services_answer_from_the_map_they_are_given() -> void:
	"""demo_village hands the services its water node's map; the adapter answers from exactly that map
	(a fixture pond here), not the authored village water."""
	var map := _pond_map()
	var shared := ServicesScript.new(map)
	assert_true(shared.water.map() == map, "the given map")
	assert_true(shared.water.near_water(0, 0), "the fixture pond is wet")
	assert_false(shared.water.near_water(Rules.to_u(19.0), Rules.to_u(9.0)), "the authored stream is not there")


func _pond_map() -> WaterMapScript:
	"""A fixture: a pond of 1 m radius at the origin, with the ford landing the adapter spills at."""
	var map := WaterMapScript.new(1229)
	assert_true(map.add_pond(&"pond", PackedInt32Array([0, 0, 1024, 512]), 184, 512).ok, "pond")
	assert_true(map.add_landing(&"ford_west", Vector2i(1024, 0), 1536).ok, "landing")
	assert_true(map.finalize().ok, "finalized")
	return map


func test_the_planner_refuses_a_bore_under_water() -> void:
	"""With the adapter's route check, a point in the water and a leg passing within half a bore of it
	are refused REFUSE_UNDER_WATER; a leg clear of it is laid; a laid route crossing it is refused too."""
	var water := VillageWaterScript.new(_pond_map())
	var plan := TunnelPlanScript.new()
	plan.water_crossing = water.crosses_water
	var bounds := Rect2i(-20480, -20480, 40960, 40960)
	var none := PackedInt32Array()
	assert_equal(plan.try_add(0, 0, bounds, none), Rules.REFUSE_UNDER_WATER, "a point in the pond")
	assert_equal(plan.try_add(-3072, 0, bounds, none), Rules.REFUSE_NONE, "west of it")
	assert_equal(plan.try_add(3072, 0, bounds, none), Rules.REFUSE_UNDER_WATER, "a leg through it")
	assert_equal(plan.try_add(3072, 3072, bounds, none), Rules.REFUSE_UNDER_WATER,
		"a leg 1374 u from its centre: 350 u off the water, inside half a bore")
	assert_equal(plan.try_add(3072, 4096, bounds, none), Rules.REFUSE_NONE, "1704 u: 680 u off, clear")
	assert_equal(plan.count, 2, "two points laid")
	plan.points_u[2] = 3072
	plan.points_u[3] = 0
	assert_equal(plan.route_reason(bounds, none), Rules.REFUSE_UNDER_WATER, "a route through it is refused")
	assert_equal(Rules.reason_text(Rules.REFUSE_UNDER_WATER), "a tunnel cannot pass under the stream or the pond", "in words")


# --- one notice feed ------------------------------------------------------------------------------

func test_the_feed_keeps_date_stamped_entries_newest_first() -> void:
	"""Posts are stamped with the bound calendar's date, read newest first, refused when empty or of an
	unknown source or level, and the ring keeps the newest CAPACITY."""
	var feed := NoticesScript.new()
	assert_true(feed.post(NoticesScript.SOURCE_FARM, NoticesScript.LEVEL_NOTE, "undated"), "posted")
	assert_equal(feed.stamp(0), NoticesScript.UNDATED, "no calendar yet")
	var calendar := CalendarScript.new()
	feed.bind_calendar(calendar)
	calendar.tick = 750 * 8
	assert_true(feed.post(NoticesScript.SOURCE_TUNNELS, NoticesScript.LEVEL_WARNING, "Tunnel 1 flooded.", "Tunnel 1 flooded — pump it out"), "posted")
	assert_equal(feed.line(0), "Y1 Spring 1, 14:00 · Warning: Tunnel 1 flooded.", "the full line")
	assert_equal(feed.short_line(0), "Y1 Spring 1, 14:00 · Warning: Tunnel 1 flooded — pump it out", "the short line")
	assert_equal(feed.text(1), "undated", "the older one second")
	assert_false(feed.post(NoticesScript.SOURCE_FARM, NoticesScript.LEVEL_NOTE, ""), "no empty notice")
	assert_false(feed.post(9, NoticesScript.LEVEL_NOTE, "x"), "no unknown source")
	assert_false(feed.post(NoticesScript.SOURCE_FARM, 5, "x"), "no unknown level")
	assert_equal(feed.count(), 2, "two kept")
	for k: int in NoticesScript.CAPACITY + 3:
		feed.post(NoticesScript.SOURCE_CREW, NoticesScript.LEVEL_NOTE, "n%d" % k)
	assert_equal(feed.count(), NoticesScript.CAPACITY, "the ring is full")
	assert_equal(feed.text(0), "n%d" % (NoticesScript.CAPACITY + 2), "newest first")
	assert_equal(feed.text(NoticesScript.CAPACITY - 1), "n3", "the oldest kept")
	var out := PackedStringArray()
	assert_equal(feed.latest_of_into(NoticesScript.SOURCE_CREW, 2, out), 2, "two of the crew's")
	assert_equal(out[0], "Y1 Spring 1, 14:00 · n%d" % (NoticesScript.CAPACITY + 2), "newest first")
	out.clear()
	assert_equal(feed.latest_of_into(NoticesScript.SOURCE_FARM, 3, out), 0, "the farm's have gone")


func test_the_news_strip_shows_fresh_notices_and_warnings_longer() -> void:
	"""The strip shows the newest fresh entries (warnings worded and kept 30 s, notes 12 s) and hides
	when none is fresh."""
	var feed := NoticesScript.new()
	var strip := NewsStripScript.new()
	_nodes.append(strip)
	strip.configure(feed)
	assert_equal(strip.refresh(Time.get_ticks_msec()), 0, "nothing to say")
	assert_false(strip.is_shown(), "hidden")
	feed.post(NoticesScript.SOURCE_FARM, NoticesScript.LEVEL_WARNING, "Blight on Bed 3!")
	feed.post(NoticesScript.SOURCE_CREW, NoticesScript.LEVEL_NOTE, "Sow done: Bed 1")
	var now: int = Time.get_ticks_msec()
	assert_equal(strip.refresh(now), 2, "both fresh")
	assert_true(strip.is_shown(), "shown")
	assert_equal(strip.line_text(0), "— · Sow done: Bed 1", "newest on top")
	assert_equal(strip.line_text(1), "— · Warning: Blight on Bed 3!", "the warning worded")
	assert_equal(strip.refresh(now + NewsStripScript.NOTE_MSEC + 1), 1, "the note has gone")
	assert_equal(strip.line_text(0), "— · Warning: Blight on Bed 3!", "the warning stays")
	assert_equal(strip.refresh(now + NewsStripScript.WARNING_MSEC + 1), 0, "then it goes too")
	assert_false(strip.is_shown(), "hidden again")


func test_the_farm_and_the_tunnels_post_to_the_one_feed() -> void:
	"""The farm's alerts arrive with their levels (ripe a note), the tunnel works' happenings as notes
	and warnings, and an order's answer (`tell`) stays out of the feed."""
	var farm := _village(false)
	farm.step(24 * HOUR_USEC)
	assert_true(_feed_has("Bed 3 (carrot) is ripe — harvest it within 2 days", NoticesScript.LEVEL_NOTE),
		"the farm's ripe note")
	var before: int = _services.notices.count()
	_works().say("Tunnel 1 widened.", "Tunnel 1 widened")
	_works().warn("Tunnel 1 is seeping.", "Tunnel 1 is seeping — brace it")
	_works().tell("Can't: select a finished tunnel first")
	assert_equal(_services.notices.count(), before + 2, "two posted, the answer not")
	assert_equal(_services.notices.level(0), NoticesScript.LEVEL_WARNING, "the seep a warning")
	assert_equal(_services.notices.level(1), NoticesScript.LEVEL_NOTE, "the widening a note")
	assert_equal(_works().log_lines[-1], "Can't: select a finished tunnel first", "the answer in the panel's log")


func test_a_task_speaks_before_the_farm_s_words() -> void:
	"""doing_text: the farm's words for its worker, but a tunnel task that has taken the resident says
	what it is doing instead."""
	var farm := _village(false)
	_command.set_task_text(func(i: int) -> String: return "Sowing bed %d" % (i + 1))
	assert_equal(_command.doing_text(1), "Sowing bed 2", "the farm's words")
	var brain: BrainScript = (farm._cast.actor(1) as DemoActorScript).brain
	brain.order_task(TaskScript.new())
	assert_equal(_command.doing_text(1), "on an errand", "the task's own words first")
	brain.release()
	assert_equal(_command.doing_text(1), "Sowing bed 2", "the farm's again")


# --- one panel in the right column ----------------------------------------------------------------

func test_the_right_column_shows_one_demo_panel_at_a_time() -> void:
	"""The farm's panel by default; a tunnel intent brings the tunnels' (the farm's hides); a bed click
	brings the farm's back; the tabs follow."""
	var farm := _village(false)
	var zone := DetailZoneScript.new()
	_nodes.append(zone)
	zone.build()
	var ext := _command.tunnels().ext
	zone.add_panel(DetailZoneScript.PANEL_FARM, farm.bed_panel)
	zone.add_panel(DetailZoneScript.PANEL_TUNNELS, ext.panel)
	farm.panel_wanted.connect(zone.show_panel.bind(DetailZoneScript.PANEL_FARM))
	ext.panel_wanted.connect(zone.show_panel.bind(DetailZoneScript.PANEL_TUNNELS))
	assert_true(farm.bed_panel.is_shown(), "the farm's by default")
	assert_false(ext.panel.is_shown(), "the tunnels' hidden")
	assert_true(zone.tab(DetailZoneScript.PANEL_FARM).button_pressed, "its tab")
	ext.set_planning(true)
	assert_false(farm.bed_panel.is_shown(), "laying a route: the farm's hides")
	assert_true(ext.panel.is_shown(), "the tunnels' shows")
	assert_true(zone.tab(DetailZoneScript.PANEL_TUNNELS).button_pressed, "its tab")
	assert_false(zone.tab(DetailZoneScript.PANEL_FARM).button_pressed, "not both")
	ext.set_planning(false)
	farm.select_bed(BED_CARROTS)
	assert_true(farm.bed_panel.is_shown(), "a bed: the farm's again")
	assert_false(ext.panel.is_shown(), "the tunnels' hides")
	zone.tab(DetailZoneScript.PANEL_TUNNELS).pressed.emit()
	assert_true(ext.panel.is_shown(), "the tab switches")
	assert_false(farm.bed_panel.is_shown(), "one at a time")


func test_the_zone_s_panels_sit_below_its_tabs_and_the_news_clear_of_both_columns() -> void:
	"""At 1280x720 and 1920x1080: the tab strip along the detail zone's top, both panels' rectangle
	below it and inside the zone (they share it, one shown at a time), and the news band between the
	minimap and the right column, above the command strip."""
	var layout := UiLayout.new()
	var geometry := UiLayout.Geometry.new()
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		var strip: Rect2 = DetailZoneScript.strip_placement(size.x, size.y, layout, geometry)
		var detail: Rect2 = geometry.detail
		var inset: float = DetailZoneScript.STRIP_H + DetailZoneScript.STRIP_GAP
		var tunnels: Rect2 = TunnelPanelScript.placement(size.x, size.y, layout, geometry, inset)
		var beds: Rect2 = BedPanelScript.placement(Vector2(size), inset, layout, geometry)
		var band: Rect2 = NewsStripScript.band_placement(size.x, size.y, layout, geometry)
		var at := "%dx%d" % [size.x, size.y]
		assert_true(detail.encloses(strip), "%s: the strip in the zone (%s in %s)" % [at, strip, detail])
		assert_true(tunnels.position.y >= strip.end.y + DetailZoneScript.STRIP_GAP, "%s: tunnels below the strip" % at)
		assert_true(detail.encloses(tunnels), "%s: tunnels inside the zone" % at)
		assert_equal(beds, tunnels, "%s: the bed panel takes the same place" % at)
		if geometry.commands.intersects(detail):
			assert_true(tunnels.end.y <= geometry.commands.position.y, "%s: the panels end above the command strip" % at)
		assert_false(tunnels.intersects(geometry.commands), "%s: never under the command strip" % at)
		assert_false(band.intersects(detail), "%s: the news clear of the right column" % at)
		assert_false(band.intersects(geometry.minimap), "%s: and of the minimap" % at)
		assert_true(band.end.y < geometry.commands.position.y, "%s: above the command strip" % at)
		## Centred on the command strip now (playtest 2026-09-29), so at 1280x720, where the commands
		## run under the right column, the band is narrower than the old 400+ (328 px): still a
		## readable column of 14 px text, never under the right column or the minimap.
		assert_true(band.size.x >= 320.0 and band.size.x <= NewsStripScript.MAX_W, "%s: a readable width (%s)" % [at, band])


func test_the_news_band_is_centred_on_the_command_strip() -> void:
	"""Playtest 2026-09-29: "center the news bar with the action bar". At every supported size, with
	the resident journal closed or open (the command strip moves left for it), the band's centre is
	the command strip's centre (±1 px), clear of the minimap and the right column."""
	var layout := UiLayout.new()
	var geometry := UiLayout.Geometry.new()
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(3840, 2160)]:
		for journal: bool in [false, true]:
			var band: Rect2 = NewsStripScript.band_placement(size.x, size.y, layout, geometry, journal)
			var at := "%dx%d journal %s" % [size.x, size.y, journal]
			var hud := UiLayout.Geometry.new()
			assert_true(UiLayout.new().compute_into(size.x, size.y, UiLayout.USER_SCALE_100, journal, hud), "%s: the HUD's layout" % at)
			assert_true(absf(band.get_center().x - hud.commands.get_center().x) <= 1.0,
				"%s: centred on the HUD's commands (%.1f vs %.1f)" % [at, band.get_center().x, hud.commands.get_center().x])
			assert_false(band.intersects(geometry.detail), "%s: clear of the right column" % at)
			assert_false(band.intersects(geometry.minimap), "%s: and of the minimap" % at)
			assert_true(band.size.x >= 320.0 and band.size.x <= NewsStripScript.MAX_W, "%s: readable (%s)" % [at, band])
			assert_true(band.end.y < geometry.commands.position.y, "%s: above the commands" % at)


func test_the_news_strip_follows_the_command_strip_when_the_journal_opens() -> void:
	"""The strip asks the right column whether the journal holds it (demo_village hands it the zone's
	`journal_open`) and lays its band out for that answer: centred on the command strip as the HUD
	lays it out with the journal closed, then open; its refresh notices the change."""
	var open: Array[bool] = [false]
	var news := NewsStripScript.new()
	_nodes.append(news)
	news.configure(_services.notices)
	news.follow_journal(func() -> bool: return open[0])
	var layout := UiLayout.new()
	var geometry := UiLayout.Geometry.new()
	for state: bool in [false, true]:
		open[0] = state
		news.refresh(0)
		assert_equal(news.journal_followed(), state, "the refresh follows the journal (%s)" % state)
		var band: Rect2 = news.band_in(Vector2(1920.0, 1080.0))
		assert_true(layout.compute_into(1920, 1080, UiLayout.USER_SCALE_100, state, geometry), "the HUD's layout")
		assert_true(absf(band.get_center().x - geometry.commands.get_center().x) <= 1.0,
			"journal %s: centred on the HUD's commands (%.1f vs %.1f)" % [state, band.get_center().x, geometry.commands.get_center().x])
	var zone := DetailZoneScript.new()
	_nodes.append(zone)
	assert_false(zone.journal_open(), "the zone's own answer, as demo_village hands it over, starts closed")