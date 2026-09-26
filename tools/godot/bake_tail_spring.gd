extends SceneTree
## Bake SpringBoneSimulator3D tail motion into per-frame tail rotations. Decision 0192.
##
## Run by tools/bake_meshy_tail.py inside a throwaway project that holds one creature's
## tailed clips. For every clip it steps the clip's OWN key times (30 Hz for Meshy clips),
## runs warm-up loops (WARM_UP_S of motion, at least one loop) so the spring starts from steady
## motion rather than from rest, then records one loop. The spring is configured only once the scene is live: set in
## _initialize, its bone names never resolve and it silently does nothing.
##
## Args after --: <spec.json> <out.json>

const TAIL_BONES: int = 8
const WARM_UP_S: float = 3.0

var _spec: Dictionary
var _out_path: String
var _clips: Array = []
var _clip: int = -1
var _stage: String = "next"
var _inst: Node3D
var _player: AnimationPlayer
var _skel: Skeleton3D
var _times: PackedFloat64Array
var _key: int = 0
var _recording: bool = false
var _warm_loops_left: int = 0
var _tail: PackedInt32Array
var _frames: Array = []
var _positions: Array = []          # where the player actually was, as independent evidence
var _result: Dictionary = {}
var _pending: bool = false          # exactly one recorded update per stepped key
var _extra_updates: int = 0
var _ground: SpringBoneCollisionPlane3D
var _travel: Vector3 = Vector3.ZERO  # the clip's horizontal root motion over one loop, world
var _floor: PackedFloat64Array       # per key: min(0, the clip's feet, its tail base's floor)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_spec = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	_out_path = args[1]
	_clips = _spec["clips"]


func _process(_delta: float) -> bool:
	match _stage:
		"next": _start_next_clip()
		"configure": _configure()
		"step": _step()
	return false


func _start_next_clip() -> void:
	if _inst != null:
		_inst.queue_free()
	_clip += 1
	if _clip >= _clips.size():
		var f := FileAccess.open(_out_path, FileAccess.WRITE)
		f.store_string(JSON.stringify(_result))
		f.close()
		print("[bake] done %d clips, %d extra skeleton updates ignored" % [_clips.size(), _extra_updates])
		quit()
		return
	_inst = (load("res://glb/%s.glb" % _clips[_clip]) as PackedScene).instantiate()
	root.add_child(_inst)
	_stage = "configure"


func _configure() -> void:
	_player = _inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var anim: Animation = _player.get_animation(_player.get_animation_list()[0])
	_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_player.play(_player.get_animation_list()[0])
	## The clip's timeline comes from the FILE, passed in the spec. Godot re-optimises clips on
	## import (merged channels, dropped keys, an added key at t = 0), so its own tracks are not
	## the file's key times and cannot be baked against.
	_times = PackedFloat64Array(_spec["times"][_clips[_clip]])
	_floor = PackedFloat64Array(_spec["floor"][_clips[_clip]])
	_skel = _inst.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_skel.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	_tail = PackedInt32Array()
	for i in TAIL_BONES:
		_tail.append(_skel.find_bone("tail_%02d" % i))
	if not _unscale(anim):
		return
	_travel = _loop_travel(anim)
	_add_spring()
	if not _skel.skeleton_updated.is_connected(_on_updated):
		_skel.skeleton_updated.connect(_on_updated)
	_key = 0
	_recording = false
	var loop_s: float = _times[_times.size() - 1] - _times[0] + (_times[1] - _times[0])
	_warm_loops_left = maxi(1, ceili(WARM_UP_S / loop_s))
	_frames = []
	_positions = []
	_stage = "step"


func _unscale(anim: Animation) -> bool:
	"""Rebuild the skeleton at unit scale: SpringBoneCollisionPlane3D is wrong under a scaled one.

	Meshy's skeleton sits under the glTF armature's 0.01 scale. Under that, Godot 4.7.2's plane
	collider lifts a chain it never touches -- a plane 5 m below still raised a test chain by
	0.2 m, and one at the chain's middle threw it horizontal (decision 0192). At scale 1 the same
	world geometry collides correctly. So the scale is moved into the bone rests and position
	tracks, which leaves every world position and every local ROTATION -- what is recorded --
	unchanged. Returns false, having refused, if the result is not unit scale.
	"""
	var factor: float = _skel.global_basis.get_scale().x
	var probe: int = _tail[TAIL_BONES - 1]
	var before: Vector3 = _skel.global_transform * _skel.get_bone_global_pose(probe).origin
	var node: Node = _skel
	while node != null and node != root:
		if node is Node3D:
			(node as Node3D).scale = Vector3.ONE
		node = node.get_parent()
	for b in _skel.get_bone_count():
		var rest := _skel.get_bone_rest(b)
		_skel.set_bone_rest(b, Transform3D(rest.basis, rest.origin * factor))
		_skel.set_bone_pose_position(b, _skel.get_bone_pose_position(b) * factor)
	for t in anim.get_track_count():
		## Bone tracks only (a ":bone" subname): they are the ones inside the scaled space.
		if anim.track_get_type(t) == Animation.TYPE_POSITION_3D and anim.track_get_path(t).get_subname_count() > 0:
			for k in anim.track_get_key_count(t):
				anim.track_set_key_value(t, k, (anim.track_get_key_value(t, k) as Vector3) * factor)
	var after: Vector3 = _skel.global_transform * _skel.get_bone_global_pose(probe).origin
	if not _skel.global_basis.get_scale().is_equal_approx(Vector3.ONE) or before.distance_to(after) > 1e-4:
		printerr("[bake] REFUSED: unit scale not reached, or the tail moved (%s -> %s) on %s" % [before, after, _clips[_clip]])
		quit(1)
		return false
	return true


