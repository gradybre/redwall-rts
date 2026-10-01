extends RefCounted
## Group orders for the demo cast: where a selection stands when sent somewhere, and who works
## where when sent to a POI. Decision 0196; the select-and-command layer is demo/control/.
##
## ---------------------------------------------------------------------------------------
## A FORMATION IS A SPIRAL OF CANDIDATE SPOTS. The clicked point first, then rings of 6k spots at
## k spacings, where the spacing lets the widest body in the group stand beside any other with a
## gap. A spot is taken when it is inside the bounds, clear of every obstacle by the body and a
## margin, clear of every resident standing there already and every tunnel mouth (nobody is sent
## to stand in a hole), a spacing from every spot taken, and REACHABLE -- the planner finds a route to it. So a click inside a building or off the map snaps
## to the nearest spots that satisfy all of that; a click with none within FORMATION_MAX_M is
## refused. Residents are then matched to spots greedily, nearest pair first, so few paths cross.
##
## Distances are measured from where each resident STANDS ON THE SURFACE -- for one in a tunnel,
## the mouth it will come up at (resident_brain.surface_point) -- never from its place underground.
##
## A WORK ORDER uses the POI's own free slots, nearest resident first; anyone beyond them holds in
## a formation behind the POI (away from what it faces). Every order goes through the brain, which
## releases whatever slot the resident held, so the reservation bits stay exact.
##
## All of this runs once per click, never per frame.

const CastSpaceScript := preload("res://demo/cast/cast_space.gd")
const BrainScript := preload("res://demo/cast/resident_brain.gd")

## Gap between two bodies standing side by side in a formation.
const FORMATION_GAP_M: float = 0.35
## A formation spot keeps at least the body radius plus this from every obstacle edge.
const CLEAR_MARGIN_M: float = 0.12
## How far from the clicked point a formation may spread (or a click may snap) before refusing.
const FORMATION_MAX_M: float = 8.0
## A right-click within this of a POI (or one of its slots) is a work order there.
const POI_PICK_M: float = 1.1
## Overflow from a work order holds this far behind the POI.
const OVERFLOW_BACK_M: float = 1.8


static func spacing_for(body: float) -> float:
	"""Centre-to-centre spacing of a formation whose widest body has radius `body`."""
	return 2.0 * body + FORMATION_GAP_M


static func formation_slots(space: CastSpaceScript, center: Vector2, count: int, body: float, bounds: Rect2,
		avoid: PackedVector3Array, reach_from: Vector2, out: PackedVector2Array) -> bool:
	"""Fill `out` with `count` distinct spots near `center` (see the header). False when fewer fit."""
	out.clear()
	var spacing := spacing_for(body)
	var ring := 0
	while out.size() < count and float(ring) * spacing <= FORMATION_MAX_M:
		var points := maxi(1, 6 * ring)
		for k in points:
			var angle := TAU * float(k) / float(points) + 0.5 * float(ring)
			var spot := center + Vector2(cos(angle), sin(angle)) * (float(ring) * spacing)
			if out.size() < count and spot_ok(space, spot, body, bounds, avoid, out, reach_from):
				out.append(spot)
		ring += 1
	return out.size() == count


static func spot_ok(space: CastSpaceScript, spot: Vector2, body: float, bounds: Rect2, avoid: PackedVector3Array,
		taken: PackedVector2Array, reach_from: Vector2) -> bool:
	"""Whether a body of radius `body` may be ordered to stand at `spot` (see the header)."""
	if not bounds.grow(-body).has_point(spot):
		return false
	if space.obstacle_clearance(spot) < body + CLEAR_MARGIN_M:
		return false
	var spacing := spacing_for(body)
	for other in taken:
		if other.distance_to(spot) < spacing - 1e-4:
			return false
	for circle in avoid:
		if Vector2(circle.x, circle.z).distance_to(spot) < circle.y + body + FORMATION_GAP_M:
			return false
	var route := PackedVector2Array()
	space.nav.plan(reach_from, spot, body, PackedVector3Array(), 0, route)
	return space.nav.last_found


