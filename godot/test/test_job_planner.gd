extends "res://test/framework/test_case.gd"
## Coverage for `scripts/core/job_planner.gd`: ARCH-SYS-009's dirty/reconcile mechanism
## (R06-JOB-008) and the daily FARM tending producer (R06-JOB-007).
##
## THE RULING'S ACCEPTANCE LIST IS THE TEST LIST. Every item in
## `docs/rulings/2026-09-09_ready06_open_item_answers.md` §1 that has an implementable owner has a
## named method here: repeated enable/dirty events create no duplicate service; two workers cannot
## spend the same claim; sources that are not in a serviceable condition create no new work;
## midnight recovery resumes demand; service is once per day including across a load/rebuild and a
## worker replacement; capacity exhaustion retains demand, reports a blocker and retries on
## release without an unbounded queue.
##
## THE CONSTANTS ARE TRANSCRIBED FROM THE DOCUMENTS, not read back out of the module. The service
## work total is §5.6's "1 WU tending/day while growing" written as 1000 milli-WU, the default is
## the ruling's own "priority 3", and the day arithmetic is GDD §5.1's offset calendar -- the
## first midnight is tick 13500, which is written here as a literal so a module that switched to
## `tick % 18000` would fail rather than agree with itself.

const IntMath := preload("res://scripts/core/int_math.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")
const JobsScript := preload("res://scripts/core/jobs.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")
const PrioritiesScript := preload("res://scripts/core/priorities.gd")
const ScheduleScript := preload("res://scripts/core/schedule.gd")
const JobPlannerScript := preload("res://scripts/core/job_planner.gd")

## GDD §5.1's offset calendar, transcribed: tick 0 is 06:00 of day 1 and the FIRST MIDNIGHT is
## tick 13500. Day N therefore begins at 13500 + (N-2)*18000 for N >= 2.
const FIRST_MIDNIGHT_TICK: int = 13500
const TICKS_PER_DAY: int = 18000
## A mid-morning tick inside day 1.
const DAY_ONE_TICK: int = 600
## §5.6 "1 WU tending/day while growing", in milli-WU.
const TENDING_MILLI_WU: int = 1000
## The ruling: "ordinary newly generated work has priority 3".
const ORDINARY_PRIORITY: int = 3
## §4.3 JobKind FARM and the four §4.3 JobStates this suite names, transcribed from the GDD's
## own numbering: HAUL 0, BUILD 1, FISH 2, RESERVED_3 3, FORAGE 4, FARM 5.
const KIND_FARM: int = 5
const STATE_QUEUED: int = 0
const STATE_WORK: int = 3
const STATE_COMPLETE: int = 5
const STATE_CANCELLED: int = 7
## farming.gd's §4.3 CropState values, transcribed from the GDD's own ordering.
const CROP_EMPTY: int = 0
const CROP_GROWING: int = 2
## §5.6: grain is loam/clay/sand-restricted with a spring day 1-4 window and a 3500 moisture
## minimum, so a plot at the 6000 starting moisture needs no water and one at 3000 does.
const GRAIN: int = 3
const LOAM: int = 0
const SPRING: int = 0
const SUMMER: int = 1
const TEND_OPERATION: int = 0
const SOW_OPERATION: int = 1
## §5.6 "4 WU sowing", in milli-WU, and BAL-CROP-001's "250 milli-U/tile at sow start".
const SOWING_MILLI_WU: int = 4000
const SEED_MILLI: int = 250
## §5.6's soils: SAND admits flax and roots but NOT grain, which is loam/clay only.
const SAND: int = 2
## §5.6's crop ids in §4.3's ASCII order: beans 0, cabbage 1, flax 2, grain 3, roots 4.
const FLAX: int = 2
const ROOTS: int = 4
## §4.3 CropState SOWN, between EMPTY and GROWING.
const CROP_SOWN: int = 1
## jobs.gd's §4.2 input-gate values: 0 not required, 3 declared but unanswerable.
const GATE_NOT_REQUIRED: int = 0
const GATE_UNAVAILABLE: int = 3

var _residents: ResidentsScript = null
var _priorities: PrioritiesScript = null
var _schedule: ScheduleScript = null
var _jobs: JobsScript = null
var _farming: FarmingScript = null
var _planner: JobPlannerScript = null


func before_each() -> void:
	"""Build one consistent set of stores sharing a single entity directory."""
	_residents = ResidentsScript.new()
	_priorities = PrioritiesScript.new()
	_schedule = ScheduleScript.new(_residents.needs())
	_jobs = JobsScript.new(_residents, _priorities, _schedule)
	_farming = FarmingScript.new(_jobs.directory())
	_planner = JobPlannerScript.new(_farming, _jobs)


func after_each() -> void:
	"""Drop every store so no test inherits another's rows."""
	_planner = null
	_farming = null
	_jobs = null
	_schedule = null
	_priorities = null
	_residents = null


# --- fixtures ------------------------------------------------------------------------------------

func _growing_plot(tile: int = 100) -> int:
	"""Create a loam plot, sow grain in its spring window and finish sowing. Returns its slot."""
	var created: FarmingScript.OpResult = _farming.create_plot_at_tile(tile, LOAM, 1)
	assert_true(created.ok, "the plot creates (error: %s)" % created.error)
	var slot: int = created.value
	assert_true(_farming.plant(slot, GRAIN, 1, SPRING, 1).ok, "grain plants in its window")
	assert_true(_farming.begin_growing(slot).ok, "the sowing work finishes")
	return slot


func _worker() -> int:
	"""Spawn a resident in a WORK hour with a JobAgent row, and return its resident slot."""
	var spawned: ResidentsScript.OpResult = _residents.spawn(&"mouse")
	assert_true(spawned.ok, "resident spawns (error: %s)" % spawned.error)
	var slot: int = spawned.value
	assert_true(_priorities.spawn(slot).ok, "priorities row spawns")
	var template: IntMath.IntResult = _schedule.default_template_id()
	assert_true(_schedule.spawn(slot, template.value).ok, "schedule row spawns")
	assert_true(_schedule.resolve(slot, 8, false).ok, "the WORK hour resolves")
	assert_true(_jobs.spawn_agent(slot).ok, "the job agent spawns")
	return slot


func _service_job_slot(owner_slot: int) -> int:
	"""The typed Job row of this owner's pending tending service, asserting one exists."""
	var ref: Vector2i = _planner.service_job_of(owner_slot, TEND_OPERATION)
	assert_true(ref != EntityDirectory.NULL_REF, "the owner has a pending service job")
	return _jobs.directory().get_typed_row(ref)


func _day_start_tick(day: int) -> int:
	"""First tick of an absolute day under the offset calendar, computed from the GDD, not the module."""
	return FIRST_MIDNIGHT_TICK + (day - 2) * TICKS_PER_DAY


# --- R06-JOB-007: the daily tending producer -----------------------------------------------------

func test_a_growing_plot_receives_one_tending_service_for_its_day() -> void:
	"""R06-JOB-007: a GROWING plot entering a day with no completed or pending tending gets one."""
	var plot: int = _growing_plot()
	var result: JobPlannerScript.OpResult = _planner.reconcile_plot(plot, DAY_ONE_TICK)
	assert_true(result.ok, "the service is created (error: %s)" % result.error)
	assert_equal(_jobs.job_count(), 1, "exactly one job exists")
	assert_equal(_planner.created_count(), 1, "the planner counts one creation")
	var job: int = _service_job_slot(plot)
	assert_equal(_jobs.kind_of(job).value, KIND_FARM, "a tending service is a FARM job")
	assert_equal(_jobs.remaining_mwu_of(job).value, TENDING_MILLI_WU, "it is §5.6's 1 WU")


func test_the_service_carries_the_rulings_priority_three_default() -> void:
	"""The ruling: ordinary newly generated work has priority 3."""
	var plot: int = _growing_plot()
	assert_true(_planner.reconcile_plot(plot, DAY_ONE_TICK).ok, "the service is created")
	var job: int = _service_job_slot(plot)
	assert_equal(_jobs.priority_of(job).value, ORDINARY_PRIORITY, "job priority is 3")
	assert_equal(_jobs.urgency_of(job).value, JobsScript.URGENCY_ORDINARY,
		"the urgency bucket stays ordinary, which is a different field from job priority")
	assert_equal(_farming.harvest_job_priority(), 2,
		"REQ-SET-073's explicit priority-2 ripe harvest is preserved, not overwritten")


func test_the_service_names_its_plot_as_the_source_and_no_destination() -> void:
	"""The plot is the work's source; tending delivers nothing and no reachability oracle exists."""
	var plot: int = _growing_plot()
	assert_true(_planner.reconcile_plot(plot, DAY_ONE_TICK).ok, "the service is created")
	var job: int = _service_job_slot(plot)
	assert_equal(_jobs.source_of(job), _farming.ref_of(plot), "source is the plot's EntityRef")
	assert_equal(_jobs.destination_of(job), EntityDirectory.NULL_REF, "destination stays null")


func test_a_created_service_stays_queued_and_is_never_written_into_work() -> void:
	"""The ruling: creating a job does not authorize teleporting its worker into WORK."""
	var plot: int = _growing_plot()
	assert_true(_planner.reconcile_plot(plot, DAY_ONE_TICK).ok, "the service is created")
	var job: int = _service_job_slot(plot)
	assert_equal(_jobs.state_of(job).value, STATE_QUEUED, "a new service is QUEUED")
	_planner.run_tick(DAY_ONE_TICK)
	assert_equal(_jobs.state_of(job).value, STATE_QUEUED, "a planner tick does not advance it")
	assert_true(_jobs.state_of(job).value != STATE_WORK, "nothing here writes JOB_STATE_WORK")


func test_a_dry_plot_declares_the_water_input_a_wet_one_does_not() -> void:
	"""§5.6's moisture condition: water is required only below the crop's stated minimum."""
	var wet: int = _growing_plot(100)
	assert_true(_planner.reconcile_plot(wet, DAY_ONE_TICK).ok, "the wet plot is serviced")
	assert_false(_planner.service_requires_water(wet, TEND_OPERATION), "6000 needs no water")
	assert_equal(_jobs.inputs_gate_of(_service_job_slot(wet)).value, JobsScript.GATE_NOT_REQUIRED,
		"a wet plot's service declares no input requirement")
	var dry: int = _growing_plot(101)
	assert_true(_farming.apply_moisture_delta(dry, -3000).ok, "moisture drops to 3000")
	assert_true(_planner.reconcile_plot(dry, DAY_ONE_TICK).ok, "the dry plot is serviced")
	assert_true(_planner.service_requires_water(dry, TEND_OPERATION), "3000 is below grain's 3500")
	assert_equal(_jobs.inputs_gate_of(_service_job_slot(dry)).value, JobsScript.GATE_UNAVAILABLE,
		"the declared water input has no supplier, so the gate cannot answer")


func test_a_plot_in_any_state_but_growing_creates_no_work() -> void:
	"""R06-JOB-007 triggers on GROWING alone; harvest and clearing keep REQ-SET-073/085."""
	var created: FarmingScript.OpResult = _farming.create_plot_at_tile(200, LOAM, 1)
	var empty: int = created.value
	assert_equal(_farming.state_of(empty).value, CROP_EMPTY, "a fresh plot is EMPTY")
	assert_equal(_planner.reconcile_plot(empty, DAY_ONE_TICK).error,
		JobPlannerScript.REFUSE_NOT_GROWING, "an EMPTY plot creates nothing")
	assert_true(_farming.plant(empty, GRAIN, 1, SPRING, 1).ok, "the plot is sown")
	assert_equal(_planner.reconcile_plot(empty, DAY_ONE_TICK).error,
		JobPlannerScript.REFUSE_NOT_GROWING, "a SOWN plot creates nothing until sowing finishes")
	assert_equal(_jobs.job_count(), 0, "no job exists in either state")


