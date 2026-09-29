extends RefCounted
## The ground the demo cast shares: points of interest and their slots, obstacle circles, and where
## every resident stands. Decision 0196. Presentation only -- nothing here feeds the simulation.
##
## Positions are on the flat ground plane as Vector2(x, z), in metres. An obstacle is the world's
## Vector3(x, radius, z): x and z are the circle's centre, y its radius.
##
## ---------------------------------------------------------------------------------------
## NEVER WALK INTO A CIRCLE. Two layers keep a resident out of an obstacle:
##   * `plan_path()` routes each trip round every circle and every resident standing still, inflated
##     by the walker's body radius and a margin (cast_nav.gd: a static visibility graph per body
##     class built once, plus the trip's own start, goal and standing residents).
##   * `constrain()` runs every frame and is exact: a resident's centre never comes closer to an
##     obstacle's centre than its radius plus the body radius, nor to another resident than their
##     two radii. It is MONOTONE -- a resident already closer than that (spawned there, or a POI
##     placed tight against a building) may move away but never further in -- so nothing pops. A
##     step that one push would resolve only by shoving the walker into something else is refused
##     outright, so nobody squeezes through a gap narrower than their body.
##   A POI tucked against a building would be unreachable, so the inflation is shrunk to leave the
##   trip's goal just outside it, and never below the obstacle's own radius.
##
## A circle whose radius is not positive is refused at setup (push_error) and ignored.
##
## UNDERGROUND. A resident inside a tunnel (demo/tunnel/) is flagged in `resident_underground` and
## is not on the surface at all: nobody separates from it, is constrained by it or plans round it,
## wherever its x/z lies. `tunnels` holds the finished tunnels, and `plan_path` routes a resident who
## fits their bore through them when that is genuinely shorter (tunnel_router.gd).
##
## Per-frame work (`constrain`, `separation`, `line_clear`) allocates nothing.

const CastNavScript := preload("res://demo/cast/cast_nav.gd")
const CastRoutinesScript := preload("res://demo/cast/cast_routines.gd")
const TunnelNetworkScript := preload("res://demo/tunnel/tunnel_network.gd")

const PLAN_MARGIN_M: float = CastNavScript.PLAN_MARGIN_M
const GOAL_EPSILON_M: float = CastNavScript.GOAL_EPSILON_M
const SLOT_SPACING_M: float = 1.2
## A slot must stand this far clear of every obstacle edge, or another spot is tried.
const SLOT_CLEARANCE_M: float = 0.3
const SEPARATION_MARGIN_M: float = 0.55
const MAX_SLOTS: int = 16
const CONSTRAIN_PASSES: int = 2
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
var resident_underground: PackedByteArray = PackedByteArray()
var nav: CastNavScript = CastNavScript.new()
var tunnels: TunnelNetworkScript = TunnelNetworkScript.new()

var _slot_at: PackedVector2Array = PackedVector2Array()
var _standing: PackedVector3Array = PackedVector3Array()


func setup(points: Array[Dictionary], obstacle_list: Array[Vector3]) -> void:
	"""Take the world's POIs and obstacle circles (x, radius, z). Clears every resident and reservation."""
	obstacles.clear()
	for circle in obstacle_list:
		if circle.y > 0.0:
			obstacles.append(circle)
		else:
			push_error("demo cast: obstacle at (%.2f, %.2f) has radius %.3f; a circle is (x, radius, z) -- ignored" % [circle.x, circle.z, circle.y])
	nav.setup(obstacles)
	_clear_pois()
	for point in points:
		_add_poi(point)
	poi_used.resize(poi_position.size())
	poi_used.fill(0)
	_place_slots()
	resident_position.clear()
	resident_radius.clear()
	resident_walking.clear()
	resident_underground.clear()
	tunnels = TunnelNetworkScript.new()


func _clear_pois() -> void:
	"""Forget every POI."""
	poi_names.clear()
	poi_position.clear()
	poi_face.clear()
	poi_capacity.clear()
	poi_stockpile.clear()
	poi_activities.clear()


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
	resident_underground.append(0)
	_standing.resize(resident_position.size())
	nav.ensure_graph(radius)
	return resident_position.size() - 1


func move_resident(index: int, at: Vector2) -> void:
	"""Record where a resident now stands."""
	resident_position[index] = at


