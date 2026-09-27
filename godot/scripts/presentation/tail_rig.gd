extends RefCounted
## One creature's live tail: Godot's spring, the spring's ground plane, and the exact ground
## constraint after it. Decision 0194. The skeletal pool makes one per tailed actor; the crowd bake
## (tools/godot/bake_tail_spring.gd) makes one per clip, so both tiers move a tail the same way.
##
## ---------------------------------------------------------------------------------------
## EVERYTHING COMES FROM THE ASSET. tools/rig_meshy_tail.py writes, as glTF extras on the tail
## bones -- which Godot imports as bone metadata `extras` -- each segment's `spring_radius_m` and
## `ground_clearance_m`, and on tail_00 the creature's `spring` settings. No table in code can then
## disagree with the file being animated.
##
## A UNIT-SCALE SKELETON IS REQUIRED. Under a scaled skeleton Godot 4.7.2's
## SpringBoneCollisionPlane3D collides wrongly -- a plane 5 m below still lifted a test chain
## (decision 0192). tools/repair_meshy_rig.py folds Meshy's 0.01 armature scale away (decision
## 0194); a skeleton still carrying a scale is refused, not worked around.
##
## PER-JOINT RADII NEED INDIVIDUAL CONFIG, and individual config makes every setting per-joint, so
## each joint is set explicitly and read back (decision 0192).
##
## `attach()` must run once the skeleton is inside the tree: before that the spring's bone names do
## not resolve and it silently does nothing (decision 0191).

const TailGroundConstraintScript := preload("res://scripts/presentation/tail_ground_constraint.gd")

const TAIL_BONES: int = 8
const SCALE_TOLERANCE: float = 1e-4

const REFUSE_NONE: StringName = &""
const REFUSE_NOT_IN_TREE: StringName = &"TAIL_SKELETON_NOT_IN_TREE"
const REFUSE_SCALED: StringName = &"TAIL_SKELETON_SCALED"
const REFUSE_NO_CHAIN: StringName = &"TAIL_NO_CHAIN"
const REFUSE_NO_METADATA: StringName = &"TAIL_NO_METADATA"
const REFUSE_SPRING_REJECTED: StringName = &"TAIL_SPRING_REJECTED"

var spring: SpringBoneSimulator3D = null
var plane: SpringBoneCollisionPlane3D = null
var constraint: SkeletonModifier3D = null
var refusal: StringName = REFUSE_NONE


func attach(skeleton: Skeleton3D) -> StringName:
	"""Build the spring, its plane and the constraint on `skeleton`. Returns REFUSE_NONE or why not."""
	if skeleton == null or not skeleton.is_inside_tree():
		refusal = REFUSE_NOT_IN_TREE
		return refusal
	refusal = check_chain(skeleton)
	if refusal != REFUSE_NONE:
		return refusal
	var meta: Dictionary = read_chain_metadata(skeleton)
	refusal = REFUSE_NO_METADATA if meta.is_empty() else _build(skeleton, meta)
	return refusal


static func check_chain(skeleton: Skeleton3D) -> StringName:
	"""At unit scale, with a tail chain. Walks the parents itself, so it needs no tree."""
	var scale := Vector3.ONE
	var node: Node = skeleton
	while node != null:
		if node is Node3D:
			scale *= (node as Node3D).scale
		node = node.get_parent()
	if not scale.is_equal_approx(Vector3.ONE):
		return REFUSE_SCALED
	for i in TAIL_BONES:
		if skeleton.find_bone("tail_%02d" % i) < 0:
			return REFUSE_NO_CHAIN
	return REFUSE_NONE


