extends SceneTree
## Capture the actual procedural stone lump (bore_dressing.gd::stone_mesh), unit size, as the engine commits it.
## Run inside the game project so the real factory is used, never a re-typed copy (ADR 1206).

const Dressing := preload("res://demo/tunnel/bore_dressing.gd")
const FACTORY_PATH: String = "res://demo/tunnel/bore_dressing.gd"


func _initialize() -> void:
	"""The capture is isolated from all gameplay owners; it only reads the shared static factory."""
	call_deferred("_run")


func _run() -> void:
	"""Emit every committed vertex and index of surface 0; authoring never substitutes a guessed lump."""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1 or FileAccess.file_exists(args[0]):
		printerr("STONE_CAPTURE_OUTPUT")
		quit(2)
		return
	var stone: ArrayMesh = Dressing.stone_mesh()
	if stone == null or stone.get_surface_count() != 1:
		printerr("STONE_CAPTURE_SURFACES")
		quit(2)
		return
	var report: Dictionary = _report(stone)
	var file: FileAccess = FileAccess.open(args[0], FileAccess.WRITE)
	if file == null:
		printerr("STONE_CAPTURE_OPEN")
		quit(2)
		return
	file.store_string(JSON.stringify(report, "\t", true, true) + "\n")
	file.close()
	var indices: Array = report.indices
	@warning_ignore("integer_division")
	var triangles: int = indices.size() / 3
	print("haul-stone-topology: ", report.vertex_count, " vertices, ", triangles, " triangles; qualification=0")
	quit(0)


func _report(stone: ArrayMesh) -> Dictionary:
	"""Retain the complete native surface plus the factory's exact source digest and dressing scale range."""
	var arrays: Array = stone.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var points: Array = []
	for vertex: Vector3 in vertices:
		points.append([vertex.x, vertex.y, vertex.z])
	var bounds: AABB = stone.get_aabb()
	return {"schema": 1, "engine": Engine.get_version_info(), "production_qualified": false,
		"factory": "bore_dressing.gd::stone_mesh; unit lump, SphereMesh radial_segments=9 rings=5",
		"factory_sha256": FileAccess.get_sha256(FACTORY_PATH),
		"dressing_scale_m": [Dressing.STONE_MIN_M, Dressing.STONE_MAX_M],
		"vertex_count": vertices.size(), "format": stone.surface_get_format(0),
		"primitive": stone.surface_get_primitive_type(0),
		"bounds": [bounds.position.x, bounds.position.y, bounds.position.z, bounds.size.x, bounds.size.y, bounds.size.z],
		"points": points, "indices": Array(arrays[Mesh.ARRAY_INDEX])}
