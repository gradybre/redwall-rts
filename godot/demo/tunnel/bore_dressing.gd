extends Node3D
## What a bore's walls hold: stones bedded in them, and roots poking through them near trees. Decision
## 0207 (the underground revamp's P1; design docs/design/underground_revamp.md §6 "Materials": embedded
## stones, roots under trees). Presentation only.
##
## Per segment of the network (decision 0208), two MultiMeshes on the UNDERGROUND layer: STONES (a lumpy stone, MAX_STONES of them) and
## ROOTS (a tapering root with a rootlet, MAX_ROOTS), placed on the bore's own drawn centreline
## (bore_curve.gd `of`). Each dug step (bore_view.gd's ring lattice) deep enough that its highest root
## stays under the section plane (`dressed_at`) rolls its own dice -- a hash of the segment's generation and
## the step, so a step always gets the same stones -- for a stone bedded into a wall (STONE_CHANCE a side), and,
## within a mature tree's root reach (forest_roots.gd, the reach the cap's root tangles are drawn to),
## up to ROOTS_PER_STEP roots out of the upper walls, likelier the nearer the trunk. Only new steps are
## dressed as the face moves; a rebuild of the whole bore re-rolls the same dice.
##
## The earth shader's bedded stones and root streaks (bore_earth.gdshader) are the fine grain; these are
## the pieces that stand proud of the wall.
##
## ROCK FACES (art pass 3's `rock_face`, decision 0971; wired by the batch 8 integration, decision 0903): where the
## ground under a step is ROCK (tunnel_ground.gd, the badger's hard ground) and the rock face is staged (`set_rock`),
## a slab of bedded rock stands against each wall, a metre a piece (every ROCK_EVERY rings), its back to the wall, its
## face (+Z) to the bore's centre line, its base on the floor, turned to the wall's tangent; each rolls its own dice
## (ROCK_CHANCE a wall, a little yaw and size), so a rock stretch is not a tiled wall. At 0.765 m it covers the wall
## past the springline and stays under the section plane (`dressed_at`). Without the model nothing is added: rock
## shows as the ground map and the dig readout say, as before.

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const Layers := preload("res://demo/demo_layers.gd")
const PrewarmScript := preload("res://demo/tunnel/underground_prewarm.gd")
const BoreMeshScript := preload("res://demo/tunnel/bore_mesh.gd")
const BoreCurveScript := preload("res://demo/tunnel/bore_curve.gd")
const RootsScript := preload("res://demo/forestry/forest_roots.gd")
const StandScript := preload("res://demo/forestry/forest_stand.gd")
const GroundScript := preload("res://demo/tunnel/tunnel_ground.gd")

const MAX_STONES: int = 192
const MAX_ROOTS: int = 96
const STEP_M: float = BoreMeshScript.RING_STEP_M
## A step's chance of a stone on each wall, and a stone's drawn radius range (m).
const STONE_CHANCE: float = 0.22
const STONE_MIN_M: float = 0.035
const STONE_MAX_M: float = 0.09
const STONE_COLOUR: Color = Color(0.36, 0.33, 0.29)
## A stone's middle lies this share of its size into the wall: bedded, not stuck on.
const STONE_BEDDED: float = 0.4
## Roots: at most this many a step, near a trunk; drawn this long (m); how high up the wall they come out
## (shares of the crown).
const ROOTS_PER_STEP: int = 2
const ROOT_CHANCE: float = 0.75
const ROOT_MIN_M: float = 0.22
const ROOT_MAX_M: float = 0.55
const ROOT_FROM_T: float = 0.55
const ROOT_TO_T: float = 0.95
## A root's base keeps this far under the section plane.
const ROOT_CAP_CLEAR_M: float = 0.05
const ROOT_COLOUR: Color = Color(0.24, 0.16, 0.1)
const ROOT_SIDES: int = 5
const ROOT_BENDS: int = 6

## ROCK FACES: a wall piece every this many rings (a metre), a wall's chance of one, its drawn size spread and yaw.
const MAX_ROCKS: int = 64
const ROCK_EVERY: int = 4
const ROCK_CHANCE: float = 0.85
const ROCK_SIZE_MIN: float = 0.9
const ROCK_SIZE_MAX: float = 1.08
const ROCK_YAW_MAX: float = 0.18
## The rock face's half depth (m, its staged bound): its back stands this far behind its origin.
const ROCK_HALF_DEPTH_M: float = 0.118

