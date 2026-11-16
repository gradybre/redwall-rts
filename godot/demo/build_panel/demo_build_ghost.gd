extends "res://demo/burrow/modular_world_overlay.gd"
## One group of a painted room's cells on one level's floor (UI-BUILD-010; decisions 1871 and 1912): the planner's
## own world overlay (modular_world_overlay.gd: the exact cells and their outline, on the 1 m grid) drawn as the
## section asks -- "valid cells GOLD outline, blocked WARNING dashed, impossible DANGER hatched and numbered against
## the reason list" -- with a tag in words over it, so the state is never told by colour alone. P-B9 (a), ruled for
## slice C. Only the level's grid-owning ghost draws the 1 m grid. Presentation only.
##
##   ✓  GOLD     solid outline, plain fill
##   !  WARNING  DASHED outline: each exposed cell edge drawn as two dashes of DASH_M with gaps between
##   X  DANGER   solid outline, HATCHED fill (build_ghost.gdshader `hatch`), its tag numbered ("X1 ...")

const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const Validity := preload("res://scripts/ui/build_validity.gd")
const GhostShader := preload("res://demo/build_panel/build_ghost.gdshader")

const TAG_PX: int = 40
## The tag's widest line before it wraps (Label3D pixels, at TAG_PX): about 40 characters.
const TAG_WRAP_PX: float = 900.0
const TAG_PIXEL_SIZE: float = 0.01
const TAG_LIFT_M: float = 0.2
## A dash along a 1 m cell edge (two a cell, the gaps between them and at the corners 0.2 m).
const DASH_M: float = 0.3
const DASH_STARTS_M: Array[float] = [0.1, 0.6]
## The base overlay's room fill and its grid lines (modular_world_overlay.gd `_material(0.17, 0.23)`).
const FILL_ALPHA: float = 0.17
const LINE_ALPHA: float = 0.23

var _tag: Label3D = null
var _kind: int = Validity.KIND_CAN_BUILD
var _drawn: PackedInt32Array = PackedInt32Array()
var _dashed: bool = false


func configure_ghost(datum: Vector3i, bounds: Rect2i, marks_layer: int, owns_grid: bool) -> StringName:
	"""Bind the floor's datum on the 1 m grid; only a grid-owning ghost shows the grid."""
	var code: StringName = configure(datum, 1024, bounds, marks_layer)
	if code != &"":
		return code
	_grid.visible = owns_grid
	var fill: ShaderMaterial = _fill.material_override as ShaderMaterial
	fill.shader = GhostShader
	fill.set_shader_parameter(&"datum_m", Vector2(_datum.x, _datum.z) / UNITS_PER_M)
	fill.set_shader_parameter(&"pitch_m", float(_pitch) / UNITS_PER_M)
	fill.set_shader_parameter(&"fill_alpha", FILL_ALPHA)
	fill.set_shader_parameter(&"line_alpha", LINE_ALPHA)
	_tag = Label3D.new()
	_tag.layers = marks_layer
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.no_depth_test = true
	_tag.font_size = TAG_PX
	_tag.pixel_size = TAG_PIXEL_SIZE
	_tag.outline_size = 8
	_tag.render_priority = 5
	_tag.outline_render_priority = 4
	# A long reason wraps rather than running off across the HUD (decision 2022).
	_tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tag.width = TAG_WRAP_PX
	add_child(_tag)
	return &""


func show_cells(cells: PackedInt32Array, shown_kind: int, words: String) -> void:
	"""Draw `cells` as validity `shown_kind` wants (see the header), its words on a tag over their middle ("" hides
	it)."""
	refresh(cells, shown_kind != Validity.KIND_CAN_BUILD)
	var colour: Color = UiTheme.color_of(Validity.token(shown_kind))
	var fill: ShaderMaterial = _fill.material_override as ShaderMaterial
	fill.set_shader_parameter(&"tint", colour)
	fill.set_shader_parameter(&"hatch", 1.0 if shown_kind == Validity.KIND_NOT_POSSIBLE else 0.0)
	(_edge.material_override as StandardMaterial3D).albedo_color = colour
	_outline(cells, shown_kind == Validity.KIND_BLOCKED)
	_kind = shown_kind
	_tag.text = words
	_tag.modulate = colour
	_tag.visible = not words.is_empty() and not cells.is_empty()
	if _tag.visible:
		_tag.position = _middle(cells) + Vector3(0.0, TAG_LIFT_M, 0.0)


func _outline(cells: PackedInt32Array, dash: bool) -> void:
	"""The outline dashed for a blocked group (rebuilt only when the cells or the dashing changed)."""
	if cells == _drawn and dash == _dashed:
		return
	_drawn = cells.duplicate()
	_dashed = dash
	_edge.mesh = _dash_mesh(cells) if dash else _boundary_mesh(cells)


func _dash_mesh(cells: PackedInt32Array) -> ImmediateMesh:
	"""Each exposed cell edge as two dashes (the base overlay's `_boundary_mesh` edges, cut)."""
	var mesh: ImmediateMesh = ImmediateMesh.new()
	var edges: PackedInt32Array = Footprint.boundary_edges(cells)
	if edges.is_empty():
		return mesh
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for at: int in range(0, edges.size(), 3):
		var ends: Array[Vector3] = _edge_ends(Vector2i(edges[at], edges[at + 1]), edges[at + 2])
		var along: Vector3 = (ends[1] - ends[0]).normalized()
		for start: float in DASH_STARTS_M:
			mesh.surface_add_vertex(ends[0] + along * start)
			mesh.surface_add_vertex(ends[0] + along * (start + DASH_M))
	mesh.surface_end()
	return mesh


func _edge_ends(cell: Vector2i, side: int) -> Array[Vector3]:
	"""The two ends of `cell`'s `side` edge, in metres (the base overlay's corners)."""
	var start: Vector2i = cell
	var end: Vector2i = cell
	match side:
		Footprint.NORTH:
			end.x += 1
		Footprint.EAST:
			start.x += 1
			end += Vector2i.ONE
		Footprint.SOUTH:
			start += Vector2i.ONE
			end.y += 1
		Footprint.WEST:
			start.y += 1
	return [world_corner(start), world_corner(end)]


func _middle(cells: PackedInt32Array) -> Vector3:
	"""The middle of the cells' bounding box, on the floor, in metres."""
	var low: Vector2i = Vector2i(cells[0], cells[1])
	var high: Vector2i = low
	for at: int in range(0, cells.size(), 2):
		low = low.min(Vector2i(cells[at], cells[at + 1]))
		high = high.max(Vector2i(cells[at], cells[at + 1]))
	return (world_corner(low) + world_corner(high + Vector2i.ONE)) / 2.0


func tag() -> Label3D:
	"""The tag (decision 1991: spaced with the level's other tags, demo_build_tags.gd)."""
	return _tag


func tag_text() -> String:
	"""What the tag says (checks)."""
	return _tag.text if _tag != null and _tag.visible else ""


func dashed() -> bool:
	"""Whether the outline is dashed (checks)."""
	return _dashed


func hatched() -> bool:
	"""Whether the fill is hatched (checks)."""
	return float((_fill.material_override as ShaderMaterial).get_shader_parameter(&"hatch")) > 0.5


func kind() -> int:
	"""The validity kind drawn (checks)."""
	return _kind
