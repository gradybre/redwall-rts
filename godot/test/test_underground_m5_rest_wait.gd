extends "res://test/underground_host_case.gd"
## Decision 2045 (P-2045-10 (a)): on a real schedule, the M5 chain's crew climbs off landing 1 for module 1's T0'
## order and reaches X in a rest hour (tick 45,414 on the generated settlement). Holding the order's Job it waits there
## for a work hour, then carries on with the same order: the chain never ends with STEP2_ACTIVITY_FORBIDS_WORK and the
## order is not restarted. Needs and R's stock are sustained as the whole-flight suites sustain them; the schedule is not.

const Installer := preload("res://scripts/core/underground_entry_installer.gd")
## Past the rest hour that the climb reaches at tick 45,414, and the work hour after it.
const WAIT_TICK_LIMIT: int = 50000


func test_a_crew_back_at_x_in_a_rest_hour_waits_and_resumes_the_same_order() -> void:
	"""The crew waits at X with the order's Job through the rest hour, then the same order goes on to its haul."""
	var live: Array = _begin_live_entry()
	var o: Session.Retirement.Owners = live[0]
	var entry: Settlement.UndergroundEntryRuntime = live[1]
	var waited: int = 0
	var order: Vector2i = Vector2i(-1, 0)
	var resumed: bool = false
	var tick: int = 1
	while entry.is_running() and tick < WAIT_TICK_LIMIT and not resumed:
		_sustain(o, entry, tick)
		assert_true(_host.run_tick(tick), "tick %d" % tick)
		var installer: Installer = entry._foreman._installer if entry._foreman != null else null
		if installer != null and installer._stage == Installer.STAGE_LEG_UPS and _resting(o, entry) \
				and 4 * (installer._stair_leg + 1) >= installer._plan.ups.size():
			waited += 1
			order = installer._project
		elif waited > 0 and installer != null:
			resumed = installer._project == order and installer._stage != Installer.STAGE_LEG_UPS
		tick += 1
	assert_true(entry.is_running(), "the chain is still running: %s" % entry.error())
	assert_true(waited > 1, "the crew waited at X through the rest hour (%d ticks)" % waited)
	assert_true(resumed, "the same order went on after the rest hour")


func _resting(o: Session.Retirement.Owners, entry: Settlement.UndergroundEntryRuntime) -> bool:
	"""The crew's resolved hour forbids work."""
	return o.jobs.schedule().rests_now(o.residents.directory().get_typed_row(entry._foreman._crew.worker))
