extends "res://test/framework/test_case.gd"
## The second level's edges (decision 0212): what test_demo_levels.gd leaves to the boundaries -- a link's slope
## against its drop, the ground at depth's rims, a level-2 room whose passage or body is dropped, the rows a piece
## and a room take, every level filter of the plan's and the rooms' refusals, the readout's ticks and ground for a
## link, and the bore view's blind face, link twins, door cut, hubs and stairs. Headless: no scene tree, no assets;
## every expected value is worked from the named constants or from the fixture itself.

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const PlanScript := preload("res://demo/tunnel/tunnel_plan.gd")
const SpecScript := preload("res://demo/tunnel/piece_spec.gd")
const GroundScript := preload("res://demo/tunnel/tunnel_ground.gd")
const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")
const ReadoutScript := preload("res://demo/tunnel/dig_readout.gd")
const BoreViewScript := preload("res://demo/tunnel/bore_view.gd")
const StairScript := preload("res://demo/tunnel/stair_view.gd")
const CapScript := preload("res://demo/tunnel/underground_cap.gd")
const GroundViewScript := preload("res://demo/tunnel/tunnel_ground_view.gd")
const Layers := preload("res://demo/demo_layers.gd")
const ViewScript := preload("res://demo/tunnel/tunnel_view.gd")
const ControlScript := preload("res://demo/tunnel/tunnel_control.gd")
const GraphTest := preload("res://test/test_demo_graph.gd")
const LevelsTest := preload("res://test/test_demo_levels.gd")

const HOME: int = RoomsScript.TEMPLATE_HOME
const L1: int = Rules.TOP_LEVEL
const L2: int = Rules.LEVEL_2
## Stairs off P's middle, east of it (so a level-2 room's crow-flies mouth and its network's differ), and the home
## on level 2 whose door (turned once: east) faces their foot.
const EAST_HEAD := Vector2i(4096, -8192)
const EAST_FOOT := Vector2i(4096, -3072)
const LOWER_HOME := Vector2i(4096 - 6656, -3072)

var _nodes: Array[Node] = []


func after_each() -> void:
	"""Free every node a test built."""
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()


func _keep(node: Node) -> Node:
	"""Track `node` for freeing."""
	_nodes.append(node)
	return node


func _east_stairs(ground: GroundScript = null) -> GraphScript:
	"""Tunnel P dug, and stairs from EAST_HEAD on it down to a blind foot at EAST_FOOT, dug."""
	var graph := GraphScript.new()
	graph.set_ground(ground)
	var ref := PackedInt32Array([-1, 0, -1])
	assert_true(graph.add_into(LevelsTest.route(LevelsTest.P_ROUTE), 2, 0, ref), "P")
	GraphTest._dig(graph, ref[2])
	var stairs := LevelsTest.plan_of(L1, Rules.LINK_STAIRS)
	assert_equal(LevelsTest.lay(graph, stairs, [EAST_HEAD, EAST_FOOT]), Rules.REFUSE_NONE, "stairs east of P's middle")
	assert_true(LevelsTest.store(graph, stairs) >= 0, "the stairs dug")
	return graph


func _lower_room(graph: GraphScript, dig_passage: bool) -> PackedInt32Array:
	"""A home at LOWER_HOME on level 2 and its passage from EAST_FOOT to its door, adopted (dug when `dig_passage`):
	(room row, room piece, passage piece, passage slot, its generation, the mouth the room spoiled at when laid)."""
	var room := PackedInt32Array([0, 0, 0, 0, 0])
	assert_true(graph.add_room(HOME, LOWER_HOME, 1, 0, room, L2), "a home on level 2")
	var laid_mouth: int = graph.piece_mouth[room[2]]
	assert_true(graph.is_mouth(laid_mouth), "it spoils at a mouth from the first")
	var plan := LevelsTest.plan_of(L2, Rules.LINK_NONE)
	assert_equal(LevelsTest.lay(graph, plan, [EAST_FOOT, graph.node_at(graph.rooms.door[room[0]])]), Rules.REFUSE_NONE, "its passage")
	var ref := PackedInt32Array([-1, 0, -1])
	assert_true(graph.add_piece(plan.spec_of(0), ref), "the passage stored")
	graph.adopt_passage(room[2], ref[2])
	if dig_passage:
		GraphTest._dig(graph, ref[2])
	return PackedInt32Array([room[0], room[2], ref[2], ref[0], ref[1], laid_mouth])


static func _link(graph: GraphScript, kind: int) -> int:
	"""The first link segment of `kind` (-1: none)."""
	return LevelsTest.first_link(graph, kind)


# --- the rules and the ground --------------------------------------------------------------------------

