extends "res://test/framework/test_case.gd"
## Synthetic finite wire/mesh fixtures. They do not qualify a species, tool grip or physical work contact.

const Content := preload("res://demo/cast/underground_actor_content.gd")
const Actor := preload("res://demo/cast/underground_actor.gd")
const Profiles := preload("res://scripts/core/underground_profiles.gd")
const RESERVE: int = 2098304
const HASH: String = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"


func _mesh(offset: float = 0.0) -> ArrayMesh:
	"""One actual four-influence ArrayMesh; the skin uses no invented normalized weights."""
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-0.5 + offset, 0, 0), Vector3(0.5, 0, 0), Vector3(0, 1, 0)])
	arrays[Mesh.ARRAY_BONES] = PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
	arrays[Mesh.ARRAY_WEIGHTS] = PackedFloat32Array([1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0])
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _file(mesh: ArrayMesh, modifier: int = 0, loop_mode: int = 1, duration: int = 65536) -> String:
	"""A create-only fixture has the same row and footer format as the independently generated content."""
	var path: String = "user://actor-content-%d-%d-%d.bin" % [get_instance_id(), modifier, loop_mode]
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer("UGACNT01".to_ascii_buffer())
	for value: int in [1, 1, 1, 1, 2, 2147483647 if modifier == 1 else 12]:
		file.store_32(value)
	for value: int in [0, -32, 0, 128, 64, 128]:
		file.store_32(value)
	for source: int in 4:
		file.store_buffer(HASH.hex_decode())
	_write_part(file, mesh, modifier)
	for value: int in [1 if modifier == 2 else 0, 2, loop_mode, 0 if modifier == 3 else duration]:
		file.store_32(value)
	file.store_buffer(HASH.hex_decode())
	_write_frames(file, modifier)
	file.store_buffer(("INVALID!" if modifier == 5 else "UGAEND01").to_ascii_buffer())
	if modifier == 6:
		file.store_8(0)
	file.close()
	return path


func _write_part(file: FileAccess, mesh: ArrayMesh, modifier: int) -> void:
	"""Retain exact geometry digest and pre-world culling coordinates in the compact descriptor."""
	for value: int in [1, 3, 1, 0]:
		file.store_32(value)
	var digest: PackedByteArray = Content.mesh_fingerprint(mesh, 1, 3, 1)
	if modifier == 7:
		digest[0] ^= 1
	file.store_buffer(digest)
	for value: int in [-1024, -1, -1024, 1024, 1025, 1024]:
		file.store_32(value)


func _write_frames(file: FileAccess, modifier: int) -> void:
	"""One exact identity frame and one translated frame, followed by common grounding values."""
	for frame: int in 2:
		var values: PackedFloat32Array = PackedFloat32Array([1, 0, 0, 0, 1, 0, 0, 0, 1, frame, 0, 0])
		if modifier == 4:
			values[0] = INF
		for value: float in values:
			file.store_float(value)
	file.store_float(0.0)
	file.store_float(0.25)


func _load(mesh: ArrayMesh, loop_mode: int = 1) -> Content:
	"""Exercise the same complete reader as a real source and remove only this test's fixture."""
	var path: String = _file(mesh, 0, loop_mode)
	var result: Content = Content.new()
	assert_equal(result.load_file(path, FileAccess.get_sha256(path), RESERVE), &"", "complete immutable content")
	assert_equal(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)), OK, "owned source removed")
	return result


func test_streamed_source_is_immutable_and_has_explicit_full_peak_admission() -> void:
	"""A live Palette is never replaced, and declared decode/mesh overlap is retained in the census."""
	var content: Content = _load(_mesh())
	assert_equal(content.part_count(), 1, "part census")
	assert_equal(content.clip_count(), 1, "clip census")
	assert_equal(content.source_digest().length(), 64, "full actual image digest")
	assert_equal(content.required_peak_bytes(), RESERVE, "source-derived peak")
	assert_equal(content.load_file("absent", HASH, RESERVE), &"ACTOR_CONTENT_ALREADY_LOADED", "immutable once")
	assert_true(content.domain_matches(PackedInt32Array([0, -32, 0, 128, 64, 128])), "exact finite bounds")
	assert_false(content.domain_matches(PackedInt32Array([0, -33, 0, 128, 64, 128])), "no extent substitution")
	var timing: PackedInt32Array = PackedInt32Array([7, 9])
	assert_true(content.clip_timing_into(0, timing), "actual finite duration")
	assert_equal(timing, PackedInt32Array([65536, 1]), "exact source loop mode")
	assert_false(content.clip_timing_into(1, timing), "absent clip")
	assert_equal(timing, PackedInt32Array([65536, 1]), "refused timing unchanged")
	assert_false(content.clip_timing_into(0, PackedInt32Array()), "exact caller shape")


