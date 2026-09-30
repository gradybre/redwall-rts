extends RefCounted
## The piece of tunnel a player is laying out. Decisions 0196 (live demo) and 0208 (the network graph).
## Pure data and integer checks: tunnel_control.gd (the Dig tool) feeds it points and draws it; the tests
## drive it directly.
##
## POINTS. The first point is the start, each further one a bend, and the last the end. A point is checked
## as it is laid (tunnel_rules.validate_point: the limit, the bounds, a new mouth's clearance; and here, its
## gap from the last point and whether the new leg runs under a building or water) and refused outright if
## it fails. Points are integer u.
##
## SNAPS. Laid on or near the network, a point SNAPS (`snap_into`): within SNAP_NODE_U of a junction or a
## ramp's foot it is that node; else within SNAP_U of a dug or planned segment's route, the nearest point on
## it. A snapped START begins the piece inside the network, a snapped END ends it there -- a junction, split
## into the segment when the piece is dug; an end that did not snap opens a new MOUTH. A snapped bend in the
## middle would break into that segment, and is refused as such.
##
## THE WHOLE PIECE (`piece_reason`) is checked on confirming: the rules' route checks (at the ends that open
## mouths), water under every leg, then the network's connection rules (tunnel_rules.gd, decision 0208):
##   * a mouth's ramp runs straight RAMP_RUN_U, so a piece is long enough for its ramps and the first and
##     last legs from a mouth run past them;
##   * every corner bends no tighter than BEND_RADIUS_U, on each segment the piece will be cut into;
##   * a junction end joins an open, quiet level bore (not a ramp; not closed or at work), at least
##     JUNCTION_GAP_U from every node, meeting it at the MEETING angle -- or an existing junction with room,
##     keeping that angle from every branch there;
##   * a CROSSING of an open bore becomes a four-way junction: at the meeting angle, in the piece's level
##     part, clear of every node;
##   * the PILLAR: every PILLAR_STEP_U of the piece keeps 1 m of earth from every other bore -- but within
##     JOIN_ZONE_U of where it joins that bore (or a bore next to it: they are one void there) -- and from
##     its own legs but the ones beside;
##   * ROOMS (decision 0209): a piece joins a room only at a free SOCKET, leaving it straight out through its
##     wall -- its leg there runs at least SOCKET_STRAIGHT_U before any bend's fillet, within the MEETING
##     angle of straight out -- and keeps 1 m of earth and half a bore from every room's void (sampled every
##     PILLAR_STEP_U, but within ROOM_JOIN_U of a socket it joins of that room); it never crosses a room's own
##     segments;
##   * the network has room.
## A refusal names its reason; one about another segment names it too (`refused_slot`), one about a room names
## the room (`refused_room`; `refused_name`).
##
## THE ROOM BEING PLACED (the room tool's auto-passage, room_tool.gd). A point snapped END_NODE onto node -1 is
## a socket of a room not laid yet, at that point, whose way straight out is `pending_outward`: it is checked
## as a free socket of a planned room.
##
## WATER. No bore may pass under water: every point and every leg is asked `water_crossing(a, b,
## clearance_u)` -- the village's water adapter (demo/village_water.gd `crosses_water`) -- with half a bore
## of clearance, and refused REFUSE_UNDER_WATER.

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const SpecScript := preload("res://demo/tunnel/piece_spec.gd")

## How near a point must be laid to a node, or to a segment's route, to join it (u; demo values).
const SNAP_NODE_U: int = Rules.JUNCTION_GAP_U
const SNAP_U: int = 1229
## Near a socket it joins, a piece is exempt from the room's pillar this far (u): leaving straight out at the
## meeting angle it has cleared the pillar by then.
const ROOM_JOIN_U: int = 2048
const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")

## (x, z) pairs in u; sized once for MAX_POINTS.
var points_u: PackedInt32Array = PackedInt32Array()
var count: int = 0
## Per laid point: how it snapped (piece_spec.gd END_*: END_NEW_MOUTH for none) and onto what.
var snap_kind: PackedInt32Array = PackedInt32Array()
var snap_ref: PackedInt32Array = PackedInt32Array()
## `(a: Vector2i, b: Vector2i, clearance_u: int) -> bool`: whether a bore a-b meets water (see WATER; unset:
## no water anywhere).
var water_crossing: Callable = Callable()
## The segment the last refusal concerns (-1: none), for its words.
var refused_slot: int = -1
## The room the last refusal concerns (-1: none), for its words.
var refused_room: int = -1
## A socket of the room being placed: its way straight out (see THE ROOM BEING PLACED).
var pending_outward: Vector2i = Vector2i.ZERO
## The crossings `piece_reason` found: (host segment, x_u, z_u) per crossing, in route order.
var crossings: PackedInt32Array = PackedInt32Array()
## `(slot: int) -> bool`: whether a job is at work on a segment, so it may not be joined now (tunnel_jobs.gd;
## unset: none is).
var job_busy: Callable = Callable()

