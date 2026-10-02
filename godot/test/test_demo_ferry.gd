extends "res://test/framework/test_case.gd"
## The ferry (decision 0437; review ECO-041, water part B lane 3): its fixed two-landing geometry, the timetable and the
## departure threshold, the far copse's windfall, whole crossings on real brains walking the real village layout -- the
## windfall gathered, ferried and stacked as the stores' wood -- the weather closure (a storm before departure and
## mid-crossing), the passenger seat the router chooses, the boat given back between crossings (the rescue may take
## it), the work board, and THE BOOKS conserved through every cancel, closure and interruption.
##
## Built over the placeholder cast on the real layout and the real village water (as test_demo_fishery.gd) -- no staged
## assets, no scene tree. Expected numbers are restated from their sources (ferry_rules.gd's named demo values, the
## woods' deadfall numbers, the boat core's).

const SimClock := preload("res://scripts/core/sim_clock.gd")
const WeatherCore := preload("res://scripts/core/weather.gd")
const Rules := preload("res://demo/ferry/ferry_rules.gd")
const FerryScript := preload("res://demo/ferry/ferry.gd")
const ViewScript := preload("res://demo/ferry/ferry_view.gd")
const FisheryScript := preload("res://demo/fishery/fishery.gd")
const FisheryRules := preload("res://demo/fishery/fishery_rules.gd")
const FleetScript := preload("res://demo/boats/boat_fleet.gd")
const Routes := preload("res://demo/boats/boat_routes.gd")
const BoatRescueScript := preload("res://demo/boats/boat_rescue.gd")
const Driver := preload("res://demo/water/fishing_driver.gd")
const PantryScript := preload("res://demo/farm/farm_pantry.gd")
const StorageScript := preload("res://demo/farm/farm_storage.gd")
const TakesScript := preload("res://demo/kitchen/ingredient_takes.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const DemoWeatherScript := preload("res://demo/weather/demo_weather.gd")
const ServicesScript := preload("res://demo/demo_services.gd")
const WaterLayout := preload("res://demo/water/water_layout.gd")
const WaterMapScript := preload("res://demo/water/water_map.gd")
const WaterDressing := preload("res://demo/water/water_dressing.gd")
const WaterplayScript := preload("res://demo/waterplay/demo_waterplay.gd")
const CrossingsScript := preload("res://demo/waterplay/water_crossings.gd")
const DemoWorldScript := preload("res://demo/world/demo_world.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const RouterScript := preload("res://demo/tunnel/tunnel_router.gd")
const WorkIds := preload("res://demo/work/work_ids.gd")
const FerryWork := preload("res://demo/work/ferry_work.gd")
const TaskRecord := preload("res://demo/work/work_task.gd")
const KindsScript := preload("res://demo/routes/route_kinds.gd")
const ReasonsScript := preload("res://demo/routes/route_reasons.gd")
const DemoFarmScript := preload("res://demo/farm/demo_farm.gd")
const Layout := preload("res://demo/world/world_layout.gd")
const ForestRules := preload("res://demo/forestry/forest_rules.gd")

const DT: float = 0.1
const MAX_FRAMES: int = 9000

## The rig: the placeholder cast on the village water, the water's play, the fishery (its fleet, skills and ice) and the
## ferry over them.
class Rig:
	var cast: DemoCastScript = null
	var play: WaterplayScript = null
	var fishery: FisheryScript = null
	var ferry: FerryScript = null
	var calendar: CalendarScript = null
	var weather: DemoWeatherScript = null
	var driver: Driver = null
	var boats: BoatRescueScript = null

static var _map_cache: WaterMapScript = null

var _nodes: Array[Object] = []
## Every rig a test built: its ferry's `flooded` lambda holds the rig, which holds the ferry -- a cycle `after_each`
## breaks (decision 0501).
var _rigs: Array[Rig] = []
var _services: ServicesScript = null
## Whether every frame of the last `_run` kept THE BOOKS.
var _books_kept: bool = true


func before_each() -> void:
	"""Fresh demo services per test."""
	_services = ServicesScript.new()


func after_each() -> void:
	"""Free every node a test built, and let each rig's ferry drop the lambda that holds the rig."""
	for node: Object in _nodes:
		if is_instance_valid(node) and node is Node:
			node.free()
	_nodes.clear()
	for rig: Rig in _rigs:
		if rig.ferry != null:
			rig.ferry.flooded = Callable()
	_rigs.clear()


# --- fixtures -------------------------------------------------------------------------------------

func _keep(node: Object) -> Object:
	"""Free `node` after the test."""
	_nodes.append(node)
	return node


static func _map() -> WaterMapScript:
	"""The village's water, built once (immutable once finalised)."""
	if _map_cache == null:
		_map_cache = WaterLayout.make_map()
	return _map_cache


func _rig(hour: int = 9) -> Rig:
	"""The placeholder cast walking the real layout round the water's band, the water's play, the fishery and the ferry,
	the calendar at `hour` on spring day 1, a mild day."""
	var world: DemoWorldScript = _keep(DemoWorldScript.new()) as DemoWorldScript
	var circles: Array[Vector3] = world.obstacles()
	circles.append_array(WaterDressing.obstacles())
	circles.append_array(WaterplayScript.land_obstacles())
	var links := WaterplayScript.make_links(_map(), circles)
	circles.append_array(links.band)
	var rig := Rig.new()
	rig.cast = _keep(DemoCastScript.new()) as DemoCastScript
	rig.cast.build({}, world.points_of_interest(), circles, links.area)
	rig.cast.set_bounds(WaterplayScript.walk_bounds(world.bounds()))
	rig.play = _keep(WaterplayScript.new()) as WaterplayScript
	rig.play.configure(rig.cast, null, null, _services, _map(), links)
	_fishery_over(rig, hour)
	rig.ferry = FerryScript.new()
	rig.ferry.configure(rig.cast, rig.fishery.fleet, rig.fishery.skills, rig.fishery.ice, _services.stores, rig.calendar,
		rig.weather, _map())
	rig.ferry.flooded = func() -> bool: return rig.play.motion.flood_permille > 0
	_rigs.append(rig)
	rig.play.crossings.ferry = rig.ferry
	return rig


func _fishery_over(rig: Rig, hour: int) -> void:
	"""The fishery (the ferry shares its fleet, skills and ice) and its boat rescue on the rig."""
	var ids: Driver.IdsResult = Driver.resolve_species_item_ids()
	assert_true(ids.ok, "the nine fish items bind")
	rig.driver = Driver.create(ids.ids, 0, 4403).driver as Driver
	rig.calendar = CalendarScript.new()
	rig.calendar.tick = (hour - 6) * SimClock.TICKS_PER_HOUR
	rig.weather = DemoWeatherScript.new()
	rig.weather.observe(0, 1, hour, 120, 0, WeatherCore.EVENT_NONE)
	var pantry := PantryScript.new(StorageScript.new(DemoFarmScript.store_position(rig.cast)))
	rig.fishery = FisheryScript.new()
	rig.fishery.configure(rig.cast, rig.driver, pantry, TakesScript.new(), _services.stores, rig.calendar, rig.weather, _map())
	rig.boats = BoatRescueScript.new()
	rig.boats.configure(rig.fishery.fleet, _map(), rig.fishery.skills.can_helm)
	rig.play.rescue.boats = rig.boats


func _run(rig: Rig, done: Callable, frames: int = MAX_FRAMES, board: bool = true) -> bool:
	"""Step the cast, the calendar, the water, the fishery (it rows the fleet) and the ferry until `done()` (bounded),
	the work board's part each 20 frames; THE BOOKS checked every frame (`_books_kept`)."""
	_books_kept = true
	for frame: int in frames:
		if bool(done.call()):
			return true
		if board and frame % 20 == 0:
			_board_pass(rig)
		rig.cast.advance(DT)
		var usec: int = rig.cast.clock.frame_usec
		rig.calendar.tick += rig.calendar.ticks_for_usec(usec)
		rig.play.step(usec)
		rig.fishery.update(usec)
		rig.ferry.update(usec)
		if not rig.ferry.books_balance():
			_books_kept = false
		if OS.get_environment("FERRY_DEBUG") == "1" and frame % 300 == 0:
			_debug(rig, frame)
	return bool(done.call())


func _board_pass(rig: Rig) -> void:
	"""The work board's part (decision 0411): each waiting job to the first idle resident who may take it."""
	var f: FerryScript = rig.ferry
	for j: int in FerryScript.MAX_JOBS:
		if not f.waiting(j):
			continue
		for who: int in rig.cast.actor_count():
			var brain: BrainScript = f.brain_of(who)
			if brain.order == BrainScript.ORDER_NONE and not brain.in_water and f.eligibility(j, who).is_empty() and f.claim(j, who):
				break


func _debug(rig: Rig, frame: int) -> void:
	"""Print the ferry's state and every live job (FERRY_DEBUG=1)."""
	var f: FerryScript = rig.ferry
	printerr("##FERRY## f%d x %d/%d stage %d words '%s' far %d aboard %d near %d stored %d boat %d/%d %s" % [frame,
		f.x_serial, f.x_state, f.x_stage, f.x_words, f.far_stack_milli, f.aboard_milli, f.near_stack_milli, f.stored_milli,
		f.fleet.phase[Routes.FERRY_BOAT], f.fleet.owner[Routes.FERRY_BOAT], f.fleet.position_m(Routes.FERRY_BOAT)])
	for j: int in FerryScript.MAX_JOBS:
		if f.j_live[j] == 1:
			var w: int = f.j_worker[j]
			var b: BrainScript = f.brain_of(w) if w >= 0 else null
			printerr("##FERRY##   job %d kind %d step %d w %d load %d goal %s words '%s' %s" % [j, f.j_kind[j], f.j_step[j], w,
				f.j_load[j], f.j_goal[j], f.j_words[j], ("state %d pos %s out %d" % [b.state, b.position, b.trip_outcome]) if b != null else ""])


func _helm(rig: Rig, who: int, level: int) -> void:
	"""Give placeholder `who` FISH `level` (the placeholders start at 0)."""
	rig.fishery.skills.xp[who] = level * level * 5000


func _storm(rig: Rig, on: bool) -> void:
	"""A storm (§5.10's heavy rain) comes up, or passes."""
	rig.weather.observe(0, 1, 12, 120, 2400 if on else 0, WeatherCore.EVENT_HEAVY_RAIN if on else WeatherCore.EVENT_NONE)


func _free_jobs(rig: Rig) -> int:
	"""Live ferry jobs."""
	return rig.ferry.job_count()


# --- the geography and the numbers ---------------------------------------------------------------------

func test_the_stages_and_route_are_boat_water_outside_every_building() -> void:
	"""Both stages are lane 1's jetty pattern -- land end dry on the bank top, deck end over water -- outside every
	building's footprint, and the ferry's route from its berth is boat water all the way (`validate`)."""
	assert_equal(Routes.validate(_map()), "", "every route, berth and jetty valid")
	assert_equal(Routes.BERTH_COUNT, 3, "a third berth for the ferry boat")
	assert_equal(Routes.FISHING_BOATS, 2, "the boathouse keeps its two")
	assert_equal(Routes.BERTH_JETTY[Routes.FERRY_BOAT], 1, "the ferry boat boards from the ferry stage")
	for jetty: int in [1, 2]:
		var land: Vector2 = Routes.jetty_land_m(jetty)
		assert_false(_map().is_water(Routes.JETTY_LANDS_U[jetty]), "%s's land end is dry" % Routes.JETTY_NAMES[jetty])
		assert_true(_map().is_water(Routes.JETTY_ENDS_U[jetty]), "%s's end is over water" % Routes.JETTY_NAMES[jetty])
		for circle: Vector3 in WaterDressing.footprint_circles():
			assert_true(Vector2(circle.x, circle.y).distance_to(land) > circle.z, "%s clear of a footprint" % Routes.JETTY_NAMES[jetty])
	var course := Routes.route(Routes.FERRY_BOAT)
	assert_equal(Vector2i(course[0], course[1]), Routes.BERTH_U[Routes.FERRY_BOAT], "the route starts at the ferry berth")
	assert_true(_map().depth_at(Routes.BERTH_U[Routes.FERRY_BOAT]) >= Routes.BOAT_DRAFT_U, "the ferry berth floats a boat")
	assert_true(_map().depth_at(Routes.route_point(Routes.FERRY_BOAT, Routes.route_points(Routes.FERRY_BOAT) - 1)) >= Routes.BOAT_DRAFT_U,
		"the far berth floats a boat")
	assert_equal(Routes.STATION_NAMES[Routes.FERRY_BOAT], Routes.FAR_STAGE_NAME, "its station is the far stage")


func test_the_timetable_departs_every_two_hours_by_day() -> void:
	"""Departures 06:00 to 18:00 every two game hours on exact ticks; none at night."""
	var six: int = Rules.hour_tick(6)
	assert_equal(Rules.departure_tick_at_or_after(six), six, "06:00 itself")
	assert_equal(Rules.departure_tick_at_or_after(six + 1), Rules.hour_tick(8), "just after: 08:00")
	assert_equal(Rules.departure_tick_at_or_after(Rules.hour_tick(17)), Rules.hour_tick(18), "17:00: the 18:00")
	assert_equal(Rules.departure_tick_at_or_after(Rules.hour_tick(18) + 1), Rules.hour_tick(24 + 6), "after the last: tomorrow's 06:00")
	assert_true(Rules.is_departure_hour(10) and not Rules.is_departure_hour(11) and not Rules.is_departure_hour(20),
		"even hours by day only")
	assert_equal(Rules.THRESHOLD_MILLI, 4000, "the departure threshold, 4 U")
	assert_equal(Rules.BOAT_CARGO_MILLI, 12000, "a crossing carries 12 U")


func test_the_far_copse_follows_the_woods_deadfall_numbers() -> void:
	"""Its piles are the woods' 1.0..2.0 U in 0.25 U steps, gathered at 20 WU a U; two lie at the start, one falls each
	midnight on the next empty spot."""
	for day: int in 40:
		var milli: int = Rules.pile_milli(day)
		assert_true(milli >= ForestRules.DEADFALL_MIN_MILLI and milli <= ForestRules.DEADFALL_MAX_MILLI, "day %d in range" % day)
		assert_equal(milli % ForestRules.DEADFALL_STEP_MILLI, 0, "day %d in 0.25 U steps" % day)
	assert_equal(Rules.gather_mwu(1500), 30000, "1.5 U is 30 WU")
	var rig: Rig = _rig()
	assert_equal(rig.ferry.pile_count(), 2, "two piles at the start")
	assert_equal(rig.ferry.fallen_milli, 2750, "1.5 + 1.25 U fallen")
	assert_true(rig.ferry.books_balance(), "the books open balanced")
	rig.calendar.tick = Rules.hour_tick(24) + 1
	rig.ferry.update(0)
	assert_equal(rig.ferry.pile_count(), 3, "a pile fell at midnight")
	assert_true(rig.ferry.books_balance(), "and is in the books")


func test_the_far_copse_is_far_by_land_and_the_ferry_is_the_short_way() -> void:
	"""The copse lies across the stream's mouth: by land round the pond's south end, longer than its walk to the far
	stage, the row and the walk on from the ferry stage to the log stack."""
	var rig: Rig = _rig()
	var nav = rig.cast.space().nav
	var out := PackedVector2Array()
	var copse: Vector2 = rig.ferry.copse_at[0]
	nav.plan(copse, rig.ferry.log_drop(), 0.5, PackedVector3Array(), 0, out)
	var land: float = preload("res://demo/cast/cast_nav.gd").path_length(copse, out)
	nav.plan(copse, rig.ferry.stack_at(FerryScript.FAR), 0.5, PackedVector3Array(), 0, out)
	var to_stage: float = preload("res://demo/cast/cast_nav.gd").path_length(copse, out)
	nav.plan(rig.ferry.stack_at(FerryScript.NEAR), rig.ferry.log_drop(), 0.5, PackedVector3Array(), 0, out)
	var on_from: float = preload("res://demo/cast/cast_nav.gd").path_length(rig.ferry.stack_at(FerryScript.NEAR), out)
	var row_m: float = float(Routes.route_length_u(Routes.FERRY_BOAT)) / 1024.0
	assert_true(land > to_stage + row_m + on_from + 10.0, "by land %.1f m against %.1f + %.1f + %.1f" % [land, to_stage, row_m, on_from])


# --- whole crossings ---------------------------------------------------------------------------------

func test_windfall_is_gathered_ferried_and_stacked_as_the_stores_wood() -> void:
	"""Gather the far copse: the windfall is carried to the far stage, the timetabled crossing loads it, rows it to the
	ferry stage, unloads it, and a hauler stacks it at the log stack -- the stores' wood rises by exactly what fell, the
	boat is given back, and THE BOOKS balance every frame."""
	var rig: Rig = _rig(9)
	_helm(rig, 4, 2)
	var wood_before: int = _services.stores.wood_milli_u
	assert_equal(rig.ferry.order_gather(PackedInt32Array()), "", "gathering ordered")
	assert_equal(rig.ferry.job_count(), 2, "a job a pile")
	var stored := func() -> bool: return rig.ferry.stored_milli == 2750 and rig.ferry.job_count() == 0
	assert_true(_run(rig, stored), "the windfall reached the stores (stored %d)" % rig.ferry.stored_milli)
	assert_true(_books_kept, "THE BOOKS balanced every frame")
	assert_equal(_services.stores.wood_milli_u - wood_before, 2750, "the stores' wood rose by what fell")
	assert_equal(rig.ferry.ferried_milli, 2750, "all of it by ferry")
	assert_true(rig.ferry.crossings_done >= 1, "a crossing done")
	assert_equal(rig.ferry.x_serial, 0, "no crossing left")
	assert_true(rig.fishery.fleet.is_free(Routes.FERRY_BOAT), "the ferry boat given back, free for a rescue")
	assert_equal(rig.ferry.pile_count(), 0, "the copse gathered")


func _stock_far(rig: Rig, milli: int) -> void:
	"""Wood on the far stage's stack, as if gathered (fallen and stacked together: THE BOOKS stay balanced)."""
	rig.ferry.fallen_milli += milli
	rig.ferry.far_stack_milli += milli


func test_the_threshold_calls_the_ferry_before_its_departure() -> void:
	"""4.0 U on the far stage calls a crossing at once, before the scheduled departure; 3.9 U waits for it; with nothing
	to carry, no crossing is called at a departure; and none by night."""
	var rig: Rig = _rig(9)
	_helm(rig, 4, 2)
	_stock_far(rig, Rules.THRESHOLD_MILLI - 100)
	rig.ferry.update(0)
	assert_equal(rig.ferry.x_serial, 0, "under the threshold: it waits for 10:00")
	_stock_far(rig, 100)
	rig.ferry.update(0)
	assert_true(rig.ferry.x_serial != 0, "at the threshold: called at once")
	assert_true(rig.ferry.x_why.contains("reached"), "why: %s" % rig.ferry.x_why)
	var empty: Rig = _rig(9)
	_helm(empty, 4, 2)
	empty.calendar.tick = Rules.hour_tick(10) + 1
	empty.ferry.update(0)
	assert_equal(empty.ferry.x_serial, 0, "nothing to carry: no crossing at 10:00")
	assert_equal(empty.ferry.next_departure, Rules.hour_tick(12), "the next departure is 12:00")
	var night: Rig = _rig(9)
	_helm(night, 4, 2)
	night.calendar.tick = Rules.hour_tick(21)
	night.ferry.next_departure = Rules.departure_tick_at_or_after(night.calendar.tick)
	_stock_far(night, Rules.THRESHOLD_MILLI)
	night.ferry.update(0)
	assert_equal(night.ferry.x_serial, 0, "no crossing by night, threshold or not")


func test_a_storm_mid_crossing_finishes_the_leg_then_holds_at_the_far_stage() -> void:
	"""A storm while the ferry rows out: it finishes the crossing, does not load, its crew steps ashore at the far stage
	and the boat is held (still the crossing's); the storm passed, a crew walks round, brings the cargo back and stores
	it. Nothing lost or doubled at any frame."""
	var rig: Rig = _rig(9)
	_helm(rig, 4, 2)
	_stock_far(rig, 3000)
	assert_equal(rig.ferry.order_send(PackedInt32Array([4])), "", "sent")
	var rowing_out := func() -> bool: return rig.ferry.x_state == FerryScript.X_ROWING and rig.ferry.x_stage == FerryScript.FAR
	assert_true(_run(rig, rowing_out), "rowing out")
	_storm(rig, true)
	assert_false(rig.ferry.is_open(), "a storm closes the ferry")
	var held := func() -> bool: return rig.ferry.x_state == FerryScript.X_HELD and rig.ferry.x_job == FerryScript.NONE
	assert_true(_run(rig, held), "held at the far stage, its crew ashore")
	assert_true(_books_kept, "THE BOOKS through the closure")
	var fleet: FleetScript = rig.fishery.fleet
	assert_equal(fleet.phase[Routes.FERRY_BOAT], FleetScript.PHASE_ON_STATION, "the boat lies at the far stage")
	assert_equal(fleet.owner[Routes.FERRY_BOAT], rig.ferry.x_serial, "still the crossing's: no rescue takes a held boat")
	assert_equal(rig.ferry.far_stack_milli, 3000, "nothing loaded while closed")
	assert_false(rig.ferry.brain_of(4).water_hold, "the crew is ashore")
	assert_true(rig.ferry.status_line().contains("a storm"), "the status says why: %s" % rig.ferry.status_line())
	_storm(rig, false)
	var stored := func() -> bool: return rig.ferry.stored_milli == 3000 and rig.ferry.job_count() == 0
	assert_true(_run(rig, stored), "brought back and stored once open")
	assert_true(_books_kept, "THE BOOKS after the hold")
	assert_true(fleet.is_free(Routes.FERRY_BOAT), "the boat given back")


func test_a_storm_before_departure_stands_the_crew_down_and_the_crossing_waits() -> void:
	"""Closed at the stage: the crew does not board, the boat is not taken (a rescue may still use it), the crossing
	waits saying why, and departs once the storm passes."""
	var rig: Rig = _rig(9)
	_helm(rig, 4, 2)
	_stock_far(rig, 2000)
	_storm(rig, true)
	assert_true(rig.ferry.send_refusal().contains("storm"), "Send is refused in a storm: %s" % rig.ferry.send_refusal())
	_storm(rig, false)
	assert_equal(rig.ferry.order_send(PackedInt32Array([4])), "", "sent")
	_storm(rig, true)
	var taken: Array = [false, false]
	var stood_down := func() -> bool:
		taken[0] = taken[0] or rig.fishery.fleet.owner[Routes.FERRY_BOAT] != 0
		taken[1] = taken[1] or rig.ferry.brain_of(4).water_hold
		return rig.ferry.x_words.contains("storm") and rig.ferry.j_worker[rig.ferry.x_job] == FerryScript.NONE
	assert_true(_run(rig, stood_down, 3000, false), "stood down at the stage")
	assert_false(taken[0], "the boat was never taken: the crew stood down before boarding")
	assert_false(taken[1], "nor did the crew set foot on the deck")
	assert_true(rig.fishery.fleet.is_free(Routes.FERRY_BOAT), "the boat untaken")
	_storm(rig, false)
	var stored := func() -> bool: return rig.ferry.stored_milli == 2000 and rig.ferry.job_count() == 0
	assert_true(_run(rig, stored), "crossed once the storm passed")
	assert_true(_books_kept, "THE BOOKS")


func test_the_router_chooses_the_ferry_for_a_passenger_when_it_is_quicker() -> void:
	"""With the boat about to load at the ferry stage, a resident on the village bank sent to the far bank is routed over
	the ferry row (by ferry, not round over the ford), waits, boards the second seat, rides and steps off at the far
	stage, then walks on; counted."""
	var rig: Rig = _rig(9)
	_helm(rig, 4, 2)
	_stock_far(rig, 1000)
	assert_equal(rig.ferry.order_send(PackedInt32Array([4])), "", "sent")
	var crew: BrainScript = rig.ferry.brain_of(4)
	var walk: float = crew.position.distance_to(rig.ferry.stage_land(FerryScript.NEAR)) / crew.walk_speed
	assert_true(rig.ferry.wait_ticks(FerryScript.NEAR) > 0 or walk < 0.1,
		"posted, the boarding waits for the crew's walk to the stage (%d ticks)" % rig.ferry.wait_ticks(FerryScript.NEAR))
	var rider: int = 5
	var brain: BrainScript = rig.ferry.brain_of(rider)
	brain.order_move(rig.ferry.stage_land(FerryScript.NEAR) + Vector2(-1.0, 0.6))
	assert_true(_run(rig, func() -> bool: return brain.trip_outcome != BrainScript.TRIP_UNDERWAY and brain.state != BrainScript.State.ROUTE,
		3000, false), "at the ferry stage")
	var goal: Vector2 = rig.ferry.copse_at[0]
	brain.order_move(goal)
	var planned := func() -> bool: return brain.state != BrainScript.State.ROUTE and brain.path.size() > 0
	assert_true(_run(rig, planned, 600, false), "planned")
	var ferry_legs: int = 0
	for code: int in brain.path_tunnel:
		if RouterScript.is_crossing_code(code) and RouterScript.crossing_row(code) == CrossingsScript.FERRY_ROW:
			ferry_legs += 1
	assert_equal(ferry_legs, 1, "the route goes by ferry")
	var kinds := KindsScript.new()
	kinds.ferry_row = CrossingsScript.FERRY_ROW
	var read := PackedStringArray()
	for k: int in brain.path.size():
		read.append("%d:%d" % [brain.path_tunnel[k], kinds.kind_of(brain.path_tunnel[k], brain.position, brain.path[k])])
	assert_true(kinds.has_kind(brain.position, brain.path, brain.path_tunnel, KindsScript.KIND_FERRY), "the Routes layer reads it by ferry: %s" % ", ".join(read))
	var waiting := func() -> bool: return rig.ferry.p_state[rider] == FerryScript.P_WAITING
	assert_true(_run(rig, waiting, 3000), "waiting at the stage")
	var where := ReasonsScript.Where.new()
	assert_equal(ReasonsScript.diagnose(brain, rig.cast.space().tunnels, where), ReasonsScript.WAITING_FERRY, "the Routes layer's post: waiting for the ferry")
	var aboard := func() -> bool: return rig.ferry.p_state[rider] == FerryScript.P_ABOARD
	assert_true(_run(rig, aboard, 3000), "aboard")
	assert_true(brain.water_hold, "held on the water (no order takes it off)")
	assert_equal(rig.fishery.fleet.crew_of(Routes.FERRY_BOAT, Rules.PASSENGER_SEAT), rider, "in the second seat")
	kinds.fleet = rig.fishery.fleet
	assert_equal(kinds.boat_kind_of(rider), KindsScript.KIND_FERRY, "aboard, the Routes layer reads it by ferry, not by boat")
	var arrived := func() -> bool: return brain.position.distance_to(goal) < 1.0
	assert_true(_run(rig, arrived), "walked on to its goal on the far bank")
	assert_equal(rig.ferry.passengers_carried, 1, "one passenger carried")
	assert_false(brain.water_hold, "off the water")
	assert_true(_books_kept, "THE BOOKS")


func test_a_crew_with_nothing_to_load_holds_for_a_waiting_passenger_to_board() -> void:
	"""With nothing to load at home the crew would push off the frame it sat down; a passenger waiting at the stage --
	whose own brain steps its leg, perhaps a step later -- is given BOARD_GRACE_STEPS to start boarding first."""
	var rig: Rig = _rig(9)
	_helm(rig, 4, 2)
	_stock_far(rig, 1000)
	var rider: BrainScript = rig.ferry.brain_of(5)
	rig.ferry.begin_passenger(rider, false)
	assert_equal(rig.ferry.order_send(PackedInt32Array([4])), "", "sent")
	var loading := func() -> bool: return rig.ferry.x_state == FerryScript.X_LOADING and rig.ferry.x_stage == FerryScript.NEAR
	assert_true(_run(rig, loading, 3000, false), "loading at home")
	var held: int = 0
	while rig.ferry.x_state == FerryScript.X_LOADING and held < 200:
		_run(rig, func() -> bool: return false, 1, false)
		held += 1
	assert_true(held >= 3, "held %d frames (several steps each) for the waiting passenger" % held)
	assert_equal(rig.ferry.x_state, FerryScript.X_ROWING, "then, the passenger never boarding, it rows")
	rig.ferry.abandon_passenger(rider)
	assert_true(_books_kept, "THE BOOKS")


func test_a_closed_ferry_is_not_offered_and_a_waiting_passenger_goes_by_land() -> void:
	"""Closed, the router is offered no ferry row; a passenger waiting at the stage when the storm comes gives it up
	there and plans again by land."""
	var rig: Rig = _rig(9)
	_helm(rig, 4, 2)
	_stock_far(rig, 1000)
	var near: Vector2 = rig.ferry.stage_land(FerryScript.NEAR)
	assert_true(rig.ferry.offer_cost_m(2, near, false) < INF, "offered while open")
	_storm(rig, true)
	assert_equal(rig.ferry.offer_cost_m(2, near, false), INF, "not offered in a storm")
	_storm(rig, false)
	assert_equal(rig.ferry.order_send(PackedInt32Array([4])), "", "sent")
	var brain: BrainScript = rig.ferry.brain_of(2)
	brain.order_move(rig.ferry.stage_land(FerryScript.NEAR) + Vector2(-1.0, 0.6))
	assert_true(_run(rig, func() -> bool: return brain.trip_outcome != BrainScript.TRIP_UNDERWAY and brain.state != BrainScript.State.ROUTE,
		3000, false), "at the ferry stage")
	brain.order_move(rig.ferry.copse_at[0])
	var waiting := func() -> bool: return rig.ferry.p_state[2] == FerryScript.P_WAITING
	assert_true(_run(rig, waiting, 3000, false), "waiting for the ferry")
	_storm(rig, true)
	var gave_up := func() -> bool: return rig.ferry.p_state[2] == FerryScript.P_NONE and brain.state != BrainScript.State.CROSS
	assert_true(_run(rig, gave_up, 600, false), "it gave the ferry up")
	assert_false(brain.water_hold, "never held")
	assert_true(brain.position.distance_to(rig.ferry.copse_at[0]) > 3.0, "not carried across")
	for point: Vector2 in brain.path:
		assert_true(point.distance_to(rig.ferry.stage_land(FerryScript.FAR)) > 0.5, "its route was cut: not on to the far stage")
	for code: int in brain.path_tunnel.slice(brain.path_index):
		assert_false(RouterScript.is_crossing_code(code) and RouterScript.crossing_row(code) == CrossingsScript.FERRY_ROW,
			"its new route does not take the ferry")


func test_a_held_crossing_whose_crew_cannot_reach_it_keeps_its_boat() -> void:
	"""Held at the far stage and its bring-back crew unable to reach it, the crossing is never ended with the boat out
	(that would orphan it): it waits for a crew who can, saying so; Cancel is refused while it is held."""
	var rig: Rig = _rig(9)
	_helm(rig, 4, 2)
	_helm(rig, 5, 2)
	_stock_far(rig, 3000)
	assert_equal(rig.ferry.order_send(PackedInt32Array([4])), "", "sent")
	assert_true(_run(rig, func() -> bool: return rig.ferry.x_state == FerryScript.X_ROWING and rig.ferry.x_stage == FerryScript.FAR), "rowing out")
	_storm(rig, true)
	assert_true(_run(rig, func() -> bool: return rig.ferry.x_state == FerryScript.X_HELD and rig.ferry.x_job == FerryScript.NONE), "held")
	assert_false(rig.ferry.cancel_crossing().is_empty(), "Cancel refused while held")
	_storm(rig, false)
	rig.ferry.update(0)
	var f: FerryScript = rig.ferry
	var serial: int = f.x_serial
	var j: int = f.x_job
	assert_true(j != FerryScript.NONE, "a crew job to bring it back")
	for k: int in Rules.MAX_TRIES:
		f._unreached(j, f.brain_of(4 if k % 2 == 0 else 5))
	assert_equal(f.x_serial, serial, "the crossing is not ended")
	assert_equal(f.fleet.owner[Routes.FERRY_BOAT], serial, "the boat still the crossing's, not orphaned")
	assert_true(f.x_words.contains("waiting for a crew"), "said: %s" % f.x_words)
	assert_true(f.is_job(j, f.j_serial[j]), "its job still on the board")
	assert_true(_books_kept, "THE BOOKS")


func test_a_storm_at_the_stage_puts_a_boarded_passenger_back_ashore() -> void:
	"""Closed at home before pushing off, a passenger already in the seat steps back ashore and its leg ends."""
	var rig: Rig = _rig(9)
	_helm(rig, 4, 2)
	var f: FerryScript = rig.ferry
	var rider: BrainScript = f.brain_of(5)
	rider.order_move(f.stage_land(FerryScript.NEAR) + Vector2(-1.0, 0.6))
	assert_true(_run(rig, func() -> bool: return rider.trip_outcome != BrainScript.TRIP_UNDERWAY and rider.state != BrainScript.State.ROUTE,
		3000, false), "at the ferry stage")
	f.begin_passenger(rider, false)
	f.p_goal[5] = rider.goal()
	f.p_path[5] = rider.path.size()
	_stock_far(rig, 1000)
	assert_equal(f.order_send(PackedInt32Array([4])), "", "sent")
	assert_true(_run(rig, func() -> bool: return f.x_state == FerryScript.X_LOADING and f.x_stage == FerryScript.NEAR, 3000, false), "loading at home")
	f.p_state[5] = FerryScript.P_ABOARD
	f.fleet.seat(Routes.FERRY_BOAT, Rules.PASSENGER_SEAT, 5)
	_storm(rig, true)
	f._closed_aboard(f.x_job)
	assert_equal(f.p_state[5], FerryScript.P_RETURNING, "the passenger steps back ashore")
	assert_equal(f.fleet.crew_of(Routes.FERRY_BOAT, Rules.PASSENGER_SEAT), FleetScript.NOBODY, "the seat freed")
	f.abandon_passenger(rider)


func test_a_waiting_passenger_given_another_order_gives_up_the_ferry() -> void:
	"""An order while it waits (its goal changed) ends the wait: the leg is given up and it plans again."""
	var rig: Rig = _rig(9)
	_helm(rig, 4, 2)
	var f: FerryScript = rig.ferry
	var rider: BrainScript = f.brain_of(5)
	f.begin_passenger(rider, false)
	_stock_far(rig, 1000)
	assert_equal(f.order_send(PackedInt32Array([4])), "", "sent")
	assert_equal(f.passenger_refusal(5), "", "waiting is fine")
	rider.order_move(rider.position + Vector2(2.0, 0.0))
	assert_true(f.passenger_refusal(5).contains("another order"), "a new order: %s" % f.passenger_refusal(5))
	f.abandon_passenger(rider)


func test_a_full_job_table_refuses_a_crossing_and_overwrites_nothing() -> void:
	"""ARCH-AUTH-003: with every job row live, Send is refused in words and no row is written (a NONE row would index
	the last one)."""
	var rig: Rig = _rig(9)
	_helm(rig, 4, 2)
	_stock_far(rig, 1000)
	var f: FerryScript = rig.ferry
	for k: int in FerryScript.MAX_JOBS:
		f.j_live[k] = 1
		f.j_kind[k] = FerryScript.KIND_GATHER
		f.j_step[k] = FerryScript.S_TO_PILE
	assert_true(f.order_send(PackedInt32Array([4])).contains("full"), "refused: %s" % f.x_words)
	assert_equal(f.x_serial, 0, "no crossing posted")
	assert_equal(f.j_step[FerryScript.MAX_JOBS - 1], FerryScript.S_TO_PILE, "the last row untouched")


func test_cancelling_before_boarding_releases_everything() -> void:
	"""Called off before the crew is aboard: no job, no crossing, the boat free, the cargo still on its stack."""
	var rig: Rig = _rig(9)
	_helm(rig, 4, 2)
	_stock_far(rig, 1500)
	assert_equal(rig.ferry.order_send(PackedInt32Array([4])), "", "sent")
	_run(rig, func() -> bool: return false, 30)
	assert_equal(rig.ferry.cancel_crossing(), "", "called off")
	assert_equal(rig.ferry.x_serial, 0, "no crossing")
	assert_equal(rig.ferry.job_count(), 0, "no job")
	assert_true(rig.fishery.fleet.is_free(Routes.FERRY_BOAT), "the boat free")
	assert_equal(rig.ferry.far_stack_milli, 1500, "the cargo on its stack")
	assert_true(rig.ferry.books_balance(), "THE BOOKS")
	assert_true(rig.ferry.cancel_crossing().contains("no crossing"), "nothing more to call off")


func test_afloat_the_crossing_is_not_cancelled_or_its_crew_taken() -> void:
	"""On the water the crossing finishes: Cancel refuses, the crew's job refuses pause and reassign, no order takes the
	helm off the boat."""
	var rig: Rig = _rig(9)
	_helm(rig, 4, 2)
	_stock_far(rig, 1500)
	assert_equal(rig.ferry.order_send(PackedInt32Array([4])), "", "sent")
	assert_true(_run(rig, func() -> bool: return rig.ferry.x_state == FerryScript.X_ROWING), "rowing")
	assert_true(rig.ferry.cancel_crossing().contains("finishes"), "Cancel refused afloat")
	var j: int = rig.ferry.x_job
	assert_true(rig.ferry.pause_job(j, true).contains("finishes the crossing"), "pause refused")
	assert_true(rig.ferry.reassign_job(j, 3).contains("finishes the crossing"), "reassign refused")
	var brain: BrainScript = rig.ferry.brain_of(4)
	brain.order_move(Vector2(0.0, 0.0))
	assert_true(brain.task != null and rig.ferry.j_worker[j] == 4, "an order does not take the helm off the boat")
	assert_true(_run(rig, func() -> bool: return rig.ferry.stored_milli == 1500 and rig.ferry.job_count() == 0), "finished and stored")
	assert_true(_books_kept, "THE BOOKS")


func test_a_carrier_called_away_sets_the_wood_down_for_the_next() -> void:
	"""A gatherer with wood in hand given another order sets it down where it stands; the job waits, the next resident
	picks it up and carries on; the stores get it all."""
	var rig: Rig = _rig(9)
	_helm(rig, 4, 2)
	assert_equal(rig.ferry.order_gather(PackedInt32Array([0])), "", "gathering ordered")
	var carrying := func() -> bool: return rig.ferry.job_of_worker(0) >= 0 and rig.ferry.j_step[rig.ferry.job_of_worker(0)] == FerryScript.S_TO_FAR_STACK
	assert_true(_run(rig, carrying, MAX_FRAMES, false), "carrying its pile")
	var j: int = rig.ferry.job_of_worker(0)
	var held: int = rig.ferry.j_load[j]
	assert_true(held > 0, "wood in hand")
	assert_true(rig.ferry.cancel_job(j).contains("delivery"), "Cancel refused: a delivery finishes")
	rig.ferry.brain_of(0).order_move(Vector2(10.0, 0.0))
	assert_true(rig.ferry.j_load_at[j].is_finite(), "set down where it stood")
	assert_equal(rig.ferry.j_worker[j], FerryScript.NONE, "the job waits for the next")
	assert_true(rig.ferry.books_balance(), "THE BOOKS with the wood set down")
	var stored := func() -> bool: return rig.ferry.stored_milli == rig.ferry.fallen_milli and rig.ferry.job_count() == 0
	assert_true(_run(rig, stored), "picked up, ferried and stored")
	assert_true(_books_kept, "THE BOOKS")


func test_between_crossings_the_rescue_may_take_the_ferry_boat() -> void:
	"""Free between crossings, the ferry boat answers a victim in the run from its own stage; owned by a crossing it does
	not; fishing never takes it."""
	var rig: Rig = _rig(9)
	var in_run := Vector2(27.4, 17.4)
	assert_true(_map().depth_at(Routes.u_of(in_run)) > Routes.BOAT_DRAFT_U, "a point in the run")
	assert_equal(rig.boats.boat_for(in_run), Routes.FERRY_BOAT, "the free ferry boat can row to it")
	assert_true(rig.boats.entry_m().distance_to(Routes.jetty_land_m(1)) < 0.01, "its crew walks to the ferry stage")
	rig.fishery.fleet.take(Routes.FERRY_BOAT, 77)
	assert_equal(rig.boats.boat_for(in_run), -1, "taken by a crossing, it is not the rescue's")
	rig.fishery.fleet.give_back(Routes.FERRY_BOAT, 77)
	rig.fishery.fleet.take(0, 91)
	rig.fishery.fleet.take(1, 92)
	_helm(rig, 4, 2)
	var why: String = rig.fishery.trip_refusal(FisheryRules.METHOD_BOAT, Driver.SITE_POND, 0, PackedInt32Array())
	assert_equal(rig.fishery.refused_code, "BOATS_OUT", "with both fishing boats out a boat trip waits: %s" % why)
	assert_true(rig.fishery.fleet.is_free(Routes.FERRY_BOAT), "the ferry boat is never taken for fishing")


func test_the_work_board_lists_and_claims_ferry_jobs() -> void:
	"""The board's adapter: each pile's gather (the Woods crew's activity), its record, a claim, and the crew's helm rule."""
	var rig: Rig = _rig(9)
	var work := FerryWork.new(rig.ferry)
	assert_equal(work.id, WorkIds.SOURCE_FERRY, "its own source")
	assert_equal(WorkIds.SOURCE_WALK, WorkIds.SOURCE_COUNT, "a queued walk is past every source")
	rig.ferry.order_gather(PackedInt32Array())
	var rows: int = 0
	for row: int in work.capacity():
		if work.live(row):
			rows += 1
			assert_equal(work.activity(row), WorkIds.ACT_WOODS, "gathering is woods work")
			var task := TaskRecord.new()
			work.fill(task, row)
			assert_equal(task.action, "Gather windfall", "its action")
			assert_equal(task.state, WorkIds.STATE_QUEUED, "queued")
	assert_equal(rows, 2, "a task a pile")
	assert_true(work.claim(0, 1), "claimed")
	assert_equal(work.worker(0), 1, "by its claimant")
	_stock_far(rig, 1000)
	_helm(rig, 4, 2)
	assert_equal(rig.ferry.order_send(PackedInt32Array()), "", "sent")
	var crew_row: int = rig.ferry.x_job
	assert_equal(work.activity(crew_row), WorkIds.ACT_HAUL, "crewing is hauling work")
	assert_true(work.eligibility(crew_row, 3).contains("helm"), "a crew needs a helm: %s" % work.eligibility(crew_row, 3))
	_helm(rig, 3, 1)
	assert_equal(work.eligibility(crew_row, 3), "", "fishing 1 takes it (never a species)")


func test_one_who_could_not_reach_the_stage_is_not_handed_the_crossing_again() -> void:
	"""A crew that could not get to the stage is not handed the same crossing again: another helm may take it."""
	var rig: Rig = _rig(9)
	_helm(rig, 4, 2)
	_helm(rig, 5, 1)
	_stock_far(rig, 1000)
	assert_equal(rig.ferry.order_send(PackedInt32Array()), "", "sent, to the board")
	var j: int = rig.ferry.x_job
	rig.ferry.j_failed[j] = 4
	assert_true(rig.ferry.eligibility(j, 4).contains("could not reach"), "not resident 4 again: %s" % rig.ferry.eligibility(j, 4))
	assert_equal(rig.ferry.eligibility(j, 5), "", "another helm may")