func set_walking(index: int, walking: bool) -> void:
	"""Whether a resident is under way (a walker is not planned around; a standing resident is)."""
	resident_walking[index] = 1 if walking else 0


func set_underground(index: int, underground: bool) -> void:
	"""Whether a resident is inside a tunnel, and so off the surface (see UNDERGROUND)."""
	resident_underground[index] = 1 if underground else 0


func separation(index: int, at: Vector2, forward: Vector2) -> Vector2:
	"""Soft push away from nearby residents, plus a pass-on-the-right nudge for anyone ahead."""
	var push := Vector2.ZERO
	var radius := resident_radius[index]
	for j in resident_position.size():
		if j == index or resident_underground[j] != 0:
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
	"""Where a resident moving `from` -> `to` may actually stand: pushed out of every other resident and
	every obstacle, twice over so it can slide along a corner. Monotone, so it never pushes anyone
	further out than they were; a step that still ends too deep in anything is refused (`from`)."""
	var radius := resident_radius[index]
	var pad := nav.max_radius + radius
	var count := nav.circles_near(to.min(from) - Vector2(pad, pad), to.max(from) + Vector2(pad, pad))
	var at := to
	for pass_index in CONSTRAIN_PASSES:
		at = _push_from_residents(index, from, at)
		for k in count:
			var o := obstacles[nav.hit(k)]
			at = _keep_out(Vector2(o.x, o.z), _obstacle_reach(o, radius, goal), from, at)
	if _clear_of_residents(index, from, at) and _clear_of_obstacles(count, radius, from, at, goal):
		return at
	return from


func _obstacle_reach(o: Vector3, radius: float, goal: Vector2) -> float:
	"""How close a body may come to an obstacle's centre: radius + body, shrunk (never below the
	obstacle's own radius) to leave the trip's goal just outside."""
	return maxf(o.y, minf(o.y + radius, Vector2(o.x, o.z).distance_to(goal) - GOAL_EPSILON_M))


func _push_from_residents(index: int, from: Vector2, at: Vector2) -> Vector2:
	"""`at` pushed out of every other resident's circle (monotone)."""
	var radius := resident_radius[index]
	for j in resident_position.size():
		if j != index and resident_underground[j] == 0:
			at = _keep_out(resident_position[j], radius + resident_radius[j], from, at)
	return at


func _clear_of_obstacles(count: int, radius: float, from: Vector2, at: Vector2, goal: Vector2) -> bool:
	"""Whether `at` keeps the monotone distance to every obstacle from the last circles_near() query."""
	for k in count:
		var o := obstacles[nav.hit(k)]
		var centre := Vector2(o.x, o.z)
		var limit := minf(_obstacle_reach(o, radius, goal), centre.distance_to(from))
		if centre.distance_to(at) < limit - 1e-4:
			return false
	return true


func _clear_of_residents(index: int, from: Vector2, at: Vector2) -> bool:
	"""Whether `at` keeps the monotone distance to every other resident."""
	var radius := resident_radius[index]
	for j in resident_position.size():
		if j == index or resident_underground[j] != 0:
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
	"""How many reservation bits at `poi` are set -- all of them, so a bit past capacity shows."""
	var bits := poi_used[poi]
	var count := 0
	while bits != 0:
		bits &= bits - 1
		count += 1
	return count


func slot_position(poi: int, slot: int) -> Vector2:
	"""Where a slot stands (worked out at setup; see _place_slots)."""
	return _slot_at[poi * MAX_SLOTS + slot]


func _place_slots() -> void:
	"""Slots line up side by side across each POI's face direction. A slot that would stand within
	SLOT_CLEARANCE_M of an obstacle edge goes behind the POI instead, away from what it faces."""
	_slot_at.resize(poi_position.size() * MAX_SLOTS)
	for poi in poi_position.size():
		var face := poi_face[poi] if poi_face[poi] != Vector2.ZERO else Vector2(0.0, 1.0)
		var across := Vector2(-face.y, face.x)
		for slot in poi_capacity[poi]:
			var offset := (float(slot) - float(poi_capacity[poi] - 1) * 0.5) * SLOT_SPACING_M
			var at := poi_position[poi] + across * offset
			if obstacle_clearance(at) < SLOT_CLEARANCE_M:
				at = poi_position[poi] - face * SLOT_SPACING_M * float(slot)
			_slot_at[poi * MAX_SLOTS + slot] = at


