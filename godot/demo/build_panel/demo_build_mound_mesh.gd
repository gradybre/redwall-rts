extends RefCounted
## MESHES FOR THE MOUNDS' DRAWING (decision 2002). Two kinds, both presentation only:
##   A GRID   a heightfield over a rectangle of world metres, one height and one colour a lattice point, its normals
##            from the heights themselves; a quad whose four corners all lie below the ground is left out, so the
##            village's own ground shows there (`grid_mesh`).
##   PARTS    plain primitives -- boxes, cylinders, tori, discs, spheres -- each placed by a transform and gathered
##            by material into one mesh of one surface a material (`add_*`, then `commit`).
## The colour's alpha carries what a grid's surface is to build_mound.gdshader: TURF, FLOOR, HEAP or EARTH.

## build_mound.gdshader reads the colour's alpha: turf, a dug floor, or earth.
const TURF: float = 1.0
const FLOOR: float = 0.5
## Heaped earth's outside: the packed earth seen from every side (the wall texture's strata are for a cut).
const HEAP: float = 0.25
const EARTH: float = 0.0
## A ground-level lattice point is drawn this far under the ground, so the village's ground covers the seam.
const UNDER_M: float = -0.03

## Per material: the triangles gathered so far.
var _surfaces: Dictionary = {}


class Gathered extends RefCounted:
	## One material's triangles: vertices, normals and indices (kept here, not in an Array, which would hand out
	## copies of its packed arrays).
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var indices: PackedInt32Array = PackedInt32Array()
## Each primitive's arrays by its shape, made once (main thread: a rebuild allocates no primitive twice).
static var _shapes: Dictionary = {}


static func grid_mesh(origin: Vector2, step: float, columns: int, heights: PackedFloat32Array,
		colours: PackedColorArray, material: Material) -> ArrayMesh:
	"""A heightfield `columns` + 1 points wide from `origin` (world m, its north-west corner), `step` m apart, with
	`heights` and `colours` row by row (see the header); null when nothing stands above the ground."""
	return mesh_of(grid_arrays(origin, step, columns, heights, colours), material)


static func mesh_of(arrays: Array, material: Material) -> ArrayMesh:
	"""One surface's arrays as a mesh in `material` (main thread; null for no arrays)."""
	if arrays.is_empty():
		return null
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	return mesh


static func grid_arrays(origin: Vector2, step: float, columns: int, heights: PackedFloat32Array,
		colours: PackedColorArray) -> Array:
	"""`grid_mesh`'s surface arrays (a worker may make them); empty when nothing stands above the ground."""
	@warning_ignore("integer_division") var rows: int = heights.size() / (columns + 1) - 1
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	vertices.resize(heights.size())
	normals.resize(heights.size())
	for j: int in rows + 1:
		for i: int in columns + 1:
			var at: int = j * (columns + 1) + i
			vertices[at] = Vector3(origin.x + i * step, heights[at], origin.y + j * step)
			normals[at] = _normal(heights, columns, rows, i, j, step)
	var indices: PackedInt32Array = _grid_indices(heights, columns, rows)
	if indices.is_empty():
		return []
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_INDEX] = indices
	return arrays


static func _normal(heights: PackedFloat32Array, columns: int, rows: int, i: int, j: int, step: float) -> Vector3:
	"""The normal at lattice point (i, j) by central differences (one-sided at the edges)."""
	var row: int = columns + 1
	var left: float = heights[j * row + maxi(i - 1, 0)]
	var right: float = heights[j * row + mini(i + 1, columns)]
	var up: float = heights[maxi(j - 1, 0) * row + i]
	var down: float = heights[mini(j + 1, rows) * row + i]
	var span_x: float = step * float(mini(i + 1, columns) - maxi(i - 1, 0))
	var span_z: float = step * float(mini(j + 1, rows) - maxi(j - 1, 0))
	return Vector3(-(right - left) / span_x, 1.0, -(down - up) / span_z).normalized()


static func _grid_indices(heights: PackedFloat32Array, columns: int, rows: int) -> PackedInt32Array:
	"""Two triangles a quad (clockwise from above, as Godot faces them), but none where all four corners are under
	the ground."""
	var out: PackedInt32Array = PackedInt32Array()
	var row: int = columns + 1
	for j: int in rows:
		for i: int in columns:
			var a: int = j * row + i
			if heights[a] < 0.0 and heights[a + 1] < 0.0 and heights[a + row] < 0.0 and heights[a + row + 1] < 0.0:
				continue
			out.append_array(PackedInt32Array([a, a + 1, a + row, a + 1, a + row + 1, a + row]))
	return out


# --- parts -------------------------------------------------------------------------------------------------------------

func add_box(material: Material, size: Vector3, at: Transform3D) -> void:
	"""A box `size` m, centred on `at` (a unit box scaled: its faces' normals stay true)."""
	if not _shapes.has(&"box"):
		_shapes[&"box"] = BoxMesh.new().get_mesh_arrays()
	_add_arrays(material, _shapes[&"box"], at * Transform3D(Basis.from_scale(size), Vector3.ZERO))


