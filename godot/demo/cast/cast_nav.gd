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
## LOCAL, NOT EVERYONE (decision 1001; the scale test's first wall, decision 0561). A plan used to ring every resident
## standing still before it searched, and to test each link against every one of them: quadratic in the residents
## standing, so one plan cost 2 ms at nine residents and 45 ms at fifty. Now:
##   * the plan's standing residents are bucketed in a grid when it begins (`_index_standing`);
##   * a standing resident is ringed only when the search first expands a node its ring could link to (`_scan_standing`
##     before every expansion), so only those in the route's corridor are ever ringed;
##   * a link is tested only against the standing residents near it -- for a static node's edges, those within an edge's
##     length of it, found once per expansion; for any other link, by a grid look along it;
##   * the plan's own nodes (start, goal, rings) sit in a hashed grid of their own (`_dyn_*`), so linking an expanded node
##     looks only at the nodes in the cells round it, not at every one.
## It is the same search: every node an expanded node could link to exists before it links, every test answers as the
## full scan did, and test_demo_route_planning.gd plans the real village both ways (the planner as it was is kept in
## test/fixtures/reference_cast_nav.gd) and finds the same routes. Only the order in which candidates of exactly equal
## cost enter the heap may differ.
##
## DIVISIBLE (decision 1001, the 2026-10-02 review's R07). `begin_plan`, `step_plan(n)` -- at most n expansions -- and
## `finish_plan` split one plan across frames; `plan` runs the three through at once. A CastNav holds one plan at a time,
## so the routing desk keeps a second (route_desk.gd `worker`), planning over this one's circles and graphs
## (`share_world`, told again whenever the circles change), for the plans it carries from frame to frame. A plan carried
## over keeps the standing residents it began with.
##
## A GOAL SHUT IN (decision 1001). Most of the plans the scale test's village failed (60% at fifty residents) went to
## a spot ringed by residents standing round it -- the supper table's overflow, a seat among the diners -- or to a spot
## tucked in among circles that no route reaches; and a failed plan searches every node the start can reach before it
## says so: a whole graph, many times over. So a plan whose goal lies within a circle's reach, or has GOAL_CROWD or more
## standing within GOAL_CROWD_M, first looks from the goal's side (`_step_shut_in`): it marks every
## node with a link INTO the goal, then into those, each link tested exactly as the search would test it from its own
## side. Reaching the start, or spending SHUT_IN_EXPANSIONS, it hands over to the search as usual; running out of nodes
## first, it has found every node that could reach the goal, the start not among them: there is no route, as the search
## would have found after reading the whole village.
##
## ONE FIELD PER SHARED GOAL (decision 1002). When many residents wait to go to the same spot -- the supper table's
## overflow, the hall door at dusk -- a plan may be GUIDED (`begin_plan(..., true)`): the goal's distance FIELD, one
## search outward from the goal over the static graph round the obstacles alone (`_begin_field`, carried in slices like
## any plan), is kept (FIELD_SLOTS of them, the least lately used dropped) and stands in for the straight line as the
## search's estimate of the way still to go -- except within FIELD_NEAR_M of the goal, where the crowd a shared goal
## draws stands and the field, which knows nobody standing, would lead the search into it: there it is the straight
## line, as for any plan. A guided plan is still an ordinary search over this resident's own graph -- its start, the
## standing residents, every link tested as any plan tests it -- so its route is as clear as any plan's; but with the
## estimate this close it expands little more than the route itself. The estimate can overstate the way where a ring at
## the tight inflation opens a gap the padded graph does not (a standing resident's ring, the start's pocket), so a
## guided route may be longer than the shortest; the suite bounds by how much on the village.
##
## Nothing here allocates during a plan beyond its arrays' first growth (and a field's own column, once a field); the grid
## queries write into member arrays.

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
## A plan's states (see DIVISIBLE): under way, a route found, no route (the straight line is the fallback).
const PLAN_PENDING: int = 0
const PLAN_FOUND: int = 1
const PLAN_NONE: int = 2
## A step no plan reaches: `plan` searches through.
const ALL_EXPANSIONS: int = 1 << 30
## The standing residents' grid (see LOCAL, NOT EVERYONE): a cell holds a few of them in a crowd.
const STANDING_CELL_M: float = 4.0
## The plan's own nodes' grid: a cell as wide as a ring node's reach, so all it links to lie in the 3 x 3 round it.
const DYN_CELL_M: float = LOCAL_LINK_M
## Its hashed buckets (a power of two); a bucket two cells share is filtered by distance like any candidate.
const DYN_BUCKETS: int = 1024
## Slack on the distances that choose which standing residents a node could reach: an extra one considered is harmless.
const NEAR_SLACK_M: float = 0.01
## How many goals' fields are kept (see ONE FIELD PER SHARED GOAL): a goal's field per body class, and the dusk's door
## places and the meal's table for three classes are a dozen and more.
const FIELD_SLOTS: int = 32
## Within this of the goal a guided plan estimates by the straight line, not the field (see ONE FIELD PER SHARED GOAL).
const FIELD_NEAR_M: float = 6.0
## What a divisible plan is doing (see DIVISIBLE): its goal's field first, when it is guided and has none, then the
## search.
const PHASE_SEARCH: int = 0
const PHASE_FIELD: int = 1
## ...and, its goal crowded, a look whether the goal is shut in first (see A GOAL SHUT IN).
const PHASE_SHUT_IN: int = 2
## A GOAL SHUT IN: a goal with at least GOAL_CROWD residents standing within GOAL_CROWD_M is looked at from its side first,
## for at most SHUT_IN_EXPANSIONS expansions.
const GOAL_CROWD: int = 2
const GOAL_CROWD_M: float = 1.5
const SHUT_IN_EXPANSIONS: int = 48

