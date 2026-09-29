extends "res://test/framework/test_case.gd"
## The live demo's tunnel extensions (decision 0196), as pure integer logic: the weather source, the
## ground map, the ground-aware dig timeline and crew rate, bore classes and loaded fit, the planner's
## weather, lantern and queue costs, mouth queues, jobs, hazards, finds, stores, chambers and threats.
##
## No scene tree and no staged assets. Every expected value is a literal worked out by hand from the
## cited constants (113 ticks and 2000 milli-U a quantum; weather.gd's §5.10 tables; the GDD's
## cellar factor 350 and 12 beds in 40 tiles) and the named demo values. Grounds are synthetic: a
## real ground map with its cells overwritten, so a test controls exactly what each quantum cuts.

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const NetworkScript := preload("res://demo/tunnel/tunnel_network.gd")
const GroundScript := preload("res://demo/tunnel/tunnel_ground.gd")
const WeatherScript := preload("res://demo/weather/demo_weather.gd")
const QueueScript := preload("res://demo/tunnel/tunnel_queue.gd")
const CrewScript := preload("res://demo/tunnel/tunnel_crew.gd")
const JobsScript := preload("res://demo/tunnel/tunnel_jobs.gd")
const StoresScript := preload("res://demo/tunnel/tunnel_stores.gd")
const FindsScript := preload("res://demo/tunnel/tunnel_finds.gd")
const HazardsScript := preload("res://demo/tunnel/tunnel_hazards.gd")
const ChambersScript := preload("res://demo/burrow/burrow_chambers.gd")
const EventsScript := preload("res://demo/events/demo_events.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const WaterMapScript := preload("res://demo/water/water_map.gd")
const VillageWaterScript := preload("res://demo/village_water.gd")
const CoreWeather := preload("res://scripts/core/weather.gd")

## A 4 m route along z = 0.5 m from x = 0.5 m: its six timeline quanta lie in cells 20..24 of row 20.
const ROW: int = 20


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


func _network_on(ground: GroundScript, route: Array[Vector2i]) -> NetworkScript:
	"""A network over `ground` with one tunnel along `route` (u), dug to the end unless the route is
	left DIGGING by the caller (slot 0)."""
	var network := NetworkScript.new()
	network.set_ground(ground)
	var flat := PackedInt32Array()
	for p in route:
		flat.append(p.x)
		flat.append(p.y)
	var ref := PackedInt32Array([-1, 0])
	assert_true(network.add_into(flat, route.size(), 0, ref), "fixture tunnel stored")
	return network


func _four_metres(ground: GroundScript) -> NetworkScript:
	"""The 4 m route of ROW (0.5, 0.5) -> (4.5, 0.5) m, still being dug."""
	return _network_on(ground, [Vector2i(512, 512), Vector2i(4608, 512)])


func _open(network: NetworkScript, slot: int) -> void:
	"""Dig tunnel `slot` to the end."""
	network.advance(slot, network.generation[slot], 1000000000)


# --- weather ----------------------------------------------------------------------------------

func test_every_day_s_climate_is_the_real_table_s() -> void:
	"""The weather holds no climate of its own: fed §5.10's (season, event) days from weather.gd's own
	readers, it reads each at 15:00 (a shower hour for every rainy day) and at 03:00."""
	var table := CoreWeather.new()
	var seasons: Array[int] = [0, 0, 0, 1, 2, 2, 3, 3]
	var events: Array[int] = [CoreWeather.EVENT_NONE, CoreWeather.EVENT_IDEAL_SPELL, CoreWeather.EVENT_HEAVY_RAIN,
		CoreWeather.EVENT_CALM_DAYS, CoreWeather.EVENT_HEAVY_RAIN, CoreWeather.EVENT_EARLY_FROST, CoreWeather.EVENT_NONE,
		CoreWeather.EVENT_HARD_FREEZE]
	var expected_t: Array[int] = [120, 180, 90, 220, 70, -30, -50, -120]
	var expected_r: Array[int] = [1200, 1800, 3200, 300, 2700, 700, 0, 0]
	var at_three: Array[int] = [0, 0, 0, 0, 0, 3, 3, 3]
	var at_fifteen: Array[int] = [1, 1, 1, 1, 1, 2, 3, 3]
	var weather := WeatherScript.new()
	for k in seasons.size():
		var t: int = table.temperature_tenths_for(seasons[k], events[k]).value
		var r: int = table.rain_for(seasons[k], events[k]).value
		weather.observe(seasons[k], 1, 15, t, r, events[k])
		assert_equal(weather.temperature_tenths(), expected_t[k], "temperature of day %d" % k)
		assert_equal(weather.rain(), expected_r[k], "rain of day %d" % k)
		assert_equal(weather.condition(), at_fifteen[k], "15:00 of day %d" % k)
		weather.observe(seasons[k], 1, 3, t, r, events[k])
		assert_equal(weather.condition(), at_three[k], "03:00 of day %d" % k)


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
	"""The one walking query: 1000 clear, 800 rain, 600 snow, 850 frost per mille; only rain is wet."""
	var weather := WeatherScript.new()
	var hours: Array[Vector3i] = [Vector3i(120, 1200, 6), Vector3i(120, 1200, 12), Vector3i(-30, 700, 15),
		Vector3i(-50, 0, 12)]
	var expected: Array[int] = [1000, 800, 600, 850]
	var wet: Array[bool] = [false, true, false, false]
	for k in hours.size():
		weather.observe(0, 1, hours[k].z, hours[k].x, hours[k].y, CoreWeather.EVENT_NONE)
		assert_equal(weather.surface_speed_permille(), expected[k], "hour %d" % k)
		assert_equal(weather.is_wet(), wet[k], "wet %d" % k)


func test_a_frost_night_s_hours_read_as_frost() -> void:
	"""Spring day 4 is a demo frost night: 02:00-05:59 fall to -3.0 C and read as frost; 06:00 is mild."""
	var weather := WeatherScript.new()
	weather.observe(0, 4, 2, 120, 1200, CoreWeather.EVENT_NONE)
	assert_equal(weather.temperature_tenths(), -30, "the frost night's air")
	assert_equal(weather.condition(), WeatherScript.COND_FROST, "frost")
	assert_equal(weather.day_temperature_tenths(), 120, "the day's own temperature is kept")
	weather.observe(0, 4, 6, 120, 1200, CoreWeather.EVENT_NONE)
	assert_equal(weather.condition(), WeatherScript.COND_CLEAR, "morning")
	weather.observe(0, 5, 2, 120, 1200, CoreWeather.EVENT_NONE)
	assert_equal(weather.condition(), WeatherScript.COND_CLEAR, "day 5 is no frost night")


func test_a_change_of_condition_bumps_the_revision_once() -> void:
	"""Unbound it opens clear at 06:00 of spring 1; a new condition bumps the revision, the same one
	again does not."""
	var weather := WeatherScript.new()
	assert_false(weather.is_bound(), "unbound")
	assert_equal(weather.revision, 0, "opening")
	assert_equal(weather.condition(), WeatherScript.COND_CLEAR, "spring 1, 06:00")
	assert_true(weather.observe(0, 1, 12, 120, 1200, CoreWeather.EVENT_NONE), "the showers start")
	assert_false(weather.observe(0, 1, 13, 120, 1200, CoreWeather.EVENT_NONE), "still raining")
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
	weather.observe(0, 1, 6, 120, 1200, CoreWeather.EVENT_NONE)
	assert_equal(weather.readout(), "Clear — Spring 1, 12.0 °C · rain 12:00–17:59 · walking at full pace", "clear")
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
	"""Two clay metres in a 4 m loam route: 113, 113, 147, 147, 113, 113 ticks; 746 in all."""
	var ground := _loam_ground()
	_mark(ground, [22, 23], GroundScript.CLAY)
	var network := _four_metres(ground)
	assert_equal(network.timeline_count(0), 6, "two shafts and four bore quanta")
	var kinds: Array[int] = []
	for k in 6:
		kinds.append(network.quantum_kind(0, k))
	assert_equal(kinds, [0, 0, 1, 1, 0, 0] as Array[int], "clay in the middle two")
	assert_equal(network.total_ticks(0), 746, "total ticks")


func test_stage_spoil_and_face_on_a_mixed_timeline() -> void:
	"""The stage turns at 113, 633 and 746; spoil posts as each ground's cut completes; the face
	moves through a clay quantum at its own pace."""
	var ground := _loam_ground()
	_mark(ground, [22, 23], GroundScript.CLAY)
	var network := _four_metres(ground)
	var spoil := PackedInt64Array([0, 0])
	network.dig_usec[0] = 300 * 1000000 / 30
	assert_equal(network.stage(0), Rules.STAGE_BORE, "300 ticks: the bore")
	network.spoil_into(0, spoil)
	assert_equal(spoil[0], 4000, "two loam cuts, the clay one not yet (74 < 98)")
	assert_equal(network.face_u(0), 1539, "(147 + 74) x 4096 / 588, floored")
	network.dig_usec[0] = 324 * 1000000 / 30
	network.spoil_into(0, spoil)
	assert_equal(spoil[0], 6400, "the clay cut posts 2400 at 98 ticks in")
	assert_equal(network.cut_count(0), 3, "three cuts")
	network.dig_usec[0] = 633 * 1000000 / 30
	assert_equal(network.stage(0), Rules.STAGE_EXIT, "633: the exit shaft")
	_open(network, 0)
	network.spoil_into(0, spoil)
	assert_equal(spoil[0], 10800, "entrance heap: 2000 + 2000 + 2400 + 2400 + 2000")
	assert_equal(spoil[1], 2000, "exit heap: the exit shaft")


func test_a_loam_tunnel_keeps_the_uniform_rule_exactly() -> void:
	"""With no ground, every done count gives the same stage, face and spoil as tunnel_rules."""
	var network := NetworkScript.new()
	var ref := PackedInt32Array([-1, 0])
	network.add_into(PackedInt32Array([0, 0, 5000, 0]), 2, 0, ref)
	var spoil := PackedInt64Array([0, 0])
	var uniform := PackedInt64Array([0, 0])
	for d in range(0, Rules.total_ticks(network.quanta[0]) + 1, 7):
		network.dig_usec[0] = d * 1000000 / 30 + 1
		assert_equal(network.face_u(0), Rules.face_u(d, network.quanta[0], 5000), "face at %d" % d)
		assert_equal(network.stage(0), Rules.stage_of(d, network.quanta[0]), "stage at %d" % d)
		network.spoil_into(0, spoil)
		Rules.spoil_into(d, network.quanta[0], uniform)
		assert_equal(spoil, uniform, "spoil at %d" % d)


func test_rock_yields_stone() -> void:
	"""Two rock metres yield 1600 milli-U of stone and 1200 milli-U of earth each."""
	var ground := _loam_ground()
	_mark(ground, [22, 23], GroundScript.ROCK)
	var network := _four_metres(ground)
	_open(network, 0)
	assert_equal(network.stone_milli_u(0), 1600, "two rock quanta")
	var spoil := PackedInt64Array([0, 0])
	network.spoil_into(0, spoil)
	assert_equal(spoil[0], 8400, "2000 x 3 + 1200 x 2 at the entrance")


func test_a_crew_rate_credits_work_exactly() -> void:
	"""At 1506 per mille, 1 s credits 1,506,000 usec; 7 usec twice credits 21 with 84 left over."""
	var network := _four_metres(_loam_ground())
	network.set_rate(0, 1506)
	network.advance(0, network.generation[0], 1000000)
	assert_equal(network.dig_usec[0], 1506000, "one second at 1506")
	assert_equal(network.done(0), 45, "45 ticks")
	network.dig_usec[0] = 0
	network.advance(0, network.generation[0], 7)
	assert_equal(network.dig_usec[0], 10, "10 of 10.542")
	assert_equal(network.dig_rem[0], 542, "remainder kept")
	network.advance(0, network.generation[0], 7)
	assert_equal(network.dig_usec[0], 21, "21 of 21.084")
	assert_equal(network.dig_rem[0], 84, "remainder")


func test_a_route_longer_than_64_m_is_refused_whole() -> void:
	"""A route over MAX_LENGTH_U is not stored (its timeline would not fit)."""
	var network := NetworkScript.new()
	var ref := PackedInt32Array([-1, 0])
	assert_false(network.add_into(PackedInt32Array([0, 0, 65537, 0]), 2, 0, ref), "65537 u refused")
	assert_true(network.add_into(PackedInt32Array([0, 0, 65536, 0]), 2, 0, ref), "65536 u stored")
	assert_equal(network.timeline_count(0), 66, "64 bore quanta and two shafts")


func test_progress_of_a_widening_pass() -> void:
	"""A widening digs each quantum five times over: after 565 ticks of a 2 m loam tunnel, five cuts
	(10000 milli-U) and the second quantum starting; 75 more, a sixth cut."""
	var network := _network_on(_loam_ground(), [Vector2i(0, 0), Vector2i(2048, 0)])
	_open(network, 0)
	var out := PackedInt64Array()
	out.resize(NetworkScript.P_SIZE)
	assert_equal(network.pass_ticks(0, 5), 2260, "4 quanta x 113 x 5")
	network.progress_into(0, 565, 5, out)
	assert_equal(out[NetworkScript.P_CUTS], 5, "five cuts")
	assert_equal(out[NetworkScript.P_SPOIL], 10000, "their spoil")
	assert_equal(out[NetworkScript.P_QUANTUM], 1, "the second quantum")
	assert_equal(out[NetworkScript.P_INTO], 0, "just begun")
	network.progress_into(0, 640, 5, out)
	assert_equal(out[NetworkScript.P_CUTS], 6, "a sixth cut at 75 in")
	network.progress_into(0, 639, 5, out)
	assert_equal(out[NetworkScript.P_CUTS], 5, "not at 74 in")


# --- bore classes and loaded fit --------------------------------------------------------------

func test_who_fits_which_bore_loaded_or_not() -> void:
	"""A mouse fits a standard bore loaded; an otter only a wide one; the badger a wide one unloaded,
	and none loaded (MOVE-REQ-005 names the failed dimension)."""
	var network := _four_metres(_loam_ground())
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
	"""A closed tunnel is open but not usable; reopened, it is usable again; each change bumps the
	revision."""
	var network := _four_metres(_loam_ground())
	_open(network, 0)
	var before := network.revision
	assert_true(network.is_usable(0), "open and whole")
	network.close(0, NetworkScript.CLOSED_COLLAPSED, 1024, 2048)
	assert_true(network.is_open(0), "still a finished tunnel")
	assert_false(network.is_usable(0), "but closed")
	assert_equal(network.closed_from_u[0], 1024, "section from")
	network.reopen(0)
	assert_true(network.is_usable(0), "reopened")
	assert_equal(network.revision, before + 2, "two changes")
	network.set_lit(0)
	assert_equal(network.speed_permille(0), 1100, "a lit bore is quicker")


# --- planning: weather, lanterns, queues ------------------------------------------------------

func _field() -> CastSpaceScript:
	"""An open field with one 8 m tunnel from (-4, 0) to (4, 0) and one walker who fits it."""
	var space := CastSpaceScript.new()
	space.setup([], [])
	var ref := PackedInt32Array([-1, 0])
	space.tunnels.add_into(PackedInt32Array([-4096, 0, 4096, 0]), 2, 99, ref)
	_open(space.tunnels, 0)
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
	the surface costs 12.5 against 10.5 below."""
	var space := _field()
	assert_false(_crosses(space), "sun: a tie keeps the surface")
	space.tunnels.surface_permille = 800
	assert_true(_crosses(space), "rain: the tunnel")


func test_lanterns_and_queues_weigh_on_the_plan() -> void:
	"""Lit, the tunnel costs 8 x 1000 / 1100 and wins in the sun; one walker queued at its entrance
	adds 3 m and it loses again; a full line closes that way in."""
	var space := _field()
	space.tunnels.set_lit(0)
	assert_true(_crosses(space), "lit: 9.27 < 10")
	assert_true(space.tunnels.queue.join(0, 5), "someone queues at the entrance")
	assert_false(_crosses(space), "queued: 12.27 > 10")
	space.tunnels.surface_permille = 600
	assert_true(_crosses(space), "snow: 16.7 on foot > 12.27")
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
	queue.clear_mouths_of(2)
	assert_equal(queue.count[5], 0, "tunnel 2's lines cleared")
	assert_equal(queue.grant[5], -1, "and its grant")


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
	assert_equal(CrewScript.pipeline_permille(4, 3), 3506, "a chamber: three faces and a finisher")


func test_experience_raises_the_rate_a_little() -> void:
	"""20 per mille per 8 quanta, capped at 100."""
	assert_equal(CrewScript.xp_bonus_permille(7), 0, "7 quanta")
	assert_equal(CrewScript.xp_bonus_permille(8), 20, "8")
	assert_equal(CrewScript.xp_bonus_permille(39), 80, "39")
	assert_equal(CrewScript.xp_bonus_permille(40), 100, "40")
	assert_equal(CrewScript.xp_bonus_permille(4000), 100, "capped")


func test_rock_needs_a_breaker() -> void:
	"""The mole alone in rock crawls at 250 per mille; a badger at its post restores the rate."""
	var crew := CrewScript.new()
	crew.set_resident(0, "Mole")
	crew.set_resident(1, "Badger")
	assert_equal(crew.rate_permille(0, 0, 1, GroundScript.ROCK, _yes), 250, "alone in rock")
	assert_equal(crew.rate_permille(0, 0, 1, GroundScript.LOAM, _yes), 1000, "alone in loam")
	assert_true(crew.join(1, 0), "the badger joins")
	assert_equal(crew.rate_permille(0, 0, 1, GroundScript.ROCK, _no), 250, "not at its post yet")
	crew.set_present(1, true)
	assert_equal(crew.rate_permille(0, 0, 1, GroundScript.ROCK, _no), 1000, "cracking rock; a surface hand adds no face")
	assert_equal(crew.rate_permille(0, 0, 1, GroundScript.ROCK, _yes), 1506, "one who fits finishes behind")


func test_the_foremole_s_experience_quickens_the_crew() -> void:
	"""40 quanta of experience: the Foremole alone digs loam at 1100 per mille, and rock with a breaker
	at 1100 too; without one, a quarter of that."""
	var crew := CrewScript.new()
	crew.set_resident(0, "Mole")
	crew.xp_quanta[0] = 40
	assert_equal(crew.rate_permille(0, 0, 1, GroundScript.LOAM, _yes), 1100, "loam")
	assert_equal(crew.rate_permille(0, 0, 1, GroundScript.ROCK, _yes), 275, "rock alone: 1100 x 250 / 1000")


func test_a_crew_holds_three_besides_the_foremole() -> void:
	"""Joins in order, refuses a fourth, and moves up on leaving."""
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
	crew.disband(2)
	assert_equal(crew.count_of(2), 0, "disbanded")


func test_experience_is_credited_to_the_face() -> void:
	"""Cuts credit the Foremole and members at the face; a step in the Foremole's rate is reported."""
	var crew := CrewScript.new()
	for i in 3:
		crew.set_resident(i, "Mouse")
	crew.join(1, 0)
	crew.set_present(1, true)
	crew.join(2, 0)
	assert_false(crew.credit_quanta(0, 0, 7, _yes), "7: no step yet")
	assert_true(crew.credit_quanta(0, 0, 1, _yes), "8: a step")
	assert_equal(crew.xp_quanta[1], 8, "the member at the face")
	assert_equal(crew.xp_quanta[2], 0, "not one away from its post")
	assert_false(crew.credit_quanta(0, 0, 0, _yes), "no cuts")


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
	assert_equal(FindsScript.relic_story(6), FindsScript.relic_story(1), "the stories cycle every five")


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
	"""An open 2 m loam tunnel, its jobs and stores: [network, jobs, stores]."""
	var network := _network_on(_loam_ground(), [Vector2i(0, 0), Vector2i(2048, 0)])
	_open(network, 0)
	var stores := StoresScript.new()
	return [network, JobsScript.new(network, stores), stores]


func test_what_each_job_costs_and_takes() -> void:
	"""On a 2 m tunnel (4 quanta): brace 1000 wood + 1000 stone and 100 ticks; one lantern 500 wood
	and 60; pumping 120; widening 2260; a loam chamber 1017."""
	var site := _job_site()
	var jobs: JobsScript = site[1]
	var cost := PackedInt32Array([0, 0])
	jobs.cost_into(0, JobsScript.JOB_BRACE, cost)
	assert_equal(cost, PackedInt32Array([1000, 1000]), "brace")
	jobs.cost_into(0, JobsScript.JOB_LANTERNS, cost)
	assert_equal(cost, PackedInt32Array([500, 0]), "lanterns")
	jobs.cost_into(0, JobsScript.JOB_WIDEN, cost)
	assert_equal(cost, PackedInt32Array([0, 0]), "widening costs only work")
	assert_equal(jobs.ticks_for(0, JobsScript.JOB_BRACE), 100, "brace work")
	assert_equal(jobs.ticks_for(0, JobsScript.JOB_LANTERNS), 60, "lantern work")
	assert_equal(jobs.ticks_for(0, JobsScript.JOB_PUMP), 120, "pumping")
	assert_equal(jobs.ticks_for(0, JobsScript.JOB_WIDEN), 2260, "widening")
	jobs.post_chamber(0, 3, 0, 1024, GroundScript.LOAM)
	assert_equal(jobs.total[0], 1017, "a loam chamber")


func test_inputs_are_paid_once_at_the_start() -> void:
	"""Brace pays 1000 + 1000 as it starts, once; short stores refuse and take nothing."""
	var site := _job_site()
	var jobs: JobsScript = site[1]
	var stores: StoresScript = site[2]
	jobs.post(0, JobsScript.JOB_BRACE, 4, 0, 2048)
	jobs.work(0, 1000000)
	assert_equal(jobs.done_ticks(0), 0, "no work before the start is paid")
	assert_true(jobs.start(0), "paid")
	assert_true(jobs.start(0), "again: already paid")
	assert_equal(stores.wood_milli_u, 39000, "wood once")
	var other := _job_site()
	var poor: StoresScript = other[2]
	poor.wood_milli_u = 999
	(other[1] as JobsScript).post(0, JobsScript.JOB_BRACE, 4, 0, 2048)
	assert_false((other[1] as JobsScript).start(0), "short")
	assert_equal(poor.wood_milli_u, 999, "nothing taken")
	assert_equal(poor.stone_milli_u, 20000, "nothing taken")


func test_work_moves_along_and_finishes() -> void:
	"""30 of 100 brace ticks: 30%, 614 u along; done, the tunnel is braced and the job cleared."""
	var site := _job_site()
	var network: NetworkScript = site[0]
	var jobs: JobsScript = site[1]
	jobs.post(0, JobsScript.JOB_BRACE, 4, 0, 2048)
	jobs.start(0)
	jobs.work(0, 1000000)
	assert_equal(jobs.percent(0), 30, "30%")
	assert_equal(Rules.to_u(jobs.along_m(0)), 614, "2048 x 30 / 100")
	assert_equal(jobs.label(0), "Brace — 30%", "label")
	jobs.pause(0)
	assert_equal(jobs.label(0), "Brace — paused at 30%", "paused, progress kept")
	jobs.post(0, JobsScript.JOB_BRACE, 5, 0, 2048)
	assert_equal(jobs.percent(0), 30, "resumed with its progress")
	jobs.work(0, 3000000)
	assert_true(jobs.is_done(0), "done")
	assert_equal(jobs.finish(0), JobsScript.JOB_BRACE, "finished a brace")
	assert_equal(network.braced[0], 1, "braced")
	assert_false(jobs.has_job(0), "cleared")


func test_a_pump_or_a_clearing_reopens_the_tunnel() -> void:
	"""Pumped out, a flooded tunnel is open to walkers again; cleared, a fallen one is too."""
	var site := _job_site()
	var network: NetworkScript = site[0]
	var jobs: JobsScript = site[1]
	network.close(0, NetworkScript.CLOSED_FLOODED, 0, 2048)
	jobs.post(0, JobsScript.JOB_PUMP, 1, 0, 0)
	jobs.start(0)
	jobs.work(0, 100000000)
	assert_equal(jobs.finish(0), JobsScript.JOB_PUMP, "pumped")
	assert_true(network.is_usable(0), "open again")
	network.close(0, NetworkScript.CLOSED_COLLAPSED, 1024, 1024)
	jobs.post(0, JobsScript.JOB_CLEAR, 2, 1024, 1024)
	jobs.start(0)
	jobs.work(0, 100000000)
	assert_equal(jobs.finish(0), JobsScript.JOB_CLEAR, "cleared")
	assert_true(network.is_usable(0), "open again")


func test_a_widening_posts_its_spoil_as_it_cuts_and_widens_the_bore() -> void:
	"""565 ticks: five cuts, 10000 milli-U heaped at the entrance, posted once; done: a wide bore."""
	var site := _job_site()
	var network: NetworkScript = site[0]
	var jobs: JobsScript = site[1]
	jobs.post(0, JobsScript.JOB_WIDEN, 6, 0, 2048)
	jobs.start(0)
	jobs.work(0, 18833334)
	assert_equal(jobs.done_ticks(0), 565, "565 ticks")
	assert_equal(jobs.post_cuts(0), 5, "five new cuts")
	assert_equal(network.extra_spoil[0], 10000, "their spoil")
	assert_equal(jobs.post_cuts(0), 0, "posted once")
	jobs.work(0, 100000000)
	assert_equal(jobs.finish(0), JobsScript.JOB_WIDEN, "finished")
	assert_equal(network.bore[0], Rules.BORE_WIDE, "wide")
	assert_equal(network.extra_spoil[0], 40000, "20 quanta of loam spoil in all")


func test_jobs_on_a_freed_tunnel_are_void() -> void:
	"""A job whose tunnel slot was freed and reused is no longer that tunnel's."""
	var network := NetworkScript.new()
	var ref := PackedInt32Array([-1, 0])
	network.add_into(PackedInt32Array([0, 0, 2048, 0]), 2, 0, ref)
	var jobs := JobsScript.new(network, StoresScript.new())
	jobs.post(0, JobsScript.JOB_PUMP, 1, 0, 0)
	assert_true(jobs.has_job(0), "posted")
	network.stop_digging(0, ref[1])
	assert_false(jobs.has_job(0), "void once the slot is freed")


# --- hazards ----------------------------------------------------------------------------------

func _hazard_site() -> Array:
	"""An open 4 m tunnel whose middle two metres are wet sand: [network, hazards]."""
	var ground := _loam_ground()
	_mark(ground, [22, 23], GroundScript.SAND | GroundScript.WET_BIT)
	var network := _four_metres(ground)
	_open(network, 0)
	var hazards := HazardsScript.new(network)
	hazards.survey(0)
	return [network, hazards]


func test_a_survey_counts_wet_and_weak_quanta_and_places_the_fall() -> void:
	"""Two wet, two weak; the fall covers the sand run, 1536..2560 u along."""
	var site := _hazard_site()
	var hazards: HazardsScript = site[1]
	assert_equal(hazards.wet_quanta[0], 2, "wet")
	assert_equal(hazards.weak_quanta[0], 2, "weak")
	assert_equal(hazards.fall_from_u[0], 1536, "fall from")
	assert_equal(hazards.fall_to_u[0], 2560, "fall to")
	assert_true(hazards.in_fall(0, 1.5), "under it")
	assert_false(hazards.in_fall(0, 0.9), "short of it")
	assert_false(hazards.in_fall(0, 3.2), "past it")


func test_rain_seeps_in_warns_at_half_and_floods_at_forty_seconds() -> void:
	"""20 s of rain warns (once); 40 s floods; nothing builds while paused."""
	var site := _hazard_site()
	var hazards: HazardsScript = site[1]
	assert_equal(hazards.update(0, 0, true, false, false), HazardsScript.EVENT_NONE, "paused")
	assert_equal(hazards.update(0, 19999999, true, false, false), HazardsScript.EVENT_NONE, "just short")
	assert_equal(hazards.update(0, 1, true, false, false), HazardsScript.EVENT_SEEP_WARNING, "half")
	assert_equal(hazards.update(0, 1, true, false, false), HazardsScript.EVENT_NONE, "warned once")
	assert_equal(hazards.update(0, 19999999, true, false, false), HazardsScript.EVENT_FLOODED, "flooded")
	assert_equal(hazards.seep_permille(0), 1000, "full")


func test_a_flood_by_the_stream_seeps_four_times_as_fast() -> void:
	"""5 s of a covering flood, no rain, counts as 20."""
	var site := _hazard_site()
	var hazards: HazardsScript = site[1]
	assert_equal(hazards.update(0, 5000000, false, true, false), HazardsScript.EVENT_SEEP_WARNING, "20 s worth")
	assert_equal(hazards.strain_usec[0], 0, "no rain, no strain")


func test_crossings_strain_a_weak_bore_until_it_falls() -> void:
	"""8 s a crossing: the fifth warns (40 of 75), the tenth brings the fall due (80)."""
	var site := _hazard_site()
	var hazards: HazardsScript = site[1]
	var events: Array[int] = []
	for k in 10:
		events.append(hazards.add_crossing(0))
	assert_equal(events, [0, 0, 0, 0, 3, 0, 0, 0, 0, 4] as Array[int], "warn at 5, due at 10")


func test_only_weak_ground_takes_a_crossing_s_strain() -> void:
	"""A tunnel through wet loam (no sand) seeps in rain but takes no strain from walkers."""
	var ground := _loam_ground()
	_mark(ground, [22, 23], GroundScript.LOAM | GroundScript.WET_BIT)
	var network := _four_metres(ground)
	_open(network, 0)
	var hazards := HazardsScript.new(network)
	hazards.survey(0)
	assert_equal(hazards.weak_quanta[0], 0, "no sand")
	assert_true(hazards.exposed(0), "but wet")
	assert_equal(hazards.add_crossing(0), HazardsScript.EVENT_NONE, "a crossing")
	assert_equal(hazards.strain_usec[0], 0, "no strain")


func test_a_long_sand_run_falls_in_its_middle_three_metres() -> void:
	"""Five sand quanta in an 8 m tunnel (timeline 2..6): the fall is the middle three, 2560..4608 u."""
	var ground := _loam_ground()
	_mark(ground, [22, 23, 24, 25, 26], GroundScript.SAND)
	var network := _network_on(ground, [Vector2i(512, 512), Vector2i(8704, 512)])
	_open(network, 0)
	var hazards := HazardsScript.new(network)
	hazards.survey(0)
	assert_equal(hazards.weak_quanta[0], 5, "five weak quanta")
	assert_equal(hazards.fall_from_u[0], 2560, "from the fourth quantum's middle")
	assert_equal(hazards.fall_to_u[0], 4608, "to the sixth's")


func test_bracing_prevents_both_and_work_pauses_them() -> void:
	"""Braced, nothing builds and what had built is gone; a job in the tunnel holds both still."""
	var site := _hazard_site()
	var network: NetworkScript = site[0]
	var hazards: HazardsScript = site[1]
	hazards.update(0, 10000000, true, false, false)
	assert_equal(hazards.update(0, 30000000, true, false, true), HazardsScript.EVENT_NONE, "working")
	assert_equal(hazards.seep_usec[0], 10000000, "held while working")
	network.set_braced(0)
	assert_equal(hazards.update(0, 30000000, true, false, false), HazardsScript.EVENT_NONE, "braced")
	assert_equal(hazards.seep_usec[0], 0, "cleared")
	assert_equal(hazards.add_crossing(0), HazardsScript.EVENT_NONE, "no strain either")
	assert_false(hazards.exposed(0), "not exposed")


func test_a_flood_and_a_fall_close_the_tunnel_and_a_repair_resets() -> void:
	"""Flooded end to end; fallen over the sand; each repair resets only the pressure that struck."""
	var site := _hazard_site()
	var network: NetworkScript = site[0]
	var hazards: HazardsScript = site[1]
	hazards.flood(0)
	assert_equal(network.closed[0], NetworkScript.CLOSED_FLOODED, "flooded")
	assert_equal(network.closed_to_u[0], 4096, "end to end")
	assert_equal(hazards.update(0, 60000000, true, false, false), HazardsScript.EVENT_NONE, "a closed tunnel builds nothing")
	network.reopen(0)
	hazards.collapse(0)
	assert_equal(network.closed[0], NetworkScript.CLOSED_COLLAPSED, "fallen")
	assert_equal(network.closed_from_u[0], 1536, "over the sand")
	hazards.seep_usec[0] = 5
	hazards.strain_usec[0] = 7
	hazards.warned[0] = HazardsScript.WARNED_SEEP | HazardsScript.WARNED_STRAIN
	hazards.repaired(0, true)
	assert_equal(hazards.seep_usec[0], 0, "pumped: the seep is gone")
	assert_equal(hazards.strain_usec[0], 7, "the strain kept")
	assert_equal(hazards.warned[0], HazardsScript.WARNED_STRAIN, "may be warned of seeping again")
	hazards.repaired(0, false)
	assert_equal(hazards.strain_usec[0], 0, "cleared: the strain is gone")
	assert_equal(hazards.warned[0], 0, "no warnings stand")


# --- chambers ---------------------------------------------------------------------------------

func _chamber_site() -> Array:
	"""An open 8 m tunnel along x from (0, 0): [network, chambers, bounds]."""
	var network := _network_on(_loam_ground(), [Vector2i(0, 0), Vector2i(8192, 0)])
	_open(network, 0)
	return [network, ChambersScript.new(), Rect2i(-20480, -20480, 40960, 40960)]


func test_a_chamber_opens_two_metres_off_the_route() -> void:
	"""At 4096 u along, side +1 stands at (4096, 2048), side -1 at (4096, -2048)."""
	var network: NetworkScript = _chamber_site()[0]
	assert_equal(ChambersScript.centre_for(network, 0, 4096, 1), Vector2i(4096, 2048), "one side")
	assert_equal(ChambersScript.centre_for(network, 0, 4096, -1), Vector2i(4096, -2048), "the other")


func test_where_a_chamber_may_not_go() -> void:
	"""Every refusal, at its boundary."""
	var site := _chamber_site()
	var network: NetworkScript = site[0]
	var chambers: ChambersScript = site[1]
	var bounds: Rect2i = site[2]
	var none := PackedInt32Array()
	assert_equal(chambers.refusal(network, Vector2i(4096, 2048), bounds, none), ChambersScript.REFUSE_NONE, "fine")
	assert_equal(chambers.refusal(network, Vector2i(18944, 2048), bounds, none), ChambersScript.REFUSE_OUT_OF_BOUNDS, "edge")
	assert_equal(chambers.refusal(network, Vector2i(18943, 2048), bounds, none), ChambersScript.REFUSE_NONE, "just inside")
	var house := PackedInt32Array([4096, 1024, 5244])
	assert_equal(chambers.refusal(network, Vector2i(4096, 2048), bounds, house), ChambersScript.REFUSE_UNDER_BUILDING, "3196 < 3197")
	house[2] = 5245
	assert_equal(chambers.refusal(network, Vector2i(4096, 2048), bounds, house), ChambersScript.REFUSE_NONE, "3197 clear")
	assert_equal(chambers.refusal(network, Vector2i(0, 2000), bounds, none), ChambersScript.REFUSE_NEAR_MOUTH, "by the entrance")
	assert_equal(chambers.refusal(network, Vector2i(4096, 1024), bounds, none), ChambersScript.REFUSE_OVER_TUNNEL, "on the bore")
	var ref := PackedInt32Array([0, 0])
	chambers.add_into(ChambersScript.KIND_HOME, network, 0, 4096, Vector2i(4096, 2048), ref)
	assert_equal(chambers.refusal(network, Vector2i(7679, 2048), bounds, none), ChambersScript.REFUSE_NEAR_CHAMBER, "3583 from it")


func test_homes_count_demo_beds_and_cellars_publish_their_api() -> void:
	"""Two beds a home (9 m^2 x 12 / 40); a finished cellar lists its id, position, 60 U and 350."""
	var site := _chamber_site()
	var network: NetworkScript = site[0]
	var chambers: ChambersScript = site[1]
	assert_equal(ChambersScript.BEDS_PER_HOME, 2, "floor(9 x 12 / 40)")
	var ref := PackedInt32Array([0, 0])
	chambers.add_into(ChambersScript.KIND_HOME, network, 0, 2048, Vector2i(2048, 2048), ref)
	chambers.add_into(ChambersScript.KIND_CELLAR, network, 0, 6144, Vector2i(6144, -2048), ref)
	assert_equal(chambers.beds(), 0, "planned homes have no beds")
	assert_equal(chambers.cellars().size(), 0, "nor planned cellars stores")
	chambers.set_done(0)
	chambers.set_done(1)
	assert_equal(chambers.beds(), 2, "one home")
	assert_equal(chambers.cellar_count(), 1, "one cellar")
	assert_equal(chambers.cellars(), [{"id": Vector2i(1, 0), "position": Vector3(6.0, 0.0, -2.0),
		"capacity_u": 60, "spoilage_permille": 350}], "the cellar API")
	assert_equal(chambers.housing_line(), "Burrow homes: 1 (2 demo beds for moles) · Root cellars: 1", "readout")
	chambers.forget(1)
	assert_equal(chambers.generation[1], 1, "a forgotten chamber retires its generation")


func test_chamber_slots_run_out() -> void:
	"""Eight chambers fill every slot; a ninth is refused."""
	var site := _chamber_site()
	var network: NetworkScript = site[0]
	var chambers: ChambersScript = site[1]
	var ref := PackedInt32Array([0, 0])
	for c in 8:
		assert_true(chambers.add_into(ChambersScript.KIND_HOME, network, 0, 0, Vector2i(c * 4000, 9000), ref), "chamber %d" % c)
	assert_false(chambers.add_into(ChambersScript.KIND_HOME, network, 0, 0, Vector2i(0, -9000), ref), "no slot")
	assert_equal(chambers.refusal(network, Vector2i(0, -9000), site[2], PackedInt32Array()), ChambersScript.REFUSE_FULL, "said so")


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
	"""A tunnel from inside the flood (1.8 m from its spill point) to just outside it (9.8 m): a resident
	standing nearer its outer mouth walks out on foot rather than going round to the inner mouth."""
	var events := EventsScript.new()
	events.trigger()
	var network := NetworkScript.new()
	var ref := PackedInt32Array([-1, 0])
	network.add_into(PackedInt32Array([20582, -922, 12390, -922]), 2, 0, ref)
	_open(network, 0)
	network.set_fit(0, true)
	assert_false(events.covers(Vector2(12.1, -0.9)), "the outer mouth is dry")
	var out := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	assert_false(events.plan_escape(network, 0, Vector2(15.1, -0.9), out), "no escape by that tunnel")


func test_an_escape_goes_through_the_nearest_tunnel_out_of_the_disc() -> void:
	"""From the east road by the ford, the tunnel whose near mouth is inside and far mouth outside;
	none when both mouths are inside."""
	var events := EventsScript.new()
	events.trigger()
	var network := NetworkScript.new()
	var ref := PackedInt32Array([-1, 0])
	network.add_into(PackedInt32Array([17408, -922, 11264, -922]), 2, 0, ref)
	network.add_into(PackedInt32Array([19968, -3072, 19456, 1536]), 2, 0, ref)
	_open(network, 0)
	_open(network, 1)
	network.set_fit(0, true)
	var out := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	assert_true(events.plan_escape(network, 0, Vector2(16.0, -0.9), out), "an escape")
	assert_equal(int(out[0]), 0, "the tunnel to the square")
	assert_equal(int(out[1]), 0, "in at its entrance")
	assert_true(Vector2(out[2], out[3]).x < 11.0, "a shelter beyond its far mouth")
	assert_false(events.plan_escape(network, 0, Vector2(19.5, -1.0), out) and int(out[0]) == 1,
		"never the tunnel with both mouths under water")
	assert_false(events.plan_escape(network, 5, Vector2(16.0, -0.9), out), "nobody who does not fit")
