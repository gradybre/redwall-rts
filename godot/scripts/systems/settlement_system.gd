extends Node
## The settlement simulation loop: owner of the core stores, driven by completed fixed ticks.
##
## ARCH-MIG-006 step 6, wiring half. `scripts/core/` already holds needs, schedules, priorities,
## jobs, work, reservations and the entity directory, each tested in isolation; until now NOTHING
## IN THE RUNNING GAME CALLED THEM. This node is the production caller: it composes the stores
## once, and runs the §5 pipeline stages that have an implemented owner, once per COMPLETED
## SIMULATION TICK.
##
## ---------------------------------------------------------------------------------------
## THE CLOCK DRIVES THIS, NOT `_process`. `GameManager` folds host microseconds into
## `scripts/core/sim_clock.gd`, which drains whole ticks and calls back once per completed tick
## with that tick's index. This node has no `_process`, reads no `delta`, and cannot run a
## fraction of a tick. REQ-SET-011: a tick is a tick, so 2x and 4x run more of exactly this
## function and nothing else, and REQ-SET-004's pause freezes it for free -- a paused clock
## accumulates no debt, so `run_tick()` is simply never called, while camera, selection and UI
## keep their own frames because the scene tree is never paused.
##
## ---------------------------------------------------------------------------------------
## STAGE ORDER IS `systems_architecture.md` §5's TABLE, NOT CONVENIENCE. Of the 23 systems in
## that table, SIX have an implemented owner and are run here in the table's own order:
##
##   ARCH-SYS-002 CommandCommit     -> `command_dispatch.commit_tick_into()`  every tick, FIRST
##   ARCH-SYS-003 IntervalIntegrator -> `needs.tick_all()`         every tick, after commit
##   ARCH-SYS-008 NeedIntent (PART)  -> `schedule.resolve_into()`  activity resolution only
##   ARCH-SYS-010 JobSelector        -> `jobs.evaluate()`/`assign_worker()`
##   ARCH-SYS-013 ProductiveWork     -> `work.tick_solo_into()` / `tick_party_into()`
##
## ARCH-SYS-017 CareHealth is not a separate call because health, cold exposure and the
## incapacitation/death status transitions are integrated INSIDE `needs.tick_all()`; it is run,
## not skipped, and it is run in ARCH-SYS-003's slot rather than its own. That is the sixth.
##
## ARCH-SYS-002 IS FIRST BECAUSE §5 SAYS "after snapshot, before selectors", and ARCH-SYS-001
## TransformSnapshot does not exist -- there is no Transform store -- so nothing precedes it here.
## A player edit committed at the top of tick k is therefore visible to the SAME tick's selection
## and work stages, which is what "before selectors" buys.
##
## WHAT ARCH-SYS-002 NOW DOES, AND WHAT IT STILL DOES NOT. It drains `commands.gd`'s ordered
## next-tick queue and commits each drained record through `command_dispatch.gd`. In THIS node's
## composition that reaches four of the six implemented kinds -- CANCEL_JOB, NAME_RESIDENT,
## SET_ACTIVITY_SCHEDULE and SET_JOB_PRIORITIES -- because this node composes the resident-side
## stores. DESIGNATE_ZONE and SET_POLICY need `forage.gd` and `job_planner.gd`, which are
## ARCH-SYS-005/009's stores and task 03's to compose; until `bind_ecology()` is called they refuse
## COMMAND_STORE_NOT_BOUND, which is an explicit refusal and NOT a silent success. The remaining
## eighteen ARCH-CMD-003 kinds refuse COMMAND_UNSUPPORTED_FEATURE and name their missing owner.
##
## ARCH-CMD-002's SPEED/PAUSE SCHEDULER EVENTS ARE STILL NOT IMPLEMENTED. Task 04.1 owns their
## separate queue and every one of its widths, enum values and refusals; `sim_clock.gd`'s two
## "BLOCKER U2 ... not implemented" comments remain accurate for that half. So blocker U2 is now
## HALF closed: economic commands have a transport and a commit stage, speed and pause do not.
##
## EVERY OTHER STAGE IS ABSENT BECAUSE ITS OWNING STORE DOES NOT EXIST, and none of them is
## faked here:
##   ARCH-SYS-001 TransformSnapshot   no Transform store; no position, no movement.
##   ARCH-SYS-004 StockAge            `economy_system.gd` states it: nothing advances lot age,
##                                    because the store and temperature factors belong to
##                                    systems this milestone does not build.
##   ARCH-SYS-005 Ecology             STORES NOW EXIST (resource_nodes.gd, forage.gd,
##                                     fishing.gd) but NOTHING DRIVES THEM. This stage is
##                                     task 03 increment 9 and is not started.
##   ARCH-SYS-006 CropWeather         farming.gd and weather.gd NOW EXIST; OrchardPlot and
##                                     Hive do not (U6). Nothing drives any of it: this
##                                     stage is task 03 increment 10 and is not started.
##   ARCH-SYS-007 ImmigrationDeparture no candidate store; `needs.gd` leaves `departure_days`
##                                    explicitly unwritten pending a complete mood.
##   ARCH-SYS-009 JobPlanner          EXISTS NOW (`scripts/core/job_planner.gd`, decision 0039)
##                                    but IS NOT COMPOSED HERE. See THE JOB QUEUE IS EMPTY below
##                                    for exactly what does and does not create work.
##   ARCH-SYS-011 Navigation          no pathfinder, no navigation graph, no route cache.
##   ARCH-SYS-012 Movement            no Transform store and no path to follow.
##   ARCH-SYS-014 BatchCompletion     no BatchState, no recipe store, no passive-wait flag.
##   ARCH-SYS-015 LogisticsCommit     no completion or transfer plans to commit.
##   ARCH-SYS-016 RoomHeat            no Building or Room store; this is also exactly why
##                                    `economy_system.gd` leaves fuel-days unpopulated.
##   ARCH-SYS-018 SocialMood          MoodMemory storage is blocked by U6 (no owner-major index
##                                    formula), so the memory total stays 0 and `needs.gd`
##                                    computes mood from the five needs alone.
##   ARCH-SYS-019 Lifecycle           no create/destroy/arrival/departure intents exist to
##                                    commit; the only lifecycle event in the game is the §5.1
##                                    cohort creation below, which is not a per-tick intent.
##   ARCH-SYS-020 Progression         no Progress store and no completed recipes or feasts.
##   ARCH-SYS-021 ForecastNotice      `economy_system.gd` recomputes its summary synchronously on
##                                    every committed change; its hourly half has nothing to
##                                    change while no lot ages and no policy exists.
##   ARCH-SYS-022 CheckpointHash      no save stream and no canonical digest yet.
##   ARCH-SYS-023 PresentationExtract the HUD polls committed state each frame; nothing is
##                                    extracted here and this node never writes to the UI.
##
## REQ-SET-007's daily order is "age stocks, update ecology, advance crops/weather, process
## immigration/departures, then evaluate progression". Four of those five have no owner at all.
## The ONE thing a day boundary can do here is the season flip: ARCH-TICK-003 places it exactly
## between aging and ecology ("aging uses the season in the elapsed interval; ecology uses the
## new calendar day's season"), and REQ-SET-143's x1.20 winter hunger multiplier is already
## implemented in `needs.gd` with the calendar season as its only input. So `run_day_boundary()`
## applies the season and does nothing else. NO CONSTANT IS INVENTED: the season comes from
## `sim_clock.gd`'s offset calendar and the multiplier from `needs.gd`.
##
## ---------------------------------------------------------------------------------------
## THE JOB QUEUE IN *THIS* SETTLEMENT IS EMPTY, AND THE REASON HAS CHANGED. It is no longer true
## that nothing in the project creates a job: `scripts/core/job_planner.gd` (ARCH-SYS-009,
## decision 0039) creates R06-JOB-007's one 1-WU FARM tending service for each GROWING FarmPlot
## per absolute day, on a dirty condition or its 30-tick staggered idle sweep. Precisely:
##
##   WHAT NOW CREATES WORK: the daily FARM tending service of a GROWING plot, and only that.
##   WHAT STILL CREATES NONE: REQ-SET-073 ripe harvest and REQ-SET-085 withered clearing (both
##     keep their own route and are NOT rerouted through the planner); forage demand
##     (R06-JOB-001/002, deferred); fishing cycles (R06-JOB-003, no Expedition store); sowing
##     first-plant (R06-JOB-004, deferred); rotation advance (R06-JOB-005, no FieldPolicy store);
##     hive service (R06-JOB-006, no Hive store); and every production order, recipe,
##     construction, care request and hauling policy, none of which has a store.
##   WHAT THIS NODE DOES: nothing of the above. It composes no farming store and no planner, so
##     ITS OWN queue is still 0 in a fresh settlement. Joining the planner, farming.gd and
##     weather.gd into this loop is ARCH-SYS-006 (task 03 increment 10), which is not started;
##     composing it here early would run a crop simulation nothing else in this node advances.
##
## `job_queue_length()` reports the real number, and the selection and work stages run over it
## honestly and find nothing. A fabricated job would make the loop look busy and would measure a
## fiction; that has not changed.
##
## Two further gaps mean the job pipeline could not complete a job even if one existed, and both
## belong to files this task does not own:
##   * `jobs.gd` implements eligibility steps 1-6 of 7. STEP 7, "legal destination", is not
##     implemented and the `estimated_path_cells` sort term is not implemented, because no
##     pathfinder exists.
##   * `assign_worker()` moves a job to JOB_STATE_RESERVED. RESERVED -> TRAVEL -> WORK is the
##     completion of travel, which is ARCH-SYS-011/012's work. Nothing here writes JOB_STATE_WORK,
##     because inventing that transition would be inventing the movement layer. The work stage
##     ticks whatever is genuinely in JOB_STATE_WORK and nothing else.
##
## ---------------------------------------------------------------------------------------
## THE RESERVATION POOL IS OWNED AND EMPTY. `reservations.gd` exists to hold job input claims
## (REQ-SET-030's all-or-nothing reservation), and there are no jobs. It is composed and cleared
## with the rest of the settlement so it is one settlement's state rather than a detached object,
## and it holds zero rows. Nothing here claims, renews or releases anything.
##
## ---------------------------------------------------------------------------------------
## ALLOCATION ON THE TICK PATH, named rather than claimed away. Per tick this node allocates
## nothing of its own: the Calendar, the IntResult and the TickResult are instance scratch, and
## every column is packed and sized once. It calls three functions that allocate INSIDE modules
## this task does not own, each their published contract:
##   * `needs.tick_all()`   ONE OpResult per tick for the whole sweep (needs.gd header).
##   * `schedule.resolve_into()` three IntResults inside `needs.gd`, per resident RESOLVED, and a
##     resident resolves once per 30 ticks (schedule.gd header).
##   * `jobs.evaluate()`    one OpResult plus ~27 IntResults per PASS, and a resident passes once
##     per 30 ticks (jobs.gd header, which names 27 as the floor available to it).
##   * `jobs.live_job_at()` one IntResult per live job per tick. `jobs.gd` publishes no `_into`
##     form of it. THIS IS THE ONE THAT WOULD MATTER, and today it costs nothing because there
##     are no jobs; when a job source lands, `jobs.gd` needs a non-allocating live-index reader.
##     Reported, not worked around, and not fixed by editing a file this task does not own.
##
## REFUSAL, NOT SENTINELS. Every operation returns a bool with the reason in `last_refusal()`, or
## an `IntMath.IntResult` whose `.ok` must be inspected. `mean_tick_usec()` REFUSES before the
## first tick rather than answering 0, because 0 microseconds is a plausible-looking measurement.