func test_an_absent_owner_creates_no_work() -> void:
	"""A slot with no plot is addressable but not serviceable."""
	assert_equal(_planner.reconcile_plot(0, DAY_ONE_TICK).error,
		JobPlannerScript.REFUSE_OWNER_NOT_PRESENT, "an empty slot refuses as not present")
	assert_equal(_jobs.job_count(), 0, "and creates nothing")


# --- R06-JOB-008: idempotence --------------------------------------------------------------------

func test_repeated_dirty_events_create_no_duplicate_service() -> void:
	"""The ruling's first acceptance item, on the marking half and the reconciling half."""
	var plot: int = _growing_plot()
	for _repeat: int in 8:
		assert_true(_planner.mark_plot_dirty(plot).ok, "the owner is marked dirty")
	assert_equal(_planner.dirty_count(), 1, "eight dirty events make one entry, not eight")
	_planner.run_tick(DAY_ONE_TICK)
	for _repeat: int in 8:
		assert_equal(_planner.reconcile_plot(plot, DAY_ONE_TICK).error,
			JobPlannerScript.REFUSE_SERVICE_PENDING, "a repeat reconcile refuses as pending")
	assert_equal(_jobs.job_count(), 1, "exactly one job exists after sixteen events")
	assert_equal(_planner.created_count(), 1, "exactly one service was created")


func test_a_repeated_tick_creates_no_duplicate_service() -> void:
	"""Reevaluation is idempotent across whole planner ticks, not just direct reconciles."""
	var plot: int = _growing_plot()
	for tick: int in range(0, 300):
		_planner.mark_plot_dirty(plot)
		_planner.run_tick(tick)
	assert_equal(_planner.created_count(), 1, "three hundred ticks create one service")
	assert_equal(_planner.pending_service_count(), 1, "one pending row, not three hundred")


func test_the_dirty_set_cannot_grow_past_one_entry_per_owner() -> void:
	"""R06-JOB-008: no hidden unbounded queue, on the dirty half."""
	var plot: int = _growing_plot()
	for _repeat: int in 5000:
		_planner.mark_plot_dirty(plot)
	assert_equal(_planner.dirty_count(), 1, "five thousand events, one entry")
	assert_true(_planner.is_plot_dirty(plot), "and the owner is still marked")


func test_a_completed_service_blocks_a_second_one_the_same_day() -> void:
	"""R06-JOB-007: a plot with COMPLETED tending gets no second service that day."""
	var plot: int = _growing_plot()
	assert_true(_planner.reconcile_plot(plot, DAY_ONE_TICK).ok, "the service is created")
	assert_true(_jobs.set_state(_service_job_slot(plot), STATE_COMPLETE).ok, "the work completes")
	assert_equal(_planner.reconcile_plot(plot, DAY_ONE_TICK).error,
		JobPlannerScript.REFUSE_SERVICE_ALREADY_COMPLETE, "the same day refuses as complete")
	assert_equal(_planner.completed_count(), 1, "the completion is recorded once")
	assert_equal(_planner.last_serviced_day_of(plot, TEND_OPERATION).value, 1,
		"the durable history names absolute day 1")
	assert_equal(_jobs.job_count(), 0, "the finished service's row is released")


func test_a_cancelled_service_is_recorded_rather_than_read_as_completed() -> void:
	"""The ruling: a cancelled cycle needs a recorded cancellation, not a fabricated completion."""
	var plot: int = _growing_plot()
	assert_true(_planner.reconcile_plot(plot, DAY_ONE_TICK).ok, "the service is created")
	assert_true(_jobs.set_state(_service_job_slot(plot), STATE_CANCELLED).ok, "it is cancelled")
	assert_true(_planner.reconcile_plot(plot, DAY_ONE_TICK).ok, "demand reopens the same day")
	assert_equal(_planner.cancelled_count(), 1, "the cancellation is counted")
	assert_equal(_planner.last_serviced_day_of(plot, TEND_OPERATION).value,
		JobPlannerScript.NO_DAY, "and no completion was fabricated for that day")


# --- the pending-service identity ----------------------------------------------------------------

func test_the_service_row_is_the_owner_major_index_of_the_ruling() -> void:
	"""`service_row = owner*OPERATION_COUNT + operation`, the ruling's owner-major child index.

	UPDATED for R06-JOB-004 (decision 0040): the operation domain is two, because the sowing
	cycle now has a row beside the daily tending service. The stride is OPERATION_COUNT;
	DAILY_SERVICE_OPERATION_COUNT is still one and now counts only the operations midnight
	reopens. The 4096 owners are farming.gd's FarmPlot capacity and are unchanged.
	"""
	assert_equal(JobPlannerScript.OPERATION_COUNT, 2,
		"tending and sowing are the two operations with an owner store in this build")
	assert_equal(JobPlannerScript.DAILY_SERVICE_OPERATION_COUNT, 1,
		"only the FARM tending operation reopens every midnight")
	assert_equal(_planner.service_row(0, TEND_OPERATION).value, 0, "the first owner's tend row")
	assert_equal(_planner.service_row(0, SOW_OPERATION).value, 1, "its sowing row sits beside it")
	assert_equal(_planner.service_row(4095, TEND_OPERATION).value, 8190, "the last owner's tend row")
	assert_equal(_planner.service_row(4095, SOW_OPERATION).value, 8191, "and its sowing row")
	assert_equal(JobPlannerScript.SERVICE_ROW_COUNT, 8192, "one row per owner per operation")
	assert_false(_planner.service_row(4096, TEND_OPERATION).ok, "an off-store owner refuses")
	assert_false(_planner.service_row(0, 2).ok, "an unimplemented operation refuses")


func test_the_service_day_is_the_offset_calendars_absolute_day() -> void:
	"""GDD §5.1: the first midnight is tick 13500, never `tick % 18000 == 0`."""
	assert_equal(JobPlannerScript.absolute_day_of_tick(0), 1, "tick 0 is day 1")
	assert_equal(JobPlannerScript.absolute_day_of_tick(13499), 1, "tick 13499 is still day 1")
	assert_equal(JobPlannerScript.absolute_day_of_tick(FIRST_MIDNIGHT_TICK), 2,
		"tick 13500 is the first midnight and opens day 2")
	assert_equal(JobPlannerScript.absolute_day_of_tick(TICKS_PER_DAY), 2,
		"tick 18000 is 06:00 of day 2, not a boundary")
	var plot: int = _growing_plot()
	assert_true(_planner.reconcile_plot(plot, 13499).ok, "a late day-1 tick is serviced")
	assert_equal(_planner.service_day_of(plot, TEND_OPERATION).value, 1,
		"and the service belongs to day 1")


func test_a_reused_owner_row_does_not_inherit_a_live_service() -> void:
	"""The identity carries the owner's GENERATION, not just its typed row.

	The old plot's service Job is deliberately left alive across the redraw: a planner that
	compared only the row and the day would hand the new plot the previous owner's Job, whose
	source points at a destroyed reference.
	"""
	var plot: int = _growing_plot()
	assert_true(_planner.reconcile_plot(plot, DAY_ONE_TICK).ok, "the first plot is serviced")
	var stale: Vector2i = _planner.service_job_of(plot, TEND_OPERATION)
	var old_generation: int = _farming.ref_of(plot).y
	assert_true(_farming.destroy(_farming.ref_of(plot)).ok, "the plot is destroyed")
	var recreated: int = _growing_plot(100)
	assert_equal(recreated, plot, "the typed row is reused")
	assert_true(_farming.ref_of(recreated).y != old_generation, "with a new generation")
	assert_true(_planner.reconcile_plot(recreated, DAY_ONE_TICK).ok,
		"the new plot gets its own service rather than inheriting the old row")
	assert_true(_planner.service_job_of(recreated, TEND_OPERATION) != stale,
		"and it is a different Job from the destroyed owner's")
	assert_equal(_planner.created_count(), 2, "two distinct services were created")
	assert_equal(_jobs.job_count(), 1, "the inherited Job was settled, not left alive")


# --- once per day across a worker replacement and a load ------------------------------------------

func test_a_worker_replacement_preserves_the_same_job_and_creates_no_second_service() -> void:
	"""The ruling: worker changes preserve the same Job and WIP."""
	var plot: int = _growing_plot()
	assert_true(_planner.reconcile_plot(plot, DAY_ONE_TICK).ok, "the service is created")
	var job: int = _service_job_slot(plot)
	var first: int = _worker()
	assert_true(_jobs.assign_worker(first, job).ok, "the first worker takes it")
	assert_true(_jobs.consume_remaining_mwu_into(job, 400, IntMath.IntResult.new()),
		"four hundred milli-WU of progress is made")
	assert_true(_jobs.release_worker(first).ok, "the first worker leaves")
	var second: int = _worker()
	assert_true(_jobs.assign_worker(second, job).ok, "a replacement takes the same job")
	assert_equal(_planner.reconcile_plot(plot, DAY_ONE_TICK).error,
		JobPlannerScript.REFUSE_SERVICE_PENDING, "no second service is created")
	assert_equal(_service_job_slot(plot), job, "the service still names the same Job row")
	assert_equal(_jobs.remaining_mwu_of(job).value, 600, "and its work in progress is preserved")


func test_two_workers_cannot_spend_the_same_service_claim() -> void:
	"""The ruling: two workers cannot spend the same claim. One service, one worker."""
	var plot: int = _growing_plot()
	assert_true(_planner.reconcile_plot(plot, DAY_ONE_TICK).ok, "the service is created")
	var job: int = _service_job_slot(plot)
	var first: int = _worker()
	var second: int = _worker()
	assert_true(_jobs.assign_worker(first, job).ok, "the first worker takes the service")
	assert_equal(_jobs.assign_worker(second, job).error, JobsScript.REFUSE_JOB_HAS_WORKER,
		"the second worker is refused the same service")
	_planner.reconcile_plot(plot, DAY_ONE_TICK)
	assert_equal(_jobs.job_count(), 1, "and reconciling produces no second job for them to take")


func test_service_is_once_per_day_across_a_load_and_revalidation() -> void:
	"""The ruling: service is once per day including load/rebuild."""
	var plot: int = _growing_plot()
	assert_true(_planner.reconcile_plot(plot, DAY_ONE_TICK).ok, "the service is created")
	var dropped: IntMath.IntResult = _planner.revalidate_after_load()
	assert_equal(dropped.value, 0, "a live service survives revalidation")
	assert_equal(_planner.reconcile_plot(plot, DAY_ONE_TICK).error,
		JobPlannerScript.REFUSE_SERVICE_PENDING, "and is still the day's one service")
	assert_equal(_jobs.job_count(), 1, "no duplicate was created across the load")


func test_completion_history_survives_a_load_when_the_pending_row_does_not() -> void:
	"""Completion history may not be discarded; it is what keeps once-per-day true after a rebuild."""
	var plot: int = _growing_plot()
	assert_true(_planner.reconcile_plot(plot, DAY_ONE_TICK).ok, "the service is created")
	assert_true(_jobs.set_state(_service_job_slot(plot), STATE_COMPLETE).ok, "it completes")
	assert_true(_planner.reconcile_plot(plot, DAY_ONE_TICK).error ==
		JobPlannerScript.REFUSE_SERVICE_ALREADY_COMPLETE, "the day is closed")
	assert_equal(_planner.revalidate_after_load().value, 0, "revalidation drops nothing")
	assert_equal(_planner.last_serviced_day_of(plot, TEND_OPERATION).value, 1,
		"the completed day survives the load")
	assert_equal(_planner.reconcile_plot(plot, DAY_ONE_TICK).error,
		JobPlannerScript.REFUSE_SERVICE_ALREADY_COMPLETE, "and still blocks a second service")


