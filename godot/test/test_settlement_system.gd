extends "res://test/framework/test_case.gd"
## Coverage for the settlement simulation loop: composition, the per-tick stage order, the
## REQ-SET-007 daily boundary, and the clock binding that drives all of it.
##
## ARCH-MIG-006 step 6, wiring half. The core modules each have their own suite; this one covers
## what SettlementSystem adds -- that the running game CALLS them, once per completed fixed tick,
## in `systems_architecture.md` §5's order, and that a paused clock calls them not at all.
##
## INSTANCES ARE NEVER ADDED TO THE SCENE TREE. `_ready()` binds the system to the GameManager
## AUTOLOAD, and a test instance that entered the tree would hijack the autoload's binding out
## from under the running project. Every instance here is built with `.new()`, driven directly,
## and freed; the one binding test builds its OWN GameManager and binds by hand.
##
## The §5.2 integration arithmetic, the §5.3 selection rules and the §5.2 work formula are each
## restated here from the GDD rather than read back out of the modules under test.

const SettlementSystemScript := preload("res://scripts/systems/settlement_system.gd")
const GameManagerScript := preload("res://scripts/systems/game_manager.gd")
const SimClockScript := preload("res://scripts/core/sim_clock.gd")
const NeedsScript := preload("res://scripts/core/needs.gd")
const ScheduleScript := preload("res://scripts/core/schedule.gd")
const JobsScript := preload("res://scripts/core/jobs.gd")
const IntMath := preload("res://scripts/core/int_math.gd")

## GDD §5.1: the starting settlement is twelve residents.
const COHORT_SIZE: int = 12

## GDD §5.2 hunger decay, restated: 250 need-points/game-hour in milli-points, scaled by the
## size multipliers 1.00 / 1.20 / 1.60. Indexed by size class, in milli-points per game hour.
const HUNGER_RATE_MILLI_PER_HOUR: Array[int] = [250000, 300000, 400000]
## §5.2's rest decay while awake, 375 points/hour, is size-independent.
const REST_RATE_MILLI_PER_HOUR: int = 375000
## The §5.2 denominator: 750 ticks/hour x 1000 milli-points.
const NEED_DENOMINATOR: int = 750000
## §5.2 spawn value for every need.
const INITIAL_NEED: int = 7500

## GDD §5.2 health bounds, restated: health is a whole integer 0-100 and a resident spawns full.
const HEALTH_MIN: int = 0
const HEALTH_MAX: int = 100

## GDD §7.1: "10 small and 2 medium residents consume 74400 NP/day".
const COHORT_DEMAND_NP: int = 74400
## The same cohort under REQ-SET-143's x1.20: 10 x floor(6000x1.0x1.2) + 2 x floor(6000x1.2x1.2).
const COHORT_WINTER_DEMAND_NP: int = 89280
## Index of winter in the calendar's season order, restated from GDD §5.1's spring/summer/
## autumn/winter year.
const SEASON_SPRING: int = 0
const SEASON_WINTER: int = 3

## §5.2 "Each work tick produces 80 milli-WU x factor/1000", with the factor clamped to 300-1800.
const BASE_MWU_PER_TICK: int = 80
const WORK_FACTOR_DENOMINATOR: int = 1000
const MIN_POTENTIAL_MWU: int = 24
const MAX_POTENTIAL_MWU: int = 144
## §5.3 "XP is 10 per completed productive WU"; a WU is 1000 milli-WU.
const XP_PER_WU: int = 10
const MILLI_WU_PER_WU: int = 1000

## A work total no bounded test run can exhaust, so a job never completes mid-assertion.
const LARGE_JOB_MWU: int = 1000000

## Host frame of 1/30 real second: exactly one tick at 1x with no remainder.
const TICK_FRAME_USEC: int = 33334
## Bounded sample for the tick-cost measurement below.
const MEASURED_TICKS: int = 300
## A very loose ceiling. ARCH-PERF-001's real gate is p99 <= 2000 us at 256 residents on the
## Windows floor; this is twelve residents in a debug editor binary, so the number this test
## PRINTS is the useful output and the assertion only catches a collapse.
const TICK_CEILING_USEC: int = 2000

var _settlement: SettlementSystemScript = null
var _game: GameManagerScript = null
var _boundaries: Array[int] = []


func before_each() -> void:
	"""Build a settlement outside the scene tree, so `_ready()` never binds the autoload clock."""
	_settlement = SettlementSystemScript.new()
	_boundaries = []


