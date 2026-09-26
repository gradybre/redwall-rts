extends SceneTree
## Baked tails: the baked clip with NO spring (left) beside the unbaked clip (right).
## Anything the left tail does, it does because the motion is in the clip -- as the crowd plays it.
const STEP: float = 1.0 / 24.0
var _out: String
var _frames: int
var _players: Array[AnimationPlayer] = []
var _skeletons: Array[Skeleton3D] = []
var _tick: int = 0
var _captured: int = 0
## Arguments after --: <out_dir> <frames>. Inputs: res://glb/baked/<key>__before.glb (tailed/) and
## <key>__after.glb (baked/), one clip each. Must run windowed: headless Godot has no renderer.
const ORDER: Array[String] = ["mouse_keeper", "mouse_fieldworker", "otter_boatwright", "otter_fisher",
	"squirrel_gatherer", "squirrel_forester"]

func _initialize() -> void:
	var a := OS.get_cmdline_user_args(); _out = a[0]; _frames = int(a[1])
	var world := Node3D.new(); root.add_child(world)
	var z := 0.0
	for k in ORDER:
		for side in ["before", "after"]:
			var inst: Node3D = (load("res://glb/baked/%s__%s.glb" % [k, side]) as PackedScene).instantiate()
			world.add_child(inst)
			inst.position = Vector3(0.0, 0.0, z)
			var label := Label3D.new(); label.text = "%s\n%s" % [k, "UNBAKED" if side == "before" else "BAKED (no spring)"]
			label.font_size = 40; label.pixel_size = 0.004; label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.position = Vector3(0.0, 1.75, z); label.modulate = Color(0.08, 0.08, 0.1); world.add_child(label)
			z += 1.35 if side == "before" else 1.9
			var p := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
			var n: StringName = p.get_animation_list()[0]
			p.get_animation(n).loop_mode = Animation.LOOP_LINEAR
			p.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			p.play(n); _players.append(p)
			var skel := inst.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
			skel.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
			_skeletons.append(skel)
			print("[tail] %s %s bones=%d" % [k, side, skel.get_bone_count()])
	_scene(world, z)

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
	if _tick < 4:
		return false
	for p in _players: p.advance(STEP)
	for s in _skeletons: s.advance(STEP)
	if _tick >= 4:
		root.get_texture().get_image().save_png("%s/f_%04d.png" % [_out, _captured]); _captured += 1
	if _captured >= _frames:
		print("[tail] captured %d" % _captured); quit()
	return false
