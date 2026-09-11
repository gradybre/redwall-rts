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
const CommandsScript := preload("res://scripts/core/commands.gd")
const CommandDispatchScript := preload("res://scripts/core/command_dispatch.gd")

## ARCH-CMD-003's sorted kind ids, transcribed from the architecture's own list.
const COMMAND_KIND_CANCEL_JOB: int = 3
const COMMAND_KIND_DESIGNATE_ZONE: int = 8
const COMMAND_KIND_NAME_RESIDENT: int = 11
const COMMAND_KIND_SET_ACTIVITY_SCHEDULE: int = 15
const COMMAND_KIND_SET_POLICY: int = 20
const COMMAND_KIND_UPGRADE: int = 23
## GDD §4.3's Activity numbering, transcribed.
const ACTIVITY_SLEEP: int = 2
const EntityDirectoryScript := preload("res://scripts/core/entity_directory.gd")
const WorldInitScript := preload("res://scripts/core/world_init.gd")
const ForageScript := preload("res://scripts/core/forage.gd")
const JobPlannerScript := preload("res://scripts/core/job_planner.gd")
const PresentationExtractScript := preload("res://scripts/core/presentation_extract.gd")
const ResourceNodesScript := preload("res://scripts/core/resource_nodes.gd")
const FishingScript := preload("res://scripts/core/fishing.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")
const RngScript := preload("res://scripts/core/rng.gd")
const OrchardHiveScript := preload("res://scripts/core/orchard_hive.gd")

## GDD §5.1: the starting settlement is twelve residents.
const COHORT_SIZE: int = 12

## An arbitrary int32 standing in for REQ-SET-009's world seed, which has no store yet. Nothing
## asserts a value derived from it: it exists so the WEATHER stream is drawable at all.
const FIXTURE_WORLD_SEED: int = 20260910

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
const SEASON_SUMMER: int = 1
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
	"""A settlement holding the GDD §5.1 starting cohort, over a seeded world.

	The seed is what REQ-SET-009's world generation would supply, and it is supplied here because
	§5.10 draws one WEATHER roll per season after the forced first spring: without it every day
	boundary from the second season on refuses, which
	`test_an_unseeded_settlement_refuses_its_second_seasons_weather_draw` asserts on purpose.
	"""
	_settlement.create_initial_settlement()
	_settlement.rng().seed_world(FIXTURE_WORLD_SEED)
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


# --- REQ-SET-007 leg order and ARCH-SYS-005 Ecology (task 03 increment 9) ------------------------

func test_the_boundary_runs_the_handover_then_ecology_then_crops_and_no_other_leg() -> void:
	"""REQ-SET-007's five legs are ordered, and only the three with an owner here may appear.

	CHANGED BY TASK 03 INCREMENT 10: this assertion previously ended at two legs, because
	ARCH-SYS-006 had no owner. Crops/weather is REQ-SET-007's THIRD step and must appear AFTER
	"update ecology", never before it and never instead of it.
	"""
	_populated()
	assert_true(_settlement.run_day_boundary(37, SEASON_WINTER), "the winter boundary runs")
	assert_equal(_settlement.daily_leg_count(), 3, "exactly three legs executed")
	assert_equal(_settlement.daily_leg_at(0).value, SettlementSystemScript.LEG_SEASON_HANDOVER,
		"ARCH-TICK-003's handover first, between aging and ecology")
	assert_equal(_settlement.daily_leg_at(1).value, SettlementSystemScript.LEG_ECOLOGY,
		"then ARCH-SYS-005 Ecology")
	assert_equal(_settlement.daily_leg_at(2).value, SettlementSystemScript.LEG_CROP_WEATHER,
		"then ARCH-SYS-006 CropWeather, REQ-SET-007's third step")
	assert_false(_settlement.daily_leg_at(3).ok, "and nothing after it")
	assert_equal(String(_settlement.daily_leg_at(3).error), "INVALID_INDEX",
		"the reader refuses rather than answering a leg that did not run")


func test_the_boundary_advances_the_settlements_own_ecology() -> void:
	"""ARCH-SYS-005 is wired to THIS settlement's stores, not to a detached fixture."""
	_populated()
	var made: FishingScript.OpResult = _settlement.ecology().fishing().create_habitat(
		2, EntityDirectoryScript.NULL_REF, PackedInt32Array([10, 11, 12]), 0, 0, 0)
	assert_true(made.ok, "a river habitat is placed in the settlement's fishery")
	var row: int = _settlement.ecology().fishing().stock_row_of(made.ref, 0).value
	assert_equal(_settlement.ecology().fishing().population_milli_of(row).value, 480000,
		"trout start at 80% of the 600 U capacity")
	assert_true(_settlement.run_day_boundary(2, SEASON_SPRING), "the day 2 boundary runs")
	assert_equal(_settlement.last_ecology_day(), 2, "the ecology consumed day 2")
	assert_equal(_settlement.ecology().fishing().population_milli_of(row).value, 490680,
		"and §5.4 recovery reached the stock through the settlement")
	assert_true(_settlement.ecology_day().ok, "the day result reports a committed day")
	assert_equal(_settlement.ecology_day().fish_stocks_recovered, 3, "with three stocks recovered")


func test_a_season_that_does_not_belong_to_that_day_is_refused() -> void:
	"""The day and the season are joined through the calendar, not taken on trust."""
	_populated()
	assert_false(_settlement.run_day_boundary(37, SEASON_SPRING),
		"absolute day 37 is winter, not spring")
	assert_equal(_settlement.last_refusal(), &"DAY_BOUNDARY_CALENDAR_MISMATCH", "and says so")
	assert_false(_settlement.is_winter(), "no season was applied")
	assert_equal(_settlement.last_ecology_day(), 0, "and no ecology day was consumed")
	assert_equal(_settlement.daily_leg_count(), 0, "no leg ran at all")


func test_day_one_raises_no_boundary_because_it_opens_at_six_in_the_morning() -> void:
	"""Tick 0 is 06:00 of day 1, so day 1 has no midnight and cannot be a boundary."""
	_populated()
	assert_false(_settlement.run_day_boundary(1, SEASON_SPRING), "day 1 opens at no crossing")
	assert_equal(_settlement.last_refusal(), &"NOT_A_DAY_BOUNDARY", "with the boundary code")
	assert_equal(_settlement.daily_leg_count(), 0, "and no leg ran")


