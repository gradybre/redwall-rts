extends RefCounted
## THE UNDERGROUND AS ONE PACKED GRAPH. Decision 0208 (the underground revamp's P2; design
## docs/design/underground_revamp.md §3), replacing tunnel_network.gd's eight straight slots.
## Presentation only: it shapes the demo cast's walks and nothing else (MOVE-G01..05 stay open).
##
## ---------------------------------------------------------------------------------------
## TABLES, sized once (Rules.MAX_*), each row an EntityRef (slot, generation): a slot freed and reused
## bumps its generation, so an old reference never reaches the new row.
##   NODES     kind (MOUTH on the surface, JUNCTION where bores meet, RAMP_END at a ramp's foot), (x, z) in
##             u, level, and up to Rules.JUNCTION_DEGREE segments.
##   SEGMENTS  a bore between two nodes: kind (BORE, or RAMP from a mouth down to its foot), level, route
##             polyline (its two nodes and up to six bends between, u), bore class, braced, lit, closed and
##             the closed stretch, the dig timeline and its progress. A segment is what a tunnel slot was:
##             jobs, hazards, crews, lanterns and the drawn bore are all per segment, and "Tunnel N" is
##             segment N - 1.
##   MOUTHS    each mouth node's row: its heap's place, the spoil heaped there, and its line
##             (tunnel_queue.gd, by mouth row).
##   PIECES    one dig the player laid: its segments in dig order, who digs it, where its spoil goes, its
##             place in THE JOB LIST.
## LEVELS: every node and segment carries its level (MOVE-REQ-013: the same x, z at another level is another
## place). Level 1's floor lies Rules.BORE_FLOOR_DEPTH_U down; only level 1 is dug (P6 adds level 2).
##
## PIECES. The dig tool lays a piece (piece_spec.gd): from a new mouth or a point on the network, to a new
## mouth or a point on it, crossing open bores on the way. `add_piece` stores it as segments: a mouth's RAMP
## (the first or last Rules.RAMP_RUN_U of the piece, straight, down to a RAMP_END node) and BORES between,
## cut at every junction. A piece meeting an open segment's route splits it there: the first half keeps the
## slot and generation, the second takes a new slot, both open with the host's class, bracing, light and
## spoil mouth. `last_splits` lists every split the last `add_piece` made (tunnel_works.gd moves walkers,
## chambers and hazards onto the halves).
##
## LIFE (per segment). PLANNED (queued, nothing dug) -> DIGGING (its digger works it, or is on the way) ->
## OPEN when its last tick is dug. A digger called away leaves it PAUSED with every tick it earned (ECON-005:
## pause retains physical progress) -- or, when not one tick of its whole piece was dug, the piece is dropped:
## no ground was broken, so there is nothing to keep. A digger that could NOT REACH the start leaves it
## PAUSED however little was dug (`hold_unreached`): the player chose that route, so it is kept to resume.
## An OPEN segment is never removed (MOVE-REQ-004); only OPEN segments no hazard has CLOSED are walked
## (MOVE-REQ-002: unfinished space is never a through route).
##
## THE DIG TIMELINE (per segment): a chain of cut quanta -- a shaft where it starts at a mouth, one per
## started metre of bore, a shaft where it breaks out at a mouth -- each dug in the ticks its GROUND takes
## (tunnel_ground.gd; all loam: exactly the cited 113). `_q_end` holds each quantum's end tick (a prefix
## sum). Work is credited in F1000-equivalent microseconds scaled by the segment's crew rate, the remainder
## kept, so no microsecond is lost or counted twice. A segment is dug from its node A to its node B.
##
## SPOIL. A piece's cuts go out at its SPOIL MOUTH: the mouth it opens at its start, or -- a piece begun
## inside the network -- the network's mouth nearest its start when it was laid. Only a shaft breaking out
## at a mouth heaps there. Every cut is posted to its mouth's tally as it completes (`mouth_spoil`), so a
## heap is read in O(1); re-digging (a widening, a clearing, a chamber) posts at the segment's spoil mouth.
##
## THE JOB LIST. Pieces wait in the order they were laid; a digger works one piece at a time, segment by
## segment, and `next_dig_for` says what it takes up next.
##
## ROOMS (decision 0209, the revamp's P3): a burrow home or root cellar is its own structure on the graph,
## held in `rooms` (demo/burrow/underground_rooms.gd) and laid by `add_room` as ONE PIECE: a MOUTH of kind
## DOOR or HATCH on the surface and its RAMP down to the DOOR node in the room's wall; the BODY, a ROOM
## segment from the door node to the room's MIDDLE node, whose timeline is the room's own quanta cell by cell
## (`quantum_point_u`); and a WALK, a ROOM segment from the middle to each SOCKET node in its wall, opened with
## the body -- never dug, and not counted in the piece's ticks. Room segments are BORE_ROOM (everybeast fits
## and stands upright in them), the ramp WIDE (the badger comes in by the front door). A passage joins a room
## only at a free socket (tunnel_plan.gd). A room piece dropped before any ground was broken frees its room
## row; a socket a passage still reaches stays as a plain junction.
##
## FIT and PLANNING are the old network's, per segment: each resident's body is recorded once (`set_body`),
## fit is judged against a segment's bore class and a load's width, and `plan` asks the router
## (tunnel_router.gd) with every usable mouth nobody stands on, costed through the paths (graph_paths.gd:
## Dijkstra from each mouth over the open segments a walker fits).
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const RouterScript := preload("res://demo/tunnel/tunnel_router.gd")
const PathsScript := preload("res://demo/tunnel/graph_paths.gd")
const SpecScript := preload("res://demo/tunnel/piece_spec.gd")
const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")
const CastNavScript := preload("res://demo/cast/cast_nav.gd")
const GroundScript := preload("res://demo/tunnel/tunnel_ground.gd")
const QueueScript := preload("res://demo/tunnel/tunnel_queue.gd")
const CrossingHookScript := preload("res://demo/cast/crossing_hook.gd")

const NODE_FREE: int = 0
const NODE_MOUTH: int = 1
const NODE_JUNCTION: int = 2
const NODE_RAMP_END: int = 3
## A room's (decision 0209): its middle, a socket in its wall, and its door ramp's foot in its wall.
const NODE_ROOM: int = 4
const NODE_SOCKET: int = 5
const NODE_DOOR: int = 6
const SEG_BORE: int = 0
const SEG_RAMP: int = 1
## A walk inside a room: its door's foot or a socket to its middle (decision 0209).
const SEG_ROOM: int = 2
## A mouth's kind (design §3 "surface kind"): a tunnel's ramp, a home's front door, a cellar's hatch.
const MOUTH_TUNNEL: int = 0
const MOUTH_DOOR: int = 1
const MOUTH_HATCH: int = 2

const PHASE_FREE: int = 0
const PHASE_DIGGING: int = 1
const PHASE_PAUSED: int = 2
const PHASE_OPEN: int = 3
const PHASE_PLANNED: int = 4

const PAUSED_CALLED_AWAY: int = 1
const PAUSED_UNREACHED: int = 2

const CLOSED_NONE: int = 0
const CLOSED_FLOODED: int = 1
const CLOSED_COLLAPSED: int = 2

## The longest timeline: a shaft, 64 bore quanta (MAX_LENGTH_U) and a shaft.
const MAX_TIMELINE: int = Rules.MAX_LENGTH_U / Rules.QUANTUM_U + 2 * Rules.SHAFT_QUANTA
const DEGREE: int = Rules.JUNCTION_DEGREE
## Demo: a lit bore is walked at this per mille of walk speed (tunnel_jobs.gd LANTERNS).
const LIT_SPEED_PERMILLE: int = 1100
## The router's cache revision: the network's in the low bits, the crossings' above them.
const REVISION_SHIFT: int = 32
## A route point this near a segment's polyline lies on it (u): a split finds its host by this.
const ON_ROUTE_U: int = 4

## progress_into() writes these slots.
const P_CUTS: int = 0
const P_SPOIL: int = 1
const P_STONE: int = 2
const P_QUANTUM: int = 3
const P_INTO: int = 4
const P_SIZE: int = 5

# --- nodes ----------------------------------------------------------------------------------
var node_kind: PackedByteArray = PackedByteArray()
var node_level: PackedByteArray = PackedByteArray()
var node_gen: PackedInt32Array = PackedInt32Array()
var node_x_u: PackedInt32Array = PackedInt32Array()
var node_z_u: PackedInt32Array = PackedInt32Array()
## DEGREE segment slots per node (-1: none).
var node_seg: PackedInt32Array = PackedInt32Array()
## The mouth row of a MOUTH node (-1 otherwise).
var node_mouth: PackedInt32Array = PackedInt32Array()
## The room row of a room's MIDDLE, SOCKET, DOOR or MOUTH node (-1 otherwise).
var node_room: PackedInt32Array = PackedInt32Array()

