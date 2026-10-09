extends "res://test/framework/test_case.gd"
## Synthetic refusal/deformation fixtures. Actual source success is tested in the separately pinned native bake.

const Grip := preload("res://data/underground/mole-worker/mole_grip_source.gd")
var _skeletons: Array[Skeleton3D] = []


func after_each() -> void:
	"""The synthetic rig is an owned Node, never a retained object from the actual asset library."""
	for skeleton: Skeleton3D in _skeletons:
		skeleton.free()
	_skeletons.clear()


func _hand() -> Transform3D:
	"""Exact measured source float32 components, including its non-axis-aligned bind."""
	return Transform3D(Basis(Vector3(1.20199930667877, -0.223188877105713, 0.103133171796799),
		Vector3(-0.103135123848915, -0.924883127212524, -0.799502670764923),
		Vector3(0.223187878727913, 0.774615287780762, -0.924884080886841)),
		Vector3(0.458497911691666, 0.294640570878983, 0.339121133089066))


func _fit() -> Transform3D:
	"""The exact existing fitted prop transform is independent of the authored translation."""
	return Transform3D(Basis(Vector3(5.52569672316987e-16, 0.289199709892273, 1.264132087897e-08),
		Vector3(1.264132087897e-08, -1.264132087897e-08, 0.289199709892273),
		Vector3(0.289199709892273, 0.0, -1.264132087897e-08)),
		Vector3(-2.4629303041479e-09, -0.197996139526367, -0.0563452765345573))


func _rig() -> Dictionary:
	"""Only the exact hand slot is a source measurement; this rig is explicitly synthetic for refusal checks."""
	var skeleton: Skeleton3D = Skeleton3D.new()
	var skin: Skin = Skin.new()
	for bone: int in Grip.BINDS:
		skeleton.add_bone("RightHand" if bone == Grip.HAND else "FixtureBone%d" % bone)
		skin.add_bind(bone, _hand() if bone == Grip.HAND else Transform3D.IDENTITY)
	_skeletons.append(skeleton)
	return {"skeleton": skeleton, "skin": skin}


func _mesh() -> ArrayMesh:
	"""Six vertices expose the unchanged wrist, absent hand influence and blended boundary independently."""
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3(0.1, 0.08, 0), Vector3(0, 0.15, 0.1),
		Vector3(-0.1, 0.1, 0.1), Vector3(-0.1, 0.1, -0.1), Vector3(0.1, 0.02, 0.1)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	arrays[Mesh.ARRAY_TANGENT] = PackedFloat32Array([1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.UP, Vector2.ONE, Vector2.ZERO, Vector2.ONE])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 3, 4, 5])
	arrays[Mesh.ARRAY_BONES] = PackedInt32Array([19, 0, 0, 0, 19, 0, 0, 0, 19, 0, 0, 0, 0, 0, 0, 0, 19, 0, 0, 0, 19, 0, 0, 0])
	arrays[Mesh.ARRAY_WEIGHTS] = PackedFloat32Array([1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0.5, 0.5, 0, 0, 1, 0, 0, 0])
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, StandardMaterial3D.new())
	return mesh


func test_null_or_wrong_rig_has_no_partial_mesh_or_fit() -> void:
	var result: Grip.Result = Grip.create(null, null, null, Transform3D.IDENTITY)
	assert_equal(result.error, &"MOLE_GRIP_SOURCE_IDENTITY", "missing source refuses before decoding")
	assert_null(result.mesh, "no partial mesh")
	assert_equal(result.fit, Transform3D.IDENTITY, "no partial corrected fit")
	assert_equal(result.changed_vertices, 0, "no partial geometry count")
	var rig: Dictionary = _rig()
	rig.skeleton.set_bone_name(Grip.HAND, "LeftHand")
	assert_equal(Grip.source_refusal(_mesh(), rig.skin, rig.skeleton, _fit()), &"MOLE_GRIP_SOURCE_IDENTITY", "different hand name refuses")


func test_exact_native_transform_transcript_keeps_small_axis_residuals() -> void:
	assert_equal(Grip.transform_digest(_hand()), Grip.HAND_DIGEST, "measured hand transcript")
	assert_equal(Grip.transform_digest(_fit()), Grip.FIT_DIGEST, "measured fit transcript")
	var changed: Transform3D = _fit()
	changed.basis.x.x = 0.0
	assert_true(Grip.transform_digest(changed) != Grip.FIT_DIGEST, "idealizing a tiny coefficient changes source identity")
	changed.origin.x = INF
	assert_equal(Grip.transform_digest(changed), "", "nonfinite transform refuses")


