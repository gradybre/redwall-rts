extends RefCounted
## The demo village's hand-authored layout: what stands where, the worn paths, the spots
## residents walk to, and the circles they walk around. Decision 0196 (live demo).
##
## PRESENTATION ONLY. Coordinates are float metres in the XZ plane of a flat ground at y = 0,
## with the village square at the origin; nothing here is simulation state. The camera is
## expected south of the square (+Z) looking north, so the buildings with the most to show --
## the hall, the kitchen, the store -- stand north, east and west with their fronts turned to the
## square, and the low things (crops, workbench, the south road) sit between square and camera.
##
## Everything is derived from `world_sizes.gd`'s recorded bounds, never from staged files, so the
## obstacles and points of interest are identical with or without the real models.

const Sizes := preload("res://demo/world/world_sizes.gd")

const GROUND_Y: float = 0.0
const SQUARE: Vector2 = Vector2.ZERO
const SOUTH: Vector2 = Vector2(0.0, 40.0)

## Walkable area half-width and the height the bound reserves for the tallest resident (badger).
const PLAY_HALF_EXTENT_M: float = 20.0
const PLAY_HEADROOM_M: float = 4.0

## Obstacles are rings of circles over each footprint's rectangle; no cell edge exceeds this.
const MAX_CELL_M: float = 1.8
## Extra clearance added to every circle.
const OBSTACLE_MARGIN_M: float = 0.15
## Circles that do not reach the play area (grown by this much) are not reported.
const OBSTACLE_REPORT_MARGIN_M: float = 3.0

## Trees block only at the trunk: residents walk under canopies. Radius at size 1.0.
const TRUNK_RADIUS_M: Dictionary = {
	&"oak_mature": 1.1, &"beech_mature": 0.7, &"oak_sapling": 0.3,
}

const ACTIVITIES: Array[StringName] = [
	&"collect_object", &"stand_and_drink", &"wave_one_hand", &"idle",
]

const SIDE_NORMAL: Dictionary = {
	&"front": Vector2(0.0, 1.0), &"back": Vector2(0.0, -1.0),
	&"right": Vector2(1.0, 0.0), &"left": Vector2(-1.0, 0.0),
}

## Buildings, each turned to face a point (its front is the model's +Z).
const BUILDINGS: Array[Dictionary] = [
	{"id": &"hall", "key": &"hall", "at": Vector2(0.0, -13.0), "face": SQUARE},
	{"id": &"well", "key": &"well", "at": Vector2(0.0, 0.0), "face": SOUTH},
	{"id": &"residence_a", "key": &"residence", "at": Vector2(-13.5, -6.0), "face": SQUARE},
	{"id": &"residence_b", "key": &"residence", "at": Vector2(-14.0, 3.2), "face": SQUARE},
	{"id": &"residence_c", "key": &"residence", "at": Vector2(-11.8, -15.2), "face": SQUARE},
	{"id": &"kitchen", "key": &"kitchen", "at": Vector2(13.5, -6.0), "face": SQUARE},
	{"id": &"store", "key": &"covered_store", "at": Vector2(14.0, 6.2), "face": SQUARE},
	{"id": &"stockpile", "key": &"open_stockpile", "at": Vector2(12.6, -15.2), "face": SQUARE},
	{"id": &"workbench", "key": &"workbench", "at": Vector2(8.6, 12.6), "face": SQUARE},
]

## Props clustered where the work happens.
const PROPS: Array[Dictionary] = [
	{"id": &"cauldron", "key": &"cauldron_tripod", "at": Vector2(8.9, -3.9), "face": SQUARE},
	{"id": &"table_w", "key": &"table_stools", "at": Vector2(-5.0, -7.0), "yaw_deg": 4.0},
	{"id": &"table_e", "key": &"table_stools", "at": Vector2(5.0, -7.0), "yaw_deg": -6.0},
	{"id": &"log_stack", "key": &"log_stack", "at": Vector2(4.6, 14.3), "face": SQUARE},
	{"id": &"sacks_store", "key": &"sack_pile", "at": Vector2(10.2, 7.9), "yaw_deg": -70.0},
	{"id": &"sacks_yard", "key": &"sack_pile", "at": Vector2(7.6, -16.4), "yaw_deg": 35.0},
	{"id": &"crate_a", "key": &"crate", "at": Vector2(10.9, 2.3), "yaw_deg": 18.0},
	{"id": &"crate_b", "key": &"crate", "at": Vector2(9.9, 2.0), "yaw_deg": -9.0},
	{"id": &"barrel_kitchen", "key": &"barrel", "at": Vector2(10.3, -8.9), "yaw_deg": 40.0},
	{"id": &"barrel_store", "key": &"barrel", "at": Vector2(11.2, 1.2), "yaw_deg": 150.0},
	{"id": &"barrel_home", "key": &"barrel", "at": Vector2(-9.8, -2.2), "yaw_deg": 75.0},
	{"id": &"bucket", "key": &"water_bucket", "at": Vector2(2.35, 0.9), "yaw_deg": -30.0},
	{"id": &"wheelbarrow", "key": &"wheelbarrow", "at": Vector2(7.9, -11.3), "yaw_deg": 120.0},
	{"id": &"handcart", "key": &"handcart", "at": Vector2(17.6, -2.6), "yaw_deg": 94.0},
]