func test_a_vanished_service_job_is_dropped_and_demand_reopens_exactly_once() -> void:
	"""A pending row pointing at a Job that no longer resolves is repaired, not trusted."""
	var plot: int = _growing_plot()
	assert_true(_planner.reconcile_plot(plot, DAY_ONE_TICK).ok, "the service is created")
	assert_true(_jobs.destroy_job(_service_job_slot(plot)).ok, "its Job is released out of band")
	assert_equal(_planner.revalidate_after_load().value, 1, "revalidation drops the stale row")
	assert_equal(_planner.pending_service_count(), 0, "no pending service remains")
	assert_true(_planner.reconcile_plot(plot, DAY_ONE_TICK).ok, "demand reopens")
	assert_equal(_planner.reconcile_plot(plot, DAY_ONE_TICK).error,
		JobPlannerScript.REFUSE_SERVICE_PENDING, "exactly once")


# --- midnight ordering and recovery ---------------------------------------------------------------

func test_midnight_settles_the_preceding_day_before_opening_the_new_one() -> void:
	"""The ruling's ordering paragraph, asserted through the guard the boundary consults."""
	var plot: int = _growing_plot()
	assert_true(_planner.reconcile_plot(plot, DAY_ONE_TICK).ok, "day 1's service is created")
	assert_false(_planner.preceding_day_is_settled(2),
		"day 1 is unsettled while its service is still outstanding")
	var boundary: JobPlannerScript.OpResult = _planner.run_day_boundary(FIRST_MIDNIGHT_TICK)
	assert_true(boundary.ok, "the boundary runs (error: %s)" % boundary.error)
	assert_equal(boundary.value, 1, "one outstanding service was settled")
	assert_true(_planner.preceding_day_is_settled(2), "and day 1 is settled once it returns")
	assert_equal(_planner.settled_unserved_count(), 1, "the unserved outcome is recorded")
	assert_equal(_jobs.job_count(), 0, "day 1's job does not survive into day 2")


func test_midnight_recovery_resumes_demand_for_the_new_day() -> void:
	"""The ruling: reopening or midnight recovery resumes demand."""
	var plot: int = _growing_plot()
	assert_true(_planner.reconcile_plot(plot, DAY_ONE_TICK).ok, "day 1's service is created")
	assert_true(_planner.run_day_boundary(FIRST_MIDNIGHT_TICK).ok, "midnight runs")
	assert_true(_planner.is_plot_dirty(plot), "the owner is reopened for the new day")
	var created: IntMath.IntResult = _planner.run_tick(FIRST_MIDNIGHT_TICK)
	assert_equal(created.value, 1, "the new day creates exactly one service")
	assert_equal(_planner.service_day_of(plot, TEND_OPERATION).value, 2,
		"and it belongs to absolute day 2")
	assert_equal(_jobs.job_count(), 1, "one job exists, not two")


func test_a_stale_pending_record_does_not_absorb_todays_demand() -> void:
	"""The service day is part of the identity, so yesterday's record cannot cover today.

	No midnight boundary is run here on purpose: a planner that compared only the owner would
	treat the day-1 record as covering day 2 and silently skip a day of service.
	"""
	var plot: int = _growing_plot()
	assert_true(_planner.reconcile_plot(plot, DAY_ONE_TICK).ok, "day 1's service is created")
	var stale: Vector2i = _planner.service_job_of(plot, TEND_OPERATION)
	assert_true(_planner.reconcile_plot(plot, FIRST_MIDNIGHT_TICK).ok, "day 2 is serviced too")
	assert_equal(_planner.service_day_of(plot, TEND_OPERATION).value, 2, "the record is day 2's")
	assert_true(_planner.service_job_of(plot, TEND_OPERATION) != stale,
		"and it names a new Job, not the stale day-1 one")
	assert_equal(_jobs.job_count(), 1, "the stale day-1 job is settled rather than left alive")
	assert_equal(_planner.settled_unserved_count(), 1, "its unserved outcome is recorded")


func test_a_completed_day_does_not_block_the_next_days_service() -> void:
	"""Once per day means once per day, not once ever."""
	var plot: int = _growing_plot()
	assert_true(_planner.reconcile_plot(plot, DAY_ONE_TICK).ok, "day 1's service is created")
	assert_true(_jobs.set_state(_service_job_slot(plot), STATE_COMPLETE).ok, "and completes")
	assert_true(_planner.run_day_boundary(FIRST_MIDNIGHT_TICK).ok, "midnight runs")
	assert_true(_planner.reconcile_plot(plot, FIRST_MIDNIGHT_TICK).ok, "day 2 is serviced")
	assert_equal(_planner.created_count(), 2, "two days, two services")
	assert_equal(_planner.service_day_of(plot, TEND_OPERATION).value, 2, "the second is day 2")


func test_an_owner_eligible_mid_day_receives_no_retroactive_service() -> void:
	"""The ruling: an owner that becomes eligible mid-day gets no service for earlier days."""
	var plot: int = _growing_plot()
	assert_true(_planner.run_day_boundary(FIRST_MIDNIGHT_TICK).ok, "day 2 opens")
	var mid_day: int = FIRST_MIDNIGHT_TICK + 5000
	assert_true(_planner.reconcile_plot(plot, mid_day).ok, "the owner is serviced")
	assert_equal(_planner.created_count(), 1, "one service, not one per elapsed day")
	assert_equal(_planner.service_day_of(plot, TEND_OPERATION).value, 2,
		"and it belongs to the current day only")


func test_a_boundary_inside_the_same_day_settles_nothing() -> void:
	"""Settlement retires rows older than today; today's own service is left alone."""
	var plot: int = _growing_plot()
	assert_true(_planner.reconcile_plot(plot, DAY_ONE_TICK).ok, "day 1's service is created")
	var boundary: JobPlannerScript.OpResult = _planner.run_day_boundary(DAY_ONE_TICK + 1)
	assert_true(boundary.ok, "the call succeeds")
	assert_equal(boundary.value, 0, "nothing is settled inside the same day")
	assert_equal(_planner.pending_service_count(), 1, "and today's service survives")
	assert_equal(_jobs.job_count(), 1, "as does its job")


func test_opening_a_day_reaches_an_owner_that_no_longer_exists() -> void:
	"""Opening demand marks every owner that is live OR still carries a record.

	A plot destroyed mid-day leaves a record naming a dead owner and a Job with a dead source.
	Marking only the LIVE owners would leave that record and that Job with nothing scheduled to
	notice them, so the condition is a disjunction and this test is what says so.
	"""
	var plot: int = _growing_plot()
	assert_true(_planner.reconcile_plot(plot, DAY_ONE_TICK).ok, "the service is created")
	assert_true(_farming.destroy(_farming.ref_of(plot)).ok, "the plot is destroyed mid-day")
	assert_false(_farming.is_present(plot), "no plot occupies the row")
	assert_equal(_planner.status_of(plot, TEND_OPERATION).value, JobPlannerScript.STATUS_PENDING,
		"but its record survives the destroy")
	assert_true(_planner.run_day_boundary(DAY_ONE_TICK + 1).ok, "the day is opened")
	assert_true(_planner.is_plot_dirty(plot), "the vanished owner is reached anyway")
	_planner.run_tick(DAY_ONE_TICK + 1)
	assert_equal(_planner.status_of(plot, TEND_OPERATION).value, JobPlannerScript.STATUS_FREE,
		"and its orphaned record is retired")
	assert_equal(_jobs.job_count(), 0, "along with the Job whose source no longer exists")


func test_midnight_releases_a_bound_worker_before_retiring_its_service() -> void:
	"""Cancellation must not leave a worker holding a released Job row."""
	var plot: int = _growing_plot()
	assert_true(_planner.reconcile_plot(plot, DAY_ONE_TICK).ok, "the service is created")
	var worker: int = _worker()
	assert_true(_jobs.assign_worker(worker, _service_job_slot(plot)).ok, "a worker takes it")
	assert_true(_planner.run_day_boundary(FIRST_MIDNIGHT_TICK).ok, "midnight runs")
	assert_equal(_jobs.job_of(worker), EntityDirectory.NULL_REF, "the worker is released")
	assert_equal(_jobs.job_count(), 0, "and the abandoned service's row is freed")


# --- capacity exhaustion ---------------------------------------------------------------------------

func _fill_the_job_arena() -> int:
	"""Create jobs until the KIND_JOB arena refuses, and return how many were created."""
	var made: int = 0
	while true:
		var created: JobsScript.OpResult = _jobs.create_job(KIND_FARM, 3, 0, 1000, 0)
		if not created.ok:
			return made
		made += 1
	return made


func test_capacity_exhaustion_retains_demand_and_reports_a_blocker() -> void:
	"""R06-JOB-008: exhaustion retains unmet policy demand and reports a blocker."""
	var plot: int = _growing_plot()
	assert_equal(_fill_the_job_arena(), 8192, "the arena holds GDD §4.2's 8192 jobs")
	var refused: JobPlannerScript.OpResult = _planner.reconcile_plot(plot, DAY_ONE_TICK)
	assert_false(refused.ok, "the service cannot be created")
	assert_equal(_planner.unmet_demand_count(), 1, "the demand is retained")
	assert_equal(_planner.blocker_count(), 1, "and a blocker is reported")
	assert_true(_planner.last_blocker() != JobPlannerScript.REFUSE_NONE,
		"the blocker carries the refusing store's own code, not an invented one")
	assert_equal(_planner.service_day_of(plot, TEND_OPERATION).value, 1,
		"retained demand remembers which day it is owed for")


func test_retained_demand_never_becomes_an_unbounded_queue() -> void:
	"""R06-JOB-008: it shall not create a hidden unbounded queue."""
	var plot: int = _growing_plot()
	_fill_the_job_arena()
	for _repeat: int in 200:
		_planner.mark_plot_dirty(plot)
		_planner.reconcile_plot(plot, DAY_ONE_TICK)
	assert_equal(_planner.unmet_demand_count(), 1,
		"two hundred refusals retain one row, because retention is one row per owner")
	assert_equal(_planner.blocker_count(), 200, "every refusal is still reported")
	assert_equal(_planner.pending_service_count(), 0, "and nothing was created")


func test_released_capacity_retries_the_retained_demand() -> void:
	"""R06-JOB-008: retry when capacity is released."""
	var plot: int = _growing_plot()
	_fill_the_job_arena()
	assert_false(_planner.reconcile_plot(plot, DAY_ONE_TICK).ok, "the first attempt is refused")
	assert_true(_jobs.destroy_job(0).ok, "one job row is released")
	assert_equal(_planner.mark_capacity_released(), 1, "the retained demand is re-marked dirty")
	var created: IntMath.IntResult = _planner.run_tick(DAY_ONE_TICK)
	assert_equal(created.value, 1, "and the retry creates the service")
	assert_equal(_planner.unmet_demand_count(), 0, "no demand remains unmet")
	assert_equal(_planner.pending_service_count(), 1, "exactly one service is pending")


func test_the_idle_sweep_alone_retries_retained_demand_within_one_period() -> void:
	"""Retry does not depend on anyone calling mark_capacity_released()."""
	var plot: int = _growing_plot()
	_fill_the_job_arena()
	assert_false(_planner.reconcile_plot(plot, DAY_ONE_TICK).ok, "the first attempt is refused")
	assert_true(_jobs.destroy_job(0).ok, "one job row is released")
	var created: int = 0
	for tick: int in range(DAY_ONE_TICK, DAY_ONE_TICK + JobPlannerScript.STAGGER_MODULUS):
		created += _planner.run_idle_sweep(tick).value
	assert_equal(created, 1, "one sweep period retries and creates the service")
	assert_equal(_planner.unmet_demand_count(), 0, "and clears the retained demand")