func _loop_travel(anim: Animation) -> Vector3:
	"""How far the hips travel horizontally over one loop (the carry walks carry root motion).

	At the wrap the clip snaps the hips back by this much. The spring would see a 1-2 m teleport
	and whip the tail; instead the creature is moved forward by it, so the motion is continuous.
	"""
	for t in anim.get_track_count():
		var path := anim.track_get_path(t)
		if anim.track_get_type(t) == Animation.TYPE_POSITION_3D and path.get_subname_count() > 0 \
				and path.get_subname(0) == "Hips" and anim.track_get_key_count(t) > 1:
			var d: Vector3 = anim.track_get_key_value(t, anim.track_get_key_count(t) - 1) - anim.track_get_key_value(t, 0)
			var world: Vector3 = _skel.global_basis * d
			return Vector3(world.x, 0.0, world.z)
	return Vector3.ZERO


func _add_spring() -> void:
	var s: Dictionary = _spec["spring"]
	var radii: Array = _spec["radii"]
	var spring := SpringBoneSimulator3D.new()
	_skel.add_child(spring)
	spring.set_setting_count(1)
	spring.set_root_bone_name(0, "tail_00")
	spring.set_end_bone_name(0, "tail_%02d" % (TAIL_BONES - 1))
	spring.set_extend_end_bone(0, true)
	spring.set_end_bone_direction(0, SpringBoneSimulator3D.BONE_DIRECTION_FROM_PARENT)
	var last := _skel.get_bone_global_rest(_tail[TAIL_BONES - 1]).origin
	var before_last := _skel.get_bone_global_rest(_tail[TAIL_BONES - 2]).origin
	spring.set_end_bone_length(0, (last - before_last).length())
	spring.set_stiffness(0, s["stiffness"])
	spring.set_drag(0, s["drag"])
	spring.set_gravity(0, s["gravity"])          # world m/s^2 (decision 0191)
	spring.set_gravity_direction(0, Vector3.DOWN)
	## Per-joint radii only take effect in INDIVIDUAL config. Without it Godot keeps the setting's
	## radius -- 0.02 m by default -- and silently ignores set_joint_radius, which let fur 7-16 cm
	## thick sink to its axis. Individual config also makes stiffness, drag and gravity per-joint,
	## so every joint is set explicitly, then read back.
	spring.set_individual_config(0, true)
	for j in spring.get_joint_count(0):
		spring.set_joint_stiffness(0, j, s["stiffness"])
		spring.set_joint_drag(0, j, s["drag"])
		spring.set_joint_gravity(0, j, s["gravity"])
		spring.set_joint_gravity_direction(0, j, Vector3.DOWN)
		spring.set_joint_radius(0, j, radii[mini(j, radii.size() - 1)])   # world metres
	_verify_joints(spring, s, radii)
	## The plane the creature stands on: y = 0, lowered per key to the clip's own feet or buried tail
	## base where the clip sinks those (decision 0192), so the hips never drive the tail into it.
	_ground = SpringBoneCollisionPlane3D.new()
	spring.add_child(_ground)
	_ground.top_level = true
	_ground.global_transform = Transform3D(Basis.IDENTITY, Vector3(0.0, _floor[0], 0.0))
	spring.set_enable_all_child_collisions(0, true)


func _verify_joints(spring: SpringBoneSimulator3D, s: Dictionary, radii: Array) -> void:
	"""Refuse the whole bake if any joint did not keep the value it was given."""
	var ok: bool = spring.is_config_individual(0) and spring.get_joint_count(0) == TAIL_BONES
	for j in spring.get_joint_count(0):
		ok = ok and is_equal_approx(spring.get_joint_radius(0, j), radii[mini(j, radii.size() - 1)])
		ok = ok and is_equal_approx(spring.get_joint_stiffness(0, j), s["stiffness"])
		ok = ok and is_equal_approx(spring.get_joint_drag(0, j), s["drag"])
		ok = ok and is_equal_approx(spring.get_joint_gravity(0, j), s["gravity"])
	if not ok:
		printerr("[bake] REFUSED: the spring did not keep its per-joint settings on %s" % _clips[_clip])
		quit(1)


func _step() -> void:
	## One clip key per engine frame: seek to it, then advance the spring by exactly the gap
	## to the previous key. The result is read in skeleton_updated, which fires after this.
	var t: float = _times[_key]
	## Never advance by zero. At the loop's wrap the pose jumps from the clip's end to its start;
	## stepped by times[0] (= 0) the spring left the tail's base joint ~170 deg off for that one
	## frame. The wrap is one ordinary key gap.
	var dt: float = t - _times[_key - 1] if _key > 0 else _times[1] - _times[0]
	_pending = true
	_ground.global_position = Vector3(0.0, _floor[_key], 0.0)
	_player.seek(t, true)
	_skel.advance(dt)


func _on_updated() -> void:
	if _stage != "step":
		return
	if not _pending:
		_extra_updates += 1
		return
	_pending = false
	if _recording:
		var frame: Array = []
		for b in _tail:
			var q := _skel.get_bone_pose_rotation(b)
			frame.append([q.x, q.y, q.z, q.w])
		_frames.append(frame)
		_positions.append(_player.current_animation_position)
	_key += 1
	if _key < _times.size():
		return
	_key = 0
	_inst.position += _travel
	if not _recording:
		_warm_loops_left -= 1
		_recording = _warm_loops_left <= 0   # warm-up done: record the next loop
		return
	_result[_clips[_clip]] = {"times": _positions, "rotations": _frames}
	_stage = "next"
