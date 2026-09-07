extends "res://test/framework/test_case.gd"
## Coverage for the GDD §5.2 work-unit model, §5.3 XP, and decision 0017's party acceptance.
##
## EVERY EXPECTED NUMBER HERE IS CLOSED-FORM, not a value read out of the implementation. The
## long-run remainder test compares 777 ticks of accumulation against `floor(777*80*510/1000)`
## computed from §5.2's own formula, so discarding the carry is off by 621 milli-WU rather than
## invisibly consistent. The XP tests assert the tick BEFORE and the tick AFTER the 1000 milli-WU
## threshold, so crediting a fractional contribution early fails on the "before" assertion and
## losing the credit fails on the "after" one.
##
## The party tests each fix the crew size AND every member's work factor in advance, so the
## expected acceptance is arithmetic a reader can check: two base-rate workers accept 160
## milli-WU a tick, four accept 320, and any implementation that multiplied by crew size would
## produce 320 and 1280. That is the per-member inflation decision 0017's coordinator exists to
## prevent, and it is asserted as an exact number rather than as "less than the inflated value".
##
## The leftover tests place the winning worker LAST in the member enumeration order (members are
## head-inserted, so the last one linked is enumerated first), so an implementation that gave the
## leftover milli-WU to the first member it walked -- or to the smallest fraction, or to the
## highest persistent ID -- picks a different worker and fails.

const IntMath := preload("res://scripts/core/int_math.gd")
const EntityDirectory := preload("res://scripts/core/entity_directory.gd")
const NeedsScript := preload("res://scripts/core/needs.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")
const PrioritiesScript := preload("res://scripts/core/priorities.gd")
const ScheduleScript := preload("res://scripts/core/schedule.gd")
const JobsScript := preload("res://scripts/core/jobs.gd")
const WorkScript := preload("res://scripts/core/work.gd")

## GDD §5.3 default schedule: 07:00-12:00 is WORK.
const HOUR_WORK: int = 8

## Need value at which REQ-SET-020's weighted average is exactly 5000, so §5.2's mood factor is
## 1000 and a level-0 worker at full health runs at the base factor of 1000.
const NEEDS_FOR_BASE_RATE: int = 5000
## Need value putting mood below 2000, whose §5.2 mood factor is 600.
const NEEDS_FOR_LOW_MOOD: int = 1500
## Health in the 40-69 band, whose §5.2 health factor is 850.
const HEALTH_MID_BAND: int = 50

## floor(1000*1000*1000/1000000): skill level 0, mood factor 1000, health factor 1000.
const FACTOR_BASE: int = 1000
## floor(1000*600*850/1000000): the low-mood, mid-health factor, deliberately NOT a multiple of
## 12.5, so 80*510/1000 = 40.8 milli-WU a tick and the retained remainder actually matters.
const FACTOR_FRACTIONAL: int = 510
## floor(1000*1100*1000/1000000): the default spawn mood of 7500 at full health.
const FACTOR_DEFAULT_MOOD: int = 1100

var _residents: ResidentsScript = null
var _needs: NeedsScript = null
var _priorities: PrioritiesScript = null
var _schedule: ScheduleScript = null
var _jobs: JobsScript = null
var _work: WorkScript = null


func before_each() -> void:
	"""Build one consistent set of stores: work, jobs and the schedule share the needs rows."""
	_residents = ResidentsScript.new()
	_needs = _residents.needs()
	_priorities = PrioritiesScript.new()
	_schedule = ScheduleScript.new(_needs)
	_jobs = JobsScript.new(_residents, _priorities, _schedule)
	_work = WorkScript.new(_jobs)


func after_each() -> void:
	"""Drop every store so no test inherits another's rows."""
	_work = null
	_jobs = null
	_schedule = null
	_priorities = null
	_needs = null
	_residents = null


# --- fixtures ------------------------------------------------------------------------------------

func _spawn_worker() -> int:
	"""Spawn one mouse with priorities, a resolved WORK hour and a JobAgent row."""
	var spawned: ResidentsScript.OpResult = _residents.spawn(&"mouse")
	assert_true(spawned.ok, "resident spawns (error: %s)" % spawned.error)
	var slot: int = spawned.value
	assert_true(_priorities.spawn(slot).ok, "priorities row spawns")
	var template: IntMath.IntResult = _schedule.default_template_id()
	assert_true(template.ok, "the default schedule template compiles")
	assert_true(_schedule.spawn(slot, template.value).ok, "schedule row spawns")
	assert_true(_schedule.resolve(slot, HOUR_WORK, false).ok, "the WORK hour resolves")
	assert_true(_jobs.spawn_agent(slot).ok, "job agent spawns")
	return slot