func test_a_replayed_day_boundary_is_refused_rather_than_applied_twice() -> void:
	"""The ecology latch reaches the settlement: the same day cannot be run again."""
	_populated()
	assert_true(_settlement.run_day_boundary(37, SEASON_WINTER), "the first run commits")
	assert_false(_settlement.run_day_boundary(37, SEASON_WINTER), "the second is refused")
	assert_equal(_settlement.last_refusal(), &"ECOLOGY_DAY_ALREADY_RUN", "with the replay code")
	assert_equal(_settlement.daily_leg_count(), 1,
		"the season handover ran and the ecology leg did not")


func test_reset_drops_the_ecology_stores_and_the_leg_log() -> void:
	"""A reset settlement is one settlement's state, ecology included."""
	_populated()
	_settlement.ecology().fishing().create_habitat(
		2, EntityDirectoryScript.NULL_REF, PackedInt32Array([10, 11, 12]), 0, 0, 0)
	assert_true(_settlement.run_day_boundary(37, SEASON_WINTER), "a boundary runs")
	_settlement.reset()
	assert_equal(_settlement.ecology().fishing().habitat_count(), 0, "the fishery is emptied")
	assert_equal(_settlement.last_ecology_day(), 0, "the day latch is dropped")
	assert_equal(_settlement.daily_leg_count(), 0, "and the leg log is cleared")


func test_the_ecology_shares_the_settlements_one_entity_directory() -> void:
	"""One directory validates every settlement reference, ecology references included."""
	_populated()
	assert_true(_settlement.ecology().directory() == _settlement.directory(),
		"the ecology stores were composed over the settlement's own directory")


# --- ARCH-SYS-006 CropWeather (task 03 increment 10) ---------------------------------------------

## GDD §5.10's spring baseline, transcribed: 12 C in tenths, and +1200 rain/day.
const SPRING_TEMPERATURE_TENTHS: int = 120
const SPRING_RAIN: int = 1200
## §5.6's hourly growth step at ideal temperature and in-range moisture, in milli-hours.
const IDEAL_GROWTH_STEP_MILLI_HOURS: int = 1000
## §4.3's Soil, stated explicitly: LOAM=0. `farming.gd`'s fifth CropDefinition row is roots.
const SOIL_LOAM: int = 0
const CROP_ROOTS: int = 4
## `sim_clock.gd`'s 750 ticks per game hour, restated. Hour crossings are its positive multiples.
const TICKS_PER_HOUR: int = 750
## §5.10's forced first-spring event: ideal spell, whose EventDefinition id is 6.
const EVENT_IDEAL_SPELL: int = 6


func _growing_plot() -> int:
	"""Sow one roots plot in this settlement's own crop store and leave it GROWING."""
	var crop: FarmingScript = _settlement.farming()
	var tile: int = _settlement.ecology().resource_nodes().tile_index(40, 40).value
	var made: FarmingScript.OpResult = _settlement.crop_weather().create_plot_at_tile(
		tile, SOIL_LOAM, 1)
	assert_true(made.ok, "the fixture plot must be created (%s)" % made.error)
	assert_true(crop.plant(made.value, CROP_ROOTS, 1, SEASON_SPRING, 1).ok, "and sown")
	assert_true(crop.begin_growing(made.value).ok, "and its sowing completed")
	return made.value


func test_creating_the_settlement_opens_day_ones_weather() -> void:
	"""Day 1 opens at 06:00 and reaches no midnight, so the stage writes its baseline at creation."""
	_populated()
	assert_equal(_settlement.weather().temperature_tenths(), SPRING_TEMPERATURE_TENTHS,
		"§5.10's spring baseline is 12 C")
	assert_equal(_settlement.weather().rain(), SPRING_RAIN, "and +1200 rain/day")
	assert_equal(_settlement.weather().event_of(), EVENT_IDEAL_SPELL,
		"§5.10's forced first-spring event is scheduled")
	assert_equal(_settlement.rng().draw_count_of(RngScript.STREAM_WEATHER).value, 0,
		"and the forced event consumed no WEATHER draw")


func test_the_hourly_crop_leg_runs_on_hour_crossings_and_not_only_at_midnight() -> void:
	"""ARCH-SYS-006's hourly cadence is driven from `run_tick()`, 23 ticks in 24 doing nothing."""
	_populated()
	var slot: int = _growing_plot()
	_run_ticks(TICKS_PER_HOUR - 1, 1)
	assert_equal(_settlement.farming().growth_milli_hours_of(slot).value, 0,
		"tick 749 is inside an hour and integrates nothing")
	assert_equal(_settlement.refused_crop_hour_count(), 0,
		"and is not DISPATCHED AND REFUSED either: a non-crossing tick must not manufacture one")
	assert_equal(_settlement.last_refusal(), &"",
		"so the settlement's one error channel is not overwritten 23 ticks in every 24")
	_run_ticks(TICKS_PER_HOUR, 2)
	assert_equal(_settlement.farming().growth_milli_hours_of(slot).value,
		IDEAL_GROWTH_STEP_MILLI_HOURS,
		"tick 750 is an hour crossing and tick 751 is not")
	_run_ticks(2 * TICKS_PER_HOUR, 1)
	assert_equal(_settlement.farming().growth_milli_hours_of(slot).value,
		2 * IDEAL_GROWTH_STEP_MILLI_HOURS, "and tick 1500 is the next crossing")
	assert_equal(_settlement.daily_leg_count(), 0,
		"none of which is a midnight: no daily leg has run at all")


func test_the_hourly_crop_leg_reports_the_hour_it_integrated() -> void:
	"""The stage's own result reaches the settlement, so a skipped hour cannot be silent."""
	_populated()
	_growing_plot()
	_run_ticks(TICKS_PER_HOUR, 1)
	assert_true(_settlement.crop_hour().ok, "the hour committed")
	assert_equal(_settlement.crop_hour().tick, TICKS_PER_HOUR, "at tick 750")
	assert_equal(_settlement.crop_hour().plots_grown, 1, "integrating the one growing plot")
	assert_equal(_settlement.refused_crop_hour_count(), 0, "and refusing no hour")


