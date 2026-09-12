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
const ForageScript := preload("res://scripts/core/forage.gd")
const OrchardHiveScript := preload("res://scripts/core/orchard_hive.gd")

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

# --- R06-JOB-001/002 constants, transcribed from the documents, never read out of the module -------

## §4.3 ZoneType, in the GDD's own numbering: FISH 0, RESERVED_1 1, FORAGE 2, FARM 3.
const ZONE_FORAGE: int = 2
const ZONE_FARM: int = 3
## §4.3 JobKind FORAGE, from the same numbering the FARM constant above is taken from.
const KIND_FORAGE: int = 4
## §5.5's five forage rows, in the table's own order.
const PATCH_BERRIES: int = 0
const PATCH_NUTS: int = 1
const PATCH_MUSHROOMS: int = 2
const PATCH_HERB: int = 3
const PATCH_ROOTS: int = 4
## §5.5's "Patch capacity U" for mushrooms, in milli-units, GDD §5.1's 80% initial stock, and
## REQ-SET-066's sustainable 20% floor of that capacity.
const MUSHROOM_CAPACITY_MILLI: int = 180000
const MUSHROOM_INITIAL_MILLI: int = 144000
const MUSHROOM_FLOOR_MILLI: int = 36000
## §5.5's "Base work WU/U" for mushrooms and for herb.
const MUSHROOM_BASE_WORK_WU: int = 5
const HERB_BASE_WORK_WU: int = 8
## §5.5's `ceil(base*1000000/((1000+40*level)*(1000+100*natural_danger)))` for herb at FORAGE
## level 0 and natural danger 1: ceil(8000000/1100000) = 8. At level 1 the same expression is
## ceil(8000000/1144000) = 7, so this number distinguishes the two levels where mushrooms cannot.
const HERB_WORK_PER_U_AT_DANGER_ONE: int = 8
## §5.5's herb capacity 160 U: §5.1's 80% initial stock is 128000 milli-U and REQ-SET-066's
## sustainable 20% floor is 32000, leaving 96000 claimable.
const HERB_STOCK_ABOVE_FLOOR_MILLI: int = 96000
## Decision 0030 §4.6's automatic basin quota in SPRING, in milli-U/day: 2800 mushrooms + 3560
## herb + 4360 roots, with berries and nuts dormant.
const SPRING_AUTOMATIC_QUOTA_MILLI: int = 10720
## Decision 0030 §4.6's manual maximum, `sum(K_i)` in milli-U/day.
const MANUAL_QUOTA_MAX_MILLI: int = 1180000
## §5.5's spring availabilities per 1000: berries and nuts are DORMANT in spring.
const SPRING_BERRIES_AVAILABILITY: int = 0
## REQ-SET-067's dangerous-work band: danger 2 or 3 needs the resident's permission.
const DANGEROUS_BAND: int = 2
## GDD §5.1's offset calendar with twelve-day seasons: absolute day 13 opens summer, and its
## first tick is the midnight that starts it.
const SUMMER_MIDNIGHT_TICK: int = 211500

# --- R06-JOB-006 constants, transcribed from the documents, never read out of the module -----------

## §4.3 JobKind KEEP, from the same ASCII numbering the FARM and FORAGE constants above use:
## HAUL 0, BUILD 1, FISH 2, RESERVED_3 3, FORAGE 4, FARM 5, COOK 6, PRESERVE 7, CRAFT 8, TEND 9,
## KEEP 10, HEAL 11.
const KIND_KEEP: int = 10
## §5.6: "service is 20 WU/day", in milli-WU.
const HIVE_SERVICE_MILLI_WU: int = 20000
## §5.6: "Winter ... consumes honey 0.5 U/day", in milli-units.
const WINTER_FEED_MILLI: int = 500

var _residents: ResidentsScript = null
var _priorities: PrioritiesScript = null
var _schedule: ScheduleScript = null
var _jobs: JobsScript = null
var _farming: FarmingScript = null
var _forage: ForageScript = null
var _hives: OrchardHiveScript = null
var _planner: JobPlannerScript = null


func before_each() -> void:
	"""Build one consistent set of stores sharing a single entity directory.

	The forage store additionally shares the Job store, because decision 0030 indexes a forage
	claim by its owning Job's typed row.
	"""
	_residents = ResidentsScript.new()
	_priorities = PrioritiesScript.new()
	_schedule = ScheduleScript.new(_residents.needs())
	_jobs = JobsScript.new(_residents, _priorities, _schedule)
	_farming = FarmingScript.new(_jobs.directory())
	_forage = ForageScript.new(_jobs.directory(), _jobs)
	_hives = OrchardHiveScript.new(_jobs.directory())
	_planner = JobPlannerScript.new(_farming, _jobs, _forage, _hives)


func after_each() -> void:
	"""Drop every store so no test inherits another's rows."""
	_planner = null
	_hives = null
	_forage = null
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
	cycle now has a row beside the daily tending service. The stride is OPERATION_COUNT; the 4096
	owners are farming.gd's FarmPlot capacity and are unchanged.

	UPDATED AGAIN for R06-JOB-006 (decision 0051): DAILY_SERVICE_OPERATION_COUNT IS NOW TWO, and
	the second daily operation is the hive service, which belongs to a DIFFERENT OWNER CLASS and
	deliberately DOES NOT widen this table. That is the property this test now pins: the FarmPlot
	stride stayed at 2 and SERVICE_ROW_COUNT stayed at 8192 while a daily operation was added.
	"""
	assert_equal(JobPlannerScript.OPERATION_COUNT, 2,
		"tending and sowing are the two operations addressing the FarmPlot table")
	assert_equal(JobPlannerScript.DAILY_SERVICE_OPERATION_COUNT, 2,
		"FARM tending and the hive service are the two operations midnight reopens")
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
	"""R06-JOB-004: a failed gate does not consume seed. Decision 0059's allocate-before-consume."""
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


# --- R06-JOB-001/002: the forage demand producer -----------------------------------------------
#
# The ruling's acceptance list is again the test list: a generated basin creates nothing; disabled,
# protected and unbound sources create no work; repeated enable/dirty events create no duplicate
# claim; two jobs cannot spend the same quota; a failed gate consumes nothing.


class DangerousForage extends ForageScript:
	"""A forage store whose zone danger band can be changed after creation.

	systems_architecture.md requires the Job's `dangerous` flag to be recomputed from the owning
	zone's danger "whenever that danger value changes", and forage.gd publishes NO danger mutator,
	so that half of the obligation has no trigger through the public API. This subclass supplies
	one for the test alone, exactly as test_forage.gd's CorruptibleForage does for the malformed
	stock guard. It writes the packed column and nothing else.
	"""

	func force_danger(slot: int, danger: int) -> void:
		"""Write one zone's §5.5 danger band directly, with no validation and no side effect."""
		_zone_danger[slot] = danger


func _forage_basin(danger: int = 0) -> Vector2i:
	"""A world-generated FORAGE basin owning all five §5.5 patches. It is nobody's designation."""
	var made: ForageScript.OpResult = _forage.create_zone(ZONE_FORAGE, danger, 0, false, true)
	assert_true(made.ok, "the basin is created (error: %s)" % made.error)
	assert_true(_forage.create_patch_set(made.ref, PackedInt32Array([10, 11, 12, 13, 14])).ok,
		"the basin receives §5.5's five patches")
	return made.ref


func _forage_designation(basin: Vector2i, danger: int = 0) -> Vector2i:
	"""A player designation bound to an existing basin: R05-BASIN-002's only legal shape."""
	var made: ForageScript.OpResult = _forage.create_zone(ZONE_FORAGE, danger, 0, false, true)
	assert_true(made.ok, "the designation is created (error: %s)" % made.error)
	assert_true(_forage.set_basin(made.ref, basin).ok, "it binds to the existing basin")
	return made.ref


func _zone_slot(zone_ref: Vector2i) -> int:
	"""The HarvestZone typed row a live zone reference names."""
	var slot: IntMath.IntResult = _forage.zone_slot_of(zone_ref)
	assert_true(slot.ok, "the zone reference resolves (error: %s)" % slot.error)
	return slot.value


func _enabled_designation(danger: int = 0, basin_danger: int = 0) -> int:
	"""A basin, a designation bound to it, and the player's demand enabled. Returns the zone row."""
	var basin: Vector2i = _forage_basin(basin_danger)
	var designation: Vector2i = _forage_designation(basin, danger)
	assert_true(_planner.enable_forage_demand(designation).ok, "the demand enables")
	return _zone_slot(designation)


func _harvest_job_slot(zone_slot: int, kind: int) -> int:
	"""The typed Job row of this demand row's published harvest, asserting one exists."""
	var ref: Vector2i = _planner.forage_demand_job_of(zone_slot, kind)
	assert_true(ref != EntityDirectory.NULL_REF, "the demand row holds a published harvest")
	return _jobs.directory().get_typed_row(ref)


# --- R06-JOB-001: enablement -------------------------------------------------------------------

func test_enabling_a_valid_designation_activates_repeat_harvest_demand() -> void:
	"""R06-JOB-001: a confirmed FORAGE designation bound to an existing basin activates demand."""
	var basin: Vector2i = _forage_basin()
	var designation: Vector2i = _forage_designation(basin)
	var enabled: JobPlannerScript.OpResult = _planner.enable_forage_demand(designation)
	assert_true(enabled.ok, "the demand activates (error: %s)" % enabled.error)
	var zone_slot: int = _zone_slot(designation)
	assert_true(_planner.is_forage_demand_enabled(zone_slot), "the designation carries demand")
	assert_equal(_planner.forage_demand_enabled_count(), 1, "exactly one designation does")
	assert_equal(_planner.forage_demand_owner_of(zone_slot), designation,
		"both halves of the designation's EntityRef are recorded")
	assert_true(_planner.is_zone_dirty(zone_slot), "and its demand is marked for reconciliation")


func test_a_generated_basin_alone_creates_no_harvest_demand() -> void:
	"""R06-JOB-001: "World-generation basin creation alone shall create no harvest demand"."""
	var basin: Vector2i = _forage_basin()
	assert_equal(_forage.zone_count(), 1, "the world generated one stock-owning basin")
	for tick: int in range(DAY_ONE_TICK, DAY_ONE_TICK + JobPlannerScript.STAGGER_MODULUS):
		_planner.run_tick(tick)
	assert_equal(_jobs.job_count(), 0, "a full sweep period creates no job at all")
	assert_equal(_planner.forage_created_count(), 0, "and no harvest is published")
	assert_equal(_forage.claim_count(), 0, "no quota is reserved against the basin")
	assert_equal(_planner.forage_demand_enabled_count(), 0, "no demand was ever enabled")
	assert_false(_planner.is_forage_demand_enabled(_zone_slot(basin)),
		"a basin existing is not a player designation")


func test_enabling_demand_on_a_basin_itself_is_refused() -> void:
	"""R05-BASIN-002 at the producer layer: a zone that owns itself is ecology, not player intent."""
	var basin: Vector2i = _forage_basin()
	var refused: JobPlannerScript.OpResult = _planner.enable_forage_demand(basin)
	assert_false(refused.ok, "the basin cannot carry harvest demand")
	assert_equal(String(refused.error), String(JobPlannerScript.REFUSE_NOT_A_DESIGNATION),
		"and the refusal names the anti-multiplication rule")
	assert_equal(_planner.forage_demand_enabled_count(), 0, "nothing is enabled")


func test_a_zone_of_another_type_is_refused() -> void:
	"""R06-JOB-001 activates demand for a FORAGE designation; a FARM zone is not one."""
	var made: ForageScript.OpResult = _forage.create_zone(ZONE_FARM, 0, 0, false, true)
	assert_true(made.ok, "a FARM zone is created")
	var refused: JobPlannerScript.OpResult = _planner.enable_forage_demand(made.ref)
	assert_false(refused.ok, "a FARM zone carries no forage demand")
	assert_equal(String(refused.error), String(JobPlannerScript.REFUSE_ZONE_TYPE_MISMATCH),
		"the refusal names the type gate")


func test_a_disabled_designation_is_refused() -> void:
	"""§4.2's `enabled` flag: a disabled source creates no work."""
	var designation: Vector2i = _forage_designation(_forage_basin())
	assert_true(_forage.set_zone_enabled(designation, false).ok, "the designation is disabled")
	var refused: JobPlannerScript.OpResult = _planner.enable_forage_demand(designation)
	assert_false(refused.ok, "a disabled designation carries no demand")
	assert_equal(String(refused.error), String(JobPlannerScript.REFUSE_ZONE_DISABLED),
		"the refusal names the enabled flag")


