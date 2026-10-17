extends "res://test/underground_host_case.gd"
## Decision 1940: once the live entry is done, its crew leaves the underground route roster from rest and walks out
## to H by ADR1219's timed walk, reserved until it arrives; a lost crew's actor is removed. Each test runs the whole
## entry to its finishing tick first (DESCENT_DONE_TICK), so this suite is in the slow tier.

const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Haul := preload("res://scripts/core/haul_planner.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)


func _finished_entry() -> Array:
	"""[owners, runtime, crew worker, its resident row, next tick] of the live entry run to its finishing tick."""
	var live: Array = _begin_live_entry()
	var o: Session.Retirement.Owners = live[0]
	var entry: Settlement.UndergroundEntryRuntime = live[1]
	_stage(o, entry._output, &"wood", 13000)
	_stage(o, entry._output, &"stone", 2000)
	var tick: int = 1
	while entry.is_running() and tick < 20000:
		assert_true(_host.run_tick(tick), "the settlement tick itself never fails: %s" % _host.last_refusal())
		tick += 1
	assert_equal(tick - 1, DESCENT_DONE_TICK, "the entry finished on its own tick")
	return [o, entry, live[2], o.residents.directory().get_typed_row(live[2]), tick]


func _walk_out_ticks(o: Session.Retirement.Owners, entry: Settlement.UndergroundEntryRuntime, row: int,
		from: Transforms.Pose) -> int:
	"""ADR1219's straight-leg lower bound from where the crew stands to H, at its own size class's ground speed."""
	var speed: IntMath.IntResult = o.residents.size_movement_u_per_s(o.residents.size_class_of(row).value)
	var ticks: IntMath.IntResult = IntMath.IntResult.new()
	var length: int = Settlement.UndergroundEntryRuntime.ceil_length(entry._anchor - Vector3i(from.x, from.y, from.z))
	assert_true(speed.ok and Haul.travel_ticks_into(length, speed.value, ticks), "the walk out is timed")
	return ticks.value


func _pose(o: Session.Retirement.Owners, worker: Vector2i) -> Transforms.Pose:
	"""The resident's current Transform."""
	var pose: Transforms.Pose = Transforms.Pose.new()
	assert_true(o.transforms.read_into(worker, pose), "the crew has a Transform")
	return pose


func _assert_finished_crew_is_held(o: Session.Retirement.Owners, entry: Settlement.UndergroundEntryRuntime,
		worker: Vector2i, row: int) -> void:
	"""On the finishing tick the crew rests on its last station as a route actor whose Job is retired: every other
	actor's occupancy proof finds it stale (ROUTE_OCCUPANT_PROFILE_STALE), which is what the leave clears."""
	assert_true(o.routes._lost_actor_row(worker) >= 0, "the finished crew is still a route actor")
	assert_equal(o.jobs.job_of(row), NULL_REF, "its Job is retired")
	assert_true(o.routes._resident_pair(Session.Retirement.Routes.R_JOB_SLOT, row) != NULL_REF, "yet the actor holds it")
	assert_true(o.routes._current_profile_into(row, Profiles.Selection.new()) != &"", "so its profile is stale")
	assert_true(entry.is_leaving() and not entry.is_running(), "the done entry is leaving, no longer running")
	assert_true(entry.reserves_resident(row), "and its crew stays reserved")


func test_the_finished_crew_leaves_the_roster_and_walks_out_to_h() -> void:
	"""Decision 1940: the tick after the finish the crew leaves the roster where it rests, then walks the exact
	timed walk to H, reserved, its Transform unmoved until arrival places it on H facing as it stood; the walk is
	saved and restored exactly, and on arrival the crew is released, Routes' occupancy current."""
	var done: Array = _finished_entry()
	var o: Session.Retirement.Owners = done[0]
	var entry: Settlement.UndergroundEntryRuntime = done[1]
	var worker: Vector2i = done[2]
	var row: int = done[3]
	var tick: int = done[4]
	_assert_finished_crew_is_held(o, entry, worker, row)
	var stood: Transforms.Pose = _pose(o, worker)
	var walk: int = _walk_out_ticks(o, entry, row, stood)
	assert_true(_host.run_tick(tick), "the leave tick: %s" % _host.last_refusal())
	tick += 1
	assert_true(o.routes._lost_actor_row(worker) < 0, "the crew left the route roster")
	assert_equal(entry.walk_ticks_left(), walk, "and set off on the exact timed walk out to H")
	assert_true(entry.reserves_resident(row) and entry.is_leaving(), "reserved and still leaving while it walks")
	assert_equal(entry.error(), Settlement.UndergroundEntryRuntime.REFUSE_KITCHEN_UNBUILT, "G9 still held")
	_assert_walk_record(entry)
	assert_true(_replace_entry_with_its_record(_host.underground_session(), tick), "the walk out restores exactly")
	entry = _host.underground_entry()
	assert_equal(entry.walk_ticks_left(), walk, "the restored walk has every tick left")
	while entry.walk_ticks_left() > 1:
		assert_true(_host.run_tick(tick), "walking out: %s" % _host.last_refusal())
		tick += 1
		var at: Transforms.Pose = _pose(o, worker)
		assert_true(at.x == stood.x and at.y == stood.y and at.z == stood.z, "the Transform stays put until arrival")
	assert_true(_host.run_tick(tick), "the arrival tick: %s" % _host.last_refusal())
	_assert_arrived(o, entry, worker, row, stood)


func _assert_walk_record(entry: Settlement.UndergroundEntryRuntime) -> void:
	"""A walk-out record that claims H's arrival heading (a walk in) is refused on restore."""
	var bytes: PackedByteArray = PackedByteArray()
	var kept: int = entry._arrival_yaw
	entry._arrival_yaw = entry._foreman.arrival_yaw()
	assert_equal(entry.capture(bytes), &"", "captured")
	entry._arrival_yaw = kept
	var fresh: Settlement.UndergroundEntryRuntime = Settlement.UndergroundEntryRuntime.new()
	assert_equal(fresh.restore(bytes, _host.underground_session()), Progress.REFUSE_SHAPE,
		"a finished crew's walk out keeps its own heading")


func _assert_arrived(o: Session.Retirement.Owners, entry: Settlement.UndergroundEntryRuntime, worker: Vector2i,
		row: int, stood: Transforms.Pose) -> void:
	"""On H's point, facing as it stood, released and free for any Job; Routes' occupancy is current."""
	var at: Transforms.Pose = _pose(o, worker)
	assert_equal(Vector3i(at.x, at.y, at.z), entry._anchor, "the crew arrived on H")
	assert_equal(at.yaw, stood.yaw, "facing as it stood")
	assert_equal(entry.walk_ticks_left(), 0, "the walk is over")
	assert_false(entry.is_leaving(), "the crew has left")
	assert_false(entry.reserves_resident(row), "and is released")
	assert_equal(entry.error(), Settlement.UndergroundEntryRuntime.REFUSE_KITCHEN_UNBUILT, "the entry still holds G9")
	assert_true(worker in _eligible_moles(o), "an idle mole again, holding no Job")
	assert_equal(o.routes._occupancy_expected_revision, o.transforms.mutation_revision(), "occupancy rebuilt")
	assert_equal(entry.advance(DESCENT_DONE_TICK + 10000), &"", "a left crew's entry no longer ticks")


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