## Crop beds (three rows of two) and the fence that keeps the woods out of them.
const CROPS: Array[Dictionary] = [
	{"id": &"bed_cabbage_w", "key": &"crop_cabbage_ripe", "at": Vector2(-12.6, 9.2), "yaw_deg": 0.0},
	{"id": &"bed_cabbage_e", "key": &"crop_cabbage_ripe", "at": Vector2(-9.4, 9.2), "yaw_deg": 0.0},
	{"id": &"bed_roots_w", "key": &"crop_roots_ripe", "at": Vector2(-12.6, 12.8), "yaw_deg": 0.0},
	{"id": &"bed_roots_e", "key": &"crop_roots_ripe", "at": Vector2(-9.4, 12.8), "yaw_deg": 0.0},
	{"id": &"bed_grain_w", "key": &"crop_grain_ripe", "at": Vector2(-12.6, 16.4), "yaw_deg": 0.0},
	{"id": &"bed_grain_e", "key": &"crop_grain_ripe", "at": Vector2(-9.4, 16.4), "yaw_deg": 0.0},
]

## Fence runs as [from, to]; each is filled with whole segments. The west run stands 1.6 m clear of
## the beds and starts south of residence_b's corner, so a resident can walk round the north-west
## corner and down the beds' west side to the middle and bottom west beds, which the 3 m beds
## otherwise wall in on every other side (demo/farm/ works them from there).
const FENCE_RUNS: Array[Array] = [
	[Vector2(-17.0, 9.6), Vector2(-17.0, 18.6)],
	[Vector2(-17.0, 18.6), Vector2(-7.4, 18.6)],
]

## Hand-placed nature inside or at the edge of the play area.
const NATURE: Array[Dictionary] = [
	{"id": &"boulder_w", "key": &"mossy_boulder", "at": Vector2(-18.4, -1.6), "yaw_deg": 30.0},
	{"id": &"boulder_se", "key": &"mossy_boulder", "at": Vector2(17.6, 16.8), "yaw_deg": -50.0},
	{"id": &"stump_s", "key": &"stump_mossy", "at": Vector2(5.2, 17.6), "yaw_deg": 10.0},
	{"id": &"stump_w", "key": &"stump_mossy", "at": Vector2(-18.4, 13.6), "yaw_deg": 80.0},
	{"id": &"log_ne", "key": &"fallen_log", "at": Vector2(17.4, -19.2), "yaw_deg": 32.0},
	{"id": &"rocks_s", "key": &"rock_cluster", "at": Vector2(-4.2, 18.6), "yaw_deg": 0.0},
	{"id": &"rocks_e", "key": &"rock_cluster", "at": Vector2(18.6, -10.0), "yaw_deg": 60.0},
	{"id": &"sapling_n", "key": &"oak_sapling", "at": Vector2(5.8, -19.0), "yaw_deg": 20.0},
	{"id": &"sapling_s", "key": &"oak_sapling", "at": Vector2(-4.4, 14.8), "yaw_deg": -40.0},
	{"id": &"oak_nw", "key": &"oak_mature", "at": Vector2(-19.5, -19.0), "yaw_deg": 110.0, "size": 0.95},
	{"id": &"reeds_a", "key": &"reeds", "at": Vector2(-18.8, 8.6), "yaw_deg": 0.0, "block": false},
	{"id": &"reeds_b", "key": &"reeds", "at": Vector2(-17.6, 10.0), "yaw_deg": 70.0, "block": false},
	{"id": &"reeds_c", "key": &"reeds", "at": Vector2(-19.4, 10.6), "yaw_deg": 150.0, "block": false},
]

