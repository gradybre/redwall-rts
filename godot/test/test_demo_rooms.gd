extends "res://test/framework/test_case.gd"
## Rooms as their own structures (decision 0209, the underground revamp's P3): the templates and their quanta,
## the room's frame and its sockets, the void's exact distances, a room laid on the network as one piece (its
## door or hatch a mouth, its body cut cell by cell, its walks opened with it), every placement refusal, a
## tunnel joining a room only at a free socket, the auto-passage, the door and the hatch as ways in on routes,
## headroom, the cellar API and the room tool's readout.
##
## No scene tree and no staged assets. Values are worked by hand from the templates in underground_rooms.gd,
## 113 ticks and 2000 milli-U a loam quantum, 1024 u a metre.

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const PathsScript := preload("res://demo/tunnel/graph_paths.gd")
const SpecScript := preload("res://demo/tunnel/piece_spec.gd")
const PlanScript := preload("res://demo/tunnel/tunnel_plan.gd")
const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")
const RoomPlanScript := preload("res://demo/burrow/room_plan.gd")
const ReadoutScript := preload("res://demo/tunnel/dig_readout.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")
const WorksScript := preload("res://demo/tunnel/tunnel_works.gd")
const CrewScript := preload("res://demo/tunnel/tunnel_crew.gd")
const FarmCellars := preload("res://demo/farm/farm_cellars.gd")
const StorageScript := preload("res://demo/farm/farm_storage.gd")
const RouterScript := preload("res://demo/tunnel/tunnel_router.gd")

const BOUNDS_U := Rect2i(-20480, -20480, 40960, 40960)
const BODY_M: float = 0.25
## The fixture home: 5 m north of the main tunnel's bore, turned so its door faces away and a socket faces it.
const HOME_AT := Vector2i(6144, 5120)
const HOME_TURNS: int = 2
const LOAM_QUANTUM: int = 113


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
		if not graph.is_open(slot):
			graph.start_dig(slot, graph.generation[slot], 0)
			graph.advance(slot, graph.generation[slot], 1000000000)


func _long_main(graph: GraphScript) -> void:
	"""A longer main tunnel: 20 m east from the origin, dug open (slots 0 ramp, 1 bore 4..16 m, 2 ramp)."""
	var ref := PackedInt32Array([-1, 0, -1])
	assert_true(graph.add_into(_route([Vector2i(0, 0), Vector2i(20480, 0)]), 2, 0, ref), "the long tunnel stored")
	_dig(graph, ref[2])


func _main(graph: GraphScript) -> void:
	"""The main tunnel: 12 m east from the origin, dug open (slots 0 ramp, 1 bore 4..8 m, 2 ramp)."""
	var ref := PackedInt32Array([-1, 0, -1])
	assert_true(graph.add_into(_route([Vector2i(0, 0), Vector2i(12288, 0)]), 2, 0, ref), "the main tunnel stored")
	_dig(graph, ref[2])


func _home(graph: GraphScript, at: Vector2i = HOME_AT, turns: int = HOME_TURNS, kind: int = RoomsScript.TEMPLATE_HOME) -> PackedInt32Array:
	"""A room laid on `graph` (not checked), for digger 0: its (row, generation, piece, ramp, generation)."""
	var ref := PackedInt32Array([0, 0, 0, 0, 0])
	assert_true(graph.add_room(kind, at, turns, 0, ref), "the room laid")
	return ref


static func _furnish(graph: GraphScript, r: int) -> void:
	"""Every fixture place of dug room `r` installed (the fit-out, decision 0210; its own tests are test_demo_fitout.gd)."""
	for f in RoomsScript.fixture_count(graph.rooms.template[r]):
		graph.fit.phase_of(graph, r, f)
		graph.fit.phase[r * RoomsScript.MAX_PLACES + f] = 2


static func _site() -> RoomsScript.Site:
	"""An open site: the bounds, nothing else."""
	var site := RoomsScript.Site.new()
	site.bounds_u = BOUNDS_U
	return site


static func _pond(centre: Vector2i, radius: int) -> Callable:
	"""A water query over one round pond: whether a-b comes within `clearance` of it."""
	return func(a: Vector2i, b: Vector2i, clearance: int) -> bool: return Rules.point_leg_u(centre, a, b) < radius + clearance


# --- the templates --------------------------------------------------------------------------

func test_both_templates_cut_twenty_four_quanta_on_twelve_floor_quanta() -> void:
	"""Two quanta high on twelve floor quanta: 24 for a home and a cellar; three sockets and two; twelve cells
	each; a home's twelve floor quanta hold 12 x 12 / 40 = 3 demo beds, and its template has three bed places."""
	for kind: int in [RoomsScript.TEMPLATE_HOME, RoomsScript.TEMPLATE_CELLAR]:
		assert_equal(RoomsScript.total_quanta(kind), 24, "%s: 24 quanta" % RoomsScript.NAMES[kind])
		assert_equal(RoomsScript.FLOOR_QUANTA[kind], 12, "12 floor quanta")
		assert_equal((RoomsScript.CELLS_LOCAL[kind] as Array).size(), 12, "12 cells")
	assert_equal([RoomsScript.socket_count(RoomsScript.TEMPLATE_HOME), RoomsScript.socket_count(RoomsScript.TEMPLATE_CELLAR)], [3, 2], "sockets")
	assert_equal(RoomsScript.BEDS_PER_HOME, 3, "three beds")
	var beds := 0
	for f in RoomsScript.fixture_count(RoomsScript.TEMPLATE_HOME):
		beds += 1 if RoomsScript.fixture_field(RoomsScript.TEMPLATE_HOME, f, 0) == RoomsScript.FIX_BED else 0
	assert_equal(beds, 3, "three bed alcoves")


func test_the_cells_are_cut_out_from_the_door_two_quanta_each() -> void:
	"""Quanta 0 and 1 are the cell nearest the door (-588, -1419); 22 and 23 the farthest (588, 1419); a cellar's
	first row is at its hatch end (z -1536)."""
	assert_equal(RoomsScript.cell_local(RoomsScript.TEMPLATE_HOME, 0), Vector2i(-588, -1419), "quantum 0")
	assert_equal(RoomsScript.cell_local(RoomsScript.TEMPLATE_HOME, 1), Vector2i(-588, -1419), "quantum 1, the same cell")
	assert_equal(RoomsScript.cell_local(RoomsScript.TEMPLATE_HOME, 2), Vector2i(588, -1419), "quantum 2, the next")
	assert_equal(RoomsScript.cell_local(RoomsScript.TEMPLATE_HOME, 23), Vector2i(588, 1419), "quantum 23")
	assert_equal(RoomsScript.cell_local(RoomsScript.TEMPLATE_CELLAR, 0).y, -1536, "the cellar's hatch end first")
	var door := RoomsScript.DOOR_LOCAL[RoomsScript.TEMPLATE_HOME]
	var last := 0
	for k in range(0, 24, 2):
		var d := RoomsScript.cell_local(RoomsScript.TEMPLATE_HOME, k) - door
		var gap := d.x * d.x + d.y * d.y
		assert_true(gap >= last, "cell %d no nearer the door than the one before" % (k / 2))
		last = gap


func test_quarter_turns_are_exact() -> void:
	"""One turn takes +X to +Z: (2048, 5) -> (-5, 2048) -> (-2048, -5) -> (5, -2048); -1 is 3."""
	var v := Vector2i(2048, 5)
	assert_equal(RoomsScript.rotate_u(v, 1), Vector2i(-5, 2048), "one")
	assert_equal(RoomsScript.rotate_u(v, 2), Vector2i(-2048, -5), "two")
	assert_equal(RoomsScript.rotate_u(v, 3), Vector2i(5, -2048), "three")
	assert_equal(RoomsScript.rotate_u(v, -1), RoomsScript.rotate_u(v, 3), "minus one")
	assert_equal(RoomsScript.rotate_u(v, 4), v, "four")


func test_the_door_the_mouth_and_the_sockets_stand_where_the_template_puts_them() -> void:
	"""The home at (6144, 5120) turned twice: its door's foot 2 m north (7168), its mouth a ramp's run beyond
	(11264), its sockets west, south and east. A cellar at the origin turned once: its hatch's foot 2 m east, its
	mouth at 6144, its sockets 2 m west and 1.5 m south."""
	var home := RoomsScript.TEMPLATE_HOME
	assert_equal(RoomsScript.door_at(home, HOME_AT, 2), Vector2i(6144, 7168), "the door's foot")
	assert_equal(RoomsScript.mouth_at(home, HOME_AT, 2), Vector2i(6144, 11264), "the door")
	var sockets := [RoomsScript.socket_at(home, HOME_AT, 2, 0), RoomsScript.socket_at(home, HOME_AT, 2, 1), RoomsScript.socket_at(home, HOME_AT, 2, 2)]
	assert_equal(sockets, [Vector2i(4096, 5120), Vector2i(6144, 3072), Vector2i(8192, 5120)], "the sockets")
	var cellar := RoomsScript.TEMPLATE_CELLAR
	assert_equal(RoomsScript.door_at(cellar, Vector2i.ZERO, 1), Vector2i(2048, 0), "the hatch's foot")
	assert_equal(RoomsScript.mouth_at(cellar, Vector2i.ZERO, 1), Vector2i(6144, 0), "the hatch")
	assert_equal([RoomsScript.socket_at(cellar, Vector2i.ZERO, 1, 0), RoomsScript.socket_at(cellar, Vector2i.ZERO, 1, 1)],
		[Vector2i(-2048, 0), Vector2i(0, 1536)], "the cellar's sockets")