func _set_all_needs(resident_slot: int, value: int) -> void:
	"""Move every one of the five needs to `value`, making REQ-SET-020's mood exactly `value`."""
	for need: int in NeedsScript.NEED_COUNT:
		var current: IntMath.IntResult = _needs.need_of(resident_slot, need)
		assert_true(current.ok, "the need reads (error: %s)" % current.error)
		assert_true(_needs.apply_need_event(resident_slot, need, value - current.value).ok,
			"the need moves to the fixture value")


func _base_rate_worker() -> int:
	"""A worker whose §5.2 work factor is exactly 1000: level 0, mood 5000, health 100."""
	var slot: int = _spawn_worker()
	_set_all_needs(slot, NEEDS_FOR_BASE_RATE)
	var factor: IntMath.IntResult = _work.work_factor_of(slot, JobsScript.JOB_KIND_KEEP)
	assert_equal(factor.value, FACTOR_BASE, "the fixture worker runs at the base factor")
	return slot


func _fractional_rate_worker() -> int:
	"""A worker whose §5.2 work factor is 510, so 80*510/1000 leaves a remainder every tick."""
	var slot: int = _spawn_worker()
	_set_all_needs(slot, NEEDS_FOR_LOW_MOOD)
	assert_true(_needs.apply_health_event(slot, HEALTH_MID_BAND - NeedsScript.HEALTH_MAX).ok,
		"health moves into the 40-69 band")
	var factor: IntMath.IntResult = _work.work_factor_of(slot, JobsScript.JOB_KIND_KEEP)
	assert_equal(factor.value, FACTOR_FRACTIONAL, "the fixture worker runs at factor 510")
	return slot


func _worked_job(resident_slot: int, remaining_mwu: int,
		kind: int = JobsScript.JOB_KIND_KEEP) -> int:
	"""Create a job, bind this worker to it, and put it in JOB_STATE_WORK."""
	var created: JobsScript.OpResult = _jobs.create_job(kind, 0, 0, remaining_mwu, 0)
	assert_true(created.ok, "job creates (error: %s)" % created.error)
	var job_slot: int = created.value
	var bound: JobsScript.OpResult = _jobs.assign_worker(resident_slot, job_slot)
	assert_true(bound.ok, "worker binds (error: %s)" % bound.error)
	assert_true(_jobs.set_state(job_slot, JobsScript.JOB_STATE_WORK).ok, "the job enters WORK")
	return job_slot


func _coordinator_job(remaining_mwu: int) -> int:
	"""Create decision 0017's coordinator Job holding the shared work total, in JOB_STATE_WORK."""
	var created: JobsScript.OpResult = _jobs.create_job(JobsScript.JOB_KIND_KEEP, 0, 0,
		remaining_mwu, 0)
	assert_true(created.ok, "coordinator job creates (error: %s)" % created.error)
	var job_slot: int = created.value
	assert_true(_jobs.make_coordinator(job_slot).ok, "the job becomes a coordinator")
	assert_true(_jobs.set_state(job_slot, JobsScript.JOB_STATE_WORK).ok, "the coordinator works")
	return job_slot


func _member_job(coordinator_slot: int, resident_slot: int) -> int:
	"""Create one member Job for a worker, linked to the coordinator, in JOB_STATE_WORK."""
	var created: JobsScript.OpResult = _jobs.create_job(JobsScript.JOB_KIND_KEEP, 0, 0, 0, 0)
	assert_true(created.ok, "member job creates (error: %s)" % created.error)
	var job_slot: int = created.value
	assert_true(_jobs.assign_worker(resident_slot, job_slot).ok, "the member binds its worker")
	assert_true(_jobs.set_coordinator(job_slot, coordinator_slot).ok, "the member joins the party")
	assert_true(_jobs.set_state(job_slot, JobsScript.JOB_STATE_WORK).ok, "the member works")
	return job_slot


func _xp(resident_slot: int) -> int:
	"""This resident's XP in the KEEP skill, which every fixture job uses."""
	var out: IntMath.IntResult = _residents.skill_xp_of(resident_slot, JobsScript.JOB_KIND_KEEP)
	assert_true(out.ok, "skill XP reads (error: %s)" % out.error)
	return out.value


# --- §5.2 the per-tick formula --------------------------------------------------------------------