# --- segments -------------------------------------------------------------------------------
var phase: PackedByteArray = PackedByteArray()
var generation: PackedInt32Array = PackedInt32Array()
var seg_kind: PackedByteArray = PackedByteArray()
var seg_level: PackedByteArray = PackedByteArray()
var node_a: PackedInt32Array = PackedInt32Array()
var node_b: PackedInt32Array = PackedInt32Array()
var piece: PackedInt32Array = PackedInt32Array()
var piece_rank: PackedInt32Array = PackedInt32Array()
## The mouth row a segment's entry shaft and bore spoil at.
var spoil_mouth: PackedInt32Array = PackedInt32Array()
## The room row a room's ramp, body or walk belongs to (-1: a tunnel's).
var seg_room: PackedInt32Array = PackedInt32Array()
var digger: PackedInt32Array = PackedInt32Array()
var point_count: PackedInt32Array = PackedInt32Array()
## (x, z) pairs in u, Rules.MAX_POINTS per segment.
var points_u: PackedInt32Array = PackedInt32Array()
## Distance from node A to each point, in u, Rules.MAX_POINTS per segment.
var cumulative_u: PackedInt32Array = PackedInt32Array()
var length_u: PackedInt32Array = PackedInt32Array()
## What the route costs a planner (legs rounded up), in u.
var cost_u: PackedInt32Array = PackedInt32Array()
## Why a PAUSED segment waits (PAUSED_*; 0 otherwise).
var pause_reason: PackedByteArray = PackedByteArray()
var quanta: PackedInt32Array = PackedInt32Array()
## F1000-equivalent microseconds of digging credited, and the crew rate's remainder.
var dig_usec: PackedInt64Array = PackedInt64Array()
var dig_rem: PackedInt64Array = PackedInt64Array()
var rate_permille: PackedInt32Array = PackedInt32Array()
## Per segment: bore class (Rules.BORE_*), braced and lit (0/1), CLOSED_*, and the closed stretch.
var bore: PackedByteArray = PackedByteArray()
var braced: PackedByteArray = PackedByteArray()
var lit: PackedByteArray = PackedByteArray()
var closed: PackedByteArray = PackedByteArray()
var closed_from_u: PackedInt32Array = PackedInt32Array()
var closed_to_u: PackedInt32Array = PackedInt32Array()
## Spoil (milli-U) re-digging heaped from this segment (widening, clearing a collapse, a chamber).
var extra_spoil: PackedInt64Array = PackedInt64Array()
## Spoil (milli-U) this segment's dig has posted: at its spoil mouth, and at the mouth it broke out at.
var posted_in: PackedInt64Array = PackedInt64Array()
var posted_out: PackedInt64Array = PackedInt64Array()

# --- mouths ---------------------------------------------------------------------------------
## The node of each mouth row (-1: free), its generation, its heap's centre (m), finished radius (0: not
## placed) and way out (the heap's side), and all the spoil posted there (milli-U).
var mouth_node: PackedInt32Array = PackedInt32Array()
var mouth_gen: PackedInt32Array = PackedInt32Array()
## MOUTH_TUNNEL, MOUTH_DOOR or MOUTH_HATCH.
var mouth_kind: PackedByteArray = PackedByteArray()
var heap_at: PackedVector2Array = PackedVector2Array()
var heap_radius_m: PackedFloat32Array = PackedFloat32Array()
var heap_dir: PackedVector2Array = PackedVector2Array()
var mouth_spoil: PackedInt64Array = PackedInt64Array()

# --- pieces ---------------------------------------------------------------------------------
var piece_live: PackedByteArray = PackedByteArray()
var piece_gen: PackedInt32Array = PackedInt32Array()
## When each piece was laid (the job list's order), who digs it, and its spoil mouth.
var piece_order: PackedInt32Array = PackedInt32Array()
var piece_digger: PackedInt32Array = PackedInt32Array()
var piece_mouth: PackedInt32Array = PackedInt32Array()
## The room row a room's piece lays (-1: a tunnel).
var piece_room: PackedInt32Array = PackedInt32Array()

# --- residents ------------------------------------------------------------------------------
## Per resident index: 1 when its body fits a standard bore; its height and radius in u (0: unknown).
var resident_fit: PackedByteArray = PackedByteArray()
var body_height_u: PackedInt32Array = PackedInt32Array()
var body_radius_u: PackedInt32Array = PackedInt32Array()

## Bumped whenever anything a route depends on changes (a segment added, split, dug open, paused, freed,
## widened, braced, lit, closed or reopened).
var revision: int = 0
## Bumped whenever the graph's shape changes (a piece added or dropped, a segment split).
var topology: int = 0
## (old segment, new segment, split along the old, u) per split the last `add_piece` made.
var last_splits: PackedInt32Array = PackedInt32Array()
## Surface walking speed per mille (the weather's), for planning.
var surface_permille: int = 1000
var router: RouterScript = RouterScript.new()
var paths: PathsScript = PathsScript.new()
var queue: QueueScript = QueueScript.new()
var ground: GroundScript = null
## The rooms (see ROOMS).
var rooms: RoomsScript = RoomsScript.new()

var _q_kind: PackedByteArray = PackedByteArray()
var _q_end: PackedInt32Array = PackedInt32Array()
var _progress: PackedInt64Array = PackedInt64Array()
var _piece_count: int = 0
var _family: PackedInt32Array = PackedInt32Array()
var _chain_node: PackedInt32Array = PackedInt32Array()
var _chain_along: PackedInt32Array = PackedInt32Array()


func _init() -> void:
	"""Size every column once."""
	_size_nodes()
	_size_segment_bytes()
	_size_segment_ints()
	_size_mouths()
	_size_pieces()
	points_u.resize(Rules.MAX_SEGMENTS * Rules.MAX_POINTS * 2)
	cumulative_u.resize(Rules.MAX_SEGMENTS * Rules.MAX_POINTS)
	_q_kind.resize(Rules.MAX_SEGMENTS * MAX_TIMELINE)
	_q_end.resize(Rules.MAX_SEGMENTS * MAX_TIMELINE)
	_progress.resize(P_SIZE)


func _size_nodes() -> void:
	"""Size the node columns."""
	node_kind.resize(Rules.MAX_NODES)
	node_level.resize(Rules.MAX_NODES)
	node_gen.resize(Rules.MAX_NODES)
	node_x_u.resize(Rules.MAX_NODES)
	node_z_u.resize(Rules.MAX_NODES)
	node_seg.resize(Rules.MAX_NODES * DEGREE)
	node_seg.fill(-1)
	node_mouth.resize(Rules.MAX_NODES)
	node_mouth.fill(-1)
	node_room.resize(Rules.MAX_NODES)
	node_room.fill(-1)


func _size_segment_bytes() -> void:
	"""Size the per-segment byte columns."""
	for column: PackedByteArray in [phase, seg_kind, seg_level, pause_reason, bore, braced, lit, closed]:
		column.resize(Rules.MAX_SEGMENTS)


func _size_segment_ints() -> void:
	"""Size the per-segment integer columns."""
	for column: PackedInt32Array in [generation, node_a, node_b, piece, piece_rank, spoil_mouth, digger,
			point_count, length_u, cost_u, quanta, rate_permille, closed_from_u, closed_to_u, seg_room]:
		column.resize(Rules.MAX_SEGMENTS)
	digger.fill(-1)
	seg_room.fill(-1)
	rate_permille.fill(Rules.PERMILLE)
	for column: PackedInt64Array in [dig_usec, dig_rem, extra_spoil, posted_in, posted_out]:
		column.resize(Rules.MAX_SEGMENTS)


func _size_mouths() -> void:
	"""Size the mouth columns."""
	mouth_node.resize(Rules.MAX_MOUTHS)
	mouth_node.fill(-1)
	mouth_gen.resize(Rules.MAX_MOUTHS)
	mouth_kind.resize(Rules.MAX_MOUTHS)
	heap_at.resize(Rules.MAX_MOUTHS)
	heap_radius_m.resize(Rules.MAX_MOUTHS)
	heap_dir.resize(Rules.MAX_MOUTHS)
	mouth_spoil.resize(Rules.MAX_MOUTHS)


func _size_pieces() -> void:
	"""Size the piece columns."""
	piece_live.resize(Rules.MAX_PIECES)
	for column: PackedInt32Array in [piece_gen, piece_order, piece_digger, piece_mouth, piece_room]:
		column.resize(Rules.MAX_PIECES)
	piece_digger.fill(-1)
	piece_room.fill(-1)


func set_ground(value: GroundScript) -> void:
	"""The ground new segments are dug through (null: all loam)."""
	ground = value


# --- references -----------------------------------------------------------------------------

func is_ref(slot: int, gen: int) -> bool:
	"""Whether (slot, gen) names a segment that still exists (EntityRef validation)."""
	return slot >= 0 and slot < Rules.MAX_SEGMENTS and phase[slot] != PHASE_FREE and generation[slot] == gen


func is_node(node: int) -> bool:
	"""Whether `node` is a live node."""
	return node >= 0 and node < Rules.MAX_NODES and node_kind[node] != NODE_FREE


func is_open(slot: int) -> bool:
	"""Whether a segment is dug open."""
	return phase[slot] == PHASE_OPEN


func is_usable(slot: int) -> bool:
	"""Whether a segment is open and no hazard has closed it: one a walker may be routed through."""
	return phase[slot] == PHASE_OPEN and closed[slot] == CLOSED_NONE


func is_unfinished(slot: int) -> bool:
	"""Whether a segment is being dug, paused or planned."""
	var p := phase[slot]
	return p == PHASE_DIGGING or p == PHASE_PAUSED or p == PHASE_PLANNED


func open_count() -> int:
	"""How many segments are dug open."""
	return phase.count(PHASE_OPEN)


func has_room() -> bool:
	"""Whether the network has room for at least one more piece of the smallest kind (a mouth, a ramp and
	a bore)."""
	return node_kind.count(NODE_FREE) >= 4 and phase.count(PHASE_FREE) >= 3 \
			and mouth_node.count(-1) >= 2 and piece_live.count(0) >= 1


# --- nodes ----------------------------------------------------------------------------------

func node_at(node: int) -> Vector2i:
	"""A node's (x, z) in u."""
	return Vector2i(node_x_u[node], node_z_u[node])


func node_m(node: int) -> Vector2:
	"""A node's (x, z) in metres (presentation)."""
	return Vector2(Rules.to_m(node_x_u[node]), Rules.to_m(node_z_u[node]))


func node_floor_y(node: int) -> float:
	"""The floor's height at a node (m): 0 at a mouth, the level's floor below."""
	if node_kind[node] == NODE_MOUTH:
		return 0.0
	return -Rules.to_m(Rules.level_floor_depth_u(node_level[node]))


func degree(node: int) -> int:
	"""How many segments meet at a node."""
	var n := 0
	for k in DEGREE:
		n += 1 if node_seg[node * DEGREE + k] >= 0 else 0
	return n


func node_segment(node: int, k: int) -> int:
	"""The `k`-th segment slot at a node (-1: none)."""
	return node_seg[node * DEGREE + k]