var circles: PackedVector3Array = PackedVector3Array()
var max_radius: float = 0.0
## The planning area (see THE PLANNING AREA); nodes outside it are not placed.
var area: Rect2 = Rect2(-1e6, -1e6, 2e6, 2e6)
## Plan statistics, for measurement: nodes expanded and whether a route was found.
var last_expanded: int = 0
var last_found: bool = false
## Fields searched (see ONE FIELD PER SHARED GOAL), for measurement.
var fields_built: int = 0
## Bumped by every `setup`: a planner sharing this one's world (see DIVISIBLE) follows it when it moves on.
var world_revision: int = 0

var _grid: CastGridScript = CastGridScript.new()
var _hits: PackedInt32Array = PackedInt32Array()
## The circles again, each in every cell it overlaps (cast_grid.gd DISKS): what the yes-or-no tests read (see LOCAL, NOT
## EVERYONE), and their query's scratch.
var _disks: CastGridScript = CastGridScript.new()
var _disk_hits: PackedInt32Array = PackedInt32Array()
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
## The standing residents' grid and scratch (see LOCAL, NOT EVERYONE): their centres, the plan each was ringed in, the
## grid's query results, the residents an expanded node's links could cut, and the widest reaches the looks pad by.
var _stand_grid: CastGridScript = CastGridScript.new()
var _stand_pos: PackedVector2Array = PackedVector2Array()
var _ringed: PackedInt32Array = PackedInt32Array()
var _stand_hits: PackedInt32Array = PackedInt32Array()
var _stand_hits2: PackedInt32Array = PackedInt32Array()
var _near_list: PackedInt32Array = PackedInt32Array()
var _max_hit_m: float = 0.0
var _max_ring_m: float = 0.0
## The plan's own nodes' grid (see LOCAL, NOT EVERYONE): per bucket its first node and the plan that filled it, per node
## the next in its bucket; and the candidates one look gathers, and the buckets it has read.
var _dyn_head: PackedInt32Array = PackedInt32Array()
var _dyn_stamp: PackedInt32Array = PackedInt32Array()
var _dyn_next: PackedInt32Array = PackedInt32Array()
var _cand: PackedInt32Array = PackedInt32Array()
var _visited: PackedInt32Array = PackedInt32Array()
## The divisible plan (see DIVISIBLE): its state and phase, whether its route is the straight line, the request it
## holds (for its field first, or to start again when the circles change), and the field guiding it (empty: none).
var _state: int = PLAN_NONE
var _phase: int = PHASE_SEARCH
var _direct: bool = false
var _req_from: Vector2 = Vector2.ZERO
var _req_to: Vector2 = Vector2.ZERO
var _req_body: float = 0.0
var _req_standing: PackedVector3Array = PackedVector3Array()
var _req_count: int = 0
var _req_guided: bool = false
var _h_field: PackedFloat32Array = PackedFloat32Array()
var _no_field: PackedFloat32Array = PackedFloat32Array()
## The graph the guiding field was searched on: a field is used only on its own graph (one swapped in meanwhile, its
## nodes numbered anew, is searched by the straight line).
var _h_graph: GraphScript = null
## The look from the goal's side (see A GOAL SHUT IN): the nodes marked, those still to expand, and the expansions spent.
var _back_marked: PackedByteArray = PackedByteArray()
var _back_queue: PackedInt32Array = PackedInt32Array()
var _back_head: int = 0
var _back_tail: int = 0
var _back_spent: int = 0
## The fields kept (see ONE FIELD PER SHARED GOAL): per slot its goal, the graph it was searched on, its distances (per
## static node; INF unreached), and when it was last used.
var _field_goal: PackedVector2Array = PackedVector2Array()
var _field_graph: Array[GraphScript] = []
var _field_dist: Array[PackedFloat32Array] = []
var _field_used: PackedInt32Array = PackedInt32Array()
var _field_clock: int = 0
## The last reachability sweep (see REACHABILITY BY ONE SWEEP): whether one stands, its start, the graph it swept, the
## static nodes it reached and the plan's own nodes (round the start) it reached.
## The planner whose world this one shares (`share_world`; null: its own), and the revision it last took.
var _world_owner: Object = null
var _world_seen: int = -1
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