func test_base_rate_tick_produces_eighty_milli_wu() -> void:
	"""§5.2: 80 milli-WU x factor/1000, which at the base factor of 1000 is exactly 80."""
	var worker: int = _base_rate_worker()
	var job: int = _worked_job(worker, 100000)
	var out: WorkScript.TickResult = _work.tick_solo(job)
	assert_true(out.ok, "the productive tick succeeds (error: %s)" % out.error)
	assert_equal(out.accepted_mwu, 80, "one base-rate tick accepts 80 milli-WU")
	assert_equal(out.remaining_mwu, 99920, "the job's outstanding work falls by exactly that")
	assert_equal(_work.potential_remainder_of(worker).value, 0,
		"80*1000 divides by 1000 exactly, so nothing is carried")


func test_work_factor_is_the_one_needs_publishes() -> void:
	"""The factor is read from needs.work_factor(), never recomputed here or in work.gd."""
	var worker: int = _fractional_rate_worker()
	var expected: IntMath.IntResult = _needs.work_factor(0, NEEDS_FOR_LOW_MOOD, HEALTH_MID_BAND)
	assert_true(expected.ok, "needs.gd computes the factor (error: %s)" % expected.error)
	var actual: IntMath.IntResult = _work.work_factor_of(worker, JobsScript.JOB_KIND_KEEP)
	assert_true(actual.ok, "work.gd reports a factor (error: %s)" % actual.error)
	assert_equal(actual.value, expected.value, "the two agree exactly")


func test_default_mood_worker_uses_the_1100_band() -> void:
	"""A freshly spawned resident sits at need 7500, mood 7500, whose §5.2 factor is 1100."""
	var worker: int = _spawn_worker()
	var factor: IntMath.IntResult = _work.work_factor_of(worker, JobsScript.JOB_KIND_KEEP)
	assert_equal(factor.value, FACTOR_DEFAULT_MOOD, "the 7000-8499 mood band gives 1100")
	var job: int = _worked_job(worker, 100000)
	assert_equal(_work.tick_solo(job).accepted_mwu, 88, "80*1100/1000 is 88 milli-WU a tick")


func test_first_fractional_tick_carries_its_remainder() -> void:
	"""80*510 = 40800 over 1000 releases 40 milli-WU and retains 800, per §5.2."""
	var worker: int = _fractional_rate_worker()
	var job: int = _worked_job(worker, 100000)
	var out: WorkScript.TickResult = _work.tick_solo(job)
	assert_true(out.ok, "the productive tick succeeds (error: %s)" % out.error)
	assert_equal(out.accepted_mwu, 40, "the whole milli-WU released this tick")
	assert_equal(_work.potential_remainder_of(worker).value, 800, "the fraction is retained")


func test_carried_remainder_releases_an_extra_milli_wu() -> void:
	"""Two ticks of 40800 make 81600, which is 81 milli-WU and not 80: the carry is spent."""
	var worker: int = _fractional_rate_worker()
	var job: int = _worked_job(worker, 100000)
	assert_true(_work.tick_solo(job).ok, "the first tick succeeds")
	var second: WorkScript.TickResult = _work.tick_solo(job)
	assert_equal(second.accepted_mwu, 41, "the second tick releases the carried fraction")
	assert_equal(second.remaining_mwu, 100000 - 81, "the job has taken 81 milli-WU in two ticks")
	assert_equal(_work.potential_remainder_of(worker).value, 600, "and retains 600")


func test_long_run_matches_closed_form_arithmetic() -> void:
	"""777 ticks at factor 510 must total floor(777*80*510/1000) = 31701 milli-WU exactly.

	Discarding the carry would give 777*40 = 31080, and rounding each tick up would give 31857;
	this asserts the one value §5.2's remainder rule produces.
	"""
	var ticks: int = 777
	var worker: int = _fractional_rate_worker()
	var job: int = _worked_job(worker, 100000)
	var accepted_total: int = 0
	for _index: int in ticks:
		var out: WorkScript.TickResult = _work.tick_solo(job)
		if not out.ok:
			fail("tick refused mid-run: %s" % out.error)
			return
		accepted_total += out.accepted_mwu
	var expected: int = ticks * WorkScript.BASE_MWU_PER_TICK * FACTOR_FRACTIONAL / 1000
	assert_equal(expected, 31701, "the closed form is the arithmetic §5.2 specifies")
	assert_equal(accepted_total, expected, "777 carried ticks total the closed-form value")
	assert_equal(_jobs.remaining_mwu_of(job).value, 100000 - expected,
		"and the job's outstanding work fell by exactly that")
	assert_equal(_work.potential_remainder_of(worker).value,
		ticks * WorkScript.BASE_MWU_PER_TICK * FACTOR_FRACTIONAL % 1000,
		"the retained fraction is the closed-form remainder")