func after_each() -> void:
	"""Free the nodes this test built."""
	if _settlement != null:
		_settlement.free()
		_settlement = null
	if _game != null:
		_game.free()
		_game = null


func _populated() -> SettlementSystemScript:
	"""A settlement holding the GDD §5.1 starting cohort."""
	_settlement.create_initial_settlement()
	return _settlement


func _run_ticks(first_tick: int, count: int) -> void:
	"""Run `count` consecutive settlement ticks starting at `first_tick`."""
	for offset: int in count:
		_settlement.run_tick(first_tick + offset)


func _quiet_offset() -> int:
	"""A 30-tick window offset on which NO resident of the cohort is due to reevaluate.

	§5.3 staggers by persistent ID mod 30 and the cohort is twelve residents, so most offsets in
	the window belong to nobody. Picking one by hand would silently land on another resident.
	"""
	var taken: Array[int] = []
	for slot: int in COHORT_SIZE:
		taken.append(_settlement.jobs().stagger_offset_of(slot).value)
	for offset: int in JobsScript.STAGGER_MODULUS:
		if not taken.has(offset):
			return offset
	fail("no offset in the 30-tick window is free of a resident")
	return 0


func _expected_decay(rate_milli_per_hour: int, ticks: int) -> int:
	"""GDD §5.2's released whole points over `ticks` at a constant rate: trunc(T*R/750000)."""
	return ticks * rate_milli_per_hour / NEED_DENOMINATOR


# --- composition and lifecycle ------------------------------------------------------------------

func test_a_fresh_settlement_is_empty() -> void:
	"""Before creation there is no population, no job and no measured tick."""
	assert_equal(_settlement.population(), 0, "no resident rows")
	assert_equal(_settlement.living_count(), 0, "no living residents")
	assert_equal(_settlement.job_queue_length(), 0, "no jobs")
	assert_equal(_settlement.ticks_run(), 0, "no ticks run")
	assert_false(_settlement.mean_tick_usec().ok, "a mean over zero ticks is refused")


func test_creation_spawns_the_gdd_cohort_with_every_component() -> void:
	"""Creation spawns twelve residents and gives each a needs, priorities, schedule and agent row."""
	assert_true(_settlement.create_initial_settlement(), "the cohort was created")
	assert_equal(_settlement.population(), COHORT_SIZE, "twelve resident rows")
	assert_equal(_settlement.living_count(), COHORT_SIZE, "twelve living residents")
	assert_equal(_settlement.needs().present_count(), COHORT_SIZE, "twelve needs rows")
	assert_equal(_settlement.priorities().present_count(), COHORT_SIZE, "twelve priorities rows")
	assert_equal(_settlement.schedule().present_count(), COHORT_SIZE, "twelve schedule rows")
	assert_equal(_settlement.jobs().agent_count(), COHORT_SIZE, "twelve job agent rows")


func test_the_reservation_pool_is_owned_and_empty() -> void:
	"""The pool is composed with the settlement and holds nothing: no job exists to claim inputs."""
	_populated()
	_run_ticks(1, 60)
	var pool: RefCounted = _settlement.reservations()
	assert_equal(pool.active_row_count(), 0, "no reservation row is active")
	assert_equal(pool.free_row_count(), pool.row_capacity(), "every row is free")
	assert_true(pool.row_capacity() > 0, "the pool was allocated")


func test_a_second_creation_is_refused_and_changes_nothing() -> void:
	"""Creating twice is refused explicitly and leaves the first settlement intact."""
	_populated()
	assert_false(_settlement.create_initial_settlement(), "the second creation is refused")
	assert_equal(_settlement.last_refusal(), &"SETTLEMENT_NOT_EMPTY", "the reason is named")
	assert_equal(_settlement.population(), COHORT_SIZE, "the first cohort is untouched")
	assert_equal(_settlement.jobs().agent_count(), COHORT_SIZE, "its agent rows survive")


func test_reset_empties_every_store_and_the_directory() -> void:
	"""reset() returns every store, the shared directory and every counter to empty."""
	_populated()
	_run_ticks(1, 5)
	_settlement.reset()
	assert_equal(_settlement.population(), 0, "no resident rows")
	assert_equal(_settlement.needs().present_count(), 0, "no needs rows")
	assert_equal(_settlement.schedule().present_count(), 0, "no schedule rows")
	assert_equal(_settlement.jobs().agent_count(), 0, "no agent rows")
	assert_equal(_settlement.directory().total_live_count(), 0, "the directory is empty")
	assert_equal(_settlement.ticks_run(), 0, "the tick counter is cleared")


