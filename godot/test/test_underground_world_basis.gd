extends "res://test/framework/test_case.gd"
## The whole finite actual native Y matrix table; no profile or world-contact qualification.

const TEMP: String = "user://test-underground-world-basis.bin"
const REPORT: String = "user://test-underground-world-basis.json"
var _baker: GDScript = null


func before_each() -> void:
	"""Read the uniquely owned offline tool without constructing its SceneTree or running its output CLI."""
	var path: String = ProjectSettings.globalize_path("res://").path_join("../tools/bake_underground_world_basis.gd").simplify_path()
	_baker = load(path) as GDScript
	assert_true(_baker != null, "actual source script loaded")


func after_each() -> void:
	"""Remove only the local fixture output bytes created by these tests."""
	_baker = null
	for path: String in [TEMP, REPORT]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_every_finite_heading_reconstructs_the_actual_native_basis_exactly() -> void:
	"""All65536 stored entries, including noncardinal cases, reproduce the native basis without interpolation."""
	var out: PackedFloat32Array = PackedFloat32Array([0.0, 0.0])
	var first_bad: int = -1
	for yaw: int in 65536:
		var actual: Basis = Basis(Vector3.UP, float(yaw) * TAU / 65536.0)
		var code: StringName = _baker.coefficients_into(yaw, out)
		var rebuilt: Basis = Basis(Vector3(out[0], 0.0, -out[1]), Vector3.UP, Vector3(out[1], 0.0, out[0]))
		if code != &"" or rebuilt != actual:
			first_bad = yaw
			break
	assert_equal(first_bad, -1, "all native values and seven implied components match")
	assert_equal(_baker.HEADING_COUNT, 65536, "complete16-bit source domain")


func test_zero_and_quarter_heading_keep_the_adopted_forward_convention() -> void:
	"""The real native transform maps0 to-Z and the positive quarter turn to-X, without gameplay rounding."""
	var out: PackedFloat32Array = PackedFloat32Array([9.0, 9.0])
	assert_equal(_baker.coefficients_into(0, out), &"", "zero native heading")
	assert_equal(out, PackedFloat32Array([1.0, 0.0]), "exact origin orientation")
	assert_equal(_baker.coefficients_into(16384, out), &"", "positive native quarter")
	var forward: Vector3 = Vector3(-out[1], 0.0, -out[0])
	assert_true(forward.x < -0.9999 and absf(forward.z) < 0.0001, "native handedness agrees with integer world")
	assert_true(out[0] != 0.0, "the actual small native cosine is retained, never replaced by cardinal zero")


func test_refused_heading_or_wrong_output_shape_leaves_previous_bytes_unchanged() -> void:
	"""No out-of-domain index is wrapped and no scratch is resized before proof."""
	var out: PackedFloat32Array = PackedFloat32Array([7.0, 8.0])
	for yaw: int in [-1, 65536, 9223372036854775807]:
		assert_equal(_baker.coefficients_into(yaw, out), &"WORLD_BASIS_INPUT", "outside finite table")
		assert_equal(out, PackedFloat32Array([7.0, 8.0]), "refused row preserved")
	var short: PackedFloat32Array = PackedFloat32Array([7.0])
	assert_equal(_baker.coefficients_into(0, short), &"WORLD_BASIS_INPUT", "exact shape")
	assert_equal(short, PackedFloat32Array([7.0]), "wrong-shaped output preserved")


func _metadata() -> Dictionary:
	"""Synthetic metadata validation fixture; only the real native bake can bind an actual backend."""
	return {"engine": {"major": 4, "minor": 7, "patch": 2, "hash": _baker.ENGINE_HASH,
		"build": "official", "status": "stable"}, "rendering_driver": "opengl3",
		"rendering_method": "gl_compatibility", "display_server": "macOS", "api_version": "4.1 fixture"}


func test_backend_engine_and_precision_scope_never_silently_expand() -> void:
	"""A matching version number alone does not claim this source certificate for another engine/shader backend."""
	var metadata: Dictionary = _metadata()
	assert_equal(_baker.backend_refusal(metadata), &"", "only a format fixture")
	metadata.engine.hash = "0".repeat(40)
	assert_equal(_baker.backend_refusal(metadata), &"WORLD_BASIS_ENGINE_UNREVIEWED", "exact official source")
	metadata = _metadata()
	metadata.rendering_driver = "vulkan"
	assert_equal(_baker.backend_refusal(metadata), &"WORLD_BASIS_BACKEND_UNREVIEWED", "another shader path")
	metadata = _metadata()
	metadata.display_server = "headless"
	assert_equal(_baker.backend_refusal(metadata), &"WORLD_BASIS_BACKEND_UNREVIEWED", "no native renderer")
	metadata = _metadata()
	metadata.api_version = "OpenGL ES 3.2"
	assert_equal(_baker.backend_refusal(metadata), &"WORLD_BASIS_PRECISION_UNREVIEWED", "no mediump substitution")
	metadata.engine = "not an engine record"
	assert_equal(_baker.backend_refusal(metadata), &"WORLD_BASIS_ENGINE_UNREVIEWED", "malformed record")


func test_existing_source_or_output_is_never_overwritten_by_preflight() -> void:
	"""A refused rebake preserves all prior bytes, including a lone incomplete raw source."""
	var file: FileAccess = FileAccess.open(TEMP, FileAccess.WRITE)
	file.store_buffer(PackedByteArray([1, 2, 3, 4]))
	file.close()
	assert_equal(_baker.output_refusal(TEMP, REPORT, _baker.resource_path), &"WORLD_BASIS_OUTPUT_EXISTS", "existing raw")
	assert_equal(FileAccess.get_file_as_bytes(TEMP), PackedByteArray([1, 2, 3, 4]), "previous source unchanged")
	assert_equal(_baker.output_refusal(REPORT, REPORT, _baker.resource_path), &"WORLD_BASIS_OUTPUT_IDENTITY", "outputs alias")
	assert_equal(_baker.output_refusal(_baker.resource_path, REPORT, _baker.resource_path),
		&"WORLD_BASIS_OUTPUT_IDENTITY", "input source protected")
	assert_false(FileAccess.file_exists(REPORT), "preflight never starts a partial report")


func test_shared_presentation_budget_does_not_borrow_simulation_arenas() -> void:
	"""One native coefficient image plus explicit loading/native allowance, not one image per resident."""
	assert_equal(_baker.COEFFICIENT_BYTES, 524288, "two native float32 values for every finite heading")
	assert_equal(_baker.PRESENTATION_RESERVE, 544768, "planned separate presentation peak")
	assert_equal(_baker.MAX_FILE_BYTES, 528412, "finite metadata and trailer bound")
