extends RefCounted
## Deterministic dressing for the demo village: the woodland ring, forest-floor debris and ground
## cover. Decision 0196 (live demo). Presentation only.
##
## Every generator draws from its own RandomNumberGenerator with a FIXED seed and runs a fixed
## number of attempts, so the same layout comes out on every run, every machine and in CI. None
## of it uses the global RNG. Output placements have the same shape as
## `world_layout.gd`'s `normalised()` entries.

const Layout := preload("res://demo/world/world_layout.gd")

const TREE_SEED: int = 1986
const DEBRIS_SEED: int = 1987
const COVER_SEED: int = 1988

## The woods start this far from the square, wobbled by a few metres so the edge is not a circle.
const CLEARING_RADIUS_M: float = 23.0
const CLEARING_WOBBLE_M: float = 2.5
## The woods stand this much further back on the camera side (+Z, south), so the default RTS view
## looks over open ground and the square is not shaded by trees behind the camera.
const SOUTH_OPENING_M: float = 15.0
const WOODS_OUTER_M: float = 62.0
const TREE_ATTEMPTS: int = 2600
const TREE_LIMIT: int = 170
## Minimum trunk-to-trunk spacing, and how far trees stand from paths and buildings.
const TREE_SPACING_M: Dictionary = {&"oak_mature": 6.5, &"beech_mature": 4.6, &"oak_sapling": 2.5}
const TREE_PATH_CLEARANCE_M: float = 2.2
const TREE_BLOCKER_CLEARANCE_M: float = 2.0

const DEBRIS_KEYS: Array[StringName] = [
	&"stump_mossy", &"rock_cluster", &"mossy_boulder", &"fallen_log", &"rock_cluster",
]
const DEBRIS_ATTEMPTS: int = 260
const DEBRIS_LIMIT: int = 34
const DEBRIS_INNER_M: float = 21.0
const DEBRIS_OUTER_M: float = 42.0
const DEBRIS_SPACING_M: float = 3.0

const TUFT_CLUSTERS: int = 320
const TUFTS_PER_CLUSTER_MAX: int = 9
const TUFT_CLUSTER_SPREAD_M: float = 1.3
const COVER_HALF_EXTENT_M: float = 36.0
const MUSHROOM_CLUSTERS: int = 26
## Ground cover keeps this far off paths (negative = may creep onto the worn edge) and POIs.
const COVER_PATH_CLEARANCE_M: float = -0.2
const COVER_POINT_CLEARANCE_M: float = 1.1


static func _rng(seed_value: int) -> RandomNumberGenerator:
	"""A generator with a fixed seed and state, so every run draws the same sequence."""
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


static func clearing_edge(p: Vector2) -> float:
	"""Radius of the clearing edge in the direction of `p`."""
	var angle: float = atan2(p.y, p.x)
	var wobble: float = sin(angle * 3.0 + 0.8) * 0.6 + sin(angle * 7.0 + 2.1) * 0.4
	var south: float = maxf(0.0, sin(angle))
	return CLEARING_RADIUS_M + wobble * CLEARING_WOBBLE_M + SOUTH_OPENING_M * south * south


static func _far_enough(p: Vector2, taken: Array[Vector3]) -> bool:
	"""Whether `p` keeps each earlier pick's spacing (taken: x, z, spacing)."""
	for t: Vector3 in taken:
		if p.distance_to(Vector2(t.x, t.y)) < t.z:
			return false
	return true


static func _tree_key(rng: RandomNumberGenerator, radius: float) -> StringName:
	"""Oak, beech, or -- only near the clearing edge -- a sapling."""
	var roll: float = rng.randf()
	if radius < CLEARING_RADIUS_M + 6.0 and roll < 0.14:
		return &"oak_sapling"
	return &"oak_mature" if roll < 0.58 else &"beech_mature"


static func _tree_site_ok(p: Vector2, blockers: Array[Vector3]) -> bool:
	"""Outside the clearing, off the paths and clear of buildings."""
	if p.length() < clearing_edge(p):
		return false
	if Layout.path_distance(p) < TREE_PATH_CLEARANCE_M:
		return false
	return Layout.clearance(p, blockers) >= TREE_BLOCKER_CLEARANCE_M


