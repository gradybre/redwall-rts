extends SkeletonModifier3D
## The exact ground constraint for an eight-bone tail chain. Decision 0194.
##
## ---------------------------------------------------------------------------------------
## WHY A SECOND MODIFIER AFTER THE SPRING. Godot's SpringBoneSimulator3D collides softly: it pushes
## a joint out of its collider once per step, then its stiffness pulls the joint back towards the
## animated pose -- and a tail's animated pose, rigid off the hips, points into the ground. Measured
## on the baked library (decision 0193), joints sat BELOW their own radius, and 39 of 60 clips had
## fur up to 2.7 cm in the ground. This modifier runs after the spring, every frame, and makes the
## ground exact: walking down the chain, any joint (or the tip the spring extends past tail_07)
## closer to `floor_height` than its segment's measured clearance is lifted by swinging the segment
## above it up -- that segment's length, the base, and the other segments' world directions kept.
## A frame that needs nothing is left exactly as the spring made it.
##
## ONE IMPLEMENTATION FOR BOTH TIERS. The crowd bake (tools/godot/bake_tail_spring.gd) runs this same
## script, so a baked crowd tail and a live skeletal-pool tail obey the same ground.
##
## ---------------------------------------------------------------------------------------
## THE SWING. The segment turns towards "behind the hips" only in proportion to how deep it would
## otherwise go: a barely-touching segment keeps its own heading. Without that fade, a hanging
## (near-vertical, headingless) segment swung 57 degrees in the frame the lift switched on.

const TAIL_BONES: int = 8
const POINTS: int = TAIL_BONES + 1
const HEADING_BLEND: float = 0.3
const FADE_DEPTH: float = 0.25          # of a segment's length: the depth by which the swing is fully "behind"
const BEHIND_AT_REST: Vector3 = Vector3(0.0, 0.0, -1.0)   # glTF creatures face +Z (asset library README)

const REFUSE_NONE: StringName = &""
const REFUSE_NO_BONE: StringName = &"TAIL_NO_BONE"
const REFUSE_CLEARANCES: StringName = &"TAIL_BAD_CLEARANCES"

## World height of the ground under this creature. The owner sets it every frame.
var floor_height: float = 0.0

var _bones: PackedInt32Array = PackedInt32Array()
var _parent_bone: int = -1
var _clear: PackedFloat32Array = PackedFloat32Array()
var _tip_offset: Vector3 = Vector3.ZERO
var _back_local: Vector3 = Vector3.ZERO
var _points: PackedVector3Array = PackedVector3Array()
var _placed: PackedVector3Array = PackedVector3Array()
var _world_rot: Array[Quaternion] = []
var _lifted: Array[Quaternion] = []


func bind_chain(skeleton: Skeleton3D, clearances: PackedFloat32Array) -> StringName:
	"""Resolve tail_00..tail_07 and take one clearance (metres) per segment. Call once, before use."""
	if clearances.size() != TAIL_BONES:
		return REFUSE_CLEARANCES
	_bones.resize(TAIL_BONES)
	for i in TAIL_BONES:
		_bones[i] = skeleton.find_bone("tail_%02d" % i)
		if _bones[i] < 0:
			_bones.clear()
			return REFUSE_NO_BONE
	_parent_bone = skeleton.get_bone_parent(_bones[0])
	_clear = point_clearances(clearances)
	## The spring extends past tail_07 by tail_07's own offset from tail_06 (BONE_DIRECTION_FROM_PARENT).
	_tip_offset = skeleton.get_bone_rest(_bones[TAIL_BONES - 1]).origin
	_back_local = skeleton.get_bone_global_rest(_parent_bone).basis.inverse() * BEHIND_AT_REST
	_points.resize(POINTS)
	_placed.resize(POINTS)
	_world_rot.resize(TAIL_BONES)
	_lifted.resize(TAIL_BONES)
	return REFUSE_NONE


