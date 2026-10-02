extends RefCounted
## Route planning for the demo cast round obstacle circles and standing residents. Decision 0196.
##
## ---------------------------------------------------------------------------------------
## BUILT ONCE, PLANNED CHEAPLY. The obstacle circles are bucketed in a grid, so a segment or a point
## is tested only against the circles near it. Each body class (body radius rounded UP to
## CLASS_STEP_M, so the graph is never narrower than the walker) gets one static visibility graph
## (cast_nav_graph.gd), built when its first resident joins. A plan adds only its start, its goal
## and rings round the residents standing still, and searches with A* on a binary heap. Static
## edges were proven clear when the graph was built; one is re-tested against standing residents
## only when one of its ends lies close enough to a standing resident for the edge to reach it.
##
## INFLATION AND THE GOAL SHRINK. On the static graph a walker's centre keeps out of each circle's
## radius plus its class radius plus PLAN_MARGIN_M, which keeps routes comfortably wide. Edges a
## plan adds itself (from its start, to its goal, round standing residents) use the walker's own
## body radius plus only LINK_MARGIN_M -- what the per-frame constraint actually allows -- so a
## badger can still leave a slot in a pocket whose exits are wider than it but narrower than its
## padded class. Those edges also shrink every circle to leave the start and goal just outside it,
## so a POI tucked against a building stays reachable. And because a slot can sit in a pocket the
## padded graph never enters, the circles within LOCAL_RING_M of the start and the goal get their
## own ring of plan nodes at that tighter inflation, to find the way out.
##
## THE PLANNING AREA (`area`). No node of a graph or a plan's own rings is placed outside it, so no
## route leaves it: the water's bands (demo/waterplay/) reach past its edge, and a band whose far end
## lay inside it could be walked round. Unbounded by default. Set it before the first graph is built.
##
## REBUILT IN SLICES (decision 0209). New circles (`setup`: a spoil heap or a room's mound came, grew or went)
## leave each body class's graph in use while its replacement is built a slice a frame (`advance_builds`, from
## the cast's frame, BUILD_BUDGET_USEC) and swapped in when it is done: a class's graph costs tens of
## milliseconds in the village, which the frame that first planned for that class used to pay whole. Meanwhile
## a plan routes over the graph as it was, but no route passes a circle added since: the plan's own start, goal
## and rings test every circle, and its graph's edges and nodes are tested against the few circles new since that
## graph was built (`_fresh`, found once a setup). A class's first graph is still built at once.
##
## REACHABILITY BY ONE SWEEP (decision 0361, the review's F06). A formation, or a crew looking for a spot beside its
## work, asks of a dozen candidate spots whether a route reaches each from one start (cast_orders.gd `spot_ok`): one A*
## a spot cost a click up to 17 ms, and one that no route reaches cost a whole graph's search (5 ms). `reaches()`
## instead sweeps everything a route from that start reaches -- once, kept for that start, body class and set of
## circles -- and answers a spot by a link from it to a node the sweep reached, or through the plan's own nodes round
## the circles by it (its pocket), each tested exactly as the plan tests its goal's links. A yes is never wrong (the plan
## would find that very route). A no can differ from the plan's answer in two rare corners: the plan shrinks the circles
## by its goal for its start's links too, so a start link the spot's own nearness clears is not tried; and the plan's
## own nodes round the goal are followed only among themselves and from what the sweep reached, so a route that leaves
## the goal's pocket into ground the sweep never reached and comes back is not found. Such a spot is refused, as an
## unreachable one is. The sweep is kept for one start, one body (its links use the body's own radius) and one graph.
##
## The sweep itself reads the static graph's CONNECTED PARTS (labelled once per graph, `_label_parts`): what a route
## from the start reaches is every part one of the start's own links reaches, and through the plan's nodes round the
## start, the parts they link to in turn -- the same links, closed over, as the plan's search would make. While a
## graph is being rebuilt round new circles its parts may be cut by them, so it then sweeps by the search itself.
##
## Nothing here allocates during a plan beyond the heap's first growth; the grid queries write into
## member arrays sized at setup.

