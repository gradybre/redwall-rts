extends RefCounted
## The carved ground and the bank skirt. Decision 0196 (live demo), water foundation. Presentation.
##
## CARVING. demo_world.gd's ground is one flat PlaneMesh whose shader samples everything in world
## XZ (demo_ground.gdshader: `world_xz` from MODEL_MATRIX * VERTEX), so ANY mesh can wear its
## material. `carve_ground()` swaps the Ground node's mesh for the same 400 m plane built on the
## water grid, with every vertex at `WaterMap.ground_height_at` -- banks falling to the waterline
## and the bed below it -- keeping the node, its name (others find it by name) and its
## material. Flat vertices are exactly y = 0, so the village is untouched.
##
## THE BANK SKIRT is a thin film over the carved bank and bed in its own material: damp mud at the
## waterline fading into the grass at the bank top, and a darker bed under the water. It sits a
## couple of centimetres above the ground and never casts a shadow.

const Rules := preload("res://demo/water/water_rules.gd")
const WaterGridScript := preload("res://demo/water/water_grid.gd")
const WaterMapScript := preload("res://demo/water/water_map.gd")

## The skirt floats this far above the carved ground (m), clear of depth fighting.
const SKIRT_LIFT_M: float = 0.02


static func carve_ground(ground: MeshInstance3D, grid: WaterGridScript) -> void:
	"""Rebuild the ground mesh on `grid`, carved, wearing the flat plane's own material."""
	var material: Material = ground.mesh.surface_get_material(0)
	if material == null and ground.mesh is PrimitiveMesh:
		material = (ground.mesh as PrimitiveMesh).material
	var tangent_w: float = _plane_tangent_w()
	var arrays: Array = _surface_arrays(grid, tangent_w, 0.0)
	arrays[Mesh.ARRAY_INDEX] = _cells(grid, func(_k: int) -> bool: return true)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	ground.mesh = mesh


static func make_skirt(grid: WaterGridScript, bank_run_u: int, material: Material) -> MeshInstance3D:
	"""The bank-and-bed film: every cell touching the bank or the water, lifted SKIRT_LIFT_M, with
	COLOR.r its wetness (0 at the bank top, 1 at the waterline and below) and COLOR.g its depth."""
	var arrays: Array = _surface_arrays(grid, _plane_tangent_w(), SKIRT_LIFT_M)
	var colours := PackedColorArray()
	colours.resize(grid.margin_u.size())
	for k: int in grid.margin_u.size():
		var wet: float = clampf(float(grid.margin_u[k] + bank_run_u) / float(bank_run_u), 0.0, 1.0)
		colours[k] = Color(wet, clampf(Rules.to_m(grid.depth_u[k]) / 2.0, 0.0, 1.0), 0.0, 1.0)
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_INDEX] = _cells(grid, func(k: int) -> bool: return grid.margin_u[k] > -bank_run_u)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	var node := MeshInstance3D.new()
	node.name = "WaterBank"
	node.mesh = mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


static func _plane_tangent_w() -> float:
	"""The binormal sign a PlaneMesh uses, so the ground shader's normal map reads the same way."""
	var plane := PlaneMesh.new()
	var tangents: PackedFloat32Array = plane.get_mesh_arrays()[Mesh.ARRAY_TANGENT]
	return tangents[3]


static func _surface_arrays(grid: WaterGridScript, tangent_w: float, lift_m: float) -> Array:
	"""Vertices at the ground height (+ `lift_m`), with height-field normals and tangents."""
	var count: int = grid.xs.size() * grid.zs.size()
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var tangents := PackedFloat32Array()
	vertices.resize(count)
	normals.resize(count)
	tangents.resize(count * 4)
	for j: int in grid.zs.size():
		for i: int in grid.xs.size():
			var k: int = grid.index(i, j)
			vertices[k] = Vector3(grid.xs[i], Rules.to_m(grid.ground_u[k]) + lift_m, grid.zs[j])
			var slope: Vector2 = _slope(grid, i, j)
			normals[k] = Vector3(-slope.x, 1.0, -slope.y).normalized()
			var tangent := Vector3(1.0, slope.x, 0.0).normalized()
			tangents[k * 4] = tangent.x
			tangents[k * 4 + 1] = tangent.y
			tangents[k * 4 + 2] = tangent.z
			tangents[k * 4 + 3] = tangent_w
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents
	return arrays


static func _slope(grid: WaterGridScript, i: int, j: int) -> Vector2:
	"""(dh/dx, dh/dz) at vertex (i, j) by central differences on the non-uniform grid."""
	var i0: int = maxi(i - 1, 0)
	var i1: int = mini(i + 1, grid.xs.size() - 1)
	var j0: int = maxi(j - 1, 0)
	var j1: int = mini(j + 1, grid.zs.size() - 1)
	var dhdx: float = Rules.to_m(grid.ground_u[grid.index(i1, j)] - grid.ground_u[grid.index(i0, j)]) \
		/ maxf(grid.xs[i1] - grid.xs[i0], 0.001)
	var dhdz: float = Rules.to_m(grid.ground_u[grid.index(i, j1)] - grid.ground_u[grid.index(i, j0)]) \
		/ maxf(grid.zs[j1] - grid.zs[j0], 0.001)
	return Vector2(dhdx, dhdz)


static func _cells(grid: WaterGridScript, keep: Callable) -> PackedInt32Array:
	"""Two triangles per grid cell with any corner `keep(k)` accepts, wound like PlaneMesh's."""
	var out := PackedInt32Array()
	var nx: int = grid.xs.size()
	for j: int in grid.zs.size() - 1:
		for i: int in nx - 1:
			var a: int = grid.index(i, j)
			var b: int = a + 1
			var c: int = a + nx
			var d: int = c + 1
			if not (keep.call(a) or keep.call(b) or keep.call(c) or keep.call(d)):
				continue
			out.append(d)
			out.append(c)
			out.append(b)
			out.append(c)
			out.append(a)
			out.append(b)
	return out