var _snap: PackedInt32Array = PackedInt32Array([0, -1, 0, 0])
var _cuts: PackedInt32Array = PackedInt32Array()
## The pillar check's segments near the piece, and their routes' boxes grown by their pillar gaps (reused).
var _near: PackedInt32Array = PackedInt32Array()
var _near_box: Array[Rect2i] = []


func _init() -> void:
	"""Size the points once."""
	points_u.resize(Rules.MAX_POINTS * 2)
	snap_kind.resize(Rules.MAX_POINTS)
	snap_ref.resize(Rules.MAX_POINTS)


func clear() -> void:
	"""Start a new route."""
	count = 0
	refused_slot = -1
	refused_room = -1
	crossings.clear()


func try_add(x_u: int, z_u: int, bounds_u: Rect2i, circles_u: PackedInt32Array,
		spots_u: PackedInt32Array = PackedInt32Array(), under_u: PackedInt32Array = PackedInt32Array()) -> int:
	"""Lay the next point, not snapped to anything, or refuse it: REFUSE_NONE when it was added, else the
	reason. The point is written in place first and only counted once every check passes."""
	return try_add_snapped(x_u, z_u, SpecScript.END_NEW_MOUTH, -1, bounds_u, circles_u, spots_u, under_u)


func try_add_snapped(x_u: int, z_u: int, kind: int, ref: int, bounds_u: Rect2i, circles_u: PackedInt32Array,
		spots_u: PackedInt32Array = PackedInt32Array(), under_u: PackedInt32Array = PackedInt32Array()) -> int:
	"""Lay the next point, snapped as `kind` onto `ref` (see SNAPS): a snapped start opens no mouth, so the
	mouth's checks are skipped for it. REFUSE_NONE when added, else the reason."""
	if _meets_water(Vector2i(x_u, z_u), Vector2i(x_u, z_u)):
		return Rules.REFUSE_UNDER_WATER
	var index := count if kind == SpecScript.END_NEW_MOUTH else maxi(count, 1)
	var reason := Rules.validate_point(x_u, z_u, index, bounds_u, circles_u, spots_u)
	if reason != Rules.REFUSE_NONE:
		return reason
	points_u[2 * count] = x_u
	points_u[2 * count + 1] = z_u
	snap_kind[count] = kind
	snap_ref[count] = ref
	return _leg_reason_and_count(under_u)


func _leg_reason_and_count(under_u: PackedInt32Array) -> int:
	"""Check the leg into the point just written (not on top of the last, under no building or water) and,
	when it passes, count the point."""
	if count > 0 and Rules.points_too_close(points_u, count):
		return Rules.REFUSE_REPEATED_POINT
	if count > 0 and Rules.leg_under(points_u, count, under_u):
		return Rules.REFUSE_UNDER_BUILDING
	if count > 0 and _leg_meets_water(count):
		return Rules.REFUSE_UNDER_WATER
	count += 1
	return Rules.REFUSE_NONE


func _meets_water(a: Vector2i, b: Vector2i) -> bool:
	"""Whether a bore from a to b (u) would pass under water (see WATER)."""
	return water_crossing.is_valid() and bool(water_crossing.call(a, b, Rules.BORE_WIDTH_U / 2))


func _leg_meets_water(k: int) -> bool:
	"""Whether the leg into point `k` would pass under water."""
	return _meets_water(point_u(k - 1), point_u(k))


func undo() -> bool:
	"""Take back the last point. False when there was none to take."""
	if count == 0:
		return false
	count -= 1
	return true


func point_u(k: int) -> Vector2i:
	"""Point `k` (u)."""
	return Vector2i(points_u[2 * k], points_u[2 * k + 1])


func route_reason(bounds_u: Rect2i, circles_u: PackedInt32Array, spots_u: PackedInt32Array = PackedInt32Array(),
		under_u: PackedInt32Array = PackedInt32Array()) -> int:
	"""REFUSE_NONE when the route as laid may be dug as a tunnel from a new mouth to a new mouth, else why not
	(the rules', then water, then its ramps: decision 0207)."""
	var reason := Rules.validate_route(points_u, count, bounds_u, circles_u, spots_u, under_u)
	if reason != Rules.REFUSE_NONE:
		return reason
	for k in range(1, count):
		if _leg_meets_water(k):
			return Rules.REFUSE_UNDER_WATER
	return Rules.ramp_refusal(length_u())


func length_u() -> int:
	"""The route's length so far, in u."""
	return Rules.route_length_u(points_u, count)


func length_to_u(x_u: int, z_u: int) -> int:
	"""The route's length if a point at (x_u, z_u) were laid next (the preview under the pointer)."""
	if count == 0:
		return 0
	var dx := x_u - points_u[2 * count - 2]
	var dz := z_u - points_u[2 * count - 1]
	return length_u() + Rules.isqrt(dx * dx + dz * dz)


func point_m(k: int) -> Vector2:
	"""Point `k` in metres (x, z), for drawing."""
	return Vector2(Rules.to_m(points_u[2 * k]), Rules.to_m(points_u[2 * k + 1]))


