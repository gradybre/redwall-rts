extends Node3D
## Exact fixed-connector triangles, metre-scale UVs and a real hatch pivot. Presentation only.
## No collision permission, paid cut, movement mode or construction completion comes from this view.

const Geometry := preload("res://scripts/core/connector_geometry.gd")
const UNITS_PER_M: float = 1024.0

var _static: MeshInstance3D = null
var _hatch: MeshInstance3D = null
var _hinge: Node3D = null
var _hinge_axis: Vector3 = Vector3.ZERO
var _hinge_sign: int = 0
var _rotations: int = 0
var _container: Node3D = null


func configure(compiled: Geometry.Compiled, materials: Array[Material]) -> StringName:
	"""Atomically replace a preview after all content/material validation; refusal retains the prior view."""
	var code: StringName = _format_error(compiled, materials)
	if code != &"":
		return code
	var staged: Node3D = Node3D.new()
	var pivot: Vector3 = Vector3.ZERO
	if not compiled.hinge_xyz.is_empty():
		pivot = _position(compiled.hinge_xyz, 0)
	var fixed: ArrayMesh = _mesh(compiled, materials, false, Vector3.ZERO)
	var moving: ArrayMesh = _mesh(compiled, materials, true, pivot)
	var fixed_node: MeshInstance3D = _instance(fixed, &"Fixed", staged)
	var hinge: Node3D = Node3D.new()
	hinge.name = &"HatchHinge"
	hinge.position = pivot
	staged.add_child(hinge)
	var hatch_node: MeshInstance3D = _instance(moving, &"Hatch", hinge)
	_clear()
	_static = fixed_node
	_hatch = hatch_node
	_hinge = hinge
	_hinge_sign = compiled.hinge_open_sign
	_hinge_axis = (_position(compiled.hinge_xyz, 3) - pivot).normalized() if not compiled.hinge_xyz.is_empty() else Vector3.ZERO
	_rotations = compiled.definition.allowed_rotations
	_container = staged
	add_child(staged)
	transform = Transform3D.IDENTITY
	return &""


func set_fixed_placement(origin_u: Vector3i, quarter_turns: int) -> bool:
	"""Place the authored piece with exactly the same integer quarter-turn convention as RoomConnectors."""
	if _static == null or quarter_turns < 0 or quarter_turns > 3 or (_rotations & (1 << quarter_turns)) == 0:
		return false
	transform = Transform3D(Basis(Vector3.UP, -float(quarter_turns) * PI * 0.5), Vector3(origin_u) / UNITS_PER_M)
	return true


func set_hatch_fraction(fraction: float) -> bool:
	"""Animate only the presentation leaf; the compiler's full swing envelope never shrinks with this fraction."""
	if _hatch == null or _hatch.mesh == null or _hinge_axis == Vector3.ZERO \
			or not is_finite(fraction) or fraction < 0.0 or fraction > 1.0:
		return false
	_hinge.basis = Basis(_hinge_axis, float(_hinge_sign) * fraction * PI * 0.5)
	return true


func fixed_mesh() -> ArrayMesh:
	"""Read the presentation mesh for renderer verification, never authoritative geometry."""
	return _static.mesh as ArrayMesh if _static != null else null


func hatch_mesh() -> ArrayMesh:
	"""Read the pivot-relative leaf mesh; its transform is supplied separately."""
	return _hatch.mesh as ArrayMesh if _hatch != null else null


func hatch_transform() -> Transform3D:
	"""The leaf's current local transform, retained as a float presentation value only."""
	return _hinge.transform if _hinge != null else Transform3D.IDENTITY


static func _format_error(compiled: Geometry.Compiled, materials: Array[Material]) -> StringName:
	"""Guard public, mutable cold packets before allocating ArrayMesh or reading a partial triangle."""
	if compiled == null or compiled.definition == null or compiled.triangle_material.is_empty():
		return &"CONNECTOR_VIEW_UNBOUND"
	var count: int = compiled.triangle_material.size()
	if count > Geometry.MAX_TRIANGLES or compiled.triangle_xyz.size() != count * 9 \
			or compiled.triangle_part.size() != count or compiled.part_kind.size() > Geometry.MAX_PARTS:
		return &"CONNECTOR_VIEW_FORMAT"
	if materials.size() != compiled.material_period_u.size() or materials.is_empty() or materials.size() > Geometry.MAX_MATERIALS:
		return &"CONNECTOR_VIEW_MATERIAL"
	for at: int in materials.size():
		if not materials[at] is BaseMaterial3D or compiled.material_period_u[at] < 1 \
				or compiled.material_period_u[at] > Geometry.MAX_LOCAL_U:
			return &"CONNECTOR_VIEW_MATERIAL"
	for coordinate: int in compiled.triangle_xyz:
		if absi(coordinate) > Geometry.MAX_LOCAL_U:
			return &"CONNECTOR_VIEW_FORMAT"
	for at: int in count:
		if compiled.triangle_material[at] < 0 or compiled.triangle_material[at] >= materials.size() \
				or compiled.triangle_part[at] < 0 or compiled.triangle_part[at] >= compiled.part_kind.size():
			return &"CONNECTOR_VIEW_FORMAT"
		var a: Vector3 = _position(compiled.triangle_xyz, at * 9)
		var b: Vector3 = _position(compiled.triangle_xyz, at * 9 + 3)
		var c: Vector3 = _position(compiled.triangle_xyz, at * 9 + 6)
		if (b - a).cross(c - a).length_squared() == 0.0:
			return &"CONNECTOR_VIEW_DEGENERATE"
	return _hinge_error(compiled)


