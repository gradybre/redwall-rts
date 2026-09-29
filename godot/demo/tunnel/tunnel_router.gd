extends RefCounted
## Route planning through the demo's finished tunnels. Decision 0196 (live demo). Presentation
## only: it plans the demo cast's walks, never the simulation's.
##
## ---------------------------------------------------------------------------------------
## A SMALL GRAPH OVER THE SURFACE PLANNER. Nodes are the trip's start and goal and both mouths of
## every open tunnel the walker fits. Between any two nodes runs a SURFACE edge, costing the length
## of cast_nav.gd's route between them; between a tunnel's two mouths also runs a TUNNEL edge,
## costing the tunnel's own length -- what the walker actually covers underground, at its walk
## speed. So a tunnel wins only when surface-to-mouth + tunnel + mouth-to-goal is SHORTER than the
## best walk without it: it is never discounted, and a tie keeps the surface -- routes are compared
## by (length, tunnels crossed), so of two equally short routes the one with fewer tunnels wins,
## whatever order the search happens to reach them in.
##
## LAZY SURFACE COSTS. A surface plan costs far more than a graph step, so each surface edge starts
## at its straight-line length -- a lower bound on any route -- and is planned for real only when
## it lies on the current best path. The search then runs again; when the best path's surface edges
## are all real, it is optimal (every edge off it is costed no higher than its truth). By the
## triangle inequality the first best path is always the direct start -> goal edge, so a trip that
## no tunnel can shorten costs one surface plan, as it did before tunnels existed.
##
## Tunnels chain: two tunnels can be linked by a surface edge between their mouths.
## Allocation: every column is sized once in _init(); a plan reuses them.

const CastNavScript := preload("res://demo/cast/cast_nav.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")

const START: int = 0
const GOAL: int = 1
const FIRST_MOUTH: int = 2
const MAX_NODES: int = FIRST_MOUTH + 2 * Rules.MAX_TUNNELS
const VIA_SURFACE: int = 0
const VIA_TUNNEL: int = 1
## Leg code for a waypoint reached on the surface (see `leg_code`).
const SURFACE_LEG: int = -1

## The open tunnels this plan may use: slot, the mouths, and the length underground.
var pair_count: int = 0
var pair_slot: PackedInt32Array = PackedInt32Array()
var pair_length_m: PackedFloat32Array = PackedFloat32Array()
## Surface plans run by the last plan (for measurement and the tests).
var last_surface_plans: int = 0

var _node: PackedVector2Array = PackedVector2Array()
var _count: int = 0
var _weight: PackedFloat32Array = PackedFloat32Array()
var _exact: PackedByteArray = PackedByteArray()
var _routes: Array[PackedVector2Array] = []
var _dist: PackedFloat32Array = PackedFloat32Array()
var _prev: PackedInt32Array = PackedInt32Array()
var _via: PackedByteArray = PackedByteArray()
var _crossed: PackedInt32Array = PackedInt32Array()
var _done: PackedByteArray = PackedByteArray()
var _chain: PackedInt32Array = PackedInt32Array()
var _settled: int = START


func _init() -> void:
	"""Size every column for MAX_NODES once."""
	pair_slot.resize(Rules.MAX_TUNNELS)
	pair_length_m.resize(Rules.MAX_TUNNELS)
	_node.resize(MAX_NODES)
	_weight.resize(MAX_NODES * MAX_NODES)
	_exact.resize(MAX_NODES * MAX_NODES)
	_routes.resize(MAX_NODES * MAX_NODES)
	for i in _routes.size():
		_routes[i] = PackedVector2Array()
	_dist.resize(MAX_NODES)
	_prev.resize(MAX_NODES)
	_via.resize(MAX_NODES)
	_crossed.resize(MAX_NODES)
	_done.resize(MAX_NODES)
	_chain.resize(MAX_NODES)


func clear_pairs() -> void:
	"""Forget the tunnels offered to the next plan."""
	pair_count = 0


func add_pair(slot: int, mouth_a: Vector2, mouth_b: Vector2, length_m: float) -> void:
	"""Offer one open tunnel: its slot, its two mouths and its length. At most MAX_TUNNELS."""
	pair_slot[pair_count] = slot
	pair_length_m[pair_count] = length_m
	_node[FIRST_MOUTH + 2 * pair_count] = mouth_a
	_node[FIRST_MOUTH + 2 * pair_count + 1] = mouth_b
	pair_count += 1


static func leg_code(slot: int, reverse: bool) -> int:
	"""The leg code for crossing tunnel `slot` (mouth a -> b, or b -> a when `reverse`)."""
	return slot * 2 + (1 if reverse else 0)


static func leg_slot(code: int) -> int:
	"""The tunnel slot a leg code crosses."""
	return code >> 1


static func leg_reversed(code: int) -> bool:
	"""Whether a leg code crosses its tunnel from mouth b to mouth a."""
	return code & 1 == 1


