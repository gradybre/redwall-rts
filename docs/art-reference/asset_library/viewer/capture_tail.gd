extends SceneTree
## Before/after tail demo: repaired (no chain) beside tailed + SpringBoneSimulator3D.
const STEP: float = 1.0 / 24.0
var _out: String
var _frames: int
var _players: Array[AnimationPlayer] = []
var _skeletons: Array[Skeleton3D] = []
var _tick: int = 0
var _captured: int = 0
var _pending: Array = []
var UNIT_SCALED: bool = true
## Tail thickness in metres, so the spring keeps the tail's surface, not its axis, off the ground.
const RADIUS_M: Dictionary = {"mouse": 0.012, "squirrel": 0.07, "otter": 0.045}
const ORDER: Array[String] = ["mouse_keeper", "squirrel_gatherer", "otter_boatwright", "squirrel_forester"]
## Per-species spring feel: [stiffness, drag, gravity]. A squirrel carries its tail; a mouse's hangs.
## Spring feel per creature: [stiffness, drag, gravity m/s^2]. Mirrors tail_centrelines.json "spring".
const FEEL: Dictionary = {"mouse_keeper": [0.35, 0.35, 3.0], "squirrel_gatherer": [1.6, 0.45, 0.6],
	"otter_boatwright": [0.8, 0.5, 2.0], "squirrel_forester": [4.0, 0.55, 0.25]}

func _initialize() -> void:
	var a := OS.get_cmdline_user_args(); _out = a[0]; _frames = int(a[1])
	UNIT_SCALED = a.size() > 2 and a[2] == "local"
	var world := Node3D.new(); root.add_child(world)
	var x := 0.0
	var z := 0.0
	for k in ORDER:
		for side in ["before", "after"]:
			var inst: Node3D = (load("res://glb/tail/%s__%s.glb" % [k, side]) as PackedScene).instantiate()
			world.add_child(inst)
			inst.position = Vector3(0.0, 0.0, z)
			var label := Label3D.new(); label.text = "%s
%s" % [k, "BEFORE: no chain" if side == "before" else "AFTER: tail chain + spring"]
			label.font_size = 40; label.pixel_size = 0.004; label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.position = Vector3(0.0, -0.18, z); label.modulate = Color(0.08, 0.08, 0.1); world.add_child(label)
			z += 1.35 if side == "before" else 1.9
			var p := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
			var n: StringName = p.get_animation_list()[0]
			p.get_animation(n).loop_mode = Animation.LOOP_LINEAR
			p.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			p.play(n); _players.append(p)
			var sk := inst.find_child("*", true, false) as Node
			var skel := inst.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
			skel.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
			_skeletons.append(skel)
			if side == "after":
				_pending.append([skel, k])
			print("[tail] %s %s bones=%d" % [k, side, skel.get_bone_count()])
	_scene(world, z)

func _add_spring(skel: Skeleton3D, key: String) -> void:
	var species: String = key.get_slice("_", 0)
	## Built once the scene is live: the skeleton inherits the glTF armature's 0.01 scale, so
	## metres are converted into its local units rather than assumed.
	var f: Array = FEEL[key]
	var unit: float = 1.0 / skel.global_basis.get_scale().x
	var s := SpringBoneSimulator3D.new(); skel.add_child(s)
	s.set_setting_count(1)
	s.set_root_bone_name(0, "tail_00"); s.set_end_bone_name(0, "tail_07")
	s.set_extend_end_bone(0, true)
	s.set_end_bone_direction(0, SpringBoneSimulator3D.BONE_DIRECTION_FROM_PARENT)
	var seg: float = (skel.get_bone_global_rest(skel.find_bone("tail_07")).origin - skel.get_bone_global_rest(skel.find_bone("tail_06")).origin).length()
	s.set_end_bone_length(0, seg)
	s.set_stiffness(0, f[0]); s.set_drag(0, f[1]); s.set_gravity(0, f[2] * (unit if UNIT_SCALED else 1.0))
	s.set_gravity_direction(0, Vector3.DOWN)
	s.set_radius(0, RADIUS_M[species] * (unit if UNIT_SCALED else 1.0))
	var ground := SpringBoneCollisionPlane3D.new(); s.add_child(ground)
	ground.top_level = true; ground.global_position = Vector3(0.0, 0.0, skel.global_position.z)
	s.set_enable_all_child_collisions(0, true)
	print("[tail] spring on %s: skeleton scale %.4f, unit %.1f, radius %.3f m" % [species, skel.global_basis.get_scale().x, unit, RADIUS_M[species]])

func _scene(world: Node3D, span: float) -> void:
	var g := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(40, span + 12)
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(0.34, 0.40, 0.26); pm.material = mat
	g.mesh = pm; g.position = Vector3(0, 0, span * 0.5); world.add_child(g)
	var sun := DirectionalLight3D.new(); sun.shadow_enabled = true; sun.light_energy = 1.3
	sun.rotation_degrees = Vector3(-50, 150, 0); world.add_child(sun)
	var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.62, 0.66, 0.72)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.75, 0.78, 0.82); env.ambient_light_energy = 0.9
	var we := WorldEnvironment.new(); we.environment = env; world.add_child(we)
	var cam := Camera3D.new(); cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = (span + 0.6) * 560.0 / 1600.0; cam.far = 200
	world.add_child(cam)
	var target := Vector3(0, 0.55, span * 0.5 - 0.7)
	## From the side (+X), slightly raised: the row runs along Z and every tail shows in profile.
	cam.look_at_from_position(target + Vector3(1.0, 0.18, 0.0).normalized() * 40.0, target, Vector3.UP)
	cam.current = true

func _process(_d: float) -> bool:
	_tick += 1
	if _tick == 2:
		for pair in _pending: _add_spring(pair[0], pair[1])
	if _tick < 4:
		return false
	for p in _players: p.advance(STEP)
	for s in _skeletons: s.advance(STEP)
	if _tick >= 30:   # let the springs settle for ~1 s before recording
		root.get_texture().get_image().save_png("%s/f_%04d.png" % [_out, _captured]); _captured += 1
	if _captured >= _frames:
		print("[tail] captured %d" % _captured); quit()
	return false
