extends Node3D
## The herb patch on the woods' floor, drawn: low leafy clumps with pale flower heads, as many standing as the patch
## holds (§5.5's stock over its capacity). Decision 0622. Presentation only, and procedural: the asset library has no
## herb model, and no paid generation is used (agent rules). Built once; `show_stock` only shows or hides clumps.

const Rules := preload("res://demo/infirmary/care_rules.gd")

@warning_ignore_start("integer_division")

const CLUMPS: int = 12
## The clumps stand within this radius of the patch's middle (m), each about LEAF_M across.
const RADIUS_M: float = 1.1
const LEAF_M: float = 0.22
const LEAVES: int = 4
const FLOWER_M: float = 0.06
const LEAF_COLOUR: Color = Color(0.33, 0.47, 0.24)
const FLOWER_COLOUR: Color = Color(0.93, 0.9, 0.72)
const SEED: int = 6223

var _clumps: Array[Node3D] = []
var _shown: int = -1


func build(at: Vector2, ground_y: float) -> void:
	"""The patch's clumps round `at` (m), standing on `ground_y`."""
	name = "HerbPatch"
	position = Vector3(at.x, ground_y, at.y)
	var leaf := _mesh(LEAF_M, LEAF_COLOUR)
	var flower := _mesh(FLOWER_M, FLOWER_COLOUR)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for k: int in CLUMPS:
		var clump := Node3D.new()
		var angle: float = TAU * float(k) / float(CLUMPS) + rng.randf_range(-0.2, 0.2)
		var reach: float = RADIUS_M * sqrt(rng.randf_range(0.05, 1.0))
		clump.position = Vector3(cos(angle) * reach, 0.0, sin(angle) * reach)
		clump.rotation.y = rng.randf_range(0.0, TAU)
		_leaves(clump, leaf, flower, rng)
		add_child(clump)
		_clumps.append(clump)


func _leaves(clump: Node3D, leaf: Mesh, flower: Mesh, rng: RandomNumberGenerator) -> void:
	"""One clump: LEAVES flattened leaves splayed round its foot and one pale flower head over them."""
	for j: int in LEAVES:
		var part := MeshInstance3D.new()
		part.mesh = leaf
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a: float = TAU * float(j) / float(LEAVES)
		part.position = Vector3(cos(a) * LEAF_M * 0.5, LEAF_M * 0.35, sin(a) * LEAF_M * 0.5)
		part.scale = Vector3(1.0, 0.35, 0.55)
		part.rotation = Vector3(0.0, -a, rng.randf_range(0.3, 0.6))
		clump.add_child(part)
	var head := MeshInstance3D.new()
	head.mesh = flower
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	head.position = Vector3(0.0, LEAF_M * 1.4, 0.0)
	clump.add_child(head)


static func _mesh(size_m: float, colour: Color) -> SphereMesh:
	"""A small low-poly sphere of `size_m` across, in a matte `colour`."""
	var mesh := SphereMesh.new()
	mesh.radius = size_m * 0.5
	mesh.height = size_m
	mesh.radial_segments = 8
	mesh.rings = 4
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.9
	mesh.material = material
	return mesh


func show_stock(stock_milli: int) -> void:
	"""Stand as many clumps as the patch holds: ceil(CLUMPS x stock / capacity)."""
	var shown: int = clampi((CLUMPS * stock_milli + Rules.HERB_CAPACITY_MILLI - 1) / Rules.HERB_CAPACITY_MILLI, 0, CLUMPS)
	if shown == _shown:
		return
	_shown = shown
	for k: int in _clumps.size():
		_clumps[k].visible = k < shown


func shown_clumps() -> int:
	"""How many clumps stand (checks)."""
	return maxi(_shown, 0)
