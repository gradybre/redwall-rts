extends RefCounted
## The static visibility graph for one body class of the demo cast. Decision 0196.
##
## Nodes are points ringed round every obstacle circle, just outside it once inflated by this
## class's body radius and the planning margin; a node inside any other inflated circle is dropped.
## Two nodes are joined when they are at most EDGE_MAX_M apart and the segment between them clears
## every inflated circle. Built once, when the first resident of the class joins; a plan then only
## adds its start, goal and the residents standing about (cast_nav.gd).
##
## Edges are capped in length so the build stays near-linear; long straight runs come back from the
## walker skipping any waypoint once the next is in clear sight (resident_brain.gd).
##
## BUILT IN SLICES (decision 0209). `begin` sets a build going and `step` carries it on for a budget of time --
## the ring nodes circle by circle, then the joins node by node -- until it is done (`ready`); `build` runs one
## through at once. The planner (cast_nav.gd) rebuilds a class's graph a slice a frame when the circles change,
## rather than all of it in the frame that first plans for that class.

const CastGridScript := preload("res://demo/cast/cast_grid.gd")

const RING_POINTS: int = 6
const EDGE_MAX_M: float = 6.0
const NODE_CELL_M: float = 3.0
## Ring points sit this far outside the inflated circle, so edges round one circle clear it.
const RING_OUTSET: float = 1.02
const RING_EXTRA_M: float = 0.02
## A budget no build reaches: `build` runs through in one go.
const BUILD_ALL_USEC: int = 1 << 40

var body_radius: float = 0.0
var nodes: PackedVector2Array = PackedVector2Array()
var adj_first: PackedInt32Array = PackedInt32Array()
var adj_to: PackedInt32Array = PackedInt32Array()
var grid: CastGridScript = CastGridScript.new()
## Per-plan scratch owned by the planner: which nodes a standing resident may be near.
var near_stamp: PackedInt32Array = PackedInt32Array()

var _hits: PackedInt32Array = PackedInt32Array()
## Whether the graph is built through (see BUILT IN SLICES), and where a sliced build has got to.
var ready: bool = false
## The circles it is built from (the planner's array as it was: a new one replaces it, never changes it).
var built_from: PackedVector3Array = PackedVector3Array()
var _margin: float = 0.0
var _next_circle: int = 0
var _next_node: int = 0
var _joining: bool = false
var _lists: Array[PackedInt32Array] = []


func build(nav: RefCounted, body: float, margin: float) -> void:
	"""Ring nodes round every circle of `nav` (cast_nav.gd) for body radius `body` and planning
	`margin`, then join those in sight -- all at once. `nav` is untyped here only to avoid a preload cycle."""
	begin(nav, body, margin)
	while not step(nav, BUILD_ALL_USEC):
		pass


func begin(nav: RefCounted, body: float, margin: float) -> void:
	"""Start building in slices (see BUILT IN SLICES) for body radius `body` and planning `margin` over the
	circles `nav` holds now."""
	body_radius = body
	_margin = margin
	built_from = nav.circles
	nodes.clear()
	_next_circle = 0
	_next_node = 0
	_joining = false
	ready = false


func step(nav: RefCounted, budget_usec: int) -> bool:
	"""Carry the build on for about `budget_usec` microseconds: the ring nodes circle by circle, the nodes
	bucketed, then the joins node by node, each phase ending a slice when the time is spent. True once the graph
	is built (and `ready`)."""
	var until := Time.get_ticks_usec() + budget_usec
	var circles: PackedVector3Array = nav.circles
	while _next_circle < circles.size():
		_ring(nav, circles[_next_circle])
		_next_circle += 1
		if Time.get_ticks_usec() >= until:
			return false
	if not _joining:
		_start_join()
		if Time.get_ticks_usec() >= until:
			return false
	while _next_node < nodes.size():
		_join_node(nav, _next_node)
		_next_node += 1
		if Time.get_ticks_usec() >= until:
			return false
	_finish_join()
	return true


func _ring(nav: RefCounted, circle: Vector3) -> void:
	"""The ring nodes round one circle, those not inside another."""
	var ring: float = (circle.y + body_radius + _margin) * RING_OUTSET / cos(PI / RING_POINTS) + RING_EXTRA_M
	for k in RING_POINTS:
		var angle := TAU * (float(k) + 0.5) / RING_POINTS
		var point := Vector2(circle.x + cos(angle) * ring, circle.z + sin(angle) * ring)
		if nav.point_open(point, body_radius):
			nodes.append(point)


func _start_join() -> void:
	"""The nodes are all placed: bucket them and make room for their joins."""
	_joining = true
	grid.build(nodes, NODE_CELL_M)
	_hits.resize(nodes.size())
	near_stamp.resize(nodes.size())
	near_stamp.fill(0)
	_lists.resize(nodes.size())
	for u in nodes.size():
		_lists[u] = PackedInt32Array()


func _join_node(nav: RefCounted, u: int) -> void:
	"""Node `u` joined to every later node within EDGE_MAX_M whose segment clears every inflated circle."""
	var reach := Vector2(EDGE_MAX_M, EDGE_MAX_M)
	var count := grid.query(nodes[u] - reach, nodes[u] + reach, _hits)
	for k in count:
		var v := _hits[k]
		if v > u and nodes[u].distance_to(nodes[v]) <= EDGE_MAX_M \
				and not nav.segment_hits_obstacle(nodes[u], nodes[v], body_radius, _margin, Vector2.ZERO, Vector2.ZERO, false):
			_lists[u].append(v)
			_lists[v].append(u)


func _finish_join() -> void:
	"""The joins as CSR; the build is done."""
	adj_first.resize(nodes.size() + 1)
	adj_first[0] = 0
	adj_to.clear()
	for u in nodes.size():
		adj_to.append_array(_lists[u])
		adj_first[u + 1] = adj_to.size()
	_lists.clear()
	ready = true


func nodes_near(at: Vector2, reach: float, out: PackedInt32Array) -> int:
	"""Candidate nodes in cells within `reach` of `at` (callers check the exact distance)."""
	var box := Vector2(reach, reach)
	return grid.query(at - box, at + box, out)