# --- the cadence -------------------------------------------------------------------------------

func test_the_idle_sweep_reaches_each_owner_on_its_own_staggered_tick() -> void:
	"""ARCH-SYS-009: idle selectors every 30 ticks staggered by ID.

	Four owners occupy typed rows 0-3, so the sweep must service exactly one of them on each of
	ticks 0, 1, 2 and 3 and none on ticks 4-29. A sweep that ignored the stagger and walked every
	row would service all four on tick 0; one that never advanced its start would only ever reach
	row 0. Both produce a different per-tick vector from the one asserted here.
	"""
	assert_equal(JobPlannerScript.IDLE_SWEEP_INTERVAL_TICKS, 30, "the stated interval is 30 ticks")
	for tile: int in range(300, 304):
		_growing_plot(tile)
	var per_tick: PackedInt32Array = PackedInt32Array()
	for tick: int in range(0, JobPlannerScript.STAGGER_MODULUS):
		per_tick.append(_planner.run_idle_sweep(tick).value)
	for tick: int in range(0, JobPlannerScript.STAGGER_MODULUS):
		var expected: int = 1 if tick < 4 else 0
		assert_equal(per_tick[tick], expected,
			"tick %d services %d owner(s)" % [tick, expected])
	assert_equal(_planner.created_count(), 4, "four owners, four services, one sweep period")


func test_two_owners_hold_independent_service_rows() -> void:
	"""One row per (owner, operation): one owner's service can never occupy another's row."""
	var first: int = _growing_plot(400)
	var second: int = _growing_plot(401)
	assert_true(_planner.reconcile_plot(first, DAY_ONE_TICK).ok, "the first owner is serviced")
	assert_equal(_planner.status_of(second, TEND_OPERATION).value, JobPlannerScript.STATUS_FREE,
		"the second owner's row is untouched by the first's service")
	assert_true(_planner.reconcile_plot(second, DAY_ONE_TICK).ok, "the second owner is serviced")
	assert_equal(_planner.pending_service_count(), 2, "two independent pending rows exist")
	assert_true(_planner.service_job_of(first, TEND_OPERATION)
		!= _planner.service_job_of(second, TEND_OPERATION), "and they name different Jobs")
	assert_equal(_planner.service_owner_of(first, TEND_OPERATION), _farming.ref_of(first),
		"each row records its own owner reference")


func test_a_planner_tick_drains_dirty_owners_before_sweeping() -> void:
	"""R06-JOB-008 reconciles a marked owner before selection, not a sweep period later."""
	var plot: int = _growing_plot(1)
	var off_slice_tick: int = (plot + 1) % JobPlannerScript.STAGGER_MODULUS
	assert_true(plot % JobPlannerScript.STAGGER_MODULUS != off_slice_tick,
		"the fixture owner is deliberately not in this tick's sweep slice")
	assert_equal(_planner.run_idle_sweep(off_slice_tick).value, 0, "the sweep alone reaches nothing")
	assert_true(_planner.mark_plot_dirty(plot).ok, "the owner is marked dirty")
	assert_equal(_planner.run_tick(off_slice_tick).value, 1, "the drain reaches it on this tick")
	assert_equal(_planner.dirty_count(), 0, "and the dirty set is emptied")


# --- explicit outcome entry points -----------------------------------------------------------------

func test_an_externally_recorded_service_closes_the_day() -> void:
	"""ARCH-SYS-006's seam: a tend performed outside a planner Job is recorded, not guessed."""
	var plot: int = _growing_plot()
	assert_true(_planner.record_service_completed(plot, TEND_OPERATION, 1).ok, "the day is recorded")
	assert_equal(_planner.reconcile_plot(plot, DAY_ONE_TICK).error,
		JobPlannerScript.REFUSE_SERVICE_ALREADY_COMPLETE, "and creates no service")
	assert_equal(_jobs.job_count(), 0, "no job exists")
	assert_false(_planner.record_service_completed(plot, TEND_OPERATION, 0).ok,
		"day 0 is outside the calendar and is refused rather than written")


func test_retiring_a_service_cancels_its_job_and_keeps_the_history() -> void:
	"""For a caller destroying an owner: retiring a record is not saying the work was done."""
	var plot: int = _growing_plot()
	assert_true(_planner.reconcile_plot(plot, DAY_ONE_TICK).ok, "the service is created")
	assert_true(_planner.retire_service(plot, TEND_OPERATION).ok, "the service retires")
	assert_equal(_jobs.job_count(), 0, "its job is cancelled and released")
	assert_equal(_planner.last_serviced_day_of(plot, TEND_OPERATION).value,
		JobPlannerScript.NO_DAY, "and no completion is fabricated")
	assert_equal(_planner.retire_service(plot, TEND_OPERATION).error,
		JobPlannerScript.REFUSE_NO_SERVICE, "retiring nothing refuses explicitly")


# --- refusals, not sentinels -----------------------------------------------------------------------

func test_every_reader_refuses_an_unaddressable_owner_or_operation() -> void:
	"""No reader answers 0 or -1 for an address it cannot resolve."""
	assert_equal(_planner.status_of(-1, TEND_OPERATION).error,
		String(JobPlannerScript.REFUSE_INVALID_OWNER_SLOT), "a negative owner refuses")
	assert_equal(_planner.status_of(4096, TEND_OPERATION).error,
		String(JobPlannerScript.REFUSE_INVALID_OWNER_SLOT), "an owner past capacity refuses")
	assert_equal(_planner.last_serviced_day_of(0, 7).error,
		String(JobPlannerScript.REFUSE_INVALID_OPERATION), "an unknown operation refuses")
	assert_false(_planner.service_day_of(0, TEND_OPERATION).ok,
		"a free row refuses rather than answering day 0 as if it were a day")
	assert_equal(_planner.reconcile_plot(0, -1).error, JobPlannerScript.REFUSE_INVALID_TICK,
		"a negative tick refuses")
	assert_equal(_planner.mark_plot_dirty(-5).error, JobPlannerScript.REFUSE_INVALID_OWNER_SLOT,
		"marking an unaddressable owner refuses")


func test_the_into_readers_agree_with_their_allocating_forms() -> void:
	"""Decision 0015: the `_into` form is the same answer without the allocation."""
	var plot: int = _growing_plot()
	assert_true(_planner.reconcile_plot(plot, DAY_ONE_TICK).ok, "the service is created")
	var scratch: IntMath.IntResult = IntMath.IntResult.new()
	assert_true(_planner.status_into(plot, TEND_OPERATION, scratch), "status reads into scratch")
	assert_equal(scratch.value, _planner.status_of(plot, TEND_OPERATION).value, "same status")
	assert_true(_planner.service_day_into(plot, TEND_OPERATION, scratch), "the day reads")
	assert_equal(scratch.value, 1, "and is day 1")
	assert_false(_planner.status_into(-1, TEND_OPERATION, scratch), "a bad address refuses")
	assert_equal(scratch.value, 0, "and leaves no plausible-looking value behind")


func test_clear_returns_every_row_to_the_empty_state() -> void:
	"""Two logically identical planners must hold identical columns."""
	var plot: int = _growing_plot()
	assert_true(_planner.reconcile_plot(plot, DAY_ONE_TICK).ok, "the service is created")
	_planner.mark_plot_dirty(plot)
	_planner.clear()
	assert_equal(_planner.pending_service_count(), 0, "no pending services remain")
	assert_equal(_planner.dirty_count(), 0, "the dirty set is empty")
	assert_equal(_planner.created_count(), 0, "the counters are zeroed")
	assert_equal(_planner.last_serviced_day_of(plot, TEND_OPERATION).value,
		JobPlannerScript.NO_DAY, "and no completion history survives a full clear")


# --- R06-JOB-004 fixtures --------------------------------------------------------------------------

func _empty_plot(tile: int = 200, soil: int = LOAM) -> int:
	"""Create a live EMPTY FarmPlot on a tile and return its slot."""
	var created: FarmingScript.OpResult = _farming.create_plot_at_tile(tile, soil, 1)
	assert_true(created.ok, "the plot creates (error: %s)" % created.error)
	return created.value


func _confirmed_plot(tile: int = 200, soil: int = LOAM, crop: int = GRAIN) -> int:
	"""Create an EMPTY plot and confirm one crop on it. Returns the slot."""
	var slot: int = _empty_plot(tile, soil)
	var confirmed: JobPlannerScript.OpResult = _planner.confirm_first_planting(slot, crop)
	assert_true(confirmed.ok, "the planting confirms (error: %s)" % confirmed.error)
	return slot


func _published_plot(tile: int = 200) -> int:
	"""Confirm grain on a loam plot and reconcile it into a published sowing Job in its window."""
	var slot: int = _confirmed_plot(tile)
	var published: JobPlannerScript.OpResult = _planner.reconcile_sowing(slot, DAY_ONE_TICK)
	assert_true(published.ok, "the sowing job publishes (error: %s)" % published.error)
	return slot


func _sowing_job_slot(owner_slot: int) -> int:
	"""The typed Job row of this owner's published sowing cycle, asserting one exists."""
	var ref: Vector2i = _planner.service_job_of(owner_slot, SOW_OPERATION)
	assert_true(ref != EntityDirectory.NULL_REF, "the owner has a published sowing job")
	return _jobs.directory().get_typed_row(ref)


# --- R06-JOB-004: the confirmation opens exactly one cycle --------------------------------------

func test_a_confirmed_crop_requests_the_first_sowing_cycle() -> void:
	"""R06-JOB-004: confirming the current crop for an EMPTY plot requests its first cycle."""
	var plot: int = _empty_plot()
	var confirmed: JobPlannerScript.OpResult = _planner.confirm_first_planting(plot, GRAIN)
	assert_true(confirmed.ok, "the confirmation is accepted (error: %s)" % confirmed.error)
	assert_equal(confirmed.value, 1, "and opens the plot's first field cycle")
	assert_equal(_planner.status_of(plot, SOW_OPERATION).value,
		JobPlannerScript.STATUS_REQUESTED, "the row holds the confirmed intent")
	assert_equal(_planner.sowing_crop_of(plot).value, GRAIN, "with the crop the player chose")
	assert_equal(_planner.requested_sowing_count(), 1, "one cycle is outstanding")
	assert_true(_planner.is_plot_dirty(plot), "and the owner is marked for reconciliation")
	assert_equal(_jobs.job_count(), 0, "confirming alone publishes no job")


func test_creating_a_plot_alone_requests_no_sowing() -> void:
	"""World generation is not a confirmation: an unconfirmed plot creates no sowing demand."""
	var plot: int = _empty_plot()
	_planner.mark_plot_dirty(plot)
	assert_true(_planner.run_tick(DAY_ONE_TICK).ok, "the planner tick runs")
	assert_true(_planner.run_tick(DAY_ONE_TICK + 1).ok, "and so does the next")
	assert_equal(_jobs.job_count(), 0, "no sowing job exists")
	assert_equal(_planner.sowing_confirmed_count(), 0, "and no cycle was ever opened")
	assert_equal(_planner.status_of(plot, SOW_OPERATION).value, JobPlannerScript.STATUS_FREE,
		"the sowing row stays free until a player confirms a crop")


