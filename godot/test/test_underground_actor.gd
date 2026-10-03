extends "res://test/framework/test_case.gd"
## Synthetic affine fixtures test the representation, never qualify a cast or connector.

const Actor := preload("res://demo/cast/underground_actor.gd")
const HASH: String = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
const Space := preload("res://scripts/core/room_space.gd")


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


func _world_metadata() -> Dictionary:
	"""Synthetic complete wire fixture; source declarations alone never qualify production coefficients."""
	return {"engine": Engine.get_version_info(), "source": {"sha256": HASH},
		"rendering_driver": "opengl3", "rendering_method": "gl_compatibility",
		"display_server": DisplayServer.get_name() if DisplayServer.get_name() != "headless" else "macOS",
		"api_version": RenderingServer.get_video_adapter_api_version() if DisplayServer.get_name() != "headless" else "4.1 fixture"}


func _world_file(modifier: int = 0) -> String:
	"""Write every actual finite heading as a disposable fixture, optionally corrupting one bounded contract."""
	var path: String = "user://underground-world-fixture-%d-%d.bin" % [get_instance_id(), modifier]
	var metadata: Dictionary = _world_metadata()
	if modifier == 4:
		metadata.source.sha256 = "f".repeat(64)
	if modifier == 5:
		metadata.rendering_driver = "vulkan"
	if modifier == 7:
		metadata.extra = [[[]]]
	if modifier == 8:
		metadata.extra = "x".repeat(2048)
	var bytes: PackedByteArray = JSON.stringify(metadata).to_utf8_buffer()
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer("UGYAW001".to_ascii_buffer())
	file.store_32(1)
	file.store_32(65535 if modifier == 3 else 65536)
	file.store_32(bytes.size())
	file.store_buffer(bytes)
	for yaw: int in 65536:
		var basis: Basis = Basis(Vector3.UP, float(yaw) * TAU / 65536.0)
		file.store_float(INF if modifier == 1 and yaw == 32769 else basis.x.x)
		file.store_float(basis.z.x)
	file.store_buffer(("INVALID!" if modifier == 2 else "UGYEND01").to_ascii_buffer())
	if modifier == 6:
		file.store_8(0)
	file.close()
	return path


func _world_basis() -> Actor.WorldBasis:
	"""Load the complete fixture through the actual streaming reader, then discard only its own source file."""
	var path: String = _world_file()
	var basis: Actor.WorldBasis = Actor.WorldBasis.new()
	assert_equal(basis.load_file(path, FileAccess.get_sha256(path), HASH, Actor.WorldBasis.RESERVED_BYTES), &"", "full source")
	assert_equal(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)), OK, "fixture removed")
	return basis


func _world_domain(minimum: Vector3i = Vector3i(0, -32, 0)) -> Space.Domain:
	"""The real Domain type validates the finite initial pack; fixture World identity grants no live authority."""
	var domain: Space.Domain = Space.Domain.new()
	assert_equal(domain.configure(Vector2i(5, 9), Vector3i(0, 512, 0), minimum,
		Vector3i(256, 48, 256), 8192, 6144, Space.MAX_CHECKS), &"", "exact immutable descriptor")
	return domain


func test_complete_world_basis_source_is_immutable_and_selection_preserves_refused_output() -> void:
	"""All finite native entries survive streaming without idealizing the tiny nonzero cardinal components."""
	var basis: Actor.WorldBasis = _world_basis()
	var out: PackedFloat32Array = PackedFloat32Array([19, 20])
	for yaw: int in [0, 1, 16384, 32768, 49152, 65535]:
		var native: Basis = Basis(Vector3.UP, float(yaw) * TAU / 65536.0)
		assert_equal(basis.coefficients_into(yaw, out), &"", "exact heading")
		assert_equal(out, PackedFloat32Array([native.x.x, native.z.x]), "native coefficient retained")
	var previous: PackedFloat32Array = out.duplicate()
	for yaw: int in [-1, 65536]:
		assert_equal(basis.coefficients_into(yaw, out), &"UNDERGROUND_WORLD_BASIS_SELECTION", "finite heading only")
	assert_equal(out, previous, "refusal preserves output")
	assert_equal(basis.coefficients_into(0, PackedFloat32Array()), &"UNDERGROUND_WORLD_BASIS_SELECTION", "two-scalar output")
	assert_equal(basis.producer_digest(), HASH, "exact expected producer")
	assert_equal(basis.load_file("missing", HASH, HASH, Actor.WorldBasis.RESERVED_BYTES),
		&"UNDERGROUND_WORLD_BASIS_ALREADY_LOADED", "no replacement or second bank")


