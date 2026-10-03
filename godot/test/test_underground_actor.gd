extends "res://test/framework/test_case.gd"
## Synthetic affine fixtures test the representation, never qualify a cast or connector.

const Actor := preload("res://demo/cast/underground_actor.gd")
const HASH: String = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"


func _attach_native(actor: Actor) -> void:
	"""The real MeshInstance ENTER_TREE must happen before its manual native palette is attached."""
	if DisplayServer.get_name() != "headless":
		(Engine.get_main_loop() as SceneTree).root.add_child(actor)


func _matrix(transform: Transform3D) -> PackedFloat32Array:
	"""Explicit column order matches the renderer adapter and binary source format."""
	var values: PackedFloat32Array = PackedFloat32Array()
	for column: Vector3 in [transform.basis.x, transform.basis.y, transform.basis.z, transform.origin]:
		values.append_array([column.x, column.y, column.z])
	return values


func _palette(transforms: Array[Transform3D], binds: PackedInt32Array = PackedInt32Array([1])) -> Actor.Palette:
	"""One small source per test, with no relationship to authored production geometry."""
	var values: PackedFloat32Array = PackedFloat32Array()
	for transform: Transform3D in transforms:
		values.append_array(_matrix(transform))
	var palette: Actor.Palette = Actor.Palette.new()
	assert_equal(palette.configure(HASH, transforms.size(), binds, values), &"", "fixture accepted")
	return palette


func _scratch(palette: Actor.Palette) -> PackedFloat32Array:
	"""The caller allocates one frame once and reuses it for all explicit updates."""
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(palette.scratch_count())
	out.fill(9.0)
	return out


func test_palette_copies_source_and_exposes_only_counts_and_digest() -> void:
	"""Mutation of input packed arrays cannot mutate a retained physical presentation source."""
	var values: PackedFloat32Array = _matrix(Transform3D.IDENTITY)
	var binds: PackedInt32Array = PackedInt32Array([1])
	var palette: Actor.Palette = Actor.Palette.new()
	assert_equal(palette.configure(HASH, 1, binds, values), &"", "configure")
	values.fill(0.0)
	binds[0] = 0
	var out: PackedFloat32Array = _scratch(palette)
	assert_equal(palette.sample_into(PackedInt32Array([0, 0, 0, 0, 0, 0, 0]), out), &"", "sample")
	assert_equal(Actor.matrix_at(out, 0), Transform3D.IDENTITY, "source not aliased")
	assert_equal(palette.source_digest(), HASH, "source identity")
	assert_equal(palette.frame_count(), 1, "exact frame count")
	assert_equal(palette.part_count(), 1, "exact parts")
	assert_equal(palette.bind_count(0), 1, "exact original binds")
	assert_equal(palette.bind_count(1), -1, "invalid part refused")
	assert_equal(palette.part_offset(-1), -1, "invalid offset refused")
	assert_equal(palette.configure(HASH, 1, binds, values), &"UNDERGROUND_PALETTE_ALREADY_CONFIGURED", "immutable")


func test_invalid_source_capacity_and_components_leave_palette_unbound() -> void:
	"""Corrupt content refuses before a palette is published or a native object is allocated."""
	var palette: Actor.Palette = Actor.Palette.new()
	var values: PackedFloat32Array = _matrix(Transform3D.IDENTITY)
	for source: String in ["", "g".repeat(64), HASH.to_upper()]:
		assert_equal(palette.configure(source, 1, PackedInt32Array([1]), values), &"UNDERGROUND_PALETTE_SOURCE", "source")
	for frames: int in [0, Actor.MAX_FRAMES + 1]:
		assert_equal(palette.configure(HASH, frames, PackedInt32Array([1]), values), &"UNDERGROUND_PALETTE_CAPACITY", "frames")
	for binds: PackedInt32Array in [PackedInt32Array(), PackedInt32Array([-1]), PackedInt32Array([65])]:
		assert_equal(palette.configure(HASH, 1, binds, values), &"UNDERGROUND_PALETTE_CAPACITY", "binds")
	assert_equal(palette.configure(HASH, 2, PackedInt32Array([1]), values), &"UNDERGROUND_PALETTE_FORMAT", "missing frame")
	for invalid: float in [NAN, INF, -INF, 1025.0]:
		values[0] = invalid
		assert_equal(palette.configure(HASH, 1, PackedInt32Array([1]), values), &"UNDERGROUND_PALETTE_NONFINITE", "value")
	assert_equal(palette.frame_count(), 0, "no partial initialization")
	values = _matrix(Transform3D.IDENTITY)
	assert_equal(palette.configure(HASH, 1, PackedInt32Array([1]), values), &"", "retry after refusal")


func test_matrix_blend_is_affine_not_a_hidden_quaternion_path() -> void:
	"""Opposite bases have their convex midpoint, exposing any accidental rotational interpolation."""
	var opposite: Basis = Basis(Vector3(-1, 0, 0), Vector3.UP, Vector3(0, 0, -1))
	var palette: Actor.Palette = _palette([Transform3D.IDENTITY, Transform3D(opposite, Vector3(4, 2, -6))])
	var out: PackedFloat32Array = _scratch(palette)
	assert_equal(palette.sample_into(PackedInt32Array([0, 1, 32768, 0, 0, 0, 65536]), out), &"", "half frame")
	var result: Transform3D = Actor.matrix_at(out, 0)
	assert_equal(result.basis.x, Vector3.ZERO, "affine x column")
	assert_equal(result.basis.y, Vector3.UP, "affine y column")
	assert_equal(result.basis.z, Vector3.ZERO, "affine z column")
	assert_equal(result.origin, Vector3(2, 1, -3), "same source interpolation for translation")


func test_transition_is_a_convex_combination_of_four_final_matrices() -> void:
	"""Nested fixed weights preserve the exact finite-content hull for body and attachment paths."""
	var palette: Actor.Palette = _palette([Transform3D(Basis.IDENTITY, Vector3(2, 0, 0)),
		Transform3D(Basis.IDENTITY, Vector3(6, 0, 0)), Transform3D(Basis.IDENTITY, Vector3(-2, 0, 0)),
		Transform3D(Basis.IDENTITY, Vector3(-6, 0, 0))])
	var out: PackedFloat32Array = _scratch(palette)
	assert_equal(palette.sample_into(PackedInt32Array([0, 1, 16384, 2, 3, 49152, 32768]), out), &"", "four inputs")
	assert_equal(Actor.matrix_at(out, 0).origin, Vector3(-1, 0, 0), "(-5 + 3) / 2")
	for weight: int in [0, 1, 16384, 32768, 65535, 65536]:
		assert_equal(palette.sample_into(PackedInt32Array([0, 1, weight, 2, 3, weight, weight]), out), &"", "legal endpoint")
		assert_true(out[9] >= -6.0 and out[9] <= 6.0, "inside source hull")
	assert_equal(Actor.matrix_at(out, 0).origin.x, 6.0, "last endpoint is exact")


func test_bad_frames_weights_and_scratch_preserve_the_prior_output() -> void:
	"""A rejected update never partially writes the caller's previously visible pose."""
	var palette: Actor.Palette = _palette([Transform3D.IDENTITY])
	var out: PackedFloat32Array = _scratch(palette)
	var before: PackedFloat32Array = out.duplicate()
	for position: int in [0, 1, 3, 4]:
		var frames: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0, 0])
		frames[position] = -1
		assert_equal(palette.sample_into(frames, out), &"UNDERGROUND_PALETTE_FRAME", "negative frame")
		frames[position] = 1
		assert_equal(palette.sample_into(frames, out), &"UNDERGROUND_PALETTE_FRAME", "missing frame")
	for position: int in [2, 5, 6]:
		var frames: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0, 0])
		for weight: int in [-1, 65537]:
			frames[position] = weight
			assert_equal(palette.sample_into(frames, out), &"UNDERGROUND_PALETTE_WEIGHT", "no extrapolation")
	assert_equal(palette.sample_into(PackedInt32Array(), out), &"UNDERGROUND_PALETTE_SAMPLE_FORMAT", "descriptor width")
	assert_equal(palette.sample_into(PackedInt32Array([0, 0, 0, 0, 0, 0, 0]), PackedFloat32Array([5])),
		&"UNDERGROUND_PALETTE_SAMPLE_FORMAT", "scratch width")
	assert_equal(out, before, "all rejected samples kept output unchanged")