static func _hinge_error(compiled: Geometry.Compiled) -> StringName:
	"""The leaf cannot animate around a missing, zero-length or unbound hinge."""
	if compiled.hinge_xyz.is_empty():
		return &"" if not compiled.part_kind.has(Geometry.HATCH) else &"CONNECTOR_VIEW_HINGE"
	if compiled.hinge_xyz.size() != 6 or compiled.hinge_open_sign not in [-1, 1] \
			or _position(compiled.hinge_xyz, 0) == _position(compiled.hinge_xyz, 3):
		return &"CONNECTOR_VIEW_HINGE"
	return &""


static func _mesh(compiled: Geometry.Compiled, materials: Array[Material], moving: bool, pivot: Vector3) -> ArrayMesh:
	"""Batch by material: one fixed MeshInstance and at most one moving hatch, not one node per tread."""
	var mesh: ArrayMesh = ArrayMesh.new()
	for material: int in materials.size():
		var vertices: PackedVector3Array = PackedVector3Array()
		var normals: PackedVector3Array = PackedVector3Array()
		var uvs: PackedVector2Array = PackedVector2Array()
		for triangle: int in compiled.triangle_material.size():
			var hatch: bool = compiled.part_kind[compiled.triangle_part[triangle]] == Geometry.HATCH
			if hatch != moving or compiled.triangle_material[triangle] != material:
				continue
			_append_triangle(compiled, triangle, pivot, vertices, normals, uvs)
		if vertices.is_empty():
			continue
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _uv_material(materials[material] as BaseMaterial3D))
	return mesh if mesh.get_surface_count() > 0 else null


static func _append_triangle(compiled: Geometry.Compiled, triangle: int, pivot: Vector3,
		vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array) -> void:
	"""Use exact clipped positions; a unit face basis preserves physical texture scale on a slope too."""
	var a: Vector3 = _position(compiled.triangle_xyz, triangle * 9)
	var b: Vector3 = _position(compiled.triangle_xyz, triangle * 9 + 3)
	var c: Vector3 = _position(compiled.triangle_xyz, triangle * 9 + 6)
	var normal: Vector3 = (b - a).cross(c - a).normalized()
	var tangent: Vector3 = Vector3.RIGHT - normal * normal.x
	if tangent.length_squared() < 0.001:
		tangent = Vector3.FORWARD - normal * normal.z * -1.0
	tangent = tangent.normalized()
	var bitangent: Vector3 = normal.cross(tangent).normalized()
	var period_m: float = float(compiled.material_period_u[compiled.triangle_material[triangle]]) / UNITS_PER_M
	# Godot uses clockwise front faces: compiler cross products describe outward normals.
	for point: Vector3 in [a, c, b]:
		vertices.append(point - pivot)
		normals.append(normal)
		uvs.append(Vector2(point.dot(tangent), point.dot(bitangent)) / period_m)


static func _uv_material(source: BaseMaterial3D) -> BaseMaterial3D:
	"""Keep authored textures/response while preventing a second hidden UV fit or triplanar override."""
	var material: BaseMaterial3D = source.duplicate() as BaseMaterial3D
	material.uv1_scale = Vector3.ONE
	material.uv1_offset = Vector3.ZERO
	material.uv1_triplanar = false
	material.uv2_triplanar = false
	material.texture_repeat = true
	material.grow = false
	material.fixed_size = false
	material.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	material.next_pass = null
	material.cull_mode = BaseMaterial3D.CULL_BACK
	return material


static func _position(packed: PackedInt32Array, at: int) -> Vector3:
	"""Only the render boundary converts fixed units into floating-point metres."""
	return Vector3(packed[at], packed[at + 1], packed[at + 2]) / UNITS_PER_M


static func _instance(mesh: ArrayMesh, label: StringName, parent: Node3D) -> MeshInstance3D:
	"""Create the two bounded mesh nodes once, then update only transforms during display."""
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	parent.add_child(instance)
	return instance


func _clear() -> void:
	"""Release the previous preview hierarchy without leaving deferred orphan geometry."""
	if _container != null:
		_container.free()
	_container = null
	_static = null
	_hatch = null
	_hinge = null