func test_the_void_distances_are_exact() -> void:
	"""A home's void reaches 2252 u (2048 bowed out 10%): a point 3252 out is 1000 clear; a leg passing 3252 off
	its centre too. A cellar's void is 1689 across and 2048 along, turned or not; two homes 5504 apart keep 1000;
	vaults side by side 4078 apart keep 700; a home 4441 from a vault keeps 500."""
	var home := RoomsScript.TEMPLATE_HOME
	var cellar := RoomsScript.TEMPLATE_CELLAR
	assert_equal(RoomsScript.void_half(home), Vector2i(2252, 2252), "a home's void")
	assert_equal(RoomsScript.void_half(cellar), Vector2i(1689, 2048), "a cellar's")
	assert_equal(RoomsScript.gap_u(home, Vector2i.ZERO, 0, Vector2i(3252, 0)), 1000, "a point")
	assert_equal(RoomsScript.gap_u(home, Vector2i.ZERO, 0, Vector2i(100, 100)), 0, "inside")
	assert_equal(RoomsScript.leg_gap_u(home, Vector2i.ZERO, 0, Vector2i(-5000, 3252), Vector2i(5000, 3252)), 1000, "a leg")
	assert_equal(RoomsScript.gap_u(cellar, Vector2i.ZERO, 0, Vector2i(1989, 2448)), 500, "a vault's corner, 300 and 400 off")
	assert_equal(RoomsScript.gap_u(cellar, Vector2i.ZERO, 1, Vector2i(2448, 1989)), 500, "turned")
	assert_equal(RoomsScript.leg_gap_u(cellar, Vector2i.ZERO, 0, Vector2i(-5000, 2548), Vector2i(5000, 2548)), 500, "a leg along its end")
	assert_equal(RoomsScript.leg_gap_u(cellar, Vector2i.ZERO, 0, Vector2i(-5000, 0), Vector2i(5000, 0)), 0, "a leg through it")
	assert_equal(RoomsScript.voids_gap_u(home, Vector2i.ZERO, 0, home, Vector2i(5504, 0), 0), 1000, "two homes")
	assert_equal(RoomsScript.voids_gap_u(cellar, Vector2i.ZERO, 0, cellar, Vector2i(4078, 0), 0), 700, "two vaults")
	assert_equal(RoomsScript.voids_gap_u(home, Vector2i.ZERO, 0, cellar, Vector2i(4441, 0), 0), 500, "a home and a vault")
	assert_equal(RoomsScript.voids_gap_u(cellar, Vector2i(4441, 0), 0, home, Vector2i.ZERO, 0), 500, "either way round")


# --- a room on the network --------------------------------------------------------------------

func test_a_room_is_one_piece_its_door_a_mouth() -> void:
	"""Laid: a DOOR mouth, its ramp (a wide bore, 4 m, a shaft and 4 quanta) to the door's foot, the body (a
	room segment of the room class, 24 quanta) to the middle, and a walk to each socket -- all planned, all the
	room's, in one piece in the job list, its ramp the first to dig."""
	var graph := GraphScript.new()
	var ref := _home(graph)
	var r := ref[0]
	var rooms := graph.rooms
	var m: int = rooms.mouth[r]
	assert_equal(graph.mouth_kind[m], GraphScript.MOUTH_DOOR, "a front door")
	assert_equal(graph.node_at(graph.mouth_node[m]), Vector2i(6144, 11264), "at the mouth")
	var ramp: int = rooms.ramp[r]
	var body: int = rooms.body[r]
	assert_equal([ref[2], ref[3]], [rooms.piece[r], ramp], "the piece and its first segment")
	assert_equal([graph.seg_kind[ramp], int(graph.bore[ramp]), graph.length_u[ramp], graph.timeline_count(ramp)],
		[GraphScript.SEG_RAMP, Rules.BORE_WIDE, 4096, 5], "the ramp")
	assert_equal([graph.seg_kind[body], int(graph.bore[body]), graph.timeline_count(body)], [GraphScript.SEG_ROOM, Rules.BORE_ROOM, 24], "the body")
	assert_equal([graph.node_kind[graph.node_a[body]], graph.node_kind[graph.node_b[body]]], [GraphScript.NODE_DOOR, GraphScript.NODE_ROOM], "door to middle")
	for k in 3:
		var w := rooms.walk_of(r, k)
		assert_equal([graph.seg_kind[w], graph.node_a[w], graph.node_b[w]], [GraphScript.SEG_ROOM, rooms.middle[r], rooms.socket_of(r, k)], "walk %d" % k)
		assert_equal(graph.node_kind[rooms.socket_of(r, k)], GraphScript.NODE_SOCKET, "socket %d" % k)
		assert_true(graph.is_room_walk(w), "a walk")
	assert_equal(graph.phase.count(GraphScript.PHASE_PLANNED), 5, "five planned segments")
	assert_equal(graph.next_dig_for(0), ramp, "its ramp first in the job list")
	assert_equal(graph.piece_room[ref[2]], r, "the piece lays the room")


func test_a_cellar_s_mouth_is_a_hatch() -> void:
	"""A root cellar's way in is a HATCH mouth; it has two sockets and walks."""
	var graph := GraphScript.new()
	var ref := _home(graph, Vector2i.ZERO, 1, RoomsScript.TEMPLATE_CELLAR)
	assert_equal(graph.mouth_kind[graph.rooms.mouth[ref[0]]], GraphScript.MOUTH_HATCH, "a hatch")
	assert_equal(graph.phase.count(GraphScript.PHASE_PLANNED), 4, "ramp, body and two walks")


func test_the_body_cuts_the_room_cell_by_cell() -> void:
	"""The body's quantum k is cut in the room's cell k / 2: its point is the cell's middle in the world."""
	var graph := GraphScript.new()
	var ref := _home(graph)
	var body: int = graph.rooms.body[ref[0]]
	var cell0 := HOME_AT + RoomsScript.rotate_u(Vector2i(-588, -1419), HOME_TURNS)
	assert_equal(graph.quantum_point_u(body, 0), cell0, "quantum 0")
	assert_equal(graph.quantum_point_u(body, 1), cell0, "quantum 1")
	assert_equal(graph.quantum_point_u(body, 2), HOME_AT + RoomsScript.rotate_u(Vector2i(588, -1419), HOME_TURNS), "quantum 2")
	assert_true(graph.is_room_body(body), "the body")
	assert_false(graph.is_room_walk(body), "not a walk")


func test_the_walks_open_with_the_body_and_are_not_counted_in_the_piece() -> void:
	"""The piece's ticks are its ramp's and its body's only (5 + 24 loam quanta = 3277); digging them opens the
	walks too, and the piece is done."""
	var graph := GraphScript.new()
	var ref := _home(graph)
	var ticks := PackedInt32Array([0, 0])
	graph.piece_ticks_into(ref[2], ticks)
	assert_equal(ticks[1], 29 * LOAM_QUANTUM, "29 quanta of loam")
	_dig(graph, ref[2])
	for k in 3:
		assert_true(graph.is_open(graph.rooms.walk_of(ref[0], k)), "walk %d open" % k)
	assert_true(graph.piece_done(ref[2]), "done")
	assert_true(graph.rooms.is_done(graph, ref[0]), "the room dug")
	assert_equal(graph.rooms.dug_permille(graph, ref[0]), 1000, "all of it")


func test_a_room_dropped_before_any_ground_is_broken_frees_its_row() -> void:
	"""Called away with nothing dug, the room's piece is dropped: its row freed (generation on), its nodes gone --
	but a socket a passage reaches stays, as a plain junction."""
	var graph := GraphScript.new()
	_main(graph)
	var ref := _home(graph)
	var r := ref[0]
	var socket := graph.rooms.socket_of(r, 1)
	var spec := SpecScript.new()
	spec.set_route(_route([Vector2i(6144, 0), Vector2i(6144, 3072)]), 2)
	spec.start_kind = SpecScript.END_ON_SEGMENT
	spec.start_ref = 1
	spec.end_kind = SpecScript.END_NODE
	spec.end_ref = socket
	var passage := PackedInt32Array([-1, 0, -1])
	assert_true(graph.add_piece(spec, passage), "the passage laid")
	var gone := PackedInt32Array([graph.rooms.middle[r], graph.rooms.door[r], graph.mouth_node[graph.rooms.mouth[r]],
		graph.rooms.socket_of(r, 0), graph.rooms.socket_of(r, 2)])
	var mouth: int = graph.rooms.mouth[r]
	graph.start_dig(ref[3], ref[4], 0)
	graph.stop_digging(ref[3], ref[4])
	assert_false(graph.rooms.is_room(r), "the row freed")
	assert_equal(graph.rooms.generation[r], 1, "its generation on")
	for node in gone:
		assert_false(graph.is_node(node), "node %d freed" % node)
	assert_equal(graph.mouth_node[mouth], -1, "its door's mouth row freed")
	assert_equal(graph.node_kind[socket], GraphScript.NODE_JUNCTION, "the passage's socket a junction now")
	assert_equal(graph.node_room[socket], -1, "no room's")


