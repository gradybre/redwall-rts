extends "res://test/framework/test_case.gd"
## The live demo's player-dug tunnels (decision 0196): the integer rules (units, digging time,
## spoil, bore fit, route validation), the tunnel network's life, the planner's tunnel shortcut, the
## brain walking and digging tunnels, the tunnel tool's planning, and the panel's words.
##
## No scene tree and no staged assets: brains are stepped at a fixed 60 Hz on hand-built circles,
## the tool runs on the placeholder cast with one placeholder made a mole, and every expected value
## is a literal worked out by hand from the cited constants (113 ticks and 2000 milli-U a quantum).

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const NetworkScript := preload("res://demo/tunnel/tunnel_network.gd")
const RouterScript := preload("res://demo/tunnel/tunnel_router.gd")
const PlanScript := preload("res://demo/tunnel/tunnel_plan.gd")
const OverlayScript := preload("res://demo/tunnel/tunnel_overlay.gd")
const ControlScript := preload("res://demo/tunnel/tunnel_control.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const CommandScript := preload("res://demo/control/demo_command.gd")
const PanelScript := preload("res://demo/control/demo_party_panel.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const Contrast := preload("res://demo/ui/woodland_contrast.gd")
const HeapsScript := preload("res://demo/tunnel/tunnel_heaps.gd")
const DemoWorldScript := preload("res://demo/world/demo_world.gd")
const DemoClockScript := preload("res://demo/demo_clock.gd")
const MarksScript := preload("res://demo/control/demo_marks.gd")
const CastOrdersScript := preload("res://demo/cast/cast_orders.gd")
const Layers := preload("res://demo/demo_layers.gd")

const DT: float = 1.0 / 60.0
const SEED: int = 9091
const BODY_M: float = 0.25
const WALK_M_S: float = 1.0
## The demo's bounds, +-20 m, in u.
const BOUNDS_U := Rect2i(-20480, -20480, 40960, 40960)

var _nodes: Array[Node] = []


func after_each() -> void:
	"""Free every node a test built."""
	for node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()


# --- fixtures -------------------------------------------------------------------------------

func _route(points: Array[Vector2i]) -> PackedInt32Array:
	"""(x, z) points in u as a flat route."""
	var out := PackedInt32Array()
	for p in points:
		out.append(p.x)
		out.append(p.y)
	return out


func _wall() -> Array[Vector3]:
	"""Five overlapping 0.9 m circles across x = -6..6 at z = 0: the straight line is blocked."""
	var wall: Array[Vector3] = []
	for x in [-6.0, -3.0, 0.0, 3.0, 6.0]:
		wall.append(Vector3(x, 0.9, 0.0))
	for x in [-4.5, -1.5, 1.5, 4.5]:
		wall.append(Vector3(x, 0.9, 0.0))
	return wall


func _ring(centre: Vector2) -> Array[Vector3]:
	"""Twelve overlapping 0.9 m circles on a 3 m ring round `centre`: a closed pen."""
	var ring: Array[Vector3] = []
	for k in 12:
		var at := centre + Vector2(cos(TAU * k / 12.0), sin(TAU * k / 12.0)) * 3.0
		ring.append(Vector3(at.x, 0.9, at.y))
	return ring


func _space(obstacles: Array[Vector3]) -> CastSpaceScript:
	"""A CastSpace over these circles, with no POIs."""
	var space := CastSpaceScript.new()
	space.setup([], obstacles)
	return space


func _open_tunnel(space: CastSpaceScript, points: Array[Vector2i]) -> int:
	"""Add a tunnel along these points and dig it to the end; returns its slot."""
	var ref := PackedInt32Array([-1, 0])
	assert_true(space.tunnels.add_into(_route(points), points.size(), 0, ref), "fixture tunnel stored")
	space.tunnels.advance(ref[0], ref[1], 1000000000)
	return ref[0]


func _lengths() -> Dictionary:
	"""Every clip the actor stages, 2 s long."""
	var lengths := {}
	for clip in DemoActorScript.CLIPS:
		lengths[clip] = 2.0
	return lengths


func _brain(space: CastSpaceScript, at: Vector2, fits: bool) -> BrainScript:
	"""A resident standing at `at`, holding no slot, fitting the bore or not."""
	var brain := BrainScript.new()
	brain.configure(space, WALK_M_S, BODY_M, SEED, _lengths())
	brain.start_at(at, 0.0, -1, -1)
	space.tunnels.set_fit(brain.index, fits)
	return brain


func _surfacing(brain: BrainScript, frames: int) -> Vector2:
	"""Step until `brain` comes up out of the ground (at most `frames`); where it came up."""
	var was_below := brain.underground
	for f in frames:
		brain.step(DT)
		if was_below and not brain.underground:
			return brain.position
		was_below = brain.underground
	return Vector2.INF


func _dig_to(space: CastSpaceScript, mole: BrainScript, slot: int, ticks: int) -> void:
	"""Step the mole until tunnel `slot` has `ticks` dug (at most 30 s)."""
	var guard := 0
	while space.tunnels.done(slot) < ticks and guard < 60 * 30:
		mole.step(DT)
		guard += 1


func _step(brain: BrainScript, seconds: float) -> void:
	"""Step one brain for `seconds`."""
	for f in roundi(seconds / DT):
		brain.step(DT)


# --- rules: units and integer maths ---------------------------------------------------------

func test_cited_constants_are_the_amendment_s() -> void:
	"""113 ticks a quantum (25 + 50 + 38), 2000 milli-U of spoil, a 1024u quantum, 30 ticks/s."""
	assert_equal(Rules.TICKS_PER_QUANTUM, 113, "brace 25 + cut 50 + finish 38")
	assert_equal(Rules.SPOIL_PER_QUANTUM_MILLI_U, 2000, "one cut posts 2000 milli-U")
	assert_equal(Rules.QUANTUM_U, 1024, "a 1 m cube")
	assert_equal(Rules.TICKS_PER_SECOND, 30, "30 fixed ticks a second")
	assert_equal(Rules.CROSS_SECTION_QUANTA, 1, "a one-quantum bore")


func test_integer_square_root_is_exact() -> void:
	"""Floor square roots, exact at and either side of perfect squares."""
	var cases := {0: 0, 1: 1, 2: 1, 3: 1, 4: 2, 15: 3, 16: 4, 1048575: 1023, 1048576: 1024,
		999999999999: 999999, 1000000000000: 1000000,
		## 67108865^2 - 1: the float seed rounds up to 67108865 here, and must be corrected down.
		4503599761588224: 67108864}
	for n: int in cases:
		assert_equal(Rules.isqrt(n), cases[n], "isqrt(%d)" % n)


func test_route_length_and_bore_quanta() -> void:
	"""A 3-4-5 leg is 5120u; legs add; every started metre is a whole quantum."""
	assert_equal(Rules.route_length_u(_route([Vector2i(0, 0), Vector2i(3072, 4096)]), 2), 5120, "one leg")
	var bent := _route([Vector2i(0, 0), Vector2i(3072, 4096), Vector2i(3072, 6144)])
	assert_equal(Rules.route_length_u(bent, 3), 7168, "two legs")
	assert_equal(Rules.route_length_u(bent, 2), 5120, "only `count` points count")
	assert_equal(Rules.bore_quanta(1), 1, "a sliver is a quantum")
	assert_equal(Rules.bore_quanta(1024), 1, "one metre")
	assert_equal(Rules.bore_quanta(2048), 2, "two metres")
	assert_equal(Rules.bore_quanta(2049), 3, "just over two")


func test_digging_time_counts_whole_ticks_from_microseconds() -> void:
	"""30 ticks a second, floored; capped at the total of (bore + 2 shafts) x 113."""
	assert_equal(Rules.total_ticks(12), 1582, "(12 + 2) x 113")
	assert_equal(Rules.done_ticks(1000000, 12), 30, "one second")
	assert_equal(Rules.done_ticks(33333, 12), 0, "just short of a tick")
	assert_equal(Rules.done_ticks(33334, 12), 1, "just a tick")
	assert_equal(Rules.done_ticks(1000000000, 2), 452, "capped at (2 + 2) x 113")


func test_stages_turn_over_at_exact_ticks() -> void:
	"""Three bore quanta: entrance 0..112, bore 113..451, exit 452..564, open at 565."""
	var expected := {0: Rules.STAGE_ENTRANCE, 112: Rules.STAGE_ENTRANCE, 113: Rules.STAGE_BORE,
		451: Rules.STAGE_BORE, 452: Rules.STAGE_EXIT, 564: Rules.STAGE_EXIT, 565: Rules.STAGE_OPEN}
	for done: int in expected:
		assert_equal(Rules.stage_of(done, 3), expected[done], "stage at %d" % done)


func test_percent_is_floored_and_reaches_100_only_when_open() -> void:
	"""0 at the start, 99 one tick short, 100 at the total."""
	assert_equal(Rules.percent(0, 3), 0, "nothing dug")
	assert_equal(Rules.percent(282, 3), 49, "282 of 565")
	assert_equal(Rules.percent(564, 3), 99, "one tick short")
	assert_equal(Rules.percent(565, 3), 100, "open")


func test_spoil_posts_when_each_cut_completes() -> void:
	"""A quantum's 2000 milli-U post 75 ticks in (brace + cut); entrance and bore spoil out of the
	entrance, the exit shaft out of the exit."""
	var cuts := {0: 0, 74: 0, 75: 1, 112: 1, 113: 1, 187: 1, 188: 2}
	for done: int in cuts:
		assert_equal(Rules.cut_quanta(done), cuts[done], "cuts after %d ticks" % done)
	var out := PackedInt64Array([0, 0])
	Rules.spoil_into(75, 3, out)
	assert_equal(out, PackedInt64Array([2000, 0]), "the entrance's own cut")
	Rules.spoil_into(526, 3, out)
	assert_equal(out, PackedInt64Array([8000, 0]), "entrance + 3 bore quanta, the exit not yet cut")
	Rules.spoil_into(527, 3, out)
	assert_equal(out, PackedInt64Array([8000, 2000]), "the exit's cut heaps at the exit")
	Rules.spoil_into(565, 3, out)
	assert_equal(out, PackedInt64Array([8000, 2000]), "done: 10 kg in all")


func test_the_dig_face_advances_through_the_bore_only() -> void:
	"""Face at 0 through the entrance shaft, proportional through the bore, the whole length after."""
	assert_equal(Rules.face_u(50, 2, 2048), 0, "in the entrance shaft")
	assert_equal(Rules.face_u(113, 2, 2048), 0, "the bore begins")
	assert_equal(Rules.face_u(226, 2, 2048), 1024, "half the bore")
	assert_equal(Rules.face_u(339, 2, 2048), 2048, "the bore is through")
	assert_equal(Rules.face_u(400, 2, 2048), 2048, "in the exit shaft")
	assert_equal(Rules.face_u(226, 3, 2500), 833, "floored, on a part-metre route")


# --- rules: who fits and who digs -----------------------------------------------------------

func test_bore_fit_admits_mice_moles_and_squirrels_only() -> void:
	"""From each cast body (drawn height, DemoActor.body_radius): mice, moles, squirrels fit;
	otters are too tall even stooped; the badger is too wide."""
	var expected := {1.0: Rules.FIT_OK, 0.9: Rules.FIT_OK, 1.15: Rules.FIT_OK, 1.49: Rules.FIT_TOO_TALL,
		2.55: Rules.FIT_TOO_WIDE}
	for height: float in expected:
		var radius_u := Rules.to_u(DemoActorScript.body_radius(height))
		assert_equal(Rules.fit_refusal(Rules.to_u(height), radius_u), expected[height], "height %.2f m" % height)
	assert_true(Rules.fits_bore(1178, 259), "squirrel: stooped 1002u under a 1024u bore")
	assert_false(Rules.fits_bore(1526, 336), "otter: stooped 1298u")


func test_bore_fit_boundaries_are_exact() -> void:
	"""ceil(h x 850 / 1000) <= 1024 admits h = 1204 and refuses 1205; 2r <= 1024 admits r = 512."""
	assert_equal(Rules.fit_refusal(1204, 100), Rules.FIT_OK, "stoops to exactly 1024u")
	assert_equal(Rules.fit_refusal(1205, 100), Rules.FIT_TOO_TALL, "stoops to 1025u")
	assert_equal(Rules.fit_refusal(900, 512), Rules.FIT_OK, "exactly the bore's width")
	assert_equal(Rules.fit_refusal(900, 513), Rules.FIT_TOO_WIDE, "one u too wide")


func test_only_moles_dig() -> void:
	"""Species names are matched without case."""
	assert_true(Rules.is_digger("Mole"), "a mole")
	assert_true(Rules.is_digger("mole"), "lower case")
	assert_false(Rules.is_digger("Mouse"), "a mouse")
	assert_false(Rules.is_digger("Placeholder"), "a placeholder")


# --- rules: route validation ----------------------------------------------------------------

func test_a_mouth_must_clear_every_obstacle_by_half_a_bore() -> void:
	"""A 1024u circle at the origin: a mouth 1536u away (1024 + 512) is clear, 1535u is not."""
	var circles := PackedInt32Array([0, 1024, 0])
	assert_false(Rules.mouth_blocked(1536, 0, circles), "exactly clear")
	assert_true(Rules.mouth_blocked(1535, 0, circles), "cutting into it")
	assert_true(Rules.mouth_blocked(0, 0, circles), "inside it")


func test_route_refusals() -> void:
	"""Each refusal in order: too few, too many, out of bounds, entrance, exit, too short, too long."""
	var circles := PackedInt32Array([0, 1024, 0])
	var one := _route([Vector2i(-5000, 0)])
	assert_equal(Rules.validate_route(one, 1, BOUNDS_U, circles), Rules.REFUSE_TOO_FEW_POINTS, "one point")
	var nine: Array[Vector2i] = []
	for k in 9:
		nine.append(Vector2i(-8000 + 2000 * k, 5000))
	assert_equal(Rules.validate_route(_route(nine), 9, BOUNDS_U, circles), Rules.REFUSE_TOO_MANY_POINTS, "nine points")
	var outside := _route([Vector2i(-5000, 5000), Vector2i(19969, 5000)])
	assert_equal(Rules.validate_route(outside, 2, BOUNDS_U, circles), Rules.REFUSE_OUT_OF_BOUNDS, "a bore past the edge")
	var edge := _route([Vector2i(-5000, 5000), Vector2i(19968, 5000)])
	assert_equal(Rules.validate_route(edge, 2, BOUNDS_U, circles), Rules.REFUSE_NONE, "a bore just inside")
	var into := _route([Vector2i(0, 0), Vector2i(5000, 0)])
	assert_equal(Rules.validate_route(into, 2, BOUNDS_U, circles), Rules.REFUSE_ENTRANCE_BLOCKED, "entrance inside")
	var out_of := _route([Vector2i(5000, 0), Vector2i(0, 0)])
	assert_equal(Rules.validate_route(out_of, 2, BOUNDS_U, circles), Rules.REFUSE_EXIT_BLOCKED, "exit inside")
	var short := _route([Vector2i(5000, 5000), Vector2i(7047, 5000)])
	assert_equal(Rules.validate_route(short, 2, BOUNDS_U, circles), Rules.REFUSE_TOO_SHORT, "2047u")
	var just := _route([Vector2i(5000, 5000), Vector2i(7048, 5000)])
	assert_equal(Rules.validate_route(just, 2, BOUNDS_U, circles), Rules.REFUSE_NONE, "2048u")


func test_a_route_may_bend_under_an_obstacle_but_not_a_building_and_is_capped_at_64_m() -> void:
	"""A bend inside an obstacle is fine -- unless that circle is a building's; 65536u of route is
	allowed, 65537u is not. (Changed with the review: a route used to pass under anything.)"""
	var circles := PackedInt32Array([0, 1024, 0])
	var under := _route([Vector2i(-5000, 0), Vector2i(0, 0), Vector2i(5000, 0)])
	assert_equal(Rules.validate_route(under, 3, BOUNDS_U, circles), Rules.REFUSE_NONE, "bends under a tree")
	assert_equal(Rules.validate_route(under, 3, BOUNDS_U, circles, PackedInt32Array(), circles), Rules.REFUSE_UNDER_BUILDING,
		"but not under a building")
	var zig := _route([Vector2i(-19000, -19000), Vector2i(-19000, 19000), Vector2i(-19000, -8536)])
	assert_equal(Rules.validate_route(zig, 3, BOUNDS_U, PackedInt32Array()), Rules.REFUSE_NONE, "38000 + 27536 = 65536u")
	var over := _route([Vector2i(-19000, -19000), Vector2i(-19000, 19000), Vector2i(-19000, -8537)])
	assert_equal(Rules.validate_route(over, 3, BOUNDS_U, PackedInt32Array()), Rules.REFUSE_TOO_LONG, "65537u")


func test_each_point_is_checked_as_it_is_laid() -> void:
	"""Only the entrance must clear obstacles when laid; the ninth point and the edge are refused."""
	var circles := PackedInt32Array([0, 1024, 0])
	assert_equal(Rules.validate_point(0, 0, 0, BOUNDS_U, circles), Rules.REFUSE_ENTRANCE_BLOCKED, "entrance inside")
	assert_equal(Rules.validate_point(0, 0, 1, BOUNDS_U, circles), Rules.REFUSE_NONE, "a bend inside")
	assert_equal(Rules.validate_point(5000, 0, 8, BOUNDS_U, circles), Rules.REFUSE_TOO_MANY_POINTS, "ninth")
	assert_equal(Rules.validate_point(5000, 0, 7, BOUNDS_U, circles), Rules.REFUSE_NONE, "eighth")
	assert_equal(Rules.validate_point(5000, -19969, 3, BOUNDS_U, circles), Rules.REFUSE_OUT_OF_BOUNDS, "past the edge")
	## Each edge exactly: a bore's half width (512u) may reach the 20480u edge, not pass it.
	assert_equal(Rules.validate_point(-19968, 0, 3, BOUNDS_U, circles), Rules.REFUSE_NONE, "west edge")
	assert_equal(Rules.validate_point(-19969, 0, 3, BOUNDS_U, circles), Rules.REFUSE_OUT_OF_BOUNDS, "past the west edge")
	assert_equal(Rules.validate_point(0, -19968, 3, BOUNDS_U, circles), Rules.REFUSE_NONE, "north edge")
	assert_equal(Rules.validate_point(0, 19968, 3, BOUNDS_U, circles), Rules.REFUSE_NONE, "south edge")
	assert_equal(Rules.validate_point(0, 19969, 3, BOUNDS_U, circles), Rules.REFUSE_OUT_OF_BOUNDS, "past the south edge")


func test_every_refusal_has_words() -> void:
	"""A reason per REFUSE_* code, and none for REFUSE_NONE."""
	assert_equal(Rules.REASONS.size(), 17, "seventeen codes (the last: under water)")
	assert_equal(Rules.reason_text(Rules.REFUSE_NONE), "", "no reason")
	assert_equal(Rules.reason_text(Rules.REFUSE_NOT_A_DIGGER), "only a mole can dig tunnels -- select the mole", "not a mole")
	assert_equal(Rules.reason_text(Rules.REFUSE_UNDER_BUILDING), "a tunnel cannot pass under a building or the well", "under")
	for code in range(1, 17):
		assert_false(Rules.reason_text(code).is_empty(), "code %d has words" % code)


# --- the route being laid -------------------------------------------------------------------

func test_a_plan_lays_undoes_and_refuses_points() -> void:
	"""Points are added in order, a refused one is not, undo takes back the last, lengths add up."""
	var plan := PlanScript.new()
	var circles := PackedInt32Array([0, 1024, 0])
	assert_equal(plan.try_add(0, 0, BOUNDS_U, circles), Rules.REFUSE_ENTRANCE_BLOCKED, "entrance in the circle")
	assert_equal(plan.count, 0, "not laid")
	assert_equal(plan.try_add(-3072, 4096, BOUNDS_U, circles), Rules.REFUSE_NONE, "entrance")
	assert_equal(plan.try_add(0, 0, BOUNDS_U, circles), Rules.REFUSE_NONE, "a bend in the circle")
	assert_equal(plan.count, 2, "two laid")
	assert_equal(plan.length_u(), 5120, "3-4-5")
	assert_equal(plan.length_to_u(3072, 4096), 10240, "and back out to the pointer")
	assert_equal(plan.route_reason(BOUNDS_U, circles), Rules.REFUSE_EXIT_BLOCKED, "ends in the circle")
	assert_true(plan.undo(), "undo the bend")
	assert_true(plan.undo(), "undo the entrance")
	assert_false(plan.undo(), "nothing left")
	assert_equal(plan.length_to_u(5, 5), 0, "no length with no points")


func test_lengths_read_to_a_tenth_of_a_metre() -> void:
	"""Rounded to the nearest tenth within the limits; a refused length is rounded away from the limit
	it breaks, so it never reads as an allowed one. (Changed with the review: 1.99 m read "2.0 m".)"""
	assert_equal(PlanScript.length_text(12698), "12.4 m", "12.400 m")
	assert_equal(PlanScript.length_text(3123), "3.0 m", "3.0498 m rounds down")
	assert_equal(PlanScript.length_text(3124), "3.1 m", "3.0508 m rounds up")
	assert_equal(PlanScript.length_text(0), "0.0 m", "nothing")
	assert_equal(PlanScript.length_text(1076), "1.0 m", "a short 1.0508 m is floored")
	assert_equal(PlanScript.length_text(2047), "1.9 m", "a refused 1.999 m never reads 2.0")
	assert_equal(PlanScript.length_text(2048), "2.0 m", "exactly the shortest")
	assert_equal(PlanScript.length_text(65536), "64.0 m", "exactly the longest")
	assert_equal(PlanScript.length_text(65537), "64.1 m", "a refused 64.001 m never reads 64.0")


# --- the network ----------------------------------------------------------------------------

func test_a_tunnel_is_stored_with_its_integer_geometry() -> void:
	"""Slot 0, generation 0, a 3-4-5 route plus a leg: 7168u, 7 quanta, digging, dug by resident 4."""
	var network := NetworkScript.new()
	var ref := PackedInt32Array([-1, 0])
	var route := _route([Vector2i(0, 0), Vector2i(3072, 4096), Vector2i(3072, 6144)])
	assert_true(network.add_into(route, 3, 4, ref), "stored")
	assert_equal(ref, PackedInt32Array([0, 0]), "slot 0, generation 0")
	assert_equal(network.length_u[0], 7168, "length")
	assert_equal(network.quanta[0], 7, "quanta")
	assert_equal(network.cumulative_u[1], 5120, "distance to the bend")
	assert_equal(network.phase[0], NetworkScript.PHASE_DIGGING, "digging")
	assert_equal(network.digger[0], 4, "its digger")
	assert_equal(network.mouth(0, true), Vector2(3.0, 6.0), "the exit, in metres")
	assert_true(network.is_ref(0, 0), "a live reference")
	assert_false(network.is_ref(0, 1), "a wrong generation")


func test_a_tunnel_that_cannot_be_stored_is_refused_whole() -> void:
	"""One point, a route under 2048u, and a ninth tunnel are refused, leaving out_ref alone."""
	var network := NetworkScript.new()
	var ref := PackedInt32Array([-1, 0])
	assert_false(network.add_into(_route([Vector2i(0, 0)]), 1, 0, ref), "one point")
	assert_false(network.add_into(_route([Vector2i(0, 0), Vector2i(2047, 0)]), 2, 0, ref), "too short")
	assert_equal(ref, PackedInt32Array([-1, 0]), "untouched")
	for k in 8:
		assert_true(network.add_into(_route([Vector2i(0, 1000 * k), Vector2i(4096, 1000 * k)]), 2, k, ref), "tunnel %d" % k)
	assert_false(network.has_room(), "full")
	assert_false(network.add_into(_route([Vector2i(0, 0), Vector2i(4096, 0)]), 2, 0, ref), "a ninth")
	assert_equal(ref, PackedInt32Array([7, 0]), "still the eighth's reference")


func test_digging_opens_a_tunnel_on_its_last_tick() -> void:
	"""A 2-quantum tunnel opens at 452 ticks: 15066666 us is 451, 15066667 us is 452."""
	var network := NetworkScript.new()
	var ref := PackedInt32Array([-1, 0])
	network.add_into(_route([Vector2i(0, 0), Vector2i(2048, 0)]), 2, 0, ref)
	network.advance(0, 0, 15066666)
	assert_equal(network.done(0), 451, "one tick short")
	assert_equal(network.phase[0], NetworkScript.PHASE_DIGGING, "still digging")
	assert_equal(network.percent(0), 99, "99%")
	network.advance(0, 0, 1)
	assert_equal(network.done(0), 452, "the last tick")
	assert_true(network.is_open(0), "open")
	assert_equal(network.open_count(), 1, "one open tunnel")
	assert_equal(network.digger[0], -1, "no digger any more")
	network.advance(0, 0, 5000000)
	assert_equal(network.done(0), 452, "an open tunnel digs no further")


func test_a_stale_or_idle_reference_digs_nothing() -> void:
	"""advance() with a wrong generation, a paused tunnel or no time does nothing."""
	var network := NetworkScript.new()
	var ref := PackedInt32Array([-1, 0])
	network.add_into(_route([Vector2i(0, 0), Vector2i(4096, 0)]), 2, 0, ref)
	network.advance(0, 1, 1000000)
	assert_equal(network.done(0), 0, "wrong generation")
	network.advance(0, 0, 0)
	assert_equal(network.dig_usec[0], 0, "no time")
	network.advance(0, 0, 1000000)
	network.stop_digging(0, 0)
	network.advance(0, 0, 1000000)
	assert_equal(network.done(0), 30, "paused: one second's 30 ticks only")


func test_stopping_keeps_progress_or_frees_an_untouched_slot() -> void:
	"""Called away with ticks dug: PAUSED, progress kept, resumable. With none: slot FREE and its
	generation bumped, so the old reference is dead and the slot's next tunnel is generation 1."""
	var network := NetworkScript.new()
	var ref := PackedInt32Array([-1, 0])
	network.add_into(_route([Vector2i(0, 0), Vector2i(4096, 0)]), 2, 3, ref)
	network.advance(0, 0, 2000000)
	network.stop_digging(0, 0)
	assert_equal(network.phase[0], NetworkScript.PHASE_PAUSED, "paused")
	assert_equal(network.done(0), 60, "two seconds kept")
	assert_equal(network.digger[0], -1, "no digger")
	assert_false(network.resume(0, 1, 5), "a wrong generation cannot resume")
	assert_true(network.resume(0, 0, 5), "resumed")
	assert_equal(network.digger[0], 5, "by its new digger")
	assert_false(network.resume(0, 0, 5), "only a paused tunnel resumes")
	network.add_into(_route([Vector2i(0, 2000), Vector2i(4096, 2000)]), 2, 3, ref)
	network.stop_digging(1, 0)
	assert_equal(network.phase[1], NetworkScript.PHASE_FREE, "nothing dug: freed")
	assert_equal(network.generation[1], 1, "generation bumped")
	assert_false(network.is_ref(1, 0), "the old reference is dead")
	network.add_into(_route([Vector2i(0, 4000), Vector2i(4096, 4000)]), 2, 3, ref)
	assert_equal(ref, PackedInt32Array([1, 1]), "the slot reused at generation 1")


func test_tunnel_geometry_for_drawing() -> void:
	"""Points along an L route, its leg directions, and a floor ramping 1.25 m down over 1.5 m."""
	var network := NetworkScript.new()
	var ref := PackedInt32Array([-1, 0])
	network.add_into(_route([Vector2i(0, 0), Vector2i(4096, 0), Vector2i(4096, 4096)]), 3, 0, ref)
	assert_equal(network.point_at(0, 2.0), Vector2(2.0, 0.0), "along the first leg")
	assert_equal(network.point_at(0, 3.5), Vector2(3.5, 0.0), "near the end of the first leg")
	assert_equal(network.direction_at(0, 3.9), Vector2(1.0, 0.0), "still heading +x just before the bend")
	assert_equal(network.point_at(0, 6.0), Vector2(4.0, 2.0), "along the second")
	assert_equal(network.point_at(0, 99.0), Vector2(4.0, 4.0), "clamped to the exit")
	assert_equal(network.direction_at(0, 1.0), Vector2(1.0, 0.0), "first leg heads +x")
	assert_equal(network.direction_at(0, 5.0), Vector2(0.0, 1.0), "second heads +z")
	assert_almost_equal(network.floor_y_at(0, 0.0), 0.0, "level with the ground at the entrance")
	assert_almost_equal(network.floor_y_at(0, 0.75), -0.625, "half way down the ramp")
	assert_almost_equal(network.floor_y_at(0, 4.0), -1.25, "bore depth")
	assert_almost_equal(network.floor_y_at(0, 8.0), 0.0, "level at the exit")


func test_fit_is_known_only_for_residents_set() -> void:
	"""Unknown and negative indices do not fit."""
	var network := NetworkScript.new()
	network.set_fit(2, true)
	network.set_fit(3, false)
	network.set_fit(4, true)
	assert_true(network.fits(4), "the last one set")
	assert_true(network.fits(2), "set to fit")
	assert_false(network.fits(3), "set not to")
	assert_false(network.fits(1), "never set")
	assert_false(network.fits(9), "past the column")
	assert_false(network.fits(-1), "no resident")


# --- the planner's shortcut -----------------------------------------------------------------

func test_a_tunnel_under_a_wall_is_the_route_when_it_is_shorter() -> void:
	"""Under a 13 m wall, a 4 m tunnel beats the walk round: the route reaches its entrance on the
	surface, crosses it as one tunnel leg, and walks on to the goal."""
	var space := _space(_wall())
	_open_tunnel(space, [Vector2i(0, -2048), Vector2i(0, 2048)])
	var index := space.add_resident(Vector2(0.0, -4.0), BODY_M)
	space.tunnels.set_fit(index, true)
	var path := PackedVector2Array()
	var legs := PackedInt32Array()
	space.plan_path(index, Vector2(0.0, -4.0), Vector2(0.0, 4.0), BODY_M, path, legs)
	assert_true(space.nav.last_found, "found")
	assert_equal(path, PackedVector2Array([Vector2(0.0, -2.0), Vector2(0.0, 2.0), Vector2(0.0, 4.0)]), "entrance, exit, goal")
	assert_equal(legs, PackedInt32Array([-1, 0, -1]), "one tunnel leg, slot 0 forward")
	space.plan_path(index, Vector2(0.0, 4.0), Vector2(0.0, -4.0), BODY_M, path, legs)
	assert_equal(legs, PackedInt32Array([-1, 1, -1]), "the other way it is crossed reversed")


func test_a_tunnel_is_not_taken_when_it_saves_nothing() -> void:
	"""A straight 6 m tunnel between two points 6 m apart in the open is exactly as long as the walk,
	so the surface is kept (a tunnel must be strictly shorter)."""
	var space := _space([])
	_open_tunnel(space, [Vector2i(-3072, -2048), Vector2i(3072, -2048)])
	var index := space.add_resident(Vector2(-3.0, -2.0), BODY_M)
	space.tunnels.set_fit(index, true)
	var path := PackedVector2Array()
	var legs := PackedInt32Array()
	space.plan_path(index, Vector2(-3.0, -2.0), Vector2(3.0, -2.0), BODY_M, path, legs)
	assert_equal(path, PackedVector2Array([Vector2(3.0, -2.0)]), "straight across")
	assert_equal(legs, PackedInt32Array([-1]), "on the surface")
	assert_equal(space.tunnels.router.last_surface_plans, 1, "one surface plan: no tunnel could beat it")


func test_a_longer_tunnel_loses_to_the_walk() -> void:
	"""A tunnel bending 6 m out of the way between two open points is never taken."""
	var space := _space([])
	_open_tunnel(space, [Vector2i(-3072, 0), Vector2i(0, 6144), Vector2i(3072, 0)])
	var index := space.add_resident(Vector2(-3.0, 0.5), BODY_M)
	space.tunnels.set_fit(index, true)
	var legs := PackedInt32Array()
	space.plan_path(index, Vector2(-3.0, 0.5), Vector2(3.0, 0.5), BODY_M, PackedVector2Array(), legs)
	assert_equal(legs, PackedInt32Array([-1]), "surface")


func test_only_those_who_fit_and_only_open_tunnels() -> void:
	"""A resident who does not fit walks round; so does everyone while the tunnel is unfinished, and
	while carrying (MOVE-REQ-002, MOVE-REQ-005)."""
	var space := _space(_wall())
	_open_tunnel(space, [Vector2i(15360, 15360), Vector2i(15360, 18432)])
	var ref := PackedInt32Array([-1, 0])
	space.tunnels.add_into(_route([Vector2i(0, -2048), Vector2i(0, 2048)]), 2, 0, ref)
	var index := space.add_resident(Vector2(0.0, -4.0), BODY_M)
	space.tunnels.set_fit(index, true)
	var path := PackedVector2Array()
	var legs := PackedInt32Array()
	space.plan_path(index, Vector2(0.0, -4.0), Vector2(0.0, 4.0), BODY_M, path, legs)
	assert_equal(legs.count(-1), legs.size(), "digging: no through route")
	space.tunnels.advance(ref[0], ref[1], 1000000000)
	space.plan_path(index, Vector2(0.0, -4.0), Vector2(0.0, 4.0), BODY_M, path, legs, false)
	assert_equal(legs.count(-1), legs.size(), "carrying: surface")
	space.tunnels.set_fit(index, false)
	space.plan_path(index, Vector2(0.0, -4.0), Vector2(0.0, 4.0), BODY_M, path, legs)
	assert_equal(legs.count(-1), legs.size(), "too big: surface")
	assert_true(path.size() >= 2, "round the wall")


func test_a_tunnel_reaches_a_goal_no_walk_can() -> void:
	"""A goal inside a closed pen, with a tunnel's exit inside it too: no surface route reaches the
	goal, so the planner must not cost the surface planner's straight-line fallback -- it goes by
	the tunnel, and reports the route found."""
	var obstacles := _ring(Vector2(0.0, 6.0))
	var space := _space(obstacles)
	## Bent so the tunnel route (2 + 6.32 + 1.5 m) is LONGER than the fallback's straight 9.5 m.
	_open_tunnel(space, [Vector2i(0, -1024), Vector2i(1024, 2048), Vector2i(0, 5120)])
	var index := space.add_resident(Vector2(0.0, -3.0), BODY_M)
	space.tunnels.set_fit(index, true)
	var path := PackedVector2Array()
	var legs := PackedInt32Array()
	space.plan_path(index, Vector2(0.0, -3.0), Vector2(0.0, 6.5), BODY_M, path, legs)
	assert_true(space.nav.last_found, "found")
	assert_equal(legs, PackedInt32Array([-1, 0, -1]), "through the tunnel")
	assert_equal(path[2], Vector2(0.0, 6.5), "to the goal in the pen")


func test_of_two_equally_short_routes_the_one_with_fewer_tunnels_wins() -> void:
	"""Exact ties on the u lattice. The goal (0, 10) sits in a closed pen, so every route ends in a
	tunnel. Route 1 crosses TWO tunnels (X under a wall to (0, 4), then Y into the pen at (0, 9)) and
	walks 1 m: 1 + 3 + 5 + 1 = 10 m. Route 2 crosses ONE (Z from (0, 1) into the pen at (0, 9.5)) and
	walks 0.5 m: 1 + 8.5 + 0.5 = 10 m. Route 1 reaches the goal first in the search (its last mouth
	is nearer the start), so only the (length, tunnels) comparison makes route 2 win."""
	var obstacles := _ring(Vector2(0.0, 10.0))
	for x in [-1.5, 0.0, 1.5]:
		obstacles.append(Vector3(x, 0.9, 2.5))
	var space := _space(obstacles)
	_open_tunnel(space, [Vector2i(0, 1024), Vector2i(0, 4096)])
	_open_tunnel(space, [Vector2i(0, 4096), Vector2i(0, 9216)])
	_open_tunnel(space, [Vector2i(0, 1024), Vector2i(0, 9728)])
	var index := space.add_resident(Vector2(0.0, 0.0), BODY_M)
	space.tunnels.set_fit(index, true)
	var path := PackedVector2Array()
	var legs := PackedInt32Array()
	space.plan_path(index, Vector2(0.0, 0.0), Vector2(0.0, 10.0), BODY_M, path, legs)
	assert_equal(legs, PackedInt32Array([-1, 4, -1]), "tunnel Z alone")
	assert_equal(path, PackedVector2Array([Vector2(0.0, 1.0), Vector2(0.0, 9.5), Vector2(0.0, 10.0)]), "via (0, 9.5)")


func test_two_tunnels_chain_across_two_walls() -> void:
	"""Walls at z = 0 and z = 6, a tunnel under each: the route crosses both, linked on the surface."""
	var walls := _wall()
	for circle in _wall():
		walls.append(Vector3(circle.x, circle.y, 6.0))
	var space := _space(walls)
	_open_tunnel(space, [Vector2i(0, -2048), Vector2i(0, 2048)])
	_open_tunnel(space, [Vector2i(0, 4096), Vector2i(0, 8192)])
	var index := space.add_resident(Vector2(0.0, -4.0), BODY_M)
	space.tunnels.set_fit(index, true)
	var path := PackedVector2Array()
	var legs := PackedInt32Array()
	space.plan_path(index, Vector2(0.0, -4.0), Vector2(0.0, 10.0), BODY_M, path, legs)
	assert_equal(legs, PackedInt32Array([-1, 0, -1, 2, -1]), "tunnel 0, then tunnel 1")
	assert_equal(path[4], Vector2(0.0, 10.0), "to the goal")


# --- residents in tunnels -------------------------------------------------------------------

func _watch_crossing(space: CastSpaceScript, brain: BrainScript, frames: int) -> Dictionary:
	"""Step `brain` for `frames`, noting: frames underground, the deepest floor, where it came up,
	and whether it was flagged underground and 'using the tunnel' on every frame below."""
	var seen := {"below": 0, "deepest": 0.0, "surfaced": Vector2.INF, "flagged": true, "in_tunnel": true,
		"went_down_from": Vector2.INF, "index_up": -1}
	var was_below := false
	for f in frames:
		var before := brain.position
		brain.step(DT)
		if brain.underground and not was_below:
			seen["went_down_from"] = before
		if brain.underground:
			seen["below"] += 1
			seen["deepest"] = minf(seen["deepest"], brain.ground_y_m)
			seen["flagged"] = seen["flagged"] and space.resident_underground[brain.index] == 1
			seen["in_tunnel"] = seen["in_tunnel"] and brain.activity() == BrainScript.ACTIVITY_TUNNEL
		elif was_below and seen["surfaced"] == Vector2.INF:
			seen["surfaced"] = brain.position
			seen["index_up"] = brain.path_index
		was_below = brain.underground
	return seen


func test_a_resident_walks_through_a_tunnel_off_the_surface() -> void:
	"""Ordered past a wall, a fitting resident walks to the entrance, goes down for 4 m at 1 m/s --
	underground, off the surface, below the ground -- comes up at the exit and holds at the goal."""
	var space := _space(_wall())
	_open_tunnel(space, [Vector2i(0, -2048), Vector2i(0, 2048)])
	var brain := _brain(space, Vector2(0.0, -4.0), true)
	brain.order_move(Vector2(0.0, 4.0))
	var seen := _watch_crossing(space, brain, 60 * 20)
	assert_true(seen["below"] >= 239 and seen["below"] <= 241, "4 m at 1 m/s is 240 frames (%d)" % seen["below"])
	assert_true(seen["flagged"], "flagged underground on every frame below")
	assert_true(seen["in_tunnel"], "'Using tunnel' on every frame below")
	assert_almost_equal(seen["deepest"], -1.25, "down to the bore floor")
	assert_equal(seen["surfaced"], Vector2(0.0, 2.0), "up at the exit")
	assert_true((seen["went_down_from"] as Vector2).distance_to(Vector2(0.0, -2.0)) < BrainScript.WAYPOINT_REACH_M,
		"went down only once at the entrance (from %s)" % seen["went_down_from"])
	assert_equal(seen["index_up"], 2, "came up and carried on along its own route, to the goal waypoint")
	assert_true(brain.trip_seconds() > 7.5, "the 4 s underground count as travel (%.2f s)" % brain.trip_seconds())
	assert_equal(brain.state, BrainScript.State.HOLD, "holding")
	assert_true(brain.position.distance_to(Vector2(0.0, 4.0)) <= BrainScript.ARRIVE_RADIUS_M + 0.02, "at the goal")
	assert_equal(space.resident_underground[brain.index], 0, "back on the surface")


func test_nobody_collides_with_or_plans_round_someone_underground() -> void:
	"""A resident flagged underground neither pushes, blocks a step, nor stands in a plan's way."""
	var space := _space([])
	var walker := space.add_resident(Vector2(0.0, -1.0), BODY_M)
	var below := space.add_resident(Vector2(0.0, 0.0), 0.5)
	space.set_underground(below, true)
	assert_equal(space.separation(walker, Vector2(0.0, -0.3), Vector2(0.0, 1.0)), Vector2.ZERO, "no push")
	assert_equal(space.constrain(walker, Vector2(0.0, -1.0), Vector2(0.0, -0.2), Vector2(0.0, 4.0)), Vector2(0.0, -0.2), "no block")
	var path := PackedVector2Array()
	space.plan_path(walker, Vector2(0.0, -4.0), Vector2(0.0, 4.0), BODY_M, path)
	assert_equal(path.size(), 1, "straight over them")
	assert_false(space.standing_blocks(walker, Vector2(0.0, -4.0), Vector2(0.0, 4.0), BODY_M, Vector2(0.0, 4.0), 0.0), "not in the way")
	space.set_underground(below, false)
	assert_true(space.standing_blocks(walker, Vector2(0.0, -4.0), Vector2(0.0, 4.0), BODY_M, Vector2(0.0, 4.0), 0.0), "back up, in the way")


func test_an_order_given_underground_is_carried_out_from_the_far_mouth() -> void:
	"""Re-ordered half way through, the resident finishes the tunnel, comes up at its exit, and only
	then heads for the new goal (MOVE-REQ-007)."""
	var space := _space(_wall())
	_open_tunnel(space, [Vector2i(0, -2048), Vector2i(0, 2048)])
	var brain := _brain(space, Vector2(0.0, -4.0), true)
	brain.order_move(Vector2(0.0, 4.0))
	var guard := 0
	while not brain.underground and guard < 600:
		brain.step(DT)
		guard += 1
	_step(brain, 1.0)
	assert_true(brain.underground, "part way through")
	assert_equal(brain.surface_point(), Vector2(0.0, 2.0), "it will come up at the exit")
	brain.order_move(Vector2(4.0, 4.0))
	while brain.underground and guard < 1200:
		brain.step(DT)
		guard += 1
	assert_equal(brain.position, Vector2(0.0, 2.0), "came up at the exit")
	_step(brain, 10.0)
	assert_true(brain.position.distance_to(Vector2(4.0, 4.0)) <= BrainScript.ARRIVE_RADIUS_M + 0.02, "then went on")


func _carry_motion() -> Dictionary:
	"""A recorded carry root path: 0.2 m/s straight ahead, 31 keys over 3 s."""
	var keys: Array = []
	for k in 31:
		keys.append([0.0, 0.02 * float(k)])
	return {"period_s": 3.0, "mean_speed_m_s": 0.2, "keys_xz": keys}


func _haul_trip(points: Array[Dictionary], attempt: int) -> Array[bool]:
	"""One stockpile resident's first trip north through a tunnel under a wall, with seed SEED +
	`attempt`: [crossed a tunnel, carried, carried while underground]."""
	var space := CastSpaceScript.new()
	space.setup(points, _wall())
	_open_tunnel(space, [Vector2i(0, -2048), Vector2i(0, 2048)])
	var brain := BrainScript.new()
	brain.configure(space, WALK_M_S, BODY_M, SEED + attempt, _lengths())
	brain.set_carry_motion(_carry_motion())
	space.tunnels.set_fit(brain.index, true)
	space.reserve(0, 0)
	brain.start_at(space.slot_position(0, 0), 0.0, 0, 0)
	var f := 0
	while brain.poi != 1 and f < 60 * 90:
		brain.step(DT)
		f += 1
	var trip: Array[bool] = [brain.crosses_tunnel(), brain.carrying, false]
	while brain.state != BrainScript.State.FACE and brain.state != BrainScript.State.ACT and f < 60 * 180:
		brain.step(DT)
		trip[2] = trip[2] or (brain.underground and brain.carrying)
		f += 1
	return trip


func test_a_carrier_hauls_through_a_bore_its_load_fits() -> void:
	"""Leaving a stockpile, a carrier may carry THROUGH a tunnel whose bore fits it with its load (the
	demo's hauling; this replaced "nobody carries a load through a tunnel"): over twelve seeds every
	trip goes through the tunnel, and those that carry carry it underground."""
	var points: Array[Dictionary] = [
		{"name": &"stockpile", "position": Vector3(0.0, 0.0, -3.0), "face": Vector3.FORWARD, "activities": [&"collect_object"], "capacity": 1},
		{"name": &"north", "position": Vector3(0.0, 0.0, 3.0), "face": Vector3.BACK, "activities": [&"idle"], "capacity": 1}]
	var counts := PackedInt32Array([0, 0, 0])
	for attempt in 12:
		var trip := _haul_trip(points, attempt)
		for k in 3:
			counts[k] += 1 if trip[k] else 0
	assert_true(_carries_at_all(), "the fixture's motion makes a carrier")
	assert_equal(counts[0], 12, "every trip through the tunnel")
	assert_equal(counts[1], 4, "four of the twelve seeds carry")
	assert_equal(counts[2], 4, "and every one of them carries it through the bore")


func _carries_at_all() -> bool:
	"""Whether a brain given _carry_motion() can carry at all (so the test above is not vacuous)."""
	var space := _space([])
	var brain := BrainScript.new()
	brain.configure(space, WALK_M_S, BODY_M, SEED, _lengths())
	brain.set_carry_motion(_carry_motion())
	return brain.can_carry()


func test_crosses_tunnel_reads_the_route_s_legs() -> void:
	"""A route with any tunnel leg crosses a tunnel; an all-surface or empty one does not."""
	var brain := _brain(_space([]), Vector2.ZERO, true)
	brain.path_tunnel = PackedInt32Array([-1, 4, -1])
	assert_true(brain.crosses_tunnel(), "one tunnel leg")
	brain.path_tunnel = PackedInt32Array([-1, -1])
	assert_false(brain.crosses_tunnel(), "all surface")
	brain.path_tunnel = PackedInt32Array()
	assert_false(brain.crosses_tunnel(), "no route")


# --- digging --------------------------------------------------------------------------------

func _dig_site() -> Array:
	"""An open field, a 2 m tunnel planned from (0, 0) to (2, 0) for a mole standing at (-3, 0):
	[space, mole brain, slot, generation]."""
	var space := _space([])
	var mole := _brain(space, Vector2(-3.0, 0.0), true)
	var ref := PackedInt32Array([-1, 0])
	assert_true(space.tunnels.add_into(_route([Vector2i(0, 0), Vector2i(2048, 0)]), 2, mole.index, ref), "planned")
	return [space, mole, ref[0], ref[1]]


func _watch_dig(space: CastSpaceScript, mole: BrainScript, slot: int, frames: int) -> Dictionary:
	"""Step the mole for `frames`, noting frames spent digging (and of those on the surface), where it
	first came up, and whether every digging frame played the dig clip, read as digging and never saw
	the percentage fall."""
	var seen := {"dig": 0, "surface_dig": 0, "surfaced": Vector2.INF, "steady": true}
	var last_percent := 0
	for f in frames:
		var was_below := mole.underground
		mole.step(DT)
		if was_below and not mole.underground and seen["surfaced"] == Vector2.INF:
			seen["surfaced"] = mole.position
		if mole.state == BrainScript.State.DIG:
			seen["dig"] += 1
			seen["surface_dig"] += 0 if mole.underground else 1
			seen["steady"] = seen["steady"] and mole.clip == &"pull_radish" \
					and mole.activity() == BrainScript.ACTIVITY_DIGGING and space.tunnels.percent(slot) >= last_percent
			last_percent = space.tunnels.percent(slot)
	return seen


func test_a_mole_digs_a_tunnel_through_and_comes_up_at_the_exit() -> void:
	"""Walk to the entrance; dig its shaft on the surface with the dig clip for 113 ticks; follow the
	face underground; open after 452 ticks in all (904 frames at 60 Hz); come up at the exit, step
	clear and hold, with 2000 milli-U heaped per quantum -- 6000 at the entrance, 2000 at the exit."""
	var site := _dig_site()
	var space: CastSpaceScript = site[0]
	var mole: BrainScript = site[1]
	mole.order_dig(site[2], site[3])
	assert_equal(mole.order, BrainScript.ORDER_DIG, "under a dig order")
	var seen := _watch_dig(space, mole, site[2], 60 * 30)
	assert_true(seen["dig"] >= 903 and seen["dig"] <= 905, "452 ticks is 904 frames (%d)" % seen["dig"])
	assert_true(seen["surface_dig"] >= 225 and seen["surface_dig"] <= 227, "the entrance shaft on the surface (%d)" % seen["surface_dig"])
	assert_true(seen["steady"], "digging clip, digging activity and a rising percentage on every frame")
	assert_true(space.tunnels.is_open(site[2]), "open")
	var spoil := PackedInt64Array([0, 0])
	space.tunnels.spoil_into(site[2], spoil)
	assert_equal(spoil, PackedInt64Array([6000, 2000]), "3 quanta out of the entrance, 1 out of the exit")
	assert_equal(seen["surfaced"], Vector2(2.0, 0.0), "up at the exit")
	assert_equal(mole.state, BrainScript.State.HOLD, "holding")
	assert_true(mole.position.distance_to(Vector2(3.0, 0.0)) <= BrainScript.ARRIVE_RADIUS_M + 0.02, "a step clear of the hole")
	assert_equal(mole.dig_tunnel, -1, "no longer digging")


func test_the_mole_follows_the_face_underground() -> void:
	"""Half way through the bore (113 + 113 ticks) the mole is 1 m in, on the bore floor's ramp."""
	var site := _dig_site()
	var space: CastSpaceScript = site[0]
	var mole: BrainScript = site[1]
	mole.order_dig(site[2], site[3])
	_dig_to(space, mole, site[2], 226)
	assert_equal(space.tunnels.done(site[2]), 226, "half way through the bore")
	assert_true(mole.underground, "underground")
	assert_equal(mole.position, Vector2(1.0, 0.0), "at the face, 1 m in")
	assert_almost_equal(mole.ground_y_m, -0.8333333, "two thirds of the way down the 1.5 m ramp")
	assert_equal(mole.surface_point(), Vector2(0.0, 0.0), "would come up at the entrance")


func test_called_away_mid_bore_the_mole_backs_out_and_the_tunnel_waits() -> void:
	"""Ordered off at 1 m in: the tunnel pauses with every tick and unit of spoil kept, the mole walks
	back out through the entrance and on to its order; resumed, it walks down to the face and
	finishes."""
	var site := _dig_site()
	var space: CastSpaceScript = site[0]
	var mole: BrainScript = site[1]
	mole.order_dig(site[2], site[3])
	_dig_to(space, mole, site[2], 226)
	mole.order_move(Vector2(-3.0, 3.0))
	assert_equal(space.tunnels.phase[site[2]], NetworkScript.PHASE_PAUSED, "paused")
	assert_equal(mole.dig_tunnel, -1, "no longer digging it")
	assert_equal(_surfacing(mole, 60 * 60), Vector2(0.0, 0.0), "came out of the entrance")
	_step(mole, 8.0)
	assert_true(mole.position.distance_to(Vector2(-3.0, 3.0)) <= BrainScript.ARRIVE_RADIUS_M + 0.02, "and went on")
	assert_equal(space.tunnels.done(site[2]), 226, "nothing lost, nothing dug while away")
	assert_true(space.tunnels.resume(site[2], site[3], mole.index), "resumed")
	mole.order_dig(site[2], site[3])
	assert_equal(_surfacing(mole, 60 * 20), Vector2(2.0, 0.0), "down to the face again, and up at the exit")
	assert_true(space.tunnels.is_open(site[2]), "finished")


func test_called_away_before_breaking_ground_frees_the_tunnel() -> void:
	"""Re-ordered on the way to the entrance, nothing was dug: the slot is freed, its generation
	bumped."""
	var site := _dig_site()
	var space: CastSpaceScript = site[0]
	var mole: BrainScript = site[1]
	mole.order_dig(site[2], site[3])
	_step(mole, 1.0)
	mole.order_move(Vector2(-5.0, 0.0))
	assert_equal(space.tunnels.phase[site[2]], NetworkScript.PHASE_FREE, "freed")
	assert_equal(space.tunnels.generation[site[2]], 1, "generation bumped")
	assert_equal(mole.dig_tunnel, -1, "the mole holds no reference")


func test_a_finished_tunnel_persists_and_serves_after_its_digger_leaves() -> void:
	"""MOVE-REQ-004: a tunnel the mole dug under a wall stays open after the mole walks off and is
	released, and a mouse ordered across the wall is routed through it."""
	var space := _space(_wall())
	var mole := _brain(space, Vector2(0.0, -4.0), true)
	var ref := PackedInt32Array([-1, 0])
	space.tunnels.add_into(_route([Vector2i(0, -2048), Vector2i(0, 2048)]), 2, mole.index, ref)
	mole.order_dig(ref[0], ref[1])
	_step(mole, 40.0)
	assert_true(space.tunnels.is_open(ref[0]), "dug")
	mole.order_move(Vector2(3.0, 4.0))
	_step(mole, 10.0)
	mole.release()
	_step(mole, 30.0)
	assert_true(space.tunnels.is_open(ref[0]), "still open after its digger left")
	assert_equal(space.tunnels.open_count(), 1, "one tunnel")
	var mouse := _brain(space, Vector2(1.0, -4.0), true)
	var legs := PackedInt32Array()
	space.plan_path(mouse.index, Vector2(1.0, -4.0), Vector2(1.0, 4.0), BODY_M, PackedVector2Array(), legs)
	assert_true(legs.has(0), "the mouse goes through it")


# --- drawing --------------------------------------------------------------------------------

func test_heaps_grow_with_their_spoil() -> void:
	"""A dome of 0.06 m³ a unit, half as tall as wide: none for none, 0.486 m for one quantum's
	2 U, 1.142 m for 26 U."""
	assert_almost_equal(OverlayScript.heap_radius_m(0), 0.0, "no heap")
	assert_true(absf(OverlayScript.heap_radius_m(2000) - 0.48572) < 1e-4, "one quantum")
	assert_true(absf(OverlayScript.heap_radius_m(26000) - 1.14209) < 1e-4, "thirteen quanta")


func test_the_overlay_shows_mouths_heaps_and_the_mound_as_digging_goes() -> void:
	"""Mid-bore: entrance hole and heap, a mound over the mole, no exit. Open: exit hole and heap,
	no mound."""
	var site := _dig_site()
	var space: CastSpaceScript = site[0]
	var mole: BrainScript = site[1]
	var overlay := OverlayScript.new()
	_nodes.append(overlay)
	overlay.configure(space.tunnels, space)
	mole.order_dig(site[2], site[3])
	overlay.refresh()
	assert_false(overlay.hole(site[2], false).visible, "no hole before any digging")
	assert_false(overlay.heap(site[2], false).visible, "nor a heap")
	_dig_to(space, mole, site[2], 226)
	overlay.refresh()
	assert_true(overlay.hole(site[2], false).visible, "entrance open")
	assert_false(overlay.hole(site[2], true).visible, "exit not yet")
	assert_true(overlay.heap(site[2], false).visible, "entrance heap")
	assert_almost_equal(overlay.heap(site[2], false).scale.x, OverlayScript.heap_radius_m(4000), "two quanta's spoil")
	assert_false(overlay.heap(site[2], true).visible, "no exit heap")
	assert_true(overlay.mound(site[2]).visible, "a mound over the mole")
	assert_equal(overlay.mound(site[2]).position, Vector3(1.0, 0.0, 0.0), "at the face")
	_step(mole, 20.0)
	_check_open_overlay(overlay, site[2])


func _check_open_overlay(overlay: OverlayScript, slot: int) -> void:
	"""An open tunnel's overlay: both mouths and heaps, no mound; its trough built, on the underground
	layer only (decision 0206: the U view is a cull mask, so the trough never waits for it)."""
	overlay.refresh()
	assert_true(overlay.hole(slot, true).visible, "exit open")
	assert_true(overlay.heap(slot, true).visible, "exit heap")
	assert_false(overlay.mound(slot).visible, "the mole is up")
	assert_true(overlay.bore(slot).visible, "the trough is built as the bore is dug")
	assert_equal(overlay.bore(slot).layers, Layers.UNDERGROUND, "on the underground layer: only the U view draws it")
	assert_equal(overlay.hole(slot, true).get_child(0).layers, Layers.SURFACE, "the mouth stays on the surface")


# --- the tunnel tool ------------------------------------------------------------------------

func _cast_with_mole() -> DemoCastScript:
	"""The placeholder cast (six 1 m capsules) in the demo's 40 m bounds, one circle at (0, 0), with
	placeholder 0 made a mole."""
	var cast := DemoCastScript.new()
	_nodes.append(cast)
	var points: Array[Dictionary] = []
	var circles: Array[Vector3] = [Vector3(0.0, 1.0, 0.0)]
	cast.build({}, points, circles)
	cast.set_bounds(AABB(Vector3(-20.0, 0.0, -20.0), Vector3(40.0, 4.0, 40.0)))
	(cast.actor(0) as DemoActorScript).species = "Mole"
	return cast


func _tool(cast: DemoCastScript, selection: Array, marks: Array, notices: Array) -> ControlScript:
	"""A tunnel tool on `cast`: selection[0] is the selected indices; marks and notices collect what
	it shows ([at, accepted] and text)."""
	var tool := ControlScript.new()
	_nodes.append(tool)
	var camera := Camera3D.new()
	_nodes.append(camera)
	tool.configure(cast, camera, func() -> PackedInt32Array: return selection[0],
		func(at: Vector3, ok: bool) -> void: marks.append([at, ok]), func(text: String) -> void: notices.append(text))
	return tool


func _key(key: Key) -> InputEventKey:
	"""A plain key press."""
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = true
	return event


func test_t_with_no_mole_says_only_a_mole_digs() -> void:
	"""T with a mouse selected (or nobody) is taken, plans nothing, and says why."""
	var cast := _cast_with_mole()
	var notices := []
	var tool := _tool(cast, [PackedInt32Array([1, 2])], [], notices)
	assert_true(tool.handle_input(_key(KEY_T)), "T is the tool's key")
	assert_false(tool.planning, "not planning")
	assert_equal(notices[-1], "Can't dig: only a mole can dig tunnels -- select the mole", "why")
	var nobody := _tool(cast, [PackedInt32Array()], [], notices)
	assert_false(nobody.begin_plan(), "nobody selected")
	assert_false(tool.handle_input(_key(KEY_Y)), "other keys are left alone")


func test_every_resident_s_fit_is_set_from_its_body() -> void:
	"""The placeholders are 1 m capsules (radius 0.22 m): all fit, as mice do."""
	var cast := _cast_with_mole()
	var tool := _tool(cast, [PackedInt32Array()], [], [])
	for i in cast.actor_count():
		assert_true(tool.network.fits((cast.actor(i) as DemoActorScript).brain.index), "placeholder %d fits" % i)
	assert_true(tool.is_digger(0), "the mole digs")
	assert_false(tool.is_digger(1), "a placeholder does not")


func test_laying_refusing_and_undoing_points() -> void:
	"""T with the mole among the selection plans for it; a point off the map is refused with a clay
	marker; a one-point route is refused at Enter, marked at its entrance; Backspace undoes."""
	var cast := _cast_with_mole()
	var marks := []
	var notices := []
	var tool := _tool(cast, [PackedInt32Array([2, 0])], marks, notices)
	assert_true(tool.handle_input(_key(KEY_T)), "T")
	assert_true(tool.planning, "planning")
	assert_equal(notices[-1], ControlScript.PLAN_FIRST, "prompted for the entrance")
	assert_false(tool.lay_ground(Vector2(25.0, 0.0)), "off the map")
	assert_equal(marks[-1], [Vector3(25.0, 0.0, 0.0), false], "a clay marker there")
	assert_equal(tool.plan.count, 0, "not laid")
	assert_true(tool.lay_ground(Vector2(-4.0, 3.0)), "the entrance")
	assert_true(tool.handle_input(_key(KEY_ENTER)), "Enter")
	assert_true(tool.planning, "a one-point route is refused; still planning")
	assert_equal(notices[-1], "Can't dig: a tunnel needs an entrance and an exit", "why")
	assert_equal(marks[-1], [Vector3(-4.0, 0.0, 3.0), false], "marked at the entrance")
	assert_true(tool.lay_ground(Vector2(9.0, 9.0)), "a stray point")
	assert_true(tool.handle_input(_key(KEY_BACKSPACE)), "Backspace")
	assert_equal(tool.plan.count, 1, "the stray point is taken back")
	assert_true(tool.handle_input(_key(KEY_BACKSPACE)), "Backspace again")
	assert_true(tool.handle_input(_key(KEY_BACKSPACE)), "and once more, with nothing left")
	assert_false(tool.planning, "which stops planning")


func test_enter_digs_a_good_route_and_sends_the_mole() -> void:
	"""A route bending under the circle: Enter stores it for the mole, sends the mole, drops an ember
	marker at the entrance and says what it costs."""
	var cast := _cast_with_mole()
	var marks := []
	var notices := []
	var tool := _tool(cast, [PackedInt32Array([2, 0])], marks, notices)
	tool.begin_plan()
	assert_true(tool.lay_ground(Vector2(-4.0, 3.0)), "the entrance")
	assert_true(tool.lay_ground(Vector2(0.0, 0.0)), "a bend under the circle")
	assert_true(tool.lay_ground(Vector2(4.0, 3.0)), "the exit")
	assert_true(tool.handle_input(_key(KEY_ENTER)), "Enter")
	assert_false(tool.planning, "done planning")
	assert_equal(tool.network.phase[0], NetworkScript.PHASE_DIGGING, "a tunnel to dig")
	var mole := (cast.actor(0) as DemoActorScript).brain
	assert_equal(tool.network.digger[0], mole.index, "by the mole")
	assert_equal(mole.order, BrainScript.ORDER_DIG, "the mole is sent")
	assert_equal(mole.dig_tunnel, 0, "to that tunnel")
	assert_equal(marks[-1], [Vector3(-4.0, 0.0, 3.0), true], "an ember marker at the entrance")
	assert_equal(notices[-1], "Digging a 10.0 m tunnel: 12 m³ to cut, 24 U of spoil, about 45 s", "what it costs")
	assert_true(tool.network.heap_radius_m[0] > 0.0 and tool.network.heap_radius_m[1] > 0.0, "its heaps placed")
	assert_equal(cast.space().obstacles.size(), 3, "and standing as obstacles beside the circle")


func test_an_exit_inside_an_obstacle_is_refused_at_the_exit() -> void:
	"""The last point inside the circle: refused, marked at the exit, still planning."""
	var cast := _cast_with_mole()
	var marks := []
	var notices := []
	var tool := _tool(cast, [PackedInt32Array([0])], marks, notices)
	tool.begin_plan()
	tool.lay_ground(Vector2(-4.0, 0.0))
	tool.lay_ground(Vector2(0.25, 0.0))
	assert_false(tool.confirm(), "refused")
	assert_true(tool.planning, "still planning")
	assert_equal(notices[-1], "Can't dig: the exit would open inside a building or obstacle", "why")
	assert_equal(marks[-1], [Vector3(0.25, 0.0, 0.0), false], "marked at the exit")
	assert_equal(tool.network.phase.count(NetworkScript.PHASE_FREE), 8, "nothing stored")


func test_escape_cancels_and_a_busy_mole_is_refused() -> void:
	"""Esc stops planning without digging; T again while the mole digs says it is busy."""
	var cast := _cast_with_mole()
	var notices := []
	var tool := _tool(cast, [PackedInt32Array([0])], [], notices)
	tool.begin_plan()
	tool.lay_ground(Vector2(-4.0, 5.0))
	assert_true(tool.handle_input(_key(KEY_ESCAPE)), "Esc")
	assert_false(tool.planning, "cancelled")
	assert_equal(notices[-1], ControlScript.PLAN_CANCELLED, "said so")
	assert_equal(tool.network.phase.count(NetworkScript.PHASE_FREE), 8, "nothing stored")
	tool.begin_plan()
	tool.lay_ground(Vector2(-4.0, 5.0))
	tool.lay_ground(Vector2(4.0, 5.0))
	assert_true(tool.confirm(), "digging")
	assert_false(tool.begin_plan(), "busy")
	assert_equal(notices[-1], "Can't dig: the mole is already digging a tunnel", "why")


func test_u_switches_the_underground_view() -> void:
	"""U turns the view on and off, and says so."""
	var cast := _cast_with_mole()
	var notices := []
	var tool := _tool(cast, [PackedInt32Array()], [], notices)
	assert_true(tool.handle_input(_key(KEY_U)), "U")
	assert_true(tool.view.on, "on")
	assert_equal(notices[-1], ControlScript.VIEW_ON, "said so")
	assert_true(tool.handle_input(_key(KEY_U)), "U again")
	assert_false(tool.view.on, "off")


func test_the_command_layer_hands_t_to_the_tool_and_shows_digging() -> void:
	"""Through demo_command: T with the mole selected plans; the party shows the mole as a digger,
	"walking to dig site", then "Digging tunnel — n%"."""
	var cast := _cast_with_mole()
	var command := CommandScript.new()
	_nodes.append(command)
	var camera := Camera3D.new()
	_nodes.append(camera)
	command.configure(cast, camera, null)
	command.select(PackedInt32Array([0]))
	assert_true(command.handle_input(_key(KEY_T)), "T taken")
	assert_true(command.tunnels().planning, "planning")
	command.tunnels().lay_ground(Vector2(-3.0, 3.0))
	command.tunnels().lay_ground(Vector2(3.0, 3.0))
	assert_true(command.handle_input(_key(KEY_ENTER)), "Enter taken")
	var entries := command.party_entries()
	assert_true(bool(entries[0]["digger"]), "a digger")
	assert_equal(entries[0]["state"], "walking to dig site", "on the way")
	var mole := (cast.actor(0) as DemoActorScript).brain
	var guard := 0
	while mole.state != BrainScript.State.DIG and guard < 60 * 60:
		mole.step(DT)
		guard += 1
	_step(mole, 5.0)
	assert_equal(command.tunnels().network.done(0), 150, "5 s of digging is 150 ticks")
	assert_equal(command.party_entries()[0]["state"], "Digging tunnel — 16%", "150 of (6 + 2) x 113 = 904 ticks")


# --- the panel ------------------------------------------------------------------------------

func test_the_panel_s_tunnel_words() -> void:
	"""Digging shows its percentage; walking a tunnel says so; the button shows only with a digger."""
	assert_equal(PanelScript.state_text(BrainScript.ACTIVITY_DIGGING, &"pull_radish", "", 43), "Digging tunnel — 43%", "digging")
	assert_equal(PanelScript.state_text(BrainScript.ACTIVITY_TUNNEL, &"walk", ""), "Using tunnel", "in a tunnel")
	assert_equal(PanelScript.state_text(BrainScript.ACTIVITY_WALKING, &"walk", "dig site"), "walking to dig site", "on the way")
	var mole: Array[Dictionary] = [{"name": "Mole digger", "digger": true}]
	var mouse: Array[Dictionary] = [{"name": "Mouse keeper", "digger": false}, {"name": "Otter"}]
	assert_true(PanelScript.has_digger(mole), "a mole")
	assert_false(PanelScript.has_digger(mouse), "no mole")


func test_the_panel_s_tunnel_text_is_legible() -> void:
	"""The button's cream on wood and brass-pressed ink, and the notice's ink on parchment, clear
	4.5:1 on each surface's darkest and lightest grain."""
	var wood := PackedColorArray([Palette.face_dark(Palette.SURFACE_WOOD), Palette.face_light(Palette.SURFACE_WOOD)])
	var brass := PackedColorArray([Palette.face_dark(Palette.SURFACE_BRASS), Palette.face_light(Palette.SURFACE_BRASS)])
	var parchment := PackedColorArray([Palette.face_dark(Palette.SURFACE_PARCHMENT), Palette.face_light(Palette.SURFACE_PARCHMENT)])
	var cream := Palette.text_on(Palette.SURFACE_WOOD)
	assert_true(Contrast.worst_ratio(cream, wood) >= Contrast.BODY_MINIMUM, "cream on wood %.2f" % Contrast.worst_ratio(cream, wood))
	var pressed := Palette.text_on(Palette.SURFACE_BRASS)
	assert_true(Contrast.worst_ratio(pressed, brass) >= Contrast.BODY_MINIMUM, "ink on brass %.2f" % Contrast.worst_ratio(pressed, brass))
	assert_true(Contrast.worst_ratio(Palette.INK, parchment) >= Contrast.BODY_MINIMUM, "notice ink")


func test_a_notice_waits_for_the_panel_to_be_built() -> void:
	"""Out of the tree the panel has no widgets yet; a notice is kept, not lost."""
	var panel := PanelScript.new()
	_nodes.append(panel)
	panel.show_notice("Tunnel: click where the entrance opens")
	assert_equal(panel.notice(), "Tunnel: click where the entrance opens", "kept")


# --- orders around digging ------------------------------------------------------------------

func test_resumed_the_mole_walks_down_to_the_face_digging() -> void:
	"""Resumed at 226 ticks, the mole walks down 1 m to the face (reading as digging all the way)
	before it digs again -- it does not start over at the entrance."""
	var site := _dig_site()
	var space: CastSpaceScript = site[0]
	var mole: BrainScript = site[1]
	mole.order_dig(site[2], site[3])
	_dig_to(space, mole, site[2], 226)
	mole.order_move(Vector2(-3.0, 3.0))
	_step(mole, 12.0)
	space.tunnels.resume(site[2], site[3], mole.index)
	mole.order_dig(site[2], site[3])
	var descending := 0
	var reads_digging := true
	for f in 60 * 10:
		mole.step(DT)
		if mole.state == BrainScript.State.TUNNEL:
			descending += 1
			reads_digging = reads_digging and mole.activity() == BrainScript.ACTIVITY_DIGGING
		if mole.state == BrainScript.State.DIG and mole.underground:
			break
	assert_true(descending >= 59 and descending <= 61, "1 m down at 1 m/s is 60 frames (%d)" % descending)
	assert_true(reads_digging, "'Digging tunnel' on the way down")
	assert_equal(space.tunnels.done(site[2]), 226, "no digging on the way down")


func test_a_mole_that_cannot_reach_the_entrance_leaves_the_dig_paused() -> void:
	"""An entrance inside a closed pen: the walk there is given up after its replans -- and the tunnel
	is KEPT, paused at 0% as the mole could not reach it, never silently deleted. (Changed with the
	playtest: it used to be freed.)"""
	var space := _space(_ring(Vector2.ZERO))
	var mole := _brain(space, Vector2(-6.0, 0.0), true)
	var ref := PackedInt32Array([-1, 0])
	assert_true(space.tunnels.add_into(_route([Vector2i(0, 0), Vector2i(0, 8192)]), 2, mole.index, ref), "planned")
	mole.order_dig(ref[0], ref[1])
	_step(mole, 60.0)
	assert_equal(mole.dig_tunnel, -1, "gave the dig up")
	assert_equal(space.tunnels.phase[ref[0]], NetworkScript.PHASE_PAUSED, "kept, paused")
	assert_equal(space.tunnels.pause_reason[ref[0]], NetworkScript.PAUSED_UNREACHED, "because it was out of reach")
	assert_equal(space.tunnels.percent(ref[0]), 0, "at 0%")
	assert_true(space.tunnels.is_ref(ref[0], ref[1]), "the same tunnel")
	assert_equal(mole.state, BrainScript.State.HOLD, "holding where it gave up")


func test_released_underground_it_comes_up_and_idles() -> void:
	"""Released half way through a tunnel, a resident finishes it, comes up at the exit and idles --
	it does not go on to the goal it was ordered to."""
	var space := _space(_wall())
	_open_tunnel(space, [Vector2i(0, -2048), Vector2i(0, 2048)])
	var brain := _brain(space, Vector2(0.0, -4.0), true)
	brain.order_move(Vector2(0.0, 4.0))
	var guard := 0
	while not brain.underground and guard < 600:
		brain.step(DT)
		guard += 1
	brain.release()
	assert_equal(_surfacing(brain, 600), Vector2(0.0, 2.0), "up at the exit")
	assert_equal(brain.state, BrainScript.State.IDLE, "idling there")
	assert_equal(brain.order, BrainScript.ORDER_NONE, "on its own again")


func test_an_entrance_the_mole_cannot_reach_is_refused_there() -> void:
	"""The tool checks the mole can walk to the entrance: one inside a pen is refused, marked at the
	entrance (not the last point)."""
	var cast := DemoCastScript.new()
	_nodes.append(cast)
	var points: Array[Dictionary] = []
	cast.build({}, points, _ring(Vector2(0.0, 8.0)))
	cast.set_bounds(AABB(Vector3(-20.0, 0.0, -20.0), Vector3(40.0, 4.0, 40.0)))
	(cast.actor(0) as DemoActorScript).species = "Mole"
	var marks := []
	var notices := []
	var tool := _tool(cast, [PackedInt32Array([0])], marks, notices)
	tool.begin_plan()
	tool.lay_ground(Vector2(0.0, 8.0))
	tool.lay_ground(Vector2(6.0, 14.0))
	assert_false(tool.confirm(), "refused")
	assert_equal(notices[-1], "Can't dig: the mole cannot reach that entrance", "why")
	assert_equal(marks[-1], [Vector3(0.0, 0.0, 8.0), false], "marked at the entrance")


# --- review and playtest fixes: rules, plan and network -------------------------------------

func test_a_point_on_top_of_the_last_is_refused() -> void:
	"""255u from the last point is refused as it is laid and in the whole route; 256u is a leg.
	(Zero-length legs drew a heap on the hole and turned the mole to yaw 0.)"""
	var plan := PlanScript.new()
	assert_equal(plan.try_add(0, 0, BOUNDS_U, PackedInt32Array()), Rules.REFUSE_NONE, "entrance")
	assert_equal(plan.try_add(255, 0, BOUNDS_U, PackedInt32Array()), Rules.REFUSE_REPEATED_POINT, "255u on")
	assert_equal(plan.count, 1, "not laid")
	assert_equal(plan.try_add(0, 0, BOUNDS_U, PackedInt32Array()), Rules.REFUSE_REPEATED_POINT, "the same point")
	assert_equal(plan.try_add(256, 0, BOUNDS_U, PackedInt32Array()), Rules.REFUSE_NONE, "256u on")
	var doubled := _route([Vector2i(0, 0), Vector2i(0, 0), Vector2i(3072, 0)])
	assert_equal(Rules.validate_route(doubled, 3, BOUNDS_U, PackedInt32Array()), Rules.REFUSE_REPEATED_POINT, "a doubled entrance")
	var close := _route([Vector2i(0, 0), Vector2i(3072, 0), Vector2i(3072, 255)])
	assert_equal(Rules.validate_route(close, 3, BOUNDS_U, PackedInt32Array()), Rules.REFUSE_REPEATED_POINT, "a doubled exit")


func test_a_leg_may_not_pass_within_half_a_bore_of_a_building() -> void:
	"""A 512u building circle: alongside a leg on z = 0 it must stay 1024u off (512 + half the bore);
	past either end the distance is to that end."""
	var leg := _route([Vector2i(-4096, 0), Vector2i(4096, 0)])
	assert_false(Rules.leg_under(leg, 1, PackedInt32Array([0, 512, 1024])), "1024u off: clear")
	assert_true(Rules.leg_under(leg, 1, PackedInt32Array([0, 512, 1023])), "1023u off: under")
	assert_true(Rules.leg_under(leg, 1, PackedInt32Array([0, 512, -1023])), "the other side")
	assert_false(Rules.leg_under(leg, 1, PackedInt32Array([5120, 512, 0])), "1024u past the end: clear")
	assert_true(Rules.leg_under(leg, 1, PackedInt32Array([5119, 512, 0])), "1023u past the end")
	assert_true(Rules.leg_under(leg, 1, PackedInt32Array([-5119, 512, 0])), "1023u before the start")
	assert_false(Rules.leg_under(leg, 1, PackedInt32Array()), "no buildings")
	var diagonal := _route([Vector2i(0, 0), Vector2i(3072, 4096)])
	assert_true(Rules.leg_under(diagonal, 1, PackedInt32Array([1536, 0, 2048])), "a building on a diagonal leg")
	assert_false(Rules.leg_under(diagonal, 1, PackedInt32Array([4096 + 1536, 0, 4096 - 2048])), "and well off it")


func test_mouths_keep_off_work_spots_and_other_mouths() -> void:
	"""A spot (x, keep, z) is kept clear like an obstacle: a mouth within keep + 512u is refused, at the
	entrance as it is laid and at either end of the whole route."""
	var spots := PackedInt32Array([0, 512, 0])
	assert_equal(Rules.validate_point(1023, 0, 0, BOUNDS_U, PackedInt32Array(), spots), Rules.REFUSE_ON_SPOT, "on the spot")
	assert_equal(Rules.validate_point(1024, 0, 0, BOUNDS_U, PackedInt32Array(), spots), Rules.REFUSE_NONE, "just clear")
	assert_equal(Rules.validate_point(0, 0, 1, BOUNDS_U, PackedInt32Array(), spots), Rules.REFUSE_NONE, "a bend may")
	var ends_on := _route([Vector2i(-5000, 0), Vector2i(0, 0)])
	assert_equal(Rules.validate_route(ends_on, 2, BOUNDS_U, PackedInt32Array(), spots), Rules.REFUSE_ON_SPOT, "an exit on it")
	var starts_on := _route([Vector2i(0, 0), Vector2i(5000, 0)])
	assert_equal(Rules.validate_route(starts_on, 2, BOUNDS_U, PackedInt32Array(), spots), Rules.REFUSE_ON_SPOT, "an entrance on it")


func test_a_tunnel_is_costed_with_its_legs_rounded_up() -> void:
	"""A leg of sqrt(2048^2 + 20^2) = 2048.098u is 2048u long but costs 2049u; a 3-4-5 leg is exact."""
	assert_equal(Rules.isqrt_ceil(16), 4, "a perfect square")
	assert_equal(Rules.isqrt_ceil(17), 5, "just over")
	assert_equal(Rules.isqrt_ceil(0), 0, "zero")
	var slant := _route([Vector2i(0, 0), Vector2i(2048, 20)])
	assert_equal(Rules.route_length_u(slant, 2), 2048, "floored length")
	assert_equal(Rules.route_cost_u(slant, 2), 2049, "ceiled cost")
	assert_equal(Rules.route_cost_u(_route([Vector2i(0, 0), Vector2i(3072, 4096)]), 2), 5120, "exact")
	var network := NetworkScript.new()
	var ref := PackedInt32Array([-1, 0])
	network.add_into(slant, 2, 0, ref)
	assert_equal(network.cost_u[0], 2049, "stored")


func test_a_tunnel_cannot_undercut_an_equal_walk_by_a_floored_sliver() -> void:
	"""Mouth to mouth, (0, 0) to (2048u, 20u): the walk is 2048.098u; the floored tunnel would be 2048u
	and win by 0.1 mm. Costed rounded up (2049u) it loses, and the walk is kept."""
	var space := _space([])
	var slot := _open_tunnel(space, [Vector2i(0, 0), Vector2i(2048, 20)])
	var index := space.add_resident(Vector2(-3.0, 5.0), BODY_M)
	space.tunnels.set_fit(index, true)
	var legs := PackedInt32Array()
	space.plan_path(index, space.tunnels.mouth(slot, false), space.tunnels.mouth(slot, true), BODY_M, PackedVector2Array(), legs)
	assert_equal(legs, PackedInt32Array([-1]), "walked, not tunnelled")


func test_an_unreached_dig_is_kept_paused_and_resumable() -> void:
	"""hold_unreached pauses a tunnel at 0% (reason UNREACHED) where stop_digging would free it; it
	resumes like any paused tunnel, and the reason clears."""
	var network := NetworkScript.new()
	var ref := PackedInt32Array([-1, 0])
	network.add_into(_route([Vector2i(0, 0), Vector2i(4096, 0)]), 2, 3, ref)
	network.hold_unreached(0, 1)
	assert_equal(network.phase[0], NetworkScript.PHASE_DIGGING, "a stale reference does nothing")
	network.hold_unreached(0, 0)
	assert_equal(network.phase[0], NetworkScript.PHASE_PAUSED, "kept, paused")
	assert_equal(network.pause_reason[0], NetworkScript.PAUSED_UNREACHED, "unreached")
	assert_equal(network.generation[0], 0, "the same tunnel")
	assert_true(network.resume(0, 0, 3), "resumable")
	assert_equal(network.pause_reason[0], 0, "no reason while digging")
	network.advance(0, 0, 1000000)
	network.stop_digging(0, 0)
	assert_equal(network.pause_reason[0], NetworkScript.PAUSED_CALLED_AWAY, "called away with ground broken")


# --- review and playtest fixes: the planner -------------------------------------------------

func test_of_two_equal_routes_fewer_tunnels_wins_whatever_the_search_order() -> void:
	"""The tie fixture again with the goal at (0, 9.5), where tunnels Y and Z both come up: Z alone
	(1 + 8.5 m) ties X then Y (1 + 3 + 5.5 m). The search reaches the two-tunnel route's label first,
	so only the (length, tunnels) order keeps Z."""
	var obstacles := _ring(Vector2(0.0, 10.0))
	for x in [-1.5, 0.0, 1.5]:
		obstacles.append(Vector3(x, 0.9, 2.5))
	var space := _space(obstacles)
	_open_tunnel(space, [Vector2i(0, 1024), Vector2i(0, 4096)])
	_open_tunnel(space, [Vector2i(0, 4096), Vector2i(0, 9728)])
	_open_tunnel(space, [Vector2i(0, 1024), Vector2i(0, 9728)])
	var index := space.add_resident(Vector2(0.0, 0.0), BODY_M)
	space.tunnels.set_fit(index, true)
	var legs := PackedInt32Array()
	space.plan_path(index, Vector2(0.0, 0.0), Vector2(0.0, 9.5), BODY_M, PackedVector2Array(), legs)
	assert_equal(legs, PackedInt32Array([-1, 4]), "tunnel Z alone, ending on its exit")


func test_a_goal_no_route_reaches_is_not_found_even_with_tunnels_open() -> void:
	"""A goal inside a closed pen, with two open tunnels elsewhere: no route, reported so."""
	var space := _space(_ring(Vector2(0.0, 10.0)))
	_open_tunnel(space, [Vector2i(-12288, -8192), Vector2i(-12288, -4096)])
	_open_tunnel(space, [Vector2i(12288, -8192), Vector2i(12288, -4096)])
	var index := space.add_resident(Vector2(0.0, -6.0), BODY_M)
	space.tunnels.set_fit(index, true)
	var path := PackedVector2Array()
	var legs := PackedInt32Array()
	space.plan_path(index, Vector2(0.0, -6.0), Vector2(0.0, 10.0), BODY_M, path, legs)
	assert_false(space.nav.last_found, "not found")
	assert_equal(legs.count(-1), legs.size(), "no tunnel leg")
	assert_equal(path[path.size() - 1], Vector2(0.0, 10.0), "the straight-line fallback")


func test_a_goal_on_a_mouth_is_reached_once() -> void:
	"""Ordered onto the tunnel's exit, the route ends there once -- no second waypoint on top of it to
	turn round for after coming up."""
	var space := _space(_wall())
	_open_tunnel(space, [Vector2i(0, -2048), Vector2i(0, 2048)])
	var index := space.add_resident(Vector2(0.0, -4.0), BODY_M)
	space.tunnels.set_fit(index, true)
	var path := PackedVector2Array()
	var legs := PackedInt32Array()
	space.plan_path(index, Vector2(0.0, -4.0), Vector2(0.0, 2.0), BODY_M, path, legs)
	assert_equal(path, PackedVector2Array([Vector2(0.0, -2.0), Vector2(0.0, 2.0)]), "entrance, exit")
	assert_equal(legs, PackedInt32Array([-1, 0]), "the exit reached through the tunnel")


func test_nobody_is_routed_through_a_tunnel_whose_mouth_someone_stands_on() -> void:
	"""Someone standing on the exit: the route goes round the wall instead. Standing just beyond reach
	(their radius + the walker's + the 0.18 m margin), the tunnel is used again."""
	var space := _space(_wall())
	_open_tunnel(space, [Vector2i(0, -2048), Vector2i(0, 2048)])
	var parked := space.add_resident(Vector2(0.0, 2.2), BODY_M)
	var index := space.add_resident(Vector2(0.0, -4.0), BODY_M)
	space.tunnels.set_fit(index, true)
	var legs := PackedInt32Array()
	space.plan_path(index, Vector2(0.0, -4.0), Vector2(0.0, 4.0), BODY_M, PackedVector2Array(), legs)
	assert_equal(legs.count(-1), legs.size(), "an occupied mouth: round the wall")
	space.move_resident(parked, Vector2(0.7, 2.0))
	space.plan_path(index, Vector2(0.0, -4.0), Vector2(0.0, 4.0), BODY_M, PackedVector2Array(), legs)
	assert_true(legs.has(0), "0.7 m off (reach 0.68 m): through the tunnel")
	space.move_resident(parked, Vector2(0.67, 2.0))
	space.plan_path(index, Vector2(0.0, -4.0), Vector2(0.0, 4.0), BODY_M, PackedVector2Array(), legs)
	assert_false(legs.has(0), "0.67 m off: round again")


func _eight_tunnels(space: CastSpaceScript) -> int:
	"""Eight open tunnels under the wall, 4 m apart; a fitting resident standing south of it."""
	for k in 8:
		var x := -16000 + k * 4000
		_open_tunnel(space, [Vector2i(x, -2048), Vector2i(x + 512, 2048)])
	var index := space.add_resident(Vector2(0.0, -12.0), BODY_M)
	space.tunnels.set_fit(index, true)
	return index


func test_mouth_to_mouth_routes_are_planned_once_per_revision() -> void:
	"""The second identical plan takes its mouth-to-mouth routes from the cache: fewer surface plans,
	the same route. A tunnel added (a new revision) plans them afresh."""
	var walls := _wall()
	for circle in _wall():
		walls.append(Vector3(circle.x, circle.y, 6.0))
	var space := _space(walls)
	_open_tunnel(space, [Vector2i(0, -2048), Vector2i(0, 2048)])
	_open_tunnel(space, [Vector2i(0, 4096), Vector2i(0, 8192)])
	var index := space.add_resident(Vector2(0.0, -4.0), BODY_M)
	space.tunnels.set_fit(index, true)
	var first := PackedVector2Array()
	var legs := PackedInt32Array()
	space.plan_path(index, Vector2(0.0, -4.0), Vector2(0.0, 10.0), BODY_M, first, legs)
	var cold := space.tunnels.router.last_surface_plans
	assert_equal(cold, 15, "cold: 15 surface plans")
	assert_equal(space.tunnels.router.last_cache_hits, 6, "6 of them mouth to mouth, planned into the cache and used")
	var second := PackedVector2Array()
	space.plan_path(index, Vector2(0.0, -4.0), Vector2(0.0, 10.0), BODY_M, second, legs)
	assert_equal(second, first, "the same route")
	assert_equal(legs, PackedInt32Array([-1, 0, -1, 2, -1]), "through both")
	assert_equal(space.tunnels.router.last_surface_plans, 9, "warm: the 6 mouth-to-mouth plans come from the cache")
	_open_tunnel(space, [Vector2i(15360, 15360), Vector2i(15360, 18432)])
	space.plan_path(index, Vector2(0.0, -4.0), Vector2(0.0, 10.0), BODY_M, second, legs)
	assert_true(space.tunnels.router.last_surface_plans >= cold, "a new revision plans the links again")


func test_a_cached_link_blocked_by_someone_standing_is_planned_round_them() -> void:
	"""Someone stands across the cached link between two tunnels (not on a mouth): the trip's route
	goes round them, and the cache keeps the clear route for the next walker."""
	var walls := _wall()
	for circle in _wall():
		walls.append(Vector3(circle.x, circle.y, 6.0))
	var space := _space(walls)
	_open_tunnel(space, [Vector2i(0, -2048), Vector2i(0, 2048)])
	_open_tunnel(space, [Vector2i(0, 4096), Vector2i(0, 8192)])
	var index := space.add_resident(Vector2(0.0, -4.0), BODY_M)
	space.tunnels.set_fit(index, true)
	var path := PackedVector2Array()
	var legs := PackedInt32Array()
	space.plan_path(index, Vector2(0.0, -4.0), Vector2(0.0, 10.0), BODY_M, path, legs)
	var clear_route := path.duplicate()
	var blocker := space.add_resident(Vector2(0.0, 3.0), 0.2)
	space.plan_path(index, Vector2(0.0, -4.0), Vector2(0.0, 10.0), BODY_M, path, legs)
	assert_equal(space.tunnels.router.last_cache_hits, 0, "the cached link is blocked")
	var at := Vector2(0.0, 2.0)
	var k := legs.find(0) + 1
	assert_equal(path[legs.find(2)], Vector2(0.0, 8.0), "still through both tunnels")
	while k < legs.find(2):
		assert_true(CastSpaceScript.distance_to_segment(Vector2(0.0, 3.0), at, path[k]) >= 0.45, "round the blocker")
		at = path[k]
		k += 1
	space.move_resident(blocker, Vector2(15.0, 15.0))
	space.plan_path(index, Vector2(0.0, -4.0), Vector2(0.0, 10.0), BODY_M, path, legs)
	assert_equal(space.tunnels.router.last_cache_hits, 1, "moved away, the cached link serves again")
	assert_equal(path, clear_route, "the clear link, not the detour planned round the blocker")


func test_eight_tunnels_plan_faster_once_the_links_are_cached() -> void:
	"""With eight open tunnels a cold plan runs every mouth-to-mouth plan it needs; the same trip
	planned again runs only start and goal edges."""
	var space := _space(_wall())
	var index := _eight_tunnels(space)
	var path := PackedVector2Array()
	var legs := PackedInt32Array()
	space.plan_path(index, Vector2(-15.0, -10.0), Vector2(15.0, 10.0), BODY_M, path, legs)
	var cold := space.tunnels.router.last_surface_plans
	var warm_path := PackedVector2Array()
	space.plan_path(index, Vector2(-15.0, -10.0), Vector2(15.0, 10.0), BODY_M, warm_path, legs)
	assert_equal(warm_path, path, "the same route")
	assert_true(space.tunnels.router.last_surface_plans < cold, "warm %d < cold %d surface plans" % [space.tunnels.router.last_surface_plans, cold])


# --- review and playtest fixes: residents in tunnels ----------------------------------------

func _to_underground(brain: BrainScript) -> void:
	"""Step `brain` until it is below (at most 10 s)."""
	var guard := 0
	while not brain.underground and guard < 600:
		brain.step(DT)
		guard += 1


func test_an_order_after_a_release_underground_is_carried_out() -> void:
	"""Released half way through a tunnel and then ordered on: the new order stands -- it comes up
	and goes on to it, instead of idling at the exit and dropping it."""
	var space := _space(_wall())
	_open_tunnel(space, [Vector2i(0, -2048), Vector2i(0, 2048)])
	var brain := _brain(space, Vector2(0.0, -4.0), true)
	brain.order_move(Vector2(0.0, 4.0))
	_to_underground(brain)
	_step(brain, 0.5)
	brain.release()
	brain.order_move(Vector2(4.0, 4.0))
	_step(brain, 20.0)
	assert_equal(brain.order, BrainScript.ORDER_MOVE, "still under the order")
	assert_equal(brain.state, BrainScript.State.HOLD, "holding")
	assert_true(brain.position.distance_to(Vector2(4.0, 4.0)) <= BrainScript.ARRIVE_RADIUS_M + 0.02,
		"at the new goal (%s)" % brain.position)


func test_released_mid_bore_and_resumed_while_backing_out_the_mole_finishes() -> void:
	"""The mole is released 1 m into its bore and, still backing out, sent back to dig: it walks back
	down to the face, digs, and the tunnel opens -- not stuck DIGGING with the mole holding."""
	var site := _dig_site()
	var space: CastSpaceScript = site[0]
	var mole: BrainScript = site[1]
	mole.order_dig(site[2], site[3])
	_dig_to(space, mole, site[2], 226)
	mole.release()
	assert_equal(space.tunnels.phase[site[2]], NetworkScript.PHASE_PAUSED, "paused")
	_step(mole, 0.2)
	assert_true(mole.underground, "still backing out")
	assert_true(space.tunnels.resume(site[2], site[3], mole.index), "resumed")
	mole.order_dig(site[2], site[3])
	_step(mole, 30.0)
	assert_true(space.tunnels.is_open(site[2]), "dug through")
	assert_equal(mole.dig_tunnel, -1, "done digging")
	assert_equal(mole.state, BrainScript.State.HOLD, "holding beyond the exit")


func test_released_underground_from_a_work_order_it_works_at_its_poi() -> void:
	"""Released half way to a POI through a tunnel, a worker keeps its slot and carries on to the POI
	to work its bout there -- as on the surface -- not at the mouth it came up at."""
	var points: Array[Dictionary] = [
		{"name": &"south", "position": Vector3(0.0, 0.0, -4.0), "face": Vector3.FORWARD, "activities": [&"collect_object"], "capacity": 1},
		{"name": &"north", "position": Vector3(0.0, 0.0, 4.0), "face": Vector3.BACK, "activities": [&"collect_object"], "capacity": 1}]
	var space := CastSpaceScript.new()
	space.setup(points, _wall())
	_open_tunnel(space, [Vector2i(0, -2048), Vector2i(0, 2048)])
	var brain := BrainScript.new()
	brain.configure(space, WALK_M_S, BODY_M, SEED, _lengths())
	space.tunnels.set_fit(brain.index, true)
	brain.start_at(Vector2(0.0, -3.0), 0.0, -1, -1)
	brain.order_work(1, 0)
	_to_underground(brain)
	brain.release()
	assert_equal(brain.poi, 1, "released below, it keeps its POI")
	var acted_at := Vector2.INF
	var idled_up := false
	for f in 60 * 12:
		brain.step(DT)
		idled_up = idled_up or (not brain.underground and brain.state == BrainScript.State.IDLE)
		if brain.state == BrainScript.State.ACT:
			acted_at = brain.position
			break
	assert_false(idled_up, "it never stopped to idle on the way")
	assert_equal(brain.poi, 1, "kept its POI")
	assert_equal(space.occupancy(1), 1, "and its slot")
	assert_true(acted_at.distance_to(space.slot_position(1, 0)) <= BrainScript.ARRIVE_RADIUS_M + 0.02,
		"worked at the POI (%s), not the exit" % acted_at)


func _dig_out_at(exit: Vector2i, obstacles: Array[Vector3], bounds: Rect2) -> BrainScript:
	"""A mole that digs a 3 m tunnel east to `exit` (u) among `obstacles` inside `bounds`, and has come up."""
	var space := _space(obstacles)
	space.bounds = bounds
	var mole := _brain(space, Vector2(float(exit.x) / 1024.0 - 5.0, float(exit.y) / 1024.0), true)
	var ref := PackedInt32Array([-1, 0])
	assert_true(space.tunnels.add_into(_route([exit - Vector2i(3072, 0), exit]), 2, mole.index, ref), "planned")
	mole.order_dig(ref[0], ref[1])
	_step(mole, 40.0)
	assert_true(space.tunnels.is_open(ref[0]), "dug")
	return mole


func test_a_mole_blocked_straight_on_steps_out_another_way() -> void:
	"""An obstacle a metre beyond the exit, reaching the diagonals too (0.77 m from them, under the
	0.37 m the mole needs): the mole steps out at the first clear turn, a right angle, to (0, 1),
	instead of holding on the hole."""
	var mole := _dig_out_at(Vector2i(0, 0), [Vector3(1.0, 0.4, 0.0)], Rect2(-20.0, -20.0, 40.0, 40.0))
	assert_true(mole.position.distance_to(Vector2(0.0, 1.0)) <= BrainScript.ARRIVE_RADIUS_M + 0.02,
		"stepped out to (0, 1) (%s)" % mole.position)
	assert_equal(mole.state, BrainScript.State.HOLD, "and holds there")


func test_a_mole_at_the_village_edge_steps_out_inside_it() -> void:
	"""The exit half a metre inside the east edge, facing out: the mole steps out inside the village,
	never past its edge."""
	var mole := _dig_out_at(Vector2i(19968, 0), [], Rect2(-20.0, -20.0, 40.0, 40.0))
	assert_true(mole.position.x <= 20.0 - mole.radius, "inside the edge (%s)" % mole.position)
	assert_true(mole.position.distance_to(Vector2(19.5, 0.0)) >= BrainScript.STEP_OUT_M - BrainScript.ARRIVE_RADIUS_M - 0.02,
		"and off the hole (%s)" % mole.position)


func test_called_away_walking_down_to_the_face_the_mole_backs_out() -> void:
	"""Resumed and walking down to its face, the mole is ordered elsewhere: the tunnel pauses again with
	nothing lost, and the mole backs up out of the entrance it went in by."""
	var site := _dig_site()
	var space: CastSpaceScript = site[0]
	var mole: BrainScript = site[1]
	mole.order_dig(site[2], site[3])
	_dig_to(space, mole, site[2], 226)
	mole.order_move(Vector2(-3.0, 3.0))
	_step(mole, 12.0)
	space.tunnels.resume(site[2], site[3], mole.index)
	mole.order_dig(site[2], site[3])
	var guard := 0
	while mole.state != BrainScript.State.TUNNEL and guard < 2000:
		mole.step(DT)
		guard += 1
	_step(mole, 0.3)
	mole.order_move(Vector2(-3.0, -3.0))
	assert_equal(space.tunnels.phase[site[2]], NetworkScript.PHASE_PAUSED, "paused again")
	assert_equal(_surfacing(mole, 600), Vector2(0.0, 0.0), "backed out of the entrance")
	assert_equal(space.tunnels.done(site[2]), 226, "nothing lost")


func test_a_tunnel_mouth_is_never_cut_even_in_open_ground() -> void:
	"""A route whose tunnel leg starts off to one side, in open ground where the exit is in plain sight:
	the walker still walks to the entrance and goes down there."""
	var space := _space([])
	_open_tunnel(space, [Vector2i(2048, -2048), Vector2i(2048, 2048)])
	var brain := _brain(space, Vector2(0.0, -4.0), true)
	brain.order_move(Vector2(0.0, 4.0))
	brain.path = PackedVector2Array([Vector2(2.0, -2.0), Vector2(2.0, 2.0), Vector2(0.0, 4.0)])
	brain.path_tunnel = PackedInt32Array([-1, 0, -1])
	brain._begin_leg()
	var seen := _watch_crossing(space, brain, 60 * 20)
	assert_true((seen["went_down_from"] as Vector2).distance_to(Vector2(2.0, -2.0)) < BrainScript.WAYPOINT_REACH_M,
		"went down at the entrance (from %s)" % seen["went_down_from"])


func test_a_carrier_s_replan_takes_only_a_bore_its_load_fits() -> void:
	"""A carrier's replan is planned WITH its load: a squirrel's log fits a standard bore, so it still
	goes through; the badger fits a wide bore unloaded but its load does not, so carrying it goes round
	(this replaced "a carrier's replan never takes a tunnel")."""
	var space := _space(_wall())
	var slot := _open_tunnel(space, [Vector2i(0, -2048), Vector2i(0, 2048)])
	var squirrel := _brain(space, Vector2(-1.0, -4.0), true)
	space.tunnels.set_body(squirrel.index, 1178, 259)
	squirrel.order_move(Vector2(-1.0, 4.0))
	squirrel.carrying = true
	squirrel._replan_or_abandon()
	assert_true(squirrel.crosses_tunnel(), "a squirrel's load fits the standard bore")
	space.tunnels.set_bore(slot, Rules.BORE_WIDE)
	var badger := _brain(space, Vector2(1.0, -4.0), true)
	space.tunnels.set_body(badger.index, 2611, 574)
	badger.order_move(Vector2(1.0, 4.0))
	assert_true(badger.crosses_tunnel(), "unloaded, the badger fits the wide bore")
	badger.carrying = true
	badger._replan_or_abandon()
	assert_false(badger.crosses_tunnel(), "carrying, the replan goes round")


func test_an_ordered_carry_hauls_by_the_same_rule() -> void:
	"""The farm's ordered carry (order_carry) goes by the routine's hauling rule: planned WITH its load,
	a squirrel carries through the standard bore under the wall; the badger, whose load no bore fits,
	carries round on the surface -- and neither drops the load for want of a tunnel."""
	var space := _space(_wall())
	var slot := _open_tunnel(space, [Vector2i(0, -2048), Vector2i(0, 2048)])
	var squirrel := _brain(space, Vector2(-1.0, -4.0), true)
	squirrel.set_carry_motion(_carry_motion())
	space.tunnels.set_body(squirrel.index, 1178, 259)
	squirrel.order_carry(Vector2(-1.0, 4.0))
	assert_true(squirrel.carrying, "the squirrel carries")
	assert_true(squirrel.crosses_tunnel(), "through the bore its load fits")
	space.tunnels.set_bore(slot, Rules.BORE_WIDE)
	var badger := _brain(space, Vector2(1.0, -4.0), true)
	badger.set_carry_motion(_carry_motion())
	space.tunnels.set_body(badger.index, 2611, 574)
	badger.order_move(Vector2(1.0, 4.0))
	assert_true(badger.crosses_tunnel(), "unloaded, the badger would take the wide bore")
	badger.order_carry(Vector2(1.0, 4.0))
	assert_true(badger.carrying, "loaded, it still carries")
	assert_false(badger.crosses_tunnel(), "but round, on the surface")


func _two_in_a_tunnel(second_from: Vector2, second_to: Vector2) -> Array:
	"""A 10 m open tunnel under a long wall; walker A from its south end north, walker B as given:
	[space, a, b]."""
	var wall: Array[Vector3] = []
	for k in 13:
		wall.append(Vector3(-9.0 + 1.5 * float(k), 0.9, 0.0))
	var space := _space(wall)
	_open_tunnel(space, [Vector2i(0, -5120), Vector2i(0, 5120)])
	var a := _brain(space, Vector2(0.0, -6.0), true)
	var b := _brain(space, second_from, true)
	a.order_move(Vector2(0.0, 7.0))
	b.order_move(second_to)
	return [space, a, b]


func test_two_walkers_one_way_down_a_bore_keep_their_distance() -> void:
	"""B, twice A's speed, follows A into the bore: underground it closes up but never nearer than
	their two radii plus the gap -- it follows, rather than walking through A."""
	var pair := _two_in_a_tunnel(Vector2(0.0, -7.0), Vector2(0.5, 7.5))
	var a: BrainScript = pair[1]
	var b: BrainScript = pair[2]
	b.walk_speed = 2.0 * WALK_M_S
	var closest := INF
	var together := 0
	for f in 60 * 30:
		a.step(DT)
		b.step(DT)
		if a.underground and b.underground:
			together += 1
			closest = minf(closest, a.position.distance_to(b.position))
	assert_true(together > 60, "both in the bore together (%d frames)" % together)
	assert_true(closest < 2.0 * BODY_M + BrainScript.BORE_GAP_M + 0.05, "B caught A up (%.3f)" % closest)
	assert_true(closest >= 2.0 * BODY_M + BrainScript.BORE_GAP_M - 0.01, "never closer than 0.65 m (%.3f)" % closest)
	assert_true(b.position.distance_to(Vector2(0.5, 7.5)) <= BrainScript.ARRIVE_RADIUS_M + 0.02, "and both came out (B at %s)" % b.position)


func test_two_walkers_meeting_in_a_bore_pass_side_by_side() -> void:
	"""A goes north as B comes south: each steps to its right, and they pass with their bodies apart
	(no more than a sliver of overlap), both coming out at the far end."""
	var pair := _two_in_a_tunnel(Vector2(0.0, 6.0), Vector2(0.0, -7.0))
	var a: BrainScript = pair[1]
	var b: BrainScript = pair[2]
	var closest := INF
	for f in 60 * 30:
		a.step(DT)
		b.step(DT)
		if a.underground and b.underground:
			closest = minf(closest, a.position.distance_to(b.position))
	assert_true(closest >= 2.0 * BrainScript.PASS_OFFSET_M - 0.02, "passed %.3f m apart" % closest)
	assert_true(a.position.distance_to(Vector2(0.0, 7.0)) <= BrainScript.ARRIVE_RADIUS_M + 0.02, "A through")
	assert_true(b.position.distance_to(Vector2(0.0, -7.0)) <= BrainScript.ARRIVE_RADIUS_M + 0.02, "B through")


func test_a_walker_waits_below_while_someone_stands_on_its_exit() -> void:
	"""Someone steps onto the exit after the walker went down: it waits below until they leave, then
	comes up -- never into them."""
	var space := _space(_wall())
	_open_tunnel(space, [Vector2i(0, -2048), Vector2i(0, 2048)])
	var brain := _brain(space, Vector2(0.0, -4.0), true)
	brain.order_move(Vector2(0.0, 4.0))
	_to_underground(brain)
	var parked := space.add_resident(Vector2(0.0, 2.0), BODY_M)
	_step(brain, 5.0)
	assert_true(brain.underground, "still below after 5 s")
	assert_true(brain.position.distance_to(Vector2(0.0, 2.0)) < 0.05, "waiting at the exit")
	space.move_resident(parked, Vector2(6.0, 6.0))
	_step(brain, 0.1)
	assert_false(brain.underground, "up once the hole is clear")


# --- review and playtest fixes: the tunnel tool ---------------------------------------------

func _digging_tool(notices: Array, marks: Array) -> ControlScript:
	"""The tool on the placeholder cast with the mole (actor 0) selected, digging a 8 m tunnel from
	(-4, 3) to (4, 3), 60 ticks in."""
	var cast := _cast_with_mole()
	var tool := _tool(cast, [PackedInt32Array([0])], marks, notices)
	tool.begin_plan()
	tool.lay_ground(Vector2(-4.0, 3.0))
	tool.lay_ground(Vector2(4.0, 3.0))
	assert_true(tool.confirm(), "digging")
	var mole := (cast.actor(0) as DemoActorScript).brain
	_dig_to(cast.space(), mole, mole.dig_tunnel, 60)
	assert_equal(tool.network.done(mole.dig_tunnel), 60, "60 ticks in")
	return tool


func _mole_of(tool: ControlScript) -> BrainScript:
	"""The mole the tool plans with (actor 0)."""
	return (tool._cast.actor(0) as DemoActorScript).brain


func test_right_clicking_the_entrance_being_dug_keeps_digging() -> void:
	"""With the mole digging, a right click on that tunnel's own entrance is taken and changes
	nothing: still digging, still its digger, a notice says so. (It used to pause the dig.)"""
	var notices := []
	var marks := []
	var tool := _digging_tool(notices, marks)
	var mole := _mole_of(tool)
	var slot := mole.dig_tunnel
	assert_true(tool.resume_at(Vector2(-4.0, 3.0)), "taken")
	assert_equal(tool.network.phase[slot], NetworkScript.PHASE_DIGGING, "still digging")
	assert_equal(mole.dig_tunnel, slot, "the same tunnel")
	assert_equal(mole.state, BrainScript.State.DIG, "the mole never stopped")
	assert_equal(notices[-1], "Already digging this tunnel (5%)", "said so")
	assert_equal(marks[-1], [Vector3(-4.0, 0.0, 3.0), true], "marked at its entrance")


func test_right_clicking_a_paused_entrance_while_digging_switches_tunnels() -> void:
	"""Tunnel A paused at 60 ticks, the mole digging B: a right click on A's entrance pauses B with its
	progress and sends the mole back to A."""
	var notices := []
	var tool := _digging_tool(notices, [])
	var mole := _mole_of(tool)
	var a := mole.dig_tunnel
	mole.order_move(Vector2(-8.0, -6.0))
	assert_equal(tool.network.phase[a], NetworkScript.PHASE_PAUSED, "A paused")
	_step(mole, 12.0)
	assert_true(tool.begin_plan(), "planning B")
	tool.lay_ground(Vector2(-8.0, -9.0))
	tool.lay_ground(Vector2(-3.0, -9.0))
	assert_true(tool.confirm(), "digging B")
	var b := mole.dig_tunnel
	_dig_to(tool._cast.space(), mole, b, 30)
	assert_true(tool.resume_at(Vector2(-4.2, 3.1)), "A's entrance")
	tool._process(DT)
	assert_equal(tool.network.phase[b], NetworkScript.PHASE_PAUSED, "B paused")
	assert_equal(tool.network.done(b), 30, "with its progress")
	assert_equal(tool.network.phase[a], NetworkScript.PHASE_DIGGING, "A resumed")
	assert_equal(tool.network.digger[a], mole.index, "by the mole")
	assert_equal(mole.dig_tunnel, a, "which is on its way to A")
	assert_equal(notices[-1], "Resuming the tunnel at 5%", "said so")


func test_a_right_click_resumes_only_near_an_entrance() -> void:
	"""A paused tunnel's entrance is taken within 1.1 m and not beyond; with no mole selected, never."""
	var notices := []
	var tool := _digging_tool(notices, [])
	var mole := _mole_of(tool)
	var slot := mole.dig_tunnel
	mole.order_move(Vector2(-8.0, -6.0))
	assert_equal(tool.entrance_near(Vector2(-4.0, 4.2)), -1, "1.2 m off")
	assert_false(tool.resume_at(Vector2(-4.0, 4.2)), "not taken 1.2 m off")
	assert_equal(tool.network.phase[slot], NetworkScript.PHASE_PAUSED, "still paused")
	assert_equal(tool.entrance_near(Vector2(-4.0, 4.1)), slot, "1.1 m off")
	tool._selection = func() -> PackedInt32Array: return PackedInt32Array([1])
	assert_false(tool.resume_at(Vector2(-4.0, 3.0)), "no mole selected")
	tool._selection = func() -> PackedInt32Array: return PackedInt32Array([0])
	assert_true(tool.resume_at(Vector2(-4.0, 4.1)), "taken at 1.1 m")
	assert_equal(tool.network.phase[slot], NetworkScript.PHASE_DIGGING, "resumed")


func test_right_click_digs_the_route_being_laid() -> void:
	"""While planning, a right press digs the route (the same as Enter), wherever the pointer is."""
	var cast := _cast_with_mole()
	var tool := _tool(cast, [PackedInt32Array([0])], [], [])
	tool.begin_plan()
	tool.lay_ground(Vector2(-4.0, 5.0))
	tool.lay_ground(Vector2(4.0, 5.0))
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	assert_true(tool.handle_input(right), "taken")
	assert_false(tool.planning, "done planning")
	assert_equal(tool.network.phase[0], NetworkScript.PHASE_DIGGING, "being dug")


func test_an_entrance_someone_stands_on_is_refused() -> void:
	"""Another resident standing on the entrance: refused, marked at the entrance, nothing stored."""
	var cast := _cast_with_mole()
	var marks := []
	var notices := []
	var tool := _tool(cast, [PackedInt32Array([0])], marks, notices)
	(cast.actor(1) as DemoActorScript).brain.start_at(Vector2(-4.0, 5.55), 0.0, -1, -1)
	tool.begin_plan()
	tool.lay_ground(Vector2(-4.0, 5.0))
	tool.lay_ground(Vector2(4.0, 5.0))
	assert_false(tool.confirm(), "refused")
	assert_equal(notices[-1], "Can't dig: someone is standing on that entrance", "0.55 m off, inside 0.22 + 0.22 + 0.18: why")
	assert_equal(marks[-1], [Vector3(-4.0, 0.0, 5.0), false], "marked at the entrance")
	assert_equal(tool.network.phase.count(NetworkScript.PHASE_FREE), 8, "nothing stored")
	(cast.actor(1) as DemoActorScript).brain.start_at(Vector2(-4.0, 6.0), 0.0, -1, -1)
	assert_true(tool.confirm(), "a step further off (0.25 + 0.22 + 0.18 < 1 m), accepted")


func test_the_notice_follows_the_tunnel() -> void:
	"""Called away mid-dig: the notice says it is paused, at what, and how to resume. Kept as a plan the
	mole could not reach: says so. Opened: says so."""
	var notices := []
	var tool := _digging_tool(notices, [])
	var mole := _mole_of(tool)
	var slot := mole.dig_tunnel
	mole.order_move(Vector2(-8.0, -6.0))
	tool._process(DT)
	assert_equal(notices[-1], "Tunnel paused at 5% — right-click its entrance with the mole to resume", "paused")
	var count := notices.size()
	tool._process(DT)
	assert_equal(notices.size(), count, "said once")
	tool.network.resume(slot, tool.network.generation[slot], mole.index)
	tool._process(DT)
	tool.network.hold_unreached(slot, tool.network.generation[slot])
	tool._process(DT)
	assert_equal(notices[-1], "The mole couldn't reach the entrance — tunnel paused at 5%; right-click its entrance with the mole to resume", "unreached")
	tool.network.resume(slot, tool.network.generation[slot], mole.index)
	tool.network.advance(slot, tool.network.generation[slot], 1000000000)
	tool._process(DT)
	assert_equal(notices[-1], ControlScript.DIG_OPEN, "open")


func test_u_twice_puts_back_the_notice_it_replaced() -> void:
	"""The underground view replaces the notice; switched off, the notice before it returns, not a
	bare 'Surface view'."""
	var notices := []
	var tool := _digging_tool(notices, [])
	var before: String = notices[-1]
	assert_true(tool.handle_input(_key(KEY_U)), "U")
	assert_equal(notices[-1], ControlScript.VIEW_ON, "the view says how to leave it")
	assert_true(tool.handle_input(_key(KEY_U)), "U again")
	assert_equal(notices[-1], before, "the dig's notice is back")


func test_the_panel_button_while_planning_cancels() -> void:
	"""The "Dig tunnel" button does what T does: starts a plan, and pressed again cancels it (it used to
	restart it, dropping the points)."""
	var cast := _cast_with_mole()
	var notices := []
	var tool := _tool(cast, [PackedInt32Array([0])], [], notices)
	assert_true(tool.toggle_plan(), "planning")
	tool.lay_ground(Vector2(-4.0, 5.0))
	assert_false(tool.toggle_plan(), "cancelled")
	assert_equal(notices[-1], ControlScript.PLAN_CANCELLED, "said so")
	assert_true(tool.toggle_plan(), "planning again")
	assert_equal(tool.plan.count, 0, "from nothing")


func test_the_route_status_counts_its_points_in_words() -> void:
	"""One point is "1 point"; two are "2 points"."""
	var cast := _cast_with_mole()
	var tool := _tool(cast, [PackedInt32Array([0])], [], [])
	tool.begin_plan()
	tool.lay_ground(Vector2(-4.0, 5.0))
	assert_equal(tool.plan_status(), "Tunnel: 1 point, 0.0 m -- click: add · Enter / right-click: dig · Backspace: undo · Esc: cancel", "one")
	tool.lay_ground(Vector2(4.0, 5.0))
	assert_true(tool.plan_status().begins_with("Tunnel: 2 points, 8.0 m"), "two")


func test_enter_while_planning_is_taken_before_the_hud() -> void:
	"""The command layer takes Enter ahead of the GUI while a route is laid (so no focused HUD button
	hears it), and digs; other keys, and Enter when not planning, are left to the GUI."""
	var cast := _cast_with_mole()
	var command := CommandScript.new()
	_nodes.append(command)
	var camera := Camera3D.new()
	_nodes.append(camera)
	command.configure(cast, camera, null)
	command.select(PackedInt32Array([0]))
	assert_false(command.take_before_gui(_key(KEY_ENTER)), "not planning: the GUI's")
	command.tunnels().begin_plan()
	command.tunnels().lay_ground(Vector2(-3.0, 3.0))
	command.tunnels().lay_ground(Vector2(3.0, 3.0))
	assert_false(command.take_before_gui(_key(KEY_A)), "another key: the GUI's")
	assert_true(command.take_before_gui(_key(KEY_KP_ENTER)), "Enter: taken")
	assert_false(command.tunnels().planning, "and dug")


func test_a_digging_mole_is_picked_by_its_mound() -> void:
	"""Underground in the surface view, a digging mole's pick proxy is its mound on the ground; a walker
	in a tunnel cannot be picked; in the underground view both are picked where drawn."""
	var site := _dig_site()
	var mole: BrainScript = site[1]
	mole.order_dig(site[2], site[3])
	_dig_to(site[0], mole, site[2], 226)
	var out := PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0])
	var foot := Vector3(1.0, mole.ground_y_m, 0.0)
	CommandScript.proxy_into(mole, foot, 0.9, false, Vector3(1.0, 44.0, 0.0), out)
	assert_equal(out, PackedFloat32Array([1.0, 0.0, 0.0, 0.6, 0.9]), "a 0.6 m capsule on the ground, the mound's 0.9 m at 44 m")
	CommandScript.proxy_into(mole, foot, 0.9, true, Vector3(1.0, 44.0, 0.0), out)
	assert_equal(out, PackedFloat32Array([1.0, mole.ground_y_m, 0.0, 0.9, BODY_M]), "underground view: its body")
	var space := _space(_wall())
	_open_tunnel(space, [Vector2i(0, -2048), Vector2i(0, 2048)])
	var walker := _brain(space, Vector2(0.0, -4.0), true)
	walker.order_move(Vector2(0.0, 4.0))
	_to_underground(walker)
	CommandScript.proxy_into(walker, Vector3(0.0, -1.0, 0.0), 1.0, false, Vector3.ZERO, out)
	assert_equal(out[4], 0.0, "a hidden walker has no proxy")
	var up := _brain(space, Vector2(5.0, 5.0), true)
	CommandScript.proxy_into(up, Vector3(5.0, 0.0, 5.0), 1.0, false, Vector3.ZERO, out)
	assert_equal(out, PackedFloat32Array([5.0, 0.0, 5.0, 1.0, BODY_M]), "on the surface: its body")