func dug_degree(node: int) -> int:
	"""How many segments meeting at a node have broken ground there: open, or dug from that end (a hub is
	drawn where three or more have; bore_view.gd)."""
	var n := 0
	for k in DEGREE:
		var s := node_seg[node * DEGREE + k]
		if s >= 0 and (is_open(s) or (node_a[s] == node and done(s) > 0)):
			n += 1
	return n


func other_end(slot: int, node: int) -> int:
	"""The node at a segment's other end from `node`."""
	return node_b[slot] if node_a[slot] == node else node_a[slot]


func end_node(slot: int, at_b: bool) -> int:
	"""A segment's node A, or node B when `at_b`."""
	return node_b[slot] if at_b else node_a[slot]


func end_at(slot: int, at_b: bool) -> Vector2:
	"""Where a segment's node A (or B) stands, in metres."""
	return node_m(end_node(slot, at_b))


func leaving_dir(slot: int, node: int) -> Vector2i:
	"""The direction (u, any length) a segment leaves `node` in: along its first leg from that end."""
	var base := 2 * slot * Rules.MAX_POINTS
	var last := 2 * (slot * Rules.MAX_POINTS + point_count[slot] - 1)
	if node_a[slot] == node:
		return Vector2i(points_u[base + 2] - points_u[base], points_u[base + 3] - points_u[base + 1])
	return Vector2i(points_u[last - 2] - points_u[last], points_u[last - 1] - points_u[last + 1])


func _new_node(kind: int, at: Vector2i, level: int) -> int:
	"""Take a free node row for a node of `kind` at `at` on `level`."""
	var node := node_kind.find(NODE_FREE)
	node_kind[node] = kind
	node_level[node] = level
	node_x_u[node] = at.x
	node_z_u[node] = at.y
	for k in DEGREE:
		node_seg[node * DEGREE + k] = -1
	if kind == NODE_MOUTH:
		_new_mouth(node)
	return node


func _free_node(node: int) -> void:
	"""Free a node with nothing left at it (and its mouth row); retire both generations."""
	if node_mouth[node] >= 0:
		var m := node_mouth[node]
		mouth_node[m] = -1
		mouth_gen[m] += 1
		heap_radius_m[m] = 0.0
		mouth_spoil[m] = 0
		node_mouth[node] = -1
	node_kind[node] = NODE_FREE
	node_room[node] = -1
	node_gen[node] += 1


func _attach(node: int, slot: int) -> void:
	"""Record segment `slot` at `node`."""
	for k in DEGREE:
		if node_seg[node * DEGREE + k] < 0:
			node_seg[node * DEGREE + k] = slot
			return


func _detach(node: int, slot: int) -> void:
	"""Forget segment `slot` at `node`; a node left with nothing is freed."""
	for k in DEGREE:
		if node_seg[node * DEGREE + k] == slot:
			node_seg[node * DEGREE + k] = -1
	if degree(node) == 0:
		_free_node(node)


# --- mouths ---------------------------------------------------------------------------------

func _new_mouth(node: int) -> void:
	"""Give a new mouth node its row: no heap placed, no spoil."""
	var m := mouth_node.find(-1)
	mouth_node[m] = node
	node_mouth[node] = m
	mouth_kind[m] = MOUTH_TUNNEL
	heap_radius_m[m] = 0.0
	heap_at[m] = Vector2.ZERO
	heap_dir[m] = Vector2.ZERO
	mouth_spoil[m] = 0


func is_mouth(m: int) -> bool:
	"""Whether mouth row `m` holds a mouth."""
	return m >= 0 and m < Rules.MAX_MOUTHS and mouth_node[m] >= 0


func mouth_at(m: int) -> Vector2:
	"""Where mouth `m` opens, in metres."""
	return node_m(mouth_node[m])


func mouth_ramp(m: int) -> int:
	"""The ramp segment down from mouth `m`."""
	return node_seg[mouth_node[m] * DEGREE]


func mouth_usable(m: int) -> bool:
	"""Whether mouth `m`'s ramp is open and not closed: a way in and out."""
	return is_mouth(m) and is_usable(mouth_ramp(m))


func mouth_opened(m: int) -> bool:
	"""Whether mouth `m`'s hole has been broken: its ramp started from it, or broken out at it."""
	var ramp := mouth_ramp(m)
	return is_open(ramp) or (node_a[ramp] == mouth_node[m] and done(ramp) > 0)


func mouth_inward(m: int) -> Vector2:
	"""The unit direction down mouth `m`'s ramp, from the hole (x, z)."""
	var dir := leaving_dir(mouth_ramp(m), mouth_node[m])
	return Vector2(dir.x, dir.y).normalized()


func mouth_of_end(slot: int, at_b: bool) -> int:
	"""The mouth row at a segment's node A (or B), or -1 when that end is underground."""
	return node_mouth[end_node(slot, at_b)]


func leg_start_node(code: int) -> int:
	"""The node a leg code (tunnel_router.gd LEG CODES) walks its segment from."""
	var slot := code >> 1
	return node_b[slot] if code & 1 == 1 else node_a[slot]


func leg_end_node(code: int) -> int:
	"""The node a leg code walks its segment to."""
	var slot := code >> 1
	return node_a[slot] if code & 1 == 1 else node_b[slot]


func entry_mouth_of(code: int) -> int:
	"""The mouth row a leg code's walk goes in at (-1: it starts underground)."""
	return node_mouth[leg_start_node(code)]


func set_heap(m: int, at: Vector2, radius: float, outward: Vector2) -> void:
	"""Where mouth `m`'s heap stands, its finished radius and the side it lies on (tunnel_heaps.gd)."""
	heap_at[m] = at
	heap_radius_m[m] = radius
	heap_dir[m] = outward


func mouth_circles_into(out: PackedVector3Array, first: int) -> int:
	"""Write every mouth as a circle (x, rim radius, z) into `out` from index `first` (`out` has room for
	MAX_MOUTHS more); returns how many."""
	var count := 0
	var rim := Rules.HOLE_RADIUS_M * Rules.RIM_FACTOR
	for m in Rules.MAX_MOUTHS:
		if mouth_node[m] >= 0:
			var at := mouth_at(m)
			out[first + count] = Vector3(at.x, rim, at.y)
			count += 1
	return count


func mouth_occupied(m: int, body: float, standing: PackedVector3Array, residents: int) -> bool:
	"""Whether a resident stands on mouth `m`: closer than their radius plus the walker's `body` plus the
	planning margin (the first `residents` circles of `standing`)."""
	var at := mouth_at(m)
	for s in residents:
		var reach := standing[s].y + body + CastNavScript.PLAN_MARGIN_M
		if Vector2(standing[s].x, standing[s].z).distance_squared_to(at) < reach * reach:
			return true
	return false


# --- pieces ---------------------------------------------------------------------------------

func room_for(spec: SpecScript) -> bool:
	"""Whether the network has the rows a piece needs: its mouths, their ramps' feet, a junction and a
	split per end on a segment and per crossing, and its segments."""
	var mouths := (1 if spec.starts_at_mouth() else 0) + (1 if spec.ends_at_mouth() else 0)
	var on_route := (1 if spec.start_kind == SpecScript.END_ON_SEGMENT else 0) \
			+ (1 if spec.end_kind == SpecScript.END_ON_SEGMENT else 0)
	var crossings := spec.crossing_count()
	var nodes := 2 * mouths + on_route + crossings
	var segments := 1 + mouths + 2 * crossings + on_route
	return node_kind.count(NODE_FREE) >= nodes and phase.count(PHASE_FREE) >= segments \
			and mouth_node.count(-1) >= mouths and piece_live.count(0) >= 1


func add_piece(spec: SpecScript, out_ref: PackedInt32Array) -> bool:
	"""Store a piece the dig tool has checked (tunnel_plan.gd) as segments, all PLANNED for `spec.digger`
	(see PIECES), and write its first segment's (slot, generation) and the piece's row into
	out_ref[0..2]. False, nothing stored, when the network has no room (or the route has under two
	points)."""
	if spec.count < 2 or not room_for(spec):
		return false
	last_splits.clear()
	var start := _resolve_end(spec.start_kind, spec.start_ref, spec.point(0))
	var finish := _resolve_end(spec.end_kind, spec.end_ref, spec.point(spec.count - 1))
	var p := _new_piece(spec.digger)
	piece_mouth[p] = _spoil_mouth_from(start)
	_lay_chain(spec, start, finish)
	_lay_segments(spec, p)
	out_ref[0] = first_of_piece(p)
	out_ref[1] = generation[out_ref[0]]
	out_ref[2] = p
	revision += 1
	topology += 1
	return true


func add_into(route_u: PackedInt32Array, count: int, digger_index: int, out_ref: PackedInt32Array) -> bool:
	"""Store a route -- `count` (x, z) points in u, already validated -- as a piece from a new mouth to a
	new mouth, crossing nothing, for `digger_index` to dig now: its first segment DIGGING. Writes the first
	segment's (slot, generation) into out_ref[0..1] (and the piece into out_ref[2] when it has room).
	False (nothing stored) with no room, a point count out of 2..MAX_POINTS, or a length out of
	MIN_LENGTH_U..MAX_LENGTH_U or too short for its two ramps."""
	var run := Rules.route_length_u(route_u, count)
	if count < 2 or count > Rules.MAX_POINTS or run < 2 * Rules.RAMP_RUN_U or run > Rules.MAX_LENGTH_U:
		return false
	var spec := SpecScript.new()
	spec.set_route(route_u, count)
	spec.digger = digger_index
	var ref := PackedInt32Array([-1, 0, -1])
	if not add_piece(spec, ref):
		return false
	start_dig(ref[0], ref[1], digger_index)
	for k in mini(out_ref.size(), 3):
		out_ref[k] = ref[k]
	return true


func _resolve_end(kind: int, ref: int, at: Vector2i) -> int:
	"""The node a piece's end stands on: a new mouth, the given node, or a new junction splitting the given
	segment at `at`."""
	if kind == SpecScript.END_NODE:
		return ref
	if kind == SpecScript.END_ON_SEGMENT:
		return _split(ref, at)
	return _new_node(NODE_MOUTH, at, Rules.LEVEL_SURFACE)