const EntityDirectoryScript := preload("res://scripts/core/entity_directory.gd")
const NeedsScript := preload("res://scripts/core/needs.gd")
const ResidentsScript := preload("res://scripts/core/residents.gd")
const PrioritiesScript := preload("res://scripts/core/priorities.gd")
const ScheduleScript := preload("res://scripts/core/schedule.gd")
const JobsScript := preload("res://scripts/core/jobs.gd")
const WorkScript := preload("res://scripts/core/work.gd")
const ReservationsScript := preload("res://scripts/core/reservations.gd")
const CommandsScript := preload("res://scripts/core/commands.gd")
const CommandDispatchScript := preload("res://scripts/core/command_dispatch.gd")
const SimClockScript := preload("res://scripts/core/sim_clock.gd")
const IntMath := preload("res://scripts/core/int_math.gd")
const PerfTimerScript := preload("res://scripts/utils/perf_timer.gd")

## Index of winter in `sim_clock.gd`'s SEASON_NAMES. `_assert_shared_contracts()` proves it names
## winter rather than trusting the ordering, because REQ-SET-143's multiplier hangs off it.
const SEASON_WINTER: int = 3
const SEASON_COUNT: int = 4

## REQ-SET-012's "a prepared meal is reachable and unreserved", answered false and NOT guessed.
## Two separate things are missing: §5.7's recipe/portion model, so no prepared MEAL exists as an
## entity at all (a `ration` lot in the pantry is stock, not a served portion nobody has claimed),
## and §5.11's pathfinder, so REACHABLE has no oracle. False therefore says "no reachable prepared
## meal", which is the true state of a settlement with no kitchen and no routes. Its only effect
## is that REQ-SET-013's raw-edible threshold (hunger<=1500) governs the eat interrupt instead of
## REQ-SET-012's 3500 -- and today not even that is observable, because both WORK and ANYTHING
## permit work and no job exists to be interrupted.
const PREPARED_MEAL_REACHABLE: bool = false