# --- review and playtest fixes: heaps, buildings and the world ------------------------------

func test_heaps_are_placed_off_work_spots_and_become_obstacles() -> void:
	"""A work spot exactly where the entrance heap would first go (right of the way out): the heap goes
	to the left instead, and both heaps become obstacles; freed, they are gone again."""
	var points: Array[Dictionary] = [{"name": &"spot", "position": Vector3(0.0, 0.0, -1.599), "face": Vector3.BACK,
		"activities": [&"idle"], "capacity": 1}]
	var space := CastSpaceScript.new()
	space.setup(points, [])
	var ref := PackedInt32Array([-1, 0])
	space.tunnels.add_into(_route([Vector2i(0, 0), Vector2i(4096, 0)]), 2, 0, ref)
	HeapsScript.place(space.tunnels, space, ref[0])
	var r := OverlayScript.heap_radius_m(10000)
	assert_true(absf(space.tunnels.heap_radius_m[0] - r) < 1e-5, "sized for 5 quanta's spoil")
	assert_true(space.tunnels.heap_at[0].distance_to(Vector2(0.0, 1.599)) < 0.01, "on the left (%s)" % space.tunnels.heap_at[0])
	assert_true(space.tunnels.heap_at[0].distance_to(space.slot_position(0, 0)) >= r + HeapsScript.SPOT_CLEAR_M, "clear of the spot")
	assert_equal(space.obstacles.size(), 2, "both heaps are obstacles")
	assert_equal(space.nav.circles.size(), 2, "and the planner has them")
	HeapsScript.clear(space.tunnels, space, ref[0])
	assert_equal(space.obstacles.size(), 0, "freed: gone")


