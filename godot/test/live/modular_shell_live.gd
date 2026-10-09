extends SceneTree
## Bounded real-renderer gallery. Synthetic dimensions; no production construction is activated.
## godot --path godot --script res://test/live/modular_shell_live.gd -- --capture <directory>

const Shell := preload("res://demo/burrow/modular_shell.gd")
const Materials := preload("res://demo/burrow/modular_materials.gd")
const Footprint := preload("res://scripts/core/room_footprint.gd")
const SIZE: Vector2i = Vector2i(1280, 720)

var _world: Node3D = null
var _camera: Camera3D = null
var _ceilings: Array[MeshInstance3D] = []
var _builders: Array[Shell] = []
var _materials: Array[Materials] = []
var _labels: Array[Label] = []
var _groups: Array[Node3D] = []
var _centers: PackedVector3Array = PackedVector3Array()
var _frames: int = 0
var _checks: int = 0
var _failures: int = 0
var _capture_dir: String = ""
var _ready_gallery: bool = false


func _initialize() -> void:
	"""Use a fixed viewport, then build the scene after nodes can safely enter the tree."""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for at: int in range(args.size() - 1):
		if args[at] == "--capture":
			_capture_dir = args[at + 1]
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_size(SIZE)
	root.title = "Redwall RTS · canonical underground shell study"
	_setup.call_deferred()


func _setup() -> void:
	"""A deliberately separate material/geometry study, without loading or altering the live village."""
	_world = Node3D.new()
	root.add_child(_world)
	_environment()
	var shapes: Array[PackedInt32Array] = [Footprint.rectangle(0, 0, 6, 4, 256).cells,
		Footprint.combine(Footprint.rectangle(0, 0, 6, 4, 256).cells,
			Footprint.rectangle(3, 2, 3, 2, 256).cells, true, 256).cells,
		Footprint.rounded_rectangle(0, 0, 24, 16, 8, 1024).cells,
		Footprint.tunnel_path(PackedInt32Array([0, 0, 16, 0, 16, 12]), 4, 1024).cells,
		Footprint.rectangle(0, 0, 6, 4, 256).cells, Footprint.rectangle(0, 0, 6, 4, 256).cells]
	var names: Array[String] = ["Kitchen study", "Concave chamber", "Rounded burrow", "Bent passage",
		"Raised floor / lower ceiling", "Finished · cut · untouched"]
	var origins: Array[Vector2i] = [Vector2i(-13, -7), Vector2i(-3, -7), Vector2i(7, -7),
		Vector2i(-12, 4), Vector2i(-3, 3), Vector2i(7, 3)]
	for at: int in range(shapes.size()):
		_add_room(shapes[at], origins[at] * 1024, at, names[at])
	_overlay()
	_ready_gallery = true


func _environment() -> void:
	"""Neutral warm workshop light separates timber, earth and masonry without paid assets."""
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.075, 0.088, 0.074)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.75, 0.77, 0.68)
	environment.environment.ambient_light_energy = 0.72
	_world.add_child(environment)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-57, -24, 0)
	sun.light_color = Color(1.0, 0.92, 0.8)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	_world.add_child(sun)
	_camera = Camera3D.new()
	_world.add_child(_camera)
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 23.5
	_camera.position = Vector3(12, 28, 30)
	_camera.look_at(Vector3(0, 0, 0))
	_camera.current = true