func _init() -> void:
	"""The plan's own grid's buckets, sized once."""
	_dyn_head.resize(DYN_BUCKETS)
	_dyn_stamp.resize(DYN_BUCKETS)
	_visited.resize(9)


func setup(obstacles: PackedVector3Array) -> void:
	"""Take the circles (x, radius, z) and bucket them. Each class's graph is rebuilt in slices (see REBUILT IN
	SLICES); a class never planned for gets its graph when it first does."""
	circles = obstacles
	world_revision += 1
	_swept = false
	max_radius = 0.0
	var centres := PackedVector2Array()
	var radii := PackedFloat32Array()
	for circle in circles:
		max_radius = maxf(max_radius, circle.y)
		centres.append(Vector2(circle.x, circle.z))
		radii.append(circle.y)
	_grid.build(centres, CIRCLE_CELL_M)
	_disks.build_disks(centres, radii, CIRCLE_CELL_M)
	_hits.resize(circles.size())
	_disk_hits.resize(_disks.item_count())
	_building.clear()
	_build_keys.clear()
	_fresh_by_class.clear()
	for key: int in _graphs:
		var graph := GraphScript.new()
		graph.begin(self, float(key) * CLASS_STEP_M, PLAN_MARGIN_M)
		_building[key] = graph
		_build_keys.append(key)


func share_world(owner: Object) -> void:
	"""Plan over `owner`'s (another CastNav's) circles, area and graphs, sharing them, not copying (see DIVISIBLE): the
	routing desk's second planner, told again whenever the owner's circles change. The fields kept are dropped, and a
	plan under way starts again over the new circles. The owner is kept, and followed again whenever its world moves on
	(`_follow_world`); it holds nothing of this one, so there is no cycle."""
	_world_owner = owner
	_world_seen = int(owner.get(&"world_revision"))
	circles = owner.get(&"circles")
	max_radius = owner.get(&"max_radius")
	area = owner.get(&"area")
	_grid = owner.get(&"_grid")
	_disks = owner.get(&"_disks")
	_disk_hits.resize(_disks.item_count())
	_graphs = owner.get(&"_graphs")
	_building = owner.get(&"_building")
	_fresh_by_class = owner.get(&"_fresh_by_class")
	_hits.resize(circles.size())
	_swept = false
	_drop_fields()
	if _state == PLAN_PENDING:
		begin_plan(_req_from, _req_to, _req_body, _req_standing, _req_count, _req_guided)


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
	"""Whether segment a-b cuts any obstacle circle at its inflated (optionally shrunk) radius: those in the cells round
	the segment (cast_grid.gd DISKS)."""
	var pad := body + margin
	var count := _disks.query(a.min(b) - Vector2(pad, pad), a.max(b) + Vector2(pad, pad), _disk_hits)
	for k in count:
		var circle := circles[_disk_hits[k]]
		var r := inflated(circle, body, margin, keep_a, keep_b, shrink)
		if r > 0.0 and distance_to_segment(Vector2(circle.x, circle.z), a, b) < r - 1e-4:
			return true
	return false


func point_open(p: Vector2, body: float, margin: float = PLAN_MARGIN_M) -> bool:
	"""Whether `p` lies inside the planning area and outside every obstacle circle inflated for `body`
	and `margin`."""
	if not area.has_point(p):
		return false
	var pad := body + margin
	var count := _disks.query(p - Vector2(pad, pad), p + Vector2(pad, pad), _disk_hits)
	for k in count:
		var circle := circles[_disk_hits[k]]
		if Vector2(circle.x, circle.z).distance_to(p) < circle.y + body + margin:
			return false
	return true


func _standing_hit(a: Vector2, b: Vector2) -> bool:
	"""Whether segment a-b cuts a standing resident's circle (shrunk for this plan's start and goal): those near the
	segment, by the standing grid (see LOCAL, NOT EVERYONE)."""
	if _standing_count == 0:
		return false
	var pad := _max_hit_m
	var lo := a.min(b)
	var hi := a.max(b)
	var count := _stand_grid.query(lo - Vector2(pad, pad), hi + Vector2(pad, pad), _stand_hits)
	for k in count:
		var s := _stand_hits[k]
		var c := _stand_pos[s]
		if c.x < lo.x - pad or c.x > hi.x + pad or c.y < lo.y - pad or c.y > hi.y + pad:
			continue
		var r := inflated(_standing[s], _link_body, LINK_MARGIN_M, _start, _goal, true)
		if r > 0.0 and distance_to_segment(c, a, b) < r - 1e-4:
			return true
	return false


