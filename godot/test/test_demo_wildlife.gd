extends "res://test/framework/test_case.gd"
## The village's ambient wildlife (demo/wildlife/, decision 1631; feature #11): the rules of who is about (by season,
## hour and weather), the authored spots against the real layout and water map, the moves, and the pooled view --
## counts, spots, the robin's flush, reduced motion, the trout's leap, the pause, no allocation per frame and nothing
## written. Runs on the stand-ins (no staged assets needed).

const Rules := preload("res://demo/wildlife/wildlife_rules.gd")
const Spots := preload("res://demo/wildlife/wildlife_spots.gd")
const Motion := preload("res://demo/wildlife/wildlife_motion.gd")
const Bodies := preload("res://demo/wildlife/wildlife_bodies.gd")
const ViewScript := preload("res://demo/wildlife/wildlife_view.gd")
const WeatherScript := preload("res://demo/weather/demo_weather.gd")
const DemoClockScript := preload("res://demo/demo_clock.gd")
const DemoMotion := preload("res://demo/access/demo_motion.gd")
const WaterLayout := preload("res://demo/water/water_layout.gd")
const WaterRules := preload("res://demo/water/water_rules.gd")
const Layout := preload("res://demo/world/world_layout.gd")
const DaylightCurves := preload("res://demo/world/daylight_curves.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")

const SPRING: int = 0
const SUMMER: int = 1
const AUTUMN: int = 2
const WINTER: int = 3
## A frame of demo time (s) and the frames a long run steps.
const FRAME_S: float = 1.0 / 60.0
const LONG_FRAMES: int = 3600

var _nodes: Array[Node] = []


func after_each() -> void:
	"""Free every view a test made, and put reduced motion back."""
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()
	DemoMotion.reduced = false


func _view(season: int = SUMMER, hour: int = 12, tenths: int = 220, rain: int = 0,
		brains: Array[BrainScript] = []) -> Array:
	"""[view, weather, clock]: the wildlife over an unbound weather read at this hour, on a clock of its own."""
	var weather := WeatherScript.new()
	weather.observe(season, 4, hour, tenths, rain, -1)
	var clock := DemoClockScript.new()
	clock.advance(FRAME_S)
	var view := ViewScript.new()
	_nodes.append(view)
	view.configure(weather, clock, WaterLayout.make_map(), brains)
	return [view, weather, clock]


func _run(view: ViewScript, frames: int) -> void:
	"""Step the view `frames` frames of demo time."""
	for f: int in frames:
		view._process(FRAME_S)


# --- the rules ------------------------------------------------------------------------------------------------

func test_daylight_is_the_gdds_seasonal_daylight() -> void:
	"""§5.10's daylight (daylight_curves.gd): spring 06:00-19:00 -- 06 in, 19 out, 05 out; a margin trims both ends."""
	assert_true(Rules.is_daylight(SPRING, 6), "spring 06:00 is light")
	assert_false(Rules.is_daylight(SPRING, 5), "spring 05:00 is dark")
	assert_true(Rules.is_daylight(SPRING, 18), "spring 18:00 is light")
	assert_false(Rules.is_daylight(SPRING, 19), "spring 19:00 is dark")
	assert_false(Rules.is_daylight(SPRING, 6, 60), "an hour's margin trims dawn")
	assert_true(Rules.is_daylight(SPRING, 7, 60), "and keeps the next hour")
	assert_false(Rules.is_daylight(SPRING, 18, 60), "and trims dusk")
	assert_true(Rules.is_daylight(WINTER, 8) and not Rules.is_daylight(WINTER, 16), "winter 08:00-16:00")


func test_the_robins_table() -> void:
	"""Robins: the season's count in daylight, half in rain or snow, none at night; fewer in winter."""
	assert_equal(Rules.count_of(Rules.ROBIN, SUMMER, 12, WeatherScript.COND_CLEAR, 220), 4, "summer noon")
	assert_equal(Rules.count_of(Rules.ROBIN, SUMMER, 12, WeatherScript.COND_RAIN, 220), 2, "rain halves them")
	assert_equal(Rules.count_of(Rules.ROBIN, WINTER, 12, WeatherScript.COND_SNOW, -50), 1, "winter snow: 3 / 2")
	assert_equal(Rules.count_of(Rules.ROBIN, WINTER, 12, WeatherScript.COND_FROST, -50), 3, "a frosty winter day")
	assert_equal(Rules.count_of(Rules.ROBIN, SUMMER, 23, WeatherScript.COND_CLEAR, 220), 0, "none at night")


