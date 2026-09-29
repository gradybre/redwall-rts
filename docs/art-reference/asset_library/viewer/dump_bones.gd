extends SceneTree
## Decision 0202's check that the pinned feet hold once Godot plays the clip: every GLB named in the job file
## is loaded through Godot's own glTF import, played by its AnimationPlayer, and every bone's global transform
## is written out at each of the clip's own key times. tools-side Python then skins the foot vertices with
## those transforms and measures the slide exactly as tools/ground_meshy_clips.py does.
## Headless. Args after --: <job.json> <out.json>
##   job.json: {"<res path>": [t0, t1, ...], ...}
##   out.json: {"<res path>": {"bones": [name, ...], "frames": [[12 floats per bone: basis x, y, z, origin], ...]}}

var _done: bool = false


func _process(_d: float) -> bool:
	if _done:
		return true
	_done = true
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var job: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var world := Node3D.new()
	root.add_child(world)
	var out: Dictionary = {}
	for path in job:
		out[path] = _dump(world, path, job[path])
	var f := FileAccess.open(args[1], FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	print("[dump_bones] %d clips" % out.size())
	quit()
	return true


func _dump(world: Node3D, path: String, times: Array) -> Dictionary:
	"""Every bone's global transform at each of `times`, as the imported clip plays."""
	var inst: Node3D = (load(path) as PackedScene).instantiate()
	world.add_child(inst)
	var p := inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var skel := inst.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var anim_name: StringName = p.get_animation_list()[0]
	p.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	p.play(anim_name)
	var names: Array[String] = []
	for b in skel.get_bone_count():
		names.append(skel.get_bone_name(b))
	var frames: Array = []
	for t in times:
		p.seek(float(t), true)
		var row: Array[float] = []
		for b in skel.get_bone_count():
			var g: Transform3D = skel.global_transform * skel.get_bone_global_pose(b)
			for v in [g.basis.x, g.basis.y, g.basis.z, g.origin]:
				row.append_array([v.x, v.y, v.z])
		frames.append(row)
	inst.queue_free()
	return {"bones": names, "frames": frames}