func _listed_hit(a: Vector2, b: Vector2, listed: int) -> bool:
	"""Whether segment a-b cuts one of the first `listed` residents of the expanded node's list (`_scan_standing`): every
	one it could cut is on it. One whose centre lies off the segment's box by more than its whole reach is passed over
	before the exact test."""
	var lo := a.min(b)
	var hi := a.max(b)
	for i in listed:
		var s := _near_list[i]
		var c := _stand_pos[s]
		var reach := _standing[s].y + _link_body + LINK_MARGIN_M
		if c.x < lo.x - reach or c.x > hi.x + reach or c.y < lo.y - reach or c.y > hi.y + reach:
			continue
		var r := inflated(_standing[s], _link_body, LINK_MARGIN_M, _start, _goal, true)
		if r > 0.0 and distance_to_segment(c, a, b) < r - 1e-4:
			return true
	return false


func _dynamic_edge_clear(a: Vector2, b: Vector2) -> bool:
	"""An edge touching one of this plan's own nodes: every circle and standing resident, shrunk."""
	return not segment_hits_obstacle(a, b, _link_body, LINK_MARGIN_M, _start, _goal, true) and not _standing_hit(a, b)


# --- planning -------------------------------------------------------------------------------

func plan(from: Vector2, to: Vector2, body: float, standing: PackedVector3Array, standing_count: int, out: PackedVector2Array) -> void:
	"""Fill `out` with waypoints from `from` (excluded) to `to` (last). Falls back to the straight line
	when no route exists; the per-frame constraint still keeps the walker out of everything."""
	begin_plan(from, to, body, standing, standing_count)
	step_plan(ALL_EXPANSIONS)
	finish_plan(out)


func begin_plan(from: Vector2, to: Vector2, body: float, standing: PackedVector3Array, standing_count: int,
		guided: bool = false) -> void:
	"""Begin a plan (see DIVISIBLE) from `from` to `to` for a body of radius `body` round the first `standing_count` of
	`standing` (copied: a plan carried over keeps them). `guided`: by the goal's field (see ONE FIELD PER SHARED GOAL),
	searched first when none is kept."""
	_follow_world()
	_hold_request(from, to, body, standing, standing_count, guided)
	last_expanded = 0
	_h_field = _no_field
	if guided:
		var slot := _field_slot(to, body)
		if slot < 0:
			_begin_field(to, body)
			return
		_h_field = _field_dist[slot]
		_h_graph = _field_graph[slot]
	_begin_search(from, to, body, standing, standing_count)


func step_plan(max_expansions: int) -> int:
	"""Carry the plan on by at most `max_expansions` expansions (see DIVISIBLE). PLAN_PENDING while it is not done,
	else PLAN_FOUND or PLAN_NONE (read the route with `finish_plan`)."""
	_follow_world()
	var budget := max_expansions
	if _phase == PHASE_FIELD:
		budget -= _step_field(budget)
		if _phase == PHASE_FIELD:
			return PLAN_PENDING
	if _phase == PHASE_SHUT_IN:
		budget -= _step_shut_in(budget)
		if _phase == PHASE_SHUT_IN:
			return PLAN_PENDING
	if _state != PLAN_PENDING:
		return _state
	return _search_step(budget)


func _search_step(budget: int) -> int:
	"""The search itself carried on by at most `budget` expansions (A* from the start to the goal); the plan's state."""
	var statics := _graph.nodes.size()
	var done := 0
	while _heap_size > 0 and done < budget:
		var u := _pop()
		if _closed[u] != 0:
			continue
		if u == statics + 1:
			_state = PLAN_FOUND
			return _state
		_closed[u] = 1
		last_expanded += 1
		done += 1
		if u < statics:
			_expand_static(u)
		else:
			_expand_dynamic(u)
	if _heap_size == 0:
		_state = PLAN_NONE
	return _state


func finish_plan(out: PackedVector2Array) -> void:
	"""The finished plan's waypoints into `out`, from its start (excluded) to its goal (last) -- the straight line when
	no route was found -- and `last_found` set."""
	out.clear()
	last_found = _state == PLAN_FOUND
	if _direct or _state != PLAN_FOUND:
		out.append(_goal)
		return
	_emit_route(out)


func _follow_world() -> void:
	"""Take the owner's world again if it has moved on since it was shared (see DIVISIBLE): a `setup` of the owner's
	rebuilds the grids this one shares in place, so they must never be read against the circles from before."""
	if _world_owner != null and int(_world_owner.get(&"world_revision")) != _world_seen:
		share_world(_world_owner)


func plan_state() -> int:
	"""Where the plan under way stands (see DIVISIBLE): PLAN_PENDING, PLAN_FOUND or PLAN_NONE."""
	return PLAN_PENDING if _phase != PHASE_SEARCH else _state


func plan_matches(from: Vector2, to: Vector2, body: float) -> bool:
	"""Whether the plan held is from `from` to `to` for a body of radius `body`."""
	return _req_from == from and _req_to == to and _req_body == body


func plan_goal() -> Vector2:
	"""Where the plan held goes (see DIVISIBLE)."""
	return _req_to