func test_a_link_s_slope_is_the_rate_of_its_drop() -> void:
	"""`link_slope` is `link_drop_m`'s rate of fall everywhere along a ramp -- its eased fillets too -- and stairs, and 0
	at and past either end."""
	var fillet := Rules.to_m(Rules.RAMP_FILLET_U)
	var h := 0.001
	for kind: int in [Rules.LINK_RAMP, Rules.LINK_STAIRS]:
		var run := Rules.to_m(Rules.link_min_run_u(kind)) + 0.5
		for end: float in [-0.5, 0.0, run, run + 0.5]:
			assert_almost_equal(Rules.link_slope(kind, end, run), 0.0, "%s: level at %.2f m" % [Rules.LINK_NAMES[kind], end])
		for along: float in [0.2, fillet * 0.5, run * 0.5, run - fillet * 0.5, run - 0.2]:
			var rate := (Rules.link_drop_m(kind, along + h, run) - Rules.link_drop_m(kind, along - h, run)) / (2.0 * h)
			assert_true(absf(rate - Rules.link_slope(kind, along, run)) < 1e-3,
				"%s at %.2f m: %.4f vs %.4f" % [Rules.LINK_NAMES[kind], along, Rules.link_slope(kind, along, run), rate])


func test_a_clay_lens_spreads_wider_below() -> void:
	"""Past a clay lens's rim, inside DEEP_CLAY_PERMILLE of its radius, the ground is clay on level 2 and not on level 1."""
	var ground := GroundScript.new()
	var lens: Vector3i = GroundScript.CLAY_PATCHES[0]
	var rim := Vector2i(12083, -2048)
	var off := Vector2(rim - Vector2i(lens.x, lens.y)).length()
	assert_true(off > lens.z and off < lens.z * GroundScript.DEEP_CLAY_PERMILLE / 1000.0, "past its rim, within 1.4 of it")
	for deep: Vector3i in GroundScript.DEEP_CLAY_PATCHES:
		assert_true(Vector2(rim - Vector2i(deep.x, deep.y)).length() > deep.z, "in no lens of its own below")
	assert_equal(ground.type_at_level(rim.x, rim.y, L2), GroundScript.CLAY, "clay below")
	assert_true(ground.type_at_level(rim.x, rim.y, L1) != GroundScript.CLAY, "not above")


func test_the_layers_place_each_level() -> void:
	"""Each level's section is its floor and the widened bore's crown, the spacing apart; the U view on level 2 draws
	level 2's layers; a height belongs to level 2 at or under the middle of the spacing."""
	assert_almost_equal(Layers.cap_y(L2), Rules.level_floor_m(L2) + (Layers.CAP_Y_M - Layers.FLOOR_Y_M), "level 2's section")
	assert_almost_equal(Layers.cap_y(L1) - Layers.cap_y(L2), Rules.to_m(Rules.LEVEL_SPACING_U), "the spacing apart")
	assert_equal(Layers.view_mask(true, L2), Layers.UNDERGROUND_2 | Layers.UNDERGROUND_2_MARKS, "level 2's view")
	assert_equal(Layers.view_mask(false, L2), Layers.SURFACE_VIEW, "the surface's")
	var middle := (Layers.floor_y(L1) + Layers.floor_y(L2)) * 0.5
	assert_equal([Layers.level_at(middle + 0.01), Layers.level_at(middle), Layers.level_at(Layers.floor_y(L2))], [L1, L2, L2],
		"either side of the middle")


func test_the_words_carry_the_candidate_numbers() -> void:
	"""The words naming the spacing and the links' sizes say what the constants say -- the spacing is a candidate, and a
	change to it must change them: the indicator's floors, a short ramp's drop and least run, the stairs' risers, and
	the longest runs."""
	assert_true(ViewScript.level_words(L2).contains("floor %s m down" % String.num(-Rules.level_floor_m(L2), 2)), "the indicator")
	var ramp := Rules.link_text(Rules.REFUSE_RAMP_SHORT, "")
	assert_true(ramp.contains("going %s m down" % _m(Rules.LEVEL_SPACING_U)), "the drop: %s" % ramp)
	assert_true(ramp.contains("%.1f m" % Rules.to_m(Rules.link_min_run_u(Rules.LINK_RAMP))), "the least run: %s" % ramp)
	var stairs := Rules.link_text(Rules.REFUSE_STAIRS_SHORT, "")
	assert_true(stairs.contains("%d timber risers of %s m" % [Rules.STAIR_RISERS, _m(Rules.STAIR_RISE_U)]), stairs)
	assert_true(stairs.contains("%s m of run" % _m(Rules.link_min_run_u(Rules.LINK_STAIRS))), stairs)
	var long := Rules.link_text(Rules.REFUSE_LINK_LONG, "")
	assert_true(long.contains("at most %s m, stairs at most %s m" % [_m(Rules.link_max_run_u(Rules.LINK_RAMP)),
		_m(Rules.link_max_run_u(Rules.LINK_STAIRS))]), long)
	assert_true(ControlScript.LINK_OPEN[Rules.LINK_STAIRS].contains("%d timber risers" % Rules.STAIR_RISERS), "the stairs' notice")
	for level in range(L1, Rules.DEEPEST_LEVEL + 1):
		assert_true(ViewScript.prewarm_words().contains(ViewScript.level_words(level)), "level %d's words drawn at boot" % level)


static func _m(u: int) -> String:
	"""A length (u) in metres as the words write it: to the hundredth, no trailing zeros ("4", "0.25")."""
	var text := "%.2f" % Rules.to_m(u)
	return text.rstrip("0").rstrip(".")


# --- a level-2 room dropped ----------------------------------------------------------------------------