func test_the_butterflies_table() -> void:
	"""Butterflies: warm, dry daylight an hour clear of dawn and dusk; none in winter or below FLY_TENTHS."""
	assert_equal(Rules.count_of(Rules.BUTTERFLY, SUMMER, 12, WeatherScript.COND_CLEAR, 220), 5, "summer noon")
	assert_equal(Rules.count_of(Rules.BUTTERFLY, SPRING, 12, WeatherScript.COND_CLEAR, 120), 3, "spring noon")
	assert_equal(Rules.count_of(Rules.BUTTERFLY, SPRING, 12, WeatherScript.COND_CLEAR, Rules.FLY_TENTHS), 3,
		"at the line they fly")
	assert_equal(Rules.count_of(Rules.BUTTERFLY, SPRING, 12, WeatherScript.COND_CLEAR, Rules.FLY_TENTHS - 1), 0,
		"just under it they do not")
	assert_equal(Rules.count_of(Rules.BUTTERFLY, SUMMER, 12, WeatherScript.COND_RAIN, 220), 0, "not in rain")
	assert_equal(Rules.count_of(Rules.BUTTERFLY, SUMMER, 5, WeatherScript.COND_CLEAR, 220), 0, "not at sunrise")
	assert_equal(Rules.count_of(Rules.BUTTERFLY, SUMMER, 6, WeatherScript.COND_CLEAR, 220), 5, "an hour after")
	assert_equal(Rules.count_of(Rules.BUTTERFLY, WINTER, 12, WeatherScript.COND_CLEAR, 220), 0, "hibernating")


func test_the_frogs_and_trouts_tables() -> void:
	"""Frogs day and night above freezing, spring to autumn; trout in daylight, never in winter or a freeze."""
	assert_equal(Rules.count_of(Rules.FROG, SPRING, 23, WeatherScript.COND_RAIN, 80), 3, "a spring night in rain")
	assert_equal(Rules.count_of(Rules.FROG, AUTUMN, 3, WeatherScript.COND_FROST, -10), 0, "gone in a frost")
	assert_equal(Rules.count_of(Rules.FROG, WINTER, 12, WeatherScript.COND_CLEAR, 20), 0, "hibernating")
	assert_equal(Rules.count_of(Rules.TROUT, SUMMER, 12, WeatherScript.COND_RAIN, 200), 2, "trout rise in rain")
	assert_equal(Rules.count_of(Rules.TROUT, SUMMER, 23, WeatherScript.COND_CLEAR, 200), 0, "not at night")
	assert_equal(Rules.count_of(Rules.TROUT, AUTUMN, 12, WeatherScript.COND_FROST, -10), 0, "not in a freeze")
	assert_equal(Rules.count_of(Rules.TROUT, WINTER, 12, WeatherScript.COND_CLEAR, 20), 0, "not in winter")
	assert_equal(Rules.count_of(Rules.KINDS, SUMMER, 12, WeatherScript.COND_CLEAR, 220), 0, "an unknown kind")
	assert_equal(Rules.count_of(-1, SUMMER, 12, WeatherScript.COND_CLEAR, 220), 0, "a negative kind")


func test_the_pools_hold_every_seasons_count() -> void:
	"""MAX_COUNT is each kind's largest season count (the pools are sized to it)."""
	for kind: int in Rules.KINDS:
		var most: int = 0
		for season: int in Rules.SEASONS:
			most = maxi(most, Rules.season_count(kind, season))
		assert_equal(Rules.MAX_COUNT[kind], most, "%s's pool" % Rules.KIND_NAMES[kind])


func test_flying_and_the_weather() -> void:
	"""may_fly: not in rain or snow; is_wet and is_freezing by condition."""
	assert_true(Rules.may_fly(WeatherScript.COND_CLEAR) and Rules.may_fly(WeatherScript.COND_FROST), "dry")
	assert_false(Rules.may_fly(WeatherScript.COND_RAIN) or Rules.may_fly(WeatherScript.COND_SNOW), "wet")
	assert_true(Rules.is_freezing(WeatherScript.COND_SNOW) and not Rules.is_freezing(WeatherScript.COND_RAIN), "cold")


