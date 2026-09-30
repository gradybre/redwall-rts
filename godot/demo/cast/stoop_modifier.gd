extends SkeletonModifier3D
## The procedural stoop: a resident in a bore bends to clear its crown. Decision 0207 (the underground
## revamp's P1; design docs/design/underground_revamp.md §6 "How residents move"). Presentation only.
##
## It runs after the AnimationPlayer, first of the skeleton's modifiers (before the tail's spring), on
## Meshy's 24-joint rig, and lowers the head by `drop_m` over the clip's own pose:
##   * THE HIPS come down HIP_SHARE of the drop (at most HIP_MAX_PER_HEIGHT of the body's height), and
##     each leg is re-solved -- thigh and shin, in the plane of its own knee -- so the FOOT keeps the
##     place and turn the clip gave it: the stoop never moves a planted foot (decision 0202's pins hold);
##   * THE SPINE bends forward over the rest, SPINE_SHARES of one angle at Spine02, Spine01 and Spine
##     (the rig's spine runs Spine02 at the hips up to Spine), solved from the rest pose (`bend_for`) so
##     the head comes down the rest of the drop; the NECK takes NECK_COUNTER of it back, so the gaze
##     stays ahead rather than on the floor.
## `lean_rad` pitches the spine on top of that (positive forward): on a ramp the actor's root follows the
## slope, so the feet meet it, and the spine takes half of that back (demo_actor.gd) -- the body leans
## into a ramp by half its slope.
##
## The resident's actor sets the pose each frame (`set_pose`), eased on the demo clock (a paused game
## holds it); with no pose the modifier is switched off, so a resident on the surface costs nothing. The pose is applied by `apply`, which the tests call on a
## skeleton built in code. Global poses are composed from the bones' own poses up the parent chain
## (`global_pose`): the skeleton's cached ones are refreshed only in its own update, which a script run
## outside the main loop (the headless tests) never reaches.

const SPINE: Array[StringName] = [&"Spine02", &"Spine01", &"Spine"]
const SPINE_SHARES: Array[float] = [0.45, 0.35, 0.2]
const NECK: StringName = &"neck"
const HEAD_TOP: StringName = &"head_end"
const HIPS: StringName = &"Hips"
const LEGS: Array[StringName] = [&"LeftUpLeg", &"LeftLeg", &"LeftFoot", &"RightUpLeg", &"RightLeg", &"RightFoot"]
const NECK_COUNTER: float = 0.5
const HIP_SHARE: float = 0.3
const HIP_MAX_PER_HEIGHT: float = 0.07
const MAX_BEND_RAD: float = 1.3
## The bend-for-drop table: this many bends from 0 to MAX_BEND_RAD.
const TABLE: int = 48

var drop_m: float = 0.0
var lean_rad: float = 0.0
## Whether the rig had the bones this bends (`setup`).
var found: bool = false
## The body's height (m): caps the hips' share.
var height_m: float = 1.0

var _spine: PackedInt32Array = PackedInt32Array()
var _neck: int = -1
var _hips: int = -1
var _legs: PackedInt32Array = PackedInt32Array()
## The actor's right, in the skeleton's space (the axis a forward bend turns about), and its up.
var _right: Vector3 = Vector3.RIGHT
var _up: Vector3 = Vector3.UP
## Head drop (m) at each of the TABLE bends, from the rest pose.
var _drops: PackedFloat32Array = PackedFloat32Array()
## Per-pose scratch, sized once in `setup` (nothing is allocated per frame): the joints the spine bend
## turns, their parents' bases, and the feet the legs are re-solved to.
var _joints: PackedInt32Array = PackedInt32Array()
var _parents: Array[Basis] = []
var _feet: Array[Transform3D] = []


func setup(skeleton: Skeleton3D, actor_from_skeleton: Basis, height: float) -> bool:
	"""Find the rig's bones and tabulate the head's drop per bend from its rest pose. False (and inert)
	when the rig lacks them (a placeholder, or another rig)."""
	height_m = height
	_right = (actor_from_skeleton.inverse() * Vector3.RIGHT).normalized()
	_up = (actor_from_skeleton.inverse() * Vector3.UP).normalized()
	_spine.resize(0)
	for bone_name: StringName in SPINE:
		_spine.append(skeleton.find_bone(bone_name))
	_neck = skeleton.find_bone(NECK)
	_hips = skeleton.find_bone(HIPS)
	_legs.resize(0)
	for bone_name: StringName in LEGS:
		_legs.append(skeleton.find_bone(bone_name))
	var head := skeleton.find_bone(HEAD_TOP)
	found = _spine.find(-1) < 0 and _neck >= 0 and _hips >= 0 and head >= 0 and _legs.find(-1) < 0
	if found:
		_tabulate(skeleton, head)
		_joints = PackedInt32Array([_spine[0], _spine[1], _spine[2], _neck])
		_parents.resize(_joints.size())
		_feet.resize(2)
	active = false
	return found


