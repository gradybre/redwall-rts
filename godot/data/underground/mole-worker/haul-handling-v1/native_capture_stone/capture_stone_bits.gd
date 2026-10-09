extends SceneTree
## Exact-bit transcript of the procedural stone lump (ADR 1206, native image v9).
## stone-source-v1's JSON numbers drop the sign of 16 negative-zero coordinates, which the native mesh
## fingerprint hashes bit for bit. This records the committed surface's raw little-endian float32 vertex bytes
## and the Content fingerprint the loader will demand. Run inside the game project (the real factory).

const Dressing := preload("res://demo/tunnel/bore_dressing.gd")
const Content := preload("res://demo/cast/underground_actor_content.gd")
const FACTORY_PATH: String = "res://demo/tunnel/bore_dressing.gd"


func _initialize() -> void:
	"""Isolated from gameplay owners; reads only the shared static factory."""
	call_deferred("_run")


func _run() -> void:
	"""Write the exact surface bytes once; refuse an existing output."""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1 or FileAccess.file_exists(args[0]):
		printerr("STONE_BITS_OUTPUT")
		quit(2)
		return
	var stone: ArrayMesh = Dressing.stone_mesh()
	var arrays: Array = stone.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var bounds: AABB = stone.get_aabb()
	var box: PackedFloat32Array = PackedFloat32Array([bounds.position.x, bounds.position.y, bounds.position.z,
		bounds.size.x, bounds.size.y, bounds.size.z])
	var report: Dictionary = {"schema": 1, "production_qualified": false,
		"factory": "bore_dressing.gd::stone_mesh", "factory_sha256": FileAccess.get_sha256(FACTORY_PATH),
		"engine": Engine.get_version_info(), "vertex_count": vertices.size(), "format": stone.surface_get_format(0),
		"points_le_f32_hex": vertices.to_byte_array().hex_encode(),
		"indices_le_i32_hex": indices.to_byte_array().hex_encode(),
		"aabb_le_f32_hex": box.to_byte_array().hex_encode(),
		"mesh_sha256": Content.mesh_fingerprint(stone, 0, vertices.size(), 1).hex_encode()}
	var file: FileAccess = FileAccess.open(args[0], FileAccess.WRITE)
	if file == null:
		printerr("STONE_BITS_OPEN")
		quit(2)
		return
	file.store_string(JSON.stringify(report, "\t", true) + "\n")
	file.close()
	print("haul-stone-bits: ", vertices.size(), " vertices; mesh ", report.mesh_sha256)
	quit(0)
