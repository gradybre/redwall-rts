extends RefCounted
## Source-bound authored hand geometry. Presentation only; no worker, contact or profile permission.
## Build once per immutable shared mole/pick archetype; never derive a new mesh on an actor tick.

const Content := preload("res://demo/cast/underground_actor_content.gd")
const SOURCE_DIGEST: String = "a938d479014ebd3a431a118a7b1c9f7aa0b522d0a33a5c5d281e58e1e2f497c1"
const DERIVED_DIGEST: String = "29f8d3218fddfaa6f2369c1c1c7dfd9b0a429b3df5cbefa38c6bf6ab9364fe14"
const HAND_DIGEST: String = "ba1835b272511bf3ef35b9586aaf6b350fc68081e4c19969420760ef4747813e"
const FIT_DIGEST: String = "3d61abccd6c4e44a312a747cb9bddd93c4fe43d253168a4d9764706a07ce9aed"
const VERTICES: int = 17172
const BINDS: int = 24
const HAND: int = 19
const CHANGED_VERTICES: int = 845
const OFFSET_U: Vector3i = Vector3i(-40, 80, 5)


class Result extends RefCounted:
	var error: StringName = &"MOLE_GRIP_UNBUILT"
	var mesh: ArrayMesh = null
	var fit: Transform3D = Transform3D.IDENTITY
	var changed_vertices: int = 0


static func create(mesh: ArrayMesh, skin: Skin, skeleton: Skeleton3D, fit: Transform3D) -> Result:
	"""No alternative body, rig, bind pose or tool fit silently inherits this authored hand correction."""
	var result: Result = Result.new()
	result.error = source_refusal(mesh, skin, skeleton, fit)
	if result.error != &"":
		return result
	var derived: ArrayMesh = _derive(mesh, skin.get_bind_pose(HAND), result)
	if derived == null or result.changed_vertices != CHANGED_VERTICES \
			or Content.mesh_fingerprint(derived, BINDS, VERTICES, 1).hex_encode() != DERIVED_DIGEST:
		result.error = &"MOLE_GRIP_DERIVATIVE_DRIFT"
		result.changed_vertices = 0
		return result
	if Content.mesh_fingerprint(mesh, BINDS, VERTICES, 1).hex_encode() != SOURCE_DIGEST:
		result.error = &"MOLE_GRIP_SOURCE_MUTATED"
		result.changed_vertices = 0
		return result
	result.mesh = derived
	result.fit = Transform3D(Basis.IDENTITY, Vector3(OFFSET_U) / 1024.0) * fit
	result.error = &""
	return result


static func source_refusal(mesh: ArrayMesh, skin: Skin, skeleton: Skeleton3D, fit: Transform3D) -> StringName:
	"""Counts are finite before native array decoding; exact imported geometry and hand transform are required."""
	if mesh == null or skin == null or skeleton == null or skin.get_bind_count() != BINDS \
			or skeleton.get_bone_count() != BINDS or skeleton.find_bone("RightHand") != HAND:
		return &"MOLE_GRIP_SOURCE_IDENTITY"
	var name: StringName = skin.get_bind_name(HAND)
	var bone: int = skeleton.find_bone(name) if name != &"" else skin.get_bind_bone(HAND)
	if bone != HAND or transform_digest(skin.get_bind_pose(HAND)) != HAND_DIGEST:
		return &"MOLE_GRIP_HAND_BIND"
	if transform_digest(fit) != FIT_DIGEST:
		return &"MOLE_GRIP_SOURCE_FIT"
	if Content.mesh_fingerprint(mesh, BINDS, VERTICES, 1).hex_encode() != SOURCE_DIGEST:
		return &"MOLE_GRIP_SOURCE_GEOMETRY"
	return &""


static func transform_digest(value: Transform3D) -> String:
	"""Match the actual twelve little-endian float32 components, including the source's small axis residuals."""
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(48)
	for column: int in 4:
		var vector: Vector3 = value.basis[column] if column < 3 else value.origin
		if not vector.is_finite():
			return ""
		for axis: int in 3:
			bytes.encode_float((column * 3 + axis) * 4, vector[axis])
	var hashing: HashingContext = HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().hex_encode()


