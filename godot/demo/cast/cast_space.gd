extends RefCounted
## The ground the demo cast shares: points of interest and their slots, obstacle circles, and where
## every resident stands. Decision 0196. Presentation only -- nothing here feeds the simulation.
##
## Positions are on the flat ground plane as Vector2(x, z), in metres. An obstacle is the world's
## Vector3(x, radius, z): x and z are the circle's centre, y its radius.
##
## ---------------------------------------------------------------------------------------
## NEVER WALK INTO A CIRCLE. Two layers keep a resident out of an obstacle:
##   * `plan_path()` routes each trip around every circle, inflated by the walker's body radius and
##     a margin, on a visibility graph of points ringed round each circle. Residents standing still
##     (working, idling, turning on the spot) count as circles too, so a walker plans round someone
##     at the well rather than walking into them. It runs once per trip, and again when blocked.
##   * `constrain()` runs every frame and is exact: a resident's centre never comes closer to an
##     obstacle's centre than its radius plus the body radius, nor to another resident than their
##     two radii. It is MONOTONE -- a resident already closer than that (spawned there, or a POI
##     placed tight against a building) may move away but never further in -- so nothing pops.
##   A POI inside an inflated circle would be unreachable, so the inflation is shrunk to leave the
##   trip's goal just outside it, and never below the obstacle's own radius.
##
## Per-frame work (`constrain`, `separation`, `segment_clear`) allocates nothing. Planning reuses
## member arrays and runs only when a trip starts.

const RING_POINTS: int = 6
const PLAN_MARGIN_M: float = 0.18
const GOAL_EPSILON_M: float = 0.03
const SLOT_SPACING_M: float = 1.2
const SEPARATION_MARGIN_M: float = 0.55
const MAX_SLOTS: int = 16
const STOCKPILE_WORDS: PackedStringArray = ["stockpile", "store", "storage", "pile", "crate", "sack", "log"]
const CARRY_CLIP: StringName = &"carry_heavy_object_walk"
const LOCOMOTION_CLIPS: Array[StringName] = [&"walk", &"carry_heavy_object_walk"]

var obstacles: PackedVector3Array = PackedVector3Array()
var poi_names: Array[StringName] = []
var poi_position: PackedVector2Array = PackedVector2Array()
var poi_face: PackedVector2Array = PackedVector2Array()
var poi_capacity: PackedInt32Array = PackedInt32Array()
var poi_used: PackedInt32Array = PackedInt32Array()
var poi_stockpile: PackedByteArray = PackedByteArray()
var poi_activities: Array[Array] = []
var resident_position: PackedVector2Array = PackedVector2Array()
var resident_radius: PackedFloat32Array = PackedFloat32Array()
var resident_walking: PackedByteArray = PackedByteArray()

var _circles: PackedVector3Array = PackedVector3Array()
var _plan_radius: PackedFloat32Array = PackedFloat32Array()
var _nodes: PackedVector2Array = PackedVector2Array()
var _cost: PackedFloat32Array = PackedFloat32Array()
var _parent: PackedInt32Array = PackedInt32Array()
var _closed: PackedByteArray = PackedByteArray()


func setup(points: Array[Dictionary], obstacle_list: Array[Vector3]) -> void:
	"""Take the world's POIs and obstacle circles. Clears every resident and reservation."""
	obstacles = PackedVector3Array(obstacle_list)
	poi_names.clear()
	poi_position.clear()
	poi_face.clear()
	poi_capacity.clear()
	poi_stockpile.clear()
	poi_activities.clear()
	for point in points:
		_add_poi(point)
	poi_used.resize(poi_position.size())
	poi_used.fill(0)
	resident_position.clear()
	resident_radius.clear()
	resident_walking.clear()