func test_a_protected_designation_is_refused() -> void:
	"""§5.5: "Protected tiles are never automatically harvested"."""
	var designation: Vector2i = _forage_designation(_forage_basin())
	assert_true(_forage.set_zone_protected(designation, true).ok, "the designation is protected")
	var refused: JobPlannerScript.OpResult = _planner.enable_forage_demand(designation)
	assert_false(refused.ok, "a protected designation carries no demand")
	assert_equal(String(refused.error), String(JobPlannerScript.REFUSE_ZONE_PROTECTED),
		"the refusal names the protection gate")


func test_a_designation_bound_to_no_existing_basin_is_refused() -> void:
	"""R06-JOB-001 requires a designation BOUND TO AN EXISTING BASIN; a destroyed one is neither."""
	var basin: Vector2i = _forage_basin()
	var designation: Vector2i = _forage_designation(basin)
	assert_true(_forage.destroy_zone(basin).ok, "the basin is destroyed under the designation")
	var refused: JobPlannerScript.OpResult = _planner.enable_forage_demand(designation)
	assert_false(refused.ok, "the designation names a basin that no longer resolves")
	assert_equal(String(refused.error), String(JobPlannerScript.REFUSE_BASIN_NOT_PRESENT),
		"the refusal names the basin binding")


func test_a_stale_zone_reference_is_refused() -> void:
	"""A destroyed designation's reference must not enable demand on whatever reuses its row."""
	var designation: Vector2i = _forage_designation(_forage_basin())
	assert_true(_forage.destroy_zone(designation).ok, "the designation is destroyed")
	var refused: JobPlannerScript.OpResult = _planner.enable_forage_demand(designation)
	assert_false(refused.ok, "a stale reference enables nothing")
	assert_equal(String(refused.error), String(JobPlannerScript.REFUSE_ZONE_NOT_PRESENT),
		"the refusal names the missing zone")


func test_a_second_enable_on_the_same_designation_is_refused() -> void:
	"""Idempotence: N confirmations activate ONE demand and allocate nothing twice."""
	var zone_slot: int = _enabled_designation()
	var again: JobPlannerScript.OpResult = _planner.enable_forage_demand(
		_forage.zone_ref_of(zone_slot))
	assert_false(again.ok, "the second enable is refused")
	assert_equal(String(again.error), String(JobPlannerScript.REFUSE_DEMAND_ENABLED),
		"and names the demand that is already active")
	assert_equal(_planner.forage_demand_enabled_count(), 1, "still exactly one demand")


# --- R06-JOB-002: quantified claims ------------------------------------------------------------

func test_work_is_created_against_an_explicitly_quantified_claim() -> void:
	"""R06-JOB-002: eligible FORAGE work against explicitly quantified claims."""
	var zone_slot: int = _enabled_designation()
	var created: JobPlannerScript.OpResult = _planner.reconcile_forage_kind(zone_slot,
		PATCH_MUSHROOMS, DAY_ONE_TICK)
	assert_true(created.ok, "the harvest is created (error: %s)" % created.error)
	assert_equal(_jobs.job_count(), 1, "exactly one job exists")
	var job: int = _harvest_job_slot(zone_slot, PATCH_MUSHROOMS)
	assert_equal(_jobs.kind_of(job).value, KIND_FORAGE, "a harvest is a FORAGE job")
	assert_equal(_forage.claim_count(), 1, "and it owns exactly one forage claim")
	var claim: IntMath.IntResult = _forage.claim_row_of(_jobs.ref_of(job))
	assert_true(claim.ok, "the claim is indexed by the owning Job's typed row")
	assert_equal(_forage.claim_remaining_milli_of(claim.value).value,
		SPRING_AUTOMATIC_QUOTA_MILLI,
		"the claim quantifies spring's whole automatic daily allowance")
	assert_equal(_planner.quantified_claim_milli_of(zone_slot, PATCH_MUSHROOMS).value,
		SPRING_AUTOMATIC_QUOTA_MILLI, "and the demand row records the same quantity")


func test_the_quantified_amount_is_forages_own_admissibility_bound() -> void:
	"""Decision 0030's `min(available_quota, stock_available)`, read from the owning store."""
	var basin: Vector2i = _forage_basin()
	assert_true(_forage.set_quota_milli(basin, MANUAL_QUOTA_MAX_MILLI, SPRING).ok,
		"the basin takes a manual quota large enough for the stock to bind instead")
	var designation: Vector2i = _forage_designation(basin)
	assert_true(_planner.enable_forage_demand(designation).ok, "the demand enables")
	var zone_slot: int = _zone_slot(designation)
	var expected: IntMath.IntResult = _forage.harvestable_milli(designation, PATCH_MUSHROOMS,
		SPRING, false)
	assert_true(expected.ok, "forage.gd answers its own admissibility bound")
	assert_equal(expected.value, MUSHROOM_INITIAL_MILLI - MUSHROOM_FLOOR_MILLI,
		"which here is §5.1's 80% stock less REQ-SET-066's 20% floor")
	assert_equal(_planner.forage_quantity_for(zone_slot, PATCH_MUSHROOMS, SPRING).value,
		expected.value, "and the producer quantifies exactly that, from the same store")


func test_the_harvest_carries_the_rulings_priority_three_default() -> void:
	"""The ruling: ordinary newly generated work has priority 3."""
	var zone_slot: int = _enabled_designation()
	assert_true(_planner.reconcile_forage_kind(zone_slot, PATCH_MUSHROOMS, DAY_ONE_TICK).ok,
		"the harvest is created")
	var job: int = _harvest_job_slot(zone_slot, PATCH_MUSHROOMS)
	assert_equal(_jobs.priority_of(job).value, ORDINARY_PRIORITY, "job priority is 3")
	assert_equal(_jobs.urgency_of(job).value, JobsScript.URGENCY_ORDINARY,
		"the urgency bucket stays ordinary, which is a different field from job priority")


func test_a_created_harvest_stays_queued_and_is_never_written_into_work() -> void:
	"""The ruling: creating a job does not authorize teleporting its worker into WORK."""
	var zone_slot: int = _enabled_designation()
	assert_true(_planner.reconcile_forage_kind(zone_slot, PATCH_MUSHROOMS, DAY_ONE_TICK).ok,
		"the harvest is created")
	var job: int = _harvest_job_slot(zone_slot, PATCH_MUSHROOMS)
	assert_equal(_jobs.state_of(job).value, STATE_QUEUED, "a new harvest is QUEUED")
	_planner.run_tick(DAY_ONE_TICK)
	assert_equal(_jobs.state_of(job).value, STATE_QUEUED, "a planner tick does not advance it")
	assert_true(_jobs.state_of(job).value != STATE_WORK, "nothing here writes JOB_STATE_WORK")


func test_the_harvest_names_its_designation_as_the_source_and_no_destination() -> void:
	"""The designation is the work's source; no output binding exists to name a destination."""
	var zone_slot: int = _enabled_designation()
	assert_true(_planner.reconcile_forage_kind(zone_slot, PATCH_MUSHROOMS, DAY_ONE_TICK).ok,
		"the harvest is created")
	var job: int = _harvest_job_slot(zone_slot, PATCH_MUSHROOMS)
	assert_equal(_jobs.source_of(job), _forage.zone_ref_of(zone_slot),
		"source is the designation's EntityRef")
	assert_equal(_jobs.destination_of(job), EntityDirectory.NULL_REF, "destination stays null")


func test_the_output_space_gate_cannot_be_answered_and_refuses_at_selection() -> void:
	"""Output space and legal access have no owning store, so the Job declares them UNANSWERABLE."""
	var zone_slot: int = _enabled_designation()
	assert_true(_planner.reconcile_forage_kind(zone_slot, PATCH_MUSHROOMS, DAY_ONE_TICK).ok,
		"the harvest is created")
	var job: int = _harvest_job_slot(zone_slot, PATCH_MUSHROOMS)
	assert_equal(_jobs.inputs_gate_of(job).value, GATE_UNAVAILABLE,
		"the gate says the owning system cannot answer, not that a container was found")
	var worker: int = _worker()
	var assigned: JobsScript.OpResult = _jobs.assign_worker(worker, job)
	assert_false(assigned.ok, "so the harvest refuses at selection")


func test_the_work_total_is_section_five_fives_formula_at_the_unskilled_level() -> void:
	"""§5.5's `work_per_u` times the claimed milli-units, with no worker bound to read a level."""
	var zone_slot: int = _enabled_designation()
	assert_true(_planner.reconcile_forage_kind(zone_slot, PATCH_MUSHROOMS, DAY_ONE_TICK).ok,
		"the harvest is created")
	var job: int = _harvest_job_slot(zone_slot, PATCH_MUSHROOMS)
	assert_equal(_jobs.remaining_mwu_of(job).value,
		MUSHROOM_BASE_WORK_WU * SPRING_AUTOMATIC_QUOTA_MILLI,
		"5 WU/U at FORAGE level 0 and natural danger 0, times the claimed milli-units")


func test_the_same_available_quantity_is_not_reserved_twice() -> void:
	"""R06-JOB-002: "It shall not reserve the same available quantity twice"."""
	var basin: Vector2i = _forage_basin()
	var first: Vector2i = _forage_designation(basin)
	var second: Vector2i = _forage_designation(basin)
	assert_true(_planner.enable_forage_demand(first).ok, "the first demand enables")
	assert_true(_planner.enable_forage_demand(second).ok, "the second demand enables")
	assert_true(_forage.zones_share_basin(first, second), "both draw from the one basin")
	assert_true(_planner.reconcile_forage_kind(_zone_slot(first), PATCH_MUSHROOMS,
		DAY_ONE_TICK).ok, "the first designation claims the day's allowance")
	var refused: JobPlannerScript.OpResult = _planner.reconcile_forage_kind(_zone_slot(second),
		PATCH_MUSHROOMS, DAY_ONE_TICK)
	assert_false(refused.ok, "the second designation is offered nothing")
	assert_equal(String(refused.error), String(JobPlannerScript.REFUSE_NOTHING_HARVESTABLE),
		"because the outstanding claim already counts against the shared allowance")
	assert_equal(_jobs.job_count(), 1, "one job, not two")
	assert_equal(_forage.claim_count(), 1, "and one claim over the shared basin")


func test_the_aggregate_quota_is_spent_once_across_the_five_kinds() -> void:
	"""Decision 0030's quota is aggregate, so an early kind's claim leaves less for a later one."""
	var zone_slot: int = _enabled_designation()
	assert_equal(_planner.reconcile_forage_zone(zone_slot, DAY_ONE_TICK).value, 1,
		"one harvest is published, not one per kind")
	assert_equal(_planner.forage_claimed_milli(), SPRING_AUTOMATIC_QUOTA_MILLI,
		"and it reserved the whole daily allowance")
	assert_equal(_planner.forage_demand_blocker_of(zone_slot, PATCH_HERB).value,
		JobPlannerScript.BLOCKER_NOTHING_HARVESTABLE,
		"herb is available in spring but the allowance is already spent")


func test_a_wider_quota_publishes_one_harvest_for_each_available_kind() -> void:
	"""With stock rather than quota binding, every in-season kind gets its own claim and Job."""
	var basin: Vector2i = _forage_basin()
	assert_true(_forage.set_quota_milli(basin, MANUAL_QUOTA_MAX_MILLI, SPRING).ok,
		"the basin takes the manual maximum")
	var designation: Vector2i = _forage_designation(basin)
	assert_true(_planner.enable_forage_demand(designation).ok, "the demand enables")
	var zone_slot: int = _zone_slot(designation)
	assert_equal(_planner.reconcile_forage_zone(zone_slot, DAY_ONE_TICK).value, 3,
		"mushrooms, herb and roots publish; berries and nuts are dormant in spring")
	assert_equal(_jobs.job_count(), 3, "three jobs")
	assert_equal(_forage.claim_count(), 3, "three claims, one per Job per decision 0030")
	assert_equal(_planner.forage_demand_blocker_of(zone_slot, PATCH_BERRIES).value,
		JobPlannerScript.BLOCKER_PATCH_DORMANT, "berries record the dormancy that stopped them")


func test_a_dormant_kind_creates_no_work() -> void:
	"""§5.5: berries have zero spring availability, so no harvest may be quantified."""
	var zone_slot: int = _enabled_designation()
	assert_equal(_forage.availability_per_1000(PATCH_BERRIES, SPRING).value,
		SPRING_BERRIES_AVAILABILITY, "§5.5 makes berries dormant in spring")
	var refused: JobPlannerScript.OpResult = _planner.reconcile_forage_kind(zone_slot,
		PATCH_BERRIES, DAY_ONE_TICK)
	assert_false(refused.ok, "a dormant kind publishes nothing")
	assert_equal(String(refused.error), String(JobPlannerScript.REFUSE_PATCH_DORMANT),
		"and the refusal names the season, not the quota")


