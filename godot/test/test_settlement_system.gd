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
const ResidentsScript := preload("res://scripts/core/residents.gd")
const WorldInitScript := preload("res://scripts/core/world_init.gd")
const WorldItemsScript := preload("res://scripts/core/item_definitions.gd")
const WorldInventoryScript := preload("res://scripts/core/inventory.gd")
const ForageScript := preload("res://scripts/core/forage.gd")
const JobPlannerScript := preload("res://scripts/core/job_planner.gd")
const PresentationExtractScript := preload("res://scripts/core/presentation_extract.gd")
const StockAgeScript := preload("res://scripts/core/stock_age.gd")
const ResourceNodesScript := preload("res://scripts/core/resource_nodes.gd")
const FishingScript := preload("res://scripts/core/fishing.gd")
const FarmingScript := preload("res://scripts/core/farming.gd")
const RngScript := preload("res://scripts/core/rng.gd")
const OrchardHiveScript := preload("res://scripts/core/orchard_hive.gd")
const BuildingsScript := preload("res://scripts/core/buildings.gd")
const ConstructionScript := preload("res://scripts/core/construction.gd")
const CatalogScript := preload("res://scripts/core/catalog.gd")
const TransformsScript := preload("res://scripts/core/transforms.gd")

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

## GDD §5.1's world content, restated from `test_world_init.gd`'s own derived census: 1695
## ResourceNode rows, 7 HarvestZone basins and 3 FishHabitat rows.
const GENERATED_RESOURCE_NODES: int = 1695
const GENERATED_BASINS: int = 7
const GENERATED_FISH_HABITATS: int = 3
## §5.1: "Ore footprints replace tree nodes". Each 4x4 deposit covers exactly four tree centres,
## so the two deposits destroy eight nodes that were CREATED first -- and §4.2 never reuses a
## persistent id, so those eight consume one each and never appear in the live census above.
const REPLACED_TREE_NODES: int = 8
## Every generated entity takes one id out of §4.2's single persistent id space -- AFTER the cohort
## since R-INIT-ID-001, which is what makes the world's first id 13 rather than the cohort's 1714.
const WORLD_PERSISTENT_IDS: int = (GENERATED_RESOURCE_NODES + REPLACED_TREE_NODES
	+ GENERATED_BASINS + GENERATED_FISH_HABITATS)
## The generated world's LIVE directory rows: the replaced tree nodes are not among them.
const WORLD_LIVE_ROWS: int = (GENERATED_RESOURCE_NODES + GENERATED_BASINS
	+ GENERATED_FISH_HABITATS)

## GDD §5.1: "A fixed-seed tutorial uses seed 20260905." The only seed the section authors, and
## the only one a boot with no New Settlement form can legitimately use.
const TUTORIAL_WORLD_SEED: int = 20260905
## §5.1: "starting at year 1/spring/day 1/06:00". Day 1 is the earliest day a store accepts.
const OPENING_DAY: int = 1

## GDD §5.1's cohort composition, in the sentence's own order: "6 mice, 2 moles, 2 otters,
## 2 squirrels".
const COHORT_SPECIES_KEYS: Array[StringName] = [&"mouse", &"mole", &"otter", &"squirrel"]
const COHORT_SPECIES_COUNTS: Array[int] = [6, 2, 2, 2]
## "active job skills level 2 except Rowan KEEP 3".
const INITIAL_SKILL_LEVEL: int = 2
const WARDEN_KEEP_LEVEL: int = 3
## "Warden KEEP XP=45000; other active initial skills XP=20000; reserved index 3 XP=0."
const INITIAL_SKILL_XP: int = 20000
const WARDEN_KEEP_XP: int = 45000

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

class RefusingCohortSettlement extends SettlementSystemScript:
	"""A settlement whose §5.1 cohort creation always refuses, over a world that generated fine.

	The only way to reach `create_generated_settlement()`'s rollback from outside: the real cohort
	refuses on a full store or a failed component attach, neither of which a caller can arrange
	once the emptiness precondition has passed.
	"""

	const REFUSAL: StringName = &"TEST_COHORT_REFUSED"

	func create_initial_settlement() -> bool:
		"""Refuse rather than spawn, recording the reason exactly as the real path would."""
		return _refuse(REFUSAL)


class BlockedCohortPreflightSettlement extends SettlementSystemScript:
	"""A settlement whose cohort preflight always refuses, with the world plan already staged.

	The real preflight checks the species catalog, the row capacities, the schedule template and
	the opening day's weather, none of which a caller can break from outside once the shipped
	catalogs compile. Overriding it is how the CALL SITE's obligation gets tested: a refusal there
	must stop the transaction before the reset, not after it.
	"""

	const REFUSAL: StringName = &"TEST_COHORT_PREFLIGHT_REFUSED"

	func _refuse_cohort_preflight() -> StringName:
		"""Refuse the cohort before the transaction opens, exactly as a real failure would."""
		return REFUSAL


class SeedObservingSettlement extends SettlementSystemScript:
	"""A settlement that records what the world looked like AT the moment the cohort was created.

	R-INIT-ID-001 step 2 requires the RNG streams seeded "before consumers use them", and step 3
	puts the cohort before terrain publication. Both are statements about an instant inside one
	call, so they can only be observed from inside it.
	"""

	var seeded_when_cohort_created: bool = false
	var nodes_when_cohort_created: int = -1
	var published_when_cohort_created: bool = true

	func create_initial_settlement() -> bool:
		"""Record the seed, census and publication state, then spawn the real §5.1 cohort."""
		seeded_when_cohort_created = rng().is_seeded()
		nodes_when_cohort_created = ecology().resource_nodes().count()
		published_when_cohort_created = world().is_published()
		return super()


class PoseObservingSettlement extends SettlementSystemScript:
	"""A settlement that records what the world looked like AT the moment the poses were written.

	INIT-POSE-R01 §2.2 requires the placement validated against the PREPARED world, before any
	generated settlement is published. That is a statement about an instant inside one call, so
	it can only be observed from inside it.
	"""

	var published_when_placed: bool = true
	var nodes_when_placed: int = -1
	var living_when_placed: int = -1

	func _place_initial_cohort() -> bool:
		"""Record the publication state and census, then run the real placement."""
		published_when_placed = world().is_published()
		nodes_when_placed = ecology().resource_nodes().count()
		living_when_placed = residents().living_count()
		return super()


class ReversedIdResidents extends ResidentsScript:
	"""A cohort whose persistent ids run BACKWARDS against its slot order, and nothing else.

	INIT-POSE-R01 §4: "Vary allocation slots and iteration order in isolated fixtures while
	keeping persistent IDs." On a fresh directory ids are minted in slot order, so a production
	world can never separate "by persistent id" from "by slot" -- the two agree on every row.
	Overriding the id reader is the only way to make them disagree, and it changes nothing else:
	the rows, the references and the directory are the real store's.
	"""

	func persistent_id_of(slot: int) -> IntMath.IntResult:
		"""Report the reverse of the real id, so slot 0 carries id 12 and slot 11 carries id 1."""
		var real: IntMath.IntResult = super(slot)
		if not real.ok:
			return real
		var flipped: IntMath.IntResult = IntMath.IntResult.new()
		flipped.succeed(COHORT_SIZE + 1 - real.value)
		return flipped


class PlannedApronWorld extends WorldInitScript:
	"""A world plan that claims a resource node IS planned on one of the twelve apron tiles.

	The authored map can never produce this: §5.1's clear mask reserves the row before resource
	placement, and a planned tree requires UNCLEARED ground. So the exclusion rule's refusing
	branch is unreachable through generation, and only a fixture can execute it. `plan_tile` is
	the one thing overridden; everything else is the real generator's.
	"""

	var plan_tile: int = 0
	var plan_is_grove: bool = false
	var plan_refuses: bool = false

	func planned_tree_centre_count() -> int:
		"""One planned centre unless this fixture is exercising the grove list instead."""
		return 0 if plan_is_grove else 1

	func planned_grove_count() -> int:
		"""One planned grove node when this fixture is exercising the grove list."""
		return 1 if plan_is_grove else 0

	func planned_tree_centre_at(_index: int) -> IntMath.IntResult:
		"""Report the fixture's tile, or a refusal when the plan reader itself is failing."""
		return _planned()

	func planned_grove_at(_index: int) -> IntMath.IntResult:
		"""Report the fixture's tile, or a refusal when the plan reader itself is failing."""
		return _planned()

	func _planned() -> IntMath.IntResult:
		"""One plan entry: either the fixture's tile or an explicit refusal to read it."""
		var out: IntMath.IntResult = IntMath.IntResult.new()
		if plan_refuses:
			out.refuse("TEST_PLAN_UNREADABLE")
			return out
		out.succeed(plan_tile)
		return out


class HistoryBreakingTransforms extends TransformsScript:
	"""A pose store whose `place()` leaves a PREVIOUS pose behind, and is otherwise the real one.

	A spawn has no history: `place()` writes previous = current so a renderer interpolating into
	the first frame does not drag a body out of somewhere it has never been. A store that got that
	wrong would still read back the right CURRENT coordinates, so only the settlement's own
	read-back check can catch it -- and only a fixture can make it happen.
	"""

	func place(ref: Vector2i, x: int, y: int, z: int, yaw: int) -> bool:
		"""Write the correct current pose, but leave a previous pose one tile west of it."""
		if not super(ref, x - 2048, y, z, yaw):
			return false
		return super.advance(ref, x, y, z)


class OccupiedRowTransforms extends TransformsScript:
	"""A pose store that reports every row as ALREADY PLACED, and is otherwise the real one.

	The precondition this exercises is the one that stops a second placement silently replacing a
	pose that is already bound to this entity -- a reused typed row, or a second placement pass.
	"""

	func is_bound(_ref: Vector2i) -> bool:
		"""Claim every row already holds a placed pose."""
		return true


class HistoryBreakingSettlement extends SettlementSystemScript:
	"""A settlement whose Transform store breaks the previous = current rule. See the store."""

	func _init() -> void:
		"""Compose the real settlement, then swap in the misbehaving pose store."""
		super()
		_transforms = HistoryBreakingTransforms.new(directory())


class OccupiedRowSettlement extends SettlementSystemScript:
	"""A settlement whose Transform store reports every candidate row already placed."""

	func _init() -> void:
		"""Compose the real settlement, then swap in the already-bound pose store."""
		super()
		_transforms = OccupiedRowTransforms.new(directory())


var _settlement: SettlementSystemScript = null
var _game: GameManagerScript = null
var _boundaries: Array[int] = []


func before_each() -> void:
	"""Build a settlement outside the scene tree, so `_ready()` never binds the autoload clock."""
	_settlement = SettlementSystemScript.new()
	_boundaries = []


func after_each() -> void:
	"""Free the nodes this test built, and hand the SHARED pause queue back the way it was found.

	STOCK-SEED-R01's critical pause is submitted into `GameManager`'s ONE R07-SCHED-001 queue --
	the production path, because a test double would prove nothing about it -- and that autoload
	outlives this suite. A CRITICAL hold left standing would be this suite editing the state
	every later suite runs against, so it is dropped here.
	"""
	if _settlement != null:
		_settlement.free()
		_settlement = null
	if _game != null:
		_game.free()
		_game = null
	GameManager.scheduler_events().clear()
	GameManager.clock().set_pause(SimClockScript.CRITICAL, false)


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


# --- ARCH-SYS-004 StockAge (decision 0085) -------------------------------------------------------

## GDD §5.8's covered-store factor and spring temperature factor, transcribed, and the
## milli-hours one game hour costs at their product: floor(1000 * 1000 / 1000).
const COVERED_STORE_FACTOR: int = 1000
const SPRING_TEMPERATURE_FACTOR: int = 1000
const COVERED_SPRING_MILLI_HOURS: int = 1000
## §4.2's owner EntityRef is not what this suite is testing; any live-looking pair will do,
## because `inventory.gd` stores the owner and does not resolve it.
const STORE_OWNER: Vector2i = Vector2i(3, 1)
const STORE_MASS_G: int = 1000000


func _declared_store_with_grain(settlement: SettlementSystemScript) -> Vector2i:
	"""Put one 4 U grain lot into a declared covered store inside the settlement's OWN inventory."""
	var inventory: WorldInventoryScript = settlement.inventory()
	var made: WorldInventoryScript.OpResult = inventory.create_container(
		STORE_OWNER, STORE_MASS_G, WorldInventoryScript.FILTERS_ACCEPT_ALL, 0, true)
	settlement.stock_age().declare_storage_class(
		made.ref, StockAgeScript.STORAGE_COVERED_STORE, false)
	var grain: int = settlement.item_definitions().compiled_id(&"grain")
	return inventory.create_lot(made.ref, grain, 4000, 0, 0, 0, 0, 0).ref


func test_the_settlement_registers_its_item_catalog_into_its_own_inventory() -> void:
	"""ARCH-SYS-004 needs shelf lives, so the §4.3 catalog is composed with the lot store."""
	assert_true(_settlement.item_definitions().is_loaded(), "the catalog loaded")
	assert_equal(_settlement.item_definitions().item_count(), 61,
		"all sixty-one v2 catalog items are compiled")
	var grain: int = _settlement.item_definitions().compiled_id(&"grain")
	assert_true(_settlement.inventory().is_item_registered(grain),
		"and each one is registered into the inventory ARCH-SYS-004 ages")
	assert_true(_settlement.stock_age().inventory() == _settlement.inventory(),
		"the aging stage ages THIS settlement's lots, not a detached fixture")


func test_stock_age_runs_on_the_hour_crossing_and_not_on_any_other_tick() -> void:
	"""ARCH-SYS-004's §5 row is "hour crossing", so 23 ticks in 24 must change no age."""
	var lot: Vector2i = _declared_store_with_grain(_settlement)
	for tick: int in range(748, 750):
		assert_true(_settlement.run_tick(tick), "tick %d commits" % tick)
	assert_equal(_settlement.inventory().lot_age_milli_hours(lot), 0,
		"no age accrued on the two ticks before the crossing")
	assert_true(_settlement.run_tick(750), "the crossing tick commits")
	assert_equal(_settlement.inventory().lot_age_milli_hours(lot), COVERED_SPRING_MILLI_HOURS,
		"and exactly one §5.8 hour landed at `(750+4500) mod 750 == 0`")
	assert_true(_settlement.run_tick(751), "the tick after the crossing commits")
	assert_equal(_settlement.inventory().lot_age_milli_hours(lot), COVERED_SPRING_MILLI_HOURS,
		"and added nothing")
	assert_equal(_settlement.refused_stock_hour_count(), 0, "with no refused hour")


func test_the_midnight_leg_logs_aging_without_running_a_second_age_pass() -> void:
	"""ARCH-TICK-002: "never perform a second age pass because the same tick is hourly and daily"."""
	_populated()
	var lot: Vector2i = _declared_store_with_grain(_settlement)
	assert_true(_settlement.run_tick(SimClockScript.FIRST_MIDNIGHT_TICK),
		"the midnight tick runs through the tick path first, as the clock drives it")
	assert_equal(_settlement.inventory().lot_age_milli_hours(lot), COVERED_SPRING_MILLI_HOURS,
		"one hour of age from the crossing")
	assert_true(_settlement.run_day_boundary(2, SEASON_SPRING), "then the day boundary runs")
	assert_equal(_settlement.inventory().lot_age_milli_hours(lot), COVERED_SPRING_MILLI_HOURS,
		"and the daily leg added no second hour")
	assert_equal(_settlement.daily_leg_at(0).value, SettlementSystemScript.LEG_STOCK_AGE,
		"while still logging aging as REQ-SET-007's first leg")


func test_a_day_boundary_with_no_tick_path_behind_it_runs_the_aging_leg_itself() -> void:
	"""The leg is executed rather than logged on trust when nothing else has consumed the tick."""
	_populated()
	var lot: Vector2i = _declared_store_with_grain(_settlement)
	assert_equal(_settlement.stock_age().last_hour_tick(), StockAgeScript.NO_HOUR_RUN,
		"no hourly pass has run")
	assert_true(_settlement.run_day_boundary(2, SEASON_SPRING), "the boundary runs")
	assert_equal(_settlement.stock_age().last_hour_tick(), SimClockScript.FIRST_MIDNIGHT_TICK,
		"and the aging leg consumed the midnight crossing itself")
	assert_equal(_settlement.inventory().lot_age_milli_hours(lot), COVERED_SPRING_MILLI_HOURS,
		"charging exactly one §5.8 hour")


func test_reset_empties_the_stock_layer_and_restores_its_catalog() -> void:
	"""A reset settlement is one settlement's stock, with the item registry still usable."""
	var lot: Vector2i = _declared_store_with_grain(_settlement)
	assert_true(_settlement.run_tick(750), "an hour crossing ages it")
	_settlement.reset()
	assert_false(_settlement.inventory().is_lot_valid(lot), "the lot is gone")
	assert_equal(_settlement.inventory().live_container_count(), 0, "and so is its container")
	assert_equal(_settlement.stock_age().declared_container_count(), 0,
		"every storage declaration went with them")
	assert_equal(_settlement.stock_age().last_hour_tick(), StockAgeScript.NO_HOUR_RUN,
		"and the hourly latch is dropped")
	var grain: int = _settlement.item_definitions().compiled_id(&"grain")
	assert_true(_settlement.inventory().is_item_registered(grain),
		"the catalog is re-registered, because inventory.clear() drops the item registry too")


# --- REQ-SET-007 leg order and ARCH-SYS-005 Ecology (task 03 increment 9) ------------------------