# --- where a room may go --------------------------------------------------------------------

func test_the_fixture_home_may_be_dug() -> void:
	"""5 m from the main tunnel, its door facing away: nothing refuses it."""
	var graph := GraphScript.new()
	_main(graph)
	assert_equal(graph.rooms.refusal(graph, _site(), RoomsScript.TEMPLATE_HOME, HOME_AT, HOME_TURNS, Rules.TOP_LEVEL),
		RoomsScript.REFUSE_NONE, "may be dug")


func test_only_the_two_levels_are_dug() -> void:
	"""A room carries a level; level 1 and level 2 may be dug (decision 0212), and no other, refused in words."""
	var graph := GraphScript.new()
	for bad: int in [Rules.LEVEL_SURFACE, Rules.LEVEL_2 + 1]:
		var reason := graph.rooms.refusal(graph, _site(), RoomsScript.TEMPLATE_HOME, HOME_AT, HOME_TURNS, bad)
		assert_equal(reason, RoomsScript.REFUSE_LEVEL, "level %d" % bad)
		assert_true(RoomsScript.reason_text(reason).contains("first or the second"), "said")
	assert_equal(graph.rooms.refusal(graph, _site(), RoomsScript.TEMPLATE_HOME, HOME_AT, HOME_TURNS, Rules.LEVEL_2),
		RoomsScript.REFUSE_NONE, "level 2 may be dug")


func test_eight_rooms_fill_the_rooms_and_twenty_four_mouths_the_network() -> void:
	"""With MAX_ROOMS rooms laid another is refused FULL; with every mouth row taken, NETWORK_FULL."""
	var graph := GraphScript.new()
	for k in RoomsScript.MAX_ROOMS:
		_home(graph, Vector2i(-18000 + 4600 * k, -15000), 0)
	var at := Vector2i(0, 12000)
	assert_equal(graph.rooms.refusal(graph, _site(), RoomsScript.TEMPLATE_HOME, at, 0, Rules.TOP_LEVEL), RoomsScript.REFUSE_FULL, "full")
	var full := GraphScript.new()
	var ref := PackedInt32Array([-1, 0, -1])
	for k in Rules.MAX_MOUTHS / 2:
		assert_true(full.add_into(_route([Vector2i(-19000, -19000 + 1500 * k), Vector2i(-10808, -19000 + 1500 * k)]), 2, 0, ref), "tunnel %d" % k)
	assert_equal(full.rooms.refusal(full, _site(), RoomsScript.TEMPLATE_HOME, at, 0, Rules.TOP_LEVEL), RoomsScript.REFUSE_NETWORK_FULL,
		"no mouth row left")
	assert_false(full.add_room(RoomsScript.TEMPLATE_HOME, at, 0, 0, PackedInt32Array([0, 0, 0, 0, 0])), "add_room refuses it too")


func test_a_room_keeps_inside_the_village() -> void:
	"""Its mound (void and skirt) must lie inside the bounds, and its door too."""
	var graph := GraphScript.new()
	var edge := Vector2i(BOUNDS_U.end.x - 2764 + 1, 0)
	assert_equal(graph.rooms.refusal(graph, _site(), RoomsScript.TEMPLATE_HOME, edge, 0, Rules.TOP_LEVEL), RoomsScript.REFUSE_OUT_OF_BOUNDS,
		"the mound over the edge by a unit")
	var inside := Vector2i(BOUNDS_U.end.x - 2764, 0)
	assert_equal(graph.rooms.refusal(graph, _site(), RoomsScript.TEMPLATE_HOME, inside, 0, Rules.TOP_LEVEL), RoomsScript.REFUSE_NONE,
		"just inside")
	var low := Vector2i(0, BOUNDS_U.position.y + 2764)
	assert_equal(graph.rooms.refusal(graph, _site(), RoomsScript.TEMPLATE_HOME, low, 0, Rules.TOP_LEVEL), RoomsScript.REFUSE_OUT_OF_BOUNDS,
		"the mound inside, its door 6 m out over the edge")


func test_a_turned_cellar_keeps_its_length_inside_the_village() -> void:
	"""A cellar turned three times lies 4 m along x: its mound reaches 2048 + 512 each way from its middle (not
	its width's 1689 + 512), its door turned inward."""
	var graph := GraphScript.new()
	var edge := Vector2i(BOUNDS_U.end.x - 2560 + 1, 0)
	assert_equal(graph.rooms.refusal(graph, _site(), RoomsScript.TEMPLATE_CELLAR, edge, 3, Rules.TOP_LEVEL),
		RoomsScript.REFUSE_OUT_OF_BOUNDS, "over the edge by a unit")
	assert_equal(graph.rooms.refusal(graph, _site(), RoomsScript.TEMPLATE_CELLAR, edge - Vector2i(1, 0), 3, Rules.TOP_LEVEL),
		RoomsScript.REFUSE_NONE, "just inside")


func test_a_room_needs_a_node_row_for_every_socket() -> void:
	"""With five node rows free, a cellar (door, mouth, middle and two sockets) may go and a home (three
	sockets) is refused NETWORK_FULL."""
	var graph := GraphScript.new()
	var free := graph.node_kind.count(GraphScript.NODE_FREE)
	for n in graph.node_kind.size():
		if graph.node_kind[n] == GraphScript.NODE_FREE and free > 5:
			graph.node_kind[n] = GraphScript.NODE_JUNCTION
			free -= 1
	var at := Vector2i(0, 12000)
	assert_equal(graph.rooms.refusal(graph, _site(), RoomsScript.TEMPLATE_CELLAR, at, 0, Rules.TOP_LEVEL), RoomsScript.REFUSE_NONE,
		"a cellar fits")
	assert_equal(graph.rooms.refusal(graph, _site(), RoomsScript.TEMPLATE_HOME, at, 0, Rules.TOP_LEVEL), RoomsScript.REFUSE_NETWORK_FULL,
		"a home does not")


func test_a_room_is_not_dug_under_water_or_its_no_dig_band() -> void:
	"""A pond 3 m across whose band (half a bore) the void reaches is refused; one a unit further off is not;
	the door ramp over it is refused too."""
	var graph := GraphScript.new()
	var site := _site()
	var reach := 2252 + 512 + 1536
	site.water = _pond(Vector2i(reach - 1, 0), 1536)
	assert_equal(graph.rooms.refusal(graph, site, RoomsScript.TEMPLATE_HOME, Vector2i.ZERO, 0, Rules.TOP_LEVEL), RoomsScript.REFUSE_UNDER_WATER,
		"the band reached")
	site.water = _pond(Vector2i(reach, 0), 1536)
	assert_equal(graph.rooms.refusal(graph, site, RoomsScript.TEMPLATE_HOME, Vector2i.ZERO, 0, Rules.TOP_LEVEL), RoomsScript.REFUSE_NONE,
		"a unit clear")
	site.water = _pond(Vector2i(0, -4096), 600)
	assert_equal(graph.rooms.refusal(graph, site, RoomsScript.TEMPLATE_HOME, Vector2i.ZERO, 0, Rules.TOP_LEVEL), RoomsScript.REFUSE_UNDER_WATER,
		"its door ramp over water")
	site.water = _pond(Vector2i(2200, 0), 100)
	assert_equal(graph.rooms.refusal(graph, site, RoomsScript.TEMPLATE_CELLAR, Vector2i.ZERO, 0, Rules.TOP_LEVEL), RoomsScript.REFUSE_UNDER_WATER,
		"a cellar's side")


func test_a_room_is_not_dug_under_the_crop_beds() -> void:
	"""A 3 m bed whose square the mound reaches is refused; one clear of it is not; a bed on the door ramp's hood
	too."""
	var graph := GraphScript.new()
	var site := _site()
	site.beds_u = PackedInt32Array([2252 + 512 + 1536 - 1, 1536, 0])
	assert_equal(graph.rooms.refusal(graph, site, RoomsScript.TEMPLATE_HOME, Vector2i.ZERO, 0, Rules.TOP_LEVEL), RoomsScript.REFUSE_OVER_CROPS,
		"over a bed")
	site.beds_u = PackedInt32Array([2252 + 512 + 1536, 1536, 0])
	assert_equal(graph.rooms.refusal(graph, site, RoomsScript.TEMPLATE_HOME, Vector2i.ZERO, 0, Rules.TOP_LEVEL), RoomsScript.REFUSE_NONE,
		"beside it")
	site.beds_u = PackedInt32Array([0, 1536, -5500])
	assert_equal(graph.rooms.refusal(graph, site, RoomsScript.TEMPLATE_HOME, Vector2i.ZERO, 0, Rules.TOP_LEVEL), RoomsScript.REFUSE_OVER_CROPS,
		"the hood over a bed")
	site.beds_u = PackedInt32Array([0, 1536, 1689 + 512 + 1536 - 1])
	assert_equal(graph.rooms.refusal(graph, site, RoomsScript.TEMPLATE_CELLAR, Vector2i.ZERO, 1, Rules.TOP_LEVEL), RoomsScript.REFUSE_OVER_CROPS,
		"a turned cellar's side")