func test_a_settlement_can_be_created_again_after_a_reset() -> void:
	"""A reset settlement accepts a fresh cohort, which is what a scene reload does."""
	_populated()
	_settlement.reset()
	assert_true(_settlement.create_initial_settlement(), "the second cohort was created")
	assert_equal(_settlement.population(), COHORT_SIZE, "twelve resident rows again")


# --- ARCH-SYS-003 interval integration ----------------------------------------------------------

func test_a_tick_integrates_needs_by_the_exact_gdd_remainder_rule() -> void:
	"""After T ticks hunger and rest have fallen by exactly trunc(T*R/750000) points.

	The closed form is restated from GDD §5.2 here; nothing reads a rate back out of needs.gd.
	"""
	_populated()
	var size: int = _settlement.residents().size_class_of(0).value
	var ticks: int = 2251
	_run_ticks(1, ticks)
	var hunger: int = _settlement.needs().need_of(0, NeedsScript.NEED_HUNGER).value
	var rest: int = _settlement.needs().need_of(0, NeedsScript.NEED_REST).value
	assert_equal(hunger, INITIAL_NEED - _expected_decay(HUNGER_RATE_MILLI_PER_HOUR[size], ticks),
		"hunger fell by the exact integrated amount")
	assert_equal(rest, INITIAL_NEED - _expected_decay(REST_RATE_MILLI_PER_HOUR, ticks),
		"rest fell by the exact integrated amount")
	assert_equal(_settlement.ticks_run(), ticks, "every tick was counted")
	assert_equal(_settlement.refused_tick_count(), 0, "no tick refused")


func test_needs_do_not_move_without_a_tick() -> void:
	"""Nothing decays on its own: the loop runs only when a tick is run."""
	_populated()
	assert_equal(_settlement.needs().need_of(0, NeedsScript.NEED_HUNGER).value, INITIAL_NEED,
		"hunger is at its spawn value")
	assert_equal(_settlement.ticks_run(), 0, "no tick has run")


func test_a_negative_tick_index_is_refused_and_runs_no_stage() -> void:
	"""A negative tick index refuses explicitly rather than integrating anything."""
	_populated()
	assert_false(_settlement.run_tick(-1), "the tick is refused")
	assert_equal(_settlement.last_refusal(), &"INVALID_TICK", "the reason is named")
	assert_equal(_settlement.ticks_run(), 0, "no tick was counted")
	assert_equal(_settlement.needs().need_of(0, NeedsScript.NEED_HUNGER).value, INITIAL_NEED,
		"needs were not integrated")


# --- ARCH-SYS-008 activity resolution -----------------------------------------------------------

func test_the_activity_is_resolved_on_the_residents_own_staggered_tick() -> void:
	"""§5.3's 30-tick stagger decides when a resident's activity resolves; not before, then yes."""
	_populated()
	var stagger: int = _settlement.jobs().stagger_offset_of(0).value
	_settlement.run_tick(30 + _quiet_offset())
	assert_false(_settlement.schedule().current_activity_of(0).ok,
		"an unresolved row refuses rather than answering a default")
	_settlement.run_tick(30 + stagger)
	var resolved: IntMath.IntResult = _settlement.schedule().current_activity_of(0)
	assert_true(resolved.ok, "the resident's own staggered tick resolved the activity")
	assert_equal(resolved.value, ScheduleScript.ACTIVITY_ANYTHING,
		"06:00 is the §5.3 default template's ANYTHING hour")


func test_the_resolved_activity_follows_the_schedule_template_hour() -> void:
	"""A tick inside the 07:00-12:00 work block resolves to WORK, the §5.3 default template."""
	_populated()
	var stagger: int = _settlement.jobs().stagger_offset_of(0).value
	# Tick 3000 is 10:00 under the offset calendar; walk up to this resident's own stagger.
	var work_tick: int = 3000 + (stagger - 3000 % 30 + 30) % 30
	_settlement.run_tick(work_tick)
	assert_equal(_settlement.schedule().current_activity_of(0).value,
		ScheduleScript.ACTIVITY_WORK, "a mid-morning hour resolves to WORK")


# --- ARCH-SYS-010 job selection -----------------------------------------------------------------

func test_the_job_queue_is_empty_and_nobody_is_assigned() -> void:
	"""With no system creating jobs, a full stagger window assigns nobody. This is honest, not idle."""
	_populated()
	_run_ticks(1, 60)
	assert_equal(_settlement.job_queue_length(), 0, "no job exists to be selected")
	assert_equal(_settlement.assignment_count(), 0, "no worker was bound")
	assert_equal(_settlement.refused_assignment_count(), 0, "no nomination was made either")


