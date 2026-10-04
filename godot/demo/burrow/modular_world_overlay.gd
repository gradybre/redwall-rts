extends Node3D
## World-coordinate drawing preview. No terrain, project, room or paid-cut state is owned here.

const Footprint := preload("res://scripts/core/room_footprint.gd")
const Palette := preload("res://demo/ui/woodland_palette.gd")
const PlanShader := preload("res://demo/burrow/modular_plan.gdshader")
const UNITS_PER_M: float = 1024.0

var rebuilds: int = 0
var _datum: Vector3i = Vector3i.ZERO
var _pitch: int = 0
var _bounds: Rect2i = Rect2i()
var _grid: MeshInstance3D = null
var _fill: MeshInstance3D = null
var _edge: MeshInstance3D = null
var _cells: PackedInt32Array = PackedInt32Array()
var _invalid: bool = false
var _initialized: bool = false


func configure(datum: Vector3i, pitch_u: int, bounds: Rect2i, marks_layer: int) -> StringName:
	"""Bind the exact drawing datum once; no implicit level depth or world-origin recentering."""
	if _initialized:
		return &"WORLD_OVERLAY_ALREADY_BOUND"
	if pitch_u < 1 or bounds.size.x < 1 or bounds.size.y < 1 or marks_layer < 1 or marks_layer > 1048575:
		return &"WORLD_OVERLAY_DOMAIN"
	var far_x: int = int(bounds.position.x) + int(bounds.size.x)
	var far_z: int = int(bounds.position.y) + int(bounds.size.y)
	if far_x > 2147483647 or far_z > 2147483647:
		return &"WORLD_OVERLAY_DOMAIN"
	var corners: PackedInt32Array = PackedInt32Array([bounds.position.x, bounds.position.y, far_x, far_z])
	corners.append_array(PackedInt32Array([bounds.position.x + 1, bounds.position.y + 1, far_x - 1, far_z - 1]))
	if not _renderable(corners, datum, pitch_u):
		return &"WORLD_OVERLAY_PRECISION"
	_datum = datum
	_pitch = pitch_u
	_bounds = bounds
	set_as_top_level(true)
	_grid = _node(marks_layer, _material(0.0, 0.055))
	_fill = _node(marks_layer, _material(0.17, 0.23))
	_edge = _node(marks_layer, _edge_material())
	_grid.mesh = _rectangle(bounds)
	_initialized = true
	return &""


func refresh(cells: PackedInt32Array, invalid: bool) -> StringName:
	"""Rebuild only changed geometry; camera movement and repeated UI notifications reuse meshes."""
	if not _initialized or cells.size() % 2 != 0 or cells.size() > Footprint.MAX_OPERATION_CELLS * 2:
		return &"WORLD_OVERLAY_DOMAIN"
	if cells == _cells and invalid == _invalid:
		return &""
	for at: int in range(0, cells.size(), 2):
		if not _bounds.has_point(Vector2i(cells[at], cells[at + 1])):
			return &"WORLD_OVERLAY_BOUNDS"
	if cells != _cells:
		_cells = cells.duplicate()
		_fill.mesh = _floor_mesh(cells)
		_edge.mesh = _boundary_mesh(cells)
		rebuilds += 1
	_invalid = invalid
	var colour: Color = Palette.CLAY if invalid else Palette.CREAM
	(_fill.material_override as ShaderMaterial).set_shader_parameter(&"tint", colour)
	(_edge.material_override as StandardMaterial3D).albedo_color = colour
	return &""


func world_corner(cell: Vector2i) -> Vector3:
	"""The exact same cell boundary/datum as input, converted to metres for presentation only."""
	return Vector3(int(_datum.x) + int(cell.x) * _pitch, _datum.y,
		int(_datum.z) + int(cell.y) * _pitch) / UNITS_PER_M