func test_the_crop_stage_advances_this_settlements_own_stores() -> void:
	"""ARCH-SYS-006 is wired to THIS settlement's crop store, not to a detached fixture."""
	_populated()
	var slot: int = _growing_plot()
	assert_true(_settlement.run_day_boundary(2, SEASON_SPRING), "the day 2 boundary runs")
	assert_true(_settlement.crop_weather_day().ok, "the crop day committed")
	assert_equal(_settlement.crop_weather_day().absolute_day, 2, "for absolute day 2")
	assert_equal(_settlement.crop_weather_day().plots_moistened, 1,
		"and the settlement's own plot took the day's moisture")
	assert_equal(_settlement.farming().moisture_of(slot).value, 6600,
		"§5.10's spring +1200 rain against 600 evaporation, from the 6000 a plot spawns with")


func test_the_crop_stage_shares_the_settlements_directory_ecology_and_stream_set() -> void:
	"""One directory, one orchard/hive store and one ARCH-RNG-002 stream set per settlement."""
	_populated()
	assert_true(_settlement.crop_weather().directory() == _settlement.directory(),
		"the crop store validates through the settlement's one directory")
	assert_true(_settlement.crop_weather().orchard_hive() == _settlement.ecology().orchard_hive(),
		"ARCH-SYS-006 borrows ARCH-SYS-005's hives rather than composing a second store")
	assert_true(_settlement.crop_weather().rng() == _settlement.rng(),
		"and consumes the settlement's one stream set")


func test_an_unseeded_settlement_refuses_its_second_seasons_weather_draw() -> void:
	"""REQ-SET-009's world generation does not exist, so an unseeded world REFUSES the draw.

	The forced first spring needs no seed, so eleven spring midnights commit; summer's stated
	draw cannot be taken and the whole leg refuses rather than leaving the season eventless.
	"""
	_settlement.create_initial_settlement()
	assert_false(_settlement.rng().is_seeded(), "no world generator has seeded this settlement")
	for day: int in range(2, 13):
		assert_true(_settlement.run_day_boundary(day, SEASON_SPRING),
			"spring day %d commits" % day)
	assert_false(_settlement.run_day_boundary(13, SEASON_SUMMER), "summer day 1 refuses")
	assert_equal(_settlement.last_refusal(), &"RNG_NOT_SEEDED", "with the stream's own code")
	assert_equal(_settlement.daily_leg_count(), 2,
		"the handover and ecology legs ran; the crops/weather leg did not")


func test_a_hive_eligibility_crossing_reaches_the_farm_side_of_the_boundary() -> void:
	"""Decision 0044's FARM half: ARCH-SYS-005 commits the strength change, ARCH-SYS-006 refreshes.

	`ecology.gd` refreshes its own ORCHARD recipients and states it cannot refresh farm ones. Here
	an unserviced hive loses REQ-SET-083's 200 strength at the boundary and crosses below §5.6's
	5000 healthy line, which invalidates the bean plot's slice; the crops/weather leg that runs
	one call later is what puts it right, without any read having repaired it.
	"""
	_populated()
	var hives: OrchardHiveScript = _settlement.ecology().orchard_hive()
	var building: Vector2i = _settlement.directory().create(EntityDirectoryScript.KIND_BUILDING)
	var made: OrchardHiveScript.OpResult = hives.create_hive(building, 46, 60, 46, 60, 1)
	assert_true(made.ok, "the fixture hive is colonised (%s)" % made.error)
	assert_true(hives.restore_hive_state(made.ref, 5100, 0, 0, 0, 1).ok,
		"and left 100 points above the healthy line, unserviced since day 1")
	var tile: int = _settlement.ecology().resource_nodes().tile_index(40, 60).value
	var plot: FarmingScript.OpResult = _settlement.crop_weather().create_plot_at_tile(
		tile, SOIL_LOAM, 1)
	assert_true(plot.ok, "the bean plot is created inside the hive's 12 m range")
	assert_true(_settlement.crop_weather().check_farm_links_of(plot.value),
		"its slice is canonical at creation")
	assert_true(_settlement.run_day_boundary(3, SEASON_SPRING), "the day 3 boundary runs")
	assert_equal(_settlement.ecology_day().hive_eligibility_crossings, 1,
		"ARCH-SYS-005 reports the crossing it committed")
	assert_equal(_settlement.crop_weather_day().farm_links_refreshed, 1,
		"and ARCH-SYS-006 refreshed the farm side of it")
	assert_true(_settlement.crop_weather().check_farm_links_of(plot.value),
		"so the slice is canonical again")


func test_reset_drops_the_crop_and_weather_stores_and_the_world_seed() -> void:
	"""A reset settlement keeps no plot, no scheduled event and no seeded stream."""
	_populated()
	_growing_plot()
	assert_true(_settlement.run_day_boundary(2, SEASON_SPRING), "a boundary runs")
	_settlement.reset()
	assert_equal(_settlement.farming().count(), 0, "the crop store is emptied")
	assert_false(_settlement.weather().is_event_scheduled(), "the weather row is cleared")
	assert_false(_settlement.rng().is_seeded(), "and the stream set is unseeded")
	assert_equal(_settlement.crop_weather().last_day_run(), 0, "with the day latch dropped")


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


# --- ARCH-SYS-002 CommandCommit -------------------------------------------------------------------

func test_the_settlement_runs_the_command_commit_stage_every_tick() -> void:
	"""ARCH-SYS-002 is wired: a player edit submitted here reaches a real store on the next tick."""
	var settlement: SettlementSystemScript = _populated()
	var resident: Vector2i = settlement.residents().ref_of(0)
	var command: CommandsScript.Command = CommandsScript.Command.new()
	command.kind = COMMAND_KIND_NAME_RESIDENT
	command.target_slot = resident.x
	command.target_generation = resident.y
	command.payload = "Cornflower".to_utf8_buffer()
	var result: CommandsScript.SubmitResult = CommandsScript.SubmitResult.new()
	assert_true(settlement.commands().submit_into(command, result),
		"the queue admits it (error: %s)" % result.error)
	assert_true(settlement.run_tick(1), "the tick runs")
	assert_equal(settlement.commands_committed_last_tick(), 1, "the stage committed it")
	assert_equal(settlement.residents().name_key_of(0), &"Cornflower",
		"and the resident really is renamed")