func test_a_dropped_level_2_room_leaves_its_door_a_blind_end() -> void:
	"""The passage dug, the room called away before its first tick: the room is dropped, its door left as the passage's
	BLIND END on level 2 belonging to no room (its row taken again by another room changes nothing there), and a bore
	may be dug on from it."""
	var graph := _east_stairs()
	var s := _lower_room(graph, true)
	var door: int = graph.rooms.door[s[0]]
	var body: int = graph.rooms.body[s[0]]
	assert_true(graph.start_dig(body, graph.generation[body], 0), "the room begun")
	graph.stop_digging(body, graph.generation[body])
	assert_false(graph.rooms.is_room(s[0]), "called away before a tick: dropped")
	assert_equal([graph.node_kind[door], graph.node_room[door], graph.node_level[door], graph.degree(door)],
		[GraphScript.NODE_END, -1, L2, 1], "its door the passage's blind end")
	var again := PackedInt32Array([0, 0, 0, 0, 0])
	assert_true(graph.add_room(HOME, Vector2i(-12288, 8192), 0, 0, again, L2) and again[0] == s[0], "its row taken again")
	assert_equal(graph.node_room[door], -1, "nothing of it at the old door")
	var on := LevelsTest.plan_of(L2, Rules.LINK_NONE)
	var from := graph.node_at(door)
	assert_equal(LevelsTest.lay(graph, on, [from, from + Vector2i(-3072, 0)]), Rules.REFUSE_NONE, "dug on from")
	assert_equal([on.snap_kind[0], on.snap_ref[0]], [SpecScript.END_NODE, door], "from the old door")


func test_a_passage_dropped_unbroken_takes_its_level_2_room_with_it() -> void:
	"""Adopted, the room spoils where its passage does (not where it did alone); the passage called away before its first
	tick is dropped and the room with it -- nothing is left to dig. A passage begun is kept, and its room; a room begun
	is never dropped as unbroken."""
	var graph := _east_stairs()
	var s := _lower_room(graph, false)
	var body: int = graph.rooms.body[s[0]]
	assert_true(graph.piece_mouth[s[2]] != s[5], "the network's mouth is not the crow's")
	assert_equal([graph.spoil_mouth[body], graph.piece_mouth[s[1]]], [graph.piece_mouth[s[2]], graph.piece_mouth[s[2]]], "spoiled with it")
	assert_true(graph.start_dig(s[3], s[4], 0), "the passage begun")
	graph.stop_digging(s[3], s[4])
	assert_equal([graph.piece_live[s[2]], graph.piece_live[s[1]], graph.rooms.is_room(s[0])], [0, 0, false], "both dropped")
	assert_equal(graph.next_dig_for(0), -1, "nothing left to dig")
	var kept := _lower_room(graph, false)
	graph.start_dig(kept[3], kept[4], 0)
	graph.advance(kept[3], kept[4], 1000000)
	graph.stop_digging(kept[3], kept[4])
	assert_equal([graph.phase[kept[3]], graph.piece_live[kept[1]]], [GraphScript.PHASE_PAUSED, 1], "a passage begun: kept")
	GraphTest._dig(graph, kept[2])
	var dug: int = graph.rooms.body[kept[0]]
	graph.start_dig(dug, graph.generation[dug], 0)
	graph.advance(dug, graph.generation[dug], 1000000)
	assert_false(graph.drop_unbroken(kept[1]), "a room begun is never dropped unbroken")
	assert_true(graph.rooms.is_room(kept[0]), "still there")


func test_a_passage_outliving_its_room_takes_no_other_room_with_it() -> void:
	"""The room dropped first (called away from its body before a tick) while its passage is not yet begun: a new room
	laid in its freed rows is not the passage's; the passage dropped later leaves the new room standing."""
	var graph := _east_stairs()
	var s := _lower_room(graph, false)
	var body: int = graph.rooms.body[s[0]]
	graph.start_dig(body, graph.generation[body], 0)
	graph.stop_digging(body, graph.generation[body])
	assert_equal([graph.piece_live[s[1]], graph.piece_adopter[s[2]]], [0, -1], "the room gone, the passage nobody's")
	var again := PackedInt32Array([0, 0, 0, 0, 0])
	assert_true(graph.add_room(HOME, Vector2i(-12288, 8192), 0, 0, again, L2), "another room")
	assert_equal(again[2], s[1], "in the freed piece row")
	graph.start_dig(s[3], s[4], 0)
	graph.stop_digging(s[3], s[4])
	assert_equal(graph.piece_live[s[2]], 0, "the passage dropped")
	assert_true(graph.rooms.is_room(again[0]) and graph.piece_live[again[2]] == 1, "the new room stands")