const REFUSE_NONE: StringName = &""
const REFUSE_INVALID_TICK: StringName = &"INVALID_TICK"
const REFUSE_INVALID_DAY: StringName = &"INVALID_ABSOLUTE_DAY"
const REFUSE_INVALID_SEASON: StringName = &"INVALID_SEASON"
const REFUSE_NO_TICK_MEASURED: StringName = &"NO_TICK_MEASURED"
const REFUSE_CLOCK_BIND: StringName = &"SIMULATION_CLOCK_BIND_REFUSED"

# --- the settlement's stores (composed once in _init, never reallocated) ----------------------

var _residents: ResidentsScript = ResidentsScript.new()
var _priorities: PrioritiesScript = PrioritiesScript.new()
var _reservations: ReservationsScript = ReservationsScript.new()
var _directory: EntityDirectoryScript = null
var _needs: NeedsScript = null
var _schedule: ScheduleScript = null
var _jobs: JobsScript = null
var _work: WorkScript = null
var _commands: CommandsScript = null
var _dispatch: CommandDispatchScript = null

# --- the live-resident index ------------------------------------------------------------------

## Resident rows this system has attached settlement components to, ascending. `residents.gd`
## keeps the same list privately and publishes no accessor, and this task does not own that file,
## so the index is maintained here at the only two lifecycle points this system owns:
## `create_initial_settlement()` and `reset()`. It exists so the per-tick pass costs O(population)
## rather than a 512-row scan.
var _live_slots: PackedInt32Array = PackedInt32Array()
var _live_count: int = 0

