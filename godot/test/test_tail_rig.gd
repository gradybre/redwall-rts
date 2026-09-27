extends "res://test/framework/test_case.gd"
## The live tail: TailRig's refusals and spring set-up, and the exact ground constraint. Decision 0194.
##
## The chain is procedural -- Hips, then tail_00..tail_07 running straight back (-Z) 5 cm apart --
## with the same bone metadata `extras` Godot imports from a tailed GLB. With the hips 2 cm above
## the ground and a 3 cm clearance, the level tail starts INSIDE its clearance, so the constraint
## has to act; every expectation below is the invariant it promises, or a literal. The constraint is
## applied through its public `apply()`, which is exactly what the modifier runs each frame.

const TailRigScript := preload("res://scripts/presentation/tail_rig.gd")
const ConstraintScript := preload("res://scripts/presentation/tail_ground_constraint.gd")

const SEGMENT_M: float = 0.05
const CLEARANCE_M: float = 0.03
const RADIUS_M: float = 0.02
const HIPS_Y: float = 0.02

var _holder: Node3D = null
var _skeleton: Skeleton3D = null


func after_each() -> void:
	"""Free the procedural creature."""
	if _holder != null:
		_holder.free()
	_holder = null
	_skeleton = null


func _creature(scale: float, with_metadata: bool) -> Skeleton3D:
	"""Hips at HIPS_Y, the chain straight back; bone rests in 1/scale units so the world is the same."""
	_holder = Node3D.new()
	_holder.scale = Vector3.ONE * scale
	_skeleton = Skeleton3D.new()
	_holder.add_child(_skeleton)
	_skeleton.add_bone("Hips")
	_skeleton.set_bone_rest(0, Transform3D(Basis.IDENTITY, Vector3(0.0, HIPS_Y, 0.0) / scale))
	for i in ConstraintScript.TAIL_BONES:
		var bone := _skeleton.add_bone("tail_%02d" % i)
		_skeleton.set_bone_parent(bone, bone - 1)
		var offset := Vector3.ZERO if i == 0 else Vector3(0.0, 0.0, -SEGMENT_M)
		_skeleton.set_bone_rest(bone, Transform3D(Basis.IDENTITY, offset / scale))
		if with_metadata:
			var extras := {"spring_radius_m": RADIUS_M, "ground_clearance_m": CLEARANCE_M}
			if i == 0:
				extras["spring"] = {"stiffness": 4.0, "drag": 0.9, "gravity": 0.5}
			_skeleton.set_bone_meta(bone, &"extras", extras)
	_skeleton.reset_bone_poses()
	return _skeleton


# --- refusals ------------------------------------------------------------------------------
## The test runner executes suites before the scene tree is live, so nothing here can be "inside the
## tree": attach() is shown refusing that, and the rest is exercised through the tree-free checks.
## The spring actually running is exercised end to end by the crowd bake, which runs this script.

func test_a_skeleton_outside_the_tree_is_refused() -> void:
	var rig: RefCounted = TailRigScript.new()
	assert_equal(rig.attach(_creature(1.0, true)), TailRigScript.REFUSE_NOT_IN_TREE, "not in the tree")


func test_a_scaled_skeleton_is_refused() -> void:
	## The collider bug lives under a scaled skeleton; decision 0194 folds the scale out of the asset.
	assert_equal(TailRigScript.check_chain(_creature(0.01, true)), TailRigScript.REFUSE_SCALED, "a 0.01 parent")


func test_a_unit_scale_chain_passes() -> void:
	assert_equal(TailRigScript.check_chain(_creature(1.0, true)), TailRigScript.REFUSE_NONE, "unit scale, full chain")


func test_a_skeleton_without_a_tail_is_refused() -> void:
	var skeleton := _creature(1.0, true)
	skeleton.set_bone_name(skeleton.find_bone("tail_05"), "Spine")
	assert_equal(TailRigScript.check_chain(skeleton), TailRigScript.REFUSE_NO_CHAIN, "tail_05 missing")


func test_the_asset_metadata_is_read_from_the_bones() -> void:
	var meta: Dictionary = TailRigScript.read_chain_metadata(_creature(1.0, true))
	assert_almost_equal(meta["radii"][7], RADIUS_M, "tail_07's radius")
	assert_almost_equal(meta["clearances"][3], CLEARANCE_M, "tail_03's clearance")
	assert_almost_equal(float(meta["spring"]["stiffness"]), 4.0, "stiffness from tail_00")


func test_a_chain_without_its_metadata_reads_as_nothing() -> void:
	assert_true(TailRigScript.read_chain_metadata(_creature(1.0, false)).is_empty(), "no extras, no tail")


func test_bind_chain_refuses_the_wrong_number_of_clearances() -> void:
	var constraint: SkeletonModifier3D = ConstraintScript.new()
	var three := PackedFloat32Array([0.01, 0.01, 0.01])
	assert_equal(constraint.bind_chain(_creature(1.0, true), three), ConstraintScript.REFUSE_CLEARANCES, "8 needed")
	constraint.free()


# --- the constraint ----------------------------------------------------------------------

func _constrained(floor_y: float) -> PackedVector3Array:
	"""Bind a constraint to the level tail 2 cm up, apply it once, return the chain's points."""
	var skeleton := _creature(1.0, true)
	var constraint: SkeletonModifier3D = ConstraintScript.new()
	var clear := PackedFloat32Array()
	clear.resize(ConstraintScript.TAIL_BONES)
	clear.fill(CLEARANCE_M)
	constraint.bind_chain(skeleton, clear)
	constraint.floor_height = floor_y
	var lifted: bool = constraint.apply(skeleton, Transform3D.IDENTITY)
	constraint.free()
	assert_true(lifted, "the tail started inside its clearance, so it was lifted")
	return _points(skeleton)


