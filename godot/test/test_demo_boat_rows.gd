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
	var calls: PackedStringArray = PackedStringArray()

	func fill_boat_row(rows: BoatRowsTable, r: int, _walker: int, _from: Vector2, _loaded: bool) -> void:
		"""Open between its ends with its boardings (none listed: not offered)."""
		rows.open_row(r, end_a, end_b, ride, limit)
		for tick: int in at_a:
			rows.add_boarding(r, 0, tick)
		for tick: int in at_b:
			rows.add_boarding(r, 1, tick)

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
	"""A table with fixture row R open between the landings, its ride RIDE, at PACE, with these boardings."""
	var rows := BoatRows.new()
	rows.pace_mm_s = PACE
	rows.open_row(R, LANDING_A, LANDING_B, RIDE, max_wait)
	for tick: int in at_a:
		assert_true(rows.add_boarding(R, 0, tick), "boarding %d at a" % tick)
	for tick: int in at_b:
		assert_true(rows.add_boarding(R, 1, tick), "boarding %d at b" % tick)
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
	assert_equal(BoatRows.ticks_to_cover(-5, 800), 0, "never negative")
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


func test_boardings_are_listed_strictly_ascending_and_at_most_eight() -> void:
	"""A closed row lists nothing; a boarding not after the last, or negative, is refused; the ninth is refused."""
	var rows := BoatRows.new()
	assert_false(rows.add_boarding(R, 0, 10), "closed")
	rows.open_row(R, LANDING_A, LANDING_B, RIDE, MAX_WAIT)
	assert_false(rows.offered(R), "open with no boarding: not offered")
	rows.open_row(R + 1, LANDING_A, LANDING_B, -5, -7)
	assert_equal(rows.ride_ticks[R + 1], 0, "a ride is never negative")
	assert_equal(rows.max_wait_ticks[R + 1], 0, "nor a wait limit")
	assert_false(rows.add_boarding(R, 0, -1), "negative")
	assert_true(rows.add_boarding(R, 0, 0), "now")
	assert_false(rows.add_boarding(R, 0, 0), "the same tick again")
	for k: int in range(1, BoatRows.MAX_BOARDINGS):
		assert_true(rows.add_boarding(R, 0, k * 100), "boarding %d" % k)
	assert_false(rows.add_boarding(R, 0, 5000), "the ninth")
	assert_equal(rows.board_count[R * 2], BoatRows.MAX_BOARDINGS, "eight at a")
	assert_equal(rows.board_count[R * 2 + 1], 0, "none at b")
	assert_true(rows.offered(R), "offered")
	rows.clear_row(R)
	assert_false(rows.offered(R), "cleared")
	assert_equal(rows.board_count[R * 2], 0, "cleared at a")


func test_the_first_boarding_is_the_one_at_or_after_the_arrival() -> void:
	"""Exactly at a boarding boards it; a tick late takes the next; after the last, none."""
	var rows := _rows([100, 300], [])
	assert_equal(rows.first_boarding(R, 0, 0), 100, "early")
	assert_equal(rows.first_boarding(R, 0, 100), 100, "exactly on time")
	assert_equal(rows.first_boarding(R, 0, 101), 300, "a tick late")
	assert_equal(rows.first_boarding(R, 0, 301), BoatRows.NONE, "after the last")
	assert_equal(rows.first_boarding(R, 1, 0), BoatRows.NONE, "none listed at b")


func test_the_far_label_is_the_boarding_then_the_ride() -> void:
	"""Reached at 7 m (210 ticks) with a boarding at 300: on at 10 m, off at 14 m. Reached later than every boarding,
	or the wait over the row's limit (90), no crossing; exactly the limit boards. Closed: none."""
	var rows := _rows([300], [])
	assert_equal(rows.far_mm(R, 0, 7000), 14000, "wait to 10 m, ride 4 m")
	assert_equal(rows.far_mm(R, 0, 10000), 14000, "on time")
	assert_equal(rows.far_mm(R, 0, 10001), BoatRows.NONE, "missed")
	assert_equal(rows.far_mm(R, 0, 6967), 14000, "6967 mm is 209.01 ticks, so 210: a wait of 90")
	assert_equal(rows.far_mm(R, 0, 6966), BoatRows.NONE, "6966 mm is 208.98 ticks, so 209: a wait of 91, over the limit")
	assert_equal(rows.far_mm(R, 1, 0), BoatRows.NONE, "nothing from b")
	rows.clear_row(R)
	assert_equal(rows.far_mm(R, 0, 7000), BoatRows.NONE, "closed")


