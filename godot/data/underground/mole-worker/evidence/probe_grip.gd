extends SceneTree
## Read-only geometry measurements for authored grip correction. They provide no clearance certificate.

const Demo := preload("res://demo/cast/demo_actor.gd")
const CastSpace := preload("res://demo/cast/cast_space.gd")
const Props := preload("res://demo/props/demo_props.gd")


func _initialize() -> void:
	"""Measure only the current original staged mesh into a new diagnostic file."""
	call_deferred("_run")


func _run() -> void:
	"""Retain hand-local vertices and weights so palm/grip authoring is based on the real rig, not an AABB guess."""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1 or FileAccess.file_exists(args[0]):
		printerr("GRIP_PROBE_OUTPUT_EXISTS")
		quit(2)
		return
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://demo/assets/manifest.json")) as Dictionary
	var space: CastSpace = CastSpace.new()
	space.setup([], [])
	var actor: Demo = Demo.new()
	if not actor.setup_creature(0, &"mole_digger", manifest.cast.mole_digger, space, 1729):
		actor.free()
		quit(2)
		return
	root.add_child(actor)
	var report: Dictionary = _measure(actor, manifest)
	actor.free()
	if report.has("error"):
		printerr(report.error)
		quit(2)
		return
	var file: FileAccess = FileAccess.open(args[0], FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	print("grip-probe: ", report.hand_vertices.size(), " actual right-hand vertices; production=0")
	quit(0)


func _measure(actor: Demo, manifest: Dictionary) -> Dictionary:
	"""Skin bind poses provide the exact mesh-to-hand frame used by every actual clip."""
	var nodes: Array[Node] = actor.get_node("Body").find_children("*", "MeshInstance3D", true, false)
	if nodes.size() != 1:
		return {"error": "GRIP_PROBE_BODY_CENSUS"}
	var mesh: MeshInstance3D = nodes[0] as MeshInstance3D
	var skeleton: Skeleton3D = actor.get("_skeleton") as Skeleton3D
	var hand: int = skeleton.find_bone("RightHand")
	var skin: Skin = mesh.skin
	var bind: int = -1
	for index: int in skin.get_bind_count():
		var bone: int = skeleton.find_bone(skin.get_bind_name(index)) if skin.get_bind_name(index) != &"" else skin.get_bind_bone(index)
		if bone == hand:
			bind = index
	if bind < 0 or mesh.mesh.get_surface_count() != 1:
		return {"error": "GRIP_PROBE_BIND_OR_SURFACE"}
	var props: Props = Props.new()
	props.load_from(manifest)
	var tunnel: GDScript = load("res://demo/tunnel/tunnel_ext.gd") as GDScript
	var fit: Transform3D = tunnel.call("pick_fit", props)
	return {"schema": 1, "cast": "mole_digger", "hand_bone": hand, "skin_bind": bind,
		"body": mesh.mesh.resource_path, "hand_vertices": _hand_vertices(mesh.mesh, skin.get_bind_pose(bind), bind),
		"hand_bind": _matrix(skin.get_bind_pose(bind)), "old_pick_fit": _matrix(fit),
		"pick_fit_x_axis": [fit.basis.x.x, fit.basis.x.y, fit.basis.x.z],
		"body_sha256": FileAccess.get_sha256("res://demo/assets/cast/mole_digger/body.glb"),
		"purpose": "source-local palm/shaft authoring only; exact grip and geometry variants remain unqualified"}


func _hand_vertices(mesh: Mesh, pose: Transform3D, hand: int) -> Array[Dictionary]:
	"""Diagnostic majority-weight selection; this is not a deformation mask or a gameplay predicate."""
	var arrays: Array = mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var ids: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	@warning_ignore("integer_division") var stride: int = weights.size() / points.size()
	var result: Array[Dictionary] = []
	for vertex: int in points.size():
		var share: float = 0.0
		for influence: int in stride:
			if ids[vertex * stride + influence] == hand:
				share += weights[vertex * stride + influence]
		if share < 0.5:
			continue
		var local: Vector3 = pose * points[vertex]
		result.append({"index": vertex, "hand_local": [local.x, local.y, local.z], "weight": share})
	return result


func _matrix(value: Transform3D) -> Array[float]:
	"""An explicit scalar transcript avoids unreadable implicit Variant serialization."""
	return [value.basis.x.x, value.basis.x.y, value.basis.x.z, value.basis.y.x, value.basis.y.y, value.basis.y.z,
		value.basis.z.x, value.basis.z.y, value.basis.z.z, value.origin.x, value.origin.y, value.origin.z]