func test_a_queued_job_is_selected_on_the_residents_staggered_tick() -> void:
	"""The selection stage really runs: a queued job is nominated and bound at the §5.3 cadence."""
	_populated()
	var created: JobsScript.OpResult = _settlement.jobs().create_job(
		JobsScript.JOB_KIND_HAUL, 1, 0, LARGE_JOB_MWU, 0)
	assert_true(created.ok, "the job was created")
	var stagger: int = _settlement.jobs().stagger_offset_of(0).value
	_settlement.run_tick(30 + _quiet_offset())
	assert_equal(_settlement.assignment_count(), 0, "no assignment on a tick nobody is due")
	_settlement.run_tick(30 + stagger)
	assert_equal(_settlement.assignment_count(), 1, "one worker was bound")
	assert_equal(_settlement.jobs().job_of(0), created.ref, "resident 0 holds that job")
	assert_equal(_settlement.jobs().state_of(created.value).value,
		JobsScript.JOB_STATE_RESERVED, "the job moved to RESERVED")


func test_a_forbidden_job_kind_is_never_assigned() -> void:
	"""§5.3 eligibility step 3 runs inside the loop: a forbidden priority yields no assignment."""
	_populated()
	var created: JobsScript.OpResult = _settlement.jobs().create_job(
		JobsScript.JOB_KIND_HAUL, 1, 0, LARGE_JOB_MWU, 0)
	for slot: int in COHORT_SIZE:
		_settlement.priorities().set_priority(slot, JobsScript.JOB_KIND_HAUL, 0)
	_run_ticks(30, 30)
	assert_true(created.ok, "the job was created")
	assert_equal(_settlement.assignment_count(), 0, "nobody may take a forbidden kind")
	assert_equal(_settlement.jobs().state_of(created.value).value,
		JobsScript.JOB_STATE_QUEUED, "the job is still queued")


# --- ARCH-SYS-013 productive work ---------------------------------------------------------------

func _start_solo_work(resident_slot: int) -> int:
	"""Put one resident to work on a fresh job and return its job slot.

	Assignment needs a resolved activity, so the hour is resolved first; nothing here writes a
	state the loop itself would write, except the RESERVED -> WORK step no navigation exists for.
	"""
	var hour: int = 8
	_settlement.schedule().resolve(resident_slot, hour, false)
	var created: JobsScript.OpResult = _settlement.jobs().create_job(
		JobsScript.JOB_KIND_HAUL, 1, 0, LARGE_JOB_MWU, 0)
	_settlement.jobs().assign_worker(resident_slot, created.value)
	_settlement.jobs().set_state(created.value, JobsScript.JOB_STATE_WORK)
	return created.value


func test_a_tick_advances_a_job_in_the_work_state() -> void:
	"""One tick produces 80 milli-WU x factor/1000 against the job, per GDD §5.2."""
	_populated()
	var job_slot: int = _start_solo_work(0)
	var factor: int = _settlement.work().work_factor_of(0, JobsScript.JOB_KIND_HAUL).value
	var expected: int = BASE_MWU_PER_TICK * factor / WORK_FACTOR_DENOMINATOR
	_settlement.run_tick(1)
	var remaining: int = _settlement.jobs().remaining_mwu_of(job_slot).value
	assert_equal(LARGE_JOB_MWU - remaining, expected, "the job advanced by one tick's production")
	assert_equal(_settlement.accepted_mwu_last_tick(), expected, "the same total is reported")
	assert_true(expected >= MIN_POTENTIAL_MWU and expected <= MAX_POTENTIAL_MWU,
		"the §5.2 factor clamp bounds one tick's production")


func test_a_job_not_in_the_work_state_takes_no_work() -> void:
	"""A RESERVED job is not worked: nothing here writes the travel transition that has no owner."""
	_populated()
	var job_slot: int = _start_solo_work(0)
	_settlement.jobs().set_state(job_slot, JobsScript.JOB_STATE_RESERVED)
	_settlement.run_tick(1)
	assert_equal(_settlement.jobs().remaining_mwu_of(job_slot).value, LARGE_JOB_MWU,
		"a reserved job took no work")
	assert_equal(_settlement.accepted_mwu_last_tick(), 0, "and none was reported")


