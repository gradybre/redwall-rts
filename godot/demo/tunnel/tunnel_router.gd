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
##
## WEATHER, LANTERNS AND QUEUES (demo). Costs are compared as WALKING TIME in metres-at-walk-speed:
## every surface edge is its length times 1000 / `surface_permille` (the weather's surface speed;
## demo_weather.gd), while a tunnel edge -- dry and sheltered -- is its cost as offered (add_pair:
## already divided by its own bore speed, faster when lit). So in rain or snow a tunnel wins trips
## it would lose in the sun. Entering a tunnel at a mouth with a queue also costs that mouth's wait
## (tunnel_queue.gd). Cached routes keep their plain lengths; the weather is applied as they are
## read, so a change of weather never invalidates the cache.
##
## MOUTH-TO-MOUTH ROUTES ARE CACHED. Between two mouths the ground does not change until a tunnel
## is added or changes phase -- tunnel_network.revision -- so each walker body's mouth-to-mouth
## surface routes are planned once per revision, round the obstacles and the mouths only, and kept
## (`_caches`, one per body radius), round the obstacles alone. A trip then plans only START ->
## mouths and mouths -> GOAL. A cached route on the best path is checked against the residents
## standing NOW before it is used (cheap segment tests), and planned afresh for this trip, round
## them, when one of them is in its way.
##
## Waypoints are emitted without repeats: a goal exactly on a mouth ends the route at the mouth.
## Allocation: every column is sized once in _init(); a plan reuses them. A cache is allocated the
## first time a body radius plans.

const CastNavScript := preload("res://demo/cast/cast_nav.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")

const START: int = 0
const GOAL: int = 1
const FIRST_MOUTH: int = 2
const MAX_NODES: int = FIRST_MOUTH + 2 * Rules.MAX_TUNNELS
const MOUTHS: int = 2 * Rules.MAX_TUNNELS
const VIA_SURFACE: int = 0
const VIA_TUNNEL: int = 1
## Leg code for a waypoint reached on the surface (see `leg_code`).
const SURFACE_LEG: int = -1
## Edge states: a straight-line lower bound, planned for this trip, or taken from the cache and not
## yet checked against the residents standing now.
const EDGE_BOUND: int = 0
const EDGE_EXACT: int = 1
const EDGE_CACHED: int = 2
## Two waypoints closer than this are one.
const SAME_POINT_M: float = 1e-4


## One body radius's mouth-to-mouth routes for one network revision.
class MouthCache:
	extends RefCounted
	var revision: int = -1
	var known: PackedByteArray = PackedByteArray()
	var weight: PackedFloat32Array = PackedFloat32Array()
	var routes: Array[PackedVector2Array] = []

	func _init() -> void:
		"""Size the columns for every ordered pair of mouths once."""
		known.resize(MOUTHS * MOUTHS)
		weight.resize(MOUTHS * MOUTHS)
		routes.resize(MOUTHS * MOUTHS)
		for i in routes.size():
			routes[i] = PackedVector2Array()


## The open tunnels this plan may use: slot, the mouths, and the cost underground.
var pair_count: int = 0
var pair_slot: PackedInt32Array = PackedInt32Array()
var pair_length_m: PackedFloat32Array = PackedFloat32Array()
## The wait (m of walking) to enter each offered tunnel at its mouth a and at its mouth b.
var pair_wait_m: PackedFloat32Array = PackedFloat32Array()
## Surface walking speed per mille (see WEATHER, LANTERNS AND QUEUES).
var surface_permille: int = 1000
## Surface plans run by the last plan, and mouth-to-mouth routes it took from the cache.
var last_surface_plans: int = 0
var last_cache_hits: int = 0

var _node: PackedVector2Array = PackedVector2Array()
var _mouth_id: PackedInt32Array = PackedInt32Array()
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
var _caches: Dictionary = {}
var _cache: MouthCache = null
var _nav: CastNavScript = null
var _body: float = 0.0
var _standing: PackedVector3Array = PackedVector3Array()
var _standing_count: int = 0


func _init() -> void:
	"""Size every column for MAX_NODES once."""
	pair_slot.resize(Rules.MAX_TUNNELS)
	pair_length_m.resize(Rules.MAX_TUNNELS)
	pair_wait_m.resize(2 * Rules.MAX_TUNNELS)
	_node.resize(MAX_NODES)
	_mouth_id.resize(MAX_NODES)
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


func add_pair(slot: int, mouth_a: Vector2, mouth_b: Vector2, length_m: float, wait_a_m: float = 0.0,
		wait_b_m: float = 0.0) -> void:
	"""Offer one open tunnel: its slot, its two mouths, its cost and the wait to enter it at each
	mouth (INF: that way in is closed). At most MAX_TUNNELS."""
	pair_slot[pair_count] = slot
	pair_length_m[pair_count] = length_m
	pair_wait_m[2 * pair_count] = wait_a_m
	pair_wait_m[2 * pair_count + 1] = wait_b_m
	_node[FIRST_MOUTH + 2 * pair_count] = mouth_a
	_node[FIRST_MOUTH + 2 * pair_count + 1] = mouth_b
	_mouth_id[FIRST_MOUTH + 2 * pair_count] = 2 * slot
	_mouth_id[FIRST_MOUTH + 2 * pair_count + 1] = 2 * slot + 1
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
		standing_count: int, revision: int, out: PackedVector2Array, legs: PackedInt32Array) -> bool:
	"""Fill `out` with waypoints from `from` (excluded) to `to` (last) and `legs` with each waypoint's
	leg code (SURFACE_LEG, or a tunnel crossed to reach it), round the first `standing_count`
	standing residents in `standing`; `revision` is the network's. True when a route was found;
	otherwise the surface planner's straight-line fallback is written, as cast_nav.gd does without
	tunnels."""
	_begin(nav, body, standing, standing_count, revision)
	_reset(from, to)
	for round_index in MAX_NODES * MAX_NODES + 1:
		_search()
		if _dist[GOAL] == INF:
			break
		if _refine() == 0:
			_emit(out, legs)
			return true
	nav.plan(from, to, body, standing, standing_count, out)
	legs.resize(out.size())
	legs.fill(SURFACE_LEG)
	return false


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
		_cache.known.fill(0)
	last_surface_plans = 0
	last_cache_hits = 0