func test_a_room_is_not_dug_under_a_building() -> void:
	"""A building's footprint circle the mound reaches is refused; one on the hood too."""
	var graph := GraphScript.new()
	var site := _site()
	site.under_u = PackedInt32Array([2252 + 512 + 2000 - 1, 2000, 0])
	assert_equal(graph.rooms.refusal(graph, site, RoomsScript.TEMPLATE_HOME, Vector2i.ZERO, 0, Rules.TOP_LEVEL), RoomsScript.REFUSE_UNDER_BUILDING,
		"under a building")
	site.under_u = PackedInt32Array([2252 + 512 + 2000, 2000, 0])
	assert_equal(graph.rooms.refusal(graph, site, RoomsScript.TEMPLATE_HOME, Vector2i.ZERO, 0, Rules.TOP_LEVEL), RoomsScript.REFUSE_NONE,
		"clear")
	site.under_u = PackedInt32Array([1024 + 1000 - 1, 1000, -5000])
	assert_equal(graph.rooms.refusal(graph, site, RoomsScript.TEMPLATE_HOME, Vector2i.ZERO, 0, Rules.TOP_LEVEL), RoomsScript.REFUSE_UNDER_BUILDING,
		"the hood under it")


func test_a_room_keeps_a_metre_of_earth_from_another() -> void:
	"""Two homes' voids 1023 apart are refused; 1024 apart are not. Another room's ramp is kept off too."""
	var graph := GraphScript.new()
	_home(graph, Vector2i.ZERO, 0)
	var rooms := graph.rooms
	assert_equal(rooms.refusal(graph, _site(), RoomsScript.TEMPLATE_HOME, Vector2i(2 * 2252 + 1023, 0), 0, Rules.TOP_LEVEL),
		RoomsScript.REFUSE_NEAR_ROOM, "1023 of earth")
	assert_equal(rooms.refusal(graph, _site(), RoomsScript.TEMPLATE_HOME, Vector2i(2 * 2252 + 1024, 0), 0, Rules.TOP_LEVEL),
		RoomsScript.REFUSE_NONE, "1024")
	assert_equal(rooms.refusal(graph, _site(), RoomsScript.TEMPLATE_HOME, Vector2i(3500, -5000), 0, Rules.TOP_LEVEL),
		RoomsScript.REFUSE_NEAR_ROOM, "beside the other's door ramp")
	assert_true(RoomsScript.reason_text(RoomsScript.REFUSE_NEAR_ROOM).contains("1 m of earth"), "said")
	assert_equal(rooms.refusal(graph, _site(), RoomsScript.TEMPLATE_HOME, Vector2i(6000, 3000), 3, Rules.TOP_LEVEL),
		RoomsScript.REFUSE_NEAR_ROOM, "its own door ramp run past the other's void (3 m off its middle)")
	assert_equal(rooms.refusal(graph, _site(), RoomsScript.TEMPLATE_HOME, Vector2i(6000, 3000), 0, Rules.TOP_LEVEL),
		RoomsScript.REFUSE_NONE, "turned away, it may go")


func test_a_room_s_door_ramp_keeps_a_metre_of_earth_from_another_s() -> void:
	"""A home turned once has its ramp along z 0 from x 2 m to its door at 6 m; another whose ramp would run
	down x 6 m across it -- its void and each ramp clear of the other's void -- is refused; 4.6 m further off,
	not."""
	var graph := GraphScript.new()
	_home(graph, Vector2i.ZERO, 1)
	assert_equal(graph.rooms.refusal(graph, _site(), RoomsScript.TEMPLATE_HOME, Vector2i(6144, 4608), 0, Rules.TOP_LEVEL),
		RoomsScript.REFUSE_NEAR_ROOM, "ramp across ramp")
	assert_equal(graph.rooms.refusal(graph, _site(), RoomsScript.TEMPLATE_HOME, Vector2i(6144, 9216), 0, Rules.TOP_LEVEL),
		RoomsScript.REFUSE_NONE, "its mouth 3 m clear of the other's")


func test_a_room_s_door_ramp_keeps_off_trees() -> void:
	"""A tree 1.2 m beside the middle of a home's door ramp -- clear of its mound and its mouth -- stands over
	the cutting: refused; 1.4 m off, clear."""
	var graph := GraphScript.new()
	var site := _site()
	site.circles_u = PackedInt32Array([1200, 300, -4096])
	assert_equal(graph.rooms.refusal(graph, site, RoomsScript.TEMPLATE_HOME, Vector2i.ZERO, 0, Rules.TOP_LEVEL),
		RoomsScript.REFUSE_SURFACE_BLOCKED, "over the cutting")
	site.circles_u = PackedInt32Array([1400, 300, -4096])
	assert_equal(graph.rooms.refusal(graph, site, RoomsScript.TEMPLATE_HOME, Vector2i.ZERO, 0, Rules.TOP_LEVEL),
		RoomsScript.REFUSE_NONE, "beside it")


func test_a_room_s_mound_keeps_off_work_spots() -> void:
	"""A work spot (reach 0.4 m) 2.5 m from the home's middle lies under its mound (void and skirt 2.76 m):
	refused; 3.2 m off it is clear."""
	var graph := GraphScript.new()
	var site := _site()
	site.spots_u = PackedInt32Array([2560, 410, 0])
	assert_equal(graph.rooms.refusal(graph, site, RoomsScript.TEMPLATE_HOME, Vector2i.ZERO, 0, Rules.TOP_LEVEL),
		RoomsScript.REFUSE_SURFACE_BLOCKED, "under the mound")
	site.spots_u = PackedInt32Array([3277, 410, 0])
	assert_equal(graph.rooms.refusal(graph, site, RoomsScript.TEMPLATE_HOME, Vector2i.ZERO, 0, Rules.TOP_LEVEL),
		RoomsScript.REFUSE_NONE, "clear")


func test_a_room_keeps_a_metre_of_earth_from_a_tunnel() -> void:
	"""The main tunnel's bore half a metre wide at z 0: a home whose void comes within 1 m of it is refused; its
	door ramp across it too; one clear by a unit is not."""
	var graph := GraphScript.new()
	_main(graph)
	var rooms := graph.rooms
	var clear := 2252 + 1024 + 512
	assert_equal(rooms.refusal(graph, _site(), RoomsScript.TEMPLATE_HOME, Vector2i(6144, clear - 1), 2, Rules.TOP_LEVEL),
		RoomsScript.REFUSE_NEAR_TUNNEL, "a unit too near")
	assert_equal(rooms.refusal(graph, _site(), RoomsScript.TEMPLATE_HOME, Vector2i(6144, clear), 2, Rules.TOP_LEVEL),
		RoomsScript.REFUSE_NONE, "clear")
	assert_equal(rooms.refusal(graph, _site(), RoomsScript.TEMPLATE_HOME, Vector2i(6144, 5120), 0, Rules.TOP_LEVEL),
		RoomsScript.REFUSE_NEAR_TUNNEL, "its door ramp across the tunnel")


func test_a_room_s_mound_and_door_keep_off_trees_heaps_and_spots() -> void:
	"""A tree (an obstacle circle) under the mound, and a work spot on the door, are refused."""
	var graph := GraphScript.new()
	var site := _site()
	site.circles_u = PackedInt32Array([2252 + 512 + 300 - 1, 300, 0])
	assert_equal(graph.rooms.refusal(graph, site, RoomsScript.TEMPLATE_HOME, Vector2i.ZERO, 0, Rules.TOP_LEVEL), RoomsScript.REFUSE_SURFACE_BLOCKED,
		"a tree under the mound")
	site.circles_u = PackedInt32Array()
	site.spots_u = PackedInt32Array([0, 512, -6144])
	assert_equal(graph.rooms.refusal(graph, site, RoomsScript.TEMPLATE_HOME, Vector2i.ZERO, 0, Rules.TOP_LEVEL), RoomsScript.REFUSE_SURFACE_BLOCKED,
		"a work spot on the door")
	site.spots_u = PackedInt32Array([0, 512, -8000])
	assert_equal(graph.rooms.refusal(graph, site, RoomsScript.TEMPLATE_HOME, Vector2i.ZERO, 0, Rules.TOP_LEVEL), RoomsScript.REFUSE_NONE,
		"clear of it")


func test_every_refusal_has_its_own_words() -> void:
	"""REASONS has a line for every code, none the same."""
	var seen: Array[String] = []
	for code in range(1, RoomsScript.REASONS.size()):
		var words := RoomsScript.reason_text(code)
		assert_false(words.is_empty() or seen.has(words), "code %d: its own words" % code)
		seen.append(words)
	assert_equal(RoomsScript.REASONS.size(), RoomsScript.REFUSE_NEEDS_PASSAGE + 1, "one per code")


# --- a tunnel joins a room at a free socket (tunnel_plan.gd ROOMS) -----------------------------

