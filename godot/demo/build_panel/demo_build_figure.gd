extends Node3D
## A RESIDENT BELOW, DRAWN IN THE BUILD PANEL'S WORLD VIEW (decision 1912's proof of concept). While a resident is
## underground in the dug rooms (demo_build_below_task.gd) the demo's own actor is indoors and not drawn; this stands
## in for it on the World view's marks layer (demo_build_world.gd), at the floor of the level it is on: a body the
## creature's height with its name over it, so the player can watch the mole dig and residents walk into the rooms.
## A stand-in, not the creature's model: the actors' rigs are drawn only on the surface and the legacy warren's layers.
## Its place is the level's floor plane (where cells are picked); the body and name are drawn SINK_M lower, on the dug
## pit's floor (demo_build_earth.gd DEPTH_M, decision 1913). Its name is drawn over everything, outline under text, and
## kept off the other tags by demo_build_tags.gd. Presentation only.

const Earth := preload("res://demo/build_panel/demo_build_earth.gd")

const LAYER: int = 256
const RADIUS_M: float = 0.28
const HEIGHT_M: float = 0.95
const NAME_PX: int = 36
const NAME_PIXEL_SIZE: float = 0.01
const NAME_PRIORITY: int = 5
const SINK_M: float = Earth.DEPTH_M
const BODY: Color = Color(0.3, 0.24, 0.32)
const DIGGING: Color = Color(0.85, 0.55, 0.3)

var _body: MeshInstance3D = null
var _name: Label3D = null
var _material: StandardMaterial3D = null


func _init() -> void:
	"""The body and its name tag, hidden."""
	name = "BuildFigure"
	visible = false
	_material = StandardMaterial3D.new()
	_material.albedo_color = BODY
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var capsule: CapsuleMesh = CapsuleMesh.new()
	capsule.radius = RADIUS_M
	capsule.height = HEIGHT_M
	_body = MeshInstance3D.new()
	_body.mesh = capsule
	_body.material_override = _material
	_body.layers = LAYER
	add_child(_body)
	_name = Label3D.new()
	_name.layers = LAYER
	_name.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name.no_depth_test = true
	_name.font_size = NAME_PX
	_name.pixel_size = NAME_PIXEL_SIZE
	_name.outline_size = 8
	_name.render_priority = NAME_PRIORITY
	_name.outline_render_priority = NAME_PRIORITY - 1
	add_child(_name)
	set_sink(SINK_M)


func show_as(name_words: String, at: Vector3) -> void:
	"""Shown at `at` (the floor, metres) with `name_words` over it."""
	_name.text = name_words
	position = at
	set_sink(SINK_M)
	visible = true


func set_sink(depth_m: float) -> void:
	"""Draw the body and name `depth_m` below its place: a dug pit's floor (SINK_M), or the floor of the cell being
	dug while it deepens under the mole (review M2: it no longer stands buried under a shallow pit)."""
	if is_equal_approx(_body.position.y, HEIGHT_M / 2.0 - depth_m):
		return
	_body.position.y = HEIGHT_M / 2.0 - depth_m
	_name.position.y = HEIGHT_M + 0.35 - depth_m


func move_to(at: Vector3) -> void:
	"""Stand at `at` (metres)."""
	position = at


func set_digging(digging: bool) -> void:
	"""A lighter, earthier body while it digs (its words say so too)."""
	_material.albedo_color = DIGGING if digging else BODY


func tag() -> Label3D:
	"""Its name tag (demo_build_tags.gd spaces it)."""
	return _name


func words() -> String:
	"""What its tag says (checks)."""
	return _name.text if visible else ""