# --- per-tick scratch (not simulation state) --------------------------------------------------

## Reused across ticks; each is consumed before the next call that writes it, and none escapes.
var _calendar: SimClockScript.Calendar = SimClockScript.Calendar.new(0)
var _read: IntMath.IntResult = IntMath.IntResult.new()
var _tick_result: WorkScript.TickResult = WorkScript.TickResult.new(false, REFUSE_NONE)
var _command_report: CommandDispatchScript.TickReport = CommandDispatchScript.TickReport.new()
var _tick_timer: PerfTimerScript = PerfTimerScript.new()

# --- observable counters ----------------------------------------------------------------------

var _ticks_run: int = 0
var _refused_tick_count: int = 0
var _tick_usec_total: int = 0
var _tick_usec_max: int = 0
var _assignment_count: int = 0
var _refused_assignment_count: int = 0
var _accepted_mwu_last_tick: int = 0
var _commands_committed_last_tick: int = 0
var _commands_refused_last_tick: int = 0
var _last_refusal: StringName = REFUSE_NONE
var _reported_refusal: bool = false


func _init() -> void:
	"""Compose the settlement stores once and size the live index; allocate nothing later.

	Every store is built here rather than at declaration because four of them borrow another:
	the residents store owns the directory and needs rows, the schedule reads those same needs,
	jobs read residents/priorities/schedule, and work reads jobs.
	"""
	_directory = _residents.directory()
	_needs = _residents.needs()
	_schedule = ScheduleScript.new(_needs)
	_jobs = JobsScript.new(_residents, _priorities, _schedule)
	_work = WorkScript.new(_jobs)
	_commands = CommandsScript.new(SimClockScript.new(), _directory)
	_dispatch = CommandDispatchScript.new(_commands, _residents, _priorities, _schedule, _jobs)
	_live_slots.resize(ResidentsScript.RESIDENT_CAPACITY)
	_live_slots.fill(EntityDirectoryScript.NULL_SLOT)
	_assert_shared_contracts()


