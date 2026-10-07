extends RefCounted
## ADR 1216: the curled pick paw, successor to mole_grip_source.gd's closed paw, for pick-holding sources only.
## Authored in contact-qualification/author_curled_paw.py and approved by Brendan; every constant below is that
## author's recorded derivation (curled-paw-v1/paw.json). It starts from the same original mesh and the same rig,
## thins the finger thickness with the accepted closing's own profile, and curls each finger cross-section about the
## pick shaft, which runs across the paw on the palm. The pick is held by the lateral-2 fit.

const Content := preload("res://demo/cast/underground_actor_content.gd")
const Accepted := preload("res://data/underground/mole-worker/mole_grip_source.gd")
const DERIVED_DIGEST: String = "2a8517bb448a6e6f0a4136ffad314357559b6c8b5dae05d5779511eb03d003af"
const CHANGED_VERTICES: int = 845
const START_M: float = 0.025
const SPAN_M: float = 0.105
const NARROW: float = 0.7
const MID_Z_M: float = -0.025571491946120177
const AXIS_Y_M: float = 0.078125
const AXIS_Z_M: float = 0.07025626879936334
const RHO_M: float = 0.050153983221491935
const FIT_SCALE: float = 0.28919971622107926
const FIT_ORIGIN_M: Vector3 = Vector3(-0.12510302385249344, 0.078125, 0.1266015408994742)


class Result extends RefCounted:
	var error: StringName = &"MOLE_CURL_UNBUILT"
	var mesh: ArrayMesh = null
	var fit: Transform3D = Transform3D.IDENTITY
	var changed_vertices: int = 0


static func create(mesh: ArrayMesh, skin: Skin, skeleton: Skeleton3D, fit: Transform3D) -> Result:
	"""Only the accepted original body, hand bind and source pick fit may be curled; anything else refuses."""
	var result: Result = Result.new()
	var code: StringName = Accepted.source_refusal(mesh, skin, skeleton, fit)
	if code != &"":
		result.error = code
		return result
	var derived: ArrayMesh = derive(mesh, skin.get_bind_pose(Accepted.HAND), result)
	if derived == null or result.changed_vertices != CHANGED_VERTICES:
		result.error = &"MOLE_CURL_DERIVATIVE_DRIFT"
		result.changed_vertices = 0
		return result
	if Content.mesh_fingerprint(derived, Accepted.BINDS, Accepted.VERTICES, 1).hex_encode() != DERIVED_DIGEST:
		result.error = &"MOLE_CURL_DERIVATIVE_DRIFT"
		result.changed_vertices = 0
		return result
	result.mesh = derived
	result.fit = held_fit()
	result.error = &""
	return result


static func held_fit() -> Transform3D:
	"""The lateral-2 hand-local pick transform: the shaft across the paw (hand X) on the palm, head along hand +Y."""
	var basis: Basis = Basis(Vector3(FIT_SCALE, 0, 0), Vector3(0, 0, -FIT_SCALE), Vector3(0, FIT_SCALE, 0))
	return Transform3D(basis, FIT_ORIGIN_M)


static func derive(mesh: ArrayMesh, hand: Transform3D, result: Result) -> ArrayMesh:
	"""Duplicate the changed attributes only; indices, skin, UVs and material are shared read-only."""
	var arrays: Array = mesh.surface_get_arrays(0).duplicate()
	var points: PackedVector3Array = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate()
	var normals: PackedVector3Array = (arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array).duplicate()
	var tangents: PackedFloat32Array = (arrays[Mesh.ARRAY_TANGENT] as PackedFloat32Array).duplicate()
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	@warning_ignore("integer_division") var stride: int = weights.size() / points.size()
	if normals.size() != points.size() or tangents.size() != points.size() * 4:
		return null
	for vertex: int in points.size():
		var share: float = _hand_share(vertex, stride, bones, weights)
		if share <= 0.0 or (hand * points[vertex]).y <= START_M:
			continue
		_curl_vertex(vertex, hand, share, points, normals, tangents)
		result.changed_vertices += 1
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents
	var derived: ArrayMesh = ArrayMesh.new()
	derived.add_surface_from_arrays(mesh.surface_get_primitive_type(0), arrays)
	derived.surface_set_material(0, mesh.surface_get_material(0))
	return derived