func _new_piece(digger_index: int) -> int:
	"""Take a free piece row, last in the job list, for `digger_index`."""
	var p := piece_live.find(0)
	piece_live[p] = 1
	piece_digger[p] = digger_index
	piece_room[p] = -1
	piece_order[p] = _piece_count
	_piece_count += 1
	return p


func _spoil_mouth_from(start: int) -> int:
	"""A piece's spoil mouth: the mouth it opens at, else the network's mouth nearest its start through
	open segments, else the nearest OPENED mouth as the crow flies (never a planned piece's, whose row may be
	freed and reused if that piece is dropped); -1 with none, and its spoil is not heaped."""
	if node_mouth[start] >= 0:
		return node_mouth[start]
	var m := paths.nearest_mouth(self, start, PathsScript.CLASS_ANY)
	return m if m >= 0 else _nearest_mouth_flat(node_at(start))


func _nearest_mouth_flat(at: Vector2i) -> int:
	"""The opened mouth nearest a point in a straight line (-1: none)."""
	var best := -1
	var best_d := 0
	for m in Rules.MAX_MOUTHS:
		if mouth_node[m] < 0 or not mouth_opened(m):
			continue
		var d := node_at(mouth_node[m]) - at
		if best < 0 or d.x * d.x + d.y * d.y < best_d:
			best_d = d.x * d.x + d.y * d.y
			best = m
	return best


func _lay_chain(spec: SpecScript, start: int, finish: int) -> void:
	"""The piece's nodes in route order, with their distance along it (u): its start, its first ramp's
	foot, the junction of each crossing, its last ramp's foot and its end (two ramps that meet share a
	foot)."""
	var length := Rules.route_length_u(spec.points_u, spec.count)
	_chain_node.clear()
	_chain_along.clear()
	_chain_push(start, 0)
	if spec.starts_at_mouth():
		_chain_push(_new_node(NODE_RAMP_END, route_point_u(spec.points_u, spec.count, Rules.RAMP_RUN_U), Rules.BUILDABLE_LEVEL),
			Rules.RAMP_RUN_U)
	for c in spec.crossing_count():
		var at := Vector2i(spec.crossings[3 * c + 1], spec.crossings[3 * c + 2])
		_chain_push(_split(spec.crossings[3 * c], at), route_along_u(spec.points_u, spec.count, at))
	var foot := length - Rules.RAMP_RUN_U
	if spec.ends_at_mouth() and foot > _chain_along[_chain_along.size() - 1]:
		_chain_push(_new_node(NODE_RAMP_END, route_point_u(spec.points_u, spec.count, foot), Rules.BUILDABLE_LEVEL), foot)
	_chain_push(finish, length)


func _chain_push(node: int, along: int) -> void:
	"""Add one node to the piece's chain."""
	_chain_node.append(node)
	_chain_along.append(along)


func _lay_segments(spec: SpecScript, p: int) -> void:
	"""One PLANNED segment between each two nodes of the chain: a RAMP where either end is a mouth, else a
	BORE; ranked in dig order; spoiling at the piece's mouth."""
	for i in _chain_node.size() - 1:
		var a := _chain_node[i]
		var b := _chain_node[i + 1]
		var kind := SEG_RAMP if node_kind[a] == NODE_MOUTH or node_kind[b] == NODE_MOUTH else SEG_BORE
		var slot := _new_segment(kind, a, b, p, i)
		_write_route(slot, spec, _chain_along[i], _chain_along[i + 1])
		_store(slot, _chain_along[i + 1] - _chain_along[i])


func _new_segment(kind: int, a: int, b: int, p: int, rank: int) -> int:
	"""Take a free segment row from node `a` to node `b` for piece `p`, PLANNED, nothing dug."""
	var slot := phase.find(PHASE_FREE)
	seg_kind[slot] = kind
	seg_level[slot] = Rules.BUILDABLE_LEVEL
	node_a[slot] = a
	node_b[slot] = b
	piece[slot] = p
	piece_rank[slot] = rank
	spoil_mouth[slot] = piece_mouth[p] if p >= 0 else -1
	seg_room[slot] = piece_room[p] if p >= 0 else -1
	phase[slot] = PHASE_PLANNED
	digger[slot] = -1
	pause_reason[slot] = 0
	_attach(a, slot)
	_attach(b, slot)
	return slot


func _write_route(slot: int, spec: SpecScript, from_along: int, to_along: int) -> void:
	"""Segment `slot`'s polyline: its node A, the piece's route points strictly between `from_along` and
	`to_along`, its node B."""
	var points := PackedInt32Array()
	var a := node_at(node_a[slot])
	points.append_array([a.x, a.y])
	var run := 0
	for k in range(1, spec.count - 1):
		run += Rules.isqrt(Rules.leg_squared_u(spec.points_u, k))
		if run > from_along and run < to_along:
			points.append_array([spec.points_u[2 * k], spec.points_u[2 * k + 1]])
	var b := node_at(node_b[slot])
	points.append_array([b.x, b.y])
	_set_route(slot, points)


func _set_route(slot: int, route: PackedInt32Array) -> void:
	"""Write a flat (x, z) route as segment `slot`'s points and their distances from node A."""
	var count := route.size() / 2
	var base := slot * Rules.MAX_POINTS
	for k in count:
		points_u[2 * (base + k)] = route[2 * k]
		points_u[2 * (base + k) + 1] = route[2 * k + 1]
		cumulative_u[base + k] = Rules.route_length_u(route, k + 1)
	point_count[slot] = count


func _store(slot: int, span_u: int = -1) -> void:
	"""A segment's scalars from its route: length, cost, quanta and timeline, nothing dug, a standard
	unbraced unlit open bore. `span_u`, when given, is the stretch of the piece's route it was cut from: its
	quanta are counted on that, not on its polyline between nodes rounded to the lattice (a diagonal ramp's
	4096u run may lie 4097u between its rounded ends, which would cut a fifth metre)."""
	var route := points_u.slice(2 * slot * Rules.MAX_POINTS, 2 * (slot * Rules.MAX_POINTS + point_count[slot]))
	length_u[slot] = Rules.route_length_u(route, point_count[slot])
	cost_u[slot] = Rules.route_cost_u(route, point_count[slot])
	quanta[slot] = Rules.bore_quanta(span_u if span_u >= 0 else length_u[slot])
	dig_usec[slot] = 0
	dig_rem[slot] = 0
	rate_permille[slot] = Rules.PERMILLE
	extra_spoil[slot] = 0
	posted_in[slot] = 0
	posted_out[slot] = 0
	bore[slot] = Rules.BORE_STANDARD
	braced[slot] = 0
	lit[slot] = 0
	closed[slot] = CLOSED_NONE
	_lay_timeline(slot)


static func route_point_u(route_u: PackedInt32Array, count: int, along: int) -> Vector2i:
	"""The point `along` u into a flat (x, z) route (clamped), exact to a unit."""
	var run := 0
	for k in range(1, count):
		var leg := Rules.isqrt(Rules.leg_squared_u(route_u, k))
		if along <= run + leg or k == count - 1:
			var into := clampi(along - run, 0, leg)
			var ax := route_u[2 * k - 2]
			var az := route_u[2 * k - 1]
			return Vector2i(ax + (route_u[2 * k] - ax) * into / maxi(leg, 1), az + (route_u[2 * k + 1] - az) * into / maxi(leg, 1))
		run += leg
	return Vector2i(route_u[0], route_u[1])


static func route_along_u(route_u: PackedInt32Array, count: int, at: Vector2i) -> int:
	"""How far along a flat route (u) its closest point to `at` lies (on the nearest leg, by its floored
	length)."""
	var best_d := -1
	var best_along := 0
	var run := 0
	for k in range(1, count):
		var a := Vector2i(route_u[2 * k - 2], route_u[2 * k - 1])
		var b := Vector2i(route_u[2 * k], route_u[2 * k + 1])
		var leg := Rules.isqrt(Rules.leg_squared_u(route_u, k))
		var d := Rules.point_leg_u(at, a, b)
		if best_d < 0 or d < best_d:
			best_d = d
			var ab := b - a
			var ap := at - a
			best_along = run + clampi((ab.x * ap.x + ab.y * ap.y) / maxi(leg, 1), 0, leg)
		run += leg
	return best_along


# --- splitting a segment at a junction ------------------------------------------------------

func _split(host: int, at: Vector2i) -> int:
	"""Split open segment `host` -- or the half of it an earlier split in this piece made that holds `at` --
	at route point `at`: a new junction there, the first half keeping the slot and generation, the second
	in a new slot with the host's state. Logged in `last_splits`. Returns the junction."""
	var slot := _holder_of(host, at)
	var route := segment_route(slot)
	var along := route_along_u(route, point_count[slot], at)
	var j := _new_node(NODE_JUNCTION, at, seg_level[slot])
	var tail := phase.find(PHASE_FREE)
	_copy_state(slot, tail)
	_cut(slot, tail, route, along, at, j)
	last_splits.append_array([slot, tail, along])
	revision += 1
	topology += 1
	return j


func _holder_of(host: int, at: Vector2i) -> int:
	"""Of `host` and every half split off it already in this piece, the one whose route passes nearest
	`at`."""
	var best := host
	var best_d := _route_distance_u(host, at)
	for i in last_splits.size() / 3:
		var tail := last_splits[3 * i + 1]
		var d := _route_distance_u(tail, at)
		if d < best_d:
			best_d = d
			best = tail
	return best


func _route_distance_u(slot: int, at: Vector2i) -> int:
	"""How far `at` lies from segment `slot`'s polyline (u)."""
	var best := -1
	var base := 2 * slot * Rules.MAX_POINTS
	for k in range(1, point_count[slot]):
		var a := Vector2i(points_u[base + 2 * k - 2], points_u[base + 2 * k - 1])
		var b := Vector2i(points_u[base + 2 * k], points_u[base + 2 * k + 1])
		var d := Rules.point_leg_u(at, a, b)
		best = d if best < 0 else mini(best, d)
	return best