const CastGridScript := preload("res://demo/cast/cast_grid.gd")
const GraphScript := preload("res://demo/cast/cast_nav_graph.gd")

const PLAN_MARGIN_M: float = 0.18
const LINK_MARGIN_M: float = 0.05
const GOAL_EPSILON_M: float = 0.03
const CLASS_STEP_M: float = 0.1
const CIRCLE_CELL_M: float = 2.0
## How far a plan's own nodes (start, goal, standing rings) reach for a link.
const LINK_M: float = 9.0
## How far a local ring node (round a circle by the start or goal, or round a standing resident)
## reaches for a link: they are for detours, not for crossing the map.
const LOCAL_LINK_M: float = 4.0
const STANDING_RING: int = 6
const LOCAL_RING_M: float = 1.5
## How long the rebuilds may take a frame (see REBUILT IN SLICES).
const BUILD_BUDGET_USEC: int = 1500

var circles: PackedVector3Array = PackedVector3Array()
var max_radius: float = 0.0
## The planning area (see THE PLANNING AREA); nodes outside it are not placed.
var area: Rect2 = Rect2(-1e6, -1e6, 2e6, 2e6)
## Plan statistics, for measurement: nodes expanded and whether a route was found.
var last_expanded: int = 0
var last_found: bool = false

var _grid: CastGridScript = CastGridScript.new()
var _hits: PackedInt32Array = PackedInt32Array()
var _graphs: Dictionary = {}
## The graphs being rebuilt (class key -> graph) and their keys, in the order they are carried on.
var _building: Dictionary = {}
var _build_keys: PackedInt32Array = PackedInt32Array()
## Per class being rebuilt, the circles its graph in use was not built from (see REBUILT IN SLICES); and those
## of the graph this plan uses.
var _fresh_by_class: Dictionary = {}
var _fresh: PackedVector3Array = PackedVector3Array()
var _graph: GraphScript = null
var _body: float = 0.0
var _link_body: float = 0.0
var _start: Vector2 = Vector2.ZERO
var _goal: Vector2 = Vector2.ZERO
var _standing: PackedVector3Array = PackedVector3Array()
var _standing_count: int = 0
var _dynamic: PackedVector2Array = PackedVector2Array()
var _cost: PackedFloat32Array = PackedFloat32Array()
var _parent: PackedInt32Array = PackedInt32Array()
var _closed: PackedByteArray = PackedByteArray()
var _heap_f: PackedFloat32Array = PackedFloat32Array()
var _heap_n: PackedInt32Array = PackedInt32Array()
var _heap_size: int = 0
var _node_hits: PackedInt32Array = PackedInt32Array()
var _chain: PackedInt32Array = PackedInt32Array()
var _local: PackedInt32Array = PackedInt32Array()
var _dynamic_reach: PackedFloat32Array = PackedFloat32Array()
var _plan_id: int = 0
## The last reachability sweep (see REACHABILITY BY ONE SWEEP): whether one stands, its start, the graph it swept, the
## static nodes it reached and the plan's own nodes (round the start) it reached.
var _swept: bool = false
var _swept_from: Vector2 = Vector2.INF
var _swept_graph: GraphScript = null
var _swept_body: float = -1.0
var _pocket_queue: PackedInt32Array = PackedInt32Array()
var _swept_static: PackedByteArray = PackedByteArray()
var _swept_points: PackedVector2Array = PackedVector2Array()
var _no_standing: PackedVector3Array = PackedVector3Array()
## The connected parts of a graph's static edges (see REACHABILITY BY ONE SWEEP): per node its part, how many parts,
## the graph they were labelled for; and the sweep's scratch -- parts reached, and the plan's own nodes reached and
## linked from.
var _part: PackedInt32Array = PackedInt32Array()
var _part_count: int = 0
var _part_graph: GraphScript = null
var _part_reached: PackedByteArray = PackedByteArray()
var _own_reached: PackedByteArray = PackedByteArray()
var _own_done: PackedByteArray = PackedByteArray()
var _part_queue: PackedInt32Array = PackedInt32Array()