# --- the spots ------------------------------------------------------------------------------------------------

func test_robin_spots_are_clear_of_everything_built() -> void:
	"""Every robin spot (on the ground) stands outside every placed obstacle's circle; every robin and butterfly spot
	is inside the play square."""
	var circles: Array[Vector3] = Layout.obstacles_for(Layout.placements())
	circles.append_array(Layout.obstacles_for(Layout.fence_placements()))
	for at: Vector3 in Spots.butterfly_spots():
		assert_true(absf(at.x) < Layout.PLAY_HALF_EXTENT_M and absf(at.z) < Layout.PLAY_HALF_EXTENT_M, "%s in play" % at)
	for at: Vector3 in Spots.robin_spots():
		assert_true(absf(at.x) < Layout.PLAY_HALF_EXTENT_M and absf(at.z) < Layout.PLAY_HALF_EXTENT_M, "%s in play" % at)
		for c: Vector3 in circles:
			assert_true(Vector2(at.x, at.z).distance_to(Vector2(c.x, c.y)) > c.z, "%s clear of %s" % [at, c])


func test_frog_spots_are_dry_bank_beside_the_pond() -> void:
	"""Each frog spot is dry land on the pond's bank (at or below 0, above the surface), clear of every landing."""
	var map := WaterLayout.make_map()
	var frogs: PackedVector3Array = Spots.frog_spots(map)
	assert_true(frogs.size() >= Rules.MAX_COUNT[Rules.FROG], "enough frog spots (%d)" % frogs.size())
	assert_true(frogs.size() <= Spots.MAX_FROG_SPOTS, "no more than the cap")
	for at: Vector3 in frogs:
		var u := Vector2i(WaterRules.to_u(at.x), WaterRules.to_u(at.z))
		assert_false(map.is_water(u), "%s is dry" % at)
		assert_true(at.y <= 0.0 and at.y >= Spots.surface_y(), "%s on the bank" % at)
		for near: Vector2i in WaterLayout.LANDING_NEAR:
			var landing := Vector2(WaterRules.to_m(near.x), WaterRules.to_m(near.y))
			assert_true(Vector2(at.x, at.z).distance_to(landing) >= Spots.LANDING_CLEAR_M, "%s clear of a landing" % at)


func test_trout_spots_are_over_deep_water() -> void:
	"""Each trout spot is on the surface over water at least TROUT_DEPTH_M deep; the stream's run is one."""
	var map := WaterLayout.make_map()
	var trout: PackedVector3Array = Spots.trout_spots(map)
	assert_true(trout.size() >= Rules.MAX_COUNT[Rules.TROUT], "enough trout spots (%d)" % trout.size())
	for at: Vector3 in trout:
		assert_almost_equal(at.y, Spots.surface_y(), "%s on the surface" % at)
		var depth: int = map.depth_at(Vector2i(WaterRules.to_u(at.x), WaterRules.to_u(at.z)))
		assert_true(depth >= WaterRules.to_u(Spots.TROUT_DEPTH_M), "%s deep enough (%d u)" % [at, depth])
		assert_almost_equal(Spots.heading_at(at).length(), 1.0, "a unit heading")
	assert_almost_equal(Spots.heading_at(Vector3(Spots.RUN_AT.x, 0.0, Spots.RUN_AT.y)).x, Spots.RUN_HEADING.normalized().x,
		"down the run")
	assert_false(Spots.deep_enough(map, Vector2(0.0, 0.0)), "dry land is not deep")
	assert_false(Spots.deep_enough(map, Vector2(25.8, -3.0)), "the ford's 0.2 m is not deep enough")
	var middle: Vector3 = Spots.pond_middle()
	assert_true(map.is_water(Vector2i(WaterRules.to_u(middle.x), WaterRules.to_u(middle.z))), "the pond's middle is water")


# --- the moves ------------------------------------------------------------------------------------------------