func test_a_basin_without_that_patch_refuses() -> void:
	"""A kind the basin owns no ForagePatch of is refused rather than quantified as zero."""
	var made: ForageScript.OpResult = _forage.create_zone(ZONE_FORAGE, 0, 0, false, true)
	assert_true(_forage.create_patch(made.ref, PATCH_MUSHROOMS, 12).ok, "one patch only")
	var designation: Vector2i = _forage_designation(made.ref)
	assert_true(_planner.enable_forage_demand(designation).ok, "the demand enables")
	var refused: JobPlannerScript.OpResult = _planner.reconcile_forage_kind(
		_zone_slot(designation), PATCH_HERB, DAY_ONE_TICK)
	assert_false(refused.ok, "the missing patch publishes nothing")
	assert_equal(String(refused.error), String(JobPlannerScript.REFUSE_PATCH_NOT_PRESENT),
		"and the refusal names the absent patch")


# --- REQ-SET-067: the derived dangerous flag ---------------------------------------------------

func test_the_dangerous_flag_is_derived_from_the_designations_own_danger() -> void:
	"""ARCH: the flag comes from the owning HarvestZone's danger, not from a caller's argument."""
	var safe: int = _enabled_designation(1)
	assert_true(_planner.reconcile_forage_kind(safe, PATCH_MUSHROOMS, DAY_ONE_TICK).ok,
		"the safe designation publishes")
	assert_false(_jobs.is_dangerous(_harvest_job_slot(safe, PATCH_MUSHROOMS)),
		"danger band 1 is below REQ-SET-067's threshold")
	var risky: int = _enabled_designation(DANGEROUS_BAND)
	assert_true(_planner.reconcile_forage_kind(risky, PATCH_MUSHROOMS, DAY_ONE_TICK).ok,
		"the risky designation publishes")
	assert_true(_jobs.is_dangerous(_harvest_job_slot(risky, PATCH_MUSHROOMS)),
		"danger band 2 makes the harvest subject to the dangerous-work permission")


func test_the_dangerous_flag_reads_the_designation_not_its_basin() -> void:
	"""forage.gd separates the basin's NATURAL danger from the harvesting zone's HAZARD band."""
	var zone_slot: int = _enabled_designation(0, 3)
	assert_true(_planner.reconcile_forage_kind(zone_slot, PATCH_MUSHROOMS, DAY_ONE_TICK).ok,
		"a safe designation over a dangerous basin publishes")
	assert_false(_jobs.is_dangerous(_harvest_job_slot(zone_slot, PATCH_MUSHROOMS)),
		"the flag follows the designation's own band, which is 0")
	assert_equal(_forage.natural_danger_of(_forage.zone_ref_of(zone_slot)).value, 3,
		"while §5.5's work formula still reads the basin's natural danger of 3")


func test_the_dangerous_flag_is_recomputed_when_the_zones_danger_changes() -> void:
	"""ARCH: "and whenever that danger value changes"."""
	_forage = DangerousForage.new(_jobs.directory(), _jobs)
	_planner = JobPlannerScript.new(_farming, _jobs, _forage)
	var zone_slot: int = _enabled_designation(0)
	assert_true(_planner.reconcile_forage_kind(zone_slot, PATCH_MUSHROOMS, DAY_ONE_TICK).ok,
		"the harvest publishes at danger 0")
	var job: int = _harvest_job_slot(zone_slot, PATCH_MUSHROOMS)
	assert_false(_jobs.is_dangerous(job), "and is not dangerous")
	(_forage as DangerousForage).force_danger(zone_slot, 3)
	_planner.mark_zone_dirty(zone_slot)
	_planner.run_tick(DAY_ONE_TICK)
	assert_true(_jobs.is_dangerous(job), "reconciling the changed designation recomputes the flag")
	assert_equal(_jobs.job_count(), 1, "and publishes no second harvest")


func test_the_consent_check_itself_is_not_duplicated_here() -> void:
	"""Storing consent is priorities.gd's; checking it is job eligibility's."""
	var zone_slot: int = _enabled_designation(DANGEROUS_BAND)
	assert_true(_planner.reconcile_forage_kind(zone_slot, PATCH_MUSHROOMS, DAY_ONE_TICK).ok,
		"a danger-2 designation still publishes its harvest")
	var worker: int = _worker()
	assert_equal(_priorities.dangerous_work_of(worker).value, 0,
		"§4.2 defaults the resident's dangerous_work permission to false")
	assert_true(_jobs.is_dangerous(_harvest_job_slot(zone_slot, PATCH_MUSHROOMS)),
		"the producer sets the flag the eligibility check reads, and stops there")


# --- the midnight boundary: repeat demand is not a daily service -------------------------------

func test_midnight_neither_settles_nor_reopens_forage_demand() -> void:
	"""Repeat demand is not a daily service: midnight must not retire it as unserved."""
	var zone_slot: int = _enabled_designation()
	assert_true(_planner.reconcile_forage_kind(zone_slot, PATCH_MUSHROOMS, DAY_ONE_TICK).ok,
		"the harvest is published on day one")
	var before: Vector2i = _planner.forage_demand_job_of(zone_slot, PATCH_MUSHROOMS)
	assert_true(_planner.run_day_boundary(FIRST_MIDNIGHT_TICK).ok, "the day boundary runs")
	_planner.run_tick(FIRST_MIDNIGHT_TICK)
	assert_equal(_planner.forage_demand_job_of(zone_slot, PATCH_MUSHROOMS), before,
		"the same Job survives the boundary")
	assert_equal(_planner.settled_unserved_count(), 0,
		"midnight settled no forage demand as unserved")
	assert_equal(_planner.forage_cancelled_count(), 0, "and cancelled nothing")
	assert_equal(_planner.forage_created_count(), 1, "no second harvest was opened for the new day")


func test_a_pending_harvest_does_not_block_the_daily_service_boundary() -> void:
	"""A demand row carries no service day, so it can never make a day unsettleable."""
	var zone_slot: int = _enabled_designation()
	assert_true(_planner.reconcile_forage_kind(zone_slot, PATCH_MUSHROOMS, DAY_ONE_TICK).ok,
		"the harvest is published")
	assert_true(_planner.preceding_day_is_settled(2),
		"the preceding day is settled with a harvest outstanding")
	assert_true(_planner.run_day_boundary(FIRST_MIDNIGHT_TICK).ok, "so the boundary opens day two")


func test_the_forage_operation_is_not_a_daily_service_operation() -> void:
	"""`is_daily_service_operation()` keeps repeat demand out of the daily machinery."""
	assert_false(_planner.is_daily_service_operation(JobPlannerScript.OPERATION_FORAGE_HARVEST),
		"the forage operation is not reopened or settled at midnight")
	assert_true(_planner.is_daily_service_operation(TEND_OPERATION), "tending still is")
	assert_false(_planner.is_operation(JobPlannerScript.OPERATION_FORAGE_HARVEST),
		"and it does not address the FarmPlot pending-service table at all")
	assert_equal(JobPlannerScript.OPERATION_DOMAIN_COUNT, 5,
		"five operations across the four owner classes R06-JOB names")


func test_the_day_boundary_marks_designations_for_the_new_days_allowance() -> void:
	"""Resetting the day's collected totals IS quota becoming available, R06-JOB-002's trigger."""
	var zone_slot: int = _enabled_designation()
	_planner.reconcile_dirty_zones(DAY_ONE_TICK, JobPlannerScript.ZONE_OWNER_CAPACITY)
	assert_false(_planner.is_zone_dirty(zone_slot), "the enable's own dirty mark is drained first")
	assert_true(_planner.run_day_boundary(FIRST_MIDNIGHT_TICK).ok, "the day boundary runs")
	assert_true(_planner.is_zone_dirty(zone_slot), "the designation is marked for reconciliation")


func test_a_live_harvest_answers_pending_rather_than_an_empty_ecology() -> void:
	"""The idempotence guard is a distinct answer: work already out is not an exhausted patch."""
	var zone_slot: int = _enabled_designation()
	assert_true(_planner.reconcile_forage_kind(zone_slot, PATCH_MUSHROOMS, DAY_ONE_TICK).ok,
		"the harvest publishes")
	var again: JobPlannerScript.OpResult = _planner.reconcile_forage_kind(zone_slot,
		PATCH_MUSHROOMS, DAY_ONE_TICK)
	assert_false(again.ok, "a second reconciliation publishes nothing")
	assert_equal(String(again.error), String(JobPlannerScript.REFUSE_DEMAND_PENDING),
		"and says the harvest is already pending, not that the ecology offered nothing")
	assert_equal(_planner.forage_demand_blocker_of(zone_slot, PATCH_MUSHROOMS).value,
		JobPlannerScript.BLOCKER_NONE, "so no gate reason is recorded against a live harvest")


func test_a_stale_claim_on_a_reused_job_row_refuses_and_publishes_nothing() -> void:
	"""A claim left behind by a destroyed Job must not be silently overwritten by the next one.

	Overwriting it would be exactly the double reservation R06-JOB-002 forbids: the abandoned
	claim's quantity is still counted against the shared allowance, and a second claim on the same
	row would hand it out again. forage.gd refuses with CLAIM_STALE_JOB and the producer passes
	that refusal through, destroying the Job it had just allocated.
	"""
	var basin: Vector2i = _forage_basin()
	var designation: Vector2i = _forage_designation(basin)
	assert_true(_planner.enable_forage_demand(designation).ok, "the demand enables")
	var stray: JobsScript.OpResult = _jobs.create_job(KIND_FORAGE, 0, 0, 100, 0)
	assert_true(stray.ok, "an unrelated FORAGE job takes the first claim row")
	assert_true(_forage.claim_forage(stray.ref, designation, PATCH_MUSHROOMS, 1000, SPRING,
		false).ok, "it claims a thousand milli-units")
	assert_true(_jobs.destroy_job(stray.value).ok, "and is destroyed without releasing the claim")
	var refused: JobPlannerScript.OpResult = _planner.reconcile_forage_kind(
		_zone_slot(designation), PATCH_MUSHROOMS, DAY_ONE_TICK)
	assert_false(refused.ok, "the producer cannot claim over the abandoned row")
	assert_equal(String(refused.error), "CLAIM_STALE_JOB",
		"and passes forage.gd's own refusal through rather than inventing one")
	assert_equal(_jobs.job_count(), 0, "the Job it allocated for the attempt is destroyed")
	assert_equal(_planner.forage_demand_status_of(_zone_slot(designation),
		PATCH_MUSHROOMS).value, JobPlannerScript.STATUS_FREE, "and no demand row is published")


# --- R06-JOB-008: idempotence, retention and the lifecycle -------------------------------------

func test_repeated_enable_and_dirty_events_create_one_harvest() -> void:
	"""The ruling: repeated enable/dirty events create no duplicate claim."""
	var zone_slot: int = _enabled_designation()
	for _repeat: int in 20:
		_planner.enable_forage_demand(_forage.zone_ref_of(zone_slot))
		_planner.mark_zone_dirty(zone_slot)
		_planner.reconcile_forage_zone(zone_slot, DAY_ONE_TICK)
	assert_equal(_jobs.job_count(), 1, "twenty reconciliations publish one harvest")
	assert_equal(_forage.claim_count(), 1, "and reserve one claim")
	assert_equal(_planner.forage_created_count(), 1, "the producer counts one creation")
	assert_equal(_planner.pending_forage_demand_count(), 1, "one demand row is pending")


func test_the_zone_dirty_set_is_idempotent_and_bounded() -> void:
	"""One entry per designation however many events name it."""
	var zone_slot: int = _enabled_designation()
	for _repeat: int in 50:
		assert_true(_planner.mark_zone_dirty(zone_slot).ok, "marking succeeds")
	assert_equal(_planner.zone_dirty_count(), 1, "fifty events make one entry")
	assert_true(_planner.is_zone_dirty(zone_slot), "and the membership bit is set")
	assert_false(_planner.mark_zone_dirty(JobPlannerScript.ZONE_OWNER_CAPACITY).ok,
		"a slot past the HarvestZone capacity refuses")