func _points(skeleton: Skeleton3D) -> PackedVector3Array:
	"""The eight joints and the tip, composed here from the LOCAL poses the constraint wrote. Outside a
	tree the skeleton's cached global poses do not refresh, and composing them by hand is also
	independent of the engine."""
	var out := PackedVector3Array()
	for i in ConstraintScript.TAIL_BONES:
		out.append(_composed(skeleton, skeleton.find_bone("tail_%02d" % i)).origin)
	out.append(_composed(skeleton, skeleton.find_bone("tail_07")) * Vector3(0.0, 0.0, -SEGMENT_M))
	return out


func _composed(skeleton: Skeleton3D, bone: int) -> Transform3D:
	"""A bone's pose relative to the skeleton: its local poses multiplied up the parent chain."""
	var xf := skeleton.get_bone_pose(bone)
	var parent := skeleton.get_bone_parent(bone)
	while parent >= 0:
		xf = skeleton.get_bone_pose(parent) * xf
		parent = skeleton.get_bone_parent(parent)
	return xf


func test_the_tail_ends_at_or_above_its_clearance() -> void:
	var points := _constrained(0.0)
	for i in range(1, points.size()):
		assert_true(points[i].y >= CLEARANCE_M - 1e-5, "point %d at %.4f m, clearance %.2f" % [i, points[i].y, CLEARANCE_M])


func test_the_lift_is_the_least_that_clears() -> void:
	## A level tail 1 cm inside its clearance comes up exactly onto it -- not further.
	var points := _constrained(0.0)
	for i in range(1, points.size()):
		assert_true(absf(points[i].y - CLEARANCE_M) < 1e-4, "point %d at %.5f m, not above %.2f" % [i, points[i].y, CLEARANCE_M])


func test_a_raised_floor_raises_the_tail_with_it() -> void:
	var points := _constrained(0.04)
	for i in range(1, points.size()):
		assert_true(points[i].y >= 0.04 + CLEARANCE_M - 1e-5, "point %d above the raised floor" % i)


func test_the_constraint_keeps_the_base_and_every_segments_length() -> void:
	var points := _constrained(0.0)
	assert_true(points[0].is_equal_approx(Vector3(0.0, HIPS_Y, 0.0)), "the base is the hips'")
	for i in range(points.size() - 1):
		assert_almost_equal(points[i].distance_to(points[i + 1]), SEGMENT_M, "segment %d length" % i)


func test_a_clear_tail_is_left_exactly_as_it_was() -> void:
	var skeleton := _creature(1.0, true)
	var constraint: SkeletonModifier3D = ConstraintScript.new()
	var clear := PackedFloat32Array()
	clear.resize(ConstraintScript.TAIL_BONES)
	clear.fill(CLEARANCE_M)
	constraint.bind_chain(skeleton, clear)
	constraint.floor_height = -1.0
	var before := _points(skeleton)
	assert_false(constraint.apply(skeleton, Transform3D.IDENTITY), "nothing lifted over a floor 1 m down")
	assert_equal(_points(skeleton), before, "poses untouched")
	constraint.free()


func test_point_clearances_take_the_thicker_neighbour() -> void:
	var out := ConstraintScript.point_clearances(PackedFloat32Array([0.1, 0.2, 0.05, 0.05, 0.3, 0.05, 0.05, 0.04]))
	assert_equal(out, PackedFloat32Array([0.1, 0.2, 0.2, 0.05, 0.3, 0.3, 0.05, 0.05, 0.04]), "per point")


func test_is_clear_needs_every_point_past_the_base() -> void:
	var clear := PackedFloat32Array([0.0, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1])
	var points := PackedVector3Array()
	for i in ConstraintScript.POINTS:
		points.append(Vector3(0.0, 0.2, -0.05 * i))
	assert_true(ConstraintScript.is_clear(points, clear, 0.0), "all at 0.2 over a 0.1 clearance")
	points[0] = Vector3(0.0, -1.0, 0.0)
	assert_true(ConstraintScript.is_clear(points, clear, 0.0), "the base is the clip's, not judged")
	points[8] = Vector3(0.0, 0.05, -0.4)
	assert_false(ConstraintScript.is_clear(points, clear, 0.0), "the tip under its clearance")


func test_lift_segment_lands_on_the_floor_and_keeps_its_length() -> void:
	## Straight down 1 m from y 1, floor at 0.5: the end rises to exactly 0.5.
	var d := ConstraintScript.lift_segment(Vector3(0.0, 1.0, 0.0), Vector3(0.0, -1.0, 0.0), 0.5, Vector2(0.0, -1.0))
	assert_almost_equal(1.0 + d.y, 0.5, "the end sits on the floor")
	assert_almost_equal(d.length(), 1.0, "length kept")
	assert_true(d.z < 0.0 and absf(d.x) < 1e-6, "a headingless segment swings behind (-Z)")


func test_a_barely_touching_segment_keeps_its_own_heading() -> void:
	## 10 cm long, pointing +X and 45 deg down from y 0.07: its end dips 0.7 mm under the floor. It rises
	## onto the floor while barely turning towards "behind" (-Z) -- the fade that stops a switch-on jump.
	var d := ConstraintScript.lift_segment(Vector3(0.0, 0.07, 0.0), Vector3(1.0, -1.0, 0.0).normalized() * 0.1,
		0.0, Vector2(0.0, -1.0))
	assert_almost_equal(0.07 + d.y, 0.0, "the end sits on the floor")
	assert_true(absf(d.z) < 0.01 * d.length(), "heading stays +X (z %.5f)" % d.z)