func _assert_shared_contracts() -> void:
	"""Prove the capacities and the season index this file reads out of other modules."""
	assert(ResidentsScript.RESIDENT_CAPACITY == NeedsScript.RESIDENT_CAPACITY,
		"the resident and needs stores must share one row capacity")
	assert(ResidentsScript.RESIDENT_CAPACITY == ScheduleScript.SCHEDULE_CAPACITY,
		"the schedule store must share the resident row capacity")
	assert(ResidentsScript.RESIDENT_CAPACITY == PrioritiesScript.PRIORITY_CAPACITY,
		"the priorities store must share the resident row capacity")
	assert(SimClockScript.SEASON_NAMES.size() == SEASON_COUNT,
		"the calendar must publish exactly four seasons")
	assert(SimClockScript.SEASON_NAMES[SEASON_WINTER] == "winter",
		"SEASON_WINTER must index the calendar's winter, which REQ-SET-143 hangs off")


func _ready() -> void:
	"""Keep receiving frames through pauses, bind to the clock, and report readiness.

	The bind is what makes this the production caller of the core modules. A refused bind is
	reported loudly rather than swallowed: the settlement would otherwise sit inert while the
	HUD kept displaying a running game.
	"""
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not GameManager.bind_simulation(run_tick, run_day_boundary):
		_last_refusal = REFUSE_CLOCK_BIND
		push_error("SettlementSystem could not bind to the clock: %s" % GameManager.last_refusal())
	print("[SettlementSystem] ready")


# --- lifecycle ---------------------------------------------------------------------------------

func create_initial_settlement() -> bool:
	"""Spawn the GDD §5.1 starting cohort and attach every per-resident settlement row.

	All-or-nothing: a partial cohort, or a resident missing its schedule or job agent, would be a
	settlement that ticks some residents and not others. On any refusal the whole settlement is
	returned to empty and the reason is preserved in `last_refusal()`.

	There is deliberately NO second emptiness check here. `residents.spawn_initial_settlement()`
	already refuses a non-empty store, to protect §5.1's "IDs 1-12", and a copy of that rule here
	would be a second place for it to be stated and to drift. Its refusal is passed through.
	"""
	var spawned: ResidentsScript.OpResult = _residents.spawn_initial_settlement()
	if not spawned.ok:
		return _refuse(spawned.error)
	if not _attach_all_residents():
		var code: StringName = _last_refusal
		reset()
		_last_refusal = code
		return false
	_last_refusal = REFUSE_NONE
	return true


func _attach_all_residents() -> bool:
	"""Attach settlement components to every spawned resident row, in ascending slot order."""
	for slot: int in ResidentsScript.RESIDENT_CAPACITY:
		if not _residents.is_present(slot):
			continue
		if not _attach_resident(slot):
			return false
	return true


func _attach_resident(slot: int) -> bool:
	"""Give one resident its Priorities, Schedule and JobAgent rows, all-or-nothing.

	The schedule template is `schedule.gd`'s own `default_template_id()`. GDD §5.1 states no
	starting template for the cohort; that module says so in its header and publishes the §5.3
	default for exactly this caller, so the number is read from it rather than written here.
	"""
	var template: IntMath.IntResult = _schedule.default_template_id()
	if not template.ok:
		return _refuse(StringName(template.error))
	var priorities: PrioritiesScript.OpResult = _priorities.spawn(slot)
	if not priorities.ok:
		return _refuse(priorities.error)
	var schedule: ScheduleScript.OpResult = _schedule.spawn(slot, template.value)
	if not schedule.ok:
		_priorities.despawn(slot)
		return _refuse(schedule.error)
	var agent: JobsScript.OpResult = _jobs.spawn_agent(slot)
	if not agent.ok:
		_schedule.despawn(slot)
		_priorities.despawn(slot)
		return _refuse(agent.error)
	_live_slots[_live_count] = slot
	_live_count += 1
	return true


func reset() -> void:
	"""Empty every settlement store, index and counter, without reallocating a column.

	`residents.clear()` also clears the directory and needs rows, because this system built the
	residents store with neither collaborator supplied and it therefore owns both.
	"""
	_residents.clear()
	_priorities.clear()
	_schedule.clear()
	_jobs.clear()
	_work.clear()
	_reservations.clear()
	_commands.clear()
	_dispatch.clear()
	_live_slots.fill(EntityDirectoryScript.NULL_SLOT)
	_live_count = 0
	_ticks_run = 0
	_refused_tick_count = 0
	_tick_usec_total = 0
	_tick_usec_max = 0
	_assignment_count = 0
	_refused_assignment_count = 0
	_accepted_mwu_last_tick = 0
	_commands_committed_last_tick = 0
	_commands_refused_last_tick = 0
	_last_refusal = REFUSE_NONE
	_reported_refusal = false