func test_a_completed_harvest_settles_and_repeat_demand_publishes_again() -> void:
	"""Repeat demand outlives the work it produced: released capacity is a new trigger."""
	var zone_slot: int = _enabled_designation()
	assert_true(_planner.reconcile_forage_kind(zone_slot, PATCH_MUSHROOMS, DAY_ONE_TICK).ok,
		"the first harvest publishes")
	var job: int = _harvest_job_slot(zone_slot, PATCH_MUSHROOMS)
	assert_true(_jobs.set_state(job, STATE_COMPLETE).ok, "the harvest completes")
	assert_true(_planner.reconcile_forage_kind(zone_slot, PATCH_MUSHROOMS, DAY_ONE_TICK).ok,
		"the same reconcile settles it and publishes the next one")
	assert_equal(_planner.forage_completed_count(), 1, "one completion is recorded")
	assert_equal(_planner.forage_created_count(), 2, "and a second harvest is published")
	assert_equal(_jobs.job_count(), 1, "the completed Job's row was released first")
	assert_equal(_forage.claim_count(), 1, "and its uncollected claim released with it")
	assert_true(_planner.is_forage_demand_enabled(zone_slot), "the standing policy is untouched")


func test_a_cancelled_harvest_is_recorded_and_its_claim_released() -> void:
	"""A CANCELLED Job is recorded as cancelled rather than read as a completion."""
	var zone_slot: int = _enabled_designation()
	assert_true(_planner.reconcile_forage_kind(zone_slot, PATCH_MUSHROOMS, DAY_ONE_TICK).ok,
		"the harvest publishes")
	var job: int = _harvest_job_slot(zone_slot, PATCH_MUSHROOMS)
	assert_true(_jobs.set_state(job, STATE_CANCELLED).ok, "the harvest is cancelled")
	_planner.reconcile_forage_kind(zone_slot, PATCH_MUSHROOMS, DAY_ONE_TICK)
	assert_equal(_planner.forage_cancelled_count(), 1, "the cancellation is counted as one")
	assert_equal(_planner.forage_completed_count(), 0, "and not as a completion")


func test_a_destroyed_designation_leaves_no_job_and_no_claim_behind() -> void:
	"""Decision 0040's lesson: a record on a vanished owner must not keep its Job alive forever."""
	var zone_slot: int = _enabled_designation()
	assert_true(_planner.reconcile_forage_kind(zone_slot, PATCH_MUSHROOMS, DAY_ONE_TICK).ok,
		"the harvest publishes")
	assert_true(_forage.destroy_zone(_forage.zone_ref_of(zone_slot)).ok,
		"the designation is destroyed under it")
	for tick: int in range(DAY_ONE_TICK, DAY_ONE_TICK + JobPlannerScript.STAGGER_MODULUS):
		_planner.run_tick(tick)
	assert_equal(_jobs.job_count(), 0,
		"one idle sweep period cancels the orphaned Job and releases its row")
	assert_equal(_forage.claim_count(), 0, "and no claim survives it")
	assert_false(_planner.is_forage_demand_enabled(zone_slot), "the demand record is dropped")
	assert_true(_planner.demand_row_is_clear(zone_slot, PATCH_MUSHROOMS),
		"and the row keeps no residue for its next occupant")
	assert_equal(_planner.forage_demand_owner_of(zone_slot), EntityDirectory.NULL_REF,
		"including the owner reference it was enabled against")


func test_a_reused_zone_row_does_not_inherit_the_previous_demand() -> void:
	"""Both halves of the owner EntityRef are checked, so a new zone starts with no demand."""
	var basin: Vector2i = _forage_basin()
	var first: Vector2i = _forage_designation(basin)
	var zone_slot: int = _zone_slot(first)
	assert_true(_planner.enable_forage_demand(first).ok, "the first designation enables demand")
	assert_true(_forage.destroy_zone(first).ok, "it is destroyed")
	var second: Vector2i = _forage_designation(basin)
	assert_equal(_zone_slot(second), zone_slot, "the freed HarvestZone row is reused")
	assert_true(second != first, "but the reference carries a new generation")
	_planner.run_tick(DAY_ONE_TICK)
	assert_false(_planner.is_forage_demand_enabled(zone_slot),
		"the new designation inherits no demand and must be enabled again")
	assert_equal(_jobs.job_count(), 0, "so nothing is published for it")


func test_disabling_stops_new_work_and_retains_the_outstanding_harvest() -> void:
	"""The acceptance list: disabled sources create no NEW work. Accepted work is not withdrawn."""
	var basin: Vector2i = _forage_basin()
	assert_true(_forage.set_quota_milli(basin, MANUAL_QUOTA_MAX_MILLI, SPRING).ok,
		"the basin takes the manual maximum so a second kind could publish")
	var designation: Vector2i = _forage_designation(basin)
	assert_true(_planner.enable_forage_demand(designation).ok, "the demand enables")
	var zone_slot: int = _zone_slot(designation)
	assert_true(_planner.reconcile_forage_kind(zone_slot, PATCH_MUSHROOMS, DAY_ONE_TICK).ok,
		"a harvest publishes")
	assert_true(_planner.disable_forage_demand(designation).ok, "the player disables the demand")
	_planner.run_tick(DAY_ONE_TICK)
	assert_equal(_jobs.job_count(), 1, "no new harvest is published for any kind")
	assert_equal(_planner.forage_demand_status_of(zone_slot, PATCH_MUSHROOMS).value,
		JobPlannerScript.STATUS_PENDING, "and the accepted one is retained, not cancelled")
	assert_equal(_planner.forage_demand_blocker_of(zone_slot, PATCH_HERB).value,
		JobPlannerScript.BLOCKER_DEMAND_NOT_ENABLED, "the retained reason names the disable")


func test_disabling_a_designation_that_carries_no_demand_is_refused() -> void:
	"""Refuse rather than report a silent no-op."""
	var designation: Vector2i = _forage_designation(_forage_basin())
	var refused: JobPlannerScript.OpResult = _planner.disable_forage_demand(designation)
	assert_false(refused.ok, "there is nothing to disable")
	assert_equal(String(refused.error), String(JobPlannerScript.REFUSE_DEMAND_NOT_ENABLED),
		"and the refusal says so")


func test_forage_capacity_exhaustion_retains_demand_and_reports_a_blocker() -> void:
	"""R06-JOB-008: exhaustion retains unmet policy demand and reports a blocker."""
	var zone_slot: int = _enabled_designation()
	assert_equal(_fill_the_job_arena(), 8192, "the arena holds GDD §4.2's 8192 jobs")
	var refused: JobPlannerScript.OpResult = _planner.reconcile_forage_kind(zone_slot,
		PATCH_MUSHROOMS, DAY_ONE_TICK)
	assert_false(refused.ok, "the harvest cannot be created")
	assert_equal(_planner.unmet_forage_demand_count(), 1, "the demand is retained")
	assert_true(_planner.last_blocker() != JobPlannerScript.REFUSE_NONE,
		"the blocker carries the refusing store's own code, not an invented one")
	assert_equal(_planner.quantified_claim_milli_of(zone_slot, PATCH_MUSHROOMS).value,
		SPRING_AUTOMATIC_QUOTA_MILLI, "retained demand remembers the quantity it could not claim")
	assert_equal(_forage.claim_count(), 0, "and no quota was reserved for a Job that never existed")


func test_retained_forage_demand_never_becomes_an_unbounded_queue() -> void:
	"""R06-JOB-008: it shall not create a hidden unbounded queue."""
	var zone_slot: int = _enabled_designation()
	_fill_the_job_arena()
	for _repeat: int in 200:
		_planner.mark_zone_dirty(zone_slot)
		_planner.reconcile_forage_kind(zone_slot, PATCH_MUSHROOMS, DAY_ONE_TICK)
	assert_equal(_planner.unmet_forage_demand_count(), 1,
		"two hundred refusals retain one row, because retention is one row per demand")
	assert_equal(_planner.pending_forage_demand_count(), 0, "and nothing was created")


func test_released_capacity_retries_the_retained_forage_demand() -> void:
	"""R06-JOB-008: retry when capacity is released."""
	var zone_slot: int = _enabled_designation()
	_fill_the_job_arena()
	assert_false(_planner.reconcile_forage_kind(zone_slot, PATCH_MUSHROOMS, DAY_ONE_TICK).ok,
		"the first attempt is refused")
	_planner.reconcile_dirty_zones(DAY_ONE_TICK, JobPlannerScript.ZONE_OWNER_CAPACITY)
	assert_false(_planner.is_zone_dirty(zone_slot), "the enable's dirty mark is drained")
	assert_true(_jobs.destroy_job(0).ok, "one job row is released")
	assert_equal(_planner.mark_capacity_released(), 1, "the retained demand is re-marked dirty")
	assert_true(_planner.run_tick(DAY_ONE_TICK).value >= 1, "and the retry creates the harvest")
	assert_equal(_planner.unmet_forage_demand_count(), 0, "no demand remains unmet")
	assert_equal(_planner.pending_forage_demand_count(), 1, "exactly one harvest is pending")


# --- decision 0059: a refusal consumes nothing -------------------------------------------------

func _quota_and_stock_fingerprint(basin: Vector2i, designation: Vector2i) -> PackedInt64Array:
	"""Every quantity a refused reconciliation must leave byte-identical, in one comparable row."""
	var basin_slot: int = _zone_slot(basin)
	var zone_slot: int = _zone_slot(designation)
	return PackedInt64Array([
		_forage.harvested_today_milli_of(basin_slot).value,
		_forage.quota_reserved_milli_of(basin_slot).value,
		_forage.harvested_today_milli_of(zone_slot).value,
		_forage.quota_reserved_milli_of(zone_slot).value,
		_forage.stock_milli_of(basin_slot * 5 + PATCH_MUSHROOMS).value,
		_forage.harvested_year_milli_of(basin_slot * 5 + PATCH_MUSHROOMS).value,
		_forage.claim_count(), _jobs.job_count(),
	])


func test_a_refused_gate_leaves_quota_and_stock_byte_identical() -> void:
	"""Decision 0059's allocate-before-consume: a failed gate consumes nothing."""
	var basin: Vector2i = _forage_basin()
	var designation: Vector2i = _forage_designation(basin)
	assert_true(_planner.enable_forage_demand(designation).ok, "the demand enables")
	var before: PackedInt64Array = _quota_and_stock_fingerprint(basin, designation)
	assert_true(_forage.set_zone_protected(designation, true).ok, "the designation is protected")
	var zone_slot: int = _zone_slot(designation)
	for _repeat: int in 20:
		assert_false(_planner.reconcile_forage_kind(zone_slot, PATCH_MUSHROOMS, DAY_ONE_TICK).ok,
			"a protected designation publishes nothing")
	assert_equal(_quota_and_stock_fingerprint(basin, designation), before,
		"twenty refusals leave every quota, stock and count byte-identical")
	assert_equal(_planner.forage_claimed_milli(), 0, "and reserve not one milli-unit")


func test_a_capacity_refusal_leaves_quota_and_stock_byte_identical() -> void:
	"""The refusal that happens AFTER the gates pass must be atomic too."""
	var basin: Vector2i = _forage_basin()
	var designation: Vector2i = _forage_designation(basin)
	assert_true(_planner.enable_forage_demand(designation).ok, "the demand enables")
	var before: PackedInt64Array = _quota_and_stock_fingerprint(basin, designation)
	assert_equal(_fill_the_job_arena(), 8192, "the job arena is full")
	assert_false(_planner.reconcile_forage_kind(_zone_slot(designation), PATCH_MUSHROOMS,
		DAY_ONE_TICK).ok, "the harvest cannot be created")
	var after: PackedInt64Array = _quota_and_stock_fingerprint(basin, designation)
	assert_equal(after[1], before[1], "the basin reserved nothing")
	assert_equal(after[3], before[3], "the designation reserved nothing")
	assert_equal(after[4], before[4], "the stock is untouched")
	assert_equal(after[6], before[6], "and no claim exists")
	assert_equal(_planner.forage_claimed_milli(), 0, "nothing was reserved")


# --- the schema, the reasons and the pure questions --------------------------------------------

func test_the_demand_row_is_the_owner_major_index_of_the_patch_block() -> void:
	"""`z * 5 + kind`, the same stride forage.gd's ForagePatch block uses."""
	assert_equal(JobPlannerScript.ZONE_OWNER_CAPACITY, 128, "GDD §4.2's 128 HarvestZone rows")
	assert_equal(JobPlannerScript.PATCH_KIND_COUNT, 5, "§5.5's five forage kinds")
	assert_equal(JobPlannerScript.DEMAND_ROW_COUNT, 640, "one row per (designation, kind) pair")
	assert_equal(_planner.demand_row(0, PATCH_BERRIES).value, 0, "the first row")
	assert_equal(_planner.demand_row(0, PATCH_ROOTS).value, 4, "the first zone's last kind")
	assert_equal(_planner.demand_row(1, PATCH_BERRIES).value, 5, "the second zone's first kind")
	assert_equal(_planner.demand_row(127, PATCH_ROOTS).value, 639, "and the last row")
	assert_false(_planner.demand_row(128, PATCH_BERRIES).ok, "a zone past capacity refuses")
	assert_false(_planner.demand_row(0, 5).ok, "as does a sixth forage kind")