static func length_text(length_u_value: int) -> String:
	"""A length in u as the panel shows it: metres to one decimal, e.g. "12.4 m". Rounded to the nearest
	tenth -- except that a length the limits refuse is rounded AWAY from the limit, so a refused 7.99 m (too
	short for its ramps) never reads "8.0 m" and a refused 64.04 m never reads "64.0 m"."""
	var tenths := (length_u_value * 10 + Rules.UNITS_PER_M / 2) / Rules.UNITS_PER_M
	if length_u_value < 2 * Rules.RAMP_RUN_U:
		tenths = length_u_value * 10 / Rules.UNITS_PER_M
	elif length_u_value > Rules.MAX_LENGTH_U:
		tenths = Rules.ceil_div(length_u_value * 10, Rules.UNITS_PER_M)
	return "%d.%d m" % [tenths / 10, tenths % 10]


# --- snapping -------------------------------------------------------------------------------

static func snap_into(graph: GraphScript, at: Vector2i, out: PackedInt32Array) -> int:
	"""Where a point laid at `at` joins the network (see SNAPS): out[0] its kind (piece_spec.gd END_*),
	out[1] the node or segment, out[2..3] the point it snaps to (u). Returns the kind."""
	out[0] = SpecScript.END_NEW_MOUTH
	out[1] = -1
	out[2] = at.x
	out[3] = at.y
	var node := _nearest_node(graph, at)
	if node >= 0:
		out[0] = SpecScript.END_NODE
		out[1] = node
		out[2] = graph.node_x_u[node]
		out[3] = graph.node_z_u[node]
		return out[0]
	var slot := _nearest_segment(graph, at)
	if slot >= 0:
		var on := _nearest_on_route(graph, slot, at)
		out[0] = SpecScript.END_ON_SEGMENT
		out[1] = slot
		out[2] = on.x
		out[3] = on.y
	return out[0]


static func _nearest_on_route(graph: GraphScript, slot: int, at: Vector2i) -> Vector2i:
	"""The point of segment `slot`'s route nearest `at` (u): on its nearest leg, projected and floored as
	underground_graph.gd `route_along_u` and `route_point_u` place it -- read in place, as the pointer moves."""
	var base := 2 * slot * Rules.MAX_POINTS
	var best := Vector2i(graph.points_u[base], graph.points_u[base + 1])
	var best_d := -1
	for k in range(1, graph.point_count[slot]):
		var a := Vector2i(graph.points_u[base + 2 * k - 2], graph.points_u[base + 2 * k - 1])
		var b := Vector2i(graph.points_u[base + 2 * k], graph.points_u[base + 2 * k + 1])
		var d := Rules.point_leg_u(at, a, b)
		if best_d >= 0 and d >= best_d:
			continue
		best_d = d
		var ab := b - a
		var leg := maxi(Rules.isqrt(ab.x * ab.x + ab.y * ab.y), 1)
		var into := clampi((ab.x * (at.x - a.x) + ab.y * (at.y - a.y)) / leg, 0, leg)
		best = Vector2i(a.x + ab.x * into / leg, a.y + ab.y * into / leg)
	return best


static func _nearest_node(graph: GraphScript, at: Vector2i) -> int:
	"""The underground node nearest `at` within SNAP_NODE_U (-1: none)."""
	var best := -1
	var best_d := SNAP_NODE_U * SNAP_NODE_U
	for node in Rules.MAX_NODES:
		if not _snaps_to_node(graph, node):
			continue
		var d := graph.node_at(node) - at
		if d.x * d.x + d.y * d.y < best_d:
			best_d = d.x * d.x + d.y * d.y
			best = node
	return best


static func _snaps_to_node(graph: GraphScript, node: int) -> bool:
	"""Whether a point may snap onto node `node`: a junction or a ramp's foot, or a room's free socket (never a
	mouth, a room's middle or its door's foot)."""
	if not graph.is_node(node):
		return false
	var kind := graph.node_kind[node]
	if kind == GraphScript.NODE_SOCKET:
		return graph.is_free_socket(node)
	return kind == GraphScript.NODE_JUNCTION or kind == GraphScript.NODE_RAMP_END


static func _nearest_segment(graph: GraphScript, at: Vector2i) -> int:
	"""The planned or dug segment whose route passes nearest `at` within SNAP_U (-1: none)."""
	var best := -1
	var best_d := SNAP_U + 1
	for slot in Rules.MAX_SEGMENTS:
		if graph.phase[slot] == GraphScript.PHASE_FREE or graph.seg_kind[slot] == GraphScript.SEG_ROOM:
			continue
		var d := _route_gap_u(graph, slot, at)
		if d < best_d:
			best_d = d
			best = slot
	return best