func test_productive_work_credits_xp_at_ten_per_completed_work_unit() -> void:
	"""§5.3's XP rule runs through the loop: 10 XP per whole WU of accepted work, no more."""
	_populated()
	var job_slot: int = _start_solo_work(0)
	var before_xp: int = _settlement.residents().skill_xp_of(0, JobsScript.JOB_KIND_HAUL).value
	_run_ticks(1, 40)
	var accepted: int = LARGE_JOB_MWU - _settlement.jobs().remaining_mwu_of(job_slot).value
	var after_xp: int = _settlement.residents().skill_xp_of(0, JobsScript.JOB_KIND_HAUL).value
	assert_true(accepted > MILLI_WU_PER_WU, "forty ticks completed at least one work unit")
	assert_equal(after_xp - before_xp, XP_PER_WU * (accepted / MILLI_WU_PER_WU),
		"XP is exactly ten per completed work unit")


func test_the_accepted_total_is_per_tick_and_not_cumulative() -> void:
	"""`accepted_mwu_last_tick()` reports one tick, so an idle tick reports zero."""
	_populated()
	var job_slot: int = _start_solo_work(0)
	_settlement.run_tick(1)
	var first: int = _settlement.accepted_mwu_last_tick()
	_settlement.jobs().set_state(job_slot, JobsScript.JOB_STATE_HAUL_OUTPUT)
	_settlement.run_tick(2)
	assert_true(first > 0, "the first tick accepted work")
	assert_equal(_settlement.accepted_mwu_last_tick(), 0, "the second accepted none")


func test_a_party_advances_its_shared_row_once_at_the_combined_rate() -> void:
	"""Decision 0017: a two-worker party advances the coordinator by the sum of both potentials."""
	_populated()
	var coordinator: int = _start_party(0, 1)
	var first: int = BASE_MWU_PER_TICK * _settlement.work().work_factor_of(
		0, JobsScript.JOB_KIND_HAUL).value / WORK_FACTOR_DENOMINATOR
	var second: int = BASE_MWU_PER_TICK * _settlement.work().work_factor_of(
		1, JobsScript.JOB_KIND_HAUL).value / WORK_FACTOR_DENOMINATOR
	_settlement.run_tick(1)
	var accepted: int = LARGE_JOB_MWU - _settlement.jobs().remaining_mwu_of(coordinator).value
	assert_equal(accepted, first + second, "the shared row advanced once, at the combined rate")
	assert_equal(_settlement.accepted_mwu_last_tick(), accepted, "the same total is reported")


func _start_party(first_slot: int, second_slot: int) -> int:
	"""Build a coordinator with two member jobs, one per worker, and return the coordinator slot."""
	var coordinator: JobsScript.OpResult = _settlement.jobs().create_job(
		JobsScript.JOB_KIND_HAUL, 1, 0, LARGE_JOB_MWU, 0)
	_settlement.jobs().make_coordinator(coordinator.value)
	_settlement.jobs().set_state(coordinator.value, JobsScript.JOB_STATE_WORK)
	for slot: int in [first_slot, second_slot]:
		_settlement.schedule().resolve(slot, 8, false)
		var member: JobsScript.OpResult = _settlement.jobs().create_job(
			JobsScript.JOB_KIND_HAUL, 1, 0, 0, 0)
		_settlement.jobs().assign_worker(slot, member.value)
		_settlement.jobs().set_coordinator(member.value, coordinator.value)
		_settlement.jobs().set_state(member.value, JobsScript.JOB_STATE_WORK)
	return coordinator.value


# --- REQ-SET-007 daily boundary -----------------------------------------------------------------

func test_a_winter_day_boundary_applies_the_hunger_multiplier() -> void:
	"""REQ-SET-143's x1.20 reaches daily demand through the daily boundary's season handover."""
	_populated()
	assert_equal(_settlement.residents().daily_demand_np().value, COHORT_DEMAND_NP,
		"the §7.1 cohort demand before winter")
	assert_true(_settlement.run_day_boundary(37, SEASON_WINTER), "the boundary was applied")
	assert_true(_settlement.is_winter(), "winter is in force")
	assert_equal(_settlement.residents().daily_demand_np().value, COHORT_WINTER_DEMAND_NP,
		"demand rises by exactly the REQ-SET-143 multiplier")


func test_a_non_winter_day_boundary_releases_the_multiplier() -> void:
	"""Leaving winter restores the §7.1 demand rather than latching the multiplier on."""
	_populated()
	_settlement.run_day_boundary(37, SEASON_WINTER)
	assert_true(_settlement.run_day_boundary(49, SEASON_SPRING), "the spring boundary applied")
	assert_false(_settlement.is_winter(), "winter is released")
	assert_equal(_settlement.residents().daily_demand_np().value, COHORT_DEMAND_NP,
		"demand returns to the §7.1 figure")