func test_world_basis_reader_refuses_corrupt_rows_metadata_footer_and_source_atomically() -> void:
	"""No positive count or format-compatible buffer can replace a complete source and its exact provenance."""
	var basis: Actor.WorldBasis = Actor.WorldBasis.new()
	for modifier: int in [1, 2, 3, 4, 5, 6, 7, 8]:
		var path: String = _world_file(modifier)
		assert_true(basis.load_file(path, FileAccess.get_sha256(path), HASH, Actor.WorldBasis.RESERVED_BYTES) != &"", "refused corruption")
		assert_equal(basis.source_digest(), "", "partial candidate never published")
		var out: PackedFloat32Array = PackedFloat32Array([17, 18])
		assert_equal(basis.coefficients_into(0, out), &"UNDERGROUND_WORLD_BASIS_SELECTION", "unbound partial data")
		assert_equal(out, PackedFloat32Array([17, 18]), "unchanged refused output")
		assert_equal(basis._coefficients.size(), 0, "failed source releases partial numeric bank")
		assert_equal(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)), OK, "own corrupt fixture removed")
	var valid_path: String = _world_file()
	assert_equal(basis.load_file(valid_path, HASH, HASH, Actor.WorldBasis.RESERVED_BYTES), &"UNDERGROUND_WORLD_BASIS_DIGEST", "same-stream hash")
	assert_equal(basis.load_file(valid_path, FileAccess.get_sha256(valid_path), HASH, Actor.WorldBasis.RESERVED_BYTES - 1),
		&"UNDERGROUND_WORLD_BASIS_ADMISSION", "reserve before allocation")
	assert_equal(basis.load_file(valid_path, FileAccess.get_sha256(valid_path), HASH, Actor.WorldBasis.RESERVED_BYTES), &"", "valid retry")
	assert_equal(DirAccess.remove_absolute(ProjectSettings.globalize_path(valid_path)), OK, "own fixture removed")


func test_world_binding_requires_the_entire_actual_domain_descriptor_and_exact_root_range() -> void:
	"""World generation, datum, extents and technical budgets cannot borrow another descriptor's proof."""
	var domain: Space.Domain = _world_domain()
	assert_equal(Actor.world_domain_refusal(domain, domain.descriptor()), &"", "exact initial domain")
	for key: String in domain.descriptor():
		var changed: Dictionary = domain.descriptor()
		changed.erase(key)
		assert_equal(Actor.world_domain_refusal(domain, changed), &"UNDERGROUND_ACTOR_WORLD_DOMAIN", "missing bound field")
	var descriptor: Dictionary = domain.descriptor()
	descriptor.world_ref.y += 1
	assert_equal(Actor.world_domain_refusal(domain, descriptor), &"UNDERGROUND_ACTOR_WORLD_DOMAIN", "foreign generation")
	descriptor = domain.descriptor()
	descriptor.max_checks -= 1
	assert_equal(Actor.world_domain_refusal(domain, descriptor), &"UNDERGROUND_ACTOR_WORLD_DOMAIN", "different capacity contract")
	var large: Space.Domain = _world_domain(Vector3i(20000, -32, 0))
	assert_equal(Actor.world_domain_refusal(large, large.descriptor()), &"UNDERGROUND_ACTOR_WORLD_PRECISION", "unproved int32 root precision")
	assert_equal(Actor.world_domain_refusal(Space.Domain.new(), Space.Domain.new().descriptor()),
		&"UNDERGROUND_ACTOR_WORLD_DOMAIN", "unconfigured domain")