func test_the_stored_blocker_and_the_returned_refusal_cannot_drift() -> void:
	"""The byte kept on the row maps to the same StringName the refusal carried."""
	var zone_slot: int = _enabled_designation()
	var refused: JobPlannerScript.OpResult = _planner.reconcile_forage_kind(zone_slot,
		PATCH_BERRIES, DAY_ONE_TICK)
	assert_false(refused.ok, "berries are dormant in spring")
	var stored: int = _planner.forage_demand_blocker_of(zone_slot, PATCH_BERRIES).value
	assert_equal(String(_planner.demand_refusal_of_blocker(stored)), String(refused.error),
		"the retained reason and the returned one are the same code")
	assert_equal(String(_planner.demand_refusal_of_blocker(JobPlannerScript.BLOCKER_COUNT)),
		String(JobPlannerScript.REFUSE_INVALID_BLOCKER), "and an out-of-domain byte refuses")


func test_publishing_clears_the_reason_a_previous_gate_left() -> void:
	"""A row that published must not still report why it once could not."""
	var zone_slot: int = _enabled_designation()
	assert_false(_planner.reconcile_forage_kind(zone_slot, PATCH_BERRIES, DAY_ONE_TICK).ok,
		"berries are dormant in spring")
	assert_equal(_planner.forage_demand_blocker_of(zone_slot, PATCH_BERRIES).value,
		JobPlannerScript.BLOCKER_PATCH_DORMANT, "so the row records the dormancy")
	assert_true(_planner.reconcile_forage_kind(zone_slot, PATCH_BERRIES,
		SUMMER_MIDNIGHT_TICK).ok, "in summer the same kind publishes")
	assert_equal(_planner.forage_demand_blocker_of(zone_slot, PATCH_BERRIES).value,
		JobPlannerScript.BLOCKER_NONE, "and the stale reason is gone")


func test_abandoning_a_vanished_designation_clears_every_retained_reason() -> void:
	"""A reused HarvestZone row must not report the previous designation's reason."""
	var zone_slot: int = _enabled_designation()
	assert_equal(_planner.reconcile_forage_zone(zone_slot, DAY_ONE_TICK).value, 1,
		"one harvest publishes and the aggregate quota blocks the rest")
	assert_equal(_planner.forage_demand_blocker_of(zone_slot, PATCH_HERB).value,
		JobPlannerScript.BLOCKER_NOTHING_HARVESTABLE, "herb records why it got nothing")
	assert_true(_forage.destroy_zone(_forage.zone_ref_of(zone_slot)).ok,
		"the designation is destroyed")
	_planner.reconcile_forage_kind(zone_slot, PATCH_MUSHROOMS, DAY_ONE_TICK)
	assert_equal(_planner.forage_demand_blocker_of(zone_slot, PATCH_HERB).value,
		JobPlannerScript.BLOCKER_NONE, "abandonment clears the reasons of every kind")


func test_the_gate_question_answers_without_publishing_anything() -> void:
	"""`forage_gate_for()` is a pure question: panel and producer read one implementation."""
	var zone_slot: int = _enabled_designation()
	assert_equal(_planner.forage_gate_for(zone_slot, PATCH_BERRIES, SPRING).value,
		JobPlannerScript.BLOCKER_PATCH_DORMANT, "it answers the dormant kind")
	assert_equal(_planner.forage_gate_for(zone_slot, PATCH_MUSHROOMS, SPRING).value,
		JobPlannerScript.BLOCKER_NONE, "and reports the harvestable one clear")
	assert_equal(_jobs.job_count(), 0, "asking publishes nothing")
	assert_equal(_forage.claim_count(), 0, "and reserves nothing")
	assert_equal(_planner.forage_demand_blocker_of(zone_slot, PATCH_BERRIES).value,
		JobPlannerScript.BLOCKER_NONE, "nor does it write the row's retained reason")


func test_the_gate_question_reports_every_blocker_in_its_domain() -> void:
	"""Including the ones the producer's own order makes unreachable through a reconcile."""
	var basin: Vector2i = _forage_basin()
	var designation: Vector2i = _forage_designation(basin)
	var zone_slot: int = _zone_slot(designation)
	assert_equal(_planner.forage_gate_for(zone_slot, PATCH_MUSHROOMS, SPRING).value,
		JobPlannerScript.BLOCKER_DEMAND_NOT_ENABLED, "an unenabled designation blocks first")
	assert_true(_planner.enable_forage_demand(designation).ok, "the demand enables")
	assert_equal(_planner.forage_gate_for(zone_slot, PATCH_MUSHROOMS, 9).value,
		JobPlannerScript.BLOCKER_SOURCE_REFUSED, "an unreadable season is not a dormant patch")
	assert_true(_forage.destroy_zone(designation).ok, "the designation is destroyed")
	assert_equal(_planner.forage_gate_for(zone_slot, PATCH_MUSHROOMS, SPRING).value,
		JobPlannerScript.BLOCKER_ZONE_NOT_PRESENT, "and a vanished zone reports its own blocker")
	assert_false(_planner.forage_gate_for(128, PATCH_MUSHROOMS, SPRING).ok,
		"an unaddressable zone refuses rather than answering a blocker")
	assert_false(_planner.forage_gate_for(0, 5, SPRING).ok, "as does a sixth forage kind")


func test_the_quantity_question_refuses_rather_than_answering_zero() -> void:
	"""A blocked designation has no quantity, and 0 would read like an admissible one."""
	var zone_slot: int = _enabled_designation()
	assert_false(_planner.forage_quantity_for(zone_slot, PATCH_BERRIES, SPRING).ok,
		"a dormant kind refuses")
	assert_equal(String(_planner.forage_quantity_for(zone_slot, PATCH_BERRIES, SPRING).error),
		String(JobPlannerScript.REFUSE_PATCH_DORMANT), "naming the gate that stopped it")
	assert_true(_planner.forage_quantity_for(zone_slot, PATCH_MUSHROOMS, SPRING).ok,
		"a harvestable kind answers")


func test_a_free_demand_row_has_no_quantified_claim_to_report() -> void:
	"""Refuse rather than return 0, which would read as a claim of nothing."""
	var zone_slot: int = _enabled_designation()
	var free: IntMath.IntResult = _planner.quantified_claim_milli_of(zone_slot, PATCH_MUSHROOMS)
	assert_false(free.ok, "a row that published nothing has no quantity")
	assert_equal(String(free.error), String(JobPlannerScript.REFUSE_DEMAND_SETTLED),
		"and says so explicitly")
	assert_false(_planner.quantified_claim_milli_of(128, PATCH_MUSHROOMS).ok,
		"an unaddressable designation refuses")


func test_no_production_order_is_created_for_repeat_harvest_demand() -> void:
	"""The ruling's OrderMode paragraph: the ecology workflow is repeat demand, not an order."""
	var zone_slot: int = _enabled_designation()
	assert_true(_planner.reconcile_forage_kind(zone_slot, PATCH_MUSHROOMS, DAY_ONE_TICK).ok,
		"the harvest publishes")
	var job: int = _harvest_job_slot(zone_slot, PATCH_MUSHROOMS)
	assert_equal(_jobs.requester_of(job), EntityDirectory.NULL_REF,
		"no order requests it: no designation or basin id is written into a recipe")
	assert_equal(_jobs.source_of(job), _forage.zone_ref_of(zone_slot),
		"the designation is named as an EntityRef on the Job, which is where §4.2 puts it")


func test_the_work_total_is_computed_at_level_zero_where_the_level_changes_it() -> void:
	"""§5.5's formula distinguishes FORAGE level 0 from level 1 only at some kind/danger pairs.

	Herb at natural danger 1 is one of them: 8 WU/U unskilled, 7 WU/U at level 1. No worker is
	bound when the harvest is created, so the unskilled -- and largest -- total is the only one
	that can honestly be written.
	"""
	var basin: Vector2i = _forage_basin(1)
	assert_true(_forage.set_quota_milli(basin, MANUAL_QUOTA_MAX_MILLI, SPRING).ok,
		"the basin takes the manual maximum so the stock binds instead of the quota")
	var designation: Vector2i = _forage_designation(basin)
	assert_true(_planner.enable_forage_demand(designation).ok, "the demand enables")
	var zone_slot: int = _zone_slot(designation)
	assert_true(_planner.reconcile_forage_kind(zone_slot, PATCH_HERB, DAY_ONE_TICK).ok,
		"the herb harvest publishes")
	assert_equal(_forage.natural_danger_of(designation).value, 1,
		"the basin's natural danger is the term §5.5's formula uses")
	assert_equal(_jobs.remaining_mwu_of(_harvest_job_slot(zone_slot, PATCH_HERB)).value,
		HERB_WORK_PER_U_AT_DANGER_ONE * HERB_STOCK_ABOVE_FLOOR_MILLI,
		"8 WU/U at level 0 times the claimed milli-units, not 7 at level 1")


func test_two_designations_address_their_own_demand_rows() -> void:
	"""`z * 5 + kind` must not let one designation's last kind land on the next one's first.

	The rows are exercised across a boundary rather than only read back: designation A's ROOTS and
	designation B's BERRIES are adjacent zone rows, so a wrong stride makes them one row and the
	second harvest silently reports the first as already pending.
	"""
	var basin: Vector2i = _forage_basin()
	assert_true(_forage.set_quota_milli(basin, MANUAL_QUOTA_MAX_MILLI, SUMMER).ok,
		"the shared basin takes the manual maximum")
	var first: Vector2i = _forage_designation(basin)
	var second: Vector2i = _forage_designation(basin)
	assert_true(_planner.enable_forage_demand(first).ok, "the first demand enables")
	assert_true(_planner.enable_forage_demand(second).ok, "the second demand enables")
	var a: int = _zone_slot(first)
	var b: int = _zone_slot(second)
	assert_equal(b, a + 1, "the two designations occupy adjacent HarvestZone rows")
	assert_equal(_planner.demand_row(b, PATCH_BERRIES).value,
		_planner.demand_row(a, PATCH_ROOTS).value + 1, "and their rows are adjacent too")
	assert_true(_planner.reconcile_forage_kind(a, PATCH_ROOTS, SUMMER_MIDNIGHT_TICK).ok,
		"the first designation publishes its roots harvest")
	assert_true(_planner.reconcile_forage_kind(b, PATCH_BERRIES, SUMMER_MIDNIGHT_TICK).ok,
		"and the second publishes its berries harvest")
	assert_equal(_jobs.job_count(), 2, "two separate jobs")
	assert_true(_planner.forage_demand_job_of(a, PATCH_ROOTS)
		!= _planner.forage_demand_job_of(b, PATCH_BERRIES), "held by two separate rows")


# --- R06-JOB-006: the daily hive service producer -------------------------------------------------

func _hive(tile_x: int = 10, tile_z: int = 10, day: int = 1) -> int:
	"""Colonise one hive on a 1x1 apiary footprint and return its typed row.

	`Hive.building` is an EntityRef to a Building and NO BUILDING STORE EXISTS, so the owning
	directory row is allocated directly, exactly as `test_orchard_hive.gd` does.
	"""
	var building: Vector2i = _jobs.directory().create(EntityDirectory.KIND_BUILDING)
	var created: OrchardHiveScript.OpResult = _hives.create_hive(
		building, tile_x, tile_z, tile_x, tile_z, day)
	assert_true(created.ok, "the fixture hive colonises (error: %s)" % created.error)
	return created.value


func _hive_job_slot(hive_slot: int) -> int:
	"""The typed Job row of this hive's pending service, asserting one exists."""
	var ref: Vector2i = _planner.hive_service_job_of(hive_slot)
	assert_true(ref != EntityDirectory.NULL_REF, "the hive has a pending service job")
	return _jobs.directory().get_typed_row(ref)


