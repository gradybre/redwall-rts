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
## wherever its x/z lies. `tunnels` is the tunnel network (underground_graph.gd, decision 0208), and
## `plan_path` routes a resident through the open segments it fits when that is genuinely shorter
## (tunnel_router.gd) -- or, given a network node, to that node underground. Inside a bore each
## resident's place is kept too (`resident_tunnel`: its segment, `resident_along`, `resident_heading`),
## so those sharing one keep their distance (`room_ahead`, `oncoming`).
##
## IN THE WATER (demo/waterplay/). A resident swimming, diving or wading out on a crossing is off the
## walking surface the same way: `set_in_water` flags it in `resident_underground` (nobody separates
## from it or plans round it) and in `resident_in_water`, but it stays drawn. `crossings` is the water's
## crossing hook (cast/crossing_hook.gd): `plan_path` also routes a resident over a finished bridge or,
## a swimmer, across the water when that is quicker; the base hook offers nothing.
##
## TUNNEL MOUTHS AND HEAPS. Nobody is sent to STAND on a planned mouth: a formation keeps off them
## (`mouth_circles`), a mole stepping out of its exit keeps off them (`on_mouth`), and no mouth may
## open on a work spot (tunnel_rules); nor over an opened mouth's open cutting (decision 0371). Walks may cross a hole's
## rim and a cutting -- planning round every mouth
## was measured at five times the cost of a plan (16 more circles to ring on every search), for a
## glance's difference. A spoil heap is a real obstacle: `set_heap` adds it to the world's
## circles, and each body class's navigation graph is rebuilt in slices over the next frames (cast_nav.gd
## REBUILT IN SLICES; once per dig accepted, never per frame). Heaps stand one per mouth (`set_heap`, by
## mouth row). A room's turfed MOUND and its door ramp are obstacles too, from the moment it is laid
## (`set_mound`, MOUND_CIRCLES by room row; decision 0209): nobody walks over a burrow home or its dig -- in
## at its door, round it otherwise.
##
## Per-frame work (`constrain`, `separation`, `line_clear`) allocates nothing.