## Points of interest. `anchor` + `side` stands the resident `gap` metres clear of the anchor's
## obstacle envelope on that side, facing it (or, with `face_out`, facing away from it -- the hall
## steps look out over the square); `along` slides it sideways. Free spots use `at` + `face_to`.
const POINTS: Array[Dictionary] = [
	{"name": &"well_drink", "anchor": &"well", "side": &"front", "gap": 0.35, "along": 0.0,
		"activities": [&"stand_and_drink", &"idle"], "capacity": 1},
	{"name": &"workbench", "anchor": &"workbench", "side": &"front", "gap": 0.35, "along": 0.0,
		"activities": [&"collect_object", &"idle"], "capacity": 1},
	{"name": &"log_stack", "anchor": &"log_stack", "side": &"front", "gap": 0.35, "along": 0.0,
		"activities": [&"collect_object"], "capacity": 1},
	{"name": &"stockpile", "anchor": &"stockpile", "side": &"front", "gap": 0.35, "along": 0.0,
		"activities": [&"collect_object"], "capacity": 2},
	{"name": &"store_front", "anchor": &"store", "side": &"front", "gap": 0.35, "along": 0.0,
		"activities": [&"collect_object", &"idle"], "capacity": 1},
	{"name": &"cauldron", "anchor": &"cauldron", "side": &"front", "gap": 0.4, "along": 0.0,
		"activities": [&"collect_object", &"idle"], "capacity": 1},
	{"name": &"crops_cabbage", "anchor": &"bed_cabbage_e", "side": &"back", "gap": 0.35,
		"along": 0.0, "activities": [&"collect_object"], "capacity": 1},
	{"name": &"crops_grain", "anchor": &"bed_grain_e", "side": &"right", "gap": 0.35,
		"along": 0.0, "activities": [&"collect_object"], "capacity": 1},
	{"name": &"hall_steps", "anchor": &"hall", "side": &"front", "gap": 0.5, "along": 0.0,
		"face_out": true, "activities": [&"wave_one_hand", &"idle"], "capacity": 2},
	{"name": &"hall_table", "anchor": &"table_w", "side": &"front", "gap": 0.4, "along": 0.0,
		"activities": [&"idle", &"stand_and_drink"], "capacity": 1},
	{"name": &"square_west", "at": Vector2(-3.9, 1.6), "face_to": Vector2(0.0, 0.4),
		"activities": [&"idle", &"wave_one_hand"], "capacity": 2},
	{"name": &"square_east", "at": Vector2(3.7, -2.4), "face_to": Vector2(0.0, 0.0),
		"activities": [&"idle", &"wave_one_hand"], "capacity": 2},
]

## Worn paths as capsules: [ax, az, bx, bz] and a radius each. They branch like a real village's
## desire lines -- an oval square, the hall apron, one east road past kitchen and store, the south
## road with spurs to the workbench and the crops, and a west lane forking to two front doors.
const PATH_SEGMENTS: Array[Vector4] = [
	Vector4(-2.4, -1.4, 2.4, 0.9),     # the square
	Vector4(-6.6, -8.4, 6.6, -8.4),    # hall apron
	Vector4(0.0, -3.0, 0.0, -8.4),     # square to hall
	Vector4(-4.6, 0.2, -8.8, -0.4),    # west lane
	Vector4(-8.8, -0.4, -10.5, -4.2),  # to residence a
	Vector4(-8.8, -0.4, -10.7, 2.0),   # to residence b
	Vector4(-6.6, -8.4, -9.3, -12.2),  # to residence c
	Vector4(4.6, -0.2, 44.0, -1.4),    # east road
	Vector4(8.6, -0.6, 10.5, -4.0),    # to the kitchen door
	Vector4(8.8, -0.4, 10.7, 4.3),     # to the store
	Vector4(5.2, -8.4, 9.3, -11.2),    # to the stockpile
	Vector4(0.6, 4.4, 1.3, 21.0),      # south road
	Vector4(1.3, 21.0, -1.8, 50.0),    # south road, on into the woods
	Vector4(1.0, 9.4, 7.0, 10.3),      # to the workbench
	Vector4(1.1, 10.9, 4.1, 12.7),     # to the log stack
	Vector4(0.8, 7.2, -6.8, 7.2),      # to the crops
	Vector4(-6.8, 7.2, -6.6, 17.2),    # down the east side of the beds
	Vector4(-6.8, 7.2, -12.8, 6.8),    # along the front of the beds
	Vector4(-12.8, 6.8, -15.9, 7.3),   # round the beds' north-west corner
	Vector4(-15.9, 7.3, -15.9, 17.0),  # down the west side of the beds
	Vector4(4.6, -1.0, 7.5, -3.2),     # to the cauldron
]
const PATH_RADII: Array[float] = [
	4.6, 1.5, 2.0, 1.25, 0.85, 0.85, 0.8, 1.3, 0.85, 0.85, 0.95, 1.25, 1.25, 0.9, 0.7, 0.9, 0.7,
	0.7, 0.6, 0.55, 0.8,
]


