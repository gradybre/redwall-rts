# Exact changed fixture

Full-file SHA256 f2ba63eb46f5bb95c22a9c90b5f239b2f1fa40271c087b34a68bd3f33ca29b23

```gdscript
func test_a_new_world_reset_leaks_no_pose_into_the_world_that_follows_it() -> void:
	"""INIT-POSE-R01 §2.4: a new world may restart persistent ids at 1, so old binding bytes are
	unsafe even though ids never repeat WITHIN a world.

	The second world's id 1 is a different creature standing in a newly initialized row; a reset
	that left the first world's binding stamp behind would hand it the first world's coordinates.
	"""
	assert_true(_generate(), "a first world stands")
	var first: Vector2i = _settlement.residents().ref_of(_slot_of_persistent_id(1))
	_settlement.reset()
	assert_equal(_settlement.transforms().bound_count(), 0, "the reset released every pose")
	var fresh: SettlementSystemScript = SettlementSystemScript.new()
	var fresh_bytes: PackedByteArray = fresh.transforms().state_bytes()
	fresh.free()
	assert_equal(_settlement.transforms().state_bytes(), fresh_bytes,
		"leaving the columns byte-identical to a freshly composed store")
	assert_false(_settlement.transforms().is_bound(first),
		"and the first world's reference reads as unplaced, not as its old coordinates")
	assert_true(_generate(), "a second world generates over it")
	var pose: TransformsScript.Pose = _pose_of_persistent_id(1)
	assert_not_null(pose, "the second world's id 1 has its own pose")
	assert_equal(pose.x, ROW_FIRST_ROOT_X_UNITS, "which is its own newly initialized apron tile")
	assert_true(pose.matches_previous(), "with no history carried over from the first world")


```