func test_refused_corrupt_candidate_keeps_no_partial_palette_or_identity() -> void:
	"""Bad rows, counts, floats, footers and trailing images refuse rather than manufacturing a positive count."""
	var mesh: ArrayMesh = _mesh()
	var content: Content = Content.new()
	for modifier: int in [1, 2, 3, 4, 5, 6]:
		var path: String = _file(mesh, modifier)
		assert_true(content.load_file(path, FileAccess.get_sha256(path), RESERVE) != &"", "corruption refused")
		assert_equal(content.source_digest(), "", "no source identity")
		assert_equal(content.part_count(), 0, "no part table")
		assert_equal(content.clip_count(), 0, "no clip table")
		assert_equal(content.required_peak_bytes(), 0, "no admitted image")
		assert_equal(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)), OK, "fixture removed")


func test_hash_and_last_byte_of_presentation_reserve_are_mandatory() -> void:
	"""The small header can admit decode but may not waive the larger actual mesh-array obligation."""
	var path: String = _file(_mesh())
	var content: Content = Content.new()
	assert_equal(content.load_file(path, HASH, RESERVE), &"ACTOR_CONTENT_DIGEST", "full consumed hash")
	assert_equal(content.load_file(path, FileAccess.get_sha256(path), RESERVE - 1),
		&"ACTOR_CONTENT_PRESENTATION_RESERVE", "every admitted byte required")
	assert_equal(content.load_file(path, "bad", RESERVE), &"ACTOR_CONTENT_ARGUMENT", "digest format")
	assert_equal(content.load_file("missing", HASH, RESERVE), &"ACTOR_CONTENT_FILE", "missing source refuses")
	assert_equal(content.load_file(path, FileAccess.get_sha256(path), RESERVE), &"", "exact budget succeeds after refusal")
	assert_equal(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)), OK, "fixture removed")


func test_fixed_presentation_phase_preserves_loop_clamp_and_ping_pong_source_modes() -> void:
	"""Source timing uses existing30Hz ticks and fixed interpolation; no authoritative position is written."""
	var mesh: ArrayMesh = _mesh()
	var clamped: Content = _load(mesh, 0)
	var looped: Content = _load(mesh, 1)
	var reflected: Content = _load(mesh, 2)
	var out: PackedInt32Array = PackedInt32Array([7, 8, 9])
	assert_equal(clamped.clip_into(0, 32768, out), &"", "half step")
	assert_equal(out, PackedInt32Array([0, 1, 32768]), "exact source interval")
	assert_equal(clamped.clip_into(0, 98304, out), &"", "nonloop stop")
	assert_equal(out, PackedInt32Array([1, 1, 0]), "final source pose retained")
	assert_equal(looped.clip_into(0, 98304, out), &"", "loop wraps")
	assert_equal(out, PackedInt32Array([0, 0, 32768]), "loop closes to first finite pose")
	assert_equal(reflected.clip_into(0, 98304, out), &"", "pingpong returns")
	assert_equal(out, PackedInt32Array([0, 1, 32768]), "reversed source phase")
	var prior: PackedInt32Array = out.duplicate()
	assert_equal(looped.clip_into(1, 0, out), &"ACTOR_CONTENT_CLIP_QUERY", "missing clip")
	assert_equal(looped.clip_into(0, -1, out), &"ACTOR_CONTENT_CLIP_QUERY", "negative clock")
	assert_equal(out, prior, "refused scratch unchanged")