static func _derive(mesh: ArrayMesh, hand: Transform3D, result: Result) -> ArrayMesh:
	"""Duplicate changed attributes only; original indices, skin, UVs and material are shared read-only."""
	var arrays: Array = mesh.surface_get_arrays(0).duplicate()
	var points: PackedVector3Array = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate()
	var normals: PackedVector3Array = (arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array).duplicate()
	var tangents: PackedFloat32Array = (arrays[Mesh.ARRAY_TANGENT] as PackedFloat32Array).duplicate()
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	@warning_ignore("integer_division") var stride: int = weights.size() / points.size()
	if not _attributes_valid(points.size(), normals, tangents):
		return null
	for vertex: int in points.size():
		var share: float = _hand_share(vertex, stride, bones, weights)
		if share <= 0.0 or (hand * points[vertex]).y <= 0.025:
			continue
		_deform_vertex(vertex, hand, share, points, normals, tangents)
		result.changed_vertices += 1
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents
	var derived: ArrayMesh = ArrayMesh.new()
	derived.add_surface_from_arrays(mesh.surface_get_primitive_type(0), arrays)
	derived.surface_set_material(0, mesh.surface_get_material(0))
	return derived


static func _attributes_valid(count: int, normals: PackedVector3Array, tangents: PackedFloat32Array) -> bool:
	"""Refuse nonfinite shading inputs rather than producing a hidden or corrupt authored variant."""
	if normals.size() != count or tangents.size() != count * 4:
		return false
	for vertex: int in count:
		if not normals[vertex].is_finite() or normals[vertex].length_squared() <= 0.0:
			return false
		var tangent: Vector3 = Vector3(tangents[vertex * 4], tangents[vertex * 4 + 1], tangents[vertex * 4 + 2])
		if not tangent.is_finite() or tangent.length_squared() <= 0.0 \
				or not is_finite(tangents[vertex * 4 + 3]):
			return false
	return true


static func _hand_share(vertex: int, stride: int, bones: PackedInt32Array, weights: PackedFloat32Array) -> float:
	"""The continuous original hand weight controls the unchanged wrist boundary."""
	var share: float = 0.0
	for influence: int in stride:
		if bones[vertex * stride + influence] == HAND:
			share += weights[vertex * stride + influence]
	return clampf(share, 0.0, 1.0)


static func _deform_vertex(vertex: int, hand: Transform3D, share: float, points: PackedVector3Array,
		normals: PackedVector3Array, tangents: PackedFloat32Array) -> void:
	"""Authored fixed geometry, with analytic normal/tangent transforms and no change to pose or skin weights."""
	var point: Vector3 = hand * points[vertex]
	var center: Vector3 = Vector3(OFFSET_U) / 1024.0
	var t: float = clampf((point.y - 0.025) / 0.105, 0.0, 1.0)
	var factor: float = t * t * (3.0 - 2.0 * t) * share
	var derivative: float = 6.0 * t * (1.0 - t) / 0.105 * share
	var narrow: float = 1.0 - 0.7 * factor
	var shorten: float = 1.0 - 0.15 * factor
	var jacobian: Basis = Basis(Vector3(narrow, 0, 0),
		Vector3(-(point.x - center.x) * 0.7 * derivative, shorten - (point.y - 0.025) * 0.15 * derivative,
			-(point.z - center.z) * 0.7 * derivative), Vector3(0, 0, narrow))
	point = Vector3(center.x + (point.x - center.x) * narrow,
		0.025 + (point.y - 0.025) * shorten, center.z + (point.z - center.z) * narrow)
	points[vertex] = hand.affine_inverse() * point
	var transform: Basis = hand.basis.inverse() * jacobian * hand.basis
	normals[vertex] = (transform.inverse().transposed() * normals[vertex]).normalized()
	var tangent: Vector3 = transform * Vector3(tangents[vertex * 4], tangents[vertex * 4 + 1], tangents[vertex * 4 + 2])
	tangent = (tangent - normals[vertex] * tangent.dot(normals[vertex])).normalized()
	tangents[vertex * 4] = tangent.x
	tangents[vertex * 4 + 1] = tangent.y
	tangents[vertex * 4 + 2] = tangent.z