func test_a_hop_moves_only_in_its_air_frames() -> void:
	"""hop_share: 0 up to AIR_FROM, 1 from AIR_TO, rising between; clamped outside 0..1."""
	assert_equal(Motion.hop_share(0.0), 0.0, "on the ground at the start")
	assert_equal(Motion.hop_share(Motion.AIR_FROM), 0.0, "still at take-off")
	assert_equal(Motion.hop_share(Motion.AIR_TO), 1.0, "landed")
	assert_equal(Motion.hop_share(1.5), 1.0, "clamped")
	var mid: float = Motion.hop_share((Motion.AIR_FROM + Motion.AIR_TO) * 0.5)
	assert_true(mid > 0.0 and mid < 1.0, "in the air: %f" % mid)


func test_a_flight_arcs_between_its_spots() -> void:
	"""flight_at: the two spots at its ends, its arc's height at the middle; its time and the glide."""
	var a := Vector3(0.0, 0.0, 0.0)
	var b := Vector3(8.0, 0.0, 0.0)
	assert_true(Motion.flight_at(a, b, 0.0).is_equal_approx(a), "starts at its spot")
	assert_true(Motion.flight_at(a, b, 1.0).is_equal_approx(b), "lands on the other")
	assert_almost_equal(Motion.flight_at(a, b, 0.5).y, Motion.ARC_BASE_M + Motion.ARC_SHARE * 8.0, "the arc's top")
	assert_almost_equal(Motion.flight_seconds(a, b), 8.0 / Motion.FLY_SPEED_M_S, "at its speed")
	assert_almost_equal(Motion.flight_seconds(a, a + Vector3(0.5, 0.0, 0.0)), Motion.MIN_FLIGHT_S, "never shorter")
	assert_false(Motion.is_gliding(Motion.GLIDE_FROM - 0.01), "flaps first")
	assert_true(Motion.is_gliding(Motion.GLIDE_FROM), "glides last")


func test_a_flutter_keeps_near_its_spot_and_faces_its_way() -> void:
	"""flutter_at stays within its reach of the centre and between its heights; yaw_toward faces +Z at 0."""
	var centre := Vector3(3.0, 0.0, -2.0)
	for k: int in 200:
		var at: Vector3 = Motion.flutter_at(centre, 1.3, float(k) * 0.37)
		assert_true(Vector2(at.x - centre.x, at.z - centre.z).length() <= Motion.FLUTTER_REACH_M * 1.7, "near")
		assert_true(at.y >= Motion.FLUTTER_HEIGHT_M - Motion.FLUTTER_RISE_M - 0.001, "above its floor")
	assert_almost_equal(Motion.yaw_toward(Vector3.ZERO, Vector3(0.0, 0.0, 2.0), 9.0), 0.0, "+Z is yaw 0")
	assert_almost_equal(Motion.yaw_toward(Vector3.ZERO, Vector3(2.0, 0.0, 0.0), 9.0), PI * 0.5, "+X is a quarter")
	assert_almost_equal(Motion.yaw_toward(Vector3.ZERO, Vector3(0.0, 5.0, 0.0), 9.0), 9.0, "straight up: fallback")
	var yaw: float = Motion.flutter_yaw(centre, 1.3, 2.0)
	assert_true(yaw >= -PI and yaw <= PI, "a yaw")


# --- the view -------------------------------------------------------------------------------------------------

func test_the_pool_is_built_once_at_its_sizes() -> void:
	"""configure builds MAX_COUNT bodies of each kind (and a flight body per robin), all children of the view."""
	var view: ViewScript = _view()[0]
	for kind: int in Rules.KINDS:
		assert_equal(view.pool_size(kind), Rules.MAX_COUNT[kind], "%s pool" % Rules.KIND_NAMES[kind])
	var robins: int = Rules.MAX_COUNT[Rules.ROBIN]
	assert_equal(view.get_child_count(), view.count() + robins, "a body each and the robins' flight bodies")
	for i: int in view.count():
		assert_equal(view.flight_body_of(i) != null, view.kind_of(i) == Rules.ROBIN, "flight body only for robins")


