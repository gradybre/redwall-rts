extends RefCounted
## Route planning over the surface and through the tunnel network. Decisions 0196 (live demo) and 0208
## (the network graph). Presentation only: it plans the demo cast's walks, never the simulation's.
##
## ---------------------------------------------------------------------------------------
## A SMALL GRAPH OVER THE SURFACE PLANNER. Its nodes are the trip's START and GOAL, every usable MOUTH of
## the network the walker may go in at (offered by the network, underground_graph.gd `plan`: open, fitting,
## nobody standing on it), and both ends of every water CROSSING offered. Its edges:
##   SURFACE   between any two of them, costing the length of cast_nav.gd's route between them;
##   TUNNEL    between two mouths, costing the network's cheapest walk between them for this walker
##             (graph_paths.gd: Dijkstra from each mouth, the SET-MOVE-001 §4 reference) plus the wait to
##             go in at the first (its queue, tunnel_queue.gd). A trip bound for a node UNDERGROUND
##             (`goal_node`: a dig's start, a job's place) reaches its GOAL only by such an edge, from the
##             mouth it goes in at;
##   CROSSING  between a crossing's two ends, at its own cost.
## So the network wins only when surface-to-mouth + tunnel + mouth-to-goal is SHORTER than the best walk
## without it: it is never discounted, and a tie keeps the surface -- routes are compared by (length,
## tunnels and crossings taken), so of two equally short routes the one with fewer wins, whatever order the
## search reaches them in.
##
## LAZY SURFACE COSTS. A surface plan costs far more than a graph step, so each surface edge starts at its
## straight-line length -- a lower bound on any route -- and is planned for real only when it lies on the
## current best path. The search then runs again; when the best path's surface edges are all real, it is
## optimal (every edge off it is costed no higher than its truth). By the triangle inequality the first best
## path is always the direct start -> goal edge, so a trip no tunnel can shorten costs one surface plan.
##
## CROSSINGS (demo/waterplay/): a finished bridge, or a swimmer's link across the stream, offered as a pair
## of ends (`add_crossing`) at its own cost in metres-at-walk-speed; at most MAX_CROSSING_PAIRS a plan.
##
## WEATHER, LANTERNS AND QUEUES (demo). Costs are compared as WALKING TIME in metres-at-walk-speed: a
## surface edge is its length times 1000 / `surface_permille` (the weather's), while a tunnel edge -- dry and
## sheltered -- is the network's walk (already over each bore's speed: a lit one is quicker). A surface leg
## through wading water costs its wet stretch at the wading pace (`wade_cost`). Cached routes keep their
## plain lengths; the weather is applied as they are read, so a change of weather never drops the cache.
##
## MOUTH-TO-MOUTH SURFACE ROUTES ARE CACHED, per walker body and network revision (and crossing revision),
## round the obstacles alone (`_caches`). A cached route on the best path is checked against the residents
## standing NOW before it is used (cheap segment tests), and planned afresh round them when one is in its way.
##
## LEG CODES. Each waypoint carries how it was reached: SURFACE_LEG; a SEGMENT walked end to end
## (`leg_code(slot, reversed)`, reversed: from its node B to its node A); or a CROSSING (`crossing_code`, above
## every segment's). A tunnel edge is emitted as one waypoint per segment walked -- each node on the way, the
## last the mouth it comes up at (or the underground goal) -- so the brain walks the leg list segment by
## segment (resident_brain.gd TUNNELS).
##
## Waypoints are emitted without repeats. Allocation: every column is sized once in _init(); a plan reuses
## them. A cache is allocated the first time a body radius plans.