func test_an_unsupported_command_refuses_in_the_running_settlement() -> void:
	"""A kind with no owning store refuses explicitly rather than appearing to have worked."""
	var settlement: SettlementSystemScript = _populated()
	var command: CommandsScript.Command = CommandsScript.Command.new()
	command.kind = COMMAND_KIND_UPGRADE
	var result: CommandsScript.SubmitResult = CommandsScript.SubmitResult.new()
	assert_true(settlement.commands().submit_into(command, result), "the queue admits it")
	assert_true(settlement.run_tick(1), "the tick runs")
	assert_equal(settlement.commands_committed_last_tick(), 0, "nothing committed")
	assert_equal(settlement.commands_refused_last_tick(), 1, "and one refused")
	var row: CommandDispatchScript.ResultRow = CommandDispatchScript.ResultRow.new()
	assert_true(settlement.command_dispatch().last_result_into(row), "the outcome is recorded")
	assert_equal(row.code(), &"COMMAND_UNSUPPORTED_FEATURE", "under the documented code")


func test_the_ecology_kinds_no_longer_refuse_store_not_bound() -> void:
	"""Task 04.4 bullet 3: `bind_ecology()` runs in composition, so DESIGNATE_ZONE reaches its store.

	BEHAVIOUR DELIBERATELY CHANGED. This test previously asserted COMMAND_STORE_NOT_BOUND, which
	was correct while this node composed no forage store and no planner. It composes both now, so
	a DESIGNATE_ZONE carrying the null target reaches the arm and refuses on the TARGET instead --
	a refusal from the store's own revalidation rather than from an absent store.
	"""
	var settlement: SettlementSystemScript = _populated()
	var command: CommandsScript.Command = CommandsScript.Command.new()
	command.kind = COMMAND_KIND_DESIGNATE_ZONE
	var result: CommandsScript.SubmitResult = CommandsScript.SubmitResult.new()
	assert_true(settlement.commands().submit_into(command, result), "the queue admits it")
	assert_true(settlement.run_tick(1), "the tick runs")
	assert_equal(settlement.commands_refused_last_tick(), 1, "a targetless designation refuses")
	var row: CommandDispatchScript.ResultRow = CommandDispatchScript.ResultRow.new()
	assert_true(settlement.command_dispatch().last_result_into(row), "the outcome is recorded")
	assert_equal(row.code(), &"COMMAND_TARGET_REQUIRED",
		"naming the missing target, NOT the missing store")


func test_an_unbound_dispatch_still_refuses_store_not_bound() -> void:
	"""The refusal this node no longer produces is still produced by a composition without ecology.

	The guard did not disappear when this node stopped triggering it: a dispatcher built without
	`forage.gd` and `job_planner.gd` refuses exactly as before, which is what keeps every other
	composition honest.
	"""
	var settlement: SettlementSystemScript = _populated()
	var lone: CommandDispatchScript = CommandDispatchScript.new(settlement.commands(),
		settlement.residents(), settlement.priorities(), settlement.schedule(), settlement.jobs())
	var command: CommandsScript.Command = CommandsScript.Command.new()
	command.kind = COMMAND_KIND_DESIGNATE_ZONE
	var result: CommandsScript.SubmitResult = CommandsScript.SubmitResult.new()
	assert_true(settlement.commands().submit_into(command, result), "the queue admits it")
	var report: CommandDispatchScript.TickReport = CommandDispatchScript.TickReport.new()
	assert_true(lone.commit_tick_into(1, report), "the unbound stage still runs")
	var row: CommandDispatchScript.ResultRow = CommandDispatchScript.ResultRow.new()
	assert_true(lone.last_result_into(row), "the outcome is recorded")
	assert_equal(row.code(), &"COMMAND_STORE_NOT_BOUND", "naming the store it lacks")


func test_the_command_stage_runs_before_the_selection_stage() -> void:
	"""§5 places CommandCommit "before selectors", so an edit is visible to the same tick."""
	var settlement: SettlementSystemScript = _populated()
	var resident: Vector2i = settlement.residents().ref_of(0)
	var command: CommandsScript.Command = CommandsScript.Command.new()
	command.kind = COMMAND_KIND_SET_ACTIVITY_SCHEDULE
	command.target_slot = resident.x
	command.target_generation = resident.y
	command.payload = PackedByteArray()
	command.payload.resize(24)
	command.payload.fill(ACTIVITY_SLEEP)
	var result: CommandsScript.SubmitResult = CommandsScript.SubmitResult.new()
	assert_true(settlement.commands().submit_into(command, result), "the queue admits it")
	assert_true(settlement.run_tick(1), "the tick runs")
	assert_equal(settlement.schedule().hour_activity_of(0, 6).value, ACTIVITY_SLEEP,
		"the whole day was rewritten before this tick's selection pass read it")


func test_the_command_stage_commits_before_the_selection_stage_can_take_the_job() -> void:
	"""§5 orders CommandCommit "before selectors", asserted by VALUE and not by comment.

	One HAUL job, one cancellation queued against it, and a tick on which resident 0 is due to
	reevaluate. Committing first cancels the job, so selection finds nothing QUEUED and binds
	nobody. Committing after selection would bind a worker first, and the assignment counter
	would read 1.
	"""
	var settlement: SettlementSystemScript = _populated()
	var created: JobsScript.OpResult = settlement.jobs().create_job(
		JobsScript.JOB_KIND_HAUL, 1, 0, LARGE_JOB_MWU, 0)
	assert_true(created.ok, "the job was created")
	var command: CommandsScript.Command = CommandsScript.Command.new()
	command.kind = COMMAND_KIND_CANCEL_JOB
	command.target_slot = created.ref.x
	command.target_generation = created.ref.y
	var result: CommandsScript.SubmitResult = CommandsScript.SubmitResult.new()
	assert_true(settlement.commands().submit_into(command, result), "the cancellation is queued")
	settlement.run_tick(30 + settlement.jobs().stagger_offset_of(0).value)
	assert_equal(settlement.commands_committed_last_tick(), 1, "the cancellation committed")
	assert_equal(settlement.jobs().state_of(created.value).value,
		JobsScript.JOB_STATE_CANCELLED, "the job is CANCELLED")
	assert_equal(settlement.assignment_count(), 0,
		"and selection bound nobody, because the commit stage ran first")


