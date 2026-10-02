extends Node3D
## The herb patch on the woods' floor, drawn: low leafy clumps with pale flower heads, as many standing as the patch
## holds (§5.5's stock over its capacity). Decision 0622. Presentation only, and procedural: the asset library has no
## herb model, and no paid generation is used (agent rules). Built once; `show_stock` only shows or hides clumps.
## THE FOOD ART'S HERB PATCH (decision 0941; wired by the batch 8 integration, decision 0903): where it is staged, the
## village hands it in (`use_model`) and it is drawn in place of the clumps, about 1.9 m across, smaller as the stock
## runs down (MODEL_LEAST of its size at one clump's worth) and gone when the patch is empty; the clump count it stands
## for is kept, so the checks read the same either way.

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
## The herb patch model's size at one clump's worth of stock (a share of its full size).
const MODEL_LEAST: float = 0.55

var _clumps: Array[Node3D] = []
var _shown: int = -1
## The food art's patch (null: the clumps), and its transform at full size.
var _model: Node3D = null
var _model_base: Transform3D = Transform3D.IDENTITY


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


func use_model(model: Node3D) -> void:
	"""Draw the food art's herb patch `model` (made at this node's origin) in place of the clumps (null: keep them)."""
	if model == null:
		return
	_model = model
	_model_base = model.transform
	add_child(model)
	var shown: int = _shown
	_shown = -1
	show_stock(maxi(shown, 0) * Rules.HERB_CAPACITY_MILLI / CLUMPS)


func show_stock(stock_milli: int) -> void:
	"""Stand as many clumps as the patch holds: ceil(CLUMPS x stock / capacity) -- or the model at that share."""
	var shown: int = clampi((CLUMPS * stock_milli + Rules.HERB_CAPACITY_MILLI - 1) / Rules.HERB_CAPACITY_MILLI, 0, CLUMPS)
	if shown == _shown:
		return
	_shown = shown
	for k: int in _clumps.size():
		_clumps[k].visible = k < shown and _model == null
	if _model != null:
		_model.visible = shown > 0
		var size: float = lerpf(MODEL_LEAST, 1.0, float(maxi(shown - 1, 0)) / float(CLUMPS - 1))
		_model.transform = Transform3D(Basis.from_scale(Vector3.ONE * size), Vector3.ZERO) * _model_base


func has_model() -> bool:
	"""Whether the food art's patch is drawn (checks)."""
	return _model != null


func shown_clumps() -> int:
	"""How many clumps stand (checks)."""
	return maxi(_shown, 0)