func test_only_a_confirmation_opens_a_cycle_so_a_rotation_edit_starts_no_work() -> void:
	"""R06-JOB-004: changing a rotation list without confirming planting starts no work.

	There is no FieldPolicy store, so no rotation list can even be expressed; what is testable --
	and what a later rotation producer must not break -- is that NO entry point other than
	`confirm_first_planting()` opens a cycle. Marking dirty, sweeping and crossing midnight are
	each exercised here and none of them starts sowing work.
	"""
	var plot: int = _empty_plot()
	for _repeat: int in 5:
		_planner.mark_plot_dirty(plot)
		_planner.run_tick(DAY_ONE_TICK)
	assert_true(_planner.run_day_boundary(FIRST_MIDNIGHT_TICK).ok, "midnight runs")
	assert_true(_planner.run_tick(FIRST_MIDNIGHT_TICK).ok, "and the new day is reconciled")
	assert_equal(_jobs.job_count(), 0, "nothing has requested a sowing cycle")
	assert_equal(_planner.allocated_field_cycle_of(plot).value, JobPlannerScript.NO_CYCLE,
		"and no field cycle has been allocated")


func test_confirming_refuses_a_plot_that_is_not_empty() -> void:
	"""R06-JOB-004 confirms the crop for an EMPTY plot; anything else refuses, not overwrites."""
	var plot: int = _growing_plot()
	var confirmed: JobPlannerScript.OpResult = _planner.confirm_first_planting(plot, GRAIN)
	assert_equal(confirmed.error, JobPlannerScript.REFUSE_PLOT_NOT_EMPTY,
		"a GROWING plot refuses a first planting")
	assert_equal(_planner.allocated_field_cycle_of(plot).value, JobPlannerScript.NO_CYCLE,
		"and the refusal allocated no field cycle")


func test_confirming_refuses_an_unknown_crop_and_an_absent_owner() -> void:
	"""No sentinel: an unaddressable owner and a crop id outside §5.6's five refuse by name."""
	var plot: int = _empty_plot()
	assert_equal(_planner.confirm_first_planting(plot, 5).error,
		JobPlannerScript.REFUSE_INVALID_CROP, "there is no sixth crop")
	assert_equal(_planner.confirm_first_planting(plot, -1).error,
		JobPlannerScript.REFUSE_INVALID_CROP, "and the empty crop id is not a crop")
	assert_equal(_planner.confirm_first_planting(1000, GRAIN).error,
		JobPlannerScript.REFUSE_OWNER_NOT_PRESENT, "an addressable but absent owner refuses")
	assert_equal(_planner.confirm_first_planting(-1, GRAIN).error,
		JobPlannerScript.REFUSE_INVALID_OWNER_SLOT, "an unaddressable owner refuses")


# --- R06-JOB-004: publication ---------------------------------------------------------------------

func test_a_gated_cycle_publishes_one_four_wu_farm_sowing_job() -> void:
	"""Every evaluable REQ-SET-070 gate passing publishes §5.6's 4 WU of sowing, once."""
	var plot: int = _confirmed_plot()
	var published: JobPlannerScript.OpResult = _planner.reconcile_sowing(plot, DAY_ONE_TICK)
	assert_true(published.ok, "the sowing job publishes (error: %s)" % published.error)
	assert_equal(_jobs.job_count(), 1, "exactly one job exists")
	assert_equal(_planner.sowing_created_count(), 1, "the planner counts one publication")
	var job: int = _sowing_job_slot(plot)
	assert_equal(_jobs.kind_of(job).value, KIND_FARM, "a sowing cycle is a FARM job")
	assert_equal(_jobs.remaining_mwu_of(job).value, SOWING_MILLI_WU, "it is §5.6's 4 WU")
	assert_equal(_jobs.source_of(job), _farming.ref_of(plot), "its source is the plot")
	assert_equal(_jobs.destination_of(job), EntityDirectory.NULL_REF, "sowing delivers nothing")


func test_the_sowing_job_carries_the_rulings_priority_three_default() -> void:
	"""The ruling: ordinary newly generated work has priority 3."""
	var plot: int = _published_plot()
	assert_equal(_jobs.priority_of(_sowing_job_slot(plot)).value, ORDINARY_PRIORITY,
		"a sowing cycle is ordinary generated work")


func test_a_published_sowing_job_is_never_written_into_work() -> void:
	"""Creating a job does not authorize teleporting its worker into WORK; movement does not exist."""
	var plot: int = _published_plot()
	var job: int = _sowing_job_slot(plot)
	assert_equal(_jobs.state_of(job).value, STATE_QUEUED, "the published job is QUEUED")
	assert_true(_planner.run_tick(DAY_ONE_TICK).ok, "a planner tick runs")
	assert_equal(_jobs.state_of(job).value, STATE_QUEUED, "and leaves it QUEUED")
	assert_true(_planner.run_day_boundary(FIRST_MIDNIGHT_TICK).ok, "midnight runs")
	assert_true(_planner.run_tick(FIRST_MIDNIGHT_TICK).ok, "and the new day is reconciled")
	assert_equal(_jobs.state_of(job).value, STATE_QUEUED,
		"a whole day of planner work never writes JOB_STATE_WORK")
	assert_true(_jobs.state_of(job).value != STATE_WORK, "which is state 3, and is never written")


func test_the_planner_tick_publishes_a_confirmed_cycle_through_the_dirty_set() -> void:
	"""R06-JOB-008: the confirmation marks the owner dirty and the drain reconciles it."""
	var plot: int = _confirmed_plot()
	var drained: IntMath.IntResult = _planner.run_tick(DAY_ONE_TICK)
	assert_true(drained.ok, "the tick runs")
	assert_equal(drained.value, 1, "and reports the one piece of work it created")
	assert_equal(_planner.status_of(plot, SOW_OPERATION).value, JobPlannerScript.STATUS_PENDING,
		"the cycle is published")
	assert_equal(_jobs.job_count(), 1, "with exactly one job")


# --- REQ-SET-070's gates: the two with an owning store --------------------------------------------

func test_the_crop_soil_gate_refuses_with_its_own_code() -> void:
	"""REQ-SET-070's crop-soil gate: §5.6 admits grain on loam and clay, never on sand."""
	var plot: int = _confirmed_plot(201, SAND, GRAIN)
	var refused: JobPlannerScript.OpResult = _planner.reconcile_sowing(plot, DAY_ONE_TICK)
	assert_equal(refused.error, JobPlannerScript.REFUSE_SOIL_INCOMPATIBLE,
		"grain on sand refuses with the soil gate's own code")
	assert_equal(_planner.sowing_gate_reason_of(plot).value,
		JobPlannerScript.REASON_SOIL_INCOMPATIBLE, "and the row retains that reason")
	assert_equal(_jobs.job_count(), 0, "no sowing job was published")


func test_the_planting_window_gate_refuses_with_its_own_code() -> void:
	"""REQ-SET-070's planting-window gate: §5.6 gives grain spring days 1-4 only."""
	var plot: int = _confirmed_plot()
	var refused: JobPlannerScript.OpResult = _planner.reconcile_sowing(plot, _day_start_tick(5))
	assert_equal(refused.error, JobPlannerScript.REFUSE_OUTSIDE_PLANT_WINDOW,
		"spring day 5 is outside grain's window")
	assert_equal(_planner.sowing_gate_reason_of(plot).value,
		JobPlannerScript.REASON_OUTSIDE_PLANT_WINDOW, "and the row retains that reason")
	assert_equal(_jobs.job_count(), 0, "no sowing job was published")


func test_the_window_gate_reads_the_offset_calendar_not_a_bare_tick_division() -> void:
	"""GDD §5.1: the first midnight is tick 13500, so day 4's ticks are 67499 and below."""
	var plot: int = _confirmed_plot()
	assert_true(_planner.reconcile_sowing(plot, 67499).ok,
		"tick 67499 is still spring day 4 and inside grain's window")
	assert_true(_planner.cancel_sowing_request(plot).ok, "clear the published cycle")
	var again: int = _confirmed_plot(202)
	assert_equal(_planner.reconcile_sowing(again, 67500).error,
		JobPlannerScript.REFUSE_OUTSIDE_PLANT_WINDOW,
		"tick 67500 is the midnight that opens spring day 5 and is outside it")


func test_a_plot_that_stopped_being_empty_refuses_with_its_own_code() -> void:
	"""A cycle confirmed for an EMPTY plot never overwrites a crop that arrived meanwhile."""
	var plot: int = _confirmed_plot()
	assert_true(_farming.plant(plot, GRAIN, 1, SPRING, 1).ok, "another path sows the plot")
	var refused: JobPlannerScript.OpResult = _planner.reconcile_sowing(plot, DAY_ONE_TICK)
	assert_equal(refused.error, JobPlannerScript.REFUSE_PLOT_NOT_EMPTY,
		"the cycle refuses rather than publishing over committed seed")
	assert_equal(_planner.sowing_gate_reason_of(plot).value,
		JobPlannerScript.REASON_PLOT_NOT_EMPTY, "and the row retains that reason")


func test_a_failed_gate_consumes_nothing() -> void:
	"""R06-JOB-004: a failed gate does not consume seed. Decision 0024's allocate-before-consume."""
	var plot: int = _confirmed_plot(201, SAND, GRAIN)
	var cycle_before: int = _planner.allocated_field_cycle_of(plot).value
	for _repeat: int in 20:
		_planner.mark_plot_dirty(plot)
		_planner.run_tick(DAY_ONE_TICK)
	assert_equal(_planner.seed_committed_milli(), 0, "no seed was committed")
	assert_equal(_farming.state_of(plot).value, CROP_EMPTY, "the plot is still EMPTY")
	assert_equal(_farming.crop_id_of(plot).value, FarmingScript.CROP_NONE,
		"and carries no crop")
	assert_equal(_jobs.job_count(), 0, "no job was created")
	assert_equal(_planner.sowing_created_count(), 0, "no publication was counted")
	assert_equal(_planner.sowing_started_count(), 0, "no productive start was counted")
	assert_equal(_planner.blocker_count(), 0, "a gate refusal is not a capacity blocker")
	assert_equal(_planner.unmet_demand_count(), 0, "and retains no capacity demand")
	assert_equal(_planner.requested_sowing_count(), 1, "the one confirmed cycle is still held")
	assert_equal(_planner.allocated_field_cycle_of(plot).value, cycle_before,
		"and twenty refusals allocated no further field cycle")


func test_a_failed_plot_stays_unsown_with_its_reason_until_its_window_opens() -> void:
	"""R06-JOB-004: failed plots remain unsown WITH AN EXPLICIT REASON, and retry when legal.

	§5.6 gives roots spring days 1-8 and summer days 1-4, so spring day 9 is outside every window
	and summer day 1 -- absolute day 13 -- is inside the second one.
	"""
	var plot: int = _confirmed_plot(203, LOAM, ROOTS)
	var refused: JobPlannerScript.OpResult = _planner.reconcile_sowing(plot, _day_start_tick(9))
	assert_equal(refused.error, JobPlannerScript.REFUSE_OUTSIDE_PLANT_WINDOW,
		"spring day 9 is past roots' first window")
	var reason: int = _planner.sowing_gate_reason_of(plot).value
	assert_equal(_planner.sowing_refusal_of_reason(reason), refused.error,
		"the retained reason names the same refusal the caller was given")
	assert_equal(_planner.status_of(plot, SOW_OPERATION).value,
		JobPlannerScript.STATUS_REQUESTED, "the plot stays unsown with its cycle held")
	assert_true(_planner.reconcile_sowing(plot, _day_start_tick(13)).ok,
		"summer day 1 opens roots' second window and the same cycle publishes")
	assert_equal(_planner.sowing_gate_reason_of(plot).value, JobPlannerScript.REASON_NONE,
		"and the retained reason is cleared by the publication")
	assert_equal(_planner.sowing_field_cycle_of(plot).value, 1,
		"the published cycle is the one the player confirmed, not a new one")