func _add_room(cells: PackedInt32Array, origin_u: Vector2i, index: int, label_text: String) -> void:
	"""Render the supplied stages and explicit openings; no objects are automatically furnished."""
	var spec: Dictionary = _spec(cells, origin_u, index)
	var builder: Shell = Shell.new()
	_builders.append(builder)
	var result: Dictionary = builder.rebuild(1, spec)
	_check("room %d builds" % index, result.ok)
	if not result.ok:
		return
	var materials: Materials = Materials.new()
	_materials.append(materials)
	var selected: PackedInt32Array = PackedInt32Array([2, 2, 1] if index == 0 else [1, 0, 1])
	if index == 3 or index == 5:
		selected = PackedInt32Array([0, 0, 0])
	materials.set_finishes(selected[0], selected[1], selected[2])
	_check("room %d materials" % index, materials.apply(result))
	var group: Node3D = Node3D.new()
	_world.add_child(group)
	_groups.append(group)
	_install_meshes(result, group)
	_outline(spec, group)
	_check("room %d cached" % index, builder.rebuild(1, spec).floor_mesh == result.floor_mesh)
	_check("room %d idle rebuild count" % index, builder.build_count == 1)
	_centers.append(Vector3(float(origin_u.x) / 1024.0 + 3.0, 0.0, float(origin_u.y) / 1024.0 + 5.0))
	_add_label(label_text)


func _add_label(label_text: String) -> void:
	"""Keep a separate presentation label for each gallery specimen."""
	var label: Label = Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", Color(0.9, 0.86, 0.72))
	label.add_theme_color_override("font_shadow_color", Color(0.03, 0.04, 0.03))
	root.add_child(label)
	_labels.append(label)


func _spec(cells: PackedInt32Array, origin_u: Vector2i, index: int) -> Dictionary:
	"""Explicit synthetic geometry and stage inputs, including a deliberate upper-level aperture."""
	@warning_ignore("integer_division") var count: int = cells.size() / 2
	var floor_u: PackedInt32Array = PackedInt32Array()
	var ceiling_u: PackedInt32Array = PackedInt32Array()
	var state: PackedByteArray = PackedByteArray()
	var ceiling_open: PackedByteArray = PackedByteArray()
	floor_u.resize(count)
	ceiling_u.resize(count)
	ceiling_u.fill(2048)
	state.resize(count)
	state.fill(Shell.FINISHED)
	ceiling_open.resize(count)
	for row: int in range(count):
		if index == 4 and cells[row * 2] >= 3:
			floor_u[row] = 512
			ceiling_u[row] = 1792
		if index == 5:
			state[row] = Shell.FINISHED if cells[row * 2] >= 4 else (Shell.CUT if cells[row * 2] == 3 else Shell.SOLID)
		if index == 0 and cells[row * 2] == 3 and cells[row * 2 + 1] == 1:
			ceiling_open[row] = 1
	var opening: PackedInt32Array = PackedInt32Array([0, 0, Footprint.NORTH, 0, 1536]) if index < 2 else PackedInt32Array()
	return {"cells": cells, "floor_u": floor_u, "ceiling_u": ceiling_u, "state": state,
		"origin_u": origin_u, "cell_size_u": 256 if index == 2 or index == 3 else 1024, "minimum_headroom_u": 1024,
		"openings": opening, "ceiling_open": ceiling_open}


func _install_meshes(result: Dictionary, group: Node3D) -> void:
	"""Install category meshes at identity: their positions and UVs already use fixed world coordinates."""
	for key: String in Shell.MESH_KEYS:
		var mesh: MeshInstance3D = MeshInstance3D.new()
		mesh.mesh = result[key]
		group.add_child(mesh)
		if key == "ceiling_mesh":
			mesh.visible = false
			_ceilings.append(mesh)


func _outline(spec: Dictionary, group: Node3D) -> void:
	"""A thin plan silhouette includes untouched cells but creates no filled floor there."""
	var lines: ImmediateMesh = ImmediateMesh.new()
	lines.surface_begin(Mesh.PRIMITIVE_LINES)
	var loops: Array[PackedInt32Array] = Footprint.boundary_loops(spec.cells)
	for loop: PackedInt32Array in loops:
		for at: int in range(0, loop.size() - 2, 2):
			for offset: int in [0, 2]:
				lines.surface_add_vertex(Vector3(float(spec.origin_u.x + loop[at + offset] * spec.cell_size_u) / 1024.0,
					0.025, float(spec.origin_u.y + loop[at + offset + 1] * spec.cell_size_u) / 1024.0))
	lines.surface_end()
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = lines
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.46, 0.59, 0.57)
	node.material_override = material
	group.add_child(node)


