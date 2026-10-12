extends "res://demo/burrow/modular_world_overlay.gd"
## One painted room's ghost on one level's floor (UI-BUILD-010; decision 1871): the planner's own world overlay
## (modular_world_overlay.gd: the exact cells and their outline, on the 1 m grid) tinted by its validity -- GOLD can
## build, WARNING blocked, DANGER not possible (build_validity.gd TOKENS) -- with a name tag in words over it, so the
## state is never told by colour alone. Only the level's grid-owning ghost draws the 1 m grid. Presentation only.

const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const Validity := preload("res://scripts/ui/build_validity.gd")

const TAG_PX: int = 40
const TAG_PIXEL_SIZE: float = 0.01
const TAG_LIFT_M: float = 0.2

var _tag: Label3D = null


func configure_ghost(datum: Vector3i, bounds: Rect2i, marks_layer: int, owns_grid: bool) -> StringName:
	"""Bind the floor's datum on the 1 m grid; only a grid-owning ghost shows the grid."""
	var code: StringName = configure(datum, 1024, bounds, marks_layer)
	if code != &"":
		return code
	_grid.visible = owns_grid
	_tag = Label3D.new()
	_tag.layers = marks_layer
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.no_depth_test = true
	_tag.font_size = TAG_PX
	_tag.pixel_size = TAG_PIXEL_SIZE
	_tag.outline_size = 8
	_tag.render_priority = 5
	_tag.outline_render_priority = 4
	add_child(_tag)
	return &""


func show_cells(cells: PackedInt32Array, kind: int, words: String) -> void:
	"""Draw `cells` tinted for validity `kind`, its words on a tag over their middle ("" hides the tag)."""
	refresh(cells, kind != Validity.KIND_CAN_BUILD)
	var colour: Color = UiTheme.color_of(Validity.token(kind))
	(_fill.material_override as ShaderMaterial).set_shader_parameter(&"tint", colour)
	(_edge.material_override as StandardMaterial3D).albedo_color = colour
	_tag.text = words
	_tag.modulate = colour
	_tag.visible = not words.is_empty() and not cells.is_empty()
	if _tag.visible:
		_tag.position = _middle(cells) + Vector3(0.0, TAG_LIFT_M, 0.0)


func _middle(cells: PackedInt32Array) -> Vector3:
	"""The middle of the cells' bounding box, on the floor, in metres."""
	var low: Vector2i = Vector2i(cells[0], cells[1])
	var high: Vector2i = low
	for at: int in range(0, cells.size(), 2):
		low = low.min(Vector2i(cells[at], cells[at + 1]))
		high = high.max(Vector2i(cells[at], cells[at + 1]))
	return (world_corner(low) + world_corner(high + Vector2i.ONE)) / 2.0


func tag_text() -> String:
	"""What the tag says (checks)."""
	return _tag.text if _tag != null and _tag.visible else ""