static func bounds() -> AABB:
	"""The walkable area: the square play field, from the ground up to badger head height."""
	var corner := Vector3(-PLAY_HALF_EXTENT_M, GROUND_Y, -PLAY_HALF_EXTENT_M)
	var size := Vector3(2.0 * PLAY_HALF_EXTENT_M, PLAY_HEADROOM_M, 2.0 * PLAY_HALF_EXTENT_M)
	return AABB(corner, size)


static func rotate_xz(v: Vector2, yaw: float) -> Vector2:
	"""Rotate a model-local XZ vector by `yaw` about +Y (Godot's Basis(UP, yaw) convention)."""
	var c: float = cos(yaw)
	var s: float = sin(yaw)
	return Vector2(v.x * c + v.y * s, -v.x * s + v.y * c)


static func yaw_facing(from: Vector2, to: Vector2) -> float:
	"""The yaw that turns a model's +Z front from `from` toward `to`."""
	var d: Vector2 = to - from
	return atan2(d.x, d.y)


static func normalised(entry: Dictionary) -> Dictionary:
	"""An authored placement as {id, key, at, yaw (rad), size, block}."""
	var at: Vector2 = entry["at"]
	var yaw: float = deg_to_rad(float(entry.get("yaw_deg", 0.0)))
	if entry.has("face"):
		yaw = yaw_facing(at, entry["face"])
	return {
		"id": entry.get("id", &""), "key": entry["key"], "at": at, "yaw": yaw,
		"size": float(entry.get("size", 1.0)), "block": bool(entry.get("block", true)),
	}


static func fence_placements() -> Array[Dictionary]:
	"""Whole fence segments along every run; each segment's length axis (+X) follows the run."""
	var out: Array[Dictionary] = []
	var length: float = Sizes.scaled_rect(&"fence", 1.0).size.x
	for run: Array in FENCE_RUNS:
		var a: Vector2 = run[0]
		var b: Vector2 = run[1]
		var count: int = maxi(1, ceili(a.distance_to(b) / length))
		var yaw: float = atan2(-(b.y - a.y), b.x - a.x)
		for i: int in count:
			var at: Vector2 = a.lerp(b, (float(i) + 0.5) / float(count))
			out.append({"id": &"", "key": &"fence", "at": at, "yaw": yaw, "size": 1.0, "block": true})
	return out


static func placements() -> Array[Dictionary]:
	"""Every hand-authored placement, normalised. Deterministic and independent of staging."""
	var out: Array[Dictionary] = []
	for table: Array[Dictionary] in [BUILDINGS, PROPS, CROPS, NATURE]:
		for entry: Dictionary in table:
			out.append(normalised(entry))
	out.append_array(fence_placements())
	return out


static func find_placement(all: Array[Dictionary], id: StringName) -> Dictionary:
	"""The placement with this id, or an empty dictionary."""
	for p: Dictionary in all:
		if p["id"] == id:
			return p
	return {}


static func cell_grid(rect: Rect2) -> Vector2i:
	"""How many circle cells cover `rect` along X and Z, none longer than MAX_CELL_M."""
	return Vector2i(maxi(1, ceili(rect.size.x / MAX_CELL_M)), maxi(1, ceili(rect.size.y / MAX_CELL_M)))


static func cell_radius(rect: Rect2) -> float:
	"""The radius of one cell's circle: half its diagonal plus the margin."""
	var grid: Vector2i = cell_grid(rect)
	return Vector2(rect.size.x / grid.x, rect.size.y / grid.y).length() * 0.5 + OBSTACLE_MARGIN_M


static func placement_circles(p: Dictionary) -> Array[Vector3]:
	"""Obstacle circles (x, z, radius) for one placement: a trunk, or a ring over its footprint."""
	var out: Array[Vector3] = []
	if not p["block"]:
		return out
	var at: Vector2 = p["at"]
	if TRUNK_RADIUS_M.has(p["key"]):
		out.append(Vector3(at.x, at.y, float(TRUNK_RADIUS_M[p["key"]]) * float(p["size"])))
		return out
	var rect: Rect2 = Sizes.scaled_rect(p["key"], p["size"])
	var grid: Vector2i = cell_grid(rect)
	var cell := Vector2(rect.size.x / grid.x, rect.size.y / grid.y)
	var radius: float = cell_radius(rect)
	for ix: int in grid.x:
		for iz: int in grid.y:
			if ix > 0 and iz > 0 and ix < grid.x - 1 and iz < grid.y - 1:
				continue
			var local: Vector2 = rect.position + cell * (Vector2(ix, iz) + Vector2(0.5, 0.5))
			var world: Vector2 = at + rotate_xz(local, p["yaw"])
			out.append(Vector3(world.x, world.y, radius))
	return out