func segment_route(slot: int) -> PackedInt32Array:
	"""A copy of segment `slot`'s polyline as a flat (x, z) route in u."""
	return points_u.slice(2 * slot * Rules.MAX_POINTS, 2 * (slot * Rules.MAX_POINTS + point_count[slot]))


func _copy_state(from: int, to: int) -> void:
	"""Give a new segment row the state of the segment it is split from: kind, level, piece, spoil mouth,
	bore class, bracing, light and phase."""
	for column: PackedByteArray in [seg_kind, seg_level, bore, braced, lit, phase, closed]:
		column[to] = column[from]
	piece[to] = piece[from]
	piece_rank[to] = piece_rank[from]
	spoil_mouth[to] = spoil_mouth[from]
	seg_room[to] = seg_room[from]
	digger[to] = -1
	pause_reason[to] = 0
	rate_permille[to] = Rules.PERMILLE
	for column: PackedInt64Array in [dig_usec, dig_rem, extra_spoil, posted_in, posted_out]:
		column[to] = 0


func _cut(slot: int, tail: int, route: PackedInt32Array, along: int, at: Vector2i, j: int) -> void:
	"""Cut `route` (segment `slot`'s) at `along`: its points up to there and `at` stay with `slot`, `at` and
	its points beyond go to `tail`; junction `j` joins them where node B was."""
	var head := PackedInt32Array()
	var rest := PackedInt32Array([at.x, at.y])
	var count := route.size() / 2
	for k in count:
		var point := Vector2i(route[2 * k], route[2 * k + 1])
		if point == at:
			continue
		if Rules.route_length_u(route, k + 1) < along:
			head.append_array([point.x, point.y])
		else:
			rest.append_array([point.x, point.y])
	head.append_array([at.x, at.y])
	var far := node_b[slot]
	_detach_only(far, slot)
	node_b[slot] = j
	node_a[tail] = j
	node_b[tail] = far
	_attach(j, slot)
	_attach(j, tail)
	_attach(far, tail)
	_set_route(slot, head)
	_set_route(tail, rest)
	_restore_open(slot)
	_restore_open(tail)


func _detach_only(node: int, slot: int) -> void:
	"""Forget segment `slot` at `node`, keeping the node (another takes its place at once)."""
	for k in DEGREE:
		if node_seg[node * DEGREE + k] == slot:
			node_seg[node * DEGREE + k] = -1


func _restore_open(slot: int) -> void:
	"""A half of a split open segment: its length, cost, quanta and timeline from its new route, all dug."""
	var route := segment_route(slot)
	length_u[slot] = Rules.route_length_u(route, point_count[slot])
	cost_u[slot] = Rules.route_cost_u(route, point_count[slot])
	quanta[slot] = Rules.bore_quanta(length_u[slot])
	_lay_timeline(slot)
	dig_usec[slot] = (total_ticks(slot) * Rules.USEC_PER_SECOND + Rules.TICKS_PER_SECOND - 1) / Rules.TICKS_PER_SECOND


# --- the job list ---------------------------------------------------------------------------

func is_piece(p: int, gen: int) -> bool:
	"""Whether (p, gen) names a piece still laid."""
	return p >= 0 and p < Rules.MAX_PIECES and piece_live[p] == 1 and piece_gen[p] == gen


func piece_segments_into(p: int, out: PackedInt32Array) -> void:
	"""Piece `p`'s segments in dig order into `out`: from its first, each next the one that starts where
	the last ends (a split-off half of a segment follows the half it was cut from)."""
	out.clear()
	var slot := first_of_piece(p)
	while slot >= 0 and out.size() < Rules.MAX_SEGMENTS:
		out.append(slot)
		slot = next_in_piece(slot)


func first_of_piece(p: int) -> int:
	"""Piece `p`'s first segment (rank 0)."""
	for slot in Rules.MAX_SEGMENTS:
		if phase[slot] != PHASE_FREE and piece[slot] == p and piece_rank[slot] == 0 and _previous_in_piece(slot) < 0:
			return slot
	return -1


func _previous_in_piece(slot: int) -> int:
	"""The segment of the same piece that ends where `slot` starts (-1: none). A split-off half copies its
	host's rank, so rank 0 alone does not make a segment its piece's first."""
	var p := piece[slot]
	for other in Rules.MAX_SEGMENTS:
		if other != slot and phase[other] != PHASE_FREE and piece[other] == p and node_b[other] == node_a[slot]:
			return other
	return -1


func next_in_piece(slot: int) -> int:
	"""The segment of the same piece that starts where `slot` ends (-1: `slot` is the last)."""
	var p := piece[slot]
	for other in Rules.MAX_SEGMENTS:
		if other != slot and phase[other] != PHASE_FREE and piece[other] == p and node_a[other] == node_b[slot]:
			return other
	return -1


func piece_done(p: int) -> bool:
	"""Whether every segment of piece `p` is open."""
	for slot in Rules.MAX_SEGMENTS:
		if phase[slot] != PHASE_FREE and piece[slot] == p and not is_open(slot):
			return false
	return true


func piece_ticks_into(p: int, out: PackedInt32Array) -> void:
	"""Piece `p`'s ticks dug (out[0]) and its total (out[1]), over all its segments."""
	out[0] = 0
	out[1] = 0
	for slot in Rules.MAX_SEGMENTS:
		if phase[slot] != PHASE_FREE and piece[slot] == p and not is_room_walk(slot):
			out[0] += done(slot)
			out[1] += total_ticks(slot)


func piece_percent(p: int) -> int:
	"""Whole percent of piece `p` dug (floored, so 100 only when all of it is open)."""
	var ticks := PackedInt32Array([0, 0])
	piece_ticks_into(p, ticks)
	return ticks[0] * 100 / maxi(ticks[1], 1)


func job_list_into(out: PackedInt32Array) -> void:
	"""Every piece with work left, in the order laid (THE JOB LIST)."""
	out.clear()
	for p in Rules.MAX_PIECES:
		if piece_live[p] == 1 and not piece_done(p):
			var k := out.size()
			out.append(p)
			while k > 0 and piece_order[out[k - 1]] > piece_order[p]:
				out[k] = out[k - 1]
				k -= 1
			out[k] = p


func next_dig_for(digger_index: int) -> int:
	"""The first unfinished segment of the first piece in the job list `digger_index` digs (-1: none)."""
	var list := PackedInt32Array()
	job_list_into(list)
	for p in list:
		if piece_digger[p] != digger_index:
			continue
		var chain := PackedInt32Array()
		piece_segments_into(p, chain)
		for slot in chain:
			if not is_open(slot):
				return slot
	return -1


func _drop_piece(p: int) -> void:
	"""A piece dropped before any of its ground was broken: free its segments and the nodes they leave
	empty, and retire its row."""
	for slot in Rules.MAX_SEGMENTS:
		if phase[slot] == PHASE_FREE or piece[slot] != p or is_open(slot):
			continue
		phase[slot] = PHASE_FREE
		generation[slot] += 1
		digger[slot] = -1
		var a := node_a[slot]
		var b := node_b[slot]
		_detach(a, slot)
		if b != a:
			_detach(b, slot)
	if piece_room[p] >= 0:
		_forget_room(piece_room[p])
	piece_live[p] = 0
	piece_gen[p] += 1
	piece_digger[p] = -1
	piece_room[p] = -1
	revision += 1
	topology += 1


# --- rooms (decision 0209) -----------------------------------------------------------------

func has_rows_for_room(sockets: int) -> bool:
	"""Whether the network has the rows a room with `sockets` sockets takes (see ROOMS): its mouth, door, middle
	and socket nodes, its ramp, body and walks, a mouth row and a piece."""
	return node_kind.count(NODE_FREE) >= 3 + sockets and phase.count(PHASE_FREE) >= 2 + sockets \
			and mouth_node.count(-1) >= 1 and piece_live.count(0) >= 1


func add_room(kind: int, at: Vector2i, quarter_turns: int, digger_index: int, out_ref: PackedInt32Array) -> bool:
	"""Lay a room of template `kind` (underground_rooms.gd) centred at `at`, turned so, on the buildable level,
	for `digger_index` to dig -- already checked by `rooms.refusal` -- as one PLANNED piece (see ROOMS). Writes
	(room row, its generation, the piece, the ramp's slot, its generation) into out_ref[0..4]. False, nothing
	stored, when the rooms or the network have no rows for it."""
	if kind == RoomsScript.TEMPLATE_NONE or not rooms.has_free_row() \
			or not has_rows_for_room(RoomsScript.socket_count(kind)):
		return false
	last_splits.clear()
	var r := rooms.take(kind, at, quarter_turns, Rules.BUILDABLE_LEVEL)
	var p := _new_piece(digger_index)
	piece_room[p] = r
	rooms.piece[r] = p
	_room_nodes(r, kind)
	piece_mouth[p] = rooms.mouth[r]
	_room_segments(r, p)
	out_ref[0] = r
	out_ref[1] = rooms.generation[r]
	out_ref[2] = p
	out_ref[3] = rooms.ramp[r]
	out_ref[4] = generation[rooms.ramp[r]]
	revision += 1
	topology += 1
	return true


func _room_nodes(r: int, kind: int) -> void:
	"""Room `r`'s nodes: its mouth (a door or a hatch) on the surface, its door's foot, its middle and its
	sockets, on its level."""
	var hole := _new_node(NODE_MOUTH, rooms.mouth_u(r), Rules.LEVEL_SURFACE)
	node_room[hole] = r
	rooms.mouth[r] = node_mouth[hole]
	mouth_kind[node_mouth[hole]] = MOUTH_DOOR if kind == RoomsScript.TEMPLATE_HOME else MOUTH_HATCH
	rooms.door[r] = _room_node(r, NODE_DOOR, rooms.door_u(r))
	rooms.middle[r] = _room_node(r, NODE_ROOM, rooms.centre(r))
	for k in RoomsScript.socket_count(kind):
		rooms.socket_node[r * RoomsScript.MAX_SOCKETS + k] = _room_node(r, NODE_SOCKET, rooms.socket_u(r, k))