func set_pose(drop: float, lean: float) -> void:
	"""Lower the head `drop` m and lean the spine `lean` rad from the next pose on; switched on only while
	there is a pose to apply, and never on a rig without the bones."""
	drop_m = drop
	lean_rad = lean
	active = found and (drop > 0.0 or lean != 0.0)


func _tabulate(skeleton: Skeleton3D, head: int) -> void:
	"""The head's drop at TABLE bends, from the rest pose, bent as `apply` bends it."""
	var points := PackedVector3Array()
	for bone: int in [_spine[0], _spine[1], _spine[2], _neck, head]:
		points.append(global_rest(skeleton, bone).origin)
	_drops.resize(TABLE + 1)
	for k in TABLE + 1:
		var bend := MAX_BEND_RAD * float(k) / float(TABLE)
		_drops[k] = (points[4] - _bent_head(points, bend)).dot(_up)


func _bent_head(points: PackedVector3Array, bend: float) -> Vector3:
	"""Where the head's top goes when the spine bends `bend` (shares at its three joints, the neck taking
	its counter back), from these rest points: Spine02, Spine01, Spine, neck, head top."""
	var head := points[4]
	var turns: Array[float] = [bend * SPINE_SHARES[0], bend * SPINE_SHARES[1], bend * SPINE_SHARES[2], -bend * NECK_COUNTER]
	var moved := PackedVector3Array(points)
	for joint in 4:
		var turn := Basis(_right, turns[joint])
		for k in range(joint + 1, 5):
			moved[k] = moved[joint] + turn * (moved[k] - moved[joint])
		head = moved[4]
	return head


func bend_for(spine_drop: float) -> float:
	"""The spine's bend that lowers the head `spine_drop` (m), from the table; MAX_BEND_RAD at most."""
	if spine_drop <= 0.0 or _drops.is_empty():
		return 0.0
	for k in range(1, TABLE + 1):
		if _drops[k] >= spine_drop:
			var t := (spine_drop - _drops[k - 1]) / maxf(_drops[k] - _drops[k - 1], 1e-6)
			return MAX_BEND_RAD * (float(k - 1) + t) / float(TABLE)
	return MAX_BEND_RAD


func hip_drop(drop: float) -> float:
	"""How much of a head drop the hips take (m): HIP_SHARE of it, at most HIP_MAX_PER_HEIGHT tall."""
	return minf(drop * HIP_SHARE, height_m * HIP_MAX_PER_HEIGHT)


func _process_modification_with_delta(_delta: float) -> void:
	"""After the clip: the stoop and the lean (see the header)."""
	apply(get_skeleton())


func apply(skeleton: Skeleton3D) -> void:
	"""Bend `skeleton`'s current pose by `drop_m` and `lean_rad`. Only a rig with the bones is ever switched
	on (`set_pose`), so only one is ever bent."""
	if skeleton == null:
		return
	var hips := hip_drop(maxf(drop_m, 0.0))
	var bend := bend_for(maxf(drop_m, 0.0) - hips)
	_feet[0] = global_pose(skeleton, _legs[2])
	_feet[1] = global_pose(skeleton, _legs[5])
	if hips > 0.0:
		_drop_hips(skeleton, hips)
	_bend_spine(skeleton, bend, lean_rad)


func _bend_spine(skeleton: Skeleton3D, bend: float, lean: float) -> void:
	"""Turn each spine joint forward by its share of `bend` + `lean`, and the neck back NECK_COUNTER of
	`bend`, each about the actor's right axis in the skeleton's space."""
	for k in _joints.size():
		_parents[k] = _parent_basis(skeleton, _joints[k])
	for k in _joints.size():
		var turn := -bend * NECK_COUNTER if k == 3 else (bend + lean) * SPINE_SHARES[k]
		if turn != 0.0:
			_turn_bone(skeleton, _joints[k], _parents[k], turn)