func test_a_summer_noon_shows_every_kind_by_its_rules() -> void:
	"""Summer noon, clear and warm: each kind's count shows, each on its own spot, the rest hidden."""
	var view: ViewScript = _view()[0]
	for kind: int in Rules.KINDS:
		var want: int = mini(Rules.count_of(kind, SUMMER, 12, WeatherScript.COND_CLEAR, 220), view.pool_size(kind))
		assert_equal(view.shown(kind), want, "%s shown" % Rules.KIND_NAMES[kind])
		var held := PackedInt32Array()
		for k: int in view.pool_size(kind):
			var i: int = view.first_of(kind) + k
			assert_equal(view.state_of(i) != ViewScript.ST_HIDDEN, k < want, "row %d shown as counted" % i)
			if k < want:
				assert_false(held.has(view.spot_of(i)), "%s spot %d not shared" % [Rules.KIND_NAMES[kind], view.spot_of(i)])
				held.append(view.spot_of(i))


func test_a_butterfly_shown_starts_on_its_flutter_path() -> void:
	"""A butterfly shown fluttering is posed on its loop at once (no frame on its plant first): its body is at the loop's
	height, off the plant top, and stays within the loop's reach on the next frame."""
	var view: ViewScript = _view()[0]
	var i: int = view.first_of(Rules.BUTTERFLY)
	var at: Vector3 = view.body_of(i).position
	var plant: Vector3 = view.spots_of(Rules.BUTTERFLY)[view.spot_of(i)] + Vector3.UP * ViewScript.REST_Y
	assert_equal(view.state_of(i), ViewScript.ST_FLY, "fluttering")
	assert_false(at.is_equal_approx(plant), "not on its plant")
	_run(view, 1)
	assert_true(view.body_of(i).position.distance_to(at) < 0.1, "no jump on the first frame")


func test_a_winter_night_shows_nothing_and_dawn_brings_the_robins() -> void:
	"""Winter 22:00: nothing; the same weather read at 10:00 shows the robins (no other kind in winter)."""
	var made: Array = _view(WINTER, 22, -50)
	var view: ViewScript = made[0]
	for kind: int in Rules.KINDS:
		assert_equal(view.shown(kind), 0, "%s at night" % Rules.KIND_NAMES[kind])
	for i: int in view.count():
		assert_false(view.body_of(i).visible, "body %d hidden" % i)
	(made[1] as WeatherScript).observe(WINTER, 4, 10, -50, 0, -1)
	_run(view, 1)
	assert_equal(view.shown(Rules.ROBIN), 3, "winter robins")
	assert_equal(view.shown(Rules.BUTTERFLY) + view.shown(Rules.FROG) + view.shown(Rules.TROUT), 0, "nothing else")
	assert_true(view.body_of(view.first_of(Rules.ROBIN)).visible, "a robin shows")


func test_a_warmer_hour_brings_the_butterflies_out() -> void:
	"""The same hour and condition read warmer (crossing FLY_TENTHS) is a new reading: the butterflies come out."""
	var made: Array = _view(SPRING, 12, Rules.FLY_TENTHS - 10)
	var view: ViewScript = made[0]
	assert_equal(view.shown(Rules.BUTTERFLY), 0, "too cool")
	(made[1] as WeatherScript).observe(SPRING, 4, 12, Rules.FLY_TENTHS + 10, 0, -1)
	_run(view, 1)
	assert_equal(view.shown(Rules.BUTTERFLY), 3, "warm enough")


func test_animals_hidden_and_shown_again_come_back() -> void:
	"""Summer noon, then night (the robins go), then noon again: every robin is back on a spot, shown."""
	var made: Array = _view()
	var view: ViewScript = made[0]
	var weather: WeatherScript = made[1]
	weather.observe(SUMMER, 4, 23, 180, 0, -1)
	_run(view, 1)
	assert_equal(view.shown(Rules.ROBIN), 0, "gone at night")
	weather.observe(SUMMER, 5, 12, 220, 0, -1)
	_run(view, 1)
	for k: int in view.pool_size(Rules.ROBIN):
		var i: int = view.first_of(Rules.ROBIN) + k
		assert_true(view.spot_of(i) >= 0 and view.shown_body_of(i).visible, "robin %d back" % k)