func plan(nav: CastNavScript, from: Vector2, to: Vector2, body: float, standing: PackedVector3Array,
		standing_count: int, out: PackedVector2Array, legs: PackedInt32Array) -> bool:
	"""Fill `out` with waypoints from `from` (excluded) to `to` (last) and `legs` with each waypoint's
	leg code (SURFACE_LEG, or a tunnel crossed to reach it). True when a route was found; otherwise
	the surface planner's straight-line fallback is written, as cast_nav.gd does without tunnels."""
	_reset(from, to)
	for round_index in MAX_NODES * MAX_NODES + 1:
		_search()
		if _dist[GOAL] == INF:
			break
		if _refine(nav, body, standing, standing_count) == 0:
			_emit(out, legs)
			return true
	nav.plan(from, to, body, standing, standing_count, out)
	legs.resize(out.size())
	legs.fill(SURFACE_LEG)
	return false


func _reset(from: Vector2, to: Vector2) -> void:
	"""This plan's nodes, every surface edge at its straight-line lower bound."""
	_node[START] = from
	_node[GOAL] = to
	_count = FIRST_MOUTH + 2 * pair_count
	last_surface_plans = 0
	for u in _count:
		for v in _count:
			_weight[u * MAX_NODES + v] = _node[u].distance_to(_node[v])
			_exact[u * MAX_NODES + v] = 0


static func _partner(mouth: int) -> int:
	"""The other mouth of a mouth node's tunnel (`mouth` >= FIRST_MOUTH)."""
	return mouth + 1 if (mouth - FIRST_MOUTH) % 2 == 0 else mouth - 1


func _search() -> void:
	"""Dense Dijkstra from START over the current costs; fills _dist, _prev and _via."""
	for u in _count:
		_dist[u] = INF
		_prev[u] = -1
		_done[u] = 0
		_crossed[u] = 0
	_dist[START] = 0.0
	for pass_index in _count:
		if not _settle_nearest():
			return
		var u := _settled
		if u == GOAL:
			return
		for v in _count:
			if v != START and v != u and _done[v] == 0:
				_relax(u, v, _weight[u * MAX_NODES + v], VIA_SURFACE)
		if u >= FIRST_MOUTH and _done[_partner(u)] == 0:
			_relax(u, _partner(u), pair_length_m[(u - FIRST_MOUTH) / 2], VIA_TUNNEL)


func _settle_nearest() -> bool:
	"""Settle the unsettled node first by (distance, tunnels crossed) into `_settled`; false when every
	remaining node is unreachable."""
	var found := false
	for u in _count:
		if _done[u] == 0 and _dist[u] < INF and (not found or _comes_before(u, _settled)):
			_settled = u
			found = true
	if found:
		_done[_settled] = 1
	return found


func _comes_before(u: int, v: int) -> bool:
	"""Whether node u's label (distance, tunnels crossed) is strictly less than node v's."""
	return _dist[u] < _dist[v] or (_dist[u] == _dist[v] and _crossed[u] < _crossed[v])


func _relax(u: int, v: int, cost: float, via: int) -> void:
	"""Route v through u when that is strictly shorter -- or exactly as short through fewer tunnels."""
	var total := _dist[u] + cost
	var crossed := _crossed[u] + (1 if via == VIA_TUNNEL else 0)
	if total < _dist[v] or (total == _dist[v] and crossed < _crossed[v]):
		_dist[v] = total
		_prev[v] = u
		_via[v] = via
		_crossed[v] = crossed


func _refine(nav: CastNavScript, body: float, standing: PackedVector3Array, standing_count: int) -> int:
	"""Plan every surface edge on the current best path that is still a lower bound; return how many."""
	var planned := 0
	var v := GOAL
	while v != START:
		var u := _prev[v]
		var edge := u * MAX_NODES + v
		if _via[v] == VIA_SURFACE and _exact[edge] == 0:
			nav.plan(_node[u], _node[v], body, standing, standing_count, _routes[edge])
			_weight[edge] = _route_length(_node[u], _routes[edge]) if nav.last_found else INF
			_exact[edge] = 1
			planned += 1
			last_surface_plans += 1
		v = u
	return planned


static func _route_length(from: Vector2, route: PackedVector2Array) -> float:
	"""Length of a waypoint route starting at `from`."""
	var total := 0.0
	var at := from
	for point in route:
		total += at.distance_to(point)
		at = point
	return total


func _emit(out: PackedVector2Array, legs: PackedInt32Array) -> void:
	"""Write the best path's waypoints and leg codes, start-exclusive, in order."""
	out.clear()
	legs.clear()
	var steps := 0
	var v := GOAL
	while v != START:
		_chain[steps] = v
		steps += 1
		v = _prev[v]
	for k in range(steps - 1, -1, -1):
		var node := _chain[k]
		if _via[node] == VIA_TUNNEL:
			var pair := (node - FIRST_MOUTH) / 2
			out.append(_node[node])
			legs.append(leg_code(pair_slot[pair], (node - FIRST_MOUTH) % 2 == 0))
		else:
			for point in _routes[_prev[node] * MAX_NODES + node]:
				out.append(point)
				legs.append(SURFACE_LEG)
