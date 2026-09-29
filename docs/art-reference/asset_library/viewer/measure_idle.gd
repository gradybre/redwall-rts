extends SceneTree
## Plays each creature's idle (before = grounded on master, after = untwisted) through Godot's own
## glTF import and AnimationPlayer, and samples the Hips heading and the feet across the loop.
## Args after --: <keys comma-separated>
const STEP: float = 1.0 / 30.0

var _done: bool = false

func _process(_d: float) -> bool:
	if _done:
		return true
	_done = true
	_run()
	return true

func _run() -> void:
	var keys: PackedStringArray = OS.get_cmdline_user_args()[0].split(",")
	var world := Node3D.new(); root.add_child(world)
	for k in keys:
		var walk: Array = _measure(world, "res://glb/%s__walk.glb" % k)
		for side in ["before", "after"]:
			var m: Array = _measure(world, "res://glb/%s__%s.glb" % [k, side])
			print("[idle] %-18s %-6s heading mean %7.2f min %7.2f max %7.2f range %6.2f | feet slide L %.4f R %.4f | walk mean %.2f"
				% [k, side, m[0], m[1], m[2], m[2] - m[1], m[3], m[4], walk[0]])

func _measure(world: Node3D, path: String) -> Array:
	var inst: Node3D = (load(path) as PackedScene).instantiate()
	world.add_child(inst)
	var p := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var skel := inst.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var anim_name: StringName = p.get_animation_list()[0]
	var length: float = p.get_animation(anim_name).length
	p.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	p.play(anim_name)
	var hips: int = skel.find_bone("Hips")
	var feet: Array[int] = [skel.find_bone("LeftFoot"), skel.find_bone("RightFoot")]
	var rest: Basis = (skel.global_transform * skel.get_bone_global_rest(hips)).basis.orthonormalized()
	var headings: Array[float] = []
	var first: Array[Vector3] = []
	var slide: Array[float] = [0.0, 0.0]
	var t: float = 0.0
	while t <= length + 1e-4:
		p.seek(t, true)
		var g: Transform3D = skel.global_transform * skel.get_bone_global_pose(hips)
		var q: Quaternion = (g.basis.orthonormalized() * rest.inverse()).get_rotation_quaternion()
		var h: float = rad_to_deg(2.0 * atan2(q.y, q.w))
		if headings.size() > 0:
			h += 360.0 * roundf((headings[-1] - h) / 360.0)
		headings.append(h)
		for i in 2:
			var f: Vector3 = (skel.global_transform * skel.get_bone_global_pose(feet[i])).origin
			if first.size() < 2:
				first.append(f)
			slide[i] = maxf(slide[i], Vector2(f.x - first[i].x, f.z - first[i].z).length())
		t += STEP
	inst.queue_free()
	var total: float = 0.0
	for h in headings: total += h
	return [total / headings.size(), headings.min(), headings.max(), slide[0], slide[1]]
