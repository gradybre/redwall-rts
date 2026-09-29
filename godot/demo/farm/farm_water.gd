extends RefCounted
## Where the farm finds water. Decision 0196.
##
## THE FARM'S WATER QUERY. Irrigation needs a single fact about the village's water: is this point (x, z
## in the tunnel network's integer u) at a water edge? The farm asks it only through the Callable
## demo_village.gd hands it -- `edge_query()` of demo/demo_water.gd, the village's ONE water adapter,
## which the tunnel works' wet-ground and flood queries go through too. Until the village's real water
## (feat/demo-water: the stream and pond, with their shore map) is wired into that adapter, the answer
## comes from DEMO_EDGES below, a tiny table of water-edge circles; the tests pass fixtures of their own.
##
## THE PLACEHOLDER POND, and only it, is water the farm draws itself: the demo world draws reeds at
## the west edge beside the beds (world_layout.gd NATURE: reeds_a..c) but no open water. It is a flat
## disc under the reeds and one obstacle circle, ISOLATED in the two PLACEHOLDER functions below and
## their two call sites (demo_village.gd `_obstacles_with_pond`, demo_farm.gd `_build_view`), so it
## is deleted, not reworked, when the real water merges. Its centre and size are demo values.

const PLACEHOLDER_CENTRE_M: Vector2 = Vector2(-21.4, 10.2)
const PLACEHOLDER_RADIUS_M: float = 3.0
## Water-edge circles (x_u, z_u, reach_u): a point within `reach` of the centre is at the water's
## edge. The one row is the placeholder pond: centre (-21.4, 10.2) m, 3 m radius, plus 2 m of shore.
const DEMO_EDGES: Array[Vector3i] = [Vector3i(-21914, 10445, 5120)]
const WATER_COLOR: Color = Color(0.29, 0.39, 0.37, 0.86)
const BANK_COLOR: Color = Color(0.3, 0.26, 0.2)
const SEGMENTS: int = 40


static func is_demo_edge_u(x_u: int, z_u: int) -> bool:
	"""PLACEHOLDER, asked only by demo_water.gd: the demo table's answer: whether (x, z) in u lies within reach of a DEMO_EDGES circle."""
	for edge: Vector3i in DEMO_EDGES:
		var dx: int = x_u - edge.x
		var dz: int = z_u - edge.y
		if dx * dx + dz * dz <= edge.z * edge.z:
			return true
	return false


# --- PLACEHOLDER POND: remove both when feat/demo-water merges ------------------------------------

static func placeholder_obstacle() -> Vector3:
	"""PLACEHOLDER: the pond as a world obstacle circle, in the published Vector3(x, radius, z) form."""
	return Vector3(PLACEHOLDER_CENTRE_M.x, PLACEHOLDER_RADIUS_M, PLACEHOLDER_CENTRE_M.y)


static func build_placeholder() -> Node3D:
	"""PLACEHOLDER: the pond's mesh -- a still water disc on an earth bank, just above the ground."""
	var node := Node3D.new()
	node.name = "PlaceholderPond"
	node.position = Vector3(PLACEHOLDER_CENTRE_M.x, 0.0, PLACEHOLDER_CENTRE_M.y)
	node.add_child(_disc("Bank", PLACEHOLDER_RADIUS_M + 0.35, 0.012, BANK_COLOR, false))
	node.add_child(_disc("Water", PLACEHOLDER_RADIUS_M, 0.03, WATER_COLOR, true))
	return node


static func _disc(node_name: String, radius: float, height: float, colour: Color, water: bool) -> MeshInstance3D:
	"""PLACEHOLDER: a flat disc of `radius` at `height` (water: glossy and a little see-through)."""
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.01
	mesh.radial_segments = SEGMENTS
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.08 if water else 0.95
	material.metallic_specular = 0.7 if water else 0.2
	if water:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position.y = height
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance
