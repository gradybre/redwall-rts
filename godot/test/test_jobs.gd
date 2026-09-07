extends "res://test/framework/test_case.gd"
## Coverage for the Job store, the JobAgent store, and GDD §5.3 / ARCH-JOB-002 job selection.
##
## The selection tests are built so that each one can only pass for the right reason. Every sort
## test puts TWO candidates in the store that differ in exactly ONE dimension of the key, and
## arranges the job IDs so that dropping the dimension under test flips the winner to the other
## job -- a "some job was selected" assertion would pass against a broken comparator, so none is
## written. The bucket and tie-break-order tests do the same for the ordering BETWEEN dimensions.
##
## The cursor tests assert the exact job slot each pass returns across three passes over 64
## candidates, so a cursor that silently restarted at index 0 returns the wrong slot on pass 2.
## The stagger tests count how many residents are due on each of thirty consecutive ticks.

const IntMath := preload("res://scripts/core/int_math.gd")
const CatalogScript := preload("res://scripts/core/catalog.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const NeedsScript := preload("res://scripts/core/needs.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")
const PrioritiesScript := preload("res://scripts/core/priorities.gd")
const ScheduleScript := preload("res://scripts/core/schedule.gd")
const JobsScript := preload("res://scripts/core/jobs.gd")

## GDD §5.3 default schedule: 07:00-12:00 WORK, 06:00-07:00 ANYTHING, 18:00-20:00 SOCIAL,
## 22:00-06:00 SLEEP. One hour is named per Activity so a test says which rule it exercises.
const HOUR_WORK: int = 8
const HOUR_ANYTHING: int = 6
const HOUR_SOCIAL: int = 19
const HOUR_SLEEP: int = 23

## A creation tick shared by candidates that must tie on the fifth sort term.
const SHARED_CREATED_TICK: int = 100

var _residents: ResidentsScript = null
var _needs: NeedsScript = null
var _priorities: PrioritiesScript = null
var _schedule: ScheduleScript = null
var _jobs: JobsScript = null


func before_each() -> void:
	"""Build one consistent set of stores: the schedule and jobs read the residents' needs rows."""
	_residents = ResidentsScript.new()
	_needs = _residents.needs()
	_priorities = PrioritiesScript.new()
	_schedule = ScheduleScript.new(_needs)
	_jobs = JobsScript.new(_residents, _priorities, _schedule)


func after_each() -> void:
	"""Drop every store so no test inherits another's rows."""
	_jobs = null
	_schedule = null
	_priorities = null
	_needs = null
	_residents = null


# --- fixtures ------------------------------------------------------------------------------------

func _spawn_resident() -> int:
	"""Spawn one mouse with its priorities and schedule rows, and return its resident slot."""
	var spawned: ResidentsScript.OpResult = _residents.spawn(&"mouse")
	assert_true(spawned.ok, "resident spawns (error: %s)" % spawned.error)
	var slot: int = spawned.value
	assert_true(_priorities.spawn(slot).ok, "priorities row spawns")
	var template: IntMath.IntResult = _schedule.default_template_id()
	assert_true(template.ok, "the default schedule template compiles")
	assert_true(_schedule.spawn(slot, template.value).ok, "schedule row spawns")
	return slot


func _spawn_worker(hour: int = HOUR_WORK) -> int:
	"""Spawn a resident, resolve their activity for `hour`, and give them a JobAgent row."""
	var slot: int = _spawn_resident()
	var resolved: IntMath.IntResult = _schedule.resolve(slot, hour, false)
	assert_true(resolved.ok, "activity resolves (error: %s)" % resolved.error)
	assert_true(_jobs.spawn_agent(slot).ok, "job agent spawns")
	return slot


func _make_job(kind: int, priority: int = 0, required_skill: int = 0,
		created_tick: int = SHARED_CREATED_TICK) -> int:
	"""Create one job and return its slot, failing the test rather than returning a bad slot."""
	var created: JobsScript.OpResult = _jobs.create_job(kind, priority, required_skill, 0,
		created_tick)
	assert_true(created.ok, "job creates (error: %s)" % created.error)
	return created.value


func _due_tick(resident_slot: int, window: int = 0) -> int:
	"""The tick in the `window`-th 30-tick period on which this resident reevaluates."""
	var offset: IntMath.IntResult = _jobs.stagger_offset_of(resident_slot)
	assert_true(offset.ok, "the stagger offset reads (error: %s)" % offset.error)
	return offset.value + window * JobsScript.REEVALUATION_INTERVAL_TICKS


func _select(resident_slot: int, window: int = 0) -> JobsScript.OpResult:
	"""Run one selection pass on the resident's own staggered tick in the given window."""
	return _jobs.evaluate(resident_slot, _due_tick(resident_slot, window))


func _make_blocked_jobs(count: int, urgency: int) -> Array[int]:
	"""Create `count` KEEP jobs in one urgency bucket, every one ineligible at step 6.

	Blocked rather than absent so each one still costs a candidate from the pass's budget: these
	fixtures exist to make a pass run out of budget without ever finding a winner.
	"""
	var slots: Array[int] = []
	for index: int in count:
		var slot: int = _make_job(JobsScript.JOB_KIND_KEEP)
		assert_true(_jobs.set_urgency(slot, urgency).ok, "the job declares bucket %d" % urgency)
		assert_true(_jobs.set_inputs_gate(slot, JobsScript.GATE_BLOCKED).ok, "its inputs are short")
		slots.append(slot)
	return slots


func _make_open_jobs(count: int, urgency: int) -> Array[int]:
	"""Create `count` eligible KEEP jobs in one urgency bucket, oldest first."""
	var slots: Array[int] = []
	for index: int in count:
		var slot: int = _make_job(JobsScript.JOB_KIND_KEEP)
		assert_true(_jobs.set_urgency(slot, urgency).ok, "the job declares bucket %d" % urgency)
		slots.append(slot)
	return slots


func _grant_skill(resident_slot: int, kind: int, level: int) -> void:
	"""Give a resident exactly `level` in one skill using §5.3's 5000*L*L cumulative curve."""
	var xp: int = ResidentsScript.SKILL_XP_PER_LEVEL_SQUARE * level * level
	assert_true(_residents.set_skill_xp(resident_slot, kind, xp).ok, "skill xp writes")
	var read: IntMath.IntResult = _residents.skill_level_of(resident_slot, kind)
	assert_equal(read.value, level, "the resident reaches skill level %d" % level)


# --- GDD §4.3 enum values come from catalog.gd (decision 0018) -----------------------------------

func test_job_kind_and_job_state_numbers_match_the_protected_catalog_table() -> void:
	"""§4.3 numbers both enums explicitly; this module must mirror neither of them locally."""
	assert_equal(JobsScript.JOB_KIND_HAUL, CatalogScript.JOB_KIND["HAUL"], "HAUL comes from catalog")
	assert_equal(JobsScript.JOB_KIND_HEAL, 11, "HEAL=11")
	assert_equal(JobsScript.JOB_KIND_RESERVED_INDEX, 3, "the reserved job kind index is 3")
	assert_equal(JobsScript.JOB_STATE_QUEUED, 0, "JobState QUEUED=0")
	assert_equal(JobsScript.JOB_STATE_HAUL_OUTPUT, 4, "JobState HAUL_OUTPUT=4")
	assert_equal(JobsScript.JOB_STATE_CANCELLED, 7, "JobState CANCELLED=7")
	assert_equal(JobsScript.JOB_STATE_COUNT, CatalogScript.JOB_STATE.size(), "eight JobStates")


func test_the_published_cadence_budget_and_bucket_constants_are_the_specified_numbers() -> void:
	"""§5.3 fixes 30 ticks, a mod-30 stagger, 32 candidates, and five ascending buckets."""
	assert_equal(JobsScript.REEVALUATION_INTERVAL_TICKS, 30, "reevaluate every 30 ticks")
	assert_equal(JobsScript.STAGGER_MODULUS, 30, "staggered by resident ID mod 30")
	assert_equal(JobsScript.CANDIDATE_BUDGET_PER_PASS, 32, "at most 32 candidates per pass")
	assert_equal(JobsScript.URGENCY_RESCUE, 0, "bucket 0 is rescue/feeding the incapacitated")
	assert_equal(JobsScript.URGENCY_PERSONAL_CRITICAL, 1, "bucket 1 is personal critical needs")
	assert_equal(JobsScript.URGENCY_FOOD_FUEL, 2, "bucket 2 is food/fuel under a 2-day reserve")
	assert_equal(JobsScript.URGENCY_ORDINARY, 3, "bucket 3 is ordinary production/construction")
	assert_equal(JobsScript.URGENCY_COSMETIC, 4, "bucket 4 is cosmetic upkeep")


# --- Job store shape and lifecycle ----------------------------------------------------------------

func test_jobs_allocate_through_the_directorys_reserved_job_arena() -> void:
	"""GDD §4.2 caps active/queued jobs at 8192, the capacity entity_directory.gd already holds."""
	var directory: EntityDirectory = _jobs.directory()
	assert_equal(JobsScript.JOB_CAPACITY, 8192, "the Job store holds 8192 rows")
	assert_equal(directory.capacity_of_kind(EntityDirectory.KIND_JOB), JobsScript.JOB_CAPACITY,
		"the store's capacity is the directory's KIND_JOB capacity, not an independent number")
	var before: int = directory.live_count(EntityDirectory.KIND_JOB)
	var created: JobsScript.OpResult = _jobs.create_job(JobsScript.JOB_KIND_HAUL, 0, 0, 0, 0)
	assert_true(created.ok, "the job creates")
	assert_equal(directory.live_count(EntityDirectory.KIND_JOB), before + 1,
		"the directory records the new KIND_JOB row")
	assert_equal(directory.get_kind(created.ref), EntityDirectory.KIND_JOB,
		"the reference is a job reference")


func test_a_new_job_carries_the_registry_defaults() -> void:
	"""§4.2: state QUEUED, no worker, no requester/destination/source, ordinary urgency."""
	var job: int = _make_job(JobsScript.JOB_KIND_BUILD, 7, 2, 44)
	assert_equal(_jobs.state_of(job).value, JobsScript.JOB_STATE_QUEUED, "state starts QUEUED")
	assert_equal(_jobs.kind_of(job).value, JobsScript.JOB_KIND_BUILD, "kind is stored")
	assert_equal(_jobs.priority_of(job).value, 7, "Job.priority is stored")
	assert_equal(_jobs.required_skill_of(job).value, 2, "Job.required_skill is stored")
	assert_equal(_jobs.created_tick_of(job).value, 44, "Job.created_tick is stored")
	assert_equal(_jobs.remaining_mwu_of(job).value, 0, "remaining_mwu starts at 0")
	assert_equal(_jobs.worker_of(job), EntityDirectory.NULL_REF, "worker starts null (-1,0)")
	assert_equal(_jobs.destination_of(job), EntityDirectory.NULL_REF, "destination starts null")
	assert_equal(_jobs.source_of(job), EntityDirectory.NULL_REF, "source starts null")
	assert_equal(_jobs.requester_of(job), EntityDirectory.NULL_REF, "requester starts null")
	assert_equal(_jobs.urgency_of(job).value, JobsScript.URGENCY_ORDINARY, "urgency starts 3")


func test_create_refuses_the_reserved_job_kind_and_every_out_of_domain_argument() -> void:
	"""SET-AMEND-001 prohibits assignment to RESERVED_3; the rest refuse rather than clamp."""
	var reserved: JobsScript.OpResult = _jobs.create_job(JobsScript.JOB_KIND_RESERVED_INDEX,
		0, 0, 0, 0)
	assert_false(reserved.ok, "a RESERVED_3 job is refused")
	assert_equal(reserved.error, JobsScript.REFUSE_RESERVED_JOB_KIND, "with the reserved code")
	assert_equal(reserved.value, 0, "a refusal carries no plausible-looking job slot")
	assert_equal(_jobs.create_job(12, 0, 0, 0, 0).error, JobsScript.REFUSE_INVALID_JOB_KIND,
		"kind 12 is outside the twelve")
	assert_equal(_jobs.create_job(0, 0, 11, 0, 0).error, JobsScript.REFUSE_INVALID_REQUIRED_SKILL,
		"a required level above 10 is refused")
	assert_equal(_jobs.create_job(0, 0, -1, 0, 0).error, JobsScript.REFUSE_INVALID_REQUIRED_SKILL,
		"a negative required level is refused")
	assert_equal(_jobs.create_job(0, 0, 0, -1, 0).error, JobsScript.REFUSE_INVALID_MWU,
		"negative remaining work is refused")
	assert_equal(_jobs.create_job(0, 0, 0, 0, -1).error, JobsScript.REFUSE_INVALID_TICK,
		"a negative creation tick is refused")
	assert_equal(_jobs.job_count(), 0, "no refused create allocated a row")


func test_destroy_clears_the_row_and_returns_the_directory_slot() -> void:
	"""A released row must hold no residue, so two identical worlds serialize identically."""
	var job: int = _make_job(JobsScript.JOB_KIND_COOK, 3, 1, 900)
	assert_true(_jobs.set_urgency(job, JobsScript.URGENCY_COSMETIC).ok, "urgency writes")
	assert_true(_jobs.set_dangerous(job, true).ok, "danger writes")
	var before: int = _jobs.directory().live_count(EntityDirectory.KIND_JOB)
	assert_true(_jobs.destroy_job(job).ok, "the job destroys")
	assert_equal(_jobs.directory().live_count(EntityDirectory.KIND_JOB), before - 1,
		"the directory row is released")
	assert_false(_jobs.is_job_present(job), "the row is no longer present")
	assert_true(_jobs.inactive_job_row_is_clear(job), "the released row holds no residue")
	assert_equal(_jobs.job_count(), 0, "the live index shrinks")
	assert_equal(_jobs.kind_of(job).error, String(JobsScript.REFUSE_JOB_NOT_PRESENT),
		"reading a released row refuses")


func test_the_store_fills_and_then_refuses_at_the_8192_row_capacity() -> void:
	"""GDD §4.2's "at most 8192 active/queued jobs" is a hard limit with an explicit refusal."""
	for index: int in JobsScript.JOB_CAPACITY:
		var created: JobsScript.OpResult = _jobs.create_job(JobsScript.JOB_KIND_HAUL, 0, 0, 0, 0)
		if not created.ok:
			fail("job %d of 8192 was refused with %s" % [index, created.error])
			return
	assert_equal(_jobs.job_count(), JobsScript.JOB_CAPACITY, "all 8192 rows are live")
	var overflow: JobsScript.OpResult = _jobs.create_job(JobsScript.JOB_KIND_HAUL, 0, 0, 0, 0)
	assert_false(overflow.ok, "the 8193rd job is refused")
	assert_equal(overflow.error, &"CAPACITY_JOB", "with the directory's own ARCH-ID-004 code")


func test_state_and_gate_writes_refuse_values_outside_their_enums() -> void:
	"""JobState is 0-7 and every eligibility gate is 0-3; neither clamps a bad value."""
	var job: int = _make_job(JobsScript.JOB_KIND_HAUL)
	assert_true(_jobs.set_state(job, JobsScript.JOB_STATE_BLOCKED).ok, "BLOCKED is a real state")
	assert_equal(_jobs.state_of(job).value, JobsScript.JOB_STATE_BLOCKED, "the state is stored")
	assert_equal(_jobs.set_state(job, 8).error, JobsScript.REFUSE_INVALID_JOB_STATE,
		"state 8 is outside the eight values")
	assert_equal(_jobs.set_state(job, -1).error, JobsScript.REFUSE_INVALID_JOB_STATE,
		"a negative state is refused")
	assert_true(_jobs.set_station_gate(job, JobsScript.GATE_UNAVAILABLE).ok,
		"UNAVAILABLE is a real gate value: a subsystem that cannot answer must be able to say so")
	assert_equal(_jobs.set_station_gate(job, JobsScript.GATE_COUNT).error,
		JobsScript.REFUSE_INVALID_GATE,
		"gate 4 is outside NOT_REQUIRED/SATISFIED/BLOCKED/UNAVAILABLE")
	assert_equal(_jobs.set_urgency(job, JobsScript.URGENCY_COUNT).error,
		JobsScript.REFUSE_INVALID_URGENCY, "there is no sixth urgency bucket")
	assert_equal(_jobs.set_remaining_mwu(job, -1).error, JobsScript.REFUSE_INVALID_MWU,
		"negative remaining work is refused rather than clamped to zero")


func test_a_job_reference_column_accepts_only_null_or_a_live_reference() -> void:
	"""§4.2 relations are explicit references; a stale one must not be written into a column."""
	var job: int = _make_job(JobsScript.JOB_KIND_HAUL)
	var resident: int = _spawn_resident()
	var resident_ref: Vector2i = _residents.ref_of(resident)
	assert_true(_jobs.set_destination(job, resident_ref).ok, "a live reference is accepted")
	assert_equal(_jobs.destination_of(job), resident_ref, "and stored verbatim")
	assert_true(_jobs.set_destination(job, EntityDirectory.NULL_REF).ok, "null is accepted")
	assert_equal(_jobs.destination_of(job), EntityDirectory.NULL_REF, "and clears the column")
	var stale: Vector2i = Vector2i(resident_ref.x, resident_ref.y + 7)
	var refused: JobsScript.OpResult = _jobs.set_source(job, stale)
	assert_false(refused.ok, "a stale generation is refused")
	assert_equal(refused.error, JobsScript.REFUSE_INVALID_REFERENCE, "with the reference code")


# --- JobAgent store ------------------------------------------------------------------------------

func test_job_agent_is_one_row_per_resident_indexed_by_the_resident_slot() -> void:
	"""§4.2: "At most 1 active job/resident"; §2.2 sizes JobAgent at the 512 resident rows."""
	assert_equal(JobsScript.AGENT_CAPACITY, NeedsScript.RESIDENT_CAPACITY,
		"the agent store is one row per resident slot")
	var first: int = _spawn_resident()
	var second: int = _spawn_resident()
	assert_true(_jobs.spawn_agent(first).ok, "the first agent spawns")
	assert_true(_jobs.is_agent_present(first), "and is present at that resident's own slot")
	assert_false(_jobs.is_agent_present(second), "the second resident has no agent yet")
	assert_equal(_jobs.agent_count(), 1, "one agent row is live")
	assert_equal(_jobs.spawn_agent(first).error, JobsScript.REFUSE_AGENT_ALREADY_PRESENT,
		"a second agent for the same resident is refused")
	assert_equal(_jobs.spawn_agent(500).error, JobsScript.REFUSE_RESIDENT_NOT_PRESENT,
		"an agent for an empty resident slot is refused")


func test_an_idle_agent_refuses_a_phase_rather_than_returning_a_plausible_queued() -> void:
	"""§4.3 numbers no idle JobState, so phase_of must refuse, not hand back a fake QUEUED."""
	var worker: int = _spawn_worker()
	assert_true(_jobs.is_agent_idle(worker), "a fresh agent is idle")
	var phase: IntMath.IntResult = _jobs.phase_of(worker)
	assert_false(phase.ok, "an idle agent has no phase")
	assert_equal(phase.error, String(JobsScript.REFUSE_AGENT_IDLE), "with the idle code")
	assert_equal(phase.value, 0, "and the refusal carries no value")
	assert_equal(_jobs.job_of(worker), EntityDirectory.NULL_REF, "its job reference is null")


func test_the_unimplemented_agent_columns_are_allocated_zero_and_never_written() -> void:
	"""No pathfinder, no lease bookkeeping and no ManualTask: reserved allocation, GDD §4.2 style."""
	var worker: int = _spawn_worker()
	var job: int = _make_job(JobsScript.JOB_KIND_HAUL)
	assert_true(_jobs.assign_worker(worker, job).ok, "a worker binds")
	assert_equal(_jobs.path_id_of(worker).value, 0, "path_id stays 0: no pathfinder exists")
	assert_equal(_jobs.path_cursor_of(worker).value, 0, "path_cursor stays 0")
	assert_equal(_jobs.lease_expiry_of(worker).value, 0, "lease_expiry stays 0: REQ-SET-032 defers")
	assert_equal(_jobs.blocked_tick_of(worker).value, 0, "blocked_tick stays 0: REQ-SET-033 defers")
	assert_equal(_jobs.manual_until_of(worker).value, 0, "manual_until stays 0: U6 blocks ManualTask")
	assert_equal(_jobs.target_of(worker), EntityDirectory.NULL_REF, "target stays null")


# --- worker binding and decision 0017 -------------------------------------------------------------

func test_assigning_a_worker_binds_both_sides_and_moves_the_job_to_reserved() -> void:
	"""One worker, one job, one phase: the two stores must never disagree about an assignment."""
	var worker: int = _spawn_worker()
	var job: int = _make_job(JobsScript.JOB_KIND_HAUL)
	var assigned: JobsScript.OpResult = _jobs.assign_worker(worker, job)
	assert_true(assigned.ok, "the assignment succeeds (error: %s)" % assigned.error)
	assert_equal(_jobs.worker_of(job), _residents.ref_of(worker), "the job names its worker")
	assert_equal(_jobs.job_of(worker), _jobs.ref_of(job), "the agent names its job")
	assert_equal(_jobs.state_of(job).value, JobsScript.JOB_STATE_RESERVED, "the job is RESERVED")
	assert_equal(_jobs.phase_of(worker).value, JobsScript.JOB_STATE_RESERVED, "so is the phase")
	assert_false(_jobs.is_agent_idle(worker), "the agent is no longer idle")


func test_assignment_refuses_a_busy_agent_a_taken_job_and_a_job_that_is_not_queued() -> void:
	"""REQ-SET-030 binds one worker atomically; a double bind must refuse, not overwrite."""
	var first: int = _spawn_worker()
	var second: int = _spawn_worker()
	var job: int = _make_job(JobsScript.JOB_KIND_HAUL)
	var other: int = _make_job(JobsScript.JOB_KIND_HAUL)
	assert_true(_jobs.assign_worker(first, job).ok, "the first worker binds")
	assert_equal(_jobs.assign_worker(first, other).error, JobsScript.REFUSE_AGENT_BUSY,
		"a busy agent cannot take a second job")
	assert_equal(_jobs.assign_worker(second, job).error, JobsScript.REFUSE_JOB_HAS_WORKER,
		"a taken job cannot be bound twice")
	assert_equal(_jobs.worker_of(job), _residents.ref_of(first), "the first binding survives")
	assert_true(_jobs.set_state(other, JobsScript.JOB_STATE_COMPLETE).ok, "a job completes")
	assert_equal(_jobs.assign_worker(second, other).error, JobsScript.REFUSE_JOB_NOT_QUEUED,
		"only a QUEUED job is on offer")


func test_worker_departure_releases_the_assignment_and_leaves_job_progress_intact() -> void:
	"""Decision 0017: departure releases the assignment only; shared progress survives."""
	var worker: int = _spawn_worker()
	var job: int = _make_job(JobsScript.JOB_KIND_BUILD)
	assert_true(_jobs.set_remaining_mwu(job, 120000).ok, "the job carries work")
	assert_true(_jobs.assign_worker(worker, job).ok, "the worker binds")
	assert_true(_jobs.release_worker(worker).ok, "the worker departs")
	assert_equal(_jobs.remaining_mwu_of(job).value, 120000,
		"remaining_mwu is untouched: progress belongs to the job, not the worker")
	assert_equal(_jobs.worker_of(job), EntityDirectory.NULL_REF, "the job has no worker")
	assert_equal(_jobs.state_of(job).value, JobsScript.JOB_STATE_QUEUED, "it returns to the queue")
	assert_true(_jobs.is_agent_idle(worker), "the agent is idle again")
	assert_equal(_jobs.release_worker(worker).error, JobsScript.REFUSE_AGENT_IDLE,
		"releasing an idle agent refuses rather than silently doing nothing")


func test_destroying_a_worked_job_or_despawning_a_busy_agent_refuses() -> void:
	"""Cancellation and departure are separate paths; neither may quietly dangle the other side."""
	var worker: int = _spawn_worker()
	var job: int = _make_job(JobsScript.JOB_KIND_HAUL)
	assert_true(_jobs.assign_worker(worker, job).ok, "the worker binds")
	assert_equal(_jobs.destroy_job(job).error, JobsScript.REFUSE_JOB_HAS_WORKER,
		"destroying a worked job refuses")
	assert_equal(_jobs.despawn_agent(worker).error, JobsScript.REFUSE_AGENT_BUSY,
		"despawning a busy agent refuses")
	assert_true(_jobs.is_job_present(job), "the job is still there")
	assert_true(_jobs.release_worker(worker).ok, "the worker is released first")
	assert_true(_jobs.destroy_job(job).ok, "and then the job destroys")
	assert_true(_jobs.despawn_agent(worker).ok, "and the agent despawns")


# --- §5.3 eligibility step 1: health/rescue safety -----------------------------------------------

func test_step1_a_dead_resident_takes_no_job() -> void:
	"""Step 1, health/rescue safety. REQ-SET-016 makes death terminal for job selection."""
	var worker: int = _spawn_worker()
	var job: int = _make_job(JobsScript.JOB_KIND_HAUL)
	assert_true(_jobs.is_eligible(worker, job).ok, "a healthy resident is eligible")
	assert_true(_needs.apply_health_event(worker, -100).ok, "health reaches 0")
	assert_equal(_needs.status_of(worker).value, NeedsScript.STATUS_DEAD, "the status is DEAD")
	var refused: JobsScript.OpResult = _jobs.is_eligible(worker, job)
	assert_false(refused.ok, "a dead resident is ineligible")
	assert_equal(refused.error, JobsScript.REFUSE_RESIDENT_DEAD, "with the step 1 dead code")


func test_step1_an_incapacitated_resident_is_rescued_rather_than_put_to_work() -> void:
	"""Step 1 and REQ-SET-023: an incapacitated resident gets a rescue job, not a work assignment."""
	var worker: int = _spawn_worker()
	var job: int = _make_job(JobsScript.JOB_KIND_HAUL)
	assert_true(_needs.apply_health_event(worker, -90).ok, "health falls to 10")
	assert_equal(_needs.status_of(worker).value, NeedsScript.STATUS_INCAPACITATED,
		"health 1-15 is INCAPACITATED")
	var refused: JobsScript.OpResult = _jobs.is_eligible(worker, job)
	assert_false(refused.ok, "an incapacitated resident is ineligible")
	assert_equal(refused.error, JobsScript.REFUSE_RESIDENT_INCAPACITATED, "with the step 1 code")
	assert_true(_needs.apply_health_event(worker, 20).ok, "treatment restores consciousness")
	assert_true(_jobs.is_eligible(worker, job).ok, "and the resident may work again")


func test_step1_rest_at_or_below_500_cancels_ordinary_work() -> void:
	"""REQ-SET-015: "While rest<=500, the system shall cancel ordinary work"."""
	var worker: int = _spawn_worker()
	var job: int = _make_job(JobsScript.JOB_KIND_HAUL)
	assert_true(_needs.apply_need_event(worker, NeedsScript.NEED_REST, -7000).ok, "rest falls")
	assert_equal(_needs.need_of(worker, NeedsScript.NEED_REST).value, 500, "rest sits at 500")
	var refused: JobsScript.OpResult = _jobs.is_eligible(worker, job)
	assert_false(refused.ok, "a collapsed resident takes no ordinary work")
	assert_equal(refused.error, JobsScript.REFUSE_REST_COLLAPSED, "with the step 1 collapse code")
	assert_true(_needs.apply_need_event(worker, NeedsScript.NEED_REST, 1).ok, "rest reaches 501")
	assert_true(_jobs.is_eligible(worker, job).ok, "501 is above the threshold and permits work")


# --- §5.3 eligibility step 2: activity permits work ----------------------------------------------

func test_step2_a_sleep_or_social_hour_forbids_work_and_anything_permits_it() -> void:
	"""§4.3 Activity: WORK and ANYTHING permit a job; SLEEP and SOCIAL do not."""
	var worker: int = _spawn_worker(HOUR_SLEEP)
	var job: int = _make_job(JobsScript.JOB_KIND_HAUL)
	assert_equal(_schedule.current_activity_of(worker).value, ScheduleScript.ACTIVITY_SLEEP,
		"hour 23 resolves to SLEEP")
	var sleeping: JobsScript.OpResult = _jobs.is_eligible(worker, job)
	assert_false(sleeping.ok, "a sleeping resident takes no job")
	assert_equal(sleeping.error, JobsScript.REFUSE_ACTIVITY_FORBIDS_WORK, "with the step 2 code")
	assert_true(_schedule.resolve(worker, HOUR_SOCIAL, false).ok, "the social hour resolves")
	assert_equal(_jobs.is_eligible(worker, job).error, JobsScript.REFUSE_ACTIVITY_FORBIDS_WORK,
		"a SOCIAL hour also forbids work")
	assert_true(_schedule.resolve(worker, HOUR_ANYTHING, false).ok, "the flexible hour resolves")
	assert_true(_jobs.is_eligible(worker, job).ok, "ANYTHING permits work")


func test_step2_an_unresolved_activity_refuses_instead_of_assuming_work() -> void:
	"""schedule.gd refuses an unresolved current_activity; selection must not invent one."""
	var resident: int = _spawn_resident()
	assert_true(_jobs.spawn_agent(resident).ok, "the agent spawns without a resolved activity")
	var job: int = _make_job(JobsScript.JOB_KIND_HAUL)
	var refused: JobsScript.OpResult = _jobs.is_eligible(resident, job)
	assert_false(refused.ok, "an unresolved activity is not treated as permission to work")
	assert_equal(refused.error, JobsScript.REFUSE_ACTIVITY_UNRESOLVED, "with the step 2 code")
	assert_true(_schedule.resolve(resident, HOUR_WORK, false).ok, "the work hour resolves")
	assert_true(_jobs.is_eligible(resident, job).ok, "and the resident becomes eligible")


# --- §5.3 eligibility step 3: job kind priority nonzero ------------------------------------------

func test_step3_a_forbidden_job_kind_priority_excludes_every_job_of_that_kind() -> void:
	"""REQ-SET-026: priority 0 is forbidden. §5.3 step 3 requires it nonzero."""
	var worker: int = _spawn_worker()
	var haul: int = _make_job(JobsScript.JOB_KIND_HAUL)
	var build: int = _make_job(JobsScript.JOB_KIND_BUILD)
	assert_true(_priorities.set_priority(worker, JobsScript.JOB_KIND_HAUL,
		PrioritiesScript.PRIORITY_FORBIDDEN).ok, "the player forbids hauling")
	var refused: JobsScript.OpResult = _jobs.is_eligible(worker, haul)
	assert_false(refused.ok, "a forbidden kind is ineligible")
	assert_equal(refused.error, JobsScript.REFUSE_KIND_PRIORITY_FORBIDDEN, "with the step 3 code")
	assert_true(_jobs.is_eligible(worker, build).ok, "another kind is unaffected")
	var selected: JobsScript.OpResult = _select(worker)
	assert_true(selected.ok, "a pass still finds the permitted job")
	assert_equal(selected.value, build, "and it is the BUILD job, never the forbidden HAUL job")


# --- §5.3 eligibility step 4: required station/tool/skill/unlock ---------------------------------

func test_step4_a_blocked_station_tool_or_unlock_gate_excludes_the_job() -> void:
	"""Step 4's three environment gates. GATE_NOT_REQUIRED is the honest unfurnished-world default."""
	var worker: int = _spawn_worker()
	var job: int = _make_job(JobsScript.JOB_KIND_COOK)
	assert_equal(_jobs.station_gate_of(job).value, JobsScript.GATE_NOT_REQUIRED,
		"a job declares no station requirement by default")
	assert_true(_jobs.is_eligible(worker, job).ok, "so it is eligible")
	assert_true(_jobs.set_station_gate(job, JobsScript.GATE_BLOCKED).ok, "the station is blocked")
	assert_equal(_jobs.is_eligible(worker, job).error, JobsScript.REFUSE_STATION_BLOCKED,
		"and the job drops out at step 4")
	assert_true(_jobs.set_station_gate(job, JobsScript.GATE_SATISFIED).ok, "the station is ready")
	assert_true(_jobs.set_tool_gate(job, JobsScript.GATE_BLOCKED).ok, "but the tool is missing")
	assert_equal(_jobs.is_eligible(worker, job).error, JobsScript.REFUSE_TOOL_BLOCKED,
		"the tool gate reports its own code")
	assert_true(_jobs.set_tool_gate(job, JobsScript.GATE_SATISFIED).ok, "the tool arrives")
	assert_true(_jobs.set_unlock_gate(job, JobsScript.GATE_BLOCKED).ok, "the recipe is locked")
	assert_equal(_jobs.is_eligible(worker, job).error, JobsScript.REFUSE_UNLOCK_BLOCKED,
		"the unlock gate reports its own code")


func test_step4_a_job_demanding_more_skill_than_the_resident_has_is_excluded() -> void:
	"""Step 4's skill half, read from the resident's own Skills column for the job's own kind."""
	var worker: int = _spawn_worker()
	var job: int = _make_job(JobsScript.JOB_KIND_CRAFT, 0, 4)
	assert_equal(_residents.skill_level_of(worker, JobsScript.JOB_KIND_CRAFT).value, 0,
		"a fresh resident starts at level 0")
	var refused: JobsScript.OpResult = _jobs.is_eligible(worker, job)
	assert_false(refused.ok, "level 0 cannot take a level 4 job")
	assert_equal(refused.error, JobsScript.REFUSE_SKILL_TOO_LOW, "with the step 4 skill code")
	_grant_skill(worker, JobsScript.JOB_KIND_CRAFT, 3)
	assert_equal(_jobs.is_eligible(worker, job).error, JobsScript.REFUSE_SKILL_TOO_LOW,
		"level 3 is still one short")
	_grant_skill(worker, JobsScript.JOB_KIND_CRAFT, 4)
	assert_true(_jobs.is_eligible(worker, job).ok, "level 4 exactly meets the requirement")


# --- decision 0022: required_skill is a MINIMUM LEVEL in the job's own skill ----------------------

func test_required_skill_is_a_minimum_level_tested_one_below_exactly_equal_and_one_above() -> void:
	"""Decision 0022: `skill_passes = resident.skill_level[Job.kind] >= Job.required_skill`."""
	var worker: int = _spawn_worker()
	var job: int = _make_job(JobsScript.JOB_KIND_CRAFT, 0, 5)
	assert_equal(_jobs.skill_index_of(job).value, JobsScript.JOB_KIND_CRAFT,
		"the skill index IS the job's kind; required_skill names the level, not the skill")
	_grant_skill(worker, JobsScript.JOB_KIND_CRAFT, 4)
	assert_false(_jobs.skill_requirement_is_met(worker, job), "level 4 is one below the minimum")
	assert_equal(_jobs.is_eligible(worker, job).error, JobsScript.REFUSE_SKILL_TOO_LOW,
		"and step 4 refuses it")
	_grant_skill(worker, JobsScript.JOB_KIND_CRAFT, 5)
	assert_true(_jobs.skill_requirement_is_met(worker, job), "level 5 exactly meets the minimum")
	assert_true(_jobs.is_eligible(worker, job).ok, "so the job is eligible at exactly equal")
	_grant_skill(worker, JobsScript.JOB_KIND_CRAFT, 6)
	assert_true(_jobs.skill_requirement_is_met(worker, job), "and level 6 is one above")
	assert_true(_jobs.is_eligible(worker, job).ok, "which is also eligible")


func test_a_required_skill_of_zero_means_no_minimum_experience_at_all() -> void:
	"""Decision 0022 keeps 0 as the default and as "no minimum", not "level zero required"."""
	var worker: int = _spawn_worker()
	var job: int = _make_job(JobsScript.JOB_KIND_CRAFT)
	assert_equal(_jobs.required_skill_of(job).value, 0, "0 is the default minimum")
	assert_equal(_residents.skill_level_of(worker, JobsScript.JOB_KIND_CRAFT).value, 0,
		"and the resident is completely unskilled")
	assert_true(_jobs.skill_requirement_is_met(worker, job), "which passes the test")
	assert_true(_jobs.is_eligible(worker, job).ok, "and the job is eligible")


func test_a_required_skill_outside_zero_to_ten_is_an_invalid_definition_and_is_refused() -> void:
	"""Decision 0022: outside 0-10 is an INVALID JOB DEFINITION -- refused, never clamped."""
	assert_true(_jobs.validate_job_definition(JobsScript.JOB_KIND_CRAFT, 0).ok, "0 is valid")
	assert_true(_jobs.validate_job_definition(JobsScript.JOB_KIND_CRAFT, 10).ok, "and so is 10")
	var above: JobsScript.OpResult = _jobs.validate_job_definition(JobsScript.JOB_KIND_CRAFT, 11)
	assert_false(above.ok, "11 is one above the top level and is invalid")
	assert_equal(above.error, JobsScript.REFUSE_INVALID_REQUIRED_SKILL, "with its own code")
	assert_false(_jobs.validate_job_definition(JobsScript.JOB_KIND_CRAFT, -1).ok, "-1 is invalid")
	assert_equal(_jobs.create_job(JobsScript.JOB_KIND_CRAFT, 0, 11, 0, 0).error,
		JobsScript.REFUSE_INVALID_REQUIRED_SKILL, "create_job runs the same check")
	assert_equal(_jobs.job_count(), 0, "and no row was allocated for the invalid definition")
	var reserved: JobsScript.OpResult = _jobs.validate_job_definition(
		JobsScript.JOB_KIND_RESERVED_INDEX, 0)
	assert_false(reserved.ok, "RESERVED_3 is not a valid productive job kind at any level")
	assert_equal(reserved.error, JobsScript.REFUSE_RESERVED_JOB_KIND, "with the reserved code")


func test_party_members_are_checked_individually_not_against_a_crew_average() -> void:
	"""Decision 0022: a crew-average skill belongs to the catch calculation, not to eligibility.

	The two residents below average exactly the job's minimum, so an average test would admit
	both; the individual test admits only the one who actually has the skill.
	"""
	var expert: int = _spawn_worker()
	var novice: int = _spawn_worker()
	var job: int = _make_job(JobsScript.JOB_KIND_FISH, 0, 6)
	_grant_skill(expert, JobsScript.JOB_KIND_FISH, 10)
	_grant_skill(novice, JobsScript.JOB_KIND_FISH, 2)
	assert_equal((10 + 2) / 2, _jobs.required_skill_of(job).value,
		"the crew average is exactly the required minimum")
	assert_true(_jobs.skill_requirement_is_met(expert, job), "the expert passes on their own level")
	assert_false(_jobs.skill_requirement_is_met(novice, job), "the novice fails on theirs")
	assert_true(_jobs.is_eligible(expert, job).ok, "so only the expert is eligible")
	assert_equal(_jobs.is_eligible(novice, job).error, JobsScript.REFUSE_SKILL_TOO_LOW,
		"and the novice is refused despite the crew average clearing the bar")


# --- §5.3 eligibility step 5: dangerous consent --------------------------------------------------

func test_step5_a_dangerous_job_needs_the_residents_recorded_consent() -> void:
	"""Step 5. §5.1 defaults dangerous_work to false, so a dangerous job is refused until granted."""
	var worker: int = _spawn_worker()
	var job: int = _make_job(JobsScript.JOB_KIND_FISH)
	assert_true(_jobs.is_eligible(worker, job).ok, "an ordinary job needs no consent")
	assert_true(_jobs.set_dangerous(job, true).ok, "the job is marked dangerous")
	var refused: JobsScript.OpResult = _jobs.is_eligible(worker, job)
	assert_false(refused.ok, "a dangerous job is refused without consent")
	assert_equal(refused.error, JobsScript.REFUSE_DANGEROUS_CONSENT, "with the step 5 code")
	assert_true(_priorities.set_dangerous_work(worker, true).ok, "the player grants consent")
	assert_true(_jobs.is_eligible(worker, job).ok, "and the job becomes eligible")


func test_step5_the_req_set_015_hazard_latch_holds_between_500_and_4000_rest() -> void:
	"""REQ-SET-015: "prevent hazardous work until rest>=4000". Two thresholds, so it must latch."""
	var worker: int = _spawn_worker()
	var dangerous: int = _make_job(JobsScript.JOB_KIND_FISH)
	var safe: int = _make_job(JobsScript.JOB_KIND_HAUL)
	assert_true(_jobs.set_dangerous(dangerous, true).ok, "one job is dangerous")
	assert_true(_priorities.set_dangerous_work(worker, true).ok, "consent is granted")
	assert_true(_needs.apply_need_event(worker, NeedsScript.NEED_REST, -7100).ok, "rest hits 400")
	assert_true(_jobs.refresh_hazard_latch(worker).ok, "the latch updates")
	assert_true(_jobs.is_hazard_locked(worker), "rest<=500 engages the hazard bar")
	assert_true(_needs.apply_need_event(worker, NeedsScript.NEED_REST, 2600).ok, "rest reaches 3000")
	assert_true(_jobs.refresh_hazard_latch(worker).ok, "the latch updates again")
	assert_true(_jobs.is_hazard_locked(worker), "3000 is below 4000, so the bar holds")
	assert_equal(_jobs.is_eligible(worker, dangerous).error, JobsScript.REFUSE_HAZARD_LOCKED,
		"hazardous work is still barred despite consent")
	assert_true(_jobs.is_eligible(worker, safe).ok, "ordinary work is permitted again")
	assert_true(_needs.apply_need_event(worker, NeedsScript.NEED_REST, 1000).ok, "rest reaches 4000")
	assert_true(_jobs.refresh_hazard_latch(worker).ok, "the latch updates once more")
	assert_false(_jobs.is_hazard_locked(worker), "rest>=4000 clears the bar")
	assert_true(_jobs.is_eligible(worker, dangerous).ok, "and hazardous work resumes")


func test_a_selection_pass_refreshes_the_hazard_latch_itself() -> void:
	"""evaluate() must not depend on some other system having called refresh_hazard_latch first."""
	var worker: int = _spawn_worker()
	var dangerous: int = _make_job(JobsScript.JOB_KIND_FISH)
	assert_true(_jobs.set_dangerous(dangerous, true).ok, "the only job is dangerous")
	assert_true(_priorities.set_dangerous_work(worker, true).ok, "consent is granted")
	assert_true(_needs.apply_need_event(worker, NeedsScript.NEED_REST, -7100).ok, "rest hits 400")
	var collapsed: JobsScript.OpResult = _select(worker)
	assert_false(collapsed.ok, "a collapsed resident selects nothing")
	assert_true(_jobs.is_hazard_locked(worker), "the pass itself engaged the latch")
	assert_true(_needs.apply_need_event(worker, NeedsScript.NEED_REST, 2600).ok, "rest reaches 3000")
	var barred: JobsScript.OpResult = _select(worker, 1)
	assert_false(barred.ok, "the dangerous job is still barred")
	assert_equal(barred.error, JobsScript.REFUSE_NO_ELIGIBLE_JOB, "so the pass finds nothing")


# --- §5.3 eligibility step 6: complete inputs ----------------------------------------------------

func test_step6_a_job_with_incomplete_inputs_is_excluded() -> void:
	"""Step 6. The reservation pool owns binding; this store carries the gate it reports."""
	var worker: int = _spawn_worker()
	var job: int = _make_job(JobsScript.JOB_KIND_COOK)
	assert_equal(_jobs.inputs_gate_of(job).value, JobsScript.GATE_NOT_REQUIRED,
		"a job declares no inputs by default")
	assert_true(_jobs.is_eligible(worker, job).ok, "so it is eligible")
	assert_true(_jobs.set_inputs_gate(job, JobsScript.GATE_BLOCKED).ok, "an ingredient is missing")
	var refused: JobsScript.OpResult = _jobs.is_eligible(worker, job)
	assert_false(refused.ok, "the job drops out at step 6")
	assert_equal(refused.error, JobsScript.REFUSE_INPUTS_INCOMPLETE, "with the step 6 code")
	assert_false(_select(worker).ok, "and a pass will not select it")
	assert_true(_jobs.set_inputs_gate(job, JobsScript.GATE_SATISFIED).ok, "the inputs arrive")
	assert_equal(_select(worker, 1).value, job, "and the job is selected")


func test_a_job_already_worked_or_out_of_the_queue_is_not_a_candidate() -> void:
	"""Candidacy precedes the six steps: a taken or non-QUEUED job is not on offer at all."""
	var first: int = _spawn_worker()
	var second: int = _spawn_worker()
	var taken: int = _make_job(JobsScript.JOB_KIND_HAUL)
	var cancelled: int = _make_job(JobsScript.JOB_KIND_HAUL)
	assert_true(_jobs.assign_worker(first, taken).ok, "the first worker takes one job")
	assert_true(_jobs.set_state(cancelled, JobsScript.JOB_STATE_CANCELLED).ok,
		"the other is cancelled")
	assert_equal(_jobs.is_eligible(second, taken).error, JobsScript.REFUSE_JOB_HAS_WORKER,
		"a worked job is not a candidate")
	assert_equal(_jobs.is_eligible(second, cancelled).error, JobsScript.REFUSE_JOB_NOT_QUEUED,
		"a cancelled job is not a candidate")
	var selected: JobsScript.OpResult = _select(second)
	assert_false(selected.ok, "so the second worker finds nothing")
	assert_equal(selected.error, JobsScript.REFUSE_NO_ELIGIBLE_JOB, "with the no-candidate code")


# --- decision 0023: gates revalidate at commitment, and never fail open ---------------------------

func test_a_gate_whose_subsystem_cannot_answer_refuses_instead_of_reading_as_satisfied() -> void:
	"""Decision 0023: "a missing subsystem must never silently read as requirement satisfied"."""
	var worker: int = _spawn_worker()
	var job: int = _make_job(JobsScript.JOB_KIND_COOK)
	assert_true(_jobs.set_station_gate(job, JobsScript.GATE_UNAVAILABLE).ok,
		"the Building store cannot answer for this job's station")
	var station: JobsScript.OpResult = _jobs.is_eligible(worker, job)
	assert_false(station.ok, "an unanswerable requirement is not a satisfied one")
	assert_equal(station.error, JobsScript.REFUSE_STATION_UNAVAILABLE,
		"and reports 'cannot answer', which is not the refusal a blocked station gives")
	assert_true(_jobs.set_station_gate(job, JobsScript.GATE_SATISFIED).ok, "the station answers")
	assert_true(_jobs.set_inputs_gate(job, JobsScript.GATE_UNAVAILABLE).ok,
		"but no reservation pool can answer for the inputs")
	assert_equal(_jobs.is_eligible(worker, job).error, JobsScript.REFUSE_INPUTS_UNAVAILABLE,
		"step 6 refuses on the same principle")
	assert_false(_select(worker).ok, "and a pass will not select the job either")
	assert_true(_jobs.set_inputs_gate(job, JobsScript.GATE_SATISFIED).ok, "the inputs are answered")
	assert_equal(_select(worker, 1).value, job, "and only then is it selectable")


func test_commitment_revalidates_the_gates_rather_than_trusting_the_nomination() -> void:
	"""Decision 0023: a cached "inputs satisfied" cannot authorise acceptance after another job
	has reserved those inputs. `assign_worker()` re-reads every gate before it binds anything."""
	var worker: int = _spawn_worker()
	var job: int = _make_job(JobsScript.JOB_KIND_COOK)
	assert_true(_jobs.set_inputs_gate(job, JobsScript.GATE_SATISFIED).ok, "the inputs are there")
	var nominated: JobsScript.OpResult = _select(worker)
	assert_equal(nominated.value, job, "the pass nominates the job")
	assert_true(_jobs.set_inputs_gate(job, JobsScript.GATE_BLOCKED).ok,
		"and then another job reserves the very same inputs")
	var refused: JobsScript.OpResult = _jobs.assign_worker(worker, job)
	assert_false(refused.ok, "the stale nomination cannot authorise the binding")
	assert_equal(refused.error, JobsScript.REFUSE_INPUTS_INCOMPLETE, "with the live step 6 code")
	assert_equal(_jobs.worker_of(job), EntityDirectory.NULL_REF, "the job took no worker")
	assert_equal(_jobs.state_of(job).value, JobsScript.JOB_STATE_QUEUED, "and stayed QUEUED")
	assert_true(_jobs.is_agent_idle(worker), "the agent is still idle")
	assert_true(_jobs.set_inputs_gate(job, JobsScript.GATE_SATISFIED).ok, "the inputs return")
	assert_true(_jobs.assign_worker(worker, job).ok, "and the binding is allowed again")


func test_commitment_refuses_a_resident_whose_own_state_moved_since_the_nomination() -> void:
	"""The revalidation covers the resident too: the hazard latch is refreshed at the commitment
	point, so hazardous work cannot be bound on rest that was current several ticks ago."""
	var worker: int = _spawn_worker()
	var job: int = _make_job(JobsScript.JOB_KIND_FISH)
	assert_true(_jobs.set_dangerous(job, true).ok, "the job is dangerous")
	assert_true(_priorities.set_dangerous_work(worker, true).ok, "and consent is on record")
	assert_equal(_select(worker).value, job, "the pass nominates it while the resident is rested")
	assert_true(_needs.apply_need_event(worker, NeedsScript.NEED_REST, -7100).ok, "rest hits 400")
	var collapsed: JobsScript.OpResult = _jobs.assign_worker(worker, job)
	assert_false(collapsed.ok, "a collapsed resident cannot be bound to the nominated job")
	assert_equal(collapsed.error, JobsScript.REFUSE_REST_COLLAPSED, "with the step 1 code")
	assert_true(_jobs.is_hazard_locked(worker), "and the commitment refreshed the hazard latch")
	assert_true(_needs.apply_need_event(worker, NeedsScript.NEED_REST, 2600).ok, "rest reaches 3000")
	assert_equal(_jobs.assign_worker(worker, job).error, JobsScript.REFUSE_HAZARD_LOCKED,
		"3000 clears step 1 but the latch holds until 4000, and commitment honours it")
	assert_true(_needs.apply_need_event(worker, NeedsScript.NEED_REST, 1000).ok, "rest reaches 4000")
	assert_true(_jobs.assign_worker(worker, job).ok, "only a fully rested resident may commit")


# --- §5.3 urgency buckets ------------------------------------------------------------------------

func test_the_five_urgency_buckets_are_consumed_in_ascending_order() -> void:
	"""§5.3: 0 rescue, 1 personal critical, 2 food/fuel under reserve, 3 ordinary, 4 cosmetic."""
	var worker: int = _spawn_worker()
	var cosmetic: int = _make_job(JobsScript.JOB_KIND_KEEP)
	var ordinary: int = _make_job(JobsScript.JOB_KIND_KEEP)
	var food: int = _make_job(JobsScript.JOB_KIND_KEEP)
	var critical: int = _make_job(JobsScript.JOB_KIND_KEEP)
	var rescue: int = _make_job(JobsScript.JOB_KIND_KEEP)
	assert_true(_jobs.set_urgency(cosmetic, JobsScript.URGENCY_COSMETIC).ok, "bucket 4 declared")
	assert_true(_jobs.set_urgency(food, JobsScript.URGENCY_FOOD_FUEL).ok, "bucket 2 declared")
	assert_true(_jobs.set_urgency(critical, JobsScript.URGENCY_PERSONAL_CRITICAL).ok, "bucket 1")
	assert_true(_jobs.set_urgency(rescue, JobsScript.URGENCY_RESCUE).ok, "bucket 0 declared")
	_jobs.set_food_reserve_below_two_days(true)
	var expected: Array[int] = [rescue, critical, food, ordinary, cosmetic]
	for index: int in expected.size():
		var selected: JobsScript.OpResult = _select(worker, index)
		assert_equal(selected.value, expected[index],
			"bucket %d is taken before every higher bucket" % index)
		assert_true(_jobs.destroy_job(expected[index]).ok, "the winner is consumed")


func test_bucket_2_applies_only_while_the_projected_reserve_is_under_two_days() -> void:
	"""§5.3 makes bucket 2 conditional; a food job ranks as ordinary work while stocks are fine."""
	var worker: int = _spawn_worker()
	var ordinary: int = _make_job(JobsScript.JOB_KIND_KEEP)
	var food: int = _make_job(JobsScript.JOB_KIND_KEEP)
	assert_true(_jobs.set_urgency(food, JobsScript.URGENCY_FOOD_FUEL).ok, "the food job declares 2")
	assert_false(_jobs.food_reserve_below_two_days(), "the reserve is fine by default")
	assert_equal(_jobs.effective_urgency_of(food).value, JobsScript.URGENCY_ORDINARY,
		"so the food job occupies bucket 3")
	assert_equal(_select(worker).value, ordinary,
		"and loses to the older ordinary job on the job-id tie-break")
	_jobs.set_food_reserve_below_two_days(true)
	assert_equal(_jobs.effective_urgency_of(food).value, JobsScript.URGENCY_FOOD_FUEL,
		"under a two-day reserve it occupies bucket 2")
	assert_equal(_select(worker, 1).value, food, "and now outranks the ordinary job")
	assert_equal(_jobs.urgency_of(food).value, JobsScript.URGENCY_FOOD_FUEL,
		"the declared bucket never changed; only the world condition did")


func test_the_urgency_bucket_outranks_the_whole_within_bucket_sort_key() -> void:
	"""Buckets are the outer order: a bucket-0 job wins even with the worse sort key everywhere."""
	var worker: int = _spawn_worker()
	var haul: int = _make_job(JobsScript.JOB_KIND_HAUL, 0)
	var build: int = _make_job(JobsScript.JOB_KIND_BUILD, 9, 0, SHARED_CREATED_TICK + 500)
	assert_equal(_priorities.priority_of(worker, JobsScript.JOB_KIND_HAUL).value, 2,
		"§5.1 starts HAUL at player priority 2")
	assert_equal(_priorities.priority_of(worker, JobsScript.JOB_KIND_BUILD).value, 3,
		"and BUILD at 3, so the HAUL job wins every within-bucket term")
	assert_equal(_select(worker).value, haul, "which it does while both sit in bucket 3")
	assert_true(_jobs.set_urgency(build, JobsScript.URGENCY_RESCUE).ok, "the BUILD job is a rescue")
	assert_equal(_select(worker, 1).value, build,
		"bucket 0 outranks a better player priority, job priority, creation tick and job id")


# --- §5.3 within-bucket sort key, one dimension at a time ----------------------------------------

func test_sort_term_1_player_priority_decides_between_otherwise_identical_candidates() -> void:
	"""First term. The BUILD job is created first, so only player_priority can flip the winner."""
	var worker: int = _spawn_worker()
	var build: int = _make_job(JobsScript.JOB_KIND_BUILD)
	var haul: int = _make_job(JobsScript.JOB_KIND_HAUL)
	assert_equal(_residents.skill_level_of(worker, JobsScript.JOB_KIND_BUILD).value,
		_residents.skill_level_of(worker, JobsScript.JOB_KIND_HAUL).value,
		"the two candidates tie on skill level")
	assert_true(_jobs.job_id_of(build).value < _jobs.job_id_of(haul).value,
		"and the BUILD job holds the lower job id, which would win every later term")
	assert_equal(_select(worker).value, haul, "HAUL's player priority 2 beats BUILD's 3")
	assert_true(_priorities.set_priority(worker, JobsScript.JOB_KIND_BUILD, 1).ok,
		"the player raises BUILD to the highest priority")
	assert_equal(_select(worker, 1).value, build, "and the winner flips")


func test_sort_term_2_job_priority_decides_when_the_player_priority_ties() -> void:
	"""Second term. Both jobs are HAUL, so player_priority ties and only Job.priority differs."""
	var worker: int = _spawn_worker()
	var high_number: int = _make_job(JobsScript.JOB_KIND_HAUL, 5)
	var low_number: int = _make_job(JobsScript.JOB_KIND_HAUL, 1)
	assert_true(_jobs.job_id_of(high_number).value < _jobs.job_id_of(low_number).value,
		"the worse-priority job holds the lower job id")
	assert_equal(_jobs.created_tick_of(high_number).value,
		_jobs.created_tick_of(low_number).value, "and both were created on the same tick")
	assert_equal(_select(worker).value, low_number, "the ascending Job.priority term picks 1 over 5")
	assert_true(_jobs.set_state(low_number, JobsScript.JOB_STATE_CANCELLED).ok, "it is withdrawn")
	assert_equal(_select(worker, 1).value, high_number, "leaving the remaining candidate")


func test_sort_term_3_skill_level_is_descending_and_decides_when_both_priorities_tie() -> void:
	"""Third term is written `-skill_level`, so the HIGHER level wins, not the lower."""
	var worker: int = _spawn_worker()
	var unskilled: int = _make_job(JobsScript.JOB_KIND_HAUL)
	var skilled: int = _make_job(JobsScript.JOB_KIND_FARM)
	assert_true(_priorities.set_priority(worker, JobsScript.JOB_KIND_FARM, 2).ok,
		"both kinds share player priority 2")
	_grant_skill(worker, JobsScript.JOB_KIND_FARM, 5)
	assert_equal(_residents.skill_level_of(worker, JobsScript.JOB_KIND_HAUL).value, 0,
		"and the resident is unskilled at hauling")
	assert_true(_jobs.job_id_of(unskilled).value < _jobs.job_id_of(skilled).value,
		"the unskilled candidate holds the lower job id and would win every later term")
	assert_equal(_select(worker).value, skilled, "the higher skill level wins the third term")


func test_sort_term_5_created_tick_decides_when_priorities_and_skill_all_tie() -> void:
	"""Fifth term, ascending: the older job wins. (The fourth term is absent -- see the header.)"""
	var worker: int = _spawn_worker()
	var late: int = _make_job(JobsScript.JOB_KIND_HAUL, 0, 0, 900)
	var early: int = _make_job(JobsScript.JOB_KIND_HAUL, 0, 0, 100)
	assert_true(_jobs.job_id_of(late).value < _jobs.job_id_of(early).value,
		"the later-created job holds the lower job id")
	assert_equal(_select(worker).value, early, "but the earlier creation tick wins")
	assert_true(_jobs.set_state(early, JobsScript.JOB_STATE_CANCELLED).ok, "it is withdrawn")
	assert_equal(_select(worker, 1).value, late, "leaving the remaining candidate")


func test_sort_term_6_job_id_breaks_a_complete_tie_and_makes_the_order_total() -> void:
	"""Sixth term. Persistent IDs are never reused, so no two candidates can compare equal."""
	var worker: int = _spawn_worker()
	var first: int = _make_job(JobsScript.JOB_KIND_HAUL)
	var second: int = _make_job(JobsScript.JOB_KIND_HAUL)
	assert_true(_jobs.job_id_of(first).value < _jobs.job_id_of(second).value,
		"the first job holds the lower persistent id")
	assert_equal(_select(worker).value, first, "which wins a complete tie")
	assert_true(_jobs.destroy_job(first).ok, "the winner is consumed")
	assert_equal(_select(worker, 1).value, second, "and the other is taken next")


func test_the_sort_terms_are_applied_in_the_specified_order_not_a_permuted_one() -> void:
	"""Each pair below is decided by an earlier term while a later term points the other way."""
	_assert_player_priority_outranks_job_priority()
	_assert_job_priority_outranks_skill_level()
	_assert_skill_level_outranks_created_tick()


func _assert_player_priority_outranks_job_priority() -> void:
	"""A HAUL job with the worst Job.priority still beats a BUILD job with the best."""
	var worker: int = _spawn_worker()
	var build: int = _make_job(JobsScript.JOB_KIND_BUILD, 0)
	var haul: int = _make_job(JobsScript.JOB_KIND_HAUL, 9)
	assert_true(_jobs.job_id_of(build).value < _jobs.job_id_of(haul).value, "BUILD is older")
	assert_equal(_select(worker).value, haul,
		"player priority 2 outranks a Job.priority of 0 against 9")


func _assert_job_priority_outranks_skill_level() -> void:
	"""With player priority tied, Job.priority decides before the resident's skill does."""
	var worker: int = _spawn_worker()
	var haul: int = _make_job(JobsScript.JOB_KIND_HAUL, 0)
	var farm: int = _make_job(JobsScript.JOB_KIND_FARM, 9)
	assert_true(_priorities.set_priority(worker, JobsScript.JOB_KIND_FARM, 2).ok, "priorities tie")
	_grant_skill(worker, JobsScript.JOB_KIND_FARM, 6)
	assert_equal(_select(worker).value, haul,
		"Job.priority 0 outranks a six-level skill advantage")


func _assert_skill_level_outranks_created_tick() -> void:
	"""With both priorities tied, skill decides before the creation tick does."""
	var worker: int = _spawn_worker()
	var old_haul: int = _make_job(JobsScript.JOB_KIND_HAUL, 0, 0, 10)
	var new_farm: int = _make_job(JobsScript.JOB_KIND_FARM, 0, 0, 900)
	assert_true(_priorities.set_priority(worker, JobsScript.JOB_KIND_FARM, 2).ok, "priorities tie")
	_grant_skill(worker, JobsScript.JOB_KIND_FARM, 4)
	assert_true(_jobs.job_id_of(old_haul).value < _jobs.job_id_of(new_farm).value, "HAUL is older")
	assert_equal(_select(worker).value, new_farm, "the higher skill outranks the older tick")


# --- §5.3 reevaluation cadence and stagger -------------------------------------------------------

func test_the_stagger_offset_is_the_residents_persistent_id_modulo_thirty() -> void:
	"""ARCH-JOB-002: "idle residents evaluate every 30 ticks staggered by persistent ID mod 30"."""
	for index: int in 5:
		var slot: int = _spawn_worker()
		var persistent_id: IntMath.IntResult = _residents.persistent_id_of(slot)
		assert_true(persistent_id.ok, "the persistent id reads")
		assert_equal(_jobs.stagger_offset_of(slot).value,
			persistent_id.value % JobsScript.STAGGER_MODULUS,
			"resident %d evaluates at persistent_id mod 30" % index)


func test_residents_evaluate_on_different_ticks_rather_than_all_at_once() -> void:
	"""The point of the stagger: at most one of ten residents is due on any single tick."""
	var workers: Array[int] = []
	for index: int in 10:
		workers.append(_spawn_worker())
	var total_due: int = 0
	for tick: int in JobsScript.REEVALUATION_INTERVAL_TICKS:
		var due_this_tick: int = 0
		for worker: int in workers:
			if _jobs.should_evaluate(worker, tick):
				due_this_tick += 1
		assert_true(due_this_tick <= 1, "tick %d has at most one due resident" % tick)
		total_due += due_this_tick
	assert_equal(total_due, workers.size(), "and every resident is due exactly once in 30 ticks")


func test_two_residents_thirty_ids_apart_share_a_tick_because_the_stagger_is_modular() -> void:
	""""mod 30" is modular, not unique-per-resident: IDs 1 and 31 collide, and must."""
	var first: int = _spawn_worker()
	var last: int = 0
	for index: int in 30:
		last = _spawn_worker()
	var first_id: IntMath.IntResult = _residents.persistent_id_of(first)
	var last_id: IntMath.IntResult = _residents.persistent_id_of(last)
	assert_equal(last_id.value - first_id.value, 30, "the two residents are thirty ids apart")
	var tick: int = _due_tick(first)
	assert_true(_jobs.should_evaluate(first, tick), "the first resident is due")
	assert_true(_jobs.should_evaluate(last, tick), "and so is the one thirty ids later")
	assert_equal(_jobs.stagger_offset_of(first).value, _jobs.stagger_offset_of(last).value,
		"they share an offset")


func test_an_evaluation_off_the_staggered_tick_refuses_rather_than_running_early() -> void:
	"""The cadence is enforced by the store, so no caller can quietly reevaluate every tick."""
	var worker: int = _spawn_worker()
	var job: int = _make_job(JobsScript.JOB_KIND_HAUL)
	var due: int = _due_tick(worker)
	var early: JobsScript.OpResult = _jobs.evaluate(worker, due + 1)
	assert_false(early.ok, "one tick early is refused")
	assert_equal(early.error, JobsScript.REFUSE_NOT_DUE_THIS_TICK, "with the cadence code")
	assert_false(_jobs.evaluate(worker, due + 29).ok, "and so is twenty-nine ticks early")
	assert_equal(_jobs.evaluate(worker, due + 30).value, job, "the next window is due again")
	assert_equal(_jobs.evaluate(worker, -1).error, JobsScript.REFUSE_INVALID_TICK,
		"a negative tick is refused rather than wrapped into a modulus")


func test_a_resident_already_holding_a_job_is_never_reevaluated() -> void:
	"""§5.3 reevaluates IDLE residents; a worker keeps the job it has."""
	var worker: int = _spawn_worker()
	var job: int = _make_job(JobsScript.JOB_KIND_HAUL)
	var better: int = _make_job(JobsScript.JOB_KIND_HAUL, -100)
	assert_true(_jobs.assign_worker(worker, job).ok, "the worker takes the first job")
	assert_false(_jobs.should_evaluate(worker, _due_tick(worker, 1)), "and is no longer due")
	var refused: JobsScript.OpResult = _jobs.evaluate(worker, _due_tick(worker, 1))
	assert_false(refused.ok, "an evaluation is refused while busy")
	assert_equal(refused.error, JobsScript.REFUSE_AGENT_BUSY, "with the busy code")
	assert_true(_jobs.release_worker(worker).ok, "once released")
	assert_equal(_jobs.evaluate(worker, _due_tick(worker, 2)).value, better,
		"the resident reevaluates and now takes the better job")


# --- §5.3 candidate budget and the decision 0023 continuation key ------------------------------

func test_a_queue_shorter_than_the_budget_needs_no_continuation_at_all() -> void:
	"""A whole queue examined inside one budget is a completed scan: there is nothing to resume,
	so the key stays at its (bucket 0, id 0) resting value and the next pass sees the queue whole.
	(That a completed pass CLEARS a key it inherited is proved by the resume test below, which
	suspends first.)"""
	var worker: int = _spawn_worker()
	for index: int in 5:
		var _slot: int = _make_job(JobsScript.JOB_KIND_HAUL)
	assert_false(_jobs.has_continuation(worker), "a fresh agent holds no continuation")
	assert_equal(_select(worker, 0).value, _jobs.live_job_at(0).value, "the oldest job wins")
	assert_false(_jobs.has_continuation(worker), "and the completed scan leaves none behind")
	assert_equal(_jobs.continuation_bucket_of(worker).value, 0, "the bucket half returns to 0")
	assert_equal(_jobs.continuation_job_id_of(worker).value, 0, "and so does the id half")
	assert_equal(_select(worker, 1).value, _jobs.live_job_at(0).value,
		"so the next pass sees the same whole queue from the top")


func test_a_pass_examines_at_most_thirty_two_candidates_across_every_bucket_it_touches() -> void:
	"""The 32 is a TOTAL, not a per-bucket allowance: 20 rescue jobs leave only 12 for bucket 4."""
	var worker: int = _spawn_worker()
	var rescues: Array[int] = _make_blocked_jobs(20, JobsScript.URGENCY_RESCUE)
	var cosmetics: Array[int] = _make_blocked_jobs(20, JobsScript.URGENCY_COSMETIC)
	var refused: JobsScript.OpResult = _select(worker, 0)
	assert_false(refused.ok, "every candidate is blocked at step 6, so the pass selects nothing")
	assert_equal(refused.error, JobsScript.REFUSE_NO_ELIGIBLE_JOB, "with the no-candidate code")
	assert_equal(_jobs.continuation_bucket_of(worker).value, JobsScript.URGENCY_COSMETIC,
		"the budget ran out in bucket 4, after all twenty rescues were examined")
	assert_equal(_jobs.continuation_job_id_of(worker).value, _jobs.job_id_of(cosmetics[11]).value,
		"exactly twelve cosmetic jobs fitted in the twelve remaining candidate slots")
	assert_equal(_jobs.job_id_of(rescues[19]).value + 1, _jobs.job_id_of(cosmetics[0]).value,
		"the two runs are consecutive in persistent id, so 20+12 is the only reading of that key")


func test_the_continuation_resumes_the_next_pass_instead_of_restarting_at_bucket_zero() -> void:
	"""40 blocked jobs then 8 open ones: pass 2 must resume where pass 1 stopped, not re-walk."""
	var worker: int = _spawn_worker()
	var blocked: Array[int] = _make_blocked_jobs(32, JobsScript.URGENCY_ORDINARY)
	var open: Array[int] = []
	for index: int in 8:
		open.append(_make_job(JobsScript.JOB_KIND_HAUL))
	assert_false(_select(worker, 0).ok, "pass 1 spends its whole budget on the blocked jobs")
	assert_equal(_jobs.continuation_bucket_of(worker).value, JobsScript.URGENCY_ORDINARY,
		"and suspends in bucket 3")
	assert_equal(_jobs.continuation_job_id_of(worker).value, _jobs.job_id_of(blocked[31]).value,
		"at the persistent id of the thirty-second candidate it examined")
	assert_equal(_select(worker, 1).value, open[0],
		"pass 2 resumes after that id and takes the first open job")
	assert_false(_jobs.has_continuation(worker), "the completed scan clears the key")


func test_the_budget_never_changes_eligibility_only_when_a_candidate_is_reached() -> void:
	"""§5.3's closing clause: a job the cursor has not reached is still eligible, never skipped."""
	var worker: int = _spawn_worker()
	var slots: Array[int] = []
	for index: int in 100:
		slots.append(_make_job(JobsScript.JOB_KIND_HAUL))
	var only_eligible: int = slots[99]
	for index: int in 99:
		assert_true(_jobs.set_inputs_gate(slots[index], JobsScript.GATE_BLOCKED).ok,
			"every earlier candidate is blocked at step 6")
	assert_true(_jobs.is_eligible(worker, only_eligible).ok,
		"the far candidate is eligible before any pass runs")
	for window: int in 3:
		var pass_result: JobsScript.OpResult = _select(worker, window)
		assert_false(pass_result.ok, "pass %d cannot reach it inside the budget" % window)
		assert_equal(pass_result.error, JobsScript.REFUSE_NO_ELIGIBLE_JOB,
			"and reports no eligible job, never marking the far candidate ineligible")
	assert_true(_jobs.is_eligible(worker, only_eligible).ok,
		"the far candidate is still eligible after three budget-limited passes")
	assert_equal(_select(worker, 3).value, only_eligible,
		"and the fourth pass reaches and selects it")


func test_an_empty_queue_refuses_explicitly_rather_than_returning_a_sentinel_slot() -> void:
	"""No job is a legitimate outcome, and it must not read as job slot -1 or job slot 0."""
	var worker: int = _spawn_worker()
	var empty: JobsScript.OpResult = _select(worker)
	assert_false(empty.ok, "an empty queue selects nothing")
	assert_equal(empty.error, JobsScript.REFUSE_NO_ELIGIBLE_JOB, "with an explicit refusal")
	assert_equal(empty.value, 0, "carrying no job slot")
	assert_equal(empty.ref, EntityDirectory.NULL_REF, "and the null reference")
	assert_false(_jobs.has_continuation(worker),
		"an empty queue exhausts every bucket, so it leaves no continuation behind")


# --- decision 0023: enumeration visits urgency buckets, not row order -----------------------------

func test_a_rescue_behind_more_than_thirty_two_cosmetic_jobs_is_still_found() -> void:
	"""Decision 0023's defect, stated as a test: forty cosmetic jobs queued ahead of one rescue.

	In ascending live-row order the rescue sits at position 41 and cannot be examined inside a
	32-candidate budget, so the resident would sweep a floor while someone lay incapacitated.
	Bucket enumeration reaches it on the FIRST pass, without raising the budget.
	"""
	var worker: int = _spawn_worker()
	var cosmetics: Array[int] = _make_open_jobs(40, JobsScript.URGENCY_COSMETIC)
	var rescue: int = _make_job(JobsScript.JOB_KIND_KEEP)
	assert_true(_jobs.set_urgency(rescue, JobsScript.URGENCY_RESCUE).ok, "the rescue declares 0")
	assert_equal(_jobs.job_count(), 41, "forty-one candidates are queued")
	assert_true(_jobs.job_id_of(cosmetics[39]).value < _jobs.job_id_of(rescue).value,
		"and the rescue is the newest of them all, behind every cosmetic job")
	assert_true(_jobs.is_eligible(worker, cosmetics[0]).ok, "the cosmetic jobs are all eligible")
	var selected: JobsScript.OpResult = _select(worker, 0)
	assert_true(selected.ok, "the first pass selects (error: %s)" % selected.error)
	assert_equal(selected.value, rescue,
		"thirty-two cosmetic jobs cannot hide a rescue: bucket 0 is walked first")
	assert_false(_jobs.has_continuation(worker), "the pass decided, so it left no continuation")


func test_higher_urgency_work_appearing_during_a_continued_scan_invalidates_it() -> void:
	"""Decision 0023: a newly available higher-urgency job invalidates a continuation into lower
	buckets, which is the only reason the second pass can see bucket 0 at all."""
	var worker: int = _spawn_worker()
	var blocked: Array[int] = _make_blocked_jobs(40, JobsScript.URGENCY_ORDINARY)
	assert_false(_select(worker, 0).ok, "pass 1 spends the budget without finding a candidate")
	assert_equal(_jobs.continuation_bucket_of(worker).value, JobsScript.URGENCY_ORDINARY,
		"and suspends inside bucket 3")
	assert_equal(_jobs.continuation_job_id_of(worker).value, _jobs.job_id_of(blocked[31]).value,
		"at the thirty-second candidate")
	var rescue: int = _make_job(JobsScript.JOB_KIND_KEEP)
	assert_true(_jobs.set_urgency(rescue, JobsScript.URGENCY_RESCUE).ok, "a rescue is raised")
	assert_false(_jobs.has_continuation(worker),
		"which invalidates the continuation rather than leaving it pointing into bucket 3")
	assert_equal(_select(worker, 1).value, rescue,
		"so pass 2 restarts at bucket 0 and takes the rescue instead of resuming past it")


func test_lower_urgency_work_appearing_during_a_continued_scan_leaves_it_alone() -> void:
	"""Only HIGHER urgency invalidates. Resetting on every insertion would starve a long queue:
	the resident would re-walk the same blocked jobs forever and never reach the open ones."""
	var worker: int = _spawn_worker()
	var blocked: Array[int] = _make_blocked_jobs(40, JobsScript.URGENCY_ORDINARY)
	assert_false(_select(worker, 0).ok, "pass 1 suspends inside bucket 3")
	var saved_id: int = _jobs.continuation_job_id_of(worker).value
	assert_equal(saved_id, _jobs.job_id_of(blocked[31]).value, "at the thirty-second candidate")
	var cosmetic: int = _make_job(JobsScript.JOB_KIND_KEEP)
	assert_true(_jobs.set_urgency(cosmetic, JobsScript.URGENCY_COSMETIC).ok, "bucket 4 work arrives")
	assert_true(_jobs.has_continuation(worker), "the continuation survives a lower-urgency job")
	assert_equal(_jobs.continuation_job_id_of(worker).value, saved_id, "unchanged")
	assert_equal(_jobs.continuation_bucket_of(worker).value, JobsScript.URGENCY_ORDINARY,
		"and still pointing into bucket 3")
	assert_equal(_select(worker, 1).value, cosmetic,
		"pass 2 finishes bucket 3's remaining eight, finds nothing, and descends to the new job")


func test_deleting_a_job_before_the_continuation_point_does_not_change_what_it_means() -> void:
	"""The key is `(bucket, persistent id)`, so deletions cannot shift it. A POSITIONAL cursor of
	32 would point at the thirty-eighth job once five earlier rows were destroyed."""
	var worker: int = _spawn_worker()
	var blocked: Array[int] = _make_blocked_jobs(32, JobsScript.URGENCY_ORDINARY)
	var open: Array[int] = _make_open_jobs(8, JobsScript.URGENCY_ORDINARY)
	assert_false(_select(worker, 0).ok, "pass 1 suspends after the thirty-two blocked jobs")
	var saved_id: int = _jobs.continuation_job_id_of(worker).value
	assert_equal(saved_id, _jobs.job_id_of(blocked[31]).value, "on the last one it examined")
	for index: int in 5:
		assert_true(_jobs.destroy_job(blocked[index]).ok, "an early job is destroyed")
	assert_equal(_jobs.job_count(), 35, "the live index is five shorter")
	assert_equal(_jobs.continuation_job_id_of(worker).value, saved_id,
		"the key names a job, not a position, so five deletions before it change nothing")
	assert_equal(_select(worker, 1).value, open[0],
		"pass 2 still resumes at the first open job, not five places past it")


func test_more_than_thirty_two_higher_urgency_candidates_that_all_fail_eligibility() -> void:
	"""Forty ineligible rescues must not trap the resident: the pass descends once bucket 0 is
	EXHAUSTED, which takes two passes, and the budget never marks any of them ineligible."""
	var worker: int = _spawn_worker()
	var rescues: Array[int] = _make_blocked_jobs(40, JobsScript.URGENCY_RESCUE)
	var ordinary: int = _make_job(JobsScript.JOB_KIND_KEEP)
	var first: JobsScript.OpResult = _select(worker, 0)
	assert_false(first.ok, "pass 1 finds nothing eligible in bucket 0")
	assert_equal(first.error, JobsScript.REFUSE_NO_ELIGIBLE_JOB, "with the no-candidate code")
	assert_equal(_jobs.continuation_bucket_of(worker).value, JobsScript.URGENCY_RESCUE,
		"and does NOT descend past a bucket it has not exhausted")
	assert_equal(_jobs.continuation_job_id_of(worker).value, _jobs.job_id_of(rescues[31]).value,
		"having examined exactly thirty-two of the forty")
	assert_equal(_select(worker, 1).value, ordinary,
		"pass 2 finishes the last eight rescues and only then takes the ordinary job")
	assert_equal(_jobs.is_eligible(worker, rescues[39]).error, JobsScript.REFUSE_INPUTS_INCOMPLETE,
		"the unexamined rescues were never evaluated, and are still refused only by step 6")


func test_the_continuation_key_is_deterministic_across_two_identically_built_worlds() -> void:
	"""SAVE/LOAD MID-SCAN IS DEFERRED: there is no save format, no world writer and no loader in
	this milestone, so no round trip can be asserted and none is faked here.

	What is provable now is the property a round trip would have to preserve. Both halves of the
	key are already world state -- the job's declared urgency bucket and the directory's
	never-reused persistent id -- and neither is a position into a runtime array. Two worlds built
	by the same sequence of operations therefore suspend on the same key, byte for byte.
	"""
	var worker: int = _spawn_worker()
	var blocked: Array[int] = _make_blocked_jobs(40, JobsScript.URGENCY_ORDINARY)
	assert_false(_select(worker, 0).ok, "the scan suspends mid-bucket")
	var key: Vector2i = Vector2i(_jobs.continuation_bucket_of(worker).value,
		_jobs.continuation_job_id_of(worker).value)
	assert_equal(key.x, JobsScript.URGENCY_ORDINARY, "the bucket half is the job's own urgency")
	assert_equal(key.y, _jobs.job_id_of(blocked[31]).value, "the id half is a real job's id")
	assert_equal(_replay_in_a_fresh_world(), key,
		"an independently built world replaying the same operations suspends on the same key")


func _replay_in_a_fresh_world() -> Vector2i:
	"""Build a second, independent set of stores, replay the same script, and return its key.

	The member stores are swapped for the duration so one fixture drives both worlds, and are
	restored before returning so the caller's world is left exactly as it was.
	"""
	var kept_residents: ResidentsScript = _residents
	var kept_priorities: PrioritiesScript = _priorities
	var kept_schedule: ScheduleScript = _schedule
	var kept_jobs: JobsScript = _jobs
	before_each()
	var worker: int = _spawn_worker()
	var blocked: Array[int] = _make_blocked_jobs(40, JobsScript.URGENCY_ORDINARY)
	assert_false(_select(worker, 0).ok, "the replayed scan suspends in the same place")
	assert_equal(_jobs.continuation_job_id_of(worker).value, _jobs.job_id_of(blocked[31]).value,
		"on its own thirty-second candidate")
	var key: Vector2i = Vector2i(_jobs.continuation_bucket_of(worker).value,
		_jobs.continuation_job_id_of(worker).value)
	_residents = kept_residents
	_needs = _residents.needs()
	_priorities = kept_priorities
	_schedule = kept_schedule
	_jobs = kept_jobs
	return key


func _suspend_in_the_cosmetic_bucket() -> int:
	"""Spawn a worker and leave it suspended mid-scan in bucket 4 over forty blocked jobs.

	The fixture for every "a job becomes available in a HIGHER bucket" test: the resident has
	already descended past buckets 0-3 and would never look at them again on its own.
	"""
	var worker: int = _spawn_worker()
	var blocked: Array[int] = _make_blocked_jobs(40, JobsScript.URGENCY_COSMETIC)
	assert_false(_select(worker, 0).ok, "pass 1 finds nothing eligible and suspends")
	assert_equal(_jobs.continuation_bucket_of(worker).value, JobsScript.URGENCY_COSMETIC,
		"inside bucket 4, having exhausted every higher bucket")
	assert_true(_jobs.has_continuation(worker), "so a continuation is held (%d blocked)"
		% blocked.size())
	return worker


func test_a_newly_created_job_invalidates_a_continuation_that_descended_below_it() -> void:
	"""Plain creation is an admission too: a new job is ORDINARY, which outranks bucket 4."""
	var worker: int = _suspend_in_the_cosmetic_bucket()
	var ordinary: int = _make_job(JobsScript.JOB_KIND_KEEP)
	assert_false(_jobs.has_continuation(worker),
		"creating ordinary work invalidates a continuation that already sits in cosmetic upkeep")
	assert_equal(_select(worker, 1).value, ordinary,
		"so pass 2 takes the new job instead of resuming eight blocked cosmetic ones")


func test_a_job_returning_to_the_queue_invalidates_a_lower_bucket_continuation() -> void:
	"""A released worker puts its job back on offer, which is an admission into that job's bucket."""
	var owner: int = _spawn_worker()
	var rescue: int = _make_job(JobsScript.JOB_KIND_KEEP)
	assert_true(_jobs.set_urgency(rescue, JobsScript.URGENCY_RESCUE).ok, "a rescue is queued")
	assert_true(_jobs.assign_worker(owner, rescue).ok, "and taken, so it is not a candidate")
	var worker: int = _suspend_in_the_cosmetic_bucket()
	assert_true(_jobs.release_worker(owner).ok, "then its worker departs")
	assert_false(_jobs.has_continuation(worker), "which invalidates the other's continuation")
	assert_equal(_select(worker, 1).value, rescue, "and pass 2 picks the rescue back up")


func test_a_job_restored_to_queued_state_invalidates_a_lower_bucket_continuation() -> void:
	"""The same rule through the state column: CANCELLED back to QUEUED puts a job back on offer."""
	var rescue: int = _make_job(JobsScript.JOB_KIND_KEEP)
	assert_true(_jobs.set_urgency(rescue, JobsScript.URGENCY_RESCUE).ok, "a rescue is queued")
	assert_true(_jobs.set_state(rescue, JobsScript.JOB_STATE_CANCELLED).ok, "then withdrawn")
	var worker: int = _suspend_in_the_cosmetic_bucket()
	assert_true(_jobs.set_state(rescue, JobsScript.JOB_STATE_QUEUED).ok, "and reinstated")
	assert_false(_jobs.has_continuation(worker), "which invalidates the continuation")
	assert_equal(_select(worker, 1).value, rescue, "so pass 2 takes the reinstated rescue")


func test_danger_being_lifted_invalidates_a_lower_bucket_continuation() -> void:
	"""Step 5 is an eligibility gate like any other: a job that stops being dangerous is on offer."""
	var rescue: int = _make_job(JobsScript.JOB_KIND_KEEP)
	assert_true(_jobs.set_urgency(rescue, JobsScript.URGENCY_RESCUE).ok, "a rescue is queued")
	assert_true(_jobs.set_dangerous(rescue, true).ok, "but it is dangerous work")
	var worker: int = _suspend_in_the_cosmetic_bucket()
	assert_equal(_jobs.is_eligible(worker, rescue).error, JobsScript.REFUSE_DANGEROUS_CONSENT,
		"and this resident has given no consent")
	assert_true(_jobs.set_dangerous(rescue, false).ok, "the hazard is cleared")
	assert_false(_jobs.has_continuation(worker), "which invalidates the continuation")
	assert_equal(_select(worker, 1).value, rescue, "and pass 2 takes the now-safe rescue")


func test_the_two_day_reserve_condition_invalidates_a_continuation_below_bucket_two() -> void:
	"""The reserve condition moves every declared food/fuel job up to bucket 2 at once, which is
	an admission into bucket 2 for any resident already scanning below it."""
	var worker: int = _spawn_worker()
	var food: Array[int] = _make_blocked_jobs(40, JobsScript.URGENCY_FOOD_FUEL)
	assert_false(_select(worker, 0).ok, "pass 1 walks them as ordinary work and suspends")
	assert_equal(_jobs.continuation_bucket_of(worker).value, JobsScript.URGENCY_ORDINARY,
		"in bucket 3, because the reserve is fine")
	assert_equal(_jobs.continuation_job_id_of(worker).value, _jobs.job_id_of(food[31]).value,
		"after thirty-two of them")
	_jobs.set_food_reserve_below_two_days(true)
	assert_false(_jobs.has_continuation(worker),
		"stocks falling below two days invalidates a continuation that sits below bucket 2")
	assert_false(_select(worker, 1).ok, "pass 2 finds them all still blocked at step 6")
	assert_equal(_jobs.continuation_bucket_of(worker).value, JobsScript.URGENCY_FOOD_FUEL,
		"but it re-walked bucket 2 from the start rather than resuming in an empty bucket 3")
	assert_equal(_jobs.continuation_job_id_of(worker).value, _jobs.job_id_of(food[31]).value,
		"examining the same first thirty-two, now as bucket 2 work")


func test_a_food_job_is_still_enumerated_as_ordinary_work_while_stocks_are_fine() -> void:
	"""A declared FOOD_FUEL job occupies bucket 2 only under a two-day reserve -- and while it does
	not, it must be enumerated WITH bucket 3, in persistent id order, not fall out of the walk.

	Unreachable is exactly what decision 0023 forbids: unexamined means not evaluated.
	"""
	var worker: int = _spawn_worker()
	var food: int = _make_job(JobsScript.JOB_KIND_KEEP)
	assert_true(_jobs.set_urgency(food, JobsScript.URGENCY_FOOD_FUEL).ok, "it declares bucket 2")
	var ordinary: int = _make_job(JobsScript.JOB_KIND_KEEP)
	assert_false(_jobs.food_reserve_below_two_days(), "but the reserve is fine")
	assert_equal(_jobs.effective_urgency_of(food).value, JobsScript.URGENCY_ORDINARY,
		"so it ranks as ordinary production")
	assert_true(_jobs.job_id_of(food).value < _jobs.job_id_of(ordinary).value,
		"and it is the older of the two candidates")
	assert_equal(_select(worker, 0).value, food,
		"bucket 3 merges the two runs by persistent id, so the older food job wins the tie")
	assert_true(_jobs.destroy_job(ordinary).ok, "with the ordinary job gone")
	assert_equal(_select(worker, 1).value, food,
		"a food job alone with stocks fine is still reached, never enumerated by no bucket at all")


func test_a_job_becoming_available_behind_the_continuation_point_invalidates_it() -> void:
	"""Same bucket, lower persistent id: the scan has already walked past that position, so the
	continuation would step over the job entirely. That is invalidation's other half."""
	var worker: int = _spawn_worker()
	var blocked: Array[int] = _make_blocked_jobs(40, JobsScript.URGENCY_ORDINARY)
	assert_false(_select(worker, 0).ok, "pass 1 suspends after thirty-two blocked jobs")
	assert_equal(_jobs.continuation_job_id_of(worker).value, _jobs.job_id_of(blocked[31]).value,
		"on the thirty-second")
	assert_true(_jobs.job_id_of(blocked[5]).value < _jobs.continuation_job_id_of(worker).value,
		"the sixth job sits behind that point")
	assert_true(_jobs.set_inputs_gate(blocked[5], JobsScript.GATE_SATISFIED).ok,
		"and its inputs arrive")
	assert_false(_jobs.has_continuation(worker), "which invalidates the continuation")
	assert_equal(_select(worker, 1).value, blocked[5],
		"so pass 2 re-walks the bucket from the start and finds it")


func test_the_live_index_is_ordered_by_urgency_bucket_and_then_by_persistent_id() -> void:
	"""The index enumeration walks: a bucket is one contiguous run, oldest job first inside it."""
	var _worker: int = _spawn_worker()
	var ordinary: Array[int] = _make_open_jobs(3, JobsScript.URGENCY_ORDINARY)
	var rescues: Array[int] = _make_open_jobs(2, JobsScript.URGENCY_RESCUE)
	assert_true(_jobs.job_id_of(ordinary[0]).value < _jobs.job_id_of(rescues[0]).value,
		"the rescues were created last, so row order would put them last")
	assert_equal(_jobs.live_job_at(0).value, rescues[0], "but bucket 0 comes first in the index")
	assert_equal(_jobs.live_job_at(1).value, rescues[1], "oldest rescue before newest")
	assert_equal(_jobs.live_job_at(2).value, ordinary[0], "then the bucket 3 run")
	assert_equal(_jobs.live_job_at(3).value, ordinary[1], "in ascending persistent id")
	assert_equal(_jobs.live_job_at(4).value, ordinary[2], "to its end")
	assert_false(_jobs.live_job_at(5).ok, "and the index holds exactly five live jobs")
	assert_true(_jobs.destroy_job(rescues[0]).ok, "destroying out of the middle of a run")
	assert_equal(_jobs.live_job_at(0).value, rescues[1], "closes the gap inside bucket 0")
	assert_equal(_jobs.live_job_at(1).value, ordinary[0], "and pulls the bucket 3 run down with it")
	assert_false(_jobs.live_job_at(4).ok, "leaving four live jobs")


func test_a_resumed_pass_starts_after_the_last_job_it_examined_not_on_it() -> void:
	"""Budget accounting across a resume: re-examining the job the key names would spend one of
	the thirty-two candidate slots twice, and the second suspension point shows whether it did."""
	var worker: int = _spawn_worker()
	var ordinary: Array[int] = _make_blocked_jobs(40, JobsScript.URGENCY_ORDINARY)
	var cosmetic: Array[int] = _make_blocked_jobs(40, JobsScript.URGENCY_COSMETIC)
	assert_false(_select(worker, 0).ok, "pass 1 examines thirty-two ordinary jobs")
	assert_equal(_jobs.continuation_job_id_of(worker).value, _jobs.job_id_of(ordinary[31]).value,
		"and suspends on the thirty-second")
	assert_false(_select(worker, 1).ok, "pass 2 finds nothing either")
	assert_equal(_jobs.continuation_bucket_of(worker).value, JobsScript.URGENCY_COSMETIC,
		"having finished bucket 3 and descended into bucket 4")
	assert_equal(_jobs.continuation_job_id_of(worker).value, _jobs.job_id_of(cosmetic[23]).value,
		"exactly eight ordinary plus twenty-four cosmetic: the thirty-second is not re-examined")


# --- store-wide invariants ------------------------------------------------------------------------

func test_clear_returns_both_stores_to_their_empty_state() -> void:
	"""clear() refills the existing buffers; it must leave no live row and no world input set."""
	var worker: int = _spawn_worker()
	var job: int = _make_job(JobsScript.JOB_KIND_HAUL)
	assert_true(_jobs.assign_worker(worker, job).ok, "a worker binds")
	_jobs.set_food_reserve_below_two_days(true)
	_jobs.clear()
	assert_equal(_jobs.job_count(), 0, "no job rows remain")
	assert_equal(_jobs.agent_count(), 0, "no agent rows remain")
	assert_false(_jobs.is_job_present(job), "the job row is gone")
	assert_false(_jobs.is_agent_present(worker), "the agent row is gone")
	assert_false(_jobs.food_reserve_below_two_days(), "the world input returns to its default")
	assert_true(_jobs.inactive_job_row_is_clear(job), "and the released row holds no residue")


func test_every_reader_refuses_an_absent_row_instead_of_answering_with_a_default() -> void:
	"""A reader that answered 0 for an empty slot would be a sentinel by another name."""
	assert_equal(_jobs.kind_of(0).error, String(JobsScript.REFUSE_JOB_NOT_PRESENT),
		"an empty job row refuses")
	assert_equal(_jobs.kind_of(-1).error, String(JobsScript.REFUSE_INVALID_JOB_SLOT),
		"a negative job slot refuses")
	assert_equal(_jobs.kind_of(JobsScript.JOB_CAPACITY).error,
		String(JobsScript.REFUSE_INVALID_JOB_SLOT), "an out-of-range job slot refuses")
	assert_equal(_jobs.continuation_job_id_of(0).error,
		String(JobsScript.REFUSE_AGENT_NOT_PRESENT), "an empty agent row refuses")
	assert_equal(_jobs.continuation_bucket_of(JobsScript.AGENT_CAPACITY).error,
		String(JobsScript.REFUSE_INVALID_RESIDENT_SLOT),
		"and so does an out-of-range one, rather than answering bucket 0")
	assert_equal(_jobs.stagger_offset_of(JobsScript.AGENT_CAPACITY).error,
		String(JobsScript.REFUSE_INVALID_RESIDENT_SLOT), "an out-of-range resident slot refuses")
	assert_equal(_jobs.ref_of(0), EntityDirectory.NULL_REF, "and an absent row has no reference")
	assert_false(_jobs.live_job_at(0).ok, "an empty live index refuses too")


# --- decision 0017: the coordinator Job -------------------------------------------------------------

func test_a_coordinator_cannot_be_selected_by_a_resident() -> void:
	"""0017: "The coordinator has worker = null, cannot be selected by a resident"."""
	var worker: int = _spawn_worker()
	var coordinator: int = _make_job(JobsScript.JOB_KIND_BUILD)
	assert_true(_jobs.make_coordinator(coordinator).ok, "the job becomes a coordinator")
	var eligible: JobsScript.OpResult = _jobs.is_eligible(worker, coordinator)
	assert_false(eligible.ok, "a coordinator is never an eligible candidate")
	assert_equal(eligible.error, JobsScript.REFUSE_COORDINATOR_JOB,
		"and refuses categorically, not as a failed step")
	var selected: JobsScript.OpResult = _select(worker)
	assert_false(selected.ok, "so a pass over a store holding only it finds nothing")
	assert_equal(selected.error, JobsScript.REFUSE_NO_ELIGIBLE_JOB, "and says so plainly")


func test_a_resident_is_selected_onto_the_member_and_not_the_coordinator() -> void:
	"""The member Job is what a worker takes; the coordinator sits beside it, unselectable."""
	var worker: int = _spawn_worker()
	var coordinator: int = _make_job(JobsScript.JOB_KIND_BUILD, 0, 0, SHARED_CREATED_TICK - 1)
	assert_true(_jobs.make_coordinator(coordinator).ok, "the coordinator exists first")
	var member: int = _make_job(JobsScript.JOB_KIND_BUILD)
	assert_true(_jobs.set_coordinator(member, coordinator).ok, "the member joins its party")
	var selected: JobsScript.OpResult = _select(worker)
	assert_true(selected.ok, "the pass finds a job (error: %s)" % selected.error)
	assert_equal(selected.value, member, "and it is the member, never the older coordinator")


func test_a_coordinator_refuses_a_worker_binding() -> void:
	"""`worker = null` is enforced at the commitment point, with its own refusal code."""
	var worker: int = _spawn_worker()
	var coordinator: int = _make_job(JobsScript.JOB_KIND_FISH)
	assert_true(_jobs.make_coordinator(coordinator).ok, "the job becomes a coordinator")
	var bound: JobsScript.OpResult = _jobs.assign_worker(worker, coordinator)
	assert_false(bound.ok, "no resident may be bound to a coordinator")
	assert_equal(bound.error, JobsScript.REFUSE_COORDINATOR_JOB, "and it says exactly why")
	assert_equal(_jobs.worker_of(coordinator), EntityDirectory.NULL_REF, "its worker stays null")


func test_a_worked_job_cannot_become_a_coordinator() -> void:
	"""The rule runs both ways: a row with a worker is a member's shape, not a coordinator's."""
	var worker: int = _spawn_worker()
	var job: int = _make_job(JobsScript.JOB_KIND_BUILD)
	assert_true(_jobs.assign_worker(worker, job).ok, "the worker binds first")
	var promoted: JobsScript.OpResult = _jobs.make_coordinator(job)
	assert_false(promoted.ok, "a job with a worker cannot become a coordinator")
	assert_equal(promoted.error, JobsScript.REFUSE_JOB_HAS_WORKER, "and it says exactly why")
	assert_false(_jobs.is_coordinator(job), "the flag is not set on a refusal")


func test_a_member_may_not_hold_shared_progress() -> void:
	"""0017: "Their shared-phase remaining_mwu stays zero" -- enforced, not merely intended."""
	var coordinator: int = _make_job(JobsScript.JOB_KIND_BUILD)
	assert_true(_jobs.make_coordinator(coordinator).ok, "the coordinator exists")
	var carrying: JobsScript.OpResult = _jobs.create_job(JobsScript.JOB_KIND_BUILD, 0, 0, 5000, 0)
	assert_true(carrying.ok, "a job carrying work creates normally")
	var linked: JobsScript.OpResult = _jobs.set_coordinator(carrying.value, coordinator)
	assert_false(linked.ok, "but it may not join a party while it carries work")
	assert_equal(linked.error, JobsScript.REFUSE_MEMBER_HOLDS_PROGRESS, "and it says exactly why")
	var member: int = _make_job(JobsScript.JOB_KIND_BUILD)
	assert_true(_jobs.set_coordinator(member, coordinator).ok, "an empty job joins")
	var written: JobsScript.OpResult = _jobs.set_remaining_mwu(member, 1)
	assert_false(written.ok, "and cannot be given work afterwards either")
	assert_equal(_jobs.remaining_mwu_of(member).value, 0, "so its work total stays zero")


func test_shared_progress_lives_in_exactly_one_row() -> void:
	"""Consuming work moves the coordinator's total and touches no member row."""
	var coordinator: int = _make_job(JobsScript.JOB_KIND_BUILD)
	assert_true(_jobs.make_coordinator(coordinator).ok, "the coordinator exists")
	assert_true(_jobs.set_remaining_mwu(coordinator, 5000).ok, "and holds the shared total")
	var first: int = _make_job(JobsScript.JOB_KIND_BUILD)
	var second: int = _make_job(JobsScript.JOB_KIND_BUILD)
	assert_true(_jobs.set_coordinator(first, coordinator).ok, "the first member joins")
	assert_true(_jobs.set_coordinator(second, coordinator).ok, "the second member joins")
	var out: IntMath.IntResult = IntMath.IntResult.new()
	assert_true(_jobs.consume_remaining_mwu_into(coordinator, 160, out), "160 milli-WU is taken")
	assert_equal(out.value, 4840, "from the coordinator's own total")
	assert_equal(_jobs.remaining_mwu_of(first).value, 0, "the first member holds nothing")
	assert_equal(_jobs.remaining_mwu_of(second).value, 0, "nor does the second")


func test_consuming_more_than_a_job_holds_is_refused() -> void:
	"""0017 caps acceptance at min(remaining, sum(potential)); over-consuming is a caller error."""
	var job: int = _make_job(JobsScript.JOB_KIND_BUILD)
	assert_true(_jobs.set_remaining_mwu(job, 100).ok, "the job holds 100 milli-WU")
	var out: IntMath.IntResult = IntMath.IntResult.new()
	assert_false(_jobs.consume_remaining_mwu_into(job, 101, out), "101 is refused")
	assert_equal(out.error, String(JobsScript.REFUSE_MWU_UNDERFLOW), "with its own code")
	assert_equal(_jobs.remaining_mwu_of(job).value, 100, "and nothing was consumed")
	assert_false(_jobs.consume_remaining_mwu_into(job, -1, out), "a negative amount is refused")
	assert_true(_jobs.consume_remaining_mwu_into(job, 100, out), "the exact total is accepted")
	assert_equal(out.value, 0, "leaving nothing outstanding")


func test_member_enumeration_walks_every_member_once() -> void:
	"""The member list is what a party tick walks; it must reach each member exactly once."""
	var coordinator: int = _make_job(JobsScript.JOB_KIND_FISH)
	assert_true(_jobs.make_coordinator(coordinator).ok, "the coordinator exists")
	var out: IntMath.IntResult = IntMath.IntResult.new()
	assert_false(_jobs.first_member_into(coordinator, out), "an empty party has no first member")
	assert_equal(out.error, String(JobsScript.REFUSE_NO_MEMBERS), "and refuses rather than -1")
	var expected: Array[int] = []
	for _index: int in 3:
		var member: int = _make_job(JobsScript.JOB_KIND_FISH)
		assert_true(_jobs.set_coordinator(member, coordinator).ok, "the member joins")
		expected.append(member)
	assert_equal(_jobs.member_count_of(coordinator).value, 3, "the party holds three members")
	var seen: Array[int] = []
	if _jobs.first_member_into(coordinator, out):
		seen.append(out.value)
		while _jobs.next_member_into(seen[seen.size() - 1], out):
			seen.append(out.value)
	seen.sort()
	expected.sort()
	assert_equal(seen, expected, "and the walk reaches each of them exactly once")


func test_a_coordinator_with_members_refuses_destruction() -> void:
	"""Releasing it would leave members pointing at a dead row; 0017 wants the batch to survive."""
	var coordinator: int = _make_job(JobsScript.JOB_KIND_BUILD)
	assert_true(_jobs.make_coordinator(coordinator).ok, "the coordinator exists")
	var member: int = _make_job(JobsScript.JOB_KIND_BUILD)
	assert_true(_jobs.set_coordinator(member, coordinator).ok, "a member joins")
	var destroyed: JobsScript.OpResult = _jobs.destroy_job(coordinator)
	assert_false(destroyed.ok, "the coordinator cannot be destroyed under its party")
	assert_equal(destroyed.error, JobsScript.REFUSE_COORDINATOR_HAS_MEMBERS, "and says why")
	assert_true(_jobs.destroy_job(member).ok, "destroying the member unlinks it first")
	assert_equal(_jobs.member_count_of(coordinator).value, 0, "leaving an empty party")
	assert_true(_jobs.destroy_job(coordinator).ok, "which may then be destroyed")


func test_departure_releases_the_assignment_and_leaves_the_party_intact() -> void:
	"""0017: departure releases that worker's assignment and personal claims ONLY."""
	var worker: int = _spawn_worker()
	var coordinator: int = _make_job(JobsScript.JOB_KIND_FISH)
	assert_true(_jobs.make_coordinator(coordinator).ok, "the coordinator exists")
	assert_true(_jobs.set_remaining_mwu(coordinator, 4000).ok, "holding the shared total")
	var member: int = _make_job(JobsScript.JOB_KIND_FISH)
	assert_true(_jobs.assign_worker(worker, member).ok, "the worker takes the member job")
	assert_true(_jobs.set_coordinator(member, coordinator).ok, "which joins the party")
	assert_true(_jobs.release_worker(worker).ok, "the worker departs")
	assert_equal(_jobs.worker_of(member), EntityDirectory.NULL_REF, "the assignment is released")
	assert_equal(_jobs.remaining_mwu_of(coordinator).value, 4000, "shared progress survives")
	assert_equal(_jobs.member_count_of(coordinator).value, 1,
		"and the member Job stays in the party, which keeps its coordinator")


func test_a_job_may_not_coordinate_itself_or_join_twice() -> void:
	"""Every link rule that would put lifecycle ownership in two places at once is refused."""
	var coordinator: int = _make_job(JobsScript.JOB_KIND_BUILD)
	assert_true(_jobs.make_coordinator(coordinator).ok, "the coordinator exists")
	assert_equal(_jobs.set_coordinator(coordinator, coordinator).error,
		JobsScript.REFUSE_SELF_COORDINATION, "a job may not coordinate itself")
	assert_equal(_jobs.make_coordinator(coordinator).error,
		JobsScript.REFUSE_ALREADY_A_COORDINATOR, "nor be promoted twice")
	var member: int = _make_job(JobsScript.JOB_KIND_BUILD)
	assert_true(_jobs.set_coordinator(member, coordinator).ok, "a member joins once")
	assert_equal(_jobs.set_coordinator(member, coordinator).error, JobsScript.REFUSE_JOB_IS_MEMBER,
		"and may not join again")
	assert_equal(_jobs.make_coordinator(member).error, JobsScript.REFUSE_JOB_IS_MEMBER,
		"nor become a coordinator while it is a member")
	var ordinary: int = _make_job(JobsScript.JOB_KIND_BUILD)
	assert_equal(_jobs.set_coordinator(ordinary, member).error,
		JobsScript.REFUSE_NOT_A_COORDINATOR, "and a member coordinates nobody")


func test_clearing_a_coordinator_link_restores_an_ordinary_job() -> void:
	"""A detached member is an ordinary job again, and may then carry its own work."""
	var coordinator: int = _make_job(JobsScript.JOB_KIND_BUILD)
	assert_true(_jobs.make_coordinator(coordinator).ok, "the coordinator exists")
	var member: int = _make_job(JobsScript.JOB_KIND_BUILD)
	assert_true(_jobs.set_coordinator(member, coordinator).ok, "the member joins")
	assert_equal(_jobs.coordinator_of(member), _jobs.ref_of(coordinator),
		"and references its coordinator by EntityRef")
	assert_true(_jobs.clear_coordinator(member).ok, "the member leaves the party")
	assert_false(_jobs.is_member(member), "it is an ordinary job again")
	assert_equal(_jobs.coordinator_of(member), EntityDirectory.NULL_REF, "with no coordinator")
	assert_true(_jobs.set_remaining_mwu(member, 500).ok, "which may now carry its own work")
	assert_equal(_jobs.member_count_of(coordinator).value, 0, "and the party is empty")


func test_resident_may_work_reports_eligibility_step_one() -> void:
	"""One published implementation of step 1, so `work.gd` cannot carry a disagreeing copy."""
	var worker: int = _spawn_worker()
	assert_true(_jobs.resident_may_work(worker).ok, "a healthy, rested resident may work")
	var rest: IntMath.IntResult = _needs.need_of(worker, NeedsScript.NEED_REST)
	assert_true(_needs.apply_need_event(worker, NeedsScript.NEED_REST, 400 - rest.value).ok,
		"rest falls to 400")
	var collapsed: JobsScript.OpResult = _jobs.resident_may_work(worker)
	assert_false(collapsed.ok, "REQ-SET-015 stops work at rest<=500")
	assert_equal(collapsed.error, JobsScript.REFUSE_REST_COLLAPSED, "with step 1's own code")
	assert_false(_jobs.resident_may_work(JobsScript.AGENT_CAPACITY).ok,
		"and an out-of-range resident refuses rather than answering yes")