static var _stone: ArrayMesh = null
static var _root: ArrayMesh = null

var _stones: Array[MultiMeshInstance3D] = []
var _roots: Array[MultiMeshInstance3D] = []
var _rocks: Array[MultiMeshInstance3D] = []
## ROCK FACES: the staged model and its fit (null: none), the ground's type query `(x_u, z_u, level) -> int`, and the
## level the segment being dressed lies on.
var _rock_mesh: Mesh = null
var _rock_fit: Transform3D = Transform3D.IDENTITY
var _rock_ground: Callable = Callable()
var _rock_level: int = 0
## Mature trees as (x, root reach, z) metres.
var _trees: PackedVector3Array = PackedVector3Array()
var _sample: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])


func configure() -> void:
	"""Room for every segment's two MultiMeshes, built the first time the segment is dressed."""
	name = "Dressing"
	_stones.resize(Rules.MAX_SEGMENTS)
	_roots.resize(Rules.MAX_SEGMENTS)
	_rocks.resize(Rules.MAX_SEGMENTS)


func _ensure(slot: int) -> void:
	"""Segment `slot`'s two MultiMeshes, empty and hidden, built once."""
	if _stones[slot] != null:
		return
	_stones[slot] = _multi(stone_mesh(), MAX_STONES)
	_roots[slot] = _multi(root_mesh(), MAX_ROOTS)
	if _rock_mesh != null:
		_rocks[slot] = _multi(_rock_mesh, MAX_ROCKS, false)


func _multi(mesh: Mesh, count: int, colours: bool = true) -> MultiMeshInstance3D:
	"""A MultiMesh node for up to `count` of `mesh` (instance colours on, unless `colours` is false: a staged model's
	own material), none shown, on the UNDERGROUND layer."""
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = colours
	multimesh.mesh = mesh
	multimesh.instance_count = count
	multimesh.visible_instance_count = 0
	var node := MultiMeshInstance3D.new()
	node.multimesh = multimesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.layers = Layers.UNDERGROUND
	node.visible = false
	add_child(node)
	return node


func register(prewarm: PrewarmScript) -> void:
	"""The stone and the root, drawn instanced, for the U view's prewarm."""
	prewarm.add_multimesh(stone_mesh())
	prewarm.add_multimesh(root_mesh())


func set_rock(mesh: Mesh, fit: Transform3D, ground_type: Callable) -> void:
	"""The staged rock face (`mesh` drawn by `fit`) for the walls where `ground_type(x_u, z_u, level)` is rock (ROCK
	FACES); before any segment is dressed. A null mesh: none."""
	_rock_mesh = mesh
	_rock_fit = fit
	_rock_ground = ground_type


func rocks(slot: int) -> MultiMeshInstance3D:
	"""Segment `slot`'s rock faces (checks; null before it is dressed or with no rock face)."""
	return _rocks[slot]


func set_trees(trees: Array[Dictionary]) -> int:
	"""The mature trees ({key, at, size}; saplings have no roots here) whose roots reach the bores.
	Returns how many."""
	_trees.resize(0)
	for tree: Dictionary in trees:
		var look: int = StandScript.LOOK_KEYS.find(tree["key"])
		if look >= 0:
			var at: Vector2 = tree["at"]
			_trees.append(Vector3(at.x, RootsScript.reach_m(look, float(tree.get("size", 1.0))), at.y))
	return _trees.size()


func stones(slot: int) -> MultiMeshInstance3D:
	"""Segment `slot`'s stones (checks; null before it is first dressed)."""
	return _stones[slot]


func roots(slot: int) -> MultiMeshInstance3D:
	"""Segment `slot`'s roots (checks; null before it is first dressed)."""
	return _roots[slot]


func clear(slot: int) -> void:
	"""No stones or roots in segment `slot`."""
	if _stones[slot] == null:
		return
	for node: MultiMeshInstance3D in [_stones[slot], _roots[slot], _rocks[slot]]:
		if node != null:
			node.multimesh.visible_instance_count = 0
			node.visible = false


# --- placing ----------------------------------------------------------------------------------