func test_a_passage_is_never_dropped_from_under_a_room_begun() -> void:
	"""A level-2 room whose body was begun before its passage (a digger sent to it first): the passage called away before
	its own first tick is kept PAUSED, not dropped -- dropping it would strand a half-dug room."""
	var graph := _east_stairs()
	var s := _lower_room(graph, false)
	var body: int = graph.rooms.body[s[0]]
	graph.start_dig(body, graph.generation[body], 1)
	graph.advance(body, graph.generation[body], 1000000)
	assert_true(graph.done(body) > 0, "the room begun")
	assert_false(graph.unbroken(s[2]), "its passage is not unbroken: its room is not")
	graph.start_dig(s[3], s[4], 0)
	graph.stop_digging(s[3], s[4])
	assert_equal([graph.piece_live[s[2]], graph.phase[s[3]]], [1, GraphScript.PHASE_PAUSED], "the passage kept, paused")
	assert_false(graph.drop_unbroken(s[2]), "nor dropped as unbroken")
	assert_true(graph.rooms.is_room(s[0]), "the room stands")


func test_a_level_2_room_goes_in_from_the_surface_at_its_passage_s_mouth() -> void:
	"""A level-2 room's entrance from the surface (its pantry's place) is the mouth its passage spoils at, not where its
	door would open on level 1."""
	var graph := _east_stairs()
	var s := _lower_room(graph, true)
	var mouth: int = graph.piece_mouth[s[1]]
	assert_equal(graph.rooms.entrance_u(graph, s[0]), graph.node_at(graph.mouth_node[mouth]), "its passage's mouth")
	assert_true(graph.rooms.entrance_u(graph, s[0]) != graph.rooms.mouth_u(s[0]), "not a door of its own")


# --- the rows -------------------------------------------------------------------------------------------

func test_the_rows_a_level_2_room_and_a_blind_piece_take() -> void:
	"""A level-2 room takes no mouth row; a piece ending blind takes a node row for its blind end: one row short of what
	storing it takes, it is refused, and with exactly that many it is not."""
	var bare := GraphScript.new()
	bare.mouth_node.fill(0)
	assert_true(bare.has_rows_for_room(3, L2) and not bare.has_rows_for_room(3, L1), "no mouth row free: only below")
	var made := _blind_piece_nodes()
	assert_true(made > 0, "storing it takes %d node rows" % made)
	for spare: int in [made - 1, made]:
		var graph := LevelsTest.two_levels(self)
		var spec := _blind_spec(graph)
		var free := graph.node_kind.count(GraphScript.NODE_FREE)
		for node in Rules.MAX_NODES:
			if free > spare and graph.node_kind[node] == GraphScript.NODE_FREE:
				graph.node_kind[node] = GraphScript.NODE_JUNCTION
				free -= 1
		assert_equal(graph.room_for(spec), spare == made, "with %d free node rows" % spare)


func _blind_spec(graph: GraphScript) -> SpecScript:
	"""A level-2 piece from the ramp's foot out east to a blind end."""
	var plan := LevelsTest.plan_of(L2, Rules.LINK_NONE)
	assert_equal(LevelsTest.lay(graph, plan, [LevelsTest.RAMP_FOOT, LevelsTest.RAMP_FOOT + Vector2i(4096, 0)]), Rules.REFUSE_NONE, "blind")
	return plan.spec_of(0)


func _blind_piece_nodes() -> int:
	"""How many node rows storing `_blind_spec` takes."""
	var graph := LevelsTest.two_levels(self)
	var spec := _blind_spec(graph)
	var before := graph.node_kind.count(GraphScript.NODE_FREE)
	var ref := PackedInt32Array([-1, 0, -1])
	assert_true(graph.add_piece(spec, ref), "stored")
	return before - graph.node_kind.count(GraphScript.NODE_FREE)


# --- a link through the ground at depth -------------------------------------------------------------------

func test_a_link_through_deep_ground_is_cut_and_read_out_in_it() -> void:
	"""Stairs whose lower half runs through ground that differs between the levels: each quantum is cut in its own
	level's ground, and the readout's metres of each ground and its hours (at the stairs' work) are the dig's."""
	var ground := GroundScript.new()
	var x := _where_the_depths_differ(ground)
	assert_true(x != Rules.MAX_LENGTH_U, "a run under P whose ground differs below")
	var graph := GraphScript.new()
	graph.set_ground(ground)
	var p := PackedInt32Array([-1, 0, -1])
	assert_true(graph.add_into(LevelsTest.route(LevelsTest.P_ROUTE), 2, 0, p), "P")
	GraphTest._dig(graph, p[2])
	var stairs := LevelsTest.plan_of(L1, Rules.LINK_STAIRS)
	assert_equal(LevelsTest.lay(graph, stairs, [Vector2i(x, -8192), Vector2i(x, -3072)]), Rules.REFUSE_NONE, "stairs there")
	var tally := ReadoutScript._tally()
	ReadoutScript.tally_into(stairs, ground, tally)
	var ref := PackedInt32Array([-1, 0, -1])
	assert_true(graph.add_piece(stairs.spec_of(0), ref), "stored")
	var metres := PackedInt64Array([0, 0, 0, 0])
	var ticks := 0
	var differs := 0
	for k in graph.timeline_count(ref[0]):
		var at := graph.quantum_point_u(ref[0], k)
		var kind := graph.quantum_kind(ref[0], k)
		assert_equal(kind, ground.type_at_level(at.x, at.y, graph.quantum_level(ref[0], k)), "quantum %d" % k)
		differs += 1 if kind != ground.type_at(at.x, at.y) else 0
		metres[kind] += 1
		ticks += GroundScript.dig_ticks(kind)
	assert_true(differs > 0, "some cut in ground level 1 has not")
	assert_equal(tally.slice(ReadoutScript.T_METRES, ReadoutScript.T_METRES + 4), metres, "the readout's ground is the dig's")
	assert_equal(tally[ReadoutScript.T_TICKS], ticks * Rules.link_work_permille(Rules.LINK_STAIRS) / Rules.PERMILLE, "its hours")


