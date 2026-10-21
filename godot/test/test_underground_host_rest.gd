extends "res://test/underground_host_case.gd"
## The live entry chain's crew resting at a resting point (ADR1226): through a sleep hour, and at a haul stand, each
## run on to the end of the prefix. Split from test_underground_host.gd so CI can shard them apart (decision 2044, CI
## time); fixture: underground_host_case.gd.


func _sleep_at_eight(o: Session.Retirement.Owners, worker: Vector2i) -> void:
	"""The crew's 08:00 hour (ticks 1500-2249 of day 1) becomes SLEEP."""
	var row: int = o.residents.directory().get_typed_row(worker)
	assert_true(o.jobs.schedule().set_hour_activity(row, 8, Schedule.ACTIVITY_SLEEP).ok, "08:00 is SLEEP")


func _run_to(entry: Settlement.UndergroundEntryRuntime, from: int, to: int) -> int:
	"""run_tick for every tick in [from, to) while the entry runs; returns the next tick to run."""
	var tick: int = from
	while entry.is_running() and tick < to:
		assert_true(_host.run_tick(tick), "the settlement tick itself never fails: %s" % _host.last_refusal())
		tick += 1
	return tick


func test_the_busy_crew_rests_at_a_resting_point_through_its_sleep_hour_and_resumes() -> void:
	"""ADR1226 (DEC-055, REQ-SET-034): the crew holds its entry Jobs all day. When its 08:00 hour turns to SLEEP it
	finishes its current safe segment, stops at a resting point (ADR1210's switch-at-rest state) and earns nothing
	while it rests. At 09:00 it resumes and finishes the prefix with the same ledgers, later."""
	var live: Array = _begin_live_entry(_sleep_at_eight)
	var o: Session.Retirement.Owners = live[0]
	var entry: Settlement.UndergroundEntryRuntime = live[1]
	var tick: int = _run_to(entry, 1, 2100)
	var resting: int = entry._foreman.accepted_mwu()
	tick = _run_to(entry, tick, 2200)
	assert_true(entry.is_running() and entry._crew_at_rest(), "at 2200 the crew stands at a resting point")
	assert_true(o.jobs.job_of(o.residents.directory().get_typed_row(live[2])) != Jobs.NULL_REF, "still holding its Job")
	tick = _run_to(entry, tick, 2250)
	assert_equal(entry._foreman.accepted_mwu(), resting, "no Work while it rests")
	tick = _run_until(entry, tick, _prefix_done.bind(entry))
	assert_true(entry.is_running() and _prefix_done(entry), "it resumes and finishes the prefix")
	assert_equal(_done_ledger(o, entry._foreman), DONE_LEDGER, "with the same ledgers")
	assert_true(tick - 1 > DONE_TICK, "later, by the rest")


func _lifting(entry: Settlement.UndergroundEntryRuntime) -> bool:
	"""The foreman's hauler has just reached R's stand and selected its lift."""
	var hauler: RefCounted = entry._foreman._hauler
	return hauler != null and hauler.stage() == hauler.STAGE_LIFT


func _set_rest(o: Session.Retirement.Owners, row: int, hour: int, activity: int) -> void:
	"""The crew's hour, and its already resolved activity, become `activity`."""
	assert_true(o.jobs.schedule().set_hour_activity(row, hour, activity).ok, "hour %d set" % hour)
	o.jobs.schedule()._current_activity[row] = activity


func test_a_rest_at_a_haul_stand_lets_the_lift_finish_and_the_haul_carries_on() -> void:
	"""ADR1226 for the hauler (REQ-SET-034): the crew's hour turns to SLEEP as it selects its lift at R's stand, a
	resting point, so the entry pauses there. The lift's HAUL Job is in WORK and its 2 WU are not a safe point, so
	the settlement's ProductiveWork finishes it while the entry waits. When the hour permits work again the hauler
	finds the Job done and loads the unit instead of refusing ENTRY_HAUL_WORK; the prefix ends with the same ledger."""
	var live: Array = _begin_live_entry()
	var o: Session.Retirement.Owners = live[0]
	var entry: Settlement.UndergroundEntryRuntime = live[1]
	var row: int = o.residents.directory().get_typed_row(live[2])
	var tick: int = _run_until(entry, 1, _lifting.bind(entry))
	var hauler: RefCounted = entry._foreman._hauler
	var hour: int = _host._hour_of(tick)
	var before: int = o.jobs.schedule().hour_activity_of(row, hour).value
	_set_rest(o, row, hour, Schedule.ACTIVITY_SLEEP)
	tick = _run_to(entry, tick, tick + 60)
	assert_true(entry.is_running() and entry._crew_at_rest(), "the crew rests at R's stand: %s" % entry.error())
	assert_equal(hauler.stage(), hauler.STAGE_LIFT, "the entry advanced nothing while it rested")
	var left: IntMath.IntResult = IntMath.IntResult.new()
	assert_true(o.jobs.remaining_mwu_into(hauler._job, left) and left.value == 0, "the lift's Work finished meanwhile")
	_set_rest(o, row, hour, before)
	tick = _run_until(entry, tick, _prefix_done.bind(entry))
	assert_true(entry.is_running() and _prefix_done(entry), "the haul carried on: %s" % entry.error())
	assert_equal(_done_ledger(o, entry._foreman), DONE_LEDGER, "with the same ledgers")