func test_a_route_under_the_well_is_refused() -> void:
	"""With the demo village's buildings, a bend laid under the well is refused as it is laid, and so is
	a straight route under it on confirming."""
	var cast := _cast_with_mole()
	var notices := []
	var tool := _tool(cast, [PackedInt32Array([0])], [], notices)
	var world := DemoWorldScript.new()
	_nodes.append(world)
	tool.set_world(world)
	tool.begin_plan()
	assert_true(tool.lay_ground(Vector2(-5.0, 2.0)), "entrance west of the well")
	assert_false(tool.lay_ground(Vector2(5.0, 2.0)), "a leg within half a bore of the well's front circles")
	assert_equal(notices[-1], "Can't dig: a tunnel cannot pass under a building or the well", "why")
	assert_true(tool.lay_ground(Vector2(5.0, 3.5)), "a leg clear of them")
	tool.plan.points_u = _route([Vector2i(-5120, 2048), Vector2i(5120, 2048), Vector2i(0, 0), Vector2i(0, 0),
		Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0)])
	tool.plan.count = 2
	assert_false(tool.confirm(), "refused whole")
	assert_equal(notices[-1], "Can't dig: a tunnel cannot pass under a building or the well", "on confirming too")


func test_the_world_names_only_its_buildings_circles() -> void:
	"""building_obstacles() is the buildings' and the well's circles, a strict part of obstacles(), with
	the well's round (0, 0)."""
	var world := DemoWorldScript.new()
	_nodes.append(world)
	var all := world.obstacles()
	var buildings := world.building_obstacles()
	assert_equal(buildings.size(), 94, "the nine buildings' 94 circles")
	# 192: the water (demo/water/) keeps trees and logs out of the stream and off its banks.
	assert_equal(all.size(), 192, "of 192 in all")
	for circle in buildings:
		assert_true(Vector2(circle.x, circle.z).distance_to(Vector2(2.3529, 0.8968)) > 0.3, "the bucket beside the well is not a building")
	for circle in buildings:
		assert_true(all.has(circle), "a building circle is an obstacle")
	var near_well := 0
	for circle in buildings:
		near_well += 1 if Vector2(circle.x, circle.z).length() < 1.5 else 0
	assert_equal(near_well, 4, "the well's four circles")


func test_the_cover_is_cleared_from_a_tunnel_s_ground() -> void:
	"""Hiding the cover along a route and round circles hides exactly the pieces that stand there."""
	var world := DemoWorldScript.new()
	_nodes.append(world)
	world.build({"world": {}, "cast": {}})
	var route := PackedVector2Array([Vector2(-18.0, -18.0), Vector2(18.0, 18.0)])
	var centre := Vector2.INF
	for p in world.cover_positions(0):
		if centre == Vector2.INF and CastSpaceScript.distance_to_segment(p, route[0], route[1]) > 5.0:
			centre = p
	var circles := PackedVector3Array([Vector3(centre.x, 2.0, centre.y)])
	var hidden := world.hide_cover(route, 1.0, circles)
	assert_true(hidden > 0, "some cover stood there (%d)" % hidden)
	var counted := 0
	var in_circle := 0
	var wrong := 0
	var margin := DemoWorldScript.COVER_MARGIN_M
	for k in DemoWorldScript.MULTIMESH_KEYS.size():
		var positions := world.cover_positions(k)
		for i in positions.size():
			var p := positions[i]
			var by_circle := p.distance_to(centre) < 2.0 + margin
			var on := by_circle or CastSpaceScript.distance_to_segment(p, route[0], route[1]) < 1.0 + margin
			wrong += 0 if (world.cover_hidden(k)[i] == 1) == on else 1
			counted += 1 if on else 0
			in_circle += 1 if by_circle else 0
	assert_true(in_circle > 0, "some cover stood in the circle (%d)" % in_circle)
	assert_equal(wrong, 0, "hidden exactly where the ground is cleared")
	assert_equal(counted, hidden, "every hidden piece counted")
	assert_equal(world.hide_cover(route, 1.0, circles), 0, "hidden once")