func _add_poi(point: Dictionary) -> void:
	"""One POI: flatten its position and face, keep its stationary activities, spot a stockpile."""
	var name := StringName(point.get("name", &""))
	var at: Vector3 = point.get("position", Vector3.ZERO)
	var face: Vector3 = point.get("face", Vector3.ZERO)
	var activities: Array[StringName] = []
	var carries := is_stockpile_name(name)
	for activity in point.get("activities", []):
		var clip := StringName(activity)
		if clip == CARRY_CLIP:
			carries = true
		if not LOCOMOTION_CLIPS.has(clip):
			activities.append(clip)
	poi_names.append(name)
	poi_position.append(Vector2(at.x, at.z))
	poi_face.append(Vector2(face.x, face.z).normalized())
	poi_capacity.append(clampi(int(point.get("capacity", 1)), 0, MAX_SLOTS))
	poi_stockpile.append(1 if carries else 0)
	poi_activities.append(activities)


static func is_stockpile_name(name: StringName) -> bool:
	"""Whether a POI's name reads as somewhere goods are stacked, so a trip away may carry them."""
	var lower := String(name).to_lower()
	for word in STOCKPILE_WORDS:
		if lower.contains(word):
			return true
	return false


# --- residents ------------------------------------------------------------------------------

func add_resident(at: Vector2, radius: float) -> int:
	"""Register a resident standing at `at`; returns its index."""
	resident_position.append(at)
	resident_radius.append(radius)
	resident_walking.append(0)
	return resident_position.size() - 1


func move_resident(index: int, at: Vector2) -> void:
	"""Record where a resident now stands."""
	resident_position[index] = at


func set_walking(index: int, walking: bool) -> void:
	"""Whether a resident is under way (a walker is not planned around; a standing resident is)."""
	resident_walking[index] = 1 if walking else 0


func separation(index: int, at: Vector2, forward: Vector2) -> Vector2:
	"""Soft push away from nearby residents, plus a pass-on-the-right nudge for anyone ahead."""
	var push := Vector2.ZERO
	var radius := resident_radius[index]
	for j in resident_position.size():
		if j == index:
			continue
		var offset := at - resident_position[j]
		var reach := radius + resident_radius[j] + SEPARATION_MARGIN_M
		var d := offset.length()
		if d >= reach or d < 1e-5:
			continue
		var weight := 1.0 - d / reach
		push += offset / d * weight
		if forward.dot(-offset) > 0.0:
			push += Vector2(-forward.y, forward.x) * weight
	return push


func constrain(index: int, from: Vector2, to: Vector2, goal: Vector2) -> Vector2:
	"""Where a resident moving `from` -> `to` may actually stand: out of every other resident, then
	out of every obstacle (obstacles win). Monotone, so it never pushes anyone further out than they
	were."""
	var radius := resident_radius[index]
	var at := to
	for j in resident_position.size():
		if j != index:
			var other := resident_position[j]
			at = _keep_out(other, radius + resident_radius[j], from, at)
	for i in obstacles.size():
		var o := obstacles[i]
		var centre := Vector2(o.x, o.z)
		var reach := maxf(o.y, minf(o.y + radius, centre.distance_to(goal) - GOAL_EPSILON_M))
		at = _keep_out(centre, reach, from, at)
	return at if _clear_of_residents(index, from, at) else from


func _clear_of_residents(index: int, from: Vector2, at: Vector2) -> bool:
	"""Whether `at` (after an obstacle pushed it) still keeps the monotone distance to every resident."""
	var radius := resident_radius[index]
	for j in resident_position.size():
		if j == index:
			continue
		var other := resident_position[j]
		var limit := minf(radius + resident_radius[j], other.distance_to(from))
		if other.distance_to(at) < limit - 1e-4:
			return false
	return true


static func _keep_out(centre: Vector2, reach: float, from: Vector2, at: Vector2) -> Vector2:
	"""`at`, moved out to min(reach, from's own distance) from `centre` if it came closer than that."""
	var limit := minf(reach, centre.distance_to(from))
	var offset := at - centre
	var d := offset.length()
	if d >= limit:
		return at
	if d < 1e-6:
		offset = from - centre
		d = maxf(offset.length(), 1e-6)
	return centre + offset / d * limit


