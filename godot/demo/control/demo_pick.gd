extends RefCounted
## Picking math for the demo's select-and-command layer. Decision 0196. Pure functions, no nodes.
##
## A resident is picked by a camera ray against a body-sized CAPSULE PROXY -- a vertical capsule
## standing on its feet, of the resident's height and body radius -- tested analytically. The
## architecture forbids a physics body per resident, so nothing here touches the physics server.
## The ground is the plane y = 0.

## A drag shorter than this, in pixels, is a click rather than a box.
const DRAG_THRESHOLD_PX: float = 6.0
const PARALLEL_EPSILON: float = 1e-9


static func ray_capsule(origin: Vector3, direction: Vector3, foot: Vector3, height: float, radius: float) -> float:
	"""Distance along a unit ray to where it first enters a vertical capsule standing at `foot`
	(`height` tall, `radius` wide), or -1 for a miss or a hit behind the origin."""
	var a := foot + Vector3(0.0, radius, 0.0)
	var b := foot + Vector3(0.0, maxf(height - radius, radius), 0.0)
	var t := _ray_cylinder(origin, direction, a, b, radius)
	if t < 0.0:
		t = _ray_sphere(origin, direction, a, radius)
		var top := _ray_sphere(origin, direction, b, radius)
		if top >= 0.0 and (t < 0.0 or top < t):
			t = top
	return t


static func _ray_cylinder(origin: Vector3, direction: Vector3, a: Vector3, b: Vector3, radius: float) -> float:
	"""Entry distance into the side of the finite cylinder a-b, or -1."""
	var axis := b - a
	var rel := origin - a
	var aa := axis.dot(axis)
	var ad := axis.dot(direction)
	var ar := axis.dot(rel)
	var qa := aa - ad * ad
	if qa < PARALLEL_EPSILON:
		return -1.0
	var qb := aa * direction.dot(rel) - ar * ad
	var qc := aa * rel.dot(rel) - ar * ar - radius * radius * aa
	var h := qb * qb - qa * qc
	if h < 0.0:
		return -1.0
	var t := (-qb - sqrt(h)) / qa
	var along := ar + t * ad
	return t if t >= 0.0 and along > 0.0 and along < aa else -1.0


static func _ray_sphere(origin: Vector3, direction: Vector3, centre: Vector3, radius: float) -> float:
	"""Entry distance into a sphere along a unit ray, or -1."""
	var rel := origin - centre
	var b := rel.dot(direction)
	var h := b * b - (rel.dot(rel) - radius * radius)
	if h < 0.0:
		return -1.0
	var t := -b - sqrt(h)
	return t if t >= 0.0 else -1.0


static func nearest_hit(origin: Vector3, direction: Vector3, feet: PackedVector3Array, heights: PackedFloat32Array,
		radii: PackedFloat32Array) -> int:
	"""The index of the capsule the ray enters first, or -1 when it enters none."""
	var best := -1
	var best_t := INF
	for i in feet.size():
		var t := ray_capsule(origin, direction, feet[i], heights[i], radii[i])
		if t >= 0.0 and t < best_t:
			best_t = t
			best = i
	return best


static func ray_ground(origin: Vector3, direction: Vector3, ground_y: float) -> float:
	"""Distance along the ray to the ground plane, or -1 when it points level or upward."""
	if direction.y > -1e-6:
		return -1.0
	var t := (ground_y - origin.y) / direction.y
	return t if t >= 0.0 else -1.0


static func is_drag(from: Vector2, to: Vector2) -> bool:
	"""Whether the pointer moved far enough between press and now to be a box, not a click."""
	return from.distance_to(to) >= DRAG_THRESHOLD_PX


static func box_members(screen: PackedVector2Array, on_screen: PackedByteArray, corner_a: Vector2, corner_b: Vector2,
		out: PackedInt32Array) -> int:
	"""Write the index of every on-screen point inside the box with these corners into `out`; return
	the count. `out` must be at least as long as `screen`."""
	var box := Rect2(corner_a, Vector2.ZERO).expand(corner_b)
	var count := 0
	for i in screen.size():
		if on_screen[i] != 0 and box.has_point(screen[i]):
			out[count] = i
			count += 1
	return count
