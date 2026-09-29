extends RefCounted
## Where a tunnel's two spoil heaps stand. Decision 0196 (live demo). Presentation only.
##
## When a dig is accepted each mouth's heap is placed at its FINISHED size -- the spoil that mouth
## will have heaped when the tunnel opens (tunnel_rules.spoil_into at the last tick), drawn at
## tunnel_overlay.heap_radius_m -- and registered with the cast as an obstacle then (CastSpace
## .set_heaps: one navigation rebuild per dig, never per frame). The heap grows in place as spoil
## posts; nobody is left standing where it will end up, and nobody is routed through it.
##
## A heap tries the spots beside its mouth in CANDIDATE_TURNS order -- to the right of the way out
## (the old fixed spot), then the left, then the diagonals and straight on -- and takes the first
## that is inside the village, HEAP_CLEAR_M clear of every obstacle, SPOT_CLEAR_M clear of every work
## spot, and clear of every tunnel's hole and rim (and of its own tunnel's other heap). With none
## clear it takes the candidate with the most room, so a heap is always somewhere.

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const NetworkScript := preload("res://demo/tunnel/tunnel_network.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const OverlayScript := preload("res://demo/tunnel/tunnel_overlay.gd")

## Turns from "right of the way out", in radians: right, left, the four diagonals, straight on.
const CANDIDATE_TURNS: Array[float] = [0.0, PI, 0.785398, -0.785398, 2.356194, -2.356194, -1.570796]
const HEAP_CLEAR_M: float = 0.15
const SPOT_CLEAR_M: float = 0.45
## A candidate stands this much beyond HEAP_CLEAR_M from its own mouth's rim.
const REACH_SLACK_M: float = 0.01


static func place(network: NetworkScript, space: CastSpaceScript, slot: int) -> void:
	"""Choose both heaps' spots for tunnel `slot`, keep them in the network and make them obstacles."""
	var finished := PackedInt64Array([0, 0])
	Rules.spoil_into(Rules.total_ticks(network.quanta[slot]), network.quanta[slot], finished)
	var circles := PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
	for end in 2:
		var r := OverlayScript.heap_radius_m(finished[end])
		var at := _choose(network, space, slot, end, r, circles[0])
		network.set_heap(slot, end == 1, at, r)
		circles[end] = Vector3(at.x, r, at.y)
	space.set_heaps(slot, circles[0], circles[1])


static func clear(network: NetworkScript, space: CastSpaceScript, slot: int) -> void:
	"""Forget tunnel `slot`'s heaps (its slot was freed) and stop treating them as obstacles."""
	network.set_heap(slot, false, Vector2.ZERO, 0.0)
	network.set_heap(slot, true, Vector2.ZERO, 0.0)
	space.set_heaps(slot, Vector3.ZERO, Vector3.ZERO)


static func outward(network: NetworkScript, slot: int, end: int) -> Vector2:
	"""The way out of a mouth, away from the tunnel."""
	if end == 0:
		return -network.direction_at(slot, 0.0)
	return network.direction_at(slot, network.length_m(slot))


static func _choose(network: NetworkScript, space: CastSpaceScript, slot: int, end: int, r: float,
		other: Vector3) -> Vector2:
	"""The first clear candidate spot for a heap of radius `r` by mouth `end` (see the header), else the
	roomiest. `other` is this tunnel's heap already placed (radius 0: none)."""
	var mouth := network.mouth(slot, end == 1)
	var out := outward(network, slot, end)
	var reach := Rules.HOLE_RADIUS_M * Rules.RIM_FACTOR + HEAP_CLEAR_M + REACH_SLACK_M + r
	var best := mouth + Vector2(-out.y, out.x) * reach
	var best_room := -INF
	for turn in CANDIDATE_TURNS:
		var at := mouth + Vector2(-out.y, out.x).rotated(turn) * reach
		var room := room_at(network, space, at, r, other)
		if room >= HEAP_CLEAR_M:
			return at
		if room > best_room:
			best_room = room
			best = at
	return best


static func room_at(network: NetworkScript, space: CastSpaceScript, at: Vector2, r: float, other: Vector3) -> float:
	"""How much room a heap of radius `r` at `at` has: the least of its clearance from the village's
	edge, every obstacle, every work spot (less SPOT_CLEAR_M), every hole's rim and the other heap."""
	if not space.bounds.grow(-r).has_point(at):
		return -INF
	var room := space.obstacle_clearance(at) - r
	for poi in space.poi_position.size():
		for k in space.poi_capacity[poi]:
			room = minf(room, space.slot_position(poi, k).distance_to(at) - r - (SPOT_CLEAR_M - HEAP_CLEAR_M))
	var rim := Rules.HOLE_RADIUS_M * Rules.RIM_FACTOR
	for slot in Rules.MAX_TUNNELS:
		if network.phase[slot] != NetworkScript.PHASE_FREE:
			for end in 2:
				room = minf(room, network.mouth(slot, end == 1).distance_to(at) - r - rim)
	if other.y > 0.0:
		room = minf(room, Vector2(other.x, other.z).distance_to(at) - r - other.y)
	return room