static func point_clearances(segments: PackedFloat32Array) -> PackedFloat32Array:
	"""Per chain point: the thicker of the two segments it joins (the base and tip have one)."""
	var out := PackedFloat32Array()
	out.resize(POINTS)
	out[0] = segments[0]
	for i in range(1, POINTS):
		out[i] = maxf(segments[i - 1], segments[mini(i, TAIL_BONES - 1)])
	return out


func _process_modification_with_delta(_delta: float) -> void:
	"""After the spring, every frame."""
	var skeleton := get_skeleton()
	if skeleton != null:
		apply(skeleton, skeleton.global_transform)


func apply(skeleton: Skeleton3D, xf: Transform3D) -> bool:
	"""Leave a clear frame alone; otherwise lift the chain off the floor. `xf` is the skeleton's
	world transform. Returns whether anything was lifted. Public so it is testable outside a tree."""
	if _bones.is_empty():
		return false
	_read_points(skeleton, xf)
	if is_clear(_points, _clear, floor_height):
		return false
	_lift(skeleton, xf)
	return true


func _read_points(skeleton: Skeleton3D, xf: Transform3D) -> void:
	"""World positions of the eight joints and the tip, as the spring left them."""
	for i in TAIL_BONES:
		_points[i] = xf * skeleton.get_bone_global_pose(_bones[i]).origin
	_points[TAIL_BONES] = xf * (skeleton.get_bone_global_pose(_bones[TAIL_BONES - 1]) * _tip_offset)


static func is_clear(points: PackedVector3Array, clear: PackedFloat32Array, floor_y: float) -> bool:
	"""True when every point past the base is at least its clearance above the floor."""
	for i in range(1, POINTS):
		if points[i].y < floor_y + clear[i]:
			return false
	return true


func _lift(skeleton: Skeleton3D, xf: Transform3D) -> void:
	"""Swing each offending segment up, then write the chain back as local rotations."""
	var xq := xf.basis.get_rotation_quaternion()
	var parent_rot := xq * skeleton.get_bone_global_pose(_parent_bone).basis.get_rotation_quaternion()
	for i in TAIL_BONES:
		_world_rot[i] = xq * skeleton.get_bone_global_pose(_bones[i]).basis.get_rotation_quaternion()
	var back := parent_rot * _back_local
	var behind := Vector2(back.x, back.z)
	behind = behind.normalized() if behind.length_squared() > 1e-12 else Vector2(0.0, -1.0)
	_placed[0] = _points[0]
	for i in TAIL_BONES:
		var d := _points[i + 1] - _points[i]
		var low := floor_height + _clear[i + 1]
		var nd := d if _placed[i].y + d.y >= low else lift_segment(_placed[i], d, low, behind)
		_placed[i + 1] = _placed[i] + nd
		_lifted[i] = Quaternion(d.normalized(), nd.normalized()) * _world_rot[i]
	var parent := parent_rot
	for i in TAIL_BONES:
		skeleton.set_bone_pose_rotation(_bones[i], (parent.inverse() * _lifted[i]).normalized())
		parent = _lifted[i]


static func lift_segment(base: Vector3, d: Vector3, low: float, behind: Vector2) -> Vector3:
	"""Segment d from `base`, swung up so its end sits at `low`; its length kept."""
	var length := d.length()
	var dy := clampf((low - base.y) / length, -1.0, 1.0)
	var w := HEADING_BLEND * length * minf(1.0, (low - base.y - d.y) / (FADE_DEPTH * length))
	var heading := Vector2(d.x + w * behind.x, d.z + w * behind.y)
	var flat := sqrt(maxf(0.0, 1.0 - dy * dy)) * length
	if heading.length_squared() <= 1e-24:
		return Vector3(0.0, dy * length, 0.0)
	heading = heading.normalized() * flat
	return Vector3(heading.x, dy * length, heading.y)