func test_an_out_of_range_day_boundary_is_refused() -> void:
	"""An unknown season or a nonpositive day refuses explicitly and changes no season state."""
	_populated()
	assert_false(_settlement.run_day_boundary(1, 4), "season 4 does not exist")
	assert_equal(_settlement.last_refusal(), &"INVALID_SEASON", "the season refusal is named")
	assert_false(_settlement.run_day_boundary(0, SEASON_WINTER), "day 0 does not exist")
	assert_equal(_settlement.last_refusal(), &"INVALID_ABSOLUTE_DAY", "the day refusal is named")
	assert_false(_settlement.is_winter(), "no season was applied")


# --- the clock binding --------------------------------------------------------------------------

func _bind_game() -> void:
	"""Bind a fresh GameManager to this settlement, as the autoloads do at boot."""
	_game = GameManagerScript.new()
	_game.bind_simulation(_settlement.run_tick, _settlement.run_day_boundary)
	_game.start_game()


func test_the_clock_runs_exactly_one_settlement_tick_per_completed_tick() -> void:
	"""The loop is driven by completed simulation ticks, never by host frames."""
	_populated()
	_bind_game()
	var ticks: int = 0
	for frame: int in 10:
		ticks += _game.advance_host_time(TICK_FRAME_USEC)
	assert_equal(ticks, 10, "ten host frames of 1/30 second are ten ticks at 1x")
	assert_equal(_settlement.ticks_run(), ticks, "one settlement tick per completed tick")
	assert_equal(_game.get_completed_tick(), _settlement.ticks_run(), "the two agree")


func test_a_faster_speed_runs_more_of_the_same_tick() -> void:
	"""REQ-SET-003: 2x runs twice as many identical ticks per real second, not a bigger tick."""
	_populated()
	_bind_game()
	_game.set_speed(SimClockScript.SPEED_DOUBLE)
	for frame: int in 10:
		_game.advance_host_time(TICK_FRAME_USEC)
	assert_equal(_settlement.ticks_run(), 20, "twice the ticks for the same host time")
	var size: int = _settlement.residents().size_class_of(0).value
	assert_equal(_settlement.needs().need_of(0, NeedsScript.NEED_HUNGER).value,
		INITIAL_NEED - _expected_decay(HUNGER_RATE_MILLI_PER_HOUR[size], 20),
		"each tick applied the identical integer rule")


func test_a_paused_clock_runs_no_settlement_tick() -> void:
	"""REQ-SET-004: while paused, needs, jobs and work freeze; the host frames keep arriving."""
	_populated()
	_bind_game()
	for frame: int in 5:
		_game.advance_host_time(TICK_FRAME_USEC)
	var before: int = _settlement.ticks_run()
	var hunger: int = _settlement.needs().need_of(0, NeedsScript.NEED_HUNGER).value
	_game.pause_game()
	for frame: int in 100:
		_game.advance_host_time(TICK_FRAME_USEC)
	assert_equal(_settlement.ticks_run(), before, "no tick ran while paused")
	assert_equal(_settlement.needs().need_of(0, NeedsScript.NEED_HUNGER).value, hunger,
		"needs are frozen")
	assert_true(before > 0, "the settlement was running before the pause")


func test_the_first_midnight_reaches_the_settlement_day_boundary() -> void:
	"""The clock's 00:00 crossing at tick 13500 runs the settlement's daily boundary."""
	_populated()
	_bind_game()
	_game.day_advanced.connect(_on_day_advanced)
	_game.set_speed(SimClockScript.SPEED_QUADRUPLE)
	var frames: int = SimClockScript.FIRST_MIDNIGHT_TICK / 4 + 10
	for frame: int in frames:
		_game.advance_host_time(TICK_FRAME_USEC)
	assert_true(_game.get_completed_tick() >= SimClockScript.FIRST_MIDNIGHT_TICK,
		"the run reached the first midnight")
	assert_equal(_boundaries, [2] as Array[int], "exactly one day boundary, into day 2")
	assert_false(_settlement.is_winter(), "day 2 is spring, so no winter multiplier")


func _on_day_advanced(absolute_day: int) -> void:
	"""Record a day boundary the GameManager republished for the HUD."""
	_boundaries.append(absolute_day)