# --- the tick ----------------------------------------------------------------------------------

func run_tick(tick_index: int) -> bool:
	"""Run one completed fixed tick through the §5 stages that have an implemented owner.

	`tick_index` is the index of the tick being committed, supplied by the clock through
	GameManager. No elapsed time, no delta and no speed reaches this function: at 2x and 4x it is
	called more often and does exactly the same work (REQ-SET-003, REQ-SET-011).
	"""
	if tick_index < 0:
		return _refuse(REFUSE_INVALID_TICK)
	_tick_timer.start()
	var ok: bool = _run_stages(tick_index)
	_record_tick_cost(_tick_timer.stop())
	return ok


func _run_stages(tick_index: int) -> bool:
	"""ARCH-SYS-002, then 003, then 008/010, then 013, in the §5 table's order.

	CommandCommit is FIRST because §5 places it "after snapshot, before selectors" and no
	TransformSnapshot exists. A refused command does not stop the tick: the stage records the
	refusal against that command and the settlement keeps running, because one player edit
	failing is not a reason to stop integrating everybody's needs.
	"""
	_last_refusal = REFUSE_NONE
	_accepted_mwu_last_tick = 0
	_commit_commands(tick_index)
	if not _integrate_interval():
		return false
	_select_jobs(tick_index)
	_run_productive_work()
	return true


func _commit_commands(tick_index: int) -> void:
	"""ARCH-SYS-002 CommandCommit: drain and commit every player edit due at this tick."""
	_commands_committed_last_tick = 0
	_commands_refused_last_tick = 0
	if not _dispatch.commit_tick_into(tick_index, _command_report):
		_last_refusal = _dispatch.last_refusal()
		return
	_commands_committed_last_tick = _command_report.committed
	_commands_refused_last_tick = _command_report.refused
	_ensure_command_clock()


func _ensure_command_clock() -> void:
	"""Keep the queue stamping `completed_tick+1` from the clock the game is really running on.

	`GameManager.start_game()` REPLACES its `SimClock` instance, so a queue bound once would go on
	reading a clock that had stopped moving and would stamp every later edit with a stale tick.
	The check is a reference comparison per tick and the rebind happens at most once per run.

	IT RUNS AFTER THE DRAIN AND ONLY ON AN EMPTY QUEUE, so no accepted command is ever discarded
	by it: records already in the queue were stamped against the OLD clock's numbering, and
	`commands.rebind_clock()` refuses to re-base them. They are committed at their own due tick
	first, and the rebind takes the next opportunity.
	"""
	var live: SimClockScript = GameManager.clock()
	if live == null or _commands.clock() == live or _commands.pending_count() != 0:
		return
	_commands.rebind_clock(live)


func _record_tick_cost(usec: int) -> void:
	"""Fold one measured tick duration into the running total, count and maximum."""
	_ticks_run += 1
	_tick_usec_total += usec
	if usec > _tick_usec_max:
		_tick_usec_max = usec


func _integrate_interval() -> bool:
	"""ARCH-SYS-003 IntervalIntegrator: one tick of needs, cold, health and status per resident.

	ARCH-SYS-017 CareHealth runs here too rather than in a stage of its own, because `needs.gd`
	integrates health, cold exposure and the incapacitation transitions inside the same sweep.
	A refusal names the row in `needs.last_refused_slot()` and stops the tick: a partial sweep
	must be visible, not averaged away.
	"""
	var swept: NeedsScript.OpResult = _needs.tick_all()
	if swept.ok:
		return true
	_refused_tick_count += 1
	_report_first_refusal(swept.error)
	return _refuse(swept.error)