func test_a_robin_takes_wing_when_a_resident_comes_close() -> void:
	"""A resident on the surface within FLUSH_M: the robin flies (its flight body shown) to another spot and lands."""
	var brain := BrainScript.new()
	brain.position = Vector2(500.0, 500.0)
	var view: ViewScript = _view(SUMMER, 12, 220, 0, [brain] as Array[BrainScript])[0]
	var robin: int = view.first_of(Rules.ROBIN)
	var spot: Vector3 = view.spots_of(Rules.ROBIN)[view.spot_of(robin)]
	assert_false(view.is_flushed(robin), "nobody near")
	brain.position = Vector2(spot.x + 0.5, spot.z)
	_run(view, 1)
	assert_equal(view.state_of(robin), ViewScript.ST_FLY, "it flies")
	assert_true(view.flight_body_of(robin).visible and not view.body_of(robin).visible, "on the wing")
	assert_true(view.flight_body_of(robin).position.distance_to(spot) < 0.3, "taking off from its spot")
	assert_true(view.spot_of(robin) >= 0, "to a spot")
	var to: Vector3 = view.spots_of(Rules.ROBIN)[view.spot_of(robin)]
	assert_false(to.is_equal_approx(spot), "another spot")
	brain.position = Vector2(500.0, 500.0)
	_run(view, int(ceilf(Motion.flight_seconds(spot, to) / FRAME_S)) + 1)
	assert_true(view.state_of(robin) != ViewScript.ST_FLY, "landed once its flight's time is up")
	assert_true(view.body_of(robin).visible and not view.flight_body_of(robin).visible, "perched again")
	assert_true(view.body_of(robin).position.is_equal_approx(to), "on the spot it flew to")


func test_an_underground_or_indoor_resident_does_not_flush_a_robin() -> void:
	"""A resident below ground or inside a building beside the robin does not flush it."""
	var brain := BrainScript.new()
	var view: ViewScript = _view(SUMMER, 12, 220, 0, [brain] as Array[BrainScript])[0]
	var robin: int = view.first_of(Rules.ROBIN)
	var spot: Vector3 = view.spots_of(Rules.ROBIN)[view.spot_of(robin)]
	brain.position = Vector2(spot.x, spot.z)
	brain.underground = true
	assert_false(view.is_flushed(robin), "below")
	brain.underground = false
	brain.indoors = true
	assert_false(view.is_flushed(robin), "indoors")
	brain.indoors = false
	assert_true(view.is_flushed(robin), "beside it on the surface")


func test_in_rain_a_robin_does_not_fly() -> void:
	"""Rain: half the robins, and over a long run none takes wing, even flushed."""
	var brain := BrainScript.new()
	var made: Array = _view(SPRING, 15, 120, 3 * WeatherScript.RAIN_PER_SHOWER_HOUR * 24, [brain] as Array[BrainScript])
	var view: ViewScript = made[0]
	assert_equal((made[1] as WeatherScript).condition(), WeatherScript.COND_RAIN, "it rains")
	var robin: int = view.first_of(Rules.ROBIN)
	var spot: Vector3 = view.spots_of(Rules.ROBIN)[view.spot_of(robin)]
	brain.position = Vector2(spot.x, spot.z)
	var flew: bool = false
	for f: int in LONG_FRAMES:
		view._process(FRAME_S)
		flew = flew or view.state_of(robin) == ViewScript.ST_FLY
	assert_false(flew, "the flushed robin never flew in rain")
	for k: int in view.pool_size(Rules.ROBIN):
		assert_true(view.state_of(view.first_of(Rules.ROBIN) + k) != ViewScript.ST_FLY, "robin %d grounded" % k)


func test_reduced_motion_keeps_everything_in_place() -> void:
	"""Reduced motion: over a long run no robin hops or flies (even flushed), no frog hops, no butterfly flutters, no
	trout leaps; every shown body stays on its spot."""
	DemoMotion.reduced = true
	var brain := BrainScript.new()
	var made: Array = _view(SUMMER, 12, 220, 0, [brain] as Array[BrainScript])
	var view: ViewScript = made[0]
	var robin: int = view.first_of(Rules.ROBIN)
	var spot: Vector3 = view.spots_of(Rules.ROBIN)[view.spot_of(robin)]
	brain.position = Vector2(spot.x, spot.z)
	var seen := PackedInt32Array()
	view._process(FRAME_S)
	var places := PackedVector3Array()
	for i: int in view.count():
		places.append(view.shown_body_of(i).position)
	for f: int in LONG_FRAMES:
		view._process(FRAME_S)
		for i: int in view.count():
			if not seen.has(view.state_of(i)):
				seen.append(view.state_of(i))
	for moving: int in [ViewScript.ST_HOP, ViewScript.ST_FLY, ViewScript.ST_LEAP]:
		assert_false(seen.has(moving), "never %s" % ViewScript.STATE_NAMES[moving])
	for i: int in view.count():
		assert_true(view.shown_body_of(i).position.is_equal_approx(places[i]), "row %d stays where it is" % i)
	var butterfly: Node3D = view.body_of(view.first_of(Rules.BUTTERFLY))
	var plant: Vector3 = view.spots_of(Rules.BUTTERFLY)[view.spot_of(view.first_of(Rules.BUTTERFLY))]
	assert_true(butterfly.position.is_equal_approx(plant + Vector3.UP * ViewScript.REST_Y), "a butterfly on its plant")