func test_the_command_queue_follows_the_clock_the_game_is_running_on() -> void:
	"""`start_game()` replaces the SimClock instance, so the queue must be rebound or it stalls."""
	var settlement: SettlementSystemScript = _populated()
	assert_true(settlement.commands().clock() != GameManager.clock(),
		"the queue starts on the private clock it was composed with")
	settlement.run_tick(1)
	assert_true(settlement.commands().clock() == GameManager.clock(),
		"and after one stage it stamps from the clock the game is really running on")


func test_a_reset_settlement_keeps_no_pending_command() -> void:
	"""Authoritative state and the pending queue are one settlement's; a reset empties both."""
	var settlement: SettlementSystemScript = _populated()
	var command: CommandsScript.Command = CommandsScript.Command.new()
	command.kind = COMMAND_KIND_UPGRADE
	var result: CommandsScript.SubmitResult = CommandsScript.SubmitResult.new()
	assert_true(settlement.commands().submit_into(command, result), "one edit is queued")
	assert_equal(settlement.commands().pending_count(), 1, "the queue holds it")
	settlement.reset()
	assert_equal(settlement.commands().pending_count(), 0, "the reset discards it")
	assert_equal(settlement.command_dispatch().result_count(), 0, "and the ledger with it")


# --- task 04.4: the intent-to-job handoff, over a generated world -------------------------------

func _generated() -> WorldInitScript:
	"""Generate REQ-SET-009's world over THIS settlement's own stores, then spawn the cohort.

	The generator is reached through the accessors `world_init.gd` publishes for exactly this
	("`ecology()` is the accessor a world generator or a test uses to reach the stores"), because
	this node composes no generator: the scenario Request's item ids have no authored source and
	the New Settlement control that would supply them is not built.

	GENERATION RUNS FIRST AND THE COHORT SECOND, deliberately: `world_init.publish()` clears the
	entity directory, so residents spawned before it would be stranded by their own world.
	"""
	var world: WorldInitScript = WorldInitScript.new(_settlement.directory(),
		_settlement.ecology().resource_nodes(), _settlement.ecology().forage(),
		_settlement.ecology().fishing(), _settlement.rng(), _settlement.farming(),
		_settlement.ecology().orchard_hive(), _settlement.jobs(), _settlement.commands())
	var request: WorldInitScript.Request = WorldInitScript.Request.new()
	request.tree_resource_id = 1
	request.stone_resource_id = 2
	request.iron_resource_id = 3
	request.forage_item_ids = PackedInt32Array([10, 11, 12, 13, 14])
	request.fish_species_item_ids = PackedInt32Array([20, 21, 22, 23, 24, 25, 26, 27, 28])
	var result: WorldInitScript.GenerateResult = world.generate(request)
	assert_true(result.ok, "the world generates (error: %s)" % result.error)
	assert_true(_settlement.create_initial_settlement(), "and the cohort spawns into it")
	return world


func _designation_payload(tiles: PackedInt32Array) -> PackedByteArray:
	"""GDD §8.1's "zone tiles": an i32 count followed by that many ascending i32 tile indices."""
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(4 + 4 * tiles.size())
	bytes.encode_s32(0, tiles.size())
	for index: int in tiles.size():
		bytes.encode_s32(4 + index * 4, tiles[index])
	return bytes


func _submit_designation(basin: Vector2i) -> bool:
	"""Submit one DESIGNATE_ZONE over `basin` through the settlement's own ARCH-CMD-001 queue."""
	var command: CommandsScript.Command = CommandsScript.Command.new()
	command.reset()
	command.kind = COMMAND_KIND_DESIGNATE_ZONE
	command.target_slot = basin.x
	command.target_generation = basin.y
	command.arg0 = ForageScript.ZONE_TYPE_FORAGE
	command.arg1 = 1
	command.payload = _designation_payload(PackedInt32Array([
		WorldInitScript.tile_index_of(20, 30), WorldInitScript.tile_index_of(21, 30)]))
	var result: CommandsScript.SubmitResult = CommandsScript.SubmitResult.new()
	return _settlement.commands().submit_into(command, result)


func _basin_stock_milli(basin: Vector2i) -> int:
	"""The generated basin's total forage stock across §5.5's five patches, in milli-units."""
	var forage: ForageScript = _settlement.ecology().forage()
	var total: int = 0
	for kind: int in ForageScript.PATCHES_PER_ZONE:
		var row: IntMath.IntResult = forage.patch_row_for_zone(basin, kind)
		assert_true(row.ok, "patch %d resolves" % kind)
		total += forage.stock_milli_of(row.value).value
	return total


func _first_designation_slot() -> int:
	"""The HarvestZone row of the one player designation in this settlement."""
	var forage: ForageScript = _settlement.ecology().forage()
	for slot: int in ForageScript.HARVEST_ZONE_CAPACITY:
		if forage.is_zone_present(slot) and forage.is_designation(slot):
			return slot
	fail("no designation exists")
	return -1


func _published_harvest_ref() -> Vector2i:
	"""The Job reference ARCH-SYS-009 published for this settlement's one designation."""
	var slot: int = _first_designation_slot()
	for kind: int in ForageScript.PATCHES_PER_ZONE:
		var found: Vector2i = _settlement.job_planner().forage_demand_job_of(slot, kind)
		if found != EntityDirectoryScript.NULL_REF:
			return found
	fail("the planner published no harvest")
	return EntityDirectoryScript.NULL_REF