func test_carry_survives_a_job_switch() -> void:
	"""BAL-NUM-001: the fraction is the worker's, so it crosses a task switch intact."""
	var worker: int = _fractional_rate_worker()
	var first: int = _worked_job(worker, 100000)
	assert_true(_work.tick_solo(first).ok, "the first job takes a tick")
	assert_equal(_work.potential_remainder_of(worker).value, 800, "800 is carried")
	assert_true(_jobs.release_worker(worker).ok, "the worker leaves that job")
	var second: int = _worked_job(worker, 100000)
	var out: WorkScript.TickResult = _work.tick_solo(second)
	assert_equal(out.accepted_mwu, 41, "the carry is spent on the new job, not discarded")
	assert_equal(_work.potential_remainder_of(worker).value, 600, "and the new fraction retained")


# --- §5.3 XP ---------------------------------------------------------------------------------------

func test_fractional_contribution_credits_no_xp() -> void:
	"""§5.3 pays 10 XP per COMPLETED WU; 12 base-rate ticks are 960 milli-WU and complete none."""
	var worker: int = _base_rate_worker()
	var job: int = _worked_job(worker, 100000)
	for _index: int in 12:
		assert_true(_work.tick_solo(job).ok, "the tick succeeds")
	assert_equal(_xp(worker), 0, "960 milli-WU of work has completed no whole WU")
	assert_equal(_work.xp_remainder_of(worker, JobsScript.JOB_KIND_KEEP).value, 960,
		"and all 960 milli-WU are retained as fractional progress")


func test_xp_lands_on_the_tick_the_threshold_is_crossed() -> void:
	"""The thirteenth base-rate tick reaches 1040 milli-WU: one whole WU, 10 XP, 40 retained."""
	var worker: int = _base_rate_worker()
	var job: int = _worked_job(worker, 100000)
	for _index: int in 13:
		assert_true(_work.tick_solo(job).ok, "the tick succeeds")
	assert_equal(_xp(worker), 10, "one completed WU is worth 10 XP")
	assert_equal(_work.xp_remainder_of(worker, JobsScript.JOB_KIND_KEEP).value, 40,
		"the surplus stays as progress toward the next WU")


func test_xp_totals_ten_per_whole_wu_over_a_long_run() -> void:
	"""31701 milli-WU of accepted work is 31 whole WU, so 310 XP, with 701 milli-WU retained."""
	var worker: int = _fractional_rate_worker()
	var job: int = _worked_job(worker, 100000)
	for _index: int in 777:
		assert_true(_work.tick_solo(job).ok, "the tick succeeds")
	assert_equal(_xp(worker), 310, "31 completed WU at 10 XP each")
	assert_equal(_work.xp_remainder_of(worker, JobsScript.JOB_KIND_KEEP).value, 701,
		"the leftover milli-WU are retained, not rounded away")


func test_xp_progress_is_retained_per_skill() -> void:
	"""Decision 0017: fractional XP progress is separate per resident AND per skill."""
	var worker: int = _base_rate_worker()
	var keep_job: int = _worked_job(worker, 100000, JobsScript.JOB_KIND_KEEP)
	for _index: int in 5:
		assert_true(_work.tick_solo(keep_job).ok, "the KEEP tick succeeds")
	assert_true(_jobs.release_worker(worker).ok, "the worker leaves the KEEP job")
	var craft_job: int = _worked_job(worker, 100000, JobsScript.JOB_KIND_CRAFT)
	for _index: int in 3:
		assert_true(_work.tick_solo(craft_job).ok, "the CRAFT tick succeeds")
	assert_equal(_work.xp_remainder_of(worker, JobsScript.JOB_KIND_KEEP).value, 400,
		"the KEEP fraction is untouched by crafting")
	assert_equal(_work.xp_remainder_of(worker, JobsScript.JOB_KIND_CRAFT).value, 240,
		"and the CRAFT fraction accrues on its own")


func test_xp_is_credited_only_from_accepted_work() -> void:
	"""Decision 0017: a finishing tick credits the accepted share, never the full potential."""
	var first: int = _base_rate_worker()
	var second: int = _base_rate_worker()
	var coordinator: int = _coordinator_job(10)
	var _first_member: int = _member_job(coordinator, first)
	var _second_member: int = _member_job(coordinator, second)
	var out: WorkScript.TickResult = _work.tick_party(coordinator)
	assert_true(out.ok, "the finishing tick succeeds (error: %s)" % out.error)
	assert_equal(out.accepted_mwu, 10, "acceptance is capped by the outstanding 10 milli-WU")
	assert_equal(_work.xp_remainder_of(first, JobsScript.JOB_KIND_KEEP).value, 5,
		"each worker banks their accepted 5 milli-WU, not their potential 80")
	assert_equal(_work.xp_remainder_of(second, JobsScript.JOB_KIND_KEEP).value, 5,
		"and so does the second")