static func global_pose(skeleton: Skeleton3D, bone: int) -> Transform3D:
	"""The bone's pose in the skeleton's space now, composed up its parent chain (see the header)."""
	var pose := skeleton.get_bone_pose(bone)
	var parent := skeleton.get_bone_parent(bone)
	while parent >= 0:
		pose = skeleton.get_bone_pose(parent) * pose
		parent = skeleton.get_bone_parent(parent)
	return pose


static func global_rest(skeleton: Skeleton3D, bone: int) -> Transform3D:
	"""The bone's rest in the skeleton's space, composed up its parent chain."""
	var rest := skeleton.get_bone_rest(bone)
	var parent := skeleton.get_bone_parent(bone)
	while parent >= 0:
		rest = skeleton.get_bone_rest(parent) * rest
		parent = skeleton.get_bone_parent(parent)
	return rest


static func _parent_basis(skeleton: Skeleton3D, bone: int) -> Basis:
	"""The bone's parent's global basis now (the skeleton's own frame for a root)."""
	var parent := skeleton.get_bone_parent(bone)
	return global_pose(skeleton, parent).basis if parent >= 0 else Basis.IDENTITY


func _turn_bone(skeleton: Skeleton3D, bone: int, parent: Basis, angle: float) -> void:
	"""Turn `bone` by `angle` about the actor's right axis (the skeleton's space), in its parent's frame."""
	var axis := (parent.inverse() * _right).normalized()
	skeleton.set_bone_pose_rotation(bone, Quaternion(axis, angle) * skeleton.get_bone_pose_rotation(bone))


func _drop_hips(skeleton: Skeleton3D, amount: float) -> void:
	"""Lower the hips `amount` along the actor's up, then re-solve each leg to its foot (see the header)."""
	var parent := _parent_basis(skeleton, _hips)
	skeleton.set_bone_pose_position(_hips, skeleton.get_bone_pose_position(_hips) - parent.inverse() * (_up * amount))
	for side in 2:
		_solve_leg(skeleton, _legs[side * 3], _legs[side * 3 + 1], _legs[side * 3 + 2], _feet[side])


func _solve_leg(skeleton: Skeleton3D, thigh: int, shin: int, foot: int, goal: Transform3D) -> void:
	"""Thigh and shin turned so the ankle meets `goal` again, the knee in the plane it bends in now, and
	the foot turned back to `goal`'s turn."""
	var hip := global_pose(skeleton, thigh).origin
	var knee := global_pose(skeleton, shin).origin
	var ankle := global_pose(skeleton, foot).origin
	var new_knee := knee_for(hip, knee, ankle, goal.origin, _right)
	_aim(skeleton, thigh, knee - hip, new_knee - hip)
	_aim(skeleton, shin, global_pose(skeleton, foot).origin - global_pose(skeleton, shin).origin, goal.origin - new_knee)
	var shin_basis := global_pose(skeleton, shin).basis
	skeleton.set_bone_pose_rotation(foot, (shin_basis.inverse() * goal.basis).get_rotation_quaternion())


static func knee_for(hip: Vector3, knee: Vector3, ankle: Vector3, goal: Vector3, right: Vector3) -> Vector3:
	"""Where the knee goes for a leg from `hip` to reach `goal`, its thigh and shin keeping their lengths
	(from `knee` and `ankle`), bending in the plane of hip, goal and the knee as it is -- a leg straight
	now bends forward, about the actor's `right` (skeleton space); one reaching too far stays straight."""
	var thigh := hip.distance_to(knee)
	var shin := knee.distance_to(ankle)
	var reach := goal - hip
	var span := clampf(reach.length(), absf(thigh - shin) + 1e-4, thigh + shin - 1e-4)
	var along := reach.normalized()
	var bent := (knee - hip) - along * (knee - hip).dot(along)
	var out := bent.normalized() if bent.length_squared() > 1e-10 else along.cross(right).normalized()
	var a := (thigh * thigh - shin * shin + span * span) / (2.0 * span)
	return hip + along * a + out * sqrt(maxf(thigh * thigh - a * a, 0.0))


static func _aim(skeleton: Skeleton3D, bone: int, from_dir: Vector3, to_dir: Vector3) -> void:
	"""Turn `bone` (in its parent's frame) so the global direction `from_dir` becomes `to_dir`."""
	if from_dir.length_squared() < 1e-12 or to_dir.length_squared() < 1e-12:
		return
	var turn := Quaternion(from_dir.normalized(), to_dir.normalized())
	var parent := _parent_basis(skeleton, bone)
	var global := Basis(turn) * global_pose(skeleton, bone).basis
	skeleton.set_bone_pose_rotation(bone, (parent.inverse() * global).get_rotation_quaternion())