static func match_nearest(from: PackedVector2Array, to: PackedVector2Array) -> PackedInt32Array:
	"""For each `from` point, the index of a `to` point, pairing the closest remaining pair first."""
	var out := PackedInt32Array()
	out.resize(from.size())
	out.fill(-1)
	var used := PackedByteArray()
	used.resize(to.size())
	for pairs in mini(from.size(), to.size()):
		var best := INF
		var best_i := -1
		var best_j := -1
		for i in from.size():
			for j in to.size():
				if out[i] < 0 and used[j] == 0 and from[i].distance_to(to[j]) < best:
					best = from[i].distance_to(to[j])
					best_i = i
					best_j = j
		out[best_i] = best_j
		used[best_j] = 1
	return out


static func poi_at(space: CastSpaceScript, point: Vector2) -> int:
	"""The POI whose standing area (its point or any slot) is nearest `point` within POI_PICK_M, or -1."""
	var best := -1
	var best_d := POI_PICK_M
	for poi in space.poi_position.size():
		var d := space.poi_position[poi].distance_to(point)
		for slot in space.poi_capacity[poi]:
			d = minf(d, space.slot_position(poi, slot).distance_to(point))
		if d <= best_d:
			best_d = d
			best = poi
	return best


static func standing_except(space: CastSpaceScript, members: Array[BrainScript]) -> PackedVector3Array:
	"""Circles (x, radius, z) of every resident standing still who is not one of `members`, and of every
	tunnel mouth."""
	var out := space.mouth_circles()
	for j in space.resident_position.size():
		if space.resident_walking[j] == 0 and space.resident_underground[j] == 0 and not _has_index(members, j):
			out.append(Vector3(space.resident_position[j].x, space.resident_radius[j], space.resident_position[j].y))
	return out


static func _has_index(members: Array[BrainScript], index: int) -> bool:
	"""Whether one of `members` is resident `index`."""
	for brain in members:
		if brain.index == index:
			return true
	return false


static func widest(members: Array[BrainScript]) -> float:
	"""The largest body radius among `members`."""
	var body := 0.0
	for brain in members:
		body = maxf(body, brain.radius)
	return body


static func order_move(space: CastSpaceScript, members: Array[BrainScript], point: Vector2, bounds: Rect2,
		face_toward: Vector2 = Vector2.INF) -> PackedVector2Array:
	"""Send `members` to a formation at `point` (turning to face a finite `face_toward` on arrival).
	Returns the spots used (the first is where the order landed), or an empty array when the order
	is refused and nobody moves."""
	var spots := PackedVector2Array()
	if members.is_empty():
		return spots
	var avoid := standing_except(space, members)
	if not formation_slots(space, point, members.size(), widest(members), bounds, avoid, members[0].surface_point(), spots):
		spots.clear()
		return spots
	var from := PackedVector2Array()
	for brain in members:
		from.append(brain.surface_point())
	var pairing := match_nearest(from, spots)
	for i in members.size():
		members[i].order_move(spots[pairing[i]], face_toward)
	return spots


static func order_work(space: CastSpaceScript, members: Array[BrainScript], poi: int, bounds: Rect2) -> int:
	"""Send `members` to work at `poi`: its free slots nearest-first, the rest to hold behind it.
	Returns how many got a slot."""
	for brain in members:
		if brain.poi != poi:
			brain.release_slot()
	var workers := _nearest_first(members, space.poi_position[poi])
	var placed := 0
	var overflow: Array[BrainScript] = []
	for brain in workers:
		var slot := brain.slot if brain.poi == poi else space.free_slot(poi)
		if slot >= 0:
			brain.order_work(poi, slot)
			placed += 1
		else:
			overflow.append(brain)
	if not overflow.is_empty():
		var behind := space.poi_position[poi] - space.poi_face[poi] * OVERFLOW_BACK_M
		if order_move(space, overflow, behind, bounds, space.poi_position[poi]).is_empty():
			for brain in overflow:
				brain.order_move(brain.surface_point(), space.poi_position[poi])
	return placed


static func _nearest_first(members: Array[BrainScript], to: Vector2) -> Array[BrainScript]:
	"""`members` sorted by distance to `to`, nearest first."""
	var out: Array[BrainScript] = members.duplicate()
	out.sort_custom(func(a: BrainScript, b: BrainScript) -> bool:
		return a.surface_point().distance_to(to) < b.surface_point().distance_to(to))
	return out


static func release(members: Array[BrainScript]) -> void:
	"""Hand `members` back to wandering."""
	for brain in members:
		brain.release()