static func _route_gap_u(graph: GraphScript, slot: int, at: Vector2i) -> int:
	"""How far `at` lies from segment `slot`'s route (u)."""
	var best := Rules.MAX_LENGTH_U * 4
	var base := 2 * slot * Rules.MAX_POINTS
	for k in range(1, graph.point_count[slot]):
		var a := Vector2i(graph.points_u[base + 2 * k - 2], graph.points_u[base + 2 * k - 1])
		var b := Vector2i(graph.points_u[base + 2 * k], graph.points_u[base + 2 * k + 1])
		best = mini(best, Rules.point_leg_u(at, a, b))
	return best


# --- the whole piece ------------------------------------------------------------------------

func starts_at_mouth() -> bool:
	"""Whether the piece as laid opens a mouth at its start."""
	return count > 0 and snap_kind[0] == SpecScript.END_NEW_MOUTH


func ends_at_mouth() -> bool:
	"""Whether the piece as laid opens a mouth at its end."""
	return count > 0 and snap_kind[count - 1] == SpecScript.END_NEW_MOUTH


func piece_reason(graph: GraphScript, bounds_u: Rect2i, circles_u: PackedInt32Array,
		spots_u: PackedInt32Array = PackedInt32Array(), under_u: PackedInt32Array = PackedInt32Array()) -> int:
	"""REFUSE_NONE when the piece as laid may be dug into the network, else why not (see THE WHOLE PIECE);
	`refused_slot` names the segment a refusal concerns."""
	refused_slot = -1
	refused_room = -1
	crossings.clear()
	var reason := Rules.validate_piece_route(points_u, count, bounds_u, circles_u, spots_u, under_u,
		starts_at_mouth(), ends_at_mouth())
	for k in range(1, count):
		if reason == Rules.REFUSE_NONE and _leg_meets_water(k):
			reason = Rules.REFUSE_UNDER_WATER
	for check: Callable in [_ramp_reason, _snap_reason.bind(graph), _crossing_reason.bind(graph),
			_bend_reason, _room_void_reason.bind(graph), _pillar_reason.bind(graph), _rows_reason.bind(graph)]:
		if reason != Rules.REFUSE_NONE:
			return reason
		reason = int(check.call())
	return reason


func _ramp_reason() -> int:
	"""A piece too short for its ramps, or bending on a ramp (see THE WHOLE PIECE)."""
	var ramps := (1 if starts_at_mouth() else 0) + (1 if ends_at_mouth() else 0)
	var length := length_u()
	if ramps == 2 and Rules.ramp_refusal(length) != Rules.REFUSE_NONE:
		return Rules.REFUSE_RAMP_TOO_STEEP
	if ramps == 1 and length < Rules.RAMP_RUN_U + Rules.JUNCTION_GAP_U:
		return Rules.REFUSE_NEAR_NODE
	var first := Rules.isqrt(Rules.leg_squared_u(points_u, 1))
	var last := Rules.isqrt(Rules.leg_squared_u(points_u, count - 1))
	if (starts_at_mouth() and count > 2 and first <= Rules.RAMP_RUN_U) or (ends_at_mouth() and count > 2 and last <= Rules.RAMP_RUN_U):
		return Rules.REFUSE_RAMP_BEND
	return Rules.REFUSE_NONE


func _snap_reason(graph: GraphScript) -> int:
	"""Where the piece joins the network: each snapped end sound, no bend on a segment, not twice the same
	place."""
	for k in range(1, count - 1):
		if snap_kind[k] != SpecScript.END_NEW_MOUTH:
			refused_slot = snap_ref[k] if snap_kind[k] == SpecScript.END_ON_SEGMENT else -1
			return Rules.REFUSE_PILLAR
	if count >= 2 and snap_kind[0] == snap_kind[count - 1] and snap_kind[0] == SpecScript.END_NODE \
			and snap_ref[0] == snap_ref[count - 1]:
		return Rules.REFUSE_SAME_NODE
	var start := _end_reason(graph, 0, 1)
	return start if start != Rules.REFUSE_NONE else _end_reason(graph, count - 1, count - 2)


func _end_reason(graph: GraphScript, k: int, inner: int) -> int:
	"""Whether end point `k` (its leg running to point `inner`) may join the network where it snapped."""
	var leaving := point_u(inner) - point_u(k)
	if snap_kind[k] == SpecScript.END_NODE and (snap_ref[k] < 0 or graph.node_kind[snap_ref[k]] == GraphScript.NODE_SOCKET):
		return _socket_reason(graph, snap_ref[k], k, inner)
	if snap_kind[k] == SpecScript.END_NODE:
		return _node_reason(graph, snap_ref[k], leaving)
	if snap_kind[k] == SpecScript.END_ON_SEGMENT:
		return _host_reason(graph, snap_ref[k], point_u(k), leaving)
	return Rules.REFUSE_NONE


