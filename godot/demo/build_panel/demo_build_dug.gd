extends Node3D
## THE DUG ROOMS, DRAWN (decision 1912's proof of concept). On the level the build panel shows (the World view's marks
## layer, demo_build_world.gd), from demo_build_works.gd:
##   OPEN cells     an earth floor, and walls 1 m high where open space meets earth (decision 1932's 1 quantum; the
##                  proof of concept draws the room at that height)
##   ORDERED cells  a pale blueprint floor, waiting for the mole, named so in words ("Waiting for the mole: N cells")
##   ways down      a dark square where one stands and a lighter one where it lands, each named
## and on the surface (the village's own layers, seen without the panel) each confirmed Entrance as a dark hole named
## "Entrance". Rebuilt only when the works or the level shown change. Presentation only.

const Works := preload("res://demo/build_panel/demo_build_works.gd")
const Footprint := preload("res://scripts/core/room_footprint.gd")
const Layers := preload("res://demo/demo_layers.gd")

const LAYER: int = 256
const WALL_M: float = 1.0
const LIFT_M: float = 0.01
const UNITS_PER_M: float = 1024.0
const FLOOR: Color = Color(0.74, 0.6, 0.42)
const WALL: Color = Color(0.45, 0.33, 0.22)
const BLUEPRINT: Color = Color(0.46, 0.58, 0.7)
const SHAFT: Color = Color(0.12, 0.09, 0.07)
const LANDING: Color = Color(0.78, 0.66, 0.46)
const TAG_PX: int = 32
const WAITING: String = "Waiting for the mole: %d cells"
## Way-down names stand above a resident's own name tag (demo_build_figure.gd) so the two never overlap.
const TAG_LIFT_M: float = 2.2

var _works: Works = null
var _floors: PackedInt32Array = PackedInt32Array()
var _datum: Vector2i = Vector2i.ZERO
var _bounds: Rect2i = Rect2i()
var _below: MeshInstance3D = null
var _surface: MeshInstance3D = null
var _tags: Array[Label3D] = []
var _seen: Vector2i = Vector2i(-1, -1)
## The level's open and ordered cells, refilled on a rebuild (demo_build_works.gd `cells_into`: its box only).
var _open: PackedInt32Array = PackedInt32Array()
var _ordered: PackedInt32Array = PackedInt32Array()
## Rebuilds since configure (checks: nothing is rebuilt on a still frame).
var rebuilds: int = 0


func configure(works: Works, floors: PackedInt32Array, datum: Vector2i, bounds: Rect2i) -> void:
	"""Draw `works` on `floors` (u per level) from `datum` (u) over `bounds` (cells)."""
	name = "BuildDug"
	_works = works
	_floors = floors
	_datum = datum
	_bounds = bounds
	_below = _mesh_node(LAYER)
	_surface = _mesh_node(Layers.SURFACE)


func _mesh_node(layer: int) -> MeshInstance3D:
	"""One mesh node on `layer`, coloured by its vertices."""
	var node: MeshInstance3D = MeshInstance3D.new()
	node.layers = layer
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Flat colours: the underground view is dark by design (tunnel_view.gd), and the proof of concept must read.
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	node.material_override = material
	add_child(node)
	return node


func refresh(level: int) -> void:
	"""Redraw when the works or the level shown (-1: none) changed."""
	var key: Vector2i = Vector2i(_works.revision, level)
	if key == _seen:
		return
	_seen = key
	rebuilds += 1
	_below.mesh = _level_mesh(level) if level >= 1 else null
	_below.visible = level >= 1
	_surface.mesh = _entrances_mesh()
	_place_tags(level)


func _level_mesh(level: int) -> ImmediateMesh:
	"""The level's open floor and walls, ordered blueprint cells, and the ways down on it."""
	_works.cells_into(level, Works.OPEN, _open)
	_works.cells_into(level, Works.ORDERED, _ordered)
	var open: PackedInt32Array = _open
	var ordered: PackedInt32Array = _ordered
	var mesh: ImmediateMesh = ImmediateMesh.new()
	if open.is_empty() and ordered.is_empty():
		return mesh
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var y: float = _floors[level] / UNITS_PER_M + LIFT_M
	for at: int in range(0, open.size(), 2):
		_quad(mesh, Vector2i(open[at], open[at + 1]), y, FLOOR)
	for at: int in range(0, ordered.size(), 2):
		_quad(mesh, Vector2i(ordered[at], ordered[at + 1]), y, BLUEPRINT)
	_walls(mesh, open, y)
	_ways(mesh, level, y + LIFT_M)
	mesh.surface_end()
	return mesh


func _quad(mesh: ImmediateMesh, cell: Vector2i, y: float, colour: Color) -> void:
	"""One cell's square at height `y`."""
	var low: Vector3 = _corner(cell, y)
	var high: Vector3 = _corner(cell + Vector2i.ONE, y)
	mesh.surface_set_color(colour)
	mesh.surface_set_normal(Vector3.UP)
	for point: Vector3 in [low, Vector3(high.x, y, low.z), high, low, high, Vector3(low.x, y, high.z)]:
		mesh.surface_add_vertex(point)


