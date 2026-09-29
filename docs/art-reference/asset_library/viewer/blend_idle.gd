extends SceneTree
## idle (1 s) -> walk (0.3 s crossfade, 2 s) -> idle (0.3 s crossfade, 1 s), played through one
## AnimationPlayer at 60 Hz as the skeletal pool would. Prints the Hips heading range over the whole
## sequence, and the largest heading change and horizontal hips move within any 0.3 s blend.
## Args after --: <keys comma-separated>
const STEP: float = 1.0 / 60.0
var _done: bool = false

func _process(_d: float) -> bool:
	if _done: return true
	_done = true
	var world := Node3D.new(); root.add_child(world)
	for k in OS.get_cmdline_user_args()[0].split(","):
		for side in ["before", "after"]:
			_run(world, k, side)
	return true

func _run(world: Node3D, k: String, side: String) -> void:
	var inst: Node3D = (load("res://glb/%s__%s.glb" % [k, side]) as PackedScene).instantiate()
	world.add_child(inst)
	var walk_scene: Node3D = (load("res://glb/%s__walk.glb" % k) as PackedScene).instantiate()
	var wp := walk_scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var walk: Animation = wp.get_animation(wp.get_animation_list()[0]).duplicate()
	walk_scene.free()
	var p := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var idle_name: StringName = p.get_animation_list()[0]
	p.get_animation(idle_name).loop_mode = Animation.LOOP_LINEAR
	walk.loop_mode = Animation.LOOP_LINEAR
	var lib := AnimationLibrary.new(); lib.add_animation("walk", walk); p.add_animation_library("x", lib)
	p.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var skel := inst.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var hips: int = skel.find_bone("Hips")
	var rest: Basis = skel.get_bone_global_rest(hips).basis.orthonormalized()
	var hs: Array[float] = []
	var xs: Array[Vector2] = []
	p.play(idle_name)
	for f in 360:
		if f == 60: p.play("x/walk", 0.3)
		if f == 240: p.play(idle_name, 0.3)
		p.advance(STEP)
		var g: Transform3D = skel.get_bone_global_pose(hips)
		var q: Quaternion = (g.basis.orthonormalized() * rest.inverse()).get_rotation_quaternion()
		var h: float = rad_to_deg(2.0 * atan2(q.y, q.w))
		if hs.size() > 0: h += 360.0 * roundf((hs[-1] - h) / 360.0)
		hs.append(h); xs.append(Vector2(g.origin.x, g.origin.z))
	var turn_in: float = absf(hs[78] - hs[59]); var turn_out: float = absf(hs[258] - hs[239])
	var move_in: float = (xs[78] - xs[59]).length(); var move_out: float = (xs[258] - xs[239]).length()
	print("[blend] %-18s %-6s heading over sequence %7.2f..%7.2f | idle->walk blend turns %5.1f deg, hips move %.3f m | walk->idle turns %5.1f deg, hips move %.3f m"
		% [k, side, hs.min(), hs.max(), turn_in, move_in, turn_out, move_out])
	inst.queue_free()
