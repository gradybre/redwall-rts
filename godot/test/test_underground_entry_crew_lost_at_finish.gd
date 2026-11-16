extends "res://test/underground_host_case.gd"
## Decision 1940: a finished crew lost before it leaves is removed from the underground route roster where it lies.
## Runs the whole entry to its finishing tick first (DESCENT_DONE_TICK), so this suite is in the slow tier. Split from
## test_underground_entry_crew_leaves.gd so CI can shard the two whole flights apart (decision 2044, CI time).


func test_a_finished_crew_lost_before_it_leaves_is_removed_from_the_roster() -> void:
	"""Decision 1940, ADR1225: a crew that dies on its last station is removed from the roster where it lies; it walks
	nowhere, and the entry stops leaving and reserving it."""
	var done: Array = _finished_entry()
	var o: Session.Retirement.Owners = done[0]
	var entry: Settlement.UndergroundEntryRuntime = done[1]
	var worker: Vector2i = done[2]
	var row: int = done[3]
	var stood: Transforms.Pose = _pose(o, worker)
	_kill(o, worker)
	assert_true(_host.run_tick(done[4]), "the tick it is removed: %s" % _host.last_refusal())
	assert_true(o.routes._lost_actor_row(worker) < 0, "the lost crew's actor is removed")
	assert_equal(entry.walk_ticks_left(), 0, "it walks nowhere")
	var at: Transforms.Pose = _pose(o, worker)
	assert_equal(Vector3i(at.x, at.y, at.z), Vector3i(stood.x, stood.y, stood.z), "it lies where it rested")
	assert_false(entry.is_leaving(), "the entry is not leaving any more")
	assert_false(entry.reserves_resident(row), "nor reserving it")
	assert_equal(entry.error(), Settlement.UndergroundEntryRuntime.REFUSE_KITCHEN_UNBUILT, "G9 still held")