func _surface() -> Array:
	"""Valid synthetic triangle; raw-array validation can test malformed inputs without engine errors."""
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.UP, Vector3.RIGHT])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK])
	return arrays


func _mesh(skinned: bool) -> ArrayMesh:
	"""An actual ArrayMesh reaches native skinning, with a deliberately simple synthetic source."""
	var arrays: Array = _surface()
	if skinned:
		arrays[Mesh.ARRAY_BONES] = PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
		arrays[Mesh.ARRAY_WEIGHTS] = PackedFloat32Array([1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0])
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, StandardMaterial3D.new())
	return mesh


func test_finite_baker_refuses_unrecorded_attachment_surface_overrides() -> void:
	"""Original attachment provenance cannot silently omit a future instance surface material."""
	var path: String = ProjectSettings.globalize_path("res://").path_join("../tools/bake_underground_matrices.gd").simplify_path()
	var baker: GDScript = load(path) as GDScript
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = _mesh(false)
	var original: Material = instance.mesh.surface_get_material(0)
	assert_equal(baker._attachment_material_error(instance), &"", "original surface")
	var override: StandardMaterial3D = StandardMaterial3D.new()
	instance.set_surface_override_material(0, override)
	assert_equal(baker._attachment_material_error(instance), &"PALETTE_PER_SURFACE_MATERIAL_OVERRIDE", "uncaptured surface")
	instance.material_override = StandardMaterial3D.new()
	assert_equal(baker._attachment_material_error(instance), &"PALETTE_PER_SURFACE_MATERIAL_OVERRIDE", "even hidden surface drift refused")
	assert_equal(instance.mesh.surface_get_material(0), original, "source material unchanged")
	assert_equal(instance.get_surface_override_material(0), override, "input instance unchanged")
	instance.set_surface_override_material(0, null)
	assert_equal(baker._attachment_material_error(instance), &"", "explicit supported global override")
	instance.material_overlay = StandardMaterial3D.new()
	assert_equal(baker._attachment_material_error(instance), &"PALETTE_ATTACHMENT_MATERIAL", "unrecorded overlay")
	instance.free()


func test_skin_validation_rejects_missing_eighth_influence_and_zero_weight() -> void:
	"""No omitted influences, undeformed fallback or normalization changes the real geometry."""
	var arrays: Array = _surface()
	assert_equal(Actor._surface_error(arrays, 0), &"", "static part")
	assert_equal(Actor._surface_error(arrays, 1), &"UNDERGROUND_ACTOR_SKIN", "missing skin")
	var bones: PackedInt32Array = PackedInt32Array()
	var weights: PackedFloat32Array = PackedFloat32Array()
	bones.resize(24)
	weights.resize(24)
	weights[7] = 1.0
	weights[15] = 1.0
	weights[23] = 0.75
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	assert_equal(Actor._surface_error(arrays, 1), &"", "eighth influence and non-unit sums retained")
	assert_equal(Actor._surface_error(arrays, 0), &"UNDERGROUND_ACTOR_SKIN", "static part cannot ignore skin")
	weights[23] = 0.0
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	assert_equal(Actor._surface_error(arrays, 1), &"UNDERGROUND_ACTOR_SKIN", "last vertex sum cannot vanish")
	weights[23] = 1.0
	bones[23] = 1
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	arrays[Mesh.ARRAY_BONES] = bones
	assert_equal(Actor._surface_error(arrays, 1), &"UNDERGROUND_ACTOR_SKIN", "eighth bind must exist")