func _passage_plan(graph: GraphScript, points: Array[Vector2i], start_kind: int, start_ref: int, end_ref: int) -> PlanScript:
	"""A plan laid through `points`, its start snapped as given and its end onto node `end_ref`."""
	var plan := PlanScript.new()
	for k in points.size():
		var kind := start_kind if k == 0 else (SpecScript.END_NODE if k == points.size() - 1 else SpecScript.END_NEW_MOUTH)
		var ref := start_ref if k == 0 else (end_ref if k == points.size() - 1 else -1)
		assert_equal(plan.try_add_snapped(points[k].x, points[k].y, kind, ref, BOUNDS_U, PackedInt32Array()), Rules.REFUSE_NONE, "point %d laid" % k)
	return plan


func test_a_point_snaps_to_a_free_socket_never_the_middle_or_the_door() -> void:
	"""Laid 0.5 m from the home's south socket it is that node; laid on the room's middle it snaps to nothing
	(nor onto the room's own segments); on its door's foot, not to that node (only onto its ramp, which the
	rules then refuse to join)."""
	var graph := GraphScript.new()
	var ref := _home(graph)
	var out := PackedInt32Array([0, -1, 0, 0])
	var socket := graph.rooms.socket_of(ref[0], 1)
	assert_equal(PlanScript.snap_into(graph, Vector2i(6144, 2560), out), SpecScript.END_NODE, "snapped")
	assert_equal(out[1], socket, "to the south socket")
	assert_equal(PlanScript.snap_into(graph, HOME_AT, out), SpecScript.END_NEW_MOUTH, "not the middle")
	PlanScript.snap_into(graph, Vector2i(6144, 7168), out)
	assert_false(out[0] == SpecScript.END_NODE, "not the door's foot")


func test_a_passage_straight_out_of_a_socket_joins_the_room() -> void:
	"""From the main tunnel's bore at (6144, 0) straight north to the south socket: accepted, dug or not."""
	var graph := GraphScript.new()
	_main(graph)
	var ref := _home(graph)
	var socket := graph.rooms.socket_of(ref[0], 1)
	var plan := _passage_plan(graph, [Vector2i(6144, 0), Vector2i(6144, 3072)], SpecScript.END_ON_SEGMENT, 1, socket)
	assert_equal(plan.piece_reason(graph, BOUNDS_U, PackedInt32Array()), Rules.REFUSE_NONE, "accepted before the room is dug")
	_dig(graph, ref[2])
	assert_equal(plan.piece_reason(graph, BOUNDS_U, PackedInt32Array()), Rules.REFUSE_NONE, "and after")


func test_a_passage_must_leave_its_socket_straight() -> void:
	"""Arriving 47.5 degrees off straight out (from the long tunnel's bore at 9.5 m) is refused; so is a leg from
	the socket straight for under a metre (900 u, less its bend's fillet) -- REFUSE_SOCKET_ANGLE, in words."""
	var graph := GraphScript.new()
	_long_main(graph)
	var ref := _home(graph)
	var socket := graph.rooms.socket_of(ref[0], 1)
	var slant := _passage_plan(graph, [Vector2i(9500, 0), Vector2i(6144, 3072)], SpecScript.END_ON_SEGMENT, 1, socket)
	assert_equal(slant.piece_reason(graph, BOUNDS_U, PackedInt32Array()), Rules.REFUSE_SOCKET_ANGLE, "45 degrees off")
	var short := _passage_plan(graph, [Vector2i(6144, 0), Vector2i(6300, 2172), Vector2i(6144, 3072)], SpecScript.END_ON_SEGMENT, 1, socket)
	assert_equal(short.piece_reason(graph, BOUNDS_U, PackedInt32Array()), Rules.REFUSE_SOCKET_ANGLE, "900 u straight")
	assert_true(Rules.link_text(Rules.REFUSE_SOCKET_ANGLE, "").contains("straight out"), "said")
	var bent := _passage_plan(graph, [Vector2i(7400, 0), Vector2i(6144, 1922), Vector2i(6144, 3072)], SpecScript.END_ON_SEGMENT, 1, socket)
	assert_equal(bent.piece_reason(graph, BOUNDS_U, PackedInt32Array()), Rules.REFUSE_SOCKET_ANGLE,
		"1150 u to a 33-degree bend: its fillet leaves under a metre straight")


func test_a_socket_takes_one_passage() -> void:
	"""Once a passage joins a socket, another to it (from the long tunnel's bore 1.8 m on) is refused
	REFUSE_SOCKET_TAKEN, and the socket no longer snaps."""
	var graph := GraphScript.new()
	_long_main(graph)
	var ref := _home(graph)
	var socket := graph.rooms.socket_of(ref[0], 1)
	var first := _passage_plan(graph, [Vector2i(6144, 0), Vector2i(6144, 3072)], SpecScript.END_ON_SEGMENT, 1, socket)
	var piece := PackedInt32Array([-1, 0, -1])
	assert_true(graph.add_piece(first.spec_of(0), piece), "the first passage")
	assert_false(graph.is_free_socket(socket), "taken")
	var tail := graph.last_splits[1]
	var second := _passage_plan(graph, [Vector2i(8000, 0), Vector2i(6144, 3072)], SpecScript.END_ON_SEGMENT, tail, socket)
	assert_equal(second.piece_reason(graph, BOUNDS_U, PackedInt32Array()), Rules.REFUSE_SOCKET_TAKEN, "a second")
	var out := PackedInt32Array([0, -1, 0, 0])
	assert_false(PlanScript.snap_into(graph, Vector2i(6144, 2900), out) == SpecScript.END_NODE and out[1] == socket, "no longer snapped to")


func test_a_tunnel_keeps_a_metre_of_earth_from_a_room() -> void:
	"""A tunnel passing 1 m and a half-bore minus a unit from the home's void is refused REFUSE_INTO_ROOM naming
	the room; a unit further off it is not; one crossing the room's walks is refused as breaking into it."""
	var graph := GraphScript.new()
	var ref := _home(graph)
	var x := 6144 - 2252 - 1024 - 512
	var near := PlanScript.new()
	near.try_add(x + 1, -4000, BOUNDS_U, PackedInt32Array())
	near.try_add(x + 1, 14000, BOUNDS_U, PackedInt32Array())
	assert_equal(near.piece_reason(graph, BOUNDS_U, PackedInt32Array()), Rules.REFUSE_INTO_ROOM, "too near")
	assert_equal(near.refused_name(graph), "Burrow home %d" % (ref[0] + 1), "named")
	var clear := PlanScript.new()
	clear.try_add(x, -4000, BOUNDS_U, PackedInt32Array())
	clear.try_add(x, 14000, BOUNDS_U, PackedInt32Array())
	assert_equal(clear.piece_reason(graph, BOUNDS_U, PackedInt32Array()), Rules.REFUSE_NONE, "clear")
	var through := PlanScript.new()
	through.try_add(-4000, 5120, BOUNDS_U, PackedInt32Array())
	through.try_add(16000, 5120, BOUNDS_U, PackedInt32Array())
	assert_equal(through.piece_reason(graph, BOUNDS_U, PackedInt32Array()), Rules.REFUSE_INTO_ROOM, "through it")


# --- the auto-passage (room_plan.gd) ------------------------------------------------------------

func test_a_room_near_the_network_proposes_its_passage_to_the_nearest_socket() -> void:
	"""The home turned once, 5 m north of the main tunnel: its passage runs from the bore at (6144, 0) straight
	to its south socket (socket 2 turned once), ending END_NODE there; standalone, none; far off, none."""
	var graph := GraphScript.new()
	_main(graph)
	var plan := RoomPlanScript.new()
	plan.kind = RoomsScript.TEMPLATE_HOME
	plan.centre_u = HOME_AT
	plan.turns = 1
	assert_equal(plan.check(graph, _site()), RoomsScript.REFUSE_NONE, "may be dug")
	assert_equal(plan.passage_socket, 2, "the south socket")
	assert_equal(plan.passage.count, 2, "a straight passage")
	assert_equal([plan.passage.point_u(0), plan.passage.point_u(1)], [Vector2i(6144, 0), Vector2i(6144, 3072)], "bore to socket")
	assert_equal([plan.passage.snap_kind[0], plan.passage.snap_ref[0]], [SpecScript.END_ON_SEGMENT, 1], "on the bore")
	assert_equal([plan.passage.snap_kind[1], plan.passage.snap_ref[1]], [SpecScript.END_NODE, -1], "the room's socket, not laid yet")
	plan.standalone = true
	plan.check(graph, _site())
	assert_equal(plan.passage.count, 0, "standalone: none")
	plan.standalone = false
	plan.centre_u = Vector2i(6144, 14000)
	plan.check(graph, _site())
	assert_equal(plan.passage_socket, -1, "beyond 6 m: none")


func _proposal(graph: GraphScript, at: Vector2i, turns: int) -> RoomPlanScript:
	"""A home's plan at `at` turned so, checked on an open site: its proposed passage, if any."""
	var plan := RoomPlanScript.new()
	plan.kind = RoomsScript.TEMPLATE_HOME
	plan.centre_u = at
	plan.turns = turns
	assert_equal(plan.check(graph, _site()), RoomsScript.REFUSE_NONE, "the home may be dug")
	return plan


func _open(graph: GraphScript, points: Array[Vector2i]) -> void:
	"""A tunnel through `points` laid for digger 0 and dug open."""
	var ref := PackedInt32Array([-1, 0, -1])
	assert_true(graph.add_into(_route(points), points.size(), 0, ref), "the tunnel stored")
	_dig(graph, ref[2])


