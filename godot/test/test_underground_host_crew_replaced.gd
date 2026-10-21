extends "res://test/underground_host_case.gd"
## The live entry chain's crew replaced: lost mid-haul, lost mid-phase, and tired at a resting point (DEC-059's shift
## change), each run on to the end of the prefix. Split from test_underground_host.gd so CI can shard them apart
## (decision 2044, CI time); fixture: underground_host_case.gd.


func test_a_crew_lost_mid_haul_is_replaced_and_the_entry_resumes_where_it_stopped() -> void:
	"""ADR1225 (Brendan: replace the crew): the crew dies after its first trip, while its second unit is admitted.
	The loss tick cancels that admission, retires the HAUL Job, releases the dead mole's Job and unregisters its
	actor; the spare mole becomes the crew, walks to H, is registered there, hauls what M still lacks and carries
	the step on. The entry ends at the same gap with the same paid ledgers as an uninterrupted run."""
	var live: Array = _live_with_spare()
	var o: Session.Retirement.Owners = live[0]
	var entry: Settlement.UndergroundEntryRuntime = live[1]
	var tick: int = _run_until(entry, 1, _first_trip_done.bind(entry))
	var lost_row: int = o.residents.directory().get_typed_row(live[2])
	_kill(o, live[2])
	assert_equal(entry.advance(tick), Jobs.REFUSE_RESIDENT_DEAD, "the loss is alerted once, as G6")
	assert_true(entry.is_running() and entry.crew().worker == live[3], "the spare mole is the crew; the chain runs")
	assert_true(entry.walk_ticks_left() > 0, "it walks in from the surface (ADR1219)")
	assert_true(o.routes._lost_actor_row(live[2]) < 0, "the lost actor is unregistered (ADR1225)")
	assert_equal(o.jobs.job_of(lost_row), Jobs.NULL_REF, "the lost mole holds no Job")
	assert_equal(o.jobs.worker_of(entry._foreman._job), Jobs.NULL_REF, "the step's BUILD Job is parked for the spare")
	assert_true(entry.reserves_resident(o.residents.directory().get_typed_row(live[3])), "the reservation moved")
	tick = _run_until(entry, tick + 1, _prefix_done.bind(entry))
	assert_true(entry.is_running() and _prefix_done(entry), "the resumed entry finishes the prefix")
	assert_equal(_done_ledger(o, entry._foreman), DONE_LEDGER,
		"every phase settled and both groups installed once, with the same Work and the same hauled units")
	assert_equal(entry.crew().worker, live[3], "the replacement finished it")


func test_a_crew_lost_mid_phase_is_replaced_and_the_paid_phase_is_not_paid_again() -> void:
	"""ADR1225: the crew dies mid-CUT, after the paid START. Sites' own departure path releases it; the replacement
	walks in, is bound to the same phase and resumes its Work (resume_phase_work), so the inputs are consumed once
	and the phase's Work total is unchanged."""
	var live: Array = _live_with_spare()
	var o: Session.Retirement.Owners = live[0]
	var entry: Settlement.UndergroundEntryRuntime = live[1]
	var tick: int = _run_until(entry, 1, _earning_the_first_cut.bind(entry))
	_kill(o, live[2])
	assert_equal(entry.advance(tick), Jobs.REFUSE_RESIDENT_DEAD, "the loss is alerted")
	assert_equal(entry._foreman._stage, entry._foreman.STAGE_RESUME, "the step waits for the replacement")
	tick = _run_until(entry, tick + 1, _prefix_done.bind(entry))
	assert_true(entry.is_running() and _prefix_done(entry), "the resumed entry finishes the prefix")
	assert_equal(_done_ledger(o, entry._foreman), DONE_LEDGER, "no Work paid twice or lost")


func _earning_the_first_cut(entry: Settlement.UndergroundEntryRuntime) -> bool:
	"""The crew is a few ticks into the paid Work of the first CUT (task 1)."""
	var foreman: RefCounted = entry._foreman
	return foreman._index == 1 and foreman._stage == foreman.STAGE_EARN and foreman._stage_ticks > 5


func test_a_tired_crew_changes_shift_at_a_resting_point_and_a_rested_mole_carries_on() -> void:
	"""DEC-059 shift change: the crew starts with rest just above its GDD 5.2 seek line (2,500). When rest reaches
	it, the crew hands over at its next resting point by ADR1225's path: it is released alive where it stands (no
	Job, unreserved, unregistered) to eat or sleep; the rested spare walks in and the prefix ends with the same
	ledger. The tired mole is not picked while it is tired, and is again once it has recovered."""
	var live: Array = _live_with_spare()
	var o: Session.Retirement.Owners = live[0]
	var entry: Settlement.UndergroundEntryRuntime = live[1]
	var tired: int = o.residents.directory().get_typed_row(live[2])
	o.jobs.needs()._need_value[tired * Needs.NEED_COUNT + Needs.NEED_REST] = Needs.REST_SEEK_SLEEP_THRESHOLD + 375
	var tick: int = _run_until(entry, 1, func() -> bool: return entry.crew().worker != live[2])
	assert_true(entry.is_running() and entry.crew().worker == live[3], "the rested spare is the crew: %s" % entry.error())
	assert_true(o.jobs.needs().need_of(tired, Needs.NEED_REST).value <= Needs.REST_SEEK_SLEEP_THRESHOLD, "it was tired")
	assert_true(o.residents.is_alive(tired), "the tired mole is alive")
	assert_equal(o.routes._resident_ref(tired), Vector2i(-1, 0), "and no longer an underground route actor")
	assert_false(entry.reserves_resident(tired), "nor reserved by the entry")
	var found: Array[Vector2i] = []
	var code: StringName = Settlement.UndergroundEntryRuntime._idle_mole(o, found)
	assert_true(code != &"" or found[0] != live[2], "a tired mole is not picked")
	var surface: Transforms.Pose = Transforms.Pose.new()
	assert_true(o.transforms.read_into(live[2], surface) and surface.y >= 0, "it left the work area for the surface")
	o.jobs.needs()._need_value[tired * Needs.NEED_COUNT + Needs.NEED_REST] = 9000
	if o.jobs.job_of(tired) == Jobs.NULL_REF and not o.residents.has_equipped_tool(tired):
		found.clear()
		assert_true(Settlement.UndergroundEntryRuntime._seeking(o.jobs.needs(), tired) == false, "rested again")
	tick = _run_until(entry, tick, _prefix_done.bind(entry))
	assert_true(entry.is_running() and _prefix_done(entry), "the spare finishes the prefix: %s" % entry.error())
	assert_equal(_done_ledger(o, entry._foreman), DONE_LEDGER, "with the same ledgers")
