extends SceneTree
## Capture the actual existing CylinderMesh, then require its full palette fingerprint in the Python proof.


func _initialize() -> void:
	"""The capture is isolated from all gameplay owners and existing project fixtures."""
	call_deferred("_run")


func _run() -> void:
	"""Emit every native vertex and index; authoring never substitutes a guessed cylinder topology."""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1 or FileAccess.file_exists(args[0]):
		printerr("HANDLING_CAPTURE_OUTPUT")
		quit(2)
		return
	var stock: CylinderMesh = CylinderMesh.new()
	stock.top_radius = 0.9 * 0.055
	stock.bottom_radius = stock.top_radius
	stock.height = 1.0
	var report: Dictionary = _report(stock)
	var file: FileAccess = FileAccess.open(args[0], FileAccess.WRITE)
	if file == null:
		printerr("HANDLING_CAPTURE_OPEN")
		quit(2)
		return
	file.store_string(JSON.stringify(report, "\t", true, true) + "\n")
	file.close()
	print("haul-stock-topology: ", report.vertex_count, " vertices, ", report.indices.size() / 3, " triangles; qualification=0")
	quit(0)


func _report(stock: CylinderMesh) -> Dictionary:
	"""Use the same source factory as demo_actor.gd and retain its complete native output."""
	var arrays: Array = stock.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var points: Array = []
	for vertex: Vector3 in vertices:
		points.append([vertex.x, vertex.y, vertex.z])
	var bounds: AABB = stock.get_aabb()
	return {"schema": 1, "engine": Engine.get_version_info(), "production_qualified": false,
		"factory": "demo_actor.gd::_build_load; height_m=0.9", "vertex_count": vertices.size(),
		"format": 0, "primitive": Mesh.PRIMITIVE_TRIANGLES,
		"bounds": [bounds.position.x, bounds.position.y, bounds.position.z, bounds.size.x, bounds.size.y, bounds.size.z],
		"points": points, "indices": Array(arrays[Mesh.ARRAY_INDEX])}