func _room_node(r: int, kind: int, at: Vector2i) -> int:
	"""A node of `kind` at `at` belonging to room `r`, on its level."""
	var node := _new_node(kind, at, rooms.level[r])
	node_room[node] = r
	return node


func _room_segments(r: int, p: int) -> void:
	"""Room `r`'s segments in piece `p`: its ramp (a wide bore; rank 0), its body (rank 1; the room's own
	quanta, cell by cell) and a walk from its middle to each socket (rank 2)."""
	rooms.ramp[r] = _room_segment(SEG_RAMP, mouth_node[rooms.mouth[r]], rooms.door[r], p, 0, Rules.BORE_WIDE)
	var body: int = _room_segment(SEG_ROOM, rooms.door[r], rooms.middle[r], p, 1, Rules.BORE_ROOM)
	rooms.body[r] = body
	quanta[body] = RoomsScript.total_quanta(rooms.template[r])
	_lay_timeline(body)
	for k in RoomsScript.socket_count(rooms.template[r]):
		rooms.walk[r * RoomsScript.MAX_SOCKETS + k] = _room_segment(SEG_ROOM, rooms.middle[r], rooms.socket_of(r, k), p, 2,
			Rules.BORE_ROOM)


func _room_segment(kind: int, a: int, b: int, p: int, rank: int, bore_class: int) -> int:
	"""A straight PLANNED segment of `kind` from node `a` to node `b` in piece `p`, of `bore_class`."""
	var slot := _new_segment(kind, a, b, p, rank)
	_set_route(slot, PackedInt32Array([node_x_u[a], node_z_u[a], node_x_u[b], node_z_u[b]]))
	_store(slot)
	bore[slot] = bore_class
	return slot


func _open_walks(r: int) -> void:
	"""Room `r`'s body is dug: its walks to its sockets open with it (they are the room's own floor)."""
	for k in RoomsScript.socket_count(rooms.template[r]):
		var w := rooms.walk_of(r, k)
		dig_usec[w] = (total_ticks(w) * Rules.USEC_PER_SECOND + Rules.TICKS_PER_SECOND - 1) / Rules.TICKS_PER_SECOND
		_set_phase(w, PHASE_OPEN, -1)
	rooms.revision += 1


func _forget_room(r: int) -> void:
	"""Room `r`'s piece was dropped (no ground broken): a socket a passage still reaches stays as a plain
	junction, and the room's row is freed."""
	for k in RoomsScript.socket_count(rooms.template[r]):
		var node := rooms.socket_of(r, k)
		if is_node(node):
			node_kind[node] = NODE_JUNCTION
			node_room[node] = -1
	rooms.release(r)


func is_room_body(slot: int) -> bool:
	"""Whether segment `slot` is a room's body (its dig is the room's own quanta)."""
	return seg_room[slot] >= 0 and rooms.body[seg_room[slot]] == slot


func is_room_walk(slot: int) -> bool:
	"""Whether segment `slot` is a walk inside a room to a socket (opened with its body, never dug)."""
	return seg_kind[slot] == SEG_ROOM and not is_room_body(slot)


func is_tunnel(slot: int) -> bool:
	"""Whether segment `slot` is a tunnel's (laid, and no room's ramp, body or walk)."""
	return phase[slot] != PHASE_FREE and seg_room[slot] < 0


func is_free_socket(node: int) -> bool:
	"""Whether `node` is a room's socket no passage has joined yet (its walk its only segment)."""
	return is_node(node) and node_kind[node] == NODE_SOCKET and degree(node) == 1


func route_box(slot: int) -> Rect2i:
	"""Segment `slot`'s route's bounding box (u; one unit larger, so a straight route has an area)."""
	var base := 2 * slot * Rules.MAX_POINTS
	var box := Rect2i(Vector2i(points_u[base], points_u[base + 1]), Vector2i.ONE)
	for k in range(1, point_count[slot]):
		box = box.expand(Vector2i(points_u[base + 2 * k], points_u[base + 2 * k + 1]))
	return box.grow(1)


# --- the dig timeline -----------------------------------------------------------------------

func entry_shafts(slot: int) -> int:
	"""Shaft quanta dug at a segment's start: one where it starts at a mouth, else none."""
	return Rules.SHAFT_QUANTA if node_kind[node_a[slot]] == NODE_MOUTH else 0


func exit_shafts(slot: int) -> int:
	"""Shaft quanta dug where a segment breaks out at a mouth, else none."""
	return Rules.SHAFT_QUANTA if node_kind[node_b[slot]] == NODE_MOUTH else 0


func _lay_timeline(slot: int) -> void:
	"""Each quantum's ground and end tick (see THE DIG TIMELINE)."""
	var run := 0
	for k in timeline_count(slot):
		var at := quantum_point_u(slot, k)
		var kind := ground.type_at(at.x, at.y) if ground != null else GroundScript.LOAM
		_q_kind[slot * MAX_TIMELINE + k] = kind
		run += GroundScript.dig_ticks(kind)
		_q_end[slot * MAX_TIMELINE + k] = run


func timeline_count(slot: int) -> int:
	"""How many quanta a segment's timeline has: its shafts and its bore."""
	return quanta[slot] + entry_shafts(slot) + exit_shafts(slot)


func quantum_kind(slot: int, k: int) -> int:
	"""The ground (tunnel_ground.gd type) quantum `k` of the timeline is dug through."""
	return _q_kind[slot * MAX_TIMELINE + k]


func quantum_along_u(slot: int, k: int) -> int:
	"""Where along the segment quantum `k` of its timeline lies, in u: 0 for an entry shaft, the length
	for an exit shaft, and the middle of its metre for a bore quantum."""
	var entry := entry_shafts(slot)
	if k < entry:
		return 0
	if k >= entry + quanta[slot]:
		return length_u[slot]
	var j := k - entry
	return (2 * j + 1) * length_u[slot] / (2 * quanta[slot])


func quantum_point_u(slot: int, k: int) -> Vector2i:
	"""Where quantum `k` of the timeline lies, (x, z) in u: along the route -- or, a room's body, in the room's
	floor cell it cuts (see ROOMS)."""
	if is_room_body(slot):
		return rooms.cell_point_u(seg_room[slot], k)
	return point_at_u(slot, quantum_along_u(slot, k))


func _bore_end_tick(slot: int) -> int:
	"""The tick the bore (and any entry shaft) is dug through: the last tick before an exit shaft."""
	var k := entry_shafts(slot) + quanta[slot] - 1
	return _q_end[slot * MAX_TIMELINE + k]


func _entry_end_tick(slot: int) -> int:
	"""The tick an entry shaft is dug through (0 with none)."""
	return _q_end[slot * MAX_TIMELINE] if entry_shafts(slot) > 0 else 0


func total_ticks(slot: int) -> int:
	"""Ticks one F1000 worker needs to dig the whole segment through its ground."""
	return _q_end[slot * MAX_TIMELINE + timeline_count(slot) - 1]


func done(slot: int) -> int:
	"""Fixed ticks dug so far (F1000-equivalent), capped at the total; an open segment is all dug."""
	if phase[slot] == PHASE_OPEN:
		return total_ticks(slot)
	return mini(total_ticks(slot), dig_usec[slot] * Rules.TICKS_PER_SECOND / Rules.USEC_PER_SECOND)


func stage(slot: int) -> int:
	"""Rules.STAGE_*: which part is being dug, or STAGE_OPEN."""
	var d := done(slot)
	if d >= total_ticks(slot):
		return Rules.STAGE_OPEN
	if d < _entry_end_tick(slot):
		return Rules.STAGE_ENTRANCE
	if d < _bore_end_tick(slot):
		return Rules.STAGE_BORE
	return Rules.STAGE_EXIT


func percent(slot: int) -> int:
	"""Whole percent of the segment dug (floored, so 100 only when it is open)."""
	return done(slot) * 100 / total_ticks(slot)


func progress_into(slot: int, ticks: int, repeat: int, out: PackedInt64Array) -> void:
	"""After `ticks` of work on a pass that digs every timeline quantum `repeat` times over (1: the dig;
	Rules.WIDE_EXTRA_QUANTA: a widening), write into `out` (P_SIZE slots): cuts completed, spoil and stone
	posted (milli-U), the timeline quantum under way and the ticks into its current repeat. A quantum's
	cut completes tunnel_ground.cut_ticks into it; its ground sets its spoil."""
	out.fill(0)
	var start := 0
	for k in timeline_count(slot):
		var kind := _q_kind[slot * MAX_TIMELINE + k]
		var each := GroundScript.dig_ticks(kind)
		var into := ticks - start
		var whole := clampi(into / each, 0, repeat) if into > 0 else 0
		var cuts := whole + (1 if whole < repeat and into > 0 and into % each >= GroundScript.cut_ticks(kind) else 0)
		out[P_CUTS] += cuts
		out[P_SPOIL] += cuts * GroundScript.spoil_of(kind)
		out[P_STONE] += cuts * GroundScript.stone_of(kind)
		out[P_QUANTUM] = k
		out[P_INTO] = clampi(into - whole * each, 0, each)
		if into < each * repeat:
			return
		start += each * repeat


func pass_ticks(slot: int, repeat: int) -> int:
	"""Ticks a pass digging every timeline quantum `repeat` times takes one F1000 worker."""
	return total_ticks(slot) * repeat


func stone_milli_u(slot: int) -> int:
	"""Stone the dig has yielded so far (rock quanta cut), milli-U."""
	progress_into(slot, done(slot), 1, _progress)
	return _progress[P_STONE]


func cut_count(slot: int) -> int:
	"""How many of the dig's quanta have been cut so far."""
	progress_into(slot, done(slot), 1, _progress)
	return _progress[P_CUTS]


