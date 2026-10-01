extends "res://test/framework/test_case.gd"
## The underground as one graph (decision 0208, the underground revamp's P2): the network's tables and
## pieces, splitting a bore at a junction, the dig timeline per segment, spoil per mouth, the job list,
## the Dijkstra paths (with a MOVE-TEST-09-style fixture against an independent reference), the router
## over them, the connection rules and the plan that applies them, the digging skill and the cost readout.
##
## No scene tree and no staged assets. Every expected value is worked by hand from the cited constants
## (113 ticks and 2000 milli-U a quantum, 1024 u a metre) and the demo values named in tunnel_rules.gd.

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const PathsScript := preload("res://demo/tunnel/graph_paths.gd")
const SpecScript := preload("res://demo/tunnel/piece_spec.gd")
const RouterScript := preload("res://demo/tunnel/tunnel_router.gd")
const PlanScript := preload("res://demo/tunnel/tunnel_plan.gd")
const SkillsScript := preload("res://demo/tunnel/dig_skills.gd")
const CrewScript := preload("res://demo/tunnel/tunnel_crew.gd")
const ReadoutScript := preload("res://demo/tunnel/dig_readout.gd")
const GroundScript := preload("res://demo/tunnel/tunnel_ground.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const CastNavScript := preload("res://demo/cast/cast_nav.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const DemoActorScript := preload("res://demo/cast/demo_actor.gd")
const WorksScript := preload("res://demo/tunnel/tunnel_works.gd")

const BOUNDS_U := Rect2i(-20480, -20480, 40960, 40960)
const DT: float = 1.0 / 60.0
const BODY_M: float = 0.25


# --- fixtures -------------------------------------------------------------------------------

static func _route(points: Array[Vector2i]) -> PackedInt32Array:
	"""(x, z) points in u as a flat route."""
	var out := PackedInt32Array()
	for p in points:
		out.append_array([p.x, p.y])
	return out


static func _dig(graph: GraphScript, p: int) -> void:
	"""Dig every segment of piece `p` open, in its order."""
	var chain := PackedInt32Array()
	graph.piece_segments_into(p, chain)
	for slot in chain:
		graph.start_dig(slot, graph.generation[slot], 0)
		graph.advance(slot, graph.generation[slot], 1000000000)


func _main(graph: GraphScript) -> void:
	"""The fixture tunnel: 12 m straight east from the origin, dug open (slots 0 ramp, 1 bore, 2 ramp)."""
	var ref := PackedInt32Array([-1, 0, -1])
	assert_true(graph.add_into(_route([Vector2i(0, 0), Vector2i(12288, 0)]), 2, 0, ref), "the main tunnel stored")
	_dig(graph, ref[2])


static func _branch_spec(host: int, at: Vector2i, to: Vector2i) -> SpecScript:
	"""A piece from a point on segment `host` to a new mouth."""
	var spec := SpecScript.new()
	spec.set_route(_route([at, to]), 2)
	spec.start_kind = SpecScript.END_ON_SEGMENT
	spec.start_ref = host
	return spec


# --- the tables and pieces ------------------------------------------------------------------

func test_a_mouth_to_mouth_piece_is_a_ramp_a_bore_and_a_ramp() -> void:
	"""12 m: a ramp from mouth A down to a foot at 4 m, a bore to a foot at 8 m, a ramp up to mouth B --
	nodes 0 and 1 the mouths (rows 0, 1), 2 and 3 the feet; the first segment digging, the rest planned."""
	var graph := GraphScript.new()
	var ref := PackedInt32Array([-1, 0, -1])
	assert_true(graph.add_into(_route([Vector2i(0, 0), Vector2i(12288, 0)]), 2, 7, ref), "stored")
	assert_equal(ref, PackedInt32Array([0, 0, 0]), "slot 0, generation 0, piece 0")
	assert_equal(Array(graph.seg_kind.slice(0, 3)), [GraphScript.SEG_RAMP, GraphScript.SEG_BORE, GraphScript.SEG_RAMP], "kinds")
	assert_equal(Array(graph.length_u.slice(0, 3)), [4096, 4096, 4096], "a 4 m ramp either end")
	assert_equal([graph.node_a[0], graph.node_b[0], graph.node_a[1], graph.node_b[1], graph.node_a[2], graph.node_b[2]],
		[0, 2, 2, 3, 3, 1], "chained node to node")
	assert_equal([graph.node_kind[0], graph.node_kind[1], graph.node_kind[2]], [GraphScript.NODE_MOUTH, GraphScript.NODE_MOUTH,
		GraphScript.NODE_RAMP_END], "mouths and a ramp's foot")
	assert_equal([graph.node_mouth[0], graph.node_mouth[1], graph.node_mouth[2]], [0, 1, -1], "mouth rows")
	assert_equal(graph.node_at(2), Vector2i(4096, 0), "the first foot 4 m in")
	assert_equal(Array(graph.phase.slice(0, 3)), [GraphScript.PHASE_DIGGING, GraphScript.PHASE_PLANNED, GraphScript.PHASE_PLANNED], "phases")
	assert_equal(graph.digger[0], 7, "its digger")
	assert_equal(graph.piece_digger[0], 7, "the piece's digger")
	assert_equal([graph.degree(0), graph.degree(2)], [1, 2], "degrees")
	assert_equal(graph.end_at(2, true), Vector2(12.0, 0.0), "mouth B in metres")


func test_a_piece_of_exactly_two_ramps_shares_their_foot() -> void:
	"""8 m: the two ramps meet at one foot and there is no bore."""
	var graph := GraphScript.new()
	var ref := PackedInt32Array([-1, 0, -1])
	assert_true(graph.add_into(_route([Vector2i(0, 0), Vector2i(8192, 0)]), 2, 0, ref), "stored")
	var chain := PackedInt32Array()
	graph.piece_segments_into(0, chain)
	assert_equal(chain, PackedInt32Array([0, 1]), "two segments")
	assert_equal([graph.seg_kind[0], graph.seg_kind[1]], [GraphScript.SEG_RAMP, GraphScript.SEG_RAMP], "both ramps")
	assert_equal(graph.node_b[0], graph.node_a[1], "sharing their foot")


func test_add_into_refuses_what_the_rules_refuse() -> void:
	"""One point, a route too short for two ramps (8191 u) and one over 64 m are refused, nothing stored."""
	var graph := GraphScript.new()
	var ref := PackedInt32Array([-1, 0, -1])
	assert_false(graph.add_into(_route([Vector2i(0, 0)]), 1, 0, ref), "one point")
	assert_false(graph.add_into(_route([Vector2i(0, 0), Vector2i(8191, 0)]), 2, 0, ref), "7.99 m")
	assert_false(graph.add_into(_route([Vector2i(-19000, -19000), Vector2i(-19000, 19000), Vector2i(-19000, -8537)]), 3, 0, ref), "65537 u")
	assert_equal(ref, PackedInt32Array([-1, 0, -1]), "untouched")
	assert_equal(graph.phase.count(GraphScript.PHASE_FREE), Rules.MAX_SEGMENTS, "nothing stored")


func test_the_network_refuses_a_piece_it_has_no_room_for() -> void:
	"""Twenty-four mouths is the cap (16 for tunnels and 8 for rooms' doors: decision 0209): twelve tunnels fill
	it, and a thirteenth is refused whole."""
	var graph := GraphScript.new()
	var ref := PackedInt32Array([-1, 0, -1])
	assert_equal(Rules.MAX_MOUTHS, 24, "the cap")
	for k in Rules.MAX_MOUTHS / 2:
		assert_true(graph.add_into(_route([Vector2i(-10000, 1500 * k - 8000), Vector2i(0, 1500 * k - 8000)]), 2, k, ref), "tunnel %d" % k)
	assert_equal(graph.mouth_node.count(-1), 0, "every mouth row taken")
	var spec := SpecScript.new()
	spec.set_route(_route([Vector2i(5000, 0), Vector2i(15000, 0)]), 2)
	assert_false(graph.room_for(spec), "no room for two more mouths")
	assert_false(graph.add_into(_route([Vector2i(5000, 0), Vector2i(15000, 0)]), 2, 0, ref), "a thirteenth refused")
	assert_equal(graph.phase.count(GraphScript.PHASE_FREE), Rules.MAX_SEGMENTS - 36, "nothing more stored")
	assert_false(graph.has_room(), "has_room says so")


# --- the dig timeline -----------------------------------------------------------------------

func test_shafts_only_where_a_segment_meets_a_mouth() -> void:
	"""The first ramp: the entry shaft and four bore quanta (565 ticks); the bore: four (452); the last ramp
	four and the exit shaft (565). Stages follow: ENTRANCE only on the first, EXIT only on the last."""
	var graph := GraphScript.new()
	graph.add_into(_route([Vector2i(0, 0), Vector2i(12288, 0)]), 2, 0, PackedInt32Array([-1, 0, -1]))
	assert_equal([graph.timeline_count(0), graph.timeline_count(1), graph.timeline_count(2)], [5, 4, 5], "quanta")
	assert_equal([graph.total_ticks(0), graph.total_ticks(1), graph.total_ticks(2)], [565, 452, 565], "ticks")
	assert_equal([graph.entry_shafts(0), graph.exit_shafts(0), graph.entry_shafts(2), graph.exit_shafts(2)], [1, 0, 0, 1], "shafts")
	graph.advance(0, 0, 3733333)
	assert_equal(graph.done(0), 111, "3.73 s is 111 ticks")
	assert_equal(graph.stage(0), Rules.STAGE_ENTRANCE, "still the shaft")
	graph.advance(0, 0, 100000)
	assert_equal(graph.stage(0), Rules.STAGE_BORE, "114 ticks: the ramp's bore")
	assert_equal(graph.face_u(0), 9, "a sliver of the first metre: (114 - 113) x 4096 / 452")
	_dig_segment(graph, 0)
	assert_true(graph.start_dig(1, 0, 0), "the bore started")
	assert_equal(graph.stage(1), Rules.STAGE_BORE, "a bore has no shaft")
	_dig_segment(graph, 1)
	graph.start_dig(2, 0, 0)
	graph.advance(2, 0, 15066667)
	assert_equal(graph.stage(2), Rules.STAGE_EXIT, "452 ticks: breaking out")
	assert_equal(graph.face_u(2), 4096, "the face at the mouth")


func _dig_segment(graph: GraphScript, slot: int) -> void:
	"""Dig one segment open."""
	graph.advance(slot, graph.generation[slot], 1000000000)
	assert_true(graph.is_open(slot), "segment %d open" % slot)


func test_spoil_posts_at_the_piece_s_mouth_and_the_exit_s_mouth() -> void:
	"""Every cut of the first two segments and the last ramp's bore spoils at mouth A (5 + 4 + 4 cuts:
	26000 milli-U); only the exit shaft's cut at mouth B (2000)."""
	var graph := GraphScript.new()
	var ref := PackedInt32Array([-1, 0, -1])
	graph.add_into(_route([Vector2i(0, 0), Vector2i(12288, 0)]), 2, 0, ref)
	assert_equal(graph.finished_spoil(0), 26000, "sized for 13 cuts")
	assert_equal(graph.finished_spoil(1), 2000, "sized for the exit's")
	assert_equal(graph.finished_spoil(0, 5000), 31000, "plus what is still to come")
	graph.advance(0, 0, 2500000)
	assert_equal(graph.heaped_milli(0), 2000, "75 ticks: the shaft's cut")
	assert_true(graph.mouth_growing(0) and graph.mouth_growing(1), "both heaps still to grow")
	_dig(graph, 0)
	assert_equal([graph.heaped_milli(0), graph.heaped_milli(1)], [26000, 2000], "all posted")
	assert_false(graph.mouth_growing(0), "done growing")
	graph.add_spoil(1, 3000)
	assert_equal(graph.heaped_milli(0), 29000, "re-digging the bore heaps at its spoil mouth")
	assert_equal(graph.extra_spoil[1], 3000, "and is kept on the segment")


func test_floors_fall_from_a_mouth_and_run_level() -> void:
	"""The first ramp falls from its mouth (node A), the last rises to its (node B), the bore is level."""
	var graph := GraphScript.new()
	graph.add_into(_route([Vector2i(0, 0), Vector2i(12288, 0)]), 2, 0, PackedInt32Array([-1, 0, -1]))
	assert_almost_equal(graph.floor_y_at(0, 0.0), 0.0, "level with the ground at mouth A")
	assert_almost_equal(graph.floor_y_at(0, 2.0), -0.4 * (2.0 - 0.4375), "1:2.5 down the straight")
	assert_almost_equal(graph.floor_y_at(0, 4.0), -1.25, "the foot")
	assert_almost_equal(graph.floor_y_at(1, 2.0), -1.25, "the bore level")
	assert_almost_equal(graph.floor_y_at(2, 0.0), -1.25, "the last ramp's foot")
	assert_almost_equal(graph.floor_y_at(2, 4.0), 0.0, "up at mouth B")
	assert_almost_equal(graph.floor_grade_at(0, 2.0), -0.4, "going down")
	assert_almost_equal(graph.floor_grade_at(2, 2.0), 0.4, "coming up")
	assert_almost_equal(graph.floor_grade_at(1, 2.0), 0.0, "level")
	assert_almost_equal(graph.node_floor_y(2), -1.25, "a foot on level 1's floor")


# --- junctions ------------------------------------------------------------------------------

func test_a_branch_splits_its_open_host_and_the_halves_keep_its_state() -> void:
	"""A branch from the bore's middle (6144, 0) north to a new mouth: the bore splits there -- the first half
	keeps slot 1 and its generation, 2048 u long; the second takes slot 3, braced and lit like it -- and a
	junction of degree three joins them; `last_splits` says so."""
	var graph := GraphScript.new()
	_main(graph)
	graph.set_braced(1)
	graph.set_lit(1)
	var ref := PackedInt32Array([-1, 0, -1])
	assert_true(graph.add_piece(_branch_spec(1, Vector2i(6144, 0), Vector2i(6144, 8192)), ref), "stored")
	assert_equal(graph.last_splits, PackedInt32Array([1, 3, 2048]), "bore 1 split 2 m in, its far half slot 3")
	assert_equal([graph.length_u[1], graph.length_u[3]], [2048, 2048], "two halves")
	assert_equal(graph.generation[1], 0, "the first half keeps its generation")
	assert_true(graph.is_open(1) and graph.is_open(3), "both open")
	assert_true(graph.braced[3] == 1 and graph.lit[3] == 1, "the far half braced and lit")
	var j := graph.node_b[1]
	assert_equal([graph.node_a[3], graph.node_b[3]], [j, 3], "the far half from the junction to the old foot")
	assert_equal(graph.node_kind[j], GraphScript.NODE_JUNCTION, "a junction")
	assert_equal(graph.degree(j), 3, "three bores meet there")
	assert_equal(graph.node_at(j), Vector2i(6144, 0), "at the split")
	assert_equal([graph.seg_kind[ref[0]], graph.node_a[ref[0]]], [GraphScript.SEG_BORE, j], "the branch starts at it")
	assert_equal(graph.spoil_mouth[ref[0]], 0, "spoiling at the network's nearest mouth (A; B ties and loses on its row)")
	assert_equal(graph.dug_degree(j), 2, "the branch has broken no ground there yet")
	_dig(graph, ref[2])
	assert_equal(graph.dug_degree(j), 3, "now it has")


func test_a_piece_through_an_open_bore_makes_a_four_way_crossing() -> void:
	"""A piece from (6144, -6144) to (6144, 6144) crossing the main bore at (6144, 0): the bore splits, the
	piece is cut there too, and the junction joins four segments."""
	var graph := GraphScript.new()
	_main(graph)
	var spec := SpecScript.new()
	spec.set_route(_route([Vector2i(6144, -6144), Vector2i(6144, 6144)]), 2)
	spec.crossings = PackedInt32Array([1, 6144, 0])
	var ref := PackedInt32Array([-1, 0, -1])
	assert_true(graph.add_piece(spec, ref), "stored")
	var chain := PackedInt32Array()
	graph.piece_segments_into(ref[2], chain)
	assert_equal(chain.size(), 4, "a ramp, a bore to the crossing, a bore on, a ramp")
	var x := graph.node_b[chain[1]]
	assert_equal(graph.node_at(x), Vector2i(6144, 0), "cut at the crossing")
	assert_equal(graph.degree(x), 4, "a four-way junction")
	assert_equal(graph.node_a[chain[2]], x, "the piece goes on from it")


func test_a_piece_may_end_at_an_existing_junction() -> void:
	"""A second branch ending at the first branch's junction adds a fourth bore there, splitting nothing."""
	var graph := GraphScript.new()
	_main(graph)
	graph.add_piece(_branch_spec(1, Vector2i(6144, 0), Vector2i(6144, 8192)), PackedInt32Array([-1, 0, -1]))
	var j := graph.node_b[1]
	var spec := SpecScript.new()
	spec.set_route(_route([Vector2i(6144, -8192), Vector2i(6144, 0)]), 2)
	spec.end_kind = SpecScript.END_NODE
	spec.end_ref = j
	assert_true(graph.add_piece(spec, PackedInt32Array([-1, 0, -1])), "stored")
	assert_equal(graph.last_splits.size(), 0, "nothing split")
	assert_equal(graph.degree(j), 4, "four bores meet")


func test_a_piece_dropped_before_breaking_ground_frees_what_it_made() -> void:
	"""Called away before a tick: its segments are freed with their generation bumped, its new mouth and foot
	freed too; the junction it split into its host stays (degree two)."""
	var graph := GraphScript.new()
	_main(graph)
	var ref := PackedInt32Array([-1, 0, -1])
	graph.add_piece(_branch_spec(1, Vector2i(6144, 0), Vector2i(6144, 8192)), ref)
	var j := graph.node_b[1]
	var mouth := graph.node_mouth.find(2)
	graph.start_dig(ref[0], ref[1], 3)
	graph.stop_digging(ref[0], ref[1])
	assert_equal(graph.phase[ref[0]], GraphScript.PHASE_FREE, "its bore freed")
	assert_false(graph.is_ref(ref[0], ref[1]), "the reference is dead")
	assert_false(graph.is_piece(ref[2], 0), "the piece is gone")
	assert_false(graph.is_node(mouth), "its mouth freed")
	assert_false(graph.is_mouth(2), "and its mouth row")
	assert_equal(graph.degree(j), 2, "the junction stays between the halves")


func test_a_piece_with_ground_broken_is_paused_not_dropped() -> void:
	"""With a tick dug the segment waits, PAUSED, and resumes under a new digger."""
	var graph := GraphScript.new()
	var ref := PackedInt32Array([-1, 0, -1])
	graph.add_into(_route([Vector2i(0, 0), Vector2i(12288, 0)]), 2, 3, ref)
	graph.advance(0, 0, 1000000)
	graph.stop_digging(0, 0)
	assert_equal(graph.phase[0], GraphScript.PHASE_PAUSED, "paused")
	assert_equal(graph.pause_reason[0], GraphScript.PAUSED_CALLED_AWAY, "called away")
	assert_equal(graph.done(0), 30, "its second kept")
	assert_false(graph.resume(1, 0, 5), "a planned segment is not resumed")
	assert_true(graph.resume(0, 0, 5), "resumed")
	assert_equal([graph.digger[0], graph.piece_digger[0]], [5, 5], "by its new digger, who takes the piece")
	graph.hold_unreached(0, 0)
	assert_equal(graph.pause_reason[0], GraphScript.PAUSED_UNREACHED, "kept as a plan it could not reach")


func test_a_split_off_half_counts_as_dug_for_its_piece() -> void:
	"""A piece whose open bore was split is never dropped by a later stop on its own planned segments."""
	var graph := GraphScript.new()
	var ref := PackedInt32Array([-1, 0, -1])
	graph.add_into(_route([Vector2i(0, 0), Vector2i(12288, 0)]), 2, 0, ref)
	graph.advance(0, 0, 1000000000)
	graph.start_dig(1, 0, 0)
	graph.advance(1, 0, 1000000000)
	graph.add_piece(_branch_spec(1, Vector2i(6144, 0), Vector2i(6144, 8192)), PackedInt32Array([-1, 0, -1]))
	graph.start_dig(2, 0, 0)
	graph.stop_digging(2, 0)
	assert_equal(graph.phase[2], GraphScript.PHASE_PAUSED, "the last ramp paused, the piece kept")


# --- the job list ---------------------------------------------------------------------------

func test_the_job_list_keeps_pieces_in_the_order_laid() -> void:
	"""Three pieces: the list is them in order; a digger's next is the first undug segment of its first
	piece; a piece dug through leaves the list."""
	var graph := GraphScript.new()
	var ref := PackedInt32Array([-1, 0, -1])
	graph.add_into(_route([Vector2i(0, 0), Vector2i(12288, 0)]), 2, 4, ref)
	graph.add_into(_route([Vector2i(0, 4096), Vector2i(12288, 4096)]), 2, 5, ref)
	graph.add_into(_route([Vector2i(0, 8192), Vector2i(12288, 8192)]), 2, 4, ref)
	var list := PackedInt32Array()
	graph.job_list_into(list)
	assert_equal(list, PackedInt32Array([0, 1, 2]), "in order")
	assert_equal(graph.next_dig_for(4), 0, "digger 4: piece 0's first")
	assert_equal(graph.next_dig_for(9), -1, "nobody else's")
	_dig(graph, 0)
	graph.job_list_into(list)
	assert_equal(list, PackedInt32Array([1, 2]), "piece 0 done")
	assert_equal(graph.next_dig_for(4), 6, "then piece 2's first segment (slot 6)")
	assert_equal(graph.piece_percent(1), 0, "nothing dug of piece 1")
	graph.advance(3, 0, 18833333)
	assert_equal(graph.piece_percent(1), 35, "565 of 1582 ticks: 35%")


# --- the paths ------------------------------------------------------------------------------

func _tee() -> GraphScript:
	"""The main tunnel with a dug branch north from its middle: mouths 0 (A), 1 (B), 2 (the branch's)."""
	var graph := GraphScript.new()
	_main(graph)
	var ref := PackedInt32Array([-1, 0, -1])
	graph.add_piece(_branch_spec(1, Vector2i(6144, 0), Vector2i(6144, 8192)), ref)
	_dig(graph, ref[2])
	return graph


func test_mouth_tables_are_the_cheapest_walks() -> void:
	"""From A to the branch's mouth: 4096 + 2048 + 4096 + 4096 u through ramp 0, bore 1, bore 4, ramp 5."""
	var graph := _tee()
	var paths := graph.paths
	var branch := graph.mouth_node[2]
	assert_equal(paths.dist_u(graph, PathsScript.CLASS_ANY, 0, branch), 14336, "14 m")
	var segs := PackedInt32Array()
	assert_true(paths.path_into(graph, PathsScript.CLASS_ANY, 0, branch, segs), "a path")
	assert_equal(segs, PackedInt32Array([0, 1, 4, 5]), "its segments in order")
	assert_equal(paths.dist_u(graph, PathsScript.CLASS_ANY, 2, graph.mouth_node[1]), 14336, "B is as far the other way")
	assert_equal(paths.nearest_mouth(graph, graph.node_b[1], PathsScript.CLASS_ANY), 0, "6 m to A and to B: the lower row")
	assert_equal(paths.dist_u(graph, PathsScript.CLASS_WIDE, 0, branch), PathsScript.UNREACHED, "no wide bore")
	assert_true(paths.path_between(graph, PathsScript.CLASS_ANY, 2, 3, segs), "foot to foot")
	assert_equal(segs, PackedInt32Array([1, 3]), "through the junction")


func test_paths_follow_light_closure_and_class() -> void:
	"""A lit bore costs its length over 1.1 (rounded up); a closed one is never walked; a widened network
	serves the wide class. Each change is a new revision, so the tables are rebuilt."""
	var graph := _tee()
	var paths := graph.paths
	var branch := graph.mouth_node[2]
	paths.dist_u(graph, PathsScript.CLASS_ANY, 0, branch)
	var built := paths.rebuilds
	graph.set_lit(1)
	assert_equal(paths.dist_u(graph, PathsScript.CLASS_ANY, 0, branch), 4096 + 1862 + 4096 + 4096, "2048 u lit: ceil(2048000 / 1100) = 1862")
	assert_equal(paths.rebuilds, built + 1, "rebuilt once for the new revision")
	paths.dist_u(graph, PathsScript.CLASS_ANY, 1, branch)
	assert_equal(paths.rebuilds, built + 1, "and not again while nothing changes")
	graph.close(4, GraphScript.CLOSED_FLOODED, 0, graph.length_u[4])
	assert_equal(paths.dist_u(graph, PathsScript.CLASS_ANY, 0, branch), PathsScript.UNREACHED, "closed: no way")
	graph.reopen(4)
	for slot in 6:
		graph.set_bore(slot, Rules.BORE_WIDE)
	assert_true(paths.dist_u(graph, PathsScript.CLASS_WIDE, 0, branch) < PathsScript.UNREACHED, "all wide: the otters' way")


func _diamond(upper_first: bool) -> GraphScript:
	"""A 16 m tunnel A-B with its bore closed, its feet X (4096, 0) and Y (12288, 0) joined round both sides:
	over U (8192, 3072) as one bent segment, and under L (8192, -3072) split into two by a branch at
	(6144, -1536) -- both ways 5120 + 5120 = 10240 u exactly."""
	var graph := GraphScript.new()
	var ref := PackedInt32Array([-1, 0, -1])
	graph.add_into(_route([Vector2i(0, 0), Vector2i(16384, 0)]), 2, 0, ref)
	_dig(graph, ref[2])
	graph.close(1, GraphScript.CLOSED_COLLAPSED, 0, 1024)
	var arcs: Array[Vector2i] = [Vector2i(8192, 3072), Vector2i(8192, -3072)]
	if not upper_first:
		arcs.reverse()
	for via in arcs:
		var spec := SpecScript.new()
		spec.set_route(_route([Vector2i(4096, 0), via, Vector2i(12288, 0)]), 3)
		spec.start_kind = SpecScript.END_NODE
		spec.start_ref = 2
		spec.end_kind = SpecScript.END_NODE
		spec.end_ref = 3
		graph.add_piece(spec, ref)
		_dig(graph, ref[2])
	var lower := -1
	for slot in Rules.MAX_SEGMENTS:
		if graph.is_open(slot) and graph.point_count[slot] == 3 and graph.points_u[2 * slot * Rules.MAX_POINTS + 3] < 0:
			lower = slot
	graph.add_piece(_branch_spec(lower, Vector2i(6144, -1536), Vector2i(6144, -9728)), ref)
	_dig(graph, ref[2])
	return graph


func test_equal_paths_tie_on_fewer_segments_whatever_the_order_built() -> void:
	"""SET-MOVE-001 §4's "documented stable tie handling": the two ways round the diamond cost exactly the
	same, so the table takes the one of fewer segments -- over the top -- whichever was dug first."""
	for upper_first: bool in [true, false]:
		var graph := _diamond(upper_first)
		var segs := PackedInt32Array()
		assert_true(graph.paths.path_into(graph, PathsScript.CLASS_ANY, 0, 3, segs), "a way to Y")
		assert_equal(graph.paths.dist_u(graph, PathsScript.CLASS_ANY, 0, 3), 4096 + 10240, "A to X, then round")
		assert_equal(segs.size(), 2, "the ramp and the single segment over the top (upper first: %s)" % upper_first)
		assert_true(graph.points_u[2 * segs[1] * Rules.MAX_POINTS + 3] > 0, "the upper way")
		var chain := PackedInt32Array()
		graph.piece_segments_into(1 if upper_first else 2, chain)
		assert_equal(chain.size(), 1, "the upper arc's piece is its one segment, not the main tunnel's ramp that starts where it ends")


# --- the router over the network (MOVE-TEST-09) ---------------------------------------------

func _open_field_tee(rain_permille: int) -> CastSpaceScript:
	"""An open field and the tee network, every bore lit, walking the surface at `rain_permille`."""
	var space := CastSpaceScript.new()
	space.setup([], [])
	space.tunnels = _tee()
	for slot in 6:
		space.tunnels.set_lit(slot)
	space.tunnels.surface_permille = rain_permille
	return space


static func _route_cost(graph: GraphScript, from: Vector2, out: PackedVector2Array, legs: PackedInt32Array, scale: float) -> float:
	"""What a planned route costs, read back from its waypoints: each surface leg its length times `scale`,
	each segment walked its cost at walk speed (graph_paths.gd `edge_cost_u`)."""
	var total := 0.0
	var at := from
	for k in out.size():
		if legs[k] == RouterScript.SURFACE_LEG:
			total += at.distance_to(out[k]) * scale
		else:
			total += Rules.to_m(PathsScript.edge_cost_u(graph, RouterScript.leg_slot(legs[k])))
		at = out[k]
	return total


static func _reference_cost(graph: GraphScript, from: Vector2, to: Vector2, scale: float) -> float:
	"""The Dijkstra reference, found independently: Floyd-Warshall over the trip's start and goal and every
	node of the network -- a surface edge between any two of the start, the goal and the mouths (straight: the
	field is open), a tunnel edge along every usable segment."""
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
	_reference_surface(graph, ids, dist, from, to, scale)
	_reference_segments(graph, ids, dist)
	for k in n:
		for i in n:
			for j in n:
				dist[i][j] = minf(dist[i][j], dist[i][k] + dist[k][j])
	return dist[0][1]


static func _reference_surface(graph: GraphScript, ids: Array[int], dist: Array[PackedFloat64Array], from: Vector2,
		to: Vector2, scale: float) -> void:
	"""The reference's surface edges: start, goal and every mouth, each to each."""
	var places: Array[Vector2] = [from, to]
	var index: Array[int] = [0, 1]
	for k in ids.size():
		if graph.node_kind[ids[k]] == GraphScript.NODE_MOUTH:
			places.append(graph.node_m(ids[k]))
			index.append(k + 2)
	for a in places.size():
		for b in places.size():
			dist[index[a]][index[b]] = minf(dist[index[a]][index[b]], places[a].distance_to(places[b]) * scale)


static func _reference_segments(graph: GraphScript, ids: Array[int], dist: Array[PackedFloat64Array]) -> void:
	"""The reference's tunnel edges: every usable segment, both ways, at its cost over its speed."""
	for slot in Rules.MAX_SEGMENTS:
		if not graph.is_usable(slot):
			continue
		var a := ids.find(graph.node_a[slot]) + 2
		var b := ids.find(graph.node_b[slot]) + 2
		var cost := Rules.to_m(Rules.ceil_div(graph.cost_u[slot] * Rules.PERMILLE, graph.speed_permille(slot)))
		dist[a][b] = minf(dist[a][b], cost)
		dist[b][a] = minf(dist[b][a], cost)


func test_move_test_09_the_route_equals_the_dijkstra_reference() -> void:
	"""SET-MOVE-001 MOVE-TEST-09: a cheap nonlocal connection -- a lit network (1100 per mille) while rain slows
	the surface to 600 -- is cheaper than the straight-line surface cost a flat octile heuristic assumes, so
	such a heuristic would be inadmissible. The router's route (Dijkstra, h = 0) costs exactly what an
	independent Floyd-Warshall over the same edges finds, from several starts to several goals."""
	var space := _open_field_tee(600)
	var graph := space.tunnels
	var index := space.add_resident(Vector2(-3.0, 1.0), BODY_M)
	graph.set_fit(index, true)
	var scale := 1000.0 / 600.0
	var trips: Array[Array] = [[Vector2(-1.0, 0.5), Vector2(13.0, 0.5)], [Vector2(-1.0, 0.5), Vector2(6.5, 9.0)],
		[Vector2(13.5, -1.0), Vector2(5.5, 8.5)], [Vector2(6.0, 9.5), Vector2(-0.5, -1.0)]]
	var used := 0
	for trip in trips:
		var out := PackedVector2Array()
		var legs := PackedInt32Array()
		space.plan_path(index, trip[0], trip[1], BODY_M, out, legs)
		assert_true(space.nav.last_found, "found %s" % str(trip))
		var got := _route_cost(graph, trip[0], out, legs, scale)
		assert_almost_equal(got, _reference_cost(graph, trip[0], trip[1], scale), "the reference's cost for %s" % str(trip))
		assert_true(got < Vector2(trip[0]).distance_to(trip[1]) * scale, "cheaper than the straight surface")
		used += legs.size() - legs.count(RouterScript.SURFACE_LEG)
	assert_true(used > 0, "the network was used")


func test_move_test_09_ties_resolve_the_same_way_every_time() -> void:
	"""Planned again and again, and with the network's tables rebuilt between, the same trip gets the same
	waypoints and legs (deterministic ties)."""
	var space := _open_field_tee(600)
	var index := space.add_resident(Vector2(-3.0, 1.0), BODY_M)
	space.tunnels.set_fit(index, true)
	var first := PackedInt32Array()
	var out := PackedVector2Array()
	space.plan_path(index, Vector2(-1.0, 0.5), Vector2(6.5, 9.0), BODY_M, out, first)
	for k in 3:
		space.tunnels.set_braced(k)
		var legs := PackedInt32Array()
		var again := PackedVector2Array()
		space.plan_path(index, Vector2(-1.0, 0.5), Vector2(6.5, 9.0), BODY_M, again, legs)
		assert_equal(legs, first, "the same legs (rebuild %d)" % k)
		assert_equal(again, out, "the same waypoints (rebuild %d)" % k)


func test_a_route_through_a_tee_walks_it_segment_by_segment() -> void:
	"""From beside mouth A to beside the branch's mouth: one waypoint per segment walked -- the foot, the
	junction, the branch's foot, its mouth -- then the goal."""
	var space := _open_field_tee(600)
	var graph := space.tunnels
	var index := space.add_resident(Vector2(-3.0, 1.0), BODY_M)
	graph.set_fit(index, true)
	var out := PackedVector2Array()
	var legs := PackedInt32Array()
	space.plan_path(index, Vector2(-1.0, 0.5), Vector2(6.5, 9.0), BODY_M, out, legs)
	assert_equal(legs, PackedInt32Array([-1, 0, 2, 8, 10, -1]), "ramp 0, bore 1, bore 4, ramp 5, all forward")
	assert_equal(out.slice(1, 5), PackedVector2Array([Vector2(4.0, 0.0), Vector2(6.0, 0.0), Vector2(6.0, 4.0), Vector2(6.0, 8.0)]),
		"the foot, the junction, the branch's foot, its mouth")


func test_a_goal_underground_is_reached_only_through_the_network() -> void:
	"""Bound for the junction itself (a node below), the route ends there with a segment leg; with no way in,
	nothing is planned."""
	var space := _open_field_tee(1000)
	var graph := space.tunnels
	var index := space.add_resident(Vector2(-3.0, 1.0), BODY_M)
	graph.set_fit(index, true)
	var j := graph.node_b[1]
	var out := PackedVector2Array()
	var legs := PackedInt32Array()
	space.plan_path(index, Vector2(-1.0, 0.5), graph.node_m(j), BODY_M, out, legs, true, false, j)
	assert_true(space.nav.last_found, "found")
	assert_equal(legs, PackedInt32Array([-1, 0, 2]), "in at A, down the ramp and along the bore")
	assert_equal(out[out.size() - 1], Vector2(6.0, 0.0), "ending at the junction")
	for slot in 6:
		graph.close(slot, GraphScript.CLOSED_FLOODED, 0, 1)
	space.plan_path(index, Vector2(-1.0, 0.5), graph.node_m(j), BODY_M, out, legs, true, false, j)
	assert_false(space.nav.last_found, "all closed: no way")
	assert_equal(out.size(), 0, "nothing to walk")


func test_nobody_goes_in_at_a_mouth_someone_stands_on() -> void:
	"""With someone standing on mouth A, a trip that would go in there goes in at another mouth or walks."""
	var space := _open_field_tee(600)
	var graph := space.tunnels
	var walker := space.add_resident(Vector2(-3.0, 1.0), BODY_M)
	graph.set_fit(walker, true)
	var blocker := space.add_resident(Vector2(0.0, 0.0), BODY_M)
	var out := PackedVector2Array()
	var legs := PackedInt32Array()
	space.plan_path(walker, Vector2(-1.0, 0.5), Vector2(6.5, 9.0), BODY_M, out, legs)
	assert_false(legs.has(0), "not in at A (its ramp's forward leg)")
	space.move_resident(blocker, Vector2(-6.0, -6.0))
	space.plan_path(walker, Vector2(-1.0, 0.5), Vector2(6.5, 9.0), BODY_M, out, legs)
	assert_true(legs.has(0), "clear again: in at A")


# --- the connection rules (tunnel_rules.gd) ---------------------------------------------------

func test_meeting_angles_are_forty_degrees_either_way() -> void:
	"""|sin| of 40 degrees is 0.6428: 41 degrees meets squarely, 39 does not; branches from one junction keep
	40 degrees apart (cos 0.766)."""
	var east := Vector2i(10000, 0)
	var at_41 := Vector2i(roundi(10000.0 * cos(deg_to_rad(41.0))), roundi(10000.0 * sin(deg_to_rad(41.0))))
	var at_39 := Vector2i(roundi(10000.0 * cos(deg_to_rad(39.0))), roundi(10000.0 * sin(deg_to_rad(39.0))))
	assert_true(Rules.meets_squarely(east, at_41), "41")
	assert_false(Rules.meets_squarely(east, at_39), "39")
	assert_true(Rules.meets_squarely(east, -at_41), "41 the other way round")
	assert_true(Rules.meets_squarely(east, Vector2i(0, 5)), "square, any length")
	assert_true(Rules.branches_apart(east, at_41), "41 apart")
	assert_false(Rules.branches_apart(east, at_39), "39 apart")
	assert_true(Rules.branches_apart(east, -east), "straight on")
	var at_40 := Vector2i(7660, 6428)
	assert_true(Rules.meets_squarely(east, at_40), "exactly 40 (sin 0.6428, as 658 / 1024 after the unit's truncation)")
	assert_true(Rules.branches_apart(east, at_40), "exactly 40 apart")
	assert_equal(Rules.unit_of(3, 4), Vector2i(614, 819), "a unit direction keeps x and z in their places, truncated")


func test_a_corner_s_fillet_must_fit_its_legs() -> void:
	"""A right angle's 1 m fillet reaches 1448 u along each leg (1024 x sqrt 2); 45 per cent of the shorter
	leg must hold it: 3218 u does, 3217 does not. Straight on reaches nowhere; straight back can never fit."""
	assert_equal(Rules.fillet_reach_u(Vector2i(1024, 0), Vector2i(0, 1024)), 1448, "a right angle")
	assert_equal(Rules.fillet_reach_u(Vector2i(1024, 0), Vector2i(2048, 0)), 0, "straight on")
	assert_equal(Rules.fillet_reach_u(Vector2i(1024, 0), Vector2i(-1024, 0)), Rules.MAX_LENGTH_U, "straight back")
	assert_true(Rules.bend_ok(_route([Vector2i(0, 0), Vector2i(3218, 0), Vector2i(3218, 3218)]), 1), "3218 u legs")
	assert_false(Rules.bend_ok(_route([Vector2i(0, 0), Vector2i(3217, 0), Vector2i(3217, 5000)]), 1), "3217 u")


func test_legs_cross_and_distances_are_exact() -> void:
	"""Two legs crossing at their middles cross there; touching ends is not crossing; a point's distance is to
	the leg's nearer end beyond it, else across it; the pillar is both half-widths and 1 m."""
	assert_true(Rules.legs_cross(Vector2i(0, 0), Vector2i(4096, 0), Vector2i(2048, -1000), Vector2i(2048, 1000)), "crossed")
	assert_equal(Rules.crossing_point(Vector2i(0, 0), Vector2i(4096, 0), Vector2i(2048, -1000), Vector2i(2048, 1000)),
		Vector2i(2048, 0), "at the middle")
	assert_false(Rules.legs_cross(Vector2i(0, 0), Vector2i(4096, 0), Vector2i(4096, 0), Vector2i(4096, 3000)), "touching")
	assert_false(Rules.legs_cross(Vector2i(0, 0), Vector2i(10000, 0), Vector2i(20000, -5000), Vector2i(20000, 5000)),
		"their lines cross, the legs do not")
	assert_equal(Rules.point_leg_u(Vector2i(2048, 700), Vector2i(0, 0), Vector2i(4096, 0)), 700, "across")
	assert_equal(Rules.point_leg_u(Vector2i(-3000, 4000), Vector2i(0, 0), Vector2i(4096, 0)), 5000, "beyond an end")
	assert_equal(Rules.pillar_gap_u(Rules.BORE_STANDARD, Rules.BORE_STANDARD), 2048, "two standard bores")
	assert_equal(Rules.pillar_gap_u(Rules.BORE_STANDARD, Rules.BORE_WIDE), 2560, "one widened")
	assert_equal(Rules.level_floor_depth_u(Rules.LEVEL_1), Rules.BORE_FLOOR_DEPTH_U, "level 1")
	assert_equal(Rules.level_floor_depth_u(Rules.LEVEL_2), 5376, "level 2, the P6 candidate")


func test_every_network_refusal_has_words() -> void:
	"""A word for each LINK code; the ones about another tunnel name it."""
	for code in range(Rules.LINK_BASE, Rules.LINK_BASE + Rules.LINK_REASONS.size()):
		assert_false(Rules.link_text(code, "Tunnel 3").is_empty(), "code %d" % code)
	assert_equal(Rules.link_text(Rules.REFUSE_PILLAR, "Tunnel 3"),
		"it would break into Tunnel 3: join it instead, or keep 1 m of earth between them", "named")
	assert_equal(Rules.link_text(Rules.REFUSE_UNDER_WATER, "x"), Rules.reason_text(Rules.REFUSE_UNDER_WATER), "a route's own words")


# --- the plan applies them (tunnel_plan.gd) ---------------------------------------------------

func _lay(graph: GraphScript, points: Array[Vector2i]) -> PlanScript:
	"""A plan with these points laid, each snapped where it lies on or near the network."""
	var plan := PlanScript.new()
	var snap := PackedInt32Array([0, -1, 0, 0])
	for p in points:
		var kind := PlanScript.snap_into(graph, p, snap)
		assert_equal(plan.try_add_snapped(snap[2], snap[3], kind, snap[1], BOUNDS_U, PackedInt32Array()), Rules.REFUSE_NONE,
			"laid %s" % p)
	return plan


func _reason(graph: GraphScript, points: Array[Vector2i]) -> int:
	"""Why the piece through these points may not be dug (REFUSE_NONE: it may)."""
	return _lay(graph, points).piece_reason(graph, BOUNDS_U, PackedInt32Array())


func test_a_point_snaps_to_a_node_to_a_bore_or_to_nothing() -> void:
	"""Within 1.5 m of a foot: that node. Within 1.2 m of a route: the nearest point on it. A mouth is never
	snapped to; far off, nothing."""
	var graph := GraphScript.new()
	_main(graph)
	var snap := PackedInt32Array([0, -1, 0, 0])
	assert_equal(PlanScript.snap_into(graph, Vector2i(4596, 900), snap), SpecScript.END_NODE, "near the first foot")
	assert_equal([snap[1], snap[2], snap[3]], [2, 4096, 0], "the foot itself")
	assert_equal(PlanScript.snap_into(graph, Vector2i(6144, 1100), snap), SpecScript.END_ON_SEGMENT, "near the bore")
	assert_equal([snap[1], snap[2], snap[3]], [1, 6144, 0], "the point on it below")
	assert_equal(PlanScript.snap_into(graph, Vector2i(-300, 1000), snap), SpecScript.END_ON_SEGMENT, "near mouth A: its ramp")
	assert_equal(snap[1], 0, "the ramp, not the mouth")
	assert_equal(PlanScript.snap_into(graph, Vector2i(6144, 1300), snap), SpecScript.END_NEW_MOUTH, "1.27 m off: nothing")
	assert_equal([snap[2], snap[3]], [6144, 1300], "where it was laid")


func test_a_tee_and_a_crossing_may_be_dug() -> void:
	"""A branch north from the bore's middle, and a piece crossing it square there, are sound; the crossing
	is found and handed on."""
	var graph := GraphScript.new()
	_main(graph)
	assert_equal(_reason(graph, [Vector2i(6144, 0), Vector2i(6144, 8192)]), Rules.REFUSE_NONE, "the tee")
	var plan := _lay(graph, [Vector2i(6144, -6144), Vector2i(6144, 6144)])
	assert_equal(plan.piece_reason(graph, BOUNDS_U, PackedInt32Array()), Rules.REFUSE_NONE, "the crossing")
	assert_equal(plan.crossings, PackedInt32Array([1, 6144, 0]), "across bore 1 at (6144, 0)")
	var spec := plan.spec_of(4)
	assert_equal([spec.start_kind, spec.end_kind, spec.digger], [SpecScript.END_NEW_MOUTH, SpecScript.END_NEW_MOUTH, 4], "the spec")


func test_the_network_s_refusals() -> void:
	"""Each connection rule refuses in its own words (tunnel_rules.gd LINK_REASONS)."""
	var graph := GraphScript.new()
	_main(graph)
	var cases: Array[Array] = [
		[[Vector2i(6144, 0), Vector2i(14336, 3072)], Rules.REFUSE_SHALLOW_MEETING, "a branch at 20.6 degrees"],
		[[Vector2i(0, 1536), Vector2i(12288, 1536)], Rules.REFUSE_PILLAR, "1.5 m beside it"],
		[[Vector2i(-2000, -2965), Vector2i(14288, 2965)], Rules.REFUSE_SHALLOW_CROSSING, "crossing the bore at 20 degrees"],
		[[Vector2i(2048, 0), Vector2i(2048, 8192)], Rules.REFUSE_JOIN_RAMP, "off the ramp"],
		[[Vector2i(6144, -4800), Vector2i(6144, 7488)], Rules.REFUSE_NEAR_NODE, "crossing inside its own ramp"],
		[[Vector2i(6144, 5000), Vector2i(6144, 0)], Rules.REFUSE_NEAR_NODE, "a 5 m mouth-to-junction piece: its foot 1 m from the junction"],
		[[Vector2i(0, 8192), Vector2i(3000, 8192), Vector2i(3000, 16384)], Rules.REFUSE_RAMP_BEND, "a bend on the ramp"],
		[[Vector2i(-16000, 8192), Vector2i(0, 8192), Vector2i(-16000, 9000)], Rules.REFUSE_TIGHT_BEND, "turning back"],
		[[Vector2i(-18000, -18000), Vector2i(0, -18000), Vector2i(0, -9808), Vector2i(-16000, -16500)], Rules.REFUSE_SELF_PILLAR,
			"coming back 1.5 m from itself"],
		[[Vector2i(4096, 0), Vector2i(4096, 6000), Vector2i(4396, 100)], Rules.REFUSE_SAME_NODE, "out and back to one foot"],
		[[Vector2i(5530, -6144), Vector2i(5530, 6144)], Rules.REFUSE_NEAR_NODE, "crossing 1.4 m from the ramp's foot"],
		[[Vector2i(0, -7168), Vector2i(4096, -10240), Vector2i(8192, -7168)], Rules.REFUSE_TIGHT_BEND,
			"a 74 degree bend a metre past the foot: its 0.94 m fillet in 45% of 1 m"],
		[[Vector2i(0, -12288), Vector2i(4096, -12288), Vector2i(4096, -4096)], Rules.REFUSE_RAMP_BEND,
			"a bend exactly at the ramp's foot, 4 m in"],
	]
	for c in cases:
		var points: Array[Vector2i] = []
		points.assign(c[0])
		assert_equal(_reason(graph, points), c[1], c[2])


func test_a_refusal_names_the_tunnel_it_concerns() -> void:
	"""Beside the main bore the plan names the segment it would break into."""
	var graph := GraphScript.new()
	_main(graph)
	var plan := _lay(graph, [Vector2i(0, 1536), Vector2i(12288, 1536)])
	assert_equal(plan.piece_reason(graph, BOUNDS_U, PackedInt32Array()), Rules.REFUSE_PILLAR, "refused")
	assert_true(plan.refused_slot >= 0 and plan.refused_slot <= 2, "a segment of the main tunnel (%d)" % plan.refused_slot)


func test_a_closed_or_busy_host_and_a_full_junction_are_refused() -> void:
	"""A closed bore, one with a job at work (the tool's `job_busy`), and a junction four bores already meet
	at."""
	var graph := GraphScript.new()
	_main(graph)
	graph.close(1, GraphScript.CLOSED_COLLAPSED, 0, 1024)
	assert_equal(_reason(graph, [Vector2i(6144, 0), Vector2i(6144, 8192)]), Rules.REFUSE_HOST_BUSY, "closed")
	graph.reopen(1)
	var plan := _lay(graph, [Vector2i(6144, 0), Vector2i(6144, 8192)])
	plan.job_busy = func(slot: int) -> bool: return slot == 1
	assert_equal(plan.piece_reason(graph, BOUNDS_U, PackedInt32Array()), Rules.REFUSE_HOST_BUSY, "at work")
	var crossing := SpecScript.new()
	crossing.set_route(_route([Vector2i(6144, -8192), Vector2i(6144, 8192)]), 2)
	crossing.crossings = PackedInt32Array([1, 6144, 0])
	graph.add_piece(crossing, PackedInt32Array([-1, 0, -1]))
	assert_equal(_reason(graph, [Vector2i(-2000, 6000), Vector2i(6144, 0)]), Rules.REFUSE_JUNCTION_FULL, "four there already")


func test_a_full_network_refuses_in_words() -> void:
	"""Every mouth row taken: a sound piece far from the rest is refused for room."""
	var graph := GraphScript.new()
	var ref := PackedInt32Array([-1, 0, -1])
	for k in Rules.MAX_MOUTHS / 2:
		graph.add_into(_route([Vector2i(-18000, 1500 * k - 18000), Vector2i(-8000, 1500 * k - 18000)]), 2, k, ref)
	assert_equal(_reason(graph, [Vector2i(5000, 15000), Vector2i(15000, 15000)]), Rules.REFUSE_NO_MOUTH_ROWS, "no mouth row: refused naming the mouths")


# --- the digging skill ------------------------------------------------------------------------

func test_moles_start_skilled_and_anybody_learns() -> void:
	"""Moles start at level 3 (45000 XP); a loam quantum's 113 ticks earn 90 XP (113 x 10 x 60 / 750); 5000
	XP is level 1; the factor is 1000 + 50 x level; the panel's words."""
	var skills := SkillsScript.new()
	skills.setup(PackedStringArray(["Mole", "Mouse"]))
	assert_equal([skills.level_of(0), skills.level_of(1)], [3, 0], "the mole skilled, the mouse not")
	assert_equal(SkillsScript.xp_of_ticks(113), 90, "a loam quantum")
	assert_equal(GroundScript.dig_ticks(GroundScript.CLAY), 147, "a clay quantum takes 147 ticks")
	assert_equal(SkillsScript.xp_of_ticks(GroundScript.dig_ticks(GroundScript.CLAY)), 117, "so earns 117 XP (147 x 600 / 750, floored)")
	assert_equal([skills.factor_permille(0), skills.factor_permille(1)], [1150, 1000], "skill factors")
	assert_false(skills.add_ticks(1, 113 * 55), "55 quanta: 4950 XP, not yet")
	assert_true(skills.add_ticks(1, 113), "the 56th: 5040 XP, level 1")
	assert_equal(skills.level_of(1), 1, "level 1")
	assert_equal(skills.line_of(0), "Digging 3 · XP 45000/80000", "the long form")
	assert_equal(skills.short_of(1), "dig 1", "the short form")
	assert_false(skills.add_ticks(9, 113), "no such resident")


func test_the_crew_digs_at_the_lead_s_skill() -> void:
	"""A mole alone digs at 1150 per mille, a mouse alone at 1000; each at the face learns from a cut."""
	var crew := CrewScript.new()
	crew.set_resident(0, "Mole")
	crew.set_resident(1, "Mouse")
	var fits := func(_i: int) -> bool: return true
	assert_equal(crew.rate_permille(0, 0, 1, GroundScript.LOAM, fits), 1150, "the mole")
	assert_equal(crew.rate_permille(0, 1, 1, GroundScript.LOAM, fits), 1000, "the mouse")
	assert_true(crew.join(1, 0), "the mouse joins the mole's crew")
	crew.set_present(1, true)
	assert_equal(crew.rate_permille(0, 0, 1, GroundScript.LOAM, fits), 1506 * 1150 / 1000, "two at a standard face, the mole's skill")
	crew.credit_ticks(0, 0, 113, fits)
	assert_equal([crew.skills.xp[0], crew.skills.xp[1]], [45090, 90], "both learn")
	crew.move_site(0, 5)
	assert_equal(crew.member_site[1], 5, "the crew follows the dig on")


# --- the cost readout ---------------------------------------------------------------------------

func test_the_readout_counts_quanta_hours_spoil_and_ground() -> void:
	"""A 12 m mouth-to-mouth piece through loam: 14 quanta (two shafts and twelve metres), 1582 ticks -- at one
	F1000 digger 2.1 demo-calendar hours (750 ticks an hour, decision 0421; the tenths floored) -- and 28 U of spoil; a
	crew at 2000 per mille halves the time (1.05 h, read 1.0). Bracing it (decision 0211) costs the Brace job's wood
	250 and stone 250 milli-U on each of its 14 quanta: 3.5 of each."""
	var plan := _lay(GraphScript.new(), [Vector2i(0, 0), Vector2i(12288, 0)])
	assert_equal(ReadoutScript.text(plan, null, 1000, 1),
		"12.0 m · 14 quanta · 2.1 h (one digger)\n28 U spoil · brace 3.5 wood + 3.5 stone", "one digger")
	assert_equal(ReadoutScript.text(plan, null, 2000, 3),
		"12.0 m · 14 quanta · 1.0 h (crew of 3)\n28 U spoil · brace 3.5 wood + 3.5 stone", "a crew")
	assert_equal(ReadoutScript.text(PlanScript.new(), null, 1000, 1), "", "nothing laid")


func test_the_readout_says_minutes_under_an_hour() -> void:
	"""Decision 0421: on the 25 s game hour short digs are minutes of it -- whole minutes, rounded up, under an hour;
	from an hour, hours to the tenth (floored, never under 1.0)."""
	assert_equal([ReadoutScript.time_text(0), ReadoutScript.time_text(1), ReadoutScript.time_text(375),
		ReadoutScript.time_text(737), ReadoutScript.time_text(738), ReadoutScript.time_text(749),
		ReadoutScript.time_text(750), ReadoutScript.time_text(1582)],
		["0 min", "1 min", "30 min", "59 min", "1.0 h", "1.0 h", "1.0 h", "2.1 h"], "the text")


# --- residents walk and dig the graph -------------------------------------------------------

static func _pen(centre: Vector2) -> Array[Vector3]:
	"""Twelve overlapping 0.9 m circles on a 3 m ring round `centre`: a closed pen."""
	var ring: Array[Vector3] = []
	for k in 12:
		var at := centre + Vector2(cos(TAU * k / 12.0), sin(TAU * k / 12.0)) * 3.0
		ring.append(Vector3(at.x, 0.9, at.y))
	return ring


func _penned_tee(dig_branch: bool) -> CastSpaceScript:
	"""A pen round (0, 12) and a 16 m tunnel east-west at z = 4 (slots 0 ramp, 1 bore, 2 ramp), with a branch
	from its middle (0, 4) north to a mouth at the pen's centre (0, 12): the bore splits at (0, 4) into slots 1
	and 3, the branch is bore 4 and ramp 5 -- dug when `dig_branch`, else planned."""
	var space := CastSpaceScript.new()
	space.setup([], _pen(Vector2(0.0, 12.0)))
	var graph := space.tunnels
	var ref := PackedInt32Array([-1, 0, -1])
	graph.add_into(_route([Vector2i(-8192, 4096), Vector2i(8192, 4096)]), 2, 0, ref)
	_dig(graph, ref[2])
	graph.add_piece(_branch_spec(1, Vector2i(0, 4096), Vector2i(0, 12288)), ref)
	if dig_branch:
		_dig(graph, ref[2])
	return space


func _walker(space: CastSpaceScript, at: Vector2) -> BrainScript:
	"""A resident who fits a bore, standing at `at`."""
	var lengths := {}
	for clip in DemoActorScript.CLIPS:
		lengths[clip] = 2.0
	var brain := BrainScript.new()
	brain.configure(space, 1.0, BODY_M, 11, lengths)
	brain.start_at(at, 0.0, -1, -1)
	space.tunnels.set_fit(brain.index, true)
	return brain


static func _walk(space: CastSpaceScript, brain: BrainScript, seconds: float) -> Dictionary:
	"""Step `brain` up to `seconds` or until it holds; the segments it was in, in order."""
	var seen := PackedInt32Array()
	for f in roundi(seconds / DT):
		brain.step(DT)
		var at := space.resident_tunnel[brain.index] if brain.underground else -1
		if at >= 0 and (seen.is_empty() or seen[seen.size() - 1] != at):
			seen.append(at)
		if brain.state == BrainScript.State.HOLD and f > 10:
			break
	return {"seen": seen}


func test_a_resident_walks_through_a_tee_into_a_pen() -> void:
	"""The pen's only way in is the branch: ordered into it, the walker goes in at A and walks ramp 0, bore 1,
	the branch's bore 4 and ramp 5, off the surface, and comes up inside."""
	var space := _penned_tee(true)
	var brain := _walker(space, Vector2(-9.5, 4.5))
	brain.order_move(Vector2(0.6, 12.4))
	var seen: PackedInt32Array = _walk(space, brain, 90.0)["seen"]
	assert_equal(seen, PackedInt32Array([0, 1, 4, 5]), "segment by segment through the junction")
	assert_false(brain.underground, "up again")
	assert_true(brain.position.distance_to(Vector2(0.6, 12.4)) < 0.2, "in the pen (%s)" % brain.position)


func test_a_closure_ahead_is_found_again_at_the_next_node() -> void:
	"""Bore 1 closes while the walker is still in ramp 0: at the foot the rest of its way is gone
	(MOVE-REQ-006), so it walks out at A and plans again -- round on the surface to B, in, and through the
	junction from the other side, bore 3."""
	var space := _penned_tee(true)
	var brain := _walker(space, Vector2(-9.5, 4.5))
	brain.order_move(Vector2(0.6, 12.4))
	for f in 1200:
		brain.step(DT)
		if brain.is_in_bore(0):
			break
	assert_true(brain.is_in_bore(0), "down ramp 0")
	space.tunnels.close(1, GraphScript.CLOSED_COLLAPSED, 0, 1024)
	var seen: PackedInt32Array = _walk(space, brain, 200.0)["seen"]
	assert_true(seen.has(3) and seen.has(4), "in by B, through the junction (%s)" % str(seen))
	assert_false(seen.has(1), "never through the fall")
	assert_true(brain.position.distance_to(Vector2(0.6, 12.4)) < 0.2, "in the pen (%s)" % brain.position)


func test_released_in_a_bore_it_walks_out_by_the_nearest_mouth() -> void:
	"""Released in the branch's bore, the walker walks out the cheapest way: up the branch's ramp into the pen,
	whose mouth is nearer than either of the main tunnel's."""
	var space := _penned_tee(true)
	var brain := _walker(space, Vector2(-9.5, 4.5))
	brain.order_move(Vector2(0.6, 12.4))
	for f in 3000:
		brain.step(DT)
		if brain.is_in_bore(4) and brain.bore_along_m() > 3.0:
			break
	brain.release()
	var seen: PackedInt32Array = _walk(space, brain, 30.0)["seen"]
	assert_equal(seen, PackedInt32Array([4, 5]), "on up the branch")
	assert_false(brain.underground, "up")
	assert_true(brain.position.distance_to(Vector2(0.0, 12.0)) < 0.3, "at the pen's mouth (%s)" % brain.position)


func test_a_digger_goes_down_to_the_junction_and_digs_the_branch_out() -> void:
	"""The branch planned, its bore started for the digger: it walks in at A and along to the junction below,
	digs the bore from there, goes on into the ramp and breaks out at the pen's mouth, then steps clear."""
	var space := _penned_tee(false)
	var graph := space.tunnels
	var brain := _walker(space, Vector2(-9.5, 4.5))
	var first := graph.first_of_piece(1)
	assert_true(graph.start_dig(first, graph.generation[first], brain.index), "started")
	brain.order_dig(first, graph.generation[first])
	var seen: PackedInt32Array = _walk(space, brain, 200.0)["seen"]
	assert_equal(seen.slice(0, 2), PackedInt32Array([0, 1]), "down ramp 0 and along bore 1 to the junction")
	assert_true(graph.piece_done(1), "the branch dug through")
	assert_equal(brain.dig_tunnel, -1, "no dig left")
	assert_false(brain.underground, "up")
	assert_true(brain.position.distance_to(Vector2(0.0, 12.0)) >= 1.0 - BrainScript.ARRIVE_RADIUS_M, "stepped clear of the hole, 1 m (%s)" % brain.position)
	assert_true(brain.position.distance_to(Vector2(0.0, 12.0)) < 2.0, "by the pen's mouth")


func test_a_digger_takes_up_its_next_piece_from_the_job_list() -> void:
	"""Two pieces queued for one digger: when the first is dug through it takes up the second."""
	var space := CastSpaceScript.new()
	space.setup([], [])
	var graph := space.tunnels
	var brain := _walker(space, Vector2(-1.0, -1.0))
	var ref := PackedInt32Array([-1, 0, -1])
	graph.add_into(_route([Vector2i(0, 0), Vector2i(8192, 0)]), 2, brain.index, ref)
	brain.order_dig(ref[0], ref[1])
	var spec := SpecScript.new()
	spec.set_route(_route([Vector2i(8192, 4096), Vector2i(0, 4096)]), 2)
	spec.digger = brain.index
	graph.add_piece(spec, ref)
	_walk(space, brain, 150.0)
	assert_true(graph.piece_done(0) and graph.piece_done(1), "both dug, one after the other")


func test_a_split_hands_walkers_finds_and_stone_to_its_halves() -> void:
	"""Review H6 and C3, through the tool's own path (add_piece, then tunnel_works `after_splits`): a walker 3 m
	into the 16 m tunnel's bore when a branch splits it 4 m in stays in the first half, one 6 m in is 2 m into
	the second; a find at 6 m follows onto the second half; and the stores gain not one milli-U more -- the
	new half's cuts (rock among them) are not counted again."""
	var space := CastSpaceScript.new()
	space.setup([], [])
	var graph := space.tunnels
	var near := _walker(space, Vector2.ZERO)
	var far := _walker(space, Vector2.ZERO)
	var brains: Array[BrainScript] = [near, far]
	var works: WorksScript = WorksScript.new()
	works.setup(space, brains, PackedStringArray(["Mouse", "Mouse"]), BOUNDS_U, func(_t: String) -> void: pass)
	var ref := PackedInt32Array([-1, 0, -1])
	graph.add_into(_route([Vector2i(-4096, 1536), Vector2i(16384, 1536)]), 2, 0, ref)
	_dig(graph, ref[2])
	works.step(16000)
	var stone_before := works.stores.stone_milli_u
	assert_true(graph.stone_milli_u(1) > 0, "the bore cut rock (the fixture is not vacuous)")
	near.task_enter_bore(1, 3.0, 12.0)
	far.task_enter_bore(1, 6.0, 12.0)
	works.found_x_u[0] = 6144
	works.found_z_u[0] = 1536
	works.found_slot[0] = 1
	works.found_count = 1
	assert_true(graph.add_piece(_branch_spec(1, Vector2i(4096, 1536), Vector2i(4096, 12288)), ref), "the branch")
	var tail := graph.last_splits[1]
	works.after_splits()
	works.step(16000)
	assert_true(near.is_in_bore(1), "the near one in the first half")
	assert_true(far.is_in_bore(tail), "the far one in the second")
	assert_almost_equal(far.bore_along_m(), 2.0, "2 m into it")
	assert_equal(works.found_slot[0], tail, "the find in the second half")
	assert_equal(works.stores.stone_milli_u, stone_before, "no stone counted twice")
	works.free()


func test_finds_follow_a_segment_split_twice_by_one_piece() -> void:
	"""Review M2: one piece that ends on a 12 m bore at 7 m and crosses it at 13 m splits it twice (the second
	time, the half the first split made). Finds at 5, 10 and 15 m of the bore land on the halves that hold
	them."""
	var space := CastSpaceScript.new()
	space.setup([], [])
	var graph := space.tunnels
	var brains: Array[BrainScript] = []
	var works: WorksScript = WorksScript.new()
	works.setup(space, brains, PackedStringArray(), BOUNDS_U, func(_t: String) -> void: pass)
	var ref := PackedInt32Array([-1, 0, -1])
	graph.add_into(_route([Vector2i(0, 0), Vector2i(20480, 0)]), 2, 0, ref)
	_dig(graph, ref[2])
	for k in 3:
		works.found_x_u[k] = 5120 + 5120 * k
		works.found_z_u[k] = 0
		works.found_slot[k] = 1
	works.found_count = 3
	var spec := SpecScript.new()
	spec.set_route(_route([Vector2i(13312, 6144), Vector2i(13312, -4096), Vector2i(7168, -4096), Vector2i(7168, 0)]), 4)
	spec.end_kind = SpecScript.END_ON_SEGMENT
	spec.end_ref = 1
	spec.crossings = PackedInt32Array([1, 13312, 0])
	assert_true(graph.add_piece(spec, ref), "stored")
	works.after_splits()
	var first_tail := graph.last_splits[1]
	var second_tail := graph.last_splits[4]
	assert_equal(Array(works.found_slot.slice(0, 3)), [1, first_tail, second_tail], "5 m, 10 m and 15 m")
	works.free()


# --- edges the rules and the tables turn on -------------------------------------------------

func test_a_piece_is_refused_one_segment_row_short() -> void:
	"""With two segment rows free, a 12 m tunnel (three segments) is refused whole and nothing is stored."""
	var graph := GraphScript.new()
	for slot in range(2, Rules.MAX_SEGMENTS):
		graph.phase[slot] = GraphScript.PHASE_OPEN
	var ref := PackedInt32Array([-1, 0, -1])
	assert_false(graph.add_into(_route([Vector2i(0, 0), Vector2i(12288, 0)]), 2, 0, ref), "refused")
	assert_equal(graph.phase.count(GraphScript.PHASE_FREE), 2, "nothing stored")
	assert_equal(graph.node_kind.count(GraphScript.NODE_FREE), Rules.MAX_NODES, "no node made")


func test_dropped_pieces_give_their_rows_back() -> void:
	"""A hundred pieces laid and dropped before a tick (more than the 96 piece rows): each gives its row back,
	so the hundred-and-first is stored."""
	var graph := GraphScript.new()
	var ref := PackedInt32Array([-1, 0, -1])
	for k in 100:
		assert_true(graph.add_into(_route([Vector2i(0, 0), Vector2i(12288, 0)]), 2, 0, ref), "piece %d stored" % k)
		graph.stop_digging(ref[0], ref[1])
	assert_equal(graph.piece_live.count(1), 0, "every row given back")
	assert_true(graph.add_into(_route([Vector2i(0, 0), Vector2i(12288, 0)]), 2, 0, ref), "the next is stored")


func test_a_piece_ending_on_its_host_and_crossing_the_half_it_made_splits_that_half() -> void:
	"""A 20 m tunnel's bore runs 4..16 m. A piece from a mouth at (13, 6) crosses it at 13 m, turns and ends on
	it at 7 m: the end splits the bore first (4..7 and 7..16), and the crossing then splits the half it lies
	on -- 7..13 and 13..16 -- not the first."""
	var graph := GraphScript.new()
	var ref := PackedInt32Array([-1, 0, -1])
	graph.add_into(_route([Vector2i(0, 0), Vector2i(20480, 0)]), 2, 0, ref)
	_dig(graph, ref[2])
	var spec := SpecScript.new()
	spec.set_route(_route([Vector2i(13312, 6144), Vector2i(13312, -4096), Vector2i(7168, -4096), Vector2i(7168, 0)]), 4)
	spec.end_kind = SpecScript.END_ON_SEGMENT
	spec.end_ref = 1
	spec.crossings = PackedInt32Array([1, 13312, 0])
	assert_true(graph.add_piece(spec, ref), "stored")
	var tail := graph.last_splits[1]
	var far := graph.last_splits[4]
	assert_equal(graph.last_splits, PackedInt32Array([1, tail, 3072, tail, far, 6144]), "the host at 7 m, then its second half at 13 m")
	assert_equal([graph.length_u[1], graph.length_u[tail], graph.length_u[far]], [3072, 6144, 3072], "three pieces of bore")
	assert_equal([graph.node_at(graph.node_b[1]), graph.node_at(graph.node_b[tail])], [Vector2i(7168, 0), Vector2i(13312, 0)],
		"a junction at 7 m and one at 13 m")
	assert_equal(graph.node_b[far], 3, "the far half ends at the old foot")


func test_equal_ways_of_one_segment_tie_on_the_lower_slot() -> void:
	"""Two arcs X-Y of exactly the same cost and one segment each: the table goes by the lower slot, whichever
	was dug first."""
	for upper_first: bool in [true, false]:
		var graph := GraphScript.new()
		var ref := PackedInt32Array([-1, 0, -1])
		graph.add_into(_route([Vector2i(0, 0), Vector2i(16384, 0)]), 2, 0, ref)
		_dig(graph, ref[2])
		graph.close(1, GraphScript.CLOSED_COLLAPSED, 0, 1024)
		var arcs: Array[Vector2i] = [Vector2i(8192, 3072), Vector2i(8192, -3072)]
		if not upper_first:
			arcs.reverse()
		var slots := PackedInt32Array()
		for via in arcs:
			var spec := SpecScript.new()
			spec.set_route(_route([Vector2i(4096, 0), via, Vector2i(12288, 0)]), 3)
			spec.start_kind = SpecScript.END_NODE
			spec.start_ref = 2
			spec.end_kind = SpecScript.END_NODE
			spec.end_ref = 3
			graph.add_piece(spec, ref)
			_dig(graph, ref[2])
			slots.append(ref[0])
		var segs := PackedInt32Array()
		graph.paths.path_into(graph, PathsScript.CLASS_ANY, 0, 3, segs)
		assert_equal(segs, PackedInt32Array([0, mini(slots[0], slots[1])]), "the lower slot (upper first: %s)" % upper_first)


func test_the_paths_heap_pops_in_order() -> void:
	"""Sixty seeded entries pushed onto the paths' heap come off by cost, then segments, then node."""
	var paths := PathsScript.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 208
	for k in 60:
		paths._push(rng.randi_range(0, 40), rng.randi_range(0, 3), k)
	var last := Vector3i(-1, -1, -1)
	var in_order := true
	for k in 60:
		var top := Vector3i(paths._heap_cost[0], paths._heap_hops[0], paths._heap_node[0])
		in_order = in_order and (top.x > last.x or (top.x == last.x and (top.y > last.y or (top.y == last.y and top.z > last.z))))
		last = top
		paths._pop()
	assert_true(in_order, "popped in (cost, segments, node) order")
	assert_equal(paths._heap_size, 0, "empty")


func test_two_close_crossings_are_refused() -> void:
	"""Two open bores 1.2 m apart: a piece crossing both would crowd one junction's hub into the other's."""
	var graph := GraphScript.new()
	_main(graph)
	var ref := PackedInt32Array([-1, 0, -1])
	graph.add_into(_route([Vector2i(0, 1229), Vector2i(12288, 1229)]), 2, 0, ref)
	_dig(graph, ref[2])
	assert_equal(_reason(graph, [Vector2i(6144, -6144), Vector2i(6144, 7373)]), Rules.REFUSE_NEAR_NODE, "crossings 1.2 m apart")


func test_a_branch_by_a_ramp_s_foot_keeps_no_pillar_from_that_ramp() -> void:
	"""A branch leaving the bore 1.6 m past the entrance ramp's foot, back at 45 degrees, passes 1.4 m from the
	ramp: joined at the foot they share, they are one void, and it may be dug."""
	var graph := GraphScript.new()
	_main(graph)
	assert_equal(_reason(graph, [Vector2i(5734, 0), Vector2i(-410, -6144)]), Rules.REFUSE_NONE, "dug")



# --- review fixes (decision 0208: the review) ------------------------------------------------

func _half_dug_branch(space: CastSpaceScript, brain: BrainScript) -> int:
	"""A 16 m tunnel east (slots 0..2), and a piece P from a mouth at (8, 12) south onto its bore at (8, 0):
	P's ramp open, P's bore (8 m, from its foot at (8, 8) to the junction) dug to 5.6 m by `brain`, who digs
	at the face. Returns P's bore."""
	var graph := space.tunnels
	var ref := PackedInt32Array([-1, 0, -1])
	graph.add_into(_route([Vector2i(0, 0), Vector2i(16384, 0)]), 2, 0, ref)
	_dig(graph, ref[2])
	var spec := SpecScript.new()
	spec.set_route(_route([Vector2i(8192, 12288), Vector2i(8192, 0)]), 2)
	spec.end_kind = SpecScript.END_ON_SEGMENT
	spec.end_ref = 1
	spec.digger = brain.index
	graph.add_piece(spec, ref)
	var ramp := ref[0]
	var bore := graph.next_in_piece(ramp)
	graph.start_dig(ramp, graph.generation[ramp], brain.index)
	graph.advance(ramp, graph.generation[ramp], 1000000000)
	graph.start_dig(bore, graph.generation[bore], brain.index)
	graph.advance(bore, graph.generation[bore], 21100000)
	brain.order_dig(bore, graph.generation[bore])
	for f in 3600:
		brain.step(DT)
		if brain.state == BrainScript.State.DIG and brain.underground:
			break
	assert_true(brain.state == BrainScript.State.DIG and brain.underground, "digging at the face")
	return bore


func _order_dig_at_first_foot(space: CastSpaceScript, brain: BrainScript) -> int:
	"""A piece Q from the main tunnel's first foot (node 2) south-west to a new mouth, sent to `brain`: its
	first segment."""
	var graph := space.tunnels
	var spec := SpecScript.new()
	spec.set_route(_route([Vector2i(4096, 0), Vector2i(-2048, -10240)]), 2)
	spec.start_kind = SpecScript.END_NODE
	spec.start_ref = 2
	spec.digger = brain.index
	var ref := PackedInt32Array([-1, 0, -1])
	assert_true(graph.add_piece(spec, ref), "Q stored")
	graph.start_dig(ref[0], ref[1], brain.index)
	brain.order_dig(ref[0], ref[1])
	return ref[0]


func test_a_digger_sent_elsewhere_never_walks_through_undug_ground() -> void:
	"""Review C1 (MOVE-REQ-002). Sent from its face 5.6 m into an 8 m bore to a dig whose start is underground
	beyond the bore's far, undug end: it backs out the way it came -- never past its face -- up its ramp, and
	goes in again at a mouth that leads there, to dig it."""
	var space := CastSpaceScript.new()
	space.setup([], [])
	var brain := _walker(space, Vector2(8.0, 14.0))
	var bore := _half_dug_branch(space, brain)
	var face := space.tunnels.face_m(bore)
	var q := _order_dig_at_first_foot(space, brain)
	var furthest := 0.0
	var dug_q := false
	for f in 60 * 90:
		brain.step(DT)
		if brain.underground and space.resident_tunnel[brain.index] == bore:
			furthest = maxf(furthest, brain.bore_along_m())
		dug_q = dug_q or (brain.state == BrainScript.State.DIG and brain.dig_tunnel == q)
	assert_true(furthest <= face + 0.01, "never past the face at %.2f m (%.2f)" % [face, furthest])
	assert_true(dug_q, "and on to dig Q")


func test_a_resident_below_with_no_way_on_walks_out_rather_than_standing() -> void:
	"""Review C2. The same, with the host's far half flooded so no walk below leads on: the digger still walks
	out -- it is never left holding underground -- and a later order is carried out on the surface."""
	var space := CastSpaceScript.new()
	space.setup([], [])
	var brain := _walker(space, Vector2(8.0, 14.0))
	var bore := _half_dug_branch(space, brain)
	var graph := space.tunnels
	for k in GraphScript.DEGREE:
		var s := graph.node_segment(graph.node_b[bore], k)
		if s >= 0 and s != bore:
			graph.close(s, GraphScript.CLOSED_FLOODED, 0, 0)
	_order_dig_at_first_foot(space, brain)
	_step(brain, 20.0)
	brain.order_move(Vector2(18.0, 18.0))
	_step(brain, 30.0)
	assert_false(brain.underground, "up")
	assert_true(brain.position.distance_to(Vector2(18.0, 18.0)) <= BrainScript.ARRIVE_RADIUS_M + 0.02, "at the order (%s)" % brain.position)


func test_a_trip_given_up_below_walks_out() -> void:
	"""Review C2: a trip abandoned while walking a tunnel (its replans spent) walks out to the nearest mouth
	instead of holding in the bore."""
	var space := _penned_tee(true)
	var brain := _walker(space, Vector2(-9.5, 4.5))
	brain.order_move(Vector2(0.0, 12.0))
	for f in 60 * 20:
		brain.step(DT)
		if brain.underground:
			break
	brain.step(DT)
	assert_true(brain.underground, "below")
	brain._abandon_trip()
	assert_equal(brain.state, BrainScript.State.TUNNEL, "walking on, out")
	_step(brain, 20.0)
	assert_false(brain.underground, "up at a mouth")


static func _step(brain: BrainScript, seconds: float) -> void:
	"""Step one brain for `seconds`."""
	for f in roundi(seconds / DT):
		brain.step(DT)


func test_a_piece_crossing_two_bores_is_the_same_piece_either_way_laid() -> void:
	"""Review H1: two parallel open tunnels 6 m apart, the east one dug first. A piece across both is sound
	laid west to east and east to west alike -- its crossings put in route order -- and is stored with a
	four-way junction on each."""
	var graph := GraphScript.new()
	var ref := PackedInt32Array([-1, 0, -1])
	for x: int in [6144, 0]:
		graph.add_into(_route([Vector2i(x, -8192), Vector2i(x, 8192)]), 2, 0, ref)
		_dig(graph, ref[2])
	for ends: Array in [[Vector2i(-6144, 0), Vector2i(12288, 0)], [Vector2i(12288, 0), Vector2i(-6144, 0)]]:
		var points: Array[Vector2i] = []
		points.assign(ends)
		var plan := _lay(graph, points)
		assert_equal(plan.piece_reason(graph, BOUNDS_U, PackedInt32Array()), Rules.REFUSE_NONE, "laid from %s" % points[0])
		assert_true(plan._along_of_crossing(0) < plan._along_of_crossing(1), "its crossings in route order")
	var plan := _lay(graph, [Vector2i(-6144, 0), Vector2i(12288, 0)])
	plan.piece_reason(graph, BOUNDS_U, PackedInt32Array())
	assert_true(graph.add_piece(plan.spec_of(0), ref), "stored")
	var fours := 0
	for node in Rules.MAX_NODES:
		fours += 1 if graph.is_node(node) and graph.degree(node) == 4 else 0
	assert_equal(fours, 2, "a four-way junction on each")


func test_a_split_tail_in_a_lower_slot_never_leads_its_piece() -> void:
	"""Review H2: a piece P from the main tunnel's far foot south to a new mouth, its first segment (a bore)
	open; a dropped piece leaves lower slots free; a crossing splits P's bore and its tail takes a lower slot.
	P still starts at its bore's head, and the crew's measures along it hold."""
	var graph := GraphScript.new()
	_main(graph)
	var ref := PackedInt32Array([-1, 0, -1])
	graph.add_into(_route([Vector2i(-20000, 20000), Vector2i(-8000, 20000)]), 2, 5, ref)
	var dropped := ref.duplicate()
	var spec := SpecScript.new()
	spec.set_route(_route([Vector2i(8192, 0), Vector2i(8192, -12288)]), 2)
	spec.start_kind = SpecScript.END_NODE
	spec.start_ref = 3
	graph.add_piece(spec, ref)
	var p := ref[2]
	var head := ref[0]
	graph.start_dig(head, ref[1], 1)
	graph.advance(head, ref[1], 1000000000)
	graph.stop_digging(dropped[0], dropped[1])
	var cross := SpecScript.new()
	cross.set_route(_route([Vector2i(0, -4096), Vector2i(16384, -4096)]), 2)
	cross.crossings = PackedInt32Array([head, 8192, -4096])
	assert_true(graph.add_piece(cross, PackedInt32Array([-1, 0, -1])), "the crossing stored")
	var tail := graph.last_splits[1]
	assert_true(tail < head, "the tail took a lower slot (%d < %d): the case under test" % [tail, head])
	assert_equal(graph.first_of_piece(p), head, "the head still leads")
	var chain := PackedInt32Array()
	graph.piece_segments_into(p, chain)
	assert_equal(chain[0], head, "its chain from the head")
	assert_equal(chain[1], tail, "then the tail")
	assert_almost_equal(graph.piece_offset_m(head), 0.0, "the head begins the piece")
	assert_almost_equal(graph.piece_offset_m(tail), graph.length_m(head), "the tail after it")


func test_someone_standing_past_a_node_is_passed_whichever_way_its_segment_runs() -> void:
	"""Review H3: a walker 2 m short of a junction, heading for it, and a resident standing still 0.8 m into
	the branch beyond. Whether the branch was drawn from the junction (node A there) or to it (node B), the
	stander is someone to pass, never someone to queue behind: no room lost ahead, and oncoming."""
	for toward_junction: bool in [false, true]:
		var space := CastSpaceScript.new()
		space.setup([], [])
		var graph := space.tunnels
		_main(graph)
		var ref := PackedInt32Array([-1, 0, -1])
		var spec := SpecScript.new()
		if toward_junction:
			spec.set_route(_route([Vector2i(6144, 8192), Vector2i(6144, 0)]), 2)
			spec.end_kind = SpecScript.END_ON_SEGMENT
			spec.end_ref = 1
		else:
			spec = _branch_spec(1, Vector2i(6144, 0), Vector2i(6144, 8192))
		graph.add_piece(spec, ref)
		var tail := graph.last_splits[1]
		_dig(graph, ref[2])
		var branch := -1
		var j := graph.node_b[1]
		for k in GraphScript.DEGREE:
			var s := graph.node_segment(j, k)
			if s >= 0 and s != 1 and s != tail:
				branch = s
		assert_equal(graph.node_a[branch] == j, not toward_junction, "the branch drawn %s the junction" % ("to" if toward_junction else "from"))
		var walker := space.add_resident(Vector2.ZERO, BODY_M)
		var stander := space.add_resident(Vector2.ZERO, BODY_M)
		space.set_underground(walker, true)
		space.set_underground(stander, true)
		space.set_in_bore(walker, 1, graph.length_m(1) - 2.0, 1)
		var into := 0.8 if graph.node_a[branch] == j else graph.length_m(branch) - 0.8
		space.set_in_bore(stander, branch, into, 0)
		assert_equal(space.room_ahead(walker, BrainScript.BORE_GAP_M), INF, "no room lost (junction at the branch's %s)" % ("B" if toward_junction else "A"))
		assert_true(space.oncoming(walker, BrainScript.PASS_WINDOW_M + 2.0), "passed as oncoming (%s)" % ("B" if toward_junction else "A"))


func test_the_ghost_s_whole_piece_check_is_cheap_enough_to_follow_the_pointer() -> void:
	"""Review H4: the ghost checks the whole piece each time the pointer moves 0.1 m. A 38 m piece across the
	village over five open 36 m tunnels (five crossings, 15 segments near it) is checked -- a valid piece, so
	every rule runs to the end -- in under 3 ms, best of five. (The reviewer's 56 m, seven-tunnel case took
	5.4 ms before the pillar check looked only at the segments whose grown boxes hold each sample, 0.8 ms
	after, on the Mac.)"""
	var graph := GraphScript.new()
	var ref := PackedInt32Array([-1, 0, -1])
	for k in 5:
		var x := -12288 + k * 6144
		graph.add_into(_route([Vector2i(x, -18432), Vector2i(x, 18432)]), 2, 0, ref)
		_dig(graph, ref[2])
	var plan := _lay(graph, [Vector2i(-19456, 2048), Vector2i(-3072, 3072), Vector2i(3072, 2048), Vector2i(19456, 3072)])
	var best := 1 << 40
	for trial in 5:
		var t0 := Time.get_ticks_usec()
		assert_equal(plan.piece_reason(graph, BOUNDS_U, PackedInt32Array()), Rules.REFUSE_NONE, "a valid piece")
		best = mini(best, Time.get_ticks_usec() - t0)
	assert_equal(plan.crossings.size() / 3, 5, "five crossings")
	assert_true(best < 3000, "checked in %d us" % best)


func test_a_piece_cut_off_from_every_mouth_spoils_at_an_opened_one() -> void:
	"""Review M3: a piece starting at the main tunnel's first foot while both its ramps are flooded (no walk
	from there to a mouth) spoils at the nearest OPENED mouth as the crow flies -- never at the nearer mouth
	of a piece only planned, whose row a drop would free for reuse."""
	var graph := GraphScript.new()
	_main(graph)
	var ref := PackedInt32Array([-1, 0, -1])
	graph.add_into(_route([Vector2i(4096, -2048), Vector2i(16384, -2048)]), 2, 0, ref)
	assert_true(graph.is_mouth(2), "a planned piece's mouth (row 2) 2 m from the foot, nearer than mouth 0")
	graph.close(0, GraphScript.CLOSED_FLOODED, 0, 0)
	graph.close(2, GraphScript.CLOSED_FLOODED, 0, 0)
	var spec := SpecScript.new()
	spec.set_route(_route([Vector2i(4096, 0), Vector2i(4096, 10240)]), 2)
	spec.start_kind = SpecScript.END_NODE
	spec.start_ref = 2
	assert_true(graph.add_piece(spec, ref), "stored")
	assert_equal(graph.piece_mouth[ref[2]], 0, "mouth 0, 4 m off and opened")


func test_a_snap_onto_a_bore_reads_its_route_in_place_as_the_graph_does() -> void:
	"""Review M5: the snap onto a bore's side (read in place as the pointer moves) is the point the graph's
	own route functions give, over 200 seeded points near a bent bore."""
	var graph := GraphScript.new()
	var ref := PackedInt32Array([-1, 0, -1])
	graph.add_into(_route([Vector2i(0, 0), Vector2i(10240, 1000), Vector2i(12000, 9000), Vector2i(20000, 9500)]), 4, 0, ref)
	_dig(graph, ref[2])
	var rng := RandomNumberGenerator.new()
	rng.seed = 2080
	var snap := PackedInt32Array([0, -1, 0, 0])
	var same := 0
	var checked := 0
	for k in 200:
		var at := Vector2i(rng.randi_range(4000, 16000), rng.randi_range(-1500, 10500))
		if PlanScript.snap_into(graph, at, snap) != SpecScript.END_ON_SEGMENT:
			continue
		var slot := snap[1]
		var route := graph.segment_route(slot)
		var expected := GraphScript.route_point_u(route, graph.point_count[slot],
			GraphScript.route_along_u(route, graph.point_count[slot], at))
		checked += 1
		same += 1 if Vector2i(snap[2], snap[3]) == expected else 0
	assert_true(checked > 20, "points snapped to the bore (%d)" % checked)
	assert_equal(same, checked, "every one where the graph puts it")


func test_bound_below_it_goes_on_by_the_end_that_costs_least() -> void:
	"""Review C1: standing 1.5 m into the 16 m tunnel's open bore, sent to dig from the bore's far foot, it walks
	on toward that foot -- the far end, as the walk along the bore plus the way on costs least from there --
	never back first to the near foot (1.5 m off, but 8 m more to walk)."""
	var space := CastSpaceScript.new()
	space.setup([], [])
	var graph := space.tunnels
	var ref := PackedInt32Array([-1, 0, -1])
	graph.add_into(_route([Vector2i(0, 0), Vector2i(16384, 0)]), 2, 0, ref)
	_dig(graph, ref[2])
	var brain := _walker(space, Vector2(0.0, 0.0))
	brain.task_stand_in_bore(1, 1.5, true)
	var spec := SpecScript.new()
	spec.set_route(_route([Vector2i(12288, 0), Vector2i(12288, -10240)]), 2)
	spec.start_kind = SpecScript.END_NODE
	spec.start_ref = 3
	spec.digger = brain.index
	graph.add_piece(spec, ref)
	graph.start_dig(ref[0], ref[1], brain.index)
	brain.order_dig(ref[0], ref[1])
	var least := 1.5
	var dug := false
	for f in 60 * 20:
		brain.step(DT)
		if brain.underground and space.resident_tunnel[brain.index] == 1:
			least = minf(least, brain.bore_along_m())
		dug = dug or brain.state == BrainScript.State.DIG
	assert_true(least >= 1.49, "never back toward the near foot (%.2f m)" % least)
	assert_true(dug, "and on to dig")


func test_the_pieces_never_run_out_before_the_segments() -> void:
	"""Review M4: a piece has at least one segment, so there is a piece row for every segment row -- a
	network of one-segment branches fills its segments before its pieces."""
	assert_true(Rules.MAX_PIECES >= Rules.MAX_SEGMENTS, "%d piece rows for %d segments" % [Rules.MAX_PIECES, Rules.MAX_SEGMENTS])