static func circle_reaches_play(circle: Vector3) -> bool:
	"""Whether a circle comes within OBSTACLE_REPORT_MARGIN_M of the play area."""
	var reach: float = PLAY_HALF_EXTENT_M + OBSTACLE_REPORT_MARGIN_M + circle.z
	return absf(circle.x) <= reach and absf(circle.y) <= reach


static func obstacles_for(all: Array[Dictionary]) -> Array[Vector3]:
	"""Every blocking circle of these placements that reaches the play area."""
	var out: Array[Vector3] = []
	for p: Dictionary in all:
		for circle: Vector3 in placement_circles(p):
			if circle_reaches_play(circle):
				out.append(circle)
	return out


static func side_envelope(p: Dictionary, side: StringName) -> float:
	"""How far the anchor's obstacle ring reaches from its origin along `side`'s normal."""
	var rect: Rect2 = Sizes.scaled_rect(p["key"], p["size"])
	var grid: Vector2i = cell_grid(rect)
	var radius: float = cell_radius(rect)
	match side:
		&"front":
			return rect.end.y - rect.size.y / grid.y * 0.5 + radius
		&"back":
			return -rect.position.y - rect.size.y / grid.y * 0.5 + radius
		&"right":
			return rect.end.x - rect.size.x / grid.x * 0.5 + radius
	return -rect.position.x - rect.size.x / grid.x * 0.5 + radius


static func anchored_spot(p: Dictionary, point: Dictionary) -> Array[Vector2]:
	"""[position, facing] for a point standing `gap` clear of an anchor's side, facing it."""
	var side: StringName = point["side"]
	var normal: Vector2 = SIDE_NORMAL[side]
	var tangent := Vector2(normal.y, -normal.x)
	var rect: Rect2 = Sizes.scaled_rect(p["key"], p["size"])
	var centre_along: float = rect.get_center().dot(tangent)
	var reach: float = side_envelope(p, side) + float(point["gap"])
	var local: Vector2 = normal * reach + tangent * (centre_along + float(point["along"]))
	var at: Vector2 = p["at"]
	var facing: Vector2 = normal if bool(point.get("face_out", false)) else -normal
	return [at + rotate_xz(local, p["yaw"]), rotate_xz(facing, p["yaw"])]


static func resolve_point(all: Array[Dictionary], point: Dictionary) -> Dictionary:
	"""One authored point of interest in the published shape."""
	var spot: Array[Vector2] = []
	if point.has("anchor"):
		spot = anchored_spot(find_placement(all, point["anchor"]), point)
	else:
		var at: Vector2 = point["at"]
		var to: Vector2 = point["face_to"]
		spot = [at, (to - at).normalized()]
	var activities: Array[StringName] = []
	for activity: StringName in point["activities"]:
		activities.append(activity)
	return {
		"name": point["name"], "position": Vector3(spot[0].x, GROUND_Y, spot[0].y),
		"face": Vector3(spot[1].x, 0.0, spot[1].y).normalized(),
		"activities": activities, "capacity": int(point["capacity"]),
	}


static func points_of_interest_for(all: Array[Dictionary]) -> Array[Dictionary]:
	"""Every authored point of interest, resolved against these placements."""
	var out: Array[Dictionary] = []
	for point: Dictionary in POINTS:
		out.append(resolve_point(all, point))
	return out


static func segment_distance(p: Vector2, seg: Vector4) -> float:
	"""Distance from `p` to the segment (seg.x, seg.y) -> (seg.z, seg.w)."""
	var a := Vector2(seg.x, seg.y)
	var ab := Vector2(seg.z, seg.w) - a
	var denom: float = maxf(ab.length_squared(), 0.0001)
	var h: float = clampf((p - a).dot(ab) / denom, 0.0, 1.0)
	return p.distance_to(a + ab * h)


static func path_distance(p: Vector2) -> float:
	"""Signed distance from `p` to the nearest worn path edge (negative on a path)."""
	var best: float = INF
	for i: int in PATH_SEGMENTS.size():
		best = minf(best, segment_distance(p, PATH_SEGMENTS[i]) - PATH_RADII[i])
	return best


static func clearance(p: Vector2, circles: Array[Vector3]) -> float:
	"""Distance from `p` to the nearest circle edge (negative inside one)."""
	var best: float = INF
	for c: Vector3 in circles:
		best = minf(best, p.distance_to(Vector2(c.x, c.y)) - c.z)
	return best
