extends RefCounted
## The shortest ways through the tunnel network, per kind of walker. Decision 0208 (design
## docs/design/underground_revamp.md §3 "Routing"). Presentation only.
##
## MOUTH TABLES. For each fit CLASS -- every bore, or widened bores and rooms only (an otter; the badger unloaded) --
## and each network revision, a DIJKSTRA (h = 0: SET-MOVE-001 §4's reference solver) runs from every live
## mouth over the usable segments that class fits. A segment costs its planner cost (legs rounded up, u)
## over its walking speed (a lit bore is quicker): an integer, "u at walk speed", so equal routes tie
## exactly. TIES break stably: fewer segments first, then the lower segment slot into a node -- the same
## graph always gives the same route. `dist_u(class, mouth, node)` is then the cheapest walk from a mouth
## to any node, and `path_into` its segments in order. The router (tunnel_router.gd) costs a tunnel edge
## between two mouths from it, and a trip bound for a node underground (a dig's start, a job) from the
## mouth it goes in at; the paths are undirected, so the same table leads out from a node to a mouth.
##
## Built lazily: a class's table is rebuilt the first time it is asked for after the revision changed.
## A binary heap over packed columns sized once; a rebuild allocates nothing.

const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const Rules := preload("res://demo/tunnel/tunnel_rules.gd")

const CLASS_ANY: int = 0
const CLASS_WIDE: int = 1
const CLASS_NONE: int = 2
const CLASSES: int = 2
const UNREACHED: int = 1 << 60
const TABLE: int = Rules.MAX_MOUTHS * Rules.MAX_NODES
## Where the one-off row (`path_between`) lives, past both classes' tables.
const SCRATCH: int = CLASSES * TABLE
## A heap holds at most one entry per relaxation: every segment from both ends, and the source.
const HEAP_MAX: int = 2 * Rules.MAX_SEGMENTS + 1

## Table rebuilds so far (measurement and the tests).
var rebuilds: int = 0

var _revision: PackedInt64Array = PackedInt64Array([-1, -1])
var _dist: PackedInt64Array = PackedInt64Array()
var _hops: PackedInt32Array = PackedInt32Array()
var _via: PackedInt32Array = PackedInt32Array()
var _done: PackedByteArray = PackedByteArray()
var _heap_cost: PackedInt64Array = PackedInt64Array()
var _heap_hops: PackedInt32Array = PackedInt32Array()
var _heap_node: PackedInt32Array = PackedInt32Array()
var _heap_size: int = 0


func _init() -> void:
	"""Size every column once."""
	_dist.resize(SCRATCH + Rules.MAX_NODES)
	_hops.resize(SCRATCH + Rules.MAX_NODES)
	_via.resize(SCRATCH + Rules.MAX_NODES)
	_done.resize(Rules.MAX_NODES)
	_heap_cost.resize(HEAP_MAX)
	_heap_hops.resize(HEAP_MAX)
	_heap_node.resize(HEAP_MAX)


static func admits(graph: GraphScript, slot: int, fit_class: int) -> bool:
	"""Whether a walker of `fit_class` may be routed through segment `slot`: usable, and wide (a widened
	bore, or a room's own segment: decision 0209) when only wide bores fit it."""
	if fit_class == CLASS_NONE or not graph.is_usable(slot):
		return false
	return fit_class == CLASS_ANY or graph.bore[slot] != Rules.BORE_STANDARD


static func edge_cost_u(graph: GraphScript, slot: int) -> int:
	"""What walking segment `slot` costs, in u at walk speed: its planner cost over its speed, rounded up."""
	return Rules.ceil_div(graph.cost_u[slot] * Rules.PERMILLE, graph.speed_permille(slot))


func dist_u(graph: GraphScript, fit_class: int, m: int, node: int) -> int:
	"""The cheapest walk (u at walk speed) from mouth `m` to `node` for `fit_class` (UNREACHED: none)."""
	if fit_class == CLASS_NONE or not graph.is_mouth(m) or node < 0:
		return UNREACHED
	_ensure(graph, fit_class)
	return _dist[_row(fit_class, m) + node]


func path_into(graph: GraphScript, fit_class: int, m: int, node: int, out: PackedInt32Array) -> bool:
	"""The segments of the cheapest walk from mouth `m` to `node`, in walking order, into `out`. False
	(out empty) when there is none."""
	out.clear()
	if dist_u(graph, fit_class, m, node) >= UNREACHED:
		return false
	var row := _row(fit_class, m)
	var at := node
	while at != graph.mouth_node[m]:
		var slot := _via[row + at]
		out.append(slot)
		at = graph.other_end(slot, at)
	out.reverse()
	return true