func test_a_paused_zone_edit_resumes_into_one_intent_one_job_and_cancels() -> void:
	"""TASK 04.4'S OWN ACCEPTANCE SENTENCE, minus the screenshots it also asks for.

	"make a next-tick zone/policy edit while paused, see the ghost and unchanged stocks, resume
	and observe one real source intent/job, then cancel." Every step is asserted by value against
	the real stores, through the real clock, in the real composition.
	"""
	var world: WorldInitScript = _generated()
	_bind_game()
	_game.pause_game()
	var basin: Vector2i = world.basin_ref_of(WorldInitScript.BASIN_FOREST_WEST_NORTH)
	var stock_before: int = _basin_stock_milli(basin)
	var zones_before: int = _settlement.ecology().forage().zone_count()
	assert_true(_submit_designation(basin), "the paused edit is admitted")
	for frame: int in 10:
		_game.advance_host_time(TICK_FRAME_USEC)
	assert_equal(_settlement.commands().pending_count(), 1, "THE GHOST: it is still pending")
	assert_equal(_basin_stock_milli(basin), stock_before, "THE STOCKS ARE UNCHANGED")
	assert_equal(_settlement.ecology().forage().zone_count(), zones_before, "and no zone exists")
	assert_equal(_settlement.job_queue_length(), 0, "and no job exists")
	_game.resume_game()
	for frame: int in 3:
		_game.advance_host_time(TICK_FRAME_USEC)
	assert_equal(_settlement.commands().pending_count(), 0, "the resumed tick drains the edit")
	assert_equal(_settlement.command_dispatch().source_intent_count(), 1, "ONE real source intent")
	assert_equal(_settlement.job_queue_length(), 1, "and ONE real job")
	_cancel_the_harvest()


func _cancel_the_harvest() -> void:
	"""Cancel the published harvest through a real CANCEL_JOB command, and prove it took."""
	var harvest: Vector2i = _published_harvest_ref()
	var command: CommandsScript.Command = CommandsScript.Command.new()
	command.reset()
	command.kind = COMMAND_KIND_CANCEL_JOB
	command.target_slot = harvest.x
	command.target_generation = harvest.y
	var result: CommandsScript.SubmitResult = CommandsScript.SubmitResult.new()
	assert_true(_settlement.commands().submit_into(command, result),
		"the cancellation is admitted")
	for frame: int in 2:
		_game.advance_host_time(TICK_FRAME_USEC)
	assert_equal(_settlement.commands().pending_count(), 0, "the cancellation drained")
	var job_slot: int = _settlement.directory().get_typed_row(harvest)
	assert_equal(_settlement.jobs().state_of(job_slot).value, JobsScript.JOB_STATE_CANCELLED,
		"and the harvest is CANCELLED")


func test_the_published_harvest_is_never_advanced_to_job_state_work() -> void:
	"""04.4: "No delivered output is expected until task 05". QUEUED or RESERVED, never WORK."""
	var world: WorldInitScript = _generated()
	_bind_game()
	assert_true(_submit_designation(world.basin_ref_of(WorldInitScript.BASIN_FOREST_WEST_NORTH)),
		"the designation is admitted")
	for frame: int in 120:
		_game.advance_host_time(TICK_FRAME_USEC)
	var job_slot: int = _settlement.directory().get_typed_row(_published_harvest_ref())
	var state: int = _settlement.jobs().state_of(job_slot).value
	assert_true(state != JobsScript.JOB_STATE_WORK, "four seconds of ticks write no WORK state")
	assert_true(state == JobsScript.JOB_STATE_QUEUED or state == JobsScript.JOB_STATE_RESERVED,
		"it is QUEUED or RESERVED, which is what a settlement without movement can reach")
	assert_equal(_settlement.accepted_mwu_last_tick(), 0, "and no work unit was accepted")


func test_a_replayed_command_in_the_running_loop_produces_no_second_job() -> void:
	"""The identity guard, through the whole composition rather than against the dispatcher alone."""
	var world: WorldInitScript = _generated()
	_bind_game()
	var basin: Vector2i = world.basin_ref_of(WorldInitScript.BASIN_FOREST_WEST_NORTH)
	assert_true(_submit_designation(basin), "the designation is admitted")
	for frame: int in 5:
		_game.advance_host_time(TICK_FRAME_USEC)
	assert_equal(_settlement.job_queue_length(), 1, "one job exists")
	var zones: int = _settlement.ecology().forage().zone_count()
	assert_true(_replay_first_command(basin), "the same envelope is re-admitted at a later tick")
	for frame: int in 40:
		_game.advance_host_time(TICK_FRAME_USEC)
	assert_equal(_settlement.ecology().forage().zone_count(), zones, "no second designation")
	assert_equal(_settlement.command_dispatch().source_intent_count(), 1, "one source intent")
	assert_equal(_settlement.job_planner().forage_demand_enabled_count(), 1, "one standing demand")
	assert_equal(_settlement.job_queue_length(), 1, "and still exactly one job")


func _replay_first_command(basin: Vector2i) -> bool:
	"""Re-admit the first command's exact envelope at a tick well past the one that ran it."""
	var replay: CommandsScript.Command = CommandsScript.Command.new()
	replay.reset()
	replay.kind = COMMAND_KIND_DESIGNATE_ZONE
	replay.target_slot = basin.x
	replay.target_generation = basin.y
	replay.arg0 = ForageScript.ZONE_TYPE_FORAGE
	replay.arg1 = 1
	replay.payload = _designation_payload(PackedInt32Array([
		WorldInitScript.tile_index_of(20, 30), WorldInitScript.tile_index_of(21, 30)]))
	replay.player_id = 0
	replay.sequence_high = 0
	replay.sequence_low = 0
	replay.execute_tick = _settlement.ticks_run() + 20
	var result: CommandsScript.SubmitResult = CommandsScript.SubmitResult.new()
	return _settlement.commands().admit_stamped_into(replay, result)


