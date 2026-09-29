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

const CastGridScript := preload("res://demo/cast/cast_grid.gd")

const RING_POINTS: int = 6
const EDGE_MAX_M: float = 6.0
const NODE_CELL_M: float = 3.0
## Ring points sit this far outside the inflated circle, so edges round one circle clear it.
const RING_OUTSET: float = 1.02
const RING_EXTRA_M: float = 0.02

var body_radius: float = 0.0
var nodes: PackedVector2Array = PackedVector2Array()
var adj_first: PackedInt32Array = PackedInt32Array()
var adj_to: PackedInt32Array = PackedInt32Array()
var grid: CastGridScript = CastGridScript.new()
## Per-plan scratch owned by the planner: which nodes a standing resident may be near.
var near_stamp: PackedInt32Array = PackedInt32Array()

var _hits: PackedInt32Array = PackedInt32Array()


func build(nav: RefCounted, body: float, margin: float) -> void:
	"""Ring nodes round every circle of `nav` (cast_nav.gd) for body radius `body` and planning
	`margin`, then join those in sight. `nav` is untyped here only to avoid a preload cycle."""
	body_radius = body
	nodes.clear()
	var outward := RING_OUTSET / cos(PI / RING_POINTS)
	var circles: PackedVector3Array = nav.circles
	for circle in circles:
		var ring: float = (circle.y + body + margin) * outward + RING_EXTRA_M
		for k in RING_POINTS:
			var angle := TAU * (float(k) + 0.5) / RING_POINTS
			var point := Vector2(circle.x + cos(angle) * ring, circle.z + sin(angle) * ring)
			if nav.point_open(point, body):
				nodes.append(point)
	grid.build(nodes, NODE_CELL_M)
	_hits.resize(nodes.size())
	near_stamp.resize(nodes.size())
	near_stamp.fill(0)
	_join(nav, margin)


func _join(nav: RefCounted, margin: float) -> void:
	"""Every pair of nodes within EDGE_MAX_M whose segment clears every inflated circle, as CSR."""
	var lists: Array[PackedInt32Array] = []
	lists.resize(nodes.size())
	for u in nodes.size():
		lists[u] = PackedInt32Array()
	var reach := Vector2(EDGE_MAX_M, EDGE_MAX_M)
	for u in nodes.size():
		var count := grid.query(nodes[u] - reach, nodes[u] + reach, _hits)
		for k in count:
			var v := _hits[k]
			if v > u and nodes[u].distance_to(nodes[v]) <= EDGE_MAX_M \
					and not nav.segment_hits_obstacle(nodes[u], nodes[v], body_radius, margin, Vector2.ZERO, Vector2.ZERO, false):
				lists[u].append(v)
				lists[v].append(u)
	adj_first.resize(nodes.size() + 1)
	adj_first[0] = 0
	adj_to.clear()
	for u in nodes.size():
		adj_to.append_array(lists[u])
		adj_first[u + 1] = adj_to.size()


func nodes_near(at: Vector2, reach: float, out: PackedInt32Array) -> int:
	"""Candidate nodes in cells within `reach` of `at` (callers check the exact distance)."""
	var box := Vector2(reach, reach)
	return grid.query(at - box, at + box, out)