func place(slot: int, network: GraphScript, from_m: float, to_m: float, widen_m: float, clear_a_m: float = 0.0,
		clear_b_m: float = 0.0) -> void:
	"""Dress segment `slot`'s steps dug between `from_m` and `to_m` (from 0: all of them again), none within
	`clear_a_m` of its node A or `clear_b_m` of its node B (a junction's hub is there: bore_view.gd HUBS)."""
	_ensure(slot)
	if from_m <= 0.0:
		clear(slot)
	_put_on_level(slot, network)
	var curve: BoreCurveScript = BoreCurveScript.of(network, slot)
	var length := network.length_m(slot)
	var step := 0 if from_m <= 0.0 else floori(from_m / STEP_M) + 1
	var cut_level := dress_level(network, slot)
	var rooted := cut_level == Rules.TOP_LEVEL
	_rock_level = network.seg_level[slot]
	while float(step) * STEP_M <= to_m:
		var along := float(step) * STEP_M
		var bore := Rules.BORE_WIDE if network.bore[slot] == Rules.BORE_WIDE or along < widen_m else Rules.BORE_STANDARD
		var floor_y := network.floor_y_at(slot, along)
		if dressed_at(floor_y, bore, cut_level) and along >= clear_a_m and along <= length - clear_b_m:
			curve.sample(along, _sample)
			_dress_step(slot, network.generation[slot] * 7919 + step, Vector3(_sample[0].x, floor_y, _sample[0].y), _sample[1], bore,
				rooted)
			if step % ROCK_EVERY == 0:
				_dress_rock(slot, network.generation[slot] * 7919 + step, Vector3(_sample[0].x, floor_y, _sample[0].y),
					_sample[1], bore)
		step += 1
	for node: MultiMeshInstance3D in [_stones[slot], _roots[slot], _rocks[slot]]:
		if node != null:
			node.visible = node.multimesh.visible_instance_count > 0


static func dressed_at(floor_y: float, bore: int, level: int = Rules.TOP_LEVEL) -> bool:
	"""Whether a step whose floor lies at `floor_y` is dressed: its highest root stays under `level`'s section
	plane (demo_layers.gd `cap_y`), so nothing stands through the cut."""
	return floor_y + Rules.crown_m(bore) * ROOT_TO_T + ROOT_CAP_CLEAR_M <= Layers.cap_y(level)


static func dress_level(network: GraphScript, slot: int) -> int:
	"""The level whose section a segment's dressing must stay under (decision 0212): its own -- or a link's foot's,
	so a link is dressed only where it is seen from the level below (it stands on both levels' layers)."""
	var level: int = network.seg_level[slot]
	return level + 1 if network.seg_kind[slot] == GraphScript.SEG_LINK else level


func _put_on_level(slot: int, network: GraphScript) -> void:
	"""Segment `slot`'s stones and roots on its level's layer (a link's on both levels'; decision 0212)."""
	var level: int = network.seg_level[slot]
	var mask := Layers.below(level)
	if network.seg_kind[slot] == GraphScript.SEG_LINK:
		mask |= Layers.below(level + 1)
	for node: MultiMeshInstance3D in [_stones[slot], _roots[slot], _rocks[slot]]:
		if node != null:
			node.layers = mask


func _dress_step(slot: int, seed_value: int, centre: Vector3, heading: Vector2, bore: int, rooted: bool = true) -> void:
	"""One step's stones and -- `rooted`: near the surface, on level 1 -- roots (see the header)."""
	var side := Vector3(-heading.y, 0.0, heading.x)
	for wall: float in [-1.0, 1.0]:
		if unit(seed_value, 1 + int(wall)) < STONE_CHANCE:
			_add_stone(slot, seed_value + int(wall) * 31, centre, side * wall, bore)
	if not rooted:
		return
	var near := root_chance(Vector2(centre.x, centre.z))
	for k in ROOTS_PER_STEP:
		if unit(seed_value, 10 + k) < near * ROOT_CHANCE:
			_add_root(slot, seed_value + k * 57, centre, side * (1.0 if unit(seed_value, 20 + k) < 0.5 else -1.0), bore)