func test_a_set_policy_edit_reaches_the_forage_store_in_this_composition() -> void:
	"""The second half of the handoff: SET_POLICY no longer refuses COMMAND_STORE_NOT_BOUND."""
	var world: WorldInitScript = _generated()
	_bind_game()
	assert_true(_submit_designation(world.basin_ref_of(WorldInitScript.BASIN_FOREST_WEST_NORTH)),
		"the designation is admitted")
	for frame: int in 5:
		_game.advance_host_time(TICK_FRAME_USEC)
	var zone: int = _first_designation_slot()
	var forage: ForageScript = _settlement.ecology().forage()
	assert_true(forage.is_zone_enabled(zone), "the designation is enabled")
	var command: CommandsScript.Command = CommandsScript.Command.new()
	command.reset()
	command.kind = COMMAND_KIND_SET_POLICY
	command.target_slot = forage.zone_ref_of(zone).x
	command.target_generation = forage.zone_ref_of(zone).y
	command.arg0 = CommandDispatchScript.POLICY_FORAGE_ZONE_ENABLED
	command.arg1 = 0
	var result: CommandsScript.SubmitResult = CommandsScript.SubmitResult.new()
	assert_true(_settlement.commands().submit_into(command, result),
		"the policy edit is admitted")
	for frame: int in 3:
		_game.advance_host_time(TICK_FRAME_USEC)
	assert_false(forage.is_zone_enabled(zone), "and the store really changed")
	assert_false(_settlement.job_planner().is_forage_demand_enabled(zone),
		"with ARCH-SYS-009's standing demand stopped alongside it")


func test_repeating_a_policy_edit_creates_no_second_job() -> void:
	"""SET_POLICY is idempotent by content, so a redelivered enable cannot duplicate work."""
	var world: WorldInitScript = _generated()
	_bind_game()
	assert_true(_submit_designation(world.basin_ref_of(WorldInitScript.BASIN_FOREST_WEST_NORTH)),
		"the designation is admitted")
	for frame: int in 5:
		_game.advance_host_time(TICK_FRAME_USEC)
	assert_equal(_settlement.job_queue_length(), 1, "one job exists")
	var ref: Vector2i = _settlement.ecology().forage().zone_ref_of(_first_designation_slot())
	for repeat: int in 3:
		var command: CommandsScript.Command = CommandsScript.Command.new()
		command.reset()
		command.kind = COMMAND_KIND_SET_POLICY
		command.target_slot = ref.x
		command.target_generation = ref.y
		command.arg0 = CommandDispatchScript.POLICY_FORAGE_ZONE_ENABLED
		command.arg1 = 1
		var result: CommandsScript.SubmitResult = CommandsScript.SubmitResult.new()
		assert_true(_settlement.commands().submit_into(command, result),
			"repeat %d is admitted" % repeat)
	for frame: int in 40:
		_game.advance_host_time(TICK_FRAME_USEC)
	assert_equal(_settlement.job_planner().forage_demand_enabled_count(), 1, "one demand")
	assert_equal(_settlement.job_queue_length(), 1, "and still exactly one job")


func test_world_generation_alone_creates_no_job_and_no_intent() -> void:
	"""R06-JOB-001: "World-generation basin creation alone shall create no harvest demand"."""
	_generated()
	_bind_game()
	for frame: int in 60:
		_game.advance_host_time(TICK_FRAME_USEC)
	assert_equal(_settlement.ecology().forage().zone_count(), 7, "seven generated basins")
	assert_equal(_settlement.job_queue_length(), 0, "and not one job")
	assert_equal(_settlement.command_dispatch().source_intent_count(), 0, "nor one source intent")
	assert_equal(_settlement.job_planner().forage_demand_enabled_count(), 0, "nor one demand")


# --- ARCH-SYS-009 and ARCH-SYS-023 as composed stages -------------------------------------------

func test_the_planner_is_composed_over_this_settlements_own_stores() -> void:
	"""A second Job or HarvestZone store would publish work nothing in this loop could select."""
	assert_not_null(_settlement.job_planner(), "ARCH-SYS-009 is composed")
	assert_true(_settlement.job_planner().jobs() == _settlement.jobs(),
		"planning into the Job store the selector reads")
	assert_true(_settlement.job_planner().forage() == _settlement.ecology().forage(),
		"over ARCH-SYS-005's own HarvestZone store")
	assert_true(_settlement.job_planner().farming() == _settlement.farming(),
		"and servicing the FarmPlot rows ARCH-SYS-006 integrates")


func test_the_measured_stage_list_matches_what_actually_runs() -> void:
	"""The header's stage list is a count of dispatched call sites; this asserts the tick half."""
	_populated()
	assert_equal(_settlement.tick_stage_count(), 7, "seven stages are dispatched per tick")
	for stage: int in _settlement.tick_stage_count():
		assert_true(String(_settlement.tick_stage_name(stage)).begins_with("ARCH-SYS-"),
			"stage %d names the ARCH-SYS system it dispatches" % stage)
	assert_equal(_settlement.tick_stage_name(_settlement.tick_stage_count()), &"",
		"and one past the last names nothing")
	assert_false(_settlement.tick_stage_usec_at(-1).ok, "a negative stage index refuses")
	assert_false(_settlement.tick_stage_usec_at(7).ok, "and so does one past the last")


func test_every_stage_is_measured_on_every_tick() -> void:
	"""Per-stage measurement, not a budget: nothing here compares the numbers to REQ-SET-163."""
	_populated()
	for stage: int in _settlement.tick_stage_count():
		assert_false(_settlement.mean_tick_stage_usec(stage).ok,
			"stage %d has no mean before the first tick" % stage)
	_run_ticks(1, 60)
	for stage: int in _settlement.tick_stage_count():
		var last: IntMath.IntResult = _settlement.tick_stage_usec_at(stage)
		assert_true(last.ok, "stage %d reports its most recent cost" % stage)
		assert_true(last.value >= 0, "which is a real elapsed measurement")
		assert_true(_settlement.mean_tick_stage_usec(stage).ok, "and a mean over the run")


func test_the_presentation_extract_captures_every_tick() -> void:
	"""ARCH-SYS-023 runs LAST, so its snapshot is of a tick every other stage has finished."""
	_populated()
	assert_equal(_settlement.presentation().capture_count(), 0, "nothing captured yet")
	_run_ticks(1, 12)
	assert_equal(_settlement.presentation().capture_count(), 12, "one frame per tick")
	assert_equal(_settlement.refused_extract_count(), 0, "and none refused")
	assert_equal(_settlement.presentation().captured_tick().value, 12, "the latest tick")
	var read: IntMath.IntResult = IntMath.IntResult.new()
	assert_true(_settlement.presentation().value_into(
		PresentationExtractScript.FIELD_POPULATION, read), "the population field is readable")
	assert_equal(read.value, _settlement.population(), "and agrees with the settlement")


