extends SceneTree
## Decision1080. Complete finite native yaw source, never a sampled clearance/profile permission.
## This tool writes only new own-worktree output files; no paid service or source asset is edited.

const MAGIC: String = "UGYAW001"
const FOOTER: String = "UGYEND01"
const VERSION: int = 1
const HEADING_COUNT: int = 65536
const COEFFICIENT_BYTES: int = HEADING_COUNT * 8
const MAX_METADATA_BYTES: int = 4096
const MAX_FILE_BYTES: int = 20 + MAX_METADATA_BYTES + COEFFICIENT_BYTES + 8
const PRESENTATION_RESERVE: int = COEFFICIENT_BYTES + 4096 + 16384
const ENGINE_HASH: String = "ed1daf0bf001b61586d9930840f2f1394092c079"
var _binary: String = ""
var _report: String = ""
var _rows: int = 0
var _source_bytes: int = 0
var _max_norm_squared: float = 0.0 # Diagnostic only; exact rational proof is an offline consumer.


func _initialize() -> void:
	"""The scene/backend initialize before reading metadata or writing the complete native table."""
	call_deferred("_run")


func _run() -> void:
	"""Refuse output collisions and unreviewed engines before starting any finite source stream."""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2:
		printerr("usage: bake_underground_world_basis.gd -- output.ugyaw report.json")
		quit(2)
		return
	_binary = args[0]
	_report = args[1]
	var code: StringName = output_refusal(_binary, _report, get_script().resource_path)
	var metadata: Dictionary = _metadata()
	if code == &"":
		code = backend_refusal(metadata)
	if code == &"":
		code = _bake(metadata)
	if code != &"":
		printerr(String(code))
		quit(2)
	else:
		print("world basis: ", _rows, " exact native headings; source only, 0 qualified profiles")
		quit(0)


static func output_refusal(binary_path: String, report_path: String, source_path: String) -> StringName:
	"""A refused invocation preserves existing source, raw data and report bytes."""
	var binary: String = ProjectSettings.globalize_path(binary_path).simplify_path()
	var report: String = ProjectSettings.globalize_path(report_path).simplify_path()
	var source: String = ProjectSettings.globalize_path(source_path).simplify_path()
	if binary == "" or report == "" or binary == report or binary == source or report == source:
		return &"WORLD_BASIS_OUTPUT_IDENTITY"
	for path: String in [binary, report]:
		if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):
			return &"WORLD_BASIS_OUTPUT_EXISTS"
		var parent: DirAccess = DirAccess.open(path.get_base_dir())
		if parent == null or parent.is_link(path.get_file()):
			return &"WORLD_BASIS_OUTPUT_DIRECTORY"
	return &""


func _metadata() -> Dictionary:
	"""Hash the actual executable script; the table claims no universal native trigonometric implementation."""
	var source: String = get_script().resource_path
	return {"schema": VERSION, "engine": Engine.get_version_info(),
		"source": {"path": source, "sha256": FileAccess.get_sha256(source)},
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"display_server": DisplayServer.get_name(), "api_version": RenderingServer.get_video_adapter_api_version(),
		"heading_count": HEADING_COUNT, "orientation": "0=-Z,+quarter=-X; +Y remains up",
		"coefficient_order": ["basis.x.x", "basis.z.x"],
		"meaning": "every finite native Y basis, immutable presentation source; not a contact or clearance certificate"}


static func backend_refusal(metadata: Dictionary) -> StringName:
	"""Match the same reviewed official single-precision native GL source as the matrix presentation."""
	var raw: Variant = metadata.get("engine")
	if not raw is Dictionary:
		return &"WORLD_BASIS_ENGINE_UNREVIEWED"
	var engine: Dictionary = raw
	if engine.get("major") != 4 or engine.get("minor") != 7 or engine.get("patch") != 2 \
			or engine.get("hash") != ENGINE_HASH or engine.get("build") != "official" or engine.get("status") != "stable":
		return &"WORLD_BASIS_ENGINE_UNREVIEWED"
	if metadata.get("rendering_driver") != "opengl3" or metadata.get("rendering_method") != "gl_compatibility" \
			or metadata.get("display_server") not in ["macOS", "Windows", "X11", "Wayland"]:
		return &"WORLD_BASIS_BACKEND_UNREVIEWED"
	var api_value: Variant = metadata.get("api_version", "")
	if not api_value is String:
		return &"WORLD_BASIS_PRECISION_UNREVIEWED"
	var api: String = api_value
	if not api.begins_with("4.") or api.length() < 3 or api[2] not in "123456":
		return &"WORLD_BASIS_PRECISION_UNREVIEWED"
	return &""