func _hold_request(from: Vector2, to: Vector2, body: float, standing: PackedVector3Array, standing_count: int,
		guided: bool) -> void:
	"""Keep the plan's request (see DIVISIBLE), its standing residents copied."""
	_req_from = from
	_req_to = to
	_req_body = body
	_req_guided = guided
	_req_count = standing_count
	if _req_standing.size() < standing_count:
		_req_standing.resize(standing_count)
	for s in standing_count:
		_req_standing[s] = standing[s]


func _begin_search(from: Vector2, to: Vector2, body: float, standing: PackedVector3Array, standing_count: int) -> void:
	"""The search's own start: straight there when nothing is in the way, else the plan's nodes and the start queued."""
	_begin(from, to, body, standing, standing_count)
	if _h_graph != _graph:
		_h_field = _no_field
	_phase = PHASE_SEARCH
	_state = PLAN_PENDING
	_direct = _dynamic_edge_clear(from, to)
	if _direct:
		_state = PLAN_FOUND
		return
	_prepare_search()
	var statics := _graph.nodes.size()
	_cost[statics] = 0.0
	_push(statics, _start.distance_to(_goal))
	if _goal_crowded():
		_begin_shut_in()


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
	_clear_dynamic()
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
	"""Hold this plan's inputs: the standing residents copied and bucketed (see LOCAL, NOT EVERYONE)."""
	_graph = ensure_graph(body)
	_fresh = _fresh_of(roundi(body_class(body) / CLASS_STEP_M))
	_body = _graph.body_radius
	_link_body = body
	_start = from
	_goal = to
	_standing_count = standing_count
	if _standing.size() < standing_count:
		_standing.resize(standing_count)
	for s in standing_count:
		_standing[s] = standing[s]
	_index_standing()


func _index_standing() -> void:
	"""Bucket this plan's standing residents (see LOCAL, NOT EVERYONE), and the widest reaches the looks are padded by:
	a link's test (the widest body at the link inflation) and a ring's (round the widest, at the class's). The arrays
	only grow."""
	if _stand_pos.size() < _standing_count:
		_stand_pos.resize(_standing_count)
		_ringed.resize(_standing_count)
		_stand_hits.resize(_standing_count)
		_near_list.resize(_standing_count)
	var widest := 0.0
	for s in _standing_count:
		_stand_pos[s] = Vector2(_standing[s].x, _standing[s].z)
		widest = maxf(widest, _standing[s].y)
	_max_hit_m = widest + _link_body + LINK_MARGIN_M
	_max_ring_m = _ring_radius(widest)
	if _standing_count > 0:
		_stand_grid.build(_stand_pos, STANDING_CELL_M, _standing_count)


func _ring_radius(standing_radius: float) -> float:
	"""How far from a standing resident's centre its ring nodes stand (it was decision 0196's ring)."""
	var r := standing_radius + _body + PLAN_MARGIN_M
	return r * GraphScript.RING_OUTSET / cos(PI / STANDING_RING) + GraphScript.RING_EXTRA_M


func _prepare_search(rings_at_goal: bool = true) -> void:
	"""The plan's own nodes -- start, goal, and the rings round the circles by them; the standing residents' rings come
	as the search reaches them -- and fresh search arrays, with room for every ring it may add. A sweep, whose goal is
	its start, rings it once (`rings_at_goal` false)."""
	_clear_dynamic()
	_add_dynamic(_start, LINK_M)
	_add_dynamic(_goal, LINK_M)
	_ring_locals(_start)
	if rings_at_goal:
		_ring_locals(_goal)
	var most := _dynamic.size() + STANDING_RING * _standing_count
	var total := _graph.nodes.size() + most
	_cost.resize(total)
	_cost.fill(INF)
	_parent.resize(total)
	_parent.fill(-1)
	_closed.resize(total)
	_closed.fill(0)
	if _cand.size() < most:
		_cand.resize(most)
	_node_hits.resize(maxi(_graph.nodes.size(), 1))
	_heap_size = 0


func _clear_dynamic() -> void:
	"""No plan nodes yet; the plan's own grid emptied with them (a new stamp)."""
	_plan_id += 1
	_dynamic.clear()
	_dynamic_reach.clear()


func _scan_standing(at: Vector2, reach: float, ring_reach: float = LOCAL_LINK_M) -> int:
	"""Before an expansion from `at`: ring every standing resident not ringed yet whose ring could lie within
	`ring_reach` of it (a ring node links within LOCAL_LINK_M), and list into `_near_list` those a link of at most `reach`
	from it could cut. The count listed."""
	if _standing_count == 0:
		return 0
	var pad := maxf(reach + _max_hit_m, ring_reach + _max_ring_m) + NEAR_SLACK_M
	var count := _stand_grid.query(at - Vector2(pad, pad), at + Vector2(pad, pad), _stand_hits)
	var listed := 0
	for k in count:
		var s := _stand_hits[k]
		var d := _stand_pos[s].distance_to(at)
		if _ringed[s] != _plan_id and d <= ring_reach + _ring_radius(_standing[s].y) + NEAR_SLACK_M:
			_ring_standing(s)
		if d < reach + _standing[s].y + _link_body + LINK_MARGIN_M + NEAR_SLACK_M:
			_near_list[listed] = s
			listed += 1
	return listed