func _node_reason(graph: GraphScript, node: int, leaving: Vector2i) -> int:
	"""Joining existing node `node`: room for one more branch, the meeting angle from every branch there, and a
	way to it through the network (one of its segments open and quiet)."""
	if graph.degree(node) >= Rules.JUNCTION_DEGREE:
		return Rules.REFUSE_JUNCTION_FULL
	var reached := false
	for k in GraphScript.DEGREE:
		var slot := graph.node_segment(node, k)
		if slot < 0:
			continue
		if not Rules.branches_apart(leaving, graph.leaving_dir(slot, node)):
			return Rules.REFUSE_SHALLOW_MEETING
		reached = reached or _quiet(graph, slot)
		refused_slot = slot
	if not reached:
		return Rules.REFUSE_HOST_BUSY
	refused_slot = -1
	return Rules.REFUSE_NONE


func _socket_reason(graph: GraphScript, node: int, k: int, inner: int) -> int:
	"""Joining a room at socket `node` (-1: a socket of the room being placed) from end point `k`, its leg
	running to point `inner`: a free socket, left straight out -- the leg's straight part at least
	SOCKET_STRAIGHT_U, within the meeting angle of the socket's way out. The room need not be dug yet."""
	if node >= 0 and not graph.is_free_socket(node):
		return Rules.REFUSE_SOCKET_TAKEN
	var outward := pending_outward
	if node >= 0:
		outward = graph.node_at(node) - graph.node_at(graph.rooms.middle[graph.node_room[node]])
	var leaving := point_u(inner) - point_u(k)
	if not Rules.leaves_straight(leaving, outward) or _straight_from(k, inner) < Rules.SOCKET_STRAIGHT_U:
		return Rules.REFUSE_SOCKET_ANGLE
	return Rules.REFUSE_NONE


func _straight_from(k: int, inner: int) -> int:
	"""How far the leg from end point `k` to point `inner` runs straight (u): its length, less the fillet of the
	bend at `inner` when there is one."""
	var leg := Rules.isqrt(Rules.leg_squared_u(points_u, maxi(k, inner)))
	if inner == 0 or inner == count - 1:
		return leg
	var beyond := inner + (inner - k)
	return leg - Rules.fillet_reach_u(point_u(inner) - point_u(k), point_u(beyond) - point_u(inner))


func _host_reason(graph: GraphScript, slot: int, at: Vector2i, leaving: Vector2i) -> int:
	"""Joining segment `slot` at `at`: an open, quiet level bore, the junction clear of every node, met at
	the meeting angle."""
	refused_slot = slot
	if graph.seg_room[slot] >= 0:
		refused_room = graph.seg_room[slot]
		return Rules.REFUSE_INTO_ROOM
	if graph.seg_kind[slot] == GraphScript.SEG_RAMP:
		return Rules.REFUSE_JOIN_RAMP
	if not _quiet(graph, slot):
		return Rules.REFUSE_HOST_BUSY
	if _near_any_node(graph, at):
		return Rules.REFUSE_NEAR_NODE
	var route := graph.segment_route(slot)
	var along := GraphScript.route_along_u(route, graph.point_count[slot], at)
	var ahead := GraphScript.route_point_u(route, graph.point_count[slot], mini(along + Rules.QUANTUM_U, graph.length_u[slot]))
	var behind := GraphScript.route_point_u(route, graph.point_count[slot], maxi(along - Rules.QUANTUM_U, 0))
	if not Rules.meets_squarely(leaving, ahead - behind):
		return Rules.REFUSE_SHALLOW_MEETING
	refused_slot = -1
	return Rules.REFUSE_NONE


func _quiet(graph: GraphScript, slot: int) -> bool:
	"""Whether a segment may be joined now: dug open, not closed by a hazard, no job at work on it."""
	return graph.is_usable(slot) and not (job_busy.is_valid() and bool(job_busy.call(slot)))


static func _near_any_node(graph: GraphScript, at: Vector2i) -> bool:
	"""Whether `at` lies within JUNCTION_GAP_U of any node."""
	for node in Rules.MAX_NODES:
		if graph.is_node(node):
			var d := graph.node_at(node) - at
			if d.x * d.x + d.y * d.y < Rules.JUNCTION_GAP_U * Rules.JUNCTION_GAP_U:
				return true
	return false


func _crossing_reason(graph: GraphScript) -> int:
	"""Every open bore the piece crosses: a four-way junction there if the crossing is sound (see THE WHOLE
	PIECE), gathered into `crossings` and put in route order."""
	for k in range(1, count):
		for slot in Rules.MAX_SEGMENTS:
			if graph.phase[slot] == GraphScript.PHASE_FREE or _is_end_host(slot) or graph.seg_kind[slot] == GraphScript.SEG_ROOM:
				continue
			var reason := _leg_crossings(graph, k, slot)
			if reason != Rules.REFUSE_NONE:
				refused_slot = slot
				return reason
	_sort_crossings()
	return _crossings_apart()


func _sort_crossings() -> void:
	"""Put `crossings` in route order (they are found leg by leg, and on each leg in slot order): an insertion
	sort of (host, x, z) triples by how far along the piece each lies."""
	for i in range(1, crossings.size() / 3):
		var triple := crossings.slice(3 * i, 3 * i + 3)
		var along := _along_of_crossing(i)
		var k := i
		while k > 0 and _along_of_crossing(k - 1) > along:
			for c in 3:
				crossings[3 * k + c] = crossings[3 * (k - 1) + c]
			k -= 1
		for c in 3:
			crossings[3 * k + c] = triple[c]


