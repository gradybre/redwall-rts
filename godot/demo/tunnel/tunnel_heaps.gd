extends RefCounted
## Where each mouth's spoil heap stands. Decisions 0196 (live demo) and 0208 (the network: one heap per
## mouth). Presentation only.
##
## When a dig is accepted the heap of every mouth it spoils at is placed at its FINISHED size -- the spoil
## that mouth will have heaped when every segment spoiling there is dug (underground_graph.gd
## `finished_spoil`), drawn at tunnel_overlay.heap_radius_m -- and registered with the cast as an obstacle
## then (CastSpace.set_heap: one navigation rebuild per dig, never per frame). The heap grows in place as
## spoil posts; nobody is left standing where it will end up, and nobody is routed through it.
##
## A heap tries the spots beside its mouth in CANDIDATE_TURNS order -- to the right of the way out (the old
## fixed spot), then the left, then the diagonals and straight on -- and takes the first that is inside the
## village, HEAP_CLEAR_M clear of every obstacle, SPOT_CLEAR_M clear of every work spot, and clear of every
## mouth's hole and rim and of its ramp's open cutting (decision 0211: a heap grown load by load in the player's view
## must not spill over the way down). With none clear it takes the candidate with the most room, so a heap is always
## somewhere. A heap already placed that must grow (a later dig spoiling at the same mouth, a widening)
## grows where it is: on the same side, pushed out so its rim still clears the hole.

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const OverlayScript := preload("res://demo/tunnel/tunnel_overlay.gd")
const MouthScript := preload("res://demo/tunnel/tunnel_mouth.gd")

## Turns from "right of the way out", in radians: right, left, the four diagonals, straight on.
const CANDIDATE_TURNS: Array[float] = [0.0, PI, 0.785398, -0.785398, 2.356194, -2.356194, -1.570796]
const HEAP_CLEAR_M: float = 0.15
const SPOT_CLEAR_M: float = 0.45
## A candidate stands this much beyond HEAP_CLEAR_M from its own mouth's rim.
const REACH_SLACK_M: float = 0.01
## A ramp's cutting's half-width with its banks (tunnel_mouth.gd).
const CUT_HALF_M: float = MouthScript.CUT_WIDTH_M * 0.5 + MouthScript.BANK_WIDTH_M


static func place(network: GraphScript, space: CastSpaceScript, m: int, extra_milli_u: int = 0) -> void:
	"""Choose (or grow) mouth `m`'s heap for its finished spoil, keep it in the network and make it an
	obstacle. `extra_milli_u` is spoil still to come (a widening accepted), sized in now."""
	var r := OverlayScript.heap_radius_m(network.finished_spoil(m, extra_milli_u))
	var out := -network.mouth_inward(m)
	var side := network.heap_dir[m] if network.heap_radius_m[m] > 0.0 else Vector2.ZERO
	if side == Vector2.ZERO:
		side = _choose(network, space, m, out, r)
	var at := network.mouth_at(m) + side * _reach(r)
	network.set_heap(m, at, r, side)
	space.set_heap(m, Vector3(at.x, r, at.y))


static func clear(network: GraphScript, space: CastSpaceScript, m: int) -> void:
	"""Forget mouth `m`'s heap (its mouth was freed) and stop treating it as an obstacle."""
	network.set_heap(m, Vector2.ZERO, 0.0, Vector2.ZERO)
	space.set_heap(m, Vector3.ZERO)


static func _reach(r: float) -> float:
	"""How far from its mouth a heap of radius `r` stands: clear of the hole's rim and of the ramp's cutting beside it."""
	return maxf(Rules.HOLE_RADIUS_M * Rules.RIM_FACTOR, CUT_HALF_M) + HEAP_CLEAR_M + REACH_SLACK_M + r


static func _choose(network: GraphScript, space: CastSpaceScript, m: int, out: Vector2, r: float) -> Vector2:
	"""The side (unit, from the mouth) of the first clear candidate spot for a heap of radius `r` by mouth `m`
	(see the header), else the roomiest."""
	var mouth := network.mouth_at(m)
	var best := Vector2(-out.y, out.x)
	var best_room := -INF
	for turn in CANDIDATE_TURNS:
		var side := Vector2(-out.y, out.x).rotated(turn)
		var room := room_at(network, space, mouth + side * _reach(r), r)
		if room >= HEAP_CLEAR_M:
			return side
		if room > best_room:
			best_room = room
			best = side
	return best


static func room_at(network: GraphScript, space: CastSpaceScript, at: Vector2, r: float) -> float:
	"""How much room a heap of radius `r` at `at` has: the least of its clearance from the village's edge,
	every obstacle, every work spot (less SPOT_CLEAR_M) and every mouth's hole and rim."""
	if not space.bounds.grow(-r).has_point(at):
		return -INF
	var room := space.obstacle_clearance(at) - r
	for poi in space.poi_position.size():
		for k in space.poi_capacity[poi]:
			room = minf(room, space.slot_position(poi, k).distance_to(at) - r - (SPOT_CLEAR_M - HEAP_CLEAR_M))
	var rim := Rules.HOLE_RADIUS_M * Rules.RIM_FACTOR
	for m in Rules.MAX_MOUTHS:
		if network.is_mouth(m):
			room = minf(room, network.mouth_at(m).distance_to(at) - r - rim)
			room = minf(room, cutting_gap(network, space, m, at) - r)
	return room


static func cutting_gap(network: GraphScript, space: CastSpaceScript, m: int, at: Vector2) -> float:
	"""How far `at` stands outside mouth `m`'s ramp cutting (its run down the ramp to the arch's far side, its banks
	and its forecourt; tunnel_mouth.gd `cutting_gap`) (m; 0 on it)."""
	var bore := int(network.bore[network.mouth_ramp(m)])
	return MouthScript.cutting_gap(network, m, at, space.court_half_m(bore), MouthScript.BANK_WIDTH_M)
