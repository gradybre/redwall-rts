extends Node3D
## THE EVERGREENS (art pass 2's Scots pine and yew, decision 0951; wired by the batch 8 integration, decision 0903). The
## woods had none: the world's ring is oak, beech and oak saplings (world_scatter.gd). This stands a few pines and yews
## among them, at Brendan's sizes (DEC-047: pine 16 m, yew 10 m; world_sizes.gd), so the winter woods keep some green.
## Presentation only:
##   * deterministic: its own fixed seed and attempt count, as world_scatter.gd's generators;
##   * in the woods (WOODS_IN_M past the clearing's edge) out to OUTER_TO_M, where the camera still sees them, mostly
##     north of the village (the camera looks north over the square); clear of the woods' trees (their spacing), the
##     paths, the water, the buildings and the foraging spots and the grove;
##   * NOT the forestry's: they are not bound to the stand (never felled, no wood); their trunks are the cast's
##     obstacles (`land_obstacles`, as the orchard's: the same with or without the models, so every run plans alike);
##   * drawn only where their models are staged: without them (CI) nothing is drawn;
##   * season trees (season_view.gd OTHER OWNERS' TREES, kind season_look.gd KIND_EVERGREEN): they keep their needles,
##     and the weather's snow lies on them.

const Scatter := preload("res://demo/world/world_scatter.gd")
const Layout := preload("res://demo/world/world_layout.gd")
const WaterDressing := preload("res://demo/water/water_dressing.gd")
const LookScript := preload("res://demo/seasons/season_look.gd")

const SEED: int = 1990
const ATTEMPTS: int = 1600
## How many: pines and yews (a sensible scatter for the outer woods, decision 0903).
const PINES: int = 10
const YEWS: int = 6
const PINE_KEY: StringName = &"pine_scots"
const YEW_KEY: StringName = &"yew_ancient"
## Where: this far past the clearing's edge, out to OUTER_TO_M (from the square's middle).
const WOODS_IN_M: float = 5.0
const OUTER_TO_M: float = 50.0
## Kept this far from the foraging spots and the orchard's grove (their own trees and bushes stand there).
const SPOT_CLEARANCE_M: float = 7.0
const KEEP_CLEAR: Array[Vector2] = [Vector2(-7.5, -29.4), Vector2(10.4, -30.4), Vector2(-12.0, 23.6), Vector2(-25.0, 27.0),
	Vector2(-10.0, -25.5)]
## Each trunk's radius at size 1.0 (art pass 2's proposal, decision 0951: pine 0.45 m, yew 0.9 m; the cast walks round).
const TRUNK_RADIUS_M: Dictionary = {PINE_KEY: 0.45, YEW_KEY: 0.9}
## Trunk-to-trunk spacing at size 1.0 (a crown's spread: pine about 9 m across, yew 11); from another tree, the mean of
## the two trees' spacings.
const SPACING_M: Dictionary = {PINE_KEY: 7.0, YEW_KEY: 8.0}
const PATH_CLEARANCE_M: float = 4.0
const BLOCKER_CLEARANCE_M: float = 3.0
## The share of picks south of the square (the camera's side): few, so they never stand between the view and the village.
const SOUTH_SHARE: float = 0.15

var _nodes: Array[Node3D] = []
var _at: PackedVector2Array = PackedVector2Array()
var _revision: int = 0


static func placements(woods: Array[Dictionary]) -> Array[Dictionary]:
	"""Where the evergreens stand ({key, at, yaw, size}), clear of `woods` (the world's tree placements); the same on
	every run."""
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var taken: Array[Vector3] = []
	for p: Dictionary in woods:
		taken.append(Vector3((p["at"] as Vector2).x, (p["at"] as Vector2).y, float(Scatter.TREE_SPACING_M.get(p["key"],
			4.0)) * float(p["size"])))
	var blockers: Array[Vector3] = WaterDressing.woods_blockers()
	blockers.append_array(Layout.obstacles_for(Layout.placements()))
	var out: Array[Dictionary] = []
	for attempt: int in ATTEMPTS:
		var key: StringName = _key_for(attempt, out)
		var p := _pick(rng)
		var size: float = rng.randf_range(0.85, 1.1)
		if out.size() >= PINES + YEWS or not _site_ok(p, blockers, taken, float(SPACING_M[key]) * size):
			continue
		taken.append(Vector3(p.x, p.y, float(SPACING_M[key]) * size))
		out.append({"key": key, "at": p, "yaw": rng.randf_range(-PI, PI), "size": size})
	return out


