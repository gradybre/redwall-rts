extends SceneTree
## Headless checks on the imported GLBs in res://glb/. Prints [verify] lines.
## 1. rest height of each <key>__rigged.glb, from the mesh baked at the skeleton's pose.
## 2. <key>__idle / __walk: idle(1s) -> walk(0.3s blend, 2s) -> idle(0.3s blend, 1s) at 60 Hz: heading range, size range, feet slide in idle.
## 3. every <key>__anim_swim|tread_water|dive: bone lengths constant, neck/head y range, skinned height range.
const STEP: float = 1.0 / 60.0

var _done: bool = false

func _process(_d: float) -> bool:
	if _done: return true
	_done = true
	_run()
	return true

func _run() -> void:
	var files: PackedStringArray = DirAccess.get_files_at("res://glb")
	for f in files:
		if f.ends_with("__rigged.glb"): _rest(f)
	for f in files:
		if f.ends_with("__idle.glb"): _blend(f.get_slice("__", 0))
	for f in files:
		if f.ends_with(".glb") and ("anim_swim" in f or "anim_tread_water" in f or "anim_dive" in f): _water(f)
	print("[verify] done")

func _inst(f: String) -> Node3D:
	var n: Node3D = (load("res://glb/" + f) as PackedScene).instantiate()
	root.add_child(n)
	return n

func _mesh(n: Node) -> MeshInstance3D:
	for m in n.find_children("*", "MeshInstance3D", true, false):
		if not (m as Node).name.begins_with("Icosphere"): return m
	return null

func _skinned_aabb(n: Node3D) -> AABB:
	"""Every 3rd vertex skinned here from the mesh arrays, the skin's binds and the skeleton's pose: the
	headless renderer registers no skin, so the engine's own bake is unavailable."""
	var mi := _mesh(n)
	var skel := mi.get_node(mi.skeleton) as Skeleton3D
	var skin := mi.skin
	var mats: Array[Transform3D] = []
	for i in skin.get_bind_count():
		var bone := skin.get_bind_bone(i)
		if bone < 0: bone = skel.find_bone(skin.get_bind_name(i))
		mats.append(skel.global_transform * skel.get_bone_global_pose(bone) * skin.get_bind_pose(i))
	var arr := mi.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var per := bones.size() / verts.size()
	var box := AABB(); var first := true
	for v in range(0, verts.size(), 3):
		var p := Vector3.ZERO
		for j in per:
			var w := weights[v * per + j]
			if w > 0.0: p += w * (mats[bones[v * per + j]] * verts[v])
		if first: box = AABB(p, Vector3.ZERO); first = false
		else: box = box.expand(p)
	return box

func _rest(f: String) -> void:
	var n := _inst(f)
	var skel := n.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	skel.reset_bone_poses()
	var p := n.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if p: p.active = false
	skel.force_update_all_bone_transforms()
	var a := _skinned_aabb(n)
	print("[verify] rest %-24s height %.4f m  bottom %+.4f  width %.3f depth %.3f  bones %d" % [f.get_slice("__", 0), a.size.y, a.position.y, a.size.x, a.size.z, skel.get_bone_count()])
	n.free()

func _blend(k: String) -> void:
	var n := _inst(k + "__idle.glb")
	var wn: Node3D = (load("res://glb/%s__walk.glb" % k) as PackedScene).instantiate()
	var wp := wn.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var walk: Animation = wp.get_animation(wp.get_animation_list()[0]).duplicate()
	wn.free()
	var p := n.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var idle: StringName = p.get_animation_list()[0]
	p.get_animation(idle).loop_mode = Animation.LOOP_LINEAR
	walk.loop_mode = Animation.LOOP_LINEAR
	var lib := AnimationLibrary.new(); lib.add_animation("walk", walk); p.add_animation_library("x", lib)
	p.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var skel := n.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var hips := skel.find_bone("Hips")
	var lf := skel.find_bone("LeftFoot"); var rf := skel.find_bone("RightFoot")
	var rest: Basis = skel.get_bone_global_rest(hips).basis.orthonormalized()
	var hs: Array[float] = []; var hmin := 1e9; var hmax := -1e9
	var f0l := Vector3.ZERO; var f0r := Vector3.ZERO; var slide := 0.0
	p.play(idle)
	for f in 360:
		if f == 60: p.play("x/walk", 0.3)
		if f == 240: p.play(idle, 0.3)
		p.advance(STEP)
		skel.force_update_all_bone_transforms()
		var g := skel.get_bone_global_pose(hips)
		var q := (g.basis.orthonormalized() * rest.inverse()).get_rotation_quaternion()
		var h := rad_to_deg(2.0 * atan2(q.y, q.w))
		if hs.size() > 0: h += 360.0 * roundf((hs[-1] - h) / 360.0)
		hs.append(h)
		if f % 20 == 0:
			var a := _skinned_aabb(n); hmin = minf(hmin, a.size.y); hmax = maxf(hmax, a.size.y)
		var lp := skel.get_bone_global_pose(lf).origin; var rp := skel.get_bone_global_pose(rf).origin
		if f == 0: f0l = lp; f0r = rp
		if f < 60: slide = maxf(slide, maxf(Vector2(lp.x - f0l.x, lp.z - f0l.z).length(), Vector2(rp.x - f0r.x, rp.z - f0r.z).length()))
	var idle_h := hs.slice(0, 60)
	print("[verify] blend %-20s idle heading %.2f..%.2f deg; whole sequence %.2f..%.2f; idle->walk turns %.1f, walk->idle %.1f; skinned height %.3f..%.3f m; idle feet slide %.4f m"
		% [k, idle_h.min(), idle_h.max(), hs.min(), hs.max(), absf(hs[78] - hs[59]), absf(hs[258] - hs[239]), hmin, hmax, slide])
	n.free()

func _water(f: String) -> void:
	var n := _inst(f)
	var p := n.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var anim_name: StringName = p.get_animation_list()[0]
	var anim := p.get_animation(anim_name)
	p.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var skel := n.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var neck := skel.find_bone("neck"); var head := skel.find_bone("Head"); var hips := skel.find_bone("Hips")
	var lens0 := {}
	var worst_len := 0.0; var nmin := 1e9; var nmax := -1e9; var hipmax := -1e9; var hmin := 1e9; var hmax := -1e9; var top := -1e9
	p.play(anim_name)
	var frames := int(ceil(anim.length / STEP))
	for fr in frames:
		p.seek(fr * STEP, true)
		skel.force_update_all_bone_transforms()
		for b in skel.get_bone_count():
			var par := skel.get_bone_parent(b)
			if par < 0: continue
			var l := skel.get_bone_global_pose(b).origin.distance_to(skel.get_bone_global_pose(par).origin)
			if fr == 0: lens0[b] = l
			else: worst_len = maxf(worst_len, absf(l - float(lens0[b])))
		var ny := (skel.global_transform * skel.get_bone_global_pose(neck)).origin.y
		nmin = minf(nmin, ny); nmax = maxf(nmax, ny)
		hipmax = maxf(hipmax, (skel.global_transform * skel.get_bone_global_pose(hips)).origin.y)
		if fr % 6 == 0:
			var a := _skinned_aabb(n); hmin = minf(hmin, a.size.y); hmax = maxf(hmax, a.size.y); top = maxf(top, a.end.y)
	print("[verify] water %-44s len %.3fs neck y %+.3f..%+.3f  hips max y %+.3f  skinned top %+.3f  extent y %.3f..%.3f  bone length drift %.5f m"
		% [f, anim.length, nmin, nmax, hipmax, top, hmin, hmax, worst_len])
	n.free()