static func _renderable(cells: PackedInt32Array, datum: Vector3i, pitch_u: int) -> bool:
	"""Refuse float32 display loss instead of showing a shifted boundary at extreme coordinates."""
	var converted: Dictionary = Footprint.to_world_corners(cells, pitch_u, datum.x, datum.z)
	if not converted.ok:
		return false
	for at: int in range(0, converted.points.size(), 2):
		var point: Vector3 = Vector3(converted.points[at], datum.y, converted.points[at + 1]) / UNITS_PER_M
		if int(point.x * UNITS_PER_M) != converted.points[at] or int(point.y * UNITS_PER_M) != datum.y \
				or int(point.z * UNITS_PER_M) != converted.points[at + 1]:
			return false
		var quarter_x: int = int(converted.points[at]) * 4 + pitch_u
		var quarter_z: int = int(converted.points[at + 1]) * 4 + pitch_u
		var interior: Vector3 = Vector3(quarter_x, int(datum.y) * 4, quarter_z) / (UNITS_PER_M * 4.0)
		if int(interior.x * UNITS_PER_M * 4.0) != quarter_x or int(interior.z * UNITS_PER_M * 4.0) != quarter_z:
			return false
	return true


func _material(fill: float, lines: float) -> ShaderMaterial:
	"""A physically scaled grid with a common world datum, including nonzero map origins."""
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = PlanShader
	material.set_shader_parameter(&"datum_m", Vector2(_datum.x, _datum.z) / UNITS_PER_M)
	material.set_shader_parameter(&"pitch_m", float(_pitch) / UNITS_PER_M)
	material.set_shader_parameter(&"fill_alpha", fill)
	material.set_shader_parameter(&"line_alpha", lines)
	material.render_priority = 2
	return material


static func _edge_material() -> StandardMaterial3D:
	"""A readable outline supplements the status words; colour is never the only refusal cue."""
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	material.render_priority = 3
	material.albedo_color = Palette.CREAM
	return material


func _node(layer: int, material: Material) -> MeshInstance3D:
	"""Keep marks on the selected level, separate from the real cap, lighting and room shell."""
	var node: MeshInstance3D = MeshInstance3D.new()
	node.layers = layer
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node


func _rectangle(bounds: Rect2i) -> ImmediateMesh:
	"""One quad supplies the grid over the explicit finite terrain domain."""
	var mesh: ImmediateMesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	_quad(mesh, bounds.position, bounds.end)
	mesh.surface_end()
	return mesh


func _floor_mesh(cells: PackedInt32Array) -> ImmediateMesh:
	"""Each selected integer cell contributes exactly two triangles, with no bounding-box fill."""
	var mesh: ImmediateMesh = ImmediateMesh.new()
	if cells.is_empty():
		return mesh
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for at: int in range(0, cells.size(), 2):
		var cell: Vector2i = Vector2i(cells[at], cells[at + 1])
		_quad(mesh, cell, cell + Vector2i.ONE)
	mesh.surface_end()
	return mesh


func _quad(mesh: ImmediateMesh, low: Vector2i, high: Vector2i) -> void:
	"""Generate the same shared corners for concave and adjacent cells."""
	for cell: Vector2i in [low, Vector2i(high.x, low.y), high, low, high, Vector2i(low.x, high.y)]:
		mesh.surface_add_vertex(world_corner(cell))


func _boundary_mesh(cells: PackedInt32Array) -> ImmediateMesh:
	"""Only exposed cell edges form the room outline; interior grid lines remain lighter."""
	var mesh: ImmediateMesh = ImmediateMesh.new()
	var edges: PackedInt32Array = Footprint.boundary_edges(cells)
	if edges.is_empty():
		return mesh
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for at: int in range(0, edges.size(), 3):
		var cell: Vector2i = Vector2i(edges[at], edges[at + 1])
		var side: int = edges[at + 2]
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
		mesh.surface_add_vertex(world_corner(start))
		mesh.surface_add_vertex(world_corner(end))
	mesh.surface_end()
	return mesh