func test_the_passage_takes_the_foot_of_the_perpendicular_when_it_is_shorter() -> void:
	"""A bore rising at 30 degrees below the home's south socket: the way straight out meets it 3500 u off, the
	perpendicular 3031 u off and 30 degrees from straight out -- the shorter is proposed."""
	var graph := GraphScript.new()
	_open(graph, [Vector2i(0, 0), Vector2i(20000, 11547)])
	var plan := _proposal(graph, Vector2i(8000, 10167), 3)
	assert_equal(plan.passage_socket, 0, "the south socket")
	assert_true(absi(plan.passage.length_u() - 3031) <= 2, "the perpendicular: %d" % plan.passage.length_u())


func test_the_passage_runs_straight_out_where_the_perpendicular_leans_too_far() -> void:
	"""A bore at 45 degrees below and beside the home: from its south and west sockets the perpendicular would
	leave 45 degrees off straight out, so the way straight out to the bore (3500 u) is proposed -- not the
	5.3 m from the bore's ramp foot."""
	var graph := GraphScript.new()
	_open(graph, [Vector2i(0, 0), Vector2i(16000, -16000)])
	var plan := _proposal(graph, Vector2i(10000, -4452), 1)
	assert_equal(plan.passage.count, 2, "a straight passage")
	assert_equal(plan.passage.length_u(), 3500, "straight out to the bore")
	assert_equal(plan.passage.snap_kind[0], SpecScript.END_ON_SEGMENT, "on the bore's side")


func test_the_passage_may_start_at_a_ramp_s_foot_but_never_on_a_ramp_s_side() -> void:
	"""Over an 8 m tunnel (two ramps and no bore) the passage starts at the ramps' shared foot, even with the
	socket 1.6 m to one side of it."""
	var graph := GraphScript.new()
	_open(graph, [Vector2i(0, 0), Vector2i(8192, 0)])
	var plan := _proposal(graph, Vector2i(2500, 5120), 1)
	assert_equal(plan.passage_socket, 2, "the south socket")
	assert_equal(plan.passage.point_u(0), Vector2i(4096, 0), "from the ramps' foot")
	assert_equal([plan.passage.snap_kind[0], graph.node_kind[plan.passage.snap_ref[0]]], [SpecScript.END_NODE, GraphScript.NODE_RAMP_END],
		"joined at that node")


func test_a_proposed_passage_starts_where_its_join_snapped() -> void:
	"""The home's south socket over the main bore half a metre from its ramp's foot: the foot of the
	perpendicular snaps onto that node, so the passage starts there and is measured from there (3113 u)."""
	var graph := GraphScript.new()
	_main(graph)
	var plan := _proposal(graph, Vector2i(4600, 5120), 1)
	assert_equal(plan.passage.point_u(0), Vector2i(4096, 0), "from the ramp's foot")
	assert_equal(plan.passage.snap_kind[0], SpecScript.END_NODE, "joined at it")
	assert_equal(plan.passage.length_u(), 3113, "and as long as that")


func test_a_passage_the_rules_pass_is_refused_beside_the_room_s_own_ramp() -> void:
	"""A passage from a new mouth 6 m off to a cellar's side socket, leaving 39 degrees toward its door ramp: the
	whole piece's rules pass it (the room not laid), but it comes within the pillar gap of its own ramp -- not
	accepted; straight out, accepted."""
	var graph := GraphScript.new()
	var plan := RoomPlanScript.new()
	plan.kind = RoomsScript.TEMPLATE_CELLAR
	for end: Vector2i in [Vector2i(6198, -3774), Vector2i(7536, 0)]:
		plan.passage.clear()
		plan.passage.pending_outward = Vector2i(1, 0)
		plan.passage.try_add_snapped(end.x, end.y, SpecScript.END_NEW_MOUTH, -1, BOUNDS_U, PackedInt32Array())
		plan.passage.try_add_snapped(1536, 0, SpecScript.END_NODE, -1, BOUNDS_U, PackedInt32Array())
		assert_equal(plan.passage.piece_reason(graph, BOUNDS_U, PackedInt32Array()), Rules.REFUSE_NONE, "the rules pass %s" % end)
		assert_equal(plan.accepts(graph, _site()), end.y == 0, "accepted from %s" % end)


func test_the_mound_is_cut_back_to_its_face_for_the_door() -> void:
	"""No vertex of a mound stands in front of its face within the notch either side of the door's way."""
	var RoomMesh: GDScript = load("res://demo/burrow/room_mesh.gd")
	var mound: ArrayMesh = RoomMesh.build_mound(Vector2(3.6, 3.6), 1.9, 2.0, 1.0)
	var inside := 0
	for v: Vector3 in mound.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		if absf(v.x) < 1.0:
			assert_true(v.z >= -2.0, "behind the face: %s" % v)
			inside += 1
	assert_true(inside > 20, "the notch has vertices to test (%d)" % inside)


func test_a_proposed_passage_keeps_off_the_room_s_own_door_ramp() -> void:
	"""A cellar's side socket (1.5 m east of its middle, its ramp running south from 2 m south): a passage leaving
	39 degrees south of east comes 2558 u from the ramp's foot (under the 2560 of a wide and a standard bore
	apart): refused; straight out east, 2560: clear."""
	var plan := RoomPlanScript.new()
	plan.kind = RoomsScript.TEMPLATE_CELLAR
	for end: Vector2i in [Vector2i(3500, -1600), Vector2i(4000, 0)]:
		plan.passage.clear()
		for p: Vector2i in [end, Vector2i(1536, 0)]:
			plan.passage.try_add_snapped(p.x, p.y, SpecScript.END_NEW_MOUTH, -1, BOUNDS_U, PackedInt32Array())
		assert_equal(plan.clear_of_own_ramp(), end.y == 0, "leaving toward %s" % end)


func test_a_passage_the_whole_piece_rules_refuse_is_not_proposed() -> void:
	"""The fixture's straight passage (bore to the south socket) would pass 0.7 m from another room's void: it is
	not proposed, and whatever is proposed instead passes the rules."""
	var graph := GraphScript.new()
	_main(graph)
	_home(graph, Vector2i(8900, 100), 1, RoomsScript.TEMPLATE_CELLAR)
	var plan := _proposal(graph, HOME_AT, 1)
	assert_false(plan.passage.count == 2 and plan.passage.point_u(0) == Vector2i(6144, 0), "not the straight passage")
	assert_true(plan.passage.count == 0 or plan.passage.piece_reason(graph, BOUNDS_U, PackedInt32Array()) == Rules.REFUSE_NONE,
		"nothing unsound")


func test_the_proposed_passage_is_laid_ending_at_the_room_s_socket() -> void:
	"""Laid as the tool lays it -- the room, then its passage with the socket's node -- the passage is a piece of
	the network ending at that socket, after the room in the job list."""
	var graph := GraphScript.new()
	_main(graph)
	var plan := RoomPlanScript.new()
	plan.centre_u = HOME_AT
	plan.turns = 1
	plan.check(graph, _site())
	var ref := PackedInt32Array([0, 0, 0, 0, 0])
	assert_true(graph.add_room(plan.kind, plan.centre_u, plan.turns, 3, ref), "the room")
	var socket := graph.rooms.socket_of(ref[0], plan.passage_socket)
	plan.passage.snap_ref[1] = socket
	assert_equal(plan.passage.piece_reason(graph, BOUNDS_U, PackedInt32Array()), Rules.REFUSE_NONE, "still sound with the room laid")
	var piece := PackedInt32Array([-1, 0, -1])
	assert_true(graph.add_piece(plan.passage.spec_of(3), piece), "the passage")
	assert_equal(graph.node_b[graph.first_of_piece(piece[2])], socket, "ending at the socket")
	var list := PackedInt32Array()
	graph.job_list_into(list)
	assert_equal(list, PackedInt32Array([ref[2], piece[2]]), "the room first")


# --- the door and the hatch are ways in -------------------------------------------------------

func _joined(graph: GraphScript) -> PackedInt32Array:
	"""The main tunnel, the home and its passage to the south socket, all dug: returns the home's ref."""
	_main(graph)
	var ref := _home(graph)
	var plan := _passage_plan(graph, [Vector2i(6144, 0), Vector2i(6144, 3072)], SpecScript.END_ON_SEGMENT, 1,
		graph.rooms.socket_of(ref[0], 1))
	var piece := PackedInt32Array([-1, 0, -1])
	assert_true(graph.add_piece(plan.spec_of(0), piece), "the passage")
	_dig(graph, ref[2])
	_dig(graph, piece[2])
	return ref


