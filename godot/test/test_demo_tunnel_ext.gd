extends "res://test/framework/test_case.gd"
## The live demo's tunnel extensions (decision 0196), as pure integer logic: the weather source, the
## ground map, the ground-aware dig timeline and crew rate, bore classes and loaded fit, the planner's
## weather, lantern and queue costs, mouth queues, jobs, hazards, finds, stores and threats. (The rooms that
## replaced the chambers are test_demo_rooms.gd's.)
##
## No scene tree and no staged assets. Every expected value is a literal worked out by hand from the
## cited constants (113 ticks and 2000 milli-U a quantum; weather.gd's §5.10 tables; the GDD's
## cellar factor 350 and 12 beds in 40 tiles) and the named demo values. Grounds are synthetic: a
## real ground map with its cells overwritten, so a test controls exactly what each quantum cuts.

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const GroundScript := preload("res://demo/tunnel/tunnel_ground.gd")
const FarmWeatherScript := preload("res://demo/farm/farm_weather.gd")
const WeatherScript := preload("res://demo/weather/demo_weather.gd")
const QueueScript := preload("res://demo/tunnel/tunnel_queue.gd")
const CrewScript := preload("res://demo/tunnel/tunnel_crew.gd")
const SkillsScript := preload("res://demo/tunnel/dig_skills.gd")
const JobsScript := preload("res://demo/tunnel/tunnel_jobs.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")
const FindsScript := preload("res://demo/tunnel/tunnel_finds.gd")
const HazardsScript := preload("res://demo/tunnel/tunnel_hazards.gd")
const EventsScript := preload("res://demo/events/demo_events.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const WaterMapScript := preload("res://demo/water/water_map.gd")
const VillageWaterScript := preload("res://demo/village_water.gd")
const CoreWeather := preload("res://scripts/core/weather.gd")

## The standard fixture: a 12 m mouth-to-mouth route along z = 0.5 m from x = 0.5 m, laid as a piece of
## three segments (underground_graph.gd PIECES): slot 0 the entrance RAMP (0.5..4.5 m: an entry shaft in
## cell 20 of ROW and bore quanta in cells 21..24), slot 1 the level BORE (4.5..8.5 m: quanta in cells
## 25..28, no shafts) and slot 2 the exit RAMP (8.5..12.5 m: quanta in 29..32, the exit shaft in 32).
## Mouth row 0 is the entrance at (0.5, 0.5) m, row 1 the exit at (12.5, 0.5) m.
const ROW: int = 20
const RAMP: int = 0
const BORE: int = 1
const EXIT_RAMP: int = 2


func _yes(_index: int) -> bool:
	"""A `fits` callable for crews: everyone fits."""
	return true


func _no(_index: int) -> bool:
	"""A `fits` callable for crews: nobody fits."""
	return false


func _loam_ground() -> GroundScript:
	"""The village's ground grid with every cell plain dry loam."""
	var ground := GroundScript.new()
	ground.cells.fill(GroundScript.LOAM)
	return ground


func _mark(ground: GroundScript, columns: Array[int], value: int) -> void:
	"""Set cells (column, ROW) to `value`."""
	for c in columns:
		ground.cells[ROW * ground.columns + c] = value


func _network_on(ground: GroundScript, route: Array[Vector2i]) -> GraphScript:
	"""A network over `ground` with one piece along `route` (u), its first segment (slot 0) DIGGING and the
	rest PLANNED (add_into)."""
	var network := GraphScript.new()
	network.set_ground(ground)
	var flat := PackedInt32Array()
	for p in route:
		flat.append(p.x)
		flat.append(p.y)
	var ref := PackedInt32Array([-1, 0, -1])
	assert_true(network.add_into(flat, route.size(), 0, ref), "fixture tunnel stored")
	return network


func _twelve_metres(ground: GroundScript) -> GraphScript:
	"""The standard 12 m route (0.5, 0.5) -> (12.5, 0.5) m, still being dug (see ROW)."""
	return _network_on(ground, [Vector2i(512, 512), Vector2i(12800, 512)])


func _open(network: GraphScript, slot: int) -> void:
	"""Dig segment `slot` to the end (taking it up first when it is PLANNED or PAUSED)."""
	network.start_dig(slot, network.generation[slot], 0)
	network.advance(slot, network.generation[slot], 1000000000)


func _open_piece(network: GraphScript, p: int) -> void:
	"""Dig every segment of piece `p`, in dig order."""
	var chain := PackedInt32Array()
	network.piece_segments_into(p, chain)
	for slot in chain:
		_open(network, slot)


func _dig_to(network: GraphScript, slot: int, ticks: int) -> void:
	"""Advance DIGGING segment `slot` at its rate 1000 until exactly `ticks` are dug (the fewest whole
	microseconds that reach them: ceil(ticks x 10^6 / 30), which never reaches the next tick)."""
	var target := Rules.ceil_div(ticks * Rules.USEC_PER_SECOND, Rules.TICKS_PER_SECOND)
	network.advance(slot, network.generation[slot], target - network.dig_usec[slot])


# --- weather ----------------------------------------------------------------------------------

func test_every_day_s_climate_is_the_real_table_s() -> void:
	"""The weather holds no climate of its own: fed §5.10's (season, event) days from weather.gd's own
	readers, it reads each on a spell's wet day (day 2 of every season, SPELLS) at 15:00 (a shower hour
	for every rainy day) and at 03:00 (dry but for the Ideal spell's three days' worth, 24 hours)."""
	var table := CoreWeather.new()
	var seasons: Array[int] = [0, 0, 0, 1, 2, 2, 3, 3]
	var events: Array[int] = [CoreWeather.EVENT_NONE, CoreWeather.EVENT_IDEAL_SPELL, CoreWeather.EVENT_HEAVY_RAIN,
		CoreWeather.EVENT_CALM_DAYS, CoreWeather.EVENT_HEAVY_RAIN, CoreWeather.EVENT_EARLY_FROST, CoreWeather.EVENT_NONE,
		CoreWeather.EVENT_HARD_FREEZE]
	var expected_t: Array[int] = [120, 180, 90, 220, 70, -30, -50, -120]
	var expected_r: Array[int] = [1200, 1800, 3200, 300, 2700, 700, 0, 0]
	var at_three: Array[int] = [0, 1, 0, 0, 0, 3, 3, 3]
	var at_fifteen: Array[int] = [1, 1, 1, 1, 1, 2, 3, 3]
	var weather := WeatherScript.new()
	for k in seasons.size():
		var t: int = table.temperature_tenths_for(seasons[k], events[k]).value
		var r: int = table.rain_for(seasons[k], events[k]).value
		weather.observe(seasons[k], 2, 15, t, r, events[k])
		assert_equal(weather.temperature_tenths(), expected_t[k], "temperature of day %d" % k)
		assert_equal(weather.rain(), expected_r[k], "rain of day %d" % k)
		assert_equal(weather.condition(), at_fifteen[k], "15:00 of day %d" % k)
		weather.observe(seasons[k], 2, 3, t, r, events[k])
		assert_equal(weather.condition(), at_three[k], "03:00 of day %d" % k)


func test_ordinary_rain_falls_in_spells_of_three_days() -> void:
	"""SPELLS (decision 0205): a spell's rain falls on its one wet day (spring 2, 5, 8, 11 -- every
	season's the same, 12 days a season) three days' worth; a downpour (2000 or more) falls on its own
	day; the dry days of a spell do not rain at all."""
	var spring: Array[int] = []
	for day: int in range(1, 13):
		spring.append(WeatherScript.falling_rain(1200, 0, day))
	assert_equal(spring, [0, 3600, 0, 0, 3600, 0, 0, 3600, 0, 0, 3600, 0] as Array[int], "spring's spells")
	for season: int in 4:
		assert_true(WeatherScript.is_wet_day(season, 2), "day 2 of season %d is wet" % season)
		assert_false(WeatherScript.is_wet_day(season, 3), "day 3 of season %d is dry" % season)
	assert_equal(WeatherScript.falling_rain(3200, 0, 3), 3200, "heavy rain falls on its own day")
	assert_equal(WeatherScript.falling_rain(2000, 0, 1), 2000, "the downpour threshold is inclusive")
	assert_equal(WeatherScript.falling_rain(1999, 0, 1), 0, "just under it waits for the wet day")
	assert_equal(WeatherScript.falling_rain(1999, 0, 2), 5997, "and falls there, three days' worth")
	assert_equal(WeatherScript.falling_rain(0, 0, 2), 0, "a dry spell stays dry")
	var weather := WeatherScript.new()
	var changes: int = 0
	var wet: bool = false
	for day: int in range(1, 13):
		for hour: int in 24:
			weather.observe(0, day, hour, 120, 1200, CoreWeather.EVENT_NONE)
			changes += 1 if weather.is_wet() != wet else 0
			wet = weather.is_wet()
	assert_equal(changes, 8, "a baseline spring: four spells of rain, each one change on and one off")


func test_an_hour_reads_as_sky_at_exact_thresholds() -> void:
	"""Above 0.0 C a rain hour is rain, else clear; at or below it snow, else frost."""
	assert_equal(WeatherScript.classify(1, false), WeatherScript.COND_CLEAR, "dry and mild")
	assert_equal(WeatherScript.classify(1, true), WeatherScript.COND_RAIN, "a shower above freezing")
	assert_equal(WeatherScript.classify(0, true), WeatherScript.COND_SNOW, "a shower at freezing: snow")
	assert_equal(WeatherScript.classify(0, false), WeatherScript.COND_FROST, "freezing and dry")
	assert_equal(WeatherScript.classify(-120, false), WeatherScript.COND_FROST, "hard freeze")


func test_a_day_s_rain_falls_as_whole_shower_hours() -> void:
	"""rain / 200 whole hours (at most 24), centred on 15:00 and kept inside the day."""
	var cases: Array[Vector3i] = [Vector3i(1200, 6, 12), Vector3i(1800, 9, 11), Vector3i(3200, 16, 7),
		Vector3i(300, 1, 15), Vector3i(199, 0, 15), Vector3i(200, 1, 15), Vector3i(0, 0, 15),
		Vector3i(4800, 24, 0), Vector3i(9999, 24, 0)]
	for c in cases:
		assert_equal(WeatherScript.shower_hours(c.x), c.y, "hours of %d" % c.x)
		assert_equal(WeatherScript.first_shower_hour(c.x), c.z, "first hour of %d" % c.x)
	assert_false(WeatherScript.is_rain_hour(1200, 11), "11:00 is before spring's showers")
	assert_true(WeatherScript.is_rain_hour(1200, 12), "12:00 is the first")
	assert_true(WeatherScript.is_rain_hour(1200, 17), "17:00 the last")
	assert_false(WeatherScript.is_rain_hour(1200, 18), "18:00 is dry")
	assert_false(WeatherScript.is_rain_hour(0, 15), "a dry day never rains")


func test_the_surface_speed_query() -> void:
	"""The one walking query: 1000 clear, 800 rain, 600 snow, 850 frost per mille; only rain is wet (on a
	spell's wet day, spring 2: its showers are 06:00-23:59)."""
	var weather := WeatherScript.new()
	var hours: Array[Vector3i] = [Vector3i(120, 1200, 3), Vector3i(120, 1200, 12), Vector3i(-30, 700, 15),
		Vector3i(-50, 0, 12)]
	var expected: Array[int] = [1000, 800, 600, 850]
	var wet: Array[bool] = [false, true, false, false]
	for k in hours.size():
		weather.observe(0, 2, hours[k].z, hours[k].x, hours[k].y, CoreWeather.EVENT_NONE)
		assert_equal(weather.surface_speed_permille(), expected[k], "hour %d" % k)
		assert_equal(weather.is_wet(), wet[k], "wet %d" % k)


func test_a_frost_night_s_hours_read_as_frost() -> void:
	"""Spring's demo frost night (farm_weather.gd's mask: spring 11 since decision 0205): 02:00-05:59 fall
	to -3.0 C and read as frost; 06:00 is not frost (that day is a spell's wet day, so it rains); the next
	night is no frost night."""
	var night: int = 11
	assert_true(FarmWeatherScript.frost_tonight(0, night - 1), "the farm's mask has spring %d" % night)
	var weather := WeatherScript.new()
	weather.observe(0, night, 2, 120, 1200, CoreWeather.EVENT_NONE)
	assert_equal(weather.temperature_tenths(), -30, "the frost night's air")
	assert_equal(weather.condition(), WeatherScript.COND_FROST, "frost")
	assert_equal(weather.day_temperature_tenths(), 120, "the day's own temperature is kept")
	weather.observe(0, night, 6, 120, 1200, CoreWeather.EVENT_NONE)
	assert_equal(weather.condition(), WeatherScript.COND_RAIN, "morning: the spell's rain, not frost")
	weather.observe(0, night + 1, 2, 120, 1200, CoreWeather.EVENT_NONE)
	assert_equal(weather.condition(), WeatherScript.COND_CLEAR, "the next night is no frost night")


func test_a_change_of_condition_bumps_the_revision_once() -> void:
	"""Unbound it opens clear at 06:00 of spring 1; a new condition bumps the revision, the same one
	again does not."""
	var weather := WeatherScript.new()
	assert_false(weather.is_bound(), "unbound")
	assert_equal(weather.revision, 0, "opening")
	assert_equal(weather.condition(), WeatherScript.COND_CLEAR, "spring 1, 06:00")
	assert_true(weather.observe(0, 2, 12, 120, 1200, CoreWeather.EVENT_NONE), "the spell's showers start")
	assert_false(weather.observe(0, 2, 13, 120, 1200, CoreWeather.EVENT_NONE), "still raining")
	assert_equal(weather.revision, 1, "one change")
	assert_false(weather.sync(), "unbound: nothing to sync from")


func test_the_weather_speaks() -> void:
	"""The panels' readout and the short line."""
	var weather := WeatherScript.new()
	weather.observe(0, 3, 12, 90, 3200, CoreWeather.EVENT_HEAVY_RAIN)
	assert_equal(weather.readout(),
		"Rain — Spring 3, Heavy rain, 9.0 °C · rain 07:00–22:59 · walking outdoors at 80%, tunnels unaffected", "rain")
	assert_equal(weather.alert_line(), "Rain, walking 80%", "rain's short line")
	weather.observe(3, 1, 12, -50, 0, CoreWeather.EVENT_NONE)
	assert_equal(weather.readout(), "Frost — Winter 1, -5.0 °C · a dry day · walking outdoors at 85%, tunnels unaffected",
		"baseline winter")
	weather.observe(0, 2, 3, 120, 1200, CoreWeather.EVENT_NONE)
	assert_equal(weather.readout(), "Clear — Spring 2, 12.0 °C · rain 06:00–23:59 · walking at full pace", "clear")
	weather.observe(0, 1, 12, 120, 1200, CoreWeather.EVENT_NONE)
	assert_equal(weather.readout(), "Clear — Spring 1, 12.0 °C · a dry day · walking at full pace", "a spell's dry day")
	assert_equal(weather.alert_line(), "Clear", "clear's short line")


# --- the water query ----------------------------------------------------------------------------

func test_the_village_water_wets_the_east_stream_bank() -> void:
	"""The real stream, through the village's water adapter: ground within 4608 u of its waterline is
	wet (x = 19.0 m by the run is; 17.5 m, 4626 u off, is not), the square's middle is dry, and the
	flood spills at the ford's west bank, 8397 u into the village."""
	var water := VillageWaterScript.new()
	assert_true(water.near_water(Rules.to_u(19.0), Rules.to_u(9.0)), "by the run")
	assert_false(water.near_water(Rules.to_u(17.5), Rules.to_u(9.0)), "4626 u off")
	assert_false(water.near_water(0, 0), "the well")
	var ground := GroundScript.new(Rect2i(-20480, -20480, 40960, 40960), water)
	assert_true(ground.wet_at(Rules.to_u(19.0), Rules.to_u(9.0)), "the ground map's east edge is wet")
	assert_false(ground.wet_at(0, 0), "its middle dry")
	assert_equal(water.spill_centre_u(), Vector2i(22427, -895), "the ford's west waterline")
	assert_equal(water.spill_radius_u(), 8397, "its flood's reach")


func test_a_fixture_water_map_is_obeyed_everywhere() -> void:
	"""A fixture pond (1024 u at the origin, with a ford landing) handed to the village's water adapter:
	the adapter's query, the ground's wet cells and the flood's disc all follow it."""
	var map := WaterMapScript.new(1229)
	assert_true(map.add_pond(&"pond", PackedInt32Array([0, 0, 1024, 512]), 184, 512).ok, "pond")
	assert_true(map.add_landing(&"ford_west", Vector2i(1024, 0), 1536).ok, "landing")
	assert_true(map.finalize().ok, "finalized")
	var water := VillageWaterScript.new(map)
	assert_true(water.near_water(5000, 0), "3976 u off the waterline: wet")
	assert_false(water.near_water(5700, 0), "4676 u off: dry")
	var ground := GroundScript.new(Rect2i(-20480, -20480, 40960, 40960), water)
	assert_true(ground.wet_at(512, 512), "the cell by the pond is wet")
	assert_false(ground.wet_at(Rules.to_u(19.0), Rules.to_u(9.0)), "the real stream's bank is dry under the fixture")
	var events := EventsScript.new(water)
	events.trigger()
	var spill := Vector2(Rules.to_m(water.spill_centre_u().x), Rules.to_m(water.spill_centre_u().y))
	assert_equal(events.centre_m(), spill, "the flood spills where the adapter says")
	assert_true(events.covers(spill + Vector2(8.1, 0.0)), "inside the spill")
	assert_false(events.covers(spill + Vector2(8.3, 0.0)), "outside it")


# --- ground -----------------------------------------------------------------------------------

func test_the_authored_ground() -> void:
	"""Patch centres take their type; the real stream's west bank is wet; the square is plain loam."""
	var ground := GroundScript.new()
	assert_equal(ground.columns, 40, "40 columns")
	assert_equal(ground.rows, 40, "40 rows")
	assert_equal(ground.type_at(5632, 1536), GroundScript.ROCK, "rock pocket east of the well")
	assert_equal(ground.type_at(7168, -2048), GroundScript.CLAY, "clay by the cauldron")
	assert_equal(ground.type_at(0, 0), GroundScript.LOAM, "the square")
	assert_false(ground.wet_at(0, 0), "the square is dry")
	assert_equal(ground.type_at(-19968, 10240), GroundScript.SAND, "sand by the reeds")
	assert_false(ground.wet_at(-19968, 10240), "the reeds' sand is dry: the water is east")
	assert_true(ground.wet_at(19456, 9216), "the stream's west bank is wet (4.5 m of the waterline)")
	assert_false(ground.wet_at(17408, 9216), "5140 u off it: dry")


func test_ground_cells_are_found_with_floor_division_and_clamped() -> void:
	"""The cell index is floor((x - origin) / 1024), exact below the origin, clamped into the grid."""
	var ground := GroundScript.new()
	assert_equal(ground.cell_of(-20480, -20480), 0, "the first cell")
	assert_equal(ground.cell_of(-20481, -20480), 0, "left of the grid clamps")
	assert_equal(ground.cell_of(-19456, -20480), 1, "1024 u in: the second cell")
	assert_equal(ground.cell_of(-19457, -20480), 0, "1023 u in: still the first")
	assert_equal(ground.cell_of(20479, 20479), 1599, "the last cell")
	assert_equal(ground.cell_of(99999, 99999), 1599, "beyond it clamps")


func test_the_edge_wobble_is_seeded_and_bounded() -> void:
	"""Every point's wobble lies in [-320, 320] and is the same every time."""
	var seen_low := false
	var seen_high := false
	for x in range(-20000, 20000, 997):
		var w := GroundScript.wobble_u(Vector2i(x, x / 3))
		assert_true(w >= -320 and w <= 320, "bounded at %d" % x)
		assert_equal(GroundScript.wobble_u(Vector2i(x, x / 3)), w, "repeatable at %d" % x)
		seen_low = seen_low or w < 0
		seen_high = seen_high or w > 0
	assert_true(seen_low and seen_high, "it varies both ways")


func test_each_ground_s_dig_work_and_spoil() -> void:
	"""Ticks a quantum (rounded up), where its cut completes, and its spoil and stone."""
	assert_equal(GroundScript.dig_ticks(GroundScript.LOAM), 113, "loam: the cited 113")
	assert_equal(GroundScript.dig_ticks(GroundScript.CLAY), 147, "clay: ceil(146.9)")
	assert_equal(GroundScript.dig_ticks(GroundScript.SAND), 91, "sand: ceil(90.4)")
	assert_equal(GroundScript.dig_ticks(GroundScript.ROCK), 113, "rock with a breaker")
	assert_equal(GroundScript.cut_ticks(GroundScript.LOAM), 75, "loam cut at 25 + 50")
	assert_equal(GroundScript.cut_ticks(GroundScript.CLAY), 98, "clay: ceil(97.5)")
	assert_equal(GroundScript.cut_ticks(GroundScript.SAND), 60, "sand")
	assert_equal(GroundScript.spoil_of(GroundScript.LOAM), 2000, "loam: the cited 2000 milli-U")
	assert_equal(GroundScript.spoil_of(GroundScript.CLAY), 2400, "clay")
	assert_equal(GroundScript.spoil_of(GroundScript.SAND), 1800, "sand")
	assert_equal(GroundScript.spoil_of(GroundScript.ROCK), 1200, "rock")
	assert_equal(GroundScript.stone_of(GroundScript.ROCK), 800, "rock yields stone")
	assert_equal(GroundScript.stone_of(GroundScript.CLAY), 0, "clay none")


# --- the ground-aware dig timeline ----------------------------------------------------------

func test_the_timeline_follows_the_ground() -> void:
	"""Each segment's timeline follows the ground under it. Clay in cells 22, 23 (the entrance ramp's middle
	two metres) and 26 (the bore's second): the ramp is an entry shaft and four bore quanta, 113, 113, 147,
	147, 113 = 633 ticks; the bore four quanta and no shaft, 113 + 147 + 113 + 113 = 486; the exit ramp
	four bore quanta and its exit shaft, all loam, 5 x 113 = 565."""
	var ground := _loam_ground()
	_mark(ground, [22, 23, 26], GroundScript.CLAY)
	var network := _twelve_metres(ground)
	assert_equal([network.timeline_count(RAMP), network.timeline_count(BORE), network.timeline_count(EXIT_RAMP)],
		[5, 4, 5] as Array[int], "a shaft only where a segment meets a mouth")
	var kinds: Array[int] = []
	for k in 5:
		kinds.append(network.quantum_kind(RAMP, k))
	assert_equal(kinds, [0, 0, 1, 1, 0] as Array[int], "clay in the ramp's middle two")
	kinds.clear()
	for k in 4:
		kinds.append(network.quantum_kind(BORE, k))
	assert_equal(kinds, [0, 1, 0, 0] as Array[int], "clay in the bore's second metre")
	assert_equal(network.total_ticks(RAMP), 633, "the ramp's ticks")
	assert_equal(network.total_ticks(BORE), 486, "the bore's ticks")
	assert_equal(network.total_ticks(EXIT_RAMP), 565, "the exit ramp's ticks")


func test_stage_spoil_and_face_on_a_mixed_timeline() -> void:
	"""The entrance ramp (clay in its middle two metres; end ticks 113, 226, 373, 520, 633): the stage turns
	at 113 and the ramp opens at 633 (a ramp dug from its mouth breaks out nowhere: no exit stage); spoil
	posts at mouth 0 as each ground's cut completes; the face moves through a clay quantum at its own pace."""
	var ground := _loam_ground()
	_mark(ground, [22, 23], GroundScript.CLAY)
	var network := _twelve_metres(ground)
	_dig_to(network, RAMP, 112)
	assert_equal(network.stage(RAMP), Rules.STAGE_ENTRANCE, "112 ticks: still the entry shaft")
	_dig_to(network, RAMP, 300)
	assert_equal(network.stage(RAMP), Rules.STAGE_BORE, "300 ticks: the bore")
	assert_equal(network.heaped_milli(0), 4000, "two loam cuts, the clay one not yet (300 - 226 = 74 < 98)")
	assert_equal(network.face_u(RAMP), 1539, "(147 + 74) x 4096 / 588, floored")
	_dig_to(network, RAMP, 324)
	assert_equal(network.heaped_milli(0), 6400, "the clay cut posts 2400 at 98 ticks in")
	assert_equal(network.cut_count(RAMP), 3, "three cuts")
	_dig_to(network, RAMP, 632)
	assert_equal(network.stage(RAMP), Rules.STAGE_BORE, "632: still the bore")
	_dig_to(network, RAMP, 633)
	assert_equal(network.stage(RAMP), Rules.STAGE_OPEN, "633: open")
	assert_equal(network.heaped_milli(0), 10800, "the ramp's heap: 2000 + 2000 + 2400 + 2400 + 2000")


func test_the_exit_ramp_breaks_out_at_its_mouth() -> void:
	"""The exit ramp (four loam bore quanta, then its exit shaft) turns to STAGE_EXIT at 452; the shaft's cut
	heaps at mouth 1, everything before it at the piece's spoil mouth 0: 13 x 2000 there, 2000 at the exit."""
	var network := _twelve_metres(_loam_ground())
	_open(network, RAMP)
	_open(network, BORE)
	network.start_dig(EXIT_RAMP, network.generation[EXIT_RAMP], 0)
	_dig_to(network, EXIT_RAMP, 451)
	assert_equal(network.stage(EXIT_RAMP), Rules.STAGE_BORE, "451: the exit ramp's bore")
	_dig_to(network, EXIT_RAMP, 452)
	assert_equal(network.stage(EXIT_RAMP), Rules.STAGE_EXIT, "452: its exit shaft")
	assert_equal(network.heaped_milli(1), 0, "the exit shaft's cut completes 75 ticks in")
	_dig_to(network, EXIT_RAMP, 527)
	assert_equal(network.heaped_milli(1), 2000, "527: cut")
	_open(network, EXIT_RAMP)
	assert_equal(network.heaped_milli(0), 26000, "the entrance heap: the ramp's 5, the bore's 4, the exit ramp's 4")
	assert_equal(network.heaped_milli(1), 2000, "the exit heap: the exit shaft")


func _dig_piece_to(network: GraphScript, chain: PackedInt32Array, ticks: int) -> void:
	"""Dig the piece whose segments are `chain` (in dig order) until `ticks` of it are dug, segment by
	segment, each taken up once the one before it is open."""
	var before := 0
	for slot in chain:
		var want := clampi(ticks - before, 0, network.total_ticks(slot))
		if want > network.done(slot):
			network.start_dig(slot, network.generation[slot], 0)
			_dig_to(network, slot, want)
		before += network.total_ticks(slot)


func _piece_stage_and_face(network: GraphScript, chain: PackedInt32Array) -> Vector2i:
	"""The piece's stage (the first unopened segment's, or STAGE_OPEN) and its face along the whole piece
	(the open segments' lengths and that segment's face), in u."""
	var along := 0
	for slot in chain:
		if not network.is_open(slot):
			return Vector2i(network.stage(slot), along + network.face_u(slot))
		along += network.length_u[slot]
	return Vector2i(Rules.STAGE_OPEN, along)


func test_a_loam_tunnel_keeps_the_uniform_rule_exactly() -> void:
	"""With no ground, a 12 m piece dug end to end -- ramp, bore, ramp: 5 + 4 + 5 = 14 quanta, as the uniform
	rule's shaft + 12 + shaft -- gives, at every tick dug, the uniform rule's stage, face and spoil at each
	end (tunnel_rules.gd stage_of, face_u, spoil_into over 12 quanta and 12288 u)."""
	var network := GraphScript.new()
	var ref := PackedInt32Array([-1, 0, -1])
	assert_true(network.add_into(PackedInt32Array([0, 0, 12288, 0]), 2, 0, ref), "stored")
	var chain := PackedInt32Array()
	network.piece_segments_into(ref[2], chain)
	assert_equal(chain, PackedInt32Array([0, 1, 2]), "three segments in dig order")
	var uniform := PackedInt64Array([0, 0])
	for d in range(0, Rules.total_ticks(12) + 1, 7):
		_dig_piece_to(network, chain, d)
		var sf := _piece_stage_and_face(network, chain)
		assert_equal(sf.x, Rules.stage_of(d, 12), "stage at %d" % d)
		assert_equal(sf.y, Rules.face_u(d, 12, 12288), "face at %d" % d)
		Rules.spoil_into(d, 12, uniform)
		assert_equal(PackedInt64Array([network.heaped_milli(0), network.heaped_milli(1)]), uniform, "spoil at %d" % d)


func test_rock_yields_stone() -> void:
	"""Two rock metres in the bore (cells 26, 27) yield 1600 milli-U of stone and 1200 milli-U of earth
	each: the bore posts 2000 x 2 + 1200 x 2 at the entrance, which heaps 10000 + 6400 + 8000 in all."""
	var ground := _loam_ground()
	_mark(ground, [26, 27], GroundScript.ROCK)
	var network := _twelve_metres(ground)
	_open_piece(network, 0)
	assert_equal(network.stone_milli_u(BORE), 1600, "two rock quanta")
	assert_equal(network.stone_milli_u(RAMP), 0, "the ramps are loam")
	assert_equal(network.posted_in[BORE], 6400, "the bore's spoil")
	assert_equal(network.heaped_milli(0), 24400, "the entrance heap")


func test_a_crew_rate_credits_work_exactly() -> void:
	"""At 1506 per mille, 1 s credits 1,506,000 usec; 7 usec twice credits 21 with 84 left over."""
	var network := _twelve_metres(_loam_ground())
	network.set_rate(RAMP, 1506)
	network.advance(RAMP, network.generation[RAMP], 1000000)
	assert_equal(network.dig_usec[RAMP], 1506000, "one second at 1506")
	assert_equal(network.done(RAMP), 45, "45 ticks")
	network.dig_usec[RAMP] = 0
	network.advance(RAMP, network.generation[RAMP], 7)
	assert_equal(network.dig_usec[RAMP], 10, "10 of 10.542")
	assert_equal(network.dig_rem[RAMP], 542, "remainder kept")
	network.advance(RAMP, network.generation[RAMP], 7)
	assert_equal(network.dig_usec[RAMP], 21, "21 of 21.084")
	assert_equal(network.dig_rem[RAMP], 84, "remainder")


func test_a_route_out_of_its_lengths_is_refused_whole() -> void:
	"""A route over MAX_LENGTH_U (its timeline would not fit) or under two ramps' run (8192 u) is not stored.
	At 65536 u: a 4 m ramp, a 56 m bore and a 4 m ramp -- 5 + 56 + 5 = 66 quanta, the old 64 and two
	shafts; at exactly 8192 u, two ramps sharing a foot, 5 quanta each."""
	var ref := PackedInt32Array([-1, 0, -1])
	assert_false(GraphScript.new().add_into(PackedInt32Array([0, 0, 65537, 0]), 2, 0, ref), "65537 u refused")
	assert_false(GraphScript.new().add_into(PackedInt32Array([0, 0, 8191, 0]), 2, 0, ref), "8191 u refused")
	var network := GraphScript.new()
	assert_true(network.add_into(PackedInt32Array([0, 0, 65536, 0]), 2, 0, ref), "65536 u stored")
	var chain := PackedInt32Array()
	network.piece_segments_into(ref[2], chain)
	var counts: Array[int] = []
	for slot in chain:
		counts.append(network.timeline_count(slot))
	assert_equal(counts, [5, 56, 5] as Array[int], "ramp, 56 m bore, ramp")
	var short := GraphScript.new()
	assert_true(short.add_into(PackedInt32Array([0, 0, 8192, 0]), 2, 0, ref), "8192 u stored")
	short.piece_segments_into(ref[2], chain)
	assert_equal(chain.size(), 2, "two ramps")
	assert_equal([short.seg_kind[chain[0]], short.seg_kind[chain[1]]], [GraphScript.SEG_RAMP, GraphScript.SEG_RAMP], "both ramps")
	assert_equal(short.node_b[chain[0]], short.node_a[chain[1]], "sharing a foot")
	assert_equal(short.timeline_count(chain[0]) + short.timeline_count(chain[1]), 10, "5 quanta each")


func test_progress_of_a_widening_pass() -> void:
	"""A widening digs each quantum five times over: after 565 ticks of the 4 m loam bore, five cuts
	(10000 milli-U) and the second quantum starting; 75 more, a sixth cut."""
	var network := _twelve_metres(_loam_ground())
	_open_piece(network, 0)
	var out := PackedInt64Array()
	out.resize(GraphScript.P_SIZE)
	assert_equal(network.pass_ticks(BORE, 5), 2260, "4 quanta x 113 x 5")
	network.progress_into(BORE, 565, 5, out)
	assert_equal(out[GraphScript.P_CUTS], 5, "five cuts")
	assert_equal(out[GraphScript.P_SPOIL], 10000, "their spoil")
	assert_equal(out[GraphScript.P_QUANTUM], 1, "the second quantum")
	assert_equal(out[GraphScript.P_INTO], 0, "just begun")
	network.progress_into(BORE, 640, 5, out)
	assert_equal(out[GraphScript.P_CUTS], 6, "a sixth cut at 75 in")
	network.progress_into(BORE, 639, 5, out)
	assert_equal(out[GraphScript.P_CUTS], 5, "not at 74 in")


# --- bore classes and loaded fit --------------------------------------------------------------

func test_who_fits_which_bore_loaded_or_not() -> void:
	"""A mouse fits a standard bore loaded; an otter only a wide one; the badger a wide one unloaded,
	and none loaded (MOVE-REQ-005 names the failed dimension). Fit is judged per segment's bore class."""
	var network := _twelve_metres(_loam_ground())
	network.set_body(0, 1024, 225)
	network.set_body(1, 1526, 336)
	network.set_body(2, 2611, 574)
	assert_equal(network.fit_refusal(0, 0, true), Rules.FIT_OK, "mouse hauling, standard")
	assert_equal(network.fit_refusal(1, 0, false), Rules.FIT_TOO_TALL, "otter, standard")
	assert_equal(network.fit_refusal(2, 0, false), Rules.FIT_TOO_WIDE, "badger, standard")
	network.set_bore(0, Rules.BORE_WIDE)
	assert_equal(network.fit_refusal(1, 0, true), Rules.FIT_OK, "otter hauling, wide")
	assert_equal(network.fit_refusal(2, 0, false), Rules.FIT_OK, "badger, wide")
	assert_equal(network.fit_refusal(2, 0, true), Rules.FIT_TOO_WIDE, "badger hauling, wide")
	assert_equal(network.fit_refusal(2, BORE, false), Rules.FIT_TOO_WIDE, "the next segment is still standard")
	assert_equal(network.fit_refusal(9, 0, false), Rules.FIT_TOO_WIDE, "an unknown resident fits nothing")


func test_loaded_width_boundaries() -> void:
	"""Loaded width is ceil(850 per mille of height), never less than the body."""
	assert_equal(Rules.loaded_width_u(1024, 225), 871, "mouse")
	assert_equal(Rules.loaded_width_u(100, 225), 450, "the body is wider")
	assert_equal(Rules.fit_refusal_in(2409, 2048, Rules.BORE_WIDE), Rules.FIT_OK, "2048 wide fits a wide bore")
	assert_equal(Rules.fit_refusal_in(2409, 2049, Rules.BORE_WIDE), Rules.FIT_TOO_WIDE, "2049 does not")
	assert_equal(Rules.fit_refusal_in(3614, 100, Rules.BORE_WIDE), Rules.FIT_OK, "stooped 3072 fits")
	assert_equal(Rules.fit_refusal_in(3615, 100, Rules.BORE_WIDE), Rules.FIT_TOO_TALL, "stooped 3073 does not")


func test_closing_and_reopening() -> void:
	"""A closed segment is open but not usable; reopened, it is usable again; each change bumps the
	revision. Closing one segment leaves the rest of its piece usable."""
	var network := _twelve_metres(_loam_ground())
	_open_piece(network, 0)
	var before := network.revision
	assert_true(network.is_usable(BORE), "open and whole")
	network.close(BORE, GraphScript.CLOSED_COLLAPSED, 1024, 2048)
	assert_true(network.is_open(BORE), "still a finished segment")
	assert_false(network.is_usable(BORE), "but closed")
	assert_true(network.is_usable(RAMP) and network.is_usable(EXIT_RAMP), "its ramps are not")
	assert_equal(network.closed_from_u[BORE], 1024, "section from")
	network.reopen(BORE)
	assert_true(network.is_usable(BORE), "reopened")
	assert_equal(network.revision, before + 2, "two changes")
	network.set_lit(BORE)
	assert_equal(network.speed_permille(BORE), 1100, "a lit bore is quicker")
	assert_equal(network.speed_permille(RAMP), 1000, "only where the lanterns hang")


# --- planning: weather, lanterns, queues ------------------------------------------------------

func _field() -> CastSpaceScript:
	"""An open field with one 8 m tunnel from (-4, 0) to (4, 0) -- two 4 m ramps sharing a foot at the
	origin: slots 0 and 1, mouth rows 0 (west) and 1 (east) -- and one walker who fits it."""
	var space := CastSpaceScript.new()
	space.setup([], [])
	var ref := PackedInt32Array([-1, 0, -1])
	assert_true(space.tunnels.add_into(PackedInt32Array([-4096, 0, 4096, 0]), 2, 99, ref), "fixture tunnel stored")
	_open_piece(space.tunnels, ref[2])
	space.add_resident(Vector2(-5.0, 0.0), 0.25)
	space.tunnels.set_fit(0, true)
	return space


func _crosses(space: CastSpaceScript) -> bool:
	"""Whether the walker's plan from (-5, 0) to (5, 0) goes through the tunnel."""
	var out := PackedVector2Array()
	var legs := PackedInt32Array()
	space.plan_path(0, Vector2(-5.0, 0.0), Vector2(5.0, 0.0), 0.25, out, legs)
	return legs.count(-1) != legs.size()


func test_rain_sends_a_walker_through_a_tunnel_the_sun_does_not() -> void:
	"""10 m on foot against 1 + 8 + 1 through the tunnel: a tie keeps the surface; at 800 per mille
	the surface costs 12.5 against 1.25 + 8 + 1.25 = 10.5 below."""
	var space := _field()
	assert_false(_crosses(space), "sun: a tie keeps the surface")
	space.tunnels.surface_permille = 800
	assert_true(_crosses(space), "rain: the tunnel")


func test_lanterns_and_queues_weigh_on_the_plan() -> void:
	"""Lit through (both ramps), the tunnel costs 8 x 1000 / 1100 and wins in the sun (9.27 < 10); one
	walker queued at its entrance adds 3 m and it loses again; a full line closes that way in."""
	var space := _field()
	space.tunnels.set_lit(0)
	assert_true(_crosses(space), "one ramp lit is enough already: 4 / 1.1 + 4 + 2 = 9.64 < 10")
	space.tunnels.set_lit(1)
	assert_true(_crosses(space), "lit: 9.27 < 10")
	assert_true(space.tunnels.queue.join(0, 5), "someone queues at the entrance")
	assert_false(_crosses(space), "queued: 12.27 > 10")
	space.tunnels.surface_permille = 600
	assert_true(_crosses(space), "snow: 16.7 on foot > 3.33 + 7.27 + 3")
	for k in range(6, 9):
		space.tunnels.queue.join(0, k)
	assert_false(_crosses(space), "a full line: no way in there")


# --- mouth queues -----------------------------------------------------------------------------

func test_a_line_forms_and_moves_up() -> void:
	"""Joining, places, the head's grant and leaving."""
	var queue := QueueScript.new()
	assert_true(queue.join(3, 10), "first")
	assert_true(queue.join(3, 11), "second")
	assert_true(queue.join(3, 10), "already in: kept")
	assert_equal(queue.count[3], 2, "two in line")
	assert_equal(queue.position_of(3, 11), 1, "second place")
	assert_false(queue.may_take(3, 11, true), "not the head")
	assert_true(queue.may_take(3, 10, true), "the head, the mouth clear")
	assert_false(queue.may_take(3, 10, false), "not while the mouth is busy")
	queue.take(3, 10)
	assert_true(queue.holds_grant(3, 10), "grant held")
	assert_equal(queue.position_of(3, 11), 0, "moved up")
	assert_false(queue.may_take(3, 11, true), "someone else holds the grant")
	queue.release_grant(10)
	assert_true(queue.may_take(3, 11, true), "grant given up")
	queue.leave(11)
	assert_equal(queue.count[3], 0, "empty")


func test_a_full_line_refuses_and_prices_itself_out() -> void:
	"""Four in line: the fifth is refused and entering there costs INF; one costs 3 m, a grant 3 more."""
	var queue := QueueScript.new()
	assert_equal(queue.wait_m(5), 0.0, "an empty mouth costs nothing")
	queue.join(5, 1)
	assert_equal(queue.wait_m(5), 3.0, "one ahead")
	queue.grant[5] = 9
	assert_equal(queue.wait_m(5), 6.0, "and a grant held")
	for k in range(2, 5):
		queue.join(5, k)
	assert_false(queue.join(5, 7), "the fifth is refused")
	assert_equal(queue.wait_m(5), INF, "full")
	queue.join(6, 8)
	queue.clear_mouth(5)
	assert_equal(queue.count[5], 0, "mouth 5's line cleared")
	assert_equal(queue.grant[5], -1, "and its grant")
	assert_equal(queue.count[6], 1, "another mouth's line kept")


func test_the_line_turns_off_an_obstacle() -> void:
	"""Straight out when clear; the first clear turn (30 degrees) when straight out is blocked."""
	var queue := QueueScript.new()
	queue.lay_out(0, Vector2(1.0, 1.0), Vector2(1.0, 0.0), func(_p: Vector2) -> bool: return true)
	assert_true(queue.place(0, 0).is_equal_approx(Vector2(2.4, 1.0)), "first place 1.4 m out")
	assert_true(queue.place(0, 2).is_equal_approx(Vector2(4.0, 1.0)), "third place 3.0 m out")
	queue.lay_out(1, Vector2.ZERO, Vector2(1.0, 0.0), func(p: Vector2) -> bool: return p.y > 0.1)
	assert_true(queue.line_dir[1].is_equal_approx(Vector2(1.0, 0.0).rotated(0.5236)), "turned 30 degrees")


# --- crews ------------------------------------------------------------------------------------

func test_the_crew_rate_follows_one_worker_per_face() -> void:
	"""One face: 1000, then 1506 (113 / 75) however many more; five faces: one each up to four."""
	assert_equal(CrewScript.pipeline_permille(0, 1), 0, "nobody")
	assert_equal(CrewScript.pipeline_permille(1, 1), 1000, "the Foremole alone")
	assert_equal(CrewScript.pipeline_permille(2, 1), 1506, "a finisher behind")
	assert_equal(CrewScript.pipeline_permille(4, 1), 1506, "no more faces")
	assert_equal(CrewScript.pipeline_permille(9, 1), 1506, "capped at four builders")
	assert_equal(CrewScript.pipeline_permille(4, 5), 4000, "widening: four faces")
	assert_equal(CrewScript.pipeline_permille(4, 3), 3506, "a room: three faces and a finisher")


func test_the_digging_skill_s_arithmetic() -> void:
	"""dig_skills.gd, the GDD's §5.3 arithmetic: a quantum's dig ticks earn ticks x 10 x 60 / 750 XP (loam's
	113: 90, floored from 90.4; clay's 147: 117; an hour's 750 ticks: 600). Moles start at level 3 (45000
	XP, factor 1000 + 50 x 3 = 1150); everyone else at 0 (factor 1000), and learns: a mouse reaches level 1
	(5000 XP) on its 56th loam quantum (55 x 90 = 4950)."""
	assert_equal(SkillsScript.xp_of_ticks(113), 90, "a loam quantum")
	assert_equal(SkillsScript.xp_of_ticks(147), 117, "a clay quantum")
	assert_equal(SkillsScript.xp_of_ticks(750), 600, "an hour at the face: 60 WU x 10")
	var skills := SkillsScript.new()
	skills.set_resident(0, "Mole")
	skills.set_resident(1, "Mouse")
	skills.set_resident(2, "Badger")
	assert_equal(skills.xp[0], 45000, "the mole starts skilled")
	assert_equal([skills.level_of(0), skills.level_of(1), skills.level_of(2)], [3, 0, 0], "levels")
	assert_equal([skills.factor_permille(0), skills.factor_permille(1)], [1150, 1000], "skill factors")
	assert_equal(skills.factor_permille(9), 1000, "no such resident: level 0")
	assert_equal(skills.line_of(0), "Digging 3 · XP 45000/80000", "the party panel's line")
	assert_equal(skills.short_of(0), "dig 3", "and its short form")
	for k in 55:
		assert_false(skills.add_ticks(1, 113), "quantum %d: no level yet" % (k + 1))
	assert_equal(skills.xp[1], 4950, "55 x 90")
	assert_true(skills.add_ticks(1, 113), "the 56th: level 1")
	assert_equal(skills.factor_permille(1), 1050, "1000 + 50")
	assert_false(skills.add_ticks(1, 0), "no work, nothing learnt")


func test_rock_needs_a_breaker() -> void:
	"""The mole alone in rock crawls at 250 per mille of its rate -- 1150 (its level 3) x 250 / 1000 = 287;
	a badger at its post restores it: 1150 alone, 1506 x 1150 / 1000 = 1731 with a finisher behind."""
	var crew := CrewScript.new()
	crew.set_resident(0, "Mole")
	crew.set_resident(1, "Badger")
	assert_equal(crew.rate_permille(0, 0, 1, GroundScript.ROCK, _yes), 287, "alone in rock")
	assert_equal(crew.rate_permille(0, 0, 1, GroundScript.LOAM, _yes), 1150, "alone in loam")
	assert_true(crew.join(1, 0), "the badger joins")
	assert_equal(crew.rate_permille(0, 0, 1, GroundScript.ROCK, _no), 287, "not at its post yet")
	crew.set_present(1, true)
	assert_equal(crew.rate_permille(0, 0, 1, GroundScript.ROCK, _no), 1150, "cracking rock; a surface hand adds no face")
	assert_equal(crew.rate_permille(0, 0, 1, GroundScript.ROCK, _yes), 1731, "one who fits finishes behind")


func test_the_foremole_s_skill_quickens_the_crew() -> void:
	"""The Foremole's skill factor scales the crew (1000 + 50 x level): a mouse leading (level 0) digs loam
	at 1000, a mole (level 3) at 1150, a mole at level 4 (80000 XP) at 1200 -- and rock alone at a quarter,
	1200 x 250 / 1000 = 300; with a finisher behind, 1506 x 1200 / 1000 = 1807."""
	var crew := CrewScript.new()
	crew.set_resident(0, "Mole")
	crew.set_resident(1, "Mouse")
	assert_equal(crew.rate_permille(0, 1, 1, GroundScript.LOAM, _yes), 1000, "a mouse leads at 1000")
	assert_equal(crew.rate_permille(0, 0, 1, GroundScript.LOAM, _yes), 1150, "a mole at 1150")
	crew.skills.xp[0] = 80000
	assert_equal(crew.rate_permille(0, 0, 1, GroundScript.LOAM, _yes), 1200, "level 4")
	assert_equal(crew.rate_permille(0, 0, 1, GroundScript.ROCK, _yes), 300, "rock alone: 1200 x 250 / 1000")
	crew.join(1, 0)
	crew.set_present(1, true)
	assert_equal(crew.rate_permille(0, 0, 1, GroundScript.LOAM, _yes), 1807, "with a finisher")


func test_a_crew_holds_three_besides_the_foremole() -> void:
	"""Joins in order, refuses a fourth, and moves up on leaving; the crew follows its dig on into the next
	segment."""
	var crew := CrewScript.new()
	for i in 6:
		crew.set_resident(i, "Mouse")
	assert_true(crew.join(1, 2), "first")
	assert_true(crew.join(2, 2), "second")
	assert_true(crew.join(3, 2), "third")
	assert_false(crew.join(4, 2), "full")
	assert_false(crew.join(3, 2), "already on it")
	assert_equal(crew.member_rank[3], 2, "third place")
	crew.leave(1)
	assert_equal(crew.member_rank[3], 1, "moved up")
	assert_equal(crew.count_of(2), 2, "two left")
	crew.move_site(2, 3)
	assert_equal(crew.count_of(3), 2, "moved on with the dig")
	assert_equal(crew.member_rank[3], 1, "each in its place")
	crew.disband(3)
	assert_equal(crew.count_of(3), 0, "disbanded")


func test_skill_is_credited_to_the_face() -> void:
	"""A quantum's ticks credit the Foremole and each member at the face who fits (113 ticks: 90 XP each);
	a member away from its post, or one who does not fit, learns nothing; a new level of the Foremole's is
	reported."""
	var crew := CrewScript.new()
	for i in 3:
		crew.set_resident(i, "Mouse")
	crew.join(1, 0)
	crew.set_present(1, true)
	crew.join(2, 0)
	assert_false(crew.credit_ticks(0, 0, 113, _yes), "90 XP: no level yet")
	assert_equal([crew.skills.xp[0], crew.skills.xp[1], crew.skills.xp[2]], [90, 90, 0], "the lead and the member at the face")
	assert_false(crew.credit_ticks(0, 0, 113, _no), "a member who does not fit learns nothing")
	assert_equal(crew.skills.xp[1], 90, "unchanged")
	crew.skills.xp[0] = 4910
	assert_true(crew.credit_ticks(0, 0, 113, _yes), "4910 + 90 = 5000: level 1")
	assert_false(crew.credit_ticks(0, 0, 0, _yes), "no work")
	assert_false(crew.credit_ticks(0, 9, 113, _yes), "no such Foremole")


# --- stores and finds -------------------------------------------------------------------------

func test_the_demo_stores_pay_all_or_nothing() -> void:
	"""40 U of wood and 20 of stone to start; a spend too big for either takes nothing."""
	var stores := StoresScript.new()
	assert_equal(stores.wood_milli_u, 40000, "wood")
	assert_equal(stores.stone_milli_u, 20000, "stone")
	assert_false(stores.pay(1000, 20001), "stone short")
	assert_equal(stores.wood_milli_u, 40000, "no wood taken")
	assert_true(stores.pay(1750, 1750), "brace a 7-quantum tunnel")
	assert_equal(StoresScript.units_text(stores.wood_milli_u), "38.2 U", "38.25 floored to a tenth")
	assert_false(stores.pay(-1, 0), "no negative spend")
	stores.add_stone(-5)
	assert_equal(stores.stone_milli_u, 18250, "no negative income")
	assert_equal(StoresScript.units_text(999), "0.9 U", "under a unit")
	assert_equal(stores.finds_line(), "Finds: 0 flint · 0 clay · 0 root stores · 0 relics", "nothing yet")
	stores.add_find(FindsScript.FIND_ROOT_STORE)
	stores.add_find(FindsScript.FIND_RELIC)
	assert_equal(stores.finds_line(), "Finds: 0 flint · 0 clay · 1 root store · 1 relic\n" + FindsScript.relic_story(1),
		"one of each, and the relic's story")


func test_find_tables_at_their_boundaries() -> void:
	"""Loam: flint below 600, clay below 900, a root store below 1400, a relic below 1460; rock: flint
	below 2500, a relic below 2600."""
	var loam := GroundScript.LOAM
	assert_equal(FindsScript.find_for(0, loam), FindsScript.FIND_FLINT, "0")
	assert_equal(FindsScript.find_for(599, loam), FindsScript.FIND_FLINT, "599")
	assert_equal(FindsScript.find_for(600, loam), FindsScript.FIND_CLAY, "600")
	assert_equal(FindsScript.find_for(1399, loam), FindsScript.FIND_ROOT_STORE, "1399")
	assert_equal(FindsScript.find_for(1459, loam), FindsScript.FIND_RELIC, "1459")
	assert_equal(FindsScript.find_for(1460, loam), FindsScript.FIND_NONE, "1460")
	assert_equal(FindsScript.find_for(2499, GroundScript.ROCK), FindsScript.FIND_FLINT, "rock 2499")
	assert_equal(FindsScript.find_for(2500, GroundScript.ROCK), FindsScript.FIND_RELIC, "rock 2500")
	assert_equal(FindsScript.find_for(2600, GroundScript.ROCK), FindsScript.FIND_NONE, "rock 2600")


func test_each_metre_is_rolled_once_per_layer() -> void:
	"""The same cell and layer always roll the same; a metre dug twice yields nothing more."""
	var finds := FindsScript.new(1600)
	var first := FindsScript.roll(845, 0)
	assert_equal(FindsScript.roll(845, 0), first, "seeded")
	assert_true(first >= 0 and first < 10000, "in range")
	assert_true(finds.claim(845, FindsScript.LAYER_BORE), "first time")
	assert_false(finds.claim(845, FindsScript.LAYER_BORE), "second time")
	assert_true(finds.claim(845, FindsScript.LAYER_WIDEN), "another layer")
	assert_false(finds.claim(1600, 0), "off the grid")
	assert_equal(finds.dig(845, FindsScript.LAYER_BORE, GroundScript.ROCK), FindsScript.FIND_NONE, "already rolled")
	assert_equal(FindsScript.relic_story(8), FindsScript.relic_story(1), "the stories cycle every seven")
	assert_true(FindsScript.relic_story(7) != FindsScript.relic_story(1), "the seventh is its own (the banner)")


func test_the_village_s_rock_pocket_holds_a_relic() -> void:
	"""Cell (25, 20) -- 5..6 m east, 0..1 m south of the square, in the rock pocket -- yields a relic in
	the bore layer (the demo's scripted run digs through it)."""
	var ground := GroundScript.new()
	var cell := 20 * ground.columns + 25
	assert_equal(ground.cells[cell] & GroundScript.TYPE_MASK, GroundScript.ROCK, "rock")
	assert_equal(FindsScript.find_for(FindsScript.roll(cell, FindsScript.LAYER_BORE), GroundScript.ROCK),
		FindsScript.FIND_RELIC, "a relic")


# --- jobs -------------------------------------------------------------------------------------

func _job_site() -> Array:
	"""The standard 12 m loam tunnel dug open, its jobs and stores: [network, jobs, stores]. The jobs
	below work its level BORE (slot 1): 4 m, four quanta and no shaft."""
	var network := _twelve_metres(_loam_ground())
	_open_piece(network, 0)
	var stores := StoresScript.new()
	return [network, JobsScript.new(network, stores), stores]


func test_what_each_job_costs_and_takes() -> void:
	"""On the 4 m bore (4 quanta): brace 1000 wood + 1000 stone and 100 ticks; one lantern 500 wood
	and 60; pumping 120; widening 2260. The entrance ramp (5 quanta, its shaft counted) braces for 1250 +
	1250 in 125 ticks."""
	var site := _job_site()
	var jobs: JobsScript = site[1]
	var cost := PackedInt32Array([0, 0])
	jobs.cost_into(BORE, JobsScript.JOB_BRACE, cost)
	assert_equal(cost, PackedInt32Array([1000, 1000]), "brace")
	jobs.cost_into(RAMP, JobsScript.JOB_BRACE, cost)
	assert_equal(cost, PackedInt32Array([1250, 1250]), "brace the ramp")
	jobs.cost_into(BORE, JobsScript.JOB_LANTERNS, cost)
	assert_equal(cost, PackedInt32Array([500, 0]), "lanterns")
	jobs.cost_into(BORE, JobsScript.JOB_WIDEN, cost)
	assert_equal(cost, PackedInt32Array([0, 0]), "widening costs only work")
	assert_equal(jobs.ticks_for(BORE, JobsScript.JOB_BRACE), 100, "brace work")
	assert_equal(jobs.ticks_for(RAMP, JobsScript.JOB_BRACE), 125, "the ramp's brace work")
	assert_equal(jobs.ticks_for(BORE, JobsScript.JOB_LANTERNS), 60, "lantern work")
	assert_equal(jobs.ticks_for(BORE, JobsScript.JOB_PUMP), 120, "pumping")
	assert_equal(jobs.ticks_for(BORE, JobsScript.JOB_WIDEN), 2260, "widening")


func test_inputs_are_paid_once_at_the_start() -> void:
	"""Brace pays 1000 + 1000 as it starts, once; short stores refuse and take nothing."""
	var site := _job_site()
	var jobs: JobsScript = site[1]
	var stores: StoresScript = site[2]
	jobs.post(BORE, JobsScript.JOB_BRACE, 4, 0, 4096)
	jobs.work(BORE, 1000000)
	assert_equal(jobs.done_ticks(BORE), 0, "no work before the start is paid")
	assert_true(jobs.start(BORE), "paid")
	assert_true(jobs.start(BORE), "again: already paid")
	assert_equal(stores.wood_milli_u, 39000, "wood once")
	var other := _job_site()
	var poor: StoresScript = other[2]
	poor.wood_milli_u = 999
	(other[1] as JobsScript).post(BORE, JobsScript.JOB_BRACE, 4, 0, 4096)
	assert_false((other[1] as JobsScript).start(BORE), "short")
	assert_equal(poor.wood_milli_u, 999, "nothing taken")
	assert_equal(poor.stone_milli_u, 20000, "nothing taken")


func test_work_moves_along_and_finishes() -> void:
	"""30 of 100 brace ticks: 30%, 1228 u along (4096 x 30 / 100, floored); done, the segment is braced
	and the job cleared -- and only that segment."""
	var site := _job_site()
	var network: GraphScript = site[0]
	var jobs: JobsScript = site[1]
	jobs.post(BORE, JobsScript.JOB_BRACE, 4, 0, 4096)
	jobs.start(BORE)
	jobs.work(BORE, 1000000)
	assert_equal(jobs.percent(BORE), 30, "30%")
	assert_equal(Rules.to_u(jobs.along_m(BORE)), 1228, "4096 x 30 / 100")
	assert_equal(jobs.label(BORE), "Brace — 30%", "label")
	jobs.pause(BORE)
	assert_equal(jobs.label(BORE), "Brace — paused at 30%", "paused, progress kept")
	jobs.post(BORE, JobsScript.JOB_BRACE, 5, 0, 4096)
	assert_equal(jobs.percent(BORE), 30, "resumed with its progress")
	jobs.work(BORE, 3000000)
	assert_true(jobs.is_done(BORE), "done")
	assert_equal(jobs.finish(BORE), JobsScript.JOB_BRACE, "finished a brace")
	assert_equal(network.braced[BORE], 1, "braced")
	assert_equal(network.braced[RAMP] + network.braced[EXIT_RAMP], 0, "its ramps are not")
	assert_false(jobs.has_job(BORE), "cleared")


func test_a_pump_or_a_clearing_reopens_the_tunnel() -> void:
	"""Pumped out, a flooded segment is open to walkers again; cleared, a fallen one is too."""
	var site := _job_site()
	var network: GraphScript = site[0]
	var jobs: JobsScript = site[1]
	network.close(BORE, GraphScript.CLOSED_FLOODED, 0, 4096)
	jobs.post(BORE, JobsScript.JOB_PUMP, 1, 0, 0)
	jobs.start(BORE)
	jobs.work(BORE, 100000000)
	assert_equal(jobs.finish(BORE), JobsScript.JOB_PUMP, "pumped")
	assert_true(network.is_usable(BORE), "open again")
	network.close(BORE, GraphScript.CLOSED_COLLAPSED, 1536, 2560)
	jobs.post(BORE, JobsScript.JOB_CLEAR, 2, 1536, 2560)
	assert_equal(jobs.total[BORE], 226, "the fallen quanta (1536 and 2560 along): 2 x 113")
	jobs.start(BORE)
	jobs.work(BORE, 100000000)
	assert_equal(jobs.finish(BORE), JobsScript.JOB_CLEAR, "cleared")
	assert_true(network.is_usable(BORE), "open again")


func test_a_widening_posts_its_spoil_as_it_cuts_and_widens_the_bore() -> void:
	"""565 ticks: five cuts, 10000 milli-U heaped at the piece's spoil mouth (the entrance, which the dig
	left at 26000), posted once; done: a wide bore, 20 quanta of loam spoil in all."""
	var site := _job_site()
	var network: GraphScript = site[0]
	var jobs: JobsScript = site[1]
	assert_equal(network.heaped_milli(0), 26000, "the dig's entrance heap: 13 quanta")
	jobs.post(BORE, JobsScript.JOB_WIDEN, 6, 0, 4096)
	jobs.start(BORE)
	jobs.work(BORE, 18833334)
	assert_equal(jobs.done_ticks(BORE), 565, "565 ticks")
	assert_equal(jobs.post_cuts(BORE), 5, "five new cuts")
	assert_equal(network.extra_spoil[BORE], 10000, "their spoil")
	assert_equal(network.heaped_milli(0), 36000, "heaped at the entrance")
	assert_equal(jobs.post_cuts(BORE), 0, "posted once")
	jobs.work(BORE, 100000000)
	assert_equal(jobs.finish(BORE), JobsScript.JOB_WIDEN, "finished")
	assert_equal(network.bore[BORE], Rules.BORE_WIDE, "wide")
	assert_equal(network.bore[RAMP], Rules.BORE_STANDARD, "its ramps not")
	assert_equal(network.extra_spoil[BORE], 40000, "20 quanta of loam spoil in all")
	assert_equal(network.heaped_milli(0), 66000, "26000 + 40000")


func test_jobs_on_a_freed_tunnel_are_void() -> void:
	"""A job whose segment was freed -- its piece dropped with not one tick dug -- is no longer that
	segment's, and the whole piece's segments go."""
	var network := GraphScript.new()
	var ref := PackedInt32Array([-1, 0, -1])
	network.add_into(PackedInt32Array([0, 0, 12288, 0]), 2, 0, ref)
	var jobs := JobsScript.new(network, StoresScript.new())
	jobs.post(0, JobsScript.JOB_PUMP, 1, 0, 0)
	jobs.post(2, JobsScript.JOB_PUMP, 1, 0, 0)
	assert_true(jobs.has_job(0) and jobs.has_job(2), "posted")
	network.stop_digging(0, ref[1])
	assert_false(jobs.has_job(0), "void once the slot is freed")
	assert_false(jobs.has_job(2), "and on the rest of the piece")
	assert_equal(network.phase[1], GraphScript.PHASE_FREE, "the piece dropped")


# --- hazards ----------------------------------------------------------------------------------

func _hazard_site() -> Array:
	"""The standard 12 m tunnel dug open, its bore's middle two metres (cells 26, 27) wet sand:
	[network, hazards]. The hazards below strike the BORE (slot 1)."""
	var ground := _loam_ground()
	_mark(ground, [26, 27], GroundScript.SAND | GroundScript.WET_BIT)
	var network := _twelve_metres(ground)
	_open_piece(network, 0)
	var hazards := HazardsScript.new(network)
	for slot in 3:
		hazards.survey(slot)
	return [network, hazards]


func test_a_survey_counts_wet_and_weak_quanta_and_places_the_fall() -> void:
	"""The bore: two wet, two weak; the fall covers the sand run, 1536..2560 u along (its second and third
	quanta's middles). The loam ramps: nothing to fear."""
	var site := _hazard_site()
	var hazards: HazardsScript = site[1]
	assert_equal(hazards.wet_quanta[BORE], 2, "wet")
	assert_equal(hazards.weak_quanta[BORE], 2, "weak")
	assert_equal(hazards.fall_from_u[BORE], 1536, "fall from")
	assert_equal(hazards.fall_to_u[BORE], 2560, "fall to")
	assert_true(hazards.in_fall(BORE, 1.5), "under it")
	assert_false(hazards.in_fall(BORE, 0.9), "short of it")
	assert_false(hazards.in_fall(BORE, 3.2), "past it")
	assert_false(hazards.exposed(RAMP) or hazards.exposed(EXIT_RAMP), "the ramps are dry loam")


func test_rain_seeps_in_warns_at_half_and_floods_at_forty_seconds() -> void:
	"""20 s of rain warns (once); 40 s floods; nothing builds while paused."""
	var site := _hazard_site()
	var hazards: HazardsScript = site[1]
	assert_equal(hazards.update(BORE, 0, true, false, false), HazardsScript.EVENT_NONE, "paused")
	assert_equal(hazards.update(BORE, 19999999, true, false, false), HazardsScript.EVENT_NONE, "just short")
	assert_equal(hazards.update(BORE, 1, true, false, false), HazardsScript.EVENT_SEEP_WARNING, "half")
	assert_equal(hazards.update(BORE, 1, true, false, false), HazardsScript.EVENT_NONE, "warned once")
	assert_equal(hazards.update(BORE, 19999999, true, false, false), HazardsScript.EVENT_FLOODED, "flooded")
	assert_equal(hazards.seep_permille(BORE), 1000, "full")


func test_a_flood_by_the_stream_seeps_four_times_as_fast() -> void:
	"""5 s of a covering flood, no rain, counts as 20."""
	var site := _hazard_site()
	var hazards: HazardsScript = site[1]
	assert_equal(hazards.update(BORE, 5000000, false, true, false), HazardsScript.EVENT_SEEP_WARNING, "20 s worth")
	assert_equal(hazards.strain_usec[BORE], 0, "no rain, no strain")


func test_crossings_strain_a_weak_bore_until_it_falls() -> void:
	"""8 s a crossing: the fifth warns (40 of 75), the tenth brings the fall due (80)."""
	var site := _hazard_site()
	var hazards: HazardsScript = site[1]
	var events: Array[int] = []
	for k in 10:
		events.append(hazards.add_crossing(BORE))
	assert_equal(events, [0, 0, 0, 0, 3, 0, 0, 0, 0, 4] as Array[int], "warn at 5, due at 10")


func test_only_weak_ground_takes_a_crossing_s_strain() -> void:
	"""A bore through wet loam (no sand) seeps in rain but takes no strain from walkers."""
	var ground := _loam_ground()
	_mark(ground, [26, 27], GroundScript.LOAM | GroundScript.WET_BIT)
	var network := _twelve_metres(ground)
	_open_piece(network, 0)
	var hazards := HazardsScript.new(network)
	hazards.survey(BORE)
	assert_equal(hazards.weak_quanta[BORE], 0, "no sand")
	assert_true(hazards.exposed(BORE), "but wet")
	assert_equal(hazards.add_crossing(BORE), HazardsScript.EVENT_NONE, "a crossing")
	assert_equal(hazards.strain_usec[BORE], 0, "no strain")


func test_a_long_sand_run_falls_in_its_middle_three_metres() -> void:
	"""Five sand quanta in the 8 m bore of a 16 m tunnel (its quanta 1..5, cells 26..30): the fall is the
	middle three, the third to the fifth quantum's middles, 2560..4608 u."""
	var ground := _loam_ground()
	_mark(ground, [26, 27, 28, 29, 30], GroundScript.SAND)
	var network := _network_on(ground, [Vector2i(512, 512), Vector2i(16896, 512)])
	_open_piece(network, 0)
	assert_equal(network.length_u[BORE], 8192, "an 8 m bore")
	var hazards := HazardsScript.new(network)
	hazards.survey(BORE)
	assert_equal(hazards.weak_quanta[BORE], 5, "five weak quanta")
	assert_equal(hazards.fall_from_u[BORE], 2560, "from the third quantum's middle")
	assert_equal(hazards.fall_to_u[BORE], 4608, "to the fifth's")


func test_bracing_prevents_both_and_work_pauses_them() -> void:
	"""Braced, nothing builds and what had built is gone; a job in the segment holds both still."""
	var site := _hazard_site()
	var network: GraphScript = site[0]
	var hazards: HazardsScript = site[1]
	hazards.update(BORE, 10000000, true, false, false)
	assert_equal(hazards.update(BORE, 30000000, true, false, true), HazardsScript.EVENT_NONE, "working")
	assert_equal(hazards.seep_usec[BORE], 10000000, "held while working")
	network.set_braced(BORE)
	assert_equal(hazards.update(BORE, 30000000, true, false, false), HazardsScript.EVENT_NONE, "braced")
	assert_equal(hazards.seep_usec[BORE], 0, "cleared")
	assert_equal(hazards.add_crossing(BORE), HazardsScript.EVENT_NONE, "no strain either")
	assert_false(hazards.exposed(BORE), "not exposed")


func test_a_flood_and_a_fall_close_the_tunnel_and_a_repair_resets() -> void:
	"""Flooded end to end (the bore's 4096 u); fallen over the sand; each repair resets only the pressure
	that struck."""
	var site := _hazard_site()
	var network: GraphScript = site[0]
	var hazards: HazardsScript = site[1]
	hazards.flood(BORE)
	assert_equal(network.closed[BORE], GraphScript.CLOSED_FLOODED, "flooded")
	assert_equal(network.closed_to_u[BORE], 4096, "end to end")
	assert_equal(network.closed[RAMP], GraphScript.CLOSED_NONE, "the ramp stays open")
	assert_equal(hazards.update(BORE, 60000000, true, false, false), HazardsScript.EVENT_NONE, "a closed segment builds nothing")
	network.reopen(BORE)
	hazards.collapse(BORE)
	assert_equal(network.closed[BORE], GraphScript.CLOSED_COLLAPSED, "fallen")
	assert_equal(network.closed_from_u[BORE], 1536, "over the sand")
	hazards.seep_usec[BORE] = 5
	hazards.strain_usec[BORE] = 7
	hazards.warned[BORE] = HazardsScript.WARNED_SEEP | HazardsScript.WARNED_STRAIN
	hazards.repaired(BORE, true)
	assert_equal(hazards.seep_usec[BORE], 0, "pumped: the seep is gone")
	assert_equal(hazards.strain_usec[BORE], 7, "the strain kept")
	assert_equal(hazards.warned[BORE], HazardsScript.WARNED_STRAIN, "may be warned of seeping again")
	hazards.repaired(BORE, false)
	assert_equal(hazards.strain_usec[BORE], 0, "cleared: the strain is gone")
	assert_equal(hazards.warned[BORE], 0, "no warnings stand")


# --- threats ----------------------------------------------------------------------------------

func test_threats_come_in_a_seeded_order() -> void:
	"""Flood, fire, flood, flood; each lasts 40 s; one at a time."""
	assert_equal([EventsScript.kind_for(0), EventsScript.kind_for(1), EventsScript.kind_for(2), EventsScript.kind_for(3)],
		[0, 1, 0, 0], "the seeded sequence")
	var events := EventsScript.new()
	assert_true(events.trigger(), "a flood")
	assert_false(events.trigger(), "one at a time")
	assert_equal(events.next_auto_usec, 616254902, "the next comes on its own after 540 s plus a seeded jitter")
	assert_equal(events.advance(0), EventsScript.CHANGE_NONE, "paused")
	assert_equal(events.advance(39999999), EventsScript.CHANGE_NONE, "a microsecond left")
	assert_equal(events.advance(1), EventsScript.CHANGE_ENDED, "over")
	assert_true(events.trigger(), "a fire next")
	assert_equal(events.kind, EventsScript.KIND_FIRE, "fire")


func test_the_first_threat_comes_on_its_own_after_six_minutes() -> void:
	"""360 s of demo time with nothing ordered brings the first."""
	var events := EventsScript.new()
	assert_equal(events.advance(359999999), EventsScript.CHANGE_NONE, "not yet")
	assert_equal(events.advance(1), EventsScript.CHANGE_STARTED, "now")
	assert_equal(events.kind, EventsScript.KIND_FLOOD, "a flood")


func test_the_flood_s_disc_and_shelters() -> void:
	"""The stream's flood spills over the ford's west bank onto the east road but not the square; a
	shelter is 2 m beyond its edge."""
	var events := EventsScript.new()
	assert_false(events.covers(Vector2(17.0, -0.9)), "no threat, nothing covered")
	events.trigger()
	assert_true(events.covers(Vector2(17.0, -0.9)), "the east road by the ford")
	assert_false(events.covers(Vector2(0.0, 0.0)), "the square")
	var shelter := events.shelter_from(events.centre_m() + Vector2(1.0, 0.0))
	assert_true(shelter.is_equal_approx(events.centre_m() + Vector2(events.radius_m() + 2.0, 0.0)), "straight out, 2 m beyond")


func test_nobody_walks_past_a_tunnel_s_way_out_to_its_far_mouth() -> void:
	"""An 8 m tunnel from inside the flood (1.8 m from its spill point; mouth row 0) to just outside it
	(9.8 m; row 1): a resident standing nearer its outer mouth walks out on foot rather than going round
	to the inner mouth (the near mouth must be the nearer of the two)."""
	var events := EventsScript.new()
	events.trigger()
	var network := GraphScript.new()
	var ref := PackedInt32Array([-1, 0, -1])
	assert_true(network.add_into(PackedInt32Array([20582, -922, 12390, -922]), 2, 0, ref), "stored")
	_open_piece(network, ref[2])
	network.set_fit(0, true)
	assert_false(events.covers(network.mouth_at(1)), "the outer mouth is dry")
	assert_true(events.covers(network.mouth_at(0)), "the inner one under water")
	var out := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	assert_false(events.plan_escape(network, 0, Vector2(15.1, -0.9), out), "no escape by that tunnel")


func test_an_escape_goes_through_the_nearest_tunnel_out_of_the_disc() -> void:
	"""From the east road by the ford, in at the near mouth (row 0) of the tunnel whose far mouth (row 1,
	8 m west) is outside the disc, and on to a shelter beyond that far mouth; never down the tunnel whose
	mouths (rows 2 and 3) are both under water, even from nearer it; nobody who fits no bore."""
	var events := EventsScript.new()
	events.trigger()
	var network := GraphScript.new()
	var ref := PackedInt32Array([-1, 0, -1])
	assert_true(network.add_into(PackedInt32Array([17408, -922, 9216, -922]), 2, 0, ref), "the tunnel to the square")
	_open_piece(network, ref[2])
	assert_true(network.add_into(PackedInt32Array([18432, -4096, 18432, 4096]), 2, 0, ref), "the drowned one")
	_open_piece(network, ref[2])
	assert_true(events.covers(network.mouth_at(2)) and events.covers(network.mouth_at(3)), "both its mouths under water")
	network.set_fit(0, true)
	var out := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	assert_true(events.plan_escape(network, 0, Vector2(16.0, -0.9), out), "an escape")
	assert_equal(Vector2i(int(out[0]), int(out[1])), Vector2i(0, 1), "in at the tunnel's east mouth, out at its west")
	assert_true(Vector2(out[2], out[3]).x < 7.1, "a shelter 2 m beyond its far mouth (x 9.0)")
	assert_true(events.plan_escape(network, 0, Vector2(19.0, -2.5), out), "from nearer the drowned tunnel")
	assert_equal(Vector2i(int(out[0]), int(out[1])), Vector2i(0, 1), "still the tunnel out of the disc")
	assert_false(events.plan_escape(network, 5, Vector2(16.0, -0.9), out), "nobody who does not fit")