func path_between(graph: GraphScript, fit_class: int, from: int, to: int, out: PackedInt32Array) -> bool:
	"""The segments of the cheapest walk between two nodes, in walking order, into `out` (a one-off Dijkstra
	from `from`, not kept). False (out empty) when there is none."""
	out.clear()
	if fit_class == CLASS_NONE or not graph.is_node(from) or not graph.is_node(to):
		return false
	for node in Rules.MAX_NODES:
		_dist[SCRATCH + node] = UNREACHED
		_via[SCRATCH + node] = -1
	_dijkstra(graph, fit_class, from, SCRATCH)
	if _dist[SCRATCH + to] >= UNREACHED:
		return false
	var at := to
	while at != from:
		out.append(_via[SCRATCH + at])
		at = graph.other_end(_via[SCRATCH + at], at)
	out.reverse()
	return true


func nearest_mouth(graph: GraphScript, node: int, fit_class: int) -> int:
	"""The mouth cheapest to reach from `node` for `fit_class` (the lower row on a tie; -1: none)."""
	var best := -1
	var best_d := UNREACHED
	for m in Rules.MAX_MOUTHS:
		var d := dist_u(graph, fit_class, m, node)
		if d < best_d:
			best_d = d
			best = m
	return best


func _row(fit_class: int, m: int) -> int:
	"""Where mouth `m`'s row of `fit_class`'s table starts."""
	return fit_class * TABLE + m * Rules.MAX_NODES


func _ensure(graph: GraphScript, fit_class: int) -> void:
	"""Rebuild `fit_class`'s table when the network changed since it was built."""
	if _revision[fit_class] == graph.revision:
		return
	_revision[fit_class] = graph.revision
	rebuilds += 1
	for m in Rules.MAX_MOUTHS:
		var row := _row(fit_class, m)
		for node in Rules.MAX_NODES:
			_dist[row + node] = UNREACHED
			_via[row + node] = -1
		if graph.is_mouth(m):
			_dijkstra(graph, fit_class, graph.mouth_node[m], row)


func _dijkstra(graph: GraphScript, fit_class: int, source: int, row: int) -> void:
	"""Fill the table row at `row`: Dijkstra from node `source` over the segments `fit_class` may use (see
	MOUTH TABLES), settling nodes in (cost, segments, node) order."""
	_done.fill(0)
	_heap_size = 0
	_dist[row + source] = 0
	_hops[row + source] = 0
	_push(0, 0, source)
	while _heap_size > 0:
		var node := _heap_node[0]
		_pop()
		if _done[node] == 1:
			continue
		_done[node] = 1
		_relax_from(graph, fit_class, row, node)


func _relax_from(graph: GraphScript, fit_class: int, row: int, node: int) -> void:
	"""Relax every segment the class may use out of a settled node."""
	for k in GraphScript.DEGREE:
		var slot := graph.node_segment(node, k)
		if slot < 0 or not admits(graph, slot, fit_class):
			continue
		var other := graph.other_end(slot, node)
		if _done[other] == 1:
			continue
		var cost := _dist[row + node] + edge_cost_u(graph, slot)
		var hops := _hops[row + node] + 1
		if _better(row + other, cost, hops, slot):
			_dist[row + other] = cost
			_hops[row + other] = hops
			_via[row + other] = slot
			_push(cost, hops, other)


func _better(at: int, cost: int, hops: int, slot: int) -> bool:
	"""Whether (cost, segments, via slot) improves on what table entry `at` holds (see TIES)."""
	if cost != _dist[at]:
		return cost < _dist[at]
	if hops != _hops[at]:
		return hops < _hops[at]
	return slot < _via[at]


# --- the heap -------------------------------------------------------------------------------

func _before(i: int, j: int) -> bool:
	"""Whether heap entry i orders before entry j: by cost, then segments, then node."""
	if _heap_cost[i] != _heap_cost[j]:
		return _heap_cost[i] < _heap_cost[j]
	if _heap_hops[i] != _heap_hops[j]:
		return _heap_hops[i] < _heap_hops[j]
	return _heap_node[i] < _heap_node[j]


func _swap(i: int, j: int) -> void:
	"""Swap two heap entries."""
	var cost := _heap_cost[i]
	var hops := _heap_hops[i]
	var node := _heap_node[i]
	_heap_cost[i] = _heap_cost[j]
	_heap_hops[i] = _heap_hops[j]
	_heap_node[i] = _heap_node[j]
	_heap_cost[j] = cost
	_heap_hops[j] = hops
	_heap_node[j] = node


func _push(cost: int, hops: int, node: int) -> void:
	"""Add an entry and sift it up."""
	var i := _heap_size
	_heap_cost[i] = cost
	_heap_hops[i] = hops
	_heap_node[i] = node
	_heap_size += 1
	while i > 0 and _before(i, (i - 1) / 2):
		_swap(i, (i - 1) / 2)
		i = (i - 1) / 2


func _pop() -> void:
	"""Remove the first entry and sift the last down into its place."""
	_heap_size -= 1
	_swap(0, _heap_size)
	var i := 0
	while true:
		var least := i
		if 2 * i + 1 < _heap_size and _before(2 * i + 1, least):
			least = 2 * i + 1
		if 2 * i + 2 < _heap_size and _before(2 * i + 2, least):
			least = 2 * i + 2
		if least == i:
			return
		_swap(i, least)
		i = least
