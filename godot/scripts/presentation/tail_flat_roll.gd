extends SkeletonModifier3D
## Keeps a FLAT tail's breadth level, whatever the spring and the hips roll. Decision 0203.
##
## ---------------------------------------------------------------------------------------
## WHY. A beaver's paddle is 28 cm wide and a few centimetres thick. Godot's SpringBoneSimulator3D
## turns each tail bone the shortest way onto its new direction, and down a curved chain those turns
## add up to a ROLL about the tail's own length: in the beaver's idle the spring rolled the paddle
## 32-56 degrees while the hips rolled at most 9.5, and its edge went 5 cm into the ground. A round
## tail's roll is invisible; a paddle's is not, and the ground constraint (which keeps the tail's
## AXIS off the ground, by the paddle's thickness) cannot see it.
##
## WHAT. After the spring and the ground constraint, every frame, each tail bone is turned about its
## own length -- the line to the next joint -- so its breadth (the creature's left-right at bind) is
## as close to LEVEL as a bone pointing that way allows: the hips' breadth with its tilt taken out. A
## paddle lies on the ground; rolling it with the hips (up to 9.5 degrees in the beaver's idle) still
## dug its edge 1.5 cm in. Each bone keeps the world direction the spring and the
## constraint gave it (the roll of a parent is not passed down to its children), so every joint is kept
## exactly where they put it, and only the paddle's roll changes.
##
## Only a chain whose tail_00 extras say `section: flat` gets this modifier (tools/rig_meshy_tail.py
## writes it). Every round tail is left exactly as before.

const TAIL_BONES: int = 8
const BREADTH_AT_REST: Vector3 = Vector3(1.0, 0.0, 0.0)   # the creature's left-right, glTF +X
const MIN_PERPENDICULAR: float = 1e-6

const REFUSE_NONE: StringName = &""
const REFUSE_NO_BONE: StringName = &"TAIL_NO_BONE"

var _bones: PackedInt32Array = PackedInt32Array()
var _parent_bone: int = -1
var _hips_breadth: Vector3 = Vector3.ZERO
var _breadth: PackedVector3Array = PackedVector3Array()   # per bone, its breadth in its own frame
var _length: PackedVector3Array = PackedVector3Array()    # per bone, the unit line to its next joint, own frame


func bind_chain(skeleton: Skeleton3D) -> StringName:
	"""Resolve tail_00..tail_07 and their parent, and read each one's breadth and length at rest."""
	_bones.resize(TAIL_BONES)
	for i in TAIL_BONES:
		_bones[i] = skeleton.find_bone("tail_%02d" % i)
		if _bones[i] < 0:
			_bones.clear()
			return REFUSE_NO_BONE
	_parent_bone = skeleton.get_bone_parent(_bones[0])
	_hips_breadth = skeleton.get_bone_global_rest(_parent_bone).basis.orthonormalized().inverse() * BREADTH_AT_REST
	_breadth.resize(TAIL_BONES)
	_length.resize(TAIL_BONES)
	for i in TAIL_BONES:
		_breadth[i] = skeleton.get_bone_global_rest(_bones[i]).basis.orthonormalized().inverse() * BREADTH_AT_REST
		## tail_07's line runs past it by its own offset from tail_06, as the spring extends it.
		var next: int = _bones[mini(i + 1, TAIL_BONES - 1)]
		_length[i] = skeleton.get_bone_rest(next).origin.normalized()
	return REFUSE_NONE


func _process_modification_with_delta(_delta: float) -> void:
	"""After the spring and the ground constraint, every frame."""
	var skeleton := get_skeleton()
	if skeleton != null:
		apply(skeleton)


func apply(skeleton: Skeleton3D) -> float:
	"""Roll each tail bone about its own length to the hips' breadth, writing local rotations. Every bone keeps
	the world DIRECTION it had, so every joint stays where it was; only the rolls change. Returns the largest
	roll taken out, in degrees. Public so it is testable outside a tree."""
	if _bones.is_empty():
		return 0.0
	var hips := global_rotation(skeleton, _parent_bone)
	var target := level_breadth(hips * _hips_breadth)
	var world := hips
	var parent := hips
	var worst := 0.0
	for i in TAIL_BONES:
		world = world * skeleton.get_bone_pose_rotation(_bones[i])      # as the spring and constraint left it
		var axis := world * _length[i]
		var roll := roll_to(axis, world * _breadth[i], target)
		worst = maxf(worst, absf(roll))
		var levelled := (Quaternion(axis.normalized(), roll) * world).normalized()
		skeleton.set_bone_pose_rotation(_bones[i], (parent.inverse() * levelled).normalized())
		parent = levelled
	return rad_to_deg(worst)


static func level_breadth(breadth: Vector3) -> Vector3:
	"""The breadth with its vertical part taken out; the breadth itself if it is (nearly) vertical."""
	var level := Vector3(breadth.x, 0.0, breadth.z)
	return level.normalized() if level.length_squared() > MIN_PERPENDICULAR else breadth


static func roll_to(axis: Vector3, breadth: Vector3, target: Vector3) -> float:
	"""The signed angle about `axis` that turns `breadth` towards `target`, both seen square to the axis.
	0 when either lies along the axis: there is no roll to measure."""
	var a := axis.normalized()
	var b := breadth - a * breadth.dot(a)
	var t := target - a * target.dot(a)
	if b.length_squared() < MIN_PERPENDICULAR or t.length_squared() < MIN_PERPENDICULAR:
		return 0.0
	return b.signed_angle_to(t, a)


static func global_rotation(skeleton: Skeleton3D, bone: int) -> Quaternion:
	"""A bone's rotation in the skeleton's space, composed from the local poses up its parents -- never a
	cached global pose, which the modifiers before this one may have left stale."""
	var q := skeleton.get_bone_pose_rotation(bone)
	var parent := skeleton.get_bone_parent(bone)
	while parent >= 0:
		q = skeleton.get_bone_pose_rotation(parent) * q
		parent = skeleton.get_bone_parent(parent)
	return q
