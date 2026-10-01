extends "res://test/framework/test_case.gd"
## Route planning spread over frames and the per-frame reads made free (decision 0361, the review's F06 and F01): the
## routing desk's budget and queue (route_desk.gd), a resident waiting "finding a route" and set off in its turn, a
## group order that never plans every route in one frame, the formation's one-sweep reachability agreeing with the
## planner, the piece chains read without rebuilding, and the selection read by revision. No scene tree, no assets.

const DeskScript := preload("res://demo/cast/route_desk.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const CastNavScript := preload("res://demo/cast/cast_nav.gd")
const CastOrdersScript := preload("res://demo/cast/cast_orders.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const DemoCastScript := preload("res://demo/cast/demo_cast.gd")
const CommandScript := preload("res://demo/control/demo_command.gd")
const PanelScript := preload("res://demo/control/demo_party_panel.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const SpecScript := preload("res://demo/tunnel/piece_spec.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")

const DT: float = 1.0 / 60.0
const BODY_M: float = 0.25
## A budget no test spends by accident, and what exhausts it.
const BIG_USEC: int = 1000000

var _nodes: Array[Node] = []
var _turns: PackedInt32Array = PackedInt32Array()
## Desks whose turns are lambdas holding the desk itself (and this suite): a cycle after_each breaks (decision 0501).
var _desks: Array[DeskScript] = []


func after_each() -> void:
	"""Free every node a test built."""
	for node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()
	_turns.clear()
	for desk: DeskScript in _desks:
		desk._turns.clear()
	_desks.clear()


func _brain(space: CastSpaceScript, at: Vector2) -> BrainScript:
	"""A resident standing at `at`, holding no slot."""
	var lengths := {}
	for clip in DemoActorScript.CLIPS:
		lengths[clip] = 2.0
	var brain := BrainScript.new()
	brain.configure(space, 1.0, BODY_M, 31 + space.resident_position.size(), lengths)
	brain.start_at(at, 0.0, -1, -1)
	return brain


func _open_space() -> CastSpaceScript:
	"""Open ground with one 1 m post at the origin."""
	var space := CastSpaceScript.new()
	space.setup([], [Vector3(0.0, 1.0, 0.0)] as Array[Vector3])
	return space


# --- the desk ---------------------------------------------------------------------------------------

func _turn(who: int) -> void:
	"""A turn callable's body: note who was served."""
	_turns.append(who)


func test_with_no_budget_everyone_plans_at_once() -> void:
	"""Out of the live scene (no budget) every plan may run, however much was spent, and nobody waits."""
	var desk := DeskScript.new()
	desk.register(0, _turn.bind(0))
	desk.charge(-1, BIG_USEC)
	assert_true(desk.may_plan(0) and desk.has_budget(), "no budget: always")


func test_the_budget_looks_ahead_and_waiters_go_first_come_first_served() -> void:
	"""With a budget: a fresh window always lets one plan start; then one starts only while a typical plan fits; a
	newcomer waits behind those already waiting; serving goes in order and stops when the window is spent; the next
	window starts whole."""
	var desk := DeskScript.new()
	for i in 3:
		desk.register(i, _turn.bind(i))
	desk.budget_usec = 1000
	assert_true(desk.may_plan(2), "a fresh window: yes")
	desk.charge(2, 600)
	assert_equal(desk.estimate_usec, 150, "a quarter of the newest plan into the running mean")
	assert_true(desk.may_plan(0), "600 + 150 fits 1000")
	desk.charge(0, 400)
	assert_false(desk.may_plan(1), "spent")
	desk.wait(1)
	desk.wait(0)
	desk.wait(1)
	assert_equal(desk.waiting(), 2, "a waiter keeps its one place")
	desk.end_window()
	assert_equal([desk.last_window_usec, desk.spent_usec()], [1000, 0], "kept for measurement; the next starts whole")
	assert_false(desk.may_plan(0), "0 waits behind 1")
	desk.serve()
	assert_equal(_turns, PackedInt32Array([1, 0]), "served in order; a turn that plans nothing gives its place up")
	assert_equal(desk.waiting(), 0, "nobody left waiting")


func test_a_turn_that_plans_ends_its_wait_and_charges_the_window() -> void:
	"""Serving stops once the window can take no typical plan more."""
	var desk := DeskScript.new()
	_desks.append(desk)
	desk.budget_usec = 1000
	desk.estimate_usec = 400
	for i in 3:
		desk.register(i, func() -> void:
			_turns.append(i)
			desk.charge(i, 700))
		desk.wait(i)
	desk.serve()
	assert_equal(_turns, PackedInt32Array([0]), "700 spent + a typical 475 > 1000: 0, then the window is done")
	desk.end_window()
	desk.serve()
	assert_equal(_turns, PackedInt32Array([0, 1]), "one a window while plans cost this much")


# --- a resident waiting for its route ------------------------------------------------------------------

func _spent_space() -> Array:
	"""Open ground with a budgeted desk whose window is spent, and a resident at (-4, 0). [space, brain]."""
	var space := _open_space()
	var brain := _brain(space, Vector2(-4.0, 0.0))
	space.routes.budget_usec = 1000
	space.routes.charge(-1, BIG_USEC)
	return [space, brain]


func test_a_turn_that_plans_and_waits_again_keeps_its_place() -> void:
	"""A resident whose turn plans and then starts a second trip that has to wait is not dropped from the queue."""
	var desk := DeskScript.new()
	_desks.append(desk)
	desk.budget_usec = 1000
	desk.register(0, func() -> void:
		desk.charge(0, 2000)
		desk.wait(0))
	desk.wait(0)
	desk.serve()
	assert_true(desk.is_waiting(0), "still waiting for its second trip")


func test_an_order_in_a_spent_window_waits_finding_a_route_then_sets_off() -> void:
	"""F06: ordered when the frame's routing is spent, the resident stands in ROUTE -- the party panel says "finding a
	route" -- and sets off in its turn on the next window."""
	var pair := _spent_space()
	var space: CastSpaceScript = pair[0]
	var brain: BrainScript = pair[1]
	brain.order_move(Vector2(4.0, 0.0))
	assert_equal([brain.state, brain.activity()], [BrainScript.State.ROUTE, BrainScript.ACTIVITY_ROUTING], "waiting")
	assert_equal(PanelScript.state_text(brain.activity(), brain.clip, ""), PanelScript.FINDING_ROUTE, "in words")
	assert_true(space.routes.is_waiting(brain.index), "at the desk")
	space.routes.end_window()
	space.routes.serve()
	assert_true(brain.state == BrainScript.State.TURN or brain.state == BrainScript.State.WALK, "set off: %d" % brain.state)
	assert_false(space.routes.is_waiting(brain.index), "no longer waiting")
	for f in roundi(20.0 / DT):
		brain.step(DT)
	assert_true(brain.arrived_near(Vector2(4.0, 0.0), 0.2), "and arrived round the post")


func test_a_waiting_carry_sets_off_carrying() -> void:
	"""An ordered carry that had to wait still sets off with its load (the carry is the trip's, not the moment's)."""
	var pair := _spent_space()
	var space: CastSpaceScript = pair[0]
	var brain: BrainScript = pair[1]
	brain.set_carry_motion({"keys_xz": [[0.0, 0.0], [0.0, 1.3]], "mean_speed_m_s": 0.2, "period_s": 6.5})
	brain.order_carry(Vector2(4.0, 0.0))
	assert_equal(brain.state, BrainScript.State.ROUTE, "waiting")
	space.routes.end_window()
	space.routes.serve()
	assert_true(brain.carrying, "set off carrying")


func test_a_routine_departure_in_a_spent_window_idles_a_moment_longer() -> void:
	"""F06 for the routine: a wanderer about to set off while the frame's routing is spent idles instead of planning, and
	goes once a window has room."""
	var space := CastSpaceScript.new()
	var points: Array[Dictionary] = []
	for x in [-6.0, 6.0]:
		points.append({"name": &"spot", "position": Vector3(x, 0.0, 0.0), "face": Vector3.FORWARD,
			"activities": [&"collect_object"] as Array[StringName], "capacity": 1})
	space.setup(points, [] as Array[Vector3])
	var brain := _brain(space, Vector2(0.0, 3.0))
	space.routes.budget_usec = 1000
	space.routes.charge(-1, BIG_USEC)
	for f in roundi(5.0 / DT):
		brain.step(DT)
	assert_equal(brain.state, BrainScript.State.IDLE, "still idling: no plan in a spent window")
	space.routes.end_window()
	for f in roundi(0.5 / DT):
		brain.step(DT)
	assert_true(brain.state == BrainScript.State.TURN or brain.state == BrainScript.State.WALK, "off once there is room")


func test_released_while_waiting_it_gives_its_place_up() -> void:
	"""A release takes it off the trip: it idles, and its place at the desk is given up at its turn."""
	var pair := _spent_space()
	var space: CastSpaceScript = pair[0]
	var brain: BrainScript = pair[1]
	brain.order_move(Vector2(4.0, 0.0))
	brain.release()
	assert_equal(brain.state, BrainScript.State.IDLE, "idling")
	space.routes.end_window()
	space.routes.serve()
	assert_equal([space.routes.waiting(), brain.state], [0, BrainScript.State.IDLE], "its place given up, not walked")


func test_a_group_order_never_plans_every_route_in_one_frame() -> void:
	"""F06: six residents of the placeholder cast ordered at once, with a budget no plan fits: the formation is chosen
	on the command's frame and the residents' routes come one a frame after it, every one served."""
	var cast := DemoCastScript.new()
	_nodes.append(cast)
	cast.build({}, [] as Array[Dictionary], [] as Array[Vector3])
	cast.set_bounds(AABB(Vector3(-20.0, 0.0, -20.0), Vector3(40.0, 4.0, 40.0)))
	cast.set_route_budget(1)
	var desk: DeskScript = cast.space().routes
	var members := PackedInt32Array([0, 1, 2, 3, 4, 5])
	assert_true(cast.order_move(members, Vector3(6.0, 0.0, 6.0))["ok"], "accepted")
	assert_equal(desk.waiting(), 6, "nobody planned on the command's frame (the formation spent it)")
	var most := 0
	for f in 12:
		var before := desk.served
		cast.advance(DT)
		most = maxi(most, desk.served - before)
	assert_equal([most, desk.waiting(), desk.served], [1, 0, 6], "one a frame, all of them served")


# --- one sweep answers the formation's spots -------------------------------------------------------------

func test_one_sweep_agrees_with_the_planner_spot_by_spot() -> void:
	"""F06: `reaches` (one sweep from the start, kept) answers as the planner does over a field with a closed ring, a
	wall and open ground -- including inside the ring, where no route goes -- and is never yes where the plan fails."""
	var circles: Array[Vector3] = [Vector3(8.0, 1.5, 0.0)]
	for k in 16:
		var angle := TAU * float(k) / 16.0
		circles.append(Vector3(cos(angle) * 3.0 - 10.0, 0.8, sin(angle) * 3.0))
	for z in [-4.0, -2.5, -1.0, 0.5, 2.0]:
		circles.append(Vector3(2.0, 0.9, z))
	var space := CastSpaceScript.new()
	space.setup([], circles)
	var route := PackedVector2Array()
	var agree := 0
	var wrong := PackedVector2Array()
	for x in range(-14, 15, 2):
		for z in range(-8, 9, 2):
			var spot := Vector2(x, z)
			if space.obstacle_clearance(spot) < BODY_M + 0.12:
				continue
			space.nav.plan(Vector2(-2.0, 6.0), spot, BODY_M, PackedVector3Array(), 0, route)
			if space.nav.reaches(Vector2(-2.0, 6.0), spot, BODY_M) == space.nav.last_found:
				agree += 1
			else:
				wrong.append(spot)
	assert_true(wrong.is_empty() and agree > 40, "spot by spot as the planner (%d agree; differ at %s)" % [agree, wrong])
	assert_false(space.nav.reaches(Vector2(-2.0, 6.0), Vector2(-10.0, 0.0), BODY_M), "nothing inside the ring")
	assert_false(space.nav.reaches(Vector2(-10.0, 0.0), Vector2(-2.0, 6.0), BODY_M), "nor out of it: a new start, a new sweep")


func test_the_sweep_is_kept_for_one_body_and_one_set_of_circles() -> void:
	"""The sweep answers for the body it was made for (its links use the body's own radius), and is made again when the
	circles change: never a yes the planner would not find."""
	var ring: Array[Vector3] = []
	for k in 8:
		ring.append(Vector3(cos(TAU * k / 8.0) * 2.0, 0.5, sin(TAU * k / 8.0) * 2.0))
	var space := CastSpaceScript.new()
	space.setup([], ring)
	var route := PackedVector2Array()
	space.nav.plan(Vector2.ZERO, Vector2(5.0, 0.3), 0.29, PackedVector3Array(), 0, route)
	var wide_found := space.nav.last_found
	space.nav.reaches(Vector2.ZERO, Vector2(5.0, 0.3), 0.21)
	assert_equal(space.nav.reaches(Vector2.ZERO, Vector2(5.0, 0.3), 0.29), wide_found, "the wider body's own answer")
	var open := _open_space()
	assert_true(open.nav.reaches(Vector2(-4.0, 0.0), Vector2(4.0, 3.0), BODY_M), "open ground")
	var wall := PackedVector3Array()
	for k in 4:
		wall.append(Vector3(-4.0 + cos(TAU * k / 4.0) * 0.9, 0.7, sin(TAU * k / 4.0) * 0.9))
	open.set_mound(0, wall)
	assert_false(open.nav.reaches(Vector2(-4.0, 0.0), Vector2(4.0, 3.0), BODY_M), "the start walled round since: swept again")


func test_holding_is_no_arrival_after_a_trip_given_up() -> void:
	"""`arrived_near` holds only after an ARRIVED trip: one given up at the very spot is not arrival."""
	var space := _open_space()
	var brain := _brain(space, Vector2(-4.0, 0.0))
	brain.order_move(Vector2(-4.0, 2.0))
	for f in roundi(5.0 / DT):
		brain.step(DT)
	assert_true(brain.arrived_near(Vector2(-4.0, 2.0), 0.2), "arrived")
	brain.trip_outcome = BrainScript.TRIP_FAILED
	assert_false(brain.arrived_near(Vector2(-4.0, 2.0), 0.2), "the same spot, a trip given up: no arrival")


func test_a_piece_short_of_node_rows_is_refused_naming_them() -> void:
	"""F08: with mouth rows to spare but no node row, a mouth-to-mouth piece is refused for the nodes, in words."""
	var graph := GraphScript.new()
	graph.node_kind.fill(GraphScript.NODE_JUNCTION)
	var spec := SpecScript.new()
	spec.set_route(PackedInt32Array([0, 0, 12288, 0]), 2)
	assert_equal(graph.rows_refusal(spec), Rules.REFUSE_NO_NODE_ROWS, "refused for its nodes")
	assert_true(Rules.link_text(Rules.REFUSE_NO_NODE_ROWS, "").contains("%d junctions" % Rules.MAX_NODES), "named, with the cap")


func _reaches_as_planned(circles: Array[Vector3], from: Vector2, spot: Vector2, what: String) -> void:
	"""Over `circles`, the planner finds a route from -> spot and `reaches` says so too."""
	var space := CastSpaceScript.new()
	space.setup([], circles)
	var route := PackedVector2Array()
	space.nav.plan(from, spot, BODY_M, PackedVector3Array(), 0, route)
	assert_true(space.nav.last_found, "%s: the planner finds a route" % what)
	assert_true(space.nav.reaches(from, spot, BODY_M), "%s: and the sweep says so" % what)


func test_the_sweep_finds_the_way_into_a_pocket_and_out_of_one() -> void:
	"""The plan's own nodes round the circles by its goal (a pocket no static node sees into) and round its start (a
	pocket whose only way out is by them, a blocker outside its mouth) are part of the sweep's answer, as of the plan's."""
	var into: Array[Vector3] = [Vector3(-0.300157, 0.518614, 2.247468), Vector3(0.801401, 0.767038, -0.505703),
		Vector3(-0.267829, 0.570135, -0.268059), Vector3(1.143471, 0.781662, -0.156017), Vector3(1.370453, 0.66643, 0.685659),
		Vector3(-1.057276, 0.812051, 1.449733), Vector3(0.276128, 0.54406, 2.463751)]
	_reaches_as_planned(into, Vector2(8.0, 8.0), Vector2(0.080805, 0.671349), "into a pocket")
	var out: Array[Vector3] = [Vector3(3.2, 0.9, 0.0)]
	for k in range(1, 10):
		out.append(Vector3(cos(TAU * k / 10.0) * 1.5, 0.45, sin(TAU * k / 10.0) * 1.5))
	_reaches_as_planned(out, Vector2.ZERO, Vector2(8.0, 0.0), "out of a pocket")
	var deep: Array[Vector3] = [Vector3(2.546054, 0.647975, 2.991942), Vector3(2.848869, 0.476906, 0.973824),
		Vector3(4.000516, 0.460137, 1.872433), Vector3(2.707319, 0.485255, 3.407525), Vector3(2.082387, 0.701336, 2.700893),
		Vector3(1.938211, 0.599003, 2.433081), Vector3(3.067106, 0.566013, 1.020725), Vector3(3.724117, 0.608098, 2.962777),
		Vector3(3.974073, 0.806901, 2.461208)]
	_reaches_as_planned(deep, Vector2(9.0, 9.0), Vector2(2.862436, 2.058102), "deep in a pocket, ring to ring")


# --- the piece chains and the selection, read per frame without making anything ---------------------------

func test_the_piece_chains_follow_every_change_of_shape() -> void:
	"""F01: where each segment begins along its piece, and where a point along a piece lies, read from the kept chains,
	equal a fresh walk of the piece after pieces are added and an open bore is split by a new one."""
	var graph := GraphScript.new()
	var ref := PackedInt32Array([-1, 0, -1])
	assert_true(graph.add_into(PackedInt32Array([0, 0, 12288, 0]), 2, 0, ref), "a tunnel")
	var first := ref[2]
	_check_chain(graph, first, "one tunnel")
	var chain := PackedInt32Array()
	graph.piece_segments_into(first, chain)
	for slot in chain:
		graph.start_dig(slot, graph.generation[slot], 0)
		graph.advance(slot, graph.generation[slot], 1000000000)
	var spec := SpecScript.new()
	spec.set_route(PackedInt32Array([6144, 8192, 6144, 0]), 2)
	spec.end_kind = SpecScript.END_ON_SEGMENT
	spec.end_ref = chain[1]
	assert_true(graph.add_piece(spec, ref), "a branch onto the bore, splitting it")
	_check_chain(graph, first, "the split tunnel")
	_check_chain(graph, ref[2], "the branch")


func _check_chain(graph: GraphScript, p: int, what: String) -> void:
	"""The kept chain of piece `p` against a fresh walk of it."""
	var chain := PackedInt32Array()
	graph.piece_segments_into(p, chain)
	var along := 0.0
	var place := PackedFloat32Array([0.0, 0.0])
	for slot in chain:
		assert_almost_equal(graph.piece_offset_m(slot), along, "%s: segment %d begins %.2f m in" % [what, slot, along])
		graph.piece_locate_into(p, along + 0.25, place)
		assert_equal([int(place[0]), snappedf(place[1], 0.001)], [slot, 0.25], "%s: a point just into segment %d" % [what, slot])
		along += graph.length_m(slot)
	place[0] = -1.0
	place[1] = -1.0
	graph.piece_locate_into(p, along + 5.0, place)
	var last := chain[chain.size() - 1]
	assert_equal([int(place[0]), snappedf(place[1], 0.001)], [last, snappedf(graph.length_m(last), 0.001)],
		"%s: past the end, clamped to the last's end" % what)


func test_the_selection_is_read_by_revision_without_an_array_a_frame() -> void:
	"""F01: every change of selection bumps its revision; the first selected and the selection read into a kept array
	follow it; an unchanged selection leaves the revision alone."""
	var cast := DemoCastScript.new()
	_nodes.append(cast)
	cast.build({}, [] as Array[Dictionary], [] as Array[Vector3])
	cast.set_bounds(AABB(Vector3(-20.0, 0.0, -20.0), Vector3(40.0, 4.0, 40.0)))
	var camera := Camera3D.new()
	_nodes.append(camera)
	var command := CommandScript.new()
	_nodes.append(command)
	command.configure(cast, camera)
	var seen := command.selection_revision()
	assert_equal(command.first_selected(), -1, "nobody")
	command.select(PackedInt32Array([4, 2]))
	assert_true(command.selection_revision() != seen, "changed")
	var into := PackedInt32Array()
	assert_equal([command.selected_into(into), into, command.first_selected()], [2, PackedInt32Array([2, 4]), 2], "read")
	seen = command.selection_revision()
	command.is_selected(2)
	command.selection_count()
	assert_equal(command.selection_revision(), seen, "reading changes nothing")
	command.clear_selection()
	assert_true(command.selection_revision() != seen and command.first_selected() == -1, "cleared")


func test_a_trip_with_no_way_there_says_why_in_the_party_panel() -> void:
	"""F02's feedback: sent to a node below whose every way in is closed, the resident holds -- and the party panel's
	words for it say why, not just "holding"."""
	var cast := DemoCastScript.new()
	_nodes.append(cast)
	cast.build({}, [] as Array[Dictionary], [] as Array[Vector3])
	cast.set_bounds(AABB(Vector3(-20.0, 0.0, -20.0), Vector3(40.0, 4.0, 40.0)))
	var camera := Camera3D.new()
	_nodes.append(camera)
	var command := CommandScript.new()
	_nodes.append(command)
	command.configure(cast, camera)
	var network: GraphScript = cast.space().tunnels
	var ref := PackedInt32Array([-1, 0, -1])
	assert_true(network.add_into(PackedInt32Array([4096, 4096, 16384, 4096]), 2, 0, ref), "a tunnel")
	var chain := PackedInt32Array()
	network.piece_segments_into(ref[2], chain)
	for slot in chain:
		network.start_dig(slot, network.generation[slot], 0)
		network.advance(slot, network.generation[slot], 1000000000)
	network.close(chain[0], 1, 0, 4096)
	network.close(chain[2], 1, 0, 4096)
	var brain: BrainScript = (cast.actor(0) as DemoActorScript).brain
	brain.order_carry_below(network.node_a[chain[1]], Vector2.ZERO)
	assert_equal([brain.activity(), brain.trip_failed()], [BrainScript.ACTIVITY_HOLDING, true], "given up at once: no way in")
	assert_equal(command.activity_text(0), PanelScript.HOLDING_REFUSED % BrainScript.REFUSED_NO_ROUTE, "says why")