# --- §5.2 what is not a productive tick -------------------------------------------------------------

func test_a_travelling_job_produces_nothing() -> void:
	"""§5.2: travel does not produce job output; JOB_STATE_TRAVEL is refused, not worked."""
	var worker: int = _base_rate_worker()
	var job: int = _worked_job(worker, 100000)
	assert_true(_jobs.set_state(job, JobsScript.JOB_STATE_TRAVEL).ok, "the job starts travelling")
	var out: WorkScript.TickResult = _work.tick_solo(job)
	assert_false(out.ok, "a travelling job takes no work")
	assert_equal(out.error, WorkScript.REFUSE_JOB_NOT_WORKING, "and says exactly why")
	assert_equal(_jobs.remaining_mwu_of(job).value, 100000, "its work total is untouched")


func test_a_collapsed_worker_produces_nothing() -> void:
	"""REQ-SET-015 cancels ordinary work at rest<=500, on the productive tick as at assignment."""
	var worker: int = _base_rate_worker()
	var job: int = _worked_job(worker, 100000)
	assert_true(_needs.apply_need_event(worker, NeedsScript.NEED_REST,
		400 - NEEDS_FOR_BASE_RATE).ok, "rest falls to 400")
	var out: WorkScript.TickResult = _work.tick_solo(job)
	assert_false(out.ok, "a collapsed worker produces no job output")
	assert_equal(_jobs.remaining_mwu_of(job).value, 100000, "the job's work total is untouched")


func test_a_dead_worker_produces_nothing() -> void:
	"""§5.2's DEAD precedence removes the worker from production entirely."""
	var worker: int = _base_rate_worker()
	var job: int = _worked_job(worker, 100000)
	assert_true(_needs.apply_health_event(worker, -NeedsScript.HEALTH_MAX).ok, "the worker dies")
	var out: WorkScript.TickResult = _work.tick_solo(job)
	assert_false(out.ok, "a dead worker produces no job output")
	assert_equal(_work.potential_remainder_of(worker).value, 0, "and no carry was consumed")


func test_a_job_without_a_worker_produces_nothing() -> void:
	"""Work comes from a bound worker; an unworked row in WORK state produces nothing."""
	var created: JobsScript.OpResult = _jobs.create_job(JobsScript.JOB_KIND_KEEP, 0, 0, 5000, 0)
	assert_true(created.ok, "the job creates")
	assert_true(_jobs.set_state(created.value, JobsScript.JOB_STATE_WORK).ok, "it enters WORK")
	var out: WorkScript.TickResult = _work.tick_solo(created.value)
	assert_false(out.ok, "no worker means no output")
	assert_equal(out.error, WorkScript.REFUSE_JOB_HAS_NO_WORKER, "and says exactly why")


func test_a_finished_job_refuses_further_work() -> void:
	"""A job with no outstanding milli-WU refuses rather than accepting zero-value ticks."""
	var worker: int = _base_rate_worker()
	var job: int = _worked_job(worker, 80)
	var first: WorkScript.TickResult = _work.tick_solo(job)
	assert_true(first.completed, "the single tick finishes the job")
	var second: WorkScript.TickResult = _work.tick_solo(job)
	assert_false(second.ok, "a completed job takes no second tick")
	assert_equal(second.error, WorkScript.REFUSE_JOB_NOT_WORKING, "because it is no longer WORK")


# --- decision 0017: the acceptance example ------------------------------------------------------------

func test_decision_0017_acceptance_example() -> void:
	"""The golden case: 120 WU, two base-rate workers, 750 ticks, 60 WU each, ONE completion."""
	var first: int = _base_rate_worker()
	var second: int = _base_rate_worker()
	var coordinator: int = _coordinator_job(120 * 1000)
	var _first_member: int = _member_job(coordinator, first)
	var _second_member: int = _member_job(coordinator, second)
	var ticks: int = 0
	var completions: int = 0
	while ticks < 800:
		var out: WorkScript.TickResult = _work.tick_party(coordinator)
		if not out.ok:
			break
		ticks += 1
		if out.completed:
			completions += 1
	assert_equal(ticks, 750, "80 + 80 milli-WU a tick finishes 120 WU after 750 productive ticks")
	assert_equal(completions, 1, "and produces exactly one completion")
	assert_equal(_xp(first), 600, "60 WU credited to the first worker at 10 XP each")
	assert_equal(_xp(second), 600, "60 WU credited to the second worker at 10 XP each")
	assert_equal(_jobs.remaining_mwu_of(coordinator).value, 0, "the shared total is exhausted")