func _walls(mesh: ImmediateMesh, open: PackedInt32Array, y: float) -> void:
	"""A 1 m wall on every edge where open space meets earth."""
	var edges: PackedInt32Array = Footprint.boundary_edges(open) if not open.is_empty() else PackedInt32Array()
	mesh.surface_set_color(WALL)
	for at: int in range(0, edges.size(), 3):
		var ends: Array[Vector2i] = _edge_ends(Vector2i(edges[at], edges[at + 1]), edges[at + 2])
		var a: Vector3 = _corner(ends[0], y)
		var b: Vector3 = _corner(ends[1], y)
		var up: Vector3 = Vector3(0.0, WALL_M, 0.0)
		mesh.surface_set_normal((b - a).cross(Vector3.UP).normalized())
		for point: Vector3 in [a, b, b + up, a, b + up, a + up]:
			mesh.surface_add_vertex(point)


static func _edge_ends(cell: Vector2i, side: int) -> Array[Vector2i]:
	"""The two corners of `cell`'s `side` edge (room_footprint.gd's sides)."""
	match side:
		Footprint.NORTH:
			return [cell, cell + Vector2i(1, 0)]
		Footprint.EAST:
			return [cell + Vector2i(1, 0), cell + Vector2i.ONE]
		Footprint.SOUTH:
			return [cell + Vector2i.ONE, cell + Vector2i(0, 1)]
	return [cell + Vector2i(0, 1), cell]


func _ways(mesh: ImmediateMesh, level: int, y: float) -> void:
	"""Each way down standing on (dark) or landing on (light) `level`."""
	for row: int in _works.way_count():
		var top: int = _works.way_level(row)
		if top != level and top + 1 != level:
			continue
		var cell: Vector2i = _works.way_cell(row)
		for offset: Vector2i in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1), Vector2i.ONE]:
			_quad(mesh, cell + offset, y, SHAFT if top == level else LANDING)


func _entrances_mesh() -> ImmediateMesh:
	"""Each confirmed Entrance as a dark 2 × 2 hole on the ground."""
	var mesh: ImmediateMesh = ImmediateMesh.new()
	var holes: int = 0
	for row: int in _works.way_count():
		if _works.way_level(row) != 0:
			continue
		if holes == 0:
			mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		holes += 1
		var cell: Vector2i = _works.way_cell(row)
		for offset: Vector2i in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1), Vector2i.ONE]:
			_quad(mesh, cell + offset, 0.04, SHAFT)
	if holes > 0:
		mesh.surface_end()
	return mesh


func _place_tags(level: int) -> void:
	"""A name over each way down seen: "Entrance" on the ground; "Way down" / "Way up" on the level shown."""
	var used: int = 0
	for row: int in _works.way_count():
		var top: int = _works.way_level(row)
		var at: Vector3 = _corner(_works.way_cell(row) + Vector2i.ONE, 0.0)
		if top == 0:
			used = _tag(used, "Entrance", at + Vector3(0.0, 1.2, 0.0), Layers.SURFACE_MARKS)
		if level >= 1 and (top == level or top + 1 == level):
			var words: String = "Way down" if top == level else "Way up to the surface" if top == 0 else "Way up"
			used = _tag(used, words, at + Vector3(0.0, _floors[level] / UNITS_PER_M + TAG_LIFT_M, 0.0), LAYER)
	if level >= 1 and not _ordered.is_empty():
		var first: Vector3 = _corner(Vector2i(_ordered[0], _ordered[1]) + Vector2i.ONE, _floors[level] / UNITS_PER_M + 0.6)
		@warning_ignore("integer_division") var waiting: int = _ordered.size() / 2
		used = _tag(used, WAITING % waiting, first, LAYER)
	for at: int in range(used, _tags.size()):
		_tags[at].visible = false


func _tag(used: int, words: String, at: Vector3, layer: int) -> int:
	"""Tag `used` (made when the pool is that short) shows `words` at `at` on `layer`; returns the next free one."""
	if used == _tags.size():
		var tag: Label3D = Label3D.new()
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.no_depth_test = true
		tag.font_size = TAG_PX
		tag.pixel_size = 0.01
		tag.outline_size = 8
		add_child(tag)
		_tags.append(tag)
	var label: Label3D = _tags[used]
	label.text = words
	label.layers = layer
	label.position = at
	label.visible = true
	return used + 1


func _corner(cell: Vector2i, y: float) -> Vector3:
	"""A cell corner in metres at height `y`."""
	return Vector3(_datum.x / UNITS_PER_M + cell.x, y, _datum.y / UNITS_PER_M + cell.y)


func tags() -> PackedStringArray:
	"""The names shown (checks)."""
	var out: PackedStringArray = PackedStringArray()
	for tag: Label3D in _tags:
		if tag.visible:
			out.append(tag.text)
	return out
