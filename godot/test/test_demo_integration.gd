extends "res://test/framework/test_case.gd"
## The live demo's farm and tunnel works as ONE village (decision 0196): one weather, one calendar,
## the tunnels' root cellars as the pantry's stores, one water adapter, one notice feed, and one demo
## panel at a time in the HUD's right column. Each test builds the pieces the way demo_village.gd
## wires them -- a command layer (whose tunnel tool builds the tunnel works) and a farm sharing ONE
## set of services -- over the placeholder cast in the real village layout. No staged assets.

const ServicesScript := preload("res://demo/demo_services.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const DemoWaterScript := preload("res://demo/demo_water.gd")
const TunnelWaterScript := preload("res://demo/tunnel/tunnel_water.gd")
const WeatherScript := preload("res://demo/weather/demo_weather.gd")
const CoreWeather := preload("res://scripts/core/weather.gd")
const DemoFarmScript := preload("res://demo/farm/demo_farm.gd")
const FarmCellars := preload("res://demo/farm/farm_cellars.gd")
const FarmWater := preload("res://demo/farm/farm_water.gd")
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
	"""The placeholder cast in the real village layout, with the farm's placeholder pond as an obstacle."""
	var world := DemoWorldScript.new()
	_nodes.append(world)
	var circles: Array[Vector3] = world.obstacles()
	circles.append(FarmWater.placeholder_obstacle())
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
		providers.append(FarmCellars.provider(_works().chambers))
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
	row: dry at 11:00; at 12:00 spring's showers begin and the planner's surface speed drops to 800;
	at midnight the empty loam bed takes exactly that same rain less spring's evaporation."""
	var farm := _village(false)
	var weather: WeatherScript = _services.weather
	assert_true(_works().weather == weather, "the tunnel works read the shared weather")
	assert_true(weather.is_bound(), "bound to the farm's real row")
	farm.step(5 * HOUR_USEC)
	_works().step(0)
	assert_equal(_works()._network.surface_permille, 1000, "11:00: dry, full pace")
	farm.step(HOUR_USEC)
	_works().step(0)
	assert_equal(weather.condition(), WeatherScript.COND_RAIN, "12:00: the showers begin")
	assert_equal(_works()._network.surface_permille, 800, "walkers slowed")
	var row: CoreWeather = farm.sim.crop_weather().weather()
	assert_equal(weather.rain(), row.rain(), "the weather's rain is the row's")
	assert_equal(weather.rain(), 1200, "spring's baseline")
	var before: int = farm.sim.moisture_of(BED_LOAM)
	farm.step(12 * HOUR_USEC)
	assert_equal(farm.sim.days_run, 1, "a midnight passed")
	assert_equal(farm.sim.last_weather_delta(), weather.rain() - SPRING_EVAPORATION, "the day's rain less evaporation")
	assert_equal(farm.sim.moisture_of(BED_LOAM), before + weather.rain() - SPRING_EVAPORATION,
		"the bed took the rain the walkers walk in")
	_works().step(0)
	assert_equal(_works()._network.surface_permille, 1000, "00:00: dry again")


func test_a_change_of_weather_is_posted_once_with_the_date() -> void:
	"""The showers starting at 12:00 are one WEATHER note in the feed, stamped with the demo date; the
	next rainy hour posts nothing."""
	var farm := _village(false)
	farm.step(6 * HOUR_USEC)
	assert_equal(_services.notices.count(), 1, "one notice")
	assert_equal(_services.notices.source(0), NoticesScript.SOURCE_WEATHER, "from the weather")
	assert_equal(_services.notices.stamp(0), "Y1 Spring 1, 12:00", "stamped with the demo date")
	assert_equal(_services.notices.summary(0), "Weather: Rain, walking 80%", "its short line")
	farm.step(HOUR_USEC)
	assert_equal(_services.notices.count(), 1, "still raining: nothing new")


func test_next_weather_runs_the_one_calendar_to_the_change() -> void:
	"""From 06:00 the next change is the 12:00 showers: six hours run -- farm, weather and date together."""
	var farm := _village(false)
	assert_equal(farm.skip_to_next_weather(), 6, "six hours")
	assert_equal(_services.calendar.date_text(), "Y1 Spring 1, 12:00", "the calendar moved")
	assert_equal(farm.sim.hours_run, 6, "the farm ran them")
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
	"""At 12:00 of spring 3 the farm warns of the night into spring 4, stamped with the same date the
	HUD then shows."""
	var farm := _village(false)
	var shell := UiShell.new()
	_nodes.append(shell)
	shell.build()
	var manager := GameManagerScript.new()
	_nodes.append(manager)
	manager.start_game()
	var date := HudDateScript.new()
	date.bind(shell, _services.calendar, manager)
	farm.step(54 * HOUR_USEC)
	date.sync()
	var frost: String = AlertsScript.frost_text(0, 3)
	assert_true(frost.begins_with("Frost tonight (Spring 4, 02:00–05:59)!"), "names the night")
	assert_true(_feed_has(frost, NoticesScript.LEVEL_WARNING), "a warning in the feed")
	var stamp: String = ""
	for k: int in _services.notices.count():
		if _services.notices.text(k) == frost:
			stamp = _services.notices.stamp(k)
	assert_equal(stamp, "Y1 Spring 3, 12:00", "stamped at noon of spring 3")
	assert_equal(shell.status_label().text, "Spring 3", "the day the HUD shows")
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
	storage.add_provider(FarmCellars.provider(chambers))
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
	assert_equal(storage.position_of(1), Vector2(-6.0, 12.0), "delivered at its centre")


func test_a_harvest_goes_to_the_coldest_store_with_room_nearest_its_bed() -> void:
	"""Two cellars (350) beat the covered store (1000); between them the one nearer the bed wins, each
	way round; a full cellar passes to the other, and a load no cellar holds goes to the store."""
	var chambers := ChambersScript.new()
	var far_cellar := _dig_cellar(chambers, Vector2(8.0, 4.0))
	var near_cellar := _dig_cellar(chambers, Vector2(-6.0, 12.8))
	var storage := StorageScript.new(Vector2(14.0, 6.2))
	storage.add_provider(FarmCellars.provider(chambers))
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

func test_both_water_queries_go_through_the_one_adapter() -> void:
	"""The farm's edge query is the shared adapter's, and the tunnel works' ground and floods ask the
	same adapter (the placeholder tables behind it)."""
	var farm := _village(false)
	var water: DemoWaterScript = _services.water
	assert_true(_works().water == water, "the tunnel works' water is the village's")
	assert_true(_works().events._water == water, "and their floods'")
	assert_true(farm.tunnels.water_edge == water.edge_query(), "the farm's edge query is the adapter's")
	assert_true(water.at_edge(Rules.to_u(-17.2), Rules.to_u(11.0)), "the pond's edge (placeholder)")
	assert_false(water.at_edge(0, 0), "the square is dry")
	assert_true(water.near_water(-15361, 10000), "the stream reach (placeholder)")
	assert_equal(water.spill_centre_u(), Vector2i(-14131, 10445), "the flood's disc (placeholder)")
	var table := TunnelWaterScript.new(PackedInt32Array([0, 0, 1024, 0, 512]), PackedInt32Array([1, 2, 3]))
	var fixture := DemoWaterScript.new(table)
	assert_true(fixture.near_water(512, 0), "a fixture table answers through the adapter")
	assert_equal(fixture.spill_radius_u(), 3, "its spill too")


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
		assert_false(band.intersects(detail), "%s: the news clear of the right column" % at)
		assert_false(band.intersects(geometry.minimap), "%s: and of the minimap" % at)
		assert_true(band.end.y < geometry.commands.position.y, "%s: above the command strip" % at)
		assert_true(band.size.x > 400.0 and band.size.x <= NewsStripScript.MAX_W, "%s: a readable width (%s)" % [at, band])
