extends "res://test/framework/test_case.gd"
## Boat crossing rows in the route planner (decision 1821): the rows' integer arithmetic (demo/routes/boat_rows.gd), the
## router's timed boat edge (tunnel_router.gd BOAT ROWS) on a fixture world with a wall and two landings, the water's
## boat rows and their services (water_crossings.gd BOAT ROWS) on the real village water with a fixture boat, and a
## perf check against a fixed-cost crossing over the same landings. The ferry's own row is test_demo_ferry.gd's.
##
## Expected numbers are restated from their sources: 750 ticks a game hour of 25 000 000 demo microseconds
## (demo_calendar.gd HOUR_USEC), so 30 ticks a second; at 1000 mm/s one metre is 30 ticks.

const BoatRows := preload("res://demo/routes/boat_rows.gd")
const ServiceScript := preload("res://demo/boats/boat_service.gd")
const RouterScript := preload("res://demo/tunnel/tunnel_router.gd")
const CastNavScript := preload("res://demo/cast/cast_nav.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const CrossingsScript := preload("res://demo/waterplay/water_crossings.gd")
const WaterplayScript := preload("res://demo/waterplay/demo_waterplay.gd")
const WaterLayout := preload("res://demo/water/water_layout.gd")
const WaterMapScript := preload("res://demo/water/water_map.gd")
const WaterDressing := preload("res://demo/water/water_dressing.gd")
const DemoWorldScript := preload("res://demo/world/demo_world.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const KindsScript := preload("res://demo/routes/route_kinds.gd")
const ServicesScript := preload("res://demo/demo_services.gd")

## The fixture world: a wall of circles along x = 0 from z -30 to 30, landings either side of it.
const LANDING_A: Vector2 = Vector2(-3.0, 0.0)
const LANDING_B: Vector2 = Vector2(3.0, 0.0)
const START: Vector2 = Vector2(-10.0, 0.0)
const GOAL: Vector2 = Vector2(10.0, 0.0)
const BODY: float = 0.25
## The fixture boat row (row 1, crossing row 3501: not the ferry's) and its pace and ride (4 m at 1000 mm/s).
const R: int = 1
const PACE: int = 1000
const RIDE: int = 120
const MAX_WAIT: int = 90
## The village water, restated from test_demo_water_play.gd (metres).
const WEST_BANK: Vector2 = Vector2(18.5, 10.5)
const EAST_BANK: Vector2 = Vector2(30.5, 10.5)


## A fixture boat between two landings: lists the boardings it is given, and records what its legs were asked.
class FixtureBoat:
	extends "res://demo/boats/boat_service.gd"
	var end_a: Vector2 = Vector2.ZERO
	var end_b: Vector2 = Vector2.ZERO
	var at_a: PackedInt64Array = PackedInt64Array()
	var at_b: PackedInt64Array = PackedInt64Array()
	var ride: int = RIDE
	var limit: int = MAX_WAIT
	var closed: bool = false
	var calls: PackedStringArray = PackedStringArray()

	func fill_boat_row(rows: BoatRowsTable, r: int, _walker: int, _from: Vector2, _loaded: bool) -> void:
		"""Open between its ends with its boardings (none listed: not offered); closed, it leaves the row as it is."""
		if closed:
			return
		rows.open_row(r, end_a, end_b, ride, limit)
		for tick: int in at_a:
			rows.add_boarding(r, 0, tick, tick)
		for tick: int in at_b:
			rows.add_boarding(r, 1, tick, tick)

	func end_point(far: bool) -> Vector2:
		"""Its ends."""
		return end_b if far else end_a

	func begin_passenger(_brain: BoatBrain, reverse: bool) -> void:
		"""Recorded."""
		calls.append("begin %s" % reverse)

	func step_passenger(_brain: BoatBrain, _delta: float) -> bool:
		"""Recorded; over at once."""
		calls.append("step")
		return true

	func abandon_passenger(_brain: BoatBrain) -> void:
		"""Recorded."""
		calls.append("abandon")

	func passenger_text(_who: int) -> String:
		"""Its own words."""
		return "aboard the fixture boat"


static var _map_cache: WaterMapScript = null

var _nodes: Array[Object] = []
var _nav: CastNavScript = null
## The last `_village`'s cast.
var _cast: DemoCastScript = null


func before_each() -> void:
	"""The fixture world's planner, fresh."""
	_nav = CastNavScript.new()
	var wall := PackedVector3Array()
	for k: int in 41:
		wall.append(Vector3(0.0, 1.0, -30.0 + 1.5 * float(k)))
	_nav.setup(wall)
	_nav.area = Rect2(-40.0, -40.0, 80.0, 80.0)


func after_each() -> void:
	"""Free every node a test built."""
	for node: Object in _nodes:
		if is_instance_valid(node) and node is Node:
			node.free()
	_nodes.clear()


# --- fixtures -------------------------------------------------------------------------------------------------------

func _rows(at_a: Array, at_b: Array, max_wait: int = MAX_WAIT) -> BoatRows:
	"""A table with fixture row R open between the landings, its ride RIDE, at PACE, with these boardings (each ready
	by the tick it boards)."""
	var rows := BoatRows.new()
	rows.pace_mm_s = PACE
	rows.open_row(R, LANDING_A, LANDING_B, RIDE, max_wait)
	for tick: int in at_a:
		assert_true(rows.add_boarding(R, 0, tick, tick), "boarding %d at a" % tick)
	for tick: int in at_b:
		assert_true(rows.add_boarding(R, 1, tick, tick), "boarding %d at b" % tick)
	return rows


func _plan(rows: BoatRows, from: Vector2, to: Vector2, out: PackedVector2Array, legs: PackedInt32Array,
		router: RouterScript = null) -> RouterScript:
	"""Plan from -> to over the fixture world with boat row R offered; the router used."""
	var use: RouterScript = router if router != null else RouterScript.new()
	use.clear_pairs()
	assert_true(use.add_boat_crossing(BoatRows.ROW0 + R, rows, R), "the boat row offered")
	assert_true(use.plan(_nav, from, to, BODY, PackedVector3Array(), 0, 0, out, legs), "a route")
	return use


static func _boat_legs(legs: PackedInt32Array, row: int) -> int:
	"""How many legs cross crossing row `row`."""
	var count: int = 0
	for code: int in legs:
		if RouterScript.is_crossing_code(code) and RouterScript.crossing_row(code) == row:
			count += 1
	return count


static func _map() -> WaterMapScript:
	"""The village's water, built once (immutable once finalised)."""
	if _map_cache == null:
		_map_cache = WaterLayout.make_map()
	return _map_cache


func _village() -> WaterplayScript:
	"""The placeholder cast on the real layout and the village water's play (as test_demo_water_play.gd's rig)."""
	var world: DemoWorldScript = DemoWorldScript.new()
	_nodes.append(world)
	var circles: Array[Vector3] = world.obstacles()
	circles.append_array(WaterDressing.obstacles())
	circles.append_array(WaterplayScript.land_obstacles())
	var links := WaterplayScript.make_links(_map(), circles)
	circles.append_array(links.band)
	var cast: DemoCastScript = DemoCastScript.new()
	_nodes.append(cast)
	cast.build({}, world.points_of_interest(), circles, links.area)
	cast.set_bounds(WaterplayScript.walk_bounds(world.bounds()))
	var play: WaterplayScript = WaterplayScript.new()
	_nodes.append(play)
	play.configure(cast, null, null, ServicesScript.new(), _map(), links)
	_cast = cast
	return play


# --- the arithmetic -------------------------------------------------------------------------------------------------

func test_ticks_and_distances_convert_at_thirty_ticks_a_second() -> void:
	"""At 1000 mm/s a metre is 30 ticks; a part tick rounds up one way and down the other; no speed is NONE."""
	assert_equal(BoatRows.ticks_to_cover(1000, 1000), 30, "a metre at a metre a second")
	assert_equal(BoatRows.ticks_to_cover(1001, 1000), 31, "a millimetre more: rounded up")
	assert_equal(BoatRows.ticks_to_cover(800, 800), 30, "0.8 m at 0.8 m/s")
	assert_equal(BoatRows.ticks_to_cover(0, 800), 0, "nothing to cover")
	assert_equal(BoatRows.ticks_to_cover(-100000, 800), 0, "never negative")
	assert_equal(BoatRows.ticks_to_cover(1000, 0), BoatRows.NONE, "no speed")
	assert_equal(BoatRows.distance_in(30, 800), 800, "a second at 0.8 m/s")
	assert_equal(BoatRows.distance_in(29, 800), 773, "29 ticks: 773.3 mm, rounded down")
	assert_equal(BoatRows.distance_in(-3, 800), 0, "never negative")
	assert_equal(BoatRows.distance_in(30, -800), 0, "nor at a negative speed")
	assert_equal(BoatRows.distance_in(750, 819), 819 * 25, "a game hour is 25 s")


func test_boat_rows_are_rows_3500_to_3507() -> void:
	"""Clear of the route preview's 3000 and the swim ashore's 4000; the ferry is the first."""
	assert_false(BoatRows.is_boat_row(3499), "below")
	assert_true(BoatRows.is_boat_row(3500), "the first")
	assert_true(BoatRows.is_boat_row(3507), "the last")
	assert_false(BoatRows.is_boat_row(3508), "above")
	assert_equal(CrossingsScript.FERRY_ROW, 3500, "the ferry keeps its row")


func test_a_row_opens_closed_rides_and_waits_are_never_negative() -> void:
	"""A closed row lists nothing; open, it is offered only with a boarding; a negative ride or limit reads 0; cleared,
	it is closed with no boarding at either landing."""
	var rows := BoatRows.new()
	assert_false(rows.add_boarding(R, 0, 10, 10), "closed")
	rows.open_row(R, LANDING_A, LANDING_B, RIDE, MAX_WAIT)
	assert_false(rows.offered(R), "open with no boarding: not offered")
	rows.open_row(R + 1, LANDING_A, LANDING_B, -5, -7)
	assert_equal(rows.ride_ticks[R + 1], 0, "a ride is never negative")
	assert_equal(rows.max_wait_ticks[R + 1], 0, "nor a wait limit")
	assert_true(rows.add_boarding(R, 0, 0, 0), "at a")
	assert_true(rows.add_boarding(R, 1, 0, 0), "at b")
	rows.clear_row(R)
	assert_false(rows.offered(R), "cleared")
	assert_equal(rows.open[R], 0, "closed")
	assert_equal(rows.board_count[R * 2], 0, "nothing at a")
	assert_equal(rows.board_count[R * 2 + 1], 0, "nothing at b")


func test_boardings_are_listed_strictly_ascending_and_at_most_eight() -> void:
	"""Ready by never negative nor after the boarding; each strictly after the last's; the ninth is refused."""
	var rows := BoatRows.new()
	rows.open_row(R, LANDING_A, LANDING_B, RIDE, MAX_WAIT)
	assert_false(rows.add_boarding(R, 0, -1, 5), "ready by before now")
	assert_false(rows.add_boarding(R, 0, 6, 5), "ready by after it boards")
	assert_true(rows.add_boarding(R, 0, 0, 0), "now")
	assert_false(rows.add_boarding(R, 0, 0, 50), "the same ready by again")
	assert_false(rows.add_boarding(R, 0, 50, 0), "the same boarding again")
	for k: int in range(1, BoatRows.MAX_BOARDINGS):
		assert_true(rows.add_boarding(R, 0, k * 100, k * 100 + 30), "boarding %d" % k)
	assert_false(rows.add_boarding(R, 0, 5000, 5000), "the ninth")
	assert_equal(rows.board_count[R * 2], BoatRows.MAX_BOARDINGS, "eight at a")
	assert_equal(rows.board_count[R * 2 + 1], 0, "none at b")
	assert_true(rows.offered(R), "offered")


func test_the_first_boarding_is_the_first_the_walker_is_ready_for() -> void:
	"""Exactly at a boarding boards it; a tick late takes the next; after the last, none. A boarding that needs the
	walker there by 50 to board at 130 is missed at 51, though it boards later than that."""
	var rows := _rows([100, 300], [])
	assert_equal(rows.first_boarding(R, 0, 0), 100, "early")
	assert_equal(rows.first_boarding(R, 0, 100), 100, "exactly on time")
	assert_equal(rows.first_boarding(R, 0, 101), 300, "a tick late")
	assert_equal(rows.first_boarding(R, 0, 301), BoatRows.NONE, "after the last")
	assert_equal(rows.first_boarding(R, 1, 0), BoatRows.NONE, "none listed at b")
	assert_true(rows.add_boarding(R, 1, 50, 130), "ready by 50, boarding at 130")
	assert_true(rows.add_boarding(R, 1, 400, 400), "then 400")
	assert_equal(rows.first_boarding(R, 1, 50), 130, "there by 50")
	assert_equal(rows.first_boarding(R, 1, 51), 400, "at 51 the boat was never called")


func test_the_far_label_is_the_boarding_then_the_ride_and_the_limit_is_apart() -> void:
	"""Reached at 7 m (210 ticks) with a boarding at 300: on at 10 m, off at 14 m; reached after the last boarding,
	none. The limit (90) is not the far label's: 6966 mm (208.98 ticks, so 209) waits 91, over it; 6967 mm (210) waits
	90, at it; a boat missed is over it too."""
	var rows := _rows([300], [])
	assert_equal(rows.far_mm(R, 0, 7000), 14000, "wait to 10 m, ride 4 m")
	assert_equal(rows.far_mm(R, 0, 10000), 14000, "on time")
	assert_equal(rows.far_mm(R, 0, 10001), BoatRows.NONE, "missed")
	assert_equal(rows.far_mm(R, 1, 0), BoatRows.NONE, "nothing from b")
	assert_equal(rows.far_mm(R, 0, 6966), 14000, "a long wait is still priced")
	assert_true(rows.over_limit(R, 0, 6966), "a wait of 91: over")
	assert_false(rows.over_limit(R, 0, 6967), "a wait of 90: at the limit")
	assert_false(rows.over_limit(R, 0, 10000), "no wait")
	assert_true(rows.over_limit(R, 0, 10001), "missed")


func test_the_far_label_never_falls_as_the_arrival_rises() -> void:
	"""FIFO (see WHY THE SEARCH STAYS EXACT): over seeded random timetables -- boardings ready by some ticks before they
	board -- and every label from 0 to 60 m in 7 mm steps, the far label never falls, never comes before the label, and
	is NONE only once the walker is ready for no boarding."""
	var rng := RandomNumberGenerator.new()
	rng.seed = 1821
	for round_index: int in 20:
		var rows := BoatRows.new()
		rows.pace_mm_s = 600 + rng.randi_range(0, 600)
		rows.open_row(R, LANDING_A, LANDING_B, rng.randi_range(0, 400), rng.randi_range(0, 400))
		var ready: int = 0
		for k: int in BoatRows.MAX_BOARDINGS:
			ready += rng.randi_range(4, 300)
			rows.add_boarding(R, 0, ready, ready + rng.randi_range(0, 3))
		var last: int = -1
		var falls: int = 0
		for at_mm: int in range(0, 60000, 7):
			var far: int = rows.far_mm(R, 0, at_mm)
			if far == BoatRows.NONE:
				assert_true(BoatRows.ticks_to_cover(at_mm, rows.pace_mm_s) > ready, "none only past the last boarding")
				break
			if far < last or far < at_mm:
				falls += 1
			last = far
		assert_equal(falls, 0, "round %d: never falls" % round_index)


# --- the router -----------------------------------------------------------------------------------------------------

func test_the_router_takes_the_boat_when_it_waits_at_the_landing_for_it() -> void:
	"""Walked to landing a by 7 m (210 ticks), the boat boards at 300 (10 m), rides 4 m, and the walk on is 7 m: 21 m
	all told, against 65 m round the wall. The route's crossing leg is boat row R's, a to b."""
	var out := PackedVector2Array()
	var legs := PackedInt32Array()
	var router: RouterScript = _plan(_rows([300], []), START, GOAL, out, legs)
	assert_equal(_boat_legs(legs, BoatRows.ROW0 + R), 1, "by boat: %s" % legs)
	assert_true(legs.has(RouterScript.crossing_code(BoatRows.ROW0 + R, false)), "a to b")
	assert_almost_equal(router.last_cost_m(), 21.0, "7 + 3 waiting + 4 riding + 7")


func test_a_boat_gone_before_the_walker_gets_there_is_not_taken() -> void:
	"""The only boarding at 200 ticks, the walker at the landing at 210: it walks round the wall."""
	var out := PackedVector2Array()
	var legs := PackedInt32Array()
	var router: RouterScript = _plan(_rows([200], []), START, GOAL, out, legs)
	assert_equal(_boat_legs(legs, BoatRows.ROW0 + R), 0, "by land")
	assert_true(router.last_cost_m() > 60.0, "round the wall (%.1f m)" % router.last_cost_m())


func test_a_wait_over_the_limit_is_not_taken_and_one_at_it_is() -> void:
	"""Reached at 210 ticks: a boarding at 300 is a wait of 90, the limit; at 301, 91, over it."""
	var out := PackedVector2Array()
	var legs := PackedInt32Array()
	_plan(_rows([301], []), START, GOAL, out, legs)
	assert_equal(_boat_legs(legs, BoatRows.ROW0 + R), 0, "91 ticks: by land")
	_plan(_rows([300], []), START, GOAL, out, legs)
	assert_equal(_boat_legs(legs, BoatRows.ROW0 + R), 1, "90 ticks: by boat")


func test_the_way_back_boards_at_landing_b() -> void:
	"""From the goal's side the boat is boarded at landing b, its own timetable: none listed there, by land; listed,
	by boat, b to a."""
	var out := PackedVector2Array()
	var legs := PackedInt32Array()
	_plan(_rows([300], []), GOAL, START, out, legs)
	assert_equal(_boat_legs(legs, BoatRows.ROW0 + R), 0, "nothing boards at b")
	_plan(_rows([], [300]), GOAL, START, out, legs)
	assert_true(legs.has(RouterScript.crossing_code(BoatRows.ROW0 + R, true)), "b to a: %s" % legs)


func test_a_walker_at_the_landing_boards_the_boat_there_now() -> void:
	"""Starting on landing a with a boarding at tick 0: the ride (4 m) and the walk on from landing b (7 m)."""
	var out := PackedVector2Array()
	var legs := PackedInt32Array()
	var router: RouterScript = _plan(_rows([0], []), LANDING_A, GOAL, out, legs)
	assert_equal(_boat_legs(legs, BoatRows.ROW0 + R), 1, "by boat")
	assert_almost_equal(router.last_cost_m(), 11.0, "4 riding + 7")


func test_a_slower_walker_reaches_the_landing_later_and_misses_a_boat_a_faster_one_takes() -> void:
	"""The same 7 m at 700 mm/s takes 300 ticks: a boarding at 299 is gone, while at 1000 mm/s (210) it is taken."""
	var out := PackedVector2Array()
	var legs := PackedInt32Array()
	var rows: BoatRows = _rows([299], [])
	_plan(rows, START, GOAL, out, legs)
	assert_equal(_boat_legs(legs, BoatRows.ROW0 + R), 1, "at 1000 mm/s")
	rows.pace_mm_s = 700
	_plan(rows, START, GOAL, out, legs)
	assert_equal(_boat_legs(legs, BoatRows.ROW0 + R), 0, "at 700 mm/s")


func test_a_boat_row_needs_an_open_row_and_counts_toward_the_cap() -> void:
	"""A closed row, a row out of the table, or no table: nothing offered. A boat row is one of the plan's pairs."""
	var router := RouterScript.new()
	router.clear_pairs()
	var rows := BoatRows.new()
	assert_false(router.add_boat_crossing(BoatRows.ROW0 + R, rows, R), "closed")
	assert_false(router.add_boat_crossing(BoatRows.ROW0 + R, null, R), "no table")
	rows.open_row(R, LANDING_A, LANDING_B, RIDE, MAX_WAIT)
	assert_false(router.add_boat_crossing(BoatRows.ROW0 + R, rows, BoatRows.MAX_ROWS), "out of the table")
	assert_false(router.add_boat_crossing(BoatRows.ROW0 + R, rows, -1), "negative")
	for k: int in RouterScript.MAX_CROSSING_PAIRS - 1:
		assert_true(router.add_crossing(k, Vector2(0.0, float(k)), Vector2(1.0, float(k)), 1.0), "pair %d" % k)
	assert_true(router.add_boat_crossing(BoatRows.ROW0 + R, rows, R), "the last pair")
	assert_false(router.add_boat_crossing(BoatRows.ROW0 + R, rows, R), "one too many")
	assert_equal(router.crossing_count, RouterScript.MAX_CROSSING_PAIRS, "the cap")


func test_a_fixed_crossing_after_a_boat_row_is_priced_as_before() -> void:
	"""A plan that offered a boat row, then a fixed crossing over the same landings at 7 m: the fixed one is priced at
	its cost (7 + 7 + 7 = 21 m), not the timetable's (its landings are not boat landings)."""
	var out := PackedVector2Array()
	var legs := PackedInt32Array()
	var router: RouterScript = _plan(_rows([3000], []), START, GOAL, out, legs)
	router.clear_pairs()
	assert_true(router.add_crossing(5, LANDING_A, LANDING_B, 7.0), "a bridge")
	assert_true(router.plan(_nav, START, GOAL, BODY, PackedVector3Array(), 0, 0, out, legs), "a route")
	assert_equal(_boat_legs(legs, 5), 1, "over the bridge")
	assert_almost_equal(router.last_cost_m(), 21.0, "at its cost")


func test_the_same_plan_twice_gives_the_same_route() -> void:
	"""Determinism: the same inputs, the same waypoints, legs and cost, from fresh routers."""
	var out_a := PackedVector2Array()
	var legs_a := PackedInt32Array()
	var out_b := PackedVector2Array()
	var legs_b := PackedInt32Array()
	var a: RouterScript = _plan(_rows([300, 900], [60]), START, GOAL, out_a, legs_a)
	var b: RouterScript = _plan(_rows([300, 900], [60]), START, GOAL, out_b, legs_b)
	assert_equal(out_a, out_b, "the waypoints")
	assert_equal(legs_a, legs_b, "the legs")
	assert_equal(a.last_cost_m(), b.last_cost_m(), "the cost")


func _walk_m(from: Vector2, to: Vector2) -> float:
	"""The fixture world's planned walk from -> to, metres."""
	var walk := PackedVector2Array()
	_nav.plan(from, to, BODY, PackedVector3Array(), 0, walk)
	var total: float = 0.0
	var at: Vector2 = from
	for point: Vector2 in walk:
		total += at.distance_to(point)
		at = point
	return total


func test_a_wait_within_the_limit_on_the_real_walk_is_taken_though_the_straight_line_would_wait_too_long() -> void:
	"""The review's finding (decision 1821): the wait limit is checked on the found route's exact labels, never on a
	straight-line bound. A short wall between start and goal (by land about 20.3 m), landings well off the line at
	(-8, 6) and (8, 6) -- so no land route through them is ever refined -- and a post between the start and landing a,
	so the real walk there is longer than its straight 6.3 m. The only boarding is 2 ticks after the real arrival, with
	a limit of 5: at the bound's arrival the wait would be over it, at the real one it is 2, and the boat is taken."""
	_nav.setup(PackedVector3Array([Vector3(0.0, 1.0, 0.0), Vector3(-9.0, 0.6, 3.0)]))
	var a := Vector2(-8.0, 6.0)
	var real_m: float = _walk_m(START, a)
	var arrive: int = BoatRows.ticks_to_cover(ceili(real_m * 1000.0), PACE)
	assert_true(arrive - BoatRows.ticks_to_cover(ceili(START.distance_to(a) * 1000.0), PACE) > 5,
		"round the post (%.2f m): the bound arrives more than the limit early" % real_m)
	for wait: int in [2, 6]:
		var rows := BoatRows.new()
		rows.pace_mm_s = PACE
		rows.open_row(R, a, Vector2(8.0, 6.0), RIDE, 5)
		rows.add_boarding(R, 0, arrive + wait, arrive + wait)
		var router := RouterScript.new()
		router.clear_pairs()
		router.add_boat_crossing(BoatRows.ROW0 + R, rows, R)
		var out := PackedVector2Array()
		var legs := PackedInt32Array()
		assert_true(router.plan(_nav, START, GOAL, BODY, PackedVector3Array(), 0, 0, out, legs), "a route")
		assert_equal(_boat_legs(legs, BoatRows.ROW0 + R), 1 if wait == 2 else 0, "a wait of %d (limit 5)" % wait)


func test_a_landing_label_is_read_in_whole_millimetres_rounded_up() -> void:
	"""From 6.9665 m before landing a (6966.5 mm: 6967 rounded up, 210 ticks) the boarding at 300 is a wait of 90, at
	the limit; rounded down (6966, 209 ticks) it would be 91, over it."""
	var out := PackedVector2Array()
	var legs := PackedInt32Array()
	_plan(_rows([300], []), LANDING_A - Vector2(6.9665, 0.0), GOAL, out, legs)
	assert_equal(_boat_legs(legs, BoatRows.ROW0 + R), 1, "by boat")


func test_one_plans_boat_rows_come_from_one_table() -> void:
	"""A second table's row offered to the same plan is refused, said once; after `clear_pairs` it may be offered."""
	var router := RouterScript.new()
	router.clear_pairs()
	var first: BoatRows = _rows([300], [])
	var second: BoatRows = _rows([300], [])
	assert_true(router.add_boat_crossing(BoatRows.ROW0 + R, first, R), "the first table")
	expect_diagnostic("one plan's boat rows come from one table")
	assert_false(router.add_boat_crossing(BoatRows.ROW0 + R, second, R), "a second table refused")
	router.clear_pairs()
	assert_true(router.add_boat_crossing(BoatRows.ROW0 + R, second, R), "a new plan")


# --- the water's boat rows ------------------------------------------------------------------------------------------

func _fixture_boat(crossings: CrossingsScript) -> FixtureBoat:
	"""A fixture boat between the west and east banks of the run, served on the first row after the ferry's."""
	var boat := FixtureBoat.new()
	boat.end_a = WEST_BANK
	boat.end_b = EAST_BANK
	assert_equal(crossings.add_boat_service(boat), BoatRows.ROW0 + 1, "the first row after the ferry's")
	return boat


func test_a_boat_service_is_offered_to_a_carrier_across_the_run_from_the_landing_it_boards() -> void:
	"""On the village water a carrier from the west bank to the east bank is offered no swim and no bridge. A fixture
	boat with no boarding is not offered; boarding only at the far bank, it is offered but not taken; boarding now at
	this bank, it is taken (row 3501) and read "by boat"; and the carrier's pace reaches the table."""
	var play: WaterplayScript = _village()
	var crossings: CrossingsScript = play.crossings
	assert_false(crossings.offers_for(0, WEST_BANK, EAST_BANK, true), "no boat yet: nothing for a carrier")
	var boat: FixtureBoat = _fixture_boat(crossings)
	var row: int = BoatRows.ROW0 + 1
	assert_false(crossings.offers_for(0, WEST_BANK, EAST_BANK, true), "no boarding listed: not offered")
	boat.at_b = PackedInt64Array([0])
	assert_true(crossings.offers_for(0, WEST_BANK, EAST_BANK, true), "a boarding at the far bank: offered")
	var space: CastSpaceScript = _cast.space()
	var path := PackedVector2Array()
	var legs := PackedInt32Array()
	space.plan_path(0, WEST_BANK, EAST_BANK, 0.22, path, legs, true, true)
	assert_equal(_boat_legs(legs, row), 0, "but none boards at this bank: by land")
	boat.at_b = PackedInt64Array()
	boat.at_a = PackedInt64Array([0])
	(_cast.actor(0) as DemoActorScript).brain.walk_speed = 0.7
	assert_true(crossings.offers_for(0, WEST_BANK, EAST_BANK, true), "a boarding now: offered")
	assert_equal(crossings.boat_rows.pace_mm_s, 700, "the carrier's pace (a placeholder carries at its walk)")
	space.plan_path(0, WEST_BANK, EAST_BANK, 0.22, path, legs, true, true)
	assert_equal(_boat_legs(legs, row), 1, "the carrier goes by boat: %s" % legs)
	assert_true(KindsScript.new().has_kind(WEST_BANK, path, legs, KindsScript.KIND_BOAT), "read by boat")


func test_a_boat_rows_leg_is_its_services() -> void:
	"""Begun, stepped, its words and abandoned by the service; never turned back mid-swim; its ends the service's."""
	var play: WaterplayScript = _village()
	var crossings: CrossingsScript = play.crossings
	var boat: FixtureBoat = _fixture_boat(crossings)
	var row: int = BoatRows.ROW0 + 1
	var brain: BrainScript = (_cast.actor(0) as DemoActorScript).brain
	crossings.begin_leg(brain, row, false)
	assert_true(crossings.step_leg(brain, 0.1), "stepped by the service: over")
	assert_equal(crossings.leg_text(brain), "aboard the fixture boat", "its words")
	assert_false(crossings.turn_back(brain), "a boat row is never turned back")
	crossings.abandon_leg(brain)
	assert_equal(boat.calls, PackedStringArray(["begin false", "step", "abandon"]), "every leg call reached it")
	assert_equal(crossings.end_point(row, true), EAST_BANK, "its far end")
	assert_equal(crossings.end_point(row, false), WEST_BANK, "its near end")


func test_a_row_its_service_leaves_closed_is_not_offered_from_a_trip_before() -> void:
	"""Each trip's rows are cleared before their services fill them: a boat offered to one trip and closed for the
	next (its service returns before opening) is not offered to the next."""
	var play: WaterplayScript = _village()
	var crossings: CrossingsScript = play.crossings
	var boat: FixtureBoat = _fixture_boat(crossings)
	boat.at_a = PackedInt64Array([0])
	assert_true(crossings.offers_for(0, WEST_BANK, EAST_BANK, true), "offered")
	boat.closed = true
	assert_false(crossings.offers_for(1, WEST_BANK, EAST_BANK, true), "closed: not offered")
	assert_false(crossings.boat_rows.offered(1), "the row left closed")


func test_every_boat_row_after_the_ferrys_can_be_served_and_no_more() -> void:
	"""Rows 3501..3507 are given in turn, even before the water is configured; the eighth service finds none. Row 0 is
	the ferry's, and empty without one."""
	var bare := CrossingsScript.new()
	assert_equal(bare.add_boat_service(FixtureBoat.new()), BoatRows.ROW0 + 1, "before configure")
	var play: WaterplayScript = _village()
	var crossings: CrossingsScript = play.crossings
	for r: int in range(1, BoatRows.MAX_ROWS):
		assert_equal(crossings.add_boat_service(FixtureBoat.new()), BoatRows.ROW0 + r, "row %d" % r)
	assert_equal(crossings.add_boat_service(FixtureBoat.new()), -1, "every row served")
	assert_null(crossings.boat_service(CrossingsScript.FERRY_BOAT_ROW), "no ferry, no row 0 service")
	assert_null(crossings.boat_service(BoatRows.MAX_ROWS), "out of the table")
	assert_null(crossings.boat_service(-1), "negative")


func test_a_walkers_pace_for_the_boat_rows_is_the_pace_it_walks() -> void:
	"""Its walk speed in mm/s (resident_brain.gd `base_speed`); a placeholder with no carry clip carries at its walk, one
	with one at the carry's own pace; never zero."""
	var play: WaterplayScript = _village()
	var brain: BrainScript = (_cast.actor(0) as DemoActorScript).brain
	brain.walk_speed = 0.8
	assert_equal(play.crossings.pace_mm_s(0, false), 800, "walking")
	assert_equal(play.crossings.pace_mm_s(0, true), 800, "carrying, with no carry clip")
	assert_equal(brain.base_speed(true), brain.walk_speed, "the brain's own reading")
	brain._carry_speed = 0.5
	assert_equal(play.crossings.pace_mm_s(0, true), 500, "carrying at its carry clip's pace")
	assert_equal(play.crossings.pace_mm_s(0, false), 800, "walking unladen at its walk")
	brain._carry_speed = 0.0
	brain.walk_speed = 0.0
	assert_equal(play.crossings.pace_mm_s(0, false), 1, "never zero")


# --- perf -----------------------------------------------------------------------------------------------------------

func _plan_quietly(router: RouterScript, rows: BoatRows, out: PackedVector2Array, legs: PackedInt32Array) -> void:
	"""One plan from START to GOAL with boat row R of `rows` offered, or (`rows` null) a fixed crossing of 7 m over the
	same landings; nothing asserted."""
	router.clear_pairs()
	if rows != null:
		router.add_boat_crossing(BoatRows.ROW0 + R, rows, R)
	else:
		router.add_crossing(BoatRows.ROW0 + R, LANDING_A, LANDING_B, 7.0)
	router.plan(_nav, START, GOAL, BODY, PackedVector3Array(), 0, 0, out, legs)


func test_a_boat_row_costs_a_plan_no_more_than_a_fixed_crossing_and_creates_no_object() -> void:
	"""Perf (decisions 1001-1004): the same trip over the same landings, timed (boat row) and fixed (a crossing of the
	same cost), through the same helper in interleaved batches on warm caches: the best boat batch is within 1.3 times
	the best fixed batch (plus 0.3 ms for the clock); and 50 boat plans create no Object (packed scratch is sized once
	in the router's and the table's _init; OBJECT_COUNT does not see packed arrays)."""
	var boat_router := RouterScript.new()
	var fixed_router := RouterScript.new()
	var rows: BoatRows = _rows([300], [])
	var out := PackedVector2Array()
	var legs := PackedInt32Array()
	var best: PackedInt64Array = PackedInt64Array([1 << 40, 1 << 40])
	for batch: int in 6:
		for side: int in 2:
			var t0: int = Time.get_ticks_usec()
			for k: int in 40:
				_plan_quietly(boat_router if side == 0 else fixed_router, rows if side == 0 else null, out, legs)
			if batch > 0:
				best[side] = mini(best[side], Time.get_ticks_usec() - t0)
	@warning_ignore("integer_division") var allowed: int = best[1] * 13 / 10 + 300
	assert_true(best[0] <= allowed, "40 boat plans %d us, 40 fixed %d us" % [best[0], best[1]])
	assert_equal(_boat_legs(legs, BoatRows.ROW0 + R), 1, "the fixed crossing taken")
	_plan_quietly(boat_router, rows, out, legs)
	assert_equal(_boat_legs(legs, BoatRows.ROW0 + R), 1, "the boat taken")
	var objects: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	for k: int in 50:
		_plan_quietly(boat_router, rows, out, legs)
	assert_equal(int(Performance.get_monitor(Performance.OBJECT_COUNT)), objects, "no object created")