func _ring_standing(s: int) -> void:
	"""Nodes round standing resident `s`, once a plan: those outside every circle, and not inside another standing
	resident's circle as this plan tests links against it -- no link could reach such a node (every segment from it
	starts inside that circle), so it is left out rather than tested link by link (a crowd's rings are mostly such)."""
	_ringed[s] = _plan_id
	var centre := _stand_pos[s]
	var ring := _ring_radius(_standing[s].y)
	for k in STANDING_RING:
		var angle := TAU * (float(k) + 0.5) / STANDING_RING
		var point := centre + Vector2(cos(angle), sin(angle)) * ring
		if point_open(point, _body) and not _inside_standing_link(point):
			_add_dynamic(point, LOCAL_LINK_M)


func _inside_standing_link(point: Vector2) -> bool:
	"""Whether `point` lies inside a standing resident's circle at the link inflation, shrunk for this plan's start and
	goal, by more than the links' tolerance -- so that every segment from it cuts that circle."""
	var pad := _max_hit_m
	var count := _stand_grid.query(point - Vector2(pad, pad), point + Vector2(pad, pad), _hits_standing())
	for k in count:
		var s := _stand_hits2[k]
		var r := inflated(_standing[s], _link_body, LINK_MARGIN_M, _start, _goal, true)
		if r > 0.0 and _stand_pos[s].distance_to(point) < r - 1e-4:
			return true
	return false


func _hits_standing() -> PackedInt32Array:
	"""A second scratch array for standing-grid queries, sized for this plan's standing residents: `_ring_standing` runs
	inside `_scan_standing`'s loop over the first."""
	if _stand_hits2.size() < _standing_count:
		_stand_hits2.resize(_standing_count)
	return _stand_hits2


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
	"""One of the plan's own nodes, and how far it may link; past the start and goal, into the plan's own grid."""
	var k := _dynamic.size()
	_dynamic.append(point)
	_dynamic_reach.append(reach)
	if k < 2:
		return
	if k >= _dyn_next.size():
		_dyn_next.resize(k * 2 + 16)
	var b := _bucket(floori(point.x / DYN_CELL_M), floori(point.y / DYN_CELL_M))
	if _dyn_stamp[b] != _plan_id:
		_dyn_stamp[b] = _plan_id
		_dyn_head[b] = -1
	_dyn_next[k] = _dyn_head[b]
	_dyn_head[b] = k


static func _bucket(cx: int, cz: int) -> int:
	"""The plan's own grid's bucket for cell (cx, cz)."""
	return ((cx * 73856093) ^ (cz * 19349663)) & (DYN_BUCKETS - 1)


func _dyn_near(at: Vector2) -> int:
	"""Into `_cand`: the start and the goal, then the plan's other nodes in the 3 x 3 cells round `at` (each bucket read
	once). The count."""
	var count := mini(_dynamic.size(), 2)
	for k in count:
		_cand[k] = k
	var cx := floori(at.x / DYN_CELL_M)
	var cz := floori(at.y / DYN_CELL_M)
	_visited.fill(-1)
	var read := 0
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var b := _bucket(cx + dx, cz + dz)
			if _dyn_stamp[b] != _plan_id or _visited.has(b):
				continue
			_visited[read] = b
			read += 1
			var k := _dyn_head[b]
			while k >= 0:
				_cand[count] = k
				count += 1
				k = _dyn_next[k]
	return count


func _in_standing(point: Vector2) -> bool:
	"""Whether `point` lies inside a standing resident's circle at the link inflation."""
	if _standing_count == 0:
		return false
	var pad := _max_hit_m
	var count := _stand_grid.query(point - Vector2(pad, pad), point + Vector2(pad, pad), _stand_hits)
	for k in count:
		var circle := _standing[_stand_hits[k]]
		if Vector2(circle.x, circle.z).distance_to(point) < circle.y + _link_body + LINK_MARGIN_M:
			return true
	return false


func _hits_for_graph() -> PackedInt32Array:
	"""The scratch array node queries write into, sized for the current graph."""
	if _node_hits.size() < _graph.nodes.size():
		_node_hits.resize(_graph.nodes.size())
	return _node_hits


func _position(node: int) -> Vector2:
	"""Where a node stands: static nodes first, then the plan's own (start, goal, rings)."""
	var statics := _graph.nodes.size()
	return _graph.nodes[node] if node < statics else _dynamic[node - statics]