# --- REQ-SET-070's gates: the three with no owning store ------------------------------------------

func test_the_storeless_seed_and_output_gates_refuse_at_selection() -> void:
	"""Seed supply and output capacity have no store, so the Job declares them UNANSWERABLE.

	Decision 0039 set this precedent for §5.6's water. Writing GATE_SATISFIED would fabricate a
	seed supply; the honest state is a job no resident can be committed to.
	"""
	var plot: int = _published_plot()
	var job: int = _sowing_job_slot(plot)
	assert_equal(_jobs.inputs_gate_of(job).value, GATE_UNAVAILABLE,
		"the sowing job declares an input requirement nothing can answer")
	assert_true(GATE_UNAVAILABLE != GATE_NOT_REQUIRED,
		"which is not the same as declaring that sowing needs no inputs")
	var worker: int = _worker()
	assert_equal(_jobs.assign_worker(worker, job).error, JobsScript.REFUSE_INPUTS_UNAVAILABLE,
		"so eligibility step 6 refuses the commitment at selection")
	assert_equal(_jobs.worker_of(job), EntityDirectory.NULL_REF, "and no worker is bound")


# --- R06-JOB-004: idempotence ----------------------------------------------------------------------

func test_a_repeated_confirmation_creates_no_duplicate_sowing_request() -> void:
	"""The ruling's acceptance list: repeated enable events create no duplicate claim."""
	var plot: int = _confirmed_plot()
	for _repeat: int in 10:
		assert_equal(_planner.confirm_first_planting(plot, GRAIN).error,
			JobPlannerScript.REFUSE_SOWING_REQUESTED, "a repeat confirmation refuses by name")
	assert_equal(_planner.requested_sowing_count(), 1, "one cycle is outstanding")
	assert_equal(_planner.sowing_confirmed_count(), 1, "one confirmation was ever accepted")
	assert_equal(_planner.allocated_field_cycle_of(plot).value, 1,
		"and ten repeats allocated no second field cycle")


func test_a_confirmation_while_a_cycle_is_published_refuses() -> void:
	"""A published cycle leaves the plot EMPTY until productive start; a re-confirm still refuses."""
	var plot: int = _published_plot()
	assert_equal(_farming.state_of(plot).value, CROP_EMPTY,
		"READY_06 §6.1: queued sowing leaves the plot EMPTY")
	assert_equal(_planner.confirm_first_planting(plot, GRAIN).error,
		JobPlannerScript.REFUSE_SOWING_PENDING, "and a second confirmation refuses by name")
	assert_equal(_jobs.job_count(), 1, "with no second job")


func test_repeated_dirty_events_create_no_duplicate_sowing_job() -> void:
	"""R06-JOB-008: reevaluation shall be idempotent."""
	var plot: int = _published_plot()
	var job: int = _sowing_job_slot(plot)
	for repeat: int in 30:
		_planner.mark_plot_dirty(plot)
		_planner.run_tick(DAY_ONE_TICK + repeat)
	assert_equal(_jobs.job_count(), 1, "one sowing job survives thirty reconciliations")
	assert_equal(_planner.sowing_created_count(), 1, "and only one publication is counted")
	assert_equal(_sowing_job_slot(plot), job, "it is the same Job row throughout")
	assert_equal(_planner.reconcile_sowing(plot, DAY_ONE_TICK).error,
		JobPlannerScript.REFUSE_SOWING_PENDING, "the guard names itself")


func test_a_reconcile_preserves_the_sowing_jobs_work_in_progress() -> void:
	"""The ruling: worker changes preserve the same Job and WIP. Nothing here touches remaining_mwu."""
	var plot: int = _published_plot()
	var job: int = _sowing_job_slot(plot)
	assert_true(_jobs.consume_remaining_mwu_into(job, 1500, IntMath.IntResult.new()),
		"1500 milli-WU of sowing progress is made")
	for _repeat: int in 5:
		_planner.mark_plot_dirty(plot)
		_planner.run_tick(DAY_ONE_TICK)
	assert_equal(_sowing_job_slot(plot), job, "the cycle still names the same Job row")
	assert_equal(_jobs.remaining_mwu_of(job).value, SOWING_MILLI_WU - 1500,
		"and its work in progress is preserved")


# --- R06-JOB-004: the identity carries the field cycle ---------------------------------------------

func test_the_sowing_identity_carries_the_field_cycle_not_a_service_day() -> void:
	"""The ruling: "sowing/rotation identity includes the field cycle"."""
	var plot: int = _published_plot()
	assert_equal(_planner.sowing_field_cycle_of(plot).value, 1, "the first cycle is 1")
	assert_equal(_planner.service_owner_of(plot, SOW_OPERATION), _farming.ref_of(plot),
		"the row stores the owner EntityRef, both halves")
	assert_equal(_planner.service_day_of(plot, SOW_OPERATION).error,
		String(JobPlannerScript.REFUSE_NOT_A_DAILY_SERVICE),
		"and refuses to answer a service day, which sowing does not have")


func test_a_sowing_cycle_is_not_settleable_as_a_daily_service() -> void:
	"""Sowing is not a daily service, so the daily entry points refuse it rather than closing it."""
	var plot: int = _published_plot()
	assert_false(_planner.is_daily_service_operation(SOW_OPERATION),
		"sowing does not reopen at midnight")
	assert_true(_planner.is_daily_service_operation(TEND_OPERATION),
		"tending does")
	assert_equal(_planner.record_service_completed(plot, SOW_OPERATION, 1).error,
		JobPlannerScript.REFUSE_NOT_A_DAILY_SERVICE,
		"a sowing cycle cannot be recorded as a day's completed service")
	assert_equal(_planner.last_serviced_day_of(plot, SOW_OPERATION).error,
		String(JobPlannerScript.REFUSE_NOT_A_DAILY_SERVICE),
		"and has no last-serviced day to read")
	assert_equal(_planner.status_of(plot, SOW_OPERATION).value, JobPlannerScript.STATUS_PENDING,
		"the refusals changed nothing")


func test_the_field_cycle_cursor_never_reuses_an_ordinal() -> void:
	"""Each confirmation on a plot takes the next cycle; a cancelled one is not handed out again."""
	var plot: int = _published_plot()
	assert_true(_planner.cancel_sowing_request(plot).ok, "the first cycle is cancelled")
	var second: JobPlannerScript.OpResult = _planner.confirm_first_planting(plot, GRAIN)
	assert_true(second.ok, "the plot can be confirmed again (error: %s)" % second.error)
	assert_equal(second.value, 2, "and takes cycle 2, never cycle 1 again")
	assert_equal(_planner.sowing_field_cycle_of(plot).value, 2, "the row carries the new cycle")
	assert_equal(_planner.allocated_field_cycle_of(plot).value, 2, "as does the cursor")


func test_the_field_cycle_cursor_refuses_at_the_int32_maximum() -> void:
	"""Refuse rather than wrap: a wrapped ordinal could name a cycle a retained row still holds."""
	assert_true(JobPlannerScript.can_allocate_field_cycle(JobPlannerScript.NO_CYCLE),
		"a plot that has never been confirmed can take cycle 1")
	assert_true(JobPlannerScript.can_allocate_field_cycle(
		JobPlannerScript.MAX_FIELD_CYCLE - 1), "one below the cap still fits")
	assert_false(JobPlannerScript.can_allocate_field_cycle(JobPlannerScript.MAX_FIELD_CYCLE),
		"the cap itself refuses")
	assert_equal(JobPlannerScript.MAX_FIELD_CYCLE, 2147483647, "which is int32's maximum")


func test_a_reused_owner_row_does_not_inherit_a_confirmed_sowing_cycle() -> void:
	"""Both halves of the owner EntityRef are checked, so a redrawn plot starts unconfirmed."""
	var plot: int = _published_plot(204)
	assert_true(_farming.destroy(_farming.ref_of(plot)).ok, "the plot is destroyed")
	var recreated: FarmingScript.OpResult = _farming.create_plot_at_tile(204, LOAM, 1)
	assert_true(recreated.ok, "and a new plot is drawn on the same tile")
	assert_equal(recreated.value, plot, "reusing the same typed row")
	assert_equal(_planner.reconcile_sowing(plot, DAY_ONE_TICK).error,
		JobPlannerScript.REFUSE_NO_SOWING_REQUEST,
		"the new plot has no confirmed crop of its own")
	assert_equal(_planner.status_of(plot, SOW_OPERATION).value, JobPlannerScript.STATUS_FREE,
		"the previous owner's request is retired")
	assert_equal(_jobs.job_count(), 0, "along with the Job whose source no longer exists")


# --- R06-JOB-004: midnight neither reopens nor settles a sowing cycle ------------------------------

func test_midnight_neither_reopens_nor_settles_a_sowing_cycle() -> void:
	"""Midnight settles the preceding day's SERVICE. A sowing cycle is not one, and survives it."""
	var plot: int = _published_plot()
	var job: int = _sowing_job_slot(plot)
	var boundary: JobPlannerScript.OpResult = _planner.run_day_boundary(FIRST_MIDNIGHT_TICK)
	assert_true(boundary.ok, "midnight runs (error: %s)" % boundary.error)
	assert_equal(boundary.value, 0, "and settles no row, because none was a daily service")
	assert_equal(_planner.settled_unserved_count(), 0,
		"the sowing cycle is not recorded as an unserved day")
	assert_equal(_planner.status_of(plot, SOW_OPERATION).value, JobPlannerScript.STATUS_PENDING,
		"it is still published")
	assert_equal(_sowing_job_slot(plot), job, "with the same Job row")
	assert_equal(_planner.sowing_field_cycle_of(plot).value, 1, "and the same field cycle")
	assert_equal(_planner.sowing_created_count(), 1, "midnight opened no second cycle")


func test_a_waiting_sowing_request_never_blocks_a_days_settlement() -> void:
	"""A row whose day is NO_DAY must not make every later day unsettleable."""
	var plot: int = _confirmed_plot(205, SAND, GRAIN)
	assert_equal(_planner.reconcile_sowing(plot, DAY_ONE_TICK).error,
		JobPlannerScript.REFUSE_SOIL_INCOMPATIBLE, "the request is held, unpublished")
	assert_true(_planner.preceding_day_is_settled(2),
		"a held sowing request carries no service day to settle")
	assert_true(_planner.run_day_boundary(FIRST_MIDNIGHT_TICK).ok, "so midnight opens day 2")
	assert_equal(_planner.status_of(plot, SOW_OPERATION).value,
		JobPlannerScript.STATUS_REQUESTED, "and the request is still held")


func test_a_tending_service_and_a_sowing_cycle_share_an_owner_without_colliding() -> void:
	"""The two operations hold independent rows: one owner, two identities, two Jobs."""
	var sowing: int = _published_plot(206)
	var growing: int = _growing_plot(207)
	assert_true(_planner.reconcile_plot(growing, DAY_ONE_TICK).ok, "the tending service is created")
	assert_equal(_jobs.job_count(), 2, "two independent jobs exist")
	assert_equal(_planner.status_of(sowing, TEND_OPERATION).value, JobPlannerScript.STATUS_FREE,
		"an EMPTY plot with a sowing cycle has no tending service")
	assert_equal(_planner.status_of(growing, SOW_OPERATION).value, JobPlannerScript.STATUS_FREE,
		"and a GROWING plot has no sowing cycle")
	assert_true(_planner.run_day_boundary(FIRST_MIDNIGHT_TICK).ok, "midnight runs")
	assert_equal(_planner.settled_unserved_count(), 1, "settling the tending service only")
	assert_equal(_planner.status_of(sowing, SOW_OPERATION).value, JobPlannerScript.STATUS_PENDING,
		"and leaving the sowing cycle exactly where it was")


