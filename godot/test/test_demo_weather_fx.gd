extends "res://test/framework/test_case.gd"
## The livelier weather (decision 1632; feature #34): each §5.10 event's look (event_look.gd, weather_view.gd), the
## storm's work factor applied once through the work pace (storm_pace.gd), the events in words and their notices
## (weather_events.gd, REQ-SET-142), and the storm's lightning (weather_fx.gd): where it may strike (Q-D15 (a)), the
## photosensitivity floor in real time, reduced motion, the pooled smoulder and no allocation per frame. Placeholder
## village; no staged assets.

const LookScript := preload("res://demo/weather/event_look.gd")
const ViewScript := preload("res://demo/weather/weather_view.gd")
const PaceScript := preload("res://demo/weather/storm_pace.gd")
const EventsScript := preload("res://demo/weather/weather_events.gd")
const FxScript := preload("res://demo/weather/weather_fx.gd")
const WeatherScript := preload("res://demo/weather/demo_weather.gd")
const WeatherCore := preload("res://scripts/core/weather.gd")
const WorkPaceScript := preload("res://demo/work/work_pace.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const DemoClockScript := preload("res://demo/demo_clock.gd")
const DemoMotion := preload("res://demo/access/demo_motion.gd")
const DemoWorldScript := preload("res://demo/world/demo_world.gd")
const WaterLayout := preload("res://demo/water/water_layout.gd")
const WaterRules := preload("res://demo/water/water_rules.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const LightningScript := preload("res://demo/fx/lightning_fx.gd")
const FireScript := preload("res://demo/fx/fire_fx.gd")
const GROUND_SHADER := preload("res://demo/world/demo_ground.gdshader")
const BridgeCrewScript := preload("res://demo/waterplay/bridge_crew.gd")
const WaterDressing := preload("res://demo/water/water_dressing.gd")
const StandScript := preload("res://demo/forestry/forest_stand.gd")
const FarmSim := preload("res://demo/farm/farm_sim.gd")
const FarmAlerts := preload("res://demo/farm/farm_alerts.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const SwimRules := preload("res://demo/waterplay/swim_rules.gd")

const STORM_RAIN: int = 3200
const FRAME_S: float = 1.0 / 60.0

var _nodes: Array[Node] = []


func tolerates_outside_tree() -> bool:
	"""The fires' particle emitters restart outside the tree (the worker runs before the root is in it)."""
	return true


func after_each() -> void:
	"""Free every node a test made; reduced motion back off."""
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()
	DemoMotion.reduced = false


func _storm(weather: WeatherScript) -> void:
	"""A §5.10 heavy rain/storm day, raining at noon."""
	weather.observe(0, 3, 12, 90, STORM_RAIN, WeatherCore.EVENT_HEAVY_RAIN)


# --- the look -------------------------------------------------------------------------------------------------

func test_each_events_look_by_its_compiled_id() -> void:
	"""The tables are read by §5.10's compiled ids: the storm slants the rain, the drought parches, the frosts lie, the
	hard freeze dims the sun; calm days and blight add nothing; no event (or a bad id) is the plain look."""
	assert_true(LookScript.rain_slant(WeatherCore.EVENT_HEAVY_RAIN) > 0.0, "a storm drives the rain")
	assert_equal(LookScript.dryness(WeatherCore.EVENT_DROUGHT), 1.0, "a drought parches")
	assert_true(LookScript.frost_floor(WeatherCore.EVENT_HARD_FREEZE) > LookScript.frost_floor(WeatherCore.EVENT_EARLY_FROST),
		"a hard freeze lies heavier than an early frost")
	assert_true(LookScript.frost_floor(WeatherCore.EVENT_EARLY_FROST) > 0.0, "an early frost lies")
	assert_true(LookScript.sun_share(WeatherCore.EVENT_HARD_FREEZE) < 1.0, "a cold low sun")
	assert_true(LookScript.haze_add(WeatherCore.EVENT_DROUGHT) > 0.0, "heat haze")
	for quiet: int in [WeatherCore.EVENT_CALM_DAYS, WeatherCore.EVENT_BLIGHT, WeatherCore.EVENT_NONE, 99, -7]:
		assert_equal(LookScript.frost_floor(quiet) + LookScript.dryness(quiet) + LookScript.rain_slant(quiet) +
			LookScript.haze_add(quiet), 0.0, "event %d adds nothing" % quiet)
		assert_equal(LookScript.sun_share(quiet), 1.0, "event %d leaves the sun" % quiet)
	for event: int in WeatherCore.EVENT_COUNT:
		assert_true(LookScript.haze_add(event) >= 0.0, "haze never negative (%d)" % event)


func test_a_frost_floor_lies_under_the_cover_and_never_thins_snow() -> void:
	"""cover_target: the greater of the condition's cover and the event's floor; frost_target all frost where the floor
	wins, else the condition's (snow stays snow)."""
	var frost_floor: float = LookScript.frost_floor(WeatherCore.EVENT_HARD_FREEZE)
	assert_almost_equal(ViewScript.cover_target(WeatherScript.COND_CLEAR, WeatherCore.EVENT_HARD_FREEZE), frost_floor, "lies")
	assert_almost_equal(ViewScript.frost_target(WeatherScript.COND_CLEAR, WeatherCore.EVENT_HARD_FREEZE), 1.0, "frost")
	assert_almost_equal(ViewScript.cover_target(WeatherScript.COND_SNOW, WeatherCore.EVENT_HARD_FREEZE),
		ViewScript.COVER[WeatherScript.COND_SNOW], "snow keeps its cover")
	assert_almost_equal(ViewScript.frost_target(WeatherScript.COND_SNOW, WeatherCore.EVENT_HARD_FREEZE), 0.0, "and is snow")
	assert_almost_equal(ViewScript.cover_target(WeatherScript.COND_CLEAR, WeatherCore.EVENT_NONE), 0.0, "a clear day")


func _village() -> Array:
	"""[view, weather]: the weather view over the placeholder world, its ground on the real ground shader."""
	var root := Node3D.new()
	_nodes.append(root)
	var world := DemoWorldScript.new()
	root.add_child(world)
	world.build({})
	var weather := WeatherScript.new()
	var view := ViewScript.new()
	root.add_child(view)
	view.configure(weather, DemoClockScript.new(), world)
	return [view, weather]


func test_a_drought_parches_the_ground_and_a_storm_slants_the_rain() -> void:
	"""Drought: the ground's own material takes `dryness` 1 (and only the ground's); a storm slants the rain; the next
	plain day undoes both."""
	var made: Array = _village()
	var view: ViewScript = made[0]
	var weather: WeatherScript = made[1]
	weather.observe(1, 7, 12, 300, 0, WeatherCore.EVENT_DROUGHT)
	view._apply_targets(1.0)
	assert_almost_equal(view.dryness(), 1.0, "parched")
	var ground: ShaderMaterial = view.cover_materials()[1]
	assert_almost_equal(float(ground.get_shader_parameter(&"dryness")), 1.0, "on the ground's material")
	assert_null(view.cover_materials()[0].get_shader_parameter(&"dryness"), "not on the buildings' overlay")
	_storm(weather)
	view._apply_targets(1.0)
	assert_almost_equal(view.rain_slant(), LookScript.rain_slant(WeatherCore.EVENT_HEAVY_RAIN), "driven rain")
	var rain: CPUParticles3D = view.get_child(0) as CPUParticles3D
	assert_true(rain.direction.x > 0.3, "the falling rain leans (%s)" % rain.direction)
	assert_almost_equal(view.dryness(), 0.0, "the grass recovers")
	weather.observe(0, 4, 12, 120, 0, WeatherCore.EVENT_NONE)
	view._apply_targets(1.0)
	assert_almost_equal(view.rain_slant(), 0.0, "straight rain again")


func test_a_hard_freeze_lays_frost_on_a_clear_day() -> void:
	"""A hard freeze's clear day: the frost floor lies (all frost) and the sun dims by its share."""
	var made: Array = _village()
	var view: ViewScript = made[0]
	(made[1] as WeatherScript).observe(3, 7, 12, -170, 0, WeatherCore.EVENT_HARD_FREEZE)
	view._apply_targets(1.0)
	assert_true(view.cover() >= LookScript.frost_floor(WeatherCore.EVENT_HARD_FREEZE) - 0.001, "the frost lies")
	assert_almost_equal(view.frost(), 1.0, "it is frost")
	assert_almost_equal(view.sun_share(), ViewScript.SUN_SHARE[WeatherScript.COND_FROST] *
		LookScript.sun_share(WeatherCore.EVENT_HARD_FREEZE), "a cold sun")


# --- the storm's work factor ----------------------------------------------------------------------------------

func test_the_storm_slows_outdoor_work_once_through_the_work_pace() -> void:
	"""§5.10's x0.80 for a resident outdoors on a storm day; 1000 indoors, below ground, out of range, or any other day;
	composed with another factor by multiplying (a Chilled 800 makes 640)."""
	var weather := WeatherScript.new()
	var outdoors := BrainScript.new()
	var inside := BrainScript.new()
	inside.indoors = true
	var below := BrainScript.new()
	below.underground = true
	var pace := PaceScript.new()
	pace.bind(weather, [inside, below, outdoors] as Array[BrainScript])
	assert_equal(pace.permille(2), PaceScript.PERMILLE, "no storm")
	_storm(weather)
	assert_equal(PaceScript.STORM_PERMILLE, 800, "§5.10's 0.80")
	assert_equal(pace.permille(2), 800, "outdoors in a storm")
	assert_equal(pace.permille(0), 1000, "indoors")
	assert_equal(pace.permille(1), 1000, "below ground")
	assert_equal(pace.permille(3), 1000, "out of range")
	assert_equal(pace.permille(-1), 1000, "negative (never the last resident's)")
	var shared := WorkPaceScript.new()
	shared.add_factor("chilled", func(_who: int) -> int: return 800)
	assert_true(shared.add_factor(PaceScript.FACTOR_NAME, pace.permille), "added once")
	assert_false(shared.add_factor(PaceScript.FACTOR_NAME, pace.permille), "never twice")
	assert_equal(shared.permille(2), 640, "multiplied with the chill")
	assert_equal(shared.slowed_text(2), "work at 64% (chilled 80%, storm 80%)", "named")
	weather.observe(0, 5, 12, 120, 0, WeatherCore.EVENT_CALM_DAYS)
	assert_equal(pace.permille(2), 1000, "a calm day")


func test_the_bridge_builders_own_timing_is_not_slowed_on_a_storm_day() -> void:
	"""Decision 1632: a WU's time is the builder's skill's alone; the storm's 0.80 comes through the work pace."""
	var crew := BridgeCrewScript.new()
	var weather := WeatherScript.new()
	_storm(weather)
	crew.set("_weather", weather)
	assert_equal(crew._usec_per_wu(0), SwimRules.work_usec(1, 0), "a storm day, level 0")
	assert_equal(crew._usec_per_wu(6), SwimRules.work_usec(1, 6), "a storm day, the beaver's level")


# --- the events in words --------------------------------------------------------------------------------------

func test_each_events_effects_read_the_real_tables() -> void:
	"""Every event's words carry its §5.10 numbers from scripts/core/weather.gd; none for no event."""
	assert_equal(EventsScript.effects_text(WeatherCore.EVENT_HEAVY_RAIN),
		"rain +2000 a day, 3 °C colder; boats stay at the jetty; outdoor work at 80%", "storm")
	assert_equal(EventsScript.effects_text(WeatherCore.EVENT_DROUGHT),
		"30 °C, no rain; the beds dry 1500 more a day; orchards want water", "drought")
	assert_equal(EventsScript.effects_text(WeatherCore.EVENT_BLIGHT), "crops lose 400 health a day", "blight")
	assert_equal(EventsScript.effects_text(WeatherCore.EVENT_EARLY_FROST), "-3 °C; frost on the beds", "early frost")
	assert_equal(EventsScript.effects_text(WeatherCore.EVENT_HARD_FREEZE),
		"-12 °C; outdoor cold 2 times as fast; no boat leaves, only the ice is open", "hard freeze")
	assert_equal(EventsScript.effects_text(WeatherCore.EVENT_CALM_DAYS), "no change: a safe interval", "calm")
	assert_equal(EventsScript.effects_text(WeatherCore.EVENT_IDEAL_SPELL),
		"18 °C (2 °C in winter); crops grow 20% faster; rain +600 a day", "ideal spell")
	assert_true(EventsScript.effects_text(WeatherCore.EVENT_IDEAL_SPELL, WeatherCore.SEASON_WINTER).begins_with("2 °C;"),
		"a winter ideal spell")
	assert_true(EventsScript.effects_text(WeatherCore.EVENT_IDEAL_SPELL, WeatherCore.SEASON_SPRING).begins_with("18 °C;"),
		"a spring one")
	assert_equal(EventsScript.effects_text(WeatherCore.EVENT_BLIGHT, WeatherCore.SEASON_SUMMER),
		"crops lose 400 health a day; the summer mussel harvest closes", "summer blight")
	assert_equal(EventsScript.effects_text(WeatherCore.EVENT_NONE), "", "none")
	assert_equal(EventsScript.name_of(WeatherCore.EVENT_COUNT), "", "out of range")


func test_the_forecast_says_start_duration_and_effects() -> void:
	"""REQ-SET-142: the forecast names the event, its first day, its length and what it does."""
	assert_equal(EventsScript.forecast_text(WeatherCore.EVENT_HEAVY_RAIN, 0, 6, 2),
		"Forecast: a storm from Spring 6 for 2 days — rain +2000 a day, 3 °C colder; boats stay at the jetty; " +
		"outdoor work at 80%", "a spring storm")
	assert_true(EventsScript.forecast_text(WeatherCore.EVENT_CALM_DAYS, 3, 6, 1).contains("for 1 day —"), "one day")
	assert_equal(EventsScript.forecast_text(WeatherCore.EVENT_NONE, 0, 6, 2), "", "nothing forecast")


func test_the_farms_forecast_line_reads_the_real_row() -> void:
	"""The first spring's forced ideal spell (§5.10: day 6), disclosed three days ahead on the real farm row: the farm's
	forecast line names it, its first day, its length and its effects in spring."""
	var sim := FarmSim.new()
	var out := PackedStringArray()
	var alerts := FarmAlerts.new()
	for day: int in 6:
		sim.advance_usec(CalendarScript.DAY_USEC)
		alerts._forecast_line(sim, out)
	assert_equal(out.size(), 1, "said once")
	assert_equal(out[0], "Forecast: an ideal spell from Spring 6 for 3 days — 18 °C; crops grow 20% faster; rain +600 a day",
		"the real disclosure")


func test_the_village_is_told_when_an_event_begins_and_ends_once_each() -> void:
	"""follow: a note when the storm comes (its effects), none while it lasts, a note when it passes."""
	var notices := NoticesScript.new()
	var events := EventsScript.new()
	assert_false(events.follow(WeatherCore.EVENT_NONE, notices), "nothing yet")
	assert_true(events.follow(WeatherCore.EVENT_HEAVY_RAIN, notices), "it begins")
	assert_false(events.follow(WeatherCore.EVENT_HEAVY_RAIN, notices), "it lasts")
	assert_equal(notices.count(), 1, "one note")
	assert_equal(notices.text(0), EventsScript.began_text(WeatherCore.EVENT_HEAVY_RAIN), "its words")
	assert_true(notices.text(0).begins_with("A storm has come: rain +2000"), "with its effects")
	assert_equal(notices.source(0), NoticesScript.SOURCE_WEATHER, "from the weather")
	assert_true(events.follow(WeatherCore.EVENT_NONE, notices), "it ends")
	assert_equal(notices.count(), 2, "and one more note")
	assert_true(notices.text(0) == "The storm has passed" or notices.text(1) == "The storm has passed", "passed")
	assert_true(events.follow(WeatherCore.EVENT_DROUGHT, null), "no feed: still followed")
	assert_equal(events.following(), WeatherCore.EVENT_DROUGHT, "following the drought")


# --- the lightning --------------------------------------------------------------------------------------------

func _fx(brains: Array[BrainScript] = []) -> Array:
	"""[fx, weather, clock, world]: the storm's effects over the placeholder world and the real water map."""
	var root := Node3D.new()
	_nodes.append(root)
	var world := DemoWorldScript.new()
	root.add_child(world)
	world.build({})
	var weather := WeatherScript.new()
	var clock := DemoClockScript.new()
	clock.advance(FRAME_S)
	var fx := FxScript.new()
	root.add_child(fx)
	fx.configure(weather, clock, null, brains)
	fx.set_targets(FxScript.trees_of(world), FxScript.buildings_of(world), WaterLayout.make_map())
	return [fx, weather, clock, world]


func test_lightning_may_strike_trees_and_open_ground_never_a_building_or_the_water() -> void:
	"""Every tree is a target; every open-ground target is dry and BUILDING_CLEAR_M clear of every building circle."""
	var made: Array = _fx()
	var fx: FxScript = made[0]
	var world: DemoWorldScript = made[3]
	var map := WaterLayout.make_map()
	assert_true(fx.target_count() > world.trees().size(), "trees and open ground (%d)" % fx.target_count())
	var trees: int = 0
	for j: int in fx.target_count():
		var at: Vector3 = fx.target(j)
		if fx.is_tree(j):
			trees += 1
			continue
		assert_false(map.is_near_water(Vector2i(WaterRules.to_u(at.x), WaterRules.to_u(at.z))), "%s dry" % at)
		for c: Vector3 in world.building_obstacles():
			assert_true(Vector2(at.x - c.x, at.z - c.z).length() >= c.y + FxScript.BUILDING_CLEAR_M, "%s clear" % at)
		for c: Vector3 in WaterDressing.footprint_circles():
			assert_true(Vector2(at.x - c.x, at.z - c.y).length() >= c.z + FxScript.BUILDING_CLEAR_M,
				"%s clear of the water-side buildings (layout circle %s)" % [at, c])
	assert_equal(trees, world.trees().size(), "every tree")


func test_a_structure_built_since_and_a_felled_tree_are_not_struck() -> void:
	"""A structure standing now (the player's, cast_space.gd `structure_circles`) keeps lightning off the ground round
	it; a felled tree (a stump, cleared) is no target; a young or mature one is."""
	var fx: FxScript = _fx()[0]
	var ground: int = -1
	for j: int in fx.target_count():
		if not fx.is_tree(j) and ground < 0:
			ground = j
	var at: Vector3 = fx.target(ground)
	var built := PackedVector3Array([Vector3(at.x + 2.0, 1.5, at.z)])
	assert_true(fx.is_safe(ground), "open ground with nothing built")
	assert_false(fx.is_safe(ground, built), "not beside a new building")
	var states: Callable = func(t: int) -> int: return StandScript.STATE_STUMP if t == 0 else StandScript.STATE_YOUNG
	fx.bind_sites(func() -> PackedVector3Array: return built, states)
	assert_false(fx.is_safe(0), "a stump is no target")
	assert_true(fx.is_safe(1), "a young tree is")
	for k: int in 50:
		fx.lightning.set("_since_s", 10.0)
		var j: int = fx.strike_near(at)
		assert_true(j != ground and j != 0, "never the built-over ground or the stump (%d)" % j)
	fx.bind_sites(Callable(), Callable())


func test_it_strikes_only_in_a_storms_rain() -> void:
	"""A storm day's rain hour storms; a storm day's dry hour, plain rain and a clear day do not."""
	var made: Array = _fx()
	var fx: FxScript = made[0]
	var weather: WeatherScript = made[1]
	_storm(weather)
	assert_true(fx.is_storming(), "a storm's rain")
	weather.observe(0, 3, 3, 90, STORM_RAIN, WeatherCore.EVENT_HEAVY_RAIN)
	assert_false(fx.is_storming(), "a storm day's dry hour (03:00)")
	weather.observe(0, 2, 12, 120, 1200, WeatherCore.EVENT_NONE)
	assert_equal(weather.condition(), WeatherScript.COND_RAIN, "plain rain")
	assert_false(fx.is_storming(), "plain rain is no storm")


func test_a_strike_keeps_its_reach_and_its_distance_from_residents() -> void:
	"""strike_near lands within STRIKE_REACH_M of the focus and never within SAFE_M of a resident on the surface; with
	every near target beside somebody, nothing strikes."""
	var brain := BrainScript.new()
	brain.position = Vector2(500.0, 500.0)
	var made: Array = _fx([brain] as Array[BrainScript])
	var fx: FxScript = made[0]
	var j: int = fx.strike_near(Vector3.ZERO)
	assert_true(j >= 0, "a strike")
	assert_true(Vector2(fx.target(j).x, fx.target(j).z).length() <= FxScript.STRIKE_REACH_M, "within reach")
	assert_equal(fx.strikes, 1, "counted")
	assert_true(fx.is_safe(j), "clear of the resident far off")
	brain.position = Vector2(fx.target(j).x + 1.0, fx.target(j).z)
	assert_false(fx.is_safe(j), "not beside a resident")
	brain.underground = true
	assert_true(fx.is_safe(j), "one below ground is not in the open")
	brain.underground = false
	brain.indoors = true
	assert_true(fx.is_safe(j), "nor one indoors")
	fx.set("_gap_s", 0.0)
	assert_equal(fx.strike_near(Vector3(9000.0, 0.0, 9000.0)), -1, "nothing within reach of a far focus")
	assert_almost_equal(float(fx.get("_gap_s")), FxScript.STRIKE_GAP_S.x, "the next try waits (no search every frame)")


func test_strikes_are_three_real_seconds_apart_whatever_the_speed() -> void:
	"""At 4x, frames of a storm strike no sooner than MIN_REAL_GAP_S of REAL time; the flash runs at real speed."""
	var made: Array = _fx()
	var fx: FxScript = made[0]
	var clock: DemoClockScript = made[2]
	_storm(made[1])
	clock.speed = 4
	clock.frame_usec = int(FRAME_S * 4.0 * 1000000.0)
	var at_frame := PackedInt32Array()
	var seen: int = 0
	for f: int in 60 * 30:
		fx._process(FRAME_S)
		fx.lightning._process(FRAME_S)
		if fx.strikes != seen:
			seen = fx.strikes
			at_frame.append(f)
	assert_true(at_frame.size() >= 4, "it storms (%d strikes in 30 s)" % at_frame.size())
	for k: int in range(1, at_frame.size()):
		assert_true(float(at_frame[k] - at_frame[k - 1]) * FRAME_S >= FxScript.MIN_REAL_GAP_S - 0.001, "gap %d" % k)
	assert_almost_equal(fx.lightning._speed, 1.0, "the flash at real speed")


func test_paused_time_does_not_count_toward_the_gap() -> void:
	"""A strike, ten seconds paused, then running again with a strike due: the next waits MIN_REAL_GAP_S of running
	time (the bolt's clock stood still while paused)."""
	var made: Array = _fx()
	var fx: FxScript = made[0]
	var clock: DemoClockScript = made[2]
	_storm(made[1])
	fx.set("_gap_s", 0.0)
	fx._process(FRAME_S)
	assert_equal(fx.strikes, 1, "struck")
	clock.frame_usec = 0
	for f: int in 600:
		fx._process(FRAME_S)
		fx.lightning._process(FRAME_S)
	clock.frame_usec = int(FRAME_S * 1000000.0)
	fx.set("_gap_s", 0.0)
	var waited: int = 0
	while fx.strikes == 1 and waited < 600:
		fx._process(FRAME_S)
		fx.lightning._process(FRAME_S)
		fx.set("_gap_s", 0.0)
		waited += 1
	assert_true(waited < 600, "it struck again")
	assert_true(float(waited) * FRAME_S >= FxScript.MIN_REAL_GAP_S - FRAME_S * 2.0, "waited %d frames running" % waited)


func test_paused_nothing_strikes_and_the_flash_holds() -> void:
	"""With no demo time, a storm strikes nothing and the bolt's clock stands."""
	var made: Array = _fx()
	var fx: FxScript = made[0]
	(made[2] as DemoClockScript).frame_usec = 0
	_storm(made[1])
	fx.set("_gap_s", 0.0)
	for f: int in 60 * 20:
		fx._process(FRAME_S)
	assert_equal(fx.strikes, 0, "no strike paused")
	assert_almost_equal(fx.lightning._speed, 0.0, "the flash holds")


func test_a_tree_strike_leaves_a_smoulder_from_the_pool_and_it_dies() -> void:
	"""A strike on a tree takes an idle pooled fire; the fire goes out by itself (no spread, nothing burns down)."""
	var made: Array = _fx()
	var fx: FxScript = made[0]
	var tree: int = -1
	for j: int in fx.target_count():
		if fx.is_tree(j):
			tree = j
			break
	assert_true(tree >= 0, "a tree to strike")
	assert_true(fx.strike(tree), "struck")
	assert_false(fx.pooled_fire(0).is_idle(), "a smoulder")
	assert_true(fx.pooled_fire(1).is_idle(), "the other free")
	assert_true(fx.pooled_fire(0).position.is_equal_approx(fx.target(tree)), "at the tree's foot")
	fx.pooled_fire(0).set_speed(1.0)
	for f: int in 60 * 40:
		fx.pooled_fire(0)._process(FRAME_S)
	assert_true(fx.pooled_fire(0).is_idle(), "out by itself")


func test_strikes_never_land_beside_a_resident() -> void:
	"""With a resident standing on a target, 200 strikes round it never land within SAFE_M of the resident."""
	var brain := BrainScript.new()
	var made: Array = _fx([brain] as Array[BrainScript])
	var fx: FxScript = made[0]
	var on: Vector3 = fx.target(fx.target_count() - 1)
	brain.position = Vector2(on.x, on.z)
	for k: int in 200:
		fx.lightning.set("_since_s", 10.0)
		var j: int = fx.strike_near(on)
		if j >= 0:
			assert_true(Vector2(fx.target(j).x, fx.target(j).z).distance_to(brain.position) >= FxScript.SAFE_M,
				"strike %d clear of the resident" % k)
	assert_true(fx.strikes > 0, "it struck elsewhere")


func test_open_ground_never_smoulders_and_two_trees_take_both_fires() -> void:
	"""A strike on open ground lights no fire; two tree strikes take the two pooled fires, a third finds none free."""
	var fx: FxScript = _fx()[0]
	var trees := PackedInt32Array()
	var ground: int = -1
	for j: int in fx.target_count():
		if fx.is_tree(j) and trees.size() < 3:
			trees.append(j)
		elif not fx.is_tree(j) and ground < 0:
			ground = j
	fx.lightning.set("_since_s", 10.0)
	assert_true(fx.strike(ground), "open ground struck")
	assert_true(fx.pooled_fire(0).is_idle() and fx.pooled_fire(1).is_idle(), "no fire on open ground")
	for k: int in 3:
		fx.lightning.set("_since_s", 10.0)
		assert_true(fx.strike(trees[k]), "tree %d struck" % k)
	assert_true(fx.pooled_fire(0).position.is_equal_approx(fx.target(trees[0])), "the first fire at the first tree")
	assert_true(fx.pooled_fire(1).position.is_equal_approx(fx.target(trees[1])), "the second at the second")


func test_reduced_motion_reaches_the_bolt_and_the_fires() -> void:
	"""Turning reduced motion on reaches the lightning (one soft swell) and every fire on the next frame."""
	var fx: FxScript = _fx()[0]
	assert_false(fx.lightning._reduced, "off")
	DemoMotion.reduced = true
	fx._process(FRAME_S)
	assert_true(fx.lightning._reduced, "the bolt")
	for k: int in fx.fire_count():
		assert_true(fx.pooled_fire(k)._reduced, "fire %d" % k)


func test_a_storm_frame_allocates_no_object() -> void:
	"""Many storm frames, strikes included, create no Object (OBJECT_COUNT)."""
	var made: Array = _fx()
	var fx: FxScript = made[0]
	_storm(made[1])
	for f: int in 60:
		fx._process(FRAME_S)
	var before: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	for f: int in 60 * 30:
		fx._process(FRAME_S)
	assert_true(fx.strikes > 0, "it struck")
	assert_equal(int(Performance.get_monitor(Performance.OBJECT_COUNT)) - before, 0, "no object made")
