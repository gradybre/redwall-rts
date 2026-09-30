extends RefCounted
## One piece of tunnel the dig tool has laid and checked, handed to the network to store
## (underground_graph.gd `add_piece`). Decision 0208. Plain data: tunnel_plan.gd fills it, the network
## reads it.
##
## A PIECE runs along its route polyline from a START to an END. Each end is a NEW MOUTH opening on the
## surface at that route point, an existing NODE of the network (a junction or a ramp's foot), or a point
## ON an open SEGMENT's route, where the network splits that segment with a new junction. On the way it
## may CROSS open segments: each crossing (host segment, point) becomes a four-way junction. The network
## cuts the piece into segments at its ramps' feet and its junctions (see underground_graph.gd PIECES).

const END_NEW_MOUTH: int = 0
const END_NODE: int = 1
const END_ON_SEGMENT: int = 2

## (x, z) pairs in u, start first; `count` of them.
var points_u: PackedInt32Array = PackedInt32Array()
var count: int = 0
var start_kind: int = END_NEW_MOUTH
## The node (END_NODE) or segment (END_ON_SEGMENT) the start is on; unused for a new mouth.
var start_ref: int = -1
var end_kind: int = END_NEW_MOUTH
var end_ref: int = -1
## (host segment, x_u, z_u) per crossing, in route order.
var crossings: PackedInt32Array = PackedInt32Array()
## The resident who will dig it (-1: nobody yet).
var digger: int = -1


func set_route(route_u: PackedInt32Array, point_count: int) -> void:
	"""Take the first `point_count` points of a flat (x, z) route in u."""
	points_u = route_u.slice(0, 2 * point_count)
	count = point_count


func point(k: int) -> Vector2i:
	"""Route point `k` (u)."""
	return Vector2i(points_u[2 * k], points_u[2 * k + 1])


func crossing_count() -> int:
	"""How many crossings the piece makes."""
	return crossings.size() / 3


func starts_at_mouth() -> bool:
	"""Whether the piece opens a new mouth at its start."""
	return start_kind == END_NEW_MOUTH


func ends_at_mouth() -> bool:
	"""Whether the piece opens a new mouth at its end."""
	return end_kind == END_NEW_MOUTH
