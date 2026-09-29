extends SceneTree
## Bake the live tail -- Godot's spring AND the exact ground constraint after it -- into per-frame
## tail rotations. Decisions 0192, 0194. The spring and constraint are built by the game's own
## scripts/presentation/tail_rig.gd, copied into this throwaway project at the same res:// path, so
## a baked crowd tail and a live skeletal-pool tail are made by one implementation.
##
## Run by tools/bake_meshy_tail.py inside a throwaway project that holds one creature's
## tailed clips. For every clip it steps the clip's OWN key times (30 Hz for Meshy clips),
## runs warm-up loops (WARM_UP_S of motion, at least one loop) so the spring starts from steady
## motion rather than from rest, then records one loop. The spring is configured only once the scene is live: set in
## _initialize, its bone names never resolve and it silently does nothing.
##
## Args after --: <spec.json> <out.json>

const TailRigScript := preload("res://scripts/presentation/tail_rig.gd")

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
var _positions: Array = []          # the key time each recorded frame was posed at
var _pose_bones: PackedInt32Array = PackedInt32Array()
var _pose_keys: Array = []
var _result: Dictionary = {}
var _pending: bool = false          # exactly one recorded update per stepped key
var _extra_updates: int = 0
var _rig: RefCounted = null
var _root: PackedVector2Array = PackedVector2Array()   # the clip's root path, world (x, z), per key
var _loop_offset: Vector3 = Vector3.ZERO                 # the whole travel of every loop already played
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
	## The body is posed from the FILE, not played by Godot: its glTF import drops keys that lie
	## near the line through their neighbours (the otter boatwright's walk lost a hips key 9.86 mm
	## off it, at 30 fps and at 60, optimizer on or off), so Godot's pose and the shipped file's
	## differed and the constraint lifted against the wrong one (decision 0194). The spec carries
	## every bone's exact local transform at every file key; the AnimationPlayer is switched off.
	_player = _inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _player != null:
		_player.active = false
	_times = PackedFloat64Array(_spec["times"][_clips[_clip]])
	_floor = PackedFloat64Array(_spec["floor"][_clips[_clip]])
	_skel = _inst.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_skel.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	_tail = PackedInt32Array()
	for i in TAIL_BONES:
		_tail.append(_skel.find_bone("tail_%02d" % i))
	_read_poses(_spec["poses"][_clips[_clip]])
	_loop_offset = Vector3.ZERO
	_rig = TailRigScript.new()
	var refused: StringName = _rig.attach(_skel)
	if refused != TailRigScript.REFUSE_NONE:
		printerr("[bake] REFUSED: %s on %s" % [refused, _clips[_clip]])
		quit(1)
		return
	## A water clip's tail is carried, not hung: no gravity (decision 0203).
	_rig.set_water(bool(_spec.get("water", {}).get(_clips[_clip], false)))
	if not _skel.skeleton_updated.is_connected(_on_updated):
		_skel.skeleton_updated.connect(_on_updated)
	_key = 0
	_recording = false
	var loop_s: float = _times[_times.size() - 1] - _times[0] + (_times[1] - _times[0])
	_warm_loops_left = maxi(1, ceili(WARM_UP_S / loop_s))
	_frames = []
	_positions = []
	_stage = "step"


func _read_poses(poses: Dictionary) -> void:
	"""Bone indices, and per key the flat [t xyz, r xyzw, s xyz] of every posed bone."""
	_pose_bones = PackedInt32Array()
	for name in poses["bones"]:
		_pose_bones.append(_skel.find_bone(name))
	_pose_keys = []
	for key in poses["keys"]:
		_pose_keys.append(PackedFloat64Array(key))
	_root = PackedVector2Array()
	for xz in poses["root_xz"]:
		_root.append(Vector2(xz[0], xz[1]))


func _apply_pose(k: int) -> void:
	"""Set every posed bone to the file's local transform at key k."""
	var key: PackedFloat64Array = _pose_keys[k]
	for j in _pose_bones.size():
		var o := j * 10
		_skel.set_bone_pose_position(_pose_bones[j], Vector3(key[o], key[o + 1], key[o + 2]))
		_skel.set_bone_pose_rotation(_pose_bones[j], Quaternion(key[o + 3], key[o + 4], key[o + 5], key[o + 6]).normalized())
		_skel.set_bone_pose_scale(_pose_bones[j], Vector3(key[o + 7], key[o + 8], key[o + 9]))


func _place_root(k: int) -> void:
	"""Move the creature along the clip's root path (decision 0195): the clip is in place, so this
	is where the travel went. Each finished loop adds its whole travel, so the spring feels the body
	walk on -- it never sees a snap back to the start."""
	_inst.position = Vector3(_root[k].x, 0.0, _root[k].y) + _loop_offset


func _step() -> void:
	## One clip key per engine frame: pose the body at it, then advance the spring by exactly the gap
	## to the previous key. The result is read in skeleton_updated, which fires after this.
	var t: float = _times[_key]
	## Never advance by zero. At the loop's wrap the pose jumps from the clip's end to its start;
	## stepped by times[0] (= 0) the spring left the tail's base joint ~170 deg off for that one
	## frame. The wrap is one ordinary key gap.
	var dt: float = t - _times[_key - 1] if _key > 0 else _times[1] - _times[0]
	_pending = true
	_rig.set_floor(_floor[_key])
	_place_root(_key)
	_apply_pose(_key)
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
		_positions.append(_times[_key])
	_key += 1
	if _key < _times.size():
		return
	_key = 0
	var travel := _root[_root.size() - 1]
	_loop_offset += Vector3(travel.x, 0.0, travel.y)
	if not _recording:
		_warm_loops_left -= 1
		_recording = _warm_loops_left <= 0   # warm-up done: record the next loop
		return
	_result[_clips[_clip]] = {"times": _positions, "rotations": _frames}
	_stage = "next"
