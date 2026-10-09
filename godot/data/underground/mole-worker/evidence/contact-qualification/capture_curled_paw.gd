extends SceneTree
## ADR 1216: run the curled-paw successor on the real staged mole body, natively, and record what it made.
## Writes the derived mesh fingerprint, the changed-vertex count, and every vertex's mesh-space position so the
## Python author's shape can be compared vertex by vertex. Usage:
##   godot --headless --path godot --script res://data/underground/mole-worker/evidence/contact-qualification/capture_curled_paw.gd -- <out.json>

const Curl := preload("res://data/underground/mole-worker/mole_grip_curl_source.gd")
const Accepted := preload("res://data/underground/mole-worker/mole_grip_source.gd")
const Meshes := preload("res://demo/cast/entry_worker_meshes.gd")
const Content := preload("res://demo/cast/underground_actor_content.gd")
const MANIFEST: String = "res://demo/assets/manifest.json"


func _initialize() -> void:
	"""Build, measure and write; any refusal is written as the error and exits nonzero."""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var report: Dictionary = {"error": "CAPTURE_ARGUMENTS"}
	if args.size() == 1:
		report = _capture()
	var file: FileAccess = FileAccess.open(args[0] if args.size() == 1 else "user://curl.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report))
	file.close()
	quit(0 if String(report.get("error", "")) == "" else 1)


func _capture() -> Dictionary:
	"""The staged body through both derivatives; positions are mesh space, float32 as the engine holds them."""
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var scene: PackedScene = load(String(manifest["cast"]["mole_digger"]["body"])) as PackedScene
	var body: Node = scene.instantiate()
	var instance: MeshInstance3D = body.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var rig: Skeleton3D = body.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var curled: Curl.Result = Curl.create(instance.mesh as ArrayMesh, instance.skin, rig, Meshes.pick_fit())
	var closed: Accepted.Result = Accepted.create(instance.mesh as ArrayMesh, instance.skin, rig, Meshes.pick_fit())
	var report: Dictionary = {"error": String(curled.error), "accepted_error": String(closed.error)}
	if curled.error == &"":
		report["changed_vertices"] = curled.changed_vertices
		report["derived_digest"] = Content.mesh_fingerprint(curled.mesh, Accepted.BINDS, Accepted.VERTICES, 1).hex_encode()
		report["points"] = _flat(curled.mesh)
		report["fit"] = _transform(curled.fit)
	body.free()
	return report


func _flat(mesh: ArrayMesh) -> Array:
	"""Every vertex position as three floats."""
	var points: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var out: Array = []
	for point: Vector3 in points:
		out.append_array([point.x, point.y, point.z])
	return out


func _transform(value: Transform3D) -> Array:
	"""Basis columns then origin."""
	return [value.basis.x.x, value.basis.x.y, value.basis.x.z, value.basis.y.x, value.basis.y.y, value.basis.y.z,
		value.basis.z.x, value.basis.z.y, value.basis.z.z, value.origin.x, value.origin.y, value.origin.z]
