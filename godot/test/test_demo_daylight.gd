extends "res://test/framework/test_case.gd"
## The day and the night (decision 0541): the curves' sampling at the hour boundaries and through the seasons, the sun's
## arc, the day key held to the world's own look, the weather on top of the hour, the underground left alone, Brighter
## nights, the night lights' pool and its budget, the prewarm, the date trigger's icon, and nothing allocated a frame.
## On the placeholder village -- no staged assets.

const Daylight := preload("res://demo/world/daylight.gd")
const Curves := preload("res://demo/world/daylight_curves.gd")
const DayNightScript := preload("res://demo/world/day_night.gd")
const NightLightsScript := preload("res://demo/world/night_lights.gd")
const Look := preload("res://demo/world/world_look.gd")
const Layout := preload("res://demo/world/world_layout.gd")
const DemoWorldScript := preload("res://demo/world/demo_world.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const WeatherScript := preload("res://demo/weather/demo_weather.gd")
const WeatherViewScript := preload("res://demo/weather/weather_view.gd")
const DemoClockScript := preload("res://demo/demo_clock.gd")
const Access := preload("res://demo/access/demo_access.gd")
const DemoMotion := preload("res://demo/access/demo_motion.gd")
const Layers := preload("res://demo/demo_layers.gd")
const KitScript := preload("res://demo/burrow/fixture_kit.gd")
const SimClock := preload("res://scripts/core/sim_clock.gd")
const TunnelViewScript := preload("res://demo/tunnel/tunnel_view.gd")
const OverlayScript := preload("res://demo/tunnel/tunnel_overlay.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const MouthScript := preload("res://demo/tunnel/tunnel_mouth.gd")
const FixtureViewScript := preload("res://demo/burrow/fixture_view.gd")

const SPRING: int = 0
const SUMMER: int = 1
const AUTUMN: int = 2
const WINTER: int = 3
## A boundary is approached this close (minutes) from either side.
const NEAR_MIN: float = 0.001
## Updates the allocation and cost check runs.
const FRAMES: int = 2000
## A write's cost budget (microseconds, mean over FRAMES on the headless suite: generous, a regression guard).
const APPLY_BUDGET_USEC: float = 400.0

var _nodes: Array[Node] = []
var _sample: Daylight.Sample = Daylight.Sample.new()


func after_each() -> void:
	"""Free every node a test made; Brighter nights and reduced motion off again."""
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()
	Access.reset()
	DemoMotion.reduced = false


func _keep(node: Node) -> Node:
	"""Track `node` for freeing."""
	_nodes.append(node)
	return node


static func _tick_at(day: int, hour: int, minute: int = 0) -> int:
	"""The calendar tick at `hour`:`minute` of day `day` (0: spring 1; even minutes are whole ticks)."""
	@warning_ignore("integer_division")
	return day * SimClock.TICKS_PER_DAY + (hour - 6) * SimClock.TICKS_PER_HOUR + minute * SimClock.TICKS_PER_HOUR / 60


func _sampled(minute: float, season: int = SPRING, bright: bool = false) -> Daylight.Sample:
	"""The one reused sample, at `minute` in `season`."""
	Daylight.sample_into(minute, season, bright, _sample)
	return _sample


func _village() -> Array:
	"""[world, calendar, weather, weather view, night lights, day/night] on the placeholder world, nothing in the tree."""
	var world: DemoWorldScript = _keep(DemoWorldScript.new())
	world.build({})
	var calendar := CalendarScript.new()
	var weather := WeatherScript.new()
	var view: WeatherViewScript = _keep(WeatherViewScript.new())
	view.configure(weather, DemoClockScript.new(), world)
	var lights: NightLightsScript = _keep(NightLightsScript.new())
	lights.configure(NightLightsScript.home_spots(Layout.placements()), Callable(), func() -> Vector3: return Vector3.ZERO)
	var cycle: DayNightScript = _keep(DayNightScript.new())
	cycle.configure(calendar, world, view, lights)
	return [world, calendar, weather, view, lights, cycle]


func _at(made: Array, tick: int) -> DayNightScript:
	"""The calendar set to `tick` and the light written."""
	(made[1] as CalendarScript).tick = tick
	var cycle: DayNightScript = made[5]
	cycle.apply()
	return cycle


# --- the clock --------------------------------------------------------------------------------------------------

func test_the_calendar_tick_reads_as_a_minute_of_the_day_and_a_season() -> void:
	"""Tick 0 is 06:00 of spring 1; the first midnight is tick 13500; a season is twelve days."""
	assert_almost_equal(Daylight.minute_of_tick(0), 360.0, "tick 0: 06:00")
	assert_almost_equal(Daylight.minute_of_tick(SimClock.FIRST_MIDNIGHT_TICK), 0.0, "the first midnight")
	assert_almost_equal(Daylight.minute_of_tick(SimClock.FIRST_MIDNIGHT_TICK - 1), 1440.0 - 0.08, "a tick before it")
	assert_almost_equal(Daylight.minute_of_tick(_tick_at(3, 19, 30)), 1170.0, "19:30 on day 4")
	var summer_starts: int = 12 * SimClock.TICKS_PER_DAY - SimClock.CALENDAR_OFFSET_TICKS
	assert_equal(Daylight.season_of_tick(0), SPRING, "spring at the start")
	assert_equal(Daylight.season_of_tick(summer_starts - 1), SPRING, "spring to its last tick")
	assert_equal(Daylight.season_of_tick(summer_starts), SUMMER, "summer from midnight")
	assert_equal(Daylight.season_of_tick(summer_starts + 36 * SimClock.TICKS_PER_DAY), SPRING, "a year on: spring")


func test_the_windows_are_the_gdd_s_daylight_and_the_brief_s_spring() -> void:
	"""Sunrise and sunset are §5.10's daylight column; spring's dawn is 05:00-07:00 and its dusk 19:00-21:00."""
	assert_equal(Curves.SUNRISE_MIN, PackedInt32Array([360, 300, 420, 480]), "sunrise: 06, 05, 07, 08")
	assert_equal(Curves.SUNSET_MIN, PackedInt32Array([1140, 1260, 1080, 960]), "sunset: 19, 21, 18, 16")
	assert_equal(Daylight.dawn_start_of(SPRING), 300, "spring's dawn from 05:00")
	assert_equal(Daylight.sunrise_of(SPRING) + Curves.DAWN_HALF_MIN, 420, "to 07:00")
	assert_equal(Daylight.sunset_of(SPRING), 1140, "its dusk from 19:00")
	assert_equal(Daylight.dusk_end_of(SPRING), 1260, "to 21:00")
	for season: int in 4:
		assert_true(Daylight.dawn_start_of(season) > 0 and Daylight.dusk_end_of(season) < Curves.MINUTES_PER_DAY,
			"season %d's windows inside its day, so the season changes at night" % season)
		assert_equal(_sampled(0.0, season).phase, Daylight.PHASE_NIGHT, "season %d: midnight is night" % season)


func test_each_key_is_met_exactly_on_its_hour() -> void:
	"""Spring: 05:00 night, 06:00 the dawn key, 07:00 the day, 19:00 the day, 20:00 the dusk key, 21:00 night."""
	var keys: Array = [[300.0, Curves.KEY_NIGHT], [360.0, Curves.KEY_DAWN], [420.0, Curves.KEY_DAY],
		[720.0, Curves.KEY_DAY], [1140.0, Curves.KEY_DAY], [1200.0, Curves.KEY_DUSK], [1260.0, Curves.KEY_NIGHT],
		[0.0, Curves.KEY_NIGHT]]
	for pair: Array in keys:
		var sample := _sampled(float(pair[0]))
		var key: int = pair[1]
		assert_almost_equal(sample.light_energy, Curves.LIGHT_ENERGY[key], "%s: the %s light" % [pair[0], Curves.KEY_NAMES[key]])
		assert_almost_equal(sample.ambient_energy, Curves.AMBIENT_ENERGY[key], "%s: its ambient" % pair[0])
		assert_almost_equal(sample.lamps, Curves.LAMPS[key], "%s: its lamps" % pair[0])
		assert_true(sample.sky_top.is_equal_approx(Curves.SKY_TOP[key]), "%s: its sky" % pair[0])
		assert_true(sample.light_colour.is_equal_approx(Curves.LIGHT_COLOUR[key]), "%s: its colour" % pair[0])


func test_between_keys_the_curves_ease() -> void:
	"""A quarter and half of each half-window: smoothstep's 0.15625 and 0.5 of the way from one key to the next."""
	var eased: Array = [[315.0, Curves.KEY_NIGHT, Curves.KEY_DAWN, 0.15625], [330.0, Curves.KEY_NIGHT, Curves.KEY_DAWN, 0.5],
		[390.0, Curves.KEY_DAWN, Curves.KEY_DAY, 0.5], [1155.0, Curves.KEY_DAY, Curves.KEY_DUSK, 0.15625],
		[1170.0, Curves.KEY_DAY, Curves.KEY_DUSK, 0.5], [1230.0, Curves.KEY_DUSK, Curves.KEY_NIGHT, 0.5]]
	for row: Array in eased:
		var key_from: int = row[1]
		var key_to: int = row[2]
		var wanted := lerpf(Curves.LIGHT_ENERGY[key_from], Curves.LIGHT_ENERGY[key_to], float(row[3]))
		assert_almost_equal(_sampled(float(row[0])).light_energy, wanted, "%s: eased between its keys" % row[0])


func test_the_shadow_is_off_while_the_light_swings() -> void:
	"""From the dusk's middle to the dawn's: no shadow, while the light's direction swings between moon and sun."""
	for minute: float in [0.0, 300.0, 330.0, 359.9, 1200.0, 1230.0, 1259.0]:
		assert_almost_equal(_sampled(minute).shadow, 0.0, "%s: no shadow" % minute)
	assert_true(_sampled(1170.0).shadow > 0.4 and _sampled(390.0).shadow > 0.4, "fading in the other halves")


func test_grey_is_the_rec_709_luminance() -> void:
	"""A colour greyed all the way is its Rec. 709 luminance; its alpha kept."""
	var grey := Daylight.greyed(Color(1.0, 0.0, 0.0, 0.5), 1.0)
	assert_true(grey.is_equal_approx(Color(0.2126, 0.2126, 0.2126, 0.5)), "red's grey %s" % grey)
	assert_true(Daylight.greyed(Color(0.0, 1.0, 0.0), 0.5).is_equal_approx(Color(0.3576, 0.8576, 0.3576)), "half way")


func test_the_phases_change_on_the_window_s_edges() -> void:
	"""04:59 night, 05:00 dawn; 06:59 dawn, 07:00 day; 18:59 day, 19:00 dusk; 20:59 dusk, 21:00 night."""
	var edges: Array = [[300.0, Daylight.PHASE_NIGHT, Daylight.PHASE_DAWN], [420.0, Daylight.PHASE_DAWN, Daylight.PHASE_DAY],
		[1140.0, Daylight.PHASE_DAY, Daylight.PHASE_DUSK], [1260.0, Daylight.PHASE_DUSK, Daylight.PHASE_NIGHT]]
	for edge: Array in edges:
		var at: float = edge[0]
		assert_equal(_sampled(at - NEAR_MIN).phase, int(edge[1]), "just before %s" % at)
		assert_equal(_sampled(at).phase, int(edge[2]), "at %s" % at)


func test_every_curve_is_continuous_across_every_boundary() -> void:
	"""No jump at any key: every value a hair before a boundary is the value a hair after."""
	for at: float in [300.0, 360.0, 420.0, 1140.0, 1200.0, 1260.0]:
		var before := Daylight.Sample.new()
		var after := Daylight.Sample.new()
		Daylight.sample_into(at - NEAR_MIN, SPRING, false, before)
		Daylight.sample_into(at + NEAR_MIN, SPRING, false, after)
		for pair: Array in [[before.light_energy, after.light_energy], [before.ambient_energy, after.ambient_energy],
				[before.sky_share, after.sky_share], [before.fog_density * 100.0, after.fog_density * 100.0],
				[before.saturation, after.saturation], [before.lamps, after.lamps], [before.shadow, after.shadow],
				[before.sun_weight, after.sun_weight], [before.exposure, after.exposure]]:
			assert_true(absf(float(pair[0]) - float(pair[1])) < 0.001, "continuous at %s (%s, %s)" % [at, pair[0], pair[1]])
		assert_true(before.light_toward.distance_to(after.light_toward) < 0.01, "the light's direction at %s" % at)


func test_the_light_rises_through_the_dawn_and_falls_through_the_dusk() -> void:
	"""Monotonic: brighter every ten minutes from 05:00 to 07:00, dimmer from 19:00 to 21:00; lamps the other way."""
	var last := -1.0
	var lamps := 2.0
	for minute: int in range(300, 421, 10):
		var sample := _sampled(float(minute))
		assert_true(sample.light_energy >= last, "dawn brighter at %d" % minute)
		assert_true(sample.lamps <= lamps, "the lamps going out at %d" % minute)
		last = sample.light_energy
		lamps = sample.lamps
	last = INF
	for minute: int in range(1140, 1261, 10):
		var sample := _sampled(float(minute))
		assert_true(sample.light_energy <= last, "dusk dimmer at %d" % minute)
		last = sample.light_energy


func test_the_seasons_shift_the_windows() -> void:
	"""Summer is light at 20:00 and still dusk at 22:00; winter is dark at 18:30 and in its dawn at 08:00; autumn's
	day ends at 18:00."""
	assert_equal(_sampled(1200.0, SUMMER).phase, Daylight.PHASE_DAY, "summer 20:00: day")
	assert_equal(_sampled(1320.0, SUMMER).phase, Daylight.PHASE_DUSK, "summer 22:00: dusk")
	assert_almost_equal(_sampled(1320.0, SUMMER).light_energy, Curves.LIGHT_ENERGY[Curves.KEY_DUSK], "its dusk key")
	assert_equal(_sampled(1110.0, WINTER).phase, Daylight.PHASE_NIGHT, "winter 18:30: night")
	assert_almost_equal(_sampled(480.0, WINTER).light_energy, Curves.LIGHT_ENERGY[Curves.KEY_DAWN], "winter 08:00: dawn")
	assert_equal(_sampled(1080.0, AUTUMN).phase, Daylight.PHASE_DUSK, "autumn 18:00: dusk")
	assert_equal(_sampled(1080.0 - NEAR_MIN, AUTUMN).phase, Daylight.PHASE_DAY, "a hair before: day")
	assert_equal(_sampled(240.0 - NEAR_MIN, SUMMER).phase, Daylight.PHASE_NIGHT, "summer before 04:00: night")
	assert_equal(_sampled(240.0, SUMMER).phase, Daylight.PHASE_DAWN, "summer 04:00: dawn")
	assert_equal(_sampled(270.0, SUMMER).phase, Daylight.PHASE_DAWN, "summer 04:30: dawn")
	assert_equal(_sampled(1380.0 - NEAR_MIN, SUMMER).phase, Daylight.PHASE_DUSK, "summer before 23:00: dusk")
	assert_equal(_sampled(1380.0, SUMMER).phase, Daylight.PHASE_NIGHT, "summer 23:00: night")


# --- the sun and the moon --------------------------------------------------------------------------------------

func test_the_sun_rises_in_the_east_peaks_in_the_south_and_sets_in_the_west() -> void:
	"""At sunrise +X (east) at the least height, at the daylight's middle due south (+Z) at its peak, at sunset -X; held at
	either end outside the daylight, and never lower than LIGHT_MIN_DEG."""
	var low := sin(deg_to_rad(Curves.LIGHT_MIN_DEG))
	var rise := Daylight.sun_toward(360.0, SPRING)
	assert_true(rise.x > 0.95 and is_equal_approx(rise.y, low), "sunrise: east, low %s" % rise)
	var noon := Daylight.sun_toward(750.0, SPRING)
	assert_true(absf(noon.x) < 0.001 and noon.z > 0.5, "the daylight's middle: due south %s" % noon)
	assert_almost_equal(noon.y, sin(deg_to_rad(Curves.SUN_PEAK_DEG)), "at the peak")
	var down := Daylight.sun_toward(1140.0, SPRING)
	assert_true(down.x < -0.95 and is_equal_approx(down.y, low), "sunset: west, low %s" % down)
	assert_true(Daylight.sun_toward(100.0, SPRING).is_equal_approx(rise), "held at sunrise before it")
	assert_true(Daylight.sun_toward(1300.0, SPRING).is_equal_approx(down), "held at sunset after it")
	for minute: int in range(360, 1141, 30):
		var toward := Daylight.sun_toward(float(minute), WINTER if minute % 60 == 0 else SPRING)
		assert_true(toward.y >= low - 0.0001 and is_equal_approx(toward.length(), 1.0), "a unit sun above %d" % minute)
	assert_true(Daylight.sun_toward(720.0, WINTER).y < Daylight.sun_toward(720.0, SUMMER).y + 0.2,
		"the peak is the same all year (only the hour of it moves)")
	assert_almost_equal(Daylight.sun_toward(720.0, WINTER).y, sin(deg_to_rad(Curves.SUN_PEAK_DEG)), "winter's noon: the peak")


func test_the_light_is_the_moon_at_night_and_the_sun_by_day() -> void:
	"""Midnight: from MOON_TOWARD, the moon's colour, no shadow; noon: the sun's direction, the world's sun, full shadow."""
	var night := _sampled(0.0)
	assert_true(night.light_toward.is_equal_approx(Curves.MOON_TOWARD.normalized()), "the moon's direction")
	assert_almost_equal(night.shadow, 0.0, "no shadow")
	var day := _sampled(720.0)
	assert_true(day.light_toward.is_equal_approx(day.sun_toward), "the sun's direction")
	assert_almost_equal(day.shadow, 1.0, "full shadow")


func test_the_day_key_is_the_world_s_own_look() -> void:
	"""DAY's values are world_look.gd's sun, sky, ambient and haze (decision 0301's targets) exactly."""
	assert_almost_equal(Curves.LIGHT_ENERGY[Curves.KEY_DAY], Look.SUN_ENERGY, "the sun's energy")
	assert_true(Curves.LIGHT_COLOUR[Curves.KEY_DAY].is_equal_approx(Look.SUN_COLOR), "the sun's colour")
	var holder := Look.make_environment()
	var env := holder.environment
	var sky := env.sky.sky_material as ProceduralSkyMaterial
	var day := _sampled(720.0)
	assert_true(day.sky_top.is_equal_approx(sky.sky_top_color), "the sky overhead")
	assert_true(day.sky_horizon.is_equal_approx(sky.sky_horizon_color), "its horizon")
	assert_true(day.ground_horizon.is_equal_approx(sky.ground_horizon_color), "the ground's horizon")
	assert_true(day.ground_bottom.is_equal_approx(sky.ground_bottom_color), "below")
	assert_almost_equal(day.sky_energy, sky.sky_energy_multiplier, "the sky's energy")
	assert_almost_equal(day.ambient_energy, env.ambient_light_energy, "the ambient's energy")
	assert_almost_equal(day.sky_share, env.ambient_light_sky_contribution, "all of it from the sky")
	assert_true(day.fog_colour.is_equal_approx(env.fog_light_color), "the haze's colour")
	assert_almost_equal(day.fog_density, env.fog_density, "the haze's density")
	assert_almost_equal(day.saturation, env.adjustment_saturation, "the saturation")
	assert_almost_equal(day.exposure, env.tonemap_exposure, "the exposure")
	holder.free()


# --- the weather on top -----------------------------------------------------------------------------------------

func test_the_gloom_of_each_sky() -> void:
	"""Clear and frost none; an overcast dry hour of a wet day, rain, a storm (heavy rain's day), snow."""
	var weather := WeatherScript.new()
	weather.observe(0, 1, 12, 150, 1200, -1)
	assert_almost_equal(WeatherViewScript.gloom_target(weather), 0.0, "a dry day: none")
	weather.observe(0, 2, 3, 150, 1200, -1)
	assert_equal(weather.condition(), WeatherScript.COND_CLEAR, "a wet day's dry 03:00")
	assert_almost_equal(WeatherViewScript.gloom_target(weather), WeatherViewScript.GLOOM_OVERCAST, "overcast")
	weather.observe(0, 2, 15, 150, 1200, -1)
	assert_almost_equal(WeatherViewScript.gloom_target(weather), WeatherViewScript.GLOOM_RAIN, "rain")
	weather.observe(0, 4, 15, 120, WeatherScript.DOWNPOUR_RAIN + 1200, -1)
	assert_equal(weather.condition(), WeatherScript.COND_RAIN, "a downpour falls")
	assert_almost_equal(WeatherViewScript.gloom_target(weather), WeatherViewScript.GLOOM_STORM, "a storm")
	weather.observe(3, 2, 15, -50, 1200, -1)
	assert_almost_equal(WeatherViewScript.gloom_target(weather), WeatherViewScript.GLOOM_SNOW, "snow")
	weather.observe(3, 1, 0, -50, 100, -1)
	assert_equal(weather.condition(), WeatherScript.COND_FROST, "frost")
	assert_almost_equal(WeatherViewScript.gloom_target(weather), 0.0, "frost: none")


func test_gloom_darkens_and_greys_whatever_the_hour() -> void:
	"""At full gloom the ambient and sky lose GLOOM_DARKEN, the saturation GLOOM_DESATURATE, the shadow GLOOM_SHADOW,
	and the sky goes grey; no gloom changes nothing."""
	for minute: float in [0.0, 360.0, 720.0, 1200.0]:
		var clear := Daylight.Sample.new()
		Daylight.sample_into(minute, SPRING, false, clear)
		var grey := Daylight.Sample.new()
		Daylight.sample_into(minute, SPRING, false, grey)
		Daylight.gloom_into(grey, 0.0)
		assert_almost_equal(grey.ambient_energy, clear.ambient_energy, "%s: no gloom, no change" % minute)
		Daylight.gloom_into(grey, 1.0)
		assert_almost_equal(grey.ambient_energy, clear.ambient_energy * (1.0 - Curves.GLOOM_DARKEN), "%s: darker" % minute)
		assert_almost_equal(grey.sky_energy, clear.sky_energy * (1.0 - Curves.GLOOM_DARKEN), "%s: the sky darker" % minute)
		assert_almost_equal(grey.saturation, clear.saturation * (1.0 - Curves.GLOOM_DESATURATE), "%s: greyer" % minute)
		assert_almost_equal(grey.shadow, clear.shadow * (1.0 - Curves.GLOOM_SHADOW), "%s: a softer shadow" % minute)
		var spread_before := maxf(clear.sky_horizon.r, maxf(clear.sky_horizon.g, clear.sky_horizon.b)) \
			- minf(clear.sky_horizon.r, minf(clear.sky_horizon.g, clear.sky_horizon.b))
		var spread_after := maxf(grey.sky_horizon.r, maxf(grey.sky_horizon.g, grey.sky_horizon.b)) \
			- minf(grey.sky_horizon.r, minf(grey.sky_horizon.g, grey.sky_horizon.b))
		assert_almost_equal(spread_after, spread_before * (1.0 - Curves.GLOOM_GREY), "%s: the horizon greyed" % minute)


func test_the_weather_multiplies_the_hour_and_the_cycle_is_the_one_writer() -> void:
	"""Rain at noon and at midnight: the light times the weather's share, the haze plus its own, the sky gloomed -- and
	the weather view, its light handed over, writes neither."""
	var made := _village()
	var weather: WeatherScript = made[2]
	var view: WeatherViewScript = made[3]
	assert_false(view.drives_light, "the cycle took the light over")
	for tick: int in [_tick_at(0, 12), _tick_at(1, 0)]:
		weather.observe(0, 2, 15, 150, 1200, -1)
		view._apply_targets(1.0)
		var cycle := _at(made, tick)
		var minute := Daylight.minute_of_tick(tick)
		var clear := Daylight.Sample.new()
		Daylight.sample_into(minute, SPRING, false, clear)
		var sun := cycle.sun()
		assert_almost_equal(sun.light_energy, clear.light_energy * WeatherViewScript.SUN_SHARE[WeatherScript.COND_RAIN],
			"%s: the light times rain's share" % minute)
		assert_almost_equal(cycle.environment().fog_density, clear.fog_density + WeatherViewScript.FOG_ADD[WeatherScript.COND_RAIN],
			"%s: the haze plus rain's" % minute)
		assert_almost_equal(cycle.environment().ambient_light_energy,
			clear.ambient_energy * (1.0 - Curves.GLOOM_DARKEN * WeatherViewScript.GLOOM_RAIN), "%s: gloomed" % minute)
		sun.light_energy = 123.0
		cycle.environment().fog_density = 9.0
		view._apply_targets(1.0)
		assert_almost_equal(sun.light_energy, 123.0, "%s: the weather view wrote no light" % minute)
		assert_almost_equal(cycle.environment().fog_density, 9.0, "%s: nor the haze" % minute)
		weather.observe(0, 1, 12, 150, 0, -1)
		view._apply_targets(1.0)


func test_the_falls_and_the_smoke_darken_with_the_night() -> void:
	"""The unshaded rain, snow and chimney smoke take the hour's UNLIT_TINT: white by day, the night's at night. The smoke
	is tinted per chimney, through its tinter; the shared puff material is never written."""
	var made := _village()
	var view: WeatherViewScript = made[3]
	var cycle: DayNightScript = made[5]
	var smoke := FixtureViewScript.new()
	_keep(smoke)
	smoke._build_room_row()
	_at(made, _tick_at(1, 0))
	cycle.set_smoke_tinter(smoke.set_smoke_tint)
	assert_true(smoke.smoke_tint().is_equal_approx(Curves.UNLIT_TINT[Curves.KEY_NIGHT]), "tinted at once when bound")
	_at(made, _tick_at(1, 12))
	assert_true(smoke._smoke[0].color.is_equal_approx(Color.WHITE), "the smoke white by day")
	_at(made, _tick_at(1, 0))
	var night: Color = Curves.UNLIT_TINT[Curves.KEY_NIGHT]
	assert_true(smoke._smoke[0].color.is_equal_approx(night), "the smoke darkened at night")
	smoke._build_room_row()
	assert_true(smoke._smoke[1].color.is_equal_approx(night), "a chimney built at night smokes in the night's tint")
	var shared := KitScript.smoke_mesh().material as StandardMaterial3D
	assert_true(shared.albedo_color.is_equal_approx(Color.WHITE), "the shared puff material untouched")
	var rain := (view._rain.mesh as PrimitiveMesh).material as StandardMaterial3D
	var own := WeatherViewScript.RAIN_COLOUR
	assert_true(rain.albedo_color.is_equal_approx(Color(own.r * night.r, own.g * night.g, own.b * night.b, own.a)),
		"the rain tinted, its alpha kept")
	var snow := (view._snow.mesh as PrimitiveMesh).material as StandardMaterial3D
	assert_almost_equal(snow.albedo_color.b, WeatherViewScript.SNOW_COLOUR.b * night.b, "the snow tinted")
	_at(made, _tick_at(2, 12))
	assert_true(smoke.smoke_tint().is_equal_approx(Color.WHITE), "white again by day")


# --- what it writes -----------------------------------------------------------------------------------------------

func test_noon_and_midnight_on_the_world_s_light() -> void:
	"""Noon: the world's sun, its shadow on, no glow, the lamps out. Midnight: the moon, the shadow pass off, the glow
	on, the lamps lit."""
	var made := _village()
	var lights: NightLightsScript = made[4]
	var cycle := _at(made, _tick_at(0, 12))
	var sun := cycle.sun()
	assert_almost_equal(sun.light_energy, Look.SUN_ENERGY, "noon: the world's sun")
	assert_true(sun.shadow_enabled and is_equal_approx(sun.shadow_opacity, 1.0), "its shadow")
	assert_false(cycle.environment().glow_enabled, "no glow")
	assert_almost_equal(lights.level(), 0.0, "the lamps out")
	assert_true((-sun.transform.basis.z).is_equal_approx(-cycle.sample.light_toward), "the sun shines down its way")
	_at(made, _tick_at(1, 0))
	assert_false(sun.shadow_enabled, "midnight: the shadow pass off")
	assert_true(sun.light_color.is_equal_approx(Curves.LIGHT_COLOUR[Curves.KEY_NIGHT]), "the moon's colour")
	assert_true(cycle.environment().glow_enabled, "the glow on")
	assert_almost_equal(cycle.environment().glow_intensity, Curves.GLOW_INTENSITY, "at full night")
	assert_almost_equal(lights.level(), 1.0, "the lamps lit")
	for tick: int in [_tick_at(1, 12), _tick_at(1, 20), _tick_at(2, 0), _tick_at(2, 5, 30), _tick_at(2, 6, 30)]:
		_check_written(_at(made, tick))


func _check_written(cycle: DayNightScript) -> void:
	"""Every value the cycle writes is its sample's, on the real sun, sky and environment (no weather: share 1, no
	haze added, no gloom)."""
	var at := cycle.sample
	var sun := cycle.sun()
	var env := cycle.environment()
	var sky := env.sky.sky_material as ProceduralSkyMaterial
	var label := "%s" % at.minute
	assert_almost_equal(sun.light_energy, at.light_energy, label + ": the light's energy")
	assert_true(sun.light_color.is_equal_approx(at.light_colour), label + ": its colour")
	assert_almost_equal(sun.shadow_opacity, at.shadow, label + ": its shadow's opacity")
	assert_equal(sun.shadow_enabled, at.shadow >= DayNightScript.SHADOW_OFF, label + ": the shadow pass")
	assert_true(sky.sky_top_color.is_equal_approx(at.sky_top), label + ": the sky overhead")
	assert_true(sky.sky_horizon_color.is_equal_approx(at.sky_horizon), label + ": its horizon")
	assert_true(sky.ground_horizon_color.is_equal_approx(at.ground_horizon), label + ": the ground's horizon")
	assert_true(sky.ground_bottom_color.is_equal_approx(at.ground_bottom), label + ": below")
	assert_almost_equal(sky.sky_energy_multiplier, at.sky_energy, label + ": the sky's energy")
	assert_true(env.ambient_light_color.is_equal_approx(at.ambient_colour), label + ": the ambient's colour")
	assert_almost_equal(env.ambient_light_energy, at.ambient_energy, label + ": its energy")
	assert_almost_equal(env.ambient_light_sky_contribution, at.sky_share, label + ": the sky's share of it")
	assert_true(env.fog_light_color.is_equal_approx(at.fog_colour), label + ": the haze's colour")
	assert_almost_equal(env.fog_density, at.fog_density, label + ": its density")
	assert_almost_equal(env.adjustment_saturation, at.saturation, label + ": the saturation")
	assert_almost_equal(env.tonemap_exposure, at.exposure, label + ": the exposure")
	assert_equal(env.glow_enabled, at.lamps >= Curves.GLOW_FROM, label + ": the glow")
	assert_almost_equal(env.glow_intensity, Curves.GLOW_INTENSITY * at.lamps, label + ": its intensity")


func test_it_writes_only_when_the_calendar_or_the_weather_moved() -> void:
	"""Under APPLY_TICKS of calendar: nothing; at it: a write. Paused (no tick): nothing. The weather moving: a write."""
	var made := _village()
	var calendar: CalendarScript = made[1]
	var cycle: DayNightScript = made[5]
	calendar.tick = _tick_at(0, 12)
	cycle.apply()
	var applies := cycle.applies
	calendar.tick += DayNightScript.APPLY_TICKS - 1
	assert_false(cycle.update(), "under APPLY_TICKS: no write")
	assert_false(cycle.update(), "paused: no write")
	calendar.tick += 1
	assert_true(cycle.update(), "at APPLY_TICKS: a write")
	assert_equal(cycle.applies, applies + 1, "one write")
	(made[2] as WeatherScript).observe(0, 2, 3, 150, 1200, -1)
	(made[3] as WeatherViewScript)._apply_targets(0.1)
	assert_almost_equal((made[3] as WeatherViewScript).sun_share(), 1.0, "an overcast dry hour: the share unmoved")
	assert_almost_equal((made[3] as WeatherViewScript).fog_add(), 0.0, "nor the haze")
	assert_true(cycle.update(), "the gloom alone moved: a write")
	assert_false(cycle.update(), "and only once")
	(made[3] as WeatherViewScript)._share = 0.9
	assert_true(cycle.update(), "the share alone moved: a write")
	calendar.tick -= DayNightScript.APPLY_TICKS
	assert_true(cycle.update(), "the calendar set back (a restart): a write")


func test_the_underground_is_never_touched() -> void:
	"""The cycle writes only the world's own environment and light: the U view's environment, on the camera, keeps every
	value through a whole day; the light and the night lights light only the surface layers."""
	var made := _village()
	var world: DemoWorldScript = made[0]
	var cycle: DayNightScript = made[5]
	var lights: NightLightsScript = made[4]
	var underground := TunnelViewScript.underground_environment()
	var fresh := TunnelViewScript.underground_environment()
	var camera := Camera3D.new()
	camera.name = "UnderCamera"
	camera.environment = underground
	world.add_child(camera)
	cycle.configure(made[1], world, made[3], lights)
	for hour: int in range(6, 31):
		_at(made, _tick_at(0, hour))
		assert_false(cycle.environment() == underground, "%d:00: its own environment" % hour)
	assert_true(camera.environment == underground, "the camera keeps the U view's")
	for property: StringName in [&"ambient_light_color", &"ambient_light_energy", &"background_color", &"fog_density",
			&"fog_light_color", &"tonemap_exposure", &"adjustment_saturation", &"glow_enabled", &"glow_intensity"]:
		assert_equal(underground.get(property), fresh.get(property), "the U view's %s untouched" % property)
	var mask := cycle.sun().light_cull_mask
	_at(made, _tick_at(2, 0))
	assert_equal(cycle.sun().light_cull_mask, mask, "the cycle never writes the light's cull mask (tunnel_view.gd's own)")
	for k: int in Curves.NIGHT_LIGHTS:
		assert_equal(lights.light(k).layers, Layers.SURFACE, "night light %d on the surface layer" % k)
		assert_equal(lights.light(k).light_cull_mask & Layers.UNDERGROUND_VIEW, 0, "lighting nothing below")


# --- brighter nights --------------------------------------------------------------------------------------------

func test_brighter_nights_raises_the_night_and_leaves_the_day() -> void:
	"""The setting on: at midnight the ambient BRIGHT_AMBIENT_GAIN times, the moon BRIGHT_LIGHT_GAIN times, the exposure
	up; at noon nothing changes. The cycle writes at once on the change."""
	var made := _village()
	var cycle := _at(made, _tick_at(1, 0))
	var ambient := cycle.environment().ambient_light_energy
	var moon := cycle.sun().light_energy
	var exposure := cycle.environment().tonemap_exposure
	Access.set_flag(Access.SET_BRIGHT_NIGHTS, true)
	assert_true(cycle.update(), "written at once on the change")
	assert_almost_equal(cycle.environment().ambient_light_energy, ambient * Curves.BRIGHT_AMBIENT_GAIN, "the ambient raised")
	assert_almost_equal(cycle.sun().light_energy, moon * Curves.BRIGHT_LIGHT_GAIN, "the moon raised")
	assert_almost_equal(cycle.environment().tonemap_exposure, exposure + Curves.BRIGHT_EXPOSURE_ADD, "the exposure up")
	var noon := Daylight.Sample.new()
	var noon_bright := Daylight.Sample.new()
	Daylight.sample_into(720.0, SPRING, false, noon)
	Daylight.sample_into(720.0, SPRING, true, noon_bright)
	assert_almost_equal(noon_bright.ambient_energy, noon.ambient_energy, "noon's ambient unchanged")
	assert_almost_equal(noon_bright.light_energy, noon.light_energy, "noon's sun unchanged")
	assert_almost_equal(noon_bright.exposure, noon.exposure, "noon's exposure unchanged")
	var plain := Daylight.Sample.new()
	var lifted := Daylight.Sample.new()
	Daylight.sample_into(1200.0, SPRING, false, plain)
	Daylight.sample_into(1200.0, SPRING, true, lifted)
	var night := plain.lamps
	assert_almost_equal(lifted.ambient_energy, plain.ambient_energy * lerpf(1.0, Curves.BRIGHT_AMBIENT_GAIN, night),
		"20:00: the ambient raised by its night")
	assert_almost_equal(lifted.light_energy, plain.light_energy
		* lerpf(1.0, Curves.BRIGHT_LIGHT_GAIN, night * (1.0 - plain.sun_weight)), "the moon's share of the light raised")
	assert_almost_equal(lifted.sky_share, plain.sky_share - Curves.BRIGHT_SKY_SHARE_CUT * night, "the sky's share cut")
	assert_almost_equal(lifted.exposure, plain.exposure + Curves.BRIGHT_EXPOSURE_ADD * night, "the exposure up")
	assert_almost_equal(_sampled(0.0, SPRING, true).sky_share,
		Curves.SKY_SHARE[Curves.KEY_NIGHT] - Curves.BRIGHT_SKY_SHARE_CUT, "midnight's sky share cut")


func test_brighter_nights_is_a_setting_and_part_of_large_readable() -> void:
	"""Off by default; named in Settings; Large readable turns it on."""
	assert_equal(Access.DEFAULTS[Access.SET_BRIGHT_NIGHTS], 0, "off by default")
	assert_equal(Access.SET_NAMES[Access.SET_BRIGHT_NIGHTS], "Brighter nights", "its name")
	assert_true(Access.PRESET_MASKS[Access.PRESET_LARGE] & (1 << Access.SET_BRIGHT_NIGHTS) != 0, "in Large readable")
	for preset: int in [Access.PRESET_KEYBOARD, Access.PRESET_MOTION, Access.PRESET_QUIET]:
		assert_equal(Access.PRESET_MASKS[preset] & (1 << Access.SET_BRIGHT_NIGHTS), 0, "not in preset %d" % preset)


# --- the night lights -------------------------------------------------------------------------------------------

func test_the_homes_are_lit_at_their_fronts() -> void:
	"""Five homes -- the hall, the residences, the kitchen -- each lamp HOME_GAP_M out from its front, HOME_UP_M up."""
	var spots := NightLightsScript.home_spots(Layout.placements())
	assert_equal(spots.size(), Curves.LIT_HOMES.size(), "one a home")
	var all := Layout.placements()
	for k: int in spots.size():
		var home: Dictionary = Layout.find_placement(all, Curves.LIT_HOMES[k])
		var at: Vector2 = home["at"]
		var front := Vector2(sin(float(home["yaw"])), cos(float(home["yaw"])))
		var out := Vector2(spots[k].x, spots[k].z) - at
		assert_true(out.dot(front) > 0.5, "%s: the lamp before its front" % Curves.LIT_HOMES[k])
		assert_almost_equal(spots[k].y, Layout.GROUND_Y + Curves.HOME_UP_M, "%s: at its height" % Curves.LIT_HOMES[k])


func test_the_pool_is_capped_and_goes_to_the_nearest_spots() -> void:
	"""Twenty lanterns and five homes: at most NIGHT_LIGHTS lit, the nearest the focus; moving the focus far
	reassigns, a step does not."""
	var lights: NightLightsScript = _keep(NightLightsScript.new())
	var mouths := func(out: PackedVector3Array) -> int:
		for k: int in 20:
			out[k] = Vector3(float(k) * 3.0, 0.5, 0.0)
		return 20
	lights.configure(NightLightsScript.home_spots(Layout.placements()), mouths, func() -> Vector3: return Vector3.ZERO)
	lights.set_level(1.0)
	lights.read_mouths()
	lights.update(Vector3(30.0, 0.0, 0.0))
	assert_equal(lights.lit_count(), Curves.NIGHT_LIGHTS, "the pool full, no more")
	assert_equal(lights.spot_count(), 25, "twenty-five spots")
	for k: int in Curves.NIGHT_LIGHTS:
		assert_true(absf(lights.light(k).position.x - 30.0) <= 12.0 + 0.01, "light %d near the focus" % k)
		assert_false(lights.light(k).shadow_enabled, "light %d shadowless" % k)
	var assigned := lights.assignments
	lights.update(Vector3(31.0, 0.0, 0.0))
	assert_equal(lights.assignments, assigned, "a short step: no reassignment")
	lights.update(Vector3(-14.0, 0.0, -6.0))
	assert_equal(lights.assignments, assigned + 1, "far: reassigned")
	for k: int in Curves.NIGHT_LIGHTS:
		var home_light := lights.light(k).light_color.is_equal_approx(Curves.HOME_COLOUR)
		var kind_energy := Curves.HOME_ENERGY if home_light else Curves.LANTERN_ENERGY
		assert_true(absf(lights.light(k).light_energy - kind_energy) <= kind_energy * Curves.FLICKER + 0.0001,
			"light %d took its new kind's energy on the reassignment" % k)
	var homes := 0
	for k: int in Curves.NIGHT_LIGHTS:
		homes += 1 if lights.light(k).light_color.is_equal_approx(Curves.HOME_COLOUR) else 0
	assert_equal(homes, Curves.LIT_HOMES.size() - 1, "near the west homes: the four west of the square lit, the kitchen not")
	assert_false(lights.read_mouths(), "the same mouths read again: no change")
	for k: int in Curves.NIGHT_LIGHTS:
		var home := lights.light(k).light_color.is_equal_approx(Curves.HOME_COLOUR)
		assert_almost_equal(lights.light(k).omni_range, Curves.HOME_RANGE_M if home else Curves.LANTERN_RANGE_M,
			"light %d's range by its kind" % k)
	lights.set_mouth_source(func(out: PackedVector3Array) -> int:
		for k: int in 20:
			out[k] = Vector3(float(k) * 3.0, 0.5, 1.0 if k == 0 else 0.0)
		return 20)
	assert_true(lights.read_mouths(), "one mouth moved, the count the same: a change")


func test_a_home_is_lit_only_when_its_query_says_so() -> void:
	"""WHICH HOMES ARE LIT: without a query every home; with one -- the winter fuel's "fuelled and demanded" hearth, at
	integration -- only those it names, re-read with the mouths, a change reassigning the pool."""
	var lights: NightLightsScript = _keep(NightLightsScript.new())
	lights.configure(NightLightsScript.home_spots(Layout.placements()), Callable(), func() -> Vector3: return Vector3.ZERO)
	lights.set_level(1.0)
	lights.update(Vector3.ZERO)
	assert_equal(lights.lit_count(), Curves.LIT_HOMES.size(), "no query: every home lit")
	var cold := {0: true, 3: true}
	lights.set_home_lit(func(k: int) -> bool: return not cold.has(k))
	lights.update(Vector3.ZERO)
	assert_equal(lights.lit_count(), Curves.LIT_HOMES.size() - 2, "the hall and one residence cold: dark")
	assert_false(lights.read_homes(), "the same answer: no change")
	cold.erase(0)
	assert_true(lights.read_homes(), "the hall lit again: a change")
	lights.update(Vector3.ZERO)
	assert_equal(lights.lit_count(), Curves.LIT_HOMES.size() - 1, "the hall's lamp back")


func test_the_lamps_follow_the_level_and_flicker_gently() -> void:
	"""Level 0 hides the pool; a level scales every energy; the flicker stays within FLICKER; reduced motion holds it."""
	var lights: NightLightsScript = _keep(NightLightsScript.new())
	var clock := DemoClockScript.new()
	lights.configure(NightLightsScript.home_spots(Layout.placements()), Callable(), func() -> Vector3: return Vector3.ZERO,
		clock)
	lights.set_level(0.5)
	lights.update(Vector3.ZERO)
	lights.flicker()
	assert_equal(lights.lit_count(), Curves.LIT_HOMES.size(), "the homes lit")
	for k: int in lights.lit_count():
		var energy := lights.light(k).light_energy
		assert_true(absf(energy - Curves.HOME_ENERGY * 0.5) <= Curves.HOME_ENERGY * 0.5 * Curves.FLICKER + 0.0001,
			"light %d at half, within the flicker" % k)
	lights._time = 0.4
	lights.flicker()
	assert_false(is_equal_approx(lights.light(1).light_energy, Curves.HOME_ENERGY * 0.5), "it wavers")
	DemoMotion.reduced = true
	lights.flicker()
	assert_almost_equal(lights.light(1).light_energy, Curves.HOME_ENERGY * 0.5, "reduced motion: steady")
	DemoMotion.reduced = false
	lights.flicker()
	var held := lights.light(1).light_energy
	lights._process(0.37)
	assert_almost_equal(lights.light(1).light_energy, held, "the demo clock paused: nothing written")
	lights._focus_source = func() -> Vector3: return Vector3(-30.0, 0.0, 0.0)
	var assigned := lights.assignments
	lights._process(0.01)
	assert_equal(lights.assignments, assigned + 1, "paused, the camera panned far: reassigned all the same")
	for k: int in lights.lit_count():
		var kind_energy := Curves.HOME_ENERGY if lights.light(k).light_color.is_equal_approx(Curves.HOME_COLOUR) \
			else Curves.LANTERN_ENERGY
		assert_true(absf(lights.light(k).light_energy - kind_energy * 0.5) <= kind_energy * 0.5 * Curves.FLICKER + 0.0001,
			"paused reassignment: light %d at its kind's energy" % k)
	lights.set_level(0.8)
	assert_true(absf(lights.light(0).light_energy - Curves.HOME_ENERGY * 0.8) <= Curves.HOME_ENERGY * 0.8 * Curves.FLICKER
		+ 0.0001, "a new level paused: the energies written at once")
	lights.set_level(0.5)
	lights._focus_source = func() -> Vector3: return Vector3.ZERO
	lights._process(0.01)
	held = lights.light(1).light_energy
	clock.advance(0.016)
	lights._process(0.37)
	assert_false(is_equal_approx(lights.light(1).light_energy, held), "running: it wavers")
	lights.set_level(0.0)
	assert_equal(lights.lit_count(), 0, "level 0: all out")
	lights.set_level(1.0)
	lights.update(Vector3.ZERO)
	assert_equal(lights.lit_count(), Curves.LIT_HOMES.size(), "lit again at the same focus: the pool shown again")


func test_the_tunnel_mouths_lanterns_are_read_from_the_overlay() -> void:
	"""An open mouth's gateway lantern is a spot (the procedural gateway: lantern_at in its frame); none while the shaft
	is dug."""
	var space := CastSpaceScript.new()
	space.setup([], [])
	var ref := PackedInt32Array([-1, 0, -1])
	space.tunnels.add_into(PackedInt32Array([0, 0, 0, 10240]), 2, 0, ref)
	var overlay: OverlayScript = _keep(OverlayScript.new())
	overlay.configure(space.tunnels, space)
	var out := PackedVector3Array()
	out.resize(4)
	space.tunnels.advance(ref[0], ref[1], 1500000)
	overlay.refresh()
	assert_equal(overlay.lantern_spots_into(out), 0, "no gateway while the shaft is dug: no lantern")
	space.tunnels.advance(ref[0], ref[1], 1000000000)
	overlay.refresh()
	assert_equal(overlay.lantern_spots_into(out), 1, "the entrance's gateway: one lantern")
	var mouth := overlay.hole(0)
	var gateway := mouth.get_child(OverlayScript.MOUTH_GATEWAY) as Node3D
	assert_true(out[0].is_equal_approx(mouth.transform * (gateway.transform * MouthScript.lantern_at())), "at its lantern")
	var none := PackedVector3Array()
	assert_equal(overlay.lantern_spots_into(none), 0, "no room: none written")


# --- the prewarm, the icon, the cost ----------------------------------------------------------------------------

func test_the_boot_s_first_frames_are_held_at_noon_with_the_shadow_on() -> void:
	"""The boot opens at sunrise, shadowless; the day prewarm holds noon -- the shadow pass on -- through the frame steps
	before the night's, and the night step's end gives sunrise back."""
	var made := _village()
	var cycle := _at(made, 0)
	assert_false(cycle.sun().shadow_enabled, "06:00, sunrise: no shadow")
	cycle.begin_day_prewarm()
	assert_true(cycle.sun().shadow_enabled and is_equal_approx(cycle.sun().shadow_opacity, 1.0), "held at noon: shadowed")
	(made[1] as CalendarScript).tick += DayNightScript.APPLY_TICKS
	cycle.update()
	assert_true(cycle.sun().shadow_enabled, "held through a write")
	cycle.begin_prewarm()
	assert_false(cycle.sun().shadow_enabled, "then the night's frames")
	cycle.end_prewarm()
	assert_almost_equal(cycle.sample.minute, Daylight.minute_of_tick(DayNightScript.APPLY_TICKS), "the calendar's hour back")


func test_a_weather_s_ease_writes_at_most_every_quarter_second() -> void:
	"""Rain easing in, frame after frame at 60 a second: a write at most every WEATHER_EVERY_S, not one a frame."""
	var made := _village()
	var view: WeatherViewScript = made[3]
	var cycle := _at(made, _tick_at(0, 12))
	(made[2] as WeatherScript).observe(0, 2, 15, 150, 1200, -1)
	var applies := cycle.applies
	for frame: int in 60:
		view._apply_targets(1.0 / 180.0)
		cycle.update(1.0 / 60.0)
	var writes := cycle.applies - applies
	assert_true(writes >= 3 and writes <= 4, "a second of easing: %d writes" % writes)


func test_the_prewarm_draws_the_night_and_gives_the_hour_back() -> void:
	"""At noon, the prewarm holds midnight -- the shadow pass off, the glow on, every night light lit -- and its end
	writes noon again."""
	var made := _village()
	var lights: NightLightsScript = made[4]
	var cycle := _at(made, _tick_at(0, 12))
	var view: WeatherViewScript = made[3]
	assert_equal(view.overlaid_count(), 0, "a clear day: no overlay")
	cycle.begin_prewarm()
	assert_true(view.overlaid_count() > 0, "the frost and snow overlay worn for the night's frames")
	assert_false(cycle.sun().shadow_enabled, "held at midnight: no shadow pass")
	assert_true(cycle.environment().glow_enabled, "the glow on")
	assert_equal(lights.lit_count(), mini(Curves.NIGHT_LIGHTS, Curves.LIT_HOMES.size()), "the pool lit")
	(made[1] as CalendarScript).tick += DayNightScript.APPLY_TICKS
	cycle.update()
	assert_false(cycle.sun().shadow_enabled, "held through a write")
	cycle.end_prewarm()
	assert_equal(view.overlaid_count(), 0, "the overlay off again")
	assert_true(cycle.sun().shadow_enabled, "noon again")
	assert_almost_equal(lights.level(), 0.0, "the lamps out")
	assert_equal(lights.lit_count(), 0, "the pool dark")


func test_the_date_trigger_wears_a_sun_by_day_and_a_moon_by_night() -> void:
	"""Two 24 px glyphs, made once; the sun at noon and at sunrise, the moon at midnight and late in the dusk."""
	var made := _village()
	var date: Button = _keep(Button.new())
	var cycle := _at(made, _tick_at(0, 12))
	cycle.set_date_button(date)
	assert_true(date.icon == DayNightScript.day_icon(), "noon: the sun")
	assert_equal(date.icon.get_size(), Vector2(24.0, 24.0), "24 px, as the HUD's own")
	assert_true(DayNightScript.day_icon() == DayNightScript.day_icon(), "made once")
	_at(made, _tick_at(0, 21))
	assert_true(date.icon == DayNightScript.night_icon(), "21:00: the moon")
	_at(made, _tick_at(1, 6))
	assert_true(date.icon == DayNightScript.day_icon(), "sunrise: the sun")
	_at(made, _tick_at(1, 20))
	assert_true(date.icon == DayNightScript.night_icon(), "20:00, the dusk's middle: the moon")
	assert_false(DayNightScript.day_icon() == DayNightScript.night_icon(), "two glyphs")


func test_a_frame_allocates_nothing_and_costs_little() -> void:
	"""FRAMES updates through two days at 4x's tick rate, the weather easing, the lamps flickering: no object kept, no
	static memory kept, and a write's mean cost within APPLY_BUDGET_USEC (a live-object census cannot see a transient,
	so the cost is the timing side of it)."""
	var made := _village()
	var calendar: CalendarScript = made[1]
	var view: WeatherViewScript = made[3]
	var lights: NightLightsScript = made[4]
	var cycle: DayNightScript = made[5]
	cycle.update()
	lights.flicker()
	var objects := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var memory := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var applies := cycle.applies
	var start := Time.get_ticks_usec()
	for frame: int in FRAMES:
		calendar.tick += 2
		view._apply_targets(0.01)
		cycle.update()
		lights.update(Vector3(float(frame % 40) - 20.0, 0.0, 0.0))
		lights.flicker()
	var spent := Time.get_ticks_usec() - start
	var writes := cycle.applies - applies
	assert_equal(int(Performance.get_monitor(Performance.OBJECT_COUNT)) - objects, 0, "no object kept")
	assert_equal(int(Performance.get_monitor(Performance.MEMORY_STATIC)) - memory, 0, "no memory kept")
	@warning_ignore("integer_division")
	assert_true(writes > FRAMES / 8, "%d writes" % writes)
	var mean := float(spent) / float(FRAMES)
	print("    daylight: %d frames, %d writes, %.1f us a frame (writes included)" % [FRAMES, writes, mean])
	assert_less_than(mean, APPLY_BUDGET_USEC, "a frame's cost")