static func coefficients_into(yaw: int, out: PackedFloat32Array) -> StringName:
	"""Observe one finite actual native matrix, preserving caller scratch on every refusal."""
	if yaw < 0 or yaw >= HEADING_COUNT or out.size() != 2:
		return &"WORLD_BASIS_INPUT"
	var basis: Basis = Basis(Vector3.UP, float(yaw) * TAU / float(HEADING_COUNT))
	if not basis.is_finite() or basis.y != Vector3.UP or basis.x.y != 0.0 or basis.z.y != 0.0 \
			or basis.x.x != basis.z.z or basis.x.z != -basis.z.x \
			or absf(basis.x.x) > 1.0 or absf(basis.z.x) > 1.0:
		return &"WORLD_BASIS_REPRESENTATION"
	out[0] = basis.x.x
	out[1] = basis.z.x
	return &""


func _bake(metadata: Dictionary) -> StringName:
	"""Stream two binary32 coefficients per row; no in-memory full table or second raw image is created."""
	var text: PackedByteArray = JSON.stringify(metadata).to_utf8_buffer()
	if text.size() > MAX_METADATA_BYTES:
		return &"WORLD_BASIS_METADATA_CAPACITY"
	var file: FileAccess = FileAccess.open(_binary, FileAccess.WRITE)
	if file == null:
		return &"WORLD_BASIS_OUTPUT_UNWRITABLE"
	file.store_buffer(MAGIC.to_ascii_buffer())
	file.store_32(VERSION)
	file.store_32(HEADING_COUNT)
	file.store_32(text.size())
	file.store_buffer(text)
	var code: StringName = _write_rows(file)
	if code == &"":
		file.store_buffer(FOOTER.to_ascii_buffer())
		if file.get_error() != OK or file.get_position() > MAX_FILE_BYTES:
			code = &"WORLD_BASIS_OUTPUT_IO"
	_source_bytes = file.get_position()
	file.close()
	return _write_report(metadata) if code == &"" else code


func _write_rows(file: FileAccess) -> StringName:
	"""Every supported heading is a stored source value; there is no unsampled angular interval."""
	var coefficients: PackedFloat32Array = PackedFloat32Array([0.0, 0.0])
	for yaw: int in HEADING_COUNT:
		var code: StringName = coefficients_into(yaw, coefficients)
		if code != &"":
			return code
		file.store_float(coefficients[0])
		file.store_float(coefficients[1])
		_max_norm_squared = maxf(_max_norm_squared,
			float(coefficients[0]) * coefficients[0] + float(coefficients[1]) * coefficients[1])
		_rows += 1
	return &"" if file.get_error() == OK else &"WORLD_BASIS_OUTPUT_IO"


func _write_report(metadata: Dictionary) -> StringName:
	"""The diagnostic float norm is not the conservative certificate; the exact offline proof still owns that."""
	var file: FileAccess = FileAccess.open(_report, FileAccess.WRITE)
	if file == null:
		return &"WORLD_BASIS_REPORT_UNWRITABLE"
	var report: Dictionary = {"schema": VERSION, "metadata": metadata, "rows": _rows,
		"source_bytes": _source_bytes, "sha256": FileAccess.get_sha256(_binary),
		"diagnostic_max_norm_squared": _max_norm_squared, "coefficient_bytes": COEFFICIENT_BYTES,
		"planned_presentation_reserve": PRESENTATION_RESERVE, "native_reservation_measured": false,
		"qualified_profiles": 0, "status": "FINITE_NATIVE_YAW_SOURCE_ONLY"}
	file.store_string(JSON.stringify(report, "  ") + "\n")
	var code: StringName = &"" if file.get_error() == OK else &"WORLD_BASIS_OUTPUT_IO"
	file.close()
	return code