func face_quantum(slot: int) -> int:
	"""The timeline quantum the dig is working (the last once it is open)."""
	progress_into(slot, done(slot), 1, _progress)
	return _progress[P_QUANTUM]


func face_u(slot: int) -> int:
	"""How far along the segment the dig face has reached, in u: 0 through an entry shaft, the whole length
	from an exit shaft on, and through the bore by whole quanta and the share dug of the one under way
	(exactly the uniform rule when every quantum is loam)."""
	var q := quanta[slot]
	var d := done(slot)
	if d <= _entry_end_tick(slot):
		return 0
	if d >= _bore_end_tick(slot):
		return length_u[slot]
	progress_into(slot, d, 1, _progress)
	var j := int(_progress[P_QUANTUM]) - entry_shafts(slot)
	var each := GroundScript.dig_ticks(_q_kind[slot * MAX_TIMELINE + _progress[P_QUANTUM]])
	return (j * each + int(_progress[P_INTO])) * length_u[slot] / (q * each)


func face_m(slot: int) -> float:
	"""How far along the segment the dig face is, in metres (presentation)."""
	return Rules.to_m(face_u(slot))


# --- life -----------------------------------------------------------------------------------

func _set_phase(slot: int, to: int, digger_index: int) -> void:
	"""Change a segment's phase and digger, and note the change (a pause reason lasts only while paused)."""
	phase[slot] = to
	digger[slot] = digger_index
	if to != PHASE_PAUSED:
		pause_reason[slot] = 0
	revision += 1


func start_dig(slot: int, gen: int, digger_index: int) -> bool:
	"""Put a PLANNED or PAUSED segment to DIGGING under `digger_index`, who takes up its piece. False when
	it is neither."""
	if not is_ref(slot, gen) or (phase[slot] != PHASE_PLANNED and phase[slot] != PHASE_PAUSED):
		return false
	_set_phase(slot, PHASE_DIGGING, digger_index)
	piece_digger[piece[slot]] = digger_index
	return true


func resume(slot: int, gen: int, digger_index: int) -> bool:
	"""Put a PAUSED segment back to DIGGING under `digger_index`. False when it is not paused."""
	return is_ref(slot, gen) and phase[slot] == PHASE_PAUSED and start_dig(slot, gen, digger_index)


func set_rate(slot: int, permille: int) -> void:
	"""The crew's digging rate on a segment, per mille of one F1000 worker's (tunnel_crew.gd)."""
	rate_permille[slot] = maxi(permille, 0)


func advance(slot: int, gen: int, usec: int) -> void:
	"""Credit `usec` microseconds of digging, scaled by the segment's rate, to a DIGGING segment (others are
	left alone); its new cuts' spoil is posted, and it opens when the last tick is dug."""
	if not is_ref(slot, gen) or phase[slot] != PHASE_DIGGING or usec <= 0:
		return
	var work := usec * rate_permille[slot] + dig_rem[slot]
	dig_usec[slot] += work / Rules.PERMILLE
	dig_rem[slot] = work % Rules.PERMILLE
	_post_spoil(slot)
	if done(slot) >= total_ticks(slot):
		_set_phase(slot, PHASE_OPEN, -1)
		if is_room_body(slot):
			_open_walks(seg_room[slot])


func _post_spoil(slot: int) -> void:
	"""Post a segment's new cuts to their mouths: its entry shaft and bore at its spoil mouth, a shaft
	breaking out at the mouth it breaks out at (see SPOIL)."""
	var d := done(slot)
	progress_into(slot, mini(d, _bore_end_tick(slot)), 1, _progress)
	var inward := _progress[P_SPOIL]
	if spoil_mouth[slot] >= 0:
		mouth_spoil[spoil_mouth[slot]] += inward - posted_in[slot]
	posted_in[slot] = inward
	if exit_shafts(slot) == 0:
		return
	progress_into(slot, d, 1, _progress)
	var outward := _progress[P_SPOIL] - inward
	mouth_spoil[mouth_of_end(slot, true)] += outward - posted_out[slot]
	posted_out[slot] = outward


func stop_digging(slot: int, gen: int) -> void:
	"""The digger was called away: keep the segment PAUSED with its progress -- or, when not one tick of its
	whole piece was dug, drop the piece (see LIFE). An open segment of the piece -- a split-off half too --
	counts all its ticks as dug."""
	if not is_ref(slot, gen) or phase[slot] != PHASE_DIGGING:
		return
	var ticks := PackedInt32Array([0, 0])
	piece_ticks_into(piece[slot], ticks)
	if ticks[0] > 0:
		_set_phase(slot, PHASE_PAUSED, -1)
		pause_reason[slot] = PAUSED_CALLED_AWAY
		return
	_drop_piece(piece[slot])


func hold_unreached(slot: int, gen: int) -> void:
	"""The digger could not reach the segment's start: keep it PAUSED as it stands (at 0% if nothing was
	dug), to be resumed, rather than dropping the player's route (see LIFE)."""
	if not is_ref(slot, gen) or phase[slot] != PHASE_DIGGING:
		return
	_set_phase(slot, PHASE_PAUSED, -1)
	pause_reason[slot] = PAUSED_UNREACHED


# --- spoil and heaps ------------------------------------------------------------------------

func heaped_milli(m: int) -> int:
	"""All the spoil mouth `m`'s heap has received, milli-U (0 for no mouth)."""
	return mouth_spoil[m] if is_mouth(m) else 0


func add_spoil(slot: int, milli_u: int) -> void:
	"""Spoil from re-digging segment `slot`, heaped at its spoil mouth."""
	extra_spoil[slot] += milli_u
	if spoil_mouth[slot] >= 0:
		mouth_spoil[spoil_mouth[slot]] += milli_u


func mouth_growing(m: int) -> bool:
	"""Whether mouth `m`'s heap is still to grow: a segment spoiling there is not yet dug."""
	for slot in Rules.MAX_SEGMENTS:
		if is_unfinished(slot) and (spoil_mouth[slot] == m or (exit_shafts(slot) > 0 and mouth_of_end(slot, true) == m)):
			return true
	return false


func finished_spoil(m: int, extra_milli_u: int = 0) -> int:
	"""The spoil mouth `m` will have heaped once every unfinished segment spoiling there is dug, plus
	`extra_milli_u` still to come (a widening accepted): what its heap is sized for (tunnel_heaps.gd)."""
	var total := heaped_milli(m) + extra_milli_u
	for slot in Rules.MAX_SEGMENTS:
		if not is_unfinished(slot):
			continue
		if spoil_mouth[slot] == m:
			progress_into(slot, _bore_end_tick(slot), 1, _progress)
			total += _progress[P_SPOIL] - posted_in[slot]
		if exit_shafts(slot) > 0 and mouth_of_end(slot, true) == m:
			progress_into(slot, total_ticks(slot), 1, _progress)
			var whole := _progress[P_SPOIL]
			progress_into(slot, _bore_end_tick(slot), 1, _progress)
			total += whole - _progress[P_SPOIL] - posted_out[slot]
	return total


# --- upgrades and hazards -------------------------------------------------------------------

func set_bore(slot: int, value: int) -> void:
	"""A segment's bore class from now on (Rules.BORE_*)."""
	bore[slot] = value
	revision += 1


func set_braced(slot: int) -> void:
	"""Timber support is installed along the whole segment."""
	braced[slot] = 1
	revision += 1


func set_lit(slot: int) -> void:
	"""Lanterns hang along the whole segment."""
	lit[slot] = 1
	revision += 1


func close(slot: int, reason: int, from_u: int, to_u: int) -> void:
	"""A hazard closes the segment (CLOSED_*): nobody is routed through it until it is reopened. A collapse
	closes the stretch from_u..to_u along it."""
	closed[slot] = reason
	closed_from_u[slot] = from_u
	closed_to_u[slot] = to_u
	revision += 1


func reopen(slot: int) -> void:
	"""The hazard is repaired: the segment is open to walkers again."""
	closed[slot] = CLOSED_NONE
	revision += 1


func speed_permille(slot: int) -> int:
	"""Walking speed in the bore, per mille of walk speed: faster when lit; weather never reaches it."""
	return LIT_SPEED_PERMILLE if lit[slot] == 1 else Rules.PERMILLE


# --- geometry (presentation) ----------------------------------------------------------------

func point_at_u(slot: int, along: int) -> Vector2i:
	"""The route point `along` u from node A (clamped), (x, z) in u, exact to a unit."""
	var base := slot * Rules.MAX_POINTS
	var a := clampi(along, 0, length_u[slot])
	var k := 1
	while k < point_count[slot] - 1 and a > cumulative_u[base + k]:
		k += 1
	var c0 := cumulative_u[base + k - 1]
	var span := maxi(cumulative_u[base + k] - c0, 1)
	var i0 := 2 * (base + k - 1)
	var dx := points_u[i0 + 2] - points_u[i0]
	var dz := points_u[i0 + 3] - points_u[i0 + 1]
	return Vector2i(points_u[i0] + dx * (a - c0) / span, points_u[i0 + 1] + dz * (a - c0) / span)


func point(slot: int, k: int) -> Vector2:
	"""Route point `k` in metres (x, z)."""
	var i := 2 * (slot * Rules.MAX_POINTS + k)
	return Vector2(Rules.to_m(points_u[i]), Rules.to_m(points_u[i + 1]))


func length_m(slot: int) -> float:
	"""The segment's length in metres (presentation)."""
	return Rules.to_m(length_u[slot])


func cost_m(slot: int) -> float:
	"""What the segment costs a planner, in metres (legs rounded up)."""
	return Rules.to_m(cost_u[slot])


func _leg_at(slot: int, along_m: float) -> int:
	"""The route leg (1..count-1, ending at that point) holding distance `along_m`."""
	var base := slot * Rules.MAX_POINTS
	for k in range(1, point_count[slot]):
		if along_m <= Rules.to_m(cumulative_u[base + k]):
			return k
	return point_count[slot] - 1