# --- health, death and unknown references (ARCH-MIG-006 step 7) ----------------------------------
#
# Step 7 retires `CombatSystem` from the settlement build (decision 0006 divergence row 9) and
# runs the health, death and unknown-reference semantics worth keeping through the settlement's
# own health and lifecycle path instead. That path is `scripts/core/needs.gd`, reached here
# through the composed SettlementSystem rather than through a bare store, because the property
# under test is that a resident of the LIVE COHORT behaves this way while the tick loop runs
# over it.
#
# NO DAMAGE MODEL IS PORTED. The GDD defines none for the settlement: §5.2 has health, REQ-SET-173
# has treatment, REQ-SET-172 has Injury, and `apply_health_event()` is the signed whole-point
# channel all of them use. A negative health event below is a wound or a starvation debt, not an
# attack, and nothing here computes one.

func _kill(slot: int) -> void:
	"""Drive one cohort resident's health to 0 through the settlement's own health channel."""
	var killed: NeedsScript.OpResult = _settlement.needs().apply_health_event(slot, -HEALTH_MAX)
	assert_true(killed.ok, "the lethal health event was accepted")


func test_a_sublethal_health_event_lowers_health_and_keeps_the_resident_living() -> void:
	"""A wound short of fatal moves the health column and changes nothing about the population."""
	_populated()
	var applied: NeedsScript.OpResult = _settlement.needs().apply_health_event(0, -30)
	assert_true(applied.ok, "the health event was accepted")
	assert_equal(applied.value, -30, "thirty whole points were absorbed")
	assert_equal(_settlement.needs().health_of(0).value, HEALTH_MAX - 30, "health fell to 70")
	assert_true(_settlement.residents().is_alive(0), "the resident is still alive")
	assert_equal(_settlement.living_count(), COHORT_SIZE, "the living count is unchanged")


func test_a_lethal_health_event_records_a_death_and_keeps_the_row() -> void:
	"""REQ-SET-016: reaching health 0 marks the row dead. It does NOT destroy it.

	This is the settlement counterpart of the legacy battle system's `apply_damage()`, which
	destroys the entity outright. A settlement corpse keeps its row: the chronicle, the burial
	job and its recoverable inventory all still have to find it.
	"""
	_populated()
	_kill(0)
	assert_equal(_settlement.needs().health_of(0).value, HEALTH_MIN, "health reached zero")
	assert_equal(_settlement.needs().status_of(0).value, NeedsScript.STATUS_DEAD, "status is dead")
	assert_equal(_settlement.living_count(), COHORT_SIZE - 1, "one fewer living resident")
	assert_equal(_settlement.needs().death_count(), 1, "the death was recorded once")
	assert_equal(_settlement.population(), COHORT_SIZE, "the row is retained, not destroyed")
	assert_true(_settlement.needs().is_present(0), "the corpse still occupies its row")


func test_health_is_floored_at_zero_by_an_overkill_event() -> void:
	"""An event far past the floor clamps at 0 rather than writing a negative health."""
	_populated()
	var applied: NeedsScript.OpResult = _settlement.needs().apply_health_event(0, -999)
	assert_true(applied.ok, "the event was accepted")
	assert_equal(applied.value, -HEALTH_MAX, "only the hundred points that existed were absorbed")
	assert_equal(_settlement.needs().health_of(0).value, HEALTH_MIN, "health floored at zero")
	assert_equal(_settlement.needs().death_count(), 1, "overkill records exactly one death")


func test_treatment_stops_at_the_health_maximum() -> void:
	"""REQ-SET-173 treatment restores whole points and cannot bank past 100."""
	_populated()
	assert_true(_settlement.needs().apply_health_event(0, -60).ok, "the resident was wounded")
	var treated: NeedsScript.OpResult = _settlement.needs().apply_health_event(0, 25)
	assert_true(treated.ok, "treatment applies")
	assert_equal(_settlement.needs().health_of(0).value, 65, "health was restored to 65")
	var overtreated: NeedsScript.OpResult = _settlement.needs().apply_health_event(0, 500)
	assert_true(overtreated.ok, "the oversized course still applies")
	assert_equal(overtreated.value, HEALTH_MAX - 65, "only the missing points were absorbed")
	assert_equal(_settlement.needs().health_of(0).value, HEALTH_MAX, "health stops at the cap")


func test_a_dead_resident_refuses_treatment_and_is_skipped_by_the_tick() -> void:
	"""A corpse is not a heal target, and the interval sweep steps over it without refusing."""
	_populated()
	_kill(0)
	var treated: NeedsScript.OpResult = _settlement.needs().apply_health_event(0, 50)
	assert_false(treated.ok, "the dead resident refuses treatment")
	assert_equal(treated.error, NeedsScript.REFUSE_RESIDENT_DEAD, "and names the reason")
	assert_equal(treated.value, 0, "a refusal carries no absorbed points")
	assert_true(_settlement.run_tick(1), "the sweep still completes with a corpse in the cohort")
	assert_equal(_settlement.refused_tick_count(), 0, "and refuses nothing")
	assert_equal(_settlement.needs().health_of(0).value, HEALTH_MIN, "the corpse does not recover")
	assert_equal(_settlement.living_count(), COHORT_SIZE - 1, "and is not counted among the living")


