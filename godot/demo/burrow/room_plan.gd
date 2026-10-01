extends RefCounted
## The room being placed with the room tool, and the passage proposed for it. Decision 0209 (the underground
## revamp's P3; design docs/design/underground_revamp.md §4 "Tools"). Pure data and integer checks: room_tool.gd
## feeds it the pointer and draws it; the tests drive it directly.
##
## PLACING. A room of `kind` stands at `centre_u`, turned `turns` quarter turns (underground_rooms.gd FRAME);
## `check` asks the rooms whether it may go there (underground_rooms.gd WHERE ONE MAY GO) and, when it may and
## it is not STANDALONE, proposes its passage.
##
## THE AUTO-PASSAGE (design §4: "an automatic passage preview to the nearest valid bore within 6 m"). For each of
## the room's sockets, every open tunnel bore (a level one, not a ramp, not a room's) and every junction or
## ramp's foot within AUTO_REACH_U of the socket offers a way to join it: the foot of the perpendicular from the
## socket, and the point where the socket's way straight out meets the bore. The shortest that the Dig tool's
## own rules accept (tunnel_plan.gd THE WHOLE PIECE: the joint, the pillar, water, buildings, the socket left
## straight out) and that keeps a pillar of earth from the room's own door ramp is the passage: a piece from the
## network ending END_NODE at the socket, starting where its join snapped (a node, or a point on a bore) and
## measured from there. None found, the room is standalone: it is dug from its own door and connected later
## by digging to one of its sockets.
##
## ON LEVEL 2 (decision 0212). A room on the second level has no door to the surface: its door is a SOCKET
## (underground_graph.gd ROOMS), and its passage joins it THERE -- the room is dug from its door, so the passage
## must reach it -- from level 2's network (its bores, junctions and blind ends, a link's foot among them). It may
## not stand alone: with no passage found (or placed standalone) it is refused (REFUSE_NEEDS_PASSAGE).

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")
const PlanScript := preload("res://demo/tunnel/tunnel_plan.gd")
const SpecScript := preload("res://demo/tunnel/piece_spec.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")

## How far from a socket the network may be joined (u; design §4: 6 m).
const AUTO_REACH_U: int = 6144

var kind: int = RoomsScript.TEMPLATE_HOME
var centre_u: Vector2i = Vector2i.ZERO
var turns: int = 0
## The level the room is placed on (see ON LEVEL 2).
var level: int = Rules.TOP_LEVEL
## Placed without a passage, even where one could join it.
var standalone: bool = false
## The last `check`: the room's refusal (underground_rooms.gd REFUSE_*), and the passage proposed (count 0: none)
## to socket `passage_socket` (-1: none).
var refusal: int = RoomsScript.REFUSE_NONE
var passage: PlanScript = PlanScript.new()
var passage_socket: int = -1

var _snap: PackedInt32Array = PackedInt32Array([0, -1, 0, 0])
var _best: PackedInt32Array = PackedInt32Array()
var _best_kind: PackedInt32Array = PackedInt32Array([0, -1])


func rotate(by: int) -> void:
	"""Turn the room `by` quarter turns (R: one on, Shift+R: one back)."""
	turns = posmod(turns + by, 4)


func check(graph: GraphScript, site: RoomsScript.Site) -> int:
	"""Whether the room may be dug where it stands (REFUSE_NONE, or why not), and -- when it may and is not
	standalone -- its passage (see THE AUTO-PASSAGE)."""
	refusal = graph.rooms.refusal(graph, site, kind, centre_u, turns, level)
	passage.clear()
	passage.level = level
	passage_socket = -1
	if refusal == RoomsScript.REFUSE_NONE and not standalone:
		_propose(graph, site)
	if refusal == RoomsScript.REFUSE_NONE and level != Rules.TOP_LEVEL and passage.count < 2:
		refusal = RoomsScript.REFUSE_NEEDS_PASSAGE
	return refusal


func socket_count() -> int:
	"""How many ways in the passage may take: every socket on level 1; on level 2 only the door (see ON LEVEL 2)."""
	return RoomsScript.socket_count(kind) if level == Rules.TOP_LEVEL else 1


func socket_point(k: int) -> Vector2i:
	"""Where way in `k` stands (u): socket `k`, or on level 2 the door."""
	return RoomsScript.socket_at(kind, centre_u, turns, k) if level == Rules.TOP_LEVEL \
			else RoomsScript.door_at(kind, centre_u, turns)


func socket_outward(k: int) -> Vector2i:
	"""The way straight out of way in `k`: from the middle through it."""
	return socket_point(k) - centre_u


func _propose(graph: GraphScript, site: RoomsScript.Site) -> void:
	"""The shortest passage the rules accept, from any socket (see THE AUTO-PASSAGE), laid into `passage`."""
	var best_length := AUTO_REACH_U + 1
	_best.clear()
	for k in socket_count():
		var socket := socket_point(k)
		var outward := socket_outward(k)
		for candidate in _candidates(graph, socket, outward):
			if not _try(graph, site, candidate, socket, outward):
				continue
			var joined := Vector2i(_snap[2], _snap[3])
			if _length(joined, socket) < best_length:
				best_length = _length(joined, socket)
				_best = PackedInt32Array([joined.x, joined.y, _best_kind[0], _best_kind[1], k])
	passage.clear()
	if _best.is_empty():
		return
	_lay(graph, Vector2i(_best[0], _best[1]), _best[2], _best[3], socket_point(_best[4]), socket_outward(_best[4]), site)
	passage_socket = _best[4]


static func _length(a: Vector2i, b: Vector2i) -> int:
	"""The straight length a-b (u)."""
	var d := b - a
	return Rules.isqrt(d.x * d.x + d.y * d.y)


