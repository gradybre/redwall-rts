extends "res://test/framework/test_case.gd"
## A clip's recorded root motion, read from the Hips bone's imported glTF extras. Decision 0195.

const ClipRootMotionScript := preload("res://scripts/presentation/clip_root_motion.gd")

var _skeleton: Skeleton3D = null


func after_each() -> void:
	"""Free the skeleton."""
	if _skeleton != null:
		_skeleton.free()
	_skeleton = null


func _skeleton_with(extras: Variant) -> Skeleton3D:
	"""A one-bone skeleton, Hips, carrying `extras` as Godot imports them (or none, when null)."""
	_skeleton = Skeleton3D.new()
	var hips := _skeleton.add_bone("Hips")
	if extras != null:
		_skeleton.set_bone_meta(hips, &"extras", extras)
	return _skeleton


func test_a_travelling_clip_reports_its_root_motion() -> void:
	var motion := {"period_s": 6.5, "travel_m": [0.0, 1.45726], "mean_speed_m_s": 0.22419, "window_s": 1.0,
		"keys_xz": [[0.0, 0.0], [0.0, 0.01]]}
	var read: Dictionary = ClipRootMotionScript.read(_skeleton_with({"root_motion": motion}))
	assert_almost_equal(float(read["mean_speed_m_s"]), 0.22419, "mean speed")
	assert_equal((read["keys_xz"] as Array).size(), 2, "the path")


func test_a_clip_in_place_reports_nothing() -> void:
	assert_true(ClipRootMotionScript.read(_skeleton_with({"spring_radius_m": 0.1})).is_empty(), "other extras only")
	after_each()
	assert_true(ClipRootMotionScript.read(_skeleton_with(null)).is_empty(), "no extras at all")


func test_the_playback_rate_matches_the_ground_speed() -> void:
	## A clip whose strides cover 0.25 m/s, walked at 0.5 m/s, plays twice as fast.
	assert_almost_equal(ClipRootMotionScript.playback_rate({"mean_speed_m_s": 0.25}, 0.5), 2.0, "0.5 / 0.25")
	assert_almost_equal(ClipRootMotionScript.playback_rate({"mean_speed_m_s": 0.25}, 0.125), 0.5, "0.125 / 0.25")


func test_a_clip_that_does_not_travel_plays_at_one() -> void:
	assert_almost_equal(ClipRootMotionScript.playback_rate({}, 0.5), 1.0, "no root motion")
	assert_almost_equal(ClipRootMotionScript.playback_rate({"mean_speed_m_s": 0.0}, 0.5), 1.0, "zero speed")
