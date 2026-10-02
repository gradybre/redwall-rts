extends Node3D
## The treads of the demo's STAIRS between levels. Decision 0212 (the underground revamp's P6; design
## docs/design/underground_revamp.md §3 rule 7, §7 "timber ramp risers and stairs"). Presentation only.
##
## A STAIRS link (tunnel_rules.gd LINKS) is swept as a bore half a riser under its walking line (bore_view.gd
## `floor_offset`), and on that sloping floor stand its Rules.STAIR_RISERS STEPS (decision 0212; their timber, decision
## 0371): each a block of packed earth one tread long, one riser deep, a bore's floor wide, under a timber TREAD board
## whose NOSING overhangs a timber RISER board at its front -- planks with the grain running across the stair, in a
## procedural timber texture (`timber_texture`). The walking line runs through the middle of every tread's top, so a
## walker's planted feet meet a tread (resident_brain.gd walks the line). A step stands once the dig has passed it.
##
## One MultiMesh a stairs segment and level: level 1's on its layer, cut at its section, and a TWIN on level 2's,
## cut at level 2's (demo_layers.gd `below`, `cap_y`) -- the link is seen from both levels (bore_view.gd LEVELS).
## Built when dug, never on a view switch; its two materials a level are registered for the prewarm at boot.

const Rules := preload("res://demo/tunnel/tunnel_rules.gd")
const GraphScript := preload("res://demo/tunnel/underground_graph.gd")
const Layers := preload("res://demo/demo_layers.gd")
const PrewarmScript := preload("res://demo/tunnel/underground_prewarm.gd")
const BoreCurveScript := preload("res://demo/tunnel/bore_curve.gd")
const CUTAWAY_SHADER := preload("res://demo/tunnel/cutaway.gdshader")

## A tread's width (m, a little inside the bore's 1.0 m floor); the tread board's thickness (m); the riser board's
## thickness and the nosing's overhang past it (shares of the tread's length: the unit step is stretched to each
## tread's, 0.31-0.5 m, so they are 2-4 cm).
const TREAD_WIDTH_M: float = 0.94
const TREAD_BOARD_M: float = 0.045
const BOARD_M: float = 0.08
const NOSING: float = 0.08
const EARTH_COLOUR: Color = Color(0.4, 0.3, 0.21)
const TIMBER_COLOUR: Color = Color(0.62, 0.47, 0.32)
## The timber texture: GRAIN_PX across, its planks PLANKS to the texture, the grain repeating GRAIN_PER_M a metre.
const GRAIN_PX: int = 128
const PLANKS: int = 4
const GRAIN_PER_M: float = 1.6
## A step is cut this far under its level's section (as a brace is: never through the cut).
const CUT_SLACK_M: float = 0.02

## One unit step mesh a level (a tread block, its tread and riser boards, 1 m long along +Z before scaling), shared,
## and the timber texture.
static var _steps: Array[ArrayMesh] = [null, null, null]
static var _grain: ImageTexture = null

var _network: GraphScript = null
## Per segment slot: level 1's steps and level 2's twin (null until it is first a stairs).
var _nodes: Array[MultiMeshInstance3D] = []
var _twins: Array[MultiMeshInstance3D] = []
var _shown: PackedInt32Array = PackedInt32Array()
var _sample: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])


func configure(network: GraphScript) -> void:
	"""Treads for this network's stairs: a row per segment slot, each made when first needed."""
	name = "Stairs"
	_network = network
	_nodes.resize(Rules.MAX_SEGMENTS)
	_twins.resize(Rules.MAX_SEGMENTS)
	_shown.resize(Rules.MAX_SEGMENTS)


static func step_mesh(level: int) -> ArrayMesh:
	"""The unit step of `level` (see the header): the block in packed earth, the tread and riser boards in timber, each
	surface in its own cutaway material cut at the level's section. Built once a level."""
	var at := clampi(level, Rules.TOP_LEVEL, Rules.DEEPEST_LEVEL)
	if _steps[at] != null:
		return _steps[at]
	var rise := Rules.to_m(Rules.STAIR_RISE_U)
	var mesh := ArrayMesh.new()
	var block := rise - TREAD_BOARD_M
	_add_box(mesh, [Vector3(TREAD_WIDTH_M, block, 1.0 - BOARD_M)], [Vector3(0.0, -TREAD_BOARD_M - block * 0.5, -BOARD_M * 0.5)],
		_cut(EARTH_COLOUR, 1.0, at, null))
	_add_box(mesh, [Vector3(TREAD_WIDTH_M, TREAD_BOARD_M, 1.0 + NOSING), Vector3(TREAD_WIDTH_M, block, BOARD_M)],
		[Vector3(0.0, -TREAD_BOARD_M * 0.5, NOSING * 0.5), Vector3(0.0, -TREAD_BOARD_M - block * 0.5, 0.5 - BOARD_M * 0.5)],
		_cut(TIMBER_COLOUR, 0.8, at, timber_texture()))
	_steps[at] = mesh
	return mesh


static func _add_box(mesh: ArrayMesh, sizes: Array[Vector3], centres: Array[Vector3], material: Material) -> void:
	"""One surface of boxes, `sizes[k]` at `centres[k]`, in `material` on `mesh`, their UVs laid so the grain runs across
	the stair (u along x) at GRAIN_PER_M."""
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in sizes.size():
		var box := BoxMesh.new()
		box.size = sizes[k]
		var arrays := box.get_mesh_arrays()
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for index: int in arrays[Mesh.ARRAY_INDEX]:
			var at: Vector3 = verts[index] + centres[k]
			tool.set_normal(normals[index])
			tool.set_uv(Vector2(at.x * GRAIN_PER_M, (at.y + at.z) * GRAIN_PER_M))
			tool.add_vertex(at)
	tool.commit(mesh)
	mesh.surface_set_material(mesh.get_surface_count() - 1, material)


