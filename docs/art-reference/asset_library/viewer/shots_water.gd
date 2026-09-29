extends SceneTree
## Windowed: render each shot of plan.json to <out>/<name>.png. A shot: {name, glb, t, view: side|front,
## size (ortho metres), cy (camera target y), water: bool, others: [{glb, x}] }. The main glb sits at x 0.
var _plan: Array
var _out: String
var _i: int = -1
var _wait: int = 0
var _world: Node3D
var _cam: Camera3D

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	_out = a[0]
	_plan = JSON.parse_string(FileAccess.get_file_as_string(a[1]))
	root.size = Vector2i(900, 900)

func _process(_d: float) -> bool:
	if _wait > 0:
		_wait -= 1
		if _wait == 0:
			root.get_texture().get_image().save_png("%s/%s.png" % [_out, _plan[_i]["name"]])
		return false
	_i += 1
	if _i >= _plan.size():
		quit(); return true
	_build(_plan[_i])
	_wait = 4
	return false

func _pose(f: String, t: float, x: float) -> void:
	var inst: Node3D = (load("res://glb/" + f) as PackedScene).instantiate()
	_world.add_child(inst)
	inst.position.x = x
	for n in inst.find_children("*", "MeshInstance3D", true, false):
		if (n as Node).name.begins_with("Icosphere"): (n as Node3D).visible = false
	var p := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if p:
		p.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		p.play(p.get_animation_list()[0]); p.seek(t, true)

func _box(size: Vector3, pos: Vector3, color: Color) -> void:
	var m := MeshInstance3D.new(); var b := BoxMesh.new(); b.size = size
	var mat := StandardMaterial3D.new(); mat.albedo_color = color; mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 1.0: mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	b.material = mat; m.mesh = b; m.position = pos; _world.add_child(m)

func _build(s: Dictionary) -> void:
	if _world: _world.queue_free()
	_world = Node3D.new(); root.add_child(_world)
	var sun := DirectionalLight3D.new(); sun.light_energy = 1.3; sun.rotation_degrees = Vector3(-50, 40, 0); _world.add_child(sun)
	var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.80, 0.83, 0.87)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.85, 0.85, 0.9); env.ambient_light_energy = 0.9
	var we := WorldEnvironment.new(); we.environment = env; _world.add_child(we)
	_pose(s["glb"], float(s.get("t", 0.0)), 0.0)
	for o in s.get("others", []): _pose(o["glb"], float(o.get("t", 0.0)), float(o["x"]))
	var side: bool = s.get("view", "side") == "side"
	if s.get("water", false):
		## the water: a translucent slab between the camera and the creature, and an opaque line at y = 0 behind it
		if side:
			_box(Vector3(0.02, 6.0, 12.0), Vector3(3.0, -3.0, 0.0), Color(0.15, 0.45, 0.75, 0.40))
			_box(Vector3(0.02, 0.012, 12.0), Vector3(-3.0, 0.0, 0.0), Color(0.05, 0.2, 0.55, 1.0))
		else:
			_box(Vector3(12.0, 6.0, 0.02), Vector3(0.0, -3.0, 3.0), Color(0.15, 0.45, 0.75, 0.40))
			_box(Vector3(12.0, 0.012, 0.02), Vector3(0.0, 0.0, -3.0), Color(0.05, 0.2, 0.55, 1.0))
	else:
		_box(Vector3(12.0, 0.02, 12.0), Vector3(0.0, -0.01, 0.0), Color(0.36, 0.42, 0.28, 1.0))
		for h in s.get("rules", []):   # height marks: thin red lines across the frame, behind
			_box(Vector3(12.0, 0.006, 0.02), Vector3(0.0, float(h), -3.0), Color(0.8, 0.1, 0.1, 1.0))
	_cam = Camera3D.new(); _cam.projection = Camera3D.PROJECTION_ORTHOGONAL; _cam.size = float(s["size"]); _world.add_child(_cam)
	var cy := float(s["cy"]); var cx := float(s.get("cx", 0.0))
	if side: _cam.look_at_from_position(Vector3(10, cy, cx), Vector3(0, cy, cx), Vector3.UP)
	else: _cam.look_at_from_position(Vector3(cx, cy, 10), Vector3(cx, cy, 0), Vector3.UP)
	_cam.current = true