func _select_jobs(tick_index: int) -> void:
	"""ARCH-SYS-008 (activity resolution only) and ARCH-SYS-010 JobSelector.

	§5.3 reevaluates an idle resident every 30 ticks staggered by persistent ID mod 30, and
	`jobs.should_evaluate()` is that predicate -- allocation-free, and false for a resident who
	already holds a job. The activity is resolved immediately before the pass that reads it, so
	eligibility step 2 can never see a stale hour.
	"""
	var hour: int = _hour_of(tick_index)
	for index: int in _live_count:
		var slot: int = _live_slots[index]
		if not _jobs.should_evaluate(slot, tick_index):
			continue
		if not _residents.is_alive(slot):
			continue
		if not _schedule.resolve_into(slot, hour, PREPARED_MEAL_REACHABLE, _read):
			continue
		_offer_a_job(slot, tick_index)


func _offer_a_job(resident_slot: int, tick_index: int) -> void:
	"""Nominate one job for an idle resident and bind it if commitment revalidates.

	`evaluate()` returns a NOMINATION; `assign_worker()` re-runs the whole of eligibility before
	it binds. Both refusals are ORDINARY here and neither is an error: with no job source, every
	pass refuses NO_ELIGIBLE_JOB, which is the honest result of an empty queue.
	"""
	var nomination: JobsScript.OpResult = _jobs.evaluate(resident_slot, tick_index)
	if not nomination.ok:
		return
	var bound: JobsScript.OpResult = _jobs.assign_worker(resident_slot, nomination.value)
	if bound.ok:
		_assignment_count += 1
		return
	_refused_assignment_count += 1


func _run_productive_work() -> void:
	"""ARCH-SYS-013 ProductiveWork: one productive tick for every live activity that can take one.

	The walk is over live jobs rather than over workers, because a party must be ticked ONCE
	through its coordinator and a per-worker walk would tick it once per member. Today the walk
	is empty: nothing creates jobs (header).
	"""
	for index: int in _jobs.job_count():
		var live: IntMath.IntResult = _jobs.live_job_at(index)
		if not live.ok:
			continue
		_tick_one_activity(live.value)


func _tick_one_activity(job_slot: int) -> void:
	"""Tick one activity: a party through its coordinator, an ordinary job on its own row.

	A member row is skipped because decision 0017 keeps shared progress on the coordinator alone.
	A refusal is ordinary -- a job in TRAVEL, a job with no worker, a finished job -- and is not
	recorded as a fault; `work.gd` guarantees a refusal carries zero accepted work.
	"""
	if _jobs.is_member(job_slot):
		return
	if _jobs.is_coordinator(job_slot):
		if _work.tick_party_into(job_slot, _tick_result):
			_accepted_mwu_last_tick += _tick_result.accepted_mwu
		return
	if _work.tick_solo_into(job_slot, _tick_result):
		_accepted_mwu_last_tick += _tick_result.accepted_mwu


func _hour_of(tick_index: int) -> int:
	"""Calendar hour 0-23 of the tick being committed, decoded into the reused Calendar.

	The hour of tick k, not of k-1: a schedule slot covers [h:00, h+1:00), so the first tick of
	an hour already belongs to the new slot. This is a per-tick reading of a static table, not an
	accumulated boundary effect, so ARCH-TICK-002's "never age twice at a crossing" does not
	apply to it.
	"""
	SimClockScript.calendar_at_into(tick_index, _calendar)
	return _calendar.hour


func run_day_boundary(absolute_day: int, season: int) -> bool:
	"""REQ-SET-007 daily boundary, restricted to the one stage that has an implemented owner.

	Stock aging, ecology, crops/weather, immigration/departures and progression all have no store
	in this milestone (header). What remains is ARCH-TICK-003's season handover -- "ecology uses
	the new calendar day's season" -- which drives REQ-SET-143's x1.20 winter hunger multiplier
	inside `needs.gd`. `absolute_day` is validated but drives nothing yet: the systems that count
	days (departure, progression streaks, candidate events) do not exist.
	"""
	if absolute_day <= 0:
		return _refuse(REFUSE_INVALID_DAY)
	if season < 0 or season >= SEASON_COUNT:
		return _refuse(REFUSE_INVALID_SEASON)
	var applied: ResidentsScript.OpResult = _residents.set_winter(season == SEASON_WINTER)
	if not applied.ok:
		return _refuse(applied.error)
	_last_refusal = REFUSE_NONE
	return true


# --- readers -----------------------------------------------------------------------------------

func population() -> int:
	"""Resident rows this settlement holds, including a row whose resident has died."""
	return _live_count


func living_count() -> int:
	"""Residents the needs store still counts as living."""
	return _residents.living_count()


func job_queue_length() -> int:
	"""Live Job rows. Zero until something creates a job; nothing in this milestone does."""
	return _jobs.job_count()