func test_party_output_is_not_multiplied_by_crew_size() -> void:
	"""The failure 0017's coordinator exists to prevent: four known workers accept 320, not 1280."""
	var coordinator: int = _coordinator_job(100000)
	var members: Array[int] = []
	for _index: int in 4:
		var worker: int = _base_rate_worker()
		members.append(_member_job(coordinator, worker))
	var out: WorkScript.TickResult = _work.tick_party(coordinator)
	assert_true(out.ok, "the party tick succeeds (error: %s)" % out.error)
	assert_equal(out.contributor_count, 4, "all four workers contributed")
	assert_equal(out.accepted_mwu, 320, "four base-rate workers accept 4*80 milli-WU, not 4*320")
	assert_equal(out.remaining_mwu, 100000 - 320, "and the shared total falls by exactly that")
	for member: int in members:
		assert_equal(_jobs.remaining_mwu_of(member).value, 0,
			"no member holds a copy of the shared progress")


func test_party_progress_accumulates_only_on_the_coordinator() -> void:
	"""Ten ticks of a four-worker party is 3200 milli-WU in one row, not 3200 in each of five."""
	var coordinator: int = _coordinator_job(100000)
	for _index: int in 4:
		var _member: int = _member_job(coordinator, _base_rate_worker())
	for _tick: int in 10:
		assert_true(_work.tick_party(coordinator).ok, "the party tick succeeds")
	assert_equal(_jobs.remaining_mwu_of(coordinator).value, 100000 - 3200,
		"the coordinator holds the sole authoritative remaining_mwu")


func test_party_of_one_advances_at_one_worker_rate() -> void:
	"""0017: a shared-capable activity keeps its coordinator even when down to one worker."""
	var coordinator: int = _coordinator_job(100000)
	var _member: int = _member_job(coordinator, _base_rate_worker())
	var out: WorkScript.TickResult = _work.tick_party(coordinator)
	assert_true(out.ok, "the single-member party ticks (error: %s)" % out.error)
	assert_equal(out.accepted_mwu, 80, "one base-rate worker accepts 80 milli-WU")
	assert_equal(out.contributor_count, 1, "and the crew is one")


# --- decision 0017: the finishing-tick split ----------------------------------------------------------

func test_leftover_goes_to_the_largest_fractional_remainder() -> void:
	"""100 milli-WU across potentials 80, 88 and 40: floors 38/42/19, leftover to fraction 96.

	Members are head-inserted, so the LAST one linked is walked FIRST. The base-rate worker is
	linked first and therefore walked last, so an implementation that handed the leftover
	milli-WU to the first member it walked would give it to the 40 worker, and one that took the
	SMALLEST fraction would also give it to the 40 worker. Both fail this assertion.
	"""
	var slow: int = _fractional_rate_worker()
	var fast: int = _spawn_worker()
	var base: int = _base_rate_worker()
	var coordinator: int = _coordinator_job(100)
	var _base_member: int = _member_job(coordinator, base)
	var _fast_member: int = _member_job(coordinator, fast)
	var _slow_member: int = _member_job(coordinator, slow)
	var out: WorkScript.TickResult = _work.tick_party(coordinator)
	assert_true(out.ok, "the finishing tick succeeds (error: %s)" % out.error)
	assert_equal(out.accepted_mwu, 100, "acceptance is the outstanding 100 milli-WU")
	assert_equal(_work.xp_remainder_of(base, JobsScript.JOB_KIND_KEEP).value, 39,
		"fraction 96 is the largest, so the base-rate worker takes the leftover milli-WU")
	assert_equal(_work.xp_remainder_of(fast, JobsScript.JOB_KIND_KEEP).value, 42,
		"the 88 worker keeps its floored share")
	assert_equal(_work.xp_remainder_of(slow, JobsScript.JOB_KIND_KEEP).value, 19,
		"and the 40 worker keeps its floored share")