# --- points of interest ---------------------------------------------------------------------

func free_slot(poi: int) -> int:
	"""The lowest free slot at `poi`, or -1 when it is full."""
	for slot in poi_capacity[poi]:
		if poi_used[poi] & (1 << slot) == 0:
			return slot
	return -1


func reserve(poi: int, slot: int) -> void:
	"""Take one slot at a POI."""
	poi_used[poi] = poi_used[poi] | (1 << slot)


func release(poi: int, slot: int) -> void:
	"""Give a slot back. Harmless for poi -1."""
	if poi >= 0 and slot >= 0:
		poi_used[poi] = poi_used[poi] & ~(1 << slot)


func occupancy(poi: int) -> int:
	"""How many slots at `poi` are taken."""
	var count := 0
	for slot in poi_capacity[poi]:
		if poi_used[poi] & (1 << slot) != 0:
			count += 1
	return count


func slot_position(poi: int, slot: int) -> Vector2:
	"""Where a slot stands: slots line up side by side across the POI's face direction."""
	var face := poi_face[poi]
	if face == Vector2.ZERO:
		face = Vector2(0.0, 1.0)
	var across := Vector2(-face.y, face.x)
	var offset := (float(slot) - float(poi_capacity[poi] - 1) * 0.5) * SLOT_SPACING_M
	return poi_position[poi] + across * offset


func choose_poi(current: int, rng: RandomNumberGenerator) -> int:
	"""A uniformly chosen POI other than `current` with a free slot, or -1 if there is none."""
	var open := 0
	for poi in poi_position.size():
		if poi != current and free_slot(poi) >= 0:
			open += 1
	if open == 0:
		return -1
	var pick := rng.randi_range(0, open - 1)
	for poi in poi_position.size():
		if poi != current and free_slot(poi) >= 0:
			if pick == 0:
				return poi
			pick -= 1
	return -1


# --- planning -------------------------------------------------------------------------------

func plan_path(index: int, from: Vector2, to: Vector2, body_radius: float, out: PackedVector2Array) -> void:
	"""Fill `out` with waypoints from `from` (excluded) to `to` (last), round every obstacle and every
	standing resident but `index`. Falls back to the straight line when no route exists;
	`constrain()` still keeps the walker out."""
	out.clear()
	_gather_circles(index, from, to, body_radius)
	if segment_clear(from, to):
		out.append(to)
		return
	_ring_nodes(from, to)
	if not _search():
		out.append(to)
		return
	var chain := PackedInt32Array()
	var node := 1
	while node > 0:
		chain.append(node)
		node = _parent[node]
	for k in range(chain.size() - 1, -1, -1):
		out.append(_nodes[chain[k]])


func _gather_circles(index: int, from: Vector2, to: Vector2, body_radius: float) -> void:
	"""This plan's circles -- obstacles, then standing residents other than `index` -- each with its
	planning radius: inflated by body and margin, shrunk to leave start and goal outside."""
	_circles.clear()
	_circles.append_array(obstacles)
	for j in resident_position.size():
		if j != index and resident_walking[j] == 0:
			_circles.append(Vector3(resident_position[j].x, resident_radius[j], resident_position[j].y))
	_plan_radius.resize(_circles.size())
	for i in _circles.size():
		_plan_radius[i] = maxf(_inflated(_circles[i], body_radius, from, to), 0.0)


static func _inflated(circle: Vector3, body_radius: float, from: Vector2, goal: Vector2) -> float:
	"""A circle's radius plus body and margin, shrunk to leave `from` and `goal` just outside it."""
	var centre := Vector2(circle.x, circle.z)
	var reach := circle.y + body_radius + PLAN_MARGIN_M
	reach = minf(reach, centre.distance_to(goal) - GOAL_EPSILON_M)
	return minf(reach, centre.distance_to(from) - GOAL_EPSILON_M)