static func timber_texture() -> ImageTexture:
	"""The steps' timber, drawn once: PLANKS boards of wavy grain, a dark seam between them, tileable."""
	if _grain == null:
		var image := Image.create_empty(GRAIN_PX, GRAIN_PX, false, Image.FORMAT_RGB8)
		for y in GRAIN_PX:
			for x in GRAIN_PX:
				image.set_pixel(x, y, grain_pixel(float(x) / float(GRAIN_PX), float(y) / float(GRAIN_PX)))
		image.generate_mipmaps()
		_grain = ImageTexture.create_from_image(image)
	return _grain


static func grain_pixel(u: float, v: float) -> Color:
	"""The timber at (u, v), 0..1 across the texture: grain lines along u that waver, lighter and darker by board, and a
	dark seam where two boards meet (along u, every 1 / PLANKS of v)."""
	var board := floorf(v * float(PLANKS))
	var across := fposmod(v * float(PLANKS), 1.0)
	var wave := sin(TAU * (u * 2.0 + board * 0.37)) * 0.08 + sin(TAU * u * 5.0) * 0.02
	var line := 0.5 + 0.5 * sin(TAU * (across * 6.0 + wave))
	var tone := 0.86 + 0.14 * line - 0.06 * fposmod(board * 0.61, 1.0)
	var seam := 0.45 if across < 0.05 or across > 0.97 else 1.0
	return Color(tone * seam, tone * seam, tone * seam)


static func _cut(colour: Color, roughness: float, level: int, albedo: Texture2D) -> ShaderMaterial:
	"""A cutaway material in `colour` (over `albedo`, when given), cut just under `level`'s section."""
	var material := ShaderMaterial.new()
	material.shader = CUTAWAY_SHADER
	material.set_shader_parameter(&"albedo_colour", colour)
	material.set_shader_parameter(&"roughness", roughness)
	material.set_shader_parameter(&"cut_y", Layers.cap_y(level) - CUT_SLACK_M)
	if albedo != null:
		material.set_shader_parameter(&"albedo_texture", albedo)
	return material


func register(prewarm: PrewarmScript) -> void:
	"""Every level's step, drawn instanced, for the U view's prewarm."""
	for level in range(Rules.TOP_LEVEL, Rules.DEEPEST_LEVEL + 1):
		prewarm.add_multimesh(step_mesh(level))


func place(slot: int, dug_m: float) -> int:
	"""Stand segment `slot`'s treads as far as its dig has reached (`dug_m`), on both levels; none when it is not a
	stairs. Returns how many stand."""
	if _network.seg_link[slot] != Rules.LINK_STAIRS or _network.seg_kind[slot] != GraphScript.SEG_LINK:
		clear(slot)
		return 0
	_ensure(slot)
	var run := _network.length_m(slot)
	var tread := run / float(Rules.STAIR_RISERS)
	var count := clampi(floori(dug_m / tread + 1e-4), 0, Rules.STAIR_RISERS)
	if count == _shown[slot] and _nodes[slot].visible:
		return count
	_shown[slot] = count
	for i in count:
		var at := step_transform(slot, i, tread)
		_nodes[slot].multimesh.set_instance_transform(i, at)
		_twins[slot].multimesh.set_instance_transform(i, at)
	for node: MultiMeshInstance3D in [_nodes[slot], _twins[slot]]:
		node.multimesh.visible_instance_count = count
		node.visible = count > 0
	return count


func step_transform(slot: int, i: int, tread: float) -> Transform3D:
	"""Tread `i` of stairs `slot` (each `tread` m long): its top's middle on the walking line (see the header),
	facing down the stairs, stretched to the tread's length."""
	var along := (float(i) + 0.5) * tread
	BoreCurveScript.of(_network, slot).sample(along, _sample)
	var heading: Vector2 = _sample[1]
	var tread_basis := Basis(Vector3(-heading.y, 0.0, heading.x), Vector3.UP, Vector3(heading.x, 0.0, heading.y))
	var top := Vector3(_sample[0].x, _network.floor_y_at(slot, along), _sample[0].y)
	return Transform3D(tread_basis.scaled_local(Vector3(1.0, 1.0, tread)), top)


func clear(slot: int) -> void:
	"""Stand no treads for segment `slot`."""
	_shown[slot] = 0
	for node: MultiMeshInstance3D in [_nodes[slot], _twins[slot]]:
		if node != null:
			node.visible = false


func _ensure(slot: int) -> void:
	"""Segment `slot`'s two step MultiMeshes, made once."""
	if _nodes[slot] != null:
		return
	_nodes[slot] = _multi(Rules.TOP_LEVEL)
	_twins[slot] = _multi(Rules.LEVEL_2)


func _multi(level: int) -> MultiMeshInstance3D:
	"""A MultiMesh of `level`'s step for up to STAIR_RISERS treads, on its layer, none shown."""
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = step_mesh(level)
	multimesh.instance_count = Rules.STAIR_RISERS
	multimesh.visible_instance_count = 0
	var node := MultiMeshInstance3D.new()
	node.multimesh = multimesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.layers = Layers.below(level)
	node.visible = false
	add_child(node)
	return node


func steps(slot: int, twin: bool = false) -> MultiMeshInstance3D:
	"""Stairs `slot`'s steps on level 1 (or level 2's twin); null before it was first a stairs (checks)."""
	return _twins[slot] if twin else _nodes[slot]