const CastNavScript := preload("res://demo/cast/cast_nav.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const PathsScript := preload("res://demo/tunnel/graph_paths.gd")

const START: int = 0
const GOAL: int = 1
const FIRST_STOP: int = 2
## Crossings offered to one plan (see CROSSINGS).
const MAX_CROSSING_PAIRS: int = 8
const MAX_NODES: int = FIRST_STOP + Rules.MAX_MOUTHS + 2 * MAX_CROSSING_PAIRS
## Cache keys: a stop's key times this plus the other's. A mouth's key is its row; a crossing end's
## MAX_MOUTHS + 2 x row + end.
const MOUTH_KEY: int = 1 << 16
const VIA_SURFACE: int = 0
const VIA_TUNNEL: int = 1
const VIA_CROSSING: int = 2
## Leg code for a waypoint reached on the surface (see LEG CODES).
const SURFACE_LEG: int = -1
## Edge states: a straight-line lower bound, planned for this trip, or taken from the cache and not yet
## checked against the residents standing now.
const EDGE_BOUND: int = 0
const EDGE_EXACT: int = 1
const EDGE_CACHED: int = 2
## Two waypoints closer than this are one.
const SAME_POINT_M: float = 1e-4


## One body radius's stop-to-stop surface routes for one revision, keyed by stop keys.
class MouthCache:
	extends RefCounted
	var revision: int = -1
	var weight: Dictionary = {}
	var routes: Dictionary = {}

	func knows(key: int) -> bool:
		"""Whether the route under `key` was planned for this revision."""
		return weight.has(key)

	func forget() -> void:
		"""Drop every route (a new revision)."""
		weight.clear()
		routes.clear()


## How many mouths and crossings this plan offers.
var mouth_count: int = 0
var crossing_count: int = 0
## Surface walking speed per mille (see WEATHER, LANTERNS AND QUEUES).
var surface_permille: int = 1000
## `(a: Vector2, b: Vector2) -> float`: a surface leg's extra metres for wading water on it (the water's
## crossing hook; none: no water).
var wade_cost: Callable = Callable()
## Surface plans run by the last plan, and stop-to-stop routes it took from the cache.
var last_surface_plans: int = 0
var last_cache_hits: int = 0

## Per stop: where it stands, its cache key, its mouth row (-1: a crossing end), the wait to go in at it
## (m), its partner and the partner edge's cost (a crossing end's; -1 and 0 for a mouth).
var _node: PackedVector2Array = PackedVector2Array()
var _key: PackedInt32Array = PackedInt32Array()
var _mouth: PackedInt32Array = PackedInt32Array()
var _wait: PackedFloat32Array = PackedFloat32Array()
var _partner: PackedInt32Array = PackedInt32Array()
var _partner_cost: PackedFloat32Array = PackedFloat32Array()
var _count: int = 0
var _graph: GraphScript = null
var _class: int = PathsScript.CLASS_NONE
var _goal_node: int = -1
var _tunnel_cost: PackedFloat32Array = PackedFloat32Array()
var _weight: PackedFloat32Array = PackedFloat32Array()
var _exact: PackedByteArray = PackedByteArray()
var _routes: Array[PackedVector2Array] = []
var _dist: PackedFloat32Array = PackedFloat32Array()
var _prev: PackedInt32Array = PackedInt32Array()
var _via: PackedByteArray = PackedByteArray()
var _crossed: PackedInt32Array = PackedInt32Array()
var _done: PackedByteArray = PackedByteArray()
var _chain: PackedInt32Array = PackedInt32Array()
var _segments: PackedInt32Array = PackedInt32Array()
var _settled: int = START
var _caches: Dictionary = {}
var _cache: MouthCache = null
var _nav: CastNavScript = null
var _body: float = 0.0
var _standing: PackedVector3Array = PackedVector3Array()
var _standing_count: int = 0


func _init() -> void:
	"""Size every column for MAX_NODES once."""
	for column: PackedVector2Array in [_node]:
		column.resize(MAX_NODES)
	for column: PackedInt32Array in [_key, _mouth, _partner, _prev, _crossed, _chain]:
		column.resize(MAX_NODES)
	for column: PackedFloat32Array in [_wait, _partner_cost, _dist]:
		column.resize(MAX_NODES)
	_via.resize(MAX_NODES)
	_done.resize(MAX_NODES)
	_tunnel_cost.resize(MAX_NODES * MAX_NODES)
	_weight.resize(MAX_NODES * MAX_NODES)
	_exact.resize(MAX_NODES * MAX_NODES)
	_routes.resize(MAX_NODES * MAX_NODES)
	for i in _routes.size():
		_routes[i] = PackedVector2Array()


func clear_pairs() -> void:
	"""Forget the mouths and crossings offered to the next plan."""
	mouth_count = 0
	crossing_count = 0
	_count = FIRST_STOP
	_graph = null
	_class = PathsScript.CLASS_NONE


func use_paths(graph: GraphScript, fit_class: int) -> void:
	"""The network (and the walker's fit class) whose paths cost the tunnel edges of the next plan."""
	_graph = graph
	_class = fit_class


func add_mouth(m: int, at: Vector2, wait_m: float) -> void:
	"""Offer mouth row `m` of the network standing at `at`, with the wait to go in there (INF: that way in
	is closed). At most Rules.MAX_MOUTHS."""
	var u := _count
	_node[u] = at
	_key[u] = m
	_mouth[u] = m
	_wait[u] = wait_m
	_partner[u] = -1
	_count += 1
	mouth_count += 1


func add_crossing(row: int, end_a: Vector2, end_b: Vector2, cost_m: float) -> bool:
	"""Offer crossing `row` of the water's table between its two land ends at `cost_m` metres-at-walk-speed,
	either way. False (nothing offered) once MAX_CROSSING_PAIRS are offered to this plan."""
	if crossing_count >= MAX_CROSSING_PAIRS or row < 0:
		return false
	for end in 2:
		var u := _count + end
		_node[u] = end_b if end == 1 else end_a
		_key[u] = Rules.MAX_MOUTHS + 2 * row + end
		_mouth[u] = -1
		_wait[u] = 0.0
		_partner[u] = _count + 1 - end
		_partner_cost[u] = cost_m
	_count += 2
	crossing_count += 1
	return true


static func leg_code(slot: int, reverse: bool) -> int:
	"""The leg code for walking segment `slot` end to end (node A to B, or B to A when `reverse`)."""
	return slot * 2 + (1 if reverse else 0)


static func crossing_code(row: int, reverse: bool) -> int:
	"""The leg code for crossing `row` of the water's table (end a to b, or b to a when `reverse`)."""
	return leg_code(Rules.MAX_SEGMENTS + row, reverse)


static func leg_slot(code: int) -> int:
	"""The segment (or MAX_SEGMENTS + crossing row) a leg code walks."""
	return code >> 1


static func leg_reversed(code: int) -> bool:
	"""Whether a leg code walks its segment from node B to node A (a crossing from end b to a)."""
	return code & 1 == 1


static func is_crossing_code(code: int) -> bool:
	"""Whether a leg code crosses one of the water's crossings rather than walking a segment."""
	return code >= 0 and leg_slot(code) >= Rules.MAX_SEGMENTS


static func crossing_row(code: int) -> int:
	"""The crossing-table row a crossing leg code crosses."""
	return leg_slot(code) - Rules.MAX_SEGMENTS


func plan(nav: CastNavScript, from: Vector2, to: Vector2, body: float, standing: PackedVector3Array,
		standing_count: int, revision: int, out: PackedVector2Array, legs: PackedInt32Array,
		goal_node: int = -1) -> bool:
	"""Fill `out` with waypoints from `from` (excluded) to `to` (last) and `legs` with each waypoint's leg code,
	round the first `standing_count` standing residents in `standing`; `revision` keys the cache. With
	`goal_node` >= 0 the goal is that network node, reached only through the network. True when a route was
	found; otherwise (a surface goal) the surface planner's straight-line fallback is written, or (a goal
	underground) nothing."""
	_begin(nav, body, standing, standing_count, revision)
	_goal_node = goal_node if _graph != null else -1
	_reset(from, to)
	for round_index in MAX_NODES * MAX_NODES + 1:
		_search()
		if _dist[GOAL] == INF:
			break
		if _refine() == 0:
			_emit(out, legs)
			_release()
			return true
	_fallback(from, to, out, legs, goal_node >= 0)
	_release()
	return false


func _release() -> void:
	"""Let go of this plan's network and surface planner. The network owns this router, so holding it past the
	plan is a reference cycle that kept both alive after the world dropped them (decision 0501)."""
	_graph = null
	_nav = null


func _fallback(from: Vector2, to: Vector2, out: PackedVector2Array, legs: PackedInt32Array, below: bool) -> void:
	"""No route: nothing for a goal underground, else the surface planner's straight-line fallback."""
	out.clear()
	legs.clear()
	if below:
		return
	_nav.plan(from, to, _body, _standing, _standing_count, out)
	legs.resize(out.size())
	legs.fill(SURFACE_LEG)


func _begin(nav: CastNavScript, body: float, standing: PackedVector3Array, standing_count: int, revision: int) -> void:
	"""Hold this plan's inputs and pick (or start) the cache for this body and revision."""
	_nav = nav
	_body = body
	_standing = standing
	_standing_count = standing_count
	var key := roundi(body * 1000.0)
	if not _caches.has(key):
		_caches[key] = MouthCache.new()
	_cache = _caches[key]
	if _cache.revision != revision:
		_cache.revision = revision
		_cache.forget()
	last_surface_plans = 0
	last_cache_hits = 0


func _reset(from: Vector2, to: Vector2) -> void:
	"""This plan's nodes, every surface edge at its straight-line lower bound -- or, between two stops, at
	its cached length when the cache has it -- and every tunnel edge from the network's paths."""
	_node[START] = from
	_node[GOAL] = to
	_mouth[START] = -1
	_mouth[GOAL] = -1
	for u in _count:
		for v in _count:
			var edge := u * MAX_NODES + v
			_weight[edge] = _node[u].distance_to(_node[v]) * _surface_scale()
			_exact[edge] = EDGE_BOUND
			if u >= FIRST_STOP and v >= FIRST_STOP and _cache.knows(_cache_index(u, v)):
				_weight[edge] = _cache.weight[_cache_index(u, v)] * _surface_scale()
				_exact[edge] = EDGE_CACHED
			_tunnel_cost[edge] = _walk_m(u, v)


func _walk_m(u: int, v: int) -> float:
	"""The tunnel edge u -> v in metres-at-walk-speed: the network's walk from mouth u to mouth v (or to the
	underground goal) plus the wait to go in at u; INF where there is none."""
	if _graph == null or _mouth[u] < 0 or u == v:
		return INF
	var target := _goal_node if v == GOAL else (_graph.mouth_node[_mouth[v]] if _mouth[v] >= 0 else -1)
	if target < 0:
		return INF
	var walk := _graph.paths.dist_u(_graph, _class, _mouth[u], target)
	if walk >= PathsScript.UNREACHED:
		return INF
	return Rules.to_m(walk) + _wait[u]


func _surface_scale() -> float:
	"""How much longer a metre on the surface counts than a metre at walk speed (the weather's)."""
	return float(Rules.PERMILLE) / float(maxi(surface_permille, 1))


func _cache_index(u: int, v: int) -> int:
	"""Where the surface route from stop u to stop v lives in the cache."""
	return _key[u] * MOUTH_KEY + _key[v]


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
		_relax_all(u)


func _relax_all(u: int) -> void:
	"""Relax every edge out of settled node u: the surface (not into a goal underground), its tunnels, and a
	crossing end's partner."""
	for v in _count:
		if v == START or v == u or _done[v] == 1:
			continue
		if not (v == GOAL and _goal_node >= 0):
			_relax(u, v, _weight[u * MAX_NODES + v], VIA_SURFACE)
		if _tunnel_cost[u * MAX_NODES + v] < INF:
			_relax(u, v, _tunnel_cost[u * MAX_NODES + v], VIA_TUNNEL)
	var partner := _partner[u] if u >= FIRST_STOP else -1
	if partner >= 0 and _done[partner] == 0:
		_relax(u, partner, _partner_cost[u], VIA_CROSSING)


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
	var crossed := _crossed[u] + (0 if via == VIA_SURFACE else 1)
	if total < _dist[v] or (total == _dist[v] and crossed < _crossed[v]):
		_dist[v] = total
		_prev[v] = u
		_via[v] = via
		_crossed[v] = crossed


func _refine() -> int:
	"""Make every surface edge on the current best path real: plan a lower bound, check a cached route
	against the residents standing now. Returns how many edges changed."""
	var changed := 0
	var v := GOAL
	while v != START:
		var u := _prev[v]
		var edge := u * MAX_NODES + v
		if _via[v] == VIA_SURFACE and _exact[edge] != EDGE_EXACT:
			changed += _make_exact(u, v, edge)
		v = u
	return changed


func _make_exact(u: int, v: int, edge: int) -> int:
	"""One surface edge made real for this trip; returns 1 when its weight changed, else 0 (a cached route
	still clear was already costed at its length)."""
	var before := _weight[edge]
	var between_stops := u >= FIRST_STOP and v >= FIRST_STOP
	if between_stops and _exact[edge] == EDGE_BOUND:
		_plan_into_cache(u, v)
	if between_stops and _cached_route_clear(u, v):
		_copy_route(_cache.routes[_cache_index(u, v)], _routes[edge])
		_weight[edge] = _cache.weight[_cache_index(u, v)] * _surface_scale()
		last_cache_hits += 1
	else:
		_plan_edge(u, v, _standing_count, _routes[edge])
		_weight[edge] = _route_cost(_node[u], _routes[edge]) * _surface_scale() if _nav.last_found else INF
	_exact[edge] = EDGE_EXACT
	return 1 if _weight[edge] != before else 0


func _plan_into_cache(u: int, v: int) -> void:
	"""Plan stop u -> stop v round the obstacles alone, and keep it for this revision."""
	var k := _cache_index(u, v)
	var route := PackedVector2Array()
	_plan_edge(u, v, 0, route)
	_cache.routes[k] = route
	_cache.weight[k] = _route_cost(_node[u], route) if _nav.last_found else INF


func _plan_edge(u: int, v: int, count: int, route: PackedVector2Array) -> void:
	"""One surface plan from node u to node v round the first `count` standing residents."""
	_nav.plan(_node[u], _node[v], _body, _standing, count, route)
	last_surface_plans += 1


func _cached_route_clear(u: int, v: int) -> bool:
	"""Whether the cached stop u -> stop v route exists and no resident standing now is in its way (inflated
	as the surface planner inflates them, shrunk to leave both stops outside)."""
	var k := _cache_index(u, v)
	if _cache.weight[k] == INF:
		return true
	var at := _node[u]
	for point in _cache.routes[k]:
		for s in _standing_count:
			var r := CastNavScript.inflated(_standing[s], _body, CastNavScript.LINK_MARGIN_M, _node[u], _node[v], true)
			if r > 0.0 and CastNavScript.distance_to_segment(Vector2(_standing[s].x, _standing[s].z), at, point) < r - 1e-4:
				return false
		at = point
	return true


static func _copy_route(from: PackedVector2Array, into: PackedVector2Array) -> void:
	"""Copy a cached route into this trip's own array. Packed arrays are shared by reference, so the trip's
	slot must never BE the cached array: the next plan into the slot would overwrite the cache."""
	into.resize(from.size())
	for i in from.size():
		into[i] = from[i]


func _route_cost(from: Vector2, route: PackedVector2Array) -> float:
	"""A waypoint route's walking cost from `from`: its length, and more for any wading water on it."""
	var total := 0.0
	var at := from
	for point in route:
		total += at.distance_to(point)
		if wade_cost.is_valid():
			total += float(wade_cost.call(at, point))
		at = point
	return total


func _emit(out: PackedVector2Array, legs: PackedInt32Array) -> void:
	"""Write the best path's waypoints and leg codes, start-exclusive, in order (see LEG CODES)."""
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
		match _via[node]:
			VIA_TUNNEL:
				_emit_tunnel(_prev[node], node, out, legs)
			VIA_CROSSING:
				out.append(_node[node])
				@warning_ignore("integer_division") legs.append(crossing_code((_key[node] - Rules.MAX_MOUTHS) / 2, (_key[node] - Rules.MAX_MOUTHS) % 2 == 0))
			_:
				_emit_surface(_routes[_prev[node] * MAX_NODES + node], out, legs)


func _emit_surface(route: PackedVector2Array, out: PackedVector2Array, legs: PackedInt32Array) -> void:
	"""A surface edge's waypoints, dropping one that repeats the waypoint before it."""
	for point in route:
		if out.is_empty() or out[out.size() - 1].distance_to(point) > SAME_POINT_M:
			out.append(point)
			legs.append(SURFACE_LEG)


func _emit_tunnel(u: int, v: int, out: PackedVector2Array, legs: PackedInt32Array) -> void:
	"""A tunnel edge from mouth u to mouth v (or the goal underground): one waypoint per segment walked."""
	var target := _goal_node if v == GOAL else _graph.mouth_node[_mouth[v]]
	_graph.paths.path_into(_graph, _class, _mouth[u], target, _segments)
	var at := _graph.mouth_node[_mouth[u]]
	for slot in _segments:
		var reverse := _graph.node_a[slot] != at
		at = _graph.other_end(slot, at)
		out.append(_graph.node_m(at))
		legs.append(leg_code(slot, reverse))
