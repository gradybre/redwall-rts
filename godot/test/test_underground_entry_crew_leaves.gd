extends "res://test/underground_host_case.gd"
## Decision 1940: once the live entry is done, its crew leaves the underground route roster from rest and walks out
## to H by ADR1219's timed walk, reserved until it arrives. The test runs the whole entry to its finishing tick first
## (DESCENT_DONE_TICK), so this suite is in the slow tier. A lost crew's removal is in
## test_underground_entry_crew_lost_at_finish.gd (split so CI can shard the two whole flights apart; decision 2044, CI
## time); `_finished_entry()` is underground_host_case.gd's.

const Profiles := preload("res://scripts/core/underground_profiles.gd")
const Haul := preload("res://scripts/core/haul_planner.gd")
const NULL_REF: Vector2i = Vector2i(-1, 0)


func _walk_out_ticks(o: Session.Retirement.Owners, entry: Settlement.UndergroundEntryRuntime, row: int,
		from: Transforms.Pose) -> int:
	"""ADR1219's straight-leg lower bound from where the crew stands to H, at its own size class's ground speed."""
	var speed: IntMath.IntResult = o.residents.size_movement_u_per_s(o.residents.size_class_of(row).value)
	var ticks: IntMath.IntResult = IntMath.IntResult.new()
	var length: int = Settlement.UndergroundEntryRuntime.ceil_length(entry._anchor - Vector3i(from.x, from.y, from.z))
	assert_true(speed.ok and Haul.travel_ticks_into(length, speed.value, ticks), "the walk out is timed")
	return ticks.value


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
	_assert_refused_record(entry, -1, entry._error, walk, "a crew still on the roster is not walking out")
	entry._error = Settlement.UndergroundEntryRuntime.REFUSE_SURFACE_ARRIVAL
	assert_false(entry.is_leaving(), "a refused leave (another code than G9) is over")
	entry._error = Settlement.UndergroundEntryRuntime.REFUSE_KITCHEN_UNBUILT
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
	"""Walk-out records the leave never writes are refused on restore: one claiming H's arrival heading (a walk in),
	and one holding another code than G9 (a refused leave walks nowhere: review M1)."""
	_assert_refused_record(entry, entry._foreman.arrival_yaw(), entry._error, entry._walk_left,
		"a finished crew's walk out keeps its own heading")
	_assert_refused_record(entry, -1, Settlement.UndergroundEntryRuntime.REFUSE_SURFACE_ARRIVAL, entry._walk_left,
		"a refused leave has no walk")


func _assert_refused_record(entry: Settlement.UndergroundEntryRuntime, yaw: int, code: StringName, walk: int,
		why: String) -> void:
	"""Capture the runtime with its walk fields set as given (then put back), and expect the restore to refuse it."""
	var bytes: PackedByteArray = PackedByteArray()
	var kept: Array = [entry._arrival_yaw, entry._error, entry._walk_left]
	entry._arrival_yaw = yaw
	entry._error = code
	entry._walk_left = walk
	assert_equal(entry.capture(bytes), &"", "captured")
	entry._arrival_yaw = kept[0]
	entry._error = kept[1]
	entry._walk_left = kept[2]
	var fresh: Settlement.UndergroundEntryRuntime = Settlement.UndergroundEntryRuntime.new()
	assert_equal(fresh.restore(bytes, _host.underground_session()), Progress.REFUSE_SHAPE, why)


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