static func read_chain_metadata(skeleton: Skeleton3D) -> Dictionary:
	"""{spring: Dictionary, radii, clearances: PackedFloat32Array} from the bones' `extras`, or {}."""
	var radii := PackedFloat32Array()
	var clearances := PackedFloat32Array()
	for i in TAIL_BONES:
		var extras: Dictionary = _bone_extras(skeleton, "tail_%02d" % i)
		if not (extras.has("spring_radius_m") and extras.has("ground_clearance_m")):
			return {}
		radii.append(float(extras["spring_radius_m"]))
		clearances.append(float(extras["ground_clearance_m"]))
	var spring_settings: Dictionary = _bone_extras(skeleton, "tail_00").get("spring", {})
	for key in ["stiffness", "drag", "gravity"]:
		if not spring_settings.has(key):
			return {}
	return {"spring": spring_settings, "radii": radii, "clearances": clearances}


static func _bone_extras(skeleton: Skeleton3D, bone_name: String) -> Dictionary:
	"""The glTF extras Godot imported onto one bone, or {}."""
	var bone := skeleton.find_bone(bone_name)
	if bone < 0 or not skeleton.has_bone_meta(bone, &"extras"):
		return {}
	return skeleton.get_bone_meta(bone, &"extras")


func _build(skeleton: Skeleton3D, meta: Dictionary) -> StringName:
	"""Spring (with its plane) first, constraint second: modifiers run in child order."""
	spring = SpringBoneSimulator3D.new()
	skeleton.add_child(spring)
	if not _configure_spring(skeleton, meta["spring"], meta["radii"]):
		return REFUSE_SPRING_REJECTED
	plane = SpringBoneCollisionPlane3D.new()
	spring.add_child(plane)
	plane.top_level = true
	plane.global_transform = Transform3D.IDENTITY
	spring.set_enable_all_child_collisions(0, true)
	constraint = TailGroundConstraintScript.new()
	skeleton.add_child(constraint)
	var bound: StringName = constraint.bind_chain(skeleton, meta["clearances"])
	return REFUSE_NONE if bound == TailGroundConstraintScript.REFUSE_NONE else bound


func _configure_spring(skeleton: Skeleton3D, settings: Dictionary, radii: PackedFloat32Array) -> bool:
	"""One chain tail_00..tail_07, every joint set individually, then read back."""
	spring.set_setting_count(1)
	spring.set_root_bone_name(0, "tail_00")
	spring.set_end_bone_name(0, "tail_%02d" % (TAIL_BONES - 1))
	spring.set_extend_end_bone(0, true)
	spring.set_end_bone_direction(0, SpringBoneSimulator3D.BONE_DIRECTION_FROM_PARENT)
	spring.set_end_bone_length(0, skeleton.get_bone_rest(skeleton.find_bone("tail_%02d" % (TAIL_BONES - 1))).origin.length())
	spring.set_individual_config(0, true)
	if spring.get_joint_count(0) != TAIL_BONES:
		return false
	for j in TAIL_BONES:
		spring.set_joint_stiffness(0, j, float(settings["stiffness"]))
		spring.set_joint_drag(0, j, float(settings["drag"]))
		spring.set_joint_gravity(0, j, float(settings["gravity"]))
		spring.set_joint_gravity_direction(0, j, Vector3.DOWN)
		spring.set_joint_radius(0, j, radii[j])
	return _spring_kept(settings, radii)


func _spring_kept(settings: Dictionary, radii: PackedFloat32Array) -> bool:
	"""Every joint still holds the value it was given."""
	if not spring.is_config_individual(0):
		return false
	for j in TAIL_BONES:
		if not (is_equal_approx(spring.get_joint_radius(0, j), radii[j])
				and is_equal_approx(spring.get_joint_stiffness(0, j), float(settings["stiffness"]))
				and is_equal_approx(spring.get_joint_drag(0, j), float(settings["drag"]))
				and is_equal_approx(spring.get_joint_gravity(0, j), float(settings["gravity"]))):
			return false
	return true


func set_floor(height: float) -> void:
	"""The ground under the creature, in world metres: both the spring's plane and the constraint."""
	plane.global_position = Vector3(0.0, height, 0.0)
	constraint.floor_height = height