func test_the_door_is_a_way_in_and_out_on_the_paths() -> void:
	"""From the home's door the paths reach the tunnel's mouths through the room and its passage (door ramp,
	body, walk, passage); a wide walker (the badger) reaches the room's middle by the door but not the tunnel's
	standard bore."""
	var graph := GraphScript.new()
	var ref := _joined(graph)
	var door: int = graph.rooms.mouth[ref[0]]
	var path := PackedInt32Array()
	assert_true(graph.paths.path_into(graph, PathsScript.CLASS_ANY, door, graph.mouth_node[0], path), "door to mouth A")
	assert_equal(path.slice(0, 3), PackedInt32Array([graph.rooms.ramp[ref[0]], graph.rooms.body[ref[0]], graph.rooms.walk_of(ref[0], 1)]),
		"down the ramp, through the room, out at the south socket")
	var middle: int = graph.rooms.middle[ref[0]]
	assert_true(graph.paths.dist_u(graph, PathsScript.CLASS_WIDE, door, middle) < PathsScript.UNREACHED, "the badger in by the door")
	assert_equal(graph.paths.dist_u(graph, PathsScript.CLASS_WIDE, door, graph.mouth_node[0]), PathsScript.UNREACHED, "not on through the bore")
	assert_equal(graph.paths.nearest_mouth(graph, middle, PathsScript.CLASS_ANY), door, "the room's nearest way out its door")


func test_a_route_goes_in_by_the_front_door_or_by_the_tunnel() -> void:
	"""Bound for the room's middle: from beside the door the route goes in at it (its ramp the first leg); from
	beside the tunnel's mouth A, in at A and through the passage."""
	var space := CastSpaceScript.new()
	space.setup([], [])
	space.tunnels = GraphScript.new()
	var graph := space.tunnels
	var ref := _joined(graph)
	var walker := space.add_resident(Vector2(6.0, 12.0), BODY_M)
	graph.set_fit(walker, true)
	var middle: int = graph.rooms.middle[ref[0]]
	var out := PackedVector2Array()
	var legs := PackedInt32Array()
	space.plan_path(walker, Vector2(6.0, 12.0), graph.node_m(middle), BODY_M, out, legs, true, false, middle)
	assert_true(space.nav.last_found, "found from the door")
	assert_equal(RouterScript.leg_slot(legs[1]), graph.rooms.ramp[ref[0]], "in by the front door")
	space.plan_path(walker, Vector2(-1.0, 0.0), graph.node_m(middle), BODY_M, out, legs, true, false, middle)
	assert_true(space.nav.last_found, "found from mouth A")
	assert_equal(RouterScript.leg_slot(legs[1]), 0, "in at mouth A")
	assert_true(Array(legs).map(func(c: int) -> int: return RouterScript.leg_slot(c) if c >= 0 else -1).has(graph.rooms.walk_of(ref[0], 1)),
		"through the south socket")


func test_a_standalone_room_s_door_leads_only_into_its_room() -> void:
	"""`leads_on`: a dug standalone home's door is offered to the router only for a trip bound inside it (its
	middle), never as a way through; the tunnel's mouth leads on to its other mouth; joined by a passage, the
	home's door leads on too."""
	var graph := GraphScript.new()
	_main(graph)
	var alone := _home(graph, Vector2i(-10240, 10240), 0)
	_dig(graph, alone[2])
	var door: int = graph.rooms.mouth[alone[0]]
	assert_true(graph.mouth_usable(door), "its door open")
	assert_false(graph.leads_on(door, PathsScript.CLASS_ANY, -1), "no way through a standalone room")
	assert_false(graph.leads_on(door, PathsScript.CLASS_ANY, graph.mouth_node[0]), "nor to a goal it does not reach")
	assert_true(graph.leads_on(door, PathsScript.CLASS_ANY, graph.rooms.middle[alone[0]]), "a way in, for a trip into it")
	assert_true(graph.leads_on(0, PathsScript.CLASS_ANY, -1), "the tunnel's mouth leads on")
	var joined := GraphScript.new()
	var ref := _joined(joined)
	assert_true(joined.leads_on(joined.rooms.mouth[ref[0]], PathsScript.CLASS_ANY, -1), "a joined home's door leads on")
	assert_false(joined.leads_on(joined.rooms.mouth[ref[0]], PathsScript.CLASS_WIDE, -1), "but not for the badger, past the bore")


func test_a_standalone_room_s_door_is_not_offered_for_a_trip_on_the_surface() -> void:
	"""The router is offered the tunnel's two mouths for a trip across the surface, not a dug standalone home's
	door (it leads nowhere); for a trip into the home, its door too."""
	var space := CastSpaceScript.new()
	space.setup([], [])
	space.tunnels = GraphScript.new()
	var graph := space.tunnels
	_main(graph)
	var alone := _home(graph, Vector2i(-10240, 10240), 0)
	_dig(graph, alone[2])
	var walker := space.add_resident(Vector2(-10.0, 3.0), BODY_M)
	graph.set_fit(walker, true)
	var out := PackedVector2Array()
	var legs := PackedInt32Array()
	space.plan_path(walker, Vector2(-10.0, 3.0), Vector2(14.0, 3.0), BODY_M, out, legs, true, false)
	assert_equal(graph.router.mouth_count, 2, "the tunnel's mouths only")
	var middle: int = graph.rooms.middle[alone[0]]
	space.plan_path(walker, Vector2(-10.0, 3.0), graph.node_m(middle), BODY_M, out, legs, true, false, middle)
	assert_equal(graph.router.mouth_count, 3, "and its door, bound inside")


func test_everybeast_stands_upright_in_a_room() -> void:
	"""HEADROOM: in a room's segment (crown 2.75 m) the badger (2.55 m) lowers its head by nothing, as a mouse;
	in a widened bore (1.1 m) it stoops as far as it can."""
	var crown: int = Rules.BORE_CROWNS_U[Rules.BORE_ROOM]
	assert_equal(crown, Rules.ROOM_CROWN_U, "the room's crown")
	assert_equal(Rules.stoop_drop_u(Rules.to_u(2.55), crown), 0, "the badger upright")
	assert_equal(Rules.stoop_drop_u(Rules.to_u(1.0), crown), 0, "a mouse upright")
	assert_true(Rules.stoop_drop_u(Rules.to_u(2.55), Rules.BORE_CROWNS_U[Rules.BORE_WIDE]) > 0, "stooping in a wide bore")
	assert_true(crown >= Rules.to_u(2.55) + Rules.STOOP_CLEAR_U, "clear of the badger's head")
	assert_equal(Rules.fit_refusal_in(Rules.to_u(2.55), Rules.to_u(1.12), Rules.BORE_ROOM), Rules.FIT_OK, "the badger fits a room")


# --- the cellar API -------------------------------------------------------------------------

func test_the_cellar_api_keeps_its_shape_served_from_rooms() -> void:
	"""No cellar until dug, nor while it is bare (decision 0210: no racks, no store); fitted out, one entry {"id":
	Vector2i(slot, generation), "position": its hatch on the ground, "capacity_u": its racks' 105, "spoilage_permille":
	350, cool} -- the chambers' old shape -- and the pantry's provider entry &"root_cellar:<slot>:<generation>",
	labelled, at the hatch."""
	var graph := GraphScript.new()
	var ref := _home(graph, Vector2i(-6144, 6144), 0, RoomsScript.TEMPLATE_CELLAR)
	assert_equal(graph.rooms.cellars(graph).size(), 0, "none until dug")
	_dig(graph, ref[2])
	assert_equal(graph.rooms.cellars(graph).size(), 0, "none while it is bare")
	_furnish(graph, ref[0])
	var cellars := graph.rooms.cellars(graph)
	assert_equal(cellars.size(), 1, "one")
	var hatch := RoomsScript.mouth_at(RoomsScript.TEMPLATE_CELLAR, Vector2i(-6144, 6144), 0)
	assert_equal(cellars[0].keys(), ["id", "position", "capacity_u", "spoilage_permille"], "the keys")
	assert_equal(cellars[0]["id"], Vector2i(ref[0], ref[1]), "its (slot, generation)")
	assert_equal(cellars[0]["position"], Vector3(Rules.to_m(hatch.x), 0.0, Rules.to_m(hatch.y)), "at its hatch")
	assert_equal([cellars[0]["capacity_u"], cellars[0]["spoilage_permille"]], [105, 350], "its store")
	var entries := FarmCellars.entries(graph)
	assert_equal(entries[0][StorageScript.KEY_ID], StringName("root_cellar:%d:%d" % [ref[0], ref[1]]), "the provider's id")
	assert_equal(entries[0][StorageScript.KEY_LABEL], "Root cellar %d" % (ref[0] + 1), "labelled")
	assert_equal(entries[0][StorageScript.KEY_POSITION], cellars[0]["position"], "delivered at the hatch")
	assert_equal(graph.rooms.housing_line(graph), "Burrow homes: 0 (0 beds) · Root cellars: 1", "the panel's line")


func test_a_home_is_no_cellar_and_a_relaid_row_is_a_new_store() -> void:
	"""A dug home publishes no cellar; a cellar row freed (never dug) and laid again is a new generation."""
	var graph := GraphScript.new()
	var home := _home(graph)
	_dig(graph, home[2])
	_furnish(graph, home[0])
	assert_equal(graph.rooms.cellars(graph).size(), 0, "a home is no cellar")
	assert_equal(graph.rooms.beds(graph), 3, "its three beds, put in")
	var cellar := _home(graph, Vector2i(-8192, -8192), 0, RoomsScript.TEMPLATE_CELLAR)
	graph.start_dig(cellar[3], cellar[4], 0)
	graph.stop_digging(cellar[3], cellar[4])
	var again := _home(graph, Vector2i(-8192, -8192), 0, RoomsScript.TEMPLATE_CELLAR)
	assert_equal(again[0], cellar[0], "the same row")
	assert_equal(again[1], cellar[1] + 1, "a new generation")
	_dig(graph, again[2])
	_furnish(graph, again[0])
	assert_equal(graph.rooms.cellars(graph)[0]["id"], Vector2i(again[0], again[1]), "published as the new store")
	assert_equal(FarmCellars.entries(graph)[0][StorageScript.KEY_ID], StringName("root_cellar:%d:%d" % [again[0], again[1]]),
		"under a new pantry id")