func add_cylinder(material: Material, top: float, bottom: float, height: float, at: Transform3D, sides: int = 12) -> void:
	"""A cylinder (or cone) `height` m along its local y, centred on `at`."""
	var key: String = "cylinder %.3f %.3f %d" % [top / maxf(bottom, 0.001), bottom, sides]
	if not _shapes.has(key):
		var shape: CylinderMesh = CylinderMesh.new()
		shape.top_radius = top
		shape.bottom_radius = bottom
		shape.height = 1.0
		shape.radial_segments = sides
		shape.rings = 1
		_shapes[key] = shape.get_mesh_arrays()
	_add_arrays(material, _shapes[key], at * Transform3D(Basis.from_scale(Vector3(1.0, height, 1.0)), Vector3.ZERO))


func add_sphere(material: Material, radius: float, at: Transform3D, segments: int = 10) -> void:
	"""A sphere `radius` m, centred on `at` (scale `at` to squash it)."""
	var key: String = "sphere %d" % segments
	if not _shapes.has(key):
		var shape: SphereMesh = SphereMesh.new()
		shape.radius = 1.0
		shape.height = 2.0
		shape.radial_segments = segments
		@warning_ignore("integer_division") var rings: int = maxi(segments / 2, 4)
		shape.rings = rings
		_shapes[key] = shape.get_mesh_arrays()
	_add_arrays(material, _shapes[key], at * Transform3D(Basis.from_scale(Vector3.ONE * radius), Vector3.ZERO))


func add_ring(material: Material, inner: float, outer: float, at: Transform3D, rings: int = 28) -> void:
	"""A torus lying in its local x/y plane (facing local +z), its tube between `inner` and `outer` m from its middle."""
	var key: String = "torus %.3f %.3f %d" % [inner, outer, rings]
	if not _shapes.has(key):
		var torus: TorusMesh = TorusMesh.new()
		torus.inner_radius = inner
		torus.outer_radius = outer
		torus.rings = rings
		torus.ring_segments = 8
		_shapes[key] = torus.get_mesh_arrays()
	_add_arrays(material, _shapes[key], at * Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3.ZERO))


func add_disc(material: Material, radius: float, at: Transform3D, sides: int = 28) -> void:
	"""A flat disc `radius` m in its local x/y plane, facing local +z (both faces drawn by the material)."""
	var middle: Vector3 = at.origin
	var normal: Vector3 = at.basis.z.normalized()
	for k: int in sides:
		var a: Vector3 = at * Vector3(cos(TAU * k / sides) * radius, sin(TAU * k / sides) * radius, 0.0)
		var b: Vector3 = at * Vector3(cos(TAU * (k + 1) / sides) * radius, sin(TAU * (k + 1) / sides) * radius, 0.0)
		_triangle(material, middle, b, a, normal)


func add_arch(material: Material, radius: float, thick: float, at: Transform3D, segments: int = 16) -> void:
	"""A half-ring of boxes, `radius` m round its middle, rising over local +y in its local x/y plane."""
	for k: int in segments:
		var angle: float = PI * (k + 0.5) / segments
		var place: Transform3D = at * Transform3D(Basis(Vector3.BACK, angle - PI / 2.0),
			Vector3(cos(angle) * radius, sin(angle) * radius, 0.0))
		add_box(material, Vector3(thick, PI * radius / segments + 0.02, thick), place)


func _add_arrays(material: Material, arrays: Array, at: Transform3D) -> void:
	"""A primitive's arrays placed by `at`, gathered under `material`."""
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var surface: Gathered = _surface(material)
	var base: int = surface.vertices.size()
	for k: int in points.size():
		surface.vertices.append(at * points[k])
		surface.normals.append((at.basis * normals[k]).normalized())
	for index: int in indices:
		surface.indices.append(base + index)


func _triangle(material: Material, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	"""One triangle under `material`."""
	var surface: Gathered = _surface(material)
	var base: int = surface.vertices.size()
	surface.vertices.append_array(PackedVector3Array([a, b, c]))
	surface.normals.append_array(PackedVector3Array([normal, normal, normal]))
	surface.indices.append_array(PackedInt32Array([base, base + 1, base + 2]))


func _surface(material: Material) -> Gathered:
	"""`material`'s gathered triangles, made on first use."""
	if not _surfaces.has(material):
		_surfaces[material] = Gathered.new()
	return _surfaces[material]


func count() -> int:
	"""Triangles gathered (checks)."""
	var total: int = 0
	for surface: Gathered in _surfaces.values():
		@warning_ignore("integer_division") var triangles: int = surface.indices.size() / 3
		total += triangles
	return total


func commit() -> ArrayMesh:
	"""Everything gathered as one mesh, a surface a material (null when nothing was gathered)."""
	if _surfaces.is_empty():
		return null
	var mesh: ArrayMesh = ArrayMesh.new()
	for material: Material in _surfaces:
		var surface: Gathered = _surfaces[material]
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = surface.vertices
		arrays[Mesh.ARRAY_NORMAL] = surface.normals
		arrays[Mesh.ARRAY_INDEX] = surface.indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)
	return mesh