static func tree_ring(blockers: Array[Vector3]) -> Array[Dictionary]:
	"""The woodland around the clearing, spaced by species."""
	var rng := _rng(TREE_SEED)
	var out: Array[Dictionary] = []
	var taken: Array[Vector3] = []
	for attempt: int in TREE_ATTEMPTS:
		var p := Vector2(rng.randf_range(-WOODS_OUTER_M, WOODS_OUTER_M),
			rng.randf_range(-WOODS_OUTER_M, WOODS_OUTER_M))
		var key: StringName = _tree_key(rng, p.length())
		var yaw: float = rng.randf_range(-PI, PI)
		var size: float = rng.randf_range(0.82, 1.14)
		if out.size() >= TREE_LIMIT or not _tree_site_ok(p, blockers):
			continue
		if not _far_enough(p, taken):
			continue
		taken.append(Vector3(p.x, p.y, float(TREE_SPACING_M[key]) * size))
		out.append({"id": &"", "key": key, "at": p, "yaw": yaw, "size": size, "block": true})
	return out


static func forest_debris(blockers: Array[Vector3]) -> Array[Dictionary]:
	"""Stumps, rocks, boulders and logs on the forest floor around the clearing."""
	var rng := _rng(DEBRIS_SEED)
	var out: Array[Dictionary] = []
	var taken: Array[Vector3] = []
	for attempt: int in DEBRIS_ATTEMPTS:
		var angle: float = rng.randf_range(-PI, PI)
		var radius: float = rng.randf_range(DEBRIS_INNER_M, DEBRIS_OUTER_M)
		var p := Vector2(cos(angle), sin(angle)) * radius
		var key: StringName = DEBRIS_KEYS[rng.randi_range(0, DEBRIS_KEYS.size() - 1)]
		var yaw: float = rng.randf_range(-PI, PI)
		var size: float = rng.randf_range(0.75, 1.2)
		if out.size() >= DEBRIS_LIMIT or Layout.path_distance(p) < 1.0:
			continue
		if Layout.clearance(p, blockers) < 1.5 or not _far_enough(p, taken):
			continue
		taken.append(Vector3(p.x, p.y, DEBRIS_SPACING_M))
		out.append({"id": &"", "key": key, "at": p, "yaw": yaw, "size": size, "block": true})
	return out


static func _cover_site_ok(p: Vector2, blockers: Array[Vector3], points: Array[Vector2]) -> bool:
	"""Off the worn paths, outside every obstacle and clear of every point of interest."""
	if Layout.path_distance(p) < COVER_PATH_CLEARANCE_M:
		return false
	if Layout.clearance(p, blockers) < 0.0:
		return false
	for point: Vector2 in points:
		if p.distance_to(point) < COVER_POINT_CLEARANCE_M:
			return false
	return true


static func _cluster(rng: RandomNumberGenerator, key: StringName, centre: Vector2, count: int,
		blockers: Array[Vector3], points: Array[Vector2]) -> Array[Dictionary]:
	"""Up to `count` non-blocking pieces of `key` scattered around `centre`."""
	var out: Array[Dictionary] = []
	for i: int in count:
		var p: Vector2 = centre + Vector2(rng.randfn(0.0, TUFT_CLUSTER_SPREAD_M),
			rng.randfn(0.0, TUFT_CLUSTER_SPREAD_M))
		var yaw: float = rng.randf_range(-PI, PI)
		var size: float = rng.randf_range(0.7, 1.25)
		if _cover_site_ok(p, blockers, points):
			out.append({"id": &"", "key": key, "at": p, "yaw": yaw, "size": size, "block": false})
	return out


static func ground_cover(blockers: Array[Vector3], points: Array[Vector2]) -> Array[Dictionary]:
	"""Grass tussocks in clumps across the clearing and woods, and mushrooms in the shade."""
	var rng := _rng(COVER_SEED)
	var out: Array[Dictionary] = []
	for i: int in TUFT_CLUSTERS:
		var centre := Vector2(rng.randf_range(-COVER_HALF_EXTENT_M, COVER_HALF_EXTENT_M),
			rng.randf_range(-COVER_HALF_EXTENT_M, COVER_HALF_EXTENT_M))
		var count: int = rng.randi_range(2, TUFTS_PER_CLUSTER_MAX)
		out.append_array(_cluster(rng, &"grass_tuft", centre, count, blockers, points))
	for i: int in MUSHROOM_CLUSTERS:
		var angle: float = rng.randf_range(-PI, PI)
		var centre := Vector2(cos(angle), sin(angle)) * rng.randf_range(17.0, 34.0)
		out.append_array(_cluster(rng, &"mushroom_cluster", centre, rng.randi_range(1, 3),
			blockers, points))
	return out