func _along_of_crossing(i: int) -> int:
	"""How far along the piece crossing `i` lies (u)."""
	return GraphScript.route_along_u(points_u, count, Vector2i(crossings[3 * i + 1], crossings[3 * i + 2]))


func _is_end_host(slot: int) -> bool:
	"""Whether the piece ends on segment `slot` (it touches it there; that is its junction, not a crossing)."""
	for k: int in [0, count - 1]:
		if snap_kind[k] == SpecScript.END_ON_SEGMENT and snap_ref[k] == slot:
			return true
	return false


func _leg_crossings(graph: GraphScript, k: int, slot: int) -> int:
	"""Leg `k` of the piece against every leg of segment `slot`: each crossing checked and kept."""
	var base := 2 * slot * Rules.MAX_POINTS
	for j in range(1, graph.point_count[slot]):
		var c := Vector2i(graph.points_u[base + 2 * j - 2], graph.points_u[base + 2 * j - 1])
		var d := Vector2i(graph.points_u[base + 2 * j], graph.points_u[base + 2 * j + 1])
		if not Rules.legs_cross(point_u(k - 1), point_u(k), c, d):
			continue
		var at := Rules.crossing_point(point_u(k - 1), point_u(k), c, d)
		var reason := _crossing_at(graph, slot, at, point_u(k) - point_u(k - 1), d - c)
		if reason != Rules.REFUSE_NONE:
			return reason
		crossings.append_array([slot, at.x, at.y])
	return Rules.REFUSE_NONE


func _crossing_at(graph: GraphScript, slot: int, at: Vector2i, along_piece: Vector2i, along_host: Vector2i) -> int:
	"""Whether the piece may cross segment `slot` at `at`: an open quiet level bore, crossed squarely, clear
	of every node and of the piece's own ramps and ends -- and no room's (its ramp is the room's way in)."""
	if graph.seg_room[slot] >= 0:
		refused_room = graph.seg_room[slot]
		return Rules.REFUSE_INTO_ROOM
	if graph.seg_kind[slot] == GraphScript.SEG_RAMP:
		return Rules.REFUSE_JOIN_RAMP
	if not _quiet(graph, slot):
		return Rules.REFUSE_HOST_BUSY
	if not Rules.meets_squarely(along_piece, along_host):
		return Rules.REFUSE_SHALLOW_CROSSING
	var along := GraphScript.route_along_u(points_u, count, at)
	var low := (Rules.RAMP_RUN_U if starts_at_mouth() else 0) + Rules.JUNCTION_GAP_U
	var high := length_u() - (Rules.RAMP_RUN_U if ends_at_mouth() else 0) - Rules.JUNCTION_GAP_U
	if _near_any_node(graph, at) or along < low or along > high:
		return Rules.REFUSE_NEAR_NODE
	return Rules.REFUSE_NONE


func _crossings_apart() -> int:
	"""Two crossings closer than JUNCTION_GAP_U along the piece would crowd one hub into another."""
	var last := -Rules.JUNCTION_GAP_U
	for c in crossings.size() / 3:
		var along := GraphScript.route_along_u(points_u, count, Vector2i(crossings[3 * c + 1], crossings[3 * c + 2]))
		if along - last < Rules.JUNCTION_GAP_U:
			refused_slot = crossings[3 * c]
			return Rules.REFUSE_NEAR_NODE
		last = along
	return Rules.REFUSE_NONE


func _bend_reason() -> int:
	"""Every corner bends no tighter than BEND_RADIUS_U on the segment it will lie in (the piece is cut at its
	ramps' feet and its crossings, so a corner's legs end there)."""
	_cut_points()
	for k in range(1, count - 1):
		var along := Rules.route_length_u(points_u, k + 1)
		var before := along - _cut_before(along)
		var after := _cut_after(along) - along
		var into := point_u(k) - point_u(k - 1)
		var onward := point_u(k + 1) - point_u(k)
		var shorter := mini(mini(before, Rules.isqrt(Rules.leg_squared_u(points_u, k))),
			mini(after, Rules.isqrt(Rules.leg_squared_u(points_u, k + 1))))
		if Rules.fillet_reach_u(into, onward) * Rules.PERMILLE > Rules.FILLET_SHARE_PERMILLE * shorter:
			return Rules.REFUSE_TIGHT_BEND
	return Rules.REFUSE_NONE


func _cut_points() -> void:
	"""Where along the piece (u) it will be cut into segments: its ends, its ramps' feet, its crossings."""
	_cuts.clear()
	_cuts.append(0)
	_cuts.append(length_u())
	if starts_at_mouth():
		_cuts.append(Rules.RAMP_RUN_U)
	if ends_at_mouth():
		_cuts.append(length_u() - Rules.RAMP_RUN_U)
	for c in crossings.size() / 3:
		_cuts.append(GraphScript.route_along_u(points_u, count, Vector2i(crossings[3 * c + 1], crossings[3 * c + 2])))


