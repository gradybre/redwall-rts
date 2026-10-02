extends Node3D
## The kitchen garden's paths as drawn (decision 0883; farm_garden.gd THE SERVICE POINTS). Presentation only.
##
## Once the garden has its first bed (the shelf up), a cross of trodden dirt paths runs between its four sites -- one
## between the two columns from the work shelf to the garden's south edge, one between the two rows -- GDD §5.9's dirt
## path, drawn as worn ground just above the grass. The beds, the shelf (farm_stock_view.gd OTHER SHELVES) and the well
## draw themselves. Refreshed at the panels' cadence; it changes only when the shelf goes up.

const Catalog := preload("res://demo/farm/farm_catalog.gd")
const GardenScript := preload("res://demo/farm/farm_garden.gd")

## Path width and colour (demo values: the village's worn paths' width and a dry-earth tone).
const PATH_WIDTH_M: float = 0.6
const PATH_Y_M: float = 0.012
const PATH_COLOR: Color = Color(0.52, 0.42, 0.3)

var _garden: GardenScript = null
var _paths: Node3D = null


func build(garden: GardenScript) -> void:
	"""Build the paths for this garden, hidden until its shelf is up."""
	name = "GardenView"
	_garden = garden
	_paths = Node3D.new()
	_paths.name = "GardenPaths"
	_paths.visible = false
	add_child(_paths)
	var bounds: Rect2 = garden_rect()
	var middle: Vector2 = bounds.get_center()
	var material := StandardMaterial3D.new()
	material.albedo_color = PATH_COLOR
	material.roughness = 1.0
	_paths.add_child(_strip(Vector2(middle.x, (Catalog.GARDEN_SHELF_AT.y + bounds.end.y) * 0.5),
		Vector2(PATH_WIDTH_M, bounds.end.y - Catalog.GARDEN_SHELF_AT.y), material))
	_paths.add_child(_strip(middle, Vector2(bounds.size.x, PATH_WIDTH_M), material))


static func garden_rect() -> Rect2:
	"""The ground the four sites cover, edge to edge."""
	var rect := Rect2(Catalog.GARDEN_AT[0], Vector2.ZERO)
	for at: Vector2 in Catalog.GARDEN_AT:
		rect = rect.expand(at - Vector2.ONE * Catalog.GARDEN_HALF_M).expand(at + Vector2.ONE * Catalog.GARDEN_HALF_M)
	return rect


static func _strip(centre: Vector2, size: Vector2, material: Material) -> MeshInstance3D:
	"""A flat strip of path `size` (x, z) centred on `centre`."""
	var mesh := PlaneMesh.new()
	mesh.size = size
	mesh.material = material
	var strip := MeshInstance3D.new()
	strip.mesh = mesh
	strip.position = Vector3(centre.x, PATH_Y_M, centre.y)
	strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return strip


func refresh() -> void:
	"""Show the paths once the garden's shelf is up."""
	if _garden != null and _paths.visible != _garden.shelf_up:
		_paths.visible = _garden.shelf_up


func paths_shown() -> bool:
	"""Whether the paths are drawn (checks)."""
	return _paths.visible
