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


func test_a_route_may_bend_under_a_building_and_is_capped_at_64_m() -> void:
	"""A bend inside an obstacle is fine; 65536u of route is allowed, 65537u is not."""
	var circles := PackedInt32Array([0, 1024, 0])
	var under := _route([Vector2i(-5000, 0), Vector2i(0, 0), Vector2i(5000, 0)])
	assert_equal(Rules.validate_route(under, 3, BOUNDS_U, circles), Rules.REFUSE_NONE, "bends under")
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
	assert_equal(Rules.REASONS.size(), 12, "twelve codes")
	assert_equal(Rules.reason_text(Rules.REFUSE_NONE), "", "no reason")
	assert_equal(Rules.reason_text(Rules.REFUSE_NOT_A_DIGGER), "only a mole can dig tunnels -- select the mole", "not a mole")
	for code in range(1, 12):
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
	"""Rounded to the nearest tenth."""
	assert_equal(PlanScript.length_text(12698), "12.4 m", "12.400 m")
	assert_equal(PlanScript.length_text(1024), "1.0 m", "one metre")
	assert_equal(PlanScript.length_text(0), "0.0 m", "nothing")
	assert_equal(PlanScript.length_text(1075), "1.0 m", "1.0498 m rounds down")
	assert_equal(PlanScript.length_text(1076), "1.1 m", "1.0508 m rounds up")


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


func test_nobody_carries_a_load_through_a_tunnel() -> void:
	"""Leaving a stockpile over a short route, a carrier may carry -- but not when the route crosses a
	tunnel: over twelve seeds every trip goes through the tunnel, and not one carries."""
	var points: Array[Dictionary] = [
		{"name": &"stockpile", "position": Vector3(0.0, 0.0, -3.0), "face": Vector3.FORWARD, "activities": [&"collect_object"], "capacity": 1},
		{"name": &"north", "position": Vector3(0.0, 0.0, 3.0), "face": Vector3.BACK, "activities": [&"idle"], "capacity": 1}]
	var crossed := 0
	var carried := 0
	for attempt in 12:
		var space := CastSpaceScript.new()
		space.setup(points, _wall())
		_open_tunnel(space, [Vector2i(0, -2048), Vector2i(0, 2048)])
		var brain := BrainScript.new()
		brain.configure(space, WALK_M_S, BODY_M, SEED + attempt, _lengths())
		brain.set_carry_motion(_carry_motion())
		space.tunnels.set_fit(brain.index, true)
		space.reserve(0, 0)
		brain.start_at(space.slot_position(0, 0), 0.0, 0, 0)
		for f in 60 * 90:
			brain.step(DT)
			if brain.poi == 1:
				crossed += 1 if brain.crosses_tunnel() else 0
				carried += 1 if brain.carrying else 0
				break
	assert_true(_carries_at_all(), "the fixture's motion makes a carrier")
	assert_equal(crossed, 12, "every trip through the tunnel")
	assert_equal(carried, 0, "and none carrying")


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
	"""An open tunnel's overlay: both mouths and heaps, no mound; its trough only underground."""
	overlay.refresh()
	assert_true(overlay.hole(slot, true).visible, "exit open")
	assert_true(overlay.heap(slot, true).visible, "exit heap")
	assert_false(overlay.mound(slot).visible, "the mole is up")
	assert_false(overlay.bore(slot).visible, "no trough in the surface view")
	overlay.set_underground_view(true)
	overlay.refresh()
	assert_true(overlay.bore(slot).visible, "the trough in the underground view")


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


func test_a_mole_that_cannot_reach_the_entrance_gives_the_dig_up() -> void:
	"""An entrance inside a closed pen: the walk there is given up after its replans, and with it the
	dig -- the untouched tunnel is freed and the mole holds, no longer digging."""
	var space := _space(_ring(Vector2.ZERO))
	var mole := _brain(space, Vector2(-6.0, 0.0), true)
	var ref := PackedInt32Array([-1, 0])
	assert_true(space.tunnels.add_into(_route([Vector2i(0, 0), Vector2i(0, 8192)]), 2, mole.index, ref), "planned")
	mole.order_dig(ref[0], ref[1])
	_step(mole, 60.0)
	assert_equal(mole.dig_tunnel, -1, "gave the dig up")
	assert_equal(space.tunnels.phase[ref[0]], NetworkScript.PHASE_FREE, "nothing was dug, so nothing is kept")
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