static func _pick(rng: RandomNumberGenerator) -> Vector2:
	"""A point in the outer woods, north of the square but for SOUTH_SHARE of picks."""
	var angle: float = rng.randf_range(PI, TAU) if rng.randf() > SOUTH_SHARE else rng.randf_range(0.0, PI)
	var from: float = Scatter.clearing_edge(Vector2.from_angle(angle)) + WOODS_IN_M
	return Vector2.from_angle(angle) * rng.randf_range(from, maxf(from, OUTER_TO_M))


static func _site_ok(p: Vector2, blockers: Array[Vector3], taken: Array[Vector3], spacing: float) -> bool:
	"""Off the paths, clear of the water and the buildings, and keeping every tree's spacing (and its own)."""
	if Layout.path_distance(p) < PATH_CLEARANCE_M or Layout.clearance(p, blockers) < BLOCKER_CLEARANCE_M:
		return false
	for spot: Vector2 in KEEP_CLEAR:
		if p.distance_to(spot) < SPOT_CLEARANCE_M:
			return false
	for t: Vector3 in taken:
		if p.distance_to(Vector2(t.x, t.y)) < (t.z + spacing) * 0.5:
			return false
	return true


static func land_obstacles(woods: Array[Dictionary]) -> Array[Vector3]:
	"""What the cast walks round (x, radius, z): each evergreen's trunk, drawn or not (see the header)."""
	var out: Array[Vector3] = []
	for p: Dictionary in placements(woods):
		var at: Vector2 = p["at"]
		out.append(Vector3(at.x, float(TRUNK_RADIUS_M[p["key"]]) * float(p["size"]), at.y))
	return out


static func _key_for(attempt: int, out: Array[Dictionary]) -> StringName:
	"""Every third attempt a yew while yews are wanted, else a pine while pines are (then whichever is still wanted)."""
	var yews_wanted: bool = _count(out, YEW_KEY) < YEWS
	if yews_wanted and (attempt % 3 == 0 or _count(out, PINE_KEY) >= PINES):
		return YEW_KEY
	return PINE_KEY


static func _count(list: Array[Dictionary], key: StringName) -> int:
	"""How many of `list` are `key`."""
	var n: int = 0
	for p: Dictionary in list:
		n += 1 if p["key"] == key else 0
	return n


func build(make: Callable, staged: Callable, woods: Array[Dictionary]) -> int:
	"""Draw the evergreens with the world's `make(key, at, yaw, size) -> Node3D`, those `staged(key)` says it has.
	Returns how many were drawn (none without their models)."""
	name = "Evergreens"
	for p: Dictionary in placements(woods):
		if not staged.is_valid() or not bool(staged.call(p["key"])):
			continue
		var node: Node3D = make.call(p["key"], p["at"], p["yaw"], p["size"])
		add_child(node)
		_nodes.append(node)
		_at.append(p["at"])
	_revision += 1
	return _nodes.size()


# --- the season's trees (season_view.gd OTHER OWNERS' TREES) -----------------------------------------------------------

func season_tree_count() -> int:
	"""Every evergreen drawn."""
	return _nodes.size()


func season_tree_node(i: int) -> Node3D:
	"""Evergreen `i`'s node."""
	return _nodes[i]


func season_tree_kind(_i: int) -> int:
	"""They keep their needles (season_look.gd KIND_EVERGREEN)."""
	return LookScript.KIND_EVERGREEN


func season_tree_at(i: int) -> Vector2:
	"""Where evergreen `i` stands."""
	return _at[i]


func season_trees_revision() -> int:
	"""Bumped when they are drawn."""
	return _revision
