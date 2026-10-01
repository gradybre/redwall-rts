extends "res://test/framework/test_case.gd"
## The second level (decision 0212, the underground revamp's P6): the candidate spacing, links down (ramps and
## stairs, their grades and costs), the ground at depth, level-2 pieces and rooms and their refusals, cross-level
## routes against a Floyd-Warshall reference (as MOVE-TEST-09), picking on the shown level's floor, the view's
## per-level layers, caps and masks, the prewarm over level 2, the night and hauling across the levels, and the cool
## rule's depth. No scene tree and no staged assets; every expected value is worked from the named constants.

const TestCaseScript := preload("res://test/framework/test_case.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const PathsScript := preload("res://demo/tunnel/graph_paths.gd")
const SpecScript := preload("res://demo/tunnel/piece_spec.gd")
const RouterScript := preload("res://demo/tunnel/tunnel_router.gd")
const PlanScript := preload("res://demo/tunnel/tunnel_plan.gd")
const ReadoutScript := preload("res://demo/tunnel/dig_readout.gd")
const GroundScript := preload("res://demo/tunnel/tunnel_ground.gd")
const WaterScript := preload("res://demo/village_water.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")
const RoomPlanScript := preload("res://demo/burrow/room_plan.gd")
const FixturesScript := preload("res://demo/burrow/room_fixtures.gd")
const Layers := preload("res://demo/demo_layers.gd")
const GraphTest := preload("res://test/test_demo_graph.gd")
const BOUNDS_U := Rect2i(-20480, -20480, 40960, 40960)
const BODY_M: float = 0.25
## The two-level fixture (see `_two_levels`): tunnels P and Q on level 1, stairs down from P, a ramp down from Q,
## and a bore on level 2 joining their feet.
const P_ROUTE: Array[Vector2i] = [Vector2i(-10240, -8192), Vector2i(10240, -8192)]
const Q_ROUTE: Array[Vector2i] = [Vector2i(-10240, 16384), Vector2i(10240, 16384)]
const STAIRS_HEAD := Vector2i(0, -8192)
const STAIRS_FOOT := Vector2i(0, -3072)
## Beside the stairs 1.75 m down their run (out of their head junction's reach), their void still within a pillar of
## level 1's floor.
const STAIRS_TOP := Vector2i(300, -6400)
const RAMP_HEAD := Vector2i(0, 16384)
const RAMP_FOOT := Vector2i(0, 16384 - 11136)


# --- the fixture -------------------------------------------------------------------------------------

static func route(points: Array[Vector2i]) -> PackedInt32Array:
	"""Points (u) as a flat (x, z) route."""
	var out := PackedInt32Array()
	for p in points:
		out.append_array([p.x, p.y])
	return out


static func plan_of(level: int, link_kind: int) -> PlanScript:
	"""A plan laid on `level`, a link of `link_kind` (LINK_NONE: a piece on one level)."""
	var plan := PlanScript.new()
	plan.level = level
	plan.link_kind = link_kind
	return plan


static func lay(graph: GraphScript, plan: PlanScript, points: Array[Vector2i]) -> int:
	"""Lay `points` into `plan`, each snapped onto its own level (as the Dig tool does), and its reason: REFUSE_NONE, or
	the first point's or the whole piece's refusal."""
	var snap := PackedInt32Array([0, -1, 0, 0])
	for p in points:
		var kind := PlanScript.snap_into(graph, p, snap, plan.level_of_point(plan.count))
		var reason := plan.try_add_snapped(snap[2], snap[3], kind, snap[1], BOUNDS_U, PackedInt32Array())
		if reason != Rules.REFUSE_NONE:
			return reason
	return plan.piece_reason(graph, BOUNDS_U, PackedInt32Array())


static func store(graph: GraphScript, plan: PlanScript) -> int:
	"""Store the laid piece and dig it open; its piece row (-1: not stored)."""
	var ref := PackedInt32Array([-1, 0, -1])
	if not graph.add_piece(plan.spec_of(0), ref):
		return -1
	GraphTest._dig(graph, ref[2])
	return ref[2]


static func first_link(graph: GraphScript, kind: int) -> int:
	"""The first link segment of `kind` (-1: none)."""
	for slot in Rules.MAX_SEGMENTS:
		if graph.phase[slot] != GraphScript.PHASE_FREE and graph.seg_kind[slot] == GraphScript.SEG_LINK \
				and graph.seg_link[slot] == kind:
			return slot
	return -1


static func two_levels(t: TestCaseScript) -> GraphScript:
	"""Tunnels P and Q (mouth to mouth, dug), STAIRS from P's bore down to a blind foot on level 2, a RAMP from Q's bore
	down to another, and a bore on level 2 from the stairs' foot to the ramp's -- all laid through the plan's rules
	(checked on `t`)."""
	var graph := GraphScript.new()
	var ref := PackedInt32Array([-1, 0, -1])
	for points: Array[Vector2i] in [P_ROUTE, Q_ROUTE]:
		t.assert_true(graph.add_into(route(points), 2, 0, ref), "a tunnel on level 1")
		GraphTest._dig(graph, ref[2])
	var stairs := plan_of(Rules.TOP_LEVEL, Rules.LINK_STAIRS)
	t.assert_equal(lay(graph, stairs, [STAIRS_HEAD, STAIRS_FOOT]), Rules.REFUSE_NONE, "stairs from P down")
	t.assert_true(store(graph, stairs) >= 0, "the stairs stored")
	var ramp := plan_of(Rules.TOP_LEVEL, Rules.LINK_RAMP)
	t.assert_equal(lay(graph, ramp, [RAMP_HEAD, RAMP_FOOT]), Rules.REFUSE_NONE, "a ramp from Q down")
	t.assert_true(store(graph, ramp) >= 0, "the ramp stored")
	var lower := plan_of(Rules.LEVEL_2, Rules.LINK_NONE)
	t.assert_equal(lay(graph, lower, [STAIRS_FOOT, RAMP_FOOT]), Rules.REFUSE_NONE, "a bore on level 2 between the feet")
	t.assert_true(store(graph, lower) >= 0, "the lower bore stored")
	return graph


func tolerates_outside_tree() -> bool:
	"""Its node fixtures are never inside the scene tree (test_case.gd ENGINE DIAGNOSTICS)."""
	return true


func _two_levels() -> GraphScript:
	"""THE TWO LEVELS fixture (`two_levels`), checked here."""
	return two_levels(self)


# --- the rules ------------------------------------------------------------------------------------

func test_the_levels_lie_the_candidate_spacing_apart() -> void:
	"""Level 1 is the bores' 1.25 m down; level 2 the candidate 4 m lower (a named demo value, DEC-040); only they dig."""
	assert_equal(Rules.LEVEL_SPACING_U, 4096, "the candidate spacing, 4 m")
	assert_equal(Rules.level_floor_depth_u(Rules.LEVEL_1), 1280, "level 1")
	assert_equal(Rules.level_floor_depth_u(Rules.LEVEL_2), 1280 + 4096, "level 2")
	assert_almost_equal(Rules.level_floor_m(Rules.LEVEL_2), -5.25, "5.25 m down")
	for level: int in [0, 1, 2, 3]:
		assert_equal(Rules.is_buildable_level(level), level == 1 or level == 2, "level %d buildable" % level)
	assert_equal(Rules.vertical_gap_u(256, 1280, 4352, 5376), 3072, "a level-1 bore and a level-2 bore: 3 m apart")
	assert_equal(Rules.vertical_gap_u(-1536, 1280, 2560, 5376), 1280, "a level-1 room and a level-2 room: 1.25 m")
	assert_true(Rules.vertical_gap_u(1000, 2000, 1500, 2500) < 0, "overlapping heights")


func test_a_ramp_down_is_never_steeper_than_one_in_two_and_a_half() -> void:
	"""A ramp link falls LEVEL_SPACING_U over its run, eased at both ends: 10.875 m at the least. Sampled every 16 u
	at its shortest and longest runs, it falls monotonically from 0 to 4 m, never steeper than 2:5, its float twin
	within a unit of it."""
	assert_equal(Rules.link_min_run_u(Rules.LINK_RAMP), 4096 * 5 / 2 + 896, "11136 u")
	for run: int in [Rules.link_min_run_u(Rules.LINK_RAMP), Rules.LINK_MAX_RAMP_RUN_U]:
		assert_equal(Rules.link_drop_u(Rules.LINK_RAMP, 0, run), 0, "the head")
		assert_equal(Rules.link_drop_u(Rules.LINK_RAMP, run, run), 4096, "the foot")
		var last := 0
		for along in range(16, run + 1, 16):
			var drop := Rules.link_drop_u(Rules.LINK_RAMP, along, run)
			assert_true(drop >= last and (drop - last) * 5 <= 16 * 2 + 5, "at %d of %d: %d after %d" % [along, run, drop, last])
			assert_true(absf(Rules.link_drop_m(Rules.LINK_RAMP, Rules.to_m(along), Rules.to_m(run)) * 1024.0 - drop) <= 1.0, "twins")
			last = drop
	assert_equal(Rules.link_grade_permille(Rules.LINK_RAMP, 11136), 400, "its steepest: 1:2.5")
	assert_almost_equal(Rules.link_slope(Rules.LINK_RAMP, 5.0, Rules.to_m(11136)), 0.4, "the straight middle")
	assert_almost_equal(Rules.link_slope(Rules.LINK_RAMP, 0.0, 10.0), 0.0, "level at its head")


func test_stairs_are_steeper_timber_risers_and_slower() -> void:
	"""Sixteen risers of 0.25 m on treads of 0.3125-0.5 m: 5-8 m of run at 4:5 at the steepest (38.7 degrees), the
	walking line straight down the pitch; walked at half pace, and each quantum a quarter more work."""
	assert_equal(Rules.STAIR_RISE_U * Rules.STAIR_RISERS, Rules.LEVEL_SPACING_U, "16 x 256 u")
	assert_equal(Rules.link_min_run_u(Rules.LINK_STAIRS), 5120, "5 m")
	assert_equal(Rules.link_max_run_u(Rules.LINK_STAIRS), 8192, "8 m")
	assert_equal(Rules.link_grade_permille(Rules.LINK_STAIRS, 5120), 800, "4:5")
	assert_equal(Rules.link_drop_u(Rules.LINK_STAIRS, 2560, 5120), 2048, "half way, half down")
	assert_almost_equal(Rules.link_slope(Rules.LINK_STAIRS, 2.5, 5.0), 0.8, "the pitch")
	assert_equal(Rules.link_speed_permille(Rules.LINK_STAIRS), 500, "half pace")
	assert_equal(Rules.link_speed_permille(Rules.LINK_RAMP), 1000, "a ramp at walk pace along its slope")
	assert_equal(Rules.link_work_permille(Rules.LINK_STAIRS), 1250, "a quarter more work a quantum")
	assert_equal(Rules.link_work_permille(Rules.LINK_RAMP), 1000, "a ramp as a bore")
	assert_true(Rules.link_min_run_u(Rules.LINK_STAIRS) < Rules.link_min_run_u(Rules.LINK_RAMP), "steeper: shorter")


func test_a_link_is_refused_too_short_or_too_long_in_words() -> void:
	"""Each kind's least and greatest run pass; a unit either side is refused, and the words say which."""
	for kind: int in [Rules.LINK_RAMP, Rules.LINK_STAIRS]:
		var short := Rules.REFUSE_STAIRS_SHORT if kind == Rules.LINK_STAIRS else Rules.REFUSE_RAMP_SHORT
		assert_equal(Rules.link_refusal(kind, Rules.link_min_run_u(kind) - 1), short, "too short")
		assert_equal(Rules.link_refusal(kind, Rules.link_min_run_u(kind)), Rules.REFUSE_NONE, "the least")
		assert_equal(Rules.link_refusal(kind, Rules.link_max_run_u(kind)), Rules.REFUSE_NONE, "the greatest")
		assert_equal(Rules.link_refusal(kind, Rules.link_max_run_u(kind) + 1), Rules.REFUSE_LINK_LONG, "too long")
	assert_true(Rules.link_text(Rules.REFUSE_RAMP_SHORT, "").contains("1:2.5"), "the ramp's grade in words")
	assert_true(Rules.link_text(Rules.REFUSE_STAIRS_SHORT, "").contains("16 timber risers"), "the stairs' in words")
	var seen: Array[String] = []
	for code in range(Rules.REFUSE_LINK_START, Rules.REFUSE_LOWER_JOIN + 1):
		var words := Rules.link_text(code, "Tunnel 3")
		assert_false(words.is_empty() or seen.has(words), "code %d has its own words" % code)
		seen.append(words)


func test_a_link_costs_and_cuts_by_its_slope() -> void:
	"""Its planner cost and its quanta are its slope's: stairs 5 m on, 4 m down -- 6557 u, 7 quanta; the shortest ramp
	12 quanta. The mouths' ramp's integer depth twins its float one."""
	assert_equal(Rules.link_slope_u(5120), 6557, "sqrt(5120^2 + 4096^2), up")
	assert_equal(Rules.link_quanta(5120), 7, "every started metre of the slope")
	assert_equal(Rules.link_quanta(11136), 12, "the shortest ramp's")
	for along in range(0, Rules.RAMP_RUN_U + 1, 64):
		assert_true(absi(Rules.ramp_depth_u(along) - roundi(Rules.ramp_depth_m(Rules.to_m(along)) * 1024.0)) <= 1, "at %d" % along)


# --- the ground at depth ------------------------------------------------------------------------------

func test_the_second_level_is_more_clay_and_rock_and_less_sand() -> void:
	"""Over the whole grid, level 2 has more clay and rock cells and fewer sand cells than level 1; a deep rock pocket
	is rock only below; a sand lens's rim is sand only above; the level-1 answers are unchanged."""
	var ground := GroundScript.new()
	var counts := [[0, 0, 0, 0], [0, 0, 0, 0]]
	for i in ground.cells.size():
		counts[0][ground.cells[i] & GroundScript.TYPE_MASK] += 1
		counts[1][ground.deep_cells[i] & GroundScript.TYPE_MASK] += 1
	assert_true(counts[1][GroundScript.CLAY] > counts[0][GroundScript.CLAY], "more clay: %s" % str(counts))
	assert_true(counts[1][GroundScript.ROCK] > counts[0][GroundScript.ROCK], "more rock")
	assert_true(counts[1][GroundScript.SAND] < counts[0][GroundScript.SAND], "less sand")
	assert_equal(ground.type_at_level(0, -8192, Rules.LEVEL_2), GroundScript.ROCK, "a deep rock pocket")
	assert_true(ground.type_at_level(0, -8192, Rules.LEVEL_1) != GroundScript.ROCK, "not near the surface")
	var rim := Vector2i(-16384 + 3584, 10240)
	assert_equal(ground.type_at_level(rim.x, rim.y, Rules.LEVEL_1), GroundScript.SAND, "the sand lens's rim above")
	assert_true(ground.type_at_level(rim.x, rim.y, Rules.LEVEL_2) != GroundScript.SAND, "not below")
	assert_equal(ground.type_at_level(5632, 1536, Rules.LEVEL_1), ground.type_at(5632, 1536), "level 1 is type_at")


func test_below_the_ground_is_wet_only_near_the_water_table() -> void:
	"""Level 1 is wet within 4.5 m of the waterline; level 2 within DEEP_WET_REACH_U (2.5 m): ground 3-4 m off the
	stream is wet above and dry below, ground within 2.5 m of it wet on both."""
	var water := WaterScript.new()
	var ground := GroundScript.new(Rect2i(-20480, -20480, 40960, 40960), water)
	var near := Vector2i.ZERO
	var mid := Vector2i.ZERO
	for r in ground.rows:
		for c in ground.columns:
			var at := ground._centre(c, r)
			var margin := water.map().inside_margin_u(at)
			if margin > -GroundScript.DEEP_WET_REACH_U and margin < 0 and near == Vector2i.ZERO:
				near = at
			if margin > -4096 and margin < -GroundScript.DEEP_WET_REACH_U - 256 and mid == Vector2i.ZERO:
				mid = at
	assert_true(near != Vector2i.ZERO and mid != Vector2i.ZERO, "found ground by the stream")
	assert_true(ground.wet_at_level(near.x, near.y, Rules.LEVEL_1) and ground.wet_at_level(near.x, near.y, Rules.LEVEL_2), "by the water")
	assert_true(ground.wet_at_level(mid.x, mid.y, Rules.LEVEL_1), "3-4 m off: wet near the surface")
	assert_false(ground.wet_at_level(mid.x, mid.y, Rules.LEVEL_2), "3-4 m off: dry at depth")


# --- the graph ----------------------------------------------------------------------------------------

func test_stairs_are_one_link_from_a_level_1_bore_down_to_a_blind_foot() -> void:
	"""Laid from P's bore: its head a junction on level 1 (P split there), its foot a blind end on level 2; one LINK
	segment of the stairs' kind, walked down its pitch line from -1.25 m to -5.25 m, costed and cut by its slope."""
	var graph := _two_levels()
	var stairs := first_link(graph, Rules.LINK_STAIRS)
	assert_true(stairs >= 0, "a stairs link")
	var head: int = graph.node_a[stairs]
	var foot: int = graph.node_b[stairs]
	assert_equal([graph.node_kind[head], graph.node_level[head]], [GraphScript.NODE_JUNCTION, Rules.LEVEL_1], "its head")
	assert_equal([graph.node_kind[foot], graph.node_level[foot]], [GraphScript.NODE_END, Rules.LEVEL_2], "its foot")
	assert_equal([graph.seg_level[stairs], graph.length_u[stairs]], [Rules.LEVEL_1, 5120], "the head's level, a 5 m run")
	assert_equal([graph.cost_u[stairs], graph.quanta[stairs]], [6557, 7], "its slope's cost and quanta")
	assert_almost_equal(graph.floor_y_at(stairs, 0.0), -1.25, "the head's floor")
	assert_almost_equal(graph.floor_y_at(stairs, 5.0), -5.25, "the foot's floor")
	assert_almost_equal(graph.floor_grade_at(stairs, 2.5), -0.8, "down the pitch")
	assert_equal(graph.floor_depth_u_at(stairs, 2560), 1280 + 2048, "its integer depth")
	assert_equal(graph.speed_permille(stairs), 500, "half pace")
	graph.set_lit(stairs)
	assert_equal(graph.speed_permille(stairs), 550, "lit: a tenth quicker, still half pace")
	assert_equal(graph.degree(head), 3, "P's two halves and the stairs meet at the head")


func test_stairs_take_a_quarter_more_work_than_a_ramp() -> void:
	"""The same microseconds of work dig 1000/1250 as many ticks on stairs as on a bore."""
	var graph := GraphScript.new()
	var ref := PackedInt32Array([-1, 0, -1])
	graph.add_into(route(P_ROUTE), 2, 0, ref)
	GraphTest._dig(graph, ref[2])
	var stairs := plan_of(Rules.TOP_LEVEL, Rules.LINK_STAIRS)
	assert_equal(lay(graph, stairs, [STAIRS_HEAD, STAIRS_FOOT]), Rules.REFUSE_NONE, "stairs")
	graph.add_piece(stairs.spec_of(0), ref)
	graph.start_dig(ref[0], ref[1], 0)
	graph.advance(ref[0], ref[1], 1000000)
	assert_equal(graph.done(ref[0]), 30 * 1000 / 1250, "24 ticks for a second of work")
	assert_equal(graph.work_permille(ref[0]), 1250, "its work")
	assert_equal(graph.work_permille(0), 1000, "a ramp's")


func test_a_link_is_dug_through_each_level_s_ground() -> void:
	"""A link's quanta lie on its head's level through the upper half of the drop and its foot's below; each is cut in
	that level's ground (tunnel_ground.gd THE GROUND AT DEPTH)."""
	var graph := GraphScript.new()
	var ground := GroundScript.new()
	graph.set_ground(ground)
	var ref := PackedInt32Array([-1, 0, -1])
	graph.add_into(route(P_ROUTE), 2, 0, ref)
	GraphTest._dig(graph, ref[2])
	var stairs := plan_of(Rules.TOP_LEVEL, Rules.LINK_STAIRS)
	lay(graph, stairs, [STAIRS_HEAD, STAIRS_FOOT])
	graph.add_piece(stairs.spec_of(0), ref)
	var slot := ref[0]
	var last := graph.timeline_count(slot) - 1
	assert_equal([graph.quantum_level(slot, 0), graph.quantum_level(slot, last)], [Rules.LEVEL_1, Rules.LEVEL_2], "head, foot")
	for k in graph.timeline_count(slot):
		var at := graph.quantum_point_u(slot, k)
		assert_equal(graph.quantum_kind(slot, k), ground.type_at_level(at.x, at.y, graph.quantum_level(slot, k)), "quantum %d" % k)
	assert_equal(graph.quantum_level(0, 0), Rules.LEVEL_1, "a mouth's ramp is level 1's")


func test_a_room_on_level_2_has_no_door_to_the_surface() -> void:
	"""On level 2 a room is laid without a mouth or a ramp: its door a free SOCKET, its body its piece's first segment on
	level 2; `adopt_passage` puts the passage first in the job list and spoils the room where the passage does; a room
	whose passage failed is dropped again, not a tick dug."""
	var graph := _two_levels()
	var room := PackedInt32Array([0, 0, 0, 0, 0])
	var mouths_before := graph.mouth_node.count(-1)
	assert_true(graph.add_room(RoomsScript.TEMPLATE_HOME, Vector2i(-6656, -3072), 1, 0, room, Rules.LEVEL_2), "laid on level 2")
	var r := room[0]
	assert_equal(graph.mouth_node.count(-1), mouths_before, "no mouth")
	assert_equal([graph.rooms.mouth[r], graph.rooms.ramp[r], graph.rooms.first_segment(r)], [-1, -1, graph.rooms.body[r]], "no ramp")
	assert_equal(room[3], graph.rooms.body[r], "its first segment is its body")
	var door: int = graph.rooms.door[r]
	assert_true(graph.node_kind[door] == GraphScript.NODE_SOCKET and graph.is_free_socket(door), "its door a free socket")
	assert_equal([graph.node_level[door], graph.seg_level[graph.rooms.body[r]]], [Rules.LEVEL_2, Rules.LEVEL_2], "on level 2")
	assert_equal(graph.rooms.way_in_count(r), 4, "three sockets and its door")
	assert_equal(graph.rooms.way_in_node(r, 3), door, "its door the fourth way in")
	var passage := PackedInt32Array([-1, 0, -1])
	var plan := plan_of(Rules.LEVEL_2, Rules.LINK_NONE)
	assert_equal(lay(graph, plan, [STAIRS_FOOT, graph.node_at(door)]), Rules.REFUSE_NONE, "a passage to the door")
	assert_true(graph.add_piece(plan.spec_of(0), passage), "stored")
	graph.adopt_passage(room[2], passage[2])
	assert_true(graph.piece_order[passage[2]] < graph.piece_order[room[2]], "the passage first")
	assert_equal(graph.next_dig_for(0), passage[0], "dug first")
	assert_equal(graph.piece_mouth[room[2]], graph.piece_mouth[passage[2]], "spoiled where the passage spoils")
	assert_true(graph.drop_unbroken(room[2]), "a room not begun is dropped")
	assert_false(graph.rooms.is_room(r), "its row freed")


func test_a_room_on_level_2_is_refused_only_by_what_lies_on_its_level() -> void:
	"""Its void inside the village, off the water, and a pillar from its own level's voids -- nothing on the surface is
	asked. A level-2 room under a level-1 tunnel may go; beside a level-2 bore it may not; beside a link at its
	height it may not; without a passage to its door the room tool refuses it."""
	var graph := _two_levels()
	var site := RoomsScript.Site.new()
	site.bounds_u = BOUNDS_U
	site.circles_u = PackedInt32Array([6144, 4096, 20480])
	site.circles_u = PackedInt32Array([-5120, 4096, 16384])
	assert_equal(graph.rooms.refusal(graph, site, RoomsScript.TEMPLATE_HOME, Vector2i(-5120, 16384), 0, Rules.LEVEL_2),
		RoomsScript.REFUSE_NONE, "under Q's mouth, and under an obstacle on the ground: nothing there is asked")
	assert_true(graph.rooms.refusal(graph, site, RoomsScript.TEMPLATE_HOME, Vector2i(-5120, 16384), 0, Rules.LEVEL_1)
		!= RoomsScript.REFUSE_NONE, "on level 1 it may not")
	assert_equal(graph.rooms.refusal(graph, site, RoomsScript.TEMPLATE_HOME, Vector2i(3072, 1024), 0, Rules.LEVEL_2),
		RoomsScript.REFUSE_NEAR_TUNNEL, "beside the level-2 bore")
	assert_equal(graph.rooms.refusal(graph, site, RoomsScript.TEMPLATE_HOME, Vector2i(3072, 8192), 0, Rules.LEVEL_2),
		RoomsScript.REFUSE_NEAR_TUNNEL, "beside the ramp down where it passes level 2's height")
	assert_equal(graph.rooms.refusal(graph, site, RoomsScript.TEMPLATE_HOME, Vector2i(-12288, 2048), 0, Rules.LEVEL_2),
		RoomsScript.REFUSE_NONE, "anywhere clear")
	var plan := RoomPlanScript.new()
	plan.level = Rules.LEVEL_2
	plan.centre_u = Vector2i(-12288, 2048)
	assert_equal(plan.check(graph, site), RoomsScript.REFUSE_NEEDS_PASSAGE, "no passage within 6 m: refused")
	assert_true(RoomsScript.reason_text(RoomsScript.REFUSE_NEEDS_PASSAGE).contains("only through the tunnels"), "in words")


func test_the_room_tool_joins_a_level_2_room_at_its_door() -> void:
	"""Placed on level 2 near the stairs' foot, the room's passage runs from level 2's network to its DOOR (the way
	it is dug from), leaving it straight out."""
	var graph := _two_levels()
	var plan := RoomPlanScript.new()
	plan.level = Rules.LEVEL_2
	var site := RoomsScript.Site.new()
	site.bounds_u = BOUNDS_U
	plan.centre_u = STAIRS_FOOT + Vector2i(-2048 - 2560, 0)
	plan.turns = 1
	assert_equal(plan.check(graph, site), RoomsScript.REFUSE_NONE, "may go, with a passage")
	assert_equal(plan.passage_socket, 0, "to its one way in")
	assert_equal(plan.passage.point_u(1), RoomsScript.door_at(RoomsScript.TEMPLATE_HOME, plan.centre_u, 1), "at its door")
	assert_equal([plan.passage.snap_kind[0], plan.passage.snap_ref[0]], [SpecScript.END_NODE, graph.node_b[first_link(graph, Rules.LINK_STAIRS)]],
		"from the stairs' foot")
	assert_equal(plan.passage.level, Rules.LEVEL_2, "a passage on level 2")
	assert_true(plan.clear_of_own_ramp(), "no ramp to keep off")


# --- laying on level 2, and links ----------------------------------------------------------------------

func test_a_level_2_piece_starts_on_its_network_and_may_end_blind() -> void:
	"""On level 2 no mouth opens: a start joining nothing is refused in words; one on a link's foot may run out to a
	blind end (stored as a NODE_END on level 2), which must keep a junction's gap from every node there."""
	var graph := _two_levels()
	assert_equal(lay(graph, plan_of(Rules.LEVEL_2, Rules.LINK_NONE), [Vector2i(-8192, 0), Vector2i(-8192, 4096)]),
		Rules.REFUSE_LOWER_START, "joining nothing")
	var out := plan_of(Rules.LEVEL_2, Rules.LINK_NONE)
	assert_equal(lay(graph, out, [RAMP_FOOT, RAMP_FOOT + Vector2i(4096, 0)]), Rules.REFUSE_NONE, "from the ramp's foot, out east")
	assert_true(out.ends_blind() and not out.ends_at_mouth() and not out.starts_at_mouth(), "blind, no mouths")
	var spec := out.spec_of(0)
	assert_equal([spec.level, spec.end_kind, spec.blind_ends()], [Rules.LEVEL_2, SpecScript.END_BLIND, 1], "stored blind")
	var mouths := graph.mouth_node.count(-1)
	assert_true(store(graph, out) >= 0, "stored")
	assert_equal(graph.mouth_node.count(-1), mouths, "no mouth opened")
	var end := -1
	for node in Rules.MAX_NODES:
		if graph.is_node(node) and graph.node_at(node) == RAMP_FOOT + Vector2i(4096, 0):
			end = node
	assert_equal([graph.node_kind[end], graph.node_level[end]], [GraphScript.NODE_END, Rules.LEVEL_2], "a blind end on level 2")
	var room := PackedInt32Array([0, 0, 0, 0, 0])
	graph.add_room(RoomsScript.TEMPLATE_HOME, Vector2i(-12288, 8192), 0, 0, room, Rules.LEVEL_2)
	var near_middle := Vector2i(-12288 + 566, 8192 + 566)
	assert_equal(lay(graph, plan_of(Rules.LEVEL_2, Rules.LINK_NONE), [RAMP_FOOT, RAMP_FOOT + Vector2i(-3072, 0), near_middle]),
		Rules.REFUSE_NEAR_NODE, "a blind end too near another node (a level-2 room's middle, which nothing snaps to)")


func test_snapping_keeps_to_the_level_laid_on() -> void:
	"""A point over P's bore snaps onto it on level 1 and onto nothing on level 2; one at the stairs' foot snaps onto
	it on level 2 and onto nothing on level 1 (the stairs are 4 m under it there); one beside the stairs' top, still
	within a pillar of level 1's floor, snaps onto their slope on level 1."""
	var graph := _two_levels()
	var snap := PackedInt32Array([0, -1, 0, 0])
	var over_p := Vector2i(-3072, -8192 + 200)
	assert_equal(PlanScript.snap_into(graph, over_p, snap, Rules.LEVEL_1), SpecScript.END_ON_SEGMENT, "P on level 1")
	assert_equal(PlanScript.snap_into(graph, over_p, snap, Rules.LEVEL_2), SpecScript.END_NEW_MOUTH, "nothing on level 2")
	assert_equal(PlanScript.snap_into(graph, STAIRS_FOOT, snap, Rules.LEVEL_2), SpecScript.END_NODE, "the foot on level 2")
	assert_equal(snap[1], graph.node_b[first_link(graph, Rules.LINK_STAIRS)], "the stairs' foot")
	assert_equal(PlanScript.snap_into(graph, STAIRS_FOOT, snap, Rules.LEVEL_1), SpecScript.END_NEW_MOUTH, "on level 1: over the foot")
	assert_equal(PlanScript.snap_into(graph, STAIRS_TOP, snap, Rules.LEVEL_1), SpecScript.END_ON_SEGMENT, "on level 1: the stairs' top")
	assert_equal(snap[1], first_link(graph, Rules.LINK_STAIRS), "which is refused as a join (below)")


func test_a_link_starts_on_level_1_and_runs_straight_down() -> void:
	"""Its head must join level 1's network; it has two points; its run is within its kind's limits; no piece joins a
	link's slope; and its foot snaps onto level 2's network."""
	var graph := _two_levels()
	assert_equal(lay(graph, plan_of(Rules.TOP_LEVEL, Rules.LINK_RAMP), [Vector2i(-12288, 4096), Vector2i(-12288, -8192)]),
		Rules.REFUSE_LINK_START, "a head joining nothing")
	var bent := plan_of(Rules.TOP_LEVEL, Rules.LINK_STAIRS)
	var snap := PackedInt32Array([0, -1, 0, 0])
	assert_equal(lay(graph, bent, [Vector2i(4096, -8192), Vector2i(4096, -3072)]), Rules.REFUSE_NONE, "stairs from P")
	assert_equal(bent.try_add_snapped(4096, 0, SpecScript.END_NEW_MOUTH, -1, BOUNDS_U, PackedInt32Array()), Rules.REFUSE_LINK_BEND, "no third point")
	assert_equal(lay(graph, plan_of(Rules.TOP_LEVEL, Rules.LINK_STAIRS), [Vector2i(-4096, -8192), Vector2i(-4096, -3584)]),
		Rules.REFUSE_STAIRS_SHORT, "stairs too short")
	assert_equal(lay(graph, plan_of(Rules.TOP_LEVEL, Rules.LINK_RAMP), [Vector2i(-4096, -8192), Vector2i(-4096, 1024)]),
		Rules.REFUSE_RAMP_SHORT, "a ramp too short")
	assert_equal(lay(graph, plan_of(Rules.TOP_LEVEL, Rules.LINK_STAIRS), [Vector2i(-4096, -8192), Vector2i(-4096, 1024)]),
		Rules.REFUSE_LINK_LONG, "stairs too long")
	var join := plan_of(Rules.TOP_LEVEL, Rules.LINK_NONE)
	assert_equal(lay(graph, join, [STAIRS_TOP, Vector2i(-8192, -6400)]), Rules.REFUSE_JOIN_LINK,
		"a tunnel may not join a link's slope")
	PlanScript.snap_into(graph, Vector2i(1000, 0), snap, bent.level_of_point(1))
	assert_equal(snap[0], SpecScript.END_ON_SEGMENT, "a link's second point snaps on level 2: the level-2 bore")


func test_levels_keep_their_pillars_in_height_not_in_plan() -> void:
	"""A level-2 bore straight under P crosses it with no junction and no pillar refused (3 m of earth between); a
	level-1 tunnel T over the level-2 bore and the stairs likewise (at the stairs, 1 m of earth exactly: their floor
	there is 3.25 m down); new stairs passing under T while still near its height are refused as breaking into it,
	and the same stairs dug the other way are laid."""
	var graph := _two_levels()
	var under := plan_of(Rules.LEVEL_2, Rules.LINK_NONE)
	assert_equal(lay(graph, under, [STAIRS_FOOT, Vector2i(-6144, -3072), Vector2i(-6144, -12288)]), Rules.REFUSE_NONE,
		"under P, across it")
	assert_equal(under.crossings.size(), 0, "no crossing of another level's bore")
	var over := plan_of(Rules.TOP_LEVEL, Rules.LINK_NONE)
	assert_equal(lay(graph, over, [Vector2i(-6144, 1024), Vector2i(6144, 1024)]), Rules.REFUSE_NONE, "over the level-2 bore")
	assert_equal(over.crossings.size(), 0, "no junction with it")
	var tee := plan_of(Rules.TOP_LEVEL, Rules.LINK_NONE)
	assert_equal(lay(graph, tee, [Vector2i(-9216, -5632), Vector2i(2560, -5632)]), Rules.REFUSE_NONE, "T over the stairs")
	assert_true(store(graph, tee) >= 0, "T dug")
	var under_t := plan_of(Rules.TOP_LEVEL, Rules.LINK_STAIRS)
	assert_equal(lay(graph, under_t, [Vector2i(-4096, -8192), Vector2i(-4096, -3072)]), Rules.REFUSE_PILLAR,
		"stairs passing under T while their void is within a pillar of its height")
	var away := plan_of(Rules.TOP_LEVEL, Rules.LINK_STAIRS)
	assert_equal(lay(graph, away, [Vector2i(-4096, -8192), Vector2i(-4096, -13312)]), Rules.REFUSE_NONE, "dug away from T")


func test_a_link_passes_under_a_ramp_s_mouth_it_is_deep_enough_under() -> void:
	"""The pillar in height reads a mouth's ramp at its own depth there: stairs passing 2.4 m beside the top of a ramp,
	already 1.6 m under its floor there, are clear of it."""
	var graph := _two_levels()
	var stairs := plan_of(Rules.TOP_LEVEL, Rules.LINK_STAIRS)
	var ramp_top := Vector2i(10240 - 512, -8192)
	assert_equal(PlanScript.other_band_u(graph, 2, ramp_top).y, Rules.ramp_depth_u(512), "the ramp's own depth near its mouth")
	assert_true(PlanScript.clear_in_height(graph, 2, ramp_top, 1280 + 2900), "a floor 2.9 m under level 1's is clear of it")
	assert_false(PlanScript.clear_in_height(graph, 2, ramp_top, 1280), "level 1's floor is not")
	assert_equal(lay(graph, stairs, [Vector2i(4096, -8192), Vector2i(4096, -3072)]), Rules.REFUSE_NONE, "stairs by P's ramp")


# --- routing across the levels (MOVE-TEST-09 style) ------------------------------------------------------

func _field(graph: GraphScript, rain_permille: int) -> CastSpaceScript:
	"""An open field over `graph`, the surface walked at `rain_permille` (rain: the network is quicker)."""
	var space := CastSpaceScript.new()
	space.setup([], [])
	space.tunnels = graph
	graph.surface_permille = rain_permille
	return space


func test_a_route_across_the_levels_equals_the_dijkstra_reference() -> void:
	"""Between P and Q only level 2 joins them: down P's stairs, along level 2, up Q's ramp. With the surface slowed to
	300 per mille, a trip from P's west to Q's west goes that way, and costs exactly what an independent Floyd-Warshall
	over the same edges (both levels' segments, the surface between start, goal and mouths) finds; its legs walk both
	links."""
	var graph := _two_levels()
	var space := _field(graph, 300)
	var index := space.add_resident(Vector2(-11.0, -9.0), BODY_M)
	graph.set_fit(index, true)
	var scale := 1000.0 / 300.0
	for trip: Array in [[Vector2(-11.0, -9.0), Vector2(-11.0, 17.0)], [Vector2(11.0, 17.0), Vector2(-9.0, -9.0)]]:
		var out := PackedVector2Array()
		var legs := PackedInt32Array()
		space.plan_path(index, trip[0], trip[1], BODY_M, out, legs)
		assert_true(space.nav.last_found, "found %s" % str(trip))
		var got := GraphTest._route_cost(graph, trip[0], out, legs, scale)
		assert_almost_equal(got, GraphTest._reference_cost(graph, trip[0], trip[1], scale), "the reference's cost %s" % str(trip))
		var links := 0
		for code in legs:
			links += 1 if code >= 0 and not RouterScript.is_crossing_code(code) and graph.seg_kind[RouterScript.leg_slot(code)] == GraphScript.SEG_LINK else 0
		assert_equal(links, 2, "down one link and up the other")
	assert_true(graph.paths.dist_u(graph, PathsScript.CLASS_ANY, 0, graph.node_b[first_link(graph, Rules.LINK_STAIRS)]) < PathsScript.UNREACHED,
		"a mouth's table reaches level 2")


func test_a_trip_bound_for_level_2_ends_at_its_node_by_the_cheapest_way() -> void:
	"""A trip whose goal is the stairs' foot on level 2 (a task's node) reaches it only through the network, at the cost
	an independent Floyd-Warshall finds from the start to that node (the surface to the mouths, every segment below)."""
	var graph := _two_levels()
	var space := _field(graph, 1000)
	var foot: int = graph.node_b[first_link(graph, Rules.LINK_STAIRS)]
	for start: Vector2 in [Vector2(-11.0, -7.0), Vector2(11.0, 17.5)]:
		var index := space.add_resident(start, BODY_M)
		graph.set_fit(index, true)
		var out := PackedVector2Array()
		var legs := PackedInt32Array()
		space.plan_path(index, start, graph.node_m(foot), BODY_M, out, legs, true, false, foot)
		assert_true(space.nav.last_found and out[out.size() - 1] == graph.node_m(foot), "ends at the foot from %s" % start)
		var reference := _reference_table(graph, start)
		var best: float = reference["dist"][0][(reference["ids"] as Array[int]).find(foot) + 2]
		assert_almost_equal(GraphTest._route_cost(graph, start, out, legs, 1.0), best, "the reference's cost from %s" % start)


static func _reference_table(graph: GraphScript, from: Vector2) -> Dictionary:
	"""test_demo_graph.gd's Floyd-Warshall reference from `from` on the surface: {ids: the network's nodes, dist: the
	all-pairs table -- row and column 0 the start, 1 unused (the start again), node ids[k] at k + 2}. The surface joins
	the start and the mouths only; every usable segment is an edge at its cost over its speed."""
	var ids: Array[int] = []
	for node in Rules.MAX_NODES:
		if graph.is_node(node):
			ids.append(node)
	var n := ids.size() + 2
	var dist: Array[PackedFloat64Array] = []
	for i in n:
		var row := PackedFloat64Array()
		row.resize(n)
		row.fill(INF)
		row[i] = 0.0
		dist.append(row)
	GraphTest._reference_surface(graph, ids, dist, from, from, 1.0)
	GraphTest._reference_segments(graph, ids, dist)
	for k in n:
		for i in n:
			for j in n:
				dist[i][j] = minf(dist[i][j], dist[i][k] + dist[k][j])
	return {"ids": ids, "dist": dist}


# --- living and working across the levels -------------------------------------------------------------

const BrainScript := preload("res://demo/cast/resident_brain.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const NightScript := preload("res://demo/burrow/night_routine.gd")
const SleepTaskScript := preload("res://demo/burrow/sleep_task.gd")
const CalendarScript := preload("res://demo/demo_calendar.gd")
const NoticesScript := preload("res://demo/demo_notices.gd")
const HaulScript := preload("res://demo/tunnel/spoil_haul.gd")
const HeapsScript := preload("res://demo/tunnel/tunnel_heaps.gd")
const CrewScript := preload("res://demo/tunnel/tunnel_crew.gd")
const CrewTaskScript := preload("res://demo/tunnel/tunnel_crew_task.gd")
const DT: float = 1.0 / 60.0
const MOUSE_U: int = 1024
const UPPER_HOME := Vector2i(0, -8192)


func _lengths() -> Dictionary:
	"""Every clip the cast knows, 2 s long."""
	var lengths := {}
	for clip in DemoActorScript.CLIPS:
		lengths[clip] = 2.0
	return lengths


func _brain(space: CastSpaceScript, at: Vector2, seed: int) -> BrainScript:
	"""A mouse at `at` who fits the bores."""
	var brain := BrainScript.new()
	brain.configure(space, 1.0, BODY_M, seed, _lengths())
	brain.start_at(at, 0.0, -1, -1)
	space.tunnels.set_body(brain.index, MOUSE_U, 256)
	return brain


func _homes_on_two_levels(graph: GraphScript) -> int:
	"""A burrow home on level 1 at UPPER_HOME (its door toward -Z), stairs from its +Z socket down to level 2, and a
	home on level 2 whose door faces the stairs' foot, joined by a passage: all dug, three beds in the lower home and
	none in the upper. Returns the lower home's row."""
	var upper := PackedInt32Array([0, 0, 0, 0, 0])
	assert_true(graph.add_room(RoomsScript.TEMPLATE_HOME, UPPER_HOME, 0, 0, upper), "the upper home")
	GraphTest._dig(graph, upper[2])
	var socket: int = graph.rooms.socket_of(upper[0], 1)
	var stairs := plan_of(Rules.TOP_LEVEL, Rules.LINK_STAIRS)
	var head := graph.node_at(socket)
	assert_equal(lay(graph, stairs, [head, head + Vector2i(0, 5120)]), Rules.REFUSE_NONE, "stairs from its socket")
	store(graph, stairs)
	var lower := PackedInt32Array([0, 0, 0, 0, 0])
	var centre := head + Vector2i(0, 5120 + 2560 + 2048)
	assert_true(graph.add_room(RoomsScript.TEMPLATE_HOME, centre, 0, 0, lower, Rules.LEVEL_2), "the lower home")
	var passage := plan_of(Rules.LEVEL_2, Rules.LINK_NONE)
	assert_equal(lay(graph, passage, [head + Vector2i(0, 5120), graph.node_at(graph.rooms.door[lower[0]])]), Rules.REFUSE_NONE,
		"its passage")
	var way := store(graph, passage)
	graph.adopt_passage(lower[2], way)
	GraphTest._dig(graph, lower[2])
	for f in 3:
		graph.fit.phase_of(graph, lower[0], f)
		graph.fit.phase[lower[0] * FixturesScript.PLACES + f] = FixturesScript.INSTALLED
	graph.fit.revision += 1
	return lower[0]


func test_at_dusk_they_go_down_the_stairs_to_their_beds_on_level_2() -> void:
	"""Three mice, beds only in the home on level 2: at dusk each walks in at the upper home's door, down the stairs
	and through the passage, and lies in its own bed there -- on level 2's floor, drawn on its layer."""
	var space := CastSpaceScript.new()
	space.setup([], [] as Array[Vector3])
	var graph := space.tunnels
	var lower := _homes_on_two_levels(graph)
	var brains: Array[BrainScript] = []
	for i in 3:
		brains.append(_brain(space, Vector2(-3.0 + 3.0 * float(i), -16.0), 7 + i))
	var calendar := CalendarScript.new()
	var night := NightScript.new()
	night.configure(graph, brains, PackedStringArray(["a", "b", "c"]), PackedInt32Array([MOUSE_U, MOUSE_U, MOUSE_U]), calendar,
		NoticesScript.new())
	calendar.tick = 12 * 750
	var linked := _night_until_asleep(space, night, calendar, brains)
	for i in 3:
		assert_true(brains[i].lying and brains[i].task is SleepTaskScript, "resident %d asleep" % i)
		assert_true(linked[i], "resident %d went down the stairs" % i)
		assert_almost_equal(brains[i].lie_top_y_m, Layers.floor_y(Rules.LEVEL_2) + NightScript.DEFAULT_BED_TOP_M, "on level 2's mattress")
		assert_equal(graph.seg_room[space.resident_tunnel[brains[i].index]], lower, "in the lower home")
		assert_equal(brains[i].view_level(), Rules.LEVEL_2, "drawn on level 2")


func _night_until_asleep(space: CastSpaceScript, night: NightScript, calendar: CalendarScript,
		brains: Array[BrainScript]) -> Array[bool]:
	"""Run the night and the brains (the calendar on at 30 ticks a second) until all lie asleep, or 150 s; whether each
	walked a link on the way."""
	var linked: Array[bool] = [false, false, false]
	for f in 60 * 150:
		night.step()
		calendar.tick += f % 2
		for i in brains.size():
			brains[i].step(DT)
			var at: int = space.resident_tunnel[brains[i].index] if brains[i].underground else -1
			linked[i] = linked[i] or (at >= 0 and space.tunnels.seg_kind[at] == GraphScript.SEG_LINK)
		if brains.all(func(b: BrainScript) -> bool: return b.lying):
			break
	return linked


func test_a_basket_is_carried_up_the_stairs_to_the_heap() -> void:
	"""A crew member at its post in a level-2 dig from the stairs' foot: a quantum's spoil cut, it fills a basket,
	carries it up the stairs and out of P's mouth -- the dig's spoil mouth -- and tips it there, the heap growing by the
	load; and walks back down to its post."""
	var graph := _two_levels()
	var space := _field(graph, 1000)
	var ref := _lower_dig(graph)
	var m: int = graph.spoil_mouth[ref[0]]
	assert_true(graph.is_mouth(m) and graph.node_level[graph.mouth_node[m]] == Rules.LEVEL_SURFACE, "it spoils at a mouth up top")
	graph.start_dig(ref[0], ref[1], 0)
	graph.advance(ref[0], ref[1], 3000000)
	HeapsScript.place(graph, space, m)
	var member := _crew_member(space, ref[0], graph.mouth_at(m) + Vector2(1.0, 1.0))
	var haul: HaulScript = graph.haul
	for f in 60 * 60:
		member.step(DT)
		if haul.mouth_of.size() > 0 and haul.mouth_of[0] == m:
			break
	assert_equal(haul.mouth_of[0], m, "at its post below, hauling for the mouth up top")
	var before := haul.on_heap_milli(graph, m)
	graph.add_spoil(ref[0], 2000)
	var up_the_link := false
	for f in 60 * 120:
		member.step(DT)
		var at: int = space.resident_tunnel[member.index] if member.underground else -1
		up_the_link = up_the_link or (at >= 0 and graph.seg_kind[at] == GraphScript.SEG_LINK and member.carrying)
		if haul.on_heap_milli(graph, m) > before:
			break
	assert_true(up_the_link and haul.on_heap_milli(graph, m) >= before + 2000, "carried up the stairs, laden; the heap grew")


func _crew_member(space: CastSpaceScript, slot: int, at: Vector2) -> BrainScript:
	"""A mouse at `at`, carrying with a carry clip's motion, sent to its post half a metre into the dig `slot` as its
	crew's member (tunnel_crew_task.gd), the dig's face 1.5 m in."""
	var crew := CrewScript.new()
	crew.set_resident(0, "Mouse")
	var member := _brain(space, at, 11)
	member.set_carry_motion({"keys_xz": [[0.0, 0.0], [0.0, 1.3]], "mean_speed_m_s": 0.2, "period_s": 6.5})
	crew.join(0, slot)
	var task := CrewTaskScript.new(crew, space.tunnels, slot, true, space.tunnels.point_at(slot, 0.5),
		func(_s: int) -> bool: return true, func(s: int) -> float: return 1.5 if s == slot else 0.0)
	member.order_task(task)
	return member


func _lower_dig(graph: GraphScript) -> PackedInt32Array:
	"""A level-2 dig west from the stairs' foot, laid through the rules and stored (not begun); its first segment's
	(slot, generation) and its piece."""
	var dig := plan_of(Rules.LEVEL_2, Rules.LINK_NONE)
	assert_equal(lay(graph, dig, [STAIRS_FOOT, STAIRS_FOOT + Vector2i(-6144, 0)]), Rules.REFUSE_NONE, "a level-2 dig west")
	var ref := PackedInt32Array([-1, 0, -1])
	assert_true(graph.add_piece(dig.spec_of(0), ref), "stored")
	return ref


func test_the_cool_rule_counts_a_cellar_s_depth_by_its_level() -> void:
	"""A racked cellar on level 2 is deep by its level's floor (5.25 m); a hearth in a level-1 home right over it does not
	warm it; a level-2 home with a hearth whose passage reaches the cellar's door within 6 m does."""
	assert_equal(FixturesScript.cool_of(Rules.level_floor_depth_u(Rules.LEVEL_2), 1, false, false), FixturesScript.COOL_YES, "deep")
	assert_equal(FixturesScript.cool_of(0, 1, false, false), FixturesScript.COOL_SHALLOW, "at the surface")
	var graph := _two_levels()
	var cellar := PackedInt32Array([0, 0, 0, 0, 0])
	assert_true(graph.add_room(RoomsScript.TEMPLATE_CELLAR, Vector2i(-5120, -3072), 1, 0, cellar, Rules.LEVEL_2), "a cellar on level 2")
	var way := plan_of(Rules.LEVEL_2, Rules.LINK_NONE)
	assert_equal(lay(graph, way, [STAIRS_FOOT, graph.node_at(graph.rooms.door[cellar[0]])]), Rules.REFUSE_NONE, "its passage")
	graph.adopt_passage(cellar[2], store(graph, way))
	GraphTest._dig(graph, cellar[2])
	graph.fit.phase_of(graph, cellar[0], 0)
	graph.fit.phase[cellar[0] * FixturesScript.PLACES] = FixturesScript.INSTALLED
	var upper := PackedInt32Array([0, 0, 0, 0, 0])
	assert_true(graph.add_room(RoomsScript.TEMPLATE_HOME, Vector2i(-5120, -3072), 0, 0, upper), "a home right over it")
	GraphTest._dig(graph, upper[2])
	_hearth(graph, upper[0])
	assert_true(graph.fit.is_cool(graph, cellar[0]), "cool: the hearth above is on another level")
	var lower := PackedInt32Array([0, 0, 0, 0, 0])
	assert_true(graph.add_room(RoomsScript.TEMPLATE_HOME, STAIRS_FOOT + Vector2i(4608, 0), 3, 0, lower, Rules.LEVEL_2), "a home east")
	var joined := plan_of(Rules.LEVEL_2, Rules.LINK_NONE)
	assert_equal(lay(graph, joined, [STAIRS_FOOT, graph.node_at(graph.rooms.door[lower[0]])]), Rules.REFUSE_NONE, "its passage")
	graph.adopt_passage(lower[2], store(graph, joined))
	GraphTest._dig(graph, lower[2])
	_hearth(graph, lower[0])
	assert_equal(graph.fit.cool(graph, cellar[0]), FixturesScript.COOL_HEARTH_OPENS, "warm: it opens onto a hearth by its door")


func test_a_hearth_never_warms_a_cellar_down_a_link() -> void:
	"""A racked cellar on level 2 whose door the stairs from a hearthed home's socket land on: the walk is the stairs' 5 m
	run -- under OPENS_ONTO_U -- but warmth stays on its level, so the cellar is cool."""
	var graph := GraphScript.new()
	var upper := PackedInt32Array([0, 0, 0, 0, 0])
	assert_true(graph.add_room(RoomsScript.TEMPLATE_HOME, UPPER_HOME, 0, 0, upper), "the upper home")
	GraphTest._dig(graph, upper[2])
	_hearth(graph, upper[0])
	var head := graph.node_at(graph.rooms.socket_of(upper[0], 1))
	var door := head + Vector2i(0, 5120)
	var cellar := PackedInt32Array([0, 0, 0, 0, 0])
	var centre := door - RoomsScript.door_at(RoomsScript.TEMPLATE_CELLAR, Vector2i.ZERO, 0)
	assert_true(graph.add_room(RoomsScript.TEMPLATE_CELLAR, centre, 0, 0, cellar, Rules.LEVEL_2), "the cellar")
	var stairs := plan_of(Rules.TOP_LEVEL, Rules.LINK_STAIRS)
	assert_equal(lay(graph, stairs, [head, door]), Rules.REFUSE_NONE, "stairs from its socket down to the cellar's door")
	graph.adopt_passage(cellar[2], store(graph, stairs))
	GraphTest._dig(graph, cellar[2])
	graph.fit.phase_of(graph, cellar[0], 0)
	graph.fit.phase[cellar[0] * FixturesScript.PLACES] = FixturesScript.INSTALLED
	graph.fit.revision += 1
	assert_true(5120 < FixturesScript.OPENS_ONTO_U, "a walk short enough, were warmth to pass the stairs")
	assert_equal(graph.fit.cool(graph, cellar[0]), FixturesScript.COOL_YES, "cool")


static func _hearth(graph: GraphScript, r: int) -> void:
	"""A hearth installed in home `r`."""
	for f in RoomsScript.fixture_count(RoomsScript.TEMPLATE_HOME):
		if RoomsScript.fixture_field(RoomsScript.TEMPLATE_HOME, f, 0) == RoomsScript.FIX_HEARTH:
			graph.fit.phase_of(graph, r, f)
			graph.fit.phase[r * FixturesScript.PLACES + f] = FixturesScript.INSTALLED
	graph.fit.revision += 1


func test_the_readout_names_the_link_its_run_slope_and_grade() -> void:
	"""The Dig tool's words for stairs and a ramp down: their kind, run and slope, quanta, and their risers or grade."""
	var graph := _two_levels()
	var stairs := plan_of(Rules.TOP_LEVEL, Rules.LINK_STAIRS)
	lay(graph, stairs, [Vector2i(4096, -8192), Vector2i(4096, -3072)])
	var words := ReadoutScript.text(stairs, null, 1000, 1)
	for part: String in ["Stairs down", "5.0 m run", "6.4 m slope", "7 quanta", "16 timber risers", "pitch 38.7°"]:
		assert_true(words.contains(part), "stairs: '%s' in %s" % [part, words])
	var ramp := plan_of(Rules.TOP_LEVEL, Rules.LINK_RAMP)
	lay(graph, ramp, [Vector2i(4096, -8192), Vector2i(4096, -8192 + 11136)])
	words = ReadoutScript.text(ramp, null, 1000, 1)
	for part: String in ["Ramp down", "10.9 m run", "11.6 m slope", "12 quanta", "grade 1:2.5", "(21.8°)"]:
		assert_true(words.contains(part), "ramp: '%s' in %s" % [part, words])


# --- the view: the village with a second level ---------------------------------------------------------

const ViewTest := preload("res://test/test_demo_underground_view.gd")
const ControlScript := preload("res://demo/tunnel/tunnel_control.gd")
const BoreViewScript := preload("res://demo/tunnel/bore_view.gd")
const StairScript := preload("res://demo/tunnel/stair_view.gd")
const CapScript := preload("res://demo/tunnel/underground_cap.gd")
const PrewarmScript := preload("res://demo/tunnel/underground_prewarm.gd")
const RoomToolScript := preload("res://demo/burrow/room_tool.gd")
const UiLayout := preload("res://scripts/ui/ui_layout.gd")
const UiShell := preload("res://scripts/ui/ui_shell.gd")
const UiRegistry := preload("res://scripts/ui/ui_registry.gd")
const HUD_SCENE: String = "res://scenes/ui/hud.tscn"
const ViewScript := preload("res://demo/tunnel/tunnel_view.gd")
const FixtureViewScript := preload("res://demo/burrow/fixture_view.gd")
const LOWER_AT := Vector2(-1.0, -1.5)

var _helper: RefCounted = null


func after_each() -> void:
	"""Free the village a test built (through its helper, the underground view's suite), and show level 1 again."""
	if _helper != null:
		_helper.after_each()
		_helper = null
	Layers.active_level = Rules.TOP_LEVEL


func _village_below() -> Dictionary:
	"""The underground view suite's dug playtest village (its tunnel, home and cellar), and on it THE SECOND LEVEL laid
	through the Dig tool as a player would: stairs down from the home's free north socket (L, L, press, release), and a
	burrow home on level 2 placed with the room tool while the view shows level 2 (PgDn), its passage to its door from
	the stairs' foot -- all dug and the home fitted. {v: the village, lower: its row, stairs: the link's slot}."""
	_helper = ViewTest.new()
	var v: Dictionary = _helper._village()
	_helper._dig(v)
	var tool: ControlScript = v["tool"]
	var network: GraphScript = tool.network
	var stairs := _lay_stairs(tool)
	assert_true(tool.handle_input(ViewTest._key(KEY_PAGEDOWN)), "PgDn in the U view")
	var list := _place_lower_home(tool)
	_helper._frame(v)
	var laid: int = network.piece_room[list[1]]
	assert_true(tool.ext.room_view.outline_below(laid).visible and not tool.ext.room_view.outline(laid).visible,
		"laid: outlined below, nothing on the ground")
	for p in list:
		ViewTest._dig_piece(network, p)
	var lower := network.rooms.template.size() - 1
	while lower >= 0 and (not network.rooms.is_room(lower) or network.rooms.level[lower] != Rules.LEVEL_2):
		lower -= 1
	ViewTest.furnish(network, lower)
	_helper._frame(v)
	assert_true(_helper.failures.is_empty(), "the village built: %s" % str(_helper.failures))
	return {"v": v, "lower": lower, "stairs": stairs}


func _place_lower_home(tool: ControlScript) -> PackedInt32Array:
	"""The burrow home on level 2 placed with the room tool at LOWER_AT, after a try refused for want of a row for its
	passage; the job list then: its passage, and it."""
	var network: GraphScript = tool.network
	tool.begin_room(RoomsScript.TEMPLATE_HOME)
	tool.room.plan.turns = 0
	tool.room.turn(2)
	tool.room.move_to(LOWER_AT)
	_refused_without_a_passage_row(tool)
	assert_true(tool.room.place(false), "the lower home laid: %s" % tool.notice())
	assert_true(tool.notice().contains(RoomToolScript.LOWER_PASSAGE), "dug from its passage: %s" % tool.notice())
	tool.cancel_plan()
	var list := PackedInt32Array()
	network.job_list_into(list)
	assert_true(list.size() == 2 and network.piece_adopter[list[0]] == list[1] and network.piece_room[list[1]] >= 0,
		"its passage before it in the job list")
	return list


func _refused_without_a_passage_row(tool: ControlScript) -> void:
	"""With one piece row left -- the room's, none for its passage -- the lower home is laid and dropped again, refused in
	words: no level-2 room is left standing."""
	var network: GraphScript = tool.network
	var held := PackedInt32Array()
	for p in Rules.MAX_PIECES:
		if network.piece_live[p] == 0 and network.piece_live.count(0) > 1:
			network.piece_live[p] = 1
			held.append(p)
	assert_false(tool.room.place(false), "no row for its passage")
	assert_true(tool.notice().contains(RoomsScript.reason_text(RoomsScript.REFUSE_NEEDS_PASSAGE)), "said: %s" % tool.notice())
	for r in RoomsScript.MAX_ROOMS:
		assert_false(network.rooms.is_room(r) and network.rooms.level[r] == Rules.LEVEL_2, "no level-2 room left (row %d)" % r)
	for p in held:
		network.piece_live[p] = 0


func _lay_stairs(tool: ControlScript) -> int:
	"""Stairs down from the playtest home's free north socket, laid and dug as the player would (L, L, two points);
	their slot."""
	var network: GraphScript = tool.network
	var head := Vector2.INF
	for k in 3:
		var at: Vector2i = network.rooms.socket_u(0, k)
		if at.y < network.rooms.centre(0).y and network.is_free_socket(network.rooms.socket_of(0, k)):
			head = Vector2(Rules.to_m(at.x), Rules.to_m(at.y))
	assert_true(tool.begin_plan() and tool.cycle_link() == Rules.LINK_RAMP and tool.cycle_link() == Rules.LINK_STAIRS, "the stairs tool")
	assert_true(tool.lay_ground(head) and tool.lay_ground(head + Vector2(0.0, -5.0)) and tool.confirm(), "stairs laid: %s" % tool.notice())
	assert_true(tool.notice().contains("stairs down"), "the notice names them: %s" % tool.notice())
	ViewTest._dig_piece(network, tool._ref[2])
	return tool._ref[0]


func test_each_level_is_drawn_on_its_own_layers() -> void:
	"""Level 2's cap, room, fit-out, passage and marks are on level 2's layers, level 1's on level 1's; the stairs are
	drawn on both, each copy in its own level's earth; the lower home has nothing on the ground."""
	var s := _village_below()
	var tool: ControlScript = s["v"]["tool"]
	var network: GraphScript = tool.network
	var lower: int = s["lower"]
	for node: VisualInstance3D in [tool.view.caps[2].cap(), tool.view.caps[2].deep(), tool.view.caps[2].light()]:
		assert_equal(node.layers, Layers.UNDERGROUND_2, "level 2's %s" % node.name)
	assert_equal(tool.view.caps[1].cap().layers, Layers.UNDERGROUND, "level 1's cap")
	assert_almost_equal(tool.view.caps[2].cap().position.y, Layers.cap_y(Rules.LEVEL_2), "at level 2's section")
	for piece: Node in tool.ext.room_view.below(lower).find_children("*", "VisualInstance3D", true, false):
		assert_equal((piece as VisualInstance3D).layers, Layers.UNDERGROUND_2, "the lower home's %s" % piece.name)
	for f in RoomsScript.fixture_count(RoomsScript.TEMPLATE_HOME):
		for node: Node in tool.ext.fixture_view.piece(lower, f).find_children("*", "VisualInstance3D", true, false):
			assert_equal((node as VisualInstance3D).layers, Layers.UNDERGROUND_2, "its fixture's %s" % node.name)
	assert_equal(tool.ext.room_view.shell(lower).material_override, BoreViewScript.hub_material(Rules.LEVEL_2), "level 2's earth")
	assert_false(tool.ext.room_view.above(lower).visible or tool.ext.fixture_view.chimney(lower).visible, "nothing on the ground")
	var stairs: int = s["stairs"]
	var bores: BoreViewScript = tool.overlay.bores
	assert_equal([bores.chunk(stairs, 0).layers, bores.twin(stairs, 0).layers], [Layers.UNDERGROUND, Layers.UNDERGROUND_2], "the stairs on both")
	assert_equal([bores.chunk(stairs, 0).material_override, bores.twin(stairs, 0).material_override],
		[BoreViewScript.earth_material(1), BoreViewScript.earth_material(2)], "each in its level's earth")
	assert_true(bores.chunk(stairs, 0).visible and bores.twin(stairs, 0).mesh == bores.chunk(stairs, 0).mesh, "one mesh, shown")
	assert_equal(bores.stairs.steps(stairs).multimesh.visible_instance_count, Rules.STAIR_RISERS, "sixteen treads")
	assert_equal([bores.stairs.steps(stairs).layers, bores.stairs.steps(stairs, true).layers], [Layers.UNDERGROUND, Layers.UNDERGROUND_2], "on both")
	var passage := network.rooms.door[lower]
	var way: int = network.node_segment(passage, 0) if network.node_segment(passage, 0) != network.rooms.body[lower] else network.node_segment(passage, 1)
	assert_equal([bores.chunk(way, 0).layers, bores.chunk(way, 0).material_override], [Layers.UNDERGROUND_2, BoreViewScript.earth_material(2)], "the passage below")


func test_a_go_to_on_a_level_2_tunnel_shows_its_level() -> void:
	"""The news's "Go to" on a tunnel (demo_village.gd `select_tunnel`, decision 0331) reveals its level in the U view:
	a level-2 passage from level 1 shows level 2; the stairs, seen from both, never switch; with the view off nothing
	moves."""
	var s := _village_below()
	var tool: ControlScript = s["v"]["tool"]
	var network: GraphScript = tool.network
	var lower: int = s["lower"]
	var passage := network.rooms.door[lower]
	var way: int = network.node_segment(passage, 0) if network.node_segment(passage, 0) != network.rooms.body[lower] else network.node_segment(passage, 1)
	assert_true(tool.view.on, "the U view is on")
	assert_equal(network.seg_level[way], Rules.LEVEL_2, "the passage is on level 2")
	tool.show_level(Rules.TOP_LEVEL)
	tool.reveal_tunnel(s["stairs"])
	assert_equal(tool.view.level, Rules.TOP_LEVEL, "the stairs are seen from level 1: no switch")
	tool.reveal_tunnel(way)
	assert_equal(tool.view.level, Rules.LEVEL_2, "the passage's level shown")
	tool.reveal_tunnel(way)
	assert_equal(tool.view.level, Rules.LEVEL_2, "already shown: kept")
	tool.show_level(Rules.TOP_LEVEL)
	tool.toggle_view()
	tool.reveal_tunnel(way)
	assert_equal(tool.view.level, Rules.TOP_LEVEL, "the view off: nothing moves")
	tool.reveal_tunnel(-1)


func test_level_2_s_rooms_and_marks_stand_on_its_floor() -> void:
	"""The lower home's fit-out and outline stand on level 2's floor, and it has no outline on the ground; level 2's cap is
	shaded from its floor; the stairs' selection line shows from both levels; a link is picked from either level, a bore
	from its own; a room is found under the pointer on its own level only."""
	var s := _village_below()
	var tool: ControlScript = s["v"]["tool"]
	var network: GraphScript = tool.network
	var lower: int = s["lower"]
	var stairs: int = s["stairs"]
	var floor_y := Layers.floor_y(Rules.LEVEL_2)
	assert_almost_equal(tool.ext.fixture_view.place_transform(lower, 0).origin.y, floor_y + FixtureViewScript.FLOOR_LIFT_M, "fit-out")
	assert_almost_equal(tool.ext.room_view.outline_below(lower).position.y, floor_y, "its outline below")
	assert_false(tool.ext.room_view.outline(lower).visible, "none on the ground")
	var shading := tool.view.caps[2].cap().material_override as ShaderMaterial
	assert_almost_equal(float(shading.get_shader_parameter(&"floor_y")), floor_y, "the cap shaded from level 2's floor")
	assert_equal(tool.ext.marks.line_below(stairs).layers, Layers.UNDERGROUND_MARKS | Layers.UNDERGROUND_2_MARKS, "the stairs' line: both")
	var passage: int = network.node_segment(network.rooms.door[lower], 0)
	if passage == network.rooms.body[lower]:
		passage = network.node_segment(network.rooms.door[lower], 1)
	assert_true(tool.ext.actions.on_level(stairs, Rules.LEVEL_1) and tool.ext.actions.on_level(stairs, Rules.LEVEL_2), "a link: both")
	assert_true(tool.ext.actions.on_level(passage, Rules.LEVEL_2) and not tool.ext.actions.on_level(passage, Rules.LEVEL_1), "a bore: its own")
	var middle: Vector2 = network.rooms.centre_m(lower)
	assert_equal(tool.ext.room_at(middle, Rules.LEVEL_2), lower, "found on level 2")
	assert_true(tool.ext.room_at(middle, Rules.LEVEL_1) != lower, "not on level 1")


func test_the_tool_lays_on_the_level_the_view_shows() -> void:
	"""A level set with the view off draws nothing below and the tool lays on level 1; with the U view on level 2 it lays
	there -- a link's head always on level 1; U back to the surface lays on level 1 again; the room tool follows PgUp;
	a held PgDn's repeats are taken and switch nothing; Ctrl+L is not L."""
	var s := _village_below()
	var tool: ControlScript = s["v"]["tool"]
	var camera: Camera3D = s["v"]["camera"]
	_opened_from_the_surface_lays_on_the_level_shown(tool, camera)
	tool.view.set_on(true)
	assert_equal([camera.cull_mask, tool.laying_level(), tool.ext.shown_level()], [Layers.level_mask(2), 2, 2], "on: level 2")
	assert_true(tool.begin_plan() and tool.plan.level == Rules.LEVEL_2, "the tool lays on level 2")
	assert_true(tool.cycle_link() == Rules.LINK_RAMP and tool.plan.level == Rules.TOP_LEVEL, "a link's head: level 1")
	_modified_letters_are_not_the_tool_s(tool)
	tool.cycle_link()
	tool.cycle_link()
	assert_true(tool.handle_input(ViewTest._key(KEY_U)) and not tool.view.on and tool.plan.level == Rules.TOP_LEVEL, "U: lays on level 1")
	assert_true(tool.begin_room(RoomsScript.TEMPLATE_CELLAR) and tool.room.plan.level == Rules.TOP_LEVEL, "a room there too")
	assert_false(tool.begin_room(RoomsScript.TEMPLATE_CELLAR), "C again: back to tunnels")
	assert_true(tool.handle_input(ViewTest._key(KEY_U)) and tool.plan.level == Rules.LEVEL_2, "U again: on level 2")
	tool.begin_room(RoomsScript.TEMPLATE_HOME)
	assert_equal(tool.room.plan.level, Rules.LEVEL_2, "the room tool on level 2")
	assert_true(tool.handle_input(ViewTest._key(KEY_PAGEUP)) and tool.room.plan.level == Rules.TOP_LEVEL, "PgUp: it follows")
	_held_pgdn_switches_nothing(tool)
	tool.cancel_plan()


func _opened_from_the_surface_lays_on_the_level_shown(tool: ControlScript, camera: Camera3D) -> void:
	"""Level 2 set with the view off: nothing below is drawn and the tool would lay on level 1; the tool opened turns
	the view on first, so it lays on level 2 and its ghost stands on level 2's floor. Left with the view off."""
	tool.view.set_on(false)
	tool.view.set_level(Rules.LEVEL_2)
	assert_equal([camera.cull_mask, tool.laying_level(), tool.ext.shown_level()], [Layers.SURFACE_VIEW, 1, 1], "off: the surface's")
	assert_true(tool.begin_plan() and tool.view.on, "the tool opened from the surface turns the view on")
	assert_equal(tool.plan.level, Rules.LEVEL_2, "and lays on the level it shows")
	assert_almost_equal(tool.overlay.plan_below().position.y, Layers.floor_y(Rules.LEVEL_2), "its ghost on that floor")
	tool.cancel_plan()
	tool.view.set_on(false)


func _modified_letters_are_not_the_tool_s(tool: ControlScript) -> void:
	"""With a ramp chosen: Ctrl+L does not cycle the link; Shift+B does not close the tool."""
	var ctrl_l := ViewTest._key(KEY_L)
	ctrl_l.ctrl_pressed = true
	tool.handle_input(ctrl_l)
	assert_equal(tool.link_kind, Rules.LINK_RAMP, "Ctrl+L: no change")
	var shift_b := ViewTest._key(KEY_B)
	shift_b.shift_pressed = true
	tool.handle_input(shift_b)
	assert_true(tool.planning, "Shift+B: the tool stays open")


func _held_pgdn_switches_nothing(tool: ControlScript) -> void:
	"""On level 1 in the U view, a held PgDn's repeat is the tool's (never the camera's zoom) and switches nothing."""
	var held := ViewTest._key(KEY_PAGEDOWN)
	held.echo = true
	assert_true(tool.takes_before_gui(held) and tool.handle_input(held), "a held key's repeat: taken, never the camera's")
	assert_equal(tool.view.level, Rules.TOP_LEVEL, "and switches nothing")


func test_a_level_switch_writes_the_cull_mask_and_builds_nothing() -> void:
	"""In the U view, PgDn and PgUp twenty times over the village: each switch sets the camera's cull mask to the level's
	layers and the indicator's words; no room or bore is rebuilt; no drawn node's material, transparency, visibility or
	layers changes -- but the pooled lights, which follow the view's focus to the level shown."""
	var s := _village_below()
	var v: Dictionary = s["v"]
	var tool: ControlScript = v["tool"]
	tool.view.set_on(true)
	(v["command"] as Node)._age_markers(60.0)
	_helper._frame(v)
	var before := _snapshot_but_lights(v)
	var rooms: int = tool.ext.room_view.shell_builds
	var bores: int = tool.overlay.bore_builds
	for press: int in 20:
		var down := tool.view.level == Rules.TOP_LEVEL
		assert_true(tool.handle_input(ViewTest._key(KEY_PAGEDOWN if down else KEY_PAGEUP)), "switch %d taken" % press)
		_helper._frame(v)
		var level := Rules.LEVEL_2 if down else Rules.TOP_LEVEL
		assert_equal([tool.view.level, Layers.active_level], [level, level], "level %d shown" % level)
		assert_equal((v["camera"] as Camera3D).cull_mask, Layers.level_mask(level), "the mask")
		assert_true(tool.view.indicator_text().contains("Level %d of 2" % level) and tool.view.indicator_shown(), "the indicator")
		assert_true(_snapshot_but_lights(v) == before, "nothing else moved after switch %d" % press)
	assert_equal([tool.ext.room_view.shell_builds, tool.overlay.bore_builds], [rooms, bores], "nothing built by a switch")


func _snapshot_but_lights(v: Dictionary) -> Dictionary:
	"""The village's drawn state (the view suite's snapshot) without the lantern pool's lights, which are handed to the
	spots nearest the focus of the level shown."""
	var state: Dictionary = ViewTest.snapshot_of(_helper._roots(v))
	var lights: Node = (v["tool"] as ControlScript).ext.marks.lights
	for light: Node in lights.get_children():
		state.erase(light.get_instance_id())
		state.erase(-light.get_instance_id())
	return state


func test_pgup_and_pgdn_switch_levels_only_in_the_u_view() -> void:
	"""On the surface PgUp/PgDn are the camera's zoom (not taken); in the U view they switch the level, before the HUD
	and the camera; Alt+PgUp stays the camera's pitch; U still toggles the view, and the indicator shows with it."""
	var s := _village_below()
	var tool: ControlScript = s["v"]["tool"]
	tool.cancel_plan()
	tool.view.set_on(false)
	tool.view.set_level(Rules.TOP_LEVEL)
	var down := ViewTest._key(KEY_PAGEDOWN)
	assert_false(tool.takes_before_gui(down) or tool.handle_input(down), "on the surface: the camera's")
	assert_equal(tool.view.level, Rules.TOP_LEVEL, "no switch")
	assert_false(tool.view.indicator_shown(), "no indicator on the surface")
	assert_true(tool.handle_input(ViewTest._key(KEY_U)) and tool.view.on and tool.view.indicator_shown(), "U: the view, and its indicator")
	assert_true(tool.takes_before_gui(down), "in the U view, before the HUD and the camera")
	assert_true(tool.handle_input(down) and tool.view.level == Rules.LEVEL_2, "PgDn: level 2")
	assert_true(tool.handle_input(down) and tool.view.level == Rules.LEVEL_2, "PgDn at the bottom: taken, still level 2")
	var alt := ViewTest._key(KEY_PAGEUP)
	alt.alt_pressed = true
	assert_false(tool.takes_before_gui(alt) or tool.handle_input(alt), "Alt+PgUp: the camera's pitch")
	assert_true(tool.handle_input(ViewTest._key(KEY_PAGEUP)) and tool.view.level == Rules.TOP_LEVEL, "PgUp: level 1")
	assert_true(tool.notice().contains("level 1 of 2"), "said: %s" % tool.notice())
	_indicator_under_the_alerts(tool)
	assert_true(tool.handle_input(down) and Layers.active_level == Rules.LEVEL_2, "level 2 shown")
	_helper.after_each()
	_helper = null
	assert_equal(Layers.active_level, Rules.TOP_LEVEL, "the view gone: level 1 again for everything that reads it")


func _indicator_under_the_alerts(tool: ControlScript) -> void:
	"""On a 4K screen the level indicator stands centred in the top-centre column, at the HUD's scale, below the band
	the HUD stacks under the alerts at the registry's least sizes -- the pause label and the error panel, ROW_GAP apart
	-- and on a canvas layer under the HUD's, so a grown error panel covers it."""
	var size_px := Vector2(3840.0, 2160.0)
	tool.view.place_indicator_for(size_px)
	var geometry := UiLayout.Geometry.new()
	if not UiLayout.new().compute_into(maxi(int(size_px.x), UiLayout.SUPPORTED_MIN_WIDTH),
			maxi(int(size_px.y), UiLayout.SUPPORTED_MIN_HEIGHT), UiLayout.USER_SCALE_100, false, geometry):
		geometry.scale = 1.0
	var registry := UiRegistry.new()
	var pause := UiRegistry.Size.new()
	var error := UiRegistry.Size.new()
	assert_true(registry.size_into(UiShell.ID_PAUSE_LABEL, pause) and registry.size_into(UiShell.ID_ERROR_PANEL, error), "sizes")
	var alerts: Rect2 = geometry.alerts
	var band_end := alerts.end.y + UiShell.ROW_GAP + pause.min_height + UiShell.ROW_GAP + error.min_height
	var rect: Rect2 = tool.view.indicator_rect()
	assert_true(rect.size.x > 0.0 and rect.position.y >= band_end * geometry.scale, "below the error panel's band: %s, %.0f" % [rect, band_end])
	assert_true(absf(rect.get_center().x - alerts.get_center().x * geometry.scale) < 1.0, "centred under them")
	assert_true(geometry.scale > 1.0 and tool.view.indicator_scale() == geometry.scale, "at the HUD's scale (%.2f)" % geometry.scale)
	assert_true(tool.view.indicator_layer() < _hud_layer(), "under the HUD's canvas layer")


static func _hud_layer() -> int:
	"""The HUD scene's canvas layer (hud.tscn's root), read from a copy freed at once."""
	var hud := (load(HUD_SCENE) as PackedScene).instantiate() as CanvasLayer
	var layer := hud.layer
	hud.free()
	return layer


func test_clicks_land_on_the_shown_level_s_floor() -> void:
	"""The U view picks on the floor of the level it shows: a ray from 10 m up meets level 2's floor 15.25 m on; the
	command layer's orders and the view's own plane agree; the focus is on that floor."""
	var s := _village_below()
	var tool: ControlScript = s["v"]["tool"]
	tool.view.set_on(true)
	var origin := Vector3(0.0, 10.0, 0.0)
	var direction := Vector3(0.0, -1.0, -1.0).normalized()
	for level: int in [Rules.TOP_LEVEL, Rules.LEVEL_2]:
		tool.view.set_level(level)
		assert_almost_equal(tool.view.pick_y(), Layers.floor_y(level), "the plane")
		var at: Vector2 = tool.view.ground_along(origin, direction)
		assert_true(at.distance_to(Vector2(0.0, -(10.0 - Layers.floor_y(level)))) < 1e-4, "level %d: met at %s" % [level, at])
		var eye := Vector3(3.0, 20.0, 5.0)
		var seen := Vector3(3.5, Layers.cap_y(level), 4.0)
		var floor_at: Vector2 = Layers.floor_through(eye, seen, Layers.floor_y(level))
		assert_true(Layers.pick_ground(eye, (seen - eye).normalized(), Layers.floor_y(level)).distance_to(floor_at) < 1e-3,
			"what the cap shows under the pointer is where the click lands, on level %d" % level)
	assert_almost_equal(tool.view.floor_focus(origin, direction, Layers.floor_y(2)).y, -5.25, "the focus on level 2's floor")
	assert_almost_equal(Layers.pick_y(true, Rules.LEVEL_2), -5.25, "the rule")
	assert_almost_equal(Layers.pick_y(false, Rules.LEVEL_2), 0.0, "the surface's is the ground")


func test_the_prewarm_covers_the_second_level_and_registered_it_at_boot() -> void:
	"""Level 2's materials are in the registry before anything is dug on it (at build time, never at a switch): its
	cap, its bores' and hubs' and rooms' earth, the stairs' treads, its frames' and ribs' cutaways. Over the village with
	its second level, every node on level 2's layers is covered."""
	_helper = ViewTest.new()
	var bare: Dictionary = _helper._village()
	var prewarm: PrewarmScript = (bare["tool"] as ControlScript).view.prewarm
	var tool: ControlScript = bare["tool"]
	for material: Material in [tool.view.caps[2].cap().material_override, BoreViewScript.earth_material(2),
			BoreViewScript.hub_material(2), tool.ext.room_view._rib_materials[2], tool.ext.marks._brace_materials[2]]:
		assert_true(prewarm.has_material(material), "registered at boot: %s" % material)
	for surface in StairScript.step_mesh(2).get_surface_count():
		assert_true(prewarm.has_material(StairScript.step_mesh(2).surface_get_material(surface)), "the stairs' tread %d" % surface)
	tool.view.begin_prewarm()
	assert_equal(tool.view.indicator_text(), ViewScript.prewarm_words(), "every level's words drawn under the cover")
	tool.view.end_prewarm()
	assert_equal(tool.view.indicator_text(), ViewScript.level_words(tool.view.level), "then the level's own again")
	_helper.after_each()
	_helper = null
	var s := _village_below()
	var v: Dictionary = s["v"]
	prewarm = (v["tool"] as ControlScript).view.prewarm
	var checked := 0
	for node: VisualInstance3D in _helper._drawn(v):
		var geometry := node as GeometryInstance3D
		if geometry == null or node.layers & (Layers.UNDERGROUND_2 | Layers.UNDERGROUND_2_MARKS) == 0 or ViewTest._is_body(v["cast"], node):
			continue
		checked += 1
		assert_true(prewarm.covers(geometry), "%s (%s under %s) is registered" % [node.name, node.get_class(), node.get_parent().name])
	assert_true(checked > 12, "level 2's drawings were walked (%d)" % checked)


func test_each_cap_outlines_the_other_level_from_its_own_mask() -> void:
	"""Each level's cap reads the other's void mask for a faint outline, and only its own for its cut: the lower home is
	dug in level 2's mask and not level 1's; the stairs' head opens level 1's cap and their foot level 2's."""
	var s := _village_below()
	var tool: ControlScript = s["v"]["tool"]
	var network: GraphScript = tool.network
	var one: CapScript = tool.view.caps[1]
	var two: CapScript = tool.view.caps[2]
	var one_material := one.cap().material_override as ShaderMaterial
	assert_equal(one_material.get_shader_parameter(&"other_void"), two.void_texture(), "level 1 outlines level 2")
	assert_equal((two.cap().material_override as ShaderMaterial).get_shader_parameter(&"other_void"), one.void_texture(), "and back")
	assert_almost_equal(float(one_material.get_shader_parameter(&"other_strength")), CapScript.OTHER_STRENGTH, "faintly")
	var middle: Vector2 = network.rooms.centre_m(s["lower"])
	assert_true(two.is_dug(middle) and not one.is_dug(middle), "the lower home in its own level's mask only")
	var stairs: int = s["stairs"]
	var head: Vector2 = network.point_at(stairs, 0.3)
	var below_one: Vector2 = network.point_at(stairs, 2.0)
	assert_true(one.void_at(head, CapScript.VOID_RHO) > 0.5, "level 1: the head, its void still above level 1's floor")
	assert_true(one.void_at(below_one, CapScript.VOID_RHO) < 0.01, "not 2 m down, 2.85 m deep: under level 1's section")
	assert_true(two.void_at(below_one, CapScript.VOID_RHO) > 0.5 and two.void_at(head, CapScript.VOID_RHO) > 0.5, "level 2: all of it")
	assert_almost_equal(two.rise_range_m(), 4.25, "level 2's rises hold a link's drop")


func test_residents_on_another_level_show_as_markers() -> void:
	"""In the lower home a resident is drawn on level 2's layer with a marker in level 1's view; on the stairs' hidden
	middle it is drawn on neither, a marker in both; on the surface, a marker in both; the command layer picks it at its
	marker on the shown level's floor when it is not on that level."""
	var s := _village_below()
	var v: Dictionary = s["v"]
	var network: GraphScript = (v["tool"] as ControlScript).network
	var actor := v["cast"].actor(2) as DemoActorScript
	var brain := actor.brain
	var way := network.rooms.body[s["lower"]]
	brain._start_travel(way, 0.0, network.length_m(way) * 0.5)
	actor._apply_view()
	assert_equal([brain.view_level(), actor.layers_now(), actor.marker().get_child(0).layers],
		[Rules.LEVEL_2, Layers.UNDERGROUND_2, Layers.UNDERGROUND_MARKS], "below on level 2")
	brain._start_travel(s["stairs"], 2.5, 2.5)
	actor._apply_view()
	assert_equal([brain.view_level(), actor.layers_now(), actor.marker().get_child(0).layers],
		[Layers.BETWEEN_LEVELS, 0, Layers.MARKS_ALL], "between the levels")
	var proxy := PackedFloat32Array([0, 0, 0, 0, 0])
	Layers.active_level = Rules.LEVEL_2
	(v["command"] as Node).proxy_into(brain, Vector3.ZERO, 1.0, true, Vector3.ZERO, proxy)
	assert_almost_equal(proxy[1], Layers.floor_y(Rules.LEVEL_2), "picked at its marker on level 2's floor")
	Layers.active_level = Rules.TOP_LEVEL
	brain._set_underground(false)
	actor._apply_view()
	assert_equal([actor.layers_now(), actor.marker().get_child(0).layers], [Layers.SURFACE, Layers.MARKS_ALL], "up top")


func test_a_resident_on_the_stairs_is_seen_from_the_level_it_is_nearest() -> void:
	"""Just down from the stairs' head a resident is still seen from level 1; just above their foot, from level 2; below,
	its marker shows in the other level's view."""
	var s := _village_below()
	var v: Dictionary = s["v"]
	var network: GraphScript = (v["tool"] as ControlScript).network
	var actor := v["cast"].actor(2) as DemoActorScript
	var brain := actor.brain
	var stairs: int = s["stairs"]
	brain._start_travel(stairs, 0.5, 0.5)
	assert_equal(brain.view_level(), Rules.TOP_LEVEL, "0.5 m down the run: level 1's")
	brain._start_travel(stairs, network.length_m(stairs) - 0.1, network.length_m(stairs) - 0.1)
	assert_equal(brain.view_level(), Rules.LEVEL_2, "at the foot: level 2's")
	actor._apply_view()
	assert_true(actor.marker().visible, "its marker shown below")
	assert_equal(actor.marker().get_child(0).layers, Layers.UNDERGROUND_MARKS, "in level 1's view")


func test_the_surface_signs_are_the_top_level_s() -> void:
	"""Seams and vents are drawn for level 1's tunnels only: never for a link or a level-2 bore."""
	var s := _village_below()
	var tool: ControlScript = s["v"]["tool"]
	var network: GraphScript = tool.network
	var signed := 0
	for slot in Rules.MAX_SEGMENTS:
		if not network.is_tunnel(slot):
			continue
		var top := network.seg_level[slot] == Rules.TOP_LEVEL and network.seg_kind[slot] != GraphScript.SEG_LINK
		assert_equal(tool.ext.signs.signed(slot), top, "segment %d (level %d, kind %d)" % [slot, network.seg_level[slot], network.seg_kind[slot]])
		signed += 1 if top else 0
		if not top:
			assert_equal(tool.ext.signs.seam_key(slot), -1, "no seam for %d" % slot)
	assert_true(signed > 0, "level 1's are signed")


func _walk(space: CastSpaceScript, brain: BrainScript, frames: int, until: Callable) -> Dictionary:
	"""Step `brain` up to `frames` frames until `until()`; which segment kinds and slots it walked, and the frames taken."""
	var kinds := {}
	var slots := {}
	for f in frames:
		brain.step(DT)
		var at: int = space.resident_tunnel[brain.index] if brain.underground else -1
		if at >= 0:
			kinds[space.tunnels.seg_kind[at]] = true
			slots[at] = true
		if bool(until.call()):
			return {"kinds": kinds, "slots": slots, "frames": f + 1}
	return {"kinds": kinds, "slots": slots, "frames": frames}


func test_a_level_2_dig_is_reached_paused_and_resumed_through_the_stairs() -> void:
	"""A digger sent from the surface to a dig starting at the stairs' foot walks down the stairs to it and digs; called
	away it walks out and the dig is kept PAUSED with its progress; resumed, it walks back down and digs on."""
	var graph := _two_levels()
	var space := _field(graph, 1000)
	var ref := _lower_dig(graph)
	var digger := _brain(space, Vector2(-11.0, -9.0), 21)
	graph.start_dig(ref[0], ref[1], digger.index)
	digger.order_dig(ref[0], ref[1])
	var went := _walk(space, digger, 60 * 120, func() -> bool: return digger.activity() == BrainScript.ACTIVITY_DIGGING)
	assert_equal(digger.activity(), BrainScript.ACTIVITY_DIGGING, "digging at the face after %d frames" % went["frames"])
	assert_true(went["kinds"].has(GraphScript.SEG_LINK), "it went down the stairs")
	for f in 600:
		digger.step(DT)
		graph.advance(ref[0], ref[1], 16667)
	var dug := graph.done(ref[0])
	assert_true(dug > 0, "some of it dug")
	digger.release()
	var out := _walk(space, digger, 60 * 120, func() -> bool: return not digger.underground)
	assert_false(digger.underground, "called away, it walked out")
	assert_true(out["kinds"].has(GraphScript.SEG_LINK), "up the stairs")
	assert_equal([graph.phase[ref[0]], graph.done(ref[0])], [GraphScript.PHASE_PAUSED, dug], "kept paused with its progress")
	assert_true(digger.resume_dig(ref[0], ref[1]), "resumed")
	_walk(space, digger, 60 * 120, func() -> bool: return digger.activity() == BrainScript.ACTIVITY_DIGGING)
	assert_equal([digger.activity(), graph.phase[ref[0]]], [BrainScript.ACTIVITY_DIGGING, GraphScript.PHASE_DIGGING], "digging again")


func test_one_on_level_2_walks_out_the_cheapest_way_up() -> void:
	"""A resident 1 m into the level-2 bore from the stairs' foot, told to leave (an evacuation's way out), goes up the
	stairs -- the cheaper way up by the reference's table -- and not the ramp, and out at a mouth to the surface."""
	var graph := _two_levels()
	var space := _field(graph, 1000)
	var brain := _brain(space, Vector2(-11.0, -9.0), 31)
	var lower := -1
	for slot in Rules.MAX_SEGMENTS:
		if graph.is_open(slot) and graph.seg_level[slot] == Rules.LEVEL_2 and graph.seg_kind[slot] == GraphScript.SEG_BORE:
			lower = slot
	brain.order_move(Vector2(-11.0, -9.0))
	brain._start_travel(lower, 1.0, 2.0)
	brain._walk_out()
	var out := _walk(space, brain, 60 * 120, func() -> bool: return not brain.underground)
	assert_false(brain.underground, "out after %d frames" % out["frames"])
	var stairs := first_link(graph, Rules.LINK_STAIRS)
	var ramp := first_link(graph, Rules.LINK_RAMP)
	assert_true(out["slots"].has(stairs) and not out["slots"].has(ramp), "up the stairs, not the ramp")
	var up_stairs := 1.0 + _way_up_m(graph, graph.node_b[stairs])
	var up_ramp := Rules.to_m(graph.cost_u[lower]) - 1.0 + _way_up_m(graph, graph.node_b[ramp])
	assert_true(up_stairs < up_ramp, "the cheaper: %.2f m by the stairs, %.2f by the ramp" % [up_stairs, up_ramp])
	assert_equal(brain.view_level(), Rules.LEVEL_SURFACE, "on the surface")


func _way_up_m(graph: GraphScript, node: int) -> float:
	"""The reference's cheapest way from network node `node` to any mouth (m)."""
	var reference := _reference_table(graph, Vector2.ZERO)
	var ids: Array[int] = reference["ids"]
	var best := INF
	for k in ids.size():
		if graph.node_kind[ids[k]] == GraphScript.NODE_MOUTH:
			best = minf(best, reference["dist"][ids.find(node) + 2][k + 2])
	return best