func test_nonfinite_and_unproved_material_geometry_refuse_before_allocation() -> void:
	"""A shader or next pass cannot silently displace a certified original mesh."""
	var arrays: Array = _surface()
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(NAN, 0, 0)])
	assert_equal(Actor._surface_error(arrays, 0), &"UNDERGROUND_ACTOR_VERTEX", "nonfinite source")
	assert_equal(Actor._material_error(ShaderMaterial.new()), &"UNDERGROUND_ACTOR_SHADER", "custom shader")
	var material: StandardMaterial3D = StandardMaterial3D.new()
	assert_equal(Actor._material_error(material), &"", "original PBR accepted")
	material.next_pass = ShaderMaterial.new()
	assert_equal(Actor._material_error(material), &"UNDERGROUND_ACTOR_DISPLACEMENT", "hidden next pass")
	assert_not_null(material.next_pass, "rejection never changes shared original material")
	material.next_pass = null
	material.grow = true
	assert_equal(Actor._material_error(material), &"UNDERGROUND_ACTOR_DISPLACEMENT", "grown vertices")
	material.grow = false
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	assert_equal(Actor._material_error(material), &"UNDERGROUND_ACTOR_DISPLACEMENT", "camera deformation")


func test_actual_renderer_updates_original_mesh_and_owned_palette_or_refuses_dummy_backend() -> void:
	"""This test also runs in the native harness; headless refusal is never reported as rendering proof."""
	var actor: Actor = Actor.new()
	_attach_native(actor)
	var mesh: ArrayMesh = _mesh(true)
	var transform: Transform3D = Transform3D(Basis.IDENTITY, Vector3(0.25, 0.5, -0.75))
	var palette: Actor.Palette = _palette([transform])
	var result: StringName = actor.configure(palette, [mesh], HASH, [AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))])
	if DisplayServer.get_name() == "headless":
		assert_equal(result, &"UNDERGROUND_RENDERER_UNAVAILABLE", "dummy backend explicitly refused")
		assert_equal(actor.get_child_count(), 0, "no native state or preview mesh allocated")
	else:
		assert_equal(result, &"", "actual renderer bound")
		assert_false((actor.get_child(0) as MeshInstance3D).visible, "no uninitialized visible skin")
		assert_equal(actor.apply_pose(PackedInt32Array([0, 0, 0, 0, 0, 0, 0])), &"", "native palette update")
		assert_equal(actor.native_matrix(0, 0), transform, "native matrix roundtrip")
		assert_equal((actor.get_child(0) as MeshInstance3D).mesh, mesh, "original mesh/material shared")
		assert_true((actor.get_child(0) as MeshInstance3D).visible, "initialized source is visible")
		assert_equal(actor.set_parts_visible(0), &"", "explicit actual-owner visibility")
		assert_false((actor.get_child(0) as MeshInstance3D).visible, "requested part hidden")
	actor.release()
	actor.release()
	assert_equal(actor.get_child_count(), 0, "idempotent native ownership cleanup")
	assert_equal(actor.apply_pose(PackedInt32Array()), &"UNDERGROUND_ACTOR_UNBOUND", "retired renderer")
	actor.free()