static func _where_the_depths_differ(ground: GroundScript) -> int:
	"""The first x (u) on P, a junction's gap clear of its ramps' feet, where stairs from P down 5 m of run would cut a
	quantum on level 2 (the lower half of the drop) in ground that differs between the levels (MAX_LENGTH_U: none)."""
	var run := 5120
	var q := Rules.link_quanta(run)
	for x in range(-4096, 4097, 256):
		for k in q:
			var along := (2 * k + 1) * run / (2 * q)
			var z := -8192 + along
			if 2 * Rules.link_drop_u(Rules.LINK_STAIRS, along, run) >= Rules.LEVEL_SPACING_U \
					and ground.type_at(x, z) != ground.type_at_level(x, z, L2):
				return x
	return Rules.MAX_LENGTH_U


# --- the plan's level filters -------------------------------------------------------------------------------

func test_a_level_2_point_opens_no_mouth_and_a_level_1_end_is_no_blind_end() -> void:
	"""A point laid on level 2 opens no mouth, so an obstacle on the ground does not block it (on level 1 it does); a
	level-1 piece's loose end opens a mouth and is not blind; a mouth counts as level 1's node only."""
	var circle := PackedInt32Array([-8192, 1024, 4096])
	var lower := LevelsTest.plan_of(L2, Rules.LINK_NONE)
	assert_equal(lower.try_add_snapped(-8192, 4096, SpecScript.END_NEW_MOUTH, -1, LevelsTest.BOUNDS_U, circle),
		Rules.REFUSE_NONE, "level 2: nothing on the ground blocks it")
	var upper := LevelsTest.plan_of(L1, Rules.LINK_NONE)
	assert_equal(upper.try_add_snapped(-8192, 4096, SpecScript.END_NEW_MOUTH, -1, LevelsTest.BOUNDS_U, circle),
		Rules.REFUSE_ENTRANCE_BLOCKED, "level 1: its mouth would be blocked")
	var tunnel := LevelsTest.plan_of(L1, Rules.LINK_NONE)
	for x: int in [-8192, 4096]:
		tunnel.try_add_snapped(x, 8192, SpecScript.END_NEW_MOUTH, -1, LevelsTest.BOUNDS_U, PackedInt32Array())
	assert_true(tunnel.count == 2 and tunnel.ends_at_mouth() and not tunnel.ends_blind(), "a level-1 end opens a mouth")
	var graph := LevelsTest.two_levels(self)
	var mouth: int = graph.node_a[0]
	assert_equal(graph.node_kind[mouth], GraphScript.NODE_MOUTH, "P's west mouth")
	assert_true(PlanScript.on_level_or_mouth(graph, mouth, L1) and not PlanScript.on_level_or_mouth(graph, mouth, L2), "level 1's")


func test_a_level_2_join_minds_level_2_s_nodes_only() -> void:
	"""Right under the shared ramp foot of an 8 m level-1 tunnel T crossing over the level-2 bore, a level-2 piece may
	join that bore: no node on level 2 is within a junction's gap."""
	var graph := LevelsTest.two_levels(self)
	var tee := LevelsTest.plan_of(L1, Rules.LINK_NONE)
	assert_equal(LevelsTest.lay(graph, tee, [Vector2i(-4096, 1024), Vector2i(4096, 1024)]), Rules.REFUSE_NONE, "T over it")
	assert_true(LevelsTest.store(graph, tee) >= 0, "T dug")
	var over := -1
	for node in Rules.MAX_NODES:
		if graph.is_node(node) and graph.node_at(node) == Vector2i(0, 1024):
			over = node
	assert_equal([graph.node_kind[over], graph.node_level[over]], [GraphScript.NODE_RAMP_END, L1], "T's ramps' foot, on level 1")
	var branch := LevelsTest.plan_of(L2, Rules.LINK_NONE)
	assert_equal(LevelsTest.lay(graph, branch, [Vector2i(0, 1024), Vector2i(-4096, 1024)]), Rules.REFUSE_NONE, "joined under it")
	assert_equal(branch.snap_kind[0], SpecScript.END_ON_SEGMENT, "on the level-2 bore")


func test_the_pillar_reads_a_link_s_void_from_its_crown_to_its_floor() -> void:
	"""Along the stairs, the band another piece keeps a pillar from runs from their crown to their floor there."""
	var graph := LevelsTest.two_levels(self)
	var stairs := _link(graph, Rules.LINK_STAIRS)
	for along: int in [0, 2560, graph.length_u[stairs]]:
		var floor_u := graph.floor_depth_u_at(stairs, along)
		assert_equal(PlanScript.other_band_u(graph, stairs, graph.point_at_u(stairs, along)),
			Vector2i(floor_u - Rules.BORE_CROWNS_U[graph.bore[stairs]], floor_u), "%d u along" % along)