func test_hiding_a_presentation_layer_changes_no_authoritative_value() -> void:
	"""04.4: "hiding layers does not change truth", asserted against the settlement's own stores."""
	var world: WorldInitScript = _generated()
	_bind_game()
	var basin: Vector2i = world.basin_ref_of(WorldInitScript.BASIN_FOREST_WEST_NORTH)
	assert_true(_submit_designation(basin), "the designation is admitted")
	for frame: int in 5:
		_game.advance_host_time(TICK_FRAME_USEC)
	var stock: int = _basin_stock_milli(basin)
	var zones: int = _settlement.ecology().forage().zone_count()
	var jobs: int = _settlement.job_queue_length()
	var living: int = _settlement.living_count()
	for layer: int in PresentationExtractScript.LAYER_COUNT:
		assert_true(_settlement.presentation().set_layer_visible(layer, false),
			"layer %d is hidden" % layer)
	for frame: int in 20:
		_game.advance_host_time(TICK_FRAME_USEC)
	assert_equal(_basin_stock_milli(basin), stock, "the generated stock is untouched")
	assert_equal(_settlement.ecology().forage().zone_count(), zones, "so is the zone count")
	assert_equal(_settlement.job_queue_length(), jobs, "so is the job queue")
	assert_equal(_settlement.living_count(), living, "and so is the population")
	assert_equal(_settlement.refused_extract_count(), 0, "capture kept running while hidden")


func test_the_planner_day_boundary_is_not_a_req_set_007_leg() -> void:
	"""ARCH-SYS-009's midnight is its own maintenance; the leg log must not claim it is a leg."""
	_populated()
	assert_true(_settlement.run_day_boundary(2, SEASON_SPRING), "the boundary runs")
	assert_equal(_settlement.refused_planner_day_count(), 0, "the planner's midnight ran")
	assert_equal(_settlement.daily_leg_count(), 3,
		"and the log still holds exactly the three REQ-SET-007 legs this system owns")


func test_every_stage_closes_its_window_exactly_once_per_tick() -> void:
	"""A stage that stopped being dispatched, or was closed against another stage's index, shows up.

	The microsecond figures cannot catch that: an unclosed stage simply keeps its previous value,
	which is still a non-negative number. The measurement COUNT can, and does.
	"""
	_populated()
	_run_ticks(1, 45)
	for stage: int in _settlement.tick_stage_count():
		var measured: IntMath.IntResult = _settlement.tick_stage_measured_count(stage)
		assert_true(measured.ok, "stage %d reports its measurement count" % stage)
		assert_equal(measured.value, _settlement.ticks_run(),
			"stage %d was measured exactly once per tick" % stage)
	assert_false(_settlement.tick_stage_measured_count(-1).ok, "an unknown stage refuses")


func test_the_planner_midnight_is_counted_rather_than_assumed() -> void:
	"""With no plot and no designation the planner's midnight has no visible effect of its own."""
	_populated()
	assert_equal(_settlement.planner_day_count(), 0, "no midnight has run")
	assert_true(_settlement.run_day_boundary(2, SEASON_SPRING), "the first boundary runs")
	assert_equal(_settlement.planner_day_count(), 1, "ARCH-SYS-009's midnight ran once")
	assert_true(_settlement.run_day_boundary(3, SEASON_SPRING), "the second boundary runs")
	assert_equal(_settlement.planner_day_count(), 2, "and again on the next day")
	assert_equal(_settlement.refused_planner_day_count(), 0, "neither refused")


func test_a_repeated_tick_index_is_counted_as_a_refused_extract() -> void:
	"""The snapshot's tick latch is observable from here, so a silently dropped one is not."""
	_populated()
	assert_true(_settlement.run_tick(5), "tick 5 runs")
	assert_equal(_settlement.refused_extract_count(), 0, "its capture succeeded")
	assert_true(_settlement.run_tick(5), "the same tick index runs again")
	assert_equal(_settlement.refused_extract_count(), 1,
		"and ARCH-SYS-023 refused to photograph it twice")
	assert_equal(_settlement.presentation().capture_count(), 1, "one frame, not two")


func test_a_refused_interval_sweep_still_extracts_the_tick() -> void:
	"""A presentation frame is taken even on a tick that refused, so the UI cannot freeze silently."""
	_populated()
	_run_ticks(1, 3)
	var before: int = _settlement.presentation().capture_count()
	assert_equal(before, 3, "three frames so far")
	assert_false(_settlement.run_tick(-1), "an invalid tick refuses before any stage runs")
	assert_equal(_settlement.presentation().capture_count(), before,
		"and takes no frame, because no tick was committed")


func test_a_command_due_at_tick_one_is_not_committed_by_tick_zero() -> void:
	"""ARCH-CMD-001 stamps `completed_tick+1`, so the stage must commit AT that tick, not before.

	Added after mutation testing: changing the stage's argument to `tick_index + 1` -- committing
	every player edit one whole tick early -- passed the entire suite, because every other test
	only ever ran the tick a command was already due at. This is the test that can see it.
	"""
	var settlement: SettlementSystemScript = _populated()
	var resident: Vector2i = settlement.residents().ref_of(0)
	var command: CommandsScript.Command = CommandsScript.Command.new()
	command.reset()
	command.kind = COMMAND_KIND_NAME_RESIDENT
	command.target_slot = resident.x
	command.target_generation = resident.y
	command.payload = "Rowan".to_utf8_buffer()
	var result: CommandsScript.SubmitResult = CommandsScript.SubmitResult.new()
	assert_true(settlement.commands().submit_into(command, result), "the edit is admitted")
	assert_equal(settlement.commands().pending_count(), 1, "and queued for the next tick")
	assert_true(settlement.run_tick(0), "the tick BEFORE its due tick runs")
	assert_equal(settlement.commands_committed_last_tick(), 0, "committing nothing")
	assert_equal(settlement.commands().pending_count(), 1, "and leaving it queued")
	assert_true(settlement.run_tick(1), "its own due tick runs")
	assert_equal(settlement.commands_committed_last_tick(), 1, "and commits it")
	assert_equal(settlement.commands().pending_count(), 0, "leaving the queue empty")