func test_static_attachment_offsets_follow_the_same_finite_palette_and_native_lifetime() -> void:
	"""The attachment uses its full baked hand/fit transform, with no quaternion or new socket offset."""
	var actor: Actor = Actor.new()
	_attach_native(actor)
	var transform: Transform3D = Transform3D(Basis.IDENTITY.scaled(Vector3(0.5, 0.25, 0.75)), Vector3(1, 2, 3))
	var palette: Actor.Palette = _palette([transform], PackedInt32Array([0]))
	var mesh: ArrayMesh = _mesh(false)
	var bounds: Array[AABB] = [AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))]
	assert_equal(actor.configure(palette, [mesh], "f".repeat(64), bounds), &"UNDERGROUND_ACTOR_SOURCE", "mismatched certificate")
	var result: StringName = actor.configure(palette, [mesh], HASH, bounds)
	if DisplayServer.get_name() == "headless":
		assert_equal(result, &"UNDERGROUND_RENDERER_UNAVAILABLE", "native path unavailable")
	else:
		assert_equal(result, &"", "native attachment")
		assert_equal(actor.apply_pose(PackedInt32Array([0, 0, 0, 0, 0, 0, 0])), &"", "attachment pose")
		assert_equal(actor.native_matrix(0, 0), transform, "actual complete affine placement")
		assert_equal(actor.set_parts_visible(2), &"UNDERGROUND_ACTOR_PART_MASK", "unknown part refused")
		assert_equal(actor.native_matrix(0, 0), transform, "refused change preserves prior pose")
	actor.free() # Out-of-tree predelete must also release the allocated native ownership.


func test_actual_instance_material_is_preserved_without_modifying_the_original_mesh() -> void:
	"""The real demo log uses an instance override; omitting it changes visible wood into default gray."""
	var actor: Actor = Actor.new()
	_attach_native(actor)
	var mesh: ArrayMesh = _mesh(false)
	var original: Material = mesh.surface_get_material(0)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.32, 0.19, 0.08)
	var palette: Actor.Palette = _palette([Transform3D.IDENTITY], PackedInt32Array([0]))
	var bounds: Array[AABB] = [AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))]
	assert_equal(actor.configure(palette, [mesh], HASH, bounds, [ShaderMaterial.new()]),
		&"UNDERGROUND_ACTOR_SHADER", "override cannot bypass vertex contract")
	assert_equal(actor.configure(palette, [mesh], HASH, bounds, [material, material]),
		&"UNDERGROUND_ACTOR_PARTS", "no silently ignored material")
	var code: StringName = actor.configure(palette, [mesh], HASH, bounds, [material])
	if DisplayServer.get_name() == "headless":
		assert_equal(code, &"UNDERGROUND_RENDERER_UNAVAILABLE", "headless does not prove material binding")
	else:
		assert_equal(code, &"", "native original override")
		assert_equal((actor.get_child(0) as MeshInstance3D).material_override, material, "same authored Material resource")
		assert_equal((actor.get_child(0) as MeshInstance3D).get_active_material(0), material, "actual active wood material")
	assert_equal(mesh.surface_get_material(0), original, "shared original mesh never changed")
	actor.free()


func test_configuration_outside_the_scene_tree_cannot_publish_an_orphan_skin_palette() -> void:
	"""MeshInstance ENTER_TREE resolves its Skeleton path, so pre-entry native attachment is forbidden."""
	var actor: Actor = Actor.new()
	var palette: Actor.Palette = _palette([Transform3D.IDENTITY])
	var code: StringName = actor.configure(palette, [_mesh(true)], HASH, [AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))])
	assert_equal(code, &"UNDERGROUND_RENDERER_UNAVAILABLE" if DisplayServer.get_name() == "headless" \
		else &"UNDERGROUND_ACTOR_OUTSIDE_TREE", "no manual palette before mesh tree entry")
	assert_equal(actor.get_child_count(), 0, "refusal allocated no mesh or native skeleton")
	actor.free()