func test_foreign_hand_mapping_or_pose_refuses_before_geometry() -> void:
	var rig: Dictionary = _rig()
	rig.skin.set_bind_bone(Grip.HAND, 0)
	assert_equal(Grip.source_refusal(_mesh(), rig.skin, rig.skeleton, _fit()), &"MOLE_GRIP_HAND_BIND", "foreign numerical map refuses")
	rig.skin.set_bind_name(Grip.HAND, "RightHand")
	rig.skin.set_bind_pose(Grip.HAND, Transform3D.IDENTITY)
	assert_equal(Grip.source_refusal(_mesh(), rig.skin, rig.skeleton, _fit()), &"MOLE_GRIP_HAND_BIND", "name cannot hide changed bind pose")


func test_nearby_fit_and_synthetic_body_do_not_inherit_actual_source_permission() -> void:
	var rig: Dictionary = _rig()
	var changed: Transform3D = _fit()
	changed.origin.x += 1.0 / 1024.0
	assert_equal(Grip.source_refusal(_mesh(), rig.skin, rig.skeleton, changed), &"MOLE_GRIP_SOURCE_FIT", "nearby socket still has another identity")
	var result: Grip.Result = Grip.create(_mesh(), rig.skin, rig.skeleton, _fit())
	assert_equal(result.error, &"MOLE_GRIP_SOURCE_GEOMETRY", "synthetic mesh is never the accepted mole")
	assert_null(result.mesh, "source mismatch produces no derived mesh")


func test_synthetic_derivative_preserves_original_and_unaffected_attributes() -> void:
	var original: ArrayMesh = _mesh()
	var before: Array = original.surface_get_arrays(0)
	var result: Grip.Result = Grip.Result.new()
	var derived: ArrayMesh = Grip._derive(original, Transform3D.IDENTITY, result)
	assert_not_null(derived, "bounded synthetic transform runs without claiming source qualification")
	assert_equal(result.changed_vertices, 3, "only distal hand-influenced vertices change")
	assert_equal(original.surface_get_arrays(0), before, "all original arrays remain unchanged")
	var after: Array = derived.surface_get_arrays(0)
	for slot: int in [Mesh.ARRAY_INDEX, Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS, Mesh.ARRAY_TEX_UV]:
		assert_equal(after[slot], before[slot], "indices, skin and UVs remain exact")
	for vertex: int in [0, 3, 5]:
		assert_equal(after[Mesh.ARRAY_VERTEX][vertex], before[Mesh.ARRAY_VERTEX][vertex], "wrist and unrelated body remain exact")
	assert_true(after[Mesh.ARRAY_VERTEX][1] != before[Mesh.ARRAY_VERTEX][1], "actual distal geometry changes")
	assert_true(derived.surface_get_material(0) == original.surface_get_material(0), "same actual material resource")


func test_derivative_is_deterministic_and_shading_stays_finite() -> void:
	var original: ArrayMesh = _mesh()
	var first: ArrayMesh = Grip._derive(original, Transform3D.IDENTITY, Grip.Result.new())
	var second: ArrayMesh = Grip._derive(original, Transform3D.IDENTITY, Grip.Result.new())
	assert_equal(first.surface_get_arrays(0), second.surface_get_arrays(0), "same source and recipe give identical decoded arrays")
	var arrays: Array = first.surface_get_arrays(0)
	for vertex: int in 6:
		var normal: Vector3 = arrays[Mesh.ARRAY_NORMAL][vertex]
		var tangent: Vector3 = Vector3(arrays[Mesh.ARRAY_TANGENT][vertex * 4], arrays[Mesh.ARRAY_TANGENT][vertex * 4 + 1], arrays[Mesh.ARRAY_TANGENT][vertex * 4 + 2])
		assert_true(normal.is_finite() and tangent.is_finite(), "normal and tangent remain finite")
		assert_less_than(absf(normal.length() - 1.0), 0.001, "normal remains unit length after native packing")
		assert_less_than(absf(normal.dot(tangent)), 0.001, "tangent remains orthogonal after native packing")


func test_nonfinite_or_missing_shading_inputs_refuse() -> void:
	assert_false(Grip._attributes_valid(1, PackedVector3Array(), PackedFloat32Array()), "missing arrays refuse")
	assert_false(Grip._attributes_valid(1, PackedVector3Array([Vector3.ZERO]), PackedFloat32Array([1, 0, 0, 1])), "zero normal refuses")
	assert_false(Grip._attributes_valid(1, PackedVector3Array([Vector3(INF, 0, 0)]), PackedFloat32Array([1, 0, 0, 1])), "nonfinite normal refuses")
	assert_false(Grip._attributes_valid(1, PackedVector3Array([Vector3.UP]), PackedFloat32Array([1, 0, 0, NAN])), "nonfinite tangent sign refuses")
	assert_true(Grip._attributes_valid(1, PackedVector3Array([Vector3.UP]), PackedFloat32Array([1, 0, 0, 1])), "finite complete input remains allowed")
