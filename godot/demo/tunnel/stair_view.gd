extends Node3D
## The treads of the demo's STAIRS between levels. Decision 0212 (the underground revamp's P6; design
## docs/design/underground_revamp.md §3 rule 7, §7 "timber ramp risers and stairs"). Presentation only.
##
## A STAIRS link (tunnel_rules.gd LINKS) is swept as a bore half a riser under its walking line (bore_view.gd
## `floor_offset`), and on that sloping floor stand its Rules.STAIR_RISERS TREADS: each a block of packed earth
## one tread long, one riser deep, a bore's floor wide, fronted by a timber RISER board. The walking line runs
## through the middle of every tread's top, so a walker's planted feet meet a tread (resident_brain.gd walks the
## line). A tread stands once the dig has passed it.
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

## A tread's width (m, a little inside the bore's 1.0 m floor), and its riser board's thickness (a share of the
## tread's length: the unit step is stretched to each tread's).
const TREAD_WIDTH_M: float = 0.94
const BOARD_M: float = 0.12
const EARTH_COLOUR: Color = Color(0.4, 0.3, 0.21)
const TIMBER_COLOUR: Color = Color(0.46, 0.31, 0.17)
## A step is cut this far under its level's section (as a brace is: never through the cut).
const CUT_SLACK_M: float = 0.02

## One unit step mesh a level (a tread block and its riser board, 1 m long along +Z before scaling), shared.
static var _steps: Array[ArrayMesh] = [null, null, null]

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
	"""The unit step of `level` (see the header): the tread block in packed earth and the riser board in timber, each
	surface in its own cutaway material cut at the level's section. Built once a level."""
	var at := clampi(level, Rules.TOP_LEVEL, Rules.DEEPEST_LEVEL)
	if _steps[at] != null:
		return _steps[at]
	var rise := Rules.to_m(Rules.STAIR_RISE_U)
	var mesh := ArrayMesh.new()
	_add_box(mesh, Vector3(TREAD_WIDTH_M, rise, 1.0), Vector3(0.0, -rise * 0.5, 0.0), _cut(EARTH_COLOUR, 1.0, at))
	_add_box(mesh, Vector3(TREAD_WIDTH_M, rise, BOARD_M), Vector3(0.0, -rise * 0.5, 0.5), _cut(TIMBER_COLOUR, 0.8, at))
	_steps[at] = mesh
	return mesh


static func _add_box(mesh: ArrayMesh, size: Vector3, centre: Vector3, material: Material) -> void:
	"""One box surface of `size` at `centre` in `material` on `mesh`."""
	var box := BoxMesh.new()
	box.size = size
	var arrays := box.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for k in verts.size():
		verts[k] += centre
	arrays[Mesh.ARRAY_VERTEX] = verts
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(mesh.get_surface_count() - 1, material)


static func _cut(colour: Color, roughness: float, level: int) -> ShaderMaterial:
	"""A plain cutaway material in `colour`, cut just under `level`'s section."""
	var material := ShaderMaterial.new()
	material.shader = CUTAWAY_SHADER
	material.set_shader_parameter(&"albedo_colour", colour)
	material.set_shader_parameter(&"roughness", roughness)
	material.set_shader_parameter(&"cut_y", Layers.cap_y(level) - CUT_SLACK_M)
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
	var basis := Basis(Vector3(-heading.y, 0.0, heading.x), Vector3.UP, Vector3(heading.x, 0.0, heading.y))
	var top := Vector3(_sample[0].x, _network.floor_y_at(slot, along), _sample[0].y)
	return Transform3D(basis.scaled_local(Vector3(1.0, 1.0, tread)), top)


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