func test_an_operational_hive_receives_one_twenty_wu_keep_service_for_its_day() -> void:
	"""R06-JOB-006: one 20-WU KEEP job, on a spring service day with no completed/pending service."""
	var hive: int = _hive()
	var result: JobPlannerScript.OpResult = _planner.reconcile_hive(hive, _day_start_tick(2))
	assert_true(result.ok, "the service is created (error: %s)" % result.error)
	assert_equal(_jobs.job_count(), 1, "exactly one job exists")
	assert_equal(_planner.hive_created_count(), 1, "the planner counts one creation")
	var job: int = _hive_job_slot(hive)
	assert_equal(_jobs.kind_of(job).value, KIND_KEEP, "§4.3's KEEP kind")
	assert_equal(_jobs.remaining_mwu_of(job).value, HIVE_SERVICE_MILLI_WU, "§5.6's 20 WU")
	assert_equal(_jobs.priority_of(job).value, ORDINARY_PRIORITY, "the ruling's priority 3")


func test_the_hive_service_job_names_its_hive_as_the_work_source() -> void:
	"""The hive is the SOURCE; nothing is delivered, so the destination stays null."""
	var hive: int = _hive()
	assert_true(_planner.reconcile_hive(hive, _day_start_tick(2)).ok, "the service is created")
	var job: int = _hive_job_slot(hive)
	assert_equal(_jobs.source_of(job), _hives.hive_ref_of(hive), "the source is the hive itself")
	assert_equal(_jobs.destination_of(job), EntityDirectory.NULL_REF, "and nothing is delivered")
	assert_equal(_jobs.inputs_gate_of(job).value, GATE_NOT_REQUIRED,
		"§5.6 prices the service as labour alone, so no input is declared")


func test_exactly_one_service_is_created_per_hive_per_eligible_day() -> void:
	"""The idempotence guard: N reconciliations and N dirty marks create ONE service."""
	var hive: int = _hive()
	var tick: int = _day_start_tick(2)
	assert_true(_planner.reconcile_hive(hive, tick).ok, "the first reconcile creates it")
	for _repeat: int in 25:
		_planner.mark_hive_dirty(hive)
		_planner.run_tick(tick)
		assert_equal(_planner.reconcile_hive(hive, tick).error,
			JobPlannerScript.REFUSE_SERVICE_PENDING, "every later attempt refuses as pending")
	assert_equal(_planner.hive_created_count(), 1, "one service, whatever the caller did")
	assert_equal(_jobs.job_count(), 1, "and one job row")
	assert_equal(_planner.pending_hive_service_count(), 1, "held by one pending row")


func test_a_completed_hive_service_blocks_a_second_one_the_same_day() -> void:
	"""The COMPLETED half of "without that day's completed or pending service"."""
	var hive: int = _hive()
	var tick: int = _day_start_tick(2)
	assert_true(_planner.reconcile_hive(hive, tick).ok, "day 2's service is created")
	assert_true(_jobs.set_state(_hive_job_slot(hive), STATE_COMPLETE).ok, "the work completes")
	assert_equal(_planner.reconcile_hive(hive, tick).error,
		JobPlannerScript.REFUSE_SERVICE_ALREADY_COMPLETE, "the same day refuses as complete")
	assert_equal(_planner.hive_completed_count(), 1, "the completion is recorded once")
	assert_equal(_hives.hive_serviced_day_of(hive).value, 2,
		"and the OWNING store's serviced_day names absolute day 2")
	assert_equal(_jobs.job_count(), 0, "the finished service's row is released")


func test_the_service_reopens_on_the_next_service_day() -> void:
	"""Once per day means once per day, not once ever."""
	var hive: int = _hive()
	assert_true(_planner.reconcile_hive(hive, _day_start_tick(2)).ok, "day 2 is serviced")
	assert_true(_jobs.set_state(_hive_job_slot(hive), STATE_COMPLETE).ok, "and completes")
	assert_true(_planner.run_day_boundary(_day_start_tick(3)).ok, "midnight runs")
	assert_true(_planner.reconcile_hive(hive, _day_start_tick(3)).ok, "day 3 is serviced")
	assert_equal(_planner.hive_created_count(), 2, "two days, two services")
	assert_equal(_planner.hive_service_day_of(hive).value, 3, "the second names day 3")


# --- R06-JOB-006: the season gate ------------------------------------------------------------------

func test_winter_creates_no_tending_labor_job() -> void:
	"""R06-JOB-006: "Winter shall create feed-delivery demand ... but no tending-labor job"."""
	var hive: int = _hive()
	var refused: JobPlannerScript.OpResult = _planner.reconcile_hive(hive, _day_start_tick(38))
	assert_false(refused.ok, "no service is created in winter")
	assert_equal(refused.error, JobPlannerScript.REFUSE_HIVE_WINTER, "and winter says so")
	assert_equal(_jobs.job_count(), 0, "no job row was allocated at all")
	assert_equal(_planner.hive_created_count(), 0, "and nothing was counted")
	assert_equal(_planner.hive_service_blocker_of(hive).value,
		JobPlannerScript.HIVE_BLOCKER_WINTER, "the row retains winter as its explicit reason")


func test_every_non_winter_day_of_the_year_creates_a_service_and_every_winter_day_none() -> void:
	"""Spring, summer and autumn are service days; winter is not. The WHOLE first year is walked.

	The season boundaries are §5.1's twelve-day seasons, computed here from the GDD rather than
	read out of the module: absolute days 1-12 spring, 13-24 summer, 25-36 autumn, 37-48 winter.
	"""
	var hive: int = _hive()
	var serviced: int = 0
	for day: int in range(2, 49):
		_hives.restore_hive_state(_hives.hive_ref_of(hive), 8000, 0, 0, 0, 1)
		_planner.retire_hive_service(hive)
		var created: bool = _planner.reconcile_hive(hive, _day_start_tick(day)).ok
		assert_equal(created, day < 37, "day %d creates work only outside winter" % day)
		if created:
			serviced += 1
			assert_true(_jobs.destroy_job(_hive_job_slot(hive)).ok, "release the job row")
			_planner.retire_hive_service(hive)
	assert_equal(serviced, 35, "days 2-36 are the thirty-five non-winter service days")


func test_winter_records_the_feed_delivery_demand_as_state_and_no_delivery_job() -> void:
	"""The feed half of the contract: demand as required, recorded, with NO job of any kind."""
	var hive: int = _hive()
	assert_false(_planner.reconcile_hive(hive, _day_start_tick(38)).ok, "winter creates no job")
	assert_equal(_planner.hive_feed_demand_milli_of(hive).value, WINTER_FEED_MILLI,
		"§5.6's honey 0.5 U/day is owed in full by a hive holding no feed")
	assert_equal(_jobs.job_count(), 0, "and NO delivery job exists: nothing owns hauling")
	assert_true(_hives.add_hive_feed(_hives.hive_ref_of(hive), WINTER_FEED_MILLI).ok, "feed it")
	assert_false(_planner.reconcile_hive(hive, _day_start_tick(38)).ok, "still no winter job")
	assert_equal(_planner.hive_feed_demand_milli_of(hive).value, 0,
		"a stocked hive owes nothing, so the demand falls to zero")


func test_a_spring_day_records_no_feed_demand() -> void:
	"""§5.6 requires feed only in winter, so a spring reconcile leaves the demand at zero."""
	var hive: int = _hive()
	assert_true(_planner.reconcile_hive(hive, _day_start_tick(2)).ok, "spring creates a service")
	assert_equal(_planner.hive_feed_demand_milli_of(hive).value, 0, "and owes no feed")


# --- R06-JOB-006: the operational condition ---------------------------------------------------------

func test_an_abandoned_hive_creates_no_service() -> void:
	"""§5.6: "a hive at 0 strength is abandoned", and the contract says non-abandoned."""
	var hive: int = _hive()
	assert_true(_hives.restore_hive_state(_hives.hive_ref_of(hive), 0, 0, 0, 0, 1).ok,
		"the hive is driven to zero strength")
	var refused: JobPlannerScript.OpResult = _planner.reconcile_hive(hive, _day_start_tick(2))
	assert_false(refused.ok, "an abandoned hive owes no service")
	assert_equal(refused.error, JobPlannerScript.REFUSE_HIVE_ABANDONED, "and says which rule")
	assert_equal(_jobs.job_count(), 0, "nothing was created")


func test_an_empty_hive_row_creates_no_service() -> void:
	"""A row holding no colonised hive is not operational; "operational" has no second flag."""
	var refused: JobPlannerScript.OpResult = _planner.reconcile_hive(7, _day_start_tick(2))
	assert_false(refused.ok, "an empty row creates nothing")
	assert_equal(refused.error, JobPlannerScript.REFUSE_HIVE_NOT_PRESENT, "and says so")


func test_a_hive_becoming_operational_mid_day_receives_no_retroactive_service() -> void:
	"""The lifecycle paragraph: no retroactive service for days before the hive existed.

	The hive is colonised on day 5 and first reconciled on day 9. It gets ONE service, for day 9;
	days 5, 6, 7 and 8 acquire nothing, now or ever.
	"""
	var hive: int = _hive(11, 11, 5)
	assert_true(_planner.reconcile_hive(hive, _day_start_tick(9)).ok, "day 9's service is created")
	assert_equal(_planner.hive_created_count(), 1, "ONE service, not five")
	assert_equal(_jobs.job_count(), 1, "and one job row")
	assert_equal(_planner.hive_service_day_of(hive).value, 9, "it belongs to today, day 9")
	assert_equal(_planner.hive_settled_unserved_count(), 0, "no earlier day was ever opened")


func test_the_colonisation_day_itself_is_already_recorded_as_serviced() -> void:
	""""A hive becoming operational during the day uses the SAME RULE" -- and the rule answers.

	`orchard_hive.create_hive()` records the colonisation day as `serviced_day`, so that day
	already HAS its completed service and the same "without that day's completed service" test
	refuses it. The next service day creates one.
	"""
	var hive: int = _hive(12, 12, 5)
	assert_equal(_hives.hive_serviced_day_of(hive).value, 5, "colonisation records day 5")
	assert_equal(_planner.reconcile_hive(hive, _day_start_tick(5)).error,
		JobPlannerScript.REFUSE_SERVICE_ALREADY_COMPLETE, "so day 5 needs no service")
	assert_true(_planner.reconcile_hive(hive, _day_start_tick(6)).ok, "and day 6 does")
	assert_equal(_planner.hive_created_count(), 1, "exactly one service across both days")


func test_midnight_settles_an_unserved_hive_service_and_cancels_its_job() -> void:
	"""Midnight settles the preceding day's outcome BEFORE opening the new day's demand."""
	var hive: int = _hive()
	assert_true(_planner.reconcile_hive(hive, _day_start_tick(2)).ok, "day 2's service is created")
	assert_true(_planner.run_day_boundary(_day_start_tick(3)).ok, "midnight runs")
	assert_equal(_planner.hive_settled_unserved_count(), 1, "day 2's service is settled unserved")
	assert_equal(_jobs.job_count(), 0, "its job was cancelled and its row released")
	assert_true(_planner.hive_service_row_is_clear(hive), "and the row keeps no residue")
	assert_true(_planner.is_hive_dirty(hive), "the new day's demand is marked for reconciliation")


func test_the_day_boundary_refuses_to_open_over_an_unsettled_hive_day() -> void:
	"""The ordering is a CHECKED precondition, not a comment about statement order."""
	var hive: int = _hive()
	assert_true(_planner.reconcile_hive(hive, _day_start_tick(2)).ok, "day 2's service exists")
	assert_false(_planner.preceding_hive_day_is_settled(3), "day 2's row is still outstanding")
	assert_true(_planner.run_day_boundary(_day_start_tick(3)).ok, "the boundary settles it first")
	assert_true(_planner.preceding_hive_day_is_settled(3), "and only then reports settled")


# --- R06-JOB-006: capacity, load and hygiene --------------------------------------------------------

func test_capacity_exhaustion_retains_hive_demand_and_reports_a_blocker() -> void:
	"""R06-JOB-008 over the third owner class: retain, report, retry -- never queue."""
	var hive: int = _hive()
	assert_equal(_fill_the_job_arena(), 8192, "the arena holds GDD §4.2's 8192 jobs")
	for _repeat: int in 50:
		assert_false(_planner.reconcile_hive(hive, _day_start_tick(2)).ok, "refused")
	assert_equal(_planner.unmet_hive_demand_count(), 1, "fifty refusals retain ONE row")
	assert_equal(_planner.hive_service_day_of(hive).value, 2, "which remembers its day")
	assert_true(_jobs.destroy_job(0).ok, "one job row is released")
	assert_equal(_planner.mark_capacity_released(), 1, "the retained demand is re-marked dirty")
	assert_equal(_planner.run_tick(_day_start_tick(2)).value, 1, "and the retry creates it")
	assert_equal(_planner.unmet_hive_demand_count(), 0, "no hive demand remains unmet")