func test_leftover_ties_break_by_ascending_persistent_id() -> void:
	"""Two equal potentials tie on fraction 80; 0017 gives the milli-WU to the lower ID.

	The lower-ID worker is linked first and therefore walked LAST, so neither "first walked" nor
	"highest ID" produces this result.
	"""
	var low: int = _base_rate_worker()
	var high: int = _base_rate_worker()
	var slow: int = _fractional_rate_worker()
	var low_id: IntMath.IntResult = _jobs.agent_persistent_id_of(low)
	var high_id: IntMath.IntResult = _jobs.agent_persistent_id_of(high)
	assert_true(low_id.value < high_id.value, "the first-spawned worker holds the lower ID")
	var coordinator: int = _coordinator_job(101)
	var _low_member: int = _member_job(coordinator, low)
	var _high_member: int = _member_job(coordinator, high)
	var _slow_member: int = _member_job(coordinator, slow)
	assert_true(_work.tick_party(coordinator).ok, "the finishing tick succeeds")
	assert_equal(_work.xp_remainder_of(low, JobsScript.JOB_KIND_KEEP).value, 41,
		"the lower persistent ID wins the tie")
	assert_equal(_work.xp_remainder_of(high, JobsScript.JOB_KIND_KEEP).value, 40,
		"and the higher persistent ID does not")
	assert_equal(_work.xp_remainder_of(slow, JobsScript.JOB_KIND_KEEP).value, 20,
		"the third worker's floored share is unaffected by the tie")


func test_finishing_tick_allocates_exactly_the_accepted_total() -> void:
	"""Conservation: the shares handed out sum to accepted_total, never more and never less."""
	var low: int = _base_rate_worker()
	var high: int = _base_rate_worker()
	var slow: int = _fractional_rate_worker()
	var coordinator: int = _coordinator_job(101)
	for worker: int in [low, high, slow]:
		var _member: int = _member_job(coordinator, worker)
	var out: WorkScript.TickResult = _work.tick_party(coordinator)
	var distributed: int = _work.xp_remainder_of(low, JobsScript.JOB_KIND_KEEP).value \
		+ _work.xp_remainder_of(high, JobsScript.JOB_KIND_KEEP).value \
		+ _work.xp_remainder_of(slow, JobsScript.JOB_KIND_KEEP).value
	assert_equal(out.accepted_mwu, 101, "the whole outstanding total is accepted")
	assert_equal(distributed, 101, "and every milli-WU of it reaches exactly one worker")


# --- decision 0017: coordinator lifecycle ---------------------------------------------------------------

func test_only_the_coordinator_records_completion() -> void:
	"""This amends ARCH-JOB-005: members stay in WORK, the coordinator alone goes COMPLETE."""
	var coordinator: int = _coordinator_job(160)
	var first_member: int = _member_job(coordinator, _base_rate_worker())
	var second_member: int = _member_job(coordinator, _base_rate_worker())
	var out: WorkScript.TickResult = _work.tick_party(coordinator)
	assert_true(out.completed, "the tick finishes the shared activity")
	assert_equal(_jobs.state_of(coordinator).value, JobsScript.JOB_STATE_COMPLETE,
		"the coordinator records the completion")
	assert_equal(_jobs.state_of(first_member).value, JobsScript.JOB_STATE_WORK,
		"the first member records none")
	assert_equal(_jobs.state_of(second_member).value, JobsScript.JOB_STATE_WORK,
		"nor does the second")


func test_a_completed_party_produces_no_second_completion() -> void:
	""""Produces one completion": a further tick refuses instead of finishing twice."""
	var coordinator: int = _coordinator_job(160)
	var _first: int = _member_job(coordinator, _base_rate_worker())
	var _second: int = _member_job(coordinator, _base_rate_worker())
	assert_true(_work.tick_party(coordinator).completed, "the first tick completes it")
	var again: WorkScript.TickResult = _work.tick_party(coordinator)
	assert_false(again.ok, "a completed coordinator takes no further work")
	assert_false(again.completed, "and reports no second completion")


func test_worker_departure_preserves_shared_progress() -> void:
	"""0017: departure releases the assignment and personal claims only; progress survives."""
	var staying: int = _base_rate_worker()
	var leaving: int = _base_rate_worker()
	var coordinator: int = _coordinator_job(100000)
	var _stay_member: int = _member_job(coordinator, staying)
	var _leave_member: int = _member_job(coordinator, leaving)
	assert_true(_work.tick_party(coordinator).ok, "the pair works one tick")
	assert_true(_jobs.release_worker(leaving).ok, "one worker departs")
	assert_equal(_jobs.remaining_mwu_of(coordinator).value, 100000 - 160,
		"the shared progress made before the departure survives it")
	var out: WorkScript.TickResult = _work.tick_party(coordinator)
	assert_true(out.ok, "the remaining worker carries on (error: %s)" % out.error)
	assert_equal(out.contributor_count, 1, "with the departed member contributing nothing")
	assert_equal(out.accepted_mwu, 80, "so the party advances at one worker's rate")