func test_a_link_breaks_into_a_level_1_room_only_at_its_height() -> void:
	"""Stairs laid straight through a dug level-1 home near their head are refused as breaking into it; stairs passing a
	level-1 home by their foot, 4 m under it, may go."""
	var graph := _east_stairs()
	var room := PackedInt32Array([0, 0, 0, 0, 0])
	var through := Vector2i(-6144, -5632)
	assert_true(graph.add_room(HOME, through, 1, 0, room), "a home across the way down")
	GraphTest._dig(graph, room[2])
	var into := LevelsTest.plan_of(L1, Rules.LINK_STAIRS)
	assert_equal(LevelsTest.lay(graph, into, [Vector2i(-6144, -8192), Vector2i(-6144, -3072)]), Rules.REFUSE_INTO_ROOM, "through it")
	var apart := _east_stairs()
	var foot := Vector2i(-2048, -3072)
	var beside := foot + Vector2i(8192, 0)
	while RoomsScript.gap_u(HOME, beside, 1, foot) > 768:
		beside.x -= 128
	var near := PackedInt32Array([0, 0, 0, 0, 0])
	assert_true(apart.add_room(HOME, beside, 1, 0, near), "a home %d u from where the stairs land" % RoomsScript.gap_u(HOME, beside, 1, foot))
	GraphTest._dig(apart, near[2])
	var by := LevelsTest.plan_of(L1, Rules.LINK_STAIRS)
	assert_equal(LevelsTest.lay(apart, by, [Vector2i(-2048, -8192), foot]), Rules.REFUSE_NONE, "past it, deep under it (%d)" % by.refused_room)


func test_a_level_1_piece_passes_over_a_level_2_room() -> void:
	"""A level-1 tunnel laid straight over a level-2 room keeps no pillar from it in plan: they are levels apart."""
	var graph := GraphScript.new()
	var room := PackedInt32Array([0, 0, 0, 0, 0])
	assert_true(graph.add_room(HOME, Vector2i(-12288, 2048), 0, 0, room, L2), "a room on level 2")
	var over := LevelsTest.plan_of(L1, Rules.LINK_NONE)
	assert_equal(LevelsTest.lay(graph, over, [Vector2i(-17408, 2048), Vector2i(-7168, 2048)]), Rules.REFUSE_NONE, "over it")


# --- the rooms' level filters -------------------------------------------------------------------------------

func test_a_level_2_room_is_refused_by_its_own_level_s_edges() -> void:
	"""No room on a level that is not; past the village's edge or under the water, a level-2 room is refused; right
	under a level-1 home it is not; nor beside another level-2 room's would-be mouth (it has none); nor by the stairs'
	head, which is at level 1's height there."""
	var graph := LevelsTest.two_levels(self)
	var rooms: RoomsScript = graph.rooms
	var site := RoomsScript.Site.new()
	site.bounds_u = LevelsTest.BOUNDS_U
	for level: int in [Rules.LEVEL_SURFACE, Rules.DEEPEST_LEVEL + 1]:
		assert_equal(rooms.refusal(graph, site, HOME, Vector2i(-12288, 2048), 0, level), RoomsScript.REFUSE_LEVEL, "level %d" % level)
	assert_equal(rooms.refusal(graph, site, HOME, Vector2i(-20480 + 512, 2048), 0, L2), RoomsScript.REFUSE_OUT_OF_BOUNDS, "past the edge")
	site.water = func(_a: Vector2i, _b: Vector2i, _reach: int) -> bool: return true
	assert_equal(rooms.refusal(graph, site, HOME, Vector2i(-12288, 2048), 0, L2), RoomsScript.REFUSE_UNDER_WATER, "under the water")
	site.water = func(_a: Vector2i, _b: Vector2i, reach: int) -> bool: return reach != RoomsScript.HOOD_HALF_U + Rules.BORE_WIDTH_U / 2
	assert_equal(rooms.refusal(graph, site, HOME, Vector2i(-12288, 2048), 0, L1), RoomsScript.REFUSE_UNDER_WATER,
		"on level 1 too, its void (split out of the door ramp's water check for level 2) under the water")
	site.water = Callable()
	var upper := PackedInt32Array([0, 0, 0, 0, 0])
	assert_true(graph.add_room(HOME, Vector2i(-12288, 2048), 0, 0, upper), "a home on level 1")
	assert_equal(rooms.refusal(graph, site, HOME, Vector2i(-12288, 2048), 0, L2), RoomsScript.REFUSE_NONE, "right under it")
	assert_equal(rooms.refusal(graph, site, HOME, Vector2i(0, -11545), 0, L2), RoomsScript.REFUSE_NONE, "by the stairs' head")
	var a_at := Vector2i(-8192, 12288)
	var a := PackedInt32Array([0, 0, 0, 0, 0])
	assert_true(graph.add_room(HOME, a_at, 0, 0, a, L2), "room A on level 2")
	var door_off := RoomsScript.door_at(HOME, a_at, 0) - a_at
	var b_at := RoomsScript.mouth_at(HOME, a_at, 0) + door_off
	assert_equal(RoomsScript.door_at(HOME, b_at, 2), RoomsScript.mouth_at(HOME, a_at, 0), "B's door where A's mouth would be")
	assert_equal(rooms.refusal(graph, site, HOME, b_at, 2, L2), RoomsScript.REFUSE_NONE, "B may go")