func _expand_static(u: int) -> void:
	"""A static node: its graph edges (each tested against the standing residents within an edge's length of it), then
	the plan's nodes."""
	var at := _graph.nodes[u]
	var listed := _scan_standing(at, GraphScript.EDGE_MAX_M)
	for e in range(_graph.adj_first[u], _graph.adj_first[u + 1]):
		var v := _graph.adj_to[e]
		if _closed[v] == 0 and _cost[u] + at.distance_to(_graph.nodes[v]) < _cost[v]:
			if (listed == 0 or not _listed_hit(at, _graph.nodes[v], listed)) and not _fresh_hit(at, _graph.nodes[v]):
				_relax(u, v)
	_link_dynamic(u, at)


func _expand_dynamic(u: int) -> void:
	"""One of the plan's own nodes: the static nodes within its reach, then the plan's other nodes."""
	var at := _position(u)
	var reach := _dynamic_reach[u - _graph.nodes.size()]
	var listed := _scan_standing(at, reach)
	var count := _graph.nodes_near(at, reach, _hits_for_graph())
	for k in count:
		var v := _node_hits[k]
		var d := at.distance_to(_graph.nodes[v])
		if _closed[v] == 0 and d <= reach and _cost[u] + d < _cost[v] \
				and not segment_hits_obstacle(at, _graph.nodes[v], _link_body, LINK_MARGIN_M, _start, _goal, true) \
				and (listed == 0 or not _listed_hit(at, _graph.nodes[v], listed)):
			_relax(u, v)
	_link_dynamic(u, at)


func _link_dynamic(u: int, at: Vector2) -> void:
	"""Offer the plan's own nodes within reach (the start and goal, the rings in the cells round u) a route through u."""
	var statics := _graph.nodes.size()
	var count := _dyn_near(at)
	for i in count:
		var k := _cand[i]
		var v := statics + k
		var d := at.distance_to(_dynamic[k])
		if v != u and _closed[v] == 0 and d <= _dynamic_reach[k] and _cost[u] + d < _cost[v] and _dynamic_edge_clear(at, _dynamic[k]):
			_relax(u, v)


func _relax(u: int, v: int) -> void:
	"""Route v through u, and queue it by cost plus the estimate of the way left (`estimate`)."""
	_cost[v] = _cost[u] + _position(u).distance_to(_position(v))
	_parent[v] = u
	_push(v, _cost[v] + estimate(v))


func estimate(v: int) -> float:
	"""The search's estimate of the way left from node `v`: the guiding field's, where it reached v and v is past
	FIELD_NEAR_M from the goal (see ONE FIELD PER SHARED GOAL), else the straight line to the goal."""
	if v < _h_field.size() and _h_field[v] != INF and _graph.nodes[v].distance_to(_goal) > FIELD_NEAR_M:
		return _h_field[v]
	return _position(v).distance_to(_goal)


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


# --- a goal shut in (see A GOAL SHUT IN) -------------------------------------------------------------

func _goal_crowded() -> bool:
	"""Whether the goal may be shut in (see A GOAL SHUT IN): tucked into a circle's reach -- a pocket the padded graph may
	not enter -- or GOAL_CROWD or more standing residents within GOAL_CROWD_M of it."""
	if not point_open(_goal, _link_body, LINK_MARGIN_M):
		return true
	if _standing_count < GOAL_CROWD:
		return false
	var pad := Vector2(GOAL_CROWD_M, GOAL_CROWD_M)
	var count := _stand_grid.query(_goal - pad, _goal + pad, _stand_hits)
	var near := 0
	for k in count:
		near += 1 if _stand_pos[_stand_hits[k]].distance_to(_goal) <= GOAL_CROWD_M else 0
	return near >= GOAL_CROWD


func _begin_shut_in() -> void:
	"""Start the look from the goal's side: the goal marked and queued."""
	_phase = PHASE_SHUT_IN
	var total := _cost.size()
	_back_marked.resize(total)
	_back_marked.fill(0)
	if _back_queue.size() < total:
		_back_queue.resize(total)
	var goal := _graph.nodes.size() + 1
	_back_marked[goal] = 1
	_back_queue[0] = goal
	_back_head = 0
	_back_tail = 1
	_back_spent = 0


func _step_shut_in(max_expansions: int) -> int:
	"""Carry the look from the goal's side on by at most `max_expansions`: done when it reaches the start (a route may
	exist: search), spends SHUT_IN_EXPANSIONS (it cannot tell: search) or runs out of nodes to reach (the goal is shut
	in: no route). The expansions spent."""
	var done := 0
	while _back_head < _back_tail and done < max_expansions:
		var x := _back_queue[_back_head]
		_back_head += 1
		done += 1
		_back_spent += 1
		if _expand_back(x) or _back_spent >= SHUT_IN_EXPANSIONS:
			_phase = PHASE_SEARCH
			return done
	if _back_head >= _back_tail:
		_phase = PHASE_SEARCH
		_state = PLAN_NONE
	return done