func test_a_party_with_no_contributing_worker_produces_nothing() -> void:
	"""Passive waiting never accelerates with crew size, and an idle crew produces zero."""
	var worker: int = _base_rate_worker()
	var coordinator: int = _coordinator_job(100000)
	var _member: int = _member_job(coordinator, worker)
	assert_true(_jobs.release_worker(worker).ok, "the only worker departs")
	var out: WorkScript.TickResult = _work.tick_party(coordinator)
	assert_false(out.ok, "the coordinator alone contributes no work")
	assert_equal(out.error, WorkScript.REFUSE_NO_CONTRIBUTORS, "and says exactly why")
	assert_equal(_jobs.remaining_mwu_of(coordinator).value, 100000, "nothing was consumed")


func test_tick_solo_refuses_a_coordinator_and_a_member() -> void:
	"""Shared progress is ticked through its coordinator; neither role is a solo job."""
	var coordinator: int = _coordinator_job(100000)
	var member: int = _member_job(coordinator, _base_rate_worker())
	var as_solo: WorkScript.TickResult = _work.tick_solo(coordinator)
	assert_false(as_solo.ok, "a coordinator is not a solo job")
	assert_equal(as_solo.error, WorkScript.REFUSE_JOB_IS_COORDINATOR, "and says exactly why")
	var member_solo: WorkScript.TickResult = _work.tick_solo(member)
	assert_false(member_solo.ok, "nor is a member")
	assert_equal(member_solo.error, WorkScript.REFUSE_JOB_IS_MEMBER, "and says exactly why")


func test_tick_party_refuses_an_ordinary_job() -> void:
	"""A job that is not a coordinator owns no shared progress and cannot be party-ticked."""
	var worker: int = _base_rate_worker()
	var job: int = _worked_job(worker, 100000)
	var out: WorkScript.TickResult = _work.tick_party(job)
	assert_false(out.ok, "an ordinary job is not a coordinator")
	assert_equal(out.error, WorkScript.REFUSE_NOT_A_COORDINATOR, "and says exactly why")


# --- inputs and refusals ------------------------------------------------------------------------------

func test_memory_total_moves_the_work_factor() -> void:
	"""REQ-SET-020's memory term is an explicit input, defaulting to 0, and it reaches mood."""
	var worker: int = _base_rate_worker()
	assert_equal(_work.memory_total_of(worker).value, 0, "the honest default is zero")
	assert_true(_work.set_memory_total(worker, 3000).ok, "a positive memory total is accepted")
	assert_equal(_work.memory_total_of(worker).value, 3000, "and is stored")
	var factor: IntMath.IntResult = _work.work_factor_of(worker, JobsScript.JOB_KIND_KEEP)
	assert_equal(factor.value, FACTOR_DEFAULT_MOOD,
		"mood 5000 plus 3000 lands in the 7000-8499 band, whose factor is 1100")


func test_reserved_skill_index_is_refused() -> void:
	"""§5.1 fixes RESERVED_3 at XP and level 0, so no accumulator addresses it."""
	var worker: int = _base_rate_worker()
	var remainder: IntMath.IntResult = _work.xp_remainder_of(worker,
		JobsScript.JOB_KIND_RESERVED_INDEX)
	assert_false(remainder.ok, "the reserved index has no XP progress")
	var factor: IntMath.IntResult = _work.work_factor_of(worker,
		JobsScript.JOB_KIND_RESERVED_INDEX)
	assert_false(factor.ok, "and no work factor")


func test_out_of_range_addresses_refuse_rather_than_return_a_number() -> void:
	"""No sentinel: an invalid address refuses explicitly and carries zero."""
	var high: IntMath.IntResult = _work.potential_remainder_of(WorkScript.RESIDENT_CAPACITY)
	assert_false(high.ok, "a slot past capacity refuses")
	assert_equal(high.value, 0, "and carries no plausible-looking number")
	var negative: WorkScript.OpResult = _work.set_memory_total(-1, 100)
	assert_false(negative.ok, "a negative slot refuses")
	assert_equal(negative.error, WorkScript.REFUSE_INVALID_RESIDENT_SLOT, "with its own code")


func test_clear_returns_every_carry_to_zero() -> void:
	"""clear() refills the existing buffers; two logically identical worlds hash identically."""
	var worker: int = _fractional_rate_worker()
	var job: int = _worked_job(worker, 100000)
	assert_true(_work.tick_solo(job).ok, "a tick leaves a carry behind")
	assert_true(_work.set_memory_total(worker, -500).ok, "and an input is set")
	_work.clear()
	assert_equal(_work.potential_remainder_of(worker).value, 0, "the work carry is cleared")
	assert_equal(_work.xp_remainder_of(worker, JobsScript.JOB_KIND_KEEP).value, 0,
		"the XP progress is cleared")
	assert_equal(_work.memory_total_of(worker).value, 0, "and the memory input returns to zero")
