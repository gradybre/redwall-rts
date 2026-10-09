extends "res://test/framework/test_case.gd"
## Route and infrastructure previews (decision 0461; review P5, ECO-039, ECO-045): the before/after estimate against
## the real router -- a tunnel and a bridge, each then built and planned for real; a loaded haul walked before and
## after a bridge; the estimate's work through the routing desk's budget; a group's fit member by member; the route
## overlay's stretch kinds; the blocked reasons from their real causes; and a large dig's stages. No scene tree and
## no staged assets: the graph suite's tunnel fixtures and the water suite's village rig (placeholder cast).

const Fixture := preload("res://test/test_demo_water_play.gd")
const EstimatorScript := preload("res://demo/routes/route_estimator.gd")
const PreviewScript := preload("res://demo/routes/preview_crossings.gd")
const KindsScript := preload("res://demo/routes/route_kinds.gd")
const ReasonsScript := preload("res://demo/routes/route_reasons.gd")
const StagesScript := preload("res://demo/routes/dig_stages.gd")
const TextScript := preload("res://demo/routes/route_text.gd")
const TripsScript := preload("res://demo/routes/work_trips.gd")
const DeskScript := preload("res://demo/cast/route_desk.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const SpecScript := preload("res://demo/tunnel/piece_spec.gd")
const PlanScript := preload("res://demo/tunnel/tunnel_plan.gd")
const RouterScript := preload("res://demo/tunnel/tunnel_router.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const CastNavScript := preload("res://demo/cast/cast_nav.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const CrossingHookScript := preload("res://demo/cast/crossing_hook.gd")
const BridgesScript := preload("res://demo/waterplay/bridges.gd")
const SwimRules := preload("res://demo/waterplay/swim_rules.gd")
const CrossingsScript := preload("res://demo/waterplay/water_crossings.gd")
const MotionScript := preload("res://demo/waterplay/swim_motion.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const ProjectScript := preload("res://demo/routes/bridge_project.gd")
const RescueCardScript := preload("res://demo/routes/rescue_card.gd")
const OverlayScript := preload("res://demo/routes/route_overlay.gd")
const CardsScript := preload("res://demo/ui/demo_incident_cards.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const LevelsTest := preload("res://test/test_demo_levels.gd")
const SafetyTest := preload("res://test/test_demo_water_safety.gd")
const DiveTaskScript := preload("res://demo/waterplay/dive_task.gd")
const WaterMapScript := preload("res://demo/water/water_map.gd")
const CardScript := preload("res://demo/ui/action_card.gd")
const TasksScript := preload("res://demo/waterplay/rescue_tasks.gd")
const FleetScript := preload("res://demo/boats/boat_fleet.gd")
const BoatRoutes := preload("res://demo/boats/boat_routes.gd")

const DT: float = 1.0 / 60.0
const BODY_M: float = 0.25
const BOUNDS_U := Rect2i(-20480, -20480, 40960, 40960)
## The water rig's neck crossing (test_demo_water_play.gd): the west bank and the east bank opposite the neck.
const NECK_WEST: Vector2 = Vector2(19.0, -25.5)
const NECK_EAST: Vector2 = Vector2(28.0, -25.5)
const COST_EPS: float = 0.001

var _water: Fixture = Fixture.new()
var _read: IntMath.IntResult = IntMath.IntResult.new()


func before_each() -> void:
	"""The water fixture's own fresh services."""
	_water.before_each()


func after_each() -> void:
	"""Free what the water fixture built."""
	_water.after_each()


# --- fixtures (the graph suite's) --------------------------------------------------------------------

static func _route(points: Array[Vector2i]) -> PackedInt32Array:
	"""(x, z) points in u as a flat route."""
	var out := PackedInt32Array()
	for p: Vector2i in points:
		out.append_array([p.x, p.y])
	return out


static func _dig(graph: GraphScript, p: int) -> void:
	"""Dig every segment of piece `p` open, in its order."""
	var chain := PackedInt32Array()
	graph.piece_segments_into(p, chain)
	for slot: int in chain:
		graph.start_dig(slot, graph.generation[slot], 0)
		graph.advance(slot, graph.generation[slot], 1000000000)


static func _pen(centre: Vector2) -> Array[Vector3]:
	"""Twelve overlapping 0.9 m circles on a 3 m ring round `centre`: a closed pen."""
	var ring: Array[Vector3] = []
	for k: int in 12:
		var at := centre + Vector2(cos(TAU * k / 12.0), sin(TAU * k / 12.0)) * 3.0
		ring.append(Vector3(at.x, 0.9, at.y))
	return ring


static func _penned_tee(dig_branch: bool) -> CastSpaceScript:
	"""The graph suite's pen round (0, 12) with a 16 m tunnel east-west at z = 4 (slots 0 ramp, 1 bore, 2 ramp), and a
	branch (piece 1) from its middle north to a mouth at the pen's centre: dug when `dig_branch`, else planned."""
	var space := CastSpaceScript.new()
	space.setup([], _pen(Vector2(0.0, 12.0)))
	var graph := space.tunnels
	var ref := PackedInt32Array([-1, 0, -1])
	graph.add_into(_route([Vector2i(-8192, 4096), Vector2i(8192, 4096)]), 2, 0, ref)
	_dig(graph, ref[2])
	var spec := SpecScript.new()
	spec.set_route(_route([Vector2i(0, 4096), Vector2i(0, 12288)]), 2)
	spec.start_kind = SpecScript.END_ON_SEGMENT
	spec.start_ref = 1
	graph.add_piece(spec, ref)
	if dig_branch:
		_dig(graph, ref[2])
	return space


static func _walker(space: CastSpaceScript, at: Vector2, walker_seed: int = 11) -> BrainScript:
	"""A resident who fits a bore, standing at `at`."""
	var lengths := {}
	for clip: StringName in DemoActorScript.CLIPS:
		lengths[clip] = 2.0
	var brain := BrainScript.new()
	brain.configure(space, 1.0, BODY_M, walker_seed, lengths)
	brain.start_at(at, 0.0, -1, -1)
	space.tunnels.set_fit(brain.index, true)
	return brain


static func _estimator(space: CastSpaceScript) -> EstimatorScript:
	"""An estimator over `space`'s planner, network and crossings (no water)."""
	var estimate := EstimatorScript.new()
	estimate.configure(space.nav, space.tunnels, space.crossings, Callable())
	return estimate


static func _live_cost(space: CastSpaceScript, who: int, from: Vector2, to: Vector2, loaded: bool,
		out: PackedVector2Array, legs: PackedInt32Array) -> float:
	"""The live router's own cost for a trip planned as cast_space.gd `plan_path` plans it, nobody standing about:
	through the LIVE network's router and the LIVE crossings (INF: no route) -- and, where plan_path consults no
	crossings and so prices no wading, the route's wading priced as the router prices it with the water's hook (the
	estimate's ONE FOOTING, worked here on its own)."""
	var graph: GraphScript = space.tunnels
	var tunnels: bool = graph.open_count() > 0 and graph.fits_any(who, loaded)
	var crossings: bool = space.crossings.offers_for(who, from, to, loaded)
	var found: bool = graph.plan(space.nav, from, to, BODY_M, PackedVector3Array(), 0, out, legs, who, loaded,
		space.crossings if crossings else null, tunnels)
	if not found:
		return INF
	var wading := 0.0
	if not crossings:
		var at := from
		for k: int in out.size():
			if legs[k] == RouterScript.SURFACE_LEG:
				wading += space.crossings.wade_extra_m(at, out[k]) * 1000.0 / float(graph.surface_permille)
			at = out[k]
	return graph.router.last_cost_m() + wading


# --- the estimate against the real router ------------------------------------------------------------

func test_a_tunnel_s_after_estimate_is_the_router_s_cost_once_it_is_dug() -> void:
	"""The penned tee: into the pen there is no way while the branch is only planned (the estimate's before is no way,
	as the live plan's), and the estimate of the branch dug open is exactly what the live router costs and plans once it
	is dug -- the same route, segment for segment."""
	var space := _penned_tee(false)
	var brain := _walker(space, Vector2(-9.5, 4.5))
	var from := Vector2(-9.5, 4.5)
	var to := Vector2(0.6, 12.4)
	var estimate := _estimator(space)
	estimate.set_walker(brain.index, BODY_M, false)
	estimate.clear_trips()
	estimate.add_trip(from, to, "into the pen")
	estimate.propose_open(1)
	estimate.start(1)
	space.nav.last_found = true
	estimate.run_all()
	assert_true(estimate.is_done(), "done")
	assert_true(space.nav.last_found, "the surface planner's last answer left as the live plans left it")
	var live := PackedVector2Array()
	var legs := PackedInt32Array()
	assert_equal(_live_cost(space, brain.index, from, to, false, live, legs), INF, "no way in yet, live")
	assert_equal(estimate.before_m[0], INF, "nor in the estimate")
	_dig(space.tunnels, 1)
	var cost := _live_cost(space, brain.index, from, to, false, live, legs)
	assert_true(cost < INF, "a way in once dug")
	assert_almost_equal(estimate.after_m[0], cost, "the estimate is the router's cost: %f vs %f" % [estimate.after_m[0], cost])
	assert_equal(estimate.after_legs[0], legs, "and its route, leg for leg")
	var planned := PackedVector2Array()
	var planned_legs := PackedInt32Array()
	space.plan_path(brain.index, from, to, BODY_M, planned, planned_legs)
	assert_equal(planned_legs, legs, "the very route a resident's own plan takes")


func test_a_before_estimate_over_the_live_network_is_the_router_s_cost_in_the_rain() -> void:
	"""With the branch dug and the surface at 80% for rain, two trips (one the tunnel shortens): the estimate's before
	(no proposal) is planned by the live router itself -- its cost exactly the router's -- and changes nothing live."""
	var space := _penned_tee(true)
	space.tunnels.surface_permille = 800
	var brain := _walker(space, Vector2(-9.5, 4.5))
	var estimate := _estimator(space)
	estimate.set_walker(brain.index, BODY_M, false)
	estimate.add_trip(Vector2(-9.5, 4.5), Vector2(0.6, 12.4), "into the pen")
	estimate.add_trip(Vector2(9.0, 3.0), Vector2(-9.0, 5.0), "along the tunnel")
	estimate.propose_nothing()
	var revision := space.tunnels.revision
	space.tunnels.router.last_surface_plans = -1
	estimate.start(7)
	estimate.run_all()
	assert_true(space.tunnels.router.last_surface_plans >= 0, "planned by the live router itself, its cache shared")
	var live := PackedVector2Array()
	var legs := PackedInt32Array()
	for k: int in 2:
		var cost := _live_cost(space, brain.index, estimate.trip_from[k], estimate.trip_to[k], false, live, legs)
		assert_almost_equal(estimate.before_m[k], cost, "trip %d: the router's own cost" % k)
	assert_equal(space.tunnels.revision, revision, "the live network untouched")


func test_a_bridge_s_after_estimate_is_the_router_s_cost_once_it_is_built() -> void:
	"""The water rig's neck: a loaded walker from the west bank to the east goes round by the ford; the estimate of a
	plank footbridge at the neck is, to the millimetre, what the live router costs once that bridge is built and open --
	and it measurably shortens the haul (the review's acceptance: "built travel benefits are observable")."""
	var rig: Fixture.Rig = _water._rig()
	var space: CastSpaceScript = rig.cast.space()
	space.tunnels.surface_permille = 800
	var estimate := EstimatorScript.new()
	estimate.configure(space.nav, space.tunnels, space.crossings, _crosses(rig))
	estimate.set_walker(1, 0.22, true)
	estimate.add_trip(NECK_WEST, NECK_EAST, "across the neck")
	var survey := BridgesScript.Survey.new()
	rig.play.bridges.survey_candidate_into(0, SwimRules.KIND_PLANK, survey)
	var scratch := _scratch_bridge(rig, survey)
	estimate.propose_bridge(scratch.approach(0, false), scratch.approach(0, true), scratch.walk_length_m(0))
	estimate.start(3)
	estimate.run_all()
	var live := PackedVector2Array()
	var legs := PackedInt32Array()
	var before := _live_cost(space, 1, NECK_WEST, NECK_EAST, true, live, legs)
	assert_almost_equal(estimate.before_m[0], before, "before: the router's cost round by the ford (%f)" % before)
	_build(rig, survey)
	var after := _live_cost(space, 1, NECK_WEST, NECK_EAST, true, live, legs)
	assert_true(absf(estimate.after_m[0] - after) < COST_EPS, "after: the router's cost over the bridge (%f vs %f)" % [estimate.after_m[0], after])
	assert_true(_has_crossing(legs) and _has_crossing(estimate.after_legs[0]), "both over a crossing")
	assert_true(after < before * 0.6, "measurably quicker: %.1f m -> %.1f m" % [before, after])
	var other := BridgesScript.Survey.new()
	assert_true(rig.play.bridges.survey_candidate_into(1, SwimRules.KIND_PLANK, other), "a second site upstream")
	var second := _scratch_bridge(rig, other)
	var both := EstimatorScript.new()
	both.configure(space.nav, space.tunnels, space.crossings, _crosses(rig))
	both.set_walker(1, 0.22, true)
	both.add_trip(NECK_WEST, NECK_EAST, "across the neck")
	both.add_trip(Vector2(0.0, 2.0), Vector2(8.0, 4.0), "a dry walk in the village")
	both.propose_bridge(second.approach(0, false), second.approach(0, true), second.walk_length_m(0))
	both.start(6)
	both.run_all()
	assert_true(absf(both.after_m[0] - after) < COST_EPS, "a second bridge proposed: the built one is still offered")
	var hook := PreviewScript.new()
	hook.configure(space.crossings, _crosses(rig))
	hook.propose(second.approach(0, false), second.approach(0, true), 5.0, 1000)
	assert_false(hook.offers_for(1, Vector2(0.0, 2.0), Vector2(8.0, 4.0), true), "a dry trip is offered no crossing")
	assert_true(hook.offers_for(1, NECK_WEST, NECK_EAST, true), "one over the water is")
	var now := EstimatorScript.new()
	now.configure(space.nav, space.tunnels, space.crossings, _crosses(rig))
	now.set_walker(1, 0.22, true)
	now.add_trip(NECK_WEST, NECK_EAST, "across the neck")
	now.start(4)
	now.run_all()
	assert_true(absf(now.before_m[0] - after) < COST_EPS, "built: an estimate of how things are now is over it too")


func test_a_loaded_haul_walked_before_and_after_the_bridge_takes_what_the_estimate_says() -> void:
	"""The repeatable haul fixture: the same walker walks the neck crossing before and after the footbridge is built;
	each walk takes the estimate's time at its pace to within 35% (turns and the bank's slope are not in a route's
	cost), and the walk after is quicker by about what the estimate said."""
	var rig: Fixture.Rig = _water._rig()
	var space: CastSpaceScript = rig.cast.space()
	var estimate := EstimatorScript.new()
	estimate.configure(space.nav, space.tunnels, space.crossings, _crosses(rig))
	var walker: BrainScript = _water._brain(rig, 1)
	estimate.set_walker(1, walker.radius, true)
	estimate.add_trip(NECK_WEST, NECK_EAST, "across the neck")
	var survey := BridgesScript.Survey.new()
	rig.play.bridges.survey_candidate_into(0, SwimRules.KIND_PLANK, survey)
	var scratch := _scratch_bridge(rig, survey)
	estimate.propose_bridge(scratch.approach(0, false), scratch.approach(0, true), scratch.walk_length_m(0))
	estimate.start(5)
	estimate.run_all()
	var walked_before := _walk_haul(rig, 1)
	_build(rig, survey)
	var walked_after := _walk_haul(rig, 1)
	var said_before := EstimatorScript.seconds_of(estimate.before_m[0], walker.walk_speed)
	var said_after := EstimatorScript.seconds_of(estimate.after_m[0], walker.walk_speed)
	assert_true(walked_before > 0.0 and walked_after > 0.0, "both walks arrived (%.1f s, %.1f s)" % [walked_before, walked_after])
	assert_true(absf(walked_before - said_before) <= 0.35 * said_before, "before: walked %.1f s, estimated %.1f s" % [walked_before, said_before])
	assert_true(absf(walked_after - said_after) <= 0.35 * said_after, "after: walked %.1f s, estimated %.1f s" % [walked_after, said_after])
	assert_true(walked_after < walked_before * 0.7, "the bridge shortens the haul: %.1f s -> %.1f s" % [walked_before, walked_after])


func _walk_haul(rig: Fixture.Rig, who: int) -> float:
	"""Walk resident `who` from the neck's west bank to its east bank and back to where it stood; the demo seconds the
	trip out took (-1: it did not arrive). Every other resident holds well away, so nobody stands in the way."""
	for other: int in rig.cast.actor_count():
		if other != who:
			_water._place(rig, other, Vector2(-14.0 + float(other), 18.0))
	_water._place(rig, who, NECK_WEST)
	var brain: BrainScript = _water._brain(rig, who)
	brain.order_move(NECK_EAST)
	var seconds := 0.0
	for frame: int in 6000:
		if brain.arrived_near(NECK_EAST, 0.3):
			return seconds
		rig.cast.advance(0.05)
		rig.play.step(rig.cast.clock.frame_usec)
		seconds += 0.05
	return -1.0


func _crosses(rig: Fixture.Rig) -> Callable:
	"""The live water's straight-line test."""
	var map: WaterMapScript = rig.play.map()
	return func(a: Vector2, b: Vector2) -> bool: return map.segment_crosses_water(MotionScript.u_of(a), MotionScript.u_of(b), 0)


func _scratch_bridge(rig: Fixture.Rig, survey: BridgesScript.Survey) -> BridgesScript:
	"""A bridge table of its own with the surveyed bridge in row 0 (the figures a planned row gives)."""
	var scratch := BridgesScript.new()
	scratch.configure(rig.play.map(), [] as Array[Vector3], rig.play.links.area)
	assert_true(scratch.plan_into(survey, "proposal", _read), "planned on the scratch table")
	return scratch


func _build(rig: Fixture.Rig, survey: BridgesScript.Survey) -> void:
	"""Plan the surveyed bridge for real and work it open."""
	assert_true(rig.play.bridges.plan_into(survey, "neck bridge", _read), "planned")
	var row: int = _read.value
	for stage: int in SwimRules.STAGE_COUNT:
		rig.play.bridges.add_work(row, rig.play.bridges.stage_left_wu(row, stage))
	rig.play.crossings.bump()
	assert_true(rig.play.bridges.is_open(row), "open")


static func _has_crossing(legs: PackedInt32Array) -> bool:
	"""Whether a route's leg codes cross a crossing."""
	for code: int in legs:
		if RouterScript.is_crossing_code(code):
			return true
	return false


# --- the budget -----------------------------------------------------------------------------------------

func test_the_estimate_plans_one_piece_a_window_and_only_when_the_desk_has_room() -> void:
	"""Nothing in a burst: a spent window refuses the step; a resident waiting for its route refuses it; each step is
	ONE piece (the copies, or one plan), charged to the window; a whole estimate takes 1 + 2 x trips windows, saying
	it is calculating until the last."""
	var space := _penned_tee(true)
	var brain := _walker(space, Vector2(-9.5, 4.5))
	var desk := DeskScript.new()
	desk.register(0, func() -> void: pass)
	desk.budget_usec = 3500
	var estimate := _estimator(space)
	estimate.set_walker(brain.index, BODY_M, false)
	estimate.add_trip(Vector2(-9.5, 4.5), Vector2(0.6, 12.4), "a")
	estimate.add_trip(Vector2(9.0, 3.0), Vector2(-9.0, 5.0), "b")
	estimate.propose_open(1)
	estimate.start(11)
	assert_equal(estimate.steps_total(), 5, "copies, then two trips before and after")
	desk.charge(-1, 1000000)
	assert_false(estimate.step(desk), "a spent window: no step")
	assert_equal(estimate.plans_run, 0, "nothing planned")
	desk.end_window()
	desk.wait(0)
	assert_false(estimate.step(desk), "a resident waiting for its route goes first")
	desk.forget(0)
	var windows := 0
	while estimate.is_calculating():
		assert_true(TextScript.trip_line(estimate, 1, 1.0).ends_with(TextScript.CALCULATING), "calculating until done")
		var plans := estimate.plans_run
		assert_true(estimate.step(desk), "a fresh window takes one step")
		assert_true(estimate.plans_run - plans <= 1, "one plan at most")
		assert_true(desk.spent_usec() > 0, "charged to the window")
		desk.end_window()
		windows += 1
	assert_equal(windows, 5, "five windows")
	assert_equal(estimate.plans_run, 4, "four plans")
	assert_true(estimate.is_done(), "done")
	assert_false(TextScript.trip_line(estimate, 1, 1.0).ends_with(TextScript.CALCULATING), "then a time")


func test_an_estimate_starts_again_when_the_network_changes_and_not_otherwise() -> void:
	"""The same request keeps its answer; a network change (a closure) makes it stale and it is worked again."""
	var space := _penned_tee(true)
	var brain := _walker(space, Vector2(-9.5, 4.5))
	var estimate := _estimator(space)
	estimate.set_walker(brain.index, BODY_M, false)
	estimate.add_trip(Vector2(-9.5, 4.5), Vector2(0.6, 12.4), "a")
	estimate.start(1)
	estimate.run_all()
	var restarts := estimate.restarts
	estimate.start(1)
	assert_equal([estimate.restarts, estimate.is_done()], [restarts, true], "kept")
	space.tunnels.close(4, GraphScript.CLOSED_FLOODED, 0, 1024)
	estimate.start(1)
	assert_true(estimate.is_calculating(), "stale: worked again")
	estimate.run_all()
	assert_equal(estimate.before_m[0], INF, "the flooded branch: no way into the pen")


# --- a group, member by member ------------------------------------------------------------------------

func test_a_group_s_fit_is_said_member_by_member_never_the_lead_s() -> void:
	"""MOVE-REQ-012: a group led by one who fits a widened bore loaded, with one who fits it only unloaded and one too
	big: each member's own verdict, from the network's fit -- the lead fitting never speaks for the rest."""
	var graph := GraphScript.new()
	graph.set_body(0, 1024, 256)
	graph.set_body(1, 2611, 573)
	graph.set_body(2, 4000, 1400)
	var names := ["Mouse keeper", "Badger quarryman", "Giant"]
	var lines := TextScript.member_lines(graph, PackedInt32Array([0, 1, 2]), Rules.BORE_WIDE, true,
		func(who: int) -> String: return names[who])
	assert_equal(lines, PackedStringArray(["Mouse keeper: " + TextScript.FITS, "Badger quarryman: " + TextScript.FITS_UNLOADED,
		"Giant: " + TextScript.TOO_BIG]), "each member its own")
	assert_equal(ReasonsScript.fit_reason(graph, 1, Rules.BORE_WIDE, false), ReasonsScript.NONE, "the badger unloaded fits")
	assert_equal(TextScript.fit_counts(graph, 3, Rules.BORE_WIDE), Vector2i(2, 1), "two fit, one carrying")


# --- the overlay's stretches ---------------------------------------------------------------------------

func test_a_route_s_stretches_are_surface_underground_by_level_and_its_crossings() -> void:
	"""Into the pen through the dug branch: surface to mouth A, underground on level 1 (ramp, bore, branch bore, ramp)
	and out in the pen; read from the route's own leg codes."""
	var space := _penned_tee(true)
	var brain := _walker(space, Vector2(-9.5, 4.5))
	var path := PackedVector2Array()
	var legs := PackedInt32Array()
	space.plan_path(brain.index, Vector2(-9.5, 4.5), Vector2(0.6, 12.4), BODY_M, path, legs)
	var kinds := KindsScript.new()
	var k := PackedInt32Array()
	var levels := PackedInt32Array()
	kinds.kinds_into(space.tunnels, Vector2(-9.5, 4.5), path, legs, k, levels)
	assert_equal(k[0], KindsScript.KIND_SURFACE, "to the mouth on the surface")
	assert_true(k.count(KindsScript.KIND_UNDERGROUND) == 4, "four segments below: %s" % k)
	for i: int in k.size():
		if k[i] == KindsScript.KIND_UNDERGROUND:
			assert_equal(levels[i], 1, "level 1")
	assert_true(kinds.runs_text(space.tunnels, Vector2(-9.5, 4.5), path, legs).begins_with("surface"), "runs in words")
	assert_true(kinds.runs_text(space.tunnels, Vector2(-9.5, 4.5), path, legs).contains("underground, level 1"), "below")


func test_water_stretches_are_wading_a_bridge_a_swim_and_the_proposed_bridge() -> void:
	"""The village water: a loaded walk round by the ford wades; a swimmer across the run swims; over a built bridge is
	a bridge; and an estimate's after over the proposal is the proposed bridge -- each from its leg code and the water's
	own wading cost."""
	var rig: Fixture.Rig = _water._rig()
	var space: CastSpaceScript = rig.cast.space()
	var kinds := KindsScript.new()
	kinds.configure(space.crossings, CrossingsScript.LINK_ROW0, rig.play.links.link_count)
	var path := PackedVector2Array()
	var legs := PackedInt32Array()
	space.plan_path(1, NECK_WEST, NECK_EAST, 0.22, path, legs, true, true)
	assert_true(kinds.has_kind(NECK_WEST, path, legs, KindsScript.KIND_WADE), "round by the ford: wading")
	_water._swimmer(rig, 0, 1100)
	space.plan_path(0, Fixture.WEST_BANK, Fixture.EAST_BANK, 0.22, path, legs)
	assert_true(kinds.has_kind(Fixture.WEST_BANK, path, legs, KindsScript.KIND_SWIM), "a swimmer swims the link")
	var estimate := EstimatorScript.new()
	estimate.configure(space.nav, space.tunnels, space.crossings, _crosses(rig))
	estimate.set_walker(1, 0.22, true)
	estimate.add_trip(NECK_WEST, NECK_EAST, "across")
	var survey := BridgesScript.Survey.new()
	rig.play.bridges.survey_candidate_into(0, SwimRules.KIND_PLANK, survey)
	var scratch := _scratch_bridge(rig, survey)
	estimate.propose_bridge(scratch.approach(0, false), scratch.approach(0, true), scratch.walk_length_m(0))
	estimate.start(2)
	estimate.run_all()
	assert_true(kinds.has_kind(NECK_WEST, estimate.after_paths[0], estimate.after_legs[0], KindsScript.KIND_PROPOSED),
		"after: over the proposed bridge")
	_build(rig, survey)
	space.plan_path(1, NECK_WEST, NECK_EAST, 0.22, path, legs, true, true)
	assert_true(kinds.has_kind(NECK_WEST, path, legs, KindsScript.KIND_BRIDGE), "built: a bridge")
	assert_false(kinds.has_kind(NECK_WEST, path, legs, KindsScript.KIND_WADE), "no wading now")


# --- the blocked reasons --------------------------------------------------------------------------------

func test_finding_a_route_is_the_desk_s_wait() -> void:
	"""A resident ordered in a spent routing window waits at the desk: "finding a route", where it stands."""
	var space := _penned_tee(true)
	var brain := _walker(space, Vector2(-9.5, 4.5))
	space.routes.budget_usec = 1000
	space.routes.charge(-1, 1000000)
	brain.order_move(Vector2(0.6, 12.4))
	var where := ReasonsScript.Where.new()
	assert_equal(ReasonsScript.diagnose(brain, space.tunnels, where), ReasonsScript.FINDING_ROUTE, "at the desk")
	assert_equal(where.at, brain.position, "where it stands")
	assert_equal(ReasonsScript.WORDS[ReasonsScript.FINDING_ROUTE], "finding a route", "in the review's words")


func test_a_flood_or_a_fall_ahead_is_said_at_that_segment_s_entry() -> void:
	"""Planned through the branch, then the branch's bore floods: "closed by flood" at its entry node; a fall instead:
	"closed by a roof fall"."""
	for closure: int in [GraphScript.CLOSED_FLOODED, GraphScript.CLOSED_COLLAPSED]:
		var space := _penned_tee(true)
		var brain := _walker(space, Vector2(-9.5, 4.5))
		brain.order_move(Vector2(0.6, 12.4))
		assert_true(brain.path_tunnel.has(RouterScript.leg_code(4, false)), "through the branch's bore 4")
		space.tunnels.close(4, closure, 0, 1024)
		var where := ReasonsScript.Where.new()
		var expected: int = ReasonsScript.CLOSED_FLOOD if closure == GraphScript.CLOSED_FLOODED else ReasonsScript.CLOSED_FALL
		assert_equal(ReasonsScript.diagnose(brain, space.tunnels, where), expected, "the closure ahead")
		assert_true(where.at.distance_to(Vector2(0.0, 4.0)) < 0.01, "at the junction it enters by (%s)" % where.at)


func test_a_load_taken_up_after_planning_is_too_wide_for_the_bore_ahead() -> void:
	"""A big body routed unloaded through a widened bore it fits, then carrying: "load too wide" at that bore -- the
	network's own fit (a load across the body is 85% of its height)."""
	var space := _penned_tee(true)
	for slot: int in Rules.MAX_SEGMENTS:
		if space.tunnels.is_open(slot):
			space.tunnels.set_bore(slot, Rules.BORE_WIDE)
	var brain := _walker(space, Vector2(-9.5, 4.5))
	space.tunnels.set_body(brain.index, 2611, 573)
	brain.order_move(Vector2(0.6, 12.4))
	assert_true(brain.crosses_tunnel(), "through the widened tunnel")
	var where := ReasonsScript.Where.new()
	assert_equal(ReasonsScript.diagnose(brain, space.tunnels, where), ReasonsScript.NONE, "unloaded: nothing in the way")
	brain.carrying = true
	assert_equal(ReasonsScript.diagnose(brain, space.tunnels, where), ReasonsScript.LOAD_TOO_WIDE, "loaded: too wide")


func test_waiting_in_a_mouth_s_line_is_said_at_the_mouth() -> void:
	"""Someone else holds mouth A's grant: the walker reaching it joins the line -- "waiting for mouth", at mouth A."""
	var space := _penned_tee(true)
	var brain := _walker(space, Vector2(-11.5, 4.0))
	space.tunnels.queue.take(0, 99)
	brain.order_move(Vector2(0.6, 12.4))
	for frame: int in 600:
		brain.step(DT)
		if brain.state == BrainScript.State.QUEUE:
			break
	var where := ReasonsScript.Where.new()
	assert_equal(ReasonsScript.diagnose(brain, space.tunnels, where), ReasonsScript.WAITING_MOUTH, "in the line")
	assert_true(where.at.distance_to(space.tunnels.mouth_at(0)) < 0.01, "at mouth A (%s)" % where.at)


func test_stranded_below_with_every_way_out_closed_is_no_safe_exit() -> void:
	"""Walking the branch when every other segment closes: no way out -- "no safe exit", where it stands."""
	var space := _penned_tee(true)
	var brain := _walker(space, Vector2(-9.5, 4.5))
	brain.order_move(Vector2(0.6, 12.4))
	for frame: int in 3000:
		brain.step(DT)
		if brain.is_in_bore(4):
			break
	assert_true(brain.is_in_bore(4), "in the branch's bore")
	for slot: int in [0, 1, 2, 3, 5]:
		space.tunnels.close(slot, GraphScript.CLOSED_COLLAPSED, 0, 1024)
	for frame: int in 600:
		brain.step(DT)
		if brain.is_stranded():
			break
	var where := ReasonsScript.Where.new()
	assert_equal(ReasonsScript.diagnose(brain, space.tunnels, where), ReasonsScript.NO_SAFE_EXIT, "stranded")
	assert_equal(where.at, brain.position, "where it stands")


func test_a_trip_with_no_route_at_all_is_said_at_its_goal() -> void:
	"""A dig whose start lies below, cut off: the brain refuses the empty route -- "can't find a way there", at the
	goal."""
	var space := _penned_tee(false)
	var brain := _walker(space, Vector2(-9.5, 4.5))
	for slot: int in [0, 1, 2, 3]:
		space.tunnels.close(slot, GraphScript.CLOSED_COLLAPSED, 0, 1024)
	var first := space.tunnels.first_of_piece(1)
	space.tunnels.start_dig(first, space.tunnels.generation[first], brain.index)
	brain.order_dig(first, space.tunnels.generation[first])
	var where := ReasonsScript.Where.new()
	assert_true(brain.trip_failed(), "given up")
	assert_equal(ReasonsScript.diagnose(brain, space.tunnels, where), ReasonsScript.NO_ROUTE, "no route")
	assert_equal(where.at, brain.goal(), "at its goal")


# --- a large dig's stages (ECO-045) ----------------------------------------------------------------------

func _crossing_dig() -> GraphScript:
	"""A 12 m main tunnel east from the origin, dug; and a 16 m piece (row 1) laid north across it from a new mouth at
	z = -8 m to a new mouth at z = +8 m, crossing the main bore at (6, 0): a ramp, a bore to the junction, a bore on,
	a ramp."""
	var graph := GraphScript.new()
	var ref := PackedInt32Array([-1, 0, -1])
	graph.add_into(_route([Vector2i(0, 0), Vector2i(12288, 0)]), 2, 0, ref)
	_dig(graph, ref[2])
	var plan := PlanScript.new()
	var snap := PackedInt32Array([0, -1, 0, 0])
	for p: Vector2i in [Vector2i(6144, -8192), Vector2i(6144, 8192)]:
		var kind := PlanScript.snap_into(graph, p, snap)
		plan.try_add_snapped(snap[2], snap[3], kind, snap[1], BOUNDS_U, PackedInt32Array())
	assert_equal(plan.piece_reason(graph, BOUNDS_U, PackedInt32Array()), Rules.REFUSE_NONE, "the crossing may be dug")
	assert_true(graph.add_piece(plan.spec_of(0), ref), "laid")
	return graph


func test_a_large_dig_reads_as_a_junction_then_a_connection() -> void:
	"""The crossing piece's milestones: the junction where it meets the main bore, then the connection at its far
	mouth; nothing dug yet, the junction is next."""
	var graph := _crossing_dig()
	var stages := StagesScript.new()
	stages.read(graph, 1)
	assert_equal(stages.chain.size(), 4, "ramp, bore, bore, ramp")
	assert_equal(stages.kinds, PackedInt32Array([StagesScript.JUNCTION, StagesScript.CONNECTION]), "junction, connection")
	assert_equal(stages.upto, PackedInt32Array([2, 4]), "two segments to the junction, four to the end")
	assert_equal([stages.reached, stages.next_milestone(), stages.heading_segments], [0, 0, 0], "nothing dug")
	assert_equal(stages.stage_line(0), "Stage 1 of 2: junction — next", "in words")


func test_a_finished_stage_is_told_apart_from_a_dead_end_heading() -> void:
	"""Dug segment by segment: the ramp alone is a heading (no stage); to the junction, stage 1 done and no heading; the
	bore past it, a heading again; the last ramp, every stage done."""
	var graph := _crossing_dig()
	var stages := StagesScript.new()
	stages.read(graph, 1)
	var chain := stages.chain.duplicate()
	var expect: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 0)]
	for k: int in chain.size():
		graph.start_dig(chain[k], graph.generation[chain[k]], 0)
		graph.advance(chain[k], graph.generation[chain[k]], 1000000000)
		stages.read(graph, 1)
		assert_equal(Vector2i(stages.reached, stages.heading_segments), expect[k], "after segment %d" % k)
	assert_true(stages.is_finished(), "all stages")
	assert_equal(stages.next_milestone(), -1, "nothing next")


func test_the_next_payoff_counts_the_work_left_to_it() -> void:
	"""Half the ramp dug: 50% of the way to the junction (its two segments' ticks, the ramp's half of them)."""
	var graph := _crossing_dig()
	var stages := StagesScript.new()
	stages.read(graph, 1)
	var ramp: int = stages.chain[0]
	graph.start_dig(ramp, graph.generation[ramp], 0)
	var to_junction := graph.total_ticks(stages.chain[0]) + graph.total_ticks(stages.chain[1])
	graph.advance(ramp, graph.generation[ramp], 0)
	assert_equal(stages.percent_to_next(graph), 0, "nothing yet")
	_dig_ticks(graph, ramp, graph.total_ticks(ramp))
	stages.read(graph, 1)
	@warning_ignore("integer_division") assert_equal(stages.percent_to_next(graph), graph.total_ticks(ramp) * 100 / to_junction, "the ramp's share")


static func _dig_ticks(graph: GraphScript, slot: int, ticks: int) -> void:
	"""Dig `ticks` ticks of segment `slot` at one F1000 worker (1 tick = 1/30 s)."""
	@warning_ignore("integer_division") graph.advance(slot, graph.generation[slot], ticks * 1000000 / 30 + 1)


func test_a_stage_s_benefit_opens_only_the_segments_to_it() -> void:
	"""A wall along z = 3 m parts the south from the north; the main tunnel lies south of it. From the crossing piece's
	south mouth to the north side, the junction stage alone helps nothing (both of the main tunnel's mouths are south
	too) -- the estimate of that stage is no quicker -- while the whole piece, breaking out north of the wall, is far
	quicker."""
	var space := CastSpaceScript.new()
	var wall: Array[Vector3] = []
	for k: int in 55:
		wall.append(Vector3(-40.5 + 1.5 * float(k), 0.9, 3.0))
	space.setup([], wall)
	space.tunnels = _crossing_dig()
	var brain := _walker(space, Vector2(6.5, -9.5))
	var stages := StagesScript.new()
	stages.read(space.tunnels, 1)
	var costs := PackedFloat32Array()
	for upto: int in [stages.upto[0], -1]:
		var estimate := _estimator(space)
		estimate.set_walker(brain.index, BODY_M, false)
		estimate.add_trip(Vector2(6.5, -9.5), Vector2(6.5, 9.5), "south to north")
		estimate.propose_open(1, upto)
		estimate.start(21)
		estimate.run_all()
		costs.append_array([estimate.before_m[0], estimate.after_m[0]])
	assert_almost_equal(costs[1], costs[0], "to the junction: no quicker (%.1f m)" % costs[1])
	var short := _estimator(space)
	short.set_walker(brain.index, BODY_M, false)
	short.add_trip(Vector2(6.5, -9.5), Vector2(6.5, 9.5), "south to north")
	short.propose_open(1, stages.chain.size() - 1)
	short.start(22)
	short.run_all()
	assert_almost_equal(short.after_m[0], short.before_m[0], "all but the last ramp open: still no way out north")
	assert_true(costs[3] < costs[2] * 0.5, "the whole piece: %.1f m against %.1f m round the wall" % [costs[3], costs[2]])


# --- a dig laid in the Dig tool -----------------------------------------------------------------------------

func test_a_piece_laid_but_not_dug_is_estimated_as_the_router_will_cost_it_once_dug() -> void:
	"""The Dig tool's plan (a spec, never stored live): its after estimate, on a copy with the piece laid and open, is
	exactly the live router's cost once that very piece is laid and dug -- and the live network is untouched by the
	estimate."""
	var space := CastSpaceScript.new()
	var wall: Array[Vector3] = []
	for k: int in 55:
		wall.append(Vector3(-40.5 + 1.5 * float(k), 0.9, 3.0))
	space.setup([], wall)
	var graph := space.tunnels
	var ref := PackedInt32Array([-1, 0, -1])
	graph.add_into(_route([Vector2i(0, 0), Vector2i(12288, 0)]), 2, 0, ref)
	_dig(graph, ref[2])
	var plan := PlanScript.new()
	var snap := PackedInt32Array([0, -1, 0, 0])
	for p: Vector2i in [Vector2i(6144, -8192), Vector2i(6144, 8192)]:
		var kind := PlanScript.snap_into(graph, p, snap)
		plan.try_add_snapped(snap[2], snap[3], kind, snap[1], BOUNDS_U, PackedInt32Array())
	assert_equal(plan.piece_reason(graph, BOUNDS_U, PackedInt32Array()), Rules.REFUSE_NONE, "may be dug")
	var brain := _walker(space, Vector2(6.5, -9.5))
	var estimate := _estimator(space)
	estimate.set_walker(brain.index, BODY_M, false)
	estimate.add_trip(Vector2(6.5, -9.5), Vector2(6.5, 9.5), "south to north")
	estimate.propose_piece(plan.spec_of(0))
	var revision := graph.revision
	var phases := graph.phase.duplicate()
	var opened := graph.open_count()
	estimate.start(5)
	estimate.run_all()
	assert_true(estimate.proposal_ok, "the copy took the piece")
	assert_equal([graph.revision, graph.phase, graph.open_count()], [revision, phases, opened], "the live network untouched")
	assert_true(graph.add_piece(plan.spec_of(0), ref), "laid for real")
	_dig(graph, ref[2])
	var live := PackedVector2Array()
	var legs := PackedInt32Array()
	var cost := _live_cost(space, brain.index, Vector2(6.5, -9.5), Vector2(6.5, 9.5), false, live, legs)
	assert_almost_equal(estimate.after_m[0], cost, "the router's cost once dug: %.2f" % cost)
	assert_true(estimate.after_m[0] < estimate.before_m[0] * 0.5, "far quicker than round the wall")


# --- the words ------------------------------------------------------------------------------------------------

func test_a_trip_reads_calculating_then_now_and_after_honestly() -> void:
	"""Unknown: calculating. No way before: a way where there was none. No shorter: no quicker. Shorter: the per cent,
	floored. Times on the calendar at the pace given (25 s a game hour)."""
	var estimate := EstimatorScript.new(1)
	estimate.add_trip(Vector2.ZERO, Vector2.ONE, "the store to the farm")
	estimate.propose_bridge(Vector2.ZERO, Vector2.ONE, 1.0)
	assert_equal(TextScript.trip_line(estimate, 0, 1.0), "the store to the farm: " + TextScript.CALCULATING, "calculating")
	estimate.before_known[0] = 1
	estimate.after_known[0] = 1
	estimate.before_m[0] = INF
	estimate.after_m[0] = 25.0
	assert_equal(TextScript.trip_line(estimate, 0, 1.0),
		"the store to the farm: now no way, after about 1 game hour (a way where there was none)", "a new way")
	estimate.before_m[0] = 50.0
	estimate.after_m[0] = 50.0
	assert_equal(TextScript.trip_line(estimate, 0, 1.0), "the store to the farm: about 2.0 game hours — no quicker this way", "none")
	estimate.after_m[0] = 30.0
	assert_equal(TextScript.trip_line(estimate, 0, 1.0),
		"the store to the farm: now about 2.0 game hours, after about 1.2 game hours (40% quicker)", "quicker")
	assert_equal(TextScript.short_time_text(30.0, 1.0), "1.2 game h", "short, for a label")
	assert_equal(TextScript.short_time_text(10.0, 1.0), "24 game min", "minutes")


func test_the_village_s_work_places_stand_on_land_and_the_far_banks_lie_across_the_water() -> void:
	"""Each place resolves to the village's own point (a point of interest's slot or a landing), clear of the water;
	the far banks are across it from the square; a bridge's relevant trips all cross the water, nearest first."""
	var rig: Fixture.Rig = _water._rig()
	var space: CastSpaceScript = rig.cast.space()
	var trips := TripsScript.new()
	trips.resolve(space, rig.play.map())
	for k: int in TripsScript.PLACE_COUNT:
		assert_true(space.crossings.water_clearance_m(trips.points[k]) > 0.3, "%s on land" % TripsScript.NAMES[k])
	var crosses := _crosses(rig)
	for far: int in [TripsScript.FAR_FORD, TripsScript.FAR_MILL]:
		assert_true(bool(crosses.call(trips.points[TripsScript.SQUARE], trips.points[far])), "%s across the water" % TripsScript.NAMES[far])
	var poi: int = space.poi_names.find(&"store_front")
	assert_equal(trips.points[TripsScript.STORE], space.slot_position(poi, 0), "the store is the store front's own slot")
	var out := PackedInt32Array()
	var crossing := 0
	for t: int in TripsScript.TRIPS.size():
		crossing += 1 if bool(crosses.call(trips.trip_from(t), trips.trip_to(t))) else 0
	assert_equal(trips.water_trips_into(Vector2(23.3, -25.0), crosses, 99, out), crossing, "every trip over the water, no other")
	assert_equal(trips.water_trips_into(Vector2(23.3, -25.0), crosses, 2, out), 2, "two")
	for t: int in out:
		assert_true(bool(crosses.call(trips.trip_from(t), trips.trip_to(t))), "%s crosses" % trips.trip_name(t))
	assert_equal(trips.trip_to(out[0]), trips.points[TripsScript.FAR_MILL], "the mill's bank nearest the neck")
	trips.near_trips_into(trips.points[TripsScript.STORE], trips.points[TripsScript.FARM], 3, out)
	assert_equal(trips.trip_name(out[0]), "the store to the farm", "the trip between the tunnel's two ends first")


func test_a_planned_bridge_s_materials_are_reserved_then_delivered_and_nothing_is_missing() -> void:
	"""Before: the shortage from the Build card's own have / need. Planned (paid): reserved at the plank stack, nothing
	missing; once at the site, delivered."""
	var rig: Fixture.Rig = _water._rig()
	var card: CardScript = rig.play.build_card(SwimRules.KIND_PLANK, PackedInt32Array([1]))
	assert_equal(ProjectScript.shortage_line(SwimRules.KIND_PLANK, card), "Plank footbridge: missing 5 planks", "short: 4.7 planks, never understated")
	rig.play.services.stores.add_planks(5000)
	assert_equal(ProjectScript.shortage_line(SwimRules.KIND_PLANK, rig.play.build_card(SwimRules.KIND_PLANK,
		PackedInt32Array([1]))), "", "paid for: nothing short")
	rig.play.build(SwimRules.KIND_PLANK, PackedInt32Array([1]))
	assert_true(rig.play.bridge_on_site_into(_read), "planned at the site")
	var row: int = _read.value
	var lines: String = ProjectScript.planned_lines(rig.play.bridges, rig.play.crew, row)
	assert_true(lines.begins_with("Materials: 5 planks — paid when it was planned, nothing missing; reserved at the plank stack"),
		"4.7 U of planks, stated as its cost was (rounded up): " + lines)
	assert_true(lines.contains("Work: piers 100% · beams 0% · deck 0%"), "its stages (no piers to build)")
	rig.play.crew.at_site[row] = 1
	assert_true(ProjectScript.planned_lines(rig.play.bridges, rig.play.crew, row).contains("delivered at the site"), "delivered")


# --- boat legs (water part B) -------------------------------------------------------------------------------------

func test_a_crew_member_aboard_reads_by_boat_out_and_back() -> void:
	"""A boat's legs are task-driven, not router pairs (decision 0432): a crew member aboard a boat under way has a BOAT
	leg -- from where the boat is, on to its station, or back to its berth -- said "by boat"; moored, or aboard
	nothing, there is none (the walk to the jetty is the route)."""
	var fleet := FleetScript.new()
	var kinds := KindsScript.new()
	var leg := PackedVector2Array()
	assert_false(kinds.boat_leg_into(3, leg), "no fleet: no boat leg")
	kinds.fleet = fleet
	assert_false(kinds.boat_leg_into(3, leg), "aboard nothing")
	fleet.seat(0, FleetScript.HELM, 3)
	var course := PackedInt32Array(BoatRoutes.ROUTES[0])
	assert_true(fleet.set_course(0, course, null), "a course from the berth")
	assert_false(kinds.boat_leg_into(3, leg), "moored: none")
	assert_true(fleet.set_off(0), "rowing out")
	fleet.step(1000000)
	assert_true(kinds.boat_leg_into(3, leg), "aboard and under way")
	assert_true(leg[0].distance_to(fleet.position_m(0)) < 0.001, "from where the boat is")
	var station := BoatRoutes.m_of(Vector2i(course[course.size() - 2], course[course.size() - 1]))
	assert_true(leg[leg.size() - 1].distance_to(station) < 0.001, "out to its station")
	fleet.row_back(0)
	assert_true(kinds.boat_leg_into(3, leg), "rowing back")
	assert_true(leg[leg.size() - 1].distance_to(BoatRoutes.m_of(BoatRoutes.BERTH_U[0])) < 0.001, "back to its berth")
	assert_false(kinds.boat_leg_into(2, leg), "the one ashore has none")
	assert_equal(KindsScript.KIND_WORDS[KindsScript.KIND_BOAT], "by boat", "said by boat, not an unknown crossing")


# --- the rescue card ---------------------------------------------------------------------------------------------

func test_the_rescue_card_names_victim_responder_landing_and_a_time_the_same_while_paused() -> void:
	"""A swimmer in difficulty in the run, a stronger swimmer sent: the card's phase names the responder, a time to
	safety (approximate), the landing it will be towed to, and Victim / Responder / Landing; nothing stepped (paused),
	the same words."""
	var rig: Fixture.Rig = _water._rig()
	_water._swimmer(rig, 0, 600)
	_water._swimmer(rig, 2, 1100)
	var victim: BrainScript = _water._brain(rig, 0)
	victim.water_place(Fixture.RUN_MID, -0.18, 0.0)
	victim.water_in()
	rig.play.rescue.start_difficulty(0)
	var card := RescueCardScript.new()
	card.configure(rig.play.rescue, rig.play.state, rig.cast)
	var details := RescueCardScript.Details.new()
	assert_true(card.details_into("water:rescue:0", details), "a rescue under way")
	assert_equal([details.victim, details.responder], [0, 2], "victim and responder")
	assert_true(details.phase.begins_with("Placeholder 2: "), "its phase: %s" % details.phase)
	assert_true(details.time.begins_with("safe ashore in about "), "a time: %s" % details.time)
	assert_true(details.landing.is_finite(), "the landing it will be towed to")
	var extra := CardsScript.Extra.new()
	assert_true(card.card_into("water:rescue:0", extra), "the card's details")
	assert_equal(extra.labels, PackedStringArray([RescueCardScript.VICTIM % card.name_of(0),
		RescueCardScript.RESPONDER % card.name_of(2), RescueCardScript.LANDING]), "three targets, the residents by name")
	assert_true(extra.labels[0].contains(card.name_of(0)) and not card.name_of(0).is_empty(), "the victim's name")
	assert_equal([extra.kinds[0], extra.ids[0], extra.ids[1]], [NoticesScript.TARGET_RESIDENT, 0, 2], "the residents")
	var again := RescueCardScript.Details.new()
	card.details_into("water:rescue:0", again)
	assert_equal([again.phase, again.time], [details.phase, details.time], "paused: the same")
	assert_false(card.details_into("threat", details), "not a rescue's key")
	assert_false(card.details_into("water:rescue:x", details), "nor one naming nobody")


func test_with_its_rescuer_called_away_the_card_says_the_blockage_and_the_safety_net() -> void:
	"""The responder lets go: no one answering -- "Needs a rescuer" and the blockage with when the water brings it
	ashore; the landing still offered."""
	var rig: Fixture.Rig = _water._rig()
	_water._swimmer(rig, 0, 600)
	_water._swimmer(rig, 2, 1100)
	var victim: BrainScript = _water._brain(rig, 0)
	victim.water_place(Fixture.RUN_MID, -0.18, 0.0)
	victim.water_in()
	rig.play.rescue.start_difficulty(0)
	var held: TasksScript.VictimTask = rig.play.rescue.victim_task(0)
	held.release(held.responder)
	var card := RescueCardScript.new()
	card.configure(rig.play.rescue, rig.play.state, rig.cast)
	var details := RescueCardScript.Details.new()
	assert_true(card.details_into("water:rescue:0", details), "still a rescue")
	assert_equal(details.phase, RescueCardScript.NOBODY_PHASE, "needs a rescuer")
	assert_equal(details.time, RescueCardScript.NOBODY_BLOCK % 90, "blocked, with the safety net's 90 s")
	assert_true(details.landing.is_finite(), "the nearest landing")


# --- the overlay ---------------------------------------------------------------------------------------------------

func test_the_overlay_draws_each_member_and_redraws_only_on_change() -> void:
	"""Two selected: one waiting at the desk (its words at its post), one walking; the ribbons rebuilt once, not again
	while nothing changes; a change of state redraws."""
	var rig: Fixture.Rig = _water._rig()
	var space: CastSpaceScript = rig.cast.space()
	var kinds := KindsScript.new()
	kinds.configure(space.crossings, CrossingsScript.LINK_ROW0, rig.play.links.link_count)
	var overlay := OverlayScript.new()
	_water._keep(overlay)
	overlay.configure(rig.cast, space.tunnels, kinds)
	_water._place(rig, 0, Vector2(0.0, 2.0))
	_water._place(rig, 1, Vector2(2.0, 2.0))
	_water._brain(rig, 1).order_move(Vector2(8.0, 6.0))
	space.routes.budget_usec = 1000
	space.routes.charge(-1, 1000000)
	_water._brain(rig, 0).order_move(Vector2(-6.0, 6.0))
	overlay.follow(PackedInt32Array([0, 1]))
	overlay.set_shown(true)
	overlay._process(0.0)
	overlay._process(OverlayScript.REDRAW_S)
	assert_equal(overlay.rebuilds, 1, "drawn once: nothing changed")
	assert_equal(overlay.label_texts(), PackedStringArray(["Placeholder 0: finding a route"]), "the waiting one's words")
	space.routes.end_window()
	space.routes.serve()
	overlay._process(0.0)
	assert_equal(overlay.rebuilds, 1, "not looked at again within a refresh")
	overlay._process(OverlayScript.REDRAW_S)
	assert_equal(overlay.rebuilds, 2, "redrawn on the change")
	assert_true(overlay.label_texts().is_empty(), "both under way now")


func test_a_dig_ending_blind_below_is_a_spur_and_levels_are_named() -> void:
	"""Two levels (the levels suite's fixture): a level-2 piece run out east from the ramp's foot to a blind end is one
	SPUR (a place to go, not a way through); the stairs' segment is between the levels, the lower bore on level 2."""
	var graph: GraphScript = LevelsTest.two_levels(self)
	var out := LevelsTest.plan_of(Rules.LEVEL_2, Rules.LINK_NONE)
	assert_equal(LevelsTest.lay(graph, out, [LevelsTest.RAMP_FOOT, LevelsTest.RAMP_FOOT + Vector2i(4096, 0)]), Rules.REFUSE_NONE, "laid")
	var ref := PackedInt32Array([-1, 0, -1])
	assert_true(graph.add_piece(out.spec_of(0), ref), "stored, not dug")
	var stages := StagesScript.new()
	stages.read(graph, ref[2])
	assert_equal(stages.kinds, PackedInt32Array([StagesScript.SPUR]), "a spur")
	assert_equal(stages.stage_line(0), "Stage 1 of 1: spur — next", "in words")
	var stairs: int = LevelsTest.first_link(graph, Rules.LINK_STAIRS)
	assert_equal(KindsScript.level_of(graph, RouterScript.leg_code(stairs, false)), KindsScript.BETWEEN_LEVELS, "the stairs")
	assert_equal(KindsScript.run_word(KindsScript.KIND_UNDERGROUND, KindsScript.BETWEEN_LEVELS), "underground, between levels", "named")
	var lower: int = graph.next_in_piece(stairs) if graph.next_in_piece(stairs) >= 0 else -1
	for slot: int in Rules.MAX_SEGMENTS:
		if graph.is_open(slot) and graph.seg_level[slot] == Rules.LEVEL_2 and graph.seg_link[slot] == Rules.LINK_NONE:
			lower = slot
	assert_equal(KindsScript.level_of(graph, RouterScript.leg_code(lower, true)), Rules.LEVEL_2, "the lower bore")
	assert_equal(KindsScript.level_of(graph, RouterScript.SURFACE_LEG), -1, "the surface has none")


func test_past_a_reached_stage_the_next_payoff_counts_from_it() -> void:
	"""The junction reached and half the bore past it dug: the way to the connection is counted from the junction --
	the bore's dug half of that bore and the last ramp."""
	var graph := _crossing_dig()
	var stages := StagesScript.new()
	stages.read(graph, 1)
	for k: int in 2:
		graph.start_dig(stages.chain[k], graph.generation[stages.chain[k]], 0)
		graph.advance(stages.chain[k], graph.generation[stages.chain[k]], 1000000000)
	var past: int = stages.chain[2]
	graph.start_dig(past, graph.generation[past], 0)
	@warning_ignore("integer_division") _dig_ticks(graph, past, graph.total_ticks(past) / 2)
	stages.read(graph, 1)
	assert_equal(stages.reached, 1, "the junction reached")
	var left := graph.total_ticks(stages.chain[2]) + graph.total_ticks(stages.chain[3])
	@warning_ignore("integer_division") assert_equal(stages.percent_to_next(graph), graph.done(past) * 100 / left, "counted from the junction")


func test_after_a_step_longer_than_the_budget_the_estimate_rests_as_many_windows() -> void:
	"""A plan is never cut in two, so one longer than the desk's whole budget is paid back: the estimate rests the
	windows it overran by, and takes its next step only after them -- its average stays within the budget."""
	var space := _penned_tee(true)
	var brain := _walker(space, Vector2(-9.5, 4.5))
	var desk := DeskScript.new()
	desk.budget_usec = 1
	var estimate := _estimator(space)
	estimate.set_walker(brain.index, BODY_M, false)
	estimate.add_trip(Vector2(-9.5, 4.5), Vector2(0.6, 12.4), "a")
	estimate.add_trip(Vector2(9.0, 3.0), Vector2(-9.0, 5.0), "b")
	estimate.start(13)
	var windows := 0
	var steps := 0
	while estimate.is_calculating() and windows < 1000000:
		if estimate.step(desk):
			steps += 1
		desk.end_window()
		windows += 1
	assert_equal(steps, estimate.steps_total(), "every step taken")
	assert_true(windows > 2 * steps, "with rests between: %d windows for %d steps" % [windows, steps])
	assert_true(estimate.steps_refused >= windows - steps, "each rest a refused window")


func test_a_discarded_copy_of_the_network_is_freed() -> void:
	"""A copy's router keeps the graph it planned through (`use_paths`): the estimate lets go of it after each plan and
	before making the next copy, so a copy no estimate holds is freed -- never two RefCounted holding each other."""
	var space := _penned_tee(false)
	var brain := _walker(space, Vector2(-9.5, 4.5))
	var estimate := _estimator(space)
	estimate.set_walker(brain.index, BODY_M, false)
	estimate.add_trip(Vector2(-9.5, 4.5), Vector2(0.6, 12.4), "into the pen")
	estimate.propose_open(1)
	estimate.start(1)
	estimate.run_all()
	var first: WeakRef = weakref(estimate._after)
	assert_not_null(first.get_ref(), "a copy made")
	estimate.propose_open(1, 2)
	estimate.start(2)
	estimate.run_all()
	assert_null(first.get_ref(), "the old copy freed")
	var second: WeakRef = weakref(estimate._after)
	estimate.stop()
	assert_null(second.get_ref(), "stopped: the copy freed")
	var dropped := _estimator(space)
	dropped.set_walker(brain.index, BODY_M, false)
	dropped.add_trip(Vector2(-9.5, 4.5), Vector2(0.6, 12.4), "into the pen")
	dropped.propose_open(1)
	dropped.start(3)
	dropped.run_all()
	var third: WeakRef = weakref(dropped._after)
	dropped = null
	assert_null(third.get_ref(), "an estimate dropped whole: its copy freed with it")


func test_a_route_read_from_a_waypoint_on_is_that_stretch_of_it() -> void:
	"""The overlay and the notes read a resident's route from the waypoint it is heading to, without slicing it: the
	same runs as the slice."""
	var space := _penned_tee(true)
	var brain := _walker(space, Vector2(-9.5, 4.5))
	var path := PackedVector2Array()
	var legs := PackedInt32Array()
	space.plan_path(brain.index, Vector2(-9.5, 4.5), Vector2(0.6, 12.4), BODY_M, path, legs)
	var kinds := KindsScript.new()
	for first: int in [1, 2, path.size() - 1]:
		assert_equal(kinds.runs_text(space.tunnels, path[first - 1], path, legs, first),
			kinds.runs_text(space.tunnels, path[first - 1], path.slice(first), legs.slice(first)), "from waypoint %d" % first)
	var rig: Fixture.Rig = _water._rig()
	var wet: CastSpaceScript = rig.cast.space()
	var water := KindsScript.new()
	water.configure(wet.crossings, CrossingsScript.LINK_ROW0, rig.play.links.link_count)
	wet.plan_path(1, NECK_WEST, NECK_EAST, 0.22, path, legs, true, true)
	var wading := 0
	for first: int in range(1, path.size()):
		var whole: String = water.runs_text(wet.tunnels, path[first - 1], path, legs, first)
		assert_equal(whole, water.runs_text(wet.tunnels, path[first - 1], path.slice(first), legs.slice(first)),
			"round by the ford, from waypoint %d" % first)
		wading += 1 if whole.contains("wading") else 0
	assert_true(wading > 0, "some of them wade")


func test_a_swimmer_treading_above_one_it_cannot_fetch_is_a_blockage_on_the_card() -> void:
	"""No diver at all: the mouse is sent to tread above the otter held below; out there, the card says the blockage --
	no diver with the air free -- and when it will float up, not a time to safety."""
	var safety: SafetyTest = SafetyTest.new()
	safety.before_each()
	var fx: Fixture = safety._fx
	var rig: Fixture.Rig = fx._rig()
	fx._swimmer(rig, 1, 840)
	fx._place(rig, 1, SafetyTest.MOUSE_BY_POND)
	var task: DiveTaskScript = safety._diver_at_the_pond(rig, 0, SafetyTest.POND_WEST)
	assert_true(fx._run(rig, func() -> bool: return task.phase == DiveTaskScript.PHASE_SEARCH), "on the bed")
	rig.play.cramp(PackedInt32Array([0]))
	var held: TasksScript.VictimTask = rig.play.rescue.victim_task(0)
	assert_equal([held.responder, held.response], [1, TasksScript.RESPONSE_WATCH], "the mouse, to watch")
	var mouse: BrainScript = fx._brain(rig, 1)
	var above := func() -> bool: return mouse.state == BrainScript.State.TASK and (mouse.task as TasksScript.SwimRescue).is_above()
	assert_true(fx._run(rig, above, 600), "treading above")
	var card := RescueCardScript.new()
	card.configure(rig.play.rescue, rig.play.state, rig.cast)
	var details := RescueCardScript.Details.new()
	assert_true(card.details_into("water:rescue:0", details), "a rescue")
	assert_true(details.time.begins_with("Blocked: no diver with the air free"), details.time)
	safety.after_each()