func _expand_back(x: int) -> bool:
	"""Mark every node with a link INTO node `x`, tested as the search tests it from that node's side. True when the
	start is one of them."""
	var at := _position(x)
	if x < _graph.nodes.size():
		_back_statics_of_static(x, at)
		return _back_dynamics(at, -1.0)
	var reach := _dynamic_reach[x - _graph.nodes.size()]
	var listed := _scan_standing(at, reach, reach)
	var count := _graph.nodes_near(at, reach, _hits_for_graph())
	for k in count:
		var v := _node_hits[k]
		if _back_marked[v] == 0 and at.distance_to(_graph.nodes[v]) <= reach \
				and not segment_hits_obstacle(at, _graph.nodes[v], _link_body, LINK_MARGIN_M, _start, _goal, true) \
				and (listed == 0 or not _listed_hit(at, _graph.nodes[v], listed)):
			_back_mark(v)
	return _back_dynamics(at, reach)


func _back_statics_of_static(x: int, at: Vector2) -> void:
	"""Static node `x`'s graph neighbours whose edge to it the search would take (the edge's tests are the same both
	ways)."""
	var listed := _scan_standing(at, GraphScript.EDGE_MAX_M)
	for e in range(_graph.adj_first[x], _graph.adj_first[x + 1]):
		var v := _graph.adj_to[e]
		if _back_marked[v] == 0 and (listed == 0 or not _listed_hit(at, _graph.nodes[v], listed)) \
				and not _fresh_hit(at, _graph.nodes[v]):
			_back_mark(v)


func _back_dynamics(at: Vector2, reach: float) -> bool:
	"""The plan's own nodes with a link into the node at `at`: each within its own reach of it (`reach` < 0: a static
	node's), or within `reach` (a node of the plan's own) -- every one of them, past the cells' look, for the goal's
	LINK_M. True when the start is one of them."""
	var statics := _graph.nodes.size()
	var count := _dynamic.size() if reach > LOCAL_LINK_M else _dyn_near(at)
	for i in count:
		var k := i if reach > LOCAL_LINK_M else _cand[i]
		var v := statics + k
		var limit := _dynamic_reach[k] if reach < 0.0 else reach
		if _back_marked[v] == 0 and at.distance_to(_dynamic[k]) <= limit and _dynamic_edge_clear(_dynamic[k], at):
			if k == 0:
				return true
			_back_mark(v)
	return false


func _back_mark(v: int) -> void:
	"""Node `v` reaches the goal: marked, and queued to look further from."""
	_back_marked[v] = 1
	_back_queue[_back_tail] = v
	_back_tail += 1


# --- goal fields (see ONE FIELD PER SHARED GOAL) ---------------------------------------------------

func _field_slot(goal: Vector2, body: float) -> int:
	"""The kept field for `goal` on this body's graph as it is now (-1: none), marked used."""
	var graph := ensure_graph(body)
	for k in _field_goal.size():
		if _field_goal[k] == goal and _field_graph[k] == graph:
			_field_clock += 1
			_field_used[k] = _field_clock
			return k
	return -1


func _begin_field(goal: Vector2, body: float) -> void:
	"""Start the goal's field: the search outward from `goal` over the static graph, its rings and nobody standing."""
	_phase = PHASE_FIELD
	_state = PLAN_PENDING
	_begin(goal, goal, body, _no_standing, 0)
	_prepare_search(false)
	var statics := _graph.nodes.size()
	_cost[statics] = 0.0
	_push(statics, 0.0)


func _step_field(max_expansions: int) -> int:
	"""Carry the field's search on by at most `max_expansions`; once every node it reaches is closed, keep the field and
	begin the plan it guides. The expansions spent."""
	var statics := _graph.nodes.size()
	var done := 0
	while _heap_size > 0 and done < max_expansions:
		var u := _pop()
		if _closed[u] != 0:
			continue
		_closed[u] = 1
		done += 1
		if u < statics:
			_expand_static(u)
		else:
			_expand_dynamic(u)
	if _heap_size == 0:
		_h_field = _keep_field()
		_h_graph = _graph
		_begin_search(_req_from, _req_to, _req_body, _req_standing, _req_count)
	return done


func _keep_field() -> PackedFloat32Array:
	"""The finished field's distances (per static node; INF unreached), kept in the least lately used slot."""
	var dist := _cost.slice(0, _graph.nodes.size())
	var slot := _field_goal.size()
	if slot >= FIELD_SLOTS:
		slot = 0
		for k in FIELD_SLOTS:
			if _field_used[k] < _field_used[slot]:
				slot = k
	else:
		_field_goal.append(Vector2.ZERO)
		_field_graph.append(null)
		_field_dist.append(PackedFloat32Array())
		_field_used.append(0)
	_field_clock += 1
	_field_goal[slot] = _goal
	_field_graph[slot] = _graph
	_field_dist[slot] = dist
	_field_used[slot] = _field_clock
	fields_built += 1
	return dist


func _drop_fields() -> void:
	"""Forget every field kept (the circles changed)."""
	_field_goal.clear()
	_field_graph.clear()
	_field_dist.clear()
	_field_used.clear()


func fields_kept() -> int:
	"""How many goals' fields are kept."""
	return _field_goal.size()


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
