extends SceneTree
## Scratch viewer: import animated GLBs as the game would, play each clip, record frames.
## Args after --: <out_dir> <walk|clips> <frames>
const STEP: float = 1.0 / 24.0
var _out: String = ""
var _mode: String = "walk"
var _frames: int = 25
var _players: Array[AnimationPlayer] = []
var _tick: int = 0
var _captured: int = 0
var _labels: Array[String] = []
var _fixmat: bool = false

func _initialize() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	_out = a[0]; _mode = a[1]; _frames = int(a[2])
	_fixmat = a.size() > 3 and a[3] == "fixmat"
	var world := Node3D.new(); root.add_child(world)
	var files: PackedStringArray = DirAccess.get_files_at("res://glb/%s" % _mode)
	var names: Array[String] = []
	for f in files:
		if f.ends_with(".glb"): names.append(f)
	if _mode == "walk":
		names = ["mole_digger.glb","mole_mason.glb","mouse_keeper.glb","mouse_fieldworker.glb",
			"squirrel_forester.glb","squirrel_gatherer.glb","otter_fisher.glb","otter_boatwright.glb",
			"badger_cellarer.glb","badger_quarryman.glb"]
	else:
		names = ["idle.glb","walk.glb","run.glb","carry_heavy_object_walk.glb","carry_water_bucket_walk.glb",
			"collect_object.glb","pull_radish.glb","wave_one_hand.glb","stand_and_drink.glb","chair_sit_idle.glb"]
	var x: float = 0.0
	var tallest: float = 0.0
	for n in names:
		var inst: Node3D = (load("res://glb/%s/%s" % [_mode, n]) as PackedScene).instantiate()
		world.add_child(inst)
		_strip_icospheres(inst)
		if _fixmat:
			_repair_materials(inst)
		var box: AABB = _mesh_aabb(inst)
		if _mode == "walk":
			## DEC-039 height by species. Meshy's rig scaled the LONGEST rest-pose dimension to
			## height_meters, so a model wider than tall in T-pose came out short. Correct it here
			## by the measured factor so the lineup is true; the files are not changed.
			var target: float = {"mole": 0.90, "mouse": 1.00, "squirrel": 1.15, "otter": 1.49,
				"badger": 2.55}[n.get_slice("_", 0)]
			var k: float = target / box.size.y
			if absf(k - 1.0) > 0.01:
				print("[viewer] %s rest height %.3f m, rescaled x%.3f to %.2f m" % [n, box.size.y, k, target])
			inst.scale = Vector3.ONE * k
			box = AABB(box.position * k, box.size * k)
		var w: float = max(box.size.x, 0.5) if _mode == "walk" else 1.0
		tallest = max(tallest, box.size.y)
		inst.position.x = x + w * 0.5
		x += w + (0.35 if _mode == "walk" else 0.35)
		var p: AnimationPlayer = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var anim_name: StringName = p.get_animation_list()[0]
		p.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
		p.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		p.play(anim_name)
		_players.append(p)
		print("[viewer] %s anim=%s len=%.2fs aabb=%s" % [n, anim_name, p.get_animation(anim_name).length, box])
	var span: float = x - 0.35
	_ground(world, span)
	_light(world)
	_camera(world, span, tallest)

func _strip_icospheres(n: Node) -> void:
	for c in n.find_children("*", "", true, false):
		if not String(c.name).to_lower().begins_with("icosphere"):
			continue
		print("[viewer] removed stray node: %s" % c.name)
		c.get_parent().remove_child(c); c.free()

func _repair_materials(n: Node) -> void:
	## The Meshy rig step exports metallic 1.0 (glTF default), the colour map doubled as full
	## emission, and specular x2. Put back what the L0 carries: dielectric, rough cloth, no glow.
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i).duplicate() as BaseMaterial3D
			print("[viewer] before: metallic=%.2f roughness=%.2f emission=%s specular=%.2f" % [mat.metallic, mat.roughness, mat.emission_enabled, mat.metallic_specular])
			mat.metallic = 0.0
			mat.roughness = 0.93
			mat.emission_enabled = false
			mat.metallic_specular = 0.5
			mi.set_surface_override_material(i, mat)

func _mesh_aabb(n: Node) -> AABB:
	var box := AABB(); var first := true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var b: AABB = mi.get_aabb()
		if first: box = b; first = false
		else: box = box.merge(b)
	return box

func _ground(world: Node3D, span: float) -> void:
	var g := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(span + 12.0, 80.0)
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(0.34, 0.40, 0.26); pm.material = mat
	g.mesh = pm; g.position = Vector3(span * 0.5, 0.0, 0.0); world.add_child(g)

func _light(world: Node3D) -> void:
	var sun := DirectionalLight3D.new(); sun.shadow_enabled = true; sun.light_energy = 1.3
	sun.rotation_degrees = Vector3(-50.0, 35.0, 0.0); world.add_child(sun)
	var env := Environment.new(); env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.66, 0.72); env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.82); env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new(); we.environment = env; world.add_child(we)

func _camera(world: Node3D, span: float, tallest: float) -> void:
	## glTF's front is +Z. The camera stands on +Z looking toward -Z, so a model that faces its
	## glTF front shows its face. The project's convention is -Z forward; see the report.
	var cam := Camera3D.new(); cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = (span + 1.6) * 560.0 / 1280.0
	cam.far = 200.0
	world.add_child(cam)
	var target := Vector3(span * 0.5, tallest * 0.45, 0.0)
	var el: float = deg_to_rad(12.0)
	cam.look_at_from_position(target + Vector3(0.0, sin(el), cos(el)) * 40.0, target, Vector3.UP)
	cam.current = true

func _process(_d: float) -> bool:
	_tick += 1
	if _tick < 6:
		return false            # let the renderer settle
	if _captured > 0 or _tick > 6:
		var img: Image = root.get_texture().get_image()
		img.save_png("%s/f_%04d.png" % [_out, _captured])
		_captured += 1
	for p in _players:
		p.advance(STEP)
	if _captured >= _frames:
		print("[viewer] captured %d frames" % _captured)
		quit()
	return false
