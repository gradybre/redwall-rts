extends RefCounted
## ADR1211: the part meshes and materials of every mole presentation source, built once from assets that already
## exist. Nothing here is authored: each mesh is the factory its source image was compiled from, and the Content
## refuses any part whose exact geometry fingerprint differs (Content.mesh_binding_refusal), so a wrong mesh can never
## be drawn in place of the certified one.
##   body (sources 0-3): the staged mole_digger import through the approved hand derivative (mole_grip_source.gd)
##   source 0/1 part 1: the staged mole_pick prop
##   source 2 part 1: the native-program-v8 stock factory (a 0.0495 m x 1 m cylinder, its own wood material)
##   source 3 part 1: the tunnel dressing's stone lump (bore_dressing.gd::stone_mesh) with the derived stone material
##   sources 4/5 (ADR1217 step 5, claw and paw handling): the original open-paw import body itself, no held part

const Grip := preload("res://data/underground/mole-worker/mole_grip_source.gd")
const Presentation := preload("res://data/underground/mole-worker/mole_presentation.gd")
const Props := preload("res://demo/props/demo_props.gd")
const CAST_KEY: StringName = &"mole_digger"
const PICK_KEY: StringName = &"mole_pick"
## native_replay_v8/capture_native_program.gd::_stock(): the accepted 522-vertex stock and its own material.
const STOCK_RADIUS_M: float = 0.9 * 0.055
const STOCK_HEIGHT_M: float = 1.0
const STOCK_COLOUR: Color = Color("8a5837")
const STOCK_ROUGHNESS: float = 0.9


class Parts extends RefCounted:
	## Per source index: an Array[Mesh] and an Array[Material] (empty when that source has no parts built).
	var meshes: Array = []
	var materials: Array = []
	var error: StringName = &""


static func build(manifest: Dictionary, props: Props) -> Parts:
	"""All six sources' parts, or the first refusal; the import is freed before returning."""
	var parts: Parts = Parts.new()
	parts.meshes.resize(Presentation.ContentSet.MAX_SOURCES)
	parts.materials.resize(Presentation.ContentSet.MAX_SOURCES)
	var cast: Dictionary = manifest.get("cast", {})
	var row: Dictionary = cast.get(String(CAST_KEY), {})
	var path: String = String(row.get("body", ""))
	if path.is_empty() or not ResourceLoader.exists(path) or props == null or not props.is_staged(PICK_KEY):
		parts.error = &"ENTRY_WORKER_ASSETS_NOT_STAGED"
		return parts
	var scene: PackedScene = load(path) as PackedScene
	var body: Node = scene.instantiate() if scene != null else null
	if body == null:
		parts.error = &"ENTRY_WORKER_BODY"
		return parts
	_fill(parts, body, props.mesh_of(PICK_KEY))
	body.free()
	return parts


static func _fill(parts: Parts, body: Node, pick: Mesh) -> void:
	"""Derive the closed-paw body once and pair it with each held part; the claw and paw images take the open paw."""
	var nodes: Array[Node] = body.find_children("*", "MeshInstance3D", true, false)
	var rigs: Array[Node] = body.find_children("*", "Skeleton3D", true, false)
	if nodes.size() != 1 or rigs.size() != 1:
		parts.error = &"ENTRY_WORKER_BODY"
		return
	var instance: MeshInstance3D = nodes[0] as MeshInstance3D
	var derived: Grip.Result = Grip.create(instance.mesh as ArrayMesh, instance.skin, rigs[0] as Skeleton3D, pick_fit())
	if derived.error != &"":
		parts.error = derived.error
		return
	var skin: Material = instance.material_override
	var held: Array[Mesh] = [pick, pick, stock_mesh(), Presentation.Dressing.stone_mesh()]
	var held_materials: Array[Material] = [null, null, null, Presentation.stone_material()]
	for source: int in held.size():
		var meshes: Array[Mesh] = [derived.mesh, held[source]]
		var materials: Array[Material] = [skin, held_materials[source]]
		parts.meshes[source] = meshes
		parts.materials[source] = materials
	for source: int in [Presentation.SOURCE_CLAW, Presentation.SOURCE_PAW]:
		var open_paw: Array[Mesh] = [instance.mesh]
		var open_materials: Array[Material] = [skin]
		parts.meshes[source] = open_paw
		parts.materials[source] = open_materials


static func pick_fit() -> Transform3D:
	"""The source-bound pick fit the approved hand derivative is pinned to (Grip.FIT_DIGEST checks it exactly)."""
	var bound: AABB = AABB(Vector3(-0.274994641542435, 0.0, -0.213909700512886),
		Vector3(0.54998928308487, 0.112690538167953, 0.427819401025772))
	var grip: Vector3 = Vector3(bound.end.x - bound.size.x * 0.14, bound.get_center().y, bound.get_center().z)
	var turn: Basis = Basis.from_euler(Vector3(0, 90, 90) * (PI / 180.0))
	return Transform3D(turn, Vector3.ZERO) * Transform3D(Basis.IDENTITY, -grip) \
		* Transform3D(Basis.from_scale(Vector3.ONE * 0.289199709892273), Vector3.ZERO)


static func stock_mesh() -> ArrayMesh:
	"""The wood stock factory native image v8 was compiled from; its fingerprint is checked by the Content."""
	var stock: CylinderMesh = CylinderMesh.new()
	stock.top_radius = STOCK_RADIUS_M
	stock.bottom_radius = stock.top_radius
	stock.height = STOCK_HEIGHT_M
	var result: ArrayMesh = ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, stock.get_mesh_arrays())
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = STOCK_COLOUR
	material.roughness = STOCK_ROUGHNESS
	result.surface_set_material(0, material)
	return result