const CastNavScript := preload("res://demo/cast/cast_nav.gd")
const CastRoutinesScript := preload("res://demo/cast/cast_routines.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const TunnelRules := preload("res://demo/tunnel/tunnel_rules.gd")
const RoomsScript := preload("res://demo/burrow/underground_rooms.gd")
const CrossingHookScript := preload("res://demo/cast/crossing_hook.gd")
const RouteDeskScript := preload("res://demo/cast/route_desk.gd")
const MouthScript := preload("res://demo/tunnel/tunnel_mouth.gd")
const PropsScript := preload("res://demo/props/demo_props.gd")

const PLAN_MARGIN_M: float = CastNavScript.PLAN_MARGIN_M
const GOAL_EPSILON_M: float = CastNavScript.GOAL_EPSILON_M
const SLOT_SPACING_M: float = 1.2
## A slot must stand this far clear of every obstacle edge, or another spot is tried.
const SLOT_CLEARANCE_M: float = 0.3
## ROOM FOR THE BODY (playtest 2026-09-29, decision 0205). Every slot then keeps the widest body
## registered here plus this margin clear of every obstacle edge -- the margin an ordered spot keeps
## (cast_orders.gd CLEAR_MARGIN_M; a preload there would be a cycle, so the suite pins the two equal).
## Before this the slots kept only SLOT_CLEARANCE_M whatever the body: the stockpile's stood 0.37 m
## off its building (0.42 m where the badger came to rest), the cauldron's 0.40 m, for the badger's
## 0.56 m body, which then stopped short of them. (Its giving an order up with a neighbour beside it
## was the stockpile's pocket: world_layout.gd POINTS.)
const SLOT_BODY_MARGIN_M: float = 0.12
## A slot short of that room is walked straight out from the nearest edge, at most this many times: a
## push can land it near the next circle of a building's ring, and one pass leaves a village slot short
## (the suite's every-slot test fails at 1); six is headroom, run once per wider body at build.
const SLOT_PUSH_PASSES: int = 6
const SEPARATION_MARGIN_M: float = 0.55
const MAX_SLOTS: int = 16
const CONSTRAIN_PASSES: int = 2
## A room's mound as obstacle circles: up to this many a room (see TUNNEL MOUTHS AND HEAPS).
const MOUND_CIRCLES: int = 4
## Surface structures placed during play: one circle each, at most this many. The cellar buildings take slots 0 and 1
## (demo_stores.gd FIRST_STRUCTURE, decision 0612) and the infirmary the last (infirmary_building.gd STRUCTURE, decision
## 0623); the two lanes' identical hunks were merged once at the batch 7 integration (decision 0902).
const STRUCTURES: int = 4
const STOCKPILE_WORDS: PackedStringArray = ["stockpile", "store", "storage", "pile", "crate", "sack", "log"]
const CARRY_CLIP: StringName = &"carry_heavy_object_walk"
const LOCOMOTION_CLIPS: Array[StringName] = [&"walk", &"carry_heavy_object_walk"]

var obstacles: PackedVector3Array = PackedVector3Array()
## How many times the obstacles (and so the navigation) have been rebuilt: by a heap's or a room's mound's change,
## never per frame (a count for the tests and the probes).
var obstacle_builds: int = 0
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
## Off the walking surface: in a tunnel, or in the water (see UNDERGROUND and IN THE WATER).
var resident_underground: PackedByteArray = PackedByteArray()
## In the water (swimming, diving, towed): off the surface, but drawn.
var resident_in_water: PackedByteArray = PackedByteArray()
## Inside a bore: which tunnel (-1 on the surface), how far along it (m) and which way (+1 toward the
## exit, -1 toward the entrance).
var resident_tunnel: PackedInt32Array = PackedInt32Array()
var resident_along: PackedFloat32Array = PackedFloat32Array()
var resident_heading: PackedInt32Array = PackedInt32Array()
## The walkable area (x, z); unbounded until DemoCast.set_bounds.
var bounds: Rect2 = Rect2(-1e4, -1e4, 2e4, 2e4)
var nav: CastNavScript = CastNavScript.new()
## Each bore class's forecourt half-width as the mouths draw it (`court_half_m`, `set_props`).
var _court_half: PackedFloat32Array = PackedFloat32Array()
var tunnels: GraphScript = GraphScript.new()
## The water's crossings (see IN THE WATER); the base offers none.
var crossings: CrossingHookScript = CrossingHookScript.new()
## The widest body registered so far (m): every slot is placed with room for it (see ROOM FOR THE BODY).
var slot_body_m: float = 0.0
## Route planning spread over frames (route_desk.gd, decision 0361): every plan is charged to the frame's window, and
## a trip start waits its turn once the window's budget is spent. No budget unless the live scene gives one.
var routes: RouteDeskScript = RouteDeskScript.new()

var _slot_at: PackedVector2Array = PackedVector2Array()
var _standing: PackedVector3Array = PackedVector3Array()
var _world_obstacles: PackedVector3Array = PackedVector3Array()
var _heap_circles: PackedVector3Array = PackedVector3Array()
var _mound_circles: PackedVector3Array = PackedVector3Array()
var _structure_circles: PackedVector3Array = PackedVector3Array()


func setup(points: Array[Dictionary], obstacle_list: Array[Vector3]) -> void:
	"""Take the world's POIs and obstacle circles (x, radius, z). Clears every resident and reservation."""
	obstacles.clear()
	for circle in obstacle_list:
		if circle.y > 0.0:
			obstacles.append(circle)
		else:
			push_error("demo cast: obstacle at (%.2f, %.2f) has radius %.3f; a circle is (x, radius, z) -- ignored" % [circle.x, circle.z, circle.y])
	_world_obstacles = obstacles.duplicate()
	_heap_circles.resize(TunnelRules.MAX_MOUTHS)
	_heap_circles.fill(Vector3.ZERO)
	_mound_circles.resize(RoomsScript.MAX_ROOMS * MOUND_CIRCLES)
	_mound_circles.fill(Vector3.ZERO)
	_structure_circles.resize(STRUCTURES)
	_structure_circles.fill(Vector3.ZERO)
	nav.setup(obstacles)
	_clear_pois()
	for point in points:
		_add_poi(point)
	poi_used.resize(poi_position.size())
	poi_used.fill(0)
	slot_body_m = 0.0
	_place_slots()
	resident_position.clear()
	resident_radius.clear()
	resident_walking.clear()
	resident_underground.clear()
	resident_in_water.clear()
	resident_tunnel.clear()
	resident_along.clear()
	resident_heading.clear()
	tunnels = GraphScript.new()
	_renew_routes()


func _renew_routes() -> void:
	"""A fresh routing desk for a fresh cast (nobody registered or waiting), keeping the budget it was given."""
	var budget := routes.budget_usec
	routes = RouteDeskScript.new()
	routes.budget_usec = budget


func set_heap(m: int, circle: Vector3) -> void:
	"""Mouth `m`'s heap now stands as this circle (x, radius, z); radius 0 removes it. The obstacles are
	rebuilt, and each body class's graph with them, in slices (cast_nav.gd REBUILT IN SLICES)."""
	_heap_circles[m] = circle
	_rebuild_obstacles()


func set_mound(r: int, circles: PackedVector3Array) -> void:
	"""Room `r`'s mound and door ramp now stand as these circles (x, radius, z; at most MOUND_CIRCLES; empty:
	none). The obstacles are rebuilt as a heap's are."""
	assert(circles.size() <= MOUND_CIRCLES, "a room's mound stands as at most MOUND_CIRCLES circles")
	for k in MOUND_CIRCLES:
		_mound_circles[r * MOUND_CIRCLES + k] = circles[k] if k < circles.size() else Vector3.ZERO
	_rebuild_obstacles()


func set_structure(s: int, circle: Vector3) -> void:
	"""Surface structure `s` (0..STRUCTURES-1; a cellar building or the infirmary) now stands as this circle (x, radius,
	z); radius 0 removes it. The obstacles are rebuilt as a heap's are."""
	_structure_circles[s] = circle
	_rebuild_obstacles()


func structure_circles() -> PackedVector3Array:
	"""Every standing structure's circle (x, radius, z): what a tunnel may not pass under (decision 0612)."""
	var out := PackedVector3Array()
	for circle in _structure_circles:
		if circle.y > 0.0:
			out.append(circle)
	return out


func _rebuild_obstacles() -> void:
	"""The world's circles, every heap and every room's mound: the obstacles, and the navigation over them."""
	obstacle_builds += 1
	obstacles = _world_obstacles.duplicate()
	for circle in _heap_circles:
		if circle.y > 0.0:
			obstacles.append(circle)
	for circle in _mound_circles:
		if circle.y > 0.0:
			obstacles.append(circle)
	for circle in _structure_circles:
		if circle.y > 0.0:
			obstacles.append(circle)
	nav.setup(obstacles)


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
	"""Register a resident standing at `at`; returns its index. A body wider than any before re-places
	the slots with room for it (ROOM FOR THE BODY) -- at build, before anyone is sent to one."""
	resident_position.append(at)
	resident_radius.append(radius)
	resident_walking.append(0)
	resident_underground.append(0)
	resident_in_water.append(0)
	resident_tunnel.append(-1)
	resident_along.append(0.0)
	resident_heading.append(0)
	_standing.resize(resident_position.size())
	nav.ensure_graph(radius)
	if radius > slot_body_m:
		slot_body_m = radius
		_place_slots()
	return resident_position.size() - 1


func move_resident(index: int, at: Vector2) -> void:
	"""Record where a resident now stands."""
	resident_position[index] = at


func set_walking(index: int, walking: bool) -> void:
	"""Whether a resident is under way (a walker is not planned around; a standing resident is)."""
	resident_walking[index] = 1 if walking else 0


func set_underground(index: int, underground: bool) -> void:
	"""Whether a resident is inside a tunnel, and so off the surface (see UNDERGROUND). Coming up
	clears its place in the bore."""
	resident_underground[index] = 1 if underground else 0
	if not underground:
		resident_tunnel[index] = -1


func set_in_water(index: int, in_water: bool) -> void:
	"""Whether a resident is in the water (see IN THE WATER): off the walking surface, but not in a bore."""
	resident_in_water[index] = 1 if in_water else 0
	resident_underground[index] = 1 if in_water else 0
	resident_tunnel[index] = -1


func set_in_bore(index: int, slot: int, along_m: float, heading: int) -> void:
	"""Where a resident is inside tunnel `slot`: `along_m` from its entrance, heading +1 or -1."""
	resident_tunnel[index] = slot
	resident_along[index] = along_m
	resident_heading[index] = heading


func room_ahead(index: int, gap: float) -> float:
	"""How far resident `index` may walk on in its bore before closing to `gap` (between bodies) behind
	someone ahead going the same way -- on its segment, or past the node it is heading for, walking away
	from it on a segment beyond (so a follower keeps its distance across a ramp's foot or a junction);
	INF with nobody ahead."""
	var room := INF
	for j in resident_position.size():
		var ahead := _ahead_m(index, j, true)
		if ahead > 0.0:
			room = minf(room, maxf(ahead - resident_radius[index] - resident_radius[j] - gap, 0.0))
	return room


func oncoming(index: int, window: float) -> bool:
	"""Whether someone in resident `index`'s bore -- or past the node it is heading for, walking toward it --
	is coming the other way within `window` metres ahead."""
	for j in resident_position.size():
		var ahead := _ahead_m(index, j, false)
		if ahead > -resident_radius[index] and ahead < window:
			return true
	return false


func _ahead_m(index: int, j: int, same_way: bool) -> float:
	"""How far resident j is ahead of resident `index` along the bores (m; negative behind), when j walks the
	same way (`same_way`) or the other way: on index's own segment, or on another segment at the node index
	is heading for. Someone standing still counts as coming the other way, on its own segment or past the
	node (so it is passed, never queued behind, whichever way that segment was drawn). -INF when j is neither
	(or not in a bore)."""
	var slot := resident_tunnel[index]
	var other := resident_tunnel[j]
	if j == index or other < 0 or slot < 0:
		return -INF
	if other == slot:
		if (resident_heading[j] == resident_heading[index]) != same_way:
			return -INF
		return (resident_along[j] - resident_along[index]) * float(resident_heading[index])
	var node := tunnels.node_b[slot] if resident_heading[index] > 0 else tunnels.node_a[slot]
	var from_a := tunnels.node_a[other] == node
	if not from_a and tunnels.node_b[other] != node:
		return -INF
	var leaving := resident_heading[j] != 0 and (resident_heading[j] > 0) == from_a
	if leaving != same_way:
		return -INF
	return _to_node_m(index, node) + _to_node_m(j, node)


func _to_node_m(index: int, node: int) -> float:
	"""How far along its segment resident `index` stands from `node`, one of the segment's ends (m)."""
	var slot := resident_tunnel[index]
	return resident_along[index] if tunnels.node_a[slot] == node else tunnels.length_m(slot) - resident_along[index]


func on_mouth(at: Vector2, body: float) -> bool:
	"""Whether a body of radius `body` standing at `at` would overlap any mouth's hole and rim (a planned one's
	too), or stand over an opened mouth's open cutting and the arch at its foot (tunnel_mouth.gd, decision 0371)."""
	var reach := body + TunnelRules.HOLE_RADIUS_M * TunnelRules.RIM_FACTOR
	for m in TunnelRules.MAX_MOUTHS:
		if not tunnels.is_mouth(m):
			continue
		if tunnels.mouth_at(m).distance_squared_to(at) < reach * reach or _over_cutting(m, at, body):
			return true
	return false


func _over_cutting(m: int, at: Vector2, body: float) -> bool:
	"""Whether a body at `at` overlaps mouth `m`'s open cutting or its forecourt, out to the far side of the arch over
	its foot (tunnel_mouth.gd `cutting_gap`)."""
	if not tunnels.mouth_opened(m):
		return false
	var bore := int(tunnels.bore[tunnels.mouth_ramp(m)])
	return MouthScript.cutting_gap(tunnels, m, at, court_half_m(bore), 0.0) < body


func court_half_m(bore: int) -> float:
	"""How far either side of a bore class's cutting its forecourt opens (m): as the mouths draw it, the staged arch's
	piers once `set_props` has the table (tunnel_mouth.gd `court_half_m`)."""
	if _court_half.size() <= bore:
		set_props(null)
	return _court_half[bore]


func set_props(props: PropsScript) -> void:
	"""The props table the mouths are drawn with (tunnel_ext.gd): the forecourts' width follows its arch."""
	_court_half.resize(TunnelRules.BORE_WIDTHS_U.size())
	for bore in _court_half.size():
		_court_half[bore] = MouthScript.court_half_m(props, bore)


func mouth_circles() -> PackedVector3Array:
	"""Every planned tunnel mouth as a circle (x, rim radius, z), for an order to keep clear of (once
	per click; allocates)."""
	var out := PackedVector3Array()
	out.resize(TunnelRules.MAX_MOUTHS)
	out.resize(tunnels.mouth_circles_into(out, 0))
	return out


func surface_occupied(index: int, at: Vector2, clearance: float) -> bool:
	"""Whether anyone on the surface but `index` stands closer to `at` than resident `index`'s radius
	plus theirs plus `clearance`."""
	for j in resident_position.size():
		if j == index or resident_underground[j] != 0:
			continue
		var reach := resident_radius[index] + resident_radius[j] + clearance
		if resident_position[j].distance_squared_to(at) < reach * reach:
			return true
	return false


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
	SLOT_CLEARANCE_M of an obstacle edge goes behind the POI instead, away from what it faces; then
	any slot short of room for the widest body is walked out until it has it (ROOM FOR THE BODY)."""
	_slot_at.resize(poi_position.size() * MAX_SLOTS)
	var need := slot_room_m()
	for poi in poi_position.size():
		var face := poi_face[poi] if poi_face[poi] != Vector2.ZERO else Vector2(0.0, 1.0)
		var across := Vector2(-face.y, face.x)
		for slot in poi_capacity[poi]:
			var offset := (float(slot) - float(poi_capacity[poi] - 1) * 0.5) * SLOT_SPACING_M
			var at := poi_position[poi] + across * offset
			if obstacle_clearance(at) < SLOT_CLEARANCE_M:
				at = poi_position[poi] - face * SLOT_SPACING_M * float(slot)
			_slot_at[poi * MAX_SLOTS + slot] = room_for(at, need)


func slot_room_m() -> float:
	"""How far clear of every obstacle edge each slot stands: the widest registered body and
	SLOT_BODY_MARGIN_M (never below SLOT_CLEARANCE_M)."""
	return maxf(SLOT_CLEARANCE_M, slot_body_m + SLOT_BODY_MARGIN_M)


func room_for(at: Vector2, need: float) -> Vector2:
	"""`at`, or the spot it reaches walking straight out from its nearest obstacle edge (at most
	SLOT_PUSH_PASSES times) until it stands `need` clear of every edge. A spot boxed in so that no
	pass clears it keeps the last one tried: the plan's goal shrink still reaches it (see the header).
	Only circles push: a spot held short by the water's edge alone stays put."""
	for pass_index in SLOT_PUSH_PASSES:
		if obstacle_clearance(at) >= need:
			return at
		var o := _nearest_circle(at)
		var centre := Vector2(o.x, o.z)
		if o.y <= 0.0 or centre.distance_to(at) - o.y >= need:
			return at
		var out := at - centre
		if out.length_squared() < 1e-12:
			out = Vector2(0.0, 1.0)
		at = centre + out.normalized() * (o.y + need)
	return at


func _nearest_circle(at: Vector2) -> Vector3:
	"""The obstacle circle whose edge is nearest `at` (x, radius, z), or Vector3.ZERO (radius 0) with
	none in reach."""
	var pad := nav.max_radius + SLOT_SPACING_M * 4.0
	var count := nav.circles_near(at - Vector2(pad, pad), at + Vector2(pad, pad))
	var best := Vector3.ZERO
	var best_edge := INF
	for k in count:
		var o := obstacles[nav.hit(k)]
		var edge := Vector2(o.x, o.z).distance_to(at) - o.y
		if edge < best_edge:
			best_edge = edge
			best = o
	return best


func obstacle_clearance(at: Vector2) -> float:
	"""Distance from `at` to the nearest obstacle edge -- or the water's edge (crossing_hook.gd STANDING):
	negative inside one; INF with none near. Every spot a resident is sent to stand at asks this."""
	var pad := nav.max_radius + SLOT_SPACING_M * 4.0
	var count := nav.circles_near(at - Vector2(pad, pad), at + Vector2(pad, pad))
	var best := crossings.water_clearance_m(at)
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
		legs: PackedInt32Array = PackedInt32Array(), allow_tunnels: bool = true, loaded: bool = false,
		goal_node: int = -1) -> void:
	"""Fill `out` with waypoints from `from` (excluded) to `to` (last), round every obstacle and every
	standing resident but `index`, and `legs` with each waypoint's leg code (-1 on the surface, or the
	segment or crossing walked to reach it: tunnel_router.gd). Resident `index` is routed through the
	network's open segments when `allow_tunnels`, their bores fit it (with its load, when `loaded`) and that
	is quicker -- and over whatever crossing `crossings` offers it (see IN THE WATER). With `goal_node` >= 0
	the trip ends at that node underground (`to` is its place), and only the network reaches it. Falls back
	to the straight line when no route exists (nothing, for a goal underground); `nav.last_found` says
	whether one did."""
	var count := _gather_standing(index)
	if goal_node >= 0:
		nav.last_found = tunnels.plan(nav, from, to, body_radius, _standing, count, out, legs, index, loaded,
			null, true, goal_node)
		return
	var use_tunnels := allow_tunnels and tunnels.open_count() > 0 and tunnels.fits_any(index, loaded)
	var use_crossings := crossings.offers_for(index, from, to, loaded)
	if not use_tunnels and not use_crossings:
		nav.plan(from, to, body_radius, _standing, count, out)
		legs.resize(out.size())
		legs.fill(-1)
		return
	nav.last_found = tunnels.plan(nav, from, to, body_radius, _standing, count, out, legs, index, loaded,
		crossings if use_crossings else null, use_tunnels)


func _gather_standing(index: int) -> int:
	"""Every resident but `index` standing still on the surface, as circles into _standing; how many."""
	var count := 0
	for j in resident_position.size():
		if j != index and resident_walking[j] == 0 and resident_underground[j] == 0:
			_standing[count] = Vector3(resident_position[j].x, resident_radius[j], resident_position[j].y)
			count += 1
	return count


func mouth_clear(index: int, m: int, hold_m: float) -> bool:
	"""Whether resident `index` may step into mouth row `m`: nobody else in its ramp within `hold_m` of the
	hole, and nobody else on the surface standing on it."""
	var ramp := tunnels.mouth_ramp(m)
	var end_m := tunnels.length_m(ramp) if tunnels.mouth_end_at_b(ramp) else 0.0
	for j in resident_position.size():
		if j != index and resident_tunnel[j] == ramp and absf(resident_along[j] - end_m) < hold_m:
			return false
	return not surface_occupied(index, tunnels.mouth_at(m), 0.05)


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