func _dress_rock(slot: int, seed_value: int, centre: Vector3, heading: Vector2, bore: int) -> void:
	"""A metre's rock faces, where the ground under it is rock and the face is staged (ROCK FACES)."""
	if _rocks[slot] == null or not _rock_ground.is_valid():
		return
	if int(_rock_ground.call(Rules.to_u(centre.x), Rules.to_u(centre.z), _rock_level)) != GroundScript.ROCK:
		return
	var side := Vector3(-heading.y, 0.0, heading.x)
	for wall: float in [-1.0, 1.0]:
		if unit(seed_value, 40 + int(wall)) < ROCK_CHANCE:
			_add_rock(slot, seed_value + int(wall) * 43, centre, side * wall, bore)


func _add_rock(slot: int, seed_value: int, centre: Vector3, out: Vector3, bore: int) -> void:
	"""One rock face against the wall on the `out` side: back to the wall, face to the centre line, base on the floor."""
	var node := _rocks[slot]
	var count := node.multimesh.visible_instance_count
	if count >= MAX_ROCKS:
		return
	node.multimesh.set_instance_transform(count, rock_transform(seed_value, centre, out, bore) * _rock_fit)
	node.multimesh.visible_instance_count = count + 1


static func rock_transform(seed_value: int, centre: Vector3, out: Vector3, bore: int) -> Transform3D:
	"""Where one rock face stands (before its model's fit): its back to the wall on the `out` side, its face (+Z) to the
	centre line, its base on the floor at `centre`, a little yawed and sized by its dice."""
	var size := lerpf(ROCK_SIZE_MIN, ROCK_SIZE_MAX, unit(seed_value, 44))
	var inward := -out
	var facing := Basis(Vector3.UP.cross(inward), Vector3.UP, inward).rotated(Vector3.UP,
		(unit(seed_value, 45) - 0.5) * 2.0 * ROCK_YAW_MAX).scaled(Vector3.ONE * size)
	return Transform3D(facing, centre + out * (BoreMeshScript.FLOOR_HALF_M[bore] - ROCK_HALF_DEPTH_M * size))


func root_chance(at: Vector2) -> float:
	"""How likely roots are at `at`: 1 at a trunk, falling to 0 at its root reach (the nearest tree's)."""
	var best := 0.0
	for tree: Vector3 in _trees:
		var reach := maxf(tree.y, 0.01)
		best = maxf(best, 1.0 - Vector2(tree.x, tree.z).distance_to(at) / reach)
	return clampf(best, 0.0, 1.0)


static func unit(seed_value: int, salt: int) -> float:
	"""A repeatable number in [0, 1) from a seed and a salt (an integer hash)."""
	var h := (seed_value * 73856093) ^ (salt * 19349663) ^ 0x5bd1e995
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xFFFFFF) / float(0x1000000)


func _add_stone(slot: int, seed_value: int, centre: Vector3, out: Vector3, bore: int) -> void:
	"""A stone bedded half into the wall on the `out` side, part way up it."""
	var node := _stones[slot]
	var count := node.multimesh.visible_instance_count
	if count >= MAX_STONES:
		return
	var t := lerpf(0.08, 0.7, unit(seed_value, 3))
	var reach := BoreMeshScript.FLOOR_HALF_M[bore] * BoreMeshScript.width_share(t)
	var size := lerpf(STONE_MIN_M, STONE_MAX_M, unit(seed_value, 4))
	var facing := Basis(Vector3(unit(seed_value, 5), unit(seed_value, 6), unit(seed_value, 7)).normalized(), unit(seed_value, 8) * TAU).scaled(Vector3(size, size * 0.8, size))
	node.multimesh.set_instance_transform(count, Transform3D(facing, centre + out * (reach + size * STONE_BEDDED) + Vector3.UP * (t * Rules.crown_m(bore))))
	node.multimesh.set_instance_color(count, STONE_COLOUR * lerpf(0.8, 1.15, unit(seed_value, 9)))
	node.multimesh.visible_instance_count = count + 1