# --- R06-JOB-004: seed commitment ------------------------------------------------------------------

func test_productive_start_commits_the_seed_exactly_once() -> void:
	"""READY_06 §6.1: at productive start the exact seed is committed and the state becomes SOWN."""
	var plot: int = _published_plot()
	var started: JobPlannerScript.OpResult = _planner.record_sowing_started(plot, DAY_ONE_TICK)
	assert_true(started.ok, "the productive start is accepted (error: %s)" % started.error)
	assert_equal(started.value, SEED_MILLI, "and returns §5.6's 250 milli-U of seed to consume")
	assert_equal(_farming.state_of(plot).value, CROP_SOWN, "the plot is SOWN")
	assert_equal(_planner.seed_committed_milli(), SEED_MILLI, "one commitment is counted")
	assert_equal(_planner.record_sowing_started(plot, DAY_ONE_TICK).error,
		FarmingScript.REFUSE_NOT_EMPTY, "a second start refuses on the committed plot")
	assert_equal(_planner.seed_committed_milli(), SEED_MILLI,
		"so two workers cannot spend the same seed")


func test_a_window_that_closed_before_productive_start_commits_no_seed() -> void:
	"""`farming.plant()` re-applies both evaluable gates, so a late start consumes nothing."""
	var plot: int = _published_plot()
	var late: JobPlannerScript.OpResult = _planner.record_sowing_started(plot, _day_start_tick(5))
	assert_equal(late.error, FarmingScript.REFUSE_OUTSIDE_PLANT_WINDOW,
		"spring day 5 is outside grain's window")
	assert_equal(_farming.state_of(plot).value, CROP_EMPTY, "the plot is still EMPTY")
	assert_equal(_planner.seed_committed_milli(), 0, "and no seed was committed")
	assert_equal(_planner.status_of(plot, SOW_OPERATION).value, JobPlannerScript.STATUS_PENDING,
		"the cycle is still published, waiting for a legal moment")


func test_productive_start_refuses_without_a_published_cycle() -> void:
	"""No seed moves for a plot whose cycle was never published: refusal, not a silent plant."""
	var plot: int = _confirmed_plot()
	assert_equal(_planner.record_sowing_started(plot, DAY_ONE_TICK).error,
		JobPlannerScript.REFUSE_SOWING_NOT_PENDING, "a held request is not a productive start")
	assert_equal(_farming.state_of(plot).value, CROP_EMPTY, "the plot is untouched")
	assert_equal(_planner.seed_committed_milli(), 0, "and no seed was committed")


func test_successful_completion_enters_growing_and_closes_the_cycle() -> void:
	"""READY_06 §6.1: only SUCCESSFUL sowing completion enters GROWING."""
	var plot: int = _published_plot()
	assert_true(_planner.record_sowing_started(plot, DAY_ONE_TICK).ok, "sowing starts")
	var done: JobPlannerScript.OpResult = _planner.record_sowing_completed(plot)
	assert_true(done.ok, "the cycle completes (error: %s)" % done.error)
	assert_equal(done.value, 1, "and reports the field cycle it closed")
	assert_equal(_farming.state_of(plot).value, CROP_GROWING, "the plot is GROWING")
	assert_equal(_planner.completed_field_cycle_of(plot).value, 1, "the history records cycle 1")
	assert_equal(_planner.status_of(plot, SOW_OPERATION).value, JobPlannerScript.STATUS_FREE,
		"the row is retired")
	assert_equal(_jobs.job_count(), 0, "and the sowing Job's row is released")


func test_completion_refuses_a_plot_that_never_reached_sown() -> void:
	"""Allocate before consume: no cycle is recorded complete on a plot that holds no seed."""
	var plot: int = _published_plot()
	assert_equal(_planner.record_sowing_completed(plot).error, FarmingScript.REFUSE_NOT_SOWN,
		"an EMPTY plot cannot finish sowing")
	assert_equal(_planner.completed_field_cycle_of(plot).value, JobPlannerScript.NO_CYCLE,
		"and no completion is fabricated")
	assert_equal(_planner.status_of(plot, SOW_OPERATION).value, JobPlannerScript.STATUS_PENDING,
		"the cycle is still published")


func test_a_completed_sowing_job_closes_the_cycle_and_leaves_the_crop_state_to_farming() -> void:
	"""Observing a COMPLETE Job closes the cycle; SOWN -> GROWING stays farming.gd's own."""
	var plot: int = _published_plot()
	assert_true(_planner.record_sowing_started(plot, DAY_ONE_TICK).ok, "sowing starts")
	assert_true(_jobs.set_state(_sowing_job_slot(plot), STATE_COMPLETE).ok, "its job completes")
	assert_equal(_planner.reconcile_sowing(plot, DAY_ONE_TICK).error,
		JobPlannerScript.REFUSE_SOWING_COMPLETE, "the reconcile settles it rather than republishing")
	assert_equal(_planner.completed_field_cycle_of(plot).value, 1, "the history records cycle 1")
	assert_equal(_planner.sowing_completed_count(), 1, "one completion is counted")
	assert_equal(_farming.state_of(plot).value, CROP_SOWN,
		"and the crop state is left to farming.begin_growing()")
	assert_equal(_jobs.job_count(), 0, "the completed Job's row is released")


func test_a_cancelled_sowing_job_is_recorded_rather_than_read_as_complete() -> void:
	"""An explicitly cancelled cycle needs a recorded cancellation, not a fabricated completion."""
	var plot: int = _published_plot()
	assert_true(_jobs.set_state(_sowing_job_slot(plot), STATE_CANCELLED).ok, "its job is cancelled")
	assert_equal(_planner.reconcile_sowing(plot, DAY_ONE_TICK).error,
		JobPlannerScript.REFUSE_SOWING_CANCELLED, "the reconcile records the cancellation")
	assert_equal(_planner.sowing_cancelled_count(), 1, "which is counted as one")
	assert_equal(_planner.completed_field_cycle_of(plot).value, JobPlannerScript.NO_CYCLE,
		"and no completion was fabricated for that cycle")


# --- R06-JOB-004: the two cancellation regimes ------------------------------------------------------

func test_pre_commitment_cancellation_leaves_the_plot_empty_with_no_seed_loss() -> void:
	"""READY_06 §6.1's first regime: release the reservations, leave EMPTY, lose no seed."""
	var plot: int = _published_plot()
	var cancelled: JobPlannerScript.OpResult = _planner.cancel_sowing_request(plot)
	assert_true(cancelled.ok, "the request cancels (error: %s)" % cancelled.error)
	assert_equal(cancelled.value, 1, "and reports the field cycle it released")
	assert_equal(_farming.state_of(plot).value, CROP_EMPTY, "the plot is left EMPTY")
	assert_equal(_farming.crop_id_of(plot).value, FarmingScript.CROP_NONE, "with no crop")
	assert_equal(_planner.seed_committed_milli(), 0, "and no seed was ever committed or lost")
	assert_equal(_jobs.job_count(), 0, "the published Job's row is released")
	assert_equal(_planner.status_of(plot, SOW_OPERATION).value, JobPlannerScript.STATUS_FREE,
		"and the row is retired")


func test_pre_commitment_cancellation_releases_a_bound_worker() -> void:
	"""The only reservation this build can hold is the Job's worker; cancellation releases it.

	No resident can be committed to a sowing Job through selection while its inputs gate is
	UNAVAILABLE, so the binding is made here directly to prove the release path itself.
	"""
	var plot: int = _published_plot()
	var job: int = _sowing_job_slot(plot)
	assert_true(_jobs.set_inputs_gate(job, GATE_NOT_REQUIRED).ok,
		"a supply the store could answer would let a worker bind")
	var worker: int = _worker()
	assert_true(_jobs.assign_worker(worker, job).ok, "the worker takes the sowing job")
	assert_true(_planner.cancel_sowing_request(plot).ok, "the request cancels")
	assert_equal(_jobs.job_of(worker), EntityDirectory.NULL_REF, "the worker is released")
	assert_equal(_jobs.job_count(), 0, "and no Job row is left held by anyone")


func test_post_commitment_cancellation_refuses_and_names_the_other_regime() -> void:
	"""Once seed is committed the regime is farming.cancel_sowing(): no refund, history preserved."""
	var plot: int = _published_plot()
	assert_true(_planner.record_sowing_started(plot, DAY_ONE_TICK).ok, "sowing starts")
	assert_equal(_planner.cancel_sowing_request(plot).error,
		JobPlannerScript.REFUSE_SOWING_COMMITTED,
		"the pre-commitment regime refuses on a plot holding committed seed")
	assert_equal(_farming.state_of(plot).value, CROP_SOWN, "the plot is untouched by the refusal")
	var discarded: FarmingScript.OpResult = _farming.cancel_sowing(plot)
	assert_true(discarded.ok, "the post-commitment regime is farming.gd's")
	assert_equal(discarded.value, 0, "and refunds nothing")
	assert_equal(_planner.seed_committed_milli(), SEED_MILLI,
		"the committed seed stays spent in the planner's own accounting")


func test_cancelling_without_a_request_refuses_by_name() -> void:
	"""No sentinel: cancelling a plot with no cycle is a refusal, not a silent success."""
	var plot: int = _empty_plot()
	assert_equal(_planner.cancel_sowing_request(plot).error,
		JobPlannerScript.REFUSE_NO_SOWING_REQUEST, "there is no cycle to cancel")
	assert_equal(_planner.cancel_sowing_request(-1).error,
		JobPlannerScript.REFUSE_INVALID_OWNER_SLOT, "and an unaddressable owner refuses")


func test_a_held_request_can_be_cancelled_before_it_ever_publishes() -> void:
	"""The pre-commitment regime covers a cycle that never got past its gates."""
	var plot: int = _confirmed_plot(208, SAND, GRAIN)
	assert_false(_planner.reconcile_sowing(plot, DAY_ONE_TICK).ok, "the soil gate refuses it")
	assert_true(_planner.cancel_sowing_request(plot).ok, "the held request cancels")
	assert_equal(_planner.requested_sowing_count(), 0, "nothing is outstanding")
	assert_equal(_planner.sowing_cancelled_count(), 1, "and the cancellation is recorded")


# --- R06-JOB-004: capacity exhaustion ---------------------------------------------------------------

func test_capacity_exhaustion_retains_the_sowing_cycle_and_reports_a_blocker() -> void:
	"""R06-JOB-008: retain the demand, report a blocker, retry on release. No hidden queue."""
	var plot: int = _confirmed_plot()
	assert_equal(_fill_the_job_arena(), 8192, "the arena holds GDD §4.2's 8192 jobs")
	for _repeat: int in 50:
		_planner.mark_plot_dirty(plot)
		_planner.reconcile_sowing(plot, DAY_ONE_TICK)
	assert_equal(_planner.unmet_demand_count(), 1, "fifty refusals retain one row")
	assert_equal(_planner.blocker_count(), 50, "every refusal is reported")
	assert_equal(_planner.sowing_field_cycle_of(plot).value, 1,
		"and retained demand remembers which field cycle it is owed for")
	assert_equal(_planner.seed_committed_milli(), 0, "a capacity refusal consumes no seed either")