func segment_clear(a: Vector2, b: Vector2) -> bool:
	"""Whether the segment a-b stays outside every circle of the last plan at its planning radius."""
	for i in _circles.size():
		var o := _circles[i]
		var r := _plan_radius[i]
		if r <= 0.0:
			continue
		if minf(a.x, b.x) > o.x + r or maxf(a.x, b.x) < o.x - r or minf(a.y, b.y) > o.z + r or maxf(a.y, b.y) < o.z - r:
			continue
		if distance_to_segment(Vector2(o.x, o.z), a, b) < r - 1e-4:
			return false
	return true


func line_clear(index: int, a: Vector2, b: Vector2, body_radius: float, goal: Vector2) -> bool:
	"""Per-frame sight test for walker `index` heading to `goal`: whether a-b clears every obstacle and
	standing resident, inflated as a plan inflates them. Uses no shared plan state; allocates nothing."""
	for i in obstacles.size():
		if _blocks(obstacles[i], body_radius, a, b, goal):
			return false
	for j in resident_position.size():
		if j != index and resident_walking[j] == 0:
			var at := resident_position[j]
			if _blocks(Vector3(at.x, resident_radius[j], at.y), body_radius, a, b, goal):
				return false
	return true


static func _blocks(circle: Vector3, body_radius: float, a: Vector2, b: Vector2, goal: Vector2) -> bool:
	"""Whether segment a-b cuts `circle` at its planning radius."""
	var r := _inflated(circle, body_radius, a, goal)
	return r > 0.0 and distance_to_segment(Vector2(circle.x, circle.z), a, b) < r - 1e-4


static func distance_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	"""Distance from p to the closest point of segment a-b."""
	var ab := b - a
	var length_sq := ab.length_squared()
	var t := 0.0 if length_sq < 1e-12 else clampf((p - a).dot(ab) / length_sq, 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _ring_nodes(from: Vector2, to: Vector2) -> void:
	"""Node 0 is the start, node 1 the goal, then RING_POINTS round each circle that lie in the open."""
	_nodes.clear()
	_nodes.append(from)
	_nodes.append(to)
	var outward := 1.0 / cos(PI / RING_POINTS) * 1.02
	for i in _circles.size():
		var o := _circles[i]
		var ring := _plan_radius[i] * outward + 0.02
		for k in RING_POINTS:
			var angle := TAU * (float(k) + 0.5) / RING_POINTS
			var point := Vector2(o.x + cos(angle) * ring, o.z + sin(angle) * ring)
			if _in_open(point):
				_nodes.append(point)


func _in_open(point: Vector2) -> bool:
	"""Whether a point lies outside every circle's planning radius."""
	for i in _circles.size():
		var o := _circles[i]
		if Vector2(o.x, o.z).distance_to(point) < _plan_radius[i]:
			return false
	return true


func _search() -> bool:
	"""A* from node 0 to node 1 over the visibility graph, edges tested lazily. Fills _parent."""
	var count := _nodes.size()
	_cost.resize(count)
	_cost.fill(INF)
	_parent.resize(count)
	_parent.fill(-1)
	_closed.resize(count)
	_closed.fill(0)
	_cost[0] = 0.0
	while true:
		var u := _cheapest_open()
		if u < 0:
			return false
		if u == 1:
			return true
		_closed[u] = 1
		_relax(u)
	return false


func _cheapest_open() -> int:
	"""The open node with the lowest cost plus straight-line distance to the goal, or -1."""
	var best := -1
	var best_f := INF
	var goal := _nodes[1]
	for v in _nodes.size():
		if _closed[v] == 0 and _cost[v] < INF:
			var f := _cost[v] + _nodes[v].distance_to(goal)
			if f < best_f:
				best_f = f
				best = v
	return best


func _relax(u: int) -> void:
	"""Offer every node still open a route through u, testing sight only when it would be cheaper."""
	var at := _nodes[u]
	for v in _nodes.size():
		if _closed[v] != 0:
			continue
		var cost := _cost[u] + at.distance_to(_nodes[v])
		if cost < _cost[v] and segment_clear(at, _nodes[v]):
			_cost[v] = cost
			_parent[v] = u