func obstacle_clearance(at: Vector2) -> float:
	"""Distance from `at` to the nearest obstacle edge (negative inside one; INF with none near)."""
	var pad := nav.max_radius + SLOT_SPACING_M * 4.0
	var count := nav.circles_near(at - Vector2(pad, pad), at + Vector2(pad, pad))
	var best := INF
	for k in count:
		var o := obstacles[nav.hit(k)]
		best = minf(best, Vector2(o.x, o.z).distance_to(at) - o.y)
	return best


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


func choose_poi_from(pool: PackedInt32Array, current: int, at: Vector2, rng: RandomNumberGenerator) -> int:
	"""A POI from `pool` (every POI when empty) other than `current`, with a free slot, drawn with
	weight 1 / (1 + distance / NEAR_M) from `at`; -1 when none is open."""
	var total := 0.0
	for k in _pool_size(pool):
		var poi := pool[k] if not pool.is_empty() else k
		if poi != current and free_slot(poi) >= 0:
			total += CastRoutinesScript.weight(at.distance_to(poi_position[poi]))
	if total <= 0.0:
		return -1
	var pick := rng.randf() * total
	var last := -1
	for k in _pool_size(pool):
		var poi := pool[k] if not pool.is_empty() else k
		if poi != current and free_slot(poi) >= 0:
			last = poi
			pick -= CastRoutinesScript.weight(at.distance_to(poi_position[poi]))
			if pick <= 0.0:
				return poi
	return last


func _pool_size(pool: PackedInt32Array) -> int:
	"""How many entries a pool has (an empty pool means every POI)."""
	return pool.size() if not pool.is_empty() else poi_position.size()


# --- planning -------------------------------------------------------------------------------

func plan_path(index: int, from: Vector2, to: Vector2, body_radius: float, out: PackedVector2Array,
		legs: PackedInt32Array = PackedInt32Array(), allow_tunnels: bool = true) -> void:
	"""Fill `out` with waypoints from `from` (excluded) to `to` (last), round every obstacle and every
	standing resident but `index`, and `legs` with each waypoint's leg code (-1 on the surface, or the
	tunnel crossed to reach it: tunnel_router.gd). Resident `index` is routed through a finished
	tunnel when `allow_tunnels` (not while carrying), it fits the bore and that is shorter. Falls
	back to the straight line when no route exists; `nav.last_found` says whether one did, with or
	without tunnels."""
	var count := 0
	for j in resident_position.size():
		if j != index and resident_walking[j] == 0 and resident_underground[j] == 0:
			_standing[count] = Vector3(resident_position[j].x, resident_radius[j], resident_position[j].y)
			count += 1
	if not allow_tunnels or tunnels.open_count() == 0 or not tunnels.fits(index):
		nav.plan(from, to, body_radius, _standing, count, out)
		legs.resize(out.size())
		legs.fill(-1)
		return
	nav.last_found = tunnels.plan(nav, from, to, body_radius, _standing, count, out, legs)


func line_clear(index: int, a: Vector2, b: Vector2, body_radius: float, goal: Vector2) -> bool:
	"""Per-frame sight test for walker `index` heading to `goal`: whether a-b clears every obstacle and
	standing resident, inflated as a plan inflates them (shrunk to leave `a` and the goal outside)."""
	if nav.segment_hits_obstacle(a, b, body_radius, PLAN_MARGIN_M, a, goal, true):
		return false
	return not standing_blocks(index, a, b, body_radius, goal, CastNavScript.LINK_MARGIN_M)


func standing_blocks(index: int, a: Vector2, b: Vector2, body_radius: float, goal: Vector2, margin: float) -> bool:
	"""Whether a resident standing still (not `index`) is in the way of segment a-b, by the walker's
	own body radius plus `margin` (negative for a tolerance), shrunk to leave `a` and the goal outside.
	Allocates nothing."""
	for j in resident_position.size():
		if j != index and resident_walking[j] == 0 and resident_underground[j] == 0:
			var at := resident_position[j]
			var r := CastNavScript.inflated(Vector3(at.x, resident_radius[j], at.y), body_radius, margin, a, goal, true)
			if r > 0.0 and CastNavScript.distance_to_segment(at, a, b) < r - 1e-4:
				return true
	return false


static func distance_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	"""Distance from p to the closest point of segment a-b."""
	return CastNavScript.distance_to_segment(p, a, b)