func test_the_boundary_runs_aging_then_the_handover_then_ecology_then_crops() -> void:
	"""REQ-SET-007's five legs are ordered, and only the four with an owner here may appear.

	CHANGED BY DECISION 0085: this assertion previously began at the season handover, because
	ARCH-SYS-004 had no owner. Stock aging is REQ-SET-007's FIRST step and ARCH-TICK-003 places
	the handover "exactly between aging and ecology", so aging must appear BEFORE the handover
	-- aging uses the elapsed interval's season, and the handover is what changes it.
	"""
	_populated()
	assert_true(_settlement.run_day_boundary(37, SEASON_WINTER), "the winter boundary runs")
	assert_equal(_settlement.daily_leg_count(), 4, "exactly four legs executed")
	assert_equal(_settlement.daily_leg_at(0).value, SettlementSystemScript.LEG_STOCK_AGE,
		"ARCH-SYS-004 StockAge first, REQ-SET-007's own first step")
	assert_equal(_settlement.daily_leg_at(1).value, SettlementSystemScript.LEG_SEASON_HANDOVER,
		"then ARCH-TICK-003's handover, between aging and ecology")
	assert_equal(_settlement.daily_leg_at(2).value, SettlementSystemScript.LEG_ECOLOGY,
		"then ARCH-SYS-005 Ecology")
	assert_equal(_settlement.daily_leg_at(3).value, SettlementSystemScript.LEG_CROP_WEATHER,
		"then ARCH-SYS-006 CropWeather, REQ-SET-007's third step")
	assert_false(_settlement.daily_leg_at(4).ok, "and nothing after it")
	assert_equal(String(_settlement.daily_leg_at(4).error), "INVALID_INDEX",
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
	assert_equal(_settlement.daily_leg_count(), 2,
		"aging and the season handover ran and the ecology leg did not")
	assert_equal(_settlement.daily_leg_at(0).value, SettlementSystemScript.LEG_STOCK_AGE,
		"and the replayed boundary logged aging without running a second age pass")


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
	assert_equal(_settlement.daily_leg_count(), 3,
		"aging, the handover and ecology ran; the crops/weather leg did not")


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

func _loaded_items() -> WorldItemsScript:
	"""Load the shipped item catalog, so the generator's request resolves real compiled ids."""
	var items: WorldItemsScript = WorldItemsScript.new()
	assert_true(items.load_default(WorldInventoryScript.new()).ok, "the item catalog loads")
	return items


func _generated() -> WorldInitScript:
	"""Run the settlement's OWN §5.1 initialization and hand back the generator it published with.

	It used to compose a second `WorldInit` over these stores and drive `generate()` directly,
	because this node composed no generator. It composes one now, and R-INIT-ID-001 made the
	difference observable: the settlement's transaction allocates the cohort FIRST, on persistent
	ids 1-12, while the standalone `generate()` wrapper resets the directory and would put the
	world in front of the residents again. The tests below want the real initialization.
	"""
	assert_true(_settlement.create_generated_settlement(_loaded_items()),
		"the settlement initializes (refusal: %s)" % _settlement.last_refusal())
	return _settlement.world()


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
	assert_equal(_settlement.tick_stage_count(), 8, "eight stages are dispatched per tick")
	for stage: int in _settlement.tick_stage_count():
		assert_true(String(_settlement.tick_stage_name(stage)).begins_with("ARCH-SYS-"),
			"stage %d names the ARCH-SYS system it dispatches" % stage)
	assert_equal(_settlement.tick_stage_name(_settlement.tick_stage_count()), &"",
		"and one past the last names nothing")
	assert_false(_settlement.tick_stage_usec_at(-1).ok, "a negative stage index refuses")
	assert_false(_settlement.tick_stage_usec_at(8).ok, "and so does one past the last")


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
	assert_equal(_settlement.daily_leg_count(), 4,
		"and the log still holds exactly the four REQ-SET-007 legs this system owns")


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


# --- REQ-SET-009 whole: generating a world that has somebody in it (decision 0064) --------------
#
# The gap these cover: `world_init.gd` built the world, `create_initial_settlement()` built the
# population, and NOTHING CALLED BOTH -- so a generated world had nobody in it and a booted game
# had twelve residents standing on no terrain. `create_generated_settlement()` is the single
# §5.1 operation, and every test below asserts against the GDD sentence rather than the code.

func _generate() -> bool:
	"""Run REQ-SET-009 over this test's settlement with §5.1's own fixed tutorial seed."""
	return _settlement.create_generated_settlement(_loaded_items())


func _live_persistent_id_at(directory: EntityDirectoryScript, slot: int) -> int:
	"""The persistent id of the live row in `slot`, or 0 when the slot holds none.

	0 is not a sentinel for failure: `ARCH-ID-002` starts persistent ids at 1 and `clear()` fills
	the column with 0, so 0 IS "no live row" in the directory's own encoding.
	"""
	var ref: Vector2i = directory.ref_of_slot(slot)
	if ref == EntityDirectoryScript.NULL_REF:
		return 0
	return directory.get_persistent_id(ref)


func _replaced_tree_node_count() -> int:
	"""Tree nodes §5.1's ore footprints created and then destroyed, derived from this run.

	Planned trees plus decision 0029's two sixteen-node deposits, less the nodes actually
	standing. Nothing is transcribed: the plan counts come off the generator that just ran.
	"""
	var world: WorldInitScript = _settlement.world()
	var planned: int = world.planned_tree_centre_count() + world.planned_grove_count()
	var ore: int = 2 * ResourceNodesScript.DEPOSIT_NODE_COUNT
	return planned + ore - _settlement.ecology().resource_nodes().count()


func _consumed_persistent_ids() -> int:
	"""Every id this settlement has issued: one per live row, plus one per row destroyed since."""
	return _settlement.directory().total_live_count() + _replaced_tree_node_count()


func _cohort_persistent_ids() -> PackedInt32Array:
	"""The twelve starting residents' persistent ids, in resident-row order."""
	var ids: PackedInt32Array = PackedInt32Array()
	ids.resize(COHORT_SIZE)
	for slot: int in COHORT_SIZE:
		ids[slot] = _settlement.residents().persistent_id_of(slot).value
	return ids


func _terrain_image() -> PackedByteArray:
	"""Every published terrain byte, as one comparable image of the generated map."""
	var image: PackedByteArray = PackedByteArray()
	image.resize(WorldInitScript.TILE_COUNT)
	for tile: int in WorldInitScript.TILE_COUNT:
		image[tile] = _settlement.world().terrain_at(tile).value
	return image


func test_generating_a_settlement_produces_the_world_and_the_cohort_together() -> void:
	"""The whole point: after ONE call there is both a world and a population in it."""
	assert_true(_generate(), "REQ-SET-009 runs (refusal: %s)" % _settlement.last_refusal())
	assert_true(_settlement.world().is_published(), "a world is published")
	assert_equal(_settlement.ecology().resource_nodes().count(), GENERATED_RESOURCE_NODES,
		"§5.1's resource nodes stand")
	assert_equal(_settlement.ecology().forage().zone_count(), GENERATED_BASINS,
		"and its seven ecology basins")
	assert_equal(_settlement.ecology().fishing().habitat_count(), GENERATED_FISH_HABITATS,
		"and the estuary's three habitats")
	assert_equal(_settlement.population(), COHORT_SIZE, "and TWELVE RESIDENTS, not zero")
	assert_equal(_settlement.living_count(), COHORT_SIZE, "all of them alive")


func test_an_ungenerated_settlement_has_neither_world_nor_population() -> void:
	"""The before state, pinned: nothing is published and nobody exists until the call is made."""
	assert_false(_settlement.world().is_published(), "no world before generation")
	assert_equal(_settlement.ecology().resource_nodes().count(), 0, "no resource node")
	assert_equal(_settlement.population(), 0, "and no resident")


func test_the_generated_cohort_is_gdd_5_1s_species_mix() -> void:
	"""§5.1: "12 adults (6 mice, 2 moles, 2 otters, 2 squirrels)"."""
	assert_true(_generate(), "the settlement generates")
	var residents: ResidentsScript = _settlement.residents()
	for entry: int in COHORT_SPECIES_KEYS.size():
		var species: IntMath.IntResult = residents.species_id(COHORT_SPECIES_KEYS[entry])
		assert_true(species.ok, "species '%s' is in the catalog" % COHORT_SPECIES_KEYS[entry])
		var counted: int = 0
		for slot: int in ResidentsScript.RESIDENT_CAPACITY:
			if residents.is_present(slot) and residents.species_of(slot).value == species.value:
				counted += 1
		assert_equal(counted, COHORT_SPECIES_COUNTS[entry],
			"%d %s" % [COHORT_SPECIES_COUNTS[entry], COHORT_SPECIES_KEYS[entry]])


func test_the_generated_cohort_starts_at_gdd_5_1s_needs_and_health() -> void:
	"""§5.1: "all five needs 7500, health 100"."""
	assert_true(_generate(), "the settlement generates")
	for slot: int in COHORT_SIZE:
		assert_true(_settlement.residents().is_present(slot), "row %d holds a resident" % slot)
		assert_equal(_settlement.needs().health_of(slot).value, HEALTH_MAX,
			"resident %d starts at health 100" % slot)
		for need: int in NeedsScript.NEED_COUNT:
			assert_equal(_settlement.needs().need_of(slot, need).value, INITIAL_NEED,
				"resident %d need %d starts at 7500" % [slot, need])


func test_the_generated_cohort_carries_gdd_5_1s_skills_and_the_reserved_zero() -> void:
	"""§5.1: "active job skills level 2 except Rowan KEEP 3"; reserved index 3 has XP/level 0."""
	assert_true(_generate(), "the settlement generates")
	var residents: ResidentsScript = _settlement.residents()
	for slot: int in COHORT_SIZE:
		for skill: int in ResidentsScript.SKILL_COUNT:
			var expected_xp: int = INITIAL_SKILL_XP
			var expected_level: int = INITIAL_SKILL_LEVEL
			if skill == ResidentsScript.SKILL_RESERVED_INDEX:
				expected_xp = 0
				expected_level = 0
			elif slot == ResidentsScript.WARDEN_INDEX and skill == ResidentsScript.SKILL_KEEP:
				expected_xp = WARDEN_KEEP_XP
				expected_level = WARDEN_KEEP_LEVEL
			assert_equal(residents.skill_xp_of(slot, skill).value, expected_xp,
				"resident %d skill %d XP" % [slot, skill])
			assert_equal(residents.skill_level_of(slot, skill).value, expected_level,
				"resident %d skill %d level" % [slot, skill])


func test_only_the_warden_is_named_in_the_generated_cohort() -> void:
	"""§5.1 names ID 1 only; §5.3 makes every other name a TRIGGER, so eleven unnamed is correct."""
	assert_true(_generate(), "the settlement generates")
	var residents: ResidentsScript = _settlement.residents()
	assert_true(residents.is_named(ResidentsScript.WARDEN_INDEX), "ID 1 is named")
	assert_equal(residents.name_key_of(ResidentsScript.WARDEN_INDEX),
		ResidentsScript.WARDEN_NAME, "Warden Rowan")
	assert_equal(residents.role_of(ResidentsScript.WARDEN_INDEX).value,
		ResidentsScript.ROLE_WARDEN, "and holds the Warden role")
	var named: int = 0
	for slot: int in COHORT_SIZE:
		if residents.is_named(slot):
			named += 1
	assert_equal(named, 1, "§5.3's naming triggers leave the other eleven unnamed")


func test_every_generated_resident_is_attached_and_ticks() -> void:
	"""A cohort without Priorities, Schedule and JobAgent rows would tick some residents only."""
	assert_true(_generate(), "the settlement generates")
	for slot: int in COHORT_SIZE:
		assert_true(_settlement.priorities().is_present(slot), "row %d has priorities" % slot)
		assert_true(_settlement.schedule().is_present(slot), "row %d has a schedule" % slot)
		assert_true(_settlement.jobs().is_agent_present(slot), "row %d has a job agent" % slot)
	assert_true(_settlement.run_tick(0), "and the whole settlement ticks")


func test_generation_seeds_the_rng_the_settlement_could_not_seed_itself() -> void:
	"""§5.10's second season refuses RNG_NOT_SEEDED without this; §5.1 owns `World.seed`."""
	assert_false(_settlement.rng().is_seeded(), "an ungenerated settlement has no seed")
	assert_true(_generate(), "the settlement generates")
	assert_true(_settlement.rng().is_seeded(), "and REQ-SET-009 seeded all nine streams")
	assert_equal(_settlement.world().published_seed().value, TUTORIAL_WORLD_SEED,
		"on §5.1's own fixed tutorial seed, the only one it authors")


func test_generating_resets_the_job_and_command_state_it_was_composed_over() -> void:
	"""Task 04.3: reset "job and command state before exposing an active world" -- in the LOOP.

	`test_world_init.gd` proves the generator resets the job store and queue it was HANDED. This
	proves the settlement handed it its own: composing the generator over a private Job store or a
	private command queue would leave the running game's stale work standing beside a new world.
	"""
	var created: JobsScript.OpResult = _settlement.jobs().create_job(
		JobsScript.JOB_KIND_HAUL, 1, 0, LARGE_JOB_MWU, 0)
	assert_true(created.ok, "a stray job exists before generation")
	var command: CommandsScript.Command = CommandsScript.Command.new()
	command.reset()
	command.kind = COMMAND_KIND_SET_POLICY
	var result: CommandsScript.SubmitResult = CommandsScript.SubmitResult.new()
	assert_true(_settlement.commands().submit_into(command, result),
		"and an untargeted player edit is queued beside it")
	assert_equal(_settlement.commands().pending_count(), 1, "the queue holds it")
	assert_true(_generate(), "the settlement generates (refusal: %s)" % _settlement.last_refusal())
	assert_equal(_settlement.jobs().job_count(), 0, "which resets THIS settlement's job store")
	assert_equal(_settlement.commands().pending_count(), 0, "and THIS settlement's queue")
	assert_equal(_settlement.directory().live_count(EntityDirectoryScript.KIND_JOB), 0,
		"with the job's directory rows released")


func test_generating_resets_the_farm_plots_it_was_composed_over() -> void:
	"""§5.1 lists no starter FarmPlot, so generation must EMPTY the store it was given.

	The store has to be THIS settlement's: a generator composed over a private FarmPlot store
	would leave ARCH-SYS-006 integrating yesterday's fields under a brand new world.
	"""
	var plot: FarmingScript.OpResult = _settlement.farming().create_plot_at_tile(
		WorldInitScript.tile_index_of(60, 60), WorldInitScript.SOIL_LOAM, OPENING_DAY)
	assert_true(plot.ok, "a field exists before generation (refusal: %s)" % plot.error)
	assert_equal(_settlement.farming().count(), 1, "the FarmPlot store holds it")
	assert_true(_generate(), "the settlement generates (refusal: %s)" % _settlement.last_refusal())
	assert_equal(_settlement.farming().count(), 0,
		"and REQ-SET-009 emptied it: §5.1 authors no starting field")


func test_generating_resets_the_hives_it_was_composed_over() -> void:
	"""§5.1 authors no starting apiary either, and R06-JOB-006 services the hives it finds.

	THE BUILDING ROW IS CREATED AND IMMEDIATELY DESTROYED, deliberately. `create_hive()` validates
	a live `KIND_BUILDING` reference and never dereferences it, and there is no Building store; a
	surviving building row would also be a live row of a kind the generator does not own, which it
	would rightly refuse. Destroying it leaves exactly what this test needs: a live Hive.
	"""
	var building: Vector2i = _settlement.directory().create(EntityDirectoryScript.KIND_BUILDING)
	var hive: OrchardHiveScript.OpResult = _settlement.ecology().orchard_hive().create_hive(
		building, 40, 40, 43, 43, OPENING_DAY)
	assert_true(hive.ok, "an apiary exists before generation (refusal: %s)" % hive.error)
	assert_true(_settlement.directory().destroy(building), "its building row is released")
	assert_equal(_settlement.ecology().orchard_hive().hive_count(), 1, "the hive store holds it")
	assert_true(_generate(), "the settlement generates (refusal: %s)" % _settlement.last_refusal())
	assert_equal(_settlement.ecology().orchard_hive().hive_count(), 0,
		"and REQ-SET-009 emptied ARCH-SYS-005's OWN hive store")


func test_the_generated_cohort_holds_gdd_5_1s_persistent_ids_one_to_twelve() -> void:
	"""§5.1: "12 adults ...; IDs 1-12; ID 1 named Warden Rowan" -- as GLOBAL persistent ids.

	THIS REPLACES `test_the_generated_cohorts_persistent_ids_are_not_gdd_5_1s_one_to_twelve`,
	which asserted that the cohort received 1714-1725 because the world was created first. That
	test was honest about the code and the code was WRONG -- not merely inconvenient: §5.1 states
	the starting ids and §4.2 states one id space across kinds, so a cohort that does not hold
	1-12 fails an authored requirement, and §5.3's `hash(persistent_id, world_seed)` names hangs
	off the same value. Ruling R-INIT-ID-001 settled that the reset which forced that order is a
	reset BEFORE new-world allocation, not one inside terrain publication, so the divergence had
	no owning-spec basis at all. The old assertion is not weakened here, it is reversed, and
	decision 0075 records the arithmetic it retires.
	"""
	assert_true(_generate(), "the settlement generates")
	var residents: ResidentsScript = _settlement.residents()
	var warden: IntMath.IntResult = residents.persistent_id_of(ResidentsScript.WARDEN_INDEX)
	assert_true(warden.ok, "Warden Rowan has a persistent id")
	assert_equal(warden.value, 1, "and it is §5.1's ID 1")
	assert_equal(residents.name_key_of(ResidentsScript.WARDEN_INDEX), ResidentsScript.WARDEN_NAME,
		"the resident holding id 1 is the one §5.1 names")
	for slot: int in COHORT_SIZE:
		var id: IntMath.IntResult = residents.persistent_id_of(slot)
		assert_true(id.ok, "cohort row %d has a persistent id" % slot)
		assert_equal(id.value, slot + 1, "row %d holds id %d" % [slot, slot + 1])


func test_the_world_entities_continue_the_same_counter_from_thirteen() -> void:
	"""R-INIT-ID-001 step 4: "next ID 13 before any subsequent entity allocation".

	Derived, not pinned: every live directory row that is NOT a resident is a world entity, and
	the lowest id among them must be COHORT_SIZE + 1 -- one id space, continuing, with nothing
	reserved and nothing renumbered.
	"""
	assert_true(_generate(), "the settlement generates")
	var directory: EntityDirectoryScript = _settlement.directory()
	var lowest_world_id: int = 0
	var world_rows: int = 0
	for slot: int in EntityDirectoryScript.DIRECTORY_CAPACITY:
		var ref: Vector2i = directory.ref_of_slot(slot)
		if ref == EntityDirectoryScript.NULL_REF \
				or directory.get_kind(ref) == EntityDirectoryScript.KIND_RESIDENT:
			continue
		var id: int = directory.get_persistent_id(ref)
		world_rows += 1
		if lowest_world_id == 0 or id < lowest_world_id:
			lowest_world_id = id
	assert_equal(world_rows, WORLD_LIVE_ROWS, "every generated world row is counted")
	assert_equal(lowest_world_id, COHORT_SIZE + 1,
		"the first world entity follows the twelfth resident")


func test_every_live_persistent_id_is_unique_across_kinds() -> void:
	"""§4.2 EntityIdentity: "IDs unique across kinds" -- audited over the whole directory.

	Residents and world entities now share one run of the counter, so this is the check that the
	new order did not hand a tree node an id the cohort already holds.
	"""
	assert_true(_generate(), "the settlement generates")
	var directory: EntityDirectoryScript = _settlement.directory()
	var seen: Dictionary = {}
	var highest: int = 0
	for slot: int in EntityDirectoryScript.DIRECTORY_CAPACITY:
		var id: int = _live_persistent_id_at(directory, slot)
		if id == 0:
			continue
		assert_false(seen.has(id), "persistent id %d is held once" % id)
		seen[id] = slot
		if id > highest:
			highest = id
	assert_equal(seen.size(), directory.total_live_count(), "one id per live row, and no more")
	assert_true(highest >= seen.size(), "ids never run below the number of rows holding them")


func test_no_destroyed_persistent_id_is_reissued() -> void:
	"""§4.2: ids are "assigned monotonically and never reused", including across the transaction.

	Two destructions are audited: §5.1's eight replaced tree nodes, which are created and then
	destroyed DURING publication, and a resident destroyed afterwards. Neither id may come back.
	"""
	assert_true(_generate(), "the settlement generates")
	var directory: EntityDirectoryScript = _settlement.directory()
	assert_equal(_replaced_tree_node_count(), REPLACED_TREE_NODES,
		"§5.1's ore footprints replaced their tree nodes, consuming ids that never come back")
	var consumed: int = _consumed_persistent_ids()
	var residents: ResidentsScript = _settlement.residents()
	var rowan_id: int = residents.persistent_id_of(ResidentsScript.WARDEN_INDEX).value
	assert_true(residents.despawn(residents.ref_of(ResidentsScript.WARDEN_INDEX)).ok,
		"a resident is removed")
	var replacement: Vector2i = directory.create(EntityDirectoryScript.KIND_RESIDENT)
	assert_true(replacement != EntityDirectoryScript.NULL_REF, "and another is created")
	var replacement_id: int = directory.get_persistent_id(replacement)
	assert_false(replacement_id == rowan_id, "the freed id %d is not reissued" % rowan_id)
	assert_equal(replacement_id, consumed + 1,
		"it continues past every id this world has ever issued")
	assert_true(directory.destroy(replacement), "the probe row is released")


func test_the_next_persistent_id_is_derived_from_every_allocation_event() -> void:
	"""R-INIT-ID-001: derive counter progression "from ALL allocation events", never pin a total.

	The next id is one more than the number of ids this initialization consumed, and that number
	is COUNTED from the run: every live directory row, plus the tree nodes created and then
	destroyed by §5.1's ore footprints. Nothing here hard-codes 1726 -- the ruling's illustrative
	total -- so composing more entities later moves this test's expectation with the code.
	"""
	assert_true(_generate(), "the settlement generates")
	var directory: EntityDirectoryScript = _settlement.directory()
	var consumed: int = _consumed_persistent_ids()
	assert_equal(consumed, directory.total_live_count() + _replaced_tree_node_count(),
		"every allocation event is either a live row or a destroyed one")
	var probe: Vector2i = directory.create(EntityDirectoryScript.KIND_BUILDING)
	assert_true(probe != EntityDirectoryScript.NULL_REF, "one more entity is allocated")
	assert_equal(directory.get_persistent_id(probe), consumed + 1,
		"the counter continues from every allocation this initialization made")
	assert_true(directory.destroy(probe), "the probe row is released")
	# The ruling asks for the next id as evidence and forbids pinning it. Printing the derived
	# value reports it without turning today's composition into tomorrow's expectation.
	print("[R-INIT-ID-001] ids consumed by initialization: %d; next id: %d" % [
		consumed, consumed + 1])


func test_the_same_seed_initializes_identically_under_the_new_order() -> void:
	"""R-INIT-ID-001's determinism evidence: repeat the whole transaction and compare everything.

	Same seed, twice, through reset: the twelve identities, the world census, the accepted seed
	and the terrain image must all match. This is the check that moving the cohort in front of
	generation did not make initialization order-dependent on leftover state.
	"""
	assert_true(_generate(), "the first initialization runs")
	var first_ids: PackedInt32Array = _cohort_persistent_ids()
	var first_terrain: PackedByteArray = _terrain_image()
	var first_nodes: int = _settlement.ecology().resource_nodes().count()
	var first_consumed: int = _consumed_persistent_ids()
	_settlement.reset()
	assert_true(_generate(), "and the second runs over the same seed")
	assert_equal(_cohort_persistent_ids(), first_ids, "the same twelve identities")
	assert_equal(_terrain_image(), first_terrain, "the same terrain image")
	assert_equal(_settlement.ecology().resource_nodes().count(), first_nodes,
		"the same resource node census")
	assert_equal(_consumed_persistent_ids(), first_consumed, "and the same ids consumed")
	assert_equal(_settlement.world().published_seed().value, TUTORIAL_WORLD_SEED,
		"on §5.1's own seed both times")


func test_generation_refuses_a_settlement_that_already_holds_residents() -> void:
	"""The transaction resets the whole settlement, so an occupied one must refuse BEFORE it does.

	This is also what makes R-INIT-ID-001's "a refused initialization retains the previous valid
	world" reachable: a world with residents in it never enters the transaction at all."""
	assert_true(_settlement.create_initial_settlement(), "a cohort exists first")
	assert_false(_generate(), "generating over it is refused")
	assert_equal(_settlement.last_refusal(), ResidentsScript.REFUSE_SETTLEMENT_NOT_EMPTY,
		"and says which rule stopped it")
	assert_equal(_settlement.population(), COHORT_SIZE, "the standing cohort is untouched")
	assert_false(_settlement.world().is_published(), "and no world was published over it")
	assert_equal(_settlement.ecology().resource_nodes().count(), 0, "nothing was created")


func test_an_unloaded_item_catalog_refuses_and_leaves_the_settlement_empty() -> void:
	"""Decision 0059: a refusal leaves every store byte-identical, not a half-initialized world.

	R-INIT-ID-001 step 5's "an empty start returns to empty", and the failure BEFORE composition:
	the catalog cannot bind, so the transaction is never entered and nothing was staged into a
	store to undo.
	"""
	assert_false(_settlement.create_generated_settlement(WorldItemsScript.new()),
		"an unloaded registry cannot bind the seventeen resource ids")
	assert_equal(_settlement.last_refusal(), &"ITEM_BINDING_REGISTRY_NOT_LOADED",
		"and the binding boundary's own code is passed through")
	assert_false(_settlement.world().is_published(), "no world")
	assert_equal(_settlement.ecology().resource_nodes().count(), 0, "no resource node")
	assert_equal(_settlement.population(), 0, "and no half-spawned cohort")
	assert_equal(_settlement.directory().total_live_count(), 0, "and no directory row")


func test_a_refusal_before_the_transaction_retains_the_previous_valid_world() -> void:
	"""R-INIT-ID-001 step 5: "A refused initialization retains the previous valid world."

	The only world that can be standing when this operation is called again is one with residents
	in it, and residents are what the preflight refuses on -- so the retention is proved rather
	than hoped for: the terrain image, the census and all twelve identities must be unchanged
	afterwards, including the ids the ruling is about.
	"""
	assert_true(_generate(), "a valid world stands first")
	var terrain: PackedByteArray = _terrain_image()
	var ids: PackedInt32Array = _cohort_persistent_ids()
	var nodes: int = _settlement.ecology().resource_nodes().count()
	var consumed: int = _consumed_persistent_ids()
	assert_false(_generate(), "a second initialization over it is refused")
	assert_equal(_settlement.last_refusal(), ResidentsScript.REFUSE_SETTLEMENT_NOT_EMPTY,
		"on the occupied-settlement rule")
	assert_equal(_terrain_image(), terrain, "the standing world's terrain is unchanged")
	assert_equal(_cohort_persistent_ids(), ids, "its twelve identities are unchanged")
	assert_equal(_settlement.ecology().resource_nodes().count(), nodes, "its census is unchanged")
	assert_equal(_consumed_persistent_ids(), consumed, "and no id was consumed by the attempt")
	assert_false(_settlement.world().has_prepared_plan(), "with no plan left staged over it")


func test_a_cohort_that_refuses_leaves_no_half_settlement_standing() -> void:
	"""Decision 0059 at world scale: a failure INSIDE the transaction publishes nothing at all.

	R-INIT-ID-001 step 5's "without partial publication", from the one direction a caller can
	provoke. Under the new order the cohort is allocated BEFORE the world, so this failure lands
	between the single reset and publication: the directory must end with no rows of any kind and
	the map must never have been published, rather than a world standing with nobody in it.
	"""
	var settlement: RefusingCohortSettlement = RefusingCohortSettlement.new()
	assert_false(settlement.create_generated_settlement(_loaded_items()),
		"the operation refuses as a whole")
	assert_equal(settlement.last_refusal(), RefusingCohortSettlement.REFUSAL,
		"and reports the cohort's own reason, not a generic one")
	assert_false(settlement.world().is_published(), "no world was published")
	assert_equal(settlement.ecology().resource_nodes().count(), 0, "no resource node")
	assert_equal(settlement.ecology().forage().zone_count(), 0, "and no basin")
	assert_equal(settlement.ecology().fishing().habitat_count(), 0, "and no habitat")
	assert_false(settlement.rng().is_seeded(), "the transaction's seeding was taken back")
	assert_equal(settlement.population(), 0, "leaving nothing standing")
	assert_equal(settlement.directory().total_live_count(), 0, "and no directory row of any kind")
	assert_false(settlement.world().has_prepared_plan(),
		"the staged plan is dropped, so nothing can publish it later")
	settlement.free()


func test_a_refused_cohort_preflight_never_enters_the_transaction() -> void:
	"""Ruling step 1: the cohort is preflighted with everything else, BEFORE the single reset.

	A cohort problem discovered after the reset would already have emptied the settlement; found
	in the preflight it costs nothing at all. The staged world plan must be dropped too, or the
	refusal would leave a world waiting to be published by the next caller.
	"""
	var settlement: BlockedCohortPreflightSettlement = BlockedCohortPreflightSettlement.new()
	assert_false(settlement.create_generated_settlement(_loaded_items()),
		"the operation refuses as a whole")
	assert_equal(settlement.last_refusal(), BlockedCohortPreflightSettlement.REFUSAL,
		"reporting the cohort preflight's own code")
	assert_false(settlement.world().is_published(), "no world was published")
	assert_false(settlement.world().has_prepared_plan(), "and no plan is left staged")
	assert_false(settlement.rng().is_seeded(), "the streams were never seeded")
	assert_equal(settlement.population(), 0, "and nobody was spawned")
	settlement.free()


func test_the_cohort_is_allocated_seeded_and_before_the_world_is_published() -> void:
	"""Ruling steps 2 and 3, observed from INSIDE the transaction rather than inferred after it.

	The streams must already be seeded when the cohort is created -- `crop_weather.prime_day()`
	runs there -- and no world entity may exist yet, because the twelve residents are what takes
	ids 1-12. Both are invisible from outside: afterwards the world is published either way.
	"""
	var settlement: SeedObservingSettlement = SeedObservingSettlement.new()
	assert_true(settlement.create_generated_settlement(_loaded_items()),
		"the settlement initializes (refusal: %s)" % settlement.last_refusal())
	assert_true(settlement.seeded_when_cohort_created,
		"the RNG streams were seeded before the cohort consumed anything")
	assert_equal(settlement.nodes_when_cohort_created, 0,
		"and not one world entity had been allocated yet")
	assert_false(settlement.published_when_cohort_created,
		"the world was published after the cohort, not before it")
	assert_equal(settlement.residents().persistent_id_of(
		ResidentsScript.WARDEN_INDEX).value, 1, "which is how Warden Rowan holds id 1")
	assert_equal(settlement.ecology().resource_nodes().count(), GENERATED_RESOURCE_NODES,
		"and the world still arrived in full")
	settlement.free()


func test_an_abandoned_transaction_does_not_leave_a_plan_that_can_publish_later() -> void:
	"""A held plan outliving a refusal is a world nobody asked for, arriving after the fact.

	`publish_prepared()` is a public step now, so the plan's lifetime is part of the contract:
	once a transaction is abandoned the generator must refuse to publish rather than create
	§5.1's 1705 rows into an empty settlement on the next call from anywhere.
	"""
	var settlement: RefusingCohortSettlement = RefusingCohortSettlement.new()
	assert_false(settlement.create_generated_settlement(_loaded_items()), "the cohort refuses")
	var published: WorldInitScript.GenerateResult = settlement.world().publish_prepared()
	assert_false(published.ok, "a later publish finds no plan")
	assert_equal(published.error, WorldInitScript.REFUSE_NO_PREPARED_PLAN,
		"and says exactly that")
	assert_equal(settlement.ecology().resource_nodes().count(), 0, "nothing was created")
	settlement.free()


func test_a_refused_generation_reports_it_and_spawns_no_cohort() -> void:
	"""A world that refused must not get a population anyway -- that is the gap in reverse.

	`world_init.gd` refuses WORLD_FOREIGN_LIVE_ROWS rather than orphaning a row it does not own,
	and this proves the bootstrap PROPAGATES that instead of pressing on to spawn twelve residents
	into an ungenerated world.
	"""
	var stray: Vector2i = _settlement.directory().create(EntityDirectoryScript.KIND_BUILDING)
	assert_true(stray != EntityDirectoryScript.NULL_REF, "a row of a kind no store here owns")
	assert_false(_generate(), "generation refuses")
	assert_equal(_settlement.last_refusal(), &"WORLD_FOREIGN_LIVE_ROWS",
		"with the generator's own reason, passed through unchanged")
	assert_false(_settlement.world().is_published(), "no world was published")
	assert_equal(_settlement.population(), 0, "and NO cohort was spawned into one that is not there")
	assert_true(_settlement.directory().is_valid(stray), "the foreign row is byte-identical")


func test_resetting_a_generated_settlement_discards_the_world_with_the_cohort() -> void:
	"""A generator still reporting a published map over emptied stores is a half settlement."""
	assert_true(_generate(), "the settlement generates")
	_settlement.reset()
	assert_false(_settlement.world().is_published(), "the map is discarded")
	assert_equal(_settlement.ecology().resource_nodes().count(), 0, "with its resource nodes")
	assert_equal(_settlement.ecology().forage().zone_count(), 0, "and its basins")
	assert_equal(_settlement.population(), 0, "and its population")
	assert_true(_generate(), "and the settlement generates again from empty")
	assert_equal(_settlement.population(), COHORT_SIZE, "with a second full cohort")


func test_a_new_world_restarts_the_id_space_at_rowan() -> void:
	"""R-INIT-ID-001's new-world reset behaviour: every new world begins its id space again.

	The ruling forbids skipping a reset across new worlds, and a second world that continued the
	first world's counter would give its Warden id 1726 instead of 1. The reset therefore happens
	once per transaction, BEFORE allocation -- which is exactly what the ruling relocated.
	"""
	assert_true(_generate(), "the first world is generated")
	assert_equal(_cohort_persistent_ids()[ResidentsScript.WARDEN_INDEX], 1, "with Rowan on id 1")
	var first_consumed: int = _consumed_persistent_ids()
	assert_true(first_consumed > COHORT_SIZE, "and a world beyond the cohort")
	_settlement.reset()
	assert_true(_generate(), "a second world is generated over the emptied settlement")
	assert_equal(_cohort_persistent_ids()[ResidentsScript.WARDEN_INDEX], 1,
		"whose Warden is id 1 again, not %d" % (first_consumed + 1))
	assert_equal(_cohort_persistent_ids()[COHORT_SIZE - 1], COHORT_SIZE,
		"and whose twelfth resident is id 12")


# --- the Building/Room/Furniture store, composed (decision 0087) --------------------------------
#
# `buildings.gd` (decision 0080) landed complete and nothing constructed it. These tests cover
# exactly what constructing it over THIS settlement's directory buys, and -- just as deliberately
# -- what it does not: there is no §7.2 starter settlement, and the counts stay honestly 0.

## A hall origin well clear of the map centre, where `world_init.gd` puts its generated content,
## so a placement in a GENERATED settlement is not competing with terrain features for tiles.
const HALL_ORIGIN_X: int = 20
const HALL_ORIGIN_Z: int = 20

## Three tiles per bed is §5.9's dormitory rule; twelve tiles therefore hold at most four beds.
const DORMITORY_TILES_X: int = 4
const DORMITORY_TILES_Z: int = 3


func _tile(x: int, z: int) -> int:
	"""§5.1's exterior grid index, `z * 128 + x`, restated here rather than read from the store."""
	return z * BuildingsScript.MAP_TILES_X + x


func _m0_mask() -> int:
	"""The unlocked-milestone mask holding M0 alone, which is what §5.11 grants at start."""
	return 1 << int(CatalogScript.MILESTONE["M0"])


func _place_hall() -> Vector2i:
	"""Place §5.9's refuge hall at this suite's fixed origin and hand back its reference."""
	var placed: BuildingsScript.OpResult = _settlement.buildings().place_building(
		int(CatalogScript.BUILDING_DEFINITION["hall"]), _tile(HALL_ORIGIN_X, HALL_ORIGIN_Z), 0,
		_m0_mask())
	assert_true(placed.ok, "the hall must place (refusal: %s)" % placed.error)
	return placed.ref


func _designate_dormitory(hall: Vector2i) -> Vector2i:
	"""Designate a 4x3 dormitory inside the hall's one-tile-inset interior."""
	var tiles: PackedInt32Array = PackedInt32Array()
	for offset_z: int in DORMITORY_TILES_Z:
		for offset_x: int in DORMITORY_TILES_X:
			tiles.append(_tile(HALL_ORIGIN_X + 1 + offset_x, HALL_ORIGIN_Z + 1 + offset_z))
	var room: BuildingsScript.OpResult = _settlement.buildings().designate_room(
		hall, int(CatalogScript.ROOM_TYPE["DORMITORY"]), tiles)
	assert_true(room.ok, "the dormitory must designate (refusal: %s)" % room.error)
	return room.ref


func _place_bed(room: Vector2i, index: int) -> Vector2i:
	"""Place one bed on the `index`th tile of this suite's dormitory footprint."""
	var tile: int = _tile(HALL_ORIGIN_X + 1 + index % DORMITORY_TILES_X,
		HALL_ORIGIN_Z + 1 + index / DORMITORY_TILES_X)
	var bed: BuildingsScript.OpResult = _settlement.buildings().place_furniture(
		room, int(CatalogScript.FURNITURE_DEFINITION["bed"]), tile, 0)
	assert_true(bed.ok, "bed %d must place (refusal: %s)" % [index, bed.error])
	return bed.ref


func test_the_building_store_is_composed_over_this_settlements_one_directory() -> void:
	"""The call decision 0080 named and did not make: `Buildings.new(_directory)`.

	Sharing the directory is the whole substance of the composition. A store built with its own
	allocator would validate every `Furniture.user` against a directory no resident lives in.
	"""
	assert_true(_settlement.buildings() != null, "the settlement composes a Building store")
	assert_true(_settlement.buildings().directory() == _settlement.directory(),
		"over the same directory every other settlement reference is allocated from")
	assert_true(_settlement.building_definitions() == _settlement.buildings().definitions(),
		"and it publishes the store's OWN §4.1-4.3 facts, not a second copy of them")


func test_an_empty_settlement_holds_no_building_room_or_furniture() -> void:
	"""Composition allocates columns; it places nothing. All three counts open at 0."""
	assert_equal(_settlement.buildings().live_building_count(), 0, "no building")
	assert_equal(_settlement.buildings().live_room_count(), 0, "no room")
	assert_equal(_settlement.buildings().live_furniture_count(), 0, "no furniture")
	assert_equal(_settlement.buildings().live_furniture_of_kind(
		int(CatalogScript.FURNITURE_DEFINITION["bed"])), 0, "and no bed for a HUD to count")


func test_a_placed_building_allocates_a_row_in_the_settlements_directory() -> void:
	"""The placement's reference is a live KIND_BUILDING row of the settlement's own allocator."""
	var before: int = _settlement.directory().live_count(EntityDirectoryScript.KIND_BUILDING)
	var hall: Vector2i = _place_hall()
	assert_equal(_settlement.directory().live_count(EntityDirectoryScript.KIND_BUILDING),
		before + 1, "the building row is allocated in the settlement's directory")
	assert_true(_settlement.directory().is_valid_of_kind(hall,
		EntityDirectoryScript.KIND_BUILDING), "and the reference validates there as a BUILDING")
	assert_true(_settlement.buildings().is_live_building(hall), "as well as in the store")


func test_the_bed_counter_reads_live_furniture_rows_and_falls_when_one_is_removed() -> void:
	"""UI §1.1's `Beds` counter source. Its value is rows, not a mask bit and not a cached total.

	Removing one of three beds must leave two. `buildings.gd` recomputes the room mask from the
	room's own chain rather than clearing bits incrementally, and this is the counter half of the
	same property: a per-kind total that tracks removals as well as placements.
	"""
	var bed_id: int = int(CatalogScript.FURNITURE_DEFINITION["bed"])
	var room: Vector2i = _designate_dormitory(_place_hall())
	var first: Vector2i = _place_bed(room, 0)
	_place_bed(room, 1)
	_place_bed(room, 2)
	assert_equal(_settlement.buildings().live_furniture_of_kind(bed_id), 3, "three beds")
	assert_true(_settlement.buildings().remove_furniture(first).ok, "one bed is removed")
	assert_equal(_settlement.buildings().live_furniture_of_kind(bed_id), 2,
		"and the counter falls to two rather than staying at three")


func test_a_bed_takes_a_resident_of_this_settlement_as_its_user() -> void:
	"""REQ-SET-009 bed assignment, the half the shared directory makes possible.

	`set_furniture_user()` validates the reference as a live KIND_RESIDENT row. With a private
	directory this call could only ever have refused, because no resident would exist in it.
	"""
	_settlement.create_initial_settlement()
	var resident: Vector2i = _settlement.residents().ref_of(0)
	assert_true(_settlement.directory().is_valid_of_kind(resident,
		EntityDirectoryScript.KIND_RESIDENT), "the cohort's first resident is a live row")
	var bed: Vector2i = _place_bed(_designate_dormitory(_place_hall()), 0)
	var used: BuildingsScript.OpResult = _settlement.buildings().set_furniture_user(bed, resident)
	assert_true(used.ok, "the bed takes that resident as its user (refusal: %s)" % used.error)
	assert_equal(_settlement.buildings().user_ref_of_furniture(bed), resident,
		"and reads back the very reference `residents()` published")


func test_a_bed_refuses_a_directory_row_that_is_not_a_resident() -> void:
	"""The shared directory is a validator, not just a common pool: kind is still checked."""
	var stray: Vector2i = _settlement.directory().create(
		EntityDirectoryScript.KIND_HARVEST_ZONE)
	assert_true(stray != EntityDirectoryScript.NULL_REF, "a live row of another kind exists")
	var bed: Vector2i = _place_bed(_designate_dormitory(_place_hall()), 0)
	var used: BuildingsScript.OpResult = _settlement.buildings().set_furniture_user(bed, stray)
	assert_false(used.ok, "a harvest zone cannot sleep in a bed")
	assert_equal(used.error, BuildingsScript.REFUSE_STALE_USER_REF, "with the store's own reason")
	assert_equal(_settlement.buildings().user_ref_of_furniture(bed),
		EntityDirectoryScript.NULL_REF, "and the bed is left unoccupied")


func test_resetting_the_settlement_empties_the_building_store_and_its_directory_rows() -> void:
	"""`reset()` must leave no building row and no directory slot allocated to one.

	A store composed into `_init()` but forgotten in `_clear_stores()` would survive a reset and
	hand the next generation a hall nobody placed -- and strand its directory slots as well.
	"""
	var room: Vector2i = _designate_dormitory(_place_hall())
	_place_bed(room, 0)
	assert_equal(_settlement.buildings().live_furniture_count(), 1, "one bed stands")
	_settlement.reset()
	assert_equal(_settlement.buildings().live_building_count(), 0, "no building survives")
	assert_equal(_settlement.buildings().live_room_count(), 0, "no room survives")
	assert_equal(_settlement.buildings().live_furniture_count(), 0, "no furniture survives")
	assert_equal(_settlement.directory().total_live_count(), 0,
		"and the directory holds no row of any kind at all")


func test_a_generated_settlement_still_places_no_building_and_counts_no_bed() -> void:
	"""THE HONEST NEGATIVE. §5.1's hall, twelve beds, hearth and pantry are NOT generated.

	`world_init.gd` publishes terrain, resource nodes, forage basins and the estuary; §5.1's
	built fixture is not among them and this change does not add it. A `Beds` counter wired to
	`live_furniture_of_kind()` today therefore shows a TRUE 0, and the §7.2 starter build remains
	outstanding work. Pinned so no later reader mistakes composition for construction.
	"""
	assert_true(_generate(), "the settlement generates")
	assert_equal(_settlement.population(), COHORT_SIZE, "with its twelve residents")
	assert_true(_settlement.world().is_published(), "and a published world")
	assert_equal(_settlement.buildings().live_building_count(), 0, "and NO starter hall")
	assert_equal(_settlement.buildings().live_furniture_of_kind(
		int(CatalogScript.FURNITURE_DEFINITION["bed"])), 0, "and NO starter beds")


func test_a_building_placed_after_generation_takes_the_next_persistent_id() -> void:
	"""R-INIT-ID-001 is undisturbed: the cohort keeps 1-12 and a building queues behind the world.

	This is what one shared directory means for the id space. A second allocator would have
	restarted the count and handed the hall a persistent id the Warden already holds.
	"""
	assert_true(_generate(), "the settlement generates")
	var ids: PackedInt32Array = _cohort_persistent_ids()
	assert_equal(ids[ResidentsScript.WARDEN_INDEX], 1, "the Warden is still id 1")
	var hall: Vector2i = _place_hall()
	var hall_id: int = _settlement.directory().get_persistent_id(hall)
	assert_true(hall_id > COHORT_SIZE,
		"the hall's persistent id %d is beyond the cohort's twelve" % hall_id)
	assert_equal(_cohort_persistent_ids(), ids, "and no resident id moved")


func test_the_building_store_adds_no_stage_to_the_tick() -> void:
	"""Composition is structural state, not a §5 stage. The dispatch order is unchanged.

	ARCH-SYS-016 RoomHeat is the one stage that would read this store, and it still has no
	connected-heat model, so nothing here is dispatched per tick.

	The eight are command commit, interval, stock age, crop hour, job planner, selection, work
	and presentation — none of which is a building stage. This literal was 7 when the store
	first composed; decision 0085's hourly stock aging added the eighth, so a future bump is
	only legitimate when it can be named here the same way.
	"""
	assert_equal(_settlement.tick_stage_count(), 8,
		"the tick still dispatches exactly the eight stages it did without the store")
	assert_equal(_settlement.tick_stage_count(), SettlementSystemScript.TICK_STAGE_PRESENTATION + 1,
		"and presentation is still the last of them")
	_populated()
	_settlement.run_tick(0)
	assert_equal(_settlement.buildings().live_building_count(), 0,
		"and a tick places nothing of its own")


# --- the Construction store's composition ------------------------------------------------------

func test_the_construction_store_shares_this_settlements_building_store() -> void:
	"""The composition IS the change: a project must act on a building this settlement owns.

	A `Construction` built over its own allocator would open projects, price them, refund them
	and pass its own suite -- and would refuse `open_build()` for every real blueprint, because
	no blueprint would live in that Building store. This asserts the borrow rather than the type.
	"""
	assert_not_null(_settlement.construction(), "the settlement composes a Construction store")
	assert_true(_settlement.construction().buildings() == _settlement.buildings(),
		"the project store must act on THIS settlement's Building rows")
	assert_true(_settlement.construction().directory() == _settlement.directory(),
		"and therefore on this settlement's one directory")
	assert_true(_settlement.construction() == _settlement.construction(),
		"and the accessor must hand back the same store, not a fresh one per call")


func test_a_project_opened_through_the_settlement_names_a_real_building() -> void:
	"""REQ-SET-124 end to end over the composed stores: place, open, and read the join back."""
	assert_true(_generate(), "the settlement generates")
	var hall: Vector2i = _place_hall()
	var project: ConstructionScript.OpResult = _settlement.construction().open_build(hall)
	assert_true(project.ok, "the project opens (%s)" % project.error)
	assert_equal(_settlement.buildings().construction_ref_of_building(hall), project.ref,
		"the Building row names the project this settlement's store published")
	assert_equal(_settlement.construction().subject_ref_of(project.ref), hall,
		"and the project names the building this settlement's store placed")
	assert_equal(_settlement.directory().live_count(
		EntityDirectoryScript.KIND_CONSTRUCTION), 1,
		"the project's slot came out of the one shared directory")


func test_a_generated_settlement_still_holds_no_construction_project() -> void:
	"""Composition is not construction, for the project store exactly as for the building store.

	`world_init.gd` places no blueprint, so there is nothing for a project to be opened against.
	A HUD wired to `live_project_count()` today reads a TRUE 0.
	"""
	assert_equal(_settlement.construction().live_project_count(), 0,
		"an ungenerated settlement holds no project")
	assert_true(_generate(), "the settlement generates")
	assert_equal(_settlement.construction().live_project_count(), 0,
		"and generating one still builds nothing")
	assert_true(_settlement.construction().verify_refund_policies().ok,
		"an empty project column is trivially self-consistent")


func test_resetting_the_settlement_releases_every_project_row() -> void:
	"""`_clear_stores()` empties this store too, so no project survives a reset."""
	assert_true(_generate(), "the settlement generates")
	var project: ConstructionScript.OpResult = _settlement.construction().open_build(_place_hall())
	assert_true(project.ok, "a project opens")
	assert_equal(_settlement.construction().live_project_count(), 1, "one project is live")
	_settlement.reset()
	assert_equal(_settlement.construction().live_project_count(), 0,
		"the reset settlement holds no project")
	assert_false(_settlement.construction().is_live_project(project.ref),
		"and the old project reference no longer validates")


func test_the_construction_store_adds_no_stage_to_the_tick() -> void:
	"""`work.gd` owns the productive tick and does not call this store, so the eight stay eight.

	The eight are command commit, interval, stock age, crop hour, job planner, selection, work
	and presentation. None of them is a construction stage, and adding one would mean naming it
	here with its reason.
	"""
	assert_equal(_settlement.tick_stage_count(), 8,
		"the tick still dispatches exactly the eight stages it did without the project store")
	_populated()
	var project: ConstructionScript.OpResult = _settlement.construction().open_build(_place_hall())
	assert_true(project.ok, "a project opens")
	var work: IntMath.IntResult = IntMath.IntResult.new()
	_settlement.run_tick(0)
	assert_true(_settlement.construction().remaining_mwu_into(project.ref, work),
		"its work reads after a tick")
	assert_equal(work.value,
		_settlement.building_definitions().work_mwu_of(
			int(CatalogScript.BUILDING_DEFINITION["hall"])),
		"and a tick retires none of it, because nothing drives construction work yet")


# --- STOCK-SEED-R01: the critical pause and the exactly-once revalidated retry -----------------
#
# ARCH-SYS-004 refuses and stops, with every collaborating store byte identical; routing that
# refusal to the EXISTING critical-pause path and retrying the same expiry transaction once is
# this system's half, and this is its coverage.
#
# THE CADENCE IS NOT GUESSED AT. 750 ticks to the hour, `(tick + 4500) mod 750 == 0`, first
# midnight 13500. Every crossing used below is a multiple of 750 for that reason, and NEVER
# `tick % 18000`, which is 06:00.

## Inventory's own ceiling on a lot's stored age. A lot created AT it overflows on the very next
## §5.8 hour, which is the one arithmetic integrity failure the shipped catalog can still reach:
## every food mass divides spoiled_food's 250 g/U exactly and every seed's 100 g/U product is
## nowhere near an int64, so neither conversion refusal is inducible through the public API.
const MAX_AGE_MILLI_HOURS: int = 9223372036854774808


func _faulting_hour_setup() -> Vector2i:
	"""A declared store with one grain lot, and a stray open inventory transaction over it.

	The stray transaction is what makes `stock_age.gd`'s `_preflight()` refuse
	INVENTORY_TRANSACTION_OPEN: the hour latch is NOT consumed and nothing is swept, so the whole
	hour stays owed. That is exactly the shape of failure the ruling's retry is for.
	"""
	var lot: Vector2i = _declared_store_with_grain(_settlement)
	_settlement.inventory().begin()
	return lot


func _pumped_critical_hold() -> bool:
	"""Whether the submitted hold has actually reached the shared clock's CRITICAL bit."""
	GameManager.scheduler_events().pump()
	return GameManager.clock().has_pause_reason(SimClockScript.CRITICAL)


func test_a_ledger_failure_in_the_hourly_sweep_raises_the_existing_critical_pause() -> void:
	"""STOCK-SEED-R01: the fault is blocking, through the pause mask that already exists.

	NOT a new pause concept: the bit asserted is `sim_clock.gd`'s CRITICAL, submitted through
	`scheduler_events.gd`'s internal-producer safety hold, and it is checked on the real clock
	after a real pump rather than on a counter this system keeps.
	"""
	_faulting_hour_setup()
	var before: PackedByteArray = _settlement.inventory().state_bytes()
	assert_true(_settlement.run_tick(750), "the tick itself still commits; the stage is not fatal")
	assert_equal(_settlement.stock_integrity_fault(), &"INVENTORY_TRANSACTION_OPEN",
		"the fault carries stock_age.gd's own refusal code")
	assert_equal(_settlement.stock_integrity_fault_tick().value, 750,
		"and names the hour crossing that refused")
	assert_equal(_settlement.stock_integrity_fault_count(), 1, "one fault was raised")
	assert_true(_settlement.is_critical_pause_held(), "this system holds CRITICAL")
	assert_equal(_settlement.stock_pause_refusal(), &"", "and the submission was not refused")
	assert_true(_pumped_critical_hold(), "the hold reached the real clock's pause mask")
	assert_equal(_settlement.inventory().state_bytes(), before,
		"and the refused hour left the lot store byte identical (decision 0059)")


func test_the_faulted_hour_is_retried_exactly_once_and_recovers_the_same_hour() -> void:
	"""The retry re-derives the FAULTED tick, not the tick it happens to run on.

	Tick 750 is the crossing that refused. The pause stops the clock, so the first tick that can
	carry the retry is 751 -- which is NOT an hour crossing -- and the hour that must land is
	still 750's, at 750's elapsed-interval season. A retry that ran `run_hour_into(751)` would
	refuse NOT_AN_HOUR_BOUNDARY and age nothing at all.
	"""
	var lot: Vector2i = _faulting_hour_setup()
	assert_true(_settlement.run_tick(750), "the crossing tick commits with the hour refused")
	assert_true(_settlement.is_stock_retry_pending(), "one retry is owed")
	assert_equal(_settlement.stock_retry_count(), 0, "and none has been attempted yet")
	_settlement.inventory().abort()
	assert_true(_settlement.run_tick(751), "the next tick carries the retry")
	assert_equal(_settlement.stock_retry_count(), 1, "exactly one retry was attempted")
	assert_equal(_settlement.stock_retry_recovered_count(), 1, "and it recovered the hour")
	assert_equal(_settlement.stock_hour().tick, 750,
		"the hour that landed is the FAULTED one, re-derived at its own tick index")
	assert_equal(_settlement.stock_age().last_hour_tick(), 750,
		"so ARCH-SYS-004's latch consumed 750, not 751")
	assert_equal(_settlement.inventory().lot_age_milli_hours(lot), COVERED_SPRING_MILLI_HOURS,
		"and exactly one §5.8 hour of age landed -- the retry adds no second hour")


func test_a_recovered_retry_clears_the_pause_and_the_fault_together() -> void:
	"""Never clear the pause while the failure stands, and always clear it once it does not."""
	_faulting_hour_setup()
	assert_true(_settlement.run_tick(750), "the hour refuses")
	assert_true(_settlement.is_critical_pause_held(), "the pause is held while the fault stands")
	_settlement.inventory().abort()
	assert_true(_settlement.run_tick(751), "the retry runs and recovers")
	assert_equal(_settlement.stock_integrity_fault(), &"", "the fault is closed")
	assert_false(_settlement.is_stock_retry_pending(), "its retry entitlement is spent")
	assert_false(_settlement.is_critical_pause_held(), "and this system no longer holds CRITICAL")
	assert_false(_pumped_critical_hold(), "the clock's CRITICAL bit is released too")
	assert_false(_settlement.is_stock_integrity_halted(), "with nothing halted")


func test_a_retry_that_also_fails_halts_the_simulation_and_is_never_retried_again() -> void:
	"""Design answer 4: a skipped hour is a correctness hole, so no later tick may run.

	The stray transaction is deliberately NOT cleared, so the retry re-derives the same inputs
	and refuses identically. That is the point of revalidating rather than replaying: the second
	refusal is real evidence the fault is unresolved, not a cached verdict.
	"""
	_faulting_hour_setup()
	assert_true(_settlement.run_tick(750), "the hour refuses")
	assert_true(_settlement.run_tick(751),
		"the tick that DISCOVERS the halt still commits, exactly as the faulting tick did")
	assert_equal(_settlement.stock_hour().error, &"INVENTORY_TRANSACTION_OPEN",
		"the retry re-derived the same inputs and refused identically")
	assert_true(_settlement.is_stock_integrity_halted(), "and the fault is now unrecoverable")
	assert_equal(_settlement.stock_retry_count(), 1, "exactly one retry was ever attempted")
	var ticks: int = _settlement.ticks_run()
	assert_false(_settlement.run_tick(752), "every LATER tick refuses")
	assert_equal(_settlement.last_refusal(), &"STOCK_AGE_INTEGRITY_HALT", "naming the halt")
	assert_equal(_settlement.stock_retry_count(), 1, "and no second retry is ever made")
	assert_equal(_settlement.ticks_run(), ticks, "a halted tick is not counted as run")


func test_a_halted_tick_runs_no_stage_and_re_asserts_the_shared_critical_bit() -> void:
	"""Continuing with a skipped hour is the hole; and CRITICAL is a bit somebody else can clear.

	`acknowledge_without_catchup()` clears the WHOLE CRITICAL bit for REQ-SET-008's overload
	ladder, which shares it. This system cannot stop that from `settlement_system.gd`, so it
	re-submits the hold on every refused tick: a wrongly cleared integrity pause costs one
	refused tick instead of resuming an unsafe world.
	"""
	_faulting_hour_setup()
	assert_true(_settlement.run_tick(750), "the hour refuses")
	assert_true(_settlement.run_tick(751), "the retry fails and halts")
	assert_true(_pumped_critical_hold(), "CRITICAL is held, and the queue is now drained")
	var measured: int = _settlement.tick_stage_measured_count(
		SettlementSystemScript.TICK_STAGE_PRESENTATION).value
	GameManager.clock().acknowledge_without_catchup()
	assert_false(GameManager.clock().has_pause_reason(SimClockScript.CRITICAL),
		"an unrelated overload acknowledgement cleared the shared bit")
	assert_false(_settlement.run_tick(752), "the halted tick still refuses")
	assert_equal(_settlement.tick_stage_measured_count(
			SettlementSystemScript.TICK_STAGE_PRESENTATION).value, measured,
		"and dispatched no stage at all")
	assert_true(_pumped_critical_hold(), "while re-asserting CRITICAL on the clock")


func test_only_a_reset_leaves_a_halted_settlement() -> void:
	"""The one exit is `reset()`. No "clear the fault" call exists, deliberately."""
	_faulting_hour_setup()
	assert_true(_settlement.run_tick(750), "the hour refuses")
	assert_true(_settlement.run_tick(751), "the retry fails and halts")
	_settlement.inventory().abort()
	_settlement.reset()
	assert_false(_settlement.is_stock_integrity_halted(), "the reset settlement is not halted")
	assert_equal(_settlement.stock_integrity_fault(), &"", "and carries no fault")
	assert_equal(_settlement.stock_retry_count(), 0, "with the retry ledger emptied")
	assert_false(_settlement.is_critical_pause_held(), "and the CRITICAL hold released")
	var lot: Vector2i = _declared_store_with_grain(_settlement)
	assert_true(_settlement.run_tick(750), "a fresh hour crossing commits again")
	assert_equal(_settlement.inventory().lot_age_milli_hours(lot), COVERED_SPRING_MILLI_HOURS,
		"and ages the new settlement's stock normally")


func test_a_later_hours_fault_earns_its_own_single_retry() -> void:
	"""Design answer 2: the entitlement is keyed to the transaction, not to a sweep or a run.

	A counter that reset every sweep would hand the SAME unrecovered fault a fresh retry every
	hour; a flag that never cleared would leave a settlement that recovered perfectly unable to
	ever fault again. Hour 750 faults and recovers; hour 1500 is a DIFFERENT expiry transaction
	and gets its own one retry.
	"""
	_faulting_hour_setup()
	assert_true(_settlement.run_tick(750), "hour 750 faults")
	_settlement.inventory().abort()
	assert_true(_settlement.run_tick(751), "and recovers on its one retry")
	_settlement.inventory().begin()
	assert_true(_settlement.run_tick(1500), "hour 1500 faults in its turn")
	assert_equal(_settlement.stock_integrity_fault_count(), 2, "a second, separate fault")
	assert_equal(_settlement.stock_integrity_fault_tick().value, 1500, "at its own hour")
	assert_true(_settlement.is_stock_retry_pending(), "with its own retry owed")
	_settlement.inventory().abort()
	assert_true(_settlement.run_tick(1501), "which recovers it")
	assert_equal(_settlement.stock_retry_count(), 2, "two faults, two retries, never three")
	assert_equal(_settlement.stock_retry_recovered_count(), 2, "both recovered")


func test_a_cadence_refusal_is_not_an_integrity_fault_and_pauses_nothing() -> void:
	"""HOUR_ALREADY_RUN means the hour was never owed; pausing for it would fabricate a fault.

	ARCH-TICK-002's idempotence latch refuses a replayed crossing. That refusal changes no state
	and is not arithmetic, ledger or schema failure, so it stays counted and non-fatal.
	"""
	_declared_store_with_grain(_settlement)
	assert_true(_settlement.run_tick(750), "the crossing runs")
	assert_true(_settlement.run_tick(750), "and is replayed")
	assert_equal(_settlement.refused_stock_hour_count(), 1, "the replay refused")
	assert_equal(_settlement.stock_hour().error, &"STOCK_AGE_HOUR_ALREADY_RUN",
		"naming ARCH-TICK-002's latch on the stage's own channel")
	assert_equal(_settlement.stock_integrity_fault(), &"", "but raised no integrity fault")
	assert_equal(_settlement.stock_integrity_fault_count(), 0, "and counted none")
	assert_false(_settlement.is_critical_pause_held(), "nothing was paused")
	assert_false(_settlement.is_stock_integrity_halted(), "and nothing halted")
	assert_false(_settlement.stock_integrity_fault_tick().ok,
		"asking which hour faulted REFUSES rather than answering tick 0")


func _store_with_one_overflowing_lot() -> Vector2i:
	"""One declared store holding a single grain lot already at inventory's age ceiling."""
	var inventory: WorldInventoryScript = _settlement.inventory()
	var made: WorldInventoryScript.OpResult = inventory.create_container(
		STORE_OWNER, STORE_MASS_G, WorldInventoryScript.FILTERS_ACCEPT_ALL, 0, true)
	_settlement.stock_age().declare_storage_class(
		made.ref, StockAgeScript.STORAGE_COVERED_STORE, false)
	var grain: int = _settlement.item_definitions().compiled_id(&"grain")
	return inventory.create_lot(made.ref, grain, 4000, 0, 0, 0, MAX_AGE_MILLI_HOURS, 0).ref


func test_a_per_lot_arithmetic_failure_pauses_and_halts_without_a_retry() -> void:
	"""Every `refused_lots` path in stock_age.gd is arithmetic or ledger failure, so all pause.

	AND NONE OF THEM IS RETRIED, because `stock_age.gd` names no lot ref and publishes no
	per-lot expiry entry point, so there is no transaction to revalidate. That is a named
	blocker in the decision record, not a judgement that this failure deserves less; what this
	file can honour -- the blocking pause and the byte-identical store -- it honours.
	"""
	var lot: Vector2i = _store_with_one_overflowing_lot()
	var before: PackedByteArray = _settlement.inventory().state_bytes()
	assert_true(_settlement.run_tick(750), "the crossing tick still commits")
	assert_equal(_settlement.refused_stock_hour_count(), 0, "the HOUR itself ran")
	assert_equal(_settlement.stock_hour().refused_lots, 1, "and refused exactly one lot")
	assert_equal(_settlement.stock_integrity_fault(), &"OVERFLOW",
		"whose checked-arithmetic refusal is the fault this system raises")
	assert_true(_settlement.is_critical_pause_held(), "the pause is held")
	assert_true(_pumped_critical_hold(), "and reached the real clock")
	assert_true(_settlement.is_stock_integrity_halted(), "with no retry available, it halts")
	assert_false(_settlement.is_stock_retry_pending(), "no retry is owed")
	assert_equal(_settlement.inventory().lot_age_milli_hours(lot), MAX_AGE_MILLI_HOURS,
		"the refused lot took no age")
	assert_equal(_settlement.inventory().state_bytes(), before,
		"and the whole lot store is byte identical")
	assert_false(_settlement.run_tick(751), "every later tick refuses")
	assert_equal(_settlement.stock_retry_count(), 0, "and no retry was ever attempted")


func test_the_daily_aging_leg_raises_and_retries_the_same_fault_as_the_tick_path() -> void:
	"""REQ-SET-007's first leg is the same pass, so it cannot have a quieter failure mode.

	This drives the boundary with NO tick path behind it, which is the case where the leg runs
	the hour itself. The crossing is the offset calendar's first midnight, 13500.
	"""
	_populated()
	var lot: Vector2i = _faulting_hour_setup()
	assert_false(_settlement.run_day_boundary(2, SEASON_SPRING), "the boundary's first leg fails")
	assert_equal(_settlement.last_refusal(), &"INVENTORY_TRANSACTION_OPEN", "naming the refusal")
	assert_equal(_settlement.stock_integrity_fault_tick().value,
		SimClockScript.FIRST_MIDNIGHT_TICK, "the fault names midnight, not tick 0")
	assert_true(_settlement.is_critical_pause_held(), "and the critical pause is held")
	assert_equal(_settlement.daily_leg_count(), 0, "no leg was recorded as executed")
	_settlement.inventory().abort()
	assert_true(_settlement.run_tick(SimClockScript.FIRST_MIDNIGHT_TICK + 1),
		"the next tick carries the one retry")
	assert_equal(_settlement.stock_age().last_hour_tick(), SimClockScript.FIRST_MIDNIGHT_TICK,
		"which consumed midnight itself")
	assert_equal(_settlement.inventory().lot_age_milli_hours(lot), COVERED_SPRING_MILLI_HOURS,
		"charging exactly one §5.8 hour")


func test_a_halted_settlement_refuses_the_daily_boundary_before_aging_anything() -> void:
	"""A boundary must not walk past an unrecovered integrity fault into ecology and crops."""
	_populated()
	_faulting_hour_setup()
	assert_true(_settlement.run_tick(750), "the hour faults")
	assert_true(_settlement.run_tick(751), "and its retry fails, halting the settlement")
	assert_false(_settlement.run_day_boundary(2, SEASON_SPRING), "the boundary refuses")
	assert_equal(_settlement.last_refusal(), &"STOCK_AGE_INTEGRITY_HALT", "naming the halt")
	assert_equal(_settlement.daily_leg_count(), 0, "having executed no leg")
	assert_equal(_settlement.last_ecology_day(), 0, "and never reached ARCH-SYS-005")


func test_the_retry_runs_inside_the_existing_stock_age_stage_and_adds_no_ninth() -> void:
	"""The tick stage count stays 8: the retry is dispatched in TICK_STAGE_STOCK_AGE's window."""
	_faulting_hour_setup()
	assert_true(_settlement.run_tick(750), "the hour faults")
	_settlement.inventory().abort()
	assert_true(_settlement.run_tick(751), "and the retry recovers it")
	assert_equal(_settlement.tick_stage_count(), 8, "still exactly eight dispatched stages")
	assert_equal(_settlement.tick_stage_measured_count(
			SettlementSystemScript.TICK_STAGE_STOCK_AGE).value, _settlement.ticks_run(),
		"and the stock-age window was opened once per tick, retry included")


func test_the_integrity_refusal_class_is_read_from_stock_ages_own_constants() -> void:
	"""The three preflight codes pause; the three cadence codes do not, and none is invented."""
	assert_true(SettlementSystemScript.is_stock_integrity_refusal(
		StockAgeScript.REFUSE_NO_INVENTORY), "an unbound lot store is a ledger failure")
	assert_true(SettlementSystemScript.is_stock_integrity_refusal(
		StockAgeScript.REFUSE_NO_ITEM_CATALOG), "an unusable catalog is a schema failure")
	assert_true(SettlementSystemScript.is_stock_integrity_refusal(
		StockAgeScript.REFUSE_TRANSACTION_OPEN), "a stray open transaction is a ledger failure")
	assert_false(SettlementSystemScript.is_stock_integrity_refusal(
		StockAgeScript.REFUSE_HOUR_ALREADY_RUN), "a replayed hour changed nothing")
	assert_false(SettlementSystemScript.is_stock_integrity_refusal(
		StockAgeScript.REFUSE_NOT_HOUR_BOUNDARY), "a non-crossing tick owed no hour")
	assert_false(SettlementSystemScript.is_stock_integrity_refusal(
		StockAgeScript.REFUSE_INVALID_TICK), "and a negative tick is a caller error")


# --- STOCK-SEED-R01: the seed-expiry authority is wired in the production composition --------------
#
# WHAT THESE ADD OVER `test_inventory.gd`. That suite proves `inventory.gd` asks the authority on
# every guarded path and `stock_age.gd` derives the verdict correctly, against a pair the test
# builds itself. NONE of that reached the running game: `set_seed_expiry_authority()` existed,
# `refuses_seed_consumption()` existed, and NOTHING CALLED THE SETTER, so the settlement's own
# inventory had no authority bound and admitted expired seed. These tests are about the wiring.
#
# `docs/gameplay_balance.md` gives seed_grain a 1440-hour shelf life, and GDD §5.8 expires a lot
# at `shelf_hours * 1000` milli-hours, so 1440000 is EXACT expiry and 1439999 is one milli-hour
# short. Both are exercised, because a `>` where the rule says `>=` passes every other test here.

const SEED_SHELF_MILLI_HOURS: int = 1440 * 1000
const SEED_LOT_QUANTITY_MILLI: int = 10000
const SEED_RESERVE_MILLI: int = 250


func _settlement_store() -> Vector2i:
	"""A container in the settlement's OWN inventory, owned by a directory-free stand-in ref."""
	var made: WorldInventoryScript.OpResult = _settlement.inventory().create_container(
		Vector2i(7, 1), 100000000, WorldInventoryScript.FILTERS_ACCEPT_ALL, 0, true)
	assert_true(made.ok, "the container is created: %s" % made.error)
	return made.ref


func _settlement_seed_lot(container: Vector2i, age_milli_hours: int) -> Vector2i:
	"""One real `seed_grain` lot in the settlement's inventory at a chosen persisted age."""
	var item_id: int = _settlement.item_definitions().compiled_id(&"seed_grain")
	var made: WorldInventoryScript.OpResult = _settlement.inventory().create_lot(container,
		item_id, SEED_LOT_QUANTITY_MILLI, 0, 0, 0, age_milli_hours, 0)
	assert_true(made.ok, "the seed lot is created: %s" % made.error)
	return made.ref


func test_the_settlement_binds_its_own_aging_stage_as_the_seed_expiry_authority() -> void:
	"""The wiring call, asserted where it is made: `_compose_stock_layer()`, before any consumer."""
	assert_true(_settlement.inventory().has_seed_expiry_authority(),
		"a freshly composed settlement already enforces STOCK-SEED-R01")
	assert_not_null(_settlement.stock_age(), "and the stage that answers for it exists")
	var container: Vector2i = _settlement_store()
	var expired: Vector2i = _settlement_seed_lot(container, SEED_SHELF_MILLI_HOURS)
	assert_true(_settlement.stock_age().refuses_seed_consumption(expired),
		"the settlement's OWN stage is the thing refusing, not a stand-in")
	assert_equal(_settlement.inventory().reserve_lot(expired, SEED_RESERVE_MILLI).error,
		WorldInventoryScript.REFUSE_SEED_PAST_SHELF_LIFE,
		"and its verdict reaches the lot store")


func test_exact_expiry_is_refused_at_reserve_and_one_milli_hour_short_is_not() -> void:
	"""GDD §5.8's boundary is `>=`. 1440000 is over; 1439999 is not."""
	var container: Vector2i = _settlement_store()
	var fresh: Vector2i = _settlement_seed_lot(container, SEED_SHELF_MILLI_HOURS - 1)
	assert_true(_settlement.inventory().reserve_lot(fresh, SEED_RESERVE_MILLI).ok,
		"one milli-hour short of the threshold still sows")
	var exact: Vector2i = _settlement_seed_lot(container, SEED_SHELF_MILLI_HOURS)
	var refused: WorldInventoryScript.OpResult = _settlement.inventory().reserve_lot(
		exact, SEED_RESERVE_MILLI)
	assert_false(refused.ok, "reaching the threshold exactly is refused")
	assert_equal(refused.error, WorldInventoryScript.REFUSE_SEED_PAST_SHELF_LIFE, "by name")


func test_an_existing_claim_is_revalidated_at_commit_and_refused() -> void:
	"""A reservation taken while the seed was fresh carries NO permission into the commit.

	This is the half a cached verdict would break: the claim was legitimate when it was taken, the
	lot aged out underneath it, and `consume_reserved()` -- the sowing/work commit -- must ask
	again rather than replay the earlier yes.
	"""
	var container: Vector2i = _settlement_store()
	var seed: Vector2i = _settlement_seed_lot(container, SEED_SHELF_MILLI_HOURS - 1000)
	assert_true(_settlement.inventory().reserve_lot(seed, SEED_RESERVE_MILLI).ok,
		"the claim is taken while the seed is still usable")
	assert_true(_settlement.inventory().advance_lot_age_hour(seed, 1000, 1000).ok,
		"then one game hour of §5.8 storage age takes it to the threshold exactly")
	assert_equal(_settlement.inventory().lot_age_milli_hours(seed), SEED_SHELF_MILLI_HOURS,
		"1440000 milli-hours, the exact expiry boundary")
	var committed: WorldInventoryScript.OpResult = _settlement.inventory().consume_reserved(
		seed, SEED_RESERVE_MILLI)
	assert_false(committed.ok, "so the commit is refused")
	assert_equal(committed.error, WorldInventoryScript.REFUSE_SEED_PAST_SHELF_LIFE, "by name")
	assert_equal(_settlement.inventory().lot_quantity_milli(seed), SEED_LOT_QUANTITY_MILLI,
		"and nothing was consumed")


func test_the_guard_still_lets_the_hourly_pass_convert_the_seed_it_refuses() -> void:
	"""The conversion is not a consumer. A guard that blocked its own cleanup would deadlock."""
	var container: Vector2i = _settlement_store()
	_settlement.stock_age().declare_storage_class(container, StockAgeScript.STORAGE_CELLAR, false)
	var seed: Vector2i = _settlement_seed_lot(container, SEED_SHELF_MILLI_HOURS)
	assert_equal(_settlement.inventory().reserve_lot(seed, SEED_RESERVE_MILLI).error,
		WorldInventoryScript.REFUSE_SEED_PAST_SHELF_LIFE, "a sower is refused")
	var hour: StockAgeScript.HourResult = _settlement.stock_age().run_hour(
		2 * SimClockScript.TICKS_PER_DAY + 9 * SimClockScript.TICKS_PER_HOUR
			- SimClockScript.CALENDAR_OFFSET_TICKS)
	assert_true(hour.ok, "while the hourly pass still runs: %s" % hour.error)
	assert_equal(hour.seed_lots_converted, 1, "converting the lot the guard refused")
	assert_equal(_settlement.inventory().lot_item_id(seed),
		_settlement.item_definitions().compiled_id(&"compost"), "into compost")
	assert_true(_settlement.inventory().reserve_lot(seed, SEED_RESERVE_MILLI).ok,
		"which no seed rule refuses")


func test_the_wiring_survives_a_settlement_reset() -> void:
	"""`inventory.clear()` drops rows and the item registry; the authority is wiring, not state."""
	_settlement.reset()
	assert_true(_settlement.inventory().has_seed_expiry_authority(),
		"the guard is still bound after a reset")
	var container: Vector2i = _settlement_store()
	var expired: Vector2i = _settlement_seed_lot(container, SEED_SHELF_MILLI_HOURS)
	assert_equal(_settlement.inventory().reserve_lot(expired, SEED_RESERVE_MILLI).error,
		WorldInventoryScript.REFUSE_SEED_PAST_SHELF_LIFE,
		"and it still refuses against the reloaded catalog")


func test_the_seed_guard_survives_a_critical_pause_and_its_retry_recovery() -> void:
	"""The fault path opens and aborts an inventory transaction; the binding must outlive both.

	`set_seed_expiry_authority()` REFUSES while a transaction is open, which is the shape of the
	bug this pins: a settlement that rebound the guard during recovery would silently fail to,
	and every sower afterwards would be handed dead seed by a settlement that looked healthy.
	"""
	_faulting_hour_setup()
	assert_true(_settlement.run_tick(750), "hour 750 faults under the stray transaction")
	assert_true(_settlement.is_critical_pause_held(), "the CRITICAL hold is raised")
	assert_true(_settlement.inventory().has_seed_expiry_authority(),
		"and the guard is still bound while the settlement is paused")
	_settlement.inventory().abort()
	assert_true(_settlement.run_tick(751), "the retry recovers the hour")
	assert_false(_settlement.is_critical_pause_held(), "and releases the hold")
	assert_true(_settlement.inventory().has_seed_expiry_authority(),
		"the guard survived the whole fault/recovery cycle")
	var container: Vector2i = _settlement_store()
	var expired: Vector2i = _settlement_seed_lot(container, SEED_SHELF_MILLI_HOURS)
	assert_equal(_settlement.inventory().reserve_lot(expired, SEED_RESERVE_MILLI).error,
		WorldInventoryScript.REFUSE_SEED_PAST_SHELF_LIFE, "and still refuses expired seed")


# --- INIT-POSE-R01: the authoritative starter placement ----------------------------------------
#
# THE GAP THESE CLOSE. Nothing in the running game gave a resident a position: `transforms.gd`
# was not among the composed stores, `place()` was never called, and the renderer carried a
# presentation-private 3151872-byte second pose store to have anything to draw. These tests pin
# the ruling's authored row -- ids 1..12 on the hall's south apron at `(58+i, 69)` -- against the
# PREPARED world's own terrain, clearing and resource plan, not against constants copied twice.
#
# EVERY EXPECTED NUMBER BELOW IS RESTATED FROM THE RULING, never read back out of the module.

## INIT-POSE-R01 §1's authored table, transcribed from the ruling itself.
const ROW_FIRST_TILE_X: int = 58
const ROW_TILE_Z: int = 69
const ROW_FIRST_TILE_INDEX: int = 8890
const ROW_FIRST_ROOT_X_UNITS: int = 119808
const ROW_ROOT_X_STEP_UNITS: int = 2048
const ROW_ROOT_Y_UNITS: int = 512
const ROW_ROOT_Z_UNITS: int = 142336
const ROW_YAW: int = 0


func _slot_of_persistent_id(persistent_id: int) -> int:
	"""The resident row currently holding `persistent_id`, or RESIDENT_CAPACITY when none does.

	Read from the store rather than assumed equal to `persistent_id - 1`: the whole point of the
	ruling's ordering rule is that the row is an allocation detail.
	"""
	for slot: int in ResidentsScript.RESIDENT_CAPACITY:
		if not _settlement.residents().is_alive(slot):
			continue
		if _settlement.residents().persistent_id_of(slot).value == persistent_id:
			return slot
	return ResidentsScript.RESIDENT_CAPACITY


func _pose_of_persistent_id(persistent_id: int) -> TransformsScript.Pose:
	"""Read the authoritative pose of the resident holding `persistent_id`, or null if unreadable."""
	var slot: int = _slot_of_persistent_id(persistent_id)
	if slot == ResidentsScript.RESIDENT_CAPACITY:
		return null
	var pose: TransformsScript.Pose = TransformsScript.Pose.new()
	if not _settlement.transforms().read_into(_settlement.residents().ref_of(slot), pose):
		return null
	return pose


func test_the_settlement_owns_one_transform_store_bound_to_its_own_directory() -> void:
	"""INIT-POSE-R01 §2.1: ONE store, on the SAME directory as the resident rows it positions.

	A Transform row is `base(kind) + typed_row` of the directory row an entity already owns, so a
	store built over a DIFFERENT directory derives rows for entities that do not exist. Identity
	is asserted, not agreement: two directories that look alike today are two allocators tomorrow.
	"""
	assert_not_null(_settlement.transforms(), "the settlement composes a Transform store")
	assert_true(_settlement.transforms() == _settlement.transforms(),
		"and publishes one object rather than minting a copy per call")
	assert_equal(_settlement.transforms().bound_count(), 0,
		"which holds no pose at all before a world is generated")


func test_the_generated_cohort_stands_on_the_authored_assembly_row() -> void:
	"""The ruling's §1 table, resident by resident, by PERSISTENT ID and not by row.

	x steps one 2 m tile pitch per id; y is §5.1's authored land elevation; z is one row south of
	the hall. Yaw is the neutral authored model orientation and previous equals current, because a
	spawn has no history to interpolate out of.
	"""
	assert_true(_generate(), "REQ-SET-009 runs (refusal: %s)" % _settlement.last_refusal())
	assert_equal(_settlement.transforms().bound_count(), COHORT_SIZE, "twelve poses are placed")
	for index: int in COHORT_SIZE:
		var pose: TransformsScript.Pose = _pose_of_persistent_id(index + 1)
		assert_not_null(pose, "persistent id %d has a readable pose" % (index + 1))
		assert_equal(pose.x, ROW_FIRST_ROOT_X_UNITS + ROW_ROOT_X_STEP_UNITS * index,
			"id %d stands at its own authored x" % (index + 1))
		assert_equal(pose.y, ROW_ROOT_Y_UNITS, "on the authored land elevation")
		assert_equal(pose.z, ROW_ROOT_Z_UNITS, "on the single authored apron row")
		assert_equal(pose.yaw, ROW_YAW, "at the neutral authored orientation")
		assert_true(pose.matches_previous(), "with previous equal to current on a new spawn")


func test_the_twelve_assembly_tiles_are_distinct_and_are_the_authored_indices() -> void:
	"""`8890 + i`, which is `z*128+x` of `(58+i, 69)`, and twelve DIFFERENT tiles.

	Two residents sharing a tile would be invisible in a pose test -- both poses would still read
	back exactly as written -- so the distinctness is asserted over the tile indices themselves.
	"""
	var seen: Dictionary = {}
	for index: int in COHORT_SIZE:
		var tile: int = WorldInitScript.tile_index_of(ROW_FIRST_TILE_X + index, ROW_TILE_Z)
		assert_equal(tile, ROW_FIRST_TILE_INDEX + index, "tile %d is the authored index" % index)
		assert_false(seen.has(tile), "and no earlier resident already stood on it")
		seen[tile] = true
		assert_equal(WorldInitScript.tile_center_x_units(ROW_FIRST_TILE_X + index),
			ROW_FIRST_ROOT_X_UNITS + ROW_ROOT_X_STEP_UNITS * index,
			"whose centre is the authored root x")
	assert_equal(seen.size(), COHORT_SIZE, "twelve distinct tiles for twelve residents")
	assert_equal(WorldInitScript.tile_center_z_units(ROW_TILE_Z), ROW_ROOT_Z_UNITS,
		"and one shared authored root z")


func test_the_generated_map_reserves_the_assembly_row_before_resource_placement() -> void:
	"""§5.1's clear mask, read from the PUBLISHED column of the world that just generated.

	Not `is_cleared_tile()` restated: `is_cleared_at()` reads the byte `_stage_masks()` wrote and
	`_stage_tree_plan()` then consulted, which is the ordering the ruling requires -- the row is
	reserved BEFORE a resource node is planned onto it.
	"""
	assert_true(_generate(), "REQ-SET-009 runs (refusal: %s)" % _settlement.last_refusal())
	for index: int in COHORT_SIZE:
		var tile_x: int = ROW_FIRST_TILE_X + index
		assert_true(_settlement.world().is_cleared_at(ROW_FIRST_TILE_INDEX + index),
			"apron tile %d is cleared in the published mask" % tile_x)
		assert_equal(_settlement.world().terrain_at(ROW_FIRST_TILE_INDEX + index).value,
			WorldInitScript.TERRAIN_LAND, "and is land")
		assert_equal(WorldInitScript.elevation_y_units_of(tile_x, ROW_TILE_Z), ROW_ROOT_Y_UNITS,
			"at §5.1's authored land elevation")
		assert_true(WorldInitScript.is_walkable(tile_x, ROW_TILE_Z), "and is walkable ground")


func test_nothing_static_or_generated_occupies_the_assembly_row() -> void:
	"""Footprint and resource exclusion, checked against the world that actually generated.

	The apron is the ring OUTSIDE §5.9's footprints, so no resident stands in a wall; and no tree,
	grove or ore node may own one of the twelve tiles once the plan has been published.
	"""
	assert_true(_generate(), "REQ-SET-009 runs (refusal: %s)" % _settlement.last_refusal())
	for index: int in COHORT_SIZE:
		var tile_x: int = ROW_FIRST_TILE_X + index
		assert_false(WorldInitScript.is_starter_footprint_tile(tile_x, ROW_TILE_Z),
			"tile %d is under no starter building footprint" % tile_x)
		assert_true(WorldInitScript.is_starter_apron_tile(tile_x, ROW_TILE_Z),
			"it is the hall's exterior apron, which is cleared ground and not a floor slab")
		assert_equal(_settlement.ecology().resource_nodes().ref_at_tile(
			ROW_FIRST_TILE_INDEX + index), EntityDirectoryScript.NULL_REF,
			"and no generated resource node stands on it")


func test_the_assembly_row_grants_no_home_bed_or_building() -> void:
	"""The ruling is explicit: this is an exterior apron, not a bed, room, floor slab or building.

	A starter placement that quietly counted as a home assignment would satisfy §5.1's room rule
	with no Furniture row in existence, which is exactly the fiction this must not create.
	"""
	assert_true(_generate(), "REQ-SET-009 runs (refusal: %s)" % _settlement.last_refusal())
	assert_equal(_settlement.buildings().live_building_count(), 0, "no building was created")
	assert_equal(_settlement.buildings().live_room_count(), 0, "no room")
	assert_equal(_settlement.buildings().live_furniture_count(), 0, "and no bed")
	for index: int in COHORT_SIZE:
		var slot: int = _slot_of_persistent_id(index + 1)
		assert_false(_settlement.residents().home_is_live(slot), "id %d has no home" % (index + 1))
		assert_false(_settlement.residents().bed_is_live(slot), "and no bed")


func test_placement_happens_against_the_prepared_world_not_a_published_one() -> void:
	"""INIT-POSE-R01 §2.2: validate and place BEFORE publishing, inside one transaction.

	Observed from inside the call, because afterwards the world is published either way. The
	cohort must already exist -- ids 1-12 are what it is ordered by -- and no world entity may.
	"""
	var settlement: PoseObservingSettlement = PoseObservingSettlement.new()
	assert_true(settlement.create_generated_settlement(_loaded_items()),
		"the settlement initializes (refusal: %s)" % settlement.last_refusal())
	assert_false(settlement.published_when_placed,
		"the poses were written before the world was published")
	assert_equal(settlement.nodes_when_placed, 0, "with no world entity allocated yet")
	assert_equal(settlement.living_when_placed, COHORT_SIZE, "and the whole cohort standing")
	assert_equal(settlement.transforms().bound_count(), COHORT_SIZE,
		"which is what ends up published with the world")
	settlement.free()


func test_the_cohort_only_fixture_places_nobody() -> void:
	"""INIT-POSE-R01 §2.6: `create_initial_settlement()` claims no map and no positioned world.

	It stays usable as a cohort fixture, and it must NOT quietly acquire the placement contract:
	an unpositioned cohort over no terrain is what it has always been.
	"""
	assert_true(_settlement.create_initial_settlement(), "the cohort-only path still works")
	assert_equal(_settlement.living_count(), COHORT_SIZE, "twelve residents exist")
	assert_equal(_settlement.transforms().bound_count(), 0, "and not one of them is placed")
	assert_false(_settlement.world().is_published(), "over no published world")


func test_assignment_follows_the_persistent_id_and_not_the_resident_row() -> void:
	"""The isolated fixture INIT-POSE-R01 §4 asks for: slot order and id order made to DISAGREE.

	With ids reversed against rows, the resolver must hand apron index 0 to the row carrying id 1
	-- which is now the LAST row, not the first. An implementation keyed on the slot returns the
	identity permutation here and is caught; on a production world the two are indistinguishable.
	"""
	var residents: ReversedIdResidents = ReversedIdResidents.new()
	assert_true(residents.spawn_initial_settlement().ok, "the fixture cohort spawns")
	var order: PackedInt32Array = PackedInt32Array()
	order.resize(COHORT_SIZE)
	assert_equal(SettlementSystemScript.resolve_assembly_order_into(residents, order),
		SettlementSystemScript.REFUSE_NONE, "the reversed cohort resolves")
	for index: int in COHORT_SIZE:
		assert_equal(order[index], COHORT_SIZE - 1 - index,
			"apron index %d is the row whose persistent id is %d" % [index, index + 1])


func test_the_resolver_refuses_a_cohort_that_is_not_exactly_ids_one_to_twelve() -> void:
	"""No dynamic-growth fallback and no partial row: an unusable cohort refuses as a whole.

	The formula has NO definition for persistent id 13 or above, so a cohort carrying one is a
	refusal rather than an extra apron tile invented on the spot.
	"""
	var order: PackedInt32Array = PackedInt32Array()
	order.resize(COHORT_SIZE)
	assert_equal(SettlementSystemScript.resolve_assembly_order_into(null, order),
		SettlementSystemScript.REFUSE_POSE_IDENTITY, "no store refuses")
	var short_cohort: ResidentsScript = ResidentsScript.new()
	for index: int in COHORT_SIZE - 1:
		short_cohort.spawn(&"mouse")
	assert_equal(SettlementSystemScript.resolve_assembly_order_into(short_cohort, order),
		SettlementSystemScript.REFUSE_POSE_IDENTITY, "eleven residents refuse")
	var over_cohort: ResidentsScript = ResidentsScript.new()
	for index: int in COHORT_SIZE + 1:
		over_cohort.spawn(&"mouse")
	assert_equal(SettlementSystemScript.resolve_assembly_order_into(over_cohort, order),
		SettlementSystemScript.REFUSE_POSE_IDENTITY, "and thirteen refuse, id 13 having no tile")


func test_the_resolver_refuses_an_undersized_output_column_rather_than_resizing_it() -> void:
	"""ARCH-MEM-001: the scratch column is sized once in `_init()` and never grown at a call."""
	var residents: ResidentsScript = ResidentsScript.new()
	assert_true(residents.spawn_initial_settlement().ok, "a real cohort stands")
	var too_small: PackedInt32Array = PackedInt32Array()
	too_small.resize(COHORT_SIZE - 1)
	assert_equal(SettlementSystemScript.resolve_assembly_order_into(residents, too_small),
		SettlementSystemScript.REFUSE_POSE_IDENTITY, "an undersized column refuses")
	assert_equal(too_small.size(), COHORT_SIZE - 1, "and is not resized behind the caller's back")


func test_a_refused_generation_over_a_published_world_leaves_the_poses_byte_identical() -> void:
	"""INIT-POSE-R01 §2.5: a published world is never overwritten, even with nobody standing in it.

	Replacement rollback does not exist, so the `resident_count > 0` guard alone is insufficient:
	an empty-but-published world would be destroyed by the transaction's reset and could not be
	rebuilt. Decision 0059's allocate-before-consume, proved over the whole pose image.
	"""
	assert_true(_generate(), "a valid world stands first")
	var poses: PackedByteArray = _settlement.transforms().state_bytes()
	var terrain: PackedByteArray = _terrain_image()
	_settlement.residents().clear()
	assert_equal(_settlement.residents().population(), 0,
		"the resident store the emptiness guard reads now holds nobody")
	assert_true(_settlement.world().is_published(), "over a world that is still published")
	assert_false(_generate(), "and a second initialization over it is refused")
	assert_equal(_settlement.last_refusal(),
		SettlementSystemScript.REFUSE_WORLD_ALREADY_PUBLISHED, "naming the published world")
	assert_equal(_settlement.transforms().state_bytes(), poses,
		"every one of the nine pose columns is byte-identical")
	assert_equal(_terrain_image(), terrain, "and so is the standing world's terrain")


func test_a_cohort_refusal_inside_the_transaction_leaves_no_pose_standing() -> void:
	"""A failure between the reset and publication must publish no half-placed row either."""
	var settlement: RefusingCohortSettlement = RefusingCohortSettlement.new()
	var empty: PackedByteArray = settlement.transforms().state_bytes()
	assert_false(settlement.create_generated_settlement(_loaded_items()), "the cohort refuses")
	assert_equal(settlement.transforms().bound_count(), 0, "no pose was bound")
	assert_equal(settlement.transforms().state_bytes(), empty,
		"and the pose columns are byte-identical to a settlement that never tried")
	settlement.free()


func test_a_new_world_reset_leaks_no_pose_into_the_world_that_follows_it() -> void:
	"""INIT-POSE-R01 §2.4: a new world may restart persistent ids at 1, so old binding bytes are
	unsafe even though ids never repeat WITHIN a world.

	The second world's id 1 is a different creature standing in a newly initialized row; a reset
	that left the first world's binding stamp behind would hand it the first world's coordinates.
	"""
	assert_true(_generate(), "a first world stands")
	var first: Vector2i = _settlement.residents().ref_of(_slot_of_persistent_id(1))
	_settlement.reset()
	assert_equal(_settlement.transforms().bound_count(), 0, "the reset released every pose")
	var fresh: SettlementSystemScript = SettlementSystemScript.new()
	var fresh_bytes: PackedByteArray = fresh.transforms().state_bytes()
	fresh.free()
	assert_equal(_settlement.transforms().state_bytes(), fresh_bytes,
		"leaving the columns byte-identical to a freshly composed store")
	assert_false(_settlement.transforms().is_bound(first),
		"and the first world's reference reads as unplaced, not as its old coordinates")
	assert_true(_generate(), "a second world generates over it")
	var pose: TransformsScript.Pose = _pose_of_persistent_id(1)
	assert_not_null(pose, "the second world's id 1 has its own pose")
	assert_equal(pose.x, ROW_FIRST_ROOT_X_UNITS, "which is its own newly initialized apron tile")
	assert_true(pose.matches_previous(), "with no history carried over from the first world")


func test_repeated_presentation_reads_change_no_authoritative_pose_byte() -> void:
	"""The renderer borrows this store; a thousand frames at varied alphas must not write to it.

	`presentation_interpolate_into()` is the one legal float boundary and it fills a caller-owned
	record. Compared over the whole nine-column image, not a sampled field.
	"""
	assert_true(_generate(), "a world stands")
	var before: PackedByteArray = _settlement.transforms().state_bytes()
	var digest: int = _settlement.transforms().authoritative_digest()
	var out: TransformsScript.PresentationPose = TransformsScript.PresentationPose.new()
	for frame: int in 200:
		for index: int in COHORT_SIZE:
			var ref: Vector2i = _settlement.residents().ref_of(_slot_of_persistent_id(index + 1))
			assert_true(_settlement.transforms().presentation_interpolate_into(
				ref, frame * 5000, 1000000, out), "the frame drew")
	assert_equal(_settlement.transforms().state_bytes(), before, "not one byte moved")
	assert_equal(_settlement.transforms().authoritative_digest(), digest, "nor did the digest")


func _planned_apron_world() -> PlannedApronWorld:
	"""A generator whose staged plan this test controls, over stores nothing else shares."""
	var residents: ResidentsScript = ResidentsScript.new()
	var jobs: JobsScript = JobsScript.new(residents, null, null)
	return PlannedApronWorld.new(residents.directory(), ResourceNodesScript.new(),
		ForageScript.new(), FishingScript.new(), RngScript.new(), null, null, jobs)


func test_the_apron_exclusion_covers_exactly_the_twelve_authored_tiles() -> void:
	"""`8890..8901` inclusive, and the tile either side of the row is NOT covered.

	This rule only ever fires on tiles the authored map does not produce, so without a direct
	test it could be replaced by `return false` and every other test would stay green.
	"""
	assert_false(SettlementSystemScript.assembly_covers_tile(ROW_FIRST_TILE_INDEX - 1),
		"the tile west of the row is outside it")
	for index: int in COHORT_SIZE:
		assert_true(SettlementSystemScript.assembly_covers_tile(ROW_FIRST_TILE_INDEX + index),
			"apron tile %d is covered" % (ROW_FIRST_TILE_INDEX + index))
	assert_false(SettlementSystemScript.assembly_covers_tile(
		ROW_FIRST_TILE_INDEX + COHORT_SIZE), "and the tile east of the row is outside it")


func test_a_plan_that_puts_a_resource_node_on_the_apron_refuses_the_placement() -> void:
	"""The exclusion's REFUSING branch, executed rather than argued to be unreachable.

	Both plan lists are covered: §5.1 plants capped centres first and then a guaranteed grove on
	top of them, and a resident standing inside either is the same defect.
	"""
	var world: PlannedApronWorld = _planned_apron_world()
	world.plan_tile = ROW_FIRST_TILE_INDEX + 3
	assert_equal(SettlementSystemScript.refuse_assembly_occupancy(world),
		SettlementSystemScript.REFUSE_POSE_OCCUPIED, "a planned tree centre on the row refuses")
	world.plan_is_grove = true
	assert_equal(SettlementSystemScript.refuse_assembly_occupancy(world),
		SettlementSystemScript.REFUSE_POSE_OCCUPIED, "and so does a planned grove node")


func test_a_plan_clear_of_the_apron_passes_the_exclusion() -> void:
	"""The other side of the same branch: a plan that avoids the row must NOT refuse.

	Without this, `return REFUSE_POSE_OCCUPIED` unconditionally would satisfy the test above.
	"""
	var world: PlannedApronWorld = _planned_apron_world()
	world.plan_tile = ROW_FIRST_TILE_INDEX - 1
	assert_equal(SettlementSystemScript.refuse_assembly_occupancy(world),
		SettlementSystemScript.REFUSE_NONE, "a centre west of the row is fine")
	world.plan_tile = ROW_FIRST_TILE_INDEX + COHORT_SIZE
	world.plan_is_grove = true
	assert_equal(SettlementSystemScript.refuse_assembly_occupancy(world),
		SettlementSystemScript.REFUSE_NONE, "and a grove node east of it is fine")


func test_an_unreadable_plan_refuses_rather_than_being_treated_as_empty() -> void:
	"""A plan entry that cannot be read is not evidence the row is clear. No world is no evidence
	either: the exclusion refuses rather than passing a placement it could not check."""
	var world: PlannedApronWorld = _planned_apron_world()
	world.plan_refuses = true
	world.plan_tile = ROW_FIRST_TILE_INDEX + 5000
	assert_equal(SettlementSystemScript.refuse_assembly_occupancy(world),
		SettlementSystemScript.REFUSE_POSE_OCCUPIED, "an unreadable centre refuses")
	world.plan_is_grove = true
	assert_equal(SettlementSystemScript.refuse_assembly_occupancy(world),
		SettlementSystemScript.REFUSE_POSE_OCCUPIED, "an unreadable grove entry refuses")
	assert_equal(SettlementSystemScript.refuse_assembly_occupancy(null),
		SettlementSystemScript.REFUSE_POSE_OCCUPIED, "and no generator at all refuses")


func test_a_pose_store_that_leaves_a_previous_pose_behind_refuses_the_whole_world() -> void:
	"""INIT-POSE-R01 §1: previous and yaw EQUAL current on this new spawn, verified by read-back.

	The current coordinates would still be right, so no position assertion could see it. The
	settlement reads all twelve poses back after writing them and refuses the transaction whole.
	"""
	var settlement: HistoryBreakingSettlement = HistoryBreakingSettlement.new()
	assert_false(settlement.create_generated_settlement(_loaded_items()),
		"a spawn with history refuses the generation")
	assert_equal(settlement.last_refusal(), SettlementSystemScript.REFUSE_POSE_TRANSFORM,
		"naming the Transform write")
	assert_false(settlement.world().is_published(), "and no world is published")
	assert_equal(settlement.residents().population(), 0, "with no cohort left standing")
	settlement.free()


func test_a_candidate_row_that_is_already_placed_refuses_before_anything_is_written() -> void:
	"""The precondition, exercised: a row already bound is not silently overwritten.

	Decided BEFORE the first `place()`, so a store reporting every row occupied leaves the pose
	columns byte-identical rather than half-written.
	"""
	var settlement: OccupiedRowSettlement = OccupiedRowSettlement.new()
	var empty: PackedByteArray = settlement.transforms().state_bytes()
	assert_false(settlement.create_generated_settlement(_loaded_items()),
		"an already-placed candidate row refuses the generation")
	assert_equal(settlement.last_refusal(), SettlementSystemScript.REFUSE_POSE_TRANSFORM,
		"naming the Transform binding")
	assert_equal(settlement.transforms().state_bytes(), empty,
		"and not one pose column byte was written")
	assert_false(settlement.world().is_published(), "with no world published")
	settlement.free()


# --- REQ-SET-128 / INV-GOODS-R01: the composed demolition gate ---------------------------------
##
## THE HEADLINE PROPERTY IS THE ONE BELOW, AND IT IS EASY TO GET BACKWARDS. A demolition request
## against a spotless building -- no goods, no claims, nobody inside -- must still REFUSE, with
## the missing-containment code, because no store binds a container to a footprint tile and the
## gate therefore cannot see a ground pile or a visitor's cart standing in the doorway. Every
## other refusal below is reached BEFORE that one, which is how each of them is observable at all.

func _active_hall() -> Vector2i:
	"""Place §5.9's hall and move it to ACTIVE, the only state a demolition may be asked for."""
	var hall: Vector2i = _place_hall()
	assert_true(_settlement.buildings().set_building_state(hall,
		int(CatalogScript.BUILDING_STATE["ACTIVE"])).ok, "the hall becomes ACTIVE")
	return hall


func _store_owned_by(owner_ref: Vector2i, mass_g: int = 400000) -> Vector2i:
	"""Create one accept-everything container keyed to `owner_ref` and return its handle."""
	var made: WorldInventoryScript.OpResult = _settlement.inventory().create_container(
		owner_ref, mass_g, WorldInventoryScript.FILTERS_ACCEPT_ALL, 0, true)
	assert_true(made.ok, "the container is created (%s)" % made.error)
	return made.ref


func _grain_lot(container_ref: Vector2i, quantity_milli: int) -> Vector2i:
	"""Put one grain lot of `quantity_milli` into a container and return its ref."""
	var grain: int = _settlement.item_definitions().compiled_id(&"grain")
	var made: WorldInventoryScript.OpResult = _settlement.inventory().create_lot(
		container_ref, grain, quantity_milli, 0, 0, 0, 0, 0)
	assert_true(made.ok, "the lot is created (%s)" % made.error)
	return made.ref


func _demolition_snapshot() -> PackedByteArray:
	"""One image of every store the gate could touch, for decision 0059's byte-identity check."""
	var out: PackedByteArray = _settlement.construction().state_bytes()
	out.append_array(_settlement.inventory().state_bytes())
	out.append_array(_settlement.directory().state_bytes())
	out.append_array(var_to_bytes(_building_image()))
	return out


func _building_image() -> PackedInt64Array:
	"""Every live Building/Room/Furniture field the gate might plausibly edit, read publicly."""
	var buildings: BuildingsScript = _settlement.buildings()
	var fields: PackedInt64Array = PackedInt64Array([buildings.live_building_count(),
		buildings.live_room_count(), buildings.live_furniture_count(),
		_settlement.construction().live_project_count()])
	for row: int in BuildingsScript.BUILDING_CAPACITY:
		var ref: Vector2i = buildings.building_ref_of_row(row)
		if ref == EntityDirectoryScript.NULL_REF:
			continue
		var project: Vector2i = buildings.construction_ref_of_building(ref)
		fields.append_array(PackedInt64Array([ref.x, ref.y,
			buildings.state_of_building(ref).value, buildings.condition_of_building(ref).value,
			project.x, project.y]))
		_append_room_image(fields, ref)
	return fields


func _append_room_image(fields: PackedInt64Array, building_ref: Vector2i) -> void:
	"""Append every room and furniture field of one building to a state image."""
	var buildings: BuildingsScript = _settlement.buildings()
	for room_row: int in buildings.rooms_of_building(building_ref):
		var room: Vector2i = buildings.room_ref_of_row(room_row)
		fields.append_array(PackedInt64Array([room.x, room.y,
			buildings.occupants_of_room(room).value, 1 if buildings.room_is_valid(room) else 0]))
		for furniture_row: int in buildings.furniture_rows_in_room(room):
			var furniture: Vector2i = buildings.furniture_ref_of_row(furniture_row)
			var user: Vector2i = buildings.user_ref_of_furniture(furniture)
			fields.append_array(PackedInt64Array([furniture.x, furniture.y, user.x, user.y]))


func test_a_spotless_building_still_refuses_because_containment_cannot_be_proved() -> void:
	"""The whole point of INV-GOODS-R01: an empty scan is NOT a proof that nothing is there.

	No container is keyed to this hall, no project touches it and nobody is inside, so stages 2
	to 4 all pass -- and the request still refuses, because no store binds an inventory container
	to a footprint tile and a ground pile in the doorway is invisible to every query that exists.
	"""
	var hall: Vector2i = _active_hall()
	var report: SettlementSystemScript.DemolitionReport = _settlement.request_demolition(hall)
	assert_false(report.ok, "a gate that cannot see the footprint may never pass")
	assert_equal(report.error, SettlementSystemScript.REFUSE_DEMOLITION_MISSING_CONTAINMENT,
		"and it refuses as a MISSING containment contract, not as a proved-empty success")
	assert_equal(report.endpoint_owner_count, 1, "the one endpoint it can enumerate is the hall")
	assert_equal(report.scanned_container_count, 0, "which really does own no container")
	assert_equal(report.stranded_lot_count, 0, "so nothing was found")
	assert_equal(report.occupant_count, 0, "and the occupant recheck ran and found nobody")


func test_the_gate_refuses_a_stale_inactive_or_already_demolishing_building() -> void:
	"""Stage 1, with its three distinguishable codes."""
	var hall: Vector2i = _place_hall()
	assert_equal(_settlement.request_demolition(hall).error,
		SettlementSystemScript.REFUSE_DEMOLITION_NOT_ACTIVE, "a blueprint is not demolished")
	assert_equal(_settlement.request_demolition(Vector2i(900, 1)).error,
		SettlementSystemScript.REFUSE_DEMOLITION_STALE_BUILDING, "nor is a ref to nothing")
	assert_true(_settlement.buildings().set_building_state(hall,
		int(CatalogScript.BUILDING_STATE["ACTIVE"])).ok, "the same hall becomes ACTIVE")
	assert_true(_settlement.construction().open_demolition(hall).ok,
		"the store-level transition opens a demolition directly")
	assert_equal(_settlement.request_demolition(hall).error,
		SettlementSystemScript.REFUSE_DEMOLITION_IN_PROGRESS,
		"and a building already carrying a project is refused for THAT reason")


func test_the_gate_reports_the_exact_stranded_lots_of_a_building_owned_store() -> void:
	"""REQ-SET-128's goods half: the refusal names every lot, not just a count in one value."""
	var hall: Vector2i = _active_hall()
	var store: Vector2i = _store_owned_by(hall)
	var wheat: Vector2i = _grain_lot(store, 4000)
	var barley: Vector2i = _grain_lot(store, 1500)
	var report: SettlementSystemScript.DemolitionReport = _settlement.request_demolition(hall)
	assert_equal(report.error, SettlementSystemScript.REFUSE_DEMOLITION_STORED_GOODS,
		"stranded goods block the demolition")
	assert_equal(report.stranded_lot_count, 2, "both lots are counted")
	assert_equal(report.stranded_quantity_milli, 5500, "with their exact total quantity")
	assert_equal(report.scanned_container_count, 1, "from the one container the hall owns")
	assert_equal(report.stranded_lot_at(0), barley,
		"the notice names the container's list head, which `_link_lot()` prepends to")
	assert_equal(report.stranded_lot_at(1), wheat, "then the lot behind it")
	assert_equal(report.stranded_lot_at(2), WorldInventoryScript.NULL_REF,
		"and nothing past the count")


func test_a_reserved_lot_is_counted_once_and_not_twice() -> void:
	"""INV-GOODS-R01: "A live lot is counted once even when `reserved_milli > 0`"."""
	var hall: Vector2i = _active_hall()
	var lot: Vector2i = _grain_lot(_store_owned_by(hall), 4000)
	assert_true(_settlement.inventory().reserve_lot(lot, 2500).ok, "a claim is placed on it")
	var report: SettlementSystemScript.DemolitionReport = _settlement.request_demolition(hall)
	assert_equal(report.error, SettlementSystemScript.REFUSE_DEMOLITION_STORED_GOODS,
		"the claimed lot is still stranded stock")
	assert_equal(report.stranded_lot_count, 1, "counted once, not once per claim")
	assert_equal(report.stranded_quantity_milli, 4000,
		"at its whole quantity: a reservation is a claim on the lot, not extra goods")
	assert_equal(report.outstanding_reserved_mass_g, 0,
		"and a lot reservation is not container headroom")


func test_reserved_container_mass_is_an_outstanding_claim_and_never_an_invented_lot() -> void:
	"""Undelivered headroom is reported separately and refuses with its own code."""
	var hall: Vector2i = _active_hall()
	var store: Vector2i = _store_owned_by(hall)
	assert_true(_settlement.inventory().reserve_container_mass(store, 12000).ok,
		"an output job claims headroom in the building's store")
	var report: SettlementSystemScript.DemolitionReport = _settlement.request_demolition(hall)
	assert_equal(report.error, SettlementSystemScript.REFUSE_DEMOLITION_CAPACITY_CLAIM,
		"an outstanding capacity claim blocks the demolition on its own")
	assert_equal(report.stranded_lot_count, 0, "no lot is invented to account for it")
	assert_equal(report.outstanding_reserved_mass_g, 12000, "the exact claimed mass is reported")
	assert_equal(report.claiming_container_count, 1, "against the one container holding it")


func test_goods_under_a_room_or_a_furniture_owner_are_not_missed() -> void:
	"""Owner equality with the BUILDING is not the whole affected set -- §4.2's other endpoints."""
	var hall: Vector2i = _active_hall()
	var room: Vector2i = _designate_dormitory(hall)
	var bed: Vector2i = _place_bed(room, 0)
	_grain_lot(_store_owned_by(room), 1000)
	_grain_lot(_store_owned_by(bed), 2000)
	var report: SettlementSystemScript.DemolitionReport = _settlement.request_demolition(hall)
	assert_equal(report.error, SettlementSystemScript.REFUSE_DEMOLITION_STORED_GOODS,
		"a container owned by a room or a bed inside the building is still affected")
	assert_equal(report.scanned_container_count, 2, "both endpoints were scanned")
	assert_equal(report.stranded_lot_count, 2, "and both lots reported")
	assert_equal(report.stranded_quantity_milli, 3000, "with the exact total")
	assert_equal(report.endpoint_owner_count, 3, "the hall, its room and its bed")


func test_a_projects_material_container_is_scanned_through_its_inventory_handle() -> void:
	"""The second reference domain: a handle Construction never validated, owned by somebody else.

	The container belongs to a RESIDENT, so no endpoint owner scan can reach it; it is reached
	only by following the project's `material_container` handle into Inventory and validating it
	there. A gate that treated that pair as a directory ref would have looked up the wrong store.
	"""
	var hall: Vector2i = _active_hall()
	var bed: Vector2i = _place_bed(_designate_dormitory(hall), 0)
	var project: ConstructionScript.OpResult = _settlement.construction().open_furniture(bed)
	assert_true(project.ok, "the bed's construction project opens (%s)" % project.error)
	var carrier: Vector2i = _settlement.directory().create(EntityDirectoryScript.KIND_RESIDENT)
	var retired: Vector2i = _store_owned_by(carrier)
	assert_true(_settlement.inventory().destroy_container(retired).ok, "a container is retired")
	var satchel: Vector2i = _store_owned_by(carrier)
	assert_equal(satchel.x, retired.x, "the next container reuses that slot")
	assert_true(_settlement.inventory().is_container_valid(satchel),
		"so the handle is a live INVENTORY container")
	assert_false(_settlement.directory().is_valid(satchel),
		"and that very same pair names no live DIRECTORY row: the domains are not interchangeable")
	_grain_lot(satchel, 700)
	assert_true(_settlement.construction().set_material_container(project.ref, satchel).ok,
		"the project names that container as its material store")
	var report: SettlementSystemScript.DemolitionReport = _settlement.request_demolition(hall)
	assert_equal(report.error, SettlementSystemScript.REFUSE_DEMOLITION_STORED_GOODS,
		"goods under another affected owner cannot vanish from the safety decision")
	assert_equal(report.scanned_container_count, 1, "the handle reached the container")
	assert_equal(report.stranded_quantity_milli, 700, "with its exact quantity")


func test_a_material_container_reached_twice_is_counted_once() -> void:
	"""Owner-keyed AND named by the handle: one container, one count, not two."""
	var hall: Vector2i = _active_hall()
	var bed: Vector2i = _place_bed(_designate_dormitory(hall), 0)
	var project: ConstructionScript.OpResult = _settlement.construction().open_furniture(bed)
	assert_true(project.ok, "the project opens (%s)" % project.error)
	var store: Vector2i = _store_owned_by(project.ref)
	_grain_lot(store, 900)
	assert_true(_settlement.construction().set_material_container(project.ref, store).ok,
		"and the project also names it by handle")
	var report: SettlementSystemScript.DemolitionReport = _settlement.request_demolition(hall)
	assert_equal(report.error, SettlementSystemScript.REFUSE_DEMOLITION_STORED_GOODS,
		"the goods are reported")
	assert_equal(report.scanned_container_count, 1, "once")
	assert_equal(report.stranded_lot_count, 1, "and the lot is counted once")
	assert_equal(report.stranded_quantity_milli, 900, "at its real quantity")


func test_an_unprovable_material_container_binding_refuses_as_a_missing_contract() -> void:
	"""`set_material_container()` range-checks only, so a plausible pair can name no container."""
	var hall: Vector2i = _active_hall()
	var room: Vector2i = _designate_dormitory(hall)
	var project: ConstructionScript.OpResult = _settlement.construction().open_furniture(
		_place_bed(room, 0))
	assert_true(project.ok, "the project opens (%s)" % project.error)
	assert_true(_settlement.construction().set_material_container(project.ref,
		Vector2i(4096, 3)).ok, "a range-valid pair is accepted by the store")
	assert_false(_settlement.inventory().is_container_valid(Vector2i(4096, 3)),
		"and it names no live container at all")
	_grain_lot(_store_owned_by(room), 800)
	var report: SettlementSystemScript.DemolitionReport = _settlement.request_demolition(hall)
	assert_equal(report.error, SettlementSystemScript.REFUSE_DEMOLITION_MISSING_CONTAINMENT,
		"an endpoint binding that cannot be proved is a missing contract, and refuses first")
	assert_equal(report.scanned_container_count, 0,
		"so the room's real stock was never scanned -- a walk that continued would have found it")
	assert_equal(report.stranded_lot_count, 0, "and this zero means nothing was counted")


func test_a_delivered_project_with_no_container_binding_refuses_as_a_missing_contract() -> void:
	"""Delivery is recorded only after goods physically moved, so an unbound handle hides them."""
	var hall: Vector2i = _active_hall()
	var room: Vector2i = _designate_dormitory(hall)
	var project: ConstructionScript.OpResult = _settlement.construction().open_furniture(
		_place_bed(room, 0))
	assert_true(project.ok, "the project opens (%s)" % project.error)
	assert_equal(_settlement.construction().material_container_ref_of(project.ref),
		EntityDirectoryScript.NULL_REF, "and it names no material container")
	var undelivered: SettlementSystemScript.DemolitionReport = _settlement.request_demolition(hall)
	assert_equal(undelivered.error,
		SettlementSystemScript.REFUSE_DEMOLITION_MISSING_CONTAINMENT,
		"a project that took nothing is no endpoint, so the walk reaches the footprint refusal")
	assert_equal(undelivered.endpoint_owner_count, 4, "hall, room, bed and the bed's project")
	_grain_lot(_store_owned_by(room), 1200)
	assert_true(_settlement.construction().deliver_material(project.ref, 0, 1000).ok,
		"now a delivery is recorded against a project that names no container")
	var delivered: SettlementSystemScript.DemolitionReport = _settlement.request_demolition(hall)
	assert_equal(delivered.error, SettlementSystemScript.REFUSE_DEMOLITION_MISSING_CONTAINMENT,
		"and the goods it took in have no endpoint this gate can enumerate")
	assert_equal(delivered.scanned_container_count, 0,
		"the endpoint proof refused first, so the room's very real stock was never even scanned")
	assert_equal(delivered.stranded_lot_count, 0,
		"and that 0 means nothing was counted -- never that nothing is there")


func test_the_endpoint_proof_runs_before_the_occupant_recheck() -> void:
	"""Stage order: an unprovable binding refuses first, and the occupant count is never taken.

	An occupant check hoisted above the endpoint proof would answer OCCUPANTS_PRESENT here --
	a true statement about a building whose containment this gate had not established it could
	even see, and a refusal a caller could clear by evicting one resident.
	"""
	var hall: Vector2i = _active_hall()
	var room: Vector2i = _designate_dormitory(hall)
	assert_true(_settlement.buildings().set_room_occupants(room, 3).ok, "three are inside")
	var bed: Vector2i = _place_bed(room, 0)
	var project: ConstructionScript.OpResult = _settlement.construction().open_furniture(bed)
	assert_true(project.ok, "the project opens (%s)" % project.error)
	assert_true(_settlement.construction().set_material_container(project.ref,
		Vector2i(4096, 3)).ok, "whose material container names nothing")
	var report: SettlementSystemScript.DemolitionReport = _settlement.request_demolition(hall)
	assert_equal(report.error, SettlementSystemScript.REFUSE_DEMOLITION_MISSING_CONTAINMENT,
		"the endpoint proof refuses before the residents are ever counted")
	assert_equal(report.occupant_count, 0, "and no occupant count was taken at all")


func test_stranded_goods_refuse_before_the_occupant_recheck() -> void:
	"""Goods are re-read on every attempt, and they answer before the resident half does."""
	var hall: Vector2i = _active_hall()
	var room: Vector2i = _designate_dormitory(hall)
	assert_true(_settlement.buildings().set_room_occupants(room, 2).ok, "two are inside")
	_grain_lot(_store_owned_by(hall), 3000)
	var report: SettlementSystemScript.DemolitionReport = _settlement.request_demolition(hall)
	assert_equal(report.error, SettlementSystemScript.REFUSE_DEMOLITION_STORED_GOODS,
		"the goods half is checked, and it is checked before the residents")
	assert_equal(report.stranded_quantity_milli, 3000, "with the exact stranded quantity")
	assert_equal(report.occupant_count, 0, "and the occupant recheck did not run")


func test_the_resident_half_still_refuses_after_a_proved_empty_goods_scan() -> void:
	"""REQ-SET-128's occupant and furniture-user refusals are preserved, with their exact counts."""
	var hall: Vector2i = _active_hall()
	var room: Vector2i = _designate_dormitory(hall)
	assert_true(_settlement.buildings().set_room_occupants(room, 4).ok, "four are inside")
	var occupied: SettlementSystemScript.DemolitionReport = _settlement.request_demolition(hall)
	assert_equal(occupied.error, ConstructionScript.REFUSE_OCCUPANTS_PRESENT,
		"and the gate re-raises the store's own code")
	assert_equal(occupied.occupant_count, 4, "with the exact number still inside")
	assert_true(_settlement.buildings().set_room_occupants(room, 0).ok, "they leave")
	var bed: Vector2i = _place_bed(room, 0)
	var sleeper: Vector2i = _settlement.directory().create(EntityDirectoryScript.KIND_RESIDENT)
	assert_true(_settlement.buildings().set_furniture_user(bed, sleeper).ok, "one is in a bed")
	var in_use: SettlementSystemScript.DemolitionReport = _settlement.request_demolition(hall)
	assert_equal(in_use.error, ConstructionScript.REFUSE_FURNITURE_IN_USE,
		"the furniture half refuses next")
	assert_equal(in_use.furniture_user_count, 1, "with the exact count still in use")


func test_a_haul_that_clears_the_store_changes_the_refusal_to_the_missing_contract() -> void:
	"""Real transfers, then a retry: the gate re-reads the store rather than a cached verdict."""
	var hall: Vector2i = _active_hall()
	var store: Vector2i = _store_owned_by(hall)
	var lot: Vector2i = _grain_lot(store, 4000)
	var elsewhere: Vector2i = _store_owned_by(
		_settlement.directory().create(EntityDirectoryScript.KIND_RESIDENT))
	assert_equal(_settlement.request_demolition(hall).error,
		SettlementSystemScript.REFUSE_DEMOLITION_STORED_GOODS, "the full store blocks it")
	assert_true(_settlement.inventory().move_lot(lot, elsewhere).ok, "the lot is really hauled")
	var hauled: SettlementSystemScript.DemolitionReport = _settlement.request_demolition(hall)
	assert_equal(hauled.error, SettlementSystemScript.REFUSE_DEMOLITION_MISSING_CONTAINMENT,
		"the goods refusal is gone, and the containment gap is what is left")
	assert_equal(hauled.stranded_lot_count, 0, "nothing is stranded in the endpoints it can see")
	assert_equal(hauled.scanned_container_count, 1, "the emptied container was still scanned")
	assert_equal(_settlement.inventory().lot_container(lot), elsewhere,
		"and the lot is in a valid surviving container")


func test_no_demolition_request_changes_one_byte_of_any_store() -> void:
	"""Decision 0059 across four stores: every refusal above leaves the settlement untouched."""
	var hall: Vector2i = _active_hall()
	var room: Vector2i = _designate_dormitory(hall)
	var bed: Vector2i = _place_bed(room, 0)
	_grain_lot(_store_owned_by(hall), 2000)
	assert_true(_settlement.buildings().set_room_occupants(room, 1).ok, "one is inside")
	var before: PackedByteArray = _demolition_snapshot()
	assert_false(_settlement.request_demolition(hall).ok, "the goods refusal fires")
	assert_true(_demolition_snapshot() == before, "and changes nothing")
	assert_true(_settlement.buildings().remove_furniture(bed).ok, "the bed is removed")
	assert_true(_settlement.buildings().set_room_occupants(room, 0).ok, "the room empties")
	var cleared: PackedByteArray = _demolition_snapshot()
	assert_false(_settlement.request_demolition(hall).ok, "the goods refusal fires again")
	assert_true(_demolition_snapshot() == cleared, "and still changes nothing")
	assert_equal(_settlement.construction().live_project_count(), 0,
		"no project was published by any of it")
	assert_equal(_settlement.buildings().state_of_building(hall).value,
		int(CatalogScript.BUILDING_STATE["ACTIVE"]), "and the building never moved to DEMOLISHING")


func test_a_spotless_request_changes_nothing_either() -> void:
	"""The path that reaches stage 5 is the one most likely to be given a state change later."""
	var hall: Vector2i = _active_hall()
	var before: PackedByteArray = _demolition_snapshot()
	var report: SettlementSystemScript.DemolitionReport = _settlement.request_demolition(hall)
	assert_equal(report.error, SettlementSystemScript.REFUSE_DEMOLITION_MISSING_CONTAINMENT,
		"it refuses at the footprint binding")
	assert_true(_demolition_snapshot() == before, "having changed nothing on the way there")


func test_the_gate_scans_every_container_an_owner_holds_rather_than_a_buffers_worth() -> void:
	"""The gate's scratch is sized from `owner_query_cells()`, so no result can outgrow it.

	Fifty empty containers under one building would overflow any hand-picked buffer, and an
	overflowing owner query REFUSES rather than truncating -- so a gate whose scratch was sized
	by guesswork would surface a scan refusal here instead of a complete scan.
	"""
	var hall: Vector2i = _active_hall()
	for index: int in 50:
		_store_owned_by(hall)
	var report: SettlementSystemScript.DemolitionReport = _settlement.request_demolition(hall)
	assert_equal(report.error, SettlementSystemScript.REFUSE_DEMOLITION_MISSING_CONTAINMENT,
		"the scan completed, so the footprint gap is what is left")
	assert_equal(report.scanned_container_count, 50, "and every container was really scanned")
	assert_equal(report.stranded_lot_count, 0, "all fifty of them being empty")