func _cut_before(along: int) -> int:
	"""The nearest cut at or before `along`."""
	var best := 0
	for cut in _cuts:
		if cut <= along and cut > best:
			best = cut
	return best


func _cut_after(along: int) -> int:
	"""The nearest cut at or after `along`."""
	var best := length_u()
	for cut in _cuts:
		if cut >= along and cut < best:
			best = cut
	return best


func _pillar_reason(graph: GraphScript) -> int:
	"""THE PILLAR (see THE WHOLE PIECE), sampled every PILLAR_STEP_U of the piece, against the segments near
	enough to matter -- each sample only against those whose route's box, grown by the pillar, holds it."""
	_near_segments(graph)
	var length := length_u()
	var along := 0
	var leg := 1
	var leg_end := Rules.isqrt(Rules.leg_squared_u(points_u, 1))
	while along <= length:
		while leg < count - 1 and along > leg_end:
			leg += 1
			leg_end += Rules.isqrt(Rules.leg_squared_u(points_u, leg))
		var at := GraphScript.route_point_u(points_u, count, along)
		var reason := _pillar_at(graph, at, leg)
		if reason != Rules.REFUSE_NONE:
			return reason
		along += Rules.PILLAR_STEP_U
	return Rules.REFUSE_NONE


func _near_segments(graph: GraphScript) -> void:
	"""The segments whose routes come within a wide bore's pillar gap of the piece's bounding box, into
	`_near`, each with its route's box grown by its own pillar gap into `_near_box`."""
	var box := Rect2i(point_u(0), Vector2i.ZERO)
	for k in count:
		box = box.expand(point_u(k))
	box = box.grow(Rules.pillar_gap_u(Rules.BORE_STANDARD, Rules.BORE_WIDE))
	_near.clear()
	_near_box.clear()
	for slot in Rules.MAX_SEGMENTS:
		if graph.phase[slot] == GraphScript.PHASE_FREE or graph.seg_kind[slot] == GraphScript.SEG_ROOM:
			continue
		var route_box := _route_box(graph, slot)
		if box.intersects(route_box):
			_near.append(slot)
			_near_box.append(route_box.grow(Rules.pillar_gap_u(Rules.BORE_STANDARD, graph.bore[slot])))


static func _route_box(graph: GraphScript, slot: int) -> Rect2i:
	"""Segment `slot`'s route's bounding box (u; one unit larger, so a straight axis-aligned route still
	has an area)."""
	var base := 2 * slot * Rules.MAX_POINTS
	var box := Rect2i(Vector2i(graph.points_u[base], graph.points_u[base + 1]), Vector2i.ONE)
	for k in range(1, graph.point_count[slot]):
		box = box.expand(Vector2i(graph.points_u[base + 2 * k], graph.points_u[base + 2 * k + 1]))
	return box.grow(1)


func _pillar_at(graph: GraphScript, at: Vector2i, leg: int) -> int:
	"""One sample of THE PILLAR, on leg `leg` of the piece: clear of every nearby bore but near a node it
	shares with it, and of the piece's own legs but the ones beside it."""
	for i in _near.size():
		if not _near_box[i].has_point(at):
			continue
		var slot := _near[i]
		if _route_gap_u(graph, slot, at) < Rules.pillar_gap_u(Rules.BORE_STANDARD, graph.bore[slot]) \
				and not _shares_near(graph, slot, at):
			refused_slot = slot
			refused_room = graph.seg_room[slot]
			return Rules.REFUSE_INTO_ROOM if refused_room >= 0 else Rules.REFUSE_PILLAR
	return _self_gap(at, leg)


func _shares_near(graph: GraphScript, slot: int, at: Vector2i) -> bool:
	"""Whether `at` lies within JOIN_ZONE_U of a place the piece joins the network next to segment `slot`: an
	end on it, on a segment sharing a node with it or on one of its nodes, or a crossing of such a segment --
	voids joined there are one void, and keep no pillar between them."""
	for k: int in [0, count - 1]:
		var host := snap_ref[k] if snap_kind[k] == SpecScript.END_ON_SEGMENT else -1
		var node := snap_ref[k] if snap_kind[k] == SpecScript.END_NODE else -1
		var joins := (host >= 0 and _neighbours(graph, host, slot)) or (node >= 0 and _touches(graph, slot, node))
		if joins and _within(point_u(k), at, Rules.JOIN_ZONE_U):
			return true
	for c in crossings.size() / 3:
		if _neighbours(graph, crossings[3 * c], slot) \
				and _within(Vector2i(crossings[3 * c + 1], crossings[3 * c + 2]), at, Rules.JOIN_ZONE_U):
			return true
	return false


static func _neighbours(graph: GraphScript, host: int, slot: int) -> bool:
	"""Whether `slot` is segment `host` or shares one of its nodes."""
	return slot == host or _touches(graph, slot, graph.node_a[host]) or _touches(graph, slot, graph.node_b[host])