# --- review and playtest fixes: drawing -----------------------------------------------------

func _overlay_on(space: CastSpaceScript) -> OverlayScript:
	"""An overlay drawing `space`'s tunnels."""
	var overlay := OverlayScript.new()
	_nodes.append(overlay)
	overlay.configure(space.tunnels, space, DemoClockScript.new())
	return overlay


func test_the_trough_is_rebuilt_per_quarter_metre_not_per_tick() -> void:
	"""Digging the 2 m bore tick by tick (226 ticks) rebuilds the trough once per 0.25 m the face
	crosses -- 9 times, not 226 -- and each build holds the dug length: 9 rings of the half-round and
	its face wall (a fan from the bore's axis)."""
	var site := _dig_site()
	var space: CastSpaceScript = site[0]
	var mole: BrainScript = site[1]
	var overlay := _overlay_on(space)
	mole.order_dig(site[2], site[3])
	_dig_to(space, mole, site[2], 113)
	overlay.refresh()
	var builds := overlay.bore_builds
	var ticks := 0
	while space.tunnels.done(site[2]) < 339 and ticks < 60 * 30:
		mole.step(DT)
		overlay.refresh()
		ticks += 1
	assert_true(ticks > 200, "stepped through the bore (%d frames)" % ticks)
	assert_equal(overlay.bore_builds - builds, 8, "8 rebuilds over the 2 m bore, one per 0.25 m")
	var arrays := (overlay.bore(site[2]).mesh as ArrayMesh).surface_get_arrays(0)
	assert_equal((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), 9 * (OverlayScript.BORE_SIDES + 1)
		+ OverlayScript.BORE_SIDES + 2, "2 m in 8 steps: 9 rings, and the face wall's axis and rim")
	assert_equal((arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size(), 8 * OverlayScript.BORE_SIDES * 6
		+ OverlayScript.BORE_SIDES * 3, "8 steps of quads, and the face wall's fan")
	assert_equal((arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array).size(), (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(),
		"lit: a normal a vertex")


func test_the_ribbon_is_rebuilt_only_as_the_face_moves_a_step() -> void:
	"""The ribbon's key moves when the face crosses 0.25 m (or the phase changes) and not on a tick
	within a step -- nor when the view switches (decision 0206: a switch rebuilds nothing)."""
	var site := _dig_site()
	var space: CastSpaceScript = site[0]
	var overlay := _overlay_on(space)
	var tunnels := space.tunnels
	tunnels.advance(site[2], site[3], 5000000)
	var key := overlay.mesh_key(site[2])
	tunnels.advance(site[2], site[3], 33334)
	assert_equal(overlay.mesh_key(site[2]), key, "a tick within the step")
	tunnels.advance(site[2], site[3], 1000000)
	assert_true(overlay.mesh_key(site[2]) != key, "the face moved on a step")
	key = overlay.mesh_key(site[2])
	tunnels.stop_digging(site[2], site[3])
	assert_true(overlay.mesh_key(site[2]) != key, "paused")


func test_heaps_stand_where_they_were_placed() -> void:
	"""A tunnel whose heaps were placed draws them there, at their current size."""
	var space := _space([])
	var ref := PackedInt32Array([-1, 0])
	space.tunnels.add_into(_route([Vector2i(0, 0), Vector2i(4096, 0)]), 2, 0, ref)
	HeapsScript.place(space.tunnels, space, ref[0])
	space.tunnels.advance(ref[0], ref[1], 1000000000)
	var overlay := _overlay_on(space)
	overlay.refresh()
	for end in 2:
		var at := space.tunnels.heap_at[end]
		assert_equal(overlay.heap(ref[0], end == 1).position, Vector3(at.x, 0.0, at.y), "heap %d where placed" % end)
	assert_almost_equal(overlay.heap(ref[0], false).scale.x, OverlayScript.heap_radius_m(10000), "the finished entrance heap")
	assert_almost_equal(overlay.heap(ref[0], false).scale.x, space.tunnels.heap_radius_m[0], "its placed size")


func test_the_ribbon_stops_at_each_hole() -> void:
	"""An open tunnel's trace starts and ends at the holes' edges: no part of it lies in a hole."""
	var space := _space([])
	var slot := _open_tunnel(space, [Vector2i(0, 0), Vector2i(4096, 0)])
	var overlay := _overlay_on(space)
	overlay.refresh()
	var vertices := (overlay.ribbon(slot).mesh as ImmediateMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var lo := INF
	var hi := -INF
	for v in vertices:
		lo = minf(lo, v.x)
		hi = maxf(hi, v.x)
	assert_true(vertices.size() > 0, "a trace")
	assert_almost_equal(lo, OverlayScript.HOLE_RADIUS_M, "it starts at the entrance hole's edge")
	assert_almost_equal(hi, 4.0 - OverlayScript.HOLE_RADIUS_M, "and ends at the exit hole's edge")


func test_a_paused_tunnel_is_marked_at_its_entrance() -> void:
	"""A clay ring round a paused tunnel's entrance; none while it is dug or once it is open."""
	var site := _dig_site()
	var space: CastSpaceScript = site[0]
	var overlay := _overlay_on(space)
	space.tunnels.advance(site[2], site[3], 2000000)
	overlay.refresh()
	assert_false(overlay.pause_ring(site[2]).visible, "digging: no ring")
	space.tunnels.stop_digging(site[2], site[3])
	overlay.refresh()
	assert_true(overlay.pause_ring(site[2]).visible, "paused: a ring")
	assert_equal(overlay.pause_ring(site[2]).position, Vector3(0.0, MarksScript.LIFT_M, 0.0), "at the entrance")
	space.tunnels.resume(site[2], site[3], 0)
	space.tunnels.advance(site[2], site[3], 1000000000)
	overlay.refresh()
	assert_false(overlay.pause_ring(site[2]).visible, "open: no ring")


func test_the_route_being_laid_is_drawn_over_everything() -> void:
	"""Under a roof the route must read: its ribbon, rings and label ignore the depth buffer."""
	var space := _space([])
	var overlay := _overlay_on(space)
	var plan := PlanScript.new()
	plan.try_add(0, 0, BOUNDS_U, PackedInt32Array())
	plan.try_add(4096, 0, BOUNDS_U, PackedInt32Array())
	overlay.show_plan(plan, Vector2(4.0, 3.0), true)
	var mesh := overlay.plan_ribbon().mesh as ImmediateMesh
	for surface in mesh.get_surface_count():
		assert_true((mesh.surface_get_material(surface) as StandardMaterial3D).no_depth_test, "ribbon part %d on top" % surface)
	assert_true(overlay.plan_label().no_depth_test, "the label on top")
	for ring in overlay.find_children("*", "MeshInstance3D", false, false):
		if ring.visible and ring.mesh == MarksScript.ring_mesh():
			assert_true((ring.material_override as StandardMaterial3D).no_depth_test, "a point's ring on top")


func test_the_mound_grows_as_the_camera_pulls_back() -> void:
	"""Drawn at its size up to 22 m, scaled with distance beyond, at most 2.5x."""
	assert_almost_equal(OverlayScript.mound_scale(0.0), 1.0, "close")
	assert_almost_equal(OverlayScript.mound_scale(22.0), 1.0, "the default distance")
	assert_almost_equal(OverlayScript.mound_scale(44.0), 2.0, "twice as far")
	assert_almost_equal(OverlayScript.mound_scale(70.0), 2.5, "zoomed right out")


func test_a_view_switch_writes_nothing_but_the_camera_mask() -> void:
	"""Decision 0206: with a world, a tool, an open tunnel and a resident in it, U on and U off -- and a
	frame of every drawing's own work after each -- leave every drawn node's transparency, material,
	visibility and layers, and every material's transparency, exactly as they were; only the camera's
	cull mask moves. The resident below is on the underground layer, the one above on the surface."""
	var world := DemoWorldScript.new()
	_nodes.append(world)
	world.build({"world": {}, "cast": {}})
	var cast := _cast_with_mole()
	var space := cast.space()
	var slot := _open_tunnel(space, [Vector2i(-4096, 8192), Vector2i(4096, 8192)])
	var below := cast.actor(2) as DemoActorScript
	below.brain.order_move(Vector2(0.0, 8.0))
	below.brain._start_travel(0, 0.0, 8.0)
	var tool := _tool(cast, [PackedInt32Array()], [], [])
	tool.set_world(world)
	var camera := tool.view._camera
	_frame_of(cast, tool)
	assert_true(below.brain.underground and tool.overlay.bore(slot).visible, "a resident in a dug bore")
	assert_equal(below.layers_now(), Layers.UNDERGROUND, "the resident below on the underground layer")
	assert_equal((cast.actor(1) as DemoActorScript).layers_now(), Layers.SURFACE, "one above on the surface")
	var before := _snapshot([world, cast, tool])
	assert_true(before.size() > 100, "a village's worth of drawn nodes (%d)" % before.size())
	for on: bool in [true, false]:
		assert_true(tool.handle_input(_key(KEY_U)), "U")
		_frame_of(cast, tool)
		assert_equal(camera.cull_mask, Layers.view_mask(on), "the mask moved")
		assert_equal(_snapshot([world, cast, tool]), before, "nothing else did (view %s)" % on)


func _frame_of(cast: DemoCastScript, tool: ControlScript) -> void:
	"""One frame of the cast's, the overlay's and the tunnel works' own per-frame work (out of the tree)."""
	cast.advance(DT)
	tool.overlay.refresh()
	tool.ext._process(DT)
	tool._process(DT)


func _snapshot(roots: Array) -> Dictionary:
	"""Every drawn node under `roots`: its path, transparency, material, visibility and layers, and its
	materials' transparency (what a fade or a swap would change)."""
	var out := {}
	for root: Node in roots:
		for node: Node in [root] + root.find_children("*", "GeometryInstance3D", true, false):
			var geometry := node as GeometryInstance3D
			if geometry == null:
				continue
			var material := geometry.material_override as BaseMaterial3D
			out[geometry.get_instance_id()] = [geometry.transparency, geometry.material_override, geometry.visible,
				geometry.layers, material.transparency if material != null else -1]
	return out


# --- review and playtest fixes: the panel ---------------------------------------------------

func _built_panel() -> PanelScript:
	"""The party panel, its widgets built (out of the tree)."""
	var panel := PanelScript.new()
	_nodes.append(panel)
	panel.show_notice("Tunnel: click where the entrance opens")
	panel.build()
	return panel


func test_the_panel_s_button_and_notice_wear_their_colours() -> void:
	"""The built button's text is the cream readable on wood (ink on brass pressed); the notice is ink
	on parchment; each clears 4.5:1."""
	var panel := _built_panel()
	var button := panel.dig_button()
	var wood := PackedColorArray([Palette.face_dark(Palette.SURFACE_WOOD), Palette.face_light(Palette.SURFACE_WOOD)])
	var parchment := PackedColorArray([Palette.face_dark(Palette.SURFACE_PARCHMENT), Palette.face_light(Palette.SURFACE_PARCHMENT)])
	assert_equal(button.get_theme_color(&"font_color"), Palette.text_on(Palette.SURFACE_WOOD), "cream on wood")
	assert_equal(button.get_theme_color(&"font_hover_color"), Palette.text_on(Palette.SURFACE_WOOD), "hovered too")
	assert_equal(button.get_theme_color(&"font_pressed_color"), Palette.text_on(Palette.SURFACE_BRASS), "pressed on brass")
	assert_true(Contrast.worst_ratio(button.get_theme_color(&"font_color"), wood) >= Contrast.BODY_MINIMUM, "readable")
	var ink := panel.notice_label().get_theme_color(&"font_color")
	assert_equal(ink, Palette.INK, "the notice in ink")
	assert_true(Contrast.worst_ratio(ink, parchment) >= Contrast.BODY_MINIMUM, "readable")


func test_a_notice_given_before_the_panel_is_built_shows_once_it_is() -> void:
	"""The waiting notice is on its label, and shown, as soon as the panel builds."""
	var panel := _built_panel()
	assert_equal(panel.notice_label().text, "Tunnel: click where the entrance opens", "shown")
	assert_true(panel.notice_label().visible, "visible")


func test_the_dig_button_shows_only_with_a_mole_in_the_party() -> void:
	"""A party with a digger shows the button; one without, or nobody, hides it."""
	var panel := _built_panel()
	var mole: Array[Dictionary] = [{"name": "Mole digger", "species": "Mole", "state": "wandering", "digger": true}]
	var mice: Array[Dictionary] = [{"name": "Mouse keeper", "species": "Mouse", "state": "wandering", "digger": false}]
	panel.show_party(mole)
	assert_true(panel.dig_button().visible, "with the mole")
	panel.show_party(mice)
	assert_false(panel.dig_button().visible, "with mice only")
	panel.show_party([])
	assert_false(panel.dig_button().visible, "with nobody")


# --- review fixes: orders measured from the surface -----------------------------------------

func _worker_below_and_one_above() -> Array:
	"""A POI north of the wall (0, 4) with one slot; A inside the tunnel at (0, 1) walking SOUTH (it
	comes up at (0, -2), 6 m from the POI though now 3 m under it); B on the surface 3.08 m off:
	[space, a, b]."""
	var points: Array[Dictionary] = [{"name": &"north", "position": Vector3(0.0, 0.0, 4.0), "face": Vector3.BACK,
		"activities": [&"collect_object"], "capacity": 1}]
	var space := CastSpaceScript.new()
	space.setup(points, _wall())
	_open_tunnel(space, [Vector2i(0, -2048), Vector2i(0, 2048)])
	var a := BrainScript.new()
	a.configure(space, WALK_M_S, BODY_M, SEED, _lengths())
	space.tunnels.set_fit(a.index, true)
	a.start_at(Vector2(0.0, 2.2), PI, -1, -1)
	a.order_move(Vector2(0.0, -4.0))
	_to_underground(a)
	_step(a, 1.0)
	var b := _brain(space, Vector2(2.5, 5.8), true)
	return [space, a, b]


func test_a_work_order_ranks_residents_by_where_they_stand_on_the_surface() -> void:
	"""One slot, two residents: the one in the tunnel is nearer by its place underground, but comes up
	6 m away; the one on the surface, 3.08 m away, gets the slot."""
	var trio := _worker_below_and_one_above()
	var a: BrainScript = trio[1]
	var b: BrainScript = trio[2]
	assert_true(a.underground and a.position.distance_to(Vector2(0.0, 4.0)) < 3.08, "A is under the POI")
	var members: Array[BrainScript] = [a, b]
	CastOrdersScript.order_work(trio[0], members, 0, Rect2(-20.0, -20.0, 40.0, 40.0))
	assert_equal(b.poi, 0, "B, nearer on the surface, works the slot")
	assert_equal(a.poi, -1, "A holds behind")


func test_overflow_with_nowhere_to_queue_holds_where_it_comes_up() -> void:
	"""With no room for a queue, the overflow holds where it stands -- for one in a tunnel, at the mouth
	it comes up at, never at its place underground."""
	var trio := _worker_below_and_one_above()
	var a: BrainScript = trio[1]
	var b: BrainScript = trio[2]
	var members: Array[BrainScript] = [a, b]
	CastOrdersScript.order_work(trio[0], members, 0, Rect2(30.0, 30.0, 2.0, 2.0))
	assert_equal(a.goal(), Vector2(0.0, -2.0), "A holds at the exit it comes up at")


# --- review and playtest fixes: the rest ----------------------------------------------------

func test_a_formation_never_stands_anyone_in_a_hole() -> void:
	"""Ordered onto a tunnel's exit, three residents stand round it, every one clear of its rim."""
	var space := _space([])
	var slot := _open_tunnel(space, [Vector2i(-4096, 0), Vector2i(0, 0)])
	var members: Array[BrainScript] = []
	for k in 3:
		members.append(_brain(space, Vector2(4.0 + float(k), 4.0), false))
	var spots := CastOrdersScript.order_move(space, members, Vector2(0.0, 0.0), Rect2(-20.0, -20.0, 40.0, 40.0))
	assert_equal(spots.size(), 3, "three spots")
	for spot in spots:
		var off := spot.distance_to(space.tunnels.mouth(slot, true))
		assert_true(off >= Rules.HOLE_RADIUS_M * Rules.RIM_FACTOR + BODY_M, "clear of the hole (%.2f m)" % off)


func test_one_walker_after_another_both_come_through() -> void:
	"""A walks the tunnel and comes out; then B walks it the same way: A's place in the bore went with
	it, so B is not held behind a walker who is no longer there."""
	var space := _space(_wall())
	_open_tunnel(space, [Vector2i(0, -2048), Vector2i(0, 2048)])
	var a := _brain(space, Vector2(0.0, -4.0), true)
	a.order_move(Vector2(2.0, 4.0))
	_step(a, 12.0)
	var b := _brain(space, Vector2(0.0, -4.0), true)
	b.order_move(Vector2(-2.0, 4.0))
	_step(b, 12.0)
	assert_true(b.position.distance_to(Vector2(-2.0, 4.0)) <= BrainScript.ARRIVE_RADIUS_M + 0.02, "B through (%s)" % b.position)


func test_a_mole_never_steps_out_into_a_hole_or_onto_someone() -> void:
	"""Straight on out of the exit lies another tunnel's entrance, whose rim also reaches both
	diagonals; at the left-hand right angle someone stands: the mole steps out at the other, to
	(0, -1)."""
	var space := _space([])
	space.bounds = Rect2(-20.0, -20.0, 40.0, 40.0)
	var ref := PackedInt32Array([-1, 0])
	space.tunnels.add_into(_route([Vector2i(1024, 0), Vector2i(1024, 4096)]), 2, 5, ref)
	var mole := _brain(space, Vector2(-5.0, 0.0), true)
	var by := space.add_resident(Vector2(0.0, 1.0), BODY_M)
	var dig := PackedInt32Array([-1, 0])
	space.tunnels.add_into(_route([Vector2i(-3072, 0), Vector2i(0, 0)]), 2, mole.index, dig)
	mole.order_dig(dig[0], dig[1])
	_step(mole, 40.0)
	assert_true(space.tunnels.is_open(dig[0]), "dug")
	assert_true(mole.goal().distance_to(Vector2(0.0, -1.0)) < 1e-5, "sent to (0, -1) (%s)" % mole.goal())
	assert_true(mole.position.distance_to(Vector2(0.0, -1.0)) <= BrainScript.ARRIVE_RADIUS_M + 0.02,
		"and there (%s)" % mole.position)
	assert_true(space.resident_position[by].distance_to(Vector2(0.0, 1.0)) < 0.01, "the bystander stayed put")


func test_the_wait_below_an_occupied_exit_is_bounded() -> void:
	"""Someone parked on the exit for good: the walker waits 6 s below, then comes up anyway."""
	var space := _space(_wall())
	_open_tunnel(space, [Vector2i(0, -2048), Vector2i(0, 2048)])
	var brain := _brain(space, Vector2(0.0, -4.0), true)
	brain.order_move(Vector2(0.0, 4.0))
	_to_underground(brain)
	space.add_resident(Vector2(0.0, 2.0), BODY_M)
	var below := 0
	for f in 60 * 20:
		brain.step(DT)
		below += 1 if brain.underground else 0
	assert_false(brain.underground, "up in the end")
	assert_true(below >= 4 * 60 + 6 * 60 - 5 and below <= 4 * 60 + 6 * 60 + 5, "4 s walking and 6 s waiting below (%d frames)" % below)


func test_an_entrance_blocked_by_someone_standing_is_unreachable() -> void:
	"""The entrance lies in a pen whose one gap a resident stands in: the mole cannot walk to it, so the
	dig is refused, marked at the entrance."""
	var pen := _ring(Vector2(0.0, 8.0))
	pen.remove_at(9)
	var cast := DemoCastScript.new()
	_nodes.append(cast)
	var points: Array[Dictionary] = []
	cast.build({}, points, pen)
	cast.set_bounds(AABB(Vector3(-20.0, 0.0, -20.0), Vector3(40.0, 4.0, 40.0)))
	(cast.actor(0) as DemoActorScript).species = "Mole"
	var marks := []
	var notices := []
	var tool := _tool(cast, [PackedInt32Array([0])], marks, notices)
	var blocker := (cast.actor(1) as DemoActorScript).brain
	blocker.start_at(Vector2(0.0, 5.3), 0.0, -1, -1)
	tool.begin_plan()
	tool.lay_ground(Vector2(0.0, 8.0))
	tool.lay_ground(Vector2(0.0, 14.0))
	assert_false(tool.confirm(), "someone in the gap: refused")
	assert_equal(notices[-1], "Can't dig: the mole cannot reach that entrance", "why")
	assert_equal(marks[-1], [Vector3(0.0, 0.0, 8.0), false], "marked at the entrance")
	blocker.start_at(Vector2(-6.0, 0.0), 0.0, -1, -1)
	assert_true(tool.confirm(), "the gap clear: reachable, accepted")


func test_a_dig_called_off_before_ground_is_broken_takes_its_heaps_with_it() -> void:
	"""Re-ordered before digging, the freed tunnel's heaps stop being obstacles, and the notice says
	the dig was called off."""
	var cast := _cast_with_mole()
	var notices := []
	var tool := _tool(cast, [PackedInt32Array([0])], [], notices)
	tool.begin_plan()
	tool.lay_ground(Vector2(-4.0, 5.0))
	tool.lay_ground(Vector2(4.0, 5.0))
	assert_true(tool.confirm(), "digging")
	assert_equal(cast.space().obstacles.size(), 3, "the circle and two heaps")
	_mole_of(tool).order_move(Vector2(-8.0, -6.0))
	tool._process(DT)
	assert_equal(tool.network.phase[0], NetworkScript.PHASE_FREE, "freed")
	assert_equal(cast.space().obstacles.size(), 1, "the heaps are gone")
	assert_equal(notices[-1], ControlScript.DIG_DROPPED, "said so")


func test_a_pause_that_changes_its_reason_within_a_frame_is_announced() -> void:
	"""Paused, resumed and left unreached before the tool looks again: still said, as unreached."""
	var notices := []
	var tool := _digging_tool(notices, [])
	var mole := _mole_of(tool)
	var slot := mole.dig_tunnel
	mole.order_move(Vector2(-8.0, -6.0))
	tool._process(DT)
	tool.network.resume(slot, tool.network.generation[slot], mole.index)
	tool.network.hold_unreached(slot, tool.network.generation[slot])
	tool._process(DT)
	assert_equal(notices[-1], "The mole couldn't reach the entrance — tunnel paused at 5%; right-click its entrance with the mole to resume", "unreached")


func test_the_panel_s_dig_button_while_planning_cancels_through_the_command_layer() -> void:
	"""The panel's button signal reaches the tool as a toggle: pressed while planning, it cancels."""
	var cast := _cast_with_mole()
	var command := CommandScript.new()
	_nodes.append(command)
	var camera := Camera3D.new()
	_nodes.append(camera)
	command.configure(cast, camera, null)
	command.select(PackedInt32Array([0]))
	command.panel().dig_requested.emit()
	assert_true(command.tunnels().planning, "planning")
	command.tunnels().lay_ground(Vector2(-3.0, 3.0))
	command.panel().dig_requested.emit()
	assert_false(command.tunnels().planning, "cancelled")


func test_a_heap_shows_as_its_first_spoil_posts() -> void:
	"""75 ticks into the entrance shaft its first 2000 milli-U post: the heap shows at once, though
	the dig face has not moved."""
	var site := _dig_site()
	var space: CastSpaceScript = site[0]
	var overlay := _overlay_on(space)
	space.tunnels.advance(site[2], site[3], 2466667)
	overlay.refresh()
	assert_equal(space.tunnels.done(site[2]), 74, "74 ticks")
	assert_false(overlay.heap(site[2], false).visible, "no spoil yet")
	space.tunnels.advance(site[2], site[3], 33334)
	overlay.refresh()
	assert_equal(space.tunnels.done(site[2]), 75, "75 ticks")
	assert_true(overlay.heap(site[2], false).visible, "the first spoil heaped")
	assert_almost_equal(overlay.heap(site[2], false).scale.x, OverlayScript.heap_radius_m(2000), "one quantum's")