func setup(obstacles: PackedVector3Array) -> void:
	"""Take the circles (x, radius, z) and bucket them. Each class's graph is rebuilt in slices (see REBUILT IN
	SLICES); a class never planned for gets its graph when it first does."""
	circles = obstacles
	_swept = false
	max_radius = 0.0
	var centres := PackedVector2Array()
	for circle in circles:
		max_radius = maxf(max_radius, circle.y)
		centres.append(Vector2(circle.x, circle.z))
	_grid.build(centres, CIRCLE_CELL_M)
	_hits.resize(circles.size())
	_building.clear()
	_build_keys.clear()
	_fresh_by_class.clear()
	for key: int in _graphs:
		var graph := GraphScript.new()
		graph.begin(self, float(key) * CLASS_STEP_M, PLAN_MARGIN_M)
		_building[key] = graph
		_build_keys.append(key)


static func body_class(body_radius: float) -> float:
	"""The body radius a graph is built for: rounded up to CLASS_STEP_M, never narrower."""
	return ceilf(body_radius / CLASS_STEP_M - 1e-4) * CLASS_STEP_M


func ensure_graph(body_radius: float) -> GraphScript:
	"""The static graph for this body's class, built the first time it is asked for."""
	var key := roundi(body_class(body_radius) / CLASS_STEP_M)
	if not _graphs.has(key):
		var graph := GraphScript.new()
		graph.build(self, body_class(body_radius), PLAN_MARGIN_M)
		_graphs[key] = graph
	return _graphs[key]


func advance_builds(budget_usec: int) -> void:
	"""Carry the graphs being rebuilt on for about `budget_usec` microseconds in all, swapping each in when it is
	done (see REBUILT IN SLICES)."""
	var until := Time.get_ticks_usec() + budget_usec
	while not _build_keys.is_empty() and Time.get_ticks_usec() < until:
		var key := _build_keys[0]
		var graph: GraphScript = _building[key]
		if graph.step(self, until - Time.get_ticks_usec()):
			_graphs[key] = graph
			_swept = false
			_drop_build(key)
			_fresh_by_class.erase(key)


func _fresh_of(key: int) -> PackedVector3Array:
	"""The circles class `key`'s graph in use was not built from: none unless it is being rebuilt; found once a
	setup (a pass over the circles), then kept until it is swapped in."""
	if not _building.has(key):
		return PackedVector3Array()
	if not _fresh_by_class.has(key):
		var old := {}
		for circle in (_graphs[key] as GraphScript).built_from:
			old[circle] = true
		var fresh := PackedVector3Array()
		for circle in circles:
			if not old.has(circle):
				fresh.append(circle)
		_fresh_by_class[key] = fresh
	return _fresh_by_class[key]


func fresh_count(body_radius: float) -> int:
	"""How many circles the graph in use for this body's class was not built from (0: it is up to date)."""
	return _fresh_of(roundi(body_class(body_radius) / CLASS_STEP_M)).size()


func _fresh_hit(a: Vector2, b: Vector2) -> bool:
	"""Whether a graph edge a-b comes into a circle its graph was not built from (at the graph's inflation)."""
	for circle in _fresh:
		if distance_to_segment(Vector2(circle.x, circle.z), a, b) < circle.y + _body + PLAN_MARGIN_M - 1e-4:
			return true
	return false


func builds_pending() -> int:
	"""How many classes' graphs are being rebuilt."""
	return _build_keys.size()


func _drop_build(key: int) -> void:
	"""Stop rebuilding class `key`'s graph: its replacement is built."""
	if _building.erase(key):
		_build_keys.remove_at(_build_keys.find(key))


# --- geometry -------------------------------------------------------------------------------