func test_turning_reduced_motion_on_settles_a_moving_animal() -> void:
	"""A butterfly fluttering when reduced motion comes on is restarted at rest the next frame."""
	var view: ViewScript = _view()[0]
	var butterfly: int = view.first_of(Rules.BUTTERFLY)
	assert_equal(view.state_of(butterfly), ViewScript.ST_FLY, "it flutters")
	DemoMotion.reduced = true
	_run(view, 1)
	assert_equal(view.state_of(butterfly), ViewScript.ST_REST, "it rests")


func test_a_trout_leaps_and_goes_under_again() -> void:
	"""A trout hides under the surface, leaps (its body shown, the leap clip) and is hidden once the leap is done."""
	var view: ViewScript = _view()[0]
	var trout: int = view.first_of(Rules.TROUT)
	assert_false(view.body_of(trout).visible, "under the surface")
	var leapt: bool = false
	for f: int in LONG_FRAMES:
		view._process(FRAME_S)
		if view.state_of(trout) == ViewScript.ST_LEAP:
			leapt = true
			assert_true(view.body_of(trout).visible, "shown in its leap")
			assert_equal(view.clip_of(trout), &"leap", "the leap clip")
			break
	assert_true(leapt, "it leapt within a minute")
	_run(view, int(ViewScript.LEAP_S / FRAME_S) + 2)
	assert_false(view.body_of(trout).visible, "under again")


func test_a_frog_hops_away_and_back_to_its_spot() -> void:
	"""A frog's hops alternate: along the bank, then back onto its spot, each HOP_M long."""
	var view: ViewScript = _view(SPRING, 12, 120)[0]
	var frog: int = view.first_of(Rules.FROG)
	var home: Vector3 = view.spots_of(Rules.FROG)[view.spot_of(frog)]
	var hops: int = 0
	var was: int = view.state_of(frog)
	for f: int in LONG_FRAMES * 2:
		view._process(FRAME_S)
		if was == ViewScript.ST_HOP and view.state_of(frog) == ViewScript.ST_REST:
			hops += 1
			var off: float = view.body_of(frog).position.distance_to(home)
			assert_almost_equal(off, 0.0 if hops % 2 == 0 else ViewScript.HOP_M[Rules.FROG], "hop %d lands" % hops)
		was = view.state_of(frog)
	assert_true(hops >= 2, "it hopped there and back (%d)" % hops)


func test_paused_nothing_moves() -> void:
	"""With the clock paused (no demo time), no state or pose changes over many frames."""
	var made: Array = _view()
	var view: ViewScript = made[0]
	(made[2] as DemoClockScript).frame_usec = 0
	var states := PackedInt32Array()
	var places := PackedVector3Array()
	for i: int in view.count():
		states.append(view.state_of(i))
		places.append(view.shown_body_of(i).position)
	_run(view, 600)
	for i: int in view.count():
		assert_equal(view.state_of(i), states[i], "row %d holds its state" % i)
		assert_true(view.shown_body_of(i).position.is_equal_approx(places[i]), "row %d holds its place" % i)


func test_a_frame_allocates_no_object() -> void:
	"""Many frames of every kind moving create no Object (OBJECT_COUNT)."""
	var view: ViewScript = _view()[0]
	_run(view, 60)
	var before: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	_run(view, LONG_FRAMES)
	assert_equal(int(Performance.get_monitor(Performance.OBJECT_COUNT)) - before, 0, "no object made")