static func _hand_share(vertex: int, stride: int, bones: PackedInt32Array, weights: PackedFloat32Array) -> float:
	"""The continuous original hand weight, as in the accepted derivative."""
	var share: float = 0.0
	for influence: int in stride:
		if bones[vertex * stride + influence] == Accepted.HAND:
			share += weights[vertex * stride + influence]
	return clampf(share, 0.0, 1.0)


static func local_curl(point: Vector3, share: float) -> PackedFloat64Array:
	"""Hand-local position and its Jacobian rows: [x, y, z, dy/dy, dy/dz, dz/dy, dz/dz] (x is unchanged)."""
	var t: float = clampf((point.y - START_M) / SPAN_M, 0.0, 1.0)
	var factor: float = t * t * (3.0 - 2.0 * t) * share
	var slope: float = 6.0 * t * (1.0 - t) / SPAN_M * share if t > 0.0 and t < 1.0 else 0.0
	var z1: float = MID_Z_M + (point.z - MID_Z_M) * (1.0 - NARROW * factor)
	var dz1_dy: float = -(point.z - MID_Z_M) * NARROW * slope
	var dz1_dz: float = 1.0 - NARROW * factor
	var out: PackedFloat64Array = PackedFloat64Array([point.x, point.y, z1, 1.0, 0.0, dz1_dy, dz1_dz])
	if point.y <= AXIS_Y_M:
		return out
	var angle: float = (point.y - AXIS_Y_M) / RHO_M
	var radial: float = AXIS_Z_M - z1
	var bent_y: float = AXIS_Y_M + radial * sin(angle)
	var bent_z: float = AXIS_Z_M - radial * cos(angle)
	var by_dy: float = -dz1_dy * sin(angle) + radial * cos(angle) / RHO_M
	var bz_dy: float = dz1_dy * cos(angle) + radial * sin(angle) / RHO_M
	out[1] = (1.0 - share) * point.y + share * bent_y
	out[2] = (1.0 - share) * z1 + share * bent_z
	out[3] = (1.0 - share) + share * by_dy
	out[4] = share * (-dz1_dz * sin(angle))
	out[5] = (1.0 - share) * dz1_dy + share * bz_dy
	out[6] = (1.0 - share) * dz1_dz + share * dz1_dz * cos(angle)
	return out


static func _curl_vertex(vertex: int, hand: Transform3D, share: float, points: PackedVector3Array,
		normals: PackedVector3Array, tangents: PackedFloat32Array) -> void:
	"""Fixed authored geometry with analytic normals and tangents; pose and skin weights are untouched."""
	var curled: PackedFloat64Array = local_curl(hand * points[vertex], share)
	points[vertex] = hand.affine_inverse() * Vector3(curled[0], curled[1], curled[2])
	var jacobian: Basis = Basis(Vector3(1, 0, 0), Vector3(0, curled[3], curled[5]), Vector3(0, curled[4], curled[6]))
	var transform: Basis = hand.basis.inverse() * jacobian * hand.basis
	normals[vertex] = (transform.inverse().transposed() * normals[vertex]).normalized()
	var tangent: Vector3 = transform * Vector3(tangents[vertex * 4], tangents[vertex * 4 + 1], tangents[vertex * 4 + 2])
	tangent = (tangent - normals[vertex] * tangent.dot(normals[vertex])).normalized()
	tangents[vertex * 4] = tangent.x
	tangents[vertex * 4 + 1] = tangent.y
	tangents[vertex * 4 + 2] = tangent.z