func _candidates(graph: GraphScript, socket: Vector2i, outward: Vector2i) -> Array[Vector2i]:
	"""Where the network within AUTO_REACH_U of `socket` may be joined (see THE AUTO-PASSAGE): feet of the
	perpendicular, and where the way straight out meets a bore, on every open tunnel bore's legs; and every
	junction and ramp's foot."""
	var out: Array[Vector2i] = []
	for slot in Rules.MAX_SEGMENTS:
		if graph.is_tunnel(slot) and graph.is_usable(slot) and graph.seg_kind[slot] == GraphScript.SEG_BORE \
				and graph.seg_level[slot] == level:
			_leg_candidates(graph, slot, socket, outward, out)
	for node in Rules.MAX_NODES:
		var node_kind: int = graph.node_kind[node] if graph.is_node(node) else GraphScript.NODE_FREE
		if (node_kind == GraphScript.NODE_JUNCTION or node_kind == GraphScript.NODE_RAMP_END or node_kind == GraphScript.NODE_END) \
				and graph.node_level[node] == level and _length(graph.node_at(node), socket) <= AUTO_REACH_U:
			out.append(graph.node_at(node))
	return out


func _leg_candidates(graph: GraphScript, slot: int, socket: Vector2i, outward: Vector2i, out: Array[Vector2i]) -> void:
	"""Segment `slot`'s legs' candidates near `socket`: the perpendicular's foot, and the way out's meeting."""
	var base := 2 * slot * Rules.MAX_POINTS
	@warning_ignore("integer_division") var far := socket + Rules.unit_of(outward.x, outward.y) * AUTO_REACH_U / Rules.DIR_SCALE
	for k in range(1, graph.point_count[slot]):
		var a := Vector2i(graph.points_u[base + 2 * k - 2], graph.points_u[base + 2 * k - 1])
		var b := Vector2i(graph.points_u[base + 2 * k], graph.points_u[base + 2 * k + 1])
		if Rules.point_leg_u(socket, a, b) > AUTO_REACH_U:
			continue
		out.append(_foot(socket, a, b))
		if Rules.legs_cross(socket, far, a, b):
			out.append(Rules.crossing_point(socket, far, a, b))


static func _foot(p: Vector2i, a: Vector2i, b: Vector2i) -> Vector2i:
	"""The point of leg a-b nearest `p` (u, floored)."""
	var ab := b - a
	var length_sq := maxi(ab.x * ab.x + ab.y * ab.y, 1)
	var along := clampi(ab.x * (p.x - a.x) + ab.y * (p.y - a.y), 0, length_sq)
	@warning_ignore("integer_division") return Vector2i(a.x + ab.x * along / length_sq, a.y + ab.y * along / length_sq)


func _try(graph: GraphScript, site: RoomsScript.Site, at: Vector2i, socket: Vector2i, outward: Vector2i) -> bool:
	"""Whether a passage from the network at `at` straight to `socket` passes the Dig tool's rules; its join
	(PlanScript.snap_into: a node, or a point on a bore) kept in _best_kind, and the point it snapped to in
	_snap[2..3] -- which is where the passage starts, and what it is measured from."""
	var join := PlanScript.snap_into(graph, at, _snap, level)
	if join == SpecScript.END_NEW_MOUTH:
		return false
	_best_kind[0] = join
	_best_kind[1] = _snap[1]
	return _lay(graph, Vector2i(_snap[2], _snap[3]), join, _snap[1], socket, outward, site)


func _lay(graph: GraphScript, at: Vector2i, join: int, ref: int, socket: Vector2i, outward: Vector2i,
		site: RoomsScript.Site) -> bool:
	"""Lay the passage from the network (`join` onto `ref` at `at`) to the room's socket into `passage`, and
	whether the rules accept it. Laying the best one again, as `_propose` does, repeats a lay that passed: it
	depends on nothing but these and the graph, which a check does not change."""
	passage.clear()
	passage.level = level
	passage.pending_outward = outward
	if passage.try_add_snapped(at.x, at.y, join, ref, site.bounds_u, site.circles_u, site.spots_u, site.under_u) != Rules.REFUSE_NONE:
		return false
	if passage.try_add_snapped(socket.x, socket.y, SpecScript.END_NODE, -1, site.bounds_u, site.circles_u, site.spots_u,
			site.under_u) != Rules.REFUSE_NONE:
		return false
	return accepts(graph, site)


func accepts(graph: GraphScript, site: RoomsScript.Site) -> bool:
	"""Whether the passage laid in `passage` may be dug: the Dig tool's rules over the whole piece, and a pillar
	of earth from the room's own door ramp (`clear_of_own_ramp`)."""
	return passage.piece_reason(graph, site.bounds_u, site.circles_u, site.spots_u, site.under_u) == Rules.REFUSE_NONE \
			and clear_of_own_ramp()


func clear_of_own_ramp() -> bool:
	"""Whether the passage keeps a pillar of earth from the room's own door ramp -- which the Dig tool's rules
	cannot see yet, the room not being laid -- as they will once it is (a wide bore beside a standard one). A room
	on level 2 has no ramp."""
	if level != Rules.TOP_LEVEL:
		return true
	var hole := RoomsScript.mouth_at(kind, centre_u, turns)
	var foot := RoomsScript.door_at(kind, centre_u, turns)
	for k in range(1, passage.count):
		if RoomsScript.legs_gap_u(passage.point_u(k - 1), passage.point_u(k), hole, foot) \
				< Rules.pillar_gap_u(Rules.BORE_WIDE, Rules.BORE_STANDARD):
			return false
	return true