func _overlay() -> void:
	"""Keep the study's title and evidence limits legible at the real 1280 by 720 viewport."""
	_overlay_backdrop(Vector2.ZERO, Vector2(1280, 90))
	_overlay_backdrop(Vector2(0, 649), Vector2(1280, 71))
	var title: Label = Label.new()
	title.position = Vector2(32, 18)
	title.text = "Underground rooms · fitted shell study"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.96, 0.91, 0.77))
	root.add_child(title)
	var subtitle: Label = Label.new()
	subtitle.position = Vector2(34, 59)
	subtitle.text = "Earth, worn timber and warm stone · exact footprints · whole-surface finishes"
	subtitle.add_theme_font_size_override("font_size", 17)
	subtitle.add_theme_color_override("font_color", Color(0.65, 0.72, 0.65))
	root.add_child(subtitle)
	var note: Label = Label.new()
	note.position = Vector2(34, 667)
	note.text = "Renderer study, not a playable build · synthetic dimensions · procedural materials · no staged art assets"
	note.add_theme_font_size_override("font_size", 15)
	note.add_theme_color_override("font_color", Color(0.62, 0.68, 0.61))
	root.add_child(note)


func _overlay_backdrop(at: Vector2, size_px: Vector2) -> void:
	"""Keep close-up geometry behind readable study captions without altering the world."""
	var backdrop: ColorRect = ColorRect.new()
	backdrop.position = at
	backdrop.size = size_px
	backdrop.color = Color(0.075, 0.088, 0.074)
	root.add_child(backdrop)


func _process(_delta: float) -> bool:
	"""Capture three actual rendered views, then stop without leaving a game process running."""
	if root.size != SIZE:
		root.size = SIZE
	if not _ready_gallery:
		return false
	_frames += 1
	_place_labels()
	if _frames == 24:
		_capture("01-gallery-cutaway")
		for ceiling: MeshInstance3D in _ceilings:
			ceiling.visible = true
	elif _frames == 48:
		_capture("02-ceilings-and-aperture")
		for ceiling: MeshInstance3D in _ceilings:
			ceiling.visible = false
		for at: int in range(_groups.size()):
			_groups[at].visible = at == 4
		_camera.size = 8.5
		_camera.position = Vector3(-7, 10, 15)
		_camera.look_at(Vector3(0, 0, 5))
	elif _frames == 72:
		_capture("03-height-join-close")
	elif _frames >= 76:
		print("SHELL-LIVE-SUMMARY %d %d" % [_checks, _failures])
		quit(0 if _failures == 0 else 1)
	return false


func _place_labels() -> void:
	"""Project labels onto the gallery without affecting room geometry or shell revisions."""
	for at: int in range(_labels.size()):
		_labels[at].visible = _frames < 48
		_labels[at].position = _camera.unproject_position(_centers[at]) - Vector2(145, 0)
		_labels[at].size = Vector2(290, 26)


func _capture(name: String) -> void:
	"""Write native pixels only; headless runs explicitly provide no screenshot evidence."""
	_check("viewport 1280x720", root.size == SIZE)
	if _capture_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(_capture_dir)
	var picture: Image = root.get_texture().get_image()
	_check("capture resolution", picture.get_size() == SIZE)
	_check("capture saved", picture.save_png(_capture_dir.path_join(name + ".png")) == OK)
	print("SHELL-CAPTURE " + _capture_dir.path_join(name + ".png"))


func _check(label: String, passed: bool) -> void:
	"""Record explicit live checks independently of process exit status."""
	_checks += 1
	_failures += 0 if passed else 1
	print("SHELL-LIVE %s: %s" % [label, "PASS" if passed else "FAIL"])