static func _touches(graph: GraphScript, slot: int, node: int) -> bool:
	"""Whether segment `slot` ends at `node`."""
	return graph.node_a[slot] == node or graph.node_b[slot] == node


static func _within(a: Vector2i, b: Vector2i, reach: int) -> bool:
	"""Whether a and b lie within `reach` of each other (u)."""
	var d := a - b
	return d.x * d.x + d.y * d.y < reach * reach


func _self_gap(at: Vector2i, leg: int) -> int:
	"""Whether a sample of the piece, on leg `leg`, keeps THE PILLAR from its own legs but that leg and those
	beside it."""
	for k in range(1, count):
		if absi(k - leg) >= 2 and Rules.point_leg_u(at, point_u(k - 1), point_u(k)) < Rules.pillar_gap_u(Rules.BORE_STANDARD, Rules.BORE_STANDARD):
			return Rules.REFUSE_SELF_PILLAR
	return Rules.REFUSE_NONE


func _room_void_reason(graph: GraphScript) -> int:
	"""ROOMS (see THE WHOLE PIECE): 1 m of earth and half a bore from every room's void, but near a socket of
	that room the piece joins."""
	var reach := Rules.PILLAR_U + Rules.BORE_WIDTH_U / 2
	var box := Rect2i(point_u(0), Vector2i.ONE)
	for k in count:
		box = box.expand(point_u(k))
	var rooms: RoomsScript = graph.rooms
	for r in RoomsScript.MAX_ROOMS:
		if not rooms.is_room(r) or not box.grow(reach).intersects(RoomsScript.world_box(rooms.template[r], rooms.centre(r), rooms.turns[r], 0)):
			continue
		var joins := _joins_room(graph, r)
		for k in range(1, count):
			if rooms.leg_gap_of(r, point_u(k - 1), point_u(k)) < reach and (not joins or _leg_breaks_into(graph, r, k, reach)):
				refused_room = r
				return Rules.REFUSE_INTO_ROOM
	return Rules.REFUSE_NONE


func _joins_room(graph: GraphScript, r: int) -> bool:
	"""Whether an end of the piece joins room `r` at one of its sockets."""
	for k: int in [0, count - 1]:
		if snap_kind[k] == SpecScript.END_NODE and snap_ref[k] >= 0 and graph.node_room[snap_ref[k]] == r:
			return true
	return false


func _leg_breaks_into(graph: GraphScript, r: int, k: int, reach: int) -> bool:
	"""Whether leg `k` of the piece -- which joins room `r` at a socket -- comes within `reach` of the room's void
	anywhere but within ROOM_JOIN_U of that socket (sampled every PILLAR_STEP_U, and at the leg's far end)."""
	var a := point_u(k - 1)
	var b := point_u(k)
	var leg := Rules.isqrt(Rules.leg_squared_u(points_u, k))
	var along := 0
	while true:
		var at := a + (b - a) * mini(along, leg) / maxi(leg, 1)
		if graph.rooms.gap_of(r, at) < reach and not _near_own_socket(graph, r, at):
			return true
		if along >= leg:
			return false
		along += Rules.PILLAR_STEP_U
	return false


func _near_own_socket(graph: GraphScript, r: int, at: Vector2i) -> bool:
	"""Whether `at` lies within ROOM_JOIN_U of an end of the piece that joins room `r` at a socket."""
	for k: int in [0, count - 1]:
		var node := snap_ref[k]
		if snap_kind[k] == SpecScript.END_NODE and node >= 0 and graph.node_room[node] == r and _within(point_u(k), at, ROOM_JOIN_U):
			return true
	return false


func _rows_reason(graph: GraphScript) -> int:
	"""Whether the network has the rows the piece needs."""
	return Rules.REFUSE_NONE if graph.room_for(spec_of(-1)) else Rules.REFUSE_NETWORK_FULL


func refused_name(graph: GraphScript) -> String:
	"""How the words name what the last refusal concerns: a room ("Burrow home 2"), a segment ("Tunnel 4"), or
	"a tunnel"."""
	if refused_room >= 0 and graph.rooms.is_room(refused_room):
		return "%s %d" % [RoomsScript.NAMES[graph.rooms.template[refused_room]], refused_room + 1]
	return "Tunnel %d" % (refused_slot + 1) if refused_slot >= 0 else "a tunnel"


func spec_of(digger_index: int) -> SpecScript:
	"""The piece as laid (with the crossings `piece_reason` found), for `digger_index` to dig
	(underground_graph.gd `add_piece`)."""
	var spec := SpecScript.new()
	spec.set_route(points_u, count)
	spec.start_kind = snap_kind[0]
	spec.start_ref = snap_ref[0]
	spec.end_kind = snap_kind[count - 1]
	spec.end_ref = snap_ref[count - 1]
	spec.crossings = crossings.duplicate()
	spec.digger = digger_index
	return spec