func test_the_far_label_never_falls_as_the_arrival_rises() -> void:
	"""FIFO (see WHY THE SEARCH STAYS EXACT): over a seeded random timetable and every label from 0 to 60 m in 7 mm
	steps, the far label never falls, never comes before the label, and is NONE only past the last boarding in reach."""
	var rng := RandomNumberGenerator.new()
	rng.seed = 1821
	for round_index: int in 20:
		var rows := BoatRows.new()
		rows.pace_mm_s = 600 + rng.randi_range(0, 600)
		rows.open_row(R, LANDING_A, LANDING_B, rng.randi_range(0, 400), BoatRows.MAX_BOARDINGS * 300)
		var tick: int = 0
		for k: int in BoatRows.MAX_BOARDINGS:
			tick += rng.randi_range(1, 300)
			rows.add_boarding(R, 0, tick)
		var last: int = -1
		var falls: int = 0
		for at_mm: int in range(0, 60000, 7):
			var far: int = rows.far_mm(R, 0, at_mm)
			if far == BoatRows.NONE:
				assert_true(BoatRows.ticks_to_cover(at_mm, rows.pace_mm_s) > tick, "none only past the last boarding")
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


# --- the water's boat rows ------------------------------------------------------------------------------------------

func test_a_boat_service_is_offered_to_a_carrier_across_the_run_and_its_leg_is_the_services() -> void:
	"""On the village water a carrier from the west bank to the east bank is offered no swim and no bridge: by land. A
	fixture boat between the banks, boarding now, is offered (row 3501, the first after the ferry's), taken and read
	"by boat"; its leg is the service's -- begun, stepped, its words, abandoned -- and never turned back mid-swim."""
	var play: WaterplayScript = _village()
	var crossings: CrossingsScript = play.crossings
	assert_false(crossings.offers_for(0, WEST_BANK, EAST_BANK, true), "no boat yet: nothing for a carrier")
	var boat := FixtureBoat.new()
	boat.end_a = WEST_BANK
	boat.end_b = EAST_BANK
	var row: int = crossings.add_boat_service(boat)
	assert_equal(row, BoatRows.ROW0 + 1, "the first row after the ferry's")
	assert_false(crossings.offers_for(0, WEST_BANK, EAST_BANK, true), "no boarding listed: not offered")
	boat.at_b = PackedInt64Array([0])
	assert_true(crossings.offers_for(0, WEST_BANK, EAST_BANK, true), "a boarding at the far bank: offered")
	var cast: DemoCastScript = _cast
	var space: CastSpaceScript = cast.space()
	var path := PackedVector2Array()
	var legs := PackedInt32Array()
	space.plan_path(0, WEST_BANK, EAST_BANK, 0.22, path, legs, true, true)
	assert_equal(_boat_legs(legs, row), 0, "but none boards at this bank: by land")
	boat.at_b = PackedInt64Array()
	boat.at_a = PackedInt64Array([0])
	assert_true(crossings.offers_for(0, WEST_BANK, EAST_BANK, true), "a boarding now: offered")
	space.plan_path(0, WEST_BANK, EAST_BANK, 0.22, path, legs, true, true)
	assert_equal(_boat_legs(legs, row), 1, "the carrier goes by boat: %s" % legs)
	var kinds := KindsScript.new()
	assert_true(kinds.has_kind(WEST_BANK, path, legs, KindsScript.KIND_BOAT), "read by boat")
	var brain: BrainScript = (cast.actor(0) as DemoActorScript).brain
	crossings.begin_leg(brain, row, false)
	assert_true(crossings.step_leg(brain, 0.1), "stepped by the service: over")
	assert_equal(crossings.leg_text(brain), "aboard the fixture boat", "its words")
	assert_false(crossings.turn_back(brain), "a boat row is never turned back")
	crossings.abandon_leg(brain)
	assert_equal(boat.calls, PackedStringArray(["begin false", "step", "abandon"]), "every leg call reached it")
	assert_equal(crossings.end_point(row, true), EAST_BANK, "its far end")