func test_an_out_of_range_resident_row_is_refused_rather_than_answered() -> void:
	"""An unknown row REFUSES on every health channel instead of reporting a plausible zero.

	The legacy battle system answers 0 health for an entity it has never heard of. That is the
	sentinel this codebase forbids: 0 is a real health value belonging to a real corpse.
	"""
	_populated()
	for slot: int in [-1, NeedsScript.RESIDENT_CAPACITY]:
		var health: IntMath.IntResult = _settlement.needs().health_of(slot)
		assert_false(health.ok, "health of row %d is refused" % slot)
		assert_equal(health.error, String(NeedsScript.REFUSE_INVALID_SLOT), "the slot is invalid")
		assert_false(_settlement.needs().status_of(slot).ok, "status of row %d is refused" % slot)
		var event: NeedsScript.OpResult = _settlement.needs().apply_health_event(slot, -10)
		assert_false(event.ok, "a health event on row %d is refused" % slot)
		assert_equal(event.error, NeedsScript.REFUSE_INVALID_SLOT, "and names the invalid slot")
	assert_equal(_settlement.living_count(), COHORT_SIZE, "no refusal touched the cohort")


func test_a_row_inside_capacity_but_outside_the_cohort_is_not_present() -> void:
	"""A valid, empty row is refused as NOT PRESENT, distinctly from an out-of-range one."""
	_populated()
	var empty_slot: int = COHORT_SIZE
	assert_false(_settlement.needs().is_present(empty_slot), "row 12 holds no resident")
	var health: IntMath.IntResult = _settlement.needs().health_of(empty_slot)
	assert_false(health.ok, "its health is refused")
	assert_equal(health.error, String(NeedsScript.REFUSE_NOT_PRESENT), "as not present")
	assert_equal(health.value, 0, "and the refusal carries no health value")
	var event: NeedsScript.OpResult = _settlement.needs().apply_health_event(empty_slot, 10)
	assert_false(event.ok, "a health event on an empty row is refused")
	assert_equal(event.error, NeedsScript.REFUSE_NOT_PRESENT, "as not present")


func test_a_resident_reference_taken_before_a_reset_is_no_longer_valid() -> void:
	"""Generation validation: a reference held across a reset names nobody, not a new resident.

	`reset()` clears the directory and a fresh cohort reuses the same slots, so the ONLY thing
	separating a stale reference from the new resident living in that slot is the generation.
	"""
	_populated()
	var stale: Vector2i = _settlement.residents().ref_of(0)
	assert_true(_settlement.directory().is_valid(stale), "the reference is valid while it lives")
	_settlement.reset()
	assert_false(_settlement.directory().is_valid(stale), "a reset invalidates it")
	assert_true(_settlement.create_initial_settlement(), "a fresh cohort was created")
	var reissued: Vector2i = _settlement.residents().ref_of(0)
	assert_equal(reissued.x, stale.x, "the new resident reuses the same slot")
	assert_false(_settlement.directory().is_valid(stale), "yet the old reference stays invalid")
	assert_true(_settlement.directory().is_valid(reissued), "and the new one is valid")


# --- measurement ---------------------------------------------------------------------------------

func test_a_settlement_tick_at_the_starting_cohort_is_measured() -> void:
	"""Measure and PRINT the real cost of a settlement tick at the §5.1 cohort of twelve.

	Twelve residents is not 256, and a debug editor binary is not the exported release build
	ARCH-PERF-002 qualifies on, so this is not REQ-SET-163 evidence. The assertion is a loose
	collapse guard; the printed number is the point.
	"""
	_populated()
	_run_ticks(1, MEASURED_TICKS)
	var mean: IntMath.IntResult = _settlement.mean_tick_usec()
	print("[measure] settlement tick at %d residents over %d ticks: mean %d us, max %d us" % [
		COHORT_SIZE, MEASURED_TICKS, mean.value, _settlement.max_tick_usec()])
	assert_true(mean.ok, "a mean is available after the run")
	assert_equal(_settlement.ticks_run(), MEASURED_TICKS, "every sampled tick was counted")
	assert_less_than(float(mean.value), float(TICK_CEILING_USEC), "the mean tick is not collapsed")