func test_a_load_drops_a_hive_row_whose_job_no_longer_resolves() -> void:
	"""The repair the ruling permits over an index into live jobs; history is not reconstructed."""
	var hive: int = _hive()
	assert_true(_planner.reconcile_hive(hive, _day_start_tick(2)).ok, "the service is created")
	assert_true(_jobs.destroy_job(_hive_job_slot(hive)).ok, "its job vanishes beneath it")
	assert_equal(_planner.revalidate_after_load().value, 1, "the dangling row is dropped")
	assert_true(_planner.hive_service_row_is_clear(hive), "and leaves no residue")
	assert_true(_planner.reconcile_hive(hive, _day_start_tick(2)).ok, "the day can be served again")


func test_a_hive_service_records_both_halves_of_its_owners_entity_ref() -> void:
	"""A Hive row is reused after a destroy, so a row keeping only the index would be inherited."""
	var hive: int = _hive()
	assert_true(_planner.reconcile_hive(hive, _day_start_tick(2)).ok, "the service is created")
	assert_equal(_planner.hive_service_owner_of(hive), _hives.hive_ref_of(hive),
		"the row names the hive by slot AND generation")
	var first_ref: Vector2i = _hives.hive_ref_of(hive)
	var first_job: Vector2i = _planner.hive_service_job_of(hive)
	assert_true(_hives.destroy_hive(first_ref).ok, "the hive is destroyed")
	var replacement: int = _hive(13, 13, 1)
	assert_equal(replacement, hive, "the directory reuses the freed typed row")
	assert_true(_hives.hive_ref_of(hive) != first_ref, "under a NEW EntityRef")
	assert_true(_planner.reconcile_hive(hive, _day_start_tick(2)).ok,
		"the new hive opens its OWN service rather than inheriting the old row's pending one")
	assert_equal(_planner.hive_settled_unserved_count(), 1,
		"and the previous occupant's service was settled unserved, not inherited")
	assert_true(_planner.hive_service_job_of(hive) != first_job, "a different Job carries it")
	assert_equal(_planner.hive_service_owner_of(hive), _hives.hive_ref_of(hive),
		"and the row now names the new occupant")


func test_a_reused_hive_row_with_a_matching_generation_is_still_not_inherited() -> void:
	"""The generation lives on the DIRECTORY SLOT, so two occupants of one typed row can share it.

	Comparing only the generation half would let this second hive inherit the first one's pending
	service. Both halves are compared, so the stale record is settled unserved instead. This is
	the exact case the generation-only comparison passed, and it is why the comparison changed.
	"""
	var hive: int = _hive()
	var first_ref: Vector2i = _hives.hive_ref_of(hive)
	assert_true(_planner.reconcile_hive(hive, _day_start_tick(2)).ok, "day 2's service exists")
	assert_true(_hives.destroy_hive(first_ref).ok, "the hive is destroyed")
	var replacement: int = _hive(14, 14, 1)
	assert_equal(replacement, hive, "the same typed row is reused")
	assert_equal(_hives.hive_ref_of(hive).y, first_ref.y,
		"and its GENERATION happens to equal the previous occupant's, on a different slot")
	assert_true(_hives.hive_ref_of(hive).x != first_ref.x, "only the slot half distinguishes them")
	assert_true(_planner.reconcile_hive(hive, _day_start_tick(2)).ok,
		"so the new hive must get its own service, not the stale pending one")
	assert_equal(_planner.hive_settled_unserved_count(), 1, "the stale record was settled")


func test_retiring_a_hive_service_cancels_its_job_and_clears_its_feed_demand() -> void:
	"""The entry point a caller destroying a hive uses; completion history stays in its store."""
	var hive: int = _hive()
	assert_false(_planner.reconcile_hive(hive, _day_start_tick(38)).ok, "winter records demand")
	assert_equal(_planner.hive_feed_demand_milli_of(hive).value, WINTER_FEED_MILLI, "as required")
	assert_true(_planner.retire_hive_service(hive).ok, "the record retires")
	assert_equal(_planner.hive_feed_demand_milli_of(hive).value, 0, "the demand is withdrawn")
	assert_equal(_planner.retire_hive_service(hive).error, JobPlannerScript.REFUSE_NO_SERVICE,
		"and a second retirement has nothing to retire")


func test_record_hive_service_completed_is_the_seam_for_work_done_elsewhere() -> void:
	"""The completion is written to the store that OWNS `Hive.serviced_day`, and its refusal holds."""
	var hive: int = _hive()
	assert_true(_planner.reconcile_hive(hive, _day_start_tick(2)).ok, "a service is pending")
	assert_true(_planner.record_hive_service_completed(hive, 2).ok, "an outside tend is recorded")
	assert_equal(_hives.hive_serviced_day_of(hive).value, 2, "in the owning store's own column")
	assert_equal(_jobs.job_count(), 0, "and the pending job's row is released")
	assert_equal(_planner.reconcile_hive(hive, _day_start_tick(2)).error,
		JobPlannerScript.REFUSE_SERVICE_ALREADY_COMPLETE, "the day is closed")
	assert_true(_hives.restore_hive_state(_hives.hive_ref_of(hive), 0, 0, 0, 0, 2).ok, "abandon")
	assert_false(_planner.record_hive_service_completed(hive, 3).ok,
		"an abandoned hive refuses in its owning store and this module does not overrule it")


func test_a_worker_replacement_preserves_the_same_hive_job_and_its_work() -> void:
	"""The ruling: worker changes preserve the same Job/WIP."""
	var hive: int = _hive()
	assert_true(_planner.reconcile_hive(hive, _day_start_tick(2)).ok, "the service is created")
	var job: int = _hive_job_slot(hive)
	var worker: int = _worker()
	assert_true(_jobs.assign_worker(worker, job).ok, "a worker takes the service")
	assert_true(_jobs.release_worker(worker).ok, "and is replaced")
	assert_equal(_planner.reconcile_hive(hive, _day_start_tick(2)).error,
		JobPlannerScript.REFUSE_SERVICE_PENDING, "the same service is still pending")
	assert_equal(_hive_job_slot(hive), job, "the SAME job row")
	assert_equal(_jobs.remaining_mwu_of(job).value, HIVE_SERVICE_MILLI_WU, "with its work intact")


# --- R06-JOB-006: the dirty set, the sweep and the tick ---------------------------------------------

func test_repeated_dirty_marks_on_one_hive_add_one_entry() -> void:
	"""R06-JOB-008's idempotence at the marking step: the set is bounded by construction."""
	var hive: int = _hive()
	for _repeat: int in 40:
		assert_true(_planner.mark_hive_dirty(hive).ok, "the mark takes")
	assert_equal(_planner.hive_dirty_count(), 1, "forty events, one entry")
	assert_true(_planner.is_hive_dirty(hive), "and the membership bit is set")
	assert_false(_planner.mark_hive_dirty(JobPlannerScript.HIVE_OWNER_CAPACITY).ok,
		"a slot past the hive capacity refuses")


func test_run_tick_creates_the_hive_service_through_the_drain() -> void:
	"""The composed tick reconciles all three owner classes and sums what each created."""
	var hive: int = _hive()
	assert_true(_planner.mark_hive_dirty(hive).ok, "an event marks the hive")
	assert_equal(_planner.run_tick(_day_start_tick(2)).value, 1, "the tick creates one service")
	assert_equal(_planner.pending_hive_service_count(), 1, "held by one pending row")
	assert_false(_planner.is_hive_dirty(hive), "and the dirty entry was drained")


func test_the_idle_sweep_reaches_a_hive_within_one_stagger_period() -> void:
	"""ARCH-SYS-009's idle cadence over the Hive class: a 1/30 slice per tick."""
	var hive: int = _hive()
	var created: int = 0
	var first: int = _day_start_tick(2)
	for tick: int in range(first, first + JobPlannerScript.STAGGER_MODULUS):
		created += _planner.run_hive_sweep(tick).value
	assert_equal(created, 1, "one sweep period reaches the hive exactly once")
	assert_equal(_planner.pending_hive_service_count(), 1, "and creates its one service")


# --- R06-JOB-006: the operation domain and the gate composition -------------------------------------

func test_the_hive_operation_is_a_daily_service_and_rotation_is_not() -> void:
	"""The two answers R06-JOB-006 and R06-JOB-005 require of the same predicate.

	The hive service reopens every midnight, exactly as FARM tending does. R06-JOB-005's rotation
	advance is EVENT-DRIVEN ON CYCLE COMPLETION, like sowing, and must never be reopened or
	settled by midnight.
	"""
	assert_true(_planner.is_daily_service_operation(JobPlannerScript.OPERATION_HIVE_KEEP),
		"R06-JOB-006's hive service IS a daily service")
	assert_false(_planner.is_daily_service_operation(JobPlannerScript.OPERATION_FIELD_ROTATION),
		"R06-JOB-005's rotation advance is NOT a daily service")
	assert_true(_planner.is_daily_service_operation(TEND_OPERATION), "tending still is")
	assert_false(_planner.is_daily_service_operation(SOW_OPERATION), "sowing still is not")
	assert_false(_planner.is_operation(JobPlannerScript.OPERATION_FIELD_ROTATION),
		"and rotation addresses no row in this file's pending-service table")
	assert_false(_planner.is_operation(JobPlannerScript.OPERATION_HIVE_KEEP),
		"nor does the hive service, which has its own slice")


func test_no_operation_outside_the_domain_reports_as_a_daily_service() -> void:
	"""The predicate is a table over the domain; anything outside it answers false, not an error."""
	assert_false(_planner.is_daily_service_operation(-1), "a negative ordinal is not daily")
	assert_false(_planner.is_daily_service_operation(
		JobPlannerScript.OPERATION_DOMAIN_COUNT), "nor is one past the domain")


func test_the_hive_gate_composition_agrees_with_the_owning_stores_predicate() -> void:
	"""`is_service_due()` is `orchard_hive.gd`'s; this producer's gates must not drift from it.

	Every gate that refuses must correspond to a hive the OWNING store also says is not due, and
	a clean gate must correspond to one it says IS due. Four conditions are walked.
	"""
	var hive: int = _hive()
	assert_true(_hives.is_service_due(hive, 2), "a fresh hive is due on day 2")
	assert_equal(_planner.hive_service_gate_for(hive, 2).value,
		JobPlannerScript.HIVE_BLOCKER_NONE, "and the producer's gates agree")
	assert_false(_hives.is_service_due(hive, 38), "winter is never due")
	assert_equal(_planner.hive_service_gate_for(hive, 38).value,
		JobPlannerScript.HIVE_BLOCKER_WINTER, "and the producer names winter")
	assert_true(_hives.record_hive_service(_hives.hive_ref_of(hive), 2).ok, "serviced on day 2")
	assert_false(_hives.is_service_due(hive, 2), "so day 2 is no longer due")
	assert_equal(_planner.hive_service_gate_for(hive, 2).value,
		JobPlannerScript.HIVE_BLOCKER_ALREADY_SERVICED, "and the producer names the completion")


func test_the_hive_gate_question_creates_nothing() -> void:
	"""A pure question: it publishes no Job, marks nothing dirty and opens no service row."""
	var hive: int = _hive()
	for _repeat: int in 10:
		assert_equal(_planner.hive_service_gate_for(hive, 2).value,
			JobPlannerScript.HIVE_BLOCKER_NONE, "the gate answers clean")
	assert_equal(_jobs.job_count(), 0, "and created nothing")
	assert_equal(_planner.hive_created_count(), 0, "and counted nothing")
	assert_equal(_planner.hive_service_status_of(hive).value, JobPlannerScript.STATUS_FREE,
		"leaving the row free")


func test_every_hive_blocker_maps_to_exactly_one_refusal_code() -> void:
	"""The retained byte and the returned StringName read one table, so they cannot drift."""
	assert_equal(JobPlannerScript.HIVE_BLOCKER_COUNT, 5, "five hive blockers")
	for blocker: int in JobPlannerScript.HIVE_BLOCKER_COUNT:
		assert_true(_planner.hive_refusal_of_blocker(blocker) !=
			JobPlannerScript.REFUSE_INVALID_HIVE_BLOCKER, "blocker %d maps" % blocker)
	assert_equal(_planner.hive_refusal_of_blocker(JobPlannerScript.HIVE_BLOCKER_COUNT),
		JobPlannerScript.REFUSE_INVALID_HIVE_BLOCKER, "an out-of-range blocker refuses")
	assert_equal(_planner.hive_refusal_of_blocker(-1),
		JobPlannerScript.REFUSE_INVALID_HIVE_BLOCKER, "and so does a negative one")