func test_explicit_world_equation_keeps_grounding_after_skin_and_identical_attachment_root() -> void:
	"""Rotation uses actual table coefficients and one scalar double expression before each native store."""
	var local: Transform3D = Transform3D(Basis(Vector3(2, 1, 0), Vector3(0, 3, 1), Vector3(1, 0, 4)), Vector3(0.25, -0.5, 0.75))
	var root_u: Vector3i = Vector3i(262143, -32256, 131073)
	var basis: Basis = Basis(Vector3.UP, TAU / 4.0)
	var composed: Transform3D = Actor.world_transform(local, 0.75, root_u, basis.x.x, basis.z.x)
	assert_equal(composed.basis.x, Actor.world_column(local.basis.x, basis.x.x, basis.z.x), "same actual coefficients")
	assert_equal(composed.origin.y, -31.25, "grounded Y and root in one expression")
	assert_true(absf(composed.origin.x - 256.7490234375) < 0.0001, "positive Z rotates toward positive X")
	var body: Transform3D = Actor.world_transform(Transform3D.IDENTITY, 0.75, root_u, basis.x.x, basis.z.x)
	assert_equal(body.origin, Vector3(float(root_u.x) / 1024.0, -30.75, float(root_u.z) / 1024.0), "post-skin body origin")


func test_native_world_binding_keeps_global_parts_independent_of_parent_and_refused_updates() -> void:
	"""Runs in the real native harness; headless explicitly proves only backend refusal, never deformation."""
	var actor: Actor = Actor.new()
	var parent: Node3D = Node3D.new()
	if DisplayServer.get_name() != "headless":
		(Engine.get_main_loop() as SceneTree).root.add_child(parent)
	parent.add_child(actor)
	var palette: Actor.Palette = _palette([Transform3D(Basis.IDENTITY, Vector3(0.25, 0.5, -0.75))])
	var code: StringName = actor.configure(palette, [_mesh(true)], HASH, [AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))])
	if DisplayServer.get_name() == "headless":
		assert_equal(code, &"UNDERGROUND_RENDERER_UNAVAILABLE", "no dummy source binding")
	else:
		assert_equal(code, &"", "actual native palette")
		_check_native_world(actor, parent, palette)
	parent.free()


func _check_native_world(actor: Actor, parent: Node3D, palette: Actor.Palette) -> void:
	"""Hidden-before-root, source identity and all rejected updates precede immutable global comparisons."""
	var basis: Actor.WorldBasis = _world_basis()
	var domain: Space.Domain = _world_domain()
	assert_equal(actor.bind_world_source(basis, domain, domain.descriptor(), "f".repeat(64), basis.source_digest()),
		&"UNDERGROUND_ACTOR_WORLD_SOURCE", "different palette source")
	assert_equal(actor.bind_world_source(basis, domain, domain.descriptor(), palette.source_digest(), basis.source_digest()),
		&"", "actual exact runtime and finite source")
	assert_equal(actor.apply_pose(PackedInt32Array([0, 0, 0, 0, 0, 0, 0])), &"", "pose before root")
	var node: MeshInstance3D = actor.get_child(0) as MeshInstance3D
	assert_false(node.visible, "bound part needs a root")
	assert_true(node.top_level, "arbitrary parent is excluded")
	assert_equal(actor.set_world_root(Vector2i(5, 9), Vector3i(16384, -4608, 8192), 16384), &"", "exact root")
	var before: Transform3D = node.global_transform
	parent.transform = Transform3D(Basis(Vector3.RIGHT, 0.7).scaled(Vector3(2, 3, 4)), Vector3(1900, -1000, 800))
	actor.transform = Transform3D(Basis(Vector3.BACK, 1.1), Vector3(17, 19, 23))
	assert_equal(node.global_transform, before, "parent changes cannot alter the proof equation")
	assert_true(node.visible, "initialized exact root and pose")
	assert_equal(actor.set_world_root(Vector2i(5, 10), Vector3i(16384, -4608, 8192), 0),
		&"UNDERGROUND_ACTOR_WORLD_BINDING", "full World generation")
	assert_equal(actor.set_world_root(Vector2i(5, 9), Vector3i(262144, -4608, 8192), 0),
		&"UNDERGROUND_ACTOR_WORLD_ROOT", "half-open root maximum")
	assert_equal(actor.set_world_root(Vector2i(5, 9), Vector3i(16384, -4608, 8192), 65536),
		&"UNDERGROUND_WORLD_BASIS_SELECTION", "no heading rounding")
	assert_equal(node.global_transform, before, "all rejected updates preserve visible world pose")
	assert_equal(actor.native_matrix(0, 0), Transform3D(Basis.IDENTITY, Vector3(0.25, 0.5, -0.75)), "original skin matrix")


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
