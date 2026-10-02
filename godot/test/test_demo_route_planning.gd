extends "res://test/framework/test_case.gd"
## One route plan made local and divisible (decision 1001) and the shared goal's field (decision 1002): the planner
## (cast_nav.gd) finds the SAME routes as it did before -- the planner as it was is kept in
## test/fixtures/reference_cast_nav.gd and both plan the real village, with up to a hundred residents standing about,
## from a fixed seed -- a plan carried over in steps finds the same route as one planned at once, the desk's second
## planner plans as its owner does, and a plan guided by its goal's field is as clear and nearly as short. No scene
## tree, no assets.

const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const CastNavScript := preload("res://demo/cast/cast_nav.gd")
const ReferenceNavScript := preload("res://test/fixtures/reference_cast_nav.gd")
const DemoWorldScript := preload("res://demo/world/demo_world.gd")
const WaterDressingScript := preload("res://demo/water/water_dressing.gd")
const WaterLayoutScript := preload("res://demo/water/water_layout.gd")
const WaterplayScript := preload("res://demo/waterplay/demo_waterplay.gd")
const ForestryScript := preload("res://demo/forestry/demo_forestry.gd")
const WeirViewScript := preload("res://demo/water/weir_gate_view.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const DeskScript := preload("res://demo/cast/route_desk.gd")

const SEED: int = 1001
## The cast's body radii: a mouse's, a middling one and the badger's (demo_actor.gd).
const BODIES: Array[float] = [0.25, 0.4, 0.56]
## How many stand about in each round of plans, and the plans a round makes.
const CROWDS: Array[int] = [0, 12, 40, 100]
const PLANS_PER_CROWD: int = 12
## A guided plan (decision 1002) may be at most this much longer than the plan it stands in for, on the village.
const GUIDED_LONGEST: float = 1.15
## A window no plan fits in: every plan the desk can cut is carried over (see route_desk.gd THE JOB).
const TINY_USEC: int = 1
## Frames enough for any plan of the village, a slice a frame.
const MAX_FRAMES: int = 4000
const DT: float = 1.0 / 60.0

var _village: Dictionary = {}


func _village_parts() -> Dictionary:
	"""The village as demo_village.gd `_build_cast` lays it for the cast: its spots, its circles -- the world's, the
	water's, the woods' trees and the weir's -- and the area routes stay in. Built once for the suite."""
	if not _village.is_empty():
		return _village
	var world: Node3D = DemoWorldScript.new()
	var circles: Array[Vector3] = world.obstacles()
	var points: Array[Dictionary] = world.points_of_interest()
	circles.append_array(WaterDressingScript.obstacles())
	circles.append_array(ForestryScript.extra_obstacles(world))
	world.free()
	circles.append_array(WaterplayScript.land_obstacles())
	circles.append_array(WeirViewScript.land_obstacles())
	var links := WaterplayScript.make_links(WaterLayoutScript.make_map(), circles)
	circles.append_array(links.band)
	points.append_array(WaterDressingScript.points_of_interest())
	_village = {"circles": PackedVector3Array(circles), "points": points, "area": links.area}
	return _village


func _new_nav() -> CastNavScript:
	"""The planner over the village."""
	var parts := _village_parts()
	var nav := CastNavScript.new()
	nav.area = parts.area
	nav.setup(parts.circles)
	return nav


func _reference_nav() -> ReferenceNavScript:
	"""The planner as it was, over the village."""
	var parts := _village_parts()
	var nav := ReferenceNavScript.new()
	nav.area = parts.area
	nav.setup(parts.circles)
	return nav


func _spots(nav: CastNavScript, rng: RandomNumberGenerator, count: int, body: float) -> PackedVector2Array:
	"""`count` points inside the planning area clear of every circle for `body` (residents stand, trips go)."""
	var area: Rect2 = _village_parts().area
	var out := PackedVector2Array()
	while out.size() < count:
		var p := Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
		if nav.point_open(p, body, CastNavScript.LINK_MARGIN_M):
			out.append(p)
	return out


func _poi_spots() -> PackedVector2Array:
	"""Where the village's spots are (x, z): where trips start and end."""
	var out := PackedVector2Array()
	for point: Dictionary in _village_parts().points:
		var at: Vector3 = point.get("position", Vector3.ZERO)
		out.append(Vector2(at.x, at.z))
	return out


func _trips(nav: CastNavScript, rng: RandomNumberGenerator, count: int, body: float) -> PackedVector2Array:
	"""`count` trips (from, to pairs): from a spot of the village or any open ground to another at least 15 m off."""
	var spots := _poi_spots()
	var out := PackedVector2Array()
	while out.size() < 2 * count:
		var from := spots[rng.randi_range(0, spots.size() - 1)] if rng.randf() < 0.5 else _spots(nav, rng, 1, body)[0]
		var to := spots[rng.randi_range(0, spots.size() - 1)] if rng.randf() < 0.5 else _spots(nav, rng, 1, body)[0]
		if from.distance_to(to) >= 15.0:
			out.append(from)
			out.append(to)
	return out


func _crowd(nav: CastNavScript, rng: RandomNumberGenerator, count: int) -> PackedVector3Array:
	"""`count` residents standing about, as circles (x, radius, z), of the cast's radii."""
	var out := PackedVector3Array()
	for p in _spots(nav, rng, count, 0.56):
		out.append(Vector3(p.x, BODIES[rng.randi_range(0, BODIES.size() - 1)], p.y))
	return out


func test_the_planner_finds_the_routes_it_found_before() -> void:
	"""The village, from a fixed seed: every body, crowds of 0 to 100 standing residents, and for each a dozen trips --
	the planner and the reference planner (as it was before decision 1001) give the same waypoints and the same answer
	whether a route was found."""
	var nav := _new_nav()
	var old_nav := _reference_nav()
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var mine := PackedVector2Array()
	var theirs := PackedVector2Array()
	var compared := 0
	var detoured := 0
	for body: float in BODIES:
		for crowd_size: int in CROWDS:
			var crowd := _crowd(nav, rng, crowd_size)
			var ends := _trips(nav, rng, PLANS_PER_CROWD, body)
			for k in PLANS_PER_CROWD:
				nav.plan(ends[2 * k], ends[2 * k + 1], body, crowd, crowd.size(), mine)
				old_nav.plan(ends[2 * k], ends[2 * k + 1], body, crowd, crowd.size(), theirs)
				assert_equal(mine, theirs, "body %.2f, %d standing, trip %d: the same route" % [body, crowd_size, k])
				assert_equal(nav.last_found, old_nav.last_found, "and the same answer")
				compared += 1
				detoured += 1 if mine.size() > 1 else 0
	assert_equal(compared, BODIES.size() * CROWDS.size() * PLANS_PER_CROWD, "every trip compared")
	assert_true(3 * detoured > compared, "a third or more go round something (%d of %d)" % [detoured, compared])


func test_a_crowd_away_from_the_route_is_never_ringed() -> void:
	"""A short trip across open ground beside a crowd standing far off rings none of them: the plan's own nodes are the
	start, the goal and the rings by them alone, as with nobody standing (see LOCAL, NOT EVERYONE)."""
	var nav := CastNavScript.new()
	nav.setup(PackedVector3Array([Vector3(0.0, 1.0, 0.0)]))
	var crowd := PackedVector3Array()
	for k in 60:
		crowd.append(Vector3(40.0 + float(k % 10), 0.3, 40.0 + floorf(float(k) / 10.0)))
	var out := PackedVector2Array()
	nav.plan(Vector2(-3.0, 0.0), Vector2(3.0, 0.0), 0.3, PackedVector3Array(), 0, out)
	var alone := nav._dynamic.size()
	nav.plan(Vector2(-3.0, 0.0), Vector2(3.0, 0.0), 0.3, crowd, crowd.size(), out)
	assert_true(nav.last_found, "round the post")
	assert_equal(nav._dynamic.size(), alone, "no ring round anyone 40 m off")


func test_a_resident_standing_across_the_way_is_ringed_and_passed() -> void:
	"""Someone standing in the gap between two posts: the plan rings them as it reaches them and goes round, clear of
	them by the link inflation."""
	var nav := CastNavScript.new()
	nav.setup(PackedVector3Array([Vector3(-2.0, 1.0, 0.0), Vector3(2.0, 1.0, 0.0)]))
	var crowd := PackedVector3Array([Vector3(0.0, 0.4, 0.0)])
	var out := PackedVector2Array()
	nav.plan(Vector2(0.0, -4.0), Vector2(0.0, 4.0), 0.3, crowd, 1, out)
	assert_true(nav.last_found and out.size() > 1, "a detour")
	assert_true(_clear_of(Vector2(0.0, -4.0), out, Vector2.ZERO, 0.4 + 0.3), "never through the one standing")


func _clear_of(from: Vector2, route: PackedVector2Array, centre: Vector2, reach: float) -> bool:
	"""Whether no leg of `route` (from `from`) passes within `reach` of `centre`."""
	var at := from
	for point in route:
		if CastNavScript.distance_to_segment(centre, at, point) < reach - 1e-3:
			return false
		at = point
	return true


func test_a_plan_carried_over_in_steps_finds_the_same_route() -> void:
	"""DIVISIBLE: one expansion a step, the plan stays PLAN_PENDING until it is done, then gives the route `plan` gives
	at once; a step of none moves nothing on."""
	var nav := _new_nav()
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 1
	var crowd := _crowd(nav, rng, 30)
	var ends := _trips(nav, rng, 4, 0.4)
	var whole := PackedVector2Array()
	var stepped := PackedVector2Array()
	var most := 0
	for k in 4:
		nav.plan(ends[2 * k], ends[2 * k + 1], 0.4, crowd, crowd.size(), whole)
		var expanded := nav.last_expanded
		nav.begin_plan(ends[2 * k], ends[2 * k + 1], 0.4, crowd, crowd.size())
		var state := nav.plan_state()
		assert_equal([nav.step_plan(0), nav.last_expanded], [state, 0], "a step of none: nothing expanded")
		var steps := 0
		while nav.step_plan(1) == CastNavScript.PLAN_PENDING:
			steps += 1
		nav.finish_plan(stepped)
		assert_equal(stepped, whole, "trip %d: the same route in %d steps" % [k, steps])
		assert_equal(nav.last_expanded, expanded, "and the same expansions")
		most = maxi(most, steps)
	assert_true(most > 10, "a trip of many steps among them (%d)" % most)


func test_a_plan_keeps_the_standing_it_began_with() -> void:
	"""A plan carried over copies its standing residents: the caller's array may be refilled meanwhile."""
	var nav := CastNavScript.new()
	nav.setup(PackedVector3Array([Vector3(-2.0, 1.0, 0.0), Vector3(2.0, 1.0, 0.0)]))
	var crowd := PackedVector3Array([Vector3(0.0, 0.4, 0.0)])
	var at_once := PackedVector2Array()
	nav.plan(Vector2(0.0, -4.0), Vector2(0.0, 4.0), 0.3, crowd, 1, at_once)
	nav.begin_plan(Vector2(0.0, -4.0), Vector2(0.0, 4.0), 0.3, crowd, 1)
	crowd[0] = Vector3(50.0, 0.4, 50.0)
	while nav.step_plan(1) == CastNavScript.PLAN_PENDING:
		pass
	var later := PackedVector2Array()
	nav.finish_plan(later)
	assert_equal(later, at_once, "planned round the one who stood there when it began")


func test_the_desks_second_planner_plans_as_its_owner_does_and_starts_again_when_the_circles_change() -> void:
	"""`share_world`: a second CastNav over the owner's circles and graphs gives the owner's routes; when the owner's
	circles change, a plan under way in the second starts again over the new ones."""
	var owner := _new_nav()
	var worker := CastNavScript.new()
	worker.share_world(owner)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 2
	var crowd := _crowd(owner, rng, 20)
	var ends := _spots(owner, rng, 6, 0.25)
	var a := PackedVector2Array()
	var b := PackedVector2Array()
	for k in 3:
		owner.plan(ends[2 * k], ends[2 * k + 1], 0.25, crowd, crowd.size(), a)
		worker.plan(ends[2 * k], ends[2 * k + 1], 0.25, crowd, crowd.size(), b)
		assert_equal(b, a, "trip %d: the owner's route" % k)
	var spot := _poi_spots()[0]
	worker.begin_plan(spot, spot + Vector2(0.05, 0.0), 0.25, PackedVector3Array(), 0)
	var before := worker.plan_state()
	assert_equal(before, CastNavScript.PLAN_FOUND, "a step along a spot: done at once")
	owner.setup(PackedVector3Array([Vector3(0.0, 1.0, -1.0), Vector3(0.0, 1.0, 1.0)]))
	worker.share_world(owner)
	assert_equal(worker.plan_state(), before, "a plan done is not begun again")
	worker.begin_plan(Vector2(-4.0, 0.0), Vector2(4.0, 0.0), 0.25, PackedVector3Array(), 0)
	assert_equal(worker.plan_state(), CastNavScript.PLAN_PENDING, "the wall is in the way: a search to make")
	owner.setup(PackedVector3Array([Vector3(0.0, 1.0, 9.0)]))
	worker.share_world(owner)
	assert_equal(worker.plan_state(), CastNavScript.PLAN_FOUND, "begun again over the new circles: straight across")


func test_a_guided_plan_is_clear_found_when_a_plan_is_and_nearly_as_short() -> void:
	"""ONE FIELD PER SHARED GOAL: a dozen residents from the village's spots to its first, guided by its field -- built
	once, then kept -- each finds a route exactly when the plain plan does, clear of every circle and everyone standing,
	no more than GUIDED_LONGEST times as long, expanding fewer nodes in all."""
	var nav := _new_nav()
	var guide := _new_nav()
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 3
	var crowd := _crowd(nav, rng, 40)
	var spots := _poi_spots()
	var goal := spots[0]
	var starts := spots.slice(1, 13)
	var plain := PackedVector2Array()
	var guided := PackedVector2Array()
	var expanded := PackedInt32Array([0, 0])
	for from in starts:
		nav.plan(from, goal, 0.4, crowd, crowd.size(), plain)
		expanded[0] += nav.last_expanded
		guide.begin_plan(from, goal, 0.4, crowd, crowd.size(), true)
		while guide.step_plan(64) == CastNavScript.PLAN_PENDING:
			pass
		guide.finish_plan(guided)
		expanded[1] += guide.last_expanded
		assert_equal(guide.last_found, nav.last_found, "found exactly when a plan is")
		if nav.last_found:
			_assert_clear(guide, from, guided, crowd, 0.4)
			assert_true(CastNavScript.path_length(from, guided) <= CastNavScript.path_length(from, plain) * GUIDED_LONGEST,
				"no more than %.2f times as long" % GUIDED_LONGEST)
	assert_equal([guide.fields_built, guide.fields_kept()], [1, 1], "one field, searched once and kept")
	assert_true(expanded[1] < expanded[0], "fewer expansions guided (%d) than not (%d)" % [expanded[1], expanded[0]])


func _assert_clear(nav: CastNavScript, from: Vector2, route: PackedVector2Array, crowd: PackedVector3Array, body: float) -> void:
	"""Every leg of `route` clears every circle and everyone standing at the link inflation (shrunk for its ends, as a
	plan's own links are)."""
	var at := from
	var goal := route[route.size() - 1]
	for point in route:
		assert_false(nav.segment_hits_obstacle(at, point, body, CastNavScript.LINK_MARGIN_M, from, goal, true),
			"a leg clears every circle")
		for s in crowd:
			var r := CastNavScript.inflated(s, body, CastNavScript.LINK_MARGIN_M, from, goal, true)
			assert_false(r > 0.0 and CastNavScript.distance_to_segment(Vector2(s.x, s.z), at, point) < r - 1e-3,
				"a leg clears everyone standing")
		at = point


func test_the_fields_kept_are_the_latest_and_dropped_when_the_circles_change() -> void:
	"""FIELD_SLOTS fields at most, the least lately used dropped first; a new set of circles drops them all."""
	var owner := _new_nav()
	var nav := CastNavScript.new()
	nav.share_world(owner)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 4
	var goals := _spots(nav, rng, CastNavScript.FIELD_SLOTS + 1, 0.25)
	var from := _spots(nav, rng, 1, 0.25)[0]
	for goal in goals:
		nav.begin_plan(from, goal, 0.25, PackedVector3Array(), 0, true)
		while nav.step_plan(256) == CastNavScript.PLAN_PENDING:
			pass
	assert_equal(nav.fields_kept(), CastNavScript.FIELD_SLOTS, "no more than FIELD_SLOTS")
	assert_equal(nav._field_slot(goals[0], 0.25), -1, "the first goal's dropped: least lately used")
	assert_true(nav._field_slot(goals[CastNavScript.FIELD_SLOTS], 0.25) >= 0, "the last kept")
	owner.setup(PackedVector3Array([Vector3(0.0, 1.0, 0.0)]))
	nav.share_world(owner)
	assert_equal(nav.fields_kept(), 0, "new circles: none kept")


# --- the desk's job (route_desk.gd THE JOB) ----------------------------------------------------------------

func _village_space(budget_usec: int) -> CastSpaceScript:
	"""The village as the cast walks it, with a routing desk of `budget_usec` a window."""
	var parts := _village_parts()
	var space := CastSpaceScript.new()
	space.nav.area = parts.area
	var circles: Array[Vector3] = []
	for circle in (parts.circles as PackedVector3Array):
		circles.append(circle)
	space.setup(parts.points, circles)
	space.routes.budget_usec = budget_usec
	return space


func _wall_space(budget_usec: int) -> CastSpaceScript:
	"""A wall of posts from x = -30 to 30 along z = 0, a spot either side of its middle (south (0, -3), north (0, 3), one
	slot each): any trip across is a long way round, a plan of many slices. A desk of `budget_usec` a window."""
	var circles: Array[Vector3] = []
	for k in 41:
		circles.append(Vector3(-30.0 + 1.5 * float(k), 1.0, 0.0))
	var points: Array[Dictionary] = []
	for z in [-3.0, 3.0]:
		points.append({"name": &"spot", "position": Vector3(0.0, 0.0, z), "face": Vector3(0.0, 0.0, signf(z)),
			"activities": [&"collect_object"] as Array[StringName], "capacity": 1})
	var space := CastSpaceScript.new()
	space.setup(points, circles)
	space.routes.budget_usec = budget_usec
	return space


func _brain_at(space: CastSpaceScript, at: Vector2, seed_value: int) -> BrainScript:
	"""A resident standing at `at`, holding no slot."""
	var lengths := {}
	for clip in DemoActorScript.CLIPS:
		lengths[clip] = 2.0
	var brain := BrainScript.new()
	brain.configure(space, 1.0, 0.4, seed_value, lengths)
	brain.start_at(at, 0.0, -1, -1)
	return brain


func _serve_until(space: CastSpaceScript, done: Callable) -> int:
	"""Serve the desk a window at a time until `done()`; the windows it took (MAX_FRAMES: never)."""
	for frame in MAX_FRAMES:
		if bool(done.call()):
			return frame
		space.routes.end_window()
		space.routes.serve()
	return MAX_FRAMES


func _walking(brain: BrainScript) -> bool:
	"""Whether `brain` has set off."""
	return brain.state == BrainScript.State.TURN or brain.state == BrainScript.State.WALK


func test_a_plan_longer_than_a_window_is_carried_over_and_the_resident_waits_then_walks_it() -> void:
	"""THE JOB: ordered round the wall with a window no plan fits, the resident stands in ROUTE while the desk carries
	its plan over window after window, then sets off along exactly the route a plan made at once gives."""
	var space := _wall_space(TINY_USEC)
	var brain := _brain_at(space, Vector2(0.0, -3.0), 7)
	var expected := PackedVector2Array()
	space.nav.plan(Vector2(0.0, -3.0), Vector2(0.0, 3.0), 0.4, PackedVector3Array(), 0, expected)
	assert_true(space.nav.last_expanded > 2 * DeskScript.SLICE_EXPANSIONS, "a plan of slices (%d)" % space.nav.last_expanded)
	brain.order_move(Vector2(0.0, 3.0))
	assert_equal(brain.state, BrainScript.State.ROUTE, "finding a route")
	assert_true(space.routes.job_owner == brain.index and space.routes.is_waiting(brain.index), "its plan is the job")
	var windows := _serve_until(space, _walking.bind(brain))
	assert_true(windows > 1 and windows < MAX_FRAMES, "carried over %d windows, then set off" % windows)
	assert_equal(brain.path, expected, "along the route a whole plan gives")
	assert_equal([space.routes.job_owner, space.routes.waiting()], [-1, 0], "the job done, nobody waiting")
	assert_true(space.routes.jobs_carried > 0, "counted as carried")


func test_while_a_job_is_under_way_others_wait_their_turn() -> void:
	"""One job at a time: a second resident ordered while the first's plan is carried over waits in the queue, and is
	served once the job is done."""
	var space := _wall_space(TINY_USEC)
	var first := _brain_at(space, Vector2(-1.0, -3.0), 7)
	var second := _brain_at(space, Vector2(1.0, -3.0), 8)
	first.order_move(Vector2(-1.0, 3.0))
	space.routes.end_window()
	assert_false(space.routes.may_plan(second.index), "no plan the desk could cut while the job is under way")
	second.order_move(Vector2(1.0, 3.0))
	assert_true(second.state == BrainScript.State.ROUTE and space.routes.waiting() == 2, "the second waits in line")
	var windows := _serve_until(space, func() -> bool: return _walking(first) and _walking(second))
	assert_true(windows < MAX_FRAMES, "both set off in turn")


func _depart_waiting(space: CastSpaceScript) -> BrainScript:
	"""A wanderer in the south spot, stepped until its own departure north waits on the desk."""
	var brain := _brain_at(space, space.slot_position(0, 0), 11)
	space.reserve(0, 0)
	brain.poi = 0
	brain.slot = 0
	for frame in MAX_FRAMES:
		brain.step(DT)
		if brain.state == BrainScript.State.ROUTE:
			break
	return brain


func test_a_departure_carried_over_goes_to_the_spot_it_picked() -> void:
	"""A wanderer's own departure, its plan carried over: it waits in ROUTE, holding its own slot, then goes to the very
	spot it picked."""
	var space := _wall_space(TINY_USEC)
	var brain := _depart_waiting(space)
	assert_equal([brain.state, brain._route_poi, brain.poi], [BrainScript.State.ROUTE, 1, 0], "waiting, the north kept")
	_serve_until(space, _walking.bind(brain))
	assert_true(_walking(brain) and brain.poi == 1, "off to the north")
	assert_equal([space.occupancy(0), space.occupancy(1)], [0, 1], "its slot moved with it")


func test_a_departure_whose_spot_is_taken_meanwhile_picks_again() -> void:
	"""The spot a waiting departure picked is taken before its plan is done: it idles a moment in its own slot."""
	var space := _wall_space(TINY_USEC)
	var brain := _depart_waiting(space)
	space.reserve(1, 0)
	_serve_until(space, func() -> bool: return brain.state != BrainScript.State.ROUTE)
	assert_equal([brain.state, brain.poi], [BrainScript.State.IDLE, 0], "idling where it was")


func test_released_while_its_plan_is_the_job_it_stays_put() -> void:
	"""A release while the job is under way: the job runs out and is dropped; the resident does not walk it."""
	var space := _wall_space(TINY_USEC)
	var brain := _brain_at(space, Vector2(0.0, -3.0), 7)
	brain.order_move(Vector2(0.0, 3.0))
	brain.release()
	var windows := _serve_until(space, func() -> bool: return space.routes.job_owner < 0)
	assert_true(windows < MAX_FRAMES, "the job dropped")
	assert_false(_walking(brain), "not walked")


func test_residents_waiting_for_one_spot_share_its_field() -> void:
	"""ONE FIELD PER SHARED GOAL: six residents ordered to one spot in a spent window; the first job past SHARED_MIN
	sharers searches the spot's field, every later plan to it is guided by it, and all of them set off."""
	var space := _village_space(TINY_USEC)
	var spots := _poi_spots()
	var brains: Array[BrainScript] = []
	for k in 6:
		brains.append(_brain_at(space, spots[k + 1], 20 + k))
	space.routes.charge(-1, 1000000)
	for brain in brains:
		brain.order_move(spots[0])
	assert_equal(space.routes.waiting(), 6, "all six wait")
	var windows := _serve_until(space, func() -> bool:
		for brain in brains:
			if not _walking(brain):
				return false
		return true)
	assert_true(windows < MAX_FRAMES, "all six set off")
	assert_equal(space.routes.worker.fields_built, 1, "one field for the spot, searched once")


func test_with_no_budget_the_desk_holds_no_job() -> void:
	"""Out of the live scene (no budget) a plan is made at once, whole, as before: no job, nobody waits."""
	var space := _village_space(0)
	var spots := _poi_spots()
	var brain := _brain_at(space, spots[0], 7)
	brain.order_move(spots[6])
	assert_true(_walking(brain), "off at once")
	assert_equal([space.routes.job_owner, space.routes.waiting(), space.routes.job_slices], [-1, 0, 0], "no job")


# --- the review's and the mutants' cases ------------------------------------------------------------------

func test_a_link_is_tested_against_everyone_whose_circle_it_could_cut() -> void:
	"""`_scan_standing` lists a resident whose centre lies past a link's length from the node but whose circle a link of
	that length could still cut."""
	var nav := CastNavScript.new()
	nav.setup(PackedVector3Array([Vector3(30.0, 1.0, 30.0)]))
	var crowd := PackedVector3Array([Vector3(4.3, 0.4, 0.0)])
	nav.begin_plan(Vector2(-6.0, 0.0), Vector2(6.0, 0.0), 0.25, crowd, 1)
	assert_true(nav._scan_standing(Vector2.ZERO, 4.0) >= 1, "4.3 m off, 0.4 m wide: within a 4 m link's reach")


func test_a_crowded_goal_still_reached_is_found_in_steps() -> void:
	"""A GOAL SHUT IN, its look carried in steps: two standing by a goal behind a post -- the look runs, reaches the
	start, and the search finds the route `plan` finds and the old planner found."""
	var circles := PackedVector3Array([Vector3(0.0, 2.0, 0.0)])
	var crowd := PackedVector3Array([Vector3(6.0, 0.3, 1.2), Vector3(6.0, 0.3, -1.2)])
	var nav := CastNavScript.new()
	nav.setup(circles)
	var old_nav := ReferenceNavScript.new()
	old_nav.setup(circles)
	var whole := PackedVector2Array()
	var theirs := PackedVector2Array()
	nav.plan(Vector2(-8.0, 0.0), Vector2(6.0, 0.0), 0.25, crowd, 2, whole)
	old_nav.plan(Vector2(-8.0, 0.0), Vector2(6.0, 0.0), 0.25, crowd, 2, theirs)
	assert_true(nav.last_found and whole == theirs, "round the post, as the old planner")
	nav.begin_plan(Vector2(-8.0, 0.0), Vector2(6.0, 0.0), 0.25, crowd, 2)
	assert_equal(nav._phase, CastNavScript.PHASE_SHUT_IN, "the goal crowded: looked at from its side first")
	while nav.step_plan(1) == CastNavScript.PLAN_PENDING:
		pass
	var stepped := PackedVector2Array()
	nav.finish_plan(stepped)
	assert_equal(stepped, whole, "the same route, a step at a time")


func _ring_fixture() -> Array:
	"""A post with a goal tucked against it, a ring of twelve standing round it at 2.2 m (shoulder to shoulder at the
	link inflation), a second post outside the ring by the start. [circles, crowd]."""
	var circles := PackedVector3Array([Vector3(0.0, 0.5, 0.0), Vector3(-5.0, 0.5, 0.0)])
	var crowd := PackedVector3Array()
	for k in 12:
		var angle := TAU * float(k) / 12.0
		crowd.append(Vector3(0.4 + cos(angle) * 2.2, 0.3, sin(angle) * 2.2))
	return [circles, crowd]


func test_a_goal_ringed_by_standing_residents_is_found_shut_in_without_a_search() -> void:
	"""A GOAL SHUT IN: the look from the goal's side runs out inside the ring -- the graph's edge out of it cut by the
	residents -- so the plan says no route with no search at all, as the old planner said after its whole search."""
	var parts := _ring_fixture()
	var crowd: PackedVector3Array = parts[1]
	var nav := CastNavScript.new()
	nav.setup(parts[0])
	var old_nav := ReferenceNavScript.new()
	old_nav.setup(parts[0])
	var out := PackedVector2Array()
	nav.plan(Vector2(-7.0, 0.0), Vector2(0.75, 0.0), 0.25, crowd, 12, out)
	assert_equal([nav.last_found, nav.last_expanded], [false, 0], "shut in: no route, nothing searched")
	old_nav.plan(Vector2(-7.0, 0.0), Vector2(0.75, 0.0), 0.25, crowd, 12, out)
	assert_true(not old_nav.last_found and old_nav.last_expanded > 0, "the old planner: no route, after a search")
	var open := crowd.slice(1)
	nav.plan(Vector2(-7.0, 0.0), Vector2(0.75, 0.0), 0.25, open, 11, out)
	var theirs := PackedVector2Array()
	old_nav.plan(Vector2(-7.0, 0.0), Vector2(0.75, 0.0), 0.25, open, 11, theirs)
	assert_true(nav.last_found and out == theirs, "one stepped out of the ring: in through the gap, as before")


func test_a_step_of_the_search_takes_the_field_only_away_from_the_goal() -> void:
	"""ONE FIELD PER SHARED GOAL: `estimate` is the field's past FIELD_NEAR_M from the goal and the straight line
	within it."""
	var nav := _new_nav()
	var goal := _poi_spots()[0]
	nav.begin_plan(_poi_spots()[5], goal, 0.4, PackedVector3Array(), 0, true)
	while nav.step_plan(64) == CastNavScript.PLAN_PENDING:
		pass
	var near_checked := 0
	var far_checked := 0
	for v in nav._h_field.size():
		var d := nav._graph.nodes[v].distance_to(goal)
		if nav._h_field[v] == INF:
			continue
		if d <= CastNavScript.FIELD_NEAR_M:
			near_checked += 1 if is_equal_approx(nav.estimate(v), d) else 0
		else:
			far_checked += 1 if nav.estimate(v) == nav._h_field[v] else 0
	assert_true(near_checked > 0 and far_checked > 0, "both kinds checked (%d near, %d far)" % [near_checked, far_checked])
	var wrong := 0
	for v in nav._h_field.size():
		var d := nav._graph.nodes[v].distance_to(goal)
		if nav._h_field[v] != INF and d > CastNavScript.FIELD_NEAR_M and nav.estimate(v) != nav._h_field[v]:
			wrong += 1
		elif nav._h_field[v] != INF and d <= CastNavScript.FIELD_NEAR_M and not is_equal_approx(nav.estimate(v), d):
			wrong += 1
	assert_equal(wrong, 0, "the field far off, the straight line near")


func test_a_guided_plan_keeps_its_standing_while_its_field_is_searched() -> void:
	"""A guided plan whose field is searched first keeps the standing residents it began with, though the caller's
	array is refilled meanwhile."""
	var nav := CastNavScript.new()
	nav.setup(PackedVector3Array([Vector3(-2.0, 1.0, 0.0), Vector3(2.0, 1.0, 0.0)]))
	var crowd := PackedVector3Array([Vector3(0.0, 0.4, 0.0)])
	var at_once := PackedVector2Array()
	nav.plan(Vector2(0.0, -4.0), Vector2(0.0, 4.0), 0.3, crowd, 1, at_once)
	nav.begin_plan(Vector2(0.0, -4.0), Vector2(0.0, 4.0), 0.3, crowd, 1, true)
	assert_equal(nav._phase, CastNavScript.PHASE_FIELD, "the field first")
	crowd[0] = Vector3(50.0, 0.4, 50.0)
	while nav.step_plan(1) == CastNavScript.PLAN_PENDING:
		pass
	var later := PackedVector2Array()
	nav.finish_plan(later)
	assert_true(later.size() > 1 and CastNavScript.path_length(Vector2(0.0, -4.0), later) >= \
			CastNavScript.path_length(Vector2(0.0, -4.0), at_once) - 1e-3, "round the one who stood there")


func test_a_field_searched_while_the_graph_was_swapped_is_not_used_on_the_new_graph() -> void:
	"""A guided plan whose field was searched on a graph swapped out before the search begins plans by the straight
	line on the new graph, and finds its route."""
	var owner := CastNavScript.new()
	owner.setup(PackedVector3Array([Vector3(0.0, 1.0, 0.0), Vector3(3.0, 1.0, 3.0)]))
	var worker := CastNavScript.new()
	worker.share_world(owner)
	worker.begin_plan(Vector2(-4.0, 0.5), Vector2(4.0, 0.5), 0.25, PackedVector3Array(), 0, true)
	worker.step_plan(2)
	owner.setup(PackedVector3Array([Vector3(0.0, 1.0, 0.0)]))
	worker.step_plan(1)
	assert_equal(worker._phase, CastNavScript.PHASE_FIELD, "begun again over the new circles, its field on the old graph")
	owner.advance_builds(1000000)
	var guard := 0
	while worker.step_plan(1) == CastNavScript.PLAN_PENDING and guard < 10000:
		guard += 1
	var out := PackedVector2Array()
	worker.finish_plan(out)
	assert_true(worker.last_found, "found")
	assert_true(worker._h_field.is_empty() or worker._h_graph == worker._graph, "no field from another graph")


func test_a_job_whose_resident_is_sent_elsewhere_meanwhile_is_dropped_and_the_new_trip_planned() -> void:
	"""THE JOB: a resident whose carried plan is under way is ordered somewhere else in a spent window: the old job is
	dropped, it waits its turn, and it walks the new trip's route, not the old one (the review's C1)."""
	var space := _wall_space(TINY_USEC)
	var brain := _brain_at(space, Vector2(0.0, -3.0), 7)
	brain.order_move(Vector2(0.0, 3.0))
	space.routes.end_window()
	space.routes.serve()
	assert_equal(space.routes.job_owner, brain.index, "its plan is the job, carried over")
	brain.order_move(Vector2(5.0, 3.0))
	assert_true(brain.state == BrainScript.State.ROUTE and space.routes.is_waiting(brain.index), "waiting again")
	var windows := _serve_until(space, _walking.bind(brain))
	assert_true(windows < MAX_FRAMES, "set off in %d windows" % windows)
	assert_equal(brain.path[brain.path.size() - 1], Vector2(5.0, 3.0), "toward the new spot")


func test_a_carried_plan_goes_round_the_residents_standing_when_it_began() -> void:
	"""THE JOB plans round everyone standing but its own resident, as a plan made at once does: someone standing on the
	way the empty village's route takes sends it another way."""
	var space := _wall_space(TINY_USEC)
	var empty := PackedVector2Array()
	space.nav.plan(Vector2(0.0, -3.0), Vector2(0.0, 3.0), 0.4, PackedVector3Array(), 0, empty)
	var blocker := _brain_at(space, empty[0], 5)
	var brain := _brain_at(space, Vector2(0.0, -3.0), 7)
	var expected := PackedVector2Array()
	space.nav.plan(Vector2(0.0, -3.0), Vector2(0.0, 3.0), 0.4,
		PackedVector3Array([Vector3(blocker.position.x, blocker.radius, blocker.position.y)]), 1, expected)
	assert_true(expected != empty, "the one standing changes the route")
	brain.order_move(Vector2(0.0, 3.0))
	_serve_until(space, _walking.bind(brain))
	assert_equal(brain.path, expected, "the carried plan went round it")


func test_the_desks_planner_follows_its_owners_new_circles_unasked() -> void:
	"""DIVISIBLE: the owner's circles change and nobody calls `share_world`: the second planner takes the new world
	before it plans, and goes round the wall that was not there."""
	var owner := CastNavScript.new()
	owner.setup(PackedVector3Array([Vector3(30.0, 1.0, 30.0)]))
	var worker := CastNavScript.new()
	worker.share_world(owner)
	var walls := PackedVector3Array([Vector3(30.0, 1.0, 30.0)])
	for k in 5:
		walls.append(Vector3(0.0, 1.0, -4.0 + 2.0 * float(k)))
	owner.setup(walls)
	var out := PackedVector2Array()
	worker.plan(Vector2(-4.0, 0.0), Vector2(4.0, 0.0), 0.25, PackedVector3Array(), 0, out)
	assert_true(worker.last_found and out.size() > 1, "round the new wall")
	assert_equal(worker.circles.size(), walls.size(), "with the owner's circles")


func test_a_job_whose_resident_is_reordered_in_a_fresh_window_plans_the_new_trip() -> void:
	"""THE JOB: ordered elsewhere while its plan is the job, in a window with room to plan whole, the resident's new plan
	is begun in place of the old one -- not the old route finished and picked up."""
	var space := _wall_space(TINY_USEC)
	var brain := _brain_at(space, Vector2(0.0, -3.0), 7)
	brain.order_move(Vector2(0.0, 3.0))
	assert_equal(space.routes.job_owner, brain.index, "its plan is the job")
	space.routes.end_window()
	space.routes.budget_usec = 1000000
	brain.order_move(Vector2(5.0, 3.0))
	assert_true(_walking(brain), "planned at once, in a window with room for it")
	assert_equal(brain.path[brain.path.size() - 1], Vector2(5.0, 3.0), "toward the new spot")
