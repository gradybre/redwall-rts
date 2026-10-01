extends RefCounted
## The pure maths of keeping tree crowns out of the camera's way. Decision 0301 (review F53). Static,
## float, presentation only; demo/camera/canopy_clear.gd drives it.
##
## A CROWN is a tree's leafy volume: an ellipsoid (centre height, horizontal and vertical half-axes) cut
## off below its BASE, all MEASURED from the staged models at size 1 after the world's sink (decision
## 0301 records the probe): the oak's crown runs from 2.6 m to 11.8 m, widest (6.4 m) at 5-6.5 m; the
## beech's from 5.5 m to 14.5 m, widest (4.2 m) at 6.5-9.5 m. A tree's crown scales with its size (and a
## young tree's with its share, forest_view.gd GROWING).
##
## `eye_direction` is the orbit rig's own (demo_camera.gd: the camera sits back along the rig's +Z, up by
## the pitch, the rig turned by yaw). `ray_enters` answers where a ray first enters a crown;
## `segment_crosses` whether a sight line passes through one. Crowns live packed, STRIDE floats each
## ([cx, cy, cz, radius, half_height, base_y]) in one array the caller keeps, so nothing is allocated
## per test; `k` is a crown's index in it.

## Per StandScript.LOOK_* (oak, beech), at size 1.
const CROWN_CENTRE_M: PackedFloat32Array = [6.0, 8.5]
const CROWN_RADIUS_M: PackedFloat32Array = [6.6, 4.4]
const CROWN_HALF_HEIGHT_M: PackedFloat32Array = [6.0, 6.0]
const CROWN_BASE_M: PackedFloat32Array = [2.6, 5.5]
## No ray meets a crown: `ray_enters` returns this.
const MISS: float = INF
## Floats per packed crown.
const STRIDE: int = 6


static func eye_direction(yaw: float, pitch: float) -> Vector3:
	"""The unit vector from the focus to the orbit camera's eye: Basis(UP, yaw) * (0, sin p, cos p)."""
	return Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))


static func set_crown(crowns: PackedFloat32Array, k: int, look: int, at: Vector2, size: float, inflate: float) -> void:
	"""Write crown `k`: a tree of `look` at `at` drawn at `size`, grown by `inflate` m all round (a size of
	0 writes an empty crown that nothing enters)."""
	var i: int = k * STRIDE
	crowns[i] = at.x
	crowns[i + 1] = CROWN_CENTRE_M[look] * size
	crowns[i + 2] = at.y
	crowns[i + 3] = CROWN_RADIUS_M[look] * size + inflate if size > 0.0 else 0.0
	crowns[i + 4] = CROWN_HALF_HEIGHT_M[look] * size + inflate if size > 0.0 else 0.0
	crowns[i + 5] = CROWN_BASE_M[look] * size - inflate


static func contains(crowns: PackedFloat32Array, k: int, p: Vector3, grow: float = 0.0) -> bool:
	"""Whether `p` lies inside crown `k` (inside its ellipsoid, at or above its base), the crown grown by
	`grow` m all round."""
	var i: int = k * STRIDE
	if crowns[i + 3] <= 0.0 or p.y < crowns[i + 5] - grow:
		return false
	var dx: float = (p.x - crowns[i]) / (crowns[i + 3] + grow)
	var dy: float = (p.y - crowns[i + 1]) / (crowns[i + 4] + grow)
	var dz: float = (p.z - crowns[i + 2]) / (crowns[i + 3] + grow)
	return dx * dx + dy * dy + dz * dz <= 1.0


static func ray_enters(crowns: PackedFloat32Array, k: int, origin: Vector3, direction: Vector3) -> float:
	"""How far along a unit ray from `origin` it first lies inside crown `k` (0 if it starts inside, MISS
	if it never does)."""
	var span: Vector2 = ray_span(crowns, k, origin, direction)
	return span.x


static func ray_span(crowns: PackedFloat32Array, k: int, origin: Vector3, direction: Vector3) -> Vector2:
	"""Where along a unit ray from `origin` it is inside crown `k`: (enters, leaves), the ellipsoid's span
	cut to the half-space above the base and to t >= 0; (MISS, MISS) if it never is."""
	var i: int = k * STRIDE
	if crowns[i + 3] <= 0.0:
		return Vector2(MISS, MISS)
	var o := Vector3((origin.x - crowns[i]) / crowns[i + 3], (origin.y - crowns[i + 1]) / crowns[i + 4],
		(origin.z - crowns[i + 2]) / crowns[i + 3])
	var d := Vector3(direction.x / crowns[i + 3], direction.y / crowns[i + 4], direction.z / crowns[i + 3])
	var a: float = d.dot(d)
	var b: float = o.dot(d)
	var disc: float = b * b - a * (o.dot(o) - 1.0)
	if a <= 0.0 or disc < 0.0:
		return Vector2(MISS, MISS)
	var t0: float = (-b - sqrt(disc)) / a
	var t1: float = (-b + sqrt(disc)) / a
	var base: float = crowns[i + 5]
	if direction.y > 0.0:
		t0 = maxf(t0, (base - origin.y) / direction.y)
	elif direction.y < 0.0:
		t1 = minf(t1, (base - origin.y) / direction.y)
	elif origin.y < base:
		return Vector2(MISS, MISS)
	t0 = maxf(t0, 0.0)
	return Vector2(t0, t1) if t0 <= t1 else Vector2(MISS, MISS)


static func segment_crosses(crowns: PackedFloat32Array, k: int, from: Vector3, to: Vector3) -> bool:
	"""Whether the sight line from `from` to `to` passes through crown `k`."""
	var span: Vector3 = to - from
	var length: float = span.length()
	if length <= 0.0001:
		return contains(crowns, k, from)
	return ray_enters(crowns, k, from, span / length) <= length