func test_released_capacity_republishes_the_same_field_cycle() -> void:
	"""The retried publication carries the cycle the player confirmed, never a fresh one."""
	var plot: int = _confirmed_plot()
	_fill_the_job_arena()
	assert_true(_planner.run_tick(DAY_ONE_TICK).ok, "the drain attempts the cycle and is refused")
	assert_equal(_planner.unmet_demand_count(), 1, "so the demand is retained")
	assert_equal(_planner.dirty_count(), 0, "and the dirty set is drained")
	assert_true(_jobs.destroy_job(0).ok, "one job row is released")
	assert_equal(_planner.mark_capacity_released(), 1, "the retained demand is re-marked dirty")
	assert_true(_planner.run_tick(DAY_ONE_TICK).ok, "the drain retries it")
	assert_equal(_planner.status_of(plot, SOW_OPERATION).value, JobPlannerScript.STATUS_PENDING,
		"and the cycle publishes")
	assert_equal(_planner.sowing_field_cycle_of(plot).value, 1, "with its original field cycle")
	assert_equal(_planner.unmet_demand_count(), 0, "leaving no retained demand behind")


# --- R06-JOB-004: readers, load repair and clear ----------------------------------------------------

func test_a_vanished_sowing_job_is_dropped_on_load_and_the_owner_must_confirm_again() -> void:
	"""The permitted repair: drop the pointer into the Job store, keep the durable history."""
	var plot: int = _published_plot()
	assert_true(_jobs.destroy_job(_sowing_job_slot(plot)).ok, "its Job row vanishes")
	var dropped: IntMath.IntResult = _planner.revalidate_after_load()
	assert_true(dropped.ok, "revalidation runs")
	assert_equal(dropped.value, 1, "and drops the one unresolvable row")
	assert_equal(_planner.status_of(plot, SOW_OPERATION).value, JobPlannerScript.STATUS_FREE,
		"the row is retired")
	assert_equal(_planner.allocated_field_cycle_of(plot).value, 1,
		"but the cursor keeps its history, so the next confirmation takes cycle 2")
	assert_equal(_planner.confirm_first_planting(plot, GRAIN).value, 2,
		"as it does")


func test_the_sowing_readers_refuse_rather_than_answer_for_an_absent_request() -> void:
	"""No reader answers 0 or -1 for a cycle that does not exist."""
	var plot: int = _empty_plot()
	assert_equal(_planner.sowing_crop_of(plot).error,
		String(JobPlannerScript.REFUSE_NO_SOWING_REQUEST), "an unconfirmed plot has no crop")
	assert_equal(_planner.sowing_field_cycle_of(plot).error,
		String(JobPlannerScript.REFUSE_NO_SOWING_REQUEST), "and no field cycle")
	assert_equal(_planner.sowing_gate_reason_of(plot).error,
		String(JobPlannerScript.REFUSE_NO_SOWING_REQUEST), "and no gate reason")
	assert_equal(_planner.sowing_crop_of(-1).error,
		String(JobPlannerScript.REFUSE_INVALID_OWNER_SLOT), "an unaddressable owner refuses")
	assert_equal(_planner.allocated_field_cycle_of(4096).error,
		String(JobPlannerScript.REFUSE_INVALID_OWNER_SLOT), "as does an owner past capacity")
	assert_equal(_planner.sowing_refusal_of_reason(JobPlannerScript.REASON_COUNT),
		JobPlannerScript.REFUSE_INVALID_GATE_REASON, "and a reason outside the domain refuses")


func test_the_sowing_into_readers_agree_with_their_allocating_forms() -> void:
	"""Decision 0015: the `_into` form is the same answer without the allocation."""
	var plot: int = _published_plot()
	var scratch: IntMath.IntResult = IntMath.IntResult.new()
	assert_true(_planner.sowing_crop_into(plot, scratch), "the crop reads into scratch")
	assert_equal(scratch.value, _planner.sowing_crop_of(plot).value, "same crop")
	assert_true(_planner.sowing_field_cycle_into(plot, scratch), "the cycle reads into scratch")
	assert_equal(scratch.value, _planner.sowing_field_cycle_of(plot).value, "same cycle")
	assert_true(_planner.sowing_gate_reason_into(plot, scratch), "the reason reads into scratch")
	assert_equal(scratch.value, JobPlannerScript.REASON_NONE, "and is REASON_NONE once published")
	assert_true(_planner.allocated_field_cycle_into(plot, scratch), "the cursor reads")
	assert_equal(scratch.value, 1, "and is cycle 1")
	assert_true(_planner.completed_field_cycle_into(plot, scratch), "the history reads")
	assert_equal(scratch.value, JobPlannerScript.NO_CYCLE, "and no cycle has completed")
	assert_false(_planner.sowing_crop_into(-1, scratch), "a bad address refuses")
	assert_equal(scratch.value, 0, "and leaves no plausible-looking value behind")


func test_clear_returns_the_sowing_columns_to_the_empty_state() -> void:
	"""Two logically identical planners must hold identical columns, cycles included."""
	var plot: int = _published_plot()
	assert_true(_planner.record_sowing_started(plot, DAY_ONE_TICK).ok, "seed is committed")
	_planner.clear()
	assert_equal(_planner.requested_sowing_count(), 0, "no cycle is outstanding")
	assert_equal(_planner.pending_service_count(), 0, "no row is published")
	assert_equal(_planner.sowing_confirmed_count(), 0, "the counters are zeroed")
	assert_equal(_planner.seed_committed_milli(), 0, "including the committed-seed total")
	assert_equal(_planner.allocated_field_cycle_of(plot).value, JobPlannerScript.NO_CYCLE,
		"and no field-cycle history survives a full clear")


func test_the_gate_reader_answers_every_evaluable_gate_without_side_effects() -> void:
	"""`sowing_gate_for()` is the same gate sweep the producer acts on, asked as a question.

	It is what a UI panel or a command handler pre-checking a confirmation reads, and it makes
	every reason in the domain reachable -- including the two the producer's own path cannot
	reach, because `confirm_first_planting()` has already refused an unknown crop and an absent
	owner before a row could ever hold one.
	"""
	var loam: int = _empty_plot(210, LOAM)
	var sand: int = _empty_plot(211, SAND)
	assert_equal(_planner.sowing_gate_for(loam, GRAIN, DAY_ONE_TICK).value,
		JobPlannerScript.REASON_NONE, "grain on loam in its window passes every evaluable gate")
	assert_equal(_planner.sowing_gate_for(sand, GRAIN, DAY_ONE_TICK).value,
		JobPlannerScript.REASON_SOIL_INCOMPATIBLE, "grain on sand fails the soil gate")
	assert_equal(_planner.sowing_gate_for(loam, GRAIN, _day_start_tick(5)).value,
		JobPlannerScript.REASON_OUTSIDE_PLANT_WINDOW, "spring day 5 fails the window gate")
	assert_equal(_planner.sowing_gate_for(loam, 5, DAY_ONE_TICK).value,
		JobPlannerScript.REASON_CROP_INVALID, "there is no sixth crop")
	assert_equal(_planner.sowing_gate_for(1000, GRAIN, DAY_ONE_TICK).value,
		JobPlannerScript.REASON_OWNER_NOT_PRESENT, "an absent owner is its own reason")
	assert_equal(_planner.sowing_gate_for(_growing_plot(212), GRAIN, DAY_ONE_TICK).value,
		JobPlannerScript.REASON_PLOT_NOT_EMPTY, "and a GROWING plot is not sowable")
	assert_equal(_jobs.job_count(), 0, "asking the question published nothing")
	assert_equal(_planner.sowing_confirmed_count(), 0, "and confirmed nothing")


func test_the_gate_reader_refuses_an_unaddressable_owner_or_a_negative_tick() -> void:
	"""A gate reason is an answer; an address the reader cannot resolve is a refusal."""
	assert_equal(_planner.sowing_gate_for(-1, GRAIN, DAY_ONE_TICK).error,
		String(JobPlannerScript.REFUSE_INVALID_OWNER_SLOT), "an unaddressable owner refuses")
	assert_equal(_planner.sowing_gate_for(0, GRAIN, -1).error,
		String(JobPlannerScript.REFUSE_INVALID_TICK), "and a negative tick refuses")
	var scratch: IntMath.IntResult = IntMath.IntResult.new()
	var plot: int = _empty_plot()
	assert_true(_planner.sowing_gate_for_into(plot, GRAIN, DAY_ONE_TICK, scratch),
		"the into form answers")
	assert_equal(scratch.value, _planner.sowing_gate_for(plot, GRAIN, DAY_ONE_TICK).value,
		"with the same reason as its allocating form")


func test_productive_start_distinguishes_never_published_from_a_vanished_job() -> void:
	"""Two different facts, two different refusals; neither commits seed."""
	var held: int = _confirmed_plot(213)
	assert_equal(_planner.record_sowing_started(held, DAY_ONE_TICK).error,
		JobPlannerScript.REFUSE_SOWING_NOT_PENDING, "a held request never published a cycle")
	var published: int = _published_plot(214)
	assert_true(_jobs.destroy_job(_sowing_job_slot(published)).ok, "its Job row vanishes")
	assert_equal(_planner.record_sowing_started(published, DAY_ONE_TICK).error,
		JobPlannerScript.REFUSE_SOWING_JOB_MISSING,
		"a published cycle that lost its Job says so instead")
	assert_equal(_planner.seed_committed_milli(), 0, "and neither refusal committed seed")
	assert_equal(_farming.state_of(held).value, CROP_EMPTY, "both plots are untouched")
	assert_equal(_farming.state_of(published).value, CROP_EMPTY, "both plots are untouched")


func test_the_idle_sweep_reaches_a_sowing_row_whose_plot_no_longer_exists() -> void:
	"""A row is a reason to sweep an owner even when its plot has gone, or its Job is orphaned."""
	var plot: int = _published_plot(215)
	assert_equal(plot, 0, "the fixture uses the first owner row, whose stagger tick is 0 mod 30")
	assert_true(_farming.destroy(_farming.ref_of(plot)).ok, "the plot is destroyed")
	assert_false(_farming.is_present(plot), "leaving no live owner to notice")
	assert_equal(_jobs.job_count(), 1, "but its sowing Job is still alive")
	var swept: IntMath.IntResult = _planner.run_idle_sweep(DAY_ONE_TICK)
	assert_true(swept.ok, "the sweep runs on this owner's staggered tick")
	assert_equal(_planner.status_of(plot, SOW_OPERATION).value, JobPlannerScript.STATUS_FREE,
		"the orphaned request is retired")
	assert_equal(_jobs.job_count(), 0, "and its Job is cancelled rather than left forever")
	assert_equal(_planner.sowing_cancelled_count(), 1, "which is recorded as a cancellation")


func test_a_retired_row_keeps_no_residue_of_the_cycle_it_carried() -> void:
	"""jobs.gd's `inactive_job_row_is_clear()` rule, applied to the planner's own rows."""
	var plot: int = _published_plot()
	assert_false(_planner.service_row_is_clear(plot, SOW_OPERATION),
		"a published row is not a free row")
	assert_true(_planner.cancel_sowing_request(plot).ok, "the cycle is cancelled")
	assert_true(_planner.service_row_is_clear(plot, SOW_OPERATION),
		"and the retired row holds no field cycle, crop, owner reference or gate reason")
	assert_true(_planner.service_row_is_clear(plot, TEND_OPERATION),
		"a row that never carried anything is clear too")
	assert_false(_planner.service_row_is_clear(4096, SOW_OPERATION),
		"and an unaddressable row is not reported clear")


func test_a_retired_tending_service_row_is_clear_as_well() -> void:
	"""The same predicate over the daily operation, so neither row can keep the other's residue."""
	var plot: int = _growing_plot()
	assert_true(_planner.reconcile_plot(plot, DAY_ONE_TICK).ok, "the service is created")
	assert_false(_planner.service_row_is_clear(plot, TEND_OPERATION), "the row is in use")
	assert_true(_planner.retire_service(plot, TEND_OPERATION).ok, "the service is retired")
	assert_true(_planner.service_row_is_clear(plot, TEND_OPERATION), "and its row is clear")
