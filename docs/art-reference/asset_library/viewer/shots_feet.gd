extends SceneTree
## Decision 0202's contact sheets: the same clip before (left, grounded on the branch it builds on) and after
## its planted feet are pinned (right), posed at the same key times: both from above, then each close up from
## behind and to one side, where a kneeling creature's feet are. An in-place
## gait is carried forward at its recorded ground speed, and a travelling clip along its recorded root path,
## as the game plays them, so a planted foot should stand still on the ground grid. On the ground: a white trail
## of each foot's contact point over the whole clip, and, for each foot planted at that key, a red disc where
## its contact began. A foot on its disc holds; one away from it has slid.
## Must run windowed: headless Godot has no renderer.
## Args after --: <out_dir> <plan.json>
##   plan.json: {"height_m", "times": [t...], "keys": [k...], "sides": {"before"|"after": {"glb": res path,
##               "offset": [[x, z] per clip key], "trail": {side: [[x, z]...]}, "discs": [[[x, z]...] per shot]}}}
var _out: String
var _plan: Dictionary
var _players: Array[AnimationPlayer] = []
var _roots: Array[Node3D] = []
var _discs: Array[Node3D] = []
var _top: Camera3D
var _front: Camera3D
var _step: int = -3


func _initialize() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	_out = a[0]
	_plan = JSON.parse_string(FileAccess.get_file_as_string(a[1]))
	var h: float = float(_plan["height_m"])
	var world := Node3D.new()
	root.add_child(world)
	var gap: float = h * 0.8
	var white := _material(Color(1, 1, 1))
	for i in 2:
		var tag: String = ["before", "after"][i]
		var side: Dictionary = _plan["sides"][tag]
		var holder := Node3D.new()
		holder.position.x = -gap if i == 0 else gap
		world.add_child(holder)
		var inst: Node3D = (load(side["glb"]) as PackedScene).instantiate()
		holder.add_child(inst)
		_roots.append(inst)
		var p := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
		p.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		p.play(p.get_animation_list()[0])
		_players.append(p)
		for trail in (side["trail"] as Dictionary).values():
			holder.add_child(_strip(trail, white, h))
		var discs := Node3D.new()
		holder.add_child(discs)
		_discs.append(discs)
		var label := Label3D.new()
		label.text = "BEFORE (0201)" if i == 0 else "PINNED (0202)"
		label.font_size = 48; label.pixel_size = h * 0.0022; label.modulate = Color(0.1, 0.1, 0.12)
		label.rotation_degrees = Vector3(-90, 0, 0); label.position = Vector3(0, 0.01, h * 0.75)
		holder.add_child(label)
	var g := MeshInstance3D.new()
	var plane := PlaneMesh.new(); plane.size = Vector2(h * 10, h * 10)
	var gm := StandardMaterial3D.new(); gm.albedo_texture = _grid(); gm.uv1_scale = Vector3(h * 10 / 0.1, h * 10 / 0.1, 1)
	gm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	plane.material = gm; g.mesh = plane; world.add_child(g)
	var sun := DirectionalLight3D.new(); sun.light_energy = 1.1; sun.rotation_degrees = Vector3(-60, 30, 0); world.add_child(sun)
	var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.62, 0.66, 0.72)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.85, 0.85, 0.9); env.ambient_light_energy = 0.9
	var we := WorldEnvironment.new(); we.environment = env; world.add_child(we)
	_top = Camera3D.new(); _top.projection = Camera3D.PROJECTION_ORTHOGONAL; _top.size = h * 2.2; world.add_child(_top)
	_front = Camera3D.new(); _front.fov = 30; world.add_child(_front)


func _material(c: Color) -> StandardMaterial3D:
	"""An unshaded flat colour."""
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _grid() -> ImageTexture:
	"""A 10 cm ground tile: grass green with a darker line on two edges."""
	var img := Image.create(32, 32, false, Image.FORMAT_RGB8)
	img.fill(Color(0.42, 0.5, 0.33))
	for i in 32:
		img.set_pixel(i, 0, Color(0.25, 0.3, 0.2)); img.set_pixel(0, i, Color(0.25, 0.3, 0.2))
	return ImageTexture.create_from_image(img)


func _strip(points: Array, mat: Material, h: float) -> MeshInstance3D:
	"""Thin boxes joining consecutive ground points, 2 mm up."""
	var node := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, mat)
	var w: float = h * 0.004
	for i in range(points.size() - 1):
		var a := Vector3(points[i][0], 0.002, points[i][1]); var b := Vector3(points[i + 1][0], 0.002, points[i + 1][1])
		var d := b - a
		if d.length() < 1e-6:
			continue
		var n := Vector3(-d.z, 0, d.x).normalized() * w
		for v in [a - n, a + n, b + n, a - n, b + n, b - n]:
			im.surface_add_vertex(v)
	im.surface_end()
	node.mesh = im
	return node


const VIEWS: Array[String] = ["top", "rear_before", "rear_after"]


func _process(_d: float) -> bool:
	_step += 1
	if _step < 0:
		return false
	var shot: int = _step / 2
	var times: Array = _plan["times"]
	if shot >= times.size() * VIEWS.size():
		quit()
		return true
	var index: int = shot / VIEWS.size()
	var view: String = VIEWS[shot % VIEWS.size()]
	if _step % 2 == 0:
		_pose(index)
		var h: float = float(_plan["height_m"])
		if view == "top":
			var centre: Vector3 = (_roots[0].global_position + _roots[1].global_position) * 0.5
			_top.look_at_from_position(centre + Vector3(0, h * 5, 0.001), centre, Vector3(0, 0, -1))
			_top.current = true
		else:
			var at: Vector3 = _roots[0 if view == "rear_before" else 1].global_position
			_front.look_at_from_position(at + Vector3(h * 0.35, h * 0.45, -h * 1.5), at + Vector3(0, h * 0.05, 0), Vector3.UP)
			_front.current = true
	else:
		root.get_texture().get_image().save_png("%s/%02d_%s.png" % [_out, index, view])
	return false


func _pose(index: int) -> void:
	"""Pose both at the shot's time, carried along the ground as the game would, and lay that shot's discs."""
	var t: float = float(_plan["times"][index])
	var key: int = int(_plan["keys"][index])
	var red := _material(Color(1.0, 0.15, 0.05))
	for i in 2:
		var side: Dictionary = _plan["sides"][["before", "after"][i]]
		_players[i].seek(t, true)
		var o: Array = side["offset"][key]
		_roots[i].position = Vector3(o[0], 0, o[1])
		for c in _discs[i].get_children():
			c.queue_free()
		for d in side["discs"][index]:
			var disc := MeshInstance3D.new()
			var cm := CylinderMesh.new(); cm.top_radius = float(_plan["height_m"]) * 0.03; cm.bottom_radius = cm.top_radius
			cm.height = 0.003; cm.material = red; disc.mesh = cm
			disc.position = Vector3(d[0], 0.0015, d[1])
			_discs[i].add_child(disc)