func test_a_level_2_nook_minds_only_its_own_level() -> void:
	"""A level-2 home's nook: a building over it, a level-1 home right over it and a level-1 tunnel across it refuse
	nothing."""
	var graph := GraphScript.new()
	var room := PackedInt32Array([0, 0, 0, 0, 0])
	assert_true(graph.add_room(HOME, Vector2i.ZERO, 0, 0, room, L2), "a home on level 2")
	var site := RoomsScript.Site.new()
	site.bounds_u = Rect2i(-65536, -65536, 131072, 131072)
	var tip := graph.rooms.nook_b(room[0], 0)
	site.under_u = PackedInt32Array([tip.x, 512, tip.y])
	assert_equal(graph.rooms.nook_refusal(graph, room[0], 0, site), RoomsScript.NOOK_OK, "a building over it")
	site.under_u = PackedInt32Array()
	var upper := PackedInt32Array([0, 0, 0, 0, 0])
	assert_true(graph.add_room(HOME, Vector2i.ZERO, 2, 0, upper), "a home on level 1 over it")
	assert_equal(graph.rooms.nook_refusal(graph, room[0], 0, site), RoomsScript.NOOK_OK, "a level-1 home over it")
	var ref := PackedInt32Array([-1, 0, -1])
	graph.add_into(PackedInt32Array([tip.x - 8192, tip.y, tip.x + 8192, tip.y]), 2, 0, ref)
	GraphTest._dig(graph, ref[2])
	assert_equal(graph.rooms.nook_refusal(graph, room[0], 0, site), RoomsScript.NOOK_OK, "a level-1 tunnel across it")


# --- the readout, the cap and the stairs drawn ----------------------------------------------------------------

func test_level_2_s_cap_is_coloured_from_level_2_s_ground() -> void:
	"""The lower cap's strata image: inside the ground's grid every pixel is coloured from the level-2 cell there -- the
	deep rock pocket under P's middle is drawn as rock, which level 1's ground there is not."""
	var ground := GroundScript.new()
	var size := int(CapScript.MAP_HALF_M * 2.0)
	var water := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var image := CapScript.deep_image(ground, water)
	var at := Vector2i(0, -8192)
	var px := Vector2i(int(Rules.to_m(at.x) + CapScript.MAP_HALF_M), int(Rules.to_m(at.y) + CapScript.MAP_HALF_M))
	var drawn := image.get_pixelv(px)
	var deep := GroundViewScript.colour_of(ground.cell_byte(at.x, at.y, L2))
	var top := GroundViewScript.colour_of(ground.cell_byte(at.x, at.y, L1))
	assert_true(Vector3(drawn.r - deep.r, drawn.g - deep.g, drawn.b - deep.b).length() < 0.01, "level 2's rock")
	assert_true(Vector3(drawn.r - top.r, drawn.g - top.g, drawn.b - top.b).length() > 0.05, "not level 1's ground")


func test_stairs_treads_stand_as_dug_on_stairs_only() -> void:
	"""Treads stand on stairs only (none on a ramp), one for each tread's length dug, each with its top's middle on the
	walking line half a tread into its own length."""
	var graph := LevelsTest.two_levels(self)
	var view: StairScript = _keep(StairScript.new())
	view.configure(graph)
	var ramp := _link(graph, Rules.LINK_RAMP)
	assert_equal(view.place(ramp, 99.0), 0, "none on a ramp")
	var stairs := _link(graph, Rules.LINK_STAIRS)
	var tread := graph.length_m(stairs) / float(Rules.STAIR_RISERS)
	assert_equal(view.place(stairs, tread * 3.5), 3, "three treads' length dug: three")
	assert_equal(view.place(stairs, graph.length_m(stairs)), Rules.STAIR_RISERS, "all dug: all")
	var step := view.step_transform(stairs, 2, tread)
	assert_almost_equal(step.origin.y, graph.floor_y_at(stairs, tread * 2.5), "tread 2's top on the line, mid-tread")


# --- the bore view on two levels ------------------------------------------------------------------------------

func _bores(graph: GraphScript) -> BoreViewScript:
	"""A bore view of `graph`, out of the tree."""
	var bores: BoreViewScript = _keep(BoreViewScript.new())
	bores.configure(graph)
	return bores