func _add_root(slot: int, seed_value: int, centre: Vector3, out: Vector3, bore: int) -> void:
	"""A root out of the upper wall on the `out` side, reaching into the bore and hanging down."""
	var node := _roots[slot]
	var count := node.multimesh.visible_instance_count
	if count >= MAX_ROOTS:
		return
	var t := lerpf(ROOT_FROM_T, ROOT_TO_T, unit(seed_value, 11))
	var reach := BoreMeshScript.FLOOR_HALF_M[bore] * BoreMeshScript.width_share(t)
	var length := lerpf(ROOT_MIN_M, ROOT_MAX_M, unit(seed_value, 12))
	var inward := -out
	var along := Vector3(-out.z, 0.0, out.x) * (unit(seed_value, 13) - 0.5)
	var facing := Basis(inward, Vector3.UP, inward.cross(Vector3.UP)).rotated(Vector3.UP, (unit(seed_value, 14) - 0.5) * 0.8)
	var at := centre + out * (reach + 0.02) + Vector3.UP * (t * Rules.crown_m(bore)) + along * 0.2
	node.multimesh.set_instance_transform(count, Transform3D(facing.scaled(Vector3.ONE * length), at))
	node.multimesh.set_instance_color(count, ROOT_COLOUR * lerpf(0.85, 1.2, unit(seed_value, 15)))
	node.multimesh.visible_instance_count = count + 1


# --- the pieces -------------------------------------------------------------------------------

static func stone_mesh() -> ArrayMesh:
	"""A unit lumpy stone (radius about 1), shared: a low sphere with every point pushed in or out."""
	if _stone != null:
		return _stone
	var sphere := SphereMesh.new()
	sphere.radial_segments = 9
	sphere.rings = 5
	var arrays := sphere.get_mesh_arrays()
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for k in points.size():
		var p := points[k] * 2.0
		points[k] = p * (1.0 + 0.22 * sin(p.x * 5.1 + p.y * 3.3) * cos(p.z * 4.7 - p.y * 1.9))
	arrays[Mesh.ARRAY_VERTEX] = points
	var tool := SurfaceTool.new()
	tool.create_from_arrays(arrays)
	tool.generate_normals()
	_stone = tool.commit()
	_stone.surface_set_material(0, _material(0.9, BaseMaterial3D.CULL_BACK))
	return _stone


static func root_mesh() -> ArrayMesh:
	"""A unit root (about 1 long), shared: a tapering tube out along +X that curls down, and a rootlet."""
	if _root != null:
		return _root
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_tube(tool, 0, func(u: float) -> Vector3: return Vector3(u * 0.75, -0.55 * u * u, 0.08 * sin(u * 4.0)), 0.05, 0.008)
	_tube(tool, (ROOT_BENDS + 1) * ROOT_SIDES, func(u: float) -> Vector3: return Vector3(0.3 + u * 0.25, -0.05 - 0.35 * u, 0.12 * u), 0.022, 0.004)
	tool.generate_normals()
	_root = tool.commit()
	_root.surface_set_material(0, _material(0.95, BaseMaterial3D.CULL_DISABLED))
	return _root


static func _tube(tool: SurfaceTool, base: int, path: Callable, from_radius: float, to_radius: float) -> void:
	"""A tapering ROOT_SIDES-sided tube along `path(u)`, u in 0..1, in ROOT_BENDS bands, its first vertex
	the tool's `base`th."""
	for i in ROOT_BENDS + 1:
		var u := float(i) / float(ROOT_BENDS)
		var at: Vector3 = path.call(u)
		var ahead: Vector3 = (path.call(minf(u + 0.01, 1.0)) as Vector3) - (path.call(maxf(u - 0.01, 0.0)) as Vector3)
		var across := ahead.cross(Vector3.FORWARD).normalized()
		var up := across.cross(ahead).normalized()
		for k in ROOT_SIDES:
			var angle := TAU * float(k) / float(ROOT_SIDES)
			tool.add_vertex(at + (across * cos(angle) + up * sin(angle)) * lerpf(from_radius, to_radius, u))
	for i in ROOT_BENDS:
		for k in ROOT_SIDES:
			var a := base + i * ROOT_SIDES + k
			var b := base + i * ROOT_SIDES + (k + 1) % ROOT_SIDES
			for index: int in [a, b, a + ROOT_SIDES, b, b + ROOT_SIDES, a + ROOT_SIDES]:
				tool.add_index(index)


static func _material(roughness: float, cull: BaseMaterial3D.CullMode) -> StandardMaterial3D:
	"""A rough material coloured per instance (the MultiMesh's colours)."""
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.roughness = roughness
	material.cull_mode = cull
	return material