func test_the_hive_into_readers_agree_with_their_allocating_forms() -> void:
	"""Decision 0015: the reconcile path's `_into` readers must answer what the allocating ones do."""
	var hive: int = _hive()
	assert_true(_planner.reconcile_hive(hive, _day_start_tick(2)).ok, "a service exists")
	var out: IntMath.IntResult = IntMath.IntResult.new()
	assert_true(_planner.hive_service_status_into(hive, out), "the status reads")
	assert_equal(out.value, _planner.hive_service_status_of(hive).value, "and agrees")
	assert_true(_planner.hive_service_day_into(hive, out), "the day reads")
	assert_equal(out.value, _planner.hive_service_day_of(hive).value, "and agrees")
	assert_true(_planner.hive_feed_demand_milli_into(hive, out), "the feed demand reads")
	assert_equal(out.value, _planner.hive_feed_demand_milli_of(hive).value, "and agrees")
	assert_true(_planner.hive_service_blocker_into(hive, out), "the blocker reads")
	assert_equal(out.value, _planner.hive_service_blocker_of(hive).value, "and agrees")
	assert_true(_planner.hive_service_gate_for_into(hive, 2, out), "the gate question reads")
	assert_equal(out.value, _planner.hive_service_gate_for(hive, 2).value, "and agrees")


func test_every_hive_reader_refuses_an_unaddressable_slot() -> void:
	"""No reader returns a sentinel for absence: each refuses with the same named code."""
	var past: int = JobPlannerScript.HIVE_OWNER_CAPACITY
	assert_false(_planner.hive_service_row(past).ok, "the row mapping refuses")
	assert_false(_planner.hive_service_status_of(past).ok, "the status refuses")
	assert_false(_planner.hive_service_day_of(past).ok, "the day refuses")
	assert_false(_planner.hive_feed_demand_milli_of(past).ok, "the feed demand refuses")
	assert_false(_planner.hive_service_blocker_of(past).ok, "the blocker refuses")
	assert_false(_planner.hive_service_gate_for(past, 2).ok, "the gate question refuses")
	assert_false(_planner.reconcile_hive(past, 0).ok, "and so does the producer")
	assert_equal(_planner.hive_service_job_of(past), EntityDirectory.NULL_REF,
		"the job reader answers the null reference rather than a plausible slot")
	assert_false(_planner.hive_service_row_is_clear(past), "and the hygiene predicate is false")


func test_a_free_hive_row_refuses_its_service_day_rather_than_answering_zero() -> void:
	"""Day 0 names no day; it is an absence, and an absence is refused, not returned."""
	var hive: int = _hive()
	assert_false(_planner.hive_service_day_of(hive).ok, "a free row has no service day")
	assert_equal(_planner.hive_service_day_of(hive).error,
		String(JobPlannerScript.REFUSE_NO_SERVICE), "and names the absence")


func test_the_hive_service_row_is_the_hives_own_typed_row() -> void:
	"""One operation per hive, so the row index IS the typed row; 1024 of them."""
	assert_equal(JobPlannerScript.HIVE_OWNER_CAPACITY, 1024, "GDD §4.2's 1024 Hive rows")
	assert_equal(_planner.hive_service_row(0).value, 0, "the first hive's row")
	assert_equal(_planner.hive_service_row(1023).value, 1023, "and the last one's")
	assert_false(_planner.hive_service_row(1024).ok, "a row past the arena refuses")


func test_the_planner_services_the_hives_of_the_store_it_was_given() -> void:
	"""The producer must not hold a private hive set; the collaborator is published and shared."""
	assert_true(_planner.hives() == _hives, "the planner services the store it was constructed with")
	assert_true(_planner.hives().directory() == _jobs.directory(),
		"and that store allocates from the one shared entity directory")


# --- the owner reference is compared in FULL, not by its generation alone (decision 0051) ---------

func test_a_reused_plot_row_does_not_inherit_the_previous_plots_tending_service() -> void:
	"""BOTH HALVES of the owner EntityRef are compared, and the SLOT half is what decides here.

	§4.1's generation lives on the DIRECTORY SLOT, not on the typed row. A destroyed plot's typed
	row is reused while a FRESH directory slot is allocated for it, and a fresh slot's first
	generation is 1 -- the same number the previous occupant's slot carried. Comparing only the
	generation therefore reported "the same owner" for a completely different plot, which would
	hand the new plot the old one's pending service and its Job.
	"""
	var plot: int = _growing_plot(700)
	var first_ref: Vector2i = _farming.ref_of(plot)
	assert_true(_planner.reconcile_plot(plot, DAY_ONE_TICK).ok, "the first plot is serviced")
	assert_true(_farming.destroy(first_ref).ok, "the plot is destroyed")
	assert_true(_jobs.directory().create(EntityDirectory.KIND_BUILDING) != EntityDirectory.NULL_REF,
		"an unrelated allocation takes the freed directory slot, as any other store's would")
	var replacement: int = _growing_plot(701)
	assert_equal(replacement, plot, "the same typed row is reused")
	assert_equal(_farming.ref_of(plot).y, first_ref.y,
		"and its GENERATION equals the previous occupant's, on a different slot")
	assert_true(_farming.ref_of(plot).x != first_ref.x, "only the slot half distinguishes them")
	assert_true(_planner.reconcile_plot(plot, DAY_ONE_TICK).ok,
		"so the new plot gets its OWN service, not the stale pending one")
	assert_equal(_planner.settled_unserved_count(), 1, "and the stale record was settled unserved")
	assert_equal(_planner.service_owner_of(plot, TEND_OPERATION), _farming.ref_of(plot),
		"the row now names the new occupant in full")


func test_a_reused_plot_row_does_not_inherit_the_previous_plots_sowing_request() -> void:
	"""The same full-reference comparison on R06-JOB-004's sowing row.

	A redrawn plot must start with NO confirmed crop. A generation-only comparison would let the
	new plot inherit the previous one's confirmed cycle and sow a crop nobody chose for it.
	"""
	var plot: int = _empty_plot(702)
	var first_ref: Vector2i = _farming.ref_of(plot)
	assert_true(_planner.confirm_first_planting(plot, GRAIN).ok, "the first plot is confirmed")
	assert_true(_farming.destroy(first_ref).ok, "the plot is destroyed")
	assert_true(_jobs.directory().create(EntityDirectory.KIND_BUILDING) != EntityDirectory.NULL_REF,
		"an unrelated allocation takes the freed directory slot, as any other store's would")
	var replacement: int = _empty_plot(703)
	assert_equal(replacement, plot, "the same typed row is reused")
	assert_equal(_farming.ref_of(plot).y, first_ref.y, "with the same generation number")
	assert_true(_farming.ref_of(plot).x != first_ref.x, "on a different directory slot")
	assert_equal(_planner.reconcile_sowing(plot, DAY_ONE_TICK).error,
		JobPlannerScript.REFUSE_NO_SOWING_REQUEST,
		"the new plot carries no confirmed crop and must be confirmed again")
	assert_equal(_planner.sowing_cancelled_count(), 1, "the stale request was abandoned")


# --- gaps a surviving mutant exposed (decision 0051) ----------------------------------------------

func test_the_day_boundary_does_not_retire_a_service_belonging_to_the_day_it_opens() -> void:
	"""Settlement retires rows STRICTLY BEFORE today, so today's live service survives a boundary.

	FOUND BY MUTATION: relaxing `_service_day >= day` to `> day` in the hive settlement sweep
	passed the whole suite. It would cancel a service already created for the day being opened --
	a boundary called twice, or called after the day's first reconcile, would destroy the Job and
	its work in progress, which the ruling's "worker changes preserve the same Job/WIP" forbids.
	"""
	var hive: int = _hive()
	assert_true(_planner.reconcile_hive(hive, _day_start_tick(2)).ok, "day 2's service is created")
	var job: Vector2i = _planner.hive_service_job_of(hive)
	assert_true(_planner.run_day_boundary(_day_start_tick(2)).ok, "the boundary for day 2 runs")
	assert_equal(_planner.hive_settled_unserved_count(), 0, "today's own service is NOT settled")
	assert_equal(_planner.pending_hive_service_count(), 1, "it is still pending")
	assert_equal(_planner.hive_service_job_of(hive), job, "on the SAME job row")
	assert_equal(_jobs.remaining_mwu_of(_hive_job_slot(hive)).value, HIVE_SERVICE_MILLI_WU,
		"with its work in progress intact")
	assert_equal(_planner.hive_created_count(), 1, "and no second service was created")


func test_a_missed_midnight_does_not_let_yesterdays_hive_row_absorb_todays_demand() -> void:
	"""The service day is the THIRD identity term, and it is compared on every reconcile.

	FOUND BY MUTATION: dropping the `_hive_service_day != day` term from the hive settle path
	passed the whole suite. Without it, a day-2 row left standing because no boundary ran would
	answer SERVICE_ALREADY_PENDING on day 3 and day 3 would silently go unserviced -- for as many
	days as the boundary stayed missed.
	"""
	var hive: int = _hive()
	assert_true(_planner.reconcile_hive(hive, _day_start_tick(2)).ok, "day 2's service is created")
	assert_equal(_planner.hive_service_day_of(hive).value, 2, "and belongs to day 2")
	assert_true(_planner.reconcile_hive(hive, _day_start_tick(3)).ok,
		"day 3 gets its OWN service even though no midnight boundary ran")
	assert_equal(_planner.hive_service_day_of(hive).value, 3, "the row now names day 3")
	assert_equal(_planner.hive_settled_unserved_count(), 1, "day 2's row was settled unserved")
	assert_equal(_planner.hive_created_count(), 2, "two days, two services")
	assert_equal(_jobs.job_count(), 1, "and day 2's job was cancelled, not left orphaned")


func test_a_hive_row_holding_a_service_is_not_reported_as_clear() -> void:
	"""The hygiene predicate must be able to say NO; a `return true` would be worse than none.

	FOUND BY MUTATION: short-circuiting `hive_service_row_is_clear()` to true passed the whole
	suite, because every test that called it called it on a row that really was clear. It is
	checked here in all four states a row can hold.
	"""
	var hive: int = _hive()
	assert_true(_planner.hive_service_row_is_clear(hive), "a fresh row is clear")
	assert_true(_planner.reconcile_hive(hive, _day_start_tick(2)).ok, "a service is created")
	assert_false(_planner.hive_service_row_is_clear(hive), "a PENDING row is not clear")
	assert_true(_jobs.set_state(_hive_job_slot(hive), STATE_CANCELLED).ok, "the job is cancelled")
	assert_true(_planner.reconcile_hive(hive, _day_start_tick(2)).ok,
		"the cancelled row settles and the still-eligible day gets a fresh service")
	assert_equal(_planner.hive_cancelled_count(), 1, "the cancellation was recorded")
	assert_false(_planner.hive_service_row_is_clear(hive), "the replacement row is not clear")
	assert_true(_planner.retire_hive_service(hive).ok, "the record is retired")
	assert_true(_planner.hive_service_row_is_clear(hive), "and the row is clear again")
	_fill_the_job_arena()
	assert_false(_planner.reconcile_hive(hive, _day_start_tick(3)).ok, "capacity refuses")
	assert_equal(_planner.unmet_hive_demand_count(), 1, "leaving retained demand")
	assert_false(_planner.hive_service_row_is_clear(hive), "an UNMET row is not clear either")


func test_the_hive_sweep_reaches_every_slot_of_its_stagger_exactly_once_per_period() -> void:
	"""ARCH-SYS-009's 1/30 slice must PARTITION the rows, not sample a subset of them.

	FOUND BY MUTATION: widening the sweep's stride from STAGGER_MODULUS to three times it passed
	the whole suite, because every sweep test used a single hive on row 0 -- which any stride
	still reaches. Rows beyond the first stagger period are what distinguish the strides, so this
	walks thirty-six of them and requires each to be serviced exactly once in one period.
	"""
	var hives: int = JobPlannerScript.STAGGER_MODULUS + 6
	for index: int in hives:
		assert_equal(_hive(20 + index % 50, 40 + index / 50, 1), index, "hive %d lands in order" % index)
	var created: int = 0
	var first: int = _day_start_tick(2)
	for tick: int in range(first, first + JobPlannerScript.STAGGER_MODULUS):
		created += _planner.run_hive_sweep(tick).value
	assert_equal(created, hives, "every hive is reached within one thirty-tick period")
	assert_equal(_planner.pending_hive_service_count(), hives, "each holding one service")
	for index: int in hives:
		assert_true(_planner.hive_service_job_of(index) != EntityDirectory.NULL_REF,
			"hive %d, beyond the first stagger period, was serviced too" % index)