static func distance_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	"""Distance from p to the closest point of segment a-b."""
	var ab := b - a
	var length_sq := ab.length_squared()
	var t := 0.0 if length_sq < 1e-12 else clampf((p - a).dot(ab) / length_sq, 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func path_length(from: Vector2, path: PackedVector2Array) -> float:
	"""How long a planned route is: from `from` through each waypoint of `path` in turn (a plan's `out`,
	which excludes its start), metres. Never shorter than the straight line to its last point, so that
	line is a lower bound on it. Allocates nothing."""
	var total := 0.0
	var at := from
	for point in path:
		total += at.distance_to(point)
		at = point
	return total


static func inflated(circle: Vector3, body: float, margin: float, keep_a: Vector2, keep_b: Vector2, shrink: bool) -> float:
	"""A circle's radius plus body and margin; with `shrink`, cut to leave keep_a and keep_b outside."""
	var reach := circle.y + body + margin
	if not shrink:
		return reach
	var centre := Vector2(circle.x, circle.z)
	return minf(reach, minf(centre.distance_to(keep_a), centre.distance_to(keep_b)) - GOAL_EPSILON_M)


func circles_near(lo: Vector2, hi: Vector2) -> int:
	"""Candidate circles whose centres lie in cells overlapping the box (callers widen it by the reach
	they care about); read them with hit(k). Returns the count."""
	return _grid.query(lo, hi, _hits)


func hit(k: int) -> int:
	"""The k-th circle index of the last circles_near() query."""
	return _hits[k]


func segment_hits_obstacle(a: Vector2, b: Vector2, body: float, margin: float, keep_a: Vector2, keep_b: Vector2, shrink: bool) -> bool:
	"""Whether segment a-b cuts any obstacle circle at its inflated (optionally shrunk) radius."""
	var pad := max_radius + body + margin
	var count := _grid.query(a.min(b) - Vector2(pad, pad), a.max(b) + Vector2(pad, pad), _hits)
	for k in count:
		var circle := circles[_hits[k]]
		var r := inflated(circle, body, margin, keep_a, keep_b, shrink)
		if r > 0.0 and distance_to_segment(Vector2(circle.x, circle.z), a, b) < r - 1e-4:
			return true
	return false


func point_open(p: Vector2, body: float, margin: float = PLAN_MARGIN_M) -> bool:
	"""Whether `p` lies inside the planning area and outside every obstacle circle inflated for `body`
	and `margin`."""
	if not area.has_point(p):
		return false
	var pad := max_radius + body + margin
	var count := _grid.query(p - Vector2(pad, pad), p + Vector2(pad, pad), _hits)
	for k in count:
		var circle := circles[_hits[k]]
		if Vector2(circle.x, circle.z).distance_to(p) < circle.y + body + margin:
			return false
	return true


func _standing_hit(a: Vector2, b: Vector2) -> bool:
	"""Whether segment a-b cuts a standing resident's circle (shrunk for this plan's start and goal)."""
	for s in _standing_count:
		var r := inflated(_standing[s], _link_body, LINK_MARGIN_M, _start, _goal, true)
		if r > 0.0 and distance_to_segment(Vector2(_standing[s].x, _standing[s].z), a, b) < r - 1e-4:
			return true
	return false


func _dynamic_edge_clear(a: Vector2, b: Vector2) -> bool:
	"""An edge touching one of this plan's own nodes: every circle and standing resident, shrunk."""
	return not segment_hits_obstacle(a, b, _link_body, LINK_MARGIN_M, _start, _goal, true) and not _standing_hit(a, b)


# --- planning -------------------------------------------------------------------------------

func plan(from: Vector2, to: Vector2, body: float, standing: PackedVector3Array, standing_count: int, out: PackedVector2Array) -> void:
	"""Fill `out` with waypoints from `from` (excluded) to `to` (last). Falls back to the straight line
	when no route exists; the per-frame constraint still keeps the walker out of everything."""
	out.clear()
	_begin(from, to, body, standing, standing_count)
	last_expanded = 0
	last_found = true
	if _dynamic_edge_clear(from, to):
		out.append(to)
		return
	_prepare_search()
	last_found = _search()
	if not last_found:
		out.append(to)
		return
	_emit_route(out)


func reaches(from: Vector2, spot: Vector2, body: float) -> bool:
	"""Whether a plan from `from` to `spot` round the obstacles alone (nobody standing) is sure to find a route, by one
	sweep from `from` kept for later questions (see REACHABILITY BY ONE SWEEP). True only when it would; false when the
	sweep cannot tell -- plan then."""
	_sweep_from(from, body)
	_begin(from, spot, body, _no_standing, 0)
	if _dynamic_edge_clear(from, spot):
		return true
	var count := _graph.nodes_near(spot, LINK_M, _hits_for_graph())
	for k in count:
		var v := _node_hits[k]
		if _swept_static[v] == 1 and spot.distance_to(_graph.nodes[v]) <= LINK_M and _dynamic_edge_clear(_graph.nodes[v], spot):
			return true
	for k in _swept_points.size():
		if _swept_points[k].distance_to(spot) <= LINK_M and _dynamic_edge_clear(_swept_points[k], spot):
			return true
	return _pocket_reached(spot)


func _pocket_reached(spot: Vector2) -> bool:
	"""Whether the plan's own nodes round the circles by `spot` (its pocket: `_ring_locals`) carry a route from what the
	sweep reached to `spot`: a ring node linked from a reached node, on through the rings, and on to the spot -- each
	link as the plan makes it."""
	_dynamic.clear()
	_dynamic_reach.clear()
	_ring_locals(spot)
	var count := _dynamic.size()
	_closed.resize(count)
	_closed.fill(0)
	_pocket_queue.resize(count)
	var tail := 0
	for k in count:
		if _ring_linked_from_sweep(k):
			_closed[k] = 1
			_pocket_queue[tail] = k
			tail += 1
	var head := 0
	while head < tail:
		var a := _pocket_queue[head]
		head += 1
		for b in count:
			if _closed[b] == 0 and _dynamic[a].distance_to(_dynamic[b]) <= LOCAL_LINK_M and _dynamic_edge_clear(_dynamic[a], _dynamic[b]):
				_closed[b] = 1
				_pocket_queue[tail] = b
				tail += 1
	for k in count:
		if _closed[k] == 1 and _dynamic[k].distance_to(spot) <= LINK_M and _dynamic_edge_clear(_dynamic[k], spot):
			return true
	return false


func _ring_linked_from_sweep(k: int) -> bool:
	"""Whether pocket node `k` is linked from a node the sweep reached (within its LOCAL_LINK_M, clear)."""
	var at := _dynamic[k]
	var count := _graph.nodes_near(at, LOCAL_LINK_M, _hits_for_graph())
	for i in count:
		var v := _node_hits[i]
		if _swept_static[v] == 1 and at.distance_to(_graph.nodes[v]) <= LOCAL_LINK_M and _dynamic_edge_clear(_graph.nodes[v], at):
			return true
	for point in _swept_points:
		if point.distance_to(at) <= LOCAL_LINK_M and _dynamic_edge_clear(point, at):
			return true
	return false


func _sweep_from(from: Vector2, body: float) -> void:
	"""Mark what a route from `from` reaches on this body's graph, unless the last sweep did (see REACHABILITY BY ONE
	SWEEP): the plan's own search with no goal to stop at, round the obstacles alone."""
	var graph := ensure_graph(body)
	if _swept and _swept_from == from and _swept_graph == graph and _swept_body == body:
		return
	_begin(from, from, body, _no_standing, 0)
	_prepare_search(false)
	if _fresh.is_empty():
		_sweep_by_parts()
	else:
		_sweep_by_search()
	_keep_sweep(from, graph)


func _sweep_by_search() -> void:
	"""The plan's own search from the start, with no goal to stop at: every node it reaches is closed."""
	var statics := _graph.nodes.size()
	_cost[statics] = 0.0
	_push(statics, 0.0)
	while _heap_size > 0:
		var u := _pop()
		if _closed[u] != 0:
			continue
		_closed[u] = 1
		if u < statics:
			_expand_static(u)
		else:
			_expand_dynamic(u)


func _sweep_by_parts() -> void:
	"""The same reach from the graph's connected parts (see REACHABILITY BY ONE SWEEP): close over the plan's own nodes
	(the start and its rings) and the parts they link to, then close every node of a part reached."""
	_label_parts()
	var own := _dynamic.size()
	_part_reached.resize(_part_count)
	_part_reached.fill(0)
	_own_reached.resize(own)
	_own_reached.fill(0)
	_own_done.resize(own)
	_own_done.fill(0)
	_own_reached[0] = 1
	var changed := true
	while changed:
		changed = false
		for k in own:
			if _own_reached[k] == 1 and _own_done[k] == 0:
				_own_done[k] = 1
				_reach_parts_from(k)
				changed = true
			elif _own_reached[k] == 0 and _own_linked(k):
				_own_reached[k] = 1
				changed = true
	var statics := _graph.nodes.size()
	for v in statics:
		_closed[v] = _part_reached[_part[v]]
	for k in own:
		_closed[statics + k] = _own_reached[k]


func _reach_parts_from(k: int) -> void:
	"""Mark the part of every static node the plan's own node `k` links to (within its reach, clear)."""
	var at := _dynamic[k]
	var count := _graph.nodes_near(at, _dynamic_reach[k], _hits_for_graph())
	for i in count:
		var v := _node_hits[i]
		if _part_reached[_part[v]] == 0 and at.distance_to(_graph.nodes[v]) <= _dynamic_reach[k] \
				and _dynamic_edge_clear(at, _graph.nodes[v]):
			_part_reached[_part[v]] = 1


func _own_linked(k: int) -> bool:
	"""Whether the plan's own node `k` is linked from one reached already: another of its own, or a static node of a
	part reached (within `k`'s reach, clear -- as the plan's search links it)."""
	var at := _dynamic[k]
	for j in _dynamic.size():
		if _own_reached[j] == 1 and _dynamic[j].distance_to(at) <= _dynamic_reach[k] and _dynamic_edge_clear(_dynamic[j], at):
			return true
	var count := _graph.nodes_near(at, _dynamic_reach[k], _hits_for_graph())
	for i in count:
		var v := _node_hits[i]
		if _part_reached[_part[v]] == 1 and at.distance_to(_graph.nodes[v]) <= _dynamic_reach[k] \
				and _dynamic_edge_clear(_graph.nodes[v], at):
			return true
	return false


func _label_parts() -> void:
	"""Label the connected parts of the current graph's static edges, once per graph (a rebuilt graph is a new one)."""
	if _part_graph == _graph:
		return
	_part_graph = _graph
	var statics := _graph.nodes.size()
	_part.resize(statics)
	_part.fill(-1)
	_part_queue.resize(statics)
	_part_count = 0
	for start in statics:
		if _part[start] < 0:
			_flood_part(start)
			_part_count += 1


func _flood_part(start: int) -> void:
	"""Give part `_part_count` to every static node joined to `start`."""
	var head := 0
	var tail := 1
	_part_queue[0] = start
	_part[start] = _part_count
	while head < tail:
		var u := _part_queue[head]
		head += 1
		for e in range(_graph.adj_first[u], _graph.adj_first[u + 1]):
			var v := _graph.adj_to[e]
			if _part[v] < 0:
				_part[v] = _part_count
				_part_queue[tail] = v
				tail += 1


func _keep_sweep(from: Vector2, graph: GraphScript) -> void:
	"""Keep what the sweep just made reached, for `reaches`."""
	var statics := _graph.nodes.size()
	_swept_static.resize(statics)
	for v in statics:
		_swept_static[v] = _closed[v]
	_swept_points.clear()
	for k in _dynamic.size():
		if _closed[statics + k] == 1:
			_swept_points.append(_dynamic[k])
	_swept = true
	_swept_from = from
	_swept_graph = graph
	_swept_body = _link_body


func _begin(from: Vector2, to: Vector2, body: float, standing: PackedVector3Array, standing_count: int) -> void:
	"""Hold this plan's inputs."""
	_graph = ensure_graph(body)
	_fresh = _fresh_of(roundi(body_class(body) / CLASS_STEP_M))
	_body = _graph.body_radius
	_link_body = body
	_start = from
	_goal = to
	_standing = standing
	_standing_count = standing_count


func _prepare_search(rings_at_goal: bool = true) -> void:
	"""The plan's own nodes, the standing-resident flags on static nodes, and fresh search arrays. A sweep, whose goal is
	its start, rings it once (`rings_at_goal` false)."""
	_plan_id += 1
	_dynamic.clear()
	_dynamic_reach.clear()
	_add_dynamic(_start, LINK_M)
	_add_dynamic(_goal, LINK_M)
	for s in _standing_count:
		_ring_standing(_standing[s])
	_ring_locals(_start)
	if rings_at_goal:
		_ring_locals(_goal)
	var total := _graph.nodes.size() + _dynamic.size()
	_cost.resize(total)
	_cost.fill(INF)
	_parent.resize(total)
	_parent.fill(-1)
	_closed.resize(total)
	_closed.fill(0)
	_node_hits.resize(maxi(_graph.nodes.size(), 1))
	_heap_size = 0


func _ring_standing(standing: Vector3) -> void:
	"""Nodes round a standing resident, and a flag on every static node an edge could reach it from."""
	var centre := Vector2(standing.x, standing.z)
	var r := standing.y + _body + PLAN_MARGIN_M
	var ring := r * GraphScript.RING_OUTSET / cos(PI / STANDING_RING) + GraphScript.RING_EXTRA_M
	for k in STANDING_RING:
		var angle := TAU * (float(k) + 0.5) / STANDING_RING
		var point := centre + Vector2(cos(angle), sin(angle)) * ring
		if point_open(point, _body):
			_add_dynamic(point, LOCAL_LINK_M)
	var count := _graph.nodes_near(centre, GraphScript.EDGE_MAX_M + r, _hits_for_graph())
	for k in count:
		_graph.near_stamp[_node_hits[k]] = _plan_id


func _ring_locals(at: Vector2) -> void:
	"""Plan nodes round every circle whose edge is within LOCAL_RING_M of `at`, at the link inflation."""
	var pad := max_radius + LOCAL_RING_M
	var count := _grid.query(at - Vector2(pad, pad), at + Vector2(pad, pad), _hits)
	_local.resize(count)
	for k in count:
		_local[k] = _hits[k]
	var outward := GraphScript.RING_OUTSET / cos(PI / GraphScript.RING_POINTS)
	for k in count:
		var circle := circles[_local[k]]
		var centre := Vector2(circle.x, circle.z)
		if centre.distance_to(at) - circle.y > LOCAL_RING_M:
			continue
		var ring := (circle.y + _link_body + LINK_MARGIN_M) * outward + GraphScript.RING_EXTRA_M
		for i in GraphScript.RING_POINTS:
			var angle := TAU * (float(i) + 0.5) / GraphScript.RING_POINTS
			var point := centre + Vector2(cos(angle), sin(angle)) * ring
			if point_open(point, _link_body, LINK_MARGIN_M) and not _in_standing(point):
				_add_dynamic(point, LOCAL_LINK_M)


func _add_dynamic(point: Vector2, reach: float) -> void:
	"""One of the plan's own nodes, and how far it may link."""
	_dynamic.append(point)
	_dynamic_reach.append(reach)


func _in_standing(point: Vector2) -> bool:
	"""Whether `point` lies inside a standing resident's circle at the link inflation."""
	for s in _standing_count:
		var circle := _standing[s]
		if Vector2(circle.x, circle.z).distance_to(point) < circle.y + _link_body + LINK_MARGIN_M:
			return true
	return false


func _hits_for_graph() -> PackedInt32Array:
	"""The scratch array node queries write into, sized for the current graph."""
	if _node_hits.size() < _graph.nodes.size():
		_node_hits.resize(_graph.nodes.size())
	return _node_hits


func _position(node: int) -> Vector2:
	"""Where a node stands: static nodes first, then the plan's own (start, goal, standing rings)."""
	var statics := _graph.nodes.size()
	return _graph.nodes[node] if node < statics else _dynamic[node - statics]


func _search() -> bool:
	"""A* from the start to the goal. Fills _parent; true when the goal is reached."""
	var statics := _graph.nodes.size()
	var start := statics
	var goal := statics + 1
	_cost[start] = 0.0
	_push(start, _start.distance_to(_goal))
	while _heap_size > 0:
		var u := _pop()
		if _closed[u] != 0:
			continue
		if u == goal:
			return true
		_closed[u] = 1
		last_expanded += 1
		if u < statics:
			_expand_static(u)
		else:
			_expand_dynamic(u)
	return false


func _expand_static(u: int) -> void:
	"""A static node: its graph edges (re-tested only near a standing resident), then the plan's nodes."""
	var at := _graph.nodes[u]
	var near_standing := _graph.near_stamp[u] == _plan_id
	for e in range(_graph.adj_first[u], _graph.adj_first[u + 1]):
		var v := _graph.adj_to[e]
		if _closed[v] == 0 and _cost[u] + at.distance_to(_graph.nodes[v]) < _cost[v]:
			if (not (near_standing or _graph.near_stamp[v] == _plan_id) or not _standing_hit(at, _graph.nodes[v])) \
					and not _fresh_hit(at, _graph.nodes[v]):
				_relax(u, v)
	_link_dynamic(u, at)


func _expand_dynamic(u: int) -> void:
	"""One of the plan's own nodes: the static nodes within its reach, then the plan's other nodes."""
	var at := _position(u)
	var reach := _dynamic_reach[u - _graph.nodes.size()]
	var count := _graph.nodes_near(at, reach, _hits_for_graph())
	for k in count:
		var v := _node_hits[k]
		var d := at.distance_to(_graph.nodes[v])
		if _closed[v] == 0 and d <= reach and _cost[u] + d < _cost[v] and _dynamic_edge_clear(at, _graph.nodes[v]):
			_relax(u, v)
	_link_dynamic(u, at)


func _link_dynamic(u: int, at: Vector2) -> void:
	"""Offer the plan's own nodes (goal, standing rings) a route through u."""
	var statics := _graph.nodes.size()
	for k in _dynamic.size():
		var v := statics + k
		var d := at.distance_to(_dynamic[k])
		if v != u and _closed[v] == 0 and d <= _dynamic_reach[k] and _cost[u] + d < _cost[v] and _dynamic_edge_clear(at, _dynamic[k]):
			_relax(u, v)


func _relax(u: int, v: int) -> void:
	"""Route v through u, and queue it by cost plus straight-line distance to the goal."""
	_cost[v] = _cost[u] + _position(u).distance_to(_position(v))
	_parent[v] = u
	_push(v, _cost[v] + _position(v).distance_to(_goal))


func _emit_route(out: PackedVector2Array) -> void:
	"""Walk the parents back from the goal and write the waypoints start-exclusive, in order."""
	var statics := _graph.nodes.size()
	_chain.clear()
	var node := statics + 1
	while node != statics and node >= 0:
		_chain.append(node)
		node = _parent[node]
	for k in range(_chain.size() - 1, -1, -1):
		out.append(_position(_chain[k]))


# --- binary heap ----------------------------------------------------------------------------

func _push(node: int, f: float) -> void:
	"""Add node with priority f."""
	if _heap_size == _heap_f.size():
		_heap_f.resize(maxi(64, _heap_size * 2))
		_heap_n.resize(_heap_f.size())
	var i := _heap_size
	_heap_size += 1
	while i > 0:
		var up := (i - 1) >> 1
		if _heap_f[up] <= f:
			break
		_heap_f[i] = _heap_f[up]
		_heap_n[i] = _heap_n[up]
		i = up
	_heap_f[i] = f
	_heap_n[i] = node


func _pop() -> int:
	"""Remove and return the node with the lowest priority."""
	var top := _heap_n[0]
	_heap_size -= 1
	var f := _heap_f[_heap_size]
	var n := _heap_n[_heap_size]
	var i := 0
	while true:
		var child := i * 2 + 1
		if child >= _heap_size:
			break
		if child + 1 < _heap_size and _heap_f[child + 1] < _heap_f[child]:
			child += 1
		if _heap_f[child] >= f:
			break
		_heap_f[i] = _heap_f[child]
		_heap_n[i] = _heap_n[child]
		i = child
	_heap_f[i] = f
	_heap_n[i] = n
	return top