func test_every_boat_row_after_the_ferrys_can_be_served_and_no_more() -> void:
	"""Rows 3501..3507 are given in turn; the eighth service finds none. Row 0 is the ferry's, and empty without one."""
	var play: WaterplayScript = _village()
	var crossings: CrossingsScript = play.crossings
	for r: int in range(1, BoatRows.MAX_ROWS):
		assert_equal(crossings.add_boat_service(FixtureBoat.new()), BoatRows.ROW0 + r, "row %d" % r)
	assert_equal(crossings.add_boat_service(FixtureBoat.new()), -1, "every row served")
	assert_null(crossings.boat_service(CrossingsScript.FERRY_BOAT_ROW), "no ferry, no row 0 service")
	assert_null(crossings.boat_service(BoatRows.MAX_ROWS), "out of the table")
	assert_null(crossings.boat_service(-1), "negative")


func test_a_walkers_pace_for_the_boat_rows_is_its_walk_and_a_carriers_share() -> void:
	"""Its walk speed in mm/s; loaded, CARRY_WALK_FRACTION of it (0.65), as the ferry always priced a load."""
	var play: WaterplayScript = _village()
	var brain: BrainScript = (_cast.actor(0) as DemoActorScript).brain
	brain.walk_speed = 0.8
	assert_equal(play.crossings.pace_mm_s(0, false), 800, "walking")
	assert_equal(play.crossings.pace_mm_s(0, true), 520, "carrying")
	brain.walk_speed = 0.0
	assert_equal(play.crossings.pace_mm_s(0, false), 1, "never zero")


# --- perf -----------------------------------------------------------------------------------------------------------

func test_a_boat_row_costs_a_plan_no_more_than_a_fixed_crossing_and_allocates_nothing() -> void:
	"""Perf (decisions 1001-1004): the same trip over the same landings, timed (boat row) and fixed (a crossing of the
	same cost), planned in interleaved batches on warm caches: the best boat batch is within 1.3 times the best fixed
	batch (plus 0.3 ms for the clock); and 50 boat plans create no object."""
	var boat_router := RouterScript.new()
	var fixed_router := RouterScript.new()
	var rows: BoatRows = _rows([300], [])
	var out := PackedVector2Array()
	var legs := PackedInt32Array()
	var best_boat: int = 1 << 40
	var best_fixed: int = 1 << 40
	for batch: int in 6:
		var t0: int = Time.get_ticks_usec()
		for k: int in 40:
			_plan(rows, START, GOAL, out, legs, boat_router)
		var t1: int = Time.get_ticks_usec()
		for k: int in 40:
			fixed_router.clear_pairs()
			fixed_router.add_crossing(BoatRows.ROW0 + R, LANDING_A, LANDING_B, 7.0)
			fixed_router.plan(_nav, START, GOAL, BODY, PackedVector3Array(), 0, 0, out, legs)
		var t2: int = Time.get_ticks_usec()
		if batch > 0:
			best_boat = mini(best_boat, t1 - t0)
			best_fixed = mini(best_fixed, t2 - t1)
	@warning_ignore("integer_division") var allowed: int = best_fixed * 13 / 10 + 300
	assert_true(best_boat <= allowed, "40 boat plans %d us, 40 fixed %d us" % [best_boat, best_fixed])
	var objects: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	for k: int in 50:
		_plan(rows, START, GOAL, out, legs, boat_router)
	assert_equal(int(Performance.get_monitor(Performance.OBJECT_COUNT)), objects, "no object created")