func ticks_run() -> int:
	"""Settlement ticks executed since the last reset(), refused ticks included."""
	return _ticks_run


func refused_tick_count() -> int:
	"""Ticks whose interval integration refused, so a partial sweep is never silent."""
	return _refused_tick_count


func assignment_count() -> int:
	"""Workers bound to a job by the selection stage since the last reset()."""
	return _assignment_count


func refused_assignment_count() -> int:
	"""Nominations that failed revalidation at the commitment point since the last reset()."""
	return _refused_assignment_count


func accepted_mwu_last_tick() -> int:
	"""Milli-work-units accepted across every activity during the most recent tick."""
	return _accepted_mwu_last_tick


func last_tick_usec() -> int:
	"""Measured duration of the most recent settlement tick, in host microseconds."""
	return _tick_timer.get_last_usec()


func max_tick_usec() -> int:
	"""Longest measured settlement tick since the last reset(), in host microseconds."""
	return _tick_usec_max


func mean_tick_usec() -> IntMath.IntResult:
	"""Mean measured tick duration in microseconds; REFUSES before the first tick.

	A mean over zero ticks has no value, and answering 0 would be a measurement-shaped sentinel.
	"""
	var out: IntMath.IntResult = IntMath.IntResult.new()
	if _ticks_run <= 0:
		out.refuse(String(REFUSE_NO_TICK_MEASURED))
		return out
	IntMath.floor_div_into(_tick_usec_total, _ticks_run, out)
	return out


func is_winter() -> bool:
	"""True while REQ-SET-143's winter hunger multiplier is in force."""
	return _residents.is_winter()


func last_refusal() -> StringName:
	"""Reason the most recent refused operation was refused; empty after a successful one."""
	return _last_refusal


func directory() -> EntityDirectoryScript:
	"""The allocator behind every settlement reference."""
	return _directory


func residents() -> ResidentsScript:
	"""The settlement's population. EconomySystem BORROWS this as its food-days divisor."""
	return _residents


func needs() -> NeedsScript:
	"""The GDD §5.2 needs, health and cold store, shared with the residents store."""
	return _needs


func priorities() -> PrioritiesScript:
	"""The per-resident job priority and work-policy store."""
	return _priorities


func schedule() -> ScheduleScript:
	"""The 24-hour schedule store and its §5.3 activity resolution."""
	return _schedule


func jobs() -> JobsScript:
	"""The Job and JobAgent store and its §5.3 selection pass."""
	return _jobs


func work() -> WorkScript:
	"""The §5.2 work-unit model and decision 0017's party acceptance."""
	return _work


func commands() -> CommandsScript:
	"""ARCH-CMD-001's ordered next-tick queue. A UI submits here; nothing else edits the stores."""
	return _commands


func command_dispatch() -> CommandDispatchScript:
	"""ARCH-SYS-002's commit stage, and the named handoff point for task 03's ecology stores.

	`bind_ecology()` on this object is what stops DESIGNATE_ZONE and SET_POLICY refusing
	COMMAND_STORE_NOT_BOUND. It is deliberately not called here: `forage.gd` and `job_planner.gd`
	are ARCH-SYS-005/009's stores, composing them would run an ecology this node does not advance.
	"""
	return _dispatch


func commands_committed_last_tick() -> int:
	"""Player commands committed by the most recent CommandCommit stage."""
	return _commands_committed_last_tick


func commands_refused_last_tick() -> int:
	"""Player commands the most recent CommandCommit stage refused, with a documented result id."""
	return _commands_refused_last_tick


func reservations() -> ReservationsScript:
	"""The global reservation pool. Empty: no job exists to claim an input (header)."""
	return _reservations


func _report_first_refusal(code: StringName) -> void:
	"""Push the first tick refusal of a run to the log, once, so a stuck loop is not silent.

	Once, deliberately: a refusal that recurs every tick would push 30 errors a second and bury
	the failure it is reporting. The count stays exact in `refused_tick_count()`.
	"""
	if _reported_refusal:
		return
	_reported_refusal = true
	push_error("SettlementSystem: interval integration refused '%s' at resident row %d" % [
		code, _needs.last_refused_slot()])


func _refuse(code: StringName) -> bool:
	"""Record a refusal code and return false, so callers can `return _refuse(...)`."""
	_last_refusal = code
	return false