func test_short_final_source_interval_reaches_the_actual_finite_endpoint() -> void:
	"""A nonintegral clip duration must not stop halfway between the final two sampled poses."""
	var path: String = _file(_mesh(), 0, 0, 32768)
	var content: Content = Content.new()
	assert_equal(content.load_file(path, FileAccess.get_sha256(path), RESERVE), &"", "half-tick final interval")
	var out: PackedInt32Array = PackedInt32Array([7, 8, 9])
	assert_equal(content.clip_into(0, 16384, out), &"", "halfway through shorter interval")
	assert_equal(out, PackedInt32Array([0, 1, 32768]), "rescaled actual final interval")
	assert_equal(content.clip_into(0, 32768, out), &"", "source stop time")
	assert_equal(out, PackedInt32Array([1, 1, 0]), "exact final finite pose")
	assert_equal(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)), OK, "fixture removed")


func test_provenance_readers_preserve_failed_outputs_and_do_not_bless_unbound_profiles() -> void:
	"""A matching source is a necessary content identity; it never replaces the actual physical owner."""
	var content: Content = _load(_mesh())
	var out: PackedByteArray = PackedByteArray()
	out.resize(32)
	for which: int in 4:
		assert_true(content.source_hash_into(which, out), "declared provenance")
		assert_equal(out.hex_encode(), HASH, "exact source digest")
	var prior: PackedByteArray = out.duplicate()
	assert_false(content.source_hash_into(4, out), "no absent provenance")
	assert_equal(out, prior, "unchanged refused bytes")
	assert_false(content.profile_matches(null, 0, 1, 1), "missing owner")
	assert_false(content.profile_matches(Profiles.new(), 0, 1, 1), "unloaded profile cannot authorize source")


func test_borrowed_mesh_geometry_and_skin_must_match_every_source_byte() -> void:
	"""Valid resource names or a shared bind count cannot substitute another original mesh."""
	var mesh: ArrayMesh = _mesh()
	var content: Content = _load(mesh)
	assert_equal(content.mesh_binding_refusal([mesh]), &"", "original exact geometry")
	assert_equal(content.mesh_binding_refusal([_mesh(0.125)]), &"ACTOR_CONTENT_MESH_DIGEST", "changed source geometry")
	assert_equal(content.mesh_binding_refusal([]), &"ACTOR_CONTENT_MESH_COUNT", "missing part")
	assert_equal(content.mesh_binding_refusal([BoxMesh.new()]), &"ACTOR_CONTENT_ORIGINAL_ARRAY_MESH", "no generated fallback")
	assert_equal(Content.mesh_fingerprint(mesh, 1, 4, 1).size(), 0, "exact vertex count")
	assert_equal(Content.mesh_fingerprint(mesh, 2, 3, 2).size(), 0, "exact surface count")
	var path: String = _file(mesh, 7)
	var wrong: Content = Content.new()
	assert_equal(wrong.load_file(path, FileAccess.get_sha256(path), RESERVE), &"", "image digest alone does not prove mesh")
	assert_equal(wrong.mesh_binding_refusal([mesh]), &"ACTOR_CONTENT_MESH_DIGEST", "source fingerprint independently required")
	assert_equal(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)), OK, "fixture removed")


func test_actor_configuration_refuses_before_native_allocation_when_source_or_tree_is_missing() -> void:
	"""Native rendered configuration belongs to a SceneTree lifecycle test; refusal preserves the existing instance."""
	var mesh: ArrayMesh = _mesh()
	var content: Content = _load(mesh)
	var actor: Actor = Actor.new()
	assert_equal(content.configure_actor(null, [mesh], []), &"ACTOR_CONTENT_ACTOR", "missing actor")
	assert_equal(content.configure_actor(actor, [_mesh(0.25)], []), &"ACTOR_CONTENT_MESH_DIGEST", "refuse before actor")
	var unavailable: StringName = &"UNDERGROUND_RENDERER_UNAVAILABLE" if DisplayServer.get_name() == "headless" \
		else &"UNDERGROUND_ACTOR_OUTSIDE_TREE"
	assert_equal(content.configure_actor(actor, [mesh], []), unavailable, "actual backend and SceneTree required")
	actor.free()
