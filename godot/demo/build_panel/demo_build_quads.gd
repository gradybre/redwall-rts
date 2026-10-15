extends RefCounted
## QUADS FOR ONE MESH SURFACE (decision 1913: the proof of concept's earth, pits and ways down). A growable list: each
## quad is wound so its front faces the normal it is given (Godot's front faces are clockwise), with metre UVs taken
## from the face's own plane (as modular_world_view.gd's sections are), a normal and a colour per corner. Built only
## when what it draws changed, never per frame. Presentation only.

var vertices: PackedVector3Array = PackedVector3Array()
var normals: PackedVector3Array = PackedVector3Array()
var uvs: PackedVector2Array = PackedVector2Array()
var colors: PackedColorArray = PackedColorArray()
var indices: PackedInt32Array = PackedInt32Array()


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, colour: Color) -> void:
	"""One quad around the loop a-b-c-d (convex), its front facing `normal`, in one colour."""
	shaded(a, b, c, d, normal, PackedColorArray([colour, colour, colour, colour]))


func shaded(a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, corners: PackedColorArray) -> void:
	"""One quad around a-b-c-d, its front facing `normal`, with `corners[k]` the colour at its k-th point."""
	var start: int = vertices.size()
	var flip: bool = (c - a).cross(b - a).dot(normal) < 0.0
	var points: PackedVector3Array = PackedVector3Array([a, d, c, b]) if flip else PackedVector3Array([a, b, c, d])
	var order: PackedInt32Array = PackedInt32Array([0, 3, 2, 1]) if flip else PackedInt32Array([0, 1, 2, 3])
	for k: int in 4:
		vertices.append(points[k])
		normals.append(normal)
		uvs.append(uv_of(points[k], normal))
		colors.append(corners[order[k]])
	for k: int in [0, 1, 2, 0, 2, 3]:
		indices.append(start + k)


static func uv_of(point: Vector3, normal: Vector3) -> Vector2:
	"""Metre UVs in the face's own plane: x/z on a floor, along/up on a wall."""
	if absf(normal.y) >= 0.5:
		return Vector2(point.x, point.z)
	return Vector2(point.z if absf(normal.x) > absf(normal.z) else point.x, point.y)


func count() -> int:
	"""Quads added."""
	@warning_ignore("integer_division") var quads: int = indices.size() / 6
	return quads


func commit(mesh: ArrayMesh, material: Material) -> void:
	"""Add the quads to `mesh` as one surface in `material` (nothing when empty)."""
	if indices.is_empty():
		return
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(mesh.get_surface_count() - 1, material)
