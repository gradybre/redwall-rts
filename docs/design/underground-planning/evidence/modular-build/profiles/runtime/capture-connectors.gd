extends SceneTree
## Native 1280x720 renderer evidence for decision 1070. SYNTHETIC dimensions and checker materials.
## Run without --headless: godot --path godot --rendering-method gl_compatibility --resolution 1280x720
## --script ../docs/design/underground-planning/evidence/modular-build/profiles/runtime/capture-connectors.gd -- <out.png> <out.json>

const Geometry := preload("res://scripts/core/connector_geometry.gd")
const Connectors := preload("res://scripts/core/room_connectors.gd")
const View := preload("res://demo/burrow/connector_view.gd")
const Fixtures := preload("res://test/test_connector_geometry.gd")
const LABELS: PackedStringArray = ["Earth / timber", "Stone stairs", "Sloping passage", "Spiral treads", "Ladder + hatch"]

var _image_path: String = ""
var _report_path: String = ""
var _world: Node3D = null
var _ui: Control = null
var _frame: int = 0
var _cases: Array = []


func _initialize() -> void:
	"""Require a real renderer so a dummy headless texture cannot count as a visible capture."""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2 or RenderingServer.get_current_rendering_driver_name() == "dummy":
		printerr("connector capture requires a native renderer and PNG/JSON output paths")
		quit(2)
		return
	_image_path = args[0]
	_report_path = args[1]
	call_deferred("_boot")


func _boot() -> void:
	"""Draw the five actual compiled families under back-face culling at an actual 1280x720 viewport."""
	root.size = Vector2i(1280, 720)
	_world = Node3D.new()
	root.add_child(_world)
	_lighting()
	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 14.0
	_world.add_child(camera)
	camera.look_at_from_position(Vector3(8, 12, 14), Vector3(0, 0.5, 0), Vector3.UP)
	camera.current = true
	var places: Array[Vector3i] = [Vector3i(-4608, 0, -2048), Vector3i(-1024, 0, -2048),
		Vector3i(2560, 0, -2048), Vector3i(-3072, 0, 2560), Vector3i(2560, 0, 2560)]
	for family: int in Connectors.FAMILY_COUNT:
		_add_connector(family, places[family])
	_ui = Control.new()
	root.add_child(_ui)
	_label("Fixed connector surfaces · native renderer", Vector2(28, 20), 25)
	_label("Synthetic geometry and checker materials — no production sizes or traversal permissions", Vector2(28, 54), 15)
	_label("BACK culling · metre-scale UVs · complete quarter-turn hatch envelope", Vector2(28, 680), 16)


func _lighting() -> void:
	"""Neutral technical look-development lighting; no new production art direction or material palette."""
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.065, 0.078, 0.072)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.82, 0.87, 0.89)
	environment.ambient_light_energy = 0.65
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.environment = environment
	_world.add_child(world_environment)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -30, 0)
	light.light_energy = 1.1
	_world.add_child(light)
	var floor_mesh: PlaneMesh = PlaneMesh.new()
	floor_mesh.size = Vector2(20, 13)
	var floor_node: MeshInstance3D = MeshInstance3D.new()
	floor_node.mesh = floor_mesh
	floor_node.position.y = -0.3
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.18, 0.205, 0.18)
	floor_node.material_override = material
	_world.add_child(floor_node)


func _add_connector(family: int, origin: Vector3i) -> void:
	"""Use the reviewed fixture compiler/view, with additional explicit fixture steps for legibility."""
	var row: Geometry.Row = Fixtures.fixture(family)
	if family in [Connectors.EARTH_TIMBER, Connectors.STONE]:
		for step: int in range(1, 4):
			Fixtures._box(row.parts, Geometry.TREAD, Vector3i(-512, (step + 1) * 256, step * 512),
				Vector3i(512, (step + 1) * 256, (step + 1) * 512), 128)
	var result: Geometry.Result = Geometry.compile(row, Fixtures.limits())
	assert(result.ok, String(result.error))
	var view: View = View.new()
	assert(view.configure(result.compiled, _materials(family)) == &"", "actual view configuration")
	_world.add_child(view)
	assert(view.set_fixed_placement(origin, 0), "fixed origin")
	if family == Connectors.LADDER_HATCH:
		assert(view.set_hatch_fraction(0.65), "raised real hatch")
	var label: Label3D = Label3D.new()
	label.text = LABELS[family]
	label.position = Vector3(origin) / 1024.0 + Vector3(0, 2.15, 0.3)
	label.font_size = 42
	label.pixel_size = 0.005
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_world.add_child(label)
	_cases.append({"family": LABELS[family], "parts": row.parts.kind.size(),
		"triangles": result.compiled.triangle_material.size(), "production_qualified": false})


func _materials(family: int) -> Array[Material]:
	"""Checker repetition makes physical scale and boundary clipping visible in the captured pixels."""
	var colors: Array[Color] = [Color(0.53, 0.33, 0.17), Color(0.50, 0.53, 0.49),
		Color(0.53, 0.40, 0.22), Color(0.62, 0.44, 0.27), Color(0.61, 0.39, 0.18)]
	var picture: Image = Image.create(32, 32, false, Image.FORMAT_RGB8)
	for y: int in 32:
		for x: int in 32:
			picture.set_pixel(x, y, colors[family] if (x < 16) == (y < 16) else colors[family].lightened(0.18))
	var top: StandardMaterial3D = StandardMaterial3D.new()
	top.albedo_texture = ImageTexture.create_from_image(picture)
	top.roughness = 0.88
	var side: StandardMaterial3D = top.duplicate() as StandardMaterial3D
	side.albedo_color = Color(0.70, 0.65, 0.58)
	return [top, side]


func _label(text: String, at: Vector2, size: int) -> void:
	"""Keep technical qualification labeling inside the screenshot itself."""
	var label: Label = Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.91, 0.92, 0.86))
	_ui.add_child(label)


func _process(_delta: float) -> bool:
	"""Wait for actual drawn frames, then capture and free the native scene."""
	if _world == null:
		return false
	_frame += 1
	if _frame == 45:
		var picture: Image = root.get_texture().get_image()
		var code: Error = picture.save_png(_image_path)
		var output: FileAccess = FileAccess.open(_report_path, FileAccess.WRITE)
		output.store_string(JSON.stringify({"engine": Engine.get_version_info(), "renderer": RenderingServer.get_current_rendering_driver_name(),
			"size": [picture.get_width(), picture.get_height()], "families": _cases,
			"image_sha256": FileAccess.get_sha256(_image_path), "save_error": code, "production_qualified": false}, "  ") + "\n")
		output.close()
		_world.free()
		_world = null
		_ui.free()
		print("connector capture: 5 synthetic families, %dx%d, save %d" % [picture.get_width(), picture.get_height(), code])
		quit(0 if code == OK else 2)
	return false