# --- digging a room -------------------------------------------------------------------------

func test_a_room_s_crew_works_three_faces() -> void:
	"""The works give a room's body its crew's rate at ROOM_FACES faces: four at the face dig it at the pipeline
	for four on three faces (3000 + ...), where the ramp ran at the pipeline for four on one face."""
	var space := CastSpaceScript.new()
	space.setup([], [])
	var graph := space.tunnels
	var brains: Array[BrainScript] = []
	for i in 4:
		var brain := BrainScript.new()
		brain.index = space.add_resident(Vector2(float(i), -3.0), BODY_M)
		brain.configure(space, 1.0, BODY_M, i, {})
		brains.append(brain)
		graph.set_fit(i, true)
	var works: WorksScript = WorksScript.new()
	works.setup(space, brains, PackedStringArray(["Mouse", "Mouse", "Mouse", "Mouse"]), BOUNDS_U, func(_t: String) -> void: pass)
	var ref := _home(graph, HOME_AT, HOME_TURNS)
	var body: int = graph.rooms.body[ref[0]]
	for i in range(1, 4):
		works.crew.join(i, body)
		works.crew.set_present(i, true)
	graph.start_dig(body, graph.generation[body], 0)
	works.step(16000)
	assert_equal(graph.rate_permille[body], CrewScript.pipeline_permille(4, RoomsScript.ROOM_FACES) * works.crew.skills.factor_permille(0) / 1000,
		"four at three faces")
	assert_true(CrewScript.pipeline_permille(4, 3) > CrewScript.pipeline_permille(4, 1), "quicker than one face")
	works.free()


func test_the_room_readout_counts_its_cells_ramp_and_passage() -> void:
	"""A loam home standing alone: 24 cells and a 4 m ramp with its shaft, 29 quanta; one digger at 1000 per
	mille: (24 + 5) x 113 ticks over 750 an hour (decision 0421) is 4.3 h; 58 U of spoil; and it says it stands alone."""
	var plan := PlanScript.new()
	var text := ReadoutScript.room_text(RoomsScript.TEMPLATE_HOME, HOME_AT, 0, plan, null, 1000, 1000, 1, "")
	assert_equal(text, "Burrow home · 29 quanta · 4.3 h (one digger)\n58 U spoil · standalone: dig a tunnel to one of its sockets later",
		"the readout")
	var passage := PlanScript.new()
	passage.try_add_snapped(6144, 0, SpecScript.END_ON_SEGMENT, 1, BOUNDS_U, PackedInt32Array())
	passage.try_add_snapped(6144, 3072, SpecScript.END_NODE, -1, BOUNDS_U, PackedInt32Array())
	var joined := ReadoutScript.room_text(RoomsScript.TEMPLATE_HOME, HOME_AT, 2, passage, null, 1000, 3000, 3, "Tunnel 2")
	assert_true(joined.begins_with("Burrow home · 32 quanta"), "three passage quanta more: %s" % joined)
	assert_true(joined.ends_with("passage 3.0 m to Tunnel 2"), "and where it joins")


# --- edges the rules and the drawings turn on --------------------------------------------------

func test_a_room_needs_its_rows_to_the_last() -> void:
	"""A home takes 6 nodes (3 + its 3 sockets) and 5 segments (2 + 3): with exactly that many free it may be
	laid, with one fewer of either it may not."""
	var graph := GraphScript.new()
	for node in range(6, Rules.MAX_NODES):
		graph.node_kind[node] = GraphScript.NODE_JUNCTION
	for slot in range(5, Rules.MAX_SEGMENTS):
		graph.phase[slot] = GraphScript.PHASE_OPEN
	assert_true(graph.has_rows_for_room(3), "exactly enough")
	graph.node_kind[5] = GraphScript.NODE_JUNCTION
	assert_false(graph.has_rows_for_room(3), "a node short")
	graph.node_kind[5] = GraphScript.NODE_FREE
	graph.phase[4] = GraphScript.PHASE_OPEN
	assert_false(graph.has_rows_for_room(3), "a segment short")


func test_a_tunnel_may_not_cross_a_room_s_door_ramp() -> void:
	"""A tunnel crossing the home's door ramp is refused as breaking into the room, named."""
	var graph := GraphScript.new()
	var ref := _home(graph)
	var cross := PlanScript.new()
	cross.try_add(-4000, 9216, BOUNDS_U, PackedInt32Array())
	cross.try_add(16000, 9216, BOUNDS_U, PackedInt32Array())
	assert_equal(cross.piece_reason(graph, BOUNDS_U, PackedInt32Array()), Rules.REFUSE_INTO_ROOM, "across its door ramp")
	assert_equal(cross.refused_name(graph), "Burrow home %d" % (ref[0] + 1), "named")


func test_the_digger_s_line_names_the_room_it_digs() -> void:
	"""The party panel says "Digging Burrow home 1 — 43%" for a room, and "Digging tunnel — 43%" at a plain dig
	site."""
	var Panel: GDScript = load("res://demo/control/demo_party_panel.gd")
	assert_equal(Panel.state_text(BrainScript.ACTIVITY_DIGGING, &"pull_radish", "Burrow home 1", 43), "Digging Burrow home 1 — 43%", "a room")
	assert_equal(Panel.state_text(BrainScript.ACTIVITY_DIGGING, &"pull_radish", "dig site", 43), "Digging tunnel — 43%", "a tunnel")


func test_a_bed_alcove_bows_the_wall_out() -> void:
	"""At an alcove's middle a home's wall stands out by the whole share; away from every alcove, not at all;
	part way in, in between."""
	var RoomMesh: GDScript = load("res://demo/burrow/room_mesh.gd")
	var alcoves := PackedFloat32Array([1.0])
	assert_almost_equal(RoomMesh.alcove_scale(1.0, alcoves, 0.25), 1.25, "the alcove's middle")
	assert_almost_equal(RoomMesh.alcove_scale(2.0, alcoves, 0.25), 1.0, "away from it")
	var part: float = RoomMesh.alcove_scale(1.2, alcoves, 0.25)
	assert_true(part > 1.0 and part < 1.25, "part way: %s" % part)
	assert_true(RoomMesh.alcove_scale(-3.1, PackedFloat32Array([3.1]), 0.25) > 1.2, "across the half-turn's seam")


func test_a_passage_is_cut_by_the_room_s_wall_once_the_room_is_dug() -> void:
	"""A bore ending at a room's socket is cut there by a plane (a negative radius, the angle into the room) once
	the room is dug; before, not at all. Its door ramp is cut at the door's foot as soon as the room breaks
	ground."""
	var graph := GraphScript.new()
	var ref := _joined_undug(graph)
	var BoreView: GDScript = load("res://demo/tunnel/bore_view.gd")
	var bores = BoreView.new()
	bores.configure(graph)
	var socket := graph.rooms.socket_of(ref[0], 1)
	assert_equal(bores.room_cut(socket), Vector4.ZERO, "the room undug: no cut")
	assert_equal(bores.room_cut(graph.rooms.door[ref[0]]), Vector4.ZERO, "nor at its door")
	var body: int = graph.rooms.body[ref[0]]
	_dig_ramp(graph, ref)
	graph.start_dig(body, graph.generation[body], 0)
	graph.advance(body, graph.generation[body], 2000000)
	assert_true(bores.room_cut(graph.rooms.door[ref[0]]).z < 0.0, "broken ground: its door is cut")
	assert_equal(bores.room_cut(socket), Vector4.ZERO, "but not the socket until the room is dug")
	_dig(graph, ref[2])
	var cut: Vector4 = bores.room_cut(socket)
	assert_equal([cut.x, cut.y, cut.z], [6.0, 3.0, -1.0], "a plane through the socket")
	assert_almost_equal(cut.w, PI * 0.5, "facing into the room (north)")
	assert_true(bores.room_cut(graph.rooms.door[ref[0]]).z < 0.0, "and at its door")
	bores.free()


static func _dig_ramp(graph: GraphScript, ref: PackedInt32Array) -> void:
	"""Dig room `ref`'s door ramp open."""
	graph.start_dig(ref[3], ref[4], 0)
	graph.advance(ref[3], ref[4], 1000000000)


func _joined_undug(graph: GraphScript) -> PackedInt32Array:
	"""The main tunnel and the home with its passage to the south socket laid, the passage dug, the home not."""
	_main(graph)
	var ref := _home(graph)
	var plan := _passage_plan(graph, [Vector2i(6144, 0), Vector2i(6144, 3072)], SpecScript.END_ON_SEGMENT, 1,
		graph.rooms.socket_of(ref[0], 1))
	var piece := PackedInt32Array([-1, 0, -1])
	assert_true(graph.add_piece(plan.spec_of(0), piece), "the passage")
	_dig(graph, piece[2])
	return ref