func test_the_wildlife_writes_nothing_to_the_weather() -> void:
	"""Presentation only: a long run leaves the weather's revision and reading as they were."""
	var made: Array = _view()
	var weather: WeatherScript = made[1]
	var revision: int = weather.revision
	var key: int = (made[0] as ViewScript).hour_key()
	_run(made[0], LONG_FRAMES)
	assert_equal(weather.revision, revision, "the weather untouched")
	assert_equal((made[0] as ViewScript).hour_key(), key, "the same hour")


func test_the_prewarm_shows_every_body_and_puts_them_back() -> void:
	"""begin_prewarm shows every body (and every flight body); end_prewarm hides them and shows the hour's again."""
	var view: ViewScript = _view(WINTER, 22, -50)[0]
	view.begin_prewarm()
	for i: int in view.count():
		assert_true(view.body_of(i).visible, "body %d shown" % i)
		if view.flight_body_of(i) != null:
			assert_true(view.flight_body_of(i).visible, "flight body %d shown" % i)
	_run(view, 10)
	view.end_prewarm()
	for i: int in view.count():
		assert_false(view.shown_body_of(i).visible, "body %d hidden again (a winter night)" % i)
		if view.flight_body_of(i) != null:
			assert_false(view.flight_body_of(i).visible, "flight body %d hidden again" % i)


func test_after_the_prewarm_a_summer_noon_shows_its_animals() -> void:
	"""end_prewarm at a summer noon: every animal the hour shows is back on a spot and visible (trout under water)."""
	var view: ViewScript = _view()[0]
	view.begin_prewarm()
	view.end_prewarm()
	for kind: int in Rules.KINDS:
		for k: int in view.shown(kind):
			var i: int = view.first_of(kind) + k
			assert_true(view.spot_of(i) >= 0, "%s %d on a spot" % [Rules.KIND_NAMES[kind], k])
			assert_equal(view.shown_body_of(i).visible, kind != Rules.TROUT, "%s %d shown" % [Rules.KIND_NAMES[kind], k])
			if view.flight_body_of(i) != null:
				assert_false(view.flight_body_of(i).visible, "robin %d perched" % k)


func test_a_butterfly_settles_on_its_plant_and_robins_keep_near_their_spots() -> void:
	"""Over a long run a resting butterfly reaches REST_Y, and a robin on the ground is never further from its spot than
	HOME_REACH_M and a hop."""
	var view: ViewScript = _view()[0]
	var butterfly: int = view.first_of(Rules.BUTTERFLY)
	var lowest: float = 99.0
	for f: int in LONG_FRAMES * 2:
		view._process(FRAME_S)
		if view.state_of(butterfly) == ViewScript.ST_REST:
			lowest = minf(lowest, view.body_of(butterfly).position.y)
		for k: int in view.shown(Rules.ROBIN):
			var i: int = view.first_of(Rules.ROBIN) + k
			if view.state_of(i) != ViewScript.ST_FLY:
				var home: Vector3 = view.spots_of(Rules.ROBIN)[view.spot_of(i)]
				assert_true(view.body_of(i).position.distance_to(home) <= ViewScript.HOME_REACH_M +
					ViewScript.HOP_M[Rules.ROBIN] + 0.001, "robin %d near its spot" % k)
	assert_almost_equal(lowest, ViewScript.REST_Y, "settled on its plant")


func test_unstaged_bodies_are_stand_ins_of_the_animals_size() -> void:
	"""Without the staged model a kind's body is a stand-in: one mesh, its kind's size, culled past VIEW_RANGE_M."""
	var bodies := Bodies.new()
	var body: Node3D = bodies.make(&"wild_not_staged", Rules.FROG, true)
	_nodes.append(body)
	assert_false(Bodies.is_staged(&"wild_not_staged"), "not staged")
	var mesh := body.get_child(0) as MeshInstance3D
	assert_not_null(mesh, "a stand-in mesh")
	assert_almost_equal(mesh.transform.basis.get_scale().z, Bodies.STAND_IN_SIZE[Rules.FROG].x, "the frog's length")
	assert_almost_equal(mesh.visibility_range_end, Bodies.VIEW_RANGE_M, "culled far off")
	assert_null(Bodies.player_of(body), "no clips")
	assert_false(body.visible, "made hidden")