func test_common_grounding_uses_the_same_four_positive_frame_weights() -> void:
	"""The extra root translation preserves the endpoint hull without multiplying source skin weights."""
	var values: PackedFloat32Array = PackedFloat32Array()
	for index: int in 4:
		values.append_array(_matrix(Transform3D(Basis.IDENTITY, Vector3(index, 0, 0))))
	var grounding: PackedFloat32Array = PackedFloat32Array([2, 6, -2, -6])
	var palette: Actor.Palette = Actor.Palette.new()
	assert_equal(palette.configure(HASH, 4, PackedInt32Array([1]), values, grounding), &"", "grounded content")
	grounding.fill(999.0)
	var out: PackedFloat32Array = _scratch(palette)
	assert_equal(palette.scratch_count(), 13, "one shared scalar beyond the skin frame")
	assert_equal(palette.sample_into(PackedInt32Array([0, 1, 16384, 2, 3, 49152, 32768]), out), &"", "same nested blend")
	assert_equal(palette.grounding_y(out), -1.0, "(-5 + 3) / 2, isolated original values")
	assert_equal(Actor.matrix_at(out, 0).origin.y, 0.0, "grounding never modifies a bone coefficient")
	var before: PackedFloat32Array = out.duplicate()
	assert_equal(palette.sample_into(PackedInt32Array([0, 8, 0, 0, 0, 0, 0]), out), &"UNDERGROUND_PALETTE_FRAME", "invalid frame")
	assert_equal(out, before, "matrix and common root stay atomic on refusal")
	assert_equal(_palette([Transform3D.IDENTITY]).grounding_y(PackedFloat32Array()), 0.0, "legacy no-offset content preserved")


func test_grounding_capacity_and_nonfinite_source_refuse_before_any_publication() -> void:
	"""The existing scalar ceiling includes the new root sequence; no larger hidden palette is admitted."""
	var values: PackedFloat32Array = _matrix(Transform3D.IDENTITY)
	var palette: Actor.Palette = Actor.Palette.new()
	assert_equal(palette.configure(HASH, 1, PackedInt32Array([1]), values, PackedFloat32Array([0, 1])),
		&"UNDERGROUND_PALETTE_GROUNDING_FORMAT", "exact frame count")
	for value: float in [NAN, INF, -INF, 1025.0]:
		assert_equal(palette.configure(HASH, 1, PackedInt32Array([1]), values, PackedFloat32Array([value])),
			&"UNDERGROUND_PALETTE_GROUNDING_NONFINITE", "bad common root refuses")
	assert_equal(Actor.Palette._grounding_error(1, Actor.MAX_SCALARS, PackedFloat32Array([0])),
		&"UNDERGROUND_PALETTE_GROUNDING_FORMAT", "same total scalar budget, tested without huge allocation")
	assert_equal(palette.frame_count(), 0, "no source partially published")
	assert_equal(palette.configure(HASH, 1, PackedInt32Array([1]), values, PackedFloat32Array([0.25])), &"", "valid retry")


func test_native_common_translation_moves_body_and_attachment_without_changing_skin_matrices() -> void:
	"""Real native parts receive one post-skin transform; dummy headless rendering still refuses."""
	var values: PackedFloat32Array = _matrix(Transform3D.IDENTITY)
	values.append_array(_matrix(Transform3D.IDENTITY))
	var palette: Actor.Palette = Actor.Palette.new()
	assert_equal(palette.configure(HASH, 1, PackedInt32Array([1, 0]), values, PackedFloat32Array([0.75])), &"", "two actual parts")
	var actor: Actor = Actor.new()
	_attach_native(actor)
	var bounds: AABB = AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))
	var code: StringName = actor.configure(palette, [_mesh(true), _mesh(false)], HASH, [bounds, bounds])
	if DisplayServer.get_name() == "headless":
		assert_equal(code, &"UNDERGROUND_RENDERER_UNAVAILABLE", "no false native evidence")
	else:
		assert_equal(code, &"", "native original parts")
		assert_equal(actor.apply_pose(PackedInt32Array([0, 0, 0, 0, 0, 0, 0])), &"", "actual common shift")
		assert_equal(actor.native_matrix(0, 0), Transform3D.IDENTITY, "original bone matrix stays exact")
		assert_equal((actor.get_child(0) as MeshInstance3D).position.y, 0.75, "body common translation")
		assert_equal(actor.native_matrix(1, 0).origin.y, 0.75, "attachment identical translation")
	actor.free()
