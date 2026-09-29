extends SceneTree
## Before (left, grounded on master) and after (right, untwisted) idles of one creature, posed at the
## same clip times, seen from above and from the front. A yellow arrow on the ground under each points
## +Z: the way the creature walks. Must run windowed: headless Godot has no renderer.
## Args after --: <out_dir> <key> <height_m> <times comma-separated>
var _out: String
var _times: PackedFloat64Array = []
var _players: Array[AnimationPlayer] = []
var _names: Array[StringName] = []
var _top: Camera3D
var _front: Camera3D
var _step: int = -3

func _initialize() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	_out = a[0]
	var key: String = a[1]
	var h: float = float(a[2])
	for t in a[3].split(","): _times.append(float(t))
	var world := Node3D.new(); root.add_child(world)
	var gap: float = h * 0.75
	for i in 2:
		var side: String = ["before", "after"][i]
		var inst: Node3D = (load("res://glb/%s__%s.glb" % [key, side]) as PackedScene).instantiate()
		world.add_child(inst)
		inst.position.x = -gap if i == 0 else gap
		for n in inst.find_children("*", "MeshInstance3D", true, false):
			if (n as MeshInstance3D).name.begins_with("Icosphere"): (n as Node3D).visible = false
		var p := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
		p.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		_names.append(p.get_animation_list()[0]); p.play(_names[-1]); _players.append(p)
		var arrow := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(h * 0.03, 0.004, h * 0.55)
		var am := StandardMaterial3D.new(); am.albedo_color = Color(1.0, 0.8, 0.1); am.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bm.material = am; arrow.mesh = bm; arrow.position = Vector3(inst.position.x, 0.003, h * 0.275); world.add_child(arrow)
		var tip := MeshInstance3D.new(); var pm := PrismMesh.new(); pm.size = Vector3(h * 0.12, h * 0.1, 0.004); pm.material = am
		tip.mesh = pm; tip.rotation_degrees = Vector3(90, 0, 0); tip.position = Vector3(inst.position.x, 0.003, h * 0.6); world.add_child(tip)
		var label := Label3D.new(); label.text = "MASTER (Meshy idle)" if i == 0 else "UNTWISTED"
		label.font_size = 48; label.pixel_size = h * 0.0022; label.modulate = Color(0.1, 0.1, 0.12)
		label.rotation_degrees = Vector3(-90, 180, 0); label.position = Vector3(inst.position.x, 0.01, -h * 0.55); world.add_child(label)
	var g := MeshInstance3D.new(); var plane := PlaneMesh.new(); plane.size = Vector2(h * 8, h * 8)
	var gm := StandardMaterial3D.new(); gm.albedo_color = Color(0.36, 0.42, 0.28); plane.material = gm; g.mesh = plane; world.add_child(g)
	var sun := DirectionalLight3D.new(); sun.shadow_enabled = true; sun.light_energy = 1.2; sun.rotation_degrees = Vector3(-60, 30, 0); world.add_child(sun)
	var env := Environment.new(); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.62, 0.66, 0.72)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.8, 0.8, 0.85); env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new(); we.environment = env; world.add_child(we)
	_top = Camera3D.new(); _top.projection = Camera3D.PROJECTION_ORTHOGONAL; _top.size = h * 1.9; world.add_child(_top)
	## From above, screen-up is -Z: a creature facing +Z (its walk) faces the bottom of the frame.
	_top.look_at_from_position(Vector3(0, h * 5, h * 0.05), Vector3(0, 0, h * 0.05), Vector3(0, 0, -1))
	_front = Camera3D.new(); _front.fov = 32; world.add_child(_front)
	_front.look_at_from_position(Vector3(0, h * 1.3, h * 4.6), Vector3(0, h * 0.5, 0), Vector3.UP)

func _process(_d: float) -> bool:
	_step += 1
	if _step < 0:
		return false
	var shot: int = _step / 2
	if shot >= _times.size() * 2:
		quit(); return true
	var t: float = _times[shot / 2]
	var view: String = "top" if shot % 2 == 0 else "front"
	if _step % 2 == 0:
		for p in _players: p.seek(t, true)
		(_top if view == "top" else _front).current = true
	else:
		root.get_texture().get_image().save_png("%s/%s_%02d_t%.2f.png" % [_out, view, shot / 2, t])
	return false