func _reset(from: Vector2, to: Vector2) -> void:
	"""This plan's nodes, every surface edge at its straight-line lower bound -- or, between two
	mouths, at its cached length when the cache has it."""
	_node[START] = from
	_node[GOAL] = to
	_count = FIRST_MOUTH + 2 * pair_count
	for u in _count:
		for v in _count:
			var edge := u * MAX_NODES + v
			_weight[edge] = _node[u].distance_to(_node[v]) * _surface_scale()
			_exact[edge] = EDGE_BOUND
			if u >= FIRST_MOUTH and v >= FIRST_MOUTH and _cache.known[_cache_index(u, v)] == 1:
				_weight[edge] = _cache.weight[_cache_index(u, v)] * _surface_scale()
				_exact[edge] = EDGE_CACHED


func _surface_scale() -> float:
	"""How much longer a metre on the surface counts than a metre at walk speed (the weather's)."""
	return float(Rules.PERMILLE) / float(maxi(surface_permille, 1))


func _cache_index(u: int, v: int) -> int:
	"""Where the route from mouth node u to mouth node v lives in the cache."""
	return _mouth_id[u] * MOUTHS + _mouth_id[v]


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
			_relax(u, _partner(u), pair_length_m[(u - FIRST_MOUTH) / 2] + pair_wait_m[u - FIRST_MOUTH], VIA_TUNNEL)


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


func _refine() -> int:
	"""Make every surface edge on the current best path real: plan a lower bound, check a cached
	route against the residents standing now. Returns how many edges changed."""
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
	"""One surface edge made real for this trip; returns 1 when its weight changed, else 0 (a cached
	route that is still clear was already costed at its length)."""
	var before := _weight[edge]
	var between_mouths := u >= FIRST_MOUTH and v >= FIRST_MOUTH
	if between_mouths and _exact[edge] == EDGE_BOUND:
		_plan_into_cache(u, v)
	if between_mouths and _cached_route_clear(u, v):
		_copy_route(_cache.routes[_cache_index(u, v)], _routes[edge])
		_weight[edge] = _cache.weight[_cache_index(u, v)] * _surface_scale()
		last_cache_hits += 1
	else:
		_plan_edge(u, v, _standing_count, _routes[edge])
		_weight[edge] = _route_length(_node[u], _routes[edge]) * _surface_scale() if _nav.last_found else INF
	_exact[edge] = EDGE_EXACT
	return 1 if _weight[edge] != before else 0


func _plan_into_cache(u: int, v: int) -> void:
	"""Plan mouth u -> mouth v round the obstacles alone, and keep it for this revision."""
	var k := _cache_index(u, v)
	_plan_edge(u, v, 0, _cache.routes[k])
	_cache.weight[k] = _route_length(_node[u], _cache.routes[k]) if _nav.last_found else INF
	_cache.known[k] = 1


func _plan_edge(u: int, v: int, count: int, route: PackedVector2Array) -> void:
	"""One surface plan from node u to node v round the first `count` standing residents."""
	_nav.plan(_node[u], _node[v], _body, _standing, count, route)
	last_surface_plans += 1


func _cached_route_clear(u: int, v: int) -> bool:
	"""Whether the cached mouth u -> mouth v route exists and no resident standing now is in its way
	(inflated as the surface planner inflates them, shrunk to leave both mouths outside)."""
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
	"""Copy a cached route into this trip's own array. Packed arrays are shared by reference, so the
	trip's slot must never BE the cached array: the next plan into the slot would overwrite the cache."""
	into.resize(from.size())
	for i in from.size():
		into[i] = from[i]


static func _route_length(from: Vector2, route: PackedVector2Array) -> float:
	"""Length of a waypoint route starting at `from`."""
	var total := 0.0
	var at := from
	for point in route:
		total += at.distance_to(point)
		at = point
	return total


func _emit(out: PackedVector2Array, legs: PackedInt32Array) -> void:
	"""Write the best path's waypoints and leg codes, start-exclusive, in order, dropping a surface
	waypoint that repeats the one before it."""
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
			out.append(_node[node])
			legs.append(leg_code(pair_slot[(node - FIRST_MOUTH) / 2], (node - FIRST_MOUTH) % 2 == 0))
			continue
		for point in _routes[_prev[node] * MAX_NODES + node]:
			if out.is_empty() or out[out.size() - 1].distance_to(point) > SAME_POINT_M:
				out.append(point)
				legs.append(SURFACE_LEG)