func point_at(slot: int, along_m: float) -> Vector2:
	"""The route's point `along_m` metres from node A (clamped to the route)."""
	var k := _leg_at(slot, along_m)
	var c0 := Rules.to_m(cumulative_u[slot * Rules.MAX_POINTS + k - 1])
	var c1 := Rules.to_m(cumulative_u[slot * Rules.MAX_POINTS + k])
	var t := clampf((along_m - c0) / maxf(c1 - c0, 1e-6), 0.0, 1.0)
	return point(slot, k - 1).lerp(point(slot, k), t)


func direction_at(slot: int, along_m: float) -> Vector2:
	"""The unit direction of the route leg `along_m` metres from node A (A -> B)."""
	var k := _leg_at(slot, along_m)
	return (point(slot, k) - point(slot, k - 1)).normalized()


func along_of(slot: int, at: Vector2) -> float:
	"""How far along the route (m) its closest point to `at` lies."""
	var best := INF
	var best_along := 0.0
	var base := slot * Rules.MAX_POINTS
	for k in range(1, point_count[slot]):
		var a := point(slot, k - 1)
		var b := point(slot, k)
		var closest := Geometry2D.get_closest_point_to_segment(at, a, b)
		var d := closest.distance_to(at)
		if d < best:
			best = d
			best_along = Rules.to_m(cumulative_u[base + k - 1]) + a.distance_to(closest)
	return best_along


func distance_to_route(slot: int, at: Vector2) -> float:
	"""How far `at` lies from the segment's polyline, in metres."""
	return point_at(slot, along_of(slot, at)).distance_to(at)


func mouth_end_at_b(slot: int) -> bool:
	"""Whether a ramp's mouth is its node B (it was dug up out to the mouth), not node A."""
	return node_kind[node_b[slot]] == NODE_MOUTH


func floor_y_at(slot: int, along_m: float) -> float:
	"""The floor's height this far along a segment (m, negative underground): a ramp down from its mouth at
	up to 1:2.5 (tunnel_rules.ramp_depth_m), a bore level at its level's floor."""
	if seg_kind[slot] != SEG_RAMP:
		return -Rules.to_m(Rules.level_floor_depth_u(seg_level[slot]))
	var from_mouth := length_m(slot) - along_m if mouth_end_at_b(slot) else along_m
	return -Rules.ramp_depth_m(from_mouth)


func floor_grade_at(slot: int, along_m: float) -> float:
	"""How the floor's height changes per metre along a segment, A to B: negative going down a ramp from its
	mouth, positive coming up one to it, 0 on the level."""
	if seg_kind[slot] != SEG_RAMP:
		return 0.0
	if mouth_end_at_b(slot):
		return Rules.ramp_slope(length_m(slot) - along_m)
	return -Rules.ramp_slope(along_m)


# --- residents and planning -----------------------------------------------------------------

func set_fit(index: int, fits_bore: bool) -> void:
	"""Record whether resident `index` fits a standard bore, with no body described (setup only: the columns
	grow here)."""
	_grow_residents(index)
	resident_fit[index] = 1 if fits_bore else 0


func set_body(index: int, height_u: int, radius_u: int) -> void:
	"""Record resident `index`'s standing height and body radius in u (setup only): its fit to every bore
	class, loaded or not, is judged from them."""
	_grow_residents(index)
	body_height_u[index] = height_u
	body_radius_u[index] = radius_u
	resident_fit[index] = 1 if Rules.fits_bore(height_u, radius_u) else 0


func _grow_residents(index: int) -> void:
	"""Make room in the resident columns for `index`."""
	if resident_fit.size() > index:
		return
	resident_fit.resize(index + 1)
	body_height_u.resize(index + 1)
	body_radius_u.resize(index + 1)


func fits(index: int) -> bool:
	"""Whether resident `index` fits a standard bore (unknown residents do not)."""
	return index >= 0 and index < resident_fit.size() and resident_fit[index] == 1


func fit_class_refusal(index: int, bore_class: int, loaded: bool) -> int:
	"""Rules.FIT_*: how resident `index` (carrying, when `loaded`) fits a bore of `bore_class`. A body
	recorded only as yes/no fits exactly the standard bore, loaded or not; an unknown one is too wide."""
	if index < 0 or index >= resident_fit.size():
		return Rules.FIT_TOO_WIDE
	if body_height_u[index] <= 0:
		return Rules.FIT_OK if resident_fit[index] == 1 else Rules.FIT_TOO_WIDE
	var h := body_height_u[index]
	var width := Rules.loaded_width_u(h, body_radius_u[index]) if loaded else 2 * body_radius_u[index]
	return Rules.fit_refusal_in(h, width, bore_class)


func fit_refusal(index: int, slot: int, loaded: bool) -> int:
	"""Rules.FIT_*: how resident `index` (carrying, when `loaded`) fits segment `slot`'s bore."""
	return fit_class_refusal(index, bore[slot], loaded)


func fits_tunnel(index: int, slot: int, loaded: bool) -> bool:
	"""Whether resident `index` (carrying, when `loaded`) fits segment `slot`'s bore."""
	return fit_refusal(index, slot, loaded) == Rules.FIT_OK


func fits_any(index: int, loaded: bool) -> bool:
	"""Whether resident `index` fits any usable segment's bore."""
	for slot in Rules.MAX_SEGMENTS:
		if is_usable(slot) and fits_tunnel(index, slot, loaded):
			return true
	return false


func walker_class(walker: int, loaded: bool) -> int:
	"""Which segments a walker may be routed through (graph_paths.gd CLASS_*): every bore, only widened
	ones, or none. Walker -1 is anybody (every bore)."""
	if walker < 0:
		return PathsScript.CLASS_ANY
	if fit_class_refusal(walker, Rules.BORE_STANDARD, loaded) == Rules.FIT_OK:
		return PathsScript.CLASS_ANY
	if fit_class_refusal(walker, Rules.BORE_WIDE, loaded) == Rules.FIT_OK:
		return PathsScript.CLASS_WIDE
	return PathsScript.CLASS_NONE


func plan(nav: CastNavScript, from: Vector2, to: Vector2, body: float, standing: PackedVector3Array,
		standing_count: int, out: PackedVector2Array, legs: PackedInt32Array, walker: int = -1,
		loaded: bool = false, crossings: CrossingHookScript = null, use_tunnels: bool = true,
		goal_node: int = -1) -> bool:
	"""Plan from -> to through the network's usable segments walker `walker` fits (carrying, when
	`loaded`; every one when -1; none unless `use_tunnels`), in at any mouth nobody stands on, and over
	whatever `crossings` offers this trip (demo/waterplay/), round the first `standing_count` standing
	residents in `standing` (tunnel_router.gd). With `goal_node` >= 0 the goal is that node underground,
	reached only through the network. True when a route was found."""
	router.clear_pairs()
	router.surface_permille = surface_permille
	var key: int = revision
	if use_tunnels:
		_offer_mouths(body, standing, standing_count, walker_class(walker, loaded), goal_node)
	router.wade_cost = crossings.wade_extra_m if crossings != null else Callable()
	if crossings != null:
		crossings.offer_into(router, walker, from, to, loaded)
		key = revision | (crossings.revision() << REVISION_SHIFT)
	return router.plan(nav, from, to, body, standing, standing_count, key, out, legs, goal_node)


func _offer_mouths(body: float, standing: PackedVector3Array, standing_count: int, fit_class: int, goal_node: int) -> void:
	"""Offer the router every usable mouth nobody stands on that leads somewhere (`leads_on`), with the paths for
	this walker's class."""
	router.use_paths(self, fit_class)
	if fit_class == PathsScript.CLASS_NONE:
		return
	for m in Rules.MAX_MOUTHS:
		if mouth_usable(m) and paths.admits(self, mouth_ramp(m), fit_class) and leads_on(m, fit_class, goal_node) \
				and not mouth_occupied(m, body, standing, standing_count):
			router.add_mouth(m, mouth_at(m), queue.wait_m(m))


func leads_on(m: int, fit_class: int, goal_node: int) -> bool:
	"""Whether mouth `m` is a way anywhere for `fit_class`: another usable mouth, or `goal_node` (a trip's goal
	underground), is reached from it through the network. A standalone room's door leads only into its room
	(decision 0209): offered for a trip bound there, never as a way through -- the router need not weigh it."""
	if goal_node >= 0 and paths.dist_u(self, fit_class, m, goal_node) < PathsScript.UNREACHED:
		return true
	for n in Rules.MAX_MOUTHS:
		if n != m and mouth_usable(n) and paths.dist_u(self, fit_class, m, mouth_node[n]) < PathsScript.UNREACHED:
			return true
	return false


# --- places along a piece (the crews, presentation) -----------------------------------------

func piece_offset_m(slot: int) -> float:
	"""How far along its piece (m) segment `slot` begins: the lengths of the segments dug before it."""
	var total := 0.0
	var chain := PackedInt32Array()
	piece_segments_into(piece[slot], chain)
	for other in chain:
		if other == slot:
			return total
		total += length_m(other)
	return total


func way_in_m(p: int) -> Vector2:
	"""Where piece `p` is gone into from the surface: the mouth it opens at its start, else its spoil mouth
	(the network's mouth nearest its start), in metres."""
	var first := first_of_piece(p)
	if first >= 0 and node_mouth[node_a[first]] >= 0:
		return node_m(node_a[first])
	return mouth_at(piece_mouth[p]) if is_mouth(piece_mouth[p]) else node_m(node_a[first])


func piece_locate_into(p: int, along_m: float, out: PackedFloat32Array) -> void:
	"""Where the point `along_m` metres along piece `p` lies: out[0] its segment, out[1] how far along that
	segment (clamped to the piece)."""
	var chain := PackedInt32Array()
	piece_segments_into(p, chain)
	var left := maxf(along_m, 0.0)
	for slot in chain:
		if left <= length_m(slot) or slot == chain[chain.size() - 1]:
			out[0] = slot
			out[1] = minf(left, length_m(slot))
			return
		left -= length_m(slot)