static func _vertices(node: MeshInstance3D) -> int:
	"""How many vertices `node`'s mesh has."""
	var mesh := node.mesh as ArrayMesh
	var n := 0
	for s in mesh.get_surface_count():
		n += (mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	return n


func test_a_blind_end_s_face_goes_when_the_network_runs_on() -> void:
	"""Stairs dug to a blind foot are closed there by a dug face (and are swept half a riser down); a level-2 bore planned
	on from the foot leaves the face, and once dug changes their state: rebuilt they are open there, the face gone."""
	var graph := _east_stairs()
	var stairs := _link(graph, Rules.LINK_STAIRS)
	var bores := _bores(graph)
	assert_almost_equal(bores.floor_offset(stairs), -0.5 * Rules.to_m(Rules.STAIR_RISE_U), "stairs: half a riser down")
	assert_almost_equal(bores.floor_offset(0), 0.0, "a ramp: on its line")
	var run := graph.length_m(stairs)
	var last := BoreViewScript.last_chunk(BoreViewScript.ring_count(run))
	bores.build(stairs, run, 0.0)
	assert_true(bores.ends_blind(stairs), "blind")
	var closed := _vertices(bores.chunk(stairs, last))
	var key := bores.state_key(stairs, 0.0)
	var bits := bores.hub_bits(stairs)
	var on := LevelsTest.plan_of(L2, Rules.LINK_NONE)
	assert_equal(LevelsTest.lay(graph, on, [EAST_FOOT, EAST_FOOT + Vector2i(-4096, 0)]), Rules.REFUSE_NONE, "on from the foot")
	var ref := PackedInt32Array([-1, 0, -1])
	assert_true(graph.add_piece(on.spec_of(0), ref), "planned on from the foot")
	assert_true(bores.ends_blind(stairs) and bores.state_key(stairs, 0.0) == key, "only planned: still closed by its face")
	GraphTest._dig(graph, ref[2])
	assert_false(bores.ends_blind(stairs), "dug: not blind now")
	assert_true(bores.state_key(stairs, 0.0) != key and bores.hub_bits(stairs) == bits - 16, "its state changed, and the overlay's")
	bores.build(stairs, run, 0.0)
	assert_true(_vertices(bores.chunk(stairs, last)) < closed, "rebuilt without its face (%d < %d)" % [_vertices(bores.chunk(stairs, last)), closed])


func test_a_twin_is_drawn_only_while_its_slot_is_a_link() -> void:
	"""A link laid and drawn shows its twin on level 2; dropped unbroken and its slot taken by a level-1 tunnel, the
	twin is hidden."""
	var graph := GraphScript.new()
	var ref := PackedInt32Array([-1, 0, -1])
	graph.add_into(LevelsTest.route(LevelsTest.P_ROUTE), 2, 0, ref)
	GraphTest._dig(graph, ref[2])
	var stairs := LevelsTest.plan_of(L1, Rules.LINK_STAIRS)
	assert_equal(LevelsTest.lay(graph, stairs, [EAST_HEAD, EAST_FOOT]), Rules.REFUSE_NONE, "stairs")
	assert_true(graph.add_piece(stairs.spec_of(0), ref), "laid")
	var slot := ref[0]
	var bores := _bores(graph)
	bores.build(slot, 1.0, 0.0)
	assert_true(bores.twin(slot, 0).visible, "a link's twin shown")
	graph.start_dig(slot, ref[1], 0)
	graph.stop_digging(slot, ref[1])
	graph.add_into(LevelsTest.route(LevelsTest.Q_ROUTE), 2, 0, ref)
	assert_equal([graph.phase[slot] != GraphScript.PHASE_FREE, graph.seg_kind[slot] != GraphScript.SEG_LINK], [true, true], "its slot reused")
	bores.build(slot, 1.0, 0.0)
	assert_true(bores.chunk(slot, 0).visible and not bores.twin(slot, 0).visible, "drawn on level 1 only")


func test_a_level_2_room_s_door_is_cut_open_once_it_breaks_ground() -> void:
	"""The passage to a level-2 room's door is cut by the room's wall from the moment the room breaks ground, not only
	once it is done; and a hub on level 2 is drawn on level 2's layer in its earth."""
	var graph := _east_stairs()
	var s := _lower_room(graph, true)
	var door: int = graph.rooms.door[s[0]]
	var bores := _bores(graph)
	assert_equal(bores.room_cut(door), Vector4.ZERO, "not before")
	var body: int = graph.rooms.body[s[0]]
	graph.start_dig(body, graph.generation[body], 0)
	graph.advance(body, graph.generation[body], 1000000)
	assert_false(graph.rooms.is_done(graph, s[0]), "begun, not done")
	assert_true(bores.room_cut(door) != Vector4.ZERO, "cut open once begun")
	var branch := LevelsTest.plan_of(L2, Rules.LINK_NONE)
	var mid := (EAST_FOOT + graph.node_at(door)) / 2
	assert_equal(LevelsTest.lay(graph, branch, [mid, mid + Vector2i(0, 4096)]), Rules.REFUSE_NONE, "a branch off the passage")
	assert_true(LevelsTest.store(graph, branch) >= 0, "dug")
	bores.refresh_hubs()
	var hub := bores.hub(graph.node_a[_link(graph, Rules.LINK_STAIRS)])
	assert_true(hub != null and hub.layers == Layers.UNDERGROUND, "level 1's hub on level 1")
	var junction := -1
	for node in Rules.MAX_NODES:
		if graph.is_node(node) and graph.node_level[node] == L2 and graph.degree(node) == 3:
			junction = node
	assert_true(junction >= 0 and bores.hub(junction) != null, "a hub at the branch")
	assert_equal([bores.hub(junction).layers, bores.hub(junction).material_override], [Layers.UNDERGROUND_2, BoreViewScript.hub_material(L2)], "level 2's")

